local addonRoot = assert(arg and arg[1], "prepared addon root is required")
local addonLoader = assert(arg and arg[2], "addon loader path is required")
dofile(addonLoader)
local B = assert(BronzeLFG, "BronzeLFG was not loaded")
local M = assert(_G.SignalFireMarketplace151, "Marketplace core was not loaded")
local N = assert(_G.SignalFireMarketplaceNetwork2A, "Marketplace network was not loaded")
local function check(v, message) if not v then error(message, 2) end end
BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace = true
check(B:SFModulesApply(), "Marketplace enable failed")
check(B.NetworkPacketHandlers2A.MKT2 and B.NetworkPacketHandlers2A.MKT2.owner == N, "MKT2 registration failed")
check(B:RegisterNetworkPacketHandler("MKT2", {}, function() end) == false, "foreign handler replaced owner")
check(B:UnregisterNetworkPacketHandler("MKT2", {}) == false, "foreign handler unregistered owner")
check(B:SFN_SendExtensionPacket("MKT2", "") == false, "empty extension payload accepted")
check(B:SFN_SendExtensionPacket("MKT2", string.rep("x", 256)) == false, "oversized extension payload accepted")
local row = assert(M:NormalizeNetworkListing({id="mkt1:a:remote:100000:0001",profile="Ascension",owner="Remote-Any Realm",listingType="Crafting Offer",profession="Alchemy",itemName="Flask",materialsPolicy="Discuss",priceMode="Tip",priceCopper=0,priceText="",location="Dalaran",availability="Today",notes="a~b|c%\n",schemaVersion=1,createdAt=time()-10,updatedAt=time()-5,expiresAt=time()+3600}, "Ascension"))
local encoded = assert(N:Serialize(row)); local decoded = assert(N:Deserialize(encoded))
check(decoded.ownerKey == M:OwnerKey(row.owner), "derived owner key was trusted")
local chunks = assert(N:Chunk(row)); check(#chunks <= 8, "chunk maximum exceeded")
local sent = {}; local old = B.SFN_SendExtensionPacket; B.SFN_SendExtensionPacket=function(_, typ, payload) sent[#sent+1]=payload; return true end
for _, payload in ipairs(chunks) do N.HandlePacket(N, {"BLFG312","MKT2", unpack((function() local r={} for x in string.gmatch(payload,"[^~]+") do r[#r+1]=x end return r end)())}, "Remote-Any Realm") end
B.SFN_SendExtensionPacket=old
check(M.runtime.remoteById[row.id] ~= nil, "valid remote upsert was not retained")
check(M.runtime.store.listingsById[row.id] == nil, "remote record was persisted")
check(N.HandlePacket(N,{"BLFG312","MKT2","R","1",row.id,tostring(row.updatedAt)},"Remote-Any Realm"), "valid remote remove rejected")
check(M.runtime.remoteById[row.id] == nil, "remote remove failed")
M:Disable("harness")
check(not B.NetworkPacketHandlers2A.MKT2, "MKT2 teardown failed")
local d=N:GetDiagnostics(); check(d.network=="inactive" and d.remote==0 and d.pending==0 and d.dedup==0 and d.outgoing==0 and not d.wake and not d.handler, "disabled diagnostics are not zero-work")
print("marketplace network sync harness: PASS")
