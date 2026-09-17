-- v44.19: Crystal Golem electrical sweepers.
--
-- The old handler only inspected Workspace:FindFirstChild(), so two of the
-- three same-named geode attacks could be ignored.  It also moved around the
-- boss, although each electrical cross rotates around its own landed geode.
-- Track every live hitbox, measure its real angular velocity, and choose a
-- movement vector that remains inside a predicted rotating gap.
do
    CONFIG.GolemSpinnerClearance = 4.5
    CONFIG.GolemSpinnerLookahead = 0.95
    CONFIG.GolemSpinnerRange = 180
    CONFIG.GolemSpinnerAngles = 24
    CONFIG.GolemSpinnerInactiveGrace = 0.85
    CONFIG.GolemSafeHoldGrace = 0.65

    local PI = math.pi

    local function rotateVectorXZ(vector, radians)
        local cosine = math.cos(radians)
        local sine = math.sin(radians)
        return Vector3.new(
            vector.X * cosine - vector.Z * sine,
            vector.Y,
            vector.X * sine + vector.Z * cosine
        )
    end

    local function signedLineAngleDelta(current, previous)
        return (current - previous + PI * 0.5) % PI - PI * 0.5
    end

    function HazardTracker:GetCrystalGolemSweepers()
        local now = os.clock()
        local tracks = self.GolemSweeperTracks or {}
        local live = {}
        local result = {}

        for _, model in ipairs(Workspace:GetChildren()) do
            if string.lower(model.Name or "") == "firstbossspinningrockhitbox" then
                local ok, pivotCFrame = pcall(model.GetPivot, model)
                local pivot = ok and pivotCFrame.Position or nil

                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") and string.lower(part.Name or "") == "hitbox" then
                        live[part] = true

                        local size = part.Size
                        local longIsX = size.X >= size.Z
                        local axis = flatten(longIsX and part.CFrame.RightVector or part.CFrame.LookVector)

                        if axis.Magnitude > 0.01 then
                            axis = axis.Unit
                            local angle = math.atan2(axis.Z, axis.X)
                            local info = tracks[part] or {
                                Angle = angle,
                                At = now,
                                Omega = 0,
                                BornAt = now,
                                LastPosition = part.Position,
                            }
                            local dt = now - (info.At or now)

                            if dt >= 0.025 then
                                local measured = signedLineAngleDelta(angle, info.Angle or angle) / dt
                                local moved = flatten(part.Position - (info.LastPosition or part.Position)).Magnitude
                                if math.abs(measured) < math.rad(240) then
                                    info.Omega = (info.Omega or 0) * 0.55 + measured * 0.45
                                    if math.abs(info.Omega) < math.rad(0.35) then
                                        info.Omega = 0
                                    end
                                end
                                if math.abs(measured) >= math.rad(0.8) or moved >= 0.035 then
                                    info.HadMotion = true
                                    info.LastMotionAt = now
                                end
                                info.Angle = angle
                                info.At = now
                                info.LastPosition = part.Position
                            end

                            info.Part = part
                            info.Model = model
                            info.Center = part.Position
                            info.Pivot = pivot or part.Position
                            info.PivotOffset = flatten(part.Position - info.Pivot)
                            info.HalfLength = (longIsX and size.X or size.Z) * 0.5
                            info.HalfWidth = (longIsX and size.Z or size.X) * 0.5
                            tracks[part] = info

                            -- The model lives for about ten seconds, but its
                            -- invisible hitbox can remain after the damaging
                            -- rotation has stopped.  Once real motion has been
                            -- observed, stationary time is proof that this cast
                            -- is finished.  Retire it locally instead of letting
                            -- a stale part keep the dodge solver active.
                            if info.HadMotion
                                and now - (info.LastMotionAt or now) >= CONFIG.GolemSpinnerInactiveGrace
                            then
                                info.Retired = true
                                local full = self.FullHazards or self.Hazards
                                full[part] = nil
                                if self.NearHazards then self.NearHazards[part] = nil end
                            end

                            if not info.Retired then
                                table.insert(result, info)
                            end
                        end
                    end
                end
            end
        end

        for part in pairs(tracks) do
            if not live[part] or not part.Parent then
                tracks[part] = nil
            end
        end

        self.GolemSweeperTracks = tracks
        return result
    end

    local function sweeperClearance(laser, position, dt)
        local rotation = (laser.Omega or 0) * dt
        local axis = Vector3.new(math.cos(laser.Angle + rotation), 0, math.sin(laser.Angle + rotation))
        local center = laser.Pivot + rotateVectorXZ(laser.PivotOffset, rotation)
        local relative = flatten(position - center)
        local along = math.abs(relative:Dot(axis))
        local across = math.abs(relative.X * axis.Z - relative.Z * axis.X)
        local beyondEnd = math.max(along - laser.HalfLength, 0)
        local beyondSide = math.max(across - laser.HalfWidth, 0)

        if beyondEnd > 0 then
            return math.sqrt(beyondEnd * beyondEnd + beyondSide * beyondSide)
        end
        return across - laser.HalfWidth
    end

    local function minimumSweeperClearance(lasers, position, dt)
        local best = math.huge
        for _, laser in ipairs(lasers) do
            best = math.min(best, sweeperClearance(laser, position, dt))
        end
        return best
    end

    function DodgeSolver:GetCrystalGolemSpinnerMove(routeDirection, enemy, targetYaw)
        if not enemy or not enemy.Model or normalizeEnemyName(enemy.Model.Name) ~= "crystal golem"
            or not self.CharacterService:IsAlive()
        then
            return nil
        end

        local lasers = self.Hazards:GetCrystalGolemSweepers()
        if #lasers == 0 then
            self.GolemSpinnerUrgent = false
            return nil
        end

        local root = self.CharacterService.Root
        local origin = root.Position
        local inRange = false
        for _, laser in ipairs(lasers) do
            if flatten(origin - laser.Pivot).Magnitude <= CONFIG.GolemSpinnerRange then
                inRange = true
                break
            end
        end
        if not inRange then
            self.GolemSpinnerUrgent = false
            return nil
        end

        local humanoid = self.CharacterService.Humanoid
        local speed = math.max(humanoid and humanoid.WalkSpeed or 16, 8)
        local route = unit(flatten(routeDirection or Vector3.zero))
        local samples = { 0.16, 0.34, 0.56, CONFIG.GolemSpinnerLookahead }
        local stillClear = math.huge
        for _, dt in ipairs(samples) do
            stillClear = math.min(stillClear, minimumSweeperClearance(lasers, origin, dt))
        end

        local currentClear = minimumSweeperClearance(lasers, origin, 0)
        local urgent = currentClear < CONFIG.GolemSpinnerClearance + 5
            or stillClear < CONFIG.GolemSpinnerClearance + 2
        self.GolemSpinnerUrgent = urgent

        -- Once the crystal has put us in a real safe bubble / wall, do not let
        -- the rotating-gap planner walk us back out merely to improve its
        -- score.  Leaving is allowed only when damage is actually reaching the
        -- held spot, which covers the rare case where a sweeper crosses it.
        local holdingRegion = self.ForcedRegionPart
            and self:IsPointInsideForcedRegion(origin)
        local damageInRegion = currentClear < CONFIG.GolemSpinnerClearance
            or self.Hazards:GetOverlapCountAt(origin, targetYaw) > 0
        if holdingRegion and not damageInRegion then
            self.GolemSafeSpotHolding = true
            self.GolemSpinnerUrgent = false
            return Vector3.zero, false
        end
        self.GolemSafeSpotHolding = false

        local bestMove = nil
        local bestScore = -math.huge
        local bestSafe = false

        local function consider(direction, scale)
            local moving = direction.Magnitude > 0.05
            local velocity = moving and direction.Unit * speed * scale or Vector3.zero
            local reach = math.min(velocity.Magnitude * 0.55, 10)

            if moving and not self.Geometry:IsDirectionClear(direction.Unit, math.max(reach, 3), directionToYaw(direction)) then
                return
            end

            local minimum = math.huge
            local finalClear = math.huge
            local endpoint = origin
            for _, dt in ipairs(samples) do
                endpoint = origin + velocity * dt
                local clearance = minimumSweeperClearance(lasers, endpoint, dt)
                minimum = math.min(minimum, clearance)
                finalClear = clearance
            end

            local safe = minimum >= CONFIG.GolemSpinnerClearance
            local score = (safe and 100000 or 0)
                + math.min(minimum, 30) * 900
                + math.min(finalClear, 35) * 120
                + self:GetBossBandScore(origin, endpoint) * 0.35

            if route.Magnitude > 0 and moving then
                score += velocity.Unit:Dot(route) * (safe and 95 or 25)
            end

            if moving then
                score -= self.Hazards:GetOverlapCountAt(endpoint, targetYaw) * 350
                if self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding) then
                    score += 180
                else
                    score -= 1200
                end
            elseif urgent then
                score -= 450
            else
                score += 40
            end

            if (safe and not bestSafe) or safe == bestSafe and score > bestScore then
                bestSafe = safe
                bestScore = score
                bestMove = moving and velocity / speed or Vector3.zero
            end
        end

        consider(Vector3.zero, 0)
        for index = 0, CONFIG.GolemSpinnerAngles - 1 do
            local angle = index / CONFIG.GolemSpinnerAngles * PI * 2
            local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
            consider(direction, 1)
            consider(direction, 0.58)
        end

        return bestMove, urgent
    end

    local oldSolveGolemSpinner = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local ok, movement, urgent = pcall(
            self.GetCrystalGolemSpinnerMove,
            self,
            routeDirection,
            enemy,
            targetYaw
        )

        if ok and movement then
            local now = os.clock()
            self.CurrentSolveEnemy = enemy
            self.LastSolve = now
            self.LastDodgeReason = "golem-sweeper-spin"
            self.IsDodging = true
            self.CachedDirection = movement
            self.CachedYaw = targetYaw
            self.CachedEmergency = urgent
            self.CachedDodging = true
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
            if movement.Magnitude > 0.05 then
                self.LastMovement = movement.Unit
            end
            return movement, targetYaw, urgent, true
        elseif not ok then
            self.GolemSpinnerError = tostring(movement)
        end

        return oldSolveGolemSpinner(self, routeDirection, enemy, targetYaw)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.20"
        self.Combat.Owner = self
        return self
    end
end

