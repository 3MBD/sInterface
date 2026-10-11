-- Chat frames scroll through ScrollUtil's OnMouseWheel handler; FloatingChatFrame_OnMouseScroll
-- is no longer used for them. Shift+wheel jumps to the top or bottom on top of the default scrolling.
local function OnMouseWheel(self, dir)
	if not IsShiftKeyDown() then return end

	if(dir > 0) then
		self:ScrollToTop()
	else
		self:ScrollToBottom()
	end
end

local function hook(frame)
	if not frame or frame.__sInterfaceScroll then return end
	frame:HookScript("OnMouseWheel", OnMouseWheel)
	frame.__sInterfaceScroll = true
end

for i = 1, NUM_CHAT_WINDOWS do
	hook(_G["ChatFrame"..i])
end

hooksecurefunc("FCF_OpenTemporaryWindow", function()
	for _, chatFrameName in pairs(CHAT_FRAMES) do
		hook(_G[chatFrameName])
	end
end)
