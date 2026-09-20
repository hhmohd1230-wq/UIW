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
    CONFIG.NLKeepSpeed = true
    CONFIG.NLEscapeBuffInterval = 0.4     -- how often we are allowed to consider it
    CONFIG.NLSlamBuffPad = 6              -- inside circle + this, spend the buff
    CONFIG.NLRushSpeed = 22               -- studs/s that counts as a charging attack
    CONFIG.NLRushWindow = 1.6             -- seconds ahead we care about it
    CONFIG.NLRushMiss = 12                -- how close its path comes before it matters

    -- When he returns to the pillar, back off - but only a little. Running to
    -- the rim was measured twice and was clearly worse (5-6 deaths, 0.7-0.9%/s
    -- against 1 death and ~2%/s staying close), because the trip out and back
    -- costs ~9 seconds and doubles the fight. Stepping out to about 75 studs
    -- takes under two seconds, puts real distance between us and the densest
    -- part of the sunburst, and we keep dodging beams normally the whole time.
    -- Off. Three measurements now agree: backing off when he returns to the
    -- pillar costs more than it saves.
    --   stay close        26-34s, 0 deaths, 53-85% of the fight in cast range
    --   back off to 75     45-102s, 1-4 deaths
    --   run to the rim     93-114s, 5-6 deaths
    -- The dodge improvements stay; only the retreat is switched off. Raise this
    -- above zero to try it again.
    CONFIG.NLSunburstRun = 0        -- seconds of holding back after he returns
    CONFIG.NLSunburstRadius = 75    -- how far back, not the rim
    CONFIG.NLPillarNear = 28       -- horizontally this close to the pillar counts as on it
    CONFIG.NLPillarHigh = 12       -- and this far above us

    local function inNorthernLands()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value.Value == "Northern Lands"
    end

    -- Circles we are standing in and have to leave on foot. The Champion's
    -- stomp was the only one here; Bob's ice slams are the same problem and
    -- bigger - 80 studs across for the large one, so 40 studs to clear from the
    -- middle, which is 2.5 seconds at walking speed and 1.7 buffed. His wave
    -- discs are in the list too: they killed us from 63% to 0% while we stood
    -- in one, and speed is the difference between crossing out sideways in time
    -- and not.
    local CIRCLES = {
        firstBossJumpSlam = true,
        largeIceSpikes = true,
        mediumIceSpikes = true,
        smallIceSpikes = true,
        secondBossCricleHitbox = true,
    }
    local function slamPush(root)
        local worst = 0
        for _, model in ipairs(Workspace:GetChildren()) do
            if CIRCLES[model.Name] then
                local box = model:FindFirstChild("hitBox", true)
                    or model:FindFirstChild("precast", true)
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
                    local closing = offset:Dot(velocity.Unit)
                    if closing > 0 then
                        local when = closing / speed
                        if when <= CONFIG.NLRushWindow then
                            -- how far off our position its path passes
                            local miss = (offset - velocity.Unit * closing).Magnitude
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

    -- Hold the speed buff up as continuously as the game allows.
    --
    -- Measured: WalkSpeed sits at 24 for about 90% of the time, in a cycle of
    -- roughly 5.5 seconds fast then 1.5 slow. Inner Rage has a 6 second cooldown
    -- against a buff lasting about 5.5, so something near 92% is the ceiling -
    -- 24 cannot be made permanent through the spell, and writing WalkSpeed
    -- directly is the thing that got the account kicked. What we can do is never
    -- leave the buff sitting ready while we are slow, which is where most of the
    -- missing time goes.
    function UIWController:KeepSpeedUp()
        if not CONFIG.NLKeepSpeed or not self.AutoCombat or not inNorthernLands() then
            return false
        end
        local character = self.Character
        local humanoid = character and character.Humanoid
        if not humanoid or not character:IsAlive() then
            return false
        end
        if humanoid.WalkSpeed > CONFIG.WalkSpeed + 1 then
            self.SpeedFast = (self.SpeedFast or 0) + 1
            return false                       -- already fast, save the cast
        end
        self.SpeedSlow = (self.SpeedSlow or 0) + 1
        local combat = self.Combat
        if not combat or not combat:CanSendInput() or combat:IsBusyCasting() then
            return false
        end
        for _, slot in ipairs({ "q", "e" }) do
            local tool = combat:GetTool(slot)
            if tool and combat:IsBuffTool(tool) and combat:IsReady(slot) then
                combat:Press(slot)
                self.SpeedRefreshes = (self.SpeedRefreshes or 0) + 1
                return true
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
        -- escapes first: if something is about to land on us, the buff is better
        -- spent getting out than on topping up a timer
        if not pcall(self.TryNorthernEscapeBuff, self) then
            pcall(self.KeepSpeedUp, self)
        else
            pcall(self.KeepSpeedUp, self)
        end
    end
end
