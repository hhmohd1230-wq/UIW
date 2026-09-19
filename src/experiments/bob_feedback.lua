-- Optional open-map build only; Bob-specific aiming and observed damage feedback.
do
    local c = getgenv().UIW
    local d = workspace:FindFirstChild("dungeonName")
    if not c or not d or d.Value ~= "Northern Lands" then return end
    local stats = {Casts=0, HealthDrops=0, NoDrop=0, MissStreak=0, Samples={}, Moves={}}
    c.BobFeedback = stats
    local combat = c.Combat
    local oldPress = combat.Press
    function combat:Press(slot)
        local enemy = c.CurrentEnemy
        local tool = self:GetTool(slot)
        if not enemy or enemy.Model.Name ~= "Bob The Frost Giant" or not tool or self:IsBuffTool(tool) then
            return oldPress(self, slot)
        end
        local root, target = c.Character.Root, enemy.Root
        if not root or not target or not target.Parent then return end
        local delta = Vector3.new(target.Position.X-root.Position.X,0,target.Position.Z-root.Position.Z)
        local usefulRange = stats.LastDamageRange and math.clamp(stats.LastDamageRange+10,60,100) or 100
        if delta.Magnitude > usefulRange then
            stats.WaitingForRange = true
            return
        end
        stats.WaitingForRange = false
        c.Character:FacePosition(target.Position)
        -- AlignOrientation takes time to turn. Don't spend the spell while it
        -- is still facing away; movement/dodging continues during this check.
        local look = Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
        if delta.Magnitude>1 and look.Magnitude>0.1 and look.Unit:Dot(delta.Unit)<0.985 then
            stats.WaitingForAim = true
            return
        end
        stats.WaitingForAim = false
        local h = enemy.Humanoid
        local hp, range = h.Health, delta.Magnitude
        stats.Casts += 1
        local sample = {Range=range, Before=hp, Tool=tool.Name, At=os.clock()}
        stats.Samples[#stats.Samples+1] = sample
        if #stats.Samples>30 then table.remove(stats.Samples,1) end
        oldPress(self, slot)
        task.delay(2.5, function()
            if c.Destroyed then return end
            if not h.Parent then sample.Result="target removed" return end
            sample.Drop = math.max(0,hp-h.Health)
            if sample.Drop>0 then
                stats.HealthDrops += 1
                stats.MissStreak = 0
                stats.LastDamageRange = range
            else
                stats.NoDrop += 1
                stats.MissStreak += 1
            end
        end)
    end
    local oldSolve = c.Dodger.Solve
    function c.Dodger:Solve(route, enemy, yaw)
        if not enemy or enemy.Model.Name ~= "Bob The Frost Giant" then return oldSolve(self,route,enemy,yaw) end
        local savedRange = CONFIG.NLBossCastRange
        -- Repeated no-damage observations request a closer position, but keep
        -- the existing hazard scorer in control of the actual dodge direction.
        CONFIG.NLBossCastRange = stats.MissStreak>=2 and 60
            or (stats.LastDamageRange and math.clamp(stats.LastDamageRange+10,60,100) or 100)
        local ok, direction, facing, emergency, dodging = pcall(oldSolve,self,route,enemy,yaw)
        CONFIG.NLBossCastRange=savedRange
        for name in pairs(self.NLNames or {}) do stats.Moves[name]=true end
        if not ok then error(direction) end
        return direction,facing,emergency,dodging
    end
end
