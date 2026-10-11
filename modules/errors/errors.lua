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

-- Blocked message types are unregistered from UIErrorsFrame instead of wrapping its OnEvent
-- script: a replaced script would run Blizzard's handler from addon (tainted) code.
local function apply()
	for event, category in next, map do
		if toBlock[category] and functionality_enabled then
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

SlashCmdList["TOGGLE"] = function() toggle_enabled() print("Errors shown: "..tostring(not functionality_enabled)) end
SLASH_TOGGLE1 = "/errors"
