local DungeonModel = {}
DungeonModel.__index = DungeonModel

function DungeonModel.new()
    return setmetatable({
        Dungeon = nil,
        Rooms = {},
        LastKnownRoom = 1,
        EnemyCache = {},
        LastEnemyRefresh = 0,
    }, DungeonModel)
end

function DungeonModel:Refresh()
    self.Dungeon = Workspace:FindFirstChild("dungeon")

    table.clear(self.Rooms)

    if not self.Dungeon then
        return
    end

    for _, child in ipairs(self.Dungeon:GetChildren()) do
        local number = tonumber(string.match(child.Name, "^room(%d+)$"))
        if number then
            self.Rooms[number] = child
        end
    end
end

function DungeonModel:WrapEnemy(model, room)
    if not model:IsA("Model") then
        return nil
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart

    if not humanoid or humanoid.Health <= 0 or not root then
        return nil
    end

    return {
        Model = model,
        Humanoid = humanoid,
        Root = root,
        Room = room,
    }
end

function DungeonModel:GetAliveEnemies(force)
    local now = os.clock()

    if not force and now - self.LastEnemyRefresh < CONFIG.TargetRefreshInterval then
        return self.EnemyCache
    end

    self.LastEnemyRefresh = now

    table.clear(self.EnemyCache)

    for roomNumber, room in pairs(self.Rooms) do
        local folder = room:FindFirstChild("enemyFolder")

        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                local enemy = self:WrapEnemy(model, roomNumber)
                if enemy then
                    table.insert(self.EnemyCache, enemy)
                end
            end
        end
    end

    if self.Dungeon then
        local bossRoom = self.Dungeon:FindFirstChild("bossRoom")
        local folder = bossRoom and bossRoom:FindFirstChild("enemyFolder")

        if folder then
            for _, model in ipairs(folder:GetChildren()) do
                local enemy = self:WrapEnemy(model, 999)
                if enemy then
                    table.insert(self.EnemyCache, enemy)
                end
            end
        end
    end

    return self.EnemyCache
end

function DungeonModel:GetEnemyDangerAt(position)
    local nearestEnemy = nil
    local nearestDistance = math.huge

    for _, enemy in ipairs(self:GetAliveEnemies()) do
        if enemy.Root and enemy.Root.Parent and enemy.Humanoid and enemy.Humanoid.Health > 0 then
            local threatClass = getEnemyThreatClass(enemy)
            local dangerRadius = 10
            if threatClass == "Melee" then
                dangerRadius = CONFIG.MeleeEmergencyRadius
            elseif threatClass == "Proximity" then
                dangerRadius = CONFIG.MeleeEmergencyRadius + CONFIG.ProximityEmergencyBonus
            end

            local velocity = flatten(enemy.Root.AssemblyLinearVelocity)
            local predicted = enemy.Root.Position + velocity * 0.30
            local distance = math.min(
                flatten(enemy.Root.Position - position).Magnitude,
                flatten(predicted - position).Magnitude
            )

            if distance <= dangerRadius and distance < nearestDistance then
                nearestEnemy = enemy
                nearestDistance = distance
            end
        end
    end

    return nearestEnemy, nearestDistance
end

function DungeonModel:FindEnemyByModel(model)
    if not model or not model.Parent then
        return nil
    end

    for _, enemy in ipairs(self:GetAliveEnemies()) do
        if enemy.Model == model then
            return enemy
        end
    end

    return nil
end

function DungeonModel:GetNearestEnemy(position)
    local best = nil
    local bestDistance = math.huge

    for _, enemy in ipairs(self:GetAliveEnemies()) do
        local distance = (enemy.Root.Position - position).Magnitude

        if distance < bestDistance then
            best = enemy
            bestDistance = distance
        end
    end

    if best and best.Room ~= 999 then
        self.LastKnownRoom = math.max(self.LastKnownRoom, best.Room)
    end

    return best
end

