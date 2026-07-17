const fs = require("fs");
const path = require("path");

const root = process.argv[2];
if (!root) throw new Error("repository root is required");

const read = (name) => fs.readFileSync(path.join(root, "SignalFire", name), "utf8");
const ui = read("SignalFireUI.lua");
const integration = read("SignalFireIntegration.lua");
const controls = read("SignalFireControls.lua");
const chat = read("SignalFireChat.lua");
const network = read("SignalFireNetwork.lua");

for (const marker of [
  "-- SIGNALFIRE_PHASE4_EVENT_TIMERS_BEGIN",
  "-- SIGNALFIRE_PHASE4_EVENT_TIMERS_END",
  'T.generation = "1.5.1-perf-phase4"',
  'B._sfPerfCorePulseFrame:SetScript("OnUpdate", nil)',
  'B._sfPerfNetworkPulseFrame:SetScript("OnUpdate", nil)',
  'B._sfPerfPresencePulseFrame:SetScript("OnUpdate", nil)',
  'function B:SF151_ScheduleDelayed',
  'function B:SF151_GetTimerDiagnostics',
]) {
  if (!ui.includes(marker)) throw new Error(`missing Phase 4 owner marker: ${marker}`);
}

if (!integration.includes('"startup.slash-final"')) throw new Error("slash finalizer did not move to the delayed scheduler");
if (!controls.includes('"startup.utility-controls"') || !controls.includes('"startup.slash-hash"')) {
  throw new Error("controls startup repair passes did not move to the delayed scheduler");
}
if (!chat.includes('"startup.slash-freeze"')) throw new Error("chat startup repair did not move to the delayed scheduler");
if (!network.includes('"startup.login-summary"')) throw new Error("Network login summary did not move to the delayed scheduler");

for (const obsolete of ["_sfUtilityFinalizerElapsed", "_sfHashRepairElapsed", "_sfSlashFreezeElapsed", "_sfLoginSummaryElapsed"]) {
  const combined = [integration, controls, chat, network].join("\n");
  if (combined.includes(obsolete)) throw new Error(`obsolete startup polling state remains: ${obsolete}`);
}

console.log("event timer source verification: PASS");
