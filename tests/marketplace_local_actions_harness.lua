local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B = assert(BronzeLFG, "BronzeLFG was not loaded")
local M = assert(_G.SignalFireMarketplace151, "Marketplace core was not loaded")
local U = assert(_G.SignalFireMarketplaceUI151, "Marketplace UI was not loaded")

local function check(value, message)
  if not value then error(message, 2) end
end

local function copy(source)
  local result = {}
  for key, value in pairs(source) do result[key] = value end
  return result
end

local function occurrences(haystack, needle)
  local count, start = 0, 1
  while true do
    local found = string.find(haystack, needle, start, true)
    if not found then return count end
    count, start = count + 1, found + string.len(needle)
  end
end

local function listing_signature(row)
  local fields = {
    "id", "owner", "ownerKey", "profile", "listingType", "profession",
    "itemName", "recipeName", "materialsPolicy", "priceMode", "priceText",
    "location", "availability", "notes", "createdAt", "expiresAt",
  }
  local values = {}
  for _, field in ipairs(fields) do values[#values+1] = tostring(row[field] or "") end
  return table.concat(values, "\31")
end

local function create(owner, profession, itemName, extra)
  extra = extra or {}
  local row, err = B:SFMarketplaceCreateListing({
    owner=owner, listingType="Crafting Offer", profession=profession, itemName=itemName,
    materialsPolicy="Customer Provides", priceMode="Tip", priceText=extra.priceText or "25g",
    location="Dalaran", availability="Today", notes=extra.notes or "Local action regression",
    expiresAt=extra.expiresAt or time()+7200,
  })
  check(row, "listing creation failed: " .. tostring(err))
  return row
end

BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension =
  BronzeLFG_DB.options.modulesByProfile.Ascension or {}
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true
BronzeLFG_DB.options.modulesByProfile.Triumvirate =
  BronzeLFG_DB.options.modulesByProfile.Triumvirate or {}
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = false
check(B:SFModulesApply(), "Marketplace enable failed")
check(B:ShowMarketplace(), "Marketplace UI did not open")
check(M.runtime and M.runtime.active, "Marketplace runtime is not active")
check(M.localLinkRegistered == true, "Marketplace link handler was not registered")
check(B.LinkHandlers565.signalfiremkt and B.LinkHandlers565.signalfiremkt.owner == M,
  "Marketplace does not own the shared link-handler entry")

local sentMessages, tells, openedChats = 0, {}, {}
local originalSendChatMessage = SendChatMessage
SendChatMessage = function() sentMessages = sentMessages + 1 end
ChatFrame_SendTell = function(owner) table.insert(tells, owner) end
ChatFrame_OpenChat = function(text) table.insert(openedChats, text) end
local chatMessages = {}
local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, message) table.insert(chatMessages, message) end

local own = create("Harness", "Alchemy", "Elixir of Wisdom")
local other = create("Other Crafter", "Alchemy", "Flask of Power")
local unsafe = create("Unsafe Crafter", "Al|ch[emy]\n", "Fl|ask [Bad]\tName",
  {notes="private owner notes", priceText="999g"})

local link, linkErr = M:BuildLocalLink(unsafe.id)
check(link, "local link was not generated: " .. tostring(linkErr))
local payload = string.match(link, "|H(signalfiremkt:[^|]+)|h")
check(payload == "signalfiremkt:" .. unsafe.id, "payload is not exactly the listing ID")
check(occurrences(link, unsafe.id) == 1, "listing ID does not occur exactly once")
check(not string.find(link, "private owner notes", 1, true), "notes leaked into the link")
check(not string.find(link, "999g", 1, true), "price leaked into the link")
check(not string.find(link, "Dalaran", 1, true), "location leaked into the link")
check(not string.find(link, "Al|ch", 1, true), "unsafe display pipe was retained")
check(not string.find(link, "[Bad]", 1, true), "unsafe display brackets were retained")

