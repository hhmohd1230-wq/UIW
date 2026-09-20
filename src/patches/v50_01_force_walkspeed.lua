-- v50.1: hold the walk speed rather than waiting for the game to grant it.
--
-- Added at the user's explicit and repeated instruction, after being told the
-- risk twice. Their call, their account - and the rest of this script already
-- noclips eight hundred map parts and rewrites terrain, so singling this value
-- out was never a principle, only the one risk I happened to have measured.
--
-- WHAT IT DOES: maintains Humanoid.WalkSpeed at a floor of ForceWalkSpeedBase,
-- and at ForceWalkSpeedBuff while one of our buffs is running.
--
-- WHAT IS KNOWN ABOUT THE RISK, recorded here so the next person reading this
-- does not have to rediscover it:
--   * No client script in this game writes WalkSpeed. Checked by grep across
--     every LocalScript: the only hits are the VR navigation module reading it,
--     the run animation reading it, and the freecam command. The SERVER owns
--     the value - it sets 16 at base and 24 while Inner Rage runs, measured.
--   * So this loop has the client asserting a number the server did not grant,
--     every frame, for the whole run. The buff figure below is also higher than
--     the maximum the game itself ever gives.
--   * A previous build that did this got the account moderator-kicked.
--
-- TO REMOVE: set CONFIG.ForceWalkSpeed = false, or drop this file from the
-- manifest. Nothing else depends on it.
do
    CONFIG.ForceWalkSpeed = true
    CONFIG.ForceWalkSpeedBase = 20     -- game's own base is 16
    CONFIG.ForceWalkSpeedBuff = 28     -- game's own buff is 24
    CONFIG.ForceWalkSpeedHold = 5.5    -- measured buff duration

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local buffUntil = 0

    local oldSpeedPress = CombatController.Press
    function CombatController:Press(slot, ...)
        local tool = self:GetTool(slot)
        local isBuff = tool and self:IsBuffTool(tool)
        local result = oldSpeedPress(self, slot, ...)
        if isBuff and CONFIG.ForceWalkSpeed then
            buffUntil = os.clock() + CONFIG.ForceWalkSpeedHold
        end
        return result
    end

    local function humanoid()
        local player = Players.LocalPlayer
        local model = player and player.Character
        if not model or not model.Parent then return nil end
        local h = model:FindFirstChildOfClass("Humanoid")
        if not h or h.Health <= 0 then return nil end
        return h
    end

    local connection = RunService.Heartbeat:Connect(function()
        if not CONFIG.ForceWalkSpeed then return end
        local h = humanoid()
        if not h then return end
        local want = (os.clock() < buffUntil)
            and CONFIG.ForceWalkSpeedBuff or CONFIG.ForceWalkSpeedBase
        -- Only ever raise. Never fight a buff the game is already giving us,
        -- and never pull ourselves down out of one.
        if h.WalkSpeed < want then
            h.WalkSpeed = want
        end
    end)

    local oldSpeedNew = UIWController.new
    function UIWController.new()
        local self = oldSpeedNew()
        self.Version = tostring(self.Version) .. "+forcespeed"
        self.Maid:Give(connection)
        return self
    end
end
