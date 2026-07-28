const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const bronze = fs.readFileSync(path.join(root, "SignalFire", "BronzeLFG.lua"), "utf8");
const marketplace = fs.readFileSync(path.join(root, "SignalFire", "SignalFireMarketplace.lua"), "utf8");
const ui = fs.readFileSync(path.join(root, "SignalFire", "SignalFireMarketplaceUI.lua"), "utf8");

function need(source, text, label) {
  if (!source.includes(text)) {
    throw new Error(`Marketplace 1F source verification failed: missing ${label}`);
  }
}

function forbid(source, text, label) {
  if (source.includes(text)) {
    throw new Error(`Marketplace 1F source verification failed: forbidden ${label}`);
  }
}

function body(source, declaration) {
  const start = source.indexOf(declaration);
  if (start < 0) {
    throw new Error(`Marketplace 1F source verification failed: missing ${declaration}`);
  }
  const end = source.indexOf("\n    function ", start + declaration.length);
  return source.slice(start, end < 0 ? source.length : end);
}

need(bronze, "BLFG.LinkHandlers565 = BLFG.LinkHandlers565 or {}", "shared link-handler registry");
need(bronze, "function BLFG:RegisterLinkHandler(typeName, owner, callback)", "link-handler registration API");
need(bronze, "function BLFG:UnregisterLinkHandler(typeName, owner)", "link-handler removal API");
need(bronze, "if not entry or entry.owner ~= owner then", "owner-checked unregister");
need(bronze, "BLFG.KnownLinkHandlerTypes565 = BLFG.KnownLinkHandlerTypes565 or {signalfiremkt=true}", "bounded known link-type set");
need(bronze, 'string.match(link, "^([%a%d_]+):(.*)$")', "exact link-type parsing");
need(bronze, "BLFG_SetItemRef_Before565(link, text, button, chatFrame)", "prior SetItemRef delegation");

