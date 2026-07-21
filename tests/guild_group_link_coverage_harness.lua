local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local P3 = assert(SignalFireChatRuntime151, "chat runtime did not load")
assert(P3.generation == "1.5.3-phase12c-coverage", "unexpected coverage owner")

local testNow = 1900000
local profileClock = 2000
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
  BronzeLFG_DB.options.parseGuildRecruitment = true
  BronzeLFG_DB.options.chatLinkScope = "all"
  BronzeLFG_DB.chatGuildListings = {}
  B.chatGuildListings = {}
  B.publicGroups = {}
  P3.ClearRuntimeCaches()
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
end

local function filter(frame, text, author)
  local _, rendered = P3.Filter(frame, "CHAT_MSG_CHANNEL", text, author, nil, "3. Newcomers")
  return rendered
end

local guildFixtures = {
  {"Mercenarios Guild Latina PVE Recluta jugadores nuevos o veteranos para realizar contenido PVE, u Mythic", "Mercenarios"},
  {"<NETWORK ERROR> is a Guild looking for active members to run mythics and progress together; we also have tons of members with *AURA* leveling alts Active and experienced leadership looking to set up RAID GROUPS soon raid times will be polled and up to yo", "NETWORK ERROR"},
  {"<Full Retards> PvP guild, is looking for active committed players to join our core group for World Bosses, BG's, Arenas, High Risk, Crows Cache, World PvP, Premades. Whisper for invite. Come join the cause.", "Full Retards"},
  {"<Highly Regarded> Realm firster clears somewhere. We hold fastest kills for all 6 CoA world bosses by significant margins. Preferably looking for necromancers, felsworn, templars, or any pumper. Raiding 8-11 pm EST Sun/Mon.", "Highly Regarded"},
  {"<Relentless> Currently 100+ level 60s strong, active PvE Ascended Raiding Guild w/300+ members on a lively Discord. 2 Raid Teams Wed/Thu 7pm PST & Sat/Sun 6PM PST. New & veteran players welcome - passionate vibes, active community. PST for guild invite", "Relentless"},
}

for _, order in ipairs({"source-first", "filter-first"}) do
  for _, frameCount in ipairs({1, 2, 5, 10}) do
    for fixtureIndex, fixture in ipairs(guildFixtures) do
      reset()
      local author = "Guild" .. order .. tostring(frameCount) .. "x" .. tostring(fixtureIndex)
      local expectedLink
      for occurrence = 1, 3 do
        local rec, sourceDisplay
        if order == "filter-first" then
          local first = filter(ChatFrame1, fixture[1], author)
          assert(string.find(first, "bronzelfgguild:", 1, true), "filter-first guild link missing")
        end
        rec, sourceDisplay = P3.IngestSource(author, fixture[1], "3. Newcomers", "CHAT_MSG_CHANNEL")
        assert(rec and rec.kind == "guild" and rec.guildRow, "guild source resolution failed")
        assert(rec.guildName == fixture[2], "guild name mismatch: " .. tostring(rec.guildName))
        assert(string.find(sourceDisplay, "bronzelfgguild:", 1, true), "source guild link missing")
        assert(count(B.chatGuildListings) == 1, "canonical Guild Browser row was not ready")
        for frameIndex = 1, frameCount do
          local rendered = filter(_G["ChatFrame" .. tostring(frameIndex)], fixture[1], author)
          local link = string.match(rendered, "(|cff%x+|Hbronzelfgguild:[^|]+|h%[[^%]]+%]|h|r)")
          assert(link, "receiving frame missed exact guild link")
          expectedLink = expectedLink or link
          assert(link == expectedLink, "guild hyperlink changed across frames or occurrences")
        end
        testNow = testNow + 1
      end
      drain()
      local stats = B:SF151_GetChatPublicIndexDiagnostics().counters
      assert((stats.candidateGateCalls or 0) == 3, "guild candidate work multiplied")
      assert((stats.TestParseCalls or 0) == 3, "guild parser work multiplied")
      assert((stats.canonicalUpserts or 0) == 3, "guild canonical upsert count was not exact")
      assert((stats.guildCanonicalUpserts or 0) == 3, "guild canonical owner count was not exact")
      assert((stats.eligibleGuildMessagesWithoutLinks or 0) == 0, "eligible guild message lacked a link")
      local expectedReceipts = frameCount * 3 + (order == "filter-first" and 3 or 0)
      assert((stats.filterReceipts or 0) == expectedReceipts, "guild filter receipt count mismatch")
    end
  end
