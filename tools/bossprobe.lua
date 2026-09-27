-- Persistent boss probe. Survives teleports by re-queueing itself, and writes
-- every boss fight to a file rather than to memory, because a teleport wipes
-- getgenv and we lose the run we were measuring.
--
-- One line per fight: boss, seconds, deaths, damage rate, cast hit rate,
-- average distance, and how much of it we spent standing still.
--
-- 2026-09-27, check-in #6 re-run. TWO CHANGES, both instrumentation only.
--
-- 1. This file now lives in the repo (tools/bossprobe.lua) and is copied to
--    the Volt workspace by build-openmap.ps1 -Volt. It previously existed
--    ONLY at %LOCALAPPDATA%\Volt\workspace\UIW\bossprobe.lua - untracked,
--    unbuilt, and one workspace wipe from taking the whole measurement
--    history with it. The instrument that decides every change in this repo
--    was the one file not under version control.
--
-- 2. The line now carries the diagnostic counters. This is the actual reason
--    check-ins #3 through #6 could not close their own questions: they asked
--    "is controller.Unwedges firing more than a few times per run", "confirm
--    NLBobRinged and NLBobPillarClear fire", "NLCycleSwitches is nil" - and
--    NONE of those counters were written anywhere. Not here, not in
--    99_telemetry.lua. The only way to read them was to catch the client
--    mid-fight with a live probe, which needs the player to be at the
--    keyboard at the moment the check-in runs. Four check-ins in a row
--    answered those three questions with "cannot tell". A question that
--    cannot be answered from the artifact the check-in reads is not a
--    question, it is a wish.
--
-- Appended AFTER v= so every existing parse of this file keeps working.
--
-- Deltas, not lifetime totals: "this fight needed 3 unwedges" is the useful
-- fact, and a lifetime counter read once at the end cannot tell you which
-- fight needed them.
--
-- NOTHING here changes behaviour. dist/UIW_openmap.lua is deliberately
-- untouched and still byte-identical to the build that produced the 51.8
-- numbers, because CONFIG.NLBarrierDodge was flipped to false on 2026-09-26
-- and has not been measured yet - the player has not played since 09-20. A
-- second behavioural change stacked on top of an unmeasured one measures
-- neither.
if getgenv().UIW_BOSSPROBE then return end
getgenv().UIW_BOSSPROBE = true

local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local LOG = "UIW/bosslog.txt"

local function append(line)
    pcall(function()
        local stamp = string.format("[%s] %s\n", os.date("%H:%M:%S"), line)
        if type(appendfile) == "function" then appendfile(LOG, stamp)
        else writefile(LOG, (isfile(LOG) and readfile(LOG) or "") .. stamp) end
    end)
end

-- come back after a teleport
pcall(function()
    if queue_on_teleport then
        queue_on_teleport([[
            task.wait(12)
            pcall(function() loadstring(readfile("UIW/bossprobe.lua"))() end)
            pcall(function() loadstring(readfile("UIW/nlobserve.lua"))() end)
        ]])
    end
end)

local function isBoss(n)
    return n:find("Bob") or n:find("Odin") or n:find("Champion")
end

-- The dodge solver, which is where the Northern Lands flags live. Named
-- Dodger on the controller (core/controller.lua:15), not DodgeSolver - the
-- first draft of this guessed Solver and read nil forever, which is the same
-- bug v50_07_cycle.lua's own comment warns about two files away.
local function dodger(c)
    return c and c.Dodger or nil
end

local function num(v) return tonumber(v) or 0 end

-- Everything we sample per frame and report as a delta over the fight.
local function snapshot(c)
    local d = dodger(c)
    return {
        Unwedges = num(c and c.Unwedges),
        Stucks   = num(c and c.StuckEvents),
        CycSw    = num(d and d.NLCycleSwitches),
        Ringed   = num(d and d.NLBobRinged),
        Pillar   = num(d and d.NLBobPillarClear),
    }
end

