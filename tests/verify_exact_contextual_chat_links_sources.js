const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");
const core = fs.readFileSync("SignalFire/SignalFireCore.lua", "utf8");

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(core, 'SignalFire_RELEASE_NAME = "SignalFire 1.5.3 Guild and Group Link Coverage RC"',
  "Phase 12C release name");
requireText(core, 'SignalFire_DEVELOPMENT_MILESTONE = "Guild and Group Link Coverage"',
  "Phase 12C development milestone");
requireText(ui, 'P3.generation = "1.5.3-phase12c-coverage"', "Phase 12C runtime owner");
requireText(ui, "P3.ResolveExactMessage = p3_resolve", "shared exact resolver export");
requireText(ui, "P3.SemanticKey = p3_semantic_key", "shared semantic key owner");
requireText(ui, "p3_upsert_canonical = function", "indexed canonical upsert owner");
requireText(ui, "function P3.TraceMessage(message)", "bounded parser trace");
requireText(diagnostics, "parser trace <message>", "parser trace slash command");

const resolverStart = ui.indexOf("local function p3_resolve(");
const resolverEnd = ui.indexOf("\n    P3.ResolveExactMessage", resolverStart);
if (resolverStart < 0 || resolverEnd < 0) throw new Error("exact resolver body not found");
const resolver = ui.slice(resolverStart, resolverEnd);
for (const required of ["p3_candidate(raw)", "p3_parse(raw)", "p3_upsert_canonical(prepared)",
  "p3_render(prepared, raw)", "p3_cache_render_decision(sourceKey, prepared, true"]) {
  requireText(resolver, required, `resolver stage ${required}`);
}
const parseAt = resolver.indexOf("p3_parse(raw)");
const upsertAt = resolver.indexOf("p3_upsert_canonical(prepared)");
const renderAt = resolver.indexOf("p3_render(prepared, raw)");
const cacheAt = resolver.indexOf("p3_cache_render_decision(sourceKey, prepared, true");
if (!(parseAt < upsertAt && upsertAt < renderAt && renderAt < cacheAt)) {
  throw new Error("exact resolver stage order is not parse -> upsert -> link -> cache");
}

const workerStart = ui.indexOf("p3_process = function(rec)");
const workerEnd = ui.indexOf("\n    function P3.Filter", workerStart);
if (workerStart < 0 || workerEnd < 0) throw new Error("deferred worker body not found");
const worker = ui.slice(workerStart, workerEnd);
for (const forbidden of ["p3_parse(", "TestParse", "p3_upsert_canonical(", "p3_render(",
  "p3_cache_render_decision("]) {
  if (worker.includes(forbidden)) throw new Error(`worker repeats exact resolver work: ${forbidden}`);
}
for (const required of ["RequestPublicGroupsRefresh", "NotifyForPublicGroup",
  "SFN_RecordGuildRecruitmentActivity", 'SF151_RequestPanelRefresh("guildBrowser")']) {
  requireText(worker, required, `deferred side effect ${required}`);
}

const filterStart = ui.indexOf("function P3.Filter(");
const filterEnd = ui.indexOf("\n    local function p3_remove_filter", filterStart);
const filter = ui.slice(filterStart, filterEnd);
requireText(filter, "p3_cached_render_decision", "filter completed-decision lookup");
requireText(filter, 'p3_resolve(author, raw, select(2, ...), event, "filter")',
  "filter resolver fallback");
for (const forbidden of ["p3_parse(", "TestParse", "p3_upsert_canonical(",
  "RequestPublicGroupsRefresh", "NotifyForPublicGroup", "collectgarbage"]) {
  if (filter.includes(forbidden)) throw new Error(`filter owns forbidden independent work: ${forbidden}`);
}

for (const alias of ["snowgrave", "kaldros", "soggoth", "sogoth", "kazzak", "vault",
  "blackfathom", "rdf", "molten core", "heasl", "azuregos", "recluta", "guild latina"]) {
  requireText(chat.toLowerCase(), alias, `field alias ${alias}`);
}
for (const field of ["exactResolverCalls", "exactResolverCacheHits", "exactResolverCacheMisses",
  "exactResolverFilterFallbacks", "exactResolverSourceOwners", "exactResolverFilterOwners",
  "exactResolverReentryPrevented", "canonicalUpserts", "exactLinksBuilt",
  "eligibleMessagesWithoutLinks", "genericLinksBuilt", "guildCandidates", "guildAccepted",
  "eligibleGuildMessagesWithoutLinks", "eligibleGroupMessagesWithoutLinks", "unknownActivities"]) {
  requireText(ui, `"${field}"`, `aggregate counter ${field}`);
}

console.log("exact contextual chat-link source verification: PASS");
