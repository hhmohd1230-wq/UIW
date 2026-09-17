local DodgeSolver = {}
DodgeSolver.__index = DodgeSolver

function DodgeSolver.new(characterService, hazards, geometry, dungeon)
    return setmetatable({
        CharacterService = characterService,
        Hazards = hazards,
        Geometry = geometry,
        Dungeon = dungeon,

        LastSolve = 0,
        CachedDirection = Vector3.zero,
        CachedYaw = 0,
        CachedEmergency = false,
        CachedDodging = false,

        LastMovement = Vector3.zero,
        OrbitSign = 1,
        LastOrbitFlip = 0,
        IsDodging = false,
        MeleePanicActive = false,
        TravelMode = true,
        TravelExitCandidateSince = 0,
        CooldownHold = false,
        ForceRouteMovement = false,
        ForcedRegionPart = nil,
        CommittedDodgeDirection = Vector3.zero,
        DodgeCommitUntil = 0,
        LastDangerTime = 0,
        CurrentSolveEnemy = nil,
    }, DodgeSolver)
end

function DodgeSolver:IsPointInsideForcedRegion(position)
    local part = self.ForcedRegionPart

    if not part or not part.Parent or not part:IsA("BasePart") then
        return false
    end

    local localPoint = part.CFrame:PointToObjectSpace(position)

    local inset = math.min(
        CONFIG.GolemForcedRegionInset,
        math.min(part.Size.X, part.Size.Z) * 0.18
    )

    local halfX = math.max(part.Size.X * 0.5 - inset, part.Size.X * 0.25)
    local halfZ = math.max(part.Size.Z * 0.5 - inset, part.Size.Z * 0.25)

    return math.abs(localPoint.X) <= halfX
        and math.abs(localPoint.Z) <= halfZ
end

function DodgeSolver:HasCrystalGolemFollowOrb()
    for _, data in ipairs(self.Hazards:GetActive()) do
        local part = data.Part

        if part and part.Parent then
            local container = data.Container or self.Hazards:GetContainer(part)

            if container
                and string.lower(container.Name or "") == "enchantedfirstbossfolloworb"
            then
                return true
            end
        end
    end

    return false
end

function DodgeSolver:GetCrystalGolemSweeperThreatPart()
    if not self.CharacterService:IsAlive() then
        return nil
    end

    local model = Workspace:FindFirstChild("firstBossSpinningRockHitbox")

    if not model then
        return nil
    end

    local root = self.CharacterService.Root

    local bestPart = nil
    local bestPerpendicular = math.huge

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and string.lower(part.Name or "") == "hitbox" then
            local localPoint = part.CFrame:PointToObjectSpace(root.Position)

            local thinIsX = part.Size.X <= part.Size.Z

            local thinCoord = thinIsX and localPoint.X or localPoint.Z
            local longCoord = thinIsX and localPoint.Z or localPoint.X

            local thinHalf = (thinIsX and part.Size.X or part.Size.Z) * 0.5
            local longHalf = (thinIsX and part.Size.Z or part.Size.X) * 0.5

            local insideHeight = math.abs(localPoint.Y) <= part.Size.Y * 0.5 + 5

            local insideSweepLength = math.abs(longCoord)
                <= longHalf + CONFIG.GolemSweeperEndpointPadding

            local perpendicularDistance = math.max(0, math.abs(thinCoord) - thinHalf)

            if insideHeight
                and insideSweepLength
                and perpendicularDistance <= CONFIG.GolemSweeperLeadDistance
                and perpendicularDistance < bestPerpendicular
            then
                bestPerpendicular = perpendicularDistance
                bestPart = part
            end
        end
    end

    return bestPart
end

