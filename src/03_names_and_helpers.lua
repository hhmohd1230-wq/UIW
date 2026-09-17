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

