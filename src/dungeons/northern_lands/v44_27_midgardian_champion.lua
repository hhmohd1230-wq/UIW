-- v44.27: Northern Lands, first boss - the Midgardian Champion.
--
-- Everything here is gated on the dungeon name, so the Enchanted Forest keeps
-- the ranges and dodging it has now.
--
-- Measured live in the fight: the passive Dual Beams are models called
-- firstBossPassiveBeam whose hitBox is 250 x 8 x 64 and whose centre sits on
-- the pillar at the middle of the arena. Each beam is a diameter, not a ray -
-- it blocks the angle it points at and the opposite one - and they turn.
--
-- That geometry decides the whole fight. A turning beam sweeps past you at
-- (turn rate x your distance from the pillar), while the gap between two beams
-- lasts the same amount of time wherever you stand. Out at 72-144 studs, where
-- we were dying three pulses at a time, the beam edge moves far faster than we
-- can walk. In close, the same gap only asks for a few studs a second.
--
-- So the plan is: stand near the pillar, in the middle of the gap we are
-- already in, and turn with it. That is also directly under the boss, which is
-- where our damage wants to be.
do
    CONFIG.NLStandRadius = 26          -- studs from the pillar we aim to hold
    CONFIG.NLStandRadiusMax = 60       -- ...unless there is no floor that close
    CONFIG.NLBeamHalfWidth = 4         -- the hitBox is 8 wide
    CONFIG.NLBeamClearance = 5         -- body plus a margin
    CONFIG.NLSlamPad = 10              -- extra studs outside a jump slam circle
    CONFIG.NLStationSlack = 3          -- close enough, stop shuffling

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- the beams, as angles around their shared centre
    local function beamField()
        local pivot, angles = nil, {}
        for _, model in ipairs(Workspace:GetChildren()) do
            if model.Name == "firstBossPassiveBeam" then
                local box = model:FindFirstChild("hitBox", true)
                if box and box:IsA("BasePart") then
                    pivot = pivot or box.Position
                    local look = flatten(box.CFrame.LookVector)
                    if look.Magnitude > 0.01 then
                        local yaw = math.atan2(look.Z, look.X)
                        -- a diameter blocks both ends
                        table.insert(angles, yaw % (math.pi * 2))
                        table.insert(angles, (yaw + math.pi) % (math.pi * 2))
                    end
                end
            end
        end
        if not pivot or #angles == 0 then
            return nil
        end
        table.sort(angles)
        return pivot, angles
    end

    -- middle of the gap we are standing in, so reaching it never crosses a beam
    local function safeAngle(angles, mine)
        local count = #angles
        for index = 1, count do
            local from = angles[index]
            local to = angles[(index % count) + 1]
            local span = (to - from) % (math.pi * 2)
            local offset = (mine - from) % (math.pi * 2)
            if offset <= span then
                return (from + span * 0.5) % (math.pi * 2), span
            end
        end
        return mine, 0
    end

    local function pointAt(pivot, angle, radius)
        return Vector3.new(
            pivot.X + math.cos(angle) * radius,
            pivot.Y,
            pivot.Z + math.sin(angle) * radius
        )
    end

    -- a jump slam we are standing in: leave it, outwards is shortest
    function DodgeSolver:GetChampionSlamEscape()
        local root = self.CharacterService.Root
        if not root then
            return nil
        end
        local worst, worstPush = nil, 0
        for _, model in ipairs(Workspace:GetChildren()) do
            if model.Name == "firstBossJumpSlam" then
                local box = model:FindFirstChild("hitBox", true)
                if box and box:IsA("BasePart") then
                    local keepOut = math.max(box.Size.X, box.Size.Z) * 0.5 + CONFIG.NLSlamPad
                    local offset = flatten(root.Position - box.Position)
                    local push = keepOut - offset.Magnitude
                    if push > worstPush then
                        worst, worstPush = offset, push
                    end
                end
            end
        end
        if not worst then
            return nil
        end
        return worst.Magnitude > 0.5 and worst.Unit or Vector3.new(1, 0, 0)
    end

    -- where we want to be standing right now
    function DodgeSolver:GetChampionStation()
        local root = self.CharacterService.Root
        if not root then
            return nil
        end
        local pivot, angles = beamField()
        if not pivot then
            return nil
        end
        self.ChampionPivot = pivot

        local offset = flatten(root.Position - pivot)
        local mine = math.atan2(offset.Z, offset.X) % (math.pi * 2)
        local angle, span = safeAngle(angles, mine)

        -- a gap has to be wide enough to hold us at that radius
        local radius = CONFIG.NLStandRadius
        local needed = 2 * (math.asin(math.min(1,
            (CONFIG.NLBeamHalfWidth + CONFIG.NLBeamClearance) / math.max(radius, 1))))
        while span < needed and radius < CONFIG.NLStandRadiusMax do
            radius += 8
            needed = 2 * (math.asin(math.min(1,
                (CONFIG.NLBeamHalfWidth + CONFIG.NLBeamClearance) / math.max(radius, 1))))
        end

        -- and there has to be floor there
        local goal = nil
        for _, candidate in ipairs({ radius, radius + 10, radius + 20, radius + 34 }) do
            if candidate <= CONFIG.NLStandRadiusMax + 20 then
                local point = pointAt(pivot, angle, candidate)
                if self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding) then
                    goal = point
                    break
                end
            end
        end
        if not goal then
            goal = pointAt(pivot, angle, radius)
        end

        self.ChampionGoal = goal
        self.ChampionRadius = offset.Magnitude
        local delta = flatten(goal - root.Position)
        if delta.Magnitude <= CONFIG.NLStationSlack then
            return Vector3.zero
        end
        return delta.Unit
    end

    ---------------------------------------------------------------------------
    local oldSolveChampion = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        if not inNorthernLands() or not self.CharacterService:IsAlive() then
            return oldSolveChampion(self, routeDirection, enemy, targetYaw)
        end

        -- a slam landing on our head beats everything else
        local okSlam, slam = pcall(self.GetChampionSlamEscape, self)
        if okSlam and slam then
            self.LastDodgeReason = "champion-slam"
            self.IsDodging = true
            self.CachedDirection = slam
            self.CachedYaw = targetYaw
            self.CachedDodging = true
            self.LastMovement = slam
            self.ChampionSlams = (self.ChampionSlams or 0) + 1
            return slam, targetYaw, true, true
        end

        local okStation, station = pcall(self.GetChampionStation, self)
        if okStation and station then
            self.LastDodgeReason = "champion-station"
            self.IsDodging = station.Magnitude > 0.05
            self.CachedDirection = station
            self.CachedYaw = targetYaw
            self.CachedDodging = self.IsDodging
            if station.Magnitude > 0.05 then
                self.LastMovement = station
            end
            self.ChampionHolds = (self.ChampionHolds or 0) + 1
            return station, targetYaw, false, self.IsDodging
        end

        return oldSolveChampion(self, routeDirection, enemy, targetYaw)
    end

    ---------------------------------------------------------------------------
    -- The Champion fights from the top of a pillar. A straight line from our
    -- chest to it clips the pillar, so the line-of-sight test said no and we
    -- stopped casting at the one boss we are standing right underneath - even
    -- though the game is happy to let the spell land.
    ---------------------------------------------------------------------------
    local oldLos = CombatController.HasLineOfSight
    function CombatController:HasLineOfSight(enemy)
        if enemy and enemy.Root and enemy.Root.Parent and isBossEnemy(enemy) and inNorthernLands() then
            local root = self.CharacterService.Root
            if root and enemy.Root.Position.Y > root.Position.Y + 6 then
                return true
            end
        end
        return oldLos(self, enemy)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.27-nl"
        return self
    end
end
