const fs = require("fs");

const runtime = fs.readFileSync("SignalFire/SignalFireRuntime.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const bronze = fs.readFileSync("SignalFire/BronzeLFG.lua", "utf8");
const core = fs.readFileSync("SignalFire/SignalFireCore.lua", "utf8");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const harness = fs.readFileSync("tests/public_groups_alerts_rules_harness.lua", "utf8");
const workflow = fs.readFileSync(".github/workflows/release.yml", "utf8");
const toc = fs.readFileSync("SignalFire/SignalFire.toc", "utf8");

const need = (source, value, label) => {
  if (!source.includes(value)) throw new Error(`Pass D source verification failed: ${label}`);
};
const needPattern = (source, pattern, label) => {
  if (!pattern.test(source)) throw new Error(`Pass D source verification failed: ${label}`);
};
const forbid = (source, value, label) => {
  if (source.includes(value)) throw new Error(`Pass D source verification failed: ${label}`);
};

const ownerStart = runtime.indexOf("-- Public Groups Alerts & Rules - Pass D.");
const ownerEnd = runtime.indexOf("-- Server profiles", ownerStart);
if (ownerStart < 0 || ownerEnd < 0) throw new Error("Pass D source verification failed: Runtime owner boundary");
const owner = runtime.slice(ownerStart, ownerEnd);

need(owner, "SignalFirePublicGroupAlerts153", "single named Runtime alert owner");
need(owner, "sf151StableLink", "canonical-row gate");
for (const field of ["row.type", "row.activity", "row.activities", "row.message", "row.rawMessage", "row.intent", "row.roles", "row.tags", "row.channel", "row.difficulty", "row.keyLevel", "row.xpAura"]) {
  need(owner, field, `canonical ${field} consumption`);
}
const corpusStart = owner.indexOf("local function sf153_corpus");
const corpusEnd = owner.indexOf("local function sf153_custom_matches", corpusStart);
if (corpusStart < 0 || corpusEnd < 0) throw new Error("Pass D source verification failed: custom corpus boundary");
const corpus = owner.slice(corpusStart, corpusEnd);
needPattern(corpus, /type\s*\(\s*row\.activities\s*\)\s*==\s*["']table["']/, "multi-activity corpus handling");
needPattern(corpus, /table\.concat\s*\(\s*values\s*,\s*["']\s["']\s*\)/, "dense multi-activity corpus handling");
for (const field of ["player", "type", "activity", "message", "rawMessage", "intent", "roles", "tags", "channel", "difficulty", "keyLevel"]) {
  needPattern(corpus, new RegExp(`tostring\\(\\s*row\\.${field}\\s+or\\s+""\\s*\\)`), `string-safe corpus field ${field}`);
}
needPattern(corpus, /tostring\(\s*value\s+or\s+""\s*\)/, "string-safe multi-activity corpus values");
needPattern(corpus, /row\.xpAura\s*==\s*true\s+and\s+"XP Aura"\s+or\s+""/, "string-safe XP Aura corpus field");
need(owner, 'typeName == "World Boss"', "first-class World Boss rule");
need(owner, 'typeName == "Raid"', "canonical Raid rule");
need(owner, 'typeName == "Dungeon"', "canonical Dungeon rule");
need(owner, 'typeName == "Key"', "canonical Key rule");
need(owner, 'typeName == "Event"', "canonical Event rule");
need(owner, 'row.intent or ""', "canonical intent corpus field");
need(owner, 'row.difficulty or ""', "canonical difficulty corpus field");
need(owner, 'publicAlertWorldBossesByProfile', "profile-aware World Boss selections");
need(owner, 'Selected World Bosses', "selected World Boss mode");
need(owner, 'publicAlertCooldown', "timestamp cooldown option");
need(owner, 'maxCacheEntries = 192', "bounded semantic dedupe cache");
need(owner, 'function A:ResetDedupe()', "profile transition dedupe reset");
need(owner, 'function A:GetDiagnostics()', "bounded diagnostics API");
need(owner, 'function A:ResetDiagnostics()', "diagnostics reset API");
const diagnosticsStart = owner.indexOf("function A:GetDiagnostics()");
const diagnosticsEnd = owner.indexOf("function A:ResetDiagnostics()", diagnosticsStart);
if (diagnosticsStart < 0 || diagnosticsEnd < 0) throw new Error("Pass D source verification failed: diagnostics boundary");
const diagnostics = owner.slice(diagnosticsStart, diagnosticsEnd);
for (const field of ["evaluations", "matched", "fired", "deduped", "disabled", "intentRejected", "roleRejected", "xpAuraRejected", "typeRejected", "activityRejected", "difficultyRejected", "customMatched", "soundsPlayed"]) {
  needPattern(diagnostics, new RegExp(`\\b${field}\\s*=\\s*0\\b`), `stable diagnostic default ${field}`);
}
needPattern(diagnostics, /for\s+key\s*,\s*value\s+in\s+pairs\(self\.stats\s+or\s+\{\}\)/, "diagnostic stats overlay");
needPattern(diagnostics, /out\[key\]\s*=\s*tonumber\(value\s+or\s+0\)\s+or\s+0/, "numeric diagnostic stats overlay");
need(owner, 'A.EvaluateCanonical = A.Evaluate', "canonical evaluation entry point");
need(owner, 'B.NotifyForPublicGroup = function', "final alert owner installation");
need(owner, 'Sound\\\\Interface\\\\RaidWarning.wav', "WoW 3.3.5 sound fallback");
for (const forbidden of ["SignalFireFastChatLinks", "TestParse", "isPublicKeystoneText", "SFProfileMatchActivity", "World Boss raw"]) {
  forbid(owner, forbidden, `raw parser/classifier dependency ${forbidden}`);
}
forbid(owner, 'SetScript("OnUpdate"', "permanent alert OnUpdate");
forbid(owner, "C_Timer", "repeating alert timer");
forbid(owner, "ChatFrame_AddMessageEventFilter", "duplicate ChatFrame parsing");
forbid(owner, "SendChatMessage", "alert chat send side effect");
if (/for\s+[^\n]*\s+in\s+pairs\(self\.cache/.test(owner)) {
  throw new Error("Pass D source verification failed: full cache scan in alert hot path");
}

const uiStart = ui.indexOf("-- Public Groups Alerts & Rules - Pass D UI owner.");
if (uiStart < 0) throw new Error("Pass D source verification failed: UI owner marker");
const passDUI = ui.slice(uiStart);
need(passDUI, "sfe153AlertsRulesPanel", "lazy Alerts & Rules subpanel");
need(passDUI, "sfe141EventAlertButton", "single existing Options alert entry point");
need(passDUI, 'entry:SetText("Alerts & Rules")', "repurposed Event Alerts entry point");
need(passDUI, 'entry:SetScript("OnClick", function() sf153_show_rules() end)', "Alerts & Rules navigation callback");
need(passDUI, "sf153_hide_legacy_controls", "legacy alert controls suppressed on Options");
need(passDUI, "hiddenLabels", "legacy alert labels suppressed on Options");
for (const forbidden of ["Configure Alert Rules", 'B.sf153ConfigureAlertRulesButton =']) {
  forbid(passDUI, forbidden, "separate Configure Alert Rules entry point");
}
need(passDUI, "publicAlertIntentFilter", "independent intent rule state");
need(passDUI, "publicAlertRoleFilter", "independent role rule state");
need(passDUI, "publicAlertXPAuraFilter", "independent XP Aura rule state");
need(passDUI, "publicAlertWorldBossMode", "World Boss mode control");
need(passDUI, "sf153_refresh_bosses", "profile-aware dynamic World Boss controls");
need(passDUI, "publicAlertDungeonDifficulty", "Dungeon difficulty control");
need(passDUI, "publicAlertCustomText", "custom quick keyword text");
need(passDUI, "SignalFireUILifecycle151", "standard dropdown lifecycle registration");
need(passDUI, "sf153_boss_display_name", "bounded World Boss display grouping");
need(passDUI, 'return "Kaldros Depthbreaker"', "Kaldros duplicate display grouping");
need(passDUI, "showSelected", "World Boss mode-aware checkbox visibility");
need(passDUI, "sf153_activate_rules_controls", "single Rules-page control activation owner");
forbid(passDUI, "publicFilter =", "Public Groups visible Type filter ownership reused by alerts");
forbid(passDUI, "publicIntentFilter =", "Public Groups visible Intent filter ownership reused by alerts");
forbid(passDUI, "sf153_wire_options_navigation", "second Pass D per-button navigation wrapper");
const sfuiSubpanelsStart = ui.indexOf("local function sfui_subpanels()");
const sfuiSubpanelsEnd = ui.indexOf("local function sfui_hide_subpanels", sfuiSubpanelsStart);
const sfuiHeaderStart = ui.indexOf("local function sfui_wire_header_button");
const sfuiHeaderEnd = ui.indexOf("local function sfui_layout_options_header", sfuiHeaderStart);
if (sfuiSubpanelsStart < 0 || sfuiSubpanelsEnd < 0 || sfuiHeaderStart < 0 || sfuiHeaderEnd < 0) {
  throw new Error("Pass D source verification failed: established Options lifecycle boundary");
}
const sfuiSubpanels = ui.slice(sfuiSubpanelsStart, sfuiSubpanelsEnd);
const sfuiHeader = ui.slice(sfuiHeaderStart, sfuiHeaderEnd);
const sfuiStyleStart = ui.indexOf("local function sfui_style_subpanel");
const sfuiStyleEnd = ui.indexOf("local function sfui_wire_header_button", sfuiStyleStart);
if (sfuiStyleStart < 0 || sfuiStyleEnd < 0) {
  throw new Error("Pass D source verification failed: shared subpanel styling boundary");
}
const sfuiStyle = ui.slice(sfuiStyleStart, sfuiStyleEnd);
need(sfuiSubpanels, "BLFG.sfe153AlertsRulesPanel", "central Options subpanel registry includes Rules");
need(sfuiHeader, "sfui_hide_subpanels(nil)", "central Options navigation hides Rules");
need(sfuiHeader, "if BLFG.optionsPanel then BLFG.optionsPanel:Show() end", "central Options navigation restores the Options host");
need(sfuiStyle, "local footer = panel.sfui1434Footer", "shared footer ownership reads the custom field");
needPattern(sfuiStyle, /local\s+footerType\s*=\s*type\(\s*footer\s*\)/, "shared footer type validation");
needPattern(sfuiStyle, /footerType\s*~=\s*["']table["']\s+and\s+footerType\s*~=\s*["']userdata["']\s+then\s+footer\s*=\s*nil/, "shared footer rejects invalid custom values");
need(sfuiStyle, 'panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")', "shared footer recreates missing or invalid ownership");
needPattern(sfuiStyle, /if\s+footer\s+and\s+footer\.SetText\s+then\s+footer:SetText\(/, "shared footer hydrates the validated owner");
need(sfuiHeader, "button.sfui1434ClickOwner", "central Options navigation tracks exact callback ownership");
need(sfuiHeader, "current == button.sfui1434ClickOwner", "central Options navigation verifies current callback ownership");
need(sfuiHeader, "button.sfui1434DownstreamClick", "central Options navigation records its downstream callback");
need(sfuiHeader, 'button:SetScript("OnClick", owner)', "central Options navigation installs its exact callback owner");
forbid(sfuiHeader, "button.sfui1434Wired then return", "historical callback flag is not the ownership guard");
need(ui, "function BLFG:SFUI1434_WireHeaderButton(button)", "central Options callback repair entry point");
const buildStart = passDUI.indexOf("local function sf153_build_rules");
const activateStart = passDUI.indexOf("local function sf153_activate_rules_controls");
const showStart = passDUI.indexOf("local function sf153_show_rules");
const attachStart = passDUI.indexOf("local function sf153_attach_options", showStart);
if (buildStart < 0 || activateStart < 0 || showStart < 0 || attachStart < 0) throw new Error("Pass D source verification failed: mutually exclusive UI lifecycle boundary");
const buildRules = passDUI.slice(buildStart, showStart);
const activateRules = passDUI.slice(activateStart, buildStart);
const showRules = passDUI.slice(showStart, attachStart);
need(buildRules, "local host = B.content", "Rules page content owner");
need(buildRules, 'CreateFrame("Frame", "SignalFireAlertsRules153", host)', "Rules page is a content sibling");
need(buildRules, "panel:SetAllPoints(host)", "Rules page content geometry");
for (const field of ["sf153MasterCheck", "sf153SoundCheck", "sf153CooldownDrop", "sf153IntentDrop", "sf153RoleDrop", "sf153AuraDrop", "sf153WorldBossCheck", "sf153WorldModeDrop", "sf153RaidCheck", "sf153RaidDrop", "sf153DungeonCheck", "sf153DungeonDrop", "sf153DifficultyDrop", "sf153KeyCheck", "sf153KeyDrop", "sf153EventCheck", "sf153CustomCheck", "sf153CustomEdit"]) {
  need(activateRules, `panel.${field}`, `Rules control activation ${field}`);
}
need(activateRules, "control:Show()", "Rules control activation show contract");
for (const forbidden of [
  'CreateFrame("Frame", "SignalFireAlertsRules153", B.optionsPanel)',
  "panel:SetAllPoints(B.optionsPanel)",
  "B.optionsPanel:Show(); panel:Show()",
]) {
  forbid(passDUI, forbidden, "overlay-based Rules page architecture");
}
need(showRules, "if B.HidePanels then B:HidePanels() end", "Rules page closes existing Options panels");
need(showRules, "sf153_hide_rule_panels(panel)", "Rules page mutually exclusive subpanel lifecycle");
need(showRules, "if B.optionsPanel then B.optionsPanel:Hide() end", "normal Options page hidden under Rules");
need(showRules, "sf153_activate_rules_controls(panel)", "Rules page restores registered controls after HidePanels");
need(showRules, "sf153_refresh_bosses()", "Rules page reapplies conditional World Boss visibility");
const hideTransitionIndex = showRules.indexOf("if B.HidePanels then B:HidePanels() end");
const activateCallIndex = showRules.indexOf("sf153_activate_rules_controls(panel)");
const refreshCallIndex = showRules.indexOf("sf153_refresh_bosses()");
if (hideTransitionIndex < 0 || activateCallIndex < 0 || refreshCallIndex < 0
  || hideTransitionIndex > activateCallIndex || activateCallIndex > refreshCallIndex) {
  throw new Error("Pass D source verification failed: Rules controls restored before final lifecycle transition");
}
forbid(showRules, "B.optionsPanel:Show()", "Rules page leaves normal Options content visible");
const attachRules = passDUI.slice(attachStart, passDUI.indexOf("local oldBuildOptions", attachStart));
need(attachRules, "B:SFUI1434_WireHeaderButton(entry)", "Rules entry returns to the central callback owner after replacement");
const bossesStart = passDUI.indexOf("local function sf153_refresh_bosses");
const bossesEnd = passDUI.indexOf("local function sf153_build_rules", bossesStart);
if (bossesStart < 0 || bossesEnd < 0) throw new Error("Pass D source verification failed: World Boss registry boundary");
const bosses = passDUI.slice(bossesStart, bossesEnd);
needPattern(bosses, /type\s*\(\s*panel\.sf153BossChecks\s*\)\s*~=\s*["']table["']/, "World Boss registry type safety");
needPattern(bosses, /local\s+registry\s*=\s*panel\.sf153BossChecks/, "World Boss registry reuse owner");
needPattern(bosses, /for\s+_,\s*control\s+in\s+pairs\s*\(\s*registry\s*\)/, "World Boss controls hidden from stable registry");
needPattern(bosses, /local\s+check\s*=\s*registry\s*\[\s*key\s*\]/, "World Boss control registry lookup");
needPattern(bosses, /check\.sf153BossName\s*=\s*name/, "World Boss control metadata refresh");
if (bosses.indexOf("registry[key] = nil") >= 0 || bosses.indexOf("panel.sf153BossChecks[key] = nil") >= 0) {
  throw new Error("Pass D source verification failed: World Boss refresh deletes registry entries");
}
const hideIndex = bosses.indexOf("control:Hide()");
const showIndex = bosses.indexOf("check:Show()");
if (hideIndex < 0 || showIndex < 0 || hideIndex > showIndex) {
  throw new Error("Pass D source verification failed: World Boss controls are not hidden before refresh");
}
const lookupIndex = bosses.indexOf("local check = registry[key]");
const createIndex = bosses.indexOf('CreateFrame("CheckButton"');
if (lookupIndex < 0 || createIndex < 0 || lookupIndex > createIndex) {
  throw new Error("Pass D source verification failed: World Boss controls are not reused before creation");
}

need(harness, "World Boss recruiter did not fire exactly once", "World Boss visual/sound regression");
need(harness, "Applicant row alerted under Recruiting", "Recruiting intent regression");
need(harness, "Ascension boss selections leaked into Triumvirate", "profile isolation regression");
need(harness, "Raid Recruiting rule did not reject LFG spam", "Raid LFG spam regression");
need(harness, "Dungeon Mythic rule leaked RDF", "Mythic versus RDF regression");
need(harness, "Key rule did not own Mythic+", "Key ownership regression");
need(harness, "Healer role refinement", "role refinement regression");
need(harness, "XP Aura refinement", "XP Aura refinement regression");
need(harness, "custom comma OR or whitespace AND semantics", "custom quick rule regression");
need(harness, "duplicate alerts", "multiple-rule one-fire regression");
need(harness, "semantic rebroadcast dedupe failed", "semantic cooldown regression");
need(harness, "normal Options content remained visible under rules", "mutually exclusive Options UI regression");
need(harness, "legacy alert control remained visible on Options", "legacy alert controls regression");
need(harness, "Selected World Boss mode did not show active-profile boss controls", "selected World Boss UI regression");
need(harness, "Kaldros duplicate user-facing choice remained", "Kaldros UI grouping regression");
need(harness, "local optionNavs", "named Options navigation coverage");
need(harness, "navName", "navigation-specific failure messages");
need(harness, "central Options navigation owner missing", "central callback owner presence regression");
need(harness, "central Options navigation owner was replaced", "central callback owner identity regression");
need(harness, "local modulesOwner", "central callback owner reapply regression");
need(harness, "SFUI1434_Apply recreated the Modules navigation owner", "central callback wrapper stacking regression");
need(harness, "Rules panel shared footer was not created", "shared footer creation regression");
need(harness, "Rules panel shared footer was not a usable FontString", "shared footer capability regression");
need(harness, "Rules panel shared footer was not hydrated", "shared footer hydration regression");
need(harness, "Rules page remained visible after Manage Modules opened", "Modules body navigation regression");
need(harness, "Rules page remained visible after direct ShowOptions", "direct ShowOptions navigation regression");
need(harness, "alert evaluation invoked the authoritative parser a second time", "no raw reparse regression");

need(workflow, "verify_public_groups_alerts_rules_sources.js", "Pass D source verifier workflow step");
need(workflow, "public_groups_alerts_rules_harness.lua", "Pass D harness workflow step");
need(toc, "SignalFireRuntime.lua", "Runtime remains production-loaded");
need(toc, "SignalFireUI.lua", "UI remains production-loaded");
if (/p\[27\]|p\[28\]/.test(core + chat + bronze + runtime + ui)) {
  throw new Error("Pass D source verification failed: LIST packet expanded past p26");
}
if (!/^## Version: 1\.5\.3/m.test(toc)) {
  throw new Error("Pass D source verification failed: addon version changed");
}
if (bronze.includes("Public Groups Alerts & Rules - Pass D")) {
  throw new Error("Pass D source verification failed: BronzeLFG.lua became a Pass D owner");
}

console.log("Public Groups Alerts & Rules Pass D source verification: PASS");
