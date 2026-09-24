
local CONFIG = {
    WalkSpeed = 16,

    DesiredCombatRange = 42,
    MinimumCombatRange = 22,
    BossCombatRange = 28,
    BossMinimumRange = 19,
    BossApproachDistance = 38,

    -- Ice Crash's replicated hitbox template reaches about 66 studs forward.
    DamageCastRange = 64,

    -- Stop just outside the attack zone until the next Q/E sequence is ready.
    PreAggroHoldDistance = 72,
    AttackCommitWindow = 2.75,

    AggressiveApproachDistance = 52,

    -- v40 boss band: attack from inside cast range without hugging the boss.
    BossMinRange = 30,
    BossIdealRange = 44,
    BossMaxRange = 56,

    -- v40 staging + hit & run for normal mobs.
    StageDistance = 84,          -- wait between DamageCastRange and this until skills are ready
    HitAndRun = true,            -- back off after casting while damage skills recover
    RetreatDistance = 74,        -- back off until at least this far from the target
    RetreatResumeWait = 0.6,     -- stop backing off when damage is this close to ready

    -- Demon Warrior behavior.
    MeleeSafetyRadius = 34,
    MeleeEmergencyRadius = 24,
    MeleePanicExitRadius = 32,
    ProximitySafetyBonus = 8,
    ProximityEmergencyBonus = 6,
    MeleeClusterPanicRadius = 27,
    MeleeClusterPanicCount = 2,
    MeleeHardNoGoRadius = 15,
    MeleeOrbitInner = 30,
    MeleeOrbitOuter = 40,
    MultiMeleeRadius = 46,
    MeleeTravelOverrideDistance = 58,

    GoalChangeThreshold = 18,
    DirectPathDistance = 42,

    -- Navigation v2: one authoritative Roblox path.
    PathAgentRadius = 2.75, -- v39: was 2.25; keeps routes further off walls/corners

    PathAgentHeight = 5,
    PathWaypointSpacing = 4,
    PathWaypointStartRadius = 2,
    PathPlaneVelocityMultiplier = 0.0625,
    PathPlaneMinThreshold = 1.0,
    PathGoalReachDistance = 3.5,
    ProgressionCheckpointReachDistance = 2.25,
    ProgressionProbeRetry = 0.45,
    ProgressionFrontierReachDistance = 5.0,
    ProgressionFrontierProbeRadii = {24, 40, 58},
    ProgressionFrontierMinProgress = 3.0,
    ProgressionFrontierProbeBudget = 3,
    ProgressionFrontierCacheTTL = 1.15,
    ProgressionFrontierFailureCacheTTL = 0.55,
    PathJumpRetry = 0.40,
    PathStuckRepathTime = 0.70,
    PathRecomputeThrottle = 0.30,

    -- NoPath recovery.
    NoPathRetryInterval = 0.80,
    NoPathRetryMaxInterval = 3.20,
    NoPathHeavyFallbackCooldown = 2.00,
    NoPathGridStep = 5,
    NoPathGridMargin = 90,
    NoPathGridMaxSpan = 430,
    NoPathGridProbeAbove = 85,
    NoPathGridProbeDepth = 240,
    NoPathExpectedHeightTolerance = 14.0,
    NoPathGroundSurfaceScanLimit = 16,
    NoPathGridMinNormalY = 0.35,
    NoPathGridMaxStepHeight = 5.25,
    NoPathGridMaxNodes = 5000,
    DirectGroundCorridorMaxDistance = 220,
    DirectGroundCorridorStep = 12,
    DirectGroundCorridorProbeAbove = 20,
    NoPathGridJumpRise = 2.75,
    NoPathEdgeProbeAbove = 10,
    NoPathEdgeProbeDepth = 25,
    NoPathEdgeHeightTolerance = 3.25,

    -- Navigation/combat handoff.
    TravelRouteDetourDot = 0.78,
    TravelDirectProbeDistance = 24,

    NavigationEnterDistance = 82,
    NavigationExitDistance = 72,
    NavigationExitConfirmTime = 0.22,

    NavigationAutoJumpCooldown = 0.55,

    GroundProbeDepth = 16,

    EdgeHardPadding = 10,
    EdgeWarningPadding = 16,
    EdgeCacheTTL = 0.16,
    EdgeCacheCell = 2,

    BodyPaddingXZ = 1.25,
    BodyPaddingY = 0.25,

    HazardPaddingXZ = 2.35,
    HazardPaddingY = 0.8,

    DodgeDistance = 12,
    DodgeCommitTime = 0.24,
    DodgeReleaseGrace = 0.12,
    DodgeReuseProbeDistance = 7,
    DangerLookaheadDistance = 12,
    PrecastLookaheadTime = 0.90,
    PrecastSafetyPadding = 2.25,
    PrecastColumnHeight = 7,
    PrecastThinHeight = 2.5,

    ProjectilePredictionHorizon = 1.15,
    ProjectilePredictionStep = 0.06,
    ProjectileVelocityMin = 4,
    ProjectileVelocitySmoothing = 0.55,
    ProjectileExtraPaddingXZ = 2.20,
    ProjectileExtraPaddingY = 0.6,

    AuraRadius = 34,
    AuraScanRadii = {3, 6, 10, 15, 21, 28, 34},
    AuraDotsPerRing = 20,
    AuraRingStepTime = 0.22,
    MobGroupDotCount = 24,
    TacticalVisualInterval = 0.22,
    PathVisualInterval = 0.25,

    -- Enchanted Forest / Crystal Golem mechanics.
    GolemRockPickupRadius = 7.0,
    GolemRockPickupDwell = 0.18,
    GolemRockPlaceRadius = 8.0,
    GolemRockPlaceRetry = 2.25,
    GolemOrbitInner = 31,
    GolemOrbitOuter = 50,
    GolemOrbKiteBias = 0.42,
    GolemForcedRegionInset = 2.0,
    GolemSweeperLeadDistance = 18,
    GolemSweeperEndpointPadding = 10,

    DodgeSolveInterval = 1 / 20,
    RouteRiskInterval = 1 / 10,
    HazardCacheInterval = 1 / 20,
    TargetRefreshInterval = 0.10,
    WorldRefreshInterval = 0.35,

    HazardVisualScanInterval = 0.075,
    HazardSpawnGrace = 0.20,
    HazardInactiveGrace = 0.12,
    TouchDangerWindow = 1.6,     -- v40: seconds after spawn an armed (touch) hitbox counts as live
    NoCastWhileEscaping = false, -- v40: tested; blocked most casts during rain phases
    LaneBallMinSize = 10,        -- v40: 17-stud "Model" balls that fly down lanes
    LaneMemory = 10,             -- seconds a lane warning is remembered
    LaneBallDelayMin = 5.0,      -- a ball appears this long after its lane warning...
    LaneBallDelayMax = 9.0,      -- ...at most this long
    LaneBallMovingSpeed = 20,    -- above this speed the corridor follows the ball's direction
    LaneCorridorHalfLength = 250,
    LaneCorridorExtraWidth = 1.5,
    -- v42 attack windows
    LaneLaserLifetime = 6.2,     -- Water Lines: the 16x150 lane is dangerous for its whole life
    OrbCorridorLength = 260,     -- Water Orbs fly toward where you were when they spawned
    TightExitPadding = 0.5,      -- padding used when searching for a gap to escape into
    CommitLeadTime = 0.4,        -- leave the staging spot this early before skills are ready
    BullseyeWindow = 1.4,        -- Cube Pylon shot: fires ~0.8-1.0 s after it appears
    BullseyeMargin = 0.4,
    TargetSwitchMargin = 15,     -- a new target must score this much better to switch

    -- v43 target scoring (lower is better; distance in studs is the base)
    PackRadius = 20,             -- enemies this close together count as a pack
    PackBonus = 8,               -- per extra enemy in the pack (max 4)
    LowHealthBonus = 30,         -- nearly dead enemies are finished first
    CloseThreatBonus = 25,       -- melee/proximity enemies already within 40 studs
    OtherLevelPenalty = 40,      -- enemies on another floor level

    -- v43 bosses and leftovers
    BossLosCheckRange = 150,     -- follow the path when the boss is out of sight within this range
    GrowthHoldTime = 1.5,        -- a growing attack stays live this long after it last grew
    GrowthLookahead = 0.8,       -- seconds of growth to avoid ahead of time
    SlamBandHalfLength = 170,    -- Protector's Slam: avoid its whole line (it grows out of the arena)
    IgnoreOrphanHazards = true,  -- leftovers with no living enemy nearby never damage
    OrphanHazardRadius = 180,

    -- v40 tanking: with high health, ignore attacks that barely hurt.
    TankEnabled = true,
    TankMaxHitFraction = 0.12,   -- only attacks that take <= 12% max health per hit
    TankHitsAssumed = 2,         -- assume you might take this many in a row
    TankHealthFloor = 0.55,      -- and still stay above 55% health
    TankMinSamples = 2,          -- hits needed before an attack type is trusted
    EngageMaxHeightDiff = 8,     -- v41: targets further above/below are reached by path first
    HotAreaRadius = 45,          -- v40: don't stand and wait when attacks are active this close
    HotAreaHazards = 2,

    BroadHazardSweepInterval = 0.35,
    BroadHazardSweepRadius = 260,

    ESPInterval = 1 / 4,
    ESPRenderDistance = 110,
    ESPMaxEntries = 12,
    ESPHideWhileInside = true,

    -- v39 stuck recovery / corner handling
    StuckTimeout = 0.8,          -- no progress for this long = stuck
    StuckBlockedTimeout = 0.3,   -- faster when something is directly in front
    StuckSpotRadius = 7,         -- stuck events this close count as the same spot
    StuckSpotMemory = 25,        -- seconds a stuck spot is remembered
    LoopWindow = 6,              -- seconds of back-and-forth that count as a loop
    LoopRadius = 6,              -- ...while staying inside this radius
    AvoidZoneSize = 7,
    AvoidZoneCost = 20,          -- pathfinder cost multiplier inside a stuck spot
    AvoidZoneLifetime = 60,
    MaxAvoidZones = 16,
    SavedStuckSpotsPerDungeon = 10,

    -- v39 auto retry
    ReplayDelay = 3,             -- seconds after the dungeon finishes (loot)
    ReplayAttempts = 5,
    ReplayRetryInterval = 3,
    ReplayOnDeathDelay = 6,      -- v41: replay when dead this long (solo death ends the run)

    StuckTime = 0.45,
    StuckEarlyVelocity = 1.15,
    StuckEarlyTime = 0.22,
    StuckProgressDistance = 0.85,
    StuckRecoveryDuration = 0.58,

    RouteAngles = {0, 15, -15, 30, -30, 45, -45, 60, -60, 80, -80},

    DodgeAngles = {0, 15, -15, 30, -30, 45, -45, 60, -60, 80, -80, 105, -105, 135, -135, 165, -165, 180},

    EmergencyBodyYawOffsets = {0, 45, -45, 90, -90, 135, -135, 180},

    Debug = false,

    -- v44.7 run log file (in-memory telemetry is always on).
    TelemetrySave = false,
    TelemetrySaveInterval = 20,
}

