-- UIW diagnostics: stuck episodes, deaths, status samples -> getgenv().UIWDiag
if getgenv().UIWDiag and getgenv().UIWDiag.Stop then getgenv().UIWDiag.Stop() end
local D = { Stuck = {}, Samples = {}, Deaths = {}, Running = true, Started = os.clock() }
getgenv().UIWDiag = D
local lp = game.Players.LocalPlayer
local conns = {}
D.Stop = function()
  D.Running = false
  for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
end
local function stamp() return math.floor(os.clock() - D.Started) end
local function fmt(v) return string.format("%.0f,%.0f,%.0f", v.X, v.Y, v.Z) end
local function hook(ch)
  local h = ch:WaitForChild("Humanoid", 10)
  if not h then return end
  table.insert(conns, h.Died:Connect(function()
    local u = getgenv().UIW
    local r = ch:FindFirstChild("HumanoidRootPart")
    local near = {}
    if r then
      for _, c in ipairs(workspace:GetChildren()) do
        local p = c:IsA("BasePart") and c or (c:IsA("Model") and not c:FindFirstChildOfClass("Humanoid") and c:FindFirstChildWhichIsA("BasePart"))
        if p and c.Name ~= "map" and c.Name ~= "dungeon" and (p.Position - r.Position).Magnitude < 40 and #near < 8 then
          table.insert(near, c.Name)
        end
      end
    end
    table.insert(D.Deaths, string.format("T%d %s | %s | dodge %s | near %s", stamp(), r and fmt(r.Position) or "?",
      u and u.HUD and u.HUD.Status.Text or "", u and tostring(u.Dodger.LastDodgeReason) or "", table.concat(near, ",")))
  end))
end
if lp.Character then task.spawn(hook, lp.Character) end
table.insert(conns, lp.CharacterAdded:Connect(function(c) task.spawn(hook, c) end))

task.spawn(function()
  local hist, lastStuckAt = {}, 0
  while D.Running do
    local u = getgenv().UIW
    local ch = lp.Character
    local r = ch and ch:FindFirstChild("HumanoidRootPart")
    local h = ch and ch:FindFirstChildOfClass("Humanoid")
    if u and not u.Destroyed and r and h and h.Health > 0 then
      local now = os.clock()
      local cmd = u.LastCommandedMovement or Vector3.zero
      table.insert(hist, { t = now, p = r.Position, c = cmd.Magnitude })
      while #hist > 0 and now - hist[1].t > 2.5 do table.remove(hist, 1) end
      local moved = (r.Position - hist[1].p).Magnitude
      local avg = 0
      for _, s in ipairs(hist) do avg += s.c end
      avg /= #hist
      if now - hist[1].t > 2 and avg > 0.5 and moved < 2.5 and now - lastStuckAt > 4 and u.Enabled then
        lastStuckAt = now
        local rt = u.Route
        local wp = rt and rt.Waypoints and rt.Waypoints[rt.WaypointIndex]
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { ch }
        params.RespectCanCollide = true
        local dir = cmd.Magnitude > 0 and cmd.Unit or Vector3.zero
        local fwd = workspace:Raycast(r.Position + Vector3.new(0, -1.5, 0), dir * 6, params)
        local goal = rt and rt.CurrentGoal
        local route = goal and rt:GetSafeDirection(goal, u:GetTargetYaw()) or Vector3.zero
        table.insert(D.Stuck, string.format("T%d %s | %s | cmd %.2f,%.2f route %.2f,%.2f | fwd %s | path %s wp%d/%d fb%s | wp %s | goal %s | %s %s",
          stamp(), fmt(r.Position), u.HUD and u.HUD.Status.Text or "", dir.X, dir.Z, route.X, route.Z,
          fwd and (fwd.Instance.Name .. string.format(" d%.1f", fwd.Distance)) or "clear",
          rt and tostring(rt.LastPathStatus) or "-", rt and rt.WaypointIndex or 0, rt and #rt.Waypoints or 0, rt and tostring(rt.FallbackRoute) or "-",
          wp and (fmt(wp.Position) .. " " .. wp.Action.Name) or "-", goal and fmt(goal) or "-",
          h.FloorMaterial.Name, tostring(u.Dodger.LastDodgeReason)))
        if #D.Stuck > 40 then table.remove(D.Stuck, 1) end
      end
      if #D.Samples == 0 or now - D.Samples[#D.Samples].t > 5 then
        table.insert(D.Samples, { t = now, s = string.format("%d %s | %s", stamp(), u.HUD and u.HUD.Status.Text or "", fmt(r.Position)) })
        if #D.Samples > 150 then table.remove(D.Samples, 1) end
      end
    end
    task.wait(0.25)
  end
end)
return "diag on"
