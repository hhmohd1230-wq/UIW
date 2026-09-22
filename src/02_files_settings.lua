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
-- Each Roblox account owns its configs and startup choices. Do not silently
-- import the old shared files: that would copy one account's settings to alts.
---------------------------------------------------------------------------
local ACCOUNT_FOLDER = SETTINGS_FOLDER .. "/accounts/" .. tostring(LocalPlayer.UserId)
local ConfigStore = {
    AccountFolder = ACCOUNT_FOLDER,
    Folder = ACCOUNT_FOLDER .. "/configs",
    MetaFile = ACCOUNT_FOLDER .. "/uiw_meta.json",
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

function ConfigStore.EnsureAccountFolder()
    SafeFile.EnsureFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then
        return
    end
    for _, path in ipairs({ SETTINGS_FOLDER .. "/accounts", ConfigStore.AccountFolder }) do
        local ok, exists = pcall(isfolder, path)
        if not (ok and exists) then pcall(makefolder, path) end
    end
end

function ConfigStore.EnsureFolder()
    ConfigStore.EnsureAccountFolder()
    if type(isfolder) ~= "function" or type(makefolder) ~= "function" then return end
    local ok, exists = pcall(isfolder, ConfigStore.Folder)
    if not (ok and exists) then pcall(makefolder, ConfigStore.Folder) end
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

-- Legacy files had no account owner. Import them only when the player asks.
function ConfigStore.ImportLegacy()
    local copied = 0
    local function copy(name, path)
        if ConfigStore.CleanName(name) ~= name or ConfigStore.Exists(name) then return end
        local data = SafeFile.ReadJson(path)
        if data and ConfigStore.Save(name, data) then copied += 1 end
    end
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, SETTINGS_FOLDER .. "/configs")
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = string.match(tostring(path), "([^/\\]+)%.json$")
                if name then copy(name, path) end
            end
        end
    end
    copy("default", SETTINGS_FILE)
    return copied
end

function ConfigStore.ReadMeta()
    local meta = SafeFile.ReadJson(ConfigStore.MetaFile) or {}
    local blackScreen
    if type(meta.BlackScreen) == "boolean" then
        blackScreen = meta.BlackScreen
    end
    local restoreCap = tonumber(meta.RestoreFPSCap)
    if not restoreCap or restoreCap < 1 or restoreCap > 10000 then
        restoreCap = nil
    end
    return {
        AutoLoad = type(meta.AutoLoad) == "string" and meta.AutoLoad or "",
        AutoExecute = meta.AutoExecute == true,
        ScriptPath = type(meta.ScriptPath) == "string" and meta.ScriptPath or nil,
        BlackScreen = blackScreen,
        RestoreFPSCap = restoreCap,
        CarryEnabled = meta.CarryEnabled == true,
        CarryHostName = type(meta.CarryHostName) == "string" and meta.CarryHostName or "",
        CarryAlts = type(meta.CarryAlts) == "string" and meta.CarryAlts or "",
        CarryMode = meta.CarryMode == "Fixed" and "Fixed" or "Auto",
        CarryFixedStage = tonumber(meta.CarryFixedStage) or 1,
        CarryHardcore = meta.CarryHardcore == true,
        CarryRunStage = tonumber(meta.CarryRunStage),
        HealerEnabled = meta.HealerEnabled == true,
        HealerTargetName = type(meta.HealerTargetName) == "string" and meta.HealerTargetName or "",
        HealerAutoEquip = meta.HealerAutoEquip ~= false,
        HealerFollowDistance = tonumber(meta.HealerFollowDistance) or 14,
    }
end

function ConfigStore.WriteMeta(meta)
    ConfigStore.EnsureAccountFolder()
    return SafeFile.WriteJson(ConfigStore.MetaFile, {
        AutoLoad = meta.AutoLoad or "",
        AutoExecute = meta.AutoExecute == true,
        ScriptPath = meta.ScriptPath,
        BlackScreen = meta.BlackScreen == true,
        RestoreFPSCap = meta.RestoreFPSCap,
        CarryEnabled = meta.CarryEnabled == true,
        CarryHostName = meta.CarryHostName or "",
        CarryAlts = meta.CarryAlts or "",
        CarryMode = meta.CarryMode == "Fixed" and "Fixed" or "Auto",
        CarryFixedStage = meta.CarryFixedStage or 1,
        CarryHardcore = meta.CarryHardcore == true,
        CarryRunStage = meta.CarryRunStage,
        HealerEnabled = meta.HealerEnabled == true,
        HealerTargetName = meta.HealerTargetName or "",
        HealerAutoEquip = meta.HealerAutoEquip ~= false,
        HealerFollowDistance = meta.HealerFollowDistance or 14,
    }, true)
end

local function validNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.clamp(value, minimum, maximum)
end
