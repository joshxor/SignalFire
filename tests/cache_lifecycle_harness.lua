local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
local CL = assert(SignalFireCacheLifecycle151, "Phase 9 cache lifecycle owner did not load")
assert(CL.generation == "1.5.2-phase12a", "unexpected cache lifecycle owner")
assert(CL.eventFrame == nil, "cache lifecycle retained an independent event owner")

local testNow = 900000
local profileClock = 1000
function time() return math.floor(testNow) end
function GetTime() return testNow end
function debugprofilestop() profileClock = profileClock + .05; return profileClock end

SignalFirePerf151.enabled = true
B:SF151_ResetCacheLifecycleStats()

local function count(values)
  local total = 0
  for _ in pairs(values or {}) do total = total + 1 end
  return total
end

local function seedRows(target, amount, prefix, stampField, oldEvery)
  for index = 1, amount do
    local stamp = testNow - index
    if oldEvery and index % oldEvery == 0 then stamp = testNow - 2000000 end
    target[prefix .. tostring(index)] = {id=prefix .. tostring(index), seen=stamp, created=stamp,
      lastSeen=stamp, lastPostSeen=stamp, applied=stamp, [stampField or "seen"]=stamp}
  end
end

BronzeLFG_DB = BronzeLFG_DB or {}
BronzeLFG_DB.network = BronzeLFG_DB.network or {}
BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
local network = BronzeLFG_DB.network
local shared = BronzeLFG_DB.signalFireNetwork

B.publicGroups = {}
seedRows(B.publicGroups, 620, "public-", "seen")
B.listings = {}
seedRows(B.listings, 330, "listing-", "seen", 7)
B.myListing = B.listings["listing-1"]
B.applicants = {}
seedRows(B.applicants, 180, "applicant-", "applied", 5)
B.chatGuildListings = {}
seedRows(B.chatGuildListings, 300, "chat-guild-", "lastPostSeen", 6)
B.guilds = {}
seedRows(B.guilds, 300, "guild-", "lastSeen")
B.guildPosts = {}
seedRows(B.guildPosts, 300, "guild-post-", "lastPostSeen", 9)
B.onlineUsers = {}
seedRows(B.onlineUsers, 620, "online-", "seen", 8)
B.sfnStatuses = {}
seedRows(B.sfnStatuses, 620, "status-", "seen", 8)
B._sf151KnownClassNames = {}
for index = 1, 350 do B._sf151KnownClassNames["player-" .. index] = "MAGE" end
B._notifySeen569 = {}
for index = 1, 350 do B._notifySeen569["notice-" .. index] = testNow - index end

B.invasionUsers = {}
B.invasionOtherPlayers = {}
B.invasionBeacons = {}
seedRows(B.invasionUsers, 300, "invasion-user-", "seen")
seedRows(B.invasionOtherPlayers, 300, "invasion-other-", "seen")
seedRows(B.invasionBeacons, 300, "beacon-", "seen")

B.sfamSeenPublic = {orphan=true, ["public-1"]=true}
B.sfamSeenApplicants = {orphan=true, ["applicant-1"]=true}
B._inlinePublicChatCache = {dead={}}
B._sfDirectLinkCache = {dead={}}
B._sffclSeen = {dead=true}
B._sffclLastRow = {dead={}}
B._sffclFilterCache = {dead={}}
B._sffclDisplayCache = {dead={}}

BronzeLFG_DB.whoPlayers = {}
BronzeLFG_DB.whoGuilds = {}
seedRows(BronzeLFG_DB.whoPlayers, 1150, "who-player-", "seen")
for index = 1, 300 do
  local guild = {id="who-guild-" .. index, seen=testNow - index, members={}}
  seedRows(guild.members, 180, "member-" .. index .. "-", "seen")
  BronzeLFG_DB.whoGuilds[guild.id] = guild
end
B.publicPlayerWho = {lastQuery={}, finalResult={}}
for index = 1, 180 do
  B.publicPlayerWho.lastQuery["query-" .. index] = testNow - index
  B.publicPlayerWho.finalResult["result-" .. index] = testNow - index
end

network.favoriteAlertCooldowns = {}
network.favoriteAlertSeenListings = {}
network.favoriteOnlineSeen = {}
for index = 1, 320 do
  network.favoriteAlertCooldowns["cooldown-" .. index] = testNow - index
  network.favoriteAlertSeenListings["seen-" .. index] = testNow - index
  network.favoriteOnlineSeen["online-" .. index] = testNow - index
end

