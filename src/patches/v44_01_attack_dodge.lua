-- v44.1: attack-preserving dodge choices, with unchanged safety gates.
do
    function DodgeSolver:FindBossAttackDodge(enemy,targetYaw)
        if not isBossEnemy(enemy) or not enemy.Root or not enemy.Root.Parent
            or self.ForceRouteMovement or self.ForcedRegionPart or self.TargetBlocked then return nil end
        local origin=self.CharacterService.Root.Position
        local delta=flatten(enemy.Root.Position-origin)
        if delta.Magnitude<CONFIG.BossMinRange+4 or delta.Magnitude>160 then return nil end
        local toward=delta.Unit
        local best,bestScore=nil,-math.huge
        for _,angle in ipairs({0,30,-30,60,-60,90,-90}) do
            local direction=unit(rotateXZ(toward,angle))
            local point=origin+direction*CONFIG.DodgeDistance
            if flatten(enemy.Root.Position-point).Magnitude>=CONFIG.BossMinRange
                and not self.Dungeon:GetEnemyDangerAt(point) then
                local safetyScore=self:ScoreCandidate(direction,toward,targetYaw)
                if safetyScore then
                    local after=flatten(enemy.Root.Position-point).Magnitude
                    local progress=delta.Magnitude-after
                    local score=safetyScore+math.clamp(progress,-12,12)*35
                    if after<=CONFIG.DamageCastRange-3 then score+=100 end
                    if score>bestScore then best,bestScore=direction,score end
                end
            end
        end
        return best
    end

    local oldSolve=DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection,enemy,targetYaw)
        local direction,yaw,emergency,dodging=oldSolve(self,routeDirection,enemy,targetYaw)
        local reason=self.LastDodgeReason
        if isBossEnemy(enemy) and enemy.Root and enemy.Root.Parent and direction.Magnitude>0
            and not emergency and not self.ForceRouteMovement and not self.ForcedRegionPart
            and reason~="bullseye" and reason~="sweeper" and reason~="melee" and reason~="large-attack" then
            local toward=unit(flatten(enemy.Root.Position-self.CharacterService.Root.Position))
            if direction:Dot(toward)<-0.15 and os.clock()-(self.LastAttackDodgeCheck or 0)>=0.10 then
                self.LastAttackDodgeCheck=os.clock()
                local replacement=self:FindBossAttackDodge(enemy,targetYaw)
                if replacement then
                    direction,yaw,emergency,dodging=replacement,targetYaw,false,true
                    self.LastDodgeReason="attack-lane"
                    self.AttackLaneSelections=(self.AttackLaneSelections or 0)+1
                    self.CachedDirection,self.CachedYaw=direction,yaw
                    self.CachedEmergency,self.CachedDodging=false,true
                    self.CommittedDodgeDirection=direction
                    self.DodgeCommitUntil=os.clock()+CONFIG.DodgeCommitTime
                    self.LastMovement=direction
                end
            end
        end
        return direction,yaw,emergency,dodging
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.1"
        return self
    end
end
