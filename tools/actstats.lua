-- per attack name: how long it exists, how long its warning shows, how long UIW treats it as active
if getgenv().ActStats and getgenv().ActStats.Stop then getgenv().ActStats.Stop() end
local S = { names = {}, running = true, tracked = setmetatable({}, {__mode = "k"}), started = os.clock() }
getgenv().ActStats = S
S.Stop = function() S.running = false end
task.spawn(function()
  local last = os.clock()
  while S.running do
    local now = os.clock()
    local dt = now - last
    last = now
    local u = getgenv().UIW
    if u and not u.Destroyed then
      local active = {}
      for _, data in ipairs(u.Hazards.CachedActive or {}) do
        if data.Container then active[data.Container] = true end
      end
      for _, c in ipairs(workspace:GetChildren()) do
        local pc = c:FindFirstChild("precast", true)
        if pc or c:FindFirstChild("hitBox", true) or active[c] then
          local st = S.names[c.Name]
          if not st then
            st = { count = 0, life = 0, activeT = 0, preVisT = 0, afterFade = 0, noPre = 0, maxLife = 0 }
            S.names[c.Name] = st
          end
          local tr = S.tracked[c]
          if not tr then tr = { born = now } S.tracked[c] = tr st.count += 1 end
          st.life += dt
          st.maxLife = math.max(st.maxLife, now - tr.born)
          local vis = pc and pc:IsA("BasePart") and pc.Transparency < 0.95
          if vis then st.preVisT += dt tr.lastVis = now end
          if not pc then st.noPre += dt end
          if active[c] then
            st.activeT += dt
            if pc and not vis and tr.lastVis and now - tr.lastVis > 1.0 then st.afterFade += dt end
          end
        end
      end
    end
    task.wait(0.25)
  end
end)
function S.Report()
  local out = {}
  for name, st in pairs(S.names) do
    table.insert(out, string.format("%s n%d life%.0f max%.1f active%.0f warn%.0f activeAfterFade%.1f noWarn%.0f",
      name, st.count, st.life, st.maxLife, st.activeT, st.preVisT, st.afterFade, st.noPre))
  end
  table.sort(out)
  return out
end
return "actstats on"
