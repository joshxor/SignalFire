const fs = require("fs");

const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");
const toc = fs.readFileSync("SignalFire/SignalFire.toc", "utf8");

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(chat, "function BLFG:SF151_ApplyChatLinkSafeDefault", "safe Chat Links migration");
requireText(chat, "options.inlineChatLinks = false", "safe Chat Links default");
requireText(ui, "B:SF151_ApplyChatLinkSafeDefault(BronzeLFG_DB)", "final chat owner migration use");
requireText(ui, "o.publicGroups ~= false and o.inlineChatLinks == true", "final safe link gate");
requireText(diagnostics, "SIGNALFIRE_PHASE10_STABILITY_BEGIN", "Phase 10 begin marker");
requireText(diagnostics, 'S.generation = "1.5.1-phase10"', "Phase 10 owner");
requireText(diagnostics, "function B:SF151_RepairReleaseDatabase", "release database migration");
requireText(diagnostics, "function S:GetConflicts", "conflict diagnostics");
requireText(diagnostics, "function S:SampleResources", "resource attribution");
requireText(diagnostics, 'cmd == "diag start"', "diagnostic slash commands");
requireText(diagnostics, "S.maximumRecent = 32", "bounded recent history");
requireText(diagnostics, "S.maximumErrors = 12", "bounded error history");
requireText(diagnostics, "S.maximumSamples = 16", "bounded resource history");
requireText(toc, "## Version: 1.5.1", "release-candidate version");

const phase10 = diagnostics.slice(diagnostics.indexOf("SIGNALFIRE_PHASE10_STABILITY_BEGIN"));
if (/SetScript\s*\(\s*["']OnUpdate["']/.test(phase10)) {
  throw new Error("Phase 10 added permanent OnUpdate polling");
}
if (phase10.includes("SetCVar(\"scriptProfile\"") || phase10.includes("SetCVar('scriptProfile'")) {
  throw new Error("Phase 10 enables script profiling automatically");
}
if (/BronzeLFG_DB\s*=\s*\{/.test(phase10)) {
  throw new Error("Phase 10 replaces the SavedVariables root");
}
if (!phase10.includes("if not S.enabled then return binding.original")) {
  throw new Error("disabled diagnostics do not have a constant-time bypass");
}

console.log("Phase 10 source verification: PASS");
