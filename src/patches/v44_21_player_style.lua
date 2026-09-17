-- v44.21: moves copied from a live player run (Enchanted Forest, 3:23 clear,
-- recording rec_0917_205046):
--   * one Q + E per mob pack: Q (Inner Rage) at ~60-80 studs, E about 1.1 s
--     later at ~40-52 studs, then straight on to the next pack
--   * Inner Rage is also used just to run faster (walk speed 16 -> 24)
--     between packs and on the way to bosses, whenever nothing is close
do
    CONFIG.MobBurstRange = 46
    CONFIG.ForestMobCastRange = 46

    CONFIG.TravelBuff = true
    CONFIG.TravelBuffMinDistance = 110   -- target this far (or none): cast the buff to run
    CONFIG.TravelBuffClearRadius = 80    -- no living enemy this close
    CONFIG.TravelBuffInterval = 1.0

    local function nearestEnemyDistance(controller, position)
        local best = math.huge
        local ok, enemies = pcall(function()
            return controller.Dungeon:GetAliveEnemies()
        end)
        if not ok or type(enemies) ~= "table" then
            return best
        end
        for _, enemy in ipairs(enemies) do
            if enemy.Root and enemy.Root.Parent then
                best = math.min(best, (enemy.Root.Position - position).Magnitude)
            end
        end
        return best
    end

    function UIWController:TryTravelBuff()
        if not CONFIG.TravelBuff or not self.AutoCombat then
            return false
        end
        local now = os.clock()
        if now - (self.TravelBuffCheckAt or 0) < CONFIG.TravelBuffInterval then
            return false
        end
        self.TravelBuffCheckAt = now

        local character = self.Character
        local root = character.Root
        if not root or not character:IsAlive() then
            return false
        end
        -- only while actually travelling, never while dodging or holding
        if (self.LastCommandedMovement or Vector3.zero).Magnitude < 0.6
            or self.Dodger.IsDodging
            or self.Dodger.CooldownHold
            or self.Combat.CooldownHolding
            or self.InWaterStream
        then
            return false
        end
        local humanoid = character.Humanoid
        if humanoid and humanoid.WalkSpeed > CONFIG.WalkSpeed + 1 then
            return false -- already buffed
        end

        local enemy = self.CurrentEnemy
        if enemy and enemy.Root and enemy.Root.Parent then
            local distance = flatten(enemy.Root.Position - root.Position).Magnitude
            if distance < CONFIG.TravelBuffMinDistance then
                return false
            end
        end
        if nearestEnemyDistance(self, root.Position) < CONFIG.TravelBuffClearRadius then
            return false
        end

        local combat = self.Combat
        if not combat:CanSendInput() or combat:IsBusyCasting() then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool and combat:IsBuffTool(tool) and combat:IsReady(slot) then
                combat:Press(slot)
                self.TravelBuffs = (self.TravelBuffs or 0) + 1
                return true
            end
        end
        return false
    end

    ---------------------------------------------------------------------------
    -- Crystal Golem: the player killed it with two Q+E combos from 60-80 studs
    -- in about 10 s and never used the rock wall. Only go for rocks when the
    -- golem is still alive after GolemBurstWindow seconds of fighting.
    ---------------------------------------------------------------------------
    CONFIG.GolemBurstWindow = 25

    local oldRockWall = UIWController.GetCrystalGolemRockWallGoal
    function UIWController:GetCrystalGolemRockWallGoal()
        local enemy = self.CurrentEnemy
        local golem = self:IsCrystalGolemFight() and enemy and enemy.Model or nil
        if not golem then
            self.GolemFightModel, self.GolemFightStart = nil, nil
            return oldRockWall(self)
        end
        local root = self.Character.Root
        local close = root and enemy.Root and flatten(enemy.Root.Position - root.Position).Magnitude <= 110
        if self.GolemFightModel ~= golem then
            self.GolemFightModel, self.GolemFightStart = golem, nil
        end
        if close and not self.GolemFightStart then
            self.GolemFightStart = os.clock()
        end
        if not self.GolemFightStart or os.clock() - self.GolemFightStart < CONFIG.GolemBurstWindow then
            self:ResetCrystalGolemMechanicState()
            return nil, nil, nil
        end
        return oldRockWall(self)
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled then
            return
        end
        pcall(self.TryTravelBuff, self)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.21"
        return self
    end
end

