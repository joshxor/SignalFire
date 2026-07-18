local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local parserHarness = assert(arg and arg[2], "parser harness path is required")

dofile(parserHarness)

local B = assert(BronzeLFG, "SignalFire did not load")
local PG = assert(SignalFirePublicGroupsView151, "Phase 6 Public Groups owner did not load")
local Refresh = assert(SignalFireRefresh151, "refresh scheduler did not load")
assert(PG.generationName == "1.5.1-perf-phase6", "unexpected Public Groups view owner")

local function widget(shown)
  local value = {shown=shown ~= false, text="", textCalls=0, backdropCalls=0, widthCalls=0}
  function value:SetText(text) self.text=tostring(text or ""); self.textCalls=self.textCalls+1 end
  function value:GetText() return self.text end
  function value:Show() self.shown=true end
  function value:Hide() self.shown=false end
  function value:IsShown() return self.shown end
  function value:IsVisible() return self.shown end
  function value:SetBackdropColor() self.backdropCalls=self.backdropCalls+1 end
  function value:LockHighlight() self.highlighted=true end
  function value:UnlockHighlight() self.highlighted=false end
  function value:SetWidth(width) self.width=width; self.widthCalls=self.widthCalls+1 end
  function value:HookScript(kind, callback) self["hook" .. kind]=callback end
  return value
end

local function publicRow()
  local row = widget(false)
  row.player=widget(); row.time=widget(); row.type=widget(); row.activity=widget(); row.roles=widget(); row.message=widget()
  return row
end

local function listing(id, player, activity, kind, seen)
  return {
    id=id, player=player, message="LFM " .. activity .. " need healer", rawMessage="LFM " .. activity .. " need healer",
    activity=activity, type=kind or "Dungeon", roles="Healer", intent="Recruiter", tags=kind or "Dungeon",
    channel="3. Newcomers", created=seen, firstSeen=seen, seen=seen, score=90,
  }
end

local function installWidgets()
  B.publicPanel=widget(true)
  B.publicCountText=widget(); B.publicHideOtherButton=widget(); B.publicSortButton=widget(); B.onlinePanelButton=widget()
  B.publicPageText=widget(); B.publicSearch=widget(); B.publicSearch.text=""
  B.publicFilterButtons={}
  for _, name in ipairs({"All","Dungeon","Raid","Key","Event","Guild","LFG","Social"}) do B.publicFilterButtons[name]=widget() end
  B.publicRoleFilterButtons={All=widget(),T=widget(),H=widget(),D=widget()}
  B.publicRows={}
  for index=1,8 do B.publicRows[index]=publicRow() end
  B.publicRowsPerPage=8
end

installWidgets()
B.GetOnlineUserRows=function() return {} end
B.SFModuleIsEnabled=function() return true end
B.SFAM_MarkRelevant=function() end
B.SFAM_PulsePublicGroupRow=function() end
B.publicGroups={}
B.publicFilter="All"; B.publicRoleFilter="All"; B.publicSortMode="Newest"; B.publicSearchText=""; B.publicPage=1
BronzeLFG_DB.publicHiddenTypes={}
BronzeLFG_DB.options.publicExpire=300
SignalFirePerf151.enabled=true
B:SF151_ResetPublicGroupsViewStats()

local function render()
  local ok, result = pcall(Refresh.original.publicGroups, B)
  assert(ok, tostring(result))
  return result
end

local baseGeneration = PG.dataGeneration
B.publicGroups.one=listing("one", "Alpha", "Molten Core", "Raid", time())
B:SF151_InvalidatePublicGroupsData("harness-insert", "one")
assert(PG.dataGeneration == baseGeneration + 1, "one insert did not increment generation exactly once")
assert(render() == true, "first visible render failed")
local first=B:SF151_GetPublicGroupsViewDiagnostics()
assert(first.snapshotsBuilt == 1 and first.viewsBuilt == 1 and first.viewSorts == 1, "first render did not build one snapshot/view/sort")
assert(first.offPageRowsFormatted == nil or first.offPageRowsFormatted == 0, "first render formatted off-page rows")

local writes=first.setTextCalls or 0
assert(render() == true, "unchanged render failed")
local unchanged=B:SF151_GetPublicGroupsViewDiagnostics()
assert(unchanged.snapshotsBuilt == 1 and unchanged.viewsBuilt == 1, "unchanged render rebuilt snapshot or view")
assert((unchanged.snapshotCacheHits or 0) >= 1 and (unchanged.viewCacheHits or 0) >= 1, "unchanged render missed caches")
assert((unchanged.rowRenderSignatureHits or 0) >= 1, "unchanged row missed render signature")
assert((unchanged.setTextCalls or 0) == writes, "unchanged render rewrote text")

local rowsBefore=0
for _ in pairs(B.publicGroups) do rowsBefore=rowsBefore+1 end
B.publicGroups.one.seen=time()
B:SF151_InvalidatePublicGroupsData("harness-repost", "one")
assert(render() == true, "repost render failed")
local rowsAfter=0
for _ in pairs(B.publicGroups) do rowsAfter=rowsAfter+1 end
assert(rowsBefore == rowsAfter and B.publicGroups.one, "repost changed canonical identity")

local nonDisplayedWrites=B:SF151_GetPublicGroupsViewDiagnostics().setTextCalls or 0
B.publicGroups.one.internalOnly="changed"
assert(render() == true, "non-displayed mutation render failed")
assert((B:SF151_GetPublicGroupsViewDiagnostics().setTextCalls or 0) == nonDisplayedWrites, "non-displayed field rewrote a row")

