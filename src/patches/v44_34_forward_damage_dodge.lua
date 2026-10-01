-- Prefer a safe attacking lane over a backward dodge. Backward movement is
-- still available for immediate hitbox exits, melee panic, forced mechanics,
-- and emergencies where no forward candidate passes every safety check.
do
    CONFIG.ForwardDodgeMaxTargetDistance = 180
    CONFIG.ForwardDodgeBackwardDot = -0.05

    local KEEP_ESCAPE_REASON = {
        hitbox = true,
        bullseye = true,
        sweeper = true,
        ["tree-sweeper"] = true,
        melee = true,
        ["large-attack"] = true,
        fallback = true,
    }

    function DodgeSolver:FindForwardDamageDodge(enemy, targetYaw)
        local root = self.CharacterService.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return nil
        end

        local offset = flatten(enemy.Root.Position - root.Position)
        local distance = offset.Magnitude
        if distance <= 0.05 or distance > CONFIG.ForwardDodgeMaxTargetDistance then
            return nil
        end

        local toward = offset.Unit
        local probe = CONFIG.DodgeDistance
        local best, bestScore = nil, -math.huge

        -- Every option keeps some forward progress. Wider diagonals remain
        -- available for line and aura attacks without giving up attack range.
        for _, angle in ipairs({ 0, 22, -22, 42, -42, 62, -62, 80, -80 }) do
            local direction = unit(rotateXZ(toward, angle))
            local point = root.Position + direction * probe
            local after = flatten(enemy.Root.Position - point).Magnitude

            local keepsBossBand = not isBossEnemy(enemy)
                or distance < CONFIG.BossMinRange
                or after >= CONFIG.BossMinRange

            if keepsBossBand and not self.Dungeon:GetEnemyDangerAt(point) then
                local safety = self:ScoreCandidate(direction, toward, targetYaw)
                if safety then
                    local progress = distance - after
                    local score = safety + progress * 70
                    score += direction:Dot(toward) * 240

                    if after <= CONFIG.DamageCastRange - 3 then
                        score += 220
                    end
                    if self.LastMovement and self.LastMovement.Magnitude > 0 then
                        score += direction:Dot(self.LastMovement) * 15
                    end

                    if score > bestScore then
                        best, bestScore = direction, score
                    end
                end
            end
        end

        return best
    end

    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolve(self, routeDirection, enemy, targetYaw)
        if not direction or direction.Magnitude <= 0.05
            or not enemy or not enemy.Root or not enemy.Root.Parent
            or emergency or self.ForceRouteMovement or self.ForcedRegionPart
            or self.TargetBlocked or self.RetreatActive
            or KEEP_ESCAPE_REASON[self.LastDodgeReason or ""]
        then
            return direction, yaw, emergency, dodging
        end

        local toward = unit(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
        local moving = unit(flatten(direction))
        if toward.Magnitude <= 0.05
            or moving:Dot(toward) >= CONFIG.ForwardDodgeBackwardDot
        then
            return direction, yaw, emergency, dodging
        end

        local replacement = self:FindForwardDamageDodge(enemy, targetYaw)
        if not replacement then
            return direction, yaw, emergency, dodging
        end

        self.LastDodgeReason = "forward-attack-lane"
        self.ForwardDodgeSelections = (self.ForwardDodgeSelections or 0) + 1
        self.CachedDirection = replacement
        self.CachedYaw = targetYaw
        self.CachedEmergency = false
        self.CachedDodging = true
        self.IsDodging = true
        self.CommittedDodgeDirection = replacement
        self.DodgeCommitUntil = os.clock() + CONFIG.DodgeCommitTime
        self.LastMovement = replacement
        return replacement, targetYaw, false, true
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = tostring(self.Version) .. "+forwarddodge1"
        return self
    end
end
