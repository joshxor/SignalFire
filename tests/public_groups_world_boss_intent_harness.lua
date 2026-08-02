local addonRoot = assert(arg and arg[1], "addon root is required")
local loader = assert(arg and arg[2], "prepared production loader is required")
dofile(loader)

local B = assert(BronzeLFG, "SignalFire did not load")
local runtime = assert(SignalFireChatRuntime151, "Public Groups parser runtime missing")
BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
B.SignalFireTestSay = true

local sentChat, joinedChannels = 0, 0
SendChatMessage = function() sentChat = sentChat + 1 end
JoinChannelByName = function() joinedChannels = joinedChannels + 1 end

local function parse(text)
  return assert(SignalFireFastChatLinks.TestParse(text), "parser returned nil: " .. text)
end

local function hasRole(value, role)
  return string.find(string.lower(tostring(value or "")), string.lower(role), 1, true) ~= nil
end

local function assertParsed(text, typeName, activity, intent, role)
  local result = parse(text)
  assert(result.type == typeName and result.activity == activity and result.intent == intent,
    text .. " => type=" .. tostring(result.type) .. " activity=" .. tostring(result.activity)
      .. " intent=" .. tostring(result.intent))
  if role then assert(hasRole(result.roles, role), text .. " role metadata missing: " .. role) end
  return result
end

-- Profile-owned World Boss discovery, including the previously supported
-- multi-boss applicant path and the live missed Kazzak tour wording.
assertParsed("LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak", "World Boss", "Lord Kazzak", "Recruiter")
assertParsed("LF DPS Azuregos", "World Boss", "Azuregos", "Recruiter", "DPS")
assertParsed("LFM Azuregos need DPS", "World Boss", "Azuregos", "Recruiter", "DPS")
assertParsed("DPS LFG Azuregos", "World Boss", "Azuregos", "Applicant", "DPS")
assertParsed("LF2 DPS Azuregos", "World Boss", "Azuregos", "Recruiter", "DPS")
assertParsed("LFM Kazzak", "World Boss", "Lord Kazzak", "Recruiter")
assertParsed("need healer Kazzak", "World Boss", "Lord Kazzak", "Recruiter", "Healer")
assertParsed("LFG Kazzak", "World Boss", "Lord Kazzak", "Applicant")
local multiBossApplicant = assertParsed("Mythic geared dps LFG Snowgrave/Kaldros/Soggoth", "World Boss", "Snowgrave / Kaldros / Soggoth", "Applicant", "DPS")
assert(multiBossApplicant.difficulty ~= "Mythic" and multiBossApplicant.difficulty ~= "Mythic+"
  and multiBossApplicant.type ~= "Dungeon" and multiBossApplicant.type ~= "Key",
  "Mythic gear wording leaked Dungeon difficulty into the World Boss result")
assertParsed("LFM Kazzak mythic geared", "World Boss", "Lord Kazzak", "Recruiter")
assertParsed("LFM world boss tour need healer", "World Boss", "World Boss", "Recruiter", "Healer")
assertParsed("LFM ZG", "Raid", "Zul'Gurub", "Recruiter")
assertParsed("tank looking for group ZG", "Raid", "Zul'Gurub", "Applicant", "Tank")

-- Server profiles remain distinct: Ascension bosses do not leak into
-- Triumvirate, while Triumvirate-owned World Boss data remains usable.
BronzeLFG_DB.options.serverProfile = "Triumvirate"
local triAzuregos = parse("LFM Azuregos")
assert(not (triAzuregos.type == "World Boss" and triAzuregos.activity == "Azuregos"), "Ascension Azuregos leaked into Triumvirate")
assertParsed("LFM Xiah", "World Boss", "Xiah", "Recruiter")
BronzeLFG_DB.options.serverProfile = "Ascension"

