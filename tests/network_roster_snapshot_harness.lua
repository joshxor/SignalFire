local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local parserHarness = assert(arg and arg[2], "parser harness path is required")

dofile(parserHarness)

local B = assert(BronzeLFG, "BronzeLFG was not loaded")
local R = assert(SignalFireRosterSnapshot151, "Phase 3 roster owner was not loaded")
assert(R.owner == "1.5.1-perf-phase3", "unexpected roster owner")

local testNow = 200000
function time() return math.floor(testNow) end
function GetTime() return testNow end
function debugprofilestop() return testNow * 1000 end

local units = {
  player={name="Harness", className="Templar", classFile="TEMPLAR"},
  party1={name="Grouped", className="Mage", classFile="MAGE"},
}
function UnitExists(token) return units[token] ~= nil end
function UnitName(token) return units[token] and units[token].name or nil end
function UnitClass(token)
  local row = units[token]
  return row and row.className or nil, row and row.classFile or nil
end
function UnitLevel() return 60 end
function GetZoneText() return "HarnessZone" end
function GetGuildInfo(token) return token == "player" and "Harness Guild" or nil end
function GetNumFriends() return 1 end
function GetFriendInfo(index) return index == 1 and "Friendly" or nil end
function GetNumGuildMembers() return 1 end
function GetGuildRosterInfo(index)
  if index ~= 1 then return nil end
  return "Guildmate", nil, nil, 60, "Mage", "Dalaran", nil, nil, true, nil, "MAGE"
end

LOCALIZED_CLASS_NAMES_MALE = {TEMPLAR="Templar", MAGE="Mage", WARRIOR="Warrior"}
LOCALIZED_CLASS_NAMES_FEMALE = LOCALIZED_CLASS_NAMES_MALE

BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.profile = {role="Tank", roleType="Protection"}
BronzeLFG_DB.favorites = {friendly=true}
BronzeLFG_DB.whoPlayers = {
  whoonly={name="WhoOnly", level=55, className="Warrior", classFile="WARRIOR", zone="Icecrown", seen=testNow},
}
B.onlineUsers = {
  Friendly={name="Friendly", level=60, className="Templar", classFile="TEMPLAR", role="Healer", zone="Stormwind", guild="Friends", seen=testNow},
  Grouped={name="Grouped", level=60, className="", classFile="MAGE", role="DPS", zone="Dalaran", seen=testNow},
}
B.sfnStatuses = {
  Friendly={name="Friendly", className="Templar", classFile="TEMPLAR", looking="Looking for Dungeons", flags="H", zone="Stormwind", seen=testNow},
  Grouped={name="Grouped", className="Mage", classFile="MAGE", looking="Online", flags="D", zone="Dalaran", seen=testNow},
}

