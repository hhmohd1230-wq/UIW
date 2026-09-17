-- UIW live-play recorder
-- Pauses UIW automation and records how a real player moves, casts and dodges.
--   loadstring(readfile("UIW/recorder.lua"))()   start (F8 stops and saves)
-- Saved to UIW/recordings/rec_<date>_<time>.json every 10 s and on stop.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local lp = Players.LocalPlayer

if getgenv().UIWRec and getgenv().UIWRec.Stop then
    pcall(getgenv().UIWRec.Stop)
end

local R = {
    Running = true,
    Started = os.clock(),
    Id = os.date("%m%d_%H%M%S"),
    Samples = {},
    Events = {},
    Conns = {},
}
getgenv().UIWRec = R

local function t()
    return math.floor((os.clock() - R.Started) * 10) / 10
end
local function f(v)
    return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end
local function event(kind, text)
    table.insert(R.Events, string.format("%.1f %s %s", t(), kind, text or ""))
end
local function give(c)
    table.insert(R.Conns, c)
    return c
end

-- pause the automation so the player is in control
local uiw = getgenv().UIW
if uiw and not uiw.Destroyed then
    R.WasEnabled = uiw.Enabled
    uiw.Enabled = false
    pcall(function() uiw.Character:ReleaseAutomationFacing() end)
    pcall(function() uiw.HUD:RefreshControls() end)
end

-- small REC badge
local gui = Instance.new("ScreenGui")
gui.Name = "UIW_REC"
gui.ResetOnSpawn = false
gui.DisplayOrder = 200
local badge = Instance.new("TextLabel")
badge.AnchorPoint = Vector2.new(0.5, 0)
badge.Position = UDim2.new(0.5, 0, 0, 6)
badge.Size = UDim2.fromOffset(230, 26)
badge.BackgroundColor3 = Color3.fromRGB(30, 12, 16)
badge.BackgroundTransparency = 0.15
badge.TextColor3 = Color3.fromRGB(255, 90, 100)
badge.Font = Enum.Font.GothamBold
badge.TextSize = 13
badge.Text = "REC  0:00  (F8 = stop & save)"
badge.Parent = gui
Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 13)
gui.Parent = lp:WaitForChild("PlayerGui")
R.Gui = gui

local function enemies()
    local list = {}
    local dungeon = Workspace:FindFirstChild("dungeon")
    if not dungeon then return list end
    for _, room in ipairs(dungeon:GetChildren()) do
        local folder = room:FindFirstChild("enemyFolder")
        if folder then
            for _, m in ipairs(folder:GetChildren()) do
                local h = m:IsA("Model") and m:FindFirstChildOfClass("Humanoid")
                local root = h and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                if h and root and h.Health > 0 then
                    table.insert(list, { Name = m.Name, Root = root, Hum = h, Room = room.Name })
                end
            end
        end
    end
    return list
end

local function attackParts(origin)
    local list = {}
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Model") or c:IsA("BasePart") then
            local part = c:FindFirstChild("hitBox") or c:FindFirstChild("precast")
            if not part and c:IsA("Model") then
                local inner = c:FindFirstChildWhichIsA("Model")
                part = inner and (inner:FindFirstChild("hitBox") or inner:FindFirstChild("precast"))
            end
            if part and part:IsA("BasePart") then
                local rel = part.CFrame:PointToObjectSpace(origin)
                local half = part.Size / 2
                local dx = math.max(math.abs(rel.X) - half.X, 0)
                local dz = math.max(math.abs(rel.Z) - half.Z, 0)
                local edge = math.sqrt(dx * dx + dz * dz)
                if edge < 40 then
                    local pre = c:FindFirstChild("precast", true)
                    table.insert(list, string.format("%s e%.1f %s", c.Name, edge,
                        pre and pre:IsA("BasePart") and string.format("T%.2f", pre.Transparency) or ""))
                end
            end
        end
    end
    return list
end

-- input
give(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local key = input.KeyCode
    if key == Enum.KeyCode.F8 then
        R.Stop()
        return
    end
    if key == Enum.KeyCode.Q or key == Enum.KeyCode.E or key == Enum.KeyCode.Space
        or key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.R or key == Enum.KeyCode.F
    then
        local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local target = ""
        if root then
            local best, bd
            for _, e in ipairs(enemies()) do
                local d = (e.Root.Position - root.Position).Magnitude
                if not bd or d < bd then best, bd = e, d end
            end
            if best then
                local look = root.CFrame.LookVector
                local to = (best.Root.Position - root.Position) * Vector3.new(1, 0, 1)
                local angle = to.Magnitude > 0 and math.deg(math.acos(math.clamp(look:Dot(to.Unit), -1, 1))) or 0
                target = string.format("nearest %s d%.0f facing-off %.0f", best.Name, bd, angle)
            end
        end
        event("key", key.Name .. " " .. target)
    end
end))

