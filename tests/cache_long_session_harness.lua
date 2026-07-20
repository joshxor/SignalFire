local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load from " .. tostring(addonRoot))
local CL = assert(SignalFireCacheLifecycle151, "Phase 9 cache lifecycle owner did not load")
local P3 = assert(SignalFireChatRuntime151, "Phase 5 chat owner did not load")
assert(P3.generation == "1.5.2-phase12b", "unexpected chat owner")

local testNow = 1000000
function time() return math.floor(testNow) end
function GetTime() return testNow end

SignalFirePerf151.enabled = true
B:SF151_ResetCacheLifecycleStats()
B:SF151_ResetChatRuntimeStats()
BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
B.onlineUsers = B.onlineUsers or {}
B.sfnStatuses = B.sfnStatuses or {}
B._notifySeen569 = B._notifySeen569 or {}

local function count(values)
  local total = 0
  for _ in pairs(values or {}) do total = total + 1 end
  return total
end

local queueScript = assert(B._sfP3Frame:GetScript("OnUpdate"), "chat queue owner missing")
local filter = assert(P3.Filter, "source chat filter missing")
local milestones = {[5000]=true, [10000]=true, [25000]=true, [50000]=true}
local samples = {}

local function drain()
  while #(B._sfP3Queue or {}) > 0 do queueScript(B._sfP3Frame, .1) end
end

local function memorySample()
  local ok, value = pcall(collectgarbage, "count")
  return ok and tonumber(value or 0) or nil
end

local memoryStart = memorySample()
local memoryWarmup, memoryPeak = nil, memoryStart
local mixedMessages = {
  "ordinary busy chat line",
  "LFM MC need healer",
  "<Harness Guild> recruiting members for dungeons and raids",
  "LFG RDF spam",
  "|cff00ff00colored ordinary chat|r",
  "look at |Hitem:12345:0:0:0|h[Malformed Item Link]|h please",
  "https://example.invalid/not-a-group",
  string.rep("long message ", 18),
}
for index = 1, 50000 do
  testNow = testNow + .01
  -- Every event reaches the lifecycle owner. One in ten also traverses the real
  -- source owner because the JavaScript-hosted Lua emulator is substantially
  -- slower than WoW's native Lua 5.1 runtime.
  if index % 10 == 0 then
    local text = mixedMessages[((index / 10 - 1) % #mixedMessages) + 1] .. " " .. tostring(index)
    local event = index % 70 == 0 and "CHAT_MSG_YELL" or index % 50 == 0 and "CHAT_MSG_SAY" or "CHAT_MSG_CHANNEL"
    local channel = event == "CHAT_MSG_CHANNEL" and (index % 30 == 0 and "4. Zone" or "3. Newcomers") or nil
    P3.IngestSource("Player" .. tostring(index % 700), text, channel, event)
    local receipts = index % 100 == 0 and 10 or 1
    for frameIndex = 1, receipts do
      filter(_G["ChatFrame" .. tostring(frameIndex)] or ChatFrame1, event, text,
        "Player" .. tostring(index % 700), nil, nil, nil, nil, nil, nil, nil, channel)
    end
  end
  CL:ObserveChat()
  if index % 100 == 0 then drain() end

  B._notifySeen569 = B._notifySeen569 or {}
  B._notifySeen569["notice-" .. tostring(index)] = testNow
  if index % 4 == 0 then
    B.onlineUsers["online-" .. tostring(index)] = {seen=testNow}
    B.sfnStatuses["status-" .. tostring(index)] = {seen=testNow}
  end
  if milestones[index] then
    local ok = B:SF151_RunCacheMaintenance("milestone-" .. tostring(index))
    assert(ok, "milestone cleanup failed")
    samples[#samples + 1] = {messages=index, memory=memorySample(),
      decisions=count(P3._decisionCache), renders=count(P3._renderDecisionCache),
      records=count(B._sfP3Records), public=count(B.publicGroups), online=count(B.onlineUsers),
      statuses=count(B.sfnStatuses), notifications=count(B._notifySeen569)}
    local row = samples[#samples]
    if index == 5000 then memoryWarmup = row.memory end
    if row.memory and (not memoryPeak or row.memory > memoryPeak) then memoryPeak = row.memory end
    assert(row.decisions <= 256 and row.renders <= 256 and row.records <= 256,
      "chat caches exceeded their Phase 5 bounds")
    assert(row.public <= CL.maximums.publicGroups, "Public Groups exceeded Phase 9 capacity")
    assert(row.online <= CL.maximums.onlineUsers and row.statuses <= CL.maximums.sfnStatuses,
      "Network cache exceeded Phase 9 capacity")
    assert(row.notifications <= CL.maximums.notificationSeen, "notification cache exceeded Phase 9 capacity")
  end
end
drain()
B:SF151_RunCacheMaintenance("final")
local memoryEnd = memorySample()

assert(#(B._sfP3Queue or {}) == 0, "chat queue did not drain")
local chatReport = B:SF151_GetChatPublicIndexDiagnostics()
assert((chatReport.counters.addMessageParseCalls or 0) == 0, "AddMessage performed parser work")
assert((chatReport.counters.queueDrops or 0) == 0, "bounded-drain simulation dropped parser jobs")
assert(count(P3._decisionCache) <= 256 and count(P3._renderDecisionCache) <= 256,
  "decision caches did not stabilize")
assert(count(B.publicGroups) <= CL.maximums.publicGroups, "Public Groups did not stabilize")
assert(count(B.onlineUsers) <= CL.maximums.onlineUsers and count(B.sfnStatuses) <= CL.maximums.sfnStatuses,
  "Network caches did not stabilize")
assert(count(B._notifySeen569) <= CL.maximums.notificationSeen, "notification cache did not stabilize")
local report = B:SF151_GetCacheLifecycleDiagnostics(false)
assert((report.runs or 0) >= 5, "long-session cleanup did not run")
assert((report.boundedEvictions or 0) > 0, "long-session capacity eviction did not occur")
assert(#(report.errors or {}) == 0, "long-session cleanup recorded errors")
local stability = SignalFireStability151
assert(not stability or (#stability.recent <= stability.maximumRecent and #stability.errors <= stability.maximumErrors),
  "Phase 10 diagnostic history grew without a bound")

print("cache long-session harness: PASS (messages=50000, realFilters=5000, startKB="
  .. (memoryStart and string.format("%.1f", memoryStart) or "unavailable")
  .. ", warmupKB=" .. (memoryWarmup and string.format("%.1f", memoryWarmup) or "unavailable")
  .. ", peakKB=" .. (memoryPeak and string.format("%.1f", memoryPeak) or "unavailable")
  .. ", endKB=" .. (memoryEnd and string.format("%.1f", memoryEnd) or "unavailable")
  .. ", public=" .. tostring(count(B.publicGroups))
  .. ", online=" .. tostring(count(B.onlineUsers)) .. ", decisions=" .. tostring(count(P3._decisionCache)) .. ")")
