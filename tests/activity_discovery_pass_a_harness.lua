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

-- G/H: add real chat messages through the production AddPublicGroup path, then
-- inspect the rows that the live parser/reconciliation pipeline creates.
B.publicGroups = {}
local function addLive(author, message)
  B:AddPublicGroup(author, message, "Harness")
  local frame = B._sfChatParseFrame
  if frame and frame.scripts and frame.scripts.OnUpdate then
    for _ = 1, 4 do frame.scripts.OnUpdate(frame, .1) end
  end
  for _, row in pairs(B.publicGroups or {}) do
    if tostring(row.rawMessage or row.message or "") == message then return row end
  end
  error("live AddPublicGroup did not create row for " .. message)
end
local mythic = addLive("MythicAuthor", "need healer BFD mythic")
local key = addLive("KeyAuthor", "LFM BFD M+5 need tank")
assert(mythic.type == "Dungeon" and mythic.activity == "Blackfathom Deeps" and mythic.difficulty == "Mythic" and tostring(mythic.key or "") == "", "plain Mythic live row")
assert(key.type == "Key" and key.activity == "Blackfathom Deeps" and key.difficulty == "Mythic+" and tostring(key.keyLevel) == "5", "Mythic+ live row")
B.publicFilter, B.publicRoleFilter, B.publicSearchText, B.publicSortMode = "All", "All", "", "Newest"
B.publicDifficultyFilter = "Mythic"
B:SF151_InvalidatePublicGroupsData("activity-discovery-harness")
local rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == mythic.id, "Mythic filter included Mythic+")
B.publicDifficultyFilter, B.publicFilter, B.publicRoleFilter, B.publicSearchText = "Mythic+", "Key", "T", "blackfathom"
rows = B:GetSortedPublicGroups()
assert(#rows == 1 and rows[1].id == key.id, "combined Mythic+ filters failed")
B.publicDifficultyFilter, B.publicPage = "All Difficulties", 2
rows = B:GetSortedPublicGroups()
assert(#rows == 2, "All Difficulties did not include both normalized difficulties")

print("activity discovery pass A harness: PASS")
