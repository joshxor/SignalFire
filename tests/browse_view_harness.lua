local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local BV = assert(SignalFireBrowseView151, "Phase 8 Browse owner did not load")
local LP = assert(SignalFireLazyPanels151, "Phase 7 lazy owner did not load")
local Refresh = assert(SignalFireRefresh151, "Phase 4 refresh owner did not load")
assert(BV.generation == "1.5.1-perf-phase8", "unexpected Browse owner")

local testNow = 700000
local profileClock = 1000
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() profileClock = profileClock + .05; return profileClock end

SignalFirePerf151.enabled = true
B:SF151_ResetBrowseViewStats()

local function listing(id, seen, kind, activity)
  return {
    id=id, leader="Leader" .. id, class="Mage", classFile="MAGE",
    type=kind or "Dungeon", activity=activity or ("Activity " .. id), difficulty="Normal", key="",
    minItemLevel="60", members=1, maxMembers=5, needTank="1", needHealer="1", needDPS="1",
    voice="None", loot="Group Loot", note="Note " .. id, created=seen - 30, seen=seen,
  }
end

local function flushRefresh(expectError)
  testNow = testNow + .2
  local handler = assert(Refresh.frame:GetScript("OnUpdate"), "refresh scheduler owner missing")
  local ok, err = pcall(handler, Refresh.frame, 1)
  if expectError then
    assert(ok, "Browse scheduler did not contain injected failure: " .. tostring(err))
    assert(not Refresh.pending and not Refresh.frame:IsShown(), "Browse failure left the shared scheduler active")
  else
    assert(ok, tostring(err))
  end
end

local function openBrowse()
  local ok, result = pcall(B.Show, B)
  assert(ok and result ~= false, "Browse open failed: " .. tostring(result))
  flushRefresh(false)
end

-- Fresh data may arrive while the shell and Browse are still unbuilt.
B.listings = {}
for i = 1, 12 do B.listings["L" .. i] = listing("L" .. i, testNow - i) end
B:SF151_InvalidateBrowseData("unbuilt-seed", true)
assert(not B.frame and not B.browse, "unbuilt dirty request constructed Browse")
assert(not BV.snapshot, "unbuilt dirty request built a snapshot")
assert(LP.panels.browse.dirty, "unbuilt dirty request was not recorded")

-- A profile switch before first use must not construct Browse.
B:SF143_SetServerProfile("Ascension", true)
assert(not B.frame and not B.browse, "pre-open profile switch constructed Browse")

openBrowse()
local first = B:SF151_GetBrowseViewDiagnostics()
assert(LP.panels.browse.buildCount == 1, "Browse did not build exactly once")
assert(first.snapshotsBuilt == 1 and first.viewsBuilt == 1 and first.visibleRenders == 1,
  "first open did not build one snapshot, view, and render")
