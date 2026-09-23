local RoutePlanner = {}
RoutePlanner.__index = RoutePlanner

function RoutePlanner.new(characterService, geometry, hazards, dungeon)
    return setmetatable({
        CharacterService = characterService,
        Geometry = geometry,
        Hazards = hazards,
        Dungeon = dungeon,
        Waypoints = {},
        WaypointIndex = 1,
        CurrentGoal = nil,
        PendingGoal = nil,
        ActivePath = nil,
        BlockedConnection = nil,
        Computing = false,
        NeedsRepath = false,
        RequestSerial = 0,
        LastCompute = 0,
        LastRequestAt = 0,
        CurrentWaypointPlaneNormal = Vector3.zero,
        CurrentWaypointPlaneDistance = 0,
        LastJumpWaypoint = 0,
        LastJumpAt = 0,
        CachedSafeDirection = Vector3.zero,
        FallbackRoute = false,
        LastPathStatus = "None",
        LastNoPathAt = 0,
        LastNoPathGoal = nil,
        ConsecutiveNoPath = 0,
        LastHeavyFallbackAt = 0,
        Use3DGoalDistance = false,
        FrontierCacheGoal = nil,
        FrontierCacheResult = nil,
        FrontierCacheAt = 0,
        FrontierProbeCursor = 1,
        CreatedEntryModifiers = setmetatable({}, { __mode = "k" }),
        Maid = Maid.new(),
    }, RoutePlanner)
end

function RoutePlanner:DisconnectBlocked()
    if self.BlockedConnection then
        pcall(function()
            self.BlockedConnection:Disconnect()
        end)
        self.BlockedConnection = nil
    end
end

function RoutePlanner:ClearPath()
    self:DisconnectBlocked()

    if self.ActivePath then
        safeDestroy(self.ActivePath)
    end

    self.ActivePath = nil
    table.clear(self.Waypoints)
    self.WaypointIndex = 1
    self.CurrentWaypointPlaneNormal = Vector3.zero
    self.CurrentWaypointPlaneDistance = 0
    self.CachedSafeDirection = Vector3.zero
    self.FallbackRoute = false
    self.LastJumpWaypoint = 0
end

function RoutePlanner:Reset()
    self.RequestSerial += 1
    self.Computing = false
    self.NeedsRepath = false
    self.CurrentGoal = nil
    self.PendingGoal = nil
    self.LastCompute = 0
    self.LastRequestAt = 0
    self.LastPathStatus = "None"
    self.LastNoPathAt = 0
    self.LastNoPathGoal = nil
    self.ConsecutiveNoPath = 0
    self.FrontierCacheGoal = nil
    self.FrontierCacheResult = nil
    self.FrontierCacheAt = 0
    self:ClearPath()
end

function RoutePlanner:InvalidateGoal()
    self.CurrentGoal = nil
    self.NeedsRepath = true
end

function RoutePlanner:EnsureEntryPassThrough(instance)
    if not instance or not instance:IsA("BasePart") or not isEntryInstance(instance) then
        return
    end

    local modifier = instance:FindFirstChild("UIW_EntryPassThrough")

    if modifier and modifier:IsA("PathfindingModifier") then
        modifier.PassThrough = true
        modifier.Label = "UIWEntry"
        return
    end

    modifier = Instance.new("PathfindingModifier")
    modifier.Name = "UIW_EntryPassThrough"
    modifier.PassThrough = true
    modifier.Label = "UIWEntry"
    modifier.Parent = instance

    self.CreatedEntryModifiers[modifier] = true
end

function RoutePlanner:RefreshEntryPassThrough()
    for _, instance in ipairs(Workspace:GetDescendants()) do
        if instance:IsA("BasePart") and isEntryInstance(instance) then
            self:EnsureEntryPassThrough(instance)
        end
    end
end

function RoutePlanner:Start()
    self:RefreshEntryPassThrough()

    self.Maid:Give(Workspace.DescendantAdded:Connect(function(instance)
        if instance:IsA("BasePart") then
            task.defer(function()
                if instance.Parent and isEntryInstance(instance) then
                    self:EnsureEntryPassThrough(instance)
                end
            end)
        end
    end))
end

function RoutePlanner:Destroy()
    self:Reset()
    self.Maid:Clean()
    self:ClearAvoidZones()
    safeDestroy(self.AvoidFolder)

    for modifier in pairs(self.CreatedEntryModifiers) do
        safeDestroy(modifier)
    end

    table.clear(self.CreatedEntryModifiers)
