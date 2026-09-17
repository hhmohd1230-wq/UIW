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
    if SafeFile.LastContent[path] == content then
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

local function validNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.clamp(value, minimum, maximum)
end

