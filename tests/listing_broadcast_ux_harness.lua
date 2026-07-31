local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local sent, notices = {}, {}
local channelIds = {Global=3, Ascension=4, Newcomers=7, LookingForGroup=8, BLFG=9, Zone=10, Trade=11, ["Global-Guild-Recruitment"]=12}
local channelShape = "pair"
local joinedChannels = {"Global", "Ascension", "Newcomers", "BLFG", "ascension"}

function GetChannelName(name) return channelIds[tostring(name or "")] or 0 end
function GetChannelList()
  local raw = {}
  for _, name in ipairs(joinedChannels) do
    table.insert(raw, channelIds[name] or 0)
    if channelShape == "triplet" then table.insert(raw, false) end
    table.insert(raw, name)
  end
  return unpack(raw)
end
function SendChatMessage(text, chatType, language, channelId)
  table.insert(sent, {text=tostring(text or ""), chatType=chatType, language=language, channelId=channelId})
end
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(notices, tostring(text or "")) end

local function resetSends() sent, notices = {}, {} end
local function contains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end
local function sawNotice(value)
  for _, item in ipairs(notices) do if string.find(item, value, 1, true) then return true end end
  return false
end
local function split(payload)
  local out, start = {}, 1
  while true do
    local at = string.find(payload, "~", start, true)
    if not at then table.insert(out, string.sub(payload, start)); return out end
    table.insert(out, string.sub(payload, start, at - 1)); start = at + 1
  end
end
local function publicSends()
  local out = {}
  for _, item in ipairs(sent) do if string.sub(item.text, 1, 8) ~= "BLFG312~" then table.insert(out, item) end end
  return out
end
local function internalSends()
  local out = {}
  for _, item in ipairs(sent) do if string.sub(item.text, 1, 13) == "BLFG312~LIST~" then table.insert(out, item) end end
  return out
end

