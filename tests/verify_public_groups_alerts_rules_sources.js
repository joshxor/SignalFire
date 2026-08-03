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
const forbid = (source, value, label) => {
  if (source.includes(value)) throw new Error(`Pass D source verification failed: ${label}`);
};

const ownerStart = runtime.indexOf("-- Public Groups Alerts & Rules - Pass D.");
const ownerEnd = runtime.indexOf("-- Server profiles", ownerStart);
if (ownerStart < 0 || ownerEnd < 0) throw new Error("Pass D source verification failed: Runtime owner boundary");
const owner = runtime.slice(ownerStart, ownerEnd);

need(owner, "SignalFirePublicGroupAlerts153", "single named Runtime alert owner");
need(owner, "sf151StableLink", "canonical-row gate");
for (const field of ["row.type", "row.activity", "row.activities", "row.intent", "row.roles", "row.difficulty", "row.keyLevel", "row.xpAura"]) {
  need(owner, field, `canonical ${field} consumption`);
}
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
need(passDUI, "Configure Alert Rules", "main Options entry point");
need(passDUI, "publicAlertIntentFilter", "independent intent rule state");
need(passDUI, "publicAlertRoleFilter", "independent role rule state");
need(passDUI, "publicAlertXPAuraFilter", "independent XP Aura rule state");
need(passDUI, "publicAlertWorldBossMode", "World Boss mode control");
need(passDUI, "sf153_refresh_bosses", "profile-aware dynamic World Boss controls");
need(passDUI, "publicAlertDungeonDifficulty", "Dungeon difficulty control");
need(passDUI, "publicAlertCustomText", "custom quick keyword text");
need(passDUI, "SignalFireUILifecycle151", "standard dropdown lifecycle registration");
forbid(passDUI, "publicFilter =", "Public Groups visible Type filter ownership reused by alerts");
forbid(passDUI, "publicIntentFilter =", "Public Groups visible Intent filter ownership reused by alerts");

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
need(harness, "Pass D rules panel was not lazy", "lazy Options UI regression");
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