function DungeonModel:GetMeleeThreats(position, radius)
    local result = {}

    for _, enemy in ipairs(self:GetAliveEnemies()) do
        if enemy.Root
            and enemy.Root.Parent
            and enemy.Humanoid
            and enemy.Humanoid.Health > 0
        then
            local threatClass = getEnemyThreatClass(enemy)

            if threatClass then
                local velocity = flatten(enemy.Root.AssemblyLinearVelocity)

                local predictionTime = threatClass == "Proximity" and 0.38 or 0.30

                local predictedPosition = enemy.Root.Position + velocity * predictionTime

                local currentDistance = flatten(enemy.Root.Position - position).Magnitude
                local predictedDistance = flatten(predictedPosition - position).Magnitude
                local effectiveDistance = math.min(currentDistance, predictedDistance)

                local detectionRadius = radius + (threatClass == "Proximity" and 8 or 0)

                if effectiveDistance <= detectionRadius then
                    table.insert(result, {
                        Enemy = enemy,
                        Distance = effectiveDistance,
                        CurrentDistance = currentDistance,
                        PredictedDistance = predictedDistance,
                        ThreatClass = threatClass,
                    })
                end
            end
        end
    end

    table.sort(result, function(a, b)
        return a.Distance < b.Distance
    end)

    return result
end

function DungeonModel:IsCheckpointReachable(position, checkpoint, routePlanner)
    if not checkpoint or not checkpoint:IsA("BasePart") or not checkpoint.Parent then
        return false
    end

    if flatten(checkpoint.Position - position).Magnitude
        <= CONFIG.ProgressionCheckpointReachDistance
    then
        return true
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = CONFIG.PathAgentRadius,
        AgentHeight = CONFIG.PathAgentHeight,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = CONFIG.PathWaypointSpacing,
    })

    local ok = pcall(function()
        path:ComputeAsync(position, checkpoint.Position)
    end)

    if ok and path.Status == Enum.PathStatus.Success and #path:GetWaypoints() > 0 then
        return true
    end

    if routePlanner and routePlanner.BuildDirectGroundCorridorRoute then
        local direct = routePlanner:BuildDirectGroundCorridorRoute(position, checkpoint.Position)
        if direct and #direct >= 2 then
            return true
        end
    end

    return false
end

function DungeonModel:GetNextReachableCheckpointTowardRoom(position, targetRoom, minimumRoom, completedCheckpoints, routePlanner)
    if not targetRoom then
        return nil, nil
    end

    local maximumRoom

    if targetRoom == 999 then
        maximumRoom = 9
    else
        maximumRoom = math.min(targetRoom, 9)
    end

    local firstRoom = math.max(minimumRoom or 1, 1)

    if firstRoom > maximumRoom then
        return nil, nil
    end

    local candidates = {}

    for roomNumber = firstRoom, maximumRoom do
        if not completedCheckpoints or not completedCheckpoints[roomNumber] then
            local room = self.Rooms[roomNumber]
            local checkpoint = room and room:FindFirstChild("checkPoint")

            if checkpoint and checkpoint:IsA("BasePart") and checkpoint.Parent then
                local distance = flatten(checkpoint.Position - position).Magnitude

                if distance > CONFIG.ProgressionCheckpointReachDistance then
                    table.insert(candidates, {
                        Part = checkpoint,
                        Room = roomNumber,
                        Distance = distance,
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a, b)
        if math.abs(a.Distance - b.Distance) <= 0.01 then
            return a.Room > b.Room
        end
        return a.Distance < b.Distance
    end)

    for _, candidate in ipairs(candidates) do
        if self:IsCheckpointReachable(position, candidate.Part, routePlanner) then
            return candidate.Part, candidate.Room
        end
    end

    return nil, nil
end

function DungeonModel:GetProgressionGoal(position)
    for roomNumber = math.max(self.LastKnownRoom, 1), 9 do
        local room = self.Rooms[roomNumber]

        if room then
            local checkpoint = room:FindFirstChild("checkPoint")

            if checkpoint and checkpoint:IsA("BasePart") then
                if flatten(checkpoint.Position - position).Magnitude
                    > CONFIG.ProgressionCheckpointReachDistance
                then
                    return checkpoint.Position
                end
            end
        end
    end

    return nil
end

