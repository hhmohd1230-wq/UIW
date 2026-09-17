local HUD = {}
HUD.__index = HUD

function HUD.new(controller)
    local self = setmetatable({}, HUD)

    self.StartTime = os.clock()
    self.Visible = true
    self.Controller = controller
    self.Minimized = false
    self.Frames = 0
    self.LastFpsUpdate = os.clock()

    local gui = Instance.new("ScreenGui")
    gui.Name = "UIW"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.DisplayOrder = 100
    gui.Parent = LocalPlayer.PlayerGui

    self.Gui = gui

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.AnchorPoint = Vector2.new(0, 1)
    main.Position = UDim2.new(0, 18, 1, -42)
    main.Size = UDim2.fromOffset(540, 556)
    main.BackgroundColor3 = Color3.fromRGB(12, 17, 28)
    main.BackgroundTransparency = 0.03
    main.BorderColor3 = Color3.fromRGB(51, 65, 91)
    main.BorderSizePixel = 1
    main.Parent = gui

    self.Main = main

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = main

    local function updateScale()
        local camera = Workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            uiScale.Scale = math.min(1, (viewport.X - 24) / 540, (viewport.Y - 24) / 600)
        end
    end

    updateScale()
    if Workspace.CurrentCamera then
        Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = main

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 42)
    header.BackgroundColor3 = Color3.fromRGB(17, 24, 39)
    header.BorderSizePixel = 0
    header.Parent = main

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.fromOffset(14, 0)
    title.Size = UDim2.fromOffset(170, 42)
    title.Font = Enum.Font.Highway
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(236, 236, 239)
    title.Text = "UIW CONTROL CENTER"
    title.Parent = header

    local version = Instance.new("TextLabel")
    version.BackgroundTransparency = 1
    version.Position = UDim2.fromOffset(190, 0)
    version.Size = UDim2.fromOffset(120, 42)
    version.Font = Enum.Font.Code
    version.TextSize = 11
    version.TextXAlignment = Enum.TextXAlignment.Left
    version.TextColor3 = Color3.fromRGB(145, 147, 155)
    version.Text = "AUTOMATION SUITE"
    version.Parent = header

    local fps = Instance.new("TextLabel")
    fps.BackgroundTransparency = 1
    fps.AnchorPoint = Vector2.new(1, 0)
    fps.Position = UDim2.new(1, -8, 0, 0)
    fps.Size = UDim2.fromOffset(100, 42)
    fps.Font = Enum.Font.Code
    fps.TextSize = 11
    fps.TextXAlignment = Enum.TextXAlignment.Right
    fps.TextColor3 = Color3.fromRGB(150, 152, 160)
    fps.Text = "fps: 0"
    fps.Parent = header

    self.FPSLabel = fps

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.BackgroundTransparency = 0
    toggleBtn.AnchorPoint = Vector2.new(1, 0)
    toggleBtn.Position = UDim2.new(1, -104, 0, 9)
    toggleBtn.Size = UDim2.fromOffset(88, 24)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(43, 205, 151)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Font = Enum.Font.Highway
    toggleBtn.TextSize = 11
    toggleBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    toggleBtn.Text = "● ACTIVE"
    toggleBtn.Parent = header

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 4)
    btnCorner.Parent = toggleBtn

    self.ToggleButton = toggleBtn

    local autoRetryBtn = Instance.new("TextButton")
    autoRetryBtn.Name = "AutoRetryButton"
    autoRetryBtn.BackgroundTransparency = 0
    autoRetryBtn.AnchorPoint = Vector2.new(1, 0)
    autoRetryBtn.Visible = false
    autoRetryBtn.BackgroundColor3 = Color3.fromRGB(43, 205, 151)
    autoRetryBtn.BorderSizePixel = 0
    autoRetryBtn.Font = Enum.Font.Highway
    autoRetryBtn.TextSize = 11
    autoRetryBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    autoRetryBtn.Text = "RETRY: ON"
    autoRetryBtn.Parent = header

    local retryBtnCorner = Instance.new("UICorner")
    retryBtnCorner.CornerRadius = UDim.new(0, 4)
    retryBtnCorner.Parent = autoRetryBtn

    self.AutoRetryButton = autoRetryBtn
    self.AutoRetryEnabled = true

    local accent = Instance.new("Frame")
    accent.Position = UDim2.fromOffset(0, 42)
    accent.Size = UDim2.new(1, 0, 0, 3)
    accent.BorderSizePixel = 0
    accent.BackgroundColor3 = COLORS.Moving
    accent.Parent = main

    self.Accent = accent

    local function createRow(name, y)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Position = UDim2.fromOffset(9, y)
        label.Size = UDim2.fromOffset(72, 20)
        label.Font = Enum.Font.Highway
        label.TextSize = 12
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = Color3.fromRGB(215, 216, 221)
        label.Text = name
        label.Parent = main

        local value = Instance.new("TextLabel")
        value.BackgroundTransparency = 1
        value.Position = UDim2.fromOffset(82, y)
        value.Size = UDim2.new(1, -92, 0, 20)
        value.Font = Enum.Font.Code
        value.TextSize = 11
        value.TextXAlignment = Enum.TextXAlignment.Left
        value.TextTruncate = Enum.TextTruncate.AtEnd
        value.TextColor3 = Color3.fromRGB(160, 163, 172)
        value.Parent = main

        return value
    end

    self.Playtime = createRow("Playtime", 54)
    self.Status = createRow("Status", 76)
    self.Ping = createRow("Ping", 98)

    local hint = Instance.new("TextLabel")
    hint.BackgroundTransparency = 1
    hint.Position = UDim2.new(0, 10, 0, 124)
    hint.Size = UDim2.fromOffset(175, 20)
    hint.Font = Enum.Font.Code
    hint.TextSize = 10
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextColor3 = Color3.fromRGB(135, 138, 146)
    hint.Text = "RightShift  •  Show / hide panel"
    hint.Parent = main

    local badge = Instance.new("Frame")
    badge.Position = UDim2.new(0, 345, 0, 124)
    badge.Size = UDim2.fromOffset(180, 20)
    badge.BackgroundColor3 = Color3.fromRGB(18, 20, 24)
    badge.BorderColor3 = Color3.fromRGB(40, 43, 50)
    badge.BorderSizePixel = 1
    badge.Parent = main

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 3)
    badgeCorner.Parent = badge

    local badgeText = Instance.new("TextLabel")
    badgeText.BackgroundTransparency = 1
    badgeText.Size = UDim2.fromScale(1, 1)
    badgeText.Font = Enum.Font.Highway
    badgeText.TextSize = 11
    badgeText.Text = "●  Autofarm: Running"
    badgeText.TextColor3 = COLORS.Running
    badgeText.Parent = badge

    self.Badge = badgeText

    local divider = Instance.new("Frame")
    divider.Position = UDim2.fromOffset(14, 152)
    divider.Size = UDim2.new(1, -28, 0, 1)
    divider.BorderSizePixel = 0
    divider.BackgroundColor3 = Color3.fromRGB(43, 54, 73)
    divider.Parent = main

    local sectionTitle = Instance.new("TextLabel")
    sectionTitle.BackgroundTransparency = 1
    sectionTitle.Position = UDim2.fromOffset(14, 162)
    sectionTitle.Size = UDim2.fromOffset(250, 20)
    sectionTitle.Font = Enum.Font.GothamBold
    sectionTitle.TextSize = 12
    sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
    sectionTitle.TextColor3 = Color3.fromRGB(222, 229, 241)
    sectionTitle.Text = "AUTOMATION MODULES"
    sectionTitle.Parent = main

    self.ControlRefreshers = {}

    local function makeToggle(label, x, y, getter, setter)
        local button = Instance.new("TextButton")
        button.AutoButtonColor = false
        button.Position = UDim2.fromOffset(x, y)
        button.Size = UDim2.fromOffset(164, 42)
        button.BackgroundColor3 = Color3.fromRGB(22, 30, 47)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.TextXAlignment = Enum.TextXAlignment.Left
        button.TextColor3 = Color3.fromRGB(220, 226, 237)
        button.Parent = main

        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.Parent = button

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = button

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(43, 55, 75)
        stroke.Transparency = 0.25
        stroke.Parent = button

        local indicator = Instance.new("Frame")
        indicator.AnchorPoint = Vector2.new(1, 0.5)
        indicator.Position = UDim2.new(1, -10, 0.5, 0)
        indicator.Size = UDim2.fromOffset(24, 12)
        indicator.BorderSizePixel = 0
        indicator.Parent = button

        local indicatorCorner = Instance.new("UICorner")
        indicatorCorner.CornerRadius = UDim.new(1, 0)
        indicatorCorner.Parent = indicator

        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Size = UDim2.fromOffset(8, 8)
        dot.BorderSizePixel = 0
        dot.BackgroundColor3 = Color3.fromRGB(245, 248, 255)
        dot.Parent = indicator

        local dotCorner = Instance.new("UICorner")
        dotCorner.CornerRadius = UDim.new(1, 0)
        dotCorner.Parent = dot

        local function refresh()
            local enabled = getter()
            button.Text = label .. (enabled and "\n   Enabled" or "\n   Disabled")
            indicator.BackgroundColor3 = enabled and COLORS.Running or Color3.fromRGB(82, 91, 108)
            dot.Position = enabled and UDim2.new(1, -6, 0.5, 0) or UDim2.new(0, 6, 0.5, 0)
        end

        button.MouseButton1Click:Connect(function()
            setter(not getter())
            refresh()
        end)

        refresh()
        table.insert(self.ControlRefreshers, refresh)
        return refresh
    end

    makeToggle("Master Auto", 14, 190,
        function() return controller.Enabled end,
        function(value)
            controller.Enabled = value
            if not value then
                controller.Character:ReleaseAutomationFacing()
                controller.Dodger.CommittedDodgeDirection = Vector3.zero
                controller.Dodger.DodgeCommitUntil = 0
            end
            toggleBtn.Text = value and "● ACTIVE" or "○ PAUSED"
            toggleBtn.BackgroundColor3 = value and COLORS.Running or Color3.fromRGB(205, 67, 82)
        end
    )
    makeToggle("Auto Combat", 188, 190,
        function() return controller.AutoCombat end,
        function(value) controller.AutoCombat = value end
    )
    makeToggle("Smart Dodge", 362, 190,
        function() return controller.AutoDodge end,
        function(value) controller.AutoDodge = value end
    )
    makeToggle("Hazard ESP", 14, 240,
        function() return controller.AutoESP end,
        function(value) controller.AutoESP = value end
    )
    makeToggle("Path Visualizer", 188, 240,
        function() return controller.AutoPathESP end,
        function(value) controller.AutoPathESP = value end
    )
    makeToggle("Auto Retry", 362, 240,
        function() return controller.AutoRetryEnabled end,
        function(value) controller.AutoRetryEnabled = value end
    )
    makeToggle("Dodge Aura Dots", 14, 290,
        function() return controller.ShowAura end,
        function(value) controller.ShowAura = value end
    )
    makeToggle("Mob Group Circles", 188, 290,
        function() return controller.ShowMobGroups end,
        function(value) controller.ShowMobGroups = value end
    )
    makeToggle("Auto Execute", 362, 290,
        function() return controller.AutoExecuteOnTeleport end,
        function(value)
            controller.AutoExecuteOnTeleport = value
            controller:SaveSettings()
            controller:ConfigureAutoExecute()
        end
    )

    local function makeAction(textValue, x, callback)
        local button = Instance.new("TextButton")
        button.AutoButtonColor = true
        button.Position = UDim2.fromOffset(x, 354)
        button.Size = UDim2.fromOffset(164, 40)
        button.BackgroundColor3 = Color3.fromRGB(35, 72, 125)
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 11
        button.TextColor3 = Color3.fromRGB(239, 245, 255)
        button.Text = textValue
        button.Parent = main

        local actionCorner = Instance.new("UICorner")
        actionCorner.CornerRadius = UDim.new(0, 8)
        actionCorner.Parent = button
        button.MouseButton1Click:Connect(callback)
    end

    makeAction("START DUNGEON", 14, function()
        pcall(function()
            game:GetService("ReplicatedStorage").remotes.changeStartValue:FireServer()
        end)
    end)
    makeAction("NEXT TARGET", 188, function()
        controller:ForceNextTarget()
    end)
    makeAction("RESET ROUTE", 362, function()
        controller.Route:Reset()
        controller.Route:InvalidateGoal()
    end)

    local configTitle = Instance.new("TextLabel")
    configTitle.BackgroundTransparency = 1
    configTitle.Position = UDim2.fromOffset(14, 400)
    configTitle.Size = UDim2.fromOffset(110, 18)
    configTitle.Font = Enum.Font.GothamBold
    configTitle.TextSize = 10
    configTitle.TextXAlignment = Enum.TextXAlignment.Left
    configTitle.TextColor3 = Color3.fromRGB(154, 169, 193)
    configTitle.Text = "CONFIGURATION"
    configTitle.Parent = main

    local function makeConfigButton(textValue, x, color, callback)
        local button = Instance.new("TextButton")
        button.Position = UDim2.fromOffset(x, 396)
        button.Size = UDim2.fromOffset(88, 26)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Font = Enum.Font.GothamSemibold
        button.TextSize = 10
        button.TextColor3 = Color3.fromRGB(242, 246, 255)
        button.Text = textValue
        button.Parent = main
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = button
        button.MouseButton1Click:Connect(callback)
    end

    makeConfigButton("SAVE", 246, Color3.fromRGB(37, 133, 101), function()
        controller:SaveSettings()
    end)
    makeConfigButton("LOAD", 340, Color3.fromRGB(35, 91, 153), function()
        controller:LoadSettings(true)
    end)
    makeConfigButton("RESET", 434, Color3.fromRGB(143, 68, 80), function()
        controller:ResetSettings()
    end)

    local tuningTitle = Instance.new("TextLabel")
    tuningTitle.BackgroundTransparency = 1
    tuningTitle.Position = UDim2.fromOffset(14, 450)
    tuningTitle.Size = UDim2.fromOffset(250, 18)
    tuningTitle.Font = Enum.Font.GothamBold
    tuningTitle.TextSize = 10
    tuningTitle.TextXAlignment = Enum.TextXAlignment.Left
    tuningTitle.TextColor3 = Color3.fromRGB(154, 169, 193)
    tuningTitle.Text = "QUICK TUNING"
    tuningTitle.Parent = main

    local function makeStepper(label, x, getter, setter, step, minimum, maximum)
        local box = Instance.new("Frame")
        box.Position = UDim2.fromOffset(x, 474)
        box.Size = UDim2.fromOffset(164, 42)
        box.BackgroundColor3 = Color3.fromRGB(22, 30, 47)
        box.BorderSizePixel = 0
        box.Parent = main

        local boxCorner = Instance.new("UICorner")
        boxCorner.CornerRadius = UDim.new(0, 8)
        boxCorner.Parent = box

        local valueLabel = Instance.new("TextLabel")
        valueLabel.BackgroundTransparency = 1
        valueLabel.Position = UDim2.fromOffset(34, 0)
        valueLabel.Size = UDim2.new(1, -68, 1, 0)
        valueLabel.Font = Enum.Font.GothamSemibold
        valueLabel.TextSize = 10
        valueLabel.TextColor3 = Color3.fromRGB(221, 228, 240)
        valueLabel.Parent = box

        local function refresh()
            valueLabel.Text = label .. "\n" .. tostring(getter())
        end

        local function adjustButton(symbol, position, direction)
            local button = Instance.new("TextButton")
            button.Position = position
            button.Size = UDim2.fromOffset(28, 28)
            button.AnchorPoint = Vector2.new(0, 0.5)
            button.BackgroundColor3 = Color3.fromRGB(35, 72, 125)
            button.BorderSizePixel = 0
            button.Font = Enum.Font.GothamBold
            button.TextSize = 15
            button.TextColor3 = Color3.fromRGB(245, 248, 255)
            button.Text = symbol
            button.Parent = box
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 6)
            c.Parent = button
            button.MouseButton1Click:Connect(function()
                setter(math.clamp(getter() + direction * step, minimum, maximum))
                refresh()
            end)
        end

        adjustButton("−", UDim2.new(0, 4, 0.5, 0), -1)
        adjustButton("+", UDim2.new(1, -32, 0.5, 0), 1)
        refresh()
        table.insert(self.ControlRefreshers, refresh)
    end

    makeStepper("WALK SPEED", 14,
        function() return CONFIG.WalkSpeed end,
        function(value)
            CONFIG.WalkSpeed = value
            if controller.Character.Humanoid then controller.Character.Humanoid.WalkSpeed = value end
        end,
        2, 12, 40
    )
    makeStepper("COMBAT RANGE", 188,
        function() return CONFIG.DesiredCombatRange end,
        function(value) CONFIG.DesiredCombatRange = value end,
        2, 24, 60
    )
    makeStepper("DAMAGE RANGE", 362,
        function() return CONFIG.DamageCastRange end,
        function(value) CONFIG.DamageCastRange = value end,
        2, 30, 80
    )

    local footer = Instance.new("TextLabel")
    footer.BackgroundTransparency = 1
    footer.Position = UDim2.fromOffset(14, 526)
    footer.Size = UDim2.new(1, -28, 0, 20)
    footer.Font = Enum.Font.Code
    footer.TextSize = 10
    footer.TextXAlignment = Enum.TextXAlignment.Left
    footer.TextColor3 = Color3.fromRGB(119, 132, 153)
    footer.Text = "Retry monitor: waiting for a supported final boss"
    footer.Parent = main
    self.RetryStatus = footer

    toggleBtn.MouseButton1Click:Connect(function()
        controller.Enabled = not controller.Enabled
        toggleBtn.Text = controller.Enabled and "● ACTIVE" or "○ PAUSED"
        toggleBtn.BackgroundColor3 = controller.Enabled and COLORS.Running or Color3.fromRGB(205, 67, 82)
    end)

    local dragging = false
    local dragStart
    local startPosition
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return self
end

