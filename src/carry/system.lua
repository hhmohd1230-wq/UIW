-- Carry progression. The host chooses the highest stage available to the
-- lowest listed alt; everyone else follows and joins the host's private party.
do
    local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("remotes")

    local function sameName(a, b)
        return type(a) == "string" and type(b) == "string"
            and string.lower(a) == string.lower(b)
    end

    local function cleanName(name)
        return string.match(tostring(name or ""), "^%s*([%w_]+)%s*$")
    end

    local function altNames(raw)
        local names, seen = {}, {}
        for value in string.gmatch(tostring(raw or ""), "[^,%s;]+") do
            local name = cleanName(value)
            if name and not seen[string.lower(name)] then
                seen[string.lower(name)] = true
                table.insert(names, name)
            end
        end
        return names
    end

    local function playerNamed(name)
        for _, player in ipairs(Players:GetPlayers()) do
            if sameName(player.Name, name) then return player end
        end
    end

    local function playerLevel(player)
        local loaded = player and player:FindFirstChild("dataLoaded")
        if not loaded or loaded.Value ~= true then return nil end
        local stats = player and player:FindFirstChild("leaderstats")
        local level = stats and stats:FindFirstChild("Level")
        return level and tonumber(level.Value)
    end

    local function stageForLevel(level)
        local choice = 1
        for index, stage in ipairs(CARRY_STAGES) do
            if level >= stage.Level then choice = index else break end
        end
        return choice
    end

    local function stageForParty(party)
        local map = party and party:FindFirstChild("mapName")
        local diff = map and map:FindFirstChild("difficulty")
        if not map or not diff then return nil end
        for index, stage in ipairs(CARRY_STAGES) do
            if stage.Name == map.Value and stage.Difficulty == diff.Value then
                return index
            end
        end
    end

    local function inLobby()
        local name = Workspace:FindFirstChild("dungeonName")
        return name and name.Value == "" and Workspace:FindFirstChild("games") ~= nil
    end

    local function ownParty()
        local games = Workspace:FindFirstChild("games")
        local lobbies = games and games:FindFirstChild("inLobby")
        if not lobbies then return nil end
        for _, party in ipairs(lobbies:GetChildren()) do
            if party:FindFirstChild(LocalPlayer.Name) then return party end
        end
    end

    local function hostParty(hostName)
        local games = Workspace:FindFirstChild("games")
        local lobbies = games and games:FindFirstChild("inLobby")
        if not lobbies then return nil end
        for _, party in ipairs(lobbies:GetChildren()) do
            if party:FindFirstChild(hostName)
                and (sameName(party.Name, hostName)
                    or string.sub(string.lower(party.Name), 1, #hostName + 1)
                        == string.lower(hostName) .. "_")
            then
                return party
            end
        end
    end

    local function dungeonFinished()
        local dungeon = Workspace:FindFirstChild("dungeon")
        local bossRoom = dungeon and dungeon:FindFirstChild("bossRoom")
        local flag = bossRoom and bossRoom:FindFirstChild("dungeonFinished")
        return (flag and flag.Value == true)
            or (dungeon and dungeon:GetAttribute("dungeonFinished") == true)
    end

    function UIWController:CarryRewardReady()
        return self.CarryRewardAt ~= nil
            and os.clock() - self.CarryRewardAt >= 1
    end

    local function pressPlay()
        local intro = LocalPlayer:FindFirstChild("PlayerGui")
        intro = intro and intro:FindFirstChild("introGui")
        local title = intro and intro:FindFirstChild("title")
        local frame = title and title:FindFirstChild("Frame")
        local button = frame and frame:FindFirstChild("TextButton")
        if not button or not frame.Visible then return false end
        if type(firesignal) == "function" then
            pcall(firesignal, button.Activated)
        else
            local center = button.AbsolutePosition + button.AbsoluteSize * 0.5
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
            end)
        end
        return true
    end

    function UIWController:CarryMembers()
        local host = cleanName(self.CarryHostName)
        local alts = altNames(self.CarryAlts)
        local filtered = {}
        for _, name in ipairs(alts) do
            if not sameName(name, host) then table.insert(filtered, name) end
        end
        return host, filtered
    end

    function UIWController:CarryTarget()
        if os.clock() < (self.CarryLevelReadyAt or 0) then
            return nil, "Waiting for player levels to load"
        end
        local host, alts = self:CarryMembers()
        if not host or #alts == 0 then return nil, "Set a host and at least one alt" end
        local hostPlayer = playerNamed(host)
        local hostLevel = playerLevel(hostPlayer)
        if not hostLevel then return nil, "Waiting for host " .. host end
        local lowest = math.huge
        for _, name in ipairs(alts) do
            local level = playerLevel(playerNamed(name))
            if not level then return nil, "Waiting for alt " .. name end
            if level > hostLevel then return nil, name .. " is higher level than the host" end
            lowest = math.min(lowest, level)
        end
        local index = self.CarryMode == "Fixed"
            and math.floor(math.clamp(tonumber(self.CarryFixedStage) or 1, 1, #CARRY_STAGES))
            or stageForLevel(lowest)
        local stage = CARRY_STAGES[index]
        if hostLevel < stage.Level then return nil, "Host needs level " .. stage.Level end
        if lowest < stage.Level then return nil, "Lowest alt needs level " .. stage.Level end
        return index, nil, lowest
    end

    function UIWController:CarryNeedsLobby()
        if not self.CarryEnabled then return false end
        local host, alts = self:CarryMembers()
        if not playerNamed(host) then return true end
        for _, name in ipairs(alts) do
            if not playerNamed(name) then return true end
        end
        local index = self:CarryTarget()
        if not index then return false end
        local runStage = tonumber(self.CarryRunStage)
        if runStage and runStage ~= index then return true end
        if not runStage then
            local name = Workspace:FindFirstChild("dungeonName")
            if name and name.Value ~= "" and name.Value ~= CARRY_STAGES[index].Name then
                return true
            end
        end
        if self.CarryMode == "Fixed" then
            local name = Workspace:FindFirstChild("dungeonName")
            return name and name.Value ~= "" and name.Value ~= CARRY_STAGES[index].Name
        end
        return false
    end

    function UIWController:SetCarryOption(key, value)
        if key == "CarryHostName" then
            self.CarryHostName = cleanName(value) or ""
        elseif key == "CarryAlts" then
            self.CarryAlts = string.sub(tostring(value or ""), 1, 10000)
        elseif key == "CarryMode" then
            self.CarryMode = value == "Fixed" and "Fixed" or "Auto"
        elseif key == "CarryFixedStage" then
            self.CarryFixedStage = math.floor(math.clamp(tonumber(value) or 1, 1, #CARRY_STAGES))
        elseif key == "CarryHardcore" then
            self.CarryHardcore = value == true
        elseif key == "CarryEnabled" then
            self.CarryEnabled = value == true
            self.CarryLastActionAt = 0
        else
            return
        end
        self:WriteMeta()
        if self.CarryEnabled then self:ConfigureAutoExecute() end
        if self.HUD then self.HUD:RefreshControls() end
    end

    function UIWController:SetCarryRunStage(index)
        if self.CarryRunStage == index then return end
        self.CarryRunStage = index
        self:WriteMeta()
    end

    function UIWController:CarryHostLobby(host, alts, index, lowest)
        local stage = CARRY_STAGES[index]
        local party = hostParty(host)
        local mine = ownParty()
        if mine and mine ~= party then
            self.CarryStatus = "Leaving another party"
            if os.clock() - (self.CarryLastActionAt or 0) > 5 then
                self.CarryLastActionAt = os.clock()
                Remotes.leaveGame:FireServer()
            end
            return
        end
        if party and stageForParty(party) ~= index then
            self.CarryStatus = "Switching to " .. stage.Name .. " " .. stage.Difficulty
            if os.clock() - (self.CarryLastActionAt or 0) > 5 then
                self.CarryLastActionAt = os.clock()
                Remotes.leaveGame:FireServer()
            end
            return
        end
        if not party then
            self.CarryStatus = "Creating " .. stage.Name .. " " .. stage.Difficulty
            if self.CarryBusy or os.clock() - (self.CarryLastActionAt or 0) < 8 then return end
            self.CarryBusy = true
            self.CarryLastActionAt = os.clock()
            task.spawn(function()
                local ok, result = pcall(function()
                    return Remotes.createLobby:InvokeServer(
                        stage.Name, stage.Difficulty, stage.Level,
                        self.CarryHardcore == true, true, false
                    )
                end)
                self.CarryBusy = false
                if not ok or result ~= true then
                    self.CarryStatus = "Create failed; retrying"
                end
            end)
            return
        end

        self:SetCarryRunStage(index)
        local private = party.mapName and party.mapName:FindFirstChild("private")
        for _, name in ipairs(alts) do
            local player = playerNamed(name)
            local actualName = player and player.Name or name
            if private and private.Value and not private:FindFirstChild(actualName) then
                Remotes.addPlayerToWhitelist:FireServer(actualName)
            end
            if not party:FindFirstChild(actualName) then
                self.CarryStatus = "Waiting for " .. actualName .. " to join"
                return
            end
        end
        self.CarryStatus = string.format("Starting %s %s | lowest level %d", stage.Name, stage.Difficulty, lowest)
        if os.clock() - (self.CarryLastActionAt or 0) > 12 then
            self.CarryLastActionAt = os.clock()
            Remotes.startDungeon:FireServer()
        end
    end

    function UIWController:CarryAltLobby(host)
        local hostPlayer = playerNamed(host)
        if not hostPlayer then
            self.CarryStatus = "Following " .. host .. " to his lobby"
            if os.clock() - (self.CarryLastActionAt or 0) < 15 then return end
            self.CarryLastActionAt = os.clock()
            if not self.CarryHostUserId then
                task.spawn(function()
                    local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(host) end)
                    if ok then self.CarryHostUserId = id end
                end)
            else
                Remotes.teleportToFriend:FireServer(self.CarryHostUserId)
            end
            return
        end
        self.CarryHostUserId = hostPlayer.UserId
        local party = hostParty(hostPlayer.Name)
        if not party then
            self.CarryStatus = "Waiting for " .. host .. " to create a party"
            return
        end
        local mine = ownParty()
        if mine == party then
            local index = stageForParty(party)
            if index then self:SetCarryRunStage(index) end
            self.CarryStatus = "In " .. host .. "'s party; waiting for everyone"
            return
        end
        if mine then
            self.CarryStatus = "Leaving another party"
            if os.clock() - (self.CarryLastActionAt or 0) > 5 then
                self.CarryLastActionAt = os.clock()
                Remotes.leaveGame:FireServer()
            end
            return
        end
        local private = party.mapName and party.mapName:FindFirstChild("private")
        if private and private.Value and not private:FindFirstChild(LocalPlayer.Name) then
            self.CarryStatus = "Waiting for host whitelist"
            return
        end
        self.CarryStatus = "Joining " .. host .. "'s party"
        if self.CarryBusy or os.clock() - (self.CarryLastActionAt or 0) < 5 then return end
        self.CarryBusy = true
        self.CarryLastActionAt = os.clock()
        task.spawn(function()
            local ok, result = pcall(function()
                return Remotes.joinDungeon:InvokeServer(party.Name)
            end)
            self.CarryBusy = false
            if ok and result == true then
                local index = stageForParty(party)
                if index then self:SetCarryRunStage(index) end
            else
                self.CarryStatus = "Join failed; retrying"
            end
        end)
    end

    function UIWController:CarryStep()
        if not self.CarryEnabled or self.Destroyed then return end
        local host, alts = self:CarryMembers()
        if not host or #alts == 0 then
            self.CarryStatus = "Enter the host and alt usernames"
            return
        end
        local isHost = sameName(LocalPlayer.Name, host)
        if not isHost then
            local listed = false
            for _, name in ipairs(alts) do
                if sameName(LocalPlayer.Name, name) then listed = true break end
            end
            if not listed then
                self.CarryStatus = "This account is not listed in the carry group"
                return
            end
        end

        if inLobby() then
            if pressPlay() then
                self.CarryStatus = "Skipping lobby intro"
                return
            end
            local intro = LocalPlayer.PlayerGui:FindFirstChild("introGui")
            if intro then
                self.CarryStatus = "Waiting for Play button"
                return
            end
            if isHost then
                local index, reason, lowest = self:CarryTarget()
                if not index then self.CarryStatus = reason return end
                self:CarryHostLobby(playerNamed(host).Name, alts, index, lowest)
            else
                self:CarryAltLobby(host)
            end
            return
        end

        local dungeonName = Workspace:FindFirstChild("dungeonName")
        if not dungeonName or dungeonName.Value == "" then
            self.CarryStatus = "Waiting for lobby or dungeon"
            return
        end
        if not isHost and not playerNamed(host) and dungeonFinished() and self:CarryRewardReady() then
            self.CarryHostMissingAt = self.CarryHostMissingAt or os.clock()
            local waited = os.clock() - self.CarryHostMissingAt
            self.CarryStatus = string.format("Host is teleporting; waiting for party retry (%.0fs)",
                math.max(0, 18 - waited))
            if waited >= 18 and os.clock() - (self.CarryLastActionAt or 0) > 10 then
                -- The host used Return to Lobby for a newly unlocked stage, or
                -- this alt missed the party teleport. Rejoin only after giving
                -- the native Retry ample time to carry the whole party.
                self.CarryLastActionAt = os.clock()
                Remotes.ReturnToLobbyEvent:FireServer()
            end
            return
        end
        self.CarryHostMissingAt = nil
        local index, reason, lowest = self:CarryTarget()
        local stage = index and CARRY_STAGES[index]
        local runStage = tonumber(self.CarryRunStage)
        local stageChanged = index and runStage and index ~= runStage
        if dungeonFinished() and self:CarryRewardReady() and stageChanged then
            if isHost then
                self.CarryStatus = stage
                    and ("Level reached; returning for " .. stage.Name .. " " .. stage.Difficulty)
                    or "Level reached; returning to lobby"
                if os.clock() - (self.CarryLastActionAt or 0) > 10 then
                    self.CarryLastActionAt = os.clock()
                    Remotes.ReturnToLobbyEvent:FireServer()
                end
            else
                self.CarryStatus = "Reward claimed; host controls the next stage"
            end
            return
        end
        if not index then
            self.CarryStatus = reason
            return
        end
        local nextStage = CARRY_STAGES[index + 1]
        if dungeonFinished() and self:CarryRewardReady() then
            self.CarryStatus = string.format("Reward claimed; retrying %s %s | lowest %d%s",
                stage.Name, stage.Difficulty, lowest,
                nextStage and (" -> " .. nextStage.Level) or " | latest dungeon")
        else
            self.CarryStatus = string.format("%s %s | lowest %d%s", stage.Name, stage.Difficulty,
                lowest, nextStage and (" -> " .. nextStage.Level) or " | latest dungeon")
        end
    end

    function UIWController:StartCarry()
        self.CarryStatus = self.CarryEnabled and "Starting carry" or "Carry off"
        self.CarryLevelReadyAt = os.clock() + 6
        self.CarryRewardAt = nil
        local rewardRemote = Remotes:FindFirstChild("cloneRewardGui")
        if rewardRemote then
            self.Maid:Give(rewardRemote.OnClientEvent:Connect(function()
                self.CarryRewardAt = os.clock()
            end))
        end
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            if os.clock() - (self.CarryCheckAt or 0) < 1 then return end
            self.CarryCheckAt = os.clock()
            local ok, err = pcall(self.CarryStep, self)
            if not ok then self.CarryStatus = "Carry error: " .. tostring(err) end
            if self.HUD and self.HUD.RefreshCarry then self.HUD:RefreshCarry() end
        end))
    end

    local oldStart = UIWController.Start
    function UIWController:Start()
        oldStart(self)
        self:StartCarry()
    end
end
