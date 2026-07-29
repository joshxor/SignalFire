local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

-- WoW 3.3.5's UIDropDownMenuTemplate concatenates the frame name during
-- construction. Guard that real-client constraint before lazy Marketplace build.
local baseCreateFrame, dropdownCreates = CreateFrame, 0
CreateFrame = function(frameType, name, parent, template)
  if template == "UIDropDownMenuTemplate" then
    assert(type(name) == "string" and name ~= "", "UIDropDownMenuTemplate requires a named frame")
    dropdownCreates = dropdownCreates + 1
  end
  return baseCreateFrame(frameType, name, parent, template)
end

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
assert(B:SFModulesApply() and not U.browseTypeSelector and not U.browseProfessionSelector and not U.browseLocationSelector and not U.browseAvailabilitySelector,
  "filter selectors were built eagerly")
assert(B:ShowMarketplace() and U.browseTypeSelector and U.browseProfessionSelector and U.browseLocationSelector and U.browseAvailabilitySelector,
  "filter selectors were not built lazily")
assert(U.browseTypeSelector.menu:GetName() == "SignalFireMarketplaceTypeDropdown151"
  and U.browseProfessionSelector.menu:GetName() == "SignalFireMarketplaceProfessionDropdown151"
  and U.browseLocationSelector.menu:GetName() == "SignalFireMarketplaceLocationDropdown151"
  and U.browseAvailabilitySelector.menu:GetName() == "SignalFireMarketplaceAvailabilityDropdown151"
  and U.browseTypeSelector.menu ~= U.browseProfessionSelector.menu and U.browseLocationSelector.menu ~= U.browseAvailabilitySelector.menu
  and dropdownCreates == 9,
  "Marketplace dropdown menus are not distinct named 3.3.5-compatible frames")
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
assert(U:GetBrowseProfessionKey() == "alchemy" and U.browseFilteredView.total == 3,
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
assert(U.browseFilteredView.total == 3 and U.browseSummary:GetText() == "Showing 1-3 of 3", "filtered page one is incorrect")
professionOptions[1].func()
typeOptions[1].func()
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

-- Keep all three controls active while exercising the bounded combined view.  Ten
-- new Offer/Alchemy/Flask rows force a partially filled second filtered page.
local combined = {}
for number = 12, 21 do
  combined[#combined + 1] = add(number, "Crafting Offer", "Alchemy", "Flask Combined " .. number)
end
local mutable = add(22, "Crafting Request", "Alchemy", "Flask Mutable")
typeOptions = options(U.browseTypeSelector); typeOptions[2].func()
professionOptions = options(U.browseProfessionSelector); professionOptions[2].func()
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseFilteredView.total == 10 and U.browseSummary:GetText() == "Showing 1-8 of 10",
  "combined type, profession, and search page one is incorrect")
local combinedSnapshot, combinedView, combinedRows = U.browseSnapshot, U.browseFilteredView, U.browseRows
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browsePage == 2 and U.browseSummary:GetText() == "Showing 9-10 of 10" and U.browseSnapshot == combinedSnapshot
  and U.browseFilteredView == combinedView and U.browseRows == combinedRows, "combined page two did not reuse snapshot, view, and rows")
U.browsePrevious:GetScript("OnClick")(U.browsePrevious)
assert(U.browsePage == 1 and U.browseSummary:GetText() == "Showing 1-8 of 10" and U.browseSnapshot == combinedSnapshot
  and U.browseFilteredView == combinedView and U.browseRows == combinedRows, "combined Previous rebuilt cache or row pool")
U.browseNext:GetScript("OnClick")(U.browseNext)
local combinedPageTwoId = U.browseRows[1].listingId
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
assert(U.selectedListingId == combinedPageTwoId, "combined page-two row lost its exact stable id")
U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2 and U:GetAppliedBrowseQuery() == "flask" and U:GetBrowseListingType() == "Crafting Offer"
  and U:GetBrowseProfessionKey() == "alchemy" and U.browseSummary:GetText() == "Showing 9-10 of 10",
  "Back did not preserve full combined state")
U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1])
browse:GetScript("OnClick")(browse)
assert(U.browsePage == 2 and U:GetAppliedBrowseQuery() == "flask" and U:GetBrowseListingType() == "Crafting Offer"
  and U:GetBrowseProfessionKey() == "alchemy" and U.browseSummary:GetText() == "Showing 9-10 of 10",
  "Browse navigation did not preserve detail combined state")
for _, button in ipairs({myListings, create, favorites}) do
  button:GetScript("OnClick")(button)
  assert(not U.browseTypeSelector:IsShown() and not U.browseProfessionSelector:IsShown(), "active-state tab did not hide selectors")
end
browse:GetScript("OnClick")(browse)
assert(U.browseTypeSelector:IsShown() and U.browseProfessionSelector:IsShown() and U.browseSearchBox:IsShown()
  and U.browsePage == 2 and U:GetAppliedBrowseQuery() == "flask" and U:GetBrowseListingType() == "Crafting Offer"
  and U:GetBrowseProfessionKey() == "alchemy", "Browse did not restore active combined controls")

