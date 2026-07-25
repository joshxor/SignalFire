local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension = {tradeskillMarketplace=true}
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")
assert(U.browseEmptyState:IsShown() and #U.browseRows == 8, "empty Browse pool is incorrect")

local function create(index)
  return assert(B:SFMarketplaceCreateListing({owner="Owner" .. index, listingType="Crafting Offer",
    profession="Alchemy", itemName="Item" .. index, recipeName=index == 1 and "Recipe" or "",
    priceMode=index == 1 and "Tip" or "Fixed Price", priceCopper=index == 10 and 12345 or 0,
    location="Dalaran", availability="Available Now", expiresAt=time() + 7200}))
end
local first = create(1)
assert(U.browseRowCount == 1 and not U.browseEmptyState:IsShown(), "one listing did not render")
assert(U.browseRows[1].labels[1]:GetText() == "Owner1" and U.browseRows[1].labels[4]:GetText() == "Item1 / Recipe"
  and U.browseRows[1].labels[7]:GetText() == "Tip", "first row columns are incorrect")
local snapshot, signature = U.browseSnapshot, U.browseRows[1].signature
assert(U:RenderBrowse() == true and U.browseSnapshot == snapshot and U.browseRows[1].signature == signature,
  "unchanged generation did not reuse snapshot/signature")
for index = 2, 10 do create(index) end
assert(U.browseRowCount == 8 and U.browseSummary:GetText() == "Showing 8 of 10", "row cap summary is incorrect")
assert(U.browseRows[1].labels[1]:GetText() == "Owner10", "newest listing is not first")
assert(U.browseRows[1].labels[7]:GetText() == "1g 23s 45c", "fixed price formatting is incorrect")
for index = 1, 8 do assert(U.browseRows[index]:IsShown(), "expected visible row " .. index) end
print("marketplace browse rows harness: PASS (shown=" .. tostring(U.browseRowCount) .. ")")