function DodgeSolver:GetCrystalGolemSweeperEscape(enemy, targetYaw)
    if not enemy
        or not enemy.Model
        or not enemy.Root
        or not enemy.Root.Parent
        or normalizeEnemyName(enemy.Model.Name) ~= "crystal golem"
    then
        return nil
    end

    local threatPart = self:GetCrystalGolemSweeperThreatPart()

    if not threatPart then
        return nil
    end

    local root = self.CharacterService.Root

    local radial = unit(flatten(root.Position - enemy.Root.Position))

    if radial.Magnitude <= 0 then
        return nil
    end

    local counterClockwise = unit(Vector3.new(-radial.Z, 0, radial.X))

    local bestDirection = nil
    local bestScore = -math.huge

    for _, angle in ipairs({0, 15, -15, 30, -30, 50, -50, 80, -80, 110, -110}) do
        local direction = unit(rotateXZ(counterClockwise, angle))

        local score = self:ScoreCandidate(direction, counterClockwise, targetYaw)

        if score then
            local future = root.Position + direction * 7

            local localFuture = threatPart.CFrame:PointToObjectSpace(future)

            local thinIsX = threatPart.Size.X <= threatPart.Size.Z

            local futureThin = math.abs(thinIsX and localFuture.X or localFuture.Z)

            score += direction:Dot(counterClockwise) * 220
            score += futureThin * 8

            if score > bestScore then
                bestScore = score
                bestDirection = direction
            end
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end

    return nil
end

-- v40: bosses are fought from a distance band, not face-to-face.
local function bossBandError(distance)
    return math.max(0, CONFIG.BossMinRange - distance)
        + math.max(0, distance - CONFIG.BossMaxRange)
end

function DodgeSolver:GetBossBandScore(fromPosition, toPosition)
    local boss = self.CurrentSolveEnemy
    if not boss or not isBossEnemy(boss) or not boss.Root or not boss.Root.Parent then
        return 0
    end
    local before = bossBandError(flatten(boss.Root.Position - fromPosition).Magnitude)
    local after = bossBandError(flatten(boss.Root.Position - toPosition).Magnitude)
    local score = (before - after) * 120
    if after > before + 1 then
        score -= 300
    end
    return score
end

function DodgeSolver:GetBossBandError(position)
    local boss = self.CurrentSolveEnemy
    if not boss or not isBossEnemy(boss) or not boss.Root or not boss.Root.Parent then
        return 0
    end
    return bossBandError(flatten(boss.Root.Position - position).Magnitude)
end

function DodgeSolver:IsMeleeEnemy(enemy)
    return getEnemyThreatClass(enemy) ~= nil
end

function DodgeSolver:GetSafeOrbitTangent(toward, targetYaw)
    local root = self.CharacterService.Root
    local baseTangent = Vector3.new(-toward.Z, 0, toward.X)

    local right = unit(baseTangent)
    local left = -right

    local function sideSafe(direction)
        local endpoint = root.Position + direction * 7
        return self.Geometry:IsDirectionClear(direction, 7, targetYaw)
            and self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding)
    end

    local rightSafe = sideSafe(right)
    local leftSafe = sideSafe(left)

    local desired = self.OrbitSign >= 0 and right or left
    local desiredSafe = self.OrbitSign >= 0 and rightSafe or leftSafe
    local opposite = self.OrbitSign >= 0 and left or right
    local oppositeSafe = self.OrbitSign >= 0 and leftSafe or rightSafe

    if not desiredSafe and oppositeSafe then
        self.OrbitSign = -self.OrbitSign
        self.LastOrbitFlip = os.clock()
        return opposite
    end

    if desiredSafe then
        return desired
    end

    if oppositeSafe then
        self.OrbitSign = -self.OrbitSign
        self.LastOrbitFlip = os.clock()
        return opposite
    end

    return desired
end

function DodgeSolver:GetNearestLiveEnemyDistance()
    if not self.CharacterService:IsAlive() then
        return math.huge
    end

    local root = self.CharacterService.Root
    local nearest = math.huge

    for _, candidate in ipairs(self.Dungeon:GetAliveEnemies()) do
        if candidate
            and candidate.Root
            and candidate.Root.Parent
            and candidate.Humanoid
            and candidate.Humanoid.Health > 0
        then
            local distance = flatten(candidate.Root.Position - root.Position).Magnitude
            if distance < nearest then
                nearest = distance
            end
        end
    end

    return nearest
end

