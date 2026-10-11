-- NUM_CHAT_WINDOWS only exists with the loadDeprecationFallbacks CVar
local NUM_WINDOWS = Constants.ChatFrameConstants.MaxChatWindows

-- sInterface's short message prefixes (unchanged values from the original file)
local SHORT_FORMATS = {
	--guild
	CHAT_GUILD_GET = "|Hchannel:GUILD|hG|h %s ",
	CHAT_OFFICER_GET = "|Hchannel:OFFICER|hO|h %s ",
	--raid
	CHAT_RAID_GET = "|Hchannel:RAID|hR|h %s ",
	CHAT_RAID_WARNING_GET = "RW %s ",
	CHAT_RAID_LEADER_GET = "|Hchannel:RAID|hR|h %s ",
	--party
	CHAT_PARTY_GET = "|Hchannel:PARTY|hP|h %s ",
	CHAT_PARTY_LEADER_GET =  "|Hchannel:PARTY|hP|h %s ",
	CHAT_PARTY_GUIDE_GET =  "|Hchannel:PARTY|hPG|h %s ",
	--instance
	CHAT_INSTANCE_CHAT_GET = "|Hchannel:Battleground|hI|h %s: ",
	CHAT_INSTANCE_CHAT_LEADER_GET = "|Hchannel:Battleground|hI|h %s: ",
	--whisper
	CHAT_WHISPER_INFORM_GET = "to %s ",
	CHAT_WHISPER_GET = "from %s ",
	CHAT_BN_WHISPER_INFORM_GET = "to %s ",
	CHAT_BN_WHISPER_GET = "from %s ",
	--say / yell
	CHAT_SAY_GET = "%s ",
	CHAT_YELL_GET = "%s ",
}

--flags
local SHORT_FLAGS = {
	CHAT_FLAG_AFK = "[AFK] ",
	CHAT_FLAG_DND = "[DND] ",
	CHAT_FLAG_GM = "[GM] ",
}

-- "|h[1. General - Zone]|h" -> "|h1|h"
local CHANNEL_PATTERN, CHANNEL_REPL = '|h%[(%d+)%. .-%]|h', '|h%1|h'

--[[ WoW: Forever (12.x engine):
  Writing CHAT_*_GET / CHAT_FLAG_* globals or replacing ChatFrameN.AddMessage taints Blizzard's
  ChatFrameMixin:MessageEventHandler. While C_ChatInfo.InChatMessagingLockdown() is true the
  CHAT_MSG_* payload (text, sender, GUID) is secret, and the now-tainted handler errors on its own
  secret comparisons / table keys (dropping the message, breaking /r). So nothing Blizzard-owned is
  written here. Instead, lines that are already in the frame and are NOT secret are rewritten through
  the frame's secure TransformMessages API from a hooksecurefunc post-hook. Secret lines (chat
  lockdown) keep Blizzard's default formatting. ]]

local issecretvalue = issecretvalue
local strfind, strsub, gsub = string.find, string.sub, string.gsub

local function EscapePattern(s)
	return (gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

local formatRules = {}   -- [chatType] = { pattern, replacement, leadingName }
for key, short in pairs(SHORT_FORMATS) do
	local orig = _G[key]   -- Blizzard's localized default; reading it does not taint it
	if type(orig) == "string" and orig ~= short and strfind(orig, "%s", 1, true) then
		local pattern = gsub(EscapePattern(orig), "%%%%s", "(.-)", 1)
		local repl = gsub(gsub(short, "%%", "%%%%"), "%%%%s", "%%1", 1)
		local chatType = key:match("^CHAT_(.+)_GET$")
		local leadingName = strsub(orig, 1, 2) == "%s"
		formatRules[chatType] = { (leadingName and "^" or "")..pattern, repl, leadingName }
	end
end

local flagRules = {}   -- [specialFlag] = { plain, pattern, replacement }
for key, short in pairs(SHORT_FLAGS) do
	local orig = _G[key]
	if type(orig) == "string" and orig ~= "" and orig ~= short then
		flagRules[key:match("^CHAT_FLAG_(.+)$")] = { orig, EscapePattern(orig), (gsub(short, "%%", "%%%%")) }
	end
end

-- For formats that start with the sender ("%s whispers: "), split off whatever Blizzard prepended
-- (timestamp) so the short prefix lands after it, as it did when the global was replaced.
local function SplitLead(text, flagRule)
	local first = strfind(text, "|H", 1, true)
	local p = flagRule and strfind(text, flagRule[1], 1, true)
	if p and (not first or p < first) then first = p end
	if not first or first == 1 then return "", text end
	return strsub(text, 1, first - 1), strsub(text, first)
end

local function Shorten(text, event, specialFlag)
	local out = gsub(text, CHANNEL_PATTERN, CHANNEL_REPL)
	local chatType = type(event) == "string" and strsub(event, 1, 9) == "CHAT_MSG_" and strsub(event, 10)
	local flagRule = chatType and type(specialFlag) == "string" and flagRules[specialFlag]
	local rule = chatType and formatRules[chatType]
	if rule then
		local lead, rest = "", out
		if rule[3] then lead, rest = SplitLead(out, flagRule) end
		local replaced, n = gsub(rest, rule[1], rule[2], 1)
		if n > 0 then out = lead..replaced end
	end
	if flagRule then
		out = gsub(out, flagRule[2], flagRule[3], 1)
	end
	return out
end

local function OnAddMessage(frame, text, r, g, b, infoID, accessID, typeID, event, eventArgs)
	if issecretvalue(text) or issecretvalue(event) or type(text) ~= "string" then return end
	local specialFlag = type(eventArgs) == "table" and eventArgs[6] or nil
	if issecretvalue(specialFlag) then specialFlag = nil end
	local short = Shorten(text, event, specialFlag)
	if short == text then return end
	local done = false
	frame:TransformMessages(function(message)
		if done or issecretvalue(message) or message ~= text then return false end
		done = true
		return true
	end, function(_, ...)
		return short, ...
	end)
end

for i = 1, NUM_WINDOWS do
	if ( i ~= 2 ) then
		local f = _G["ChatFrame"..i]
		if f and f.TransformMessages then
			hooksecurefunc(f, "AddMessage", OnAddMessage)
		end
	end
end
