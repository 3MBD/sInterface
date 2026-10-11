local _, ns = ...
local E = ns.E

if not E:C('progressbars', 'enabled') then return end;

local ProgressBars = ns.sInterfaceProgressBars
local barName = "reputation"

local PARAGON = PARAGON or "Paragon"
local PARAGON_REACTION = MAX_REPUTATION_REACTION + 1

local reactions = {}

for eclass, color in next, FACTION_BAR_COLORS do
	reactions[eclass] = {color.r, color.g, color.b}
end
-- Paragon
reactions[PARAGON_REACTION] = {0, 0.5, 0.9}

-- GetWatchedFactionInfo was removed; the watched faction is a FactionData table
local function GetWatchedFaction()
	local data = C_Reputation.GetWatchedFactionData()
	if data and data.factionID and data.factionID ~= 0 then
		return data
	end
end

local function GetReputation()
	local data = GetWatchedFaction()
	if not data then return end

	local pendingReward, standingText
	local name, standingID, factionID = data.name, data.reaction, data.factionID
	local min, max, cur = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding

	-- GetFriendshipReputation(id) -> C_GossipInfo.GetFriendshipReputation(id) (table)
	local friendship = C_GossipInfo.GetFriendshipReputation(factionID)
	if (friendship and friendship.friendshipFactionID and friendship.friendshipFactionID > 0) then
		standingText = friendship.reaction
		if (friendship.nextThreshold) then
			min, max, cur = friendship.reactionThreshold, friendship.nextThreshold, friendship.standing
		else
			min, max, cur = 0, 1, 1 -- force a full bar when maxed out
		end
		standingID = 5 -- force friends' color
	elseif C_Reputation.IsMajorFaction and C_Reputation.IsMajorFaction(factionID) and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
		-- renown factions: Blizzard shows renown progress on a blue bar
		local major = C_MajorFactions.GetMajorFactionData(factionID)
		if major then
			min, max, cur = 0, major.renownLevelThreshold, major.renownReputationEarned
			standingText = RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(major.renownLevel) or tostring(major.renownLevel)
		end
		standingID = PARAGON_REACTION
	else
		local isParagon = true
		if C_Reputation.IsFactionParagonForCurrentPlayer then
			isParagon = C_Reputation.IsFactionParagonForCurrentPlayer(factionID)
		end
		local value, paragonNextThreshold, _, hasRewardPending
		if isParagon then
			value, paragonNextThreshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)
		end
		if (value and paragonNextThreshold and paragonNextThreshold > 0) then
			cur = value % paragonNextThreshold
			min = 0
			max = paragonNextThreshold
			pendingReward = hasRewardPending
			standingID = PARAGON_REACTION -- force paragon's color
			standingText = PARAGON
		end
	end

	max = max - min
	cur = cur - min
	-- cur and max are both 0 for maxed out factions
	if(cur == max) then
		cur, max = 1, 1
	end
	if (not standingText) and standingID >= 1 and standingID <= MAX_REPUTATION_REACTION then
		standingText = GetText('FACTION_STANDING_LABEL' .. standingID, UnitSex('player'))
	end

	return cur, max, name, factionID, standingID, standingText, pendingReward
end

local function Update(bar)
	local cur, max, name, _, standingID = GetReputation()
	if (name) then
		bar:SetAnimatedValues(cur, 0, max, standingID)
		local colors = reactions[standingID] or reactions[PARAGON_REACTION]
		bar:SetStatusBarColor(colors[1], colors[2], colors[3])
	end
end

local function Disable(bar)
	bar:UnregisterEvent("UPDATE_FACTION")
end

local function Enable(bar)
	bar:RegisterEvent("UPDATE_FACTION")
	Update(bar)
end

local function reputationVisibility(self)
	if (GetWatchedFaction()) then
		Enable(self.Reputation)
		ProgressBars:EnableBar(barName)
	else
		Disable(self.Reputation)
		ProgressBars:DisableBar(barName)
	end
end

local reputationHolder = ProgressBars:CreateBar(barName)
reputationHolder:SetHeight(E:C('progressbars', 'reputation', 'height'))
reputationHolder:SetScript("OnEvent", reputationVisibility)
-- the watched faction now changes through C_Reputation (Blizzard reads
-- GetWatchedFactionData right after either setter); UPDATE_FACTION covers server changes
reputationHolder:RegisterEvent("UPDATE_FACTION")
for _, setter in ipairs({ "SetWatchedFactionByIndex", "SetWatchedFactionByID" }) do
	if C_Reputation[setter] then
		hooksecurefunc(C_Reputation, setter, function()
			reputationVisibility(reputationHolder)
		end)
	end
end

local reputation = CreateFrame("StatusBar", "ProgressBar", reputationHolder, "AnimatedStatusBarTemplate")
reputation:SetMatchBarValueToAnimation(true)
reputation:SetAllPoints(reputationHolder)
reputation:SetStatusBarTexture(E:C('general', 'texture'))
reputation:GetStatusBarTexture():SetDrawLayer("ARTWORK")
reputation:SetScript("OnEvent", Update)
reputationHolder.Reputation = reputation
C_Timer.After(1, function()
	reputationVisibility(reputationHolder)
end)

local tooltip = GameTooltip
reputationHolder:SetScript("OnEnter", function(self)
	local cur, max, name, _, _, standingText = GetReputation()
	if not name then return end
	tooltip:SetOwner(self, "ANCHOR_CURSOR")
	tooltip:ClearLines()
	tooltip:AddLine(name)
	tooltip:AddDoubleLine("Standing", standingText, 1, 1, 1)
	tooltip:AddDoubleLine("Current", E:CommaValue(cur), 1, 1, 1)
	tooltip:AddDoubleLine("Required", E:CommaValue(max), 1, 1, 1)
	tooltip:AddDoubleLine("To level", E:CommaValue((max-cur)), 1, 1, 1)

	tooltip:Show()
end)
reputationHolder:SetScript("OnLeave", function(self)
	tooltip:Hide()
end)
