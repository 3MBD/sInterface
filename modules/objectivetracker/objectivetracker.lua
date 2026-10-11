local _, ns = ...
local E = ns.E

if not E:C('objectivetracker', 'enabled') then return end

local ObjectiveTrackerFrame = ObjectiveTrackerFrame

local gettingSet = false
local function AdjustSetPoint(self)
	if gettingSet then return end
	gettingSet = true
	local point, relativeTo, relativePoint, x, y = unpack(E:C('objectivetracker', 'pos'))
	if type(relativeTo) == "string" then
		-- the progress bars do not exist when that module is disabled
		relativeTo = _G[relativeTo] or Minimap
	end
	-- the frame manager anchors the tracker with more than one point; the tracker is an Edit Mode
	-- frame, so its original anchoring methods are used
	E:ClearAllPoints(self)
	E:SetPoint(self, point, relativeTo, relativePoint, x, y)
	gettingSet = false
end

hooksecurefunc(ObjectiveTrackerFrame, "SetPoint", AdjustSetPoint)
