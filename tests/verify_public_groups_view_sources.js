const fs = require("fs");

const ui = fs.readFileSync("SignalFire/SignalFireUI.lua", "utf8");
const bronze = fs.readFileSync("SignalFire/BronzeLFG.lua", "utf8").replace(/\r\n/g, "\n");

function requireText(text, label) {
  if (!ui.includes(text)) throw new Error(`missing ${label}: ${text}`);
}

requireText('PG.generationName = "1.5.1-perf-phase6b"', "Phase 6 owner");
requireText("PG.maximumViews = 16", "bounded view cache");
requireText("function B:SF151_InvalidatePublicGroupsData", "data-generation invalidation");
requireText("snapshotGeneration == PG.dataGeneration", "snapshot generation hit");
requireText("local signature = table.concat({tostring(PG.dataGeneration)", "view signature");
requireText("p6_note(\"rowRenderSignatureHits\")", "row render signatures");
requireText("public-groups.expiry", "sleepable expiration task");
requireText('B:SF151_CancelDelayed("public-groups.expiry")', "hidden expiry cancellation");
requireText("PG.AttachPanel = p6_attach_panel", "panel lifecycle owner");
requireText("Refresh.original.publicGroups = function() return PG.Render() end", "final scheduled owner");
requireText("p6_wrap_row_mutation(\"MirrorListingToPublic\")", "listing invalidation");
requireText("p6_wrap_row_mutation(\"UpsertInvasionPublicListing\")", "invasion invalidation");
requireText("if not p6_visible(B.publicPanel) then", "hidden-panel skip");
requireText("PG.rendering = nil", "error-safe render guard");

if (!bronze.includes("return removed\nend\n\nfunction BLFG:BuildProfileWhisper")) {
  throw new Error("ExpirePublicGroups does not report material removals");
}

const block = ui.slice(
  ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_BEGIN"),
  ui.indexOf("-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_END")
);
if (block.includes('SetScript("OnUpdate"')) throw new Error("Phase 6 added permanent OnUpdate polling");
if (block.includes("BLFG_570b1c_ApplyPublicParserFix")) throw new Error("renderer reparses canonical chat rows");
if (block.includes("AddPublicGroup")) throw new Error("renderer re-enters chat row creation");

console.log("Public Groups view-cache source checks: PASS");
