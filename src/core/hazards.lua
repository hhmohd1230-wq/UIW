local HazardTracker = {}
HazardTracker.__index = HazardTracker

local DRAGON_ATTACK_CONTAINERS = {
    thirdbossxshot = true,
    thirdbosscrossshot = true,
    thirdbossflamebreathe = true,
    thirdbossoneshot = true,
    thirdbossoneshotbeam = true,
}

function HazardTracker.new(characterService, selfTracker)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Include

    return setmetatable({
        CharacterService = characterService,
        SelfTracker = selfTracker,
        Hazards = setmetatable({}, { __mode = "k" }),
        ContainerState = setmetatable({}, { __mode = "k" }),
        ContainerDiscoveryScanAt = setmetatable({}, { __mode = "k" }),
        CachedActive = {},
        CachedParts = {},
        LastCacheTime = 0,
        LastBroadSweep = 0,
        OverlapParams = overlapParams,
        Maid = Maid.new(),
    }, HazardTracker)
end

function HazardTracker:GetContainer(part)
    if part and (isLocalPlayerOwnedInstance(part) or isDetachedLocalPlayerEffect(part)) then
        return nil
    end

    local broad = part and getBroadHazardContainer(part)
    if broad then
        return broad
    end

    local special = part and getSpecialHazardContainer(part)
    if special then
        return special
    end

    local parent = part and part.Parent
    if parent and parent ~= Workspace then
        return parent
    end

    return part
end

function HazardTracker:IsPrecastPart(part)
    if not part or not part:IsA("BasePart") then return false end
    local ownName = string.lower(part.Name)
    if string.find(ownName, "hitbox", 1, true) and not string.find(ownName, "precast", 1, true) then
        return false
    end
    local current = part
    for _ = 1, 3 do
        if not current or current == Workspace then break end
        local name = string.lower(current.Name)
        if string.find(name, "precast", 1, true)
            or string.find(name, "telegraph", 1, true) then return true end
        current = current.Parent
    end
    return false
end

function HazardTracker:IsWarningVisible(part)
    if not part or not part.Parent then return false end
    if part:GetAttribute("UIWHiddenDragonWarning") == true then
        return part.Transparency < 0.98
    end
    if part.Transparency < 0.98 and part.LocalTransparencyModifier < 0.98 then return true end
    for _, visual in ipairs(part:GetDescendants()) do
        if (visual:IsA("Decal") or visual:IsA("Texture")) and visual.Transparency < 0.98 then
            return true
        elseif (visual:IsA("ParticleEmitter") or visual:IsA("Beam") or visual:IsA("Trail"))
            and visual.Enabled then return true
        elseif visual:IsA("SurfaceGui") and visual.Enabled then return true end
    end
    return false
end

function HazardTracker:UpdateWarningBounds(data)
    if data.LaneCorridor or data.GrowWarning then return end
    local part = data.Part
    local size = part.Size
    local original = part:GetAttribute("OriginalSize")
    if typeof(original) ~= "Vector3" then
        local value = part:FindFirstChild("OriginalSize")
        original = value and value:IsA("Vector3Value") and value.Value or nil
    end
    if typeof(original) == "Vector3" and original.X > 0 and original.Y > 0 and original.Z > 0
        and math.max(original.X, original.Y, original.Z) <= 1024 then
        size = Vector3.new(math.max(size.X, original.X), math.max(size.Y, original.Y), math.max(size.Z, original.Z))
    end
    local cf = part.CFrame
    local axes = {cf.RightVector, cf.UpVector, cf.LookVector}
    local dims = {size.X, size.Y, size.Z}
    local vertical = 1
    for i = 2, 3 do
        if math.abs(axes[i].Y) > math.abs(axes[vertical].Y) then vertical = i end
    end
    local worldHeight = math.abs(axes[1].Y) * size.X + math.abs(axes[2].Y) * size.Y
        + math.abs(axes[3].Y) * size.Z
    if worldHeight <= CONFIG.PrecastThinHeight and math.abs(axes[vertical].Y) > 0.9 then
        dims[vertical] += CONFIG.PrecastColumnHeight / math.abs(axes[vertical].Y)
        cf += Vector3.new(0, CONFIG.PrecastColumnHeight * 0.5, 0)
    end
    data.WarningCF = cf
    data.WarningHalf = Vector3.new(dims[1], dims[2], dims[3]) * 0.5
end

function HazardTracker:IsBodyInWarning(position, yaw, data)
    if not data.WarningCF then self:UpdateWarningBounds(data) end
    local cf, half = data.WarningCF, data.WarningHalf
    local bodyCF, bodyHalf = self:GetBodyCF(position, yaw), self:GetBodySize() * 0.5
    local point = cf:PointToObjectSpace(bodyCF.Position)
    local function radius(axis)
        return math.abs(axis:Dot(bodyCF.RightVector)) * bodyHalf.X
            + math.abs(axis:Dot(bodyCF.UpVector)) * bodyHalf.Y
            + math.abs(axis:Dot(bodyCF.LookVector)) * bodyHalf.Z
    end
    local padding = self.TightPadding and CONFIG.TightExitPadding or CONFIG.PrecastSafetyPadding
    return math.abs(point.X) <= half.X + radius(cf.RightVector) + padding
        and math.abs(point.Y) <= half.Y + radius(cf.UpVector) + padding
        and math.abs(point.Z) <= half.Z + radius(cf.LookVector) + padding
end

function HazardTracker:IsPrecastTrajectoryClear(position, direction, yaw, distance)
    self:RefreshCache(false)
    direction = unit(flatten(direction))
    local controller = getgenv().UIW
    local sampleLength = controller and controller.EnchantedDragonPerf and 4.5 or 2
    for _, data in ipairs(self.CachedWarnings or {}) do
        local count = math.max(1, math.ceil(distance / sampleLength))
        for i = 0, count do
            if self:IsBodyInWarning(position + direction * (distance * i / count), yaw, data) then
                return false
            end
        end
    end
    return true
