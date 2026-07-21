local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local parserHarness = assert(arg and arg[2], "parser harness path is required")

dofile(parserHarness)

local B = assert(BronzeLFG, "BronzeLFG was not loaded")
local T = assert(SignalFireTimer151, "Phase 4 timer owner was not loaded")
assert(T.generation == "1.5.1-perf-phase4", "unexpected timer owner")

local testNow = 300000
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() return testNow * 1000 end

local function tick(frame, elapsed)
  local handler = assert(frame:GetScript("OnUpdate"), "active frame has no OnUpdate owner")
  local ok, err = pcall(handler, frame, elapsed)
  assert(ok, tostring(err))
end

SignalFirePerf151.enabled = true
B:SF151_ResetTimerStats()

assert(not (B._sfPerfCorePulseFrame and B._sfPerfCorePulseFrame:GetScript("OnUpdate")),
  "legacy core pulse is still active")
assert(not (B._sfPerfNetworkPulseFrame and B._sfPerfNetworkPulseFrame:GetScript("OnUpdate")),
  "legacy Network pulse is still active")
assert(not (B._sfPerfPresencePulseFrame and B._sfPerfPresencePulseFrame:GetScript("OnUpdate")),
  "legacy presence scheduler is still active")
assert(not T.taskByKey["maintenance.slow"], "slow maintenance left a permanent delayed task")

T.tasks = {}
T.taskByKey = {}
T.errors = {}
T.delayFrame:Hide()
assert(not T.delayFrame:IsShown(), "empty delayed scheduler did not sleep")

