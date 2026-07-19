local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
local S = assert(SignalFireStability151, "Phase 10 diagnostics did not load")
assert(S.generation == "1.5.1-phase10b", "unexpected diagnostics generation")
assert(SignalFireChatRuntime151 and SignalFireChatRuntime151.Apply,
  "chat runtime owner did not load")
SignalFireChatRuntime151.Apply()
assert(S.enabled == false and S.installed ~= true, "diagnostics did not default off")
assert(next(S.bindings) == nil, "disabled diagnostics wrapped runtime methods")
assert(not S.eventFrame:GetScript("OnUpdate"), "diagnostics installed idle polling")

local originalBrowse = B.RefreshBrowse
assert(B:SF151_HandleDiagnosticSlash("diag start") == true, "diag start was not handled")
assert(S.enabled and S.installed, "diagnostics did not start")
assert(B.RefreshBrowse ~= originalBrowse, "audited method was not wrapped")
local wrappedBrowse = B.RefreshBrowse
B:SF151_HandleDiagnosticSlash("diag start")
assert(B.RefreshBrowse == wrappedBrowse, "repeated start stacked a second wrapper")

local function frame_state(report, name)
  for _, row in ipairs(report.frames or {}) do
    if row.name == name then return row.state, row end
  end
end

local publicCountBeforeProbe = 0
for _ in pairs(B.publicGroups or {}) do publicCountBeforeProbe = publicCountBeforeProbe + 1 end
local networkSends = 0
local savedSendAddonMessage = SendAddonMessage
SendAddonMessage = function() networkSends = networkSends + 1 end
local visibleBeforeProbe = ChatFrame1.lastMessage
local ownership = B:SF151_ProbeChatFrameOwnership()
assert((ownership.totals.signalFireOutermost or 0) == 10,
  "outermost chat wrappers were not identified")
assert(ChatFrame1.lastMessage == visibleBeforeProbe, "ownership probe produced visible chat output")
local publicCountAfterProbe = 0
for _ in pairs(B.publicGroups or {}) do publicCountAfterProbe = publicCountAfterProbe + 1 end
assert(publicCountAfterProbe == publicCountBeforeProbe, "ownership probe created a fake listing")
assert(networkSends == 0, "ownership probe generated network traffic")

local signalFireAddMessage = ChatFrame1.AddMessage
ChatFrame1.AddMessage = function(self, text, ...)
  assert(type(text) == "string", "later chat wrapper requires a string payload")
  string.lower(text)
  return signalFireAddMessage(self, text, ...)
end
local chained = B:SF151_ProbeChatFrameOwnership()
assert(frame_state(chained, "ChatFrame1") == "signalFireChained",
  "later chat wrapper was not reported as chained")
ChatFrame1.AddMessage = function() end
local missing = B:SF151_ProbeChatFrameOwnership()
assert(frame_state(missing, "ChatFrame1") == "signalFireMissing",
  "missing chat wrapper was not detected")
ChatFrame1.AddMessage = function(self, ...)
  signalFireAddMessage(self, ...)
  return signalFireAddMessage(self, ...)
end
local duplicated = B:SF151_ProbeChatFrameOwnership()
assert(frame_state(duplicated, "ChatFrame1") == "signalFireDuplicated",
  "duplicated chat wrapper execution was not detected")
ChatFrame1.AddMessage = function() error("outer chat owner rejected diagnostic payload") end
local unknown = B:SF151_ProbeChatFrameOwnership()
assert(frame_state(unknown, "ChatFrame1") == "unknown",
  "uncertain chat ownership was not reported honestly")
ChatFrame1.AddMessage = signalFireAddMessage
SendAddonMessage = savedSendAddonMessage

local signalFireSetItemRef = SetItemRef
local setItem = S:ProbeSetItemRefOwnership()
assert(setItem.state == "signalFireOutermost" and setItem.hits == 1,
  "outermost SetItemRef owner was not identified")
SetItemRef = function(link, ...)
  assert(type(link) == "string", "later SetItemRef wrapper requires a string payload")
  string.sub(link, 1, 8)
  return signalFireSetItemRef(link, ...)