const setItemRefDefinitions = (bronze.match(/function SetItemRef\(/g) || []).length;
if (setItemRefDefinitions !== 3) {
  throw new Error(`Marketplace 1F source verification failed: expected the existing three SetItemRef definitions, found ${setItemRefDefinitions}`);
}
forbid(marketplace, "function SetItemRef(", "Marketplace-owned SetItemRef wrapper");
forbid(ui, "function SetItemRef(", "UI-owned SetItemRef wrapper");

need(marketplace, "M.maximumLocalLinkIdLength = 128", "local-link ID limit");
need(marketplace, "M.maximumLocalLinkLength = 320", "local-link total-length limit");
need(marketplace, "function M:ResolveLocalLink(id)", "constant-time resolver");
need(marketplace, "function M:BuildLocalLink(id)", "local-link builder");
need(marketplace, "function M:OpenWhisper(id)", "whisper action");
need(marketplace, "function M:HandleLocalLink(id)", "local-link click handler");
need(marketplace, "function M:RegisterLocalLinkHandler()", "handler registration lifecycle");
need(marketplace, "function M:UnregisterLocalLinkHandler()", "handler removal lifecycle");

const resolver = body(marketplace, "function M:ResolveLocalLink(id)");
need(resolver, "runtime.byId[id]", "by-ID resolver lookup");
need(resolver, "row.id ~= id", "resolver ID integrity check");
need(resolver, "row.profile ~= runtime.profile", "resolver profile integrity check");
need(resolver, "tonumber(row.expiresAt or 0) <= mkt_epoch()", "resolver expiration check");
forbid(resolver, "listingOrder", "resolver listing-order scan");
forbid(resolver, "pairs(", "resolver table scan");
forbid(resolver, "ipairs(", "resolver array scan");

const builder = body(marketplace, "function M:BuildLocalLink(id)");
need(builder, "|Hsignalfiremkt:", "SignalFire Marketplace hyperlink type");
need(builder, ':gsub("[%c|%[%]]", "")', "sanitized display label");
need(builder, 'row.profession or ""):gsub("[%c|%[%]]", ""), 48)', "profession display bound");
need(builder, 'row.itemName or ""):gsub("[%c|%[%]]", ""), 96)', "item display bound");
need(builder, "mkt_text(profession .. \": \" .. item, 120)", "title display bound");
need(builder, "self.maximumLocalLinkLength", "final local-link bound");

const whisper = body(marketplace, "function M:OpenWhisper(id)");
need(whisper, "ChatFrame_SendTell", "preferred whisper composer API");
need(whisper, "ChatFrame_OpenChat", "whisper composer fallback API");
need(whisper, "ChatEdit_ActivateChat", "legacy whisper composer fallback API");
need(whisper, "row.ownerKey == self:GetCurrentOwnerKey()", "self-whisper rejection");
forbid(whisper, "SendChatMessage", "automatic whisper transmission");

const enable = body(marketplace, "function M:Enable(profile)");
need(enable, "self:RegisterLocalLinkHandler()", "Enable-time handler registration");
need(enable, 'self:Disable("profile-change")', "profile-change teardown before registration");
const disable = body(marketplace, "function M:Disable(reason)");
need(disable, "self:UnregisterLocalLinkHandler()", "Disable-time handler removal");

const controls = [
  "detailWhisper",
  "detailFavorite",
  "detailLink",
  "myDetailLink",
  "favoriteWhisper",
  "favoriteLink",
];
for (const control of controls) {
  need(ui, `self.${control}`, `${control} control`);
  need(ui, `self.${control}:SetScript("OnClick"`, `${control} click handler`);
  need(ui, `self.${control}:SetScript("OnClick", nil)`, `${control} lifecycle cleanup`);
}
if (66 + new Set(controls).size !== 72) {
  throw new Error("Marketplace 1F source verification failed: enabled script-count delta is not six");
}

need(ui, "function U:WhisperListing(id)", "UI whisper helper");
need(ui, "function U:ToggleBrowseFavorite()", "Browse favorite toggle");
need(ui, "function U:GenerateLocalLink(id)", "UI link-generation helper");
need(ui, "function U:OpenExactListing(id)", "exact-listing navigation helper");
need(ui, 'self:SetTab("Browse")', "Browse-tab exact-link navigation");
need(ui, "self.selectedListingId=row.id", "exact listing selection");
need(ui, "self.favoriteWhisper:Hide(); self.favoriteLink:Hide()", "unavailable Favorite action hiding");

forbid(marketplace, "SendChatMessage(", "Marketplace automatic message transmission");
forbid(ui, "SendChatMessage(", "Marketplace UI automatic message transmission");
forbid(marketplace, "OnUpdate", "Marketplace local-action polling");
forbid(ui, "OnUpdate", "Marketplace UI local-action polling");
forbid(marketplace, "ChatFrame_AddMessageEventFilter", "Marketplace chat filter");
forbid(ui, "ChatFrame_AddMessageEventFilter", "Marketplace UI chat filter");
forbid(marketplace, "SendAddonMessage", "Marketplace addon-message networking");
forbid(ui, "SendAddonMessage", "Marketplace UI addon-message networking");
forbid(marketplace, "BLFG312", "Marketplace network packet");
forbid(ui, "BLFG312", "Marketplace UI network packet");
forbid(marketplace, "C_Timer.NewTicker", "Marketplace repeating timer");
forbid(ui, "C_Timer.NewTicker", "Marketplace UI repeating timer");

const countHarnesses = [
  "marketplace_browse_type_profession_filters_harness.lua",
  "marketplace_browse_location_availability_filters_harness.lua",
  "marketplace_browse_favorites_clear_filters_harness.lua",
  "marketplace_phase1b_lazy_ui_harness.lua",
];
for (const file of countHarnesses) {
  const source = fs.readFileSync(path.join(root, "tests", file), "utf8");
  if (source.includes("ActiveScriptCount() == 66")) {
    throw new Error(`Marketplace 1F source verification failed: stale enabled script count remains in ${file}`);
  }
}

console.log("marketplace phase1f source verification: PASS");
