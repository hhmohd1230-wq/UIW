local PathESP = {}
PathESP.__index = PathESP

function PathESP.new()
    local folder = Instance.new("Folder")
    folder.Name = "UIW_PathESP"
    folder.Parent = Workspace

    return setmetatable({
        Folder = folder,
        LastUpdate = 0,
    }, PathESP)
end

-- v44: pooled segments. The old version destroyed and re-created every
-- segment 4x per second, which is heavy Instance churn in long dungeons.
local PATH_ESP_MAX_SEGMENTS = 24

function PathESP:GetSegment(index)
    self.Pool = self.Pool or {}
    local part = self.Pool[index]
    if part and part.Parent then
        return part
    end
    part = Instance.new("Part")
    part.Name = "Segment"
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = Color3.fromRGB(240, 195, 55)
    part.Transparency = 1
    part.Parent = self.Folder
    self.Pool[index] = part
    return part
end

function PathESP:Hide()
    if not self.Pool or self.Hidden then
        return
    end
    self.Hidden = true
    for _, part in ipairs(self.Pool) do
        if part.Parent then
            part.Transparency = 1
        end
    end
end

function PathESP:Update(waypoints, currentIndex, rootPosition)
    local now = os.clock()
    if now - self.LastUpdate < CONFIG.PathVisualInterval then return end
    self.LastUpdate = now

    if not waypoints or #waypoints == 0 or not rootPosition then
        self:Hide()
        return
    end

    local points = {rootPosition}
    for i = currentIndex, #waypoints do
        if #points > PATH_ESP_MAX_SEGMENTS then break end
        if waypoints[i] then
            table.insert(points, waypoints[i].Position)
        end
    end

    self.Hidden = false
    local used = 0
    for i = 1, #points - 1 do
        local p1 = points[i]
        local p2 = points[i + 1]
        local distance = (p2 - p1).Magnitude

        if distance > 0.1 then
            used += 1
            local part = self:GetSegment(used)
            part.Size = Vector3.new(0.4, 0.4, distance)
            part.CFrame = CFrame.lookAt(p1, p2) * CFrame.new(0, 0, -distance / 2)
            part.Transparency = 0
        end
    end

    for index = used + 1, #(self.Pool or {}) do
        local part = self.Pool[index]
        if part.Parent and part.Transparency < 1 then
            part.Transparency = 1
        end
    end
end

function PathESP:Destroy()
    if self.Folder then
        self.Folder:Destroy()
    end
end