end

function HazardTracker:GetWarningExitDirection(part, position)
    local data = self.Hazards[part]
    if not data or not data.IsPrecast then return nil end
    if not data.WarningCF then self:UpdateWarningBounds(data) end
    local cf, half = data.WarningCF, data.WarningHalf
    local point = cf:PointToObjectSpace(position)
    local axes = {cf.RightVector, cf.UpVector, -cf.LookVector}
    local coordinates = {point.X, point.Y, point.Z}
    local extents = {half.X, half.Y, half.Z}
    local best, distance = nil, math.huge
    for i, axis in ipairs(axes) do
        if math.abs(axis.Y) < 0.5 then
            local exit = extents[i] - math.abs(coordinates[i])
            if exit < distance then
                best = unit(flatten(axis)) * (coordinates[i] >= 0 and 1 or -1)
                distance = exit
            end
        end
    end
    return best
end

function HazardTracker:ScanContainerVisualState(container)
    if not container or not container.Parent then return false end
    local function visible(object)
        if object:IsA("BasePart") then
            if object:GetAttribute("UIWHiddenDragonWarning") == true then
                return object.Transparency < 0.98
            end
            return object.Transparency < 0.98 and object.LocalTransparencyModifier < 0.98
        elseif object:IsA("Decal") or object:IsA("Texture") then
            return object.Transparency < 0.98
        elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
            return object.Enabled
        elseif object:IsA("SurfaceGui") then return object.Enabled end
        return false
    end
    local function armed(object)
        -- A hitbox with a touch trigger is about to deal (or is dealing) damage.
        -- Live-confirmed in Aquatic Temple: pylon shots gain the trigger at
        -- ~0.85 s, right when the hits land, after the warning has faded.
        if not object:IsA("TouchTransmitter") then return false end
        local owner = object.Parent
        return owner ~= nil
            and string.find(string.lower(owner.Name), "hitbox", 1, true) ~= nil
            and not isStaticDungeonGeometry(owner)
    end
    local isArmed = false
    if visible(container) then return true, false end
    for _, object in ipairs(container:GetDescendants()) do
        if visible(object) then return true, isArmed end
        if not isArmed and armed(object) then isArmed = true end
    end
    return false, isArmed
end

function HazardTracker:IsContainerActive(container, now)
    now = now or os.clock()

    if not container or not container.Parent then
        self.ContainerState[container] = nil
        return false
    end

    local state = self.ContainerState[container]
    if not state then
        state = {
            LastScan = -math.huge,
            RawActive = false,
            RawSince = now,
            Active = true,
            FirstSeen = now,
        }
        self.ContainerState[container] = state
    end

    if now - state.LastScan >= CONFIG.HazardVisualScanInterval then
        state.LastScan = now
        local visibleNow, armedNow = self:ScanContainerVisualState(container)
        -- v40: an armed hitbox counts only during the attack's burst window;
        -- the trigger can linger after the damage has already been dealt.
        local raw = visibleNow
            or (armedNow and now - state.FirstSeen <= CONFIG.TouchDangerWindow)
        if raw ~= state.RawActive then
            state.RawActive = raw
            state.RawSince = now
        end
    end

    if state.RawActive then
        state.Active = true
        return true
    end

    if now - state.FirstSeen <= CONFIG.HazardSpawnGrace then
        state.Active = true
        return true
    end

    if state.Active and now - state.RawSince < CONFIG.HazardInactiveGrace then
        return true
    end

    state.Active = false
    return false
end

local function isExactAttackPartName(tracker, part)
    local lower = string.lower(part.Name or "")
    return tracker:IsPrecastPart(part)
        or lower == "hitbox"
        or lower == "hitboxpart"
        or lower == "precast"
        or string.find(lower, "hitbox", 1, true) ~= nil
        or string.find(lower, "precast", 1, true) ~= nil
end

function HazardTracker:IsPartActive(part, now)
    if not part
        or not part.Parent
        or isEntryInstance(part)
        or isNonHazardMechanicInstance(part)
        or isLocalPlayerOwnedInstance(part)
        or isDetachedLocalPlayerEffect(part)
        or self.SelfTracker:IsOwn(part)
    then
        return false
    end

    if isStaticDungeonGeometry(part) and not getBroadHazardContainer(part) then
        if not isExactAttackPartName(self, part) then
            return false
        end
    end

    local data = self.Hazards[part]
    if not data then
        return false
    end

    local container = data.Container or self:GetContainer(part)
    data.Container = container

    if self:IsPrecastPart(part) then return self:IsWarningVisible(part) end
    return self:IsContainerActive(container, now)
end

function HazardTracker:IsHazardPart(part)
    if not part:IsA("BasePart") then
        return false
    end

    if isEntryInstance(part) or isNonHazardMechanicInstance(part) then
        return false
    end

    if isLocalPlayerOwnedInstance(part) or isDetachedLocalPlayerEffect(part) then
        return false
    end

    if self.SelfTracker:IsOwn(part) then
        return false
    end

    local lower = string.lower(part.Name)
    local broadContainer = getBroadHazardContainer(part)
    if broadContainer
        and DRAGON_ATTACK_CONTAINERS[string.lower(broadContainer.Name or "")]
    then
        -- Dragon attack models contain many decorative queryable parts. The
        -- actual warning and damage volumes are consistently named precast
        -- and hitBox; tracking the rest inflated one burst to 92 hazards.
        return lower == "precast" or lower == "hitbox"
            or string.find(lower, "precast", 1, true) ~= nil
            or string.find(lower, "hitbox", 1, true) ~= nil
    end

    if self:IsPrecastPart(part) then return true end

    if self:IsLaneBall(part) then return true end

    if lower == "hitbox"
        or lower == "hitboxpart"
        or lower == "precast"
        or string.find(lower, "hitbox", 1, true)
        or string.find(lower, "precast", 1, true)
    then
        return true
    end

    if broadContainer and (part.CanQuery or part.CanTouch) then
        return true
    end

    if isStaticDungeonGeometry(part) then
        return false
    end

    local hinted = hasHazardNameHint(lower)

    if hinted and (part.CanQuery or part.CanTouch) then
        if part.Transparency < 0.98 then
            return true
        end

        local maxAxis = math.max(part.Size.X, part.Size.Y, part.Size.Z)
        local volume = part.Size.X * part.Size.Y * part.Size.Z

        if maxAxis >= 3 and volume >= 8 then
            return true
        end
    end

    local special = getSpecialHazardContainer(part)

    if special and part.CanQuery then
        local maxPlanar = math.max(part.Size.X, part.Size.Z)
        local footprint = part.Size.X * part.Size.Z

        if part.Transparency >= 0.80 and maxPlanar >= 8 and footprint >= 100 then
            return true
        end
    end

    return false