-- Guild precedence, arbitrary boss wording, and substring boundaries remain
-- protected from World Boss Public Groups classification.
local guild = parse("<Highly Regarded> We hold fastest kills for all 6 CoA world bosses. Preferably looking for any pumper.")
assert(guild.kind == "guild" and guild.type == "Guild", "world-boss guild ad lost Guild precedence")
local raid = parse("LFM ZG world boss clears need DPS")
assert(raid.type == "Raid" and raid.activity == "Zul'Gurub", "raid activity lost precedence to generic World Boss wording")
local ordinaryBoss = SignalFireFastChatLinks.TestParse("the boss is dead now")
assert(not (ordinaryBoss and ordinaryBoss.type == "World Boss"), "ordinary boss sentence became World Boss")
local kazzakSubstring = parse("LFM Kazzakian transmog")
assert(kazzakSubstring.type ~= "World Boss", "unrelated Kazzak-like substring matched World Boss")

local function drainQueue()
  local frame = assert(B._sfP3Frame, "Phase 3 worker frame missing")
  local update = frame.GetScript and frame:GetScript("OnUpdate") or nil
  if type(update) ~= "function" then
    assert(runtime.StartParserWork and runtime.StartParserWork() == true, "Phase 3 worker did not start with queued work")
    update = assert(frame:GetScript("OnUpdate"), "Phase 3 worker update missing")
  end
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    update(frame, .07)
    guard = guard + 1
    assert(guard < 100, "Phase 3 worker did not drain")
  end
  local state = assert(runtime.GetParserRuntimeState(), "Phase 3 worker runtime state missing")
  assert(state.queueDepth == 0 and state.workerScript == false and state.workerActive == false,
    "Phase 3 worker did not return to idle")
end

local function drainRefresh()
  local refresh = assert(SignalFireRefresh151, "Public Groups refresh owner missing")
  local frame = assert(refresh.frame, "Public Groups refresh frame missing")
  local guard = 0
  while refresh.pending == true or (refresh.dirty and refresh.dirty.publicGroups == true) do
    SignalFireHarnessAdvanceTime((tonumber(refresh.debounceSeconds or .15) or .15) + .05)
    local update = assert(frame:GetScript("OnUpdate"), "Public Groups debounce worker missing")
    update(frame, .03)
    guard = guard + 1
    assert(guard < 20, "Public Groups debounce did not drain")
  end
end

local function clearRows()
  B.publicGroups = {}
  runtime.ClearRuntimeCaches()
  B:SF151_InvalidatePublicGroupsData("world-boss-intent-reset")
end

local function findRow(author, text)
  for _, row in pairs(B.publicGroups or {}) do
    if tostring(row.player or "") == author and tostring(row.rawMessage or row.message or "") == text then return row end
  end
  return nil
end

local function ingest(author, text)
  local rec, display = runtime.IngestSource(author, text, "3. Newcomers", "CHAT_MSG_CHANNEL")
  assert(type(rec) == "table", "source owner did not create a parser record: " .. text)
  assert(rec.done ~= true, "source parser record completed before deferred worker: " .. text)
  assert(type(B._sfP3Queue) == "table" and #B._sfP3Queue > 0,
    "source parser record did not enter the deferred queue: " .. text)
  local queued = assert(runtime.GetParserRuntimeState(), "queued parser runtime state missing")
  assert(queued.queueDepth > 0, "source parser record queue depth was not positive: " .. text)
  drainQueue()
  local row = assert(findRow(author, text), "canonical Public Groups row missing: " .. text)
  assert(row.key and tostring(row.key) == tostring(row.id), "canonical row identity changed")
  return row
end

-- End-to-end source -> authoritative parser -> deferred worker -> canonical row.
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
runtime.Apply()
local initialRuntime = assert(runtime.GetParserRuntimeState(), "initial parser runtime state missing")
assert(initialRuntime.sourceActive == true and initialRuntime.workerOwnerActive == true
  and initialRuntime.suspended == false and initialRuntime.queueDepth == 0
  and initialRuntime.workerScript == false,
  "parser runtime was not active and idle after Apply")
