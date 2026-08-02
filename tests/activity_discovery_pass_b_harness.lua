local addonRoot = assert(arg and arg[1], "addon root is required")
local loader = assert(arg and arg[2], "prepared production loader is required")
dofile(loader)

local B = assert(BronzeLFG, "SignalFire did not load")
BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
B.SignalFireTestSay = true

local sentChat, joinedChannels = 0, 0
SendChatMessage = function() sentChat = sentChat + 1 end
JoinChannelByName = function() joinedChannels = joinedChannels + 1 end

local function count(value)
  local total = 0
  for _ in pairs(value or {}) do total = total + 1 end
  return total
end

local function parse(text)
  return assert(SignalFireFastChatLinks.TestParse(text), "parser returned nil: " .. text)
end

-- Parser metadata is produced by the live parser/discovery path.  The
-- negative cases may be rejected entirely; neither outcome is affirmative.
local positive = {
  "LFM 1-60 XP aura spam need healer",
  "LF2 DPS aura of experience prestige run",
  "RDF spam experience aura need tank",
  "1-60 exp aura need DPS",
  "leveling group XP aura",
}
for _, text in ipairs(positive) do
  assert(parse(text).xpAura == true, "positive XP Aura fixture was not detected: " .. text)
end

local negative = {
  "paladin aura need healer",
  "devotion aura build",
  "aura mastery healer",
  "need tank resistance aura helpful",
  "LFM 1-60 no XP aura",
  "leveling without XP aura",
  "1-60 need healer",
  "prestige dungeon spam",
}
for _, text in ipairs(negative) do
  local result = SignalFireFastChatLinks.TestParse(text)
  assert(not (result and result.xpAura == true), "false-positive XP Aura fixture: " .. text)
end

-- Preserve Pass A parser distinctions and canonical activity spelling.
assert(parse("LFM BFD Mythic need healer").activity == "Blackfathom Deeps", "BFD canonical activity changed")
assert(parse("LFM SM Cath Mythic need healer").activity == "Scarlet Monastery - Cathedral", "SM Cath canonical activity changed")
assert(parse("LFM BRD Prison Mythic need healer").activity == "Blackrock Depths - Prison", "BRD Prison canonical activity changed")
assert(parse("LFM DMN Mythic need healer").activity == "Dire Maul - North", "DMN canonical activity changed")
assert(parse("LFM mythic Molten Core").type == "Raid", "raid precedence changed")
assert(parse("LFM BFD M+5 need healer").type == "Key", "Mythic+ type changed")

local runtime = assert(SignalFireChatRuntime151, "Public Groups parser runtime missing")
runtime.Apply()
BronzeLFG.publicGroups = {}
BronzeLFG:SF151_InvalidatePublicGroupsData("activity-discovery-pass-b-reset")

local function drainQueue()
  local frame = assert(B._sfP3Frame, "chat queue frame missing")
  local update = frame:GetScript("OnUpdate")
  if type(update) ~= "function" then
    assert(runtime.StartParserWork and runtime.StartParserWork() == true, "chat parser worker did not start")
    update = assert(frame:GetScript("OnUpdate"), "chat queue update missing")
  end
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    update(frame, .07)
    guard = guard + 1
    assert(guard < 100, "chat queue did not drain")
  end
end

local function ingest(text, author)
  assert(runtime.IngestSource(author, text, "3. Newcomers", "CHAT_MSG_CHANNEL") ~= false,
    "source owner rejected fixture: " .. text)
  drainQueue()
  for _, row in pairs(B.publicGroups or {}) do
    if row.player == author and row.rawMessage == text then return row end
  end
  error("production canonical row missing: " .. text)
end

local auraRow = ingest("LFM BFD Mythic+5 XP aura need healer", "AuraOne")
local ordinaryRow = ingest("LFM BFD Mythic need healer", "PlainOne")
local cathRow = ingest("LFM SM Cath Mythic need healer", "CathOne")
local prisonRow = ingest("LFM BRD Prison Mythic need tank", "PrisonOne")
local dmnRow = ingest("LFM DMN Mythic need dps", "DmnOne")
local deadminesRow = ingest("LFM Deadmines keystone +7 need tank", "DeadminesOne")

assert(auraRow.xpAura == true and ordinaryRow.xpAura == false, "XP Aura row metadata did not reach canonical rows")
assert(auraRow.type == "Key" and auraRow.activity == "Blackfathom Deeps" and auraRow.difficulty == "Mythic+",
  "Mythic+ canonical row changed")
assert(tostring(auraRow.keyLevel) == "5" and tostring(auraRow.key) == tostring(auraRow.id) and tostring(auraRow.key) ~= "5",
  "Mythic+ row identity was overloaded with keystone metadata")
