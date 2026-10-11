local _, ns = ...
local E = ns.E

if not E:C('nameplates', 'enabled') then return end;

-- Nameplates are built by Blizzard_NamePlates (NamePlateUnitFrameMixin), which lays them out
-- again whenever an option, style or CVar changes. The skin is therefore applied from
-- post-hooks on those layout functions instead of the old DefaultCompactNamePlate* setup
-- functions, and it never writes to Blizzard's tables.
if not (NamePlateUnitFrameMixin and NamePlateUnitFrameMixin.UpdateAnchors
	and NamePlateCastingBarMixin and NamePlateCastingBarMixin.UpdateBarFillTexture
	and NamePlateAuraItemMixin and NamePlateAuraItemMixin.OnLoad) then
	print("|cffff6060sInterface|r: nameplate styling disabled - Blizzard nameplate API not found on this client.")
	return
end

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

local styled = setmetatable({}, { __mode = "k" })   -- plates that already have their borders
local deferred = setmetatable({}, { __mode = "k" }) -- plates whose layout waits for combat to end

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

-- Blizzard colours the bar last in CompactUnitFrame_UpdateHealthColor (the aggro flash only
-- toggles a texture). Reaction colours, or threat colours for tanks; players keep Blizzard's.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
	if not IsNamePlate(frame) or not frame.unit then return end
	local healthBar = frame.healthBar

	if not UnitIsPlayer(frame.unit) then
		local status
		if E:C('nameplates', 'tankMode') and E:PlayerIsTank() then
			status = UnitThreatSituation("player", frame.unit)
			-- secret when the threat state is restricted: fall back to the reaction colour
			if issecretvalue(status) then status = nil end
		end

		local r, g, b
		if status == nil then
			local reaction = UnitReaction(frame.unit, "player")
			reaction = reaction and not issecretvalue(reaction) and colours.reaction[reaction]
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
			healthBar:SetStatusBarColor(r, g, b)
		end
	end

	TintBackground(healthBar, healthBar:GetStatusBarColor())
end)

hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
	if not IsNamePlate(frame) or not frame.unit then return end
	if UnitIsPlayer(frame.unit) then
		frame.name:SetText((UnitName(frame.unit)))
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

	-- the name stays a child of the plate: unlike the health bar it is also shown for plates
	-- that only show a name
	namePlate.selectionHighlight:SetAlpha(0)

	styled[namePlate] = true
end

-- Textures, fonts and draw layers. Blizzard resets them on every layout pass.
local function ApplyLook(namePlate)
	local healthBar = namePlate.healthBar
	local castBar = namePlate.CastBarsContainer.castBar
	local font, _, flags = GameFontNormalOutline:GetFont()

	healthBar.barTexture:SetTexture(texture)
	local background = healthBar.bgTexture
	background:SetTexture(texture)
	background:SetTextureSliceMargins(0, 0, 0, 0)
	background:SetTexCoord(0, 1, 0, 1)
	background:SetDrawLayer("BACKGROUND")

	-- sInterface's font face and outline, at the size Blizzard computes from the nameplate
	-- size settings
	local _, castSize = castBar.Text:GetFont()
	castBar.Text:SetFont(font, castSize, flags)
	local _, nameSize = namePlate.name:GetFont()
	namePlate.name:SetFont(font, nameSize, flags)
	local layer, sublayer = namePlate.selectionHighlight:GetDrawLayer()
	namePlate.name:SetDrawLayer(layer, sublayer+1)
end

-- Anchors and sizes. Moving regions of a protected frame is blocked in combat.
local function ApplyGeometry(namePlate)
	local healthBar = namePlate.healthBar
	local castBar = namePlate.CastBarsContainer.castBar

	local background = healthBar.bgTexture
	background:ClearAllPoints()
	background:SetAllPoints(healthBar)

	-- a thin cast bar just below the health bar
	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", namePlate.HealthBarsContainer, "BOTTOMLEFT", 0, -3)
	castBar:SetPoint("TOPRIGHT", namePlate.HealthBarsContainer, "BOTTOMRIGHT", 0, -3)
	castBar:SetHeight(3)

	namePlate.name:ClearAllPoints()
	PixelUtil.SetPoint(namePlate.name, "BOTTOM", healthBar, "TOP", 0, -3)

	local auras = namePlate.AurasFrame.DebuffListFrame
	auras:ClearAllPoints()
	auras:SetPoint("BOTTOM", healthBar, "TOP", 0, 12)
	auras:SetScale(0.85)
