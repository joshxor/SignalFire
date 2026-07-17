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
function objectMethods:AddMessage(text) self.lastMessage = text end

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

local chat = assert(SignalFireChatRuntime151, "Phase 5 chat owner was not loaded")
assert(chat.generation == "1.5.1-perf-phase5", "wrong final chat/Public Groups owner")
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
local message = "LFM MC 1 HEALER"
local linkedId = nil
for i = 1, 10 do
  local rendered = filter(_G["ChatFrame" .. i], message, "Tester")
  assert(string.find(rendered, "Molten Core", 1, true), "receiving frame missed the activity link")
  local id = string.match(rendered, "bronzelfgpub:([^|]+)")
  assert(id and id ~= "", "activity link did not contain a stable row ID")
  linkedId = linkedId or id
  assert(linkedId == id, "receiving frames did not reuse one stable row ID")
end
assert(#(BronzeLFG._sfP3Queue or {}) == 1, "one source message created multiple parser jobs")
assert(tableCount(BronzeLFG.publicGroups) == 0, "rendering created a preview Public Groups row")

ChatFrame1.AddMessage = function(self, text) self.lastMessageValue = text end
chat.Apply()
ChatFrame1:AddMessage("[3. Newcomers] [Tester]: " .. message)
assert(string.find(ChatFrame1.lastMessageValue or "", "bronzelfgpub:" .. linkedId, 1, true),
  "AddMessage fallback did not reuse the source decision")
local beforeUnknown = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters.testParseCalls
ChatFrame1:AddMessage("[3. Newcomers] [UnknownTester]: LFM MC need heals")
local afterUnknown = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters.testParseCalls
assert(beforeUnknown == afterUnknown, "AddMessage fallback called TestParse")

BronzeLFG:OpenPublicGroupLink(linkedId, "Molten Core - Need H")
assert(BronzeLFG.publicGroups[linkedId], "immediate link click did not finish the queued canonical row")
assert(BronzeLFG.selectedPublic == linkedId, "immediate link click did not select the exact canonical row")
drainQueue()
assert(tableCount(BronzeLFG.publicGroups) == 1, "one accepted record did not create exactly one row")
assert(BronzeLFG.publicGroups[linkedId], "deferred upsert did not preserve the link target ID")
assert(BronzeLFG.publicGroups[linkedId].activity == "Molten Core", "activity specificity was lost")
assert(string.find(tostring(BronzeLFG.publicGroups[linkedId].roles or ""), "H", 1, true), "role specificity was lost")
local firstStats = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters
assert((firstStats.filterCalls or 0) == 10, "ten receiving frames did not produce ten filter receipts")
assert((firstStats.sourceEvents or 0) == 1, "one source message produced multiple source decisions")
assert((firstStats.testParseCalls or 0) == 1, "one source message was classified more than once")
assert((firstStats.enqueued or 0) == 1 and (firstStats.processed or 0) == 1,
  "one source message did not produce one queue record")
assert((firstStats.consolidationRowsScanned or 0) == 0, "first canonical upsert scanned Public Groups")
assert((firstStats.addMessageParseCalls or 0) == 0, "AddMessage performed parsing")

for i = 1, 10 do
  local rendered = filter(_G["ChatFrame" .. i], message, "Tester")
  assert(string.find(rendered, "bronzelfgpub:" .. linkedId, 1, true), "repost missed stable activity link")
end
assert(#(BronzeLFG._sfP3Queue or {}) == 0, "same-window repost queued a second parser job")

nowValue = nowValue + 7
filter(ChatFrame1, message, "Tester")
drainQueue()
assert(tableCount(BronzeLFG.publicGroups) == 1, "TTL repost created a duplicate row")
assert(BronzeLFG.publicGroups[linkedId], "TTL repost changed the stable row ID")

nowValue = nowValue + 7
local second = filter(ChatFrame1, "LFG RDF", "Tester")
local secondId = string.match(second, "bronzelfgpub:([^|]+)")
assert(secondId and secondId ~= linkedId, "different activity reused the wrong canonical identity")
nowValue = nowValue + 7
local third = filter(ChatFrame1, message, "OtherTester")
local thirdId = string.match(third, "bronzelfgpub:([^|]+)")
assert(thirdId and thirdId ~= linkedId, "different player reused the wrong canonical identity")
drainQueue()
assert(tableCount(BronzeLFG.publicGroups) == 3, "distinct canonical listings did not remain distinct")

nowValue = nowValue + 7
local protocol = filter(ChatFrame1, "BLFG312~PRESENCE~payload", "Protocol")
assert(protocol == "BLFG312~PRESENCE~payload", "protocol traffic was rewritten")
assert(#(BronzeLFG._sfP3Queue or {}) == 0, "protocol traffic entered the parser queue")

local parseBefore = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters.testParseCalls
ChatFrame1:AddMessage("[3. Newcomers] [NoSource]: LFM MC 1 HEALER")
local parseAfter = BronzeLFG:SF151_GetChatPublicIndexDiagnostics().counters.testParseCalls
assert(parseBefore == parseAfter, "lookup-only AddMessage path performed classification")

BronzeLFG_DB.options.inlineChatLinks = false
nowValue = nowValue + 7
local plain = filter(ChatFrame1, "LFM BWL need tank", "Linkless")
assert(not string.find(plain, "bronzelfgpub:", 1, true), "links-disabled mode still rendered a link")
assert(#(BronzeLFG._sfP3Queue or {}) == 1, "links-disabled mode stopped background parsing")
drainQueue()
BronzeLFG_DB.options.inlineChatLinks = true

BronzeLFG_DB.options.chatLinkScope = "main"
nowValue = nowValue + 7
local hidden = filter(ChatFrame3, "LFM ZG need healer", "ScopeTester")
local main = filter(ChatFrame1, "LFM ZG need healer", "ScopeTester")
assert(not string.find(hidden, "bronzelfgpub:", 1, true), "Main Chat Only linked another frame")
assert(string.find(main, "bronzelfgpub:", 1, true), "Main Chat Only missed ChatFrame1")
drainQueue()
BronzeLFG_DB.options.chatLinkScope = "all"

BronzeLFG:SF151_ResetChatRuntimeStats()
nowValue = nowValue + 7
filter(ChatFrame1, "LFM AQ40 need dps", "Indexed")
drainQueue()
local indexStats = BronzeLFG:SF151_GetChatPublicIndexDiagnostics()
assert(indexStats.addMessageParseCalls == 0, "AddMessage parse counter was non-zero")
assert((indexStats.counters.consolidationRowsScanned or 0) == 0, "steady-state upsert scanned Public Groups")
assert((indexStats.counters.indexFullScans or 0) == 0, "steady-state upsert rebuilt the canonical index")
assert((indexStats.counters.refreshDirtyRequests or 0) == 1, "one mutation requested more than one refresh")

local oldProbe = SignalFireFastChatLinks.TestParse
SignalFireFastChatLinks.TestParse = function() error("injected parser failure") end
nowValue = nowValue + 7
local parserFailure = filter(ChatFrame1, "LFM MC need heals injected", "ParserFailure")
assert(parserFailure == "LFM MC need heals injected", "parser failure changed rendered chat")
assert(#(BronzeLFG._sfP3Queue or {}) == 0, "parser failure queued a record")
SignalFireFastChatLinks.TestParse = oldProbe

local oldRefresh = BronzeLFG.RequestPublicGroupsRefresh
BronzeLFG.RequestPublicGroupsRefresh = function() error("injected refresh failure") end
nowValue = nowValue + 7
filter(ChatFrame1, "LFM NAXX need tank", "RefreshFailure")
drainQueue()
assert(BronzeLFG._sfChatQueueProcessing == nil and BronzeLFG._sfP3SuppressNotify == nil,
  "processing error left an active-state guard set")
BronzeLFG.RequestPublicGroupsRefresh = oldRefresh
nowValue = nowValue + 7
filter(ChatFrame1, "LFM ONY need healer", "AfterFailure")
drainQueue()
assert(BronzeLFG._sfChatQueueProcessing == nil, "queue did not recover after an injected error")

BronzeLFG:SF151_ResetChatRuntimeStats()
nowValue = nowValue + 7
for i = 1, 45 do filter(ChatFrame1, "LFM MC need healer run " .. tostring(i), "Overflow" .. tostring(i)) end
local overflow = BronzeLFG:SF151_GetChatPublicIndexDiagnostics()
assert(overflow.queueDepth == 40, "queue maximum was not enforced")
assert((overflow.counters.queueDrops or 0) == 5, "queue drop accounting was incorrect")
drainQueue()
assert(#(BronzeLFG._sfP3Queue or {}) == 0, "overflow queue did not recover")

print("parser regression harness: PASS (" .. tostring(result.passed) .. " passed, "
  .. tostring(result.skipped) .. " skipped, 0 failed)")
