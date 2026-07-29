const fs=require("fs"),p=require("path"),r=p.resolve(__dirname,"..");
const n=fs.readFileSync(p.join(r,"SignalFire/SignalFireMarketplaceNetwork.lua"),"utf8"),m=fs.readFileSync(p.join(r,"SignalFire/SignalFireMarketplace.lua"),"utf8");
const need=(s,x)=>{if(!s.includes(x))throw Error("Marketplace 2B verification failed: "+x)};
need(n,'op=="Q"'); need(n,'N.discoveryKey, N.replayKey'); need(n,'N.requesterCooldown, N.responderCooldown = 10, 10'); need(n,'#ids<20'); need(n,'row.ownerKey==owner'); need(n,'runtime.store.listingsById[id]'); need(n,'#(runtime.outgoing or {}) + #packets > self.maximumOutgoing'); need(n,'function N:PumpReplay'); need(n,'function N:ManualSync'); need(n,'B:SF151_CancelDelayed(self.discoveryKey)'); need(m,'cmd == "marketplace sync"');
for(const x of ['OnUpdate','ChatFrame_AddMessageEventFilter','SendChatMessage('])if(n.includes(x))throw Error('Marketplace 2B forbidden: '+x);
console.log("marketplace phase2b replay source verification: PASS");
