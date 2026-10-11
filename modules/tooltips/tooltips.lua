local _, ns = ...
local E = ns.E

if not E:C('tooltips', 'enabled') then return end

local unpack, type = unpack, type
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local GameTooltip = GameTooltip
local issecretvalue = issecretvalue or function() return false end

-- Unit names, races, creature types and tooltip lines can be secret values on
-- WoW: Forever (always for NPCs). Lines built from them are left as Blizzard wrote them.
local function anySecret(...)
	for i = 1, select('#', ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

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
	local focus = GetMouseFoci()[1]
	if focus and focus.GetAttribute then
		return focus:GetAttribute("unit")
	end
end

local function OnTooltipSetUnit(self, ...)
	local unit = select(2, self:GetUnit()) or GetMouseFocusUnit() or (UnitExists("mouseover") and "mouseover")
	if not unit or issecretvalue(unit) then return end
	local line = 1
	if UnitIsPlayer(unit) then
		local name, realm = UnitName(unit)
		local _, unitClass = UnitClass(unit)
		if anySecret(name, realm, unitClass) then return end
		local classColor = RAID_CLASS_COLORS[unitClass]
		if not classColor then return end

		if realm then
			left[line]:SetFormattedText("|cff%02x%02x%02x%s %s %s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name, 'of', realm)
		else
			left[line]:SetFormattedText("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, name)
		end
		line = line + 1

		local guild = GetGuildInfo(unit)
		if guild and not issecretvalue(guild) and left[line] then
			left[line]:SetFormattedText('|cff%02x%02x%02x%s|r', 255, 213, 131, guild)
			line = line + 1
		end

		local level, race = UnitLevel(unit), UnitRace(unit)
		if anySecret(level, race) or not left[line] then return end
		local difficultyColor
		level = level > 0 and level or '??'
		if level == '??' then
			difficultyColor = { r = 0.69, g = 0.69, b = 0.69 }
		else
			difficultyColor = GetQuestDifficultyColor(level)
		end

		left[line]:SetFormattedText('|cff%02x%02x%02x%s|r %s', difficultyColor.r * 255, difficultyColor.g * 255, difficultyColor.b * 255, level, race)
	else
		local name = UnitName(unit)
		left[line]:SetText(name)
		line = line + 1

		local info = left[line] and left[line]:GetText()
		if not info then return GameTooltip:Show() end
		if issecretvalue(info) then return end

		if not strmatch(info, "Level") and not strmatch(info, "Pet Level") then
			line = line + 1
		end

		local level, race = UnitLevel(unit), UnitCreatureType(unit)
		if anySecret(level, race) or not left[line] then return end
		level = level == -1 and '??' or level
		local color = type(level) == 'number' and GetQuestDifficultyColor(level) or { r = 1, g = 0.5, b = 0.5 }
		if level and race then
			left[line]:SetFormattedText('|cff%02x%02x%02x%s|r %s', color.r * 255, color.g * 255, color.b * 255, level, race)
		end
	end
end

-- OnTooltipSetUnit was replaced by tooltip data post-calls in 10.0.2
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, ...)
	if tooltip ~= GameTooltip then return end
	OnTooltipSetUnit(tooltip, ...)
end)


-- ShoppingTooltip3, WorldMapTooltip and SmallTextTooltip no longer exist
local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }

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
		tooltip.NineSlice:Hide()
	end

	SetBackdropStyle(tooltip)
end

-- Blizzard re-shows the default border whenever a tooltip's style is (re)applied
hooksecurefunc("SharedTooltip_SetBackdropStyle", function(tooltip)
	if tooltip.style and tooltip.NineSlice then
		tooltip.NineSlice:Hide()
	end
end)