SignalFirePerf151.enabled = true
B:SF151_ResetRosterSnapshotStats()
B:SF151_InvalidateRosterData("harness-start")
local first = B:GetOnlineUserRows()
assert(#first == 3, "Ascension snapshot should contain self and two SignalFire users")
assert(first[1].self == true, "self row should sort first")
for _ = 1, 5 do assert(B:GetOnlineUserRows() == first, "unchanged generation did not reuse the canonical snapshot") end
local stats = B:SF151_GetRosterSnapshotDiagnostics()
assert(stats.canonicalSnapshotsBuilt == 1, "unchanged requests rebuilt the canonical snapshot")
assert(stats.snapshotCacheHits == 5, "expected five snapshot cache hits")
assert(stats.canonicalSorts == 1, "canonical roster sorted more than once")
assert(stats.statusComparisons == 2, "status scan did not scale with status entries")
assert(stats.unitMapBuilds == 1, "unit map should build once per generation")
assert(stats.unitTokensInspected == #R.unitTokens, "unit tokens were not inspected exactly once")

local byName = {}
for _, row in ipairs(first) do byName[row.name] = row end
assert(byName.Friendly.className == "Templar", "custom class display was not preserved")
assert(byName.Grouped.className == "Mage", "localized Wrath class display was not preserved")
assert(byName.Friendly.friend == true, "friend enrichment failed")
assert(byName.Grouped.groupmate == true, "group enrichment failed")
assert(byName.WhoOnly == nil, "Ascension retained a /who-only row")

BronzeLFG_DB.options.serverProfile = "Triumvirate"
B:SF151_InvalidateRosterData("profile-test")
local triumvirate = B:GetOnlineUserRows()
local foundWho = false
for _, row in ipairs(triumvirate) do if row.name == "WhoOnly" and row.whoOnly then foundWho = true end end
assert(foundWho, "Triumvirate lost its /who row")

B.onlineFilter = "All"
B.fullRosterSearch = {text="", GetText=function(self) return self.text end}
local canonicalBefore = B:GetOnlineUserRows()
local allView = B:SFRP_GetRosterRows()
B.fullRosterSearch.text = "friendly"
local searchView = B:SFRP_GetRosterRows()
assert(#searchView == 1 and searchView[1].name == "Friendly", "search view is incorrect")
assert(B:GetOnlineUserRows() == canonicalBefore, "search rebuilt or replaced the canonical snapshot")
B.fullRosterSearch.text = ""
B.onlineFilter = "Favorites"
local favoriteView = B:SFRP_GetRosterRows()
assert(#favoriteView == 1 and favoriteView[1].name == "Friendly", "favorite filter is incorrect")
assert(allView ~= canonicalBefore, "filtered view should not expose the canonical array for mutation")

local generationBeforeBurst = R.generation
local snapshotRequestsBeforeBurst = B:SF151_GetRosterSnapshotDiagnostics().canonicalSnapshotRequests or 0
for i = 1, 20 do
  local name = "Burst" .. tostring(i)
  B:HandlePresence({"BLFG312", "PING", name, "1.5.1", "60", "MAGE", "DPS", "Dalaran", "", tostring(testNow), "Arcane", "Mage"})
end
assert(R.generation == generationBeforeBurst + 20, "presence changes did not increment the roster generation")
assert((B:SF151_GetRosterSnapshotDiagnostics().canonicalSnapshotRequests or 0) == snapshotRequestsBeforeBurst,
  "presence transition handling scanned the full roster")

local P4 = assert(SignalFireRefresh151, "refresh scheduler missing")
local networkBuilds, rosterBuilds = 0, 0
B.sfnPanel = CreateFrame("Frame")
B.onlinePanel = CreateFrame("Frame")
B.sfnPanel:Hide()
B.onlinePanel:Hide()
P4.original.network = function() networkBuilds = networkBuilds + 1 end
P4.original.roster = function() rosterBuilds = rosterBuilds + 1 end
testNow = testNow + 1
assert(pcall(P4.frame:GetScript("OnUpdate"), P4.frame, 1), "hidden-panel scheduler failed")
assert(networkBuilds == 0 and rosterBuilds == 0, "hidden panels rebuilt after a presence burst")
B.sfnPanel:Show()
B.onlinePanel:Show()
B:RefreshSFNetwork()
B:RefreshOnlinePanel()
testNow = testNow + 1
assert(pcall(P4.frame:GetScript("OnUpdate"), P4.frame, 1), "visible-panel scheduler failed")
assert(networkBuilds == 1 and rosterBuilds == 1, "dirty visible panels did not rebuild exactly once")

local burstRows = B:GetOnlineUserRows()
assert(#burstRows >= 20, "presence burst did not update source state")
stats = B:SF151_GetRosterSnapshotDiagnostics()
assert(stats.canonicalSnapshotsBuilt == 3, "presence burst should produce one post-burst canonical build")

local transitionChecks = stats.favoriteTransitionChecks or 0
assert(transitionChecks >= 20, "presence transitions were not checked per changed record")

testNow = testNow + 400
local generationBeforeExpiry = R.generation
local expiredRows = B:GetOnlineUserRows()
assert(R.generation == generationBeforeExpiry + 1, "stale expiry did not invalidate the generation")
assert(#expiredRows == 1, "stale remote users were not removed")

local hoverGeneration = R.generation
local hoverStats = B:SF151_GetRosterSnapshotDiagnostics()
assert(R.generation == hoverGeneration, "row hover invalidated the roster generation")
local afterHover = B:SF151_GetRosterSnapshotDiagnostics()
assert((afterHover.canonicalSorts or 0) == (hoverStats.canonicalSorts or 0), "row hover sorted the roster")
assert((afterHover.statusComparisons or 0) == (hoverStats.statusComparisons or 0), "row hover scanned statuses")
assert((afterHover.hoverTriggeredRefreshRequests or 0) == 0, "hover refresh diagnostics are not zero")

local panel = B.sfnPanel or CreateFrame("Frame")
B.sfnPanel = panel
panel:Show()
P4.pending = false
P4.dirty.network = nil
P4.original.network = function() error("injected renderer error") end
B:RefreshSFNetwork()
testNow = testNow + 1
local ok = pcall(P4.frame:GetScript("OnUpdate"), P4.frame, 1)
assert(not ok, "injected renderer error did not propagate")
assert(P4.executing == nil, "refresh scheduler remained locked after an error")
local recovered = 0
P4.original.network = function() recovered = recovered + 1 end
B:RefreshSFNetwork()
testNow = testNow + 1
assert(pcall(P4.frame:GetScript("OnUpdate"), P4.frame, 1), "refresh scheduler did not recover")
assert(recovered == 1, "future refresh did not execute after error recovery")

assert(SignalFireUILifecycle151 and SignalFireUILifecycle151.generation == "1.5.1-perf-phase2",
  "Phase 2 lifecycle owner changed")
local uiStats = SignalFirePerf151.stats and SignalFirePerf151.stats.ui or {}
assert((uiStats.recursiveTreeScans or 0) == 0, "recursive UI traversal regressed")

stats = B:SF151_GetRosterSnapshotDiagnostics()
print("network roster harness: PASS (generation=" .. tostring(stats.generation)
  .. ", builds=" .. tostring(stats.canonicalSnapshotsBuilt or 0)
  .. ", hits=" .. tostring(stats.snapshotCacheHits or 0)
  .. ", sorts=" .. tostring(stats.canonicalSorts or 0) .. ")")
