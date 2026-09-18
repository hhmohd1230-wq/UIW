-- v44.29: Northern Lands - spend the speed buff on escapes, not just travel.
--
-- The travel buff only fires while walking between rooms with nothing near us.
-- The two attacks that actually need speed are the Champion's stomp, where a
-- 67 stud circle lands on your head and you have to clear ~45 studs, and the
-- whirlwinds, which cross the arena in a straight line and are only survivable
-- if you get out of the lane in time. At 16 walk speed the stomp circle is a
-- 2.8 second walk; at the buffed 24 it is 1.9, which is the difference between
-- leaving and not.
do
    CONFIG.NLEscapeBuff = true
    CONFIG.NLEscapeBuffInterval = 0.4     -- how often we are allowed to consider it
    CONFIG.NLSlamBuffPad = 6              -- inside circle + this, spend the buff
    CONFIG.NLRushSpeed = 22               -- studs/s that counts as a charging attack
    CONFIG.NLRushWindow = 1.6             -- seconds ahead we care about it
    CONFIG.NLRushMiss = 12                -- how close its path comes before it matters

    -- Retreating to the rim when he returns to the pillar is the right idea for
    -- a human and wrong for this script, measured twice:
    --   stay close          41-52s, 1 death,  50-61% of the fight in cast range
    --   run out on beams    93-114s, 5-6 deaths, 13-18% in range
    --   run out on his return 93-106s, 5 deaths, 13-15% in range
    -- The run costs ~4.4s each way and the script does not come back quickly,
    -- so the fight doubles in length - which means more Sun-Bursts survived,
    -- not fewer. Killing him before the next cycle is the better defence.
    -- Set this above zero to turn the retreat back on.
    CONFIG.NLSunburstRun = 0       -- seconds we stay out after he returns to the pillar
    CONFIG.NLPillarNear = 28       -- horizontally this close to the pillar counts as on it
    CONFIG.NLPillarHigh = 12       -- and this far above us

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- are we standing in a stomp circle?
    local function slamPush(root)
        local worst = 0
        for _, model in ipairs(Workspace:GetChildren()) do
            if model.Name == "firstBossJumpSlam" then
                local box = model:FindFirstChild("hitBox", true)
                if box and box:IsA("BasePart") then
                    local keepOut = math.max(box.Size.X, box.Size.Z) * 0.5 + CONFIG.NLSlamBuffPad
                    local away = flatten(root.Position - box.Position).Magnitude
                    worst = math.max(worst, keepOut - away)
                end
            end
        end
        return worst
    end

    -- is something fast on a line that passes close to us soon?
    local function rushIncoming(self, root)
        local hazards = self.Hazards
        for _, data in ipairs(hazards.CachedActive or {}) do
            local part = data.Part
            if part and part.Parent then
                local velocity = flatten(hazards:GetProjectileVelocity(data))
                local speed = velocity.Magnitude
                if speed >= CONFIG.NLRushSpeed then
                    local offset = flatten(root.Position - part.Position)
                    local closing = -offset:Dot(velocity.Unit)
                    if closing > 0 then
                        local when = closing / speed
                        if when <= CONFIG.NLRushWindow then
                            -- how far off our position its path passes
                            local miss = (offset + velocity.Unit * closing).Magnitude
                            local reach = math.max(part.Size.X, part.Size.Z) * 0.5
                            if miss <= CONFIG.NLRushMiss + reach then
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    function UIWController:TryNorthernEscapeBuff()
        if not CONFIG.NLEscapeBuff or not self.AutoCombat or not inNorthernLands() then
            return false
        end
        local now = os.clock()
        if now - (self.NLBuffAt or 0) < CONFIG.NLEscapeBuffInterval then
            return false
        end
        self.NLBuffAt = now

        local character = self.Character
        local root = character and character.Root
        if not root or not character:IsAlive() then
            return false
        end
        local humanoid = character.Humanoid
        if humanoid and humanoid.WalkSpeed > CONFIG.WalkSpeed + 1 then
            return false      -- already running fast
        end

        local need = slamPush(root) > 0
        if not need then
            local ok, rushing = pcall(rushIncoming, self, root)
            need = ok and rushing
        end
        if not need then
            return false
        end

        local combat = self.Combat
        if not combat or not combat:CanSendInput() or combat:IsBusyCasting() then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool and combat:IsBuffTool(tool) and combat:IsReady(slot) then
                combat:Press(slot)
                self.NLEscapeBuffs = (self.NLEscapeBuffs or 0) + 1
                return true
            end
        end
        return false
    end

    -- He leaves the pillar for the stomp and comes back for Sun-Burst. The
    -- coming back is the part worth watching: dodging that one near the middle
    -- is not realistic, so it is the cue to leave.
    function UIWController:WatchChampionReturn()
        if not inNorthernLands() then
            return
        end
        local enemy = self.CurrentEnemy
        if not enemy or not enemy.Model
            or normalizeEnemyName(enemy.Model.Name) ~= "midgardian champion"
            or not enemy.Root or not enemy.Root.Parent
        then
            self.NLOnPillar = false
            return
        end
        local root = self.Character and self.Character.Root
        local pivot = self.Dodger and self.Dodger.NLPivot
        if not root or not pivot then
            return
        end
        local across = flatten(enemy.Root.Position - Vector3.new(pivot.X, enemy.Root.Position.Y, pivot.Z)).Magnitude
        local above = enemy.Root.Position.Y - root.Position.Y
        local onPillar = across <= CONFIG.NLPillarNear and above >= CONFIG.NLPillarHigh
        if onPillar and not self.NLOnPillar and CONFIG.NLSunburstRun > 0 then
            self.Dodger.NLSunburstUntil = os.clock() + CONFIG.NLSunburstRun
            self.NLSunbursts = (self.NLSunbursts or 0) + 1
        end
        self.NLOnPillar = onPillar
    end

    local oldStep = UIWController.Step
    function UIWController:Step()
        oldStep(self)
        if self.Destroyed or not self.Enabled then
            return
        end
        pcall(self.WatchChampionReturn, self)
        pcall(self.TryNorthernEscapeBuff, self)
    end
end
