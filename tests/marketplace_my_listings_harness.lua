local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
function UnitName(unit) if unit == "player" then return "Aesri" end end
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")

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
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U:ActiveScriptCount() == 0 and not U.myListingsView and not U.mySelectedListingId, "disable did not clean owned view")
print("marketplace my listings harness: PASS")
