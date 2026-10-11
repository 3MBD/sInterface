local _, ns = ...
local E = ns.E

-- textures sized for 45px buttons; stretched over the button instead
local overlayKeys = { "HighlightTexture", "PushedTexture", "CheckedTexture", "NewActionTexture", "SpellHighlightTexture", "Border", "Flash", "QuickKeybindHighlightTexture" }

-- Blizzard re-applies the button art whenever Edit Mode updates a bar (UpdateButtonArt),
-- so the border and empty-slot art are hidden through alpha after every update
local function ApplyButtonArt(button)
	-- Border around button
	local normalTexture = button:GetNormalTexture()
	if normalTexture then normalTexture:SetAlpha(0) end

	-- Used when the button is empty
	if button.SlotArt then button.SlotArt:SetAlpha(0) end
	if button.SlotBackground then button.SlotBackground:SetAlpha(0) end

	if InCombatLockdown() then return end
	for _, key in ipairs(overlayKeys) do
		local region = button[key]
		if region then
			region:ClearAllPoints()
			region:SetAllPoints(button)
		end
	end
end

local function StyleActionButton(button)
	if not button or button.__styled then return end

	local buttonName = button:GetName()

	local icon = button.icon or _G[buttonName.."Icon"]
	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	-- square icons, as before the rounded icon mask
	if button.IconMask then icon:RemoveMaskTexture(button.IconMask) end

	ApplyButtonArt(button)
	if button.UpdateButtonArt then
		hooksecurefunc(button, "UpdateButtonArt", ApplyButtonArt)
	end

	local shadowFrame = CreateFrame("Frame", buttonName.."sInterfaceSkin", button)
	shadowFrame:SetAllPoints(button)
	E:ShadowedBorder(shadowFrame)

	button.__styled = true
end

local function StyleAllActionButtons()
	for i = 1, NUM_ACTIONBAR_BUTTONS do
		StyleActionButton(_G["ActionButton"..i])
		StyleActionButton(_G["MultiBarBottomLeftButton"..i])
		StyleActionButton(_G["MultiBarBottomRightButton"..i])
		StyleActionButton(_G["MultiBarRightButton"..i])
		StyleActionButton(_G["MultiBarLeftButton"..i])
	end
	for i = 1, 6 do
		StyleActionButton(_G["OverrideActionBarButton"..i])
	end

	for i=1, NUM_PET_ACTION_SLOTS do
		StyleActionButton(_G["PetActionButton"..i])
	end

	-- NUM_STANCE_SLOTS no longer exists
	for i=1, StanceBar.numButtons do
		StyleActionButton(_G["StanceButton"..i])
	end

	for i=1, NUM_POSSESS_SLOTS do
		StyleActionButton(_G["PossessButton"..i])
	end
end

-- restyling repositions regions of protected buttons; wait if the UI loads during combat
if InCombatLockdown() then
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		StyleAllActionButtons()
	end)
else
	StyleAllActionButtons()
end