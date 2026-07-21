local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local chat = assert(SignalFireChatRuntime151, "Phase 12C chat owner did not load")
assert(chat.generation == "1.5.2-phase12c", "unexpected chat owner")
local stressMessages = tonumber(arg and arg[3]) or 50000
local parsingOffMessages = tonumber(arg and arg[4]) or 100000
assert(stressMessages >= 100 and stressMessages % 100 == 0, "stress message count must be a multiple of 100")

local testNow = 1600000
local profileClock = 1000
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() profileClock = profileClock + .05; return profileClock end

B:SF151_SetDeveloperDiagnostics(true)
B.SignalFireTestSay = true

local function count(values)
  local result = 0
  for _ in pairs(values or {}) do result = result + 1 end
  return result
end

local function drain()
  local frame = assert(B._sfP3Frame, "worker frame missing")
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    local update = assert(frame:GetScript("OnUpdate"), "active worker OnUpdate missing")
    update(frame, .01)
    guard = guard + 1
    assert(guard < 10000, "worker queue did not drain")
  end
  assert(not frame:IsShown(), "worker remained active after queue drained")
  assert(frame:GetScript("OnUpdate") == nil, "worker OnUpdate remained installed after drain")
end

local function reset(publicGroups, links)
  BronzeLFG_DB.options.publicGroups = publicGroups
  BronzeLFG_DB.options.inlineChatLinks = links
  BronzeLFG_DB.options.chatLinkScope = "all"
  B.publicGroups = {}
  chat.ClearRuntimeCaches()
  B:SF151_DedupePublicGroups()
  chat.Apply()
  B:SF151_ResetChatRuntimeStats()
end

local function stats()
  return B:SF151_GetChatPublicIndexDiagnostics().counters
end

local negative = {
  "What tank build should I use?", "Does the queue work?", "My guild is quiet tonight.",
  "Do I need a key?", "That healer is good.", "Mythic talents feel weird.",
  "Join Discord for patch notes.", "The invasion was fun.", "Which dungeon drops this?",
  "Can DPS use this item?", "The raid was fun.", "This group is loud.",
}

