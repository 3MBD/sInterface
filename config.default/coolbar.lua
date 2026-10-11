local _, ns = ...
local C = ns.C

local GetItemName = C_Item.GetItemNameByID

C["coolbar"] = {
	enabled = true,
	width = 160,
	height = 15,
	oocTransparency = 0.3,
	pos = { "TOP", "oUF_sInterfacePlayer", "BOTTOM", 0, -50 },
	disabled = {
		[GetItemName(6948) or "Hearthstone"] = true,
		[GetItemName(110560) or "Garrison Hearthstone"] = true,
	}
}

