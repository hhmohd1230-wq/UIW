-- Inventory page: the hub's front end for the inventory engine.
--
-- The engine itself does not own a window. It attaches to Dungeon Quest's own
-- inventory GUI and adds sorting, filters, upgrade planning and sell planning
-- to it, which is why its controls appear inside the game's inventory rather
-- than here. So this page is not a copy of that - it is the part that was
-- missing: somewhere to turn it on, see that it is alive, and read what it has
-- actually done, without opening the inventory to find out.
--
-- It loads the engine from the bundled source only when asked. Until then
-- nothing of it runs, which keeps a 440 KB chunk out of every dungeon run that
-- has no use for it.
do
    local ENGINE_KEY = "__DQ_INVENTORY_CLASS_SORTER_V1"

    local function env()
        return (getgenv and getgenv()) or _G
    end

    local function engine()
        local value = env()[ENGINE_KEY]
        return type(value) == "table" and value or nil
    end

    -- "12.4M" reads better than "12400000" in a tile two inches wide
    local function compact(value)
        value = tonumber(value) or 0
        local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
        for _, unit in ipairs(units) do
            if value >= unit[1] then
                return string.format("%.1f%s", value / unit[1], unit[2])
            end
        end
        return tostring(math.floor(value))
    end

    -- What the engine knows, reduced to the four numbers worth a glance.
    local function readStats()
        local controller = engine()
        if not controller then
            return nil
        end
        local tracked, bestPotential = 0, 0
        for _, info in pairs(controller.InventoryInfos or {}) do
            if type(info) == "table" then
                tracked += 1
                local potential = tonumber(info.Potential) or 0
                if potential > bestPotential then
                    bestPotential = potential
                end
            end
        end
        local session = controller.SessionStats or {}
        return {
            Alive = controller.Alive ~= false,
            Tracked = tracked,
            BestPotential = bestPotential,
            Upgrades = tonumber(session.Upgrades) or 0,
            Equipped = tonumber(session.Equipped) or 0,
            Sold = tonumber(session.Sold) or 0,
            SellGold = tonumber(session.SellGold) or 0,
            UpgradeGold = tonumber(session.UpgradeGold) or 0,
        }
    end

    function UIKit.BuildInventoryPage(hud, page, controller)
        local T = UIKit.Theme

        -----------------------------------------------------------------------
        -- Status card
        -----------------------------------------------------------------------
        local header = UIKit.Card(page, {
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 96),
        }, T.Accent)

        UIKit.Label(header, {
            Position = UDim2.fromOffset(16, 14),
            Size = UDim2.new(1, -150, 0, 20),
            Font = UIKit.Fonts.Bold,
            TextSize = 16,
            Text = "Inventory Tools",
            ZIndex = 3,
        })

        local blurb = UIKit.Label(header, {
            Position = UDim2.fromOffset(16, 38),
            Size = UDim2.new(1, -150, 0, 44),
            Font = UIKit.Fonts.Body,
            TextSize = 12,
            TextColor3 = T.SubText,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = "Sorting, filters, upgrade planning and sell planning, added to the game's own inventory window. Open your inventory to use them.",
            ZIndex = 3,
        })

        -- a pill that says, at a glance, whether any of this is running
        local pill = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 14),
            Size = UDim2.fromOffset(104, 26),
            BackgroundColor3 = T.Off,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = header,
        })
        UIKit.Corner(pill, 13)
        local dot = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 10, 0.5, 0),
            Size = UDim2.fromOffset(8, 8),
            BackgroundColor3 = T.Muted,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = pill,
        })
        UIKit.Corner(dot, 4)
        local pillText = UIKit.Label(pill, {
            Position = UDim2.fromOffset(24, 0),
            Size = UDim2.new(1, -30, 1, 0),
            Font = UIKit.Fonts.Semi,
            TextSize = 12,
            TextColor3 = T.SubText,
            Text = "Off",
            ZIndex = 4,
        })

        -----------------------------------------------------------------------
        -- The four numbers
        -----------------------------------------------------------------------
        local tiles = UIKit.Card(page, {
            Position = UDim2.fromOffset(0, 104),
            Size = UDim2.new(1, 0, 0, 62),
        })
        local width = 0.25
        local trackedValue = UIKit.Tile(tiles, "Items tracked",
            UDim2.new(0 * width, 8, 0, 8), UDim2.new(width, -12, 1, -16))
        local bestValue = UIKit.Tile(tiles, "Best potential",
            UDim2.new(1 * width, 4, 0, 8), UDim2.new(width, -12, 1, -16))
        local upgradeValue = UIKit.Tile(tiles, "Upgrades bought",
            UDim2.new(2 * width, 4, 0, 8), UDim2.new(width, -12, 1, -16))
        local soldValue = UIKit.Tile(tiles, "Sold this session",
            UDim2.new(3 * width, 4, 0, 8), UDim2.new(width, -8, 1, -16))

        -----------------------------------------------------------------------
        -- Controls
        -----------------------------------------------------------------------
        local controls = UIKit.Card(page, {
            Position = UDim2.fromOffset(0, 174),
            Size = UDim2.new(1, 0, 0, 58),
        })

        local rowLabel = UIKit.Label(controls, {
            Position = UDim2.fromOffset(16, 10),
            Size = UDim2.new(1, -180, 0, 18),
            Font = UIKit.Fonts.Semi,
            TextSize = 13,
            Text = "Enable inventory tools",
            ZIndex = 3,
        })
        local rowHint = UIKit.Label(controls, {
            Position = UDim2.fromOffset(16, 28),
            Size = UDim2.new(1, -180, 0, 16),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = "Loads on demand; nothing runs until you switch it on.",
            ZIndex = 3,
        })

        local _, setSwitch = UIKit.Switch(controls, UDim2.new(1, -16, 0.5, 0))
        local switchButton = UIKit.New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.fromOffset(42, 22),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 5,
            Parent = controls,
        })

        -----------------------------------------------------------------------
        -- Focus upgrade: one item, to a level you choose
        --
        -- Auto Upgrade Best picks for you, which is right until you have
        -- decided which weapon you are keeping. This is the other case: name
        -- the item, name the level, stop there.
        -----------------------------------------------------------------------
        local focus = UIKit.Card(page, {
            Position = UDim2.fromOffset(0, 240),
            Size = UDim2.new(1, 0, 0, 150),
        })

        UIKit.Label(focus, {
            Position = UDim2.fromOffset(16, 10),
            Size = UDim2.new(1, -32, 0, 18),
            Font = UIKit.Fonts.Bold,
            TextSize = 13,
            Text = "Upgrade one item to a target",
            ZIndex = 3,
        })

        local list = UIKit.New("ScrollingFrame", {
            Position = UDim2.fromOffset(16, 34),
            Size = UDim2.new(1, -32, 0, 72),
            BackgroundColor3 = T.Tile,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = T.Muted,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 3,
            Parent = focus,
        })
        UIKit.Corner(list, 8)
        UIKit.New("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = list,
        })

        local chosenUID, chosenName, rows = nil, nil, {}

        local targetPct = 100
        local targetButton = UIKit.Button(focus, {
            Position = UDim2.fromOffset(16, 114),
            Size = UDim2.fromOffset(96, 26),
            Text = "Target: 100%",
            ZIndex = 3,
        })
        UIKit.Corner(targetButton, 7)

        local runButton, setRunColour = UIKit.Button(focus, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -16, 0, 114),
            Size = UDim2.fromOffset(150, 26),
            BackgroundColor3 = T.Off,
            Text = "Choose an item",
            ZIndex = 3,
        })
        UIKit.Corner(runButton, 7)

        local status = UIKit.Label(focus, {
            Position = UDim2.fromOffset(122, 114),
            Size = UDim2.new(1, -290, 0, 26),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = "",
            ZIndex = 3,
        })

        local function refreshRunButton()
            if chosenUID then
                runButton.Text = string.format("Upgrade to %d%%", targetPct)
                setRunColour(T.Accent)
            else
                runButton.Text = "Choose an item"
                setRunColour(T.Off)
            end
        end

        targetButton.MouseButton1Click:Connect(function()
            -- the levels anyone actually stops at
            local steps = { 25, 50, 75, 100 }
            local index = 1
            for i, value in ipairs(steps) do
                if value == targetPct then index = i % #steps + 1 break end
            end
            targetPct = steps[index]
            targetButton.Text = "Target: " .. targetPct .. "%"
            refreshRunButton()
        end)

        local function selectRow(uid, name, button)
            chosenUID, chosenName = uid, name
            for other, otherButton in pairs(rows) do
                otherButton.BackgroundColor3 = other == uid and T.Accent or T.Tile
                otherButton.BackgroundTransparency = other == uid and 0 or 0.55
            end
            status.Text = "Selected " .. tostring(name)
            refreshRunButton()
        end

        local function rebuildList()
            local controller = engine()
            for _, row in pairs(rows) do row:Destroy() end
            rows = {}
            if not controller or type(controller.ListUpgradable) ~= "function" then
                return
            end
            local ok, items = pcall(controller.ListUpgradable, controller)
            if not ok or type(items) ~= "table" then
                return
            end
            for order, item in ipairs(items) do
                if order > 40 then break end
                local row = UIKit.Button(list, {
                    Size = UDim2.new(1, -6, 0, 22),
                    BackgroundColor3 = T.Tile,
                    BackgroundTransparency = 0.55,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextSize = 11,
                    LayoutOrder = order,
                    ZIndex = 4,
                    Text = string.format("  %s   %d/%d   pot %s",
                        item.Name, item.Current, item.Maximum, compact(item.Potential)),
                })
                UIKit.Corner(row, 6)
                rows[item.UID] = row
                row.MouseButton1Click:Connect(function()
                    selectRow(item.UID, item.Name, row)
                end)
            end
            if chosenUID and not rows[chosenUID] then
                chosenUID = nil
                status.Text = "That item is gone from your inventory."
                refreshRunButton()
            end
        end

        runButton.MouseButton1Click:Connect(function()
            local controller = engine()
            if not controller then
                status.Text = "Turn the inventory tools on first."
                return
            end
            if not chosenUID then
                status.Text = "Pick an item from the list."
                return
            end
            controller:SetFocusUpgrade(chosenUID, targetPct)
            status.Text = "Planning " .. tostring(chosenName) .. "..."
            task.spawn(function()
                local ok, message = controller:RunFocusUpgrade()
                status.Text = ok and ("Upgrade sent for " .. tostring(chosenName))
                    or tostring(message or "Upgrade was not started.")
                task.wait(1)
                pcall(rebuildList)
            end)
        end)

        -----------------------------------------------------------------------
        -- Where the controls actually are
        -----------------------------------------------------------------------
        local footer = UIKit.Card(page, {
            Position = UDim2.fromOffset(0, 398),
            Size = UDim2.new(1, 0, 0, 44),
        })
        local footerText = UIKit.Label(footer, {
            Position = UDim2.fromOffset(16, 8),
            Size = UDim2.new(1, -32, 1, -16),
            TextSize = 12,
            TextColor3 = T.SubText,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = "Once enabled, open the game's inventory: a class bar, sort and filter menus and the upgrade and sell planners appear inside it.",
            ZIndex = 3,
        })

        -----------------------------------------------------------------------
        -- Wiring
        -----------------------------------------------------------------------
        local function setPill(state, colour, text)
            UIKit.Tween(dot, 0.2, { BackgroundColor3 = colour })
            pillText.Text = text
            pillText.TextColor3 = colour
            UIKit.SetGlow(header, colour)
        end

        local starting = false

        local function start()
            if engine() or starting then
                return
            end
            if type(UIWInventorySource) ~= "string" then
                setPill(false, T.Bad, "Missing")
                footerText.Text = "The inventory engine was not bundled into this build."
                return
            end
            starting = true
            setPill(false, T.Warn, "Loading")
            task.spawn(function()
                local chunk, compileError = loadstring(UIWInventorySource, "=UIWInventory")
                if not chunk then
                    starting = false
                    setPill(false, T.Bad, "Error")
                    footerText.Text = "Inventory engine failed to compile: " .. tostring(compileError)
                    return
                end
                local ok, runError = pcall(chunk)
                starting = false
                if not ok then
                    setPill(false, T.Bad, "Error")
                    footerText.Text = "Inventory engine failed to start: " .. tostring(runError)
                    setSwitch(false)
                end
            end)
        end

        local function stop()
            local current = engine()
            if current and type(current.Stop) == "function" then
                pcall(current.Stop, current)
            end
            env()[ENGINE_KEY] = nil
        end

        switchButton.MouseButton1Click:Connect(function()
            if engine() or starting then
                setSwitch(false)
                stop()
            else
                setSwitch(true)
                start()
            end
        end)

        -----------------------------------------------------------------------
        -- Refresh
        -----------------------------------------------------------------------
        local running = true
        local function refresh()
            local stats = readStats()
            if not stats then
                setPill(false, starting and T.Warn or T.Muted, starting and "Loading" or "Off")
                trackedValue.Text = "-"
                bestValue.Text = "-"
                upgradeValue.Text = "-"
                soldValue.Text = "-"
                return
            end
            setPill(true, T.Good, "Active")
            trackedValue.Text = tostring(stats.Tracked)
            bestValue.Text = stats.BestPotential > 0 and compact(stats.BestPotential) or "-"
            upgradeValue.Text = string.format("%d  (%s gold)", stats.Upgrades, compact(stats.UpgradeGold))
            soldValue.Text = string.format("%d  (%s gold)", stats.Sold, compact(stats.SellGold))
            pcall(rebuildList)
        end

        task.spawn(function()
            while running do
                pcall(refresh)
                task.wait(1)
            end
        end)

        -- The HUD calls this on teardown. Without it the loop above keeps a
        -- destroyed page alive and the engine outlives the hub that started it.
        hud.InventoryCleanup = function()
            running = false
            stop()
        end

        refresh()
        return page
    end
end
