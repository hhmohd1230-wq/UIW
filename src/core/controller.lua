local UIWController = {}
UIWController.__index = UIWController

function UIWController.new()
    local self = setmetatable({}, UIWController)

    self.Maid = Maid.new()
    self.Character = CharacterService.new()
    self.Dungeon = DungeonModel.new()
    self.SelfAbilities = SelfAbilityTracker.new()
    self.Hazards = HazardTracker.new(self.Character, self.SelfAbilities)
    self.Hazards.Dungeon = self.Dungeon
    self.Geometry = GeometrySensor.new(self.Character)
    self.Route = RoutePlanner.new(self.Character, self.Geometry, self.Hazards, self.Dungeon)
    self.Dodger = DodgeSolver.new(self.Character, self.Hazards, self.Geometry, self.Dungeon)
    self.Combat = CombatController.new(self.Character, self.SelfAbilities)
    self.ESP = HitboxESP.new(self.Hazards)
    self.PathESP = PathESP.new()
    self.TargetHealth = TargetHealthBar.new()

    self.Enabled = true
    self.AutoDodge = true
    self.AutoCombat = true
    self.AutoESP = true
    self.AutoPathESP = true
    self.AutoRetryEnabled = true
    self.ShowAura = true
    self.ShowMobGroups = true
    self.AutoExecuteOnTeleport = false
    self.ActiveConfig = nil
    self.AutoLoadConfig = ""

    self:InitConfigs()

    self.HUD = HUD.new(self)

    self.TacticalDisplay = TacticalDisplay.new(
        self.Character,
        self.Hazards,
        self.Geometry,
        self.Dungeon,
        self.Dodger
    )

    self.CurrentEnemy = nil
    self.CurrentEnemyModel = nil
    self.CurrentEnemyDeathConnection = nil
    self.LastWorldRefresh = 0
    self.LastProgressPosition = nil
    self.LastProgressTime = 0
    self.LastNavigationAutoJump = 0
    self.LastCommandedMovement = Vector3.zero
    self.RecoveryDirection = Vector3.zero
    self.RecoveryUntil = 0
    self.RecoverySign = 1
    self.HardRecoveryActive = false

    -- Crystal Golem wall mechanic state.
    self.GolemRockStage = "pickup"
    self.GolemSupplyTarget = nil
    self.GolemBuildTarget = nil
    self.GolemPickupArrivedAt = 0
    self.GolemBuildArrivedAt = 0

    self.ProgressionOverridePart = nil
    self.ProgressionOverrideRoom = nil
    self.ProgressionOverrideTargetModel = nil
    self.ProgressionFrontierGoal = nil
    self.ProgressionFrontierTargetModel = nil
    self.CompletedProgressionCheckpoints = {}
    self.ProgressionFloorRoom = 1
    self.ProgressionProbeRetryAt = 0

    self.Destroyed = false

    return self
end

function UIWController:ApplySettings(settings)
    if type(settings) ~= "table" then return false end

    local function readBoolean(name, fallback)
        if type(settings[name]) == "boolean" then
            return settings[name]
        end
        return fallback
    end

    self.Enabled = readBoolean("Enabled", self.Enabled)
    self.AutoCombat = readBoolean("AutoCombat", self.AutoCombat)
    self.AutoDodge = readBoolean("AutoDodge", self.AutoDodge)
    self.AutoESP = readBoolean("AutoESP", self.AutoESP)
    self.AutoPathESP = readBoolean("AutoPathESP", self.AutoPathESP)
    self.AutoRetryEnabled = readBoolean("AutoRetryEnabled", self.AutoRetryEnabled)
    self.ShowAura = readBoolean("ShowAura", self.ShowAura)
    self.ShowMobGroups = readBoolean("ShowMobGroups", self.ShowMobGroups)

    CONFIG.WalkSpeed = validNumber(settings.WalkSpeed, 12, 40, CONFIG.WalkSpeed)
    CONFIG.DesiredCombatRange = validNumber(settings.DesiredCombatRange, 24, 60, CONFIG.DesiredCombatRange)
    CONFIG.DamageCastRange = validNumber(settings.DamageCastRange, 30, 80, CONFIG.DamageCastRange)

    local humanoid = self.Character and self.Character.Humanoid
    if humanoid and humanoid.WalkSpeed < CONFIG.WalkSpeed then
        humanoid.WalkSpeed = CONFIG.WalkSpeed
    end

    if not self.Enabled and self.Character and self.Dodger then
        pcall(function()
            self.Character:ReleaseAutomationFacing()
            self.Dodger.CommittedDodgeDirection = Vector3.zero
            self.Dodger.DodgeCommitUntil = 0
        end)
    end

    if self.HUD then self.HUD:RefreshControls() end
    return true
end

function UIWController:GetSettings()
    return {
        Enabled = self.Enabled,
        AutoCombat = self.AutoCombat,
        AutoDodge = self.AutoDodge,
        AutoESP = self.AutoESP,
        AutoPathESP = self.AutoPathESP,
        AutoRetryEnabled = self.AutoRetryEnabled,
        ShowAura = self.ShowAura,
        ShowMobGroups = self.ShowMobGroups,
        WalkSpeed = CONFIG.WalkSpeed,
        DesiredCombatRange = CONFIG.DesiredCombatRange,
        DamageCastRange = CONFIG.DamageCastRange,
    }
end

---------------------------------------------------------------------------
-- Configs
---------------------------------------------------------------------------
function UIWController:Notify(text, kind)
    if self.HUD and self.HUD.Notify then
        self.HUD:Notify(text, kind)
    end
end

function UIWController:WriteMeta()
    local meta = ConfigStore.ReadMeta()
    meta.AutoLoad = self.AutoLoadConfig or ""
    meta.AutoExecute = self.AutoExecuteOnTeleport == true
    meta.ScriptPath = self:GetScriptPath()
    return ConfigStore.WriteMeta(meta)
end

-- Where the script file lives in the executor workspace. A loader can set
-- getgenv().UIW_SCRIPT_PATH before running the script to change it.
function UIWController:GetScriptPath()
    local custom = getgenv().UIW_SCRIPT_PATH
    if type(custom) == "string" and custom ~= "" then
        return custom
    end
    local meta = ConfigStore.ReadMeta()
    return meta.ScriptPath or ConfigStore.DefaultScriptPath
end

function UIWController:InitConfigs()
    pcall(ConfigStore.Migrate)
    local meta = ConfigStore.ReadMeta()
    self.AutoExecuteOnTeleport = meta.AutoExecute
    self.AutoLoadConfig = meta.AutoLoad
    if meta.AutoLoad ~= "" then
        local data = ConfigStore.Load(meta.AutoLoad)
        if data then
            self:ApplySettings(data)
            self.ActiveConfig = meta.AutoLoad
            self.StartupNotice = "Auto loaded config \"" .. meta.AutoLoad .. "\""
        else
            -- the auto-load config was removed outside the script
            self.AutoLoadConfig = ""
            self:WriteMeta()
        end
    end
end

function UIWController:ListConfigs()
    return ConfigStore.List()
end

function UIWController:SaveConfig(name)
    name = ConfigStore.CleanName(name) or self.ActiveConfig or "default"
    local ok, message = ConfigStore.Save(name, self:GetSettings())
    if ok then
        self.ActiveConfig = name
    end
    self:Notify(message, ok and "success" or "error")
    if self.HUD then self.HUD:RefreshConfigs() end
    return ok
end

function UIWController:LoadConfig(name)
    local data, message = ConfigStore.Load(name)
    local ok = data ~= nil and self:ApplySettings(data)
    if ok then
        self.ActiveConfig = name
    end
    self:Notify(ok and ("Loaded config \"" .. name .. "\"") or message, ok and "success" or "error")
    if self.HUD then self.HUD:RefreshConfigs() end
    return ok
end

-- Deleting the config in use puts everything back to the defaults,
-- including Auto Load and Auto Execute.
function UIWController:DeleteConfig(name)
    local ok, message = ConfigStore.Delete(name)
    if not ok then
        self:Notify(message, "error")
        return false
    end
    local wasActive = name == self.ActiveConfig or name == self.AutoLoadConfig
    if name == self.AutoLoadConfig then
        self.AutoLoadConfig = ""
    end
    if wasActive then
        self.ActiveConfig = nil
        self.AutoLoadConfig = ""
        self.AutoExecuteOnTeleport = false
        self:ApplySettings(DEFAULT_SETTINGS)
        message = message .. " - everything reset to defaults"
    end
    self:WriteMeta()
    self:Notify(message, "warning")
    if self.HUD then self.HUD:RefreshConfigs() end
    return true
end

