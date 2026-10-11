-- Diagnostics: records Lua errors that involve sInterface so they can be copied out of the game
-- with /sierr, also after a /reload (they are kept in the SavedVariable sInterface_ErrorLog).
--
-- Every error is still passed to the previous error handler, so the normal error display is
-- unchanged. The one difference: an sInterface error message that was already shown once is only
-- counted afterwards, so a repeating error does not bury the screen in popups. Nothing is hidden;
-- /sierr lists every distinct error with its count.

local ADDON = ...

local MAX_ENTRIES = 40
local MAX_STACK = 700

local current, byMessage = {}, {}

local function record(message)
	local entry = byMessage[message]
	if entry then
		entry.count = entry.count + 1
		return false
	end

	if #current >= MAX_ENTRIES then return true end

	local stack
	if debugstack then
		local ok, text = pcall(debugstack, 3, 8, 0)
		if ok and type(text) == "string" then stack = text:sub(1, MAX_STACK) end
	end

	entry = { message = message, count = 1, stack = stack }
	byMessage[message] = entry
	current[#current + 1] = entry
	return true
end

local previousHandler = geterrorhandler()
seterrorhandler(function(message)
	local show = true
	local ok, text = pcall(tostring, message)
	if ok and text:find("sInterface", 1, true) then
		local recorded, result = pcall(record, text)
		if recorded then show = result end
	end

	if show and previousHandler then
		return previousHandler(message)
	end
end)

local previous = {}

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
	if name ~= ADDON then return end
	self:UnregisterEvent("ADDON_LOADED")

	-- SavedVariables exist now: keep last session's errors and store this session's
	local saved = sInterface_ErrorLog
	previous = (type(saved) == "table" and type(saved.current) == "table") and saved.current or {}
	sInterface_ErrorLog = { current = current }
end)

local function format(title, entries, lines)
	lines[#lines + 1] = title .. " (" .. #entries .. " distinct)"
	for _, entry in ipairs(entries) do
		lines[#lines + 1] = "[" .. entry.count .. "x] " .. tostring(entry.message)
		if entry.stack and entry.stack ~= "" then
			lines[#lines + 1] = entry.stack
		end
	end
	lines[#lines + 1] = ""
end

local window
local function ShowLog()
	if not window then
		window = CreateFrame("Frame", "sInterfaceErrorLog", UIParent, BackdropTemplateMixin and "BackdropTemplate")
		window:SetSize(760, 520)
		window:SetPoint("CENTER")
		window:SetFrameStrata("DIALOG")
		window:SetBackdrop({
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeSize = 1,
		})
		window:SetBackdropColor(0, 0, 0, 0.92)
		window:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
		window:EnableMouse(true)
		window:SetMovable(true)
		window:RegisterForDrag("LeftButton")
		window:SetScript("OnDragStart", window.StartMoving)
		window:SetScript("OnDragStop", window.StopMovingOrSizing)

		local hint = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		hint:SetPoint("TOPLEFT", 10, -8)
		hint:SetText("sInterface errors: click in the box, Ctrl+A, Ctrl+C, then paste it where you send it. Esc closes.")

		local box = CreateFrame("EditBox", nil, window)
		box:SetMultiLine(true)
		box:SetAutoFocus(false)
		box:SetFontObject("GameFontHighlightSmall")
		box:SetPoint("TOPLEFT", 10, -30)
		box:SetPoint("BOTTOMRIGHT", -10, 10)
		box:SetScript("OnEscapePressed", function() window:Hide() end)
		window.box = box

		tinsert(UISpecialFrames, "sInterfaceErrorLog")
	end

	local lines = {}
	format("This session", current, lines)
	if #previous > 0 then
		format("Before the last reload or login", previous, lines)
	end
	if #current == 0 and #previous == 0 then
		lines = { "No sInterface errors have been recorded." }
	end

	local text = table.concat(lines, "\n")
	-- the edit box has no scroll bar: keep what fits the window
	window.box:SetText(text:sub(1, 3800))
	window:Show()
end

SLASH_SINTERFACEERRORS1 = "/sierr"
SlashCmdList["SINTERFACEERRORS"] = function(argument)
	if argument and argument:lower() == "clear" then
		wipe(current)
		wipe(byMessage)
		wipe(previous)
		print("sInterface: error log cleared")
	else
		ShowLog()
	end
end
