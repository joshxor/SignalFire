local root, loader=assert(arg[1]),assert(arg[2]); dofile(loader)
local B=assert(BronzeLFG); local M=assert(_G.SignalFireMarketplace151); local U=assert(_G.SignalFireMarketplaceUI151)
local function ok(v,s) if not v then error(s,2) end end
BronzeLFG_DB.options.serverProfile="Ascension"; BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace=true; ok(B:SFModulesApply(),"enable")
ok(B:ShowMarketplace(),"open"); local r=assert(M.runtime)
local messages, opens, sends, editSends, tells, packets={},0,0,0,0,0
local box={text="",cursor=0,destination="GUILD"}; function box:GetText()return self.text end; function box:SetText(v)self.text=v end; function box:GetCursorPosition()return self.cursor end; function box:SetCursorPosition(v)self.cursor=v end
local active=nil
ChatEdit_GetActiveWindow=function()return active end
ChatFrame_OpenChat=function()opens=opens+1; active=box end
ChatEdit_ActivateChat=function(b)active=b end
ChatEdit_InsertLink=function(link)local t=box.text; box.text=string.sub(t,1,box.cursor)..link..string.sub(t,box.cursor+1); box.cursor=box.cursor+#link; return true end
SendChatMessage=function()sends=sends+1 end; ChatEdit_SendText=function()editSends=editSends+1 end; ChatFrame_SendTell=function()tells=tells+1 end
DEFAULT_CHAT_FRAME.AddMessage=function(_,v)messages[#messages+1]=v end
local row=assert(B:SFMarketplaceCreateListing({owner="Harness",listingType="Crafting Offer",profession="Alchemy",itemName="Flask",materialsPolicy="Discuss",priceMode="Tip",location="Dalaran",availability="Today",expiresAt=time()+3600}))
local link=assert(M:BuildLocalLink(row.id)); r.outgoing={}; ok(M:OpenShareComposer(row.id),"inactive composer opens")
ok(opens==1 and box.text==link and messages[#messages]=="SignalFire> Marketplace link added to chat. Press Enter to send.","inactive insertion")
box.text="beforeafter"; box.cursor=6; active=box; local destination=box.destination; ok(M:OpenShareComposer(row.id),"active draft")
ok(box.text=="before"..link.."after" and box.destination==destination,"cursor insertion or destination")
local once=box.text; ok(M:OpenShareComposer(row.id) and box.text==once,"unchanged draft duplicate")
local remote=assert(B:SFMarketplaceCreateListing({owner="Remote",listingType="Crafting Offer",profession="Tailoring",itemName="Bag",materialsPolicy="Discuss",priceMode="Tip",location="Dalaran",availability="Today",expiresAt=time()+3600}))
r.outgoing={}; box.text=""; box.cursor=0; ok(M:OpenShareComposer(remote.id),"active remote listing may be shared"); ok(#r.outgoing==0,"zero packets")
ok(M:SetFavorite(remote.id,true),"favorite"); ok(M:OpenShareComposer(remote.id),"active Favorite")
local unchanged=box.text; local unavailable=#messages; ok(not M:OpenShareComposer("bad"),"malformed ID"); ok(box.text==unchanged and #messages==unavailable+1,"unavailable exactly once")
local expired=row.id; r.byId[expired].expiresAt=time()-1; unchanged=box.text; unavailable=#messages; ok(not M:OpenShareComposer(expired),"expired row"); ok(box.text==unchanged and #messages==unavailable+1,"expired untouched")
local scripts=U:ActiveScriptCount(); ok(scripts==72,"ActiveScriptCount() == 72")
BronzeLFG_DB.options.modulesByProfile.Ascension.tradeskillMarketplace=false; ok(B:SFModulesApply(),"disable"); ok(U:ActiveScriptCount() == 0,"ActiveScriptCount() == 0"); unchanged=box.text; unavailable=#messages; ok(not M:OpenShareComposer(remote.id),"disabled Marketplace"); ok(box.text==unchanged and #messages==unavailable+1,"disabled untouched")
ok(sends==0 and editSends==0 and tells==0,"no send APIs"); active=nil; ChatFrame_OpenChat=nil; ChatEdit_ActivateChat=nil; ChatFrameEditBox=nil; ok(not M:OpenShareComposer(remote.id),"missing APIs fail safely")
print("marketplace share link harness: PASS")