-- State 1: 100,000 source events return before candidate, parser, queue, or filters.
reset(false, false)
for index = 1, parsingOffMessages do
  local message = index % 97 == 0 and "LFM MC need healer" or negative[(index % #negative) + 1]
  assert(chat.IngestSource("Off" .. tostring(index), message, "3. Newcomers", "CHAT_MSG_CHANNEL") == nil,
    "parsing-off source returned a record")
end
local off = stats()
assert((off.candidateGateCalls or 0) == 0, "parsing-off traffic reached the candidate gate")
assert((off.TestParseCalls or 0) == 0, "parsing-off traffic reached TestParse")
assert((off.queueRecordsCreated or 0) == 0, "parsing-off traffic created queue records")
assert((off.filtersCurrentlyInstalled or 0) == 0, "parsing-off mode retained filters")
assert((off.filterReceipts or 0) == 0 and (off.chatLinesRewritten or 0) == 0,
  "parsing-off mode touched display filters")
assert(not B._sfP3Frame:IsShown(), "parsing-off mode woke the worker")

-- Generic terms without recruitment context never invoke TestParse.
reset(true, false)
for index, message in ipairs(negative) do
  chat.IngestSource("Negative" .. tostring(index), message, "3. Newcomers", "CHAT_MSG_CHANNEL")
end
local rejected = stats()
assert((rejected.candidateGateCalls or 0) == #negative, "negative gate call count is incorrect")
assert((rejected.candidateGateRejected or 0) == #negative, "ordinary conversation passed the gate")
assert((rejected.TestParseCalls or 0) == 0 and (rejected.queueRecordsCreated or 0) == 0,
  "ordinary conversation reached the parser queue")

-- Every accepted parser fixture reaches the queue; the parser suite itself verifies results.
reset(true, false)
local accepted = 0
for index, fixture in ipairs(SignalFireParserRegression.tests or {}) do
  if not fixture.ignore then
    accepted = accepted + 1
    assert(chat.Candidate(fixture.text), "candidate gate rejected fixture: " .. tostring(fixture.name))
    assert(chat.IngestSource("Fixture" .. tostring(index), fixture.text, "3. Newcomers", "CHAT_MSG_CHANNEL"),
      "source owner rejected fixture: " .. tostring(fixture.name))
  end
end
drain()
local acceptedStats = stats()
assert((acceptedStats.TestParseCalls or 0) == accepted, "accepted fixtures did not all reach TestParse")
assert(SignalFireParserRegression.Run().failed == 0, "48-case parser regression failed")

local function stress(frameCount, links)
  reset(true, links)
  local frames = {}
  for index = 1, frameCount do frames[index] = _G["ChatFrame" .. tostring(index)] end
  for index = 1, stressMessages do
    local valid = index % 100 == 0
    local message = valid and ("LFM MC need healer run " .. tostring(index))
      or (negative[(index % #negative) + 1] .. " " .. tostring(index))
    local author = "Stress" .. tostring(index)
    chat.IngestSource(author, message, "3. Newcomers", "CHAT_MSG_CHANNEL")
    if links then
      for frameIndex = 1, frameCount do
        chat.Filter(frames[frameIndex], "CHAT_MSG_CHANNEL", message, author,
          nil, nil, nil, nil, nil, nil, nil, "3. Newcomers")
      end
    end
    if index % 50 == 0 then drain() end
  end
  drain()
  local result = stats()
  local expectedParsed = stressMessages / 100
  assert((result.TestParseCalls or 0) == expectedParsed, "stress parser call count changed")
  assert((result.queueRecordsCreated or 0) == expectedParsed
      and (result.queueRecordsProcessed or 0) == expectedParsed,
    "stress queue count changed")
  assert((result.historicalFullTableDuplicateScans or 0) == 0,
    "live chat reached the historical duplicate scan")
  assert((result.inlineCandidateCalls or 0) == 0 and (result.inlineParserCalls or 0) == 0
      and (result.inlineQueueCalls or 0) == 0 and (result.inlineUpsertCalls or 0) == 0
      and (result.inlineRefreshCalls or 0) == 0 and (result.inlineSavedVariableWrites or 0) == 0
      and (result.inlineCacheSweepCalls or 0) == 0,
    "display path performed forbidden work")
  if links then
    assert((result.filtersCurrentlyInstalled or 0) == 3, "links-on filter count is not three")
    assert((result.filterReceipts or 0) == stressMessages * frameCount, "filter receipts did not scale only by frames")
  else
    assert((result.filtersCurrentlyInstalled or 0) == 0, "links-off mode retained filters")
    assert((result.filterReceipts or 0) == 0 and (result.chatLinesRewritten or 0) == 0,
      "links-off mode touched display filters")
  end
  assert(count(chat._decisionCache) <= 256 and count(chat._renderDecisionCache) <= 256,
    "chat decision cache exceeded its bound")
  print("stress " .. (links and "links-on" or "links-off") .. " frames=" .. tostring(frameCount)
    .. ": source=" .. tostring(stressMessages) .. ", TestParse=" .. tostring(result.TestParseCalls or 0)
    .. ", filters=" .. tostring(result.filterReceipts or 0))
  return result
end

local matrix = {}
for _, links in ipairs({false, true}) do
  local label = links and "on" or "off"
  matrix[label] = {}
  for _, frameCount in ipairs({1, 2, 5, 10}) do
    matrix[label][frameCount] = stress(frameCount, links)
  end
end
for _, label in ipairs({"off", "on"}) do
  local baseline = matrix[label][1]
  for _, frameCount in ipairs({2, 5, 10}) do
    local item = matrix[label][frameCount]
    assert(item.TestParseCalls == baseline.TestParseCalls, "TestParse scaled with ChatFrame count")
    assert(item.queueRecordsCreated == baseline.queueRecordsCreated, "queue work scaled with ChatFrame count")
    assert(item.queueRecordsProcessed == baseline.queueRecordsProcessed, "processed work scaled with ChatFrame count")
  end
end

-- Worker budget and deterministic overflow.
reset(true, false)
for index = 1, 45 do
  chat.IngestSource("Burst" .. tostring(index), "LFM MC need healer " .. tostring(index),
    "3. Newcomers", "CHAT_MSG_CHANNEL")
end
assert(#B._sfP3Queue == 40, "queue did not enforce its maximum")
local update = assert(B._sfP3Frame:GetScript("OnUpdate"), "worker OnUpdate missing")
update(B._sfP3Frame, .01)
assert(#B._sfP3Queue >= 36, "worker exceeded the four-record maximum")
drain()
local budget = stats()
assert((budget.queueDrops or 0) == 5, "overflow drop accounting is incorrect")
assert((budget.workerMaximumRecordMs or 0) >= 0 and (budget.workerMaximumFrameMs or 0) >= 0,
  "worker timing diagnostics are invalid")

-- Reconciliation remains idempotent through repeated option and lifecycle transitions.
local originalSetItemRef = SetItemRef
local originalAddMessage = ChatFrame1.AddMessage
for index = 1, 100 do
  BronzeLFG_DB.options.publicGroups = false
  BronzeLFG_DB.options.inlineChatLinks = false
  chat.Apply()
  assert(B:SF151_GetChatFilterState().knownSignalFireRegistrations == 0, "parsing-off toggle retained filters")
  BronzeLFG_DB.options.publicGroups = true
  BronzeLFG_DB.options.inlineChatLinks = false
  chat.Apply()
  assert(B:SF151_GetChatFilterState().knownSignalFireRegistrations == 0, "links-off toggle retained filters")
  BronzeLFG_DB.options.inlineChatLinks = true
  chat.Apply()
  chat.Apply()
  assert(B:SF151_GetChatFilterState().knownSignalFireRegistrations == 3, "links-on toggle lost filters")
end
assert(SetItemRef == originalSetItemRef, "SignalFire changed SetItemRef ownership")
assert(ChatFrame1.AddMessage == originalAddMessage, "SignalFire changed AddMessage ownership")

-- Native hyperlinks and completed cache misses pass through byte-for-byte.
local native = {
  "|cff0070dd|Hitem:19019:0:0:0:0:0:0:0|h[Thunderfury]|h|r",
  "|cff71d5ff|Hspell:133|h[Fireball]|h|r",
  "|cffffff00|Hquest:1:60|h[Test Quest]|h|r",
  "|cffffff00|Hachievement:6:Harness:1:1:1:1:0:0:0:0|h[Level 10]|h|r",
  "|Hplayer:Tester|h[Tester]|h", "|cffffd000|Htrade:51309:450:450|h[Tailoring]|h|r",
}
for index, message in ipairs(native) do
  local _, rendered = chat.Filter(ChatFrame1, "CHAT_MSG_CHANNEL", message, "Native" .. tostring(index))
  assert(rendered == message, "native hyperlink was modified")
end

print("public chat parser FPS harness: PASS")
print("matrix links-off: frames 1/2/5/10, source=" .. tostring(stressMessages))
print("matrix links-on: frames 1/2/5/10, source=" .. tostring(stressMessages))
