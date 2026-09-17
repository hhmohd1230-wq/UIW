-- v44: bounded hazard prediction, attack opportunities, and wide navigation.
do
    CONFIG.PathPreferredRadius = 4.5
    CONFIG.MajorWarningWidth = 44
    CONFIG.MajorEscapeLimit = 220

    local legacyHazardPart = HazardTracker.IsHazardPart
    function HazardTracker:IsHazardPart(part)
        -- Enemy decorations (e.g. Generator.headOrb) are not damage hitboxes.
        if part:IsA("BasePart") and not isExactAttackPartName(self, part) then
            local model = part.Parent
            for _ = 1, 6 do
                if not model or model == Workspace then break end
                if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
                    return false
                end
                model = model.Parent
            end
        end
        return legacyHazardPart(self, part)
    end

    local legacyTank = HazardTracker.IsTankable
    function HazardTracker:IsTankable(data)
        -- Sparse damage history must never suppress an impending large attack.
        if data.IsPrecast or data.GrowWarning then return false end
        local size = data.Part.Size
        if math.min(size.X, size.Z) >= CONFIG.MajorWarningWidth then return false end
        return legacyTank(self, data)
    end

    function RoutePlanner:CreatePath(radius)
        self:PruneAvoidZones()
        return PathfindingService:CreatePath({
            AgentRadius = radius or CONFIG.PathPreferredRadius,
            AgentHeight = CONFIG.PathAgentHeight,
            AgentCanJump = true, AgentCanClimb = true,
            WaypointSpacing = CONFIG.PathWaypointSpacing,
            Costs = { UIWAvoid = CONFIG.AvoidZoneCost },
        })
    end

    function GeometrySensor:IsWideSegmentClear(origin, destination, radius)
        local delta = flatten(destination - origin)
        if delta.Magnitude < 0.1 then return true end
        local size = self:GetSweepSize()
        size = Vector3.new(math.max(size.X, radius * 2), size.Y, math.max(size.Z, radius * 2))
        local center = origin + Vector3.new(0, math.max(0.8, size.Y * 0.28), 0)
        local hit, ok = self:BlockcastSkippingEntries(CFrame.new(center), size, delta)
        if not ok or hit then return false end
        local samples = math.max(1, math.ceil(delta.Magnitude / 3))
        for i = 1, samples do
            if not self:HasGround(origin:Lerp(destination, i / samples)) then return false end
        end
        return true
    end

    function RoutePlanner:SkipToVisibleWaypoint(targetYaw)
        local root = self.CharacterService.Root
        if not root then return false end
        for index = math.min(#self.Waypoints, self.WaypointIndex + 5), self.WaypointIndex + 1, -1 do
            local waypoint = self.Waypoints[index]
            local skipJump = false
            for j = self.WaypointIndex, index do
                if self.Waypoints[j].Action == Enum.PathWaypointAction.Jump then skipJump = true break end
            end
            local delta = flatten(waypoint.Position - root.Position)
            if not skipJump and delta.Magnitude > 2 and delta.Magnitude <= 28
                and math.abs(waypoint.Position.Y - root.Position.Y) <= 3
                and self.Geometry:IsWideSegmentClear(root.Position, waypoint.Position, CONFIG.PathPreferredRadius)
                and self.Hazards:IsTrajectoryClear(root.Position, delta.Unit, targetYaw, delta.Magnitude)
                and self.Hazards:IsPrecastTrajectoryClear(root.Position, delta.Unit, targetYaw, delta.Magnitude)
            then
                self.WaypointIndex = index
                self.LastJumpWaypoint = 0
                self:SetupWaypointPlane()
                return true
            end
        end
        return false
    end

    local legacyPreferred = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        self.AttackHolding = false
        if not self.ForceRouteMovement and not self.TargetBlocked and isBossEnemy(enemy)
            and enemy.Root and enemy.Root.Parent and self.Combat
            and normalizeEnemyName(enemy.Model.Name) ~= "crystal golem" then
            local root = self.CharacterService.Root
            local delta = flatten(enemy.Root.Position - root.Position)
            local distance = delta.Magnitude
            if distance > CONFIG.BossMaxRange and distance <= 150
                and math.abs(enemy.Root.Position.Y-root.Position.Y) <= 20
                and self.Combat:HasLineOfSight(enemy) then
                local probe = math.min(18,distance-CONFIG.BossIdealRange)
                local destination=root.Position+delta.Unit*probe
                if self.Geometry:IsWideSegmentClear(root.Position,destination,CONFIG.PathPreferredRadius) then
                    self.TravelMode=false
                    return delta.Unit
                end
            end
            if distance >= CONFIG.BossMinRange and distance <= CONFIG.BossMaxRange
                and self.Combat:HasLineOfSight(enemy) then
                local state = self.Combat:GetPreparationState()
                if state.AnyDamageReady or self.Combat:IsBusyCasting() then
                    -- Only normal movement holds. The hazard solver still runs first.
                    self.TravelMode = false
                    self.AttackHolding = true
                    return Vector3.zero
                end
            end
        end
        return legacyPreferred(self, routeDirection, enemy, targetYaw)
    end

    local legacyAim = CombatController.GetAimYaw
    function CombatController:GetAimYaw(enemy, fallbackYaw, enemies)
        if isBossEnemy(enemy) and enemy.Root and enemy.Root.Parent then
            local yaw = directionToYaw(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
            self.LastAimModel, self.LastAimYaw, self.LastAimOffset = enemy.Model, yaw, 0
            return yaw
        end
        return legacyAim(self, enemy, fallbackYaw, enemies)
    end

    local legacyCombat = CombatController.Update
    function CombatController:Update(enemy)
        if self.SuppressForMajorEscape then
            self.LastAction = nil
            self.LastBlockReason = "moving to safety before casting"
            return false
        end
        if not isBossEnemy(enemy) then return legacyCombat(self, enemy) end
        self.LastAction, self.LastBlockReason = nil, nil
        if not enemy.Root or not enemy.Root.Parent or not self.CharacterService:IsAlive() then return false end
        if not self:CanSendInput() then self.LastBlockReason = "chat focused" return false end
        if self:IsBusyCasting() then self.LastBlockReason = "casting" return false end
        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance > CONFIG.DamageCastRange then self.LastBlockReason = "outside damage range" return false end
        local yaw = directionToYaw(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
        -- At 60 studs, the old 28 degree tolerance could miss a 16-stud-wide spell.
        local tolerance = math.clamp(math.deg(math.atan((CONFIG.CastHitboxWidth * 0.4) / math.max(distance, 1))), 4, 16)
        if not self:IsFacing(yaw, tolerance) then self.LastBlockReason = "turning to target" return false end
        if not self:HasLineOfSight(enemy) then self.LastBlockReason = "no line of sight" return false end
        local damageSlot, buffSlot
        for _, slot in ipairs({"q", "e"}) do
            local tool = self:GetTool(slot)
            if tool and self:IsReady(slot) then
                if self:IsBuffTool(tool) then buffSlot = buffSlot or slot
                else damageSlot = damageSlot or slot end
            end
        end
        if not damageSlot then self.LastBlockReason = "damage cooldown" return false end
        -- Prime once, then guarantee the next available input goes to damage.
        if buffSlot and (self.BossBuffTarget ~= enemy.Model or os.clock() - (self.BossBuffAt or 0) > 4) then
            self.BossBuffTarget, self.BossBuffAt = enemy.Model, os.clock()
            self:Press(buffSlot)
        else
            self:ClearCommit()
            self:Press(damageSlot)
        end
        return true
    end

    function UIWController:GetMajorWarningGoal()
        local now = os.clock()
        if now - (self.MajorScanAt or 0) < 0.18 then
            local d = self.MajorWarning
            if d and d.Part and d.Part.Parent then return self.MajorEscapeGoal, "LargeAttackEscape", nil end
            return nil
        end
        self.MajorScanAt = now
        local origin = self.Character.Root.Position
        local yaw = self.Character.DesiredYaw or 0
        local threat
        for _, d in ipairs(self.Hazards.CachedWarnings or {}) do
            if d.WarningCF and d.WarningHalf and not d.LaneCorridor then
                local cf, h = d.WarningCF, d.WarningHalf
                -- Measure the oriented floor footprint. A diagonal thin lane's
                -- world-aligned bounding box is wide in both X and Z.
                local axes={cf.RightVector,cf.UpVector,cf.LookVector}
                local widths={h.X*2,h.Y*2,h.Z*2}
                local vertical=1
                for i=2,3 do if math.abs(axes[i].Y)>math.abs(axes[vertical].Y) then vertical=i end end
                local narrow=math.huge
                for i=1,3 do
                    if i~=vertical then narrow=math.min(narrow,widths[i]*math.sqrt(math.max(0,1-axes[i].Y*axes[i].Y))) end
                end
                if narrow >= CONFIG.MajorWarningWidth
                    and self.Hazards:IsBodyInWarning(origin, yaw, d) then
                    threat = d break
                end
            end
        end
        if not threat then
            self.MajorWarning, self.MajorEscapeGoal = nil, nil
            return nil
        end
        local body = self.Character.BodySize
        local padding = math.max(body.X,body.Z)*0.5 + CONFIG.PrecastSafetyPadding + 3
        local cf, half = threat.WarningCF, threat.WarningHalf
        local localOrigin = cf:PointToObjectSpace(origin)
        local candidates = {}
        -- Ray/box exits cover a large attack without a fixed short dodge radius.
        for i = 0, 15 do
            local a = i * math.pi / 8
            local direction = Vector3.new(math.cos(a),0,math.sin(a))
            local v = cf:VectorToObjectSpace(direction)
            local exit = math.huge
            for _, axis in ipairs({"X","Y","Z"}) do
                if math.abs(v[axis]) > 0.001 then
                    local edge = v[axis] > 0 and half[axis]+padding or -half[axis]-padding
                    local t = (edge-localOrigin[axis])/v[axis]
                    if t > 0 then exit = math.min(exit,t) end
                end
            end
            if exit <= CONFIG.MajorEscapeLimit then
                table.insert(candidates, {Point=origin+direction*exit, Distance=exit})
            end
        end
        table.sort(candidates,function(a,b) return a.Distance < b.Distance end)
        local chosen, best = nil, math.huge
        local initialHits={}
        for _,part in ipairs(self.Hazards:GetBodyOverlaps(origin,yaw)) do initialHits[part]=true end
        for _, candidate in ipairs(candidates) do
            local point = candidate.Point
            local delta = flatten(point-origin)
            if self.Geometry:HasGround(point)
                and self.Geometry:IsDirectionClear(delta.Unit,delta.Magnitude,yaw)
                and self.Hazards:GetOverlapCountAt(point,yaw)==0 then
                local clear = true
                for _,d in ipairs(self.Hazards.CachedWarnings or {}) do
                    if self.Hazards:IsBodyInWarning(point,yaw,d) then clear=false break end
                end
                if clear then
                    -- Reject paths that leave the initial danger and re-enter another.
                    for step=1,math.ceil(delta.Magnitude/4) do
                        local at=origin+delta*(step/math.ceil(delta.Magnitude/4))
                        if not self.Geometry:HasGround(at) then clear=false break end
                        for _,part in ipairs(self.Hazards:GetBodyOverlaps(at,yaw)) do
                            if not initialHits[part] then clear=false break end
                        end
                        if not clear then break end
                        for _,d in ipairs(self.Hazards.CachedWarnings or {}) do
                            if not self.Hazards:IsBodyInWarning(origin,yaw,d)
                                and self.Hazards:IsBodyInWarning(at,yaw,d) then clear=false break end
                        end
                        if not clear then break end
                    end
                end
                if clear then
                    local score = candidate.Distance
                    if self.MajorEscapeGoal and (point-self.MajorEscapeGoal).Magnitude < 10 then score-=8 end
                    if score < best then chosen,best=point,score end
                end
            end
        end
        self.MajorWarning, self.MajorEscapeGoal = threat,chosen
        if chosen then return chosen,"LargeAttackEscape",nil,flatten(chosen-origin).Magnitude end
        return nil -- No verified route: retain the existing least-risk solver.
    end

    -- Aquatic Temple's Sea King uses centerPart + enabled beams, not precast.
    SAFE_ZONE_MULTI_CONTAINER_NAMES.lastbosssafezones = true
    local legacySafeZone = UIWController.GetActiveSafeZone
    function UIWController:GetActiveSafeZone()
        local part,state,distance=legacySafeZone(self)
        if not self.Character:IsAlive() then return part,state,distance end
        local zones=Workspace:FindFirstChild("lastBossSafeZones")
        if zones and isBossEnemy(self.CurrentEnemy) then
            for _,zone in ipairs(zones:GetChildren()) do
                local center=zone:FindFirstChild("centerPart")
                if center and center:IsA("BasePart") and hasEnabledSafeZoneBeam(zone) then
                    local d=flatten(center.Position-self.Character.Root.Position).Magnitude
                    if d<=250 and (not part or d<distance) then
                        part,state,distance=center,"MassSafeZone",d
                    end
                end
            end
        end
        return part,state,distance
    end

    local legacyMechanic = UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        local goal,state,part,distance = legacyMechanic(self)
        if not goal then goal,state,part,distance = self:GetMajorWarningGoal() end
        self.ActiveMechanicState = state
        self.Combat.SuppressForMajorEscape = goal ~= nil and (
            state == "LargeAttackEscape" or state == "MassSafeZone" or state == "MemorySafeZone"
            or state == "SafeZone" or state == "SafeSpotCircle" or state == "CrystalGolemWallCover")
            and flatten(goal-self.Character.Root.Position).Magnitude > 3.5
        return goal,state,part,distance
    end

    local legacySolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local owner = self.Owner
        if owner and owner.ActiveMechanicState == "LargeAttackEscape" and owner.MajorEscapeGoal then
            local delta=flatten(owner.MajorEscapeGoal-self.CharacterService.Root.Position)
            if delta.Magnitude > 0.5 and self.Geometry:IsDirectionClear(delta.Unit,math.min(delta.Magnitude,5),targetYaw) then
                self.LastDodgeReason,self.IsDodging="large-attack",true
                self.CommittedDodgeDirection=Vector3.zero
                self.DodgeCommitUntil=0
                return delta.Unit,targetYaw,false,true
            end
        end
        -- Do not reuse a backward dodge after the danger has ended during a cast window.
        if self.AttackHolding and self.Combat and self.Combat:GetPreparationState().AnyDamageReady
            and not self:IsImmediateHazardDanger(Vector3.zero,targetYaw) then
            self.CommittedDodgeDirection=Vector3.zero
            self.DodgeCommitUntil=0
        end
        return legacySolve(self,routeDirection,enemy,targetYaw)
    end

    local legacyNew = UIWController.new
    function UIWController.new()
        local self=legacyNew()
        self.Version="44"
        self.Dodger.Combat=self.Combat
        self.Dodger.Owner=self
        return self
    end
end
