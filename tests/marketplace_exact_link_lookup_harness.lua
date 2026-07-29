local root, loader=assert(arg[1]),assert(arg[2]); dofile(loader)
local B=assert(BronzeLFG); local M=assert(_G.SignalFireMarketplace151); local N=assert(_G.SignalFireMarketplaceNetwork2A)
local function ok(v,s) if not v then error(s,2) end end
BronzeLFG_DB.options.serverProfile="Ascension"; BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace=true; ok(B:SFModulesApply(),"enable")
local r=M.runtime; local stamp=time(); local id="mkt1:a:linkowner:100000:0001"
local row=assert(M:NormalizeNetworkListing({id=id,profile="Ascension",owner=UnitName("player"),listingType="Crafting Offer",profession="Alchemy",itemName="Flask",materialsPolicy="Discuss",priceMode="Tip",priceCopper=0,priceText="",location="Dalaran",availability="Today",notes="",schemaVersion=1,createdAt=stamp-10,updatedAt=stamp-5,expiresAt=stamp+3600},"Ascension"))
r.store.listingsById[id]=row; r.store.listingOrder[#r.store.listingOrder+1]=id; M:IndexListing(r,row)
local sent={}; local old=B.SFN_SendExtensionPacket; B.SFN_SendExtensionPacket=function(_,typ,payload) sent[#sent+1]=payload; return true end
ok(N:HandleLookup({"BLFG312","MKT2","L","1","Ascension",id,"lookup-1",tostring(stamp)},"Other-Realm"),"owner lookup")
ok(#r.outgoing>0,"owner response queued"); ok(N:HandleLookup({"BLFG312","MKT2","L","2","Ascension",id,"lookup-1",tostring(stamp)},"Other-Realm")==false,"version")
ok(N:HandleLookup({"BLFG312","MKT2","L","1","Ascension","bad","lookup-1",tostring(stamp)},"Other-Realm")==false,"stable id")
local missing="mkt1:a:remote:100001:0002"; ok(N:RequestExactLink(missing),"request")
ok(r.linkLookupsById[missing] and r.lookupWake,"pending wake"); ok(N:RequestExactLink(missing),"duplicate coalesces")
ok(#r.linkLookupsById==1 or next(r.linkLookupsById)~=nil,"one pending")
local remote=assert(M:NormalizeNetworkListing({id=missing,profile="Ascension",owner="Other-Realm",listingType="Crafting Offer",profession="Alchemy",itemName="Potion",materialsPolicy="Discuss",priceMode="Tip",priceCopper=0,priceText="",location="Dalaran",availability="Today",notes="",schemaVersion=1,createdAt=stamp-10,updatedAt=stamp-4,expiresAt=stamp+3600},"Ascension"))
local oldHandle=M.HandleLocalLink; M.HandleLocalLink=function(_,got) return got==missing end
ok(N:AcceptUpsert(remote,"Other-Realm"),"upsert resolves"); ok(not r.linkLookupsById[missing],"resolved clears")
M.HandleLocalLink=oldHandle; B.SFN_SendExtensionPacket=old
M:Disable("exact-links"); local d=N:GetDiagnostics(); ok(d.lookupPending==0 and not d.lookupWake and d.network=="inactive","disabled cleanup")
print("marketplace exact link lookup harness: PASS")
