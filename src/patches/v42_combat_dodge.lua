--[[
    UIW v38 — Combat + Dodge upgrade patch

    HOW TO INSTALL (one paste, nothing to delete):
      Paste this whole block into your script DIRECTLY ABOVE these two lines
      near the very bottom:

          local Controller =
              UIWController.new()

      Every class (HazardTracker, DodgeSolver, CombatController, HUD,
      UIWController) is already defined at that point, so this block just
      replaces the methods listed below. The rest of your script is untouched.

    COMBAT
      * Won't cast damage skills while facing the wrong way (e.g. during an
        emergency body turn). The cooldown is saved for a cast that can hit.
      * Won't cast damage skills through walls (line-of-sight check). Mobs,
        players, doorway "entry" parts and invisible parts don't count as walls.
      * Aims up to 24° off the target when that puts more mobs inside the
        skill's forward hitbox. The locked target always stays inside it.
      * Only waits for the buff when that's worth it: if the buff has a long
        cooldown and the damage skill is ready, it attacks without the buff.
      * If staging with everything ready doesn't fire the buff within 3 s,
        stops waiting instead of standing still forever.
      * Any damage cast clears the commit (before, only E did).
      * Doesn't press Q/E while a chat or text box has focus.
      * Caches tool lookups instead of scanning the backpack several times
        per frame.

    DODGE
      * Escaping a hitbox you're already inside now measures the real exit
        distance in each direction and takes the shortest safe one. It also
        tries turning the body's thin side toward the exit.
      * When you're inside a moving projectile, the escape heads sideways off
        its path instead of racing it.
      * The "aura" no longer counts every still hitbox within 34 studs as a
        threat (that caused constant jitter-dodging). Still hitboxes count
        within 7 studs. Moving projectiles count only if they're closing in
        and would reach you within about 1.2 s.
      * The aura scan scores directions cheaply first, then fully checks only
        the best ones (with a budget), so boss fights stutter less.
      * Scoring prefers moving sideways to an incoming projectile's path and
        penalizes running toward it.
      * Melee panic weights close mobs more heavily, checks that the path
        doesn't brush past a mob, and now also avoids projectiles and
        telegraph (precast) zones.
      * A committed dodge lane is only reused if it's still clear of
        telegraphs and has safe ground.
      * If you enter a hitbox between solver ticks, it re-solves immediately
        instead of waiting for the next tick.
      * When no safe option exists, it steps away from the threat instead of
        freezing in place.
      * Body-overlap queries are memoized per hazard-cache tick, which cuts a
        large share of the physics queries.

    HUD
      * Adds colors for the MECHANIC and PROGRESSION states.
      * Shows why a cast was held (turning to target / no line of sight).
]]