function DodgeSolver:UpdateNavigationMode(routeDirection, enemy, targetYaw)
    -- v41: target on another level / out of sight: keep following the path.
    if self.TargetBlocked then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local nearestDistance = self:GetNearestLiveEnemyDistance()

    if nearestDistance > CONFIG.NavigationEnterDistance then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    if nearestDistance > CONFIG.NavigationExitDistance then
        self.TravelExitCandidateSince = 0
        return self.TravelMode
    end

    if not enemy or not enemy.Root or not enemy.Root.Parent then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    routeDirection = unit(flatten(routeDirection))

    if routeDirection.Magnitude <= 0 then
        self.TravelExitCandidateSince = 0
        return self.TravelMode
    end

    local root = self.CharacterService.Root
    local toEnemy = flatten(enemy.Root.Position - root.Position)
    local toward = unit(toEnemy)

    if toward.Magnitude <= 0 then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local routeDot = routeDirection:Dot(toward)

    local probeDistance = math.min(toEnemy.Magnitude, CONFIG.TravelDirectProbeDistance)

    local directClear = self.Geometry:IsDirectionClear(toward, probeDistance, targetYaw)

    if not directClear or routeDot < CONFIG.TravelRouteDetourDot then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local now = os.clock()

    if self.TravelMode then
        if self.TravelExitCandidateSince <= 0 then
            self.TravelExitCandidateSince = now
            return true
        end

        if now - self.TravelExitCandidateSince < CONFIG.NavigationExitConfirmTime then
            return true
        end
    end

    self.TravelMode = false
    self.TravelExitCandidateSince = 0
    return false
end

function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
    routeDirection = unit(flatten(routeDirection))

    if self.ForceRouteMovement then
        return routeDirection
    end

    local navigating = self:UpdateNavigationMode(routeDirection, enemy, targetYaw)

    local meleeTravelOverride = false

    if navigating and enemy and enemy.Root and enemy.Root.Parent then
        local threatClass = getEnemyThreatClass(enemy)

        if threatClass then
            local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
            local overrideDistance = CONFIG.MeleeTravelOverrideDistance

            if threatClass == "Proximity" then
                overrideDistance += CONFIG.ProximitySafetyBonus
            end

            -- STAIRS/WALL FIX: Do not pull off the yellow path if a wall is in the way!
            local toward = unit(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
            local directClear = true
            if toward.Magnitude > 0 then
                directClear = self.Geometry:IsDirectionClear(toward, math.min(distance, overrideDistance), targetYaw)
            end

            if distance <= overrideDistance and directClear and not self.TargetBlocked then
                meleeTravelOverride = true
                self.TravelMode = false
                self.TravelExitCandidateSince = 0
            end
        end
    end

    -- v40 hit & run: back away from the target while damage skills recover.
    if self.RetreatActive and enemy and enemy.Root and enemy.Root.Parent then
        local away = unit(flatten(self.CharacterService.Root.Position - enemy.Root.Position))
        if away.Magnitude > 0 then
            return unit(away - routeDirection * 0.35)
        end
    end

    -- v40: cooldown staging holds position even while navigating.
    if self.CooldownHold
        and enemy
        and not isBossEnemy(enemy)
        and not (enemy.Model and normalizeEnemyName(enemy.Model.Name) == "crystal golem")
    then
        return Vector3.zero
    end

    if navigating and not meleeTravelOverride then
        return routeDirection
    end

    if not enemy or not enemy.Root or not enemy.Root.Parent then
        return routeDirection
    end

    local root = self.CharacterService.Root
    local toEnemy = flatten(enemy.Root.Position - root.Position)
    local distance = toEnemy.Magnitude
    local toward = unit(toEnemy)

    if toward.Magnitude <= 0 then
        return routeDirection
    end

    local enemyName = enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name) or ""

    local crystalGolem = enemyName == "crystal golem"

    local bossTarget = isBossEnemy(enemy)

    if self.CooldownHold and not bossTarget and not crystalGolem then
        return Vector3.zero
    end

    local tangent = self:GetSafeOrbitTangent(toward, targetYaw)

    if crystalGolem then
        local counterClockwise = unit(Vector3.new(toward.Z, 0, -toward.X))

        if counterClockwise.Magnitude <= 0 then
            counterClockwise = tangent
        end

        local orbLive = self:HasCrystalGolemFollowOrb()

        if distance > CONFIG.GolemOrbitOuter then
            return unit(counterClockwise * 0.82 + toward * 0.72)
        elseif distance < CONFIG.GolemOrbitInner then
            return unit(counterClockwise * 1.05 - toward * 0.58)
        elseif orbLive then
            return unit(counterClockwise * 1.10 - toward * CONFIG.GolemOrbKiteBias)
        else
            return counterClockwise
        end
    end

    if bossTarget then
        -- v40: hold the boss inside [BossMinRange, BossMaxRange] (all within
        -- cast range) and circle slowly; no need to stand on top of it.
        if distance > CONFIG.BossMaxRange then
            return unit(toward * 1.45 + routeDirection * 0.35 + tangent * 0.10)
        elseif distance < CONFIG.BossMinRange then
            return unit(-toward * 1.0 + tangent * 0.70)
        else
            local correction = math.clamp((distance - CONFIG.BossIdealRange) / 12, -1, 1)
            return tangent * 0.45 + toward * (0.25 * correction)
        end
    end

    if self:IsMeleeEnemy(enemy) then
        if distance > CONFIG.MeleeOrbitOuter then
            return unit(toward * 1.02 + routeDirection * 0.72 + tangent * 0.22)
        elseif distance > CONFIG.MeleeOrbitInner then
            return unit(tangent * 0.92 + toward * 0.30 + routeDirection * 0.34)
        elseif distance > CONFIG.MeleeEmergencyRadius then
            return unit(tangent * 1.00 - toward * 0.22 + routeDirection * 0.22)
        else
            return unit(tangent * 1.00 - toward * 0.70 + routeDirection * 0.10)
        end
    end

    if distance < CONFIG.MinimumCombatRange then
        return unit(-toward * 0.72 + tangent * 0.95 + routeDirection * 0.14)
    elseif distance > CONFIG.AggressiveApproachDistance then
        return unit(toward * 1.00 + routeDirection * 0.82 + tangent * 0.06)
    elseif distance > CONFIG.DesiredCombatRange then
        return unit(toward * 0.82 + routeDirection * 0.70 + tangent * 0.12)
    else
        return unit(tangent * 0.82 + routeDirection * 0.42 + toward * 0.18)
    end
