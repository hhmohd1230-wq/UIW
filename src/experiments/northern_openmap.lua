-- Optional standalone add-on; appended only by build-openmap.ps1.
-- Keep original walk surfaces and elevations. Never edit dungeon mechanics.
do
    local env = getgenv()
    if env.UIW_OpenMap then env.UIW_OpenMap:Destroy() end
    local c = env.UIW
    local dungeon = workspace:FindFirstChild("dungeonName")
    local deadline = os.clock() + 60
    while (not dungeon or dungeon.Value == "") and os.clock() < deadline do
        task.wait(0.1)
        dungeon = workspace:FindFirstChild("dungeonName")
    end
    if not c or not dungeon or dungeon.Value ~= "Northern Lands" then return end
    while not workspace:FindFirstChild("Map") and not workspace:FindFirstChild("map") and os.clock() < deadline do task.wait(0.1) end
    -- The folder replicates before its parts. Wait for actual geometry and a
    -- short stable count, rather than marking an empty map as prepared.
    local lastCount, stable = 0, 0
    while os.clock() < deadline and stable < 4 do
        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        local count = map and #map:QueryDescendants("BasePart") or 0
        stable = count > 20 and count == lastCount and stable + 1 or 0
        lastCount = count
        task.wait(0.25)
    end
    c.Character:Refresh()
    local test = { Enabled = true, Changed = {}, Supports = {}, Count = 0, Floors = 0,
        WaterBackup = {}, Guards = {}, Protected = 0, Controller = c, PreviousFlat = c.FlatArena }
    env.UIW_OpenMap = test
    -- This build uses the explicit cleared-pit checkpoint transition below.
    -- The older timeout reset must not kill us while lower mobs remain alive.
    local oldReachHigh = c.ReachHighMobs
    c.ReachHighMobs = function() end
    c.FlatArena = false
    if c.Flat then c.Flat:Disable() c.Flat:Restore() end

    local function protected(p, map)
        -- Inspect every ancestor, including nested barrier models.
        local node = p
        while node and node ~= map do
            local n = node.Name:lower()
            if n:find("barrier", 1, true) or n:find("door", 1, true)
                or n:find("gate", 1, true)
                -- the red, green and yellow totems are the answer to his colour
                -- orbs, so they are never scenery
                or n:find("crystal", 1, true) or n:find("totem", 1, true)
                or node:GetAttribute("UIWKeep") then return true end
            node = node.Parent
        end
        return false
    end
    -- Bob's arena, asked for totally flat. In his room the original walk
    -- surfaces are what is left making it uneven, so nothing is kept as a
    -- support and the artificial floor carries us instead - sitting flush with
    -- the measured height rather than three studs under it, so there is one
    -- continuous plane to circle on and nothing to catch a foot.
    local function inBobRoom()
        local crystals = workspace:FindFirstChild("secondBossCrystals")
        if not crystals then return false end
        local root = c.Character and c.Character.Root
        if not root then return false end
        for _, part in ipairs(crystals:GetDescendants()) do
            if part:IsA("BasePart")
                and (Vector3.new(part.Position.X, 0, part.Position.Z)
                    - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude < 420
            then
                return true
            end
        end
        return false
    end

    local function floorShape(p)
        local n = p.Name:lower()
        -- "plank", "ice3" and "ice plates" came out of this list. Measured
        -- within 400 studs: 52 parts were still solid, and 10 of them were held
        -- up by nothing but those three words - nine planks and an ice plate
        -- that do not look like floors at all. The genuine surfaces among them,
        -- three ice3 slabs and one ice plate, pass the shape test on their own
        -- (the big one is 246 x 11 x 251), so they stay either way. Dropping the
        -- names loses the clutter and keeps every real floor.
        for _, word in ipairs({"floor", "ground", "platform", "ramp", "stair", "step", "arena"}) do
            if n:find(word, 1, true) then return true end
        end
        -- Use the local thin axis and its WORLD normal, not a world-Y box.
        -- This retains rotated floor slabs and sloped bridge decks.
        local s, cf = p.Size, p.CFrame
        local thin, width, depth, normal = s.Y, s.X, s.Z, cf.UpVector
        if s.X < thin then thin, width, depth, normal = s.X, s.Y, s.Z, cf.RightVector end
        if s.Z < thin then thin, width, depth, normal = s.Z, s.X, s.Y, cf.LookVector end
        return math.abs(normal.Y) >= 0.65 and width >= 6 and depth >= 6
            and thin <= math.min(width, depth) * 0.4
    end
    -- Reverted: for one build Bob's room kept no supports, so the artificial
    -- slab became the floor and moved the character up and down as its height
    -- estimate drifted. The real floor is what carries the mobs and it is what
    -- should carry us - its slopes and steps are the arena, not clutter. Only
    -- the decoration comes out.
    local function floor(p)
        return floorShape(p)
    end
    function test:Restore()
        for _, guard in pairs(self.Guards) do guard:Destroy() end
        self.Guards = {}
        for _, saved in ipairs(self.WaterBackup) do
            workspace.Terrain:PasteRegion(saved.Data, saved.Corner, true)
            saved.Data:Destroy()
        end
        self.WaterBackup = {}
        self.WaterReady = false
        for p, saved in pairs(self.Changed) do
            if p.Parent then
                p.CanCollide, p.CanQuery, p.Transparency = saved.Collide, saved.Query, saved.Alpha
                p.LocalTransparencyModifier = saved.LocalAlpha or 0
            end
        end
        self.Changed = {}
        self.Supports = {}
        self.Count = 0
        if self.Platform then self.Platform:Destroy() self.Platform = nil end
        if self.Deep then self.Deep:Destroy() self.Deep = nil end
        self.Height = nil
        self.Lowest = nil
        self.DeepRescue = nil
        self.PitTargetY = nil
        self.DropSince = nil
    end
    function test:RemoveWater()
        if self.WaterReady then return end
        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        if not map then return end
        local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
        for _, p in ipairs(map:QueryDescendants("BasePart")) do
            local cf, s = p.CFrame, p.Size/2
            local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
            local ext = Vector3.new(math.abs(r.X)*s.X+math.abs(u.X)*s.Y+math.abs(l.X)*s.Z,
                math.abs(r.Y)*s.X+math.abs(u.Y)*s.Y+math.abs(l.Y)*s.Z,
                math.abs(r.Z)*s.X+math.abs(u.Z)*s.Y+math.abs(l.Z)*s.Z)
            lo, hi = lo:Min(p.Position-ext), hi:Max(p.Position+ext)
        end
        if lo.X == math.huge then return end
        lo, hi = lo-Vector3.new(64,64,64), hi+Vector3.new(64,64,64)
        -- Small engine-side chunks avoid a huge Lua voxel array. Backup supports undo.
        for x=math.floor(lo.X/256)*256, hi.X, 256 do
            for y=math.floor(lo.Y/256)*256, hi.Y, 256 do
                for z=math.floor(lo.Z/256)*256, hi.Z, 256 do
                    local corner = Vector3int16.new(x/4,y/4,z/4)
                    local backup = workspace.Terrain:CopyRegion(Region3int16.new(corner, Vector3int16.new(x/4+63,y/4+63,z/4+63)))
                    self.WaterBackup[#self.WaterBackup+1] = {Data=backup, Corner=corner}
                    workspace.Terrain:ReplaceMaterial(Region3.new(Vector3.new(x,y,z),Vector3.new(x+256,y+256,z+256)),4,Enum.Material.Water,Enum.Material.Air)
                end
            end
        end
        self.WaterReady = true
    end
    function test:Sweep()
        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        if not map then return end
        if self.Map ~= map then
            if self.MapConnection then self.MapConnection:Disconnect() end
            self.Map = map
            self.MapConnection = map.DescendantAdded:Connect(function(p)
                if p:IsA("BasePart") then self.NeedsSweep = true end
            end)
        end
        local floors, barriers = 0, 0
        for _, p in ipairs(map:QueryDescendants("BasePart")) do
            if not self.Changed[p] then
                if protected(p, map) then barriers += 1
                elseif p.Anchored then
                    self.Changed[p] = {Collide=p.CanCollide, Query=p.CanQuery, Alpha=p.Transparency, LocalAlpha=p.LocalTransparencyModifier}
                    if p.CanCollide and floor(p) then self.Supports[p] = true end
                    -- The real walk surfaces stay SOLID. Only the scenery loses
                    -- its collision.
                    --
                    -- Making them invisible height references and letting one
                    -- flat plane carry us instead is what produced every
                    -- movement bug in this file: falling out from under our own
                    -- floor when it sat too high, the plane refusing to follow
                    -- us into the pit, and worst of all the stand-off - we turn
                    -- collision off on our side only, the server still has the
                    -- floor solid, and a character with no ground on our side
                    -- and ground on theirs hangs in freefall going nowhere.
                    -- Measured: floor at 18, character at -58.5, Freefall at
                    -- zero velocity, indefinitely.
                    --
                    -- The file already said this and then did the opposite: the
                    -- real floor is what carries the mobs and it is what should
                    -- carry us. Its slopes and steps are the arena, not clutter.
                    p.CanCollide = self.Supports[p] == true
                    p.CanQuery = self.Supports[p] == true
                    p.Transparency = 1
                    p.LocalTransparencyModifier = 1
                    self.Count += 1
                end
            end
        end
        self.Floors, self.Protected = floors, barriers
        local refs = {workspace.Terrain}
        for p in pairs(self.Supports) do
            if p.Parent then refs[#refs+1] = p self.Floors += 1 end
        end
        self.Params = RaycastParams.new()
        self.Params.FilterType = Enum.RaycastFilterType.Include
        self.Params.FilterDescendantsInstances = refs
        self.Params.RespectCanCollide = false
        self.Params.IgnoreWater = true
        local rooms = workspace:FindFirstChild("dungeon")
        if rooms then
            for _, p in ipairs(rooms:QueryDescendants("BasePart")) do
                if p.Name:lower() == "physicalbarrier" and p.CanCollide and not self.Guards[p] then
                    local guard = Instance.new("Part")
                    guard.Name = "UIW_ClosedBarrierGuard"
                    guard.Anchored = true
                    guard.Transparency = 1
                    guard.CanTouch = false
                    -- Extend the closed gate across the artificial floor so its
                    -- edges cannot become an unintended route into the next room.
                    --
                    -- Bounded, though. At 4096 x 2048 the guard was not a wider
                    -- gate but an infinite plane through the level: measured
                    -- stuck against one 2 studs ahead while the barrier it
                    -- belonged to was 151 studs away, because anywhere near that
                    -- plane is inside a slab that size. A margin around the real
                    -- gate stops us slipping round its edge without cutting the
                    -- room we are standing in in half.
                    local span = math.max(p.Size.X, p.Size.Z) + 120
                    local tall = p.Size.Y + 80
                    guard.Size = p.Size.X > p.Size.Z and Vector3.new(span,tall,p.Size.Z+2)
                        or Vector3.new(p.Size.X+2,tall,span)
                    guard.CFrame = p.CFrame
                    guard.Parent = workspace
                    self.Guards[p] = guard
                end
            end
        end
    end
    function test:WalkSurface(dt)
        for p, guard in pairs(self.Guards) do
            if not p.Parent or not p.CanCollide then
                guard:Destroy()
                self.Guards[p] = nil
            else guard.CFrame = p.CFrame end
        end
        local root = c.Character.Root
        if not root or not self.Params then return end
        if not self.Platform then
            local p = Instance.new("Part")
            p.Name = "UIW_NorthernFlatFloor"
            p.Anchored = true
            p.Size = Vector3.new(768, 2, 768)
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(180, 202, 220)
            p.CanTouch = false
            self.Platform = p
        end
        -- The catch floor. Once the map is noclipped this platform is the only
        -- solid thing left in the world, so any moment its height is wrong is a
        -- moment there is nothing at all underneath us - and the dungeon has no
        -- bottom, so "nothing underneath us" is a death. That is not a rare
        -- edge case here: self.Height is deliberately dropped to the pit floor
        -- when we descend after Bob, and nothing ever raises it again, so the
        -- climb towards Odin is walked with the real floor switched off and the
        -- artificial one sixty studs below our feet.
        --
        -- So there is now a second plane, well below every floor this dungeon
        -- has shown us, that exists purely to be landed on. Falling is allowed.
        -- Falling forever is not.
        if not self.Deep then
            local p = Instance.new("Part")
            p.Name = "UIW_NorthernCatchFloor"
            p.Anchored = true
            p.Size = Vector3.new(1024, 8, 1024)
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(120, 140, 160)
            p.Transparency = 0.6
            p.CanTouch = false
            self.Deep = p
        end

        local hit = workspace:Raycast(root.Position + Vector3.new(0, 8, 0), Vector3.new(0, -120, 0), self.Params)
        if not self.Height or self.CharacterModel ~= c.Character.Character then
            self.CharacterModel = c.Character.Character
            local h = c.Character.Humanoid
            self.Height = hit and hit.Position.Y or (root.Position.Y - root.Size.Y/2 - (h and h.HipHeight or 2))
        end

        -- Follow the floor, in both directions.
        --
        -- This was a raise-only rule for one build and that was a mistake with
        -- an obvious failure mode: the floor ratchets up to the highest thing
        -- we ever pass over and then stays there, so walking off a raised slab
        -- leaves the only solid surface in the world above our heads and we
        -- drop out from underneath it. Measured in game at exactly that: the
        -- platform at 27.7 with the character at 21, standing under its own
        -- floor.
        --
        -- The height to use is not simply whatever the ray under us hits. Ice3
        -- meshes float over the pit, and one of those directly below us reads
        -- as a floor at 18 while every probe ten studs out reads -61. So take
        -- the middle of a small ring instead of the single sample: a real floor
        -- carries the whole ring and wins, an isolated chunk is outvoted. That
        -- is the same thing the original comment was reaching for when it said
        -- the real floor is what carries the mobs.
        -- The deliberate descent: lower the floor and let it carry us. Slow
        -- enough that we stay standing on it the whole way rather than falling
        -- after it, which is the difference between arriving on the landing we
        -- chose and arriving wherever seventy-four studs of gravity puts us.
        if self.PitDropping and self.PitTargetY then
            self.Height = math.max(self.PitTargetY, self.Height - 55 * math.min(dt or 0.03, 0.1))
        end

        if not self.PitDropping then
            local ring = {}
            if hit then ring[#ring+1] = hit.Position.Y end
            for i = 0, 7 do
                local a = i * math.pi / 4
                local at = root.Position + Vector3.new(math.cos(a) * 11, 6, math.sin(a) * 11)
                local r2 = workspace:Raycast(at, Vector3.new(0, -400, 0), self.Params)
                if r2 then ring[#ring+1] = r2.Position.Y end
            end
            if #ring > 0 then
                table.sort(ring)
                local target = ring[math.ceil(#ring / 2)]
                if target > self.Height then
                    -- Rise like a lift, never like a launch.
                    self.Height = math.min(target, self.Height + 70 * math.min(dt or 0.03, 0.1))
                    self.DropSince = nil
                elseif target < self.Height - 0.75 then
                    -- Confirm a drop before taking it, so a flickering edge
                    -- cannot jolt us, then take it - but only as far as a step
                    -- or a slope. This map is three tiers with a seventy-four
                    -- stud sheer gap between the middle one and the pit, and
                    -- following that automatically is how we end up at the
                    -- bottom of the world with no way back: it is ninety studs
                    -- up to the tier we fell from and a hundred and seventy to
                    -- the one above it. A cliff is the pit logic's business,
                    -- because only it knows whether we are meant to be down
                    -- there yet and where it is safe to land.
                    -- A cliff is only a cliff while we are still standing on
                    -- top of it. Once we are already below our own floor this
                    -- is not a decision to jump off anything, it is a recovery,
                    -- and refusing it is what leaves us floating: we switch the
                    -- map's collision off locally but the server still thinks
                    -- that floor is solid, so a character with nothing under it
                    -- on our side and ground under it on theirs hangs in
                    -- permanent freefall. Measured exactly that - floor at 18,
                    -- character at -58.5, Freefall with no velocity, forever.
                    local fallen = root.Position.Y < self.Height - 10
                    if self.Height - target > 25 and not fallen then
                        -- Hold the floor where it is and let the pit logic
                        -- decide; it is the only thing that knows whether we
                        -- belong down there and where it is safe to land.
                        self.DropSince = nil
                    elseif fallen then
                        -- No confirmation delay here. Every frame we spend
                        -- without a floor is a frame of that stand-off, so take
                        -- the ground the moment we can see it.
                        self.Height, self.DropSince = target, nil
                    else
                        self.DropSince = self.DropSince or os.clock()
                        if os.clock() - self.DropSince > 0.15 then
                            self.Height, self.DropSince = target, nil
                        end
                    end
                else
                    self.Height, self.DropSince = target, nil
                end
                self.Lowest = math.min(self.Lowest or ring[1], ring[1])
            end
        end

        -- How deep this dungeon goes, learned rather than assumed - and it has
        -- to be learned from further away than our own feet. While we hover
        -- above the pit waiting for a clear landing, the floor under us reads
        -- 17 and the pit floor is at -62, so a catch floor placed from the
        -- first number sits forty-eight studs above the ground we are trying
        -- to reach and blocks the descent it was meant to make survivable.
        if os.clock() - (self.DepthAt or 0) > 0.5 then
            self.DepthAt = os.clock()
            for i = 0, 5 do
                local a = i * math.pi / 3
                for _, radius in ipairs({45, 110}) do
                    local at = root.Position + Vector3.new(math.cos(a) * radius, 6, math.sin(a) * radius)
                    local far = workspace:Raycast(at, Vector3.new(0, -600, 0), self.Params)
                    if far then self.Lowest = math.min(self.Lowest or far.Position.Y, far.Position.Y) end
                end
            end
        end
        self.Lowest = math.min(self.Lowest or self.Height, self.Height)

        -- ...which demotes this to a gap filler. It parks three studs under
        -- the surface we just measured, so wherever the map has real floor the
        -- real floor is what we stand on and this only ever catches us over a
        -- hole.
        --
        -- Bob's arena was asked for flat and had this plane carrying us there.
        -- That is off, and not casually: it has now been tried twice and both
        -- times it did the same thing, lifting and dropping the character as
        -- its height estimate drifted. Trading the arena's real slopes for a
        -- flat one is not worth another movement bug. Worth revisiting once
        -- this is stable, with the flatness done by measuring the arena once on
        -- arrival rather than by following us around.
        self.Platform.CFrame = CFrame.new(root.Position.X, self.Height-4, root.Position.Z)
        self.Platform.Parent = workspace

        -- Normally it just sits out of the way, thirty studs under the deepest
        -- floor we have seen, so an intended drop into the pit still happens.
        -- If something has gone wrong enough that we are already below it, it
        -- comes up to meet us and then carries us back at a walking pace -
        -- catching a fall is the whole job, and stranding us at the bottom of
        -- the world instead of killing us there is only half of it.
        local base = self.Lowest - 30
        local want = base
        if root.Position.Y < base + 4 then
            self.DeepRescue = math.min(self.DeepRescue or math.huge, root.Position.Y - 8)
        end
        if self.DeepRescue then
            self.DeepRescue = self.DeepRescue + 45 * math.min(dt or 0.03, 0.1)
            if self.DeepRescue >= base then
                self.DeepRescue = nil
            else
                want = self.DeepRescue
            end
        end
        self.Deep.CFrame = CFrame.new(root.Position.X, want, root.Position.Z)
        self.Deep.Parent = workspace
        -- Map-only noclip. Keep character collision for this floor and barriers.
        for p, saved in pairs(self.Changed) do
            if p.Parent then
                p.CanCollide = false
                p.Transparency = 1
                p.LocalTransparencyModifier = 1
            end
        end
    end
    -- The clearance is an argument now, not a constant. Twenty-two mobs are
    -- alive in that pit and they do not politely leave a forty-eight stud hole
    -- anywhere, so a fixed requirement means no landing is ever found and we
    -- hover above the fight for as long as it lasts. Landing near a mob is a
    -- fight; never landing is not.
    function test:LandingClear(point, enemies, clearance)
        clearance = clearance or 48
        for _, e in ipairs(enemies) do
            if e.Room==6 and e.Root and e.Root.Parent then
                local v=e.Root.AssemblyLinearVelocity
                if v.Magnitude>30 then v=v.Unit*30 end
                for _,dt in ipairs({0,1.2}) do
                    local delta=e.Root.Position+v*dt-point
                    if Vector3.new(delta.X,0,delta.Z).Magnitude<clearance then return false end
                end
            end
        end
        if not c.Hazards:IsFullBodyClear(point,c.Character.DesiredYaw or 0) then return false end
        for _, hazard in ipairs(c.Hazards:GetActive()) do
            local p=hazard.Part
            if p and p.Parent then
                local velocity=c.Hazards:GetProjectileVelocity(hazard)
                for _,dt in ipairs({0,0.6,1.2}) do
                    local q=p.CFrame:PointToObjectSpace(point-velocity*dt)
                    local h=p.Size/2+Vector3.new(10,8,10)
                    if math.abs(q.X)<h.X and math.abs(q.Y)<h.Y and math.abs(q.Z)<h.Z then return false end
                end
            end
        end
        return true
    end
    function test:UpdatePit()
        if not c.Enabled or not c.Character:IsAlive() then return end
        local root = c.Character.Root
        local enemies = c.Dungeon:GetAliveEnemies(true)
        local lower, nextGroup, bobAlive = nil, nil, false
        for _, e in ipairs(enemies) do
            if e.Model.Name == "Bob The Frost Giant" then bobAlive = true end
            -- Live spawn markers identify room6 as the pit (Y about -54);
            -- room5 is still the upper approach after Bob.
            if e.Room == 6 and e.Root.Position.Y < 0 then lower = e end
            if e.Room >= 7 and e.Root.Position.Y > root.Position.Y+22 then nextGroup = e end
        end
        if lower and not bobAlive then
            if not self.PitSeen then self.PitWaitingSince = os.clock() end
            self.PitSeen = true
            self.PitClearAt = nil
            -- However we got here, if we are already down among them then we
            -- are in the pit and there is nothing left to plan. Without this
            -- the status line still reads "moving above clear landing" while we
            -- stand on the pit floor, and the search goes on looking for a
            -- landing below a floor that is already under our feet.
            if root.Position.Y < lower.Root.Position.Y + 20 then
                self.PitEntered = true
                self.PitDropping = false
                self.PitTargetY = nil
                c.Dodger.NLPitLandingGoal = nil
                self.PitStatus = "already in the pit"
            end
            -- Give up ground on the clearance the longer we stand up here doing
            -- nothing: forty-eight studs to start with, then down to twenty
            -- over half a minute. Hovering costs the whole fight; landing close
            -- to a spearman costs one exchange.
            local waited = os.clock() - (self.PitWaitingSince or os.clock())
            local clearance = math.max(20, 48 - waited)
            local offset = Vector3.new(lower.Root.Position.X-root.Position.X,0,lower.Root.Position.Z-root.Position.Z)
            if offset.Magnitude < 200 and not self.PitEntered then
                local guards = {}
                for p,g in pairs(self.Guards) do if p.Parent and p.CanCollide then guards[#guards+1]=g end end
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Include
                params.FilterDescendantsInstances = guards
                local landing=self.PitLanding
                if self.PitDropping then
                    -- Done when the floor has finished travelling, not when we
                    -- happen to be near it: riding it down we are always three
                    -- studs above it, so the old test passed on the first frame.
                    if self.Height <= (self.PitTargetY or self.Height) + 0.5 then
                        self.PitEntered=true
                        self.PitDropping=false
                        self.PitTargetY=nil
                        c.Dodger.NLPitLandingGoal=nil
                        self.PitStatus="landed away from lower mobs"
                    else
                        -- keep steering over the landing while we descend
                        c.Dodger.NLPitLandingGoal=landing
                            and Vector3.new(landing.X,root.Position.Y,landing.Z) or nil
                    end
                    return
                end
                if landing and not self:LandingClear(landing,enemies,clearance) then landing=nil self.PitJumpAt=nil end
                if not landing then
                    self.PitLanding=nil
                    if os.clock()-(self.PitSearchAt or 0)<0.5 then
                        c.Dodger.NLPitLandingGoal=nil
                        return
                    end
                    self.PitSearchAt=os.clock()
                    local bestScore=math.huge
                    for _,radius in ipairs({70,100,130}) do
                        for i=0,15 do
                            local angle=i*math.pi/8
                            local at=lower.Root.Position+Vector3.new(math.cos(angle)*radius,8,math.sin(angle)*radius)
                            local floorHit=workspace:Raycast(at,Vector3.new(0,-100,0),self.Params)
                            if floorHit and floorHit.Normal.Y>0.7 and floorHit.Position.Y<self.Height-20 then
                                local candidate=floorHit.Position+Vector3.new(0,3,0)
                                local travel=Vector3.new(candidate.X-root.Position.X,0,candidate.Z-root.Position.Z)
                                if not workspace:Raycast(root.Position,travel,params)
                                    and not workspace:Raycast(root.Position+Vector3.new(0,candidate.Y-root.Position.Y,0),travel,params)
                                    and self:LandingClear(candidate,enemies,clearance) then
                                    if travel.Magnitude<bestScore then landing=candidate bestScore=travel.Magnitude end
                                end
                            end
                        end
                    end
                    self.PitLanding=landing
                end
                if not landing then
                    c.Dodger.NLPitLandingGoal=nil
                    self.PitStatus=string.format("waiting for a landing with %.0f studs clear", clearance)
                    return
                end
                c.Dodger.NLPitLandingGoal=Vector3.new(landing.X,root.Position.Y,landing.Z)
                local away=Vector3.new(landing.X-root.Position.X,0,landing.Z-root.Position.Z)
                self.PitStatus="moving above clear landing"
                if away.Magnitude<6 and self:LandingClear(Vector3.new(root.Position.X,landing.Y,root.Position.Z),enemies,clearance) then
                    -- Ride down, do not jump off.
                    --
                    -- The map has a seventy-four stud sheer gap between this
                    -- tier and the pit floor - measured, there is no surface of
                    -- any kind in between - so the old sequence jumped and then
                    -- dropped the floor out from under us for the whole of it.
                    -- A fall that long lands where it lands: not on the chosen
                    -- spot, sometimes on the mobs we picked the spot to avoid.
                    --
                    -- We own the floor, so we can lower it instead and travel
                    -- with it. It stays under us the entire way, it stays over
                    -- the landing we chose, and it can be stopped.
                    self.PitTargetY = landing.Y
                    self.PitDropping = true
                    self.PitStatus = "riding the floor down to the landing"
                end
            end
            return
        end
        if not self.PitEntered or not nextGroup or self.PitResetAttempted then return end
        local hardcore = workspace:FindFirstChild("hardcore")
        if hardcore and hardcore.Value then self.PitStatus="reset disabled in hardcore" return end
        self.PitClearAt = self.PitClearAt or os.clock()
        if os.clock()-self.PitClearAt < 2 then return end
        self.PitResetAttempted = true
        self.PitStatus = "lower mobs cleared; resetting to checkpoint"
        local oldCharacter, oldY = c.Character.Character, root.Position.Y
        local retryEnabled = c.AutoRetryEnabled
        c.AutoRetryEnabled = false
        c.Character.Humanoid.Health = 0
        task.spawn(function()
            local deadline = os.clock()+15
            repeat task.wait(0.25) until c.Destroyed or os.clock()>deadline
                or (c.Character.Character~=oldCharacter and c.Character:IsAlive())
            if c.Destroyed then return end
            c.AutoRetryEnabled = retryEnabled
            local newRoot = c.Character.Root
            self.PitResetGain = newRoot and newRoot.Position.Y-oldY or 0
            self.PitStatus = self.PitResetGain>22 and "checkpoint reset confirmed" or "checkpoint reset did not gain height; no repeat"
        end)
    end
    function test:SetEnabled(value)
        self.Enabled = value == true
        if self.Enabled then self:Sweep() self:WalkSurface(0) self:RemoveWater() else self:Restore() end
    end
    function test:Destroy()
        if self.Connection then self.Connection:Disconnect() end
        if self.MapConnection then self.MapConnection:Disconnect() end
        self:Restore()
        c.ReachHighMobs = oldReachHigh
        c.Dodger.NLPitLandingGoal=nil
        c.FlatArena = self.PreviousFlat
        if env.UIW_OpenMap == self then env.UIW_OpenMap = nil end
    end
    -- Restore synchronously on controller reload, before the next build starts.
    local destroy = c.Destroy
    c.Destroy = function(controller, ...)
        test:Destroy()
        return destroy(controller, ...)
    end
    c.Version = tostring(c.Version) .. "-openmap9"
    local elapsed = 0
    test.Connection = game:GetService("RunService").PreSimulation:Connect(function(dt)
        if c.Destroyed or env.UIW ~= c or dungeon.Value ~= "Northern Lands" then
            test:Destroy()
            return
        end
        elapsed += dt
        if test.Enabled then test:WalkSurface(dt) end
        if test.Enabled and os.clock()-(test.PitCheckAt or 0)>=0.1 then
            test.PitCheckAt=os.clock()
            local pitOK,pitErr=pcall(test.UpdatePit,test)
            if not pitOK then test.LastError=tostring(pitErr) end
        end
        if elapsed >= 2 or test.NeedsSweep then
            elapsed = 0
            test.NeedsSweep = false
            if test.Enabled then
                local ok, err = pcall(test.Sweep, test)
                test.LastError = not ok and tostring(err) or nil
                if ok and not test.WaterReady then
                    local waterOK, waterErr = pcall(test.RemoveWater, test)
                    if not waterOK then test.LastError = tostring(waterErr) end
                end
            end
        end
    end)
    test:Sweep()
    test:WalkSurface(0)
    test:RemoveWater()
    test.PreparedBeforeStart = test.WaterReady == true and test.Count > 0
        and workspace:FindFirstChild("dungeonStarted") and not workspace.dungeonStarted.Value
end
