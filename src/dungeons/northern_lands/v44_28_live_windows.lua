-- Northern Lands only. Warning lifetime, not model lifetime, defines a beam.
-- Keep this layer after the general field and anti-reversal planners.
do
    CONFIG.NLAwareRadius = 150     -- only what can reach this close to us matters
    CONFIG.NLBobRadius = 40        -- how close we hold to Bob The Frost Giant
    -- Bob's beams are 400 studs long and sweep in from the edges, so a 150 stud
    -- bubble only meets them once they are already on top of us. Seeing them
    -- form gives room to walk to a spot they are not going to reach.
    -- His beams are 400 studs long and spawn at the rim, and his wave is a
    -- 198 stud corridor. A bubble smaller than the attacks themselves means we
    -- only meet them once they are already on us, so this reaches the whole
    -- arena.
    CONFIG.NLBobAware = 420
    -- ...and the budget has to match, or the extra sight is spent on beams that
    -- get trimmed anyway. Measured at 48: Bob's arena carries forty-odd beams
    -- on its own, which is the entire budget before the wave is even counted.
    CONFIG.NLBobBoxes = 76

    -- Not every attack costs the same. These are multipliers on being inside
    -- the box, so the planner does not trade a brush with a killer to avoid two
    -- cheap ones.
    --
    -- NIGHTMARE CHANGES THE PREMISE. Measured there: the Champion's passive
    -- beam 135%, his jump slam 125%, Bob's horizontal beam 113%, his wave 119%.
    -- Every one of those is more than our whole health bar, so there is no
    -- longer any such thing as a cheap hit to trade against - the target is not
    -- fewer hits, it is none. The weights still matter for choosing between two
    -- bad squares, but anything measured above 100% belongs at the top of this
    -- table, and the old numbers below it were all set on Insane.
    -- genericNeonBall used to sit here at 5, "measured 80-86% in one hit".
    -- That measurement was an artefact. Read the game's own scripts: every
    -- genericNeonBall, ours and the enemies', is cloned, tweened to
    -- Transparency 1 over 0.45s and handed to Debris. It is a muzzle flash.
    -- The observer blames the nearest hazard part when we lose health, and a
    -- sparkle sitting at distance 0 wins that contest against a beam 100 studs
    -- away - so it collected the blame for everything that really hit us.
    local DEADLY = {
        secondBossHorizontalBeam = 6,
        firstBossBigSpike = 5,        -- measured 89% in one hit
        firstBossCrissCross = 3,      -- 35-43% each and they arrive in threes
        -- The single most common source of damage in two recorded human runs:
        -- 14 of 34 hits, and the cause of five separate deaths. A mob attack,
        -- not a boss one, which is why it went unnoticed while we studied
        -- bosses. Three hits of ~33% kill.
        -- Raised from 3. Measured in the lower room, six bars crossed us in
        -- seven tenths of a second - 32, 31, 29, 30, 29, 29 percent - which is
        -- death twice over from one wave. A 3 put this level with a moving beam
        -- while it was killing us faster than anything Bob has. The recorded
        -- distances run 22, 22, 21, 17, 17, 14 studs and that is the bar
        -- carrying on past us between the server applying the damage and our
        -- sampling it, not a hitbox we have mismeasured: the wave moves, so by
        -- the time we see it, it has left.
        northernMageShot = 5,
        secondBossSpreadBeam = 6,     -- also measured as a one-shot: 100%
        secondBossMovingBeam = 3,
        -- The Champion on Nightmare, measured: his passive beam took 135%, 102%
        -- and 98% off us in one fight and killed us three times in 83 seconds.
        -- It was not in this table at all, so it carried the default weight of
        -- 1 - the lowest thing in the dungeon - on the strength of a note at
        -- the top of this file saying a passive beam is "about 40%". That was
        -- true on Insane. It is his whole fight on Nightmare, and the planner
        -- was pricing it below a mob's shuriken.
        firstBossPassiveBeam = 6,
        firstBossJumpSlam = 6,        -- measured 125% on Nightmare, was 4
        -- Odin. Measured single hits of 42% and 78% with nothing the tracker
        -- could name, so these are first estimates from hitbox size rather than
        -- from attributed damage; the next runs will attribute them properly.
        thirdBossLineShot = 5,        -- 13 x 138 x 219, the arena-crossing one
        thirdBossMissile = 4,
        thirdBossMultiRings = 3,
        thirdBossBouncingOrb = 3,
        -- Unvalidated, like the rest of his: first guesses, to be replaced the
        -- moment one clean Odin fight goes through the attribution.
        thirdBossPassiveOrb = 4,
        thirdBossSpiralOrb = 4,
        largeIceSpikes = 3,           -- Bob, an 80 stud circle
        mediumIceSpikes = 2,
        smallIceSpikes = 2,
        -- Bob's wave. Now that the sparkle is out of the way and attribution
        -- means something, this is not merely one of the dangerous attacks -
        -- it is the fight. A clean 54 second kill, measured: four hits in the
        -- whole fight, three of them the wave, 73%, 74% and 77%. It did 224 of
        -- the 330 percent we lost. The horizontal beam, weighted the same as
        -- this one, did nothing at all. So it goes above the rest rather than
        -- level with them: two of these is a death and nothing else comes
        -- close.
        secondBossCricleHitbox = 9,
        -- Bob's colour orbs. These sat on the default of 1 while an entire file
        -- of this script exists to walk them into a crystal because touching
        -- one is a disaster. The planner was being told the opposite of what
        -- the rest of the code believes.
        secondBossRedOrb = 5, secondBossGreenOrb = 5, secondBossYellowOrb = 5,
    }
    -- What an attack is worth when nobody has measured it yet.
    --
    -- This used to be 1, which made anything missing from the table above the
    -- cheapest thing in the dungeon - and an audit against the full list of
    -- this map's attack names found ELEVEN we track and then price at 1,
    -- including every one of Bob's colour orbs, the Champion's seeking spikes
    -- and whirlwind, Odin's bouncing orb beam, and the warrior's circle strike
    -- we went to the trouble of measuring at 25 studs growing to 34.
    --
    -- A 1 against a 6 tells the planner to walk through any of those rather
    -- than take one step nearer a beam. That is not caution, it is a statement
    -- that we know they are harmless, and we do not know that about any of
    -- them. Something we bothered to track is at least an ordinary attack, so
    -- the fallback is the middle of the table. Anything still sitting on this
    -- number is unmeasured, not safe.
    CONFIG.NLUnknownWeight = 3
    CONFIG.NLGapClearance = 9      -- beam half width plus a body
    CONFIG.NLMinRadius = 28        -- closest we stand to the pillar
    CONFIG.NLMaxRadius = 135       -- and the furthest, for Sun-Burst
    CONFIG.NLCastRadius = 60       -- inside this we can still hit the boss (range 64)
    CONFIG.NLWalkCost = 0.06       -- studs of walking traded against studs of closeness
    CONFIG.NLSafety = 1.2          -- stand this much past the bare minimum radius
    CONFIG.NLBurstLead = 1.4       -- seconds of beam spawning we look ahead
    CONFIG.NLBurstAlarmEnds = 10   -- this many blocked angles means Sun-Burst is starting
    CONFIG.NLBurstHold = 7         -- once it starts, commit to the run for this long
    CONFIG.NLGoalPull = 0.3        -- score per stud away from where we want to stand
    CONFIG.NLGoalPullMax = 8       -- ...multiplied by up to this when far out of position
    -- Being unable to cast is not a small cost. With the mob combo block fixed,
    -- the probe's verdict against Bob became "outside damage range", 100% of 623
    -- samples: we were simply never close enough to hit him. A fight we cannot
    -- shoot in is lost for certain, while brushing a hazard is a risk - so every stud
    -- outside cast range is priced high enough to outweigh a cheap hazard and
    -- still lose to a one-shot, whose weight is several times this.
    CONFIG.NLRangePull = 4         -- score per stud we would still be out of cast range
    -- What a melee mob is actually worth standing away from. This was 34 studs
    -- at a weight of 8, which made it the strongest single term in the whole
    -- scorer: standing 15 studs from one warrior scored 152 per time sample, so
    -- over four samples it beat most hazards outright. The result was that any
    -- pack of warriors pushed us backwards out of our own casting range and we
    -- waited for them to walk to us one at a time.
    --
    -- The real danger is measured, not guessed: northernWarriorCircleStrike is
    -- 25 studs across and grows to 34, so its radius is 12 to 17 studs. A 34
    -- stud keep-out was double the grown attack's radius - the same mistake as
    -- the mage padding, a safety margin twice the size of the thing it guards
    -- against, and the direct reason circling a pack was impossible.
    CONFIG.NLMeleeKeepOut = 20     -- circle strike radius 17, plus a body
    CONFIG.NLMeleeWeight = 4

    -- Never stand still in a mob fight. Standing is sometimes the lowest-risk
    -- square on paper, but it ends the rotation, and the rotation is what keeps
    -- their shots landing where we just were. A flat cost means holding still
    -- has to be clearly better than moving, not merely equal.
    CONFIG.NLStandStillCost = 45
    -- The same idea for bosses, where it had no cost at all until now. Measured
    -- against Bob on Nightmare: 20% of the fight held still, while the two
    -- attacks that decide it do more than our whole health bar in one touch.
    CONFIG.NLBossStandStillCost = 60
    -- Mage waves: leave the lane, do not live in it. Standing in the six stud
    -- gap between two bars does work - it is the neat answer, and it is also a
    -- stationary answer that stops the circle and depends on us holding a gap
    -- narrower than our own body for as long as the wave lasts. Stepping out
    -- sideways costs about 17 studs and puts the whole thing behind us. So any
    -- direction that runs along the wave, with it or against it, is charged for
    -- staying in the lane; perpendicular is free.
    CONFIG.NLWaveLaneRange = 70    -- a wave this close is worth reacting to
    CONFIG.NLWaveLaneCost = 55

    ---------------------------------------------------------------------------
    -- EXPERIMENT: closer packs, never standing, and leaving the mage wave.
    --
    -- Three requested changes that belong together, kept together so they can
    -- be lifted back out in one piece if the numbers get worse. Set
    -- NLStrategyExperiment to false to fall back to the values in the comments.
    ---------------------------------------------------------------------------
    CONFIG.NLStrategyExperiment = true

    -- 1. Group the pack tighter. Mobs chase us, so the circle we run is the
    --    shape they end up in: a tighter, faster one funnels them into a heap
    --    we can hit with one cast instead of a smear we chase across the room.
    CONFIG.NLPackClearanceExp = 12        -- was 20 studs beyond the outermost mob
    CONFIG.NLPackMaxRadiusExp = 70        -- was 80
    CONFIG.NLMobOrbitStepExp = 40         -- was 32 degrees aimed ahead

    -- 2. Never stand still in a mob fight, surrounded or not. 45 made standing
    --    merely unattractive, and when a pack closes in it was still winning:
    --    every direction costs something once they are all around us, so the
    --    cheapest square was the one we were on. Standing is what lets them
    --    settle their aim, so it has to lose to a bad direction, not just to a
    --    good one. This is a cost and not a ban, so a genuinely walled-in spot
    --    can still choose it.
    CONFIG.NLStandStillCostExp = 140      -- was 45

    -- 3. Leave the mage's wave instead of living in it. The gap between two
    --    bars is six studs of real safety and the scorer found it, which is why
    --    we would plant ourselves mid-attack and wait: nothing was charging us
    --    for still being among the bars, only for being inside one. Now any
    --    position that ends up within this range of a bar is priced by how
    --    close it is, so stepping the seventeen studs fully out beats standing
    --    in the slot - and if we truly are boxed in, the slot is still there.
    -- 22 was not enough daylight and the measurement says so plainly: we were
    -- struck at 22 studs and then at 21, 17, 17 and 14 as the rest of the row
    -- came through. A bar is 35 wide with 13 between them, so clearing one bar
    -- by twenty studs still leaves us in the path of the next. Clear the row.
    CONFIG.NLMageClearOut = 34            -- studs of daylight we want from a bar
    CONFIG.NLMageClearCost = 7            -- per stud short of that
    -- Bob's wave, measured: ten discs, diameters 22 up to 76 in steps of 6, at
    -- 0, 22, 44 ... 198 studs from him, spawned in sequence about every third of
    -- a second and marching outward along one bearing. It is not a ring around
    -- him and it is not something you back away from - it is a widening corridor
    -- pointing one way, which is why the answer is to leave it sideways and why
    -- it is narrow next to him and wide at the rim.
    --
    -- So any direction along that corridor, toward Bob or away from him, is
    -- charged; across it is free. Priced above the wave's own danger so that
    -- leaving beats standing even while we are still inside it.
    CONFIG.NLBobWaveAxisCost = 120
    CONFIG.NLBobWaveRange = 110
    CONFIG.NLOrbGoalPull = 7       -- score per stud off the spot behind the crystal
    CONFIG.NLBossHorizon = 2.6     -- seconds of travel we compare against, for Bob and Odin
    CONFIG.NLProbeDistance = 22    -- ...but only this much is checked for being walkable
    -- DamageCastRange = 64 is our own rule, not the game's. Our damage spell is
    -- Flame Shuriken, a 45 stud disc that flies - there is no 64 stud leash on
    -- it. The evidence that it lands much further out is Ethos: it damaged Bob
    -- at 0.73-1.40%/s while inside 60 studs for only 0-18% of the fight, which
    -- is impossible if 64 were a real limit.
    --
    -- Holding that made-up limit against Bob cost us the fight completely:
    -- measured 361 seconds, 15 deaths, and his health never moved off 100%. We
    -- spent the whole fight trying to reach a distance we did not need, through
    -- the beams, dying on the way, over and over.
    -- ...and then 140 turned out to be just as made up as the 64 it replaced,
    -- in the other direction. Measured on Nightmare against Bob: 574 frames of
    -- fight, and his health moved on ONE of them. That single frame was at 87
    -- studs. Everything logged past 90 - and 73% of the fight was past 120 -
    -- did nothing at all.
    --
    -- 87 is not a coincidence. Flame Shuriken's own script flies the projectile
    -- from six studs in front of us out to eighty-six, along our look vector,
    -- and stops. That is the reach. We had been standing at 120 to 210 studs
    -- holding the cast button at a boss we could not touch, which is the whole
    -- explanation for a 113 second Champion and a Bob fight that will not end.
    --
    -- So this is the real number now. It also does the positioning work for
    -- free: the scorer already charges four points a stud for every stud
    -- outside cast range, and against a true 88 that term finally points where
    -- the damage is instead of at a line in the air.
    CONFIG.NLBossCastRange = 88
    -- The same made-up leash exists for mobs, twice over: DamageCastRange 64 and
    -- MobBurstRange 46, which holds fire until we have closed to 46 studs. That
    -- is what caps the circle - there is no point riding a wide arc if we stop
    -- shooting the moment we are on it. Measured at 46.1, the fights where the
    -- arc opened past 200 degrees were also the fights that did 5.8-6.0%/s with
    -- 100% of the time in range, so the wide circle is worth having.
    CONFIG.NLMobCastRange = 100
    -- ...but NOT for the Champion. His passive beams are diameters through a
    -- pillar, so the speed a beam edge sweeps past you is turn rate times your
    -- distance from that pillar: close in, the gap asks for a few studs a
    -- second; far out, it moves faster than you can walk. Standing off and
    -- shooting him is the exact mistake the close-range plan was built to fix.
    -- Measured when the long range was applied to him as well: 119 seconds and
    -- five deaths, against 48 seconds and one.
    local LONG_RANGE = {
        ["bob the frost giant"] = true,
        ["odin"] = true,
    }

    local function northern()
        local d = Workspace:FindFirstChild("dungeonName")
        return d and d.Value == "Northern Lands"
    end
    -- Room 2 is not the final boss room, so the generic classifier missed the
    -- Champion. This also prevented the elevated-boss line-of-sight exception.
    --
    -- Bob and Odin were missing from this list, and it cost us the entire
    -- second boss fight. Measured with a cast-block probe sampling ten times a
    -- second: against Bob, 100% of 397 samples were blocked with "closing for
    -- close-range mob combo". The mob combo holds fire until you are inside
    -- MobBurstRange, and the dodge planner holds Bob at 40 studs and further -
    -- so we never closed, so we never cast, for the whole fight. Every boss in
    -- this dungeon has to be named here or it is treated as a mob.
    local NL_BOSSES = {
        ["midgardian champion"] = true,
        ["bob the frost giant"] = true,
        ["odin"] = true,
    }
    local boss = isBossEnemy
    isBossEnemy = function(enemy)
        if northern() and enemy and enemy.Model
            and NL_BOSSES[normalizeEnemyName(enemy.Model.Name)] then
            return true
        end
        return boss(enemy)
    end
    -- Everything the dungeon spawns was catalogued by name and hitbox size over
    -- four full runs. Several of these were invisible to the planner: they are
    -- models whose only part is a precast, so the hazard tracker filed them as
    -- warnings and collect() skipped them, and they were never dodged at all.
    -- The ice spikes are the clearest case - a 80 x 80 circle on the floor.
    local timed = {firstBossPassiveBeam=true, firstBossJumpSlam=true, spearmanStrikeHitbox=true,
        northernMageShot=true, northernWarriorCircleStrike=true,
        -- Bob: three sizes of ground circle, warned by a precast and nothing else
        largeIceSpikes=true, mediumIceSpikes=true, smallIceSpikes=true,
        -- mobs: a long melee lane, 114 studs of it
        northernWarriorLineStrike=true,
        -- Odin: the two warned attacks
        thirdBossLineShot=true, thirdBossMultiRings=true,
        -- Bob's expanding wave, which nothing was tracking at all
        secondBossCricleHitbox=true,
        -- His two big beams. They were in no list, so they reached the planner
        -- only through the generic tracker - which skips anything still flagged
        -- as a warning. That means we never saw them forming, only once they
        -- were already live, and a 400 stud beam that is already live is a beam
        -- that has already arrived. Both carry a precast and a hitBox, so
        -- routing them through here gives us the whole geometry while it is
        -- still only a warning. They are the top damage source in the fight now
        -- that the wave and the orbs are handled.
        secondBossHorizontalBeam=true, secondBossSpreadBeam=true}
    local windup = {firstBossPassiveBeam=1.0, firstBossJumpSlam=2.0}
    -- How long after the warning goes dark the ground is still dangerous. The
    -- default 0.30s suits a beam, where the warning and the hit are the same
    -- moment; a spike field warns, the warning clears, and then the spikes come
    -- up, so leaving on the warning is only safe if we stay away a little
    -- longer than that.
    local linger = {largeIceSpikes=1.2, mediumIceSpikes=1.2, smallIceSpikes=1.2,
        thirdBossMultiRings=0.8, thirdBossLineShot=0.6, northernWarriorLineStrike=0.6,
        -- these fire as the warning ends, so they have to outlive it
        secondBossHorizontalBeam=1.0, secondBossSpreadBeam=1.0}

    -- Attacks whose precast IS the damage area, not a flashing warning that
    -- precedes one. Measured in Bob's arena: every one of these precasts sits at
    -- Transparency 1.0, so the "is the warning lit" test said no, HadWarning was
    -- never set, and the 0.30s no-warning rule retired the attack a third of a
    -- second after it appeared. That is why the ice spikes never once showed up
    -- in the planner's list while we were being hit by them. For these, the
    -- model existing in the workspace is the whole of its lifetime.
    -- Bob's attacks only. northernWarriorCircleStrike was in here for one build
    -- and cost us the Champion fight: 77s and three deaths against 45s and one.
    -- Never-expires is right for a wave the game deletes when it ends, and wrong
    -- for a mob attack whose model is left lying in the workspace, where it
    -- becomes a permanent no-go zone we keep walking around.
    local warnBox = {largeIceSpikes=true, mediumIceSpikes=true, smallIceSpikes=true,
        -- Bob's opening wave. It was in no list at all: it carries a precast and
        -- nothing else, so the tracker filed it as a warning and the collector
        -- skipped it. Caught it growing live through 22, 28, 34 and 76 studs
        -- across, which is exactly the expanding ring - small near him, wide by
        -- the time it reaches the rim.
        secondBossCricleHitbox=true}

    -- Where the damage actually is, when it is not the part we would guess.
    -- secondBossMovingBeam has no hitBox and no precast. Its PrimaryPart is a
    -- 4x1x2 marker, which is all we were tracking - while the thing that hits
    -- you is a 52 stud bar strung between two balls. We were dodging a dot.
    local bodyPart = {secondBossMovingBeam = {"middleBeam", "swirlPart"}}
    -- Found by logging everything that appears during the fight: the whirlwinds
    -- and the shurikens are bare MeshParts sitting straight in the workspace
    -- with no hitBox and no precast child, so the hazard tracker never saw them
    -- at all. firstBossCrissCross crosses the arena at 30 studs/s - that is the
    -- one that kept killing us "out of nowhere".
    local moving = {northernMageShot=true, firstBossSeekingSpikes=true,
        firstBossCrissCross=true, firstBossBigSpike=true,
        firstBossWhirlwind=true, firstBossWhirlWind=true, spearmanStrike=true,
        -- The colour orbs were left out so we could walk them to a crystal
        -- instead of fleeing. Leading one is still the plan, but the orb has to
        -- be treated as dangerous while we do it, so the planner keeps a step
        -- ahead of it. The orb is real: it has a body and it homes on us.
        secondBossRedOrb=true, secondBossGreenOrb=true, secondBossYellowOrb=true,
        -- genericNeonBall is deliberately NOT here any more, and this is the
        -- single worst bug the dungeon has had.
        --
        -- It is not an explosion. It is decoration. ReplicatedStorage has two
        -- copies, projectiles and enemyProjectiles, and both are used the same
        -- way everywhere in the game: clone it, parent it to workspace, tween
        -- Transparency to 1 over 0.45s, Debris it. Gun muzzles, rocket packs,
        -- spell casts. It has never done a point of damage.
        --
        -- Our own abilities spawn one. Amethyst Blast clones it at our own
        -- HumanoidRootPart and grows it to 30 studs, and Debris keeps it around
        -- for five seconds. So the planner saw a large, growing, 5x-weighted
        -- hazard welded to our own body, every time we cast - and a hazard
        -- wider than the lookahead makes every direction score as "inside the
        -- box", which is the one condition under which the scorer gives up and
        -- stands still. We were not failing to dodge the wave. We were rooted
        -- to the spot by our own spell effect while the wave went through us.
        -- Odin. Both are bare parts sitting in the workspace with no hitBox and
        -- no precast, the same shape of blind spot the whirlwinds were: he took
        -- 42-78% off us in single hits that the tracker recorded as "nothing
        -- nearby". thirdBossBouncingOrb is 12 cubed, thirdBossMissile 10x10x30.
        thirdBossBouncingOrb=true, thirdBossMissile=true, thirdBossBouncingOrbBeam=true,
        -- Two more of Odin's, from a full list of the dungeon's attack names.
        -- We were tracking 13 of the 32 attacks Northern Lands has, and four of
        -- the missing ones were his - which is a poor position to be in against
        -- the boss we have never measured.
        --
        -- Both of these pass the test the neon ball failed. thirdBossPassiveOrb
        -- is a real travelling projectile: the game clones it, then drives it
        -- along its own look vector from a Heartbeat connection for up to
        -- twenty seconds. thirdBossSpiralOrb appears in no client script at
        -- all, which means the server makes it, the same signature as Bob's
        -- beams and every other attack that has ever actually hurt us.
        --
        -- thirdBossSmite and thirdBossBeamPart are deliberately NOT here. The
        -- smite is particles emitted where the hit already landed and the beam
        -- part lives 0.4 seconds; both are the picture of an attack arriving,
        -- like the neon ball, and adding them would put a hazard on our own
        -- head after the damage was already done.
        thirdBossPassiveOrb=true, thirdBossSpiralOrb=true,
        -- and Bob's moving beam, now that we know where its body is
        secondBossMovingBeam=true}
    local tracks = setmetatable({}, {__mode="k"})
    local function live(container, now)
        local box
        local named = bodyPart[container.Name]
        if named then
            for _, want in ipairs(named) do
                local part = container:FindFirstChild(want, true)
                if part and part:IsA("BasePart") then box = part break end
            end
        end
        box = box or container:FindFirstChild("hitBox", true)
        if not box and container:IsA("BasePart") then box = container end
        -- Some attacks never grow a hitBox on our side - the precast circle is
        -- the whole thing we can see. Use it as the box rather than ignoring
        -- the attack, which is what happened before.
        if not box then
            local pre = container:FindFirstChild("precast", true)
            if pre and pre:IsA("BasePart") then box = pre end
        end
        if not box or not box:IsA("BasePart") then return nil end
        local info = tracks[container]
        if not info then
            local look=flatten(box.CFrame.LookVector)
            info = {At=now, Position=box.Position, Velocity=Vector3.zero, Seen=now, Visible=now,
                Angle=math.atan2(look.Z,look.X),Omega=0,
                Size=box.Size, SizeAt=now, Growth=Vector3.zero}
            tracks[container] = info
        end
        -- An expanding ring is a different problem from a moving one: it does
        -- not come to you, it gets wider where it already is. Measure how fast
        -- it is growing so the planner can be told where its edge will be, not
        -- only where it is.
        local sdt = now - (info.SizeAt or now)
        if sdt >= 0.1 then
            local change = box.Size - (info.Size or box.Size)
            info.Growth = change / sdt
            info.Size, info.SizeAt = box.Size, now
        end
        local dt = now - info.At
        if dt >= 0.025 then
            local velocity = (box.Position-info.Position)/dt
            if velocity.Magnitude < 450 then info.Velocity = velocity else info.Velocity=Vector3.zero end
            local look=flatten(box.CFrame.LookVector)
            local angle=math.atan2(look.Z,look.X)
            local omega=((angle-info.Angle+math.pi)%(2*math.pi)-math.pi)/dt
            info.Omega=math.abs(omega)<7 and omega or 0
            info.Angle=angle
            info.At, info.Position = now, box.Position
        end
        local pre = container:FindFirstChild("precast", true)
        if pre and pre:IsA("BasePart") and pre.Transparency < 0.98 then
            info.Visible = now
            info.HadWarning = true
        end
        -- For these the model's presence is the attack; there is no lit warning
        -- to expire, so neither timer applies.
        if warnBox[container.Name] then return box, info end
        local hold = linger[container.Name] or 0.30
        if timed[container.Name] and info.HadWarning and now-info.Visible > hold then return nil end
        if timed[container.Name] and not info.HadWarning and now-info.Seen > 0.30 then return nil end
        return box, info
    end

    -- These attacks can outlive a nearby mob. Nearest-enemy inference had
    -- attributed mage shots to warriors and deleted them when the warrior died.
    local register = HazardTracker.Register
    function HazardTracker:Register(part)
        register(self, part)
        if not northern() then return end
        local data = (self.FullHazards or self.Hazards)[part]
        if data and data.Container and (moving[data.Container.Name] or timed[data.Container.Name]) then
            data.SourceEnemyModel, data.SourceEnemyHumanoid = nil, nil
        end
    end
    local active = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        if northern() and container and container.Parent and timed[container.Name] then
            return live(container, now or os.clock()) ~= nil
        end
        return active(self, container, now)
    end

    -- The old Champion station scanned every lingering beam, including spent
    -- warnings. Its unvalidated slam direction could also cross a live beam.
    local oldStation, oldSlam = DodgeSolver.GetChampionStation, DodgeSolver.GetChampionSlamEscape
    function DodgeSolver:GetChampionStation(...)
        if northern() then return nil end
        return oldStation(self, ...)
    end
    function DodgeSolver:GetChampionSlamEscape(...)
        if northern() then return nil end
        return oldSlam(self, ...)
    end

    local function collect(self, now)
        local root = self.CharacterService.Root
        local list, seen, beams = {}, {}, {}
        local function add(part, velocity, name, omega, info)
            if seen[part] then return end
            seen[part] = true
            local cf, half = part.CFrame, part.Size*0.5
            -- An expanding ring will be wider by the time we get there than it
            -- is in this frame, so plan against the edge it is heading for. A
            -- fifth of a second of growth is enough to stop us walking into the
            -- rim we just measured as clear; more than that and we would flee a
            -- wave that has not arrived.
            if info and info.Growth and info.Growth.Magnitude > 1 then
                local ahead = info.Growth * 0.2 * 0.5
                -- capped: a part that jitters in size for a frame must not be
                -- able to inflate itself into a wall
                half = half + Vector3.new(
                    math.clamp(ahead.X, 0, 12), 0, math.clamp(ahead.Z, 0, 12))
            end
            -- Distance to the box itself, not to its centre. A 250 stud beam
            -- through the pillar has its centre 130 studs away while passing
            -- straight through us, and a small orb 140 studs off is irrelevant;
            -- centre distance gets both of those backwards. This keeps the work
            -- to what is actually near us, which is cheaper and sharper.
            local here = cf:PointToObjectSpace(root.Position)
            local dx = math.max(math.abs(here.X) - half.X, 0)
            local dy = math.max(math.abs(here.Y) - half.Y, 0)
            local dz = math.max(math.abs(here.Z) - half.Z, 0)
            if math.sqrt(dx * dx + dy * dy + dz * dz) > (self.NLAwareNow or CONFIG.NLAwareRadius) then return end
            -- northernMageShot measured live: each bar is 7 x 64 x 35, and
            -- consecutive bars in a wave sit 13 studs apart centre to centre,
            -- which leaves a 6 stud gap between them. The old 8 stud pad turned
            -- a 7 stud thick bar into a 23 stud one and a 35 wide bar into 51,
            -- so the gaps between bars vanished entirely and a sidestep that
            -- really needs 17 studs looked like it needed 26. This is the
            -- attack that has done us the most damage of anything in the
            -- dungeon - 15 of all recorded hits - and we were modelling it
            -- three times thicker than it is.
            -- All three wave hits in the clean fight were recorded with the
            -- disc surface 2 studs away, not with us inside it. We are not
            -- standing in the wave any more; we are grazing it and losing
            -- three quarters of our health for the couple of studs. Whether
            -- the real hitbox is slightly larger than the part we can see or
            -- the health event simply lands a frame after we leave, the answer
            -- is the same and it is cheap: clear it by a body's width instead
            -- of by nothing. 5 was the default for anything unlisted, which is
            -- how the one attack that decides the fight ended up with the same
            -- margin as a stray mob projectile.
            local pad=name=="secondBossCricleHitbox" and 12
                or name=="northernMageShot" and 3
                or name=="firstBossJumpSlam" and 16
                or (name=="firstBossCrissCross" and 12)
                or ((name=="firstBossBigSpike" or name=="firstBossSeekingSpikes") and 9)
                or 5
            -- The shurikens are flat discs: firstBossSeekingSpikes is 20x0x20
            -- and firstBossBigSpike 40x0x40, zero studs tall. With the usual 3
            -- stud vertical allowance a disc lying on the floor can sit
            -- entirely below the height test while we walk through it, so a
            -- flat hazard gets a body's worth of height instead.
            local tall = half.Y < 4 and 9 or 3
            list[#list+1] = {CF=cf, Half=half+Vector3.new(pad,tall,pad), V=velocity, Omega=omega or 0,
                Starts=0,
                Ends=info and windup[name] and math.max(0.3,windup[name]+0.5-(now-info.Seen)) or math.huge,
                Name=name, Distance=math.sqrt(dx * dx + dy * dy + dz * dz)}
        end
        for _,container in ipairs(Workspace:GetChildren()) do
            if timed[container.Name] or moving[container.Name] then
                local part, info = live(container, now)
                if part then
                    add(part, timed[container.Name] and Vector3.zero or info.Velocity, container.Name, info.Omega, info)
                    if container.Name == "firstBossPassiveBeam" then beams[#beams+1]=part end
                end
            end
        end
        for _,data in ipairs(self.Hazards:GetActive()) do
            local part, container = data.Part, data.Container
            if part and part.Parent and not data.IsPrecast and not (container and timed[container.Name]) then
                add(part, self.Hazards:GetProjectileVelocity(data), container and container.Name or part.Name)
            end
        end
        local names = {}
        for _, box in ipairs(list) do names[box.Name] = (names[box.Name] or 0) + 1 end
        self.NLNames = names
        -- Standing inside a box is the condition that makes the scorer give up:
        -- if a hazard is wider than the lookahead, every candidate direction is
        -- also inside it, nothing scores better than staying put, and we stop
        -- moving. That is how a cosmetic sparkle stuck to our own body rooted us
        -- in the middle of Bob's wave for an entire patch cycle. Count it by
        -- name so the next one cannot hide: getgenv().UIW.NLInside.
        local inside = self.NLInside or {}
        for _, box in ipairs(list) do
            if box.Distance <= 0 then
                inside[box.Name] = (inside[box.Name] or 0) + 1
            end
        end
        self.NLInside = inside
        table.sort(list, function(a,b) return a.Distance < b.Distance end)
        -- The cap exists to bound the work, but Bob's arena carries forty-odd
        -- beams and his wave is ten separate discs, so the wave is exactly what
        -- the cap throws away - the one attack that kills us outright. Keep
        -- every piece of it and trim the rest.
        local cap = (self.NLAwareNow and self.NLAwareNow > 200) and CONFIG.NLBobBoxes or 32
        local index = #list
        while #list > cap and index > 0 do
            if list[index].Name ~= "secondBossCricleHitbox" then
                table.remove(list, index)
            end
            index -= 1
        end
        return list, beams
    end
    local function risk(list, position, time)
        local score = 0
        for _,box in ipairs(list) do
            if time<box.Starts or time>box.Ends then continue end
            local cf=box.CF
            if math.abs(box.Omega)>0.02 then
                cf=CFrame.new(cf.Position)*CFrame.Angles(0,-box.Omega*time,0)*(cf-cf.Position)
            end
            local p=cf:PointToObjectSpace(position-box.V*time)
            local half=box.Half
            if math.abs(p.Y)<=half.Y then
                local dx,dz=math.abs(p.X)-half.X,math.abs(p.Z)-half.Z
                if dx<=0 and dz<=0 then score += (100+math.min(-dx,-dz)*2)*(DEADLY[box.Name] or CONFIG.NLUnknownWeight)
                else score += math.max(0,4-math.max(dx,dz))*0.4 end
            end
        end
        return score
    end
    local solve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, yaw)
        if not northern() or not self.CharacterService:IsAlive() then return solve(self,routeDirection,enemy,yaw) end
        local now=os.clock()
        if now-(self.NLAt or 0)<0.045 and self.NLDirection then
            return self.NLDirection,yaw,self.NLEmergency,self.NLDodging
        end
        local root=self.CharacterService.Root
        local champion=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="midgardian champion"
        local bob=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="bob the frost giant"
        -- Odin needs the same treatment as Bob and for the same reason: his
        -- line shot is 13 x 138 x 219 and his ring is 75 across, so a 150 stud
        -- bubble is smaller than his attacks are long. Every Odin fight we have
        -- recorded took 42-78% off us in single hits the tracker could not name,
        -- which is what being blind to an attack looks like from the inside.
        local odin=enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="odin"
        self.NLAwareNow = (bob or odin) and CONFIG.NLBobAware or CONFIG.NLAwareRadius
        local list,beams=collect(self,now)
        local preferred=unit(flatten(routeDirection or Vector3.zero))
        local goal
        if champion then
            -- Every beam is a diameter through the pillar, so it blocks the
            -- angle it points at and the opposite one. How far out we have to
            -- stand is set by how many are lit at once: half the gap we sit in
            -- has to subtend the beam's half width plus our body.
            --   3 lit beams  -> 18 studs is enough, stay close and keep casting
            --   12 lit beams -> 69 studs
            --   23 lit beams (Sun-Burst) -> 132 studs, get out
            -- A fixed 46 was only ever right for about 7, which is why we died
            -- at 57-74 studs during Sun-Burst with 22 beams up.
            self.NLPivot = (#beams > 0) and beams[1].Position or self.NLPivot
            local pivot = self.NLPivot
            if pivot then
                local flatPivot = Vector3.new(pivot.X, root.Position.Y, pivot.Z)
                local offset = flatten(root.Position - flatPivot)
                local mine = math.atan2(offset.Z, offset.X) % (2 * math.pi)
                local ends = {}
                for _, part in ipairs(beams) do
                    local look = flatten(part.CFrame.LookVector)
                    if look.Magnitude > 0.01 then
                        local yaw = math.atan2(look.Z, look.X)
                        ends[#ends + 1] = yaw % (2 * math.pi)
                        ends[#ends + 1] = (yaw + math.pi) % (2 * math.pi)
                    end
                end
                -- Sun-Burst is a spawn-rate spike, so react to how fast beams
                -- are appearing rather than waiting until we are surrounded.
                -- Walking from 40 studs out to 130 takes about four seconds; by
                -- the time the count alone says "run", it is already too late.
                self.NLSeen = self.NLSeen or {}
                local fresh = 0
                for _, part in ipairs(beams) do
                    if not self.NLSeen[part] then
                        self.NLSeen[part] = now
                        fresh += 1
                    end
                end
                for part, at in pairs(self.NLSeen) do
                    if now - at > 1 then self.NLSeen[part] = nil end
                end
                self.NLRate = (self.NLRate or 0) * 0.6 + fresh * 0.4
                local lead = math.floor(self.NLRate * CONFIG.NLBurstLead * 2)

                -- Every gap is a candidate. The one we stand in is not
                -- automatically the best: a wider gap elsewhere may let us
                -- stand close enough to keep casting, and the path scoring
                -- below decides whether we can safely get there.
                local angle, span, radius = mine, math.pi * 2, CONFIG.NLMinRadius
                if #ends > 0 then
                    table.sort(ends)
                    local bestCost = math.huge
                    for i = 1, #ends do
                        local from = ends[i]
                        local width = (ends[(i % #ends) + 1] - from) % (2 * math.pi)
                        if width <= 0.0001 then width = 2 * math.pi end
                        local middle = (from + width * 0.5) % (2 * math.pi)
                        -- the bare minimum radius puts us exactly on the edge of
                        -- the beam, so stand a fifth further out than that
                        local need = CONFIG.NLGapClearance / math.max(math.sin(width * 0.5), 0.02)
                        local r = math.clamp(math.max(need * CONFIG.NLSafety, CONFIG.NLMinRadius),
                            CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                        -- how far round the circle we would have to walk
                        local turn = math.abs((middle - mine + math.pi) % (2 * math.pi) - math.pi)
                        local walk = turn * math.max(offset.Magnitude, r) + math.abs(offset.Magnitude - r)
                        local cost = r + walk * CONFIG.NLWalkCost
                        -- only chase a shooting position that still has room in
                        -- it, not one we only just fit into
                        if r <= CONFIG.NLCastRadius then
                            cost -= 25
                        end
                        if cost < bestCost then
                            bestCost, angle, span, radius = cost, middle, width, r
                        end
                    end
                end

                -- and if beams are pouring in, stand where the count is heading
                if lead > 0 then
                    local ahead = #ends + lead
                    local packed = CONFIG.NLGapClearance / math.max(math.sin(math.pi / ahead), 0.02)
                    radius = math.clamp(math.max(radius, packed), CONFIG.NLMinRadius, CONFIG.NLMaxRadius)
                end

                -- Tried and rejected: latching a run out to 135 studs when the
                -- beam count spikes. Measured, it was much worse - 6 deaths and
                -- 0.69%/s against 0 deaths and 2.67%/s for staying close - and
                -- it got hit anyway at 94-138 studs, because the beams reach 125
                -- and we spent the fight walking instead of killing. The fights
                -- with 69-85% time in cast range are the ones with no deaths:
                -- killing the boss quickly is what removes Sun-Bursts, not
                -- outrunning them.
                -- Sun-Burst: the Champion teleports back onto the pillar and
                -- only then spawns beams, so the return is the warning. Running
                -- on the beam count instead was measured far worse - the run out
                -- takes 4.4 s and we were caught halfway every time. Started on
                -- the teleport there is time to arrive: beams reach 125 studs,
                -- so past that nothing can touch us.
                if now < (self.NLSunburstUntil or 0) then
                    radius = math.max(radius, CONFIG.NLSunburstRadius or 75)
                    self.NLBursting = true
                else
                    self.NLBursting = false
                end
                self.NLWantRadius, self.NLGapDegrees = radius, math.deg(span)
                self.NLLead = lead
                goal = flatPivot + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
                preferred = unit(flatten(goal - root.Position))
            end
        end
        -- Bob: measured 122 studs away with "closing for close-range mob combo"
        -- blocking 91% of casts - it was permanently on its way in and never
        -- arriving, which is why he barely lost health. His opening wave also
        -- grows as it travels, so the circle is smallest next to him: close is
        -- both where the damage happens and where the wave is easiest to step
        -- around.
        if bob and enemy.Root and enemy.Root.Parent then
            local offset = flatten(root.Position - enemy.Root.Position)
            local out = offset.Magnitude > 1 and offset.Unit or Vector3.new(1, 0, 0)
            local stand = enemy.Root.Position + out * CONFIG.NLBobRadius
            goal = Vector3.new(stand.X, root.Position.Y, stand.Z)
            preferred = unit(flatten(goal - root.Position))
        end

        -- Mobs: walk a circle around them instead of standing and trading.
        -- They close the distance and fire straight lines at where you are, so
        -- a constant orbit inside our own cast range beats both behaviours at
        -- once - their shots land behind us and they never arrive.
        if not champion and not bob and enemy then
            local ok, spot = pcall(self.GetMobOrbitGoal, self, enemy)
            if ok and spot then
                goal = spot
                preferred = unit(flatten(goal - root.Position))
            end
        end

        -- Leading a colour orb into its crystal beats any standing position:
        -- the orb homes at walking speed, so it is never outrun, and the only
        -- way it ends is at the crystal.
        local orbErrand = false
        if self.NLOrbGoal and now < (self.NLOrbUntil or 0) then
            goal = self.NLOrbGoal
            preferred = unit(flatten(goal - root.Position))
            orbErrand = true
        end

        local standing=risk(list,root.Position,0)+risk(list,root.Position,0.3)+risk(list,root.Position,0.65)
            +risk(list,root.Position,1.0)+risk(list,root.Position,1.5)
        if not goal and standing<1 then
            self.NLDirection=nil
            return solve(self,routeDirection,enemy,yaw)
        end
        local speed=math.max(self.CharacterService.Humanoid.WalkSpeed,8)
        -- How far ahead we look before choosing a direction, and this is the
        -- single most important number in the whole fight.
        --
        -- Bob was on the mob horizon of 0.65 seconds. At 24 studs a second that
        -- is 15 studs of travel - and his wave discs have radii of 11 to 38. So
        -- standing near the middle of one, EVERY candidate direction still ends
        -- inside the box after 15 studs. Every option scores the same, nothing
        -- looks like an escape, and the planner shuffles on the spot. That is
        -- exactly what the frame log showed: 2 studs from the centre at the
        -- start, 3 studs after 1.7 seconds, dead.
        --
        -- When the hazard is wider than the distance we look, there is no
        -- escape to find. His attacks are arena-scale, so the lookahead has to
        -- be too: 2.6 seconds is 62 studs, which crosses out of a 76 stud
        -- corridor from near its middle.
        local wide = bob or odin
        local horizon = wide and CONFIG.NLBossHorizon or (champion and 1.5 or 0.65)
        local times = wide and {0.3,0.8,1.4,2.0,2.6}
            or (champion and {0.15,0.4,0.7,1.0,1.25,1.5} or {0.12,0.3,0.5,0.65})
        local melee={}
        if not champion then
            for _,e in ipairs(self.Dungeon and self.Dungeon:GetAliveEnemies() or {}) do
                if e.Root and e.Root.Parent and getEnemyThreatClass(e)=="Melee" then
                    melee[#melee+1]=e.Root.Position
                end
            end
        end
        -- How hard we pull towards where we are supposed to stand. A flat 0.3
        -- per stud was drowned by the risk term: being inside one hazard box
        -- scores 100 and up, per time sample, while a whole step's worth of
        -- progress towards the goal is worth a handful of points. Measured
        -- against Bob, that left us 208 studs from a boss we are meant to hold
        -- at 40 - not as a decision, but because the goal could not be heard.
        -- So the pull grows with how far out of position we are, and is capped
        -- so that a lethal box still wins the argument.
        -- Where we have to be to do any damage at all, as opposed to where we
        -- would ideally stand.
        local castTarget, castRange
        if enemy and enemy.Root and enemy.Root.Parent then
            castTarget = enemy.Root.Position
            castRange = (enemy.Model and LONG_RANGE[normalizeEnemyName(enemy.Model.Name)])
                and CONFIG.NLBossCastRange or (CONFIG.DamageCastRange or 64)
        end
        local goalPull = CONFIG.NLGoalPull
        if goal then
            local away = flatten(goal - root.Position).Magnitude
            goalPull = goalPull * math.clamp(away / 25, 1, CONFIG.NLGoalPullMax)
        end
        -- Walking the orb to its crystal is not a preference to be outvoted. It
        -- is the only thing that ends the orb: it homes at walking pace, so it
        -- is never outrun, and on contact it makes a 120 stud explosion. The
        -- standing spot is deliberately past the crystal on the far side, so the
        -- orb has to fly through the crystal to reach us - it dies on the pillar
        -- and the pillar is between us and it.
        if orbErrand then
            goalPull = math.max(goalPull, CONFIG.NLOrbGoalPull)
        end
        -- the nearest live mage wave, and which way it is travelling
        local waveDir, waveNear = nil, math.huge
        if not champion and not bob then
            for _, box in ipairs(list) do
                if box.Name == "northernMageShot" and box.Distance < waveNear then
                    local v = flatten(box.V)
                    if v.Magnitude > 1 then
                        waveDir, waveNear = v.Unit, box.Distance
                    end
                end
            end
        end
        local mobFight = not champion and not bob and enemy ~= nil

        -- Bob's wave corridor: the line from him through the nearest disc.
        local waveAxis, waveAxisNear = nil, math.huge
        if bob and enemy.Root and enemy.Root.Parent then
            for _, box in ipairs(list) do
                if box.Name == "secondBossCricleHitbox" and box.Distance < waveAxisNear then
                    local along = flatten(box.CF.Position - enemy.Root.Position)
                    if along.Magnitude > 4 then
                        waveAxis, waveAxisNear = along.Unit, box.Distance
                    end
                end
            end
        end

        local best,bestScore=nil,math.huge
        for i=0,16 do
            local angle=i*math.pi/8
            local dir=i==16 and Vector3.zero or Vector3.new(math.cos(angle),0,math.sin(angle))
            local distance=speed*horizon
            -- Walkability is checked over a short step, not the whole horizon.
            -- Asking "is 62 studs of ground clear" would reject almost every
            -- direction in a room with anything in it, which would undo the
            -- long lookahead the moment it started to matter.
            -- Only the long-horizon bosses need this. Applying it everywhere
            -- quietly loosened the Champion's clearance check from 36 studs to
            -- 22, so directions that are blocked further out started passing -
            -- and his fight went from 29s and no deaths to 57s and two. His
            -- plan is to hold close to the pillar and turn with the gap, and
            -- that only works if the direction really is clear the whole way.
            local probe=wide and math.min(distance,CONFIG.NLProbeDistance) or distance
            if dir.Magnitude==0 or (self.Geometry:IsDirectionClear(dir,probe,yaw)
                and self.Geometry:IsGroundPadded(root.Position+dir*probe,CONFIG.EdgeHardPadding)) then
                local score=0
                for _,t in ipairs(times) do
                    local position=root.Position+dir*speed*t
                    score+=risk(list,position,t)
                    for _,mob in ipairs(melee) do
                        score+=math.max(0,CONFIG.NLMeleeKeepOut-flatten(position-mob).Magnitude)
                            *CONFIG.NLMeleeWeight
                    end
                end
                if goal then
                    score+=flatten(root.Position+dir*distance-goal).Magnitude*goalPull
                else score-=dir:Dot(preferred)*4 end
                if castTarget then
                    local after=flatten(root.Position+dir*distance-castTarget).Magnitude
                    score+=math.max(0,after-castRange)*CONFIG.NLRangePull
                end
                if self.NLDirection then score+=(1-dir:Dot(self.NLDirection))*1.5 end
                if dir.Magnitude == 0 then
                    if mobFight then
                        score += CONFIG.NLStrategyExperiment
                            and CONFIG.NLStandStillCostExp or CONFIG.NLStandStillCost
                    else
                        -- Standing still was FREE at a boss. Only mob fights
                        -- were ever charged for it, and measured against Bob on
                        -- Nightmare we hold still for 20% of the fight - with
                        -- his wave at 119% and his beam at 113%, every one of
                        -- those frames is a coin flip we do not need to take.
                        -- Lower than the mob figure on purpose: boss dodging is
                        -- a precise business and there are real moments when
                        -- the square you are on is the right one. This only has
                        -- to beat a tie.
                        score += CONFIG.NLBossStandStillCost
                    end
                end
                if waveDir and waveNear <= CONFIG.NLWaveLaneRange and dir.Magnitude > 0 then
                    score += math.abs(dir:Dot(waveDir)) * CONFIG.NLWaveLaneCost
                end
                if CONFIG.NLStrategyExperiment and waveDir
                    and waveNear <= CONFIG.NLWaveLaneRange
                then
                    -- How much daylight is left between us and the nearest bar
                    -- at the end of the move. Sitting in the six stud slot
                    -- between two of them reads as perfectly safe to everything
                    -- else in this scorer, because it is - right up until the
                    -- next wave arrives on a slightly different line and we are
                    -- still standing there.
                    for _, t in ipairs(times) do
                        local position = root.Position + dir * speed * t
                        local closest = math.huge
                        for _, box in ipairs(list) do
                            if box.Name == "northernMageShot" then
                                local here = box.CF:PointToObjectSpace(position)
                                local dx = math.max(math.abs(here.X) - box.Half.X, 0)
                                local dz = math.max(math.abs(here.Z) - box.Half.Z, 0)
                                closest = math.min(closest, math.sqrt(dx*dx + dz*dz))
                            end
                        end
                        if closest < CONFIG.NLMageClearOut then
                            score += (CONFIG.NLMageClearOut - closest) * CONFIG.NLMageClearCost
                        end
                    end
                end
                if waveAxis and waveAxisNear <= CONFIG.NLBobWaveRange then
                    if dir.Magnitude > 0 then
                        score += math.abs(dir:Dot(waveAxis)) * CONFIG.NLBobWaveAxisCost
                    else
                        score += CONFIG.NLBobWaveAxisCost      -- standing in it is the worst option
                    end
                end
                if score<bestScore then best,bestScore=dir,score end
            end
        end

        -- Boxed in is not a reason to stand there.
        --
        -- Measured over a mob fight: eight per cent of frames under three studs
        -- a second, and two per cent with all sixteen directions failing the
        -- clearance gate at once. In those frames standing was not chosen over
        -- moving, it was the only thing left on the list - so the 140 we charge
        -- for holding still never got compared against anything, and we planted
        -- ourselves in the middle of a pack that was closing in.
        --
        -- When a pack surrounds us every direction has a body in it, which is
        -- exactly when moving matters most. So ask again with a step short
        -- enough to be a sidestep rather than a charge, and take the best of
        -- those. Sideways first, because a way round is what we want, not a way
        -- through: the two directions across our facing are tried before the
        -- ones ahead and behind.
        -- Boxed in at a boss is rarer - 4 frames in 147 against Bob - but the
        -- consequence is worse, so the same sidestep applies.
        if (not best or best.Magnitude == 0) then
            local shortest, shortestScore = nil, math.huge
            local facing = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
            for i = 0, 15 do
                local angle = i * math.pi / 8
                local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
                if self.Geometry:IsDirectionClear(dir, 6, yaw) then
                    local position = root.Position + dir * 6
                    -- Sideways beats forwards and backwards, then the ordinary
                    -- risk of the square decides between the two sides.
                    local sideways = 1 - math.abs(dir:Dot(facing))
                    local score = risk(list, position, 0.25) - sideways * 40
                    for _, mob in ipairs(melee) do
                        score += math.max(0, CONFIG.NLMeleeKeepOut - flatten(position-mob).Magnitude)
                            * CONFIG.NLMeleeWeight
                    end
                    if score < shortestScore then shortest, shortestScore = dir, score end
                end
            end
            if shortest then best, bestScore = shortest, shortestScore end
        end

        if not best then self.NLDirection=nil return solve(self,routeDirection,enemy,yaw) end
        self.NLAt,self.NLDirection=now,best
        self.NLEmergency,self.NLDodging=standing>=100,best.Magnitude>0.05
        self.LastDodgeReason=champion and "nl-champion-live" or "nl-mob-live"
        self.LastSolve=now
        self.CachedDirection,self.CachedYaw,self.CachedDodging=best,yaw,self.NLDodging
        self.IsDodging=self.NLDodging
        if self.NLDodging then self.LastMovement=best end
        self.NLLiveBoxes,self.NLLiveBeams=#list,#beams
        return best,yaw,self.NLEmergency,self.NLDodging
    end

    ---------------------------------------------------------------------------
    -- Let the shuriken fly at the bosses of this dungeon instead of walking it
    -- in by hand. Contained to Northern Lands bosses and restored immediately,
    -- so nothing else in the script sees a different range.
    ---------------------------------------------------------------------------
    local oldBossUpdate = CombatController.Update
    function CombatController:Update(enemy)
        if northern() and enemy and enemy.Model then
            local who = normalizeEnemyName(enemy.Model.Name)
            if LONG_RANGE[who] then
                local saved = CONFIG.DamageCastRange
                CONFIG.DamageCastRange = CONFIG.NLBossCastRange
                local ok, result = pcall(oldBossUpdate, self, enemy)
                CONFIG.DamageCastRange = saved
                return ok and result or false
            elseif not NL_BOSSES[who] then
                local savedCast, savedBurst = CONFIG.DamageCastRange, CONFIG.MobBurstRange
                CONFIG.DamageCastRange = CONFIG.NLMobCastRange
                CONFIG.MobBurstRange = CONFIG.NLMobCastRange
                local ok, result = pcall(oldBossUpdate, self, enemy)
                CONFIG.DamageCastRange, CONFIG.MobBurstRange = savedCast, savedBurst
                return ok and result or false
            end
        end
        return oldBossUpdate(self, enemy)
    end

    -- This file loads last of the planners, so its version string is the one
    -- that survives. A measurement is worthless if we cannot say which build
    -- produced it, and we have already once scored a fight against a build that
    -- turned out to be the previous one, served from a stale cache.
    local newController = UIWController.new
    function UIWController.new()
        local self = newController()
        self.Version = "49.4-weights"
        return self
    end
end
