-- v44.15: never dodge our own spells. Live finding: casting E spawns a
-- top-level "lightningBurstHitbox" (55x21x93) in front of us that lives >10 s;
-- it was tracked as an enemy attack, so the script ran away from its own hits.
do
    local OWN_ABILITY_NAMES = {
        lightningbursthitbox = true,
    }
    getgenv().UIW_OwnAbilities = OWN_ABILITY_NAMES

    local function topModel(inst)
        local p = inst
        while p.Parent and p.Parent ~= Workspace do
            p = p.Parent
        end
        return p
    end

    local oldHazardPart = HazardTracker.IsHazardPart
    function HazardTracker:IsHazardPart(part)
        local top = topModel(part)
        if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
            return false
        end
        return oldHazardPart(self, part)
    end

    local oldPress = CombatController.Press
    function CombatController:Press(slot)
        local tool = self:GetTool(slot)
        if tool and not self:IsBuffTool(tool) then
            self.LastDamagePressAt = os.clock()
            local root = self.CharacterService.Root
            if root then
                self.LastDamagePressCF = root.CFrame
            end
        end
        return oldPress(self, slot)
    end

    -- Learn other self-spawned spell hitboxes: a new top-level model with a
    -- hitBox that appears right after our damage cast, in front of us.
    function UIWController:LearnOwnAbility(model)
        local combat = self.Combat
        local pressedAt = combat.LastDamagePressAt
        local cf = combat.LastDamagePressCF
        if not pressedAt or not cf then
            return
        end
        local dt = os.clock() - pressedAt
        if dt < 0.15 or dt > 1.3 then
            return
        end
        local hit = model:FindFirstChild("hitBox")
        if not hit or not hit:IsA("BasePart") then
            return
        end
        local rel = cf:PointToObjectSpace(hit.Position)
        if -rel.Z < -5 or -rel.Z > 80 or math.abs(rel.X) > 14 then
            return
        end
        local name = string.lower(model.Name)
        self.OwnAbilityVotes = self.OwnAbilityVotes or {}
        local votes = (self.OwnAbilityVotes[name] or 0) + 1
        self.OwnAbilityVotes[name] = votes
        if votes >= 3 and not OWN_ABILITY_NAMES[name] and not (self.OwnAbilityVeto or {})[name] then
            OWN_ABILITY_NAMES[name] = true
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.16"
        local controller = self
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if OWN_ABILITY_NAMES[string.lower(child.Name)] then
                return
            end
            if not child:IsA("Model") then
                return
            end
            local pressedAt = controller.Combat.LastDamagePressAt
            if not pressedAt or os.clock() - pressedAt > 1.3 then
                -- Seen without a cast of ours: an enemy attack, never ours.
                controller.OwnAbilityVeto = controller.OwnAbilityVeto or {}
                controller.OwnAbilityVeto[string.lower(child.Name)] = true
                return
            end
            do
                task.delay(0.05, function()
                    if child.Parent then
                        pcall(controller.LearnOwnAbility, controller, child)
                    end
                end)
            end
        end))
        -- Drop anything already tracked from our own spells.
        local hazards = self.Hazards
        local full = hazards.FullHazards or hazards.Hazards
        for part, data in pairs(full) do
            local top = data.Container or topModel(part)
            if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
                full[part] = nil
            end
        end
        return self
    end

    -- Purge learned names from the hazard tables as they are learned.
    local oldRefreshOwn = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local before = self.LastCacheTime
        oldRefreshOwn(self, force)
        if self.LastCacheTime ~= before then
            for i = #self.CachedActive, 1, -1 do
                local data = self.CachedActive[i]
                local top = data.Container
                if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
                    table.remove(self.CachedActive, i)
                    local full = self.FullHazards or self.Hazards
                    full[data.Part] = nil
                    if self.NearHazards then self.NearHazards[data.Part] = nil end
                end
            end
        end
    end
end

