const fs = require("fs");
const path = require("path");

const root = process.argv[2] || process.cwd();
const addon = path.join(root, "SignalFire");
const toc = fs.readFileSync(path.join(addon, "SignalFire.toc"), "utf8");
const chat = fs.readFileSync(path.join(addon, "SignalFireChat.lua"), "utf8");
const core = fs.readFileSync(path.join(addon, "SignalFireMarketplace.lua"), "utf8");
const lazy = fs.readFileSync(path.join(addon, "SignalFireUI.lua"), "utf8");
const ui = fs.readFileSync(path.join(addon, "SignalFireMarketplaceUI.lua"), "utf8");

function requireText(source, text, message) {
  if (!source.includes(text)) throw new Error(message || `missing ${text}`);
}

const files = toc.split(/\r?\n/).map((line) => line.trim()).filter((line) => line && !line.startsWith("##"));
const marketplace = files.indexOf("SignalFireMarketplace.lua");
const marketplaceUI = files.indexOf("SignalFireMarketplaceUI.lua");
const diagnostics = files.indexOf("SignalFireDiagnostics.lua");
if (!(marketplace >= 0 && marketplaceUI === marketplace + 1 && diagnostics === marketplaceUI + 1)) {
  throw new Error("Marketplace UI TOC placement is incorrect");
}

requireText(lazy, "function LP:RegisterPanel", "dynamic lazy registration is missing");
requireText(lazy, "function LP:UnregisterPanel", "dynamic lazy unregistration is missing");
requireText(chat, 'sfmm_enabled("tradeskillMarketplace")', "final sidebar owner is not module-aware");
requireText(chat, '{"Marketplace", "Crafting offers and requests"', "Marketplace sidebar item is missing");
requireText(core, 'if self.SFMarketplaceOpen then return self:SFMarketplaceOpen("slash") end',
  "existing slash dispatcher does not open Marketplace");
requireText(core, "panel=panel", "Marketplace status does not report panel state");

for (const tab of ["Browse", "My Listings", "Create Listing", "Favorites"]) {
  requireText(ui, `"${tab}"`, `missing ${tab} navigation tab`);
}
for (const required of ["U:Build", "U:Register", "U:Unregister", "U:Enable", "U:Disable",
  "U:Open", "U:GetPanelState", "U:IsDisabledClean"]) requireText(ui, required);

for (const forbidden of [
  'SetScript("OnUpdate"', "RegisterEvent(", "ChatFrame_", "SendAddonMessage",
  "SetItemRef", "InlinePublicChatLinkForMessage", "SF151_ScheduleDelayed",
  "SF151_CancelDelayed", "listingsById", "CreateEditBox", "FauxScrollFrame",
]) {
  if (ui.includes(forbidden)) throw new Error(`Phase 1B contains forbidden ownership: ${forbidden}`);
}

console.log("marketplace phase1b source verification: PASS");
