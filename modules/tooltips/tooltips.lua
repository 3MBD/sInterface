local _, ns = ...
local E = ns.E

if not E:C('tooltips', 'enabled') then return end

local unpack, type = unpack, type
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local GameTooltip = GameTooltip
-- secret values exist only on the 12.x engine; elsewhere nothing is ever secret
local issecretvalue = issecretvalue or function() return false end

GameTooltipStatusBar:ClearAllPoints()
GameTooltipStatusBar:Hide()

local bgColor = { 0.03, 0.03, 0.03, 0.8 }
local backdrop = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	tiled = false, edgeSize = 0,
	insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function SetBackdropStyle(self)
	if (self.SetBackdrop) then
		self:SetBackdrop(nil)
	end

	if not self.style then return end

	self.style:SetBackdrop(backdrop)
	self.style:SetBackdropBorderColor(1, 1, 1, 0)
	self.style:SetBackdropColor(unpack(bgColor))
end

local function anchor_to_cursor(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_CURSOR")
end

local function anchor_to_coords(tooltip, parent)
	tooltip:SetOwner(parent, "ANCHOR_NONE")
	tooltip:ClearAllPoints()
	tooltip:SetClampedToScreen(true)
	tooltip:SetPoint(unpack(E:C('tooltips', 'pos')))
end

local anchor_cursor = E:C("tooltips", "anchor_cursor")

if anchor_cursor then
	hooksecurefunc("GameTooltip_SetDefaultAnchor", anchor_to_cursor)
else
	hooksecurefunc("GameTooltip_SetDefaultAnchor", anchor_to_coords)
end

local left = setmetatable({}, { __index = function(left, i)
	local line = _G["GameTooltipTextLeft" .. i]
	if line then rawset(left, i, line) end
	return line
end })

local function GetMouseFocusUnit()
	-- GetMouseFocus was replaced by GetMouseFoci
	local focus = GetMouseFoci()[1]
	if focus and not focus:IsForbidden() and focus.GetAttribute then
		local unit = focus:GetAttribute("unit")
		if not issecretvalue(unit) and type(unit) == "string" then
			return unit
		end
	end
end

-- Never boolean-test / compare a value before issecretvalue() has cleared it.
local function GetTooltipUnit(data)
	local unit
	-- tooltipData.guid may be secret (unit identity); do not call tooltip:GetUnit() here,
	-- TooltipUtil.GetDisplayedUnit boolean-tests guid/unit in our tainted execution
	local guid = data and data.guid
	if not issecretvalue(guid) and guid then
		unit = UnitTokenFromGUID(guid)
	end
	if issecretvalue(unit) or not unit then
		unit = GetMouseFocusUnit() or (UnitExists("mouseover") and "mouseover") or nil
	end
	return unit
end

local UNIT_LEVEL_LINE = Enum.TooltipDataLineType.UnitLevel

local function FindLevelLine(data)
	if not (data and data.lines) then return end
	for _, lineData in ipairs(data.lines) do
		local lineType, lineIndex = lineData.type, lineData.lineIndex
		if not issecretvalue(lineType) and lineType == UNIT_LEVEL_LINE
			and not issecretvalue(lineIndex) and type(lineIndex) == "number" then
			return lineIndex
		end
	end
end

local function OnTooltipSetUnit(self, data)
	local unit = GetTooltipUnit(data)
	if not unit then return end
	local numLines = self:NumLines()
	local line = 1
	if UnitIsPlayer(unit) then
		local name, realm = UnitName(unit)
		-- WoW: Forever returns the character's surname where the realm used to be; show the
		-- client's own "name surname" display name instead of "name of surname"
		if NameUtil and NameUtil.FormatUnitNameForDisplay then
			name, realm = NameUtil.FormatUnitNameForDisplay(unit), nil
		end
		local _, unitClass = UnitClass(unit)
		local classColor = (not issecretvalue(unitClass)) and unitClass and RAID_CLASS_COLORS[unitClass]

		if classColor then
			if issecretvalue(realm) or realm then
				left[line]:SetFormattedText("|cff%02x%02x%02x%s %s %s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name, 'of', realm)
			else
				left[line]:SetFormattedText("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
			end
		end
		line = line + 1

		local guild = GetGuildInfo(unit)
		if (issecretvalue(guild) or guild) and line <= numLines then
			left[line]:SetFormattedText('|cff%02x%02x%02x%s|r', 255, 213, 131, guild)
			line = line + 1
		end

		local level, race = UnitLevel(unit), UnitRace(unit)
		if issecretvalue(level) or line > numLines then return end
		local difficultyColor
		level = level > 0 and level or '??'
		if level == '??' then
			difficultyColor = { r = 0.69, g = 0.69, b = 0.69 }
		else
			difficultyColor = GetQuestDifficultyColor(level)
		end
		if not issecretvalue(race) and race == nil then race = "" end

		left[line]:SetFormattedText('|cff%02x%02x%02x%s|r %s', difficultyColor.r * 255, difficultyColor.g * 255, difficultyColor.b * 255, level, race)
	else
		local name = UnitName(unit)
		left[line]:SetText(name)
		line = line + 1

		local levelLine = FindLevelLine(data)
		if levelLine and levelLine > 1 then
			line = levelLine
		else
			if line > numLines then return end
			local info = left[line]:GetText()
			if issecretvalue(info) then return end -- cannot inspect; Blizzard's line stays as rendered
			-- the post-call runs before Blizzard shows the tooltip, so it is not shown here
			if not info then return end

			if not strmatch(info, "Level") and not strmatch(info, "Pet Level") then
				line = line + 1
			end
		end
		if line > numLines then return end

		local level, race = UnitLevel(unit), UnitCreatureType(unit)
		if issecretvalue(level) then return end
		level = level == -1 and '??' or level
		local color = type(level) == 'number' and GetQuestDifficultyColor(level) or { r = 1, g = 0.5, b = 0.5 }
		if level and (issecretvalue(race) or race) then
			left[line]:SetFormattedText('|cff%02x%02x%02x%s|r %s', color.r * 255, color.g * 255, color.b * 255, level, race)
		end
	end
end

-- OnTooltipSetUnit no longer fires: unit tooltips are built in Lua by TooltipDataHandlerMixin.
-- ProcessInfo calls tooltip:Show() itself right after the post-calls.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
	if tooltip ~= GameTooltip then return end
	OnTooltipSetUnit(tooltip, data)
end)


local tooltips = {}
for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3", "WorldMapTooltip", "SmallTextTooltip" }) do
	if _G[name] then tooltips[#tooltips + 1] = _G[name] end
end

for _, tooltip in ipairs(tooltips) do
	tooltip.style = CreateFrame("Frame", nil, tooltip, BackdropTemplateMixin and "BackdropTemplate" or nil)
	tooltip.style:SetFrameLevel(tooltip:GetFrameLevel())
	tooltip.style:SetAllPoints()

	if (tooltip == GameTooltip) then
		tooltip.GetBackdrop = function(self) return self.style:GetBackdrop() end
		tooltip.GetBackdropColor = function(self) return self.style:GetBackdropColor() end
		tooltip.GetBackdropBorderColor = function(self) return self.style:GetBackdropBorderColor() end
	end

	if (tooltip.style and tooltip.NineSlice) then
		-- SharedTooltip_SetBackdropStyle re-Shows NineSlice on every hide/restyle; Blizzard never
		-- changes its alpha, so alpha 0 keeps it invisible (no blinking) without replacing a
		-- Blizzard method (the old NineSlice.Show override tainted GameTooltip_OnHide).
		tooltip.NineSlice:Hide()
		tooltip.NineSlice:SetAlpha(0)
	end

	SetBackdropStyle(tooltip)
end
