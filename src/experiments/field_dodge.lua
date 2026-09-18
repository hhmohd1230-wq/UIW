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
    -- The field is a rescue, not the driver. It used to take over 87-133 times
    -- in one boss fight, which is the script repositioning instead of standing
    -- and killing things - runs got slower even though deaths went down. These
    -- thresholds only let it speak up when the spot we are on is genuinely
    -- about to be hit and it has something clearly better.
    CONFIG.FieldRescueUnder = 0.45       -- our spot dies this soon
    CONFIG.FieldBetterBy = 0.8           -- ...and the new one is this much better
    CONFIG.FieldCommitTime = 0.35        -- keep a chosen escape instead of re-steering
    CONFIG.FieldPanicUnder = 0.18        -- about to land: re-steer anyway
    CONFIG.FieldCacheTime = 0.05
    CONFIG.FieldBusyBoxes = 40           -- past this many attacks we ease off
    CONFIG.FieldBusyCacheTime = 0.12
    CONFIG.FieldBusyBearings = 10
    CONFIG.FieldMaxBoxes = 48            -- hard ceiling, nearest kept
    CONFIG.FieldTimeBudget = 0.0015      -- seconds per solve, never more
    CONFIG.FieldSpinMinRate = math.rad(6)  -- slower than this counts as not turning
    CONFIG.FieldSpinMaxRate = math.rad(400)
    CONFIG.FieldSpinHorizon = 1.6          -- how far ahead a turning box is followed
    CONFIG.FieldSpinSteps = 8              -- fewest time samples for a turning box
    CONFIG.FieldSpinMaxSteps = 32          -- and the most, so one beam cannot eat a frame

    local Field = {}

    -- rotate around Y, +X towards +Z, the same sense as atan2(z, x)
    local function spinXZ(vector, radians)
        local c, s = math.cos(radians), math.sin(radians)
        return Vector3.new(
            vector.X * c - vector.Z * s,
            vector.Y,
            vector.X * s + vector.Z * c
        )
    end

    -- How fast a hazard part is turning. Sweeping beams (the golem's electrical
    -- cross, anything that rotates around an anchor) look like a harmless static
    -- wall to a straight-line model: they never move towards you, they turn into
    -- you. Measuring the turn is what makes them predictable.
    local spinTracks = setmetatable({}, { __mode = "k" })

    local function trackSpin(part, cf, now)
        local look = flatten(cf.LookVector)
        if look.Magnitude < 0.01 then
            return 0
        end
        local angle = math.atan2(look.Z, look.X)
        local info = spinTracks[part]
        if not info then
            spinTracks[part] = { Angle = angle, At = now, Omega = 0 }
            return 0
        end
        local dt = now - info.At
        if dt >= 0.03 then
            local delta = (angle - info.Angle + math.pi) % (math.pi * 2) - math.pi
            local measured = delta / dt
            if math.abs(measured) <= CONFIG.FieldSpinMaxRate then
                info.Omega = info.Omega * 0.5 + measured * 0.5
            end
            info.Angle, info.At = angle, now
        end
        if math.abs(info.Omega) < CONFIG.FieldSpinMinRate then
            return 0
        end
        return info.Omega
    end

    -- what a turning part turns around: its model's pivot, else itself
    local function pivotOf(part)
        local model = part.Parent
        if model and model:IsA("Model") then
            local ok, cf = pcall(model.GetPivot, model)
            if ok and cf then
                return cf.Position
            end
        end
        return part.Position
    end

    -- How far a box could possibly matter: we only ever ask about points on the
    -- rings around us, so anything that cannot reach the outermost ring inside
    -- the horizon is dropped before any maths is done on it. At the Ancient
    -- Tree this takes the list from ~138 boxes to a handful, which is the
    -- difference between 28 and 60 fps.
    local function ringReach()
        local most = 0
        for _, radius in ipairs(CONFIG.FieldRings) do
            most = math.max(most, radius)
        end
        return most
    end

    -- every live attack as { CF, HalfX, HalfZ, HalfY, V, Omega, Pivot }
    function Field.Collect(solver)
        local hazards = solver.Hazards
        local now = os.clock()
        local list = {}
        local root = solver.CharacterService and solver.CharacterService.Root
        local origin = root and root.Position or nil
        local rings = ringReach() + CONFIG.FieldPadXZ + 2
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
                local omega = 0
                local pivot = nil
                local okSpin, measured = pcall(trackSpin, part, part.CFrame, now)
                if okSpin and measured ~= 0 then
                    omega = measured
                    pivot = pivotOf(part)
                    -- a turning hitbox has to be predicted from its live pose;
                    -- the frozen warning pose would be turned forward from the
                    -- wrong starting angle
                    cf, half = part.CFrame, part.Size * 0.5
                end
                local reach = nil
                if omega ~= 0 then
                    -- furthest the bar reaches from what it turns around, so a
                    -- point outside that circle can be rejected in two steps
                    local right = flatten(cf.RightVector) * (half.X + CONFIG.FieldPadXZ)
                    local ahead = flatten(cf.LookVector) * (half.Z + CONFIG.FieldPadXZ)
                    local middle = flatten(cf.Position - pivot)
                    reach = 0
                    for _, corner in ipairs({ middle + right + ahead, middle + right - ahead,
                                              middle - right + ahead, middle - right - ahead }) do
                        reach = math.max(reach, corner.Magnitude)
                    end
                end
                if origin then
                    local far
                    if pivot then
                        far = flatten(origin - pivot).Magnitude > (reach or 0) + rings
                    else
                        local span = half.Magnitude + velocity.Magnitude * CONFIG.FieldHorizon
                        far = flatten(origin - cf.Position).Magnitude > span + rings
                    end
                    if far then
                        continue
                    end
                end
                table.insert(list, {
                    CF = cf,
                    RMax = reach,
                    HX = half.X + CONFIG.FieldPadXZ,
                    HY = half.Y + CONFIG.FieldPadY,
                    HZ = half.Z + CONFIG.FieldPadXZ,
                    V = velocity,
                    Omega = omega,
                    Pivot = pivot,
                    Part = part,
                })
            end
        end
        if #list > CONFIG.FieldBusyBoxes then
            for _, box in ipairs(list) do
                box.Busy = true
            end
        end

        if origin and #list > CONFIG.FieldMaxBoxes then
            table.sort(list, function(a, b)
                return flatten(a.CF.Position - origin).Magnitude
                    < flatten(b.CF.Position - origin).Magnitude
            end)
            for index = #list, CONFIG.FieldMaxBoxes + 1, -1 do
                list[index] = nil
            end
        end

        return list
    end

    -- is `point` covered by the box as it will stand `t` seconds from now?
    -- Instead of turning the box we turn the point backwards around the pivot,
    -- which is the same test and needs no CFrame rebuilding.
    local function coveredAt(box, point, t)
        local p = point - box.V * t
        if box.Omega ~= 0 and box.Pivot then
            p = box.Pivot + spinXZ(p - box.Pivot, -box.Omega * t)
        end
        local relative = box.CF:PointToObjectSpace(p)
        return math.abs(relative.X) <= box.HX
            and math.abs(relative.Y) <= box.HY
            and math.abs(relative.Z) <= box.HZ
    end

    -- earliest time in [0, horizon] at which `point` is inside the box
    local function hitTime(box, point, horizon)
        -- a turning box cannot be solved with straight-line algebra, so walk the
        -- next couple of seconds in steps and take the first step that covers us
        if box.Omega ~= 0 and box.Pivot then
            local radius = flatten(point - box.Pivot).Magnitude
            if radius > (box.RMax or math.huge) then
                return nil          -- the beam cannot reach this far out
            end
            -- The step has to be short enough that the point cannot cross the
            -- bar between two samples, or a thin fast beam is stepped straight
            -- over and reported as safe.
            local sweep = math.abs(box.Omega) * math.max(radius, 1)   -- studs per second
            local span = math.min(horizon, CONFIG.FieldSpinHorizon)
            local step = math.min(span / CONFIG.FieldSpinSteps, math.max(box.HX, 0.5) / math.max(sweep, 0.01))
            local ceiling = box.Busy and 12 or CONFIG.FieldSpinMaxSteps
            local steps = math.clamp(math.ceil(span / step), CONFIG.FieldSpinSteps, ceiling)
            step = span / steps
            for index = 0, steps do
                if coveredAt(box, point, index * step) then
                    return math.max((index - 1) * step, 0)
                end
            end
            return nil
        end

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
        local busy = cached and cached.Result and (cached.Result.Boxes or 0) > CONFIG.FieldBusyBoxes
        local interval = busy and CONFIG.FieldBusyCacheTime or CONFIG.FieldCacheTime
        if cached and now - cached.At < interval then
            return cached.Result
        end

        local origin = root.Position
        local horizon = CONFIG.FieldHorizon
        local boxes = Field.Collect(solver)
        local speed = math.max(character.Humanoid and character.Humanoid.WalkSpeed or CONFIG.WalkSpeed, 8)
        local hereSafe = Field.SafeUntil(boxes, origin, horizon)
        local spot = preferredSpot(solver, origin)

        local best, bestScore
        local bearings = (#boxes > CONFIG.FieldBusyBoxes)
            and CONFIG.FieldBusyBearings
            or CONFIG.FieldBearings
        -- A solve must never be allowed to eat a frame. At the Forest Dragon,
        -- 48 turning attacks x 40 candidate spots took the game to 6 fps, and a
        -- dodge computed too late is worth nothing anyway. When the budget runs
        -- out we keep the best spot found so far and move on.
        local startedAt = os.clock()
        local outOfTime = false
        for _, radius in ipairs(CONFIG.FieldRings) do
            if outOfTime then
                break
            end
            for i = 0, bearings - 1 do
                if os.clock() - startedAt > CONFIG.FieldTimeBudget then
                    outOfTime = true
                    break
                end
                local direction = unit(rotateXZ(Vector3.new(1, 0, 0), i * 360 / bearings))
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

        local result = { HereSafe = hereSafe, Best = best, Boxes = #boxes, List = boxes }
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

        -- how much of the fight we spend being pushed around, so "is it slower?"
        -- can be answered with a number instead of a feeling
        local clock = os.clock()
        local since = clock - (self.DodgeClock or clock)
        self.DodgeClock = clock
        if since < 0.5 then
            self.SecondsAlive = (self.SecondsAlive or 0) + since
            if dodging then
                self.SecondsDodging = (self.SecondsDodging or 0) + since
            end
        end

        local owner = self.Owner
        if owner and owner.FieldDodge == false then
            return direction, yaw, emergency, dodging
        end
        if not CONFIG.FieldDodge or self.ForceRouteMovement then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        if not root or not self.CharacterService:IsAlive() then
            return direction, yaw, emergency, dodging
        end

        -- The Crystal Golem's sweeper planner deliberately stands still inside a
        -- crystal shelter, and the field would read that stillness as "about to
        -- be hit" and walk us out of it. That hold is worth protecting.
        -- Its *moving* answers are not: measured live, we took four ticks of
        -- 40% while standing 11 studs inside a turning bar with that planner in
        -- control. On those frames the field is allowed to argue, now that it
        -- can predict a turning attack.
        -- champion-slam is an escape from a circle we are standing in, and
        -- champion-station only moves a few studs inside a beam gap: both are
        -- already the right answer, but the station is still allowed to be
        -- overruled below if the field finds it is about to be hit.
        if self.LastDodgeReason == "golem-dome"
            or self.LastDodgeReason == "champion-slam"
            or (self.LastDodgeReason == "golem-sweeper-spin" and self.GolemSafeSpotHolding)
        then
            return direction, yaw, emergency, dodging
        end

        -- Same for any mechanic that pins us to a region (cleanse bubble, built
        -- wall): staying inside it is the point.
        if self.ForcedRegionPart and self:IsPointInsideForcedRegion(root.Position) then
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

        -- Stick with an escape we already committed to instead of picking a new
        -- direction every frame; the constant re-steering is what ate the clock.
        local now = os.clock()
        if self.FieldCommitDir
            and now < (self.FieldCommitUntil or 0)
            and result.HereSafe > CONFIG.FieldPanicUnder
        then
            self.LastDodgeReason = "field"
            self.CachedDirection = self.FieldCommitDir
            self.CachedDodging = true
            self.IsDodging = true
            return self.FieldCommitDir, targetYaw, false, true
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
            oldSafe = Field.SafeUntil(result.List, point, CONFIG.FieldHorizon)
                - step / math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        end

        if best.Margin > oldSafe + CONFIG.FieldBetterBy then
            self.FieldTakeovers = (self.FieldTakeovers or 0) + 1
            self.FieldCommitDir = best.Direction
            self.FieldCommitUntil = now + CONFIG.FieldCommitTime
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
        if self.FieldDodge == nil then
            self.FieldDodge = true
        end
        local hud = self.HUD
        if hud and hud.AddToggleRow and hud.Pages and hud.Pages.Automation then
            hud.AddToggleRow(hud.Pages.Automation, 11, "Field Dodge (test)",
                "Escapes by how long a spot stays safe; turn off for the older dodge",
                function() return self.FieldDodge ~= false end,
                function(value) self.FieldDodge = value end)
        end
        return self
    end

    local oldApplyField = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.FieldDodge) == "boolean" then
            self.FieldDodge = settings.FieldDodge
        end
        return oldApplyField(self, settings)
    end

    local oldGetField = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGetField(self)
        settings.FieldDodge = self.FieldDodge ~= false
        return settings
    end
end