local beforeMutation = U.browseFilteredView.total
assert(B:SFMarketplaceEditListing(mutable.id, {listingType="Crafting Offer"}), "mutable listing did not enter combined results")
assert(U.browseFilteredView.total == beforeMutation + 1, "visible edit did not enter combined results")
local entered = false
for _, row in ipairs(U.browseFilteredView.rows) do if row.id == mutable.id then entered = true end end
assert(entered, "entered listing is absent from the exact combined view")
assert(B:SFMarketplaceEditListing(mutable.id, {listingType="Crafting Request"}), "mutable listing did not leave combined results")
assert(U.browseFilteredView.total == beforeMutation, "visible edit did not leave combined results")
for _, row in ipairs(U.browseFilteredView.rows) do assert(row.id ~= mutable.id, "left listing remains in combined view") end

-- Remove the partially filled final page through the public API; visible Browse
-- must clamp rather than leave an empty page while retaining the active state.
U.browsePage = 2; U:RenderBrowse()
assert(B:SFMarketplaceRemoveListing(U.browseFilteredView.rows[9].id) and B:SFMarketplaceRemoveListing(U.browseFilteredView.rows[9].id),
  "combined final-page removals failed")
assert(U.browsePage == 1 and U.browseSummary:GetText() == "Showing 1-8 of 8" and U:GetAppliedBrowseQuery() == "flask"
  and U:GetBrowseListingType() == "Crafting Offer" and U:GetBrowseProfessionKey() == "alchemy", "removal did not clamp combined page")

local unique = add(23, "Crafting Offer", "Leatherworking", "Flask Unique Profession")
professionOptions = options(U.browseProfessionSelector)
local uniqueOption
for _, option in ipairs(professionOptions) do if option.value == "leatherworking" then uniqueOption = option end end
assert(uniqueOption, "unique profession option is missing")
uniqueOption.func()
assert(U:GetBrowseProfessionKey() == "leatherworking" and U.browseProfessionSelector.label:GetText() == "Leatherworking", "unique profession selection is incorrect")
assert(B:SFMarketplaceRemoveListing(unique.id), "unique profession removal failed")
assert(U:GetBrowseProfessionKey() == "" and U.browseProfessionSelector.label:GetText() == "All Professions" and U.browsePage == 1
  and U:GetBrowseListingType() == "Crafting Offer" and U:GetAppliedBrowseQuery() == "flask", "selected profession invalidation did not preserve other state")

-- Hidden mutations must only dirty Browse; instrument retained labels and row text
-- to prove no rendering occurs until actual Browse navigation returns.
local writes = {rows=0, type=0, profession=0, summary=0, page=0}
local originals = {}
local function watch(object, key)
  originals[object] = object.SetText
  object.SetText = function(self, value) writes[key] = writes[key] + 1; return originals[self](self, value) end
end
for _, row in ipairs(U.browseRows) do for _, label in ipairs(row.labels) do watch(label, "rows") end end
watch(U.browseTypeSelector.label, "type"); watch(U.browseProfessionSelector.label, "profession")
watch(U.browseSummary, "summary"); watch(U.browsePageIndicator, "page")
myListings:GetScript("OnClick")(myListings)
local hidden = add(24, "Crafting Offer", "Alchemy", "Flask Hidden Mutation")
assert(U.browseDirty or not U.browseFilteredView, "hidden mutation did not invalidate Browse")
assert(writes.rows == 0 and writes.type == 0 and writes.profession == 0 and writes.summary == 0 and writes.page == 0,
  "hidden mutation wrote Browse controls")
for object, original in pairs(originals) do object.SetText = original end
browse:GetScript("OnClick")(browse)
local hiddenFound = false
for _, row in ipairs(U.browseFilteredView.rows) do if row.id == hidden.id then hiddenFound = true end end
assert(hiddenFound and not U.browseDirty, "returning to Browse did not consume hidden mutation")

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
local typeMenu, professionMenu = typeButton.menu, professionButton.menu
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = false; B:SFModulesApply()
assert(typeButton:GetScript("OnClick") == nil and professionButton:GetScript("OnClick") == nil and U:ActiveScriptCount() == 0,
  "disable retained selector scripts")
assert(U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions"
  and U:GetAppliedBrowseQuery() == "" and U.browsePage == 1, "disable retained stale filter state or labels")
BronzeLFG_DB.options.modulesByProfile.Triumvirate.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browseTypeSelector == typeButton and U.browseProfessionSelector == professionButton
  and U.browseTypeSelector.menu == typeMenu and U.browseProfessionSelector.menu == professionMenu and dropdownCreates == 9
  and U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions"
  and U:ActiveScriptCount() == 72, "re-enable duplicated selectors, menus, or scripts")
print("marketplace browse type/profession filters harness: PASS")
