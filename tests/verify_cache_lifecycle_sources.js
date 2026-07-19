const fs = require("fs");

const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");
const start = diagnostics.indexOf("-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_BEGIN");
const end = diagnostics.indexOf("-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_END");
if (start < 0 || end <= start) throw new Error("Phase 9 cache lifecycle markers are missing");
const block = diagnostics.slice(start, end);

for (const required of [
  'CL.generation = "1.5.1-perf-phase9"',
  "CL.chatInterval = 256",
  "SF151_RunCacheMaintenance",
  "SF151_GetCacheLifecycleDiagnostics",
  "SF151_GetCacheLifecycleInventory",
  "SF151_ResetCacheLifecycleStats",
  'eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")',
  'eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")',
]) {
  if (!block.includes(required)) throw new Error(`missing Phase 9 source contract: ${required}`);
}

if (/SetScript\s*\(\s*["']OnUpdate["']/.test(block)) {
  throw new Error("Phase 9 added OnUpdate polling");
}
if (block.includes("InlinePublicChatLinkForMessage") || block.includes("ChatFrame_AddMessageEventFilter")) {
  throw new Error("Phase 9 modified chat-link or filter ownership");
}
if (block.includes("RefreshPublicGroups =") || block.includes("RefreshBrowse =")) {
  throw new Error("Phase 9 modified a renderer owner");
}

console.log("cache lifecycle source verification: PASS");
