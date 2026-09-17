local GeometrySensor = {}
GeometrySensor.__index = GeometrySensor

function GeometrySensor.new(characterService)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true

    return setmetatable({
        CharacterService = characterService,
        Params = params,
        EdgeCache = {},
        EdgeCacheReset = 0,
    }, GeometrySensor)
end

function GeometrySensor:RefreshFilter()
    local ignore = {}

    if self.CharacterService.Character then
        table.insert(ignore, self.CharacterService.Character)
    end

    local esp = Workspace:FindFirstChild("UIW_HitboxESP")
        or Workspace:FindFirstChild("UnderworldHitboxESP")

    if esp then
        table.insert(ignore, esp)
    end

    self.Params.FilterDescendantsInstances = ignore
end

function GeometrySensor:MakeNavigationRayParams(extraIgnore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.RespectCanCollide = true

    local ignore = {}

    if self.CharacterService.Character then
        table.insert(ignore, self.CharacterService.Character)
    end

    local esp1 = Workspace:FindFirstChild("UIW_HitboxESP")
    local esp2 = Workspace:FindFirstChild("UnderworldHitboxESP")
    if esp1 then table.insert(ignore, esp1) end
    if esp2 then table.insert(ignore, esp2) end

    -- IGNORING MOBS AS GEOMETRY FIX
    local dungeon = Workspace:FindFirstChild("dungeon")
    if dungeon then
        for _, room in ipairs(dungeon:GetChildren()) do
            local ef = room:FindFirstChild("enemyFolder")
            if ef then
                table.insert(ignore, ef)
            end
        end
    end

    if extraIgnore then
        for _, item in ipairs(extraIgnore) do
            if item then
                table.insert(ignore, item)
            end
        end
    end

    params.FilterDescendantsInstances = ignore

    return params
end

function GeometrySensor:RaycastSkippingEntries(origin, direction, extraIgnore)
    local ignore = {}

    if extraIgnore then
        for _, instance in ipairs(extraIgnore) do
            if instance then
                table.insert(ignore, instance)
            end
        end
    end

    local castOrigin = origin
    local remaining = direction

    for _ = 1, 12 do
        if remaining.Magnitude <= 0.001 then
            return nil
        end

        local params = self:MakeNavigationRayParams(ignore)
        local result = Workspace:Raycast(castOrigin, remaining, params)

        if not result then
            return nil
        end

        local entry = getEntryAncestor(result.Instance)

        if not entry then
            return result
        end

        table.insert(ignore, entry)

        local travelled = math.max(result.Distance, 0)
        local epsilon = 0.05
        local directionUnit = remaining.Unit

        castOrigin = result.Position + directionUnit * epsilon

        local leftover = math.max(remaining.Magnitude - travelled - epsilon, 0)

        remaining = directionUnit * leftover
    end

    return nil
end

function GeometrySensor:BlockcastSkippingEntries(castCF, size, direction)
    local ignored = {}

    for _ = 1, 8 do
        local params = self:MakeNavigationRayParams(ignored)

        local ok, result = pcall(function()
            return Workspace:Blockcast(castCF, size, direction, params)
        end)

        if not ok then
            return nil, false
        end

        if not result then
            return nil, true
        end

        if not isEntryInstance(result.Instance) then
            return result, true
        end

        table.insert(ignored, getEntryAncestor(result.Instance) or result.Instance)
    end

    return nil, true
end

function GeometrySensor:HasGround(position)
    local result = self:RaycastSkippingEntries(
        position + Vector3.new(0, 3, 0),
        Vector3.new(0, -CONFIG.GroundProbeDepth, 0)
    )

    return result ~= nil
end

function GeometrySensor:GetEdgeCacheKey(position, radius)
    local cell = CONFIG.EdgeCacheCell
    return tostring(math.floor(position.X / cell + 0.5))
        .. ":" .. tostring(math.floor(position.Z / cell + 0.5))
        .. ":" .. tostring(radius)
end

function GeometrySensor:ResetEdgeCacheIfNeeded()
    local now = os.clock()
    if now - self.EdgeCacheReset >= CONFIG.EdgeCacheTTL then
        table.clear(self.EdgeCache)
        self.EdgeCacheReset = now
    end
end

function GeometrySensor:IsWallProtected(center, probe)
    local direction = flatten(probe - center)
    local distance = direction.Magnitude

    if distance <= 0.05 then
        return false
    end

    direction = direction.Unit

    local result = self:RaycastSkippingEntries(
        center + Vector3.new(0, 2.4, 0),
        direction * distance
    )

    return result ~= nil
end

function GeometrySensor:IsGroundPadded(position, radius)
    self:ResetEdgeCacheIfNeeded()

    local key = self:GetEdgeCacheKey(position, radius)
    local cached = self.EdgeCache[key]
    if cached ~= nil then
        return cached
    end

    if not self:HasGround(position) then
        self.EdgeCache[key] = false
        return false
    end

    for i = 0, 7 do
        local angle = math.rad(i * 45)
        local probe = position + Vector3.new(
            math.cos(angle) * radius,
            0,
            math.sin(angle) * radius
        )

        if not self:HasGround(probe) and not self:IsWallProtected(position, probe) then
            self.EdgeCache[key] = false
            return false
        end
    end

    self.EdgeCache[key] = true
    return true
end

function GeometrySensor:GetEdgeClearanceScore(position)
    self:ResetEdgeCacheIfNeeded()

    local radius = CONFIG.EdgeWarningPadding
    local key = "score:" .. self:GetEdgeCacheKey(position, radius)
    local cached = self.EdgeCache[key]
    if cached ~= nil then
        return cached
    end

    local count = 0

    for i = 0, 7 do
        local angle = math.rad(i * 45)
        local probe = position + Vector3.new(
            math.cos(angle) * radius,
            0,
            math.sin(angle) * radius
        )

        if self:HasGround(probe) or self:IsWallProtected(position, probe) then
            count += 1
        end
    end

    self.EdgeCache[key] = count
    return count
end

function GeometrySensor:GetSweepSize()
    local body = self.CharacterService.BodySize

    return Vector3.new(
        math.max(2.5, body.X + CONFIG.BodyPaddingXZ * 2),
        math.clamp(body.Y * 0.46, 2.4, 3.6),
        math.max(1.8, body.Z + CONFIG.BodyPaddingXZ * 2)
    )
end

function GeometrySensor:IsDirectionClear(direction, distance, yaw)
    local character = self.CharacterService

    if not character:IsAlive() then
        return false
    end

    direction = unit(flatten(direction))

    if direction.Magnitude <= 0 then
        return false
    end

    local root = character.Root

    yaw = yaw or character.DesiredYaw or directionToYaw(direction)

    local sweepSize = self:GetSweepSize()

    local center = root.Position + Vector3.new(0, math.max(0.8, sweepSize.Y * 0.28), 0)

    local castCF = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

    local result, ok = self:BlockcastSkippingEntries(castCF, sweepSize, direction * distance)

    if not ok then
        return false
    end

    if result then
        return false, result
    end

    local endpoint = root.Position + direction * distance

    if not self:HasGround(endpoint) then
        return false
    end

    return true
end

function GeometrySensor:IsDirectionClearFrom(origin, direction, distance, yaw)
    local character = self.CharacterService

    if not character:IsAlive() then
        return false
    end

    direction = unit(flatten(direction))

    if direction.Magnitude <= 0 then
        return false
    end

    yaw = yaw or character.DesiredYaw or directionToYaw(direction)

    local sweepSize = self:GetSweepSize()

    local center = origin + Vector3.new(0, math.max(0.8, sweepSize.Y * 0.28), 0)

    local castCF = CFrame.new(center) * CFrame.Angles(0, yaw, 0)

    local result, ok = self:BlockcastSkippingEntries(castCF, sweepSize, direction * distance)

    if not ok then
        return false
    end

    if result then
        return false, result
    end

    local endpoint = origin + direction * distance

    if not self:HasGround(endpoint) then
        return false
    end

    return true
end

function GeometrySensor:GetCollidableBodyOverlaps(position, yaw)
    local character = self.CharacterService
    if not character:IsAlive() then
        return {}
    end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = {character.Character, self.CharacterService.Character}

    local esp1 = Workspace:FindFirstChild("UIW_HitboxESP")
    local esp2 = Workspace:FindFirstChild("UnderworldHitboxESP")
    if esp1 then table.insert(ignoreList, esp1) end
    if esp2 then table.insert(ignoreList, esp2) end

    -- IGNORING MOBS AS GEOMETRY FIX
    local dungeon = Workspace:FindFirstChild("dungeon")
    if dungeon then
        for _, room in ipairs(dungeon:GetChildren()) do
            local ef = room:FindFirstChild("enemyFolder")
            if ef then
                table.insert(ignoreList, ef)
            end
        end
    end

    params.FilterDescendantsInstances = ignoreList
    params.MaxParts = 48

    local sweepSize = self:GetSweepSize()
    local center = position + Vector3.new(0, math.max(1.0, sweepSize.Y * 0.32), 0)
    local boxCF = CFrame.new(center) * CFrame.Angles(0, yaw or character.DesiredYaw or 0, 0)

    local ok, parts = pcall(function()
        return Workspace:GetPartBoundsInBox(
            boxCF,
            Vector3.new(
                math.max(1.6, sweepSize.X - 0.35),
                math.max(1.8, sweepSize.Y - 0.35),
                math.max(1.4, sweepSize.Z - 0.35)
            ),
            params
        )
    end)

    if not ok then
        return {}
    end

    local result = {}

    for _, part in ipairs(parts) do
        if part:IsA("BasePart")
            and part.CanCollide
            and not isEntryInstance(part)
            and not part:IsDescendantOf(character.Character)
        then
            local lp = part.CFrame:PointToObjectSpace(position)
            local half = part.Size * 0.5

            if math.abs(lp.Y) <= half.Y + 1.8 then
                table.insert(result, part)
            end
        end
    end

    return result
end

function GeometrySensor:GetCollidableOverlapCountAt(position, yaw)
    return #self:GetCollidableBodyOverlaps(position, yaw)
end

function GeometrySensor:GetStartingOverlapEscape(preferred, targetYaw)
    local character = self.CharacterService
    if not character:IsAlive() then
        return nil, 0
    end

    local root = character.Root
    local overlaps = self:GetCollidableBodyOverlaps(root.Position, targetYaw)
    if #overlaps == 0 then
        return nil, 0
    end

    local push = Vector3.zero

    for _, part in ipairs(overlaps) do
        local p = part.CFrame:PointToObjectSpace(root.Position)
        local half = part.Size * 0.5
        local px = half.X - math.abs(p.X)
        local pz = half.Z - math.abs(p.Z)
        local localExit

        if px < pz then
            localExit = Vector3.new(p.X >= 0 and 1 or -1, 0, 0)
        else
            localExit = Vector3.new(0, 0, p.Z >= 0 and 1 or -1)
        end

        push += part.CFrame:VectorToWorldSpace(localExit)
    end

    push = unit(flatten(push))
    preferred = unit(flatten(preferred))

    if push.Magnitude <= 0 then
        push = preferred.Magnitude > 0 and -preferred
            or unit(flatten(root.CFrame.LookVector))
    end

    local best = nil
    local bestScore = -math.huge
    local currentCount = #overlaps

    for _, angle in ipairs({0, 20, -20, 40, -40, 65, -65, 90, -90, 120, -120, 150, -150, 180}) do
        local direction = unit(rotateXZ(push, angle))
        local p3 = root.Position + direction * 3
        local p6 = root.Position + direction * 6
        local p9 = root.Position + direction * 9

        if self:IsGroundPadded(p6, CONFIG.EdgeHardPadding) then
            local c3 = self:GetCollidableOverlapCountAt(p3, targetYaw)
            local c6 = self:GetCollidableOverlapCountAt(p6, targetYaw)
            local c9 = self:GetCollidableOverlapCountAt(p9, targetYaw)

            local score =
                (currentCount - c3) * 260
                + (currentCount - c6) * 420
                + (currentCount - c9) * 620
                + self:GetEdgeClearanceScore(p6) * 16

            if preferred.Magnitude > 0 then
                score += direction:Dot(preferred) * 18
            end

            if c9 == 0 then
                score += 900
            end

            if score > bestScore then
                bestScore = score
                best = direction
            end
        end
    end

    return best, currentCount
end

