local _, ns = ...
local E = ns.E

if not E:C('chat', 'enabled') then return end

-- NUM_CHAT_WINDOWS only exists with the loadDeprecationFallbacks CVar
local NUM_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows

local function KeepHidden(button)
	if not button then return end
	button:HookScript("OnShow", button.Hide)
	button:Hide()
end

KeepHidden(ChatFrameMenuButton)
KeepHidden(ChatFrameToggleVoiceDeafenButton)
KeepHidden(ChatFrameToggleVoiceMuteButton)
KeepHidden(ChatFrameChannelButton)
KeepHidden(QuickJoinToastButton)

hooksecurefunc("FCFTab_UpdateColors", function(self, selected)
	local fs = self:GetFontString()
	if not fs then return end
	local font, size = fs:GetFont()
	if font then
		fs:SetFont(font, size, "OUTLINE")
	end

	if selected then
		fs:SetTextColor(1, 0.75, 0, 1)
	else
		fs:SetTextColor(0.5, 0.5, 0.5, 1)
	end
end)

-- the tab art textures are parentKeys now (they used to be ChatFrameNTabLeft etc.)
local TAB_TEXTURE_KEYS = {
	"Left", "Middle", "Right",
	"ActiveLeft", "ActiveMiddle", "ActiveRight",
	"HighlightLeft", "HighlightMiddle", "HighlightRight",
}
local FRAME_TEXTURE_NAMES = { "TopTexture", "RightTexture", "BottomTexture", "LeftTexture", "Background" }

local function ClearTexture(texture)
	if texture and texture.SetTexture then
		texture:SetTexture(nil)
	end
end

local styled = {}

local function style(self)
	if not self or styled[self] then return end

	local name = self:GetName()

	self:SetClampRectInsets(0, 0, 0, 0)
	-- SetMinResize/SetMaxResize were replaced by SetResizeBounds
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
	-- the scroll bar (and with it the scroll-to-bottom button) moved out of the button frame
	if self.ScrollBar then
		self.ScrollBar:Hide()
		self.ScrollBar:HookScript("OnShow", self.ScrollBar.Hide)
	end

	_G[name.."EditBoxLeft"]:Hide()
	_G[name.."EditBoxMid"]:Hide()
	_G[name.."EditBoxRight"]:Hide()
	local eb = _G[name.."EditBox"]
	eb:SetAltArrowKeyMode(false)
	eb:ClearAllPoints()
	eb:SetPoint("BOTTOM", tab, "TOP", 0, -10)
	eb:SetPoint("LEFT", self, -5, 0)
	eb:SetPoint("RIGHT", self, 10, 0)

	for _, key in ipairs(TAB_TEXTURE_KEYS) do ClearTexture(tab[key]) end
	for _, suffix in ipairs(FRAME_TEXTURE_NAMES) do ClearTexture(_G[name..suffix]) end

	styled[self] = true
end

for i = 1, NUM_WINDOWS do
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

-- ChatFrame1 is an Edit Mode system: its position and size come from Edit Mode (and it stays
-- locked), so sInterface's placement is re-applied afterwards with the original widget methods.
-- Edit Mode's SetPoint/ClearAllPoints overrides would taint Edit Mode.
local function PositionChatFrame1()
	local f = ChatFrame1
	E:ClearAllPoints(f)
	E:SetPoint(f, unpack(E:C('chat', 'position')))
	f:SetUserPlaced(true)
	f:SetHeight(E:C('chat', 'height'))
	f:SetWidth(E:C('chat', 'width'))
	-- Edit Mode re-derives clamp insets from its selection frame on every layout apply
	f:SetClampRectInsets(0, 0, 0, 0)
end

local deferFrame
local function RequestPosition()
	if InCombatLockdown() then
		-- a protected frame snapped to ChatFrame1 in Edit Mode would make moving it a blocked action
		if not deferFrame then
			deferFrame = CreateFrame("Frame")
			deferFrame:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				PositionChatFrame1()
			end)
		end
		deferFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	PositionChatFrame1()
end

hooksecurefunc("FloatingChatFrame_Update", function(id)
	RequestPosition()

	-- UPDATE_CHAT_WINDOWS re-applies the client's saved chat font size just before this call
	local frame = id and _G["ChatFrame"..id]
	if frame and styled[frame] then
		local font, _, flags = frame:GetFont()
		if font then
			frame:SetFont(font, E:C('chat', 'fontSize'), flags)
		end
	end
end)

-- Edit Mode layout apply re-anchors/resizes ChatFrame1 from the active layout
hooksecurefunc(ChatFrame1, "UpdateSystem", RequestPosition)

-- class coloured names in every chat type
local function ColourByClass()
	-- "0" = always class-colour names (ChatFrameUtil.ShouldColorChatByClass). Writing
	-- colorNameByClass into Blizzard's ChatTypeInfo would taint the secure chat handler, which
	-- reads it for every message.
	if GetCVar("chatClassColorOverride") ~= "0" then
		SetCVar("chatClassColorOverride", "0")
	end
end

local ChatLogin = CreateFrame('Frame', nil)
ChatLogin:RegisterEvent('PLAYER_LOGIN')
ChatLogin:SetScript('OnEvent', ColourByClass)
