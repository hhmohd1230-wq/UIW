local TargetHealthBar = {}
TargetHealthBar.__index = TargetHealthBar

function TargetHealthBar.new()
    local self = setmetatable({}, TargetHealthBar)

    local gui = Instance.new("ScreenGui")
    gui.Name = "UIWTargetHealth"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.Parent = LocalPlayer.PlayerGui

    self.Gui = gui

    local existing = LocalPlayer.PlayerGui:FindFirstChild("bossHealth")

    if existing and existing:FindFirstChild("healthFrame") then
        self.Frame = existing.healthFrame:Clone()
        self.Frame.Name = "TargetHealthFrame"
        self.Frame.Parent = gui
    else
        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.fromScale(0.5, 0.16)
        frame.Size = UDim2.fromScale(0.35, 0.05)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local fill = Instance.new("Frame")
        fill.Name = "currentHealth"
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
        fill.BorderSizePixel = 0
        fill.Parent = frame

        local health = Instance.new("TextLabel")
        health.Name = "health"
        health.BackgroundTransparency = 1
        health.Size = UDim2.fromScale(1, 1)
        health.Font = Enum.Font.Highway
        health.TextSize = 14
        health.TextColor3 = Color3.fromRGB(245, 245, 245)
        health.Parent = frame

        local name = Instance.new("TextLabel")
        name.Name = "bossName"
        name.BackgroundTransparency = 1
        name.AnchorPoint = Vector2.new(0.5, 1)
        name.Position = UDim2.fromScale(0.5, 0)
        name.Size = UDim2.fromScale(1, 0.8)
        name.Font = Enum.Font.Highway
        name.TextSize = 14
        name.TextColor3 = Color3.fromRGB(191, 171, 58)
        name.Parent = frame

        self.Frame = frame
    end

    self.Frame.Visible = false
    self.Target = nil

    return self
end

function TargetHealthBar:SetTarget(enemy)
    self.Target = enemy
end

function TargetHealthBar:Update()
    local enemy = self.Target

    if not enemy
        or not enemy.Model
        or not enemy.Model.Parent
        or not enemy.Humanoid
        or enemy.Humanoid.Health <= 0
    then
        self.Frame.Visible = false
        return
    end

    self.Frame.Visible = true

    local name = self.Frame:FindFirstChild("bossName", true)
    local health = self.Frame:FindFirstChild("health", true)

    if name and name:IsA("TextLabel") then
        name.Text = enemy.Model.Name
    end

    if health and health:IsA("TextLabel") then
        health.Text = shortNumber(enemy.Humanoid.Health) .. "/" .. shortNumber(enemy.Humanoid.MaxHealth)
    end

    local current = self.Frame:FindFirstChild("currentHealth", true)

    if current and current:IsA("GuiObject") then
        local ratio = math.clamp(
            enemy.Humanoid.Health / math.max(enemy.Humanoid.MaxHealth, 1),
            0,
            1
        )

        current.Size = UDim2.new(ratio, 0, 1, 0)
    end
end

function TargetHealthBar:Destroy()
    safeDestroy(self.Gui)
end

