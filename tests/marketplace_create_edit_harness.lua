local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)
local B, U = assert(BronzeLFG), assert(SignalFireMarketplaceUI151)
BronzeLFG_DB.options.serverProfile="Ascension"; BronzeLFG_DB.options.modulesByProfile={Ascension={tradeskillMarketplace=true}}
assert(B:SFModulesApply() and B:ShowMarketplace() and U:SetTab("Create Listing"))
assert(U.formMessage and U.formPreview, "retained form controls missing")
assert(U:SubmitListingForm()==false and U.formMessage, "invalid form lost retained message")
print("marketplace create/edit harness: PASS")
