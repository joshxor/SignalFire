local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")
local row = assert(B:SFMarketplaceCreateListing({owner="Detail Owner", listingType="Crafting Offer", profession="Alchemy",
  itemName="Long Item", recipeName="", materialsPolicy="Customer Provides", priceMode="Fixed Price", priceCopper=12345,
  location="Dalaran", availability="Today", notes="", expiresAt=time()+7200}))
local pooled = U.browseRows
assert(U.browseRows[1]:GetScript("OnMouseUp"), "populated row is not clickable")
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == row.id, "populated row did not select exact id")
assert(U.detailValues[1]:GetText() == "Detail Owner" and U.detailValues[5]:GetText() == "None"
  and U.detailValues[11]:GetText() == "No notes.", "detail fields are incorrect")
assert(U:SelectBrowseRow(U.browseRows[8]) == false, "unused row performed an action")
assert(U.detailBack:GetScript("OnClick"), "Back button is not clickable")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browseRows == pooled and not U.selectedListingId and not U.browseDetail:IsShown()
  and U.browseTableHeader:IsShown() and U.browseScrollArea:IsShown(), "Back did not restore Browse controls")
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
local browseButton
for _, button in ipairs(U.navButtons) do if button.marketplaceTab == "Browse" then browseButton = button end end
assert(browseButton and browseButton:GetScript("OnClick"), "Browse navigation is not clickable")
browseButton:GetScript("OnClick")(browseButton)
assert(not U.selectedListingId and not U.browseDetail:IsShown() and U.browseTableHeader:IsShown()
  and U.browseScrollArea:IsShown(), "Browse navigation did not close detail")
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(B:SFMarketplaceEditListing(row.id, {notes="Updated"}) and U.detailValues[11]:GetText() == "Updated", "edit did not refresh detail")
assert(B:SFMarketplaceRemoveListing(row.id) and not U.selectedListingId and U.browseDetail:IsShown() == false, "remove did not restore Browse")
assert(U:SelectBrowseRow(U.browseRows[1]) == false, "removed row remained selectable")
assert(U:SetTab("Favorites") and not U.selectedListingId, "tab switch retained selection")
U.selectedListingId = row.id; U:Enable("Different Profile")
assert(not U.selectedListingId, "profile change retained selection")
U:Enable("Ascension")
local panel, detail = U.panel, U.browseDetail
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U.browseRows[1]:GetScript("OnMouseUp") == nil and U.detailBack:GetScript("OnClick") == nil, "disable retained detail scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.panel == panel and U.browseDetail == detail, "re-enable duplicated controls")
print("marketplace browse detail harness: PASS")

