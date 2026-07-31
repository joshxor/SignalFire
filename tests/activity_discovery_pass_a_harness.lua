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
local diffs = assert(BLFG_CreateDifficultyListFor("Dungeon", "Classic Dungeon"))
assert(contains(diffs, "Normal") and contains(diffs, "Heroic") and contains(diffs, "Mythic") and contains(diffs, "Mythic+"))
assert(not contains(diffs, "Ascended"), "raid-only Ascended leaked into dungeon creation")
assert(BLFG_ActivitySupportsKeyLevel("Classic Dungeon") == true)
BronzeLFG_DB.options.serverProfile = "Triumvirate"
assert(not contains(BLFG_CreateDifficultyListFor("Dungeon", "Classic Dungeon"), "Mythic"), "Triumvirate creation changed")
BronzeLFG_DB.options.serverProfile = "Ascension"

-- D/E/F: all cases use the live TestParse production API.
for _, fixture in ipairs({
  {"BFD mythic", "Blackfathom Deeps", "Mythic", "Dungeon"},
  {"mythic SM Cath", "Scarlet Monastery - Cathedral", "Mythic", "Dungeon"},
  {"BRD Prison mythic", "Blackrock Depths - Prison", "Mythic", "Dungeon"},
  {"mythic Dire Maul North", "Dire Maul North", "Mythic", "Dungeon"},
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

-- G/H: exact normalized difficulty combines with the production Public Groups view.
B.publicGroups = {
  mythic={id="mythic", player="A", message="BFD mythic", activity="Blackfathom Deeps", type="Dungeon", difficulty="Mythic", roles="Healer", seen=time(), created=time()},
  key={id="key", player="B", message="BFD M+5", activity="Blackfathom Deeps", type="Key", difficulty="Mythic+", keyLevel="5", roles="Tank", seen=time(), created=time()},
}
B.publicFilter, B.publicRoleFilter, B.publicSearchText, B.publicSortMode = "All", "All", "", "Newest"
B.publicDifficultyFilter = "Mythic"
B:SF151_InvalidatePublicGroupsData("activity-discovery-harness")
local rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == "mythic", "Mythic filter included Mythic+")
B.publicDifficultyFilter, B.publicFilter, B.publicRoleFilter, B.publicSearchText = "Mythic+", "Key", "T", "blackfathom"
rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == "key", "combined Mythic+ filters failed")
B.publicDifficultyFilter, B.publicPage = "All Difficulties", 2
rows = B:GetSortedPublicGroups()
assert(#rows == 2, "All Difficulties did not include both normalized difficulties")

print("activity discovery pass A harness: PASS")
