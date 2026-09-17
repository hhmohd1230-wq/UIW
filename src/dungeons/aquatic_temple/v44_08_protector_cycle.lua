-- v44.8: Ancient Temple Protector cycle planner (measured live):
--   t+0.00  lines circle: 24 beams (6 wide, 15 deg apart) from a point 25 studs
--           in front of the boss; damage lands about 1 s later
--   t+1.47  squares: rings around that point, half size 15.5 + 17.5k, 12 thick
--   t+4.98  stomp wave: starts at the boss root along its facing, width = r + 10,
--           grows about 48 studs/s, lasts 5 s, one-shots
--   t+10.16 grid lines; t+15.65 the cycle repeats
do
    CONFIG.ProtRayClear = 4.4
    CONFIG.ProtRayMinDist = 33
    CONFIG.ProtRayMaxDist = 52
    CONFIG.ProtRayImpact = 1.0
    CONFIG.ProtSquareFirst = 15.5
    CONFIG.ProtSquareStep = 17.5
    CONFIG.ProtSquareCount = 5
    CONFIG.ProtSquareHalf = 6
    CONFIG.ProtSquarePad = 1.6
    CONFIG.ProtHoldUntil = 3.3
    CONFIG.ProtWedgeDelay = 4.98
    CONFIG.ProtWedgeLead = 1.7
    CONFIG.ProtWedgeSpeed = 47.6
    CONFIG.ProtWedgeLife = 5.3
    CONFIG.ProtWedgePad = 2.4
    CONFIG.ProtWedgeLength = 160
    CONFIG.ProtOrbitRadius = 20
    CONFIG.ProtOrbitMin = 12
    CONFIG.ProtOrbitMax = 30

    local function isProtector(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient temple protector"
            and enemy.Root and enemy.Root.Parent
    end

    local function perpOf(d)
        return Vector3.new(-d.Z, 0, d.X)
    end

    ---------------------------------------------------------------------------
    -- Event capture
    ---------------------------------------------------------------------------
    local oldRegister = HazardTracker.Register
    function HazardTracker:Register(part)
        local known = self.Hazards[part] ~= nil
        oldRegister(self, part)
        local data = self.Hazards[part]
        if known or not data then
            return
        end

        local owner = self.Owner
        local boss = owner and owner.CurrentEnemy
        if not isProtector(boss) then
            boss = nil
            local dungeon = owner and owner.Dungeon
            if dungeon then
                for _, enemy in ipairs(dungeon:GetAliveEnemies()) do
                    if isProtector(enemy) then
                        boss = enemy
                        break
                    end
                end
            end
            if not boss then
                return
            end
        end

        local cname = data.Container and data.Container.Name or ""
        if cname ~= "firstBossRightHandShot" and cname ~= "Model" and cname ~= "secondBossGridShot" then
            return
        end

        -- These attacks are modeled exactly below; never stretch them into
        -- arena-wide slam lines.
        data.SlamBand = false
        data.ProtectorAttack = cname

        local now = os.clock()
        local st = self.ProtState or {}
        self.ProtState = st
        local bossRoot = boss.Root
        local look = flatten(bossRoot.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)

        if cname == "firstBossRightHandShot" then
            if not st.RaysAt or now - st.RaysAt > 6 then
                st.RaysAt = now
                st.Rays = {}
                st.Plan = nil
                st.PlanAt = 0
                st.Look = look
                st.Origin = nil
                st.Cycles = (st.Cycles or 0) + 1
            end
            if not st.Origin then
                local container = data.Container
                local primary = container:IsA("Model") and container.PrimaryPart
                    or container:FindFirstChild("PrimaryPart")
                if primary and primary:IsA("BasePart") then
                    st.Origin = primary.Position
                end
            end
            if part.Name == "hitBox" then
                table.insert(st.Rays, part)
                st.Plan = nil
            end
        elseif cname == "Model" and part.Name == "hitBox" then
            local size = part.Size
            local thin = math.min(size.X, size.Z)
            local rel = flatten(part.Position - bossRoot.Position)
            if thin <= 10.6 and size.Y >= 100 then
                -- Stomp wave piece.
                local r = rel:Dot(look)
                if not st.WedgeAt or now - st.WedgeAt > 3 then
                    st.WedgeAt = now - math.max(0, r) / CONFIG.ProtWedgeSpeed
                    st.WedgeDir = look
                    st.WedgeOrigin = bossRoot.Position
                    st.WedgePart = part
                    st.Wedges = (st.Wedges or 0) + 1
                end
            elseif thin <= 13 and size.Y >= 100 then
                if not st.SquaresAt or now - st.SquaresAt > 3 then
                    st.SquaresAt = now
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Wedge (stomp wave) as a virtual hazard
    ---------------------------------------------------------------------------
    function HazardTracker:GetProtectorWedge()
        local st = self.ProtState
        if not st or not st.WedgeAt or os.clock() - st.WedgeAt > CONFIG.ProtWedgeLife then
            return nil
        end
        return st
    end

    function HazardTracker:IsInProtectorWedge(position, pad)
        local st = self:GetProtectorWedge()
        if not st then
            return false, 0, 0
        end
        local v = flatten(position - st.WedgeOrigin)
        local r = v:Dot(st.WedgeDir)
        local lat = v:Dot(perpOf(st.WedgeDir))
        local half = math.max(r, 0) * 0.5 + 5 + (pad or CONFIG.ProtWedgePad)
        local inside = r > -6 and r < CONFIG.ProtWedgeLength and math.abs(lat) < half
        return inside, r, lat
    end

    local oldOverlaps = HazardTracker.GetBodyOverlaps
    function HazardTracker:GetBodyOverlaps(position, yaw)
        local result = oldOverlaps(self, position, yaw)
        local st = self:GetProtectorWedge()
        if st and st.WedgePart then
            local pad = self.TightPadding and 1.3 or CONFIG.ProtWedgePad
            if self:IsInProtectorWedge(position, pad) then
                for _, part in ipairs(result) do
                    if part == st.WedgePart then
                        return result
                    end
                end
                local copy = table.clone(result)
                table.insert(copy, st.WedgePart)
                return copy
            end
        end
        return result
    end

    ---------------------------------------------------------------------------
    -- Lines + squares: one spot that is safe from the beams (and, if
    -- possible, between the square rings), close to the boss.
    ---------------------------------------------------------------------------
    function DodgeSolver:ComputeProtectorSpot(st, boss)
        local origin = st.Origin
        if not origin then
            local look = st.Look or flatten(boss.Root.CFrame.LookVector).Unit
            origin = boss.Root.Position + look * 25
        end

        local rays = {}
        for _, ray in ipairs(st.Rays or {}) do
            if ray.Parent then
                local d = flatten(ray.Position - origin)
                if d.Magnitude > 1 then
                    table.insert(rays, d.Unit)
                end
            end
        end
        if #rays < 6 then
            return nil
        end

        local angles = {}
        for _, d in ipairs(rays) do
            table.insert(angles, math.atan2(d.Z, d.X))
        end
        table.sort(angles)

        local look = st.Look
        local side = perpOf(look)
        local root = self.CharacterService.Root
        local rootPos = root.Position
        local bossPos = boss.Root.Position
        local speed = math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        local timeLeft = math.max(0.2, st.RaysAt + CONFIG.ProtRayImpact - os.clock())

        local function raySafe(q)
            for _, d in ipairs(rays) do
                if q:Dot(d) > -9.5 and math.abs(q:Dot(perpOf(d))) < CONFIG.ProtRayClear then
                    return false
                end
            end
            return true
        end

        local function squareSafe(q)
            local cheb = math.max(math.abs(q:Dot(look)), math.abs(q:Dot(side)))
            for k = 0, CONFIG.ProtSquareCount - 1 do
                local h = CONFIG.ProtSquareFirst + CONFIG.ProtSquareStep * k
                if math.abs(cheb - h) < CONFIG.ProtSquareHalf + CONFIG.ProtSquarePad then
                    return false
                end
            end
            return true
        end

        local candidates = {}
        local count = #angles
        for i = 1, count do
            local a1 = angles[i]
            local a2 = i < count and angles[i + 1] or (angles[1] + math.pi * 2)
            if a2 - a1 > math.rad(8) then
                local mid = (a1 + a2) * 0.5
                for _, offset in ipairs({ 0, -0.02, 0.02 }) do
                    local dir = Vector3.new(math.cos(mid + offset), 0, math.sin(mid + offset))
                    for dist = CONFIG.ProtRayMinDist, CONFIG.ProtRayMaxDist, 1 do
                        local q = dir * dist
                        if raySafe(q) then
                            local point = Vector3.new(origin.X + q.X, rootPos.Y, origin.Z + q.Z)
                            local travel = flatten(point - rootPos).Magnitude
                            local toBoss = flatten(point - bossPos).Magnitude
                            if toBoss >= 7 then
                                -- Close to the boss matters most: the stomp comes 3.6 s
                                -- later from this spot, and it is easy to dodge up close.
                                local score = travel * 0.8 + toBoss * 1.1
                                if toBoss > 35 then score += 40 end
                                if not squareSafe(q) then score += 60 end
                                if travel > speed * timeLeft + 2 then score += 200 end
                                if toBoss > CONFIG.DamageCastRange - 6 then score += 60 end
                                table.insert(candidates, { Point = point, Score = score, Travel = travel })
                            end
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            return a.Score < b.Score
        end)

        local checked = 0
        for _, c in ipairs(candidates) do
            if checked >= 12 then
                break
            end
            checked += 1
            local delta = flatten(c.Point - rootPos)
            local okGround = self.Geometry:HasGround(c.Point)
            local okStream = not self.Hazards:IsInActiveStream(c.Point)
            local okPath = delta.Magnitude < 1
                or self.Geometry:IsDirectionClear(delta.Unit, math.min(delta.Magnitude, 30), directionToYaw(delta.Unit))
            if okGround and okStream and okPath then
                return c.Point
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- Orbit (used before the stomp and whenever the boss is in reach)
    ---------------------------------------------------------------------------
    function DodgeSolver:GetProtectorOrbit(boss, targetYaw, urgency)
        local root = self.CharacterService.Root
        local toMe = flatten(root.Position - boss.Root.Position)
        local distance = toMe.Magnitude
        if distance < 0.5 then
            return nil
        end
        local out = toMe.Unit
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or out

        -- Rotate away from where the boss is facing.
        local now = os.clock()
        local cross = look.X * out.Z - look.Z * out.X
        local wanted = cross >= 0 and 1 or -1
        if not self.ProtOrbitSign or (now - (self.ProtOrbitFlipAt or 0) > 2.5 and wanted ~= self.ProtOrbitSign and out:Dot(look) > 0.2) then
            if self.ProtOrbitSign ~= wanted then
                self.ProtOrbitFlipAt = now
            end
            self.ProtOrbitSign = wanted
        end

        local radial = math.clamp((distance - CONFIG.ProtOrbitRadius) / 6, -1, 1)
        for attempt = 1, 2 do
            local sign = self.ProtOrbitSign
            local tangent = Vector3.new(-out.Z, 0, out.X) * sign
            local dir = unit(tangent * (urgency or 1) - out * radial * 0.8)
            local yaw = directionToYaw(dir)
            if self.Geometry:IsDirectionClear(dir, 6, yaw)
                and self.Geometry:HasGround(root.Position + dir * 5)
                and self.Hazards:IsTrajectoryClear(root.Position, dir, targetYaw, 5)
            then
                return dir
            end
            if attempt == 1 and now - (self.ProtOrbitFlipAt or 0) > 0.6 then
                self.ProtOrbitSign = -sign
                self.ProtOrbitFlipAt = now
            else
                break
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- v44.10: no constant spinning. Keep beside the boss (outside the line he
    -- faces) and only move when he turns toward us or the stomp is due.
    ---------------------------------------------------------------------------
    CONFIG.ProtCycle = 15.65
    CONFIG.ProtStompLead = 1.2          -- start stepping aside this long before the stomp
    CONFIG.ProtStompTail = 0.6
    CONFIG.ProtStompSafeAngle = 100     -- degrees from the boss's facing that count as safe
    CONFIG.ProtStompGoalAngle = 118
    CONFIG.ProtSideSafeAngle = 65       -- outside the stomp window
    CONFIG.ProtSideGoalAngle = 95
    CONFIG.ProtSideRadius = 18
    CONFIG.ProtSideMin = 11
    CONFIG.ProtAimLockLead = 1.35       -- fallback when the aim snap is not seen
    CONFIG.ProtStompClear = 2.2         -- margin outside the wave edge

    function DodgeSolver:GetPredictedStomp(st, now)
        local base = st.RaysAt
        if not base and st.SquaresAt then
            base = st.SquaresAt - 1.47
        end
        if not base then
            return nil
        end
        local predicted = base + CONFIG.ProtWedgeDelay
        -- Rays missed this cycle: keep counting from the last one.
        while predicted + CONFIG.ProtStompTail < now and now - base < CONFIG.ProtCycle * 4 do
            predicted += CONFIG.ProtCycle
        end
        -- A wave already fired for this prediction.
        if st.WedgeAt and math.abs(st.WedgeAt - predicted) < 2 and now > st.WedgeAt + 0.2 then
            return nil
        end
        return predicted
    end

    -- Returns a move direction, Vector3.zero when already safe (hold), or nil.
    function DodgeSolver:GetProtectorSideStep(boss, targetYaw, safeAngle, goalAngle)
        local root = self.CharacterService.Root
        local toMe = flatten(root.Position - boss.Root.Position)
        local distance = toMe.Magnitude
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)
        local out = distance > 0.5 and toMe.Unit or -look
        local theta = math.deg(math.acos(math.clamp(out:Dot(look), -1, 1)))
        self.ProtFacingAngle = theta

        if theta >= safeAngle and distance <= CONFIG.ProtOrbitMax then
            return Vector3.zero
        end

        local cross = look.X * out.Z - look.Z * out.X
        local preferred = cross >= 0 and 1 or -1
        local radius = math.clamp(distance, CONFIG.ProtSideMin, CONFIG.ProtSideRadius)

        for attempt = 1, 2 do
            local sign = attempt == 1 and preferred or -preferred
            local goal = boss.Root.Position + rotateXZ(look, sign * goalAngle) * radius
            goal = Vector3.new(goal.X, root.Position.Y, goal.Z)
            local delta = flatten(goal - root.Position)
            if delta.Magnitude < 1 then
                return Vector3.zero
            end
            local dir = delta.Unit
            local probe = math.min(delta.Magnitude, 8)
            local ahead = root.Position + dir * math.min(delta.Magnitude, 4)
            if self.Geometry:IsDirectionClear(dir, probe, directionToYaw(dir))
                and self.Geometry:HasGround(ahead)
                and not self.Hazards:IsInActiveStream(ahead)
                and self.Hazards:GetOverlapCountAt(ahead, targetYaw) == 0
            then
                return dir
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- Planner
    ---------------------------------------------------------------------------
    function DodgeSolver:ProtectorPlan(boss, targetYaw)
        local st = self.Hazards.ProtState
        local root = self.CharacterService.Root
        local now = os.clock()
        if not st then
            return nil
        end

        -- Track the boss's facing to catch the aim snap before the stomp.
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)
        local snapped = false
        if self.ProtLastLook and now - (self.ProtLastLookAt or 0) < 0.35 then
            local turn = math.deg(math.acos(math.clamp(look:Dot(self.ProtLastLook), -1, 1)))
            snapped = turn > 6
        end
        self.ProtLastLook = look
        self.ProtLastLookAt = now

        -- 1) Stomp wave on screen and we are in its cone: get out sideways
        --    (or behind the boss when that is shorter).
        local inside, r, lat = self.Hazards:IsInProtectorWedge(root.Position, 1.6)
        if inside then
            local d = st.WedgeDir
            local p = perpOf(d)
            local sideSign = lat >= 0 and 1 or -1
            local options = {
                { Dir = unit(p * sideSign - d * 0.35), Need = (math.max(r, 0) * 0.5 + 6.6 - math.abs(lat)) },
                { Dir = unit(-d + p * sideSign * 0.3), Need = r + 7.6 },
                { Dir = unit(p * sideSign + d * 0.2), Need = (math.max(r, 0) * 0.5 + 6.6 - math.abs(lat)) * 1.1 },
            }
            table.sort(options, function(a, b) return a.Need < b.Need end)
            for _, o in ipairs(options) do
                local yaw = directionToYaw(o.Dir)
                if self.Geometry:IsDirectionClear(o.Dir, math.clamp(o.Need, 3, 12), yaw)
                    and self.Geometry:HasGround(root.Position + o.Dir * 4)
                then
                    return o.Dir, "stomp-exit"
                end
            end
            return unit(p * sideSign), "stomp-exit"
        end

        -- 2) Lines + squares window: go to the planned spot and stand still.
        if st.RaysAt and now - st.RaysAt <= CONFIG.ProtHoldUntil then
            if not st.Plan and now - (st.PlanAt or 0) > 0.12 then
                st.PlanAt = now
                st.Plan = self:ComputeProtectorSpot(st, boss)
                st.PlanTries = (st.PlanTries or 0) + 1
            end
            if st.Plan then
                local delta = flatten(st.Plan - root.Position)
                self.SelectedAuraPoint = st.Plan
                if delta.Magnitude <= 0.9 then
                    return Vector3.zero, "lines-hold"
                end
                return delta.Unit * math.clamp(delta.Magnitude / 2.5, 0.4, 1), "lines-spot"
            end
            return nil
        end

        -- 3) Stomp wave is due. Measured live: about 1.4 s before the wave the
        --    boss snaps to face the player and that aim is locked. Right after
        --    the snap, walk straight out sideways of the locked line.
        local predicted = self:GetPredictedStomp(st, now)
        if predicted then
            local untilStomp = predicted - now
            if snapped and untilStomp < 2.4 and untilStomp > -0.4 then
                st.AimFor = predicted
                st.AimLook = look
            end
            local locked = st.AimFor == predicted or untilStomp <= CONFIG.ProtAimLockLead
            if locked and untilStomp <= 2.4 and untilStomp >= -CONFIG.ProtStompTail then
                local d = (st.AimFor == predicted and st.AimLook) or look
                local v = flatten(root.Position - boss.Root.Position)
                local r = v:Dot(d)
                local lat = v:Dot(perpOf(d))
                local need = math.max(r, 0) * 0.5 + 5 + CONFIG.ProtStompClear
                if r < -7 or math.abs(lat) >= need then
                    return Vector3.zero, "stomp-safe"
                end
                local sign = lat >= 0 and 1 or -1
                if math.abs(lat) < 1.5 and self.ProtStompSide then
                    sign = self.ProtStompSide
                end
                for attempt = 1, 2 do
                    local s = attempt == 1 and sign or -sign
                    local dir = unit(perpOf(d) * s - d * (r > 30 and 0.25 or 0))
                    if self.Geometry:IsDirectionClear(dir, 8, directionToYaw(dir))
                        and self.Geometry:HasGround(root.Position + dir * 5)
                    then
                        self.ProtStompSide = s
                        return dir, "stomp-sidestep"
                    end
                end
                return unit(perpOf(d) * sign), "stomp-sidestep"
            end
        end

        return nil
    end

    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if isProtector(enemy) and not self.ForceRouteMovement and self.CharacterService:IsAlive() then
            self.CurrentSolveEnemy = enemy
            local ok, dir, reason = pcall(self.ProtectorPlan, self, enemy, targetYaw)
            if ok and dir then
                local now = os.clock()
                self.LastSolve = now
                self.LastDodgeReason = reason
                self.IsDodging = true
                self.CachedDirection, self.CachedYaw = dir, targetYaw
                self.CachedEmergency, self.CachedDodging = false, true
                self.CommittedDodgeDirection = Vector3.zero
                self.DodgeCommitUntil = 0
                if dir.Magnitude > 0 then
                    self.LastMovement = dir
                end
                return dir, targetYaw, false, true
            elseif not ok then
                self.ProtPlanError = tostring(dir)
            end
        end
        return oldSolve(self, routeDirection, enemy, targetYaw)
    end

    -- Close to the Protector: stay beside him and attack; only move when he
    -- turns to face us.
    local oldPreferred = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        local result = oldPreferred(self, routeDirection, enemy, targetYaw)
        if not isProtector(enemy) or self.ForceRouteMovement or self.TargetBlocked then
            return result
        end
        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance <= CONFIG.ProtOrbitMax and distance >= 3 then
            self.AttackHolding = false
            self.TravelMode = false
            local dir = self:GetProtectorSideStep(enemy, targetYaw, CONFIG.ProtSideSafeAngle, CONFIG.ProtSideGoalAngle)
            if dir then
                self.AttackHolding = dir.Magnitude <= 0
                return dir
            end
        end
        return result
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.10"
        return self
    end
end

