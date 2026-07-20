local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
local migrate = assert(B.SF151_RepairReleaseDatabase, "release migration is unavailable")
local chat = assert(SignalFireChatRuntime151, "chat runtime is unavailable")

assert(SignalFire_VERSION == "1.5.2", "global version is not 1.5.2")
assert(SignalFire_RELEASE_CHANNEL == "rc", "release channel is not RC")
assert(SignalFire_RELEASE_NAME == "SignalFire 1.5.2 Phase 12B RC", "release name is inconsistent")
assert(SignalFire_GetVersion() == "1.5.2", "authoritative version getter is inconsistent")
assert(SignalFire_GetTitleText() == "SignalFire v1.5.2", "production title is inconsistent")
assert(SignalFirePerf151 and SignalFirePerf151.enabled == false,
  "performance diagnostics did not default Off")
assert(SignalFireStability151 and SignalFireStability151.enabled == false
    and SignalFireStability151.deep == false,
  "stability or deep diagnostics did not default Off")
assert(B.SignalFireTestSay ~= true, "test-say mode defaulted On")
assert(not SignalFireStability151.eventFrame:GetScript("OnUpdate"),
  "production diagnostics installed an idle OnUpdate")

local function repair(db)
  local ok, report = migrate(B, db)
  assert(ok and type(report) == "table", "migration failed")
  return report
end

local cases = {
  {name="fresh", db={}, links=false},
  {name="explicit-on", db={options={inlineChatLinks=true}}, links=true},
  {name="explicit-off", db={options={inlineChatLinks=false}}, links=false},
  {name="missing-legacy", db={options={inlineChatLinks=nil}}, links=false},
  {name="malformed-profile", db={options={serverProfile="invalid"}}, links=false},
  {name="malformed-scale", db={options={scale="huge"}}, links=false},
  {name="malformed-modules", db={options={modules="bad", modulesByProfile=9}}, links=false},
  {name="stale-network", db={network="bad", signalFireNetwork={events={}}}, links=false},
  {name="stale-community", db={signalFireNetwork={events="bad", notices=17}}, links=false},
  {name="invalid-optional-caches", db={network={favoriteAlertCooldowns="bad"},
    signalFireNetwork={eventAlertSeen="bad", noticeDismissed=42}}, links=false},
  {name="phase8-shape", db={options={serverProfile="Ascension", scale=1.1,
    inlineChatLinks=true, chatLinkScope="visible"}, signalFireNetwork={events={}, notices={}}}, links=true},
  {name="phase9-shape", db={options={serverProfile="Triumvirate", scale=.9,
    inlineChatLinks=false, modulesByProfile={Triumvirate={}, Ascension={}}}, network={}}, links=false},
  {name="phase10-shape", db={options={sf151Phase10ReleaseMigration=true,
    sf151Phase10ChatLinkDefaultMigrated=true, inlineChatLinks=true}}, links=true},
  {name="phase10b-shape", db={options={sf151Phase10ReleaseMigration=true,
    inlineChatLinks=false, chatLinkScope="all"}, signalFireNetwork={events={}, notices={}}}, links=false},
}

local frameBefore = B.frame
local lazyBefore = SignalFireLazyPanels151 and SignalFireLazyPanels151.shellBuilt
local timer = SignalFireEventTimers151
local delayedBefore = timer and timer.delayedFrame and timer.delayedFrame:IsShown()
for _, case in ipairs(cases) do
  local report = repair(case.db)
  assert(case.db.options.inlineChatLinks == case.links, case.name .. " Chat Links result is wrong")
  assert(report.chatLinks == case.links, case.name .. " report is wrong")
  assert(case.db.options.publicGroups ~= false, case.name .. " disabled Public Groups")
  assert(case.db.options.serverProfile == "Ascension" or case.db.options.serverProfile == "Triumvirate",
    case.name .. " left an invalid profile")
  assert(type(case.db.options.modules) == "table"
      and type(case.db.options.modulesByProfile) == "table",
    case.name .. " left invalid module state")
  assert(case.db.options.modulesByProfile.Ascension.invasions == false,
    case.name .. " enabled Ascension Invasions")
  local events, notices = case.db.signalFireNetwork.events, case.db.signalFireNetwork.notices
  local second = repair(case.db)
  assert(second.repairs == 0, case.name .. " migration is not idempotent")
  assert(case.db.signalFireNetwork.events == events and case.db.signalFireNetwork.notices == notices,
    case.name .. " migration replaced valid community tables")
end
assert(B.frame == frameBefore, "migration constructed the main UI")
assert(not SignalFireLazyPanels151 or SignalFireLazyPanels151.shellBuilt == lazyBefore,
  "migration constructed a lazy panel shell")
