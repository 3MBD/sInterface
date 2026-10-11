local _, ns = ...
local E = ns.E

if not E:C('coolbar', 'enabled') then return end;

local CoolBar = CreateFrame("Frame", "CoolBar", UIParent)

local tick0, tick1, tick2, tick3, tick4, tick5, tick6 = 0, 1, 3, 10, 30, 120, 360
local segment
local cooldowns = {}
local noCooldowns = {}

local THROTTLE_THRESHHOLD = 0.5
local lastUpdate = 0

local issecretvalue = issecretvalue or function() return false end
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local GetSpellTexture = C_Spell.GetSpellTexture

-- Cooldown start/duration are secret while addon restrictions (combat, encounters, ...) are
-- active. Those spells are positioned without reading the values: a duration object is
-- evaluated against a curve that reproduces the bar's scale, and the result drives a hidden
-- status bar whose fill edge the icon is anchored to.
local canTrackSecret = C_Spell.GetSpellCooldownDuration and C_CurveUtil and C_CurveUtil.CreateCurve and true or false
local positionCurve

local function fs(frame, text, offset, just)
	local fs = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightOutline")
	if (text > 60) then text = (text/60).."m" end
	fs:SetText(text)
	fs:SetPoint("LEFT", offset, 0)
end

-- horizontal position on the bar for a number of seconds remaining
local function remainingToOffset(remain)
	if remain < tick1 then
		return segment * remain
	elseif remain < tick2 then
		return ((0.5 * remain) + 0.5)*segment
	elseif remain < tick3 then
		return ((0.14285714 * remain) + 1.5714285)*segment
	elseif remain < tick4 then
		return ((0.05 * remain) + 2.5)*segment
	elseif remain < tick5 then
		return ((0.01111112 * remain) + 3.666665)*segment
	elseif remain < tick6 then
		return ((0.00416666 * remain) + 5.5)*segment
	else
		return CoolBar:GetWidth()
	end
end

local function createPositionCurve()
	local curve = C_CurveUtil.CreateCurve()
	if curve.SetType and Enum.LuaCurveType then
		curve:SetType(Enum.LuaCurveType.Linear)
	end
	local points = { 0, tick1, tick2, tick3, tick4, tick5 - 0.001, tick5, tick6 }
	for _, remain in ipairs(points) do
		curve:AddPoint(remain, remainingToOffset(remain))
	end
	curve:AddPoint(86400, CoolBar:GetWidth())
	return curve
end

local function disableSecretTracking(err)
	canTrackSecret = false
	print("|cff00ffffsInterface|r: cooldowns can't be shown on the CoolBar while addon restrictions are active ("..tostring(err)..")")
end

-- returns start, duration when readable; nil, nil, info when secret; nothing when not on cooldown
local function readCooldown(spellId)
	local info = GetSpellCooldown(spellId)
	if not info then return end
	if issecretvalue(info.startTime) or issecretvalue(info.duration) then
		return nil, nil, info
	end
	return info.startTime, info.duration, info
end

function CoolBar:PLAYER_LOGIN()
	CoolBar:SetFrameStrata("BACKGROUND")
	CoolBar:SetHeight(E:C('coolbar', 'height'))
	CoolBar:SetWidth(E:C('coolbar', 'width'))
	CoolBar:SetPoint(unpack(E:C('coolbar', 'pos')))

	CoolBar.bg = CoolBar:CreateTexture(nil, "ARTWORK")
	CoolBar.bg:SetTexture(E:C('general', 'texture'))
	CoolBar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.5)
	CoolBar.bg:SetAllPoints(CoolBar)

	E:ShadowedBorder(CoolBar)

	segment = CoolBar:GetWidth() / 7

	CoolBar.fontLayer = CreateFrame("Frame", nil, CoolBar)
	CoolBar.fontLayer:SetAllPoints(CoolBar)
	CoolBar.fontLayer:SetFrameLevel(128)

	fs(CoolBar.fontLayer, tick0, 2, "LEFT")
	fs(CoolBar.fontLayer, tick1, segment, "CENTER")
	fs(CoolBar.fontLayer, tick2, segment* 2, "CENTER")
	fs(CoolBar.fontLayer, tick3, segment * 3, "CENTER")
	fs(CoolBar.fontLayer, tick4, segment * 4, "CENTER")
	fs(CoolBar.fontLayer, tick5, segment * 5, "CENTER")
	fs(CoolBar.fontLayer, tick6, (segment * 6)+4, "RIGHT")

	CoolBar.active = 0

	if canTrackSecret then
		positionCurve = createPositionCurve()
	end

	E:RegisterAlphaAnimation(CoolBar)
	CoolBar:PlayHide()
