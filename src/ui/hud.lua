---------------------------------------------------------------------------
-- UIW hub window
--   sidebar tabs (Home / Automation / Settings / Configs), gradient cards,
--   soft drop shadow, toasts, minimise bubble. RightShift shows / hides.
--   Keeps the old HUD interface: SetStatus, SetRetryStatus, Heartbeat,
--   Toggle, RefreshControls, Destroy and the Accent / Badge / Status /
--   FPSLabel / RetryStatus / AutoRetryButton fields other parts use.
---------------------------------------------------------------------------
local UIKit = {}

UIKit.Theme = {
    Window = Color3.fromRGB(14, 15, 20),
    Sidebar = Color3.fromRGB(18, 19, 26),
    Card = Color3.fromRGB(24, 25, 33),
    Tile = Color3.fromRGB(34, 35, 45),
    TileHover = Color3.fromRGB(44, 46, 58),
    Stroke = Color3.fromRGB(46, 48, 62),
    Text = Color3.fromRGB(238, 240, 247),
    SubText = Color3.fromRGB(160, 164, 178),
    Muted = Color3.fromRGB(110, 114, 128),
    Accent = Color3.fromRGB(124, 104, 255),
    Accent2 = Color3.fromRGB(70, 150, 255),
    Good = Color3.fromRGB(46, 204, 142),
    Bad = Color3.fromRGB(236, 76, 96),
    Warn = Color3.fromRGB(242, 183, 64),
    Off = Color3.fromRGB(58, 60, 74),
    White = Color3.fromRGB(255, 255, 255),
}

UIKit.Fonts = {
    Bold = Enum.Font.GothamBold,
    Semi = Enum.Font.GothamMedium,
    Body = Enum.Font.Gotham,
    Mono = Enum.Font.Code,
}

function UIKit.New(className, props, children)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then
            object[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = object
    end
    if props and props.Parent then
        object.Parent = props.Parent
    end
    return object
end

function UIKit.Corner(parent, radius)
    return UIKit.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent, color, transparency, thickness)
    return UIKit.New("UIStroke", {
        Color = color or UIKit.Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function UIKit.Gradient(parent, from, to, rotation)
    return UIKit.New("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 0,
        Parent = parent,
    })
end

function UIKit.Padding(parent, left, top, right, bottom)
    return UIKit.New("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingTop = UDim.new(0, top or left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or left or 0),
        Parent = parent,
    })
end

function UIKit.Tween(object, time, props, style)
    local ok, tween = pcall(function()
        return game:GetService("TweenService"):Create(
            object,
            TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            props
        )
    end)
    if ok and tween then
        tween:Play()
        return tween
    end
    for key, value in pairs(props) do
        pcall(function() object[key] = value end)
    end
    return nil
end

function UIKit.Label(parent, props)
    local defaults = {
        BackgroundTransparency = 1,
        Font = UIKit.Fonts.Body,
        TextSize = 13,
        TextColor3 = UIKit.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "",
        Parent = parent,
    }
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    return UIKit.New("TextLabel", defaults)
end

function UIKit.Button(parent, props)
    local defaults = {
        AutoButtonColor = false,
        BackgroundColor3 = UIKit.Theme.Tile,
        BorderSizePixel = 0,
        Font = UIKit.Fonts.Semi,
        TextSize = 13,
        TextColor3 = UIKit.Theme.Text,
        Text = "",
        Parent = parent,
    }
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    local button = UIKit.New("TextButton", defaults)
    local base = defaults.BackgroundColor3
    button.MouseEnter:Connect(function()
        UIKit.Tween(button, 0.15, { BackgroundColor3 = base:Lerp(UIKit.Theme.White, 0.08) })
    end)
    button.MouseLeave:Connect(function()
        UIKit.Tween(button, 0.2, { BackgroundColor3 = base })
    end)
    return button, function(color)
        base = color
        UIKit.Tween(button, 0.2, { BackgroundColor3 = color })
    end
end

-- UIGradient tints text too, so the gradient sits on a backing frame and the
-- (transparent) button with the text sits on top of it
function UIKit.GradientButton(parent, props, radius)
    local backing = UIKit.New("Frame", {
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        Position = props.Position,
        Size = props.Size,
        BackgroundColor3 = UIKit.Theme.White,
        BorderSizePixel = 0,
        Visible = props.Visible ~= false,
        ZIndex = props.ZIndex or 3,
        Parent = parent,
    })
    UIKit.Corner(backing, radius or 8)
    local gradient = UIKit.Gradient(backing, UIKit.Theme.Accent, UIKit.Theme.Accent2, props.Rotation or 0)
    local button = UIKit.New("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = props.Font or UIKit.Fonts.Bold,
        TextSize = props.TextSize or 13,
        TextColor3 = UIKit.Theme.White,
        Text = props.Text or "",
        ZIndex = (props.ZIndex or 3) + 1,
        Parent = backing,
    })
    button.MouseEnter:Connect(function()
        UIKit.Tween(gradient, 0.2, { Offset = Vector2.new(0.15, 0) })
    end)
    button.MouseLeave:Connect(function()
        UIKit.Tween(gradient, 0.2, { Offset = Vector2.zero })
    end)
    return button, backing
end

-- soft shadow built from stacked transparent frames (no image assets needed)
function UIKit.Shadow(holder, radius)
    for i = 1, 6 do
        local spread = i * 4
        UIKit.Corner(UIKit.New("Frame", {
            Name = "Shadow" .. i,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 6),
            Size = UDim2.new(1, spread * 2, 1, spread * 2),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.82 + i * 0.028,
            BorderSizePixel = 0,
            ZIndex = 0,
            Parent = holder,
        }), radius + spread)
    end
end

