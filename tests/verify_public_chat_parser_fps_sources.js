const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(ui, 'P3.generation = "1.5.2-phase12c"', "Phase 12C owner");
requireText(ui, "P3.workerMaximumRecords = 4", "worker record budget");
requireText(ui, "P3.workerMaximumMs = 0.75", "worker time budget");
requireText(ui, "function P3.ReconcileFilterRegistration()", "filter reconciliation owner");
requireText(ui, "function P3.IngestSource", "source ingestion owner");
requireText(ui, "p3_upsert_canonical = function", "canonical indexed owner");
requireText(chat, "parsingDisabledLegacyQueueReturns", "legacy option gate");

const filterStart = ui.indexOf("function P3.Filter(");
const filterEnd = ui.indexOf("\n    local function p3_remove_filter", filterStart);
if (filterStart < 0 || filterEnd < 0) throw new Error("final P3.Filter body was not found");
const filter = ui.slice(filterStart, filterEnd);
for (const forbidden of [
  "p3_parse", "TestParse", "p3_enqueue", "p3_process",
  "AddPublicGroup", "InlinePublicChatLinkForMessage", "sfcq_enqueue",
  "sfcq_public_signal", "sffcl_upsert", "p3_upsert_canonical",
  "UpsertGuildBrowserChatListing", "RequestPublicGroupsRefresh", "RefreshPublicGroups",
  "SignalFireCacheLifecycle151", "collectgarbage",
]) {
  if (filter.includes(forbidden)) throw new Error(`display filter contains forbidden work: ${forbidden}`);
}
requireText(filter, "p3_cached_render_decision", "completed render-cache lookup");
requireText(filter, "p3_resolve", "shared exact-resolver fallback");
if (filter.indexOf("p3_cached_render_decision") < filter.indexOf("p3_frame_allowed")) {
  throw new Error("display cache lookup occurs before the option/frame gates");
}

const legacyStart = chat.indexOf("local function sfcq_enqueue");
const legacyEnd = chat.indexOf("\n    local function", legacyStart + 20);
if (legacyStart < 0 || legacyEnd < 0) throw new Error("legacy queue entrance was not found");
const legacy = chat.slice(legacyStart, legacyEnd);
const gateAt = legacy.indexOf("BronzeLFG_DB.options.publicGroups == false");
const normalizeAt = legacy.indexOf("tostring(text or");
if (gateAt < 0 || normalizeAt < 0 || gateAt > normalizeAt) {
  throw new Error("legacy queue option gate is not before text normalization");
}

const applyStart = ui.indexOf("function P3.Apply()");
const applyEnd = ui.indexOf("\n    function P3.ClearRuntimeCaches", applyStart);
const apply = ui.slice(applyStart, applyEnd);
if (apply.includes("p3_hook_custom_chat_frames")) {
  throw new Error("Phase 12C installs AddMessage wrappers");
}

console.log("public chat parser FPS source verification: PASS");
