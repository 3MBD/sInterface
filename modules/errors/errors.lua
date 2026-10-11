local _, ns = ...
local E = ns.E

if not E:C('errors', 'enabled') then return end;

local functionality_enabled = true;

local toBlock = {
	errors = true,
	information = false,
	system = false,
	combat = false,
}

local map = {
	SYSMSG = "system",
	UI_INFO_MESSAGE = "information",
	UI_ERROR_MESSAGE = "errors",
}

-- Unregister the blocked events instead of replacing UIErrorsFrame's OnEvent script
-- (Blizzard's own /uierrorsoff does the same). Only blocked events are touched, and
-- RegisterEvent is only called again when the user toggles them back on.
local blockedEvents = {}
for event, category in next, map do
	if toBlock[category] then
		blockedEvents[#blockedEvents + 1] = event
	end
end

local function apply()
	for _, event in ipairs(blockedEvents) do
		if functionality_enabled then
			UIErrorsFrame:UnregisterEvent(event)
		else
			UIErrorsFrame:RegisterEvent(event)
		end
	end
end
apply()

local toggle_enabled = function()
	functionality_enabled = not functionality_enabled
	apply()
end

SlashCmdList["SINTERFACE_ERRORS"] = function() toggle_enabled() print("Errors shown: "..tostring(not functionality_enabled)) end
SLASH_SINTERFACE_ERRORS1 = "/errors"
