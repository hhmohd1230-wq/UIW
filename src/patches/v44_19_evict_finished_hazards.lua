-- v44.19: permanently evict attack parts after the normal activity detector
-- has observed the effect and then declared its container finished.  This does
-- not destroy server-owned instances; it removes only stale local hazard data.
do
    local oldContainerActiveRetire = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        local state = container and self.ContainerState[container] or nil
        if state and state.UIWRetired then
            return false
        end

        local active = oldContainerActiveRetire(self, container, now)
        state = container and self.ContainerState[container] or nil
        if state and state.RawActive then
            state.UIWWasActive = true
        end

        if state and state.UIWWasActive and not active and not state.UIWRetired then
            state.UIWRetired = true
            local full = self.FullHazards or self.Hazards
            for _, object in ipairs(container:GetDescendants()) do
                if object:IsA("BasePart") then
                    full[object] = nil
                    self.Hazards[object] = nil
                    if self.NearHazards then self.NearHazards[object] = nil end
                end
            end
            self.LastCacheTime = 0
        end

        return active
    end
end

