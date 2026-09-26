-- v44.31: Northern Lands mobs - circle them instead of trading shots.
--
-- Their behaviour makes this work: they walk towards you and fire in straight
-- lines at where you are. Standing off and shooting back means eating those
-- lines; walking a circle around them at a fixed radius means every shot is
-- aimed where you just were, and you never let them close the gap. Measured
-- across two recorded human runs, northernMageShot was the single biggest
-- source of damage in the dungeon - 14 of 34 hits - so this is the attack the
-- orbit is meant to beat.
--
-- The radius is kept inside our own cast range (64) so circling and damaging
-- are the same activity rather than a trade.
--
-- Walls: rather than removing them, the orbit is wall-aware. It looks ahead
-- along the circle, and when the way round is blocked it turns and goes the
-- other way. Flat Arena already clears scenery on this client, which is the
-- legitimate version of "remove the walls".
do
    CONFIG.NLMobOrbit = true
    CONFIG.NLMobOrbitRadius = 58      -- inside cast range, outside their reach
    CONFIG.NLMobOrbitStep = 32        -- degrees round the circle we aim ahead
    CONFIG.NLMobOrbitMin = 34         -- never let one get closer than this
    CONFIG.NLMobOrbitProbe = 12       -- studs checked before committing to a way round
    CONFIG.NLMobOrbitHold = 1.2       -- seconds we keep spinning the same way
    -- Measured: every single time the circle was refused, the raycast hit
    -- nothing at all - it was the ground check, i.e. the point on the circle
    -- was off the edge of the arena floor. Not one wall. So the answer is to
    -- pull the circle in until it is back over floor, not to pass through
    -- anything: coming inward keeps us going round, noclip would just walk us
    -- off the map.
    CONFIG.NLMobOrbitRadii = { 58, 48, 40, 34 }
    -- A mob this far from the one we are shooting still counts as part of the
    -- same pack, so the circle is drawn around all of them.
    -- Wide enough to take in the whole room, not just the two mobs in front of
    -- us. A pack of two got circled while another group stood untouched further
    -- back; including them puts the centre between the groups, which both draws
    -- them together and keeps them all inside one circle.
    CONFIG.NLPackSpan = 140
    CONFIG.NLPackClearance = 20     -- studs beyond the outermost mob in the pack
    -- The circle may now be wide, because the shuriken flies - the same thing
    -- that proved true against Bob. It is only capped below the range at which
    -- we can still hit the middle.
    CONFIG.NLPackMaxRadius = 80
    CONFIG.NLGatherReach = 220
    CONFIG.NLGatherLead = 18

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- somewhere on the circle, a step ahead of where we are now
    local function orbitPoint(centre, radial, radius, degrees)
        local turned = unit(rotateXZ(radial, degrees))
        if turned.Magnitude == 0 then
            return nil
        end
        return centre + turned * radius
    end

    function DodgeSolver:GetMobOrbitGoal(enemy)
        if not CONFIG.NLMobOrbit or not inNorthernLands() then
            return nil
        end
        if not enemy or not enemy.Model or not enemy.Root or not enemy.Root.Parent then
            return nil
        end
        if isBossEnemy(enemy) then
            return nil            -- bosses have their own standing rules
        end
        local root = self.CharacterService.Root
        if not root then
            return nil
        end

        -- Circle the GROUP, not the one mob we happen to be shooting.
        --
        -- Measured across twenty mob fights: the arc we actually covered around
        -- the target ranged from 10 to 310 degrees, and damage tracked it almost
        -- perfectly - 310 degrees gave 5.38%/s with 100% of the fight in range,
        -- while 20 to 50 degrees gave 0.00%/s. The cause was not walls. A
        -- raycast along the way round found something solid in 0% of samples in
        -- seventeen of those twenty fights.
        --
        -- It was this: the orbit centre was whichever mob was currently
        -- targeted. Target selection moves between mobs scattered across the
        -- room, so every switch teleports the centre, resets our bearing, and
        -- the circle restarts from nothing. We were walking twenty arcs instead
        -- of one circle. Orbiting the middle of the pack fixes it at the source,
        -- and it is also where the damage wants to be, because the pack stays
        -- clustered in there.
        local centre = Vector3.new(enemy.Root.Position.X, root.Position.Y, enemy.Root.Position.Z)
        local pack, sum, spread = 0, Vector3.zero, 0
        local enemies=self.Dungeon and self.Dungeon:GetAliveEnemies() or {}
        local function samePack(other)
            return other.Root and other.Root.Parent and not isBossEnemy(other)
                and other.Room==enemy.Room and math.abs(other.Root.Position.Y-root.Position.Y)<12
        end
        for _, other in ipairs(enemies) do
            if samePack(other)
                and flatten(other.Root.Position - centre).Magnitude <= CONFIG.NLPackSpan
            then
                pack += 1
                sum += Vector3.new(other.Root.Position.X, root.Position.Y, other.Root.Position.Z)
            end
        end
        if pack >= 2 then
            local middle = sum / pack
            for _, other in ipairs(enemies) do
                if samePack(other) then
                    local out = flatten(other.Root.Position - middle).Magnitude
                    if out <= CONFIG.NLPackSpan then spread = math.max(spread, out) end
                end
            end
            centre = middle
            self.NLPackSize, self.NLPackSpread = pack, spread
        else
            self.NLPackSize, self.NLPackSpread = pack, 0
        end

        -- Advance the orbit toward an uncollected mob while retaining its spin.
        -- Use only this room and elevation; a distant pack behind a gate or
        -- below the balcony must not pull this fight away from its floor.
        local now=os.clock()
        local gather,best=nil,math.huge
        for _,other in ipairs(enemies) do
            if samePack(other) then
                local distance=flatten(other.Root.Position-root.Position).Magnitude
                if distance>75 and distance<=CONFIG.NLGatherReach then
                    local count,sum=0,Vector3.zero
                    for _,near in ipairs(enemies) do
                        if samePack(near) and flatten(near.Root.Position-other.Root.Position).Magnitude<55 then
                            count+=1
                            sum+=near.Root.Position
                        end
                    end
                    -- Prefer the large waiting group, not the nearest lone pursuer.
                    local score=distance-count*35
                    if getEnemyThreatClass(other)~="Melee" then score-=20 end
                    if other.Model==self.NLGatherTarget then score-=25 end
                    if score<best then
                        gather,best=other,score
                        self.NLGatherCluster=sum/math.max(count,1)
                        self.NLGatherCount=count
                    end
                end
            end
        end
        local wanted=Vector3.zero
        if gather then
            local toward=flatten(gather.Root.Position-centre)
            if toward.Magnitude>1 then wanted=toward.Unit*math.min(CONFIG.NLGatherLead,toward.Magnitude) end
        end
        if self.NLGatherRoom~=enemy.Room or now-(self.NLGatherAt or 0)>1 then self.NLGatherBias=Vector3.zero end
        local dt=math.clamp(now-(self.NLGatherAt or now),0,0.2)
        self.NLGatherBias=(self.NLGatherBias or Vector3.zero):Lerp(wanted,1-math.exp(-dt*3))
        self.NLGatherAt,self.NLGatherRoom=now,enemy.Room
        self.NLGatherTarget=gather and gather.Model or nil
        self.NLGatherPoint=nil
        if gather then
            local destination=Vector3.new(self.NLGatherCluster.X,root.Position.Y,self.NLGatherCluster.Z)
            local approach=flatten(root.Position-destination)
            self.NLGatherPoint=destination+(approach.Magnitude>1 and approach.Unit or Vector3.new(1,0,0))*40
        end
        centre+=self.NLGatherBias

        local offset = flatten(root.Position - centre)
        if offset.Magnitude < 1 then
            return nil
        end
        local radial = offset.Unit

        -- Circling a group needs a radius that clears the widest mob in it and
        -- still keeps the middle of the pack inside our own casting range, so
        -- that going round and doing damage are the same activity rather than
        -- alternatives. A lone mob keeps the fixed ladder.
        local radii = CONFIG.NLMobOrbitRadii
        if spread > 0 then
            -- Experiment (NLStrategyExperiment): run a tighter circle. Mobs
            -- chase us, so the shape we run is the shape they end up in - pull
            -- the radius in and they bunch instead of trailing out behind.
            local clearance = CONFIG.NLStrategyExperiment
                and CONFIG.NLPackClearanceExp or CONFIG.NLPackClearance
            local maxRadius = CONFIG.NLStrategyExperiment
                and CONFIG.NLPackMaxRadiusExp or CONFIG.NLPackMaxRadius
            local want = math.clamp(spread + clearance,
                CONFIG.NLMobOrbitMin, maxRadius)
            radii = { want, want - 8, want + 8, CONFIG.NLMobOrbitMin }
        end

        -- keep circling the same way unless that way is blocked; flipping every
        -- frame is just rocking on the spot with extra steps
        if now > (self.NLSpinUntil or 0) then
            self.NLSpin = self.NLSpin or 1
        end

        for _, spin in ipairs({ self.NLSpin or 1, -(self.NLSpin or 1) }) do
          local step = CONFIG.NLStrategyExperiment
              and CONFIG.NLMobOrbitStepExp or CONFIG.NLMobOrbitStep
          for _, degrees in ipairs({ step, step * 0.5 }) do
            for _, radius in ipairs(radii) do
                local point = orbitPoint(centre, radial, radius, degrees * spin)
                -- Keep the current damage target reachable while gathering.
                -- If it is already far away, permit only progress toward it.
                if point and gather then
                    local limit=math.max((CONFIG.NLMobCastRange or 100)-5,
                        flatten(root.Position-enemy.Root.Position).Magnitude)
                    if flatten(point-enemy.Root.Position).Magnitude>limit then
                        local base=centre-self.NLGatherBias
                        point=orbitPoint(base,unit(flatten(root.Position-base)),radius,degrees*spin)
                    end
                end
                if point then
                    local step = flatten(point - root.Position)
                    if step.Magnitude > 0.5 then
                        local direction = step.Unit
                        local reach = math.min(step.Magnitude, CONFIG.NLMobOrbitProbe)
                        if self.Geometry:IsDirectionClear(direction, reach, directionToYaw(direction))
                            and self.Geometry:IsGroundPadded(root.Position + direction * reach,
                                CONFIG.EdgeHardPadding)
                        then
                            if spin ~= self.NLSpin then
                                -- turned round: hold this way for a moment
                                self.NLSpin = spin
                                self.NLSpinFlips = (self.NLSpinFlips or 0) + 1
                            end
                            self.NLSpinUntil = now + CONFIG.NLMobOrbitHold
                            self.NLOrbiting = true
                            self.NLOrbitRadius = radius
                            return point
                        end
                    end
                end
            end
          end
        end

        -- Boxed in both ways. Record what is in the way, so the answer can be
        -- "clear that specific thing" rather than "walk through everything".
        self.NLOrbiting = false
        self.NLBlockers = self.NLBlockers or {}
        local probe = unit(rotateXZ(radial, CONFIG.NLMobOrbitStep * (self.NLSpin or 1)))
        if probe.Magnitude > 0 then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { self.CharacterService.Character }
            params.RespectCanCollide = true
            local hit = Workspace:Raycast(root.Position, probe * CONFIG.NLMobOrbitProbe, params)
            if hit and hit.Instance then
                local part = hit.Instance
                local key = string.format("%s/%s %.0fx%.0fx%.0f anchored=%s",
                    part.Parent and part.Parent.Name or "?", part.Name,
                    part.Size.X, part.Size.Y, part.Size.Z, tostring(part.Anchored))
                self.NLBlockers[key] = (self.NLBlockers[key] or 0) + 1
            else
                self.NLBlockers["nothing hit (ground/edge check)"] =
                    (self.NLBlockers["nothing hit (ground/edge check)"] or 0) + 1
            end
        end
        if offset.Magnitude < CONFIG.NLMobOrbitMin then
            return centre + radial * CONFIG.NLMobOrbitRadius
        end
        return nil
    end
end
