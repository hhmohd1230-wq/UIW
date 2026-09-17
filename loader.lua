-- UIW loader: loadstring(readfile("UIW/loader.lua"))()
-- UIW_BUILD: "main" (default), "flat", or "stable".
-- UIW_LOCAL: nil = saved build first; true = saved only; false = download first.
-- UIW_BRANCH: optional Git branch override, with its own separate cache.
local env = getgenv()
local builds = {
    main = {branch = "main", file = "dist/UIW.lua", saved = "UIW/UIW_main.lua"},
    flat = {branch = "experiment-flatmap", file = "dist/UIW.lua", saved = "UIW/UIW_flat.lua"},
    stable = {branch = "main", file = "dist/UIW_stable_v44.22.lua", saved = "UIW/UIW_stable.lua"},
}
local name = string.lower(tostring(env.UIW_BUILD or "main"))
local build = builds[name]
local function fail(message)
    error("[UIW loader] " .. message, 0)
end
if not build then fail("Unknown UIW_BUILD: " .. name .. ". Use main, flat, or stable.") end
local branch = env.UIW_BRANCH or build.branch
if type(branch) ~= "string" or branch == "" then fail("UIW_BRANCH must be a nonempty string.") end
local saved = build.saved
if branch ~= build.branch then
    local key = branch:gsub(".", function(c) return string.format("%02x", string.byte(c)) end)
    saved = "UIW/cache_" .. name .. "_" .. key .. ".lua"
end
local function compile(source)
    if type(source) ~= "string" or source == "" then return nil, "empty script" end
    local ok, chunk, err = pcall(loadstring, source)
    if not ok then return nil, tostring(chunk) end
    if type(chunk) ~= "function" then return nil, tostring(err) end
    return chunk
end
local function readSaved()
    if type(readfile) ~= "function" then return nil, "readfile is unavailable" end
    local ok, source = pcall(readfile, saved)
    if not ok then return nil, "cannot read " .. saved .. ": " .. tostring(source) end
    local chunk, err = compile(source)
    if not chunk then return nil, saved .. " does not compile: " .. tostring(err) end
    return chunk
end
local function download()
    local encoded = branch:gsub("[^%w%-_%.~]", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    local url = "https://raw.githubusercontent.com/hhmohd1230-wq/UIW/" .. encoded .. "/" .. build.file
    local ok, source = pcall(function() return game:HttpGet(url, true) end)
    if not ok then return nil, "Download failed for " .. url .. ": " .. tostring(source) end
    local chunk, err = compile(source)
    if not chunk then return nil, "Downloaded script does not compile: " .. tostring(err) end
    local persisted = false
    if type(writefile) == "function" then
        local writeOK, writeError = pcall(function()
            if type(isfolder) == "function" and not isfolder("UIW") and type(makefolder) == "function" then
                makefolder("UIW")
            end
            writefile(saved, source)
        end)
        persisted = writeOK
        if not writeOK then warn("[UIW loader] Could not save downloaded build: " .. tostring(writeError)) end
    end
    return chunk, nil, persisted
end
local chunk, firstError, secondError, persisted
local origin
if env.UIW_LOCAL == false then
    chunk, firstError, persisted = download()
    origin = "GitHub"
    if not chunk then
        warn("[UIW loader] " .. tostring(firstError) .. "; trying " .. saved)
        chunk, secondError = readSaved()
        origin, persisted = saved, chunk ~= nil
    end
else
    chunk, firstError = readSaved()
    origin, persisted = saved, chunk ~= nil
    if not chunk and env.UIW_LOCAL ~= true then
        chunk, secondError, persisted = download()
        origin = "GitHub"
    end
end
if not chunk then
    fail("Cannot load " .. name .. ". " .. tostring(firstError) ..
        (secondError and ("; " .. tostring(secondError)) or ""))
end
-- The game's teleport support needs the path for this particular build.
env.UIW_SCRIPT_PATH = persisted and saved or nil
if not persisted then warn("[UIW loader] Running without a saved copy; teleport auto-execute is unavailable for this download.") end
print("[UIW loader] Loading " .. name .. " from " .. origin)
return chunk()
