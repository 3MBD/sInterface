local _, ns = ...
local E = ns.E

if not E:C('objectivetracker', 'enabled') then return end

local ObjectiveTrackerFrame = ObjectiveTrackerFrame

local gettingSet = false
local function AdjustSetPoint(self,...)
	if gettingSet then return end
	gettingSet = true
	-- the frame manager anchors the tracker with more than one point; the tracker is an Edit Mode
	-- frame, so its original anchoring methods are used
	E:ClearAllPoints(self)
	E:SetPoint(self, unpack(E:C('objectivetracker', 'pos')))
	gettingSet = false
end

hooksecurefunc(ObjectiveTrackerFrame, "SetPoint", AdjustSetPoint)