end

-- IsProtected can be secret; an unknown answer counts as protected
local function GeometryIsLocked(namePlate)
	if not InCombatLockdown() then return false end
	local protected = namePlate.HealthBarsContainer:IsProtected()
	return issecretvalue(protected) or protected
end

hooksecurefunc(NamePlateUnitFrameMixin, "UpdateAnchors", function(namePlate)
	if namePlate:IsForbidden() then return end
	if not styled[namePlate] then Style(namePlate) end

	ApplyLook(namePlate)

	if GeometryIsLocked(namePlate) then
		deferred[namePlate] = true
	else
		deferred[namePlate] = nil
		ApplyGeometry(namePlate)
	end
end)

local regen = CreateFrame("Frame")
regen:RegisterEvent("PLAYER_REGEN_ENABLED")
regen:SetScript("OnEvent", function()
	for namePlate in next, deferred do
		deferred[namePlate] = nil
		if not namePlate:IsForbidden() and namePlate.unit then
			ApplyGeometry(namePlate)
		end
	end
end)

-- Cast bars switch art for every cast, delay, interrupt change and stop. sInterface's texture is
-- used with the classic cast colours (yellow, green channel, grey uninterruptible, red failed).
-- The cast type is secret for some units; the fill is then tinted through a boolean colour
-- selection and Blizzard's art stays for the stop states.
local function TintCast(castBar)
	if castBar.reverseChanneling or not castBar.unit then return end

	local notInterruptible
	if castBar.channeling then
		notInterruptible = select(7, UnitChannelInfo(castBar.unit))
	else
		notInterruptible = select(8, UnitCastingInfo(castBar.unit))
	end
	if not (issecretvalue(notInterruptible) or notInterruptible ~= nil) then return end

	local standard = castBar:GetTypeInfo(CastingBarType.Standard)
	local channel = castBar:GetTypeInfo(CastingBarType.Channel)
	local uninterruptible = castBar:GetTypeInfo(CastingBarType.Uninterruptable)
	if not (standard and channel and uninterruptible) then return end

	local base = castBar.channeling and channel.classicFillColor or standard.classicFillColor
	castBar:GetStatusBarTexture():SetVertexColorFromBoolean(notInterruptible, uninterruptible.classicFillColor, base)
end

local function StyleCastFill(castBar, isFull)
	if castBar:IsForbidden() then return end

	local barType = castBar.barType
	if issecretvalue(barType) then
		if not isFull then
			castBar:SetStatusBarTexture(texture)
			TintCast(castBar)
		end
		return
	end

	local info = castBar:GetTypeInfo(barType)
	local color = info and (isFull and info.classicFullColor or info.classicFillColor)
	if not color then return end

	castBar:SetStatusBarTexture(texture)
	castBar:SetStatusBarColor(color:GetRGB())
end

hooksecurefunc(NamePlateCastingBarMixin, "UpdateBarFillTexture", StyleCastFill)
-- the cast state flags (casting, channeling) are set only after the first fill update
hooksecurefunc(NamePlateCastingBarMixin, "HandleCastStart", function(castBar)
	if not castBar:IsForbidden() and issecretvalue(castBar.barType) then TintCast(castBar) end
end)

hooksecurefunc(NamePlateAuraItemMixin, "OnLoad", function(aura)
	if aura:IsForbidden() then return end
	local font, size, flags = GameFontNormalOutline:GetFont()
	aura.CountFrame.Count:SetFont(font, size, flags)
	aura.CountFrame:SetPoint("BOTTOMRIGHT", 2, -2)
end)