end

function RoutePlanner:IsNoPathGroundSafe(result)
    if not result or not result.Instance then
        return false
    end

    if result.Normal.Y < CONFIG.NoPathGridMinNormalY then
        return false
    end

    local instance = result.Instance
    local root = getWorkspaceRoot(instance)

    if root and string.lower(root.Name or "") == "borders" then
        return false
    end

    local lowerName = string.lower(instance.Name or "")
    local fullName = string.lower(instance:GetFullName())

    local alwaysUnsafeWords = { "lava", "void", "kill" }

    for _, word in ipairs(alwaysUnsafeWords) do
        if string.find(lowerName, word, 1, true) or string.find(fullName, word, 1, true) then
            return false
        end
    end

    if self.Hazards and self.Hazards:IsPartActive(instance, os.clock()) then
        return false
    end

    return true
end

function RoutePlanner:GetNoPathGroundPoint(x, z, probeY, probeDepth, expectedY)
    local origin = Vector3.new(x, probeY, z)
    local remainingDepth = probeDepth or CONFIG.NoPathGridProbeDepth
    local ignored = {}

    local bestPosition = nil
    local bestPart = nil
    local bestError = math.huge

    for _ = 1, CONFIG.NoPathGroundSurfaceScanLimit do
        if remainingDepth <= 0 then
            break
        end

        local result = self.Geometry:RaycastSkippingEntries(
            origin,
            Vector3.new(0, -remainingDepth, 0),
            ignored
        )

        if not result then
            break
        end

        local instance = result.Instance
        local root = getWorkspaceRoot(instance)
        local isBorder = root and string.lower(root.Name or "") == "borders"
        local validGround = not isBorder and self:IsNoPathGroundSafe(result)

        if validGround then
            if not expectedY then
                return result.Position, result.Instance
            end

            local errorY = math.abs(result.Position.Y - expectedY)

            if errorY < bestError then
                bestError = errorY
                bestPosition = result.Position
                bestPart = result.Instance
            end

            if errorY <= CONFIG.NoPathExpectedHeightTolerance then
                return result.Position, result.Instance
            end
        end

        local travelled = math.max(result.Distance, 0)
        local epsilon = 0.35

        origin = result.Position + Vector3.new(0, -epsilon, 0)
        remainingDepth -= travelled + epsilon

        if instance ~= Workspace.Terrain then
            table.insert(ignored, instance)
        elseif isBorder and root then
            table.insert(ignored, root)
        end
    end

    if expectedY and bestPosition and bestError <= CONFIG.NoPathExpectedHeightTolerance then
        return bestPosition, bestPart
    end

    return nil
end

function RoutePlanner:IsNoPathEdgeClear(a, b)
    local signedDeltaY = b.Position.Y - a.Position.Y
    local deltaY = math.abs(signedDeltaY)

    if deltaY > CONFIG.NoPathGridMaxStepHeight then
        return false
    end

    for _, t in ipairs({0.33, 0.66}) do
        local x = a.Position.X + (b.Position.X - a.Position.X) * t
        local z = a.Position.Z + (b.Position.Z - a.Position.Z) * t
        local expectedY = a.Position.Y + signedDeltaY * t

        local localProbeY = math.max(a.Position.Y, b.Position.Y) + CONFIG.NoPathEdgeProbeAbove

        local groundPosition = self:GetNoPathGroundPoint(
            x, z, localProbeY, CONFIG.NoPathEdgeProbeDepth, expectedY
        )

        if not groundPosition then
            return false
        end

        if math.abs(groundPosition.Y - expectedY) > CONFIG.NoPathEdgeHeightTolerance then
            return false
        end
    end

    return true
end