local function finish(fight, c)
    local secs = os.clock() - fight.Start
    local n = math.max(fight.N, 1)
    local now = snapshot(c)
    local b = fight.Base

    -- Which boss modes the solver actually held during the fight. "none"
    -- means NLBossMode stayed nil for the whole fight, which is the claim
    -- check-in #6 makes about Bob and has never been checked.
    local modes = {}
    for m in pairs(fight.Modes) do table.insert(modes, m) end
    table.sort(modes)
    local modeStr = #modes > 0 and table.concat(modes, "+") or "none"

    -- Did the cycle predictor EVER have a live prediction? If this reads
    -- "never" on a Bob fight the Workspace.ChildAdded listener in
    -- v50_07_cycle.lua is not matching anything, and neither of the two
    -- options in check-in #6's question 4 is the fix - the names or the
    -- parenting are. If it reads a number, the predictor sees the boss and
    -- the dead write is the fix.
    local dueStr = fight.DueSeen > 0
        and string.format("min%.2f/n%d", fight.DueMin, fight.DueSeen)
        or "never"

    local unwedged = now.Unwedges - b.Unwedges
    append(string.format(
        "%s | %.0fs | %.0f%%->%.0f%% = %.2f%%/s | deaths %d | casts %d/%d hit | dist avg %.0f | still %.0f%% | v=%s"
        .. " | unwedge %d%s | stuck %d | cyc sw%d due=%s | mode %s | ring %d/%d",
        fight.Name, secs, fight.Hp0, fight.Hp,
        (fight.Hp0 - fight.Hp) / math.max(secs, 1),
        fight.Deaths, fight.Landed, fight.Casts,
        fight.DistSum / n,
        fight.Still / n * 100,
        tostring(c and c.Version),
        unwedged, (unwedged > 0 and fight.UAt) and ("@" .. fight.UAt) or "",
        now.Stucks - b.Stucks,
        now.CycSw - b.CycSw,
        dueStr,
        modeStr,
        now.Ringed - b.Ringed, now.Pillar - b.Pillar))
end

task.spawn(function()
    local fight, press
    while true do
        local c = getgenv().UIW
        local r = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
        local h = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
        local boss
        if c and c.Dungeon then
            for _, e in ipairs(c.Dungeon:GetAliveEnemies(true) or {}) do
                local n = e.Model and e.Model.Name or ""
                if isBoss(n) and e.Humanoid and e.Humanoid.Health > 0 then boss = e break end
            end
        end

        -- hook the damage cast once a controller exists
        if c and c.Combat and not press then
            press = c.Combat.Press
            c.Combat.Press = function(self, slot, ...)
                local res = press(self, slot, ...)
                if slot == "e" and fight and fight.Boss and fight.Boss.Humanoid then
                    local rr = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                    if rr then
                        fight.Casts = fight.Casts + 1
                        local before = fight.Boss.Humanoid.Health
                        local f = fight
                        task.delay(1.2, function()
                            if f.Boss.Humanoid.Health < before - 1 then f.Landed = f.Landed + 1 end
                        end)
                    end
                end
                return res
            end
        end

        if boss and r and h then
            if not fight or fight.Model ~= boss.Model then
                if fight then finish(fight, c) end
                fight = {Model = boss.Model, Name = boss.Model.Name, Boss = boss,
                    Start = os.clock(), Hp0 = boss.Humanoid.Health / boss.Humanoid.MaxHealth * 100,
                    Hp = 100, Deaths = 0, Casts = 0, Landed = 0, DistSum = 0, N = 0, Still = 0,
                    WasAlive = h.Health > 0,
                    Base = snapshot(c), Modes = {}, DueSeen = 0, DueMin = math.huge, UAt = nil}
            end
            fight.Boss = boss
            fight.Hp = boss.Humanoid.Health / boss.Humanoid.MaxHealth * 100
            fight.N = fight.N + 1
            fight.DistSum = fight.DistSum + (boss.Root.Position - r.Position).Magnitude
            if Vector3.new(r.AssemblyLinearVelocity.X, 0, r.AssemblyLinearVelocity.Z).Magnitude < 3 then
                fight.Still = fight.Still + 1
            end
            if fight.WasAlive and h.Health <= 0 then fight.Deaths = fight.Deaths + 1 end
            fight.WasAlive = h.Health > 0

            -- diagnostics, sampled at the same 10Hz as everything else
            local d = dodger(c)
            fight.Modes[tostring(d and d.NLBossMode or "none")] = true
            if c and c.CycleDueIn then
                local ok, due = pcall(c.CycleDueIn, c)
                if ok and type(due) == "number" then
                    fight.DueSeen = fight.DueSeen + 1
                    if due < fight.DueMin then fight.DueMin = due end
                end
            end
            if c and c.UnwedgeAt then fight.UAt = tostring(c.UnwedgeAt) end
        elseif fight then
            finish(fight, c)
            fight = nil
        end
        task.wait(0.1)
    end
end)

append("=== boss probe started ===")
