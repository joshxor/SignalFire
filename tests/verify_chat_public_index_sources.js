const fs = require("fs");

const sourcePath = process.argv[2];
if (!sourcePath) throw new Error("SignalFireUI.lua path is required");
const source = fs.readFileSync(sourcePath, "utf8");
const startMarker = "-- SIGNALFIRE_PHASE5_CHAT_PUBLIC_INDEX_BEGIN";
const endMarker = "-- SIGNALFIRE_PHASE5_CHAT_PUBLIC_INDEX_END";
const start = source.indexOf(startMarker);
const end = source.indexOf(endMarker);
if (start < 0 || end <= start) throw new Error("Phase 5 source markers were not found");
const block = source.slice(start, end);

for (const required of [
  'P3.generation = "1.5.3-phase12c-coverage"',
  "local function p3_source_key",
  "local function p3_cached_render_decision",
  "local function p3_index_lookup",
  "p3_upsert_canonical = function",
  "local function p3_rebuild_public_index",
  "function B:SF151_GetChatPublicIndexDiagnostics()",
  'local P3_INDEX_MAX = 512',
  'local function p3_inline()',
]) {
  if (!block.includes(required)) throw new Error(`missing Phase 5 owner: ${required}`);
}

for (const removed of [
  "p3_make_preview",
  "p3_consolidate",
  "previewRow",
]) {
  if (block.includes(removed)) throw new Error(`obsolete steady-state path remains: ${removed}`);
}

const rewriteStart = block.indexOf("local function p3_rewrite_rendered_message");
const rewriteEnd = block.indexOf("local function p3_hook_custom_chat_frame", rewriteStart);
if (rewriteStart < 0 || rewriteEnd <= rewriteStart) throw new Error("AddMessage fallback block was not found");
const rewrite = block.slice(rewriteStart, rewriteEnd);
for (const forbidden of ["p3_parse(", "p3_enqueue(", "p3_upsert_canonical(", "RequestPublicGroupsRefresh", "NotifyForPublicGroup"] ) {
  if (rewrite.includes(forbidden)) throw new Error(`AddMessage fallback duplicates exact-resolver work: ${forbidden}`);
}
if (!rewrite.includes("p3_cached_render_decision")) throw new Error("AddMessage fallback does not reuse source decisions");
if (!rewrite.includes("p3_resolve")) throw new Error("AddMessage fallback lacks the shared resolver fallback");

const upsertStart = block.indexOf("p3_upsert_canonical = function");
const upsertEnd = block.indexOf("local function p3_row_quality", upsertStart);
const upsert = block.slice(upsertStart, upsertEnd);
if (upsert.includes("for id, row in pairs(B.publicGroups)")) throw new Error("steady-state upsert scans Public Groups");
if (!upsert.includes("p3_index_lookup(key)")) throw new Error("steady-state upsert bypasses canonical index");

console.log("chat/Public Groups canonical-index source checks: PASS");
