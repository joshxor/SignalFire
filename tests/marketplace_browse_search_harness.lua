local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)

local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() == true and not U.browseSearchBox, "search controls were built eagerly")
assert(B:ShowMarketplace() == true and U.browseSearchBox and U.browseSearchButton and U.browseClear,
  "search controls were not built lazily")

local function add(index, item, recipe, extra)
  extra = extra or {}
  return assert(B:SFMarketplaceCreateListing({owner=extra.owner or ("Owner " .. index), listingType="Crafting Offer",
    profession=extra.profession or "Alchemy", itemName=item, recipeName=recipe or "", materialsPolicy="Customer Provides",
    priceMode="Free", location=extra.location or "Dalaran", availability="Today", notes=extra.notes or "",
    expiresAt=time()+7200}))
end
local other = add(1, "Other Item", "")
for index = 2, 10 do add(index, "Flask Item " .. index, "") end
local recipe = add(11, "Stone", "Greater Flask Mastery")
add(12, "Stone", "", {owner="Flask Player", profession="Flask Profession", location="Flask Location", notes="Flask Notes"})
assert(U.browseSnapshot.total == 12 and U:GetAppliedBrowseQuery() == "", "empty search did not preserve unfiltered view")

U.browseSearchBox:SetText("FLASK")
assert(U.browseSearchButton:GetScript("OnClick"), "Search lacks OnClick")
U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U:GetAppliedBrowseQuery() == "flask" and U.browseFilteredView.total == 10 and U.browseSummary:GetText() == "Showing 1-8 of 10",
  "Search button or case-insensitive item/recipe matching is incorrect")
assert(U.browseFilteredView.rows[1].id == recipe.id, "newest-first filtered order changed")
assert(U.browseSearchBox:GetText() == "FLASK", "applied raw entry changed unexpectedly")
local snapshot, filtered, rows = U.browseSnapshot, U.browseFilteredView, U.browseRows
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browsePage == 2 and U.browseSnapshot == snapshot and U.browseFilteredView == filtered and U.browseRows == rows
  and U.browseSummary:GetText() == "Showing 9-10 of 10", "search paging rebuilt a cached view or row pool")
local pageTwoId = U.browseRows[1].listingId
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == pageTwoId and not U.browseSearchBox:IsShown(), "page two selection did not hide search")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2 and U:GetAppliedBrowseQuery() == "flask" and U.browseSearchBox:IsShown(), "Back did not preserve search page")
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
local browseButton; for _, button in ipairs(U.navButtons) do if button.marketplaceTab == "Browse" then browseButton = button end end
browseButton:GetScript("OnClick")(browseButton)
assert(U.browsePage == 2 and U:GetAppliedBrowseQuery() == "flask", "Browse navigation did not preserve search page")

U.browseSearchBox:SetText("greater")
assert(U.browseSearchBox:GetScript("OnEnterPressed"), "EditBox lacks OnEnterPressed")
U.browseSearchBox:GetScript("OnEnterPressed")(U.browseSearchBox)
assert(U.browsePage == 1 and U.browseFilteredView.total == 1 and U.browseRows[1].listingId == recipe.id,
  "Enter did not apply recipe search and reset page")
U.browseSearchBox:SetText(" flask   ")
U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseFilteredView.total == 10, "trimmed matching is incorrect")
for _, query in ipairs({"player", "profession", "location", "notes"}) do
  U.browseSearchBox:SetText(query); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
  assert(U.browseFilteredView.total == 0, "non-item field matched " .. query)
end
assert(U.browseEmptyState:GetText() == "No marketplace listings match your search." and U.browseSummary:GetText() == ""
  and not U.browseRows[1]:IsShown() and not U.browseNext:IsShown(), "zero-search state is incorrect")
U.browseSearchBox:SetText("   "); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U:GetAppliedBrowseQuery() == "" and U.browseSearchBox:GetText() == "" and U.browseFilteredView.total == 12,
  "whitespace query did not clear search")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseClear:GetScript("OnClick"), "Clear lacks OnClick")
U.browseClear:GetScript("OnClick")(U.browseClear)
assert(U:GetAppliedBrowseQuery() == "" and U.browseFilteredView.total == 12, "Clear did not restore all listings")
assert(B:SFMarketplaceEditListing(other.id, {itemName="Flask Entered"}), "edit failed")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseFilteredView.total == 11, "visible edit did not enter search")
assert(B:SFMarketplaceEditListing(other.id, {itemName="Other Item"}) and U.browseFilteredView.total == 10,
  "visible edit did not leave search")
U:ChangeBrowsePage(1)
assert(B:SFMarketplaceRemoveListing(U.browseFilteredView.rows[1].id) and U.browsePage == 2, "first removal unexpectedly changed matched page")
assert(B:SFMarketplaceRemoveListing(U.browseFilteredView.rows[1].id) and U.browsePage == 1, "removal did not clamp matched page")
U.browseSearchBox:SetText("flask"); U.browseSearchBox:GetScript("OnEscapePressed")(U.browseSearchBox)
assert(U:GetAppliedBrowseQuery() == "flask", "Escape changed applied query")
U:Enable("Different Profile")
assert(U:GetAppliedBrowseQuery() == "" and U.browseSearchBox:GetText() == "" and U.browsePage == 1, "profile change did not reset search")
U:Enable("Ascension")
local box, search, clear = U.browseSearchBox, U.browseSearchButton, U.browseClear
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(search:GetScript("OnClick") == nil and clear:GetScript("OnClick") == nil and box:GetScript("OnEnterPressed") == nil
  and box:GetScript("OnEscapePressed") == nil, "disable retained search scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browseSearchBox == box and U.browseSearchButton == search and U.browseClear == clear,
  "re-enable duplicated search controls")
print("marketplace browse search harness: PASS")
