-- Healer mode follows one party member, keeps the normal hazard dodger active,
-- equips the best owned spell-power armor and casts owned healing abilities.
do
    local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("remotes")
    local HEALER_ROUTE_FILE = ConfigStore.AccountFolder .. "/healer_routes.json"
    local ROUTE_SAMPLE_DISTANCE = 4
    local ROUTE_REACH_DISTANCE = 5
    local ROUTE_RESYNC_DISTANCE = 32
    local ROUTE_COMBAT_PAUSE_DISTANCE = 100

    local function healerDungeonFinished()
        local dungeon = Workspace:FindFirstChild("dungeon")
        local bossRoom = dungeon and dungeon:FindFirstChild("bossRoom")
        local flag = bossRoom and bossRoom:FindFirstChild("dungeonFinished")
        return (flag and flag:IsA("ValueBase") and flag.Value == true)
            or (dungeon and dungeon:GetAttribute("dungeonFinished") == true)
    end

    local HEAL_SCORE = {
        ["revitalize"] = 900,
        ["universal heal"] = 860,
        ["chain heal"] = 820,
        ["life pulse"] = 780,
        ["life dash"] = 740,
        ["aura of life"] = 620,
        ["rejuvenating spray"] = 580,
        ["holy circle"] = 520,
        ["redemption"] = 420,
    }

    local HEAL_RANGE = {
        ["universal heal"] = math.huge,
        ["chain heal"] = 55,
        ["revitalize"] = 32,
        ["life pulse"] = 30,
        ["life dash"] = 34,
        ["aura of life"] = 28,
        ["rejuvenating spray"] = 36,
        ["holy circle"] = 28,
        ["redemption"] = 24,
    }

    -- Most heals apply over time or leave an area behind. This shared coverage
    -- window prevents the second equipped spell from firing immediately after
    -- the first one. Critical health shortens the wait, but still separates
    -- the casts so both heals are not wasted on the same instant of damage.
    local HEAL_COVERAGE = {
        ["revitalize"] = 4.0,
        ["universal heal"] = 2.5,
        ["chain heal"] = 2.0,
        ["life pulse"] = 4.0,
        ["life dash"] = 2.5,
        ["aura of life"] = 4.0,
        ["rejuvenating spray"] = 1.5,
        ["holy circle"] = 4.0,
        ["redemption"] = 2.0,
    }

    local function normalized(value)
        return string.lower(string.match(tostring(value or ""), "^%s*(.-)%s*$"))
    end

    local function cleanName(value)
        return string.match(tostring(value or ""), "^%s*([%w_]+)%s*$")
    end

    local function playerNamed(name)
        name = normalized(name)
        for _, player in ipairs(Players:GetPlayers()) do
            if normalized(player.Name) == name then return player end
        end
    end

    local function routeVector(point)
        if type(point) ~= "table" then return nil end
        local x, y, z = tonumber(point.X or point.x or point[1]),
            tonumber(point.Y or point.y or point[2]),
            tonumber(point.Z or point.z or point[3])
        if not x or not y or not z then return nil end
        return Vector3.new(x, y, z)
    end

    local function routePoint(position)
        return { X = position.X, Y = position.Y, Z = position.Z }
    end

    local function itemNumber(key)
        return tonumber(string.match(tostring(key or ""), "(%d+)$"))
    end

    local function isEquipped(item)
        if item.equipped == true then return true end
        if type(item.equipped) == "table" then
            for _, value in pairs(item.equipped) do
                if value == true then return true end
            end
        end
        return false
    end

    local function bestSpellPower(container, level)
        local bestKey, bestItem, bestSpell, bestHealth = nil, nil, -1, -1
        for key, item in pairs(container or {}) do
            if type(item) == "table" and (tonumber(item.levelReq) or 0) <= level then
                local spell = tonumber(item.spellPower) or 0
                local health = tonumber(item.health) or 0
                if spell > bestSpell or (spell == bestSpell and health > bestHealth) then
                    bestKey, bestItem, bestSpell, bestHealth = key, item, spell, health
                end
            end
        end
        return bestKey, bestItem
    end

    local function healingAbilities(container, level)
        local found, usedNames = {}, {}
        for key, item in pairs(container or {}) do
            local name = normalized(type(item) == "table" and item.name)
            local score = HEAL_SCORE[name]
            if score and (tonumber(item.levelReq) or 0) <= level and not usedNames[name] then
                usedNames[name] = true
                table.insert(found, { Key = key, Item = item, Score = score })
            end
        end
        table.sort(found, function(a, b)
            if a.Score == b.Score then
                return (tonumber(a.Item.levelReq) or 0) > (tonumber(b.Item.levelReq) or 0)
            end
            return a.Score > b.Score
        end)
        return found
    end

    function UIWController:GetHealerTarget()
        if not self.HealerEnabled then return nil end
        local requested = cleanName(self.HealerTargetName)
        if not requested or requested == "" then requested = cleanName(self.CarryHostName) end
        local target = playerNamed(requested)
        if target == LocalPlayer then return nil end
        local character = target and target.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not root or humanoid.Health <= 0 then return nil end
        return target, character, humanoid, root, requested
    end

    function UIWController:SetHealerOption(key, value)
        if key == "HealerEnabled" then
            self.HealerEnabled = value == true
            if self.HealerEnabled then
                self.AutoDodge = true
            end
        elseif key == "HealerTargetName" then
            self.HealerTargetName = cleanName(value) or ""
        elseif key == "HealerAutoEquip" then
            self.HealerAutoEquip = value == true
        elseif key == "HealerFollowDistance" then
            self.HealerFollowDistance = math.clamp(tonumber(value) or 14, 8, 35)
        elseif key == "HealerUseRecordedPath" then
            self.HealerUseRecordedPath = value == true
            self.HealerRouteIndex = nil
            self.RecordedRouteCompleteKey = nil
            self.Route:InvalidateGoal()
        else
            return
        end
        self.HealerLastEquipAt = 0
        self.Route:InvalidateGoal()
        self:WriteMeta()
        if self.HealerEnabled then self:ConfigureAutoExecute() end
        if self.HUD then
            self.HUD:RefreshControls()
            if self.HUD.RefreshHealer then self.HUD:RefreshHealer() end
        end
    end

    function UIWController:GetHealerRouteName()
        local dungeon = Workspace:FindFirstChild("dungeonName")
        local name = dungeon and dungeon:IsA("ValueBase") and tostring(dungeon.Value or "") or ""
        return name ~= "" and name or ("Place " .. tostring(game.PlaceId))
    end

    function UIWController:GetHealerRouteKey()
        return string.lower(string.gsub(self:GetHealerRouteName(), "[^%w]+", "_"))
    end

    function UIWController:LoadHealerRoutes()
        if self.HealerRecordedRoutes then return self.HealerRecordedRoutes end
        local saved = SafeFile.ReadJson(HEALER_ROUTE_FILE)
        self.HealerRecordedRoutes = type(saved) == "table" and saved or {}
        return self.HealerRecordedRoutes
    end

    function UIWController:SaveHealerRoutes()
        ConfigStore.EnsureAccountFolder()
        return SafeFile.WriteJson(HEALER_ROUTE_FILE, self:LoadHealerRoutes(), true)
    end

    function UIWController:GetRecordedHealerRoute()
        local route = self:LoadHealerRoutes()[self:GetHealerRouteKey()]
        return type(route) == "table" and route or nil
    end

    function UIWController:StartHealerRouteRecording()
        if not self.Character:IsAlive() then
            self.HealerRouteStatus = "Cannot record until the character has spawned"
            return false
        end
        self.HealerRecording = true
        self.RecordedRouteCompleteKey = nil
        self.HealerRecordingKey = self:GetHealerRouteKey()
        self.HealerRecordingPoints = { routePoint(self.Character.Root.Position) }
        self.HealerRouteStatus = "Recording " .. self:GetHealerRouteName()
            .. " route: 1 point • saves automatically when complete"
        self.Character:ReleaseAutomationFacing()
        self.Route:Reset()
        if self.HUD and self.HUD.RefreshHealer then self.HUD:RefreshHealer() end
        return true
    end

    function UIWController:SampleHealerRoute(force)
        if not self.HealerRecording or not self.Character:IsAlive() then return end
        local points = self.HealerRecordingPoints
        local position = self.Character.Root.Position
        local previous = points and routeVector(points[#points])
        local delta = previous and position - previous or Vector3.zero
        if not previous
            or flatten(delta).Magnitude >= ROUTE_SAMPLE_DISTANCE
            or math.abs(delta.Y) >= 2
            or (force and delta.Magnitude >= 0.5)
        then
            if #points < 800 then table.insert(points, routePoint(position)) end
            self.HealerRouteStatus = string.format("Recording %s route: %d points • auto-saves when complete",
                self:GetHealerRouteName(), #points)
        end
    end

    function UIWController:StopHealerRouteRecording(automatic)
        if not self.HealerRecording then return false end
        self:SampleHealerRoute(true)
        self.HealerRecording = false
        local points = self.HealerRecordingPoints or {}
        if #points < 2 then
            self.HealerRouteStatus = "Recording discarded: walk farther before saving"
            return false
        end
        self:LoadHealerRoutes()[self.HealerRecordingKey or self:GetHealerRouteKey()] = points
        local saved = self:SaveHealerRoutes()
        self.HealerRouteIndex = nil
        self.RecordedRouteCompleteKey = nil
        local dungeonName = self:GetHealerRouteName()
        self.HealerRouteStatus = saved
            and string.format("%s %s route: %d points",
                automatic and "Auto-saved" or "Saved", dungeonName, #points)
            or "Could not save route in the executor workspace"
        if self.HUD and self.HUD.RefreshHealer then self.HUD:RefreshHealer() end
        return saved
    end

    function UIWController:ClearHealerRecordedPath()
        if self.HealerRecording then self.HealerRecording = false end
        local routes = self:LoadHealerRoutes()
        routes[self:GetHealerRouteKey()] = nil
        self.HealerRouteIndex = nil
        self.RecordedRouteCompleteKey = nil
        local saved = self:SaveHealerRoutes()
        self.HealerRouteStatus = saved and ("Recorded route cleared for " .. self:GetHealerRouteName())
            or "Could not clear the recorded route"
        self.Route:Reset()
        if self.HUD and self.HUD.RefreshHealer then self.HUD:RefreshHealer() end
        return saved
    end

    function UIWController:GetHealerRecordedGoal(targetPosition)
        if not self.HealerUseRecordedPath then return nil end
        local points = self:GetRecordedHealerRoute()
        if not points or #points < 2 or not self.Character:IsAlive() then
            self.HealerRouteStatus = "Recorded route enabled • no route saved for this dungeon"
            return nil
        end

        local currentPosition = self.Character.Root.Position
        local function nearest(position)
            local bestIndex, bestDistance = nil, math.huge
            for index, point in ipairs(points) do
                local vector = routeVector(point)
                if vector then
                    local distance = (vector - position).Magnitude
                    if distance < bestDistance then
                        bestIndex, bestDistance = index, distance
                    end
                end
            end
            return bestIndex, bestDistance
        end

        local currentIndex = tonumber(self.HealerRouteIndex)
        local currentPoint = currentIndex and routeVector(points[currentIndex])
        if not currentPoint or (currentPoint - currentPosition).Magnitude > ROUTE_RESYNC_DISTANCE then
            currentIndex = nearest(currentPosition)
        end
        local targetIndex, targetDistance = nearest(targetPosition)
        if not currentIndex or not targetIndex or targetDistance > 55 then
            self.HealerRouteStatus = "Recorded route unavailable near the host • using live pathfinder"
            self.HealerRouteIndex = nil
            return nil
        end

        local direction = targetIndex > currentIndex and 1 or targetIndex < currentIndex and -1 or 0
        if direction == 0 then
            self.HealerRouteIndex = currentIndex
            self.HealerRouteStatus = string.format("Recorded route active • point %d/%d", currentIndex, #points)
            return nil
        end

        currentPoint = routeVector(points[currentIndex])
        if currentPoint and (currentPoint - currentPosition).Magnitude <= ROUTE_REACH_DISTANCE then
            currentIndex = math.clamp(currentIndex + direction, 1, #points)
        end
        self.HealerRouteIndex = currentIndex
        self.HealerRouteStatus = string.format("Recorded route active • point %d/%d toward host", currentIndex, #points)
        return routeVector(points[currentIndex])
    end

    function UIWController:GetRecordedProgressGoal()
        if not self.HealerUseRecordedPath or not self.Character:IsAlive() then return nil end
        local key = self:GetHealerRouteKey()
        if self.RecordedRouteCompleteKey == key then return nil end
        local points = self:GetRecordedHealerRoute()
        if not points or #points < 2 then
            self.HealerRouteStatus = "Recorded route enabled • no route saved for "
                .. self:GetHealerRouteName()
            return nil
        end

        local position = self.Character.Root.Position
        local index = tonumber(self.HealerRouteIndex)
        local point = index and routeVector(points[index])
        if not point or (point - position).Magnitude > ROUTE_RESYNC_DISTANCE then
            local nearestIndex, nearestDistance = 1, math.huge
            local firstCandidate = index and math.max(1, index) or 1
            local lastCandidate = index and math.min(#points, index + 80) or #points
            for candidateIndex = firstCandidate, lastCandidate do
                local candidate = points[candidateIndex]
                local vector = routeVector(candidate)
                if vector then
                    local distance = (vector - position).Magnitude
                    if distance < nearestDistance then
                        nearestIndex, nearestDistance = candidateIndex, distance
                    end
                end
            end
            index = nearestIndex
            point = routeVector(points[index])
        end

        if point and (point - position).Magnitude <= ROUTE_REACH_DISTANCE then
            if index >= #points then
                self.RecordedRouteCompleteKey = key
                self.HealerRouteStatus = "Recorded " .. self:GetHealerRouteName()
                    .. " route completed"
                return nil
            end
            index += 1
            point = routeVector(points[index])
        end

        self.HealerRouteIndex = index
        self.HealerRouteStatus = string.format("Auto route active • %s • point %d/%d",
            self:GetHealerRouteName(), index, #points)
        return point
    end

    function UIWController:UpdateHealerNavigation(goal)
        if not goal then return end
        local previous = self.HealerNavigationGoal
        if not previous or flatten(goal - previous).Magnitude >= 5
            or math.abs(goal.Y - previous.Y) >= 2.5
        then
            self.HealerNavigationGoal = goal
            self.Route:InvalidateGoal()
        end
    end

    function UIWController:EquipHealerLoadout()
        if not self.HealerEnabled or not self.HealerAutoEquip or self.HealerEquipBusy then return end
        self.HealerEquipBusy = true
        task.spawn(function()
            local ok, message = pcall(function()
                local scripts = LocalPlayer:FindFirstChild("PlayerScripts")
                local ui = scripts and scripts:FindFirstChild("Ui")
                local inventoryScript = ui and ui:FindFirstChild("inventory")
                if not inventoryScript then return "inventory is loading" end
                local inventoryModule = require(inventoryScript)
                local inventory = inventoryModule.GetPlayerInvy()
                if type(inventory) ~= "table" then return "inventory is loading" end

                local stats = LocalPlayer:FindFirstChild("leaderstats")
                local levelValue = stats and stats:FindFirstChild("Level")
                local level = tonumber(levelValue and levelValue.Value) or 1
                local equipped = {}

                local chestKey, chest = bestSpellPower(inventory.chests, level)
                local helmetKey, helmet = bestSpellPower(inventory.helmets, level)
                if chestKey and not isEquipped(chest) then
                    Remotes.equipItem:InvokeServer("chest", itemNumber(chestKey))
                end
                if helmetKey and not isEquipped(helmet) then
                    Remotes.equipItem:InvokeServer("helmet", itemNumber(helmetKey))
                end
                if chest then table.insert(equipped, tostring(chest.name)) end
                if helmet then table.insert(equipped, tostring(helmet.name)) end

                local abilities = healingAbilities(inventory.abilities, level)
                for index = 1, math.min(2, #abilities) do
                    local chosen = abilities[index]
                    local slot = index == 1 and "q" or "e"
                    local slotEquipped = type(chosen.Item.equipped) == "table"
                        and chosen.Item.equipped[slot] == true
                    if not slotEquipped then
                        Remotes.equipItem:InvokeServer("ability", itemNumber(chosen.Key), slot)
                    end
                    table.insert(equipped, tostring(chosen.Item.name))
                end
                if #abilities == 0 then table.insert(equipped, "no owned healing spell") end
                return table.concat(equipped, " | ")
            end)
            self.HealerEquipBusy = false
            self.HealerLoadout = ok and message or ("equip error: " .. tostring(message))
        end)
    end

    function UIWController:HealerCast(targetHumanoid, distance)
        local healerHumanoid = self.Character and self.Character.Humanoid
        local targetMissingHealth = targetHumanoid and targetHumanoid.MaxHealth > 0
            and targetHumanoid.Health + 1 < targetHumanoid.MaxHealth
        local healerMissingHealth = healerHumanoid and healerHumanoid.MaxHealth > 0
            and healerHumanoid.Health > 0
            and healerHumanoid.Health + 1 < healerHumanoid.MaxHealth
        if not targetMissingHealth and not healerMissingHealth then
            return false
        end

        local targetPercent = targetHumanoid and targetHumanoid.MaxHealth > 0
            and targetHumanoid.Health / targetHumanoid.MaxHealth * 100 or 100
        local healerPercent = healerHumanoid and healerHumanoid.MaxHealth > 0
            and healerHumanoid.Health / healerHumanoid.MaxHealth * 100 or 100
        local lowestPercent = math.min(targetMissingHealth and targetPercent or 100,
            healerMissingHealth and healerPercent or 100)
        local now = os.clock()
        local minimumGap = lowestPercent <= 50 and 0.9 or 1.25
        if now - (self.HealerLastCastAt or 0) < minimumGap then return false end
        if lowestPercent > 50 and now < (self.HealerHealCoveredUntil or 0) then return false end

        local ready = {}
        for _, container in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
            if container then
                for _, tool in ipairs(container:GetChildren()) do
                    local spellName = tool:IsA("Tool") and normalized(tool.Name)
                    local score = spellName and HEAL_SCORE[spellName]
                    local cooldown = tool:FindFirstChild("cooldown")
                    local event = tool:FindFirstChild("localEvent")
                    -- A wounded healer may use a local spell for themselves.
                    -- A wounded host still requires the spell to reach them.
                    local reachesTarget = targetMissingHealth
                        and distance <= (HEAL_RANGE[spellName] or 0)
                    local inRange = healerMissingHealth or reachesTarget
                    if score and inRange and event
                        and (not cooldown or (tonumber(cooldown.Value) or 0) <= 0)
                    then
                        table.insert(ready, { Tool = tool, Event = event, Score = score })
                    end
                end
            end
        end
        table.sort(ready, function(a, b) return a.Score > b.Score end)
        local chosen = ready[1]
        if not chosen then return false end

        self.HealerLastCastAt = now
        local ok = pcall(function() chosen.Event:Fire() end)
        if ok then
            self.HealerLastSpell = chosen.Tool.Name
            self.HealerHealCoveredUntil = now + (HEAL_COVERAGE[normalized(chosen.Tool.Name)] or 2)
            local healingName = cleanName(self.HealerTargetName)
                or cleanName(self.CarryHostName) or "target"
            self.HealerStatus = string.format("Healing %s with %s | host %.0f%% • healer %.0f%% | %.0f studs",
                healingName, chosen.Tool.Name,
                targetPercent, healerPercent, distance or 0)
        end
        return ok
    end

    function UIWController:HealerNavigationRecovery(targetRoot, distance)
        if not targetRoot or not self.Character:IsAlive()
            or distance <= (tonumber(self.HealerFollowDistance) or 14)
        then
            self.HealerProgressPosition = self.Character.Root and self.Character.Root.Position or nil
            self.HealerProgressAt = os.clock()
            return
        end

        local now = os.clock()
        local position = self.Character.Root.Position
        local goal = self.HealerNavigationGoal or targetRoot.Position
        local delta = goal - position
        local horizontal = flatten(delta).Magnitude
        local humanoid = self.Character.Humanoid

        -- Give climbing and short upward transitions an early jump instead of
        -- waiting for the generic stuck detector to complete its full cycle.
        if delta.Y >= 2 and horizontal <= 11 and humanoid
            and humanoid.FloorMaterial ~= Enum.Material.Air
            and now - (self.HealerLastClimbJumpAt or 0) >= 0.7
        then
            self.HealerLastClimbJumpAt = now
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        if not self.HealerProgressPosition then
            self.HealerProgressPosition = position
            self.HealerProgressAt = now
            return
        end
        if (position - self.HealerProgressPosition).Magnitude >= 2 then
            self.HealerProgressPosition = position
            self.HealerProgressAt = now
            return
        end
        if now - (self.HealerProgressAt or now) >= 1.25
            and now - (self.HealerLastForcedRepathAt or 0) >= 1.25
        then
            self.HealerLastForcedRepathAt = now
            self.HealerProgressAt = now
            self.Route:ClearPath()
            self.Route:ForceRepath(goal)
            if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            self.HealerRouteStatus = "Live pathfinder repathing around an obstacle"
        end
    end

    function UIWController:HealerUpdate()
        if not self.HealerEnabled or self.Destroyed then return end
        local target, _, humanoid, root, requested = self:GetHealerTarget()
        if not target then
            local fallback = cleanName(self.HealerTargetName) or cleanName(self.CarryHostName)
            self.HealerStatus = fallback
                and ("Waiting for " .. fallback)
                or "Enter a player or configure a Carry host"
            return
        end
        local distance = (root.Position - self.Character.Root.Position).Magnitude
        self:HealerNavigationRecovery(root, distance)
        local health = humanoid.Health / math.max(humanoid.MaxHealth, 1) * 100
        local healerHumanoid = self.Character and self.Character.Humanoid
        local healerHealth = healerHumanoid and healerHumanoid.MaxHealth > 0
            and healerHumanoid.Health / healerHumanoid.MaxHealth * 100 or 0
        if not self:HealerCast(humanoid, distance) then
            self.HealerStatus = string.format("Following %s | host %.0f%% • healer %.0f%% | %.0f studs",
                requested or target.Name, health, healerHealth, distance)
        end
    end

    local oldGetGoal = UIWController.GetGoal
    function UIWController:GetGoal()
        if self.HealerEnabled then
            local mechanicGoal = self:GetPriorityMechanicGoal()
            if mechanicGoal then return oldGetGoal(self) end
            local _, _, _, root = self:GetHealerTarget()
            if not root then return nil end
            local distance = (root.Position - self.Character.Root.Position).Magnitude
            if distance > (tonumber(self.HealerFollowDistance) or 14) then
                local goal = self:GetHealerRecordedGoal(root.Position) or root.Position
                self:UpdateHealerNavigation(goal)
                return goal
            end
            return nil
        end
        if self.HealerUseRecordedPath then
            local mechanicGoal = self:GetPriorityMechanicGoal()
            if mechanicGoal then return oldGetGoal(self) end
            local enemy = self.CurrentEnemy
            local enemyDistance = enemy and enemy.Root and enemy.Root.Parent
                and (enemy.Root.Position - self.Character.Root.Position).Magnitude or math.huge
            if enemyDistance > ROUTE_COMBAT_PAUSE_DISTANCE then
                local routeGoal = self:GetRecordedProgressGoal()
                if routeGoal then
                    self:UpdateHealerNavigation(routeGoal)
                    return routeGoal
                end
            else
                self.HealerRouteStatus = string.format("Auto route paused for combat • %.0f studs", enemyDistance)
            end
        end
        return oldGetGoal(self)
    end

    local oldGetTargetYaw = UIWController.GetTargetYaw
    function UIWController:GetTargetYaw()
        if self.HealerEnabled then
            local _, _, _, root = self:GetHealerTarget()
            if root and self.Character.Root then
                local direction = flatten(root.Position - self.Character.Root.Position)
                if direction.Magnitude > 0.05 then return directionToYaw(direction) end
            end
        end
        return oldGetTargetYaw(self)
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        if self.HealerRecording then
            self.Character:ReleaseAutomationFacing()
            return
        end
        if not self.HealerEnabled then
            if not self.HealerUseRecordedPath then return oldStep(self) end
            local dodge = self.AutoDodge
            self.AutoDodge = true
            local ok, err = pcall(oldStep, self)
            self.AutoDodge = dodge
            if not ok then error(err) end
            return
        end
        local combat, dodge = self.AutoCombat, self.AutoDodge
        local use3DGoalDistance = self.Route.Use3DGoalDistance
        self.AutoCombat = false
        self.AutoDodge = true
        self.Route.Use3DGoalDistance = true
        local ok, err = pcall(oldStep, self)
        self.AutoCombat = combat
        self.AutoDodge = dodge
        self.Route.Use3DGoalDistance = use3DGoalDistance
        if not ok then error(err) end
        if self.Enabled and self.Character:IsAlive() then self:HealerUpdate() end
    end

    function UIWController:StartHealer()
        self:LoadHealerRoutes()
        local savedRoute = self:GetRecordedHealerRoute()
        self.HealerRouteStatus = savedRoute
            and string.format("Saved %s route: %d points", self:GetHealerRouteName(), #savedRoute)
            or ("No recorded route for " .. self:GetHealerRouteName())
        if self.HealerEnabled then
            self.AutoDodge = true
        end
        self.HealerStatus = self.HealerEnabled and "Starting healer" or "Healer off"
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if self.HealerRecording and now - (self.HealerLastRecordSampleAt or 0) >= 0.15 then
                self.HealerLastRecordSampleAt = now
                self:SampleHealerRoute(false)
                if healerDungeonFinished() then
                    self:StopHealerRouteRecording(true)
                end
            end
            if now - (self.HealerHUDAt or 0) >= 0.5 then
                self.HealerHUDAt = now
                if self.HUD and self.HUD.RefreshHealer then self.HUD:RefreshHealer() end
            end
            if not self.HealerEnabled then return end
            if self.HealerAutoEquip and now - (self.HealerLastEquipAt or 0) >= 12 then
                self.HealerLastEquipAt = now
                self:EquipHealerLoadout()
            end
        end))
    end

    local oldStart = UIWController.Start
    function UIWController:Start()
        oldStart(self)
        self:StartHealer()
    end
end
