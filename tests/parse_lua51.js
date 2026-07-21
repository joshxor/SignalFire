const fs = require("fs");
const luaparse = require("luaparse");

const files = process.argv.slice(2);
if (files.length === 0) throw new Error("at least one Lua file is required");

for (const file of files) {
  const source = fs.readFileSync(file, "utf8");
  try {
    luaparse.parse(source, { luaVersion: "5.1" });
  } catch (error) {
    throw new Error(`${file}: ${error.message}`);
  }
}

console.log(`Lua 5.1 parse: PASS (${files.length} files)`);