end

-- v40 lane balls (live-confirmed, Aquatic Temple / Temple Core Generator):
-- a Model with a long thin `precast` (16x1x150) marks a lane; a few seconds
-- later a 17-stud anchored part named "Model" appears in Workspace, waits
-- ~1.5 s, then flies along the lane at ~78 studs/s for ~3 s.
function HazardTracker:IsLaneBall(part)
    return part:IsA("BasePart")
        and part.Parent == Workspace
        and part.Name == "Model"
        and math.min(part.Size.X, part.Size.Y, part.Size.Z) >= CONFIG.LaneBallMinSize
end

function HazardTracker:RegisterLane(model)
    if not model or not model.Parent or model.Parent ~= Workspace or not model:IsA("Model") then
        return
    end

    local precast = model:FindFirstChild("precast", true)
    if not precast or not precast:IsA("BasePart") then
        return
    end

    local size = precast.Size
    if math.max(size.X, size.Z) < 100 or math.min(size.X, size.Z) > 30 then
        return
    end

    self.Lanes = self.Lanes or {}
    self.RegisteredLaneModels = self.RegisteredLaneModels or setmetatable({}, { __mode = "k" })
    if self.RegisteredLaneModels[model] then
        return
    end
    self.RegisteredLaneModels[model] = true

    local axis = size.Z >= size.X and precast.CFrame.LookVector or precast.CFrame.RightVector

    table.insert(self.Lanes, {
        Center = precast.Position,
        Axis = unit(flatten(axis)),
        HalfLength = math.max(size.X, size.Z) * 0.5,
        HalfWidth = math.min(size.X, size.Z) * 0.5,
        Born = os.clock(),
    })

    while #self.Lanes > 40 do
        table.remove(self.Lanes, 1)
    end
end

function HazardTracker:FindLaneForBall(position)
    local best, bestScore = nil, math.huge
    local now = os.clock()

    for index = #(self.Lanes or {}), 1, -1 do
        local lane = self.Lanes[index]
        if now - lane.Born > CONFIG.LaneMemory then
            table.remove(self.Lanes, index)
        else
            local rel = flatten(position - lane.Center)
            local along = rel:Dot(lane.Axis)
            local side = (rel - lane.Axis * along).Magnitude
            if side <= lane.HalfWidth + 14 and math.abs(along) <= lane.HalfLength + 40 then
                -- Balls appear ~6-8 s after their lane warning (live-measured).
                local age = now - lane.Born
                local agePenalty = (age < CONFIG.LaneBallDelayMin or age > CONFIG.LaneBallDelayMax) and 25 or 0
                local score = side * 2 + math.max(0, math.abs(along) - lane.HalfLength) + agePenalty
                if score < bestScore then
                    best, bestScore = lane, score
                end
            end
        end
    end

    return best
end

function HazardTracker:SetupLaneCorridor(data)
    local part = data.Part
    local lane = self:FindLaneForBall(part.Position)
    if not lane then
        return
    end

    local origin = Vector3.new(part.Position.X, part.Position.Y, part.Position.Z)
    data.LaneCorridor = true
    data.IsPrecast = true
    data.WarningCF = CFrame.lookAt(origin, origin + lane.Axis)
    data.WarningHalf = Vector3.new(
        math.max(lane.HalfWidth, part.Size.X * 0.5) + CONFIG.LaneCorridorExtraWidth,
        math.max(part.Size.Y * 0.5, 10),
        CONFIG.LaneCorridorHalfLength
    )
end

-- v40 damage learning: remember how hard each attack type hits, so cheap
-- attacks can be tanked while attacking and heavy ones are always dodged.
function HazardTracker:GetDamageKey(data)
    local container = data.Container
    local name = container and container.Name or (data.Part and data.Part.Name) or "?"
    if data.Ball then
        name ..= ":ball"
    end
    return name
end

function HazardTracker:LearnDamage(fraction, position)
    self.DamageProfile = self.DamageProfile or {}
    local keys = {}

    for part, data in pairs(self.Hazards) do
        if part and part.Parent and not data.LaneCorridor then
            local lp = part.CFrame:PointToObjectSpace(position)
            local half = part.Size * 0.5 + Vector3.new(3, 3, 3)
            if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
                keys[self:GetDamageKey(data)] = true
            end
        end
    end

    local learned = {}
    for key in pairs(keys) do
        local entry = self.DamageProfile[key] or { Hits = 0, Fraction = 0 }
        entry.Hits += 1
        -- Conservative: remember the worst recent hit, decay slowly.
        entry.Fraction = math.max(fraction, entry.Fraction * 0.8 + fraction * 0.2)
        self.DamageProfile[key] = entry
        table.insert(learned, key)
    end

    if #learned > 0 then
        self.DamageProfileDirty = true
    end
    return learned
end