clearRows()
local postClearRuntime = assert(runtime.GetParserRuntimeState(), "post-clear parser runtime state missing")
assert(postClearRuntime.sourceActive == true and postClearRuntime.suspended == false
  and postClearRuntime.queueDepth == 0 and postClearRuntime.workerScript == false,
  "ClearRuntimeCaches changed active parser ownership")
local worldTour = ingest("KazzakTour", "LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak")
assert(worldTour.type == "World Boss" and worldTour.activity == "Lord Kazzak" and worldTour.intent == "Recruiter",
  "live Kazzak tour canonical metadata was not preserved")
local worldRecruit = ingest("AzuregosLF", "LF DPS Azuregos")
local worldAura = ingest("AzuregosNeed", "LFM Azuregos need DPS XP aura")
local worldApplicant = ingest("AzuregosLFG", "DPS LFG Azuregos")
local kazzakApplicant = ingest("KazzakLFG", "LFG Kazzak")
assert(worldRecruit.type == "World Boss" and worldRecruit.activity == "Azuregos" and worldRecruit.intent == "Recruiter", "Azuregos recruiter row")
assert(worldAura.xpAura == true and worldAura.roles and hasRole(worldAura.roles, "DPS"), "Azuregos XP Aura metadata")
assert(worldApplicant.type == "World Boss" and worldApplicant.intent == "Applicant" and hasRole(worldApplicant.roles, "DPS"), "Azuregos applicant row")
assert(kazzakApplicant.type == "World Boss" and kazzakApplicant.activity == "Lord Kazzak" and kazzakApplicant.intent == "Applicant", "Kazzak applicant row")

local raidApplicant = ingest("ZGApplicant", "LFG ZG")
local raidRecruiter = ingest("ZGRecruiter", "LFM ZG need DPS")
local rdfApplicant = ingest("RDFApplicant", "DPS LFG RDF")
local rdfRecruiter = ingest("RDFRecruiter", "LFM RDF need DPS")
local mythicApplicant = ingest("MythicApplicant", "DPS LFG BFD Mythic")
local mythicRecruiter = ingest("MythicRecruiter", "LFM BFD Mythic need healer")
local mythicPlusRecruiter = ingest("MythicPlusRecruiter", "LFM BFD M+5 need healer")
assert(raidApplicant.type == "Raid" and raidApplicant.activity == "Zul'Gurub" and raidApplicant.intent == "Applicant", "LFG ZG canonical intent")
assert(raidRecruiter.type == "Raid" and raidRecruiter.activity == "Zul'Gurub" and raidRecruiter.intent == "Recruiter", "LFM ZG canonical intent")
assert(rdfApplicant.intent == "Applicant" and rdfRecruiter.intent == "Recruiter", "RDF intent metadata")
assert(mythicApplicant.type == "Dungeon" and mythicApplicant.difficulty == "Mythic" and mythicApplicant.intent == "Applicant", "plain Mythic applicant")
assert(mythicRecruiter.type == "Dungeon" and mythicRecruiter.difficulty == "Mythic" and mythicRecruiter.intent == "Recruiter", "plain Mythic recruiter")
assert(mythicPlusRecruiter.type == "Key" and mythicPlusRecruiter.difficulty == "Mythic+" and tostring(mythicPlusRecruiter.keyLevel) == "5", "keyed Mythic+ recruiter")

local function setView(filter, intent, difficulty, role, search, aura)
  B.publicFilter = filter or "All"
  B.publicIntentFilter = intent or "All Intents"
  B.publicDifficultyFilter = difficulty or "All Difficulties"
  B.publicRoleFilter = role or "All"
  B.publicSearchText = search or ""
  B.publicXPAuraFilter = aura or "All Listings"
  B:SF151_InvalidatePublicGroupsData("world-boss-intent-view")
  return B:GetSortedPublicGroups()
end

