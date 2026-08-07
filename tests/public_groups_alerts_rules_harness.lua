local addonRoot = assert(arg and arg[1], "addon root is required")
local loader = assert(arg and arg[2], "prepared production loader is required")
dofile(loader)

local B = assert(BronzeLFG, "SignalFire did not load")
local runtime = assert(SignalFireChatRuntime151, "Public Groups parser runtime missing")
local alerts = assert(SignalFirePublicGroupAlerts153, "Pass D alert owner missing")

BronzeLFG_DB.options = BronzeLFG_DB.options or {}
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.publicGroups = true
BronzeLFG_DB.options.inlineChatLinks = true
BronzeLFG_DB.options.chatLinkScope = "all"
B.SignalFireTestSay = true

runtime.Apply()

local initialRuntime =
  assert(
    runtime.GetParserRuntimeState(),
    "initial parser runtime state missing"
  )

assert(
  initialRuntime.sourceActive == true
    and initialRuntime.workerOwnerActive == true
    and initialRuntime.suspended == false
    and initialRuntime.queueDepth == 0
    and initialRuntime.workerScript == false,
  "parser runtime was not active and idle after Apply"
)

assert(
  B._sf153FinalAlertOwner == true,
  "Pass D final alert owner was lost during parser Apply"
)

local chatAlerts, errorAlerts, sounds = {}, {}, {}
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(chatAlerts, tostring(text or "")) end
UIErrorsFrame = {AddMessage=function(_, text) table.insert(errorAlerts, tostring(text or "")) end}
PlaySoundFile = function(path) table.insert(sounds, tostring(path or "")) end

local function clearOutput()
  chatAlerts, errorAlerts, sounds = {}, {}, {}
end

local function clearRows()
  B.publicGroups = {}
  if runtime.ClearRuntimeCaches then runtime.ClearRuntimeCaches() end
  if B.SF151_InvalidatePublicGroupsData then B:SF151_InvalidatePublicGroupsData("pass-d-alert-reset") end
end

local function drainQueue()
  local frame = assert(B._sfP3Frame, "Phase 3 worker frame missing")
  local update = frame:GetScript("OnUpdate")
  if type(update) ~= "function" and runtime.StartParserWork then
    assert(runtime.StartParserWork() == true, "Phase 3 worker did not start")
    update = assert(frame:GetScript("OnUpdate"), "Phase 3 worker update missing")
  end
  local guard = 0
  while #(B._sfP3Queue or {}) > 0 do
    assert(type(update) == "function", "Phase 3 worker script was not installed")
    update(frame, .1)
    guard = guard + 1
    assert(guard < 100, "Phase 3 worker did not drain")
  end
end

local function findRow(author, text)
  for _, row in pairs(B.publicGroups or {}) do
    if tostring(row.player or "") == author and tostring(row.rawMessage or row.message or "") == text then return row end
  end
  return nil
end

local function ingest(author, text)
  local rec = runtime.IngestSource(author, text, "3. Newcomers", "CHAT_MSG_CHANNEL")
  assert(type(rec) == "table", "canonical source rejected: " .. text)
  assert(rec.done ~= true, "source parser record completed before deferred worker: " .. text)
  assert(type(B._sfP3Queue) == "table" and #B._sfP3Queue > 0,
    "source parser record did not enter deferred queue: " .. text)
  local queued = assert(runtime.GetParserRuntimeState(), "queued parser runtime state missing")
  assert(queued.queueDepth > 0,
    "source parser queue depth was not positive: " .. text)
  drainQueue()
  local row = assert(findRow(author, text), "canonical row missing: " .. text)
  assert(row.sf151StableLink == true and row.key == row.id, "alert input was not the canonical row")
  return row
end

local clearedRuntimeVerified = false

local function resetCase()
  clearOutput()
  clearRows()
  if not clearedRuntimeVerified then
    local postClear =
      assert(
        runtime.GetParserRuntimeState(),
        "post-clear parser runtime state missing"
      )

    assert(
      postClear.sourceActive == true
        and postClear.suspended == false
        and postClear.queueDepth == 0
        and postClear.workerScript == false,
      "ClearRuntimeCaches changed active parser ownership"
    )
    clearedRuntimeVerified = true
  end
  alerts:ResetDiagnostics()
  local opts = BronzeLFG_DB.options
  opts.notifyEnabled, opts.publicAlertEnabled, opts.notifySound = true, true, true
  opts.publicAlertCooldown = 20
  opts.publicAlertIntentFilter = "All Intents"
  opts.publicAlertRoleFilter = "All Roles"
  opts.publicAlertXPAuraFilter = "All Listings"
  opts.publicAlertWorldBoss, opts.publicAlertEvent = true, false
  opts.publicAlertWorldBossMode = "Any World Boss"
  opts.publicAlertRaid, opts.publicAlertDungeon, opts.publicAlertKey = false, false, false
  opts.publicAlertRaidFilter, opts.publicAlertDungeonFilter, opts.publicAlertKeyFilter = "Any Raid", "Any Dungeon", "Any Key"
  opts.publicAlertDungeonDifficulty = "All Difficulties"
  opts.publicAlertCustomEnabled, opts.publicAlertCustomText = false, ""
