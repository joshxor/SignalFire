const fs = require("fs");

const read = (name) => fs.readFileSync(name, "utf8");
const listing = read("SignalFire/SignalFireListing.lua");
const bronze = read("SignalFire/BronzeLFG.lua");
const community = read("SignalFire/SignalFireCommunity.lua");
const ui = read("SignalFire/SignalFireUI.lua");
const marketplace = read("SignalFire/SignalFireMarketplace.lua");
const marketplaceNetwork = read("SignalFire/SignalFireMarketplaceNetwork.lua");
const toc = read("SignalFire/SignalFire.toc");
const fail = (message) => { throw new Error(`listing broadcast UX source verification failed: ${message}`); };
const requireText = (source, text, label) => { if (!source.includes(text)) fail(label || text); };
const count = (source, pattern) => (source.match(pattern) || []).length;
const slice = (source, startText, endText) => {
  const start = source.indexOf(startText);
  const end = source.indexOf(endText, start + startText.length);
  if (start < 0 || end < 0) fail(`missing source boundary ${startText}`);
  return source.slice(start, end);
};

const marker = "-- Listing and public-broadcast UX.";
const feature = listing.slice(listing.indexOf(marker));
if (!feature.startsWith(marker)) fail("authoritative feature block missing");

const owners = [
  "SFListingBroadcastState", "SFDiscoverPublicChannels", "SFSetPublicBroadcastChannels",
  "SFGetPublicBroadcastChannels", "SFResolvePublicBroadcastDestinations",
  "SFSendPublicBroadcast", "SFRoleCounts", "SFNormalizeListingRoles", "SFRolePhrase",
  "SFLevelRange", "SFExpandRecruitmentTemplate", "SFRefreshPublicBroadcastSummary",
  "SFOpenPublicBroadcastSelector", "SFEnsureListingBroadcastControls", "PostMyListingToChat",
];
for (const owner of owners) {
  const matches = count(feature, new RegExp(`function B:${owner}\\(`, "g"));
  if (matches !== 1) fail(`${owner} owner count is ${matches}`);
}
if (count(feature, /function B:ShowCreate\(/g) !== 1) fail("feature ShowCreate wrapper count");
if (count(feature, /function B:CreateListing\(/g) !== 1) fail("feature CreateListing wrapper count");
if (listing.slice(0, listing.indexOf(marker)).includes("if B and B.SFSendPublicBroadcast then")) {
  fail("pre-definition SFSendPublicBroadcast guard remains");
}
if (listing.includes('s[{"tankCount","healerCount","supportCount","dpsCount"}[i]]')) {
  fail("Lua 5.1-invalid table constructor indexing remains");
}

requireText(feature, "local raw = { GetChannelList() }", "all GetChannelList returns are not captured");
requireText(feature, "for offset = 1, 2 do", "pair/triplet-safe channel discovery");
requireText(feature, 'normalized ~= "blfg"', "BLFG exclusion");
requireText(feature, "sanitizeChannels", "bounded name deduplication");
requireText(feature, "#out < MAX_CHANNELS", "bounded selected destinations");
if (count(feature, /local function joinedChannelEntries\(\)/g) !== 1) fail("joined-channel entry owner count");
requireText(feature, "{id=raw[i], name=name, key=normalized}", "discovery does not retain live ID/name/key entries");
requireText(feature, "local entries, byKey = joinedChannelEntries(), {}", "send does not rescan current joined entries");
requireText(feature, "SendChatMessage(text, \"CHANNEL\", nil, destination.id)", "public send does not use discovered live numeric ID");
if (/GetChannelName\s*\(/.test(feature)) fail("GetChannelName remains an authoritative public send resolver");
requireText(feature, "local candidates = self:SFDiscoverPublicChannels()", "selector does not use current joined-channel discovery");
requireText(feature, "s.channels = pruneChannels(s.channels, candidates)", "selector does not prune unavailable selections");
requireText(feature, "s.channels = pruneChannels(channels, self:SFDiscoverPublicChannels())", "saved selection is not constrained to joined channels");
requireText(feature, 'oldKey == "global-guild-recruitment"', "profile-safe Global-Guild-Recruitment migration missing");
requireText(feature, 'eligible = id == "Triumvirate"', "Global-Guild-Recruitment migration is not Triumvirate-only");
requireText(feature, 'oldKey == "ascension"', "profile-safe Ascension migration missing");
requireText(feature, "for _, joined in ipairs(joinedChannelEntries())", "legacy migration does not verify currently joined channels");
if (feature.includes("(unavailable)")) fail("unavailable selector rows remain");
if (feature.includes("JoinChannelByName")) fail("public selector joins channels");

const creator = slice(bronze, "local function blfgCreatorPostToChat", "\nfunction BLFG:PublishRecruitmentListing");
const invasion = slice(bronze, "function BLFG:PostInvasionToChat()", "\nfunction BLFG:ClearInvasionData");
const recruitmentSend = slice(community, "function BLFG:SF139_SendRecruitmentBroadcast()", "\n    function BLFG:SF139_SaveRecruitmentTemplate");
for (const [name, source] of [["creator", creator], ["invasion", invasion], ["recruitment", recruitmentSend]]) {
  requireText(source, "SFSendPublicBroadcast", `${name} does not use shared public owner`);
  if (/GetChannelName|JoinChannelByName|["']global["']/i.test(source)) fail(`${name} retains a user-facing channel fallback`);
}
requireText(bronze, 'local CHANNEL = "BLFG"', "internal BLFG channel changed");
requireText(bronze, "local function sendChan(payload)", "internal LIST transport owner changed");
requireText(bronze, "JoinChannelByName(CHANNEL)", "internal BLFG join behavior changed");

const createOwner = slice(feature, "local oldCreate = B.CreateListing", "\n  end\nend");
requireText(createOwner, "local s = saveControls(self)", "normalization does not precede legacy CreateListing");
if (createOwner.indexOf("local s = saveControls(self)") > createOwner.indexOf("oldCreate(self")) fail("normalization occurs after serialization");
requireText(createOwner, "Minimum level cannot be higher than maximum level", "reversed level validation");
requireText(createOwner, "self:SFSendPublicBroadcast(self:ListingRecruitmentText(self.myListing))", "Create & Broadcast public send");

const packetOrder = [
  "clean(l.needTank), clean(l.needHealer), clean(l.needDPS)",
  "clean(l.voice), clean(l.loot), clean(l.note), clean(l.created)",
  "clean(l.tankCount", "clean(l.healerCount", "clean(l.dpsCount",
  "clean(l.supportCount", "clean(l.minLevel", "clean(l.maxLevel",
];
let packetCursor = -1;
for (const field of packetOrder) {
  const next = bronze.indexOf(field, packetCursor + 1);
  if (next < 0 || next < packetCursor) fail(`LIST packet field order: ${field}`);
  packetCursor = next;
}
for (const text of [
  "id=p[3], leader=p[4], class=p[5], classFile=p[6]",
  "type=p[7], activity=p[8], difficulty=p[9], key=p[10]",
  "minItemLevel=p[11], members=tonumber(p[12]) or 1",
  "maxMembers=tonumber(p[13]) or 5",
  "needTank=p[14], needHealer=p[15], needDPS=p[16]",
  "voice=p[17], loot=p[18], note=p[19]",
  "created=tonumber(p[20]) or now()",
  "tankCount=tonumber(p[21])", "healerCount=tonumber(p[22])",
  "dpsCount=tonumber(p[23])", "supportCount=tonumber(p[24])",
  "minLevel=tonumber(p[25])", "maxLevel=tonumber(p[26])",
]) requireText(bronze, text, `LIST parser contract ${text}`);
requireText(bronze, "BLFG:SFNormalizeListingRoles(listing)", "received optional fields are not normalized");

for (const text of [
  "BronzeLFG_DB.createByProfile", "legacyCount(legacy.needTank)",
  "legacyCount(legacy.needHealer)", "legacyCount(legacy.needDPS)",
  "s.supportCount = 0", "s.rolesMigrated = true",
  "listingBroadcastMigration.legacyChannelProfile",
]) requireText(feature, text, `migration ${text}`);
requireText(feature, "local oldSetServerProfile = B.SF143_SetServerProfile", "profile switch owner");
requireText(feature, "saveControls(self)", "profile UI save");
requireText(feature, "loadControls(self)", "profile UI load");
requireText(feature, '"InputBoxTemplate"', "visible input styling");
requireText(feature, 'legacy:EnableMouse(false)', "hidden legacy controls remain clickable");

requireText(feature, "function B:SFAM_UpdateCreatePreview", "posting preview integration");
requireText(feature, "self:ListingRecruitmentText(self:SFListingDraft())", "preview does not use public wording");
requireText(bronze, "msg = self:SFExpandRecruitmentTemplate(msg, listing)", "legacy Recruitment Creator template expansion");
requireText(community, "msg = self:SFExpandRecruitmentTemplate(msg, listing)", "active Recruitment Creator template expansion");
requireText(feature, 'values[k] ~= nil and values[k] or "{" .. k .. "}"', "unknown template variable behavior");

for (const text of [
  "row.supportCount", "row.levelRange", "row.roles = string.gsub(self:SFRolePhrase",
]) requireText(feature, text, `Public Groups mirror ${text}`);
requireText(ui, 'p8_role_letter("Support")', "compact Support display");
requireText(ui, "B:SFRolePhrase(listing)", "full count display");
requireText(ui, '"\\n|cffffcc00Level Req:|r " .. record.levelRange', "listing detail level range");

const dungeonOpen = slice(listing, "local function sfalp1430j_open", "\n      local function sfalp1430j_create_selector");
requireText(dungeonOpen, "BLFG.publicBroadcastPopup", "dungeon popup does not close public selector");
const selectorOpen = slice(feature, "function B:SFOpenPublicBroadcastSelector()", "\n    function B:SFEnsureListingBroadcastControls");
requireText(selectorOpen, "CloseDropDownMenus", "public selector does not close native Create Listing menus");
requireText(selectorOpen, "SignalFireAscensionListingPolish", "public selector does not close custom dungeon popup");
requireText(selectorOpen, 'popup:SetFrameStrata("DIALOG")', "public selector lacks dialog strata");
requireText(selectorOpen, "popup:SetFrameLevel(math.max(100", "public selector lacks elevated frame level");
requireText(selectorOpen, '"UIPanelCloseButton"', "public selector close X missing");
requireText(selectorOpen, 'close:SetText("Close")', "public selector Close button missing");
requireText(selectorOpen, 'popup:SetScript("OnKeyDown"', "public selector Escape behavior missing");
requireText(selectorOpen, '"SignalFirePublicBroadcastPopup"', "public selector is not an Escape-closeable named frame");
const controls = slice(feature, "function B:SFEnsureListingBroadcastControls()", "\n    function B:SFListingDraft");
requireText(controls, "SFListingBroadcastPopupCloseHook", "Create Listing dropdown popup-close hook missing");
requireText(controls, 'dropdown:HookScript("OnMouseDown", hidePublicPopup)', "Create Listing dropdown does not close public selector");
requireText(controls, 'self.create:HookScript("OnHide", function() B:SFHidePublicBroadcastSelector() end)', "Create Listing lifecycle does not close public selector");
requireText(controls, 'self.frame:HookScript("OnHide", function() B:SFHidePublicBroadcastSelector() end)', "main-window lifecycle does not close public selector");
requireText(feature, "self:SFHidePublicBroadcastSelector()", "profile navigation does not close public selector");

if (/NewTicker|C_Timer\.NewTicker/.test(feature)) fail("repeating timer added");
if (/SetScript\(\s*["']OnUpdate["']/.test(feature)) fail("permanent OnUpdate added");
if (/SendChatMessage/.test(feature.slice(0, feature.indexOf("function B:SFSendPublicBroadcast")))) {
  fail("broadcast occurs before the explicit send owner");
}
for (const operation of ["U~1~", "R~1~", "Q~1~", "L~1~"]) {
  requireText(marketplaceNetwork, operation, `Marketplace packet ${operation}`);
}
requireText(marketplace, "Press Enter to send.", "Share Link remains user-controlled");
requireText(toc, "## Version: 1.5.3", "version remains 1.5.3");

console.log("listing broadcast UX source verification: PASS");
