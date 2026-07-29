-- SignalFire Marketplace 2A: bounded, session-only incremental network sync.
do
  local B, M = _G.BronzeLFG, _G.SignalFireMarketplace151
  if B and M then
    local N = _G.SignalFireMarketplaceNetwork2A or {}
    _G.SignalFireMarketplaceNetwork2A = N
    N.protocolVersion, N.maximumPacket, N.maximumChunks, N.maximumPayload = 1, 255, 8, 1024
    N.maximumPending, N.pendingTTL, N.maximumDedup, N.dedupTTL = 32, 30, 256, 120
    N.maximumOutgoing, N.maximumRemote, N.sendSpacing = 64, 200, 0.35
    N.wakeKey = "marketplace.network.outgoing"
    N.discoveryKey, N.replayKey = "marketplace.network.discovery", "marketplace.network.replay"
    N.requesterCooldown, N.responderCooldown = 10, 10
    N.maximumLinkLookups, N.linkLookupTTL, N.linkRequesterCooldown = 16, 6, 5
    N.linkWakeKey = "marketplace.network.link-lookup"
    local FIELDS = {"schemaVersion","id","profile","owner","ownerKey","listingType","profession","professionKey","itemName","itemKey","recipeName","recipeKey","materialsPolicy","priceMode","priceCopper","priceText","location","locationKey","availability","notes","createdAt","updatedAt","expiresAt"}
    local function now() return math.floor(tonumber(time and time() or 0) or 0) end
    local function count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
    local function copy(row) local r={}; for k,v in pairs(row or {}) do r[k]=v end; return r end
    local function note(kind)
      N.diagnostics = N.diagnostics or {sent=0,received=0,accepted=0,rejected=0,stale=0,spoofed=0,duplicate=0,dropped=0}
      N.diagnostics[kind] = (tonumber(N.diagnostics[kind] or 0) or 0) + 1
    end
    local function esc(value)
      value=tostring(value or "")
      return (string.gsub(value, "[^%w%-%._]", function(c) return string.format("%%%02X", string.byte(c)) end))
    end
    local function unesc(value)
      if type(value)~="string" or #value>3072 then return nil end
      local out,i={},1
      while i<=#value do
        local c=string.sub(value,i,i)
        if c=="%" then
          local hex=string.sub(value,i+1,i+2)
          if #hex~=2 or not string.match(hex,"^[%x][%x]$") then return nil end
          out[#out+1]=string.char(tonumber(hex,16)); i=i+3
        else out[#out+1]=c; i=i+1 end
      end
      return table.concat(out)
    end
    local function split(s, delimiter)
      local r,start={},1
      while true do local p=string.find(s,delimiter,start,true); if not p then r[#r+1]=string.sub(s,start); return r end; r[#r+1]=string.sub(s,start,p-1); start=p+1 end
    end
    function N:Serialize(row)
      local parts={}
      for _,field in ipairs(FIELDS) do parts[#parts+1]=esc(row[field]) end
      local payload=table.concat(parts,"|")
      return #payload<=self.maximumPayload and payload or nil
    end
    function N:Deserialize(payload)
      if type(payload)~="string" or #payload==0 or #payload>self.maximumPayload then return nil,"payload size" end
      local values=split(payload,"|"); if #values~=#FIELDS then return nil,"field count" end
      local input={}
      for i,field in ipairs(FIELDS) do local value=unesc(values[i]); if value==nil or #value>240 then return nil,"escape" end; input[field]=value end
      for _,field in ipairs({"schemaVersion","priceCopper","createdAt","updatedAt","expiresAt"}) do
        if not string.match(input[field],"^%d+$") then return nil,"integer" end
        input[field]=tonumber(input[field])
      end
      if input.schemaVersion~=M.schemaVersion or not M:IsStableListingId(input.id) then return nil,"identity" end
      if #input.profile>32 or #input.owner>48 then return nil,"length" end
      local code = input.profile == "Ascension" and "a" or (input.profile == "Triumvirate" and "t" or "")
      if code == "" or string.sub(input.id, 6, 6) ~= code then return nil,"profile identity" end
      local row,err=M:NormalizeNetworkListing(input,input.profile)
      if not row then return nil,err end
      -- Never trust transmitted derived keys.
      return row
    end
    local function token_valid(token) return type(token)=="string" and string.match(token,"^[%w%-_]+$") and #token>=1 and #token<=96 end
    local function prune(runtime)
      local stamp=now()
      for token,p in pairs(runtime.pending or {}) do if stamp-(p.seen or 0)>N.pendingTTL then runtime.pending[token]=nil end end
      for key,seen in pairs(runtime.dedup or {}) do if stamp-seen>N.dedupTTL then runtime.dedup[key]=nil end end
      while count(runtime.dedup)>N.maximumDedup do local oldest,at=nil,nil; for k,v in pairs(runtime.dedup) do if not at or v<at then oldest,at=k,v end end; runtime.dedup[oldest]=nil end
      for id,seen in pairs(runtime.lookupRequestedById or {}) do if stamp-seen>N.dedupTTL then runtime.lookupRequestedById[id]=nil end end
    end
    local function profile_code(profile) return profile=="Ascension" and "a" or (profile=="Triumvirate" and "t" or "") end
    local function canonical_local(runtime,id)
      for _,listed in ipairs(runtime.store.listingOrder or {}) do if listed==id then return true end end
      return false
    end
    local function unavailable()
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> Marketplace listing is unavailable.") end
    end
    function N:Chunk(row)
      local encoded=self:Serialize(row); if not encoded then return nil end
      local token=esc(row.id).."-"..tostring(row.updatedAt)
      token=string.gsub(token,"%%","x")
      if not token_valid(token) then return nil end
      local packets,offset={},1
      while offset<=#encoded do
        local part=#packets+1; local prefix="BLFG312~MKT2~U~1~"..token.."~"..part.."~"..self.maximumChunks.."~"
        local room=self.maximumPacket-#prefix
        if room<1 or part>self.maximumChunks then return nil end
        packets[#packets+1]=string.sub(encoded,offset,offset+room); offset=offset+room
      end
      local total=#packets; if total<1 or total>self.maximumChunks then return nil end
      for i,chunk in ipairs(packets) do packets[i]="U~1~"..token.."~"..i.."~"..total.."~"..chunk end
      return packets
    end
    function N:QueuePayload(payload)
      local runtime=M.runtime
      if not runtime or not runtime.active or not M:IsEnabled() or #payload==0 or #("BLFG312~MKT2~"..payload)>self.maximumPacket then return false end
      runtime.outgoing=runtime.outgoing or {}
      if #runtime.outgoing>=self.maximumOutgoing then note("dropped"); return false end
      runtime.outgoing[#runtime.outgoing+1]={profile=runtime.profile,payload=payload}
      self:ScheduleWake(runtime); return true
    end
    function N:QueueUpsert(row)
      if not row or not M:IsEnabled() then return false end
      local packets=self:Chunk(row); if not packets then note("dropped"); return false end
      local runtime=M.runtime
      -- A listing is atomic: never leave only some of its chunks queued.
      if not runtime or #(runtime.outgoing or {}) + #packets > self.maximumOutgoing then note("dropped"); return false end
      for _,packet in ipairs(packets) do runtime.outgoing[#runtime.outgoing+1]={profile=runtime.profile,payload=packet} end
      self:ScheduleWake(runtime)
      return true
    end
    function N:QueueRemove(row)
      if not row or not M:IsStableListingId(row.id) then return false end
      return self:QueuePayload("R~1~"..row.id.."~"..tostring(math.floor(tonumber(row.updatedAt or 0) or 0)))
    end
    function N:ScheduleWake(runtime)
      if runtime.wake or not B.SF151_ScheduleDelayed then return false end
      runtime.wake=true
      B:SF151_ScheduleDelayed(self.wakeKey,self.sendSpacing,function()
        local current=M.runtime; if not current then return end; current.wake=false
        local item=table.remove(current.outgoing or {},1)
        if item and M:IsEnabled() and item.profile==current.profile then
          if B:SFN_SendExtensionPacket("MKT2",item.payload) then note("sent") else note("dropped") end
        end
        if current.replay and current.replay.active then N:PumpReplay(current) end
        if #(current.outgoing or {})>0 then N:ScheduleWake(current) end
      end)
      return true
    end
    function N:RemoveRemote(id, reason)
      local runtime=M.runtime; local row=runtime and runtime.remoteById and runtime.remoteById[id]
      if not row then return false end
      M:UnindexListing(runtime,row); runtime.remoteById[id]=nil; runtime.remoteSourceById[id]=nil
      for i=#runtime.remoteOrder,1,-1 do if runtime.remoteOrder[i]==id then table.remove(runtime.remoteOrder,i) end end
      runtime.remoteCount=math.max(0,(runtime.remoteCount or 1)-1)
      if reason~="expired" then runtime.dataGeneration=runtime.dataGeneration+1; local ui=_G.SignalFireMarketplaceUI151; if ui and ui.OnMarketplaceDataChanged then ui:OnMarketplaceDataChanged() end end
      M:ScheduleExpiration(); return true
    end
    local function same(a,b)
      for _,k in ipairs(FIELDS) do if tostring(a[k] or "")~=tostring(b[k] or "") then return false end end
      return true
    end
    function N:AcceptUpsert(row, author)
      local runtime=M.runtime; if not runtime or not runtime.active or row.profile~=runtime.profile then note("rejected"); return false end
      local stamp=now(); if row.expiresAt<=stamp or row.createdAt>stamp+300 or row.updatedAt>stamp+300 or row.expiresAt>stamp+8*24*3600 then note("rejected"); return false end
      if M:OwnerKey(row.owner)~=M:OwnerKey(author) then note("spoofed"); return false end
      if M:OwnerKey(author)==M:GetCurrentOwnerKey() then return false end
      if runtime.store.listingsById[row.id] then note("rejected"); return false end
      local old=runtime.remoteById[row.id]
      if old then
        if row.updatedAt<old.updatedAt then note("stale"); return false end
        if row.updatedAt==old.updatedAt then if same(row,old) then note("duplicate"); return false end; note("rejected"); return false end
        M:UnindexListing(runtime,old)
      elseif (runtime.remoteCount or 0)>=self.maximumRemote then
        local victim=nil; for _,candidate in pairs(runtime.remoteById) do if not victim or candidate.expiresAt<victim.expiresAt or (candidate.expiresAt==victim.expiresAt and candidate.id<victim.id) then victim=candidate end end
        if victim then self:RemoveRemote(victim.id,"evict") end
      end
      runtime.remoteById[row.id]=row; runtime.remoteSourceById[row.id]=M:OwnerKey(author)
      if not old then runtime.remoteOrder[#runtime.remoteOrder+1]=row.id; runtime.remoteCount=(runtime.remoteCount or 0)+1 end
      M:IndexListing(runtime,row); runtime.dataGeneration=runtime.dataGeneration+1; note("accepted")
      local ui=_G.SignalFireMarketplaceUI151; if ui and ui.OnMarketplaceDataChanged then ui:OnMarketplaceDataChanged() end
      M:ScheduleExpiration(); self:ResolveLinkLookup(row); return true
    end
    function N:ScheduleLinkLookupWake(runtime)
      if not runtime or not runtime.active then return false end
      local nearest=nil
      for _,lookup in pairs(runtime.linkLookupsById or {}) do if not nearest or lookup.expiresAt<nearest then nearest=lookup.expiresAt end end
      if not nearest then runtime.lookupWake=false; return false end
      if B.SF151_CancelDelayed then B:SF151_CancelDelayed(self.linkWakeKey) end
      runtime.lookupWake=true
      local generation,profile=runtime.generation,runtime.profile
      if B.SF151_ScheduleDelayed then B:SF151_ScheduleDelayed(self.linkWakeKey,math.max(0,nearest-now()),function()
        local current=M.runtime; if not current or current.generation~=generation or current.profile~=profile or not M:IsEnabled() then return end
        current.lookupWake=false
        local stamp=now()
        for id,lookup in pairs(current.linkLookupsById or {}) do
          if lookup.expiresAt<=stamp then current.linkLookupsById[id]=nil; note("lookupTimedOut"); unavailable() end
        end
        N:ScheduleLinkLookupWake(current)
      end) end
      return true
    end
    function N:ResolveLinkLookup(row)
      local runtime=M.runtime; local lookup=runtime and runtime.linkLookupsById and runtime.linkLookupsById[row.id]
      if not lookup or lookup.profile~=runtime.profile or row.profile~=runtime.profile then return false end
      runtime.linkLookupsById[row.id]=nil; note("lookupResolved"); self:ScheduleLinkLookupWake(runtime)
      -- This is the original click's exact ID only; HandleLocalLink retains the
      -- established lazy UI ownership and its single unavailable fallback.
      return M:HandleLocalLink(row.id)
    end
    function N:RequestExactLink(id)
      local runtime=M.runtime; id=tostring(id or "")
      if not runtime or not runtime.active or not M:IsEnabled() or not M:IsStableListingId(id)
          or string.sub(id,6,6)~=profile_code(runtime.profile) then note("lookupRejected"); return false end
      runtime.linkLookupsById,runtime.lookupRequestedById=runtime.linkLookupsById or {},runtime.lookupRequestedById or {}
      if runtime.linkLookupsById[id] then return true end
      local stamp=now(); if stamp-(runtime.lookupRequestedById[id] or 0)<self.linkRequesterCooldown then note("lookupRejected"); return false end
      if count(runtime.linkLookupsById)>=self.maximumLinkLookups then note("lookupRejected"); unavailable(); return true end
      local token="l"..tostring(runtime.generation).."-"..tostring(stamp).."-"..tostring(#id)
      if not token_valid(token) then note("lookupRejected"); return false end
      local payload="L~1~"..runtime.profile.."~"..id.."~"..token.."~"..tostring(stamp)
      if #("BLFG312~MKT2~"..payload)>self.maximumPacket or not self:QueuePayload(payload) then note("lookupRejected"); return false end
      runtime.lookupRequestedById[id]=stamp; runtime.linkLookupsById[id]={id=id,profile=runtime.profile,token=token,requestedAt=stamp,expiresAt=stamp+self.linkLookupTTL}
      note("lookupSent")
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> Looking up Marketplace listing...") end
      self:ScheduleLinkLookupWake(runtime); return true
    end
    function N:HandleLookup(p,author)
      local runtime=M.runtime; local profile,id,token,stamp=tostring(p[5] or ""),tostring(p[6] or ""),tostring(p[7] or ""),tostring(p[8] or "")
      local stampValue=tonumber(stamp)
      if #p~=8 or profile~=runtime.profile or profile_code(profile)=="" or not M:IsStableListingId(id)
          or string.sub(id,6,6)~=profile_code(profile) or not token_valid(token) or not string.match(stamp,"^%d+$")
          or not stampValue or math.abs(now()-stampValue)>300 then note("lookupRejected"); return false end
      local requester=M:OwnerKey(author); if requester=="" or requester==M:GetCurrentOwnerKey() then return true end
      local dedup="L:"..requester..":"..id
      if runtime.dedup[dedup] and now()-runtime.dedup[dedup]<self.linkRequesterCooldown then note("duplicate"); return true end
      runtime.dedup[dedup]=now(); note("lookupReceived"); prune(runtime)
      local row=runtime.store.listingsById[id]
      if not row or not canonical_local(runtime,id) or row.profile~=runtime.profile or row.ownerKey~=M:GetCurrentOwnerKey()
          or tonumber(row.expiresAt or 0)<=now() or runtime.remoteById[id] then return true end
      local normalized=M:NormalizeNetworkListing(row,runtime.profile)
      if not normalized or normalized.id~=id then return true end
      if self:QueueUpsert(row) then note("lookupResponded"); return true end
      return false
    end
    function N:HandlePacket(_, p, author)
      local runtime=M.runtime; if not runtime or not runtime.active or not M:IsEnabled() then return false end
      note("received"); runtime.pending,runtime.dedup=runtime.pending or {},runtime.dedup or {}; prune(runtime)
      local op,version=p[3],p[4]; if tonumber(version)~=self.protocolVersion then note("rejected"); return false end
      if op=="Q" then return self:HandleDiscovery(p,author) end
      if op=="L" then return self:HandleLookup(p,author) end
      if op=="R" then
        local id,revision=tostring(p[5] or ""),tostring(p[6] or "")
        if #p~=6 or not M:IsStableListingId(id) or not string.match(revision,"^%d+$") then note("rejected"); return false end
        local row=runtime.remoteById[id]; if not row then return true end
        if M:OwnerKey(author)~=row.ownerKey then note("spoofed"); return false end
        if tonumber(revision)<row.updatedAt then note("stale"); return false end
        self:RemoveRemote(id,"remove"); note("accepted"); return true
      end
      if op~="U" or #p~=8 then note("rejected"); return false end
      local token,part,total,chunk=tostring(p[5] or ""),tonumber(p[6]),tonumber(p[7]),p[8]
      if not token_valid(token) or not part or not total or part<1 or total<1 or part>total or total>self.maximumChunks or type(chunk)~="string" then note("rejected"); return false end
      local pending=runtime.pending[token]
      if not pending then if count(runtime.pending)>=self.maximumPending then note("rejected"); return false end; pending={count=total,parts={},seen=now(),author=author}; runtime.pending[token]=pending end
      if pending.count~=total or M:OwnerKey(pending.author)~=M:OwnerKey(author) then runtime.pending[token]=nil; note("rejected"); return false end
      if pending.parts[part] then if pending.parts[part]==chunk then note("duplicate"); return true end; runtime.pending[token]=nil; note("rejected"); return false end
      pending.parts[part]=chunk; pending.seen=now(); local parts={}
      for i=1,total do if not pending.parts[i] then return true end; parts[#parts+1]=pending.parts[i] end
      runtime.pending[token]=nil; local encoded=table.concat(parts); if #encoded>self.maximumPayload then note("rejected"); return false end
      local key=token..":"..encoded; if runtime.dedup[key] then note("duplicate"); return false end; runtime.dedup[key]=now(); prune(runtime)
      local row=self:Deserialize(encoded); if not row then note("rejected"); return false end
      return self:AcceptUpsert(row,author)
    end
    function N:QueueDiscovery(runtime)
      runtime=runtime or M.runtime; if not runtime or not runtime.active then return false end
      local stamp=now(); if stamp-(runtime.lastSync or 0)<self.requesterCooldown then return false end
      local token="q"..tostring(runtime.generation).."-"..tostring(stamp)
      if not token_valid(token) then return false end
      local payload="Q~1~"..runtime.profile.."~"..token.."~"..stamp
      if not self:QueuePayload(payload) then return false end
      runtime.lastSync=stamp; note("syncSent"); return true
    end
    function N:ReplayIds(runtime)
      local ids,seen,stamp={},{},now(); local owner=M:GetCurrentOwnerKey()
      for i=#(runtime.store.listingOrder or {}),1,-1 do
        local id=runtime.store.listingOrder[i]; local row=runtime.store.listingsById[id]
        if #ids<20 and not seen[id] and row and row.id==id and row.profile==runtime.profile
          and M:IsStableListingId(id) and row.ownerKey==owner and tonumber(row.expiresAt or 0)>stamp then
          seen[id]=true; ids[#ids+1]=id
        end
      end
      return ids
    end
    function N:ScheduleReplay(runtime, reason, delay)
      runtime=runtime or M.runtime; if not runtime or not runtime.active then return false end
      if runtime.replay and (runtime.replay.pending or runtime.replay.active) then return true end
      runtime.replay={profile=runtime.profile,generation=runtime.generation,ids=self:ReplayIds(runtime),cursor=1,pending=true,active=false,reason=reason}
      runtime.replayWake=true
      if B.SF151_ScheduleDelayed then B:SF151_ScheduleDelayed(self.replayKey,delay or .75,function()
        local current=M.runtime; local replay=current and current.replay
        if not current or not replay or replay.generation~=current.generation or replay.profile~=current.profile or not M:IsEnabled() then return end
        current.replayWake=false; replay.pending=false; replay.active=true; N:PumpReplay(current)
      end) end
      return true
    end
    function N:PumpReplay(runtime)
      local replay=runtime and runtime.replay
      if not replay or not replay.active or replay.generation~=runtime.generation then return false end
      while replay.cursor<=#replay.ids do
        local id=replay.ids[replay.cursor]; local row=runtime.store.listingsById[id]; local packets=row and self:Chunk(row) or nil
        if not row or row.profile~=runtime.profile or row.ownerKey~=M:GetCurrentOwnerKey() or tonumber(row.expiresAt or 0)<=now() or not M:IsStableListingId(id) then replay.cursor=replay.cursor+1
        elseif #(runtime.outgoing or {}) + #packets > self.maximumOutgoing then return false
        else
          for _,packet in ipairs(packets) do runtime.outgoing[#runtime.outgoing+1]={profile=runtime.profile,payload=packet} end
          self:ScheduleWake(runtime); replay.cursor=replay.cursor+1; note("replayListings")
        end
      end
      runtime.lastReplay=now(); runtime.replay=nil; note("replayRuns"); return true
    end
    function N:HandleDiscovery(p,author)
      local runtime=M.runtime; local profile,token,stamp=tostring(p[5] or ""),tostring(p[6] or ""),tostring(p[7] or "")
      if #p~=7 or profile~=runtime.profile or (profile~="Ascension" and profile~="Triumvirate") or not token_valid(token) or not string.match(stamp,"^%d+$") or math.abs(now()-tonumber(stamp))>300 then note("rejected"); return false end
      local key=M:OwnerKey(author); if key=="" or key==M:GetCurrentOwnerKey() then return true end
      local dedup="Q:"..key..":"..token; if runtime.dedup[dedup] then note("duplicate"); return true end
      runtime.dedup[dedup]=now(); note("syncReceived"); prune(runtime)
      if now()-(runtime.lastReplay or 0)<self.responderCooldown then return true end
      self:ScheduleReplay(runtime,"discovery",.75); return true
    end
    function N:ScheduleInitial(runtime)
      if runtime.initialSync then return end; runtime.initialSync=true; runtime.discoveryWake=true
      local generation,profile=runtime.generation,runtime.profile
      if B.SF151_ScheduleDelayed then B:SF151_ScheduleDelayed(self.discoveryKey,.75,function()
        local current=M.runtime; if current and current.generation==generation and current.profile==profile and M:IsEnabled() then current.discoveryWake=false; N:QueueDiscovery(current) end
      end) end
      self:ScheduleReplay(runtime,"initial",1.5)
    end
    function N:ManualSync()
      local runtime=M.runtime; if not runtime or not runtime.active or not M:IsEnabled() then return false end
      local sent=self:QueueDiscovery(runtime); self:ScheduleReplay(runtime,"manual",.75); return sent
    end
    function N:Enable(runtime)
      if self.registered then return true end
      self.callback=self.callback or function(owner,p,author) return owner:HandlePacket(owner,p,author) end
      self.registered=B.RegisterNetworkPacketHandler and B:RegisterNetworkPacketHandler("MKT2",self,self.callback) == true or false
      if self.registered then runtime.outgoing,runtime.pending,runtime.dedup={}, {}, {}; runtime.linkLookupsById,runtime.lookupRequestedById={}, {}; runtime.wake=false; runtime.discoveryWake=false; runtime.replayWake=false; runtime.lookupWake=false; self:ScheduleInitial(runtime) end
      return self.registered
    end
    function N:Disable()
      local runtime=M.runtime
      if B.SF151_CancelDelayed then B:SF151_CancelDelayed(self.wakeKey) end
      if B.SF151_CancelDelayed then B:SF151_CancelDelayed(self.discoveryKey); B:SF151_CancelDelayed(self.replayKey) end
      if B.SF151_CancelDelayed then B:SF151_CancelDelayed(self.linkWakeKey) end
      if runtime then runtime.outgoing,runtime.pending,runtime.dedup={}, {}, {}; runtime.linkLookupsById,runtime.lookupRequestedById={}, {}; runtime.wake=false; runtime.discoveryWake=false; runtime.replayWake=false; runtime.lookupWake=false; runtime.replay=nil; runtime.remoteById,runtime.remoteOrder,runtime.remoteSourceById={}, {}, {}; runtime.remoteCount=0 end
      if B.UnregisterNetworkPacketHandler then B:UnregisterNetworkPacketHandler("MKT2",self) end
      self.registered=false; return true
    end
    function N:GetDiagnostics()
      local r=M.runtime; local d=self.diagnostics or {}
      return {network=(r and r.active and self.registered) and "active" or "inactive",remote=r and r.remoteCount or 0,sent=d.sent or 0,received=d.received or 0,accepted=d.accepted or 0,rejected=d.rejected or 0,stale=d.stale or 0,spoofed=d.spoofed or 0,duplicate=d.duplicate or 0,pending=r and count(r.pending) or 0,dedup=r and count(r.dedup) or 0,outgoing=r and #(r.outgoing or {}) or 0,dropped=d.dropped or 0,wake=r and r.wake or false,handler=self.registered==true,syncSent=d.syncSent or 0,syncReceived=d.syncReceived or 0,replayRuns=d.replayRuns or 0,replayListings=d.replayListings or 0,replayPending=r and r.replay and #r.replay.ids-r.replay.cursor+1 or 0,discoveryWake=r and r.discoveryWake or false,replayWake=r and r.replayWake or false,lastSync=r and r.lastSync or 0,lookupSent=d.lookupSent or 0,lookupReceived=d.lookupReceived or 0,lookupResponded=d.lookupResponded or 0,lookupResolved=d.lookupResolved or 0,lookupTimedOut=d.lookupTimedOut or 0,lookupRejected=d.lookupRejected or 0,lookupPending=r and count(r.linkLookupsById) or 0,lookupWake=r and r.lookupWake or false}
    end
    if M.runtime and M.runtime.active and M:IsEnabled() then N:Enable(M.runtime) end
  end
end