local snapshotBuilds=B:SF151_GetPublicGroupsViewDiagnostics().snapshotsBuilt
B.publicFilter="Raid"
assert(render() == true, "filter render failed")
assert(B:SF151_GetPublicGroupsViewDiagnostics().snapshotsBuilt == snapshotBuilds, "filter rebuilt canonical snapshot")
B.publicSearchText="molten"
assert(render() == true, "search render failed")
assert(B:SF151_GetPublicGroupsViewDiagnostics().snapshotsBuilt == snapshotBuilds, "search rebuilt canonical snapshot")

B.publicFilter="All"; B.publicSearchText=""; B.publicPage=1
for index=2,18 do
  local id="row" .. tostring(index)
  B.publicGroups[id]=listing(id, "Player" .. tostring(index), "Molten Core", "Raid", time()-index)
end
B:SF151_InvalidatePublicGroupsData("harness-page-data")
assert(render() == true, "multi-page render failed")
local beforePage=B:SF151_GetPublicGroupsViewDiagnostics()
B.publicPage=2
assert(render() == true, "page-two render failed")
local afterPage=B:SF151_GetPublicGroupsViewDiagnostics()
assert(afterPage.snapshotsBuilt == beforePage.snapshotsBuilt, "page change rebuilt snapshot")
assert(afterPage.viewsBuilt == beforePage.viewsBuilt, "page change rebuilt filtered view")
assert((afterPage.viewCacheHits or 0) > (beforePage.viewCacheHits or 0), "page change did not hit view cache")
assert((afterPage.offPageRowsFormatted or 0) == 0, "page change formatted off-page rows")

local selectedId=B.publicRows[1].key
B.selectedPublic=selectedId
local viewBuilds=afterPage.viewsBuilt
assert(render() == true, "selection render failed")
local selection=B:SF151_GetPublicGroupsViewDiagnostics()
assert(selection.viewsBuilt == viewBuilds, "selection rebuilt the view")
local detailRuns=selection.detailRendersExecuted or 0
assert(render() == true, "repeated selection render failed")
assert((B:SF151_GetPublicGroupsViewDiagnostics().detailRendersExecuted or 0) == detailRuns, "repeated selection rewrote detail state")
assert((B:SF151_GetPublicGroupsViewDiagnostics().detailSignatureHits or 0) >= 1, "repeated selection missed detail signature")

B.publicPanel:Hide()
local hiddenSnapshotBuilds=B:SF151_GetPublicGroupsViewDiagnostics().snapshotsBuilt
B.publicGroups.hidden=listing("hidden", "HiddenPlayer", "Molten Core", "Raid", time())
B:SF151_InvalidatePublicGroupsData("hidden-burst", "hidden")
assert(render() == false, "hidden panel rendered rows")
local hidden=B:SF151_GetPublicGroupsViewDiagnostics()
assert(hidden.snapshotsBuilt == hiddenSnapshotBuilds and (hidden.hiddenRendersSkipped or 0) >= 1, "hidden panel built a snapshot")
B.publicPanel:Show()
assert(render() == true, "dirty panel did not render when shown")
assert(B:SF151_GetPublicGroupsViewDiagnostics().snapshotsBuilt == hiddenSnapshotBuilds + 1, "opening dirty panel did not build once")

local oldId="expired"
B.publicGroups[oldId]=listing(oldId, "Expired", "Molten Core", "Raid", time()-400)
B:SF151_InvalidatePublicGroupsData("expiry-setup", oldId)
local expiryGeneration=PG.dataGeneration
local removed=B:ExpirePublicGroups()
assert(removed >= 1 and not B.publicGroups[oldId], "expiration did not remove the row")
assert(PG.dataGeneration == expiryGeneration + 1, "expiration did not increment generation once")

B.publicGroups.invasion={id="invasion",player="Beacon",message="Goldshire Invasion",activity="Goldshire Invasion",type="Event",roles="T/H/D",tags="Invasion,Event",source="Invasion Beacon",isInvasionBeacon=true,created=time(),seen=time()}
B:SF151_InvalidatePublicGroupsData("invasion", "invasion")
assert(render() == true, "invasion listing render failed")
assert(PG.snapshot and PG.snapshot.byId.invasion, "invasion listing was not preserved")

local function recover(stage)
  B:SF151_InvalidatePublicGroupsData("error-" .. stage)
  PG.testErrorStage=stage
  assert(render() == false, stage .. " error did not fail safely")
  assert(PG.rendering == nil and PG.dirty == true, stage .. " error left a stuck guard or clean state")
  PG.testErrorStage=nil
  assert(render() == true, stage .. " error did not recover")
end
recover("snapshot")
B.publicSearchText="core-error-view"
recover("view")
B.publicSearchText=""
recover("row")

local final=B:SF151_GetPublicGroupsViewDiagnostics()
assert((final.renderErrors or 0) == 3, "injected errors were not counted")
assert((final.offPageRowsFormatted or 0) == 0, "off-page formatting occurred")
assert((B._sfP3Stats.addMessageParseCalls or 0) == 0, "Phase 6 regressed AddMessage parsing")
assert((B._sfP3Stats.consolidationRowsScanned or 0) == 0, "Phase 6 regressed chat consolidation")

print("Public Groups view-cache harness: PASS (snapshots=" .. tostring(final.snapshotsBuilt or 0)
  .. ", snapshotHits=" .. tostring(final.snapshotCacheHits or 0)
  .. ", views=" .. tostring(final.viewsBuilt or 0)
  .. ", viewHits=" .. tostring(final.viewCacheHits or 0)
  .. ", rowSignatureHits=" .. tostring(final.rowRenderSignatureHits or 0)
  .. ", setText=" .. tostring(final.setTextCalls or 0) .. ")")
