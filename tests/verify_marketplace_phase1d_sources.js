const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireMarketplaceUI.lua", "utf8");
const core = fs.readFileSync("SignalFire/SignalFireMarketplace.lua", "utf8");
function requireText(source, text) { if (!source.includes(text)) throw new Error(`missing ${text}`); }

for (const text of ["U:BuildMyListingsView", "runtime.byOwner", "U:RenderMyListings", "U:RenderMyListingsDetail",
  "U:RemoveMyListing", "Confirm Remove", "No active listings for this character.", "myListingsRows", "myListingsPage",
  "U:BuildFavoritesView", "U:RenderFavorites", "U:RenderFavoriteDetail", "U:RemoveFavorite", "No favorite listings.", "favoritesRows"]) requireText(ui, text);
requireText(core, "function M:GetCurrentOwnerKey()");
for (const forbidden of ["SetScript(\"OnUpdate\"", "RegisterEvent(", "SendAddonMessage", "SetItemRef", "ChatFrame_"]) {
  if (ui.includes(forbidden)) throw new Error(`Marketplace 1D added forbidden ownership: ${forbidden}`);
}
console.log("marketplace phase1d source verification: PASS");
