-- v44.2: reduce Protector frame stalls without dropping active hazards.
do
    CONFIG.AuraDodgeBudget = 24

    local oldRefresh = HazardTracker.RefreshCache
    function HazardTracker:RefreshCache(force)
        if self.SnapshotLocked then return end
        return oldRefresh(self,force)
    end

    function HazardTracker:IsBodyInWarning(position,yaw,data)
        if not data.WarningCF then self:UpdateWarningBounds(data) end
        local cf,half=data.WarningCF,data.WarningHalf
        if not cf or not half then return false end
        if self.WarningProjectionStamp~=self.LastCacheTime then
            self.WarningProjectionStamp=self.LastCacheTime
            self.WarningProjections={}
        end
        self.WarningProjections=self.WarningProjections or {}
        local entries=self.WarningProjections[data]
        if not entries then entries={} self.WarningProjections[data]=entries end
        local key=tostring(yaw or 0)..(self.TightPadding and ":tight" or ":normal")
        local projected=entries[key]
        if not projected or projected.CF~=cf or projected.Half~=half then
            local bodyCF=self:GetBodyCF(Vector3.zero,yaw)
            local bodyHalf=self:GetBodySize()*0.5
            local function radius(axis)
                return math.abs(axis:Dot(bodyCF.RightVector))*bodyHalf.X
                    +math.abs(axis:Dot(bodyCF.UpVector))*bodyHalf.Y
                    +math.abs(axis:Dot(bodyCF.LookVector))*bodyHalf.Z
            end
            local pad=self.TightPadding and CONFIG.TightExitPadding or CONFIG.PrecastSafetyPadding
            projected={CF=cf,Half=half,Offset=cf:VectorToObjectSpace(bodyCF.Position),
                Bounds=half+Vector3.new(radius(cf.RightVector)+pad,radius(cf.UpVector)+pad,radius(cf.LookVector)+pad)}
            entries[key]=projected
        end
        local point=cf:PointToObjectSpace(position)+projected.Offset
        local bounds=projected.Bounds
        return math.abs(point.X)<=bounds.X and math.abs(point.Y)<=bounds.Y and math.abs(point.Z)<=bounds.Z
    end

    local oldSolve=DodgeSolver.Solve
    function DodgeSolver:Solve(routeDirection,enemy,targetYaw)
        self.Hazards:RefreshCache(false)
        -- One consistent hazard snapshot for this non-yielding search. Rebuilding
        -- it during candidate checks previously invalidated overlap memoization.
        self.Hazards.SnapshotLocked=true
        local ok,a,b,c,d=pcall(oldSolve,self,routeDirection,enemy,targetYaw)
        self.Hazards.SnapshotLocked=false
        if not ok then error(a,0) end
        return a,b,c,d
    end

    local oldMechanic=UIWController.GetPriorityMechanicGoal
    function UIWController:GetPriorityMechanicGoal()
        if self.MechanicStepStamp==self.StepStamp and self.StepStamp then
            return self.MechanicStepGoal,self.MechanicStepState,self.MechanicStepPart,self.MechanicStepDistance
        end
        local a,b,c,d=oldMechanic(self)
        self.MechanicStepStamp=self.StepStamp
        self.MechanicStepGoal,self.MechanicStepState,self.MechanicStepPart,self.MechanicStepDistance=a,b,c,d
        return a,b,c,d
    end

    local oldStep=UIWController.Step
    function UIWController:Step()
        if self.Destroyed then return end
        local now=os.clock()
        if now-(self.LastFullStep or 0)<1/30 then
            if self.Enabled and self.Character:IsAlive() then
                self.Character.Humanoid:Move(self.LastCommandedMovement or Vector3.zero,false)
            end
            return
        end
        self.LastFullStep=now
        self.StepStamp=(self.StepStamp or 0)+1
        return oldStep(self)
    end

    local oldNew=UIWController.new
    function UIWController.new()
        local self=oldNew()
        self.Version="44.2"
        return self
    end
end
