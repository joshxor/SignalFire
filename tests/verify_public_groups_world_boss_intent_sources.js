const fs = require("fs");

const core = fs.readFileSync("SignalFire/SignalFireCore.lua", "utf8");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const bronze = fs.readFileSync("SignalFire/BronzeLFG.lua", "utf8");
const harness = fs.readFileSync("tests/public_groups_world_boss_intent_harness.lua", "utf8");
const workflow = fs.readFileSync(".github/workflows/release.yml", "utf8");

const need = (source, value, label) => {
  if (!source.includes(value)) throw new Error(`Pass C source verification failed: ${label}`);
};

need(core, "worldBosses = ASCENSION_WORLDBOSSES_143", "Ascension World Boss profile ownership");
need(core, "worldBossAliases", "profile-owned World Boss aliases");
need(core, '"Lord Kazzak"', "canonical Lord Kazzak data");
need(core, '"Dragons of Nightmare"', "canonical Dragons of Nightmare data");
need(core, '"Kaldros Depthbreaker"', "preserved Kaldros activity data");

need(chat, "local function sffcl_world_boss_entries", "profile-aware World Boss matcher");
need(chat, "active.worldBosses", "active profile World Boss consumption");
need(chat, "active.worldBossAliases", "profile-aware alias consumption");
need(chat, "SignalFireFastChatLinks.IsWorldBossCandidate", "bounded candidate matcher export");
need(chat, '"World Boss"', "generic World Boss representation");
need(chat, '" worldboss "', "worldboss spelling support");
need(chat, "SignalFireFastChatLinks.DetectIntent", "authoritative intent owner export");
need(chat, "result.intent = sffcl_intent(raw)", "canonical parser intent metadata");
need(chat, '"Lord Kazzak"', "Kazzak canonicalization");
need(chat, '"Snowgrave / Kaldros / Soggoth"', "preserved multi-boss fixture expectation");

const worldBlockStart = chat.indexOf("local function sffcl_world_activities");
const worldBlockEnd = chat.indexOf("local function sffcl_specific_dungeon", worldBlockStart);
if (worldBlockStart < 0 || worldBlockEnd < 0) throw new Error("Pass C source verification failed: World Boss matcher boundary");
const worldBlock = chat.slice(worldBlockStart, worldBlockEnd);
if (worldBlock.includes("if not sffcl_is_ascension()")) {
  throw new Error("Pass C source verification failed: World Boss matcher retained an Ascension-only gate");
}
if (worldBlock.includes("if sffcl_word(s, \"azuregos\")")) {
  throw new Error("Pass C source verification failed: duplicated hard-coded World Boss database remained");
}

need(ui, "local worldBoss = SignalFireFastChatLinks and SignalFireFastChatLinks.IsWorldBossCandidate", "World Boss candidate gate");
need(ui, "activity = activity or worldBoss", "World Boss candidate activity context");
need(ui, 'local function p6_intent_matches', "Public Groups intent filter owner");
need(ui, 'record.intent == "Recruiter"', "Recruiting canonical filter mapping");
need(ui, 'record.intent == "Applicant"', "Seeking Group canonical filter mapping");
need(ui, 'publicIntentFilter or "All Intents"', "intent filter state");
need(ui, 'for _, value in ipairs({"All Intents", "Recruiting", "Seeking Group"})', "intent dropdown options");
need(ui, 'publicFilterButtons["World Boss"]', "World Boss control owner");
need(ui, '["World Boss"]', "World Boss snapshot/count ownership");
need(ui, 'local names = {"All", "Dungeon", "Raid", "Key", "Event", "Guild", "LFG", "Social", "World Boss"}', "mutually-exclusive World Boss control set");
need(ui, 'worldBossAnchor', "World Boss/Intent geometry anchor");
need(ui, 'and owner.publicIntentDrop', "lazy Public Groups readiness includes Intent");
need(ui, '"publicIntentDrop"', "standard Intent dropdown lifecycle registration");
need(ui, 'self.publicIntentFilter = "All Intents"', "Clear resets Intent");
need(bronze, '"World Boss"', "base Public Groups World Boss control/count");
need(bronze, "function BLFG:PublicMatchesIntentFilter", "legacy intent filter compatibility owner");
need(bronze, 'self:PublicMatchesIntentFilter(g, self.publicIntentFilter)', "base intent filter intersection");

for (const phrase of [
  "LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak",
  "LF DPS Azuregos", "LFM Azuregos need DPS", "DPS LFG Azuregos", "LF2 DPS Azuregos", "LFM Kazzak", "LFG Kazzak",
  "LFG ZG", "LFM ZG need DPS", "world-boss guild ad lost Guild precedence", "raid activity lost precedence",
  "World Boss", "Recruiting", "Seeking Group",
  "World Boss filter", "plain Mythic recruiting filter leaked RDF", "Mythic+ recruiting filter changed",
  "for _ = 1, 20 do", "filtered-out selected World Boss row", "workerScript == false",
  "for _, frameCount in ipairs({1, 2, 5, 10})", "one TestParse per receiving frame",
]) need(harness, phrase, `harness fixture/coverage ${phrase}`);

need(workflow, "verify_public_groups_world_boss_intent_sources.js", "Pass C source verifier workflow step");
need(workflow, "public_groups_world_boss_intent_harness.lua", "Pass C harness workflow step");
need(workflow, "activity_discovery_pass_a_harness.lua", "Pass A harness retained");
need(workflow, "activity_discovery_pass_b_harness.lua", "Pass B harness retained");

if (/p\[27\]|p\[28\]/.test(core + chat + bronze + ui)) {
  throw new Error("Pass C source verification failed: LIST packet expanded past p26");
}
if (/B\._sfP3Frame:SetScript\(\s*["']OnUpdate["']\s*,\s*function/.test(ui)) {
  throw new Error("Pass C source verification failed: permanent idle parser OnUpdate function");
}

console.log("Public Groups World Boss and intent source verification: PASS");
