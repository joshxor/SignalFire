local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")

dofile(addonLoader)

local B = assert(BronzeLFG, "SignalFire did not load")
local M = assert(SignalFireMarketplace151, "Marketplace core did not load")
local U = assert(SignalFireMarketplaceUI151, "Marketplace UI owner did not load")

BronzeLFG_DB.options.serverProfile = "Ascension"
BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension =
  BronzeLFG_DB.options.modulesByProfile.Ascension or {}
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = false
B:SFModulesApply()
assert(M:GetStatus().panel == "unbuilt", "unconstructed Marketplace did not report unbuilt")

BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true
B:SFModulesApply()
assert(B:ShowMarketplace() == true, "Marketplace did not open")
assert(M:GetStatus().panel == "visible", "open Marketplace did not report visible")

local contentFrame = assert(B.marketplacePanel, "canonical Marketplace content frame is missing")
local ownerFrame = U.panel
local staleFrame = CreateFrame("Frame")
staleFrame:Hide()
U.panel = staleFrame
assert(M:GetStatus().panel == "visible", "status did not use the canonical content frame")
U.panel = ownerFrame

contentFrame:Hide()
assert(M:GetStatus().panel == "hidden", "constructed hidden Marketplace did not report hidden")

print("marketplace phase1b visibility harness: PASS")
