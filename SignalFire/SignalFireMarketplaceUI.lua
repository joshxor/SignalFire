-- SignalFire Tradeskill Marketplace Phase 1B: lazy UI shell only.
do
  local B = _G.BronzeLFG
  local M = _G.SignalFireMarketplace151
  local LP = _G.SignalFireLazyPanels151
  if B and M and LP and LP.RegisterPanel and LP.UnregisterPanel then
    local U = _G.SignalFireMarketplaceUI151 or {}
    _G.SignalFireMarketplaceUI151 = U

    U.generation = "1.5.3-marketplace-phase1b"
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
      ["Browse"]="No marketplace listings.",
      ["My Listings"]="No active listings.",
      ["Create Listing"]="No draft listing.",
      ["Favorites"]="No favorite listings.",
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
      self.placeholder:SetText(PLACEHOLDERS[tab])
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
      self.placeholder = mktui_font(panel, PLACEHOLDERS.Browse, 12, .72, .72, .72)
      self.placeholder:SetPoint("TOPLEFT", self.sectionTitle, "BOTTOMLEFT", 0, -18)

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