end

-- SetFromScale/SetToScale were renamed SetScaleFrom/SetScaleTo
local function scaleAnimation(group, from, to)
	local anim = group:CreateAnimation("Scale")
	anim:SetScaleFrom(from, from)
	anim:SetScaleTo(to, to)
	return anim
end

local function finish(f)
	f.ticker:Cancel()
	f.ticker = nil
	f.finishAnimation:Play()
	CoolBar.active = CoolBar.active - 1
	if CoolBar.active == 0 then
		CoolBar:PlayHide()
	end
end

-- original behaviour: the cooldown's end time is known, so the icon is placed numerically
local function updateKnown(f)
	local start, dur = readCooldown(f.spellId)
	if start and f.endTime > start + dur then
		f.endTime = start + dur
	end

	local gameTime = GetTime()
	local remain = f.endTime - gameTime
	if gameTime >= f.endTime then
		finish(f)
		return
	end

	f:SetPoint("CENTER", CoolBar, "LEFT", remainingToOffset(remain), 0)
	if remain < 0.2 and not f.finishAnimation:IsPlaying() then
		f.failAnimation:Stop()
		f.finishAnimation:Play()
	end
end

local function setSecretPosition(f)
	f.position:SetValue(f.duration:EvaluateRemainingDuration(positionCurve))
end

-- restricted: the remaining time is secret, only the never-secret isActive flag is inspected
local function updateSecret(f)
	local info = GetSpellCooldown(f.spellId)
	if not (info and info.isActive) then
		finish(f)
		return
	end

	-- this path has only been verified against the client's API documentation, so a client
	-- that rejects it turns the feature off once instead of erroring on every frame
	local ok, err = pcall(setSecretPosition, f)
	if not ok then
		disableSecretTracking(err)
		finish(f)
	end
end

