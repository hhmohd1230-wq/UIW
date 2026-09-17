local HitboxESP = {}
HitboxESP.__index = HitboxESP

function HitboxESP.new(hazardTracker)
    local folder = Instance.new("Folder")
    folder.Name = "UIW_HitboxESP"
    folder.Parent = Workspace

    return setmetatable({
        HazardTracker = hazardTracker,
        Folder = folder,
        Entries = {},
        EntryConnections = {},
        Enabled = true,
        LastUpdate = 0,
    }, HitboxESP)
end

function HitboxESP:GetContainer(part)
    return self.HazardTracker:GetContainer(part)
end

function HitboxESP:IsContainerVisuallyActive(container)
    return self.HazardTracker:IsContainerActive(container, os.clock())
end

function HitboxESP:IsContainerStableActive(container, now)
    return self.HazardTracker:IsContainerActive(container, now)
end

function HitboxESP:GetDistanceToPart(part, point)
    local p = part.CFrame:PointToObjectSpace(point)
    local h = part.Size * 0.5

    local dx = math.max(math.abs(p.X) - h.X, 0)
    local dy = math.max(math.abs(p.Y) - h.Y, 0)
    local dz = math.max(math.abs(p.Z) - h.Z, 0)

    return Vector3.new(dx, dy, dz).Magnitude
end

function HitboxESP:Create(part)
    if self.Entries[part] or not part or not part.Parent then
        return
    end

    local box = Instance.new("SelectionBox")
    box.Name = "UIWHitboxOutline"
    box.Adornee = part
    box.LineThickness = 0.025
    box.SurfaceTransparency = 1

    if string.find(string.lower(part.Name), "precast") then
        box.Color3 = Color3.fromRGB(255, 190, 65)
        box.SurfaceColor3 = Color3.fromRGB(255, 190, 65)
    else
        box.Color3 = Color3.fromRGB(255, 65, 85)
        box.SurfaceColor3 = Color3.fromRGB(255, 65, 85)
    end

    box.Parent = self.Folder
    self.Entries[part] = box

    self.EntryConnections[part] = part.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            self:Remove(part)
        end
    end)
end

function HitboxESP:Remove(part)
    local connection = self.EntryConnections[part]
    if connection then
        pcall(function()
            connection:Disconnect()
        end)
        self.EntryConnections[part] = nil
    end

    safeDestroy(self.Entries[part])
    self.Entries[part] = nil
end

function HitboxESP:Update(force)
    local now = os.clock()
    if not force and now - self.LastUpdate < CONFIG.ESPInterval then
        return
    end
    self.LastUpdate = now

    if not self.Enabled then
        for part in pairs(self.Entries) do
            self:Remove(part)
        end
        return
    end

    local character = self.HazardTracker.CharacterService
    local root = character.Root
    local rootPosition = root and root.Position

    if not rootPosition then
        return
    end

    local camera = Workspace.CurrentCamera
    local cameraPosition = camera and camera.CFrame.Position

    local candidates = {}

    for _, hazard in ipairs(self.HazardTracker:GetActive()) do
        local part = hazard.Part

        if part and part.Parent then
            local distance = self:GetDistanceToPart(part, rootPosition)
            local inside = distance <= 0.05

            if not inside and cameraPosition then
                inside = self:GetDistanceToPart(part, cameraPosition) <= 0.05
            end

            if distance <= CONFIG.ESPRenderDistance
                and (not CONFIG.ESPHideWhileInside or not inside)
            then
                candidates[#candidates + 1] = {
                    Part = part,
                    Distance = distance,
                }
            end
        end
    end

    if #candidates > 1 then
        table.sort(candidates, function(a, b)
            return a.Distance < b.Distance
        end)
    end

    local seen = {}
    local maxEntries = math.min(CONFIG.ESPMaxEntries, #candidates)

    for i = 1, maxEntries do
        local part = candidates[i].Part
        seen[part] = true

        if not self.Entries[part] then
            self:Create(part)
        end
    end

    for part in pairs(self.Entries) do
        if not part.Parent or not seen[part] then
            self:Remove(part)
        end
    end
end

function HitboxESP:Destroy()
    for part in pairs(self.Entries) do
        self:Remove(part)
    end
    safeDestroy(self.Folder)
end

