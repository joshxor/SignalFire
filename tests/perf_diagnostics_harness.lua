local diagnosticsPath = assert(arg and arg[1], "diagnostics path is required")

unpack = unpack or table.unpack

local now = 100
local profileMs = 1000
local messages = {}
local garbageSamples = 0

function GetTime() return now end
function time() return math.floor(now) end
function debugprofilestop()
  profileMs = profileMs + 0.25
  return profileMs
end

local realCollectGarbage = collectgarbage
collectgarbage = function(mode)
  assert(mode == "count", "unexpected garbage-collector command")
  garbageSamples = garbageSamples + 1
  return 1234.5
end

DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, text) messages[#messages + 1] = text end,
}
SlashCmdList = {}
hash_SlashCmdList = {}
hash_SecureCmdList = {}
local oldSlashCalls = 0
SlashCmdList["SIGNALFIRE"] = function(input)
  oldSlashCalls = oldSlashCalls + 1
  return "old:" .. tostring(input)
end
function ChatFrame_ImportListToHash() end

local function newFrame(name, shown)
  local frame = {name=name, shown=shown == true, scripts={}, events={}}
  function frame:GetName() return self.name end
  function frame:SetScript(script, fn) self.scripts[script] = fn end
  function frame:GetScript(script) return self.scripts[script] end
  function frame:RegisterEvent(event) self.events[event] = true end
  function frame:IsShown() return self.shown end
  function frame:IsVisible() return self.shown end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  return frame
end

function CreateFrame(_, name)
  return newFrame(name or "anonymous", false)
end

BronzeLFG_DB = {network={}, signalFireNetwork={}}
BronzeLFG = {
  publicGroups={}, onlineUsers={}, sfnStatuses={}, frame=newFrame("main", false),
}
local B = BronzeLFG

local coreCalls = 0
B._sfPerfCorePulseFrame = newFrame("corePulse", true)
B._sfPerfCorePulseFrame:SetScript("OnUpdate", function(_, elapsed)
  coreCalls = coreCalls + 1
  return "pulse", elapsed
end)

local createCalls = 0
function B:CreateUI(value)
  createCalls = createCalls + 1
  return value, nil, 7
end

local presenceCalls = 0
function B:HandlePresence(value)
  presenceCalls = presenceCalls + 1
  return "presence:" .. value
end

function B:GetOnlineUserRows()
  return {{name="one"}, {name="two"}}
end

function B:BuildOptions() self.optionsPanel = self.optionsPanel or {}; return "options" end
function B:BuildCreate() return "create" end
function B:SFAM_UpdateCreatePreview() return "preview" end

function B:SF151_ResetChatRuntimeStats() self.chatReset = (self.chatReset or 0) + 1 end
function B:SF151_ResetRefreshStats() self.refreshReset = (self.refreshReset or 0) + 1 end
function B:SF151_ResetTimerStats() self.timerReset = (self.timerReset or 0) + 1 end
function B:SF151_ResetHotPathStats() self.hotReset = (self.hotReset or 0) + 1 end

SignalFireRefresh151 = {
  original={
    network=function() return "network", nil, 3 end,
    roster=function() return "roster" end,
    publicGroups=function() return "groups" end,
  },
  stats={},
  frame=newFrame("refresh", false),
}
SignalFireRefresh151.frame:SetScript("OnUpdate", function() return "refreshPulse" end)

assert(loadfile(diagnosticsPath))()

local P = assert(SignalFirePerf151, "diagnostics namespace was not created")
assert(P.enabled == false, "diagnostics must default to disabled")
assert(garbageSamples == 0, "loading diagnostics sampled memory")
assert(not B.chatReset and not B.refreshReset and not B.timerReset and not B.hotReset,
  "loading diagnostics reset existing counters")
