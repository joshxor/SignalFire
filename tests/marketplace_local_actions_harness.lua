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

for index=1,10 do
  local row = create("Browse Crafter " .. index, "Alchemy", "Flask Browse " .. index)
  check(M:SetFavorite(row.id, true), "favorite fixture creation failed")
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

local chatMessages = {}
local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, message) table.insert(chatMessages, message) end

U.selectedListingId = other.id
check(U:RenderDetail(), "Browse detail did not render")
check(U.detailWhisper:IsShown() and U.detailFavorite:IsShown() and U.detailLink:IsShown(),
  "Browse actions are not visible for an available remote listing")
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
U.favoriteLink:GetScript("OnClick")(U.favoriteLink)
check(string.find(chatMessages[#chatMessages-1], "signalfiremkt:" .. other.id, 1, true),
  "favorite link button did not print the selected link")

check(U:SetTab("Browse"), "Browse did not reopen")
M:SetFavorite(other.id, false)
U.selectedListingId = other.id
check(U:RenderDetail(), "Browse detail did not rerender")
check(U.detailFavorite.label:GetText() == "Favorite", "favorite label began incorrectly")
local dataGeneration = M.runtime.dataGeneration
local favoritesGeneration = M.runtime.favoritesGeneration
U.detailFavorite:GetScript("OnClick")(U.detailFavorite)
check(M:IsFavorite(other.id), "Browse favorite action did not add the favorite")
check(M.runtime.dataGeneration == dataGeneration
  and M.runtime.favoritesGeneration == favoritesGeneration+1,
  "favorite add changed the wrong generation")
check(U.detailFavorite.label:GetText() == "Unfavorite", "favorite add label did not refresh")
U.detailFavorite:GetScript("OnClick")(U.detailFavorite)
check(not M:IsFavorite(other.id), "Browse favorite action did not remove the favorite")
check(M.runtime.dataGeneration == dataGeneration
  and M.runtime.favoritesGeneration == favoritesGeneration+2,
  "favorite removal changed the wrong generation")

M.runtime.store.favoritesById[expired.id] = {
  addedAt=time(), owner=expired.owner, profession=expired.profession,
  itemName=expired.itemName, listingType=expired.listingType,
}
check(U:SetTab("Favorites"), "Favorites did not reopen")
U.favoriteSelectedId = expired.id
check(U:RenderFavoriteDetail(), "unavailable favorite detail did not render")
check(not U.favoriteWhisper:IsShown() and not U.favoriteLink:IsShown()
  and U.favoriteAction:IsShown(), "unavailable favorite exposed contact actions")

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

DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
BLFG_SetItemRef_Before565 = priorSetItemRef
SendChatMessage = originalSendChatMessage
print("marketplace local actions harness: PASS")
