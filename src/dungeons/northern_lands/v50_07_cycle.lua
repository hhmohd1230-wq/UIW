-- v50.7: Northern Lands boss cycles - know when, not where.
--
-- Measured from six recorded fights, burst to burst, with the spread of each
-- period rather than just its average:
--
--   Bob   secondBossMovingBeam      every  5.0s   sd 0.1   n=92
--   Bob   secondBossHorizontalBeam  every 14.8s   sd 1.3   n=29
--   Bob   secondBossSpreadBeam      every 14.8s   sd 1.3   n=29
--   Bob   secondBossCricleHitbox    every 14.9s   sd 6.1   n=20
--   Bob   ice spikes                every 27.0s   sd 14.5  n=11
--   Champ firstBossJumpSlam         every 29.9s   sd 0.0   n=4
--
-- Only the tight ones are used. A period with a standard deviation half its
-- own length is not a cycle, it is an average of unrelated things, and acting
-- on it would be worse than reacting: we would leave good ground early for an
-- attack that is not coming. The wave and the ice spikes stay out for now on
-- those grounds, and go in when more fights narrow them.
--
-- WHAT THIS PREDICTS: the timing, and nothing else. Where an attack will land
-- is not in this data - the probe records that something spawned, not its
-- geometry - so guessing a position would be invention. Knowing the second is
-- enough to be worth having: it turns "dodge once it exists" into "stop
-- committing to damage just before it does".
--
-- The structure is lifted from the Ancient Temple Protector planner in this
-- same script, which does the same thing for that boss from its own measured
-- cycle.
do
    CONFIG.NLCyclePredict = true
    -- How long before a due attack we start treating the room as dangerous.
    -- Roughly the time to walk clear at 24 studs a second, plus the spread of
    -- the period itself so we are early rather than exactly on time.
    CONFIG.NLCycleLead = 1.6
    -- A prediction is only trusted for this many periods after the last sighting.
    -- Bosses reset their rotation on phase changes and on our death, and a
    -- confident wrong answer is worse than no answer.
    CONFIG.NLCycleTrust = 2.5

    local CYCLE = {
        secondBossMovingBeam     = 5.0,
        secondBossHorizontalBeam = 14.8,
        secondBossSpreadBeam     = 14.8,
        firstBossJumpSlam        = 29.9,
    }
    -- events closer together than this are the same burst, not a new one
    local BURST = 3.0

    local function northernNow()
        local d = Workspace:FindFirstChild("dungeonName")
        return d and d.Value == "Northern Lands"
    end

    local seen = {}          -- name -> {last burst start, last event}
    Workspace.ChildAdded:Connect(function(child)
        local period = CYCLE[child.Name]
        if not period or not northernNow() then return end
        local now = os.clock()
        local s = seen[child.Name]
        if not s then
            s = {burst = now, event = now}
            seen[child.Name] = s
        else
            if now - s.event > BURST then s.burst = now end
            s.event = now
        end
    end)

    -- How close are we to the next one of anything we can predict?
    -- Returns seconds until the soonest due attack, or nil when nothing is.
    --
    -- A plain local, called directly. The first draft hung this off the dodge
    -- solver's Owner - which the solver does not have - so it would have read
    -- nil every frame and predicted nothing, silently, exactly like the pit
    -- goal that was written seven times and read none.
    local function cycleDueIn()
        if not CONFIG.NLCyclePredict then return nil end
        local now, soonest = os.clock(), nil
        for name, period in pairs(CYCLE) do
            local s = seen[name]
            if s then
                local since = now - s.burst
                -- stale: the rotation has probably reset since we last saw it
                if since <= period * CONFIG.NLCycleTrust then
                    local due = period - (since % period)
                    if not soonest or due < soonest then soonest = due end
                end
            end
        end
        return soonest
    end
    -- exposed for the diagnostics as well
    function UIWController:CycleDueIn() return cycleDueIn() end

    -- Fold it into the boss mode: a due attack makes the room dangerous a
    -- moment before it actually is, which is the whole point.
    local oldCycleSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, yaw)
        local a, b, c, d = oldCycleSolve(self, routeDirection, enemy, yaw)
        if CONFIG.NLCyclePredict then
            local due = cycleDueIn()
            if due and due <= CONFIG.NLCycleLead then
                self.NLCycleWarning = true
                if self.NLBossMode == "attack" then
                    self.NLBossMode = "evade"
                    self.NLCycleSwitches = (self.NLCycleSwitches or 0) + 1
                end
            else
                self.NLCycleWarning = nil
            end
        end
        return a, b, c, d
    end

    local oldCycleNew = UIWController.new
    function UIWController.new()
        local self = oldCycleNew()
        self.Version = tostring(self.Version) .. "+cycle"
        return self
    end
end
