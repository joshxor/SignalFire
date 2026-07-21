local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local CL = assert(SignalFireCacheLifecycle151, "cache lifecycle owner did not load")
local T = assert(SignalFireTimer151, "Phase 4 lifecycle owner did not load")
assert(CL.generation == "1.5.2-phase12a", "unexpected cache lifecycle generation")
assert(CL.eventFrame == nil, "cache lifecycle retained a chat/lifecycle event frame")
assert(CL.minimumAutomaticInterval == 30, "automatic interval is incorrect")

local testNow = 1200000
local profileClock = 5000
function time() return math.floor(testNow) end
function GetTime() return testNow end
function debugprofilestop() profileClock = profileClock + .05; return profileClock end

SignalFirePerf151.enabled = true
B:SF151_ResetCacheLifecycleStats()
CL.lastAutomaticRunAt = nil
CL.chatEvents = 0

local function count(values)
  local result = 0
  for _ in pairs(values or {}) do result = result + 1 end
  return result
end

local function seed(target, amount, prefix)
  for index = 1, amount do
    target[prefix .. tostring(index)] = {id=prefix .. tostring(index), seen=testNow,
      created=testNow, lastSeen=testNow, lastPostSeen=testNow, applied=testNow}
  end
end

BronzeLFG_DB = BronzeLFG_DB or {}
BronzeLFG_DB.network = BronzeLFG_DB.network or {}
BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
BronzeLFG_DB.whoPlayers = {}
BronzeLFG_DB.whoGuilds = {}

B.publicGroups = {}; seed(B.publicGroups, CL.maximums.publicGroups, "public-")
B.listings = {}; seed(B.listings, CL.maximums.listings, "listing-")
B.myListing = B.listings["listing-1"]
B.applicants = {}; seed(B.applicants, CL.maximums.applicants, "applicant-")
B.chatGuildListings = {}; seed(B.chatGuildListings, CL.maximums.chatGuildListings, "chat-guild-")
B.guilds = {}; seed(B.guilds, CL.maximums.guilds, "guild-")
B.guildPosts = {}; seed(B.guildPosts, CL.maximums.guildPosts, "guild-post-")
B.onlineUsers = {}; seed(B.onlineUsers, CL.maximums.onlineUsers, "online-")
B.sfnStatuses = {}; seed(B.sfnStatuses, CL.maximums.sfnStatuses, "status-")
B._sf151KnownClassNames = {}
for index = 1, CL.maximums.knownClassNames do B._sf151KnownClassNames["class-" .. index] = "MAGE" end
B._notifySeen569 = {}
for index = 1, CL.maximums.notificationSeen do B._notifySeen569["notify-" .. index] = testNow end
B.invasionUsers = {}; seed(B.invasionUsers, CL.maximums.invasionUsers, "inv-user-")
B.invasionOtherPlayers = {}; seed(B.invasionOtherPlayers, CL.maximums.invasionOtherPlayers, "inv-player-")
B.invasionBeacons = {}; seed(B.invasionBeacons, CL.maximums.invasionBeacons, "beacon-")

seed(BronzeLFG_DB.whoPlayers, CL.maximums.whoPlayers, "who-player-")
for guildIndex = 1, CL.maximums.whoGuilds do
  local guild = {id="who-guild-" .. guildIndex, seen=testNow, lastSeen=testNow, members={}}
  seed(guild.members, CL.maximums.whoMembers, "member-" .. guildIndex .. "-")
  BronzeLFG_DB.whoGuilds[guild.id] = guild
end

local network = BronzeLFG_DB.network
network.favoriteAlertCooldowns = {}
network.favoriteAlertSeenListings = {}
network.favoriteOnlineSeen = {}
for index = 1, CL.maximums.favoriteAlertState do
  network.favoriteAlertCooldowns["cooldown-" .. index] = testNow
  network.favoriteAlertSeenListings["seen-" .. index] = testNow
  network.favoriteOnlineSeen["online-" .. index] = testNow
end

local shared = BronzeLFG_DB.signalFireNetwork
shared.events, shared.notices = {}, {}
shared.eventAlertSeen, shared.eventAlertKnown = {}, {}
shared.eventAlertCooldowns, shared.eventDismissed = {}, {}
shared.noticeSeen, shared.noticeDismissed = {}, {}
for index = 1, 60 do
  local id = "event-" .. index
  shared.events[index] = {id=id, created=testNow, expires=testNow + 3600}
  shared.eventAlertSeen[id], shared.eventAlertKnown[id] = true, true
  shared.eventAlertCooldowns[id], shared.eventDismissed[id] = testNow, true
