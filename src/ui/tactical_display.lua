local TacticalDisplay = {}
TacticalDisplay.__index = TacticalDisplay

function TacticalDisplay.new(character, hazards, geometry, dungeon, dodger)
    local folder = Instance.new("Folder")
    folder.Name = "UIW_TacticalDisplay"
    folder.Parent = Workspace

    return setmetatable({
        Character = character,
        Hazards = hazards,
        Geometry = geometry,
        Dungeon = dungeon,
        Dodger = dodger,
        Folder = folder,
        AuraDots = {},
        GroupRings = {},
        ShowAura = true,
        ShowMobGroups = true,
        LastUpdate = 0,
    }, TacticalDisplay)
end

function TacticalDisplay:CreateDot(parent, name, color, size)
    local dot = Instance.new("Part")
    dot.Name = name
    dot.Shape = Enum.PartType.Ball
    dot.Size = Vector3.new(size, size, size)
    dot.Anchored = true
    dot.CanCollide = false
    dot.CanTouch = false
    dot.CanQuery = false
    dot.CastShadow = false
    dot.Material = Enum.Material.Neon
    dot.Color = color
    dot.Transparency = 0.16
    dot.Parent = parent
    return dot
end

function TacticalDisplay:EnsureAuraDots()
    local required = CONFIG.AuraDotsPerRing
    while #self.AuraDots < required do
        table.insert(self.AuraDots, self:CreateDot(
            self.Folder,
            "AuraDot",
            Color3.fromRGB(58, 205, 255),
            0.48
        ))
    end
end

function TacticalDisplay:UpdateAura(root)
    self:EnsureAuraDots()

    if not self.ShowAura then
        for _, dot in ipairs(self.AuraDots) do dot.Transparency = 1 end
        return nil, nil
    end

    local threat, distance = self.Hazards:GetAuraThreat(root.Position, CONFIG.AuraRadius)
    local center = root.Position - Vector3.new(0, 2.65, 0)
    local forward = unit(flatten(root.CFrame.LookVector))
    local yaw = directionToYaw(forward)
    local selected = self.Dodger and self.Dodger.SelectedAuraPoint
    local selectedRadius = selected and flatten(selected - root.Position).Magnitude or math.huge
    local ringIndex = math.floor(os.clock() / CONFIG.AuraRingStepTime) % #CONFIG.AuraScanRadii + 1
    local radius = CONFIG.AuraScanRadii[ringIndex]

    for index, dot in ipairs(self.AuraDots) do
        local angle = ((index - 1) / CONFIG.AuraDotsPerRing) * math.pi * 2
        local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local testPoint = root.Position + direction * radius

        -- v44.7: cheap display only (no wall casts / trajectory sweeps per dot).
        local attackThreat = self.Hazards:GetPointThreat(testPoint) > 0
        local enemyThreat = self.Dungeon:GetEnemyDangerAt(testPoint) ~= nil
        local combatThreat = attackThreat or enemyThreat
        local reachable = true

        local selectionTolerance = math.max(1.5, radius * math.pi / CONFIG.AuraDotsPerRing)
        local isSelected = selected
            and math.abs(selectedRadius - radius) <= 1.5
            and flatten(testPoint - selected).Magnitude <= selectionTolerance
        dot.Position = center + direction * radius
        dot.Color = isSelected and Color3.fromRGB(255, 225, 70)
            or (combatThreat and Color3.fromRGB(255, 58, 84)
            or (reachable and Color3.fromRGB(48, 230, 153) or Color3.fromRGB(90, 145, 170)))
        dot.Size = Vector3.one * (isSelected and 0.82 or 0.48)
        dot.Transparency = self.ShowAura and (combatThreat and 0.18 or 0.12) or 1
    end

    return threat, distance
end

function TacticalDisplay:EnsureGroupRing(key)
    local ring = self.GroupRings[key]
    if ring then return ring end

    ring = {}
    for index = 1, CONFIG.MobGroupDotCount do
        table.insert(ring, self:CreateDot(
            self.Folder,
            "MobGroup_" .. tostring(key) .. "_" .. tostring(index),
            Color3.fromRGB(255, 174, 55),
            0.62
        ))
    end
    self.GroupRings[key] = ring
    return ring
end

function TacticalDisplay:UpdateMobGroups(targetEnemy)
    local groups = {}
    for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
        if enemy.Root and enemy.Root.Parent then
            local key = enemy.Room or 999
            local group = groups[key]
            if not group then
                group = {Enemies = {}, Center = Vector3.zero}
                groups[key] = group
            end
            table.insert(group.Enemies, enemy)
            group.Center += enemy.Root.Position
        end
    end

    for key, ring in pairs(self.GroupRings) do
        if not groups[key] then
            for _, dot in ipairs(ring) do safeDestroy(dot) end
            self.GroupRings[key] = nil
        elseif not self.ShowMobGroups then
            for _, dot in ipairs(ring) do dot.Transparency = 1 end
        end
    end

    if not self.ShowMobGroups then return end

    for key, group in pairs(groups) do
        group.Center /= #group.Enemies
        local radius = 16
        for _, enemy in ipairs(group.Enemies) do
            radius = math.max(radius, flatten(enemy.Root.Position - group.Center).Magnitude + 8)
        end
        radius = math.min(radius, 62)

        local ring = self:EnsureGroupRing(key)
        local center = group.Center - Vector3.new(0, 2.8, 0)
        local targetGroup = targetEnemy and targetEnemy.Room == key
        for index, dot in ipairs(ring) do
            local angle = ((index - 1) / #ring) * math.pi * 2
            dot.Position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
            dot.Color = targetGroup and Color3.fromRGB(48, 230, 153) or Color3.fromRGB(255, 174, 55)
            dot.Transparency = 0.20
        end
    end
end

function TacticalDisplay:Update(showAura, showMobGroups, targetEnemy)
    local now = os.clock()
    if now - self.LastUpdate < CONFIG.TacticalVisualInterval then return end
    self.LastUpdate = now
    self.ShowAura = showAura
    self.ShowMobGroups = showMobGroups

    local root = self.Character.Root
    if not root or not root.Parent then return end
    self:UpdateAura(root)
    self:UpdateMobGroups(targetEnemy)
end

function TacticalDisplay:Destroy()
    safeDestroy(self.Folder)
end