end

function DodgeSolver:GetMeleePenalty(position)
    local penalty = 0

    for _, info in ipairs(self.Dungeon:GetMeleeThreats(position, 55)) do
        local distance = info.Distance
        local safetyRadius = CONFIG.MeleeSafetyRadius
        local emergencyRadius = CONFIG.MeleeEmergencyRadius

        if info.ThreatClass == "Proximity" then
            safetyRadius += CONFIG.ProximitySafetyBonus
            emergencyRadius += CONFIG.ProximityEmergencyBonus
        end

        if distance <= CONFIG.MeleeHardNoGoRadius then
            penalty += 12000
        elseif distance <= emergencyRadius then
            penalty += 4000 + (emergencyRadius - distance) * 650
        elseif distance < safetyRadius then
            penalty += (safetyRadius - distance) * 400
        end
    end

    return penalty
end

function DodgeSolver:GetEnchantedForestLineEscapeBonus(direction)
    local root = self.CharacterService.Root

    if not root then
        return 0
    end

    local bestBonus = 0

    for _, data in ipairs(self.Hazards:GetActive()) do
        local part = data.Part

        if part and part.Parent then
            local container = data.Container or self.Hazards:GetContainer(part)
            local containerName = container and string.lower(container.Name or "") or ""

            if containerName == "mushroomwizardshot"
                or containerName == "magebossstrraightshot"
                or containerName == "magebossstraightshot"
                or containerName == "magehorizontalbeam"
            then
                local size = part.Size
                local longest = math.max(size.X, size.Z)
                local shortest = math.min(size.X, size.Z)

                if longest >= 45 and shortest <= 12 then
                    local longAxis

                    if size.X >= size.Z then
                        longAxis = flatten(part.CFrame.RightVector)
                    else
                        longAxis = flatten(part.CFrame.LookVector)
                    end

                    longAxis = unit(longAxis)

                    local perpendicularity = 1 - math.abs(direction:Dot(longAxis))

                    bestBonus = math.max(bestBonus, perpendicularity * 180)
                end
            end
        end
    end

    return bestBonus
end

