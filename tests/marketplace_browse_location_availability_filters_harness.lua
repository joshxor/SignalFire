local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local baseCreateFrame, dropdownCreates = CreateFrame, 0
CreateFrame = function(frameType, name, parent, template)
  if template == "UIDropDownMenuTemplate" then
    assert(type(name) == "string" and name ~= "", "UIDropDownMenuTemplate requires a named frame")
    dropdownCreates = dropdownCreates + 1
  end
  return baseCreateFrame(frameType, name, parent, template)
end
function UIDropDownMenu_Initialize(menu, initializer) menu.initialize = initializer end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) table.insert(_G.__mktMenuButtons, info) end
function ToggleDropDownMenu(_, _, menu) menu.opened = true end
function CloseDropDownMenus() end

local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() and not U.browseLocationSelector and not U.browseAvailabilitySelector, "new selectors were built eagerly")
assert(B:ShowMarketplace() and U.browseLocationSelector and U.browseAvailabilitySelector, "new selectors were not lazy")

local selectors = {U.browseTypeSelector, U.browseProfessionSelector, U.browseLocationSelector, U.browseAvailabilitySelector}
local names, seen = {}, {}
for _, selector in ipairs(selectors) do
  local name = selector.menu:GetName()
  assert(type(name) == "string" and name ~= "" and not seen[name], "dropdown names are not stable and distinct")
  seen[name], names[#names + 1] = true, name
end
assert(names[3] == "SignalFireMarketplaceLocationDropdown151" and names[4] == "SignalFireMarketplaceAvailabilityDropdown151"
  and dropdownCreates == 9 and U.browseLocationSelector.label:GetText() == "All Locations"
  and U.browseAvailabilitySelector.label:GetText() == "All Availability", "selector defaults or dropdown ownership are incorrect")

local function add(number, location, availability, listingType, profession, item)
  return assert(B:SFMarketplaceCreateListing({owner="Owner " .. number, listingType=listingType or "Crafting Offer", profession=profession or "Alchemy",
    itemName=item or "Flask " .. number, materialsPolicy="Customer Provides", priceMode="Free", location=location,
    availability=availability, expiresAt=time()+7200}))
end
local rows = {}
for number = 1, 10 do rows[#rows + 1] = add(number, number % 2 == 0 and "Dalaran" or "Booty Bay", number % 3 == 0 and "Today" or "Available Now") end
rows[#rows + 1] = add(11, "Dalaran", "Scheduled", "Crafting Request", "Blacksmithing", "Sword")

local function options(selector)
  selector:GetScript("OnClick")(selector)
  _G.__mktMenuButtons = {}
  selector.menu.initialize(selector.menu, 1)
  return _G.__mktMenuButtons
end
local locations, availability = options(U.browseLocationSelector), options(U.browseAvailabilitySelector)
assert(#locations == 3 and locations[1].text == "All Locations" and locations[2].text == "Booty Bay" and locations[3].text == "Dalaran",
  "locations are not unique and alphabetical by locationKey")
assert(#availability == 5 and availability[1].text == "All Availability" and availability[2].text == "Available Now"
  and availability[3].text == "Today" and availability[4].text == "This Session" and availability[5].text == "Scheduled", "availability options are not exact")

locations[3].func()
assert(U:GetBrowseLocationKey() == "dalaran" and U.browseFilteredView.total == 6 and U.browsePage == 1, "location filtering is not exact")
availability[3].func()
assert(U:GetBrowseAvailability() == "Today" and U.browseFilteredView.total == 1, "availability filtering is not exact")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseFilteredView.total == 1, "location, availability, and search are not ANDed")
U.browseClear:GetScript("OnClick")(U.browseClear)
assert(U:GetBrowseLocationKey() == "dalaran" and U:GetBrowseAvailability() == "Today", "search clear changed dropdown filters")
availability[1].func(); locations[1].func()
assert(U:GetBrowseLocationKey() == "" and U:GetBrowseAvailability() == "", "All selectors did not clear only themselves")

local snapshot, view, pool = U.browseSnapshot, U.browseFilteredView, U.browseRows
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browsePage == 2 and U.browseSnapshot == snapshot and U.browseFilteredView == view and U.browseRows == pool, "paging rebuilt Browse caches or pool")
local page = U.browsePage
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1]); U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == page, "details did not preserve Browse page")
for _, button in ipairs(U.navButtons) do
  if button.marketplaceTab ~= "Browse" then
    button:GetScript("OnClick")(button)
    assert(not U.browseTypeSelector:IsShown() and not U.browseProfessionSelector:IsShown() and not U.browseLocationSelector:IsShown() and not U.browseAvailabilitySelector:IsShown(), "tab left a selector visible")
  end
end
for _, button in ipairs(U.navButtons) do if button.marketplaceTab == "Browse" then button:GetScript("OnClick")(button) end end
assert(U.browseLocationSelector:IsShown() and U.browseAvailabilitySelector:IsShown() and U.browsePage == page, "Browse did not restore retained state")

locations = options(U.browseLocationSelector); locations[2].func()
assert(U:GetBrowseLocationKey() == "booty bay", "location selection setup failed")
for _, row in ipairs(rows) do if row.location == "Booty Bay" then assert(B:SFMarketplaceRemoveListing(row.id), "location removal failed") end end
assert(U:GetBrowseLocationKey() == "" and U.browseLocationSelector.label:GetText() == "All Locations", "invalid location did not reset")

BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U.browseLocationSelector:GetScript("OnClick") == nil and U.browseAvailabilitySelector:GetScript("OnClick") == nil and U:ActiveScriptCount() == 0, "disable retained new scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U:ActiveScriptCount() == 49 and U.browseLocationSelector.menu:GetName() == names[3]
  and U.browseAvailabilitySelector.menu:GetName() == names[4] and dropdownCreates == 9, "re-enable duplicated selectors or dropdowns")
print("marketplace browse location/availability filters harness: PASS")