function HazardTracker:IsTankable(data)
    if not CONFIG.TankEnabled or data.LaneCorridor or data.Ball or data.SlamBand then
        return false
    end

    local humanoid = self.CharacterService.Humanoid
    if not humanoid or humanoid.MaxHealth <= 0 then
        return false
    end

    local entry = self.DamageProfile and self.DamageProfile[self:GetDamageKey(data)]
    if not entry or entry.Hits < CONFIG.TankMinSamples then
        return false
    end

    local health = humanoid.Health / humanoid.MaxHealth
    return entry.Fraction <= CONFIG.TankMaxHitFraction
        and health - entry.Fraction * CONFIG.TankHitsAssumed >= CONFIG.TankHealthFloor
end

function HazardTracker:IsLaneWarningPart(part)
    if not part or string.lower(part.Name) ~= "precast" then
        return false
    end
    local model = part.Parent
    if not model or not model:IsA("Model") or model.Parent ~= Workspace then
        return false
    end
    if model:FindFirstChild("hitBox", true) then
        return false
    end
    local size = part.Size
    return math.max(size.X, size.Z) >= 100 and math.min(size.X, size.Z) <= 30
end

-- Water Orbs fly toward where the player was when they spawned.
function HazardTracker:SetupOrbCorridor(data)
    local root = self.CharacterService.Root
    local part = data.Part
    if not root or not part then
        return false
    end
    local direction = unit(flatten(root.Position - part.Position))
    if direction.Magnitude <= 0 then
        return false
    end
    local length = CONFIG.OrbCorridorLength * 0.5
    local center = part.Position + direction * (length - 10)
    data.LaneCorridor = true
    data.OrbAimed = true
    data.WarningCF = CFrame.lookAt(center, center + direction)
    data.WarningHalf = Vector3.new(
        part.Size.X * 0.5 + CONFIG.LaneCorridorExtraWidth,
        math.max(part.Size.Y * 0.5, 10),
        length
    )
    return true
end

-- v42 Water Stream (Ancient Temple Protector): the floor outside the arena
-- becomes a damaging substance. There is no sideways exit; the only safe place
-- is inside the boss arena.
function HazardTracker:IsStreamData(data)
    local container = data and data.Container
    return container ~= nil and string.lower(container.Name or "") == "secondbossdamageparts"
end

function HazardTracker:IsInActiveStream(position)
    for _, data in ipairs(self.CachedActive) do
        if self:IsStreamData(data) then
            local part = data.Part
            if part and part.Parent then
                local lp = part.CFrame:PointToObjectSpace(position)
                local half = part.Size * 0.5
                if math.abs(lp.X) <= half.X + 1
                    and math.abs(lp.Z) <= half.Z + 1
                    and lp.Y >= -half.Y - 2
                    and lp.Y <= half.Y + 9
                then
                    return true
                end
            end
        end
    end
    return false
end

function HazardTracker:RegisterAttackContainer(container)
    if not container
        or not container.Parent
        or isLocalPlayerOwnedInstance(container)
        or isDetachedLocalPlayerEffect(container)
        or isNonHazardMechanicInstance(container)
    then
        return
    end

    -- Attack models are often assembled one descendant at a time. Every part
    -- already receives its own DescendantAdded registration, so repeatedly
    -- rescanning the whole growing model creates quadratic work during large
    -- dragon volleys. Keep occasional rescans to catch unusual nested setups.
    local now = os.clock()
    local lastScan = self.ContainerDiscoveryScanAt[container] or -math.huge
    if now - lastScan < 0.075 then return end
    self.ContainerDiscoveryScanAt[container] = now

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("BasePart") and self:IsHazardPart(descendant) then
            self:Register(descendant)
        end
    end

    if container:IsA("BasePart") and self:IsHazardPart(container) then
        self:Register(container)
    end
end

function HazardTracker:BroadSweep()
    local now = os.clock()

    if now - self.LastBroadSweep < CONFIG.BroadHazardSweepInterval then
        return
    end

    self.LastBroadSweep = now

    local root = self.CharacterService.Root
    local rootPosition = root and root.Position

    for _, child in ipairs(Workspace:GetChildren()) do
        if isLocalPlayerOwnedInstance(child)
            or isDetachedLocalPlayerEffect(child)
            or isNonHazardMechanicInstance(child)
        then
            continue
        end

        if child:IsA("BasePart") then
            if (not rootPosition
                or (child.Position - rootPosition).Magnitude <= CONFIG.BroadHazardSweepRadius)
                and self:IsHazardPart(child)
            then
                self:Register(child)
            end
        elseif (child:IsA("Model") or child:IsA("Folder"))
            and (isBossAttackContainerName(child.Name) or hasHazardNameHint(child.Name))
        then
            self:RegisterAttackContainer(child)
        end
    end
end

function HazardTracker:RegisterSpecialContainer(container)
    if not container
        or not container.Parent
        or isLocalPlayerOwnedInstance(container)
        or isDetachedLocalPlayerEffect(container)
        or isNonHazardMechanicInstance(container)
    then
        return
    end

    if not SPECIAL_HAZARD_CONTAINERS[string.lower(container.Name)] then
        return
    end

    for _, descendant in ipairs(container:GetDescendants()) do
        if descendant:IsA("BasePart") and self:IsHazardPart(descendant) then
            self:Register(descendant)
        end
    end
end