function UIWController:SetAutoLoad(name)
    if name and name ~= "" and not ConfigStore.Exists(name) then
        self:Notify("Save the config first, then turn on Auto Load", "error")
        return false
    end
    self.AutoLoadConfig = name or ""
    local ok = self:WriteMeta()
    if not ok then
        self:Notify("Could not save the Auto Load choice", "error")
    elseif self.AutoLoadConfig ~= "" then
        self:Notify("\"" .. self.AutoLoadConfig .. "\" will load on every start", "success")
    else
        self:Notify("Auto Load off", "info")
    end
    if self.HUD then self.HUD:RefreshConfigs() end
    return ok
end

function UIWController:SetAutoExecute(value)
    self.AutoExecuteOnTeleport = value == true
    local ok = self:WriteMeta()
    if not ok then
        self:Notify("Could not save the Auto Execute choice", "error")
    elseif value then
        self:ConfigureAutoExecute(true)
    else
        self:Notify("Auto Execute off", "info")
    end
    if self.HUD then self.HUD:RefreshConfigs() end
    return ok
end

function UIWController:ResetSettings()
    self:ApplySettings(DEFAULT_SETTINGS)
    self:Notify("Switches and sliders reset to defaults (saved configs kept)", "info")
    if self.HUD then self.HUD:RefreshConfigs() end
end

-- Old names, kept for anything that still calls them.
function UIWController:SaveSettings()
    return self:SaveConfig(self.ActiveConfig or "default")
end

function UIWController:LoadSettings()
    if self.ActiveConfig then
        return self:LoadConfig(self.ActiveConfig)
    end
    return false
end

---------------------------------------------------------------------------
-- Auto execute: the executor runs this code once after the next teleport.
-- It re-reads uiw_meta.json at that moment, so turning the switch off later
-- still stops it, and it loads the script file named in the meta file.
---------------------------------------------------------------------------
local AUTO_EXECUTE_CODE = [==[
if getgenv().UIW_AUTOEXEC_STARTED then
    return -- queued more than once; the first copy does the work
end
getgenv().UIW_AUTOEXEC_STARTED = true
task.spawn(function()
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    local HttpService = game:GetService("HttpService")
    local function exists(path)
        local ok, result = pcall(isfile, path)
        return ok and result == true
    end
    local okMeta, meta = pcall(function()
        return HttpService:JSONDecode(readfile("UIW/uiw_meta.json"))
    end)
    if not okMeta or type(meta) ~= "table" or meta.AutoExecute ~= true then
        return
    end
    task.wait(1)
    local existing = getgenv().UIW
    if existing and not existing.Destroyed then
        return -- already running (executor auto-execute folder)
    end
    for _, path in ipairs({ meta.ScriptPath, "UIW/UIW.lua" }) do
        if type(path) == "string" and exists(path) then
            getgenv().UIW_SCRIPT_PATH = path
            local chunk, err = loadstring(readfile(path))
            if not chunk then
                warn("[UIW] Auto Execute: " .. tostring(err))
                return
            end
            local ok, runErr = pcall(chunk)
            if not ok then
                warn("[UIW] Auto Execute: " .. tostring(runErr))
            end
            return
        end
    end
    warn("[UIW] Auto Execute: script file not found (" .. tostring(meta.ScriptPath) .. ")")
end)
]==]

function UIWController:ConfigureAutoExecute(announce)
    if not self.AutoExecuteOnTeleport then
        return false
    end

    local path = self:GetScriptPath()
    if not SafeFile.IsFile(path) then
        self:Notify("Auto Execute needs the script saved at workspace/" .. path, "error")
        if self.HUD then self.HUD:SetRetryStatus("auto execute: " .. path .. " missing", COLORS.Emergency) end
        return false
    end

    if getgenv().UIW_AUTOEXEC_QUEUED == game.JobId then
        if announce then self:Notify("Auto Execute on - runs after every teleport", "success") end
        return true
    end

    local queueTeleport = (type(queue_on_teleport) == "function" and queue_on_teleport)
        or (type(queueonteleport) == "function" and queueonteleport)
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)

    if type(queueTeleport) ~= "function" then
        self:Notify("Your executor has no teleport queue", "error")
        return false
    end

    local ok, err = pcall(queueTeleport, AUTO_EXECUTE_CODE)
    if ok then
        getgenv().UIW_AUTOEXEC_QUEUED = game.JobId
        if announce then self:Notify("Auto Execute on - runs after every teleport", "success") end
    else
        self:Notify("Auto Execute failed: " .. tostring(err), "error")
    end
    return ok
end

function UIWController:RefreshWorld()
    self.Character:Refresh()
    self.Dungeon:Refresh()

    -- only raise the speed: never undo a speed buff (Inner Rage 16 -> 24)
    local humanoid = self.Character.Humanoid
    if humanoid and humanoid.WalkSpeed < CONFIG.WalkSpeed then
        humanoid.WalkSpeed = CONFIG.WalkSpeed
    end
end

function UIWController:ClearDeathConnection()
    if self.CurrentEnemyDeathConnection then
        pcall(function()
            self.CurrentEnemyDeathConnection:Disconnect()
        end)
        self.CurrentEnemyDeathConnection = nil
    end
end

function UIWController:ForceNextTarget()
    self:ClearDeathConnection()

    self.CurrentEnemy = nil
    self.CurrentEnemyModel = nil
    self.Dungeon.LastEnemyRefresh = 0

    self.Route:InvalidateGoal()

    local nextEnemy = self.Dungeon:GetNearestEnemy(self.Character.Root.Position)

    if nextEnemy then
        self:SetTarget(nextEnemy)
    end
end

function UIWController:SetTarget(enemy)
    local nextModel = enemy and enemy.Model or nil
    local targetChanged = nextModel ~= self.CurrentEnemyModel

    if targetChanged then
        self:ClearDeathConnection()
    end

    self.CurrentEnemy = enemy
    self.CurrentEnemyModel = nextModel

    self.TargetHealth:SetTarget(enemy)

    if targetChanged then
        self.ProgressionFrontierGoal = nil
        self.ProgressionFrontierTargetModel = nil

        self.Route:InvalidateGoal()

        if enemy and enemy.Humanoid then
            self.CurrentEnemyDeathConnection = enemy.Humanoid.Died:Connect(function()
                task.defer(function()
                    if self.Destroyed then
                        return
                    end
                    self:ForceNextTarget()
                end)
            end)
        end
    end
end

-- v43 target choice: not just "nearest". Prefer packs (more enemies per cast),
-- nearly dead enemies, and melee threats that are already close; deprioritise
-- enemies on another level. Keep the current target unless another is clearly better.
function UIWController:ScoreTarget(enemy, rootPosition, enemies)
    local offset = enemy.Root.Position - rootPosition
    local distance = flatten(offset).Magnitude
    local score = distance

    if not isBossEnemy(enemy) and math.abs(offset.Y) > CONFIG.EngageMaxHeightDiff then
        score += CONFIG.OtherLevelPenalty
    end

    local pack = 0
    for _, other in ipairs(enemies) do
        if other ~= enemy and other.Root and other.Root.Parent
            and (other.Root.Position - enemy.Root.Position).Magnitude <= CONFIG.PackRadius
        then
            pack += 1
        end
    end
    score -= math.min(pack, 4) * CONFIG.PackBonus

    local humanoid = enemy.Humanoid
    if humanoid and humanoid.MaxHealth > 0 then
        score -= (1 - humanoid.Health / humanoid.MaxHealth) * CONFIG.LowHealthBonus
    end

    if getEnemyThreatClass(enemy) and distance < 40 then
        score -= CONFIG.CloseThreatBonus
    end

    return score
end

function UIWController:SelectTarget()
    if not self.Character:IsAlive() then
        return nil
    end

    local rootPosition = self.Character.Root.Position
    -- keeps LastKnownRoom up to date for progression
    self.Dungeon:GetNearestEnemy(rootPosition)

    local enemies = self.Dungeon:GetAliveEnemies()
    local best, bestScore = nil, math.huge
    local current, currentScore = nil, math.huge

    for _, enemy in ipairs(enemies) do
        if enemy.Root and enemy.Root.Parent and enemy.Humanoid and enemy.Humanoid.Health > 0 then
            local score = self:ScoreTarget(enemy, rootPosition, enemies)
            if score < bestScore then
                best, bestScore = enemy, score
            end
            if enemy.Model == self.CurrentEnemyModel then
                current, currentScore = enemy, score
            end
        end
    end

    if current and best ~= current and bestScore > currentScore - CONFIG.TargetSwitchMargin then
        best = current
    end

    if best then
        if best.Model ~= self.CurrentEnemyModel then
            self:SetTarget(best)
        else
            self.CurrentEnemy = best
            self.TargetHealth:SetTarget(best)
        end
    elseif self.CurrentEnemy then
        self:SetTarget(nil)
    end

    return best
end

