const fs = require("fs");
const path = require("path");

const source = process.argv[2];
const target = process.argv[3];
if (!source || !target) throw new Error("source and target directories are required");

fs.rmSync(target, { recursive: true, force: true });
fs.mkdirSync(target, { recursive: true });

for (const file of fs.readdirSync(source).filter((name) => name.endsWith(".lua"))) {
  let text = fs.readFileSync(path.join(source, file), "utf8");
  // WoW's Lua 5.1 accepts legacy interface paths containing single backslashes.
  // Fengari follows newer Lua escape rules, so duplicate only unknown escapes in
  // the disposable runtime-test copy. The checked-in addon source is untouched.
  text = text.replace(/(^|[^\\])\\(?![abfnrtv\\"'\n\r0-9xz])/g,
    (_, prefix) => `${prefix}\\\\`);
  fs.writeFileSync(path.join(target, file), text);
}
