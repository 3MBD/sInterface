local _, ns = ...
local oUF = ns.oUF or oUF
assert(oUF, 'oUF not loaded')

-- The combat log payload is no longer readable by addons on this client
-- (CombatLogGetCurrentEventInfo maps to a function that only exists in C_CombatLogSecure,
-- Environment = "SecureOnly"), so trinket use is tracked through the arena crowd-control API
-- Blizzard's own arena frames use: C_PvP.GetArenaCrowdControlDuration returns a duration object
-- that can drive a Cooldown frame even when its values are secret.

local GetTrinketIcon = function(unit)
	if UnitFactionGroup(unit) == "Horde" then
		return "Interface\\Icons\\INV_Jewelry_TrinketPVP_02"
	else
		return "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
	end
end

local function UpdateCooldown(self)
	local element = self.Trinket
	local unit = self.__unit
	if not (unit and C_PvP and C_PvP.GetArenaCrowdControlDuration) then return end

	local duration = C_PvP.GetArenaCrowdControlDuration(unit)
	if duration then
		element.cooldownFrame:SetCooldownFromDurationObject(duration, true)
	else
		element.cooldownFrame:Clear()
	end
end

local Update = function(self, event, ...)
	local element = self.Trinket
	local _, instanceType = IsInInstance();
	if instanceType ~= 'arena' then
		element:Hide();
		return;
	else
		element:Show();
	end

	if(element.PreUpdate) then element:PreUpdate(event) end

	if event == "ARENA_OPPONENT_UPDATE" then
		local unit, type = ...
		if unit == self.__unit and type == "seen" then
			if UnitExists(unit) and UnitIsPlayer(unit) then
				element.Icon:SetTexture(GetTrinketIcon(unit))
			end
			if C_PvP and C_PvP.RequestCrowdControlSpell then
				C_PvP.RequestCrowdControlSpell(unit)
			end
		end
	elseif event == 'PLAYER_ENTERING_WORLD' then
		element.cooldownFrame:Clear()
	end

	UpdateCooldown(self)

	if(element.PostUpdate) then element:PostUpdate(event) end
end

local Enable = function(self)
	if self.Trinket then
		self:RegisterEvent("ARENA_OPPONENT_UPDATE", Update, true)
		self:RegisterEvent("PLAYER_ENTERING_WORLD", Update, true)
		-- ARENA_COOLDOWNS_UPDATE is registered unit-less by Blizzard (Deprecated_ArenaUI.lua:188);
		-- ARENA_CROWD_CONTROL_SPELL_UPDATE is a unit event whose payload can be secret, so let the
		-- client filter it by unit and never read the payload.
		self:RegisterEvent("ARENA_COOLDOWNS_UPDATE", Update, true)
		self:RegisterEvent("ARENA_CROWD_CONTROL_SPELL_UPDATE", Update)

		if not self.Trinket.cooldownFrame then
			self.Trinket.cooldownFrame = CreateFrame("Cooldown", nil, self.Trinket, "CooldownFrameTemplate")
			self.Trinket.cooldownFrame:SetAllPoints(self.Trinket)
			self.Trinket.cooldownFrame:SetHideCountdownNumbers(true)
		end

		if not self.Trinket.Icon then
			self.Trinket.Icon = self.Trinket:CreateTexture(nil, "BORDER")
			self.Trinket.Icon:SetAllPoints(self.Trinket)
			self.Trinket.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
			self.Trinket.Icon:SetTexture(GetTrinketIcon('player'))
		end

		return true
	end
end

local Disable = function(self)
	if self.Trinket then
		self:UnregisterEvent("ARENA_OPPONENT_UPDATE", Update)
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Update)
		self:UnregisterEvent("ARENA_COOLDOWNS_UPDATE", Update)
		self:UnregisterEvent("ARENA_CROWD_CONTROL_SPELL_UPDATE", Update)
		self.Trinket:Hide()
	end
end

oUF:AddElement('Trinket', Update, Enable, Disable)
