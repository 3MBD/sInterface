local _, ns = ...
local oUF = ns.oUF or oUF
local E = ns.E

-- Secret values (12.x engine): addon code may pass them to formatting/widget APIs but must not
-- compare, do arithmetic on, index tables with, or string.sub them. issecretvalue exists only on
-- engines that have secrets, so it doubles as the capability check.
local issecret = issecretvalue or function() return false end

-- oUF 14 colors are ColorMixin objects (embeds/oUF/colors.lua:62-78); its power element and the
-- [powercolor] tag call :GetRGB()/:GenerateHexColorMarkup() on them, so overrides must be created
-- with oUF:CreateColor instead of plain {r, g, b} arrays.
local function C(r, g, b) return oUF:CreateColor(r, g, b) end

oUF.colors.power['MANA']                   = C(0.37, 0.6, 1)
oUF.colors.power['RAGE']                   = C(0.9, 0.3, 0.23)
oUF.colors.power['FOCUS']                  = C(1, 0.81, 0.27)
oUF.colors.power['RUNIC_POWER']            = C(0, 0.81, 1)
oUF.colors.power['AMMOSLOT']               = C(0.78, 1, 0.78)
oUF.colors.power['FUEL']                   = C(0.9, 0.3, 0.23)
oUF.colors.power['POWER_TYPE_STEAM']       = C(0.55, 0.57, 0.61)
oUF.colors.power['POWER_TYPE_PYRITE']      = C(0.60, 0.09, 0.17)
oUF.colors.power['POWER_TYPE_HEAT']        = C(0.55, 0.57, 0.61)
oUF.colors.power['POWER_TYPE_OOZE']        = C(0.76, 1, 0)
oUF.colors.power['POWER_TYPE_BLOOD_POWER'] = C(0.7, 0, 1)
oUF.colors.ghost                           = C(0.4, 0.76, 0.93)
oUF.colors.dead                            = C(0.76, 0.37, 0.37)
oUF.colors.health                          = C(0.68, 0.31, 0.31)

local FULL_HEALTH_COLOR = C(0.33, 0.58, 0.33)

-- Same "%.1f<suffix>" style as sValue below, but computed by the client so it accepts secrets
-- (AbbreviateNumbers: SecretArguments = "AllowedWhenTainted").
local ABBREVIATE_OPTIONS = {
	breakpointData = {
		{ breakpoint = 1e12, abbreviation = 't', significandDivisor = 1e11, fractionDivisor = 10, abbreviationIsGlobal = false },
		{ breakpoint = 1e9,  abbreviation = 'b', significandDivisor = 1e8,  fractionDivisor = 10, abbreviationIsGlobal = false },
		{ breakpoint = 1e6,  abbreviation = 'm', significandDivisor = 1e5,  fractionDivisor = 10, abbreviationIsGlobal = false },
		{ breakpoint = 1e3,  abbreviation = 'k', significandDivisor = 1e2,  fractionDivisor = 10, abbreviationIsGlobal = false },
	},
}

local sValue = function(val)
	if issecret(val) then
		return AbbreviateNumbers(val, ABBREVIATE_OPTIONS)
	end

	local placeValue = ("%%.%df"):format(1)
	if (val >= 1e12) then
		return placeValue:format(val / 1e12) .. "t"
	elseif (val >= 1e9) then
		return placeValue:format(val / 1e9) .. "b"
	elseif (val >= 1e6) then
		return placeValue:format(val / 1e6) .. "m"
	elseif (val >= 1e3) then
		return placeValue:format(val / 1e3) .. "k"
	else
		return ('%d'):format(val)
	end
end

local function hex(r, g, b)
	if (type(r) == 'table') then
		if (r.r) then r, g, b = r.r, r.g, r.b else r, g, b = unpack(r) end
	end
	return ('|cff%02x%02x%02x'):format(r * 255, g * 255, b * 255)
end

local function StatusColor(unit)
	if E:PlayerIsTank() then
		-- UnitInRaid is SecretWhenUnitIdentityRestricted: a secret result means the unit is not
		-- in our party/raid, which is the same as "not a raid member" for this check.
		local inRaid = UnitInRaid(unit)
		if issecret(inRaid) then inRaid = nil end

		if inRaid or UnitInParty(unit) then
			local myName, unitName = UnitName("player"), UnitName(unit)
			if not issecret(myName) and not issecret(unitName) and myName ~= unitName then
				local status = UnitThreatSituation(unit)
				if not issecret(status) and status and status > 0 then
					return hex(GetThreatStatusColor(status))
				end
			end
		end
	end

	return hex(1, 1, 1)
end

local function ShortName(u)
	local name = oUF.Tags.Methods['name'](u)
	if issecret(name) then
		-- string.sub cannot operate on secret strings; show the untruncated (secret) name
		return name
	end
	return string.sub(name, 1, 7)
end

oUF.Tags.Methods['sInterface:name'] = function(u)
	return StatusColor(u) .. oUF.Tags.Methods['name'](u) .. "|r"
end
oUF.Tags.Events['sInterface:name'] = 'UNIT_CONNECTION UNIT_NAME_UPDATE UNIT_THREAT_SITUATION_UPDATE'


