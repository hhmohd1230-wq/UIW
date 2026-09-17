-- v44.9: Sea King lag fix + dead-boss leftovers.
-- Live finding: after the Protector dies, ~1700 of its slam hitbox parts stay
-- in Workspace. Every hazard refresh and every broad sweep walked all of them
-- (60 ms each), which dropped the Sea King fight to 3-15 FPS.
do
    CONFIG.HazardNearRadius = 320        -- hazards farther than this are not refreshed
    CONFIG.HazardNearRebuild = 0.75
    CONFIG.ContainerRescan = 3           -- known attack containers are rescanned at most this often
    CONFIG.ContainerFarRadius = 380
    CONFIG.DeadBossLeftoverRadius = 420
    CONFIG.DeadBossMobGuard = 150        -- leftovers near a living enemy still count

    local function containerPosition(container)
        if container:IsA("BasePart") then
            return container.Position
        end
        if container:IsA("Model") then
            local ok, pivot = pcall(container.GetPivot, container)
            if ok then
                return pivot.Position
            end
        end
        local part = container:FindFirstChildWhichIsA("BasePart", true)
        return part and part.Position
    end

    local oldContainer = HazardTracker.RegisterAttackContainer
    function HazardTracker:RegisterAttackContainer(container)
        if not container or not container.Parent then
            return
        end
        self.ContainerMemo = self.ContainerMemo or setmetatable({}, { __mode = "k" })
        local now = os.clock()
        local memo = self.ContainerMemo[container]
        if memo then
            if now - memo.First > 0.6 and now - memo.At < CONFIG.ContainerRescan then
                return
            end
        else
            memo = { First = now, At = 0 }
            self.ContainerMemo[container] = memo
        end
        memo.At = now

        if now - memo.First > 0.6 then
            local root = self.CharacterService.Root
            local position = root and containerPosition(container)
            if position and (position - root.Position).Magnitude > CONFIG.ContainerFarRadius then
                return
            end
        end

        return oldContainer(self, container)
    end

    ---------------------------------------------------------------------------
    -- Dead bosses: their leftovers never hurt.
    ---------------------------------------------------------------------------
    function HazardTracker:UpdateBossDeaths(now)
        if now - (self.BossDeathCheckAt or 0) < 0.25 or not self.Dungeon then
            return
        end
        self.BossDeathCheckAt = now
        self.BossSeen = self.BossSeen or {}
        self.DeadBosses = self.DeadBosses or {}

        local alive = {}
        self.AliveEnemyPositions = {}
        for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
            if enemy.Model and enemy.Root and enemy.Root.Parent then
                if not isBossEnemy(enemy) then
                    table.insert(self.AliveEnemyPositions, enemy.Root.Position)
                end
                if isBossEnemy(enemy) then
                    alive[enemy.Model] = true
                    self.BossSeen[enemy.Model] = {
                        Position = enemy.Root.Position,
                        Name = normalizeEnemyName(enemy.Model.Name),
                    }
                end
            end
        end

        for model, info in pairs(self.BossSeen) do
            local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
            local dead = not alive[model] and (not humanoid or humanoid.Health <= 0 or not model.Parent)
            if dead then
                self.BossSeen[model] = nil
                table.insert(self.DeadBosses, { Position = info.Position, Name = info.Name, At = now })
                self.NearBuiltAt = 0
                if info.Name == "ancient temple protector" then
                    self.ProtectorDead = true
                    self.ProtectorDeadSeen = true
                end
            end
        end
    end

    function HazardTracker:IsDeadBossLeftover(part, data)
        if not self.DeadBosses or #self.DeadBosses == 0 then
            return false
        end
        local position = part.Position
        for _, dead in ipairs(self.DeadBosses) do
            if (data.BornAt or 0) <= dead.At + 0.5
                and (position - dead.Position).Magnitude <= CONFIG.DeadBossLeftoverRadius + part.Size.Magnitude * 0.5
            then
                for _, enemyPosition in ipairs(self.AliveEnemyPositions or {}) do
                    if (enemyPosition - position).Magnitude <= CONFIG.DeadBossMobGuard then
                        return false
                    end
                end
                return true
            end
        end
        return false
    end

    -- The Protector's water-stream floor stops mattering once he is dead.
    local oldStream = HazardTracker.IsInActiveStream
    function HazardTracker:IsInActiveStream(position)
        if self.ProtectorDead then
            local protectorAlive = false
            for _, info in pairs(self.BossSeen or {}) do
                if info.Name == "ancient temple protector" then
                    protectorAlive = true
                    break
                end
            end
            if not protectorAlive then
                return false
            end
            self.ProtectorDead = false
        end
        return oldStream(self, position)
    end

    ---------------------------------------------------------------------------
    -- The game never removes the Protector's attack models (thousands after a
    -- long fight). Once he is dead they are harmless, so remove our local
    -- copies in small batches; this is what made the Sea King fight lag.
    ---------------------------------------------------------------------------
    CONFIG.CleanDeadBossLeftovers = true
    CONFIG.LeftoverCleanBatch = 150

    local PROTECTOR_PREFIXES = { "firstboss", "secondboss" }

    local function isProtectorLeftoverName(name)
        local lower = string.lower(name or "")
        for _, prefix in ipairs(PROTECTOR_PREFIXES) do
            if string.sub(lower, 1, #prefix) == prefix then
                return true
            end
        end
        return false
    end

    function HazardTracker:IsProtectorGone()
        for _, info in pairs(self.BossSeen or {}) do
            if info.Name == "ancient temple protector" then
                return false
            end
        end
        if self.ProtectorDeadSeen then
            return true
        end
        -- Loaded after he died: the Sea King being alive means he is gone.
        for _, info in pairs(self.BossSeen or {}) do
            if info.Name == "sea king" then
                self.ProtectorDeadSeen = true
                return true
            end
        end
        return false
    end

    function HazardTracker:CleanLeftovers(now)
        if not CONFIG.CleanDeadBossLeftovers or self.Cleaning then
            return
        end
        if now - (self.LeftoverCheckAt or 0) < 2 then
            return
        end
        self.LeftoverCheckAt = now
        if not self:IsProtectorGone() then
            return
        end

        local targets = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            if (child:IsA("Model") or child:IsA("Folder"))
                and isProtectorLeftoverName(child.Name)
                and not child:FindFirstChildOfClass("Humanoid")
            then
                table.insert(targets, child)
            end
        end
        if #targets == 0 then
            return
        end

        self.Cleaning = true
        task.spawn(function()
            local removed = 0
            for index, container in ipairs(targets) do
                if self.Destroyed then
                    break
                end
                for _, d in ipairs(container:GetDescendants()) do
                    if self.FullHazards then
                        self.FullHazards[d] = nil
                    end
                end
                pcall(container.Destroy, container)
                removed += 1
                if index % CONFIG.LeftoverCleanBatch == 0 then
                    task.wait()
                end
            end
            self.LeftoversRemoved = (self.LeftoversRemoved or 0) + removed
            self.NearBuiltAt = 0
            self.Cleaning = false
        end)
    end

    local oldSweep = HazardTracker.BroadSweep
    function HazardTracker:BroadSweep()
        local now = os.clock()
        if self.Destroyed then
            return
        end
        self:CleanLeftovers(now)
        return oldSweep(self)
    end

    local oldContainerSkip = HazardTracker.RegisterAttackContainer
    function HazardTracker:RegisterAttackContainer(container)
        if container and isProtectorLeftoverName(container.Name) and self:IsProtectorGone() then
            return
        end
        return oldContainerSkip(self, container)
    end

    ---------------------------------------------------------------------------
    -- Refresh only nearby, live hazards.
    ---------------------------------------------------------------------------
    local oldRegister = HazardTracker.Register
    function HazardTracker:Register(part)
        local full = self.FullHazards
        if full and self.Hazards ~= full then
            self.Hazards = full
        end
        if self.ProtectorDeadSeen then
            local parent = part.Parent
            for _ = 1, 4 do
                if not parent or parent == Workspace then
                    break
                end
                if isProtectorLeftoverName(parent.Name) then
                    return
                end
                parent = parent.Parent
            end
        end
        oldRegister(self, part)
        if self.NearHazards and self.Hazards[part] then
            self.NearHazards[part] = self.Hazards[part]
        end
    end

    local oldRefresh = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local now = os.clock()
        if not force and now - self.LastCacheTime < CONFIG.HazardCacheInterval then
            return
        end
        if self.SnapshotLocked then
            return
        end

        local full = self.FullHazards or self.Hazards
        self.FullHazards = full
        self:UpdateBossDeaths(now)

        if not self.NearHazards or now - (self.NearBuiltAt or 0) > CONFIG.HazardNearRebuild then
            self.NearBuiltAt = now
            local near = {}
            local root = self.CharacterService.Root
            local rootPosition = root and root.Position
            local total, kept = 0, 0
            for part, data in pairs(full) do
                if not part.Parent then
                    full[part] = nil
                else
                    total += 1
                    local keep = data.Ball or data.LaneLaser or self:IsStreamData(data)
                        or not rootPosition
                        or (part.Position - rootPosition).Magnitude
                            <= CONFIG.HazardNearRadius + part.Size.Magnitude * 0.5
                    if keep and not data.Ball and not data.LaneLaser and self:IsDeadBossLeftover(part, data) then
                        keep = false
                    end
                    if self.ProtectorDeadSeen and data.Container and isProtectorLeftoverName(data.Container.Name) then
                        full[part] = nil
                        keep = false
                    end
                    if keep then
                        near[part] = data
                        kept += 1
                    end
                end
            end
            self.NearHazards = near
            self.HazardTotals = { Total = total, Near = kept }
        end

        self.Hazards = self.NearHazards
        local ok, err = pcall(oldRefresh, self, force)
        self.Hazards = full
        if not ok then
            error(err, 0)
        end
    end

    ---------------------------------------------------------------------------
    -- v44.10 Generator Water Lines: the beam is the short opaque flash. Once
    -- it has flashed and faded, the lane is safe to walk through.
    ---------------------------------------------------------------------------
    CONFIG.LaneLaserAfterFlash = 0.5

    function HazardTracker:IsLaneLaserLive(data, now)
        local part = data.Part
        local age = now - (data.BornAt or now)
        if age > CONFIG.LaneLaserLifetime or not part or not part.Parent then
            return false
        end
        if part.Transparency < 0.95 then
            data.LaneFlashed = true
            data.LaneVisibleAt = now
            return true
        end
        if data.LaneFlashed then
            return now - (data.LaneVisibleAt or 0) <= CONFIG.LaneLaserAfterFlash
        end
        return true
    end

    ---------------------------------------------------------------------------
    -- v44.10 Sea King: do not walk to the two green safe circles; go hit him.
    ---------------------------------------------------------------------------
    CONFIG.SeaKingUseSafeCircles = false
    if not CONFIG.SeaKingUseSafeCircles then
        SAFE_ZONE_MULTI_CONTAINER_NAMES.lastbosssafezones = nil
    end

    local oldSafeZone = UIWController.GetActiveSafeZone
    function UIWController:GetActiveSafeZone()
        local part, state, distance = oldSafeZone(self)
        if part and not CONFIG.SeaKingUseSafeCircles then
            local zones = Workspace:FindFirstChild("lastBossSafeZones")
            if zones and part:IsDescendantOf(zones) then
                return nil, nil, nil
            end
        end
        return part, state, distance
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.11"
        return self
    end
end

