const fs = require("fs");

const sourcePath = process.argv[2];
const targetPath = process.argv[3];
if (!sourcePath || !targetPath) throw new Error("source and target paths are required");

const source = fs.readFileSync(sourcePath, "utf8");
const startMarker = "-- SIGNALFIRE_PHASE7_LAZY_PANELS_BEGIN";
const endMarker = "-- SIGNALFIRE_PHASE7_LAZY_PANELS_END";
const start = source.indexOf(startMarker);
const end = source.indexOf(endMarker);
if (start < 0 || end < start) throw new Error("Phase 7 lazy-panel block was not found");

fs.writeFileSync(targetPath, source.slice(start, end + endMarker.length) + "\n");