function UIWController:IsCrystalGolemFight()
    local enemy = self.CurrentEnemy

    if not enemy or not enemy.Model or not enemy.Model.Parent then
        return false
    end

    return normalizeEnemyName(enemy.Model.Name) == "crystal golem"
end

function UIWController:ResetCrystalGolemMechanicState()
    self.GolemRockStage = "pickup"
    self.GolemSupplyTarget = nil
    self.GolemBuildTarget = nil
    self.GolemPickupArrivedAt = 0
    self.GolemBuildArrivedAt = 0
end

function UIWController:GetCrystalGolemFallingCrystal()
    if not self.Character:IsAlive() then
        return nil
    end

    local root = self.Character.Root
    local bestPart = nil
    local bestDistance = math.huge

    for _, child in ipairs(Workspace:GetChildren()) do
        if string.lower(child.Name or "") == "firstbosscrystaldrop" then
            local candidate = child:IsA("BasePart") and child
                or child:FindFirstChildWhichIsA("BasePart", true)

            if candidate and candidate.Parent then
                local distance = flatten(candidate.Position - root.Position).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = candidate
                end
            end
        end
    end

    return bestPart
end

function UIWController:GetCrystalGolemCleanseBubble()
    if not self.Character:IsAlive() then
        return nil
    end

    local root = self.Character.Root
    local safeZones = Workspace:FindFirstChild("firstBossSafeZones")

    if not safeZones then
        return nil
    end

    local bestPart = nil
    local bestDistance = math.huge

    local function isActiveBubble(part)
        if not part or not part:IsA("BasePart") then
            return false
        end

        local light = part:FindFirstChildWhichIsA("PointLight", true)

        if light and light.Enabled then
            return true
        end

        return part.Transparency <= 0.25
            and part.Material == Enum.Material.ForceField
            and part.Color.G >= 0.65
            and part.Color.R <= 0.35
    end

    for _, child in ipairs(safeZones:GetChildren()) do
        if isActiveBubble(child) then
            local distance = flatten(child.Position - root.Position).Magnitude

            if distance < bestDistance then
                bestDistance = distance
                bestPart = child
            end
        end
    end

    return bestPart
end

function UIWController:GetCrystalGolemCleanseGoal()
    local fallingCrystal = self:GetCrystalGolemFallingCrystal()

    if not fallingCrystal then
        return nil, nil
    end

    local bubble = self:GetCrystalGolemCleanseBubble()

    if not bubble then
        return nil, nil
    end

    return bubble.Position, bubble
end

function UIWController:GetCrystalGolemBuiltWallCover()
    if not self:IsCrystalGolemFight() or not self.Character:IsAlive() then
        return nil, nil
    end

    local buildZones = Workspace:FindFirstChild("firstBossBuildZones")

    if not buildZones then
        return nil, nil
    end

    local root = self.Character.Root
    local bestSafeBox = nil
    local bestWall = nil
    local bestDistance = math.huge

    for _, wall in ipairs(buildZones:GetChildren()) do
        if wall:IsA("Model") and string.lower(wall.Name or "") == "wallmodel" then
            local built = wall:FindFirstChild("built")
            local safeBox = wall:FindFirstChild("safeBox", true)

            if built
                and built:IsA("BoolValue")
                and built.Value
                and safeBox
                and safeBox:IsA("BasePart")
            then
                local distance = flatten(safeBox.Position - root.Position).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestSafeBox = safeBox
                    bestWall = wall
                end
            end
        end
    end

    return bestSafeBox, bestWall
end

function UIWController:GetCrystalGolemSupplyTarget()
    if not self:IsCrystalGolemFight() or not self.Character:IsAlive() then
        return nil
    end

    local suppliesRoot = Workspace:FindFirstChild("firstBossSupplyModels")

    if not suppliesRoot then
        return nil
    end

    local root = self.Character.Root
    local bestPart = nil
    local bestDistance = math.huge

    for _, supplyModel in ipairs(suppliesRoot:GetChildren()) do
        if supplyModel:IsA("Model") and supplyModel:FindFirstChild("buildingSupplies", true) then
            local target = supplyModel:FindFirstChild("mainPart", true)
                or supplyModel:FindFirstChildWhichIsA("BasePart", true)

            if target and target:IsA("BasePart") and target.Parent then
                local distance = flatten(target.Position - root.Position).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = target
                end
            end
        end
    end

    return bestPart
end

function UIWController:GetCrystalGolemBuildTarget()
    if not self:IsCrystalGolemFight() or not self.Character:IsAlive() then
        return nil, nil
    end

    local buildZones = Workspace:FindFirstChild("firstBossBuildZones")

    if not buildZones then
        return nil, nil
    end

    local root = self.Character.Root
    local bestPart = nil
    local bestWall = nil
    local bestDistance = math.huge

    for _, wall in ipairs(buildZones:GetChildren()) do
        if wall:IsA("Model") and string.lower(wall.Name or "") == "wallmodel" then
            local built = wall:FindFirstChild("built")
            local beamPart = wall:FindFirstChild("beamPart", true)

            if built
                and built:IsA("BoolValue")
                and not built.Value
                and beamPart
                and beamPart:IsA("BasePart")
            then
                local distance = flatten(beamPart.Position - root.Position).Magnitude

                if distance < bestDistance then
                    bestDistance = distance
                    bestPart = beamPart
                    bestWall = wall
                end
            end
        end
    end

    return bestPart, bestWall
end

function UIWController:IsCrystalGolemRockWallPhaseActive()
    if not self:IsCrystalGolemFight() then
        return false
    end

    local supply = self:GetCrystalGolemSupplyTarget()
    local buildTarget = self:GetCrystalGolemBuildTarget()

    return supply ~= nil and buildTarget ~= nil
end

function UIWController:GetCrystalGolemRockWallGoal()
    if not self:IsCrystalGolemFight() or not self.Character:IsAlive() then
        self:ResetCrystalGolemMechanicState()
        return nil, nil, nil
    end

    local safeBox = self:GetCrystalGolemBuiltWallCover()

    if safeBox then
        self.GolemRockStage = "cover"
        return safeBox.Position, "CrystalGolemWallCover", safeBox
    end

    if not self:IsCrystalGolemRockWallPhaseActive() then
        self:ResetCrystalGolemMechanicState()
        return nil, nil, nil
    end

    local now = os.clock()

    if self.GolemRockStage ~= "place" then
        self.GolemRockStage = "pickup"
    end

    if self.GolemRockStage == "pickup" then
        local target = self.GolemSupplyTarget

        if not target or not target.Parent then
            target = self:GetCrystalGolemSupplyTarget()
            self.GolemSupplyTarget = target
            self.GolemPickupArrivedAt = 0
        end

        if not target then
            return nil, nil, nil
        end

        local distance = flatten(target.Position - self.Character.Root.Position).Magnitude

        if distance <= CONFIG.GolemRockPickupRadius then
            if self.GolemPickupArrivedAt <= 0 then
                self.GolemPickupArrivedAt = now
            elseif now - self.GolemPickupArrivedAt >= CONFIG.GolemRockPickupDwell then
                self.GolemRockStage = "place"
                self.GolemSupplyTarget = nil
                self.GolemPickupArrivedAt = 0
                self.GolemBuildTarget = nil
                self.GolemBuildArrivedAt = 0

                self.Route:InvalidateGoal()

                local buildTarget = self:GetCrystalGolemBuildTarget()
                self.GolemBuildTarget = buildTarget

                if buildTarget then
                    return buildTarget.Position, "CrystalGolemRockPlace", buildTarget
                end
            end
        else
            self.GolemPickupArrivedAt = 0
        end

        return target.Position, "CrystalGolemRockPickup", target
    end

    local buildTarget = self.GolemBuildTarget

    if not buildTarget or not buildTarget.Parent then
        buildTarget = self:GetCrystalGolemBuildTarget()
        self.GolemBuildTarget = buildTarget
        self.GolemBuildArrivedAt = 0
    end

    if not buildTarget then
        self:ResetCrystalGolemMechanicState()
        return nil, nil, nil
    end

    local distance = flatten(buildTarget.Position - self.Character.Root.Position).Magnitude

    if distance <= CONFIG.GolemRockPlaceRadius then
        if self.GolemBuildArrivedAt <= 0 then
            self.GolemBuildArrivedAt = now
        elseif now - self.GolemBuildArrivedAt >= CONFIG.GolemRockPlaceRetry then
            self:ResetCrystalGolemMechanicState()
            self.Route:InvalidateGoal()

            local retrySupply = self:GetCrystalGolemSupplyTarget()

            if retrySupply then
                self.GolemSupplyTarget = retrySupply
                return retrySupply.Position, "CrystalGolemRockPickup", retrySupply
            end

            return nil, nil, nil
        end
    else
        self.GolemBuildArrivedAt = 0
    end

    return buildTarget.Position, "CrystalGolemRockPlace", buildTarget
