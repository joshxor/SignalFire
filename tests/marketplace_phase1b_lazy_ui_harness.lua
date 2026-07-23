local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local M = assert(SignalFireMarketplace151, "Marketplace core did not load")
local U = assert(SignalFireMarketplaceUI151, "Marketplace UI owner did not load")
local LP = assert(SignalFireLazyPanels151, "lazy-panel owner did not load")

local function set_module(profile, enabled)
  BronzeLFG_DB.options.serverProfile = profile
  BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
  BronzeLFG_DB.options.modulesByProfile[profile] = BronzeLFG_DB.options.modulesByProfile[profile] or {}
  BronzeLFG_DB.options.modulesByProfile[profile].tradeskillMarketplace = enabled
end

local function has_marketplace_item()
  for _, item in ipairs(B:SFModulesBuildSideItems()) do
    if item[1] == "Marketplace" then return true end
  end
  return false
end

set_module("Ascension", false)
B:SFModulesApply()
assert(U:GetPanelState() == "unbuilt" and not U.panel and not U.registered,
  "disabled login constructed or registered Marketplace UI")
assert(not LP.panels.marketplace and not has_marketplace_item(),
  "disabled Marketplace retained lazy or sidebar access")

local disabledMessages = {}
local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(disabledMessages, text) end
assert(B:SF151_HandlePerfSlash("marketplace") == true, "final slash owner did not handle Marketplace")
DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
assert(not U.panel and not B.frame, "disabled slash command constructed UI")
assert(string.find(disabledMessages[#disabledMessages] or "", "is disabled", 1, true),
  "disabled slash command did not explain the disabled state")

set_module("Ascension", true)
assert(B:SFModulesApply() == true, "module application did not enable Marketplace")
assert(M.runtime and M.runtime.active and U.active and U.registered and LP.panels.marketplace,
  "enabled Marketplace did not register its lazy descriptor")
assert(U:GetPanelState() == "unbuilt" and has_marketplace_item(),
  "enable constructed the panel or omitted sidebar access")

B:CreateUI()
B:SF143_ApplyProfileToOptions()
B:SF143_ApplyProfileToCreate()
assert(U:GetPanelState() == "unbuilt" and U.buildCount == 0,
  "login or profile application constructed Marketplace UI")

assert(B:ShowOptions() == true, "Options did not open during lazy test")
assert(U:GetPanelState() == "unbuilt" and U.buildCount == 0,
  "Options construction built Marketplace UI")

assert(B:SF151_HandlePerfSlash("marketplace") == true, "enabled slash did not open Marketplace")
assert(U:GetPanelState() == "visible" and U.buildCount == 1 and U.openCount == 1,
  "first open did not construct and show Marketplace exactly once")
assert(#U.navButtons == 4 and U:ActiveScriptCount() == 4,
  "Marketplace shell navigation is incomplete")
local firstPanel = U.panel
assert(M:GetStatus().panel == "visible", "Marketplace status did not report its visible content frame")
local ownerPanel = U.panel
local stalePanel = CreateFrame("Frame")
stalePanel:Hide()
U.panel = stalePanel
assert(M:GetStatus().panel == "visible",
  "Marketplace status used a stale owner reference instead of the canonical content frame")
U.panel = ownerPanel

local visibleMessages = {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(visibleMessages, text) end
assert(B:SF151_HandlePerfSlash("marketplace status") == true,
  "visible Marketplace status command was not handled")
DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
assert(string.find(visibleMessages[3] or "", "panel=visible", 1, true),
  "visible Marketplace slash status did not report panel=visible")

assert(B:ShowBrowse() == true, "Browse did not open after Marketplace")
assert(U:GetPanelState() == "hidden", "opening another panel did not hide Marketplace")
assert(M:GetStatus().panel == "hidden", "hidden Marketplace status was incorrect")
local refreshes = U.refreshCount
assert(B:SFMarketplaceRefresh() == false and U.refreshCount == refreshes
  and U.hiddenRefreshSkips >= 1, "hidden Marketplace performed refresh work")

assert(B:ShowMarketplace() == true and U.panel == firstPanel and U.buildCount == 1,
  "second open did not reuse the Marketplace frame")
set_module("Ascension", false)
assert(B:SFModulesApply() == true, "module application did not disable Marketplace")
assert(U.panel == firstPanel and U:GetPanelState() == "hidden" and not U.active and not U.registered,
  "Disable did not retain one inert hidden frame")
assert(not LP.panels.marketplace and U:ActiveScriptCount() == 0 and U:IsDisabledClean(),
  "Disable left active Marketplace UI ownership")
assert(not has_marketplace_item(), "Disable left Marketplace sidebar access")
local disabled = B:SFMarketplaceGetStatus()
assert(disabled.runtime == "inactive" and disabled.panel == "hidden" and disabled.disabledClean == true,
  "Phase 1A disabled invariant did not survive a constructed panel")

set_module("Ascension", true)
assert(B:SFModulesApply() == true and U.registered and U.panel == firstPanel,
  "re-enable did not register the existing Marketplace frame")
assert(U:GetPanelState() == "hidden" and U.buildCount == 1 and U:ActiveScriptCount() == 4,
  "re-enable rebuilt the frame or failed to restore scripts")
assert(B:SF151_HandlePerfSlash("marketplace") == true and U:GetPanelState() == "visible"
  and U.panel == firstPanel and U.buildCount == 1, "re-enabled Marketplace did not reuse its frame")

set_module("Ascension", false)
B:SFModulesApply()
local final = U:GetDiagnostics()
assert(final.state == "hidden" and final.disabledClean and final.activeScripts == 0,
  "final disabled UI state is not inert")

print("marketplace phase1b lazy UI harness: PASS (builds=" .. tostring(final.buildCount)
  .. ", opens=" .. tostring(final.openCount) .. ", hiddenSkips=" .. tostring(final.hiddenRefreshSkips) .. ")")
