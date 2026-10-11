local _, ns = ...
local E = ns.E

if not E:C('nameplates', 'enabled') then return end;

-- Nameplates are built by Blizzard_NamePlates (NamePlateUnitFrameMixin), which lays them out
-- again whenever an option, style or CVar changes. The skin is therefore applied from
-- post-hooks on those layout functions instead of the old DefaultCompactNamePlate* setup
-- functions, and it never writes to Blizzard's tables.

local issecretvalue = issecretvalue or function() return false end

local colours = {
	secure = {  0.2, 0.8, 0.1 },
	insecure = { 1, 1, 0.3},
	na = { 1, 0, 0 },
	reaction = {}
}

local multiplier = 0.4

for eclass, color in next, FACTION_BAR_COLORS do
	colours.reaction[eclass] = {color.r, color.g, color.b}
end

local texture = E:C('general', 'texture')
local styled = setmetatable({}, { __mode = "k" })

-- compact unit frame functions also run for party and raid frames
local function IsNamePlate(frame)
	return not frame:IsForbidden() and frame.HealthBarsContainer ~= nil
end

-- background = bar colour * multiplier; secret colours (e.g. secret class colours) cannot be
-- multiplied, so they are darkened through alpha instead
local function TintBackground(healthBar, r, g, b)
	local background = healthBar.bgTexture
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then
		background:SetVertexColor(r, g, b, multiplier)
	else
		background:SetVertexColor(r*multiplier, g*multiplier, b*multiplier, 1)
	end
end

-- reaction colours, or threat colours for tanks; Blizzard keeps colouring players
local function UpdateHealthColor(frame)
	if not IsNamePlate(frame) or not frame.unit then return end

	if not UnitIsPlayer(frame.unit) then
		local status = UnitThreatSituation("player", frame.unit)
		if issecretvalue(status) then status = nil end

		local r, g, b
		if (not (E:C('nameplates', 'tankMode') and E:PlayerIsTank())) or (status == nil) then
			local reaction = UnitReaction(frame.unit, "player")
			reaction = not issecretvalue(reaction) and colours.reaction[reaction]
			if reaction then
				r, g, b = unpack(reaction)
			end
		elseif status == 3 then
			r, g, b = unpack(colours.secure)
		elseif status == 2 then
			r, g, b = unpack(colours.insecure)
		else
			r, g, b = unpack(colours.na)
		end

		if r then
			frame.healthBar:SetStatusBarColor(r, g, b)
		end
	end

	TintBackground(frame.healthBar, frame.healthBar:GetStatusBarColor())
end

-- threat updates run the aggro flash first and Blizzard's health colour afterwards, so both
-- are hooked to keep these colours on top
hooksecurefunc("CompactUnitFrame_UpdateAggroFlash", UpdateHealthColor)
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", UpdateHealthColor)

hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
	if not IsNamePlate(frame) or not frame.unit then return end
	if UnitIsPlayer(frame.unit) then
		frame.name:SetText(UnitName(frame.unit))
	end
	frame.name:SetTextColor(1, 1, 1, 1)
end)

-- once per pooled nameplate
local function Style(namePlate)
	local healthBar = namePlate.healthBar
	local castBar = namePlate.CastBarsContainer.castBar

	-- the target/selection borders replaced the old nameplate border, which sInterface hid
	healthBar.selectedBorder:SetAlpha(0)
	healthBar.deselectedOverlay:SetAlpha(0)
	E:ShadowedBorder(healthBar)

	castBar.Border:SetAlpha(0)
	castBar.Background:SetAlpha(0.3)
	castBar.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
	E:ShadowedBorder(castBar)
	E:ShadowedBorder(castBar.Icon)

	namePlate.name:SetParent(healthBar)
	namePlate.selectionHighlight:SetAlpha(0)

	styled[namePlate] = true
end

-- every layout pass resets textures, fonts and anchors
local function Layout(namePlate)
	if namePlate:IsForbidden() then return end
	if not styled[namePlate] then Style(namePlate) end

	local healthBar = namePlate.healthBar
	local castBar = namePlate.CastBarsContainer.castBar
	local font, size, flags = GameFontNormalOutline:GetFont()

	healthBar:SetStatusBarTexture(texture)
	local background = healthBar.bgTexture
	background:SetTexture(texture)
	background:SetTextureSliceMargins(0, 0, 0, 0)
	background:SetTexCoord(0, 1, 0, 1)
	background:SetDrawLayer("BACKGROUND")
	background:ClearAllPoints()
	background:SetAllPoints(healthBar)

	-- a thin cast bar just below the health bar
	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", namePlate.HealthBarsContainer, "BOTTOMLEFT", 0, -3)
	castBar:SetPoint("TOPRIGHT", namePlate.HealthBarsContainer, "BOTTOMRIGHT", 0, -3)
	castBar:SetHeight(3)
	castBar.Text:SetFont(font, size*UIParent:GetScale(), flags)

	namePlate.name:SetFont(font, size*UIParent:GetScale(), flags)
	local layer, sublayer = namePlate.selectionHighlight:GetDrawLayer()
	namePlate.name:SetDrawLayer(layer, sublayer+1)
	namePlate.name:ClearAllPoints()
	PixelUtil.SetPoint(namePlate.name, "BOTTOM", healthBar, "TOP", 0, -3)

	local auras = namePlate.AurasFrame.DebuffListFrame
	auras:ClearAllPoints()
	auras:SetPoint("BOTTOM", healthBar, "TOP", 0, 12)
	auras:SetScale(0.85)

	UpdateHealthColor(namePlate)
end

hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", Layout)

-- cast bars switch art for every cast: use sInterface's texture with the classic cast colours,
-- unless the cast type is secret for this unit, in which case Blizzard's art stays
hooksecurefunc(NamePlateCastingBarMixin, "UpdateBarFillTexture", function(castBar, isFull)
	if castBar:IsForbidden() or issecretvalue(castBar.barType) then return end

	local info = castBar:GetTypeInfo(castBar.barType)
	local color = info and (isFull and info.classicFullColor or info.classicFillColor)
	if not color then return end

	castBar:SetStatusBarTexture(texture)
	castBar:SetStatusBarColor(color:GetRGB())
end)

hooksecurefunc(NamePlateAuraItemMixin, "OnLoad", function(aura)
	if aura:IsForbidden() then return end
	local font, size, flags = GameFontNormalOutline:GetFont()
	aura.CountFrame.Count:SetFont(font, size, flags)
	aura.CountFrame:SetPoint("BOTTOMRIGHT", 2, -2)
end)
