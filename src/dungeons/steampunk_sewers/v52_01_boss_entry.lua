-- Keep the Steampunk boss approach on solid ground. Its last walkway can
-- expose a long drop; a dodge or route direction must not step into the gap.
do
    local function groundAt(position, map)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Include
        params.FilterDescendantsInstances = { map }
        params.RespectCanCollide = true
        local hit = Workspace:Raycast(
            position + Vector3.new(0, 2, 0),
            Vector3.new(0, -18, 0),
            params
        )
        if hit and hit.Normal.Y >= 0.55 then
            return hit.Position.Y
        end
        return nil
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled or not self.Character:IsAlive() then
            return
        end
        local name = Workspace:FindFirstChild("dungeonName")
        if not name or name.Value ~= "Steampunk Sewers" then return end

        local root = self.Character.Root
        if root.Position.X < 1320 or root.Position.X > 1460
            or root.Position.Y < -65 or root.Position.Y > 15
        then
            return
        end

        local movement = flatten(self.LastCommandedMovement or Vector3.zero)
        if movement.Magnitude < 0.25 then return end
        local map = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("map")
        if not map then return end

        local currentGround = groundAt(root.Position, map)
        local ahead = root.Position + movement.Unit * 6
        local aheadGround = groundAt(ahead, map)
        if not aheadGround or (currentGround and currentGround - aheadGround > 8) then
            self.Character.Humanoid:Move(Vector3.zero, false)
            self.LastCommandedMovement = Vector3.zero
            if os.clock() - (self.SteamEdgeRepathAt or 0) > 1 then
                self.SteamEdgeRepathAt = os.clock()
                self.Route:InvalidateGoal()
            end
            self.HUD:SetStatus("PATHING", "boss walkway edge | finding safe ground")
        end
    end

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = tostring(self.Version) .. "+steamedge"
        return self
    end
end
