-- v44.25: keep the frame rate up when a boss arena fills with attacks.
--
-- Measured at the Enchanted Forest Dragon: 60 fps normally, 6-28 fps in the
-- heavy bursts, with 80+ live attacks on screen. Two different costs are at
-- work there - what the game draws, and what we compute - so this watches the
-- actual frame rate and eases both, then puts them back when the fight calms
-- down. Nothing is changed permanently: everything is restored when the frame
-- rate recovers and when the script unloads.
do
    CONFIG.SmoothGuard = true
    CONFIG.SmoothLowFps = 45          -- below this we start easing off
    CONFIG.SmoothGoodFps = 55         -- above this for a while we put it all back
    CONFIG.SmoothHoldTime = 5         -- seconds of good frames before restoring
    CONFIG.SmoothSampleTime = 1

    local Smooth = {}
    Smooth.__index = Smooth

    function Smooth.new(controller)
        return setmetatable({
            Controller = controller,
            Level = 0,                -- 0 = untouched, 1 = lighter, 2 = lightest
            Frames = 0,
            Fps = 60,
            LastSample = os.clock(),
            GoodSince = nil,
            Saved = {},
        }, Smooth)
    end

    -- what the game draws
    function Smooth:SetQuality(low)
        local saved = self.Saved
        pcall(function()
            local lighting = game:GetService("Lighting")
            if low then
                if saved.GlobalShadows == nil then
                    saved.GlobalShadows = lighting.GlobalShadows
                end
                lighting.GlobalShadows = false
            elseif saved.GlobalShadows ~= nil then
                lighting.GlobalShadows = saved.GlobalShadows
                saved.GlobalShadows = nil
            end
        end)
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if not terrain then
                return
            end
            if low then
                if saved.Decoration == nil then
                    saved.Decoration = terrain.Decoration
                end
                terrain.Decoration = false
            elseif saved.Decoration ~= nil then
                terrain.Decoration = saved.Decoration
                saved.Decoration = nil
            end
        end)
        pcall(function()
            local rendering = settings().Rendering
            if low then
                if saved.QualityLevel == nil then
                    saved.QualityLevel = rendering.QualityLevel
                end
                rendering.QualityLevel = Enum.QualityLevel.Level01
            elseif saved.QualityLevel ~= nil then
                rendering.QualityLevel = saved.QualityLevel
                saved.QualityLevel = nil
            end
        end)
    end

    -- what we compute: thinking 30 times a second is a luxury at 20 fps, and a
    -- dodge decided after the frame is drawn is worth nothing anyway
    function Smooth:SetRates(low)
        local saved = self.Saved
        if low then
            if saved.DodgeSolveInterval == nil then
                saved.DodgeSolveInterval = CONFIG.DodgeSolveInterval
                saved.HazardCacheInterval = CONFIG.HazardCacheInterval
            end
            CONFIG.DodgeSolveInterval = math.max(CONFIG.DodgeSolveInterval, 1 / 6)
            CONFIG.HazardCacheInterval = math.max(CONFIG.HazardCacheInterval, 1 / 6)
        elseif saved.DodgeSolveInterval ~= nil then
            CONFIG.DodgeSolveInterval = saved.DodgeSolveInterval
            CONFIG.HazardCacheInterval = saved.HazardCacheInterval
            saved.DodgeSolveInterval, saved.HazardCacheInterval = nil, nil
        end
    end

    function Smooth:SetDragonCompute(active)
        local saved = self.Saved
        if active then
            if saved.DragonDodgeAngles == nil then
                saved.DragonDodgeAngles = CONFIG.DodgeAngles
                saved.DragonAuraScanRadii = CONFIG.AuraScanRadii
                saved.DragonAuraDotsPerRing = CONFIG.AuraDotsPerRing
            end
            CONFIG.DodgeAngles = { 0, 45, -45, 90, -90, 180 }
            CONFIG.AuraScanRadii = { 8, 18, 28, 34 }
            CONFIG.AuraDotsPerRing = 8
        elseif saved.DragonDodgeAngles ~= nil then
            CONFIG.DodgeAngles = saved.DragonDodgeAngles
            CONFIG.AuraScanRadii = saved.DragonAuraScanRadii
            CONFIG.AuraDotsPerRing = saved.DragonAuraDotsPerRing
            saved.DragonDodgeAngles = nil
            saved.DragonAuraScanRadii = nil
            saved.DragonAuraDotsPerRing = nil
        end
    end

    function Smooth:Apply(level)
        if level == self.Level then
            return
        end
        self.Level = level
        self.Controller.SmoothLevel = level
        if level >= 1 then
            self:SetQuality(true)
        else
            self:SetQuality(false)
        end
        if level >= 2 then
            self:SetRates(true)
        else
            self:SetRates(false)
        end
    end

    function Smooth:Step(now)
        if not CONFIG.SmoothGuard then
            self:Apply(0)
            return
        end
        if now - self.LastSample < CONFIG.SmoothSampleTime then
            return
        end
        local seconds = now - self.LastSample
        self.Fps = self.Frames / math.max(seconds, 0.1)
        self.Frames = 0
        self.LastSample = now
        self.Controller.SmoothFps = math.floor(self.Fps)

        -- Enter the lightest mode before the Enchanted Forest Dragon fills
        -- the arena. Waiting for the measured FPS drop makes the first volley
        -- hitch badly and leaves the healer several frames behind hazards.
        if self.Controller.EnchantedDragonPerf then
            self.GoodSince = nil
            self:SetDragonCompute(true)
            self:Apply(2)
            return
        end
        self:SetDragonCompute(false)

        if self.Fps < CONFIG.SmoothLowFps then
            self.GoodSince = nil
            self:Apply(self.Fps < CONFIG.SmoothLowFps * 0.6 and 2 or math.max(self.Level, 1))
        elseif self.Fps >= CONFIG.SmoothGoodFps then
            self.GoodSince = self.GoodSince or now
            if self.Level > 0 and now - self.GoodSince >= CONFIG.SmoothHoldTime then
                self:Apply(self.Level - 1)
                self.GoodSince = now
            end
        else
            self.GoodSince = nil
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Smooth = Smooth.new(self)
        self.SmoothConn = RunService.RenderStepped:Connect(function()
            self.Smooth.Frames += 1
        end)
        return self
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Smooth then
            return
        end
        pcall(self.Smooth.Step, self.Smooth, os.clock())
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function()
            if self.SmoothConn then
                self.SmoothConn:Disconnect()
            end
            self.Smooth:SetDragonCompute(false)
            self.Smooth:Apply(0)
        end)
        return oldDestroy(self)
    end
end
