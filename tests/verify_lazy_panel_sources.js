const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const toc = fs.readFileSync("SignalFire/SignalFire.toc", "utf8");
const start = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_BEGIN");
const end = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_END");
if (start < 0 || end < start) throw new Error("Phase 7 lazy-panel owner markers are missing");
const block = ui.slice(start, end);

for (const required of [
  'LP.generation = "1.5.1-perf-phase7"',
  "function LP:EnsureMainShell",
  "function LP:EnsurePanel",
  "function LP:MarkDirty",
  "function LP:HideBuiltPanels",
  "function B:SF151_GetLazyPanelDiagnostics",
  "function B:SF151_PrintLazyPanelDiagnostics",
  "function B:SF151_ResetLazyPanelStats",
]) {
  if (!block.includes(required)) throw new Error(`missing Phase 7 owner: ${required}`);
}

if (block.includes('SetScript("OnUpdate"')) throw new Error("Phase 7 introduced OnUpdate polling");
if (block.includes("GetChildren(")) throw new Error("Phase 7 introduced recursive/tree traversal");
if (!block.includes("LP.suppressFeatureBuilders")) throw new Error("legacy eager builders are not suppressed");
if (!block.includes("record.dependencies")) throw new Error("panel dependencies are not explicit");
if (!block.includes("self.maximumErrors")) throw new Error("panel error history is not bounded");

const luaFiles = toc.split(/\r?\n/).filter((line) => /\.lua\s*$/.test(line));
if (luaFiles.length !== 14) throw new Error(`TOC Lua load order changed: ${luaFiles.length} files`);

console.log("lazy panel source verification: PASS");

