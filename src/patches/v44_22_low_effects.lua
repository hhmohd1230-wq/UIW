-- v44.22: low effects. In boss fights (and whenever the lag guard is on) the
-- game's attack effects are hidden to keep the frame rate up:
--   * particles / trails / beams become fully transparent and stop emitting
--     (their Enabled flag is left alone - hazard detection reads it)
--   * lights, explosions and screen post effects are switched off
-- Warning (precast) and hitBox parts are never touched.
do
    CONFIG.LowEffectsDefault = true
    CONFIG.LowEffectsScanBudget = 400     -- descendants handled per frame

    local Lighting = game:GetService("Lighting")
    local INVISIBLE = NumberSequence.new(1)
    local SKIP_ROOTS = {
        map = true, dungeon = true, Terrain = true, Camera = true,
        UIW_HitboxESP = true, UIW_PathESP = true,
    }

    local function quiet(object)
        local class = object.ClassName
        if class == "ParticleEmitter" then
            object.Rate = 0
            object.Transparency = INVISIBLE
        elseif class == "Trail" or class == "Beam" then
            object.Transparency = INVISIBLE
        elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight"
            or class == "Fire" or class == "Smoke" or class == "Sparkles"
        then
            object.Enabled = false
        elseif class == "Explosion" then
            object.Visible = false
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
        table.insert(self.Queue, child)
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
    end

    -- process queued roots a little every frame (no frame spikes)
    function LowFx:Step()
        if not self.Active then
            return
        end
        local budget = CONFIG.LowEffectsScanBudget
        while budget > 0 and #self.Queue > 0 do
            local root = table.remove(self.Queue)
            if root.Parent then
                pcall(quiet, root)
                local descendants = root:GetDescendants()
                budget -= #descendants
                for _, object in ipairs(descendants) do
                    local ok = pcall(quiet, object)
                    if ok then
                        self.Quieted += 1
                    end
                end
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
            local want = self.LowEffects and (inBossFight(self) or lagging)
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

