const fs = require("fs");

const read = (name) => fs.readFileSync(`SignalFire/${name}`, "utf8");
const ui = read("SignalFireUI.lua");
const chat = read("SignalFireChat.lua");
const marketplace = read("SignalFireMarketplace.lua");
const marketNetwork = read("SignalFireMarketplaceNetwork.lua");
const marketUI = read("SignalFireMarketplaceUI.lua");
const toc = fs.readFileSync("SignalFire/SignalFire.toc", "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`runtime FPS cleanup verification failed: ${label}`);
};

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

// Marketplace is event/keyed-wake driven. Its module teardown owns all packet
// handlers and scheduled wakes, while a hidden panel cannot render a snapshot.
for (const text of [
  "function M:Disable(reason)", "self:CancelExpiration()", "network:Disable(reason)",
  "function N:Disable()", "B:UnregisterNetworkPacketHandler(\"MKT2\",self)",
  "B:SF151_CancelDelayed(self.wakeKey)", "B:SF151_CancelDelayed(self.linkWakeKey)",
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

// Preserve stable external contracts and avoid permanent diagnostics work.
requireText(marketplace, "mkt1:[at]:[%w%-]+:%d+:%d+", "stable Marketplace listing identity");
requireText(marketplace, "Press Enter to send.", "user-controlled Share Link composer");
requireText(toc, "## Version: 1.5.3", "version remains 1.5.3");
if (ui.includes("NewTicker") || ui.includes("permanent profiler")) {
  throw new Error("runtime FPS cleanup verification failed: permanent profiling/ticker work");
}

console.log("runtime FPS cleanup source verification: PASS");