function HazardTracker:Register(part)
    if self.Hazards[part] then
        return
    end

    if not self:IsHazardPart(part) then
        return
    end

    local now = os.clock()
    local container = self:GetContainer(part)

    local detectedName = string.lower((container and container.Name) or part.Name or "")
    if detectedName == "magebossstrraightshot"
        or detectedName == "magebossstraightshot"
        or detectedName == "magehorizontalbeam"
        or detectedName == "mageprojectileball"
        or detectedName == "magebossminionspawneffect"
    then
        self.LastDetectedAttack = (container and container.Name) or part.Name
        self.LastDetectedAttackTime = now
    end

    self.Hazards[part] = {
        Part = part,
        Name = part.Parent and part.Parent.Name or part.Name,
        Container = container,
        IsPrecast = self:IsPrecastPart(part),
        BornAt = now,
        LastMotionPosition = part.Position,
        LastMotionTime = now,
        EstimatedVelocity = Vector3.zero,
        MotionSamples = 0,
    }

    if self:IsLaneBall(part) then
        local data = self.Hazards[part]
        data.Ball = true
        data.Container = part
        if not self:SetupOrbCorridor(data) then
            self:SetupLaneCorridor(data)
        end
    end

    if self:IsLaneWarningPart(part) then
        self.Hazards[part].LaneLaser = true
    end

    if container and not self.ContainerState[container] then
        self.ContainerState[container] = {
            LastScan = -math.huge,
            RawActive = false,
            RawSince = now,
            Active = true,
            FirstSeen = now,
        }
    end

    self.LastCacheTime = 0
end

function HazardTracker:Unregister(part)
    if self.Hazards[part] then
        self.Hazards[part] = nil
        self.LastCacheTime = 0
    end
end

function HazardTracker:Start()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("BasePart")
            and not isNonHazardMechanicInstance(descendant)
            and not isLocalPlayerOwnedInstance(descendant)
            and not isDetachedLocalPlayerEffect(descendant)
        then
            self:Register(descendant)
        end
    end

    self:BroadSweep()

    self.Maid:Give(Workspace.DescendantAdded:Connect(function(instance)
        if instance:IsA("BasePart") then
            if isNonHazardMechanicInstance(instance)
                or isLocalPlayerOwnedInstance(instance)
                or isDetachedLocalPlayerEffect(instance)
            then
                return
            end

            local broad = getBroadHazardContainer(instance)
            local special = getSpecialHazardContainer(instance)
            local candidate = broad ~= nil or special ~= nil or self:IsHazardPart(instance)

            -- Streamed room geometry accounts for thousands of additions in
            -- one frame. It needs no deferred work when it is not an attack.
            if not candidate then return end

            self:Register(instance)
            if broad then self:RegisterAttackContainer(broad) end
            if special then self:RegisterSpecialContainer(special) end

            -- One later check catches attacks that resize or reveal a named
            -- part after parenting it. Older builds queued three tasks for
            -- every BasePart in the streamed dungeon map.
            task.delay(0.10, function()
                if not instance.Parent then return end
                self:Register(instance)
                local laterBroad = getBroadHazardContainer(instance)
                if laterBroad then self:RegisterAttackContainer(laterBroad) end
                local laterSpecial = getSpecialHazardContainer(instance)
                if laterSpecial then self:RegisterSpecialContainer(laterSpecial) end
            end)
        elseif instance:IsA("Model") and instance.Parent == Workspace
            and not (isBossAttackContainerName(instance.Name) or hasHazardNameHint(instance.Name))
        then
            for _, delayTime in ipairs({0.03, 0.12}) do
                task.delay(delayTime, function()
                    if instance.Parent then self:RegisterLane(instance) end
                end)
            end
        elseif instance:IsA("Model") or instance:IsA("Folder") then
            if isBossAttackContainerName(instance.Name) or hasHazardNameHint(instance.Name) then
                task.defer(function()
                    if instance.Parent then
                        self:RegisterAttackContainer(instance)
                    end
                end)
                for _, delayTime in ipairs({0.03, 0.10, 0.25}) do
                    task.delay(delayTime, function()
                        if instance.Parent then
                            self:RegisterAttackContainer(instance)
                        end
                    end)
                end
            end
        end
    end))

    self.Maid:Give(Workspace.DescendantRemoving:Connect(function(instance)
        self:Unregister(instance)
    end))

    self.Maid:Give(RunService.Heartbeat:Connect(function()
        self:BroadSweep()
    end))
end

function HazardTracker:IsPredictiveProjectile(data)
    if not data or not data.Part or not data.Part.Parent then
        return false
    end

    if data.Ball then
        return true
    end

    -- Anything that is actually moving is predicted too.
    if (data.MotionSamples or 0) >= 2
        and data.EstimatedVelocity
        and data.EstimatedVelocity.Magnitude >= CONFIG.ProjectileVelocityMin * 2
    then
        return true
    end

    local partName = string.lower(data.Part.Name or "")

    if partName == "thirdbossorbshot"
        or partName == "battlemageorb"
        or partName == "spiritorb"
        or partName == "mageprojectileball"
    then
        return true
    end

    local container = data.Container
        or getBroadHazardContainer(data.Part)
        or getSpecialHazardContainer(data.Part)

    local containerName = container and string.lower(container.Name or "") or ""

    local specialContainer = getSpecialHazardContainer(data.Part)
    local specialContainerName = specialContainer and string.lower(specialContainer.Name or "") or ""

    return containerName == "thirdbosscrescent"
        or containerName == "thirdbossfirewall"
        or containerName == "thirdbossflamewallhitbox"
        or containerName == "battlemageorb"
        or containerName == "spiritorb"
        or containerName == "golemrockthrow"
        or containerName == "golemrockthrowsmall"
        or containerName == "enchantedfirstbossfolloworb"
        or containerName == "mageprojectileball"
        or specialContainerName == "mageprojectileball"
end

function HazardTracker:UpdateMotionSample(data, now)
    local part = data and data.Part

    if not part or not part.Parent then
        return
    end

    local position = part.Position
    local lastPosition = data.LastMotionPosition or position
    local lastTime = data.LastMotionTime or now
    local dt = now - lastTime

    if dt >= 0.018 then
        local rawVelocity = (position - lastPosition) / dt

        if rawVelocity.Magnitude >= CONFIG.ProjectileVelocityMin then
            if (data.MotionSamples or 0) > 0 and data.EstimatedVelocity then
                data.EstimatedVelocity = data.EstimatedVelocity:Lerp(rawVelocity, CONFIG.ProjectileVelocitySmoothing)
            else
                data.EstimatedVelocity = rawVelocity
            end

            data.MotionSamples = (data.MotionSamples or 0) + 1
        end

        data.LastMotionPosition = position
        data.LastMotionTime = now
    end
