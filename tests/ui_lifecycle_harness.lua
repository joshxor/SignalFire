local lifecyclePath = assert(arg and arg[1], "extracted lifecycle path is required")

unpack = unpack or table.unpack
loadstring = loadstring or load

local treeVisits = 0
local oldPatchCalls = 0
local suppressCalls = 0
local messages = {}

local function newControl(name, text)
  local control = {name=name, text=text or "", shown=true, checked=false}
  function control:GetName() return self.name end
  function control:GetText() return self.text end
  function control:SetText(value) self.text = tostring(value or "") end
  function control:GetChecked() return self.checked end
  function control:SetChecked(value) self.checked = value and true or false end
  function control:Show() self.shown = true end
  function control:Hide() self.shown = false end
  function control:IsShown() return self.shown end
  function control:IsVisible() return self.shown end
  function control:GetChildren() treeVisits = treeVisits + 1; return nil end
  function control:SetAlpha(value) self.alpha = value end
  function control:EnableMouse(value) self.mouse = value end
  return control
end

function UIDropDownMenu_GetText(control) return control and control.text or "" end
function BLFG_DropdownText(control) return control and control.text or "" end

SignalFirePerf151 = {enabled=true, stats={}}
function SignalFirePerf151:Note(category, field, amount)
  self.stats[category] = self.stats[category] or {}
  self.stats[category][field] = (self.stats[category][field] or 0) + (amount or 1)
end

