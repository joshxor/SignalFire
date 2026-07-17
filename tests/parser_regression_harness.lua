local addonRoot = assert(arg and arg[1], "addon root is required")

unpack = unpack or table.unpack
loadstring = loadstring or load

local nowValue = 100000
function GetTime() return nowValue end
function time() return math.floor(nowValue) end
function now() return nowValue end
function debugprofilestop() return nowValue * 1000 end

local function noop() end
local function falseFn() return false end
local function oneFn() return 1 end

local objectMethods = {}
local objectMeta = {
  __index = function(self, key)
    local method = objectMethods[key]
    if method then return method end
    method = function() end
    objectMethods[key] = method
    return method
  end,
}

local function newObject(name)
  return setmetatable({name=name, shown=false, scripts={}, events={}, width=1024, height=768}, objectMeta)
end

function objectMethods:GetName() return self.name end
function objectMethods:SetScript(kind, fn) self.scripts[kind] = fn end
function objectMethods:GetScript(kind) return self.scripts[kind] end
function objectMethods:HookScript(kind, fn) self.scripts["hook:" .. kind] = fn end
function objectMethods:RegisterEvent(event) self.events[event] = true end
function objectMethods:UnregisterEvent(event) self.events[event] = nil end
function objectMethods:IsEventRegistered(event) return self.events[event] == true end
function objectMethods:Show() self.shown = true end
function objectMethods:Hide() self.shown = false end
function objectMethods:IsShown() return self.shown end
function objectMethods:IsVisible() return self.shown end
function objectMethods:SetWidth(value) self.width = value end
function objectMethods:SetHeight(value) self.height = value end
function objectMethods:SetSize(width, height) self.width, self.height = width, height end
function objectMethods:GetWidth() return self.width end
function objectMethods:GetHeight() return self.height end
function objectMethods:GetFrameLevel() return self.frameLevel or 1 end
function objectMethods:SetFrameLevel(value) self.frameLevel = value end
function objectMethods:GetFrameStrata() return self.frameStrata or "MEDIUM" end
function objectMethods:SetFrameStrata(value) self.frameStrata = value end
function objectMethods:GetChildren() return nil end
function objectMethods:GetRegions() return nil end
function objectMethods:CreateFontString() return newObject("font") end
function objectMethods:CreateTexture() return newObject("texture") end
function objectMethods:SetText(value) self.text = value end
function objectMethods:GetText() return self.text or "" end
function objectMethods:SetChecked(value) self.checked = value end
function objectMethods:GetChecked() return self.checked end
function objectMethods:SetValue(value) self.value = value end
function objectMethods:GetValue() return self.value or 0 end
function objectMethods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "" end
function objectMethods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function objectMethods:AddMessage() end

UIParent = newObject("UIParent")
UIParent.shown = true
WorldFrame = newObject("WorldFrame")
DEFAULT_CHAT_FRAME = newObject("ChatFrame1")
NUM_CHAT_WINDOWS = 10
for i = 1, NUM_CHAT_WINDOWS do _G["ChatFrame" .. i] = i == 1 and DEFAULT_CHAT_FRAME or newObject("ChatFrame" .. i) end

function CreateFrame(_, name) return newObject(name or "anonymous") end
function UnitName(unit) return unit == "player" and "Harness" or nil end
function UnitClass() return "Templar", "TEMPLAR" end
function UnitGUID(unit) return unit == "player" and "Player-1" or nil end
function UnitLevel() return 60 end
function UnitExists(unit) return unit == "player" end
function GetRealmName() return "HarnessRealm" end
function GetZoneText() return "HarnessZone" end
function GetSubZoneText() return "" end
function GetRealZoneText() return "HarnessZone" end
function GetLocale() return "enUS" end
function GetServerTime() return math.floor(nowValue) end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetCursorPosition() return 0, 0 end
function IsInGuild() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return 0 end
function GetNumPartyMembers() return 0 end
function GetNumRaidMembers() return 0 end
function GetNumGuildMembers() return 0 end
function GetGuildInfo() return nil end
function GetPlayerInfoByGUID() return nil end
function GetChannelName() return 0 end
function GetCVar() return "0" end
function GetAddOnMetadata(_, field) return field == "Version" and "1.5.1" or nil end

local noops = {
  "ChatFrame_AddMessageEventFilter", "ChatFrame_RemoveMessageEventFilter", "SendChatMessage",
  "SendAddonMessage", "RegisterAddonMessagePrefix", "SetCVar", "PlaySound", "PlaySoundFile",
  "ToggleDropDownMenu", "CloseDropDownMenus", "UIDropDownMenu_Initialize",
  "UIDropDownMenu_SetWidth", "UIDropDownMenu_SetText", "UIDropDownMenu_SetSelectedValue",
  "UIDropDownMenu_SetSelectedID", "UIDropDownMenu_SetButtonWidth", "UIDropDownMenu_JustifyText",
  "UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo", "PanelTemplates_SetNumTabs",
  "PanelTemplates_SetTab", "FauxScrollFrame_Update", "FauxScrollFrame_GetOffset",
  "StaticPopup_Show", "ReloadUI", "SetWhoToUI", "FriendsFrame_SendWho", "SendWho",
}
for _, name in ipairs(noops) do _G[name] = noop end

