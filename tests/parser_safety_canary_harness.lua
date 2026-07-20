local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local P3 = assert(SignalFireChatRuntime151, "Phase 12C parser owner did not load")
local C = assert(SignalFireParserCanary151, "parser canary owner did not load")
local perf = assert(SignalFirePerf151, "final slash owner did not load")
assert(P3.generation == "1.5.2-phase12c", "unexpected parser owner")
assert(C.generation == "1.5.2-phase12c-canary", "unexpected canary owner")

local testNow = 2100000
local profileClock = 1000
local profileStep = .05
local fps = 60
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() profileClock = profileClock + profileStep; return profileClock end
function GetFramerate() return fps end

local function count(values)
  local result = 0
  for _ in pairs(values or {}) do result = result + 1 end
  return result
end

local function advance(seconds)
  testNow = testNow + seconds
end

local function parser_command(command)
  local owner = assert(SlashCmdList["SIGNALFIRE"], "final /sf owner is missing")
  assert(owner(command) == true, "parser command was not handled: " .. tostring(command))
end

local function runtime()
  return assert(P3.GetParserRuntimeState, "runtime-state API missing")()
end

local function assert_off(label)
  local state = runtime()
  assert(BronzeLFG_DB.options.publicGroups == false, label .. ": parser remained enabled")
  assert(BronzeLFG_DB.options.inlineChatLinks == false, label .. ": links remained enabled")
  assert(state.sourceActive == false, label .. ": source ingestion remained active")
  assert(state.filtersInstalled == 0 and P3._filterInstalled ~= true, label .. ": filters remained installed")
  assert(state.queueDepth == 0, label .. ": queue was not cleared")
  assert(not B._sfP3Frame:IsShown(), label .. ": worker remained shown")
  assert(B._sfP3Frame:GetScript("OnUpdate") == nil, label .. ": worker OnUpdate remained installed")
  assert(not C.frame:IsShown(), label .. ": canary timer remained shown")
  assert(C.frame:GetScript("OnUpdate") == nil, label .. ": canary OnUpdate remained installed")
end

local function start(duration)
  parser_command("parser canary " .. tostring(duration))
  assert(C.active == true, "canary did not start")
  assert(BronzeLFG_DB.options.publicGroups == true, "canary did not enable parsing")
  assert(BronzeLFG_DB.options.inlineChatLinks == false, "canary enabled Chat Links")
  assert(P3._filterInstalled ~= true, "canary installed render filters")
  assert(C.frame:IsShown() and C.frame:GetScript("OnUpdate") ~= nil, "canary timer did not wake")
end

local function ingest(index)
  return P3.IngestSource("Canary" .. tostring(index), "LFM MC need healer", "3. Newcomers", "CHAT_MSG_CHANNEL")
end

local function worker()
  return B._sfP3Frame:GetScript("OnUpdate")
end

-- Test 1: final slash routing remains reachable after every known late repair.
assert(SlashCmdList["SIGNALFIRE"] == perf.slashWrapper, "diagnostics wrapper is not final /sf owner")
parser_command("parser identity")
local identity = C:GetIdentity()
assert(identity.matchesExpected == true, "current canary identity did not match")
assert(identity.version == "1.5.2" and identity.releaseChannel == "rc",
  "release identity did not match")
assert(identity.releaseName == "SignalFire 1.5.2 Phase 12C Exact Links RC",
  "release name did not match")
assert(identity.chatRuntimeGeneration == "1.5.2-phase12c"
  and identity.parserWorkerGeneration == "1.5.2-phase12c"
  and identity.canaryGeneration == "1.5.2-phase12c-canary",
  "runtime generations did not match")
assert(identity.sourceOwnerActive and identity.workerOwnerActive and identity.shutdownOwnerActive,
  "final parser owners were not active")
assert(not identity.parserEnabled and not identity.chatLinksEnabled and identity.installedFilters == 0,
  "identity did not begin in the safe Off state")
assert(not identity.sourceProcessingActive and not identity.workerRunning and identity.queueDepth == 0,
  "identity did not begin with sleeping parser work")
