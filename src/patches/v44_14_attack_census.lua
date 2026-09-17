-- v44.14: always-on attack census (read with getgenv().UIW_EF). For every new
-- attack model: name, nearest enemy, size, warning timing and lifetime.
do
    CONFIG.AttackCensus = true
    CONFIG.AttackCensusExamples = 3

    local function topModel(inst)
        local p = inst
        while p.Parent and p.Parent ~= Workspace do
            p = p.Parent
        end
        return p
    end

    local function describe(cont)
        local pre, hb
        for _, d in ipairs(cont:GetDescendants()) do
            if d:IsA("BasePart") then
                if d.Name == "precast" and not pre then pre = d end
                if d.Name == "hitBox" and not hb then hb = d end
            end
        end
        local s = ""
        if pre then
            s = s .. string.format("pT%.2f S%.0fx%.0f", pre.Transparency, pre.Size.X, pre.Size.Z)
        end
        if hb then
            s = s .. string.format(" hT%.2f%s S%.0fx%.0fx%.0f", hb.Transparency,
                hb:FindFirstChildOfClass("TouchTransmitter") and " TT" or "", hb.Size.X, hb.Size.Y, hb.Size.Z)
        end
        return s
    end

    ---------------------------------------------------------------------------
    -- Big bosses: cast range reaches their body, not their center, so casts
    -- still land while standing in a safe bubble / behind a wall.
    ---------------------------------------------------------------------------
    local BIG_BOSS_REACH = {
        ["crystal golem"] = 18,
        ["enchanted forest dragon"] = 24,
        ["sea king"] = 12,
        ["ancient temple protector"] = 10,
    }

    local reachCache = setmetatable({}, { __mode = "k" })
    local function bossReach(enemy)
        local cap = enemy and enemy.Model and BIG_BOSS_REACH[normalizeEnemyName(enemy.Model.Name)]
        if not cap then
            return 0
        end
        local cached = reachCache[enemy.Model]
        if cached and os.clock() - cached.At < 10 then
            return cached.Reach
        end
        local reach = 0
        local ok, size = pcall(enemy.Model.GetExtentsSize, enemy.Model)
        if ok and size then
            reach = math.min(math.min(size.X, size.Z) * 0.5 * 0.7, cap)
        end
        reachCache[enemy.Model] = { Reach = reach, At = os.clock() }
        return reach
    end

    local oldBossUpdate = CombatController.Update
    function CombatController:Update(enemy)
        local reach = bossReach(enemy)
        if reach <= 0 then
            return oldBossUpdate(self, enemy)
        end
        local base = CONFIG.DamageCastRange
        CONFIG.DamageCastRange = base + reach
        local ok, result = pcall(oldBossUpdate, self, enemy)
        CONFIG.DamageCastRange = base
        if not ok then error(result, 0) end
        return result
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.14"
        if not CONFIG.AttackCensus then
            return self
        end
        local log = { Started = os.clock(), ByName = {}, Count = 0, Dungeon = "?" }
        getgenv().UIW_EF = log
        local seen = setmetatable({}, { __mode = "k" })
        local controller = self

        self.Maid:Give(Workspace.DescendantAdded:Connect(function(inst)
            if not inst:IsA("BasePart") or (inst.Name ~= "hitBox" and inst.Name ~= "precast") then
                return
            end
            local cont = topModel(inst)
            if seen[cont] then
                return
            end
            seen[cont] = true
            log.Count += 1
            task.defer(function()
                if controller.Destroyed then return end
                local root = controller.Character.Root
                local pos = inst.Position
                local nearest, nearestDistance = "?", math.huge
                for _, e in ipairs(controller.Dungeon:GetAliveEnemies()) do
                    if e.Root and e.Root.Parent then
                        local d = (e.Root.Position - pos).Magnitude
                        if d < nearestDistance then
                            nearest, nearestDistance = e.Model.Name, d
                        end
                    end
                end
                local name = cont.Name
                local agg = log.ByName[name]
                if not agg then
                    agg = { n = 0, enemies = {}, examples = {} }
                    log.ByName[name] = agg
                end
                agg.n += 1
                agg.enemies[nearest] = (agg.enemies[nearest] or 0) + 1
                if #agg.examples >= CONFIG.AttackCensusExamples then
                    return
                end
                local ex = {
                    At = math.floor((os.clock() - log.Started) * 10) / 10,
                    En = nearest,
                    Ed = math.floor(nearestDistance),
                    Me = root and math.floor((root.Position - pos).Magnitude) or -1,
                    Seq = {},
                }
                table.insert(agg.examples, ex)
                local born = os.clock()
                local last
                for _, t in ipairs({ 0, 0.3, 0.6, 0.9, 1.2, 1.6, 2.2, 3, 4.5, 7, 10 }) do
                    local w = born + t - os.clock()
                    if w > 0 then task.wait(w) end
                    if not cont.Parent then
                        ex.Life = math.floor((os.clock() - born) * 10) / 10
                        break
                    end
                    local s = describe(cont)
                    if s ~= last then
                        table.insert(ex.Seq, t .. ":" .. s)
                        last = s
                    end
                end
                if cont.Parent and not ex.Life then
                    ex.Life = ">10"
                end
            end)
        end))
        -- Keep the census across teleports (one small file per dungeon).
        local lastSave = 0
        local forceSave = false
        local watched = nil
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            local humanoid = controller.Character.Humanoid
            if humanoid and humanoid ~= watched then
                watched = humanoid
                humanoid.Died:Connect(function()
                    task.delay(0.3, function()
                        forceSave = true
                    end)
                end)
            end
        end))
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if (now - lastSave < 30 and not forceSave) or log.Count == 0 then
                return
            end
            forceSave = false
            lastSave = now
            local key = controller:GetDungeonKey() or "unknown"
            local path = "UIW/census_" .. string.gsub(key, "[^%w]", "_") .. ".json"
            local saved = SafeFile.ReadJson(path) or {}
            for name, agg in pairs(log.ByName) do
                local entry = saved[name] or { n = 0, enemies = {}, examples = {} }
                entry.n = math.max(entry.n or 0, agg.n)
                entry.enemies = agg.enemies
                if #agg.examples > 0 then
                    entry.examples = agg.examples
                end
                saved[name] = entry
            end
            local t = getgenv().UIW_Telemetry
            if t then
                local hits = {}
                for i = math.max(1, #t.Hits - 25), #t.Hits do
                    local h = t.Hits[i]
                    local th = {}
                    for _, x in ipairs(h.Threats or {}) do
                        table.insert(th, x.Name .. "@" .. x.Distance)
                    end
                    table.insert(hits, string.format("%.1f %dM hp%d %s | %s", h.T, math.floor(h.Lost / 1e6), h.HealthPct, h.Reason, table.concat(th, ",")))
                end
                saved["__hits_" .. (t.RunId or "run")] = hits
            end
            SafeFile.WriteJson(path, saved, true)
        end))
        return self
    end
end