function DodgeSolver:ScoreCandidate(direction, preferred, yaw)
    local rootPosition = self.CharacterService.Root.Position
    direction = unit(flatten(direction))

    local clear = self.Geometry:IsDirectionClear(direction, CONFIG.DodgeDistance, yaw)
    if not clear then
        return nil
    end

    local future = rootPosition + direction * math.min(7, CONFIG.DodgeDistance)

    if self.ForcedRegionPart
        and self:IsPointInsideForcedRegion(rootPosition)
        and not self:IsPointInsideForcedRegion(future)
    then
        return nil
    end

    if not self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding) then
        return nil
    end

    if not self.Hazards:IsTrajectoryClear(rootPosition, direction, yaw, CONFIG.DodgeDistance) then
        return nil
    end

    if not self.Hazards:IsPredictiveTrajectoryClear(rootPosition, direction, yaw, CONFIG.DodgeDistance) then
        return nil
    end

    local warningDistance = math.max(CONFIG.DodgeDistance,
        math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed) * CONFIG.PrecastLookaheadTime)
    if not self.Hazards:IsPrecastTrajectoryClear(rootPosition, direction, yaw, warningDistance) then return nil end

    local solvingBoss = self.CurrentSolveEnemy
        and isBossEnemy(self.CurrentSolveEnemy)
    local progressWeight = solvingBoss and 220
        or (self.AuraThreat and 175 or 130)
    local score = direction:Dot(preferred) * progressWeight

    score += self:GetBossBandScore(rootPosition, future)

    local auraPart = self.AuraThreat and self.AuraThreat.Part
    if auraPart and auraPart.Parent then
        local awayFromThreat = unit(flatten(rootPosition - auraPart.Position))
        if awayFromThreat.Magnitude > 0 then
            score += direction:Dot(awayFromThreat) * 190
        end
    end

    score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, CONFIG.DodgeDistance) * 3

    score += self:GetEnchantedForestLineEscapeBonus(direction)

    score -= self:GetMeleePenalty(future)
    score += self.Geometry:GetEdgeClearanceScore(future) * 22

    if self.LastMovement.Magnitude > 0 then
        score += direction:Dot(self.LastMovement) * 12
    end

    return score
end

function DodgeSolver:FindExpandingAuraDodge(preferred, targetYaw)
    local rootPosition = self.CharacterService.Root.Position
    preferred = unit(flatten(preferred))
    if preferred.Magnitude <= 0 then
        preferred = unit(flatten(self.CharacterService.Root.CFrame.LookVector))
    end

    self.SelectedAuraPoint = nil

    local boss = self.CurrentSolveEnemy
    local solvingBoss = boss
        and isBossEnemy(boss)
        and boss.Root
        and boss.Root.Parent
    local towardBoss = solvingBoss
        and unit(flatten(boss.Root.Position - rootPosition))
        or Vector3.zero
    local bossForwardDirection, bossForwardPoint, bossForwardScore = nil, nil, -math.huge
    local bossEmergencyDirection, bossEmergencyPoint, bossEmergencyScore = nil, nil, -math.huge

    for _, radius in ipairs(CONFIG.AuraScanRadii) do
        local bestDirection = nil
        local bestPoint = nil
        local bestScore = -math.huge

        for index = 1, CONFIG.AuraDotsPerRing do
            local angle = ((index - 1) / CONFIG.AuraDotsPerRing) * 360
            local direction = unit(rotateXZ(preferred, angle))
            local point = rootPosition + direction * radius

            local safe = self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding)
                and self.Geometry:IsDirectionClear(direction, radius, targetYaw)
                and self.Hazards:GetPointThreat(point) <= 0
                and not self.Dungeon:GetEnemyDangerAt(point)
                and self.Hazards:IsTrajectoryClear(rootPosition, direction, targetYaw, radius)
                and self.Hazards:IsPredictiveTrajectoryClear(rootPosition, direction, targetYaw, radius)

            if safe then
                local bossAdvance = solvingBoss and direction:Dot(towardBoss) or 0
                local score = direction:Dot(preferred) * (solvingBoss and 180 or 220)
                score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, radius) * 4
                score += self.Geometry:GetEdgeClearanceScore(point) * 20

                local auraPart = self.AuraThreat and self.AuraThreat.Part
                if auraPart and auraPart.Parent then
                    local away = unit(flatten(rootPosition - auraPart.Position))
                    score += direction:Dot(away) * (solvingBoss and 90 or 260)
                end

                if solvingBoss then
                    local futureBossDistance = flatten(boss.Root.Position - point).Magnitude
                    local bossScore = score
                        + bossAdvance * 700
                        - futureBossDistance * 18
                        - radius * 1.5

                    if bossAdvance >= -0.05 and bossScore > bossForwardScore then
                        bossForwardScore = bossScore
                        bossForwardDirection = direction
                        bossForwardPoint = point
                    end

                    if bossScore > bossEmergencyScore then
                        bossEmergencyScore = bossScore
                        bossEmergencyDirection = direction
                        bossEmergencyPoint = point
                    end
                elseif score > bestScore then
                    bestScore = score
                    bestDirection = direction
                    bestPoint = point
                end
            end
        end

        if not solvingBoss and bestDirection then
            self.SelectedAuraPoint = bestPoint
            return bestDirection, targetYaw, false
        end
    end

    if bossForwardDirection then
        self.SelectedAuraPoint = bossForwardPoint
        return bossForwardDirection, targetYaw, false
    end

    if bossEmergencyDirection then
        self.SelectedAuraPoint = bossEmergencyPoint
        return bossEmergencyDirection, targetYaw, false
    end

    return nil