end
setItem = S:ProbeSetItemRefOwnership()
assert(setItem.state == "signalFireChained", "later SetItemRef wrapper was not reported as chained")
SetItemRef = function(...)
  signalFireSetItemRef(...)
  return signalFireSetItemRef(...)
end
setItem = S:ProbeSetItemRefOwnership()
assert(setItem.state == "signalFireDuplicated", "duplicated SetItemRef execution was not detected")
SetItemRef = function() end
setItem = S:ProbeSetItemRefOwnership()
assert(setItem.state == "signalFireMissing", "missing SetItemRef handler was not detected")
SetItemRef = function() error("outer SetItemRef owner rejected diagnostic payload") end
setItem = S:ProbeSetItemRefOwnership()
assert(setItem.state == "unknown", "uncertain SetItemRef ownership was not reported honestly")
SetItemRef = signalFireSetItemRef

local filterBefore = S:GetChatFilterReport().filterCalls
BronzeLFG_DB.options.inlineChatLinks = false
B.SignalFireTestSay = true
SignalFireChatRuntime151.Filter(ChatFrame1, "CHAT_MSG_SAY", "LFM MC 1 HEALER", "Harness")
local filterAfter = S:GetChatFilterReport()
assert(filterAfter.expectedSignalFireFilters == 3 and filterAfter.knownSignalFireRegistrations == 3,
  "filter registration state is incorrect")
assert(filterAfter.filterCalls == filterBefore + 1, "filter interval activity was not measured")
assert(BronzeLFG_DB.options.inlineChatLinks == false, "Chat Links Off changed during diagnostics")
BronzeLFG_DB.options.inlineChatLinks = true
local repaired, migration = B:SF151_RepairReleaseDatabase(BronzeLFG_DB)
assert(repaired and migration.chatLinks == true and BronzeLFG_DB.options.inlineChatLinks == true,
  "explicit Chat Links On preference was not preserved")
BronzeLFG_DB.options.inlineChatLinks = false

local savedFrame = B.frame
B.frame = CreateFrame("Frame", "Phase10ScaleHarness")
assert(S:InstallScaleOwner(), "scale diagnostic owner was not installed")
B.frame:SetScale(1.1)
assert(S.methods["ui.scale"] and S.methods["ui.scale"].executions == 1,
  "scale application was not measured")
B.frame = savedFrame

local depth = 0
function B:SF151_Phase10HarnessReentrant(value)
  if depth == 0 then
    depth = 1
    local result = self:SF151_Phase10HarnessReentrant(value + 1)
    depth = 0
    return result
  end
  return value
end
assert(S:WrapMethod("test.reentrant", "SF151_Phase10HarnessReentrant", "execution"),
  "reentrant test method was not wrapped")
