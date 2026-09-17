-- v44.24: the two Crystal Golem attacks that were not being dodged at all.
--
-- 1. Electric sweepers. The geode lands, a 50 stud bar grows out of it, and
--    only then does it turn through the arena. Measured live: the hitbox model
--    (firstBossSpinningRockHitbox, one hitBox part 50 x 49 x 1) lives 8.2 s,
--    and the kill at 12.1 s came 2.3 s after it spawned.
--    The tracker counts an armed hitbox as dangerous for TouchDangerWindow
--    (1.6 s) after it appears, which is right for an attack that lands once and
--    exactly wrong here: the attack was dropped from the hazard tables at the
--    moment it became lethal, so nothing dodged it.
--    The rule below keeps a big armed hitbox live for as long as it is still
--    moving or turning. It is written by behaviour, not by name, so it also
--    covers the second boss's 450 stud spinning laser and whatever Northern
--    Lands turns out to have.
--
-- 2. Dome blast. "enchantedFirstBossFollowOrb" follows a player for up to 30 s
--    and on contact grows (innerBall 5.6 -> 40 studs across in 1.6 s) into a
--    dome that shreds anything still inside. The model has no part named
--    hitBox or precast, so the tracker never registered it and we never moved.
--    20 studs is one second of walking: it only ever needed to be noticed.
do
    -- a sweeping beam: big, armed, and still moving
    CONFIG.SweeperMinSize = 20              -- studs, longest side of the hitbox
    CONFIG.SweeperQuietGrace = 3.0          -- stays live this long after it stops changing
    CONFIG.SweeperMaxLife = 16              -- ...but never longer than this
    CONFIG.SweeperMoveEpsilon = 0.2         -- studs between samples
    CONFIG.SweeperGrowEpsilon = 0.5         -- the bar growing counts as being alive
    CONFIG.SweeperTurnEpsilon = math.rad(1)

    CONFIG.DomeMaxRadius = 20               -- innerBall ends at 40 wide
    CONFIG.DomePad = 6                      -- and we want daylight, not a tie
    CONFIG.DomeTriggerGrowth = 1.5          -- studs of growth that means "it went off"
    CONFIG.DomeWatchRange = 160

    ---------------------------------------------------------------------------
    -- 1. A big armed hitbox that is still moving is still an attack.
    ---------------------------------------------------------------------------
    local motion = setmetatable({}, { __mode = "k" })

    local function sweeperPart(container)
        for _, object in ipairs(container:GetDescendants()) do
            if object:IsA("BasePart")
                and string.find(string.lower(object.Name), "hitbox", 1, true)
                and math.max(object.Size.X, object.Size.Y, object.Size.Z) >= CONFIG.SweeperMinSize
            then
                return object
            end
        end
        return nil
    end

    local function stillSweeping(container, now)
        local info = motion[container]

        if not info or not info.Part then
            -- The model can be registered before its hitBox has replicated, so
            -- a miss is retried for a few seconds instead of being remembered
            -- as "not a sweeper" for good.
            local first = info and info.FirstLook or now
            if not info then
                info = { FirstLook = now, LookAt = -1 }
                motion[container] = info
            end
            if now - first > 4 then
                return false
            end
            if now - info.LookAt < 0.4 then
                return false
            end
            info.LookAt = now
            local part = sweeperPart(container)
            if not part then
                return false
            end
            info.Part, info.CF, info.Size = part, part.CFrame, part.Size
            info.At, info.Born, info.LastChange = now, now, now
            return true
        end

        local part = info.Part
        if not part or not part.Parent or now - info.Born > CONFIG.SweeperMaxLife then
            return false
        end

        -- A sweeper is quiet for a moment between landing and turning: it grows
        -- its bar first. Growth counts as life, otherwise the attack is retired
        -- during the wind-up and is gone by the time it starts killing people.
        if now - info.At >= 0.08 then
            local cf, size = part.CFrame, part.Size
            local moved = (cf.Position - info.CF.Position).Magnitude
            local turned = math.acos(math.clamp(cf.LookVector:Dot(info.CF.LookVector), -1, 1))
            local grew = (size - info.Size).Magnitude
            if moved >= CONFIG.SweeperMoveEpsilon
                or turned >= CONFIG.SweeperTurnEpsilon
                or grew >= CONFIG.SweeperGrowEpsilon
            then
                info.LastChange = now
            end
            info.CF, info.Size, info.At = cf, size, now
        end

        -- While it is still doing anything at all it stays live; a bar that has
        -- sat completely still for a while is a leftover and goes back to the
        -- normal rules.
        return now - info.LastChange <= CONFIG.SweeperQuietGrace
    end

    local oldActive = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        if container and container.Parent then
            local ok, sweeping = pcall(stillSweeping, container, now)
            if ok and sweeping then
                return true
            end
        end
        return oldActive(self, container, now)
    end

    ---------------------------------------------------------------------------
    -- 2. The sweeper planner used to switch itself off unless the current
    -- target was the golem. The geodes are thrown while we are shooting mobs,
    -- which is exactly when nothing dodged them.
    ---------------------------------------------------------------------------
    local GOLEM_STAND_IN = { Model = { Name = "Crystal Golem" } }

    -- The bar is 50 studs across, so it reaches 25 from the geode. Anything
    -- further out than this is not our problem yet - and hijacking movement for
    -- a geode 150 studs away is pure lost damage time.
    CONFIG.GolemSweeperEngage = 55

    local oldSpinnerMove = DodgeSolver.GetCrystalGolemSpinnerMove
    function DodgeSolver:GetCrystalGolemSpinnerMove(routeDirection, enemy, targetYaw)
        local targeted = enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "crystal golem"
        if not targeted then
            local root = self.CharacterService.Root
            local ok, list = pcall(self.Hazards.GetCrystalGolemSweepers, self.Hazards)
            if ok and root and type(list) == "table" then
                for _, laser in ipairs(list) do
                    local pivot = laser.Pivot or laser.Center
                    if pivot and flatten(root.Position - pivot).Magnitude <= CONFIG.GolemSweeperEngage then
                        enemy = GOLEM_STAND_IN
                        break
                    end
                end
            end
        end
        return oldSpinnerMove(self, routeDirection, enemy, targetYaw)
    end

    ---------------------------------------------------------------------------
    -- 3. Dome blast: leave the circle before it finishes growing.
    ---------------------------------------------------------------------------
    function HazardTracker:GetGrowingDomes()
        local now = os.clock()
        -- the dodge solver asks every frame; one look per 10th of a second is
        -- plenty for something that takes 1.6 s to grow, and keeps this off the
        -- frame budget when a boss arena is full of parts
        local cached = self.DomeCache
        if cached and now - cached.At < 0.1 then
            return cached.List
        end
        local states = self.DomeStates or setmetatable({}, { __mode = "k" })
        self.DomeStates = states
        local list = {}

        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") then
                local ball = model:FindFirstChild("innerBall")
                if ball and ball:IsA("BasePart") then
                    local size = ball.Size.X
                    local state = states[model]
                    if not state then
                        state = { Start = size, Born = now }
                        states[model] = state
                    end
                    state.Size = size
                    if not state.GrowingSince and size >= state.Start + CONFIG.DomeTriggerGrowth then
                        state.GrowingSince = now
                    end
                    if state.GrowingSince then
                        table.insert(list, {
                            Model = model,
                            Part = ball,
                            Center = ball.Position,
                            Radius = math.max(size * 0.5, 3),
                            Since = state.GrowingSince,
                        })
                    end
                end
            end
        end

        self.DomeCache = { At = now, List = list }
        return list
    end

    -- Where to walk so that no growing dome still covers us. Straight out is
    -- the shortest way, so it is tried first and only bent when that way is
    -- blocked or walks into something else.
    function DodgeSolver:GetDomeEscape(targetYaw)
        local character = self.CharacterService
        if not character:IsAlive() then
            return nil
        end
        local root = character.Root
        if not root then
            return nil
        end

        -- Standing in a shelter region beats the dome: missing the falling
        -- crystal is a one-shot kill, the dome is damage over time. Merely
        -- walking to some other mechanic goal does not beat it - that is how
        -- we ate 38% while strolling through a fully grown dome.
        if self.ForcedRegionPart then
            self.DomeEscaping = false
            return nil
        end

        local ok, domes = pcall(self.Hazards.GetGrowingDomes, self.Hazards)
        if not ok or type(domes) ~= "table" or #domes == 0 then
            self.DomeEscaping = false
            return nil
        end

        local origin = root.Position
        local keepOut = CONFIG.DomeMaxRadius + CONFIG.DomePad
        local away = Vector3.zero
        local caught = false

        for _, dome in ipairs(domes) do
            local offset = flatten(origin - dome.Center)
            local distance = offset.Magnitude
            if distance <= CONFIG.DomeWatchRange and distance < keepOut then
                caught = true
                local push = distance > 0.5 and offset.Unit or Vector3.new(1, 0, 0)
                -- the closer to the middle, the more this dome decides
                away += push * (keepOut - distance + 1)
            end
        end

        if not caught then
            self.DomeEscaping = false
            return nil
        end

        local preferred = unit(flatten(away))
        if preferred.Magnitude < 0.05 then
            preferred = unit(flatten(character.Root.CFrame.LookVector))
        end

        local function usable(direction)
            if not self.Geometry:IsDirectionClear(direction, 14, directionToYaw(direction)) then
                return false
            end
            local point = origin + direction * 14
            if not self.Geometry:IsGroundPadded(point, CONFIG.EdgeHardPadding) then
                return false
            end
            return self.Hazards:GetOverlapCountAt(point, targetYaw) == 0
        end

        for _, degrees in ipairs({ 0, -25, 25, -50, 50, -75, 75, -105, 105 }) do
            local direction = unit(rotateXZ(preferred, degrees))
            if direction.Magnitude > 0 and usable(direction) then
                self.DomeEscaping = true
                self.DomeEscapes = (self.DomeEscapes or 0) + 1
                return direction
            end
        end

        -- nothing clean: out is still better than standing in it
        self.DomeEscaping = true
        return preferred
    end

    local oldSolveForDome = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local ok, escape = pcall(self.GetDomeEscape, self, targetYaw)
        if ok and escape then
            local now = os.clock()
            self.CurrentSolveEnemy = enemy
            self.LastSolve = now
            self.LastDodgeReason = "golem-dome"
            self.IsDodging = true
            self.CachedDirection = escape
            self.CachedYaw = targetYaw
            self.CachedEmergency = true
            self.CachedDodging = true
            self.CommittedDodgeDirection = Vector3.zero
            self.DodgeCommitUntil = 0
            self.LastMovement = escape
            return escape, targetYaw, true, true
        end
        return oldSolveForDome(self, routeDirection, enemy, targetYaw)
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.24"
        return self
    end
end
