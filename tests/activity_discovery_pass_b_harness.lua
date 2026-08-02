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
  "DPS with aura LFG",
  "58 Necro DPS with aura LF UBRS/LBRS xp runs",
  "lfm rfc | tank have aura",
  "lfm rfc | tank have aura xp",
}
for _, text in ipairs(positive) do
  assert(parse(text).xpAura == true, "positive XP Aura fixture was not detected: " .. text)
end

local negative = {
  "paladin with aura",
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

local liveAuraFixtures = {
  {text="DPS with aura LFG", activity="Random Dungeon Finder", intent="Applicant"},
  {text="58 Necro DPS with aura LF UBRS/LBRS xp runs", activity="Lower Blackrock Spire", intent="Applicant"},
  {text="lfm rfc | tank have aura", activity="Ragefire Chasm", intent="Recruiter"},
  {text="lfm rfc | tank have aura xp", activity="Ragefire Chasm", intent="Recruiter"},
}
for _, fixture in ipairs(liveAuraFixtures) do
  local result = parse(fixture.text)
  assert(result.xpAura == true and result.activity == fixture.activity and result.intent == fixture.intent,
    "live shorthand XP Aura metadata changed: " .. fixture.text)
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

local liveAuraTitles = {
  {text="DPS with aura LFG", author="AuraApplicant", activity="Random Dungeon Finder", title="Random Dungeon Finder - LFG D - XP Aura"},
  {text="58 Necro DPS with aura LF UBRS/LBRS xp runs", author="AuraSpire", activity="Lower Blackrock Spire", title="Lower Blackrock Spire - LFG D - XP Aura"},
  {text="lfm rfc | tank have aura", author="AuraRfcOne", activity="Ragefire Chasm", title="Ragefire Chasm - Need T - XP Aura"},
  {text="lfm rfc | tank have aura xp", author="AuraRfcTwo", activity="Ragefire Chasm", title="Ragefire Chasm - Need T - XP Aura"},
}
for _, fixture in ipairs(liveAuraTitles) do
  assert(runtime.Candidate(fixture.text) == true, "affirmative shorthand XP Aura candidate was rejected: " .. fixture.text)
  local _, display = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", fixture.text, fixture.author)
  assert(type(display) == "string" and display:find("|Hbronzelfgpub:", 1, true)
    and display:find("[" .. fixture.title .. "]", 1, true),
    "affirmative shorthand XP Aura link was not rendered: " .. fixture.text .. " => " .. tostring(display))
  drainQueue()
  local row
  for _, candidate in pairs(B.publicGroups or {}) do
    if candidate.player == fixture.author and candidate.rawMessage == fixture.text then row = candidate end
  end
  assert(row and row.xpAura == true and row.activity == fixture.activity,
    "affirmative shorthand XP Aura row metadata was not canonical: " .. fixture.text)
end
local cappedAuraTitle = assert(runtime.BuildExactLinkTitle({
  xpAura=true, activity=string.rep("Long Specific Activity ", 4), type="Dungeon", intent="Recruiter", roles="DPS"
}), "specific XP Aura title owner missing")
assert(#cappedAuraTitle <= 72 and cappedAuraTitle:sub(-10) == " - XP Aura",
  "specific XP Aura title cap removed its suffix: " .. cappedAuraTitle)

local ownAuraText = "DPS with aura LFG"
local ownAuraAuthor = (UnitName and UnitName("player")) or "AuraSelf"
local _, ownAuraDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_SAY", ownAuraText, ownAuraAuthor)
assert(type(ownAuraDisplay) == "string" and ownAuraDisplay:find("|Hbronzelfgpub:", 1, true)
  and ownAuraDisplay:find("[Random Dungeon Finder - LFG D - XP Aura]", 1, true),
  "self outgoing XP Aura chat did not use the final link path")
drainQueue()

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
local paladinText = "paladin aura need healer"
local negatedText = "LFM 1-60 no XP aura"
local paladinParsed = SignalFireFastChatLinks.TestParse(paladinText)
local negatedParsed = SignalFireFastChatLinks.TestParse(negatedText)
assert(not (paladinParsed and paladinParsed.xpAura == true), "paladin Aura parser metadata became affirmative")
assert(not (negatedParsed and negatedParsed.xpAura == true), "negated XP Aura parser metadata became affirmative")
assert(SignalFireFastChatLinks.DetectXPAura(paladinText) == false, "paladin Aura detector became affirmative")
assert(SignalFireFastChatLinks.DetectXPAura(negatedText) == false, "negated XP Aura detector became affirmative")
local _, paladinDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", paladinText, "AuraPaladin")
local _, negatedDisplay = runtime.Filter(DEFAULT_CHAT_FRAME, "CHAT_MSG_CHANNEL", negatedText, "AuraNegated")
local function hasXPAuraLink(value)
  value = tostring(value or "")
  return value:find("|Hbronzelfgpub:", 1, true) ~= nil and value:find("[XP Aura]", 1, true) ~= nil
end
assert(not hasXPAuraLink(paladinDisplay) and not hasXPAuraLink(negatedDisplay),
  "false-positive or negated Aura received an XP Aura link")
assert(paladinDisplay == paladinText, "class/combat Aura changed from its established raw chat behavior")
drainQueue()
local paladinRow, negatedRow
for _, row in pairs(B.publicGroups or {}) do
  if row.player == "AuraPaladin" and row.rawMessage == paladinText then paladinRow = row end
  if row.player == "AuraNegated" and row.rawMessage == negatedText then negatedRow = row end
end
assert(not (paladinRow and paladinRow.xpAura == true), "paladin Aura canonical row became affirmative")
assert(not (negatedRow and negatedRow.xpAura == true), "negated XP Aura canonical row became affirmative")
if paladinRow then
  assert(#setView("All", "All", "All Difficulties", "AuraPaladin", "XP Aura Only") == 0,
    "paladin Aura row qualified under XP Aura Only")
end
if negatedRow then
  assert(#setView("All", "All", "All Difficulties", "AuraNegated", "XP Aura Only") == 0,
    "negated XP Aura row qualified under XP Aura Only")
end

-- The real Phase 6 controls and Phase 4 scheduler own filter changes.
local showResult = B:ShowPublicGroups()
assert(showResult ~= false, "Public Groups did not open for Pass B")
local PG = assert(SignalFirePublicGroupsView151, "Phase 6 Public Groups owner missing")
local difficultyDrop = assert(B.publicDifficultyDrop, "Difficulty control missing after ShowPublicGroups")
local auraButton = assert(B.publicXPAuraButton, "XP Aura button missing after ShowPublicGroups")
local search = assert(B.publicSearch, "Search control missing after ShowPublicGroups")
local searchLabel = assert(B.publicSearchLabel, "Search label missing after ShowPublicGroups")
assert(B.publicXPAuraDrop == nil and B.publicXPAuraLabel == nil, "dedicated XP Aura dropdown ownership remained")
assert(auraButton:GetParent() == B.publicPanel and auraButton:GetText():find("XP Aura (", 1, true),
  "XP Aura button escaped Public Groups or lost its count label")
assert(search:GetParent() == B.publicPanel and searchLabel:GetParent() == B.publicPanel
  and searchLabel:GetText() == "Search", "Search control escaped Public Groups")
assert(B.publicXPAuraFilter == "All Listings", "XP Aura button did not start unrestricted")
local snapshotCounts = assert(B:GetPublicFilterCounts(), "Public Groups snapshot counts missing")
assert(auraButton:GetText() == "XP Aura (" .. tostring(snapshotCounts.XPAura or 0) .. ")",
  "XP Aura button count did not come from the current snapshot")
local auraClick = assert(auraButton:GetScript("OnClick"), "XP Aura button callback missing")

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
auraClick(auraButton)
assert(B.publicFilter == "Dungeon" and B.publicRoleFilter == "H" and B.publicDifficultyFilter == "Mythic"
  and B.publicSearchText == "bfd mythic healer" and B.publicXPAuraFilter == "XP Aura Only"
  and B.publicPage == 1 and refreshCalls > 0,
  "XP Aura button cleared another filter or failed to reset page")
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
assert(auraButton._sfP6Highlight == true, "XP Aura button did not enter its active visual state")
assert(sentChat == sentBeforeFilter and joinedChannels == joinedBeforeFilter,
  "XP Aura filtering sent chat or joined a channel")
B.RefreshPublicGroups = originalRefresh

B.publicPage = 3
auraClick(auraButton)
assert(B.publicXPAuraFilter == "All Listings" and B.publicPage == 1
  and B.publicFilter == "Dungeon" and B.publicRoleFilter == "H"
  and B.publicDifficultyFilter == "Mythic" and B.publicSearchText == "bfd mythic healer",
  "XP Aura button did not clear only its additive filter")
guard = 0
while refresh.pending == true or (refresh.dirty and refresh.dirty.publicGroups == true) do
  SignalFireHarnessAdvanceTime((tonumber(refresh.debounceSeconds or .15) or .15) + .05)
  local update = assert(refreshFrame:GetScript("OnUpdate"), "debounced Public Groups refresh owner missing")
  update(refreshFrame, .03)
  guard = guard + 1
  assert(guard < 20, "Public Groups debounce did not drain after clearing XP Aura")
end
assert(auraButton._sfP6Highlight == false, "XP Aura button remained visually active after clearing")

-- Existing state migration remains accepted by the additive button owner.
B.publicXPAuraFilter = "All XP Aura"
PG.AttachPanel(B.publicPanel)
assert(B.publicXPAuraFilter == "All Listings", "legacy All XP Aura state did not migrate")
B.publicXPAuraFilter = "XP Aura Only"
PG.AttachPanel(B.publicPanel)
assert(B.publicXPAuraFilter == "XP Aura Only", "XP Aura Only state did not survive button attachment")
B.publicXPAuraFilter = "All Listings"

-- Repair and reuse the same named controls through the final lazy lifecycle.
local originalDifficultyInitializer = difficultyDrop.dropdownInitializer
local originalAuraButtonScript = auraButton:GetScript("OnClick")
B.publicDifficultyDrop, B.publicDifficultyLabel = nil, nil
B.publicXPAuraButton = nil
PG.AttachPanel(B.publicPanel)
assert(B.publicDifficultyDrop == difficultyDrop and B.publicDifficultyLabel ~= nil,
  "Difficulty control was not repaired on surviving panel")
assert(B.publicXPAuraButton == auraButton and auraButton:GetScript("OnClick") == originalAuraButtonScript,
  "XP Aura button was not repaired on surviving panel")
for _ = 1, 20 do
  assert(B:ShowPublicGroups() ~= false, "Public Groups reuse failed")
  assert(B.publicDifficultyDrop == difficultyDrop and B.publicXPAuraButton == auraButton
    and B.publicXPAuraDrop == nil and B.publicXPAuraLabel == nil,
    "Public Groups duplicated controls during reuse")
  assert(difficultyDrop.dropdownInitializer == originalDifficultyInitializer
    and auraButton:GetScript("OnClick") == originalAuraButtonScript, "Public Groups lifecycle hook duplicated")
  if B.HidePanels then B:HidePanels() end
end
local topLeftXY, anchorXY
anchorXY = function(widget, anchor, seen)
  local left, top = topLeftXY(widget, seen)
  local width, height = tonumber(widget:GetWidth() or 0) or 0, tonumber(widget:GetHeight() or 0) or 0
  if anchor == "TOPLEFT" then return left, top end
  if anchor == "TOPRIGHT" then return left + width, top end
  if anchor == "TOP" then return left + width / 2, top end
  if anchor == "BOTTOMLEFT" then return left, top - height end
  if anchor == "BOTTOMRIGHT" then return left + width, top - height end
  if anchor == "BOTTOM" then return left + width / 2, top - height end
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
  if point == "TOP" then left = left - width / 2 end
  if point == "BOTTOMLEFT" then top = top + height end
  if point == "BOTTOMRIGHT" then left = left - width; top = top + height end
  if point == "BOTTOM" then left = left - width / 2; top = top + height end
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
local socialRect = rect(assert(B.publicFilterButtons and B.publicFilterButtons.Social, "Social control missing"), 22)
local auraRect = rect(auraButton, 22)
local searchLabelRect = rect(searchLabel, 14)
local searchRect = rect(search, 22)
local sortRect = rect(assert(B.publicSortButton, "Sort control missing"), 22)
local function disjoint(first, second)
  return first.right <= second.left or second.right <= first.left
    or first.bottom >= second.top or second.bottom >= first.top
end
assert(difficultyLabelRect.left >= roleD.right + 12, "Difficulty overlaps role controls")
assert(difficultyLabelRect.right + 8 <= difficultyRect.left, "Difficulty label overlaps its dropdown")
assert(difficultyLabelRect.left >= 8 and difficultyRect.right <= panelWidth - 8,
  "Difficulty escaped Public Groups panel")
assert(auraRect.left >= socialRect.right + 8 and auraRect.left >= 8 and auraRect.right <= panelWidth - 8,
  "XP Aura button is not an additive top-row control")
assert(searchLabelRect.left >= 8 and searchRect.left >= 8 and searchRect.right <= panelWidth - 8,
  "Search escaped Public Groups panel")
assert(math.abs((searchLabelRect.left + searchLabelRect.right) / 2
  - (searchRect.left + searchRect.right) / 2) <= 1,
  "Search label is not centered over its edit box")
assert(searchLabelRect.bottom > searchRect.top and disjoint(searchLabelRect, sortRect),
  "Search label overlaps its edit box or Sort control")
assert(searchRect.top <= sortRect.bottom - 1 and disjoint(searchRect, sortRect),
  "Search edit box overlaps Sort control")
assert(disjoint(difficultyRect, searchRect), "Difficulty overlaps Search")

B.publicXPAuraFilter = "XP Aura Only"
B:ClearPublicGroups()
assert(B.publicXPAuraFilter == "All Listings", "Clear did not reset XP Aura filter state")

print("activity discovery pass B harness: PASS")