local allRows = setView("All", "All Intents", "All Difficulties")
assert(#allRows == 12, "canonical fixture set changed size")
local counts = assert(B:GetPublicFilterCounts(), "Public Groups counts missing")
assert(counts["World Boss"] == 5 and counts.Raid == 2 and counts.Dungeon == 4 and counts.Key == 1,
  "World Boss or activity type counts changed")

local worldRows = setView("World Boss", "All Intents", "All Difficulties")
assert(#worldRows == 5, "World Boss filter leaked another type")
local worldRecruiting = setView("World Boss", "Recruiting", "All Difficulties")
assert(#worldRecruiting == 3, "Recruiting World Boss filter was not exact")
local worldSeeking = setView("World Boss", "Seeking Group", "All Difficulties")
assert(#worldSeeking == 2, "Seeking Group World Boss filter count changed")
local seekingIds = {}
for _, record in ipairs(worldSeeking) do
  assert(record.kind == "World Boss", "Seeking Group filter leaked a non-World-Boss record")
  assert(record.intent == "Applicant", "Seeking Group filter leaked a non-Applicant record")
  seekingIds[record.id] = true
end
assert(seekingIds[worldApplicant.id] and seekingIds[kazzakApplicant.id],
  "Seeking Group World Boss filter returned the wrong Applicant rows")
local auraWorld = setView("World Boss", "Recruiting", "All Difficulties", "D", "azuregos xp aura", "XP Aura Only")
assert(#auraWorld == 1 and auraWorld[1].id == worldAura.id, "World Boss/search/role/XP Aura intersection changed")

local raidSeeking = setView("Raid", "Seeking Group", "All Difficulties")
assert(#raidSeeking == 1 and raidSeeking[1].id == raidApplicant.id, "Raid intent filter changed")
local mythicRecruiting = setView("Dungeon", "Recruiting", "Mythic")
assert(#mythicRecruiting == 1 and mythicRecruiting[1].id == mythicRecruiter.id, "plain Mythic recruiting filter leaked RDF or applicant rows")
local mythicPlusRecruiting = setView("Key", "Recruiting", "Mythic+")
assert(#mythicPlusRecruiting == 1 and mythicPlusRecruiting[1].id == mythicPlusRecruiter.id, "Mythic+ recruiting filter changed")
assert(#setView("Dungeon", "Seeking Group", "Mythic") == 1 and setView("Dungeon", "Seeking Group", "Mythic")[1].id == mythicApplicant.id,
  "plain Mythic applicant filter changed")

-- The real lazy Public Groups lifecycle owns both controls and their dropdowns.
B.publicFilter, B.publicIntentFilter, B.publicDifficultyFilter = "All", "All Intents", "All Difficulties"
B.publicRoleFilter, B.publicSearchText, B.publicXPAuraFilter = "All", "", "All Listings"
assert(B:ShowPublicGroups() ~= false, "Public Groups did not open")
local PG = assert(SignalFirePublicGroupsView151, "Phase 6 Public Groups owner missing")
local worldButton = assert(B.publicFilterButtons and B.publicFilterButtons["World Boss"], "World Boss control missing")
local intentDrop = assert(B.publicIntentDrop, "Intent dropdown missing")
assert(worldButton:GetParent() == B.publicPanel and intentDrop:GetParent() == B.publicPanel, "Pass C controls escaped panel geometry")
local expectedWorldLabel = "World Boss (" .. tostring(counts["World Boss"]) .. ")"
assert(tostring(worldButton:GetText() or ""):find(expectedWorldLabel, 1, true),
  "World Boss count label did not hydrate from the current snapshot")
local intentOptions = assert(intentDrop:RunDropdownInitializer(), "Intent dropdown initializer missing")
assert(#intentOptions == 3 and intentOptions[1].text == "All Intents" and intentOptions[2].text == "Recruiting"
  and intentOptions[3].text == "Seeking Group", "Intent dropdown options changed")

local sentBeforeFilters, joinedBeforeFilters = sentChat, joinedChannels
B.publicPage = 4
local worldClick = assert(worldButton:GetScript("OnClick"), "World Boss callback missing")
worldClick(worldButton)
assert(B.publicFilter == "World Boss" and B.publicPage == 1, "World Boss click did not reset page")
local recruitingOption = intentOptions[2]
local seekingOption = intentOptions[3]
local selectedBeforeIntent = worldRecruit.id
B.selectedPublic = selectedBeforeIntent
seekingOption.func()
assert(B.publicIntentFilter == "Seeking Group" and B.publicPage == 1 and B.selectedPublic == selectedBeforeIntent,
  "Intent change bypassed the real debounce or changed unrelated state synchronously")
drainRefresh()
assert(B.selectedPublic == nil, "filtered-out selected World Boss row did not clear after debounce")
assert(sentChat == sentBeforeFilters and joinedChannels == joinedBeforeFilters, "filtering sent chat or joined a channel")
recruitingOption.func()
drainRefresh()
assert(B.publicIntentFilter == "Recruiting" and B.publicPage == 1, "Recruiting dropdown callback changed state incorrectly")
assert(B.publicFilter == "World Boss" and worldButton._sfP6Highlight == true,
  "World Boss selection or highlight was not preserved")

local preservedWorldButton, preservedIntentDrop = worldButton, intentDrop
for _ = 1, 20 do
  assert(B:ShowPublicGroups() ~= false, "Public Groups reuse failed")
  assert(B.publicFilterButtons["World Boss"] == preservedWorldButton and B.publicIntentDrop == preservedIntentDrop,
    "Public Groups controls duplicated during lifecycle reuse")
  assert(B.publicFilter == "World Boss" and worldButton._sfP6Highlight == true,
    "World Boss selection or highlight changed during lifecycle reuse")
  assert(tostring(worldButton:GetText() or ""):find(expectedWorldLabel, 1, true),
    "World Boss count label changed during lifecycle reuse")
  if B.HidePanels then B:HidePanels() end
end
PG.AttachPanel(B.publicPanel)
assert(B.publicIntentDrop == preservedIntentDrop and B.publicFilterButtons["World Boss"] == preservedWorldButton,
  "Public Groups controls were not idempotently repaired")
assert(tostring(worldButton:GetText() or ""):find(expectedWorldLabel, 1, true),
  "World Boss count label was lost during final panel reconciliation")

-- Candidate admission and parser ownership stay bounded, single-pass, and idle
-- after the deferred work is drained.
assert(runtime.Candidate("LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak") == true, "Kazzak tour candidate rejected")
assert(runtime.Candidate("DPS LFG Azuregos") == true, "Azuregos applicant candidate rejected")
assert(runtime.Candidate("the boss is dead now") == false, "ordinary boss text became parse-heavy")
B:SF151_SetDeveloperDiagnostics(true)

local function assertOneParsePerReceivingFrame(frameCount)
  clearRows()
  local before = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
  for index = 1, frameCount do
    local rec = runtime.IngestSource("Perf" .. tostring(frameCount) .. "-" .. tostring(index), "LFM Kazzak", "3. Newcomers", "CHAT_MSG_CHANNEL")
    assert(type(rec) == "table", "performance fixture did not create a parser record")
  end
  drainQueue()
  local after = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
  assert(after - before == frameCount,
    "one TestParse per receiving frame invariant changed at " .. tostring(frameCount))
end

-- One logical frame still owns one authoritative parse as delivery scales from
-- the normal case through a short burst; no duplicate parser path is introduced.
for _, frameCount in ipairs({1, 2, 5, 10}) do
  assertOneParsePerReceivingFrame(frameCount)
end

clearRows()
local beforeParse = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
runtime.ClearRuntimeCaches()
B.publicGroups = {}
B:SF151_InvalidatePublicGroupsData("single-parser-check")
runtime.IngestSource("SinglePass", "LFM Kazzak", "3. Newcomers", "CHAT_MSG_CHANNEL")
local afterParse = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
assert(afterParse - beforeParse == 1, "one logical chat occurrence invoked TestParse more than once")
drainQueue()
local state = assert(runtime.GetParserRuntimeState(), "parser runtime state missing")
assert(state.queueDepth == 0 and state.workerScript == false, "Phase 3 worker did not return to idle")
B:SF151_SetDeveloperDiagnostics(false)

print("Public Groups World Boss and recruiting intent harness: PASS")
