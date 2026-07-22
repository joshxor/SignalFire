local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local P3 = assert(SignalFireChatRuntime151, "Phase 12C runtime did not load")
assert(P3.generation == "1.5.3-phase12c-coverage", "unexpected exact-link owner")
assert(SignalFire_VERSION == "1.5.3", "unexpected visible version")
assert(SignalFire_RELEASE_CHANNEL == "stable", "unexpected release channel")
assert(SignalFire_RELEASE_NAME == "SignalFire 1.5.3",
  "unexpected release name")
assert(SignalFire_DEVELOPMENT_MILESTONE == "Guild and Group Link Coverage",
  "unexpected development milestone")

local testNow = 1800000
local profileClock = 1000
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() profileClock = profileClock + .01; return profileClock end

B.SignalFireTestSay = true
B:SF151_SetDeveloperDiagnostics(true)

local function count(values)
  local result = 0
  for _ in pairs(values or {}) do result = result + 1 end
  return result
end

local function reset()
  BronzeLFG_DB.options.serverProfile = "Ascension"
  BronzeLFG_DB.options.publicGroups = true
  BronzeLFG_DB.options.inlineChatLinks = true
  BronzeLFG_DB.options.chatLinkScope = "all"
  B.publicGroups = {}
  P3.ClearRuntimeCaches()
  B:SF151_DedupePublicGroups()
  P3.Apply()
  B:SF151_ResetChatRuntimeStats()
end

local function drain()
  local frame = assert(B._sfP3Frame, "worker frame missing")
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    local update = assert(frame:GetScript("OnUpdate"), "active worker missing")
    update(frame, .01)
    guard = guard + 1
    assert(guard < 1000, "worker queue did not drain")
  end
  assert(frame:GetScript("OnUpdate") == nil and not frame:IsShown(), "worker did not sleep")
end

local function filter(frame, text, author)
  local _, rendered = P3.Filter(frame, "CHAT_MSG_CHANNEL", text, author, nil, "3. Newcomers")
  return rendered
end

local fixtures = {
  {"LFM Kazzak | Heasl and dps no HR PST", "Lord Kazzak - Need H/D"},
  {"LFM HEAL RDF SPAM WE HAVE AURA", "Random Dungeon Finder - Need H"},
  {"Mythic geared dps LFG Snowgrave/Kaldros/Soggoth", "Snowgrave / Kaldros / Soggoth - LFG D"},
  {"lf 1 tank 1 healer 20+ we have aura rdf spam", "Random Dungeon Finder - Need T/H"},
  {"LFM Vault need tank then gtg", "Vaults of Inquisition - Need T"},
  {"48 tank LFG RDF group with aura", "Random Dungeon Finder - LFG T"},
  {"lvl 22 dps LF team with aura RDF spam", "Random Dungeon Finder - LFG D"},
  {"lvl 56 DPS with exp aura | RDF spam 50+ grp", "Random Dungeon Finder - LFG D"},
  {"Healer LFG BFD", "Blackfathom Deeps - LFG H"},
  {"LFM good Dps 1k+ Dungeon farm 35+", "Random Dungeon Finder - Need D"},
  {"TANK LF GRP WITH AURA TO RDF SPAM", "Random Dungeon Finder - LFG T"},
  {"LFM RDF NEED TANK / DPS", "Random Dungeon Finder - Need T/D"},
  {"LFM SPAM RDF Need Tank Healer DPS WITH HAVE AURAS 40+", "Random Dungeon Finder - Need T/H/D"},
  {"lf dps and support azuregos instanced", "Azuregos - Need D"},
  {"lv 46 SC DPS with AURA LFG", "Random Dungeon Finder - LFG D"},
  {"LF2M Tank and 1 DPS 45+ WE HAVE AURAS EXP", "Random Dungeon Finder - Need T/D"},
}

