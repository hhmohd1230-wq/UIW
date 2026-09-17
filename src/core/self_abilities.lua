local SelfAbilityTracker = {}
SelfAbilityTracker.__index = SelfAbilityTracker

function SelfAbilityTracker.new()
    return setmetatable({
        Ignore = setmetatable({}, { __mode = "k" }),
        LastLocalCast = {},
        Maid = Maid.new(),
    }, SelfAbilityTracker)
end

function SelfAbilityTracker:RegisterCast(slot)
    self.LastLocalCast[slot] = os.clock()
end

function SelfAbilityTracker:MarkOwn(instance)
    if instance then
        self.Ignore[instance] = true
    end
end

function SelfAbilityTracker:IsOwn(instance)
    if not instance then
        return false
    end
    if self.Ignore[instance] then
        return true
    end
    local current = instance
    while current and current ~= Workspace do
        if self.Ignore[current] then
            return true
        end
        current = current.Parent
    end
    return false
end

function SelfAbilityTracker:Start()
    self.Maid:Give(Workspace.ChildAdded:Connect(function(child)
        if child.Name ~= "genericNeonBall" then
            return
        end
        local castTime = self.LastLocalCast.e
        if not castTime then
            return
        end
        local age = os.clock() - castTime
        if age >= 0 and age <= 1.65 then
            self:MarkOwn(child)
        end
    end))
end

function SelfAbilityTracker:Destroy()
    self.Maid:Clean()
end

