const fs=require("fs"),p=require("path"),r=p.resolve(__dirname,"..");
const read=f=>fs.readFileSync(p.join(r,f),"utf8"), n=read("SignalFire/SignalFireMarketplaceNetwork.lua"),m=read("SignalFire/SignalFireMarketplace.lua"),b=read("SignalFire/BronzeLFG.lua");
const need=(s,x)=>{if(!s.includes(x))throw Error("Marketplace 2B exact links verification failed: "+x)};
for(const x of ['N.maximumLinkLookups, N.linkLookupTTL, N.linkRequesterCooldown = 16, 6, 5','N.linkWakeKey = "marketplace.network.link-lookup"','op=="L"','function N:HandleLookup','function N:RequestExactLink','function N:ResolveLinkLookup','"L~1~"','self.maximumPacket','M:IsStableListingId(id)','string.sub(id,6,6)~=profile_code(profile)','token_valid(token)','math.abs(now()-tonumber(stamp))>300','canonical_local(runtime,id)','row.ownerKey~=M:GetCurrentOwnerKey()','runtime.remoteById[id]','self:QueueUpsert(row)','linkLookupsById','self:ScheduleLinkLookupWake(runtime)','B:SF151_CancelDelayed(self.linkWakeKey)','lookupPending','lookupWake'])need(n,x);
need(m,'network:RequestExactLink(id)'); need(n,'M:HandleLocalLink(row.id)'); need(b,'Final SetItemRef wrapper');
for(const x of ['OnUpdate','NewTicker','ChatFrame_AddMessageEventFilter','SendChatMessage('])if(n.includes(x))throw Error('Marketplace 2B exact links forbidden: '+x);
if((n.match(/RegisterNetworkPacketHandler\("MKT2"/g)||[]).length!==1)throw Error('Marketplace 2B exact links verification failed: extra handler');
console.log("marketplace phase2b exact links source verification: PASS");
