local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
assert(B.SF151_RepairReleaseDatabase, "Phase 10 release migration did not load")

local function migrate(db)
  local ok, report = B:SF151_RepairReleaseDatabase(db)
  assert(ok and type(report) == "table", "release migration failed")
  return report
end

local fresh = {}
local freshReport = migrate(fresh)
assert(fresh.options.inlineChatLinks == false, "fresh install enabled Chat Links")
assert(fresh.options.publicGroups == true, "fresh install disabled Public Groups parsing")
assert(fresh.options.serverProfile == "Triumvirate", "fresh install profile was not repaired")
assert(fresh.options.scale == 1, "fresh install scale was not repaired")
assert(fresh.options.chatLinkScope == "main", "fresh install link scope was not repaired")
assert(fresh.options.modulesByProfile.Ascension.invasions == false,
  "Ascension Invasions migration is unsafe")
assert(freshReport.chatLinks == false, "fresh migration report is incorrect")

local explicitTrue = {options={inlineChatLinks=true, publicGroups=true,
  serverProfile="Ascension", scale=1.2, chatLinkScope="all", custom="preserve"}}
migrate(explicitTrue)
assert(explicitTrue.options.inlineChatLinks == true, "explicit Chat Links On was overwritten")
assert(explicitTrue.options.serverProfile == "Ascension" and explicitTrue.options.scale == 1.2,
  "valid profile or scale was overwritten")
assert(explicitTrue.options.chatLinkScope == "all" and explicitTrue.options.custom == "preserve",
  "valid release settings were overwritten")

local explicitFalse = {options={inlineChatLinks=false, publicGroups=true,
  serverProfile="Triumvirate", scale=.9, chatLinkScope="visible"}}
migrate(explicitFalse)
assert(explicitFalse.options.inlineChatLinks == false, "explicit Chat Links Off was overwritten")
assert(explicitFalse.options.scale == .9 and explicitFalse.options.chatLinkScope == "visible",
  "valid scale or link scope was overwritten")

local malformed = {options="broken", profile="broken", favorites="broken",
  network="broken", signalFireNetwork="broken", retained={value=17}}
local malformedReport = migrate(malformed)
assert(type(malformed.options) == "table" and type(malformed.profile) == "table",
  "malformed root structures were not repaired")
assert(type(malformed.network.favoriteAlertCooldowns) == "table",
  "malformed Network structures were not repaired")
assert(type(malformed.signalFireNetwork.events) == "table"
    and type(malformed.signalFireNetwork.notices) == "table",
  "malformed community structures were not repaired")
assert(malformed.retained.value == 17, "unrelated SavedVariables data was changed")
assert(malformedReport.repairs > 0, "malformed migration reported no repairs")

local invalidModules = {options={serverProfile="Ascension", scale=1, chatLinkScope="main",
  modules={chatParsing="yes"}, modulesByProfile={Triumvirate={guildBrowser=7},
    Ascension={invasions=true, notices="required"}}, moduleSavedSettings={}}}
migrate(invalidModules)
assert(invalidModules.options.modules.chatParsing == nil
    and invalidModules.options.modulesByProfile.Triumvirate.guildBrowser == nil
    and invalidModules.options.modulesByProfile.Ascension.notices == nil
    and invalidModules.options.modulesByProfile.Ascension.invasions == false,
  "invalid module state was not repaired safely")

local upgrade = {
  options={inlineChatLinks=true, publicGroups=false, publicStrict=false,
    parseGuildRecruitment=false, serverProfile="InvalidProfile", scale="broken",
    chatLinkScope="broken", modulesByProfile="broken", moduleSavedSettings="broken"},
  signalFireNetwork={events={{id="event-1"}}, notices={{id="notice-1"}}},
  network={favoriteAlertCooldowns={A=1}}, favorites={Tester=true}, retained="keep",
}
local first = migrate(upgrade)
local events = upgrade.signalFireNetwork.events
local notices = upgrade.signalFireNetwork.notices
local favorites = upgrade.favorites
assert(upgrade.options.inlineChatLinks == true, "legacy explicit Chat Links choice was lost")
assert(upgrade.options.publicGroups == false and upgrade.options.publicStrict == false
    and upgrade.options.parseGuildRecruitment == false,
  "explicit parsing settings were changed")
