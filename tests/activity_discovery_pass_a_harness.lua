local addonRoot = assert(arg and arg[1], "addon root is required")
local loader = assert(arg and arg[2], "prepared production loader is required")
dofile(loader)

local B = assert(BronzeLFG, "SignalFire did not load")
BronzeLFG_DB.options.serverProfile = "Ascension"

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

BronzeLFG_DB.createByProfile.Ascension = {
  type="Mythic+", activity=polish.ASC_MYTHIC, specificDungeon="Blackfathom Deeps", difficulty="Mythic+", key="",
  minItemLevel="", maxMembers="5", voice="None", loot="Group Loot", note="", needTank=true, needHealer=true, needDPS=true,
}
polish.LoadState(B, "Ascension")
assert(B.keyLabel:IsShown() and B.keyBox:IsShown() and B.useKeystoneButton:IsShown(), "Mythic+ key controls were not visible")
assert(B:ValidateCreateListing() == false, "Mythic+ accepted a missing key level")
B.keyBox:SetText("5")
polish.SaveCurrent(B, "Ascension")
B:CreateListing()
assert(B.myListing and B.myListing.activity == "Blackfathom Deeps" and B.myListing.difficulty == "Mythic+" and tostring(B.myListing.key) == "5", "Mythic+ listing lifecycle")

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
local function drainPublicQueue()
  local frame = assert(B._sfP3Frame, "chat queue frame missing")
  local update = (frame.GetScript and frame:GetScript("OnUpdate")) or (frame.scripts and frame.scripts.OnUpdate)
  assert(type(update) == "function", "chat queue update missing")
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    update(frame, .07)
    guard = guard + 1
    assert(guard < 100, "chat queue did not drain")
  end
end

local function normalizedPlayer(value)
  return string.lower(tostring(value or "")):gsub("%-.*", "")
end

B.publicGroups = {}
local function addLive(author, message)
  B:AddPublicGroup(author, message, "Harness")
  drainPublicQueue()
  for _, row in pairs(B.publicGroups or {}) do
    if normalizedPlayer(row.player or row.author) == normalizedPlayer(author)
      and tostring(row.rawMessage or row.message or "") == message then return row end
  end
  error("live AddPublicGroup did not create row for " .. message)
end
local mythic = addLive("MythicBFD", "need healer BFD mythic")
local cath = addLive("MythicCath", "LFM mythic SM Cath need DPS")
local prison = addLive("MythicPrison", "BRD Prison mythic need tank")
local key = addLive("KeyBFD", "LFM BFD M+5 need tank")
local deadmines = addLive("KeyDM", "need healer keystone Deadmines +7")
local dmn = addLive("MythicDMN", "DMN mythic need healer")
assert(mythic.type == "Dungeon" and mythic.activity == "Blackfathom Deeps" and mythic.difficulty == "Mythic" and tostring(mythic.key or "") == "" and tostring(mythic.keyLevel or "") == "", "plain Mythic BFD live row")
assert(cath.type == "Dungeon" and cath.activity == "Scarlet Monastery - Cathedral" and cath.difficulty == "Mythic", "plain Mythic Cathedral live row")
assert(prison.type == "Dungeon" and prison.activity == "Blackrock Depths - Prison" and prison.difficulty == "Mythic", "plain Mythic Prison live row")
assert(dmn.type == "Dungeon" and dmn.activity == "Dire Maul - North" and dmn.difficulty == "Mythic", "plain Mythic DMN live row")
assert(key.type == "Key" and key.activity == "Blackfathom Deeps" and key.difficulty == "Mythic+" and tostring(key.keyLevel) == "5" and tostring(key.key) == "5", "Mythic+ BFD live row")
assert(deadmines.type == "Key" and deadmines.activity == "Deadmines" and deadmines.difficulty == "Mythic+" and tostring(deadmines.keyLevel) == "7" and tostring(deadmines.key) == "7", "Mythic+ Deadmines live row")
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
assert(#rows == 6, "All Difficulties did not include both normalized difficulties")

print("activity discovery pass A harness: PASS")
