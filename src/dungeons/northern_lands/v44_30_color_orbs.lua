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
    CONFIG.NLOrbAimCos = 0.82        -- how directly it has to be coming at us
    CONFIG.NLOrbWatch = 220          -- studs: far enough to notice it early
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
                    table.insert(list, { Colour = colour, Part = part, Info = info })
                end
            end
        end
        return list
    end

    -- the one that is coming for us, out of everybody's
    local function mine(self, root, now)
        local best, bestScore = nil, -math.huge
        for _, orb in ipairs(orbs(now)) do
            local toUs = flatten(root.Position - orb.Part.Position)
            local range = toUs.Magnitude
            if range <= CONFIG.NLOrbWatch and range > 1 then
                local velocity = flatten(orb.Info.Velocity)
                if velocity.Magnitude > 1 then
                    local aim = velocity.Unit:Dot(toUs.Unit)
                    if aim >= CONFIG.NLOrbAimCos then
                        -- the closest one that is genuinely aimed at us
                        local score = aim * 100 - range
                        if score > bestScore then
                            best, bestScore = orb, score
                        end
                    end
                end
            end
        end
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
        local where = crystals()
        local crystal = where and where[orb.Colour]
        if not crystal then
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