assert(deadminesRow.type == "Key" and deadminesRow.activity == "Deadmines"
  and deadminesRow.difficulty == "Mythic+"
  and tostring(deadminesRow.keyLevel) == "7" and tostring(deadminesRow.key) ~= "7",
  "Deadmines keystone metadata changed")
assert(cathRow.activity == "Scarlet Monastery - Cathedral" and prisonRow.activity == "Blackrock Depths - Prison"
  and dmnRow.activity == "Dire Maul - North", "Pass A canonical row coverage changed")

local function setView(filter, role, difficulty, search, aura)
  B.publicFilter = filter or "All"
  B.publicRoleFilter = role or "All"
  B.publicDifficultyFilter = difficulty or "All Difficulties"
  B.publicSearchText = search or ""
  B.publicXPAuraFilter = aura or "All Listings"
  return B:GetSortedPublicGroups()
end

assert(#setView() == 6 and B.publicXPAuraFilter == "All Listings",
  "All Listings did not retain ordinary and XP Aura rows")
local legacyRows = setView("All", "All", "All Difficulties", "", "All XP Aura")
assert(#legacyRows == 6 and B.publicXPAuraFilter == "All Listings",
  "legacy All XP Aura state did not migrate to All Listings")
local auraOnly = setView("All", "All", "All Difficulties", "", "XP Aura Only")
assert(#auraOnly == 1 and auraOnly[1].id == auraRow.id and auraOnly[1].xpAura == true,
  "XP Aura Only did not isolate affirmative rows")