local order = {}
B:SF151_ScheduleDelayed("order.a", 0.5, function() table.insert(order, "a") end)
B:SF151_ScheduleDelayed("order.b", 0.5, function() table.insert(order, "b") end)
assert(T.delayFrame:IsShown(), "delayed scheduler did not wake")
tick(T.delayFrame, 0.02)
assert(#order == 0, "delayed callback ran before the 30 Hz throttle")
testNow = testNow + 0.5
tick(T.delayFrame, 0.04)
assert(table.concat(order, ",") == "a,b", "equal-deadline callbacks lost deterministic ordering")
assert(not T.delayFrame:IsShown(), "delayed scheduler did not sleep after draining")

local replacementRuns = 0
B:SF151_ScheduleDelayed("replace", 0, function() replacementRuns = replacementRuns + 100 end)
B:SF151_ScheduleDelayed("replace", 0, function() replacementRuns = replacementRuns + 1 end)
testNow = testNow + 0.1
tick(T.delayFrame, 0.04)
assert(replacementRuns == 1, "key replacement executed a stale callback")

local recovered = false
B:SF151_ScheduleDelayed("failure", 0, function() error("injected delayed failure") end)
B:SF151_ScheduleDelayed("recovery", 0, function() recovered = true end)
testNow = testNow + 0.1
tick(T.delayFrame, 0.04)
assert(recovered, "a failed callback blocked later delayed work")
assert(T.executingTask == nil, "delayed scheduler remained locked after an error")
assert(#T.errors == 1, "delayed callback failure was not recorded exactly once")
assert(not T.delayFrame:IsShown(), "failed delayed queue did not return to sleep")

local presence = assert(SignalFirePresenceAdminFix, "presence owner was not loaded")
local presenceSends = 0
presence.SendOwnPresence = function() presenceSends = presenceSends + 1 end
function GetChannelName() return 0 end
assert(presence.RequestPresence("retry-harness", true) == false, "unavailable channel did not request a retry")
assert(T.delayFrame:IsShown() and #T.tasks == 1, "presence retry did not use the delayed scheduler")
function GetChannelName() return 1 end
testNow = testNow + 1.9
tick(T.delayFrame, 0.04)
assert(#T.tasks == 1, "presence retry ran before its GetTime deadline")
testNow = testNow + 0.1
tick(T.delayFrame, 0.04)
assert(presenceSends == 2, "presence retry did not perform the delayed request")
assert(#T.tasks == 0 and not T.delayFrame:IsShown(), "presence retry left a permanent scheduler loop")

presenceSends = 0
testNow = testNow + 7
assert(presence.HandlePresenceRequest("Remote", "Remote") == true, "presence response request failed")
assert(#T.tasks == 1, "presence response delay did not use the delayed scheduler")
testNow = testNow + 0.39
tick(T.delayFrame, 0.04)
assert(presenceSends == 0, "presence response ran before its fractional deadline")
testNow = testNow + 0.01
tick(T.delayFrame, 0.04)
assert(presenceSends == 1 and #T.tasks == 0, "presence response delay did not execute exactly once")

presenceSends = 0
assert(presence.RequestPresence("refresh-now-harness", true) == true, "immediate Refresh Now presence request failed")
assert(presenceSends == 1 and #T.tasks == 0, "Refresh Now created polling instead of sending immediately")

B.sfnPanel = CreateFrame("Frame")
B.onlinePanel = CreateFrame("Frame")
B.sfnPanel:Hide()
B.onlinePanel:Hide()
T.UpdateNetworkOwner()
assert(not T.networkFrame:IsShown(), "hidden Network panels left the ticker awake")

BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
BronzeLFG_DB.signalFireNetwork.autoRefreshSeconds = 0
B.sfnPanel:Show()
T.UpdateNetworkOwner()
assert(T.networkFrame:IsShown(), "visible Network panel did not wake the ticker")
local beforeTicks = B:SF151_GetTimerDiagnostics().networkTicks or 0
tick(T.networkFrame, 0.5)
assert((B:SF151_GetTimerDiagnostics().networkTicks or 0) == beforeTicks,
  "Network ticker exceeded its 1 Hz limit")
tick(T.networkFrame, 0.5)
assert((B:SF151_GetTimerDiagnostics().networkTicks or 0) == beforeTicks + 1,
  "visible Network ticker did not run at 1 Hz")

local presenceRequests = 0
SignalFirePresenceAdminFix = SignalFirePresenceAdminFix or {}
SignalFirePresenceAdminFix.RequestPresence = function() presenceRequests = presenceRequests + 1 end
for _, interval in ipairs({15, 30, 60}) do
  BronzeLFG_DB.signalFireNetwork.autoRefreshSeconds = interval
  B._sfnNextAutoRefresh = math.floor(testNow) + interval
  testNow = testNow + interval
  tick(T.networkFrame, 1)
end
assert(presenceRequests == 3, "15/30/60 visible Network auto-refresh deadlines were not honored")
B.sfnPanel:Hide()
T.UpdateNetworkOwner()
assert(not T.networkFrame:IsShown(), "Network ticker did not sleep when its panel hid")
testNow = testNow + 60
assert(presenceRequests == 3, "hidden Network state performed an automatic presence request")
B.onlinePanel:Show()
T.UpdateNetworkOwner()
assert(T.networkFrame:IsShown(), "Full Roster alone did not wake the visible ticker")
B.onlinePanel:Hide()
T.UpdateNetworkOwner()
assert(not T.networkFrame:IsShown(), "Full Roster hide did not stop the visible ticker")

B.newApplicantAlert = true
T.ApplyApplicantOwner()
assert(T.applicantFrame:IsShown(), "active applicant alert did not wake its animation")
local applicantTicks = B:SF151_GetTimerDiagnostics().applicantTicks or 0
tick(T.applicantFrame, 1 / 60)
assert((B:SF151_GetTimerDiagnostics().applicantTicks or 0) == applicantTicks,
  "applicant animation exceeded 30 Hz")
tick(T.applicantFrame, 1 / 60)
assert((B:SF151_GetTimerDiagnostics().applicantTicks or 0) == applicantTicks + 1,
  "applicant animation did not run at 30 Hz")
B.newApplicantAlert = false
tick(T.applicantFrame, 1 / 30)
assert(not T.applicantFrame:IsShown(), "cleared applicant alert left animation awake")

BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.freeLauncher = false
BronzeLFG_DB.minimap = BronzeLFG_DB.minimap or {}
BronzeLFG_DB.minimap.angle = 215
BronzeLFG_DB.minimapAngle = 215
B.minimapAngle = 215
B.mm = CreateFrame("Frame")
B.mm:SetScript("OnDragStart", function(self) self.dragging = true end)
B.mm:SetScript("OnDragStop", function(self)
  self.dragging = false
  BronzeLFG_DB.minimap.angle = B.minimapAngle
  BronzeLFG_DB.minimapAngle = B.minimapAngle
end)
B.mm._sfP4DragOwner = false
T.ApplyMinimapOwner()
Minimap = Minimap or CreateFrame("Frame")
Minimap.GetCenter = function() return 100, 100 end
UIParent.GetEffectiveScale = function() return 1 end
function GetCursorPosition() return 180, 100 end
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local dragStart = assert(B.mm:GetScript("OnDragStart"), "minimap drag start owner missing")
local dragStop = assert(B.mm:GetScript("OnDragStop"), "minimap drag stop owner missing")
assert(pcall(dragStart, B.mm), "minimap drag start failed")
assert(B.mm.dragging and T.dragFrame:IsShown(), "minimap drag did not enter its active state")
tick(T.dragFrame, 1 / 60)
assert(B.minimapAngle == 0, "active minimap drag did not update the transient angle")
assert(BronzeLFG_DB.minimap.angle == 215 and BronzeLFG_DB.minimapAngle == 215,
  "active minimap drag wrote SavedVariables before drag end")
assert(pcall(dragStop, B.mm), "minimap drag stop failed")
assert(not T.dragFrame:IsShown(), "minimap drag owner did not sleep at drag end")
assert(BronzeLFG_DB.minimap.angle == B.minimapAngle and BronzeLFG_DB.minimapAngle == B.minimapAngle,
  "minimap drag did not persist its final angle")

local diagnostics = B:SF151_GetTimerDiagnostics()
assert(diagnostics.callbackErrorCount == 1, "timer diagnostics lost callback errors")
assert((diagnostics.finalDragSaves or 0) == 1, "minimap final-save diagnostic is incorrect")
assert(diagnostics.oldCoreActive == false and diagnostics.oldNetworkActive == false
  and diagnostics.oldPresenceActive == false, "legacy idle pulses reactivated")

print("event-driven timer harness: PASS (scheduled=" .. tostring(diagnostics.tasksScheduled or 0)
  .. ", executed=" .. tostring(diagnostics.tasksExecuted or 0)
  .. ", networkTicks=" .. tostring(diagnostics.networkTicks or 0) .. ")")
