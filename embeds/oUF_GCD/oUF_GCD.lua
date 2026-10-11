local _, ns = ...
local cfg = ns.cfg
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

	self.GCD.ReferenceSpellName = '***SEE BELOW***'

You have to set a reference spell. You should choose one that has no cooldown
except the global cooldown, and that cant be interrupted or silenced -- and
it has to be one that's in your spellbook.

Alternatively, you can add spells to the "referenceSpells" block at the top of
this file and the addon will automatically choose the first one that you know. I'll add
more spells to the list as I figure out what they are. For now, you can just add more
spells to the list -- it doesnt matter where.

Enjoy!
--]]

local referenceSpells = {}
referenceSpells["DEATHKNIGHT"] = 49998
referenceSpells["DEMONHUNTER"] = 162243
referenceSpells["DRUID"] = 5176
referenceSpells["HUNTER"] = 193455
referenceSpells["MAGE"] = 30449
referenceSpells["MONK"] = 100780
referenceSpells["PALADIN"] = 85256
referenceSpells["PRIEST"] = 589
referenceSpells["ROGUE"] = 53
referenceSpells["SHAMAN"] = 192106
referenceSpells["WARLOCK"] = 686
referenceSpells["WARRIOR"] = 5308

local spellId
local hasInitialized = false
local GetTime = GetTime
local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local GetSpellCooldown = GetSpellCooldown

local Init = function()
	local FindInSpellbook = function(spellId)
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, numSpells = GetSpellTabInfo(tab)
			for i = (offset + 1), (offset + numSpells) do
				local _, _, _, _, _, _, _spellId = GetSpellInfo(i, BOOKTYPE_SPELL)
				if not (_spellId == nil) and (spellId == _spellId) then
					return true
				end
			end
		end
		return false
	end

	local _, englishClass = UnitClass("player")
	local _, _, _, _, _, _, _spellId = GetSpellInfo(referenceSpells[englishClass])

	local found = false
	if FindInSpellbook(_spellId) then
		spellId = _spellId
		found = true
	else
		print("oUF_GCD could not find spellId", _spellId, "for class", englishClass)
	end

	hasInitialized = true
	return found
end


local OnUpdateGCD
do
	OnUpdateGCD = function(self)
		self.Spark:ClearAllPoints()
		local perc = (GetTime() - self.starttime) / self.duration
		if perc > 1 then
			self:Hide()
			return
		else
			self.Spark:SetPoint('CENTER', self, 'LEFT', self:GetWidth() * perc, 0)
		end
	end
end

local OnHideGCD = function(self)
	self:SetScript('OnUpdate', nil)
	self.drawing = false
end

local OnShowGCD = function(self)
	self:SetScript('OnUpdate', OnUpdateGCD)
end

local Update = function(self, event, unit)
	if self.GCD then
		if spellId == nil then
			if hasInitialized or not Init() then
				return
			end
		end

		local start, dur = GetSpellCooldown(spellId)

		if (not start) then return end
		if (not dur) then dur = 0 end

		if (dur == 0) then
			self.GCD:Hide()
		else
			self.GCD.starttime = start
			self.GCD.duration = dur
			self.GCD:Show()
		end
	end
end

local Enable = function(self)
	if (self.GCD) then
		self.GCD:Hide()
		self.GCD.drawing = false
		self.GCD.starttime = 0
		self.GCD.duration = 0

		self:RegisterEvent('ACTIONBAR_UPDATE_COOLDOWN', Update, true)
		self.GCD:SetScript('OnHide', OnHideGCD)
		self.GCD:SetScript('OnShow', OnShowGCD)
	end
end

local Disable = function(self)
	if (self.GCD) then
		self:UnregisterEvent('ACTIONBAR_UPDATE_COOLDOWN')
		self.GCD:Hide()
	end
end

oUF:AddElement('GCD', Update, Enable, Disable)
