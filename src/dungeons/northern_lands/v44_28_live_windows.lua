-- Northern Lands only. Warning lifetime, not model lifetime, defines a beam.
-- Keep this layer after the general field and anti-reversal planners.
do
    CONFIG.NLAwareRadius = 150     -- only what can reach this close to us matters
    CONFIG.NLBobRadius = 40        -- how close we hold to Bob The Frost Giant
    CONFIG.NLGapClearance = 9      -- beam half width plus a body
    CONFIG.NLMinRadius = 28        -- closest we stand to the pillar
    CONFIG.NLMaxRadius = 135       -- and the furthest, for Sun-Burst
    CONFIG.NLCastRadius = 60       -- inside this we can still hit the boss (range 64)
    CONFIG.NLWalkCost = 0.06       -- studs of walking traded against studs of closeness
    CONFIG.NLSafety = 1.2          -- stand this much past the bare minimum radius
    CONFIG.NLBurstLead = 1.4       -- seconds of beam spawning we look ahead
    CONFIG.NLBurstAlarmEnds = 10   -- this many blocked angles means Sun-Burst is starting
    CONFIG.NLBurstHold = 7         -- once it starts, commit to the run for this long

    local function northern()
        local d = Workspace:FindFirstChild("dungeonName")
        return d and d.Value == "Northern Lands"
    end
    -- Room 2 is not the final boss room, so the generic classifier missed the
    -- Champion. This also prevented the elevated-boss line-of-sight exception.
    local boss = isBossEnemy
    isBossEnemy = function(enemy)
        if northern() and enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "midgardian champion" then
            return true
        end
        return boss(enemy)
    end
    local timed = {firstBossPassiveBeam=true, firstBossJumpSlam=true, spearmanStrikeHitbox=true,
        northernMageShot=true, northernWarriorCircleStrike=true}
    local windup = {firstBossPassiveBeam=1.0, firstBossJumpSlam=2.0}
    -- Found by logging everything that appears during the fight: the whirlwinds
    -- and the shurikens are bare MeshParts sitting straight in the workspace
    -- with no hitBox and no precast child, so the hazard tracker never saw them
    -- at all. firstBossCrissCross crosses the arena at 30 studs/s - that is the
    -- one that kept killing us "out of nowhere".
    local moving = {northernMageShot=true, firstBossSeekingSpikes=true,
        firstBossCrissCross=true, firstBossBigSpike=true,
        firstBossWhirlwind=true, firstBossWhirlWind=true, spearmanStrike=true}
    local tracks = setmetatable({}, {__mode="k"})
    local function live(container, now)
        local box = container:FindFirstChild("hitBox", true)
        if not box and container:IsA("BasePart") then box = container end
        if not box or not box:IsA("BasePart") then return nil end
        local info = tracks[container]
        if not info then
            local look=flatten(box.CFrame.LookVector)
            info = {At=now, Position=box.Position, Velocity=Vector3.zero, Seen=now, Visible=now,
                Angle=math.atan2(look.Z,look.X),Omega=0}
            tracks[container] = info
        end
        local dt = now - info.At
        if dt >= 0.025 then
            local velocity = (box.Position-info.Position)/dt
            if velocity.Magnitude < 450 then info.Velocity = velocity else info.Velocity=Vector3.zero end
            local look=flatten(box.CFrame.LookVector)
            local angle=math.atan2(look.Z,look.X)
            local omega=((angle-info.Angle+math.pi)%(2*math.pi)-math.pi)/dt
            info.Omega=math.abs(omega)<7 and omega or 0
            info.Angle=angle
            info.At, info.Position = now, box.Position
        end
        local pre = container:FindFirstChild("precast", true)
        if pre and pre:IsA("BasePart") and pre.Transparency < 0.98 then
            info.Visible = now
            info.HadWarning = true
        end
        if timed[container.Name] and info.HadWarning and now-info.Visible > 0.30 then return nil end
        if timed[container.Name] and not info.HadWarning and now-info.Seen > 0.30 then return nil end
        return box, info
    end

    -- These attacks can outlive a nearby mob. Nearest-enemy inference had
    -- attributed mage shots to warriors and deleted them when the warrior died.
    local register = HazardTracker.Register
    function HazardTracker:Register(part)
        register(self, part)
        if not northern() then return end
        local data = (self.FullHazards or self.Hazards)[part]
        if data and data.Container and (moving[data.Container.Name] or timed[data.Container.Name]) then
            data.SourceEnemyModel, data.SourceEnemyHumanoid = nil, nil
        end
    end
    local active = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        if northern() and container and container.Parent and timed[container.Name] then
            return live(container, now or os.clock()) ~= nil
        end
        return active(self, container, now)
    end

    -- The old Champion station scanned every lingering beam, including spent
    -- warnings. Its unvalidated slam direction could also cross a live beam.
    local oldStation, oldSlam = DodgeSolver.GetChampionStation, DodgeSolver.GetChampionSlamEscape
    function DodgeSolver:GetChampionStation(...)
        if northern() then return nil end
        return oldStation(self, ...)
    end
    function DodgeSolver:GetChampionSlamEscape(...)
        if northern() then return nil end
        return oldSlam(self, ...)
    end

    local function collect(self, now)
        local root = self.CharacterService.Root
        local list, seen, beams = {}, {}, {}
        local function add(part, velocity, name, omega, info)
            if seen[part] then return end
            seen[part] = true
            local cf, half = part.CFrame, part.Size*0.5
            -- Distance to the box itself, not to its centre. A 250 stud beam
            -- through the pillar has its centre 130 studs away while passing
            -- straight through us, and a small orb 140 studs off is irrelevant;
            -- centre distance gets both of those backwards. This keeps the work
            -- to what is actually near us, which is cheaper and sharper.
            local here = cf:PointToObjectSpace(root.Position)
            local dx = math.max(math.abs(here.X) - half.X, 0)
            local dy = math.max(math.abs(here.Y) - half.Y, 0)
            local dz = math.max(math.abs(here.Z) - half.Z, 0)
            if math.sqrt(dx * dx + dy * dy + dz * dz) > CONFIG.NLAwareRadius then return end
            local pad=name=="firstBossJumpSlam" and 16
                or ((name=="firstBossCrissCross" or name=="firstBossBigSpike"
                    or name=="firstBossSeekingSpikes") and 8)
                or 5
            -- The shurikens are flat discs: firstBossSeekingSpikes is 20x0x20
            -- and firstBossBigSpike 40x0x40, zero studs tall. With the usual 3
            -- stud vertical allowance a disc lying on the floor can sit
            -- entirely below the height test while we walk through it, so a
            -- flat hazard gets a body's worth of height instead.
            local tall = half.Y < 4 and 9 or 3
            list[#list+1] = {CF=cf, Half=half+Vector3.new(pad,tall,pad), V=velocity, Omega=omega or 0,
                Starts=0,
                Ends=info and windup[name] and math.max(0.3,windup[name]+0.5-(now-info.Seen)) or math.huge,
                Name=name, Distance=math.sqrt(dx * dx + dy * dy + dz * dz)}
        end
        for _,container in ipairs(Workspace:GetChildren()) do
            if timed[container.Name] or moving[container.Name] then
                local part, info = live(container, now)
                if part then
                    add(part, timed[container.Name] and Vector3.zero or info.Velocity, container.Name, info.Omega, info)
                    if container.Name == "firstBossPassiveBeam" then beams[#beams+1]=part end
                end
            end
        end
        for _,data in ipairs(self.Hazards:GetActive()) do
            local part, container = data.Part, data.Container
            if part and part.Parent and not data.IsPrecast and not (container and timed[container.Name]) then
                add(part, self.Hazards:GetProjectileVelocity(data), container and container.Name or part.Name)
            end
        end
        local names = {}
        for _, box in ipairs(list) do names[box.Name] = (names[box.Name] or 0) + 1 end
        self.NLNames = names
        table.sort(list, function(a,b) return a.Distance < b.Distance end)
        while #list > 32 do table.remove(list) end
        return list, beams
    end
    local function risk(list, position, time)
        local score = 0
        for _,box in ipairs(list) do
            if time<box.Starts or time>box.Ends then continue end
            local cf=box.CF
            if math.abs(box.Omega)>0.02 then
                cf=CFrame.new(cf.Position)*CFrame.Angles(0,-box.Omega*time,0)*(cf-cf.Position)
            end
            local p=cf:PointToObjectSpace(position-box.V*time)
            local half=box.Half
            if math.abs(p.Y)<=half.Y then
                local dx,dz=math.abs(p.X)-half.X,math.abs(p.Z)-half.Z
                if dx<=0 and dz<=0 then score += (100+math.min(-dx,-dz)*2)*(box.Name=="firstBossJumpSlam" and 4 or 1)
                else score += math.max(0,4-math.max(dx,dz))*0.4 end
            end
        end
        return score
    end
    local solve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, yaw)
        if not northern() or not self.CharacterService:IsAlive() then return solve(self,routeDirection,enemy,yaw) end
        local now=os.clock()
        if now-(self.NLAt or 0)<0.045 and self.NLDirection then
            return self.NLDirection,yaw,self.NLEmergency,self.NLDodging
        end
        local root=self.CharacterService.Root
        local list,beams=collect(self,now)
        local champion=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="midgardian champion"
        local bob=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="bob the frost giant"
        local preferred=unit(flatten(routeDirection or Vector3.zero))
        local goal
        if champion then
            -- Every beam is a diameter through the pillar, so it blocks the
            -- angle it points at and the opposite one. How far out we have to
            -- stand is set by how many are lit at once: half the gap we sit in
            -- has to subtend the beam's half width plus our body.
            --   3 lit beams  -> 18 studs is enough, stay close and keep casting
            --   12 lit beams -> 69 studs
            --   23 lit beams (Sun-Burst) -> 132 studs, get out
            -- A fixed 46 was only ever right for about 7, which is why we died
            -- at 57-74 studs during Sun-Burst with 22 beams up.
            self.NLPivot = (#beams > 0) and beams[1].Position or self.NLPivot
            local pivot = self.NLPivot
            if pivot then
                local flatPivot = Vector3.new(pivot.X, root.Position.Y, pivot.Z)
                local offset = flatten(root.Position - flatPivot)
                local mine = math.atan2(offset.Z, offset.X) % (2 * math.pi)
                local ends = {}
                for _, part in ipairs(beams) do
                    local look = flatten(part.CFrame.LookVector)
                    if look.Magnitude > 0.01 then
                        local yaw = math.atan2(look.Z, look.X)
                        ends[#ends + 1] = yaw % (2 * math.pi)
                        ends[#ends + 1] = (yaw + math.pi) % (2 * math.pi)
                    end
                end
                -- Sun-Burst is a spawn-rate spike, so react to how fast beams
                -- are appearing rather than waiting until we are surrounded.
                -- Walking from 40 studs out to 130 takes about four seconds; by
                -- the time the count alone says "run", it is already too late.
                self.NLSeen = self.NLSeen or {}
                local fresh = 0
                for _, part in ipairs(beams) do
                    if not self.NLSeen[part] then
                        self.NLSeen[part] = now
                        fresh += 1
                    end
                end
                for part, at in pairs(self.NLSeen) do
                    if now - at > 1 then self.NLSeen[part] = nil end
                end
                self.NLRate = (self.NLRate or 0) * 0.6 + fresh * 0.4
                local lead = math.floor(self.NLRate * CONFIG.NLBurstLead * 2)

                -- Every gap is a candidate. The one we stand in is not
                -- automatically the best: a wider gap elsewhere may let us
                -- stand close enough to keep casting, and the path scoring
                -- below decides whether we can safely get there.
                local angle, span, radius = mine, math.pi * 2, CONFIG.NLMinRadius
                if #ends > 0 then
                    table.sort(ends)
                    local bestCost = math.huge
                    for i = 1, #ends do
                        local from = ends[i]
                        local width = (ends[(i % #ends) + 1] - from) % (2 * math.pi)
                        if width <= 0.0001 then width = 2 * math.pi end
                        local middle = (from + width * 0.5) % (2 * math.pi)
                        -- the bare minimum radius puts us exactly on the edge of
                        -- the beam, so stand a fifth further out than that
                        local need = CONFIG.NLGapClearance / math.max(math.sin(width * 0.5), 0.02)
                        local r = math.clamp(math.max(need * CONFIG.NLSafety, CONFIG.NLMinRadius),
                            CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                        -- how far round the circle we would have to walk
                        local turn = math.abs((middle - mine + math.pi) % (2 * math.pi) - math.pi)
                        local walk = turn * math.max(offset.Magnitude, r) + math.abs(offset.Magnitude - r)
                        local cost = r + walk * CONFIG.NLWalkCost
                        -- only chase a shooting position that still has room in
                        -- it, not one we only just fit into
                        if r <= CONFIG.NLCastRadius then
                            cost -= 25
                        end
                        if cost < bestCost then
                            bestCost, angle, span, radius = cost, middle, width, r
                        end
                    end
                end

                -- and if beams are pouring in, stand where the count is heading
                if lead > 0 then
                    local ahead = #ends + lead
                    local packed = CONFIG.NLGapClearance / math.max(math.sin(math.pi / ahead), 0.02)
                    radius = math.clamp(math.max(radius, packed), CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                end

                -- Tried and rejected: latching a run out to 135 studs when the
                -- beam count spikes. Measured, it was much worse - 6 deaths and
                -- 0.69%/s against 0 deaths and 2.67%/s for staying close - and
                -- it got hit anyway at 94-138 studs, because the beams reach 125
                -- and we spent the fight walking instead of killing. The fights
                -- with 69-85% time in cast range are the ones with no deaths:
                -- killing the boss quickly is what removes Sun-Bursts, not
                -- outrunning them.
                -- Sun-Burst: the Champion teleports back onto the pillar and
                -- only then spawns beams, so the return is the warning. Running
                -- on the beam count instead was measured far worse - the run out
                -- takes 4.4 s and we were caught halfway every time. Started on
                -- the teleport there is time to arrive: beams reach 125 studs,
                -- so past that nothing can touch us.
                if now < (self.NLSunburstUntil or 0) then
                    radius = math.max(radius, CONFIG.NLSunburstRadius or 75)
                    self.NLBursting = true
                else
                    self.NLBursting = false
                end
                self.NLWantRadius, self.NLGapDegrees = radius, math.deg(span)
                self.NLLead = lead
                goal = flatPivot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
                preferred = unit(flatten(goal - root.Position))
            end
        end
        -- Bob: measured 122 studs away with "closing for close-range mob combo"
        -- blocking 91% of casts - it was permanently on its way in and never
        -- arriving, which is why he barely lost health. His opening wave also
        -- grows as it travels, so the circle is smallest next to him: close is
        -- both where the damage happens and where the wave is easiest to step
        -- around.
        if bob and enemy.Root and enemy.Root.Parent then
            local offset = flatten(root.Position - enemy.Root.Position)
            local out = offset.Magnitude > 1 and offset.Unit or Vector3.new(1, 0, 0)
            local stand = enemy.Root.Position + out * CONFIG.NLBobRadius
            goal = Vector3.new(stand.X, root.Position.Y, stand.Z)
            preferred = unit(flatten(goal - root.Position))
        end

        -- Leading a colour orb into its crystal beats any standing position:
        -- the orb homes at walking speed, so it is never outrun, and the only
        -- way it ends is at the crystal.
        if self.NLOrbGoal and now < (self.NLOrbUntil or 0) then
            goal = self.NLOrbGoal
            preferred = unit(flatten(goal - root.Position))
        end

        local standing=risk(list,root.Position,0)+risk(list,root.Position,0.3)+risk(list,root.Position,0.65)
            +risk(list,root.Position,1.0)+risk(list,root.Position,1.5)
        if not goal and standing<1 then
            self.NLDirection=nil
            return solve(self,routeDirection,enemy,yaw)
        end
        local speed=math.max(self.CharacterService.Humanoid.WalkSpeed,8)
        local horizon=champion and 1.5 or 0.65
        local times=champion and {0.15,0.4,0.7,1.0,1.25,1.5} or {0.12,0.3,0.5,0.65}
        local melee={}
        if not champion then
            for _,e in ipairs(self.Dungeon and self.Dungeon:GetAliveEnemies() or {}) do
                if e.Root and e.Root.Parent and getEnemyThreatClass(e)=="Melee" then
                    melee[#melee+1]=e.Root.Position
                end
            end
        end
        local best,bestScore=nil,math.huge
        for i=0,16 do
            local angle=i*math.pi/8
            local dir=i==16 and Vector3.zero or Vector3.new(math.cos(angle),0,math.sin(angle))
            local distance=speed*horizon
            if dir.Magnitude==0 or (self.Geometry:IsDirectionClear(dir,distance,yaw)
                and self.Geometry:IsGroundPadded(root.Position+dir*distance,CONFIG.EdgeHardPadding)) then
                local score=0
                for _,t in ipairs(times) do
                    local position=root.Position+dir*speed*t
                    score+=risk(list,position,t)
                    for _,mob in ipairs(melee) do
                        score+=math.max(0,34-flatten(position-mob).Magnitude)*8
                    end
                end
                if goal then score+=flatten(root.Position+dir*distance-goal).Magnitude*0.3
                else score-=dir:Dot(preferred)*4 end
                if self.NLDirection then score+=(1-dir:Dot(self.NLDirection))*1.5 end
                if score<bestScore then best,bestScore=dir,score end
            end
        end
        if not best then self.NLDirection=nil return solve(self,routeDirection,enemy,yaw) end
        self.NLAt,self.NLDirection=now,best
        self.NLEmergency,self.NLDodging=standing>=100,best.Magnitude>0.05
        self.LastDodgeReason=champion and "nl-champion-live" or "nl-mob-live"
        self.LastSolve=now
        self.CachedDirection,self.CachedYaw,self.CachedDodging=best,yaw,self.NLDodging
        self.IsDodging=self.NLDodging
        if self.NLDodging then self.LastMovement=best end
        self.NLLiveBoxes,self.NLLiveBeams=#list,#beams
        return best,yaw,self.NLEmergency,self.NLDodging
    end
end