shared.events = {{id="event-live"}}
shared.eventAlertSeen = {orphan=true, ["event-live"]=true}
shared.eventAlertKnown = {orphan=true, ["event-live"]=true}
shared.eventAlertCooldowns = {orphan=true, ["event-live"]=true}
shared.eventDismissed = {orphan=true, ["event-live"]=true}
shared.notices = {{id="notice-live"}}
shared.noticeSeen = {orphan=true, ["notice-live"]=true}
shared.noticeDismissed = {orphan=true, ["notice-live"]=true}
network.noticeSeen = {orphan=true, ["notice-live"]=true}
network.noticeDismissed = {orphan=true, ["notice-live"]=true}

local ok, removed = B:SF151_RunCacheMaintenance("harness")
assert(ok and removed > 0, "cache maintenance failed or removed nothing")
assert(count(B.publicGroups) <= CL.maximums.publicGroups, "Public Groups exceeded capacity")
assert(count(B.listings) <= CL.maximums.listings, "Browse listings exceeded capacity")
assert(B.myListing and B.listings[B.myListing.id], "active listing was evicted")
assert(count(B.applicants) <= CL.maximums.applicants, "applicants exceeded capacity")
assert(count(B.chatGuildListings) <= CL.maximums.chatGuildListings, "chat guild cache exceeded capacity")
assert(count(B.guilds) <= CL.maximums.guilds and count(B.guildPosts) <= CL.maximums.guildPosts,
  "guild caches exceeded capacity")
assert(count(B.onlineUsers) <= CL.maximums.onlineUsers and count(B.sfnStatuses) <= CL.maximums.sfnStatuses,
  "Network caches exceeded capacity")
assert(count(B._sf151KnownClassNames) <= CL.maximums.knownClassNames, "class cache exceeded capacity")
assert(count(B._notifySeen569) <= CL.maximums.notificationSeen, "notification cache exceeded capacity")
assert(count(B.invasionUsers) <= CL.maximums.invasionUsers, "Invasion users exceeded capacity")
assert(count(B.invasionOtherPlayers) <= CL.maximums.invasionOtherPlayers, "Invasion players exceeded capacity")
assert(count(B.invasionBeacons) <= CL.maximums.invasionBeacons, "Invasion beacons exceeded capacity")
assert(count(BronzeLFG_DB.whoPlayers) <= CL.maximums.whoPlayers, "WHO players exceeded capacity")
assert(count(BronzeLFG_DB.whoGuilds) <= CL.maximums.whoGuilds, "WHO guilds exceeded capacity")
for _, guild in pairs(BronzeLFG_DB.whoGuilds) do
  assert(count(guild.members) <= CL.maximums.whoMembers, "WHO member map exceeded capacity")
end
assert(count(B.publicPlayerWho.lastQuery) <= CL.maximums.publicWho, "public WHO query cache exceeded capacity")
assert(count(B.publicPlayerWho.finalResult) <= CL.maximums.publicWho, "public WHO result cache exceeded capacity")
assert(count(network.favoriteAlertCooldowns) <= CL.maximums.favoriteAlertState, "favorite cooldowns exceeded capacity")
assert(not B.sfamSeenPublic.orphan and not B.sfamSeenApplicants.orphan, "orphan seen-state survived")
assert(not shared.eventAlertSeen.orphan and not shared.noticeSeen.orphan, "community orphan state survived")
assert(not shared.noticeDismissed.orphan and not network.noticeDismissed.orphan,
  "notice dismissal orphan survived")
assert(B._inlinePublicChatCache == nil and B._sfDirectLinkCache == nil and B._sffclSeen == nil,
  "dead compatibility caches survived")
assert(B._sf151KnownClassNames ~= nil, "active CoA class cache was removed")

local report = B:SF151_GetCacheLifecycleDiagnostics(false)
assert((report.runs or 0) == 1, "maintenance run was not counted")
assert((report.ttlRemovals or 0) > 0, "TTL removals were not counted")
assert((report.boundedEvictions or 0) > 0, "capacity evictions were not counted")
assert((report.orphanedReferencesRemoved or 0) > 0, "orphan cleanup was not counted")
assert(#(report.errors or {}) == 0, "cache lifecycle diagnostics reported errors")
assert(#B:SF151_GetCacheLifecycleInventory() >= 30, "cache inventory is incomplete")

local oldListings = B.listings
local oldMyListing = B.myListing
B.myListing = setmetatable({}, {__index=function() error("injected cleanup failure") end})
local failed = B:SF151_RunCacheMaintenance("error-safety")
assert(failed == false and CL.running == false, "cleanup error left the reentrancy guard active")
B.listings = oldListings
B.myListing = oldMyListing
local recovered = B:SF151_RunCacheMaintenance("recovery")
assert(recovered == true and CL.running == false, "cleanup did not recover after an error")

print("cache lifecycle harness: PASS (inventory=" .. tostring(#CL.inventory)
  .. ", removed=" .. tostring(report.entriesRemoved or 0) .. ")")
