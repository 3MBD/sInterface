local _, ns = ...
local E = ns.E

if not E:C('minimap', 'enabled') then return end

local hider = CreateFrame("Frame")
hider:Hide()

local SQUARE_MASK = 'Interface\\ChatFrame\\ChatFrameBackground'

-- Position
-- the cluster that used to hold the minimap would otherwise keep catching clicks where it was
MinimapCluster:EnableMouse(false)
Minimap:ClearAllPoints()
Minimap:SetPoint(unpack(E:C('minimap', 'position')))
Minimap:SetSize(E:C('minimap', 'width'), E:C('minimap', 'height'))

-- Square Shape
Minimap:SetMaskTexture(SQUARE_MASK)
-- WoW: Forever re-applies its round mask whenever the rotateMinimap setting changes
local applyingMask = false
hooksecurefunc(Minimap, "SetMaskTexture", function(self, texture)
	if applyingMask or texture == SQUARE_MASK then return end
	applyingMask = true
	self:SetMaskTexture(SQUARE_MASK)
	applyingMask = false
end)

-- Border
MinimapCompassTexture:SetAlpha(0)
MinimapCompassTextureUnderlay:SetAlpha(0)
MinimapCluster.BorderTop:Hide()
-- WoW: Forever's day/night ring is drawn around the default round minimap
if MinimapCluster.DielFrame then MinimapCluster.DielFrame:Hide() end

-- Zoom
local zoomIn = Minimap.ZoomIn
local zoomOut = Minimap.ZoomOut
Minimap:EnableMouseWheel(true)
Minimap:SetScript("OnMouseWheel", function(self, direction)
	if direction > 0 then
		zoomIn:Click()
	elseif direction < 0 then
		zoomOut:Click()
	end
end)
zoomIn:Hide()
zoomOut:Hide()
-- the buttons are shown again whenever the cursor enters the minimap
zoomIn:HookScript("OnShow", zoomIn.Hide)
zoomOut:HookScript("OnShow", zoomOut.Hide)

-- Voice
-- MiniMapVoiceChatFrame:Hide()

-- Compass
-- the north marker is part of MinimapCompassTexture, hidden with the border

-- Zone
MinimapCluster.ZoneTextButton:Hide()
if (E:C('minimap', 'zoneText')) then
	MinimapZoneText:SetFontObject("GameFontNormalOutline")
	MinimapZoneText:SetPoint("LEFT", Minimap, "LEFT", 0, 0)
	MinimapZoneText:SetPoint("RIGHT", Minimap, "RIGHT", 0, 0)
	MinimapZoneText:SetPoint("BOTTOM", Minimap, "TOP", 0, -5)
	MinimapZoneText:SetParent(Minimap)
end

-- Clock
-- Blizzard loads the clock on demand at login, so hide it once it exists
if C_AddOns.IsAddOnLoaded("Blizzard_TimeManager") then
	TimeManagerClockButton:Hide()
else
	local clock = CreateFrame("Frame")
	clock:RegisterEvent("ADDON_LOADED")
	clock:SetScript("OnEvent", function(self, event, addonName)
		if addonName == "Blizzard_TimeManager" then
			TimeManagerClockButton:Hide()
			self:UnregisterAllEvents()
		end
	end)
end

-- Calendar
GameTimeFrame:Hide()

-- Garrison
ExpansionLandingPageMinimapButton:Hide()
ExpansionLandingPageMinimapButton:UnregisterAllEvents();

-- Tracking
local tracking = MinimapCluster.Tracking
tracking.Background:SetAlpha(0)
tracking.Button:SetAlpha(0)
tracking:ClearAllPoints()
tracking:SetPoint("TOPRIGHT", Minimap, 0, 0)
tracking:SetScale(.9)

-- Mail
local indicators = MinimapCluster.IndicatorFrame
local mail = indicators.MailFrame
-- the indicator row lays its icons out again whenever mail arrives; move the mail icon back
-- afterwards (flagging it ignoreInLayout would taint Blizzard's layout code)
local function anchorMail()
	mail:ClearAllPoints()
	mail:SetPoint("TOPLEFT", Minimap, 0, 0)
end
anchorMail()
hooksecurefunc(indicators, "Layout", anchorMail)
mail:SetFrameStrata("LOW")
MiniMapMailIcon:SetTexture("Interface\\Minimap\\ObjectIcons.blp")
MiniMapMailIcon:SetTexCoord(0.875, 1, 0.25, 0.375)

-- Queues
-- an Edit Mode system; Blizzard re-anchors it to the minimap whenever the layout changes
local function anchorQueueStatusButton()
	E:ClearAllPoints(QueueStatusButton)
	E:SetPoint(QueueStatusButton, "BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
end
anchorQueueStatusButton()
hooksecurefunc(QueueStatusButton, "UpdateDefaultAnchor", anchorQueueStatusButton)

-- Instance
local instanceDifficulty = MinimapCluster.InstanceDifficulty
instanceDifficulty:ClearAllPoints()
instanceDifficulty:Hide()
-- shown again by Blizzard on every instance change
instanceDifficulty:SetParent(hider)

-- World Map
-- the minimap no longer has a world map button

E:ShadowedBorder(Minimap)
