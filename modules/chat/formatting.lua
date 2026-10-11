-- Chat lines can be secret values on WoW: Forever (dungeons, raids, encounters, PvP). Blizzard
-- builds them from the CHAT_*_GET format strings, so replacing those globals would taint that code
-- and break secret lines. Instead each finished, non-secret line is rewritten afterwards through the
-- chat frame's secure TransformMessages; secret lines keep the default format.
local issecretvalue = issecretvalue or function() return false end

local formats = {
	--guild
	GUILD = "|Hchannel:GUILD|hG|h %s ",
	OFFICER = "|Hchannel:OFFICER|hO|h %s ",

	--raid
	RAID = "|Hchannel:RAID|hR|h %s ",
	RAID_WARNING = "RW %s ",
	RAID_LEADER = "|Hchannel:RAID|hR|h %s ",

	--party
	PARTY = "|Hchannel:PARTY|hP|h %s ",
	PARTY_LEADER =  "|Hchannel:PARTY|hP|h %s ",
	PARTY_GUIDE =  "|Hchannel:PARTY|hPG|h %s ",

	--instance
	INSTANCE_CHAT = "|Hchannel:Battleground|hI|h %s: ",
	INSTANCE_CHAT_LEADER = "|Hchannel:Battleground|hI|h %s: ",

	--whisper
	WHISPER_INFORM = "to %s ",
	WHISPER = "from %s ",
	BN_WHISPER_INFORM = "to %s ",
	BN_WHISPER = "from %s ",

	--say / yell
	SAY = "%s ",
	YELL = "%s ",
}

--flags
local flags = {
	AFK = "[AFK] ",
	DND = "[DND] ",
	GM = "[GM] ",
}

local function toPattern(text)
	return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Blizzard's own format strings, read but never written, matched as patterns
local prefixes = {}
for chatType, format in pairs(formats) do
	local default = _G["CHAT_"..chatType.."_GET"]
	if type(default) == "string" and default:find("%s", 1, true) then
		prefixes[chatType] = {
			pattern = (toPattern(default):gsub("%%%%s", "(.-)", 1)),
			format = format,
		}
	end
end

local flagPatterns = {}
for flag, short in pairs(flags) do
	local default = _G["CHAT_FLAG_"..flag]
	if type(default) == "string" and default ~= "" then
		flagPatterns[toPattern(default)] = short
	end
end

-- marks lines that have been looked at so each line is rewritten at most once
local processed = {}

local function shouldTransform(message, ...)
	if issecretvalue(message) or type(message) ~= "string" then return false end
	local n = select('#', ...)
	if n > 0 then
		local last = select(n, ...)
		if not issecretvalue(last) and last == processed then return false end
	end
	return true
end

-- Blizzard puts the optional timestamp in front of the formatted line
local function timestampLength()
	local timestampFormat = ChatFrameUtil.GetTimestampFormat()
	return timestampFormat and #TimeUtil.BetterDate(timestampFormat, time()) or 0
end

-- extra values are the ones ChatFrame passes to AddMessage: id, accessID, typeID, event, ...
local function transform(message, r, g, b, ...)
	local event = select(4, ...)
	local chatType = type(event) == "string" and not issecretvalue(event) and event:match("^CHAT_MSG_(.+)")
	local prefix = chatType and prefixes[chatType]
	if prefix then
		local s, e, name = message:find(prefix.pattern, timestampLength() + 1)
		if s then
			for pattern, short in pairs(flagPatterns) do
				name = name:gsub(pattern, short)
			end
			message = message:sub(1, s - 1) .. prefix.format:format(name) .. message:sub(e + 1)
		end
	end

	message = message:gsub('|h%[(%d+)%. .-%]|h', '|h%1|h')
	return message, r, g, b, ...
end

local function transformWithMarker(message, r, g, b, ...)
	local n = select('#', ...)
	local extra = { ... }
	extra[n + 1] = processed
	return transform(message, r, g, b, unpack(extra, 1, n + 1))
end

for i = 1, NUM_CHAT_WINDOWS do
	if ( i ~= 2 ) then
		local f = _G["ChatFrame"..i]
		hooksecurefunc(f, "AddMessage", function(frame)
			frame:TransformMessages(shouldTransform, transformWithMarker)
		end)
	end
end
