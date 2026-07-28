const fs = require("fs");
const ui = fs.readFileSync("SignalFire/SignalFireMarketplaceUI.lua", "utf8");
for (const text of ["formMode", "formValidationText", "formSuccessText", "formUpdating", "This listing is no longer available.", "SetBrowseToolbarVisible", "UpdateListingPreview", "priceCopper"]) {
  if (!ui.includes(text)) throw new Error(`Marketplace 1E missing ${text}`);
}
if (ui.includes("self.formMessage, self.formPreviewSignature = nil, nil")) throw new Error("form reset destroys retained message control");
console.log("marketplace phase1e source verification: PASS");