end
for index = 1, 40 do
  local id = "notice-" .. index
  shared.notices[index] = {id=id, created=testNow, expires=testNow + 3600}
  shared.noticeSeen[id], shared.noticeDismissed[id] = true, true
end

local baseline = {
  public=count(B.publicGroups), whoPlayers=count(BronzeLFG_DB.whoPlayers),
  whoGuilds=count(BronzeLFG_DB.whoGuilds), events=#shared.events, notices=#shared.notices,
}
for index = 1, 100000 do
  local event = index % 3 == 0 and "CHAT_MSG_CHANNEL"
    or (index % 3 == 1 and "CHAT_MSG_SAY" or "CHAT_MSG_YELL")
  assert(event and CL:ObserveChat() == false, "chat observation started maintenance")
end
local report = CL:GetDiagnostics(false)
assert(report.chatEvents == 100000, "chat observations were not counted")
assert((report.runs or 0) == 0 and report.chatMaintenanceRuns == 0,
  "chat triggered cache maintenance")
assert(count(B.publicGroups) == baseline.public and count(BronzeLFG_DB.whoPlayers) == baseline.whoPlayers
    and count(BronzeLFG_DB.whoGuilds) == baseline.whoGuilds
    and #shared.events == baseline.events and #shared.notices == baseline.notices,
  "chat observation mutated a cache")

for _ = 1, 100 do CL:MaybeRun("automatic-burst") end
report = CL:GetDiagnostics(false)
assert(report.automaticRunRequests == 100 and report.automaticRunsExecuted == 1
    and report.automaticRunsCooldownSkipped == 99,
  "automatic burst was not collapsed to one cleanup")

testNow = testNow + CL.minimumAutomaticInterval + 1
assert(CL:MaybeRun("automatic-after-interval") == true,
  "automatic maintenance did not recover after its interval")
report = CL:GetDiagnostics(false)
assert(report.automaticRunsExecuted == 2, "second automatic cleanup did not execute")

local command = assert(B.SF151_HandlePerfSlash, "manual cleanup command owner is missing")
local cleanupMessage
local previousAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, message) cleanupMessage = message end
assert(command(B, "perf cleanup") == true and command(B, "perf cleanup") == true,
  "manual cleanup command did not execute twice")
DEFAULT_CHAT_FRAME.AddMessage = previousAddMessage
report = CL:GetDiagnostics(false)
assert(report.forcedRuns == 2, "manual cleanup was not forced twice")
assert(string.find(tostring(cleanupMessage), " ms", 1, true),
  "enabled diagnostics did not report manual cleanup time")

testNow = testNow + CL.minimumAutomaticInterval + 1
local lifecycle = assert(T.eventFrame and T.eventFrame:GetScript("OnEvent"),
  "Phase 4 lifecycle event owner is missing")
lifecycle(T.eventFrame, "PLAYER_LOGIN")
lifecycle(T.eventFrame, "PLAYER_ENTERING_WORLD")
report = CL:GetDiagnostics(false)
assert(report.automaticRunRequests == 103 and report.automaticRunsExecuted == 3
    and report.automaticRunsCooldownSkipped == 100,
  "login/world-entry caused duplicate automatic cleanup")
assert(report.loginMaintenanceRuns == 1 and report.worldEntryMaintenanceRuns == 0,
  "lifecycle execution reasons were not attributed correctly")
assert(report.chatMaintenanceRuns == 0 and report.maximumCleanupMs > 0,
  "healthy lifecycle diagnostics are incorrect")
for _, field in ipairs({"compatibilityMs", "publicMs", "browseMs", "networkMs",
    "guildMs", "whoMs", "alertsMs", "communityMs"}) do
  assert(type(report[field]) == "number", "missing per-pass timing: " .. field)
end
assert(#(report.errors or {}) == 0 and CL.running == false,
  "hotfix stress test reported an error or retained its guard")

print("cache chat-trigger hotfix harness: PASS (chat=100000, auto="
  .. tostring(report.automaticRunsExecuted) .. "/" .. tostring(report.automaticRunRequests)
  .. ", skipped=" .. tostring(report.automaticRunsCooldownSkipped)
  .. ", forced=" .. tostring(report.forcedRuns)
  .. ", passesMs=" .. table.concat({
    tostring(report.compatibilityMs), tostring(report.publicMs), tostring(report.browseMs),
    tostring(report.networkMs), tostring(report.guildMs), tostring(report.whoMs),
    tostring(report.alertsMs), tostring(report.communityMs)}, "/") .. ")")