local maximumLocalLinkLength = M.maximumLocalLinkLength
M.maximumLocalLinkLength = 20
check(M:BuildLocalLink(unsafe.id) == nil, "oversized final link was accepted")
M.maximumLocalLinkLength = maximumLocalLinkLength
check(M:ResolveLocalLink("") == nil, "empty ID resolved")
check(M:ResolveLocalLink(string.rep("x", 129)) == nil, "oversized ID resolved")
check(M:ResolveLocalLink("not-a-marketplace-id") == nil, "malformed ID resolved")
check(M:ResolveLocalLink("mkt1:a:missing:100000:1") == nil, "missing ID resolved")

local edited, editErr = B:SFMarketplaceEditListing(unsafe.id,
  {profession="Tailoring", itemName="Mooncloth Bag"})
check(edited, "listing edit failed: " .. tostring(editErr))
check(edited.id == unsafe.id, "listing edit changed the stable ID")
local editedLink = assert(M:BuildLocalLink(unsafe.id))
check(string.match(editedLink, "|H(signalfiremkt:[^|]+)|h") == payload,
  "listing edit changed the payload")
check(string.find(editedLink, "Tailoring: Mooncloth Bag", 1, true),
  "listing edit did not refresh the display label")

local expired = copy(M.runtime.byId[other.id])
expired.id, expired.expiresAt = "mkt1:a:expired:100000:1", time()-1
M.runtime.byId[expired.id] = expired
check(M:ResolveLocalLink(expired.id) == nil, "expired row resolved")

local wrongProfile = copy(M.runtime.byId[other.id])
wrongProfile.id, wrongProfile.profile = "mkt1:t:wrongprofile:100000:1", "Triumvirate"
M.runtime.byId[wrongProfile.id] = wrongProfile
check(M:ResolveLocalLink(wrongProfile.id) == nil, "wrong-profile row resolved")

local mismatched = copy(M.runtime.byId[other.id])
local mismatchKey = "mkt1:a:mismatched:100000:1"
M.runtime.byId[mismatchKey] = mismatched
check(M:ResolveLocalLink(mismatchKey) == nil, "row/key ID mismatch resolved")

local blankOwner = copy(M.runtime.byId[other.id])
blankOwner.id, blankOwner.owner, blankOwner.ownerKey =
  "mkt1:a:blankowner:100000:1", "", ""
M.runtime.byId[blankOwner.id] = blankOwner
check(M:OpenWhisper(blankOwner.id) == false, "blank-owner row opened a whisper")

local active = M.runtime.active
M.runtime.active = false
check(M:ResolveLocalLink(other.id) == nil, "inactive runtime resolved a link")
M.runtime.active = active
local runtimeProfile = M.runtime.profile
M.runtime.profile = "Triumvirate"
check(M:ResolveLocalLink(other.id) == nil, "runtime profile mismatch resolved a link")
M.runtime.profile = runtimeProfile

local originalIsEnabled = M.IsEnabled
M.IsEnabled = function() return false end
check(M:ResolveLocalLink(other.id) == nil, "disabled module resolved a link")
M.IsEnabled = originalIsEnabled

local priorCalls = 0
local priorSetItemRef = BLFG_SetItemRef_Before565
BLFG_SetItemRef_Before565 = function() priorCalls = priorCalls + 1 end
local publicLinkCalls = 0
local originalOpenPublicGroupLink = B.OpenPublicGroupLink
B.OpenPublicGroupLink = function(_, id)
  publicLinkCalls = publicLinkCalls + 1
  check(id == "fixture", "existing SignalFire link payload changed")
end
SetItemRef("bronzelfgpub:fixture", "[Existing SignalFire]", "LeftButton", DEFAULT_CHAT_FRAME)
check(publicLinkCalls == 1 and priorCalls == 0,
  "existing SignalFire hyperlink did not retain its normal dispatcher path")
B.OpenPublicGroupLink = originalOpenPublicGroupLink
local guildLinkCalls = 0
local originalOpenGuildBrowserLink = B.OpenGuildBrowserLink
B.OpenGuildBrowserLink = function(_, guildName)
  guildLinkCalls = guildLinkCalls + 1
  check(guildName == "Fixture Guild", "existing SignalFire guild link payload changed")
