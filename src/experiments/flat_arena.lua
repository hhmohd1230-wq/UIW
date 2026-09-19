-- EXPERIMENT (branch experiment-flatmap): flat boss arenas + sharper dodging.
--
-- In a boss fight the decoration around the arena (trees, rocks, bridges,
-- railings) is switched off on this client only: collisions off and hidden.
-- The floor is never touched, so there is nothing to fall through. With the
-- clutter gone every direction the dodge solver picks is actually walkable,
-- the frame rate goes up, and the hazard tracker gets more time per frame.
--
-- Everything is restored when the fight ends or the script is unloaded.
-- Toggle: "Flat Arena" in the Automation tab (getgenv().UIW.FlatArena).
do
    CONFIG.FlatArena = true
    CONFIG.FlatArenaRadius = 260          -- studs around the boss
    CONFIG.FlatArenaFloorBand = 5         -- anything whose top is this far above the floor is clutter
    CONFIG.FlatArenaMaxSize = 600         -- skip enormous parts (whole platforms)
    CONFIG.FlatArenaRescan = 2            -- seconds between sweeps
    CONFIG.FlatArenaBossRange = 300
    CONFIG.FlatArenaMobRange = 130

    -- sharper reactions while the arena is flat
    CONFIG.FlatDodgeSolveInterval = 1 / 30
    CONFIG.FlatHazardCacheInterval = 1 / 30
    CONFIG.FlatPrecastLookaheadTime = 1.15
    CONFIG.FlatDangerLookaheadDistance = 16

    local FlatArena = {}
    FlatArena.__index = FlatArena

    function FlatArena.new(controller)
        local params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.MaxParts = 1200
        return setmetatable({
            Controller = controller,
            Active = false,
            Changed = {},          -- [part] = { CanCollide, Transparency }
            Count = 0,
            LastScan = 0,
            Params = params,
            Saved = nil,
        }, FlatArena)
    end

    function FlatArena:MapRoots()
        local roots = {}
        for _, name in ipairs({ "map", "Map" }) do
            local model = Workspace:FindFirstChild(name)
            if model then
                table.insert(roots, model)
            end
        end
        return roots
    end

    function FlatArena:FloorY()
        local root = self.Controller.Character.Root
        if not root then
            return nil
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { self.Controller.Character.Character }
        params.RespectCanCollide = true
        local hit = Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params)
        return hit and hit.Position.Y or (root.Position.Y - 3)
    end

    function FlatArena:Sweep(center)
        local roots = self:MapRoots()
        if #roots == 0 then
            return
        end
        local floorY = self:FloorY()
        if not floorY then
            return
        end
        self.Params.FilterDescendantsInstances = roots
        local ok, parts = pcall(function()
            return Workspace:GetPartBoundsInRadius(center, CONFIG.FlatArenaRadius, self.Params)
        end)
        if not ok or type(parts) ~= "table" then
            return
        end
        for _, part in ipairs(parts) do
            if part:IsA("BasePart")
                and not self.Changed[part]
                and part.CanCollide
                and part.Anchored                  -- moving parts are left alone
                and part.Size.Magnitude <= CONFIG.FlatArenaMaxSize
            then
                local half = part.Size.Y * 0.5
                local top = part.Position.Y + half
                local bottom = part.Position.Y - half
                -- clutter = stands above the floor and does not form the floor
                if top > floorY + CONFIG.FlatArenaFloorBand and bottom > floorY - 1 then
                    self.Changed[part] = {
                        CanCollide = part.CanCollide,
                        Transparency = part.Transparency,
                    }
                    self.Count += 1
                    pcall(function()
                        part.CanCollide = false
                        part.Transparency = 1
                    end)
                end
            end
        end
    end

    function FlatArena:Restore()
        for part, saved in pairs(self.Changed) do
            if part.Parent then
                pcall(function()
                    part.CanCollide = saved.CanCollide
                    part.Transparency = saved.Transparency
                end)
            end
        end
        self.Changed = {}
        self.Count = 0
    end

    function FlatArena:Enable()
        if self.Active then
            return
        end
        self.Active = true
        self.Saved = {
            DodgeSolveInterval = CONFIG.DodgeSolveInterval,
            HazardCacheInterval = CONFIG.HazardCacheInterval,
            PrecastLookaheadTime = CONFIG.PrecastLookaheadTime,
            DangerLookaheadDistance = CONFIG.DangerLookaheadDistance,
        }
        CONFIG.DodgeSolveInterval = CONFIG.FlatDodgeSolveInterval
        CONFIG.HazardCacheInterval = CONFIG.FlatHazardCacheInterval
        CONFIG.PrecastLookaheadTime = CONFIG.FlatPrecastLookaheadTime
        CONFIG.DangerLookaheadDistance = CONFIG.FlatDangerLookaheadDistance
        self.LastScan = 0
    end

    function FlatArena:Disable()
        if not self.Active then
            return
        end
        self.Active = false
        for key, value in pairs(self.Saved or {}) do
            CONFIG[key] = value
        end
        self.Saved = nil
        self:Restore()
    end

    function FlatArena:Step(now)
        if not self.Active then
            return
        end
        if now - self.LastScan < CONFIG.FlatArenaRescan then
            return
        end
        self.LastScan = now
        local enemy = self.Controller.CurrentEnemy
        local root = self.Controller.Character.Root
        local center = enemy and enemy.Root and enemy.Root.Parent and enemy.Root.Position
            or (root and root.Position)
        if center then
            self:Sweep(center)
        end
    end

    ---------------------------------------------------------------------------
    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    local function bossNearby(controller)
        local enemy = controller.CurrentEnemy
        local root = controller.Character.Root
        if not root or not enemy or not enemy.Root or not enemy.Root.Parent then
            return false
        end
        local range = (enemy.Root.Position - root.Position).Magnitude
        if isBossEnemy(enemy) then
            return range <= CONFIG.FlatArenaBossRange
        end
        -- Northern Lands mobs are fought by circling them, and scenery is what
        -- breaks a circle - you get half way round and walk into a rock. Same
        -- client-side clearing as the boss arenas: collision off and hidden for
        -- decoration only, never the floor, all restored afterwards.
        return inNorthernLands() and range <= CONFIG.FlatArenaMobRange
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Flat = FlatArena.new(self)
        if self.FlatArena == nil then
            self.FlatArena = CONFIG.FlatArena
        end
        self.Version = "45-flat"
        local hud = self.HUD
        if hud and hud.AddToggleRow and hud.Pages and hud.Pages.Automation then
            hud.AddToggleRow(hud.Pages.Automation, 10, "Flat Arena (test)",
                "In boss fights: hides and un-solids the scenery, sharper dodging",
                function() return self.FlatArena ~= false end,
                function(value)
                    self.FlatArena = value
                    if not value then
                        self.Flat:Disable()
                    end
                end)
        end
        return self
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed then
            return
        end
        local now = os.clock()
        if now - (self.FlatCheckAt or 0) >= 0.5 then
            self.FlatCheckAt = now
            if self.FlatArena and self.Enabled and bossNearby(self) then
                self.FlatHoldUntil = now + 6
                self.Flat:Enable()
            elseif self.Flat.Active and now > (self.FlatHoldUntil or 0) then
                self.Flat:Disable()
            end
        end
        pcall(self.Flat.Step, self.Flat, now)
    end

    local oldDestroy = UIWController.Destroy
    function UIWController:Destroy()
        pcall(function() self.Flat:Disable() end)
        return oldDestroy(self)
    end

    local oldApply = UIWController.ApplySettings
    function UIWController:ApplySettings(settings)
        if type(settings) == "table" and type(settings.FlatArena) == "boolean" then
            self.FlatArena = settings.FlatArena
        end
        return oldApply(self, settings)
    end

    local oldGet = UIWController.GetSettings
    function UIWController:GetSettings()
        local settings = oldGet(self)
        settings.FlatArena = self.FlatArena ~= false
        return settings
    end
end