assert(not timer or not timer.delayedFrame or timer.delayedFrame:IsShown() == delayedBefore,
  "migration woke the delayed timer")

local originalDB, originalRealm = BronzeLFG_DB, GetRealmName
BronzeLFG_DB = {}
repair(BronzeLFG_DB)
function GetRealmName() return "Bronzebeard" end
BronzeLFG_DB.options.serverProfileManual = nil
B:SF143_EnsureDetectedProfile()
assert(BronzeLFG_DB.options.serverProfile == "Ascension", "Ascension profile was not detected")
assert(BronzeLFG_DB.options.modulesByProfile.Ascension.invasions == false,
  "detected Ascension profile enabled Invasions")
BronzeLFG_DB = {}
repair(BronzeLFG_DB)
function GetRealmName() return "Triumvirate" end
BronzeLFG_DB.options.serverProfileManual = nil
B:SF143_EnsureDetectedProfile()
assert(BronzeLFG_DB.options.serverProfile == "Triumvirate", "Triumvirate profile was not detected")
BronzeLFG_DB, GetRealmName = originalDB, originalRealm

BronzeLFG_DB.options.inlineChatLinks = false
BronzeLFG_DB.options.publicGroups = true
chat.Apply()
local settings = assert(B:SFCP_GetSettings(), "effective chat settings are unavailable")
assert(settings.inlineChatLinks == false and settings.publicGroups == true,
  "effective options do not reflect Chat Links Off")

local nativeLinks = {
  "|Hitem:12345:0:0:0|h[Native Item]|h",
  "|Hspell:133|h[Fireball]|h",
  "|Hquest:42:60|h[A Native Quest]|h",
  "|Hachievement:6:Player-1:1:1:1:1:0:0:0:0|h[Level 10]|h",
  "|Hplayer:NativePlayer|h[NativePlayer]|h",
  "|Htrade:51313:450:450:abcdef:1234|h[Enchanting]|h",
}
for index, nativeLink in ipairs(nativeLinks) do
  local message = "LFM MC need healer " .. nativeLink
  chat.IngestSource("Native" .. tostring(index), message, "3. Newcomers", "CHAT_MSG_CHANNEL")
  local _, rendered = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", message,
    "Native" .. tostring(index), nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
  assert(string.find(rendered or "", nativeLink, 1, true), "native hyperlink was changed")
  assert(not string.find(rendered or "", "bronzelfgpub:", 1, true),
    "Chat Links Off injected a SignalFire hyperlink")
end

local updateQueue = B._sfP3Frame and B._sfP3Frame:GetScript("OnUpdate")
local guard = 0
while #(B._sfP3Queue or {}) > 0 do
  assert(updateQueue, "chat queue owner is missing")
  updateQueue(B._sfP3Frame, .1)
  guard = guard + 1
  assert(guard < 100, "chat queue did not drain")
end
local parsed = false
for _, row in pairs(B.publicGroups or {}) do
  if string.find(tostring(row.player or ""), "Native", 1, true) then parsed = true; break end
end
assert(parsed, "Chat Links Off disabled Public Groups parsing")

BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
repair(BronzeLFG_DB)
chat.Apply()
chat.IngestSource("ExplicitOn", "LFM MC need healer", "3. Newcomers", "CHAT_MSG_CHANNEL")
while #(B._sfP3Queue or {}) > 0 do updateQueue(B._sfP3Frame, .1) end
local _, linked = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", "LFM MC need healer",
  "ExplicitOn", nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
assert(string.find(linked or "", "bronzelfgpub:", 1, true),
  "explicit Chat Links On did not produce a SignalFire link")
local first = string.find(linked or "", "bronzelfgpub:", 1, true)
assert(not string.find(linked or "", "bronzelfgpub:", first + 1, true),
  "explicit Chat Links On produced duplicate links")
repair(BronzeLFG_DB)
assert(BronzeLFG_DB.options.inlineChatLinks == true,
  "explicit Chat Links On did not survive reload migration")
assert(#(B._sfP3Queue or {}) <= 40, "chat queue exceeded its bound")

assert(B:SF151_HandleDiagnosticSlash("diag") == true,
  "diagnostic help command is unavailable")
assert(SignalFireStability151.enabled == false and SignalFireStability151.deep == false,
  "diagnostic help enabled diagnostics")

print("production release harness: PASS (migrationCases=" .. tostring(#cases)
  .. ", nativeLinks=" .. tostring(#nativeLinks) .. ", title=" .. SignalFire_GetTitleText() .. ")")