end

local function diagnostics()
  return alerts:GetDiagnostics()
end

-- A/B: World Boss canonical type and Recruiting intent, while the UI remains hidden.
resetCase()
local zeroDiag = diagnostics()
assert(zeroDiag.evaluations == 0
  and zeroDiag.fired == 0
  and zeroDiag.deduped == 0
  and zeroDiag.intentRejected == 0
  and zeroDiag.customMatched == 0
  and zeroDiag.soundsPlayed == 0,
  "ResetDiagnostics did not return numeric zero counters")
local world = ingest("AzuregosRecruiter", "LF DPS Azuregos")
assert(world.type == "World Boss" and world.activity == "Azuregos" and world.intent == "Recruiter", "Azuregos canonical metadata changed")
assert(#chatAlerts == 1 and #errorAlerts == 1 and #sounds == 1, "World Boss recruiter did not fire exactly once")
assert(sounds[1] == "Sound\\Interface\\RaidWarning.wav", "Pass D did not use the safe RaidWarning sound")
local noPanelYet = B.sfe153AlertsRulesPanel == nil and B.publicPanel == nil
assert(noPanelYet, "hidden-panel alert test opened Public Groups UI")

BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
clearOutput()
ingest("AzuregosApplicant", "DPS LFG Azuregos")
assert(#chatAlerts == 0 and #errorAlerts == 0 and #sounds == 0, "Applicant row alerted under Recruiting")
ingest("KazzakRecruiter", "LFM Kazzak")
assert(#chatAlerts == 1 and string.find(chatAlerts[1], "Lord Kazzak", 1, true), "Kazzak was not canonicalized in alert output")
clearOutput()
ingest("KazzakTour", "LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak")
assert(#chatAlerts == 1 and string.find(chatAlerts[1], "Lord Kazzak", 1, true), "live Kazzak fixture did not alert")

-- C: Selected World Bosses and profile-owned selection state.
resetCase()
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
BronzeLFG_DB.options.publicAlertWorldBossMode = "Selected World Bosses"
alerts:SetWorldBossSelection("Azuregos", true, "Ascension")
alerts:SetWorldBossSelection("Lord Kazzak", false, "Ascension")
ingest("SelectedAzuregos", "LF DPS Azuregos")
ingest("SelectedKazzak", "LFM Kazzak")
assert(#chatAlerts == 1 and string.find(chatAlerts[1], "Azuregos", 1, true), "selected World Boss mode did not honor Azuregos-only state")
resetCase()
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
BronzeLFG_DB.options.publicAlertWorldBossMode = "Selected World Bosses"
alerts:SetWorldBossSelection("Azuregos", false, "Ascension")
alerts:SetWorldBossSelection("Lord Kazzak", true, "Ascension")
ingest("InverseAzuregos", "LF DPS Azuregos")
ingest("InverseKazzak", "LFM Kazzak")
assert(#chatAlerts == 1 and string.find(chatAlerts[1], "Lord Kazzak", 1, true), "selected World Boss inverse state failed")
BronzeLFG_DB.options.serverProfile = "Triumvirate"
local triSelections = alerts:GetWorldBossSelections("Triumvirate")
assert(triSelections.Azuregos == nil and triSelections["Lord Kazzak"] == nil, "Ascension boss selections leaked into Triumvirate")
local triBosses = alerts:GetWorldBosses("Triumvirate")
if triBosses[1] then
  alerts:SetWorldBossSelection(triBosses[1], true, "Triumvirate")
  assert(alerts:GetWorldBossSelections("Ascension")[triBosses[1]] == nil, "Triumvirate selection leaked into Ascension")
end
BronzeLFG_DB.options.serverProfile = "Ascension"

-- D: Recruiting intent solves raid LFG spam and remains independent of view filters.
resetCase()
BronzeLFG_DB.options.publicAlertWorldBoss = false
BronzeLFG_DB.options.publicAlertRaid = true
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
ingest("RaidApplicant1", "LFG ZG")
ingest("RaidApplicant2", "DPS LFG ZG")
ingest("RaidRecruiter", "LFM ZG need DPS")
local raidDiag = diagnostics()
assert(raidDiag.fired == 1 and #chatAlerts == 1, "Raid Recruiting rule did not reject LFG spam")

-- E: Plain Mythic is Dungeon, RDF has no Mythic difficulty, and Mythic+ is Key.
resetCase()
BronzeLFG_DB.options.publicAlertWorldBoss = false
BronzeLFG_DB.options.publicAlertDungeon = true
BronzeLFG_DB.options.publicAlertDungeonDifficulty = "Mythic"
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
ingest("MythicRecruiter", "LFM BFD Mythic need healer")
ingest("MythicApplicant", "DPS LFG BFD Mythic")
ingest("RdfRecruiter", "LFM RDF need DPS")
ingest("RdfApplicant", "DPS LFG RDF")
ingest("MythicPlusRecruiter", "LFM BFD M+5 need healer")
assert(diagnostics().fired == 1 and #chatAlerts == 1, "Dungeon Mythic rule leaked RDF, Applicant, or Mythic+")
BronzeLFG_DB.options.publicAlertDungeon = false
BronzeLFG_DB.options.publicAlertKey = true
ingest("KeyRecruiter", "LFM BFD M+5 need healer")
assert(diagnostics().fired == 2 and #chatAlerts == 2 and string.find(chatAlerts[2], "Key", 1, true), "Key rule did not own Mythic+")

-- F/G: Role and XP Aura refinements are canonical AND restrictions.
resetCase()
BronzeLFG_DB.options.publicAlertWorldBoss = false
BronzeLFG_DB.options.publicAlertDungeon = true
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
BronzeLFG_DB.options.publicAlertRoleFilter = "Healer"
ingest("HealerNeeded", "LFM BFD need healer")
ingest("DpsOnly", "LFM BFD need DPS")
assert(diagnostics().fired == 1, "Healer role refinement did not reject DPS-only row")
resetCase()
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
BronzeLFG_DB.options.publicAlertXPAuraFilter = "XP Aura Only"
ingest("AuraWorld", "LFM Azuregos need DPS XP aura")
ingest("PlainWorld", "LFM Azuregos need DPS")
assert(diagnostics().fired == 1 and diagnostics().xpAuraRejected >= 1, "XP Aura refinement changed")

-- H/I: Custom OR/AND syntax and one fire for multiple matching rules.
resetCase()
BronzeLFG_DB.options.publicAlertWorldBoss = false
BronzeLFG_DB.options.publicAlertCustomEnabled = true
BronzeLFG_DB.options.publicAlertCustomText = "azuregos, kazzak, bfd mythic"
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
ingest("CustomAzuregos", "LF DPS Azuregos")
local customAzuregosDiag = diagnostics()
assert(customAzuregosDiag.customMatched == 1 and customAzuregosDiag.fired == 1,
  "custom Azuregos OR clause did not fire exactly once")
ingest("CustomKazzak", "LFM Kazzak")
local customKazzakDiag = diagnostics()
assert(customKazzakDiag.customMatched == 2 and customKazzakDiag.fired == 2,
  "custom Kazzak OR clause did not fire exactly once")
local customBfdMythic = ingest("CustomBfdMythic", "LFM BFD Mythic need healer")
assert(customBfdMythic.type == "Dungeon"
  and customBfdMythic.activity == "Blackfathom Deeps"
  and customBfdMythic.difficulty == "Mythic"
  and customBfdMythic.intent == "Recruiter"
  and (string.find(string.lower(tostring(customBfdMythic.message or "")), "bfd", 1, true)
    or string.find(string.lower(tostring(customBfdMythic.rawMessage or "")), "bfd", 1, true)),
  "custom BFD Mythic row did not retain canonical and original searchable metadata")
local customBfdMythicDiag = diagnostics()
assert(customBfdMythicDiag.customMatched == 3 and customBfdMythicDiag.fired == 3,
  "custom BFD Mythic AND clause did not fire exactly once")
ingest("CustomBfdNormal", "LFM BFD need healer")
local customBfdNormalDiag = diagnostics()
assert(customBfdNormalDiag.customMatched == 3 and customBfdNormalDiag.fired == 3,
  "custom BFD normal row incorrectly matched the Mythic AND clause")
assert(customBfdNormalDiag.intentRejected == 0,
  "custom BFD normal unexpectedly changed intent rejection count")
local customChatCount = #chatAlerts
ingest("CustomApplicant", "DPS LFG Azuregos")
local customApplicantDiag = diagnostics()
assert(customApplicantDiag.customMatched == 3 and customApplicantDiag.fired == 3
  and customApplicantDiag.intentRejected == 1
  and #chatAlerts == customChatCount,
  "custom applicant bypassed Recruiting intent refinement")
assert(customApplicantDiag.customMatched == 3 and customApplicantDiag.fired == 3, "custom comma OR or whitespace AND semantics changed")
resetCase()
BronzeLFG_DB.options.publicAlertWorldBoss = true
BronzeLFG_DB.options.publicAlertCustomEnabled = true
BronzeLFG_DB.options.publicAlertCustomText = "azuregos"
ingest("DoubleMatch", "LF DPS Azuregos")
local doubleDiag = diagnostics()
assert(doubleDiag.matched == 1 and doubleDiag.customMatched == 1 and doubleDiag.fired == 1
  and #chatAlerts == 1 and #errorAlerts == 1 and #sounds == 1, "built-in and custom rules produced duplicate alerts")

-- J: semantic cooldown suppresses equivalent rebroadcasts, then permits expiry and activity change.
resetCase()
BronzeLFG_DB.options.publicAlertIntentFilter = "Recruiting"
ingest("RepeatPlayer", "LFM Azuregos")
ingest("RepeatPlayer", "LFM Azuregos need DPS")
assert(diagnostics().deduped == 1 and diagnostics().fired == 1, "semantic rebroadcast dedupe failed")
SignalFireHarnessAdvanceTime(21)
ingest("RepeatPlayer", "LFM Azuregos need healer")
ingest("RepeatPlayer", "LFM Kazzak")
assert(diagnostics().fired == 3, "cooldown expiry or meaningful activity change did not re-alert")
assert(diagnostics().cacheSize <= 192, "alert dedupe cache exceeded its bound")

-- K: master and sound controls remain independent.
resetCase()
BronzeLFG_DB.options.notifyEnabled = false
BronzeLFG_DB.options.publicAlertEnabled = false
ingest("DisabledAlerts", "LFM Azuregos")
assert(#chatAlerts == 0 and #errorAlerts == 0 and #sounds == 0 and diagnostics().disabled == 1, "disabled alerts produced output")
BronzeLFG_DB.options.notifyEnabled = true
BronzeLFG_DB.options.publicAlertEnabled = true
BronzeLFG_DB.options.notifySound = false
ingest("SilentAlerts", "LFM Azuregos")
assert(#chatAlerts == 1 and #errorAlerts == 1 and #sounds == 0, "sound toggle suppressed visual alert")

-- L: the new configuration is a mutually exclusive Options page with one entry point.
BronzeLFG_DB.options.publicAlertWorldBossMode = "Any World Boss"
assert(B:ShowOptions() ~= false, "Options panel did not open")
local eventEntry = assert(B.sfe141EventAlertButton, "Alerts & Rules entry point was not created")
assert(eventEntry:IsShown(), "Alerts & Rules entry point was not visible")
assert(eventEntry:GetText() == "Alerts & Rules", "existing Event Alerts entry point was not repurposed")
assert(not (B.sf153ConfigureAlertRulesButton and B.sf153ConfigureAlertRulesButton:IsShown()),
  "separate Configure Alert Rules entry point remained visible")
local legacyControls = {
  B.optNotify, B.optNotifySound, B.optNotifyHCBB, B.eventFilterDD,
  B.optNotifyRaid, B.raidFilterDD, B.optNotifyKey, B.keyFilterDD,
  B.optNotifyDungeon, B.dungeonFilterDD, B.dungeonFilterDD5612,
  B.dungeonAlertDropdown, B.dungeonAlertDropdown5613,
  B.dungeonAlertDropdown5614, B.dungeonAlertDropdown5615,
}
for _, control in ipairs(legacyControls) do
  assert(not control or not control:IsShown(), "legacy alert control remained visible on Options")
end
local listingAlertEntries = eventEntry:IsShown() and 1 or 0
if B.sf153ConfigureAlertRulesButton and B.sf153ConfigureAlertRulesButton:IsShown() then listingAlertEntries = listingAlertEntries + 1 end
assert(listingAlertEntries == 1, "only one listing-alert navigation entry was visible")

local openRules = assert(eventEntry:GetScript("OnClick"), "Alerts & Rules callback missing")
openRules(eventEntry)
local rulesPanel = assert(B.sfe153AlertsRulesPanel, "Pass D rules panel was not built")
assert(rulesPanel:IsShown(), "Pass D rules panel was not shown")
assert(rulesPanel:GetParent() == B.content, "Pass D rules page was not owned by the main content area")
assert(not B.optionsPanel:IsShown(), "normal Options content remained visible under rules")
for _, panel in ipairs({B.sfmmPanel, B.sfcpPanel, B.sfn138FavoriteOptionsPanel, B.sfamPolishPanel, B.sfe141EventOptionsPanel}) do
  assert(not panel or not panel:IsShown(), "Options subpanel remained visible under rules")
end
local rulesControls = {
  {"master", rulesPanel.sf153MasterCheck},
  {"sound", rulesPanel.sf153SoundCheck},
  {"cooldown", rulesPanel.sf153CooldownDrop},
  {"intent", rulesPanel.sf153IntentDrop},
  {"role", rulesPanel.sf153RoleDrop},
  {"xp-aura", rulesPanel.sf153AuraDrop},
  {"world-boss", rulesPanel.sf153WorldBossCheck},
  {"world-mode", rulesPanel.sf153WorldModeDrop},
  {"raid", rulesPanel.sf153RaidCheck},
  {"raid-filter", rulesPanel.sf153RaidDrop},
  {"dungeon", rulesPanel.sf153DungeonCheck},
  {"dungeon-filter", rulesPanel.sf153DungeonDrop},
  {"difficulty", rulesPanel.sf153DifficultyDrop},
  {"key", rulesPanel.sf153KeyCheck},
  {"key-filter", rulesPanel.sf153KeyDrop},
  {"event", rulesPanel.sf153EventCheck},
  {"custom", rulesPanel.sf153CustomCheck},
  {"custom-edit", rulesPanel.sf153CustomEdit},
}
local function assertRulesControlsVisible(stage)
  for _, item in ipairs(rulesControls) do
    local name, control = item[1], item[2]
    assert(control, "Pass D rules control missing: " .. name)
    assert(control:IsShown(), "Pass D rules control not visible: " .. name .. " (" .. stage .. ")")
  end
end
assertRulesControlsVisible("first open")
local rulesControlRefs = {}
for _, item in ipairs(rulesControls) do rulesControlRefs[item[1]] = item[2] end
assert(type(rulesPanel.sf153BossChecks) == "table", "World Boss control registry was not a table")
local bossRegistry = rulesPanel.sf153BossChecks
local bossRegistryCount = 0
local bossControls = {}
for key, control in pairs(bossRegistry) do
  bossRegistryCount = bossRegistryCount + 1
  assert(not control:IsShown(), "Any World Boss mode left boss controls visible")
end
assert(bossRegistryCount > 0, "World Boss control registry was empty")
rulesPanel.sf153WorldModeDrop:sf153SetValues({"Any World Boss", "Selected World Bosses"}, "Selected World Bosses")
local selectedVisibleCount = 0
local kaldrosChoices = 0
local kaldrosLabel = nil
for key, control in pairs(bossRegistry) do
  if control:IsShown() then
    bossControls[key] = control
    selectedVisibleCount = selectedVisibleCount + 1
  end
  local rawName = string.lower(tostring(control.sf153BossName or ""))
  if rawName == "kaldros" or rawName == "kaldros depthbreaker" then
    kaldrosChoices = kaldrosChoices + 1
    kaldrosLabel = control.sf153Label and control.sf153Label:GetText() or ""
  end
end
assert(selectedVisibleCount > 0, "Selected World Boss mode did not show active-profile boss controls")
assert(kaldrosChoices == 1 and kaldrosLabel == "Kaldros Depthbreaker", "Kaldros duplicate user-facing choice remained")
rulesPanel.sf153WorldModeDrop:sf153SetValues({"Any World Boss", "Selected World Bosses"}, "Any World Boss")
for _, control in pairs(bossRegistry) do
  assert(not control:IsShown(), "Any World Boss mode did not hide selected boss controls")
end
assertRulesControlsVisible("after World Boss mode changes")

local repeatedBossRegistryCount = 0
for key, control in pairs(bossRegistry) do repeatedBossRegistryCount = repeatedBossRegistryCount + 1 end
assert(repeatedBossRegistryCount == bossRegistryCount, "World Boss registry count changed on same-profile refresh")
openRules(eventEntry)
assert(B.sfe153AlertsRulesPanel == rulesPanel, "repeated rule-panel opens duplicated the panel")
assert(rulesPanel.sf153BossChecks == bossRegistry, "World Boss registry table was replaced on refresh")
assertRulesControlsVisible("reopen")
for _, item in ipairs(rulesControls) do
  assert(item[2] == rulesControlRefs[item[1]], "Rules control was recreated on reopen: " .. item[1])
end
for key, control in pairs(bossControls) do
  assert(rulesPanel.sf153BossChecks[key] == control, "World Boss control was recreated on same-profile refresh")
end

local optionNavs = {
  {"Modules", B.sfmmOpenButton},
  {"Chat & Parsing", B.sfcpOpenButton},
  {"Favorite Alerts", B.sfn138FavoriteAlertButton},
  {"Polish Settings", B.sfamPolishButton},
}
for _, item in ipairs(optionNavs) do
  local navName, nav = item[1], item[2]
  if nav then
    local click = assert(nav:GetScript("OnClick"), "Options navigation callback missing: " .. navName)
    openRules(eventEntry)
    assert(rulesPanel:IsShown(), "Rules page did not open before " .. navName)
    click(nav)
    assert(not rulesPanel:IsShown(), "Rules page remained visible after " .. navName .. " opened")
    assert(B.optionsPanel:IsShown(), "Options content remained hidden after " .. navName .. " opened")
    openRules(eventEntry)
    assert(rulesPanel == B.sfe153AlertsRulesPanel, "Rules panel changed after " .. navName .. " navigation")
    assert(rulesPanel.sf153IntentDrop:IsShown(), "Intent dropdown remained hidden after " .. navName .. " navigation")
    assertRulesControlsVisible("after " .. navName .. " navigation reopen")
  end
end

if B.sfmmBodyButton then
  openRules(eventEntry)
  assert(rulesPanel:IsShown(), "Rules page did not open before Manage Modules")
  local bodyClick = assert(B.sfmmBodyButton:GetScript("OnClick"), "Manage Modules callback missing")
  bodyClick(B.sfmmBodyButton)
  assert(not rulesPanel:IsShown(), "Rules page remained visible after Manage Modules opened")
  openRules(eventEntry)
  assertRulesControlsVisible("after Manage Modules navigation reopen")
end

openRules(eventEntry)
assertRulesControlsVisible("pre-Back reopen")
local back = assert(rulesPanel.sf153BackButton, "Rules page Back button was not stored")
back:GetScript("OnClick")(back)
assert(not rulesPanel:IsShown() and B.optionsPanel:IsShown(), "Back did not return to the normal Options page")
openRules(eventEntry)
assertRulesControlsVisible("Back reopen")
assert(B.sfe153AlertsRulesPanel == rulesPanel and rulesPanel.sf153BossChecks == bossRegistry,
  "Rules page or World Boss registry was not reused after navigation")

openRules(eventEntry)
assert(rulesPanel:IsShown(), "Rules page did not open before direct ShowOptions regression")
B:ShowOptions()
assert(not rulesPanel:IsShown(), "Rules page remained visible after direct ShowOptions")
assert(B.optionsPanel:IsShown(), "normal Options page did not reopen after direct ShowOptions")
openRules(eventEntry)
assertRulesControlsVisible("after direct ShowOptions reopen")

B:HidePanels()
assert(not rulesPanel:IsShown(), "rules panel did not close with Options lifecycle")

-- M/N/O: canonical-only evaluation, bounded idle architecture, and no chat side effects.
local beforeParser = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
local directRow = {sf151StableLink=true, sf151CanonicalKey="direct", player="Direct", type="World Boss", activity="Azuregos", intent="Recruiter", roles="DPS", message="keyword"}
BronzeLFG_DB.options.notifyEnabled = true
BronzeLFG_DB.options.publicAlertEnabled = true
BronzeLFG_DB.options.notifySound = false
alerts:EvaluateCanonical(directRow)
local afterParser = tonumber(B._sfP3Stats and B._sfP3Stats.TestParseCalls or 0) or 0
assert(beforeParser == afterParser, "alert evaluation invoked the authoritative parser a second time")
assert(B._sfP3Frame:GetScript("OnUpdate") == nil or #(B._sfP3Queue or {}) == 0,
  "alert engine installed a permanent parser worker")

print("Public Groups Alerts & Rules Pass D harness: PASS")
