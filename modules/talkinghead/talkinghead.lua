local addon, ns = ...
local E = ns.E

if not E:C('talkinghead', 'enabled') then return end

local TalkingHeadAnchor = CreateFrame("Frame", addon.."TalkingHeadAnchor", UIParent)
TalkingHeadAnchor:SetScale(E:C('talkinghead', 'scale'))
TalkingHeadAnchor:SetPoint(unpack(E:C('talkinghead', 'position')))
TalkingHeadAnchor:SetSize(1,1)

-- TalkingHeadFrame is part of the default UI now (Blizzard_TalkingHeadUI is gone). It is an Edit
-- Mode frame that the bottom frame manager takes back every time it is shown, and Edit Mode
-- re-anchors it whenever a layout is applied, so it is moved back after both. Its original
-- anchoring methods are used and no flags are written to it: either would taint Edit Mode.
local function anchorTalkingHead()
	TalkingHeadFrame:SetParent(TalkingHeadAnchor)
	E:ClearAllPoints(TalkingHeadFrame)
	E:SetPoint(TalkingHeadFrame, "CENTER")
end

anchorTalkingHead()
hooksecurefunc(TalkingHeadFrame, "ApplySystemAnchor", anchorTalkingHead)
hooksecurefunc(BottomManagedFrameContainer, "UpdateFrame", function(_, frame)
	if frame == TalkingHeadFrame then anchorTalkingHead() end
end)
