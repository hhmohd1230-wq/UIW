--[[
    UIW loader
      loadstring(game:HttpGet("https://raw.githubusercontent.com/hhmohd1230-wq/UIW/main/loader.lua"))()

    Options (set before the line above):
      getgenv().UIW_BUILD  = "main"    -- "main" (default), "openmap" (Northern Lands), "flat", "stable"
      getgenv().UIW_BRANCH = "main"    -- any branch name, overrides UIW_BUILD
      getgenv().UIW_LOCAL  = true      -- skip the download, run the saved copy

    The loader downloads the built script, saves it to UIW/UIW.lua so Auto
    Execute keeps working after a teleport, and falls back to that saved copy
    if GitHub cannot be reached.
]]

local USER = "hhmohd1230-wq"
local REPO = "UIW"
local SAVE_PATH = "UIW/UIW.lua"

local BUILDS = {
    main = { branch = "main", file = "dist/UIW.lua", local_ = "UIW/UIW.lua" },
    flat = { branch = "experiment-flatmap", file = "dist/UIW.lua", local_ = "UIW/UIW_flat.lua" },
    stable = { branch = "main", file = "dist/UIW_stable_v44.22.lua", local_ = "UIW/UIW_stable.lua" },
    -- Northern Lands build: same script plus the open-map pass that clears
    -- scenery on your own client, keeps the floors, and leaves every barrier
    -- standing.
    openmap = { branch = "main", file = "dist/UIW_openmap.lua", local_ = "UIW/UIW_openmap.lua" },
}

local build = BUILDS[string.lower(tostring(getgenv().UIW_BUILD or "main"))] or BUILDS.main
local branch = getgenv().UIW_BRANCH or build.branch

local function notify(text)
    print("[UIW loader] " .. text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "UIW",
            Text = text,
            Duration = 4,
        })
    end)
end

local function canFile()
    return type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
end

-- offline / UIW_LOCAL: run the copy of the chosen build that is already saved
local function readSaved()
    if not canFile() then
        return nil
    end
    for _, path in ipairs({ build.local_, SAVE_PATH }) do
        local ok, exists = pcall(isfile, path)
        if ok and exists then
            local okRead, source = pcall(readfile, path)
            if okRead and type(source) == "string" and #source > 10000 then
                return source, path
            end
        end
    end
    return nil
end

local function download()
    local url = string.format(
        "https://raw.githubusercontent.com/%s/%s/%s/%s?cb=%d",
        USER, REPO, branch, build.file, math.floor(os.time())
    )
    local ok, source = pcall(function()
        return game:HttpGet(url, true)
    end)
    if not ok or type(source) ~= "string" or #source < 10000 then
        return nil, tostring(source)
    end
    return source
end

local source, err
if not getgenv().UIW_LOCAL then
    source, err = download()
    if source and canFile() then
        pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("UIW") then
                makefolder("UIW")
            end
            writefile(SAVE_PATH, source)
        end)
    end
end

local savedPath
if not source then
    source, savedPath = readSaved()
    if source then
        notify(getgenv().UIW_LOCAL and ("running the saved " .. tostring(savedPath))
            or ("GitHub not reachable, running the saved " .. tostring(savedPath)))
    end
end

if not source then
    notify("could not load the script: " .. tostring(err))
    return
end

getgenv().UIW_SCRIPT_PATH = savedPath or SAVE_PATH

local chunk, compileError = loadstring(source)
if not chunk then
    notify("script did not compile: " .. tostring(compileError))
    return
end

notify(savedPath and ("loaded " .. savedPath) or ("loading " .. branch .. " (" .. build.file .. ")"))
return chunk()
