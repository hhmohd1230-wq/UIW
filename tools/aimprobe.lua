-- Why did a cast go in the wrong direction?
-- Records the facing at each key press and compares it with the direction the
-- spell actually came out in (the server picks the direction, so ping matters).
if getgenv().AimProbe and getgenv().AimProbe.Stop then getgenv().AimProbe.Stop() end
local A = { log = {}, hist = {}, running = true, conns = {} }
getgenv().AimProbe = A
local lp = game.Players.LocalPlayer
local u = getgenv().UIW
A.Stop = function()
    A.running = false
    for _, c in ipairs(A.conns) do pcall(function() c:Disconnect() end) end
    if u and A.OldPress then u.Combat.Press = A.OldPress end
end
local function yawOf(v)
    return math.deg(math.atan2(-v.X, -v.Z))
end
task.spawn(function()
    while A.running do
        local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        if r then
            table.insert(A.hist, { t = os.clock(), yaw = yawOf(r.CFrame.LookVector) })
            if #A.hist > 300 then table.remove(A.hist, 1) end
        end
        task.wait(0.05)
    end
end)
if u then
    A.OldPress = u.Combat.Press
    u.Combat.Press = function(self, slot)
        local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local e = u.CurrentEnemy
        local info = { t = os.clock(), slot = slot }
        if r then
            info.lookYaw = yawOf(r.CFrame.LookVector)
            info.desired = u.Character.DesiredYaw and math.deg(u.Character.DesiredYaw)
            if e and e.Root and e.Root.Parent then
                local to = (e.Root.Position - r.Position) * Vector3.new(1, 0, 1)
                if to.Magnitude > 0.1 then
                    info.targetYaw = yawOf(to.Unit)
                    info.dist = to.Magnitude
                    info.name = e.Model and e.Model.Name
                end
            end
        end
        table.insert(A.log, info)
        if #A.log > 80 then table.remove(A.log, 1) end
        return A.OldPress(self, slot)
    end
end
table.insert(A.conns, workspace.ChildAdded:Connect(function(c)
    if c.Name ~= "Frost Cone" and c.Name ~= "Ice Crash" and c.Name ~= "Lightning Burst" then return end
    task.wait(0.05)
    local p = c:FindFirstChild("PrimaryPart") or c:FindFirstChildWhichIsA("BasePart", true)
    if not p then return end
    local coneYaw = yawOf(p.CFrame.LookVector)
    local press
    for i = #A.log, 1, -1 do
        if not A.log[i].cone then press = A.log[i] break end
    end
    local best, bestd
    for _, h in ipairs(A.hist) do
        local d = math.abs((h.yaw - coneYaw + 540) % 360 - 180)
        if not bestd or d < bestd then best, bestd = h, d end
    end
    table.insert(A.log, {
        cone = true, t = os.clock(), coneYaw = coneYaw,
        sincePress = press and os.clock() - press.t or -1,
        matchAgo = best and (os.clock() - best.t) or -1,
        matchErr = bestd or -1,
        pressLook = press and press.lookYaw,
        pressTarget = press and press.targetYaw,
        errVsTarget = (press and press.targetYaw) and math.abs((coneYaw - press.targetYaw + 540) % 360 - 180) or nil,
    })
end))
function A.Report()
    local out = {}
    for _, e in ipairs(A.log) do
        if e.cone then
            table.insert(out, string.format("CAST-OUT yaw%.0f | %.2fs after press | same as facing %.2fs ago (err %.0f) | pressLook %.0f target %s | offBy %s",
                e.coneYaw, e.sincePress, e.matchAgo, e.matchErr, e.pressLook or 0,
                tostring(e.pressTarget and math.floor(e.pressTarget)), tostring(e.errVsTarget and math.floor(e.errVsTarget))))
        else
            table.insert(out, string.format("press %s look%.0f want%s target%s d%s %s", e.slot, e.lookYaw or 0,
                tostring(e.desired and math.floor(e.desired)), tostring(e.targetYaw and math.floor(e.targetYaw)),
                tostring(e.dist and math.floor(e.dist)), tostring(e.name)))
        end
    end
    return out
end
return "aimprobe on"
