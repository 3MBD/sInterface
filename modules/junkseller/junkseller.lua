local _, ns = ...
local E = ns.E

if not E:C('junkseller', 'enabled') then return end;

local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local UseContainerItem = C_Container.UseContainerItem
local POOR = Enum.ItemQuality.Poor

local function GreySell()
	for bag=0,(NUM_BAG_SLOTS or 4) do
		for slot=1,GetContainerNumSlots(bag) do
			local info = GetContainerItemInfo(bag, slot)
			if info and info.quality == POOR and not info.hasNoValue then
				UseContainerItem(bag, slot)
			end
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", GreySell)
if MerchantFrame:IsVisible() then GreySell() end
