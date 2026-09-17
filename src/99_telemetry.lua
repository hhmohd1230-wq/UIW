-- v38 telemetry: records every hit you take with the dodge state at that
-- moment, plus dodge-solver timing. Read it from getgenv().UIW_Telemetry.
do
    local telemetry = {
        StartedAt = os.clock(),
        Hits = {},
        HitCount = 0,
        DamageTaken = 0,
        Reasons = {},
        Solves = 0,
        SolveTime = 0,
        MaxSolveTime = 0,
        Casts = { q = 0, e = 0 },
        BlockReasons = {},
    }
    getgenv().UIW_Telemetry = telemetry

    local dodger = Controller.Dodger
    local solve = dodger.Solve
    dodger.Solve = function(self, ...)
        local startedAt = os.clock()
        local a, b, c, d = solve(self, ...)
        if self.LastSolve >= startedAt then
            local elapsed = os.clock() - startedAt
            telemetry.Solves += 1
            telemetry.SolveTime += elapsed
            telemetry.MaxSolveTime = math.max(telemetry.MaxSolveTime, elapsed)
            local reason = self.LastDodgeReason or "none"
            telemetry.Reasons[reason] = (telemetry.Reasons[reason] or 0) + 1
        end
        return a, b, c, d
    end

    local combat = Controller.Combat
    local press = combat.Press
    combat.Press = function(self, slot)
        telemetry.Casts[slot] = (telemetry.Casts[slot] or 0) + 1
        return press(self, slot)
    end
    local update = combat.Update
    combat.Update = function(self, enemy)
        local result = update(self, enemy)
        if self.LastBlockReason then
            telemetry.BlockReasons[self.LastBlockReason] = (telemetry.BlockReasons[self.LastBlockReason] or 0) + 1
        end
        return result
    end

    local function describeThreats(position)
        local list = {}
        for _, data in ipairs(Controller.Hazards:GetActive()) do
            local part = data.Part
            if part and part.Parent then
                local lp = part.CFrame:PointToObjectSpace(position)
                local half = part.Size * 0.5
                local distance = Vector3.new(
                    math.max(math.abs(lp.X) - half.X, 0),
                    math.max(math.abs(lp.Y) - half.Y, 0),
                    math.max(math.abs(lp.Z) - half.Z, 0)
                ).Magnitude
                if distance <= 20 then
                    local velocity = Controller.Hazards:GetProjectileVelocity(data)
                    table.insert(list, {
                        Name = (data.Container and data.Container.Name or "?") .. "/" .. part.Name,
                        Distance = math.floor(distance * 10) / 10,
                        Speed = math.floor(velocity.Magnitude),
                        Precast = data.IsPrecast == true,
                    })
                end
            end
        end
        table.sort(list, function(x, y) return x.Distance < y.Distance end)
        while #list > 4 do table.remove(list) end
        return list
    end

    local function nearestEnemies(position)
        local list = {}
        for _, enemy in ipairs(Controller.Dungeon:GetAliveEnemies()) do
            if enemy.Root and enemy.Root.Parent then
                table.insert(list, {
                    Name = enemy.Model.Name,
                    Distance = math.floor(flatten(enemy.Root.Position - position).Magnitude),
                    Class = getEnemyThreatClass(enemy) or "Ranged",
                })
            end
        end
        table.sort(list, function(x, y) return x.Distance < y.Distance end)
        while #list > 3 do table.remove(list) end
        return list
    end

    local hookedHumanoid = nil
    local healthConnection = nil

    local function hook(humanoid)
        if hookedHumanoid == humanoid then return end
        if healthConnection then healthConnection:Disconnect() end
        hookedHumanoid = humanoid
        local lastHealth = humanoid.Health
        healthConnection = humanoid.HealthChanged:Connect(function(health)
            local lost = lastHealth - health
            lastHealth = health
            if lost <= 0 or Controller.Destroyed then return end
            local root = Controller.Character.Root
            if not root then return end
            telemetry.HitCount += 1
            telemetry.DamageTaken += lost
            table.insert(telemetry.Hits, {
                T = math.floor((os.clock() - telemetry.StartedAt) * 10) / 10,
                Lost = math.floor(lost),
                HealthPct = math.floor(health / math.max(humanoid.MaxHealth, 1) * 100),
                Dodging = Controller.Dodger.IsDodging,
                Reason = Controller.Dodger.LastDodgeReason or "none",
                Panic = Controller.Dodger.MeleePanicActive,
                Status = Controller.HUD.Status.Text,
                Threats = describeThreats(root.Position),
                Enemies = nearestEnemies(root.Position),
            })
            while #telemetry.Hits > 60 do table.remove(telemetry.Hits, 1) end
        end)
    end

    Controller.Maid:Give(RunService.Heartbeat:Connect(function()
        local humanoid = Controller.Character.Humanoid
        if humanoid and humanoid.Parent then
            hook(humanoid)
        end
    end))

    Controller.Maid:Give(function()
        if healthConnection then healthConnection:Disconnect() end
    end)

    -- Save a snapshot every 5 s so the data survives teleports.
    local HttpService = game:GetService("HttpService")
    local runId = os.date("%m%d_%H%M%S")
    telemetry.RunId = runId
    local lastSave = 0
    Controller.Maid:Give(RunService.Heartbeat:Connect(function()
        if not CONFIG.TelemetrySave or os.clock() - lastSave < CONFIG.TelemetrySaveInterval or type(writefile) ~= "function" then return end
        lastSave = os.clock()
        pcall(function()
            local spots = {}
            for _, spot in ipairs(Controller.StuckSpots or {}) do
                table.insert(spots, {
                    Pos = string.format("%.0f,%.0f,%.0f", spot.Position.X, spot.Position.Y, spot.Position.Z),
                    Count = spot.Count,
                    Avoided = spot.Avoided,
                })
            end
            SafeFile.WriteJson("UIW/telemetry_" .. runId .. ".json", {
                RunId = runId,
                Dungeon = Workspace:FindFirstChild("dungeonName") and Workspace.dungeonName.Value or "?",
                Elapsed = math.floor(os.clock() - telemetry.StartedAt),
                Status = Controller.HUD.Status.Text,
                Retry = Controller.HUD.RetryStatus.Text,
                Alive = #Controller.Dungeon:GetAliveEnemies(),
                Solves = telemetry.Solves,
                AvgSolveMs = math.floor(telemetry.SolveTime / math.max(telemetry.Solves, 1) * 100000) / 100,
                MaxSolveMs = math.floor(telemetry.MaxSolveTime * 100000) / 100,
                Reasons = telemetry.Reasons,
                Casts = telemetry.Casts,
                BlockReasons = telemetry.BlockReasons,
                HitCount = telemetry.HitCount,
                DamageTaken = telemetry.DamageTaken,
                Hits = telemetry.Hits,
                StuckEvents = Controller.StuckEvents or 0,
                StuckSpots = spots,
                AvoidZones = #(Controller.Route.AvoidZones or {}),
                DamageProfile = Controller.Hazards.DamageProfile,
                TankedChecks = Controller.Hazards.TankedCount or 0,
                Fps = Controller.HUD.FPSLabel.Text,
            })
        end)
    end))
end
