const fs = require("fs");

const sourcePath = process.argv[2];
const targetPath = process.argv[3];
if (!sourcePath || !targetPath) throw new Error("source and target paths are required");
const source = fs.readFileSync(sourcePath, "utf8");
const marker = "assert(SignalFireParserRegression";
const end = source.indexOf(marker);
if (end < 0) throw new Error("parser harness loader boundary was not found");
fs.writeFileSync(targetPath, source.slice(0, end));