for _, frameCount in ipairs({1, 2, 5, 10}) do
  for fixtureIndex, fixture in ipairs(fixtures) do
    reset()
    local author = "Source" .. tostring(frameCount) .. "x" .. tostring(fixtureIndex)
    local expectedLink, stableId = nil, nil
    for occurrence = 1, 3 do
      local rec, sourceDisplay = P3.IngestSource(author, fixture[1], "3. Newcomers", "CHAT_MSG_CHANNEL")
      if not rec then
        local trace = P3.TraceMessage(fixture[1])
        local state = P3.GetParserRuntimeState()
        local counters = B:SF151_GetChatPublicIndexDiagnostics().counters
        local direct = SignalFireFastChatLinks.TestParse(fixture[1])
        error("source resolver rejected fixture: " .. fixture[1]
          .. " (" .. tostring(trace and trace.rejectionReason or "no reason")
          .. ", active=" .. tostring(state.sourceActive) .. ", suspended=" .. tostring(state.suspended)
          .. ", candidate=" .. tostring(counters.candidateGateCalls)
          .. ", parser=" .. tostring(counters.parserCalls)
          .. ", errors=" .. tostring(counters.processingErrors)
          .. ", direct=" .. tostring(direct and direct.eligible) .. "/" .. tostring(direct and direct.activity) .. ")")
      end
      assert(string.find(sourceDisplay, fixture[2], 1, true),
        "source display title mismatch: " .. fixture[1] .. " => " .. tostring(sourceDisplay))
      for frameIndex = 1, frameCount do
        local rendered = filter(_G["ChatFrame" .. tostring(frameIndex)], fixture[1], author)
        assert(string.find(rendered, fixture[2], 1, true), "frame missed exact title: " .. fixture[1])
        assert(not string.find(rendered, "[SignalFire Group]", 1, true), "generic SignalFire link emitted")
        assert(not string.find(rendered, "[Group Listing]", 1, true), "generic group link emitted")
        assert(not string.find(rendered, "[Looking For Group]", 1, true), "generic LFG link emitted")
        local link = string.match(rendered, "(|cff%x+|Hbronzelfgpub:[^|]+|h%[[^%]]+%]|h|r)")
        local id = string.match(rendered, "bronzelfgpub:([^|]+)")
        assert(link and id, "exact hyperlink or stable ID missing: " .. fixture[1])
        expectedLink = expectedLink or link
        stableId = stableId or id
        assert(link == expectedLink and id == stableId, "receiving frames diverged")
      end
      testNow = testNow + 1
    end
    assert(count(B.publicGroups) == 1 and B.publicGroups[stableId], "canonical row identity diverged")
    local stats = B:SF151_GetChatPublicIndexDiagnostics().counters
    assert((stats.candidateGateCalls or 0) == 3, "candidate work did not remain once per occurrence")
    assert((stats.TestParseCalls or 0) == 3, "TestParse did not remain once per occurrence")
    assert((stats.canonicalUpserts or 0) == 3, "canonical upsert did not remain once per occurrence")
    assert((stats.exactLinksBuilt or 0) >= 1 and (stats.exactLinksBuilt or 0) <= 3,
      "exact link construction exceeded one build per occurrence")
    assert((stats.filterReceipts or 0) == frameCount * 3, "filter receipts did not scale only by frames")
    assert((stats.normalizationCalls or 0) == 1, "normalization scaled with occurrences or ChatFrames")
    assert((stats.eligibleMessagesWithoutLinks or 0) == 0, "eligible message lacked an exact link")
    assert((stats.genericLinksBuilt or 0) == 0, "generic link was built")
    assert((stats.historicalFullTableDuplicateScans or 0) == 0, "live chat used a full-table scan")
    drain()
  end
end

-- The first filter may own resolution when frame delivery precedes the source owner.
reset()
local refreshes, notifications = 0, 0
local oldRefresh, oldNotify = B.RequestPublicGroupsRefresh, B.NotifyForPublicGroup
B.RequestPublicGroupsRefresh = function(...) refreshes = refreshes + 1; return oldRefresh and oldRefresh(...) end
B.NotifyForPublicGroup = function(...) notifications = notifications + 1; return oldNotify and oldNotify(...) end
local fallbackText = "LFM MC need heals"
local first = filter(ChatFrame1, fallbackText, "FilterFirst")
assert(string.find(first, "Molten Core - Need H", 1, true), "filter fallback missed first occurrence")
assert(refreshes == 0 and notifications == 0, "filter fallback performed deferred side effects")
local rec, sourceDisplay = P3.IngestSource("FilterFirst", fallbackText, "3. Newcomers", "CHAT_MSG_CHANNEL")
assert(rec and sourceDisplay == first, "source did not reuse filter-owned exact decision")
for index = 2, 10 do assert(filter(_G["ChatFrame" .. index], fallbackText, "FilterFirst") == first) end
local fallbackStats = B:SF151_GetChatPublicIndexDiagnostics().counters
assert((fallbackStats.candidateGateCalls or 0) == 1 and (fallbackStats.TestParseCalls or 0) == 1,
  "filter-first ownership duplicated classification")
assert((fallbackStats.canonicalUpserts or 0) == 1 and (fallbackStats.exactLinksBuilt or 0) == 1,
  "filter-first ownership duplicated row or link work")
assert((fallbackStats.normalizationCalls or 0) == 1, "source/filter paths normalized independently")
assert((fallbackStats.exactResolverFilterOwners or 0) == 1, "filter owner was not recorded")
drain()
B.RequestPublicGroupsRefresh, B.NotifyForPublicGroup = oldRefresh, oldNotify

-- Ineligible field captures remain byte-for-byte ordinary chat.
for index, text in ipairs({
  "any lvling guilds recruiting?",
  "Massmorra aleatoria disponivel hoje, confira as novidades!",
}) do
  reset()
  local rec, display = P3.IngestSource("Ignored" .. tostring(index), text, "3. Newcomers", "CHAT_MSG_CHANNEL")
  assert(rec == nil and display == text, "ignored fixture entered source parsing")
  assert(filter(ChatFrame1, text, "Ignored" .. tostring(index)) == text, "ignored fixture gained a link")
  assert(count(B.publicGroups) == 0 and #(B._sfP3Queue or {}) == 0, "ignored fixture mutated runtime state")
end

-- The bounded trace reports source/filter identity and the exact canonical result.
reset()
local trace = P3.TraceMessage("LFM RDF NEED TANK / DPS")
assert(trace.keyMatches and trace.candidateAccepted and trace.exactParserResult == "eligible", "trace decision failed")
assert(trace.activity == "Random Dungeon Finder" and trace.intent == "Recruiter", "trace semantics failed")
assert(trace.canonicalRowExists and trace.stableId and trace.finalHyperlink, "trace canonical link failed")
assert(trace.parserCallCount == 1 and trace.upsertCount == 1 and trace.linkBuildCount == 1,
  "trace work counts were not exact")
assert(B:SF152_HandleParserSlash("parser trace LFM MC need heals") == true,
  "/sf parser trace was not handled by the final slash owner")
assert(hash_SlashCmdList["/sf"]("parser trace Healer LFG BFD") == true,
  "final /sf owner did not route parser trace")

print("exact contextual chat links harness: PASS")
print("fixtures=" .. tostring(#fixtures) .. ", occurrences=3, frames=1/2/5/10")