end
SetItemRef("bronzelfgguild:Fixture%20Guild", "[Existing SignalFire Guild]", "LeftButton", DEFAULT_CHAT_FRAME)
check(guildLinkCalls == 1 and priorCalls == 0,
  "existing SignalFire guild hyperlink did not retain its normal dispatcher path")
B.OpenGuildBrowserLink = originalOpenGuildBrowserLink
SetItemRef("item:12345", "[Native Item]", "LeftButton", DEFAULT_CHAT_FRAME)
SetItemRef("unknown_type:data", "[Unknown]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2, "unknown/native links did not delegate exactly once each")

local registryEntry = B.LinkHandlers565.signalfiremkt
SetItemRef("signalfiremkt:" .. other.id, "[Marketplace]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2, "Marketplace link delegated to the prior SetItemRef handler")
check(B.LinkHandlers565.signalfiremkt == registryEntry,
  "Marketplace click replaced its registry entry")
check(U.selectedTab == "Browse" and U.selectedListingId == other.id,
  "Marketplace click did not select the exact Browse listing")

local unavailableBefore = #chatMessages
local selectionBeforeUnavailable = U.selectedListingId
SetItemRef("signalfiremkt:" .. expired.id, "[Expired Marketplace]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2 and #chatMessages == unavailableBefore + 1
  and chatMessages[#chatMessages] == "SignalFire> Looking up Marketplace listing..."
  and M.runtime.linkLookupsById[expired.id] ~= nil
  and U.selectedListingId == selectionBeforeUnavailable,
  "handled Marketplace missing link did not begin one bounded lookup")

local marketplaceCallback = registryEntry.callback
registryEntry.callback = function() error("Marketplace callback fixture error") end
unavailableBefore = #chatMessages
SetItemRef("signalfiremkt:" .. other.id, "[Marketplace Callback Error]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2 and #chatMessages == unavailableBefore + 1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable."
  and U.selectedListingId == selectionBeforeUnavailable,
  "callback error delegated or was not safely consumed")
registryEntry.callback = function()
  DEFAULT_CHAT_FRAME:AddMessage("SignalFire> Marketplace listing is unavailable.")
  return false
end
unavailableBefore = #chatMessages
SetItemRef("signalfiremkt:" .. other.id, "[Marketplace Callback False]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2 and #chatMessages == unavailableBefore + 1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable.",
  "callback false duplicated its unavailable message or delegated")
registryEntry.callback = marketplaceCallback

check(B:UnregisterLinkHandler("signalfiremkt", {}) == false,
  "wrong owner removed the Marketplace handler")
check(B.LinkHandlers565.signalfiremkt == registryEntry,
  "wrong-owner unregister changed the registry")
check(B:UnregisterLinkHandler("signalfiremkt", M) == true,
  "correct owner could not remove the Marketplace handler")
check(B.LinkHandlers565.signalfiremkt == nil, "removed handler remains registered")
M.localLinkRegistered = false
check(M:RegisterLocalLinkHandler(), "Marketplace handler could not be restored")
check(B.LinkHandlers565.signalfiremkt.owner == M, "restored handler has the wrong owner")

check(M:OpenWhisper(other.id), "remote listing did not open a whisper")
check(tells[#tells] == "Other Crafter", "preferred whisper API received the wrong owner")
check(M:OpenWhisper(own.id) == false, "own listing opened a whisper")
check(M:OpenWhisper(expired.id) == false, "expired listing opened a whisper")
local sendTell = ChatFrame_SendTell
ChatFrame_SendTell = nil
check(M:OpenWhisper(other.id), "fallback whisper composer did not open")
check(openedChats[#openedChats] == "/w Other Crafter ", "fallback whisper text is not exact")
ChatFrame_SendTell = sendTell
check(sentMessages == 0, "local contact action transmitted chat")

local unrelatedFavorite
for index=1,10 do
  local row = create("Browse Crafter " .. index, "Alchemy", "Flask Browse " .. index)
  check(M:SetFavorite(row.id, true), "favorite fixture creation failed")
  if index == 1 then unrelatedFavorite = row.id end
end
check(M:SetFavorite(other.id, true), "selected favorite fixture failed")
U.browseSearchQuery = "flask"
U.browseListingType = "Crafting Offer"
U.browseProfessionKey = "alchemy"
U.browseLocationKey = "dalaran"
U.browseAvailability = "Today"
U.browseFavoritesOnly = true
U.browsePage = 2
local state = {
  U.browseSearchQuery, U.browseListingType, U.browseProfessionKey,
  U.browseLocationKey, U.browseAvailability, U.browseFavoritesOnly, U.browsePage,
}
check(M:HandleLocalLink(other.id), "valid local link could not be handled")
check(U.selectedTab == "Browse" and U.selectedListingId == other.id,
  "exact-link navigation selected the wrong listing")
check(U.browseSearchQuery == state[1] and U.browseListingType == state[2]
  and U.browseProfessionKey == state[3] and U.browseLocationKey == state[4]
  and U.browseAvailability == state[5] and U.browseFavoritesOnly == state[6]
  and U.browsePage == state[7], "exact-link navigation changed Browse state")
check(U.browseDetail:IsShown() and not U.browseSearchBox:IsShown(),
  "exact-link navigation did not show detail and hide the toolbar")

local selectedBeforeInvalid = U.selectedListingId
local unavailableBefore = #chatMessages
check(M:HandleLocalLink(expired.id), "expired local link did not coalesce the existing lookup")
check(#chatMessages == unavailableBefore, "duplicate expired link lookup emitted another message")
check(U.selectedListingId == selectedBeforeInvalid, "expired link changed the selected listing")
unavailableBefore = #chatMessages
check(M:HandleLocalLink(wrongProfile.id) == false, "wrong-profile local link was handled")
check(#chatMessages == unavailableBefore+1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable.",
  "wrong-profile link did not emit exactly one unavailable message")
check(U.selectedListingId == selectedBeforeInvalid, "wrong-profile link changed the selected listing")
unavailableBefore = #chatMessages
check(M:HandleLocalLink("mkt1:a:missing:100000:1") == false, "missing local link was handled")
check(#chatMessages == unavailableBefore+1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable.",
  "missing link did not emit exactly one unavailable message")
check(U.selectedListingId == selectedBeforeInvalid, "missing link changed the selected listing")

local generatedDataGeneration = M.runtime.dataGeneration
local generatedFavoritesGeneration = M.runtime.favoritesGeneration
local generatedIndexCount = M.runtime.indexCount
local generatedById, generatedByOwner = M.runtime.byId, M.runtime.byOwner
local generatedOtherSignature = listing_signature(M.runtime.byId[other.id])
local generatedOwnSignature = listing_signature(M.runtime.byId[own.id])

U.selectedListingId = other.id
check(U:RenderDetail(), "Browse detail did not render")
check(U.detailWhisper:IsShown() and U.detailFavorite:IsShown() and U.detailLink:IsShown(),
  "Browse actions are not visible for an available remote listing")
local browseTellCount = #tells
U.detailWhisper:GetScript("OnClick")(U.detailWhisper)
check(#tells == browseTellCount+1 and tells[#tells] == "Other Crafter",
  "Browse Whisper did not target the exact listing owner")
U.detailLink:GetScript("OnClick")(U.detailLink)
check(string.find(chatMessages[#chatMessages-1], "signalfiremkt:" .. other.id, 1, true),
  "Browse link button did not print the selected link")

check(U:SetTab("My Listings"), "My Listings did not open")
U.mySelectedListingId = own.id
check(U:RenderMyListingsDetail(), "owned detail did not render")
check(U.myDetailLink:IsShown(), "owned link action is hidden")
U.myDetailLink:GetScript("OnClick")(U.myDetailLink)
check(string.find(chatMessages[#chatMessages-1], "signalfiremkt:" .. own.id, 1, true),
  "owned link button did not print the selected link")

check(U:SetTab("Favorites"), "Favorites did not open")
U.favoriteSelectedId = other.id
check(U:RenderFavoriteDetail(), "favorite detail did not render")
check(U.favoriteWhisper:IsShown() and U.favoriteLink:IsShown(),
  "favorite contact actions are hidden for an available remote listing")
check(U.favoriteAction.label:GetText() == "Unfavorite",
  "active favorite did not retain its Unfavorite action")
local favoriteTellCount = #tells
U.favoriteWhisper:GetScript("OnClick")(U.favoriteWhisper)
check(#tells == favoriteTellCount+1 and tells[#tells] == "Other Crafter",
  "Favorite Whisper did not target the exact listing owner")
U.favoriteLink:GetScript("OnClick")(U.favoriteLink)
check(string.find(chatMessages[#chatMessages-1], "signalfiremkt:" .. other.id, 1, true),
  "favorite link button did not print the selected link")
check(M.runtime.dataGeneration == generatedDataGeneration
  and M.runtime.favoritesGeneration == generatedFavoritesGeneration
  and M.runtime.indexCount == generatedIndexCount
  and M.runtime.byId == generatedById and M.runtime.byOwner == generatedByOwner,
  "Generate Link mutated runtime generations or indexes")
check(listing_signature(M.runtime.byId[other.id]) == generatedOtherSignature
  and listing_signature(M.runtime.byId[own.id]) == generatedOwnSignature,
  "Generate Link mutated listing data")
check(M.runtime.byId[other.id].generatedLink == nil
  and M.runtime.byId[other.id].localLink == nil
  and M.runtime.byId[own.id].generatedLink == nil
  and M.runtime.byId[own.id].localLink == nil,
  "Generate Link persisted generated-link state")
check(sentMessages == 0, "Generate Link selected an outgoing chat path")

check(U:SetTab("Browse"), "Browse did not reopen")
M:SetFavorite(other.id, false)
U.selectedListingId = other.id
check(U:RenderDetail(), "Browse detail did not rerender")
check(U.detailFavorite.label:GetText() == "Favorite", "favorite label began incorrectly")
local dataGeneration = M.runtime.dataGeneration
local favoritesGeneration = M.runtime.favoritesGeneration
local favoriteBrowseState = {
  U.browseSearchQuery, U.browseListingType, U.browseProfessionKey,
  U.browseLocationKey, U.browseAvailability, U.browseFavoritesOnly, U.browsePage,
}
U.detailFavorite:GetScript("OnClick")(U.detailFavorite)
check(M:IsFavorite(other.id), "Browse favorite action did not add the favorite")
check(M.runtime.dataGeneration == dataGeneration
  and M.runtime.favoritesGeneration == favoritesGeneration+1,
  "favorite add changed the wrong generation")
check(U.detailFavorite.label:GetText() == "Unfavorite", "favorite add label did not refresh")
check(U.selectedListingId == other.id and U.browseDetail:IsShown(),
  "favorite add closed or changed Browse detail")
check(U.browseSearchQuery == favoriteBrowseState[1]
  and U.browseListingType == favoriteBrowseState[2]
  and U.browseProfessionKey == favoriteBrowseState[3]
  and U.browseLocationKey == favoriteBrowseState[4]
  and U.browseAvailability == favoriteBrowseState[5]
  and U.browseFavoritesOnly == favoriteBrowseState[6]
  and U.browsePage == favoriteBrowseState[7],
  "favorite add changed Browse search/filter/page state")
check(M:IsFavorite(unrelatedFavorite), "favorite add changed an unrelated favorite")
U.detailFavorite:GetScript("OnClick")(U.detailFavorite)
check(not M:IsFavorite(other.id), "Browse favorite action did not remove the favorite")
check(M.runtime.dataGeneration == dataGeneration
  and M.runtime.favoritesGeneration == favoritesGeneration+2,
  "favorite removal changed the wrong generation")
check(M:IsFavorite(unrelatedFavorite), "favorite removal changed an unrelated favorite")

check(M:SetFavorite(own.id, true), "own-favorite fixture failed")
check(U:SetTab("Favorites"), "Favorites did not open for own favorite")
U.favoriteSelectedId = own.id
check(U:RenderFavoriteDetail(), "own active favorite detail did not render")
check(not U.favoriteWhisper:IsShown() and U.favoriteLink:IsShown(),
  "own active favorite has incorrect Whisper/Generate Link visibility")
check(U.favoriteAction.label:GetText() == "Unfavorite",
  "own active favorite did not retain its Unfavorite action")

M.runtime.store.favoritesById[expired.id] = {
  addedAt=time(), owner=expired.owner, profession=expired.profession,
  itemName=expired.itemName, listingType=expired.listingType,
}
check(U:SetTab("Favorites"), "Favorites did not reopen")
U.favoriteSelectedId = expired.id
check(U:RenderFavoriteDetail(), "unavailable favorite detail did not render")
check(not U.favoriteWhisper:IsShown(), "unavailable favorite exposed Whisper")
check(not U.favoriteLink:IsShown(), "unavailable favorite exposed Generate Link")
check(U.favoriteAction:GetScript("OnClick")
  and U.favoriteAction.label:GetText() == "Remove Favorite",
  "unavailable favorite did not retain its Remove Favorite action")

local controls = {
  U.detailWhisper, U.detailFavorite, U.detailLink,
  U.myDetailLink, U.favoriteWhisper, U.favoriteLink,
}
local panel = U.panel
check(U:ActiveScriptCount() == 72, "enabled script count is not 72")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false
check(B:SFModulesApply(), "Marketplace disable failed")
check(U:ActiveScriptCount() == 0, "disabled script count is not zero")
check(B.LinkHandlers565.signalfiremkt == nil, "handler survived Marketplace disable")
check(M.localLinkRegistered == false and M.localLinkCallback ~= nil,
  "disable retained registered-link state or discarded the retained callback")
local disabledOpenCount, disabledSelection, disabledPanel = U.openCount, U.selectedListingId, U:GetPanelState()
unavailableBefore = #chatMessages
SetItemRef("signalfiremkt:" .. other.id, "[Disabled Marketplace]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2 and B.LinkHandlers565.signalfiremkt == nil
  and #chatMessages == unavailableBefore + 1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable."
  and U.openCount == disabledOpenCount and U.selectedListingId == disabledSelection
  and U:GetPanelState() == disabledPanel,
  "disabled same-profile Marketplace link delegated or initialized UI")
for _, control in ipairs(controls) do
  check(control:GetScript("OnClick") == nil, "local-action script survived disable")
end

BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true
check(B:SFModulesApply(), "Marketplace re-enable failed")
check(B:ShowMarketplace(), "Marketplace did not reopen")
check(U:ActiveScriptCount() == 72, "re-enabled script count is not 72")
check(U.panel == panel, "Marketplace panel was recreated")
check(U.detailWhisper == controls[1] and U.detailFavorite == controls[2]
  and U.detailLink == controls[3] and U.myDetailLink == controls[4]
  and U.favoriteWhisper == controls[5] and U.favoriteLink == controls[6],
  "local-action controls were recreated")
check(B.LinkHandlers565.signalfiremkt
  and B.LinkHandlers565.signalfiremkt.owner == M,
  "Marketplace handler was not restored")

local ascensionLink = "signalfiremkt:" .. other.id
BronzeLFG_DB.options.serverProfile = "Triumvirate"
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = false
check(B:SFModulesApply(), "Triumvirate profile switch failed")
check(B.LinkHandlers565.signalfiremkt == nil and M.localLinkRegistered == false
  and U:ActiveScriptCount() == 0, "profile switch retained Marketplace registration or scripts")
local switchedOpenCount, switchedSelection, switchedPanel = U.openCount, U.selectedListingId, U:GetPanelState()
unavailableBefore = #chatMessages
SetItemRef(ascensionLink, "[Old Ascension Marketplace]", "LeftButton", DEFAULT_CHAT_FRAME)
check(priorCalls == 2 and B.LinkHandlers565.signalfiremkt == nil
  and #chatMessages == unavailableBefore + 1
  and chatMessages[#chatMessages] == "SignalFire> Marketplace listing is unavailable."
  and U.openCount == switchedOpenCount and U.selectedListingId == switchedSelection
  and U:GetPanelState() == switchedPanel,
  "disabled-profile Marketplace link delegated, opened UI, or changed selection")

DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
BLFG_SetItemRef_Before565 = priorSetItemRef
SendChatMessage = originalSendChatMessage
print("marketplace local actions harness: PASS")
