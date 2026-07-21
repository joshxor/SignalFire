const fs = require("fs");

const roster = fs.readFileSync("SignalFire/SignalFireRoster.lua", "utf8");
const network = fs.readFileSync("SignalFire/SignalFireNetwork.lua", "utf8");
const community = fs.readFileSync("SignalFire/SignalFireCommunity.lua", "utf8");
const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");

if (/r:SetScript\("OnLeave", function\(row\)\s+if BLFG\.RefreshOnlinePanel/.test(roster)) {
  throw new Error("Full Roster OnLeave still refreshes the roster");
}
if (!/SIGNALFIRE_PHASE3_NETWORK_ROSTER_BEGIN/.test(ui)
    || !/function B:GetOnlineUserRows\(\)/.test(ui)
    || !/function B:SFRP_GetRosterRows\(\)/.test(ui)) {
  throw new Error("final Phase 3 roster owners are missing");
}
if (/local byName = \{\}\s+for _, u in ipairs\(rows\)/.test(network)) {
  throw new Error("Network renderer still rebuilds its status merge map");
}
if (/local function sfam_compiled_online_rows\(self\)[\s\S]*?table\.sort\(rows/.test(network)) {
  throw new Error("Beacon compiler still sorts a second roster");
}
if (/local SFE_OldRefreshSFNetwork[\s\S]*?function BLFG:RefreshSFNetwork[\s\S]*?SFE_RefreshEventBoard/.test(community)) {
  throw new Error("Network refresh still rebuilds the Event Board");
}
if (!/local function sfe_refresh_active_event_view\(\)/.test(community)
    || !/if row then sfe_refresh_active_event_view\(\) end/.test(community)) {
  throw new Error("Event packets do not refresh their active view directly");
}

console.log("network roster source checks: PASS");