function RoutePlanner:BuildDirectGroundCorridorRoute(startPosition, desiredGoal)
    local planarDelta = flatten(desiredGoal - startPosition)
    local planarDistance = planarDelta.Magnitude

    if planarDistance <= 1 or planarDistance > CONFIG.DirectGroundCorridorMaxDistance then
        return nil
    end

    local direction = planarDelta.Unit
    local yaw = directionToYaw(direction)

    if not self.Geometry:IsDirectionClearFrom(startPosition, direction, planarDistance, yaw) then
        return nil
    end

    local count = math.max(2, math.ceil(planarDistance / CONFIG.DirectGroundCorridorStep))

    local probeY = math.max(startPosition.Y, desiredGoal.Y) + CONFIG.DirectGroundCorridorProbeAbove

    local nodes = {}

    for index = 0, count do
        local t = index / count
        local x = startPosition.X + (desiredGoal.X - startPosition.X) * t
        local z = startPosition.Z + (desiredGoal.Z - startPosition.Z) * t
        local expectedY = startPosition.Y + (desiredGoal.Y - startPosition.Y) * t

        local groundPosition, groundPart = self:GetNoPathGroundPoint(x, z, probeY, nil, expectedY)

        if not groundPosition then
            return nil
        end

        local node = {
            Position = groundPosition,
            Ground = groundPart,
        }

        if #nodes > 0 then
            local previous = nodes[#nodes]

            if math.abs(node.Position.Y - previous.Position.Y) > CONFIG.NoPathGridMaxStepHeight then
                return nil
            end

            if not self:IsNoPathEdgeClear(previous, node) then
                return nil
            end
        end

        table.insert(nodes, node)
    end

    local waypoints = {}

    for index, node in ipairs(nodes) do
        local action = Enum.PathWaypointAction.Walk

        if index > 1 then
            local previous = nodes[index - 1]
            if node.Position.Y - previous.Position.Y >= CONFIG.NoPathGridJumpRise then
                action = Enum.PathWaypointAction.Jump
            end
        end

        table.insert(waypoints, {
            Position = node.Position + Vector3.new(0, 0.15, 0),
            Action = action,
        })
    end

    if #waypoints >= 2 then
        return waypoints
    end

    return nil
end

function RoutePlanner:FindReachableFrontierGoal(startPosition, desiredGoal)
    local now = os.clock()

    if self.FrontierCacheGoal
        and (self.FrontierCacheGoal - desiredGoal).Magnitude <= CONFIG.GoalChangeThreshold
    then
        local ttl = self.FrontierCacheResult
            and CONFIG.ProgressionFrontierCacheTTL
            or CONFIG.ProgressionFrontierFailureCacheTTL

        if now - self.FrontierCacheAt < ttl then
            return self.FrontierCacheResult
        end
    end

    local toward = unit(flatten(desiredGoal - startPosition))

    if toward.Magnitude <= 0 then
        return nil
    end

    local startPlanarDistance = flatten(desiredGoal - startPosition).Magnitude

    local candidates = {}
    for _, radius in ipairs(CONFIG.ProgressionFrontierProbeRadii) do
        for _, angle in ipairs(CONFIG.RouteAngles) do
            table.insert(candidates, {
                Radius = radius,
                Angle = angle,
            })
        end
    end

    local count = #candidates
    if count == 0 then
        return nil
    end

    local cursor = math.clamp(self.FrontierProbeCursor or 1, 1, count)
    local budget = math.max(1, CONFIG.ProgressionFrontierProbeBudget or 3)
    local bestGoal = nil
    local bestScore = -math.huge
    local tested = 0
    local visited = 0

    while tested < budget and visited < count do
        local spec = candidates[cursor]
        cursor += 1
        if cursor > count then
            cursor = 1
        end
        visited += 1

        local direction = rotateXZ(toward, spec.Angle)
        local sampleXZ = startPosition + direction * spec.Radius
        local ground = self:GetNoPathGroundPoint(
            sampleXZ.X,
            sampleXZ.Z,
            startPosition.Y + CONFIG.DirectGroundCorridorProbeAbove,
            90,
            startPosition.Y
        )

        if ground then
            tested += 1
            local candidate = ground + Vector3.new(0, 0.15, 0)
            local candidateDistance = flatten(desiredGoal - candidate).Magnitude
            local progress = startPlanarDistance - candidateDistance

            if progress >= -2 then
                local path = PathfindingService:CreatePath({
                    AgentRadius = CONFIG.PathAgentRadius,
                    AgentHeight = CONFIG.PathAgentHeight,
                    AgentCanJump = true,
                    WaypointSpacing = CONFIG.PathWaypointSpacing,
                })

                local ok = pcall(function()
                    path:ComputeAsync(startPosition, candidate)
                end)

                if ok
                    and path.Status == Enum.PathStatus.Success
                    and #path:GetWaypoints() > 0
                then
                    local verticalImprovement =
                        math.abs(startPosition.Y - desiredGoal.Y)
                        - math.abs(candidate.Y - desiredGoal.Y)

                    local score =
                        progress * 5
                        + verticalImprovement * 0.35
                        + direction:Dot(toward) * 8
                        - math.abs(spec.Angle) * 0.025

                    if progress >= CONFIG.ProgressionFrontierMinProgress or bestGoal == nil then
                        if score > bestScore then
                            bestScore = score
                            bestGoal = candidate
                        end
                    end
                end

                safeDestroy(path)
            end
        end
    end

    self.FrontierProbeCursor = cursor
    self.FrontierCacheGoal = desiredGoal
    self.FrontierCacheResult = bestGoal
    self.FrontierCacheAt = now

    return bestGoal
end

function RoutePlanner:BuildNoPathGroundRoute(startPosition, desiredGoal)
    local planarDelta = flatten(desiredGoal - startPosition)
    local planarDistance = planarDelta.Magnitude

    if planarDistance <= 1 then
        return nil
    end

    local searchGoal = desiredGoal

    if planarDistance > CONFIG.NoPathGridMaxSpan then
        searchGoal = startPosition + planarDelta.Unit * CONFIG.NoPathGridMaxSpan
    end

    local margin = CONFIG.NoPathGridMargin
    local step = CONFIG.NoPathGridStep

    local minX = math.floor((math.min(startPosition.X, searchGoal.X) - margin) / step) * step
    local maxX = math.ceil((math.max(startPosition.X, searchGoal.X) + margin) / step) * step
    local minZ = math.floor((math.min(startPosition.Z, searchGoal.Z) - margin) / step) * step
    local maxZ = math.ceil((math.max(startPosition.Z, searchGoal.Z) + margin) / step) * step

    local countX = math.floor((maxX - minX) / step + 0.5)
    local countZ = math.floor((maxZ - minZ) / step + 0.5)

    if (countX + 1) * (countZ + 1) > CONFIG.NoPathGridMaxNodes then
        return nil
    end

    local probeY = math.max(startPosition.Y, desiredGoal.Y) + CONFIG.NoPathGridProbeAbove

    local nodes = {}

    local function key(ix, iz)
        return tostring(ix) .. ":" .. tostring(iz)
    end

    for ix = 0, countX do
        local x = minX + ix * step

        for iz = 0, countZ do
            local z = minZ + iz * step

            local segment = flatten(searchGoal - startPosition)
            local segmentLengthSq = segment.X * segment.X + segment.Z * segment.Z
            local routeT = 0

            if segmentLengthSq > 0.001 then
                local fromStart = Vector3.new(x - startPosition.X, 0, z - startPosition.Z)
                routeT = math.clamp(
                    (fromStart.X * segment.X + fromStart.Z * segment.Z) / segmentLengthSq,
                    0,
                    1
                )
            end

            local expectedY = startPosition.Y + (searchGoal.Y - startPosition.Y) * routeT

            local groundPosition, groundPart = self:GetNoPathGroundPoint(x, z, probeY, nil, expectedY)

            if groundPosition then
                nodes[key(ix, iz)] = {
                    IX = ix,
                    IZ = iz,
                    Position = groundPosition,
                    Ground = groundPart,
                }
            end
        end
    end

    local nodeCount = 0

    for _ in pairs(nodes) do
        nodeCount += 1
    end

    if nodeCount < 2 then
        return nil
    end

    local function nearestNode(position)
        local best = nil
        local bestDistance = math.huge

        for _, node in pairs(nodes) do
            local distance = flatten(node.Position - position).Magnitude
            if distance < bestDistance then
                best = node
                bestDistance = distance
            end
        end

        return best, bestDistance
    end

    local startNode, startDistance = nearestNode(startPosition)
    local goalNode, goalDistance = nearestNode(searchGoal)

    if not startNode
        or not goalNode
        or startDistance > step * 1.8
        or goalDistance > step * 2.2
    then
        return nil
    end

    local startKey = key(startNode.IX, startNode.IZ)
    local goalKey = key(goalNode.IX, goalNode.IZ)

    local open = { [startKey] = true }
    local cameFrom = {}
    local gScore = { [startKey] = 0 }

    local directions = {
        { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
        { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 },
    }

    local edgeCache = {}

    local function heuristic(node)
        return flatten(goalNode.Position - node.Position).Magnitude
    end

    local foundKey = nil

    for _ = 1, math.min(nodeCount * 5, 8000) do
        local currentKey = nil
        local currentNode = nil
        local currentF = math.huge

        for candidateKey in pairs(open) do
            local candidate = nodes[candidateKey]
            local f = (gScore[candidateKey] or math.huge) + heuristic(candidate)

            if f < currentF then
                currentKey = candidateKey
                currentNode = candidate
                currentF = f
            end
        end

        if not currentNode then
            break
        end

        if currentKey == goalKey then
            foundKey = currentKey
            break
        end

        open[currentKey] = nil

        for _, offset in ipairs(directions) do
            local nextKey = key(currentNode.IX + offset[1], currentNode.IZ + offset[2])
            local nextNode = nodes[nextKey]

            if nextNode then
                local edgeKey = currentKey .. ">" .. nextKey
                local clear = edgeCache[edgeKey]

                if clear == nil then
                    clear = self:IsNoPathEdgeClear(currentNode, nextNode)
                    edgeCache[edgeKey] = clear
                end

                if clear then
                    local planarCost = flatten(nextNode.Position - currentNode.Position).Magnitude
                    local riseCost = math.abs(nextNode.Position.Y - currentNode.Position.Y) * 1.5
                    local tentative = (gScore[currentKey] or 0) + planarCost + riseCost

                    if tentative < (gScore[nextKey] or math.huge) then
                        cameFrom[nextKey] = currentKey
                        gScore[nextKey] = tentative
                        open[nextKey] = true
                    end
                end
            end
        end
    end

    if not foundKey then
        return nil
    end

    local reversed = {}
    local currentKey = foundKey

    while currentKey do
        local node = nodes[currentKey]
        if not node then
            break
        end
        table.insert(reversed, 1, node)
        currentKey = cameFrom[currentKey]
    end

    if #reversed < 2 then
        return nil
    end

    local waypoints = {}

    for index, node in ipairs(reversed) do
        local action = Enum.PathWaypointAction.Walk

        if index > 1 then
            local previous = reversed[index - 1]
            if node.Position.Y - previous.Position.Y >= CONFIG.NoPathGridJumpRise then
                action = Enum.PathWaypointAction.Jump
            end
        end

        table.insert(waypoints, {
            Position = node.Position + Vector3.new(0, 0.15, 0),
            Action = action,
        })
    end

    return waypoints
end

function RoutePlanner:InstallFallbackRoute(waypoints, desiredGoal)
    if not waypoints or #waypoints < 2 then
        return false
    end

    self:DisconnectBlocked()

    if self.ActivePath then
        safeDestroy(self.ActivePath)
    end

    self.ActivePath = nil
    self.Waypoints = waypoints
    self.WaypointIndex = self:FindStartingWaypoint(waypoints)
    self.CurrentGoal = desiredGoal
    self.NeedsRepath = false
    self.CachedSafeDirection = Vector3.zero
    self.FallbackRoute = true
    self.LastPathStatus = "GroundFallback"

    self:SetupWaypointPlane()

    return true
end

function RoutePlanner:CreatePath()
    self:PruneAvoidZones()

    return PathfindingService:CreatePath({
        AgentRadius = CONFIG.PathAgentRadius,
        AgentHeight = CONFIG.PathAgentHeight,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = CONFIG.PathWaypointSpacing,
        Costs = {
            UIWAvoid = CONFIG.AvoidZoneCost,
        },
    })
end

-- v39: spots where the character got stuck become expensive for the
-- pathfinder, so the next route goes around them instead of into them.
function RoutePlanner:AddAvoidZone(position, lifetime)
    if not self.AvoidFolder or not self.AvoidFolder.Parent then
        local folder = Instance.new("Folder")
        folder.Name = "UIW_AvoidZones"
        folder.Parent = Workspace
        self.AvoidFolder = folder
    end

    self.AvoidZones = self.AvoidZones or {}

    local part = Instance.new("Part")
    part.Name = "UIWAvoidZone"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = Vector3.new(CONFIG.AvoidZoneSize, 8, CONFIG.AvoidZoneSize)
    part.CFrame = CFrame.new(position + Vector3.new(0, 1, 0))

    local modifier = Instance.new("PathfindingModifier")
    modifier.Label = "UIWAvoid"
    modifier.Parent = part

    part.Parent = self.AvoidFolder

    table.insert(self.AvoidZones, {
        Part = part,
        Expires = os.clock() + (lifetime or CONFIG.AvoidZoneLifetime),
    })

    while #self.AvoidZones > CONFIG.MaxAvoidZones do
        safeDestroy(table.remove(self.AvoidZones, 1).Part)
    end
end

function RoutePlanner:PruneAvoidZones()
    if not self.AvoidZones then
        return
    end

    local now = os.clock()
    for index = #self.AvoidZones, 1, -1 do
        if now >= self.AvoidZones[index].Expires then
            safeDestroy(table.remove(self.AvoidZones, index).Part)
        end
    end
end

function RoutePlanner:ClearAvoidZones()
    for _, zone in ipairs(self.AvoidZones or {}) do
        safeDestroy(zone.Part)
    end
    self.AvoidZones = {}
end

function RoutePlanner:SkipToVisibleWaypoint(targetYaw)
    local root = self.CharacterService.Root
    if not root or #self.Waypoints == 0 then
        return false
    end

    local last = math.min(#self.Waypoints, self.WaypointIndex + 8)

    for index = last, self.WaypointIndex + 1, -1 do
        local waypoint = self.Waypoints[index]
        local delta = flatten(waypoint.Position - root.Position)

        if delta.Magnitude > 2
            and delta.Magnitude <= 36
            and math.abs(waypoint.Position.Y - root.Position.Y) <= 3
            and self.Geometry:IsDirectionClear(delta.Unit, delta.Magnitude, targetYaw)
        then
            self.WaypointIndex = index
            self.LastJumpWaypoint = 0
            self:SetupWaypointPlane()
            return true
        end
    end

    return false
end

function RoutePlanner:FindStartingWaypoint(waypoints)
    local root = self.CharacterService.Root

    if not root or #waypoints == 0 then
        return 1
    end

    if #waypoints == 1 then
        return 1
    end

    local index = 2

    while index <= #waypoints do
        local delta = flatten(waypoints[index].Position - root.Position)
        if delta.Magnitude >= CONFIG.PathWaypointStartRadius then
            break
        end
        index += 1
    end

    return math.min(index, #waypoints)
end

function RoutePlanner:SetupWaypointPlane()
    self.CurrentWaypointPlaneNormal = Vector3.zero
    self.CurrentWaypointPlaneDistance = 0

    local index = self.WaypointIndex

    if index <= 1 or index > #self.Waypoints then
        return
    end

    local previous = self.Waypoints[index - 1]
    local current = self.Waypoints[index]

    if not previous or not current then
        return
    end

    local normal = previous.Position - current.Position
    normal = Vector3.new(normal.X, 0, normal.Z)

    if normal.Magnitude <= 0.000001 then
        return
    end

    normal = normal.Unit

    self.CurrentWaypointPlaneNormal = normal
    self.CurrentWaypointPlaneDistance = normal:Dot(current.Position)
end

function RoutePlanner:IsCurrentWaypointReached()
    if self.WaypointIndex > #self.Waypoints then
        return true
    end

    if not self.CharacterService:IsAlive() then
        return false
    end

    local root = self.CharacterService.Root
    local normal = self.CurrentWaypointPlaneNormal

    if normal.Magnitude <= 0.000001 then
        return true
    end

    local distance = normal:Dot(root.Position) - self.CurrentWaypointPlaneDistance

    local forwardVelocity = -normal:Dot(root.AssemblyLinearVelocity)

    local threshold = math.max(
        CONFIG.PathPlaneMinThreshold,
        CONFIG.PathPlaneVelocityMultiplier * math.max(0, forwardVelocity)
    )

    return distance <= threshold
end

function RoutePlanner:AdvanceWaypoints()
    while self.WaypointIndex <= #self.Waypoints and self:IsCurrentWaypointReached() do
        self.WaypointIndex += 1
        self.LastJumpWaypoint = 0
        self:SetupWaypointPlane()
    end
end

function RoutePlanner:HandleWaypointJump()
    local waypoint = self.Waypoints[self.WaypointIndex]

    if not waypoint or waypoint.Action ~= Enum.PathWaypointAction.Jump then
        return
    end

    local humanoid = self.CharacterService.Humanoid

    if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
        return
    end

    local now = os.clock()

    if self.LastJumpWaypoint == self.WaypointIndex
        and now - self.LastJumpAt < CONFIG.PathJumpRetry
    then
        return
    end

    self.LastJumpWaypoint = self.WaypointIndex
    self.LastJumpAt = now

    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

function RoutePlanner:InstallPath(path, waypoints, goal)
    if not path or #waypoints == 0 then
        return false
    end

    local oldPath = self.ActivePath

    self:DisconnectBlocked()

    self.ActivePath = path
    self.Waypoints = waypoints
    self.WaypointIndex = self:FindStartingWaypoint(waypoints)
    self.CurrentGoal = goal
    self.NeedsRepath = false
    self.CachedSafeDirection = Vector3.zero
    self.FallbackRoute = false
    self.LastPathStatus = "Success"

    self:SetupWaypointPlane()

    local installedPath = path

    self.BlockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
        if self.ActivePath ~= installedPath then
            return
        end

        if blockedWaypointIndex >= self.WaypointIndex then
            self.NeedsRepath = true

            local target = self.CurrentGoal

            if target then
                task.defer(function()
                    if self.ActivePath == installedPath and self.NeedsRepath then
                        self:RequestPath(target, true)
                    end
                end)
            end
        end
    end)

    if oldPath and oldPath ~= path then
        safeDestroy(oldPath)
    end

    return true
end

function RoutePlanner:RequestPath(goal, force)
    if not goal or not self.CharacterService:IsAlive() then
        return
    end

    local now = os.clock()

    if self.LastPathStatus == "NoPath"
        and self.LastNoPathGoal
        and (self.LastNoPathGoal - goal).Magnitude <= CONFIG.GoalChangeThreshold
        and now - self.LastNoPathAt < math.min(
            CONFIG.NoPathRetryMaxInterval,
            CONFIG.NoPathRetryInterval
                * math.max(1, 2 ^ math.max(0, (self.ConsecutiveNoPath or 1) - 1))
        )
    then
        return
    end

    if #self.Waypoints > 0 and now - self.LastRequestAt < CONFIG.PathRecomputeThrottle then
        self.PendingGoal = goal
        return
    end

    if self.Computing then
        self.PendingGoal = goal
        if force then
            self.NeedsRepath = true
        end
        return
    end

    if not force
        and self.CurrentGoal
        and (self.CurrentGoal - goal).Magnitude <= CONFIG.GoalChangeThreshold
        and #self.Waypoints > 0
        and self.WaypointIndex <= #self.Waypoints
        and not self.NeedsRepath
    then
        return
    end

    self.LastRequestAt = now
    self.Computing = true
    self.RequestSerial += 1

    local serial = self.RequestSerial
    local startPosition = self.CharacterService.Root.Position
    local requestedGoal = goal

    task.spawn(function()
        local path = self:CreatePath()

        local success = pcall(function()
            path:ComputeAsync(startPosition, requestedGoal)
        end)

        -- Prefer clearance even when the route is longer; allow narrow doors
        -- only after the wide route fails. No shared radius is changed here.
        local usedRadius = CONFIG.PathPreferredRadius
        if serial == self.RequestSerial and (not success or path.Status ~= Enum.PathStatus.Success) then
            safeDestroy(path)
            path = self:CreatePath(CONFIG.PathAgentRadius)
            usedRadius = CONFIG.PathAgentRadius
            success = pcall(function() path:ComputeAsync(startPosition, requestedGoal) end)
        end
        if serial == self.RequestSerial then self.LastRouteRadius = usedRadius end

        if serial ~= self.RequestSerial then
            safeDestroy(path)
            return
        end

        local installed = false

        if success and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()

            if #waypoints > 0 then
                installed = self:InstallPath(path, waypoints, requestedGoal)

                if installed then
                    self.ConsecutiveNoPath = 0
                end
            end
        end

        if not installed then
            safeDestroy(path)

            self.CachedSafeDirection = Vector3.zero

            local directWaypoints = self:BuildDirectGroundCorridorRoute(startPosition, requestedGoal)

            if serial ~= self.RequestSerial then
                return
            end

            if directWaypoints and #directWaypoints >= 2 then
                installed = self:InstallFallbackRoute(directWaypoints, requestedGoal)

                if installed then
                    self.LastPathStatus = "DirectFallback"
                end
            end

            local fallbackWaypoints = nil

            if not installed
                and os.clock() - (self.LastHeavyFallbackAt or 0) >= CONFIG.NoPathHeavyFallbackCooldown
            then
                self.LastHeavyFallbackAt = os.clock()
                fallbackWaypoints = self:BuildNoPathGroundRoute(startPosition, requestedGoal)
            end

            if serial ~= self.RequestSerial then
                return
            end

            if not installed and fallbackWaypoints and #fallbackWaypoints >= 2 then
                installed = self:InstallFallbackRoute(fallbackWaypoints, requestedGoal)
            end

            if not installed then
                self:ClearPath()
                self.CurrentGoal = requestedGoal
                self.NeedsRepath = true
                self.LastPathStatus = "NoPath"
                self.ConsecutiveNoPath = math.min(4, (self.ConsecutiveNoPath or 0) + 1)
                self.LastNoPathAt = os.clock()
                self.LastNoPathGoal = requestedGoal
            end
        else
            self.LastNoPathGoal = nil
            self.LastNoPathAt = 0
        end

        self.LastCompute = os.clock()
        self.Computing = false

        local pending = self.PendingGoal
        self.PendingGoal = nil

        if pending and self.CharacterService:IsAlive() then
            local needsPending = not self.CurrentGoal
                or (self.CurrentGoal - pending).Magnitude > CONFIG.GoalChangeThreshold
                or self.NeedsRepath

            if needsPending then
                task.defer(function()
                    self:RequestPath(pending, true)
                end)
            end
        end
    end)
end

function RoutePlanner:ForceRepath(goal)
    self.NeedsRepath = true
    goal = goal or self.CurrentGoal
    if goal then
        self:RequestPath(goal, true)
    end
end

function RoutePlanner:GetRawDirection(goal, reachDistance)
    local character = self.CharacterService

    if not character:IsAlive() or not goal then
        self.CachedSafeDirection = Vector3.zero
        return Vector3.zero
    end

    local root = character.Root
    local fullGoalDelta = goal - root.Position
    local goalDelta = flatten(fullGoalDelta)
    local effectiveReachDistance = tonumber(reachDistance) or CONFIG.PathGoalReachDistance

    -- Healer following needs true 3D distance for stairs, ladders and drops.
    -- Combat navigation intentionally uses horizontal distance because enemy
    -- root heights and animation offsets are not walkable destinations.
    local reachDelta = self.Use3DGoalDistance and fullGoalDelta or goalDelta
    if reachDelta.Magnitude <= effectiveReachDistance then
        self.CachedSafeDirection = Vector3.zero
        return Vector3.zero
    end

    local goalChanged = not self.CurrentGoal
        or (self.CurrentGoal - goal).Magnitude > CONFIG.GoalChangeThreshold

    if goalChanged then
        self:RequestPath(goal, true)
    elseif self.NeedsRepath then
        self:RequestPath(goal, true)
    elseif #self.Waypoints == 0 then
        self:RequestPath(goal, true)
    end

    if #self.Waypoints > 0 and self.WaypointIndex <= #self.Waypoints then
        self:AdvanceWaypoints()
    end

    if #self.Waypoints > 0 and self.WaypointIndex > #self.Waypoints then
        self.CachedSafeDirection = Vector3.zero
        self:ClearPath()
        self.CurrentGoal = goal
        self.NeedsRepath = true
        self:RequestPath(goal, true)
        return Vector3.zero
    end

    if self.WaypointIndex <= #self.Waypoints and #self.Waypoints > 0 then
        self:HandleWaypointJump()

        local waypoint = self.Waypoints[self.WaypointIndex]
        local delta = flatten(waypoint.Position - root.Position)

        if delta.Magnitude > 0.05 then
            local direction = unit(delta)
            self.CachedSafeDirection = direction
            return direction
        end
    end

    if self.Computing
        and #self.Waypoints > 0
        and self.WaypointIndex <= #self.Waypoints
        and self.CachedSafeDirection.Magnitude > 0
    then
        return self.CachedSafeDirection
    end

    if not self.Computing then
        self:RequestPath(goal, true)
    end

    if goalDelta.Magnitude <= 10 then
        local direction = unit(goalDelta)
        self.CachedSafeDirection = direction
        return direction
    end

    self.CachedSafeDirection = Vector3.zero
    return Vector3.zero
end

function RoutePlanner:GetSafeDirection(goal, targetYaw, reachDistance)
    return self:GetRawDirection(goal, reachDistance)
end
