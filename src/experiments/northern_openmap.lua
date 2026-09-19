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
    c.FlatArena = false
    if c.Flat then c.Flat:Disable() c.Flat:Restore() end

    local function protected(p, map)
        -- Inspect every ancestor, including nested barrier models.
        local node = p
        while node and node ~= map do
            local n = node.Name:lower()
            if n:find("barrier", 1, true) or n:find("door", 1, true)
                or n:find("gate", 1, true)
                or node:GetAttribute("UIWKeep") then return true end
            node = node.Parent
        end
        return false
    end
    local function floor(p)
        local n = p.Name:lower()
        for _, word in ipairs({"floor", "ground", "platform", "ramp", "stair", "step", "arena", "plank", "ice3", "ice plates"}) do
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
        self.Height = nil
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
                    -- Actual stairs, ramps and upper decks must stay physical:
                    -- a height sample alone cannot lift us onto an upper floor.
                    if self.Supports[p] then
                        p.CanQuery = true
                        p.LocalTransparencyModifier = 0
                    else
                        p.CanCollide = false
                        p.CanQuery = false
                        p.Transparency = 1
                        p.LocalTransparencyModifier = 1
                    end
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
                    guard.Size = p.Size.X > p.Size.Z and Vector3.new(4096,2048,p.Size.Z+2)
                        or Vector3.new(p.Size.X+2,2048,4096)
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
            p.Size = Vector3.new(512, 2, 512)
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(180, 202, 220)
            p.CanTouch = false
            self.Platform = p
        end
        local hit = workspace:Raycast(root.Position + Vector3.new(0, 8, 0), Vector3.new(0, -120, 0), self.Params)
        if not self.Height then
            local h = c.Character.Humanoid
            self.Height = hit and hit.Position.Y or (root.Position.Y - root.Size.Y/2 - (h and h.HipHeight or 2))
        elseif hit then
            self.Height += math.clamp(hit.Position.Y-self.Height, -30*dt, 30*dt)
        end
        -- Keep the fallback below the real surface so original steps/ramps
        -- carry the character instead of being covered by a moving flat slab.
        self.Platform.CFrame = CFrame.new(root.Position.X, self.Height-3, root.Position.Z)
        self.Platform.Parent = workspace
        -- Map-only noclip. Keep character collision for this floor and barriers.
        for p, saved in pairs(self.Changed) do
            if p.Parent then
                if self.Supports[p] then
                    p.CanCollide = saved.Collide
                    p.CanQuery = true
                    p.Transparency = saved.Alpha
                    p.LocalTransparencyModifier = 0
                else
                    p.CanCollide = false
                    p.Transparency = 1
                    p.LocalTransparencyModifier = 1
                end
            end
        end
    end
    function test:SetEnabled(value)
        self.Enabled = value == true
        if self.Enabled then self:Sweep() self:WalkSurface(0) self:RemoveWater() else self:Restore() end
    end
    function test:Destroy()
        if self.Connection then self.Connection:Disconnect() end
        if self.MapConnection then self.MapConnection:Disconnect() end
        self:Restore()
        c.FlatArena = self.PreviousFlat
        if env.UIW_OpenMap == self then env.UIW_OpenMap = nil end
    end
    -- Restore synchronously on controller reload, before the next build starts.
    local destroy = c.Destroy
    c.Destroy = function(controller, ...)
        test:Destroy()
        return destroy(controller, ...)
    end
    c.Version = tostring(c.Version) .. "-openmap6"
    local elapsed = 0
    test.Connection = game:GetService("RunService").PreSimulation:Connect(function(dt)
        if c.Destroyed or env.UIW ~= c or dungeon.Value ~= "Northern Lands" then
            test:Destroy()
            return
        end
        elapsed += dt
        if test.Enabled then test:WalkSurface(dt) end
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
