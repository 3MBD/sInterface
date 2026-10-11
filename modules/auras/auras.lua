local addon, ns = ...
local E = ns.E

if not E:C('auras', 'enabled') then return end;

local size = E:C('auras', 'size')
local spacing = E:C('auras', 'spacing')
local max_per_row = E:C('auras', 'max_per_row')

local sInterfaceBuffFrame = CreateFrame('Frame', addon..'BuffFrame', UIParent)
local sInterfaceBuffFrameWidth = (size * E:C('auras', 'max_per_row')) + ((-E:C('auras', 'spacing') - 1) * E:C('auras', 'max_per_row'))
local sInterfaceBuffFrameHeight  = size
sInterfaceBuffFrame:SetSize(sInterfaceBuffFrameWidth, sInterfaceBuffFrameHeight)

local function updateBuffFrameAnchor()
	sInterfaceBuffFrame:ClearAllPoints()
	if (Minimap:IsShown()) then
		sInterfaceBuffFrame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", E:C('auras', 'spacing'), 0);
	else
		-- sInterfaceFrame was never created; the screen (UIParent) was the effective anchor
		sInterfaceBuffFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -E:C('general', 'edgeSpacing'), -E:C('general', 'edgeSpacing'));
	end
end
updateBuffFrameAnchor()

Minimap:HookScript("OnHide", updateBuffFrameAnchor)
Minimap:HookScript("OnShow", updateBuffFrameAnchor)

-- Modern BuffFrame (Blizzard_BuffFrame / AuraContainer): unnamed AuraButtonTemplate buttons in
-- BuffFrame.auraFrames / DebuffFrame.auraFrames, laid out by AuraContainerMixin:UpdateGridLayout,
-- which resets scale, size and Icon/Duration anchors on every layout pass.
local function style(aura)
	aura:SetScale(1)
	aura:SetSize(size, size)

	aura.Icon:ClearAllPoints()
	aura.Icon:SetAllPoints(aura)

	aura.Duration:ClearAllPoints()
	aura.Duration:SetPoint("TOP", aura, "BOTTOM", 0, 6)
	aura.Duration:SetFontObject("GameFontNormalOutline") -- Edit Mode resets it to DEFAULT_AURA_DURATION_FONT

	if aura.styled then return end

	if aura ~= BuffFrame.ConsolidatedBuffs then
		aura.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	end

	if aura.DebuffBorder then aura.DebuffBorder:SetAlpha(0) end
	if aura.TempEnchantBorder then aura.TempEnchantBorder:SetAlpha(0) end

	aura.Duration:SetJustifyH("CENTER")

	E:ShadowedBorder(aura)

	aura.styled = true
end

local function anchorRows(list, relativeTo, relativePoint, x, y)
	local previousAura, aboveAura
	for i, aura in ipairs(list) do
		aura:ClearAllPoints()

		if i > 1 and mod(i, max_per_row) == 1 then
			aura:SetPoint("TOPRIGHT", aboveAura, "BOTTOMRIGHT", 0, spacing*2)
			aboveAura = aura
		elseif i == 1 then
			aura:SetPoint("TOPRIGHT", relativeTo, relativePoint, x, y)
			aboveAura = aura
		else
			-- TOPRIGHT/TOPLEFT == RIGHT/LEFT for equal-size buttons; keeps private-aura anchors top-aligned
			aura:SetPoint("TOPRIGHT", previousAura, "TOPLEFT", spacing, 0)
		end
		previousAura = aura
	end
end

local buffs, debuffs, privateAnchors = {}, {}, {}

local function updateAnchors()
	wipe(buffs)
	wipe(debuffs)
	wipe(privateAnchors)

	-- temp enchants come first in BuffFrame.auraInfo, so auraFrames order == old TempEnchant..BuffButton order
	local consolidated = BuffFrame.ConsolidatedBuffs
	if consolidated and consolidated:IsShown() and consolidated:ShouldShow() then
		buffs[#buffs + 1] = consolidated
	end
	for _, aura in ipairs(BuffFrame.auraFrames) do
		if not aura.isAuraAnchor and aura:IsShown() then
			buffs[#buffs + 1] = aura
		end
	end
	for _, aura in ipairs(buffs) do
		style(aura)
	end
	anchorRows(buffs, sInterfaceBuffFrame, "TOPRIGHT", 0, 0)

	-- only visible when the collapseExpandBuffs CVar is on; keep it beside sInterface's buffs
	local collapse = BuffFrame.CollapseAndExpandButton
	if collapse and collapse:IsShown() then
		collapse:ClearAllPoints()
		collapse:SetPoint("TOPRIGHT", sInterfaceBuffFrame, "TOPLEFT", spacing, 0)
	end

	for _, aura in ipairs(DebuffFrame.auraFrames) do
		if aura.isAuraAnchor then
			-- private aura anchors: Icon/Duration are plain Frames; move only, never restyle
			privateAnchors[#privateAnchors + 1] = aura
		elseif aura:IsShown() then
			style(aura)
			debuffs[#debuffs + 1] = aura
		end
	end
	for _, anchor in ipairs(privateAnchors) do
		debuffs[#debuffs + 1] = anchor
	end

	local numBuffs = #buffs
	if numBuffs == 0 then
		anchorRows(debuffs, sInterfaceBuffFrame, "TOPRIGHT", 0, 0)
	else
		-- first buff of the last buff row (original used BUFF_ACTUAL_DISPLAY arithmetic)
		local anchor = buffs[(floor((numBuffs - 1) / max_per_row) * max_per_row) + 1]
		anchorRows(debuffs, anchor, "BOTTOMRIGHT", 0, spacing*6)
	end
end

if not (BuffFrame and BuffFrame.auraFrames and BuffFrame.UpdateAuraButtons and BuffFrame.UpdateGridLayout
	and DebuffFrame and DebuffFrame.auraFrames and DebuffFrame.UpdateAuraButtons and DebuffFrame.UpdateGridLayout) then
	print("|cff00ffffsInterface|r: the default buff frame has an unexpected layout; buffs keep their default position")
	return
end

hooksecurefunc(BuffFrame, "UpdateAuraButtons", updateAnchors)
hooksecurefunc(BuffFrame, "UpdateGridLayout", updateAnchors)
hooksecurefunc(DebuffFrame, "UpdateAuraButtons", updateAnchors)
hooksecurefunc(DebuffFrame, "UpdateGridLayout", updateAnchors)
-- no initial call: BuffFrame/DebuffFrame:Update() runs on PLAYER_ENTERING_WORLD
