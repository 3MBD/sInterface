
-- rActionBar: bars
-- zork, 2016

-----------------------------
-- Variables
-----------------------------

local A, L = ...

--the stance, pet and possess bars have no background art any more
local function ClearTextures(...)
  for i = 1, select("#", ...) do
    local texture = _G[(select(i, ...))]
    if texture then texture:SetTexture(nil) end
  end
end

-----------------------------
-- Init
-----------------------------

--BagBar
function rActionBar:CreateBagBar(addonName,cfg)
  cfg.blizzardBar = nil
  cfg.frameName = addonName.."BagBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle] hide; show"
  local buttonList = { MainMenuBarBackpackButton, CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot }
  --WoW: Forever also has a reagent bag slot and a key ring
  for _, button in next, { CharacterReagentBag0Slot, KeyRingButton } do
    if button:IsShown() then table.insert(buttonList, button) end
  end
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --the bag bar is an Edit Mode frame now; BagsBar:Layout re-anchors the buttons to it (on
  --VARIABLES_LOADED and whenever an item is picked up), so put them back after every move
  BagsBar:SetParent(L.hiddenFrame)
  local anchors, busy = {}, false
  local function RestorePoint(button)
    if busy then return end
    busy = true
    button:ClearAllPoints()
    button:SetPoint(unpack(anchors[button]))
    busy = false
  end
  for _, button in next, buttonList do
    anchors[button] = { button:GetPoint(1) }
    hooksecurefunc(button, "SetPoint", RestorePoint)
  end
end

--MicroMenuBar
function rActionBar:CreateMicroMenuBar(addonName,cfg)
  cfg.blizzardBar = nil
  cfg.frameName = addonName.."MicroMenuBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle] hide; show"
  --MICRO_BUTTONS is gone: the micro buttons are children of MicroMenu, ordered by layoutIndex
  local buttonList = {}
  for _, button in next, { MicroMenu:GetChildren() } do
    if button.layoutIndex and button:IsShown() then
      table.insert(buttonList, button)
    end
  end
  table.sort(buttonList, function(a, b) return a.layoutIndex < b.layoutIndex end)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --special
  PetBattleFrame.BottomFrame.MicroButtonFrame:SetScript("OnShow", nil)
  OverrideActionBar:SetScript("OnShow", nil)
  --the micro menu frame and its art stay behind in the Edit Mode container
  MicroMenuContainer:SetParent(L.hiddenFrame)
end

--Bar1
function rActionBar:CreateActionBar1(addonName,cfg)
  L:HideMainMenuBar()
  cfg.blizzardBar = nil
  cfg.frameName = addonName.."Bar1"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle] hide; show"
  --pages 13-15 are action bars 6-8 now; the override, temp shapeshift and vehicle pages are
  --looked up when the state changes, like Blizzard does (numeric pages still work)
  cfg.actionPage = cfg.actionPage or "[bar:6]6;[bar:5]5;[bar:4]4;[bar:3]3;[bar:2]2;[overridebar]override;[shapeshift]shapeshift;[vehicleui]vehicle;[possessbar]possess;[bonusbar:5]11;[bonusbar:4]10;[bonusbar:3]9;[bonusbar:2]8;[bonusbar:1]7;1"
  local buttonName = "ActionButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --the button grid of actionbar1 is no longer fixed here: showgrid is a set of flags that
  --MainActionBar (still loaded, only hidden) maintains from its events and Edit Mode settings
  --_onstate-page state driver
  for i, button in next, buttonList do
    frame:SetFrameRef(buttonName..i, button)
  end
  frame:Execute(([[
    buttons = table.new()
    for i=1, %d do
      table.insert(buttons, self:GetFrameRef("%s"..i))
    end
  ]]):format(numButtons, buttonName))
  frame:SetAttribute("_onstate-page", [[
    --print("_onstate-page","index",newstate)
    local page = tonumber(newstate)
    if newstate == "override" then
      page = HasOverrideActionBar() and GetOverrideBarIndex() or nil
    elseif newstate == "shapeshift" then
      page = HasTempShapeshiftActionBar() and GetTempShapeshiftBarIndex() or nil
    elseif newstate == "vehicle" or newstate == "possess" then
      if HasVehicleActionBar() then
        page = GetVehicleBarIndex()
      elseif HasOverrideActionBar() then
        page = GetOverrideBarIndex()
      elseif HasBonusActionBar() then
        page = GetBonusBarIndex()
      end
    end
    page = page or GetActionBarPage() or 1
    for i, button in next, buttons do
      button:SetAttribute("actionpage", page)
    end
  ]])
  RegisterStateDriver(frame, "page", cfg.actionPage)
end

