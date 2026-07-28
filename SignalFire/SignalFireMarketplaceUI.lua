-- SignalFire Tradeskill Marketplace: lazy Browse and owned-listings views.
do
  local B = _G.BronzeLFG
  local M = _G.SignalFireMarketplace151
  local LP = _G.SignalFireLazyPanels151
  if B and M and LP and LP.RegisterPanel and LP.UnregisterPanel then
    local U = _G.SignalFireMarketplaceUI151 or {}
    _G.SignalFireMarketplaceUI151 = U

    U.generation = "1.5.3-marketplace-phase1d"
    U.panelKey = "marketplace"
    U.buildCount = tonumber(U.buildCount or 0) or 0
    U.openCount = tonumber(U.openCount or 0) or 0
    U.refreshCount = tonumber(U.refreshCount or 0) or 0
    U.hiddenRefreshSkips = tonumber(U.hiddenRefreshSkips or 0) or 0

    -- Session-only UI ownership. The single panel and its four buttons have no
    -- TTL or entry growth: they are allocated once on first open, retained for
    -- reuse, and made inert on Disable. Nothing here is persisted.
    local TABS = {"Browse", "My Listings", "Create Listing", "Favorites"}
    local PLACEHOLDERS = {
      ["My Listings"]="No active listings.",
      ["Create Listing"]="No draft listing.",
      ["Favorites"]="No favorite listings.",
    }
    local BROWSE_COLUMNS = {
      {"Player", 88}, {"Type", 92}, {"Profession", 96}, {"Item / Recipe", 150},
      {"Location", 90}, {"Availability", 94}, {"Price / Tip", 86}, {"Expires", 66},
    }
    local BROWSE_PAGE_SIZE = 8
    local MY_LISTINGS_COLUMNS = {
      {"Type", 86}, {"Profession", 92}, {"Item / Recipe", 160}, {"Location", 88},
      {"Availability", 88}, {"Price / Tip", 82}, {"Expires", 62},
    }
    local FAVORITES_COLUMNS = {{"Player", 92}, {"Type", 88}, {"Profession", 94}, {"Item / Recipe", 170}, {"Status", 78}, {"Favorited", 72}}

    local function mktui_emit(text)
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. tostring(text or ""))
      end
    end

    local function mktui_backdrop(frame, alpha)
      frame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3, right=3, top=3, bottom=3},
      })
      frame:SetBackdropColor(.015, .015, .015, alpha or .96)
      frame:SetBackdropBorderColor(.72, .5, .12, 1)
    end

    local function mktui_font(parent, text, size, red, green, blue)
      local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      label:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
      label:SetText(tostring(text or ""))
      label:SetTextColor(red or 1, green or .82, blue or .2)
      return label
    end

    local function mktui_nav_click(button)
      if U.active and button and button.marketplaceTab then U:SetTab(button.marketplaceTab) end
    end

    local function mktui_text(value)
      return tostring(value or "")
    end

    local function mktui_search_key(value)
      return string.lower((mktui_text(value):gsub("^%s+", ""):gsub("%s+$", "")))
    end

    local function mktui_price(row)
      if mktui_text(row.priceText) ~= "" then return row.priceText end
      if row.priceMode == "Free" then return "Free" end
      if row.priceMode == "Negotiable" then return "Negotiable" end
      if row.priceMode == "Tip" then return "Tip" end
      local copper = math.max(0, tonumber(row.priceCopper or 0) or 0)
      local gold = math.floor(copper / 10000)
      local silver = math.floor((copper % 10000) / 100)
      local rest = copper % 100
      local parts = {}
      if gold > 0 then table.insert(parts, tostring(gold) .. "g") end
      if silver > 0 then table.insert(parts, tostring(silver) .. "s") end
      if rest > 0 or #parts == 0 then table.insert(parts, tostring(rest) .. "c") end
      return table.concat(parts, " ")
    end

    local function mktui_remaining(expiresAt, stamp)
      local left = (tonumber(expiresAt or 0) or 0) - stamp
      if left < 60 then return "<1m" end
      if left < 3600 then return tostring(math.floor(left / 60)) .. "m" end
      if left < 86400 then
        local hours = math.floor(left / 3600)
        local minutes = math.floor((left % 3600) / 60)
        return minutes > 0 and (tostring(hours) .. "h " .. tostring(minutes) .. "m") or (tostring(hours) .. "h")
      end
      return tostring(math.floor(left / 86400)) .. "d"
    end

    function U:ClearBrowseSnapshot()
      self.browseSnapshot = nil
      self.browseSnapshotGeneration = nil
      self.browseSnapshotProfile = nil
      self.browseDirty = true
    end

    function U:ClearMyListingsView()
      self.myListingsView = nil
      self.myListingsGeneration = nil
      self.myListingsProfile = nil
      self.myListingsOwnerKey = nil
      self.myListingsDirty = true
    end

    function U:ClearFavoritesView()
      self.favoritesView, self.favoritesGeneration, self.favoritesDataGeneration, self.favoritesProfile, self.favoritesDirty = nil, nil, nil, nil, true
    end

    function U:BuildFavoritesView()
      local runtime = M.runtime
      if not runtime or not runtime.active or runtime.profile ~= self.profile then return nil end
      if self.favoritesView and self.favoritesGeneration == runtime.favoritesGeneration and self.favoritesDataGeneration == runtime.dataGeneration and self.favoritesProfile == runtime.profile then return self.favoritesView end
      local rows, stamp = {}, tonumber(time and time() or 0) or 0
      for id, summary in pairs(runtime.store.favoritesById or {}) do
        if type(summary) == "table" then
          local active = runtime.byId[id]
          local row = active and tonumber(active.expiresAt or 0) > stamp and active or nil
          table.insert(rows, {id=id, active=row ~= nil, row=row, summary=summary, addedAt=tonumber(summary.addedAt or 0) or 0})
        end
      end
      table.sort(rows, function(a, b) if a.addedAt == b.addedAt then return a.id < b.id end return a.addedAt > b.addedAt end)
      self.favoritesView = {total=#rows, rows=rows}; self.favoritesGeneration, self.favoritesDataGeneration, self.favoritesProfile = runtime.favoritesGeneration, runtime.dataGeneration, runtime.profile
      return self.favoritesView
    end

    function U:GetCurrentOwnerKey()
      return M.GetCurrentOwnerKey and M:GetCurrentOwnerKey() or ""
    end

    function U:BuildMyListingsView()
      local runtime = M.runtime
      if not runtime or not runtime.active or runtime.profile ~= self.profile then return nil end
      local ownerKey = self:GetCurrentOwnerKey()
      if ownerKey == "" then return nil end
      if self.myListingsView and self.myListingsGeneration == runtime.dataGeneration
        and self.myListingsProfile == runtime.profile and self.myListingsOwnerKey == ownerKey then return self.myListingsView end
      local bucket, rows, stamp = runtime.byOwner and runtime.byOwner[ownerKey], {}, tonumber(time and time() or 0) or 0
      -- listingOrder is the canonical creation ordering; walk it newest first and
      -- use the owner bucket only for exact membership.
      for index = #(runtime.store.listingOrder or {}), 1, -1 do
        local id = runtime.store.listingOrder[index]
        if bucket and bucket[id] then
          local row = runtime.byId[id]
          if type(row) == "table" and row.id == id and row.profile == runtime.profile and row.ownerKey == ownerKey
            and tonumber(row.expiresAt or 0) > stamp then table.insert(rows, row) end
        end
      end
      self.myListingsView = {generation=runtime.dataGeneration, total=#rows, rows=rows, ownerKey=ownerKey}
      self.myListingsGeneration, self.myListingsProfile, self.myListingsOwnerKey = runtime.dataGeneration, runtime.profile, ownerKey
      return self.myListingsView
    end

    function U:ClearBrowseFilteredView()
      self.browseFilteredView = nil
      self.browseFilteredGeneration = nil
      self.browseFilteredProfile = nil
      self.browseFilteredQuery = nil
      self.browseFilteredType = nil
      self.browseFilteredProfession = nil
      self.browseFilteredLocation = nil
      self.browseFilteredAvailability = nil
      self.browseFilteredFavorites = nil
      self.browseFilteredFavoritesGeneration = nil
    end

    function U:GetAppliedBrowseQuery()
      return mktui_search_key(self.browseSearchQuery)
    end

    function U:GetBrowseListingType() return tostring(self.browseListingType or "") end
    function U:GetBrowseProfessionKey() return mktui_search_key(self.browseProfessionKey) end
    function U:GetBrowseLocationKey() return mktui_search_key(self.browseLocationKey) end
    function U:GetBrowseAvailability() return tostring(self.browseAvailability or "") end

    function U:HasActiveBrowseFilters()
      return self:GetBrowseListingType() ~= "" or self:GetBrowseProfessionKey() ~= ""
        or self:GetBrowseLocationKey() ~= "" or self:GetBrowseAvailability() ~= "" or self.browseFavoritesOnly == true
    end

    function U:SyncBrowseToggleButtons()
      if self.browseFavoritesButton then
        local active = self.browseFavoritesOnly == true
        self.browseFavoritesButton:SetBackdropColor(active and .24 or .04, active and .16 or .04, active and .03 or .04, active and 1 or .92)
        self.browseFavoritesButton:SetBackdropBorderColor(active and 1 or .52, active and .72 or .4, active and .18 or .12, 1)
        self.browseFavoritesButton.label:SetTextColor(active and 1 or .82, active and .9 or .78, active and .48 or .62)
      end
      if self.browseClearFilters then
        local enabled = self.active and self:HasActiveBrowseFilters()
        self.browseClearFilters:SetAlpha(enabled and 1 or .45)
        self.browseClearFilters:EnableMouse(enabled)
      end
    end

    function U:SyncBrowseFilterLabels()
      if self.browseTypeSelector and self.browseTypeSelector.label then
        self.browseTypeSelector.label:SetText(self:GetBrowseListingType() ~= "" and self:GetBrowseListingType() or "All Types")
      end
      if self.browseProfessionSelector and self.browseProfessionSelector.label then
        self.browseProfessionSelector.label:SetText(self.browseProfessionLabel ~= "" and self.browseProfessionLabel or "All Professions")
      end
      if self.browseLocationSelector and self.browseLocationSelector.label then
        self.browseLocationSelector.label:SetText(self.browseLocationLabel ~= "" and self.browseLocationLabel or "All Locations")
      end
      if self.browseAvailabilitySelector and self.browseAvailabilitySelector.label then
        self.browseAvailabilitySelector.label:SetText(self:GetBrowseAvailability() ~= "" and self:GetBrowseAvailability() or "All Availability")
      end
      self:SyncBrowseToggleButtons()
    end

    function U:GetBrowseProfessionOptions(snapshot)
      snapshot = snapshot or self:BuildBrowseSnapshot()
      local choices, seen = {{key="", text="All Professions"}}, {}
      for _, row in ipairs((snapshot and snapshot.rows) or {}) do
        local key = mktui_search_key(row.professionKey)
        if key ~= "" and not seen[key] then
          seen[key] = true
          table.insert(choices, {key=key, text=mktui_text(row.profession)})
        end
      end
      table.sort(choices, function(a, b)
        if a.key == "" then return true end
        if b.key == "" then return false end
        return string.lower(a.text) < string.lower(b.text)
      end)
      return choices
    end

    function U:GetBrowseLocationOptions(snapshot)
      snapshot = snapshot or self:BuildBrowseSnapshot()
      local choices, seen = {{key="", text="All Locations"}}, {}
      for _, row in ipairs((snapshot and snapshot.rows) or {}) do
        local key = mktui_search_key(row.locationKey)
        if key ~= "" and not seen[key] then
          seen[key] = true
          table.insert(choices, {key=key, text=mktui_text(row.location)})
        end
      end
      table.sort(choices, function(a, b)
        if a.key == "" then return true end
        if b.key == "" then return false end
        return string.lower(a.text) < string.lower(b.text)
      end)
      return choices
    end

    function U:ApplyBrowseFilter(listingType, professionKey, professionLabel)
      if not self.active then return false end
      listingType = tostring(listingType or "")
      professionKey = mktui_search_key(professionKey)
      professionLabel = mktui_text(professionLabel)
      if self:GetBrowseListingType() == listingType and self:GetBrowseProfessionKey() == professionKey then return false end
      self.browseListingType, self.browseProfessionKey = listingType, professionKey
      self.browseProfessionLabel = professionKey ~= "" and professionLabel or ""
      self.browsePage = 1
      self:ClearBrowseFilteredView()
      self:SyncBrowseFilterLabels()
      return self:RenderBrowse()
    end

    function U:ApplyBrowseLocation(locationKey, locationLabel)
      if not self.active then return false end
      locationKey, locationLabel = mktui_search_key(locationKey), mktui_text(locationLabel)
      if self:GetBrowseLocationKey() == locationKey then return false end
      self.browseLocationKey, self.browseLocationLabel, self.browsePage = locationKey, locationKey ~= "" and locationLabel or "", 1
      self:ClearBrowseFilteredView()
      self:SyncBrowseFilterLabels()
      return self:RenderBrowse()
    end

    function U:ApplyBrowseAvailability(availability)
      if not self.active then return false end
      availability = tostring(availability or "")
      if self:GetBrowseAvailability() == availability then return false end
      self.browseAvailability, self.browsePage = availability, 1
      self:ClearBrowseFilteredView()
      self:SyncBrowseFilterLabels()
      return self:RenderBrowse()
    end

    function U:ToggleBrowseFavorites()
      if not self.active then return false end
      self.browseFavoritesOnly = not (self.browseFavoritesOnly == true)
      self.browsePage = 1
      self:ClearBrowseFilteredView()
      self:SyncBrowseToggleButtons()
      return self:RenderBrowse()
    end

    function U:ClearBrowseFilters()
      if not self.active or not self:HasActiveBrowseFilters() then return false end
      self.browseListingType, self.browseProfessionKey, self.browseProfessionLabel = "", "", ""
      self.browseLocationKey, self.browseLocationLabel, self.browseAvailability = "", "", ""
      self.browseFavoritesOnly, self.browsePage = false, 1
      self:ClearBrowseFilteredView()
      self:SyncBrowseFilterLabels()
      return self:RenderBrowse()
    end

    function U:BuildBrowseFilteredView()
      local snapshot = self:BuildBrowseSnapshot()
      if not snapshot then return nil end
      local query = self:GetAppliedBrowseQuery()
      local listingType, professionKey = self:GetBrowseListingType(), self:GetBrowseProfessionKey()
      local locationKey, availability = self:GetBrowseLocationKey(), self:GetBrowseAvailability()
      local favoritesOnly = self.browseFavoritesOnly == true
      local favoritesGeneration = favoritesOnly and (tonumber(M.runtime and M.runtime.favoritesGeneration or 0) or 0) or 0
      if self.browseFilteredView and self.browseFilteredGeneration == snapshot.generation
        and self.browseFilteredProfile == self.profile and self.browseFilteredQuery == query
        and self.browseFilteredType == listingType and self.browseFilteredProfession == professionKey
        and self.browseFilteredLocation == locationKey and self.browseFilteredAvailability == availability
        and self.browseFilteredFavorites == favoritesOnly and self.browseFilteredFavoritesGeneration == favoritesGeneration then
        return self.browseFilteredView
      end
      local rows = {}
      for _, row in ipairs(snapshot.rows) do
        if (listingType == "" or row.listingType == listingType)
          and (professionKey == "" or mktui_search_key(row.professionKey) == professionKey)
          and (locationKey == "" or mktui_search_key(row.locationKey) == locationKey)
          and (availability == "" or row.availability == availability)
          and (not favoritesOnly or M:IsFavorite(row.id))
          and (query == "" or (string.find(mktui_search_key(row.itemName), query, 1, true)
            or string.find(mktui_search_key(row.itemKey), query, 1, true)
            or string.find(mktui_search_key(row.recipeName), query, 1, true)
            or string.find(mktui_search_key(row.recipeKey), query, 1, true))) then
          table.insert(rows, row)
        end
      end
      self.browseFilteredView = {generation=snapshot.generation, total=#rows, rows=rows, query=query, listingType=listingType, professionKey=professionKey, locationKey=locationKey, availability=availability, favoritesOnly=favoritesOnly, favoritesGeneration=favoritesGeneration}
      self.browseFilteredGeneration, self.browseFilteredProfile, self.browseFilteredQuery = snapshot.generation, self.profile, query
      self.browseFilteredType, self.browseFilteredProfession = listingType, professionKey
      self.browseFilteredLocation, self.browseFilteredAvailability = locationKey, availability
      self.browseFilteredFavorites, self.browseFilteredFavoritesGeneration = favoritesOnly, favoritesGeneration
      return self.browseFilteredView
    end

    function U:ApplyBrowseSearch()
      if not self.active then return false end
      local query = mktui_search_key(self.browseSearchBox and self.browseSearchBox:GetText() or "")
      if query == "" and self.browseSearchBox then self.browseSearchBox:SetText("") end
      if query == self:GetAppliedBrowseQuery() then
        if self.browseSearchBox then self.browseSearchBox:ClearFocus() end
        return false
      end
      self.browseSearchQuery, self.browsePage = query, 1
      self:ClearBrowseFilteredView()
      if self.browseSearchBox then self.browseSearchBox:ClearFocus() end
      return self:RenderBrowse()
    end

    function U:ClearBrowseSearch()
      if not self.active or self:GetAppliedBrowseQuery() == "" then return false end
      self.browseSearchQuery, self.browsePage = "", 1
      self:ClearBrowseFilteredView()
      if self.browseSearchBox then self.browseSearchBox:SetText(""); self.browseSearchBox:ClearFocus() end
      return self:RenderBrowse()
    end

    function U:OnMarketplaceDataChanged()
      self:ClearBrowseSnapshot()
      self:ClearBrowseFilteredView()
      self:ClearMyListingsView()
      self:ClearFavoritesView()
      if self.active and self:GetPanelState() == "visible" and self.selectedTab == "Browse" then
        if self.selectedListingId then self:RenderDetail() else self:RenderBrowse() end
      elseif self.active and self:GetPanelState() == "visible" and self.selectedTab == "My Listings" then
        if self.mySelectedListingId then self:RenderMyListingsDetail() else self:RenderMyListings() end
      elseif self.active and self:GetPanelState() == "visible" and self.selectedTab == "Favorites" then
        if self.favoriteSelectedId then self:RenderFavoriteDetail() else self:RenderFavorites() end
      end
    end

    function U:SetBrowseToolbarVisible(visible)
      for _, control in ipairs({self.browseSearchLabel, self.browseTypeSelector, self.browseProfessionSelector,
        self.browseLocationSelector, self.browseAvailabilitySelector, self.browseFavoritesButton,
        self.browseSearchBox, self.browseSearchButton, self.browseClear, self.browseClearFilters}) do
        if control then if visible then control:Show() else control:Hide() end end
      end
    end

    function U:OnMarketplaceFavoritesChanged()
      self:ClearFavoritesView()
      if self.browseFavoritesOnly then self:ClearBrowseFilteredView() end
      if self.active and self:GetPanelState() == "visible" and self.selectedTab == "Browse" and not self.selectedListingId then
        if self.browseFavoritesOnly then return self:RenderBrowse() end
      elseif self.active and self:GetPanelState() == "visible" and self.selectedTab == "Favorites" then
        if self.favoriteSelectedId then return self:RenderFavoriteDetail() end
        return self:RenderFavorites()
      end
      self.browseDirty = true
      return false
    end

    function U:BuildBrowseSnapshot()
      local runtime = M.runtime
      if not runtime or not runtime.active or runtime.profile ~= self.profile then return nil end
      if self.browseSnapshot and self.browseSnapshotGeneration == runtime.dataGeneration
        and self.browseSnapshotProfile == runtime.profile then return self.browseSnapshot end
      local stamp, active = tonumber(time and time() or 0) or 0, {}
      for index = #(runtime.store.listingOrder or {}), 1, -1 do
        local id = runtime.store.listingOrder[index]
        local row = runtime.byId[id]
        if type(row) == "table" and row.id == id and row.profile == runtime.profile
          and type(row.owner) == "string" and type(row.listingType) == "string"
          and type(row.profession) == "string" and type(row.itemName) == "string"
          and tonumber(row.expiresAt or 0) > stamp then
          table.insert(active, row)
        end
      end
      self.browseSnapshot = {generation=runtime.dataGeneration, total=#active, rows=active}
      self.browseSnapshotGeneration, self.browseSnapshotProfile = runtime.dataGeneration, runtime.profile
      return self.browseSnapshot
    end

    function U:RenderBrowse()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "Browse" then
        self.browseDirty = true
        return false
      end
      local canonical = self:BuildBrowseSnapshot()
      if not canonical then return false end
      local selectedProfession = self:GetBrowseProfessionKey()
      if selectedProfession ~= "" then
        local valid = false
        for _, option in ipairs(self:GetBrowseProfessionOptions(canonical)) do if option.key == selectedProfession then valid = true break end end
        if not valid then
          self.browseProfessionKey, self.browseProfessionLabel, self.browsePage = "", "", 1
          self:ClearBrowseFilteredView()
          self:SyncBrowseFilterLabels()
        end
      end
      local selectedLocation = self:GetBrowseLocationKey()
      if selectedLocation ~= "" then
        local valid = false
        for _, option in ipairs(self:GetBrowseLocationOptions(canonical)) do if option.key == selectedLocation then valid = true break end end
        if not valid then
          self.browseLocationKey, self.browseLocationLabel, self.browsePage = "", "", 1
          self:ClearBrowseFilteredView()
          self:SyncBrowseFilterLabels()
        end
      end
      local snapshot = self:BuildBrowseFilteredView()
      if not snapshot then return false end
      local stamp = tonumber(time and time() or 0) or 0
      local pages = math.max(1, math.ceil(snapshot.total / BROWSE_PAGE_SIZE))
      self.browsePage = math.max(1, math.min(tonumber(self.browsePage or 1) or 1, pages))
      local first = ((self.browsePage - 1) * BROWSE_PAGE_SIZE) + 1
      local last = math.min(snapshot.total, first + BROWSE_PAGE_SIZE - 1)
      local shown = snapshot.total > 0 and (last - first + 1) or 0
      if shown == 0 then
        local searched = self:GetAppliedBrowseQuery() ~= ""
        local filtered = self:HasActiveBrowseFilters()
        self.browseEmptyState:SetText(searched and filtered and "No marketplace listings match your search and filters."
          or searched and "No marketplace listings match your search."
          or filtered and "No marketplace listings match your filters."
          or "No marketplace listings available.")
        self.browseEmptyState:Show()
      else self.browseEmptyState:Hide() end
      self.browseSummary:SetText(snapshot.total > 0 and ("Showing " .. tostring(first) .. "-" .. tostring(last)
        .. " of " .. tostring(snapshot.total)) or "")
      self.browsePageIndicator:SetText("Page " .. tostring(self.browsePage) .. " of " .. tostring(pages))
      if pages > 1 then
        self.browsePrevious:Show(); self.browseNext:Show(); self.browsePageIndicator:Show()
        self.browsePrevious:EnableMouse(self.browsePage > 1)
        self.browseNext:EnableMouse(self.browsePage < pages)
        self.browsePrevious:SetAlpha(self.browsePage > 1 and 1 or .45)
        self.browseNext:SetAlpha(self.browsePage < pages and 1 or .45)
      else
        self.browsePrevious:Hide(); self.browseNext:Hide(); self.browsePageIndicator:Hide()
      end
      local searched = self:GetAppliedBrowseQuery() ~= ""
      self.browseClear:SetAlpha(searched and 1 or .45)
      self.browseClear:EnableMouse(searched)
      self:SyncBrowseToggleButtons()
      for index, rowControl in ipairs(self.browseRows) do
        local row = snapshot.rows[first + index - 1]
        if row then
          local item = row.itemName
          if row.recipeName and row.recipeName ~= "" and row.recipeName ~= row.itemName then item = item .. " / " .. row.recipeName end
          local values = {row.owner, row.listingType, row.profession, item, row.location, row.availability,
            mktui_price(row), mktui_remaining(row.expiresAt, stamp)}
          local signature = table.concat(values, "\31")
          if rowControl.signature ~= signature then
            for column, value in ipairs(values) do rowControl.labels[column]:SetText(value) end
            rowControl.signature = signature
          end
          rowControl.listingId = row.id
          rowControl:Show()
        else
          rowControl:Hide()
          rowControl.signature, rowControl.listingId = nil, nil
        end
      end
      self.browseRowCount, self.browseDirty = shown, false
      return true
    end

    function U:ChangeBrowsePage(delta)
      if not self.active or self.selectedTab ~= "Browse" or self.selectedListingId then return false end
      local snapshot = self:BuildBrowseFilteredView()
      if not snapshot then return false end
      local pages = math.max(1, math.ceil(snapshot.total / BROWSE_PAGE_SIZE))
      local target = math.max(1, math.min((tonumber(self.browsePage or 1) or 1) + (tonumber(delta or 0) or 0), pages))
      if target == self.browsePage then return false end
      self.browsePage = target
      return self:RenderBrowse()
    end

    function U:ClearSelection()
      self.selectedListingId, self.detailSignature, self.detailDirty = nil, nil, false
    end

    function U:ClearMyListingsSelection()
      self.mySelectedListingId, self.myDetailSignature, self.myDetailDirty, self.myRemoveConfirmId = nil, nil, false, nil
    end

    function U:ClearFavoriteSelection() self.favoriteSelectedId, self.favoriteDetailSignature, self.favoriteDetailDirty = nil, nil, false end

    function U:ResetListingForm()
      local store = M.runtime and M.runtime.store or {}; local settings = store.settings or {}
      self.formEditId, self.formReturnId = nil, nil
      self.formValues = {listingType=settings.lastListingType or "Crafting Offer", profession=settings.lastProfession or "", itemName="", recipeName="", materialsPolicy="Discuss", priceMode="Negotiable", priceText="", location=settings.lastLocation or "", availability=settings.lastAvailability or "Available Now", expirationMinutes=tonumber(settings.defaultExpirationMinutes) or 60, notes=""}
      for key, control in pairs(self.formInputs or {}) do if control.SetText then control:SetText(tostring(self.formValues[key] or "")) end end
      self.formMessage, self.formPreviewSignature = nil, nil
    end
    function U:ShowListingForm(editId)
      if not self.formShell then return false end
      if editId then
        local row = M:GetListing(editId)
        if not row or row.profile ~= self.profile or row.ownerKey ~= self:GetCurrentOwnerKey() then return false end
        self.formEditId, self.formReturnId = row.id, row.id; self.formValues = {listingType=row.listingType, profession=row.profession, itemName=row.itemName, recipeName=row.recipeName, materialsPolicy=row.materialsPolicy, priceMode=row.priceMode, priceText=row.priceText, location=row.location, availability=row.availability, expirationMinutes=0, notes=row.notes}
        for key, control in pairs(self.formInputs) do control:SetText(tostring(self.formValues[key] or "")) end
        self.formPrimary.label:SetText("Save Changes"); self.sectionTitle:SetText("Edit Listing")
      elseif not self.formValues then self:ResetListingForm(); self.formPrimary.label:SetText("Create Listing") end
      self.formShell:Show(); self.placeholder:Hide(); return true
    end
    function U:SubmitListingForm()
      local values = {}; for key, control in pairs(self.formInputs or {}) do values[key] = mktui_text(control:GetText()) end
      values.listingType = values.listingType ~= "" and values.listingType or "Crafting Offer"; values.materialsPolicy = values.materialsPolicy ~= "" and values.materialsPolicy or "Discuss"; values.priceMode = values.priceMode ~= "" and values.priceMode or "Negotiable"; values.availability = values.availability ~= "" and values.availability or "Available Now"
      if values.profession == "" or values.itemName == "" then self.formMessage:SetText(values.profession == "" and "Profession is required." or "Item is required."); return false end
      if not self.formEditId then values.expiresAt = (time and time() or 0) + 3600 end
      local row, err = self.formEditId and M:EditListing(self.formEditId, values) or M:CreateListing(values)
      if not row then self.formMessage:SetText(tostring(err)); return false end
      self.formMessage:SetText(self.formEditId and "Listing updated." or "Listing created."); local id = row.id; self:ResetListingForm(); self.formShell:Hide(); self:SetTab("My Listings"); self.mySelectedListingId = id; self:RenderMyListingsDetail(); return true
    end
    function U:CancelListingForm()
      local id = self.formReturnId; self:ResetListingForm(); self.formShell:Hide(); if id then self:SetTab("My Listings"); self.mySelectedListingId=id; return self:RenderMyListingsDetail() end; return self:SetTab("Create Listing")
    end

    function U:RenderFavorites()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "Favorites" then self.favoritesDirty = true; return false end
      local snapshot = self:BuildFavoritesView(); if not snapshot then return false end
      local pages = math.max(1, math.ceil(snapshot.total / BROWSE_PAGE_SIZE)); self.favoritesPage = math.max(1, math.min(tonumber(self.favoritesPage or 1) or 1, pages))
      local first, last = ((self.favoritesPage - 1) * BROWSE_PAGE_SIZE) + 1, math.min(snapshot.total, ((self.favoritesPage - 1) * BROWSE_PAGE_SIZE) + BROWSE_PAGE_SIZE)
      local shown = snapshot.total > 0 and last - first + 1 or 0
      if shown == 0 then self.favoritesEmptyState:Show() else self.favoritesEmptyState:Hide() end
      self.favoritesSummary:SetText(snapshot.total > 0 and ("Showing " .. first .. "-" .. last .. " of " .. snapshot.total) or ""); self.favoritesPageIndicator:SetText("Page " .. self.favoritesPage .. " of " .. pages)
      if pages > 1 then self.favoritesPrevious:Show(); self.favoritesNext:Show(); self.favoritesPageIndicator:Show() else self.favoritesPrevious:Hide(); self.favoritesNext:Hide(); self.favoritesPageIndicator:Hide() end
      for index, control in ipairs(self.favoritesRows) do
        local favorite = snapshot.rows[first + index - 1]
        if favorite then
          local source, status = favorite.row or favorite.summary, favorite.active and "Active" or "Unavailable"
          local item = source.itemName or ""; if favorite.row and favorite.row.recipeName and favorite.row.recipeName ~= "" and favorite.row.recipeName ~= item then item = item .. " / " .. favorite.row.recipeName end
          local values = {source.owner or "", source.listingType or "", source.profession or "", item, status, tostring(favorite.addedAt)}; local signature = table.concat(values, "\31")
          if control.signature ~= signature then for column, value in ipairs(values) do control.labels[column]:SetText(value) end; control.signature = signature end
          control.favoriteId = favorite.id; control:Show()
        else control:Hide(); control.signature, control.favoriteId = nil, nil end
      end
      self.favoritesRowCount, self.favoritesDirty = shown, false; return true
    end

    function U:ShowFavoritesTable()
      self:ClearFavoriteSelection(); self.favoritesDetail:Hide(); self.favoritesTableHeader:Show(); self.favoritesScrollArea:Show(); self.favoritesSummary:Show(); return self:RenderFavorites()
    end
    function U:ChangeFavoritesPage(delta)
      local view = self:BuildFavoritesView(); if not view or self.favoriteSelectedId then return false end
      local pages = math.max(1, math.ceil(view.total / BROWSE_PAGE_SIZE)); self.favoritesPage = math.max(1, math.min((self.favoritesPage or 1) + (delta or 0), pages)); return self:RenderFavorites()
    end
    function U:RenderFavoriteDetail()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "Favorites" then self.favoriteDetailDirty = true; return false end
      local id, runtime = tostring(self.favoriteSelectedId or ""), M.runtime; local summary = runtime and runtime.store.favoritesById[id]
      if type(summary) ~= "table" then return self:ShowFavoritesTable() end
      local row = runtime.byId[id]; if row and tonumber(row.expiresAt or 0) <= (time and time() or 0) then row = nil end
      local values = row and {row.owner,row.listingType,row.profession,row.itemName,row.recipeName ~= "" and row.recipeName or "None",row.materialsPolicy,mktui_price(row),row.location,row.availability,mktui_remaining(row.expiresAt,time()),row.notes ~= "" and row.notes or "No notes.","Active"}
        or {summary.owner,summary.listingType,summary.profession,summary.itemName,"","","","","","","This listing is no longer available.","Unavailable"}
      local signature = table.concat(values, "\31"); if self.favoriteDetailSignature ~= signature then for index, value in ipairs(values) do self.favoriteDetailValues[index]:SetText(value) end; self.favoriteDetailSignature = signature end
      self.favoriteAction.label:SetText(row and "Unfavorite" or "Remove Favorite"); self.favoritesTableHeader:Hide(); self.favoritesScrollArea:Hide(); self.favoritesSummary:Hide(); self.favoritesPrevious:Hide(); self.favoritesNext:Hide(); self.favoritesPageIndicator:Hide(); self.favoritesDetail:Show(); return true
    end
    function U:SelectFavoriteRow(control)
      local id = control and tostring(control.favoriteId or "") or ""; if not self.active or self.selectedTab ~= "Favorites" or id == "" or not M:IsFavorite(id) then return false end
      self:ClearFavoriteSelection(); self.favoriteSelectedId = id; return self:RenderFavoriteDetail()
    end
    function U:RemoveFavorite()
      local id = tostring(self.favoriteSelectedId or ""); if not M:IsFavorite(id) then return self:ShowFavoritesTable() end
      local ok = M:SetFavorite(id, false); self:ClearFavoritesView(); self:ShowFavoritesTable(); return ok == true
    end

    function U:RenderMyListings()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "My Listings" then self.myListingsDirty = true; return false end
      local snapshot = self:BuildMyListingsView()
      if not snapshot then return false end
      local pages = math.max(1, math.ceil(snapshot.total / BROWSE_PAGE_SIZE))
      self.myListingsPage = math.max(1, math.min(tonumber(self.myListingsPage or 1) or 1, pages))
      local first, last = ((self.myListingsPage - 1) * BROWSE_PAGE_SIZE) + 1, math.min(snapshot.total, ((self.myListingsPage - 1) * BROWSE_PAGE_SIZE) + BROWSE_PAGE_SIZE)
      local shown, stamp = snapshot.total > 0 and (last - first + 1) or 0, tonumber(time and time() or 0) or 0
      if shown == 0 then self.myListingsEmptyState:Show() else self.myListingsEmptyState:Hide() end
      self.myListingsSummary:SetText(snapshot.total > 0 and ("Showing " .. tostring(first) .. "-" .. tostring(last) .. " of " .. tostring(snapshot.total)) or "")
      self.myListingsPageIndicator:SetText("Page " .. tostring(self.myListingsPage) .. " of " .. tostring(pages))
      if pages > 1 then
        self.myListingsPrevious:Show(); self.myListingsNext:Show(); self.myListingsPageIndicator:Show()
        self.myListingsPrevious:EnableMouse(self.myListingsPage > 1); self.myListingsNext:EnableMouse(self.myListingsPage < pages)
        self.myListingsPrevious:SetAlpha(self.myListingsPage > 1 and 1 or .45); self.myListingsNext:SetAlpha(self.myListingsPage < pages and 1 or .45)
      else self.myListingsPrevious:Hide(); self.myListingsNext:Hide(); self.myListingsPageIndicator:Hide() end
      for index, control in ipairs(self.myListingsRows) do
        local row = snapshot.rows[first + index - 1]
        if row then
          local item = row.itemName
          if row.recipeName and row.recipeName ~= "" and row.recipeName ~= row.itemName then item = item .. " / " .. row.recipeName end
          local values = {row.listingType, row.profession, item, row.location, row.availability, mktui_price(row), mktui_remaining(row.expiresAt, stamp)}
          local signature = table.concat(values, "\31")
          if control.signature ~= signature then for column, value in ipairs(values) do control.labels[column]:SetText(value) end; control.signature = signature end
          control.listingId = row.id; control:Show()
        else control:Hide(); control.signature, control.listingId = nil, nil end
      end
      self.myListingsRowCount, self.myListingsDirty = shown, false
      return true
    end

    function U:ChangeMyListingsPage(delta)
      if not self.active or self.selectedTab ~= "My Listings" or self.mySelectedListingId then return false end
      local snapshot = self:BuildMyListingsView(); if not snapshot then return false end
      local pages = math.max(1, math.ceil(snapshot.total / BROWSE_PAGE_SIZE))
      local page = math.max(1, math.min((tonumber(self.myListingsPage or 1) or 1) + (tonumber(delta or 0) or 0), pages))
      if page == self.myListingsPage then return false end
      self.myListingsPage = page; return self:RenderMyListings()
    end

    function U:ShowMyListingsTable()
      self:ClearMyListingsSelection(); self.myListingsDetail:Hide(); self.myListingsTableHeader:Show(); self.myListingsScrollArea:Show(); self.myListingsSummary:Show()
      return self:RenderMyListings()
    end

    function U:RenderMyListingsDetail()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "My Listings" then self.myDetailDirty = true; return false end
      local id, stamp = tostring(self.mySelectedListingId or ""), tonumber(time and time() or 0) or 0
      local row, ownerKey = id ~= "" and M:GetListing(id) or nil, self:GetCurrentOwnerKey()
      if not row or row.id ~= id or row.profile ~= self.profile or row.ownerKey ~= ownerKey or tonumber(row.expiresAt or 0) <= stamp then return self:ShowMyListingsTable() end
      local values = {row.owner, row.listingType, row.profession, row.itemName, mktui_text(row.recipeName) ~= "" and row.recipeName or "None", mktui_text(row.materialsPolicy), mktui_price(row), row.location, row.availability, mktui_remaining(row.expiresAt, stamp), mktui_text(row.notes) ~= "" and row.notes or "No notes."}
      local signature = table.concat(values, "\31")
      if self.myDetailSignature ~= signature then for index, value in ipairs(values) do self.myDetailValues[index]:SetText(value) end; self.myDetailSignature = signature end
      self.myListingsTableHeader:Hide(); self.myListingsScrollArea:Hide(); self.myListingsSummary:Hide(); self.myListingsPrevious:Hide(); self.myListingsNext:Hide(); self.myListingsPageIndicator:Hide()
      self.myRemoveButton.label:SetText(self.myRemoveConfirmId == id and "Confirm Remove" or "Remove Listing"); self.myListingsDetail:Show(); self.myDetailDirty = false
      return true
    end

    function U:SelectMyListingsRow(control)
      if not self.active or self.selectedTab ~= "My Listings" or not control or not control:IsShown() then return false end
      local id, row = tostring(control.listingId or ""), M:GetListing(tostring(control.listingId or ""))
      if not row or row.id ~= id or row.ownerKey ~= self:GetCurrentOwnerKey() then return false end
      self:ClearMyListingsSelection(); self.mySelectedListingId = id; return self:RenderMyListingsDetail()
    end

    function U:RemoveMyListing()
      local id, row = tostring(self.mySelectedListingId or ""), M:GetListing(tostring(self.mySelectedListingId or ""))
      if not self.active or self.selectedTab ~= "My Listings" or not row or row.id ~= id or row.ownerKey ~= self:GetCurrentOwnerKey() then self:ShowMyListingsTable(); return false end
      if self.myRemoveConfirmId ~= id then self.myRemoveConfirmId = id; return self:RenderMyListingsDetail() end
      local ok = M:RemoveListing(id)
      self:ClearMyListingsView(); self:ShowMyListingsTable()
      return ok == true
    end
    function U:EditMyListing()
      local id, row = tostring(self.mySelectedListingId or ""), M:GetListing(tostring(self.mySelectedListingId or ""))
      if not row or row.id ~= id or row.ownerKey ~= self:GetCurrentOwnerKey() or row.profile ~= self.profile then return false end
      self.selectedTab="Create Listing"; self:ClearMyListingsSelection(); self.browseShell:Hide(); self.myListingsShell:Hide(); self.favoritesShell:Hide(); self:SetBrowseToolbarVisible(false); return self:ShowListingForm(id)
    end

    function U:ShowBrowseTable()
      self:ClearSelection()
      if self.browseDetail then self.browseDetail:Hide() end
      if self.browseTableHeader then self.browseTableHeader:Show() end
      if self.browseScrollArea then self.browseScrollArea:Show() end
      if self.browseSummary then self.browseSummary:Show() end
      if self.browsePrevious then self.browsePrevious:Show() end
      if self.browseNext then self.browseNext:Show() end
      if self.browsePageIndicator then self.browsePageIndicator:Show() end
      self:SetBrowseToolbarVisible(true)
      return self:RenderBrowse()
    end

    function U:RenderDetail()
      if not self.active or self:GetPanelState() ~= "visible" or self.selectedTab ~= "Browse" then self.detailDirty = true; return false end
      local id, stamp = tostring(self.selectedListingId or ""), tonumber(time and time() or 0) or 0
      local row = id ~= "" and M:GetListing(id) or nil
      if not row or row.id ~= id or row.profile ~= self.profile or tonumber(row.expiresAt or 0) <= stamp then return self:ShowBrowseTable() end
      local values = {row.owner, row.listingType, row.profession, row.itemName,
        mktui_text(row.recipeName) ~= "" and row.recipeName or "None", mktui_text(row.materialsPolicy), mktui_price(row),
        row.location, row.availability, mktui_remaining(row.expiresAt, stamp), mktui_text(row.notes) ~= "" and row.notes or "No notes."}
      local signature = table.concat(values, "\31")
      if self.detailSignature ~= signature then
        for index, value in ipairs(values) do self.detailValues[index]:SetText(value) end
        self.detailSignature = signature
      end
      self.browseTableHeader:Hide(); self.browseScrollArea:Hide(); self.browseSummary:Hide()
      self.browsePrevious:Hide(); self.browseNext:Hide(); self.browsePageIndicator:Hide()
      self:SetBrowseToolbarVisible(false); self.browseDetail:Show()
      self.detailDirty = false
      return true
    end

    function U:SelectBrowseRow(rowControl)
      if not self.active or self.selectedTab ~= "Browse" or not rowControl or not rowControl:IsShown() then return false end
      local id = tostring(rowControl.listingId or "")
      local row = id ~= "" and M:GetListing(id) or nil
      if not row or row.id ~= id then return false end
      self:CloseBrowseSelectors()
      self.selectedListingId, self.detailSignature = id, nil
      return self:RenderDetail()
    end

    local function mktui_row_click(rowControl) if U.active then U:SelectBrowseRow(rowControl) end end
    local function mktui_my_row_click(rowControl) if U.active then U:SelectMyListingsRow(rowControl) end end
    local function mktui_back_click() if U.active then U:ShowBrowseTable() end end
    local function mktui_my_back_click() if U.active then U:ShowMyListingsTable() end end
    local function mktui_my_remove_click() if U.active then U:RemoveMyListing() end end
    local function mktui_my_edit_click() if U.active then U:EditMyListing() end end
    local function mktui_favorite_row_click(row) if U.active then U:SelectFavoriteRow(row) end end
    local function mktui_favorite_back_click() if U.active then U:ShowFavoritesTable() end end
    local function mktui_favorite_action_click() if U.active then U:RemoveFavorite() end end
    local function mktui_form_submit() if U.active then U:SubmitListingForm() end end
    local function mktui_form_cancel() if U.active then U:CancelListingForm() end end
    local function mktui_previous_click() if U.active then U:ChangeBrowsePage(-1) end end
    local function mktui_next_click() if U.active then U:ChangeBrowsePage(1) end end
    local function mktui_my_previous_click() if U.active then U:ChangeMyListingsPage(-1) end end
    local function mktui_my_next_click() if U.active then U:ChangeMyListingsPage(1) end end
    local function mktui_favorite_previous_click() if U.active then U:ChangeFavoritesPage(-1) end end
    local function mktui_favorite_next_click() if U.active then U:ChangeFavoritesPage(1) end end
    local function mktui_search_click() if U.active then U:ApplyBrowseSearch() end end
    local function mktui_clear_click() if U.active then U:ClearBrowseSearch() end end
    local function mktui_search_enter(box) if U.active then U:ApplyBrowseSearch() else box:ClearFocus() end end
    local function mktui_search_escape(box) box:ClearFocus() end
    local function mktui_type_click() if U.active then U:OpenBrowseSelector("type") end end
    local function mktui_profession_click() if U.active then U:OpenBrowseSelector("profession") end end
    local function mktui_location_click() if U.active then U:OpenBrowseSelector("location") end end
    local function mktui_availability_click() if U.active then U:OpenBrowseSelector("availability") end end
    local function mktui_favorites_click() if U.active then U:ToggleBrowseFavorites() end end
    local function mktui_clear_filters_click() if U.active then U:ClearBrowseFilters() end end

    function U:CloseBrowseSelectors()
      if CloseDropDownMenus then CloseDropDownMenus() end
    end

    function U:OpenBrowseSelector(kind)
      local selector = kind == "type" and self.browseTypeSelector or kind == "profession" and self.browseProfessionSelector
        or kind == "location" and self.browseLocationSelector or self.browseAvailabilitySelector
      if not selector or not selector.menu then return false end
      if kind == "profession" then selector.options = self:GetBrowseProfessionOptions() end
      if kind == "location" then selector.options = self:GetBrowseLocationOptions() end
      selector.menu.ownerSelector = selector
      UIDropDownMenu_Initialize(selector.menu, selector.menuInitializer, "MENU")
      if ToggleDropDownMenu then ToggleDropDownMenu(1, nil, selector.menu, selector, 0, 0) end
      return true
    end

    function U:GetPanelState()
      local panel = B.marketplacePanel or self.panel
      if not panel then return "unbuilt" end
      if panel.IsVisible then return panel:IsVisible() and "visible" or "hidden" end
      return panel.IsShown and panel:IsShown() and "visible" or "hidden"
    end

    function U:ActiveScriptCount()
      local count = 0
      for _, button in ipairs(self.navButtons or {}) do
        if button:GetScript("OnClick") then count = count + 1 end
      end
      for _, row in ipairs(self.browseRows or {}) do if row:GetScript("OnMouseUp") then count = count + 1 end end
      for _, row in ipairs(self.myListingsRows or {}) do if row:GetScript("OnMouseUp") then count = count + 1 end end
      for _, row in ipairs(self.favoritesRows or {}) do if row:GetScript("OnMouseUp") then count = count + 1 end end
      if self.detailBack and self.detailBack:GetScript("OnClick") then count = count + 1 end
      if self.myDetailBack and self.myDetailBack:GetScript("OnClick") then count = count + 1 end
      if self.myRemoveButton and self.myRemoveButton:GetScript("OnClick") then count = count + 1 end
      if self.myEditButton and self.myEditButton:GetScript("OnClick") then count = count + 1 end
      if self.favoriteBack and self.favoriteBack:GetScript("OnClick") then count = count + 1 end
      if self.favoriteAction and self.favoriteAction:GetScript("OnClick") then count = count + 1 end
      if self.formPrimary and self.formPrimary:GetScript("OnClick") then count = count + 1 end
      if self.formCancel and self.formCancel:GetScript("OnClick") then count = count + 1 end
      if self.browsePrevious and self.browsePrevious:GetScript("OnClick") then count = count + 1 end
      if self.browseNext and self.browseNext:GetScript("OnClick") then count = count + 1 end
      if self.myListingsPrevious and self.myListingsPrevious:GetScript("OnClick") then count = count + 1 end
      if self.myListingsNext and self.myListingsNext:GetScript("OnClick") then count = count + 1 end
      if self.favoritesPrevious and self.favoritesPrevious:GetScript("OnClick") then count = count + 1 end
      if self.favoritesNext and self.favoritesNext:GetScript("OnClick") then count = count + 1 end
      if self.browseSearchButton and self.browseSearchButton:GetScript("OnClick") then count = count + 1 end
      if self.browseClear and self.browseClear:GetScript("OnClick") then count = count + 1 end
      if self.browseTypeSelector and self.browseTypeSelector:GetScript("OnClick") then count = count + 1 end
      if self.browseProfessionSelector and self.browseProfessionSelector:GetScript("OnClick") then count = count + 1 end
      if self.browseLocationSelector and self.browseLocationSelector:GetScript("OnClick") then count = count + 1 end
      if self.browseAvailabilitySelector and self.browseAvailabilitySelector:GetScript("OnClick") then count = count + 1 end
      if self.browseFavoritesButton and self.browseFavoritesButton:GetScript("OnClick") then count = count + 1 end
      if self.browseClearFilters and self.browseClearFilters:GetScript("OnClick") then count = count + 1 end
      if self.browseSearchBox and self.browseSearchBox:GetScript("OnEnterPressed") then count = count + 1 end
      if self.browseSearchBox and self.browseSearchBox:GetScript("OnEscapePressed") then count = count + 1 end
      return count
    end

    function U:ActivateScripts()
      if not self.panel then return false end
      self.panel:EnableMouse(true)
      for _, button in ipairs(self.navButtons or {}) do
        button:EnableMouse(true)
        button:SetScript("OnClick", mktui_nav_click)
      end
      for _, row in ipairs(self.browseRows or {}) do row:EnableMouse(true); row:SetScript("OnMouseUp", mktui_row_click) end
      for _, row in ipairs(self.myListingsRows or {}) do row:EnableMouse(true); row:SetScript("OnMouseUp", mktui_my_row_click) end
      for _, row in ipairs(self.favoritesRows or {}) do row:EnableMouse(true); row:SetScript("OnMouseUp", mktui_favorite_row_click) end
      if self.detailBack then self.detailBack:EnableMouse(true); self.detailBack:SetScript("OnClick", mktui_back_click) end
      if self.myDetailBack then self.myDetailBack:EnableMouse(true); self.myDetailBack:SetScript("OnClick", mktui_my_back_click) end
      if self.myRemoveButton then self.myRemoveButton:EnableMouse(true); self.myRemoveButton:SetScript("OnClick", mktui_my_remove_click) end
      if self.myEditButton then self.myEditButton:EnableMouse(true); self.myEditButton:SetScript("OnClick", mktui_my_edit_click) end
      if self.favoriteBack then self.favoriteBack:EnableMouse(true); self.favoriteBack:SetScript("OnClick", mktui_favorite_back_click) end
      if self.favoriteAction then self.favoriteAction:EnableMouse(true); self.favoriteAction:SetScript("OnClick", mktui_favorite_action_click) end
      if self.formPrimary then self.formPrimary:EnableMouse(true); self.formPrimary:SetScript("OnClick", mktui_form_submit) end
      if self.formCancel then self.formCancel:EnableMouse(true); self.formCancel:SetScript("OnClick", mktui_form_cancel) end
      if self.browsePrevious then self.browsePrevious:SetScript("OnClick", mktui_previous_click) end
      if self.browseNext then self.browseNext:SetScript("OnClick", mktui_next_click) end
      if self.myListingsPrevious then self.myListingsPrevious:EnableMouse(true); self.myListingsPrevious:SetScript("OnClick", mktui_my_previous_click) end
      if self.myListingsNext then self.myListingsNext:EnableMouse(true); self.myListingsNext:SetScript("OnClick", mktui_my_next_click) end
      if self.favoritesPrevious then self.favoritesPrevious:EnableMouse(true); self.favoritesPrevious:SetScript("OnClick", mktui_favorite_previous_click) end
      if self.favoritesNext then self.favoritesNext:EnableMouse(true); self.favoritesNext:SetScript("OnClick", mktui_favorite_next_click) end
      if self.browseSearchButton then self.browseSearchButton:EnableMouse(true); self.browseSearchButton:SetScript("OnClick", mktui_search_click) end
      if self.browseClear then self.browseClear:SetScript("OnClick", mktui_clear_click) end
      if self.browseTypeSelector then self.browseTypeSelector:EnableMouse(true); self.browseTypeSelector:SetScript("OnClick", mktui_type_click) end
      if self.browseProfessionSelector then self.browseProfessionSelector:EnableMouse(true); self.browseProfessionSelector:SetScript("OnClick", mktui_profession_click) end
      if self.browseLocationSelector then self.browseLocationSelector:EnableMouse(true); self.browseLocationSelector:SetScript("OnClick", mktui_location_click) end
      if self.browseAvailabilitySelector then self.browseAvailabilitySelector:EnableMouse(true); self.browseAvailabilitySelector:SetScript("OnClick", mktui_availability_click) end
      if self.browseFavoritesButton then self.browseFavoritesButton:EnableMouse(true); self.browseFavoritesButton:SetScript("OnClick", mktui_favorites_click) end
      if self.browseClearFilters then self.browseClearFilters:SetScript("OnClick", mktui_clear_filters_click) end
      if self.browseSearchBox then self.browseSearchBox:EnableMouse(true); self.browseSearchBox:SetScript("OnEnterPressed", mktui_search_enter); self.browseSearchBox:SetScript("OnEscapePressed", mktui_search_escape) end
      return true
    end

    function U:DeactivateScripts()
      if self.panel then self.panel:EnableMouse(false) end
      for _, button in ipairs(self.navButtons or {}) do
        button:SetScript("OnClick", nil)
        button:EnableMouse(false)
      end
      for _, row in ipairs(self.browseRows or {}) do row:SetScript("OnMouseUp", nil); row:EnableMouse(false) end
      for _, row in ipairs(self.myListingsRows or {}) do row:SetScript("OnMouseUp", nil); row:EnableMouse(false) end
      for _, row in ipairs(self.favoritesRows or {}) do row:SetScript("OnMouseUp", nil); row:EnableMouse(false) end
      if self.detailBack then self.detailBack:SetScript("OnClick", nil); self.detailBack:EnableMouse(false) end
      if self.myDetailBack then self.myDetailBack:SetScript("OnClick", nil); self.myDetailBack:EnableMouse(false) end
      if self.myRemoveButton then self.myRemoveButton:SetScript("OnClick", nil); self.myRemoveButton:EnableMouse(false) end
      if self.myEditButton then self.myEditButton:SetScript("OnClick", nil); self.myEditButton:EnableMouse(false) end
      if self.favoriteBack then self.favoriteBack:SetScript("OnClick", nil); self.favoriteBack:EnableMouse(false) end
      if self.favoriteAction then self.favoriteAction:SetScript("OnClick", nil); self.favoriteAction:EnableMouse(false) end
      if self.formPrimary then self.formPrimary:SetScript("OnClick", nil); self.formPrimary:EnableMouse(false) end
      if self.formCancel then self.formCancel:SetScript("OnClick", nil); self.formCancel:EnableMouse(false) end
      if self.browsePrevious then self.browsePrevious:SetScript("OnClick", nil); self.browsePrevious:EnableMouse(false) end
      if self.browseNext then self.browseNext:SetScript("OnClick", nil); self.browseNext:EnableMouse(false) end
      if self.myListingsPrevious then self.myListingsPrevious:SetScript("OnClick", nil); self.myListingsPrevious:EnableMouse(false) end
      if self.myListingsNext then self.myListingsNext:SetScript("OnClick", nil); self.myListingsNext:EnableMouse(false) end
      if self.favoritesPrevious then self.favoritesPrevious:SetScript("OnClick", nil); self.favoritesPrevious:EnableMouse(false) end
      if self.favoritesNext then self.favoritesNext:SetScript("OnClick", nil); self.favoritesNext:EnableMouse(false) end
      if self.browseSearchButton then self.browseSearchButton:SetScript("OnClick", nil); self.browseSearchButton:EnableMouse(false) end
      if self.browseClear then self.browseClear:SetScript("OnClick", nil); self.browseClear:EnableMouse(false) end
      if self.browseTypeSelector then self.browseTypeSelector:SetScript("OnClick", nil); self.browseTypeSelector:EnableMouse(false) end
      if self.browseProfessionSelector then self.browseProfessionSelector:SetScript("OnClick", nil); self.browseProfessionSelector:EnableMouse(false) end
      if self.browseLocationSelector then self.browseLocationSelector:SetScript("OnClick", nil); self.browseLocationSelector:EnableMouse(false) end
      if self.browseAvailabilitySelector then self.browseAvailabilitySelector:SetScript("OnClick", nil); self.browseAvailabilitySelector:EnableMouse(false) end
      if self.browseFavoritesButton then self.browseFavoritesButton:SetScript("OnClick", nil); self.browseFavoritesButton:EnableMouse(false) end
      if self.browseClearFilters then self.browseClearFilters:SetScript("OnClick", nil); self.browseClearFilters:EnableMouse(false) end
      self:CloseBrowseSelectors()
      if self.browseSearchBox then self.browseSearchBox:SetScript("OnEnterPressed", nil); self.browseSearchBox:SetScript("OnEscapePressed", nil); self.browseSearchBox:EnableMouse(false); self.browseSearchBox:ClearFocus() end
      return true
    end

    function U:SetTab(tab)
      if not self.active or not self.panel or not self.panel:IsShown() then return false end
      if not PLACEHOLDERS[tab] then tab = "Browse" end
      if self.browseSearchBox then self.browseSearchBox:ClearFocus() end
      self:CloseBrowseSelectors()
      if tab ~= "Browse" or self.selectedListingId then self:ClearSelection() end
      if tab ~= "My Listings" or self.mySelectedListingId then self:ClearMyListingsSelection() end
      if tab ~= "Favorites" or self.favoriteSelectedId then self:ClearFavoriteSelection() end
      self.selectedTab = tab
      self.sectionTitle:SetText(tab)
      local browse = tab == "Browse"
      if self.browseShell then
        if browse then self.browseShell:Show() else self.browseShell:Hide() end
      end
      local mine = tab == "My Listings"
      if self.myListingsShell then if mine then self.myListingsShell:Show() else self.myListingsShell:Hide() end end
      local favorites = tab == "Favorites"; if self.favoritesShell then if favorites then self.favoritesShell:Show() else self.favoritesShell:Hide() end end
      local create = tab == "Create Listing"; if self.formShell and not create then self.formShell:Hide() end
      if browse then
        self.placeholder:Hide()
      elseif mine then
        self.placeholder:Hide()
      elseif favorites then
        self.placeholder:Hide()
      elseif create then
        self.placeholder:Hide(); self:ShowListingForm()
      else
        self.placeholder:SetText(PLACEHOLDERS[tab])
        self.placeholder:Show()
        self:SetBrowseToolbarVisible(false)
      end
      for _, button in ipairs(self.navButtons) do
        local selected = button.marketplaceTab == tab
        button:SetBackdropColor(selected and .24 or .04, selected and .16 or .04,
          selected and .03 or .04, selected and 1 or .92)
        button:SetBackdropBorderColor(selected and 1 or .52, selected and .72 or .4,
          selected and .18 or .12, 1)
        button.label:SetTextColor(selected and 1 or .82, selected and .9 or .78,
          selected and .48 or .62)
      end
      self.refreshCount = self.refreshCount + 1
      if browse then self:ShowBrowseTable() elseif mine then self:ShowMyListingsTable() elseif favorites then self:ShowFavoritesTable() end
      return true
    end

    function U:Build()
      if self.panel then return true end
      if not self.active then return false, "Marketplace module is disabled" end
      if not B.content then return false, "SignalFire content shell is unavailable" end

      local panel = CreateFrame("Frame", nil, B.content)
      panel:SetWidth(820); panel:SetHeight(520)
      panel:SetPoint("TOPLEFT", B.content, "TOPLEFT", 0, 0)
      mktui_backdrop(panel, .97)
      panel:Hide()

      local title = mktui_font(panel, "Tradeskill Marketplace", 18, 1, .78, .18)
      title:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -18)

      self.navButtons = {}
      for index, tab in ipairs(TABS) do
        local button = CreateFrame("Button", nil, panel)
        button:SetWidth(150); button:SetHeight(30)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 20 + ((index - 1) * 158), -52)
        mktui_backdrop(button, .92)
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        button.marketplaceTab = tab
        button.label = mktui_font(button, tab, 12, .82, .78, .62)
        button.label:SetPoint("CENTER")
        table.insert(self.navButtons, button)
      end

      self.sectionTitle = mktui_font(panel, "Browse", 15, 1, .82, .22)
      self.sectionTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -112)
      self.placeholder = mktui_font(panel, "", 12, .72, .72, .72)
      self.placeholder:SetPoint("TOPLEFT", self.sectionTitle, "BOTTOMLEFT", 0, -18)

      local browseShell = CreateFrame("Frame", nil, panel)
      browseShell:SetWidth(780); browseShell:SetHeight(352)
      browseShell:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -140)
      local function selector(width, menuName, options, onSelect)
        local button = CreateFrame("Button", nil, panel)
        button:SetWidth(width); button:SetHeight(22)
        mktui_backdrop(button, .88)
        button.options = options
        button.label = mktui_font(button, "", 9, .9, .76, .32)
        button.label:SetPoint("LEFT", button, "LEFT", 6, 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -18, 0)
        button.label:SetJustifyH("LEFT")
        button.arrow = button:CreateTexture(nil, "OVERLAY")
        button.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        button.arrow:SetWidth(12); button.arrow:SetHeight(12); button.arrow:SetPoint("RIGHT", button, "RIGHT", -3, 0)
        local menu = _G[menuName]
        if not menu then menu = CreateFrame("Frame", menuName, UIParent, "UIDropDownMenuTemplate") end
        button.menu, menu.ownerSelector = menu, button
        button.menuInitializer = function(self, level)
          if (level or 1) ~= 1 then return end
          local owner = self.ownerSelector
          for _, option in ipairs(owner.options or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value, info.notCheckable = option.text, option.key, true
            info.func = function()
              onSelect(option)
              if CloseDropDownMenus then CloseDropDownMenus() end
            end
            UIDropDownMenu_AddButton(info, level)
          end
        end
        UIDropDownMenu_Initialize(menu, button.menuInitializer, "MENU")
        return button
      end
      local typeSelector = selector(85, "SignalFireMarketplaceTypeDropdown151", {{key="", text="All Types"}, {key="Crafting Offer", text="Crafting Offer"},
        {key="Crafting Request", text="Crafting Request"}}, function(option) U:ApplyBrowseFilter(option.key, U:GetBrowseProfessionKey(), U.browseProfessionLabel) end)
      typeSelector:SetPoint("TOPLEFT", self.sectionTitle, "BOTTOMLEFT", 0, -8)
      local professionSelector = selector(96, "SignalFireMarketplaceProfessionDropdown151", {{key="", text="All Professions"}}, function(option)
        U:ApplyBrowseFilter(U:GetBrowseListingType(), option.key, option.text)
      end)
      professionSelector:SetPoint("LEFT", typeSelector, "RIGHT", 3, 0)
      local locationSelector = selector(85, "SignalFireMarketplaceLocationDropdown151", {{key="", text="All Locations"}}, function(option)
        U:ApplyBrowseLocation(option.key, option.text)
      end)
      locationSelector:SetPoint("LEFT", professionSelector, "RIGHT", 3, 0)
      local availabilitySelector = selector(92, "SignalFireMarketplaceAvailabilityDropdown151", {{key="", text="All Availability"},
        {key="Available Now", text="Available Now"}, {key="Today", text="Today"}, {key="This Session", text="This Session"}, {key="Scheduled", text="Scheduled"}}, function(option)
        U:ApplyBrowseAvailability(option.key)
      end)
      availabilitySelector:SetPoint("LEFT", locationSelector, "RIGHT", 3, 0)
      self.browseTypeSelector, self.browseProfessionSelector = typeSelector, professionSelector
      self.browseLocationSelector, self.browseAvailabilitySelector = locationSelector, availabilitySelector
      local favoritesButton = CreateFrame("Button", nil, panel)
      favoritesButton:SetWidth(54); favoritesButton:SetHeight(22); favoritesButton:SetPoint("LEFT", availabilitySelector, "RIGHT", 3, 0)
      mktui_backdrop(favoritesButton, .88); favoritesButton.label = mktui_font(favoritesButton, "Favorites", 8, .82, .78, .62); favoritesButton.label:SetPoint("CENTER")
      self.browseFavoritesButton = favoritesButton
      self.browseSearchLabel = mktui_font(panel, "Find", 9, .9, .76, .32)
      self.browseSearchLabel:SetPoint("LEFT", favoritesButton, "RIGHT", 5, 0)
      local searchBox = CreateFrame("EditBox", nil, panel)
      searchBox:SetWidth(90); searchBox:SetHeight(22); searchBox:SetPoint("LEFT", self.browseSearchLabel, "RIGHT", 3, 0)
      searchBox:SetAutoFocus(false); searchBox:SetFontObject(ChatFontNormal); searchBox:SetTextInsets(5, 5, 2, 2)
      if searchBox.SetMaxLetters then searchBox:SetMaxLetters(100) end
      mktui_backdrop(searchBox, .92)
      local searchButton = CreateFrame("Button", nil, panel)
      searchButton:SetWidth(40); searchButton:SetHeight(22); searchButton:SetPoint("LEFT", searchBox, "RIGHT", 3, 0)
      mktui_backdrop(searchButton, .88); searchButton.label = mktui_font(searchButton, "Search", 9, .9, .76, .32); searchButton.label:SetPoint("CENTER")
      local clearButton = CreateFrame("Button", nil, panel)
      clearButton:SetWidth(34); clearButton:SetHeight(22); clearButton:SetPoint("LEFT", searchButton, "RIGHT", 3, 0)
      mktui_backdrop(clearButton, .88); clearButton.label = mktui_font(clearButton, "Clear", 9, .9, .76, .32); clearButton.label:SetPoint("CENTER")
      local clearFilters = CreateFrame("Button", nil, panel)
      clearFilters:SetWidth(64); clearFilters:SetHeight(22); clearFilters:SetPoint("LEFT", clearButton, "RIGHT", 3, 0)
      mktui_backdrop(clearFilters, .88); clearFilters.label = mktui_font(clearFilters, "Clear Filters", 8, .9, .76, .32); clearFilters.label:SetPoint("CENTER")
      self.browseSearchBox, self.browseSearchButton, self.browseClear, self.browseClearFilters = searchBox, searchButton, clearButton, clearFilters
      self:SyncBrowseFilterLabels()
      local header = CreateFrame("Frame", nil, browseShell)
      header:SetWidth(780); header:SetHeight(24)
      header:SetPoint("TOPLEFT", browseShell, "TOPLEFT", 0, 0)
      mktui_backdrop(header, .90)
      self.browseTableHeader = header
      self.browseTableHeaders = {}
      local x = 8
      for _, column in ipairs(BROWSE_COLUMNS) do
        local label = mktui_font(header, column[1], 10, .9, .76, .32)
        label:SetWidth(column[2]); label:SetJustifyH("LEFT")
        label:SetPoint("LEFT", header, "LEFT", x, 0)
        table.insert(self.browseTableHeaders, label)
        x = x + column[2]
      end

      local scroll = CreateFrame("ScrollFrame", nil, browseShell)
      scroll:SetWidth(780); scroll:SetHeight(320)
      scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
      mktui_backdrop(scroll, .72)
      local rows = CreateFrame("Frame", nil, scroll)
      rows:SetWidth(760); rows:SetHeight(320)
      rows:SetPoint("TOPLEFT", scroll, "TOPLEFT", 8, -8)
      scroll:SetScrollChild(rows)
      self.browseScrollArea = scroll
      self.browseRowsArea = rows
      self.browseRows = {}
      local rowY = -4
      for index = 1, 8 do
        local row = CreateFrame("Button", nil, rows)
        row:SetWidth(744); row:SetHeight(32)
        row:SetPoint("TOPLEFT", rows, "TOPLEFT", 0, rowY)
        mktui_backdrop(row, .55)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.labels, row.signature = {}, nil
        local columnX = 8
        for _, column in ipairs(BROWSE_COLUMNS) do
          local label = mktui_font(row, "", 10, .86, .82, .68)
          label:SetWidth(column[2]); label:SetJustifyH("LEFT")
          label:SetPoint("LEFT", row, "LEFT", columnX, 0)
          table.insert(row.labels, label)
          columnX = columnX + column[2]
        end
        row:Hide(); table.insert(self.browseRows, row); rowY = rowY - 36
      end
      self.browseRowCount = 0
      self.browseEmptyState = mktui_font(rows, "No marketplace listings available.", 12, .72, .72, .72)
      self.browseEmptyState:SetPoint("CENTER", rows, "CENTER", 0, 0)
      self.browseSummary = mktui_font(browseShell, "", 10, .72, .72, .72)
      self.browseSummary:SetPoint("TOPRIGHT", browseShell, "TOPRIGHT", -4, 10)
      local previous = CreateFrame("Button", nil, browseShell)
      previous:SetWidth(54); previous:SetHeight(20); previous:SetPoint("TOPLEFT", browseShell, "BOTTOMLEFT", 0, -4)
      mktui_backdrop(previous, .88)
      previous.label = mktui_font(previous, "Previous", 9, .9, .76, .32); previous.label:SetPoint("CENTER")
      local page = mktui_font(browseShell, "", 10, .72, .72, .72)
      page:SetPoint("LEFT", previous, "RIGHT", 10, 0)
      local nextButton = CreateFrame("Button", nil, browseShell)
      nextButton:SetWidth(38); nextButton:SetHeight(20); nextButton:SetPoint("LEFT", page, "RIGHT", 10, 0)
      mktui_backdrop(nextButton, .88)
      nextButton.label = mktui_font(nextButton, "Next", 9, .9, .76, .32); nextButton.label:SetPoint("CENTER")
      self.browsePrevious, self.browseNext, self.browsePageIndicator = previous, nextButton, page
      local detail = CreateFrame("Frame", nil, browseShell)
      detail:SetWidth(780); detail:SetHeight(352)
      detail:SetPoint("TOPLEFT", browseShell, "TOPLEFT", 0, 0)
      mktui_backdrop(detail, .72)
      local back = CreateFrame("Button", nil, detail)
      back:SetWidth(116); back:SetHeight(24); back:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -10)
      mktui_backdrop(back, .88)
      back.label = mktui_font(back, "Back to Listings", 10, .9, .76, .32); back.label:SetPoint("CENTER")
      self.detailBack, self.detailValues = back, {}
      local fields = {"Player", "Listing Type", "Profession", "Item", "Recipe", "Materials Policy", "Price / Tip", "Location", "Availability", "Expires", "Notes"}
      for index, field in ipairs(fields) do
        local column, y = index <= 6 and 0 or 380, -48 - (((index - 1) % 6) * 43)
        local name = mktui_font(detail, field, 10, .9, .76, .32)
        name:SetWidth(105); name:SetJustifyH("LEFT"); name:SetPoint("TOPLEFT", detail, "TOPLEFT", 12 + column, y)
        local value = mktui_font(detail, "", 11, .86, .82, .68)
        value:SetWidth(250); value:SetHeight(38); value:SetJustifyH("LEFT"); value:SetJustifyV("TOP")
        value:SetPoint("TOPLEFT", detail, "TOPLEFT", 120 + column, y)
        if value.SetNonSpaceWrap then value:SetNonSpaceWrap(false) end
        self.detailValues[index] = value
      end
      detail:Hide(); self.browseDetail = detail
      self.browseShell = browseShell

      local myShell = CreateFrame("Frame", nil, panel)
      myShell:SetWidth(780); myShell:SetHeight(352); myShell:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -140)
      local myHeader = CreateFrame("Frame", nil, myShell)
      myHeader:SetWidth(780); myHeader:SetHeight(24); myHeader:SetPoint("TOPLEFT", myShell, "TOPLEFT", 0, 0); mktui_backdrop(myHeader, .90)
      self.myListingsTableHeader, self.myListingsTableHeaders = myHeader, {}
      local myX = 8
      for _, column in ipairs(MY_LISTINGS_COLUMNS) do
        local label = mktui_font(myHeader, column[1], 10, .9, .76, .32); label:SetWidth(column[2]); label:SetJustifyH("LEFT"); label:SetPoint("LEFT", myHeader, "LEFT", myX, 0)
        table.insert(self.myListingsTableHeaders, label); myX = myX + column[2]
      end
      local myScroll = CreateFrame("ScrollFrame", nil, myShell)
      myScroll:SetWidth(780); myScroll:SetHeight(320); myScroll:SetPoint("TOPLEFT", myHeader, "BOTTOMLEFT", 0, -4); mktui_backdrop(myScroll, .72)
      local myRowsArea = CreateFrame("Frame", nil, myScroll)
      myRowsArea:SetWidth(760); myRowsArea:SetHeight(320); myRowsArea:SetPoint("TOPLEFT", myScroll, "TOPLEFT", 8, -8); myScroll:SetScrollChild(myRowsArea)
      self.myListingsScrollArea, self.myListingsRowsArea, self.myListingsRows = myScroll, myRowsArea, {}
      local myY = -4
      for index = 1, 8 do
        local row = CreateFrame("Button", nil, myRowsArea)
        row:SetWidth(744); row:SetHeight(32); row:SetPoint("TOPLEFT", myRowsArea, "TOPLEFT", 0, myY); mktui_backdrop(row, .55); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.labels, row.signature = {}, nil
        local columnX = 8
        for _, column in ipairs(MY_LISTINGS_COLUMNS) do
          local label = mktui_font(row, "", 10, .86, .82, .68); label:SetWidth(column[2]); label:SetJustifyH("LEFT"); label:SetPoint("LEFT", row, "LEFT", columnX, 0)
          table.insert(row.labels, label); columnX = columnX + column[2]
        end
        row:Hide(); table.insert(self.myListingsRows, row); myY = myY - 36
      end
      self.myListingsEmptyState = mktui_font(myRowsArea, "No active listings for this character.", 12, .72, .72, .72)
      self.myListingsEmptyState:SetPoint("CENTER", myRowsArea, "CENTER", 0, 0)
      self.myListingsSummary = mktui_font(myShell, "", 10, .72, .72, .72); self.myListingsSummary:SetPoint("TOPRIGHT", myShell, "TOPRIGHT", -4, 10)
      local myPrevious = CreateFrame("Button", nil, myShell)
      myPrevious:SetWidth(54); myPrevious:SetHeight(20); myPrevious:SetPoint("TOPLEFT", myShell, "BOTTOMLEFT", 0, -4); mktui_backdrop(myPrevious, .88); myPrevious.label = mktui_font(myPrevious, "Previous", 9, .9, .76, .32); myPrevious.label:SetPoint("CENTER")
      local myPage = mktui_font(myShell, "", 10, .72, .72, .72); myPage:SetPoint("LEFT", myPrevious, "RIGHT", 10, 0)
      local myNext = CreateFrame("Button", nil, myShell)
      myNext:SetWidth(38); myNext:SetHeight(20); myNext:SetPoint("LEFT", myPage, "RIGHT", 10, 0); mktui_backdrop(myNext, .88); myNext.label = mktui_font(myNext, "Next", 9, .9, .76, .32); myNext.label:SetPoint("CENTER")
      self.myListingsPrevious, self.myListingsNext, self.myListingsPageIndicator = myPrevious, myNext, myPage
      local myDetail = CreateFrame("Frame", nil, myShell)
      myDetail:SetWidth(780); myDetail:SetHeight(352); myDetail:SetPoint("TOPLEFT", myShell, "TOPLEFT", 0, 0); mktui_backdrop(myDetail, .72)
      local myBack = CreateFrame("Button", nil, myDetail)
      myBack:SetWidth(116); myBack:SetHeight(24); myBack:SetPoint("TOPLEFT", myDetail, "TOPLEFT", 10, -10); mktui_backdrop(myBack, .88); myBack.label = mktui_font(myBack, "Back to Listings", 10, .9, .76, .32); myBack.label:SetPoint("CENTER")
      local remove = CreateFrame("Button", nil, myDetail)
      remove:SetWidth(116); remove:SetHeight(24); remove:SetPoint("LEFT", myBack, "RIGHT", 8, 0); mktui_backdrop(remove, .88); remove.label = mktui_font(remove, "Remove Listing", 10, .9, .76, .32); remove.label:SetPoint("CENTER")
      local edit = CreateFrame("Button", nil, myDetail); edit:SetWidth(88); edit:SetHeight(24); edit:SetPoint("LEFT", remove, "RIGHT", 8, 0); mktui_backdrop(edit, .88); edit.label=mktui_font(edit,"Edit Listing",10,.9,.76,.32); edit.label:SetPoint("CENTER")
      self.myDetailBack, self.myRemoveButton, self.myEditButton, self.myDetailValues = myBack, remove, edit, {}
      for index, field in ipairs(fields) do
        local column, y = index <= 6 and 0 or 380, -48 - (((index - 1) % 6) * 43)
        local name = mktui_font(myDetail, field, 10, .9, .76, .32); name:SetWidth(105); name:SetJustifyH("LEFT"); name:SetPoint("TOPLEFT", myDetail, "TOPLEFT", 12 + column, y)
        local value = mktui_font(myDetail, "", 11, .86, .82, .68); value:SetWidth(250); value:SetHeight(38); value:SetJustifyH("LEFT"); value:SetJustifyV("TOP"); value:SetPoint("TOPLEFT", myDetail, "TOPLEFT", 120 + column, y)
        if value.SetNonSpaceWrap then value:SetNonSpaceWrap(false) end
        self.myDetailValues[index] = value
      end
      myDetail:Hide(); myShell:Hide(); self.myListingsDetail, self.myListingsShell, self.myListingsPage = myDetail, myShell, 1

      local favoritesShell = CreateFrame("Frame", nil, panel)
      favoritesShell:SetWidth(780); favoritesShell:SetHeight(352); favoritesShell:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -140)
      local favoritesHeader = CreateFrame("Frame", nil, favoritesShell); favoritesHeader:SetWidth(780); favoritesHeader:SetHeight(24); favoritesHeader:SetPoint("TOPLEFT", favoritesShell, "TOPLEFT", 0, 0); mktui_backdrop(favoritesHeader, .90)
      local x = 8
      for _, column in ipairs(FAVORITES_COLUMNS) do local label = mktui_font(favoritesHeader, column[1], 10, .9, .76, .32); label:SetWidth(column[2]); label:SetJustifyH("LEFT"); label:SetPoint("LEFT", favoritesHeader, "LEFT", x, 0); x = x + column[2] end
      local favoritesScroll = CreateFrame("ScrollFrame", nil, favoritesShell); favoritesScroll:SetWidth(780); favoritesScroll:SetHeight(320); favoritesScroll:SetPoint("TOPLEFT", favoritesHeader, "BOTTOMLEFT", 0, -4); mktui_backdrop(favoritesScroll, .72)
      local favoritesArea = CreateFrame("Frame", nil, favoritesScroll); favoritesArea:SetWidth(760); favoritesArea:SetHeight(320); favoritesArea:SetPoint("TOPLEFT", favoritesScroll, "TOPLEFT", 8, -8); favoritesScroll:SetScrollChild(favoritesArea)
      self.favoritesRows, self.favoritesTableHeader, self.favoritesScrollArea = {}, favoritesHeader, favoritesScroll
      local y = -4
      for index = 1, 8 do
        local row = CreateFrame("Button", nil, favoritesArea); row:SetWidth(744); row:SetHeight(32); row:SetPoint("TOPLEFT", favoritesArea, "TOPLEFT", 0, y); mktui_backdrop(row, .55); row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight"); row.labels, row.signature = {}, nil
        local columnX = 8
        for _, column in ipairs(FAVORITES_COLUMNS) do local label = mktui_font(row, "", 10, .86, .82, .68); label:SetWidth(column[2]); label:SetJustifyH("LEFT"); label:SetPoint("LEFT", row, "LEFT", columnX, 0); table.insert(row.labels, label); columnX = columnX + column[2] end
        row:Hide(); table.insert(self.favoritesRows, row); y = y - 36
      end
      self.favoritesEmptyState = mktui_font(favoritesArea, "No favorite listings.", 12, .72, .72, .72); self.favoritesEmptyState:SetPoint("CENTER", favoritesArea, "CENTER", 0, 0)
      self.favoritesSummary = mktui_font(favoritesShell, "", 10, .72, .72, .72); self.favoritesSummary:SetPoint("TOPRIGHT", favoritesShell, "TOPRIGHT", -4, 10)
      local fp = CreateFrame("Button", nil, favoritesShell); fp:SetWidth(54); fp:SetHeight(20); fp:SetPoint("TOPLEFT", favoritesShell, "BOTTOMLEFT", 0, -4); mktui_backdrop(fp, .88); fp.label = mktui_font(fp, "Previous", 9, .9, .76, .32); fp.label:SetPoint("CENTER")
      local fi = mktui_font(favoritesShell, "", 10, .72, .72, .72); fi:SetPoint("LEFT", fp, "RIGHT", 10, 0)
      local fn = CreateFrame("Button", nil, favoritesShell); fn:SetWidth(38); fn:SetHeight(20); fn:SetPoint("LEFT", fi, "RIGHT", 10, 0); mktui_backdrop(fn, .88); fn.label = mktui_font(fn, "Next", 9, .9, .76, .32); fn.label:SetPoint("CENTER")
      self.favoritesPrevious, self.favoritesNext, self.favoritesPageIndicator = fp, fn, fi
      local detail = CreateFrame("Frame", nil, favoritesShell); detail:SetWidth(780); detail:SetHeight(352); detail:SetPoint("TOPLEFT", favoritesShell, "TOPLEFT", 0, 0); mktui_backdrop(detail, .72)
      local back = CreateFrame("Button", nil, detail); back:SetWidth(116); back:SetHeight(24); back:SetPoint("TOPLEFT", detail, "TOPLEFT", 10, -10); mktui_backdrop(back, .88); back.label = mktui_font(back, "Back to Favorites", 10, .9, .76, .32); back.label:SetPoint("CENTER")
      local action = CreateFrame("Button", nil, detail); action:SetWidth(116); action:SetHeight(24); action:SetPoint("LEFT", back, "RIGHT", 8, 0); mktui_backdrop(action, .88); action.label = mktui_font(action, "Unfavorite", 10, .9, .76, .32); action.label:SetPoint("CENTER")
      self.favoriteBack, self.favoriteAction, self.favoriteDetailValues = back, action, {}
      local favoriteFields = {"Player", "Listing Type", "Profession", "Item", "Recipe", "Materials Policy", "Price / Tip", "Location", "Availability", "Expires", "Notes", "Status"}
      for index, field in ipairs(favoriteFields) do local column, rowY = index <= 6 and 0 or 380, -48 - (((index - 1) % 6) * 43); local name = mktui_font(detail, field, 10, .9, .76, .32); name:SetWidth(105); name:SetPoint("TOPLEFT", detail, "TOPLEFT", 12 + column, rowY); local value = mktui_font(detail, "", 11, .86, .82, .68); value:SetWidth(250); value:SetHeight(38); value:SetPoint("TOPLEFT", detail, "TOPLEFT", 120 + column, rowY); self.favoriteDetailValues[index] = value end
      detail:Hide(); favoritesShell:Hide(); self.favoritesDetail, self.favoritesShell, self.favoritesPage = detail, favoritesShell, 1

      local form = CreateFrame("Frame", nil, panel); form:SetWidth(780); form:SetHeight(360); form:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -140); mktui_backdrop(form, .72)
      self.formShell, self.formInputs = form, {}
      local fields = {{"listingType","Listing Type"},{"profession","Profession"},{"itemName","Item"},{"recipeName","Recipe"},{"materialsPolicy","Materials"},{"priceMode","Price Mode"},{"priceText","Price / Tip"},{"location","Location"},{"availability","Availability"},{"notes","Notes"}}
      for index, field in ipairs(fields) do
        local col, row = index <= 5 and 0 or 380, (index-1)%5; local label=mktui_font(form,field[2],10,.9,.76,.32); label:SetPoint("TOPLEFT",form,"TOPLEFT",12+col,-16-(row*54)); local box=CreateFrame("EditBox",nil,form); box:SetWidth(330); box:SetHeight(24); box:SetPoint("TOPLEFT",form,"TOPLEFT",12+col,-32-(row*54)); box:SetAutoFocus(false); box:SetFontObject(ChatFontNormal); mktui_backdrop(box,.88); self.formInputs[field[1]]=box
      end
      self.formMessage=mktui_font(form,"",10,.9,.45,.25); self.formMessage:SetPoint("TOPLEFT",form,"TOPLEFT",12,-300)
      local primary=CreateFrame("Button",nil,form); primary:SetWidth(110); primary:SetHeight(24); primary:SetPoint("TOPLEFT",form,"TOPLEFT",12,-326); mktui_backdrop(primary,.88); primary.label=mktui_font(primary,"Create Listing",10,.9,.76,.32); primary.label:SetPoint("CENTER")
      local cancel=CreateFrame("Button",nil,form); cancel:SetWidth(72); cancel:SetHeight(24); cancel:SetPoint("LEFT",primary,"RIGHT",8,0); mktui_backdrop(cancel,.88); cancel.label=mktui_font(cancel,"Cancel",10,.9,.76,.32); cancel.label:SetPoint("CENTER")
      self.formPrimary,self.formCancel=primary,cancel; form:Hide()

      self.panel = panel
      B.marketplacePanel = panel
      self.buildCount = self.buildCount + 1
      self:ActivateScripts()
      return true
    end

    function U:Hide()
      self:ClearSelection()
      self:ClearMyListingsSelection()
      self:ClearFavoriteSelection()
      if self.browseSearchBox then self.browseSearchBox:ClearFocus() end
      self:CloseBrowseSelectors()
      if self.panel then self.panel:Hide() end
      return true
    end

    function U:Refresh()
      if not self.panel or not self.panel:IsShown() then
        self.hiddenRefreshSkips = self.hiddenRefreshSkips + 1
        return false
      end
      return self:SetTab(self.selectedTab or "Browse")
    end

    function U:Show()
      if not self.active or not self.panel then return false end
      if B.HidePanels then B:HidePanels() end
      self.panel:Show()
      self:SetTab(self.selectedTab or "Browse")
      if B.frame then B.frame:Show() end
      B.currentTab = "Marketplace"
      self.openCount = self.openCount + 1
      return true
    end

    function U:Register()
      if self.registered then return true end
      local ok, recordOrError = LP:RegisterPanel(self.panelKey, {
        builder=function() return U:Build() end,
        show=function() return U:Show() end,
        refresh=function() return U:Refresh() end,
        ready=function() return U.panel ~= nil end,
        visible=function() return U.panel and U.panel:IsShown() and true or false end,
        hide=function() return U:Hide() end,
        requiresShell=true,
      })
      if not ok then return false, recordOrError end
      self.registered = true
      return true
    end

    function U:Unregister()
      if self.registered then LP:UnregisterPanel(self.panelKey) end
      self.registered = false
      return true
    end

    function U:Enable(profile)
      self:CloseBrowseSelectors()
      if self.profile ~= tostring(profile or "") then
        self:ClearBrowseSnapshot(); self:ClearBrowseFilteredView(); self:ClearMyListingsView(); self:ClearFavoritesView(); self:ClearSelection(); self:ClearMyListingsSelection(); self:ClearFavoriteSelection(); self.browsePage = 1; self.myListingsPage = 1; self.favoritesPage = 1; self.browseSearchQuery = ""
        self.browseListingType, self.browseProfessionKey, self.browseProfessionLabel = "", "", ""
        self.browseLocationKey, self.browseLocationLabel, self.browseAvailability = "", "", ""
        self.browseFavoritesOnly = false
        if self.browseSearchBox then self.browseSearchBox:SetText(""); self.browseSearchBox:ClearFocus() end
        self:SyncBrowseFilterLabels()
      end
      self.active = true
      self.profile = tostring(profile or "")
      local ok, err = self:Register()
      if not ok then self.active = false; return false, err end
      if self.panel then self:ActivateScripts() end
      return true
    end

    function U:Disable(reason)
      local wasVisible = self.panel and self.panel:IsShown() and true or false
      self.active = false
      self:Hide()
      self:DeactivateScripts()
      self:Unregister()
      self.selectedTab = nil
      self.browsePage = 1
      self.myListingsPage = 1
      self.favoritesPage = 1
      self.browseSearchQuery = ""
      self.browseListingType, self.browseProfessionKey, self.browseProfessionLabel = "", "", ""
      self.browseLocationKey, self.browseLocationLabel, self.browseAvailability = "", "", ""
      self.browseFavoritesOnly = false
      self:SyncBrowseFilterLabels()
      if self.browseSearchBox then self.browseSearchBox:SetText(""); self.browseSearchBox:ClearFocus() end
      self.temporary = nil
      self:ClearBrowseSnapshot()
      self:ClearBrowseFilteredView()
      self:ClearMyListingsView()
      self:ClearFavoritesView()
      for _, row in ipairs(self.browseRows or {}) do row:Hide(); row.signature, row.listingId = nil, nil end
      for _, row in ipairs(self.myListingsRows or {}) do row:Hide(); row.signature, row.listingId = nil, nil end
      for _, row in ipairs(self.favoritesRows or {}) do row:Hide(); row.signature, row.favoriteId = nil, nil end
      self.lastDisableReason = tostring(reason or "disabled")
      if wasVisible and B.frame and B.frame:IsShown() and LP.panels.browse then
        LP:Open("browse", "marketplace-disable")
      elseif B.currentTab == "Marketplace" then
        B.currentTab = "Browse"
      end
      return true
    end

    function U:Open(trigger)
      if not M:IsEnabled() then
        mktui_emit("Tradeskill Marketplace is disabled. Enable it in Options > Modules or use /sf marketplace on.")
        return false
      end
      local ok, err = M:Enable()
      if not ok then mktui_emit("Could not open Marketplace: " .. tostring(err)); return false end
      M:ExpireListings("open")
      return LP:Open(self.panelKey, tostring(trigger or "marketplace"))
    end

    function U:IsDisabledClean()
      return not self.active and not self.registered and self:GetPanelState() ~= "visible"
        and self:ActiveScriptCount() == 0
    end

    function U:GetDiagnostics()
      return {
        generation=self.generation,
        state=self:GetPanelState(),
        active=self.active == true,
        registered=self.registered == true,
        buildCount=self.buildCount,
        openCount=self.openCount,
        refreshCount=self.refreshCount,
        hiddenRefreshSkips=self.hiddenRefreshSkips,
        activeScripts=self:ActiveScriptCount(),
        disabledClean=self:IsDisabledClean(),
      }
    end

    function B:ShowMarketplace() return U:Open("sidebar") end
    function B:SFMarketplaceOpen(trigger) return U:Open(trigger) end
    function B:SFMarketplaceRefresh() return U:Refresh() end
    function B:SFMarketplaceGetUIDiagnostics() return U:GetDiagnostics() end

    if M.runtime and M.runtime.active and M:IsEnabled() then U:Enable(M.runtime.profile)
    else U:Disable("load-disabled") end
  end
end

