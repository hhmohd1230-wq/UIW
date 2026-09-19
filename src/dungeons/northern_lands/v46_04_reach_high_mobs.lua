-- v46.4: the two groups before Odin stand on high ground.
--
-- We arrive at the bottom of the climb, they are above us, and the fight stalls
-- until the barrier opens. Two answers, cheapest first.
--
-- 1. Shoot them where they stand. The line of sight test traces from our chest
--    to theirs, so a lip of floor between us reads as "blocked" even though the
--    shuriken flies over it perfectly well. That exception already exists for
--    the Champion on his pillar; there is no reason it should not apply to a
--    mob on a ledge. Combined with the 100 stud mob cast range, most of these
--    groups are already in reach from below.
--
-- 2. If that still leaves us unable to touch them, reset. Dying respawns us at
--    the room's spawn point, which for these rooms is up on the ledge with
--    them - so a reset is a climb. This is the ordinary Reset button, not a
--    teleport: the character dies and the game puts it back where it chooses.
--    It is the fallback, not the opening move, and it is measured: we record
--    the height before and after so we can tell whether it actually helped
--    rather than assuming it did.
do
    CONFIG.NLReachHigh = true
    CONFIG.NLHighAbove = 22          -- studs above us that counts as "on high ground"
    CONFIG.NLHighStuck = 9           -- seconds of being unable to hurt them first
    CONFIG.NLResetCooldown = 30      -- never more often than this
    CONFIG.NLResetMax = 3            -- per room, then stop trying

    local function northern()
        local d = Workspace:FindFirstChild("dungeonName")
        return d and d.Value == "Northern Lands"
    end

    ---------------------------------------------------------------------------
    -- 1. Let us shoot upwards.
    ---------------------------------------------------------------------------
    local oldHighLos = CombatController.HasLineOfSight
    function CombatController:HasLineOfSight(enemy)
        if CONFIG.NLReachHigh and northern()
            and enemy and enemy.Root and enemy.Root.Parent
        then
            local root = self.CharacterService.Root
            if root and enemy.Root.Position.Y > root.Position.Y + 6 then
                return true
            end
        end
        return oldHighLos(self, enemy)
    end

    ---------------------------------------------------------------------------
    -- 2. Reset only when shooting upwards has not worked either.
    ---------------------------------------------------------------------------
    function UIWController:ReachHighMobs()
        if not CONFIG.NLReachHigh or not self.AutoCombat or not northern() then
            return
        end
        local character = self.Character
        local root = character and character.Root
        local humanoid = character and character.Humanoid
        if not root or not humanoid or not character:IsAlive() then
            self.NLHighSince = nil
            return
        end

        -- highest live mob, and whether any of them is losing health
        local above, target = nil, nil
        for _, enemy in ipairs(self.Dungeon and self.Dungeon:GetAliveEnemies() or {}) do
            if enemy.Root and enemy.Root.Parent and not isBossEnemy(enemy) then
                local lift = enemy.Root.Position.Y - root.Position.Y
                if lift >= CONFIG.NLHighAbove and (not above or lift > above) then
                    above, target = lift, enemy
                end
            end
        end
        if not target then
            self.NLHighSince, self.NLHighHealth = nil, nil
            return
        end

        -- Are we hurting it? If its health is falling we are already winning
        -- from down here and there is nothing to fix.
        local health = target.Humanoid and target.Humanoid.Health or 0
        if self.NLHighHealth and health < self.NLHighHealth - 1 then
            self.NLHighSince = nil
        end
        self.NLHighHealth = health

        local now = os.clock()
        self.NLHighSince = self.NLHighSince or now
        if now - self.NLHighSince < CONFIG.NLHighStuck then
            return
        end
        if now - (self.NLResetAt or 0) < CONFIG.NLResetCooldown then
            return
        end
        if (self.NLResets or 0) >= CONFIG.NLResetMax then
            return
        end

        self.NLResetAt = now
        self.NLResets = (self.NLResets or 0) + 1
        self.NLHighSince = nil
        -- Measured, not assumed: if the respawn does not actually put us higher
        -- this is worthless and the numbers will say so.
        local wasY, wantY = root.Position.Y, target.Root.Position.Y
        self.NLResetLog = self.NLResetLog or {}
        pcall(function()
            humanoid.Health = 0
        end)
        task.spawn(function()
            task.wait(6)
            local newRoot = self.Character and self.Character.Root
            local gained = newRoot and (newRoot.Position.Y - wasY) or 0
            table.insert(self.NLResetLog, string.format(
                "reset #%d: was %.0f, mob at %.0f, respawned %.0f (gained %.0f)",
                self.NLResets, wasY, wantY, newRoot and newRoot.Position.Y or -1, gained))
        end)
    end

    local oldHighStep = UIWController.Step
    function UIWController:Step()
        oldHighStep(self)
        if self.Destroyed or not self.Enabled then
            return
        end
        pcall(self.ReachHighMobs, self)
    end

    -- fresh room, fresh budget
    local oldHighNew = UIWController.new
    function UIWController.new()
        local self = oldHighNew()
        self.NLResets = 0
        -- Append rather than replace: this file loads last, so setting the
        -- version outright hid the planner's own number and a build reported
        -- itself as the previous one.
        self.Version = tostring(self.Version) .. "+reachhigh"
        return self
    end
end