end

function UIWController:GetActiveSafeZone()
    if not self.Character:IsAlive() then
        return nil, nil, nil
    end

    local root = self.Character.Root
    local bestPart = nil
    local bestState = nil
    local bestDistance = math.huge

    local function consider(part, state)
        if not part
            or not part.Parent
            or not part:IsA("BasePart")
            or not isSafeZoneDestinationPart(part)
        then
            return
        end

        if not isStandaloneSafeZonePart(part) and part.Transparency >= 0.98 then
            return
        end

        local distance = flatten(part.Position - root.Position).Magnitude

        if distance < bestDistance then
            bestDistance = distance
            bestPart = part
            bestState = state
        end
    end

    for _, child in ipairs(Workspace:GetChildren()) do
        local lower = string.lower(child.Name or "")

        if child:IsA("Model") and SAFE_ZONE_SINGLE_CONTAINER_NAMES[lower] then
            for _, descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("BasePart") and string.lower(descendant.Name or "") == "precast" then
                    consider(
                        descendant,
                        lower == "thirdbossmemorysafezone" and "MemorySafeZone" or "SafeZone"
                    )
                end
            end
        elseif child:IsA("Model") and SAFE_ZONE_MULTI_CONTAINER_NAMES[lower] then
            for _, descendant in ipairs(child:GetDescendants()) do
                if descendant:IsA("BasePart") and string.lower(descendant.Name or "") == "precast" then
                    consider(descendant, "MassSafeZone")
                end
            end
        elseif SAFE_ZONE_NONDESTINATION_CONTAINER_NAMES[lower] then
            for _, descendant in ipairs(child:GetDescendants()) do
                if isStandaloneSafeZonePart(descendant) then
                    consider(descendant, "SafeSpotCircle")
                end
            end
        elseif isStandaloneSafeZonePart(child) then
            consider(child, "SafeSpotCircle")
        end
    end

    return bestPart, bestState, bestDistance
end

function UIWController:GetPriorityMechanicGoal()
    local cleanseGoal, cleansePart = self:GetCrystalGolemCleanseGoal()

    if cleanseGoal then
        local distance = flatten(cleanseGoal - self.Character.Root.Position).Magnitude
        return cleanseGoal, "FallingCrystalCleanse", cleansePart, distance
    end

    local safePart, safeState, safeDistance = self:GetActiveSafeZone()

    if safePart then
        return safePart.Position, safeState, safePart, safeDistance
    end

    local golemGoal, golemState, golemPart = self:GetCrystalGolemRockWallGoal()

    if golemGoal then
        local distance = flatten(golemGoal - self.Character.Root.Position).Magnitude
        return golemGoal, golemState, golemPart, distance
    end

    return nil, nil, nil, nil
end

function UIWController:GetGoal()
    local mechanicGoal = self:GetPriorityMechanicGoal()

    if mechanicGoal then
        return mechanicGoal
    end

    local root = self.Character.Root
    local overridePart = self.ProgressionOverridePart

    if overridePart and overridePart.Parent then
        local distance = flatten(overridePart.Position - root.Position).Magnitude

        if distance > CONFIG.ProgressionCheckpointReachDistance then
            return overridePart.Position
        end

        local completedRoom = self.ProgressionOverrideRoom

        if completedRoom then
            self.CompletedProgressionCheckpoints[completedRoom] = true

            local nextFloor = completedRoom + 1

            local liveEnemyRoom = self.CurrentEnemy
                and self.CurrentEnemy.Humanoid
                and self.CurrentEnemy.Humanoid.Health > 0
                and tonumber(self.CurrentEnemy.Room)
                or nil

            if liveEnemyRoom and liveEnemyRoom >= 1 and liveEnemyRoom <= 9 then
                nextFloor = math.min(nextFloor, liveEnemyRoom)
            end

            self.ProgressionFloorRoom = math.max(self.ProgressionFloorRoom, nextFloor)
            self.Dungeon.LastKnownRoom = math.max(self.Dungeon.LastKnownRoom, nextFloor)
        end

        self.ProgressionOverridePart = nil
        self.ProgressionOverrideRoom = nil
        self.ProgressionOverrideTargetModel = nil
        self.ProgressionProbeRetryAt = 0

        self.Route:InvalidateGoal()
    elseif overridePart then
        self.ProgressionOverridePart = nil
        self.ProgressionOverrideRoom = nil
        self.ProgressionOverrideTargetModel = nil
        self.ProgressionProbeRetryAt = 0
    end

    local frontierGoal = self.ProgressionFrontierGoal

    if frontierGoal then
        local frontierTargetStillValid = self.CurrentEnemy
            and self.CurrentEnemy.Model == self.ProgressionFrontierTargetModel
            and self.CurrentEnemy.Humanoid
            and self.CurrentEnemy.Humanoid.Health > 0

        if not frontierTargetStillValid then
            self.ProgressionFrontierGoal = nil
            self.ProgressionFrontierTargetModel = nil
        else
            local frontierDistance = flatten(frontierGoal - root.Position).Magnitude

            if frontierDistance > CONFIG.ProgressionFrontierReachDistance then
                return frontierGoal
            end

            self.ProgressionFrontierGoal = nil
            self.ProgressionFrontierTargetModel = nil
            self.ProgressionProbeRetryAt = 0
            self.Route:InvalidateGoal()
        end
    end

    if self.CurrentEnemy
        and self.CurrentEnemy.Root
        and self.CurrentEnemy.Root.Parent
        and self.CurrentEnemy.Humanoid
        and self.CurrentEnemy.Humanoid.Health > 0
    then
        local enemy = self.CurrentEnemy

        local enemyRoomNumber = tonumber(enemy.Room)

        if enemyRoomNumber
            and enemyRoomNumber >= 1
            and enemyRoomNumber <= 9
            and self.ProgressionFloorRoom > enemyRoomNumber
        then
            self.ProgressionFloorRoom = enemyRoomNumber

            if self.Dungeon.LastKnownRoom > enemyRoomNumber then
                self.Dungeon.LastKnownRoom = enemyRoomNumber
            end
        end

        local enemyGoal = enemy.Root.Position

        local noPathToThisEnemy = self.Route.LastPathStatus == "NoPath"
            and not self.Route.FallbackRoute
            and self.Route.LastNoPathGoal
            and (self.Route.LastNoPathGoal - enemyGoal).Magnitude <= CONFIG.GoalChangeThreshold

        if noPathToThisEnemy and enemy.Room and enemy.Room > 1 then
            local now = os.clock()

            if now >= self.ProgressionProbeRetryAt then
                self.ProgressionProbeRetryAt = now + CONFIG.ProgressionProbeRetry

                local maximumRoom = enemy.Room == 999 and 9 or math.min(enemy.Room, 9)

                local minimumRoom = math.min(math.max(self.ProgressionFloorRoom, 1), maximumRoom)

                local checkpoint, checkpointRoom = self.Dungeon:GetNextReachableCheckpointTowardRoom(
                    root.Position,
                    enemy.Room,
                    minimumRoom,
                    self.CompletedProgressionCheckpoints,
                    self.Route
                )

                if checkpoint then
                    self.ProgressionFloorRoom = math.max(self.ProgressionFloorRoom, checkpointRoom)
                    self.ProgressionOverridePart = checkpoint
                    self.ProgressionOverrideRoom = checkpointRoom
                    self.ProgressionOverrideTargetModel = enemy.Model

                    self.Route:InvalidateGoal()

                    return checkpoint.Position
                end

                local frontier = self.Route:FindReachableFrontierGoal(root.Position, enemyGoal)

                if frontier then
                    self.ProgressionFrontierGoal = frontier
                    self.ProgressionFrontierTargetModel = enemy.Model

                    self.Route:InvalidateGoal()

                    return frontier
                end
            end
        else
            self.ProgressionProbeRetryAt = 0
        end

        return enemyGoal
    end

    return self.Dungeon:GetProgressionGoal(root.Position)
end

function UIWController:GetTargetYaw()
    local enemy = self.CurrentEnemy

    if enemy and enemy.Root and enemy.Root.Parent then
        local direction = flatten(enemy.Root.Position - self.Character.Root.Position)

        if direction.Magnitude > 0.05 then
            return directionToYaw(direction)
        end
    end

    return self.Character.DesiredYaw
        or directionToYaw(self.Character.Root.CFrame.LookVector)
end

