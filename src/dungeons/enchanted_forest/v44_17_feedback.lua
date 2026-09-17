-- v44.17: user feedback round (Enchanted Forest).
--   * finished line attacks are not dangerous: once the warning has faded
--     (and the touch window has passed) the attack no longer blocks us
--   * the Ancient Enchanted Tree is always the target while it lives
--   * around the Tree, dodges keep their sideways part but lose the part that
--     pushes away from the shore
--   * Enchanted Forest mobs: walk in closer before casting
do
    -- The Tree (room 4) is a boss too: boss movement, boss casting, no hit & run.
    MINI_BOSS_NAMES["ancient enchanted tree"] = true
    MINI_BOSS_NAMES["enchanted forest dragon"] = true

    CONFIG.PostWarningWindow = 0.9
    CONFIG.ForestMobCastRange = 48

    local function isTree(enemy)
        return enemy and enemy.Model
            and normalizeEnemyName(enemy.Model.Name) == "ancient enchanted tree"
            and enemy.Root and enemy.Root.Parent
    end

    local function inForest()
        local value = Workspace:FindFirstChild("dungeonName")
        return value and value:IsA("StringValue") and value.Value == "Enchanted Forest"
    end

    ---------------------------------------------------------------------------
    -- Warning faded -> attack done.
    ---------------------------------------------------------------------------
    local oldActive = HazardTracker.IsContainerActive
    function HazardTracker:IsContainerActive(container, now)
        now = now or os.clock()
        local result = oldActive(self, container, now)
        if not result then
            return false
        end
        local state = self.ContainerState[container]
        if not state then
            return result
        end
        if not state.PrecastPart and (now - (state.FirstSeen or now) < 0.8) then
            local pre = container:FindFirstChild("precast", true)
            if pre and pre:IsA("BasePart") then
                state.PrecastPart = pre
            end
        end
        local pre = state.PrecastPart
        if not pre or not pre.Parent then
            return result
        end
        if pre.Transparency < 0.95 then
            state.PrecastSeen = true
            state.PrecastLastVisible = now
            return true
        end
        if state.PrecastSeen
            and now - state.PrecastLastVisible > CONFIG.PostWarningWindow
            and now - (state.FirstSeen or now) > CONFIG.TouchDangerWindow + 0.2
        then
            return false
        end
        return result
    end

    ---------------------------------------------------------------------------
    -- Tree first.
    ---------------------------------------------------------------------------
    local oldSelect = UIWController.SelectTarget
    function UIWController:SelectTarget()
        local best = oldSelect(self)
        if best and isTree(best) then
            return best
        end
        for _, enemy in ipairs(self.Dungeon:GetAliveEnemies()) do
            if isTree(enemy) and enemy.Humanoid and enemy.Humanoid.Health > 0 then
                local distance = flatten(enemy.Root.Position - self.Character.Root.Position).Magnitude
                if distance <= 260 then
                    if enemy.Model ~= self.CurrentEnemyModel then
                        self:SetTarget(enemy)
                    else
                        self.CurrentEnemy = enemy
                    end
                    return enemy
                end
            end
        end
        return best
    end

    ---------------------------------------------------------------------------
    -- Around the Tree: never drift away from the shore while dodging.
    ---------------------------------------------------------------------------
    local oldSolve = DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection, enemy, targetYaw)
        local direction, yaw, emergency, dodging = oldSolve(self, routeDirection, enemy, targetYaw)
        if not isTree(enemy) or not direction or direction.Magnitude <= 0.05 then
            return direction, yaw, emergency, dodging
        end
        local reason = self.LastDodgeReason
        if reason == "tree-sweeper" then
            return direction, yaw, emergency, dodging
        end
        local root = self.CharacterService.Root
        local rel = flatten(root.Position - enemy.Root.Position)
        local stand = self.Owner and self.Owner.TreeStandGoal
        local standR = stand and flatten(stand - enemy.Root.Position).Magnitude or 100
        if rel.Magnitude <= standR + 4 then
            return direction, yaw, emergency, dodging
        end
        local out = rel.Unit
        local outward = direction:Dot(out)
        if outward <= 0.1 then
            return direction, yaw, emergency, dodging
        end
        local sideways = direction - out * outward
        if sideways.Magnitude < 0.2 then
            return direction, yaw, emergency, dodging
        end
        local dir = sideways.Unit
        if self.Hazards:IsTrajectoryClear(root.Position, dir, targetYaw, 5)
            and self.Geometry:IsDirectionClear(dir, 5, directionToYaw(dir))
        then
            local scaled = dir * direction.Magnitude
            self.CachedDirection = scaled
            self.LastMovement = dir
            return scaled, yaw, emergency, dodging
        end
        return direction, yaw, emergency, dodging
    end

    ---------------------------------------------------------------------------
    -- Enchanted Forest mobs: cast from closer.
    ---------------------------------------------------------------------------
    local function withMobRange(fn)
        return function(self, enemy, ...)
            if enemy and not isBossEnemy(enemy) and inForest() then
                local base = CONFIG.DamageCastRange
                CONFIG.DamageCastRange = math.min(base, CONFIG.ForestMobCastRange)
                local ok, a, b = pcall(fn, self, enemy, ...)
                CONFIG.DamageCastRange = base
                if not ok then error(a, 0) end
                return a, b
            end
            return fn(self, enemy, ...)
        end
    end

    CombatController.Update = withMobRange(CombatController.Update)
    CombatController.ShouldHoldApproach = withMobRange(CombatController.ShouldHoldApproach)

    local oldNew = UIWController.new
    function UIWController.new()
        local self = oldNew()
        self.Version = "44.17"
        return self
    end
end

