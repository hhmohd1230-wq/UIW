-- v46.6: stop throwing casts at a character that does not exist yet.
--
-- Found in the game's own console, repeating all run:
--
--   Humanoid is not a valid member of Model "Mo_DeliumX"
--     Script 'Players.<name>.Backpack.Inner Rage.LocalScript', Line 28
--     Script 'Players.<name>.Backpack.Flame Shuriken.LocalScript', Line 28
--
-- Those are the game's ability scripts failing, and they come in pairs a few
-- hundredths of a second apart - our buff and our damage spell fired together
-- into a character whose Humanoid is not there. They cluster around respawns:
-- the old character is gone, the new one is still being assembled, and we are
-- already pressing keys at it. Every one of those is a cast spent for nothing,
-- and they land in the worst possible moment, the seconds just after a death
-- when we are trying to get back into the fight.
--
-- CanSendInput only ever asked whether a text box had focus. It now also asks
-- whether there is a character to cast with.
do
    CONFIG.CastReadyDelay = 0.35   -- seconds after a character appears before we trust it

    local spawnedAt = 0
    local function watch(player)
        spawnedAt = os.clock()
        player.CharacterAdded:Connect(function()
            spawnedAt = os.clock()
        end)
    end
    pcall(watch, Players.LocalPlayer)

    local oldReadyInput = CombatController.CanSendInput
    function CombatController:CanSendInput()
        local character = self.CharacterService
        local model = character and character.Character
        local humanoid = character and character.Humanoid
        local root = character and character.Root
        local ready = model and model.Parent
            and humanoid and humanoid.Parent and humanoid.Health > 0
            and root and root.Parent
            and (os.clock() - spawnedAt) >= CONFIG.CastReadyDelay
        if not ready then
            self.SkippedPresses = (self.SkippedPresses or 0) + 1
            return false
        end
        return oldReadyInput(self)
    end

    local oldReadyNew = UIWController.new
    function UIWController.new()
        local self = oldReadyNew()
        self.Version = tostring(self.Version) .. "+castready"
        return self
    end
end