-- v39 stuck recovery.
-- Escalates per stuck spot instead of repeating the same wiggle:
--   1-2: slide along the wall (alternating sides at the same spot)
--   3:   step back, mark the spot as "avoid" for the pathfinder, repath
--   4:   skip ahead to a waypoint with a clear straight line
--   5+:  walk into the most open nearby direction, then full repath
-- It also catches back-and-forth loops that never trigger "no progress".
-- v40: standing still is only safe when nothing is going off nearby.
function UIWController:IsAreaHot()
    local root = self.Character.Root
    if not root then
        return false
    end

    local count = 0
    for _, data in ipairs(self.Hazards:GetActive()) do
        local part = data.Part
        if part and part.Parent then
            local reach = CONFIG.HotAreaRadius
            if data.WarningHalf then
                reach += math.max(data.WarningHalf.X, data.WarningHalf.Z)
            else
                reach += math.max(part.Size.X, part.Size.Z) * 0.5
            end
            if flatten(part.Position - root.Position).Magnitude <= reach then
                count += 1
                if count >= CONFIG.HotAreaHazards then
                    return true
                end
            end
        end
    end

    return false
end

function UIWController:GetStuckSpot(position, now)
    self.StuckSpots = self.StuckSpots or {}

    for index = #self.StuckSpots, 1, -1 do
        if now - self.StuckSpots[index].Last > CONFIG.StuckSpotMemory then
            table.remove(self.StuckSpots, index)
        end
    end

    for _, spot in ipairs(self.StuckSpots) do
        if flatten(spot.Position - position).Magnitude <= CONFIG.StuckSpotRadius then
            return spot
        end
    end

    local spot = {
        Position = position,
        Count = 0,
        Last = now,
        SlideSide = 1,
        Avoided = false,
    }
    table.insert(self.StuckSpots, spot)
    self:RememberStuckSpot(position)
    return spot
end

-- Stuck spots are saved per dungeon, so the next run (a new server) routes
-- around known bad corners from the start.
local STUCK_SPOT_FILE = "UIW/stuck_spots.json"

local function readStuckSpotFile()
    return SafeFile.ReadJson(STUCK_SPOT_FILE) or {}
end

function UIWController:GetDungeonKey()
    local value = Workspace:FindFirstChild("dungeonName")
    if value and value:IsA("StringValue") and value.Value ~= "" then
        return value.Value
    end
    return nil
end

function UIWController:RememberStuckSpot(position)
    local key = self:GetDungeonKey()
    if not key or type(writefile) ~= "function" then
        return
    end

    pcall(function()
        local data = readStuckSpotFile()
        local list = data[key] or {}

        for _, saved in ipairs(list) do
            local savedPosition = Vector3.new(saved.X, saved.Y, saved.Z)
            if (savedPosition - position).Magnitude <= CONFIG.StuckSpotRadius then
                saved.Hits = (saved.Hits or 1) + 1
                data[key] = list
                SafeFile.WriteJson(STUCK_SPOT_FILE, data)
                return
            end
        end

        table.insert(list, {
            X = math.floor(position.X * 10) / 10,
            Y = math.floor(position.Y * 10) / 10,
            Z = math.floor(position.Z * 10) / 10,
            Hits = 1,
        })

        table.sort(list, function(a, b)
            return (a.Hits or 1) > (b.Hits or 1)
        end)
        while #list > CONFIG.SavedStuckSpotsPerDungeon do
            table.remove(list)
        end

        data[key] = list
        SafeFile.WriteJson(STUCK_SPOT_FILE, data)
    end)
end

function UIWController:LoadSavedStuckSpots()
    local key = self:GetDungeonKey()
    if not key then
        return 0
    end

    local list = readStuckSpotFile()[key] or {}
    for _, saved in ipairs(list) do
        self.Route:AddAvoidZone(Vector3.new(saved.X, saved.Y, saved.Z), 3600)
    end
    return #list
end

function UIWController:IsOscillating(position, now)
    -- Only meaningful while navigating; combat orbiting legitimately stays in an area.
    if not self.Dodger.TravelMode or self.Dodger.IsDodging then
        self.PositionHistory = {}
        return false
    end

    self.PositionHistory = self.PositionHistory or {}
    local history = self.PositionHistory

    if #history == 0 or now - history[#history].Time >= 0.5 then
        table.insert(history, { Position = position, Time = now })
    end

    while #history > 0 and now - history[1].Time > CONFIG.LoopWindow do
        table.remove(history, 1)
    end

    if #history < 2 or now - history[1].Time < CONFIG.LoopWindow - 0.6 then
        return false
    end

    local center = Vector3.zero
    for _, sample in ipairs(history) do
        center += sample.Position
    end
    center /= #history

    for _, sample in ipairs(history) do
        if flatten(sample.Position - center).Magnitude > CONFIG.LoopRadius then
            return false
        end
    end

    return true
end

function UIWController:FindOpenDirection(position, avoidDirection, goalDirection, targetYaw, distance)
    local best, bestScore = nil, -math.huge

    for i = 0, 15 do
        local direction = unit(rotateXZ(Vector3.new(1, 0, 0), i * 22.5))
        local endpoint = position + direction * distance

        if self.Geometry:IsDirectionClear(direction, distance, targetYaw)
            and self.Geometry:IsGroundPadded(endpoint, math.min(CONFIG.EdgeHardPadding, 6))
        then
            local score = self.Geometry:GetEdgeClearanceScore(endpoint) * 10

            if avoidDirection.Magnitude > 0 then
                score -= direction:Dot(avoidDirection) * 40
            end
            if goalDirection.Magnitude > 0 then
                score += direction:Dot(goalDirection) * 25
            end

            -- Prefer places that are far from every remembered stuck spot.
            for _, spot in ipairs(self.StuckSpots or {}) do
                local d = flatten(spot.Position - endpoint).Magnitude
                if d < CONFIG.StuckSpotRadius * 2 then
                    score -= (CONFIG.StuckSpotRadius * 2 - d) * 6
                end
            end

            if score > bestScore then
                bestScore = score
                best = direction
            end
        end
    end

    return best
end

function UIWController:BeginRecovery(direction, duration, hard)
    self.RecoveryDirection = direction
    self.RecoveryUntil = os.clock() + duration
    self.HardRecoveryActive = hard
    self.StuckEvents = (self.StuckEvents or 0) + 1
    return direction, true, hard
end

