-- v44.23: keep facing the target until the spell actually leaves.
-- Measured live (Frost Cone, 125 ms ping): the spell model appears ~0.70 s
-- after the key press and its direction is the character's facing at THAT
-- moment, not at the press. The old code pressed and immediately turned away
-- to dodge or reposition, so casts flew off in random directions (measured
-- errors of 16, 83 and 133 degrees).
do
    CONFIG.CastFacingHold = 1.0        -- seconds of facing lock after a damage cast
    CONFIG.CastFacingMaxHold = 1.8     -- never longer than this, even while busy casting

    local function lockedYaw(character, yaw)
        local lock = character.CastLock
        if not lock then
            return yaw
        end
        local now = os.clock()
        local busy = false
        local model = character.Character
        local flag = model and model:FindFirstChild("busyCasting")
        if flag and flag:IsA("BoolValue") then
            busy = flag.Value
        end
        local expired = now > lock.Until and not busy
        if expired or now > lock.Hard then
            character.CastLock = nil
            return yaw
        end
        local root = character.Root
        local part = lock.Part
        if root and part and part.Parent then
            local to = flatten(part.Position - root.Position)
            if to.Magnitude > 0.5 then
                return directionToYaw(to.Unit)   -- follow a moving target
            end
        end
        return lock.Yaw or yaw
    end

    local oldSetYaw = CharacterService.SetYaw
    function CharacterService:SetYaw(yaw)
        return oldSetYaw(self, lockedYaw(self, yaw))
    end

    function CharacterService:LockCastFacing(part, yaw)
        local now = os.clock()
        self.CastLock = {
            Part = part,
            Yaw = yaw,
            Until = now + CONFIG.CastFacingHold,
            Hard = now + CONFIG.CastFacingMaxHold,
        }
    end

    -- remember which enemy a cast is meant for
    local oldUpdate = CombatController.Update
    function CombatController:Update(enemy)
        self.CastFacingEnemy = enemy
        return oldUpdate(self, enemy)
    end

    local oldPress = CombatController.Press
    function CombatController:Press(slot)
        local tool = self:GetTool(slot)
        if tool and not self:IsBuffTool(tool) then
            local character = self.CharacterService
            local root = character.Root
            local enemy = self.CastFacingEnemy
            local part = enemy and enemy.Root and enemy.Root.Parent and enemy.Root or nil
            local yaw = character.DesiredYaw
            if not yaw and root then
                yaw = directionToYaw(flatten(root.CFrame.LookVector))
            end
            if part or yaw then
                character:LockCastFacing(part, yaw)
            end
        end
        return oldPress(self, slot)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.23"
        return self
    end
end

