const fs = require("fs");
const ui = fs.readFileSync("SignalFire/SignalFireMarketplaceUI.lua", "utf8");
function need(text) { if (!ui.includes(text)) throw new Error(`Marketplace 1E missing ${text}`); }
for (const text of ["self.formSelectors={}", "SignalFireMarketplaceFormTypeDropdown151", "SignalFireMarketplaceFormMaterialsDropdown151", "SignalFireMarketplaceFormPriceModeDropdown151", "SignalFireMarketplaceFormAvailabilityDropdown151", "SignalFireMarketplaceFormExpirationDropdown151", "formMode, self.formEditId, self.formReturnId", "Keep Current", "self.formValues[key]", "for _, key in ipairs({\"listingType\",\"materialsPolicy\",\"priceMode\",\"availability\",\"expirationMinutes\"})", "current.id ~= self.formEditId", "current.profile ~= self.profile", "current.ownerKey ~= self:GetCurrentOwnerKey()", "2147483647", "Fixed Price requires", "values.priceMode=='Free'", "self.formUpdating", "self:CloseFormSelectors()", "for _, selector in pairs(self.formSelectors or {}) do selector:SetScript(\"OnClick\", nil)"]) need(text);
for (const key of ["profession", "itemName", "recipeName", "gold", "silver", "copper", "priceText", "location", "notes"]) need(`{"${key}"`);
if (ui.includes("self.formMessage, self.formPreviewSignature = nil, nil")) throw new Error("form reset destroys retained message control");
for (const forbidden of ["SetScript(\"OnUpdate\"", "RegisterEvent(", "SendAddonMessage", "ChatFrame_", "SetItemRef"]) if (ui.includes(forbidden)) throw new Error(`forbidden Marketplace ownership: ${forbidden}`);
console.log("marketplace phase1e source verification: PASS");
