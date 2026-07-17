const fs = require("fs");

const sourcePath = process.argv[2];
const targetPath = process.argv[3];
if (!sourcePath || !targetPath) throw new Error("source and target paths are required");

const source = fs.readFileSync(sourcePath, "utf8");
const startMarker = "-- SIGNALFIRE_PHASE3_NETWORK_ROSTER_BEGIN";
const endMarker = "-- SIGNALFIRE_PHASE3_NETWORK_ROSTER_END";
const start = source.indexOf(startMarker);
const end = source.indexOf(endMarker);
if (start < 0 || end < 0 || end <= start) throw new Error("Phase 3 roster markers were not found");

const block = source.slice(start + startMarker.length, end)
  .replace(/(^|[^\\])\\(?![abfnrtv\\"'\n\r0-9xz])/g, (_, prefix) => `${prefix}\\\\`);
fs.writeFileSync(targetPath, block);
