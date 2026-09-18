-- v44.11: auto-execute can run before the game has loaded; wait for the
-- player, PlayerGui and Backpack first.
do
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    local players = game:GetService("Players")
    while not players.LocalPlayer do
        task.wait(0.1)
    end
    local player = players.LocalPlayer
    player:WaitForChild("PlayerGui", 60)
    player:WaitForChild("Backpack", 60)
    local waited = 0
    while not player.Character and waited < 30 do
        task.wait(0.25)
        waited += 0.25
    end
    task.wait(0.5)
end

if getgenv().UIW then
    pcall(function()
        getgenv().UIW:Destroy()
    end)
elseif getgenv().UNDERWORLD_AI then
    pcall(function()
        getgenv().UNDERWORLD_AI:Destroy()
    end)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    WalkSpeed = 16,

    DesiredCombatRange = 42,
    MinimumCombatRange = 22,
    BossCombatRange = 28,
    BossMinimumRange = 19,
    BossApproachDistance = 38,

    -- Ice Crash's replicated hitbox template reaches about 66 studs forward.
    DamageCastRange = 64,

    -- Stop just outside the attack zone until the next Q/E sequence is ready.
    PreAggroHoldDistance = 72,
    AttackCommitWindow = 2.75,

    AggressiveApproachDistance = 52,

    -- v40 boss band: attack from inside cast range without hugging the boss.
    BossMinRange = 30,
    BossIdealRange = 44,
    BossMaxRange = 56,

    -- v40 staging + hit & run for normal mobs.
    StageDistance = 84,          -- wait between DamageCastRange and this until skills are ready
    HitAndRun = true,            -- back off after casting while damage skills recover
    RetreatDistance = 74,        -- back off until at least this far from the target
    RetreatResumeWait = 0.6,     -- stop backing off when damage is this close to ready

    -- Demon Warrior behavior.
    MeleeSafetyRadius = 34,
    MeleeEmergencyRadius = 24,
    MeleePanicExitRadius = 32,
    ProximitySafetyBonus = 8,
    ProximityEmergencyBonus = 6,
    MeleeClusterPanicRadius = 27,
    MeleeClusterPanicCount = 2,
    MeleeHardNoGoRadius = 15,
    MeleeOrbitInner = 30,
    MeleeOrbitOuter = 40,
    MultiMeleeRadius = 46,
    MeleeTravelOverrideDistance = 58,

    GoalChangeThreshold = 18,
    DirectPathDistance = 42,

    -- Navigation v2: one authoritative Roblox path.
    PathAgentRadius = 2.75, -- v39: was 2.25; keeps routes further off walls/corners

    PathAgentHeight = 5,
    PathWaypointSpacing = 4,
    PathWaypointStartRadius = 2,
    PathPlaneVelocityMultiplier = 0.0625,
    PathPlaneMinThreshold = 1.0,
    PathGoalReachDistance = 3.5,
    ProgressionCheckpointReachDistance = 2.25,
    ProgressionProbeRetry = 0.45,
    ProgressionFrontierReachDistance = 5.0,
    ProgressionFrontierProbeRadii = {24, 40, 58},
    ProgressionFrontierMinProgress = 3.0,
    ProgressionFrontierProbeBudget = 3,
    ProgressionFrontierCacheTTL = 1.15,
    ProgressionFrontierFailureCacheTTL = 0.55,
    PathJumpRetry = 0.40,
    PathStuckRepathTime = 0.70,
    PathRecomputeThrottle = 0.30,

    -- NoPath recovery.
    NoPathRetryInterval = 0.80,
    NoPathRetryMaxInterval = 3.20,
    NoPathHeavyFallbackCooldown = 2.00,
    NoPathGridStep = 5,
    NoPathGridMargin = 90,
    NoPathGridMaxSpan = 430,
    NoPathGridProbeAbove = 85,
    NoPathGridProbeDepth = 240,
    NoPathExpectedHeightTolerance = 14.0,
    NoPathGroundSurfaceScanLimit = 16,
    NoPathGridMinNormalY = 0.35,
    NoPathGridMaxStepHeight = 5.25,
    NoPathGridMaxNodes = 5000,
    DirectGroundCorridorMaxDistance = 220,
    DirectGroundCorridorStep = 12,
    DirectGroundCorridorProbeAbove = 20,
    NoPathGridJumpRise = 2.75,
    NoPathEdgeProbeAbove = 10,
    NoPathEdgeProbeDepth = 25,
    NoPathEdgeHeightTolerance = 3.25,

    -- Navigation/combat handoff.
    TravelRouteDetourDot = 0.78,
    TravelDirectProbeDistance = 24,

    NavigationEnterDistance = 82,
    NavigationExitDistance = 72,
    NavigationExitConfirmTime = 0.22,

    NavigationAutoJumpCooldown = 0.55,

    GroundProbeDepth = 16,

    EdgeHardPadding = 10,
    EdgeWarningPadding = 16,
    EdgeCacheTTL = 0.16,
    EdgeCacheCell = 2,

    BodyPaddingXZ = 1.25,
    BodyPaddingY = 0.25,

    HazardPaddingXZ = 2.35,
    HazardPaddingY = 0.8,

    DodgeDistance = 12,
    DodgeCommitTime = 0.24,
    DodgeReleaseGrace = 0.12,
    DodgeReuseProbeDistance = 7,
    DangerLookaheadDistance = 12,
    PrecastLookaheadTime = 0.90,
    PrecastSafetyPadding = 2.25,
    PrecastColumnHeight = 7,
    PrecastThinHeight = 2.5,

    ProjectilePredictionHorizon = 1.15,
    ProjectilePredictionStep = 0.06,
    ProjectileVelocityMin = 4,
    ProjectileVelocitySmoothing = 0.55,
    ProjectileExtraPaddingXZ = 2.20,
    ProjectileExtraPaddingY = 0.6,

    AuraRadius = 34,
    AuraScanRadii = {3, 6, 10, 15, 21, 28, 34},
    AuraDotsPerRing = 20,
    AuraRingStepTime = 0.22,
    MobGroupDotCount = 24,
    TacticalVisualInterval = 0.22,
    PathVisualInterval = 0.25,

    -- Enchanted Forest / Crystal Golem mechanics.
    GolemRockPickupRadius = 7.0,
    GolemRockPickupDwell = 0.18,
    GolemRockPlaceRadius = 8.0,
    GolemRockPlaceRetry = 2.25,
    GolemOrbitInner = 31,
    GolemOrbitOuter = 50,
    GolemOrbKiteBias = 0.42,
    GolemForcedRegionInset = 2.0,
    GolemSweeperLeadDistance = 18,
    GolemSweeperEndpointPadding = 10,

    DodgeSolveInterval = 1 / 20,
    RouteRiskInterval = 1 / 10,
    HazardCacheInterval = 1 / 20,
    TargetRefreshInterval = 0.10,
    WorldRefreshInterval = 0.35,

    HazardVisualScanInterval = 0.075,
    HazardSpawnGrace = 0.20,
    HazardInactiveGrace = 0.12,
    TouchDangerWindow = 1.6,     -- v40: seconds after spawn an armed (touch) hitbox counts as live
    NoCastWhileEscaping = false, -- v40: tested; blocked most casts during rain phases
    LaneBallMinSize = 10,        -- v40: 17-stud "Model" balls that fly down lanes
    LaneMemory = 10,             -- seconds a lane warning is remembered
    LaneBallDelayMin = 5.0,      -- a ball appears this long after its lane warning...
    LaneBallDelayMax = 9.0,      -- ...at most this long
    LaneBallMovingSpeed = 20,    -- above this speed the corridor follows the ball's direction
    LaneCorridorHalfLength = 250,
    LaneCorridorExtraWidth = 1.5,
    -- v42 attack windows
    LaneLaserLifetime = 6.2,     -- Water Lines: the 16x150 lane is dangerous for its whole life
    OrbCorridorLength = 260,     -- Water Orbs fly toward where you were when they spawned
    TightExitPadding = 0.5,      -- padding used when searching for a gap to escape into
    CommitLeadTime = 0.4,        -- leave the staging spot this early before skills are ready
    BullseyeWindow = 1.4,        -- Cube Pylon shot: fires ~0.8-1.0 s after it appears
    BullseyeMargin = 0.4,
    TargetSwitchMargin = 15,     -- a new target must score this much better to switch

    -- v43 target scoring (lower is better; distance in studs is the base)
    PackRadius = 20,             -- enemies this close together count as a pack
    PackBonus = 8,               -- per extra enemy in the pack (max 4)
    LowHealthBonus = 30,         -- nearly dead enemies are finished first
    CloseThreatBonus = 25,       -- melee/proximity enemies already within 40 studs
    OtherLevelPenalty = 40,      -- enemies on another floor level

    -- v43 bosses and leftovers
    BossLosCheckRange = 150,     -- follow the path when the boss is out of sight within this range
    GrowthHoldTime = 1.5,        -- a growing attack stays live this long after it last grew
    GrowthLookahead = 0.8,       -- seconds of growth to avoid ahead of time
    SlamBandHalfLength = 170,    -- Protector's Slam: avoid its whole line (it grows out of the arena)
    IgnoreOrphanHazards = true,  -- leftovers with no living enemy nearby never damage
    OrphanHazardRadius = 180,

    -- v40 tanking: with high health, ignore attacks that barely hurt.
    TankEnabled = true,
    TankMaxHitFraction = 0.12,   -- only attacks that take <= 12% max health per hit
    TankHitsAssumed = 2,         -- assume you might take this many in a row
    TankHealthFloor = 0.55,      -- and still stay above 55% health
    TankMinSamples = 2,          -- hits needed before an attack type is trusted
    EngageMaxHeightDiff = 8,     -- v41: targets further above/below are reached by path first
    HotAreaRadius = 45,          -- v40: don't stand and wait when attacks are active this close
    HotAreaHazards = 2,

    BroadHazardSweepInterval = 0.35,
    BroadHazardSweepRadius = 260,

    ESPInterval = 1 / 4,
    ESPRenderDistance = 110,
    ESPMaxEntries = 12,
    ESPHideWhileInside = true,

    -- v39 stuck recovery / corner handling
    StuckTimeout = 0.8,          -- no progress for this long = stuck
    StuckBlockedTimeout = 0.3,   -- faster when something is directly in front
    StuckSpotRadius = 7,         -- stuck events this close count as the same spot
    StuckSpotMemory = 25,        -- seconds a stuck spot is remembered
    LoopWindow = 6,              -- seconds of back-and-forth that count as a loop
    LoopRadius = 6,              -- ...while staying inside this radius
    AvoidZoneSize = 7,
    AvoidZoneCost = 20,          -- pathfinder cost multiplier inside a stuck spot
    AvoidZoneLifetime = 60,
    MaxAvoidZones = 16,
    SavedStuckSpotsPerDungeon = 10,

    -- v39 auto retry
    ReplayDelay = 3,             -- seconds after the dungeon finishes (loot)
    ReplayAttempts = 5,
    ReplayRetryInterval = 3,
    ReplayOnDeathDelay = 6,      -- v41: replay when dead this long (solo death ends the run)

    StuckTime = 0.45,
    StuckEarlyVelocity = 1.15,
    StuckEarlyTime = 0.22,
    StuckProgressDistance = 0.85,
    StuckRecoveryDuration = 0.58,

    RouteAngles = {0, 15, -15, 30, -30, 45, -45, 60, -60, 80, -80},

    DodgeAngles = {0, 15, -15, 30, -30, 45, -45, 60, -60, 80, -80, 105, -105, 135, -135, 165, -165, 180},

    EmergencyBodyYawOffsets = {0, 45, -45, 90, -90, 135, -135, 180},

    Debug = false,

    -- v44.7 run log file (in-memory telemetry is always on).
    TelemetrySave = false,
    TelemetrySaveInterval = 20,
}

local SETTINGS_FOLDER = "UIW"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"
local AUTOEXEC_FILE = "UIW/UIW_Aura_Mage_v13.lua"

local DEFAULT_SETTINGS = {
    Enabled = true,
    AutoCombat = true,
    AutoDodge = true,
    AutoESP = true,
    AutoPathESP = true,
    AutoRetryEnabled = true,
    ShowAura = true,
    ShowMobGroups = true,
    AutoExecuteOnTeleport = false,
    LowEffects = true,
    WalkSpeed = 16,
    DesiredCombatRange = 42,
    DamageCastRange = 64,
}

-- v44: crash-safe file access. Every call is protected, the UIW folder is
-- created before writing, and a file is only rewritten when its content
-- changed and not more often than MinInterval seconds.
local SafeFile = { LastContent = {}, LastWrite = {}, MinInterval = 4 }

function SafeFile.IsFile(path)
    if type(isfile) ~= "function" then
        return false
    end
    local ok, result = pcall(isfile, path)
    return ok and result == true
end

function SafeFile.Read(path)
    if type(readfile) ~= "function" or not SafeFile.IsFile(path) then
        return nil
    end
    local ok, result = pcall(readfile, path)
    if ok and type(result) == "string" then
        return result
    end
    return nil
end

function SafeFile.EnsureFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return true
    end
    local ok, exists = pcall(isfolder, SETTINGS_FOLDER)
    if ok and exists then
        return true
    end
    pcall(makefolder, SETTINGS_FOLDER)
    local ok2, exists2 = pcall(isfolder, SETTINGS_FOLDER)
    return ok2 and exists2 == true
end

function SafeFile.Write(path, content, force)
    if type(writefile) ~= "function" or type(content) ~= "string" then
        return false
    end
    -- skip identical rewrites, but only while the file is really still there
    if SafeFile.LastContent[path] == content and SafeFile.IsFile(path) then
        return true
    end
    local now = os.clock()
    if not force and now - (SafeFile.LastWrite[path] or -math.huge) < SafeFile.MinInterval then
        return false
    end
    if not SafeFile.EnsureFolder() then
        return false
    end
    SafeFile.LastWrite[path] = now
    local ok = pcall(writefile, path, content)
    if ok then
        SafeFile.LastContent[path] = content
    end
    return ok
end

function SafeFile.ReadJson(path)
    local text = SafeFile.Read(path)
    if not text then
        return nil
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(text)
    end)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

function SafeFile.WriteJson(path, data, force)
    local ok, text = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return false
    end
    return SafeFile.Write(path, text, force)
end

local function readSettingsFile()
    if type(isfile) ~= "function" or type(readfile) ~= "function" then
        return nil, "Your executor does not support saved files"
    end
    if not SafeFile.IsFile(SETTINGS_FILE) then
        return nil, "No saved config found"
    end
    local ok, result = pcall(function()
        return HttpService:JSONDecode(SafeFile.Read(SETTINGS_FILE))
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil, "The saved config could not be read"
end

local function writeSettingsFile(settings)
    if type(writefile) ~= "function" then
        return false, "Your executor does not support saved files"
    end
    local ok = SafeFile.WriteJson(SETTINGS_FILE, settings, true)
    return ok, ok and "Config saved" or "Could not save config (check the executor workspace folder)"
end

function SafeFile.Delete(path)
    SafeFile.LastContent[path] = nil
    SafeFile.LastWrite[path] = nil
    if type(delfile) ~= "function" or not SafeFile.IsFile(path) then
        return not SafeFile.IsFile(path)
    end
    pcall(delfile, path)
    return not SafeFile.IsFile(path)
end

---------------------------------------------------------------------------
-- Named configs: UIW/configs/<name>.json
-- Script-wide switches (which config loads on start, auto execute, where
-- the script file is) live in UIW/uiw_meta.json.
---------------------------------------------------------------------------
local ConfigStore = {
    Folder = SETTINGS_FOLDER .. "/configs",
    MetaFile = SETTINGS_FOLDER .. "/uiw_meta.json",
    DefaultScriptPath = SETTINGS_FOLDER .. "/UIW.lua",
}

function ConfigStore.Supported()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function ConfigStore.CleanName(name)
    name = tostring(name or "")
    name = string.gsub(name, "[^%w%s_%-]", "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    name = string.sub(name, 1, 24)
    if name == "" then
        return nil
    end
    return name
end

function ConfigStore.PathFor(name)
    return ConfigStore.Folder .. "/" .. name .. ".json"
end

function ConfigStore.EnsureFolder()
    SafeFile.EnsureFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return
    end
    local ok, exists = pcall(isfolder, ConfigStore.Folder)
    if not (ok and exists) then
        pcall(makefolder, ConfigStore.Folder)
    end
end

function ConfigStore.List()
    local names = {}
    if type(listfiles) ~= "function" then
        return names
    end
    ConfigStore.EnsureFolder()
    local ok, files = pcall(listfiles, ConfigStore.Folder)
    if not ok or type(files) ~= "table" then
        return names
    end
    for _, file in ipairs(files) do
        local name = string.match(tostring(file), "([^/\\]+)%.json$")
        if name then
            table.insert(names, name)
        end
    end
    table.sort(names, function(a, b)
        return string.lower(a) < string.lower(b)
    end)
    return names
end

function ConfigStore.Exists(name)
    return name ~= nil and SafeFile.IsFile(ConfigStore.PathFor(name))
end

function ConfigStore.Save(name, data)
    if not ConfigStore.Supported() then
        return false, "Your executor cannot save files"
    end
    ConfigStore.EnsureFolder()
    local ok = SafeFile.WriteJson(ConfigStore.PathFor(name), data, true)
    return ok, ok and ("Saved config \"" .. name .. "\"") or "Could not write the config file"
end

function ConfigStore.Load(name)
    if not ConfigStore.Exists(name) then
        return nil, "Config \"" .. tostring(name) .. "\" not found"
    end
    local data = SafeFile.ReadJson(ConfigStore.PathFor(name))
    if not data then
        return nil, "Config \"" .. name .. "\" could not be read"
    end
    return data
end

function ConfigStore.Delete(name)
    local ok = SafeFile.Delete(ConfigStore.PathFor(name))
    if not ok then
        return false, type(delfile) == "function" and "Could not delete the config" or "Your executor cannot delete files"
    end
    return true, "Deleted config \"" .. name .. "\""
end

function ConfigStore.ReadMeta()
    local meta = SafeFile.ReadJson(ConfigStore.MetaFile) or {}
    return {
        AutoLoad = type(meta.AutoLoad) == "string" and meta.AutoLoad or "",
        AutoExecute = meta.AutoExecute == true,
        ScriptPath = type(meta.ScriptPath) == "string" and meta.ScriptPath or nil,
    }
end

function ConfigStore.WriteMeta(meta)
    return SafeFile.WriteJson(ConfigStore.MetaFile, {
        AutoLoad = meta.AutoLoad or "",
        AutoExecute = meta.AutoExecute == true,
        ScriptPath = meta.ScriptPath,
    }, true)
end

-- One-time move of the old single UIW/settings.json into the new layout.
function ConfigStore.Migrate()
    if SafeFile.IsFile(ConfigStore.MetaFile) or not SafeFile.IsFile(SETTINGS_FILE) then
        return
    end
    local old = SafeFile.ReadJson(SETTINGS_FILE)
    local meta = { AutoLoad = "", AutoExecute = false }
    if old then
        if ConfigStore.Save("default", old) then
            meta.AutoLoad = "default"
        end
        meta.AutoExecute = old.AutoExecuteOnTeleport == true
    end
    if ConfigStore.WriteMeta(meta) then
        SafeFile.Delete(SETTINGS_FILE)
    end
end

local function validNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.clamp(value, minimum, maximum)
end

local COLORS = {
    Idle = Color3.fromRGB(140, 143, 150),
    Moving = Color3.fromRGB(75, 145, 255),
    Pathing = Color3.fromRGB(240, 195, 55),
    Combat = Color3.fromRGB(255, 145, 45),
    Dodge = Color3.fromRGB(255, 55, 78),
    Emergency = Color3.fromRGB(255, 35, 35),
    Running = Color3.fromRGB(43, 205, 151),
    Melee = Color3.fromRGB(220, 85, 255),
}

local BODY_NAMES = {
    HumanoidRootPart = true, Head = true,
    UpperTorso = true, LowerTorso = true, Torso = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
    LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
    RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
    ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

local MELEE_ENEMY_NAMES = {
    ["magic minion"] = true,
    ["striker bot"] = true,
    ["sand peasant"] = true,
    ["sandstone soldier"] = true,
    ["enraged sandstone soldier"] = true,
    ["sand warlock"] = true,
    ["frost minion"] = true,
    ["ice minion"] = true,
    ["frostwalker"] = true,
    ["frostwalker soldier"] = true,
    ["tundra hunter"] = true,
    ["alpha tundra hunter"] = true,
    ["frost familiar"] = true,
    ["pirate savage"] = true,
    ["infected pirate"] = true,
    ["king's guard"] = true,
    ["hitman"] = true,
    ["demon warrior"] = true,
    ["blood minion"] = true,
    ["samurai swordsman"] = true,
    ["bodyguard"] = true,
    ["raider"] = true,
    ["fighter bot"] = true,
    ["hologram assassin"] = true,
    ["hologram warrior"] = true,
    ["aggressive lava walker"] = true,
    ["mushroom spearman"] = true,
    ["northern warrior"] = true,
    ["dracani warrior"] = true,
    ["pincer warrior"] = true,
    ["shadow imp"] = true,
    ["shadow stalker"] = true,
    ["yokai shogun"] = true,
    ["fire imp"] = true,
    ["corrupted warrior"] = true,
    ["voidskitter"] = true,
    ["eldritch reaver"] = true,
    ["corrupted growth"] = true,
    ["elite queensguard"] = true,
    ["draugr warrior"] = true,
}

local PROXIMITY_THREAT_NAMES = {
    ["elite swordsman"] = true,
    ["burly enforcer"] = true,
    ["bomb drone"] = true,
    ["explosive lava walker"] = true,
    ["temple guard"] = true,
    ["dracani knight"] = true,
}

local function normalizeEnemyName(name)
    return string.lower(tostring(name or ""))
end

-- v42: mini-bosses live in normal rooms (e.g. Aquatic Temple room 2 and 6),
-- so "boss" is decided by name, not only by the boss room.
local MINI_BOSS_NAMES = {
    ["temple core generator"] = true,
    ["ancient temple protector"] = true,
    ["sea king"] = true,
    ["crystal golem"] = true,
    ["cannon blaster 2000"] = true,
}

local function isBossEnemy(enemy)
    if not enemy then
        return false
    end
    if tonumber(enemy.Room) == 999 then
        return true
    end
    return enemy.Model ~= nil and MINI_BOSS_NAMES[normalizeEnemyName(enemy.Model.Name)] == true
end

local function getEnemyThreatClass(enemy)
    if not enemy or not enemy.Model then
        return nil
    end
    local lower = normalizeEnemyName(enemy.Model.Name)
    if MELEE_ENEMY_NAMES[lower] or string.find(lower, "magic minion", 1, true) then
        return "Melee"
    end
    if PROXIMITY_THREAT_NAMES[lower] then
        return "Proximity"
    end
    return nil
end

local SPECIAL_HAZARD_CONTAINERS = {
    -- The Canals / Mage Overlord.
    magebossstrraightshot = true,
    magebossstraightshot = true,
    magehorizontalbeam = true,
    mageprojectileball = true,
    magebossminionspawneffect = true,

    overgrowthlonglinespikes = true,
    overgrowthspikes = true,

    -- Orbital Outpost / Lord Varosh
    thirdbosscirclehit = true,
    thirdbosscirclehit2 = true,
    thirdbosslifestealbeams = true,
    thirdbosslifestealhitbox = true,
    thirdbossrandomline = true,
    thirdbossorbshot = true,
    thirdbosspassiveorb = true,

    -- Volcanic Chambers / Lava King
    thirdbossdualswingline = true,
    thirdbossspreadline = true,
    thirdbosslavaline = true,
    thirdbosscrescent = true,
    thirdbossfirewall = true,
    thirdbossflamewall = true,
    thirdbossflamewallhitbox = true,

    -- Enchanted Forest mobs / bosses
    mushroomwizardshot = true,
    poisoncircle = true,
    battlemageorb = true,

    firstbosscrystal = true,
    firstbosscrystaldrop = true,
    firstbossspinningrockhitbox = true,
    enchantedfirstbossfolloworb = true,
    golemrockclap = true,
    golemrockthrow = true,
    golemrockthrowsmall = true,

    spiritorb = true,
    spiritstrike = true,
}

local HAZARD_NAME_HINTS = {
    "hitbox", "hit box", "damage", "precast", "projectile", "orb", "beam", "laser",
    "line", "circle", "slam", "shot", "missile", "rocket", "blast", "explosion",
    "strike", "swing", "wave", "spike", "geyser", "flame", "fire", "life steal",
    "lifesteal", "stun", "focus", "barrage", "pulse", "crescent", "throw", "clap",
}

local function hasHazardNameHint(name)
    local lower = string.lower(tostring(name or ""))
    for _, hint in ipairs(HAZARD_NAME_HINTS) do
        if string.find(lower, hint, 1, true) then
            return true
        end
    end
    return false
end

local function isBossAttackContainerName(name)
    local lower = string.lower(tostring(name or ""))
    if SPECIAL_HAZARD_CONTAINERS[lower] then
        return true
    end
    if string.find(lower, "boss", 1, true) and hasHazardNameHint(lower) then
        return true
    end
    return false
end

local function getBroadHazardContainer(instance)
    local current = instance
    while current and current ~= Workspace do
        if isBossAttackContainerName(current.Name) then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getSpecialHazardContainer(instance)
    local current = instance
    while current and current ~= Workspace do
        if SPECIAL_HAZARD_CONTAINERS[string.lower(current.Name)] then
            return current
        end
        current = current.Parent
    end
    return nil
end

local SAFE_ZONE_SINGLE_CONTAINER_NAMES = {
    thirdbosssafespot = true,
    thirdbossmemorysafezone = true,
}

local SAFE_ZONE_MULTI_CONTAINER_NAMES = {
    thirdbossmasssafespotcircles = true,
}

local SAFE_ZONE_NONDESTINATION_CONTAINER_NAMES = {
    thirdbosssafespotspawns = true,
    finalbossobjectspawns = true,
}

local SAFE_ZONE_STANDALONE_PART_NAMES = {
    safespotcircle = true,
}

local function getNamedAncestor(instance, names)
    local current = instance
    while current and current ~= Workspace do
        if names[string.lower(current.Name or "")] then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function getSafeZoneSingleAncestor(instance)
    return getNamedAncestor(instance, SAFE_ZONE_SINGLE_CONTAINER_NAMES)
end

local function getSafeZoneMultiAncestor(instance)
    return getNamedAncestor(instance, SAFE_ZONE_MULTI_CONTAINER_NAMES)
end

local function getSafeZoneSpawnAncestor(instance)
    return getNamedAncestor(instance, SAFE_ZONE_NONDESTINATION_CONTAINER_NAMES)
end

local function isStandaloneSafeZonePart(instance)
    return instance
        and instance:IsA("BasePart")
        and SAFE_ZONE_STANDALONE_PART_NAMES[string.lower(instance.Name or "")] == true
end

local function hasEnabledSafeZoneBeam(instance)
    if not instance then
        return false
    end
    for _, descendant in ipairs(instance:GetDescendants()) do
        if descendant:IsA("Beam") and descendant.Enabled then
            return true
        end
    end
    return false
end

local function isSafeZoneDestinationPart(instance)
    if not instance or not instance:IsA("BasePart") then
        return false
    end
    if isStandaloneSafeZonePart(instance) then
        return hasEnabledSafeZoneBeam(instance)
    end
    local single = getSafeZoneSingleAncestor(instance)
    if single then
        return string.lower(instance.Name or "") == "precast"
    end
    local multi = getSafeZoneMultiAncestor(instance)
    if multi then
        return string.lower(instance.Name or "") == "precast"
    end
    return false
end

local function hasActiveMemorySafeZone()
    local safe = Workspace:FindFirstChild("thirdBossMemorySafeZone")
    if not safe then
        return false
    end
    local precast = safe:FindFirstChild("precast", true)
    return precast
        and precast:IsA("BasePart")
        and precast.Parent ~= nil
        and precast.Transparency < 0.98
end

local function isManagedSafeZoneMechanicInstance(instance)
    if not instance then
        return false
    end
    if isStandaloneSafeZonePart(instance) then
        return true
    end
    if getSafeZoneSingleAncestor(instance)
        or getSafeZoneMultiAncestor(instance)
        or getSafeZoneSpawnAncestor(instance)
    then
        return true
    end
    local current = instance
    while current and current ~= Workspace do
        if string.lower(current.Name or "") == "thirdbossmemorydamagezone" then
            return hasActiveMemorySafeZone()
        end
        current = current.Parent
    end
    return false
end

local CRYSTAL_GOLEM_UTILITY_ROOT_NAMES = {
    firstbossbuildzones = true,
    firstbosssafezones = true,
    firstbosssupplymodels = true,
    firstbosscrystaldroppart = true,
    firstbosscrystaldrop = true,
}

local function isCrystalGolemUtilityInstance(instance)
    local current = instance
    while current and current ~= Workspace do
        if CRYSTAL_GOLEM_UTILITY_ROOT_NAMES[string.lower(current.Name or "")] then
            return true
        end
        current = current.Parent
    end
    return false
end

local function isNonHazardMechanicInstance(instance)
    return isManagedSafeZoneMechanicInstance(instance)
        or isCrystalGolemUtilityInstance(instance)
end

local function getEntryAncestor(instance)
    local current = instance
    while current do
        local lower = string.lower(current.Name or "")
        if string.find(lower, "entry", 1, true) then
            return current
        end
        if current == Workspace then
            break
        end
        current = current.Parent
    end
    return nil
end

local function isEntryInstance(instance)
    return getEntryAncestor(instance) ~= nil
end

local function getAncestorTool(instance)
    local current = instance
    while current and current ~= Workspace do
        if current:IsA("Tool") then
            return current
        end
        current = current.Parent
    end
    return nil
end

local function isLocalPlayerOwnedInstance(instance)
    if not instance then
        return false
    end
    local player = Players.LocalPlayer
    if not player then
        return false
    end
    local character = player.Character
    if character and (instance == character or instance:IsDescendantOf(character)) then
        return true
    end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack and (instance == backpack or instance:IsDescendantOf(backpack)) then
        return true
    end
    local tool = getAncestorTool(instance)
    if tool then
        if character and tool:IsDescendantOf(character) then
            return true
        end
        if backpack and tool:IsDescendantOf(backpack) then
            return true
        end
        if tool.Parent == player then
            return true
        end
    end
    return false
end

local LOCAL_PLAYER_EFFECT_ROOT_NAMES = {
    ["traiiblazings"] = true,
    ["piercing roots"] = true,
    ["piercingrootshitbox"] = true,
    ["ice crash"] = true,
}

local STATIC_DUNGEON_ROOT_NAMES = {
    ["map"] = true,
    ["borders"] = true,
}

local function getWorkspaceRoot(instance)
    local current = instance
    while current and current.Parent and current.Parent ~= Workspace do
        current = current.Parent
    end
    return current
end

local function isDetachedLocalPlayerEffect(instance)
    local root = getWorkspaceRoot(instance)
    if not root then
        return false
    end
    return LOCAL_PLAYER_EFFECT_ROOT_NAMES[string.lower(root.Name or "")] == true
end

local function isStaticDungeonGeometry(instance)
    local root = getWorkspaceRoot(instance)
    if not root then
        return false
    end
    return STATIC_DUNGEON_ROOT_NAMES[string.lower(root.Name or "")] == true
end

local function log(...)
    if CONFIG.Debug then
        print("[UIW]", ...)
    end
end

local function safeDestroy(object)
    if object then
        pcall(function()
            object:Destroy()
        end)
    end
end

local function flatten(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function unit(v)
    local m = v.Magnitude
    if m <= 0.001 then
        return Vector3.zero
    end
    return v / m
end

local function rotateXZ(v, degrees)
    local r = math.rad(degrees)
    local c = math.cos(r)
    local s = math.sin(r)
    return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c)
end

local function directionToYaw(direction)
    direction = unit(flatten(direction))
    if direction.Magnitude <= 0 then
        return 0
    end
    return math.atan2(-direction.X, -direction.Z)
end

local function angleDifference(a, b)
    return math.atan2(math.sin(a - b), math.cos(a - b))
end

local function shortNumber(value)
    if value >= 1e9 then
        return string.format("%.2fB", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.2fM", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.1fK", value / 1e3)
    end
    return tostring(math.floor(value))
end

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({ Tasks = {} }, Maid)
end

function Maid:Give(taskObject)
    table.insert(self.Tasks, taskObject)
    return taskObject
end

function Maid:Clean()
    for _, taskObject in ipairs(self.Tasks) do
        if typeof(taskObject) == "RBXScriptConnection" then
            pcall(function()
                taskObject:Disconnect()
            end)
        elseif typeof(taskObject) == "Instance" then
            safeDestroy(taskObject)
        elseif type(taskObject) == "function" then
            pcall(taskObject)
        end
    end
    table.clear(self.Tasks)
end

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new()
    return setmetatable({
        Character = nil,
        Humanoid = nil,
        Root = nil,
        BodySize = Vector3.new(4.5, 5, 2),
        BodyOffset = Vector3.zero,
        FacingAttachment = nil,
        FacingOrientation = nil,
        DesiredYaw = 0,
        OriginalAutoRotate = true,
    }, CharacterService)
end

function CharacterService:IsAlive()
    return self.Character
        and self.Character.Parent
        and self.Humanoid
        and self.Humanoid.Health > 0
        and self.Root
        and self.Root.Parent
end

function CharacterService:CalculateBodyBounds()
    if not self.Character or not self.Root then
        return
    end

    local rootCF = self.Root.CFrame
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local found = false

    for _, part in ipairs(self.Character:GetChildren()) do
        if part:IsA("BasePart") and BODY_NAMES[part.Name] then
            found = true
            local half = part.Size * 0.5
            for _, x in ipairs({-half.X, half.X}) do
                for _, y in ipairs({-half.Y, half.Y}) do
                    for _, z in ipairs({-half.Z, half.Z}) do
                        local worldPoint = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
                        local p = rootCF:PointToObjectSpace(worldPoint)
                        minX = math.min(minX, p.X)
                        minY = math.min(minY, p.Y)
                        minZ = math.min(minZ, p.Z)
                        maxX = math.max(maxX, p.X)
                        maxY = math.max(maxY, p.Y)
                        maxZ = math.max(maxZ, p.Z)
                    end
                end
            end
        end
    end

    if not found then
        self.BodySize = Vector3.new(4.5, 5, 2)
        self.BodyOffset = Vector3.zero
        return
    end

    self.BodySize = Vector3.new(
        math.max(2, maxX - minX),
        math.max(4, maxY - minY),
        math.max(1.4, maxZ - minZ)
    )

    self.BodyOffset = Vector3.new(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
end

function CharacterService:DestroyFacing()
    safeDestroy(self.FacingOrientation)
    safeDestroy(self.FacingAttachment)
    self.FacingOrientation = nil
    self.FacingAttachment = nil
end

function CharacterService:SetupFacing()
    if not self.Root or not self.Humanoid then
        return
    end

    self:DestroyFacing()

    self.OriginalAutoRotate = self.Humanoid.AutoRotate
    self.Humanoid.AutoRotate = false

    local attachment = Instance.new("Attachment")
    attachment.Name = "UIWFacingAttachment"
    attachment.Parent = self.Root

    local align = Instance.new("AlignOrientation")
    align.Name = "UIWFacing"
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.RigidityEnabled = false
    align.Responsiveness = 50
    align.MaxTorque = math.huge
    align.Parent = self.Root

    self.FacingAttachment = attachment
    self.FacingOrientation = align
end

function CharacterService:SetYaw(yaw)
    self.DesiredYaw = yaw

    if not self.FacingOrientation or not self.FacingOrientation.Parent then
        self:SetupFacing()
    end

    if self.FacingOrientation then
        self.FacingOrientation.CFrame = CFrame.Angles(0, yaw, 0)
    end
end

function CharacterService:ReleaseAutomationFacing()
    if self.Humanoid then
        self.Humanoid.AutoRotate = self.OriginalAutoRotate ~= false
    end
    self:DestroyFacing()
end

function CharacterService:FacePosition(position)
    if not self:IsAlive() then
        return
    end
    local direction = flatten(position - self.Root.Position)
    if direction.Magnitude <= 0.05 then
        return
    end
    self:SetYaw(directionToYaw(direction))
end

function CharacterService:Refresh()
    local character = LocalPlayer.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return false
    end

    local changed = character ~= self.Character

    self.Character = character
    self.Humanoid = humanoid
    self.Root = root

    if humanoid.WalkSpeed < CONFIG.WalkSpeed then
        humanoid.WalkSpeed = CONFIG.WalkSpeed -- only raise; keeps speed buffs
    end

    if changed then
        self:CalculateBodyBounds()
        self:SetupFacing()
    end

    return true
end

function CharacterService:Destroy()
    if self.Humanoid then
        pcall(function()
            self.Humanoid.AutoRotate = self.OriginalAutoRotate
        end)
    end
    self:DestroyFacing()
end

local SelfAbilityTracker = {}
SelfAbilityTracker.__index = SelfAbilityTracker

function SelfAbilityTracker.new()
    return setmetatable({
        Ignore = setmetatable({}, { __mode = "k" }),
        LastLocalCast = {},
        Maid = Maid.new(),
    }, SelfAbilityTracker)
end

function SelfAbilityTracker:RegisterCast(slot)
    self.LastLocalCast[slot] = os.clock()
end

function SelfAbilityTracker:MarkOwn(instance)
    if instance then
        self.Ignore[instance] = true
    end
end

function SelfAbilityTracker:IsOwn(instance)
    if not instance then
        return false
    end
    if self.Ignore[instance] then
        return true
    end
    local current = instance
    while current and current ~= Workspace do
        if self.Ignore[current] then
            return true
        end
        current = current.Parent
    end
    return false
end

function SelfAbilityTracker:Start()
    self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "genericNeonBall" then
            return
        end
        local castTime = self.LastLocalCast.e
        if not castTime then
            return
        end
        local age = os.clock() - castTime
        if age >= 0 and age <= 1.65 then
            self:MarkOwn(child)
        end
    end))
end

function SelfAbilityTracker:Destroy()
    self.Maid:Clean()
end

local HazardTracker = {}
HazardTracker.__index = HazardTracker

function HazardTracker.new(characterService, selfTracker)
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Include

    return setmetatable({
        CharacterService = characterService,
        SelfTracker = selfTracker,
        Hazards = setmetatable({}, { __mode = "k" }),
        ContainerState = setmetatable({}, { __mode = "k" }),
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
    for _, data in ipairs(self.CachedWarnings or {}) do
        local count = math.max(1, math.ceil(distance / 2))
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

    if self:IsPrecastPart(part) then return true end

    if self:IsLaneBall(part) then return true end

    local lower = string.lower(part.Name)

    if lower == "hitbox"
        or lower == "hitboxpart"
        or lower == "precast"
        or string.find(lower, "hitbox", 1, true)
        or string.find(lower, "precast", 1, true)
    then
        return true
    end

    local broadContainer = getBroadHazardContainer(part)

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
            for _, delayTime in ipairs({0.03, 0.12}) do
                task.delay(delayTime, function()
                    if instance.Parent then self:Register(instance) end
                end)
            end
            task.defer(function()
                if not instance.Parent
                    or isNonHazardMechanicInstance(instance)
                    or isLocalPlayerOwnedInstance(instance)
                    or isDetachedLocalPlayerEffect(instance)
                then
                    return
                end

                self:Register(instance)

                local broad = getBroadHazardContainer(instance)
                if broad then
                    self:RegisterAttackContainer(broad)
                end

                local special = getSpecialHazardContainer(instance)
                if special then
                    self:RegisterSpecialContainer(special)
                end
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

    local step = 2.25
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

local HitboxESP = {}
HitboxESP.__index = HitboxESP

function HitboxESP.new(hazardTracker)
    local folder = Instance.new("Folder")
    folder.Name = "UIW_HitboxESP"
    folder.Parent = Workspace

    return setmetatable({
        HazardTracker = hazardTracker,
        Folder = folder,
        Entries = {},
        EntryConnections = {},
        Enabled = true,
        LastUpdate = 0,
    }, HitboxESP)
end

function HitboxESP:GetContainer(part)
    return self.HazardTracker:GetContainer(part)
end

function HitboxESP:IsContainerVisuallyActive(container)
    return self.HazardTracker:IsContainerActive(container, os.clock())
end

function HitboxESP:IsContainerStableActive(container, now)
    return self.HazardTracker:IsContainerActive(container, now)
end

function HitboxESP:GetDistanceToPart(part, point)
    local p = part.CFrame:PointToObjectSpace(point)
    local h = part.Size * 0.5

    local dx = math.max(math.abs(p.X) - h.X, 0)
    local dy = math.max(math.abs(p.Y) - h.Y, 0)
    local dz = math.max(math.abs(p.Z) - h.Z, 0)

    return Vector3.new(dx, dy, dz).Magnitude
end

function HitboxESP:Create(part)
    if self.Entries[part] or not part or not part.Parent then
        return
    end

    local box = Instance.new("SelectionBox")
    box.Name = "UIWHitboxOutline"
    box.Adornee = part
    box.LineThickness = 0.025
    box.SurfaceTransparency = 1

    if string.find(string.lower(part.Name), "precast") then
        box.Color3 = Color3.fromRGB(255, 190, 65)
        box.SurfaceColor3 = Color3.fromRGB(255, 190, 65)
    else
        box.Color3 = Color3.fromRGB(255, 65, 85)
        box.SurfaceColor3 = Color3.fromRGB(255, 65, 85)
    end

    box.Parent = self.Folder
    self.Entries[part] = box

    self.EntryConnections[part] = part.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            self:Remove(part)
        end
    end)
end

function HitboxESP:Remove(part)
    local connection = self.EntryConnections[part]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        self.EntryConnections[part] = nil
    end

    safeDestroy(self.Entries[part])
    self.Entries[part] = nil
end

function HitboxESP:Update(force)
    local now = os.clock()
    if not force and now - self.LastUpdate < CONFIG.ESPInterval then
        return
    end
    self.LastUpdate = now

    if not self.Enabled then
        for part in pairs(self.Entries) do
            self:Remove(part)
        end
        return
    end

    local character = self.HazardTracker.CharacterService
    local root = character.Root
    local rootPosition = root and root.Position

    if not rootPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position

    local candidates = {}

    for _, hazard in ipairs(self.HazardTracker:GetActive()) do
        local part = hazard.Part

        if part and part.Parent then
            local distance = self:GetDistanceToPart(part, rootPosition)
            local inside = distance <= 0.05

            if not inside and cameraPosition then
                inside = self:GetDistanceToPart(part, cameraPosition) <= 0.05
            end

            if distance <= CONFIG.ESPRenderDistance
                and (not CONFIG.ESPHideWhileInside or not inside)
            then
                candidates[#candidates + 1] = {
                    Part = part,
                    Distance = distance,
                }
            end
        end
    end

    if #candidates > 1 then
        table.sort(candidates, function(a, b)
            return a.Distance < b.Distance
        end)
    end

    local seen = {}
    local maxEntries = math.min(CONFIG.ESPMaxEntries, #candidates)

    for i = 1, maxEntries do
        local part = candidates[i].Part
        seen[part] = true

        if not self.Entries[part] then
            self:Create(part)
        end
    end

    for part in pairs(self.Entries) do
        if not part.Parent or not seen[part] then
            self:Remove(part)
        end
    end
end

function HitboxESP:Destroy()
    for part in pairs(self.Entries) do
        self:Remove(part)
    end
    safeDestroy(self.Folder)
end

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
    local goalDelta = flatten(goal - root.Position)
    local effectiveReachDistance = tonumber(reachDistance) or CONFIG.PathGoalReachDistance

    if goalDelta.Magnitude <= effectiveReachDistance then
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

local DodgeSolver = {}
DodgeSolver.__index = DodgeSolver

function DodgeSolver.new(characterService, hazards, geometry, dungeon)
    return setmetatable({
        CharacterService = characterService,
        Hazards = hazards,
        Geometry = geometry,
        Dungeon = dungeon,

        LastSolve = 0,
        CachedDirection = Vector3.zero,
        CachedYaw = 0,
        CachedEmergency = false,
        CachedDodging = false,

        LastMovement = Vector3.zero,
        OrbitSign = 1,
        LastOrbitFlip = 0,
        IsDodging = false,
        MeleePanicActive = false,
        TravelMode = true,
        TravelExitCandidateSince = 0,
        CooldownHold = false,
        ForceRouteMovement = false,
        ForcedRegionPart = nil,
        CommittedDodgeDirection = Vector3.zero,
        DodgeCommitUntil = 0,
        LastDangerTime = 0,
        CurrentSolveEnemy = nil,
    }, DodgeSolver)
end

function DodgeSolver:IsPointInsideForcedRegion(position)
    local part = self.ForcedRegionPart

    if not part or not part.Parent or not part:IsA("BasePart") then
        return false
    end

    local localPoint = part.CFrame:PointToObjectSpace(position)

    local inset = math.min(
        CONFIG.GolemForcedRegionInset,
        math.min(part.Size.X, part.Size.Z) * 0.18
    )

    local halfX = math.max(part.Size.X * 0.5 - inset, part.Size.X * 0.25)
    local halfZ = math.max(part.Size.Z * 0.5 - inset, part.Size.Z * 0.25)

    return math.abs(localPoint.X) <= halfX
        and math.abs(localPoint.Z) <= halfZ
end

function DodgeSolver:HasCrystalGolemFollowOrb()
    for _, data in ipairs(self.Hazards:GetActive()) do
        local part = data.Part

        if part and part.Parent then
            local container = data.Container or self.Hazards:GetContainer(part)

            if container
                and string.lower(container.Name or "") == "enchantedfirstbossfolloworb"
            then
                return true
            end
        end
    end

    return false
end

function DodgeSolver:GetCrystalGolemSweeperThreatPart()
    if not self.CharacterService:IsAlive() then
        return nil
    end

    local model = Workspace:FindFirstChild("firstBossSpinningRockHitbox")

    if not model then
        return nil
    end

    local root = self.CharacterService.Root

    local bestPart = nil
    local bestPerpendicular = math.huge

    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and string.lower(part.Name or "") == "hitbox" then
            local localPoint = part.CFrame:PointToObjectSpace(root.Position)

            local thinIsX = part.Size.X <= part.Size.Z

            local thinCoord = thinIsX and localPoint.X or localPoint.Z
            local longCoord = thinIsX and localPoint.Z or localPoint.X

            local thinHalf = (thinIsX and part.Size.X or part.Size.Z) * 0.5
            local longHalf = (thinIsX and part.Size.Z or part.Size.X) * 0.5

            local insideHeight = math.abs(localPoint.Y) <= part.Size.Y * 0.5 + 5

            local insideSweepLength = math.abs(longCoord)
                <= longHalf + CONFIG.GolemSweeperEndpointPadding

            local perpendicularDistance = math.max(0, math.abs(thinCoord) - thinHalf)

            if insideHeight
                and insideSweepLength
                and perpendicularDistance <= CONFIG.GolemSweeperLeadDistance
                and perpendicularDistance < bestPerpendicular
            then
                bestPerpendicular = perpendicularDistance
                bestPart = part
            end
        end
    end

    return bestPart
end

function DodgeSolver:GetCrystalGolemSweeperEscape(enemy, targetYaw)
    if not enemy
        or not enemy.Model
        or not enemy.Root
        or not enemy.Root.Parent
        or normalizeEnemyName(enemy.Model.Name) ~= "crystal golem"
    then
        return nil
    end

    local threatPart = self:GetCrystalGolemSweeperThreatPart()

    if not threatPart then
        return nil
    end

    local root = self.CharacterService.Root

    local radial = unit(flatten(root.Position - enemy.Root.Position))

    if radial.Magnitude <= 0 then
        return nil
    end

    local counterClockwise = unit(Vector3.new(-radial.Z, 0, radial.X))

    local bestDirection = nil
    local bestScore = -math.huge

    for _, angle in ipairs({0, 15, -15, 30, -30, 50, -50, 80, -80, 110, -110}) do
        local direction = unit(rotateXZ(counterClockwise, angle))

        local score = self:ScoreCandidate(direction, counterClockwise, targetYaw)

        if score then
            local future = root.Position + direction * 7

            local localFuture = threatPart.CFrame:PointToObjectSpace(future)

            local thinIsX = threatPart.Size.X <= threatPart.Size.Z

            local futureThin = math.abs(thinIsX and localFuture.X or localFuture.Z)

            score += direction:Dot(counterClockwise) * 220
            score += futureThin * 8

            if score > bestScore then
                bestScore = score
                bestDirection = direction
            end
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end

    return nil
end

-- v40: bosses are fought from a distance band, not face-to-face.
local function bossBandError(distance)
    return math.max(0, CONFIG.BossMinRange - distance)
        + math.max(0, distance - CONFIG.BossMaxRange)
end

function DodgeSolver:GetBossBandScore(fromPosition, toPosition)
    local boss = self.CurrentSolveEnemy
    if not boss or not isBossEnemy(boss) or not boss.Root or not boss.Root.Parent then
        return 0
    end
    local before = bossBandError(flatten(boss.Root.Position - fromPosition).Magnitude)
    local after = bossBandError(flatten(boss.Root.Position - toPosition).Magnitude)
    local score = (before - after) * 120
    if after > before + 1 then
        score -= 300
    end
    return score
end

function DodgeSolver:GetBossBandError(position)
    local boss = self.CurrentSolveEnemy
    if not boss or not isBossEnemy(boss) or not boss.Root or not boss.Root.Parent then
        return 0
    end
    return bossBandError(flatten(boss.Root.Position - position).Magnitude)
end

function DodgeSolver:IsMeleeEnemy(enemy)
    return getEnemyThreatClass(enemy) ~= nil
end

function DodgeSolver:GetSafeOrbitTangent(toward, targetYaw)
    local root = self.CharacterService.Root
    local baseTangent = Vector3.new(-toward.Z, 0, toward.X)

    local right = unit(baseTangent)
    local left = -right

    local function sideSafe(direction)
        local endpoint = root.Position + direction * 7
        return self.Geometry:IsDirectionClear(direction, 7, targetYaw)
            and self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding)
    end

    local rightSafe = sideSafe(right)
    local leftSafe = sideSafe(left)

    local desired = self.OrbitSign >= 0 and right or left
    local desiredSafe = self.OrbitSign >= 0 and rightSafe or leftSafe
    local opposite = self.OrbitSign >= 0 and left or right
    local oppositeSafe = self.OrbitSign >= 0 and leftSafe or rightSafe

    if not desiredSafe and oppositeSafe then
        self.OrbitSign = -self.OrbitSign
        self.LastOrbitFlip = os.clock()
        return opposite
    end

    if desiredSafe then
        return desired
    end

    if oppositeSafe then
        self.OrbitSign = -self.OrbitSign
        self.LastOrbitFlip = os.clock()
        return opposite
    end

    return desired
end

function DodgeSolver:GetNearestLiveEnemyDistance()
    if not self.CharacterService:IsAlive() then
        return math.huge
    end

    local root = self.CharacterService.Root
    local nearest = math.huge

    for _, candidate in ipairs(self.Dungeon:GetAliveEnemies()) do
        if candidate
            and candidate.Root
            and candidate.Root.Parent
            and candidate.Humanoid
            and candidate.Humanoid.Health > 0
        then
            local distance = flatten(candidate.Root.Position - root.Position).Magnitude
            if distance < nearest then
                nearest = distance
            end
        end
    end

    return nearest
end

function DodgeSolver:UpdateNavigationMode(routeDirection, enemy, targetYaw)
    -- v41: target on another level / out of sight: keep following the path.
    if self.TargetBlocked then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local nearestDistance = self:GetNearestLiveEnemyDistance()

    if nearestDistance > CONFIG.NavigationEnterDistance then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    if nearestDistance > CONFIG.NavigationExitDistance then
        self.TravelExitCandidateSince = 0
        return self.TravelMode
    end

    if not enemy or not enemy.Root or not enemy.Root.Parent then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    routeDirection = unit(flatten(routeDirection))

    if routeDirection.Magnitude <= 0 then
        self.TravelExitCandidateSince = 0
        return self.TravelMode
    end

    local root = self.CharacterService.Root
    local toEnemy = flatten(enemy.Root.Position - root.Position)
    local toward = unit(toEnemy)

    if toward.Magnitude <= 0 then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local routeDot = routeDirection:Dot(toward)

    local probeDistance = math.min(toEnemy.Magnitude, CONFIG.TravelDirectProbeDistance)

    local directClear = self.Geometry:IsDirectionClear(toward, probeDistance, targetYaw)

    if not directClear or routeDot < CONFIG.TravelRouteDetourDot then
        self.TravelMode = true
        self.TravelExitCandidateSince = 0
        return true
    end

    local now = os.clock()

    if self.TravelMode then
        if self.TravelExitCandidateSince <= 0 then
            self.TravelExitCandidateSince = now
            return true
        end

        if now - self.TravelExitCandidateSince < CONFIG.NavigationExitConfirmTime then
            return true
        end
    end

    self.TravelMode = false
    self.TravelExitCandidateSince = 0
    return false
end

function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
    routeDirection = unit(flatten(routeDirection))

    if self.ForceRouteMovement then
        return routeDirection
    end

    local navigating = self:UpdateNavigationMode(routeDirection, enemy, targetYaw)

    local meleeTravelOverride = false

    if navigating and enemy and enemy.Root and enemy.Root.Parent then
        local threatClass = getEnemyThreatClass(enemy)

        if threatClass then
            local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
            local overrideDistance = CONFIG.MeleeTravelOverrideDistance

            if threatClass == "Proximity" then
                overrideDistance += CONFIG.ProximitySafetyBonus
            end

            -- STAIRS/WALL FIX: Do not pull off the yellow path if a wall is in the way!
            local toward = unit(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
            local directClear = true
            if toward.Magnitude > 0 then
                directClear = self.Geometry:IsDirectionClear(toward, math.min(distance, overrideDistance), targetYaw)
            end

            if distance <= overrideDistance and directClear and not self.TargetBlocked then
                meleeTravelOverride = true
                self.TravelMode = false
                self.TravelExitCandidateSince = 0
            end
        end
    end

    -- v40 hit & run: back away from the target while damage skills recover.
    if self.RetreatActive and enemy and enemy.Root and enemy.Root.Parent then
        local away = unit(flatten(self.CharacterService.Root.Position - enemy.Root.Position))
        if away.Magnitude > 0 then
            return unit(away - routeDirection * 0.35)
        end
    end

    -- v40: cooldown staging holds position even while navigating.
    if self.CooldownHold
        and enemy
        and not isBossEnemy(enemy)
        and not (enemy.Model and normalizeEnemyName(enemy.Model.Name) == "crystal golem")
    then
        return Vector3.zero
    end

    if navigating and not meleeTravelOverride then
        return routeDirection
    end

    if not enemy or not enemy.Root or not enemy.Root.Parent then
        return routeDirection
    end

    local root = self.CharacterService.Root
    local toEnemy = flatten(enemy.Root.Position - root.Position)
    local distance = toEnemy.Magnitude
    local toward = unit(toEnemy)

    if toward.Magnitude <= 0 then
        return routeDirection
    end

    local enemyName = enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name) or ""

    local crystalGolem = enemyName == "crystal golem"

    local bossTarget = isBossEnemy(enemy)

    if self.CooldownHold and not bossTarget and not crystalGolem then
        return Vector3.zero
    end

    local tangent = self:GetSafeOrbitTangent(toward, targetYaw)

    if crystalGolem then
        local counterClockwise = unit(Vector3.new(toward.Z, 0, -toward.X))

        if counterClockwise.Magnitude <= 0 then
            counterClockwise = tangent
        end

        local orbLive = self:HasCrystalGolemFollowOrb()

        if distance > CONFIG.GolemOrbitOuter then
            return unit(counterClockwise * 0.82 + toward * 0.72)
        elseif distance < CONFIG.GolemOrbitInner then
            return unit(counterClockwise * 1.05 - toward * 0.58)
        elseif orbLive then
            return unit(counterClockwise * 1.10 - toward * CONFIG.GolemOrbKiteBias)
        else
            return counterClockwise
        end
    end

    if bossTarget then
        -- v40: hold the boss inside [BossMinRange, BossMaxRange] (all within
        -- cast range) and circle slowly; no need to stand on top of it.
        if distance > CONFIG.BossMaxRange then
            return unit(toward * 1.45 + routeDirection * 0.35 + tangent * 0.10)
        elseif distance < CONFIG.BossMinRange then
            return unit(-toward * 1.0 + tangent * 0.70)
        else
            local correction = math.clamp((distance - CONFIG.BossIdealRange) / 12, -1, 1)
            return tangent * 0.45 + toward * (0.25 * correction)
        end
    end

    if self:IsMeleeEnemy(enemy) then
        if distance > CONFIG.MeleeOrbitOuter then
            return unit(toward * 1.02 + routeDirection * 0.72 + tangent * 0.22)
        elseif distance > CONFIG.MeleeOrbitInner then
            return unit(tangent * 0.92 + toward * 0.30 + routeDirection * 0.34)
        elseif distance > CONFIG.MeleeEmergencyRadius then
            return unit(tangent * 1.00 - toward * 0.22 + routeDirection * 0.22)
        else
            return unit(tangent * 1.00 - toward * 0.70 + routeDirection * 0.10)
        end
    end

    if distance < CONFIG.MinimumCombatRange then
        return unit(-toward * 0.72 + tangent * 0.95 + routeDirection * 0.14)
    elseif distance > CONFIG.AggressiveApproachDistance then
        return unit(toward * 1.00 + routeDirection * 0.82 + tangent * 0.06)
    elseif distance > CONFIG.DesiredCombatRange then
        return unit(toward * 0.82 + routeDirection * 0.70 + tangent * 0.12)
    else
        return unit(tangent * 0.82 + routeDirection * 0.42 + toward * 0.18)
    end
end

function DodgeSolver:GetMeleePenalty(position)
    local penalty = 0

    for _, info in ipairs(self.Dungeon:GetMeleeThreats(position, 55)) do
        local distance = info.Distance
        local safetyRadius = CONFIG.MeleeSafetyRadius
        local emergencyRadius = CONFIG.MeleeEmergencyRadius

        if info.ThreatClass == "Proximity" then
            safetyRadius += CONFIG.ProximitySafetyBonus
            emergencyRadius += CONFIG.ProximityEmergencyBonus
        end

        if distance <= CONFIG.MeleeHardNoGoRadius then
            penalty += 12000
        elseif distance <= emergencyRadius then
            penalty += 4000 + (emergencyRadius - distance) * 650
        elseif distance < safetyRadius then
            penalty += (safetyRadius - distance) * 400
        end
    end

    return penalty
end

function DodgeSolver:GetEnchantedForestLineEscapeBonus(direction)
    local root = self.CharacterService.Root

    if not root then
        return 0
    end

    local bestBonus = 0

    for _, data in ipairs(self.Hazards:GetActive()) do
        local part = data.Part

        if part and part.Parent then
            local container = data.Container or self.Hazards:GetContainer(part)
            local containerName = container and string.lower(container.Name or "") or ""

            if containerName == "mushroomwizardshot"
                or containerName == "magebossstrraightshot"
                or containerName == "magebossstraightshot"
                or containerName == "magehorizontalbeam"
            then
                local size = part.Size
                local longest = math.max(size.X, size.Z)
                local shortest = math.min(size.X, size.Z)

                if longest >= 45 and shortest <= 12 then
                    local longAxis

                    if size.X >= size.Z then
                        longAxis = flatten(part.CFrame.RightVector)
                    else
                        longAxis = flatten(part.CFrame.LookVector)
                    end

                    longAxis = unit(longAxis)

                    local perpendicularity = 1 - math.abs(direction:Dot(longAxis))

                    bestBonus = math.max(bestBonus, perpendicularity * 180)
                end
            end
        end
    end

    return bestBonus
end

function DodgeSolver:ScoreCandidate(direction, preferred, yaw)
    local rootPosition = self.CharacterService.Root.Position
    direction = unit(flatten(direction))

    local clear = self.Geometry:IsDirectionClear(direction, CONFIG.DodgeDistance, yaw)
    if not clear then
        return nil
    end

    local future = rootPosition + direction * math.min(7, CONFIG.DodgeDistance)

    if self.ForcedRegionPart
        and self:IsPointInsideForcedRegion(rootPosition)
        and not self:IsPointInsideForcedRegion(future)
    then
        return nil
    end

    if not self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding) then
        return nil
    end

    if not self.Hazards:IsTrajectoryClear(rootPosition, direction, yaw, CONFIG.DodgeDistance) then
        return nil
    end

    if not self.Hazards:IsPredictiveTrajectoryClear(rootPosition, direction, yaw, CONFIG.DodgeDistance) then
        return nil
    end

    local warningDistance = math.max(CONFIG.DodgeDistance,
        math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed) * CONFIG.PrecastLookaheadTime)
    if not self.Hazards:IsPrecastTrajectoryClear(rootPosition, direction, yaw, warningDistance) then return nil end

    local solvingBoss = self.CurrentSolveEnemy
        and isBossEnemy(self.CurrentSolveEnemy)
    local progressWeight = solvingBoss and 220
        or (self.AuraThreat and 175 or 130)
    local score = direction:Dot(preferred) * progressWeight

    score += self:GetBossBandScore(rootPosition, future)

    local auraPart = self.AuraThreat and self.AuraThreat.Part
    if auraPart and auraPart.Parent then
        local awayFromThreat = unit(flatten(rootPosition - auraPart.Position))
        if awayFromThreat.Magnitude > 0 then
            score += direction:Dot(awayFromThreat) * 190
        end
    end

    score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, CONFIG.DodgeDistance) * 3

    score += self:GetEnchantedForestLineEscapeBonus(direction)

    score -= self:GetMeleePenalty(future)
    score += self.Geometry:GetEdgeClearanceScore(future) * 22

    if self.LastMovement.Magnitude > 0 then
        score += direction:Dot(self.LastMovement) * 12
    end

    return score
end

function DodgeSolver:FindExpandingAuraDodge(preferred, targetYaw)
    local rootPosition = self.CharacterService.Root.Position
    preferred = unit(flatten(preferred))
    if preferred.Magnitude <= 0 then
        preferred = unit(flatten(self.CharacterService.Root.CFrame.LookVector))
    end

    self.SelectedAuraPoint = nil

    local boss = self.CurrentSolveEnemy
    local solvingBoss = boss
        and isBossEnemy(boss)
        and boss.Root
        and boss.Root.Parent
    local towardBoss = solvingBoss
        and unit(flatten(boss.Root.Position - rootPosition))
        or Vector3.zero
    local bossForwardDirection, bossForwardPoint, bossForwardScore = nil, nil, -math.huge
    local bossEmergencyDirection, bossEmergencyPoint, bossEmergencyScore = nil, nil, -math.huge

    for _, radius in ipairs(CONFIG.AuraScanRadii) do
        local bestDirection = nil
        local bestPoint = nil
        local bestScore = -math.huge

        for index = 1, CONFIG.AuraDotsPerRing do
            local angle = ((index - 1) / CONFIG.AuraDotsPerRing) * 360
            local direction = unit(rotateXZ(preferred, angle))
            local point = rootPosition + direction * radius

            local safe = self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding)
                and self.Geometry:IsDirectionClear(direction, radius, targetYaw)
                and self.Hazards:GetPointThreat(point) <= 0
                and not self.Dungeon:GetEnemyDangerAt(point)
                and self.Hazards:IsTrajectoryClear(rootPosition, direction, targetYaw, radius)
                and self.Hazards:IsPredictiveTrajectoryClear(rootPosition, direction, targetYaw, radius)

            if safe then
                local bossAdvance = solvingBoss and direction:Dot(towardBoss) or 0
                local score = direction:Dot(preferred) * (solvingBoss and 180 or 220)
                score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, radius) * 4
                score += self.Geometry:GetEdgeClearanceScore(point) * 20

                local auraPart = self.AuraThreat and self.AuraThreat.Part
                if auraPart and auraPart.Parent then
                    local away = unit(flatten(rootPosition - auraPart.Position))
                    score += direction:Dot(away) * (solvingBoss and 90 or 260)
                end

                if solvingBoss then
                    local futureBossDistance = flatten(boss.Root.Position - point).Magnitude
                    local bossScore = score
                        + bossAdvance * 700
                        - futureBossDistance * 18
                        - radius * 1.5

                    if bossAdvance >= -0.05 and bossScore > bossForwardScore then
                        bossForwardScore = bossScore
                        bossForwardDirection = direction
                        bossForwardPoint = point
                    end

                    if bossScore > bossEmergencyScore then
                        bossEmergencyScore = bossScore
                        bossEmergencyDirection = direction
                        bossEmergencyPoint = point
                    end
                elseif score > bestScore then
                    bestScore = score
                    bestDirection = direction
                    bestPoint = point
                end
            end
        end

        if not solvingBoss and bestDirection then
            self.SelectedAuraPoint = bestPoint
            return bestDirection, targetYaw, false
        end
    end

    if bossForwardDirection then
        self.SelectedAuraPoint = bossForwardPoint
        return bossForwardDirection, targetYaw, false
    end

    if bossEmergencyDirection then
        self.SelectedAuraPoint = bossEmergencyPoint
        return bossEmergencyDirection, targetYaw, false
    end

    return nil
end

function DodgeSolver:FindNormalDodge(preferred, targetYaw)
    local bestDirection = nil
    local bestScore = -math.huge

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local score = self:ScoreCandidate(direction, preferred, targetYaw)

        if score and score > bestScore then
            bestScore = score
            bestDirection = direction
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end

    return nil
end

function DodgeSolver:FindEmergencyOrientation(preferred, targetYaw)
    local bestDirection = nil
    local bestYaw = nil
    local bestScore = -math.huge

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local movementYaw = directionToYaw(direction)

        for _, yawOffset in ipairs(CONFIG.EmergencyBodyYawOffsets) do
            local yaw = movementYaw + math.rad(yawOffset)
            local score = self:ScoreCandidate(direction, preferred, yaw)

            if score then
                score -= math.abs(angleDifference(yaw, targetYaw)) * 8

                if score > bestScore then
                    bestScore = score
                    bestDirection = direction
                    bestYaw = yaw
                end
            end
        end
    end

    if bestDirection then
        return bestDirection, bestYaw, true
    end

    return nil
end

function DodgeSolver:FindLeastRiskEscape(preferred, targetYaw)
    local rootPosition = self.CharacterService.Root.Position
    preferred = unit(flatten(preferred))
    local bestDirection = nil
    local bestScore = -math.huge
    local escapeDistance = 6

    for _, angle in ipairs(CONFIG.DodgeAngles) do
        local direction = unit(rotateXZ(preferred, angle))
        local future = rootPosition + direction * escapeDistance
        if self.Geometry:IsDirectionClear(direction, escapeDistance, targetYaw)
            and self.Geometry:IsGroundPadded(future, math.min(6, CONFIG.EdgeHardPadding))
        then
            local score = direction:Dot(preferred) * 90
            score += self:GetBossBandScore(rootPosition, future)
            score -= self.Hazards:GetTrajectoryThreat(rootPosition, direction, escapeDistance) * 7
            score -= self:GetMeleePenalty(future)

            local auraPart = self.AuraThreat and self.AuraThreat.Part
            if auraPart and auraPart.Parent then
                local away = unit(flatten(rootPosition - auraPart.Position))
                score += direction:Dot(away) * 240
            end

            if score > bestScore then
                bestScore = score
                bestDirection = direction
            end
        end
    end

    if bestDirection then
        return bestDirection, targetYaw, false
    end
    return nil
end

function DodgeSolver:GetActiveHitboxEscape(targetYaw)
    local root = self.CharacterService.Root
    local overlaps = self.Hazards:GetCurrentOverlaps(targetYaw)
    local currentOverlapCount = #overlaps

    if currentOverlapCount == 0 then
        return nil
    end

    local escape = Vector3.zero

    for _, part in ipairs(overlaps) do
        if part and part.Parent then
            local warningExit = self.Hazards:GetWarningExitDirection(part, root.Position)
            if warningExit then
                escape += warningExit
                continue
            end
            local localPoint = part.CFrame:PointToObjectSpace(root.Position)
            local half = part.Size * 0.5
            local xExit = half.X - math.abs(localPoint.X)
            local zExit = half.Z - math.abs(localPoint.Z)

            local localDirection

            if xExit < zExit then
                localDirection = Vector3.new(localPoint.X >= 0 and 1 or -1, 0, 0)
            else
                localDirection = Vector3.new(0, 0, localPoint.Z >= 0 and 1 or -1)
            end

            local worldDirection = flatten(part.CFrame:VectorToWorldSpace(localDirection))

            if worldDirection.Magnitude > 0 then
                escape += unit(worldDirection)
            end
        end
    end

    escape = unit(escape)

    if escape.Magnitude <= 0 then
        escape = unit(flatten(root.CFrame.LookVector))
    end

    local directions = {
        escape,
        unit(rotateXZ(escape, 25)),
        unit(rotateXZ(escape, -25)),
        unit(rotateXZ(escape, 50)),
        unit(rotateXZ(escape, -50)),
        unit(rotateXZ(escape, 90)),
        unit(rotateXZ(escape, -90)),
        -escape,
    }

    local bestDirection = nil
    local bestYaw = nil
    local bestScore = -math.huge

    for _, direction in ipairs(directions) do
        if direction.Magnitude > 0 then
            local movementYaw = directionToYaw(direction)

            local yawCandidates = {
                targetYaw,
                movementYaw,
                movementYaw + math.rad(90),
                movementYaw - math.rad(90),
            }

            for _, yaw in ipairs(yawCandidates) do
                if self.Geometry:IsDirectionClear(direction, 4, yaw) then
                    local future4 = root.Position + direction * 4
                    local future7 = root.Position + direction * 7

                    if self.Geometry:IsGroundPadded(future7, CONFIG.EdgeHardPadding) then
                        local count4 = self.Hazards:GetOverlapCountAt(future4, yaw)
                        local count7 = self.Hazards:GetOverlapCountAt(future7, yaw)

                        local score =
                            (currentOverlapCount - count4) * 420
                            + (currentOverlapCount - count7) * 760

                        if count7 == 0 then
                            score += 1800
                        end

                        score += self.Geometry:GetEdgeClearanceScore(future7) * 18

                        score -= math.abs(angleDifference(yaw, targetYaw)) * 3

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestYaw = yaw
                        end
                    end
                end
            end
        end
    end

    if bestDirection then
        return bestDirection, bestYaw, true
    end

    return nil
end

function DodgeSolver:GetMeleePanicEscape(targetYaw, routeDirection)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    -- (placeholder kept so the class shape stays the same)
    return nil
end

function DodgeSolver:IsImmediateHazardDanger(preferred, targetYaw)
    self.SelectedAuraPoint = nil
    self.AuraThreat = nil
    self.AuraThreatDistance = nil

    local root = self.CharacterService.Root

    if self.Hazards:GetOverlapCountAt(root.Position, targetYaw) > 0 then
        return true
    end

    local auraThreat, auraDistance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)

    self.AuraThreat = auraThreat
    self.AuraThreatDistance = auraDistance
    if auraThreat then
        return true
    end

    preferred = unit(flatten(preferred or Vector3.zero))

    local warningDistance = math.max(CONFIG.DangerLookaheadDistance,
        math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed) * CONFIG.PrecastLookaheadTime)
    if not self.Hazards:IsPrecastTrajectoryClear(root.Position, preferred, targetYaw, warningDistance) then
        return true
    end

    local incoming = self.Hazards:GetIncomingProjectileThreat(root.Position, preferred, targetYaw, CONFIG.DodgeDistance)

    if incoming then
        return true
    end

    if #self.Hazards:GetActive() == 0 then
        return false
    end

    if preferred.Magnitude <= 0 then
        return false
    end

    return not self.Hazards:IsTrajectoryClear(root.Position, preferred, targetYaw, CONFIG.DangerLookaheadDistance)
end

function DodgeSolver:FindOpenMovement(preferred, targetYaw)
    local root = self.CharacterService.Root
    preferred = unit(flatten(preferred))

    if preferred.Magnitude <= 0 then
        return Vector3.zero
    end

    for _, angle in ipairs({0, 20, -20, 40, -40, 65, -65, 90, -90, 120, -120, 150, -150, 180}) do
        local direction = unit(rotateXZ(preferred, angle))
        local future = root.Position + direction * 6

        if self.Geometry:IsDirectionClear(direction, 6, targetYaw)
            and self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding)
        then
            return direction
        end
    end

    return Vector3.zero
end

function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    local direction = self:GetCombatPreferred(routeDirection, enemy, targetYaw)
    return direction, targetYaw, false, false
end

local CombatController = {}
CombatController.__index = CombatController

function CombatController.new(characterService, selfTracker)
    return setmetatable({
        CharacterService = characterService,
        SelfTracker = selfTracker,
        LastPress = {
            q = 0,
            e = 0,
        },
        LastAction = nil,
        AttackCommitTarget = nil,
        AttackCommitUntil = 0,
        CooldownHolding = false,
    }, CombatController)
end

function CombatController:GetTool(slot)
    for _, container in ipairs({ LocalPlayer.Backpack, LocalPlayer.Character }) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local abilitySlot = tool:FindFirstChild("abilitySlot")

                    if abilitySlot and string.lower(tostring(abilitySlot.Value)) == slot then
                        return tool
                    end
                end
            end
        end
    end

    return nil
end

function CombatController:IsBusyCasting()
    local character = self.CharacterService.Character
    local busy = character and character:FindFirstChild("busyCasting")

    return busy and busy:IsA("BoolValue") and busy.Value or false
end

function CombatController:GetCooldownRemaining(slot)
    local tool = self:GetTool(slot)

    if not tool then
        return nil
    end

    local cooldown = tool:FindFirstChild("cooldown")

    if not cooldown then
        return 0
    end

    local value = tonumber(cooldown.Value)

    if not value then
        return 0
    end

    return math.max(value, 0)
end

function CombatController:IsSlotCooldownReady(slot)
    local remaining = self:GetCooldownRemaining(slot)

    if remaining == nil then
        return false
    end

    return remaining <= 0 and os.clock() - self.LastPress[slot] > 0.35
end

function CombatController:IsReady(slot)
    if self:IsBusyCasting() then
        return false
    end

    return self:IsSlotCooldownReady(slot)
end

function CombatController:GetPreparationState()
    -- Replaced by the v38 combat + dodge section near the end of this file.
    return {
        HasDamage = false,
        HasBuff = false,
        DamageReady = true,
        BuffReady = true,
        LongestWait = 0,
    }
end

function CombatController:ClearCommit()
    self.AttackCommitTarget = nil
    self.AttackCommitUntil = 0
end

function CombatController:ArmCommit(enemy)
    if not enemy or not enemy.Model then
        return
    end

    self.AttackCommitTarget = enemy.Model
    self.AttackCommitUntil = os.clock() + CONFIG.AttackCommitWindow
end

function CombatController:IsCommitArmed(enemy)
    if not enemy or not enemy.Model then
        return false
    end

    if self.AttackCommitTarget ~= enemy.Model then
        return false
    end

    if os.clock() > self.AttackCommitUntil then
        self:ClearCommit()
        return false
    end

    return true
end

function CombatController:ShouldHoldApproach(enemy, travelMode)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    self.CooldownHolding = false
    return false
end

function CombatController:GetHoldText()
    return "holding"
end

function CombatController:IsBuffTool(tool)
    if not tool then
        return false
    end

    local buffPower = tool:FindFirstChild("buffPower")
    local damage = tool:FindFirstChild("damage")

    return buffPower ~= nil and damage == nil
end

function CombatController:Press(slot)
    local keyCode = slot == "q" and Enum.KeyCode.Q or Enum.KeyCode.E

    self.LastPress[slot] = os.clock()

    self.SelfTracker:RegisterCast(slot)

    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)

    task.delay(0.045, function()
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)

    self.LastAction = slot
end

function CombatController:Update(enemy)
    -- Replaced by the v38 combat + dodge section near the end of this file.
    self.LastAction = nil
    return false
end

local TargetHealthBar = {}
TargetHealthBar.__index = TargetHealthBar

function TargetHealthBar.new()
    local self = setmetatable({}, TargetHealthBar)

    local gui = Instance.new("ScreenGui")
    gui.Name = "UIWTargetHealth"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.Parent = LocalPlayer.PlayerGui

    self.Gui = gui

    local existing = LocalPlayer.PlayerGui:FindFirstChild("bossHealth")

    if existing and existing:FindFirstChild("healthFrame") then
        self.Frame = existing.healthFrame:Clone()
        self.Frame.Name = "TargetHealthFrame"
        self.Frame.Parent = gui
    else
        local frame = Instance.new("Frame")
        frame.AnchorPoint = Vector2.new(0.5, 0)
        frame.Position = UDim2.fromScale(0.5, 0.16)
        frame.Size = UDim2.fromScale(0.35, 0.05)
        frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        frame.BorderSizePixel = 0
        frame.Parent = gui

        local fill = Instance.new("Frame")
        fill.Name = "currentHealth"
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(150, 45, 45)
        fill.BorderSizePixel = 0
        fill.Parent = frame

        local health = Instance.new("TextLabel")
        health.Name = "health"
        health.BackgroundTransparency = 1
        health.Size = UDim2.fromScale(1, 1)
        health.Font = Enum.Font.Highway
        health.TextSize = 14
        health.TextColor3 = Color3.fromRGB(245, 245, 245)
        health.Parent = frame

        local name = Instance.new("TextLabel")
        name.Name = "bossName"
        name.BackgroundTransparency = 1
        name.AnchorPoint = Vector2.new(0.5, 1)
        name.Position = UDim2.fromScale(0.5, 0)
        name.Size = UDim2.fromScale(1, 0.8)
        name.Font = Enum.Font.Highway
        name.TextSize = 14
        name.TextColor3 = Color3.fromRGB(191, 171, 58)
        name.Parent = frame

        self.Frame = frame
    end

    self.Frame.Visible = false
    self.Target = nil

    return self
end

function TargetHealthBar:SetTarget(enemy)
    self.Target = enemy
end

function TargetHealthBar:Update()
    local enemy = self.Target

    if not enemy
        or not enemy.Model
        or not enemy.Model.Parent
        or not enemy.Humanoid
        or enemy.Humanoid.Health <= 0
    then
        self.Frame.Visible = false
        return
    end

    self.Frame.Visible = true

    local name = self.Frame:FindFirstChild("bossName", true)
    local health = self.Frame:FindFirstChild("health", true)

    if name and name:IsA("TextLabel") then
        name.Text = enemy.Model.Name
    end

    if health and health:IsA("TextLabel") then
        health.Text = shortNumber(enemy.Humanoid.Health) .. "/" .. shortNumber(enemy.Humanoid.MaxHealth)
    end

    local current = self.Frame:FindFirstChild("currentHealth", true)

    if current and current:IsA("GuiObject") then
        local ratio = math.clamp(
            enemy.Humanoid.Health / math.max(enemy.Humanoid.MaxHealth, 1),
            0,
            1
        )

        current.Size = UDim2.new(ratio, 0, 1, 0)
    end
end

function TargetHealthBar:Destroy()
    safeDestroy(self.Gui)
end

local PathESP = {}
PathESP.__index = PathESP

function PathESP.new()
    local folder = Instance.new("Folder")
    folder.Name = "UIW_PathESP"
    folder.Parent = Workspace

    return setmetatable({
        Folder = folder,
        LastUpdate = 0,
    }, PathESP)
end

-- v44: pooled segments. The old version destroyed and re-created every
-- segment 4x per second, which is heavy Instance churn in long dungeons.
local PATH_ESP_MAX_SEGMENTS = 24

function PathESP:GetSegment(index)
    self.Pool = self.Pool or {}
    local part = self.Pool[index]
    if part and part.Parent then
        return part
    end
    part = Instance.new("Part")
    part.Name = "Segment"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(240, 195, 55)
    part.Transparency = 1
    part.Parent = self.Folder
    self.Pool[index] = part
    return part
end

function PathESP:Hide()
    if not self.Pool or self.Hidden then
        return
    end
    self.Hidden = true
    for _, part in ipairs(self.Pool) do
        if part.Parent then
            part.Transparency = 1
        end
    end
end

function PathESP:Update(waypoints, currentIndex, rootPosition)
    local now = os.clock()
    if now - self.LastUpdate < CONFIG.PathVisualInterval then return end
    self.LastUpdate = now

    if not waypoints or #waypoints == 0 or not rootPosition then
        self:Hide()
        return
    end

    local points = {rootPosition}
    for i = currentIndex, #waypoints do
        if #points > PATH_ESP_MAX_SEGMENTS then break end
        if waypoints[i] then
            table.insert(points, waypoints[i].Position)
        end
    end

    self.Hidden = false
    local used = 0
    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]
        local distance = (p2 - p1).Magnitude

        if distance > 0.1 then
            used += 1
            local part = self:GetSegment(used)
            part.Size = Vector3.new(0.4, 0.4, distance)
            part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance / 2)
            part.Transparency = 0
        end
    end

    for index = used + 1, #(self.Pool or {}) do
        local part = self.Pool[index]
        if part.Parent and part.Transparency < 1 then
            part.Transparency = 1
        end
    end
end

function PathESP:Destroy()
    if self.Folder then
        self.Folder:Destroy()
    end
end

local TacticalDisplay = {}
TacticalDisplay.__index = TacticalDisplay

function TacticalDisplay.new(character, hazards, geometry, dungeon, dodger)
    local folder = Instance.new("Folder")
    folder.Name = "UIW_TacticalDisplay"
    folder.Parent = Workspace

    return setmetatable({
        Character = character,
        Hazards = hazards,
        Geometry = geometry,
        Dungeon = dungeon,
        Dodger = dodger,
        Folder = folder,
        AuraDots = {},
        GroupRings = {},
        ShowAura = true,
        ShowMobGroups = true,
        LastUpdate = 0,
    }, TacticalDisplay)
end

function TacticalDisplay:CreateDot(parent, name, color, size)
    local dot = Instance.new("Part")
    dot.Name = name
    dot.Shape = Enum.PartType.Ball
    dot.Size = Vector3.new(size, size, size)
    dot.Anchored = true
    dot.CanCollide = false
    dot.CanTouch = false
    dot.CanQuery = false
    dot.CastShadow = false
    dot.Material = Enum.Material.Neon
    dot.Color = color
    dot.Transparency = 0.16
    dot.Parent = parent
    return dot
end

function TacticalDisplay:EnsureAuraDots()
    local required = CONFIG.AuraDotsPerRing
    while #self.AuraDots < required do
        table.insert(self.AuraDots, self:CreateDot(
            self.Folder,
            "AuraDot",
            Color3.fromRGB(58, 205, 255),
            0.48
        ))
    end
end

function TacticalDisplay:UpdateAura(root)
    self:EnsureAuraDots()

    if not self.ShowAura then
        for _, dot in ipairs(self.AuraDots) do dot.Transparency = 1 end
        return nil, nil
    end

    local threat, distance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)
    local center = root.Position - Vector3.new(0, 2.65, 0)
    local forward = unit(flatten(root.CFrame.LookVector))
    local yaw = directionToYaw(forward)
    local selected = self.Dodger and self.Dodger.SelectedAuraPoint
    local selectedRadius = selected and flatten(selected - root.Position).Magnitude or math.huge
    local ringIndex = math.floor(os.clock() / CONFIG.AuraRingStepTime) % #CONFIG.AuraScanRadii + 1
    local radius = CONFIG.AuraScanRadii[ringIndex]

    for index, dot in ipairs(self.AuraDots) do
        local angle = ((index - 1) / CONFIG.AuraDotsPerRing) * math.pi * 2
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local testPoint = root.Position + direction * radius

        -- v44.7: cheap display only (no wall casts / trajectory sweeps per dot).
        local attackThreat = self.Hazards:GetPointThreat(testPoint) > 0
        local enemyThreat = self.Dungeon:GetEnemyDangerAt(testPoint) ~= nil
        local combatThreat = attackThreat or enemyThreat
        local reachable = true

        local selectionTolerance = math.max(1.5, radius * math.pi / CONFIG.AuraDotsPerRing)
        local isSelected = selected
            and math.abs(selectedRadius - radius) <= 1.5
            and flatten(testPoint - selected).Magnitude <= selectionTolerance
        dot.Position = center + direction * radius
        dot.Color = isSelected and Color3.fromRGB(255, 225, 70)
            or (combatThreat and Color3.fromRGB(255, 58, 84)
            or (reachable and Color3.fromRGB(48, 230, 153) or Color3.fromRGB(90, 145, 170)))
        dot.Size = Vector3.one * (isSelected and 0.82 or 0.48)
        dot.Transparency = self.ShowAura and (combatThreat and 0.18 or 0.12) or 1
    end

    return threat, distance
end

function TacticalDisplay:EnsureGroupRing(key)
    local ring = self.GroupRings[key]
    if ring then return ring end

    ring = {}
    for index = 1, CONFIG.MobGroupDotCount do
        table.insert(ring, self:CreateDot(
            self.Folder,
            "MobGroup_" .. tostring(key) .. "_" .. tostring(index),
            Color3.fromRGB(255, 174, 55),
            0.62
        ))
    end
    self.GroupRings[key] = ring
    return ring
end

function TacticalDisplay:UpdateMobGroups(targetEnemy)
    local groups = {}
    for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
        if enemy.Root and enemy.Root.Parent then
            local key = enemy.Room or 999
            local group = groups[key]
            if not group then
                group = {Enemies = {}, Center = Vector3.zero}
                groups[key] = group
            end
            table.insert(group.Enemies, enemy)
            group.Center += enemy.Root.Position
        end
    end

    for key, ring in pairs(self.GroupRings) do
        if not groups[key] then
            for _, dot in ipairs(ring) do safeDestroy(dot) end
            self.GroupRings[key] = nil
        elseif not self.ShowMobGroups then
            for _, dot in ipairs(ring) do dot.Transparency = 1 end
        end
    end

    if not self.ShowMobGroups then return end

    for key, group in pairs(groups) do
        group.Center /= #group.Enemies
        local radius = 16
        for _, enemy in ipairs(group.Enemies) do
            radius = math.max(radius, flatten(enemy.Root.Position - group.Center).Magnitude + 8)
        end
        radius = math.min(radius, 62)

        local ring = self:EnsureGroupRing(key)
        local center = group.Center - Vector3.new(0, 2.8, 0)
        local targetGroup = targetEnemy and targetEnemy.Room == key
        for index, dot in ipairs(ring) do
            local angle = ((index - 1) / #ring) * math.pi * 2
            dot.Position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            dot.Color = targetGroup and Color3.fromRGB(48, 230, 153) or Color3.fromRGB(255, 174, 55)
            dot.Transparency = 0.20
        end
    end
end

function TacticalDisplay:Update(showAura, showMobGroups, targetEnemy)
    local now = os.clock()
    if now - self.LastUpdate < CONFIG.TacticalVisualInterval then return end
    self.LastUpdate = now
    self.ShowAura = showAura
    self.ShowMobGroups = showMobGroups

    local root = self.Character.Root
    if not root or not root.Parent then return end
    self:UpdateAura(root)
    self:UpdateMobGroups(targetEnemy)
end

function TacticalDisplay:Destroy()
    safeDestroy(self.Folder)
end

---------------------------------------------------------------------------
-- UIW hub window
--   sidebar tabs (Home / Automation / Settings / Configs), gradient cards,
--   soft drop shadow, toasts, minimise bubble. RightShift shows / hides.
--   Keeps the old HUD interface: SetStatus, SetRetryStatus, Heartbeat,
--   Toggle, RefreshControls, Destroy and the Accent / Badge / Status /
--   FPSLabel / RetryStatus / AutoRetryButton fields other parts use.
---------------------------------------------------------------------------
local UIKit = {}

UIKit.Theme = {
    Window = Color3.fromRGB(14, 15, 20),
    Sidebar = Color3.fromRGB(18, 19, 26),
    Card = Color3.fromRGB(24, 25, 33),
    Tile = Color3.fromRGB(34, 35, 45),
    TileHover = Color3.fromRGB(44, 46, 58),
    Stroke = Color3.fromRGB(46, 48, 62),
    Text = Color3.fromRGB(238, 240, 247),
    SubText = Color3.fromRGB(160, 164, 178),
    Muted = Color3.fromRGB(110, 114, 128),
    Accent = Color3.fromRGB(124, 104, 255),
    Accent2 = Color3.fromRGB(70, 150, 255),
    Good = Color3.fromRGB(46, 204, 142),
    Bad = Color3.fromRGB(236, 76, 96),
    Warn = Color3.fromRGB(242, 183, 64),
    Off = Color3.fromRGB(58, 60, 74),
    White = Color3.fromRGB(255, 255, 255),
}

UIKit.Fonts = {
    Bold = Enum.Font.GothamBold,
    Semi = Enum.Font.GothamMedium,
    Body = Enum.Font.Gotham,
    Mono = Enum.Font.Code,
}

function UIKit.New(className, props, children)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        if key ~= "Parent" then
            object[key] = value
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = object
    end
    if props and props.Parent then
        object.Parent = props.Parent
    end
    return object
end

function UIKit.Corner(parent, radius)
    return UIKit.New("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function UIKit.Stroke(parent, color, transparency, thickness)
    return UIKit.New("UIStroke", {
        Color = color or UIKit.Theme.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

function UIKit.Gradient(parent, from, to, rotation)
    return UIKit.New("UIGradient", {
        Color = ColorSequence.new(from, to),
        Rotation = rotation or 0,
        Parent = parent,
    })
end

function UIKit.Padding(parent, left, top, right, bottom)
    return UIKit.New("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingTop = UDim.new(0, top or left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingBottom = UDim.new(0, bottom or top or left or 0),
        Parent = parent,
    })
end

function UIKit.Tween(object, time, props, style)
    local ok, tween = pcall(function()
        return game:GetService("TweenService"):Create(
            object,
            TweenInfo.new(time, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            props
        )
    end)
    if ok and tween then
        tween:Play()
        return tween
    end
    for key, value in pairs(props) do
        pcall(function() object[key] = value end)
    end
    return nil
end

function UIKit.Label(parent, props)
    local defaults = {
        BackgroundTransparency = 1,
        Font = UIKit.Fonts.Body,
        TextSize = 13,
        TextColor3 = UIKit.Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "",
        Parent = parent,
    }
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    return UIKit.New("TextLabel", defaults)
end

function UIKit.Button(parent, props)
    local defaults = {
        AutoButtonColor = false,
        BackgroundColor3 = UIKit.Theme.Tile,
        BorderSizePixel = 0,
        Font = UIKit.Fonts.Semi,
        TextSize = 13,
        TextColor3 = UIKit.Theme.Text,
        Text = "",
        Parent = parent,
    }
    for key, value in pairs(props or {}) do
        defaults[key] = value
    end
    local button = UIKit.New("TextButton", defaults)
    local base = defaults.BackgroundColor3
    button.MouseEnter:Connect(function()
        UIKit.Tween(button, 0.15, { BackgroundColor3 = base:Lerp(UIKit.Theme.White, 0.08) })
    end)
    button.MouseLeave:Connect(function()
        UIKit.Tween(button, 0.2, { BackgroundColor3 = base })
    end)
    return button, function(color)
        base = color
        UIKit.Tween(button, 0.2, { BackgroundColor3 = color })
    end
end

-- UIGradient tints text too, so the gradient sits on a backing frame and the
-- (transparent) button with the text sits on top of it
function UIKit.GradientButton(parent, props, radius)
    local backing = UIKit.New("Frame", {
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        Position = props.Position,
        Size = props.Size,
        BackgroundColor3 = UIKit.Theme.White,
        BorderSizePixel = 0,
        Visible = props.Visible ~= false,
        ZIndex = props.ZIndex or 3,
        Parent = parent,
    })
    UIKit.Corner(backing, radius or 8)
    local gradient = UIKit.Gradient(backing, UIKit.Theme.Accent, UIKit.Theme.Accent2, props.Rotation or 0)
    local button = UIKit.New("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = props.Font or UIKit.Fonts.Bold,
        TextSize = props.TextSize or 13,
        TextColor3 = UIKit.Theme.White,
        Text = props.Text or "",
        ZIndex = (props.ZIndex or 3) + 1,
        Parent = backing,
    })
    button.MouseEnter:Connect(function()
        UIKit.Tween(gradient, 0.2, { Offset = Vector2.new(0.15, 0) })
    end)
    button.MouseLeave:Connect(function()
        UIKit.Tween(gradient, 0.2, { Offset = Vector2.zero })
    end)
    return button, backing
end

-- soft shadow built from stacked transparent frames (no image assets needed)
function UIKit.Shadow(holder, radius)
    for i = 1, 6 do
        local spread = i * 4
        UIKit.Corner(UIKit.New("Frame", {
            Name = "Shadow" .. i,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 6),
            Size = UDim2.new(1, spread * 2, 1, spread * 2),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.82 + i * 0.028,
            BorderSizePixel = 0,
            ZIndex = 0,
            Parent = holder,
        }), radius + spread)
    end
end

-- a card with a coloured glow in one corner (like the reference design)
function UIKit.Card(parent, props, glow)
    local card = UIKit.New("Frame", {
        BackgroundColor3 = UIKit.Theme.Card,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = props.Position,
        Size = props.Size,
        LayoutOrder = props.LayoutOrder or 0,
        Parent = parent,
    })
    UIKit.Corner(card, 12)
    UIKit.Stroke(card, UIKit.Theme.Stroke, 0.35)
    if glow then
        local shine = UIKit.New("Frame", {
            Name = "Glow",
            BackgroundColor3 = glow,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 1,
            Parent = card,
        })
        UIKit.Corner(shine, 12)
        local gradient = UIKit.Gradient(shine, UIKit.Theme.White, UIKit.Theme.White, props.GlowRotation or 35)
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.45, 0.92),
            NumberSequenceKeypoint.new(1, 0.45),
        })
        card:SetAttribute("GlowColor", glow)
    end
    return card
end

function UIKit.SetGlow(card, color)
    local shine = card:FindFirstChild("Glow")
    if shine then
        UIKit.Tween(shine, 0.35, { BackgroundColor3 = color })
    end
end

-- a small stat tile: caption + value
function UIKit.Tile(parent, caption, position, size)
    local tile = UIKit.New("Frame", {
        BackgroundColor3 = UIKit.Theme.Tile,
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = position,
        Size = size,
        ZIndex = 2,
        Parent = parent,
    })
    UIKit.Corner(tile, 8)
    UIKit.Label(tile, {
        Position = UDim2.fromOffset(10, 5),
        Size = UDim2.new(1, -20, 0, 16),
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = caption,
        ZIndex = 3,
    })
    local value = UIKit.Label(tile, {
        Position = UDim2.fromOffset(10, 21),
        Size = UDim2.new(1, -20, 0, 16),
        TextSize = 11,
        TextColor3 = UIKit.Theme.SubText,
        Text = "-",
        ZIndex = 3,
    })
    return value, tile
end

-- iOS-like switch; returns the track and a setter
function UIKit.Switch(parent, position)
    local track = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = position,
        Size = UDim2.fromOffset(42, 22),
        BackgroundColor3 = UIKit.Theme.Off,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = parent,
    })
    UIKit.Corner(track, 11)
    local knob = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = UIKit.Theme.White,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = track,
    })
    UIKit.Corner(knob, 8)
    local function set(value, instant)
        local time = instant and 0 or 0.22
        UIKit.Tween(track, time, { BackgroundColor3 = value and UIKit.Theme.Good or UIKit.Theme.Off })
        UIKit.Tween(knob, time, { Position = value and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
    end
    return track, set
end

---------------------------------------------------------------------------
local HUD = {}
HUD.__index = HUD

local STATUS_COLORS = {
    MOVING = COLORS.Moving,
    PATHING = COLORS.Pathing,
    COMBAT = COLORS.Combat,
    DODGING = COLORS.Dodge,
    EMERGENCY = COLORS.Emergency,
    MELEE = COLORS.Melee,
    RUNNING = COLORS.Running,
}

local WINDOW_W, WINDOW_H = 660, 430

function HUD.new(controller)
    local self = setmetatable({}, HUD)
    local T = UIKit.Theme

    self.StartTime = os.clock()
    self.Visible = true
    self.Controller = controller
    self.Frames = 0
    self.LastFpsUpdate = os.clock()
    self.LastSlowUpdate = 0
    self.ControlRefreshers = {}
    self.ConfigRefreshers = {}
    self.Connections = {}
    self.Pages = {}
    self.TabButtons = {}
    self.SelectedConfig = controller.ActiveConfig

    local function connect(signal, fn)
        local connection = signal:Connect(fn)
        table.insert(self.Connections, connection)
        return connection
    end

    local parentGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = parentGui:FindFirstChild("UIW")
    if old then
        safeDestroy(old)
    end

    local gui = UIKit.New("ScreenGui", {
        Name = "UIW",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 100,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = parentGui,
    })
    self.Gui = gui

    -- holder = shadow + window, dragged as one
    local holder = UIKit.New("Frame", {
        Name = "Holder",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(WINDOW_W, WINDOW_H),
        BackgroundTransparency = 1,
        Parent = gui,
    })
    self.Holder = holder
    UIKit.Shadow(holder, 16)

    local scale = UIKit.New("UIScale", { Parent = holder })
    local function updateScale()
        local camera = Workspace.CurrentCamera
        if camera then
            local viewport = camera.ViewportSize
            scale.Scale = math.clamp(math.min((viewport.X - 24) / WINDOW_W, (viewport.Y - 60) / WINDOW_H), 0.45, 1)
        end
    end
    updateScale()
    if Workspace.CurrentCamera then
        connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), updateScale)
    end

    local main = UIKit.New("Frame", {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = T.White,
        BorderSizePixel = 0,
        ZIndex = 1,
        Parent = holder,
    })
    UIKit.Corner(main, 16)
    UIKit.Stroke(main, T.Stroke, 0.1)
    UIKit.Gradient(main, Color3.fromRGB(24, 25, 35), T.Window, 90)
    self.Main = holder -- Toggle() shows / hides the whole window

    -----------------------------------------------------------------------
    -- title bar
    -----------------------------------------------------------------------
    local titleBar = UIKit.New("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = main,
    })

    local logo = UIKit.New("Frame", {
        Position = UDim2.fromOffset(16, 11),
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = T.White,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = titleBar,
    })
    UIKit.Corner(logo, 14)
    UIKit.Gradient(logo, T.Accent, T.Accent2, 45)
    UIKit.Label(logo, {
        Size = UDim2.fromScale(1, 1),
        Font = UIKit.Fonts.Bold,
        TextSize = 13,
        Text = "U",
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 4,
    })

    UIKit.Label(titleBar, {
        Position = UDim2.fromOffset(54, 8),
        Size = UDim2.fromOffset(60, 20),
        Font = UIKit.Fonts.Bold,
        TextSize = 17,
        Text = "UIW",
        ZIndex = 3,
    })
    UIKit.Label(titleBar, {
        Position = UDim2.fromOffset(54, 27),
        Size = UDim2.fromOffset(200, 14),
        TextSize = 11,
        TextColor3 = T.Muted,
        Text = "Dungeon Automation  •  v44.20",
        ZIndex = 3,
    })

    -- status pill (Accent dot + Badge text are used by the rest of the script)
    local pill = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -92, 0.5, 0),
        Size = UDim2.fromOffset(190, 26),
        BackgroundColor3 = T.Tile,
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = titleBar,
    })
    UIKit.Corner(pill, 13)
    UIKit.Stroke(pill, T.Stroke, 0.4)
    local accent = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 11, 0.5, 0),
        Size = UDim2.fromOffset(8, 8),
        BackgroundColor3 = COLORS.Running,
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = pill,
    })
    UIKit.Corner(accent, 4)
    self.Accent = accent
    self.Badge = UIKit.Label(pill, {
        Position = UDim2.fromOffset(26, 0),
        Size = UDim2.new(1, -34, 1, 0),
        Font = UIKit.Fonts.Semi,
        TextSize = 11,
        TextColor3 = COLORS.Running,
        Text = "Automation: starting",
        ZIndex = 4,
    })

    local function windowButton(text, offset, color)
        local button = UIKit.Button(titleBar, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, offset, 0.5, 0),
            Size = UDim2.fromOffset(30, 30),
            BackgroundColor3 = T.Tile,
            Font = UIKit.Fonts.Bold,
            TextSize = 16,
            TextColor3 = color or T.SubText,
            Text = text,
            ZIndex = 4,
        })
        UIKit.Corner(button, 9)
        return button
    end
    local minimizeButton = windowButton("–", -52)
    local closeButton = windowButton("×", -14, T.Bad)

    -- hidden: the controller still wires its own retry toggle to this
    self.AutoRetryButton = UIKit.New("TextButton", {
        Name = "AutoRetryButton",
        Visible = false,
        Text = "RETRY: ON",
        Parent = titleBar,
    })
    self.AutoRetryEnabled = true

    -----------------------------------------------------------------------
    -- sidebar
    -----------------------------------------------------------------------
    local sidebar = UIKit.New("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(12, 56),
        Size = UDim2.new(0, 52, 1, -68),
        BackgroundColor3 = T.Sidebar,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = main,
    })
    UIKit.Corner(sidebar, 14)
    UIKit.Stroke(sidebar, T.Stroke, 0.5)

    local tabList = UIKit.New("Frame", {
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 1, -70),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = sidebar,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = tabList,
    })

    local avatar = UIKit.New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.fromOffset(38, 38),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        Image = "",
        ZIndex = 3,
        Parent = sidebar,
    })
    UIKit.Corner(avatar, 19)
    UIKit.Stroke(avatar, T.Accent, 0.3, 1.5)

    -----------------------------------------------------------------------
    -- pages
    -----------------------------------------------------------------------
    local content = UIKit.New("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(76, 56),
        Size = UDim2.new(1, -88, 1, -68),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = 2,
        Parent = main,
    })

    local function newPage(name, scrolling)
        local page
        if scrolling then
            page = UIKit.New("ScrollingFrame", {
                Name = name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 3,
                ScrollBarImageColor3 = T.Muted,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Visible = false,
                ZIndex = 2,
                Parent = content,
            })
            UIKit.New("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = page,
            })
            UIKit.Padding(page, 0, 0, 8, 6)
        else
            page = UIKit.New("Frame", {
                Name = name,
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Visible = false,
                ZIndex = 2,
                Parent = content,
            })
        end
        self.Pages[name] = page
        return page
    end

    local function pageHeader(page, order, title, subtitle)
        local header = UIKit.New("Frame", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            LayoutOrder = order,
            ZIndex = 2,
            Parent = page,
        })
        UIKit.Label(header, {
            Size = UDim2.new(1, 0, 0, 22),
            Font = UIKit.Fonts.Bold,
            TextSize = 17,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(header, {
            Position = UDim2.fromOffset(0, 22),
            Size = UDim2.new(1, 0, 0, 16),
            TextSize = 12,
            TextColor3 = T.Muted,
            Text = subtitle,
            ZIndex = 3,
        })
        return header
    end

    local function selectTab(name)
        for tabName, page in pairs(self.Pages) do
            local active = tabName == name
            if active and not page.Visible then
                page.Position = UDim2.fromOffset(0, 10)
                page.Visible = true
                UIKit.Tween(page, 0.3, { Position = UDim2.fromOffset(0, 0) })
            elseif not active then
                page.Visible = false
            end
        end
        for tabName, entry in pairs(self.TabButtons) do
            local active = tabName == name
            UIKit.Tween(entry.Button, 0.2, {
                BackgroundColor3 = active and T.Tile or T.Sidebar,
                TextColor3 = active and T.Text or T.Muted,
            })
            UIKit.Tween(entry.Bar, 0.2, { BackgroundTransparency = active and 0 or 1 })
        end
        self.CurrentTab = name
    end
    self.SelectTab = selectTab

    local function tabButton(name, icon, order)
        local button = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Size = UDim2.fromOffset(38, 38),
            BackgroundColor3 = T.Sidebar,
            BorderSizePixel = 0,
            Font = UIKit.Fonts.Bold,
            TextSize = 17,
            TextColor3 = T.Muted,
            Text = icon,
            LayoutOrder = order,
            ZIndex = 3,
            Parent = tabList,
        })
        UIKit.Corner(button, 10)
        local bar = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, -7, 0.5, 0),
            Size = UDim2.fromOffset(3, 18),
            BackgroundColor3 = T.Accent,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = button,
        })
        UIKit.Corner(bar, 2)
        button.MouseButton1Click:Connect(function()
            selectTab(name)
        end)
        self.TabButtons[name] = { Button = button, Bar = bar }
    end

    tabButton("Home", "⌂", 1)
    tabButton("Automation", "⚔", 2)
    tabButton("Settings", "⚙", 3)
    tabButton("Configs", "▤", 4)

    -----------------------------------------------------------------------
    -- Home
    -----------------------------------------------------------------------
    local home = newPage("Home", false)

    local profile = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 66),
    }, T.Accent)
    local bigAvatar = UIKit.New("ImageLabel", {
        Position = UDim2.fromOffset(10, 9),
        Size = UDim2.fromOffset(48, 48),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = profile,
    })
    UIKit.Corner(bigAvatar, 12)
    UIKit.Label(profile, {
        Position = UDim2.fromOffset(70, 12),
        Size = UDim2.new(1, -80, 0, 22),
        Font = UIKit.Fonts.Bold,
        TextSize = 17,
        Text = "Hello, " .. tostring(LocalPlayer.DisplayName),
        ZIndex = 3,
    })
    self.ProfileSub = UIKit.Label(profile, {
        Position = UDim2.fromOffset(70, 35),
        Size = UDim2.new(1, -80, 0, 16),
        TextSize = 12,
        TextColor3 = T.SubText,
        Text = "@" .. tostring(LocalPlayer.Name),
        ZIndex = 3,
    })

    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok and image and bigAvatar.Parent then
            bigAvatar.Image = image
            avatar.Image = image
        end
    end)

    local gridTop = 76
    local rowH = 134

    -- Session (green)
    local session = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, gridTop),
        Size = UDim2.new(0.5, -5, 0, rowH),
    }, T.Good)
    UIKit.Label(session, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Session", ZIndex = 3 })
    UIKit.Label(session, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14),
        TextSize = 10, TextColor3 = T.SubText, Text = "This server, right now", ZIndex = 3 })
    self.Playtime = UIKit.Tile(session, "Playtime", UDim2.fromOffset(10, 46), UDim2.new(0.5, -14, 0, 38))
    self.FPSLabel = UIKit.Tile(session, "FPS", UDim2.new(0.5, 4, 0, 46), UDim2.new(0.5, -14, 0, 38))
    self.Ping = UIKit.Tile(session, "Ping", UDim2.fromOffset(10, 88), UDim2.new(0.5, -14, 0, 38))
    self.PlayersLabel = UIKit.Tile(session, "Players", UDim2.new(0.5, 4, 0, 88), UDim2.new(0.5, -14, 0, 38))
    self.FPSLabel.Text = "0 fps"

    -- Automation (green when running, red when paused)
    local automation = UIKit.Card(home, {
        Position = UDim2.new(0.5, 5, 0, gridTop),
        Size = UDim2.new(0.5, -5, 0, rowH),
        GlowRotation = 20,
    }, T.Good)
    self.AutomationCard = automation
    UIKit.Label(automation, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Automation", ZIndex = 3 })
    self.AutomationState = UIKit.Label(automation, { Position = UDim2.fromOffset(12, 25),
        Size = UDim2.new(1, -24, 0, 14), TextSize = 10, TextColor3 = T.SubText, Text = "", ZIndex = 3 })
    self.Status = UIKit.Label(automation, {
        Position = UDim2.fromOffset(12, 44),
        Size = UDim2.new(1, -24, 0, 36),
        TextSize = 12,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Text = "starting",
        ZIndex = 3,
    })
    local toggleBtn, setToggleColor = UIKit.Button(automation, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 10, 1, -10),
        Size = UDim2.new(1, -20, 0, 32),
        BackgroundColor3 = T.Good,
        Font = UIKit.Fonts.Bold,
        TextSize = 13,
        TextColor3 = Color3.fromRGB(12, 14, 18),
        Text = "Pause",
        ZIndex = 3,
    })
    UIKit.Corner(toggleBtn, 9)
    self.ToggleButton = toggleBtn
    self.SetToggleColor = setToggleColor

    -- Dungeon (violet)
    local dungeon = UIKit.Card(home, {
        Position = UDim2.fromOffset(0, gridTop + rowH + 10),
        Size = UDim2.new(0.5, -5, 0, rowH),
    }, T.Accent)
    UIKit.Label(dungeon, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Dungeon", ZIndex = 3 })
    self.DungeonName = UIKit.Label(dungeon, { Position = UDim2.fromOffset(12, 25),
        Size = UDim2.new(1, -24, 0, 14), TextSize = 10, TextColor3 = T.SubText, Text = "-", ZIndex = 3 })
    self.TimeLeftLabel = UIKit.Tile(dungeon, "Time left", UDim2.fromOffset(10, 46), UDim2.new(0.5, -14, 0, 38))
    self.ProgressLabel = UIKit.Tile(dungeon, "Progress", UDim2.new(0.5, 4, 0, 46), UDim2.new(0.5, -14, 0, 38))
    self.RetryStatus = UIKit.Label(dungeon, {
        Position = UDim2.fromOffset(12, 92),
        Size = UDim2.new(1, -24, 0, 32),
        TextSize = 10,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = T.SubText,
        Text = "Retry: waiting for the final boss",
        ZIndex = 3,
    })

    -- Config (gold)
    local configCard = UIKit.Card(home, {
        Position = UDim2.new(0.5, 5, 0, gridTop + rowH + 10),
        Size = UDim2.new(0.5, -5, 0, rowH),
        GlowRotation = 20,
    }, T.Warn)
    UIKit.Label(configCard, { Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18),
        Font = UIKit.Fonts.Bold, TextSize = 14, Text = "Config", ZIndex = 3 })
    UIKit.Label(configCard, { Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 14),
        TextSize = 10, TextColor3 = T.SubText, Text = "Tap to manage configs", ZIndex = 3 })
    local homeActive = UIKit.Tile(configCard, "In use", UDim2.fromOffset(10, 46), UDim2.new(1, -20, 0, 38))
    local homeAutoLoad = UIKit.Tile(configCard, "Auto Load", UDim2.fromOffset(10, 88), UDim2.new(0.5, -14, 0, 38))
    local homeAutoExec = UIKit.Tile(configCard, "Auto Execute", UDim2.new(0.5, 4, 0, 88), UDim2.new(0.5, -14, 0, 38))
    local configTap = UIKit.New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
        Parent = configCard,
    })
    configTap.MouseButton1Click:Connect(function()
        selectTab("Configs")
    end)
    table.insert(self.ConfigRefreshers, function()
        homeActive.Text = controller.ActiveConfig or "defaults (not saved)"
        homeAutoLoad.Text = controller.AutoLoadConfig ~= "" and controller.AutoLoadConfig or "off"
        homeAutoExec.Text = controller.AutoExecuteOnTeleport and "on" or "off"
        homeAutoLoad.TextColor3 = controller.AutoLoadConfig ~= "" and T.Good or T.SubText
        homeAutoExec.TextColor3 = controller.AutoExecuteOnTeleport and T.Good or T.SubText
    end)

    -----------------------------------------------------------------------
    -- Automation
    -----------------------------------------------------------------------
    local automationPage = newPage("Automation", true)
    pageHeader(automationPage, 0, "Automation", "What the script does for you")

    local function toggleRow(page, order, title, description, getter, setter, refreshers)
        local row = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Size = UDim2.new(1, 0, 0, 52),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
            Text = "",
            LayoutOrder = order,
            ZIndex = 2,
            Parent = page,
        })
        UIKit.Corner(row, 10)
        UIKit.Stroke(row, T.Stroke, 0.45)
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -80, 0, 18),
            Font = UIKit.Fonts.Semi,
            TextSize = 13,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 27),
            Size = UDim2.new(1, -80, 0, 16),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = description,
            ZIndex = 3,
        })
        local _, setSwitch = UIKit.Switch(row, UDim2.new(1, -14, 0.5, 0))
        local function refresh(instant)
            setSwitch(getter() == true, instant)
        end
        row.MouseEnter:Connect(function()
            UIKit.Tween(row, 0.15, { BackgroundColor3 = T.Tile })
        end)
        row.MouseLeave:Connect(function()
            UIKit.Tween(row, 0.2, { BackgroundColor3 = T.Card })
        end)
        row.MouseButton1Click:Connect(function()
            setter(not getter())
            refresh()
        end)
        refresh(true)
        table.insert(refreshers or self.ControlRefreshers, refresh)
        return row
    end

    self.AddToggleRow = toggleRow   -- later parts can add their own switches

    local function setMaster(value)
        controller.Enabled = value
        if not value then
            pcall(function()
                controller.Character:ReleaseAutomationFacing()
                controller.Dodger.CommittedDodgeDirection = Vector3.zero
                controller.Dodger.DodgeCommitUntil = 0
            end)
        end
        self:RefreshControls()
    end

    toggleRow(automationPage, 1, "Master Auto", "Turns all automation on or off",
        function() return controller.Enabled end, setMaster)
    toggleRow(automationPage, 2, "Auto Combat", "Casts Q / E at the chosen target",
        function() return controller.AutoCombat end,
        function(value) controller.AutoCombat = value end)
    toggleRow(automationPage, 3, "Smart Dodge", "Moves out of attack warnings and hitboxes",
        function() return controller.AutoDodge end,
        function(value) controller.AutoDodge = value end)
    toggleRow(automationPage, 4, "Auto Retry", "Replays the dungeon when it ends",
        function() return controller.AutoRetryEnabled end,
        function(value) controller.AutoRetryEnabled = value end)
    toggleRow(automationPage, 5, "Hazard ESP", "Draws attack hitboxes",
        function() return controller.AutoESP end,
        function(value) controller.AutoESP = value end)
    toggleRow(automationPage, 6, "Path Visualizer", "Draws the walking route",
        function() return controller.AutoPathESP end,
        function(value) controller.AutoPathESP = value end)
    toggleRow(automationPage, 7, "Dodge Aura Dots", "Shows safe / unsafe spots around you",
        function() return controller.ShowAura end,
        function(value) controller.ShowAura = value end)
    toggleRow(automationPage, 8, "Mob Group Circles", "Marks enemy packs",
        function() return controller.ShowMobGroups end,
        function(value) controller.ShowMobGroups = value end)
    toggleRow(automationPage, 9, "Low Effects", "Hides attack effects in boss fights and when the game lags",
        function() return controller.LowEffects ~= false end,
        function(value)
            controller.LowEffects = value
            if not value and controller.LowFx then
                controller.LowFx:Disable()
            end
        end)

    -----------------------------------------------------------------------
    -- Settings
    -----------------------------------------------------------------------
    local settingsPage = newPage("Settings", true)
    pageHeader(settingsPage, 0, "Settings", "Movement and combat tuning")

    local function sliderRow(order, title, description, getter, setter, minimum, maximum, step)
        local row = UIKit.New("Frame", {
            Size = UDim2.new(1, 0, 0, 72),
            BackgroundColor3 = T.Card,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 2,
            Parent = settingsPage,
        })
        UIKit.Corner(row, 10)
        UIKit.Stroke(row, T.Stroke, 0.45)
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -90, 0, 18),
            Font = UIKit.Fonts.Semi,
            TextSize = 13,
            Text = title,
            ZIndex = 3,
        })
        UIKit.Label(row, {
            Position = UDim2.fromOffset(14, 26),
            Size = UDim2.new(1, -90, 0, 14),
            TextSize = 11,
            TextColor3 = T.Muted,
            Text = description,
            ZIndex = 3,
        })
        local valueBox = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 0, 10),
            Size = UDim2.fromOffset(52, 24),
            BackgroundColor3 = T.Tile,
            BorderSizePixel = 0,
            ZIndex = 3,
            Parent = row,
        })
        UIKit.Corner(valueBox, 7)
        local valueLabel = UIKit.Label(valueBox, {
            Size = UDim2.fromScale(1, 1),
            Font = UIKit.Fonts.Semi,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 4,
        })
        local track = UIKit.New("TextButton", {
            AutoButtonColor = false,
            Position = UDim2.new(0, 14, 0, 52),
            Size = UDim2.new(1, -28, 0, 6),
            BackgroundColor3 = T.Off,
            BorderSizePixel = 0,
            Text = "",
            ZIndex = 3,
            Parent = row,
        })
        UIKit.Corner(track, 3)
        local fill = UIKit.New("Frame", {
            Size = UDim2.fromScale(0, 1),
            BackgroundColor3 = T.White,
            BorderSizePixel = 0,
            ZIndex = 4,
            Parent = track,
        })
        UIKit.Corner(fill, 3)
        UIKit.Gradient(fill, T.Accent, T.Accent2, 0)
        local knob = UIKit.New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0, 0.5),
            Size = UDim2.fromOffset(16, 16),
            BackgroundColor3 = T.White,
            BorderSizePixel = 0,
            ZIndex = 5,
            Parent = track,
        })
        UIKit.Corner(knob, 8)

        local function refresh()
            local value = getter()
            local alpha = math.clamp((value - minimum) / (maximum - minimum), 0, 1)
            fill.Size = UDim2.fromScale(alpha, 1)
            knob.Position = UDim2.fromScale(alpha, 0.5)
            valueLabel.Text = tostring(value)
        end

        local dragging = false
        local function update(x)
            local width = math.max(track.AbsoluteSize.X, 1)
            local alpha = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
            local value = minimum + math.floor(alpha * (maximum - minimum) / step + 0.5) * step
            setter(math.clamp(value, minimum, maximum))
            refresh()
        end
        track.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = true
                self.SliderDragging = true
                update(input.Position.X)
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch)
            then
                update(input.Position.X)
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging = false
                self.SliderDragging = false
            end
        end)
        refresh()
        table.insert(self.ControlRefreshers, refresh)
    end

    sliderRow(1, "Walk Speed", "Character speed (game default is 16)",
        function() return CONFIG.WalkSpeed end,
        function(value)
            CONFIG.WalkSpeed = value
            local humanoid = controller.Character.Humanoid
            if humanoid and humanoid.WalkSpeed <= 24 then
                humanoid.WalkSpeed = math.max(value, 16)
            end
        end, 12, 40, 1)
    sliderRow(2, "Combat Range", "Distance kept from normal enemies",
        function() return CONFIG.DesiredCombatRange end,
        function(value) CONFIG.DesiredCombatRange = value end, 24, 60, 1)
    sliderRow(3, "Damage Range", "How far away spells are cast",
        function() return CONFIG.DamageCastRange end,
        function(value) CONFIG.DamageCastRange = value end, 30, 80, 1)

    local keysCard = UIKit.Card(settingsPage, { Size = UDim2.new(1, 0, 0, 92), LayoutOrder = 4 })
    UIKit.Label(keysCard, { Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 18),
        Font = UIKit.Fonts.Semi, TextSize = 13, Text = "Window", ZIndex = 3 })
    UIKit.Label(keysCard, { Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 14),
        TextSize = 11, TextColor3 = T.Muted, Text = "RightShift shows / hides this window", ZIndex = 3 })
    local unloadButton = UIKit.Button(keysCard, {
        Position = UDim2.new(0, 14, 0, 50),
        Size = UDim2.new(0, 150, 0, 30),
        BackgroundColor3 = Color3.fromRGB(70, 30, 40),
        TextColor3 = T.Bad,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Unload script",
        ZIndex = 3,
    })
    UIKit.Corner(unloadButton, 8)
    local unloadArmed = 0
    unloadButton.MouseButton1Click:Connect(function()
        if os.clock() - unloadArmed > 3 then
            unloadArmed = os.clock()
            unloadButton.Text = "Tap again to unload"
            task.delay(3, function()
                if unloadButton.Parent then unloadButton.Text = "Unload script" end
            end)
            return
        end
        controller:Destroy()
    end)

    -----------------------------------------------------------------------
    -- Configs
    -----------------------------------------------------------------------
    local configsPage = newPage("Configs", true)
    pageHeader(configsPage, 0, "Configs", "Save, load and delete your setups")

    -- save row
    local saveCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1 })
    local nameBox = UIKit.New("TextBox", {
        Position = UDim2.fromOffset(12, 12),
        Size = UDim2.new(1, -124, 0, 32),
        BackgroundColor3 = T.Tile,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = UIKit.Fonts.Body,
        TextSize = 13,
        TextColor3 = T.Text,
        PlaceholderText = "Config name (e.g. northern lands)",
        PlaceholderColor3 = T.Muted,
        Text = controller.ActiveConfig or "",
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Parent = saveCard,
    })
    UIKit.Corner(nameBox, 8)
    UIKit.Padding(nameBox, 10, 0, 10, 0)
    local saveButton = UIKit.GradientButton(saveCard, {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.fromOffset(100, 32),
        Text = "Save",
        ZIndex = 3,
    })
    saveButton.MouseButton1Click:Connect(function()
        local name = ConfigStore.CleanName(nameBox.Text)
            or self.SelectedConfig
            or controller.ActiveConfig
            or "default"
        if controller:SaveConfig(name) then
            self.SelectedConfig = name
            nameBox.Text = name
            self:RefreshConfigs()
        end
    end)

    -- list
    local listCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 150), LayoutOrder = 2 })
    local listFrame = UIKit.New("ScrollingFrame", {
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = T.Muted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 3,
        Parent = listCard,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = listFrame,
    })
    UIKit.Padding(listFrame, 2, 2, 2, 2)
    local emptyLabel = UIKit.Label(listCard, {
        Size = UDim2.fromScale(1, 1),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = T.Muted,
        TextSize = 12,
        Text = "No saved configs yet - type a name and press Save",
        ZIndex = 3,
    })

    local deleteArmed = { Name = nil, At = 0 }

    local function smallButton(parent, text, color, textColor, x)
        local button = UIKit.Button(parent, {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, x, 0.5, 0),
            Size = UDim2.fromOffset(64, 26),
            BackgroundColor3 = color,
            Font = UIKit.Fonts.Semi,
            TextSize = 12,
            TextColor3 = textColor,
            Text = text,
            ZIndex = 5,
        })
        UIKit.Corner(button, 7)
        return button
    end

    local function rebuildList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        local names = controller:ListConfigs()
        emptyLabel.Visible = #names == 0
        if self.SelectedConfig and not table.find(names, self.SelectedConfig) then
            self.SelectedConfig = nil
        end
        for index, name in ipairs(names) do
            local selected = name == self.SelectedConfig
            local item = UIKit.New("TextButton", {
                AutoButtonColor = false,
                Size = UDim2.new(1, -6, 0, 38),
                BackgroundColor3 = selected and T.TileHover or T.Tile,
                BorderSizePixel = 0,
                Text = "",
                LayoutOrder = index,
                ZIndex = 4,
                Parent = listFrame,
            })
            UIKit.Corner(item, 8)
            if selected then
                UIKit.Stroke(item, T.Accent, 0.2, 1.5)
            end
            local tags = {}
            if name == controller.ActiveConfig then table.insert(tags, "in use") end
            if name == controller.AutoLoadConfig then table.insert(tags, "auto load") end
            UIKit.Label(item, {
                Position = UDim2.fromOffset(12, 3),
                Size = UDim2.new(1, -170, 0, 18),
                Font = UIKit.Fonts.Semi,
                TextSize = 13,
                Text = name,
                ZIndex = 5,
            })
            UIKit.Label(item, {
                Position = UDim2.fromOffset(12, 19),
                Size = UDim2.new(1, -170, 0, 14),
                TextSize = 10,
                TextColor3 = #tags > 0 and T.Good or T.Muted,
                Text = #tags > 0 and table.concat(tags, "  •  ") or "saved",
                ZIndex = 5,
            })
            local loadButton = smallButton(item, "Load", Color3.fromRGB(38, 58, 104), T.Text, -78)
            local armed = deleteArmed.Name == name and os.clock() - deleteArmed.At < 3
            local deleteButton = smallButton(item, armed and "Sure?" or "Delete",
                Color3.fromRGB(78, 30, 42), T.Bad, -8)

            item.MouseButton1Click:Connect(function()
                self.SelectedConfig = name
                nameBox.Text = name
                self:RefreshConfigs()
            end)
            loadButton.MouseButton1Click:Connect(function()
                self.SelectedConfig = name
                nameBox.Text = name
                controller:LoadConfig(name)
            end)
            deleteButton.MouseButton1Click:Connect(function()
                if deleteArmed.Name ~= name or os.clock() - deleteArmed.At > 3 then
                    deleteArmed.Name, deleteArmed.At = name, os.clock()
                    deleteButton.Text = "Sure?"
                    task.delay(3, function()
                        if deleteButton.Parent and deleteArmed.Name == name then
                            deleteButton.Text = "Delete"
                        end
                    end)
                    return
                end
                deleteArmed.Name = nil
                if controller:DeleteConfig(name) then
                    if nameBox.Text == name then
                        nameBox.Text = ""
                    end
                    self.SelectedConfig = nil
                    self:RefreshConfigs()
                end
            end)
        end
    end

    -- switches
    local configSwitches = {}
    toggleRow(configsPage, 3, "Auto Load", "Load the selected config every time the script starts",
        function()
            local target = self.SelectedConfig or controller.ActiveConfig
            return controller.AutoLoadConfig ~= "" and controller.AutoLoadConfig == target
        end,
        function(value)
            if value then
                local target = self.SelectedConfig or controller.ActiveConfig
                if not target then
                    controller:Notify("Select or save a config first", "error")
                    return
                end
                controller:SetAutoLoad(target)
            else
                controller:SetAutoLoad("")
            end
        end, configSwitches)
    toggleRow(configsPage, 4, "Auto Execute", "Run the script again after every teleport",
        function() return controller.AutoExecuteOnTeleport end,
        function(value) controller:SetAutoExecute(value) end, configSwitches)

    local infoCard = UIKit.Card(configsPage, { Size = UDim2.new(1, 0, 0, 84), LayoutOrder = 5 })
    self.ScriptPathLabel = UIKit.Label(infoCard, {
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.new(1, -28, 0, 30),
        TextSize = 11,
        TextWrapped = true,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextColor3 = T.SubText,
        ZIndex = 3,
    })
    local resetButton = UIKit.Button(infoCard, {
        Position = UDim2.new(0, 14, 0, 44),
        Size = UDim2.new(0, 150, 0, 30),
        BackgroundColor3 = T.Tile,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Reset to defaults",
        ZIndex = 3,
    })
    UIKit.Corner(resetButton, 8)
    resetButton.MouseButton1Click:Connect(function()
        controller:ResetSettings()
    end)
    local refreshButton = UIKit.Button(infoCard, {
        Position = UDim2.new(0, 172, 0, 44),
        Size = UDim2.new(0, 110, 0, 30),
        BackgroundColor3 = T.Tile,
        Font = UIKit.Fonts.Semi,
        TextSize = 12,
        Text = "Refresh list",
        ZIndex = 3,
    })
    UIKit.Corner(refreshButton, 8)
    refreshButton.MouseButton1Click:Connect(function()
        self:RefreshConfigs()
    end)

    table.insert(self.ConfigRefreshers, function()
        rebuildList()
        for _, refresh in ipairs(configSwitches) do
            refresh()
        end
        local path = controller:GetScriptPath()
        local found = SafeFile.IsFile(path)
        self.ScriptPathLabel.Text = found
            and ("Auto Execute runs  workspace/" .. path .. "  after a teleport")
            or ("Auto Execute needs the script saved as  workspace/" .. path .. "  (build.cmd -Volt)")
        self.ScriptPathLabel.TextColor3 = found and T.SubText or T.Warn
    end)

    -----------------------------------------------------------------------
    -- toasts
    -----------------------------------------------------------------------
    local toastHolder = UIKit.New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -16, 1, -16),
        Size = UDim2.fromOffset(300, 300),
        BackgroundTransparency = 1,
        ZIndex = 50,
        Parent = gui,
    })
    UIKit.New("UIListLayout", {
        Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = toastHolder,
    })
    self.ToastHolder = toastHolder
    self.ToastCount = 0

    -----------------------------------------------------------------------
    -- minimise bubble
    -----------------------------------------------------------------------
    local bubble, bubbleFrame = UIKit.GradientButton(gui, {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 16, 0.5, 0),
        Size = UDim2.fromOffset(48, 48),
        Text = "UIW",
        TextSize = 14,
        Rotation = 45,
        Visible = false,
        ZIndex = 40,
    }, 24)
    UIKit.Stroke(bubbleFrame, T.White, 0.6, 1.5)
    self.Bubble = bubbleFrame

    local function showWindow(show)
        self.Visible = show
        holder.Visible = show
        bubbleFrame.Visible = not show
        if show then
            updateScale()
            local target = scale.Scale
            scale.Scale = target * 0.96
            UIKit.Tween(scale, 0.25, { Scale = target })
        end
    end
    self.ShowWindow = showWindow

    minimizeButton.MouseButton1Click:Connect(function()
        showWindow(false)
    end)
    closeButton.MouseButton1Click:Connect(function()
        showWindow(false)
        self:Notify("Hidden - press RightShift or tap the UIW button", "info")
    end)

    -----------------------------------------------------------------------
    -- dragging (window by the title bar, bubble anywhere)
    -----------------------------------------------------------------------
    local function makeDraggable(handle, target, onClick)
        local dragging, moved, dragStart, startPosition = false, false, nil, nil
        handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch
            then
                dragging, moved = true, false
                dragStart = input.Position
                startPosition = target.Position
            end
        end)
        connect(UserInputService.InputChanged, function(input)
            if not dragging or self.SliderDragging then return end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local delta = input.Position - dragStart
                if delta.Magnitude > 4 then moved = true end
                target.Position = UDim2.new(
                    startPosition.X.Scale, startPosition.X.Offset + delta.X,
                    startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
                )
            end
        end)
        connect(UserInputService.InputEnded, function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch)
            then
                dragging = false
                if not moved and onClick then onClick() end
            end
        end)
    end
    makeDraggable(titleBar, holder)
    makeDraggable(bubble, bubbleFrame, function() showWindow(true) end)

    toggleBtn.MouseButton1Click:Connect(function()
        setMaster(not controller.Enabled)
    end)

    selectTab("Home")
    self:RefreshControls()
    self:RefreshConfigs()
    if controller.StartupNotice then
        task.delay(0.5, function()
            self:Notify(controller.StartupNotice, "success")
        end)
    end

    return self
end

---------------------------------------------------------------------------
function HUD:Notify(text, kind)
    if not self.ToastHolder or not self.ToastHolder.Parent then
        return
    end
    local T = UIKit.Theme
    local color = ({
        success = T.Good,
        error = T.Bad,
        warning = T.Warn,
        info = T.Accent2,
    })[kind or "info"] or T.Accent2

    self.ToastCount += 1
    local toast = UIKit.New("Frame", {
        Size = UDim2.fromOffset(290, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = T.Card,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = self.ToastCount,
        ZIndex = 51,
        Parent = self.ToastHolder,
    })
    UIKit.Corner(toast, 10)
    local stroke = UIKit.Stroke(toast, color, 1, 1)
    UIKit.Padding(toast, 14, 10, 12, 10)
    local bar = UIKit.New("Frame", {
        Position = UDim2.new(0, -8, 0, 0),
        Size = UDim2.new(0, 3, 1, 0),
        BackgroundColor3 = color,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 52,
        Parent = toast,
    })
    UIKit.Corner(bar, 2)
    local label = UIKit.Label(toast, {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        TextSize = 12,
        TextTransparency = 1,
        Text = tostring(text),
        ZIndex = 52,
    })

    UIKit.Tween(toast, 0.25, { BackgroundTransparency = 0.05 })
    UIKit.Tween(stroke, 0.25, { Transparency = 0.3 })
    UIKit.Tween(bar, 0.25, { BackgroundTransparency = 0 })
    UIKit.Tween(label, 0.25, { TextTransparency = 0 })

    task.delay(3.5, function()
        if not toast.Parent then return end
        UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
        UIKit.Tween(stroke, 0.3, { Transparency = 1 })
        UIKit.Tween(bar, 0.3, { BackgroundTransparency = 1 })
        UIKit.Tween(label, 0.3, { TextTransparency = 1 })
        task.wait(0.35)
        safeDestroy(toast)
    end)
end

function HUD:SetStatus(action, text)
    local color = STATUS_COLORS[action] or COLORS.Idle
    self.Accent.BackgroundColor3 = color
    self.Badge.TextColor3 = color
    self.Badge.Text = action == "IDLE" and "Automation: paused"
        or ("Automation: " .. string.lower(tostring(action)))
    self.Status.Text = text or action
end

local function readWorkspaceValue(name)
    local value = Workspace:FindFirstChild(name)
    if value and value:IsA("ValueBase") then
        return value.Value
    end
    return nil
end

function HUD:Heartbeat()
    self.Frames += 1

    local now = os.clock()
    local elapsed = now - self.StartTime

    if now - self.LastFpsUpdate >= 0.5 then
        local duration = now - self.LastFpsUpdate
        self.FPSLabel.Text = tostring(math.floor(self.Frames / duration)) .. " fps"
        self.Frames = 0
        self.LastFpsUpdate = now

        local hours = math.floor(elapsed / 3600)
        self.Playtime.Text = hours > 0
            and string.format("%d:%02d:%02d", hours, math.floor(elapsed / 60) % 60, math.floor(elapsed % 60))
            or string.format("%02d:%02d", math.floor(elapsed / 60), math.floor(elapsed % 60))

        local ping = 0
        pcall(function()
            ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        self.Ping.Text = tostring(ping) .. " ms"
    end

    if now - self.LastSlowUpdate >= 1 then
        self.LastSlowUpdate = now
        self.PlayersLabel.Text = tostring(#Players:GetPlayers()) .. " / " .. tostring(Players.MaxPlayers)

        local dungeonName = readWorkspaceValue("dungeonName")
        dungeonName = (dungeonName and dungeonName ~= "") and tostring(dungeonName) or "Lobby / not in a dungeon"
        self.DungeonName.Text = dungeonName
        self.ProfileSub.Text = "@" .. tostring(LocalPlayer.Name) .. "  •  " .. dungeonName

        local timeLeft = tonumber(readWorkspaceValue("timeLeft"))
        self.TimeLeftLabel.Text = (timeLeft and timeLeft > 0)
            and string.format("%d:%02d", math.floor(timeLeft / 60), timeLeft % 60)
            or "-"
        local progress = readWorkspaceValue("dungeonProgress")
        self.ProgressLabel.Text = (progress and progress ~= "") and tostring(progress) or "-"
    end
end

function HUD:Toggle()
    if self.ShowWindow then
        self.ShowWindow(not self.Visible)
    else
        self.Visible = not self.Visible
        self.Main.Visible = self.Visible
    end
end

function HUD:RefreshControls()
    for _, refresh in ipairs(self.ControlRefreshers or {}) do
        pcall(refresh)
    end

    local T = UIKit.Theme
    local enabled = self.Controller.Enabled
    if self.ToggleButton then
        self.ToggleButton.Text = enabled and "Pause automation" or "Resume automation"
        self.SetToggleColor(enabled and T.Good or T.Bad)
    end
    if self.AutomationCard then
        UIKit.SetGlow(self.AutomationCard, enabled and T.Good or T.Bad)
        self.AutomationState.Text = enabled and "Running - tap to pause" or "Paused - tap to resume"
    end
    if not enabled then
        self:SetStatus("IDLE", "paused")
    end
end

function HUD:RefreshConfigs()
    for _, refresh in ipairs(self.ConfigRefreshers or {}) do
        local ok, err = pcall(refresh)
        if not ok then
            warn("[UIW] config panel: " .. tostring(err))
        end
    end
end

function HUD:SetRetryStatus(text, color)
    if not self.RetryStatus then return end
    self.RetryStatus.Text = "Retry: " .. tostring(text)
    self.RetryStatus.TextColor3 = color or UIKit.Theme.SubText
end

function HUD:Destroy()
    for _, connection in ipairs(self.Connections or {}) do
        pcall(function() connection:Disconnect() end)
    end
    self.Connections = {}
    safeDestroy(self.Gui)
end

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

--[[
    UIW v38 — Combat + Dodge upgrade patch

    HOW TO INSTALL (one paste, nothing to delete):
      Paste this whole block into your script DIRECTLY ABOVE these two lines
      near the very bottom:

          local Controller =
              UIWController.new()

      Every class (HazardTracker, DodgeSolver, CombatController, HUD,
      UIWController) is already defined at that point, so this block just
      replaces the methods listed below. The rest of your script is untouched.

    COMBAT
      * Won't cast damage skills while facing the wrong way (e.g. during an
        emergency body turn). The cooldown is saved for a cast that can hit.
      * Won't cast damage skills through walls (line-of-sight check). Mobs,
        players, doorway "entry" parts and invisible parts don't count as walls.
      * Aims up to 24° off the target when that puts more mobs inside the
        skill's forward hitbox. The locked target always stays inside it.
      * Only waits for the buff when that's worth it: if the buff has a long
        cooldown and the damage skill is ready, it attacks without the buff.
      * If staging with everything ready doesn't fire the buff within 3 s,
        stops waiting instead of standing still forever.
      * Any damage cast clears the commit (before, only E did).
      * Doesn't press Q/E while a chat or text box has focus.
      * Caches tool lookups instead of scanning the backpack several times
        per frame.

    DODGE
      * Escaping a hitbox you're already inside now measures the real exit
        distance in each direction and takes the shortest safe one. It also
        tries turning the body's thin side toward the exit.
      * When you're inside a moving projectile, the escape heads sideways off
        its path instead of racing it.
      * The "aura" no longer counts every still hitbox within 34 studs as a
        threat (that caused constant jitter-dodging). Still hitboxes count
        within 7 studs. Moving projectiles count only if they're closing in
        and would reach you within about 1.2 s.
      * The aura scan scores directions cheaply first, then fully checks only
        the best ones (with a budget), so boss fights stutter less.
      * Scoring prefers moving sideways to an incoming projectile's path and
        penalizes running toward it.
      * Melee panic weights close mobs more heavily, checks that the path
        doesn't brush past a mob, and now also avoids projectiles and
        telegraph (precast) zones.
      * A committed dodge lane is only reused if it's still clear of
        telegraphs and has safe ground.
      * If you enter a hitbox between solver ticks, it re-solves immediately
        instead of waiting for the next tick.
      * When no safe option exists, it steps away from the threat instead of
        freezing in place.
      * Body-overlap queries are memoized per hazard-cache tick, which cuts a
        large share of the physics queries.

    HUD
      * Adds colors for the MECHANIC and PROGRESSION states.
      * Shows why a cast was held (turning to target / no line of sight).
]]

do
    ---------------------------------------------------------------------------
    -- Tuning
    ---------------------------------------------------------------------------
    CONFIG.CastHitboxWidth = 16          -- width of the forward damage hitbox (studs)
    CONFIG.AimMaxOffsetDegrees = 24      -- max aim deviation from the locked target
    CONFIG.CastFacingTolerance = 28      -- degrees; damage casts wait until facing is this close
    CONFIG.LosBypassDistance = 18        -- closer than this, skip the line-of-sight check
    CONFIG.BuffMaxWait = 4.0             -- max seconds worth waiting for a buff when damage is ready
    CONFIG.MaxStageHold = 3.0            -- max seconds to stand at the staging line with everything ready
    CONFIG.StaticAuraRadius = 7          -- still hitboxes trigger the aura only this close
    CONFIG.ProjectileAuraTime = 1.2      -- moving projectiles trigger the aura within this time-to-contact
    CONFIG.ExitProbeMax = 26             -- how far to search for a hitbox exit
    CONFIG.ExitProbeStep = 2
    CONFIG.AuraDodgeBudget = 90          -- full safety checks allowed per aura solve
    CONFIG.AuraPointThreatLimit = 60     -- GetPointThreat below this = acceptable destination
    CONFIG.DodgeUrgentResolve = true

    local SLOTS = { "q", "e" }

    local function yawToDirection(yaw)
        return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
    end

    ---------------------------------------------------------------------------
    -- HazardTracker
    ---------------------------------------------------------------------------
    local legacyGetBodyOverlaps = HazardTracker.GetBodyOverlaps

    function HazardTracker:GetBodyOverlaps(position, yaw)
        self:RefreshCache(false)

        local stamp = self.LastCacheTime
        if self.OverlapMemoStamp ~= stamp or not self.OverlapMemo then
            self.OverlapMemoStamp = stamp
            self.OverlapMemo = {}
        end

        local key = (self.TightPadding and "t" or "n") .. string.format(
            "%d:%d:%d:%d",
            math.floor(position.X * 2 + 0.5),
            math.floor(position.Y * 2 + 0.5),
            math.floor(position.Z * 2 + 0.5),
            math.floor(((yaw or 0) % (math.pi * 2)) * 8 + 0.5)
        )

        local cached = self.OverlapMemo[key]
        if cached then
            return cached
        end

        local result = legacyGetBodyOverlaps(self, position, yaw)
        self.OverlapMemo[key] = result
        return result
    end

    function HazardTracker:GetAuraThreat(position, radius)
        radius = radius or CONFIG.AuraRadius

        local best = nil
        local bestDistance = radius
        local bestUrgency = math.huge

        for _, data in ipairs(self:GetActive()) do
            local part = data.Part
            if part and part.Parent then
                local lp = part.CFrame:PointToObjectSpace(position)
                local half = part.Size * 0.5
                local distance = Vector3.new(
                    math.max(math.abs(lp.X) - half.X, 0),
                    math.max(math.abs(lp.Y) - half.Y, 0),
                    math.max(math.abs(lp.Z) - half.Z, 0)
                ).Magnitude

                if distance <= radius then
                    local urgency = nil
                    local velocity = self:GetProjectileVelocity(data)

                    if velocity.Magnitude >= CONFIG.ProjectileVelocityMin then
                        local closing = velocity:Dot(unit(position - part.Position))
                        if closing > CONFIG.ProjectileVelocityMin * 0.5 then
                            local timeToContact = distance / closing
                            if timeToContact <= CONFIG.ProjectileAuraTime then
                                urgency = timeToContact
                            end
                        end
                    elseif distance <= CONFIG.StaticAuraRadius then
                        urgency = distance / math.max(CONFIG.WalkSpeed, 1)
                    end

                    if urgency and urgency < bestUrgency then
                        best = data
                        bestUrgency = urgency
                        bestDistance = distance
                    end
                end
            end
        end

        return best, bestDistance
    end

    ---------------------------------------------------------------------------
    -- DodgeSolver
    ---------------------------------------------------------------------------
    local legacyActiveEscape = DodgeSolver.GetActiveHitboxEscape
    local legacyScoreCandidate = DodgeSolver.ScoreCandidate

    function DodgeSolver:ScoreCandidate(direction, preferred, yaw)
        local score = legacyScoreCandidate(self, direction, preferred, yaw)
        if not score then
            return nil
        end

        local threat = self.IncomingProjectile
        if threat and threat.Part and threat.Part.Parent then
            local velocity = flatten(self.Hazards:GetProjectileVelocity(threat))
            if velocity.Magnitude > 0.1 then
                local along = unit(flatten(direction)):Dot(velocity.Unit)
                score += (1 - math.abs(along)) * 160
                if along < -0.5 then
                    score -= 200 -- running into it
                end
            end
        end

        return score
    end

    function DodgeSolver:GetActiveHitboxEscape(targetYaw)
        local root = self.CharacterService.Root
        local origin = root.Position
        local overlaps = self.Hazards:GetCurrentOverlaps(targetYaw)

        if #overlaps == 0 then
            return nil
        end

        local seed = Vector3.zero
        local insideProjectile = false

        for _, part in ipairs(overlaps) do
            if part and part.Parent then
                local data = self.Hazards.Hazards[part]
                local velocity = data and flatten(self.Hazards:GetProjectileVelocity(data)) or Vector3.zero

                if velocity.Magnitude >= CONFIG.ProjectileVelocityMin then
                    -- Moving projectile: leave its path sideways.
                    insideProjectile = true
                    local offset = flatten(origin - part.Position)
                    local perpendicular = offset - velocity.Unit * offset:Dot(velocity.Unit)
                    if perpendicular.Magnitude < 0.2 then
                        perpendicular = Vector3.new(-velocity.Z, 0, velocity.X)
                    end
                    seed += unit(perpendicular) * 1.5
                else
                    local warningExit = self.Hazards:GetWarningExitDirection(part, origin)
                    if warningExit then
                        seed += warningExit
                    else
                        local lp = part.CFrame:PointToObjectSpace(origin)
                        local half = part.Size * 0.5
                        local localDirection
                        if half.X - math.abs(lp.X) < half.Z - math.abs(lp.Z) then
                            localDirection = Vector3.new(lp.X >= 0 and 1 or -1, 0, 0)
                        else
                            localDirection = Vector3.new(0, 0, lp.Z >= 0 and 1 or -1)
                        end
                        seed += unit(flatten(part.CFrame:VectorToWorldSpace(localDirection)))
                    end
                end
            end
        end

        seed = unit(seed)
        if seed.Magnitude <= 0 then
            seed = unit(flatten(root.CFrame.LookVector))
        end

        local angles = { 0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180 }
        local exitStep = 1.5
        local bestDirection, bestYaw, bestPoint = nil, nil, nil
        local bestDistance = math.huge
        local bestScore = -math.huge

        local function search(yaw, isTargetYaw)
            for _, angle in ipairs(angles) do
                local direction = unit(rotateXZ(seed, angle))
                local limit = math.min(CONFIG.ExitProbeMax, bestDistance + 4)
                local exitDistance = nil
                local d = exitStep

                while d <= limit do
                    if self.Hazards:IsFullBodyClear(origin + direction * d, yaw) then
                        exitDistance = d
                        break
                    end
                    d += exitStep
                end

                if exitDistance then
                    local travel = exitDistance + 0.75
                    local endpoint = origin + direction * travel

                    local ok = self.Hazards:IsFullBodyClear(endpoint, yaw)
                        and self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding)
                        and self.Geometry:IsDirectionClear(direction, travel, yaw)
                        and (insideProjectile
                            or self.Hazards:IsPredictiveTrajectoryClear(origin, direction, yaw, travel))

                    if ok then
                        local score = -exitDistance * 60
                            + direction:Dot(seed) * 25
                            + self.Geometry:GetEdgeClearanceScore(endpoint) * 8
                            - self:GetMeleePenalty(endpoint) * 0.15

                        if not isTargetYaw then
                            score -= 30
                        end

                        if self.LastMovement.Magnitude > 0 then
                            score += direction:Dot(self.LastMovement) * 10
                        end

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestYaw = yaw
                            bestDistance = exitDistance
                            bestPoint = endpoint
                        end
                    end
                end
            end
        end

        -- v42: search with tight padding so narrow safe gaps (the cube pylon's
        -- ring between bullseye and outer bars) are found at all.
        self.Hazards.TightPadding = true
        local okSearch, searchErr = pcall(function()
            search(targetYaw, true)
            if not bestDirection or bestDistance > 6 then
                search(directionToYaw(seed), false)
            end
        end)
        self.Hazards.TightPadding = false
        if not okSearch then
            warn("[UIW] exit search failed: " .. tostring(searchErr))
        end

        if bestDirection then
            self.SelectedAuraPoint = bestPoint
            return bestDirection, bestYaw, bestYaw ~= targetYaw
        end

        return legacyActiveEscape(self, targetYaw)
    end

    function DodgeSolver:GetMeleePanicEscape(targetYaw, routeDirection)
        local root = self.CharacterService.Root
        local origin = root.Position
        local threats = self.Dungeon:GetMeleeThreats(origin, CONFIG.MultiMeleeRadius)

        if #threats == 0 then
            self.MeleePanicActive = false
            return nil
        end

        local nearest = math.huge
        local closeCount = 0
        local trigger = false
        local center = Vector3.zero
        local weightSum = 0

        for _, info in ipairs(threats) do
            local proximity = info.ThreatClass == "Proximity"
            local emergencyRadius = CONFIG.MeleeEmergencyRadius
                + (proximity and CONFIG.ProximityEmergencyBonus or 0)
            local clusterRadius = CONFIG.MeleeClusterPanicRadius
                + (proximity and CONFIG.ProximitySafetyBonus or 0)

            nearest = math.min(nearest, info.Distance)

            if info.Distance <= emergencyRadius then
                trigger = true
            end
            if info.Distance <= clusterRadius then
                closeCount += 1
            end

            -- Close mobs dominate the escape direction.
            local weight = 1 / (math.max(info.Distance, 4) ^ 2)
            center += info.Enemy.Root.Position * weight
            weightSum += weight
        end

        if closeCount >= CONFIG.MeleeClusterPanicCount then
            trigger = true
        end

        if not self.MeleePanicActive then
            if not trigger then
                return nil
            end
            self.MeleePanicActive = true
        elseif nearest >= CONFIG.MeleePanicExitRadius + CONFIG.ProximityEmergencyBonus
            and closeCount == 0
        then
            self.MeleePanicActive = false
            return nil
        end

        center /= weightSum

        local away = unit(flatten(origin - center))
        if away.Magnitude <= 0 then
            away = unit(flatten(-root.CFrame.LookVector))
        end

        local towardCluster = -away
        local orbit = self:GetSafeOrbitTangent(towardCluster, targetYaw)
        routeDirection = unit(flatten(routeDirection or Vector3.zero))
        local base = unit(away * 0.72 + orbit * 0.92)

        local function predictedDistance(info, point)
            local enemyRoot = info.Enemy.Root
            local t = info.ThreatClass == "Proximity" and 0.42 or 0.32
            local predicted = enemyRoot.Position + flatten(enemyRoot.AssemblyLinearVelocity) * t
            return flatten(predicted - point).Magnitude
        end

        local bestDirection = nil
        local bestScore = -math.huge

        for _, angle in ipairs({ 0, 20, -20, 40, -40, 60, -60, 80, -80, 100, -100, 125, -125, 150, -150, 180 }) do
            local direction = unit(rotateXZ(base, angle))
            local future = origin + direction * 10

            if self.Geometry:IsGroundPadded(future, CONFIG.EdgeHardPadding) then
                local futureMin = math.huge
                local sum = 0
                local hard = false
                local emergencyHit = false
                local midpoint = origin + direction * 5

                for _, info in ipairs(threats) do
                    local proximity = info.ThreatClass == "Proximity"
                    local d = predictedDistance(info, future)
                    local dMid = predictedDistance(info, midpoint)

                    futureMin = math.min(futureMin, d)
                    sum += d

                    if math.min(d, dMid) <= CONFIG.MeleeHardNoGoRadius + (proximity and 3 or 0) then
                        hard = true
                    elseif d <= CONFIG.MeleeEmergencyRadius
                        + (proximity and CONFIG.ProximityEmergencyBonus or 0)
                    then
                        emergencyHit = true
                    end
                end

                local improvement = futureMin - nearest
                local routeDot = routeDirection.Magnitude > 0 and direction:Dot(routeDirection) or 0

                local score = futureMin * 170
                    + improvement * 300
                    + sum * 8
                    + routeDot * 75
                    + direction:Dot(orbit) * 40
                    + self.Geometry:GetEdgeClearanceScore(future) * 22

                if hard then
                    score -= 12000
                elseif emergencyHit then
                    score -= 4500
                end
                if improvement < 0.75 then
                    score -= 500
                end
                if routeDot < -0.45 then
                    score -= 350
                end

                -- Expensive safety checks only for candidates that could win.
                if score > bestScore
                    and self.Geometry:IsDirectionClear(direction, 8, targetYaw)
                    and self.Hazards:IsTrajectoryClear(origin, direction, targetYaw, 8)
                    and self.Hazards:IsPredictiveTrajectoryClear(origin, direction, targetYaw, 8)
                    and self.Hazards:IsPrecastTrajectoryClear(origin, direction, targetYaw, 8)
                then
                    bestScore = score
                    bestDirection = direction
                end
            end
        end

        if bestDirection then
            return bestDirection, targetYaw, false
        end

        local shortOrbit = self:GetSafeOrbitTangent(towardCluster, targetYaw)
        if shortOrbit.Magnitude > 0
            and self.Geometry:IsDirectionClear(shortOrbit, 3, targetYaw)
        then
            return shortOrbit, targetYaw, false
        end

        return nil
    end

    function DodgeSolver:IsImmediateHazardDanger(preferred, targetYaw)
        self.AuraThreat = nil
        self.AuraThreatDistance = nil
        self.IncomingProjectile = nil
        self.IncomingProjectileTime = nil

        local root = self.CharacterService.Root

        if self.Hazards:GetOverlapCountAt(root.Position, targetYaw) > 0 then
            return true
        end

        preferred = unit(flatten(preferred or Vector3.zero))

        local incoming, impactTime = self.Hazards:GetIncomingProjectileThreat(
            root.Position,
            preferred,
            targetYaw,
            preferred.Magnitude > 0 and CONFIG.DodgeDistance or 0
        )

        if incoming then
            self.IncomingProjectile = incoming
            self.IncomingProjectileTime = impactTime
            return true
        end

        local auraThreat, auraDistance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)
        self.AuraThreat = auraThreat
        self.AuraThreatDistance = auraDistance
        if auraThreat then
            return true
        end

        -- Standing still: the overlap check above already covers telegraphs
        -- landing on the current position.
        if preferred.Magnitude <= 0 then
            return false
        end

        local speed = math.min(CONFIG.WalkSpeed, self.CharacterService.Humanoid.WalkSpeed)
        local lookahead = math.max(CONFIG.DangerLookaheadDistance, speed * CONFIG.PrecastLookaheadTime)

        if not self.Hazards:IsPrecastTrajectoryClear(root.Position, preferred, targetYaw, lookahead) then
            return true
        end

        if #self.Hazards:GetActive() == 0 then
            return false
        end

        return not self.Hazards:IsTrajectoryClear(
            root.Position,
            preferred,
            targetYaw,
            CONFIG.DangerLookaheadDistance
        )
    end

    function DodgeSolver:FindExpandingAuraDodge(preferred, targetYaw)
        local root = self.CharacterService.Root
        local origin = root.Position

        preferred = unit(flatten(preferred))
        if preferred.Magnitude <= 0 then
            preferred = unit(flatten(root.CFrame.LookVector))
        end

        self.SelectedAuraPoint = nil

        local boss = self.CurrentSolveEnemy
        local solvingBoss = boss
            and isBossEnemy(boss)
            and boss.Root
            and boss.Root.Parent
        local auraPart = self.AuraThreat and self.AuraThreat.Part
        local away = (auraPart and auraPart.Parent) and unit(flatten(origin - auraPart.Position)) or Vector3.zero

        local projectileDirection = Vector3.zero
        if self.IncomingProjectile then
            local v = flatten(self.Hazards:GetProjectileVelocity(self.IncomingProjectile))
            if v.Magnitude > 0.1 then
                projectileDirection = v.Unit
            end
        end

        local budget = CONFIG.AuraDodgeBudget
        local forward, forwardScore, forwardPoint = nil, -math.huge, nil
        local fallback, fallbackScore, fallbackPoint = nil, -math.huge, nil

        for _, radius in ipairs(CONFIG.AuraScanRadii) do
            if budget <= 0 then
                break
            end

            local candidates = {}

            for index = 1, CONFIG.AuraDotsPerRing do
                local direction = unit(rotateXZ(preferred, ((index - 1) / CONFIG.AuraDotsPerRing) * 360))
                local point = origin + direction * radius

                local score = direction:Dot(preferred) * (solvingBoss and 180 or 220)
                score += direction:Dot(away) * (solvingBoss and 90 or 260)

                if projectileDirection.Magnitude > 0 then
                    score += (1 - math.abs(direction:Dot(projectileDirection))) * 200
                end

                local bossAdvance = 0
                if solvingBoss then
                    -- v40: "forward" means toward the boss distance band, not onto the boss.
                    bossAdvance = self:GetBossBandError(origin) - self:GetBossBandError(point)
                    score += bossAdvance * 40 - radius * 1.5
                end

                candidates[#candidates + 1] = {
                    Direction = direction,
                    Point = point,
                    Score = score,
                    BossAdvance = bossAdvance,
                }
            end

            table.sort(candidates, function(a, b)
                return a.Score > b.Score
            end)

            -- Best-first: the first candidate that passes every check wins the ring.
            for _, c in ipairs(candidates) do
                if budget <= 0 then
                    break
                end

                local pointThreat = self.Hazards:GetPointThreat(c.Point)

                if pointThreat < CONFIG.AuraPointThreatLimit
                    and not self.Dungeon:GetEnemyDangerAt(c.Point)
                then
                    budget -= 1

                    if self.Geometry:IsGroundPadded(c.Point, CONFIG.EdgeHardPadding)
                        and self.Hazards:IsTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Hazards:IsPredictiveTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Hazards:IsPrecastTrajectoryClear(origin, c.Direction, targetYaw, radius)
                        and self.Geometry:IsDirectionClear(c.Direction, radius, targetYaw)
                    then
                        local finalScore = c.Score
                            - pointThreat * 2
                            + self.Geometry:GetEdgeClearanceScore(c.Point) * 20

                        if not solvingBoss then
                            self.SelectedAuraPoint = c.Point
                            return c.Direction, targetYaw, false
                        end

                        if c.BossAdvance >= -1 and finalScore > forwardScore then
                            forward, forwardScore, forwardPoint = c.Direction, finalScore, c.Point
                        end
                        if finalScore > fallbackScore then
                            fallback, fallbackScore, fallbackPoint = c.Direction, finalScore, c.Point
                        end

                        break
                    end
                end
            end
        end

        if forward then
            self.SelectedAuraPoint = forwardPoint
            return forward, targetYaw, false
        end

        if fallback then
            self.SelectedAuraPoint = fallbackPoint
            return fallback, targetYaw, false
        end

        return nil
    end

    function DodgeSolver:FindEmergencyOrientation(preferred, targetYaw)
        local bestDirection, bestYaw = nil, nil
        local bestScore = -math.huge

        for _, angle in ipairs(CONFIG.DodgeAngles) do
            local direction = unit(rotateXZ(preferred, angle))
            local movementYaw = directionToYaw(direction)

            -- 0 = facing the movement (thin along travel),
            -- ±90 = side-on (thin across travel, squeezes between hitboxes).
            for _, yawOffset in ipairs({ 90, -90, 0 }) do
                local yaw = movementYaw + math.rad(yawOffset)
                local score = self:ScoreCandidate(direction, preferred, yaw)

                if score then
                    score -= math.abs(angleDifference(yaw, targetYaw)) * 8
                    if score > bestScore then
                        bestScore = score
                        bestDirection = direction
                        bestYaw = yaw
                    end
                end
            end
        end

        if bestDirection then
            return bestDirection, bestYaw, true
        end

        return nil
    end

    -- v42 Cube Pylon bullseye: a 10x10 center square plus four 34x7 bars about
    -- 17 studs out. The only safe place is the thin ring between them, so move
    -- to the middle of that ring and stand still until the shot has fired.
    function DodgeSolver:GetBullseyeEscape(targetYaw)
        local root = self.CharacterService.Root
        local now = os.clock()
        local best = nil

        for _, data in ipairs(self.Hazards:GetActive()) do
            local container = data.Container
            if container and container.Name == "cubePylonShot" and container.Parent then
                local state = self.Hazards.ContainerState[container]
                local age = state and now - state.FirstSeen or 0
                if age <= CONFIG.BullseyeWindow and (not best or best.Container ~= container) then
                    local distance = flatten(container:GetPivot().Position - root.Position).Magnitude
                    if distance <= 40 and (not best or age < best.Age) then
                        best = { Container = container, Age = age }
                    end
                end
            end
        end

        if not best then
            self.BullseyeTarget = nil
            return nil
        end

        -- Measure the pattern from its parts.
        local center, bars = nil, {}
        for _, part in ipairs(best.Container:GetDescendants()) do
            if part:IsA("BasePart") and part.Name == "hitBox" then
                if math.max(part.Size.X, part.Size.Z) <= 16 then
                    center = part
                else
                    table.insert(bars, part)
                end
            end
        end
        if not center or #bars == 0 then
            return nil
        end

        local frame = center.CFrame
        local centerHalf = math.max(center.Size.X, center.Size.Z) * 0.5
        local inner = math.huge
        for _, bar in ipairs(bars) do
            local rel = frame:PointToObjectSpace(bar.Position)
            local thickness = math.min(bar.Size.X, bar.Size.Z)
            inner = math.min(inner, math.max(math.abs(rel.X), math.abs(rel.Z)) - thickness * 0.5)
        end

        local body = self.CharacterService.BodySize
        local bodyHalf = math.max(body.X, body.Z) * 0.5
        local safeMin = centerHalf + bodyHalf + CONFIG.BullseyeMargin
        local safeMax = inner - bodyHalf - CONFIG.BullseyeMargin
        if safeMax <= safeMin then
            return nil -- no ring wide enough; let the normal escape handle it
        end
        local ringRadius = (safeMin + safeMax) * 0.5

        local localPos = frame:PointToObjectSpace(root.Position)
        local norm = math.max(math.abs(localPos.X), math.abs(localPos.Z))
        local outer = inner + math.min(bars[1].Size.X, bars[1].Size.Z) + bodyHalf + CONFIG.BullseyeMargin

        if norm >= outer then
            return nil -- already outside the whole pattern
        end

        -- Other attacks (e.g. pyramid lines) at a position, ignoring this bullseye.
        local function otherHazardAt(position)
            for _, hit in ipairs(self.Hazards:GetBodyOverlaps(position, targetYaw)) do
                local hitData = self.Hazards.Hazards[hit]
                if not (hitData and hitData.Container == best.Container) then
                    return true
                end
            end
            return false
        end

        if norm >= safeMin and norm <= safeMax then
            self.Hazards.TightPadding = true
            local covered = otherHazardAt(root.Position)
            self.Hazards.TightPadding = false
            if not covered then
                self.BullseyeTarget = nil
                return Vector3.zero, targetYaw, false -- in the ring: hold still
            end
        end

        -- Candidate ring points: the player's own direction first, then the 8 compass points.
        local candidates = {}
        if norm > 0.5 then
            local scale = ringRadius / norm
            table.insert(candidates, Vector3.new(localPos.X * scale, 0, localPos.Z * scale))
        end
        for i = 0, 7 do
            local angle = math.rad(i * 45)
            local dx, dz = math.cos(angle), math.sin(angle)
            local m = math.max(math.abs(dx), math.abs(dz))
            table.insert(candidates, Vector3.new(dx / m * ringRadius, 0, dz / m * ringRadius))
        end

        local chosen, chosenDistance = nil, math.huge
        self.Hazards.TightPadding = true
        for _, localTarget in ipairs(candidates) do
            local world = frame:PointToWorldSpace(Vector3.new(localTarget.X, localPos.Y, localTarget.Z))
            local distance = flatten(world - root.Position).Magnitude
            if distance > 0.8 and distance < chosenDistance and self.Geometry:HasGround(world) then
                -- Only other attacks may block a ring point.
                if not otherHazardAt(world) then
                    chosen, chosenDistance = world, distance
                end
            end
        end
        self.Hazards.TightPadding = false

        if not chosen then
            return nil
        end

        self.BullseyeTarget = chosen
        self.SelectedAuraPoint = chosen
        local delta = flatten(chosen - root.Position)
        if delta.Magnitude < 0.6 then
            return Vector3.zero, targetYaw, false
        end
        return delta.Unit * math.clamp(delta.Magnitude / 2, 0.35, 1), targetYaw, false
    end

    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local now = os.clock()
        local root = self.CharacterService.Root
        local origin = root.Position

        self.CurrentSolveEnemy = enemy

        if now - self.LastSolve < CONFIG.DodgeSolveInterval then
            local urgent = CONFIG.DodgeUrgentResolve
                and (self.LastDodgeReason == "bullseye"
                    or (not self.CachedDodging
                        and self.Hazards:GetOverlapCountAt(origin, targetYaw) > 0))

            if not urgent then
                self.IsDodging = self.CachedDodging
                return self.CachedDirection,
                    self.CachedYaw,
                    self.CachedEmergency,
                    self.CachedDodging
            end
        end

        self.LastSolve = now
        self.SelectedAuraPoint = nil
        self.AuraThreat = nil
        self.AuraThreatDistance = nil
        self.IncomingProjectile = nil

        local direction, yaw, emergency
        local dodging = false
        local reason = nil

        -- 0) Cube Pylon bullseye: go to the safe ring and wait there.
        direction, yaw, emergency = self:GetBullseyeEscape(targetYaw)
        if direction then
            dodging = true
            reason = "bullseye"
        end

        -- 1) Already inside an attack: get out.
        if not direction then
            direction, yaw, emergency = self:GetActiveHitboxEscape(targetYaw)
            if direction then
                dodging = true
                reason = "hitbox"
            end
        end

        -- 2) Crystal Golem thin sweeper.
        if not direction then
            direction, yaw, emergency = self:GetCrystalGolemSweeperEscape(enemy, targetYaw)
            if direction then
                dodging = true
                reason = "sweeper"
            end
        end

        -- 3) Melee panic.
        if not direction then
            direction, yaw, emergency = self:GetMeleePanicEscape(targetYaw, routeDirection)
            if direction then
                dodging = true
                reason = "melee"
            end
        end

        local preferred = self:GetCombatPreferred(routeDirection, enemy, targetYaw)

        -- 4) Is the next bit of movement actually threatened?
        local danger = false
        if not direction then
            danger = self:IsImmediateHazardDanger(preferred, targetYaw)
        end

        if danger or direction then
            self.LastDangerTime = now
        end

        if danger and preferred.Magnitude <= 0 then
            preferred = unit(flatten(routeDirection))
            if preferred.Magnitude <= 0 then
                preferred = unit(flatten(root.CFrame.LookVector))
            end
        end

        -- Keep a recent escape lane while it stays fully safe.
        local committed = self.CommittedDodgeDirection
        local withinCommit = committed.Magnitude > 0
            and now < self.DodgeCommitUntil
            and now - self.LastDangerTime <= CONFIG.DodgeCommitTime + CONFIG.DodgeReleaseGrace

        if not direction and withinCommit then
            local probe = CONFIG.DodgeReuseProbeDistance
            local reusable = self.Geometry:IsDirectionClear(committed, probe, targetYaw)
                and self.Geometry:IsGroundPadded(origin + committed * probe, CONFIG.EdgeHardPadding)
                and self.Hazards:IsTrajectoryClear(origin, committed, targetYaw, probe)
                and self.Hazards:IsPredictiveTrajectoryClear(origin, committed, targetYaw, probe)
                and self.Hazards:IsPrecastTrajectoryClear(origin, committed, targetYaw, probe)

            if reusable then
                direction, yaw, emergency = committed, targetYaw, false
                dodging = true
                reason = "committed"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindExpandingAuraDodge(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "aura"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindNormalDodge(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "normal"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindEmergencyOrientation(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "orientation"
            end
        end

        if not direction and danger then
            direction, yaw, emergency = self:FindLeastRiskEscape(preferred, targetYaw)
            if direction then
                dodging = true
                reason = "least-risk"
            end
        end

        -- Nothing passed: step away from the threat rather than freezing.
        if not direction and danger then
            local sourcePart = (self.AuraThreat and self.AuraThreat.Part)
                or (self.IncomingProjectile and self.IncomingProjectile.Part)
            local awayDirection = Vector3.zero

            if sourcePart and sourcePart.Parent then
                awayDirection = unit(flatten(origin - sourcePart.Position))
            end

            if awayDirection.Magnitude > 0
                and self.Geometry:IsDirectionClear(awayDirection, 3, targetYaw)
                and self.Geometry:HasGround(origin + awayDirection * 3)
            then
                direction = awayDirection
            else
                direction = Vector3.zero
            end

            yaw, emergency, dodging = targetYaw, false, true
            reason = "fallback"
        end

        -- 5) No danger: normal movement.
        if not direction then
            if self.RetreatActive and not self.ForceRouteMovement then
                direction = self:FindOpenMovement(preferred, targetYaw)
            elseif self.ForceRouteMovement or self.TravelMode then
                direction = preferred
            else
                direction = self:FindOpenMovement(preferred, targetYaw)
            end
            yaw = targetYaw
            emergency = false
            dodging = false
        end

        direction = direction or Vector3.zero
        yaw = yaw or targetYaw
        emergency = emergency or false

        self.CachedDirection = direction
        self.CachedYaw = yaw
        self.CachedEmergency = emergency
        self.CachedDodging = dodging
        self.IsDodging = dodging
        self.LastDodgeReason = reason

        if reason == "bullseye" then
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
        elseif dodging and direction.Magnitude > 0 then
            local changedLane = self.CommittedDodgeDirection.Magnitude <= 0
                or direction:Dot(self.CommittedDodgeDirection) < 0.60
                or now >= self.DodgeCommitUntil

            if changedLane then
                self.CommittedDodgeDirection = unit(flatten(direction))
                self.DodgeCommitUntil = now + CONFIG.DodgeCommitTime
            end
        elseif now - self.LastDangerTime > CONFIG.DodgeReleaseGrace then
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
        end

        if direction.Magnitude > 0 then
            self.LastMovement = direction
        end

        return direction, yaw, emergency, dodging
    end

    ---------------------------------------------------------------------------
    -- CombatController
    ---------------------------------------------------------------------------
    local legacyGetTool = CombatController.GetTool

    function CombatController:GetTool(slot)
        self.ToolCache = self.ToolCache or {}

        local now = os.clock()
        local entry = self.ToolCache[slot]

        if entry and now - entry.Time < 0.5 then
            local tool = entry.Tool
            if tool == nil then
                return nil
            end

            local parent = tool.Parent
            if parent ~= nil
                and (parent == LocalPlayer.Backpack or parent == LocalPlayer.Character)
            then
                return tool
            end
        end

        local tool = legacyGetTool(self, slot)
        self.ToolCache[slot] = { Tool = tool, Time = now }
        return tool
    end

    function CombatController:CanSendInput()
        local ok, focused = pcall(function()
            return UserInputService:GetFocusedTextBox()
        end)
        return not (ok and focused)
    end

    function CombatController:GetPreparationState()
        local state = {
            HasDamage = false,
            HasBuff = false,
            DamageReady = true,
            BuffReady = true,
            DamageWait = 0,
            BuffWait = 0,
            LongestWait = 0,
            BuffWorthWaiting = false,
            AnyDamageReady = false,
        }

        for _, slot in ipairs(SLOTS) do
            local tool = self:GetTool(slot)
            if tool then
                local remaining = self:GetCooldownRemaining(slot) or 0
                local ready = self:IsSlotCooldownReady(slot)

                if self:IsBuffTool(tool) then
                    state.HasBuff = true
                    state.BuffWait = math.max(state.BuffWait, remaining)
                    if not ready then
                        state.BuffReady = false
                    end
                else
                    state.HasDamage = true
                    state.DamageWait = math.max(state.DamageWait, remaining)
                    if not ready then
                        state.DamageReady = false
                    else
                        state.AnyDamageReady = true
                    end
                end
            end
        end

        state.LongestWait = math.max(state.DamageWait, state.BuffWait)

        -- If damage is cooling longer than the buff anyway, waiting for the
        -- buff costs nothing.
        state.BuffWorthWaiting = state.HasBuff
            and not state.BuffReady
            and state.BuffWait <= math.max(CONFIG.BuffMaxWait, state.DamageWait)

        return state
    end

    function CombatController:GetLosIgnoreList()
        local now = os.clock()
        if self.LosIgnore and now - (self.LosIgnoreAt or 0) < 1 then
            return self.LosIgnore
        end

        local list = {}

        if self.CharacterService.Character then
            table.insert(list, self.CharacterService.Character)
        end

        for _, name in ipairs({ "UIW_HitboxESP", "UnderworldHitboxESP", "UIW_PathESP", "UIW_TacticalDisplay" }) do
            local folder = Workspace:FindFirstChild(name)
            if folder then
                table.insert(list, folder)
            end
        end

        local dungeon = Workspace:FindFirstChild("dungeon")
        if dungeon then
            for _, room in ipairs(dungeon:GetChildren()) do
                local enemyFolder = room:FindFirstChild("enemyFolder")
                if enemyFolder then
                    table.insert(list, enemyFolder)
                end
            end
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                table.insert(list, player.Character)
            end
        end

        self.LosIgnore = list
        self.LosIgnoreAt = now
        return list
    end

    function CombatController:HasLineOfSight(enemy)
        local root = self.CharacterService.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end

        local now = os.clock()
        local cache = self.LosCache
        if cache and cache.Model == enemy.Model and now - cache.Time < 0.15 then
            return cache.Value
        end

        local ignore = table.clone(self:GetLosIgnoreList())
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true
        params.RespectCanCollide = true

        local origin = root.Position + Vector3.new(0, 1.5, 0)
        local goal = enemy.Root.Position
        local clear = false

        for _ = 1, 8 do
            local delta = goal - origin
            if delta.Magnitude < 1 then
                clear = true
                break
            end

            params.FilterDescendantsInstances = ignore
            local hit = Workspace:Raycast(origin, delta, params)

            if not hit or hit.Instance:IsDescendantOf(enemy.Model) then
                clear = true
                break
            end

            local instance = hit.Instance
            local passable = instance ~= Workspace.Terrain
                and (
                    (instance:IsA("BasePart") and instance.Transparency >= 0.9)
                    or isEntryInstance(instance)
                )

            if not passable then
                break
            end

            table.insert(ignore, getEntryAncestor(instance) or instance)
        end

        self.LosCache = { Model = enemy.Model, Time = now, Value = clear }
        return clear
    end

    -- v41: a target on another level (stairs / ledges) or behind geometry is
    -- "blocked": keep following the path to it instead of fighting from below.
    function CombatController:IsTargetBlocked(enemy)
        local root = self.CharacterService.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end

        local offset = enemy.Root.Position - root.Position
        local isBoss = isBossEnemy(enemy)
        if not isBoss and math.abs(offset.Y) > CONFIG.EngageMaxHeightDiff then
            return true
        end

        local distance = flatten(offset).Magnitude
        local losRange = isBoss and CONFIG.BossLosCheckRange or CONFIG.StageDistance
        if distance <= losRange and distance > CONFIG.LosBypassDistance then
            return not self:HasLineOfSight(enemy)
        end

        return false
    end

    function CombatController:GetAimYaw(enemy, fallbackYaw, enemies)
        local root = self.CharacterService.Root

        if not enemy or not enemy.Root or not enemy.Root.Parent or not root then
            self.LastAimModel = nil
            return fallbackYaw
        end

        local toTarget = flatten(enemy.Root.Position - root.Position)
        local distance = toTarget.Magnitude
        if distance < 0.05 then
            return fallbackYaw
        end

        local baseDirection = toTarget.Unit
        local bestDirection = baseDirection
        local bestOffset = 0
        local bestScore = -math.huge

        if distance <= CONFIG.DamageCastRange + 10
            and enemies
            and #enemies > 1
        then
            local halfWidth = CONFIG.CastHitboxWidth * 0.5
            local sameTarget = self.LastAimModel == enemy.Model

            for _, offset in ipairs({ 0, 6, -6, 12, -12, 18, -18, 24, -24 }) do
                if math.abs(offset) <= CONFIG.AimMaxOffsetDegrees then
                    local direction = unit(rotateXZ(baseDirection, offset))
                    local right = Vector3.new(-direction.Z, 0, direction.X)

                    -- The locked target must stay well inside the hitbox.
                    if toTarget:Dot(direction) >= 0
                        and math.abs(toTarget:Dot(right)) <= halfWidth * 0.6
                    then
                        local count = 0

                        for _, other in ipairs(enemies) do
                            if other.Root
                                and other.Root.Parent
                                and other.Humanoid
                                and other.Humanoid.Health > 0
                            then
                                local rel = flatten(other.Root.Position - root.Position)
                                local forward = rel:Dot(direction)
                                if forward >= -2
                                    and forward <= CONFIG.DamageCastRange
                                    and math.abs(rel:Dot(right)) <= halfWidth + 1.5
                                then
                                    count += 1
                                end
                            end
                        end

                        local score = count * 10 - math.abs(offset) * 0.15
                        if sameTarget and offset == self.LastAimOffset then
                            score += 3 -- hysteresis, avoids aim flicker
                        end

                        if score > bestScore then
                            bestScore = score
                            bestDirection = direction
                            bestOffset = offset
                        end
                    end
                end
            end
        end

        local yaw = directionToYaw(bestDirection)
        self.LastAimModel = enemy.Model
        self.LastAimYaw = yaw
        self.LastAimOffset = bestOffset
        return yaw
    end

    function CombatController:IsFacing(yaw, toleranceDegrees)
        local root = self.CharacterService.Root
        if not root then
            return false
        end

        local look = unit(flatten(root.CFrame.LookVector))
        if look.Magnitude <= 0 then
            return false
        end

        local dot = math.clamp(look:Dot(yawToDirection(yaw)), -1, 1)
        return math.deg(math.acos(dot)) <= toleranceDegrees
    end

    -- v40 staging: wait just outside cast range until the attack is ready,
    -- even while navigating (the old version only held in a tiny band).
    function CombatController:ShouldHoldApproach(enemy, travelMode)
        self.CooldownHolding = false

        if not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or not self.CharacterService:IsAlive()
        then
            self:ClearCommit()
            self.ReadySince = nil
            return false
        end

        if isBossEnemy(enemy) then
            return false
        end

        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude

        if distance > CONFIG.StageDistance or distance <= CONFIG.DamageCastRange then
            self.ReadySince = nil
            return false
        end

        local state = self:GetPreparationState()
        if not state.HasDamage then
            return false
        end

        local now = os.clock()

        local function hold()
            self.CooldownHolding = true
            return true
        end

        -- Buff already cast: wait out the cast lock, then commit.
        if self:IsCommitArmed(enemy) then
            if self:IsBusyCasting() then
                return hold()
            end
            if state.DamageReady then
                return false
            end
            return hold()
        end

        if not state.DamageReady then
            self.ReadySince = nil
            -- v42: leave early so skills come off cooldown right as we arrive.
            local speed = math.max(self.CharacterService.Humanoid and self.CharacterService.Humanoid.WalkSpeed or 16, 1)
            local travelTime = math.max(0, distance - CONFIG.DamageCastRange) / speed
            if not state.AnyDamageReady and state.DamageWait > travelTime + CONFIG.CommitLeadTime then
                return hold()
            end
            if state.AnyDamageReady then
                return false
            end
            return false
        end

        if state.HasBuff then
            if state.BuffReady then
                -- Update() casts the buff from here. If it never fires, stop waiting.
                self.ReadySince = self.ReadySince or now
                if now - self.ReadySince > CONFIG.MaxStageHold then
                    return false
                end
                return hold()
            end

            self.ReadySince = nil
            if state.BuffWorthWaiting then
                return hold()
            end
        end

        return false
    end

    -- v40 hit & run: after a damage cast on normal mobs, back off until the
    -- damage skills are nearly ready again.
    function CombatController:ShouldRetreat(enemy)
        self.RetreatActive = false

        if not CONFIG.HitAndRun
            or not self.RetreatArmed
            or not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or isBossEnemy(enemy)
            or not self.CharacterService:IsAlive()
        then
            self.RetreatArmed = false
            return false
        end

        local now = os.clock()
        local state = self:GetPreparationState()

        -- Cooldown values can lag a frame behind the key press.
        if now - (self.RetreatArmedAt or 0) > 0.5 then
            if state.AnyDamageReady or state.DamageWait <= CONFIG.RetreatResumeWait then
                self.RetreatArmed = false
                return false
            end
        end

        if now - (self.RetreatArmedAt or 0) > 20 then
            self.RetreatArmed = false
            return false
        end

        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance >= CONFIG.RetreatDistance then
            return false
        end

        self.RetreatActive = true
        return true
    end

    function CombatController:GetHoldText()
        if self:IsBusyCasting() then
            return "priming attack"
        end

        if self.RetreatActive then
            local s = self:GetPreparationState()
            return string.format("hit & run | backing off, damage ready in %.1fs", s.DamageWait)
        end

        local state = self:GetPreparationState()

        if not state.DamageReady then
            return string.format("waiting damage cooldown | %.1fs", state.DamageWait)
        end

        if state.HasBuff and not state.BuffReady then
            return string.format("waiting buff | %.1fs", state.BuffWait)
        end

        if state.HasBuff then
            return "casting buff before engaging"
        end

        return "attack ready | holding aggro line"
    end

    function CombatController:Update(enemy)
        self.LastAction = nil
        self.LastBlockReason = nil

        if not enemy
            or not enemy.Root
            or not enemy.Root.Parent
            or not self.CharacterService:IsAlive()
        then
            self:ClearCommit()
            return false
        end

        if not self:CanSendInput() then
            self.LastBlockReason = "chat focused"
            return false
        end

        if CONFIG.NoCastWhileEscaping and self.EscapingHitbox then
            self.LastBlockReason = "escaping hitbox"
            return false
        end

        local root = self.CharacterService.Root
        local distance = flatten(enemy.Root.Position - root.Position).Magnitude
        local inRange = distance <= CONFIG.DamageCastRange
        local staging = not inRange and distance <= CONFIG.StageDistance

        local state = self:GetPreparationState()

        local aimYaw = (self.LastAimModel == enemy.Model and self.LastAimYaw)
            or directionToYaw(flatten(enemy.Root.Position - root.Position))

        local losOk = nil

        for _, slot in ipairs(SLOTS) do
            local tool = self:GetTool(slot)

            if tool and self:IsReady(slot) then
                local isBuff = self:IsBuffTool(tool)
                local allowed = false

                if isBuff then
                    allowed = inRange or (staging and state.DamageReady)
                elseif inRange then
                    if not self:IsFacing(aimYaw, CONFIG.CastFacingTolerance) then
                        self.LastBlockReason = "turning to target"
                    else
                        if losOk == nil then
                            losOk = distance <= CONFIG.LosBypassDistance
                                or self:HasLineOfSight(enemy)
                        end

                        if losOk then
                            allowed = true
                        else
                            self.LastBlockReason = "no line of sight"
                        end
                    end
                end

                if allowed then
                    if isBuff then
                        if staging then
                            self:ArmCommit(enemy)
                        end
                    else
                        self:ClearCommit()
                        if not isBossEnemy(enemy) then
                            self.RetreatArmed = true
                            self.RetreatArmedAt = os.clock()
                        end
                    end

                    self:Press(slot)
                    return true
                end
            end
        end

        return false
    end

    ---------------------------------------------------------------------------
    -- UIWController: aim at the best spot instead of dead-center on the target
    ---------------------------------------------------------------------------
    local legacyGetTargetYaw = UIWController.GetTargetYaw

    function UIWController:GetTargetYaw()
        local base = legacyGetTargetYaw(self)
        return self.Combat:GetAimYaw(
            self.CurrentEnemy,
            base,
            self.Dungeon:GetAliveEnemies()
        )
    end

    ---------------------------------------------------------------------------
    -- HUD
    ---------------------------------------------------------------------------
    local legacySetStatus = HUD.SetStatus
    local EXTRA_STATUS_COLORS = {
        MECHANIC = Color3.fromRGB(80, 220, 235),
        PROGRESSION = COLORS.Pathing,
    }

    function HUD:SetStatus(action, text)
        local combat = self.Controller and self.Controller.Combat
        if combat
            and combat.LastBlockReason
            and (action == "MOVING" or action == "RUNNING")
        then
            text = tostring(text or action) .. " | " .. combat.LastBlockReason
        end

        legacySetStatus(self, action, text)

        local color = EXTRA_STATUS_COLORS[action]
        if color then
            self.Accent.BackgroundColor3 = color
            self.Badge.TextColor3 = color
        end
    end

    print("[UIW] v42 combat + dodge section applied")
end

-- v44: bounded hazard prediction, attack opportunities, and wide navigation.
do
    CONFIG.PathPreferredRadius = 4.5
    CONFIG.MajorWarningWidth = 44
    CONFIG.MajorEscapeLimit = 220

    local legacyHazardPart = HazardTracker.IsHazardPart
    function HazardTracker:IsHazardPart(part)
        -- Enemy decorations (e.g. Generator.headOrb) are not damage hitboxes.
        if part:IsA("BasePart") and not isExactAttackPartName(self, part) then
            local model = part.Parent
            for _ = 1, 6 do
                if not model or model == Workspace then break end
                if model:IsA("Model") and model:FindFirstChildOfClass("Humanoid") then
                    return false
                end
                model = model.Parent
            end
        end
        return legacyHazardPart(self, part)
    end

    local legacyTank = HazardTracker.IsTankable
    function HazardTracker:IsTankable(data)
        -- Sparse damage history must never suppress an impending large attack.
        if data.IsPrecast or data.GrowWarning then return false end
        local size = data.Part.Size
        if math.min(size.X, size.Z) >= CONFIG.MajorWarningWidth then return false end
        return legacyTank(self, data)
    end

    function RoutePlanner:CreatePath(radius)
        self:PruneAvoidZones()
        return PathfindingService:CreatePath({
            AgentRadius = radius or CONFIG.PathPreferredRadius,
            AgentHeight = CONFIG.PathAgentHeight,
            AgentCanJump = true, AgentCanClimb = true,
            WaypointSpacing = CONFIG.PathWaypointSpacing,
            Costs = { UIWAvoid = CONFIG.AvoidZoneCost },
        })
    end

    function GeometrySensor:IsWideSegmentClear(origin, destination, radius)
        local delta = flatten(destination - origin)
        if delta.Magnitude < 0.1 then return true end
        local size = self:GetSweepSize()
        size = Vector3.new(math.max(size.X, radius * 2), size.Y, math.max(size.Z, radius * 2))
        local center = origin + Vector3.new(0, math.max(0.8, size.Y * 0.28), 0)
        local hit, ok = self:BlockcastSkippingEntries(CFrame.new(center), size, delta)
        if not ok or hit then return false end
        local samples = math.max(1, math.ceil(delta.Magnitude / 3))
        for i = 1, samples do
            if not self:HasGround(origin:Lerp(destination, i / samples)) then return false end
        end
        return true
    end

    function RoutePlanner:SkipToVisibleWaypoint(targetYaw)
        local root = self.CharacterService.Root
        if not root then return false end
        for index = math.min(#self.Waypoints, self.WaypointIndex + 5), self.WaypointIndex + 1, -1 do
            local waypoint = self.Waypoints[index]
            local skipJump = false
            for j = self.WaypointIndex, index do
                if self.Waypoints[j].Action == Enum.PathWaypointAction.Jump then skipJump = true break end
            end
            local delta = flatten(waypoint.Position - root.Position)
            if not skipJump and delta.Magnitude > 2 and delta.Magnitude <= 28
                and math.abs(waypoint.Position.Y - root.Position.Y) <= 3
                and self.Geometry:IsWideSegmentClear(root.Position, waypoint.Position, CONFIG.PathPreferredRadius)
                and self.Hazards:IsTrajectoryClear(root.Position, delta.Unit, targetYaw, delta.Magnitude)
                and self.Hazards:IsPrecastTrajectoryClear(root.Position, delta.Unit, targetYaw, delta.Magnitude)
            then
                self.WaypointIndex = index
                self.LastJumpWaypoint = 0
                self:SetupWaypointPlane()
                return true
            end
        end
        return false
    end

    local legacyPreferred = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        self.AttackHolding = false
        if not self.ForceRouteMovement and not self.TargetBlocked and isBossEnemy(enemy)
            and enemy.Root and enemy.Root.Parent and self.Combat
            and normalizeEnemyName(enemy.Model.Name) ~= "crystal golem" then
            local root = self.CharacterService.Root
            local delta = flatten(enemy.Root.Position - root.Position)
            local distance = delta.Magnitude
            if distance > CONFIG.BossMaxRange and distance <= 150
                and math.abs(enemy.Root.Position.Y-root.Position.Y) <= 20
                and self.Combat:HasLineOfSight(enemy) then
                local probe = math.min(18,distance-CONFIG.BossIdealRange)
                local destination=root.Position+delta.Unit*probe
                if self.Geometry:IsWideSegmentClear(root.Position,destination,CONFIG.PathPreferredRadius) then
                    self.TravelMode=false
                    return delta.Unit
                end
            end
            if distance >= CONFIG.BossMinRange and distance <= CONFIG.BossMaxRange
                and self.Combat:HasLineOfSight(enemy) then
                local state = self.Combat:GetPreparationState()
                if state.AnyDamageReady or self.Combat:IsBusyCasting() then
                    -- Only normal movement holds. The hazard solver still runs first.
                    self.TravelMode = false
                    self.AttackHolding = true
                    return Vector3.zero
                end
            end
        end
        return legacyPreferred(self, routeDirection, enemy, targetYaw)
    end

    local legacyAim = CombatController.GetAimYaw
    function CombatController:GetAimYaw(enemy, fallbackYaw, enemies)
        if isBossEnemy(enemy) and enemy.Root and enemy.Root.Parent then
            local yaw = directionToYaw(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
            self.LastAimModel, self.LastAimYaw, self.LastAimOffset = enemy.Model, yaw, 0
            return yaw
        end
        return legacyAim(self, enemy, fallbackYaw, enemies)
    end

    local legacyCombat = CombatController.Update
    function CombatController:Update(enemy)
        if self.SuppressForMajorEscape then
            self.LastAction = nil
            self.LastBlockReason = "moving to safety before casting"
            return false
        end
        if not isBossEnemy(enemy) then return legacyCombat(self, enemy) end
        self.LastAction, self.LastBlockReason = nil, nil
        if not enemy.Root or not enemy.Root.Parent or not self.CharacterService:IsAlive() then return false end
        if not self:CanSendInput() then self.LastBlockReason = "chat focused" return false end
        if self:IsBusyCasting() then self.LastBlockReason = "casting" return false end
        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance > CONFIG.DamageCastRange then self.LastBlockReason = "outside damage range" return false end
        local yaw = directionToYaw(flatten(enemy.Root.Position - self.CharacterService.Root.Position))
        -- At 60 studs, the old 28 degree tolerance could miss a 16-stud-wide spell.
        local tolerance = math.clamp(math.deg(math.atan((CONFIG.CastHitboxWidth * 0.4) / math.max(distance, 1))), 4, 16)
        if not self:IsFacing(yaw, tolerance) then self.LastBlockReason = "turning to target" return false end
        if not self:HasLineOfSight(enemy) then self.LastBlockReason = "no line of sight" return false end
        local damageSlot, buffSlot
        for _, slot in ipairs({"q", "e"}) do
            local tool = self:GetTool(slot)
            if tool and self:IsReady(slot) then
                if self:IsBuffTool(tool) then buffSlot = buffSlot or slot
                else damageSlot = damageSlot or slot end
            end
        end
        if not damageSlot then self.LastBlockReason = "damage cooldown" return false end
        -- Prime once, then guarantee the next available input goes to damage.
        if buffSlot and (self.BossBuffTarget ~= enemy.Model or os.clock() - (self.BossBuffAt or 0) > 4) then
            self.BossBuffTarget, self.BossBuffAt = enemy.Model, os.clock()
            self:Press(buffSlot)
        else
            self:ClearCommit()
            self:Press(damageSlot)
        end
        return true
    end

    function UIWController:GetMajorWarningGoal()
        local now = os.clock()
        if now - (self.MajorScanAt or 0) < 0.18 then
            local d = self.MajorWarning
            if d and d.Part and d.Part.Parent then return self.MajorEscapeGoal, "LargeAttackEscape", nil end
            return nil
        end
        self.MajorScanAt = now
        local origin = self.Character.Root.Position
        local yaw = self.Character.DesiredYaw or 0
        local threat
        for _, d in ipairs(self.Hazards.CachedWarnings or {}) do
            if d.WarningCF and d.WarningHalf and not d.LaneCorridor then
                local cf, h = d.WarningCF, d.WarningHalf
                -- Measure the oriented floor footprint. A diagonal thin lane's
                -- world-aligned bounding box is wide in both X and Z.
                local axes={cf.RightVector,cf.UpVector,cf.LookVector}
                local widths={h.X*2,h.Y*2,h.Z*2}
                local vertical=1
                for i=2,3 do if math.abs(axes[i].Y)>math.abs(axes[vertical].Y) then vertical=i end end
                local narrow=math.huge
                for i=1,3 do
                    if i~=vertical then narrow=math.min(narrow,widths[i]*math.sqrt(math.max(0,1-axes[i].Y*axes[i].Y))) end
                end
                if narrow >= CONFIG.MajorWarningWidth
                    and self.Hazards:IsBodyInWarning(origin, yaw, d) then
                    threat = d break
                end
            end
        end
        if not threat then
            self.MajorWarning, self.MajorEscapeGoal = nil, nil
            return nil
        end
        local body = self.Character.BodySize
        local padding = math.max(body.X,body.Z)*0.5 + CONFIG.PrecastSafetyPadding + 3
        local cf, half = threat.WarningCF, threat.WarningHalf
        local localOrigin = cf:PointToObjectSpace(origin)
        local candidates = {}
        -- Ray/box exits cover a large attack without a fixed short dodge radius.
        for i = 0, 15 do
            local a = i * math.pi / 8
            local direction = Vector3.new(math.cos(a),0,math.sin(a))
            local v = cf:VectorToObjectSpace(direction)
            local exit = math.huge
            for _, axis in ipairs({"X","Y","Z"}) do
                if math.abs(v[axis]) > 0.001 then
                    local edge = v[axis] > 0 and half[axis]+padding or -half[axis]-padding
                    local t = (edge-localOrigin[axis])/v[axis]
                    if t > 0 then exit = math.min(exit,t) end
                end
            end
            if exit <= CONFIG.MajorEscapeLimit then
                table.insert(candidates, {Point=origin+direction*exit, Distance=exit})
            end
        end
        table.sort(candidates,function(a,b) return a.Distance < b.Distance end)
        local chosen, best = nil, math.huge
        local initialHits={}
        for _,part in ipairs(self.Hazards:GetBodyOverlaps(origin,yaw)) do initialHits[part]=true end
        for _, candidate in ipairs(candidates) do
            local point = candidate.Point
            local delta = flatten(point-origin)
            if self.Geometry:HasGround(point)
                and self.Geometry:IsDirectionClear(delta.Unit,delta.Magnitude,yaw)
                and self.Hazards:GetOverlapCountAt(point,yaw)==0 then
                local clear = true
                for _,d in ipairs(self.Hazards.CachedWarnings or {}) do
                    if self.Hazards:IsBodyInWarning(point,yaw,d) then clear=false break end
                end
                if clear then
                    -- Reject paths that leave the initial danger and re-enter another.
                    for step=1,math.ceil(delta.Magnitude/4) do
                        local at=origin+delta*(step/math.ceil(delta.Magnitude/4))
                        if not self.Geometry:HasGround(at) then clear=false break end
                        for _,part in ipairs(self.Hazards:GetBodyOverlaps(at,yaw)) do
                            if not initialHits[part] then clear=false break end
                        end
                        if not clear then break end
                        for _,d in ipairs(self.Hazards.CachedWarnings or {}) do
                            if not self.Hazards:IsBodyInWarning(origin,yaw,d)
                                and self.Hazards:IsBodyInWarning(at,yaw,d) then clear=false break end
                        end
                        if not clear then break end
                    end
                end
                if clear then
                    local score = candidate.Distance
                    if self.MajorEscapeGoal and (point-self.MajorEscapeGoal).Magnitude < 10 then score-=8 end
                    if score < best then chosen,best=point,score end
                end
            end
        end
        self.MajorWarning, self.MajorEscapeGoal = threat,chosen
        if chosen then return chosen,"LargeAttackEscape",nil,flatten(chosen-origin).Magnitude end
        return nil -- No verified route: retain the existing least-risk solver.
    end

    -- Aquatic Temple's Sea King uses centerPart + enabled beams, not precast.
    SAFE_ZONE_MULTI_CONTAINER_NAMES.lastbosssafezones = true
    local legacySafeZone = UIWController.GetActiveSafeZone
    function UIWController:GetActiveSafeZone()
        local part,state,distance=legacySafeZone(self)
        if not self.Character:IsAlive() then return part,state,distance end
        local zones=Workspace:FindFirstChild("lastBossSafeZones")
        if zones and isBossEnemy(self.CurrentEnemy) then
            for _,zone in ipairs(zones:GetChildren()) do
                local center=zone:FindFirstChild("centerPart")
                if center and center:IsA("BasePart") and hasEnabledSafeZoneBeam(zone) then
                    local d=flatten(center.Position-self.Character.Root.Position).Magnitude
                    if d<=250 and (not part or d<distance) then
                        part,state,distance=center,"MassSafeZone",d
                    end
                end
            end
        end
        return part,state,distance
    end

    local legacyMechanic = UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        local goal,state,part,distance = legacyMechanic(self)
        if not goal then goal,state,part,distance = self:GetMajorWarningGoal() end
        self.ActiveMechanicState = state
        self.Combat.SuppressForMajorEscape = goal ~= nil and (
            state == "LargeAttackEscape" or state == "MassSafeZone" or state == "MemorySafeZone"
            or state == "SafeZone" or state == "SafeSpotCircle" or state == "CrystalGolemWallCover")
            and flatten(goal-self.Character.Root.Position).Magnitude > 3.5
        return goal,state,part,distance
    end

    local legacySolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local owner = self.Owner
        if owner and owner.ActiveMechanicState == "LargeAttackEscape" and owner.MajorEscapeGoal then
            local delta=flatten(owner.MajorEscapeGoal-self.CharacterService.Root.Position)
            if delta.Magnitude > 0.5 and self.Geometry:IsDirectionClear(delta.Unit,math.min(delta.Magnitude,5),targetYaw) then
                self.LastDodgeReason,self.IsDodging="large-attack",true
                self.CommittedDodgeDirection=Vector3.zero
                self.DodgeCommitUntil=0
                return delta.Unit,targetYaw,false,true
            end
        end
        -- Do not reuse a backward dodge after the danger has ended during a cast window.
        if self.AttackHolding and self.Combat and self.Combat:GetPreparationState().AnyDamageReady
            and not self:IsImmediateHazardDanger(Vector3.zero,targetYaw) then
            self.CommittedDodgeDirection=Vector3.zero
            self.DodgeCommitUntil=0
        end
        return legacySolve(self,routeDirection,enemy,targetYaw)
    end

    local legacyNew = UIWController.new
    function UIWController.new()
        local self=legacyNew()
        self.Version="44"
        self.Dodger.Combat=self.Combat
        self.Dodger.Owner=self
        return self
    end
end
-- v44.1: attack-preserving dodge choices, with unchanged safety gates.
do
    function DodgeSolver:FindBossAttackDodge(enemy,targetYaw)
        if not isBossEnemy(enemy) or not enemy.Root or not enemy.Root.Parent
            or self.ForceRouteMovement or self.ForcedRegionPart or self.TargetBlocked then return nil end
        local origin=self.CharacterService.Root.Position
        local delta=flatten(enemy.Root.Position-origin)
        if delta.Magnitude<CONFIG.BossMinRange+4 or delta.Magnitude>160 then return nil end
        local toward=delta.Unit
        local best,bestScore=nil,-math.huge
        for _,angle in ipairs({0,30,-30,60,-60,90,-90}) do
            local direction=unit(rotateXZ(toward,angle))
            local point=origin+direction*CONFIG.DodgeDistance
            if flatten(enemy.Root.Position-point).Magnitude>=CONFIG.BossMinRange
                and not self.Dungeon:GetEnemyDangerAt(point) then
                local safetyScore=self:ScoreCandidate(direction,toward,targetYaw)
                if safetyScore then
                    local after=flatten(enemy.Root.Position-point).Magnitude
                    local progress=delta.Magnitude-after
                    local score=safetyScore+math.clamp(progress,-12,12)*35
                    if after<=CONFIG.DamageCastRange-3 then score+=100 end
                    if score>bestScore then best,bestScore=direction,score end
                end
            end
        end
        return best
    end

    local oldSolve=DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection,enemy,targetYaw)
        local direction,yaw,emergency,dodging=oldSolve(self,routeDirection,enemy,targetYaw)
        local reason=self.LastDodgeReason
        if isBossEnemy(enemy) and enemy.Root and enemy.Root.Parent and direction.Magnitude>0
            and not emergency and not self.ForceRouteMovement and not self.ForcedRegionPart
            and reason~="bullseye" and reason~="sweeper" and reason~="melee" and reason~="large-attack" then
            local toward=unit(flatten(enemy.Root.Position-self.CharacterService.Root.Position))
            if direction:Dot(toward)<-0.15 and os.clock()-(self.LastAttackDodgeCheck or 0)>=0.10 then
                self.LastAttackDodgeCheck=os.clock()
                local replacement=self:FindBossAttackDodge(enemy,targetYaw)
                if replacement then
                    direction,yaw,emergency,dodging=replacement,targetYaw,false,true
                    self.LastDodgeReason="attack-lane"
                    self.AttackLaneSelections=(self.AttackLaneSelections or 0)+1
                    self.CachedDirection,self.CachedYaw=direction,yaw
                    self.CachedEmergency,self.CachedDodging=false,true
                    self.CommittedDodgeDirection=direction
                    self.DodgeCommitUntil=os.clock()+CONFIG.DodgeCommitTime
                    self.LastMovement=direction
                end
            end
        end
        return direction,yaw,emergency,dodging
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.1"
        return self
    end
end
-- v44.2: reduce Protector frame stalls without dropping active hazards.
do
    CONFIG.AuraDodgeBudget = 24

    local oldRefresh = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        if self.SnapshotLocked then return end
        return oldRefresh(self,force)
    end

    function HazardTracker:IsBodyInWarning(position,yaw,data)
        if not data.WarningCF then self:UpdateWarningBounds(data) end
        local cf,half=data.WarningCF,data.WarningHalf
        if not cf or not half then return false end
        if self.WarningProjectionStamp~=self.LastCacheTime then
            self.WarningProjectionStamp=self.LastCacheTime
            self.WarningProjections={}
        end
        self.WarningProjections=self.WarningProjections or {}
        local entries=self.WarningProjections[data]
        if not entries then entries={} self.WarningProjections[data]=entries end
        local key=tostring(yaw or 0)..(self.TightPadding and ":tight" or ":normal")
        local projected=entries[key]
        if not projected or projected.CF~=cf or projected.Half~=half then
            local bodyCF=self:GetBodyCF(Vector3.zero,yaw)
            local bodyHalf=self:GetBodySize()*0.5
            local function radius(axis)
                return math.abs(axis:Dot(bodyCF.RightVector))*bodyHalf.X
                    +math.abs(axis:Dot(bodyCF.UpVector))*bodyHalf.Y
                    +math.abs(axis:Dot(bodyCF.LookVector))*bodyHalf.Z
            end
            local pad=self.TightPadding and CONFIG.TightExitPadding or CONFIG.PrecastSafetyPadding
            projected={CF=cf,Half=half,Offset=cf:VectorToObjectSpace(bodyCF.Position),
                Bounds=half+Vector3.new(radius(cf.RightVector)+pad,radius(cf.UpVector)+pad,radius(cf.LookVector)+pad)}
            entries[key]=projected
        end
        local point=cf:PointToObjectSpace(position)+projected.Offset
        local bounds=projected.Bounds
        return math.abs(point.X)<=bounds.X and math.abs(point.Y)<=bounds.Y and math.abs(point.Z)<=bounds.Z
    end

    local oldSolve=DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection,enemy,targetYaw)
        self.Hazards:RefreshCache(false)
        -- One consistent hazard snapshot for this non-yielding search. Rebuilding
        -- it during candidate checks previously invalidated overlap memoization.
        self.Hazards.SnapshotLocked=true
        local ok,a,b,c,d=pcall(oldSolve,self,routeDirection,enemy,targetYaw)
        self.Hazards.SnapshotLocked=false
        if not ok then error(a,0) end
        return a,b,c,d
    end

    local oldMechanic=UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        if self.MechanicStepStamp==self.StepStamp and self.StepStamp then
            return self.MechanicStepGoal,self.MechanicStepState,self.MechanicStepPart,self.MechanicStepDistance
        end
        local a,b,c,d=oldMechanic(self)
        self.MechanicStepStamp=self.StepStamp
        self.MechanicStepGoal,self.MechanicStepState,self.MechanicStepPart,self.MechanicStepDistance=a,b,c,d
        return a,b,c,d
    end

    local oldStep=UIWController.Step
    function UIWController:Step()
        if self.Destroyed then return end
        local now=os.clock()
        if now-(self.LastFullStep or 0)<1/30 then
            if self.Enabled and self.Character:IsAlive() then
                self.Character.Humanoid:Move(self.LastCommandedMovement or Vector3.zero,false)
            end
            return
        end
        self.LastFullStep=now
        self.StepStamp=(self.StepStamp or 0)+1
        return oldStep(self)
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.2"
        return self
    end
end
-- v44.3: Ancient Temple Protector / Water Burst strategy.
do
    CONFIG.ProtectorMinRange=18
    CONFIG.ProtectorIdealRange=24
    CONFIG.ProtectorMaxRange=32
    local function protector(enemy)
        return enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="ancient temple protector"
            and enemy.Root and enemy.Root.Parent
    end
    local function band(distance)
        return math.max(0,CONFIG.ProtectorMinRange-distance)+math.max(0,distance-CONFIG.ProtectorMaxRange)
    end
    local oldBandError=DodgeSolver.GetBossBandError
    function DodgeSolver:GetBossBandError(position)
        local e=self.CurrentSolveEnemy
        if protector(e) then return band(flatten(e.Root.Position-position).Magnitude) end
        return oldBandError(self,position)
    end
    local oldBandScore=DodgeSolver.GetBossBandScore
    function DodgeSolver:GetBossBandScore(from,to)
        local e=self.CurrentSolveEnemy
        if protector(e) then
            local before=band(flatten(e.Root.Position-from).Magnitude)
            local after=band(flatten(e.Root.Position-to).Magnitude)
            return (before-after)*120-(after>before+1 and 300 or 0)
        end
        return oldBandScore(self,from,to)
    end

    local oldPreferred=DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection,enemy,targetYaw)
        if not protector(enemy) or self.ForceRouteMovement or self.TargetBlocked then
            return oldPreferred(self,routeDirection,enemy,targetYaw)
        end
        self.AttackHolding=false
        local root=self.CharacterService.Root
        local delta=flatten(enemy.Root.Position-root.Position)
        local distance=delta.Magnitude
        if distance<0.1 or distance>160 or not self.Combat:HasLineOfSight(enemy) then
            return oldPreferred(self,routeDirection,enemy,targetYaw)
        end
        local toward=delta.Unit
        if distance>CONFIG.ProtectorMaxRange then
            local probe=math.min(12,distance-CONFIG.ProtectorIdealRange)
            if self.Geometry:IsDirectionClear(toward,probe,targetYaw)
                and self.Geometry:IsWideSegmentClear(root.Position,root.Position+toward*probe,3) then
                self.TravelMode=false
                return toward
            end
            return unit(flatten(routeDirection))
        end
        self.TravelMode=false
        local tangent=self:GetSafeOrbitTangent(toward,targetYaw)
        if distance<CONFIG.ProtectorMinRange then return unit(tangent-toward*0.35) end
        local state=self.Combat:GetPreparationState()
        if state.AnyDamageReady or self.Combat:IsBusyCasting() then
            self.AttackHolding=true
            return Vector3.zero
        end
        return tangent*0.45+toward*math.clamp((distance-CONFIG.ProtectorIdealRange)/16,-0.2,0.2)
    end

    function DodgeSolver:IsProtectorBurstActive()
        if not protector(self.CurrentSolveEnemy) then return false end
        for _,d in ipairs(self.Hazards.CachedActive) do
            local part=d.Part
            if part and part.Parent then
                if d.SlamBand then return true end
                if d.IsPrecast then
                    local hit=part.Parent:FindFirstChild("hitBox")
                    if hit and hit:IsA("BasePart") and hit.Size.Y>=120
                        and math.min(hit.Size.X,hit.Size.Z)<=16 then return true end
                end
            end
        end
        return false
    end

    function DodgeSolver:FindProtectorSideExit(targetYaw)
        local enemy=self.CurrentSolveEnemy
        if not protector(enemy) or self.ForceRouteMovement or not self:IsProtectorBurstActive() then return nil end
        local origin=self.CharacterService.Root.Position
        local delta=flatten(enemy.Root.Position-origin)
        if delta.Magnitude<CONFIG.ProtectorMinRange or delta.Magnitude>160 then return nil end
        local toward=delta.Unit
        local oldTight=self.Hazards.TightPadding
        self.Hazards.TightPadding=true
        local ok,direction=pcall(function()
            local initial={}
            for _,part in ipairs(self.Hazards:GetBodyOverlaps(origin,targetYaw)) do initial[part]=true end
            local best,bestScore=nil,-math.huge
            -- Try short lateral exits first. Going forward is considered only
            -- when it also passes every corridor and endpoint check.
            for _,length in ipairs({3,6,9,12}) do
                for _,angle in ipairs({90,-90,65,-65,40,-40}) do
                    local dir=unit(rotateXZ(toward,angle))
                    local point=origin+dir*length
                    local distance=flatten(enemy.Root.Position-point).Magnitude
                    if distance>=CONFIG.ProtectorMinRange-2 and distance<=delta.Magnitude+3
                        and self.Hazards:IsFullBodyClear(point,targetYaw)
                        and self.Geometry:IsDirectionClear(dir,length,targetYaw)
                        and self.Geometry:IsGroundPadded(point,3)
                        and not self.Dungeon:GetEnemyDangerAt(point) then
                        local clear=true
                        local departed={}
                        for step=1,math.ceil(length/2) do
                            local at=origin+dir*(length*step/math.ceil(length/2))
                            if not self.Geometry:HasGround(at) then clear=false break end
                            local present={}
                            for _,part in ipairs(self.Hazards:GetBodyOverlaps(at,targetYaw)) do
                                present[part]=true
                                if not initial[part] or departed[part] then clear=false break end
                            end
                            if not clear then break end
                            for part in pairs(initial) do if not present[part] then departed[part]=true end end
                        end
                        if clear and self.Hazards:IsPredictiveTrajectoryClear(origin,dir,targetYaw,length) then
                            local score=-length*12+(delta.Magnitude-distance)*18
                            if self.LastMovement.Magnitude>0 then score+=dir:Dot(self.LastMovement)*8 end
                            if score>bestScore then best,bestScore=dir,score end
                        end
                    end
                end
                if best then return best end
            end
            return nil
        end)
        self.Hazards.TightPadding=oldTight
        if not ok then error(direction,0) end
        return direction
    end

    local oldHitbox=DodgeSolver.GetActiveHitboxEscape
    function DodgeSolver:GetActiveHitboxEscape(targetYaw)
        if protector(self.CurrentSolveEnemy)
            and self.Hazards:GetOverlapCountAt(self.CharacterService.Root.Position,targetYaw)>0 then
            local direction=self:FindProtectorSideExit(targetYaw)
            if direction then
                self.ProtectorSideExits=(self.ProtectorSideExits or 0)+1
                return direction,targetYaw,false
            end
        end
        return oldHitbox(self,targetYaw)
    end

    local oldAura=DodgeSolver.FindExpandingAuraDodge
    function DodgeSolver:FindExpandingAuraDodge(preferred,targetYaw)
        local direction=self:FindProtectorSideExit(targetYaw)
        if direction then
            self.ProtectorSideExits=(self.ProtectorSideExits or 0)+1
            return direction,targetYaw,false
        end
        return oldAura(self,preferred,targetYaw)
    end

    local oldAttackLane=DodgeSolver.FindBossAttackDodge
    function DodgeSolver:FindBossAttackDodge(enemy,targetYaw)
        if protector(enemy) then return self:FindProtectorSideExit(targetYaw) end
        return oldAttackLane(self,enemy,targetYaw)
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.3"
        return self
    end
end

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

-- v44.8: Ancient Temple Protector cycle planner (measured live):
--   t+0.00  lines circle: 24 beams (6 wide, 15 deg apart) from a point 25 studs
--           in front of the boss; damage lands about 1 s later
--   t+1.47  squares: rings around that point, half size 15.5 + 17.5k, 12 thick
--   t+4.98  stomp wave: starts at the boss root along its facing, width = r + 10,
--           grows about 48 studs/s, lasts 5 s, one-shots
--   t+10.16 grid lines; t+15.65 the cycle repeats
do
    CONFIG.ProtRayClear = 4.4
    CONFIG.ProtRayMinDist = 33
    CONFIG.ProtRayMaxDist = 52
    CONFIG.ProtRayImpact = 1.0
    CONFIG.ProtSquareFirst = 15.5
    CONFIG.ProtSquareStep = 17.5
    CONFIG.ProtSquareCount = 5
    CONFIG.ProtSquareHalf = 6
    CONFIG.ProtSquarePad = 1.6
    CONFIG.ProtHoldUntil = 3.3
    CONFIG.ProtWedgeDelay = 4.98
    CONFIG.ProtWedgeLead = 1.7
    CONFIG.ProtWedgeSpeed = 47.6
    CONFIG.ProtWedgeLife = 5.3
    CONFIG.ProtWedgePad = 2.4
    CONFIG.ProtWedgeLength = 160
    CONFIG.ProtOrbitRadius = 20
    CONFIG.ProtOrbitMin = 12
    CONFIG.ProtOrbitMax = 30

    local function isProtector(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient temple protector"
            and enemy.Root and enemy.Root.Parent
    end

    local function perpOf(d)
        return Vector3.new(-d.Z, 0, d.X)
    end

    ---------------------------------------------------------------------------
    -- Event capture
    ---------------------------------------------------------------------------
    local oldRegister = HazardTracker.Register
    function HazardTracker:Register(part)
        local known = self.Hazards[part] ~= nil
        oldRegister(self, part)
        local data = self.Hazards[part]
        if known or not data then
            return
        end

        local owner = self.Owner
        local boss = owner and owner.CurrentEnemy
        if not isProtector(boss) then
            boss = nil
            local dungeon = owner and owner.Dungeon
            if dungeon then
                for _, enemy in ipairs(dungeon:GetAliveEnemies()) do
                    if isProtector(enemy) then
                        boss = enemy
                        break
                    end
                end
            end
            if not boss then
                return
            end
        end

        local cname = data.Container and data.Container.Name or ""
        if cname ~= "firstBossRightHandShot" and cname ~= "Model" and cname ~= "secondBossGridShot" then
            return
        end

        -- These attacks are modeled exactly below; never stretch them into
        -- arena-wide slam lines.
        data.SlamBand = false
        data.ProtectorAttack = cname

        local now = os.clock()
        local st = self.ProtState or {}
        self.ProtState = st
        local bossRoot = boss.Root
        local look = flatten(bossRoot.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)

        if cname == "firstBossRightHandShot" then
            if not st.RaysAt or now - st.RaysAt > 6 then
                st.RaysAt = now
                st.Rays = {}
                st.Plan = nil
                st.PlanAt = 0
                st.Look = look
                st.Origin = nil
                st.Cycles = (st.Cycles or 0) + 1
            end
            if not st.Origin then
                local container = data.Container
                local primary = container:IsA("Model") and container.PrimaryPart
                    or container:FindFirstChild("PrimaryPart")
                if primary and primary:IsA("BasePart") then
                    st.Origin = primary.Position
                end
            end
            if part.Name == "hitBox" then
                table.insert(st.Rays, part)
                st.Plan = nil
            end
        elseif cname == "Model" and part.Name == "hitBox" then
            local size = part.Size
            local thin = math.min(size.X, size.Z)
            local rel = flatten(part.Position - bossRoot.Position)
            if thin <= 10.6 and size.Y >= 100 then
                -- Stomp wave piece.
                local r = rel:Dot(look)
                if not st.WedgeAt or now - st.WedgeAt > 3 then
                    st.WedgeAt = now - math.max(0, r) / CONFIG.ProtWedgeSpeed
                    st.WedgeDir = look
                    st.WedgeOrigin = bossRoot.Position
                    st.WedgePart = part
                    st.Wedges = (st.Wedges or 0) + 1
                end
            elseif thin <= 13 and size.Y >= 100 then
                if not st.SquaresAt or now - st.SquaresAt > 3 then
                    st.SquaresAt = now
                end
            end
        end
    end

    ---------------------------------------------------------------------------
    -- Wedge (stomp wave) as a virtual hazard
    ---------------------------------------------------------------------------
    function HazardTracker:GetProtectorWedge()
        local st = self.ProtState
        if not st or not st.WedgeAt or os.clock() - st.WedgeAt > CONFIG.ProtWedgeLife then
            return nil
        end
        return st
    end

    function HazardTracker:IsInProtectorWedge(position, pad)
        local st = self:GetProtectorWedge()
        if not st then
            return false, 0, 0
        end
        local v = flatten(position - st.WedgeOrigin)
        local r = v:Dot(st.WedgeDir)
        local lat = v:Dot(perpOf(st.WedgeDir))
        local half = math.max(r, 0) * 0.5 + 5 + (pad or CONFIG.ProtWedgePad)
        local inside = r > -6 and r < CONFIG.ProtWedgeLength and math.abs(lat) < half
        return inside, r, lat
    end

    local oldOverlaps = HazardTracker.GetBodyOverlaps
    function HazardTracker:GetBodyOverlaps(position, yaw)
        local result = oldOverlaps(self, position, yaw)
        local st = self:GetProtectorWedge()
        if st and st.WedgePart then
            local pad = self.TightPadding and 1.3 or CONFIG.ProtWedgePad
            if self:IsInProtectorWedge(position, pad) then
                for _, part in ipairs(result) do
                    if part == st.WedgePart then
                        return result
                    end
                end
                local copy = table.clone(result)
                table.insert(copy, st.WedgePart)
                return copy
            end
        end
        return result
    end

    ---------------------------------------------------------------------------
    -- Lines + squares: one spot that is safe from the beams (and, if
    -- possible, between the square rings), close to the boss.
    ---------------------------------------------------------------------------
    function DodgeSolver:ComputeProtectorSpot(st, boss)
        local origin = st.Origin
        if not origin then
            local look = st.Look or flatten(boss.Root.CFrame.LookVector).Unit
            origin = boss.Root.Position + look * 25
        end

        local rays = {}
        for _, ray in ipairs(st.Rays or {}) do
            if ray.Parent then
                local d = flatten(ray.Position - origin)
                if d.Magnitude > 1 then
                    table.insert(rays, d.Unit)
                end
            end
        end
        if #rays < 6 then
            return nil
        end

        local angles = {}
        for _, d in ipairs(rays) do
            table.insert(angles, math.atan2(d.Z, d.X))
        end
        table.sort(angles)

        local look = st.Look
        local side = perpOf(look)
        local root = self.CharacterService.Root
        local rootPos = root.Position
        local bossPos = boss.Root.Position
        local speed = math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        local timeLeft = math.max(0.2, st.RaysAt + CONFIG.ProtRayImpact - os.clock())

        local function raySafe(q)
            for _, d in ipairs(rays) do
                if q:Dot(d) > -9.5 and math.abs(q:Dot(perpOf(d))) < CONFIG.ProtRayClear then
                    return false
                end
            end
            return true
        end

        local function squareSafe(q)
            local cheb = math.max(math.abs(q:Dot(look)), math.abs(q:Dot(side)))
            for k = 0, CONFIG.ProtSquareCount - 1 do
                local h = CONFIG.ProtSquareFirst + CONFIG.ProtSquareStep * k
                if math.abs(cheb - h) < CONFIG.ProtSquareHalf + CONFIG.ProtSquarePad then
                    return false
                end
            end
            return true
        end

        local candidates = {}
        local count = #angles
        for i = 1, count do
            local a1 = angles[i]
            local a2 = i < count and angles[i + 1] or (angles[1] + math.pi * 2)
            if a2 - a1 > math.rad(8) then
                local mid = (a1 + a2) * 0.5
                for _, offset in ipairs({ 0, -0.02, 0.02 }) do
                    local dir = Vector3.new(math.cos(mid + offset), 0, math.sin(mid + offset))
                    for dist = CONFIG.ProtRayMinDist, CONFIG.ProtRayMaxDist, 1 do
                        local q = dir * dist
                        if raySafe(q) then
                            local point = Vector3.new(origin.X + q.X, rootPos.Y, origin.Z + q.Z)
                            local travel = flatten(point - rootPos).Magnitude
                            local toBoss = flatten(point - bossPos).Magnitude
                            if toBoss >= 7 then
                                -- Close to the boss matters most: the stomp comes 3.6 s
                                -- later from this spot, and it is easy to dodge up close.
                                local score = travel * 0.8 + toBoss * 1.1
                                if toBoss > 35 then score += 40 end
                                if not squareSafe(q) then score += 60 end
                                if travel > speed * timeLeft + 2 then score += 200 end
                                if toBoss > CONFIG.DamageCastRange - 6 then score += 60 end
                                table.insert(candidates, { Point = point, Score = score, Travel = travel })
                            end
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b)
            return a.Score < b.Score
        end)

        local checked = 0
        for _, c in ipairs(candidates) do
            if checked >= 12 then
                break
            end
            checked += 1
            local delta = flatten(c.Point - rootPos)
            local okGround = self.Geometry:HasGround(c.Point)
            local okStream = not self.Hazards:IsInActiveStream(c.Point)
            local okPath = delta.Magnitude < 1
                or self.Geometry:IsDirectionClear(delta.Unit, math.min(delta.Magnitude, 30), directionToYaw(delta.Unit))
            if okGround and okStream and okPath then
                return c.Point
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- Orbit (used before the stomp and whenever the boss is in reach)
    ---------------------------------------------------------------------------
    function DodgeSolver:GetProtectorOrbit(boss, targetYaw, urgency)
        local root = self.CharacterService.Root
        local toMe = flatten(root.Position - boss.Root.Position)
        local distance = toMe.Magnitude
        if distance < 0.5 then
            return nil
        end
        local out = toMe.Unit
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or out

        -- Rotate away from where the boss is facing.
        local now = os.clock()
        local cross = look.X * out.Z - look.Z * out.X
        local wanted = cross >= 0 and 1 or -1
        if not self.ProtOrbitSign or (now - (self.ProtOrbitFlipAt or 0) > 2.5 and wanted ~= self.ProtOrbitSign and out:Dot(look) > 0.2) then
            if self.ProtOrbitSign ~= wanted then
                self.ProtOrbitFlipAt = now
            end
            self.ProtOrbitSign = wanted
        end

        local radial = math.clamp((distance - CONFIG.ProtOrbitRadius) / 6, -1, 1)
        for attempt = 1, 2 do
            local sign = self.ProtOrbitSign
            local tangent = Vector3.new(-out.Z, 0, out.X) * sign
            local dir = unit(tangent * (urgency or 1) - out * radial * 0.8)
            local yaw = directionToYaw(dir)
            if self.Geometry:IsDirectionClear(dir, 6, yaw)
                and self.Geometry:HasGround(root.Position + dir * 5)
                and self.Hazards:IsTrajectoryClear(root.Position, dir, targetYaw, 5)
            then
                return dir
            end
            if attempt == 1 and now - (self.ProtOrbitFlipAt or 0) > 0.6 then
                self.ProtOrbitSign = -sign
                self.ProtOrbitFlipAt = now
            else
                break
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- v44.10: no constant spinning. Keep beside the boss (outside the line he
    -- faces) and only move when he turns toward us or the stomp is due.
    ---------------------------------------------------------------------------
    CONFIG.ProtCycle = 15.65
    CONFIG.ProtStompLead = 1.2          -- start stepping aside this long before the stomp
    CONFIG.ProtStompTail = 0.6
    CONFIG.ProtStompSafeAngle = 100     -- degrees from the boss's facing that count as safe
    CONFIG.ProtStompGoalAngle = 118
    CONFIG.ProtSideSafeAngle = 65       -- outside the stomp window
    CONFIG.ProtSideGoalAngle = 95
    CONFIG.ProtSideRadius = 18
    CONFIG.ProtSideMin = 11
    CONFIG.ProtAimLockLead = 1.35       -- fallback when the aim snap is not seen
    CONFIG.ProtStompClear = 2.2         -- margin outside the wave edge

    function DodgeSolver:GetPredictedStomp(st, now)
        local base = st.RaysAt
        if not base and st.SquaresAt then
            base = st.SquaresAt - 1.47
        end
        if not base then
            return nil
        end
        local predicted = base + CONFIG.ProtWedgeDelay
        -- Rays missed this cycle: keep counting from the last one.
        while predicted + CONFIG.ProtStompTail < now and now - base < CONFIG.ProtCycle * 4 do
            predicted += CONFIG.ProtCycle
        end
        -- A wave already fired for this prediction.
        if st.WedgeAt and math.abs(st.WedgeAt - predicted) < 2 and now > st.WedgeAt + 0.2 then
            return nil
        end
        return predicted
    end

    -- Returns a move direction, Vector3.zero when already safe (hold), or nil.
    function DodgeSolver:GetProtectorSideStep(boss, targetYaw, safeAngle, goalAngle)
        local root = self.CharacterService.Root
        local toMe = flatten(root.Position - boss.Root.Position)
        local distance = toMe.Magnitude
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)
        local out = distance > 0.5 and toMe.Unit or -look
        local theta = math.deg(math.acos(math.clamp(out:Dot(look), -1, 1)))
        self.ProtFacingAngle = theta

        if theta >= safeAngle and distance <= CONFIG.ProtOrbitMax then
            return Vector3.zero
        end

        local cross = look.X * out.Z - look.Z * out.X
        local preferred = cross >= 0 and 1 or -1
        local radius = math.clamp(distance, CONFIG.ProtSideMin, CONFIG.ProtSideRadius)

        for attempt = 1, 2 do
            local sign = attempt == 1 and preferred or -preferred
            local goal = boss.Root.Position + rotateXZ(look, sign * goalAngle) * radius
            goal = Vector3.new(goal.X, root.Position.Y, goal.Z)
            local delta = flatten(goal - root.Position)
            if delta.Magnitude < 1 then
                return Vector3.zero
            end
            local dir = delta.Unit
            local probe = math.min(delta.Magnitude, 8)
            local ahead = root.Position + dir * math.min(delta.Magnitude, 4)
            if self.Geometry:IsDirectionClear(dir, probe, directionToYaw(dir))
                and self.Geometry:HasGround(ahead)
                and not self.Hazards:IsInActiveStream(ahead)
                and self.Hazards:GetOverlapCountAt(ahead, targetYaw) == 0
            then
                return dir
            end
        end
        return nil
    end

    ---------------------------------------------------------------------------
    -- Planner
    ---------------------------------------------------------------------------
    function DodgeSolver:ProtectorPlan(boss, targetYaw)
        local st = self.Hazards.ProtState
        local root = self.CharacterService.Root
        local now = os.clock()
        if not st then
            return nil
        end

        -- Track the boss's facing to catch the aim snap before the stomp.
        local look = flatten(boss.Root.CFrame.LookVector)
        look = look.Magnitude > 0 and look.Unit or Vector3.new(1, 0, 0)
        local snapped = false
        if self.ProtLastLook and now - (self.ProtLastLookAt or 0) < 0.35 then
            local turn = math.deg(math.acos(math.clamp(look:Dot(self.ProtLastLook), -1, 1)))
            snapped = turn > 6
        end
        self.ProtLastLook = look
        self.ProtLastLookAt = now

        -- 1) Stomp wave on screen and we are in its cone: get out sideways
        --    (or behind the boss when that is shorter).
        local inside, r, lat = self.Hazards:IsInProtectorWedge(root.Position, 1.6)
        if inside then
            local d = st.WedgeDir
            local p = perpOf(d)
            local sideSign = lat >= 0 and 1 or -1
            local options = {
                { Dir = unit(p * sideSign - d * 0.35), Need = (math.max(r, 0) * 0.5 + 6.6 - math.abs(lat)) },
                { Dir = unit(-d + p * sideSign * 0.3), Need = r + 7.6 },
                { Dir = unit(p * sideSign + d * 0.2), Need = (math.max(r, 0) * 0.5 + 6.6 - math.abs(lat)) * 1.1 },
            }
            table.sort(options, function(a, b) return a.Need < b.Need end)
            for _, o in ipairs(options) do
                local yaw = directionToYaw(o.Dir)
                if self.Geometry:IsDirectionClear(o.Dir, math.clamp(o.Need, 3, 12), yaw)
                    and self.Geometry:HasGround(root.Position + o.Dir * 4)
                then
                    return o.Dir, "stomp-exit"
                end
            end
            return unit(p * sideSign), "stomp-exit"
        end

        -- 2) Lines + squares window: go to the planned spot and stand still.
        if st.RaysAt and now - st.RaysAt <= CONFIG.ProtHoldUntil then
            if not st.Plan and now - (st.PlanAt or 0) > 0.12 then
                st.PlanAt = now
                st.Plan = self:ComputeProtectorSpot(st, boss)
                st.PlanTries = (st.PlanTries or 0) + 1
            end
            if st.Plan then
                local delta = flatten(st.Plan - root.Position)
                self.SelectedAuraPoint = st.Plan
                if delta.Magnitude <= 0.9 then
                    return Vector3.zero, "lines-hold"
                end
                return delta.Unit * math.clamp(delta.Magnitude / 2.5, 0.4, 1), "lines-spot"
            end
            return nil
        end

        -- 3) Stomp wave is due. Measured live: about 1.4 s before the wave the
        --    boss snaps to face the player and that aim is locked. Right after
        --    the snap, walk straight out sideways of the locked line.
        local predicted = self:GetPredictedStomp(st, now)
        if predicted then
            local untilStomp = predicted - now
            if snapped and untilStomp < 2.4 and untilStomp > -0.4 then
                st.AimFor = predicted
                st.AimLook = look
            end
            local locked = st.AimFor == predicted or untilStomp <= CONFIG.ProtAimLockLead
            if locked and untilStomp <= 2.4 and untilStomp >= -CONFIG.ProtStompTail then
                local d = (st.AimFor == predicted and st.AimLook) or look
                local v = flatten(root.Position - boss.Root.Position)
                local r = v:Dot(d)
                local lat = v:Dot(perpOf(d))
                local need = math.max(r, 0) * 0.5 + 5 + CONFIG.ProtStompClear
                if r < -7 or math.abs(lat) >= need then
                    return Vector3.zero, "stomp-safe"
                end
                local sign = lat >= 0 and 1 or -1
                if math.abs(lat) < 1.5 and self.ProtStompSide then
                    sign = self.ProtStompSide
                end
                for attempt = 1, 2 do
                    local s = attempt == 1 and sign or -sign
                    local dir = unit(perpOf(d) * s - d * (r > 30 and 0.25 or 0))
                    if self.Geometry:IsDirectionClear(dir, 8, directionToYaw(dir))
                        and self.Geometry:HasGround(root.Position + dir * 5)
                    then
                        self.ProtStompSide = s
                        return dir, "stomp-sidestep"
                    end
                end
                return unit(perpOf(d) * sign), "stomp-sidestep"
            end
        end

        return nil
    end

    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if isProtector(enemy) and not self.ForceRouteMovement and self.CharacterService:IsAlive() then
            self.CurrentSolveEnemy = enemy
            local ok, dir, reason = pcall(self.ProtectorPlan, self, enemy, targetYaw)
            if ok and dir then
                local now = os.clock()
                self.LastSolve = now
                self.LastDodgeReason = reason
                self.IsDodging = true
                self.CachedDirection, self.CachedYaw = dir, targetYaw
                self.CachedEmergency, self.CachedDodging = false, true
                self.CommittedDodgeDirection = Vector3.zero
                self.DodgeCommitUntil = 0
                if dir.Magnitude > 0 then
                    self.LastMovement = dir
                end
                return dir, targetYaw, false, true
            elseif not ok then
                self.ProtPlanError = tostring(dir)
            end
        end
        return oldSolve(self, routeDirection, enemy, targetYaw)
    end

    -- Close to the Protector: stay beside him and attack; only move when he
    -- turns to face us.
    local oldPreferred = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        local result = oldPreferred(self, routeDirection, enemy, targetYaw)
        if not isProtector(enemy) or self.ForceRouteMovement or self.TargetBlocked then
            return result
        end
        local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
        if distance <= CONFIG.ProtOrbitMax and distance >= 3 then
            self.AttackHolding = false
            self.TravelMode = false
            local dir = self:GetProtectorSideStep(enemy, targetYaw, CONFIG.ProtSideSafeAngle, CONFIG.ProtSideGoalAngle)
            if dir then
                self.AttackHolding = dir.Magnitude <= 0
                return dir
            end
        end
        return result
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.10"
        return self
    end
end

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

-- v44.12: Enchanted Forest - Ancient Enchanted Tree (measured live):
--   * the tree sits behind a water moat (water from ~55 to ~90 studs); the
--     closest ground ring is ~90-100 studs from its center, so the old code
--     never got in cast range and dealt 0 damage
--   * Enchanted Sweeper: 2 diameter lasers (450 long, 1.5 thick) through the
--     tree, perpendicular, still for ~0.7 s, then rotating ~10 deg/s; each
--     touch ticks ~90M every 0.1 s
do
    CONFIG.TreeRingMin = 80
    CONFIG.TreeRingMax = 150
    CONFIG.TreeRingStep = 3
    CONFIG.TreeRingAngles = 36
    CONFIG.TreeStandExtra = 4
    CONFIG.TreeRadiusCap = 45
    CONFIG.TreeSweeperSync = 1.6          -- how hard to pull toward the middle of the gap
    CONFIG.TreeSweeperClear = 2.6         -- studs from a laser line counted as touching
    CONFIG.TreeSweeperRange = 240

    local function isTree(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient enchanted tree"
            and enemy.Root and enemy.Root.Parent
    end

    local TWO_PI = math.pi * 2
    local function wrap(a)
        a = a % TWO_PI
        if a < 0 then a += TWO_PI end
        return a
    end

    ---------------------------------------------------------------------------
    -- Ground ring around the moat
    ---------------------------------------------------------------------------
    function UIWController:ScanTreeRing(tree)
        local center = tree.Root.Position
        local root = self.Character.Root
        local floorY = root.Position.Y - 3
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = false
        local ignore = { self.Character.Character, tree.Model }
        for _, name in ipairs({ "UIW_HitboxESP", "UIW_PathESP", "UIW_TacticalDisplay", "UIW_AvoidZones", "enemies" }) do
            local f = Workspace:FindFirstChild(name)
            if f then table.insert(ignore, f) end
        end
        local ring = {}
        for i = 0, CONFIG.TreeRingAngles - 1 do
            local angle = i / CONFIG.TreeRingAngles * TWO_PI
            local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local found = nil
            for r = CONFIG.TreeRingMin, CONFIG.TreeRingMax, CONFIG.TreeRingStep do
                local p = center + dir * r
                local localIgnore = table.clone(ignore)
                local hit
                for _ = 1, 4 do
                    params.FilterDescendantsInstances = localIgnore
                    hit = Workspace:Raycast(Vector3.new(p.X, floorY + 40, p.Z), Vector3.new(0, -90, 0), params)
                    if hit and hit.Instance ~= Workspace.Terrain
                        and (hit.Instance.Name == "hitBox" or hit.Instance.Name == "precast"
                            or hit.Instance.Transparency >= 0.9 or not hit.Instance.CanCollide)
                    then
                        table.insert(localIgnore, hit.Instance)
                    else
                        break
                    end
                end
                if hit and hit.Material ~= Enum.Material.Water and math.abs(hit.Position.Y - floorY) <= 8 then
                    found = r
                    break
                end
            end
            ring[i + 1] = { Angle = angle, R = found }
        end
        self.TreeRing = { Model = tree.Model, Center = center, Ring = ring, At = os.clock() }
        return self.TreeRing
    end

    function UIWController:GetTreeStandPoint(tree)
        local info = self.TreeRing
        local root = self.Character.Root
        local closeEnough = flatten(root.Position - tree.Root.Position).Magnitude <= 170
        if not info or info.Model ~= tree.Model or (os.clock() - info.At > 60 and closeEnough) then
            if closeEnough or not info or info.Model ~= tree.Model then
                local previous = info
                info = self:ScanTreeRing(tree)
                local valid = 0
                for _, slot in ipairs(info.Ring) do
                    if slot.R then valid += 1 end
                end
                if valid < 3 and previous and previous.Model == tree.Model then
                    -- Scanned from the wrong height (e.g. right after respawn): keep the old ring.
                    previous.At = os.clock()
                    self.TreeRing = previous
                    info = previous
                elseif valid < 3 then
                    self.TreeRing = nil
                    return nil
                end
            end
        end
        local rel = flatten(root.Position - info.Center)
        local phi = wrap(math.atan2(rel.Z, rel.X))
        local best, bestCost = nil, math.huge
        for _, slot in ipairs(info.Ring) do
            if slot.R then
                local diff = math.abs(wrap(slot.Angle - phi + math.pi) - math.pi)
                local cost = diff * rel.Magnitude + slot.R * 0.3
                if cost < bestCost then
                    best, bestCost = slot, cost
                end
            end
        end
        if not best then
            return nil
        end
        local r = best.R + CONFIG.TreeStandExtra
        -- Stay on our own bearing when the ring there is known and close.
        local angle = best.Angle
        local p = info.Center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * r
        return Vector3.new(p.X, root.Position.Y, p.Z), r
    end

    function CombatController:GetTreeRadius(enemy)
        local now = os.clock()
        if self.TreeRadiusModel == enemy.Model and now - (self.TreeRadiusAt or 0) < 10 then
            return self.TreeRadius
        end
        local radius = 30
        local ok, size = pcall(enemy.Model.GetExtentsSize, enemy.Model)
        if ok and size then
            radius = math.min(size.X, size.Z) * 0.5
        end
        self.TreeRadius = math.min(radius, CONFIG.TreeRadiusCap)
        self.TreeRadiusModel = enemy.Model
        self.TreeRadiusAt = now
        return self.TreeRadius
    end

    -- Casting reaches the tree's body, not its center.
    local oldUpdate = CombatController.Update
    function CombatController:Update(enemy)
        if isTree(enemy) then
            local base = CONFIG.DamageCastRange
            local width = CONFIG.CastHitboxWidth
            local radius = self:GetTreeRadius(enemy)
            CONFIG.DamageCastRange = base + radius
            -- The tree is ~80 studs wide: aiming a few degrees off still hits.
            CONFIG.CastHitboxWidth = width + radius * 2.5
            local ok, result = pcall(oldUpdate, self, enemy)
            CONFIG.DamageCastRange = base
            CONFIG.CastHitboxWidth = width
            if not ok then error(result, 0) end
            return result
        end
        return oldUpdate(self, enemy)
    end

    local oldGoal = UIWController.GetGoal
    function UIWController:GetGoal()
        local enemy = self.CurrentEnemy
        if isTree(enemy) and self.Character:IsAlive() then
            local mechanic = self:GetPriorityMechanicGoal()
            if mechanic then
                return mechanic
            end
            local ok, point = pcall(self.GetTreeStandPoint, self, enemy)
            if ok and point then
                self.TreeStandGoal = point
                return point
            end
        end
        self.TreeStandGoal = nil
        return oldGoal(self)
    end

    ---------------------------------------------------------------------------
    -- Spinning lasers
    ---------------------------------------------------------------------------
    function HazardTracker:TrackTreeLaser(model)
        if not model or model.Name ~= "secondBossSpinningLaserHitbox" then
            return
        end
        self.TreeLasers = self.TreeLasers or {}
        if self.TreeLasers[model] then
            return
        end
        task.defer(function()
            local part = model:FindFirstChild("hitBox") or model:FindFirstChildWhichIsA("BasePart")
            if part then
                self.TreeLasers[model] = { Part = part, Born = os.clock() }
            end
        end)
    end

    function HazardTracker:GetTreeLasers()
        local list = {}
        local now = os.clock()
        for model, info in pairs(self.TreeLasers or {}) do
            local part = info.Part
            if not model.Parent or not part.Parent then
                self.TreeLasers[model] = nil
            else
                local size = part.Size
                local axis = size.X >= size.Z and part.CFrame.RightVector or part.CFrame.LookVector
                axis = flatten(axis)
                if axis.Magnitude > 0 then
                    axis = axis.Unit
                    local angle = math.atan2(axis.Z, axis.X)
                    if info.LastAngle and now - info.LastAt >= 0.08 then
                        local d = (angle - info.LastAngle) % math.pi
                        if d > math.pi / 2 then d -= math.pi end
                        local w = d / (now - info.LastAt)
                        info.Omega = info.Omega and (info.Omega * 0.6 + w * 0.4) or w
                        if math.abs(w) >= math.rad(0.8) then
                            info.HadMotion = true
                            info.LastMotionAt = now
                        end
                        info.LastAngle, info.LastAt = angle, now
                    elseif not info.LastAngle then
                        info.LastAngle, info.LastAt = angle, now
                    end
                    -- These invisible models can remain in Workspace after the
                    -- rotating damage has stopped.  Retire the tracker after a
                    -- measured spin becomes stationary instead of dodging the
                    -- stale hitbox until Roblox eventually destroys the model.
                    local retired = info.HadMotion
                        and now - (info.LastMotionAt or now) >= 0.85
                    if retired then
                        info.Retired = true
                        self.TreeLasers[model] = nil
                        local full = self.FullHazards or self.Hazards
                        full[part] = nil
                        if self.NearHazards then self.NearHazards[part] = nil end
                    elseif not info.Retired then
                        table.insert(list, {
                            Part = part,
                            Center = part.Position,
                            Axis = axis,
                            Angle = angle,
                            Omega = info.Omega or 0,
                            HalfLength = math.max(size.X, size.Z) * 0.5,
                        })
                    end
                end
            end
        end
        return list
    end

    function HazardTracker:GetTreeLaserHit(position, clearance)
        for _, laser in ipairs(self.TreeLaserCache or {}) do
            if laser.Part.Parent then
                local v = flatten(position - laser.Center)
                local along = math.abs(v:Dot(laser.Axis))
                local across = math.abs(v.X * laser.Axis.Z - v.Z * laser.Axis.X)
                if along <= laser.HalfLength and across <= clearance then
                    return laser.Part
                end
            end
        end
        return nil
    end

    local oldRefreshLasers = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local before = self.LastCacheTime
        oldRefreshLasers(self, force)
        if self.LastCacheTime ~= before and self.TreeLasers and next(self.TreeLasers) then
            self.TreeLaserCache = self:GetTreeLasers()
        elseif not self.TreeLasers or not next(self.TreeLasers) then
            self.TreeLaserCache = nil
        end
    end

    local oldOverlapsLaser = HazardTracker.GetBodyOverlaps
    function HazardTracker:GetBodyOverlaps(position, yaw)
        local result = oldOverlapsLaser(self, position, yaw)
        if self.TreeLaserCache and #self.TreeLaserCache > 0 then
            local clearance = self.TightPadding and 1.8 or CONFIG.TreeSweeperClear
            local part = self:GetTreeLaserHit(position, clearance)
            if part then
                for _, p in ipairs(result) do
                    if p == part then return result end
                end
                local copy = table.clone(result)
                table.insert(copy, part)
                return copy
            end
        end
        return result
    end

    -- Ride along with the rotating cross in the middle of a gap, choosing a
    -- velocity that is also clear of the circles / lines that come with it.
    local function laserClearance(lasers, omega, pivot, position, dt)
        local rel = flatten(position - pivot)
        local R = rel.Magnitude
        if R < 1 then
            return 0
        end
        local phi = math.atan2(rel.Z, rel.X)
        local best = math.huge
        for _, laser in ipairs(lasers) do
            local theta = laser.Angle + omega * dt
            local d = math.abs(((phi - theta) % math.pi))
            d = math.min(d, math.pi - d)
            best = math.min(best, math.sin(d) * R)
        end
        return best
    end

    function DodgeSolver:GetTreeSweeperMove(boss, targetYaw)
        self.TreeSweeperUrgent = false
        local lasers = self.Hazards.TreeLaserCache
        if not lasers or #lasers == 0 then
            return nil
        end
        local root = self.CharacterService.Root
        local origin = root.Position
        local pivot = lasers[1].Center
        local rel = flatten(origin - pivot)
        local R = rel.Magnitude
        if R < 1 or R > CONFIG.TreeSweeperRange then
            return nil
        end
        local phi = wrap(math.atan2(rel.Z, rel.X))

        local angles, omega = {}, 0
        for _, laser in ipairs(lasers) do
            table.insert(angles, wrap(laser.Angle))
            table.insert(angles, wrap(laser.Angle + math.pi))
            omega += laser.Omega
        end
        omega /= #lasers
        table.sort(angles)

        local lower, upper = angles[#angles] - TWO_PI, angles[1]
        for i = 1, #angles do
            local a = angles[i]
            local b = i < #angles and angles[i + 1] or angles[1] + TWO_PI
            local p = phi
            if p < a then p += TWO_PI end
            if p >= a and p < b then
                lower, upper = a, b
                phi = p
                break
            end
        end
        local mid = (lower + upper) * 0.5

        local speed = math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        local tangent = Vector3.new(-math.sin(phi), 0, math.cos(phi))
        local out = rel.Unit

        local tangential = (omega + math.clamp((mid - phi) * CONFIG.TreeSweeperSync, -1.2, 1.2)) * R
        local radial = 0
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - pivot).Magnitude or R
        if R > standR + 6 then
            radial = -speed * 0.78
            tangential = math.clamp(tangential, -speed * 0.6, speed * 0.6)
        else
            radial = math.clamp((standR - R) * 1.2, -speed * 0.5, speed * 0.5)
        end
        tangential = math.clamp(tangential, -speed, speed)
        local base = tangent * tangential + out * radial
        local baseSpeed = math.min(base.Magnitude, speed)
        local baseDir = base.Magnitude > 0.3 and base.Unit or tangent

        local best, bestScore = nil, -math.huge
        local nowClear = laserClearance(lasers, omega, pivot, origin, 0)
        for _, offset in ipairs({ 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150, 180 }) do
            for _, scale in ipairs({ 1, 0.55 }) do
                local dir = unit(rotateXZ(baseDir, offset))
                local v = dir * math.max(baseSpeed, 6) * scale
                if offset ~= 0 then
                    v = dir * speed * scale
                end
                local p1 = origin + v * 0.35
                local p2 = origin + v * 0.7
                local r2 = flatten(p2 - pivot).Magnitude
                if r2 >= standR - 5 then
                    local clear = math.min(
                        laserClearance(lasers, omega, pivot, p1, 0.35),
                        laserClearance(lasers, omega, pivot, p2, 0.7)
                    )
                    local laserOk = clear >= CONFIG.TreeSweeperClear + 1.2
                    local reach = math.min(v.Magnitude * 0.7, 9)
                    local hazardOk = reach < 1 or self.Hazards:IsTrajectoryClear(origin, dir, targetYaw, reach)
                    local endFree = self.Hazards:GetOverlapCountAt(p2, targetYaw) == 0
                    local score = (laserOk and 1000 or clear * 50)
                        + (hazardOk and 200 or 0)
                        + (endFree and 300 or 0)
                        - math.abs(offset) * 0.6
                        - (1 - scale) * 15
                        + math.min(clear, 20)
                        - math.abs(r2 - standR) * 1.5
                    if score > bestScore
                        and self.Geometry:IsDirectionClear(dir, math.max(reach, 3), directionToYaw(dir))
                    then
                        best, bestScore = v, score
                    end
                end
            end
        end

        self.TreeSweeperUrgent = nowClear < CONFIG.TreeSweeperClear + 4
        if not best then
            return nil
        end
        return best / speed
    end

    local oldSolveTree = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if isTree(enemy) and not self.ForceRouteMovement and self.CharacterService:IsAlive() then
            local ok, dir = pcall(self.GetTreeSweeperMove, self, enemy, targetYaw)
            if ok and dir then
                local unitDir = dir.Magnitude > 0 and dir.Unit or Vector3.zero
                do
                    local now = os.clock()
                    self.CurrentSolveEnemy = enemy
                    self.LastSolve = now
                    self.LastDodgeReason = "tree-sweeper"
                    self.IsDodging = true
                    self.CachedDirection, self.CachedYaw = dir, targetYaw
                    self.CachedEmergency, self.CachedDodging = false, true
                    self.CommittedDodgeDirection = Vector3.zero
                    self.DodgeCommitUntil = 0
                    if dir.Magnitude > 0 then self.LastMovement = unitDir end
                    return dir, targetYaw, false, true
                end
            elseif not ok then
                self.TreePlanError = tostring(dir)
            end
        end
        return oldSolveTree(self, routeDirection, enemy, targetYaw)
    end

    -- Dodges around the tree: slide along the shore (stay in range) instead
    -- of running away from it.
    local oldAttackDodge = DodgeSolver.FindBossAttackDodge
    function DodgeSolver:FindBossAttackDodge(enemy, targetYaw)
        if not isTree(enemy) then
            return oldAttackDodge(self, enemy, targetYaw)
        end
        local root = self.CharacterService.Root
        local origin = root.Position
        local rel = flatten(origin - enemy.Root.Position)
        if rel.Magnitude < 1 then
            return nil
        end
        local out = rel.Unit
        local tangent = Vector3.new(-out.Z, 0, out.X)
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - enemy.Root.Position).Magnitude or rel.Magnitude
        local reach = CONFIG.DamageCastRange + CONFIG.TreeRadiusCap - 2
        local best, bestScore = nil, -math.huge
        for _, side in ipairs({ 1, -1 }) do
            for _, inward in ipairs({ 0.35, 0, -0.25 }) do
                local dir = unit(tangent * side - out * inward)
                local point = origin + dir * CONFIG.DodgeDistance
                local pr = flatten(point - enemy.Root.Position).Magnitude
                local R = rel.Magnitude
                if pr <= math.max(reach, R - 2) and pr >= standR - 6 and self.Geometry:HasGround(point) then
                    local safety = self:ScoreCandidate(dir, dir, targetYaw)
                    if safety then
                        local score = safety - math.abs(pr - standR) * 20
                        if self.LastMovement.Magnitude > 0 then
                            score += dir:Dot(self.LastMovement) * 30
                        end
                        if score > bestScore then
                            best, bestScore = dir, score
                        end
                    end
                end
            end
        end
        return best
    end

    -- Near the tree: go to the stand ring and hold there while casting.
    local oldPreferredTree = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        if isTree(enemy) and not self.ForceRouteMovement then
            local stand = self.Owner and self.Owner.TreeStandGoal
            if stand then
                local delta = flatten(stand - self.CharacterService.Root.Position)
                self.TravelMode = delta.Magnitude > 40
                self.AttackHolding = delta.Magnitude <= 3
                if delta.Magnitude <= 3 then
                    return Vector3.zero
                end
                local route = unit(flatten(routeDirection))
                if route.Magnitude > 0 then
                    return route
                end
                return delta.Unit
            end
        end
        return oldPreferredTree(self, routeDirection, enemy, targetYaw)
    end

    local oldNewTree = UIWController.new
    function UIWController.new()
        local self = oldNewTree()
        self.Version = "44.12"
        local hazards = self.Hazards
        for _, child in ipairs(Workspace:GetChildren()) do
            hazards:TrackTreeLaser(child)
        end
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if child.Name == "secondBossSpinningLaserHitbox" then
                hazards:TrackTreeLaser(child)
            end
        end))
        return self
    end
end

-- v44.13: use Inner Rage / Inner Focus (damage + speed buff) to escape fast
-- when a dangerous dodge is underway; the buff also boosts the next hits.
do
    CONFIG.EscapeBuff = true
    CONFIG.EscapeBuffCooldown = 1.5

    local URGENT = {
        hitbox = true, nuke = true, ["large-attack"] = true,
        ["stomp-sidestep"] = true, ["stomp-exit"] = true,
        melee = true, fallback = true, ["least-risk"] = true, orientation = true,
    }

    function CombatController:TryEscapeBuff()
        if not CONFIG.EscapeBuff or not self.CharacterService:IsAlive() or not self:CanSendInput() then
            return false
        end
        local now = os.clock()
        if now - (self.EscapeBuffAt or 0) < CONFIG.EscapeBuffCooldown then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = self:GetTool(slot)
            if tool and self:IsBuffTool(tool) and self:IsReady(slot) then
                self.EscapeBuffAt = now
                self.EscapeBuffs = (self.EscapeBuffs or 0) + 1
                self:Press(slot)
                return true
            end
        end
        return false
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled or not self.AutoCombat then
            return
        end
        local dodger = self.Dodger
        if dodger.IsDodging
            and (URGENT[dodger.LastDodgeReason or ""] or dodger.TreeSweeperUrgent)
        then
            pcall(self.Combat.TryEscapeBuff, self.Combat)
        end
    end


    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.13"
        return self
    end
end

-- v44.14: always-on attack census (read with getgenv().UIW_EF). For every new
-- attack model: name, nearest enemy, size, warning timing and lifetime.
do
    CONFIG.AttackCensus = true
    CONFIG.AttackCensusExamples = 3

    local function topModel(inst)
        local p = inst
        while p.Parent and p.Parent ~= Workspace do
            p = p.Parent
        end
        return p
    end

    local function describe(cont)
        local pre, hb
        for _, d in ipairs(cont:GetDescendants()) do
            if d:IsA("BasePart") then
                if d.Name == "precast" and not pre then pre = d end
                if d.Name == "hitBox" and not hb then hb = d end
            end
        end
        local s = ""
        if pre then
            s = s .. string.format("pT%.2f S%.0fx%.0f", pre.Transparency, pre.Size.X, pre.Size.Z)
        end
        if hb then
            s = s .. string.format(" hT%.2f%s S%.0fx%.0fx%.0f", hb.Transparency,
                hb:FindFirstChildOfClass("TouchTransmitter") and " TT" or "", hb.Size.X, hb.Size.Y, hb.Size.Z)
        end
        return s
    end

    ---------------------------------------------------------------------------
    -- Big bosses: cast range reaches their body, not their center, so casts
    -- still land while standing in a safe bubble / behind a wall.
    ---------------------------------------------------------------------------
    local BIG_BOSS_REACH = {
        ["crystal golem"] = 18,
        ["enchanted forest dragon"] = 24,
        ["sea king"] = 12,
        ["ancient temple protector"] = 10,
    }

    local reachCache = setmetatable({}, { __mode = "k" })
    local function bossReach(enemy)
        local cap = enemy and enemy.Model and BIG_BOSS_REACH[normalizeEnemyName(enemy.Model.Name)]
        if not cap then
            return 0
        end
        local cached = reachCache[enemy.Model]
        if cached and os.clock() - cached.At < 10 then
            return cached.Reach
        end
        local reach = 0
        local ok, size = pcall(enemy.Model.GetExtentsSize, enemy.Model)
        if ok and size then
            reach = math.min(math.min(size.X, size.Z) * 0.5 * 0.7, cap)
        end
        reachCache[enemy.Model] = { Reach = reach, At = os.clock() }
        return reach
    end

    local oldBossUpdate = CombatController.Update
    function CombatController:Update(enemy)
        local reach = bossReach(enemy)
        if reach <= 0 then
            return oldBossUpdate(self, enemy)
        end
        local base = CONFIG.DamageCastRange
        CONFIG.DamageCastRange = base + reach
        local ok, result = pcall(oldBossUpdate, self, enemy)
        CONFIG.DamageCastRange = base
        if not ok then error(result, 0) end
        return result
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.14"
        if not CONFIG.AttackCensus then
            return self
        end
        local log = { Started = os.clock(), ByName = {}, Count = 0, Dungeon = "?" }
        getgenv().UIW_EF = log
        local seen = setmetatable({}, { __mode = "k" })
        local controller = self

        self.Maid:Give(Workspace.DescendantAdded:Connect(function(inst)
            if not inst:IsA("BasePart") or (inst.Name ~= "hitBox" and inst.Name ~= "precast") then
                return
            end
            local cont = topModel(inst)
            if seen[cont] then
                return
            end
            seen[cont] = true
            log.Count += 1
            task.defer(function()
                if controller.Destroyed then return end
                local root = controller.Character.Root
                local pos = inst.Position
                local nearest, nearestDistance = "?", math.huge
                for _, e in ipairs(controller.Dungeon:GetAliveEnemies()) do
                    if e.Root and e.Root.Parent then
                        local d = (e.Root.Position - pos).Magnitude
                        if d < nearestDistance then
                            nearest, nearestDistance = e.Model.Name, d
                        end
                    end
                end
                local name = cont.Name
                local agg = log.ByName[name]
                if not agg then
                    agg = { n = 0, enemies = {}, examples = {} }
                    log.ByName[name] = agg
                end
                agg.n += 1
                agg.enemies[nearest] = (agg.enemies[nearest] or 0) + 1
                if #agg.examples >= CONFIG.AttackCensusExamples then
                    return
                end
                local ex = {
                    At = math.floor((os.clock() - log.Started) * 10) / 10,
                    En = nearest,
                    Ed = math.floor(nearestDistance),
                    Me = root and math.floor((root.Position - pos).Magnitude) or -1,
                    Seq = {},
                }
                table.insert(agg.examples, ex)
                local born = os.clock()
                local last
                for _, t in ipairs({ 0, 0.3, 0.6, 0.9, 1.2, 1.6, 2.2, 3, 4.5, 7, 10 }) do
                    local w = born + t - os.clock()
                    if w > 0 then task.wait(w) end
                    if not cont.Parent then
                        ex.Life = math.floor((os.clock() - born) * 10) / 10
                        break
                    end
                    local s = describe(cont)
                    if s ~= last then
                        table.insert(ex.Seq, t .. ":" .. s)
                        last = s
                    end
                end
                if cont.Parent and not ex.Life then
                    ex.Life = ">10"
                end
            end)
        end))
        -- Keep the census across teleports (one small file per dungeon).
        local lastSave = 0
        local forceSave = false
        local watched = nil
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            local humanoid = controller.Character.Humanoid
            if humanoid and humanoid ~= watched then
                watched = humanoid
                humanoid.Died:Connect(function()
                    task.delay(0.3, function()
                        forceSave = true
                    end)
                end)
            end
        end))
        self.Maid:Give(RunService.Heartbeat:Connect(function()
            local now = os.clock()
            if (now - lastSave < 30 and not forceSave) or log.Count == 0 then
                return
            end
            forceSave = false
            lastSave = now
            local key = controller:GetDungeonKey() or "unknown"
            local path = "UIW/census_" .. string.gsub(key, "[^%w]", "_") .. ".json"
            local saved = SafeFile.ReadJson(path) or {}
            for name, agg in pairs(log.ByName) do
                local entry = saved[name] or { n = 0, enemies = {}, examples = {} }
                entry.n = math.max(entry.n or 0, agg.n)
                entry.enemies = agg.enemies
                if #agg.examples > 0 then
                    entry.examples = agg.examples
                end
                saved[name] = entry
            end
            local t = getgenv().UIW_Telemetry
            if t then
                local hits = {}
                for i = math.max(1, #t.Hits - 25), #t.Hits do
                    local h = t.Hits[i]
                    local th = {}
                    for _, x in ipairs(h.Threats or {}) do
                        table.insert(th, x.Name .. "@" .. x.Distance)
                    end
                    table.insert(hits, string.format("%.1f %dM hp%d %s | %s", h.T, math.floor(h.Lost / 1e6), h.HealthPct, h.Reason, table.concat(th, ",")))
                end
                saved["__hits_" .. (t.RunId or "run")] = hits
            end
            SafeFile.WriteJson(path, saved, true)
        end))
        return self
    end
end

-- v44.15: never dodge our own spells. Live finding: casting E spawns a
-- top-level "lightningBurstHitbox" (55x21x93) in front of us that lives >10 s;
-- it was tracked as an enemy attack, so the script ran away from its own hits.
do
    local OWN_ABILITY_NAMES = {
        lightningbursthitbox = true,
    }
    getgenv().UIW_OwnAbilities = OWN_ABILITY_NAMES

    local function topModel(inst)
        local p = inst
        while p.Parent and p.Parent ~= Workspace do
            p = p.Parent
        end
        return p
    end

    local oldHazardPart = HazardTracker.IsHazardPart
    function HazardTracker:IsHazardPart(part)
        local top = topModel(part)
        if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
            return false
        end
        return oldHazardPart(self, part)
    end

    local oldPress = CombatController.Press
    function CombatController:Press(slot)
        local tool = self:GetTool(slot)
        if tool and not self:IsBuffTool(tool) then
            self.LastDamagePressAt = os.clock()
            local root = self.CharacterService.Root
            if root then
                self.LastDamagePressCF = root.CFrame
            end
        end
        return oldPress(self, slot)
    end

    -- Learn other self-spawned spell hitboxes: a new top-level model with a
    -- hitBox that appears right after our damage cast, in front of us.
    function UIWController:LearnOwnAbility(model)
        local combat = self.Combat
        local pressedAt = combat.LastDamagePressAt
        local cf = combat.LastDamagePressCF
        if not pressedAt or not cf then
            return
        end
        local dt = os.clock() - pressedAt
        if dt < 0.15 or dt > 1.3 then
            return
        end
        local hit = model:FindFirstChild("hitBox")
        if not hit or not hit:IsA("BasePart") then
            return
        end
        local rel = cf:PointToObjectSpace(hit.Position)
        if -rel.Z < -5 or -rel.Z > 80 or math.abs(rel.X) > 14 then
            return
        end
        local name = string.lower(model.Name)
        self.OwnAbilityVotes = self.OwnAbilityVotes or {}
        local votes = (self.OwnAbilityVotes[name] or 0) + 1
        self.OwnAbilityVotes[name] = votes
        if votes >= 3 and not OWN_ABILITY_NAMES[name] and not (self.OwnAbilityVeto or {})[name] then
            OWN_ABILITY_NAMES[name] = true
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.16"
        local controller = self
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if OWN_ABILITY_NAMES[string.lower(child.Name)] then
                return
            end
            if not child:IsA("Model") then
                return
            end
            local pressedAt = controller.Combat.LastDamagePressAt
            if not pressedAt or os.clock() - pressedAt > 1.3 then
                -- Seen without a cast of ours: an enemy attack, never ours.
                controller.OwnAbilityVeto = controller.OwnAbilityVeto or {}
                controller.OwnAbilityVeto[string.lower(child.Name)] = true
                return
            end
            do
                task.delay(0.05, function()
                    if child.Parent then
                        pcall(controller.LearnOwnAbility, controller, child)
                    end
                end)
            end
        end))
        -- Drop anything already tracked from our own spells.
        local hazards = self.Hazards
        local full = hazards.FullHazards or hazards.Hazards
        for part, data in pairs(full) do
            local top = data.Container or topModel(part)
            if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
                full[part] = nil
            end
        end
        return self
    end

    -- Purge learned names from the hazard tables as they are learned.
    local oldRefreshOwn = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local before = self.LastCacheTime
        oldRefreshOwn(self, force)
        if self.LastCacheTime ~= before then
            for i = #self.CachedActive, 1, -1 do
                local data = self.CachedActive[i]
                local top = data.Container
                if top and OWN_ABILITY_NAMES[string.lower(top.Name)] then
                    table.remove(self.CachedActive, i)
                    local full = self.FullHazards or self.Hazards
                    full[data.Part] = nil
                    if self.NearHazards then self.NearHazards[data.Part] = nil end
                end
            end
        end
    end
end

-- v44.17: user feedback round (Enchanted Forest).
--   * finished line attacks are not dangerous: once the warning has faded
--     (and the touch window has passed) the attack no longer blocks us
--   * the Ancient Enchanted Tree is always the target while it lives
--   * around the Tree, dodges keep their sideways part but lose the part that
--     pushes away from the shore
--   * Enchanted Forest mobs: walk in closer before casting
do
    -- The Tree (room 4) is a boss too: boss movement, boss casting, no hit & run.
    MINI_BOSS_NAMES["ancient enchanted tree"] = true
    MINI_BOSS_NAMES["enchanted forest dragon"] = true

    CONFIG.PostWarningWindow = 0.9
    CONFIG.ForestMobCastRange = 48

    local function isTree(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient enchanted tree"
            and enemy.Root and enemy.Root.Parent
    end

    local function inForest()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value:IsA("StringValue") and value.Value == "Enchanted Forest"
    end

    ---------------------------------------------------------------------------
    -- Warning faded -> attack done.
    ---------------------------------------------------------------------------
    -- (v44.22: the warning is looked for during the whole attack, and a
    -- warning that was shown and then removed also counts as faded. Before,
    -- a warning added late or deleted after fading kept the attack "live"
    -- forever - e.g. the Crystal Golem's crystals.)
    local oldActive = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        local result = oldActive(self, container, now)
        if not result then
            return false
        end
        local state = self.ContainerState[container]
        if not state then
            return result
        end
        local pre = state.PrecastPart
        if (not pre or not pre.Parent) and now - (state.PrecastLookAt or -1) >= 0.3 then
            state.PrecastLookAt = now
            local found = container:FindFirstChild("precast", true)
            if found and found:IsA("BasePart") then
                state.PrecastPart = found
                pre = found
            end
        end
        local visible = pre ~= nil and pre.Parent ~= nil and pre.Transparency < 0.95
        if visible then
            state.PrecastSeen = true
            state.PrecastLastVisible = now
            return true
        end
        if not state.PrecastSeen then
            return result -- attack without a warning: trust the normal check
        end
        if now - state.PrecastLastVisible > CONFIG.PostWarningWindow
            and now - (state.FirstSeen or now) > CONFIG.TouchDangerWindow + 0.2
        then
            return false
        end
        return result
    end

    ---------------------------------------------------------------------------
    -- Tree first.
    ---------------------------------------------------------------------------
    local oldSelect = UIWController.SelectTarget
    function UIWController:SelectTarget()
        local best = oldSelect(self)
        if best and isTree(best) then
            return best
        end
        for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
            if isTree(enemy) and enemy.Humanoid and enemy.Humanoid.Health > 0 then
                local distance = flatten(enemy.Root.Position - self.Character.Root.Position).Magnitude
                if distance <= 260 then
                    if enemy.Model ~= self.CurrentEnemyModel then
                        self:SetTarget(enemy)
                    else
                        self.CurrentEnemy = enemy
                    end
                    return enemy
                end
            end
        end
        return best
    end

    ---------------------------------------------------------------------------
    -- Around the Tree: never drift away from the shore while dodging.
    ---------------------------------------------------------------------------
    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolve(self, routeDirection, enemy, targetYaw)
        if not isTree(enemy) or not direction or direction.Magnitude <= 0.05 then
            return direction, yaw, emergency, dodging
        end
        local reason = self.LastDodgeReason
        if reason == "tree-sweeper" then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        local rel = flatten(root.Position - enemy.Root.Position)
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - enemy.Root.Position).Magnitude or 100
        if rel.Magnitude <= standR + 4 then
            return direction, yaw, emergency, dodging
        end
        local out = rel.Unit
        local outward = direction:Dot(out)
        if outward <= 0.1 then
            return direction, yaw, emergency, dodging
        end
        local sideways = direction - out * outward
        if sideways.Magnitude < 0.2 then
            return direction, yaw, emergency, dodging
        end
        local dir = sideways.Unit
        if self.Hazards:IsTrajectoryClear(root.Position, dir, targetYaw, 5)
            and self.Geometry:IsDirectionClear(dir, 5, directionToYaw(dir))
        then
            local scaled = dir * direction.Magnitude
            self.CachedDirection = scaled
            self.LastMovement = dir
            return scaled, yaw, emergency, dodging
        end
        return direction, yaw, emergency, dodging
    end

    ---------------------------------------------------------------------------
    -- Enchanted Forest mobs: cast from closer.
    ---------------------------------------------------------------------------
    local function withMobRange(fn)
        return function(self, enemy, ...)
            if enemy and not isBossEnemy(enemy) and inForest() then
                local base = CONFIG.DamageCastRange
                CONFIG.DamageCastRange = math.min(base, CONFIG.ForestMobCastRange)
                local ok, a, b = pcall(fn, self, enemy, ...)
                CONFIG.DamageCastRange = base
                if not ok then error(a, 0) end
                return a, b
            end
            return fn(self, enemy, ...)
        end
    end

    CombatController.Update = withMobRange(CombatController.Update)
    CombatController.ShouldHoldApproach = withMobRange(CombatController.ShouldHoldApproach)

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.17"
        return self
    end
end

-- v44.19: Crystal Golem electrical sweepers.
--
-- The old handler only inspected Workspace:FindFirstChild(), so two of the
-- three same-named geode attacks could be ignored.  It also moved around the
-- boss, although each electrical cross rotates around its own landed geode.
-- Track every live hitbox, measure its real angular velocity, and choose a
-- movement vector that remains inside a predicted rotating gap.
do
    CONFIG.GolemSpinnerClearance = 4.5
    CONFIG.GolemSpinnerLookahead = 0.95
    CONFIG.GolemSpinnerRange = 180
    CONFIG.GolemSpinnerAngles = 24
    CONFIG.GolemSpinnerInactiveGrace = 0.85
    CONFIG.GolemSafeHoldGrace = 0.65

    local PI = math.pi

    local function rotateVectorXZ(vector, radians)
        local cosine = math.cos(radians)
        local sine = math.sin(radians)
        return Vector3.new(
            vector.X * cosine - vector.Z * sine,
            vector.Y,
            vector.X * sine + vector.Z * cosine
        )
    end

    local function signedLineAngleDelta(current, previous)
        return (current - previous + PI * 0.5) % PI - PI * 0.5
    end

    function HazardTracker:GetCrystalGolemSweepers()
        local now = os.clock()
        local tracks = self.GolemSweeperTracks or {}
        local live = {}
        local result = {}

        for _, model in ipairs(Workspace:GetChildren()) do
            if string.lower(model.Name or "") == "firstbossspinningrockhitbox" then
                local ok, pivotCFrame = pcall(model.GetPivot, model)
                local pivot = ok and pivotCFrame.Position or nil

                for _, part in ipairs(model:GetDescendants()) do
                    if part:IsA("BasePart") and string.lower(part.Name or "") == "hitbox" then
                        live[part] = true

                        local size = part.Size
                        local longIsX = size.X >= size.Z
                        local axis = flatten(longIsX and part.CFrame.RightVector or part.CFrame.LookVector)

                        if axis.Magnitude > 0.01 then
                            axis = axis.Unit
                            local angle = math.atan2(axis.Z, axis.X)
                            local info = tracks[part] or {
                                Angle = angle,
                                At = now,
                                Omega = 0,
                                BornAt = now,
                                LastPosition = part.Position,
                            }
                            local dt = now - (info.At or now)

                            if dt >= 0.025 then
                                local measured = signedLineAngleDelta(angle, info.Angle or angle) / dt
                                local moved = flatten(part.Position - (info.LastPosition or part.Position)).Magnitude
                                if math.abs(measured) < math.rad(240) then
                                    info.Omega = (info.Omega or 0) * 0.55 + measured * 0.45
                                    if math.abs(info.Omega) < math.rad(0.35) then
                                        info.Omega = 0
                                    end
                                end
                                if math.abs(measured) >= math.rad(0.8) or moved >= 0.035 then
                                    info.HadMotion = true
                                    info.LastMotionAt = now
                                end
                                info.Angle = angle
                                info.At = now
                                info.LastPosition = part.Position
                            end

                            info.Part = part
                            info.Model = model
                            info.Center = part.Position
                            info.Pivot = pivot or part.Position
                            info.PivotOffset = flatten(part.Position - info.Pivot)
                            info.HalfLength = (longIsX and size.X or size.Z) * 0.5
                            info.HalfWidth = (longIsX and size.Z or size.X) * 0.5
                            tracks[part] = info

                            -- The model lives for about ten seconds, but its
                            -- invisible hitbox can remain after the damaging
                            -- rotation has stopped.  Once real motion has been
                            -- observed, stationary time is proof that this cast
                            -- is finished.  Retire it locally instead of letting
                            -- a stale part keep the dodge solver active.
                            if info.HadMotion
                                and now - (info.LastMotionAt or now) >= CONFIG.GolemSpinnerInactiveGrace
                            then
                                info.Retired = true
                                local full = self.FullHazards or self.Hazards
                                full[part] = nil
                                if self.NearHazards then self.NearHazards[part] = nil end
                            end

                            if not info.Retired then
                                table.insert(result, info)
                            end
                        end
                    end
                end
            end
        end

        for part in pairs(tracks) do
            if not live[part] or not part.Parent then
                tracks[part] = nil
            end
        end

        self.GolemSweeperTracks = tracks
        return result
    end

    local function sweeperClearance(laser, position, dt)
        local rotation = (laser.Omega or 0) * dt
        local axis = Vector3.new(math.cos(laser.Angle + rotation), 0, math.sin(laser.Angle + rotation))
        local center = laser.Pivot + rotateVectorXZ(laser.PivotOffset, rotation)
        local relative = flatten(position - center)
        local along = math.abs(relative:Dot(axis))
        local across = math.abs(relative.X * axis.Z - relative.Z * axis.X)
        local beyondEnd = math.max(along - laser.HalfLength, 0)
        local beyondSide = math.max(across - laser.HalfWidth, 0)

        if beyondEnd > 0 then
            return math.sqrt(beyondEnd * beyondEnd + beyondSide * beyondSide)
        end
        return across - laser.HalfWidth
    end

    local function minimumSweeperClearance(lasers, position, dt)
        local best = math.huge
        for _, laser in ipairs(lasers) do
            best = math.min(best, sweeperClearance(laser, position, dt))
        end
        return best
    end

    function DodgeSolver:GetCrystalGolemSpinnerMove(routeDirection, enemy, targetYaw)
        if not enemy or not enemy.Model or normalizeEnemyName(enemy.Model.Name) ~= "crystal golem"
            or not self.CharacterService:IsAlive()
        then
            return nil
        end

        local lasers = self.Hazards:GetCrystalGolemSweepers()
        if #lasers == 0 then
            self.GolemSpinnerUrgent = false
            return nil
        end

        local root = self.CharacterService.Root
        local origin = root.Position
        local inRange = false
        for _, laser in ipairs(lasers) do
            if flatten(origin - laser.Pivot).Magnitude <= CONFIG.GolemSpinnerRange then
                inRange = true
                break
            end
        end
        if not inRange then
            self.GolemSpinnerUrgent = false
            return nil
        end

        local humanoid = self.CharacterService.Humanoid
        local speed = math.max(humanoid and humanoid.WalkSpeed or 16, 8)
        local route = unit(flatten(routeDirection or Vector3.zero))
        local samples = { 0.16, 0.34, 0.56, CONFIG.GolemSpinnerLookahead }
        local stillClear = math.huge
        for _, dt in ipairs(samples) do
            stillClear = math.min(stillClear, minimumSweeperClearance(lasers, origin, dt))
        end

        local currentClear = minimumSweeperClearance(lasers, origin, 0)
        local urgent = currentClear < CONFIG.GolemSpinnerClearance + 5
            or stillClear < CONFIG.GolemSpinnerClearance + 2
        self.GolemSpinnerUrgent = urgent

        -- Once the crystal has put us in a real safe bubble / wall, do not let
        -- the rotating-gap planner walk us back out merely to improve its
        -- score.  Leaving is allowed only when damage is actually reaching the
        -- held spot, which covers the rare case where a sweeper crosses it.
        local holdingRegion = self.ForcedRegionPart
            and self:IsPointInsideForcedRegion(origin)
        local damageInRegion = currentClear < CONFIG.GolemSpinnerClearance
            or self.Hazards:GetOverlapCountAt(origin, targetYaw) > 0
        if holdingRegion and not damageInRegion then
            self.GolemSafeSpotHolding = true
            self.GolemSpinnerUrgent = false
            return Vector3.zero, false
        end
        self.GolemSafeSpotHolding = false

        local bestMove = nil
        local bestScore = -math.huge
        local bestSafe = false

        local function consider(direction, scale)
            local moving = direction.Magnitude > 0.05
            local velocity = moving and direction.Unit * speed * scale or Vector3.zero
            local reach = math.min(velocity.Magnitude * 0.55, 10)

            if moving and not self.Geometry:IsDirectionClear(direction.Unit, math.max(reach, 3), directionToYaw(direction)) then
                return
            end

            local minimum = math.huge
            local finalClear = math.huge
            local endpoint = origin
            for _, dt in ipairs(samples) do
                endpoint = origin + velocity * dt
                local clearance = minimumSweeperClearance(lasers, endpoint, dt)
                minimum = math.min(minimum, clearance)
                finalClear = clearance
            end

            local safe = minimum >= CONFIG.GolemSpinnerClearance
            local score = (safe and 100000 or 0)
                + math.min(minimum, 30) * 900
                + math.min(finalClear, 35) * 120
                + self:GetBossBandScore(origin, endpoint) * 0.35

            if route.Magnitude > 0 and moving then
                score += velocity.Unit:Dot(route) * (safe and 95 or 25)
            end

            if moving then
                score -= self.Hazards:GetOverlapCountAt(endpoint, targetYaw) * 350
                if self.Geometry:IsGroundPadded(endpoint, CONFIG.EdgeHardPadding) then
                    score += 180
                else
                    score -= 1200
                end
            elseif urgent then
                score -= 450
            else
                score += 40
            end

            if (safe and not bestSafe) or safe == bestSafe and score > bestScore then
                bestSafe = safe
                bestScore = score
                bestMove = moving and velocity / speed or Vector3.zero
            end
        end

        consider(Vector3.zero, 0)
        for index = 0, CONFIG.GolemSpinnerAngles - 1 do
            local angle = index / CONFIG.GolemSpinnerAngles * PI * 2
            local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
            consider(direction, 1)
            consider(direction, 0.58)
        end

        return bestMove, urgent
    end

    local oldSolveGolemSpinner = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local ok, movement, urgent = pcall(
            self.GetCrystalGolemSpinnerMove,
            self,
            routeDirection,
            enemy,
            targetYaw
        )

        if ok and movement then
            local now = os.clock()
            self.CurrentSolveEnemy = enemy
            self.LastSolve = now
            self.LastDodgeReason = "golem-sweeper-spin"
            self.IsDodging = true
            self.CachedDirection = movement
            self.CachedYaw = targetYaw
            self.CachedEmergency = urgent
            self.CachedDodging = true
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
            if movement.Magnitude > 0.05 then
                self.LastMovement = movement.Unit
            end
            return movement, targetYaw, urgent, true
        elseif not ok then
            self.GolemSpinnerError = tostring(movement)
        end

        return oldSolveGolemSpinner(self, routeDirection, enemy, targetYaw)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.20"
        self.Combat.Owner = self
        return self
    end
end

-- v44.20: close-range adaptive mob combos.
-- A buff-only skill is always primed immediately before the ready damage
-- skill(s).  With no Inner Focus / Inner Rage equipped, ready damage skills
-- are queued together and fired back-to-back as soon as each cast lock ends.
do
    CONFIG.MobBurstRange = 34
    CONFIG.MobBurstBuffWait = 3.0
    CONFIG.MobSpamSyncWait = 1.25
    CONFIG.MobComboWindow = 6.0
    CONFIG.MobBuffCarryWindow = 3.2
    CONFIG.MobStageDistance = 90
    CONFIG.MobBurstDirectRange = 70   -- beyond this the route decides the way
    CONFIG.ForestMobCastRange = CONFIG.MobBurstRange

    local function getMobSpellState(combat)
        local buffs = {}
        local damage = {}
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool then
                local entry = {
                    Slot = slot,
                    Tool = tool,
                    Ready = combat:IsSlotCooldownReady(slot),
                    Wait = combat:GetCooldownRemaining(slot) or math.huge,
                }
                if combat:IsBuffTool(tool) then
                    table.insert(buffs, entry)
                else
                    table.insert(damage, entry)
                end
            end
        end
        return buffs, damage
    end

    local function clearMobCombo(combat, clearPrimed)
        combat.MobComboTarget = nil
        combat.MobComboQueue = nil
        combat.MobComboIndex = nil
        combat.MobComboUntil = nil
        if clearPrimed then
            combat.MobBuffPrimedUntil = nil
        end
    end

    local function hasReady(entries)
        for _, entry in ipairs(entries) do
            if entry.Ready then return true end
        end
        return false
    end

    local function allReady(entries)
        if #entries == 0 then return false end
        for _, entry in ipairs(entries) do
            if not entry.Ready then return false end
        end
        return true
    end

    local function pendingDamage(combat)
        local queue = combat.MobComboQueue
        if not queue then return false end
        for index = combat.MobComboIndex or 1, #queue do
            if not queue[index].Buff then return true end
        end
        return false
    end

    local oldPreferredMobBurst = DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection, enemy, targetYaw)
        if enemy and enemy.Model and enemy.Root and enemy.Root.Parent
            and not isBossEnemy(enemy)
            and not self.ForceRouteMovement
            and not self.TargetBlocked
            and self.CharacterService:IsAlive()
        then
            local combat = self.Combat
            local buffs, damage = {}, {}
            if combat then
                buffs, damage = getMobSpellState(combat)
            end
            local buffReady = #buffs == 0 or hasReady(buffs)
            local burstArmed = allReady(damage) and buffReady
                or (combat and combat.MobComboTarget == enemy.Model)

            if burstArmed then
                local root = self.CharacterService.Root
                local offset = enemy.Root.Position - root.Position
                local toward = unit(flatten(offset))
                local distance = flatten(offset).Magnitude
                -- Only walk straight at the mob when it is close, on our level
                -- and nothing is in between; otherwise keep following the path
                -- (a straight line through walls got the character stuck).
                if distance > CONFIG.MobBurstRange - 2
                    and distance <= CONFIG.MobBurstDirectRange
                    and toward.Magnitude > 0
                    and math.abs(offset.Y) <= CONFIG.EngageMaxHeightDiff
                    and combat and combat:HasLineOfSight(enemy)
                then
                    local step = math.min(distance - CONFIG.MobBurstRange + 2, 16)
                    if self.Geometry:IsWideSegmentClear(root.Position, root.Position + toward * step, CONFIG.PathPreferredRadius) then
                        return unit(toward * 1.35 + unit(flatten(routeDirection)) * 0.25)
                    end
                end
            end
        end
        return oldPreferredMobBurst(self, routeDirection, enemy, targetYaw)
    end

    -- Stage outside normal aggro range until the complete one-shot package is
    -- ready.  Do not use travel-time prediction to enter early: every equipped
    -- damage spell, plus a present buff, must be ready before committing.
    local oldMobComboHold = CombatController.ShouldHoldApproach
    function CombatController:ShouldHoldApproach(enemy, travelMode)
        if enemy and enemy.Model and enemy.Root and enemy.Root.Parent
            and not isBossEnemy(enemy) and self.CharacterService:IsAlive()
        then
            local distance = flatten(enemy.Root.Position - self.CharacterService.Root.Position).Magnitude
            if distance > CONFIG.MobBurstRange and distance <= CONFIG.MobStageDistance then
                local buffs, damage = getMobSpellState(self)
                if #damage > 0 then
                    local packageReady = allReady(damage)
                        and (#buffs == 0 or hasReady(buffs))
                    self.CooldownHolding = not packageReady
                    return not packageReady
                end
            end
        end
        return oldMobComboHold(self, enemy, travelMode)
    end

    local oldMobBurstUpdate = CombatController.Update
    function CombatController:Update(enemy)
        local now = os.clock()
        local primed = self.MobBuffPrimedUntil and now < self.MobBuffPrimedUntil

        if not enemy or not enemy.Model then
            -- Keep a just-primed damage queue alive while target selection moves
            -- to the next mob; otherwise the buff is wasted between targets.
            if primed and pendingDamage(self) then
                self.MobComboTarget = nil
            else
                clearMobCombo(self)
            end
            return oldMobBurstUpdate(self, enemy)
        end

        if isBossEnemy(enemy) then
            clearMobCombo(self, true)
            return oldMobBurstUpdate(self, enemy)
        end

        if not enemy.Root or not enemy.Root.Parent or not self.CharacterService:IsAlive() then
            if primed and pendingDamage(self) then
                self.MobComboTarget = nil
            else
                clearMobCombo(self)
            end
            return oldMobBurstUpdate(self, enemy)
        end

        self.LastAction = nil
        self.LastBlockReason = nil

        if self.MobComboQueue and pendingDamage(self)
            and primed and self.MobComboTarget ~= enemy.Model
        then
            self.MobComboTarget = enemy.Model
            self.MobComboUntil = now + CONFIG.MobComboWindow
        elseif self.MobComboTarget
            and (self.MobComboTarget ~= enemy.Model or now > (self.MobComboUntil or 0))
        then
            clearMobCombo(self)
        end

        local root = self.CharacterService.Root
        local offset = flatten(enemy.Root.Position - root.Position)
        local distance = offset.Magnitude
        if distance > CONFIG.MobBurstRange then
            self.LastBlockReason = "closing for close-range mob combo"
            return false
        end

        if not self:CanSendInput() then
            self.LastBlockReason = "chat focused"
            return false
        end
        if CONFIG.NoCastWhileEscaping and self.EscapingHitbox then
            self.LastBlockReason = "escaping hitbox"
            return false
        end
        if self:IsBusyCasting() then
            self.LastBlockReason = self.MobComboTarget and "linking mob combo" or "casting"
            return false
        end

        local aimYaw = (self.LastAimModel == enemy.Model and self.LastAimYaw)
            or directionToYaw(offset)
        if not self:IsFacing(aimYaw, CONFIG.CastFacingTolerance) then
            self.LastBlockReason = "turning to target"
            return false
        end
        if distance > CONFIG.LosBypassDistance and not self:HasLineOfSight(enemy) then
            self.LastBlockReason = "no line of sight"
            return false
        end

        local buffs, damage = getMobSpellState(self)
        if #damage == 0 then
            return oldMobBurstUpdate(self, enemy)
        end

        -- Continue the queued combo. Inputs are deliberately sent after each
        -- cast lock rather than literally on the same frame, where Roblox can
        -- discard the second key press.
        if self.MobComboTarget == enemy.Model and self.MobComboQueue then
            local index = self.MobComboIndex or 1
            local entry = self.MobComboQueue[index]
            if not entry then
                clearMobCombo(self)
                return false
            end
            if self:IsReady(entry.Slot) then
                self:Press(entry.Slot)
                if entry.Buff then
                    self.MobBuffPrimedUntil = now + CONFIG.MobBuffCarryWindow
                end
                self.MobComboIndex = index + 1
                if index >= #self.MobComboQueue then
                    clearMobCombo(self, true)
                    self:ClearCommit()
                    self.RetreatArmed = true
                    self.RetreatArmedAt = now
                end
                return true
            end
            self.LastBlockReason = entry.Buff
                and "waiting to prime mob buff"
                or "waiting for next combo damage input"
            return false
        end

        local readyDamage = {}
        local soonestDamage = math.huge
        for _, entry in ipairs(damage) do
            soonestDamage = math.min(soonestDamage, entry.Wait)
            if entry.Ready then table.insert(readyDamage, entry) end
        end
        if #readyDamage == 0 then
            self.LastBlockReason = "damage cooldown"
            return false
        end

        local readyBuff = nil
        local soonestBuff = math.huge
        for _, entry in ipairs(buffs) do
            soonestBuff = math.min(soonestBuff, entry.Wait)
            if entry.Ready and not readyBuff then readyBuff = entry end
        end

        if #buffs > 0 and not readyBuff and soonestBuff <= CONFIG.MobBurstBuffWait then
            self.LastBlockReason = string.format("holding mob combo for buff | %.1fs", soonestBuff)
            return false
        end

        -- No buff equipped: synchronize two damage spells when the second is
        -- almost ready; otherwise use every damage spell that is ready now.
        if #buffs == 0 and #damage > 1 and #readyDamage < #damage then
            local longestShortWait = 0
            for _, entry in ipairs(damage) do
                if not entry.Ready then longestShortWait = math.max(longestShortWait, entry.Wait) end
            end
            if longestShortWait <= CONFIG.MobSpamSyncWait then
                self.LastBlockReason = string.format("syncing damage spam | %.1fs", longestShortWait)
                return false
            end
        end

        local queue = {}
        if readyBuff then
            table.insert(queue, { Slot = readyBuff.Slot, Buff = true })
        end
        for _, entry in ipairs(readyDamage) do
            table.insert(queue, { Slot = entry.Slot, Buff = false })
        end

        self.MobComboTarget = enemy.Model
        self.MobComboQueue = queue
        self.MobComboIndex = 1
        self.MobComboUntil = now + CONFIG.MobComboWindow
        self:ArmCommit(enemy)

        local first = queue[1]
        if first and self:IsReady(first.Slot) then
            self:Press(first.Slot)
            if first.Buff then
                self.MobBuffPrimedUntil = now + CONFIG.MobBuffCarryWindow
            end
            self.MobComboIndex = 2
            if #queue == 1 then
                clearMobCombo(self, true)
                self:ClearCommit()
                self.RetreatArmed = true
                self.RetreatArmedAt = now
            end
            return true
        end

        self.LastBlockReason = "arming mob combo"
        return false
    end

    -- v44.13 used buffs for urgent dodges, which could consume Inner Focus at
    -- long range immediately before a mob burst.  On normal mobs, reserve the
    -- buff for damage unless health is low enough that survival must win.
    local oldTryEscapeBuffMobCombo = CombatController.TryEscapeBuff
    function CombatController:TryEscapeBuff()
        local owner = self.Owner
        local enemy = owner and owner.CurrentEnemy
        if enemy and enemy.Model and not isBossEnemy(enemy) then
            local humanoid = self.CharacterService.Humanoid
            local healthRatio = humanoid
                and humanoid.Health / math.max(humanoid.MaxHealth, 1)
                or 0
            if healthRatio > 0.35 then
                return false
            end
        end
        return oldTryEscapeBuffMobCombo(self)
    end
end

-- v44.19: permanently evict attack parts after the normal activity detector
-- has observed the effect and then declared its container finished.  This does
-- not destroy server-owned instances; it removes only stale local hazard data.
do
    local oldContainerActiveRetire = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        local state = container and self.ContainerState[container] or nil
        if state and state.UIWRetired then
            return false
        end

        local active = oldContainerActiveRetire(self, container, now)
        state = container and self.ContainerState[container] or nil
        if state and state.RawActive then
            state.UIWWasActive = true
        end

        if state and state.UIWWasActive and not active and not state.UIWRetired then
            state.UIWRetired = true
            local full = self.FullHazards or self.Hazards
            for _, object in ipairs(container:GetDescendants()) do
                if object:IsA("BasePart") then
                    full[object] = nil
                    self.Hazards[object] = nil
                    if self.NearHazards then self.NearHazards[object] = nil end
                end
            end
            self.LastCacheTime = 0
        end

        return active
    end
end

-- v44.20: keep crystal-mechanic shelter until it really deactivates, and bind
-- spawned attacks to their living source so a dead mob/boss can never leave a
-- locally blocking hitbox behind.
do
    ---------------------------------------------------------------------------
    -- Crystal Golem: latch the chosen cleanse bubble after the falling crystal
    -- disappears. The active light / force-field state, not the crystal model,
    -- is the authority for when the mechanic has actually ended.
    ---------------------------------------------------------------------------
    local oldGolemCleanseGoal = UIWController.GetCrystalGolemCleanseGoal
    function UIWController:GetCrystalGolemCleanseGoal()
        local now = os.clock()
        local goal, part = oldGolemCleanseGoal(self)
        if goal and part and part.Parent then
            self.GolemHeldSafePart = part
            self.GolemHeldSafeSeenAt = now
            return goal, part
        end

        local held = self.GolemHeldSafePart
        if held and held.Parent and self:IsCrystalGolemFight() then
            local active = self:GetCrystalGolemCleanseBubble()
            if active and active.Parent then
                -- Follow the active bubble if the game replaced its part.
                self.GolemHeldSafePart = active
                self.GolemHeldSafeSeenAt = now
                return active.Position, active
            end
            if now - (self.GolemHeldSafeSeenAt or 0) <= CONFIG.GolemSafeHoldGrace then
                return held.Position, held
            end
        end

        self.GolemHeldSafePart = nil
        self.GolemHeldSafeSeenAt = nil
        return nil, nil
    end

    local function pointInsideMechanicPart(part, position)
        if not part or not part.Parent or not part:IsA("BasePart") then
            return false
        end
        local localPoint = part.CFrame:PointToObjectSpace(position)
        local inset = math.min(
            CONFIG.GolemForcedRegionInset,
            math.min(part.Size.X, part.Size.Z) * 0.18
        )
        local halfX = math.max(part.Size.X * 0.5 - inset, part.Size.X * 0.25)
        local halfZ = math.max(part.Size.Z * 0.5 - inset, part.Size.Z * 0.25)
        return math.abs(localPoint.X) <= halfX and math.abs(localPoint.Z) <= halfZ
    end

    local oldPriorityMechanicGoal = UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        local goal, state, part, distance = oldPriorityMechanicGoal(self)
        if state == "FallingCrystalCleanse" and self.Character:IsAlive() then
            local inside = pointInsideMechanicPart(part, self.Character.Root.Position)
            -- Run to shelter first; once inside, keep attacking any boss that is
            -- in cast range while the movement controller holds the safe spot.
            self.Combat.SuppressForMajorEscape = not inside
            self.GolemSafeSpotInside = inside
        else
            self.GolemSafeSpotInside = false
        end
        return goal, state, part, distance
    end

    ---------------------------------------------------------------------------
    -- Attack ownership: associate each newly observed attack container with the
    -- closest live enemy at spawn time. Once that exact enemy dies or is removed,
    -- evict all of its attack parts from both hazard tables immediately.
    ---------------------------------------------------------------------------
    CONFIG.AttackSourceBindRadius = 180

    local oldRegisterDeadSource = HazardTracker.Register
    function HazardTracker:Register(part)
        local known = (self.FullHazards or self.Hazards)[part] ~= nil
        oldRegisterDeadSource(self, part)
        local full = self.FullHazards or self.Hazards
        local data = full[part]
        if known or not data or data.SourceEnemyModel or not self.Dungeon then
            return
        end

        self.AttackSourceByContainer = self.AttackSourceByContainer
            or setmetatable({}, { __mode = "k" })
        local key = data.Container or part.Parent
        local source = key and self.AttackSourceByContainer[key] or nil
        if source and (not source.Model.Parent or source.Humanoid.Health <= 0) then
            source = nil
        end

        if not source then
            local bestDistance = CONFIG.AttackSourceBindRadius
            for _, enemy in ipairs(self.Dungeon:GetAliveEnemies(true)) do
                if enemy.Root and enemy.Root.Parent then
                    local distance = (enemy.Root.Position - part.Position).Magnitude
                    if distance < bestDistance then
                        source = enemy
                        bestDistance = distance
                    end
                end
            end
            if source and key then
                self.AttackSourceByContainer[key] = source
            end
        end

        if source then
            data.SourceEnemyModel = source.Model
            data.SourceEnemyHumanoid = source.Humanoid
        end
    end

    local function sourceIsDead(data)
        local model = data.SourceEnemyModel
        if not model then return false end
        if not model.Parent then return true end
        local humanoid = data.SourceEnemyHumanoid
        if not humanoid or not humanoid.Parent then
            humanoid = model:FindFirstChildOfClass("Humanoid")
            data.SourceEnemyHumanoid = humanoid
        end
        return not humanoid or humanoid.Health <= 0
    end

    local oldRefreshDeadSource = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        local full = self.FullHazards or self.Hazards
        local removed = 0
        for part, data in pairs(full) do
            if sourceIsDead(data) then
                full[part] = nil
                if self.Hazards ~= full then self.Hazards[part] = nil end
                if self.NearHazards then self.NearHazards[part] = nil end
                removed += 1
            end
        end
        if removed > 0 then
            self.DeadSourceHazardsRemoved = (self.DeadSourceHazardsRemoved or 0) + removed
            self.LastCacheTime = 0
        end
        return oldRefreshDeadSource(self, force)
    end
end

-- v44.21: moves copied from a live player run (Enchanted Forest, 3:23 clear,
-- recording rec_0917_205046):
--   * one Q + E per mob pack: Q (Inner Rage) at ~60-80 studs, E about 1.1 s
--     later at ~40-52 studs, then straight on to the next pack
--   * Inner Rage is also used just to run faster (walk speed 16 -> 24)
--     between packs and on the way to bosses, whenever nothing is close
do
    CONFIG.MobBurstRange = 46
    CONFIG.ForestMobCastRange = 46

    CONFIG.TravelBuff = true
    CONFIG.TravelBuffMinDistance = 110   -- target this far (or none): cast the buff to run
    CONFIG.TravelBuffClearRadius = 80    -- no living enemy this close
    CONFIG.TravelBuffInterval = 1.0

    local function nearestEnemyDistance(controller, position)
        local best = math.huge
        local ok, enemies = pcall(function()
            return controller.Dungeon:GetAliveEnemies()
        end)
        if not ok or type(enemies) ~= "table" then
            return best
        end
        for _, enemy in ipairs(enemies) do
            if enemy.Root and enemy.Root.Parent then
                best = math.min(best, (enemy.Root.Position - position).Magnitude)
            end
        end
        return best
    end

    function UIWController:TryTravelBuff()
        if not CONFIG.TravelBuff or not self.AutoCombat then
            return false
        end
        local now = os.clock()
        if now - (self.TravelBuffCheckAt or 0) < CONFIG.TravelBuffInterval then
            return false
        end
        self.TravelBuffCheckAt = now

        local character = self.Character
        local root = character.Root
        if not root or not character:IsAlive() then
            return false
        end
        -- only while actually travelling, never while dodging or holding
        if (self.LastCommandedMovement or Vector3.zero).Magnitude < 0.6
            or self.Dodger.IsDodging
            or self.Dodger.CooldownHold
            or self.Combat.CooldownHolding
            or self.InWaterStream
        then
            return false
        end
        local humanoid = character.Humanoid
        if humanoid and humanoid.WalkSpeed > CONFIG.WalkSpeed + 1 then
            return false -- already buffed
        end

        local enemy = self.CurrentEnemy
        if enemy and enemy.Root and enemy.Root.Parent then
            local distance = flatten(enemy.Root.Position - root.Position).Magnitude
            if distance < CONFIG.TravelBuffMinDistance then
                return false
            end
        end
        if nearestEnemyDistance(self, root.Position) < CONFIG.TravelBuffClearRadius then
            return false
        end

        local combat = self.Combat
        if not combat:CanSendInput() or combat:IsBusyCasting() then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool and combat:IsBuffTool(tool) and combat:IsReady(slot) then
                combat:Press(slot)
                self.TravelBuffs = (self.TravelBuffs or 0) + 1
                return true
            end
        end
        return false
    end

    ---------------------------------------------------------------------------
    -- Crystal Golem: the player killed it with two Q+E combos from 60-80 studs
    -- in about 10 s and never used the rock wall. Only go for rocks when the
    -- golem is still alive after GolemBurstWindow seconds of fighting.
    ---------------------------------------------------------------------------
    CONFIG.GolemBurstWindow = 25

    local oldRockWall = UIWController.GetCrystalGolemRockWallGoal
    function UIWController:GetCrystalGolemRockWallGoal()
        local enemy = self.CurrentEnemy
        local golem = self:IsCrystalGolemFight() and enemy and enemy.Model or nil
        if not golem then
            self.GolemFightModel, self.GolemFightStart = nil, nil
            return oldRockWall(self)
        end
        local root = self.Character.Root
        local close = root and enemy.Root and flatten(enemy.Root.Position - root.Position).Magnitude <= 110
        if self.GolemFightModel ~= golem then
            self.GolemFightModel, self.GolemFightStart = golem, nil
        end
        if close and not self.GolemFightStart then
            self.GolemFightStart = os.clock()
        end
        if not self.GolemFightStart or os.clock() - self.GolemFightStart < CONFIG.GolemBurstWindow then
            self:ResetCrystalGolemMechanicState()
            return nil, nil, nil
        end
        return oldRockWall(self)
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled then
            return
        end
        pcall(self.TryTravelBuff, self)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.21"
        return self
    end
end

-- v44.22: low effects. In boss fights (and whenever the lag guard is on) the
-- game's attack effects are hidden to keep the frame rate up:
--   * particles / trails / beams become fully transparent and stop emitting
--     (their Enabled flag is left alone - hazard detection reads it)
--   * lights, explosions and screen post effects are switched off
-- Warning (precast) and hitBox parts are never touched.
do
    CONFIG.LowEffectsDefault = true
    CONFIG.LowEffectsScanBudget = 400     -- descendants handled per frame

    local Lighting = game:GetService("Lighting")
    local INVISIBLE = NumberSequence.new(1)
    local SKIP_ROOTS = {
        map = true, dungeon = true, Terrain = true, Camera = true,
        UIW_HitboxESP = true, UIW_PathESP = true,
    }

    local function quiet(object)
        local class = object.ClassName
        if class == "ParticleEmitter" then
            object.Rate = 0
            object.Transparency = INVISIBLE
        elseif class == "Trail" or class == "Beam" then
            object.Transparency = INVISIBLE
        elseif class == "PointLight" or class == "SpotLight" or class == "SurfaceLight"
            or class == "Fire" or class == "Smoke" or class == "Sparkles"
        then
            object.Enabled = false
        elseif class == "Explosion" then
            object.Visible = false
        end
    end

    local LowFx = {}
    LowFx.__index = LowFx

    function LowFx.new(controller)
        return setmetatable({
            Controller = controller,
            Active = false,
            Queue = {},
            Done = setmetatable({}, { __mode = "k" }),
            Watched = setmetatable({}, { __mode = "k" }),
            Lighting = nil,
            Maid = Maid.new(),
            Quieted = 0,
        }, LowFx)
    end

    function LowFx:ShouldSkipRoot(child)
        if SKIP_ROOTS[child.Name] then
            return true
        end
        if child == LocalPlayer.Character then
            return true
        end
        return Players:GetPlayerFromCharacter(child) ~= nil
    end

    function LowFx:QueueRoot(child)
        if self.Done[child] or self:ShouldSkipRoot(child) then
            return
        end
        self.Done[child] = true
        table.insert(self.Queue, child)
        if not self.Watched[child] then
            self.Watched[child] = true
            child.DescendantAdded:Connect(function(object)
                if self.Active then
                    pcall(quiet, object)
                end
            end)
        end
    end

    function LowFx:Enable()
        if self.Active then
            return
        end
        self.Active = true
        table.clear(self.Queue)
        self.Done = setmetatable({}, { __mode = "k" })
        for _, child in ipairs(Workspace:GetChildren()) do
            self:QueueRoot(child)
        end
        -- enemies live inside the dungeon folder
        local dungeon = Workspace:FindFirstChild("dungeon")
        if dungeon then
            for _, room in ipairs(dungeon:GetChildren()) do
                local folder = room:FindFirstChild("enemyFolder")
                if folder then
                    for _, enemy in ipairs(folder:GetChildren()) do
                        self:QueueRoot(enemy)
                    end
                end
            end
        end
        if not self.Lighting then
            local saved = { GlobalShadows = Lighting.GlobalShadows, Effects = {} }
            pcall(function()
                Lighting.GlobalShadows = false
            end)
            for _, effect in ipairs(Lighting:GetChildren()) do
                if effect:IsA("PostEffect") and effect.Enabled then
                    saved.Effects[effect] = true
                    pcall(function() effect.Enabled = false end)
                end
            end
            self.Lighting = saved
        end
    end

    function LowFx:RestoreLighting()
        local saved = self.Lighting
        if not saved then
            return
        end
        self.Lighting = nil
        pcall(function()
            Lighting.GlobalShadows = saved.GlobalShadows
        end)
        for effect in pairs(saved.Effects) do
            pcall(function() effect.Enabled = true end)
        end
    end

    function LowFx:Disable()
        if not self.Active then
            return
        end
        self.Active = false
        table.clear(self.Queue)
        self:RestoreLighting()
    end

    function LowFx:Start()
        self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
            if self.Active then
                self:QueueRoot(child)
            end
        end))
    end

    -- process queued roots a little every frame (no frame spikes)
    function LowFx:Step()
        if not self.Active then
            return
        end
        local budget = CONFIG.LowEffectsScanBudget
        while budget > 0 and #self.Queue > 0 do
            local root = table.remove(self.Queue)
            if root.Parent then
                pcall(quiet, root)
                local descendants = root:GetDescendants()
                budget -= #descendants
                for _, object in ipairs(descendants) do
                    local ok = pcall(quiet, object)
                    if ok then
                        self.Quieted += 1
                    end
                end
            end
        end
    end

    function LowFx:Destroy()
        self:Disable()
        self.Maid:Clean()
    end

    ---------------------------------------------------------------------------
    local function inBossFight(controller)
        local enemy = controller.CurrentEnemy
        if not enemy or not enemy.Root or not enemy.Root.Parent or not isBossEnemy(enemy) then
            return false
        end
        local root = controller.Character.Root
        return root ~= nil and (enemy.Root.Position - root.Position).Magnitude <= 260
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.LowFx = LowFx.new(self)
        if self.LowEffects == nil then
            self.LowEffects = CONFIG.LowEffectsDefault
        end
        self.Version = "44.22"
        return self
    end

    local oldStart = UIWController.Start
    function UIWController:Start()
        oldStart(self)
        self.LowFx:Start()
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed then
            return
        end
        local now = os.clock()
        if now - (self.LowFxCheckAt or 0) >= 0.5 then
            self.LowFxCheckAt = now
            local perf = getgenv().UIW_Perf
            local lagging = type(perf) == "table" and perf.Lite == true
            local want = self.LowEffects and (inBossFight(self) or lagging)
            if want then
                self.LowFxHoldUntil = now + 8
                self.LowFx:Enable()
            elseif self.LowFx.Active and now > (self.LowFxHoldUntil or 0) then
                self.LowFx:Disable()
            end
        end
        pcall(self.LowFx.Step, self.LowFx)
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function() self.LowFx:Destroy() end)
        return oldDestroy(self)
    end

    local oldApply = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.LowEffects) == "boolean" then
            self.LowEffects = settings.LowEffects
        end
        return oldApply(self, settings)
    end

    local oldGet = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGet(self)
        settings.LowEffects = self.LowEffects ~= false
        return settings
    end
end

-- v44.23: keep facing the target until the spell actually leaves.
-- Measured live (Frost Cone, 125 ms ping): the spell model appears ~0.70 s
-- after the key press and its direction is the character's facing at THAT
-- moment, not at the press. The old code pressed and immediately turned away
-- to dodge or reposition, so casts flew off in random directions (measured
-- errors of 16, 83 and 133 degrees).
do
    CONFIG.CastFacingHold = 1.0        -- seconds of facing lock after a damage cast
    CONFIG.CastFacingMaxHold = 1.8     -- never longer than this, even while busy casting

    local function lockedYaw(character, yaw)
        local lock = character.CastLock
        if not lock then
            return yaw
        end
        local now = os.clock()
        local busy = false
        local model = character.Character
        local flag = model and model:FindFirstChild("busyCasting")
        if flag and flag:IsA("BoolValue") then
            busy = flag.Value
        end
        local expired = now > lock.Until and not busy
        if expired or now > lock.Hard then
            character.CastLock = nil
            return yaw
        end
        local root = character.Root
        local part = lock.Part
        if root and part and part.Parent then
            local to = flatten(part.Position - root.Position)
            if to.Magnitude > 0.5 then
                return directionToYaw(to.Unit)   -- follow a moving target
            end
        end
        return lock.Yaw or yaw
    end

    local oldSetYaw = CharacterService.SetYaw
    function CharacterService:SetYaw(yaw)
        return oldSetYaw(self, lockedYaw(self, yaw))
    end

    function CharacterService:LockCastFacing(part, yaw)
        local now = os.clock()
        self.CastLock = {
            Part = part,
            Yaw = yaw,
            Until = now + CONFIG.CastFacingHold,
            Hard = now + CONFIG.CastFacingMaxHold,
        }
    end

    -- remember which enemy a cast is meant for
    local oldUpdate = CombatController.Update
    function CombatController:Update(enemy)
        self.CastFacingEnemy = enemy
        return oldUpdate(self, enemy)
    end

    local oldPress = CombatController.Press
    function CombatController:Press(slot)
        local tool = self:GetTool(slot)
        if tool and not self:IsBuffTool(tool) then
            local character = self.CharacterService
            local root = character.Root
            local enemy = self.CastFacingEnemy
            local part = enemy and enemy.Root and enemy.Root.Parent and enemy.Root or nil
            local yaw = character.DesiredYaw
            if not yaw and root then
                yaw = directionToYaw(flatten(root.CFrame.LookVector))
            end
            if part or yaw then
                character:LockCastFacing(part, yaw)
            end
        end
        return oldPress(self, slot)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.23"
        return self
    end
end

-- v44.24: the two Crystal Golem attacks that were not being dodged at all.
--
-- 1. Electric sweepers. The geode lands, a 50 stud bar grows out of it, and
--    only then does it turn through the arena. Measured live: the hitbox model
--    (firstBossSpinningRockHitbox, one hitBox part 50 x 49 x 1) lives 8.2 s,
--    and the kill at 12.1 s came 2.3 s after it spawned.
--    The tracker counts an armed hitbox as dangerous for TouchDangerWindow
--    (1.6 s) after it appears, which is right for an attack that lands once and
--    exactly wrong here: the attack was dropped from the hazard tables at the
--    moment it became lethal, so nothing dodged it.
--    The rule below keeps a big armed hitbox live for as long as it is still
--    moving or turning. It is written by behaviour, not by name, so it also
--    covers the second boss's 450 stud spinning laser and whatever Northern
--    Lands turns out to have.
--
-- 2. Dome blast. "enchantedFirstBossFollowOrb" follows a player for up to 30 s
--    and on contact grows (innerBall 5.6 -> 40 studs across in 1.6 s) into a
--    dome that shreds anything still inside. The model has no part named
--    hitBox or precast, so the tracker never registered it and we never moved.
--    20 studs is one second of walking: it only ever needed to be noticed.
do
    -- a sweeping beam: big, armed, and still moving
    CONFIG.SweeperMinSize = 20              -- studs, longest side of the hitbox
    CONFIG.SweeperQuietGrace = 3.0          -- stays live this long after it stops changing
    CONFIG.SweeperMaxLife = 16              -- ...but never longer than this
    CONFIG.SweeperMoveEpsilon = 0.2         -- studs between samples
    CONFIG.SweeperGrowEpsilon = 0.5         -- the bar growing counts as being alive
    CONFIG.SweeperTurnEpsilon = math.rad(1)

    CONFIG.DomeMaxRadius = 20               -- innerBall ends at 40 wide
    CONFIG.DomePad = 6                      -- and we want daylight, not a tie
    CONFIG.DomeTriggerGrowth = 1.5          -- studs of growth that means "it went off"
    CONFIG.DomeWatchRange = 160

    ---------------------------------------------------------------------------
    -- 1. A big armed hitbox that is still moving is still an attack.
    ---------------------------------------------------------------------------
    local motion = setmetatable({}, { __mode = "k" })

    local function sweeperPart(container)
        for _, object in ipairs(container:GetDescendants()) do
            if object:IsA("BasePart")
                and string.find(string.lower(object.Name), "hitbox", 1, true)
                and math.max(object.Size.X, object.Size.Y, object.Size.Z) >= CONFIG.SweeperMinSize
            then
                return object
            end
        end
        return nil
    end

    local function stillSweeping(container, now)
        local info = motion[container]

        if not info or not info.Part then
            -- The model can be registered before its hitBox has replicated, so
            -- a miss is retried for a few seconds instead of being remembered
            -- as "not a sweeper" for good.
            local first = info and info.FirstLook or now
            if not info then
                info = { FirstLook = now, LookAt = -1 }
                motion[container] = info
            end
            if now - first > 4 then
                return false
            end
            if now - info.LookAt < 0.4 then
                return false
            end
            info.LookAt = now
            local part = sweeperPart(container)
            if not part then
                return false
            end
            info.Part, info.CF, info.Size = part, part.CFrame, part.Size
            info.At, info.Born, info.LastChange = now, now, now
            return true
        end

        local part = info.Part
        if not part or not part.Parent or now - info.Born > CONFIG.SweeperMaxLife then
            return false
        end

        -- A sweeper is quiet for a moment between landing and turning: it grows
        -- its bar first. Growth counts as life, otherwise the attack is retired
        -- during the wind-up and is gone by the time it starts killing people.
        if now - info.At >= 0.08 then
            local cf, size = part.CFrame, part.Size
            local moved = (cf.Position - info.CF.Position).Magnitude
            local turned = math.acos(math.clamp(cf.LookVector:Dot(info.CF.LookVector), -1, 1))
            local grew = (size - info.Size).Magnitude
            if moved >= CONFIG.SweeperMoveEpsilon
                or turned >= CONFIG.SweeperTurnEpsilon
                or grew >= CONFIG.SweeperGrowEpsilon
            then
                info.LastChange = now
            end
            info.CF, info.Size, info.At = cf, size, now
        end

        -- While it is still doing anything at all it stays live; a bar that has
        -- sat completely still for a while is a leftover and goes back to the
        -- normal rules.
        return now - info.LastChange <= CONFIG.SweeperQuietGrace
    end

    local oldActive = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        if container and container.Parent then
            local ok, sweeping = pcall(stillSweeping, container, now)
            if ok and sweeping then
                return true
            end
        end
        return oldActive(self, container, now)
    end

    ---------------------------------------------------------------------------
    -- 2. The sweeper planner used to switch itself off unless the current
    -- target was the golem. The geodes are thrown while we are shooting mobs,
    -- which is exactly when nothing dodged them.
    ---------------------------------------------------------------------------
    local GOLEM_STAND_IN = { Model = { Name = "Crystal Golem" } }

    -- The bar is 50 studs across, so it reaches 25 from the geode. Anything
    -- further out than this is not our problem yet - and hijacking movement for
    -- a geode 150 studs away is pure lost damage time.
    CONFIG.GolemSweeperEngage = 55

    local oldSpinnerMove = DodgeSolver.GetCrystalGolemSpinnerMove
    function DodgeSolver:GetCrystalGolemSpinnerMove(routeDirection, enemy, targetYaw)
        local targeted = enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "crystal golem"
        if not targeted then
            local root = self.CharacterService.Root
            local ok, list = pcall(self.Hazards.GetCrystalGolemSweepers, self.Hazards)
            if ok and root and type(list) == "table" then
                for _, laser in ipairs(list) do
                    local pivot = laser.Pivot or laser.Center
                    if pivot and flatten(root.Position - pivot).Magnitude <= CONFIG.GolemSweeperEngage then
                        enemy = GOLEM_STAND_IN
                        break
                    end
                end
            end
        end
        return oldSpinnerMove(self, routeDirection, enemy, targetYaw)
    end

    ---------------------------------------------------------------------------
    -- 3. Dome blast: leave the circle before it finishes growing.
    ---------------------------------------------------------------------------
    function HazardTracker:GetGrowingDomes()
        local now = os.clock()
        -- the dodge solver asks every frame; one look per 10th of a second is
        -- plenty for something that takes 1.6 s to grow, and keeps this off the
        -- frame budget when a boss arena is full of parts
        local cached = self.DomeCache
        if cached and now - cached.At < 0.1 then
            return cached.List
        end
        local states = self.DomeStates or setmetatable({}, { __mode = "k" })
        self.DomeStates = states
        local list = {}

        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") then
                local ball = model:FindFirstChild("innerBall")
                if ball and ball:IsA("BasePart") then
                    local size = ball.Size.X
                    local state = states[model]
                    if not state then
                        state = { Start = size, Born = now }
                        states[model] = state
                    end
                    state.Size = size
                    if not state.GrowingSince and size >= state.Start + CONFIG.DomeTriggerGrowth then
                        state.GrowingSince = now
                    end
                    if state.GrowingSince then
                        table.insert(list, {
                            Model = model,
                            Part = ball,
                            Center = ball.Position,
                            Radius = math.max(size * 0.5, 3),
                            Since = state.GrowingSince,
                        })
                    end
                end
            end
        end

        self.DomeCache = { At = now, List = list }
        return list
    end

    -- Where to walk so that no growing dome still covers us. Straight out is
    -- the shortest way, so it is tried first and only bent when that way is
    -- blocked or walks into something else.
    function DodgeSolver:GetDomeEscape(targetYaw)
        local character = self.CharacterService
        if not character:IsAlive() then
            return nil
        end
        local root = character.Root
        if not root then
            return nil
        end

        -- Standing in a shelter region beats the dome: missing the falling
        -- crystal is a one-shot kill, the dome is damage over time. Merely
        -- walking to some other mechanic goal does not beat it - that is how
        -- we ate 38% while strolling through a fully grown dome.
        if self.ForcedRegionPart then
            self.DomeEscaping = false
            return nil
        end

        local ok, domes = pcall(self.Hazards.GetGrowingDomes, self.Hazards)
        if not ok or type(domes) ~= "table" or #domes == 0 then
            self.DomeEscaping = false
            return nil
        end

        local origin = root.Position
        local keepOut = CONFIG.DomeMaxRadius + CONFIG.DomePad
        local away = Vector3.zero
        local caught = false

        for _, dome in ipairs(domes) do
            local offset = flatten(origin - dome.Center)
            local distance = offset.Magnitude
            if distance <= CONFIG.DomeWatchRange and distance < keepOut then
                caught = true
                local push = distance > 0.5 and offset.Unit or Vector3.new(1, 0, 0)
                -- the closer to the middle, the more this dome decides
                away += push * (keepOut - distance + 1)
            end
        end

        if not caught then
            self.DomeEscaping = false
            return nil
        end

        local preferred = unit(flatten(away))
        if preferred.Magnitude < 0.05 then
            preferred = unit(flatten(character.Root.CFrame.LookVector))
        end

        local function usable(direction)
            if not self.Geometry:IsDirectionClear(direction, 14, directionToYaw(direction)) then
                return false
            end
            local point = origin + direction * 14
            if not self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding) then
                return false
            end
            return self.Hazards:GetOverlapCountAt(point, targetYaw) == 0
        end

        for _, degrees in ipairs({ 0, -25, 25, -50, 50, -75, 75, -105, 105 }) do
            local direction = unit(rotateXZ(preferred, degrees))
            if direction.Magnitude > 0 and usable(direction) then
                self.DomeEscaping = true
                self.DomeEscapes = (self.DomeEscapes or 0) + 1
                return direction
            end
        end

        -- nothing clean: out is still better than standing in it
        self.DomeEscaping = true
        return preferred
    end

    local oldSolveForDome = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local ok, escape = pcall(self.GetDomeEscape, self, targetYaw)
        if ok and escape then
            local now = os.clock()
            self.CurrentSolveEnemy = enemy
            self.LastSolve = now
            self.LastDodgeReason = "golem-dome"
            self.IsDodging = true
            self.CachedDirection = escape
            self.CachedYaw = targetYaw
            self.CachedEmergency = true
            self.CachedDodging = true
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
            self.LastMovement = escape
            return escape, targetYaw, true, true
        end
        return oldSolveForDome(self, routeDirection, enemy, targetYaw)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.24"
        return self
    end
end
-- v44.25: keep the frame rate up when a boss arena fills with attacks.
--
-- Measured at the Enchanted Forest Dragon: 60 fps normally, 6-28 fps in the
-- heavy bursts, with 80+ live attacks on screen. Two different costs are at
-- work there - what the game draws, and what we compute - so this watches the
-- actual frame rate and eases both, then puts them back when the fight calms
-- down. Nothing is changed permanently: everything is restored when the frame
-- rate recovers and when the script unloads.
do
    CONFIG.SmoothGuard = true
    CONFIG.SmoothLowFps = 45          -- below this we start easing off
    CONFIG.SmoothGoodFps = 55         -- above this for a while we put it all back
    CONFIG.SmoothHoldTime = 5         -- seconds of good frames before restoring
    CONFIG.SmoothSampleTime = 1

    local Smooth = {}
    Smooth.__index = Smooth

    function Smooth.new(controller)
        return setmetatable({
            Controller = controller,
            Level = 0,                -- 0 = untouched, 1 = lighter, 2 = lightest
            Frames = 0,
            Fps = 60,
            LastSample = os.clock(),
            GoodSince = nil,
            Saved = {},
        }, Smooth)
    end

    -- what the game draws
    function Smooth:SetQuality(low)
        local saved = self.Saved
        pcall(function()
            local lighting = game:GetService("Lighting")
            if low then
                if saved.GlobalShadows == nil then
                    saved.GlobalShadows = lighting.GlobalShadows
                end
                lighting.GlobalShadows = false
            elseif saved.GlobalShadows ~= nil then
                lighting.GlobalShadows = saved.GlobalShadows
                saved.GlobalShadows = nil
            end
        end)
        pcall(function()
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if not terrain then
                return
            end
            if low then
                if saved.Decoration == nil then
                    saved.Decoration = terrain.Decoration
                end
                terrain.Decoration = false
            elseif saved.Decoration ~= nil then
                terrain.Decoration = saved.Decoration
                saved.Decoration = nil
            end
        end)
        pcall(function()
            local rendering = settings().Rendering
            if low then
                if saved.QualityLevel == nil then
                    saved.QualityLevel = rendering.QualityLevel
                end
                rendering.QualityLevel = Enum.QualityLevel.Level01
            elseif saved.QualityLevel ~= nil then
                rendering.QualityLevel = saved.QualityLevel
                saved.QualityLevel = nil
            end
        end)
    end

    -- what we compute: thinking 30 times a second is a luxury at 20 fps, and a
    -- dodge decided after the frame is drawn is worth nothing anyway
    function Smooth:SetRates(low)
        local saved = self.Saved
        if low then
            if saved.DodgeSolveInterval == nil then
                saved.DodgeSolveInterval = CONFIG.DodgeSolveInterval
                saved.HazardCacheInterval = CONFIG.HazardCacheInterval
            end
            CONFIG.DodgeSolveInterval = math.max(CONFIG.DodgeSolveInterval, 1 / 15)
            CONFIG.HazardCacheInterval = math.max(CONFIG.HazardCacheInterval, 1 / 15)
        elseif saved.DodgeSolveInterval ~= nil then
            CONFIG.DodgeSolveInterval = saved.DodgeSolveInterval
            CONFIG.HazardCacheInterval = saved.HazardCacheInterval
            saved.DodgeSolveInterval, saved.HazardCacheInterval = nil, nil
        end
    end

    function Smooth:Apply(level)
        if level == self.Level then
            return
        end
        self.Level = level
        self.Controller.SmoothLevel = level
        if level >= 1 then
            self:SetQuality(true)
        else
            self:SetQuality(false)
        end
        if level >= 2 then
            self:SetRates(true)
        else
            self:SetRates(false)
        end
    end

    function Smooth:Step(now)
        if not CONFIG.SmoothGuard then
            self:Apply(0)
            return
        end
        if now - self.LastSample < CONFIG.SmoothSampleTime then
            return
        end
        local seconds = now - self.LastSample
        self.Fps = self.Frames / math.max(seconds, 0.1)
        self.Frames = 0
        self.LastSample = now
        self.Controller.SmoothFps = math.floor(self.Fps)

        if self.Fps < CONFIG.SmoothLowFps then
            self.GoodSince = nil
            self:Apply(self.Fps < CONFIG.SmoothLowFps * 0.6 and 2 or math.max(self.Level, 1))
        elseif self.Fps >= CONFIG.SmoothGoodFps then
            self.GoodSince = self.GoodSince or now
            if self.Level > 0 and now - self.GoodSince >= CONFIG.SmoothHoldTime then
                self:Apply(self.Level - 1)
                self.GoodSince = now
            end
        else
            self.GoodSince = nil
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Smooth = Smooth.new(self)
        self.SmoothConn = RunService.RenderStepped:Connect(function()
            self.Smooth.Frames += 1
        end)
        return self
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Smooth then
            return
        end
        pcall(self.Smooth.Step, self.Smooth, os.clock())
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function()
            if self.SmoothConn then
                self.SmoothConn:Disconnect()
            end
            self.Smooth:Apply(0)
        end)
        return oldDestroy(self)
    end
end
-- v44.27: Northern Lands, first boss - the Midgardian Champion.
--
-- Everything here is gated on the dungeon name, so the Enchanted Forest keeps
-- the ranges and dodging it has now.
--
-- Measured live in the fight: the passive Dual Beams are models called
-- firstBossPassiveBeam whose hitBox is 250 x 8 x 64 and whose centre sits on
-- the pillar at the middle of the arena. Each beam is a diameter, not a ray -
-- it blocks the angle it points at and the opposite one - and they turn.
--
-- That geometry decides the whole fight. A turning beam sweeps past you at
-- (turn rate x your distance from the pillar), while the gap between two beams
-- lasts the same amount of time wherever you stand. Out at 72-144 studs, where
-- we were dying three pulses at a time, the beam edge moves far faster than we
-- can walk. In close, the same gap only asks for a few studs a second.
--
-- So the plan is: stand near the pillar, in the middle of the gap we are
-- already in, and turn with it. That is also directly under the boss, which is
-- where our damage wants to be.
do
    CONFIG.NLStandRadius = 26          -- studs from the pillar we aim to hold
    CONFIG.NLStandRadiusMax = 60       -- ...unless there is no floor that close
    CONFIG.NLBeamHalfWidth = 4         -- the hitBox is 8 wide
    CONFIG.NLBeamClearance = 5         -- body plus a margin
    CONFIG.NLSlamPad = 10              -- extra studs outside a jump slam circle
    CONFIG.NLStationSlack = 3          -- close enough, stop shuffling

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- the beams, as angles around their shared centre
    local function beamField()
        local pivot, angles = nil, {}
        for _, model in ipairs(Workspace:GetChildren()) do
            if model.Name == "firstBossPassiveBeam" then
                local box = model:FindFirstChild("hitBox", true)
                if box and box:IsA("BasePart") then
                    pivot = pivot or box.Position
                    local look = flatten(box.CFrame.LookVector)
                    if look.Magnitude > 0.01 then
                        local yaw = math.atan2(look.Z, look.X)
                        -- a diameter blocks both ends
                        table.insert(angles, yaw % (math.pi * 2))
                        table.insert(angles, (yaw + math.pi) % (math.pi * 2))
                    end
                end
            end
        end
        if not pivot or #angles == 0 then
            return nil
        end
        table.sort(angles)
        return pivot, angles
    end

    -- middle of the gap we are standing in, so reaching it never crosses a beam
    local function safeAngle(angles, mine)
        local count = #angles
        for index = 1, count do
            local from = angles[index]
            local to = angles[(index % count) + 1]
            local span = (to - from) % (math.pi * 2)
            local offset = (mine - from) % (math.pi * 2)
            if offset <= span then
                return (from + span * 0.5) % (math.pi * 2), span
            end
        end
        return mine, 0
    end

    local function pointAt(pivot, angle, radius)
        return Vector3.new(
            pivot.X + math.cos(angle) * radius,
            pivot.Y,
            pivot.Z + math.sin(angle) * radius
        )
    end

    -- a jump slam we are standing in: leave it, outwards is shortest
    function DodgeSolver:GetChampionSlamEscape()
        local root = self.CharacterService.Root
        if not root then
            return nil
        end
        local worst, worstPush = nil, 0
        for _, model in ipairs(Workspace:GetChildren()) do
            if model.Name == "firstBossJumpSlam" then
                local box = model:FindFirstChild("hitBox", true)
                if box and box:IsA("BasePart") then
                    local keepOut = math.max(box.Size.X, box.Size.Z) * 0.5 + CONFIG.NLSlamPad
                    local offset = flatten(root.Position - box.Position)
                    local push = keepOut - offset.Magnitude
                    if push > worstPush then
                        worst, worstPush = offset, push
                    end
                end
            end
        end
        if not worst then
            return nil
        end
        return worst.Magnitude > 0.5 and worst.Unit or Vector3.new(1, 0, 0)
    end

    -- where we want to be standing right now
    function DodgeSolver:GetChampionStation()
        local root = self.CharacterService.Root
        if not root then
            return nil
        end
        local pivot, angles = beamField()
        if not pivot then
            return nil
        end
        self.ChampionPivot = pivot

        local offset = flatten(root.Position - pivot)
        local mine = math.atan2(offset.Z, offset.X) % (math.pi * 2)
        local angle, span = safeAngle(angles, mine)

        -- a gap has to be wide enough to hold us at that radius
        local radius = CONFIG.NLStandRadius
        local needed = 2 * (math.asin(math.min(1,
            (CONFIG.NLBeamHalfWidth + CONFIG.NLBeamClearance) / math.max(radius, 1))))
        while span < needed and radius < CONFIG.NLStandRadiusMax do
            radius += 8
            needed = 2 * (math.asin(math.min(1,
                (CONFIG.NLBeamHalfWidth + CONFIG.NLBeamClearance) / math.max(radius, 1))))
        end

        -- and there has to be floor there
        local goal = nil
        for _, candidate in ipairs({ radius, radius + 10, radius + 20, radius + 34 }) do
            if candidate <= CONFIG.NLStandRadiusMax + 20 then
                local point = pointAt(pivot, angle, candidate)
                if self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding) then
                    goal = point
                    break
                end
            end
        end
        if not goal then
            goal = pointAt(pivot, angle, radius)
        end

        self.ChampionGoal = goal
        self.ChampionRadius = offset.Magnitude
        local delta = flatten(goal - root.Position)
        if delta.Magnitude <= CONFIG.NLStationSlack then
            return Vector3.zero
        end
        return delta.Unit
    end

    ---------------------------------------------------------------------------
    local oldSolveChampion = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if not inNorthernLands() or not self.CharacterService:IsAlive() then
            return oldSolveChampion(self, routeDirection, enemy, targetYaw)
        end

        -- a slam landing on our head beats everything else
        local okSlam, slam = pcall(self.GetChampionSlamEscape, self)
        if okSlam and slam then
            self.LastDodgeReason = "champion-slam"
            self.IsDodging = true
            self.CachedDirection = slam
            self.CachedYaw = targetYaw
            self.CachedDodging = true
            self.LastMovement = slam
            self.ChampionSlams = (self.ChampionSlams or 0) + 1
            return slam, targetYaw, true, true
        end

        local okStation, station = pcall(self.GetChampionStation, self)
        if okStation and station then
            self.LastDodgeReason = "champion-station"
            self.IsDodging = station.Magnitude > 0.05
            self.CachedDirection = station
            self.CachedYaw = targetYaw
            self.CachedDodging = self.IsDodging
            if station.Magnitude > 0.05 then
                self.LastMovement = station
            end
            self.ChampionHolds = (self.ChampionHolds or 0) + 1
            return station, targetYaw, false, self.IsDodging
        end

        return oldSolveChampion(self, routeDirection, enemy, targetYaw)
    end

    ---------------------------------------------------------------------------
    -- The Champion fights from the top of a pillar. A straight line from our
    -- chest to it clips the pillar, so the line-of-sight test said no and we
    -- stopped casting at the one boss we are standing right underneath - even
    -- though the game is happy to let the spell land.
    ---------------------------------------------------------------------------
    local oldLos = CombatController.HasLineOfSight
    function CombatController:HasLineOfSight(enemy)
        if enemy and enemy.Root and enemy.Root.Parent and isBossEnemy(enemy) and inNorthernLands() then
            local root = self.CharacterService.Root
            if root and enemy.Root.Position.Y > root.Position.Y + 6 then
                return true
            end
        end
        return oldLos(self, enemy)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.27-nl"
        return self
    end
end
-- EXPERIMENT (branch experiment-flatmap): flat boss arenas + sharper dodging.
--
-- In a boss fight the decoration around the arena (trees, rocks, bridges,
-- railings) is switched off on this client only: collisions off and hidden.
-- The floor is never touched, so there is nothing to fall through. With the
-- clutter gone every direction the dodge solver picks is actually walkable,
-- the frame rate goes up, and the hazard tracker gets more time per frame.
--
-- Everything is restored when the fight ends or the script is unloaded.
-- Toggle: "Flat Arena" in the Automation tab (getgenv().UIW.FlatArena).
do
    CONFIG.FlatArena = true
    CONFIG.FlatArenaRadius = 260          -- studs around the boss
    CONFIG.FlatArenaFloorBand = 5         -- anything whose top is this far above the floor is clutter
    CONFIG.FlatArenaMaxSize = 600         -- skip enormous parts (whole platforms)
    CONFIG.FlatArenaRescan = 2            -- seconds between sweeps
    CONFIG.FlatArenaBossRange = 300

    -- sharper reactions while the arena is flat
    CONFIG.FlatDodgeSolveInterval = 1 / 30
    CONFIG.FlatHazardCacheInterval = 1 / 30
    CONFIG.FlatPrecastLookaheadTime = 1.15
    CONFIG.FlatDangerLookaheadDistance = 16

    local FlatArena = {}
    FlatArena.__index = FlatArena

    function FlatArena.new(controller)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.MaxParts = 1200
        return setmetatable({
            Controller = controller,
            Active = false,
            Changed = {},          -- [part] = { CanCollide, Transparency }
            Count = 0,
            LastScan = 0,
            Params = params,
            Saved = nil,
        }, FlatArena)
    end

    function FlatArena:MapRoots()
        local roots = {}
        for _, name in ipairs({ "map", "Map" }) do
            local model = Workspace:FindFirstChild(name)
            if model then
                table.insert(roots, model)
            end
        end
        return roots
    end

    function FlatArena:FloorY()
        local root = self.Controller.Character.Root
        if not root then
            return nil
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { self.Controller.Character.Character }
        params.RespectCanCollide = true
        local hit = Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
        return hit and hit.Position.Y or (root.Position.Y - 3)
    end

    function FlatArena:Sweep(center)
        local roots = self:MapRoots()
        if #roots == 0 then
            return
        end
        local floorY = self:FloorY()
        if not floorY then
            return
        end
        self.Params.FilterDescendantsInstances = roots
        local ok, parts = pcall(function()
            return Workspace:GetPartBoundsInRadius(center, CONFIG.FlatArenaRadius, self.Params)
        end)
        if not ok or type(parts) ~= "table" then
            return
        end
        for _, part in ipairs(parts) do
            if part:IsA("BasePart")
                and not self.Changed[part]
                and part.CanCollide
                and part.Anchored                  -- moving parts are left alone
                and part.Size.Magnitude <= CONFIG.FlatArenaMaxSize
            then
                local half = part.Size.Y * 0.5
                local top = part.Position.Y + half
                local bottom = part.Position.Y - half
                -- clutter = stands above the floor and does not form the floor
                if top > floorY + CONFIG.FlatArenaFloorBand and bottom > floorY - 1 then
                    self.Changed[part] = {
                        CanCollide = part.CanCollide,
                        Transparency = part.Transparency,
                    }
                    self.Count += 1
                    pcall(function()
                        part.CanCollide = false
                        part.Transparency = 1
                    end)
                end
            end
        end
    end

    function FlatArena:Restore()
        for part, saved in pairs(self.Changed) do
            if part.Parent then
                pcall(function()
                    part.CanCollide = saved.CanCollide
                    part.Transparency = saved.Transparency
                end)
            end
        end
        self.Changed = {}
        self.Count = 0
    end

    function FlatArena:Enable()
        if self.Active then
            return
        end
        self.Active = true
        self.Saved = {
            DodgeSolveInterval = CONFIG.DodgeSolveInterval,
            HazardCacheInterval = CONFIG.HazardCacheInterval,
            PrecastLookaheadTime = CONFIG.PrecastLookaheadTime,
            DangerLookaheadDistance = CONFIG.DangerLookaheadDistance,
        }
        CONFIG.DodgeSolveInterval = CONFIG.FlatDodgeSolveInterval
        CONFIG.HazardCacheInterval = CONFIG.FlatHazardCacheInterval
        CONFIG.PrecastLookaheadTime = CONFIG.FlatPrecastLookaheadTime
        CONFIG.DangerLookaheadDistance = CONFIG.FlatDangerLookaheadDistance
        self.LastScan = 0
    end

    function FlatArena:Disable()
        if not self.Active then
            return
        end
        self.Active = false
        for key, value in pairs(self.Saved or {}) do
            CONFIG[key] = value
        end
        self.Saved = nil
        self:Restore()
    end

    function FlatArena:Step(now)
        if not self.Active then
            return
        end
        if now - self.LastScan < CONFIG.FlatArenaRescan then
            return
        end
        self.LastScan = now
        local enemy = self.Controller.CurrentEnemy
        local root = self.Controller.Character.Root
        local center = enemy and enemy.Root and enemy.Root.Parent and enemy.Root.Position
            or (root and root.Position)
        if center then
            self:Sweep(center)
        end
    end

    ---------------------------------------------------------------------------
    local function bossNearby(controller)
        local enemy = controller.CurrentEnemy
        local root = controller.Character.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end
        if not isBossEnemy(enemy) then
            return false
        end
        return (enemy.Root.Position - root.Position).Magnitude <= CONFIG.FlatArenaBossRange
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Flat = FlatArena.new(self)
        if self.FlatArena == nil then
            self.FlatArena = CONFIG.FlatArena
        end
        self.Version = "45-flat"
        local hud = self.HUD
        if hud and hud.AddToggleRow and hud.Pages and hud.Pages.Automation then
            hud.AddToggleRow(hud.Pages.Automation, 10, "Flat Arena (test)",
                "In boss fights: hides and un-solids the scenery, sharper dodging",
                function() return self.FlatArena ~= false end,
                function(value)
                    self.FlatArena = value
                    if not value then
                        self.Flat:Disable()
                    end
                end)
        end
        return self
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed then
            return
        end
        local now = os.clock()
        if now - (self.FlatCheckAt or 0) >= 0.5 then
            self.FlatCheckAt = now
            if self.FlatArena and self.Enabled and bossNearby(self) then
                self.FlatHoldUntil = now + 6
                self.Flat:Enable()
            elseif self.Flat.Active and now > (self.FlatHoldUntil or 0) then
                self.Flat:Disable()
            end
        end
        pcall(self.Flat.Step, self.Flat, now)
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function() self.Flat:Disable() end)
        return oldDestroy(self)
    end

    local oldApply = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.FlatArena) == "boolean" then
            self.FlatArena = settings.FlatArena
        end
        return oldApply(self, settings)
    end

    local oldGet = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGet(self)
        settings.FlatArena = self.FlatArena ~= false
        return settings
    end
end

-- EXPERIMENT (branch experiment-flatmap): time-based escape field.
--
-- The old dodge asks "is this direction clear right now?" and throws away any
-- direction that is not. Surrounded by six Battle Mage orbs every direction is
-- "not clear", so it froze and died. This one asks a different question for
-- every candidate spot around the character:
--
--     how long until that spot becomes dangerous, and can I get there first?
--
-- Each live attack is turned into a moving box (position, half size, speed).
-- For a spot we solve when the box will cover it (slab test along the box's
-- own axes), which gives the spot a "safe until" time. A spot is good when
-- safe-until is later than the time it takes to walk there. If nothing is
-- fully safe we take the spot that stays safe the longest instead of standing
-- still, which is what used to kill us.
do
    CONFIG.FieldDodge = true
    CONFIG.FieldHorizon = 2.4            -- seconds we look ahead
    CONFIG.FieldMargin = 0.35            -- extra seconds a spot must stay safe
    CONFIG.FieldRings = { 6, 11, 17, 24 }
    CONFIG.FieldBearings = 16
    CONFIG.FieldPadXZ = 2.0              -- body half width added to every box
    CONFIG.FieldPadY = 7
    -- The field is a rescue, not the driver. It used to take over 87-133 times
    -- in one boss fight, which is the script repositioning instead of standing
    -- and killing things - runs got slower even though deaths went down. These
    -- thresholds only let it speak up when the spot we are on is genuinely
    -- about to be hit and it has something clearly better.
    CONFIG.FieldRescueUnder = 0.45       -- our spot dies this soon
    CONFIG.FieldBetterBy = 0.8           -- ...and the new one is this much better
    CONFIG.FieldCommitTime = 0.35        -- keep a chosen escape instead of re-steering
    CONFIG.FieldPanicUnder = 0.18        -- about to land: re-steer anyway
    CONFIG.FieldCacheTime = 0.05
    CONFIG.FieldBusyBoxes = 40           -- past this many attacks we ease off
    CONFIG.FieldBusyCacheTime = 0.12
    CONFIG.FieldBusyBearings = 10
    CONFIG.FieldMaxBoxes = 48            -- hard ceiling, nearest kept
    CONFIG.FieldTimeBudget = 0.0015      -- seconds per solve, never more
    CONFIG.FieldSpinMinRate = math.rad(6)  -- slower than this counts as not turning
    CONFIG.FieldSpinMaxRate = math.rad(400)
    CONFIG.FieldSpinHorizon = 1.6          -- how far ahead a turning box is followed
    CONFIG.FieldSpinSteps = 8              -- fewest time samples for a turning box
    CONFIG.FieldSpinMaxSteps = 32          -- and the most, so one beam cannot eat a frame

    local Field = {}

    -- rotate around Y, +X towards +Z, the same sense as atan2(z, x)
    local function spinXZ(vector, radians)
        local c, s = math.cos(radians), math.sin(radians)
        return Vector3.new(
            vector.X * c - vector.Z * s,
            vector.Y,
            vector.X * s + vector.Z * c
        )
    end

    -- How fast a hazard part is turning. Sweeping beams (the golem's electrical
    -- cross, anything that rotates around an anchor) look like a harmless static
    -- wall to a straight-line model: they never move towards you, they turn into
    -- you. Measuring the turn is what makes them predictable.
    local spinTracks = setmetatable({}, { __mode = "k" })

    local function trackSpin(part, cf, now)
        local look = flatten(cf.LookVector)
        if look.Magnitude < 0.01 then
            return 0
        end
        local angle = math.atan2(look.Z, look.X)
        local info = spinTracks[part]
        if not info then
            spinTracks[part] = { Angle = angle, At = now, Omega = 0 }
            return 0
        end
        local dt = now - info.At
        if dt >= 0.03 then
            local delta = (angle - info.Angle + math.pi) % (math.pi * 2) - math.pi
            local measured = delta / dt
            if math.abs(measured) <= CONFIG.FieldSpinMaxRate then
                info.Omega = info.Omega * 0.5 + measured * 0.5
            end
            info.Angle, info.At = angle, now
        end
        if math.abs(info.Omega) < CONFIG.FieldSpinMinRate then
            return 0
        end
        return info.Omega
    end

    -- what a turning part turns around: its model's pivot, else itself
    local function pivotOf(part)
        local model = part.Parent
        if model and model:IsA("Model") then
            local ok, cf = pcall(model.GetPivot, model)
            if ok and cf then
                return cf.Position
            end
        end
        return part.Position
    end

    -- How far a box could possibly matter: we only ever ask about points on the
    -- rings around us, so anything that cannot reach the outermost ring inside
    -- the horizon is dropped before any maths is done on it. At the Ancient
    -- Tree this takes the list from ~138 boxes to a handful, which is the
    -- difference between 28 and 60 fps.
    local function ringReach()
        local most = 0
        for _, radius in ipairs(CONFIG.FieldRings) do
            most = math.max(most, radius)
        end
        return most
    end

    -- every live attack as { CF, HalfX, HalfZ, HalfY, V, Omega, Pivot }
    function Field.Collect(solver)
        local hazards = solver.Hazards
        local now = os.clock()
        local list = {}
        local root = solver.CharacterService and solver.CharacterService.Root
        local origin = root and root.Position or nil
        local rings = ringReach() + CONFIG.FieldPadXZ + 2
        for _, data in ipairs(hazards.CachedActive or {}) do
            local part = data.Part
            if part and part.Parent then
                local cf, half
                if data.WarningCF and data.WarningHalf then
                    cf, half = data.WarningCF, data.WarningHalf
                else
                    cf, half = part.CFrame, part.Size * 0.5
                end
                local velocity = flatten(hazards:GetProjectileVelocity(data))
                local omega = 0
                local pivot = nil
                local okSpin, measured = pcall(trackSpin, part, part.CFrame, now)
                if okSpin and measured ~= 0 then
                    omega = measured
                    pivot = pivotOf(part)
                    -- a turning hitbox has to be predicted from its live pose;
                    -- the frozen warning pose would be turned forward from the
                    -- wrong starting angle
                    cf, half = part.CFrame, part.Size * 0.5
                end
                local reach = nil
                if omega ~= 0 then
                    -- furthest the bar reaches from what it turns around, so a
                    -- point outside that circle can be rejected in two steps
                    local right = flatten(cf.RightVector) * (half.X + CONFIG.FieldPadXZ)
                    local ahead = flatten(cf.LookVector) * (half.Z + CONFIG.FieldPadXZ)
                    local middle = flatten(cf.Position - pivot)
                    reach = 0
                    for _, corner in ipairs({ middle + right + ahead, middle + right - ahead,
                                              middle - right + ahead, middle - right - ahead }) do
                        reach = math.max(reach, corner.Magnitude)
                    end
                end
                if origin then
                    local far
                    if pivot then
                        far = flatten(origin - pivot).Magnitude > (reach or 0) + rings
                    else
                        local span = half.Magnitude + velocity.Magnitude * CONFIG.FieldHorizon
                        far = flatten(origin - cf.Position).Magnitude > span + rings
                    end
                    if far then
                        continue
                    end
                end
                table.insert(list, {
                    CF = cf,
                    RMax = reach,
                    HX = half.X + CONFIG.FieldPadXZ,
                    HY = half.Y + CONFIG.FieldPadY,
                    HZ = half.Z + CONFIG.FieldPadXZ,
                    V = velocity,
                    Omega = omega,
                    Pivot = pivot,
                    Part = part,
                })
            end
        end
        if #list > CONFIG.FieldBusyBoxes then
            for _, box in ipairs(list) do
                box.Busy = true
            end
        end

        if origin and #list > CONFIG.FieldMaxBoxes then
            table.sort(list, function(a, b)
                return flatten(a.CF.Position - origin).Magnitude
                    < flatten(b.CF.Position - origin).Magnitude
            end)
            for index = #list, CONFIG.FieldMaxBoxes + 1, -1 do
                list[index] = nil
            end
        end

        return list
    end

    -- is `point` covered by the box as it will stand `t` seconds from now?
    -- Instead of turning the box we turn the point backwards around the pivot,
    -- which is the same test and needs no CFrame rebuilding.
    local function coveredAt(box, point, t)
        local p = point - box.V * t
        if box.Omega ~= 0 and box.Pivot then
            p = box.Pivot + spinXZ(p - box.Pivot, -box.Omega * t)
        end
        local relative = box.CF:PointToObjectSpace(p)
        return math.abs(relative.X) <= box.HX
            and math.abs(relative.Y) <= box.HY
            and math.abs(relative.Z) <= box.HZ
    end

    -- earliest time in [0, horizon] at which `point` is inside the box
    local function hitTime(box, point, horizon)
        -- a turning box cannot be solved with straight-line algebra, so walk the
        -- next couple of seconds in steps and take the first step that covers us
        if box.Omega ~= 0 and box.Pivot then
            local radius = flatten(point - box.Pivot).Magnitude
            if radius > (box.RMax or math.huge) then
                return nil          -- the beam cannot reach this far out
            end
            -- The step has to be short enough that the point cannot cross the
            -- bar between two samples, or a thin fast beam is stepped straight
            -- over and reported as safe.
            local sweep = math.abs(box.Omega) * math.max(radius, 1)   -- studs per second
            local span = math.min(horizon, CONFIG.FieldSpinHorizon)
            local step = math.min(span / CONFIG.FieldSpinSteps, math.max(box.HX, 0.5) / math.max(sweep, 0.01))
            local ceiling = box.Busy and 12 or CONFIG.FieldSpinMaxSteps
            local steps = math.clamp(math.ceil(span / step), CONFIG.FieldSpinSteps, ceiling)
            step = span / steps
            for index = 0, steps do
                if coveredAt(box, point, index * step) then
                    return math.max((index - 1) * step, 0)
                end
            end
            return nil
        end

        local relative = box.CF:PointToObjectSpace(point)
        if math.abs(relative.Y) > box.HY then
            return nil
        end
        local speed = box.V.Magnitude
        if speed < 0.5 then
            if math.abs(relative.X) <= box.HX and math.abs(relative.Z) <= box.HZ then
                return 0
            end
            return nil
        end
        -- in the box's frame the point drifts at -V
        local drift = box.CF:VectorToObjectSpace(-box.V)
        local enter, exit = 0, horizon
        for _, axis in ipairs({ { relative.X, drift.X, box.HX }, { relative.Z, drift.Z, box.HZ } }) do
            local position, velocity, half = axis[1], axis[2], axis[3]
            if math.abs(velocity) < 0.01 then
                if math.abs(position) > half then
                    return nil
                end
            else
                local t1 = (-half - position) / velocity
                local t2 = (half - position) / velocity
                if t1 > t2 then
                    t1, t2 = t2, t1
                end
                enter = math.max(enter, t1)
                exit = math.min(exit, t2)
                if enter > exit then
                    return nil
                end
            end
        end
        if enter > horizon or exit < 0 then
            return nil
        end
        return math.max(enter, 0)
    end

    function Field.SafeUntil(boxes, point, horizon)
        local best = horizon
        for _, box in ipairs(boxes) do
            local t = hitTime(box, point, horizon)
            if t and t < best then
                best = t
                if best <= 0 then
                    return 0
                end
            end
        end
        return best
    end

    -- the spot we would like to stand on: keeps the target in cast range
    local function preferredSpot(solver, origin)
        local enemy = solver.CurrentSolveEnemy
        if not enemy or not enemy.Root or not enemy.Root.Parent then
            return nil
        end
        local delta = flatten(origin - enemy.Root.Position)
        local distance = delta.Magnitude
        if distance < 1 then
            return nil
        end
        local want
        if isBossEnemy(enemy) then
            want = math.clamp(distance, CONFIG.BossMinRange, CONFIG.BossMaxRange)
        else
            want = math.clamp(distance, CONFIG.MobBurstRange * 0.6, CONFIG.MobBurstRange)
        end
        return enemy.Root.Position + delta.Unit * want
    end

    function Field.Solve(solver, preferred, targetYaw)
        local character = solver.CharacterService
        local root = character.Root
        if not root then
            return nil
        end
        local now = os.clock()
        local cached = solver.FieldCache
        local busy = cached and cached.Result and (cached.Result.Boxes or 0) > CONFIG.FieldBusyBoxes
        local interval = busy and CONFIG.FieldBusyCacheTime or CONFIG.FieldCacheTime
        if cached and now - cached.At < interval then
            return cached.Result
        end

        local origin = root.Position
        local horizon = CONFIG.FieldHorizon
        local boxes = Field.Collect(solver)
        local speed = math.max(character.Humanoid and character.Humanoid.WalkSpeed or CONFIG.WalkSpeed, 8)
        local hereSafe = Field.SafeUntil(boxes, origin, horizon)
        local spot = preferredSpot(solver, origin)

        local best, bestScore
        local bearings = (#boxes > CONFIG.FieldBusyBoxes)
            and CONFIG.FieldBusyBearings
            or CONFIG.FieldBearings
        -- A solve must never be allowed to eat a frame. At the Forest Dragon,
        -- 48 turning attacks x 40 candidate spots took the game to 6 fps, and a
        -- dodge computed too late is worth nothing anyway. When the budget runs
        -- out we keep the best spot found so far and move on.
        local startedAt = os.clock()
        local outOfTime = false
        for _, radius in ipairs(CONFIG.FieldRings) do
            if outOfTime then
                break
            end
            for i = 0, bearings - 1 do
                if os.clock() - startedAt > CONFIG.FieldTimeBudget then
                    outOfTime = true
                    break
                end
                local direction = unit(rotateXZ(Vector3.new(1, 0, 0), i * 360 / bearings))
                local point = origin + direction * radius
                local safe = Field.SafeUntil(boxes, point, horizon)
                local arrival = radius / speed
                local margin = safe - arrival
                if margin > 0 then
                    local score = math.min(margin, 1.6) * 120
                    score -= radius * 1.2
                    if spot then
                        score -= flatten(point - spot).Magnitude * 1.5
                    elseif preferred and preferred.Magnitude > 0 then
                        score += direction:Dot(preferred) * 25
                    end
                    if solver.LastMovement and solver.LastMovement.Magnitude > 0 then
                        score += direction:Dot(solver.LastMovement) * 15
                    end
                    if (not bestScore or score > bestScore) then
                        -- only now pay for the walk / ground checks
                        if solver.Geometry:IsDirectionClear(direction, radius, targetYaw)
                            and solver.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding)
                        then
                            best = { Direction = direction, Radius = radius, Safe = safe, Margin = margin, Point = point }
                            bestScore = score
                        end
                    end
                end
            end
        end

        local result = { HereSafe = hereSafe, Best = best, Boxes = #boxes, List = boxes }
        solver.FieldCache = { At = now, Result = result }
        return result
    end

    ---------------------------------------------------------------------------
    -- Take over only when the old solver is about to leave us somewhere that
    -- dies sooner than what the field found.
    ---------------------------------------------------------------------------
    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolve(self, routeDirection, enemy, targetYaw)

        -- how much of the fight we spend being pushed around, so "is it slower?"
        -- can be answered with a number instead of a feeling
        local clock = os.clock()
        local since = clock - (self.DodgeClock or clock)
        self.DodgeClock = clock
        if since < 0.5 then
            self.SecondsAlive = (self.SecondsAlive or 0) + since
            if dodging then
                self.SecondsDodging = (self.SecondsDodging or 0) + since
            end
        end

        local owner = self.Owner
        if owner and owner.FieldDodge == false then
            return direction, yaw, emergency, dodging
        end
        if not CONFIG.FieldDodge or self.ForceRouteMovement then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        if not root or not self.CharacterService:IsAlive() then
            return direction, yaw, emergency, dodging
        end

        -- The Crystal Golem's sweeper planner deliberately stands still inside a
        -- crystal shelter, and the field would read that stillness as "about to
        -- be hit" and walk us out of it. That hold is worth protecting.
        -- Its *moving* answers are not: measured live, we took four ticks of
        -- 40% while standing 11 studs inside a turning bar with that planner in
        -- control. On those frames the field is allowed to argue, now that it
        -- can predict a turning attack.
        -- champion-slam is an escape from a circle we are standing in, and
        -- champion-station only moves a few studs inside a beam gap: both are
        -- already the right answer, but the station is still allowed to be
        -- overruled below if the field finds it is about to be hit.
        if self.LastDodgeReason == "golem-dome"
            or self.LastDodgeReason == "champion-slam"
            or (self.LastDodgeReason == "golem-sweeper-spin" and self.GolemSafeSpotHolding)
        then
            return direction, yaw, emergency, dodging
        end

        -- Same for any mechanic that pins us to a region (cleanse bubble, built
        -- wall): staying inside it is the point.
        if self.ForcedRegionPart and self:IsPointInsideForcedRegion(root.Position) then
            return direction, yaw, emergency, dodging
        end

        local result = Field.Solve(self, routeDirection, targetYaw)
        if not result then
            return direction, yaw, emergency, dodging
        end

        self.FieldHereSafe = result.HereSafe
        if result.HereSafe > CONFIG.FieldRescueUnder then
            return direction, yaw, emergency, dodging   -- we are fine where we are
        end

        -- Stick with an escape we already committed to instead of picking a new
        -- direction every frame; the constant re-steering is what ate the clock.
        local now = os.clock()
        if self.FieldCommitDir
            and now < (self.FieldCommitUntil or 0)
            and result.HereSafe > CONFIG.FieldPanicUnder
        then
            self.LastDodgeReason = "field"
            self.CachedDirection = self.FieldCommitDir
            self.CachedDodging = true
            self.IsDodging = true
            return self.FieldCommitDir, targetYaw, false, true
        end

        local best = result.Best
        if not best then
            return direction, yaw, emergency, dodging
        end

        -- how long would the old choice keep us alive?
        local oldSafe = 0
        if direction and direction.Magnitude > 0.05 then
            local step = math.min(CONFIG.DodgeDistance, best.Radius)
            local point = root.Position + unit(flatten(direction)) * step
            oldSafe = Field.SafeUntil(result.List, point, CONFIG.FieldHorizon)
                - step / math.max(self.CharacterService.Humanoid.WalkSpeed, 8)
        end

        if best.Margin > oldSafe + CONFIG.FieldBetterBy then
            self.FieldTakeovers = (self.FieldTakeovers or 0) + 1
            self.FieldCommitDir = best.Direction
            self.FieldCommitUntil = now + CONFIG.FieldCommitTime
            self.LastDodgeReason = "field"
            self.CachedDirection = best.Direction
            self.CachedDodging = true
            self.IsDodging = true
            self.LastMovement = best.Direction
            return best.Direction, targetYaw, false, true
        end

        return direction, yaw, emergency, dodging
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "45-flat+field"
        if self.FieldDodge == nil then
            self.FieldDodge = true
        end
        local hud = self.HUD
        if hud and hud.AddToggleRow and hud.Pages and hud.Pages.Automation then
            hud.AddToggleRow(hud.Pages.Automation, 11, "Field Dodge (test)",
                "Escapes by how long a spot stays safe; turn off for the older dodge",
                function() return self.FieldDodge ~= false end,
                function(value) self.FieldDodge = value end)
        end
        return self
    end

    local oldApplyField = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.FieldDodge) == "boolean" then
            self.FieldDodge = settings.FieldDodge
        end
        return oldApplyField(self, settings)
    end

    local oldGetField = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGetField(self)
        settings.FieldDodge = self.FieldDodge ~= false
        return settings
    end
end

-- v44.26: stop walking forward, back, forward.
--
-- Measured live: 24 direction reversals a minute, and in the bad moments four
-- of them inside 1.4 seconds - flips 0.10 s, 0.33 s, 0.11 s, 0.12 s apart, with
-- the reason changing each time (hitbox -> none -> aura -> committed). No single
-- planner is at fault: each one is answering sensibly on its own, and the
-- character ends up rocking on the spot between them, taking damage it could
-- have walked away from and dealing none of its own.
--
-- This is the last word on movement, after every other planner has spoken. A
-- direction that reverses the one we are already walking is only allowed when
-- it is a real emergency; otherwise we keep going, or step sideways if the new
-- answer really does disagree. Sideways beats rocking: it still leaves the old
-- lane, and it never undoes the distance already covered.
do
    CONFIG.FlipGuard = true
    CONFIG.FlipGuardWindow = 0.45      -- a direction is protected for this long
    CONFIG.FlipGuardDot = -0.35        -- more opposed than this counts as a reversal
    CONFIG.FlipGuardProbe = 10         -- studs checked before stepping sideways

    local function sideStep(solver, oldDirection, newDirection, targetYaw)
        -- the two ways round: pick the one the new answer leans towards
        local left = Vector3.new(-oldDirection.Z, 0, oldDirection.X)
        local right = Vector3.new(oldDirection.Z, 0, -oldDirection.X)
        local first, second = left, right
        if newDirection:Dot(right) > newDirection:Dot(left) then
            first, second = right, left
        end
        for _, candidate in ipairs({ first, second }) do
            local direction = unit(flatten(candidate))
            if direction.Magnitude > 0
                and solver.Geometry:IsDirectionClear(direction, CONFIG.FlipGuardProbe, targetYaw)
                and solver.Geometry:IsGroundPadded(
                    solver.CharacterService.Root.Position + direction * CONFIG.FlipGuardProbe,
                    CONFIG.EdgeHardPadding)
            then
                return direction
            end
        end
        return nil
    end

    local oldSolveFlip = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolveFlip(self, routeDirection, enemy, targetYaw)

        if not CONFIG.FlipGuard or not direction or direction.Magnitude <= 0.05 then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        if not root then
            return direction, yaw, emergency, dodging
        end

        local now = os.clock()
        local moving = unit(flatten(direction))
        local held = self.FlipGuardDir

        if held and now - (self.FlipGuardAt or 0) <= CONFIG.FlipGuardWindow
            and moving:Dot(held) < CONFIG.FlipGuardDot
        then
            -- A genuine emergency is allowed to turn us straight round - but
            -- only once. Measured at the Ancient Tree, its sweeper planner
            -- flagged an emergency and reversed three times inside 0.3 s, which
            -- is rocking on the spot, not escaping. After the second reversal in
            -- half a second we stop honouring it and step sideways instead.
            local recent = (now - (self.FlipBurstAt or 0) <= 0.6) and (self.FlipBurst or 0) or 0
            if emergency and recent < 2 then
                self.FlipBurst, self.FlipBurstAt = recent + 1, now
                self.FlipGuardDir, self.FlipGuardAt = moving, now
                self.FlipsAllowed = (self.FlipsAllowed or 0) + 1
                return direction, yaw, emergency, dodging
            end
            self.FlipBurst, self.FlipBurstAt = recent + 1, now

            local sideways = sideStep(self, held, moving, targetYaw)
            local kept = sideways or held
            self.FlipsBlocked = (self.FlipsBlocked or 0) + 1
            self.CachedDirection = kept
            self.LastMovement = kept
            if sideways then
                -- a sideways answer becomes the new lane to protect
                self.FlipGuardDir, self.FlipGuardAt = sideways, now
            end
            return kept, yaw, emergency, dodging
        end

        self.FlipGuardDir, self.FlipGuardAt = moving, now
        return direction, yaw, emergency, dodging
    end
end
-- Northern Lands only. Warning lifetime, not model lifetime, defines a beam.
-- Keep this layer after the general field and anti-reversal planners.
do
    CONFIG.NLGapClearance = 9      -- beam half width plus a body
    CONFIG.NLMinRadius = 28        -- closest we stand to the pillar
    CONFIG.NLMaxRadius = 135       -- and the furthest, for Sun-Burst
    CONFIG.NLCastRadius = 60       -- inside this we can still hit the boss (range 64)
    CONFIG.NLWalkCost = 0.06       -- studs of walking traded against studs of closeness
    CONFIG.NLSafety = 1.2          -- stand this much past the bare minimum radius
    CONFIG.NLBurstLead = 1.4       -- seconds of beam spawning we look ahead
    CONFIG.NLBurstAlarmEnds = 10   -- this many blocked angles means Sun-Burst is starting
    CONFIG.NLBurstHold = 7         -- once it starts, commit to the run for this long

    local function northern()
        local d = Workspace:FindFirstChild("dungeonName")
        return d and d.Value == "Northern Lands"
    end
    -- Room 2 is not the final boss room, so the generic classifier missed the
    -- Champion. This also prevented the elevated-boss line-of-sight exception.
    local boss = isBossEnemy
    isBossEnemy = function(enemy)
        if northern() and enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "midgardian champion" then
            return true
        end
        return boss(enemy)
    end
    local timed = {firstBossPassiveBeam=true, firstBossJumpSlam=true, spearmanStrikeHitbox=true,
        northernMageShot=true, northernWarriorCircleStrike=true}
    local windup = {firstBossPassiveBeam=1.0, firstBossJumpSlam=2.0}
    local moving = {northernMageShot=true, firstBossSeekingSpikes=true,
        firstBossWhirlwind=true, firstBossWhirlWind=true, spearmanStrike=true}
    local tracks = setmetatable({}, {__mode="k"})
    local function live(container, now)
        local box = container:FindFirstChild("hitBox", true)
        if not box and container:IsA("BasePart") then box = container end
        if not box or not box:IsA("BasePart") then return nil end
        local info = tracks[container]
        if not info then
            local look=flatten(box.CFrame.LookVector)
            info = {At=now, Position=box.Position, Velocity=Vector3.zero, Seen=now, Visible=now,
                Angle=math.atan2(look.Z,look.X),Omega=0}
            tracks[container] = info
        end
        local dt = now - info.At
        if dt >= 0.025 then
            local velocity = (box.Position-info.Position)/dt
            if velocity.Magnitude < 450 then info.Velocity = velocity else info.Velocity=Vector3.zero end
            local look=flatten(box.CFrame.LookVector)
            local angle=math.atan2(look.Z,look.X)
            local omega=((angle-info.Angle+math.pi)%(2*math.pi)-math.pi)/dt
            info.Omega=math.abs(omega)<7 and omega or 0
            info.Angle=angle
            info.At, info.Position = now, box.Position
        end
        local pre = container:FindFirstChild("precast", true)
        if pre and pre:IsA("BasePart") and pre.Transparency < 0.98 then
            info.Visible = now
            info.HadWarning = true
        end
        if timed[container.Name] and info.HadWarning and now-info.Visible > 0.30 then return nil end
        if timed[container.Name] and not info.HadWarning and now-info.Seen > 0.30 then return nil end
        return box, info
    end

    -- These attacks can outlive a nearby mob. Nearest-enemy inference had
    -- attributed mage shots to warriors and deleted them when the warrior died.
    local register = HazardTracker.Register
    function HazardTracker:Register(part)
        register(self, part)
        if not northern() then return end
        local data = (self.FullHazards or self.Hazards)[part]
        if data and data.Container and (moving[data.Container.Name] or timed[data.Container.Name]) then
            data.SourceEnemyModel, data.SourceEnemyHumanoid = nil, nil
        end
    end
    local active = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        if northern() and container and container.Parent and timed[container.Name] then
            return live(container, now or os.clock()) ~= nil
        end
        return active(self, container, now)
    end

    -- The old Champion station scanned every lingering beam, including spent
    -- warnings. Its unvalidated slam direction could also cross a live beam.
    local oldStation, oldSlam = DodgeSolver.GetChampionStation, DodgeSolver.GetChampionSlamEscape
    function DodgeSolver:GetChampionStation(...)
        if northern() then return nil end
        return oldStation(self, ...)
    end
    function DodgeSolver:GetChampionSlamEscape(...)
        if northern() then return nil end
        return oldSlam(self, ...)
    end

    local function collect(self, now)
        local root = self.CharacterService.Root
        local list, seen, beams = {}, {}, {}
        local function add(part, velocity, name, omega, info)
            if seen[part] then return end
            seen[part] = true
            local cf, half = part.CFrame, part.Size*0.5
            if (part.Position-root.Position).Magnitude > half.Magnitude+130 then return end
            local pad=name=="firstBossJumpSlam" and 16 or 5
            list[#list+1] = {CF=cf, Half=half+Vector3.new(pad,3,pad), V=velocity, Omega=omega or 0,
                Starts=0,
                Ends=info and windup[name] and math.max(0.3,windup[name]+0.5-(now-info.Seen)) or math.huge,
                Name=name, Distance=(part.Position-root.Position).Magnitude-half.Magnitude}
        end
        for _,container in ipairs(Workspace:GetChildren()) do
            if timed[container.Name] or moving[container.Name] then
                local part, info = live(container, now)
                if part then
                    add(part, timed[container.Name] and Vector3.zero or info.Velocity, container.Name, info.Omega, info)
                    if container.Name == "firstBossPassiveBeam" then beams[#beams+1]=part end
                end
            end
        end
        for _,data in ipairs(self.Hazards:GetActive()) do
            local part, container = data.Part, data.Container
            if part and part.Parent and not data.IsPrecast and not (container and timed[container.Name]) then
                add(part, self.Hazards:GetProjectileVelocity(data), container and container.Name or part.Name)
            end
        end
        table.sort(list, function(a,b) return a.Distance < b.Distance end)
        while #list > 32 do table.remove(list) end
        return list, beams
    end
    local function risk(list, position, time)
        local score = 0
        for _,box in ipairs(list) do
            if time<box.Starts or time>box.Ends then continue end
            local cf=box.CF
            if math.abs(box.Omega)>0.02 then
                cf=CFrame.new(cf.Position)*CFrame.Angles(0,-box.Omega*time,0)*(cf-cf.Position)
            end
            local p=cf:PointToObjectSpace(position-box.V*time)
            local half=box.Half
            if math.abs(p.Y)<=half.Y then
                local dx,dz=math.abs(p.X)-half.X,math.abs(p.Z)-half.Z
                if dx<=0 and dz<=0 then score += (100+math.min(-dx,-dz)*2)*(box.Name=="firstBossJumpSlam" and 4 or 1)
                else score += math.max(0,4-math.max(dx,dz))*0.4 end
            end
        end
        return score
    end
    local solve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, yaw)
        if not northern() or not self.CharacterService:IsAlive() then return solve(self,routeDirection,enemy,yaw) end
        local now=os.clock()
        if now-(self.NLAt or 0)<0.045 and self.NLDirection then
            return self.NLDirection,yaw,self.NLEmergency,self.NLDodging
        end
        local root=self.CharacterService.Root
        local list,beams=collect(self,now)
        local champion=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="midgardian champion"
        local preferred=unit(flatten(routeDirection or Vector3.zero))
        local goal
        if champion then
            -- Every beam is a diameter through the pillar, so it blocks the
            -- angle it points at and the opposite one. How far out we have to
            -- stand is set by how many are lit at once: half the gap we sit in
            -- has to subtend the beam's half width plus our body.
            --   3 lit beams  -> 18 studs is enough, stay close and keep casting
            --   12 lit beams -> 69 studs
            --   23 lit beams (Sun-Burst) -> 132 studs, get out
            -- A fixed 46 was only ever right for about 7, which is why we died
            -- at 57-74 studs during Sun-Burst with 22 beams up.
            self.NLPivot = (#beams > 0) and beams[1].Position or self.NLPivot
            local pivot = self.NLPivot
            if pivot then
                local flatPivot = Vector3.new(pivot.X, root.Position.Y, pivot.Z)
                local offset = flatten(root.Position - flatPivot)
                local mine = math.atan2(offset.Z, offset.X) % (2 * math.pi)
                local ends = {}
                for _, part in ipairs(beams) do
                    local look = flatten(part.CFrame.LookVector)
                    if look.Magnitude > 0.01 then
                        local yaw = math.atan2(look.Z, look.X)
                        ends[#ends + 1] = yaw % (2 * math.pi)
                        ends[#ends + 1] = (yaw + math.pi) % (2 * math.pi)
                    end
                end
                -- Sun-Burst is a spawn-rate spike, so react to how fast beams
                -- are appearing rather than waiting until we are surrounded.
                -- Walking from 40 studs out to 130 takes about four seconds; by
                -- the time the count alone says "run", it is already too late.
                self.NLSeen = self.NLSeen or {}
                local fresh = 0
                for _, part in ipairs(beams) do
                    if not self.NLSeen[part] then
                        self.NLSeen[part] = now
                        fresh += 1
                    end
                end
                for part, at in pairs(self.NLSeen) do
                    if now - at > 1 then self.NLSeen[part] = nil end
                end
                self.NLRate = (self.NLRate or 0) * 0.6 + fresh * 0.4
                local lead = math.floor(self.NLRate * CONFIG.NLBurstLead * 2)

                -- Every gap is a candidate. The one we stand in is not
                -- automatically the best: a wider gap elsewhere may let us
                -- stand close enough to keep casting, and the path scoring
                -- below decides whether we can safely get there.
                local angle, span, radius = mine, math.pi * 2, CONFIG.NLMinRadius
                if #ends > 0 then
                    table.sort(ends)
                    local bestCost = math.huge
                    for i = 1, #ends do
                        local from = ends[i]
                        local width = (ends[(i % #ends) + 1] - from) % (2 * math.pi)
                        if width <= 0.0001 then width = 2 * math.pi end
                        local middle = (from + width * 0.5) % (2 * math.pi)
                        -- the bare minimum radius puts us exactly on the edge of
                        -- the beam, so stand a fifth further out than that
                        local need = CONFIG.NLGapClearance / math.max(math.sin(width * 0.5), 0.02)
                        local r = math.clamp(math.max(need * CONFIG.NLSafety, CONFIG.NLMinRadius),
                            CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                        -- how far round the circle we would have to walk
                        local turn = math.abs((middle - mine + math.pi) % (2 * math.pi) - math.pi)
                        local walk = turn * math.max(offset.Magnitude, r) + math.abs(offset.Magnitude - r)
                        local cost = r + walk * CONFIG.NLWalkCost
                        -- only chase a shooting position that still has room in
                        -- it, not one we only just fit into
                        if r <= CONFIG.NLCastRadius then
                            cost -= 25
                        end
                        if cost < bestCost then
                            bestCost, angle, span, radius = cost, middle, width, r
                        end
                    end
                end

                -- and if beams are pouring in, stand where the count is heading
                if lead > 0 then
                    local ahead = #ends + lead
                    local packed = CONFIG.NLGapClearance / math.max(math.sin(math.pi / ahead), 0.02)
                    radius = math.clamp(math.max(radius, packed), CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                end

                -- Sun-Burst is a four second walk, not a dodge. Every hit we
                -- took in it was while still moving, 49 to 70 studs short of
                -- where we were heading: the run was starting too late and,
                -- worse, kept being called off whenever a couple of beams
                -- expired and the count briefly looked survivable again.
                -- So the moment the count crosses the alarm we commit and keep
                -- going, and the beams themselves only reach 125 studs out.
                if #ends >= CONFIG.NLBurstAlarmEnds or lead >= 4 then
                    self.NLBurstUntil = now + CONFIG.NLBurstHold
                end
                if now < (self.NLBurstUntil or 0) then
                    radius = CONFIG.NLMaxRadius
                    self.NLBursting = true
                else
                    self.NLBursting = false
                end
                self.NLWantRadius, self.NLGapDegrees = radius, math.deg(span)
                self.NLLead = lead
                goal = flatPivot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
                preferred = unit(flatten(goal - root.Position))
            end
        end
        local standing=risk(list,root.Position,0)+risk(list,root.Position,0.3)+risk(list,root.Position,0.65)
            +risk(list,root.Position,1.0)+risk(list,root.Position,1.5)
        if not goal and standing<1 then
            self.NLDirection=nil
            return solve(self,routeDirection,enemy,yaw)
        end
        local speed=math.max(self.CharacterService.Humanoid.WalkSpeed,8)
        local horizon=champion and 1.5 or 0.65
        local times=champion and {0.15,0.4,0.7,1.0,1.25,1.5} or {0.12,0.3,0.5,0.65}
        local melee={}
        if not champion then
            for _,e in ipairs(self.Dungeon and self.Dungeon:GetAliveEnemies() or {}) do
                if e.Root and e.Root.Parent and getEnemyThreatClass(e)=="Melee" then
                    melee[#melee+1]=e.Root.Position
                end
            end
        end
        local best,bestScore=nil,math.huge
        for i=0,16 do
            local angle=i*math.pi/8
            local dir=i==16 and Vector3.zero or Vector3.new(math.cos(angle),0,math.sin(angle))
            local distance=speed*horizon
            if dir.Magnitude==0 or (self.Geometry:IsDirectionClear(dir,distance,yaw)
                and self.Geometry:IsGroundPadded(root.Position+dir*distance,CONFIG.EdgeHardPadding)) then
                local score=0
                for _,t in ipairs(times) do
                    local position=root.Position+dir*speed*t
                    score+=risk(list,position,t)
                    for _,mob in ipairs(melee) do
                        score+=math.max(0,34-flatten(position-mob).Magnitude)*8
                    end
                end
                if goal then score+=flatten(root.Position+dir*distance-goal).Magnitude*0.3
                else score-=dir:Dot(preferred)*4 end
                if self.NLDirection then score+=(1-dir:Dot(self.NLDirection))*1.5 end
                if score<bestScore then best,bestScore=dir,score end
            end
        end
        if not best then self.NLDirection=nil return solve(self,routeDirection,enemy,yaw) end
        self.NLAt,self.NLDirection=now,best
        self.NLEmergency,self.NLDodging=standing>=100,best.Magnitude>0.05
        self.LastDodgeReason=champion and "nl-champion-live" or "nl-mob-live"
        self.LastSolve=now
        self.CachedDirection,self.CachedYaw,self.CachedDodging=best,yaw,self.NLDodging
        self.IsDodging=self.NLDodging
        if self.NLDodging then self.LastMovement=best end
        self.NLLiveBoxes,self.NLLiveBeams=#list,#beams
        return best,yaw,self.NLEmergency,self.NLDodging
    end
end

local Controller = UIWController.new()

getgenv().UIW = Controller
getgenv().UNDERWORLD_AI = Controller

print("[UIW] NavigationV2-v44.20 loaded | persistent mob combos + safe-spot hold")

Controller:Start()

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