-- a card with a coloured glow in one corner (like the reference design)
function UIKit.Card(parent, props, glow)
    local card = UIKit.New("Frame", {
        BackgroundColor3 = UIKit.Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = props.Position,
        Size = props.Size,
        LayoutOrder = props.LayoutOrder or 0,
        Parent = parent,
    })
    UIKit.Corner(card, 12)
    UIKit.Stroke(card, UIKit.Theme.Stroke, 0.35)
    if glow then
        local shine = UIKit.New("Frame", {
            Name = "Glow",
            BackgroundColor3 = glow,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 1,
            Parent = card,
        })
        UIKit.Corner(shine, 12)
        local gradient = UIKit.Gradient(shine, UIKit.Theme.White, UIKit.Theme.White, props.GlowRotation or 35)
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 0.92),
            NumberSequenceKeypoint.new(1, 0.45),
        })
        card:SetAttribute("GlowColor", glow)
    end
    return card
end

function UIKit.SetGlow(card, color)
    local shine = card:FindFirstChild("Glow")
    if shine then
        UIKit.Tween(shine, 0.35, { BackgroundColor3 = color })
    end
end

-- a small stat tile: caption + value
function UIKit.Tile(parent, caption, position, size)
    local tile = UIKit.New("Frame", {
        BackgroundColor3 = UIKit.Theme.Tile,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        ZIndex = 2,
        Parent = parent,
    })
    UIKit.Corner(tile, 8)
    UIKit.Label(tile, {
        Position = UDim2.fromOffset(10, 5),
        Size = UDim2.new(1, -20, 0, 16),
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = caption,
        ZIndex = 3,
    })
    local value = UIKit.Label(tile, {
        Position = UDim2.fromOffset(10, 21),
        Size = UDim2.new(1, -20, 0, 16),
        TextSize = 11,
        TextColor3 = UIKit.Theme.SubText,
        Text = "-",
        ZIndex = 3,
    })
    return value, tile
end

