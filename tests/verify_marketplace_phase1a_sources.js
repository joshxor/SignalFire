const fs = require("fs");
const path = require("path");

const root = process.argv[2] || process.cwd();
const addon = path.join(root, "SignalFire");
const marketplacePath = path.join(addon, "SignalFireMarketplace.lua");
const marketplace = fs.readFileSync(marketplacePath, "utf8");
const toc = fs.readFileSync(path.join(addon, "SignalFire.toc"), "utf8");
const runtime = fs.readFileSync(path.join(addon, "SignalFireRuntime.lua"), "utf8");
const chat = fs.readFileSync(path.join(addon, "SignalFireChat.lua"), "utf8");
const diagnostics = fs.readFileSync(path.join(addon, "SignalFireDiagnostics.lua"), "utf8");

function requireText(source, text, message) {
  if (!source.includes(text)) throw new Error(message || `missing ${text}`);
}

requireText(runtime, 'key = "tradeskillMarketplace"', "Marketplace module is not registered");
requireText(runtime, "modules.tradeskillMarketplace = false", "Marketplace profile defaults are not Off");
requireText(runtime, 'marketplace:Reconcile("modules-apply")', "module application does not reconcile Marketplace");
requireText(chat, 'key="tradeskillMarketplace"', "final module owner does not register Marketplace");
requireText(chat, 'defaults={Triumvirate=false, Ascension=false}', "final module owner defaults are not Off");
requireText(chat, 'SignalFireMarketplace151:Reconcile("modules-apply")', "final module owner does not reconcile Marketplace");
requireText(diagnostics, "SFMarketplaceHandleSlash", "final slash dispatcher does not route Marketplace commands");

const lines = toc.split(/\r?\n/).filter(Boolean);
const uiIndex = lines.indexOf("SignalFireUI.lua");
const marketplaceIndex = lines.indexOf("SignalFireMarketplace.lua");
const diagnosticsIndex = lines.indexOf("SignalFireDiagnostics.lua");
if (!(uiIndex >= 0 && marketplaceIndex === uiIndex + 1 && diagnosticsIndex === marketplaceIndex + 1)) {
  throw new Error("Marketplace TOC placement is incorrect");
}

for (const forbidden of [
  "CreateFrame(",
  "ChatFrame_AddMessageEventFilter",
  "ChatFrame_RemoveMessageEventFilter",
  'SetScript("OnUpdate"',
  "SendAddonMessage",
  "SetItemRef",
  "InlinePublicChatLinkForMessage",
  "|Hsignalfiremkt:",
]) {
  if (marketplace.includes(forbidden)) throw new Error(`Phase 1A contains forbidden owner: ${forbidden}`);
}

if (fs.existsSync(path.join(addon, "SignalFireMarketplaceUI.lua"))) {
  throw new Error("Phase 1A must not create SignalFireMarketplaceUI.lua");
}

for (const required of [
  "M:MigrateProfile",
  "M:NormalizeListing",
  "M:CreateListing",
  "M:GetListing",
  "M:EditListing",
  "M:RemoveListing",
  "M:RebuildIndexes",
  "M:SetFavorite",
  "M:ScheduleExpiration",
  "M:Enable",
  "M:Disable",
  "M:GetStatus",
]) requireText(marketplace, required);

console.log("marketplace phase1a source verification: PASS");