end

function HazardTracker:GetProjectileVelocity(data)
    if not data or not data.Part or not data.Part.Parent then
        return Vector3.zero
    end

    local estimated = data.EstimatedVelocity or Vector3.zero

    if estimated.Magnitude >= CONFIG.ProjectileVelocityMin then
        return estimated
    end

    local assembly = data.Part.AssemblyLinearVelocity

    if assembly.Magnitude >= CONFIG.ProjectileVelocityMin then
        return assembly
    end

    return Vector3.zero
end

function HazardTracker:IsProjectedBodyInsidePart(rootPosition, yaw, part, projectedPartCF)
    local bodyCF = self:GetBodyCF(rootPosition, yaw)
    local localPoint = projectedPartCF:PointToObjectSpace(bodyCF.Position)
    local body = self:GetBodySize()
    local half = part.Size * 0.5

    half += body * 0.5

    local paddingXZ = CONFIG.ProjectileExtraPaddingXZ
    local paddingY = CONFIG.ProjectileExtraPaddingY

    local mageProjectileContainer = getSpecialHazardContainer(part)
    if mageProjectileContainer
        and string.lower(mageProjectileContainer.Name or "") == "mageprojectileball"
    then
        paddingXZ += 3.5
        paddingY += 1.0
    end

    half += Vector3.new(paddingXZ, paddingY, paddingXZ)

    return math.abs(localPoint.X) <= half.X
        and math.abs(localPoint.Y) <= half.Y
        and math.abs(localPoint.Z) <= half.Z
end

function HazardTracker:GetIncomingProjectileThreat(startPosition, playerDirection, yaw, moveDistance)
    self:RefreshCache(false)

    playerDirection = unit(flatten(playerDirection or Vector3.zero))
    moveDistance = math.max(moveDistance or 0, 0)

    local humanoid = self.CharacterService.Humanoid
    local playerSpeed = humanoid and humanoid.WalkSpeed or 20

    local bestData = nil
    local bestTime = math.huge

    for _, data in ipairs(self.CachedActive) do
        if self:IsPredictiveProjectile(data) then
            local part = data.Part
            local velocity = self:GetProjectileVelocity(data)

            if velocity.Magnitude >= CONFIG.ProjectileVelocityMin then
                local rotation = part.CFrame.Rotation
                local time = 0

                while time <= CONFIG.ProjectilePredictionHorizon do
                    local moveAmount = math.min(moveDistance, playerSpeed * time)
                    local playerPosition = startPosition + playerDirection * moveAmount
                    local projectilePosition = part.Position + velocity * time
                    local projectedCF = CFrame.new(projectilePosition) * rotation

                    if self:IsProjectedBodyInsidePart(playerPosition, yaw, part, projectedCF) then
                        if time < bestTime then
                            bestData = data
                            bestTime = time
                        end
                        break
                    end

                    time += CONFIG.ProjectilePredictionStep
                end
            end
        end
    end

    return bestData, bestTime
end

function HazardTracker:IsPredictiveTrajectoryClear(startPosition, playerDirection, yaw, moveDistance)
    local data = self:GetIncomingProjectileThreat(startPosition, playerDirection, yaw, moveDistance)
    return data == nil
end

