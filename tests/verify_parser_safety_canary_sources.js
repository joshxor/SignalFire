const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");
const core = fs.readFileSync("SignalFire/SignalFireCore.lua", "utf8");

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(core, 'SignalFire_RELEASE_NAME = "SignalFire 1.5.3 Guild and Group Link Coverage RC"', "canary release name");
requireText(ui, "function P3.StopParserWork(reason)", "shared parser shutdown owner");
requireText(ui, 'B._sfP3Frame:SetScript("OnUpdate", nil)', "sleeping parser worker");
requireText(ui, 'p3_canary_check("before source candidate")', "source deadline check");
requireText(ui, 'p3_canary_check("before TestParse")', "parser deadline check");
requireText(ui, 'p3_canary_abort("worker re-entry")', "worker re-entry trigger");
requireText(ui, 'p3_canary_abort("queue corruption")', "queue-corruption trigger");
requireText(ui, 'p3_canary_abort("hard queue bound exceeded")', "queue-bound trigger");
requireText(ui, 'p3_canary_abort("worker frame exceeded 10 ms")', "worker-time trigger");

const filterStart = ui.indexOf("function P3.Filter(");
const filterEnd = ui.indexOf("\n    local function p3_remove_filter", filterStart);
if (filterStart < 0 || filterEnd < 0) throw new Error("P3.Filter body not found");
const filter = ui.slice(filterStart, filterEnd);
for (const forbidden of ["TestParse", "p3_parse(", "p3_enqueue(", "p3_process(",
  "p3_upsert_canonical(", "ClearRuntimeCaches", "CacheLifecycle", "RequestPublicGroupsRefresh"]) {
  if (filter.includes(forbidden)) throw new Error(`display filter contains forbidden work: ${forbidden}`);
}

requireText(diagnostics, "SIGNALFIRE_PHASE12B_PARSER_CANARY_BEGIN", "canary block");
requireText(diagnostics, "function C:Shutdown(outcome, reason)", "single canary shutdown path");
requireText(diagnostics, "function C:CheckSafety()", "automatic safety owner");
requireText(diagnostics, "function C:GetIdentity()", "build identity owner");
requireText(diagnostics, "function C:PrintIdentity(row)", "build identity printer");
requireText(diagnostics, "function B:SF152_HandleParserSlash(command)", "final parser slash handler");
for (const command of ["parser identity", "parser trace ", "parser canary", "parser abort", "parser off", "parser status", "parser report"]) {
  requireText(diagnostics, command, `${command} command`);
}
requireText(diagnostics, 'row.version == "1.5.3"', "exact version identity gate");
requireText(diagnostics, 'row.diagnosticGeneration == "1.5.1-phase10b"',
  "diagnostic identity gate");
requireText(diagnostics, 'string.find(row.chatRuntimeGeneration, "phase12c", 1, true)',
  "Phase 12C runtime identity gate");
requireText(diagnostics, 'row.installedFilters == 0', "zero-filter identity gate");
requireText(diagnostics, "The installed SignalFire files do not match the canary build. Canary not started.",
  "mixed-install refusal");
requireText(diagnostics, 'C.frame:SetScript("OnUpdate", nil)', "inactive canary timer");
requireText(diagnostics, 'C:ForceOff("canary build startup", true)', "safe startup state");
requireText(diagnostics, "P3.StopParserWork", "runtime-owned shutdown call");
requireText(diagnostics, "P3._canaryDiagnosticsEnabled = false", "bounded measurements");

console.log("parser safety canary source verification: PASS");
