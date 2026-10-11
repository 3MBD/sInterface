local _, ns = ...
local E = ns.E

if not E:C('uf', 'enabled') then return end

local oUF = ns.oUF or oUF
local _, class = UnitClass('player')

-- Unit health, power, cast and aura data can be secret values on this client: they may be
-- passed to widget setters but not compared, used in arithmetic or boolean-tested.
local issecretvalue = issecretvalue or function() return false end

-- native StatusBar interpolation replaces the Lua-side oUF_Smooth plugin
local SMOOTHING = Enum.StatusBarInterpolation.ExponentialEaseOut

local CASTBAR_X_OFFSET = 0
local CASTBAR_Y_OFFSET = 10

local POWER_X_OFFSET = 0
local POWER_Y_OFFSET = 1

local CLASSPOWER_X_OFFSET = 0
local CLASSPOWER_Y_OFFSET = -8

local TEXT_Y_OFFSET = 6
local TEXT_X_OFFSET = 2

local CASTBAR_HEIGHT_RATIO = 1.3

local oocAlpha = E:C('general', 'oocAlpha')

-- Override some oUF.colors.power
-- oUF colours are ColorMixin objects, plain {r, g, b} tables break its elements
oUF.colors.power["COMBO_POINTS"] = oUF:CreateColor(1, 0.1, 0.1)
oUF.colors.power["FOCUS"] = oUF:CreateColor(1, 0.5, 0.25) -- why do we have to do this?

-- true or false, or nil while the player's health is secret
local function PlayerHealthIsFull()
	local cur, max = UnitHealth('player'), UnitHealthMax('player')
	if issecretvalue(cur) or issecretvalue(max) then return nil end
	return cur >= max
end

-- isTradeskill is never secret and is only returned while a cast is in progress
local function IsCasting(unit)
	return select(6, UnitCastingInfo(unit)) ~= nil
end

-- the pet frame does not exist when it is disabled
local function Pet(method, ...)
	local pet = _G.oUF_sInterfacePet
	if pet and pet[method] then
		pet[method](pet, ...)
	end
end

local function EnterCombat(self)
	self:PlayReveal()
	Pet('PlayReveal')
end

local function LeaveCombat(self)
	-- unknown (secret) health counts as not full
	if PlayerHealthIsFull() ~= true or IsCasting("player") then return end
	self:PlayHide()
	Pet('PlayHide')
end

local function HealthUpdate(self)
	if UnitAffectingCombat('player') then
		if self:GetAlpha() ~= 1 then
			self:PlayReveal()
			Pet('PlayReveal')
		end
		return
	end

	if PlayerHealthIsFull() == true then
		self:PlayHide()
		Pet('PlayHide')
	else
		self:PlayAlpha(oocAlpha)
		Pet('PlayAlpha', oocAlpha)
	end
end

local function EnterVehicle(self)
	self:PlayAlpha(oocAlpha)
	Pet('PlayAlpha', oocAlpha)
end

local function ExitVehicle(self)
	HealthUpdate(self)
end

local function SpellStart(self)
	if not UnitAffectingCombat('player') or self:GetAlpha() == 0 then
		self:PlayAlpha(oocAlpha)
	end
end

local function SpellFinish(self)
	if not UnitAffectingCombat('player') then
		self:PlayHide()
	end
end