RAID_CLASS_COLORS = {}
CUSTOM_CLASS_COLORS = {}
LOCALIZED_CLASS_NAMES_MALE = {TEMPLAR="Templar"}
LOCALIZED_CLASS_NAMES_FEMALE = {TEMPLAR="Templar"}
ChatTypeInfo = {}
StaticPopupDialogs = {}
SlashCmdList = {}
hash_SlashCmdList = {}
hash_SecureCmdList = {}
UISpecialFrames = {}
SOUNDKIT = {}
OKAY = "Okay"
CANCEL = "Cancel"
ACCEPT = "Accept"
UNKNOWN = "Unknown"

BronzeLFG_DB = {options={serverProfile="Ascension", publicGroups=true, inlineChatLinks=true}}

local files = {
  "SignalFireCore.lua", "BronzeLFG.lua", "SignalFireDiscovery.lua", "SignalFireNetwork.lua",
  "SignalFireRoster.lua", "SignalFireCommunity.lua", "SignalFireRuntime.lua",
  "SignalFireIntegration.lua", "SignalFireControls.lua", "SignalFireChat.lua",
  "SignalFireListing.lua", "SignalFireUI.lua", "SignalFireDiagnostics.lua",
}
for _, file in ipairs(files) do
  local chunk, err = loadfile(addonRoot .. "/" .. file)
  assert(chunk, file .. ": " .. tostring(err))
  local ok, runtimeError = pcall(chunk, "SignalFire", {})
  assert(ok, file .. ": " .. tostring(runtimeError))
end

assert(SignalFireParserRegression and SignalFireParserRegression.Run,
  "parser regression suite was not loaded")
local result = SignalFireParserRegression.Run()
assert(result.total == 33, "expected 33 parser tests, got " .. tostring(result.total))
assert(result.failed == 0, "parser regressions failed: " .. tostring(result.failed))
assert(result.passed + result.skipped == 33, "parser result count mismatch")

local perf = assert(SignalFirePerf151, "performance diagnostics were not loaded")
assert(SlashCmdList["SIGNALFIRE"] == perf.slashWrapper, "diagnostics are not the final slash owner")
assert(hash_SlashCmdList["/sf"] == perf.slashWrapper, "final /sf hash does not use diagnostics owner")
local menuOpens = 0
BronzeLFG.ToggleFrame = function() menuOpens = menuOpens + 1 end
local function assertPerfHandled(label)
  local before = menuOpens
  local owner = assert(SlashCmdList["SIGNALFIRE"], label .. " did not install /sf")
  assert(owner("perf") == true, label .. " did not handle /sf perf")
  assert(menuOpens == before, label .. " allowed /sf perf to open the SignalFire menu")
end

assertPerfHandled("diagnostics owner")
assert(SignalFireSlashFreezeFix and SignalFireSlashFreezeFix.Apply, "chat slash owner unavailable")
SignalFireSlashFreezeFix.Apply()
assertPerfHandled("chat delayed reinstall")
assert(SignalFireSlashFinal and SignalFireSlashFinal.Install, "integration slash owner unavailable")
SignalFireSlashFinal.Install()
assertPerfHandled("integration delayed reinstall")
assert(SignalFireModules and SignalFireModules.InstallSlash, "module slash owner unavailable")
SignalFireModules.InstallSlash()
assertPerfHandled("module login reinstall")
perf:InstallSlash()
assertPerfHandled("diagnostics reconciliation")

assert(SlashCmdList["SIGNALFIREPERF"]("on") == true and perf.enabled == true,
  "/sfperf on alias failed")
assert(SlashCmdList["SIGNALFIREPERF"]("off") == true and perf.enabled == false,
  "/sfperf off alias failed")
assert(hash_SlashCmdList["/sf"]("perf on") == true and perf.enabled == true, "/sf perf on failed")
assert(hash_SlashCmdList["/sf"]("perf off") == true and perf.enabled == false, "/sf perf off failed")

local lifecycle = assert(SignalFireUILifecycle151, "UI lifecycle owner was not loaded")
assert(lifecycle.generation == "1.5.1-perf-phase2", "wrong final UI lifecycle owner")
local rosterSnapshot = assert(SignalFireRosterSnapshot151, "Network/roster snapshot owner was not loaded")
assert(rosterSnapshot.owner == "1.5.1-perf-phase3", "wrong final Network/roster owner")

print("parser regression harness: PASS (" .. tostring(result.passed) .. " passed, "
  .. tostring(result.skipped) .. " skipped, 0 failed)")