-- iOS-like switch; returns the track and a setter
function UIKit.Switch(parent, position)
    local track = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = position,
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = UIKit.Theme.Off,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = parent,
    })
    UIKit.Corner(track, 11)
    local knob = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = UIKit.Theme.White,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    UIKit.Corner(knob, 8)
    local function set(value, instant)
        local time = instant and 0 or 0.22
        UIKit.Tween(track, time, { BackgroundColor3 = value and UIKit.Theme.Good or UIKit.Theme.Off })
        UIKit.Tween(knob, time, { Position = value and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
    end
    return track, set
end

---------------------------------------------------------------------------
local HUD = {}
HUD.__index = HUD

local STATUS_COLORS = {
    MOVING = COLORS.Moving,
    PATHING = COLORS.Pathing,
    COMBAT = COLORS.Combat,
    DODGING = COLORS.Dodge,
    EMERGENCY = COLORS.Emergency,
    MELEE = COLORS.Melee,
    RUNNING = COLORS.Running,
}

local WINDOW_W, WINDOW_H = 660, 430

function HUD.new(controller)
    local self = setmetatable({}, HUD)
    local T = UIKit.Theme

    self.StartTime = os.clock()
    self.Visible = true
    self.Controller = controller
    self.Frames = 0
    self.LastFpsUpdate = os.clock()
    self.LastSlowUpdate = 0
    self.ControlRefreshers = {}
    self.ConfigRefreshers = {}
    self.Connections = {}
    self.Pages = {}
    self.TabButtons = {}
    self.SelectedConfig = controller.ActiveConfig

    local function connect(signal, fn)
        local connection = signal:Connect(fn)
        table.insert(self.Connections, connection)
        return connection
    end

    local parentGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = parentGui:FindFirstChild("UIW")
    if old then
        safeDestroy(old)
    end

    local gui = UIKit.New("ScreenGui", {
        Name = "UIW",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parentGui,
    })
    self.Gui = gui

    -- holder = shadow + window, dragged as one
    local holder = UIKit.New("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    self.Holder = holder
    UIKit.Shadow(holder, 16)

    local scale = UIKit.New("UIScale", { Parent = holder })
    local function updateScale()
        local camera = Workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            scale.Scale = math.clamp(math.min((viewport.X - 24) / WINDOW_W, (viewport.Y - 60) / WINDOW_H), 0.45, 1)
        end
    end
    updateScale()
    if Workspace.CurrentCamera then
        connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end

    local main = UIKit.New("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = T.White,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = holder,
    })
    UIKit.Corner(main, 16)
    UIKit.Stroke(main, T.Stroke, 0.1)
    UIKit.Gradient(main, Color3.fromRGB(24, 25, 35), T.Window, 90)
    self.Main = holder -- Toggle() shows / hides the whole window

    -----------------------------------------------------------------------
    -- title bar
    -----------------------------------------------------------------------
    local titleBar = UIKit.New("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = main,
    })

    local logo = UIKit.New("Frame", {
        Position = UDim2.fromOffset(16, 11),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = T.White,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = titleBar,
    })
    UIKit.Corner(logo, 14)
    UIKit.Gradient(logo, T.Accent, T.Accent2, 45)
    UIKit.Label(logo, {
        Size = UDim2.fromScale(1, 1),
        Font = UIKit.Fonts.Bold,
        TextSize = 13,
        Text = "U",
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    UIKit.Label(titleBar, {
        Position = UDim2.fromOffset(54, 8),
        Size = UDim2.fromOffset(60, 20),
        Font = UIKit.Fonts.Bold,
        TextSize = 17,
        Text = "UIW",
        ZIndex = 3,
    })
    UIKit.Label(titleBar, {
        Position = UDim2.fromOffset(54, 27),
        Size = UDim2.fromOffset(200, 14),
        TextSize = 11,
        TextColor3 = T.Muted,
        Text = "Dungeon Automation  •  v44.20",
        ZIndex = 3,
    })

    -- status pill (Accent dot + Badge text are used by the rest of the script)
    local pill = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -92, 0.5, 0),
        Size = UDim2.fromOffset(190, 26),
        BackgroundColor3 = T.Tile,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = titleBar,
    })
    UIKit.Corner(pill, 13)
    UIKit.Stroke(pill, T.Stroke, 0.4)
    local accent = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = COLORS.Running,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = pill,
    })
    UIKit.Corner(accent, 4)
    self.Accent = accent
    self.Badge = UIKit.Label(pill, {
        Position = UDim2.fromOffset(26, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Font = UIKit.Fonts.Semi,
        TextSize = 11,
        TextColor3 = COLORS.Running,
        Text = "Automation: starting",
        ZIndex = 4,
    })

    local function windowButton(text, offset, color)
        local button = UIKit.Button(titleBar, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, offset, 0.5, 0),
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = T.Tile,
            Font = UIKit.Fonts.Bold,
            TextSize = 16,
            TextColor3 = color or T.SubText,
            Text = text,
            ZIndex = 4,
        })
        UIKit.Corner(button, 9)
        return button
    end
    local minimizeButton = windowButton("–", -52)
    local closeButton = windowButton("×", -14, T.Bad)

    -- hidden: the controller still wires its own retry toggle to this
    self.AutoRetryButton = UIKit.New("TextButton", {
        Name = "AutoRetryButton",
        Visible = false,
        Text = "RETRY: ON",
        Parent = titleBar,
    })
    self.AutoRetryEnabled = true

    -----------------------------------------------------------------------
    -- sidebar
    -----------------------------------------------------------------------
    local sidebar = UIKit.New("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(12, 56),
        Size = UDim2.new(0, 52, 1, -68),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = main,
    })
    UIKit.Corner(sidebar, 14)
    UIKit.Stroke(sidebar, T.Stroke, 0.5)

    local tabList = UIKit.New("Frame", {
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = sidebar,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })

    local avatar = UIKit.New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.fromOffset(38, 38),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 3,
        Parent = sidebar,
    })
    UIKit.Corner(avatar, 19)
    UIKit.Stroke(avatar, T.Accent, 0.3, 1.5)

    -----------------------------------------------------------------------
    -- pages
    -----------------------------------------------------------------------
    local content = UIKit.New("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(76, 56),
        Size = UDim2.new(1, -88, 1, -68),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = main,
    })

    local function newPage(name, scrolling)
        local page
        if scrolling then
            page = UIKit.New("ScrollingFrame", {
                Name = name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = T.Muted,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Visible = false,
                ZIndex = 2,
                Parent = content,
            })
            UIKit.New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = page,
            })
            UIKit.Padding(page, 0, 0, 8, 6)
        else
            page = UIKit.New("Frame", {
                Name = name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Visible = false,
                ZIndex = 2,
                Parent = content,
            })
        end
        self.Pages[name] = page
        return page
    end

    local function pageHeader(page, order, title, subtitle)
        local header = UIKit.New("Frame", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            ZIndex = 2,
            Parent = page,
        })
        UIKit.Label(header, {
            Size = UDim2.new(1, 0, 0, 22),
            Font = UIKit.Fonts.Bold,
            TextSize = 17,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(header, {
            Position = UDim2.fromOffset(0, 22),
            Size = UDim2.new(1, 0, 0, 16),
            TextSize = 12,
            TextColor3 = T.Muted,
            Text = subtitle,
            ZIndex = 3,
        })
        return header
    end

    local function selectTab(name)
        for tabName, page in pairs(self.Pages) do
            local active = tabName == name
            if active and not page.Visible then
                page.Position = UDim2.fromOffset(0, 10)
                page.Visible = true
                UIKit.Tween(page, 0.3, { Position = UDim2.fromOffset(0, 0) })
            elseif not active then
                page.Visible = false
            end
        end
        for tabName, entry in pairs(self.TabButtons) do
            local active = tabName == name
            UIKit.Tween(entry.Button, 0.2, {
                BackgroundColor3 = active and T.Tile or T.Sidebar,
                TextColor3 = active and T.Text or T.Muted,
            })
            UIKit.Tween(entry.Bar, 0.2, { BackgroundTransparency = active and 0 or 1 })
        end
        self.CurrentTab = name
    end
    self.SelectTab = selectTab

    local function tabButton(name, icon, order)
        local button = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Size = UDim2.fromOffset(38, 38),
            BackgroundColor3 = T.Sidebar,
            BorderSizePixel = 0,
            Font = UIKit.Fonts.Bold,
            TextSize = 17,
            TextColor3 = T.Muted,
            Text = icon,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = tabList,
        })
        UIKit.Corner(button, 10)
        local bar = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, -7, 0.5, 0),
            Size = UDim2.fromOffset(3, 18),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = button,
        })
        UIKit.Corner(bar, 2)
        button.MouseButton1Click:Connect(function()
            selectTab(name)
        end)
        self.TabButtons[name] = { Button = button, Bar = bar }
    end

    tabButton("Home", "⌂", 1)
    tabButton("Automation", "⚔", 2)
    tabButton("Settings", "⚙", 3)
    tabButton("Configs", "▤", 4)
    tabButton("Inventory", "▦", 5)
    local inventoryPage = newPage("Inventory", false)
    if UIKit.BuildInventoryPage then UIKit.BuildInventoryPage(self, inventoryPage, controller) end

    -----------------------------------------------------------------------
    -- Home
    -----------------------------------------------------------------------
    local home = newPage("Home", false)

    local profile = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 66),
    }, T.Accent)
    local bigAvatar = UIKit.New("ImageLabel", {
        Position = UDim2.fromOffset(10, 9),
        Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = profile,
    })
    UIKit.Corner(bigAvatar, 12)
    UIKit.Label(profile, {
        Position = UDim2.fromOffset(70, 12),
        Size = UDim2.new(1, -80, 0, 22),
        Font = UIKit.Fonts.Bold,
        TextSize = 17,
        Text = "Hello, " .. tostring(LocalPlayer.DisplayName),
        ZIndex = 3,
    })
    self.ProfileSub = UIKit.Label(profile, {
        Position = UDim2.fromOffset(70, 35),
        Size = UDim2.new(1, -80, 0, 16),
        TextSize = 12,
        TextColor3 = T.SubText,
        Text = "@" .. tostring(LocalPlayer.Name),
        ZIndex = 3,
    })

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok and image and bigAvatar.Parent then
            bigAvatar.Image = image
            avatar.Image = image
        end
    end)

    local gridTop = 76
    local rowH = 134

    -- Session (green)
    local session = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, gridTop),
        Size = UDim2.new(0.5, -5, 0, rowH),
    }, T.Good)
    UIKit.Label(session, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Session", ZIndex = 3 })
    UIKit.Label(session, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14),
        TextSize = 10, TextColor3 = T.SubText, Text = "This server, right now", ZIndex = 3 })
    self.Playtime = UIKit.Tile(session, "Playtime", UDim2.fromOffset(10, 46), UDim2.new(0.5, -14, 0, 38))
    self.FPSLabel = UIKit.Tile(session, "FPS", UDim2.new(0.5, 4, 0, 46), UDim2.new(0.5, -14, 0, 38))
    self.Ping = UIKit.Tile(session, "Ping", UDim2.fromOffset(10, 88), UDim2.new(0.5, -14, 0, 38))
    self.PlayersLabel = UIKit.Tile(session, "Players", UDim2.new(0.5, 4, 0, 88), UDim2.new(0.5, -14, 0, 38))
    self.FPSLabel.Text = "0 fps"

    -- Automation (green when running, red when paused)
    local automation = UIKit.Card(home, {
        Position = UDim2.new(0.5, 5, 0, gridTop),
        Size = UDim2.new(0.5, -5, 0, rowH),
        GlowRotation = 20,
    }, T.Good)
    self.AutomationCard = automation
    UIKit.Label(automation, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Automation", ZIndex = 3 })
    self.AutomationState = UIKit.Label(automation, { Position = UDim2.fromOffset(12, 25),
        Size = UDim2.new(1, -24, 0, 14), TextSize = 10, TextColor3 = T.SubText, Text = "", ZIndex = 3 })
    self.Status = UIKit.Label(automation, {
        Position = UDim2.fromOffset(12, 44),
        Size = UDim2.new(1, -24, 0, 36),
        TextSize = 12,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "starting",
        ZIndex = 3,
    })
    local toggleBtn, setToggleColor = UIKit.Button(automation, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.new(1, -20, 0, 32),
        BackgroundColor3 = T.Good,
        Font = UIKit.Fonts.Bold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(12, 14, 18),
        Text = "Pause",
        ZIndex = 3,
    })
    UIKit.Corner(toggleBtn, 9)
    self.ToggleButton = toggleBtn
    self.SetToggleColor = setToggleColor

    -- Dungeon (violet)
    local dungeon = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, gridTop + rowH + 10),
        Size = UDim2.new(0.5, -5, 0, rowH),
    }, T.Accent)
    UIKit.Label(dungeon, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Dungeon", ZIndex = 3 })
    self.DungeonName = UIKit.Label(dungeon, { Position = UDim2.fromOffset(12, 25),
        Size = UDim2.new(1, -24, 0, 14), TextSize = 10, TextColor3 = T.SubText, Text = "-", ZIndex = 3 })
    self.TimeLeftLabel = UIKit.Tile(dungeon, "Time left", UDim2.fromOffset(10, 46), UDim2.new(0.5, -14, 0, 38))
    self.ProgressLabel = UIKit.Tile(dungeon, "Progress", UDim2.new(0.5, 4, 0, 46), UDim2.new(0.5, -14, 0, 38))
    self.RetryStatus = UIKit.Label(dungeon, {
        Position = UDim2.fromOffset(12, 92),
        Size = UDim2.new(1, -24, 0, 32),
        TextSize = 10,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = T.SubText,
        Text = "Retry: waiting for the final boss",
        ZIndex = 3,
    })

    -- Config (gold)
    local configCard = UIKit.Card(home, {
        Position = UDim2.new(0.5, 5, 0, gridTop + rowH + 10),
        Size = UDim2.new(0.5, -5, 0, rowH),
        GlowRotation = 20,
    }, T.Warn)
    UIKit.Label(configCard, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Config", ZIndex = 3 })
    UIKit.Label(configCard, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14),
        TextSize = 10, TextColor3 = T.SubText, Text = "Tap to manage configs", ZIndex = 3 })
    local homeActive = UIKit.Tile(configCard, "In use", UDim2.fromOffset(10, 46), UDim2.new(1, -20, 0, 38))
    local homeAutoLoad = UIKit.Tile(configCard, "Auto Load", UDim2.fromOffset(10, 88), UDim2.new(0.5, -14, 0, 38))
    local homeAutoExec = UIKit.Tile(configCard, "Auto Execute", UDim2.new(0.5, 4, 0, 88), UDim2.new(0.5, -14, 0, 38))
    local configTap = UIKit.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Parent = configCard,
    })
    configTap.MouseButton1Click:Connect(function()
        selectTab("Configs")
    end)
    table.insert(self.ConfigRefreshers, function()
        homeActive.Text = controller.ActiveConfig or "defaults (not saved)"
        homeAutoLoad.Text = controller.AutoLoadConfig ~= "" and controller.AutoLoadConfig or "off"
        homeAutoExec.Text = controller.AutoExecuteOnTeleport and "on" or "off"
        homeAutoLoad.TextColor3 = controller.AutoLoadConfig ~= "" and T.Good or T.SubText
        homeAutoExec.TextColor3 = controller.AutoExecuteOnTeleport and T.Good or T.SubText
    end)

    -----------------------------------------------------------------------
    -- Automation
    -----------------------------------------------------------------------
    local automationPage = newPage("Automation", true)
    pageHeader(automationPage, 0, "Automation", "What the script does for you")

    local function toggleRow(page, order, title, description, getter, setter, refreshers)
        local row = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
            Text = "",
            LayoutOrder = order,
            ZIndex = 2,
            Parent = page,
        })
        UIKit.Corner(row, 10)
        UIKit.Stroke(row, T.Stroke, 0.45)
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -80, 0, 18),
            Font = UIKit.Fonts.Semi,
            TextSize = 13,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 27),
            Size = UDim2.new(1, -80, 0, 16),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = description,
            ZIndex = 3,
        })
        local _, setSwitch = UIKit.Switch(row, UDim2.new(1, -14, 0.5, 0))
        local function refresh(instant)
            setSwitch(getter() == true, instant)
        end
        row.MouseEnter:Connect(function()
            UIKit.Tween(row, 0.15, { BackgroundColor3 = T.Tile })
        end)
        row.MouseLeave:Connect(function()
            UIKit.Tween(row, 0.2, { BackgroundColor3 = T.Card })
        end)
        row.MouseButton1Click:Connect(function()
            setter(not getter())
            refresh()
        end)
        refresh(true)
        table.insert(refreshers or self.ControlRefreshers, refresh)
        return row
    end

    self.AddToggleRow = toggleRow   -- later parts can add their own switches

    local function setMaster(value)
        controller.Enabled = value
        if not value then
            pcall(function()
                controller.Character:ReleaseAutomationFacing()
                controller.Dodger.CommittedDodgeDirection = Vector3.zero
                controller.Dodger.DodgeCommitUntil = 0
            end)
        end
        self:RefreshControls()
    end

    toggleRow(automationPage, 1, "Master Auto", "Turns all automation on or off",
        function() return controller.Enabled end, setMaster)
    toggleRow(automationPage, 2, "Auto Combat", "Casts Q / E at the chosen target",
        function() return controller.AutoCombat end,
        function(value) controller.AutoCombat = value end)
    toggleRow(automationPage, 3, "Smart Dodge", "Moves out of attack warnings and hitboxes",
        function() return controller.AutoDodge end,
        function(value) controller.AutoDodge = value end)
    toggleRow(automationPage, 4, "Auto Retry", "Replays the dungeon when it ends",
        function() return controller.AutoRetryEnabled end,
        function(value) controller.AutoRetryEnabled = value end)
    toggleRow(automationPage, 5, "Hazard ESP", "Draws attack hitboxes",
        function() return controller.AutoESP end,
        function(value) controller.AutoESP = value end)
    toggleRow(automationPage, 6, "Path Visualizer", "Draws the walking route",
        function() return controller.AutoPathESP end,
        function(value) controller.AutoPathESP = value end)
    toggleRow(automationPage, 7, "Dodge Aura Dots", "Shows safe / unsafe spots around you",
        function() return controller.ShowAura end,
        function(value) controller.ShowAura = value end)
    toggleRow(automationPage, 8, "Mob Group Circles", "Marks enemy packs",
        function() return controller.ShowMobGroups end,
        function(value) controller.ShowMobGroups = value end)
    toggleRow(automationPage, 9, "Low Effects", "Hides attack effects in boss fights and when the game lags",
        function() return controller.LowEffects ~= false end,
        function(value)
            controller.LowEffects = value
            if not value and controller.LowFx then
                controller.LowFx:Disable()
            end
        end)

    -----------------------------------------------------------------------
    -- Settings
    -----------------------------------------------------------------------
    local settingsPage = newPage("Settings", true)
    pageHeader(settingsPage, 0, "Settings", "Movement and combat tuning")

    local function sliderRow(order, title, description, getter, setter, minimum, maximum, step)
        local row = UIKit.New("Frame", {
            Size = UDim2.new(1, 0, 0, 72),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 2,
            Parent = settingsPage,
        })
        UIKit.Corner(row, 10)
        UIKit.Stroke(row, T.Stroke, 0.45)
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -90, 0, 18),
            Font = UIKit.Fonts.Semi,
            TextSize = 13,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 26),
            Size = UDim2.new(1, -90, 0, 14),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = description,
            ZIndex = 3,
        })
        local valueBox = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 10),
            Size = UDim2.fromOffset(52, 24),
            BackgroundColor3 = T.Tile,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = row,
        })
        UIKit.Corner(valueBox, 7)
        local valueLabel = UIKit.Label(valueBox, {
            Size = UDim2.fromScale(1, 1),
            Font = UIKit.Fonts.Semi,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })
        local track = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Position = UDim2.new(0, 14, 0, 52),
            Size = UDim2.new(1, -28, 0, 6),
            BackgroundColor3 = T.Off,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 3,
            Parent = row,
        })
        UIKit.Corner(track, 3)
        local fill = UIKit.New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = T.White,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = track,
        })
        UIKit.Corner(fill, 3)
        UIKit.Gradient(fill, T.Accent, T.Accent2, 0)
        local knob = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = T.White,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = track,
        })
        UIKit.Corner(knob, 8)

        local function refresh()
            local value = getter()
            local alpha = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
            valueLabel.Text = tostring(value)
        end

        local dragging = false
        local function update(x)
            local width = math.max(track.AbsoluteSize.X, 1)
            local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
            local value = minimum + math.floor(alpha * (maximum - minimum) / step + 0.5) * step
            setter(math.clamp(value, minimum, maximum))
            refresh()
        end
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                self.SliderDragging = true
                update(input.Position.X)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch)
            then
                update(input.Position.X)
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
                self.SliderDragging = false
            end
        end)
        refresh()
        table.insert(self.ControlRefreshers, refresh)
    end

    sliderRow(1, "Walk Speed", "Character speed (game default is 16)",
        function() return CONFIG.WalkSpeed end,
        function(value)
            CONFIG.WalkSpeed = value
            local humanoid = controller.Character.Humanoid
            if humanoid and humanoid.WalkSpeed <= 24 then
                humanoid.WalkSpeed = math.max(value, 16)
            end
        end, 12, 40, 1)
    sliderRow(2, "Combat Range", "Distance kept from normal enemies",
        function() return CONFIG.DesiredCombatRange end,
        function(value) CONFIG.DesiredCombatRange = value end, 24, 60, 1)
    sliderRow(3, "Damage Range", "How far away spells are cast",
        function() return CONFIG.DamageCastRange end,
        function(value) CONFIG.DamageCastRange = value end, 30, 80, 1)

    local keysCard = UIKit.Card(settingsPage, { Size = UDim2.new(1, 0, 0, 92), LayoutOrder = 4 })
    UIKit.Label(keysCard, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 18),
        Font = UIKit.Fonts.Semi, TextSize = 13, Text = "Window", ZIndex = 3 })
    UIKit.Label(keysCard, { Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 14),
        TextSize = 11, TextColor3 = T.Muted, Text = "RightShift shows / hides this window", ZIndex = 3 })
    local unloadButton = UIKit.Button(keysCard, {
        Position = UDim2.new(0, 14, 0, 50),
        Size = UDim2.new(0, 150, 0, 30),
        BackgroundColor3 = Color3.fromRGB(70, 30, 40),
        TextColor3 = T.Bad,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Unload script",
        ZIndex = 3,
    })
    UIKit.Corner(unloadButton, 8)
    local unloadArmed = 0
    unloadButton.MouseButton1Click:Connect(function()
        if os.clock() - unloadArmed > 3 then
            unloadArmed = os.clock()
            unloadButton.Text = "Tap again to unload"
            task.delay(3, function()
                if unloadButton.Parent then unloadButton.Text = "Unload script" end
            end)
            return
        end
        controller:Destroy()
    end)

    -----------------------------------------------------------------------
    -- Configs
    -----------------------------------------------------------------------
    local configsPage = newPage("Configs", true)
    pageHeader(configsPage, 0, "Configs", "Save, load and delete your setups")

    -- save row
    local saveCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1 })
    local nameBox = UIKit.New("TextBox", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -124, 0, 32),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = UIKit.Fonts.Body,
        TextSize = 13,
        TextColor3 = T.Text,
        PlaceholderText = "Config name (e.g. northern lands)",
        PlaceholderColor3 = T.Muted,
        Text = controller.ActiveConfig or "",
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = saveCard,
    })
    UIKit.Corner(nameBox, 8)
    UIKit.Padding(nameBox, 10, 0, 10, 0)
    local saveButton = UIKit.GradientButton(saveCard, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.fromOffset(100, 32),
        Text = "Save",
        ZIndex = 3,
    })
    saveButton.MouseButton1Click:Connect(function()
        local name = ConfigStore.CleanName(nameBox.Text)
            or self.SelectedConfig
            or controller.ActiveConfig
            or "default"
        if controller:SaveConfig(name) then
            self.SelectedConfig = name
            nameBox.Text = name
            self:RefreshConfigs()
        end
    end)

    -- list
    local listCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 2 })
    local listFrame = UIKit.New("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = listCard,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listFrame,
    })
    UIKit.Padding(listFrame, 2, 2, 2, 2)
    local emptyLabel = UIKit.Label(listCard, {
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = T.Muted,
        TextSize = 12,
        Text = "No saved configs yet - type a name and press Save",
        ZIndex = 3,
    })

    local deleteArmed = { Name = nil, At = 0 }

    local function smallButton(parent, text, color, textColor, x)
        local button = UIKit.Button(parent, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, x, 0.5, 0),
            Size = UDim2.fromOffset(64, 26),
            BackgroundColor3 = color,
            Font = UIKit.Fonts.Semi,
            TextSize = 12,
            TextColor3 = textColor,
            Text = text,
            ZIndex = 5,
        })
        UIKit.Corner(button, 7)
        return button
    end

    local function rebuildList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        local names = controller:ListConfigs()
        emptyLabel.Visible = #names == 0
        if self.SelectedConfig and not table.find(names, self.SelectedConfig) then
            self.SelectedConfig = nil
        end
        for index, name in ipairs(names) do
            local selected = name == self.SelectedConfig
            local item = UIKit.New("TextButton", {
                AutoButtonColor = false,
                Size = UDim2.new(1, -6, 0, 38),
                BackgroundColor3 = selected and T.TileHover or T.Tile,
                BorderSizePixel = 0,
                Text = "",
                LayoutOrder = index,
                ZIndex = 4,
                Parent = listFrame,
            })
            UIKit.Corner(item, 8)
            if selected then
                UIKit.Stroke(item, T.Accent, 0.2, 1.5)
            end
            local tags = {}
            if name == controller.ActiveConfig then table.insert(tags, "in use") end
            if name == controller.AutoLoadConfig then table.insert(tags, "auto load") end
            UIKit.Label(item, {
                Position = UDim2.fromOffset(12, 3),
                Size = UDim2.new(1, -170, 0, 18),
                Font = UIKit.Fonts.Semi,
                TextSize = 13,
                Text = name,
                ZIndex = 5,
            })
            UIKit.Label(item, {
                Position = UDim2.fromOffset(12, 19),
                Size = UDim2.new(1, -170, 0, 14),
                TextSize = 10,
                TextColor3 = #tags > 0 and T.Good or T.Muted,
                Text = #tags > 0 and table.concat(tags, "  •  ") or "saved",
                ZIndex = 5,
            })
            local loadButton = smallButton(item, "Load", Color3.fromRGB(38, 58, 104), T.Text, -78)
            local armed = deleteArmed.Name == name and os.clock() - deleteArmed.At < 3
            local deleteButton = smallButton(item, armed and "Sure?" or "Delete",
                Color3.fromRGB(78, 30, 42), T.Bad, -8)

            item.MouseButton1Click:Connect(function()
                self.SelectedConfig = name
                nameBox.Text = name
                self:RefreshConfigs()
            end)
            loadButton.MouseButton1Click:Connect(function()
                self.SelectedConfig = name
                nameBox.Text = name
                controller:LoadConfig(name)
            end)
            deleteButton.MouseButton1Click:Connect(function()
                if deleteArmed.Name ~= name or os.clock() - deleteArmed.At > 3 then
                    deleteArmed.Name, deleteArmed.At = name, os.clock()
                    deleteButton.Text = "Sure?"
                    task.delay(3, function()
                        if deleteButton.Parent and deleteArmed.Name == name then
                            deleteButton.Text = "Delete"
                        end
                    end)
                    return
                end
                deleteArmed.Name = nil
                if controller:DeleteConfig(name) then
                    if nameBox.Text == name then
                        nameBox.Text = ""
                    end
                    self.SelectedConfig = nil
                    self:RefreshConfigs()
                end
            end)
        end
    end

    -- switches
    local configSwitches = {}
    toggleRow(configsPage, 3, "Auto Load", "Load the selected config every time the script starts",
        function()
            local target = self.SelectedConfig or controller.ActiveConfig
            return controller.AutoLoadConfig ~= "" and controller.AutoLoadConfig == target
        end,
        function(value)
            if value then
                local target = self.SelectedConfig or controller.ActiveConfig
                if not target then
                    controller:Notify("Select or save a config first", "error")
                    return
                end
                controller:SetAutoLoad(target)
            else
                controller:SetAutoLoad("")
            end
        end, configSwitches)
    toggleRow(configsPage, 4, "Auto Execute", "Run the script again after every teleport",
        function() return controller.AutoExecuteOnTeleport end,
        function(value) controller:SetAutoExecute(value) end, configSwitches)

    local infoCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 5 })
    self.ScriptPathLabel = UIKit.Label(infoCard, {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 30),
        TextSize = 11,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = T.SubText,
        ZIndex = 3,
    })
    local resetButton = UIKit.Button(infoCard, {
        Position = UDim2.new(0, 14, 0, 44),
        Size = UDim2.new(0, 150, 0, 30),
        BackgroundColor3 = T.Tile,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Reset to defaults",
        ZIndex = 3,
    })
    UIKit.Corner(resetButton, 8)
    resetButton.MouseButton1Click:Connect(function()
        controller:ResetSettings()
    end)
    local refreshButton = UIKit.Button(infoCard, {
        Position = UDim2.new(0, 172, 0, 44),
        Size = UDim2.new(0, 110, 0, 30),
        BackgroundColor3 = T.Tile,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Refresh list",
        ZIndex = 3,
    })
    UIKit.Corner(refreshButton, 8)
    refreshButton.MouseButton1Click:Connect(function()
        self:RefreshConfigs()
    end)

    table.insert(self.ConfigRefreshers, function()
        rebuildList()
        for _, refresh in ipairs(configSwitches) do
            refresh()
        end
        local path = controller:GetScriptPath()
        local found = SafeFile.IsFile(path)
        self.ScriptPathLabel.Text = found
            and ("Auto Execute runs  workspace/" .. path .. "  after a teleport")
            or ("Auto Execute needs the script saved as  workspace/" .. path .. "  (build.cmd -Volt)")
        self.ScriptPathLabel.TextColor3 = found and T.SubText or T.Warn
    end)

    -----------------------------------------------------------------------
    -- toasts
    -----------------------------------------------------------------------
    local toastHolder = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(300, 300),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = gui,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = toastHolder,
    })
    self.ToastHolder = toastHolder
    self.ToastCount = 0

    -----------------------------------------------------------------------
    -- minimise bubble
    -----------------------------------------------------------------------
    local bubble, bubbleFrame = UIKit.GradientButton(gui, {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(48, 48),
        Text = "UIW",
        TextSize = 14,
        Rotation = 45,
        Visible = false,
        ZIndex = 40,
    }, 24)
    UIKit.Stroke(bubbleFrame, T.White, 0.6, 1.5)
    self.Bubble = bubbleFrame

    local function showWindow(show)
        self.Visible = show
        holder.Visible = show
        bubbleFrame.Visible = not show
        if show then
            updateScale()
            local target = scale.Scale
            scale.Scale = target * 0.96
            UIKit.Tween(scale, 0.25, { Scale = target })
        end
    end
    self.ShowWindow = showWindow

    minimizeButton.MouseButton1Click:Connect(function()
        showWindow(false)
    end)
    closeButton.MouseButton1Click:Connect(function()
        showWindow(false)
        self:Notify("Hidden - press RightShift or tap the UIW button", "info")
    end)

    -----------------------------------------------------------------------
    -- dragging (window by the title bar, bubble anywhere)
    -----------------------------------------------------------------------
    local function makeDraggable(handle, target, onClick)
        local dragging, moved, dragStart, startPosition = false, false, nil, nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging, moved = true, false
                dragStart = input.Position
                startPosition = target.Position
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not dragging or self.SliderDragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local delta = input.Position - dragStart
                if delta.Magnitude > 4 then moved = true end
                target.Position = UDim2.new(
                    startPosition.X.Scale, startPosition.X.Offset + delta.X,
                    startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
                )
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch)
            then
                dragging = false
                if not moved and onClick then onClick() end
            end
        end)
    end
    makeDraggable(titleBar, holder)
    makeDraggable(bubble, bubbleFrame, function() showWindow(true) end)

    toggleBtn.MouseButton1Click:Connect(function()
        setMaster(not controller.Enabled)
    end)

    selectTab(Workspace:FindFirstChild("dungeonName") and "Home" or "Inventory")
    self:RefreshControls()
    self:RefreshConfigs()
    if controller.StartupNotice then
        task.delay(0.5, function()
            self:Notify(controller.StartupNotice, "success")
        end)
    end

    return self