function UIWController:GetStuckRecovery(routeDirection, targetYaw, fallbackDirection)
    local now = os.clock()
    local root = self.Character.Root
    local humanoid = self.Character.Humanoid
    local position = root.Position

    -- A recovery move is running: keep it, unless it is itself blocked.
    if now < self.RecoveryUntil and self.RecoveryDirection.Magnitude > 0 then
        if self.Geometry:IsDirectionClear(self.RecoveryDirection, 1.5, targetYaw) then
            return self.RecoveryDirection, true, self.HardRecoveryActive == true
        end
        self.RecoveryUntil = 0
        self.LastProgressTime = now - CONFIG.StuckTimeout -- re-evaluate right away
    end

    self.HardRecoveryActive = false

    if not self.LastProgressPosition or self.LastCommandedMovement.Magnitude < 0.5 then
        self.LastProgressPosition = position
        self.LastProgressTime = now
        return nil, false, false
    end

    local elapsed = now - self.LastProgressTime
    local progress = flatten(position - self.LastProgressPosition).Magnitude

    if progress > 3.5 then
        self.LastProgressPosition = position
        self.LastProgressTime = now
    end

    local basis = unit(flatten(routeDirection))
    if basis.Magnitude <= 0 then
        basis = unit(flatten(fallbackDirection or Vector3.zero))
    end
    if basis.Magnitude <= 0 then
        basis = unit(flatten(root.CFrame.LookVector))
    end

    local speed = flatten(root.AssemblyLinearVelocity).Magnitude
    local clear, hit = self.Geometry:IsDirectionClear(basis, 2.5, targetYaw)
    local blocked = not clear and hit ~= nil

    local stalled = progress <= 3.5
        and (elapsed >= CONFIG.StuckTimeout
            or (blocked and elapsed >= CONFIG.StuckBlockedTimeout and speed < 3))

    local looping = self:IsOscillating(position, now)

    if not stalled and not looping then
        return nil, false, false
    end

    local spot = self:GetStuckSpot(position, now)
    spot.Count += looping and 2 or 1
    spot.Last = now
    self.PositionHistory = {}
    self.LastProgressPosition = position
    self.LastProgressTime = now

    local function jump()
        if humanoid.FloorMaterial ~= Enum.Material.Air then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            self.LastNavigationAutoJump = now
        end
    end

    local wallNormal = Vector3.zero
    if hit and hit.Normal then
        wallNormal = unit(flatten(hit.Normal))
    end

    -- Low obstacle (step / small ledge): jump over it, but only once per spot.
    if blocked and spot.Count == 1 and not looping
        and self.Geometry:IsDirectionClearFrom(position + Vector3.new(0, 3.5, 0), basis, 3.5, targetYaw)
    then
        jump()
        return self:BeginRecovery(basis, 0.35, false)
    end

    -- Level 1-2: slide along the wall, alternating sides at this spot.
    if spot.Count <= 2 then
        local candidates = {}

        if wallNormal.Magnitude > 0 then
            local along = basis - wallNormal * basis:Dot(wallNormal)
            if along.Magnitude < 0.25 then
                along = Vector3.new(-wallNormal.Z, 0, wallNormal.X)
            end
            along = unit(along)
            local first = spot.SlideSide >= 0 and along or -along
            table.insert(candidates, unit(first + wallNormal * 0.35))
            table.insert(candidates, unit(-first + wallNormal * 0.35))
        else
            local side = Vector3.new(-basis.Z, 0, basis.X) * spot.SlideSide
            table.insert(candidates, unit(basis * 0.4 + side))
            table.insert(candidates, unit(basis * 0.4 - side))
        end

        spot.SlideSide = -spot.SlideSide

        for _, direction in ipairs(candidates) do
            if self.Geometry:IsDirectionClear(direction, 4, targetYaw) then
                jump()
                return self:BeginRecovery(direction, 0.55, false)
            end
        end
        -- Neither side is open: fall through to the next level now.
        spot.Count = 3
    end

    -- Level 3: back off, mark the spot for the pathfinder, repath.
    if spot.Count == 3 then
        if not spot.Avoided then
            spot.Avoided = true
            self.Route:AddAvoidZone(spot.Position)
        end

        local back = unit(-basis + wallNormal * 0.6)
        if back.Magnitude <= 0 or not self.Geometry:IsDirectionClear(back, 3, targetYaw) then
            back = self:FindOpenDirection(position, basis, Vector3.zero, targetYaw, 4) or back
        end

        self.Route:ClearPath()
        self.Route:ForceRepath(self.Route.CurrentGoal)
        return self:BeginRecovery(back, 0.5, true)
    end

    -- Level 4: skip ahead to a waypoint with a clear straight line.
    if spot.Count == 4 then
        if not spot.Avoided then
            spot.Avoided = true
            self.Route:AddAvoidZone(spot.Position)
        end

        if self.Route:SkipToVisibleWaypoint(targetYaw) then
            return nil, false, false
        end
        spot.Count = 5
    end

    -- Level 5+: walk into open space away from the corner, then rebuild the route.
    local goalDirection = Vector3.zero
    if self.Route.CurrentGoal then
        goalDirection = unit(flatten(self.Route.CurrentGoal - position))
    end

    local open = self:FindOpenDirection(position, basis, goalDirection, targetYaw, 10)
        or self:FindOpenDirection(position, Vector3.zero, Vector3.zero, targetYaw, 5)

    if not spot.Avoided then
        spot.Avoided = true
        self.Route:AddAvoidZone(spot.Position)
    end

    local goal = self.Route.CurrentGoal
    self.Route:Reset()
    if goal then
        self.Route:ForceRepath(goal)
    end

    if spot.Count >= 8 then
        -- Truly wedged: forget this spot so the cycle can start fresh.
        spot.Count = 0
    end

    if open then
        jump()
        return self:BeginRecovery(open, 1.1, true)
    end

    jump()
    local wiggle = unit(-basis * 0.3 + Vector3.new(-basis.Z, 0, basis.X) * spot.SlideSide)
    spot.SlideSide = -spot.SlideSide
    return self:BeginRecovery(wiggle, 0.45, true)
end

