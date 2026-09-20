-- v49.5: stop throwing casts at a character that is not there, and spend Inner
-- Rage on getting out of a death position instead of on a corpse.
--
-- The game's own console has been printing this all run, in pairs:
--
--   Humanoid is not a valid member of Model "Mo_DeliumX"
--     Script 'Players.<name>.Backpack.Inner Rage.LocalScript', Line 28
--     Script 'Players.<name>.Backpack.Flame Shuriken.LocalScript', Line 28
--
-- Those are the game's ability scripts failing because we pressed the key at a
-- character model that has no Humanoid yet - the moment around a respawn. v46.6
-- was meant to have fixed this by tightening CanSendInput, and it did not,
-- because not every path to a cast goes through CanSendInput: the prediction
-- navigation patch calls Press directly, and so do the combo runners.
--
-- So the guard moves to Press, which is the one place every cast in the script
-- has to pass through. It also checks the LIVE character rather than the
-- controller's cached reference, because the cached one is exactly what is
-- stale in the half second after a death.
--
-- This is not only tidiness. Every one of those failed presses spends a six
-- second cooldown for nothing, and when the one it spends is Inner Rage we
-- respawn at base speed with no buff available - slow, in a boss arena, in the
-- seconds when we most need to be moving.
do
    CONFIG.CastGuard = true
    -- Inner Rage is a 22 to 24 stud-per-second sprint on a six second cooldown
    -- and 5.5 of those seconds are the buff itself, so there is very little
    -- spare. Holding it for a moment that needs speed beats spending it the
    -- instant it comes off cooldown.
    CONFIG.EscapeBuffAtBoss = true
    CONFIG.EscapeBuffHold = 1.0    -- seconds between escape presses

    local Players = game:GetService("Players")

    local function liveCharacter()
        local player = Players.LocalPlayer
        local model = player and player.Character
        if not model or not model.Parent then return nil end
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return nil end
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        return model, humanoid, root
    end

    local oldGuardPress = CombatController.Press
    function CombatController:Press(slot, ...)
        if CONFIG.CastGuard and not liveCharacter() then
            self.BlockedPresses = (self.BlockedPresses or 0) + 1
            return
        end
        return oldGuardPress(self, slot, ...)
    end

    ---------------------------------------------------------------------------
    -- Spend the buff on escaping, at a boss.
    ---------------------------------------------------------------------------
    -- The dodge solver already works out how bad the square we are standing on
    -- is - it sums the risk at our own position across the whole lookahead and
    -- calls anything over 100 an emergency. That is the death position, and it
    -- is the moment the extra eight studs a second is worth more than it is at
    -- any other point in the fight: the difference between clearing the edge of
    -- a wave and being caught by it is usually a stride.
    local function bossNearby(controller)
        local enemy = controller.Target or controller.CurrentTarget
        local model = enemy and enemy.Model
        if not model then return false end
        local name = model.Name
        return name:find("Bob") ~= nil or name:find("Odin") ~= nil
            or name:find("Champion") ~= nil
    end

    function UIWController:EscapeWithSpeed()
        if not CONFIG.EscapeBuffAtBoss or not self.AutoCombat then return false end
        local solver = self.Dodger
        if not solver or not solver.NLEmergency then return false end
        if not bossNearby(self) then return false end

        local _, humanoid = liveCharacter()
        if not humanoid then return false end
        -- Already fast: the buff is running and there is nothing to buy.
        if humanoid.WalkSpeed > CONFIG.WalkSpeed + 1 then return false end

        local now = os.clock()
        if now - (self.EscapeBuffAt or 0) < CONFIG.EscapeBuffHold then return false end

        local combat = self.Combat
        if not combat or not combat:CanSendInput() or combat:IsBusyCasting() then return false end

        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool and combat:IsBuffTool(tool) and combat:IsReady(slot) then
                combat:Press(slot)
                self.EscapeBuffAt = now
                self.EscapeBuffUses = (self.EscapeBuffUses or 0) + 1
                return true
            end
        end
        return false
    end

    local oldEscapeStep = UIWController.Step
    function UIWController:Step()
        oldEscapeStep(self)
        if self.Destroyed or not self.Enabled then return end
        pcall(self.EscapeWithSpeed, self)
    end

    local oldEscapeNew = UIWController.new
    function UIWController.new()
        local self = oldEscapeNew()
        self.Version = tostring(self.Version) .. "+castguard"
        return self
    end
end
