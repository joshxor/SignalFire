const fs = require("fs");
const chat = fs.readFileSync("SignalFire/SignalFireChat.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const bronze = fs.readFileSync("SignalFire/BronzeLFG.lua", "utf8");
const harness = fs.readFileSync("tests/activity_discovery_pass_b_harness.lua", "utf8");
const workflow = fs.readFileSync(".github/workflows/release.yml", "utf8");

const need = (source, value, label) => {
  if (!source.includes(value)) throw new Error(`activity discovery Pass B source verification failed: ${label}`);
};

need(chat, "local function sffcl_xp_aura_signal", "authoritative XP Aura detector");
need(chat, "SignalFireFastChatLinks.DetectXPAura", "shared parser detector export");
need(chat, "result.xpAura = sffcl_xp_aura_signal(raw) and true or false", "parser XP Aura metadata");
need(chat, "row.xpAura = sffcl_xp_aura_signal(raw) and true or false", "legacy fast-row XP Aura metadata");
need(chat, "parsed.xpAura = discovery.xpAura and true or false", "discovery metadata propagation");
for (const phrase of ["xp aura", "exp aura", "experience aura", "aura of experience", "aura spam",
  "with aura", "have aura", "has aura", "got aura", "aura xp", "aura exp"]) {
  need(chat, phrase, `XP Aura phrase ${phrase}`);
}
for (const phrase of ["no xp aura", "without xp aura", "no aura", "paladin aura", "paladin with aura",
  "devotion aura", "resistance aura", "aura mastery"]) {
  need(chat, phrase, `XP Aura false-positive guard ${phrase}`);
}
const auraStart = chat.indexOf("local function sffcl_xp_aura_signal");
const auraEnd = chat.indexOf("SignalFireFastChatLinks.DetectXPAura", auraStart);
const auraDetector = chat.slice(auraStart, auraEnd);
if (auraStart < 0 || auraEnd < 0 || !auraDetector.includes("local shorthand")
  || !auraDetector.includes("if intent or (need and (role or activity))")
  || /if shorthand then return true/.test(auraDetector)) {
  throw new Error("activity discovery Pass B source verification failed: bounded shorthand detector gate missing");
}

need(ui, "row.xpAura = parsed.xpAura == true", "canonical row XP Aura ownership");
need(ui, "xpAura=row.xpAura == true", "snapshot XP Aura normalization");
need(ui, "local xpAura = SignalFireFastChatLinks and SignalFireFastChatLinks.DetectXPAura", "final candidate gate XP Aura detector reuse");
need(ui, "local xpAuraContext = role or activity", "bounded XP Aura candidate context");
need(ui, "or (xpAura and xpAuraContext)", "XP Aura candidate gate admission");
need(ui, "local function p3_generic_activity", "generic activity title guard");
need(ui, 'local title = xpAuraTitle and "XP Aura"', "generic XP Aura link title");
need(ui, 'row.xpAura == true and not xpAuraTitle', "specific XP Aura title suffix guard");
need(ui, '" - XP Aura"', "specific XP Aura title suffix");
need(ui, 'local xpAura = tostring(B.publicXPAuraFilter or "All Listings")', "XP Aura filter state");
need(ui, 'if xpAura == "All XP Aura" then xpAura = "All Listings" end', "legacy XP Aura filter migration");
need(ui, "local function p6_xp_aura_matches", "Public Groups XP Aura filter owner");
need(ui, 'if filter == "XP Aura Only"', "positive-only filter semantics");
need(ui, "counts.XPAura", "snapshot XP Aura count");
need(ui, "publicXPAuraButton", "additive XP Aura button owner");
need(ui, '"XP Aura ("', "XP Aura button count label");
need(ui, "local function p6_update_xp_aura_button", "shared XP Aura button state helper");
need(ui, 'if createdAuraButton then auraButton:SetText("XP Aura (0)") end', "first-creation-only XP Aura fallback");
need(ui, "local searchTokens = {}", "multi-token search owner");
need(ui, "auraSearch", "XP Aura search corpus");
need(ui, "keySearch", "numeric key search corpus");
need(ui, "PG.AttachPanel = p6_attach_panel", "Phase 6 attachment owner");
need(ui, '"_sfP6XPAuraButton"', "idempotent XP Aura button owner");
need(ui, 'auraButton:SetPoint("TOPLEFT", auraAnchor, "TOPRIGHT", 12, 0)', "relative XP Aura button anchor");
need(ui, 'search:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -87)', "Search row layout owner");
need(ui, 'searchLabel:SetPoint("BOTTOM", search, "TOP", 0, 4)', "centered Search label anchor");
need(ui, 'searchLabel:SetJustifyH("CENTER")', "centered Search label alignment");
need(ui, 'B.publicSearchLabel', "inherited Search label ownership");
need(ui, "p7_reconcile_public_groups", "Phase 7 Public Groups reconciliation");
need(ui, "RegisterKnownDropdowns", "standard dropdown lifecycle registration");
need(ui, "difficulty, xpAura},", "XP Aura filter participates in view signature");
need(ui, '"XP Aura Only"', "XP Aura filter option");
need(ui, '"All Listings"', "unrestricted XP Aura filter option");
if ((ui.match(/auraButton:SetText\("XP Aura \(0\)"\)/g) || []).length !== 1) {
  throw new Error("activity discovery Pass B source verification failed: XP Aura zero fallback was not creation-only");
}
if (/\{"All XP Aura",\s*"XP Aura Only"\}/.test(ui)) {
  throw new Error("activity discovery Pass B source verification failed: obsolete XP Aura option remained");
}
for (const obsolete of ["_sfP6XPAuraDrop", "SignalFirePublicXPAuraDrop", "publicXPAuraDrop", "publicXPAuraLabel"]) {
  if (ui.includes(obsolete)) {
    throw new Error(`activity discovery Pass B source verification failed: dedicated XP Aura dropdown remained (${obsolete})`);
  }
}
need(bronze, "self.publicSearchLabel = font(p, \"Search\"", "base Search label owner");
need(ui, "frame:SetScript(\"OnUpdate\", nil)", "idle parser worker shutdown");

if (/row\.key\s*=\s*parsed\.key(?:Level|level)?\b/.test(ui)) {
  throw new Error("activity discovery Pass B source verification failed: row.key identity was overloaded");
}
if (/p\[27\]|p\[28\]/.test(chat + ui)) {
  throw new Error("activity discovery Pass B source verification failed: LIST packet expanded past p[26]");
}
const phase6Start = ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_BEGIN");
const phase6End = ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_END", phase6Start);
const attachStart = ui.indexOf("local function p6_attach_panel", phase6Start);
const attachEnd = ui.indexOf("PG.AttachPanel = p6_attach_panel", attachStart);
if (phase6Start < 0 || phase6End < 0 || attachStart < 0 || attachEnd < 0 || attachEnd > phase6End) {
  throw new Error("activity discovery Pass B source verification failed: Phase 6 attachment boundary");
}
const attach = ui.slice(attachStart, attachEnd);
if (attach.indexOf('"_sfP6XPAuraButton"') > attach.indexOf('field(panel, "_sfP6ViewHooks") == true')) {
  throw new Error("activity discovery Pass B source verification failed: control repair is behind the hook guard");
}
const phase7Start = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_BEGIN");
const phase7End = ui.indexOf("-- SIGNALFIRE_PHASE7_LAZY_PANELS_END", phase7Start);
if (phase7Start < 0 || phase7End < 0) throw new Error("activity discovery Pass B source verification failed: Phase 7 boundary");
const phase7 = ui.slice(phase7Start, phase7End);
if ((phase7.match(/p7_reconcile_public_groups\(B\)/g) || []).length < 2) {
  throw new Error("activity discovery Pass B source verification failed: lazy reuse/build reconciliation missing");
}

for (const fixture of [
  "positive XP Aura fixture", "false-positive XP Aura fixture", "XP Aura Only", "multi-token search",
  "filtered-out selected row", "for _ = 1, 20 do", "no chat or channel side effects", "XP Aura button",
  "DPS with aura LFG", "58 Necro DPS with aura LF UBRS/LBRS xp runs", "lfm rfc | tank have aura",
]) need(harness, fixture === "positive XP Aura fixture" ? "positive = {" : fixture === "false-positive XP Aura fixture" ? "local negative = {" : fixture === "XP Aura Only" ? 'auraClick(auraButton)' : fixture === "multi-token search" ? "bfd mythic healer" : fixture === "filtered-out selected row" ? "filtered-out selected row did not clear" : fixture === "for _ = 1, 20 do" ? "for _ = 1, 20 do" : fixture === "no chat or channel side effects" ? "sentChat == sentBeforeFilter" : fixture === "XP Aura button" ? "publicXPAuraButton" : fixture, fixture);
need(harness, "All Listings", "unrestricted XP Aura harness state");
need(harness, "All XP Aura", "legacy XP Aura harness migration");
need(harness, "|Hbronzelfgpub:", "generic XP Aura hyperlink protocol");
need(harness, "[XP Aura]", "generic XP Aura hyperlink title");
need(harness, "runtime.Candidate(auraLinkText)", "final candidate gate regression");
need(harness, "inlineChatLinks = false", "chat links disabled regression");
need(workflow, "verify_activity_discovery_pass_b_sources.js", "workflow Pass B source verifier");
need(workflow, "activity_discovery_pass_b_harness.lua", "workflow Pass B harness");
need(workflow, "activity_discovery_pass_a_harness.lua", "Pass A harness retained");

if (/B\._sfP3Frame:SetScript\(\s*["']OnUpdate["']\s*,\s*function/.test(ui)) {
  throw new Error("activity discovery Pass B source verification failed: permanent Public Groups parser OnUpdate function");
}

console.log("activity discovery pass B source verification: PASS");