parser_command("parser status")
SignalFireSlashFreezeFix.Apply()
parser_command("parser identity")
parser_command("parser status")
SignalFireSlashFinal.Install()
parser_command("parser identity")
parser_command("parser status")
SignalFireModules.InstallSlash()
parser_command("parser identity")
parser_command("parser status")
perf:InstallSlash()
assert(SlashCmdList["SIGNALFIRE"] == perf.slashWrapper, "late slash repair displaced final owner")
for _, command in ipairs({"parser identity", "parser status", "parser report", "parser off", "parser abort"}) do
  parser_command(command)
end

-- A stale or mixed installation must fail closed before enabling source ingestion.
local expectedVersion = SignalFire_VERSION
SignalFire_VERSION = "1.5.1"
parser_command("parser canary 5")
assert(C.active == false, "wrong-version canary started")
assert_off("wrong-version identity rejection")
assert(C:GetIdentity().matchesExpected == false, "wrong version passed identity")
SignalFire_VERSION = expectedVersion

local expectedGeneration = P3.generation
P3.generation = "1.5.1-phase3i"
parser_command("parser canary 5")
assert(C.active == false, "wrong-runtime canary started")
assert_off("wrong-runtime identity rejection")
P3.generation = expectedGeneration

local expectedShutdown = P3.StopParserWork
P3.StopParserWork = nil
parser_command("parser canary 5")
assert(C.active == false, "missing-shutdown canary started")
assert(BronzeLFG_DB.options.publicGroups == false and BronzeLFG_DB.options.inlineChatLinks == false,
  "missing-shutdown rejection did not leave settings Off")
P3.StopParserWork = expectedShutdown
assert(C:GetIdentity().matchesExpected == true, "restored canary identity did not match")

parser_command("parser canary")
assert(C.requestedDuration == 10, "default canary duration is not 10 seconds")
parser_command("parser abort")
for _, bad in ipairs({"0", "-1", "2.5", "121", "invalid"}) do
  parser_command("parser canary " .. bad)
  assert(C.active == false, "invalid duration started a canary: " .. bad)
end

-- Test 2: a five-second canary resolves exactly, defers side effects, and stops itself.
start(5)
assert(ingest(1), "eligible source was not queued")
local update = assert(worker(), "worker did not install OnUpdate for queued work")
update(B._sfP3Frame, .01)
assert(count(B.publicGroups) > 0, "completed canonical listing was not retained")
fps = 47
advance(5.1)
assert(C.frame:GetScript("OnUpdate"), "canary timer disappeared before expiry")(C.frame, .25)
assert_off("automatic completion")
assert(C.lastReport and C.lastReport.outcome == "completed", "completion report was not retained")
assert(C.lastReport.TestParseCalls > 0, "completion report missed TestParse calls")
assert(C.lastReport.filtersInstalled == 0 and C.lastReport.filterReceipts == 0,
  "links-off canary reported render filters")
assert(C.lastReport.startingFPS == 60 and C.lastReport.minimumFPS == 47 and C.lastReport.endingFPS == 47,
  "FPS samples were not bounded correctly")

-- Test 3: manual abort discards only unfinished jobs and is idempotent.
fps = 60
start(60)
assert(ingest(10), "completed-listing source was not queued")
assert(worker(), "worker missing before completed listing")(B._sfP3Frame, .01)
local completedRows = count(B.publicGroups)
for index = 11, 20 do assert(ingest(index), "backlog source was not queued") end
local parserCallsBeforeAbort = (B._sfP3Stats or {}).TestParseCalls or 0
local staleWorker = assert(worker(), "worker missing before abort")
parser_command("parser abort")
assert_off("manual abort")
assert(count(B.publicGroups) >= completedRows, "manual abort removed completed exact listings")
staleWorker(B._sfP3Frame, .01)
assert(((B._sfP3Stats or {}).TestParseCalls or 0) == parserCallsBeforeAbort,
  "TestParse ran after manual abort")
parser_command("parser abort")
assert_off("repeated abort")

