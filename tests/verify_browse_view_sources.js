const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(ui, "SIGNALFIRE_PHASE8_BROWSE_VIEW_BEGIN", "Phase 8 begin marker");
requireText(ui, "SIGNALFIRE_PHASE8_BROWSE_VIEW_END", "Phase 8 end marker");
requireText(ui, "SignalFireBrowseView151", "Browse cache owner");
requireText(ui, "P4.original.browse = function", "authoritative scheduler slot");
requireText(ui, "SF151_GetBrowseViewDiagnostics", "Browse diagnostics getter");
requireText(diagnostics, "browseView=", "performance report integration");
requireText(diagnostics, "session.browseDisplayViews", "Browse cache inventory");

const phase8 = ui.slice(ui.indexOf("SIGNALFIRE_PHASE8_BROWSE_VIEW_BEGIN"));
if (phase8.includes("GetVisibleListings(")) throw new Error("Phase 8 calls the historical Browse array builder");
if (phase8.includes("RefreshDetail(")) throw new Error("Phase 8 calls the historical detail renderer");
if (phase8.includes("RefreshBadge(")) throw new Error("Phase 8 calls the historical applicant rescan");
if (phase8.includes("browse.expiration")) throw new Error("Phase 8 schedules Browse expiration polling");
if (/SetScript\s*\(\s*["']OnUpdate["']/.test(phase8)) throw new Error("Phase 8 added permanent OnUpdate polling");

console.log("Browse view-cache source verification: PASS");