function HazardTracker:RefreshCache(force)
    local now = os.clock()

    if not force and now - self.LastCacheTime < CONFIG.HazardCacheInterval then
        return
    end

    self.LastCacheTime = now

    table.clear(self.CachedActive)
    table.clear(self.CachedParts)

    local root = self.CharacterService.Root
    local rootPosition = root and root.Position

    self.CachedWarnings = self.CachedWarnings or {}
    table.clear(self.CachedWarnings)

    if self.Dungeon then
        self.LivingEnemyPositions = self.LivingEnemyPositions or {}
        table.clear(self.LivingEnemyPositions)
        for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
            if enemy.Root and enemy.Root.Parent then
                table.insert(self.LivingEnemyPositions, enemy.Root.Position)
            end
        end
        if #self.LivingEnemyPositions == 0 then
            -- Between waves the dungeon may not have spawned the next pack yet;
            -- only trust "no enemies" once the dungeon model is present.
            if not self.Dungeon.Dungeon then
                self.LivingEnemyPositions = nil
            end
        end
    end
    local containerActive = {}

    for part, data in pairs(self.Hazards) do
        if part
            and part.Parent
            and not isEntryInstance(part)
            and not isNonHazardMechanicInstance(part)
            and not isLocalPlayerOwnedInstance(part)
            and not isDetachedLocalPlayerEffect(part)
            and not self.SelfTracker:IsOwn(part)
        then
            if isStaticDungeonGeometry(part) and not getBroadHazardContainer(part) then
                if not isExactAttackPartName(self, part) then
                    self.Hazards[part] = nil
                    continue
                end
            end

            if not data.IsPrecast or data.Ball then
                self:UpdateMotionSample(data, now)
            end

            local container = data.Container or self:GetContainer(part)
            data.Container = container

            if data.Ball then
                local velocity = flatten(data.EstimatedVelocity or Vector3.zero)
                if velocity.Magnitude >= CONFIG.LaneBallMovingSpeed then
                    -- Moving: the corridor is exactly ahead of the ball.
                    local direction = velocity.Unit
                    local length = CONFIG.LaneCorridorHalfLength
                    local center = part.Position + direction * (length - 12)
                    data.LaneCorridor = true
                    data.WarningCF = CFrame.lookAt(center, center + direction)
                    data.WarningHalf = Vector3.new(
                        part.Size.X * 0.5 + CONFIG.LaneCorridorExtraWidth,
                        math.max(part.Size.Y * 0.5, 10),
                        length
                    )
                elseif not data.LaneCorridor then
                    if not self:SetupOrbCorridor(data) then
                        self:SetupLaneCorridor(data)
                    end
                end
            end

            data.IsPrecast = data.LaneCorridor == true or self:IsPrecastPart(part)
            local active
            if data.Ball then
                active = true
            elseif data.IsPrecast then
                active = self:IsWarningVisible(part)
                    or (data.LaneLaser and self:IsLaneLaserLive(data, now))
                self:UpdateWarningBounds(data)
            else
                active = containerActive[container]
            end
            if not data.IsPrecast and active == nil then
                active = self:IsContainerActive(container, now)
                containerActive[container] = active
            end

            -- v43b: Protector's Slam band (hitBox ~X x 150 x 12). It grows along
            -- its long axis until it leaves the arena, so avoid its whole line
            -- from the moment it appears.
            if not data.IsPrecast and part.Parent and data.SlamBand == nil then
                local s = part.Size
                data.SlamBand = s.Y >= 120
                    and math.min(s.X, s.Z) <= 16
                    and math.max(s.X, s.Z) >= 20
                    and math.max(s.X, s.Z) <= 200
                    and part.Parent ~= Workspace
                    and part.Parent:IsA("Model")
                    and part.Parent.Name == "Model"
                    and part.Parent:FindFirstChild("precast") ~= nil
            end
            if data.SlamBand and part.Parent then
                local s = part.Size
                local longIsX = s.X >= s.Z
                local previous = data.SlamLastSize
                local dt = now - (data.SlamLastTime or now)
                if previous and math.max(s.X - previous.X, s.Z - previous.Z) > 0.1 then
                    data.SlamMovingUntil = now + 0.25
                    if dt > 0.01 then
                        data.SlamGrowth = Vector3.new(math.max(0,s.X-previous.X)/dt,0,math.max(0,s.Z-previous.Z)/dt)
                    end
                end
                data.SlamLastSize = s
                data.SlamLastTime = now
                -- Hidden, disarmed leftovers persist in this dungeon. Their
                -- existence alone is not evidence of an active attack.
                active = active or part:FindFirstChildOfClass("TouchTransmitter") ~= nil
                    or now < (data.SlamMovingUntil or 0)
                data.GrowWarning = active == true
                data.WarningCF = part.CFrame
                data.WarningHalf = Vector3.new(
                    (s.X + (now < (data.SlamMovingUntil or 0) and (data.SlamGrowth or Vector3.zero).X or 0) * CONFIG.GrowthLookahead) * 0.5,
                    s.Y * 0.5,
                    (s.Z + (now < (data.SlamMovingUntil or 0) and (data.SlamGrowth or Vector3.zero).Z or 0) * CONFIG.GrowthLookahead) * 0.5
                )
            end

            -- v43: attacks that keep growing (Protector's Slam) are live for
            -- their whole life, with their future size predicted ahead.
            if not data.IsPrecast and not data.SlamBand and part.Parent then
                local size = part.Size
                local lastSize = data.LastSize or size
                local dt = now - (data.LastSizeTime or now)
                if dt > 0.02 then
                    local delta = size - lastSize
                    if math.max(delta.X, delta.Z) > 0.3 then
                        data.Growing = true
                        data.GrowUntil = now + CONFIG.GrowthHoldTime
                        data.GrowthRate = Vector3.new(
                            math.max(delta.X, 0) / dt,
                            0,
                            math.max(delta.Z, 0) / dt
                        )
                    end
                    data.LastSize = size
                    data.LastSizeTime = now
                elseif not data.LastSize then
                    data.LastSize = size
                    data.LastSizeTime = now
                end
                if data.Growing and now <= (data.GrowUntil or 0) then
                    active = true
                    local rate = data.GrowthRate or Vector3.zero
                    local half = (size + rate * CONFIG.GrowthLookahead) * 0.5
                    -- Predict measured growth only; known SlamBand keeps its dedicated rule.
                    data.WarningCF = part.CFrame
                    data.WarningHalf = half
                    data.GrowWarning = true
                elseif data.GrowWarning then
                    data.Growing, data.GrowWarning = false, false
                    data.GrowthRate, data.WarningCF, data.WarningHalf = nil, nil, nil
                end
            end

            -- v43: leftovers from dead enemies never damage; ignore hazards with
            -- no living enemy anywhere near them (environmental ones excepted).
            if active
                and CONFIG.IgnoreOrphanHazards
                and self.LivingEnemyPositions
                and not self:IsStreamData(data)
                and not data.LaneLaser
                and not data.Ball
                and not data.SlamBand
            then
                local hasSource = false
                local radius = CONFIG.OrphanHazardRadius
                for _, position in ipairs(self.LivingEnemyPositions) do
                    if flatten(position - part.Position).Magnitude <= radius + part.Size.Magnitude * 0.5 then
                        hasSource = true
                        break
                    end
                end
                if not hasSource then
                    active = false
                end
            end

            if active and self:IsTankable(data) then
                active = false
                self.TankedCount = (self.TankedCount or 0) + 1
            end

            if active
                and (not rootPosition
                    or (part.Position - rootPosition).Magnitude
                        < 180 + (data.WarningHalf and data.WarningHalf.Magnitude or part.Size.Magnitude * 0.5))
            then
                if data.IsPrecast or data.GrowWarning then table.insert(self.CachedWarnings, data) end
                table.insert(self.CachedActive, data)
                table.insert(self.CachedParts, part)
            end
        else
            self.Hazards[part] = nil
        end
    end

    -- Cross/X Shot keeps an overlapping precast and hitBox for each beam.
    -- Their X/Z footprints are identical, so one representative per attack
    -- container preserves the dodge shape while halving every solver query.
    local dragonChosen = {}
    local filteredActive = {}
    for _, data in ipairs(self.CachedActive) do
        local container = data.Container
        local dragon = container
            and DRAGON_ATTACK_CONTAINERS[string.lower(container.Name or "")]
        if dragon then
            local previous = dragonChosen[container]
            if not previous or (data.IsPrecast and not previous.IsPrecast) then
                dragonChosen[container] = data
            end
        else
            table.insert(filteredActive, data)
        end
    end
    for _, data in pairs(dragonChosen) do table.insert(filteredActive, data) end
    if #filteredActive ~= #self.CachedActive then
        table.clear(self.CachedActive)
        table.clear(self.CachedParts)
        for _, data in ipairs(filteredActive) do
            table.insert(self.CachedActive, data)
            table.insert(self.CachedParts, data.Part)
        end
    end

    self.OverlapParams.FilterDescendantsInstances = self.CachedParts
end

function HazardTracker:GetActive()
    self:RefreshCache(false)
    return self.CachedActive
end

function HazardTracker:GetBodySize()
    local body = self.CharacterService.BodySize
    local padXZ = self.TightPadding and CONFIG.TightExitPadding or CONFIG.BodyPaddingXZ

    return Vector3.new(
        body.X + padXZ * 2,
        body.Y + CONFIG.BodyPaddingY * 2,
        body.Z + padXZ * 2
    )
end

function HazardTracker:GetBodyCF(position, yaw)
    return CFrame.new(position)
        * CFrame.Angles(0, yaw, 0)
        * CFrame.new(self.CharacterService.BodyOffset)
end

function HazardTracker:GetBodyOverlaps(position, yaw)
    self:RefreshCache(false)
    local parts, seen = {}, {}
    if #self.CachedParts > 0 then
        local ok, hits = pcall(function()
            return Workspace:GetPartBoundsInBox(self:GetBodyCF(position, yaw), self:GetBodySize(), self.OverlapParams)
        end)
        if ok then
            for _, part in ipairs(hits) do parts[#parts + 1] = part; seen[part] = true end
        end
    end
    for _, data in ipairs(self.CachedWarnings or {}) do
        if not seen[data.Part] and self:IsBodyInWarning(position, yaw, data) then
            parts[#parts + 1] = data.Part
            seen[data.Part] = true
        end
    end
    return parts
end

function HazardTracker:IsFullBodyClear(position, yaw)
    return #self:GetBodyOverlaps(position, yaw) == 0
end

function HazardTracker:IsTrajectoryClear(startPosition, direction, yaw, distance)
    direction = unit(flatten(direction))

    if direction.Magnitude <= 0 then
        return false
    end

    distance = math.max(distance or 0, 0)

    local controller = getgenv().UIW
    local step = controller and controller.EnchantedDragonPerf and 4.5 or 2.25
    local sample = 0

    while sample < distance do
        local p = startPosition + direction * sample
        if not self:IsFullBodyClear(p, yaw) then
            return false
        end
        sample += step
    end

    return self:IsFullBodyClear(startPosition + direction * distance, yaw)
end

function HazardTracker:GetPointThreatFromActive(position, active)
    local score = 0

    for _, hazard in ipairs(active) do
        local part = hazard.Part

        if part and part.Parent then
            local localPoint = part.CFrame:PointToObjectSpace(position)
            local half = part.Size * 0.5

            half += Vector3.new(CONFIG.HazardPaddingXZ, CONFIG.HazardPaddingY, CONFIG.HazardPaddingXZ)

            local dx = math.max(math.abs(localPoint.X) - half.X, 0)
            local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
            local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)

            local distance = Vector3.new(dx, dy, dz).Magnitude

            if distance <= 0 then
                score += 100000
            elseif distance < 5 then
                score += (5 - distance) * 100
            elseif distance < 12 then
                score += (12 - distance) * 14
            elseif distance < 24 then
                score += (24 - distance) * 1.4
            end
        end
    end

    return score
end

function HazardTracker:GetPointThreat(position)
    return self:GetPointThreatFromActive(position, self:GetActive())
end

function HazardTracker:GetAuraThreat(position, radius)
    local nearest = nil
    local nearestDistance = radius or CONFIG.AuraRadius

    for _, data in ipairs(self:GetActive()) do
        local part = data.Part
        if part and part.Parent then
            local localPoint = part.CFrame:PointToObjectSpace(position)
            local half = part.Size * 0.5
            local dx = math.max(math.abs(localPoint.X) - half.X, 0)
            local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
            local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
            local distance = Vector3.new(dx, dy, dz).Magnitude

            if distance <= nearestDistance then
                local predictive = self:IsPredictiveProjectile(data)
                local velocity = predictive and self:GetProjectileVelocity(data) or Vector3.zero
                local approaching = velocity.Magnitude < CONFIG.ProjectileVelocityMin
                    or velocity.Unit:Dot(unit(position - part.Position)) > 0.12

                if approaching then
                    nearest = data
                    nearestDistance = distance
                end
            end
        end
    end

    return nearest, nearestDistance
end

function HazardTracker:GetTrajectoryThreat(startPosition, direction, distance)
    direction = unit(flatten(direction))

    if direction.Magnitude <= 0 then
        return 0
    end

    local active = self:GetActive()
    if #active == 0 then
        return 0
    end

    local total = 0
    local sample = math.min(2.5, distance)

    while sample <= distance do
        total += self:GetPointThreatFromActive(startPosition + direction * sample, active)
        sample += 2.5
    end

    return total
end

function HazardTracker:GetCurrentOverlaps(yaw)
    local root = self.CharacterService.Root

    if not root then
        return {}
    end

    return self:GetBodyOverlaps(root.Position, yaw)
end

function HazardTracker:GetOverlapCountAt(position, yaw)
    return #self:GetBodyOverlaps(position, yaw)
end

function HazardTracker:Destroy()
    self.Maid:Clean()
end
