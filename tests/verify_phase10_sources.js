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
requireText(ui, "p3_parsing_enabled() and o.inlineChatLinks == true", "final safe link gate");
requireText(diagnostics, "SIGNALFIRE_PHASE10_STABILITY_BEGIN", "Phase 10 begin marker");
requireText(diagnostics, 'S.generation = "1.5.1-phase10b"', "Phase 10b owner");
requireText(diagnostics, "function B:SF151_RepairReleaseDatabase", "release database migration");
requireText(diagnostics, "function S:GetConflicts", "conflict diagnostics");
requireText(diagnostics, "function S:ProbeOwnership", "controlled ownership probe");
requireText(diagnostics, "signalFireChained", "explicit chained ownership state");
requireText(diagnostics, "function S:ProbeSetItemRefOwnership", "SetItemRef reachability probe");
requireText(ui, "function B:SF151_ProbeChatFrameOwnership", "chat-frame reachability probe");
requireText(ui, "function B:SF151_GetChatFilterState", "filter state and activity split");
requireText(diagnostics, "function S:SampleResources", "resource attribution");
requireText(diagnostics, 's_emit("chat ownership:', "printed chat ownership summary");
requireText(diagnostics, 's_emit("panels:', "printed lazy-panel summary");
requireText(diagnostics, 's_emit("timers:', "printed timer summary");
requireText(diagnostics, 's_emit("cache lifecycle:', "printed cache summary");
requireText(diagnostics, 's_emit("conflicts:', "printed conflict summary");
requireText(diagnostics, 'cmd == "diag start"', "diagnostic slash commands");
requireText(diagnostics, "S.maximumRecent = 32", "bounded recent history");
requireText(diagnostics, "S.maximumErrors = 12", "bounded error history");
requireText(diagnostics, "S.maximumSamples = 16", "bounded resource history");
requireText(toc, "## Version: 1.5.3", "release-candidate version");

const phase10Start = diagnostics.indexOf("SIGNALFIRE_PHASE10_STABILITY_BEGIN");
const phase10End = diagnostics.indexOf("SIGNALFIRE_PHASE10_STABILITY_END", phase10Start);
if (phase10Start < 0 || phase10End <= phase10Start) throw new Error("Phase 10 source markers are incomplete");
const phase10 = diagnostics.slice(phase10Start, phase10End);
if (/SetScript\s*\(\s*["']OnUpdate["']/.test(phase10)) {
  throw new Error("Phase 10 added permanent OnUpdate polling");
}
if (phase10.includes("SetCVar(\"scriptProfile\"") || phase10.includes("SetCVar('scriptProfile'")) {
  throw new Error("Phase 10 enables script profiling automatically");
}
if (phase10.includes("ChatFrame_AddMessageEventFilter") || phase10.includes("ChatFrame_RemoveMessageEventFilter")) {
  throw new Error("Phase 10b changes chat-filter ownership");
}
if (/\b_G\.SetItemRef\s*=(?!=)/.test(phase10) || /\bSetItemRef\s*=\s*function/.test(phase10)) {
  throw new Error("Phase 10b rehooks SetItemRef");
}
if (/BronzeLFG_DB\s*=\s*\{/.test(phase10)) {
  throw new Error("Phase 10 replaces the SavedVariables root");
}
if (!phase10.includes("if not S.enabled then return binding.original")) {
  throw new Error("disabled diagnostics do not have a constant-time bypass");
}

console.log("Phase 10 source verification: PASS");
