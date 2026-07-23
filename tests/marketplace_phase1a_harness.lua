local addonRoot = assert(arg and arg[1], "addon root is required")
local parserHarness = assert(arg and arg[2], "parser harness path is required")

dofile(parserHarness)

local B = assert(BronzeLFG, "SignalFire did not load")
local M = assert(SignalFireMarketplace151, "Marketplace owner did not load")
local U = assert(SignalFireMarketplaceUI151, "Marketplace UI owner did not load")
local T = assert(SignalFireTimer151, "sleeping timer owner did not load")

local testNow = 1800000000
function GetTime() return testNow end
function time() return math.floor(testNow) end
function debugprofilestop() return testNow * 1000 end
function UnitName(unit) if unit == "player" then return "Aesri" end end

local function count(rows)
  local total = 0
  for _ in pairs(rows or {}) do total = total + 1 end
  return total
end

local function tick(frame, elapsed)
  local handler = assert(frame:GetScript("OnUpdate"), "active scheduler has no OnUpdate")
  local ok, err = pcall(handler, frame, elapsed)
  assert(ok, tostring(err))
end

local function set_profile(profile)
  BronzeLFG_DB.options.serverProfile = profile
end

local function set_module(profile, value)
  BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
  BronzeLFG_DB.options.modulesByProfile[profile] = BronzeLFG_DB.options.modulesByProfile[profile] or {}
  BronzeLFG_DB.options.modulesByProfile[profile].tradeskillMarketplace = value
end

set_profile("Ascension")
set_module("Ascension", nil)
set_module("Triumvirate", nil)
BronzeLFG_DB.marketplace = nil
M:Disable("harness-reset")

assert(B:SFModuleDefaultEnabled("tradeskillMarketplace") == false,
  "Ascension Marketplace default is not Off")
set_profile("Triumvirate")
assert(B:SFModuleDefaultEnabled("tradeskillMarketplace") == false,
  "Triumvirate Marketplace default is not Off")
set_profile("Ascension")

local disabled = B:SFMarketplaceGetStatus()
assert(disabled.runtime == "inactive" and disabled.disabledClean == true,
  "fresh disabled status is not clean")
assert(disabled.events == 0 and disabled.filters == 0 and disabled.timers == 0
  and disabled.onUpdate == 0 and disabled.queues == 0 and disabled.indexes == 0,
  "disabled Marketplace owns runtime work")
assert(BronzeLFG_DB.marketplace == nil, "disabled status initialized the Marketplace schema")
local statusMessages = {}
local originalAddMessage = DEFAULT_CHAT_FRAME.AddMessage
DEFAULT_CHAT_FRAME.AddMessage = function(_, text) table.insert(statusMessages, text) end
assert(B:SF151_HandlePerfSlash("marketplace status") == true,
  "Marketplace status did not use the final slash dispatcher")
DEFAULT_CHAT_FRAME.AddMessage = originalAddMessage
assert(statusMessages[3] == "SignalFire> runtime=inactive, panel=unbuilt, generation=0, indexes=0, views=0",
  "disabled runtime status output changed")
assert(statusMessages[4] == "SignalFire> events=0, filters=0, timers=0, onUpdate=0, queues=0, disabledClean=true",
  "disabled zero-work status output changed")
assert(BronzeLFG_DB.marketplace == nil, "disabled slash status migrated Marketplace data")

local store, migration = B:SFMarketplaceMigrate("Ascension")
assert(store and migration and BronzeLFG_DB.marketplace.schemaVersion == 1,
  "explicit migration did not create schema version 1")
assert(type(store.listingsById) == "table" and type(store.listingOrder) == "table"
  and type(store.favoritesById) == "table" and type(store.settings) == "table",
  "profile schema is incomplete")
local sameStore, secondMigration = B:SFMarketplaceMigrate("Ascension")
assert(sameStore == store and secondMigration.repairs == 0, "migration is not idempotent")

store.listingsById.bad = {listingType="Nope"}
store.favoritesById.bad = "malformed"
local repairedStore, malformedReport = B:SFMarketplaceMigrate("Ascension")
assert(repairedStore.listingsById.bad == nil and repairedStore.favoritesById.bad == nil,
  "malformed records survived migration")
assert(malformedReport.repairs > 0, "malformed migration did not report repairs")

set_module("Ascension", true)
assert(B:SFModulesApply() == true and M.runtime and M.runtime.active,
  "Marketplace did not enable")
assert(M.runtime.profile == "Ascension", "Marketplace enabled the wrong profile")

local first = assert(B:SFMarketplaceCreateListing({
  listingType="Crafting Offer", profession=" Alchemy ", itemName=" Flask of Endless Rage ",
  materialsPolicy="Customer Provides", priceMode="Tip", priceText="Tips appreciated",
  location=" Dalaran ", availability="Available Now", expirationMinutes=60,
}))
local second = assert(B:SFMarketplaceCreateListing({
  listingType="Crafting Request", profession="Blacksmithing", itemName="Titansteel Destroyer",
  materialsPolicy="Split Materials", priceMode="Negotiable", location="Dalaran",
  availability="Today", expirationMinutes=60,
}))
assert(first.id ~= second.id, "stable IDs collided")
assert(string.match(first.id, "^mkt1:a:aesri:%d+:%d+$"), "stable ID format is wrong")
assert(M.runtime.indexCount == 2 and M.runtime.byId[first.id] and M.runtime.byId[second.id],
  "canonical by-ID index is wrong")
