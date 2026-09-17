-- v44.3: Ancient Temple Protector / Water Burst strategy.
do
    CONFIG.ProtectorMinRange=18
    CONFIG.ProtectorIdealRange=24
    CONFIG.ProtectorMaxRange=32
    local function protector(enemy)
        return enemy and enemy.Model and normalizeEnemyName(enemy.Model.Name)=="ancient temple protector"
            and enemy.Root and enemy.Root.Parent
    end
    local function band(distance)
        return math.max(0,CONFIG.ProtectorMinRange-distance)+math.max(0,distance-CONFIG.ProtectorMaxRange)
    end
    local oldBandError=DodgeSolver.GetBossBandError
    function DodgeSolver:GetBossBandError(position)
        local e=self.CurrentSolveEnemy
        if protector(e) then return band(flatten(e.Root.Position-position).Magnitude) end
        return oldBandError(self,position)
    end
    local oldBandScore=DodgeSolver.GetBossBandScore
    function DodgeSolver:GetBossBandScore(from,to)
        local e=self.CurrentSolveEnemy
        if protector(e) then
            local before=band(flatten(e.Root.Position-from).Magnitude)
            local after=band(flatten(e.Root.Position-to).Magnitude)
            return (before-after)*120-(after>before+1 and 300 or 0)
        end
        return oldBandScore(self,from,to)
    end

    local oldPreferred=DodgeSolver.GetCombatPreferred
    function DodgeSolver:GetCombatPreferred(routeDirection,enemy,targetYaw)
        if not protector(enemy) or self.ForceRouteMovement or self.TargetBlocked then
            return oldPreferred(self,routeDirection,enemy,targetYaw)
        end
        self.AttackHolding=false
        local root=self.CharacterService.Root
        local delta=flatten(enemy.Root.Position-root.Position)
        local distance=delta.Magnitude
        if distance<0.1 or distance>160 or not self.Combat:HasLineOfSight(enemy) then
            return oldPreferred(self,routeDirection,enemy,targetYaw)
        end
        local toward=delta.Unit
        if distance>CONFIG.ProtectorMaxRange then
            local probe=math.min(12,distance-CONFIG.ProtectorIdealRange)
            if self.Geometry:IsDirectionClear(toward,probe,targetYaw)
                and self.Geometry:IsWideSegmentClear(root.Position,root.Position+toward*probe,3) then
                self.TravelMode=false
                return toward
            end
            return unit(flatten(routeDirection))
        end
        self.TravelMode=false
        local tangent=self:GetSafeOrbitTangent(toward,targetYaw)
        if distance<CONFIG.ProtectorMinRange then return unit(tangent-toward*0.35) end
        local state=self.Combat:GetPreparationState()
        if state.AnyDamageReady or self.Combat:IsBusyCasting() then
            self.AttackHolding=true
            return Vector3.zero
        end
        return tangent*0.45+toward*math.clamp((distance-CONFIG.ProtectorIdealRange)/16,-0.2,0.2)
    end

    function DodgeSolver:IsProtectorBurstActive()
        if not protector(self.CurrentSolveEnemy) then return false end
        for _,d in ipairs(self.Hazards.CachedActive) do
            local part=d.Part
            if part and part.Parent then
                if d.SlamBand then return true end
                if d.IsPrecast then
                    local hit=part.Parent:FindFirstChild("hitBox")
                    if hit and hit:IsA("BasePart") and hit.Size.Y>=120
                        and math.min(hit.Size.X,hit.Size.Z)<=16 then return true end
                end
            end
        end
        return false
    end

    function DodgeSolver:FindProtectorSideExit(targetYaw)
        local enemy=self.CurrentSolveEnemy
        if not protector(enemy) or self.ForceRouteMovement or not self:IsProtectorBurstActive() then return nil end
        local origin=self.CharacterService.Root.Position
        local delta=flatten(enemy.Root.Position-origin)
        if delta.Magnitude<CONFIG.ProtectorMinRange or delta.Magnitude>160 then return nil end
        local toward=delta.Unit
        local oldTight=self.Hazards.TightPadding
        self.Hazards.TightPadding=true
        local ok,direction=pcall(function()
            local initial={}
            for _,part in ipairs(self.Hazards:GetBodyOverlaps(origin,targetYaw)) do initial[part]=true end
            local best,bestScore=nil,-math.huge
            -- Try short lateral exits first. Going forward is considered only
            -- when it also passes every corridor and endpoint check.
            for _,length in ipairs({3,6,9,12}) do
                for _,angle in ipairs({90,-90,65,-65,40,-40}) do
                    local dir=unit(rotateXZ(toward,angle))
                    local point=origin+dir*length
                    local distance=flatten(enemy.Root.Position-point).Magnitude
                    if distance>=CONFIG.ProtectorMinRange-2 and distance<=delta.Magnitude+3
                        and self.Hazards:IsFullBodyClear(point,targetYaw)
                        and self.Geometry:IsDirectionClear(dir,length,targetYaw)
                        and self.Geometry:IsGroundPadded(point,3)
                        and not self.Dungeon:GetEnemyDangerAt(point) then
                        local clear=true
                        local departed={}
                        for step=1,math.ceil(length/2) do
                            local at=origin+dir*(length*step/math.ceil(length/2))
                            if not self.Geometry:HasGround(at) then clear=false break end
                            local present={}
                            for _,part in ipairs(self.Hazards:GetBodyOverlaps(at,targetYaw)) do
                                present[part]=true
                                if not initial[part] or departed[part] then clear=false break end
                            end
                            if not clear then break end
                            for part in pairs(initial) do if not present[part] then departed[part]=true end end
                        end
                        if clear and self.Hazards:IsPredictiveTrajectoryClear(origin,dir,targetYaw,length) then
                            local score=-length*12+(delta.Magnitude-distance)*18
                            if self.LastMovement.Magnitude>0 then score+=dir:Dot(self.LastMovement)*8 end
                            if score>bestScore then best,bestScore=dir,score end
                        end
                    end
                end
                if best then return best end
            end
            return nil
        end)
        self.Hazards.TightPadding=oldTight
        if not ok then error(direction,0) end
        return direction
    end

    local oldHitbox=DodgeSolver.GetActiveHitboxEscape
    function DodgeSolver:GetActiveHitboxEscape(targetYaw)
        if protector(self.CurrentSolveEnemy)
            and self.Hazards:GetOverlapCountAt(self.CharacterService.Root.Position,targetYaw)>0 then
            local direction=self:FindProtectorSideExit(targetYaw)
            if direction then
                self.ProtectorSideExits=(self.ProtectorSideExits or 0)+1
                return direction,targetYaw,false
            end
        end
        return oldHitbox(self,targetYaw)
    end

    local oldAura=DodgeSolver.FindExpandingAuraDodge
    function DodgeSolver:FindExpandingAuraDodge(preferred,targetYaw)
        local direction=self:FindProtectorSideExit(targetYaw)
        if direction then
            self.ProtectorSideExits=(self.ProtectorSideExits or 0)+1
            return direction,targetYaw,false
        end
        return oldAura(self,preferred,targetYaw)
    end

    local oldAttackLane=DodgeSolver.FindBossAttackDodge
    function DodgeSolver:FindBossAttackDodge(enemy,targetYaw)
        if protector(enemy) then return self:FindProtectorSideExit(targetYaw) end
        return oldAttackLane(self,enemy,targetYaw)
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.3"
        return self
    end
end

