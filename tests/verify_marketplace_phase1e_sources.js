const fs = require("fs");
const ui = fs.readFileSync("SignalFire/SignalFireMarketplaceUI.lua", "utf8");
function need(text) { if (!ui.includes(text)) throw new Error(`Marketplace 1E missing ${text}`); }
for (const text of ["self.formSelectors={}", "SignalFireMarketplaceFormTypeDropdown151", "SignalFireMarketplaceFormMaterialsDropdown151", "SignalFireMarketplaceFormPriceModeDropdown151", "SignalFireMarketplaceFormAvailabilityDropdown151", "SignalFireMarketplaceFormExpirationDropdown151", "formMode, self.formEditId, self.formReturnId", "Keep Current", "self.formValues[key]", "for _, key in ipairs({\"listingType\",\"materialsPolicy\",\"priceMode\",\"availability\",\"expirationMinutes\"})", "current.id ~= self.formEditId", "current.profile ~= self.profile", "current.ownerKey ~= self:GetCurrentOwnerKey()", "2147483647", "Fixed Price requires", "values.priceMode=='Free'", "self.formUpdating", "self:CloseFormSelectors()", "for _, selector in pairs(self.formSelectors or {}) do selector:SetScript(\"OnClick\", nil)"]) need(text);
for (const key of ["profession", "itemName", "recipeName", "gold", "silver", "copper", "priceText", "location", "notes"]) need(`{"${key}"`);
for (const anchor of [
  'self.sectionTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -92)',
  'typeSelector:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -112)',
  'browseShell:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -140)',
  'self.browseSummary:SetPoint("TOPRIGHT", browseShell, "BOTTOMRIGHT", 0, -4)',
  'primary:SetPoint("TOPLEFT",form,"TOPLEFT",12,-330)',
]) need(anchor);
for (const staleAnchor of [
  'typeSelector:SetPoint("TOPLEFT", self.sectionTitle, "BOTTOMLEFT"',
  'self.browseSummary:SetPoint("TOPRIGHT", browseShell, "TOPRIGHT"',
]) if (ui.includes(staleAnchor)) throw new Error(`Marketplace 1E stale layout anchor: ${staleAnchor}`);
for (const selectorY of [-334, -348]) {
  const selectorAnchor = new RegExp(`button:SetPoint\\("TOPLEFT",form,"TOPLEFT",[^\\n]*,${selectorY}\\)`);
  if (selectorAnchor.test(ui)) throw new Error(`Marketplace 1E stale selector y position: ${selectorY}`);
}
for (const label of ['[30]="30 minutes"', '[60]="1 hour"', '[120]="2 hours"', '[240]="4 hours"', '[480]="8 hours"', '[1440]="24 hours"']) need(label);
need('if key=="expirationMinutes" and U.formMode=="edit"');
if (ui.includes("self.formMessage, self.formPreviewSignature = nil, nil")) throw new Error("form reset destroys retained message control");
for (const forbidden of ["SetScript(\"OnUpdate\"", "RegisterEvent(", "SendAddonMessage", "ChatFrame_", "SetItemRef"]) if (ui.includes(forbidden)) throw new Error(`forbidden Marketplace ownership: ${forbidden}`);
console.log("marketplace phase1e source verification: PASS");
