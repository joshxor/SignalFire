local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}, Triumvirate={tradeskillMarketplace=true}}
local currentPlayerName = "Aesri"
function UnitName(unit) if unit == "player" then return currentPlayerName end end
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")
assert(M:GetCurrentOwnerKey() == "aesri", "bare current character name was not canonicalized")

local function create(owner, number)
  return assert(B:SFMarketplaceCreateListing({owner=owner, listingType="Crafting Offer", profession="Alchemy",
    itemName="Owned Item " .. number, materialsPolicy="Customer Provides", priceMode="Tip", location="Dalaran",
    availability="Today", notes="note " .. number, expiresAt=time() + 7200}))
end

local first = create(" Aesri ", 1)
for index = 2, 9 do create("Aesri", index) end
local other = create("Aesri-Alt", 10)
assert(U:SetTab("My Listings") == true and U.myListingsView.total == 9, "exact owner index view is incorrect")
assert(#U.myListingsRows == 8 and U.myListingsRows[1].labels[3]:GetText() == "Owned Item 9", "owned rows are not newest first")
assert(U.myListingsPage == 1 and U:ChangeMyListingsPage(1) == true and U.myListingsPage == 2, "owned paging failed")
assert(U.myListingsRows[1].listingId == first.id, "second owned page is incorrect")
assert(U:SelectMyListingsRow(U.myListingsRows[1]) == true and U.mySelectedListingId == first.id, "stable owned selection failed")
assert(U.myDetailValues[1]:GetText() == "Aesri" and U.myDetailValues[11]:GetText() == "note 1", "owned details are incorrect")
assert(U.myDetailBack:GetScript("OnClick"), "owned Back has no script")
U.myDetailBack:GetScript("OnClick")(U.myDetailBack)
assert(U.myListingsPage == 2 and not U.mySelectedListingId, "Back did not preserve owned page")
assert(U:SelectMyListingsRow(U.myListingsRows[1]) == true, "owned row no longer selects")
assert(U:RemoveMyListing() == true and M:GetListing(first.id), "first removal click was not confirmation-only")
assert(U:RemoveMyListing() == true and not M:GetListing(first.id) and U.myListingsPage == 1, "confirmed removal did not clamp page")
assert(U:SelectMyListingsRow({listingId=other.id, IsShown=function() return true end}) == false, "foreign owner was selectable")
assert(U:SetTab("Browse") == true, "Browse did not restore")
local browseSnapshot = U:BuildBrowseSnapshot()
assert(U:SetTab("My Listings") == true and U.myListingsView.total == 8, "owned view did not retain removal state")
assert(U:SetTab("Browse") == true and U:BuildBrowseSnapshot() == browseSnapshot, "tab navigation rebuilt Browse snapshot")
assert(U:OnMarketplaceFavoritesChanged() == false and U:BuildMyListingsView().total == 8, "favorite-only change rebuilt owned view")

local legacy = create("Aesri-Vol'jin", 11)
local missing = create("Aesri", 12)
local expired = create("Aesri", 13)
M.runtime.store.listingsById[expired.id].expiresAt = time() - 1
assert(U:SetTab("My Listings") == true and U:BuildMyListingsView().total == 10,
  "canonical owner view omitted a realm-suffixed owned listing or included an expired one")
assert(M.runtime.byOwner.aesri and M.runtime.byOwner.aesri[legacy.id] and M.runtime.byOwner.aesri[missing.id],
  "canonical owner index does not contain owned listing IDs")
assert(M:GetListing(legacy.id).owner == "Aesri-Vol'jin" and M:GetListing(legacy.id).ownerKey == "aesri",
  "visible legacy owner was changed or canonical ownership was not stored")

currentPlayerName = "Aesri-Vol'jin"
U:ClearMyListingsView()
assert(M:GetCurrentOwnerKey() == "aesri" and U:BuildMyListingsView().total == 10,
  "realm-suffixed current player did not match bare owned listings")
currentPlayerName = "Aesri-Any Realm"
U:ClearMyListingsView()
assert(M:GetCurrentOwnerKey() == "aesri" and U:BuildMyListingsView().total == 10,
  "space-containing realm suffix was not stripped from current ownership")
currentPlayerName = "Aesri"

local edited = assert(B:SFMarketplaceEditListing(legacy.id, {itemName="Owned Item Edited"}))
assert(edited.ownerKey == "aesri" and M:OpenWhisper(legacy.id) == false and M:BuildLocalLink(legacy.id),
  "Edit, local link, or self-Whisper did not use canonical owner identity")
assert(U:SetTab("Browse") == true, "Browse did not open for owner-independence check")
local activeOther = false
for _, row in ipairs(U:BuildBrowseSnapshot().rows) do if row.id == other.id then activeOther = true end end
assert(activeOther, "Browse stopped including another active profile owner's listing")
assert(B:SFMarketplaceRemoveListing(expired.id), "expired owned fixture could not be removed before migration cache test")
local legacyCreatedAt, legacyExpiresAt = M:GetListing(legacy.id).createdAt, M:GetListing(legacy.id).expiresAt
local orderBeforeMigration = table.concat(M.runtime.store.listingOrder, "\31")

M.runtime.store.listingsById[legacy.id].ownerKey = "aesri-vol'jin"
M.runtime.store.listingsById[missing.id].ownerKey = nil
local retainedPanel, retainedRows = U.panel, U.myListingsRows
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U:ActiveScriptCount() == 0 and not U.myListingsView and not U.mySelectedListingId, "disable did not clean owned view")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() == true and U.panel == retainedPanel and U.myListingsRows == retainedRows,
  "same-profile re-enable rebuilt retained My Listings controls")
assert(M:GetListing(legacy.id).ownerKey == "aesri" and M:GetListing(missing.id).ownerKey == "aesri"
  and M.runtime.byOwner.aesri[legacy.id] and M.runtime.byOwner.aesri[missing.id],
  "migration and index rebuild did not repair canonical owner keys")
assert(M:GetListing(legacy.id).id == legacy.id and M:GetListing(legacy.id).createdAt == legacyCreatedAt
  and M:GetListing(legacy.id).expiresAt == legacyExpiresAt
  and table.concat(M.runtime.store.listingOrder, "\31") == orderBeforeMigration,
  "owner-key migration changed stable listing identity, lifetime, or order")
assert((tonumber(M.runtime.indexRepairs or 0) or 0) >= 2, "owner-key migration repairs were not reported")

U.myListingsView = {total=0, rows={}, ownerKey="aesri"}
U.myListingsGeneration, U.myListingsProfile, U.myListingsOwnerKey = 1, "Ascension", "aesri"
U.myListingsRuntimeGeneration = (tonumber(M.runtime.generation or 0) or 0) - 1
assert(M.runtime.dataGeneration == 1 and U:BuildMyListingsView().total == 10
  and U.myListingsRuntimeGeneration == M.runtime.generation,
  "replacement runtime reused an old empty My Listings cache")

BronzeLFG_DB.options.serverProfile = "Triumvirate"; B:SFModulesApply()
assert(B:ShowMarketplace() == true and U.panel == retainedPanel and U:BuildMyListingsView().total == 0,
  "old-profile My Listings rows leaked into Triumvirate")
BronzeLFG_DB.options.serverProfile = "Ascension"; B:SFModulesApply()
assert(B:ShowMarketplace() == true and U.panel == retainedPanel and U:BuildMyListingsView().total == 10,
  "returning to Ascension did not restore canonical owned listings")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U:ActiveScriptCount() == 0 and not U.myListingsView and not U.mySelectedListingId, "final disable did not clean owned view")
print("marketplace my listings harness: PASS")