local combined = setView("Key", "H", "Mythic+", "bfd mythic healer", "XP Aura Only")
assert(#combined == 1 and combined[1].id == auraRow.id, "combined XP Aura filters were not intersected")
assert(#setView("Dungeon", "H", "Mythic", "bfd mythic healer", "All Listings") == 1,
  "Type/Role/Difficulty/Search intersection changed")

assert(#setView("All", "All", "All Difficulties", "blackfathom", "All Listings") == 2,
  "canonical activity search failed")
local mythicPlusSearch = setView("All", "All", "All Difficulties", "MYTHIC+", "All Listings")
local mythicPlusIds = {}
for _, row in ipairs(mythicPlusSearch) do
  mythicPlusIds[row.id] = true
end
assert(#mythicPlusSearch == 2 and mythicPlusIds[auraRow.id] and mythicPlusIds[deadminesRow.id],
  "case-insensitive Mythic+ search failed")
assert(#setView("All", "All", "All Difficulties", "+5", "All Listings") == 1,
  "numeric key search failed")
assert(#setView("All", "All", "All Difficulties", "xp aura", "All Listings") == 1,
  "XP Aura search metadata failed")
assert(#setView("All", "All", "All Difficulties", "AuraOne", "All Listings") == 1,
  "player search failed")
assert(#setView("All", "H", "All Difficulties", "", "All Listings") == 3,
  "role metadata search/filter failed")
assert(#setView("All", "All", "All Difficulties", "bfd mythic healer", "All Listings") == 2,
  "multi-token search did not intersect terms")
assert(#setView("All", "All", "All Difficulties", "", "All Listings") == count(B.publicGroups),
  "blank search restricted Public Groups")

-- The authoritative runtime filter owns inline links when the user enables
-- them.  Generic affirmative XP Aura rows receive the useful [XP Aura] title.
local auraLinkText = "LF2 DPS aura of experience prestige run"
assert(runtime.Candidate(auraLinkText) == true, "generic XP Aura candidate was rejected by final gate")
local _, linkedDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", auraLinkText, "AuraLinker")
assert(type(linkedDisplay) == "string" and linkedDisplay:find("|Hbronzelfgpub:", 1, true)
  and linkedDisplay:find("[XP Aura]", 1, true), "generic XP Aura link was not rendered")
drainQueue()
local auraLinkRow
for _, row in pairs(B.publicGroups or {}) do
  if row.player == "AuraLinker" and row.rawMessage == auraLinkText then auraLinkRow = row end
end
assert(auraLinkRow and auraLinkRow.xpAura == true, "generic XP Aura link row lost affirmative metadata")
assert(#setView("All", "All", "All Difficulties", "AuraLinker", "XP Aura Only") == 1,
  "generic XP Aura link row did not qualify for XP Aura Only")

BronzeLFG_DB.options.inlineChatLinks = false
runtime.Apply()
local _, disabledDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", auraLinkText, "AuraDisabled")
assert(disabledDisplay == auraLinkText, "chat links were forced while disabled")
local disabledRow = ingest(auraLinkText, "AuraDisabled")
assert(disabledRow.xpAura == true
  and #setView("All", "All", "All Difficulties", "AuraDisabled", "XP Aura Only") == 1,
  "XP Aura discovery stopped when chat links were disabled")

BronzeLFG_DB.options.inlineChatLinks = true
runtime.Apply()
local _, paladinDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", "paladin aura need healer", "AuraPaladin")
local _, negatedDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", "LFM 1-60 no XP aura", "AuraNegated")
assert(paladinDisplay == "paladin aura need healer" and negatedDisplay == "LFM 1-60 no XP aura",
  "false-positive or negated Aura chat link was rendered")

-- The real Phase 6 controls and Phase 4 scheduler own filter changes.
local showResult = B:ShowPublicGroups()
assert(showResult ~= false, "Public Groups did not open for Pass B")
local PG = assert(SignalFirePublicGroupsView151, "Phase 6 Public Groups owner missing")
local difficultyDrop = assert(B.publicDifficultyDrop, "Difficulty control missing after ShowPublicGroups")
local auraDrop = assert(B.publicXPAuraDrop, "XP Aura control missing after ShowPublicGroups")
local auraLabel = assert(B.publicXPAuraLabel, "XP Aura label missing after ShowPublicGroups")
local search = assert(B.publicSearch, "Search control missing after ShowPublicGroups")
local searchLabel = assert(B.publicSearchLabel, "Search label missing after ShowPublicGroups")
assert(auraDrop:GetParent() == B.publicPanel and auraLabel:GetParent() == B.publicPanel, "XP Aura control escaped Public Groups")
assert(search:GetParent() == B.publicPanel and searchLabel:GetParent() == B.publicPanel
  and searchLabel:GetText() == "Search", "Search control escaped Public Groups")
local auraOptions = auraDrop:RunDropdownInitializer()
assert(#auraOptions == 2, "XP Aura dropdown duplicated options")
local auraByText = {}
for _, info in ipairs(auraOptions) do auraByText[info.text] = info end
assert(auraByText["All Listings"] and auraByText["XP Aura Only"] and not auraByText["All XP Aura"],
  "XP Aura dropdown choices changed")

local refreshCalls = 0
local originalRefresh = B.RefreshPublicGroups
B.RefreshPublicGroups = function(self, ...)
  refreshCalls = refreshCalls + 1
  return originalRefresh and originalRefresh(self, ...)
end
B.publicFilter, B.publicRoleFilter, B.publicDifficultyFilter = "Dungeon", "H", "Mythic"
B.publicSearchText, B.publicXPAuraFilter, B.publicPage = "bfd mythic healer", "All Listings", 4
B.selectedPublic = ordinaryRow.id
local sentBeforeFilter, joinedBeforeFilter = sentChat, joinedChannels
auraByText["XP Aura Only"].func()
assert(B.publicFilter == "Dungeon" and B.publicRoleFilter == "H" and B.publicDifficultyFilter == "Mythic"
  and B.publicSearchText == "bfd mythic healer" and B.publicPage == 1 and refreshCalls > 0,
  "XP Aura callback cleared another filter or failed to reset page")
assert(B.selectedPublic == ordinaryRow.id, "selection was cleared synchronously before debounce")
local refresh = assert(SignalFireRefresh151, "Public Groups refresh owner missing")
local refreshFrame = assert(refresh.frame, "Public Groups refresh frame missing")
local guard = 0
while refresh.pending == true or (refresh.dirty and refresh.dirty.publicGroups == true) do
  SignalFireHarnessAdvanceTime((tonumber(refresh.debounceSeconds or .15) or .15) + .05)
  local update = assert(refreshFrame:GetScript("OnUpdate"), "debounced Public Groups refresh owner missing")
  update(refreshFrame, .03)
  guard = guard + 1
  assert(guard < 20, "Public Groups debounce did not drain")
end
assert(B.selectedPublic == nil, "filtered-out selected row did not clear after debounced render")
assert(sentChat == sentBeforeFilter and joinedChannels == joinedBeforeFilter,
  "XP Aura filtering sent chat or joined a channel")
B.RefreshPublicGroups = originalRefresh

-- Repair and reuse the same named controls through the final lazy lifecycle.
local originalDifficultyInitializer = difficultyDrop.dropdownInitializer
local originalAuraInitializer = auraDrop.dropdownInitializer
B.publicDifficultyDrop, B.publicDifficultyLabel = nil, nil
B.publicXPAuraDrop, B.publicXPAuraLabel = nil, nil
PG.AttachPanel(B.publicPanel)
assert(B.publicDifficultyDrop == difficultyDrop and B.publicDifficultyLabel ~= nil,
  "Difficulty control was not repaired on surviving panel")
assert(B.publicXPAuraDrop == auraDrop and B.publicXPAuraLabel ~= nil,
  "XP Aura control was not repaired on surviving panel")
for _ = 1, 20 do
  assert(B:ShowPublicGroups() ~= false, "Public Groups reuse failed")
  assert(B.publicDifficultyDrop == difficultyDrop and B.publicXPAuraDrop == auraDrop,
    "Public Groups duplicated controls during reuse")
  assert(difficultyDrop.dropdownInitializer == originalDifficultyInitializer
    and auraDrop.dropdownInitializer == originalAuraInitializer, "dropdown lifecycle hook duplicated")
  assert(#difficultyDrop:RunDropdownInitializer() == 5 and #auraDrop:RunDropdownInitializer() == 2,
    "dropdown options duplicated during reuse")
  if B.HidePanels then B:HidePanels() end
end
local topLeftXY, anchorXY
anchorXY = function(widget, anchor, seen)
  local left, top = topLeftXY(widget, seen)
  local width, height = tonumber(widget:GetWidth() or 0) or 0, tonumber(widget:GetHeight() or 0) or 0
  if anchor == "TOPLEFT" then return left, top end
  if anchor == "TOPRIGHT" then return left + width, top end
  if anchor == "BOTTOMLEFT" then return left, top - height end
  if anchor == "BOTTOMRIGHT" then return left + width, top - height end
  return left + width / 2, top - height / 2
end

topLeftXY = function(widget, seen)
  if widget == B.publicPanel then return 0, 0 end
  seen = seen or {}
  if seen[widget] then return 0, 0 end
  seen[widget] = true
  local point, relative, relativePoint, x, y = widget:GetPoint()
  if not relative or relative == widget then return 0, 0 end
  local baseX, baseY = anchorXY(relative, relativePoint or "TOPLEFT", seen)
  local width, height = tonumber(widget:GetWidth() or 0) or 0, tonumber(widget:GetHeight() or 0) or 0
  local left, top = baseX + (tonumber(x or 0) or 0), baseY + (tonumber(y or 0) or 0)
  if point == "TOPRIGHT" then left = left - width end
  if point == "BOTTOMLEFT" then top = top + height end
  if point == "BOTTOMRIGHT" then left = left - width; top = top + height end
  if point == "CENTER" then left = left - width / 2; top = top + height / 2 end
  return left, top
end

local function rect(widget, visualHeight)
  local left, top = topLeftXY(widget)
  local width = tonumber(widget:GetWidth() or 0) or 0
  local height = tonumber(visualHeight or widget:GetHeight() or 0) or 0
  return {left=left, right=left + width, top=top, bottom=top - height}
end

local panelWidth = B.publicPanel:GetWidth()
local roleD = rect(assert(B.publicRoleFilterButtons and B.publicRoleFilterButtons.D, "DPS role control missing"), 22)
local difficultyLabelRect = rect(B.publicDifficultyLabel, 14)
local difficultyRect = rect(difficultyDrop, 32)
local auraLabelRect = rect(auraLabel, 14)
local auraRect = rect(auraDrop, 32)
local searchLabelRect = rect(searchLabel, 14)
local searchRect = rect(search, 22)
local sortRect = rect(assert(B.publicSortButton, "Sort control missing"), 22)
assert(difficultyLabelRect.left >= roleD.right + 12, "Difficulty overlaps role controls")
assert(difficultyLabelRect.right + 8 <= difficultyRect.left, "Difficulty label overlaps its dropdown")
assert(difficultyLabelRect.left >= 8 and difficultyRect.right <= panelWidth - 8,
  "Difficulty escaped Public Groups panel")
assert(difficultyRect.right + 16 <= auraLabelRect.left, "Difficulty overlaps XP Aura label")
assert(auraLabelRect.right + 8 <= auraRect.left, "XP Aura label overlaps its dropdown")
assert(auraRect.left >= 8 and auraRect.right <= panelWidth - 8, "XP Aura escaped Public Groups panel")
assert(searchLabelRect.right + 8 <= searchRect.left, "Search label overlaps its edit box")
assert(searchLabelRect.left >= 8 and searchRect.left >= 8 and searchRect.right + 12 <= sortRect.left
  and searchRect.right <= panelWidth - 8,
  "Search overlaps Sort or escaped Public Groups panel")
assert(searchRect.bottom >= auraRect.top + 4, "Search row overlaps XP Aura controls")

print("activity discovery pass B harness: PASS")