DEFAULT_CHAT_FRAME = {AddMessage=function(_, text) messages[#messages + 1] = text end}
BronzeLFG_DB = {options={serverProfile="Triumvirate", modules={}, modulesByProfile={}}}

function BLFG_SF1430H_SuppressNativeDropdown(control)
  suppressCalls = suppressCalls + 1
  control:SetAlpha(0)
  control:EnableMouse(false)
end

function BLFG_FixDropdownButton(control)
  oldPatchCalls = oldPatchCalls + 1
  if control.SFDisableNativeMenu then BLFG_SF1430H_SuppressNativeDropdown(control) end
end

function BLFG_SF135J_FixAllDropdowns(root)
  if root and root.GetChildren then root:GetChildren() end
end

function BLFG_SF135J_FixVisibleDropdowns()
  BLFG_SF135J_FixAllDropdowns(BronzeLFG and BronzeLFG.frame)
end

local createCalls = 0
local showCreateCalls = 0
local profileCreateCalls = 0
local profileOptionsCalls = 0
local updateControlCalls = 0
local postingPreviewCalls = 0
local compactPreviewCalls = 0
local applyUICalls = 0
local identityCalls = 0

BronzeLFG = {}
local B = BronzeLFG

local function buildCore(self)
  self.frame = self.frame or newControl("frame")
  self.content = self.content or newControl("content")
  self.side = self.side or newControl("side")
  self.browse = self.browse or newControl("browse")
  self.create = self.create or newControl("create")
  self.profile = self.profile or newControl("profile")
  self.apps = self.apps or newControl("apps")
  self.publicPanel = self.publicPanel or newControl("public")
  self.onlinePanel = self.onlinePanel or newControl("online")
  self.guildPanel = self.guildPanel or newControl("guild")
  self.optionsPanel = self.optionsPanel or newControl("options")
  self.myPanel = self.myPanel or newControl("my")
  self.typeDrop = self.typeDrop or newControl("TypeDrop", "Dungeon")
  self.activityDrop = self.activityDrop or newControl("ActivityDrop", "Random Dungeon Finder")
  self.specificDungeonDrop = self.specificDungeonDrop or newControl("SpecificDrop", "Select Dungeon")
  self.specificDungeonDrop.SFDisableNativeMenu = true
  self.diffDrop = self.diffDrop or newControl("DiffDrop", "Normal")
  self.voiceDrop = self.voiceDrop or newControl("VoiceDrop", "None")
  self.lootDrop = self.lootDrop or newControl("LootDrop", "Group Loot")
  self.profileRole = self.profileRole or newControl("ProfileRole", "DPS")
  self.serverProfileDD = self.serverProfileDD or newControl("ServerProfile", BronzeLFG_DB.options.serverProfile)
  self.needTank = self.needTank or newControl("tank")
  self.needHealer = self.needHealer or newControl("healer")
  self.needDPS = self.needDPS or newControl("dps")
  self.keyBox = self.keyBox or newControl("key", "")
  self.minIlvlBox = self.minIlvlBox or newControl("min", "")
  self.maxBox = self.maxBox or newControl("max", "5")
  self.noteBox = self.noteBox or newControl("note", "")
  self.sfamCreatePreview = self.sfamCreatePreview or newControl("postingPreview")
  self.sf1429Preview = self.sf1429Preview or newControl("compactPreview")
  for _, field in ipairs({"typeDrop", "activityDrop", "specificDungeonDrop", "diffDrop", "voiceDrop", "lootDrop", "profileRole", "serverProfileDD"}) do
    local control = self[field]
    _G[control:GetName() .. "Button"] = _G[control:GetName() .. "Button"] or newControl(control:GetName() .. "Button")
  end
end

function B:CreateUI()
  createCalls = createCalls + 1
  buildCore(self)
  self:SF143_ApplyProfileToCreate()
  self:SF143_ApplyProfileToOptions()
  self:SFAM_UpdateCreatePreview()
  self:SFAM_UpdateCreatePreview()
end

function B:ShowCreate()
  showCreateCalls = showCreateCalls + 1
  self:CreateUI()
  self:UpdateCreateControls()
  self:SF143_ApplyProfileToCreate()
  self.create:Show()
end

function B:SF143_GetProfileId() return BronzeLFG_DB.options.serverProfile end
function B:SF143_ApplyProfileToCreate()
  profileCreateCalls = profileCreateCalls + 1
  if self.raiseProfileError then error("profile failure") end
  self:SFAM_UpdateCreatePreview()
end
function B:SF143_ApplyProfileToOptions() profileOptionsCalls = profileOptionsCalls + 1 end
function B:UpdateCreateControls()
  updateControlCalls = updateControlCalls + 1
  self:SF143_ApplyProfileToCreate()
  self:SFAM_UpdateCreatePreview()
end
function B:SFAM_UpdateCreatePreview() postingPreviewCalls = postingPreviewCalls + 1 end
function B:SFUI1434_Apply() identityCalls = identityCalls + 1 end

SignalFireAscensionListingPolish = {}
function SignalFireAscensionListingPolish.UpdatePreview() compactPreviewCalls = compactPreviewCalls + 1 end
function SignalFireAscensionListingPolish.ApplyUI(self)
  applyUICalls = applyUICalls + 1
  SignalFireAscensionListingPolish.UpdatePreview(self)
end

local chunk, err = loadfile(lifecyclePath)
assert(chunk, err)
assert(pcall(chunk), "Phase 2 lifecycle block failed to load")

local L = assert(SignalFireUILifecycle151, "lifecycle namespace was not created")
assert(L.generation == "1.5.1-perf-phase2", "wrong lifecycle generation")

-- Initial construction and repeated fast path.
B:CreateUI()
assert(createCalls == 1 and L.initialized, "initial CreateUI did not complete")
local patchCount = oldPatchCalls
assert(patchCount > 0, "dropdowns were not registered")
assert(B.specificDungeonDrop._signalFireDropdownPatched == "suppressed", "custom dungeon dropdown was not suppressed")
assert(suppressCalls == 1, "custom dungeon dropdown suppression did not run exactly once")
B:CreateUI()
assert(createCalls == 1, "repeated CreateUI did not use the fast path")

-- Explicit registration is idempotent and never recursively scans a parent tree.
BLFG_SF135J_FixVisibleDropdowns()
BLFG_SF135J_FixVisibleDropdowns()
assert(oldPatchCalls == patchCount, "duplicate dropdown patching was not skipped")
assert(treeVisits == 0, "recursive dropdown traversal was still used")

-- A genuinely missing core panel re-enters the recovery chain once.
B.optionsPanel = nil
B:CreateUI()
assert(createCalls == 2 and B.optionsPanel, "missing-panel recovery did not execute")
B:CreateUI()
assert(createCalls == 2, "post-recovery CreateUI did not return to the fast path")

-- Repeated ShowCreate calls preserve behavior while unchanged profile/preview work is skipped.
B:ShowCreate()
local profileAfterShow = profileCreateCalls
local previewAfterShow = postingPreviewCalls
B:ShowCreate()
assert(showCreateCalls == 2, "ShowCreate behavior was suppressed")
assert(profileCreateCalls == profileAfterShow, "unchanged ShowCreate reapplied the profile")
assert(postingPreviewCalls == previewAfterShow, "unchanged ShowCreate rebuilt the preview")

-- Profile transitions execute once per actual profile change.
local beforeSwitch = profileCreateCalls
BronzeLFG_DB.options.serverProfile = "Ascension"
B.serverProfileDD:SetText("Ascension")
B:SF143_ApplyProfileToCreate()
BronzeLFG_DB.options.serverProfile = "Triumvirate"
B.serverProfileDD:SetText("Triumvirate")
B:SF143_ApplyProfileToCreate()
assert(profileCreateCalls == beforeSwitch + 2, "profile transitions were not applied")
local unchangedProfile = profileCreateCalls
B:SF143_ApplyProfileToCreate()
assert(profileCreateCalls == unchangedProfile, "unchanged profile application was not skipped")

-- Preview signatures execute only for changed visible inputs.
local previewBase = postingPreviewCalls
B:SFAM_UpdateCreatePreview()
assert(postingPreviewCalls == previewBase, "unchanged preview input was not skipped")
B.noteBox:SetText("Changed note")
B:SFAM_UpdateCreatePreview()
assert(postingPreviewCalls == previewBase + 1, "changed preview input did not execute")

-- Applying guards clear even when the wrapped profile function throws.
B.typeDrop:SetText("Raid")
B.raiseProfileError = true
local ok = pcall(function() B:SF143_ApplyProfileToCreate() end)
assert(not ok, "profile error was unexpectedly swallowed")
assert(not L.lastCreateProfileSignatureActive and L.transactionDepth == 0, "profile guard was not cleared after an error")
B.raiseProfileError = nil
assert(pcall(function() B:SF143_ApplyProfileToCreate() end), "profile application did not recover after an error")

local ui = SignalFirePerf151.stats.ui or {}
assert((ui.createUIFullExecutions or 0) == 2, "unexpected full CreateUI count")
assert((ui.createUIFastPath or 0) >= 3, "CreateUI fast paths were not recorded")
assert((ui.dropdownPatchSkips or 0) > 0, "duplicate dropdown patch skips were not recorded")
assert((ui.profileApplicationsSkipped or 0) > 0, "profile skips were not recorded")
assert((ui.previewUpdatesSkipped or 0) > 0, "preview skips were not recorded")
assert((ui.recursiveTreeScans or 0) == 0 and (ui.treeFramesVisited or 0) == 0, "recursive scan counters changed")

print("ui lifecycle harness: PASS (full=" .. tostring(ui.createUIFullExecutions or 0)
  .. ", fast=" .. tostring(ui.createUIFastPath or 0)
  .. ", scans=" .. tostring(ui.recursiveTreeScans or 0)
  .. ", frames=" .. tostring(ui.treeFramesVisited or 0)
  .. ", profile=" .. tostring(ui.profileApplicationsRequested or 0) .. "/" .. tostring(ui.profileApplicationsExecuted or 0)
  .. ", preview=" .. tostring(ui.previewUpdatesRequested or 0) .. "/" .. tostring(ui.previewUpdatesExecuted or 0) .. ")")
