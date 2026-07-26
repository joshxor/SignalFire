local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")
assert(U.browseEmptyState:IsShown() and U.browseSummary:GetText() == "" and not U.browseNext:IsShown(), "empty Browse has usable paging")
local function add(number)
  return assert(B:SFMarketplaceCreateListing({owner="Owner " .. tostring(number), listingType="Crafting Offer", profession="Alchemy",
    itemName="Item " .. tostring(number), materialsPolicy="Customer Provides", priceMode="Free", location="Dalaran",
    availability="Today", expiresAt=time()+7200}))
end
for number = 1, 8 do add(number) end
assert(U.browsePage == 1 and U.browseSummary:GetText() == "Showing 1-8 of 8" and not U.browseNext:IsShown(), "one page is incorrect")
for number = 9, 18 do add(number) end
local pooled, snapshot = U.browseRows, U.browseSnapshot
assert(U.browsePageIndicator:GetText() == "Page 1 of 3" and U.browseSummary:GetText() == "Showing 1-8 of 18"
  and U.browseRows[1].labels[1]:GetText() == "Owner 18", "page one is incorrect")
local nextClick = assert(U.browseNext:GetScript("OnClick"), "Next button is not clickable")
nextClick(U.browseNext)
assert(U.browsePage == 2 and U.browseSnapshot == snapshot
  and U.browseRows == pooled and U.browseSummary:GetText() == "Showing 9-16 of 18"
  and U.browseRows[1].labels[1]:GetText() == "Owner 10", "page two is incorrect")
local pageTwoId = U.browseRows[1].listingId
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == pageTwoId, "page two row did not keep exact listing id")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2 and U.browseRows[1].listingId == pageTwoId, "Back did not restore page two")
nextClick(U.browseNext)
assert(U.browsePage == 3 and U.browseSummary:GetText() == "Showing 17-18 of 18"
  and U.browseRows[1].labels[1]:GetText() == "Owner 2", "page three is incorrect")
nextClick(U.browseNext)
assert(U.browsePage == 3, "Next changed the final page")
local previousClick = assert(U.browsePrevious:GetScript("OnClick"), "Previous button is not clickable")
previousClick(U.browsePrevious)
assert(U.browsePage == 2, "Previous did not navigate")
-- Remove through the authoritative current snapshot to exercise page clamping.
while U.browseSnapshot.total > 8 do assert(B:SFMarketplaceRemoveListing(U.browseSnapshot.rows[#U.browseSnapshot.rows].id)) end
assert(U.browsePage == 1 and U.browseSummary:GetText() == "Showing 1-8 of 8", "removal did not clamp page")
while U.browseSnapshot.total > 0 do assert(B:SFMarketplaceRemoveListing(U.browseSnapshot.rows[1].id)) end
assert(U.browsePage == 1 and U.browseEmptyState:IsShown() and not U.browseNext:IsShown(), "empty reset is incorrect")
U.browsePage = 3; U:Enable("Different Profile")
assert(U.browsePage == 1, "profile change did not reset page")
U:Enable("Ascension")
local previous, nextButton = U.browsePrevious, U.browseNext
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(previous:GetScript("OnClick") == nil and nextButton:GetScript("OnClick") == nil, "disable retained paging scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browsePrevious == previous and U.browseNext == nextButton, "re-enable duplicated paging controls")
print("marketplace browse paging harness: PASS")
