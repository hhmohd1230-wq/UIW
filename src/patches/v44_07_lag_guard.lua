-- v44.7: lag guard, smoother path following, boss attack recorder,
-- Protector never stops attacking while escaping.
do
    CONFIG.PerfLiteFps = 38              -- below this FPS, switch visuals off
    CONFIG.PerfLiteHazards = 70          -- or when this many hazards are live
    CONFIG.PerfLiteRecover = 8           -- seconds of good FPS before visuals come back
    CONFIG.PathLookAhead = 14            -- studs of path to aim along (straighter walking)
    CONFIG.PathLookAheadMaxRise = 1.6    -- waypoint height change allowed inside the look-ahead
    CONFIG.PathLookAheadInterval = 0.2
    CONFIG.BossRecorderLimit = 260

    ---------------------------------------------------------------------------
    -- Profiler + adaptive "lite" mode
    ---------------------------------------------------------------------------
    local perf = {
        Steps = 0, StepTime = 0, StepMax = 0,
        Refreshes = 0, RefreshTime = 0, RefreshMax = 0,
        Sweeps = 0, SweepTime = 0,
        Added = 0, AddedRate = 0,
        Lite = false, LiteSince = 0, LiteSwitches = 0,
        Fps = 60,
    }
    getgenv().UIW_Perf = perf

    local function resetWindow()
        perf.Steps, perf.StepTime, perf.StepMax = 0, 0, 0
        perf.Refreshes, perf.RefreshTime, perf.RefreshMax = 0, 0, 0
        perf.Sweeps, perf.SweepTime = 0, 0
    end
    perf.Reset = resetWindow

    local oldRefresh = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local before = self.LastCacheTime
        local t0 = os.clock()
        local a = oldRefresh(self, force)
        if self.LastCacheTime ~= before then
            local dt = os.clock() - t0
            perf.Refreshes += 1
            perf.RefreshTime += dt
            if dt > perf.RefreshMax then perf.RefreshMax = dt end
        end
        return a
    end

    local oldSweep = HazardTracker.BroadSweep
    function HazardTracker:BroadSweep()
        local before = self.LastBroadSweep
        local t0 = os.clock()
        oldSweep(self)
        if self.LastBroadSweep ~= before then
            perf.Sweeps += 1
            perf.SweepTime += os.clock() - t0
        end
    end

    local oldStart = HazardTracker.Start
    function HazardTracker:Start()
        oldStart(self)
        self.Maid:Give(Workspace.DescendantAdded:Connect(function()
            perf.Added += 1
        end))
    end

    local VISUAL_FLAGS = { "AutoESP", "AutoPathESP", "ShowAura", "ShowMobGroups" }

    function UIWController:UpdatePerfMode(now)
        if now - (self.PerfCheckAt or 0) < 1 then
            return
        end
        local elapsed = now - (self.PerfCheckAt or now)
        self.PerfCheckAt = now

        local fps = 60
        pcall(function()
            fps = math.floor(Workspace:GetRealPhysicsFPS())
        end)
        -- Render FPS from the HUD label when it exists ("FPS 57" style).
        local label = self.HUD and self.HUD.FPSLabel and self.HUD.FPSLabel.Text
        local parsed = label and tonumber(string.match(label, "(%d+)"))
        if parsed then fps = parsed end
        perf.Fps = fps
        if elapsed > 0 then
            perf.AddedRate = math.floor(perf.Added / elapsed)
        end
        perf.Added = 0

        local hazards = #(self.Hazards.CachedActive or {})
        perf.Hazards = hazards
        perf.Warnings = #(self.Hazards.CachedWarnings or {})

        local heavy = fps < CONFIG.PerfLiteFps or hazards > CONFIG.PerfLiteHazards
        if heavy then
            self.PerfGoodSince = nil
            if not perf.Lite then
                perf.Lite = true
                perf.LiteSince = now
                perf.LiteSwitches += 1
            end
        elseif perf.Lite then
            self.PerfGoodSince = self.PerfGoodSince or now
            if now - self.PerfGoodSince >= CONFIG.PerfLiteRecover then
                perf.Lite = false
            end
        end
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        if self.Destroyed then return end
        local t0 = os.clock()
        self:UpdatePerfMode(t0)

        local saved = nil
        if perf.Lite then
            saved = {}
            for _, key in ipairs(VISUAL_FLAGS) do
                saved[key] = self[key]
                self[key] = false
            end
        end

        local ok, err = pcall(oldStep, self)

        if saved then
            for key, value in pairs(saved) do
                self[key] = value
            end
        end

        local dt = os.clock() - t0
        perf.Steps += 1
        perf.StepTime += dt
        if dt > perf.StepMax then perf.StepMax = dt end

        if not ok then
            perf.LastError = tostring(err)
            perf.Errors = (perf.Errors or 0) + 1
        end
    end

    ---------------------------------------------------------------------------
    -- Smoother walking: aim along the path a few waypoints ahead instead of
    -- at the next 4-stud waypoint (which wobbles on textured floors).
    ---------------------------------------------------------------------------
    local oldSafeDirection = RoutePlanner.GetSafeDirection
    function RoutePlanner:GetSafeDirection(goal, targetYaw, reachDistance)
        local direction = oldSafeDirection(self, goal, targetYaw, reachDistance)
        if direction.Magnitude <= 0 or self.FallbackRoute then
            return direction
        end

        local waypoints = self.Waypoints
        local index = self.WaypointIndex
        local root = self.CharacterService.Root
        if not root or #waypoints == 0 or index > #waypoints then
            return direction
        end

        local now = os.clock()
        if self.LookAheadTarget
            and self.LookAheadIndex == index
            and self.LookAheadPath == waypoints
            and now - (self.LookAheadAt or 0) < CONFIG.PathLookAheadInterval
        then
            local delta = flatten(self.LookAheadTarget - root.Position)
            if delta.Magnitude > 1 then
                return delta.Unit
            end
            return direction
        end

        self.LookAheadAt = now
        self.LookAheadIndex = index
        self.LookAheadPath = waypoints
        self.LookAheadTarget = nil

        local first = waypoints[index]
        if not first or first.Action == Enum.PathWaypointAction.Jump then
            return direction
        end

        -- Farthest waypoint within the look-ahead on the same level, no jumps.
        local baseY = first.Position.Y
        local travelled = flatten(first.Position - root.Position).Magnitude
        local farthest = index
        for i = index + 1, #waypoints do
            local w = waypoints[i]
            if w.Action == Enum.PathWaypointAction.Jump
                or math.abs(w.Position.Y - baseY) > CONFIG.PathLookAheadMaxRise
            then
                break
            end
            travelled += flatten(w.Position - waypoints[i - 1].Position).Magnitude
            if travelled > CONFIG.PathLookAhead then
                break
            end
            farthest = i
        end

        if farthest <= index then
            return direction
        end

        -- Walk back until the straight line is wide-clear.
        for i = farthest, index + 1, -1 do
            local target = waypoints[i].Position
            local ok, clear = pcall(function()
                return self.Geometry:IsWideSegmentClear(
                    root.Position,
                    Vector3.new(target.X, root.Position.Y, target.Z),
                    CONFIG.PathAgentRadius
                )
            end)
            if ok and clear then
                self.LookAheadTarget = target
                -- Waypoints we cut past count as reached.
                if i - 1 > index then
                    self.WaypointIndex = i - 1
                    self:SetupWaypointPlane()
                    self.LookAheadIndex = self.WaypointIndex
                end
                local delta = flatten(target - root.Position)
                if delta.Magnitude > 1 then
                    return delta.Unit
                end
                return direction
            end
            if i <= index + 1 then break end
        end

        return direction
    end

    -- The old visible-waypoint skip compared the root height (about 3 studs
    -- above the floor) with floor-level waypoints, so it almost never fired.
    local oldSkip = RoutePlanner.SkipToVisibleWaypoint
    function RoutePlanner:SkipToVisibleWaypoint(targetYaw)
        local root = self.CharacterService.Root
        local current = self.Waypoints[self.WaypointIndex]
        if not root or not current then
            return oldSkip(self, targetYaw)
        end
        local hip = root.Position.Y - current.Position.Y
        if hip > 1 and hip < 6 then
            -- Temporarily compare against floor height.
            local original = root.Position
            local ok, result = pcall(function()
                for index = math.min(#self.Waypoints, self.WaypointIndex + 5), self.WaypointIndex + 1, -1 do
                    local waypoint = self.Waypoints[index]
                    local skipJump = false
                    for j = self.WaypointIndex, index do
                        if self.Waypoints[j].Action == Enum.PathWaypointAction.Jump then skipJump = true break end
                    end
                    local delta = flatten(waypoint.Position - original)
                    if not skipJump and delta.Magnitude > 2 and delta.Magnitude <= 28
                        and math.abs(waypoint.Position.Y - current.Position.Y) <= 3
                        and self.Geometry:IsWideSegmentClear(original, Vector3.new(waypoint.Position.X, original.Y, waypoint.Position.Z), CONFIG.PathAgentRadius)
                        and self.Hazards:IsTrajectoryClear(original, delta.Unit, targetYaw, delta.Magnitude)
                    then
                        self.WaypointIndex = index
                        self.LastJumpWaypoint = 0
                        self:SetupWaypointPlane()
                        return true
                    end
                end
                return false
            end)
            if ok then return result end
        end
        return oldSkip(self, targetYaw)
    end

    ---------------------------------------------------------------------------
    -- Protector: escaping never blocks casting. If we are going to be hit
    -- anyway, the hit should at least come with damage on the boss.
    ---------------------------------------------------------------------------
    local oldCombat = CombatController.Update
    function CombatController:Update(enemy)
        if self.SuppressForMajorEscape and isBossEnemy(enemy) then
            self.SuppressForMajorEscape = false
            local result = oldCombat(self, enemy)
            self.SuppressForMajorEscape = true
            return result
        end
        return oldCombat(self, enemy)
    end

    ---------------------------------------------------------------------------
    -- Boss attack recorder (Protector / Sea King): what spawns, where and how
    -- it grows. Read with getgenv().UIW_BossLog.
    ---------------------------------------------------------------------------
    local bossLog = { Entries = {}, Started = os.clock() }
    getgenv().UIW_BossLog = bossLog

    local function round(v, d)
        local m = 10 ^ (d or 1)
        return math.floor(v * m + 0.5) / m
    end

    local function describe(part, boss, t)
        local rel = part.Position - boss.Root.Position
        local cf = part.CFrame
        return {
            T = round(t, 2),
            S = string.format("%.1f,%.1f,%.1f", part.Size.X, part.Size.Y, part.Size.Z),
            P = string.format("%.1f,%.1f,%.1f", rel.X, rel.Y, rel.Z),
            R = string.format("%.2f,%.2f,%.2f", cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z),
            V = round(part.Transparency, 2),
            Tt = part:FindFirstChildOfClass("TouchTransmitter") ~= nil,
        }
    end

    local oldRegister = HazardTracker.Register
    function HazardTracker:Register(part)
        local known = self.Hazards[part] ~= nil
        oldRegister(self, part)
        if known or not self.Hazards[part] then
            return
        end
        local owner = self.Owner
        local boss = owner and owner.CurrentEnemy
        if not boss or not boss.Root or not boss.Root.Parent then
            return
        end
        local bossName = normalizeEnemyName(boss.Model.Name)
        if bossName ~= "ancient temple protector" and bossName ~= "sea king" then
            return
        end
        bossLog.Counts = bossLog.Counts or {}
        local used = bossLog.Counts[bossName] or 0
        local limit = bossName == "sea king" and 320 or 140
        if used >= limit or #bossLog.Entries >= 460 then
            return
        end
        if part.Name ~= "hitBox" and part.Parent ~= Workspace then
            return
        end
        bossLog.Counts[bossName] = used + 1
        local data = self.Hazards[part]
        local born = os.clock()
        local entry = {
            Boss = boss.Model.Name,
            At = round(born - bossLog.Started, 2),
            Name = part.Name,
            Parent = part.Parent and part.Parent.Name or "?",
            Container = data.Container and data.Container.Name or "?",
            Precast = data.IsPrecast == true,
            Me = (function()
                local root = owner.Character and owner.Character.Root
                if not root then return "?" end
                local rel = root.Position - boss.Root.Position
                return string.format("%.1f,%.1f", rel.X, rel.Z)
            end)(),
            Look = string.format("%.2f,%.2f", boss.Root.CFrame.LookVector.X, boss.Root.CFrame.LookVector.Z),
            Samples = { describe(part, boss, 0) },
        }
        table.insert(bossLog.Entries, entry)
        for _, delay in ipairs({ 0.3, 0.7, 1.2, 2.0 }) do
            task.delay(delay, function()
                if part.Parent and boss.Root and boss.Root.Parent then
                    table.insert(entry.Samples, describe(part, boss, os.clock() - born))
                else
                    entry.Gone = entry.Gone or round(os.clock() - born, 2)
                end
            end)
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.7"
        self.Hazards.Owner = self
        return self
    end
end