end

function DodgeSolver:FindNormalDodge(preferred, targetYaw)
    local bestDirection = nil
    local bestScore = -math.huge

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local score = self:ScoreCandidate(direction, preferred, targetYaw)

        if score and score > bestScore then
            bestScore = score
            bestDirection = direction
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end

    return nil
end

function DodgeSolver:FindEmergencyOrientation(preferred, targetYaw)
    local bestDirection = nil
    local bestYaw = nil
    local bestScore = -math.huge

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local movementYaw = directionToYaw(direction)

        for _, yawOffset in ipairs(CONFIG.EmergencyBodyYawOffsets) do
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

function DodgeSolver:FindLeastRiskEscape(preferred, targetYaw)
    local rootPosition = self.CharacterService.Root.Position
    preferred = unit(flatten(preferred))
    local bestDirection = nil
    local bestScore = -math.huge
    local escapeDistance = 6

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local future = rootPosition + direction * escapeDistance
        if self.Geometry:IsDirectionClear(direction, escapeDistance, targetYaw)
            and self.Geometry:IsGroundPadded(future, math.min(6, CONFIG.EdgeHardPadding))
        then
            local score = direction:Dot(preferred) * 90
            score += self:GetBossBandScore(rootPosition, future)
            score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, escapeDistance) * 7
            score -= self:GetMeleePenalty(future)

            local auraPart = self.AuraThreat and self.AuraThreat.Part
            if auraPart and auraPart.Parent then
                local away = unit(flatten(rootPosition - auraPart.Position))
                score += direction:Dot(away) * 240
            end

            if score > bestScore then
                bestScore = score
                bestDirection = direction
            end
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end
    return nil
end

