local addonRoot = assert(arg and arg[1], "addon root is required")
local loader = assert(arg and arg[2], "prepared production loader is required")
dofile(loader)

local B = assert(BronzeLFG, "SignalFire did not load")
BronzeLFG_DB.options.serverProfile = "Ascension"

-- Simulate the normal already-joined internal transport.  CreateListing must
-- send its LIST packet to BLFG and never exercise the unrelated join fallback.
local sentChat, joinedChannels = {}, {}
local previousGetChannelName = GetChannelName
local previousSendChatMessage = SendChatMessage
local previousJoinChannelByName = JoinChannelByName
function GetChannelName(name)
  if tostring(name or "") == "BLFG" then return 9 end
  return previousGetChannelName and previousGetChannelName(name) or 0
end
function SendChatMessage(payload, chatType, language, destination)
  table.insert(sentChat, {payload=tostring(payload or ""), chatType=chatType, language=language, destination=destination})
end
function JoinChannelByName(name) table.insert(joinedChannels, tostring(name or "")) end

local function split(payload)
  local out, start = {}, 1
  while true do
    local at = string.find(payload, "~", start, true)
    if not at then table.insert(out, string.sub(payload, start)); return out end
    table.insert(out, string.sub(payload, start, at - 1)); start = at + 1
  end
