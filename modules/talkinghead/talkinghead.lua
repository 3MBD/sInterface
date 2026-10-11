local addon, ns = ...
local E = ns.E

if not E:C('talkinghead', 'enabled') then return end

local TalkingHeadAnchor = CreateFrame("Frame", addon.."TalkingHeadAnchor", UIParent)
TalkingHeadAnchor:SetScale(E:C('talkinghead', 'scale'))
TalkingHeadAnchor:SetPoint(unpack(E:C('talkinghead', 'position')))
TalkingHeadAnchor:SetSize(1,1)

local function anchorTalkingHead()
	-- the same flag Edit Mode sets when the frame is moved away from its default position
	TalkingHeadFrame.ignoreFramePositionManager = true
	TalkingHeadFrame:SetParent(TalkingHeadAnchor)
	TalkingHeadFrame:ClearAllPoints()
	TalkingHeadFrame:SetPoint("CENTER")
end

-- part of the default UI since 10.0 (Blizzard_TalkingHeadUI is gone); Edit Mode re-anchors it
-- whenever layouts are applied
anchorTalkingHead()
hooksecurefunc(TalkingHeadFrame, "ApplySystemAnchor", anchorTalkingHead)
