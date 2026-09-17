--[[
    UIW loader
      loadstring(game:HttpGet("https://raw.githubusercontent.com/hhmohd1230-wq/UIW/main/loader.lua"))()

    Options (set before the line above):
      getgenv().UIW_BUILD  = "main"    -- "main" (default), "flat" (experiment), "stable" (v44.22)
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
    main = { branch = "main", file = "dist/UIW.lua" },
    flat = { branch = "experiment-flatmap", file = "dist/UIW.lua" },
    stable = { branch = "main", file = "dist/UIW_stable_v44.22.lua" },
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

local function readSaved()
    if not canFile() then
        return nil
    end
    local ok, exists = pcall(isfile, SAVE_PATH)
    if not (ok and exists) then
        return nil
    end
    local okRead, source = pcall(readfile, SAVE_PATH)
    return okRead and source or nil
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

if not source then
    source = readSaved()
    if source then
        notify("GitHub not reachable, running the saved copy")
    end
end

if not source then
    notify("could not load the script: " .. tostring(err))
    return
end

getgenv().UIW_SCRIPT_PATH = SAVE_PATH

local chunk, compileError = loadstring(source)
if not chunk then
    notify("script did not compile: " .. tostring(compileError))
    return
end

notify("loading " .. branch .. " (" .. build.file .. ")")
return chunk()