assert(upgrade.options.serverProfile == "Triumvirate" and upgrade.options.scale == 1,
  "invalid profile or scale was not repaired")
assert(upgrade.retained == "keep", "unknown upgrade field was removed")
local second = migrate(upgrade)
assert(second.repairs == 0, "release migration is not idempotent")
assert(upgrade.signalFireNetwork.events == events and upgrade.signalFireNetwork.notices == notices
    and upgrade.favorites == favorites,
  "idempotent migration replaced valid data tables")
assert(first.repairs > second.repairs, "migration repair accounting is incorrect")

local frameBefore = B.frame
local timer = SignalFireEventTimers151
local timerActiveBefore = timer and timer.delayedFrame and timer.delayedFrame:IsShown()
for _ = 1, 100 do migrate(upgrade) end
assert(B.frame == frameBefore, "release migration constructed UI")
assert(not timer or not timer.delayedFrame or timer.delayedFrame:IsShown() == timerActiveBefore,
  "release migration changed timer state")

assert(BronzeLFG_DB.options.inlineChatLinks == false,
  "the canary startup did not force the installed Chat Links setting Off")
local globalReport = migrate(BronzeLFG_DB)
assert(globalReport.chatLinks == false, "global migration report lost the canary startup state")

BronzeLFG_DB.options.inlineChatLinks = true

if B.SF143_SetServerProfile then
  B:SF143_SetServerProfile("Triumvirate", true)
  assert(BronzeLFG_DB.options.inlineChatLinks == true, "profile switch disabled explicit Chat Links On")
  B:SF143_SetServerProfile("Ascension", true)
  assert(BronzeLFG_DB.options.inlineChatLinks == true, "profile return disabled explicit Chat Links On")
end
BronzeLFG_DB.options.modulesByProfile.Ascension = {}
migrate(BronzeLFG_DB)
assert(BronzeLFG_DB.options.inlineChatLinks == true,
  "profile-settings reset disabled explicit Chat Links On")
migrate(BronzeLFG_DB)
assert(BronzeLFG_DB.options.inlineChatLinks == true, "reload migration disabled explicit Chat Links On")

local chat = assert(SignalFireChatRuntime151, "chat runtime is unavailable")
BronzeLFG_DB.options.inlineChatLinks = false
BronzeLFG_DB.options.publicGroups = true
chat.Apply()
local native = "LFM MC need healer |Hitem:12345:0:0:0|h[Native Item]|h"
chat.IngestSource("MigrationTester", native, "3. Newcomers", "CHAT_MSG_CHANNEL")
local _, rendered = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", native, "MigrationTester",
  nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
assert(not string.find(rendered or "", "bronzelfgpub:", 1, true),
  "Chat Links Off injected a SignalFire hyperlink")
assert(string.find(rendered or "", "|Hitem:12345", 1, true),
  "Chat Links Off damaged an ordinary native hyperlink")
local queue = B._sfP3Frame and B._sfP3Frame:GetScript("OnUpdate")
local guard = 0
while #(B._sfP3Queue or {}) > 0 do
  assert(queue, "chat parser queue owner is missing")
  queue(B._sfP3Frame, .1)
  guard = guard + 1
  assert(guard < 100, "chat parser queue did not drain")
end
local found = false
for _, row in pairs(B.publicGroups or {}) do
  if row.player == "MigrationTester" then found = true; break end
end
assert(found, "Chat Links Off disabled Public Groups parsing")

local resetAll = {}
migrate(resetAll)
assert(resetAll.options.inlineChatLinks == false and resetAll.options.publicGroups == true,
  "reset-all state did not restore the safe release defaults")

print("release migration harness: PASS (freshLinks=false, malformedRepairs="
  .. tostring(malformedReport.repairs) .. ", idempotentRepairs=" .. tostring(second.repairs) .. ")")
