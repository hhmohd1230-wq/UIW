local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.new()
    return setmetatable({
        Character = nil,
        Humanoid = nil,
        Root = nil,
        BodySize = Vector3.new(4.5, 5, 2),
        BodyOffset = Vector3.zero,
        FacingAttachment = nil,
        FacingOrientation = nil,
        DesiredYaw = 0,
        OriginalAutoRotate = true,
    }, CharacterService)
end

function CharacterService:IsAlive()
    return self.Character
        and self.Character.Parent
        and self.Humanoid
        and self.Humanoid.Health > 0
        and self.Root
        and self.Root.Parent
end

function CharacterService:CalculateBodyBounds()
    if not self.Character or not self.Root then
        return
    end

    local rootCF = self.Root.CFrame
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local found = false

    for _, part in ipairs(self.Character:GetChildren()) do
        if part:IsA("BasePart") and BODY_NAMES[part.Name] then
            found = true
            local half = part.Size * 0.5
            for _, x in ipairs({-half.X, half.X}) do
                for _, y in ipairs({-half.Y, half.Y}) do
                    for _, z in ipairs({-half.Z, half.Z}) do
                        local worldPoint = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
                        local p = rootCF:PointToObjectSpace(worldPoint)
                        minX = math.min(minX, p.X)
                        minY = math.min(minY, p.Y)
                        minZ = math.min(minZ, p.Z)
                        maxX = math.max(maxX, p.X)
                        maxY = math.max(maxY, p.Y)
                        maxZ = math.max(maxZ, p.Z)
                    end
                end
            end
        end
    end

    if not found then
        self.BodySize = Vector3.new(4.5, 5, 2)
        self.BodyOffset = Vector3.zero
        return
    end

    self.BodySize = Vector3.new(
        math.max(2, maxX - minX),
        math.max(4, maxY - minY),
        math.max(1.4, maxZ - minZ)
    )

    self.BodyOffset = Vector3.new(
        (minX + maxX) * 0.5,
        (minY + maxY) * 0.5,
        (minZ + maxZ) * 0.5
    )
end

function CharacterService:DestroyFacing()
    safeDestroy(self.FacingOrientation)
    safeDestroy(self.FacingAttachment)
    self.FacingOrientation = nil
    self.FacingAttachment = nil
end

function CharacterService:SetupFacing()
    if not self.Root or not self.Humanoid then
        return
    end

    self:DestroyFacing()

    self.OriginalAutoRotate = self.Humanoid.AutoRotate
    self.Humanoid.AutoRotate = false

    local attachment = Instance.new("Attachment")
    attachment.Name = "UIWFacingAttachment"
    attachment.Parent = self.Root

    local align = Instance.new("AlignOrientation")
    align.Name = "UIWFacing"
    align.Mode = Enum.OrientationAlignmentMode.OneAttachment
    align.Attachment0 = attachment
    align.RigidityEnabled = false
    align.Responsiveness = 50
    align.MaxTorque = math.huge
    align.Parent = self.Root

    self.FacingAttachment = attachment
    self.FacingOrientation = align
end

function CharacterService:SetYaw(yaw)
    self.DesiredYaw = yaw

    if not self.FacingOrientation or not self.FacingOrientation.Parent then
        self:SetupFacing()
    end

    if self.FacingOrientation then
        self.FacingOrientation.CFrame = CFrame.Angles(0, yaw, 0)
    end
end

function CharacterService:ReleaseAutomationFacing()
    if self.Humanoid then
        self.Humanoid.AutoRotate = self.OriginalAutoRotate ~= false
    end
    self:DestroyFacing()
end

function CharacterService:FacePosition(position)
    if not self:IsAlive() then
        return
    end
    local direction = flatten(position - self.Root.Position)
    if direction.Magnitude <= 0.05 then
        return
    end
    self:SetYaw(directionToYaw(direction))
end

function CharacterService:Refresh()
    local character = LocalPlayer.Character
    if not character then
        return false
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return false
    end

    local changed = character ~= self.Character

    self.Character = character
    self.Humanoid = humanoid
    self.Root = root

    if humanoid.WalkSpeed < CONFIG.WalkSpeed then
        humanoid.WalkSpeed = CONFIG.WalkSpeed -- only raise; keeps speed buffs
    end

    if changed then
        self:CalculateBodyBounds()
        self:SetupFacing()
    end

    return true
end

function CharacterService:Destroy()
    if self.Humanoid then
        pcall(function()
            self.Humanoid.AutoRotate = self.OriginalAutoRotate
        end)
    end
    self:DestroyFacing()
end

