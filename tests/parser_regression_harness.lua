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
  return setmetatable({name=name, shown=false, scripts={}, events={}, width=1024, height=768,
    sf135jClickCatcher=false, sf135jArrow=false, _sf1430jSelector=false}, objectMeta)
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
function objectMethods:GetFrameLevel() return rawget(self, "frameLevel") or 1 end
function objectMethods:SetFrameLevel(value) self.frameLevel = value end
function objectMethods:GetFrameStrata() return rawget(self, "frameStrata") or "MEDIUM" end
function objectMethods:SetFrameStrata(value) self.frameStrata = value end
function objectMethods:SetScale(value) self.scale = value end
function objectMethods:GetScale() return rawget(self, "scale") or 1 end
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
function objectMethods:AddMessage(text) self.lastMessage = text end

UIParent = newObject("UIParent")
UIParent.shown = true
WorldFrame = newObject("WorldFrame")
DEFAULT_CHAT_FRAME = newObject("ChatFrame1")
NUM_CHAT_WINDOWS = 10
for i = 1, NUM_CHAT_WINDOWS do _G["ChatFrame" .. i] = i == 1 and DEFAULT_CHAT_FRAME or newObject("ChatFrame" .. i) end

function CreateFrame(_, name)
  local frame = newObject(name or "anonymous")
  if name then
    _G[name] = frame
    _G[name .. "Text"] = _G[name .. "Text"] or newObject(name .. "Text")
    _G[name .. "Button"] = _G[name .. "Button"] or newObject(name .. "Button")
  end
  return frame
end
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
function UIDropDownMenu_SetText(frame, text) if frame then frame.text = tostring(text or "") end end
function UIDropDownMenu_GetText(frame) return frame and rawget(frame, "text") or "" end
function UIDropDownMenu_CreateInfo() return {} end
function FauxScrollFrame_GetOffset() return 0 end

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
assert(result.total == 57, "expected 57 parser tests, got " .. tostring(result.total))
if result.failed > 0 then
  for _, item in ipairs(result.results or {}) do
    if item.status == "FAIL" then print("parser fixture failed: " .. tostring(item.detail)) end
  end
end
assert(result.failed == 0, "parser regressions failed: " .. tostring(result.failed))
assert(result.passed + result.skipped == 57, "parser result count mismatch")

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

local chat = assert(SignalFireChatRuntime151, "Phase 12C chat owner was not loaded")
assert(chat.generation == "1.5.3-phase12c-coverage", "wrong final chat/Public Groups owner")
BronzeLFG:SF151_SetDeveloperDiagnostics(true)
BronzeLFG:SF151_ResetChatRuntimeStats()

