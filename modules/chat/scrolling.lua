local function OnMouseScroll(self, dir)
	if(dir > 0) then
		if(IsShiftKeyDown()) then
			self:ScrollToTop()
		else
			self:ScrollUp()
		end
	else
		if(IsShiftKeyDown()) then
			self:ScrollToBottom()
		else
			self:ScrollDown()
		end
	end
end

-- Chat frames get a per-frame OnMouseWheel closure from ScrollUtil (only when the chatMouseScroll
-- CVar is on); FloatingChatFrame_OnMouseScroll is no longer their handler. Replace the frame
-- script instead of the Blizzard global, and only where Blizzard installed a wheel handler.
local done = {}
local function Apply(frame)
	if frame and not done[frame] and frame:GetScript("OnMouseWheel") then
		frame:SetScript("OnMouseWheel", OnMouseScroll)
		done[frame] = true
	end
end

for _, name in pairs(CHAT_FRAMES) do
	Apply(_G[name])
end
hooksecurefunc("FCF_OpenTemporaryWindow", function()
	for _, name in pairs(CHAT_FRAMES) do
		Apply(_G[name])
	end
end)
