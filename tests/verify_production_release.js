const fs = require("fs");
const path = require("path");

const root = process.cwd();
const addon = path.join(root, "SignalFire");
const tocText = fs.readFileSync(path.join(addon, "SignalFire.toc"), "utf8");
const tocFiles = tocText.split(/\r?\n/).map((line) => line.trim())
  .filter((line) => line && !line.startsWith("##"));
const luaFiles = fs.readdirSync(addon).filter((name) => name.endsWith(".lua")).sort();

function requireText(source, text, label) {
  if (!source.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText(tocText, "## Interface: 30300", "Wrath interface version");
requireText(tocText, "## Version: 1.5.3", "TOC version");
requireText(tocText, "## SavedVariables: BronzeLFG_DB", "SavedVariables declaration");
if (tocFiles.length !== 14) throw new Error(`expected 14 TOC files, got ${tocFiles.length}`);
if (JSON.stringify([...tocFiles].sort()) !== JSON.stringify(luaFiles)) {
  throw new Error("TOC and addon Lua file sets differ");
}
for (const file of tocFiles) {
  if (!fs.existsSync(path.join(addon, file))) throw new Error(`missing TOC file: ${file}`);
}

const combined = tocFiles.map((file) => fs.readFileSync(path.join(addon, file), "utf8")).join("\n");
const core = fs.readFileSync(path.join(addon, "SignalFireCore.lua"), "utf8");
const chat = fs.readFileSync(path.join(addon, "SignalFireChat.lua"), "utf8");
const network = fs.readFileSync(path.join(addon, "SignalFireNetwork.lua"), "utf8");
const diagnostics = fs.readFileSync(path.join(addon, "SignalFireDiagnostics.lua"), "utf8");
const workflow = fs.readFileSync(path.join(root, ".github/workflows/release.yml"), "utf8");

requireText(core, 'SignalFire_VERSION = "1.5.3"', "authoritative version");
requireText(core, 'SignalFire_RELEASE_CHANNEL = "stable"', "release channel");
requireText(core, 'SignalFire_RELEASE_NAME = "SignalFire 1.5.3"', "release name");
requireText(core, 'SignalFire_DEVELOPMENT_MILESTONE = "Guild and Group Link Coverage"', "development milestone");
requireText(core, 'return "SignalFire v" .. SignalFire_GetVersion()', "stable title composition");
requireText(chat, "options.inlineChatLinks = false", "safe Chat Links default");
requireText(chat, "options.inlineChatLinks ~= true and options.inlineChatLinks ~= false",
  "explicit Chat Links preference preservation");
requireText(diagnostics, "P.enabled = false", "performance diagnostics default");
requireText(diagnostics, "S.enabled = false", "stability diagnostics default");
requireText(diagnostics, "S.deep = false", "deep diagnostics default");
requireText(workflow, 'test "${#lua_files[@]}" -eq "${#toc_files[@]}"',
  "dynamic package file-count validation");

if (combined.includes("(Beta)") || combined.includes("SignalFire (Beta)")) {
  throw new Error("production addon still contains a Beta title");
}
for (const stale of ['or "1.4.23"', 'or "1.5.0"']) {
  if (combined.includes(stale)) throw new Error(`stale runtime version fallback remains: ${stale}`);
}
const testSayAssignments = [...combined.matchAll(/SignalFireTestSay\s*=\s*true/g)];
if (testSayAssignments.length !== 2
    || !chat.includes('if cmd == "testsay on" then')
    || !network.includes('elseif msg == "testsay on" then')) {
  throw new Error("test-say mode has an unexpected enable path");
}

console.log(`stable release source verification: PASS (${tocFiles.length} Lua files, version 1.5.3)`);