local function tableCount(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end

local function filter(frame, message, author, event)
  local _, rendered = chat.Filter(frame, event or "CHAT_MSG_CHANNEL", message, author or "Tester",
    nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
  return rendered
end

local function ingest(message, author, event, channel)
  return chat.IngestSource(author or "Tester", message, channel or "3. Newcomers",
    event or "CHAT_MSG_CHANNEL")
end

local function drainQueue()
  local frame = assert(BronzeLFG._sfP3Frame, "chat queue frame missing")
  local update = assert(frame:GetScript("OnUpdate"), "chat queue update missing")
  local guard = 0
  while #(BronzeLFG._sfP3Queue or {}) > 0 do
    update(frame, 0.07)
    guard = guard + 1
    assert(guard < 100, "chat queue did not drain")
  end
end

BronzeLFG.publicGroups = {}
BronzeLFG.SignalFireTestSay = true
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
chat.Apply()

local message = "LFM MC 1 HEALER"
assert(ingest(message, "Tester"), "source owner rejected a valid listing")
local linkedId = nil
for i = 1, 10 do
  local rendered = filter(_G["ChatFrame" .. i], message, "Tester")
  assert(string.find(rendered, "Molten Core - Need H", 1, true),
    "first display did not receive the exact activity link")
  local id = string.match(rendered, "bronzelfgpub:([^|]+)")
  assert(id and id ~= "", "first display link did not contain a stable row ID")
  linkedId = linkedId or id
  assert(linkedId == id, "first receiving frames did not reuse one stable row ID")
end
assert(#(BronzeLFG._sfP3Queue or {}) == 1, "one source message created multiple parser jobs")
assert(tableCount(BronzeLFG.publicGroups) == 1, "exact resolver did not create one canonical row before display")
drainQueue()
assert(tableCount(BronzeLFG.publicGroups) == 1, "worker changed canonical row ownership")

for i = 1, 10 do
  local rendered = filter(_G["ChatFrame" .. i], message, "Tester")
  assert(string.find(rendered, "Molten Core", 1, true), "completed display cache missed the activity link")
  local id = string.match(rendered, "bronzelfgpub:([^|]+)")
  assert(id and id ~= "", "activity link did not contain a stable row ID")
  linkedId = linkedId or id
  assert(linkedId == id, "receiving frames did not reuse one stable row ID")
end
BronzeLFG:OpenPublicGroupLink(linkedId, "Molten Core - Need H")
assert(BronzeLFG.selectedPublic == linkedId, "cached link did not select the exact canonical row")

local firstStats = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters
assert((firstStats.filterReceipts or 0) == 20, "filter receipt accounting is incorrect")
assert((firstStats.sourceEvents or 0) == 1, "one source message produced multiple decisions")
assert((firstStats.TestParseCalls or 0) == 1, "one source message was parsed more than once")
assert((firstStats.queueRecordsCreated or 0) == 1 and (firstStats.queueRecordsProcessed or 0) == 1,
  "one source message did not produce one worker record")
assert((firstStats.inlineParserCalls or 0) == 0 and (firstStats.inlineQueueCalls or 0) == 0,
  "display filtering performed forbidden parser work")

nowValue = nowValue + 7
assert(ingest(message, "Tester"), "repost was not ingested")
drainQueue()
assert(tableCount(BronzeLFG.publicGroups) == 1, "repost created a duplicate row")
assert(BronzeLFG.publicGroups[linkedId], "repost changed the stable row ID")

nowValue = nowValue + 7
ingest("LFG RDF", "Tester")
ingest(message, "OtherTester")
drainQueue()
local second = filter(ChatFrame1, "LFG RDF", "Tester")
local third = filter(ChatFrame1, message, "OtherTester")
local secondId = string.match(second, "bronzelfgpub:([^|]+)")
local thirdId = string.match(third, "bronzelfgpub:([^|]+)")
assert(secondId and secondId ~= linkedId, "different activity reused the wrong canonical identity")
assert(thirdId and thirdId ~= linkedId, "different player reused the wrong canonical identity")
assert(tableCount(BronzeLFG.publicGroups) == 3, "distinct canonical listings did not remain distinct")

local beforeProtocol = #(BronzeLFG._sfP3Queue or {})
assert(not ingest("BLFG312~PRESENCE~payload", "Protocol"), "protocol traffic entered source parsing")
assert(#(BronzeLFG._sfP3Queue or {}) == beforeProtocol, "protocol traffic entered the parser queue")

BronzeLFG_DB.options.inlineChatLinks = false
chat.Apply()
assert(BronzeLFG:SF151_GetChatFilterState().knownSignalFireRegistrations == 0,
  "links-off mode retained display filters")
nowValue = nowValue + 7
ingest("LFM BWL need tank", "Linkless")
assert(#(BronzeLFG._sfP3Queue or {}) == 1, "links-off mode stopped source parsing")
drainQueue()
BronzeLFG_DB.options.inlineChatLinks = true
chat.Apply()
assert(BronzeLFG:SF151_GetChatFilterState().knownSignalFireRegistrations == 3,
  "links-on mode did not install exactly three filters")

BronzeLFG_DB.options.publicGroups = false
chat.Apply()
BronzeLFG:SF151_ResetChatRuntimeStats()
assert(not ingest("LFM AQ40 need dps", "Disabled"), "parsing-off mode accepted a source event")
local disabled = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters
assert((disabled.candidateGateCalls or 0) == 0 and (disabled.TestParseCalls or 0) == 0,
  "parsing-off mode entered candidate or parser work")
assert((disabled.queueRecordsCreated or 0) == 0 and (disabled.filtersCurrentlyInstalled or 0) == 0,
  "parsing-off mode created queue work or retained filters")
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
chat.Apply()

local oldProbe = SignalFireFastChatLinks.TestParse
SignalFireFastChatLinks.TestParse = function() error("injected parser failure") end
nowValue = nowValue + 7
ingest("LFM MC need heals injected", "ParserFailure")
assert(BronzeLFG._sfChatQueueProcessing == nil and BronzeLFG._sfP3SuppressNotify == nil,
  "parser failure left an active-state guard set")
assert((SignalFireChatRuntime151._exactInFlightCount or 0) == 0,
  "parser failure left the exact resolver guard set")
SignalFireFastChatLinks.TestParse = oldProbe

local oldRefresh = BronzeLFG.RequestPublicGroupsRefresh
BronzeLFG.RequestPublicGroupsRefresh = function() error("injected refresh failure") end
nowValue = nowValue + 7
ingest("LFM NAXX need tank", "RefreshFailure")
drainQueue()
assert(BronzeLFG._sfChatQueueProcessing == nil and BronzeLFG._sfP3SuppressNotify == nil,
  "processing error left an active-state guard set")
BronzeLFG.RequestPublicGroupsRefresh = oldRefresh

BronzeLFG:SF151_ResetChatRuntimeStats()
nowValue = nowValue + 7
for i = 1, 45 do ingest("LFM MC need healer run " .. tostring(i), "Overflow" .. tostring(i)) end
local overflow = BronzeLFG:SF151_GetChatPublicIndexDiagnostics()
assert(overflow.queueDepth == 40, "queue maximum was not enforced")
assert((overflow.counters.queueDrops or 0) == 5, "queue drop accounting was incorrect")
local worker = assert(BronzeLFG._sfP3Frame:GetScript("OnUpdate"), "chat queue update missing")
worker(BronzeLFG._sfP3Frame, 0.01)
assert(#(BronzeLFG._sfP3Queue or {}) == 36, "worker exceeded the four-record frame budget")
drainQueue()
assert(#(BronzeLFG._sfP3Queue or {}) == 0, "overflow queue did not recover")

print("parser regression harness: PASS (" .. tostring(result.passed) .. " passed, "
  .. tostring(result.skipped) .. " skipped, 0 failed)")