-- UnitFrame_OnEnter reads self.unit, which oUF no longer sets (Blizzard's ping code owns it)
local function UpdateUnitTooltip(self)
	local unit = SecureButton_GetModifiedUnit(self)
	if not unit or GameTooltip:IsForbidden() then return end

	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	if GameTooltip:SetUnit(unit) then
		self.UpdateTooltip = UpdateUnitTooltip
	else
		self.UpdateTooltip = nil
	end
end

local OnEnter = function(self)
	UpdateUnitTooltip(self)
	if self.GroupRoleIndicator then
		if self.LFDTimer then self.LFDTimer:Cancel() end
		self.GroupRoleIndicator:PlayReveal()
	end
	self.Highlight:Show()
end

local OnLeave = function(self)
	UnitFrame_OnLeave(self)
	if self.GroupRoleIndicator then
		self.LFDTimer = C_Timer.NewTimer(1, function() self.GroupRoleIndicator:PlayHide() end)
	end
	self.Highlight:Hide()
end

-- Right-click menus come from oUF's *type2 = togglemenu attribute; the old dropdown
-- (UnitPopup_ShowMenu) no longer exists.

-- Aura names are secret in combat and aura containers only match spell IDs, so the
-- uf.buffs name whitelist is resolved to spell IDs once at login. Numeric keys are spell IDs.
local function ResolveTrackedBuffSpellIDs()
	local ids, keys = {}, {}
	for _, source in ipairs({ ns.C.uf and ns.C.uf.buffs, ns.UC.uf and ns.UC.uf.buffs }) do
		for key in next, source or {} do keys[key] = true end
	end

	for key in next, keys do
		if E:C('uf', 'buffs', key) then
			local spellID = type(key) == 'number' and key or C_Spell.GetSpellIDForSpellIdentifier(key)
			if spellID then ids[spellID] = true end
		end
	end

	return ids
end

local AuraPostCreateButton = function(auras, button, options)
	local size = auras.size

	local c = button.Count
	if c then
		c:ClearAllPoints()
		c:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', size*0.35, -(size*0.21))
		c:SetFontObject("GameFontNormalOutline")
		local font, _, flags = c:GetFont()
		c:SetFont(font, size*0.6, flags)
		c:SetTextColor(1, 1, 1)
	end

	if button.Cooldown then button.Cooldown:SetReverse(true) end
	button.Icon:SetTexCoord(.05, .95, .2, .7)
	button.Icon:SetDesaturated(options and options.sInterfaceDesaturate or false)

	E:ShadowedBorder(button)
end

-- Debuffs cast by others are desaturated on units that are not friendly. Aura data is not
-- readable per button any more, so two copies of the "others" group exist and one is enabled.
local AurasPostUpdate = function(auras)
	local unit = auras:GetUnit()
	local hostile = (unit and not UnitIsFriend('player', unit)) and true or false
	if auras.sInterfaceHostile == hostile then return end

	auras.sInterfaceHostile = hostile
	auras:SetAuraGroupEnabled(auras.sInterfaceOthers.desaturated, hostile)
	auras:SetAuraGroupEnabled(auras.sInterfaceOthers.normal, not hostile)
end

local function AddOthersDebuffs(b)
	b.sInterfaceOthers = {
		normal = b:AddGroup('HARMFUL|!PLAYER'),
		desaturated = b:AddGroup('HARMFUL|!PLAYER', { sInterfaceDesaturate = true }),
	}
	b:SetAuraGroupEnabled(b.sInterfaceOthers.desaturated, false)
	b.sInterfaceHostile = false
	b.PostUpdate = AurasPostUpdate
end

local function Auras(self, unit)
	local baseUnit = unit:match('[^%d]+')
	local enabled = E:C('uf', baseUnit, 'auras', 'enabled')
	if not enabled then return end

	local mode = E:C('uf', baseUnit, 'auras', 'mode')
	local size = E:C('uf', baseUnit, 'auras', 'size')

	local frameWidth = self:GetWidth()
	local spacing = 0
	local buttonsPerRow = 0
	local iterations = 0 -- reduce aura per row until loop condition satisfied
	while (spacing < 4) do -- require at least this many pixels spacing between buttons
		buttonsPerRow = (math.floor(frameWidth / size) - iterations)
		local leftover = frameWidth - (buttonsPerRow*size)
		spacing = leftover / (buttonsPerRow-1)
		iterations = iterations+1
	end

	-- oUF auras are Blizzard aura containers laid out by the client; a row holds
	-- exactly buttonsPerRow buttons (the extra half pixel absorbs float rounding)
	local b = self:CreateAuras({
		initialAnchor = 'BOTTOMLEFT',
		growthX = 'RIGHT',
		growthY = 'UP',
		layoutLimit = frameWidth + 0.5,
	})
	-- anchor before adding groups, the container cannot be repositioned by addons afterwards
	b:SetSize(frameWidth, 14)
	b:SetPoint('BOTTOMLEFT', self, 'TOPLEFT', 0, 12)
	b.size = size
	b.width = size
	b.height = size/1.4
	b.elementSpacing = spacing
	b.lineSpacing = spacing
	b.maxFrameCount = buttonsPerRow
	b.showCount = true
	b.PostCreateButton = AuraPostCreateButton

	-- each group is capped at one row; buffs come first, then debuffs
	if mode == 'aura' then
		b:AddGroup('HELPFUL')
		b:AddGroup('HARMFUL|PLAYER')
		AddOthersDebuffs(b)
	elseif mode == 'debuff' then
		b:AddGroup('HARMFUL|PLAYER')
		AddOthersDebuffs(b)
	else
		-- Blizzard's personal-display buffs (was nameplateShowSelf) plus the uf.buffs whitelist
		b:AddGroup('HELPFUL', { candidateFilters = { nameplateShowPersonal = true } })
		local ids = ResolveTrackedBuffSpellIDs()
		if next(ids) then
			b:AddGroup('HELPFUL', { candidateFilters = { nameplateShowPersonal = false, includeSpellIDs = ids } })
		end
	end

	self.sInterfaceAuras = b
end

local PostUpdateHealth = function(health, unit)
	if UnitIsDead(unit) or UnitIsGhost(unit) or not UnitIsConnected(unit) then
		health:SetValue(0)
	end
end

local PostUpdatePower = function(Power, _, _, _, max)
	-- the maximum is secret for units that are not player controlled; it cannot be tested for 0
	if issecretvalue(max) then
		Power:Show()
		return
	end

	if (max == 0) then
		Power:Hide()
	else
		Power:Show()
	end
end

-- oUF dropped .bg/.multiplier tinting; background textures get colour * multiplier here.
-- Secret colour components cannot be multiplied, so they darken through alpha instead.
local function TintBackground(bg, r, g, b)
	local mu = bg.multiplier or 1
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then
		bg:SetVertexColor(r, g, b, mu)
	else
		bg:SetVertexColor(r * mu, g * mu, b * mu, 1)
	end
end

local PostUpdateBarColor = function(element, _, color, r, g, b)
	local bg = element.bg
	if not bg then return end

	-- same precedence oUF uses for the bar itself
	if b then
		TintBackground(bg, r, g, b)
	elseif color then
		TintBackground(bg, color:GetRGB())
	end
end

local PostUpdateAdditionalPowerColor = function(element, color)
	PostUpdateBarColor(element, nil, color)
end

local function PostUpdatePowerArenaPreparation(self, specID)
	self:Hide()
end

local function PostUpdateClassPower(element, _, max, _, hasMaxChanged, powerType)
	if class == "DEATHKNIGHT" then return end
	local ClassPowerPip = element[1]
	local classPowerBar = ClassPowerPip:GetParent()

	if max == nil then
		classPowerBar:Hide()
		return
	end

	classPowerBar:Show()

	local unitFrameParent = element[1]:GetParent():GetParent()
	local anchor
	if unitFrameParent.AdditionalPower and unitFrameParent.AdditionalPower:IsShown() then
		anchor = unitFrameParent.AdditionalPower
	elseif unitFrameParent.Power and unitFrameParent.Power:IsShown() then
		anchor = unitFrameParent.Power
	else
		anchor = unitFrameParent
	end

	classPowerBar:SetPoint("TOP", anchor, "BOTTOM", CLASSPOWER_X_OFFSET, CLASSPOWER_Y_OFFSET)

	if(hasMaxChanged) then
		local multiplier = 0.7

		local newMax = (max > 5) and 5 or max
		local width = (E:C('uf', 'player', 'size', 'width') - (E:C('uf', 'classIconSpacing') * (newMax - 1))) / newMax

		local color = oUF.colors.power[powerType or "COMBO_POINTS"] or oUF.colors.power["COMBO_POINTS"]
		local r, g, b = color:GetRGB()

		for index = 1, max do
			local pip = element[index]
			pip:SetWidth(width)

			if index <= 5 then
				pip:SetStatusBarColor(r, g, b)
			else
				pip:SetStatusBarColor(r * multiplier, g * multiplier, b * multiplier)
			end
		end

		for index = max+1, 10 do
			local pip = element[index]
			pip:Hide()
		end
	end
end

-- oUF no longer calls PostUpdate when the class power goes away (e.g. leaving cat form)
local function PostClassPowerVisibility(element, isVisible)
	if class == "DEATHKNIGHT" then return end
	element[1]:GetParent():SetShown(isVisible)
end

local NOT_INTERRUPTIBLE_COLOR = CreateColor(0.65, 0.65, 0.65)

-- "elapsed | total" for casts and "remaining | total" for channels, formatted by the client
-- because cast times are duration objects that can hold secret values
local castTimeFormatter = C_StringUtil.CreateNumericRuleFormatter()
castTimeFormatter:SetBreakpoints({ { threshold = 0, format = "%.1f" } })

local function SetCastTimeFormat(self, isChannel)
	if self.sInterfaceTimeIsChannel == isChannel then return end
	self.sInterfaceTimeIsChannel = isChannel

	local property = Enum.DurationTextBindingProperty
	self.Time.binding:SetTextFormat("{} | {}", {
		{ property = isChannel and property.RemainingDuration or property.ElapsedDuration, formatter = castTimeFormatter },
		{ property = property.TotalDuration, formatter = castTimeFormatter },
	})
end

local PostCastStart = function(self, unit, _, notInterruptible)
	self.sInterfaceFailed = nil
	self:PlayReveal()
	self.Spark:Show()

	local isCasting = IsCasting(unit)
	SetCastTimeFormat(self, not isCasting)

	local color = isCasting and self.CastingColorObject or self.ChannelingColorObject
	local colorIsSecret = false
	if unit ~= 'player' and UnitCanAttack('player', unit) then
		-- notInterruptible is secret for units other than the player and pet
		if issecretvalue(notInterruptible) then
			color = C_CurveUtil.EvaluateColorFromBoolean(notInterruptible, NOT_INTERRUPTIBLE_COLOR, color)
			colorIsSecret = true
		elseif notInterruptible then
			color = NOT_INTERRUPTIBLE_COLOR
		end
	end
	if colorIsSecret then
		-- a secret colour given to the bar itself makes its GetAlpha() secret too, and the fade
		-- animation cannot take that as its start value: colour only the fill texture
		self:GetStatusBarTexture():SetVertexColor(color:GetRGB())
	else
		self:SetStatusBarColor(color:GetRGB())
	end

	local parent = self:GetParent()
	local anchor
	if parent.ClassPowerBar and parent.ClassPowerBar:IsShown() then
		anchor = parent.ClassPowerBar
	elseif parent.AdditionalPower and parent.AdditionalPower:IsShown() then
		anchor = parent.AdditionalPowerHolder
	elseif parent.Power and parent.Power:IsShown() then
		anchor = parent.PowerHolder
	else
		anchor = parent
	end

	self.Icon:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", CASTBAR_X_OFFSET, -CASTBAR_Y_OFFSET)
end

local PostCastStop = function(self)
	-- a failed or interrupted cast is still held on screen when its _STOP event arrives
	if self.sInterfaceFailed then return end
	self:SetStatusBarColor(unpack(self.CompleteColor))
	self:PlayAlpha(0, 0.1)
end

local PostCastFailed = function(self)
	self.sInterfaceFailed = true
	self:SetStatusBarColor(unpack(self.FailColor))
	self:PlayAlpha(0, 0.1)
end

-- pushback, shown in red after the cast time as before
local CustomDelayText = function(self, delay)
	self.Delay:SetFormattedText(" -%.1f", delay)
end

local Castbar = function(self, unit)
	local iconSpacing = 6
	local cb = createStatusbar(self, E:C('general', 'texture'), nil, nil, nil, 1, 1, 1, 1)

	cb.Delay = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightOutline")
	cb.Delay:SetJustifyH("RIGHT")
	cb.Delay:SetPoint('TOPRIGHT', -TEXT_X_OFFSET, TEXT_Y_OFFSET)
	cb.Delay:SetTextColor(1, 0, 0)

	cb.Time = cb:CreateFontString("sInterface_CastBarTime", "ARTWORK", "GameFontHighlightOutline")
	cb.Time:SetJustifyH("RIGHT")
	cb.Time:SetPoint('TOPRIGHT', cb.Delay, 'TOPLEFT')
	cb.Time.binding = C_DurationUtil.CreateDurationTextBinding()
	cb.Time.binding:SetFormatter(castTimeFormatter)
	SetCastTimeFormat(cb, false)

	cb.Text = cb:CreateFontString("sInterface_CastBarTime", "ARTWORK", "GameFontHighlightOutline")
	cb.Text:SetJustifyH("LEFT")
	cb.Text:SetPoint("TOPLEFT", TEXT_X_OFFSET, TEXT_Y_OFFSET)
	cb.Text:SetPoint('RIGHT', cb.Time, 'LEFT')
	cb.Text:SetText("Example") -- Set so GetFontHeight() returns a value > 0
	cb.Text:SetHeight(cb.Text:GetStringHeight())

	cb.CastingColor = {0, 0.7, 1}
	cb.CompleteColor = {0.12, 0.86, 0.15}
	cb.FailColor = {1.0, 0.09, 0}
	cb.ChannelingColor = {0.32, 0.3, 1}
	cb.CastingColorObject = CreateColor(unpack(cb.CastingColor))
	cb.ChannelingColorObject = CreateColor(unpack(cb.ChannelingColor))

	cb.Icon = cb:CreateTexture(nil, 'ARTWORK')
	cb.Icon:SetTexCoord(.1, .9, .1, .9)

	cb:SetPoint("BOTTOMLEFT", cb.Icon, "BOTTOMRIGHT", iconSpacing, 0)

	cb.Shield = cb:CreateTexture(nil, 'ARTWORK')
	cb.Shield:SetTexture[[Interface\CastingBar\UI-CastingBar-Arena-Shield]]
	cb.Shield:SetPoint('CENTER', cb.Icon, 'CENTER', 7, 0)

	cb.Spark = cb:CreateTexture(nil,'OVERLAY')
	cb.Spark:SetBlendMode('Add')
	cb.Spark:SetSize(10, cb:GetHeight())
	cb.Spark:SetPoint("CENTER", cb:GetStatusBarTexture(), "RIGHT", 0, 0)

	cb.PostCastStart = PostCastStart
	cb.PostCastStop = PostCastStop
	cb.PostCastFail = PostCastFailed
	cb.PostCastInterrupted = PostCastFailed
	cb.PostCastInterruptible = PostCastFailed
	cb.CustomDelayText = CustomDelayText

	cb.timeToHold = 0.75

	E:ShadowedBorder(cb)
	E:ShadowedBorder(cb.Icon)

	E:RegisterAlphaAnimation(cb)

	local cbHeight = self:GetHeight()/CASTBAR_HEIGHT_RATIO
	local textHeight = cb.Text:GetStringHeight();
	local iconSize = (cbHeight+textHeight)-TEXT_Y_OFFSET
	cb.Icon:SetSize(iconSize, iconSize)
	cb.Shield:SetSize(cbHeight*5.25, cbHeight*5.25)
	cb:SetSize(self:GetWidth()-iconSpacing-iconSize, cbHeight)
	self.Castbar = cb
end

-- oUF updates the prediction bars without an interpolation argument
local function SmoothSubBar(bar)
	local setValue = bar.SetValue
	bar.SetValue = function(b, value, interpolation)
		return setValue(b, value, interpolation or SMOOTHING)
	end
end

local HealthPrediction = function(self)
	local myBar = createStatusbar(self.Health, E:C('general', 'texture'), nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	myBar:SetPoint('TOP')
	myBar:SetPoint('BOTTOM')
	myBar:SetFrameStrata(self.Health:GetFrameStrata())
	myBar:SetFrameLevel(self.Health:GetFrameLevel())
	myBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
	myBar:SetWidth(self:GetWidth())
	SmoothSubBar(myBar)

	local otherBar = createStatusbar(self.Health, E:C('general', 'texture'), nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	otherBar:SetPoint('TOP')
	otherBar:SetPoint('BOTTOM')
	otherBar:SetFrameStrata(self.Health:GetFrameStrata())
	otherBar:SetFrameLevel(self.Health:GetFrameLevel())
	otherBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
	otherBar:SetWidth(self:GetWidth())
	SmoothSubBar(otherBar)

	local absorbBar = createStatusbar(self.Health, E:C('general', 'texture'), nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	absorbBar:SetPoint('TOP')
	absorbBar:SetPoint('BOTTOM')
	absorbBar:SetFrameStrata(self.Health:GetFrameStrata())
	absorbBar:SetFrameLevel(self.Health:GetFrameLevel())
	absorbBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
	absorbBar:SetWidth(self:GetWidth())

	local healAbsorbBar = createStatusbar(self.Health, E:C('general', 'texture'), nil, nil, 200, 0.33, 0.59, 0.33, 0.6)
	healAbsorbBar:SetPoint('TOP')
	healAbsorbBar:SetPoint('BOTTOM')
	healAbsorbBar:SetFrameStrata(self.Health:GetFrameStrata())
	healAbsorbBar:SetFrameLevel(self.Health:GetFrameLevel())
	healAbsorbBar:SetPoint('LEFT', self.Health:GetStatusBarTexture(), 'RIGHT')
	healAbsorbBar:SetWidth(self:GetWidth())

	-- the HealthPrediction element is now part of Health
	local h = self.Health
	h.HealingPlayer = myBar
	h.HealingOther = otherBar
	h.DamageAbsorb = absorbBar
	h.HealAbsorb = healAbsorbBar
	h.incomingHealOverflow = 1.1
end

local Health = function(self)
	local h = createStatusbar(self, E:C('general', 'texture'))
	h:SetAllPoints()

	local hbg = h:CreateTexture(nil, 'BACKGROUND')
	hbg:SetDrawLayer('BACKGROUND', 1)
	hbg:SetAllPoints(h)
	hbg:SetTexture(E:C('general', 'texture'))

	h.colorTapping = true
	h.colorClass = true
	h.colorReaction = true
	hbg.multiplier = .4

	h.smoothing = SMOOTHING

	h.PostUpdate = PostUpdateHealth
	h.PostUpdateColor = PostUpdateBarColor

	h.bg = hbg
	self.Health = h
end

local LFD = function(self)
	local GroupRoleIndicator = self.Health:CreateTexture(nil, 'OVERLAY')
	GroupRoleIndicator:SetSize(16, 16)
	GroupRoleIndicator:SetPoint('RIGHT', -5, 0)

	E:RegisterAlphaAnimation(GroupRoleIndicator)
	GroupRoleIndicator:PlayHide()

	self.GroupRoleIndicator = GroupRoleIndicator
end

local ReadyCheck = function(self)
	local rc = self.Health:CreateTexture(nil, 'OVERLAY')
	rc:SetPoint('CENTER', self.Health, 'LEFT', 0, 0)
	rc:SetSize(12, 12)
	self.ReadyCheck = rc
end

local Power = function(self, unit)
	local powerHolder = CreateFrame("Frame", nil, self)
	powerHolder:SetPoint("LEFT")
	powerHolder:SetPoint("RIGHT")
	powerHolder:SetPoint("TOP", self, "BOTTOM", POWER_X_OFFSET, POWER_Y_OFFSET)
	powerHolder:SetHeight(E:C('uf', unit:match('[^%d]+'), 'size', 'power'))

	local p = createStatusbar(powerHolder, E:C('general', 'texture'), nil, nil, nil, 1, 1, 1, 1)
	p:SetPoint('LEFT', (self:GetWidth()/18), 0)
	p:SetPoint('RIGHT', -(self:GetWidth()/18), 0)
	p:SetPoint("TOP")
	p:SetPoint("BOTTOM")

	if unit == 'player' then p.frequentUpdates = true end

	p.smoothing = SMOOTHING

	local pbg = p:CreateTexture(nil, 'BACKGROUND')
	pbg:SetAllPoints(p)
	pbg:SetTexture(E:C('general', 'texture'))

	p.colorPower = true
	pbg.multiplier = .4
	E:ShadowedBorder(p)
	p:SetFrameStrata(self.Health:GetFrameStrata())
	p:SetFrameLevel(self.Health:GetFrameLevel()+2)
	p.shadowedBackdrop:SetFrameStrata(self.Health:GetFrameStrata())
	p.shadowedBackdrop:SetFrameLevel(self.Health:GetFrameLevel()+1)
	p.shadowedShadow:SetFrameStrata(self.Health:GetFrameStrata())
	p.shadowedShadow:SetFrameLevel(self.Health:GetFrameLevel()+1)

	p.PostUpdate = PostUpdatePower
	p.PostUpdateColor = PostUpdateBarColor

	p.bg = pbg
	self.Power = p
	self.PowerHolder = powerHolder
end

local AdditionalPower = function(self, unit)
	local powerHolder = CreateFrame("Frame", nil, self)
	powerHolder:SetPoint("LEFT")
	powerHolder:SetPoint("RIGHT")
	powerHolder:SetPoint("TOP", self.PowerHolder, "BOTTOM", 0, -4)
	powerHolder:SetHeight(E:C('uf', unit:match('[^%d]+'), 'size', 'power'))


	local p = createStatusbar(powerHolder, E:C('general', 'texture'), nil, nil, nil, 1, 1, 1, 1)
	p:SetPoint('LEFT', (self:GetWidth()/18), 0)
	p:SetPoint('RIGHT', -(self:GetWidth()/18), 0)
	p:SetPoint("TOP")
	p:SetPoint("BOTTOM")

	local pbg = p:CreateTexture(nil, 'BACKGROUND')
	pbg:SetAllPoints(p)
	pbg:SetTexture(E:C('general', 'texture'))

	p.colorPower = true
	pbg.multiplier = .4
	E:ShadowedBorder(p)
	p:SetFrameStrata(self.Health:GetFrameStrata())
	p:SetFrameLevel(self.Health:GetFrameLevel()+1)
	p.shadowedBackdrop:SetFrameStrata(self.Health:GetFrameStrata())
	p.shadowedBackdrop:SetFrameLevel(self.Health:GetFrameLevel()+1)
	p.shadowedShadow:SetFrameStrata(self.Health:GetFrameStrata())
	p.shadowedShadow:SetFrameLevel(self.Health:GetFrameLevel()+1)

	p.PostUpdateColor = PostUpdateAdditionalPowerColor

	p.bg = pbg
	self.AdditionalPower = p
	self.AdditionalPowerHolder = powerHolder
end

local PhaseIndicator = function(self)
	local PhaseIndicator = self:CreateTexture(nil, "OVERLAY")
	PhaseIndicator:SetPoint("LEFT", -20, 0)
	PhaseIndicator:SetSize(16, 16)
	self.PhaseIndicator = PhaseIndicator
end

-- oUF passes the unit to style functions; it no longer sets self.unit (Blizzard code reads it)
local pendingClicks = {}
local clickRetry = CreateFrame('Frame')
clickRetry:SetScript('OnEvent', function(retry)
	retry:UnregisterEvent('PLAYER_REGEN_ENABLED')
	for frame in next, pendingClicks do
		frame:RegisterForClicks'AnyUp'
		pendingClicks[frame] = nil
	end
end)

local Shared = function(self, unit)
	unit = unit:match('^(.-)%d+') or unit

	self:SetScript('OnEnter', OnEnter)
	self:SetScript('OnLeave', OnLeave)

	local width = E:C('uf', unit, 'size', 'width')
	local height = E:C('uf', unit, 'size', 'height')
	-- group members can be styled during combat; their size is set securely by
	-- oUF-initialConfigFunction
	if InCombatLockdown() then
		-- RegisterForClicks is protected: do it when combat ends
		pendingClicks[self] = true
		clickRetry:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		self:RegisterForClicks'AnyUp'
		self:SetSize(width, height)
	end

	Health(self)

	E:ShadowedBorder(self)

	local ricon = self.Health:CreateTexture(nil, 'OVERLAY')
	local riconsize = self.Health:GetHeight()-2
	ricon:SetSize(riconsize, riconsize)
	ricon:SetPoint('RIGHT', -5, 0)
	self.RaidTargetIndicator = ricon

	local hl = self.Health:CreateTexture(nil, nil, nil, 1)
	hl:SetAllPoints(self)
	hl:SetTexture("Interface/TargetingFrame/UI-TargetingFrame-BarFill")
	hl:SetVertexColor(1, 1, 1, 0.15)
	hl:SetBlendMode('ADD')
	hl:Hide()
	self.Highlight = hl
end


local UnitSpecific = {
	player = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		AdditionalPower(self, unit)
		HealthPrediction(self)

		Auras(self, unit)

		local fcf = CreateFrame("Frame", nil, self.Health)
		fcf:SetSize(32, 32)
		fcf:SetPoint("CENTER")
		fcf.mode = "Fountain"
		fcf.fontHeight=16
		for i = 1, 6 do
			fcf[i] = fcf:CreateFontString(nil, "OVERLAY", "CombatTextFont")
		end
		self.FloatingCombatFeedback = fcf

		-- oUF's player castbar hides PlayerCastingBarFrame and PetCastingBarFrame itself

		local htext = self.Health:CreateFontString("sInterface_PlayerHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		htext.frequentUpdates = .1
		self:Tag(htext, '[sInterface:health]')

		local ptext = self.Health:CreateFontString("sInterface_TargetName", "ARTWORK", "GameFontNormalOutline")
		ptext:SetJustifyH("LEFT")
		ptext:SetPoint('TOPLEFT', TEXT_X_OFFSET, TEXT_Y_OFFSET)
		ptext.frequentUpdates = .1
		self:Tag(ptext, '[sInterface:power]')

		-- unnamed: the global ClassPowerBar is a Blizzard mixin used by the resource displays
		local ClassPowerBar = CreateFrame('Frame', nil, self)
		ClassPowerBar:SetWidth(self:GetWidth())
		ClassPowerBar:SetHeight(self.PowerHolder:GetHeight())
		ClassPowerBar:SetPoint("TOP", self.PowerHolder, "BOTTOM", CLASSPOWER_X_OFFSET, CLASSPOWER_Y_OFFSET)
		-- shown by the ClassPower callbacks while the class has a class power (runes stay visible)
		if class ~= "DEATHKNIGHT" then
			ClassPowerBar:Hide()
		end
		self.ClassPowerBar = ClassPowerBar

		local ClassPower = {}
		ClassPower.PostUpdate = PostUpdateClassPower
		ClassPower.PostVisibility = PostClassPowerVisibility

		for index = 1, 11 do
			local ClassPowerPip = CreateFrame("StatusBar", nil, ClassPowerBar)
			ClassPowerPip:SetStatusBarTexture(E:C('general', 'texture'))
			ClassPowerPip:SetHeight(ClassPowerBar:GetHeight())
			ClassPowerPip:SetWidth(16)
			E:ShadowedBorder(ClassPowerPip)

			if index > 5 then
				ClassPowerPip:SetPoint("LEFT", ClassPower[index-5], "LEFT", 0, 0)
				ClassPowerPip:SetFrameLevel(ClassPower[1]:GetFrameLevel()+1)
			elseif index > 1 then
				ClassPowerPip:SetPoint('LEFT', ClassPower[index-1], 'RIGHT', E:C('uf', 'classIconSpacing'), 0)
			else
				ClassPowerPip:SetPoint('LEFT', ClassPowerBar, 'LEFT', 0, 0)
			end

			ClassPower[index] = ClassPowerPip
		end

		self.ClassPower = ClassPower

		if(class == 'DEATHKNIGHT') then
			local Runes = {}
			local totalRunes = 6
			local width = (E:C('uf', 'player', 'size', 'width') - (E:C('uf', 'classIconSpacing') * (totalRunes - 1))) / totalRunes
			for index = 1, totalRunes do
				local Rune = CreateFrame('StatusBar', nil, ClassPowerBar)
				Rune:SetSize(width, ClassPowerBar:GetHeight())
				Rune:SetStatusBarTexture(E:C('general', 'texture'))
				E:ShadowedBorder(Rune)

				if index > 1 then
					Rune:SetPoint('LEFT', Runes[index - 1], 'RIGHT', E:C('uf', 'classIconSpacing'), 0)
				else
					Rune:SetPoint('LEFT', ClassPowerBar, 'LEFT', 0, 0)
				end

				Runes[index] = Rune
			end
			Runes.colorSpec = true
			self.Runes = Runes
		end

		Castbar(self)

		self.GCD = CreateFrame('Frame', nil, self.Health)
		self.GCD:SetPoint('LEFT', self.Health, 'LEFT')
		self.GCD:SetPoint('RIGHT', self.Health, 'RIGHT')
		self.GCD:SetHeight(E:C('uf', 'player', 'size', 'height')+4)

		self.GCD:SetHeight(E:C('uf', 'player', 'size', 'height')+4)

		self.GCD.Spark = self.GCD:CreateTexture(nil, "OVERLAY")
		self.GCD.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		self.GCD.Spark:SetBlendMode("ADD")
		self.GCD.Spark:SetHeight((E:C('uf', 'player', 'size', 'height')*2)+4)
		self.GCD.Spark:SetWidth(9)
		self.GCD.Spark:SetPoint('LEFT', self.Health, 'LEFT', 0, 0)

		local altp = createStatusbar(self, E:C('general', 'texture'), nil, E:C('uf', 'player', 'size', 'power'), self:GetWidth(), 1, 1, 1, 1)
		altp:SetPoint("BOTTOM", self, "TOP", 0, 3)
		altp.bg = altp:CreateTexture(nil, 'BORDER')
		altp.bg:SetAllPoints(altp)
		altp.bg:SetTexture(E:C('general', 'texture'))
		altp.bg:SetVertexColor(1, 1, 1, 0.3)
		altp.Text = altp:CreateFontString("sInterface_AltPower", "ARTWORK", "GameFontNormalOutline")
		altp.Text:SetJustifyH("LEFT")
		altp.Text:SetPoint("BOTTOM", altp, "TOP", 0, -2)
		self:Tag(altp.Text, '[sInterface:altpower]')
		altp:EnableMouse(true)
		E:ShadowedBorder(altp)
		self.AlternativePower = altp

		E:RegisterAlphaAnimation(self)

		if E:C('uf', 'hidePlayerFrameOoc') then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", LeaveCombat, true)
			self:RegisterEvent("PLAYER_REGEN_DISABLED", EnterCombat, true)
			self:RegisterEvent("UNIT_HEALTH", HealthUpdate)
			self:RegisterEvent("UNIT_SPELLCAST_START", SpellStart)
			self:RegisterEvent("UNIT_SPELLCAST_STOP", SpellFinish)
			self:RegisterEvent("UNIT_ENTERED_VEHICLE", EnterVehicle)
			self:RegisterEvent("UNIT_EXITED_VEHICLE", ExitVehicle)
			self:PlayHide()
		end
	end,

	target = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		HealthPrediction(self)
		Castbar(self)
		PhaseIndicator(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_TargetHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		htext.frequentUpdates = .1
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_TargetName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetPoint('RIGHT', htext, 'LEFT', -3, 0)
		name:SetHeight(10)
		self:Tag(name, '[sInterface:level<$ ][sInterface:name]')
	end,

	focus = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		HealthPrediction(self)
		Castbar(self)
		PhaseIndicator(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_FocusHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_FocusName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetHeight(10)
		name:SetPoint('RIGHT', htext, 'LEFT', -3, 0)
		self:Tag(name, '[sInterface:level<$ ][sInterface:name]')
	end,

	boss = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		Castbar(self)
		PhaseIndicator(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_BossHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_BossName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetHeight(10)
		name:SetPoint('RIGHT', htext, 'LEFT')
		self:Tag(name, '[sInterface:name]')

		local altp = createStatusbar(self, E:C('general', 'texture'), nil, self.Power:GetHeight(), self:GetWidth(), 1, 1, 1, 1)
		altp:SetPoint('BOTTOM', self, 'TOP', 0, 5)
		altp.bg = altp:CreateTexture(nil, 'BORDER')
		altp.bg:SetAllPoints(altp)
		altp.bg:SetTexture(E:C('general', 'texture'))
		altp.bg:SetVertexColor(1, 1, 1, 0.3)
		altp.Text = altp:CreateFontString("sInterface_AltPower", "ARTWORK", "GameFontNormalOutline")
		altp.Text:SetJustifyH("LEFT")
		altp.Text:SetPoint('CENTER')
		altp:EnableMouse(true)
		altp.colorTexture = true
		self:Tag(altp.Text, '[sInterface:altpower]')
		E:ShadowedBorder(altp)
		self.AlternativePower = altp
	end,

	pet = function(self, unit)
		Shared(self, unit)
		HealthPrediction(self)
		PhaseIndicator(self)

		local name = self.Health:CreateFontString("sInterface_PetName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('CENTER', self.Health, 0, 3)
		self:Tag(name, '[sInterface:name]')
		self.Name = name;
		self.Name:Hide();

		self:SetScript('OnEnter', function(self)UIFrameFadeIn(self.Name, 0.3, 0, 1)end)
		self:SetScript('OnLeave', function(self)UIFrameFadeOut(self.Name, 0.3, 1, 0)end)

		if E:C('uf', 'hidePlayerFrameOoc') then
			E:RegisterAlphaAnimation(self)
			self:PlayHide()
		end
	end,

	targettarget = function(self, unit)
		Shared(self, unit)
		Auras(self, unit)

		local name = self.Health:CreateFontString("sInterface_TargetTargetName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('CENTER', 0, TEXT_Y_OFFSET)
		self:Tag(name, '[sInterface:shortname]')
	end,

	party = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		HealthPrediction(self)
		PhaseIndicator(self)
		LFD(self)
		ReadyCheck(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_PartyHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_PartyName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetHeight(10)
		name:SetPoint('RIGHT', htext, 'LEFT', -3, 0)
		self:Tag(name, '[sInterface:level<$ ][sInterface:name]')
	end,

	tank = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		HealthPrediction(self)
		PhaseIndicator(self)
		LFD(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_TankHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_TankName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetHeight(10)
		name:SetPoint('RIGHT', htext, 'LEFT', -3, 0)
		self:Tag(name, '[sInterface:level<$ ][sInterface:name]')

		local rc = self.Health:CreateTexture(nil, 'OVERLAY')
		rc:SetPoint('CENTER')
		rc:SetSize(12, 12)
		self.ReadyCheck = rc
	end,

	arena = function(self, unit)
		Shared(self, unit)
		Power(self, unit)
		Castbar(self)
		Auras(self, unit)

		local htext = self.Health:CreateFontString("sInterface_ArenaHealth", "ARTWORK", "GameFontNormalOutline")
		htext:SetJustifyH("RIGHT")
		htext:SetPoint('TOPRIGHT', self, -TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(htext, '[sInterface:health]')

		local name = self.Health:CreateFontString("sInterface_ArenaName", "ARTWORK", "GameFontHighlightOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		name:SetHeight(10)
		name:SetPoint('RIGHT', htext, 'LEFT', -3, 0)
		-- [arenaspec] reads GetArenaOpponentSpec, which is always secret (and Forever has no
		-- specializations); show the opponent's name instead
		self:Tag(name, '[sInterface:name]')

		local t = CreateFrame('Frame', nil, self)
		t:SetSize(E:C('uf', unit:match('[^%d]+'), 'size', 'height'), E:C('uf', unit:match('[^%d]+'), 'size', 'height'))
		t:SetPoint('TOPRIGHT', self, 'TOPLEFT', -4, 0)
		E:ShadowedBorder(t)
		self.Trinket = t

		self.Power.PostUpdateArenaPreparation = PostUpdatePowerArenaPreparation
	end,

	raid = function(self, unit)
		Shared(self, unit)
		HealthPrediction(self)
		LFD(self)
		ReadyCheck(self)

		local name = self.Health:CreateFontString("sInterface_RaidName", "ARTWORK", "GameFontNormalOutline")
		name:SetJustifyH("LEFT")
		name:SetPoint('TOPLEFT', self, TEXT_X_OFFSET, TEXT_Y_OFFSET)
		self:Tag(name, '[sInterface:shortname]')
	end,
}

UnitSpecific.focustarget = UnitSpecific.targettarget

oUF:RegisterStyle('sInterface', Shared)
for unit,layout in next, UnitSpecific do
	oUF:RegisterStyle('sInterface - ' .. unit:gsub('^%l', string.upper), layout)
end

local function spawnHelper(self, unit, pos)
	local baseUnit = unit:match('^(.-)%d+') or unit
	if not E:C("uf", baseUnit, "enabled") then return end

	if(UnitSpecific[unit]) then
		self:SetActiveStyle('sInterface - ' .. unit:gsub('^%l', string.upper))
	elseif(UnitSpecific[unit:match('[^%d]+')]) then
		self:SetActiveStyle('sInterface - ' .. unit:match('[^%d]+'):gsub('^%l', string.upper))
	else
		self:SetActiveStyle'sInterface'
	end
	local object = self:Spawn(unit)
	object:SetPoint(unpack(pos))
	return object
end

local function partySpawn(self)
	if not E:C('uf', 'party', 'enabled') then return end

	-- oUF disables the pooled Blizzard party frames, their pet frames and the compact party frames
	local adjuster = E:C('uf', 'party', 'auras', 'enabled') and E:C('uf', 'party', 'auras', 'size') or 0
	local yOffset =  -23 + -adjuster

	self:SetActiveStyle('sInterface - Party')
	local party = self:SpawnHeader(nil, nil,
	'showPlayer', false,
	'showSolo', false,
	'showParty', true,
	'yOffset', yOffset,
	'oUF-initialConfigFunction',
		([[
			self:SetHeight(%d)
			self:SetWidth(%d)
		]]):format(E:C('uf', 'party', 'size', 'height'), E:C('uf', 'party', 'size', 'width'))
	)

	party:SetVisibility('custom [@arena1,exists][@arena2,exists][@arena3,exists][group:party,nogroup:raid] show; hide')
	party:SetPoint(unpack(E:C('uf', 'party', 'position')))
end

local function maintankSpawn(self)
	if not E:C('uf', 'maintank', 'enabled') then return end

	local adjuster = E:C('uf', 'maintank', 'auras', 'enabled') and E:C('uf', 'maintank', 'auras', 'size') or 0
	local yOffset =  -23 + -adjuster

	self:SetActiveStyle('sInterface - Tank')
	local maintank = self:SpawnHeader('oUF_MainTank', nil,
	'showRaid', true,
	'showSolo', false,
	'groupFilter', 'MAINTANK',
	'yOffset', yOffset,
	'oUF-initialConfigFunction',
		([[
			self:SetHeight(%d)
			self:SetWidth(%d)
		]]):format(E:C('uf', 'maintank', 'size', 'height'), E:C('uf', 'maintank', 'size', 'width'))
	)

	maintank:SetVisibility('raid')
	maintank:SetPoint(unpack(E:C('uf', 'maintank', 'position')))
end

-- The raid container is an Edit Mode frame of its own now, so reparenting the manager no longer
-- hides it. Block both the way oUF blocks the other Blizzard unit frames, without writing to
-- Blizzard tables (that taints them).
local function HideBlizzardRaidFrames()
	if InCombatLockdown() or not C_AddOns.IsAddOnLoaded('Blizzard_CompactRaidFrames') then return end

	for _, frame in ipairs({ CompactRaidFrameManager, CompactRaidFrameContainer }) do
		frame:UnregisterAllEvents()
		frame:SetRolesets('alwaysBlocked')
	end
end

local function raidSpawn(self)
	if not E:C('uf', 'raid', 'enabled') then return end

	HideBlizzardRaidFrames()

	self:SetActiveStyle('sInterface - Raid')
	local raid = oUF:SpawnHeader(nil, nil,
	'showPlayer', true,
	'showSolo', false,
	'showParty', false,
	'showRaid', true,
	'xoffset', 8,
	'yOffset', -8,
	'point', 'TOP',
	'groupFilter', '1,2,3,4,5,6,7,8',
	'groupingOrder', '1,2,3,4,5,6,7,8',
	'groupBy', 'GROUP',
	'maxColumns', 8,
	'unitsPerColumn', 5,
	'columnSpacing', 8,
	'columnAnchorPoint', 'LEFT',
	'oUF-initialConfigFunction', ([[
		self:SetHeight(%d)
		self:SetWidth(%d)
	]]):format(E:C('uf', 'raid', 'size', 'height'), E:C('uf', 'raid', 'size', 'width'))
	)

	raid:SetVisibility('raid')
	raid:SetPoint(unpack(E:C('uf', 'raid', 'position')))
end

local function bossSpawn(self)
	if not E:C("uf", "boss", "enabled") then return end

	spawnHelper(self, "boss1", E:C("uf", "boss", "position"))

	local adjuster = E:C('uf', 'boss', 'auras', 'enabled') and E:C('uf', 'boss', 'auras', 'size') or 0
	local bossCastBar = _G['oUF_sInterfaceBoss1'].Castbar
	local bossPowerBar = _G['oUF_sInterfaceBoss1'].Power
	local bossyOffset = bossCastBar:GetHeight() + (CASTBAR_Y_OFFSET*3) + bossPowerBar:GetHeight() + adjuster

	for i = 2, MAX_BOSS_FRAMES do
		local pos = { 'BOTTOMLEFT', 'oUF_sInterfaceBoss'..i-1, 'TOPLEFT', 0, bossyOffset }
		spawnHelper(self, 'boss' .. i, pos)
	end
end

local function arenaSpawn(self)
	if not E:C('uf', 'arena', 'enabled') then return end

	spawnHelper(self, "arena1", E:C('uf', 'arena', 'position'))

	local adjuster = E:C('uf', 'arena', 'auras', 'enabled') and E:C('uf', 'arena', 'auras', 'size') or 0
	local arenaCastBar = _G['oUF_sInterfaceArena1'].Castbar
	local arenaPowerBar = _G['oUF_sInterfaceArena1'].Power
	local arenayOffset = arenaCastBar:GetHeight() + (CASTBAR_Y_OFFSET*3) + arenaPowerBar:GetHeight() + adjuster

	for i = 2, 5 do
		local pos = { "BOTTOM", "oUF_sInterfaceArena"..i-1, "TOP", 0, arenayOffset }
		spawnHelper(self, "arena" ..i, pos)
	end
end

local function playerSpawn(self)
	if not E:C('uf', 'player', 'enabled') then return end

	spawnHelper(self, 'player', E:C('uf', 'player', 'position'))

	-- emulatePersonalResourceDisplay used to anchor the player frame to the player's own
	-- nameplate. On this client the Personal Resource Display is an Edit Mode frame, not a
	-- nameplate (C_NamePlate.SetNamePlateSelfClickThrough is gone), so there is nothing to
	-- follow: the frame stays at uf.player.position and the nameplate CVars are left alone.
end

oUF:Factory(function(self)
	playerSpawn(self)
	spawnHelper(self, "target", E:C("uf", "target", "position"))
	spawnHelper(self, "targettarget", E:C("uf", "targettarget", "position"))
	spawnHelper(self, "focus", E:C("uf", "focus", "position"))
	spawnHelper(self, "focustarget", E:C("uf", "focustarget", "position"))
	spawnHelper(self, "pet", E:C("uf", "pet", "position"))

	partySpawn(self)
	raidSpawn(self)
	maintankSpawn(self)
	bossSpawn(self)
	arenaSpawn(self)
end)
