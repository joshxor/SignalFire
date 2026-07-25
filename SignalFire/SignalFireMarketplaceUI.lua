-- SignalFire Tradeskill Marketplace Phase 1B: lazy UI shell only.
do
  local B = _G.BronzeLFG
  local M = _G.SignalFireMarketplace151
  local LP = _G.SignalFireLazyPanels151
  if B and M and LP and LP.RegisterPanel and LP.UnregisterPanel then
    local U = _G.SignalFireMarketplaceUI151 or {}
    _G.SignalFireMarketplaceUI151 = U

    U.generation = "1.5.3-marketplace-phase1c2"
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

    function U:OnMarketplaceDataChanged()
      self:ClearBrowseSnapshot()
      if self.active and self:GetPanelState() == "visible" and self.selectedTab == "Browse" then
        self:RenderBrowse()
      end
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
      local snapshot = self:BuildBrowseSnapshot()
      if not snapshot then return false end
      local stamp = tonumber(time and time() or 0) or 0
      local shown = math.min(8, snapshot.total)
      if shown == 0 then self.browseEmptyState:Show() else self.browseEmptyState:Hide() end
      self.browseSummary:SetText(snapshot.total > 8 and ("Showing 8 of " .. tostring(snapshot.total)) or "")
      for index, rowControl in ipairs(self.browseRows) do
        local row = snapshot.rows[index]
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
          rowControl:Show()
        else
          rowControl:Hide()
          rowControl.signature = nil
        end
      end
      self.browseRowCount, self.browseDirty = shown, false
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
      return count
    end

    function U:ActivateScripts()
      if not self.panel then return false end
      self.panel:EnableMouse(true)
      for _, button in ipairs(self.navButtons or {}) do
        button:EnableMouse(true)
        button:SetScript("OnClick", mktui_nav_click)
      end
      return true
    end

    function U:DeactivateScripts()
      if self.panel then self.panel:EnableMouse(false) end
      for _, button in ipairs(self.navButtons or {}) do
        button:SetScript("OnClick", nil)
        button:EnableMouse(false)
      end
      return true
    end

    function U:SetTab(tab)
      if not self.active or not self.panel or not self.panel:IsShown() then return false end
      if not PLACEHOLDERS[tab] then tab = "Browse" end
      self.selectedTab = tab
      self.sectionTitle:SetText(tab)
      local browse = tab == "Browse"
      if self.browseShell then
        if browse then self.browseShell:Show() else self.browseShell:Hide() end
      end
      if browse then
        self.placeholder:Hide()
      else
        self.placeholder:SetText(PLACEHOLDERS[tab])
        self.placeholder:Show()
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
      if browse then self:RenderBrowse() end
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
      local header = CreateFrame("Frame", nil, browseShell)
      header:SetWidth(780); header:SetHeight(24)
      header:SetPoint("TOPLEFT", browseShell, "TOPLEFT", 0, 0)
      mktui_backdrop(header, .90)
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
        local row = CreateFrame("Frame", nil, rows)
        row:SetWidth(744); row:SetHeight(32)
        row:SetPoint("TOPLEFT", rows, "TOPLEFT", 0, rowY)
        mktui_backdrop(row, .55)
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
      self.browseShell = browseShell

      self.panel = panel
      B.marketplacePanel = panel
      self.buildCount = self.buildCount + 1
      self:ActivateScripts()
      return true
    end

    function U:Hide()
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
      if self.profile ~= tostring(profile or "") then self:ClearBrowseSnapshot() end
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
      self.temporary = nil
      self:ClearBrowseSnapshot()
      for _, row in ipairs(self.browseRows or {}) do row:Hide(); row.signature = nil end
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
