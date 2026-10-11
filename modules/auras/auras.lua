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
	if (Minimap:IsShown()) then
		sInterfaceBuffFrame:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", E:C('auras', 'spacing'), 0);
	else
		sInterfaceBuffFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -E:C('general', 'edgeSpacing'), -E:C('general', 'edgeSpacing'));
	end
end
updateBuffFrameAnchor()

Minimap:HookScript("OnHide", updateBuffFrameAnchor)
Minimap:HookScript("OnShow", updateBuffFrameAnchor)

-- Since 10.0 player auras are unnamed buttons (BuffFrame.auraFrames, DebuffFrame.auraFrames)
-- that Blizzard sizes and lays out on a grid. Blizzard's frames and Edit Mode are left alone;
-- the buttons are restyled and re-anchored to sInterfaceBuffFrame after every Blizzard update.
local function style(aura)
	if not aura then return end

	local icon = aura.Icon
	local duration = aura.Duration

	aura:SetScale(1)
	aura:SetSize(size, size)

	icon:ClearAllPoints()
	icon:SetAllPoints(aura)

	duration:ClearAllPoints()
	duration:SetPoint("TOP", aura, "BOTTOM", 0, 6)

	if aura.styled then return end

	icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

	if aura.DebuffBorder then aura.DebuffBorder:SetAlpha(0) end
	if aura.TempEnchantBorder then aura.TempEnchantBorder:SetAlpha(0) end

	duration:SetParent(aura)
	duration:SetJustifyH("CENTER")
	duration:SetFontObject("GameFontNormalOutline")

	E:ShadowedBorder(aura)

	aura.styled = true
end

local function anchorRows(auras, firstPoint, firstRelative, firstRelativePoint, firstX, firstY)
	local previousAura, aboveAura
	for i, aura in ipairs(auras) do
		aura:ClearAllPoints()

		if i > 1 and mod(i, max_per_row) == 1 then
			aura:SetPoint("TOPRIGHT", aboveAura, "BOTTOMRIGHT", 0, spacing*2)
			aboveAura = aura
		elseif i == 1 then
			aura:SetPoint(firstPoint, firstRelative, firstRelativePoint, firstX, firstY)
			aboveAura = aura
		else
			aura:SetPoint("RIGHT", previousAura, "LEFT", spacing, 0)
		end
		previousAura = aura
	end
end

local buffs = {}

local function updateBuffAnchors()
	wipe(buffs)

	if BuffFrame.ConsolidatedBuffs and BuffFrame.ConsolidatedBuffs:IsShown() then
		table.insert(buffs, BuffFrame.ConsolidatedBuffs)
	end
	for _, aura in ipairs(BuffFrame.auraFrames) do
		if aura:IsShown() and not aura.isAuraAnchor then
			table.insert(buffs, aura)
		end
	end

	for _, buff in ipairs(buffs) do
		style(buff)
	end
	anchorRows(buffs, "TOPRIGHT", sInterfaceBuffFrame, "TOPRIGHT", 0, 0)

	local collapse = BuffFrame.CollapseAndExpandButton
	if collapse then
		collapse:ClearAllPoints()
		collapse:SetPoint("TOPRIGHT", sInterfaceBuffFrame, "TOPLEFT", spacing, 0)
	end
end

local debuffs = {}

local function updateDebuffAnchors()
	wipe(debuffs)

	-- private aura anchors follow the visible debuffs, as in the default layout
	local anchors = {}
	for _, aura in ipairs(DebuffFrame.auraFrames) do
		if aura.isAuraAnchor then
			table.insert(anchors, aura)
		elseif aura:IsShown() then
			style(aura)
			table.insert(debuffs, aura)
		end
	end
	for _, anchor in ipairs(anchors) do
		table.insert(debuffs, anchor)
	end

	local numBuffs = #buffs
	if numBuffs == 0 then
		anchorRows(debuffs, "TOPRIGHT", sInterfaceBuffFrame, "TOPRIGHT", 0, 0)
	else
		-- below the first buff of the last row
		local anchor = buffs[(math.floor((numBuffs - 1) / max_per_row) * max_per_row) + 1]
		anchorRows(debuffs, "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, spacing*6)
	end
end

local function updateAllAnchors()
	updateBuffAnchors()
	updateDebuffAnchors()
end

if not (BuffFrame and BuffFrame.auraFrames and DebuffFrame and DebuffFrame.auraFrames) then
	print("|cff00ffffsInterface|r: the default buff frame has an unexpected layout; buffs keep their default position")
	return
end

hooksecurefunc(BuffFrame, "UpdateAuraButtons", updateAllAnchors)
hooksecurefunc(BuffFrame, "UpdateGridLayout", updateAllAnchors)
hooksecurefunc(BuffFrame, "UpdateAuraContainerAnchor", updateBuffAnchors)
hooksecurefunc(DebuffFrame, "UpdateAuraButtons", updateDebuffAnchors)
hooksecurefunc(DebuffFrame, "UpdateGridLayout", updateDebuffAnchors)
updateAllAnchors()
