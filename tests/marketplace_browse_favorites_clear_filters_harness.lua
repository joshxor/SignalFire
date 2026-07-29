local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)
function UIDropDownMenu_Initialize(menu, initializer) menu.initialize = initializer end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) table.insert(_G.__mktMenuButtons, info) end
function ToggleDropDownMenu(_, _, menu) menu.opened = true end
function CloseDropDownMenus() end

local B, M, U = assert(BronzeLFG), assert(SignalFireMarketplace151), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = {Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() and not U.browseFavoritesButton and not U.browseClearFilters, "Pass B controls were eager")
assert(B:ShowMarketplace() and U.browseFavoritesButton and U.browseClearFilters and #U.browseRows == 8, "Pass B controls were not lazy")
assert(U.panel:GetWidth() == 820 and U.panel:GetHeight() == 520, "Marketplace panel dimensions are wrong")
assert(U.browseShell:GetWidth() == 780 and U.browseShell:GetHeight() == 352, "Browse shell dimensions are wrong")
assert(#U.browseRows == 8, "Browse row pool is wrong")
assert(U.browseTypeSelector and U.browseProfessionSelector and U.browseLocationSelector and U.browseAvailabilitySelector,
  "Browse selectors are missing")
assert(U.browseFavoritesButton and U.browseSearchLabel and U.browseSearchBox and U.browseSearchButton and U.browseClear and U.browseClearFilters,
  "Browse toolbar controls are missing")
assert(U.browseFavoritesButton:GetWidth() == 54 and U.browseClearFilters:GetWidth() == 64, "Browse toolbar dimensions are wrong")
assert(not U.browseFavoritesOnly and not U:HasActiveBrowseFilters(), "Browse filter backing defaults are wrong")
assert(U:GetBrowseListingType() == "" and U:GetBrowseProfessionKey() == "" and U:GetBrowseLocationKey() == ""
  and U:GetBrowseAvailability() == "" and U:GetAppliedBrowseQuery() == "", "Browse normalized defaults are wrong")
assert((tonumber(U.browsePage or 1) or 1) == 1, "Browse effective page default is wrong")
assert(U.browseTypeSelector.label:GetText() == "All Types" and U.browseProfessionSelector.label:GetText() == "All Professions"
  and U.browseLocationSelector.label:GetText() == "All Locations" and U.browseAvailabilitySelector.label:GetText() == "All Availability",
  "Browse selector labels are wrong")

local function add(number, favored, location, availability, listingType, profession, item)
  local row = assert(B:SFMarketplaceCreateListing({owner="Owner " .. number, listingType=listingType or "Crafting Offer", profession=profession or "Alchemy",
    itemName=item or "Flask " .. number, materialsPolicy="Customer Provides", priceMode="Free", location=location or "Dalaran",
    availability=availability or "Today", expiresAt=time()+7200}))
  if favored then assert(B:SFMarketplaceSetFavorite(row.id, true)) end
  return row
end
local rows = {}
for number = 1, 10 do rows[#rows + 1] = add(number, number <= 9, "Dalaran", "Today") end
local similar = add(11, false, "Dalaran", "Today", "Crafting Offer", "Alchemy", "Flask Similar")
local other = add(12, true, "Stormwind", "Scheduled", "Crafting Request", "Blacksmithing", "Sword")
assert(U.browseSnapshot, "canonical Browse snapshot was not built after listings")
local canonical = U.browseSnapshot
local runtime = M.runtime
local dataGeneration, favoritesGeneration, order = runtime.dataGeneration, runtime.favoritesGeneration, runtime.store.listingOrder
local byId, byOwner, byType, byProfession, byItem = runtime.byId, runtime.byOwner, runtime.byType, runtime.byProfession, runtime.byItem
local byLocation, byAvailability = runtime.byLocation, runtime.byAvailability
local function assert_favorite_ownership(expectedGeneration, message)
  assert(runtime.favoritesGeneration == expectedGeneration and runtime.dataGeneration == dataGeneration and U.browseSnapshot == canonical
    and runtime.store.listingOrder == order and runtime.byId == byId and runtime.byOwner == byOwner and runtime.byType == byType
    and runtime.byProfession == byProfession and runtime.byItem == byItem and runtime.byLocation == byLocation and runtime.byAvailability == byAvailability, message)
end
assert(B:SFMarketplaceSetFavorite(similar.id, true), "favorite exact-id mutation failed")
assert_favorite_ownership(favoritesGeneration + 1, "favoriting replaced listing-owned data")
assert(B:SFMarketplaceSetFavorite(similar.id, true), "favorite no-op failed")
assert_favorite_ownership(favoritesGeneration + 1, "favorite no-op mutated runtime")
assert(B:SFMarketplaceSetFavorite(similar.id, false), "unfavorite exact-id mutation failed")
assert_favorite_ownership(favoritesGeneration + 2, "unfavoriting replaced listing-owned data")
assert(B:SFMarketplaceSetFavorite(similar.id, false), "unfavorite no-op failed")
assert_favorite_ownership(favoritesGeneration + 2, "unfavorite no-op mutated runtime")

local function options(selector)
  selector:GetScript("OnClick")(selector); _G.__mktMenuButtons = {}; selector.menu.initialize(selector.menu, 1); return _G.__mktMenuButtons
end
local function choose(selector, text)
  for _, option in ipairs(options(selector)) do if option.text == text then option.func(); return end end
  error("missing option " .. text)
end
choose(U.browseTypeSelector, "Crafting Offer"); choose(U.browseProfessionSelector, "Alchemy")
choose(U.browseLocationSelector, "Dalaran"); choose(U.browseAvailabilitySelector, "Today")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
U.browseFavoritesButton:GetScript("OnClick")(U.browseFavoritesButton)
assert(U.browseFavoritesOnly and U.browseFilteredView.total == 9 and U:HasActiveBrowseFilters()
  and U.browseClearFilters:GetScript("OnClick"), "full AND favorites filter is incorrect")
local expectedFavoriteIds = {}
for number = 1, 9 do expectedFavoriteIds[rows[number].id] = true end
for _, row in ipairs(U.browseFilteredView.rows) do
  assert(expectedFavoriteIds[row.id] and row.id ~= similar.id and M:IsFavorite(row.id), "Favorites-only matched metadata instead of exact stable IDs")
end
U.browseClear:GetScript("OnClick")(U.browseClear)
assert(U:GetAppliedBrowseQuery() == "" and U.browseFavoritesOnly and U:GetBrowseLocationKey() == "dalaran", "search Clear changed filters")
U.browseSearchBox:SetText("flask"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
local view = U.browseFilteredView
U.browseNext:GetScript("OnClick")(U.browseNext)
assert(U.browsePage == 2 and U.browseSnapshot == canonical and U.browseFilteredView == view, "paging did not reuse cache")
local pageId = U.browseRows[1].listingId; U.browseRows[1]:GetScript("OnMouseUp")(U.browseRows[1]); U.detailBack:GetScript("OnClick")(U.detailBack)
assert(U.browsePage == 2 and U.selectedListingId == nil and U.browseRows[1].listingId == pageId, "details lost filtered page")

local before = U.browseFilteredView.total
assert(B:SFMarketplaceSetFavorite(rows[9].id, false) and U.browseFilteredView.total == before - 1 and U.browseSnapshot == canonical, "visible favorite mutation did not refresh exact view")
U.browseClearFilters:GetScript("OnClick")(U.browseClearFilters)
assert(not U.browseFavoritesOnly and U:GetBrowseListingType() == "" and U:GetBrowseProfessionKey() == "" and U:GetBrowseLocationKey() == ""
  and U:GetBrowseAvailability() == "" and U:GetAppliedBrowseQuery() == "flask" and U.browsePage == 1, "Clear Filters did not preserve search only")
local same = U.browseFilteredView
assert(U:ClearBrowseFilters() == false and U.browseFilteredView == same, "inactive Clear Filters rebuilt results")

U.browseFavoritesButton:GetScript("OnClick")(U.browseFavoritesButton)
U.browseSearchBox:SetText("missing"); U.browseSearchButton:GetScript("OnClick")(U.browseSearchButton)
assert(U.browseEmptyState:GetText() == "No marketplace listings match your search and filters." and not U.browseRows[1]:IsShown(), "favorites zero state is incorrect")
local browse, hidden = nil, nil
for _, button in ipairs(U.navButtons) do if button.marketplaceTab == "Browse" then browse = button elseif button.marketplaceTab == "My Listings" then hidden = button end end
hidden:GetScript("OnClick")(hidden)
assert(not U.browseFavoritesButton:IsShown() and not U.browseClearFilters:IsShown(), "tab retained Browse toolbar")
browse:GetScript("OnClick")(browse)
assert(U.browseFavoritesButton:IsShown() and U.browseClearFilters:IsShown(), "Browse did not restore Pass B toolbar")

local favoritesButton, clearFilters = U.browseFavoritesButton, U.browseClearFilters
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false; B:SFModulesApply()
assert(U:ActiveScriptCount() == 0 and favoritesButton:GetScript("OnClick") == nil and clearFilters:GetScript("OnClick") == nil, "disable retained Pass B scripts")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true; B:SFModulesApply()
assert(B:ShowMarketplace() and U.browseFavoritesButton == favoritesButton and U.browseClearFilters == clearFilters and U:ActiveScriptCount() == 72, "re-enable duplicated Marketplace controls")
print("marketplace browse favorites/clear filters harness: PASS")
