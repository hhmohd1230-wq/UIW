-- v44.26: stop walking forward, back, forward.
--
-- Measured live: 24 direction reversals a minute, and in the bad moments four
-- of them inside 1.4 seconds - flips 0.10 s, 0.33 s, 0.11 s, 0.12 s apart, with
-- the reason changing each time (hitbox -> none -> aura -> committed). No single
-- planner is at fault: each one is answering sensibly on its own, and the
-- character ends up rocking on the spot between them, taking damage it could
-- have walked away from and dealing none of its own.
--
-- This is the last word on movement, after every other planner has spoken. A
-- direction that reverses the one we are already walking is only allowed when
-- it is a real emergency; otherwise we keep going, or step sideways if the new
-- answer really does disagree. Sideways beats rocking: it still leaves the old
-- lane, and it never undoes the distance already covered.
do
    CONFIG.FlipGuard = true
    CONFIG.FlipGuardWindow = 0.45      -- a direction is protected for this long
    CONFIG.FlipGuardDot = -0.35        -- more opposed than this counts as a reversal
    CONFIG.FlipGuardProbe = 10         -- studs checked before stepping sideways

    local function sideStep(solver, oldDirection, newDirection, targetYaw)
        -- the two ways round: pick the one the new answer leans towards
        local left = Vector3.new(-oldDirection.Z, 0, oldDirection.X)
        local right = Vector3.new(oldDirection.Z, 0, -oldDirection.X)
        local first, second = left, right
        if newDirection:Dot(right) > newDirection:Dot(left) then
            first, second = right, left
        end
        for _, candidate in ipairs({ first, second }) do
            local direction = unit(flatten(candidate))
            if direction.Magnitude > 0
                and solver.Geometry:IsDirectionClear(direction, CONFIG.FlipGuardProbe, targetYaw)
                and solver.Geometry:IsGroundPadded(
                    solver.CharacterService.Root.Position + direction * CONFIG.FlipGuardProbe,
                    CONFIG.EdgeHardPadding)
            then
                return direction
            end
        end
        return nil
    end

    local oldSolveFlip = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolveFlip(self, routeDirection, enemy, targetYaw)

        if not CONFIG.FlipGuard or not direction or direction.Magnitude <= 0.05 then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        if not root then
            return direction, yaw, emergency, dodging
        end

        local now = os.clock()
        local moving = unit(flatten(direction))
        local held = self.FlipGuardDir

        if held and now - (self.FlipGuardAt or 0) <= CONFIG.FlipGuardWindow
            and moving:Dot(held) < CONFIG.FlipGuardDot
        then
            -- A genuine emergency is allowed to turn us straight round - but
            -- only once. Measured at the Ancient Tree, its sweeper planner
            -- flagged an emergency and reversed three times inside 0.3 s, which
            -- is rocking on the spot, not escaping. After the second reversal in
            -- half a second we stop honouring it and step sideways instead.
            local recent = (now - (self.FlipBurstAt or 0) <= 0.6) and (self.FlipBurst or 0) or 0
            if emergency and recent < 2 then
                self.FlipBurst, self.FlipBurstAt = recent + 1, now
                self.FlipGuardDir, self.FlipGuardAt = moving, now
                self.FlipsAllowed = (self.FlipsAllowed or 0) + 1
                return direction, yaw, emergency, dodging
            end
            self.FlipBurst, self.FlipBurstAt = recent + 1, now

            local sideways = sideStep(self, held, moving, targetYaw)
            local kept = sideways or held
            self.FlipsBlocked = (self.FlipsBlocked or 0) + 1
            self.CachedDirection = kept
            self.LastMovement = kept
            if sideways then
                -- a sideways answer becomes the new lane to protect
                self.FlipGuardDir, self.FlipGuardAt = sideways, now
            end
            return kept, yaw, emergency, dodging
        end

        self.FlipGuardDir, self.FlipGuardAt = moving, now
        return direction, yaw, emergency, dodging
    end
end