function UIWController:Step()
    if self.Destroyed then
        return
    end

    local now = os.clock()

    if now - self.LastWorldRefresh >= CONFIG.WorldRefreshInterval then
        self.LastWorldRefresh = now
        self:RefreshWorld()
    end

    if not self.Character:IsAlive() then
        return
    end

    self.Hazards:RefreshCache(false)

    self.TacticalDisplay:Update(self.ShowAura, self.ShowMobGroups, self.CurrentEnemy)

    self.ESP.Enabled = self.AutoESP
    self.ESP:Update(false)

    if self.AutoPathESP then
        self.PathESP:Update(self.Route.Waypoints, self.Route.WaypointIndex, self.Character.Root.Position)
    else
        self.PathESP:Hide()
    end

    self:SelectTarget()
    self.TargetHealth:Update()

    if not self.Enabled then
        self.Dodger.ForceRouteMovement = false
        self.Dodger.ForcedRegionPart = nil
        self.Character:ReleaseAutomationFacing()
        self.LastCommandedMovement = Vector3.zero
        self.HUD:SetStatus("IDLE", "disabled")
        return
    end

    local targetYaw = self:GetTargetYaw()

    local mechanicGoal, mechanicState, mechanicPart = self:GetPriorityMechanicGoal()

    local goal = mechanicGoal or self:GetGoal()

    local mechanicActive = mechanicGoal ~= nil

    self.Dodger.ForceRouteMovement = mechanicActive
    self.Dodger.ForcedRegionPart = nil

    if mechanicActive
        and mechanicPart
        and mechanicPart:IsA("BasePart")
        and (
            mechanicState == "FallingCrystalCleanse"
            or mechanicState == "CrystalGolemWallCover"
            or mechanicState == "MemorySafeZone"
            or mechanicState == "MassSafeZone"
            or mechanicState == "SafeZone"
            or mechanicState == "SafeSpotCircle"
        )
    then
        self.Dodger.ForcedRegionPart = mechanicPart
    end

    local routeDirection = Vector3.zero

    if goal then
        local routeReachDistance = nil
        local progressionPart = self.ProgressionOverridePart

        if progressionPart
            and progressionPart.Parent
            and (progressionPart.Position - goal).Magnitude <= 0.05
        then
            routeReachDistance = CONFIG.ProgressionCheckpointReachDistance
        end

        routeDirection = self.Route:GetSafeDirection(goal, targetYaw, routeReachDistance)
    end

    self.Dodger.CooldownHold = false

    local recoveryFallback

    if mechanicActive then
        recoveryFallback = routeDirection
    else
        recoveryFallback = self.Dodger:GetCombatPreferred(routeDirection, self.CurrentEnemy, targetYaw)
    end

    local cooldownHold = false
    if self.AutoCombat
        and not mechanicActive
        and not (self.CurrentEnemy and isBossEnemy(self.CurrentEnemy))
    then
        cooldownHold = self.Combat:ShouldHoldApproach(self.CurrentEnemy, self.Dodger.TravelMode)
    end

    local targetBlocked = not mechanicActive and self.Combat:IsTargetBlocked(self.CurrentEnemy)
    self.Dodger.TargetBlocked = targetBlocked

    if cooldownHold and (targetBlocked or self.InWaterStream or self:IsAreaHot()) then
        cooldownHold = false
    end

    local retreating = false
    if self.AutoCombat and not mechanicActive and not targetBlocked and not self.InWaterStream then
        retreating = self.Combat:ShouldRetreat(self.CurrentEnemy)
    else
        self.Combat.RetreatActive = false
    end

    self.Dodger.CooldownHold = cooldownHold and not retreating
    self.Dodger.RetreatActive = retreating

    local routeRepathHold = self.Route.Computing and routeDirection.Magnitude <= 0

    if cooldownHold or retreating or routeRepathHold then
        self.LastProgressPosition = self.Character.Root.Position
        self.LastProgressTime = now
        self.RecoveryUntil = 0
        self.HardRecoveryActive = false
    end

    local recoveryDirection, recovering, hardRecovering

    if cooldownHold then
        recoveryDirection = nil
        recovering = false
        hardRecovering = false
    else
        recoveryDirection, recovering, hardRecovering = self:GetStuckRecovery(
            routeDirection,
            targetYaw,
            recoveryFallback
        )
    end

    if recovering and recoveryDirection then
        routeDirection = recoveryDirection
    end

    local movement = routeDirection
    local yaw = targetYaw
    local emergency = false
    local dodging = false

    if self.AutoDodge then
        movement, yaw, emergency, dodging = self.Dodger:Solve(routeDirection, self.CurrentEnemy, targetYaw)
    end

    if hardRecovering and recoveryDirection and not mechanicActive and not emergency and not dodging then
        movement = recoveryDirection
        yaw = targetYaw
        emergency = false
        dodging = true
    end

    -- v42 Water Stream: standing on the damaging floor outside the arena ->
    -- take the path into the arena at full speed instead of dodging sideways.
    local inStream = self.Hazards:IsInActiveStream(self.Character.Root.Position)
    self.InWaterStream = inStream
    if inStream and not mechanicActive then
        local toward = routeDirection
        if toward.Magnitude <= 0.05 and self.CurrentEnemy and self.CurrentEnemy.Root then
            toward = unit(flatten(self.CurrentEnemy.Root.Position - self.Character.Root.Position))
        end
        if toward.Magnitude > 0.05 then
            movement = unit(toward)
            yaw = targetYaw
            emergency = false
            dodging = true
        end
    end

    if not emergency then
        yaw = targetYaw
    end

    self.Character:SetYaw(yaw)
    self.Character.Humanoid:Move(movement, false)
    self.LastCommandedMovement = movement

    self.Combat.EscapingHitbox = dodging and self.Dodger.LastDodgeReason == "hitbox"

    local attacked = false
    if self.AutoCombat then
        attacked = self.Combat:Update(self.CurrentEnemy)
    end

    local overlaps = self.Hazards:GetCurrentOverlaps(yaw)
    local meleeThreats = self.Dungeon:GetMeleeThreats(self.Character.Root.Position, CONFIG.MultiMeleeRadius)

    local nearestMelee = math.huge
    local nearestMeleeClass = nil

    for _, info in ipairs(meleeThreats) do
        if info.Distance < nearestMelee then
            nearestMelee = info.Distance
            nearestMeleeClass = info.ThreatClass
        end
    end

    local function goalDistance()
        if goal then
            return math.floor((goal - self.Character.Root.Position).Magnitude)
        end
        return 0
    end

    if inStream and not mechanicActive then
        self.HUD:SetStatus("EMERGENCY", "Water Stream | running into the boss arena")
    elseif #overlaps > 0 then
        local attackName = self.Hazards.LastDetectedAttack
        local attackRecent = attackName and os.clock() - (self.Hazards.LastDetectedAttackTime or 0) <= 3
        self.HUD:SetStatus(
            "EMERGENCY",
            attackRecent
                and ("escaping " .. tostring(attackName) .. " | active hitbox")
                or "escaping active hitbox | still attacking when in range"
        )
    elseif mechanicActive then
        local mechanicDistance = mechanicPart
            and math.floor(flatten(mechanicPart.Position - self.Character.Root.Position).Magnitude)
            or 0

        local mechanicLabel = mechanicState or "SafeZone"
        local mechanicVerb = mechanicState == "LargeAttackEscape" and "leave large attack" or "enter safe zone"

        if mechanicState == "CrystalGolemRockPickup" then
            mechanicVerb = "pick up rock"
        elseif mechanicState == "CrystalGolemRockPlace" then
            mechanicVerb = "place rock"
        elseif mechanicState == "CrystalGolemWallCover" then
            mechanicVerb = "get behind wall"
        elseif mechanicState == "FallingCrystalCleanse" then
            mechanicVerb = "cleanse falling crystal"
        end

        self.HUD:SetStatus(
            "MECHANIC",
            mechanicLabel .. " | " .. mechanicVerb .. " " .. tostring(mechanicDistance) .. " studs"
        )
    elseif self.Dodger.MeleePanicActive then
        self.HUD:SetStatus(
            "MELEE",
            "panic "
                .. string.lower(nearestMeleeClass or "melee")
                .. " spacing | "
                .. string.format("%.0f", nearestMelee)
                .. " studs"
        )
    elseif recovering then
        self.HUD:SetStatus(
            "PATHING",
            hardRecovering
                and "unsticking | backing off corner + new route"
                or "unsticking | sliding along wall"
        )
    elseif self.Route.FallbackRoute then
        self.HUD:SetStatus("PATHING", "PFS NoPath | ground-route fallback")
    elseif dodging and self.Dodger.LastDodgeReason == "bullseye" then
        self.HUD:SetStatus("DODGING", "Cube Pylon bullseye | standing in the safe ring")
    elseif dodging then
        local attackName = self.Hazards.LastDetectedAttack
        local attackRecent = attackName and os.clock() - (self.Hazards.LastDetectedAttackTime or 0) <= 3
        local auraThreat = self.Dodger.AuraThreat
        local auraName = auraThreat and (
            (auraThreat.Container and auraThreat.Container.Name)
            or auraThreat.Name
            or (auraThreat.Part and auraThreat.Part.Name)
        )
        self.HUD:SetStatus(
            "DODGING",
            auraName
                and ("AURA • " .. tostring(auraName) .. " • " .. string.format("%.1f", self.Dodger.AuraThreatDistance or 0) .. " studs")
                or attackRecent
                and ("Mage Overlord | dodging " .. tostring(attackName))
                or "real threat in movement corridor"
        )
    elseif retreating or cooldownHold then
        self.HUD:SetStatus("PATHING", self.Combat:GetHoldText())
    elseif attacked then
        self.HUD:SetStatus(
            "COMBAT",
            "engaging " .. (self.CurrentEnemy and self.CurrentEnemy.Model.Name or "enemy")
        )
    elseif self.Route.Computing and #self.Route.Waypoints == 0 then
        self.HUD:SetStatus("PATHING", "calculating initial dungeon route")
    elseif self.ProgressionOverridePart and self.ProgressionOverridePart.Parent then
        local checkpointDistance = math.floor(
            (self.ProgressionOverridePart.Position - self.Character.Root.Position).Magnitude + 0.5
        )

        self.HUD:SetStatus(
            "PROGRESSION",
            "room "
                .. tostring(self.ProgressionOverrideRoom or "?")
                .. " checkpoint | "
                .. tostring(checkpointDistance)
                .. " studs | floor "
                .. tostring(self.ProgressionFloorRoom)
        )
    elseif self.Dodger.TravelMode and movement.Magnitude > 0.05 then
        self.HUD:SetStatus("PATHING", "NAVIGATION | " .. tostring(goalDistance()) .. " away")
    elseif self.Dodger.TravelMode and movement.Magnitude <= 0.05 then
        self.HUD:SetStatus(
            "PATHING",
            "NAVIGATION | recalculating route | " .. tostring(goalDistance()) .. " away"
        )
    elseif movement.Magnitude > 0.05 then
        self.HUD:SetStatus(
            "MOVING",
            "approaching "
                .. (self.CurrentEnemy and self.CurrentEnemy.Model.Name or "enemy")
                .. " | "
                .. tostring(goalDistance())
                .. " away"
        )
    else
        self.HUD:SetStatus("RUNNING", "holding safe ground")
    end
end