assert(first.snapshotRows == 12, "first snapshot lost seeded listings: " .. tostring(first.snapshotRows))
assert(first.canonicalSorts == 1 and first.viewSorts == 0, "first open sort ownership is incorrect")
assert(first.offPageRowsFormatted == 0, "first open formatted off-page rows")
assert(first.rowsConsidered == #B.rows, "first open did not limit work to the visible row pool")
assert(rawget(B.rows[1], "key"), "first open rendered no Browse rows: count=" .. tostring(B.browseCountText:GetText())
  .. ", filter=" .. tostring(B.filter) .. ", search=" .. tostring(B.search:GetText()))
assert(not (SignalFireTimer151.taskByKey and SignalFireTimer151.taskByKey["browse.expiration"]),
  "first Browse render scheduled a long-lived expiration task")

-- Reopen and unchanged refreshes reuse all data work and row signatures.
openBrowse()
local reopened = B:SF151_GetBrowseViewDiagnostics()
assert(LP.panels.browse.buildCount == 1, "reopening Browse rebuilt the panel")
assert(rawget(B.rows[1], "key"), "reopening Browse cleared visible rows: " .. tostring(B.browseCountText:GetText()))
assert(reopened.snapshotsBuilt == 1 and reopened.viewsBuilt == 1, "reopening Browse rebuilt cached data")
assert(reopened.snapshotCacheHits >= 1 and reopened.viewCacheHits >= 1, "reopening Browse missed caches")
local writesBefore = reopened.rowsMateriallyWritten
local signatureBefore = BV.rowStates[1] and BV.rowStates[1].signature
B:RefreshBrowse("unchanged")
flushRefresh(false)
local unchanged = B:SF151_GetBrowseViewDiagnostics()
assert(unchanged.snapshotsBuilt == 1 and unchanged.viewsBuilt == 1 and unchanged.canonicalSorts == 1,
  "unchanged refresh rebuilt or resorted data")
assert(unchanged.rowsMateriallyWritten == writesBefore, "unchanged refresh rewrote visible rows: "
  .. tostring(writesBefore) .. " -> " .. tostring(unchanged.rowsMateriallyWritten)
  .. ", hits=" .. tostring(unchanged.rowSignatureHits)
  .. ", gen=" .. tostring(unchanged.dataGeneration)
  .. ", snapshots=" .. tostring(unchanged.snapshotsBuilt)
  .. ", views=" .. tostring(unchanged.viewsBuilt)
  .. ", sigBefore=" .. tostring(signatureBefore)
  .. ", sigAfter=" .. tostring(BV.rowStates[1] and BV.rowStates[1].signature))
assert(unchanged.rowSignatureHits >= #B.rows, "unchanged refresh missed row signatures")

-- One material insertion creates exactly one new generation and cached dataset.
local generationBefore = BV.dataGeneration
B.listings.L13 = listing("L13", testNow + 10)
B:SF151_InvalidateBrowseData("insert", true)
flushRefresh(false)
local inserted = B:SF151_GetBrowseViewDiagnostics()
assert(BV.dataGeneration == generationBefore + 1, "one insert did not increment generation once")
assert(inserted.snapshotsBuilt == 2 and inserted.viewsBuilt == 2 and inserted.canonicalSorts == 2,
  "one insert did not rebuild exactly one snapshot and view")

-- A non-visible record update rebuilds data but does not rewrite visible controls.
local visibleWrites = inserted.rowsMateriallyWritten
B.listings.L12.note = "Changed off page"
B:SF151_InvalidateBrowseData("off-page-update", true)
flushRefresh(false)
local offPage = B:SF151_GetBrowseViewDiagnostics()
assert(offPage.rowsMateriallyWritten == visibleWrites, "off-page update rewrote visible controls")
assert(offPage.offPageRowsFormatted == 0, "off-page update formatted off-page controls")

-- Search and filter rebuild only the view; page changes reuse both caches.
local snapshotsBeforeSearch = offPage.snapshotsBuilt
B.search:SetText("activity l13")
B:RefreshBrowse("search")
flushRefresh(false)
local searched = B:SF151_GetBrowseViewDiagnostics()
assert(searched.snapshotsBuilt == snapshotsBeforeSearch and searched.viewsBuilt == offPage.viewsBuilt + 1,
  "search rebuilt the canonical snapshot or missed the view rebuild")
B.search:SetText("")
B.filter = "Dungeons"
B:RefreshBrowse("filter")
flushRefresh(false)
local filtered = B:SF151_GetBrowseViewDiagnostics()
assert(filtered.snapshotsBuilt == snapshotsBeforeSearch and filtered.viewsBuilt == searched.viewsBuilt + 1,
  "filter rebuilt the canonical snapshot or missed the view rebuild")
local viewsBeforePage = filtered.viewsBuilt
local snapshotsBeforePage = filtered.snapshotsBuilt
B:SF151_SetBrowsePage(2)
flushRefresh(false)
local paged = B:SF151_GetBrowseViewDiagnostics()
assert(paged.snapshotsBuilt == snapshotsBeforePage and paged.viewsBuilt == viewsBeforePage,
  "page change rebuilt snapshot or view")
assert(paged.offPageRowsFormatted == 0, "page change formatted off-page rows")

-- Selection changes reuse data; a repeated selection hits the detail signature.
local selected = rawget(B.rows[1], "key")
assert(selected, "page did not render a selectable row")
local viewBuildsBeforeSelection = paged.viewsBuilt
B.selectedListing = selected
B:RefreshBrowse("selection")
flushRefresh(false)
local selectedStats = B:SF151_GetBrowseViewDiagnostics()
assert(selectedStats.viewsBuilt == viewBuildsBeforeSelection, "selection rebuilt the view")
assert(selectedStats.selectionOnlyUpdates >= 1 and selectedStats.detailRenders >= 1,
  "selection did not use the selection-only path")
local detailRenders = selectedStats.detailRenders
B:RefreshBrowse("same-selection")
flushRefresh(false)
local sameSelection = B:SF151_GetBrowseViewDiagnostics()
assert(sameSelection.detailRenders == detailRenders and sameSelection.detailSignatureHits >= 1,
  "repeated selection rewrote detail controls")

-- Hover has no Browse refresh owner and therefore changes no counters.
local wrappersBeforeHover = sameSelection.refreshWrapperCalls
local onEnter = B.rows[1]:GetScript("OnEnter")
if onEnter then onEnter(B.rows[1]) end
assert(B:SF151_GetBrowseViewDiagnostics().refreshWrapperCalls == wrappersBeforeHover,
  "tooltip hover requested Browse refresh")

-- Hidden mutation bursts remain data-only until one reopen render.
B.browse:Hide()
local snapshotsBeforeHidden = B:SF151_GetBrowseViewDiagnostics().snapshotsBuilt
for i = 14, 16 do
  B.listings["L" .. i] = listing("L" .. i, testNow + i)
  B:SF151_InvalidateBrowseData("hidden-burst", true)
end
assert(B:SF151_GetBrowseViewDiagnostics().snapshotsBuilt == snapshotsBeforeHidden,
  "hidden burst built a Browse snapshot")
assert(LP.panels.browse.dirty, "hidden burst did not leave Browse dirty")
openBrowse()
local reopenedBurst = B:SF151_GetBrowseViewDiagnostics()
assert(reopenedBurst.snapshotsBuilt == snapshotsBeforeHidden + 1,
  "hidden burst did not collapse into one snapshot on reopen")

-- Refresh-time expiration removes stale rows and repairs selection without a timer.
local expiring = B.rows[1].key
assert(expiring and B.listings[expiring], "expiration target missing")
B.listings[expiring].seen = testNow - 901
B.selectedListing = expiring
B:SF151_InvalidateBrowseData("expire-test", true)
flushRefresh(false)
assert(not B.listings[expiring], "expired listing remained in canonical data")
assert(B.selectedListing == nil, "expired selected listing was not repaired")
assert(not (SignalFireTimer151.taskByKey and SignalFireTimer151.taskByKey["browse.expiration"]),
  "Browse expiration created a delayed task")

-- The final protocol owner invalidates one generation for one material LIST.
B.browse:Show()
local protocolGeneration = BV.dataGeneration
local payload = table.concat({
  "BLFG312", "LIST", "REMOTE-1", "RemoteLeader", "Mage", "MAGE", "Dungeon",
  "The Nexus", "Normal", "", "60", "1", "5", "1", "1", "1", "None",
  "Group Loot", "Protocol listing", tostring(math.floor(testNow)),
}, "~")
B:HandleMessage(payload)
assert(BV.dataGeneration == protocolGeneration + 1, "one protocol LIST did not increment generation once")
flushRefresh(false)
local stableProtocolGeneration = BV.dataGeneration
B:HandleMessage(payload)
assert(BV.dataGeneration == stableProtocolGeneration, "unchanged protocol repost incremented generation")

-- Existing action targets remain exact after cached selection rendering.
B.selectedListing = "REMOTE-1"
B:RefreshBrowse("action-target")
flushRefresh(false)
local whisperTarget = nil
local oldSendChatMessage = SendChatMessage
SendChatMessage = function(_, channel, _, target) if channel == "WHISPER" then whisperTarget = target end end
local whisperClick = assert(B.detail.whisper:GetScript("OnClick"), "Browse whisper action missing")
whisperClick()
SendChatMessage = oldSendChatMessage
assert(whisperTarget == "RemoteLeader", "Browse whisper action used a stale listing target")

-- Nested broadcast/full-group cancellation commits one data generation.
local own = listing("OWN-1", testNow, "Dungeon", "Wailing Caverns")
own.leader = UnitName("player")
own.members, own.maxMembers = 1, 1
B.myListing = own
B.listings[own.id] = own
BV:Invalidate("nested-setup")
local nestedGeneration = BV.dataGeneration
local oldGetChannelName = GetChannelName
GetChannelName = function() return 1 end
B:Broadcast()
GetChannelName = oldGetChannelName
assert(BV.dataGeneration == nestedGeneration + 1, "nested broadcast/cancel incremented generation more than once")
assert(not B.myListing and not B.listings[own.id], "full-group broadcast did not preserve cancellation behavior")

-- Snapshot, view, and row failures clear guards and recover on the next request.
BV:Invalidate("snapshot-failure")
BV.injectSnapshotFailure = true
B:RefreshBrowse("snapshot-failure")
flushRefresh(true)
BV.injectSnapshotFailure = nil
assert(not BV.rendering and BV.dirty, "snapshot failure left Browse locked or clean")
B:RefreshBrowse("snapshot-recovery")
flushRefresh(false)

BV.injectViewFailure = true
B.filter = "Raids"
B:RefreshBrowse("view-failure")
flushRefresh(true)
BV.injectViewFailure = nil
assert(not BV.rendering and BV.dirty, "view failure left Browse locked or clean")
B:RefreshBrowse("view-recovery")
flushRefresh(false)

BV.injectRowFailure = true
B:RefreshBrowse("row-failure")
flushRefresh(true)
BV.injectRowFailure = nil
assert(not BV.rendering and BV.dirty, "row failure left Browse locked or clean")
B:RefreshBrowse("row-recovery")
flushRefresh(false)

local final = B:SF151_GetBrowseViewDiagnostics()
assert(final.offPageRowsFormatted == 0, "Browse formatted off-page rows")
assert(final.viewSorts == 0, "Browse performed a redundant view sort")
assert(LP.panels.browse.buildCount == 1, "Browse rebuilt during view tests")
assert(not SignalFireTimer151.delayFrame:IsShown() or #(SignalFireTimer151.tasks or {}) > 0,
  "delayed scheduler stayed awake without work")

print("Browse view-cache harness: PASS (snapshots=" .. tostring(final.snapshotsBuilt)
  .. ", snapshotHits=" .. tostring(final.snapshotCacheHits)
  .. ", views=" .. tostring(final.viewsBuilt)
  .. ", viewHits=" .. tostring(final.viewCacheHits)
  .. ", writes=" .. tostring(final.rowsMateriallyWritten)
  .. ", signatureHits=" .. tostring(final.rowSignatureHits) .. ")")