function DodgeSolver:GetActiveHitboxEscape(targetYaw)
    local root = self.CharacterService.Root
    local overlaps = self.Hazards:GetCurrentOverlaps(targetYaw)
    local currentOverlapCount = #overlaps

    if currentOverlapCount == 0 then
        return nil
    end

    local escape = Vector3.zero

    for _, part in ipairs(overlaps) do
        if part and part.Parent then
            local warningExit = self.Hazards:GetWarningExitDirection(part, root.Position)
            if warningExit then
                escape += warningExit
                continue
            end
            local localPoint = part.CFrame:PointToObjectSpace(root.Position)
            local half = part.Size * 0.5
            local xExit = half.X - math.abs(localPoint.X)
            local zExit = half.Z - math.abs(localPoint.Z)

            local localDirection

            if xExit < zExit then
                localDirection = Vector3.new(localPoint.X >= 0 and 1 or -1, 0, 0)
            else
                localDirection = Vector3.new(0, 0, localPoint.Z >= 0 and 1 or -1)
            end

            local worldDirection = flatten(part.CFrame:VectorToWorldSpace(localDirection))

            if worldDirection.Magnitude > 0 then
                escape += unit(worldDirection)
            end
        end
    end

    escape = unit(escape)

    if escape.Magnitude <= 0 then
        escape = unit(flatten(root.CFrame.LookVector))
    end

    local directions = {
        escape,
        unit(rotateXZ(escape, 25)),
        unit(rotateXZ(escape, -25)),
        unit(rotateXZ(escape, 50)),
        unit(rotateXZ(escape, -50)),
        unit(rotateXZ(escape, 90)),
        unit(rotateXZ(escape, -90)),
        -escape,
    }

    local bestDirection = nil
    local bestYaw = nil
    local bestScore = -math.huge

    for _, direction in ipairs(directions) do
        if direction.Magnitude > 0 then
            local movementYaw = directionToYaw(direction)

            local yawCandidates = {
                targetYaw,
                movementYaw,
                movementYaw + math.rad(90),
                movementYaw - math.rad(90),
            }

            for _, yaw in ipairs(yawCandidates) do
                if self.Geometry:IsDirectionClear(direction, 4, yaw) then
                    local future4 = root.Position + direction * 4
                    local future7 = root.Position + direction * 7

                    if self.Geometry:IsGroundPadded(future7, CONFIG.EdgeHardPadding) then
                        local count4 = self.Hazards:GetOverlapCountAt(future4, yaw)
                        local count7 = self.Hazards:GetOverlapCountAt(future7, yaw)

                        local score =
                            (currentOverlapCount - count4) * 420
                            + (currentOverlapCount - count7) * 760

                        if count7 == 0 then
                            score += 1800
                        end

                        score += self.Geometry:GetEdgeClearanceScore(future7) * 18

                        score -= math.abs(angleDifference(yaw, targetYaw)) * 3

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestYaw = yaw
                        end
                    end
                end
            end
        end
    end

    if bestDirection then
        return bestDirection, bestYaw, true
    end

    return nil
end

function DodgeSolver:GetMeleePanicEscape(targetYaw, routeDirection)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    -- (placeholder kept so the class shape stays the same)
    return nil
end

function DodgeSolver:IsImmediateHazardDanger(preferred, targetYaw)
    self.SelectedAuraPoint = nil
    self.AuraThreat = nil
    self.AuraThreatDistance = nil

    local root = self.CharacterService.Root

    if self.Hazards:GetOverlapCountAt(root.Position, targetYaw) > 0 then
        return true
    end

    local auraThreat, auraDistance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)

    self.AuraThreat = auraThreat
    self.AuraThreatDistance = auraDistance
    if auraThreat then
        return true
    end

    preferred = unit(flatten(preferred or Vector3.zero))

    local warningDistance = math.max(CONFIG.DangerLookaheadDistance,
        math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed) * CONFIG.PrecastLookaheadTime)
    if not self.Hazards:IsPrecastTrajectoryClear(root.Position, preferred, targetYaw, warningDistance) then
        return true
    end

    local incoming = self.Hazards:GetIncomingProjectileThreat(root.Position, preferred, targetYaw, CONFIG.DodgeDistance)

    if incoming then
        return true
    end

    if #self.Hazards:GetActive() == 0 then
        return false
    end

    if preferred.Magnitude <= 0 then
        return false
    end

    return not self.Hazards:IsTrajectoryClear(root.Position, preferred, targetYaw, CONFIG.DangerLookaheadDistance)
end

function DodgeSolver:FindOpenMovement(preferred, targetYaw)
    local root = self.CharacterService.Root
    preferred = unit(flatten(preferred))

    if preferred.Magnitude <= 0 then
        return Vector3.zero
    end

    for _, angle in ipairs({0, 20, -20, 40, -40, 65, -65, 90, -90, 120, -120, 150, -150, 180}) do
        local direction = unit(rotateXZ(preferred, angle))
        local future = root.Position + direction * 6

        if self.Geometry:IsDirectionClear(direction, 6, targetYaw)
            and self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding)
        then
            return direction
        end
    end

    return Vector3.zero
end

function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    local direction = self:GetCombatPreferred(routeDirection, enemy, targetYaw)
    return direction, targetYaw, false, false
end

