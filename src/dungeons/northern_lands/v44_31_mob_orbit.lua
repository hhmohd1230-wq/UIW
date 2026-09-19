-- v44.31: Northern Lands mobs - circle them instead of trading shots.
--
-- Their behaviour makes this work: they walk towards you and fire in straight
-- lines at where you are. Standing off and shooting back means eating those
-- lines; walking a circle around them at a fixed radius means every shot is
-- aimed where you just were, and you never let them close the gap. Measured
-- across two recorded human runs, northernMageShot was the single biggest
-- source of damage in the dungeon - 14 of 34 hits - so this is the attack the
-- orbit is meant to beat.
--
-- The radius is kept inside our own cast range (64) so circling and damaging
-- are the same activity rather than a trade.
--
-- Walls: rather than removing them, the orbit is wall-aware. It looks ahead
-- along the circle, and when the way round is blocked it turns and goes the
-- other way. Flat Arena already clears scenery on this client, which is the
-- legitimate version of "remove the walls".
do
    CONFIG.NLMobOrbit = true
    CONFIG.NLMobOrbitRadius = 58      -- inside cast range, outside their reach
    CONFIG.NLMobOrbitStep = 32        -- degrees round the circle we aim ahead
    CONFIG.NLMobOrbitMin = 34         -- never let one get closer than this
    CONFIG.NLMobOrbitProbe = 12       -- studs checked before committing to a way round
    CONFIG.NLMobOrbitHold = 1.2       -- seconds we keep spinning the same way

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- somewhere on the circle, a step ahead of where we are now
    local function orbitPoint(centre, radial, radius, degrees)
        local turned = unit(rotateXZ(radial, degrees))
        if turned.Magnitude == 0 then
            return nil
        end
        return centre + turned * radius
    end

    function DodgeSolver:GetMobOrbitGoal(enemy)
        if not CONFIG.NLMobOrbit or not inNorthernLands() then
            return nil
        end
        if not enemy or not enemy.Model or not enemy.Root or not enemy.Root.Parent then
            return nil
        end
        if isBossEnemy(enemy) then
            return nil            -- bosses have their own standing rules
        end
        local root = self.CharacterService.Root
        if not root then
            return nil
        end

        local centre = Vector3.new(enemy.Root.Position.X, root.Position.Y, enemy.Root.Position.Z)
        local offset = flatten(root.Position - centre)
        if offset.Magnitude < 1 then
            return nil
        end
        local radial = offset.Unit
        local now = os.clock()

        -- keep circling the same way unless that way is blocked; flipping every
        -- frame is just rocking on the spot with extra steps
        if now > (self.NLSpinUntil or 0) then
            self.NLSpin = self.NLSpin or 1
        end

        for _, spin in ipairs({ self.NLSpin or 1, -(self.NLSpin or 1) }) do
            for _, degrees in ipairs({ CONFIG.NLMobOrbitStep, CONFIG.NLMobOrbitStep * 0.5 }) do
                local point = orbitPoint(centre, radial, CONFIG.NLMobOrbitRadius, degrees * spin)
                if point then
                    local step = flatten(point - root.Position)
                    if step.Magnitude > 0.5 then
                        local direction = step.Unit
                        local reach = math.min(step.Magnitude, CONFIG.NLMobOrbitProbe)
                        if self.Geometry:IsDirectionClear(direction, reach, directionToYaw(direction))
                            and self.Geometry:IsGroundPadded(root.Position + direction * reach,
                                CONFIG.EdgeHardPadding)
                        then
                            if spin ~= self.NLSpin then
                                -- turned round: hold this way for a moment
                                self.NLSpin = spin
                                self.NLSpinFlips = (self.NLSpinFlips or 0) + 1
                            end
                            self.NLSpinUntil = now + CONFIG.NLMobOrbitHold
                            self.NLOrbiting = true
                            return point
                        end
                    end
                end
            end
        end

        -- Boxed in both ways. Record what is in the way, so the answer can be
        -- "clear that specific thing" rather than "walk through everything".
        self.NLOrbiting = false
        self.NLBlockers = self.NLBlockers or {}
        local probe = unit(rotateXZ(radial, CONFIG.NLMobOrbitStep * (self.NLSpin or 1)))
        if probe.Magnitude > 0 then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { self.CharacterService.Character }
            params.RespectCanCollide = true
            local hit = Workspace:Raycast(root.Position, probe * CONFIG.NLMobOrbitProbe, params)
            if hit and hit.Instance then
                local part = hit.Instance
                local key = string.format("%s/%s %.0fx%.0fx%.0f anchored=%s",
                    part.Parent and part.Parent.Name or "?", part.Name,
                    part.Size.X, part.Size.Y, part.Size.Z, tostring(part.Anchored))
                self.NLBlockers[key] = (self.NLBlockers[key] or 0) + 1
            else
                self.NLBlockers["nothing hit (ground/edge check)"] =
                    (self.NLBlockers["nothing hit (ground/edge check)"] or 0) + 1
            end
        end
        if offset.Magnitude < CONFIG.NLMobOrbitMin then
            return centre + radial * CONFIG.NLMobOrbitRadius
        end
        return nil
    end
end
