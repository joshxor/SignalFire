local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)
local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile="Ascension"; BronzeLFG_DB.options.modulesByProfile={Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() and B:ShowMarketplace() and U:SetTab("Create Listing"))
assert(U.formMessage and U.formPreview, "retained form controls missing")
local message, preview, selectors, inputs = U.formMessage, U.formPreview, U.formSelectors, U.formInputs
assert(selectors and selectors.listingType and selectors.materialsPolicy and selectors.priceMode and selectors.availability and selectors.expirationMinutes, "form selectors missing")
for _, key in ipairs({"profession","itemName","recipeName","gold","silver","copper","priceText","location","notes"}) do assert(inputs[key], "missing input " .. key) end
U:ResetListingForm()
assert(U.formMessage == message and U.formPreview == preview and U.formSelectors == selectors and U.formInputs == inputs, "reset replaced retained controls")
assert(U:SetFormSelector("listingType", "Crafting Request") and U.formValues.listingType == "Crafting Request", "selector did not normalize value")
assert(U:SetFormSelector("listingType", "invalid") == false, "unsupported selector value accepted")
assert(U:SubmitListingForm()==false and U.formMessage, "invalid form lost retained message")
print("marketplace create/edit harness: PASS")