end

local groupFixtures = {
  {"lf dps and support azuregos instanced", "Azuregos - Need D", "Azuregos", "Recruiter"},
  {"lv 46 SC DPS with AURA LFG", "Random Dungeon Finder - LFG D", "Random Dungeon Finder", "Applicant", "SC"},
  {"LF2M Tank and 1 DPS 45+ WE HAVE AURAS EXP", "Random Dungeon Finder - Need T/D", "Random Dungeon Finder", "Recruiter"},
}

for _, fixture in ipairs(groupFixtures) do
  reset()
  local rec, display = P3.IngestSource("GroupCoverage", fixture[1], "3. Newcomers", "CHAT_MSG_CHANNEL")
  assert(rec and rec.kind == "group", "group fixture was rejected")
  assert(rec.parsed.activity == fixture[3] and rec.parsed.intent == fixture[4], "group semantics mismatch")
  assert(rec.parsed.unknownActivity == fixture[5], "ambiguous activity diagnostic mismatch")
  assert(string.find(display, fixture[2], 1, true), "group exact link title mismatch")
  assert(count(B.publicGroups) == 1 and B.publicGroups[rec.stableId], "group canonical row missing")
  drain()
end

for _, text in ipairs({
  "~~ USE PROPER CHAT CHANNELS ~~ [/join Guild Recruitment] -- [/join Trade -- /join Poll] ~~",
  "any lvling guilds recruiting?",
}) do
  reset()
  local rec, display = P3.IngestSource("NegativeGuild", text, "3. Newcomers", "CHAT_MSG_CHANNEL")
  assert(rec == nil and display == text, "negative guild fixture was accepted")
  assert(filter(ChatFrame1, text, "NegativeGuild") == text, "negative guild fixture gained a link")
  assert(count(B.chatGuildListings) == 0 and count(B.publicGroups) == 0, "negative fixture created a row")
end

reset()
local trace = P3.TraceMessage(guildFixtures[2][1])
assert(trace.keyMatches and trace.kind == "guild" and trace.guildRecruiter == true, "guild trace semantics failed")
assert(trace.guildSeeker == false and trace.guildName == "NETWORK ERROR", "guild trace classification failed")
assert(trace.canonicalRowExists and trace.finalHyperlink and trace.upsertCount == 1, "guild trace ownership failed")

-- Guild/group-heavy city-chat simulation. Exactly ten percent of the traffic is
-- eligible; ordinary English/Spanish conversation and BLFG312 packets remain cheap.
reset()
local cityMessages = 10000
for index = 1, cityMessages do
  local message
  if index % 20 == 0 then
    message = guildFixtures[(index / 20) % #guildFixtures + 1][1]
  elseif index % 20 == 1 then
    message = "lf dps and support azuregos instanced run " .. tostring(index)
  elseif index % 5 == 0 then
    message = "BLFG312~PING~" .. tostring(index)
  elseif index % 3 == 0 then
    message = "hola jugadores, que tal la zona hoy " .. tostring(index)
  else
    message = "ordinary city conversation " .. tostring(index)
  end
  local author = "City" .. tostring(index)
  P3.IngestSource(author, message, "3. Newcomers", "CHAT_MSG_CHANNEL")
  for frameIndex = 1, 10 do filter(_G["ChatFrame" .. tostring(frameIndex)], message, author) end
  if index % 100 == 0 then drain() end
end
drain()
local city = B:SF151_GetChatPublicIndexDiagnostics().counters
assert((city.TestParseCalls or 0) == 1000, "city-chat parser work exceeded eligible messages")
assert((city.canonicalUpserts or 0) == 1000, "city-chat canonical work was not exact")
assert((city.filterReceipts or 0) == cityMessages * 10, "city-chat filter receipts were incomplete")
assert((city.eligibleGuildMessagesWithoutLinks or 0) == 0, "city-chat guild link miss")
assert((city.eligibleGroupMessagesWithoutLinks or 0) == 0, "city-chat group link miss")
assert((city.historicalFullTableDuplicateScans or 0) == 0, "city-chat used a full-table scan")
assert((city.inlineCacheSweepCalls or 0) == 0, "city-chat triggered cache maintenance")
assert(count(P3._renderDecisionCache) <= 256 and count(P3._semanticKeyCache) <= 256,
  "city-chat decision caches exceeded their bounds")

print("guild and group link coverage harness: PASS")
print("guildFixtures=5, groupFixtures=3, orders=2, occurrences=3, frames=1/2/5/10, city=10000")
