local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(characterService, selfTracker)
    return setmetatable({
        CharacterService = characterService,
        SelfTracker = selfTracker,
        LastPress = {
            q = 0,
            e = 0,
        },
        LastAction = nil,
        AttackCommitTarget = nil,
        AttackCommitUntil = 0,
        CooldownHolding = false,
    }, CombatController)
end

function CombatController:GetTool(slot)
    for _, container in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local abilitySlot = tool:FindFirstChild("abilitySlot")

                    if abilitySlot and string.lower(tostring(abilitySlot.Value)) == slot then
                        return tool
                    end
                end
            end
        end
    end

    return nil
end

function CombatController:IsBusyCasting()
    local character = self.CharacterService.Character
    local busy = character and character:FindFirstChild("busyCasting")

    return busy and busy:IsA("BoolValue") and busy.Value or false
end

function CombatController:GetCooldownRemaining(slot)
    local tool = self:GetTool(slot)

    if not tool then
        return nil
    end

    local cooldown = tool:FindFirstChild("cooldown")

    if not cooldown then
        return 0
    end

    local value = tonumber(cooldown.Value)

    if not value then
        return 0
    end

    return math.max(value, 0)
end

function CombatController:IsSlotCooldownReady(slot)
    local remaining = self:GetCooldownRemaining(slot)

    if remaining == nil then
        return false
    end

    return remaining <= 0 and os.clock() - self.LastPress[slot] > 0.35
end

function CombatController:IsReady(slot)
    if self:IsBusyCasting() then
        return false
    end

    return self:IsSlotCooldownReady(slot)
end

function CombatController:GetPreparationState()
    -- Replaced by the v38 combat + dodge section near the end of this file.
    return {
        HasDamage = false,
        HasBuff = false,
        DamageReady = true,
        BuffReady = true,
        LongestWait = 0,
    }
end

function CombatController:ClearCommit()
    self.AttackCommitTarget = nil
    self.AttackCommitUntil = 0
end

function CombatController:ArmCommit(enemy)
    if not enemy or not enemy.Model then
        return
    end

    self.AttackCommitTarget = enemy.Model
    self.AttackCommitUntil = os.clock() + CONFIG.AttackCommitWindow
end

function CombatController:IsCommitArmed(enemy)
    if not enemy or not enemy.Model then
        return false
    end

    if self.AttackCommitTarget ~= enemy.Model then
        return false
    end

    if os.clock() > self.AttackCommitUntil then
        self:ClearCommit()
        return false
    end

    return true
end

function CombatController:ShouldHoldApproach(enemy, travelMode)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    self.CooldownHolding = false
    return false
end

function CombatController:GetHoldText()
    return "holding"
end

function CombatController:IsBuffTool(tool)
    if not tool then
        return false
    end

    local buffPower = tool:FindFirstChild("buffPower")
    local damage = tool:FindFirstChild("damage")

    return buffPower ~= nil and damage == nil
end

function CombatController:Press(slot)
    local keyCode = slot == "q" and Enum.KeyCode.Q or Enum.KeyCode.E

    self.LastPress[slot] = os.clock()

    self.SelfTracker:RegisterCast(slot)

    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)

    task.delay(0.045, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)

    self.LastAction = slot
end

function CombatController:Update(enemy)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    self.LastAction = nil
    return false
end

