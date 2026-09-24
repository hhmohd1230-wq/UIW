-- Keep moving into the Enchanted Forest Dragon arena. The Dragon can start
-- spawning map-wide warnings before the player reaches it; treating those as
-- normal combat hazards makes the dodge solver circle or stop outside the
-- arena. During the approach, the route owns movement until casting range.
do
    local ENTRY_RELEASE_DISTANCE = 68
    local ENTRY_REPATH_DELAY = 1.15
    local ENTRY_PROGRESS_EPSILON = 2.0

    local function inEnchantedForest()
        local name = Workspace:FindFirstChild("dungeonName")
        return name and name:IsA("StringValue") and name.Value == "Enchanted Forest"
    end

    local function isDragon(enemy)
        return enemy and enemy.Model and enemy.Root and enemy.Root.Parent
            and enemy.Humanoid and enemy.Humanoid.Health > 0
            and normalizeEnemyName(enemy.Model.Name) == "enchanted forest dragon"
    end

    local function clearEntry(self)
        self.EnchantedDragonEntryActive = false
        self.EnchantedDragonEntryEnemy = nil
        self.EnchantedDragonEntryBestDistance = nil
        self.EnchantedDragonEntryProgressAt = nil
    end

    local oldMechanicGoal = UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        local enemy = self.CurrentEnemy
        if inEnchantedForest() and isDragon(enemy) and self.Character:IsAlive() then
            local distance = flatten(enemy.Root.Position - self.Character.Root.Position).Magnitude
            if distance > ENTRY_RELEASE_DISTANCE then
                if self.EnchantedDragonEntryEnemy ~= enemy.Model then
                    self.EnchantedDragonEntryBestDistance = distance
                    self.EnchantedDragonEntryProgressAt = os.clock()
                end
                self.EnchantedDragonEntryActive = true
                self.EnchantedDragonEntryEnemy = enemy.Model
                return enemy.Root.Position, "DragonArenaEntry", enemy.Root, distance
            end
        end

        if self.EnchantedDragonEntryActive then
            clearEntry(self)
        end
        return oldMechanicGoal(self)
    end

    -- Large Dragon warnings are often already active in the arena while the
    -- player is still on the approach. Follow the computed path unless the
    -- character is physically inside a live hitbox right now.
    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local owner = self.Owner
        if owner and owner.EnchantedDragonEntryActive and isDragon(enemy) then
            local root = self.CharacterService.Root
            local overlaps = self.Hazards:GetOverlapCountAt(root.Position, targetYaw)
            local preferred = unit(flatten(routeDirection or Vector3.zero))

            if overlaps <= 0 then
                if preferred.Magnitude <= 0.05 then
                    local toward = unit(flatten(enemy.Root.Position - root.Position))
                    local future = root.Position + toward * 5
                    if toward.Magnitude > 0.05
                        and self.Geometry:IsDirectionClear(toward, 5, targetYaw)
                        and self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding)
                    then
                        preferred = toward
                    end
                end

                if preferred.Magnitude > 0.05 then
                    self.CommittedDodgeDirection = Vector3.zero
                    self.DodgeCommitUntil = 0
                    self.CachedDirection = preferred
                    self.CachedYaw = targetYaw
                    self.CachedEmergency = false
                    self.CachedDodging = false
                    self.IsDodging = false
                    self.LastDodgeReason = "dragon-entry"
                    self.LastMovement = preferred
                    return preferred, targetYaw, false, false
                end
            end
        end
        return oldSolve(self, routeDirection, enemy, targetYaw)
    end

    -- Recompute the path quickly if streaming or a stair edge leaves the
    -- approach with no measurable forward progress.
    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if not self.EnchantedDragonEntryActive or not self.Character:IsAlive() then
            return
        end

        local enemy = self.CurrentEnemy
        if not isDragon(enemy) then
            clearEntry(self)
            return
        end

        local now = os.clock()
        local distance = flatten(enemy.Root.Position - self.Character.Root.Position).Magnitude
        local best = self.EnchantedDragonEntryBestDistance
        if not best or distance <= best - ENTRY_PROGRESS_EPSILON then
            self.EnchantedDragonEntryBestDistance = distance
            self.EnchantedDragonEntryProgressAt = now
        elseif now - (self.EnchantedDragonEntryProgressAt or now) >= ENTRY_REPATH_DELAY then
            self.EnchantedDragonEntryBestDistance = distance
            self.EnchantedDragonEntryProgressAt = now
            self.Route:InvalidateGoal()
            self.RecoveryUntil = 0
            self.HardRecoveryActive = false
        end

        self.HUD:SetStatus("PATHING", "entering Dragon arena | " .. math.floor(distance) .. " away")
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = tostring(self.Version) .. "+dragonentry1"
        return self
    end
end