assert(B:SF151_Phase10HarnessReentrant(4) == 5, "wrapped return values changed")
assert((S.methods["test.reentrant"].reentrant or 0) == 1, "reentrancy was not detected")
assert(#S.active == 0, "reentrant call left an active guard")

function B:SF151_Phase10HarnessError() error("injected Phase 10 error") end
assert(S:WrapMethod("test.error", "SF151_Phase10HarnessError", "execution"),
  "error test method was not wrapped")
for _ = 1, 20 do
  local ok = pcall(B.SF151_Phase10HarnessError, B)
  assert(ok == false, "wrapped error was swallowed")
  assert(#S.active == 0, "error left an active guard")
end
assert(#S.errors == S.maximumErrors, "error history is not bounded")

local profileMs = 1000
function debugprofilestop() profileMs = profileMs + 60; return profileMs end
function B:SF151_Phase10HarnessSlow(value) return value end
assert(S:WrapMethod("test.slow", "SF151_Phase10HarnessSlow", "execution"),
  "slow test method was not wrapped")
for index = 1, 48 do assert(B:SF151_Phase10HarnessSlow(index) == index) end
assert(#S.recent == S.maximumRecent, "slow-operation history is not bounded")
assert((S.methods["test.slow"].severe or 0) == 48, "slow-operation threshold did not fire")

local oldGetNumAddOns, oldGetAddOnInfo = GetNumAddOns, GetAddOnInfo
local oldIsAddOnLoaded, oldUpdateMemory, oldGetMemory = IsAddOnLoaded, UpdateAddOnMemoryUsage, GetAddOnMemoryUsage
local oldUpdateCPU, oldGetCPU, oldGetCVar = UpdateAddOnCPUUsage, GetAddOnCPUUsage, GetCVar
function GetNumAddOns() return 2 end
function GetAddOnInfo(index) return index == 1 and "SignalFire" or "ElvUI" end
function IsAddOnLoaded(value) return value == 1 or value == 2 or value == "ElvUI" end
function UpdateAddOnMemoryUsage() end
function GetAddOnMemoryUsage(index) return index == 1 and 321.5 or 0 end
function UpdateAddOnCPUUsage() end
function GetAddOnCPUUsage(index) return index == 1 and 44.25 or 0 end
function GetCVar() return "0" end
local memory = S:SampleResources("memory")
assert(memory.signalFireKB == 321.5 and memory.loadedAddons == 2,
  "per-addon memory sample is incorrect")
local cpuOff = S:SampleResources("cpu")
assert(cpuOff.signalFireCPU == nil and cpuOff.scriptProfile == false,
  "CPU was sampled while script profiling was disabled")
function GetCVar() return "1" end
local cpuOn = S:SampleResources("cpu")
assert(cpuOn.signalFireCPU == 44.25 and cpuOn.scriptProfile == true,
  "CPU sample was not collected when profiling was already enabled")

local conflicts = S:GetConflicts()
assert(#conflicts.addons >= 1 and conflicts.addons[1].name == "ElvUI",
  "known addon conflict indicator was not reported")
local savedAddMessage = ChatFrame1.AddMessage
ChatFrame1.AddMessage = function() end
S:ProbeOwnership()
local replaced = S:GetConflicts()
assert(frame_state(replaced.chatOwnership, "ChatFrame1") == "signalFireMissing",
  "chat-frame replacement was not classified by reachability")
ChatFrame1.AddMessage = savedAddMessage

GetNumAddOns, GetAddOnInfo = oldGetNumAddOns, oldGetAddOnInfo
IsAddOnLoaded, UpdateAddOnMemoryUsage, GetAddOnMemoryUsage = oldIsAddOnLoaded, oldUpdateMemory, oldGetMemory
UpdateAddOnCPUUsage, GetAddOnCPUUsage, GetCVar = oldUpdateCPU, oldGetCPU, oldGetCVar

local report = B:SF151_GetStabilityDiagnostics()
assert(report.enabled and report.maximumActiveDepth >= 2, "integrated report missed call depth")
assert(report.refresh and report.refresh.generation, "integrated report missed refresh ownership")
assert(type(report.cacheSizes) == "table" and #report.cacheSizes > 0,
  "integrated report missed current cache sizes")
assert(#report.recent <= S.maximumRecent and #report.errors <= S.maximumErrors,
  "integrated report contains unbounded history")

local printed = {}
local oldAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) printed[#printed + 1] = tostring(text or "") end
S:PrintReport()
DEFAULT_CHAT_FRAME.AddMessage = oldAddMessage
local output = table.concat(printed, "\n")
for _, label in ipairs({"chat ownership:", "chat filters:", "SetItemRef ownership:",
    "panels:", "timers:", "cache lifecycle:", "conflicts:", "resources:"}) do
  assert(string.find(output, label, 1, true), "printed report missed " .. label)
end
assert(#printed < 80, "printed diagnostic report is not reasonably bounded")

assert(B:SF151_HandleDiagnosticSlash("diag stop") == true and S.enabled == false,
  "diag stop was not handled")
local callsBefore = S.methods["test.slow"].requests
assert(B:SF151_Phase10HarnessSlow(99) == 99, "disabled wrapper changed behavior")
assert(S.methods["test.slow"].requests == callsBefore, "disabled diagnostics collected hot-path data")

print("stability diagnostics harness: PASS (recent=" .. tostring(#S.recent)
  .. ", errors=" .. tostring(#S.errors) .. ", depth=" .. tostring(report.maximumActiveDepth) .. ")")
