local _, ns = ...
local E = ns.E

if not E:C('mirrortimer', 'enabled') then return end;

-- colours the default UI used before timer bars switched to atlases
local timerColors = {
	EXHAUSTION = { 1.00, 0.90, 0.00 },
	BREATH = { 0.00, 0.50, 1.00 },
	DEATH = { 1.00, 0.70, 0.00 },
	FEIGNDEATH = { 1.00, 0.70, 0.00 },
}

local function style(mir, mirSB, mirT)
	-- background and border textures; the label is a FontString and stays
	for _, region in ipairs({mir:GetRegions()}) do
		if region:IsObjectType("Texture") then
			region:SetAlpha(0)
		end
	end

	E:ShadowedBorder(mirSB)
	mirSB:SetStatusBarTexture(E:C('general', 'texture'))
	mirSB:SetSize(mir:GetWidth(), mir:GetHeight()/3)

	mirT:ClearAllPoints()
	mirT:SetPoint("CENTER", mir, "TOP", 0, 0)
	mirT:SetFontObject("GameFontHighlightOutline")
end

local function setTexture(mir, timer)
	mir.StatusBar:SetStatusBarTexture(E:C('general', 'texture'))
	local color = timerColors[timer]
	if color then
		mir.StatusBar:SetStatusBarColor(color[1], color[2], color[3])
	end
end

-- MirrorTimer1-3 became the pooled MirrorTimerContainer.mirrorTimers in 10.0
for _, mir in ipairs(MirrorTimerContainer.mirrorTimers) do
	style(mir, mir.StatusBar, mir.Text)
	-- every new timer resets the bar to the default atlas
	hooksecurefunc(mir, "Setup", setTexture)
end