oUF.Tags.Methods['sInterface:shortname'] = function(u)
	if UnitIsDead(u) then
		return hex(oUF.colors.health) .. ShortName(u) .. "|r"
	elseif UnitIsGhost(u) then
		return hex(oUF.colors.ghost) .. ShortName(u) .. "|r"
	elseif not UnitIsConnected(u) then
		return hex(oUF.colors.disconnected) .. ShortName(u) .. "|r"
	end

	return StatusColor(u) .. ShortName(u) .. "|r"
end
oUF.Tags.Events['sInterface:shortname'] = 'UNIT_NAME_UPDATE UNIT_HEALTH UNIT_CONNECTION UNIT_THREAT_SITUATION_UPDATE'


-- MAX_PLAYER_LEVEL is not defined on Forever (only Blizzard_UIPanels_Game/Vanilla/ReputationFrame.lua
-- sets it, and that file does not load for camelot); query the client instead.
local function MaxPlayerLevel()
	return (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or MAX_PLAYER_LEVEL
end

oUF.Tags.Methods['sInterface:level'] = function(u)
	local level = UnitEffectiveLevel(u)

	if level == MaxPlayerLevel() then
		return nil
	end

	local difficulty = hex(GetCreatureDifficultyColor((level > 0) and level or 999))

	if level <= 0 then
		level = '??'
	end

	return difficulty .. level .. "|r"
end
oUF.Tags.Events['sInterface:level'] = 'UNIT_LEVEL UNIT_CONNECTION'


-- Secret-health fallback: the "damaged => red + ' | NN%'" / "full => green" decision is made by the
-- client through curves, because addon code cannot compare secret health values.
local healthPercentCurve, healthColorCurve
local function GetHealthCurves()
	if healthPercentCurve == nil and C_CurveUtil and C_CurveUtil.CreateCurve and C_CurveUtil.CreateColorCurve then
		-- fraction [0, 1) -> 100 * x + 0.5 (TruncateWhenZero floors => rounds like math.floor(p + .5));
		-- full health (1.0) -> 0 so TruncateWhenZero returns '' and the " | NN%" suffix is dropped.
		healthPercentCurve = C_CurveUtil.CreateCurve()
		healthPercentCurve:SetType(Enum.LuaCurveType.Linear)
		healthPercentCurve:AddPoint(0, 0.5)
		healthPercentCurve:AddPoint(0.9999999, 100.4999995)
		healthPercentCurve:AddPoint(1, 0)

		healthColorCurve = C_CurveUtil.CreateColorCurve()
		healthColorCurve:SetType(Enum.LuaCurveType.Step)
		healthColorCurve:AddPoint(0, oUF.colors.health)
		healthColorCurve:AddPoint(0.9999999, oUF.colors.health)
		healthColorCurve:AddPoint(1, FULL_HEALTH_COLOR)
	end
	return healthPercentCurve, healthColorCurve
end

oUF.Tags.Methods["sInterface:health"] = function(unit)
	if UnitIsDead(unit) then
		return hex(oUF.colors.health) .. "Dead" .. "|r"
	elseif UnitIsGhost(unit) then
		return hex(oUF.colors.ghost) .. "Ghost" .. "|r"
	elseif not UnitIsConnected(unit) then
		return hex(oUF.colors.disconnected) .. "Disconnected" .. "|r"
	end

	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	if issecret(cur) or issecret(max) then
		local percentCurve, colorCurve = GetHealthCurves()
		if not percentCurve then
			return sValue(cur)
		end
		local percent = C_StringUtil.TruncateWhenZero(UnitHealthPercent(unit, true, percentCurve))
		local text = sValue(cur) .. C_StringUtil.WrapString(percent, " | ", "%")
		return C_ColorUtil.WrapTextInColor(text, UnitHealthPercent(unit, true, colorCurve))
	end

	if (cur < max) and (cur ~= 0) then
		return (hex(oUF.colors.health) .. sValue(cur)) .. " | " .. math.floor(cur / max * 100 + .5) .. "%|r"
	else
		return (hex(0.33, 0.58, 0.33) .. sValue(cur)) .. "|r"
	end

end
oUF.Tags.Events["sInterface:health"] = "UNIT_HEALTH UNIT_CONNECTION"

oUF.Tags.Methods['sInterface:power'] = function(u)
	return oUF.Tags.Methods['powercolor'](u) .. sValue(UnitPower(u))
end
oUF.Tags.Events['sInterface:power'] = 'UNIT_POWER_UPDATE PLAYER_SPECIALIZATION_CHANGED PLAYER_TALENT_UPDATE UNIT_CONNECTION'


local ALTERNATE = (Enum and Enum.PowerType and Enum.PowerType.Alternate) or ALTERNATE_POWER_INDEX

oUF.Tags.Methods['sInterface:altpower'] = function(u)
	local cur = UnitPower(u, ALTERNATE)
	local max = UnitPowerMax(u, ALTERNATE)
	if issecret(max) then
		-- cannot test max == 0: TruncateWhenZero gives '' for 0 and WrapString then drops the whole text
		return C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(max), '|cffCDC5C2' .. sValue(cur) .. '|cffCDC5C2 / ')
	end
	if max == 0 then return end
	return ('|cffCDC5C2' .. sValue(cur)) .. ('|cffCDC5C2 / ') .. sValue(max)
end
oUF.Tags.Events['sInterface:altpower'] = 'UNIT_POWER_UPDATE UNIT_MAXPOWER'
