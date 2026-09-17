-- EXPERIMENT (branch experiment-flatmap): time-based escape field.
--
-- The old dodge asks "is this direction clear right now?" and throws away any
-- direction that is not. Surrounded by six Battle Mage orbs every direction is
-- "not clear", so it froze and died. This one asks a different question for
-- every candidate spot around the character:
--
--     how long until that spot becomes dangerous, and can I get there first?
--
-- Each live attack is turned into a moving box (position, half size, speed).
-- For a spot we solve when the box will cover it (slab test along the box's
-- own axes), which gives the spot a "safe until" time. A spot is good when
-- safe-until is later than the time it takes to walk there. If nothing is
-- fully safe we take the spot that stays safe the longest instead of standing
-- still, which is what used to kill us.
do
    CONFIG.FieldDodge = true
    CONFIG.FieldHorizon = 2.4            -- seconds we look ahead
    CONFIG.FieldMargin = 0.35            -- extra seconds a spot must stay safe
    CONFIG.FieldRings = { 6, 11, 17, 24 }
    CONFIG.FieldBearings = 16
    CONFIG.FieldPadXZ = 2.0              -- body half width added to every box
    CONFIG.FieldPadY = 7
    CONFIG.FieldRescueUnder = 0.8        -- take over when our spot dies within this
    CONFIG.FieldBetterBy = 0.4           -- ...and only if we find something this much better
    CONFIG.FieldCacheTime = 0.05

    local Field = {}

    -- every live attack as { CF, HalfX, HalfZ, HalfY, V }
    function Field.Collect(solver)
        local hazards = solver.Hazards
        local list = {}
        for _, data in ipairs(hazards.CachedActive or {}) do
            local part = data.Part
            if part and part.Parent then
                local cf, half
                if data.WarningCF and data.WarningHalf then
                    cf, half = data.WarningCF, data.WarningHalf
                else
                    cf, half = part.CFrame, part.Size * 0.5
                end
                local velocity = flatten(hazards:GetProjectileVelocity(data))
                table.insert(list, {
                    CF = cf,
                    HX = half.X + CONFIG.FieldPadXZ,
                    HY = half.Y + CONFIG.FieldPadY,
                    HZ = half.Z + CONFIG.FieldPadXZ,
                    V = velocity,
                    Part = part,
                })
            end
        end
        return list
    end

    -- earliest time in [0, horizon] at which `point` is inside the box
    local function hitTime(box, point, horizon)
        local relative = box.CF:PointToObjectSpace(point)
        if math.abs(relative.Y) > box.HY then
            return nil
        end
        local speed = box.V.Magnitude
        if speed < 0.5 then
            if math.abs(relative.X) <= box.HX and math.abs(relative.Z) <= box.HZ then
                return 0
            end
            return nil
        end
        -- in the box's frame the point drifts at -V
        local drift = box.CF:VectorToObjectSpace(-box.V)
        local enter, exit = 0, horizon
        for _, axis in ipairs({ { relative.X, drift.X, box.HX }, { relative.Z, drift.Z, box.HZ } }) do
            local position, velocity, half = axis[1], axis[2], axis[3]
            if math.abs(velocity) < 0.01 then
                if math.abs(position) > half then
                    return nil
                end
            else
                local t1 = (-half - position) / velocity
                local t2 = (half - position) / velocity
                if t1 > t2 then
                    t1, t2 = t2, t1
                end
                enter = math.max(enter, t1)
                exit = math.min(exit, t2)
                if enter > exit then
                    return nil
                end
            end
        end
        if enter > horizon or exit < 0 then
            return nil
        end
        return math.max(enter, 0)
    end

    function Field.SafeUntil(boxes, point, horizon)
        local best = horizon
        for _, box in ipairs(boxes) do
            local t = hitTime(box, point, horizon)
            if t and t < best then
                best = t
                if best <= 0 then
                    return 0
                end
            end
        end
        return best
    end

    -- the spot we would like to stand on: keeps the target in cast range
    local function preferredSpot(solver, origin)
        local enemy = solver.CurrentSolveEnemy
        if not enemy or not enemy.Root or not enemy.Root.Parent then
            return nil
        end
        local delta = flatten(origin - enemy.Root.Position)
        local distance = delta.Magnitude
        if distance < 1 then
            return nil
        end
        local want
        if isBossEnemy(enemy) then
            want = math.clamp(distance, CONFIG.BossMinRange, CONFIG.BossMaxRange)
        else
            want = math.clamp(distance, CONFIG.MobBurstRange * 0.6, CONFIG.MobBurstRange)
        end
        return enemy.Root.Position + delta.Unit * want
    end

    function Field.Solve(solver, preferred, targetYaw)
        local character = solver.CharacterService
        local root = character.Root
        if not root then
            return nil
        end
        local now = os.clock()
        local cached = solver.FieldCache
        if cached and now - cached.At < CONFIG.FieldCacheTime then
            return cached.Result
        end

        local origin = root.Position
        local horizon = CONFIG.FieldHorizon
        local boxes = Field.Collect(solver)
        local speed = math.max(character.Humanoid and character.Humanoid.WalkSpeed or CONFIG.WalkSpeed, 8)
        local hereSafe = Field.SafeUntil(boxes, origin, horizon)
        local spot = preferredSpot(solver, origin)

        local best, bestScore
        for _, radius in ipairs(CONFIG.FieldRings) do
            for i = 0, CONFIG.FieldBearings - 1 do
                local direction = unit(rotateXZ(Vector3.new(1, 0, 0), i * 360 / CONFIG.FieldBearings))
                local point = origin + direction * radius
                local safe = Field.SafeUntil(boxes, point, horizon)
                local arrival = radius / speed
                local margin = safe - arrival
                if margin > 0 then
                    local score = math.min(margin, 1.6) * 120
                    score -= radius * 1.2
                    if spot then
                        score -= flatten(point - spot).Magnitude * 1.5
                    elseif preferred and preferred.Magnitude > 0 then
                        score += direction:Dot(preferred) * 25
                    end
                    if solver.LastMovement and solver.LastMovement.Magnitude > 0 then
                        score += direction:Dot(solver.LastMovement) * 15
                    end
                    if (not bestScore or score > bestScore) then
                        -- only now pay for the walk / ground checks
                        if solver.Geometry:IsDirectionClear(direction, radius, targetYaw)
                            and solver.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding)
                        then
                            best = { Direction = direction, Radius = radius, Safe = safe, Margin = margin, Point = point }
                            bestScore = score
                        end
                    end
                end
            end
        end

        local result = { HereSafe = hereSafe, Best = best, Boxes = #boxes }
        solver.FieldCache = { At = now, Result = result }
        return result
    end

    ---------------------------------------------------------------------------
    -- Take over only when the old solver is about to leave us somewhere that
    -- dies sooner than what the field found.
    ---------------------------------------------------------------------------
    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolve(self, routeDirection, enemy, targetYaw)
        if not CONFIG.FieldDodge or self.ForceRouteMovement then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        if not root or not self.CharacterService:IsAlive() then
            return direction, yaw, emergency, dodging
        end

        local result = Field.Solve(self, routeDirection, targetYaw)
        if not result then
            return direction, yaw, emergency, dodging
        end

        self.FieldHereSafe = result.HereSafe
        if result.HereSafe > CONFIG.FieldRescueUnder then
            return direction, yaw, emergency, dodging   -- we are fine where we are
        end

        local best = result.Best
        if not best then
            return direction, yaw, emergency, dodging
        end

        -- how long would the old choice keep us alive?
        local oldSafe = 0
        if direction and direction.Magnitude > 0.05 then
            local step = math.min(CONFIG.DodgeDistance, best.Radius)
            local point = root.Position + unit(flatten(direction)) * step
            oldSafe = Field.SafeUntil(Field.Collect(self), point, CONFIG.FieldHorizon) - step / math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        end

        if best.Margin > oldSafe + CONFIG.FieldBetterBy then
            self.FieldTakeovers = (self.FieldTakeovers or 0) + 1
            self.LastDodgeReason = "field"
            self.CachedDirection = best.Direction
            self.CachedDodging = true
            self.IsDodging = true
            self.LastMovement = best.Direction
            return best.Direction, targetYaw, false, true
        end

        return direction, yaw, emergency, dodging
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "45-flat+field"
        return self
    end
end

