-- v44.20: keep crystal-mechanic shelter until it really deactivates, and bind
-- spawned attacks to their living source so a dead mob/boss can never leave a
-- locally blocking hitbox behind.
do
    ---------------------------------------------------------------------------
    -- Crystal Golem: latch the chosen cleanse bubble after the falling crystal
    -- disappears. The active light / force-field state, not the crystal model,
    -- is the authority for when the mechanic has actually ended.
    ---------------------------------------------------------------------------
    local oldGolemCleanseGoal = UIWController.GetCrystalGolemCleanseGoal
    function UIWController:GetCrystalGolemCleanseGoal()
        local now = os.clock()
        local goal, part = oldGolemCleanseGoal(self)
        if goal and part and part.Parent then
            self.GolemHeldSafePart = part
            self.GolemHeldSafeSeenAt = now
            return goal, part
        end

        local held = self.GolemHeldSafePart
        if held and held.Parent and self:IsCrystalGolemFight() then
            local active = self:GetCrystalGolemCleanseBubble()
            if active and active.Parent then
                -- Follow the active bubble if the game replaced its part.
                self.GolemHeldSafePart = active
                self.GolemHeldSafeSeenAt = now
                return active.Position, active
            end
            if now - (self.GolemHeldSafeSeenAt or 0) <= CONFIG.GolemSafeHoldGrace then
                return held.Position, held
            end
        end

        self.GolemHeldSafePart = nil
        self.GolemHeldSafeSeenAt = nil
        return nil, nil
    end

    local function pointInsideMechanicPart(part, position)
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
        return math.abs(localPoint.X) <= halfX and math.abs(localPoint.Z) <= halfZ
    end

    local oldPriorityMechanicGoal = UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        local goal, state, part, distance = oldPriorityMechanicGoal(self)
        if state == "FallingCrystalCleanse" and self.Character:IsAlive() then
            local inside = pointInsideMechanicPart(part, self.Character.Root.Position)
            -- Run to shelter first; once inside, keep attacking any boss that is
            -- in cast range while the movement controller holds the safe spot.
            self.Combat.SuppressForMajorEscape = not inside
            self.GolemSafeSpotInside = inside
        else
            self.GolemSafeSpotInside = false
        end
        return goal, state, part, distance
    end

    ---------------------------------------------------------------------------
    -- Attack ownership: associate each newly observed attack container with the
    -- closest live enemy at spawn time. Once that exact enemy dies or is removed,
    -- evict all of its attack parts from both hazard tables immediately.
    ---------------------------------------------------------------------------
    CONFIG.AttackSourceBindRadius = 180

    local oldRegisterDeadSource = HazardTracker.Register
    function HazardTracker:Register(part)
        local known = (self.FullHazards or self.Hazards)[part] ~= nil
        oldRegisterDeadSource(self, part)
        local full = self.FullHazards or self.Hazards
        local data = full[part]
        if known or not data or data.SourceEnemyModel or not self.Dungeon then
            return
        end

        self.AttackSourceByContainer = self.AttackSourceByContainer
            or setmetatable({}, { __mode = "k" })
        local key = data.Container or part.Parent
        local source = key and self.AttackSourceByContainer[key] or nil
        if source and (not source.Model.Parent or source.Humanoid.Health <= 0) then
            source = nil
        end

        if not source then
            local bestDistance = CONFIG.AttackSourceBindRadius
            for _, enemy in ipairs(self.Dungeon:GetAliveEnemies(true)) do
                if enemy.Root and enemy.Root.Parent then
                    local distance = (enemy.Root.Position - part.Position).Magnitude
                    if distance < bestDistance then
                        source = enemy
                        bestDistance = distance
                    end
                end
            end
            if source and key then
                self.AttackSourceByContainer[key] = source
            end
        end

        if source then
            data.SourceEnemyModel = source.Model
            data.SourceEnemyHumanoid = source.Humanoid
        end
    end

    local function sourceIsDead(data)
        local model = data.SourceEnemyModel
        if not model then return false end
        if not model.Parent then return true end
        local humanoid = data.SourceEnemyHumanoid
        if not humanoid or not humanoid.Parent then
            humanoid = model:FindFirstChildOfClass("Humanoid")
            data.SourceEnemyHumanoid = humanoid
        end
        return not humanoid or humanoid.Health <= 0
    end

    local oldRefreshDeadSource = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local full = self.FullHazards or self.Hazards
        local removed = 0
        for part, data in pairs(full) do
            if sourceIsDead(data) then
                full[part] = nil
                if self.Hazards ~= full then self.Hazards[part] = nil end
                if self.NearHazards then self.NearHazards[part] = nil end
                removed += 1
            end
        end
        if removed > 0 then
            self.DeadSourceHazardsRemoved = (self.DeadSourceHazardsRemoved or 0) + removed
            self.LastCacheTime = 0
        end
        return oldRefreshDeadSource(self, force)
    end
end

