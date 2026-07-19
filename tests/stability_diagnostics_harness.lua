local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
local S = assert(SignalFireStability151, "Phase 10 diagnostics did not load")
assert(S.generation == "1.5.1-phase10", "unexpected diagnostics generation")
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
local replaced = S:GetConflicts()
local sawReplacement = false
for _, frame in ipairs(replaced.frames) do
  if frame.name == "ChatFrame1" and frame.replaced then sawReplacement = true end
end
assert(sawReplacement, "chat-frame wrapper replacement was not detected")
ChatFrame1.AddMessage = savedAddMessage

GetNumAddOns, GetAddOnInfo = oldGetNumAddOns, oldGetAddOnInfo
IsAddOnLoaded, UpdateAddOnMemoryUsage, GetAddOnMemoryUsage = oldIsAddOnLoaded, oldUpdateMemory, oldGetMemory
UpdateAddOnCPUUsage, GetAddOnCPUUsage, GetCVar = oldUpdateCPU, oldGetCPU, oldGetCVar

local report = B:SF151_GetStabilityDiagnostics()
assert(report.enabled and report.maximumActiveDepth >= 2, "integrated report missed call depth")
assert(report.refresh and report.refresh.generation, "integrated report missed refresh ownership")
assert(#report.recent <= S.maximumRecent and #report.errors <= S.maximumErrors,
  "integrated report contains unbounded history")

assert(B:SF151_HandleDiagnosticSlash("diag stop") == true and S.enabled == false,
  "diag stop was not handled")
local callsBefore = S.methods["test.slow"].requests
assert(B:SF151_Phase10HarnessSlow(99) == 99, "disabled wrapper changed behavior")
assert(S.methods["test.slow"].requests == callsBefore, "disabled diagnostics collected hot-path data")

print("stability diagnostics harness: PASS (recent=" .. tostring(#S.recent)
  .. ", errors=" .. tostring(#S.errors) .. ", depth=" .. tostring(report.maximumActiveDepth) .. ")")
