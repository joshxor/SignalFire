local root, loader=assert(arg[1]),assert(arg[2]); dofile(loader)
local B=assert(BronzeLFG); local M=assert(_G.SignalFireMarketplace151); local N=assert(_G.SignalFireMarketplaceNetwork2A)
local function ok(v,s) if not v then error(s,2) end end
BronzeLFG_DB.options.serverProfile="Ascension"; BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace=true; ok(B:SFModulesApply(),"enable")
local r=M.runtime; ok(r.discoveryWake and r.replay,"initial one-shot sync missing")
ok(N:HandlePacket(nil,{"BLFG312","MKT2","Q","1","Ascension","q-test",tostring(time())},"Other-Any Realm"),"valid Q")
ok(N:HandlePacket(nil,{"BLFG312","MKT2","Q","1","Triumvirate","q-bad",tostring(time())},"Other-Any Realm")==false,"wrong profile")
M:Disable("replay-test"); local d=N:GetDiagnostics(); ok(not d.discoveryWake and not d.replayWake and d.replayPending==0,"teardown")
print("marketplace network replay harness: PASS")
