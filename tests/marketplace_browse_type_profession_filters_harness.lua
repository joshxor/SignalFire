local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

-- Narrow local dropdown stub: it records the production initializer and the
-- actual option callbacks, so this harness never calls the internal setter.
function UIDropDownMenu_Initialize(menu, initializer) menu.initialize = initializer end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) table.insert(_G.__mktMenuButtons, info) end
function ToggleDropDownMenu(_, _, menu) menu.opened = true end
function CloseDropDownMenus() end

local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() and not U.browseTypeSelector and not U.browseProfessionSelector,
  "filter selectors were built eagerly")
assert(B:ShowMarketplace() and U.browseTypeSelector and U.browseProfessionSelector,
  "filter selectors were not built lazily")
assert(U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions",
  "filter defaults are incorrect")

local function add(number, listingType, profession, item)
  return assert(B:SFMarketplaceCreateListing({owner="Owner " .. number, listingType=listingType, profession=profession,
    itemName=item or (profession .. " Item " .. number), materialsPolicy="Customer Provides", priceMode="Free",
    location="Dalaran", availability="Today", expiresAt=time()+7200}))
end
for number = 1, 10 do add(number, number % 2 == 0 and "Crafting Request" or "Crafting Offer", number % 3 == 0 and "Blacksmithing" or "Alchemy", number % 2 == 0 and "Flask" or "Sword") end
add(11, "Crafting Offer", "Enchanting", "Flask Enchant")

local function options(selector)
  selector:GetScript("OnClick")(selector)
  _G.__mktMenuButtons = {}
  selector.menu.initialize(selector.menu, 1)
  return _G.__mktMenuButtons
end
local typeOptions = options(U.browseTypeSelector)
assert(#typeOptions == 3 and typeOptions[1].text == "All Types" and typeOptions[2].text == "Crafting Offer"
  and typeOptions[3].text == "Crafting Request", "listing type options are not exact")
local professionOptions = options(U.browseProfessionSelector)
assert(professionOptions[1].text == "All Professions" and professionOptions[2].text == "Alchemy"
  and professionOptions[3].text == "Blacksmithing" and professionOptions[4].text == "Enchanting", "profession options are not unique and alphabetical")

typeOptions[2].func()
assert(U:GetBrowseListingType() == "Crafting Offer" and U.browsePage == 1 and U.browseFilteredView.total == 6,
  "type selector did not apply exact Crafting Offer filtering")
typeOptions[3].func()
assert(U:GetBrowseListingType() == "Crafting Request" and U.browseFilteredView.total == 5,
  "type selector did not apply exact Crafting Request filtering")
typeOptions[2].func()
professionOptions[2].func()
assert(U:GetBrowseProfessionKey() == "alchemy" and U.browseFilteredView.total == 4,
  "profession selector did not apply exact normalized key filtering")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseFilteredView.total == 0 and U.browseEmptyState:GetText() == "No marketplace listings match your search and filters.",
  "combined search and filters are not ANDed")
U.browseClear:GetScript("OnClick")(U.browseClear)
assert(U:GetBrowseListingType() == "Crafting Offer" and U:GetBrowseProfessionKey() == "alchemy", "Search Clear cleared a dropdown filter")
typeOptions[1].func()
assert(U:GetBrowseListingType() == "" and U:GetBrowseProfessionKey() == "alchemy", "All Types cleared the wrong filter")
professionOptions[1].func()
assert(U:GetBrowseProfessionKey() == "", "All Professions did not clear only the profession filter")

-- A repeated active choice is a close-only operation: it must not replace either
-- bounded cache object or force row writes.
typeOptions[2].func()
local sameSnapshot, sameView = U.browseSnapshot, U.browseFilteredView
typeOptions[2].func()
assert(U.browseSnapshot == sameSnapshot and U.browseFilteredView == sameView, "reselecting a type rebuilt caches")
professionOptions = options(U.browseProfessionSelector)
professionOptions[4].func()
assert(U.browseFilteredView.total == 1, "exact profession matching is incorrect")
U.browseSearchBox:SetText("missing"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseEmptyState:GetText() == "No marketplace listings match your search and filters." and U.browseSummary:GetText() == ""
  and not U.browseRows[1]:IsShown() and not U.browseNext:IsShown(), "search/filter zero state is incorrect")
