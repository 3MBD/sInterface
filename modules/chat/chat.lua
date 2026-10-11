local _, ns = ...
local E = ns.E

if not E:C('chat', 'enabled') then return end

ChatFrameMenuButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
ChatFrameMenuButton:Hide()

ChatFrameToggleVoiceDeafenButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
ChatFrameToggleVoiceDeafenButton:Hide()

ChatFrameToggleVoiceMuteButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
ChatFrameToggleVoiceMuteButton:Hide()

ChatFrameChannelButton:HookScript("OnShow", ChatFrameMenuButton.Hide)
ChatFrameChannelButton:Hide()

QuickJoinToastButton:HookScript("OnShow", QuickJoinToastButton.Hide)
QuickJoinToastButton:Hide()

hooksecurefunc("FCFTab_UpdateColors", function(self, selected)
	local string = self:GetFontString()
	local font, size = string:GetFont()
	string:SetFont(font, size, "OUTLINE")

	if selected then
		string:SetTextColor(1, 0.75, 0, 1)
	else
		string:SetTextColor(0.5, 0.5, 0.5, 1)
	end
end)

local tabTextures = {
	"Left", "Middle", "Right",
	"ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}

local function style(self)
	if not self or self.styled then return end

	local name = self:GetName()

	self:SetClampRectInsets(0, 0, 0, 0)
	self:SetResizeBounds(100, 50, UIParent:GetWidth(), UIParent:GetHeight())
	local font, _, flags = ChatFontNormal:GetFont()
	self:SetFont(font, E:C('chat', 'fontSize'), flags)

	local tab = _G[name.."Tab"]
	tab:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
	end)
	tab:SetScript("OnLeave", function(self)
		self:SetAlpha(0.3)
		self:GetFontString():SetFontObject("GameFontNormalOutline")
	end)
	local tabFs = tab:GetFontString()
	tabFs:SetFontObject("GameFontNormalOutline")

	local bframe = _G[name.."ButtonFrame"]
	bframe:Hide()
	bframe:HookScript("OnShow", bframe.Hide)

	_G[name.."EditBoxLeft"]:Hide()
	_G[name.."EditBoxMid"]:Hide()
	_G[name.."EditBoxRight"]:Hide()
	local eb = _G[name.."EditBox"]
	eb:SetAltArrowKeyMode(false)
	eb:ClearAllPoints()
	eb:SetPoint("BOTTOM", tab, "TOP", 0, -10)
	eb:SetPoint("LEFT", self, -5, 0)
	eb:SetPoint("RIGHT", self, 10, 0)

	for _, key in ipairs(tabTextures) do
		tab[key]:SetTexture(nil)
	end
	_G[name.."TopTexture"]:SetTexture(nil)
	_G[name.."RightTexture"]:SetTexture(nil)
	_G[name.."BottomTexture"]:SetTexture(nil)
	_G[name.."LeftTexture"]:SetTexture(nil)
	_G[name.."Background"]:SetTexture(nil)

	self.styled = true
end

for i = 1, NUM_CHAT_WINDOWS do
	style(_G["ChatFrame"..i])
end

hooksecurefunc("FCF_OpenTemporaryWindow", function()
	for _, chatFrameName in pairs(CHAT_FRAMES) do
		local frame = _G[chatFrameName]
		if frame.isTemporary then
			style(frame)
		end
	end
end)

-- The general chat frame is an Edit Mode system: its position and size are owned by Edit Mode
-- (and it is meant to stay locked), so re-apply sInterface's placement after Edit Mode applies its own.
local function placeChatFrame1()
	ChatFrame1:ClearAllPoints()
	ChatFrame1:SetPoint(unpack(E:C('chat', 'position')))
	ChatFrame1:SetHeight(E:C('chat', 'height'))
	ChatFrame1:SetWidth(E:C('chat', 'width'))
end

hooksecurefunc("FloatingChatFrame_Update", placeChatFrame1)
hooksecurefunc(ChatFrame1, "UpdateSystem", placeChatFrame1)

-- class coloured names in every chat type. Blizzard reads this setting itself; writing
-- colorNameByClass into ChatTypeInfo would taint chat message formatting
local function ColourByClass()
	-- "0" shows class colours for every chat type (ChatFrameUtil.ShouldColorChatByClass)
	SetCVar("chatClassColorOverride", "0")
end

local ChatLogin = CreateFrame('Frame', nil)
ChatLogin:RegisterEvent('PLAYER_LOGIN')
ChatLogin:SetScript('OnEvent', ColourByClass)