assert(SlashCmdList["SIGNALFIRE"] == P.slashWrapper, "final slash owner was not installed")
assert(hash_SlashCmdList["/sf"] == P.slashWrapper, "Wrath slash hash was not updated")
assert(hash_SecureCmdList["/sf"] == P.slashWrapper, "secure slash hash was not updated")
assert(type(SlashCmdList["SIGNALFIREPERF"]) == "function", "dedicated performance alias was not installed")
assert(hash_SlashCmdList["/sfperf"] == SlashCmdList["SIGNALFIREPERF"],
  "dedicated performance alias hash was not updated")
assert(SlashCmdList["SIGNALFIRE"]("unrelated") == "old:unrelated" and oldSlashCalls == 1,
  "unrelated slash commands did not reach the previous final owner")
assert(SlashCmdList["SIGNALFIRE"]("perf") == true and oldSlashCalls == 1,
  "performance command fell through to the previous owner")

local login = assert(P.eventFrame and P.eventFrame:GetScript("OnEvent"),
  "diagnostics login installer was not created")
login(P.eventFrame, "PLAYER_LOGIN")
assert(P.installError == nil, "diagnostics instrumentation failed to attach")

local first, middle, last = B:CreateUI("same")
assert(first == "same" and middle == nil and last == 7, "disabled wrapper changed return values")
assert(createCalls == 1, "disabled wrapper changed call count")
assert(next(P.stats) == nil, "disabled method wrapper recorded statistics")

local n1, n2, n3 = SignalFireRefresh151.original.network(B)
assert(n1 == "network" and n2 == nil and n3 == 3, "disabled refresh wrapper changed results")
assert(next(P.stats) == nil, "disabled refresh wrapper recorded statistics")

local pulse = B._sfPerfCorePulseFrame:GetScript("OnUpdate")
local p1, p2 = pulse(B._sfPerfCorePulseFrame, 0.5)
assert(p1 == "pulse" and p2 == 0.5 and coreCalls == 1, "disabled OnUpdate wrapper changed behavior")
assert(next(P.stats) == nil, "disabled OnUpdate wrapper recorded statistics")

assert(B:SF151_HandlePerfSlash("perf caches") == true, "cache command was not handled")
assert(B:SF151_HandlePerfSlash("perf print") == true, "print command was not handled")
assert(garbageSamples == 0, "non-memory commands sampled memory")

assert(B:SF151_HandlePerfSlash("perf on") == true and P.enabled == true, "enable command failed")
assert(B.chatReset == 1 and B.refreshReset == 1 and B.timerReset == 1 and B.hotReset == 1,
  "enable command did not reset diagnostics")

B:CreateUI("measured")
B:BuildOptions()
B:HandlePresence("packet")
SignalFireRefresh151.original.network(B)
pulse(B._sfPerfCorePulseFrame, 0.25)
assert(((P.stats.calls or {})["ui.CreateUI"] or {}).calls == 1, "CreateUI was not measured")
assert(((P.stats.ui or {}).panelBuildRequests or 0) == 1, "panel build request was not measured")
assert(((P.stats.ui or {}).actualPanelBuilds or 0) == 1, "actual panel build was not measured")
assert(((P.stats.calls or {})["network.HandlePresence"] or {}).calls == 1, "presence was not measured")
assert(((P.stats.calls or {})["refresh.network"] or {}).calls == 1, "refresh was not measured")
assert(((P.stats.onUpdate or {})["core.pulse"] or {}).calls == 1, "OnUpdate was not measured")

assert(B:SF151_HandlePerfSlash("perf memory") == true, "memory command was not handled")
assert(garbageSamples == 1, "memory command did not take exactly one explicit sample")

assert(B:SF151_HandlePerfSlash("perf off") == true and P.enabled == false, "disable command failed")
local measuredCalls = ((P.stats.calls or {})["ui.CreateUI"] or {}).calls
B:CreateUI("disabled-again")
assert(((P.stats.calls or {})["ui.CreateUI"] or {}).calls == measuredCalls,
  "disabled diagnostics continued recording")

collectgarbage = realCollectGarbage
print("perf diagnostics harness: PASS")
