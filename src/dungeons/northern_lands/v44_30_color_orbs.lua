-- v44.30: Bob The Frost Giant's Color Orbs are an errand, not a dodge.
--
-- Bob sends a homing orb at up to six players. It travels at about walking
-- speed, so it cannot be outrun forever and dodging it achieves nothing: it
-- just keeps coming. Touching it does damage and applies anti-healing. The way
-- it is meant to be answered is to walk it into the crystal of its own colour,
-- which destroys it.
--
-- Read live from the arena rather than hardcoded, confirmed against the
-- positions in the world:
--   Workspace.secondBossCrystals.red    at -144.3, 23.2, 268.3
--   Workspace.secondBossCrystals.green  at -158.8, 23.2, 334.8
--   Workspace.secondBossCrystals.yellow at -105.0, 23.2, 377.5
-- The orbs arrive as top level parts called secondBossRedOrb, secondBossGreenOrb
-- and secondBossYellowOrb, so the colour is in the name at both ends.
do
    CONFIG.NLOrbLead = true
    -- Six orbs are in the air at once, one per player. A loose test matched
    -- somebody else's orb that happened to be pointing our way, and the errand
    -- then ran continuously - measured 277 triggers while Bob sat untouched at
    -- 123 studs. Ours is the one that keeps pointing at us as we move, so it
    -- has to be both sharply aimed and aimed for a while.
    -- Loosened, with a counter behind each gate. Measured across a whole
    -- session: the errand fired zero times. Every Bob fight, the orb was never
    -- walked to a crystal even once - it just chased us until it caught us, and
    -- the 120 stud explosion it makes on contact is weighted as one of the most
    -- dangerous things in the dungeon for good reason. Gates that never open are
    -- worse than gates that sometimes open wrongly, so these are wider and each
    -- rejection is now counted rather than guessed at.
    CONFIG.NLOrbAimCos = 0.88        -- within about 28 degrees of straight at us
    CONFIG.NLOrbLockTime = 0.35      -- and holding that for this long
    CONFIG.NLOrbWatch = 150          -- studs: close enough to be ours
    -- An orb 100 studs out is not urgent - it travels at walking pace, so there
    -- is time to keep fighting and deal with it when it is actually close.
    -- Running the errand from the moment it spawns meant the fight was spent
    -- walking to crystals: measured 1564 errand frames in one fight.
    -- 55 was set when we fought Bob from 40 studs. We now hold him at up to 140,
    -- so an orb inside 55 studs of us is one that has already crossed most of
    -- the arena - by then the errand is a panic, not a plan.
    CONFIG.NLOrbAct = 120            -- only start the errand inside this
    CONFIG.NLOrbHold = 1.5           -- seconds a spotted orb keeps the errand alive
    CONFIG.NLOrbStandOff = 9         -- how far past the crystal we stand
    CONFIG.NLOrbDone = 14            -- orb this close to its crystal: job done

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    local function crystals()
        local folder = Workspace:FindFirstChild("secondBossCrystals")
        if not folder then
            return nil
        end
        local found = {}
        for _, child in ipairs(folder:GetChildren()) do
            local colour = string.lower(child.Name)
            local part = child:IsA("BasePart") and child
                or child:FindFirstChildWhichIsA("BasePart")
            if part then
                found[colour] = part.Position
            end
        end
        return found
    end

    -- track every orb so we can tell where it is going
    local orbTracks = setmetatable({}, { __mode = "k" })

    local function orbs(now)
        local list = {}
        for _, thing in ipairs(Workspace:GetChildren()) do
            local colour = string.match(string.lower(thing.Name), "^secondboss(%a+)orb$")
            if colour then
                local part = thing:IsA("BasePart") and thing
                    or thing:FindFirstChildWhichIsA("BasePart", true)
                if part then
                    local info = orbTracks[thing]
                    if not info then
                        info = { Position = part.Position, At = now, Velocity = Vector3.zero }
                        orbTracks[thing] = info
                    end
                    local dt = now - info.At
                    if dt >= 0.05 then
                        info.Velocity = (part.Position - info.Position) / dt
                        info.Position, info.At = part.Position, now
                    end
                    info.Thing = thing
                    table.insert(list, { Colour = colour, Part = part, Info = info })
                end
            end
        end
        return list
    end

    -- the one that is coming for us, out of everybody's
    local function note(self, why)
        self.OrbWhy = self.OrbWhy or {}
        self.OrbWhy[why] = (self.OrbWhy[why] or 0) + 1
    end

    local function mine(self, root, now)
        local best, bestScore = nil, -math.huge
        local any = false
        for _, orb in ipairs(orbs(now)) do
            any = true
            local toUs = flatten(root.Position - orb.Part.Position)
            local range = toUs.Magnitude
            if range <= CONFIG.NLOrbWatch and range > 1 then
                local velocity = flatten(orb.Info.Velocity)
                if velocity.Magnitude > 1 then
                    local aim = velocity.Unit:Dot(toUs.Unit)
                    if aim >= CONFIG.NLOrbAimCos then
                        -- a homing orb keeps its aim on us while we move; a
                        -- stranger's orb only lines up for a moment in passing
                        orb.Info.LockedSince = orb.Info.LockedSince or now
                        if now - orb.Info.LockedSince >= CONFIG.NLOrbLockTime then
                            local score = aim * 100 - range
                            if score > bestScore then
                                best, bestScore = orb, score
                            end
                        end
                    else
                        orb.Info.LockedSince = nil
                        note(self, "not aimed at us")
                    end
                else
                    note(self, "orb not moving yet")
                end
            else
                note(self, "orb beyond watch range")
            end
        end
        if not any then note(self, "no orbs in world") end
        if not best and any then note(self, "no orb claimed as ours") end
        return best
    end

    function UIWController:LeadColourOrb()
        if not CONFIG.NLOrbLead or not inNorthernLands() then
            return
        end
        local solver = self.Dodger
        local root = self.Character and self.Character.Root
        if not solver or not root or not self.Character:IsAlive() then
            return
        end
        local now = os.clock()

        local ok, orb = pcall(mine, self, root, now)
        if not ok or not orb then
            return
        end
        if flatten(root.Position - orb.Part.Position).Magnitude > CONFIG.NLOrbAct then
            note(self, "ours, but still too far to act")
            return    -- still far: keep fighting, it is coming at walking pace
        end
        local where = crystals()
        local crystal = where and where[orb.Colour]
        if not crystal then
            note(self, "no crystal for colour " .. tostring(orb.Colour))
            return    -- unknown colour: leave it to the normal dodging
        end

        -- Stand just beyond the crystal, on the far side from the orb, so the
        -- orb has to fly through the crystal to reach us. Standing on top of it
        -- is not enough - it can arrive at an angle and clip us instead.
        local approach = flatten(crystal - orb.Part.Position)
        local beyond = approach.Magnitude > 1 and approach.Unit or Vector3.new(1, 0, 0)
        local goal = crystal + beyond * CONFIG.NLOrbStandOff
        goal = Vector3.new(goal.X, root.Position.Y, goal.Z)

        if flatten(orb.Part.Position - crystal).Magnitude <= CONFIG.NLOrbDone then
            return    -- it is about to hit the crystal, stop dragging it around
        end

        solver.NLOrbGoal = goal
        solver.NLOrbUntil = now + CONFIG.NLOrbHold
        solver.NLOrbColour = orb.Colour
        self.OrbErrands = (self.OrbErrands or 0) + 1
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled then
            return
        end
        pcall(self.LeadColourOrb, self)
    end
end
