const fs = require("fs");

const diagnostics = fs.readFileSync("SignalFire/SignalFireDiagnostics.lua", "utf8");
const start = diagnostics.indexOf("-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_BEGIN");
const end = diagnostics.indexOf("-- SIGNALFIRE_PHASE9_CACHE_LIFECYCLE_END");
if (start < 0 || end <= start) throw new Error("Phase 9 cache lifecycle markers are missing");
const block = diagnostics.slice(start, end);

for (const required of [
  'CL.generation = "1.5.2-phase12a"',
  "CL.minimumAutomaticInterval = 30",
  "function CL:MaybeRun(reason)",
  "function CL:Run(reason, force)",
  "SF151_RunCacheMaintenance",
  "SF151_GetCacheLifecycleDiagnostics",
  "SF151_GetCacheLifecycleInventory",
  "SF151_ResetCacheLifecycleStats",
  "CL.eventFrame = nil",
]) {
  if (!block.includes(required)) throw new Error(`missing Phase 9 source contract: ${required}`);
}

if (/SetScript\s*\(\s*["']OnUpdate["']/.test(block)) {
  throw new Error("Phase 9 added OnUpdate polling");
}
if (block.includes("InlinePublicChatLinkForMessage") || block.includes("ChatFrame_AddMessageEventFilter")) {
  throw new Error("Phase 9 modified chat-link or filter ownership");
}
for (const forbidden of [
  'RegisterEvent("CHAT_MSG_CHANNEL")',
  'RegisterEvent("CHAT_MSG_SAY")',
  'RegisterEvent("CHAT_MSG_YELL")',
  'self.chatEvents % self.chatInterval',
  'CL:Run("chat-checkpoint")',
]) {
  if (block.includes(forbidden)) throw new Error(`Phase 12A retained chat maintenance ownership: ${forbidden}`);
}
if (!block.includes('pcall(CL.MaybeRun, CL, reason or "slow-maintenance")')) {
  throw new Error("slow maintenance does not use the automatic lifecycle gate");
}
if (!block.includes('CL:Run("slash", true)')) {
  throw new Error("manual cleanup is not forced");
}
if (block.includes("RefreshPublicGroups =") || block.includes("RefreshBrowse =")) {
  throw new Error("Phase 9 modified a renderer owner");
}

console.log("cache lifecycle source verification: PASS");