-- Test 4: an expired backlog stops before another TestParse begins.
start(5)
for index = 30, 39 do assert(ingest(index), "expired-backlog source was not queued") end
local expiredWorker = assert(worker(), "worker missing for expired backlog")
local beforeExpiryCalls = (B._sfP3Stats or {}).TestParseCalls or 0
advance(5.1)
expiredWorker(B._sfP3Frame, .01)
assert_off("expired backlog")
assert(((B._sfP3Stats or {}).TestParseCalls or 0) == beforeExpiryCalls,
  "TestParse began after canary deadline")

-- Test 5: every automatic safety trigger uses the same shutdown owner.
local originalProbe = SignalFireFastChatLinks.TestParse
start(60)
SignalFireFastChatLinks.TestParse = function() error("injected parser failure") end
assert(not ingest(50), "parser-error source returned an exact record")
SignalFireFastChatLinks.TestParse = originalProbe
assert_off("parser error")
assert(C.lastAbortReason == "parser error", "parser-error reason was not retained")

start(60)
assert(ingest(51), "re-entry source was not queued")
P3._workerRunning = true
assert(worker(), "worker missing for re-entry test")(B._sfP3Frame, .01)
P3._workerRunning = false
assert_off("worker re-entry")
assert(C.lastAbortReason == "worker re-entry", "worker re-entry reason was not retained")

start(60)
B._sfP3Queue = "corrupt"
C:CheckRuntime("test queue corruption")
assert_off("queue corruption")
assert(C.lastAbortReason == "queue corruption", "queue-corruption reason was not retained")

start(60)
B._sfP3Queue = {}
for index = 1, 41 do B._sfP3Queue[index] = {} end
C:CheckRuntime("test hard bound")
assert_off("hard queue bound")
assert(C.lastAbortReason == "hard queue bound exceeded", "hard-bound reason was not retained")

start(60)
profileStep = 11
assert(ingest(52), "slow-frame source was not queued")
assert(worker(), "worker missing for slow-frame test")(B._sfP3Frame, .01)
profileStep = .05
assert_off("slow worker frame")
assert(C.lastAbortReason == "worker frame exceeded 10 ms", "slow-frame reason was not retained")

start(60)
B._sfP3Stats.inlineParserCalls = 1
C:CheckRuntime("test forbidden render")
assert_off("forbidden render")
assert(C.lastAbortReason == "forbidden ChatFrame render work", "forbidden-render reason was not retained")

start(60)
P3._filterInstalled = true
C:CheckRuntime("test unexpected filter")
assert_off("unexpected filter")
assert(C.lastAbortReason == "Public Groups render filters appeared while Chat Links were Off",
  "unexpected-filter reason was not retained")

start(60)
SignalFireCacheLifecycle151:Run("chat-test")
assert_off("chat maintenance")
assert(C.lastAbortReason == "chat-triggered cache maintenance", "chat-maintenance reason was not retained")

-- Test 6: repeated completion/abort/off/reconciliation leaves no active owner.
for index = 1, 100 do
  if index % 3 == 0 then
    start(1)
    advance(1.1)
    C.frame:GetScript("OnUpdate")(C.frame, .25)
  elseif index % 3 == 1 then
    start(60)
    parser_command("parser abort")
  else
    parser_command("parser off")
  end
  P3.Apply()
  P3.ReconcileFilterRegistration()
  parser_command("parser status")
  parser_command("parser report")
  assert_off("lifecycle " .. tostring(index))
end

-- Test 7: Phase 12C ownership and worker budgets remain unchanged.
assert(P3.workerMaximumRecords == 4 and P3.workerMaximumMs == .75, "worker budget changed")
assert(P3.generation == "1.5.2-phase12c", "source owner changed")
assert(((B._sfP3Stats or {}).historicalFullTableDuplicateScans or 0) == 0,
  "historical live-chat scan returned")
assert_off("final state")

print("parser safety canary harness: PASS (lifecycle=100, finalFilters="
  .. tostring(runtime().filtersInstalled) .. ", finalQueue=" .. tostring(runtime().queueDepth) .. ")")
