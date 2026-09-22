-- v51.01: get out of the wall.
--
-- Measured, live, at the end of a Bob fight on Nightmare: the character sat at
-- (-242, 21, 366) with all sixteen compass rays blocked at distance ZERO by
-- Meshes/JTNWarrior_Cube.133 and the floor ray blocked at zero too. We were
-- inside the west wall. Humanoid state Running, WalkSpeed 20, nothing
-- anchored, velocity 0.001, MoveDirection 0. The solver was alive and stepping
-- (1534 -> 1558 solves in a second) and still nothing moved, because every
-- direction scored as blocked, so it produced no direction at all and the run
-- stood in the wall until the player rejoined the game.
--
-- Two things now stop that. The map layer keeps walls solid except while we
-- are dropping, so we should not get in. This is the other half: if we do get
-- in, get out by ourselves rather than waiting for a human to notice.
--
-- Nothing here writes CFrame or AssemblyLinearVelocity. The only levers are
-- the ones a player has - walk, jump - plus turning our OWN collision off for
-- a few seconds, which is the same trick the map layer uses and is reversible.
do
    CONFIG.Unwedge = true
    CONFIG.UnwedgeMoved = 2.5      -- studs in a second: less than this is stuck
    CONFIG.UnwedgeFor = 5          -- consecutive stuck seconds before we act
    CONFIG.UnwedgeJumpPhase = 3.0  -- seconds of jump-and-walk first
    CONFIG.UnwedgeGhostPhase = 3.0  -- then this long with our own collision off
    CONFIG.UnwedgeProbe = 24       -- how far the escape rays look

    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")

    local state = {
        Last = nil,
        At = 0,
        Stuck = 0,
        Until = 0,
        Started = 0,
        Dir = nil,
        Saved = nil,
    }

    local function character()
        local plr = Players.LocalPlayer
        local model = plr and plr.Character
        local root = model and model:FindFirstChild("HumanoidRootPart")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        if root and hum and hum.Health > 0 then
            return model, root, hum
        end
    end

    -- The way out is the longest clear ray. If everything is blocked - which is
    -- what being inside a mesh looks like - fall back to whichever direction
    -- had the furthest hit, because a thin wall is a shorter trip than a thick
    -- one, and after that to the arena itself.
    local function wayOut(model, root)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { model }
        params.IgnoreWater = true
        local best, bestRoom = nil, -1
        for i = 0, 15 do
            local a = i * math.pi / 8
            local dir = Vector3.new(math.cos(a), 0, math.sin(a))
            local hit = workspace:Raycast(root.Position, dir * CONFIG.UnwedgeProbe, params)
            local room = hit and (hit.Position - root.Position).Magnitude or CONFIG.UnwedgeProbe
            if room > bestRoom then best, bestRoom = dir, room end
        end
        return best or Vector3.new(1, 0, 0), bestRoom
    end

    local function beginEscape(controller, root)
        state.Until = os.clock() + CONFIG.UnwedgeJumpPhase + CONFIG.UnwedgeGhostPhase
        state.Started = os.clock()
        state.Saved = nil
        controller.Unwedges = (controller.Unwedges or 0) + 1
        controller.UnwedgeAt = string.format("%.0f,%.0f,%.0f",
            root.Position.X, root.Position.Y, root.Position.Z)
    end

    local function ghost(model, on)
        if on then
            if not state.Saved then
                state.Saved = {}
                for _, p in ipairs(model:GetDescendants()) do
                    if p:IsA("BasePart") then state.Saved[p] = p.CanCollide end
                end
            end
            for p in pairs(state.Saved) do
                if p.Parent then p.CanCollide = false end
            end
        elseif state.Saved then
            for p, was in pairs(state.Saved) do
                if p.Parent then p.CanCollide = was end
            end
            state.Saved = nil
        end
    end

    local jumpAt = 0
    RunService.Heartbeat:Connect(function()
        if not CONFIG.Unwedge then return end
        local controller = getgenv().UIW
        if not controller or controller.Destroyed or not controller.Enabled then return end
        local model, root, hum = character()
        if not model then
            state.Stuck, state.Until = 0, 0
            ghost(nil, false)
            return
        end
        local now = os.clock()

        local dungeonStarted = workspace:FindFirstChild("dungeonStarted")
        if not dungeonStarted or dungeonStarted.Value ~= true
            or not (controller.Dungeon and controller.Dungeon.HasSeenEnemies)
        then
            state.Stuck, state.Until = 0, 0
            state.Last, state.At = root.Position, now
            ghost(model, false)
            return
        end

        -- an escape in progress owns the character until it is done
        if now < state.Until then
            local elapsed = now - state.Started
            if elapsed > CONFIG.UnwedgeJumpPhase then ghost(model, true) end
            if now - jumpAt > 0.4 then
                jumpAt = now
                hum.Jump = true
            end
            hum:Move(state.Dir or Vector3.new(1, 0, 0), false)
            return
        end
        if state.Saved then
            ghost(model, false)
            state.Last, state.At, state.Stuck = root.Position, now, 0
        end

        if now - state.At < 1 then return end
        local moved = state.Last and (root.Position - state.Last).Magnitude or math.huge
        state.Last, state.At = root.Position, now

        -- Deliberately NOT gated on MoveDirection.
        --
        -- The first draft only counted a second against us if the humanoid was
        -- already trying to walk, on the reasoning that standing still on
        -- purpose is not being stuck. Measured an hour later: character at
        -- (-239, 26, 364), not moving, MoveDirection exactly 0 - and so never
        -- counted as stuck at all. That is the failure mode, not the exception
        -- to it. With no target the solver produces no goal, the base solver
        -- produces no direction, and a character that has been told to go
        -- nowhere looks identical to one that cannot go anywhere.
        --
        -- So any five seconds without moving is treated as stuck. The real
        -- deliberate holds are all shorter than that: the colour-orb wait is
        -- NLOrbHold + NLOrbSettle, about 2.1 seconds at most.
        if moved < CONFIG.UnwedgeMoved then
            state.Stuck = state.Stuck + 1
        else
            state.Stuck = 0
        end

        if state.Stuck >= CONFIG.UnwedgeFor then
            state.Stuck = 0
            local dir, room = wayOut(model, root)
            state.Dir = dir
            controller.UnwedgeRoom = room
            beginEscape(controller, root)
        end
    end)
end