function UIWController:Start()
    self:RefreshWorld()

    self.SelfAbilities:Start()
    self.Route:Start()
    self.Hazards:Start()

    self:ConfigureAutoExecute()

    -- Pre-place avoid zones at corners this dungeon got stuck on before.
    task.spawn(function()
        for _ = 1, 20 do
            if self.Destroyed then return end
            if self:GetDungeonKey() then
                self.SavedStuckSpotsLoaded = self:LoadSavedStuckSpots()
                return
            end
            task.wait(0.5)
        end
    end)

    -- v40 damage learning: attribute each hit to the attacks you were in,
    -- saved per dungeon in UIW/damage_profile.json.
    local DAMAGE_FILE = "UIW/damage_profile.json"

    local function readDamageFile()
        return SafeFile.ReadJson(DAMAGE_FILE) or {}
    end

    task.spawn(function()
        for _ = 1, 20 do
            if self.Destroyed then return end
            local key = self:GetDungeonKey()
            if key then
                self.Hazards.DamageProfile = readDamageFile()[key] or {}
                return
            end
            task.wait(0.5)
        end
    end)

    local hookedHumanoid, damageConnection = nil, nil
    local lastSave = 0
    self.Maid:Give(RunService.Heartbeat:Connect(function()
        local humanoid = self.Character.Humanoid
        if humanoid and humanoid ~= hookedHumanoid then
            if damageConnection then damageConnection:Disconnect() end
            hookedHumanoid = humanoid
            local last = humanoid.Health
            damageConnection = humanoid.HealthChanged:Connect(function(health)
                local lost = last - health
                last = health
                local root = self.Character.Root
                if lost > 0 and root and humanoid.MaxHealth > 0 then
                    self.Hazards:LearnDamage(lost / humanoid.MaxHealth, root.Position)
                end
            end)
        end

        if self.Hazards.DamageProfileDirty and os.clock() - lastSave > 30 and type(writefile) == "function" then
            lastSave = os.clock()
            self.Hazards.DamageProfileDirty = false
            local key = self:GetDungeonKey()
            if key then
                pcall(function()
                    local all = readDamageFile()
                    all[key] = self.Hazards.DamageProfile
                    SafeFile.WriteJson(DAMAGE_FILE, all)
                end)
            end
        end
    end))
    self.Maid:Give(function()
        if damageConnection then damageConnection:Disconnect() end
    end)

    -- AUTO START DUNGEON UPON LOAD
    task.spawn(function()
        task.wait(1.5)
        pcall(function()
            game:GetService("ReplicatedStorage").remotes.changeStartValue:FireServer()
        end)
    end)

    -- AUTO RETRY TOGGLE BUTTON EVENT
    self.Maid:Give(self.HUD.AutoRetryButton.MouseButton1Click:Connect(function()
        self.AutoRetryEnabled = not self.AutoRetryEnabled
        if self.AutoRetryEnabled then
            self.HUD.AutoRetryButton.Text = "RETRY: ON"
            self.HUD.AutoRetryButton.BackgroundColor3 = Color3.fromRGB(43, 205, 151)
        else
            self.HUD.AutoRetryButton.Text = "RETRY: OFF"
            self.HUD.AutoRetryButton.BackgroundColor3 = Color3.fromRGB(205, 43, 60)
        end
    end))

    -- AUTO RETRY (v39)
    -- Uses the game's own completion flag (dungeon.bossRoom.dungeonFinished)
    -- and sends exactly the replay data the game's Replay button sends.
    self.ReplayTriggered = false
    self.RunStartTime = os.clock()
    self.ReplayToken = 0
    self.CompletionSeenAt = nil

    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    local function readValue(parent, name)
        local value = parent and parent:FindFirstChild(name)
        if value and value:IsA("ValueBase") then
            return value.Value
        end
        return nil
    end

    -- Mirrors collectDungeonData() in the game's ReplayDungeonButton script.
    local function collectDungeonData()
        local data = {}

        local dungeonName = readValue(Workspace, "dungeonName")
        if type(dungeonName) == "string" and dungeonName ~= "" then
            data.dungeonName = dungeonName
        end

        local progress = readValue(Workspace, "dungeonProgress")
        if progress ~= nil then data.dungeonProgress = progress end

        local started = readValue(Workspace, "dungeonStarted")
        if started ~= nil then data.dungeonStarted = started end

        local hardcore = readValue(Workspace, "hardcore")
        if hardcore ~= nil then
            data.hardcore = hardcore
            data.isHardcore = hardcore
        end

        local dungeon = Workspace:FindFirstChild("dungeon")
        if dungeon then
            for _, value in ipairs(dungeon:GetChildren()) do
                if value:IsA("ValueBase") then
                    data[value.Name] = value.Value
                end
            end

            local bossRoom = dungeon:FindFirstChild("bossRoom")
            if bossRoom then
                for _, value in ipairs(bossRoom:GetChildren()) do
                    if value:IsA("ValueBase") then
                        data[value.Name] = value.Value
                    end
                end
            end
        end

        return data
    end

    local function dungeonFinished()
        local dungeon = Workspace:FindFirstChild("dungeon")
        local bossRoom = dungeon and dungeon:FindFirstChild("bossRoom")

        if readValue(bossRoom, "dungeonFinished") == true then
            return true
        end

        if dungeon and dungeon:GetAttribute("dungeonFinished") == true then
            return true
        end

        return false
    end

    local function tryReplay()
        if self.ReplayTriggered or not self.AutoRetryEnabled or self.Destroyed then
            return
        end

        local dungeonName = readValue(Workspace, "dungeonName") or "?"

        -- v41: in solo, dying ends the run without a "finished" flag.
        local humanoid = self.Character.Humanoid
        local dead = humanoid and humanoid.Parent and humanoid.Health <= 0
        if dead then
            self.DeadSince = self.DeadSince or os.clock()
        else
            self.DeadSince = nil
        end
        local deadLongEnough = self.DeadSince and os.clock() - self.DeadSince >= CONFIG.ReplayOnDeathDelay

        if not dungeonFinished() and not deadLongEnough then
            self.CompletionSeenAt = nil
            if self.HUD and os.clock() - self.RunStartTime > 5 then
                local fighting = readValue(
                    Workspace:FindFirstChild("dungeon") and Workspace.dungeon:FindFirstChild("bossRoom"),
                    "fightingBoss"
                )
                self.HUD:SetRetryStatus(
                    tostring(dungeonName) .. (fighting and " • boss fight" or " • waiting for dungeon to finish"),
                    fighting and COLORS.Combat or COLORS.Moving
                )
            end
            return
        end

        self.CompletionSeenAt = self.CompletionSeenAt or os.clock()
        local remaining = CONFIG.ReplayDelay - (os.clock() - self.CompletionSeenAt)

        if remaining > 0 then
            if self.HUD then
                self.HUD:SetRetryStatus(
                    string.format("%s %s • replay in %.0fs", tostring(dungeonName), deadLongEnough and "failed (died)" or "finished", remaining),
                    COLORS.Running
                )
            end
            return
        end

        local data = collectDungeonData()
        if not data.dungeonName then
            if self.HUD then
                self.HUD:SetRetryStatus("finished, but the dungeon name is missing", COLORS.Emergency)
            end
            return
        end

        local remotes = ReplicatedStorage:FindFirstChild("remotes")
        local replayRemote = remotes and remotes:FindFirstChild("replayDungeon")
        if not replayRemote then
            if self.HUD then
                self.HUD:SetRetryStatus("replayDungeon remote not found", COLORS.Emergency)
            end
            return
        end

        self.ReplayTriggered = true
        self.ReplayToken += 1
        local token = self.ReplayToken

        task.spawn(function()
            for attempt = 1, CONFIG.ReplayAttempts do
                if token ~= self.ReplayToken or not self.AutoRetryEnabled or self.Destroyed then
                    return
                end

                if self.HUD then
                    self.HUD:SetRetryStatus(
                        string.format("replaying %s • request %d/%d", data.dungeonName, attempt, CONFIG.ReplayAttempts),
                        COLORS.Pathing
                    )
                end

                local ok, err = pcall(function()
                    replayRemote:FireServer(data)
                end)
                if not ok then
                    warn("[UIW] replay request failed: " .. tostring(err))
                end

                task.wait(CONFIG.ReplayRetryInterval)
            end

            if self.HUD then
                self.HUD:SetRetryStatus("replay sent • waiting for teleport", COLORS.Running)
            end

            -- Still here after a while? Allow another round.
            task.wait(10)
            if token == self.ReplayToken then
                self.ReplayTriggered = false
                self.CompletionSeenAt = nil
            end
        end)
    end

    self.Maid:Give(RunService.Heartbeat:Connect(function()
        if os.clock() - (self.LastRetryCheck or 0) < 0.5 then return end
        self.LastRetryCheck = os.clock()
        pcall(tryReplay)
    end))

    self.Maid:Give(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.75)

        self.ReplayTriggered = false
        self.ReplayToken += 1
        self.RunStartTime = os.clock()
        self.CompletionSeenAt = nil
        self.DeadSince = nil
        self:ClearDeathConnection()

        self.CurrentEnemy = nil
        self.CurrentEnemyModel = nil

        self.LastProgressPosition = nil
        self.LastProgressTime = 0
        self.LastCommandedMovement = Vector3.zero
        self.RecoveryDirection = Vector3.zero
        self.RecoveryUntil = 0
        self.HardRecoveryActive = false
        self.StuckSpots = {}
        self.PositionHistory = {}
        self.Dodger.MeleePanicActive = false
        self.Dodger.CommittedDodgeDirection = Vector3.zero
        self.Dodger.DodgeCommitUntil = 0
        self.Dodger.LastDangerTime = 0
        self.Dodger.ForceRouteMovement = false
        self.Dodger.ForcedRegionPart = nil
        self.Dodger.TravelMode = true

        self:ResetCrystalGolemMechanicState()

        self.ProgressionOverridePart = nil
        self.ProgressionOverrideRoom = nil
        self.ProgressionOverrideTargetModel = nil
        self.ProgressionFrontierGoal = nil
        self.ProgressionFrontierTargetModel = nil

        table.clear(self.CompletedProgressionCheckpoints)

        self.ProgressionFloorRoom = 1
        self.ProgressionProbeRetryAt = 0

        self.Dodger.TravelExitCandidateSince = 0

        self.Route:Reset()
        self.Route:ClearAvoidZones()
        self:LoadSavedStuckSpots()

        self:RefreshWorld()
    end))

    self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == Enum.KeyCode.RightShift then
            self.HUD:Toggle()
        end
    end))

    RunService:BindToRenderStep(
        "UIW_Movement",
        Enum.RenderPriority.Character.Value + 1,
        function()
            self:Step()
            self.HUD:Heartbeat()
        end
    )

    self.Maid:Give(function()
        pcall(function()
            RunService:UnbindFromRenderStep("UIW_Movement")
        end)
    end)

    log("Loaded")
end

function UIWController:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    self:ClearDeathConnection()

    self.Maid:Clean()
    self.SelfAbilities:Destroy()
    self.Hazards:Destroy()
    self.Route:Destroy()
    self.ESP:Destroy()
    self.PathESP:Destroy()
    self.TacticalDisplay:Destroy()
    self.TargetHealth:Destroy()
    self.HUD:Destroy()
    self.Character:Destroy()

    if self.Character.Humanoid then
        pcall(function()
            self.Character.Humanoid:Move(Vector3.zero, false)
        end)
    end

    getgenv().UIW = nil
    getgenv().UNDERWORLD_AI = nil

    log("Destroyed")
end

