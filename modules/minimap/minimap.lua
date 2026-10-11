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

-- Zoom
local zoomIn = Minimap.ZoomIn
local zoomOut = Minimap.ZoomOut
Minimap:EnableMouseWheel(true)
-- the minimap's own OnMouseWheel already zooms through the (hidden) zoom buttons
if not Minimap.OnMouseWheel then
	Minimap:SetScript("OnMouseWheel", function(self, direction)
		if direction > 0 then
			zoomIn:Click()
		elseif direction < 0 then
			zoomOut:Click()
		end
	end)
end
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
	-- drop its anchor to the hidden zone button
	MinimapZoneText:ClearAllPoints()
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
-- the tracking icon is the button's own texture now, so only the round background is faded
tracking.Background:SetAlpha(0)
tracking:SetParent(Minimap)
tracking:ClearAllPoints()
tracking:SetPoint("TOPRIGHT", Minimap, 0, 0)
tracking:SetScale(.9)

-- Mail
-- the mail icon is laid out by the indicator row it sits in, so the whole row is moved. Blizzard
-- re-anchors the row when tracking is shown or hidden and when the header is flipped.
local indicators = MinimapCluster.IndicatorFrame
indicators:SetParent(Minimap)
local function anchorIndicators()
	indicators:ClearAllPoints()
	indicators:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 0, 0)
end
anchorIndicators()
hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", anchorIndicators)
hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", anchorIndicators)
indicators.MailFrame:SetFrameStrata("LOW")
if MiniMapMailIcon:SetTexture("Interface\\Minimap\\ObjectIcons.blp") then
	MiniMapMailIcon:SetTexCoord(0.875, 1, 0.25, 0.375)
else
	-- keep Blizzard's envelope if this client does not have the old icon sheet
	MiniMapMailIcon:SetAtlas("ui-hud-minimap-mail-up", true)
end

-- Queues
-- an Edit Mode system. Edit Mode re-anchors it in several places (layout changes, its default
-- anchor, minimap scale changes), all of them through its SetPoint, so it is moved back after that.
QueueStatusButton:SetParent(Minimap)
local anchoringQueueStatusButton = false
local function anchorQueueStatusButton()
	if anchoringQueueStatusButton then return end
	anchoringQueueStatusButton = true
	E:ClearAllPoints(QueueStatusButton)
	E:SetPoint(QueueStatusButton, "BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", 0, 0)
	anchoringQueueStatusButton = false
end
anchorQueueStatusButton()
hooksecurefunc(QueueStatusButton, "SetPoint", anchorQueueStatusButton)

-- Instance
local instanceDifficulty = MinimapCluster.InstanceDifficulty
instanceDifficulty:ClearAllPoints()
instanceDifficulty:Hide()
-- shown again by Blizzard on every instance change
instanceDifficulty:SetParent(hider)

-- World Map
-- the minimap no longer has a world map button

-- Addon compartment
-- anchored to the calendar button, which is hidden above
if AddonCompartmentFrame then
	AddonCompartmentFrame:ClearAllPoints()
	AddonCompartmentFrame:SetPoint("TOPRIGHT", tracking, "BOTTOMRIGHT", 0, -2)
end

-- Day/night indicator (WoW: Forever)
-- it would otherwise float where the round minimap used to be. Blizzard moves it again whenever
-- the minimap cluster's Edit Mode scale is applied.
local dielFrame = MinimapCluster.DielFrame
if dielFrame then
	local function anchorDielFrame()
		dielFrame:ClearAllPoints()
		dielFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 0, 0)
	end
	anchorDielFrame()
	hooksecurefunc(MinimapCluster, "SetEditModeScale", anchorDielFrame)
end

E:ShadowedBorder(Minimap)