-- damage / deaths / respawns
local function hookCharacter(ch)
    local h = ch:WaitForChild("Humanoid", 10)
    if not h then return end
    local last = h.Health
    give(h.HealthChanged:Connect(function(hp)
        if hp < last - h.MaxHealth * 0.02 then
            local root = ch:FindFirstChild("HumanoidRootPart")
            event("hit", string.format("-%.0f%% hp%.0f%% | %s", (last - hp) / h.MaxHealth * 100, hp / h.MaxHealth * 100,
                root and table.concat(attackParts(root.Position), "; ") or ""))
        end
        last = hp
    end))
    give(h.Died:Connect(function()
        event("died", "")
    end))
end
if lp.Character then task.spawn(hookCharacter, lp.Character) end
give(lp.CharacterAdded:Connect(function(c)
    event("respawn", "")
    task.spawn(hookCharacter, c)
end))

-- new attacks near us
give(Workspace.ChildAdded:Connect(function(c)
    if c.Name == "groundAura" or c.Name == "Frost Cone" then return end
    task.defer(function()
        local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local part = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart", true)
        if root and part and (part.Position - root.Position).Magnitude < 80 then
            event("spawn", string.format("%s %s size %.0fx%.0fx%.0f d%.0f at %s",
                c.Name, part.Name, part.Size.X, part.Size.Y, part.Size.Z,
                (part.Position - root.Position).Magnitude, f(part.Position)))
        end
    end)
end))

local function save()
    pcall(function()
        if isfolder and not isfolder("UIW/recordings") then
            makefolder("UIW/recordings")
        end
        local progress = Workspace:FindFirstChild("dungeonProgress")
        local name = Workspace:FindFirstChild("dungeonName")
        writefile("UIW/recordings/rec_" .. R.Id .. ".json", HttpService:JSONEncode({
            Dungeon = name and name.Value or "",
            Progress = progress and progress.Value or "",
            Seconds = t(),
            Samples = R.Samples,
            Events = R.Events,
        }))
    end)
end
R.Save = save

function R.Stop()
    if not R.Running then return end
    R.Running = false
    event("stop", "")
    save()
    for _, c in ipairs(R.Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() R.Gui:Destroy() end)
    local u = getgenv().UIW
    if u and not u.Destroyed and R.WasEnabled ~= nil then
        u.Enabled = R.WasEnabled
        pcall(function() u.HUD:RefreshControls() end)
    end
    print("[UIW] recording saved: UIW/recordings/rec_" .. R.Id .. ".json")
end

event("start", Workspace:FindFirstChild("dungeonName") and Workspace.dungeonName.Value or "")

task.spawn(function()
    local lastSave = os.clock()
    while R.Running do
        local ch = lp.Character
        local root = ch and ch:FindFirstChild("HumanoidRootPart")
        local h = ch and ch:FindFirstChildOfClass("Humanoid")
        if root and h and h.Health > 0 then
            local near = {}
            local list = enemies()
            table.sort(list, function(a, b)
                return (a.Root.Position - root.Position).Magnitude < (b.Root.Position - root.Position).Magnitude
            end)
            for i = 1, math.min(4, #list) do
                local e = list[i]
                table.insert(near, string.format("%s@%s hp%.0f", e.Name, f(e.Root.Position), e.Hum.Health / e.Hum.MaxHealth * 100))
            end
            local vel = root.AssemblyLinearVelocity
            table.insert(R.Samples, string.format("%.1f p%s v%.1f,%.1f look%.2f,%.2f hp%.0f ws%.0f | %s | %s",
                t(), f(root.Position), vel.X, vel.Z, root.CFrame.LookVector.X, root.CFrame.LookVector.Z,
                h.Health / h.MaxHealth * 100, h.WalkSpeed,
                table.concat(near, "; "), table.concat(attackParts(root.Position), "; ")))
        end
        local elapsed = os.clock() - R.Started
        badge.Text = string.format("REC  %d:%02d  (F8 = stop & save)", math.floor(elapsed / 60), math.floor(elapsed % 60))
        if os.clock() - lastSave > 10 then
            lastSave = os.clock()
            save()
        end
        task.wait(0.2)
    end
end)

return "recording " .. R.Id
