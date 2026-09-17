-- v44.20: close-range adaptive mob combos.
-- A buff-only skill is always primed immediately before the ready damage
-- skill(s).  With no Inner Focus / Inner Rage equipped, ready damage skills
-- are queued together and fired back-to-back as soon as each cast lock ends.
do
    CONFIG.MobBurstRange = 34
    CONFIG.MobBurstBuffWait = 3.0
    CONFIG.MobSpamSyncWait = 1.25
    CONFIG.MobComboWindow = 6.0
    CONFIG.MobBuffCarryWindow = 3.2
    CONFIG.MobStageDistance = 90
    CONFIG.MobBurstDirectRange = 70   -- beyond this the route decides the way
    CONFIG.ForestMobCastRange = CONFIG.MobBurstRange

    local function getMobSpellState(combat)
        local buffs = {}
        local damage = {}
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool then
                local entry = {
                    Slot = slot,
                    Tool = tool,
                    Ready = combat:IsSlotCooldownReady(slot),
                    Wait = combat:GetCooldownRemaining(slot) or math.huge,
                }
                if combat:IsBuffTool(tool) then
                    table.insert(buffs, entry)
                else
                    table.insert(damage, entry)
                end
            end
        end
        return buffs, damage
    end

    local function clearMobCombo(combat, clearPrimed)
        combat.MobComboTarget = nil
        combat.MobComboQueue = nil
        combat.MobComboIndex = nil
        combat.MobComboUntil = nil
        if clearPrimed then
            combat.MobBuffPrimedUntil = nil
        end
    end

    local function hasReady(entries)
        for _, entry in ipairs(entries) do
            if entry.Ready then return true end
        end
        return false
    end

    local function allReady(entries)
        if #entries == 0 then return false end
        for _, entry in ipairs(entries) do
            if not entry.Ready then return false end
        end
        return true
    end

    local function pendingDamage(combat)
        local queue = combat.MobComboQueue
        if not queue then return false end
        for index = combat.MobComboIndex or 1, #queue do
            if not queue[index].Buff then return true end
        end
        return false
    end

    local oldPreferredMobBurst = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        if enemy and enemy.Model and enemy.Root and enemy.Root.Parent
            and not isBossEnemy(enemy)
            and not self.ForceRouteMovement
            and not self.TargetBlocked
            and self.CharacterService:IsAlive()
        then
            local combat = self.Combat
            local buffs, damage = {}, {}
            if combat then
                buffs, damage = getMobSpellState(combat)
            end
            local buffReady = #buffs == 0 or hasReady(buffs)
            local burstArmed = allReady(damage) and buffReady
                or (combat and combat.MobComboTarget == enemy.Model)

            if burstArmed then
                local root = self.CharacterService.Root
                local offset = enemy.Root.Position - root.Position
                local toward = unit(flatten(offset))
                local distance = flatten(offset).Magnitude
                -- Only walk straight at the mob when it is close, on our level
                -- and nothing is in between; otherwise keep following the path
                -- (a straight line through walls got the character stuck).
                if distance > CONFIG.MobBurstRange - 2
                    and distance <= CONFIG.MobBurstDirectRange
                    and toward.Magnitude > 0
                    and math.abs(offset.Y) <= CONFIG.EngageMaxHeightDiff
                    and combat and combat:HasLineOfSight(enemy)
                then
                    local step = math.min(distance - CONFIG.MobBurstRange + 2, 16)
                    if self.Geometry:IsWideSegmentClear(root.Position, root.Position + toward * step, CONFIG.PathPreferredRadius) then
                        return unit(toward * 1.35 + unit(flatten(routeDirection)) * 0.25)
                    end
                end
            end
        end
        return oldPreferredMobBurst(self, routeDirection, enemy, targetYaw)
    end

    -- Stage outside normal aggro range until the complete one-shot package is
    -- ready.  Do not use travel-time prediction to enter early: every equipped
    -- damage spell, plus a present buff, must be ready before committing.
    local oldMobComboHold = CombatController.ShouldHoldApproach
    function CombatController:ShouldHoldApproach(enemy, travelMode)
        if enemy and enemy.Model and enemy.Root and enemy.Root.Parent
            and not isBossEnemy(enemy) and self.CharacterService:IsAlive()
        then
            local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
            if distance > CONFIG.MobBurstRange and distance <= CONFIG.MobStageDistance then
                local buffs, damage = getMobSpellState(self)
                if #damage > 0 then
                    local packageReady = allReady(damage)
                        and (#buffs == 0 or hasReady(buffs))
                    self.CooldownHolding = not packageReady
                    return not packageReady
                end
            end
        end
        return oldMobComboHold(self, enemy, travelMode)
    end

    local oldMobBurstUpdate = CombatController.Update
    function CombatController:Update(enemy)
        local now = os.clock()
        local primed = self.MobBuffPrimedUntil and now < self.MobBuffPrimedUntil

        if not enemy or not enemy.Model then
            -- Keep a just-primed damage queue alive while target selection moves
            -- to the next mob; otherwise the buff is wasted between targets.
            if primed and pendingDamage(self) then
                self.MobComboTarget = nil
            else
                clearMobCombo(self)
            end
            return oldMobBurstUpdate(self, enemy)
        end

        if isBossEnemy(enemy) then
            clearMobCombo(self, true)
            return oldMobBurstUpdate(self, enemy)
        end

        if not enemy.Root or not enemy.Root.Parent or not self.CharacterService:IsAlive() then
            if primed and pendingDamage(self) then
                self.MobComboTarget = nil
            else
                clearMobCombo(self)
            end
            return oldMobBurstUpdate(self, enemy)
        end

        self.LastAction = nil
        self.LastBlockReason = nil

        if self.MobComboQueue and pendingDamage(self)
            and primed and self.MobComboTarget ~= enemy.Model
        then
            self.MobComboTarget = enemy.Model
            self.MobComboUntil = now + CONFIG.MobComboWindow
        elseif self.MobComboTarget
            and (self.MobComboTarget ~= enemy.Model or now > (self.MobComboUntil or 0))
        then
            clearMobCombo(self)
        end

        local root = self.CharacterService.Root
        local offset = flatten(enemy.Root.Position - root.Position)
        local distance = offset.Magnitude
        if distance > CONFIG.MobBurstRange then
            self.LastBlockReason = "closing for close-range mob combo"
            return false
        end

        if not self:CanSendInput() then
            self.LastBlockReason = "chat focused"
            return false
        end
        if CONFIG.NoCastWhileEscaping and self.EscapingHitbox then
            self.LastBlockReason = "escaping hitbox"
            return false
        end
        if self:IsBusyCasting() then
            self.LastBlockReason = self.MobComboTarget and "linking mob combo" or "casting"
            return false
        end

        local aimYaw = (self.LastAimModel == enemy.Model and self.LastAimYaw)
            or directionToYaw(offset)
        if not self:IsFacing(aimYaw, CONFIG.CastFacingTolerance) then
            self.LastBlockReason = "turning to target"
            return false
        end
        if distance > CONFIG.LosBypassDistance and not self:HasLineOfSight(enemy) then
            self.LastBlockReason = "no line of sight"
            return false
        end

        local buffs, damage = getMobSpellState(self)
        if #damage == 0 then
            return oldMobBurstUpdate(self, enemy)
        end

        -- Continue the queued combo. Inputs are deliberately sent after each
        -- cast lock rather than literally on the same frame, where Roblox can
        -- discard the second key press.
        if self.MobComboTarget == enemy.Model and self.MobComboQueue then
            local index = self.MobComboIndex or 1
            local entry = self.MobComboQueue[index]
            if not entry then
                clearMobCombo(self)
                return false
            end
            if self:IsReady(entry.Slot) then
                self:Press(entry.Slot)
                if entry.Buff then
                    self.MobBuffPrimedUntil = now + CONFIG.MobBuffCarryWindow
                end
                self.MobComboIndex = index + 1
                if index >= #self.MobComboQueue then
                    clearMobCombo(self, true)
                    self:ClearCommit()
                    self.RetreatArmed = true
                    self.RetreatArmedAt = now
                end
                return true
            end
            self.LastBlockReason = entry.Buff
                and "waiting to prime mob buff"
                or "waiting for next combo damage input"
            return false
        end

        local readyDamage = {}
        local soonestDamage = math.huge
        for _, entry in ipairs(damage) do
            soonestDamage = math.min(soonestDamage, entry.Wait)
            if entry.Ready then table.insert(readyDamage, entry) end
        end
        if #readyDamage == 0 then
            self.LastBlockReason = "damage cooldown"
            return false
        end

        local readyBuff = nil
        local soonestBuff = math.huge
        for _, entry in ipairs(buffs) do
            soonestBuff = math.min(soonestBuff, entry.Wait)
            if entry.Ready and not readyBuff then readyBuff = entry end
        end

        if #buffs > 0 and not readyBuff and soonestBuff <= CONFIG.MobBurstBuffWait then
            self.LastBlockReason = string.format("holding mob combo for buff | %.1fs", soonestBuff)
            return false
        end

        -- No buff equipped: synchronize two damage spells when the second is
        -- almost ready; otherwise use every damage spell that is ready now.
        if #buffs == 0 and #damage > 1 and #readyDamage < #damage then
            local longestShortWait = 0
            for _, entry in ipairs(damage) do
                if not entry.Ready then longestShortWait = math.max(longestShortWait, entry.Wait) end
            end
            if longestShortWait <= CONFIG.MobSpamSyncWait then
                self.LastBlockReason = string.format("syncing damage spam | %.1fs", longestShortWait)
                return false
            end
        end

        local queue = {}
        if readyBuff then
            table.insert(queue, { Slot = readyBuff.Slot, Buff = true })
        end
        for _, entry in ipairs(readyDamage) do
            table.insert(queue, { Slot = entry.Slot, Buff = false })
        end

        self.MobComboTarget = enemy.Model
        self.MobComboQueue = queue
        self.MobComboIndex = 1
        self.MobComboUntil = now + CONFIG.MobComboWindow
        self:ArmCommit(enemy)

        local first = queue[1]
        if first and self:IsReady(first.Slot) then
            self:Press(first.Slot)
            if first.Buff then
                self.MobBuffPrimedUntil = now + CONFIG.MobBuffCarryWindow
            end
            self.MobComboIndex = 2
            if #queue == 1 then
                clearMobCombo(self, true)
                self:ClearCommit()
                self.RetreatArmed = true
                self.RetreatArmedAt = now
            end
            return true
        end

        self.LastBlockReason = "arming mob combo"
        return false
    end

    -- v44.13 used buffs for urgent dodges, which could consume Inner Focus at
    -- long range immediately before a mob burst.  On normal mobs, reserve the
    -- buff for damage unless health is low enough that survival must win.
    local oldTryEscapeBuffMobCombo = CombatController.TryEscapeBuff
    function CombatController:TryEscapeBuff()
        local owner = self.Owner
        local enemy = owner and owner.CurrentEnemy
        if enemy and enemy.Model and not isBossEnemy(enemy) then
            local humanoid = self.CharacterService.Humanoid
            local healthRatio = humanoid
                and humanoid.Health / math.max(humanoid.MaxHealth, 1)
                or 0
            if healthRatio > 0.35 then
                return false
            end
        end
        return oldTryEscapeBuffMobCombo(self)
    end
end

