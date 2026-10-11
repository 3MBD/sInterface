local _, ns = ...
local oUF = ns.oUF or oUF

--[[
oUF_GCD - Global Cooldown timer for oUF
by Exactly of Turalyon (us)


Example

	self.GCD = CreateFrame('Frame', nil, self)
	self.GCD:SetPoint('BOTTOMLEFT', self.Title, 'BOTTOMLEFT')
	self.GCD:SetPoint('BOTTOMRIGHT', self.Title, 'BOTTOMRIGHT')
	self.GCD:SetHeight(2)

	self.GCD.Spark = self.GCD:CreateTexture(nil, "OVERLAY")
	self.GCD.Spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	self.GCD.Spark:SetBlendMode("ADD")
	self.GCD.Spark:SetHeight(10)
	self.GCD.Spark:SetWidth(10)
	self.GCD.Spark:SetPoint('BOTTOMLEFT', self.Title, 'BOTTOMLEFT', -5, -5)

The global cooldown is read from the dedicated "Global Cooldown" spell (61304), the same
spell oUF's own castbar uses (embeds/oUF/elements/castbar.lua:91), so no per-class reference
spell or spellbook scan is needed any more (GetNumSpellTabs/GetSpellTabInfo/GetSpellInfo/
GetSpellCooldown/BOOKTYPE_SPELL no longer exist on this client).
--]]

local GCD_SPELL_ID = 61304
local GetTime = GetTime
local issecret = issecretvalue or function() return false end

local function GetGCDInfo()
	return C_Spell.GetSpellCooldown(GCD_SPELL_ID)
end

-- Plain-number path (unchanged maths from the original plugin).
local OnUpdateGCD = function(self)
	self.Spark:ClearAllPoints()
	local perc = (GetTime() - self.starttime) / self.duration
	if perc > 1 then
		self:Hide()
		return
	else
		self.Spark:SetPoint('CENTER', self, 'LEFT', self:GetWidth() * perc, 0)
	end
end

-- Secret path: the client advances an invisible timer bar from a duration object and the spark
-- follows its fill edge; we only poll the never-secret isActive flag to know when to hide.
local OnUpdateGCDTimer = function(self)
	local info = GetGCDInfo()
	if not (info and info.isActive) then
		self:Hide()
	end
end

local function GetTimerBar(element)
	local bar = element.__gcdTimer
	if not bar then
		bar = CreateFrame('StatusBar', nil, element)
		bar:SetAllPoints(element)
		bar:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8')
		bar:GetStatusBarTexture():SetAlpha(0)
		bar:SetMinMaxValues(0, 1)
		element.__gcdTimer = bar
	end
	return bar
end

local OnHideGCD = function(self)
	self:SetScript('OnUpdate', nil)
	self.drawing = false
end

local OnShowGCD = function(self)
	self:SetScript('OnUpdate', self.__secretTimer and OnUpdateGCDTimer or OnUpdateGCD)
end

local Update = function(self, event, unit)
	local element = self.GCD
	if not element then return end

	local info = GetGCDInfo()
	-- isActive is NeverSecret (SpellSharedDocumentation.lua SpellCooldownInfo)
	if not (info and info.isActive) then
		element:Hide()
		return
	end

	local start, dur = info.startTime, info.duration
	if not issecret(start) and not issecret(dur) then
		element.__secretTimer = nil
		if element.__gcdTimer then element.__gcdTimer:Hide() end
		if dur == 0 then
			element:Hide()
		else
			element.starttime = start
			element.duration = dur
			element:Show()
			element:SetScript('OnUpdate', OnUpdateGCD)
		end
	else
		-- may return nothing; the duration object itself can carry secret values
		local duration = C_Spell.GetSpellCooldownDuration and C_Spell.GetSpellCooldownDuration(GCD_SPELL_ID)
		if not (duration and Enum.StatusBarTimerDirection) then
			element:Hide()
			return
		end

		local bar = GetTimerBar(element)
		bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, Enum.StatusBarTimerDirection.ElapsedTime)
		bar:Show()
		element.Spark:ClearAllPoints()
		element.Spark:SetPoint('CENTER', bar:GetStatusBarTexture(), 'RIGHT', 0, 0)
		element.__secretTimer = true
		element:Show()
		element:SetScript('OnUpdate', OnUpdateGCDTimer)
	end
end

local Enable = function(self)
	if (self.GCD) then
		self.GCD:Hide()
		self.GCD.drawing = false
		self.GCD.starttime = 0
		self.GCD.duration = 0

		self:RegisterEvent('ACTIONBAR_UPDATE_COOLDOWN', Update, true)
		self:RegisterEvent('SPELL_UPDATE_COOLDOWN', Update, true)
		self.GCD:SetScript('OnHide', OnHideGCD)
		self.GCD:SetScript('OnShow', OnShowGCD)
	end
end

local Disable = function(self)
	if (self.GCD) then
		self:UnregisterEvent('ACTIONBAR_UPDATE_COOLDOWN', Update)
		self:UnregisterEvent('SPELL_UPDATE_COOLDOWN', Update)
		self.GCD:Hide()
	end
end

oUF:AddElement('GCD', Update, Enable, Disable)