U.browseClear:GetScript("OnClick")(U.browseClear)
assert(U.browseFilteredView.total == 1, "search clear did not preserve active filters")
typeOptions[1].func()
professionOptions = options(U.browseProfessionSelector)
professionOptions[4].func()
assert(U.browseFilteredView.total == 1, "profession-only exact match setup failed")
U.browseSearchBox:SetText("missing"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
U.browseClear:GetScript("OnClick")(U.browseClear)
typeOptions[3].func()
assert(U.browseFilteredView.total == 0 and U.browseEmptyState:GetText() == "No marketplace listings match your filters."
  and U.browseSummary:GetText() == "" and not U.browseRows[1]:IsShown() and not U.browseNext:IsShown(), "type-only zero state is incorrect")
typeOptions[1].func()
professionOptions[2].func()
U.browseSearchBox:SetText("missing"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
professionOptions[1].func()
assert(U.browseEmptyState:GetText() == "No marketplace listings match your search.", "search-only zero state changed")
U.browseClear:GetScript("OnClick")(U.browseClear)

typeOptions[2].func(); professionOptions = options(U.browseProfessionSelector); professionOptions[2].func()
assert(U.browseFilteredView.total == 4 and U.browseSummary:GetText() == "Showing 1-4 of 4", "filtered page one is incorrect")
professionOptions[1].func()
local snapshot, view, rows = U.browseSnapshot, U.browseFilteredView, U.browseRows
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browsePage == 2 and U.browseSummary:GetText() == "Showing 9-11 of 11" and U.browseSnapshot == snapshot
  and U.browseFilteredView == view and U.browseRows == rows, "paging rebuilt cache or row pool")
local pageTwoId = U.browseRows[1].listingId
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == pageTwoId, "page two row did not preserve stable id")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2 and U:GetBrowseListingType() == "" and U:GetBrowseProfessionKey() == "", "Back did not preserve filtered page")
local browse, myListings, create, favorites
for _, button in ipairs(U.navButtons) do
  if button.marketplaceTab == "Browse" then browse = button elseif button.marketplaceTab == "My Listings" then myListings = button
  elseif button.marketplaceTab == "Create Listing" then create = button elseif button.marketplaceTab == "Favorites" then favorites = button end
end
for _, button in ipairs({myListings, create, favorites}) do
  button:GetScript("OnClick")(button)
  assert(not U.browseTypeSelector:IsShown() and not U.browseProfessionSelector:IsShown(), "tab did not hide selectors")
end
browse:GetScript("OnClick")(browse)
assert(U.browseTypeSelector:IsShown() and U.browseProfessionSelector:IsShown() and U.browsePage == 2, "Browse did not restore selectors and page")

-- Profile switching while hidden must reset both retained labels, not merely the
-- backing session values.
typeOptions[2].func(); professionOptions = options(U.browseProfessionSelector); professionOptions[2].func()
U.browseSearchBox:SetText("sword"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
B:ShowBrowse()
BronzeLFG_DB.options.serverProfile = "Triumvirate"
BronzeLFG_DB.options.modulesByProfile.Triumvirate = {tradeskillMarketplace=true}
B:SFModulesApply()
assert(U:GetBrowseListingType() == "" and U:GetBrowseProfessionKey() == "" and U:GetAppliedBrowseQuery() == "" and U.browsePage == 1
  and U.browseSearchBox:GetText() == "" and U.browseTypeSelector.label:GetText() == "All Types"
  and U.browseProfessionSelector.label:GetText() == "All Professions", "hidden profile change retained stale selector labels")

local typeButton, professionButton = U.browseTypeSelector, U.browseProfessionSelector
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = false; B:SFModulesApply()
assert(typeButton:GetScript("OnClick") == nil and professionButton:GetScript("OnClick") == nil and U:ActiveScriptCount() == 0,
  "disable retained selector scripts")
assert(U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions"
  and U:GetAppliedBrowseQuery() == "" and U.browsePage == 1, "disable retained stale filter state or labels")
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browseTypeSelector == typeButton and U.browseProfessionSelector == professionButton
  and U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions"
  and U:ActiveScriptCount() == 21, "re-enable duplicated selectors, menus, or scripts")
print("marketplace browse type/profession filters harness: PASS")