function HUD:SetStatus(action, text)
    local color = COLORS.Idle

    if action == "MOVING" then
        color = COLORS.Moving
    elseif action == "PATHING" then
        color = COLORS.Pathing
    elseif action == "COMBAT" then
        color = COLORS.Combat
    elseif action == "DODGING" then
        color = COLORS.Dodge
    elseif action == "EMERGENCY" then
        color = COLORS.Emergency
    elseif action == "MELEE" then
        color = COLORS.Melee
    elseif action == "RUNNING" then
        color = COLORS.Running
    end

    self.Accent.BackgroundColor3 = color
    self.Badge.TextColor3 = color
    self.Badge.Text = action == "IDLE" and "○  Automation: Paused" or "●  Automation: " .. action
    self.Status.Text = text or action
end

function HUD:Heartbeat()
    self.Frames += 1

    local now = os.clock()
    local elapsed = now - self.StartTime

    self.Playtime.Text = string.format(
        "%02d:%02d",
        math.floor(elapsed / 60),
        math.floor(elapsed % 60)
    )

    if now - self.LastFpsUpdate >= 0.5 then
        local duration = now - self.LastFpsUpdate

        self.FPSLabel.Text = "fps: " .. tostring(math.floor(self.Frames / duration))

        self.Frames = 0
        self.LastFpsUpdate = now

        local ping = 0

        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)

        self.Ping.Text = tostring(ping)
    end
end

function HUD:Toggle()
    self.Visible = not self.Visible
    self.Main.Visible = self.Visible
end

function HUD:RefreshControls()
    for _, refresh in ipairs(self.ControlRefreshers or {}) do
        pcall(refresh)
    end

    local enabled = self.Controller.Enabled
    self.ToggleButton.Text = enabled and "● ACTIVE" or "○ PAUSED"
    self.ToggleButton.BackgroundColor3 = enabled and COLORS.Running or Color3.fromRGB(205, 67, 82)
end

function HUD:SetRetryStatus(text, color)
    if not self.RetryStatus then return end
    self.RetryStatus.Text = "Retry monitor: " .. tostring(text)
    self.RetryStatus.TextColor3 = color or Color3.fromRGB(119, 132, 153)
end

function HUD:Destroy()
    safeDestroy(self.Gui)
end

