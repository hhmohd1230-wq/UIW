-- v44.22: low effects. In boss fights (and whenever the lag guard is on) the
-- game's attack effects are hidden to keep the frame rate up:
--   * particles / trails / beams become fully transparent and stop emitting
--     (their Enabled flag is left alone - hazard detection reads it)
--   * lights, explosions and screen post effects are switched off
-- Dragon warning parts can be hidden locally, while HazardTracker continues
-- reading their original transparency for Smart Dodge.
do
    CONFIG.LowEffectsDefault = true
    CONFIG.LowEffectsScanBudget = 400     -- descendants handled per frame

    local Lighting = game:GetService("Lighting")
    local INVISIBLE = NumberSequence.new(1)
    local SKIP_ROOTS = {
        map = true, dungeon = true, Terrain = true, Camera = true,
        UIW_HitboxESP = true, UIW_PathESP = true,
    }
    local DRAGON_EFFECTS = {
        thirdbossxshot = true,
        thirdbosscrossshot = true,
        thirdbossflamebreathe = true,
        thirdbossoneshot = true,
        thirdbossoneshotbeam = true,
    }

    local function dragonEffectContainer(object)
        local current = object
        while current and current ~= Workspace do
            if DRAGON_EFFECTS[string.lower(current.Name or "")] then return current end
            current = current.Parent
        end
        return nil
    end

    local function quiet(object)
        local class = object.ClassName
        if class == "ParticleEmitter" then
            object.Rate = 0
            object.Transparency = INVISIBLE
            pcall(function() object:Clear() end)
        elseif class == "Trail" or class == "Beam" then
            object.Transparency = INVISIBLE
        elseif class == "Decal" or class == "Texture" then
            object.Transparency = 1
        elseif class == "SurfaceGui" then
            object.Enabled = false
        elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight"
            or class == "Fire" or class == "Smoke" or class == "Sparkles"
        then
            object.Enabled = false
        elseif class == "Explosion" then
            object.Visible = false
        elseif object:IsA("BasePart") then
            -- Dragon attacks use enormous visible parts. Hide them locally,
            -- but mark warnings so HazardTracker still treats their original
            -- transparency as active for Smart Dodge.
            if dragonEffectContainer(object) then
                if string.find(string.lower(object.Name or ""), "precast", 1, true) then
                    object:SetAttribute("UIWHiddenDragonWarning", true)
                end
                object.LocalTransparencyModifier = 1
                object.CastShadow = false
            end
        end
    end

    local LowFx = {}
    LowFx.__index = LowFx

    function LowFx.new(controller)
        return setmetatable({
            Controller = controller,
            Active = false,
            Queue = {},
            Done = setmetatable({}, { __mode = "k" }),
            Watched = setmetatable({}, { __mode = "k" }),
            Lighting = nil,
            Maid = Maid.new(),
            Quieted = 0,
        }, LowFx)
    end

    function LowFx:ShouldSkipRoot(child)
        if SKIP_ROOTS[child.Name] then
            return true
        end
        if child == LocalPlayer.Character then
            return true
        end
        return Players:GetPlayerFromCharacter(child) ~= nil
    end

    function LowFx:QueueRoot(child)
        if self.Done[child] or self:ShouldSkipRoot(child) then
            return
        end
        self.Done[child] = true
        table.insert(self.Queue, { Root = child, Descendants = nil, Index = 1 })
        if not self.Watched[child] then
            self.Watched[child] = true
            child.DescendantAdded:Connect(function(object)
                if self.Active then
                    pcall(quiet, object)
                end
            end)
        end
    end

    function LowFx:Enable()
        if self.Active then
            return
        end
        self.Active = true
        table.clear(self.Queue)
        self.Done = setmetatable({}, { __mode = "k" })
        for _, child in ipairs(Workspace:GetChildren()) do
            self:QueueRoot(child)
        end
        -- enemies live inside the dungeon folder
        local dungeon = Workspace:FindFirstChild("dungeon")
        if dungeon then
            for _, room in ipairs(dungeon:GetChildren()) do
                local folder = room:FindFirstChild("enemyFolder")
                if folder then
                    for _, enemy in ipairs(folder:GetChildren()) do
                        self:QueueRoot(enemy)
                    end
                end
            end
        end
        if not self.Lighting then
            local saved = { GlobalShadows = Lighting.GlobalShadows, Effects = {} }
            pcall(function()
                Lighting.GlobalShadows = false
            end)
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") and effect.Enabled then
                    saved.Effects[effect] = true
                    pcall(function() effect.Enabled = false end)
                end
            end
            self.Lighting = saved
        end
    end

    function LowFx:RestoreLighting()
        local saved = self.Lighting
        if not saved then
            return
        end
        self.Lighting = nil
        pcall(function()
            Lighting.GlobalShadows = saved.GlobalShadows
        end)
        for effect in pairs(saved.Effects) do
            pcall(function() effect.Enabled = true end)
        end
    end

    function LowFx:Disable()
        if not self.Active then
            return
        end
        self.Active = false
        table.clear(self.Queue)
        self:RestoreLighting()
    end

    function LowFx:Start()
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if self.Active then
                self:QueueRoot(child)
            end
        end))
        self.Maid:Give(Workspace.DescendantAdded:Connect(function(object)
            if not self.Active then return end
            local class = object.ClassName
            local visual = class == "ParticleEmitter" or class == "Trail" or class == "Beam"
                or class == "PointLight" or class == "SpotLight" or class == "SurfaceLight"
                or class == "Fire" or class == "Smoke" or class == "Sparkles"
                or class == "Explosion"
            local beamPart = object:IsA("BasePart") and object.Parent
                and string.lower(object.Parent.Name or "") == "thirdbossoneshotbeam"
            if not visual and not beamPart then return end
            local character = LocalPlayer.Character
            if character and (object == character or object:IsDescendantOf(character)) then return end
            pcall(quiet, object)
        end))
    end

    -- process queued roots a little every frame (no frame spikes)
    function LowFx:Step()
        if not self.Active then
            return
        end
        local budget = CONFIG.LowEffectsScanBudget
        while budget > 0 and #self.Queue > 0 do
            local item = self.Queue[#self.Queue]
            local root = item.Root
            if not root.Parent then
                table.remove(self.Queue)
                continue
            end
            if not item.Descendants then
                pcall(quiet, root)
                item.Descendants = root:GetDescendants()
            end
            while budget > 0 and item.Index <= #item.Descendants do
                local object = item.Descendants[item.Index]
                item.Index += 1
                budget -= 1
                local ok = pcall(quiet, object)
                if ok then self.Quieted += 1 end
            end
            if item.Index > #item.Descendants then
                table.remove(self.Queue)
            end
        end
    end

    function LowFx:Destroy()
        self:Disable()
        self.Maid:Clean()
    end

    ---------------------------------------------------------------------------
    local function inBossFight(controller)
        local enemy = controller.CurrentEnemy
        if not enemy or not enemy.Root or not enemy.Root.Parent or not isBossEnemy(enemy) then
            return false
        end
        local root = controller.Character.Root
        return root ~= nil and (enemy.Root.Position - root.Position).Magnitude <= 260
    end

    local function enchantedDragonNearby(controller)
        local root = controller.Character and controller.Character.Root
        if not root then return false end
        local function isNearby(enemy)
            return enemy and enemy.Model and enemy.Root and enemy.Root.Parent
                and normalizeEnemyName(enemy.Model.Name) == "enchanted forest dragon"
                and (enemy.Root.Position - root.Position).Magnitude <= 340
        end
        if isNearby(controller.CurrentEnemy) then return true end
        for _, enemy in ipairs(controller.Dungeon:GetAliveEnemies()) do
            if isNearby(enemy) then return true end
        end
        return false
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.LowFx = LowFx.new(self)
        if self.LowEffects == nil then
            self.LowEffects = CONFIG.LowEffectsDefault
        end
        self.Version = "44.22"
        return self
    end

    local oldStart = UIWController.Start
    function UIWController:Start()
        oldStart(self)
        self.LowFx:Start()
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed then
            return
        end
        local now = os.clock()
        if now - (self.LowFxCheckAt or 0) >= 0.5 then
            self.LowFxCheckAt = now
            local perf = getgenv().UIW_Perf
            local lagging = type(perf) == "table" and perf.Lite == true
            local dragon = enchantedDragonNearby(self)
            self.EnchantedDragonPerf = dragon
            local want = self.LowEffects and (dragon or inBossFight(self) or lagging)
            if want then
                self.LowFxHoldUntil = now + 8
                self.LowFx:Enable()
            elseif self.LowFx.Active and now > (self.LowFxHoldUntil or 0) then
                self.LowFx:Disable()
            end
        end
        pcall(self.LowFx.Step, self.LowFx)
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function() self.LowFx:Destroy() end)
        return oldDestroy(self)
    end

    local oldApply = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.LowEffects) == "boolean" then
            self.LowEffects = settings.LowEffects
        end
        return oldApply(self, settings)
    end

    local oldGet = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGet(self)
        settings.LowEffects = self.LowEffects ~= false
        return settings
    end
end