-- A. Pair/triplet channel discovery, exclusion, deduplication, and no send.
channelShape = "pair"
local pair = B:SFDiscoverPublicChannels()
assert(#pair == 3 and contains(pair, "Global") and contains(pair, "Ascension") and contains(pair, "Newcomers"))
assert(not contains(pair, "BLFG"), "pair discovery exposed BLFG")
assert(#sent == 0, "pair discovery sent chat")
channelShape = "triplet"
local triplet = B:SFDiscoverPublicChannels()
assert(#triplet == 3 and contains(triplet, "Global") and contains(triplet, "Ascension") and contains(triplet, "Newcomers"))
assert(not contains(triplet, "BLFG"), "triplet discovery exposed BLFG")
assert(#sent == 0, "triplet discovery sent chat")

-- B. Selection lifecycle remains bounded, name-only, removable, and deduplicated.
BronzeLFG_DB.options.serverProfile = "Ascension"
B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers", "ascension", "BLFG", "", "Unavailable"})
local selected = B:SFGetPublicBroadcastChannels()
assert(#selected == 2 and selected[1] == "Ascension" and selected[2] == "Newcomers")
for _, value in ipairs(selected) do assert(type(value) == "string", "numeric channel ID persisted") end
B:SFSetPublicBroadcastChannels({})
assert(#B:SFGetPublicBroadcastChannels() == 0, "clear selection failed")
local tooMany = {}
joinedChannels = {}
for i = 1, 20 do local name = "Channel" .. tostring(i); channelIds[name] = i + 20; joinedChannels[i] = name; tooMany[i] = name end
assert(#B:SFSetPublicBroadcastChannels(tooMany) == 8, "selection bound failed")
joinedChannels = {"Global", "Ascension", "Newcomers", "BLFG", "ascension"}
B:SFSetPublicBroadcastChannels({"Unavailable"})
B:SFSetPublicBroadcastChannels({})
assert(#B:SFGetPublicBroadcastChannels() == 0, "unavailable selection was retained")

-- C/D. Idempotent legacy channel/role migration and explicit new-value precedence.
BronzeLFG_DB.listingBroadcastByProfile = nil
BronzeLFG_DB.listingBroadcastMigration = nil
BronzeLFG_DB.recruitmentCreator = {broadcastChannel="Ascension"}
BronzeLFG_DB.createByProfile = {
  Ascension={needTank=true, needHealer="1", needDPS=1, minLevel="", maxLevel=""},
  Triumvirate={needTank=false, needHealer="0", needDPS=false},
}
local legacy = B:SFListingBroadcastState()
assert(legacy.channels[1] == "Ascension", "joined legacy channel did not migrate")
assert(legacy.tankCount == 1 and legacy.healerCount == 1 and legacy.dpsCount == 1 and legacy.supportCount == 0,
  "legacy role flags did not migrate")
assert(BronzeLFG_DB.recruitmentCreator.broadcastChannel == "Ascension", "legacy channel field was erased")
assert(BronzeLFG_DB.createByProfile.Ascension.needTank == true, "legacy role field was erased")
local again = B:SFListingBroadcastState()
assert(again == legacy and #again.channels == 1, "legacy migration was not idempotent")
BronzeLFG_DB.listingBroadcastByProfile.Ascension.tankCount = 6
BronzeLFG_DB.listingBroadcastByProfile.Ascension.rolesMigrated = false
assert(B:SFListingBroadcastState().tankCount == 6, "explicit new count lost to legacy migration")

-- K. Exact readable role wording.
assert(B:SFRolePhrase({tankCount=1}) == "Need 1 Tank")
assert(B:SFRolePhrase({tankCount=2}) == "Need 2 Tanks")
assert(B:SFRolePhrase({tankCount=1,dpsCount=2}) == "Need 1 Tank and 2 DPS")
assert(B:SFRolePhrase({tankCount=1,healerCount=1,supportCount=1,dpsCount=2})
  == "Need 1 Tank, 1 Healer, 1 Support, and 2 DPS")
assert(B:SFRolePhrase({supportCount=2}) == "Need 2 Support")
assert(B:SFRolePhrase({}) == "Need flexible roles")

-- E/G. Multi-channel sending and current-channel pruning/empty outcomes.
B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers", "ascension", "BLFG"})
resetSends()
local message = B:ListingRecruitmentText({activity="Molten Core",tankCount=1,dpsCount=2,minLevel=30,maxLevel=40})
assert(B:SFSendPublicBroadcast(message) == true)
local public = publicSends()
assert(#public == 2 and public[1].text == public[2].text, "multi-channel text was not identical")
assert(public[1].channelId == 4 and public[2].channelId == 7, "send-time channel IDs were wrong")
for _, item in ipairs(public) do assert(item.channelId ~= 3 and item.channelId ~= 9, "Global or BLFG received public text") end
B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers"}); joinedChannels = {"Global", "Ascension", "BLFG"}; resetSends()
assert(#B:SFGetPublicBroadcastChannels() == 1 and B:SFSendPublicBroadcast(message) == true and #publicSends() == 1,
  "left channel was not pruned before sending")
joinedChannels = {"Global", "Ascension", "Newcomers", "BLFG", "ascension"}
B:SFSetPublicBroadcastChannels({}); resetSends()
assert(B:SFSendPublicBroadcast(message) == false and #publicSends() == 0 and sawNotice("Select at least one"))

-- Build the real Create Listing UI once, then exercise profile-visible state.
B:ShowCreate()
assert(B.listingBroadcastControlsBuilt and B.tankCountBox and B.supportCountBox and B.minLevelBox)
local originalTankBox, originalChannelButton = B.tankCountBox, B.publicBroadcastChoose

-- Live correction: stale server-specific legacy values never become unavailable rows.
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.listingBroadcastByProfile = nil
BronzeLFG_DB.listingBroadcastMigration = nil
BronzeLFG_DB.recruitmentCreator = {broadcastChannel="Global-Guild-Recruitment"}
joinedChannels = {"Ascension", "Newcomers", "Zone", "Trade", "BLFG"}
B:SFOpenPublicBroadcastSelector()
local popup = assert(B.publicBroadcastPopup, "public broadcast popup was not created")
local visible = {}
for _, row in ipairs(popup.rows) do if row:IsShown() then table.insert(visible, row.channelName) end end
assert(#visible == 4 and contains(visible, "Ascension") and contains(visible, "Newcomers") and contains(visible, "Zone") and contains(visible, "Trade"),
  "selector did not use only current joined public channels")
assert(not contains(visible, "BLFG") and not contains(visible, "Global-Guild-Recruitment"), "stale or BLFG channel leaked into Ascension")
assert(#B:SFGetPublicBroadcastChannels() == 0, "unavailable legacy selection was retained")
assert(popup:GetFrameStrata() == "DIALOG" and popup:GetFrameLevel() > B.create:GetFrameLevel(), "public popup did not use elevated dialog layering")

-- The historical Triumvirate channel remains selectable only when currently joined.
B:SF143_SetServerProfile("Triumvirate", true)
joinedChannels = {"Global-Guild-Recruitment", "BLFG"}
local triumvirate = B:SFDiscoverPublicChannels()
assert(#triumvirate == 1 and triumvirate[1] == "Global-Guild-Recruitment", "legitimate Triumvirate channel was excluded")

-- Dungeon and public-channel popups are mutually exclusive and reuse existing controls.
B:SF143_SetServerProfile("Ascension", true)
joinedChannels = {"Ascension", "Newcomers", "Zone", "Trade", "BLFG"}
local dungeonSelector = assert(B.specificDungeonDrop._sf1430jSelector, "custom dungeon selector missing")
local dungeonClick = assert(dungeonSelector:GetScript("OnClick"), "custom dungeon selector script missing")
dungeonClick(dungeonSelector)
local dungeonPopup = assert(SignalFireAscensionListingPolish.dungeonSelectorPopup1430j, "custom dungeon popup missing")
assert(dungeonPopup:IsShown(), "custom dungeon popup did not open")
B:SFOpenPublicBroadcastSelector()
assert(not dungeonPopup:IsShown() and popup:IsShown(), "public popup did not close dungeon popup")
dungeonClick(dungeonSelector)
assert(dungeonPopup:IsShown() and not popup:IsShown(), "dungeon popup did not close public popup")
assert(dungeonSelector:GetScript("OnClick") == dungeonClick, "dungeon selector script was duplicated")
assert(#sent == 0, "popup lifecycle sent chat")

B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers"})
joinedChannels = {"Ascension", "Zone", "Trade", "BLFG"}
B:SFOpenPublicBroadcastSelector()
assert(#B:SFGetPublicBroadcastChannels() == 1 and B:SFGetPublicBroadcastChannels()[1] == "Ascension", "refresh did not prune left channel")
assert(not string.find(B.publicBroadcastSummary:GetText(), "Newcomers", 1, true), "refresh summary retained left channel")
assert(#sent == 0, "refresh pruning sent chat")
joinedChannels = {"Ascension", "Newcomers", "Zone", "Trade", "BLFG"}

B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers"})
B.tankCountBox:SetText("2"); B.healerCountBox:SetText("1"); B.supportCountBox:SetText("3"); B.dpsCountBox:SetText("4")
B.minLevelBox:SetText("30"); B.maxLevelBox:SetText("40")
B:SF143_SetServerProfile("Triumvirate", true)
B:SFSetPublicBroadcastChannels({"Global"})
B.tankCountBox:SetText("0"); B.healerCountBox:SetText("2"); B.supportCountBox:SetText("0"); B.dpsCountBox:SetText("1")
B.minLevelBox:SetText("60"); B.maxLevelBox:SetText("60")
B:SF143_SetServerProfile("Ascension", true)
assert(B.tankCountBox == originalTankBox and B.publicBroadcastChoose == originalChannelButton, "profile switch recreated controls")
assert(B.tankCountBox:GetText() == "2" and B.supportCountBox:GetText() == "3", "Ascension visible counts did not return")
assert(B.minLevelBox:GetText() == "30" and B.maxLevelBox:GetText() == "40", "Ascension visible levels did not return")
assert(#B:SFGetPublicBroadcastChannels() == 2, "Ascension channel selection did not return")

-- H/I. Count and level normalization, including Use My Level and reversed blocking.
local countCases = {
  {"",0}, {"-1",0}, {"1.5",0}, {"0",0}, {"1",1}, {"40",40}, {"41",40},
}
for _, fixture in ipairs(countCases) do
  local row = B:SFNormalizeListingRoles({tankCount=fixture[1]})
  assert(row.tankCount == fixture[2], "count normalization failed for " .. fixture[1])
end
assert(B:SFLevelRange({minLevel=34,maxLevel=34}) == "Level 34")
assert(B:SFLevelRange({minLevel=30,maxLevel=40}) == "Levels 30-40")
assert(B:SFLevelRange({minLevel=40}) == "Minimum Level 40+")
assert(B:SFLevelRange({maxLevel=50}) == "Maximum Level 50")
local useMyLevel = assert(B.publicBroadcastUseMyLevel:GetScript("OnClick"), "Use My Level click missing")
useMyLevel()
assert(B.minLevelBox:GetText() == "60" and B.maxLevelBox:GetText() == "60", "Use My Level failed")

-- L. Actual preview and both Recruitment Creator builders expand level variables.
B.tankCountBox:SetText("1"); B.healerCountBox:SetText("1"); B.supportCountBox:SetText("1"); B.dpsCountBox:SetText("2")
B.minLevelBox:SetText("30"); B.maxLevelBox:SetText("40")
B:SFAM_UpdateCreatePreview()
local preview = B.sfamCreatePreview and B.sfamCreatePreview.text and B.sfamCreatePreview.text:GetText() or ""
assert(string.find(preview, "1 Tank, 1 Healer, 1 Support, and 2 DPS", 1, true), "preview lacks full role phrase")
assert(string.find(preview, "Levels 30-40", 1, true), "preview lacks level range")
B.RecruitmentCreator = B.RecruitmentCreator or {}
B.RecruitmentCreator.guildEdit = B.RecruitmentCreator.guildEdit or CreateFrame("EditBox")
B.RecruitmentCreator.notesEdit = B.RecruitmentCreator.notesEdit or CreateFrame("EditBox")
B.RecruitmentCreator.discordEdit = B.RecruitmentCreator.discordEdit or CreateFrame("EditBox")
B.RecruitmentCreator.guildEdit:SetText("Harness")
B.RecruitmentCreator.notesEdit:SetText("{level}|{minLevel}|{maxLevel}|{levelRange}|{unknown}")
B.RecruitmentCreator.discordEdit:SetText("")
B.myListing = {activity="Test",tankCount=1,minLevel=30,maxLevel=40}
local ad = B:BuildRecruitmentAd()
assert(string.find(ad, "60|30|40|Levels 30-40|{unknown}", 1, true), "Recruitment Creator variables did not expand")
assert(not string.find(ad, "nil", 1, true), "template rendered nil")

-- F/H/I. Create & Broadcast serializes normalized data before one public operation.
B.myListing = nil; B.listings = {}
B:ShowCreate()
B.tankCountBox:SetText("41"); B.healerCountBox:SetText("-1"); B.supportCountBox:SetText("1.5"); B.dpsCountBox:SetText("2")
B.minLevelBox:SetText("0"); B.maxLevelBox:SetText("300")
B:SFSetPublicBroadcastChannels({"Ascension", "Newcomers"})
resetSends()
B:CreateListing()
local internals, publics = internalSends(), publicSends()
assert(#internals == 1, "Create did not perform one internal LIST synchronization")
assert(#publics == 2 and publics[1].text == publics[2].text, "Create did not perform one two-channel public operation")
local packet = split(internals[1].text)
assert(packet[21] == "40" and packet[22] == "0" and packet[23] == "2" and packet[24] == "0",
  "invalid counts reached serialization")
assert(packet[25] == "" and packet[26] == "", "invalid levels reached serialization")
assert(string.find(publics[1].text, "40 Tanks", 1, true) and string.find(publics[1].text, "2 DPS", 1, true),
  "public text did not use normalized counts")
B.myListing = nil; B.listings = {}
B.minLevelBox:SetText("50"); B.maxLevelBox:SetText("40"); resetSends()
assert(B:CreateListing() == false and #internalSends() == 0 and #publicSends() == 0, "reversed levels were transmitted")
assert(B.minLevelBox:GetText() == "50" and B.maxLevelBox:GetText() == "40", "reversed levels were not preserved")
assert(sawNotice("Minimum level cannot be higher"), "reversed levels lacked feedback")

-- J/M. Old/new LIST compatibility, optional normalization, extra data, and mirrors.
local oldPayload = table.concat({
  "BLFG312","LIST","OLD-1","OldLeader","Mage","MAGE","Dungeon","The Nexus","Normal","",
  "60","1","5","1","1","1","None","Group Loot","Old packet","1000",
}, "~")
B:HandleMessage(oldPayload)
local old = assert(B.listings["OLD-1"], "old packet did not parse")
assert(old.tankCount == 1 and old.healerCount == 1 and old.dpsCount == 1 and old.supportCount == 0)
local newPayload = table.concat({
  "BLFG312","LIST","NEW-1","NewLeader","Mage","MAGE","Raid","Molten Core","Normal","",
  "60","1","40","1","1","1","None","Group Loot","New packet","1000",
  "41","-1","2.5","2","30","40","harmless-extra",
}, "~")
B:HandleMessage(newPayload)
local new = assert(B.listings["NEW-1"], "new packet did not parse")
assert(new.tankCount == 40 and new.healerCount == 0 and new.dpsCount == 0 and new.supportCount == 2)
assert(new.minLevel == 30 and new.maxLevel == 40)
B.myListing = new; resetSends(); B:Broadcast(); B:Broadcast()
local roundTrips = internalSends()
assert(#roundTrips == 2 and roundTrips[1].text == roundTrips[2].text, "new packet reserialization was not deterministic")
local mirror = assert(B:MirrorListingToPublic(new), "new listing did not mirror")
assert(mirror.supportCount == 2 and mirror.levelRange == "Levels 30-40")
assert(string.find(mirror.roles, "Support", 1, true) and string.find(mirror.message, "Levels 30-40", 1, true))
local oldMirror = assert(B:MirrorListingToPublic(old), "old listing did not mirror")
assert(oldMirror.supportCount == 0 and oldMirror.message ~= "", "old listing display failed")

-- N. Twenty UI/profile/selector cycles reuse controls/scripts and never send.
B.myListing = nil; resetSends()
local tankScript = B.tankCountBox:GetScript("OnTextChanged")
local chooseScript = B.publicBroadcastChoose:GetScript("OnClick")
for i = 1, 20 do
  B:ShowCreate()
  B:SFDiscoverPublicChannels()
  B:SFOpenPublicBroadcastSelector()
  B:SFSetPublicBroadcastChannels(i % 2 == 0 and {"Ascension"} or {})
  if B.publicBroadcastPopup then B.publicBroadcastPopup:Hide() end
  if B.create then B.create:Hide() end
  B:SF143_SetServerProfile(i % 2 == 0 and "Ascension" or "Triumvirate", true)
end
assert(B.tankCountBox == originalTankBox and B.publicBroadcastChoose == originalChannelButton, "lifecycle duplicated controls")
assert(B.tankCountBox:GetScript("OnTextChanged") == tankScript, "lifecycle duplicated input scripts")
assert(B.publicBroadcastChoose:GetScript("OnClick") == chooseScript, "lifecycle duplicated button scripts")
assert(#sent == 0, "lifecycle sent chat without Broadcast")
assert(#B:SFGetPublicBroadcastChannels() <= 8, "lifecycle exceeded saved selection bound")

print("listing broadcast UX harness: PASS")
