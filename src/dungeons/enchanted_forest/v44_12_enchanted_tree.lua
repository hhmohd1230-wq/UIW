-- v44.12: Enchanted Forest - Ancient Enchanted Tree (measured live):
--   * the tree sits behind a water moat (water from ~55 to ~90 studs); the
--     closest ground ring is ~90-100 studs from its center, so the old code
--     never got in cast range and dealt 0 damage
--   * Enchanted Sweeper: 2 diameter lasers (450 long, 1.5 thick) through the
--     tree, perpendicular, still for ~0.7 s, then rotating ~10 deg/s; each
--     touch ticks ~90M every 0.1 s
do
    CONFIG.TreeRingMin = 80
    CONFIG.TreeRingMax = 150
    CONFIG.TreeRingStep = 3
    CONFIG.TreeRingAngles = 36
    CONFIG.TreeStandExtra = 4
    CONFIG.TreeRadiusCap = 45
    CONFIG.TreeSweeperSync = 1.6          -- how hard to pull toward the middle of the gap
    CONFIG.TreeSweeperClear = 2.6         -- studs from a laser line counted as touching
    CONFIG.TreeSweeperRange = 240

    local function isTree(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient enchanted tree"
            and enemy.Root and enemy.Root.Parent
    end

    local TWO_PI = math.pi * 2
    local function wrap(a)
        a = a % TWO_PI
        if a < 0 then a += TWO_PI end
        return a
    end

    ---------------------------------------------------------------------------
    -- Ground ring around the moat
    ---------------------------------------------------------------------------
    function UIWController:ScanTreeRing(tree)
        local center = tree.Root.Position
        local root = self.Character.Root
        local floorY = root.Position.Y - 3
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false
        local ignore = { self.Character.Character, tree.Model }
        for _, name in ipairs({ "UIW_HitboxESP", "UIW_PathESP", "UIW_TacticalDisplay", "UIW_AvoidZones", "enemies" }) do
            local f = Workspace:FindFirstChild(name)
            if f then table.insert(ignore, f) end
        end
        local ring = {}
        for i = 0, CONFIG.TreeRingAngles - 1 do
            local angle = i / CONFIG.TreeRingAngles * TWO_PI
            local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local found = nil
            for r = CONFIG.TreeRingMin, CONFIG.TreeRingMax, CONFIG.TreeRingStep do
                local p = center + dir * r
                local localIgnore = table.clone(ignore)
                local hit
                for _ = 1, 4 do
                    params.FilterDescendantsInstances = localIgnore
                    hit = Workspace:Raycast(Vector3.new(p.X, floorY + 40, p.Z), Vector3.new(0, -90, 0), params)
                    if hit and hit.Instance ~= Workspace.Terrain
                        and (hit.Instance.Name == "hitBox" or hit.Instance.Name == "precast"
                            or hit.Instance.Transparency >= 0.9 or not hit.Instance.CanCollide)
                    then
                        table.insert(localIgnore, hit.Instance)
                    else
                        break
                    end
                end
                if hit and hit.Material ~= Enum.Material.Water and math.abs(hit.Position.Y - floorY) <= 8 then
                    found = r
                    break
                end
            end
            ring[i + 1] = { Angle = angle, R = found }
        end
        self.TreeRing = { Model = tree.Model, Center = center, Ring = ring, At = os.clock() }
        return self.TreeRing
    end

    function UIWController:GetTreeStandPoint(tree)
        local info = self.TreeRing
        local root = self.Character.Root
        local closeEnough = flatten(root.Position - tree.Root.Position).Magnitude <= 170
        if not info or info.Model ~= tree.Model or (os.clock() - info.At > 60 and closeEnough) then
            if closeEnough or not info or info.Model ~= tree.Model then
                local previous = info
                info = self:ScanTreeRing(tree)
                local valid = 0
                for _, slot in ipairs(info.Ring) do
                    if slot.R then valid += 1 end
                end
                if valid < 3 and previous and previous.Model == tree.Model then
                    -- Scanned from the wrong height (e.g. right after respawn): keep the old ring.
                    previous.At = os.clock()
                    self.TreeRing = previous
                    info = previous
                elseif valid < 3 then
                    self.TreeRing = nil
                    return nil
                end
            end
        end
        local rel = flatten(root.Position - info.Center)
        local phi = wrap(math.atan2(rel.Z, rel.X))
        local best, bestCost = nil, math.huge
        for _, slot in ipairs(info.Ring) do
            if slot.R then
                local diff = math.abs(wrap(slot.Angle - phi + math.pi) - math.pi)
                local cost = diff * rel.Magnitude + slot.R * 0.3
                if cost < bestCost then
                    best, bestCost = slot, cost
                end
            end
        end
        if not best then
            return nil
        end
        local r = best.R + CONFIG.TreeStandExtra
        -- Stay on our own bearing when the ring there is known and close.
        local angle = best.Angle
        local p = info.Center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r
        return Vector3.new(p.X, root.Position.Y, p.Z), r
    end

    function CombatController:GetTreeRadius(enemy)
        local now = os.clock()
        if self.TreeRadiusModel == enemy.Model and now - (self.TreeRadiusAt or 0) < 10 then
            return self.TreeRadius
        end
        local radius = 30
        local ok, size = pcall(enemy.Model.GetExtentsSize, enemy.Model)
        if ok and size then
            radius = math.min(size.X, size.Z) * 0.5
        end
        self.TreeRadius = math.min(radius, CONFIG.TreeRadiusCap)
        self.TreeRadiusModel = enemy.Model
        self.TreeRadiusAt = now
        return self.TreeRadius
    end

    -- Casting reaches the tree's body, not its center.
    local oldUpdate = CombatController.Update
    function CombatController:Update(enemy)
        if isTree(enemy) then
            local base = CONFIG.DamageCastRange
            local width = CONFIG.CastHitboxWidth
            local radius = self:GetTreeRadius(enemy)
            CONFIG.DamageCastRange = base + radius
            -- The tree is ~80 studs wide: aiming a few degrees off still hits.
            CONFIG.CastHitboxWidth = width + radius * 2.5
            local ok, result = pcall(oldUpdate, self, enemy)
            CONFIG.DamageCastRange = base
            CONFIG.CastHitboxWidth = width
            if not ok then error(result, 0) end
            return result
        end
        return oldUpdate(self, enemy)
    end

    local oldGoal = UIWController.GetGoal
    function UIWController:GetGoal()
        local enemy = self.CurrentEnemy
        if isTree(enemy) and self.Character:IsAlive() then
            local mechanic = self:GetPriorityMechanicGoal()
            if mechanic then
                return mechanic
            end
            local ok, point = pcall(self.GetTreeStandPoint, self, enemy)
            if ok and point then
                self.TreeStandGoal = point
                return point
            end
        end
        self.TreeStandGoal = nil
        return oldGoal(self)
    end

    ---------------------------------------------------------------------------
    -- Spinning lasers
    ---------------------------------------------------------------------------
    function HazardTracker:TrackTreeLaser(model)
        if not model or model.Name ~= "secondBossSpinningLaserHitbox" then
            return
        end
        self.TreeLasers = self.TreeLasers or {}
        if self.TreeLasers[model] then
            return
        end
        task.defer(function()
            local part = model:FindFirstChild("hitBox") or model:FindFirstChildWhichIsA("BasePart")
            if part then
                self.TreeLasers[model] = { Part = part, Born = os.clock() }
            end
        end)
    end

    function HazardTracker:GetTreeLasers()
        local list = {}
        local now = os.clock()
        for model, info in pairs(self.TreeLasers or {}) do
            local part = info.Part
            if not model.Parent or not part.Parent then
                self.TreeLasers[model] = nil
            else
                local size = part.Size
                local axis = size.X >= size.Z and part.CFrame.RightVector or part.CFrame.LookVector
                axis = flatten(axis)
                if axis.Magnitude > 0 then
                    axis = axis.Unit
                    local angle = math.atan2(axis.Z, axis.X)
                    if info.LastAngle and now - info.LastAt >= 0.08 then
                        local d = (angle - info.LastAngle) % math.pi
                        if d > math.pi / 2 then d -= math.pi end
                        local w = d / (now - info.LastAt)
                        info.Omega = info.Omega and (info.Omega * 0.6 + w * 0.4) or w
                        if math.abs(w) >= math.rad(0.8) then
                            info.HadMotion = true
                            info.LastMotionAt = now
                        end
                        info.LastAngle, info.LastAt = angle, now
                    elseif not info.LastAngle then
                        info.LastAngle, info.LastAt = angle, now
                    end
                    -- These invisible models can remain in Workspace after the
                    -- rotating damage has stopped.  Retire the tracker after a
                    -- measured spin becomes stationary instead of dodging the
                    -- stale hitbox until Roblox eventually destroys the model.
                    local retired = info.HadMotion
                        and now - (info.LastMotionAt or now) >= 0.85
                    if retired then
                        info.Retired = true
                        self.TreeLasers[model] = nil
                        local full = self.FullHazards or self.Hazards
                        full[part] = nil
                        if self.NearHazards then self.NearHazards[part] = nil end
                    elseif not info.Retired then
                        table.insert(list, {
                            Part = part,
                            Center = part.Position,
                            Axis = axis,
                            Angle = angle,
                            Omega = info.Omega or 0,
                            HalfLength = math.max(size.X, size.Z) * 0.5,
                        })
                    end
                end
            end
        end
        return list
    end

    function HazardTracker:GetTreeLaserHit(position, clearance)
        for _, laser in ipairs(self.TreeLaserCache or {}) do
            if laser.Part.Parent then
                local v = flatten(position - laser.Center)
                local along = math.abs(v:Dot(laser.Axis))
                local across = math.abs(v.X * laser.Axis.Z - v.Z * laser.Axis.X)
                if along <= laser.HalfLength and across <= clearance then
                    return laser.Part
                end
            end
        end
        return nil
    end

    local oldRefreshLasers = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local before = self.LastCacheTime
        oldRefreshLasers(self, force)
        if self.LastCacheTime ~= before and self.TreeLasers and next(self.TreeLasers) then
            self.TreeLaserCache = self:GetTreeLasers()
        elseif not self.TreeLasers or not next(self.TreeLasers) then
            self.TreeLaserCache = nil
        end
    end

    local oldOverlapsLaser = HazardTracker.GetBodyOverlaps
    function HazardTracker:GetBodyOverlaps(position, yaw)
        local result = oldOverlapsLaser(self, position, yaw)
        if self.TreeLaserCache and #self.TreeLaserCache > 0 then
            local clearance = self.TightPadding and 1.8 or CONFIG.TreeSweeperClear
            local part = self:GetTreeLaserHit(position, clearance)
            if part then
                for _, p in ipairs(result) do
                    if p == part then return result end
                end
                local copy = table.clone(result)
                table.insert(copy, part)
                return copy
            end
        end
        return result
    end

    -- Ride along with the rotating cross in the middle of a gap, choosing a
    -- velocity that is also clear of the circles / lines that come with it.
    local function laserClearance(lasers, omega, pivot, position, dt)
        local rel = flatten(position - pivot)
        local R = rel.Magnitude
        if R < 1 then
            return 0
        end
        local phi = math.atan2(rel.Z, rel.X)
        local best = math.huge
        for _, laser in ipairs(lasers) do
            local theta = laser.Angle + omega * dt
            local d = math.abs(((phi - theta) % math.pi))
            d = math.min(d, math.pi - d)
            best = math.min(best, math.sin(d) * R)
        end
        return best
    end

    function DodgeSolver:GetTreeSweeperMove(boss, targetYaw)
        self.TreeSweeperUrgent = false
        local lasers = self.Hazards.TreeLaserCache
        if not lasers or #lasers == 0 then
            return nil
        end
        local root = self.CharacterService.Root
        local origin = root.Position
        local pivot = lasers[1].Center
        local rel = flatten(origin - pivot)
        local R = rel.Magnitude
        if R < 1 or R > CONFIG.TreeSweeperRange then
            return nil
        end
        local phi = wrap(math.atan2(rel.Z, rel.X))

        local angles, omega = {}, 0
        for _, laser in ipairs(lasers) do
            table.insert(angles, wrap(laser.Angle))
            table.insert(angles, wrap(laser.Angle + math.pi))
            omega += laser.Omega
        end
        omega /= #lasers
        table.sort(angles)

        local lower, upper = angles[#angles] - TWO_PI, angles[1]
        for i = 1, #angles do
            local a = angles[i]
            local b = i < #angles and angles[i + 1] or angles[1] + TWO_PI
            local p = phi
            if p < a then p += TWO_PI end
            if p >= a and p < b then
                lower, upper = a, b
                phi = p
                break
            end
        end
        local mid = (lower + upper) * 0.5

        local speed = math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        local tangent = Vector3.new(-math.sin(phi), 0, math.cos(phi))
        local out = rel.Unit

        local tangential = (omega + math.clamp((mid - phi) * CONFIG.TreeSweeperSync, -1.2, 1.2)) * R
        local radial = 0
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - pivot).Magnitude or R
        if R > standR + 6 then
            radial = -speed * 0.78
            tangential = math.clamp(tangential, -speed * 0.6, speed * 0.6)
        else
            radial = math.clamp((standR - R) * 1.2, -speed * 0.5, speed * 0.5)
        end
        tangential = math.clamp(tangential, -speed, speed)
        local base = tangent * tangential + out * radial
        local baseSpeed = math.min(base.Magnitude, speed)
        local baseDir = base.Magnitude > 0.3 and base.Unit or tangent

        local best, bestScore = nil, -math.huge
        local nowClear = laserClearance(lasers, omega, pivot, origin, 0)
        for _, offset in ipairs({ 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150, 180 }) do
            for _, scale in ipairs({ 1, 0.55 }) do
                local dir = unit(rotateXZ(baseDir, offset))
                local v = dir * math.max(baseSpeed, 6) * scale
                if offset ~= 0 then
                    v = dir * speed * scale
                end
                local p1 = origin + v * 0.35
                local p2 = origin + v * 0.7
                local r2 = flatten(p2 - pivot).Magnitude
                if r2 >= standR - 5 then
                    local clear = math.min(
                        laserClearance(lasers, omega, pivot, p1, 0.35),
                        laserClearance(lasers, omega, pivot, p2, 0.7)
                    )
                    local laserOk = clear >= CONFIG.TreeSweeperClear + 1.2
                    local reach = math.min(v.Magnitude * 0.7, 9)
                    local hazardOk = reach < 1 or self.Hazards:IsTrajectoryClear(origin, dir, targetYaw, reach)
                    local endFree = self.Hazards:GetOverlapCountAt(p2, targetYaw) == 0
                    local score = (laserOk and 1000 or clear * 50)
                        + (hazardOk and 200 or 0)
                        + (endFree and 300 or 0)
                        - math.abs(offset) * 0.6
                        - (1 - scale) * 15
                        + math.min(clear, 20)
                        - math.abs(r2 - standR) * 1.5
                    if score > bestScore
                        and self.Geometry:IsDirectionClear(dir, math.max(reach, 3), directionToYaw(dir))
                    then
                        best, bestScore = v, score
                    end
                end
            end
        end

        self.TreeSweeperUrgent = nowClear < CONFIG.TreeSweeperClear + 4
        if not best then
            return nil
        end
        return best / speed
    end

    local oldSolveTree = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if isTree(enemy) and not self.ForceRouteMovement and self.CharacterService:IsAlive() then
            local ok, dir = pcall(self.GetTreeSweeperMove, self, enemy, targetYaw)
            if ok and dir then
                local unitDir = dir.Magnitude > 0 and dir.Unit or Vector3.zero
                do
                    local now = os.clock()
                    self.CurrentSolveEnemy = enemy
                    self.LastSolve = now
                    self.LastDodgeReason = "tree-sweeper"
                    self.IsDodging = true
                    self.CachedDirection, self.CachedYaw = dir, targetYaw
                    self.CachedEmergency, self.CachedDodging = false, true
                    self.CommittedDodgeDirection = Vector3.zero
                    self.DodgeCommitUntil = 0
                    if dir.Magnitude > 0 then self.LastMovement = unitDir end
                    return dir, targetYaw, false, true
                end
            elseif not ok then
                self.TreePlanError = tostring(dir)
            end
        end
        return oldSolveTree(self, routeDirection, enemy, targetYaw)
    end

    -- Dodges around the tree: slide along the shore (stay in range) instead
    -- of running away from it.
    local oldAttackDodge = DodgeSolver.FindBossAttackDodge
    function DodgeSolver:FindBossAttackDodge(enemy, targetYaw)
        if not isTree(enemy) then
            return oldAttackDodge(self, enemy, targetYaw)
        end
        local root = self.CharacterService.Root
        local origin = root.Position
        local rel = flatten(origin - enemy.Root.Position)
        if rel.Magnitude < 1 then
            return nil
        end
        local out = rel.Unit
        local tangent = Vector3.new(-out.Z, 0, out.X)
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - enemy.Root.Position).Magnitude or rel.Magnitude
        local reach = CONFIG.DamageCastRange + CONFIG.TreeRadiusCap - 2
        local best, bestScore = nil, -math.huge
        for _, side in ipairs({ 1, -1 }) do
            for _, inward in ipairs({ 0.35, 0, -0.25 }) do
                local dir = unit(tangent * side - out * inward)
                local point = origin + dir * CONFIG.DodgeDistance
                local pr = flatten(point - enemy.Root.Position).Magnitude
                local R = rel.Magnitude
                if pr <= math.max(reach, R - 2) and pr >= standR - 6 and self.Geometry:HasGround(point) then
                    local safety = self:ScoreCandidate(dir, dir, targetYaw)
                    if safety then
                        local score = safety - math.abs(pr - standR) * 20
                        if self.LastMovement.Magnitude > 0 then
                            score += dir:Dot(self.LastMovement) * 30
                        end
                        if score > bestScore then
                            best, bestScore = dir, score
                        end
                    end
                end
            end
        end
        return best
    end

    -- Near the tree: go to the stand ring and hold there while casting.
    local oldPreferredTree = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        if isTree(enemy) and not self.ForceRouteMovement then
            local stand = self.Owner and self.Owner.TreeStandGoal
            if stand then
                local delta = flatten(stand - self.CharacterService.Root.Position)
                self.TravelMode = delta.Magnitude > 40
                self.AttackHolding = delta.Magnitude <= 3
                if delta.Magnitude <= 3 then
                    return Vector3.zero
                end
                local route = unit(flatten(routeDirection))
                if route.Magnitude > 0 then
                    return route
                end
                return delta.Unit
            end
        end
        return oldPreferredTree(self, routeDirection, enemy, targetYaw)
    end

    local oldNewTree = UIWController.new
    function UIWController.new()
        local self = oldNewTree()
        self.Version = "44.12"
        local hazards = self.Hazards
        for _, child in ipairs(Workspace:GetChildren()) do
            hazards:TrackTreeLaser(child)
        end
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if child.Name == "secondBossSpinningLaserHitbox" then
                hazards:TrackTreeLaser(child)
            end
        end))
        return self
    end
end