--Bar2
function rActionBar:CreateActionBar2(addonName,cfg)
  cfg.blizzardBar = MultiBarBottomLeft
  cfg.frameName = addonName.."Bar2"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; show"
  local buttonName = "MultiBarBottomLeftButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
end

--Bar3
function rActionBar:CreateActionBar3(addonName,cfg)
  cfg.blizzardBar = MultiBarBottomRight
  cfg.frameName = addonName.."Bar3"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; show"
  local buttonName = "MultiBarBottomRightButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
end

--Bar4
function rActionBar:CreateActionBar4(addonName,cfg)
  cfg.blizzardBar = MultiBarRight
  cfg.frameName = addonName.."Bar4"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; show"
  local buttonName = "MultiBarRightButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
end

--Bar5
function rActionBar:CreateActionBar5(addonName,cfg)
  cfg.blizzardBar = MultiBarLeft
  cfg.frameName = addonName.."Bar5"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; show"
  local buttonName = "MultiBarLeftButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
end

--StanceBar
function rActionBar:CreateStanceBar(addonName,cfg)
  cfg.blizzardBar = StanceBar
  cfg.frameName = addonName.."StanceBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; show"
  local buttonName = "StanceButton"
  local numButtons = StanceBar.numButtons
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --special
  ClearTextures("StanceBarLeft", "StanceBarMiddle", "StanceBarRight")
end

--PetBar
function rActionBar:CreatePetBar(addonName,cfg)
  cfg.blizzardBar = PetActionBar
  --its OnUpdate colours the pet buttons' hotkeys by range, and only runs while it is visible
  cfg.blizzardBarKeepVisible = true
  cfg.frameName = addonName.."PetBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[petbattle][overridebar][vehicleui][possessbar][shapeshift] hide; [pet] show; hide"
  local buttonName = "PetActionButton"
  local numButtons = NUM_PET_ACTION_SLOTS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --special
  ClearTextures("SlidingActionBarTexture0", "SlidingActionBarTexture1")
end

--ExtraBar
function rActionBar:CreateExtraBar(addonName,cfg)
  --ExtraAbilityContainer reparents ExtraActionBarFrame whenever an extra action appears, so the
  --button is taken over instead; the empty frame stays with Blizzard and must not catch clicks
  cfg.blizzardBar = nil
  cfg.frameName = addonName.."ExtraBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[extrabar] show; hide"
  local buttonName = "ExtraActionButton"
  local numButtons = NUM_ACTIONBAR_BUTTONS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --special
  ExtraActionBarFrame:EnableMouse(false)
end

--VehicleExitBar
function rActionBar:CreateVehicleExitBar(addonName,cfg)
  cfg.blizzardBar = nil
  cfg.frameName = addonName.."VehicleExitBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[canexitvehicle]c;[mounted]m;n"
  cfg.frameVisibilityFunc = "exit"
  --create vehicle exit button
  local button = CreateFrame("CHECKBUTTON", A.."VehicleExitButton", nil, "ActionButtonTemplate, SecureHandlerClickTemplate")
  button.icon:SetTexture("interface\\addons\\"..A.."\\embeds\\rActionBar\\media\\vehicleexit")
  --the button art is sized for 45px buttons and anchored to the top left; keep it centred
  local normalTexture = button:GetNormalTexture()
  if normalTexture then
    normalTexture:ClearAllPoints()
    normalTexture:SetAllPoints(button)
  end
  button:RegisterForClicks("AnyUp")
  local function OnClick(self)
    if UnitOnTaxi("player") then TaxiRequestEarlyLanding() else VehicleExit() end self:SetChecked(false)
  end
  button:SetScript("OnClick", OnClick)
  local buttonList = { button }
  local frame = L:CreateButtonFrame(cfg, buttonList)
  --[canexitvehicle] is not triggered on taxi, exit workaround
  frame:SetAttribute("_onstate-exit", [[ if CanExitVehicle() then self:Show() else self:Hide() end ]])
  if not CanExitVehicle() then frame:Hide() end
end

--PossessExitBar, this is the two button bar to cancel a possess in progress
function rActionBar:CreatePossessExitBar(addonName,cfg)
  cfg.blizzardBar = PossessActionBar
  cfg.frameName = addonName.."PossessExitBar"
  cfg.frameParent = cfg.frameParent or UIParent
  cfg.frameTemplate = "SecureHandlerStateTemplate"
  cfg.frameVisibility = cfg.frameVisibility or "[possessbar] show; hide"
  local buttonName = "PossessButton"
  local numButtons = NUM_POSSESS_SLOTS
  local buttonList = L:GetButtonList(buttonName, numButtons)
  local frame = L:CreateButtonFrame(cfg,buttonList)
  --special
  ClearTextures("PossessBackground1", "PossessBackground2")
end
