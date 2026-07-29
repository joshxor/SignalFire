-- SignalFire Tradeskill Marketplace Phase 1A: local data engine only.
do
  local B = _G.BronzeLFG
  if B then
    local M = _G.SignalFireMarketplace151 or {}
    _G.SignalFireMarketplace151 = M

    M.generation = "1.5.3-marketplace-phase1a"
    M.schemaVersion = 1
    M.moduleKey = "tradeskillMarketplace"
    M.maximumListings = 200
    M.maximumOwnerListings = 20
    M.favoriteStaleTTL = 7 * 24 * 60 * 60
    M.expirationTaskKey = "marketplace.expiration"
    M.maximumLocalLinkIdLength = 128
    M.maximumLocalLinkLength = 320
    M.runtimeSequence = tonumber(M.runtimeSequence or 0) or 0
    M.expirationRemovals = tonumber(M.expirationRemovals or 0) or 0
    M.indexRepairs = tonumber(M.indexRepairs or 0) or 0
    M.errorCount = tonumber(M.errorCount or 0) or 0

    -- Runtime indexes are session-only. Owner: SignalFireMarketplace151.
    -- Keys: stable listing IDs and normalized field values. Maximum: 200 listings
    -- per active profile. TTL: active module/profile lifetime. Eviction: listing
    -- removal or expiration. Cleanup: Disable/profile switch. Never persisted.

    local LISTING_TYPES = { ["Crafting Offer"]=true, ["Crafting Request"]=true }
    local MATERIALS = {
      ["Crafter Provides"]=true, ["Customer Provides"]=true,
      ["Split Materials"]=true, ["Discuss"]=true,
    }
    local PRICE_MODES = {
      ["Fixed Price"]=true, ["Tip"]=true, ["Negotiable"]=true, ["Free"]=true,
    }
    local AVAILABILITY = {
      ["Available Now"]=true, ["Today"]=true, ["This Session"]=true, ["Scheduled"]=true,
    }

    local function mkt_epoch()
      return tonumber(time and time() or 0) or 0
    end

    local function mktui_data_changed()
      local ui = _G.SignalFireMarketplaceUI151
      if ui and ui.OnMarketplaceDataChanged then ui:OnMarketplaceDataChanged() end
    end

    local function mktui_favorites_changed()
      local ui = _G.SignalFireMarketplaceUI151
      if ui and ui.OnMarketplaceFavoritesChanged then ui:OnMarketplaceFavoritesChanged() end
    end

    local function mkt_trim(value)
      local text = tostring(value or "")
      text = string.gsub(text, "[%c]", " ")
      text = string.gsub(text, "^%s+", "")
      text = string.gsub(text, "%s+$", "")
      text = string.gsub(text, "%s+", " ")
      return text
    end

    local function mkt_text(value, maximum)
      local text = mkt_trim(value)
      if maximum and string.len(text) > maximum then text = string.sub(text, 1, maximum) end
      return text
    end

    local function mkt_key(value)
      return string.lower(mkt_text(value, 160))
    end

    local function mkt_owner_key(value)
      local text = tostring(value or "")
      text = string.gsub(text, "|[cC]%x%x%x%x%x%x%x%x", "")
      text = string.gsub(text, "|[rR]", "")
      text = mkt_text(text, 48)
      text = string.gsub(text, "%-.*$", "")
      return string.lower(mkt_text(text, 48))
    end

    local function mkt_slug(value)
      local slug = string.lower(mkt_text(value, 48))
      slug = string.gsub(slug, "[^%w]+", "-")
      slug = string.gsub(slug, "^-+", "")
      slug = string.gsub(slug, "-+$", "")
      if slug == "" then slug = "player" end
      return slug
    end

    local function mkt_count(rows)
      local count = 0
      for _ in pairs(type(rows) == "table" and rows or {}) do count = count + 1 end
      return count
    end

    local function mkt_copy(row)
      if type(row) ~= "table" then return nil end
      local copy = {}
      for key, value in pairs(row) do copy[key] = value end
      return copy
    end

    local function mkt_profile()
      if B.SF143_GetProfileId then
        local ok, value = pcall(B.SF143_GetProfileId, B)
        if ok and value and tostring(value) ~= "" then return tostring(value) end
      end
      return tostring(BronzeLFG_DB and BronzeLFG_DB.options
        and BronzeLFG_DB.options.serverProfile or "Triumvirate")
    end

    local function mkt_profile_code(profile)
      return tostring(profile) == "Ascension" and "a" or "t"
    end

    local function mkt_player()
      local name = UnitName and UnitName("player") or nil
      name = mkt_text(name, 48)
      return name ~= "" and name or "Player"
    end

    local function mkt_emit(text)
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. tostring(text or ""))
      end
    end

    local function mkt_default_settings(settings)
      settings = type(settings) == "table" and settings or {}
      if tonumber(settings.defaultExpirationMinutes) == nil then settings.defaultExpirationMinutes = 60 end
      if settings.lastListingType == nil then settings.lastListingType = "Crafting Offer" end
      if settings.lastProfession == nil then settings.lastProfession = "" end
      if settings.lastLocation == nil then settings.lastLocation = "" end
      if settings.lastAvailability == nil then settings.lastAvailability = "Available Now" end
      return settings
    end

    function M:RecordError(message)
      self.errorCount = (tonumber(self.errorCount or 0) or 0) + 1
      self.lastError = mkt_text(message, 240)
    end

    function M:IsEnabled()
      return B.SFModuleIsEnabled and B:SFModuleIsEnabled(self.moduleKey) == true or false
    end

    -- Keep UI ownership checks aligned with listing normalization.  This is
    -- deliberately an exact, normalized key rather than display-name matching.
    function M:GetCurrentOwnerKey()
      return mkt_owner_key(mkt_player())
    end
    function M:OwnerKey(value) return mkt_owner_key(value) end

    function M:ReadProfileStore(profile)
      local root = BronzeLFG_DB and BronzeLFG_DB.marketplace
      if type(root) ~= "table" or type(root.profiles) ~= "table" then return nil end
      local store = root.profiles[tostring(profile or mkt_profile())]
      return type(store) == "table" and store or nil
    end

    function M:EnsureProfileStore(profile)
      BronzeLFG_DB = BronzeLFG_DB or {}
      local repairs = 0
      if type(BronzeLFG_DB.marketplace) ~= "table" then
        BronzeLFG_DB.marketplace = {}; repairs = repairs + 1
      end
      local root = BronzeLFG_DB.marketplace
      local version = tonumber(root.schemaVersion or 0) or 0
      if version > self.schemaVersion then return nil, "Marketplace data uses a newer schema" end
      if type(root.profiles) ~= "table" then root.profiles = {}; repairs = repairs + 1 end
      profile = tostring(profile or mkt_profile())
      if type(root.profiles[profile]) ~= "table" then root.profiles[profile] = {}; repairs = repairs + 1 end
      local store = root.profiles[profile]
      if type(store.listingsById) ~= "table" then store.listingsById = {}; repairs = repairs + 1 end
      if type(store.listingOrder) ~= "table" then store.listingOrder = {}; repairs = repairs + 1 end
      if type(store.favoritesById) ~= "table" then store.favoritesById = {}; repairs = repairs + 1 end
      if type(store.settings) ~= "table" then store.settings = {}; repairs = repairs + 1 end
      store.settings = mkt_default_settings(store.settings)
      local sequence = math.floor(tonumber(store.nextSequence or 1) or 1)
      if sequence < 1 then sequence = 1; repairs = repairs + 1 end
      store.nextSequence = sequence
      if root.schemaVersion ~= self.schemaVersion then root.schemaVersion = self.schemaVersion; repairs = repairs + 1 end
      return store, repairs
    end

    function M:NormalizeListing(input, existing, profile, migrating)
      if type(input) ~= "table" then return nil, "listing must be a table" end
      profile = tostring(profile or mkt_profile())
      local listingType = mkt_text(input.listingType or (existing and existing.listingType), 32)
      if not LISTING_TYPES[listingType] then return nil, "invalid listing type" end
      local profession = mkt_text(input.profession or (existing and existing.profession), 64)
      if profession == "" then return nil, "profession is required" end
      local itemName = mkt_text(input.itemName or (existing and existing.itemName), 128)
      if itemName == "" then return nil, "item or recipe is required" end
      local recipeName = mkt_text(input.recipeName or (existing and existing.recipeName), 128)
      local materials = mkt_text(input.materialsPolicy or (existing and existing.materialsPolicy) or "Discuss", 32)
      if not MATERIALS[materials] then return nil, "invalid materials policy" end
      local priceMode = mkt_text(input.priceMode or (existing and existing.priceMode) or "Negotiable", 24)
      if not PRICE_MODES[priceMode] then return nil, "invalid price mode" end
      local availability = mkt_text(input.availability or (existing and existing.availability) or "Available Now", 32)
      if not AVAILABILITY[availability] then return nil, "invalid availability" end
      local owner = existing and existing.owner or mkt_text(input.owner or mkt_player(), 48)
      if owner == "" then return nil, "owner is required" end
      local createdAt = math.floor(tonumber(existing and existing.createdAt or input.createdAt or mkt_epoch()) or mkt_epoch())
      local current = mkt_epoch()
      local expiresAt = tonumber(input.expiresAt)
      if not expiresAt and input.expirationMinutes ~= nil then
        local minutes = tonumber(input.expirationMinutes or 60) or 60
        minutes = math.max(30, math.min(24 * 60, minutes))
        expiresAt = current + math.floor(minutes * 60)
      end
      if not expiresAt then expiresAt = tonumber(existing and existing.expiresAt) end
      if not expiresAt then expiresAt = current + 60 * 60 end
      expiresAt = math.floor(expiresAt)
      if expiresAt <= createdAt and not migrating then return nil, "expiration must be after creation" end
      local priceCopper = math.floor(tonumber(input.priceCopper
        or (existing and existing.priceCopper) or 0) or 0)
      priceCopper = math.max(0, math.min(2147483647, priceCopper))
      local row = {
        schemaVersion=self.schemaVersion,
        id=existing and tostring(existing.id or "") or tostring(input.id or ""),
        profile=profile,
        owner=owner,
        ownerKey=mkt_owner_key(owner),
        listingType=listingType,
        profession=profession,
        professionKey=mkt_key(profession),
        itemName=itemName,
        itemKey=mkt_key(itemName),
        recipeName=recipeName,
        recipeKey=mkt_key(recipeName),
        materialsPolicy=materials,
        priceMode=priceMode,
        priceCopper=priceCopper,
        priceText=mkt_text(input.priceText or (existing and existing.priceText), 80),
        location=mkt_text(input.location or (existing and existing.location) or "Anywhere", 64),
        availability=availability,
        notes=mkt_text(input.notes or (existing and existing.notes), 240),
        createdAt=createdAt,
        updatedAt=migrating and math.floor(tonumber(input.updatedAt or createdAt) or createdAt) or current,
        expiresAt=expiresAt,
      }
      if row.location == "" then row.location = "Anywhere" end
      row.locationKey = mkt_key(row.location)
      return row
    end

    function M:NormalizeNetworkListing(input, profile)
      local row, err = self:NormalizeListing(input, nil, profile, true)
      if not row then return nil, err end
      row.id = tostring(input.id or "")
      row.updatedAt = math.floor(tonumber(input.updatedAt or 0) or 0)
      if row.updatedAt < row.createdAt then return nil, "invalid revision" end
      return row
    end

    function M:IsStableListingId(id)
      return type(id) == "string" and #id <= 128 and string.match(id, "^mkt1:[at]:[%w%-]+:%d+:%d+$") ~= nil
    end

    function M:PruneStaleFavorites(store, stamp)
      if type(store) ~= "table" or type(store.favoritesById) ~= "table" then return 0 end
      stamp = tonumber(stamp or mkt_epoch()) or mkt_epoch()
      local removed = 0
      for id, favorite in pairs(store.favoritesById) do
        local added = type(favorite) == "table" and tonumber(favorite.addedAt or 0) or 0
        if type(favorite) ~= "table" or (not store.listingsById[id]
          and stamp - added > self.favoriteStaleTTL) then
          store.favoritesById[id] = nil
          removed = removed + 1
        end
      end
      return removed
    end

    function M:MigrateProfile(profile)
      profile = tostring(profile or mkt_profile())
      local store, repairsOrError = self:EnsureProfileStore(profile)
      if not store then return nil, repairsOrError end
      local repairs = tonumber(repairsOrError or 0) or 0
      local valid = {}
      local maximumSequence = 0
      for id, source in pairs(store.listingsById) do
        local textId = tostring(id or "")
        local row, err = self:NormalizeListing(source, nil, profile, true)
        local expectedPrefix = "mkt1:" .. mkt_profile_code(profile) .. ":"
        if row and string.sub(textId, 1, string.len(expectedPrefix)) == expectedPrefix
          and string.match(textId, "^mkt1:[at]:[%w%-]+:%d+:%d+$") then
          row.id = textId
          valid[textId] = row
          local sequence = tonumber(string.match(textId, ":(%d+)$") or 0) or 0
          if sequence > maximumSequence then maximumSequence = sequence end
          if source.id ~= textId or source.schemaVersion ~= self.schemaVersion or source.ownerKey ~= row.ownerKey then repairs = repairs + 1 end
        else
          repairs = repairs + 1
          if err then self:RecordError("migration rejected " .. textId .. ": " .. err) end
        end
      end
      store.listingsById = valid
      local ordered, seen = {}, {}
      for _, id in ipairs(store.listingOrder or {}) do
        if valid[id] and not seen[id] then
          seen[id] = true
          table.insert(ordered, id)
        end
      end
      local appended = {}
      for id in pairs(valid) do if not seen[id] then table.insert(appended, id) end end
      table.sort(appended, function(left, right)
        local a, b = valid[left], valid[right]
        if a.createdAt == b.createdAt then return left < right end
        return a.createdAt < b.createdAt
      end)
      for _, id in ipairs(appended) do table.insert(ordered, id) end
      if #ordered > self.maximumListings then
        for index = 1, #ordered - self.maximumListings do valid[ordered[index]] = nil; repairs = repairs + 1 end
        local kept = {}
        for index = #ordered - self.maximumListings + 1, #ordered do table.insert(kept, ordered[index]) end
        ordered = kept
      end
      store.listingOrder = ordered
      if store.nextSequence <= maximumSequence then store.nextSequence = maximumSequence + 1; repairs = repairs + 1 end
      self:PruneStaleFavorites(store, mkt_epoch())
      return store, {repairs=repairs, listings=#ordered}
    end

    local function mkt_bucket_add(index, key, id)
      if key == "" then return end
      local bucket = index[key]
      if not bucket then bucket = {}; index[key] = bucket end
      bucket[id] = true
    end

    local function mkt_bucket_remove(index, key, id)
      local bucket = index[key]
      if not bucket then return end
      bucket[id] = nil
      if not next(bucket) then index[key] = nil end
    end

    function M:IndexListing(runtime, row)
      if not runtime or not row or runtime.byId[row.id] then return false end
      runtime.byId[row.id] = row
      runtime.expiration[row.id] = row.expiresAt
      mkt_bucket_add(runtime.byOwner, row.ownerKey, row.id)
      mkt_bucket_add(runtime.byType, row.listingType, row.id)
      mkt_bucket_add(runtime.byProfession, row.professionKey, row.id)
      mkt_bucket_add(runtime.byItem, row.itemKey, row.id)
      mkt_bucket_add(runtime.byLocation, row.locationKey, row.id)
      mkt_bucket_add(runtime.byAvailability, row.availability, row.id)
      runtime.indexCount = runtime.indexCount + 1
      return true
    end

    function M:UnindexListing(runtime, row)
      if not runtime or not row or runtime.byId[row.id] == nil then return false end
      runtime.byId[row.id] = nil
      runtime.expiration[row.id] = nil
      mkt_bucket_remove(runtime.byOwner, row.ownerKey, row.id)
      mkt_bucket_remove(runtime.byType, row.listingType, row.id)
      mkt_bucket_remove(runtime.byProfession, row.professionKey, row.id)
      mkt_bucket_remove(runtime.byItem, row.itemKey, row.id)
      mkt_bucket_remove(runtime.byLocation, row.locationKey, row.id)
      mkt_bucket_remove(runtime.byAvailability, row.availability, row.id)
      runtime.indexCount = math.max(0, runtime.indexCount - 1)
      return true
    end

    function M:NewRuntime(profile, store)
      self.runtimeSequence = self.runtimeSequence + 1
      return {
        active=true, profile=profile, store=store,
        generation=self.runtimeSequence, dataGeneration=1, favoritesGeneration=1, indexCount=0,
        byId={}, byOwner={}, byType={}, byProfession={}, byItem={},
        byLocation={}, byAvailability={}, expiration={},
        remoteById={}, remoteOrder={}, remoteSourceById={}, remoteCount=0,
        events=0, filters=0, onUpdate=0, queues=0, views=0,
        timerActive=false, expirationRemovals=0, indexRepairs=0, errors=0,
      }
    end

    function M:RebuildIndexes(runtime)
      runtime = runtime or self.runtime
      if not runtime then return false, "runtime is inactive" end
      runtime.byId, runtime.byOwner, runtime.byType = {}, {}, {}
      runtime.byProfession, runtime.byItem, runtime.byLocation = {}, {}, {}
      runtime.byAvailability, runtime.expiration = {}, {}
      runtime.indexCount = 0
      local repairs = 0
      local order, seen = {}, {}
      for _, id in ipairs(runtime.store.listingOrder or {}) do
        local row = runtime.store.listingsById[id]
        if row and not seen[id] then
          seen[id] = true
          table.insert(order, id)
          if not self:IndexListing(runtime, row) then repairs = repairs + 1 end
        else
          repairs = repairs + 1
        end
      end
      for id, row in pairs(runtime.store.listingsById or {}) do
        if runtime.byId[id] == nil then
          self:IndexListing(runtime, row)
          table.insert(order, id)
          repairs = repairs + 1
        end
      end
      runtime.store.listingOrder = order
      runtime.indexRepairs = runtime.indexRepairs + repairs
      self.indexRepairs = self.indexRepairs + repairs
      return true, repairs
    end

    function M:RepairIndexes()
      return self:RebuildIndexes(self.runtime)
    end

    function M:CancelExpiration()
      if B.SF151_CancelDelayed then B:SF151_CancelDelayed(self.expirationTaskKey) end
      self.timerActive = false
      if self.runtime then self.runtime.timerActive = false end
    end

    function M:ScheduleExpiration()
      local runtime = self.runtime
      self:CancelExpiration()
      if not runtime or not runtime.active or not B.SF151_ScheduleDelayed then return false end
      local nearest = nil
      for _, expiresAt in pairs(runtime.expiration) do
        expiresAt = tonumber(expiresAt)
        if expiresAt and (not nearest or expiresAt < nearest) then nearest = expiresAt end
      end
      if not nearest then return false end
      local generation = runtime.generation
      local key = B:SF151_ScheduleDelayed(self.expirationTaskKey,
        math.max(0, nearest - mkt_epoch()), function()
          local current = M.runtime
          if not current or current.generation ~= generation or not M:IsEnabled() then return end
          M.timerActive = false
          current.timerActive = false
          M:ExpireListings("deadline")
        end)
      runtime.timerActive = key and true or false
      self.timerActive = runtime.timerActive
      return runtime.timerActive
    end

    function M:RemovePersisted(runtime, id)
      local row = runtime and runtime.store.listingsById[id]
      if not row then return false end
      self:UnindexListing(runtime, row)
      runtime.store.listingsById[id] = nil
      for index = #runtime.store.listingOrder, 1, -1 do
        if runtime.store.listingOrder[index] == id then table.remove(runtime.store.listingOrder, index) end
      end
      return true
    end

    function M:ExpireListings()
      local runtime = self.runtime
      if not runtime then return 0 end
      local stamp, expired = mkt_epoch(), {}
      for id, expiresAt in pairs(runtime.expiration) do
        if tonumber(expiresAt or 0) <= stamp then table.insert(expired, id) end
      end
      for _, id in ipairs(expired) do
        if runtime.store.listingsById[id] then
          local row = runtime.byId[id]
          self:RemovePersisted(runtime, id)
          local network = _G.SignalFireMarketplaceNetwork2A
          if network and network.QueueRemove and row and self:IsEnabled() then network:QueueRemove(row) end
        else
          local network = _G.SignalFireMarketplaceNetwork2A
          if network and network.RemoveRemote then network:RemoveRemote(id, "expired") end
        end
      end
      if #expired > 0 then
        runtime.dataGeneration = runtime.dataGeneration + 1
        runtime.expirationRemovals = runtime.expirationRemovals + #expired
        self.expirationRemovals = self.expirationRemovals + #expired
        mktui_data_changed()
      end
      local prunedFavorites = self:PruneStaleFavorites(runtime.store, stamp)
      if prunedFavorites > 0 then
        runtime.favoritesGeneration = runtime.favoritesGeneration + 1
        mktui_favorites_changed()
      end
      self:ScheduleExpiration()
      return #expired
    end

    function M:GenerateId(runtime, owner, stamp)
      local store = runtime.store
      local sequence = math.max(1, math.floor(tonumber(store.nextSequence or 1) or 1))
      local prefix = "mkt1:" .. mkt_profile_code(runtime.profile) .. ":" .. mkt_slug(owner)
        .. ":" .. tostring(math.floor(stamp)) .. ":"
      local id = prefix .. string.format("%04d", sequence)
      while store.listingsById[id] do
        sequence = sequence + 1
        id = prefix .. string.format("%04d", sequence)
      end
      store.nextSequence = sequence + 1
      return id
    end

    function M:CreateListing(input)
      local runtime = self.runtime
      if not runtime or not runtime.active then return nil, "Marketplace module is disabled" end
      if #(runtime.store.listingOrder or {}) >= self.maximumListings then return nil, "Marketplace listing limit reached" end
      local row, err = self:NormalizeListing(input, nil, runtime.profile, false)
      if not row then return nil, err end
      local ownerCount = 0
      for _, localId in ipairs(runtime.store.listingOrder or {}) do
        local localRow = runtime.store.listingsById[localId]
        if localRow and localRow.ownerKey == row.ownerKey then ownerCount = ownerCount + 1 end
      end
      if ownerCount >= self.maximumOwnerListings then return nil, "owner listing limit reached" end
      row.id = self:GenerateId(runtime, row.owner, row.createdAt)
      runtime.store.listingsById[row.id] = row
      table.insert(runtime.store.listingOrder, row.id)
      self:IndexListing(runtime, row)
      runtime.dataGeneration = runtime.dataGeneration + 1
      self:ScheduleExpiration()
      mktui_data_changed()
      local network = _G.SignalFireMarketplaceNetwork2A
      if network and network.QueueUpsert then network:QueueUpsert(row) end
      return mkt_copy(row)
    end

    function M:GetListing(id)
      local runtime = self.runtime
      local row = runtime and runtime.byId[tostring(id or "")] or nil
      return mkt_copy(row)
    end

    function M:ResolveLocalLink(id)
      if type(id) ~= "string" or id == "" or #id > self.maximumLocalLinkIdLength
          or not string.match(id, "^mkt1:[at]:[%w%-]+:%d+:%d+$") then
        return nil, "Marketplace listing is unavailable."
      end
      local runtime = self.runtime
      if not self:IsEnabled() or not runtime or not runtime.active or runtime.profile ~= mkt_profile() then return nil, "Marketplace listing is unavailable." end
      local row = runtime.byId[id]
      if not row or row.id ~= id or row.profile ~= runtime.profile or tonumber(row.expiresAt or 0) <= mkt_epoch() then return nil, "Marketplace listing is unavailable." end
      return row
    end
    function M:BuildLocalLink(id)
      local row, err = self:ResolveLocalLink(id); if not row then return nil, err end
      local profession = mkt_text(tostring(row.profession or ""):gsub("[%c|%[%]]", ""), 48)
      local item = mkt_text(tostring(row.itemName or ""):gsub("[%c|%[%]]", ""), 96)
      local title = mkt_text(profession .. ": " .. item, 120)
      local link = "|cffd4a017|Hsignalfiremkt:" .. row.id .. "|h[" .. title .. "]|h|r"
      if #link > self.maximumLocalLinkLength then return nil, "Marketplace listing is unavailable." end
      return link
    end
    function M:OpenWhisper(id)
      local row = self:ResolveLocalLink(id)
      if not row or mkt_text(row.owner, 48) == "" or row.ownerKey == self:GetCurrentOwnerKey() then return false end
      if ChatFrame_SendTell then ChatFrame_SendTell(row.owner); return true end
      if ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. row.owner .. " "); return true end
      if ChatEdit_ActivateChat and ChatFrameEditBox then
        ChatFrameEditBox:SetText("/w " .. row.owner .. " ")
        ChatEdit_ActivateChat(ChatFrameEditBox)
        return true
      end
      return false
    end
    function M:HandleLocalLink(id)
      local row = self:ResolveLocalLink(id)
      if not row then mkt_emit("Marketplace listing is unavailable."); return false end
      local ui = _G.SignalFireMarketplaceUI151
      if not (ui and ui.OpenExactListing and ui:OpenExactListing(row.id)) then
        mkt_emit("Marketplace listing is unavailable.")
        return false
      end
      return true
    end
    function M:RegisterLocalLinkHandler()
      if self.localLinkRegistered then return true end
      self.localLinkCallback = self.localLinkCallback or function(_, id) return M:HandleLocalLink(id) end
      self.localLinkRegistered = B.RegisterLinkHandler
        and B:RegisterLinkHandler("signalfiremkt", self, self.localLinkCallback) == true or false
      return self.localLinkRegistered
    end
    function M:UnregisterLocalLinkHandler()
      local removed = B.UnregisterLinkHandler
        and B:UnregisterLinkHandler("signalfiremkt", self) == true or false
      self.localLinkRegistered = false
      return removed
    end

    function M:EditListing(id, changes)
      local runtime = self.runtime
      id = tostring(id or "")
      local existing = runtime and runtime.byId[id]
      if not existing then return nil, "listing not found" end
      local row, err = self:NormalizeListing(changes or {}, existing, runtime.profile, false)
      if not row then return nil, err end
      row.id = existing.id
      self:UnindexListing(runtime, existing)
      runtime.store.listingsById[id] = row
      self:IndexListing(runtime, row)
      runtime.dataGeneration = runtime.dataGeneration + 1
      self:ScheduleExpiration()
      mktui_data_changed()
      local network = _G.SignalFireMarketplaceNetwork2A
      if network and network.QueueUpsert then network:QueueUpsert(row) end
      return mkt_copy(row)
    end

    function M:RemoveListing(id)
      local runtime = self.runtime
      id = tostring(id or "")
      local row = runtime and runtime.store.listingsById[id]
      if not runtime or not row or not self:RemovePersisted(runtime, id) then return false, "listing not found" end
      runtime.dataGeneration = runtime.dataGeneration + 1
      self:ScheduleExpiration()
      mktui_data_changed()
      local network = _G.SignalFireMarketplaceNetwork2A
      if network and network.QueueRemove then network:QueueRemove(row) end
      return true
    end

    function M:SetFavorite(id, enabled)
      local runtime = self.runtime
      id = tostring(id or "")
      if not runtime then return false, "Marketplace module is disabled" end
      if enabled == false then
        if runtime.store.favoritesById[id] == nil then return true end
        runtime.store.favoritesById[id] = nil
        runtime.favoritesGeneration = (tonumber(runtime.favoritesGeneration or 0) or 0) + 1
        mktui_favorites_changed()
        return true
      end
      local row = runtime.byId[id]
      if not row then return false, "listing not found" end
      if runtime.store.favoritesById[id] ~= nil then return true end
      runtime.store.favoritesById[id] = {
        addedAt=mkt_epoch(), owner=row.owner, profession=row.profession,
        itemName=row.itemName, listingType=row.listingType,
      }
      runtime.favoritesGeneration = (tonumber(runtime.favoritesGeneration or 0) or 0) + 1
      mktui_favorites_changed()
      return true
    end

    function M:IsFavorite(id)
      local runtime = self.runtime
      return runtime and runtime.store.favoritesById[tostring(id or "")] ~= nil or false
    end

    function M:Enable(profile)
      profile = tostring(profile or mkt_profile())
      if not self:IsEnabled() then self:Disable("module-disabled"); return false, "module disabled" end
      if self.runtime and self.runtime.active and self.runtime.profile == profile then
        local currentUI = _G.SignalFireMarketplaceUI151
        if currentUI and currentUI.Enable then return currentUI:Enable(profile) end
        return true
      end
      self:Disable("profile-change")
      local store, report = self:MigrateProfile(profile)
      if not store then self:RecordError(report); return false, report end
      local runtime = self:NewRuntime(profile, store)
      self.runtime = runtime
      local ok, repairs = self:RebuildIndexes(runtime)
      if not ok then self:RecordError(repairs); self:Disable("index-error"); return false, repairs end
      runtime.indexRepairs = runtime.indexRepairs + (tonumber(report.repairs or 0) or 0)
      self.indexRepairs = self.indexRepairs + (tonumber(report.repairs or 0) or 0)
      self:ExpireListings("enable")
      if not self:RegisterLocalLinkHandler() then
        self:RecordError("Marketplace hyperlink handler is unavailable")
        self:Disable("link-handler-error")
        return false, "Marketplace hyperlink handler is unavailable"
      end
      local network = _G.SignalFireMarketplaceNetwork2A
      if network and network.Enable and not network:Enable(runtime) then
        self:Disable("network-handler-error")
        return false, "Marketplace network handler is unavailable"
      end
      local marketplaceUI = _G.SignalFireMarketplaceUI151
      if marketplaceUI and marketplaceUI.Enable then
        local uiOK, uiResult, uiError = pcall(marketplaceUI.Enable, marketplaceUI, profile)
        if not uiOK or uiResult == false then
          self:RecordError(uiOK and uiError or uiResult)
          self:Disable("ui-enable-error")
          return false, uiOK and uiError or uiResult
        end
      end
      return true
    end

    function M:Disable(reason)
      self:CancelExpiration()
      local network = _G.SignalFireMarketplaceNetwork2A
      if network and network.Disable then network:Disable(reason) end
      self:UnregisterLocalLinkHandler()
      local marketplaceUI = _G.SignalFireMarketplaceUI151
      if marketplaceUI and marketplaceUI.Disable then
        local ok, err = pcall(marketplaceUI.Disable, marketplaceUI, reason)
        if not ok then self:RecordError(err) end
      end
      local runtime = self.runtime
      if runtime then
        runtime.active = false
        runtime.byId, runtime.byOwner, runtime.byType = nil, nil, nil
        runtime.byProfession, runtime.byItem, runtime.byLocation = nil, nil, nil
        runtime.byAvailability, runtime.expiration = nil, nil
        runtime.remoteById, runtime.remoteOrder, runtime.remoteSourceById = nil, nil, nil
        runtime.store = nil
      end
      self.runtime = nil
      self.selectedId = nil
      self.editId = nil
      self.lastDisableReason = tostring(reason or "disabled")
      return true
    end

    function M:Reconcile(reason)
      if self.reconciling then return false, "reconcile already active" end
      self.reconciling = true
      local ok, result, detail = pcall(function()
        if M:IsEnabled() then return M:Enable(mkt_profile()) end
        M:Disable(reason or "module-disabled")
        return true
      end)
      self.reconciling = nil
      if not ok then
        self:RecordError(result)
        self:Disable("reconcile-error")
        return false, result
      end
      return result, detail
    end

    function M:GetStatus()
      local profile = mkt_profile()
      local root = BronzeLFG_DB and BronzeLFG_DB.marketplace
      local store = self:ReadProfileStore(profile)
      local runtime = self.runtime
      local active = runtime and runtime.active and runtime.profile == profile or false
      local timers = self.timerActive and 1 or 0
      local indexes = active and tonumber(runtime.indexCount or 0) or 0
      local enabled = self:IsEnabled()
      local marketplaceUI = _G.SignalFireMarketplaceUI151
      local panel = marketplaceUI and marketplaceUI.GetPanelState
        and marketplaceUI:GetPanelState() or "unbuilt"
      local uiClean = not marketplaceUI or not marketplaceUI.IsDisabledClean
        or marketplaceUI:IsDisabledClean()
      local disabledClean = not enabled and not runtime and timers == 0 and indexes == 0
        and not self.localLinkRegistered and uiClean
      local network = _G.SignalFireMarketplaceNetwork2A
      local networkStatus = network and network.GetDiagnostics and network:GetDiagnostics()
        or {network="inactive",remote=0,pending=0,dedup=0,outgoing=0,wake=false,handler=false}
      return {
        owner=self.generation, profile=profile, enabled=enabled,
        schema=type(root) == "table" and tonumber(root.schemaVersion or 0) or 0,
        persisted=store and mkt_count(store.listingsById) or 0,
        favorites=store and mkt_count(store.favoritesById) or 0,
        nextSequence=store and tonumber(store.nextSequence or 1) or 1,
        runtime=active and "active" or "inactive", panel=panel,
        runtimeGeneration=active and runtime.generation or 0,
        indexes=indexes, views=0, events=0, filters=0, timers=timers,
        onUpdate=0, queues=0,
        expirationRemovals=tonumber(self.expirationRemovals or 0) or 0,
        indexRepairs=tonumber(self.indexRepairs or 0) or 0,
        errors=tonumber(self.errorCount or 0) or 0,
        disabledClean=disabledClean,
        network=networkStatus,
      }
    end

    function M:PrintStatus()
      local status = self:GetStatus()
      mkt_emit("marketplace owner=" .. tostring(status.owner) .. ", profile=" .. tostring(status.profile)
        .. ", enabled=" .. tostring(status.enabled))
      mkt_emit("schema=" .. tostring(status.schema) .. ", persisted=" .. tostring(status.persisted)
        .. ", favorites=" .. tostring(status.favorites) .. ", nextSequence=" .. tostring(status.nextSequence))
      mkt_emit("runtime=" .. tostring(status.runtime) .. ", panel=" .. tostring(status.panel)
        .. ", generation=" .. tostring(status.runtimeGeneration)
        .. ", indexes=" .. tostring(status.indexes) .. ", views=" .. tostring(status.views))
      mkt_emit("events=" .. tostring(status.events) .. ", filters=" .. tostring(status.filters)
        .. ", timers=" .. tostring(status.timers) .. ", onUpdate=" .. tostring(status.onUpdate)
        .. ", queues=" .. tostring(status.queues) .. ", disabledClean=" .. tostring(status.disabledClean))
      mkt_emit("expirationRemovals=" .. tostring(status.expirationRemovals)
        .. ", indexRepairs=" .. tostring(status.indexRepairs) .. ", errors=" .. tostring(status.errors))
      local n = status.network
      mkt_emit("network=" .. tostring(n.network) .. ", remote=" .. tostring(n.remote)
        .. ", sent=" .. tostring(n.sent) .. ", received=" .. tostring(n.received)
        .. ", accepted=" .. tostring(n.accepted) .. ", rejected=" .. tostring(n.rejected)
        .. ", stale=" .. tostring(n.stale) .. ", spoofed=" .. tostring(n.spoofed)
        .. ", duplicate=" .. tostring(n.duplicate) .. ", pending=" .. tostring(n.pending)
        .. ", dedup=" .. tostring(n.dedup) .. ", outgoing=" .. tostring(n.outgoing)
        .. ", dropped=" .. tostring(n.dropped) .. ", wake=" .. tostring(n.wake)
        .. ", handler=" .. tostring(n.handler))
      return status
    end

    function B:SFMarketplaceHandleSlash(command)
      local cmd = string.lower(mkt_trim(command))
      if cmd == "marketplace status" or cmd == "market status" then
        M:PrintStatus(); return true
      elseif cmd == "marketplace sync" or cmd == "market sync" then
        local network = _G.SignalFireMarketplaceNetwork2A
        if not M:IsEnabled() or not (network and network.ManualSync) or not network:ManualSync() then
          mkt_emit("Tradeskill Marketplace sync is unavailable.")
          return true
        end
        mkt_emit("Marketplace discovery and replay queued.")
        return true
      elseif cmd == "marketplace on" or cmd == "market on" then
        self:SFModuleSetEnabled(M.moduleKey, true)
        mkt_emit("Tradeskill Marketplace enabled for " .. mkt_profile() .. ".")
        return true
      elseif cmd == "marketplace off" or cmd == "market off" then
        self:SFModuleSetEnabled(M.moduleKey, false)
        mkt_emit("Tradeskill Marketplace disabled for " .. mkt_profile() .. ".")
        return true
      elseif cmd == "marketplace default" or cmd == "market default" then
        self:SFModuleUseProfileDefault(M.moduleKey)
        mkt_emit("Tradeskill Marketplace reset to the profile default.")
        return true
      elseif cmd == "marketplace" or cmd == "market" then
        if not M:IsEnabled() then
          mkt_emit("Tradeskill Marketplace is disabled for " .. mkt_profile()
            .. ". Enable it in Options > Modules or use /sf marketplace on.")
          return true
        end
        if self.SFMarketplaceOpen then return self:SFMarketplaceOpen("slash") end
        mkt_emit("Tradeskill Marketplace UI is unavailable.")
        return true
      end
      return false
    end

    function B:SFMarketplaceMigrate(profile) return M:MigrateProfile(profile) end
    function B:SFMarketplaceCreateListing(input) return M:CreateListing(input) end
    function B:SFMarketplaceGetListing(id) return M:GetListing(id) end
    function B:SFMarketplaceEditListing(id, changes) return M:EditListing(id, changes) end
    function B:SFMarketplaceRemoveListing(id) return M:RemoveListing(id) end
    function B:SFMarketplaceSetFavorite(id, enabled) return M:SetFavorite(id, enabled) end
    function B:SFMarketplaceIsFavorite(id) return M:IsFavorite(id) end
    function B:SFMarketplaceExpireListings() return M:ExpireListings("manual") end
    function B:SFMarketplaceRepairIndexes() return M:RepairIndexes() end
    function B:SFMarketplaceGetStatus() return M:GetStatus() end

    M:Reconcile("load")
  end
end