do
    ---------------------------------------------------------------------------
    -- Tuning
    ---------------------------------------------------------------------------
    CONFIG.CastHitboxWidth = 16          -- width of the forward damage hitbox (studs)
    CONFIG.AimMaxOffsetDegrees = 24      -- max aim deviation from the locked target
    CONFIG.CastFacingTolerance = 28      -- degrees; damage casts wait until facing is this close
    CONFIG.LosBypassDistance = 18        -- closer than this, skip the line-of-sight check
    CONFIG.BuffMaxWait = 4.0             -- max seconds worth waiting for a buff when damage is ready
    CONFIG.MaxStageHold = 3.0            -- max seconds to stand at the staging line with everything ready
    CONFIG.StaticAuraRadius = 7          -- still hitboxes trigger the aura only this close
    CONFIG.ProjectileAuraTime = 1.2      -- moving projectiles trigger the aura within this time-to-contact
    CONFIG.ExitProbeMax = 26             -- how far to search for a hitbox exit
    CONFIG.ExitProbeStep = 2
    CONFIG.AuraDodgeBudget = 90          -- full safety checks allowed per aura solve
    CONFIG.AuraPointThreatLimit = 60     -- GetPointThreat below this = acceptable destination
    CONFIG.DodgeUrgentResolve = true

    local SLOTS = { "q", "e" }

    local function yawToDirection(yaw)
        return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
    end

    ---------------------------------------------------------------------------
    -- HazardTracker
    ---------------------------------------------------------------------------
    local legacyGetBodyOverlaps = HazardTracker.GetBodyOverlaps

    function HazardTracker:GetBodyOverlaps(position, yaw)
        self:RefreshCache(false)

        local stamp = self.LastCacheTime
        if self.OverlapMemoStamp ~= stamp or not self.OverlapMemo then
            self.OverlapMemoStamp = stamp
            self.OverlapMemo = {}
        end

        local key = (self.TightPadding and "t" or "n") .. string.format(
            "%d:%d:%d:%d",
            math.floor(position.X * 2 + 0.5),
            math.floor(position.Y * 2 + 0.5),
            math.floor(position.Z * 2 + 0.5),
            math.floor(((yaw or 0) % (math.pi * 2)) * 8 + 0.5)
        )

        local cached = self.OverlapMemo[key]
        if cached then
            return cached
        end

        local result = legacyGetBodyOverlaps(self, position, yaw)
        self.OverlapMemo[key] = result
        return result
    end

    function HazardTracker:GetAuraThreat(position, radius)
        radius = radius or CONFIG.AuraRadius

        local best = nil
        local bestDistance = radius
        local bestUrgency = math.huge

        for _, data in ipairs(self:GetActive()) do
            local part = data.Part
            if part and part.Parent then
                local lp = part.CFrame:PointToObjectSpace(position)
                local half = part.Size * 0.5
                local distance = Vector3.new(
                    math.max(math.abs(lp.X) - half.X, 0),
                    math.max(math.abs(lp.Y) - half.Y, 0),
                    math.max(math.abs(lp.Z) - half.Z, 0)
                ).Magnitude

                if distance <= radius then
                    local urgency = nil
                    local velocity = self:GetProjectileVelocity(data)

                    if velocity.Magnitude >= CONFIG.ProjectileVelocityMin then
                        local closing = velocity:Dot(unit(position - part.Position))
                        if closing > CONFIG.ProjectileVelocityMin * 0.5 then
                            local timeToContact = distance / closing
                            if timeToContact <= CONFIG.ProjectileAuraTime then
                                urgency = timeToContact
                            end
                        end
                    elseif distance <= CONFIG.StaticAuraRadius then
                        urgency = distance / math.max(CONFIG.WalkSpeed, 1)
                    end

                    if urgency and urgency < bestUrgency then
                        best = data
                        bestUrgency = urgency
                        bestDistance = distance
                    end
                end
            end
        end

        return best, bestDistance
    end

    ---------------------------------------------------------------------------
    -- DodgeSolver
    ---------------------------------------------------------------------------
    local legacyActiveEscape = DodgeSolver.GetActiveHitboxEscape
    local legacyScoreCandidate = DodgeSolver.ScoreCandidate

    function DodgeSolver:ScoreCandidate(direction, preferred, yaw)
        local score = legacyScoreCandidate(self, direction, preferred, yaw)
        if not score then
            return nil
        end

        local threat = self.IncomingProjectile
        if threat and threat.Part and threat.Part.Parent then
            local velocity = flatten(self.Hazards:GetProjectileVelocity(threat))
            if velocity.Magnitude > 0.1 then
                local along = unit(flatten(direction)):Dot(velocity.Unit)
                score += (1 - math.abs(along)) * 160
                if along < -0.5 then
                    score -= 200 -- running into it
                end
            end
        end

        return score
    end

    function DodgeSolver:GetActiveHitboxEscape(targetYaw)
        local root = self.CharacterService.Root
        local origin = root.Position
        local overlaps = self.Hazards:GetCurrentOverlaps(targetYaw)

        if #overlaps == 0 then
            return nil
        end

        local seed = Vector3.zero
        local insideProjectile = false

        for _, part in ipairs(overlaps) do
            if part and part.Parent then
                local data = self.Hazards.Hazards[part]
                local velocity = data and flatten(self.Hazards:GetProjectileVelocity(data)) or Vector3.zero

                if velocity.Magnitude >= CONFIG.ProjectileVelocityMin then
                    -- Moving projectile: leave its path sideways.
                    insideProjectile = true
                    local offset = flatten(origin - part.Position)
                    local perpendicular = offset - velocity.Unit * offset:Dot(velocity.Unit)
                    if perpendicular.Magnitude < 0.2 then
                        perpendicular = Vector3.new(-velocity.Z, 0, velocity.X)
                    end
                    seed += unit(perpendicular) * 1.5
                else
                    local warningExit = self.Hazards:GetWarningExitDirection(part, origin)
                    if warningExit then
                        seed += warningExit
                    else
                        local lp = part.CFrame:PointToObjectSpace(origin)
                        local half = part.Size * 0.5
                        local localDirection
                        if half.X - math.abs(lp.X) < half.Z - math.abs(lp.Z) then
                            localDirection = Vector3.new(lp.X >= 0 and 1 or -1, 0, 0)
                        else
                            localDirection = Vector3.new(0, 0, lp.Z >= 0 and 1 or -1)
                        end
                        seed += unit(flatten(part.CFrame:VectorToWorldSpace(localDirection)))
                    end
                end
            end
        end

        seed = unit(seed)
        if seed.Magnitude <= 0 then
            seed = unit(flatten(root.CFrame.LookVector))
        end

        local angles = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }
        local exitStep = 1.5
        local bestDirection, bestYaw, bestPoint = nil, nil, nil
        local bestDistance = math.huge
        local bestScore = -math.huge

        local function search(yaw, isTargetYaw)
            for _, angle in ipairs(angles) do
                local direction = unit(rotateXZ(seed, angle))
                local limit = math.min(CONFIG.ExitProbeMax, bestDistance + 4)
                local exitDistance = nil
                local d = exitStep

                while d <= limit do
                    if self.Hazards:IsFullBodyClear(origin + direction * d, yaw) then
                        exitDistance = d
                        break
                    end
                    d += exitStep
                end

                if exitDistance then
                    local travel = exitDistance + 0.75
                    local endpoint = origin + direction * travel

                    local ok = self.Hazards:IsFullBodyClear(endpoint, yaw)
                        and self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding)
                        and self.Geometry:IsDirectionClear(direction, travel, yaw)
                        and (insideProjectile
                            or self.Hazards:IsPredictiveTrajectoryClear(origin, direction, yaw, travel))

                    if ok then
                        local score = -exitDistance * 60
                            + direction:Dot(seed) * 25
                            + self.Geometry:GetEdgeClearanceScore(endpoint) * 8
                            - self:GetMeleePenalty(endpoint) * 0.15

                        if not isTargetYaw then
                            score -= 30
                        end

                        if self.LastMovement.Magnitude > 0 then
                            score += direction:Dot(self.LastMovement) * 10
                        end

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestYaw = yaw
                            bestDistance = exitDistance
                            bestPoint = endpoint
                        end
                    end
                end
            end
        end

        -- v42: search with tight padding so narrow safe gaps (the cube pylon's
        -- ring between bullseye and outer bars) are found at all.
        self.Hazards.TightPadding = true
        local okSearch, searchErr = pcall(function()
            search(targetYaw, true)
            if not bestDirection or bestDistance > 6 then
                search(directionToYaw(seed), false)
            end
        end)
        self.Hazards.TightPadding = false
        if not okSearch then
            warn("[UIW] exit search failed: " .. tostring(searchErr))
        end

        if bestDirection then
            self.SelectedAuraPoint = bestPoint
            return bestDirection, bestYaw, bestYaw ~= targetYaw
        end

        return legacyActiveEscape(self, targetYaw)
    end

    function DodgeSolver:GetMeleePanicEscape(targetYaw, routeDirection)
        local root = self.CharacterService.Root
        local origin = root.Position
        local threats = self.Dungeon:GetMeleeThreats(origin, CONFIG.MultiMeleeRadius)

        if #threats == 0 then
            self.MeleePanicActive = false
            return nil
        end

        local nearest = math.huge
        local closeCount = 0
        local trigger = false
        local center = Vector3.zero
        local weightSum = 0

        for _, info in ipairs(threats) do
            local proximity = info.ThreatClass == "Proximity"
            local emergencyRadius = CONFIG.MeleeEmergencyRadius
                + (proximity and CONFIG.ProximityEmergencyBonus or 0)
            local clusterRadius = CONFIG.MeleeClusterPanicRadius
                + (proximity and CONFIG.ProximitySafetyBonus or 0)

            nearest = math.min(nearest, info.Distance)

            if info.Distance <= emergencyRadius then
                trigger = true
            end
            if info.Distance <= clusterRadius then
                closeCount += 1
            end

            -- Close mobs dominate the escape direction.
            local weight = 1 / (math.max(info.Distance, 4) ^ 2)
            center += info.Enemy.Root.Position * weight
            weightSum += weight
        end

        if closeCount >= CONFIG.MeleeClusterPanicCount then
            trigger = true
        end

        if not self.MeleePanicActive then
            if not trigger then
                return nil
            end
            self.MeleePanicActive = true
        elseif nearest >= CONFIG.MeleePanicExitRadius + CONFIG.ProximityEmergencyBonus
            and closeCount == 0
        then
            self.MeleePanicActive = false
            return nil
        end

        center /= weightSum

        local away = unit(flatten(origin - center))
        if away.Magnitude <= 0 then
            away = unit(flatten(-root.CFrame.LookVector))
        end

        local towardCluster = -away
        local orbit = self:GetSafeOrbitTangent(towardCluster, targetYaw)
        routeDirection = unit(flatten(routeDirection or Vector3.zero))
        local base = unit(away * 0.72 + orbit * 0.92)

        local function predictedDistance(info, point)
            local enemyRoot = info.Enemy.Root
            local t = info.ThreatClass == "Proximity" and 0.42 or 0.32
            local predicted = enemyRoot.Position + flatten(enemyRoot.AssemblyLinearVelocity) * t
            return flatten(predicted - point).Magnitude
        end

        local bestDirection = nil
        local bestScore = -math.huge

        for _, angle in ipairs({ 0, 20, -20, 40, -40, 60, -60, 80, -80, 100, -100, 125, -125, 150, -150, 180 }) do
            local direction = unit(rotateXZ(base, angle))
            local future = origin + direction * 10

            if self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding) then
                local futureMin = math.huge
                local sum = 0
                local hard = false
                local emergencyHit = false
                local midpoint = origin + direction * 5

                for _, info in ipairs(threats) do
                    local proximity = info.ThreatClass == "Proximity"
                    local d = predictedDistance(info, future)
                    local dMid = predictedDistance(info, midpoint)

                    futureMin = math.min(futureMin, d)
                    sum += d

                    if math.min(d, dMid) <= CONFIG.MeleeHardNoGoRadius + (proximity and 3 or 0) then
                        hard = true
                    elseif d <= CONFIG.MeleeEmergencyRadius
                        + (proximity and CONFIG.ProximityEmergencyBonus or 0)
                    then
                        emergencyHit = true
                    end
                end

                local improvement = futureMin - nearest
                local routeDot = routeDirection.Magnitude > 0 and direction:Dot(routeDirection) or 0

                local score = futureMin * 170
                    + improvement * 300
                    + sum * 8
                    + routeDot * 75
                    + direction:Dot(orbit) * 40
                    + self.Geometry:GetEdgeClearanceScore(future) * 22

                if hard then
                    score -= 12000
                elseif emergencyHit then
                    score -= 4500
                end
                if improvement < 0.75 then
                    score -= 500
                end
                if routeDot < -0.45 then
                    score -= 350
                end

                -- Expensive safety checks only for candidates that could win.
                if score > bestScore
                    and self.Geometry:IsDirectionClear(direction, 8, targetYaw)
                    and self.Hazards:IsTrajectoryClear(origin, direction, targetYaw, 8)
                    and self.Hazards:IsPredictiveTrajectoryClear(origin, direction, targetYaw, 8)
                    and self.Hazards:IsPrecastTrajectoryClear(origin, direction, targetYaw, 8)
                then
                    bestScore = score
                    bestDirection = direction
                end
            end
        end

        if bestDirection then
            return bestDirection, targetYaw, false
        end

        local shortOrbit = self:GetSafeOrbitTangent(towardCluster, targetYaw)
        if shortOrbit.Magnitude > 0
            and self.Geometry:IsDirectionClear(shortOrbit, 3, targetYaw)
        then
            return shortOrbit, targetYaw, false
        end

        return nil
    end

    function DodgeSolver:IsImmediateHazardDanger(preferred, targetYaw)
        self.AuraThreat = nil
        self.AuraThreatDistance = nil
        self.IncomingProjectile = nil
        self.IncomingProjectileTime = nil

        local root = self.CharacterService.Root

        if self.Hazards:GetOverlapCountAt(root.Position, targetYaw) > 0 then
            return true
        end

        preferred = unit(flatten(preferred or Vector3.zero))

        local incoming, impactTime = self.Hazards:GetIncomingProjectileThreat(
            root.Position,
            preferred,
            targetYaw,
            preferred.Magnitude > 0 and CONFIG.DodgeDistance or 0
        )

        if incoming then
            self.IncomingProjectile = incoming
            self.IncomingProjectileTime = impactTime
            return true
        end

        local auraThreat, auraDistance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)
        self.AuraThreat = auraThreat
        self.AuraThreatDistance = auraDistance
        if auraThreat then
            return true
        end

        -- Standing still: the overlap check above already covers telegraphs
        -- landing on the current position.
        if preferred.Magnitude <= 0 then
            return false
        end

        local speed = math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed)
        local lookahead = math.max(CONFIG.DangerLookaheadDistance, speed * CONFIG.PrecastLookaheadTime)

        if not self.Hazards:IsPrecastTrajectoryClear(root.Position, preferred, targetYaw, lookahead) then
            return true
        end

        if #self.Hazards:GetActive() == 0 then
            return false
        end

        return not self.Hazards:IsTrajectoryClear(
            root.Position,
            preferred,
            targetYaw,
            CONFIG.DangerLookaheadDistance
        )
    end

    function DodgeSolver:FindExpandingAuraDodge(preferred, targetYaw)
        local root = self.CharacterService.Root
        local origin = root.Position

        preferred = unit(flatten(preferred))
        if preferred.Magnitude <= 0 then
            preferred = unit(flatten(root.CFrame.LookVector))
        end

        self.SelectedAuraPoint = nil

        local boss = self.CurrentSolveEnemy
        local solvingBoss = boss
            and isBossEnemy(boss)
            and boss.Root
            and boss.Root.Parent
        local auraPart = self.AuraThreat and self.AuraThreat.Part
        local away = (auraPart and auraPart.Parent) and unit(flatten(origin - auraPart.Position)) or Vector3.zero

        local projectileDirection = Vector3.zero
        if self.IncomingProjectile then
            local v = flatten(self.Hazards:GetProjectileVelocity(self.IncomingProjectile))
            if v.Magnitude > 0.1 then
                projectileDirection = v.Unit
            end
        end

        local budget = CONFIG.AuraDodgeBudget
        local forward, forwardScore, forwardPoint = nil, -math.huge, nil
        local fallback, fallbackScore, fallbackPoint = nil, -math.huge, nil

        for _, radius in ipairs(CONFIG.AuraScanRadii) do
            if budget <= 0 then
                break
            end

            local candidates = {}

            for index = 1, CONFIG.AuraDotsPerRing do
                local direction = unit(rotateXZ(preferred, ((index - 1) / CONFIG.AuraDotsPerRing) * 360))
                local point = origin + direction * radius

                local score = direction:Dot(preferred) * (solvingBoss and 180 or 220)
                score += direction:Dot(away) * (solvingBoss and 90 or 260)

                if projectileDirection.Magnitude > 0 then
                    score += (1 - math.abs(direction:Dot(projectileDirection))) * 200
                end

                local bossAdvance = 0
                if solvingBoss then
                    -- v40: "forward" means toward the boss distance band, not onto the boss.
                    bossAdvance = self:GetBossBandError(origin) - self:GetBossBandError(point)
                    score += bossAdvance * 40 - radius * 1.5
                end

                candidates[#candidates + 1] = {
                    Direction = direction,
                    Point = point,
                    Score = score,
                    BossAdvance = bossAdvance,
                }
            end

            table.sort(candidates, function(a, b)
                return a.Score > b.Score
            end)

            -- Best-first: the first candidate that passes every check wins the ring.
            for _, c in ipairs(candidates) do
                if budget <= 0 then
                    break
                end

                local pointThreat = self.Hazards:GetPointThreat(c.Point)

                if pointThreat < CONFIG.AuraPointThreatLimit
                    and not self.Dungeon:GetEnemyDangerAt(c.Point)
                then
                    budget -= 1

                    if self.Geometry:IsGroundPadded(c.Point, CONFIG.EdgeHardPadding)
                        and self.Hazards:IsTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Hazards:IsPredictiveTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Hazards:IsPrecastTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Geometry:IsDirectionClear(c.Direction, radius, targetYaw)
                    then
                        local finalScore = c.Score
                            - pointThreat * 2
                            + self.Geometry:GetEdgeClearanceScore(c.Point) * 20

                        if not solvingBoss then
                            self.SelectedAuraPoint = c.Point
                            return c.Direction, targetYaw, false
                        end

                        if c.BossAdvance >= -1 and finalScore > forwardScore then
                            forward, forwardScore, forwardPoint = c.Direction, finalScore, c.Point
                        end
                        if finalScore > fallbackScore then
                            fallback, fallbackScore, fallbackPoint = c.Direction, finalScore, c.Point
                        end

                        break
                    end
                end
            end
        end

        if forward then
            self.SelectedAuraPoint = forwardPoint
            return forward, targetYaw, false
        end

        if fallback then
            self.SelectedAuraPoint = fallbackPoint
            return fallback, targetYaw, false
        end

        return nil
    end

    function DodgeSolver:FindEmergencyOrientation(preferred, targetYaw)
        local bestDirection, bestYaw = nil, nil
        local bestScore = -math.huge
        local controller = getgenv().UIW
        local yawOffsets = controller and controller.EnchantedDragonPerf
            and { 0 } or { 90, -90, 0 }

        for _, angle in ipairs(CONFIG.DodgeAngles) do
            local direction = unit(rotateXZ(preferred, angle))
            local movementYaw = directionToYaw(direction)

            -- 0 = facing the movement (thin along travel),
            -- ±90 = side-on (thin across travel, squeezes between hitboxes).
            for _, yawOffset in ipairs(yawOffsets) do
                local yaw = movementYaw + math.rad(yawOffset)
                local score = self:ScoreCandidate(direction, preferred, yaw)

                if score then
                    score -= math.abs(angleDifference(yaw, targetYaw)) * 8
                    if score > bestScore then
                        bestScore = score
                        bestDirection = direction
                        bestYaw = yaw
                    end
                end
            end
        end

        if bestDirection then
            return bestDirection, bestYaw, true
        end

        return nil
    end

    -- v42 Cube Pylon bullseye: a 10x10 center square plus four 34x7 bars about
    -- 17 studs out. The only safe place is the thin ring between them, so move
    -- to the middle of that ring and stand still until the shot has fired.
    function DodgeSolver:GetBullseyeEscape(targetYaw)
        local root = self.CharacterService.Root
        local now = os.clock()
        local best = nil

        for _, data in ipairs(self.Hazards:GetActive()) do
            local container = data.Container
            if container and container.Name == "cubePylonShot" and container.Parent then
                local state = self.Hazards.ContainerState[container]
                local age = state and now - state.FirstSeen or 0
                if age <= CONFIG.BullseyeWindow and (not best or best.Container ~= container) then
                    local distance = flatten(container:GetPivot().Position - root.Position).Magnitude
                    if distance <= 40 and (not best or age < best.Age) then
                        best = { Container = container, Age = age }
                    end
                end
            end
        end

        if not best then
            self.BullseyeTarget = nil
            return nil
        end

        -- Measure the pattern from its parts.
        local center, bars = nil, {}
        for _, part in ipairs(best.Container:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "hitBox" then
                if math.max(part.Size.X, part.Size.Z) <= 16 then
                    center = part
                else
                    table.insert(bars, part)
                end
            end
        end
        if not center or #bars == 0 then
            return nil
        end

        local frame = center.CFrame
        local centerHalf = math.max(center.Size.X, center.Size.Z) * 0.5
        local inner = math.huge
        for _, bar in ipairs(bars) do
            local rel = frame:PointToObjectSpace(bar.Position)
            local thickness = math.min(bar.Size.X, bar.Size.Z)
            inner = math.min(inner, math.max(math.abs(rel.X), math.abs(rel.Z)) - thickness * 0.5)
        end

        local body = self.CharacterService.BodySize
        local bodyHalf = math.max(body.X, body.Z) * 0.5
        local safeMin = centerHalf + bodyHalf + CONFIG.BullseyeMargin
        local safeMax = inner - bodyHalf - CONFIG.BullseyeMargin
        if safeMax <= safeMin then
            return nil -- no ring wide enough; let the normal escape handle it
        end
        local ringRadius = (safeMin + safeMax) * 0.5

        local localPos = frame:PointToObjectSpace(root.Position)
        local norm = math.max(math.abs(localPos.X), math.abs(localPos.Z))
        local outer = inner + math.min(bars[1].Size.X, bars[1].Size.Z) + bodyHalf + CONFIG.BullseyeMargin

        if norm >= outer then
            return nil -- already outside the whole pattern
        end

        -- Other attacks (e.g. pyramid lines) at a position, ignoring this bullseye.
        local function otherHazardAt(position)
            for _, hit in ipairs(self.Hazards:GetBodyOverlaps(position, targetYaw)) do
                local hitData = self.Hazards.Hazards[hit]
                if not (hitData and hitData.Container == best.Container) then
                    return true
                end
            end
            return false
        end

        if norm >= safeMin and norm <= safeMax then
            self.Hazards.TightPadding = true
            local covered = otherHazardAt(root.Position)
            self.Hazards.TightPadding = false
            if not covered then
                self.BullseyeTarget = nil
                return Vector3.zero, targetYaw, false -- in the ring: hold still
            end
        end

        -- Candidate ring points: the player's own direction first, then the 8 compass points.
        local candidates = {}
        if norm > 0.5 then
            local scale = ringRadius / norm
            table.insert(candidates, Vector3.new(localPos.X * scale, 0, localPos.Z * scale))
        end
        for i = 0, 7 do
            local angle = math.rad(i * 45)
            local dx, dz = math.cos(angle), math.sin(angle)
            local m = math.max(math.abs(dx), math.abs(dz))
            table.insert(candidates, Vector3.new(dx / m * ringRadius, 0, dz / m * ringRadius))
        end

        local chosen, chosenDistance = nil, math.huge
        self.Hazards.TightPadding = true
        for _, localTarget in ipairs(candidates) do
            local world = frame:PointToWorldSpace(Vector3.new(localTarget.X, localPos.Y, localTarget.Z))
            local distance = flatten(world - root.Position).Magnitude
            if distance > 0.8 and distance < chosenDistance and self.Geometry:HasGround(world) then
                -- Only other attacks may block a ring point.
                if not otherHazardAt(world) then
                    chosen, chosenDistance = world, distance
                end
            end
        end
        self.Hazards.TightPadding = false

        if not chosen then
            return nil
        end

        self.BullseyeTarget = chosen
        self.SelectedAuraPoint = chosen
        local delta = flatten(chosen - root.Position)
        if delta.Magnitude < 0.6 then
            return Vector3.zero, targetYaw, false
        end
        return delta.Unit * math.clamp(delta.Magnitude / 2, 0.35, 1), targetYaw, false
    end

    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local now = os.clock()
        local root = self.CharacterService.Root
        local origin = root.Position

        self.CurrentSolveEnemy = enemy

        if now - self.LastSolve < CONFIG.DodgeSolveInterval then
            local urgent = CONFIG.DodgeUrgentResolve
                and (self.LastDodgeReason == "bullseye"
                    or (not self.CachedDodging
                        and self.Hazards:GetOverlapCountAt(origin, targetYaw) > 0))

            if not urgent then
                self.IsDodging = self.CachedDodging
                return self.CachedDirection,
                    self.CachedYaw,
                    self.CachedEmergency,
                    self.CachedDodging
            end
        end

        self.LastSolve = now
        self.SelectedAuraPoint = nil
        self.AuraThreat = nil
        self.AuraThreatDistance = nil
        self.IncomingProjectile = nil

        local direction, yaw, emergency
        local dodging = false
        local reason = nil

        -- 0) Cube Pylon bullseye: go to the safe ring and wait there.
        direction, yaw, emergency = self:GetBullseyeEscape(targetYaw)
        if direction then
            dodging = true
            reason = "bullseye"
        end

        -- 1) Already inside an attack: get out.
        if not direction then
            direction, yaw, emergency = self:GetActiveHitboxEscape(targetYaw)
            if direction then
                dodging = true
                reason = "hitbox"
            end
        end

        -- 2) Crystal Golem thin sweeper.
        if not direction then
            direction, yaw, emergency = self:GetCrystalGolemSweeperEscape(enemy, targetYaw)
            if direction then
                dodging = true
                reason = "sweeper"
            end
        end

        -- 3) Melee panic.
        if not direction then
            direction, yaw, emergency = self:GetMeleePanicEscape(targetYaw, routeDirection)
            if direction then
                dodging = true
                reason = "melee"
            end
        end

        local preferred = self:GetCombatPreferred(routeDirection, enemy, targetYaw)

        -- 4) Is the next bit of movement actually threatened?
        local danger = false
        if not direction then
            danger = self:IsImmediateHazardDanger(preferred, targetYaw)
        end

        if danger or direction then
            self.LastDangerTime = now
        end

        if danger and preferred.Magnitude <= 0 then
            preferred = unit(flatten(routeDirection))
            if preferred.Magnitude <= 0 then
                preferred = unit(flatten(root.CFrame.LookVector))
            end
        end

        -- Keep a recent escape lane while it stays fully safe.
        local committed = self.CommittedDodgeDirection
        local withinCommit = committed.Magnitude > 0
            and now < self.DodgeCommitUntil
            and now - self.LastDangerTime <= CONFIG.DodgeCommitTime + CONFIG.DodgeReleaseGrace

        if not direction and withinCommit then
            local probe = CONFIG.DodgeReuseProbeDistance
            local reusable = self.Geometry:IsDirectionClear(committed, probe, targetYaw)
                and self.Geometry:IsGroundPadded(origin + committed * probe, CONFIG.EdgeHardPadding)
                and self.Hazards:IsTrajectoryClear(origin, committed, targetYaw, probe)
                and self.Hazards:IsPredictiveTrajectoryClear(origin, committed, targetYaw, probe)
                and self.Hazards:IsPrecastTrajectoryClear(origin, committed, targetYaw, probe)

            if reusable then
                direction, yaw, emergency = committed, targetYaw, false
                dodging = true
                reason = "committed"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindExpandingAuraDodge(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "aura"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindNormalDodge(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "normal"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindEmergencyOrientation(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "orientation"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindLeastRiskEscape(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "least-risk"
            end
        end

        -- Nothing passed: step away from the threat rather than freezing.
        if not direction and danger then
            local sourcePart = (self.AuraThreat and self.AuraThreat.Part)
                or (self.IncomingProjectile and self.IncomingProjectile.Part)
            local awayDirection = Vector3.zero

            if sourcePart and sourcePart.Parent then
                awayDirection = unit(flatten(origin - sourcePart.Position))
            end

            if awayDirection.Magnitude > 0
                and self.Geometry:IsDirectionClear(awayDirection, 3, targetYaw)
                and self.Geometry:HasGround(origin + awayDirection * 3)
            then
                direction = awayDirection
            else
                direction = Vector3.zero
            end

            yaw, emergency, dodging = targetYaw, false, true
            reason = "fallback"
        end

        -- 5) No danger: normal movement.
        if not direction then
            if self.RetreatActive and not self.ForceRouteMovement then
                direction = self:FindOpenMovement(preferred, targetYaw)
            elseif self.ForceRouteMovement or self.TravelMode then
                direction = preferred
            else
                direction = self:FindOpenMovement(preferred, targetYaw)
            end
            yaw = targetYaw
            emergency = false
            dodging = false
        end

        direction = direction or Vector3.zero
        yaw = yaw or targetYaw
        emergency = emergency or false

        self.CachedDirection = direction
        self.CachedYaw = yaw
        self.CachedEmergency = emergency
        self.CachedDodging = dodging
        self.IsDodging = dodging
        self.LastDodgeReason = reason

        if reason == "bullseye" then
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
        elseif dodging and direction.Magnitude > 0 then
            local changedLane = self.CommittedDodgeDirection.Magnitude <= 0
                or direction:Dot(self.CommittedDodgeDirection) < 0.60
                or now >= self.DodgeCommitUntil

            if changedLane then
                self.CommittedDodgeDirection = unit(flatten(direction))
                self.DodgeCommitUntil = now + CONFIG.DodgeCommitTime
            end
        elseif now - self.LastDangerTime > CONFIG.DodgeReleaseGrace then
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
        end

        if direction.Magnitude > 0 then
            self.LastMovement = direction
        end

        return direction, yaw, emergency, dodging
    end

    ---------------------------------------------------------------------------
    -- CombatController
    ---------------------------------------------------------------------------
    local legacyGetTool = CombatController.GetTool

    function CombatController:GetTool(slot)
        self.ToolCache = self.ToolCache or {}

        local now = os.clock()
        local entry = self.ToolCache[slot]

        if entry and now - entry.Time < 0.5 then
            local tool = entry.Tool
            if tool == nil then
                return nil
            end

            local parent = tool.Parent
            if parent ~= nil
                and (parent == LocalPlayer.Backpack or parent == LocalPlayer.Character)
            then
                return tool
            end
        end

        local tool = legacyGetTool(self, slot)
        self.ToolCache[slot] = { Tool = tool, Time = now }
        return tool
    end

    function CombatController:CanSendInput()
        local ok, focused = pcall(function()
            return UserInputService:GetFocusedTextBox()
        end)
        return not (ok and focused)
    end

    function CombatController:GetPreparationState()
        local state = {
            HasDamage = false,
            HasBuff = false,
            DamageReady = true,
            BuffReady = true,
            DamageWait = 0,
            BuffWait = 0,
            LongestWait = 0,
            BuffWorthWaiting = false,
            AnyDamageReady = false,
        }

        for _, slot in ipairs(SLOTS) do
            local tool = self:GetTool(slot)
            if tool then
                local remaining = self:GetCooldownRemaining(slot) or 0
                local ready = self:IsSlotCooldownReady(slot)

                if self:IsBuffTool(tool) then
                    state.HasBuff = true
                    state.BuffWait = math.max(state.BuffWait, remaining)
                    if not ready then
                        state.BuffReady = false
                    end
                else
                    state.HasDamage = true
                    state.DamageWait = math.max(state.DamageWait, remaining)
                    if not ready then
                        state.DamageReady = false
                    else
                        state.AnyDamageReady = true
                    end
                end
            end
        end

        state.LongestWait = math.max(state.DamageWait, state.BuffWait)

        -- If damage is cooling longer than the buff anyway, waiting for the
        -- buff costs nothing.
        state.BuffWorthWaiting = state.HasBuff
            and not state.BuffReady
            and state.BuffWait <= math.max(CONFIG.BuffMaxWait, state.DamageWait)

        return state
    end

    function CombatController:GetLosIgnoreList()
        local now = os.clock()
        if self.LosIgnore and now - (self.LosIgnoreAt or 0) < 1 then
            return self.LosIgnore
        end

        local list = {}

        if self.CharacterService.Character then
            table.insert(list, self.CharacterService.Character)
        end

        for _, name in ipairs({ "UIW_HitboxESP", "UnderworldHitboxESP", "UIW_PathESP", "UIW_TacticalDisplay" }) do
            local folder = Workspace:FindFirstChild(name)
            if folder then
                table.insert(list, folder)
            end
        end

        local dungeon = Workspace:FindFirstChild("dungeon")
        if dungeon then
            for _, room in ipairs(dungeon:GetChildren()) do
                local enemyFolder = room:FindFirstChild("enemyFolder")
                if enemyFolder then
                    table.insert(list, enemyFolder)
                end
            end
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                table.insert(list, player.Character)
            end
        end

        self.LosIgnore = list
        self.LosIgnoreAt = now
        return list
    end

    function CombatController:HasLineOfSight(enemy)
        local root = self.CharacterService.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end

        local now = os.clock()
        local cache = self.LosCache
        if cache and cache.Model == enemy.Model and now - cache.Time < 0.15 then
            return cache.Value
        end

        local ignore = table.clone(self:GetLosIgnoreList())
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        params.RespectCanCollide = true

        local origin = root.Position + Vector3.new(0, 1.5, 0)
        local goal = enemy.Root.Position
        local clear = false

        for _ = 1, 8 do
            local delta = goal - origin
            if delta.Magnitude < 1 then
                clear = true
                break
            end

            params.FilterDescendantsInstances = ignore
            local hit = Workspace:Raycast(origin, delta, params)

            if not hit or hit.Instance:IsDescendantOf(enemy.Model) then
                clear = true
                break
            end

            local instance = hit.Instance
            local passable = instance ~= Workspace.Terrain
                and (
                    (instance:IsA("BasePart") and instance.Transparency >= 0.9)
                    or isEntryInstance(instance)
                )

            if not passable then
                break
            end

            table.insert(ignore, getEntryAncestor(instance) or instance)
        end

        self.LosCache = { Model = enemy.Model, Time = now, Value = clear }
        return clear
    end

    -- v41: a target on another level (stairs / ledges) or behind geometry is
    -- "blocked": keep following the path to it instead of fighting from below.
    function CombatController:IsTargetBlocked(enemy)
        local root = self.CharacterService.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end

        local offset = enemy.Root.Position - root.Position
        local isBoss = isBossEnemy(enemy)
        if not isBoss and math.abs(offset.Y) > CONFIG.EngageMaxHeightDiff then
            return true
        end

        local distance = flatten(offset).Magnitude
        local losRange = isBoss and CONFIG.BossLosCheckRange or CONFIG.StageDistance
        if distance <= losRange and distance > CONFIG.LosBypassDistance then
            return not self:HasLineOfSight(enemy)
        end

        return false
    end

    function CombatController:GetAimYaw(enemy, fallbackYaw, enemies)
        local root = self.CharacterService.Root

        if not enemy or not enemy.Root or not enemy.Root.Parent or not root then
            self.LastAimModel = nil
            return fallbackYaw
        end

        local toTarget = flatten(enemy.Root.Position - root.Position)
        local distance = toTarget.Magnitude
        if distance < 0.05 then
            return fallbackYaw
        end

        local baseDirection = toTarget.Unit
        local bestDirection = baseDirection
        local bestOffset = 0
        local bestScore = -math.huge

        if distance <= CONFIG.DamageCastRange + 10
            and enemies
            and #enemies > 1
        then
            local halfWidth = CONFIG.CastHitboxWidth * 0.5
            local sameTarget = self.LastAimModel == enemy.Model

            for _, offset in ipairs({ 0, 6, -6, 12, -12, 18, -18, 24, -24 }) do
                if math.abs(offset) <= CONFIG.AimMaxOffsetDegrees then
                    local direction = unit(rotateXZ(baseDirection, offset))
                    local right = Vector3.new(-direction.Z, 0, direction.X)

                    -- The locked target must stay well inside the hitbox.
                    if toTarget:Dot(direction) >= 0
                        and math.abs(toTarget:Dot(right)) <= halfWidth * 0.6
                    then
                        local count = 0

                        for _, other in ipairs(enemies) do
                            if other.Root
                                and other.Root.Parent
                                and other.Humanoid
                                and other.Humanoid.Health > 0
                            then
                                local rel = flatten(other.Root.Position - root.Position)
                                local forward = rel:Dot(direction)
                                if forward >= -2
                                    and forward <= CONFIG.DamageCastRange
                                    and math.abs(rel:Dot(right)) <= halfWidth + 1.5
                                then
                                    count += 1
                                end
                            end
                        end

                        local score = count * 10 - math.abs(offset) * 0.15
                        if sameTarget and offset == self.LastAimOffset then
                            score += 3 -- hysteresis, avoids aim flicker
                        end

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestOffset = offset
                        end
                    end
                end
            end
        end

        local yaw = directionToYaw(bestDirection)
        self.LastAimModel = enemy.Model
        self.LastAimYaw = yaw
        self.LastAimOffset = bestOffset
        return yaw
    end

    function CombatController:IsFacing(yaw, toleranceDegrees)
        local root = self.CharacterService.Root
        if not root then
            return false
        end

        local look = unit(flatten(root.CFrame.LookVector))
        if look.Magnitude <= 0 then
            return false
        end

        local dot = math.clamp(look:Dot(yawToDirection(yaw)), -1, 1)
        return math.deg(math.acos(dot)) <= toleranceDegrees
    end

    -- v40 staging: wait just outside cast range until the attack is ready,
    -- even while navigating (the old version only held in a tiny band).
    function CombatController:ShouldHoldApproach(enemy, travelMode)
        self.CooldownHolding = false

        if not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or not self.CharacterService:IsAlive()
        then
            self:ClearCommit()
            self.ReadySince = nil
            return false
        end

        if isBossEnemy(enemy) then
            return false
        end

        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude

        if distance > CONFIG.StageDistance or distance <= CONFIG.DamageCastRange then
            self.ReadySince = nil
            return false
        end

        local state = self:GetPreparationState()
        if not state.HasDamage then
            return false
        end

        local now = os.clock()

        local function hold()
            self.CooldownHolding = true
            return true
        end

        -- Buff already cast: wait out the cast lock, then commit.
        if self:IsCommitArmed(enemy) then
            if self:IsBusyCasting() then
                return hold()
            end
            if state.DamageReady then
                return false
            end
            return hold()
        end

        if not state.DamageReady then
            self.ReadySince = nil
            -- v42: leave early so skills come off cooldown right as we arrive.
            local speed = math.max(self.CharacterService.Humanoid and self.CharacterService.Humanoid.WalkSpeed or 16, 1)
            local travelTime = math.max(0, distance - CONFIG.DamageCastRange) / speed
            if not state.AnyDamageReady and state.DamageWait > travelTime + CONFIG.CommitLeadTime then
                return hold()
            end
            if state.AnyDamageReady then
                return false
            end
            return false
        end

        if state.HasBuff then
            if state.BuffReady then
                -- Update() casts the buff from here. If it never fires, stop waiting.
                self.ReadySince = self.ReadySince or now
                if now - self.ReadySince > CONFIG.MaxStageHold then
                    return false
                end
                return hold()
            end

            self.ReadySince = nil
            if state.BuffWorthWaiting then
                return hold()
            end
        end

        return false
    end

    -- v40 hit & run: after a damage cast on normal mobs, back off until the
    -- damage skills are nearly ready again.
    function CombatController:ShouldRetreat(enemy)
        self.RetreatActive = false

        if not CONFIG.HitAndRun
            or not self.RetreatArmed
            or not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or isBossEnemy(enemy)
            or not self.CharacterService:IsAlive()
        then
            self.RetreatArmed = false
            return false
        end

        local now = os.clock()
        local state = self:GetPreparationState()

        -- Cooldown values can lag a frame behind the key press.
        if now - (self.RetreatArmedAt or 0) > 0.5 then
            if state.AnyDamageReady or state.DamageWait <= CONFIG.RetreatResumeWait then
                self.RetreatArmed = false
                return false
            end
        end

        if now - (self.RetreatArmedAt or 0) > 20 then
            self.RetreatArmed = false
            return false
        end

        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance >= CONFIG.RetreatDistance then
            return false
        end

        self.RetreatActive = true
        return true
    end

    function CombatController:GetHoldText()
        if self:IsBusyCasting() then
            return "priming attack"
        end

        if self.RetreatActive then
            local s = self:GetPreparationState()
            return string.format("hit & run | backing off, damage ready in %.1fs", s.DamageWait)
        end

        local state = self:GetPreparationState()

        if not state.DamageReady then
            return string.format("waiting damage cooldown | %.1fs", state.DamageWait)
        end

        if state.HasBuff and not state.BuffReady then
            return string.format("waiting buff | %.1fs", state.BuffWait)
        end

        if state.HasBuff then
            return "casting buff before engaging"
        end

        return "attack ready | holding aggro line"
    end

    function CombatController:Update(enemy)
        self.LastAction = nil
        self.LastBlockReason = nil

        if not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or not self.CharacterService:IsAlive()
        then
            self:ClearCommit()
            return false
        end

        if not self:CanSendInput() then
            self.LastBlockReason = "chat focused"
            return false
        end

        if CONFIG.NoCastWhileEscaping and self.EscapingHitbox then
            self.LastBlockReason = "escaping hitbox"
            return false
        end

        local root = self.CharacterService.Root
        local distance = flatten(enemy.Root.Position - root.Position).Magnitude
        local inRange = distance <= CONFIG.DamageCastRange
        local staging = not inRange and distance <= CONFIG.StageDistance

        local state = self:GetPreparationState()

        local aimYaw = (self.LastAimModel == enemy.Model and self.LastAimYaw)
            or directionToYaw(flatten(enemy.Root.Position - root.Position))

        local losOk = nil

        for _, slot in ipairs(SLOTS) do
            local tool = self:GetTool(slot)

            if tool and self:IsReady(slot) then
                local isBuff = self:IsBuffTool(tool)
                local allowed = false

                if isBuff then
                    allowed = inRange or (staging and state.DamageReady)
                elseif inRange then
                    if not self:IsFacing(aimYaw, CONFIG.CastFacingTolerance) then
                        self.LastBlockReason = "turning to target"
                    else
                        if losOk == nil then
                            losOk = distance <= CONFIG.LosBypassDistance
                                or self:HasLineOfSight(enemy)
                        end

                        if losOk then
                            allowed = true
                        else
                            self.LastBlockReason = "no line of sight"
                        end
                    end
                end

                if allowed then
                    if isBuff then
                        if staging then
                            self:ArmCommit(enemy)
                        end
                    else
                        self:ClearCommit()
                        if not isBossEnemy(enemy) then
                            self.RetreatArmed = true
                            self.RetreatArmedAt = os.clock()
                        end
                    end

                    self:Press(slot)
                    return true
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- UIWController: aim at the best spot instead of dead-center on the target
    ---------------------------------------------------------------------------
    local legacyGetTargetYaw = UIWController.GetTargetYaw

    function UIWController:GetTargetYaw()
        local base = legacyGetTargetYaw(self)
        return self.Combat:GetAimYaw(
            self.CurrentEnemy,
            base,
            self.Dungeon:GetAliveEnemies()
        )
    end

    ---------------------------------------------------------------------------
    -- HUD
    ---------------------------------------------------------------------------
    local legacySetStatus = HUD.SetStatus
    local EXTRA_STATUS_COLORS = {
        MECHANIC = Color3.fromRGB(80, 220, 235),
        PROGRESSION = COLORS.Pathing,
    }

    function HUD:SetStatus(action, text)
        local combat = self.Controller and self.Controller.Combat
        if combat
            and combat.LastBlockReason
            and (action == "MOVING" or action == "RUNNING")
        then
            text = tostring(text or action) .. " | " .. combat.LastBlockReason
        end

        legacySetStatus(self, action, text)

        local color = EXTRA_STATUS_COLORS[action]
        if color then
            self.Accent.BackgroundColor3 = color
            self.Badge.TextColor3 = color
        end
    end

    print("[UIW] v42 combat + dodge section applied")
end