end

---------------------------------------------------------------------------
function HUD:Notify(text, kind)
    if not self.ToastHolder or not self.ToastHolder.Parent then
        return
    end
    local T = UIKit.Theme
    local color = ({
        success = T.Good,
        error = T.Bad,
        warning = T.Warn,
        info = T.Accent2,
    })[kind or "info"] or T.Accent2

    self.ToastCount += 1
    local toast = UIKit.New("Frame", {
        Size = UDim2.fromOffset(290, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = self.ToastCount,
        ZIndex = 51,
        Parent = self.ToastHolder,
    })
    UIKit.Corner(toast, 10)
    local stroke = UIKit.Stroke(toast, color, 1, 1)
    UIKit.Padding(toast, 14, 10, 12, 10)
    local bar = UIKit.New("Frame", {
        Position = UDim2.new(0, -8, 0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 52,
        Parent = toast,
    })
    UIKit.Corner(bar, 2)
    local label = UIKit.Label(toast, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextSize = 12,
        TextTransparency = 1,
        Text = tostring(text),
        ZIndex = 52,
    })

    UIKit.Tween(toast, 0.25, { BackgroundTransparency = 0.05 })
    UIKit.Tween(stroke, 0.25, { Transparency = 0.3 })
    UIKit.Tween(bar, 0.25, { BackgroundTransparency = 0 })
    UIKit.Tween(label, 0.25, { TextTransparency = 0 })

    task.delay(3.5, function()
        if not toast.Parent then return end
        UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
        UIKit.Tween(stroke, 0.3, { Transparency = 1 })
        UIKit.Tween(bar, 0.3, { BackgroundTransparency = 1 })
        UIKit.Tween(label, 0.3, { TextTransparency = 1 })
        task.wait(0.35)
        safeDestroy(toast)
    end)
end

function HUD:SetStatus(action, text)
    local color = STATUS_COLORS[action] or COLORS.Idle
    self.Accent.BackgroundColor3 = color
    self.Badge.TextColor3 = color
    self.Badge.Text = action == "IDLE" and "Automation: paused"
        or ("Automation: " .. string.lower(tostring(action)))
    self.Status.Text = text or action
end

local function readWorkspaceValue(name)
    local value = Workspace:FindFirstChild(name)
    if value and value:IsA("ValueBase") then
        return value.Value
    end
    return nil
end

function HUD:Heartbeat()
    self.Frames += 1

    local now = os.clock()
    local elapsed = now - self.StartTime

    if now - self.LastFpsUpdate >= 0.5 then
        local duration = now - self.LastFpsUpdate
        self.FPSLabel.Text = tostring(math.floor(self.Frames / duration)) .. " fps"
        self.Frames = 0
        self.LastFpsUpdate = now

        local hours = math.floor(elapsed / 3600)
        self.Playtime.Text = hours > 0
            and string.format("%d:%02d:%02d", hours, math.floor(elapsed / 60) % 60, math.floor(elapsed % 60))
            or string.format("%02d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60))

        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        self.Ping.Text = tostring(ping) .. " ms"
    end

    if now - self.LastSlowUpdate >= 1 then
        self.LastSlowUpdate = now
        self.PlayersLabel.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)

        local dungeonName = readWorkspaceValue("dungeonName")
        dungeonName = (dungeonName and dungeonName ~= "") and tostring(dungeonName) or "Lobby / not in a dungeon"
        self.DungeonName.Text = dungeonName
        self.ProfileSub.Text = "@" .. tostring(LocalPlayer.Name) .. "  •  " .. dungeonName

        local timeLeft = tonumber(readWorkspaceValue("timeLeft"))
        self.TimeLeftLabel.Text = (timeLeft and timeLeft > 0)
            and string.format("%d:%02d", math.floor(timeLeft / 60), timeLeft % 60)
            or "-"
        local progress = readWorkspaceValue("dungeonProgress")
        self.ProgressLabel.Text = (progress and progress ~= "") and tostring(progress) or "-"
    end
end

function HUD:Toggle()
    if self.ShowWindow then
        self.ShowWindow(not self.Visible)
    else
        self.Visible = not self.Visible
        self.Main.Visible = self.Visible
    end
end

function HUD:RefreshControls()
    for _, refresh in ipairs(self.ControlRefreshers or {}) do
        pcall(refresh)
    end

    local T = UIKit.Theme
    local enabled = self.Controller.Enabled
    if self.ToggleButton then
        self.ToggleButton.Text = enabled and "Pause automation" or "Resume automation"
        self.SetToggleColor(enabled and T.Good or T.Bad)
    end
    if self.AutomationCard then
        UIKit.SetGlow(self.AutomationCard, enabled and T.Good or T.Bad)
        self.AutomationState.Text = enabled and "Running - tap to pause" or "Paused - tap to resume"
    end
    if not enabled then
        self:SetStatus("IDLE", "paused")
    end
end

function HUD:RefreshConfigs()
    for _, refresh in ipairs(self.ConfigRefreshers or {}) do
        local ok, err = pcall(refresh)
        if not ok then
            warn("[UIW] config panel: " .. tostring(err))
        end
    end
end

function HUD:SetRetryStatus(text, color)
    if not self.RetryStatus then return end
    self.RetryStatus.Text = "Retry: " .. tostring(text)
    self.RetryStatus.TextColor3 = color or UIKit.Theme.SubText
end

function HUD:Destroy()
    if self.InventoryCleanup then self.InventoryCleanup() end
    for _, connection in ipairs(self.Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    safeDestroy(self.Gui)
end
