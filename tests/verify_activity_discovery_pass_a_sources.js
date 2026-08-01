const fs = require("fs");
const core = fs.readFileSync("SignalFire/SignalFireCore.lua", "utf8");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const listing = fs.readFileSync("SignalFire/SignalFireListing.lua", "utf8");
const harness = fs.readFileSync("tests/activity_discovery_pass_a_harness.lua", "utf8");
const loaderHarness = fs.readFileSync("tests/parser_regression_harness.lua", "utf8");
const workflow = fs.readFileSync(".github/workflows/release.yml", "utf8");
const need = (source, value, label) => { if (!source.includes(value)) throw new Error(`activity discovery source verification failed: ${label}`); };
need(core, 'basicDungeonDifficulties = {"Normal", "Heroic", "Mythic"}', "Ascension ordinary Dungeon profile list");
need(listing, 'if typeName == "Dungeon" then return {"Normal", "Heroic", "Mythic"} end', "final Ascension difficulty owner");
need(listing, 'state.difficulty ~= "Heroic" and state.difficulty ~= "Mythic"', "saved Mythic state preservation");
need(listing, 'difficulty == "Heroic" or difficulty == "Mythic"', "plain Mythic preview");
need(chat, "function B:SFDiscoverActivityPassA(text)", "authoritative discovery helper");
need(chat, "parsed.difficulty, parsed.keyLevel", "normalized discovery metadata");
need(chat, 'discovery.difficulty == "Mythic+" then parsed.type = "Key"', "Mythic+ precedence");
need(chat, 'parsed.type == "Raid"', "raid precedence");
need(chat, 'contains(input, " guild ")', "guild protection");
need(chat, 'result.difficulty = fast.difficulty', "core parser difficulty propagation");
need(chat, "result.keyLevel = fast.keyLevel", "reconciliation metadata preservation");
need(ui, "publicDifficultyFilter", "Public Groups difficulty state");
need(ui, '"All Difficulties", "Normal", "Heroic", "Mythic", "Mythic+"', "difficulty dropdown choices");
need(ui, "p6_difficulty_matches", "exact difficulty matcher");
need(ui, "record.difficulty", "difficulty search metadata");
if (ui.includes('record.difficulty == "Mythic+" and record.kind == "Key"')) throw new Error("activity discovery source verification failed: Mythic+ is incorrectly gated by type");
need(ui, 'panel, "TOPLEFT", 260, -92', "non-overlapping difficulty label placement");
need(ui, 'panel, "TOPLEFT", 318, -86', "non-overlapping difficulty dropdown placement");
need(ui, "PG.AttachPanel = p6_attach_panel", "Phase 6 Public Groups attachment owner");
need(ui, '"publicDifficultyDrop"', "known Public Groups difficulty dropdown registration");
const phase6Start = ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_BEGIN");
const phase6End = ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_END", phase6Start);
if (phase6Start < 0 || phase6End < 0) throw new Error("activity discovery source verification failed: Phase 6 lifecycle boundary");
const attachStart = ui.indexOf("local function p6_attach_panel", phase6Start);
const attachEnd = ui.indexOf("PG.AttachPanel = p6_attach_panel", attachStart);
if (attachStart < 0 || attachEnd < 0 || attachEnd > phase6End) throw new Error("activity discovery source verification failed: Phase 6 attachment boundary");
const attach = ui.slice(attachStart, attachEnd);
if (/if not panel or panel\._sfP6ViewHooks then return end/.test(attach)) {
  throw new Error("activity discovery source verification failed: hook marker still blocks control reconciliation");
}
const hookGuard = attach.indexOf('field(panel, "_sfP6ViewHooks") == true');
const controlReconciliation = attach.indexOf("publicDifficultyDrop");
if (hookGuard < 0 || controlReconciliation < 0 || controlReconciliation > hookGuard) {
  throw new Error("activity discovery source verification failed: Phase 6 controls are not reconciled before hook guard");
}
const phase7Start = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_BEGIN");
const phase7End = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_END", phase7Start);
if (phase7Start < 0 || phase7End < 0) throw new Error("activity discovery source verification failed: Phase 7 lifecycle boundary");
const phase7 = ui.slice(phase7Start, phase7End);
need(phase7, "p7_reconcile_public_groups", "Phase 7 Public Groups attachment reconciliation");
need(phase7, "SignalFirePublicGroupsView151", "Phase 7 authoritative Public Groups attachment owner");
need(phase7, "publicDifficultyDrop", "Phase 7 Public Groups difficulty readiness");
const ensurePanelStart = phase7.indexOf("function LP:EnsurePanel");
const ensurePanelEnd = phase7.indexOf("function LP:HideBuiltPanels", ensurePanelStart);
if (ensurePanelStart < 0 || ensurePanelEnd < 0) throw new Error("activity discovery source verification failed: Phase 7 EnsurePanel boundary");
const ensurePanel = phase7.slice(ensurePanelStart, ensurePanelEnd);
if ((ensurePanel.match(/p7_reconcile_public_groups\(B\)/g) || []).length < 2) {
  throw new Error("activity discovery source verification failed: Public Groups attachment was not reconciled on reuse and build paths");
}
const reuseReady = ensurePanel.indexOf("if record.ready(B)");
const reuseRegistration = ensurePanel.indexOf("RegisterKnownDropdowns", ensurePanel.indexOf("p7_reconcile_public_groups(B)"));
if (reuseReady < 0 || reuseRegistration < 0 || reuseRegistration > reuseReady) {
  throw new Error("activity discovery source verification failed: lazy Public Groups reuse does not register reconciled dropdowns");
}
need(ui, "row.keyLevel = parsed.keyLevel or parsed.keylevel or parsed.key or row.keyLevel", "Public Groups keystone metadata ownership");
need(ui, 'keyLevel=tostring(row.keyLevel or "")', "Public Groups snapshot keyLevel ownership");
if (/row\.key\s*=\s*parsed\.key(?:Level|level)?\b/.test(ui)) {
  throw new Error("activity discovery source verification failed: parser keystone metadata overwrote Public Groups row.key identity");
}
if (/keyLevel\s*=\s*tostring\(row\.keyLevel\s+or\s+row\.key\b/.test(ui)) {
  throw new Error("activity discovery source verification failed: snapshot keyLevel fell back to Public Groups row.key identity");
}
const mergeStart = chat.indexOf("local function sf151_merge_row");
const mergeEnd = chat.indexOf("\n    function B:SF151_ReconcilePublicGroups", mergeStart);
if (mergeStart < 0 || mergeEnd < 0) throw new Error("activity discovery source verification failed: Public Groups merge boundary");
if (chat.slice(mergeStart, mergeEnd).includes('"key"')) {
  throw new Error("activity discovery source verification failed: sf151_merge_row merged stable row.key identity");
}
need(workflow, "verify_activity_discovery_pass_a_sources.js", "workflow source verifier");
need(workflow, "activity_discovery_pass_a_harness.lua", "workflow Lua harness");
need(harness, "function JoinChannelByName", "joined BLFG channel simulation");
need(harness, "onlyListPacket", "production CreateListing packet capture");
need(harness, "RunDropdownInitializer", "actual difficulty dropdown callback coverage");
need(harness, "filtered-out selected Public Group was retained", "selected row clearing coverage");
need(harness, "for _ = 1, 20 do", "geometry/reuse lifecycle coverage");
need(harness, "LIST packet expanded past p[26]", "current LIST packet compatibility coverage");
need(harness, "assertStablePublicRow", "Public Groups stable identity coverage");
need(harness, 'tostring(key.key) ~= "5"', "BFD Mythic+ row identity is not keystone metadata");
need(harness, 'tostring(deadmines.key) ~= "7"', "Deadmines Mythic+ row identity is not keystone metadata");
need(loaderHarness, "function objectMethods:SetPoint", "stored mock geometry");
need(loaderHarness, "function UIDropDownMenu_Initialize", "stored dropdown initializer mock");
if (/p\[27\]|p\[28\]/.test(chat + core + ui)) throw new Error("activity discovery source verification failed: packet expansion");
console.log("activity discovery pass A source verification: PASS");
