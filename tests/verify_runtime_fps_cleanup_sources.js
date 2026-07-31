const fs = require("fs");

const toc = fs.readFileSync("SignalFire/SignalFire.toc", "utf8");
const files = toc.split(/\r?\n/).map((line) => line.trim())
  .filter((line) => line && !line.startsWith("##"));
if (files.length !== 16 || new Set(files).size !== files.length) {
  throw new Error(`runtime FPS cleanup verification failed: unexpected TOC production file set (${files.length})`);
}
const sources = Object.fromEntries(files.map((name) => [name, fs.readFileSync(`SignalFire/${name}`, "utf8")]));
const allProduction = Object.values(sources).join("\n");
const read = (name) => sources[name];
const ui = read("SignalFireUI.lua");
const chat = read("SignalFireChat.lua");
const marketplace = read("SignalFireMarketplace.lua");
const marketNetwork = read("SignalFireMarketplaceNetwork.lua");
const marketUI = read("SignalFireMarketplaceUI.lua");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`runtime FPS cleanup verification failed: ${label}`);
};

// This is an explicit whole-TOC audit. Existing OnUpdate owners are legacy or
// event-driven UI owners; any new owner changes a reviewed count and must be
// deliberately documented here rather than becoming an accidental poller.
const approvedOnUpdateOwners = {
  "SignalFireCore.lua": 0, "BronzeLFG.lua": 20, "SignalFireDiscovery.lua": 0,
  "SignalFireNetwork.lua": 4, "SignalFireRoster.lua": 0, "SignalFireCommunity.lua": 0,
  "SignalFireRuntime.lua": 1, "SignalFireIntegration.lua": 1, "SignalFireControls.lua": 0,
  "SignalFireChat.lua": 1, "SignalFireListing.lua": 0, "SignalFireUI.lua": 24,
  "SignalFireMarketplace.lua": 0, "SignalFireMarketplaceNetwork.lua": 0,
  "SignalFireMarketplaceUI.lua": 0, "SignalFireDiagnostics.lua": 6,
};
for (const [name, source] of Object.entries(sources)) {
  const updates = (source.match(/SetScript\(\s*["']OnUpdate["']/g) || []).length;
  if (updates !== approvedOnUpdateOwners[name]) throw new Error(`runtime FPS cleanup verification failed: unreviewed OnUpdate owner in ${name}`);
  if (/NewTicker|C_Timer\.NewTicker/.test(source)) throw new Error(`runtime FPS cleanup verification failed: repeating timer in ${name}`);
}
for (const forbidden of ["message-rate drop", "message rate drop", "chat throttle", "rate-limit chat"]) {
  if (allProduction.toLowerCase().includes(forbidden)) throw new Error(`runtime FPS cleanup verification failed: ${forbidden}`);
}

// The Phase 12 source owner is the only authoritative parser path. Display
// filters are presentation-only and must remain safe when links are disabled.
const filterStart = ui.indexOf("function P3.Filter(");
const filterEnd = ui.indexOf("\n    local function p3_remove_filter", filterStart);
if (filterStart < 0 || filterEnd < 0) throw new Error("runtime FPS cleanup verification failed: chat filter boundary");
const filter = ui.slice(filterStart, filterEnd);
for (const forbidden of ["p3_parse", "TestParse", "p3_enqueue", "p3_process", "p3_upsert_canonical"]) {
  if (filter.includes(forbidden)) throw new Error(`runtime FPS cleanup verification failed: filter performs ${forbidden}`);
}
requireText(ui, "function P3.ReconcileFilterRegistration()", "chat filter owner");
requireText(ui, "if wanted == (P3._filterInstalled == true) then", "idempotent chat filter reconciliation");
requireText(ui, "ChatFrame_RemoveMessageEventFilter", "chat-links-off filter teardown");
requireText(chat, "BronzeLFG_DB.options.publicGroups == false", "parse-groups disabled source gate");
if ((ui.match(/local function p3_parse\(/g) || []).length !== 1) {
  throw new Error("runtime FPS cleanup verification failed: second Phase 12 parser owner");
}

// Marketplace is event/keyed-wake driven. Its module teardown owns all packet
// handlers and scheduled wakes, while a hidden panel cannot render a snapshot.
for (const text of [
  "function M:Disable(reason)", "self:CancelExpiration()", "network:Disable(reason)",
  "function N:Disable()", "B:UnregisterNetworkPacketHandler(\"MKT2\",self)",
  "B:SF151_CancelDelayed(self.wakeKey)", "B:SF151_CancelDelayed(self.linkWakeKey)",
  "B:SF151_CancelDelayed(self.discoveryKey)", "B:SF151_CancelDelayed(self.replayKey)",
  "function M:CancelExpiration()", "B:SF151_CancelDelayed(self.expirationTaskKey)",
  "local generation,profile=runtime.generation,runtime.profile",
  "current.generation~=generation or current.profile~=profile",
  "if not scheduled then runtime.wake=false; return false end",
]) requireText(marketplace + marketNetwork, text, `Marketplace lifecycle guard ${text}`);
if (marketNetwork.includes("SetScript(\"OnUpdate\"") || marketNetwork.includes("NewTicker")) {
  throw new Error("runtime FPS cleanup verification failed: Marketplace introduced periodic work");
}
requireText(marketUI, "if not self.panel or not self.panel:IsShown() then", "hidden Marketplace refresh gate");
requireText(marketUI, "self.hiddenRefreshSkips = self.hiddenRefreshSkips + 1", "hidden Marketplace refresh accounting");
requireText(marketUI, "if not self.active or self:GetPanelState() ~= \"visible\"", "hidden Marketplace render gate");
requireText(marketUI, "function U:DeactivateScripts()", "Marketplace script teardown");
requireText(marketUI, "self:ActiveScriptCount() == 0", "Marketplace disabled script invariant");
requireText(marketNetwork, "function N:ScheduleReplay", "keyed replay ownership");
requireText(marketNetwork, "function N:ScheduleLinkLookupWake", "keyed exact-link ownership");
requireText(marketNetwork, "N.maximumPending, N.pendingTTL, N.maximumDedup, N.dedupTTL = 32, 30, 256, 120", "bounded packet caches");
requireText(marketNetwork, "N.maximumLinkLookups, N.linkLookupTTL, N.linkRequesterCooldown = 16, 6, 5", "bounded exact-link cache");

// Hidden Network/Public Groups panels defer through the lazy-panel owner;
// neither data mutation path is permitted to construct or traverse rows.
requireText(ui, "LP:MarkDirty(\"network\", \"event-board-refresh\")", "hidden Network dirty ownership");
requireText(ui, "LP:MarkDirty(\"publicGroups\", \"public-data\")", "hidden Public Groups dirty ownership");
requireText(ui, "function LP:MarkDirty(key, reason)", "bounded panel dirty generations");
requireText(ui, "function LP:Open(key, trigger)", "visible panel refresh owner");

// Preserve stable external contracts and avoid permanent diagnostics work.
requireText(marketplace, "mkt1:[at]:[%w%-]+:%d+:%d+", "stable Marketplace listing identity");
for (const operation of ["U~1~", "R~1~", "Q~1~", "L~1~"]) requireText(marketNetwork, operation, `Marketplace packet contract ${operation}`);
requireText(marketplace, "|Hsignalfiremkt:", "stable Marketplace hyperlink contract");
requireText(marketplace, "Press Enter to send.", "user-controlled Share Link composer");
requireText(toc, "## Version: 1.5.3", "version remains 1.5.3");
if (allProduction.includes("permanent profiler")) {
  throw new Error("runtime FPS cleanup verification failed: permanent profiling/ticker work");
}

console.log("runtime FPS cleanup source verification: PASS");
