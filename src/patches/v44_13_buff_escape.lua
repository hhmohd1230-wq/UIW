-- v44.13: use Inner Rage / Inner Focus (damage + speed buff) to escape fast
-- when a dangerous dodge is underway; the buff also boosts the next hits.
do
    CONFIG.EscapeBuff = true
    CONFIG.EscapeBuffCooldown = 1.5

    local URGENT = {
        hitbox = true, nuke = true, ["large-attack"] = true,
        ["stomp-sidestep"] = true, ["stomp-exit"] = true,
        melee = true, fallback = true, ["least-risk"] = true, orientation = true,
    }

    function CombatController:TryEscapeBuff()
        if not CONFIG.EscapeBuff or not self.CharacterService:IsAlive() or not self:CanSendInput() then
            return false
        end
        local now = os.clock()
        if now - (self.EscapeBuffAt or 0) < CONFIG.EscapeBuffCooldown then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = self:GetTool(slot)
            if tool and self:IsBuffTool(tool) and self:IsReady(slot) then
                self.EscapeBuffAt = now
                self.EscapeBuffs = (self.EscapeBuffs or 0) + 1
                self:Press(slot)
                return true
            end
        end
        return false
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled or not self.AutoCombat then
            return
        end
        local dodger = self.Dodger
        if dodger.IsDodging
            and (URGENT[dodger.LastDodgeReason or ""] or dodger.TreeSweeperUrgent)
        then
            pcall(self.Combat.TryEscapeBuff, self.Combat)
        end
    end


    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.13"
        return self
    end
end

