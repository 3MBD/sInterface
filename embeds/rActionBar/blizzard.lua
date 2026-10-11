
-- rActionBar: blizzard
-- zork, 2016

-----------------------------
-- Config
-----------------------------

local cfg = {}

-----------------------------
-- Variables
-----------------------------

local A, L = ...

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()
L.hiddenFrame = hiddenFrame

local scripts = {
  "OnShow", "OnHide", "OnEvent", "OnEnter", "OnLeave", "OnUpdate", "OnValueChanged", "OnClick", "OnMouseDown", "OnMouseUp",
}

--MainMenuBar became MainActionBar, an Edit Mode system: hide it by reparenting only and keep its
--events and scripts, they drive the button grid (ACTIONBAR_SHOWGRID) of ActionButton1-12
local framesToHide = {
  MainActionBar,
  OverrideActionBar,
}

local framesToDisable = {
  MicroButtonAndBagsBar, StatusTrackingBarManager,
  MainMenuBarVehicleLeaveButton,
  OverrideActionBar,
  OverrideActionBarExpBar, OverrideActionBarHealthBar, OverrideActionBarPowerBar, OverrideActionBarPitchFrame,
}

-----------------------------
-- Functions
-----------------------------

--DisableAllScripts
local function DisableAllScripts(frame)
  for i, script in next, scripts do
    if frame:HasScript(script) then
      frame:SetScript(script,nil)
    end
  end
end

--L:HideMainMenuBar
function L:HideMainMenuBar()
  --the currency workaround (TokenFrame_Update on CURRENCY_DISPLAY_UPDATE) is gone: those functions
  --no longer exist and the currency display no longer depends on the main menu bar
  for i, frame in next, framesToHide do
    frame:SetParent(hiddenFrame)
  end
  for i, frame in next, framesToDisable do
    frame:UnregisterAllEvents()
    DisableAllScripts(frame)
  end
end

--fix blizzard cooldown flash
local issecretvalue = issecretvalue or function() return false end

local function FixCooldownFlash(self)
  if not self then return end
  --the effective alpha is secret when a parent's alpha was set from secret values
  local alpha = self:GetEffectiveAlpha()
  if issecretvalue(alpha) then return end
  if alpha > 0 then
    self:Show()
  else
    self:Hide()
  end
end

--only for the buttons rActionBar owns: a hook on the shared Cooldown metatable ran for every
--cooldown in the UI, including Blizzard frames with secret alpha
local hookedCooldowns = {}
local cooldownKeys = { "cooldown", "chargeCooldown", "lossOfControlCooldown" }
function L:HookCooldownFlash(button)
  for _, key in next, cooldownKeys do
    local cooldown = button[key]
    if cooldown and cooldown.SetCooldown and not hookedCooldowns[cooldown] then
      hookedCooldowns[cooldown] = true
      hooksecurefunc(cooldown, "SetCooldown", FixCooldownFlash)
    end
  end
end