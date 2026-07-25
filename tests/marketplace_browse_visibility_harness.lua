local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() == true and B:ShowMarketplace() == true, "Marketplace did not open")
local function add(owner)
  return assert(B:SFMarketplaceCreateListing({owner=owner, listingType="Crafting Offer", profession="Alchemy",
    itemName="Flask", priceMode="Free", location="Dalaran", availability="Today", expiresAt=time()+3600}))
end
add("Visible")
assert(U.browseRowCount == 1, "visible mutation did not render")
assert(B:ShowBrowse() == true and U:GetPanelState() == "hidden", "Marketplace did not hide")
local snapshot, count = U.browseSnapshot, U.browseRowCount
add("Hidden")
assert(U.browseSnapshot == nil and U.browseRowCount == count and U.browseDirty, "hidden mutation rendered Browse")
assert(B:ShowMarketplace() == true and U.browseRowCount == 2 and not U.browseDirty,
  "reopen did not consume dirty Browse state")
assert(B:SFMarketplaceRemoveListing("mkt1:missing") == false, "unexpected removal result")
for _, row in ipairs(U.browseSnapshot.rows) do assert(B:SFMarketplaceRemoveListing(row.id) == true, "remove failed") end
assert(U.browseRowCount == 0 and U.browseEmptyState:IsShown(), "final removal did not restore empty state")
local panel, rows = U.panel, U.browseRows
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() == true and U.panel == panel and U.browseRows == rows and #U.browseRows == 8,
  "disable/re-enable duplicated Browse rows")
print("marketplace browse visibility harness: PASS")