end
local function onlyListPacket(label)
  assert(#joinedChannels == 0, label .. " used JoinChannelByName")
  assert(#sentChat == 1, label .. " did not produce exactly one internal LIST packet")
  local packet = sentChat[1]
  assert(packet.chatType == "CHANNEL" and packet.destination == 9, label .. " did not use joined BLFG channel")
  assert(string.sub(packet.payload, 1, 13) == "BLFG312~LIST~", label .. " was not a LIST packet")
  return split(packet.payload)
end

local function contains(list, expected)
  for _, value in ipairs(list or {}) do if value == expected then return true end end
  return false
end
local function parse(text)
  local value = assert(SignalFireFastChatLinks.TestParse(text), "parser returned nil")
  return value
end

-- A/B/C: the production profile and create helpers keep plain Mythic separate
-- from keyed Mythic+ without changing Triumvirate's creation data.
local diffs = assert(BLFG_CreateDifficultyListFor("Dungeon", "Standard Dungeons"))
assert(contains(diffs, "Normal") and contains(diffs, "Heroic") and contains(diffs, "Mythic") and not contains(diffs, "Mythic+"))
assert(not contains(diffs, "Ascended"), "raid-only Ascended leaked into dungeon creation")
assert(BLFG_ActivitySupportsKeyLevel("Standard Dungeons") == false)
assert(BLFG_CreateDifficultyListFor("Mythic+", "Mythic+ Pool")[1] == "Mythic+", "dedicated key flow changed")
BronzeLFG_DB.options.serverProfile = "Triumvirate"
assert(not contains(BLFG_CreateDifficultyListFor("Dungeon", "Classic Dungeon"), "Mythic"), "Triumvirate creation changed")
BronzeLFG_DB.options.serverProfile = "Ascension"

-- Production Create Listing lifecycle: state is loaded through the final
-- Ascension owner, saved, reopened, and submitted through CreateListing.
B:CreateUI()
B:ShowCreate()
local polish = assert(SignalFireAscensionListingPolish, "Ascension listing owner missing")
BronzeLFG_DB.createByProfile = BronzeLFG_DB.createByProfile or {}
BronzeLFG_DB.createByProfile.Ascension = {
  type="Dungeon", activity=polish.ASC_STANDARD, specificDungeon="Blackfathom Deeps", difficulty="Mythic", key="7",
  minItemLevel="", maxMembers="5", voice="None", loot="Group Loot", note="", needTank=true, needHealer=true, needDPS=true,
}
polish.LoadState(B, "Ascension")
assert(BLFG_DropdownText(B.typeDrop) == "Dungeon" and BLFG_DropdownText(B.specificDungeonDrop) == "Blackfathom Deeps" and BLFG_DropdownText(B.diffDrop) == "Mythic", "plain Mythic create state did not load")
assert(not B.keyLabel:IsShown() and not B.keyBox:IsShown() and not B.useKeystoneButton:IsShown(), "plain Mythic key controls remained visible")
assert(B:ListingRecruitmentText(B:SFListingDraft()):find("Mythic Blackfathom Deeps", 1, true), "plain Mythic posting preview missing difficulty")
polish.SaveCurrent(B, "Ascension")
polish.LoadState(B, "Ascension")
assert(BLFG_DropdownText(B.specificDungeonDrop) == "Blackfathom Deeps" and BLFG_DropdownText(B.diffDrop) == "Mythic", "plain Mythic state did not survive reopening")
B:CreateListing()
assert(B.myListing and B.myListing.type == "Dungeon" and B.myListing.activity == "Blackfathom Deeps" and B.myListing.difficulty == "Mythic" and tostring(B.myListing.key or "") == "", "plain Mythic listing serialization")
local plainPacket = onlyListPacket("plain Mythic")
assert(#plainPacket == 26 and plainPacket[7] == "Dungeon" and plainPacket[8] == "Blackfathom Deeps" and plainPacket[9] == "Mythic" and plainPacket[10] == "", "plain Mythic LIST positions")
assert(plainPacket[21] ~= nil and plainPacket[22] ~= nil and plainPacket[23] ~= nil and plainPacket[24] ~= nil and plainPacket[25] ~= nil and plainPacket[26] ~= nil and plainPacket[27] == nil, "LIST packet expanded past p[26]")
local plainListingId = assert(B.myListing and B.myListing.id, "plain Mythic listing id missing")

sentChat = {}
joinedChannels = {}
B:CancelMyListing("harness")
assert(B.myListing == nil, "plain Mythic listing remained active after cancellation")
assert(B.selectedListing == nil, "selected listing remained after cancellation")
assert(#joinedChannels == 0, "CancelMyListing used JoinChannelByName")
assert(#sentChat == 1, "CancelMyListing did not produce exactly one internal REMOVE packet")
local removePacket = sentChat[1]
assert(removePacket.chatType == "CHANNEL" and removePacket.destination == 9, "CancelMyListing did not use joined BLFG channel")
assert(string.sub(removePacket.payload, 1, 15) == "BLFG312~REMOVE~", "cancellation was not a REMOVE packet")
local removeParts = split(removePacket.payload)
assert(removeParts[3] == tostring(plainListingId), "REMOVE packet referenced the wrong listing: " .. tostring(removeParts[3]))

sentChat = {}
joinedChannels = {}
assert(SignalFireHarnessAdvanceTime, "mock clock helper missing")
local beforeTime = time()
SignalFireHarnessAdvanceTime(1)
assert(time() > beforeTime, "mock clock did not advance")
B:ShowCreate()

BronzeLFG_DB.createByProfile.Ascension = {
  type="Mythic+", activity=polish.ASC_MYTHIC, specificDungeon="Blackfathom Deeps", difficulty="Mythic+", key="",
  minItemLevel="", maxMembers="5", voice="None", loot="Group Loot", note="", needTank=true, needHealer=true, needDPS=true,
}
polish.LoadState(B, "Ascension")
assert(B.keyLabel:IsShown() and B.keyBox:IsShown() and B.useKeystoneButton:IsShown(), "Mythic+ key controls were not visible")
assert(B:ValidateCreateListing() == false, "Mythic+ accepted a missing key level")
B.keyBox:SetText("5")
polish.SaveCurrent(B, "Ascension")
local validKey = B:ValidateCreateListing()
assert(validKey == true, "Mythic+ with valid key failed production validation: type=" .. tostring(BLFG_DropdownText(B.typeDrop)) .. ", activity=" .. tostring(BLFG_DropdownText(B.activityDrop)) .. ", specific=" .. tostring(BLFG_DropdownText(B.specificDungeonDrop)) .. ", difficulty=" .. tostring(BLFG_DropdownText(B.diffDrop)) .. ", key=" .. tostring(B.keyBox:GetText()) .. ", active=" .. tostring(B.myListing and B.myListing.id))
B:CreateListing()
assert(B.myListing, "Mythic+ creation did not produce listing")
assert(B.myListing.id ~= plainListingId, "Mythic+ reused plain listing id: " .. tostring(B.myListing.id))
assert(B.myListing.activity == "Blackfathom Deeps", "Mythic+ activity mismatch: " .. tostring(B.myListing.activity))
assert(B.myListing.difficulty == "Mythic+", "Mythic+ difficulty mismatch: " .. tostring(B.myListing.difficulty))
assert(tostring(B.myListing.key or "") == "5", "Mythic+ key mismatch: " .. tostring(B.myListing.key))
local keyPacket = onlyListPacket("Mythic+")
assert(#keyPacket == 26 and keyPacket[8] == "Blackfathom Deeps" and keyPacket[9] == "Mythic+" and keyPacket[10] == "5", "Mythic+ LIST positions")

-- D/E/F: all cases use the live TestParse production API.
for _, fixture in ipairs({
  {"BFD mythic", "Blackfathom Deeps", "Mythic", "Dungeon"},
  {"mythic SM Cath", "Scarlet Monastery - Cathedral", "Mythic", "Dungeon"},
  {"BRD Prison mythic", "Blackrock Depths - Prison", "Mythic", "Dungeon"},
  {"mythic Dire Maul North", "Dire Maul - North", "Mythic", "Dungeon"},
  {"DMN mythic", "Dire Maul - North", "Mythic", "Dungeon"},
  {"LFM BFD M+5", "Blackfathom Deeps", "Mythic+", "Key", "5"},
  {"LFM mythic plus SM Cath", "Scarlet Monastery - Cathedral", "Mythic+", "Key"},
  {"need healer keystone Deadmines +7", "Deadmines", "Mythic+", "Key", "7"},
}) do
  local got = parse(fixture[1])
  assert(got.activity == fixture[2] and got.difficulty == fixture[3] and got.type == fixture[4], fixture[1])
  assert((fixture[5] == nil) or got.keyLevel == fixture[5], fixture[1] .. " key level")
end
assert(parse("LFM mythic Molten Core").type == "Raid", "raid precedence lost")
local guild = parse("<Mythic Friends> mythic raiding guild recruiting members")
assert(guild.kind == "guild", "guild precedence lost")

-- G/H: drain the same deferred Public Groups worker that live chat uses.
BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.publicGroups = true
local runtime = assert(SignalFireChatRuntime151, "Phase 3 chat runtime missing")
runtime.Apply()

-- SF151_GetChatRuntimeStatus is a legacy counter tuple in this production
-- revision; GetParserRuntimeState is the authoritative table-valued runtime
-- status owner for the source/worker lifecycle fields below.
local function chatRuntimeStatus()
  local state = assert(runtime.GetParserRuntimeState, "parser runtime status API missing")()
  local legacyDepth = B:SF151_GetChatRuntimeStatus()
  assert(tonumber(legacyDepth) == tonumber(state.queueDepth), "chat runtime status depth disagreement")
  return state
end
local function chatRuntimeDiagnostic(state)
  return "sourceActive=" .. tostring(state.sourceActive)
    .. " suspended=" .. tostring(state.suspended)
    .. " reason=" .. tostring(state.lastStopReason)
    .. " depth=" .. tostring(state.queueDepth)
    .. " workerActive=" .. tostring(state.workerActive)
    .. " workerScript=" .. tostring(state.workerScript)
end

local initialStatus = chatRuntimeStatus()
assert(initialStatus.sourceActive == true, "Public Groups parser inactive before live fixtures: " .. chatRuntimeDiagnostic(initialStatus))
assert(initialStatus.queueDepth == 0, "Public Groups queue was not idle before live fixtures: " .. chatRuntimeDiagnostic(initialStatus))
assert(initialStatus.workerScript == false, "idle Public Groups worker retained OnUpdate: " .. chatRuntimeDiagnostic(initialStatus))

local function drainPublicQueue()
  local frame = assert(B._sfP3Frame, "chat queue frame missing")
  local runtime = assert(SignalFireChatRuntime151, "chat runtime missing")
  local function status()
    return assert(runtime.GetParserRuntimeState, "parser runtime status API missing")()
  end
  local depth = #(B._sfP3Queue or {})
  if depth == 0 then return end

  local state = status()
  assert(state.sourceActive, "chat parser inactive while queue contains work: " .. chatRuntimeDiagnostic(state))

  local update = (frame.GetScript and frame:GetScript("OnUpdate")) or (frame.scripts and frame.scripts.OnUpdate)
  if type(update) ~= "function" then
    local started = runtime.StartParserWork()
    assert(started == true, "production parser worker failed to start: depth=" .. tostring(#(B._sfP3Queue or {})))
    update = (frame.GetScript and frame:GetScript("OnUpdate")) or (frame.scripts and frame.scripts.OnUpdate)
  end
  assert(type(update) == "function", "chat queue update missing with queued work")

  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    update(frame, .07)
    guard = guard + 1
    assert(guard < 100, "chat queue did not drain")
  end
  local finalState = status()
  assert(finalState.queueDepth == 0, "chat queue remained populated after drain: " .. chatRuntimeDiagnostic(finalState))
end

local function normalizedPlayer(value)
  return string.lower(tostring(value or "")):gsub("%-.*", "")
end

local function assertStablePublicRow(row, label)
  assert(row and row.id and row.key, label .. " missing stable Public Groups identity")
  assert(tostring(row.key) == tostring(row.id), label .. " row.key did not retain row.id: " .. tostring(row.key))
end
local function assertEmptyKeyLevel(row, label)
  assert(tostring(row.keyLevel or "") == "", label .. " unexpectedly retained keystone metadata: " .. tostring(row.keyLevel))
end

B.publicGroups = {}
local function addLive(author, message)
  local returned = B:AddPublicGroup(author, message, "Harness")
  drainPublicQueue()
  for _, row in pairs(B.publicGroups or {}) do
    if normalizedPlayer(row.player or row.author) == normalizedPlayer(author)
      and tostring(row.rawMessage or row.message or "") == message then return row end
  end
  if type(returned) == "table"
    and normalizedPlayer(returned.player or returned.author) == normalizedPlayer(author)
    and tostring(returned.rawMessage or returned.message or "") == message then
      return returned
  end
  local state = chatRuntimeStatus()
  error("live AddPublicGroup did not create row for " .. message
    .. " " .. chatRuntimeDiagnostic(state))
end
local mythic = addLive("MythicBFD", "need healer BFD mythic")
local cath = addLive("MythicCath", "LFM mythic SM Cath need DPS")
local prison = addLive("MythicPrison", "BRD Prison mythic need tank")
local key = addLive("KeyBFD", "LFM BFD M+5 need tank")
local deadmines = addLive("KeyDM", "need healer keystone Deadmines +7")
local dmn = addLive("MythicDMN", "DMN mythic need healer")
assertStablePublicRow(mythic, "plain Mythic BFD live row")
assertEmptyKeyLevel(mythic, "plain Mythic BFD live row")
assert(mythic.type == "Dungeon" and mythic.activity == "Blackfathom Deeps" and mythic.difficulty == "Mythic", "plain Mythic BFD live row metadata")
assertStablePublicRow(cath, "plain Mythic Cathedral live row")
assertEmptyKeyLevel(cath, "plain Mythic Cathedral live row")
assert(cath.type == "Dungeon" and cath.activity == "Scarlet Monastery - Cathedral" and cath.difficulty == "Mythic", "plain Mythic Cathedral live row")
assertStablePublicRow(prison, "plain Mythic Prison live row")
assertEmptyKeyLevel(prison, "plain Mythic Prison live row")
assert(prison.type == "Dungeon" and prison.activity == "Blackrock Depths - Prison" and prison.difficulty == "Mythic", "plain Mythic Prison live row")
assertStablePublicRow(dmn, "plain Mythic DMN live row")
assertEmptyKeyLevel(dmn, "plain Mythic DMN live row")
assert(dmn.type == "Dungeon" and dmn.activity == "Dire Maul - North" and dmn.difficulty == "Mythic", "plain Mythic DMN live row")
assertStablePublicRow(key, "Mythic+ BFD live row")
assert(key.type == "Key" and key.activity == "Blackfathom Deeps" and key.difficulty == "Mythic+" and tostring(key.keyLevel) == "5" and tostring(key.key) ~= "5", "Mythic+ BFD live row")
assertStablePublicRow(deadmines, "Mythic+ Deadmines live row")
assert(deadmines.type == "Key" and deadmines.activity == "Deadmines" and deadmines.difficulty == "Mythic+" and tostring(deadmines.keyLevel) == "7" and tostring(deadmines.key) ~= "7", "Mythic+ Deadmines live row")
B.publicFilter, B.publicRoleFilter, B.publicSearchText, B.publicSortMode = "All", "All", "", "Newest"
B.publicDifficultyFilter = "Mythic"
B:SF151_InvalidatePublicGroupsData("activity-discovery-harness")
local rows = B:GetSortedPublicGroups()
assert(#rows == 4, "Mythic filter did not retain exact plain Mythic rows")
B.publicDifficultyFilter, B.publicFilter, B.publicRoleFilter, B.publicSearchText = "Mythic+", "Key", "T", "blackfathom"
rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == key.id, "combined Mythic+ filters failed")
B.publicDifficultyFilter, B.publicPage = "All Difficulties", 2
rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == key.id, "All Difficulties changed more than the difficulty filter")
B.publicFilter, B.publicRoleFilter, B.publicSearchText = "All", "All", ""
rows = B:GetSortedPublicGroups()
assert(#rows == 6, "All Difficulties did not include both normalized difficulties after clearing other filters")

-- Exercise the real production dropdown callbacks and the production-created
-- controls, including their final Phase 6 selection behavior.
B:ShowPublicGroups()
local difficultyDrop = assert(B.publicDifficultyDrop, "difficulty dropdown missing")
local difficultyLabel = assert(B.publicDifficultyLabel, "difficulty label missing")
local originalInitializer = assert(difficultyDrop.dropdownInitializer, "difficulty dropdown initializer missing")
local options = difficultyDrop:RunDropdownInitializer()
assert(#options == 5, "difficulty dropdown duplicated options")
local byText = {}
for _, info in ipairs(options) do byText[info.text] = info end
for _, value in ipairs({"All Difficulties", "Normal", "Heroic", "Mythic", "Mythic+"}) do assert(byText[value] and type(byText[value].func) == "function", "difficulty dropdown option missing: " .. value) end
local sentBeforeFilters = #sentChat
local refreshes = 0
local originalRefresh = B.RefreshPublicGroups
B.RefreshPublicGroups = function(self, ...)
  refreshes = refreshes + 1
  return originalRefresh and originalRefresh(self, ...)
end
B.publicPage = 3
byText["Mythic"].func()
assert(B.publicDifficultyFilter == "Mythic" and B.publicPage == 1 and BLFG_DropdownText(difficultyDrop) == "Mythic" and refreshes > 0, "Mythic dropdown callback")
B.selectedPublic = key.id
byText["Mythic"].func()
assert(B.selectedPublic == nil, "filtered-out selected Public Group was retained")
byText["All Difficulties"].func()
assert(B.publicDifficultyFilter == "All Difficulties", "All Difficulties dropdown reset")
B.RefreshPublicGroups = originalRefresh
assert(#sentChat == sentBeforeFilters, "Public Groups filtering sent chat")

local function leftAndWidth(widget)
  local _, _, _, x = widget:GetPoint()
  return tonumber(x or 0) or 0, tonumber(widget:GetWidth() or 0) or 0
end
local dps = assert(B.publicRoleFilterButtons and B.publicRoleFilterButtons.D, "DPS role control missing")
local roleX, roleWidth = leftAndWidth(dps)
local labelX = select(4, difficultyLabel:GetPoint())
local dropX, dropWidth = leftAndWidth(difficultyDrop)
assert(labelX > roleX + roleWidth, "difficulty label overlaps role controls")
assert(dropX + dropWidth <= B.publicPanel:GetWidth(), "difficulty dropdown escaped Public Groups panel")
for _ = 1, 20 do
  B:ShowPublicGroups()
  local cycleOptions = difficultyDrop:RunDropdownInitializer()
  assert(B.publicDifficultyLabel == difficultyLabel and B.publicDifficultyDrop == difficultyDrop and difficultyDrop.dropdownInitializer == originalInitializer and #cycleOptions == 5, "difficulty controls duplicated during lifecycle")
  if B.HidePanels then B:HidePanels() end
end
assert(#sentChat == sentBeforeFilters, "Public Groups lifecycle sent chat")

print("activity discovery pass A harness: PASS")