local SETTINGS_FOLDER = "UIW"
local SETTINGS_FILE = SETTINGS_FOLDER .. "/settings.json"
local AUTOEXEC_FILE = "UIW/UIW_Aura_Mage_v13.lua"

-- Ordered by the level needed to enter each mode. Carry progression uses the
-- lowest configured alt, not the host's level.
local CARRY_STAGES = {
    { Name = "Desert Temple", Difficulty = "Easy", Level = 1 },
    { Name = "Desert Temple", Difficulty = "Medium", Level = 6 },
    { Name = "Desert Temple", Difficulty = "Hard", Level = 12 },
    { Name = "Desert Temple", Difficulty = "Insane", Level = 20 },
    { Name = "Desert Temple", Difficulty = "Nightmare", Level = 27 },
    { Name = "Winter Outpost", Difficulty = "Easy", Level = 30 },
    { Name = "Winter Outpost", Difficulty = "Medium", Level = 40 },
    { Name = "Winter Outpost", Difficulty = "Hard", Level = 45 },
    { Name = "Winter Outpost", Difficulty = "Insane", Level = 50 },
    { Name = "Winter Outpost", Difficulty = "Nightmare", Level = 55 },
    { Name = "Pirate Island", Difficulty = "Insane", Level = 60 },
    { Name = "Pirate Island", Difficulty = "Nightmare", Level = 65 },
    { Name = "King's Castle", Difficulty = "Insane", Level = 70 },
    { Name = "King's Castle", Difficulty = "Nightmare", Level = 75 },
    { Name = "The Underworld", Difficulty = "Insane", Level = 80 },
    { Name = "The Underworld", Difficulty = "Nightmare", Level = 85 },
    { Name = "Samurai Palace", Difficulty = "Insane", Level = 90 },
    { Name = "Samurai Palace", Difficulty = "Nightmare", Level = 95 },
    { Name = "The Canals", Difficulty = "Insane", Level = 100 },
    { Name = "The Canals", Difficulty = "Nightmare", Level = 105 },
    { Name = "Ghastly Harbor", Difficulty = "Insane", Level = 110 },
    { Name = "Ghastly Harbor", Difficulty = "Nightmare", Level = 115 },
    { Name = "Steampunk Sewers", Difficulty = "Insane", Level = 120 },
    { Name = "Steampunk Sewers", Difficulty = "Nightmare", Level = 125 },
    { Name = "Orbital Outpost", Difficulty = "Insane", Level = 140 },
    { Name = "Orbital Outpost", Difficulty = "Nightmare", Level = 145 },
    { Name = "Volcanic Chambers", Difficulty = "Insane", Level = 150 },
    { Name = "Volcanic Chambers", Difficulty = "Nightmare", Level = 155 },
    { Name = "Aquatic Temple", Difficulty = "Insane", Level = 160 },
    { Name = "Aquatic Temple", Difficulty = "Nightmare", Level = 165 },
    { Name = "Enchanted Forest", Difficulty = "Insane", Level = 170 },
    { Name = "Enchanted Forest", Difficulty = "Nightmare", Level = 175 },
    { Name = "Northern Lands", Difficulty = "Insane", Level = 180 },
    { Name = "Northern Lands", Difficulty = "Nightmare", Level = 185 },
}

local DEFAULT_SETTINGS = {
    Enabled = true,
    AutoCombat = true,
    AutoDodge = true,
    AutoESP = true,
    AutoPathESP = true,
    AutoRetryEnabled = true,
    ShowAura = true,
    ShowMobGroups = true,
    FPSLimitEnabled = false,
    FPSCap = 30,
    BlackScreen = false,
    CarryEnabled = false,
    CarryHostName = "",
    CarryAlts = "",
    CarryMode = "Auto",
    CarryFixedStage = 1,
    CarryHardcore = false,
    HealerEnabled = false,
    HealerTargetName = "",
    HealerAutoEquip = true,
    HealerFollowDistance = 10,
    AutoExecuteOnTeleport = false,
    LowEffects = true,
    WalkSpeed = 16,
    DesiredCombatRange = 42,
    DamageCastRange = 64,
}
