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

local snapshot, view, rows = U.browseSnapshot, U.browseFilteredView, U.browseRows
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browseSnapshot == snapshot and U.browseFilteredView == view and U.browseRows == rows, "paging rebuilt cache or row pool")
local pageTwoId = U.browseRows[1].listingId
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == pageTwoId, "page two row did not preserve stable id")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2, "Back did not preserve filtered page")

local typeButton, professionButton = U.browseTypeSelector, U.browseProfessionSelector
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(typeButton:GetScript("OnClick") == nil and professionButton:GetScript("OnClick") == nil and U:ActiveScriptCount() == 0,
  "disable retained selector scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browseTypeSelector == typeButton and U.browseProfessionSelector == professionButton
  and U:ActiveScriptCount() == 21, "re-enable duplicated selectors or scripts")
print("marketplace browse type/profession filters harness: PASS")