function CoolBar:CreateCooldown(spellId)
	if ((GetTime() - lastUpdate) < THROTTLE_THRESHHOLD) then return end
	lastUpdate = GetTime()
	local start, dur, info = readCooldown(spellId)
	if not info then return end

	local chargeInfo = GetSpellCharges(spellId)
	local maxCharges = chargeInfo and chargeInfo.maxCharges

	local duration
	if start then
		if (dur < 2) and (maxCharges == nil) then
			noCooldowns[spellId] = true
			return
		end --probably GCD

		if (dur > 600) then
			noCooldowns[spellId] = true
			return
		end --too long to care
	else
		if not (canTrackSecret and positionCurve) or not info.isActive or info.isOnGCD then return end
		duration = C_Spell.GetSpellCooldownDuration(spellId, true)
		if not duration then return end
		local isZero = duration.IsZero and duration:IsZero()
		if not issecretvalue(isZero) and isZero then return end --only the GCD
	end

	local f

	for _, frame in pairs(cooldowns) do
		if frame.spellId == spellId then
			f = frame
			break
		end
	end

	if not f then
		local icon = GetSpellTexture(spellId)
		f = CreateFrame("Frame", nil, CoolBar)
		f.spellId = spellId
		f.icon = f:CreateTexture(nil, "ARTWORK")
		f.icon:SetTexture(icon)
		f.icon:SetAllPoints(f)
		f.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

		f.finishAnimation = f:CreateAnimationGroup()
		f.finishAnimation.scaleUp = scaleAnimation(f.finishAnimation, 1, 4)
		f.finishAnimation.scaleUp:SetDuration(0.3)
		f.finishAnimation.scaleUp:SetSmoothing("OUT")
		f.finishAnimation.scaleUp:SetEndDelay(0.8)
		f.finishAnimation.alphaOut = f.finishAnimation:CreateAnimation("Alpha")
		f.finishAnimation.alphaOut:SetFromAlpha(1)
		f.finishAnimation.alphaOut:SetToAlpha(0)
		f.finishAnimation.alphaOut:SetDuration(0.6)
		f.finishAnimation:HookScript("OnFinished", function()
			f:Hide()
		end)

		f.failAnimation = f:CreateAnimationGroup()
		f.failAnimation.scaleUp = scaleAnimation(f.failAnimation, 1, 3)
		f.failAnimation.scaleUp:SetDuration(0.3)
		f.failAnimation.scaleUp:SetSmoothing("OUT")
		f.failAnimation.scaleUp:SetEndDelay(0.1)

		f.failAnimation.alphaOut = f.failAnimation:CreateAnimation("Alpha")
		f.failAnimation.alphaOut:SetFromAlpha(1)
		f.failAnimation.alphaOut:SetToAlpha(0)
		f.failAnimation.alphaOut:SetDuration(0.2)
		f.failAnimation.alphaOut:SetOrder(2)
		f.failAnimation.scaleDown = scaleAnimation(f.failAnimation, 1, 0.33)
		f.failAnimation.scaleDown:SetDuration(0.2)
		f.failAnimation.scaleDown:SetOrder(2)

		f.failAnimation.alphaIn = f.failAnimation:CreateAnimation("Alpha")
		f.failAnimation.alphaIn:SetToAlpha(1)
		f.failAnimation.alphaIn:SetDuration(0.2)
		f.failAnimation.alphaIn:SetOrder(3)

		table.insert(cooldowns, f)
	end

	-- already being tracked (e.g. cast again after a reset); restart below
	if f.ticker then
		f.ticker:Cancel()
		CoolBar.active = CoolBar.active - 1
	end

	f.finishAnimation:Stop()
	f:ClearAllPoints()
	f:SetHeight(CoolBar:GetHeight()*1.5)
	f:SetWidth(CoolBar:GetHeight()*1.5)
	f:SetAlpha(1)
	CoolBar.active = CoolBar.active + 1

	if (CoolBar.active == 1) then
		if UnitAffectingCombat('player') then
			CoolBar:PlayReveal()
		else
			CoolBar:PlayAlpha(E:C('general', 'oocAlpha'))
		end
	end

	local update
	if start then
		f.endTime = start + dur
		update = updateKnown
	else
		if not f.position then
			f.position = CreateFrame("StatusBar", nil, CoolBar)
			f.position:SetAllPoints(CoolBar)
			f.position:SetStatusBarTexture(E:C('general', 'texture'))
			f.position:GetStatusBarTexture():SetAlpha(0)
		end
		f.position:SetMinMaxValues(0, CoolBar:GetWidth())
		f.position:SetValue(CoolBar:GetWidth())
		f.duration = duration
		f:SetPoint("CENTER", f.position:GetStatusBarTexture(), "RIGHT", 0, 0)
		update = updateSecret
	end

	f.ticker = C_Timer.NewTicker(0.01, function()
		update(f)

		if f.ticker and (random() > .98) then
			f:SetFrameLevel(random(1,5) * 2 + 2)
		end
	end)

	C_Timer.After(0.03, function(self)
		f:Show()
	end)
end

local function isDisabled(spellId)
	local disabled = E:C('coolbar', 'disabled')
	if not disabled then return false end
	if disabled[spellId] then return true end
	-- the default list is keyed by name
	local name = C_Spell.GetSpellName and C_Spell.GetSpellName(spellId)
	if issecretvalue(name) or name == nil then return false end
	return disabled[name] and true or false
end

function CoolBar:UNIT_SPELLCAST_SUCCEEDED(_, _, spellId)
	if issecretvalue(spellId) or (spellId == nil) or (noCooldowns[spellId]) then return end

	if not isDisabled(spellId) then
		C_Timer.After(0.1, function()
			CoolBar:CreateCooldown(spellId)
		end)
	end
end

function CoolBar:UNIT_SPELLCAST_FAILED(_, _, spellId)
	if issecretvalue(spellId) or (spellId == nil) or noCooldowns[spellId] then return end

	local f
	for _, frame in pairs(cooldowns) do

		if (frame.spellId == spellId) and frame:IsShown() then
			f = frame
			break
		end
	end

	if not f then return end

	if not f.finishAnimation:IsPlaying() then
		f.failAnimation:Stop()
		f.failAnimation:Play()
	end
end

function CoolBar:PLAYER_REGEN_DISABLED()
	if CoolBar.active > 0 then
		CoolBar:PlayReveal()
	end
end

function CoolBar:PLAYER_REGEN_ENABLED()
	if CoolBar.active > 0 then
		CoolBar:PlayAlpha(E:C('general', 'oocAlpha'))
	end
end

CoolBar:SetScript("OnEvent", function(this, event, ...)
	this[event](this, ...)
end)
for k, _ in pairs(CoolBar) do
	if (k  == string.upper(k)) then
		if (string.find(k, "UNIT_")) then
			CoolBar:RegisterUnitEvent(k, "player", "vehicle")
		else
			CoolBar:RegisterEvent(k)
		end
	end
end
