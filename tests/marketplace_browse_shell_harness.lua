local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local U = assert(SignalFireMarketplaceUI151, "Marketplace UI owner did not load")

BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true
assert(B:SFModulesApply() == true, "Marketplace did not enable")
assert(not U.panel and U.buildCount == 0, "Browse shell built before first open")
assert(B:ShowMarketplace() == true, "Marketplace did not open")

local expected = {"Player", "Type", "Profession", "Item / Recipe", "Location", "Availability", "Price / Tip", "Expires"}
assert(#U.browseTableHeaders == #expected, "Browse column count is incorrect")
for index, title in ipairs(expected) do
  assert(U.browseTableHeaders[index]:GetText() == title, "missing Browse header: " .. title)
end
assert(U.browseScrollArea and U.browseRowsArea, "Browse reserved scroll area is missing")
assert(U.browseRowCount == 0, "Browse shell created listing rows")
assert(U.browseEmptyState:GetText() == "No marketplace listings available.", "Browse empty state is incorrect")

local panel, headers = U.panel, U.browseTableHeaders
assert(B:ShowBrowse() == true, "Browse navigation away failed")
assert(B:ShowMarketplace() == true, "Browse return failed")
assert(U.selectedTab == "Browse", "Browse is not the default Marketplace tab")
assert(U.panel == panel and U.browseTableHeaders == headers and U.buildCount == 1,
  "Browse return rebuilt shell controls")

print("marketplace browse shell harness: PASS (headers=" .. tostring(#U.browseTableHeaders) .. ")")
