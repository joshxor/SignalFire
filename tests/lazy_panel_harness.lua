local lazyPath = assert(arg and arg[1], "extracted lazy-panel path is required")

unpack = unpack or table.unpack
local clock = 1000
local messages = {}
local buildCounts = {}
local refreshCounts = {}

function debugprofilestop() clock = clock + .25; return clock end
function GetTime() return clock / 1000 end
function time() return math.floor(clock / 1000) end

local function control(name, shown)
  local f = {name=name, shown=shown == true, scripts={}, scale=1}
  function f:GetName() return self.name end
  function f:Show() self.shown = true; local fn=self.scripts.OnShow; if fn then fn(self) end end
  function f:Hide() self.shown = false; local fn=self.scripts.OnHide; if fn then fn(self) end end
  function f:IsShown() return self.shown end
  function f:IsVisible() return self.shown end
  function f:SetScale(value) self.scale = value end
  function f:SetScript(key, fn) self.scripts[key] = fn end
  function f:GetScript(key) return self.scripts[key] end
  return f
end

DEFAULT_CHAT_FRAME = {AddMessage=function(_, text) messages[#messages + 1] = text end}
BronzeLFG_DB = {options={scale=1.1, showMinimap=true, serverProfile="Triumvirate"}}
SignalFireUILifecycle151 = {
  registered=0,
  RegisterKnownDropdowns=function(self) self.registered = self.registered + 1 end,
}

BronzeLFG = {publicGroups={}}
local B = BronzeLFG

local function built(name)
  buildCounts[name] = (buildCounts[name] or 0) + 1
end
local function refreshed(name)
  refreshCounts[name] = (refreshCounts[name] or 0) + 1
end

function B:BuildSide() self.side = self.side or control("side", true); built("side") end
function B:BuildBrowse() self.browse = control("browse"); built("browse") end
function B:BuildCreate() self.create=control("create"); self.typeDrop=control("typeDrop"); built("create") end
function B:BuildProfile() self.profile=control("profile"); self.profileRole=control("profileRole"); built("profile") end
function B:BuildApplicants() self.apps=control("apps"); self.appRows={}; built("applicants") end
function B:BuildPublicGroups() self.publicPanel=control("public"); self.publicRows={}; built("publicGroups") end
function B:BuildGuildBrowser() self.guildPanel=control("guild"); built("guildBrowser") end
function B:BuildMyListing() self.myPanel=control("my"); built("myListing") end
function B:BuildOptions() self.optionsPanel=control("options"); built("options") end
function B:BuildInvasions() self.invasionPanel=control("invasions"); built("invasions") end
function B:BuildOnlinePanel() self.onlinePanel=control("roster"); self.onlinePanel._sfrpFullRoster=true; built("fullRoster") end
function B:SFE_BuildEventBoard() self.sfeEventPanel=control("events"); built("eventBoard") end
function B:BuildSFNetworkPanel()
  self.sfnPanel=control("network")
  built("network")
  self:SFE_BuildEventBoard()
end
function B:BuildMinimap() self.mm=control("minimap", true); built("minimap") end
function B:UpdateMinimap() refreshed("minimap") end
function B:RestoreMyListingState() self.restored=true end
function B:ApplySignalFireBetaTitle() self.titleApplied=(self.titleApplied or 0)+1 end
function B:SFUI1434_Apply() self.identityApplied=(self.identityApplied or 0)+1 end

function B:HidePanels()
  for _, field in ipairs({"browse","create","profile","apps","publicPanel","guildPanel","myPanel","optionsPanel","sfnPanel","invasionPanel"}) do
    if self[field] then self[field]:Hide() end
  end
end

local function show(owner, field, tab, refresh)
  owner:CreateUI()
  owner:SF135N_EnsureCoreUI()
  owner:HidePanels()
  owner[field]:Show()
  if owner.frame then owner.frame:Show() end
  owner.currentTab=tab
  if refresh then owner[refresh](owner) end
end

function B:ShowBrowse() show(self,"browse","Browse","RefreshBrowse") end
function B:ShowCreate() show(self,"create","Create Listing","UpdateCreateControls") end
function B:ShowProfile() show(self,"profile","Profile","UpdateWhisperPreview569") end
function B:ShowApplicants() show(self,"apps","Applicants","RefreshApplicants") end
function B:ShowPublicGroups() show(self,"publicPanel","Public Groups","RefreshPublicGroups") end
function B:ShowGuildBrowser() show(self,"guildPanel","Guild Browser","RefreshGuildBrowser") end
function B:ShowMyListing() show(self,"myPanel","My Listing","RefreshMyListing") end
function B:ShowOptions() show(self,"optionsPanel","Options") end
function B:ShowInvasions() show(self,"invasionPanel","Invasions","RefreshInvasions") end
function B:ShowSFNetwork() show(self,"sfnPanel","Network","RefreshSFNetwork") end
function B:ShowFullRoster() self:CreateUI(); self:BuildOnlinePanel(); self.onlinePanel:Show(); self:RefreshOnlinePanel() end
function B:OpenSFEEventBoard() self:SFE_BuildEventBoard(); self:SFE_RefreshEventBoard() end

for _, name in ipairs({"RefreshBrowse","UpdateCreateControls","UpdateWhisperPreview569","RefreshApplicants",
  "RefreshPublicGroups","RefreshGuildBrowser","RefreshMyListing","RefreshSFNetwork","RefreshOnlinePanel","RefreshInvasions",
  "SFE_RefreshEventBoard"}) do
  B[name] = function() refreshed(name) end
end
function B:RequestPublicGroupsRefresh() refreshed("RequestPublicGroupsRefresh") end

function B:SF135N_EnsureCoreUI()
  self:BuildBrowse(); self:BuildCreate(); self:BuildProfile(); self:BuildApplicants(); self:BuildPublicGroups()
  self:BuildGuildBrowser(); self:BuildMyListing(); self:BuildOptions(); self:BuildSFNetworkPanel(); self:BuildOnlinePanel(); self:BuildInvasions()
end

function B:CreateUI()
  if self.frame then return end
  self.frame=control("main")
  self.content=control("content", true)
  self:BuildSide()
  self:BuildBrowse(); self:BuildCreate(); self:BuildProfile(); self:BuildApplicants(); self:BuildPublicGroups()
  self:BuildOnlinePanel(); self:BuildGuildBrowser(); self:BuildOptions(); self:BuildMyListing(); self:BuildMinimap()
  self:RestoreMyListingState()
  self:ShowBrowse()
  self:SF135N_EnsureCoreUI()
end
function B:Show() self:CreateUI(); self.frame:Show(); self:ShowBrowse() end
function B:Toggle() if self.frame and self.frame:IsShown() then self.frame:Hide() else self:Show() end end

assert(loadfile(lazyPath))()
local LP = assert(SignalFireLazyPanels151, "lazy panel owner missing")
assert(LP.generation == "1.5.1-perf-phase7", "wrong lazy generation")

-- Fresh login performs only startup recovery and minimap construction.
B:CreateUI()
assert(B.mm and not B.frame, "fresh login constructed the main shell")
for _, key in ipairs(LP.order) do assert(not LP.panels[key].built, "fresh login built " .. key) end
assert((buildCounts.minimap or 0) == 1, "minimap was not built once")

-- Background data marks an unbuilt panel dirty without constructing it.
B:RefreshPublicGroups()
B:RequestPublicGroupsRefresh()
assert(not B.publicPanel and LP.panels.publicGroups.dirty, "public data constructed or failed to dirty Public Groups")
B:RefreshSFNetwork()
B:SFE_RefreshEventBoard()
assert(not B.sfnPanel and LP.panels.network.dirty, "presence/event data constructed Network")

-- First main open creates the shell and Browse only.
assert(B:Show(), "main window did not open")
assert(B.frame and B.browse and B.frame:IsShown(), "main shell/default page missing")
assert((buildCounts.browse or 0) == 1, "Browse did not build exactly once")
for _, key in ipairs({"create","profile","applicants","publicGroups","guildBrowser","myListing","options","network","fullRoster","invasions"}) do
  assert(not LP.panels[key].built, "main open unexpectedly built " .. key)
end
local sideBuilds = buildCounts.side or 0
B:Toggle(); B:Toggle()
assert((buildCounts.browse or 0) == 1 and (buildCounts.side or 0) == sideBuilds, "reopen rebuilt shell or Browse")

-- Public Groups first use renders current data once and then reuses controls.
B.publicGroups.example={id="example", activity="Molten Core"}
assert(B:ShowPublicGroups(), "Public Groups did not open")
assert((buildCounts.publicGroups or 0) == 1 and (refreshCounts.RefreshPublicGroups or 0) == 1,
  "Public Groups first use did not build/refresh once")
B:ShowPublicGroups()
assert((buildCounts.publicGroups or 0) == 1, "Public Groups rebuilt")

-- Network owns its embedded Event/Notice surface, but not Full Roster.
assert(B:ShowSFNetwork(), "Network did not open")
assert((buildCounts.network or 0) == 1 and (buildCounts.eventBoard or 0) == 1, "Network embedded dependency missing")
assert((buildCounts.fullRoster or 0) == 0, "Network eagerly built Full Roster")
B:ShowFullRoster()
assert((buildCounts.fullRoster or 0) == 1, "Full Roster did not build on first use")
B:ShowFullRoster()
assert((buildCounts.fullRoster or 0) == 1, "Full Roster rebuilt")

-- Every remaining page is first-use and idempotent.
for _, method in ipairs({"ShowCreate","ShowProfile","ShowApplicants","ShowGuildBrowser","ShowMyListing","ShowOptions","ShowInvasions"}) do
  assert(B[method](B), method .. " failed")
  assert(B[method](B), method .. " repeat failed")
end
for _, key in ipairs(LP.order) do assert(LP.panels[key].buildCount == 1, key .. " actual build count was not one") end

-- HidePanels never constructs and only hides existing pages.
local totalBuilds = 0
for _, value in pairs(buildCounts) do totalBuilds = totalBuilds + value end
B:HidePanels()
local afterHide = 0
for _, value in pairs(buildCounts) do afterHide = afterHide + value end
assert(totalBuilds == afterHide, "HidePanels built controls")

-- Failure and dependency-cycle guards clear and permit a later retry.
local invasion = LP.panels.invasions
B.invasionPanel=nil; invasion.built=false; invasion.failed=false
local realInvasionBuilder = invasion.builder
invasion.builder=function() error("injected panel failure") end
local ok = LP:EnsurePanel("invasions", "error-test")
assert(not ok and not invasion.building and invasion.failed, "panel error left its guard active")
invasion.builder=realInvasionBuilder
assert(LP:EnsurePanel("invasions", "retry-test") and invasion.buildCount == 2, "failed panel did not retry")

local create, options = LP.panels.create, LP.panels.options
B.create=nil; B.typeDrop=nil; create.built=false; create.failed=false
B.optionsPanel=nil; options.built=false; options.failed=false
create.dependencies={"options"}; options.dependencies={"create"}
local cycleOK = LP:EnsurePanel("create", "cycle-test")
assert(not cycleOK and not create.building and not options.building, "dependency cycle was not contained")
create.dependencies={}; options.dependencies={}; create.failed=false; options.failed=false
assert(LP:EnsurePanel("create", "cycle-recovery"), "panel did not recover after dependency cycle")

assert(#LP.errors <= LP.maximumErrors, "lazy error history exceeded its bound")
local d = B:SF151_GetLazyPanelDiagnostics()
assert(d.shellBuildCount == 1 and d.panelsBuiltBeforeFirstOpen == 0, "startup lazy diagnostics are incorrect")
assert((d.refreshesConvertedToDirty or 0) >= 3, "deferred refresh diagnostics were not recorded")

print("lazy panel harness: PASS (shell=" .. tostring(d.shellBuildCount)
  .. ", prevented=" .. tostring(d.backgroundBuildsPrevented)
  .. ", deferred=" .. tostring(d.refreshesConvertedToDirty) .. ")")