assert(M.runtime.byProfession.alchemy[first.id] and M.runtime.byLocation.dalaran[first.id],
  "normalized indexes are wrong")

local readCopy = assert(B:SFMarketplaceGetListing(first.id))
readCopy.profession = "Corrupted"
assert(B:SFMarketplaceGetListing(first.id).profession == "Alchemy",
  "read operation exposed mutable canonical storage")

local edited = assert(B:SFMarketplaceEditListing(first.id, {
  profession="Enchanting", itemName="Enchant Weapon - Berserking", expirationMinutes=120,
}))
assert(edited.id == first.id, "edit changed the stable ID")
assert(not M.runtime.byProfession.alchemy or not M.runtime.byProfession.alchemy[first.id],
  "edit left the old profession index")
assert(M.runtime.byProfession.enchanting[first.id], "edit did not add the new profession index")
assert(edited.expiresAt == testNow + 120 * 60, "edit did not apply the new expiration")

assert(B:SFMarketplaceSetFavorite(first.id, true) == true, "favorite add failed")
assert(B:SFMarketplaceIsFavorite(first.id) == true, "favorite lookup failed")
assert(B:SFMarketplaceRemoveListing(first.id) == true, "remove failed")
assert(not M.runtime.byId[first.id] and M.runtime.indexCount == 1,
  "remove left canonical index state")
assert(repairedStore.favoritesById[first.id], "remove discarded the favorite summary immediately")
assert(M:PruneStaleFavorites(repairedStore, testNow + M.favoriteStaleTTL + 1) == 1
  and repairedStore.favoritesById[first.id] == nil, "stale favorite cleanup failed")

table.insert(repairedStore.listingOrder, second.id)
table.insert(repairedStore.listingOrder, "missing")
M.runtime.byId = {}
local repairOK, repairCount = B:SFMarketplaceRepairIndexes()
assert(repairOK and repairCount >= 2, "index repair did not report corrupt order entries")
assert(#repairedStore.listingOrder == 1 and repairedStore.listingOrder[1] == second.id,
  "index repair did not canonicalize listing order")
assert(M.runtime.byId[second.id], "index repair did not restore by-ID lookup")

local expiring = assert(B:SFMarketplaceCreateListing({
  listingType="Crafting Offer", profession="Tailoring", itemName="Frostweave Bag",
  materialsPolicy="Crafter Provides", priceMode="Fixed Price", priceCopper=100000,
  location="Dalaran", availability="Available Now", expiresAt=testNow + 5,
}))
assert(T.taskByKey[M.expirationTaskKey], "nearest expiration was not scheduled")
assert(M.timerActive and M.runtime.timerActive, "expiration timer ownership was not reported")
testNow = testNow + 5
tick(T.delayFrame, 0.04)
assert(not B:SFMarketplaceGetListing(expiring.id), "expiration callback did not remove the listing")
assert(M.expirationRemovals >= 1, "expiration diagnostics did not increment")

local ascensionStore = repairedStore
set_profile("Triumvirate")
set_module("Triumvirate", true)
assert(B:SFModulesApply() == true and M.runtime.profile == "Triumvirate",
  "profile switch did not replace runtime ownership")
assert(M.runtime.store ~= ascensionStore and M.runtime.indexCount == 0,
  "profile-scoped storage leaked across profiles")
local triumvirateListing = assert(B:SFMarketplaceCreateListing({
  listingType="Crafting Request", profession="Engineering", itemName="Mekgineer's Chopper",
  materialsPolicy="Customer Provides", priceMode="Negotiable", location="Dalaran",
  availability="Scheduled", expirationMinutes=60,
}))
assert(string.match(triumvirateListing.id, "^mkt1:t:aesri:%d+:%d+$"),
  "Triumvirate stable ID has the wrong profile code")

set_profile("Ascension")
assert(B:SFModulesApply() == true and M.runtime.store == ascensionStore,
  "returning to a profile did not restore its persisted store")
assert(M.runtime.byId[second.id], "returning to a profile did not rebuild indexes")

set_module("Ascension", false)
assert(B:SFModulesApply() == true and M.runtime == nil,
  "Disable did not clear runtime ownership")
assert(not T.taskByKey[M.expirationTaskKey] and M.timerActive == false,
  "Disable left the expiration callback active")
local finalStatus = B:SFMarketplaceGetStatus()
assert(finalStatus.runtime == "inactive" and finalStatus.events == 0 and finalStatus.filters == 0
  and finalStatus.timers == 0 and finalStatus.onUpdate == 0 and finalStatus.queues == 0
  and finalStatus.indexes == 0 and finalStatus.views == 0 and finalStatus.disabledClean == true,
  "disabled zero-work invariant failed")

set_module("Ascension", true)
assert(B:SFModulesApply() == true and M.runtime.byId[second.id],
  "re-enable did not restore persisted listings")
set_module("Ascension", false)
B:SFModulesApply()

assert(not U.panel, "Phase 1A lifecycle operations constructed Marketplace UI")
assert(finalStatus.events == 0 and finalStatus.filters == 0 and finalStatus.onUpdate == 0,
  "Phase 1A acquired forbidden owners")

print("marketplace phase1a harness: PASS (schema=" .. tostring(BronzeLFG_DB.marketplace.schemaVersion)
  .. ", ascensionListings=" .. tostring(count(ascensionStore.listingsById))
  .. ", repairs=" .. tostring(M.indexRepairs) .. ")")
