-- SignalFire 1.5.1
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Final interface ownership
do
  repeat
    local BLFG = BronzeLFG
    if not BLFG then break end

    local SFUI_HEADER_WIDTH = 124
    local SFUI_HEADER_GAP = 8
    local SFUI_HEADER_RIGHT = 18

    local function sfui_profile_id()
      if BLFG.SF143_GetProfileId then
        local ok, id = pcall(function() return BLFG:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      if BronzeLFG_DB and BronzeLFG_DB.options then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sfui_profile_name(compact)
      if SignalFire_GetProfileDisplayName then
        return SignalFire_GetProfileDisplayName(sfui_profile_id(), compact)
      end
      return sfui_profile_id()
    end

    local function sfui_version_label()
      if SignalFire_GetVersionLabel then return SignalFire_GetVersionLabel(sfui_profile_id()) end
      return "v" .. tostring(SignalFire_VERSION or "1.5.1") .. " - " .. sfui_profile_name(true)
    end

    local function sfui_flat(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Buttons\\WHITE8X8",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .94)
      frame:SetBackdropBorderColor(.62, .43, .08, .92)
    end

    local function sfui_subpanels()
      local panels = {}
      if BLFG.sfmmPanel then table.insert(panels, BLFG.sfmmPanel) end
      if BLFG.sfcpPanel then table.insert(panels, BLFG.sfcpPanel) end
      if BLFG.sfn138FavoriteOptionsPanel then table.insert(panels, BLFG.sfn138FavoriteOptionsPanel) end
      if BLFG.sfamPolishPanel then table.insert(panels, BLFG.sfamPolishPanel) end
      if BLFG.sfe141EventOptionsPanel then table.insert(panels, BLFG.sfe141EventOptionsPanel) end
      return panels
    end

    local function sfui_hide_subpanels(except)
      for _, panel in ipairs(sfui_subpanels()) do
        if panel and panel ~= except and panel.Hide then panel:Hide() end
      end
    end

    local function sfui_style_subpanel(panel)
      if not panel then return end
      sfui_flat(panel, .985)
      if panel.SetFrameLevel and BLFG.optionsPanel and BLFG.optionsPanel.GetFrameLevel then
        panel:SetFrameLevel((BLFG.optionsPanel:GetFrameLevel() or 1) + 170)
      end
      local children = {panel:GetChildren()}
      for _, child in ipairs(children) do
        if child and child.GetText and child.SetPoint then
          local text = tostring(child:GetText() or "")
          if text == "Back to Options" then
            child:ClearAllPoints()
            child:SetWidth(150)
            child:SetHeight(28)
            child:SetPoint("BOTTOM", panel, "BOTTOM", 0, 30)
          end
        end
      end
      if not panel.sfui1434Footer then
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.sfui1434Footer = fs
        fs:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
        fs:SetTextColor(.45, .85, 1)
      end
      panel.sfui1434Footer:SetText(sfui_version_label())
    end

    local function sfui_wire_header_button(button)
      if not button or button.sfui1434Wired then return end
      button.sfui1434Wired = true
      local old = button:GetScript("OnClick")
      button:SetScript("OnClick", function(self, ...)
        sfui_hide_subpanels(nil)
        if old then old(self, ...) end
        for _, panel in ipairs(sfui_subpanels()) do
          if panel and panel.IsShown and panel:IsShown() then sfui_style_subpanel(panel) end
        end
      end)
    end

    local function sfui_layout_options_header()
      local p = BLFG.optionsPanel
      if not p then return end
      if BLFG.SFCP_AddOptions then pcall(function() BLFG:SFCP_AddOptions() end) end
      if BLFG.SFMM_AddOptions then pcall(function() BLFG:SFMM_AddOptions() end) end

      local buttons = {
        BLFG.sfmmOpenButton,
        BLFG.sfcpOpenButton,
        BLFG.sfn138FavoriteAlertButton,
        BLFG.sfamPolishButton,
        BLFG.sfe141EventAlertButton,
      }
      local count = 0
      for _, b in ipairs(buttons) do if b then count = count + 1 end end
      if count == 0 then return end
      local panelWidth = (p.GetWidth and p:GetWidth()) or 820
      local total = count * SFUI_HEADER_WIDTH + (count - 1) * SFUI_HEADER_GAP
      local x = panelWidth - SFUI_HEADER_RIGHT - total
      if x < 112 then x = 112 end
      for _, b in ipairs(buttons) do
        if b then
          b:ClearAllPoints()
          b:SetWidth(SFUI_HEADER_WIDTH)
          b:SetHeight(24)
          b:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
          b:Show(); b:Enable(); b:SetAlpha(1)
          sfui_wire_header_button(b)
          x = x + SFUI_HEADER_WIDTH + SFUI_HEADER_GAP
        end
      end

      if BLFG.sfmmBodyButton then
        BLFG.sfmmBodyButton:SetWidth(150)
        BLFG.sfmmBodyButton:SetHeight(24)
        BLFG.sfmmBodyButton:Show(); BLFG.sfmmBodyButton:Enable(); BLFG.sfmmBodyButton:SetAlpha(1)
        sfui_wire_header_button(BLFG.sfmmBodyButton)
      end
    end

    local function sfui_hide_legacy_module_controls()
      local inv = BLFG.optModuleInvasions
      if inv then
        inv:Hide(); inv:Disable()
        if inv.EnableMouse then inv:EnableMouse(false) end
      end
      local host = inv and inv:GetParent() or BLFG.optionsPanel
      if host and host.GetRegions then
        local regions = {host:GetRegions()}
        for _, region in ipairs(regions) do
          if region and region.GetText and region.Hide then
            local text = tostring(region:GetText() or "")
            if text == "Modules" or text == "Invasions" then region:Hide() end
          end
        end
      end
    end

    local function sfui_suppress_legacy_version_elements()
      if BLFG.versionText then
        if BLFG.versionText.SetText then BLFG.versionText:SetText("") end
        if BLFG.versionText.SetAlpha then BLFG.versionText:SetAlpha(0) end
        if BLFG.versionText.Hide then BLFG.versionText:Hide() end
      end
      if BLFG.sfui1434VersionBadge then
        if BLFG.sfui1434VersionBadge.Hide then BLFG.sfui1434VersionBadge:Hide() end
        if BLFG.sfui1434VersionBadge.SetAlpha then BLFG.sfui1434VersionBadge:SetAlpha(0) end
      end
      if BLFG.sfui1434VersionBadgeText and BLFG.sfui1434VersionBadgeText.SetText then
        BLFG.sfui1434VersionBadgeText:SetText("")
      end
    end

    local function sfui_apply_identity()
      BLFG.version = (SignalFire_GetVersion and SignalFire_GetVersion()) or tostring(SignalFire_VERSION or "1.5.0")
      if BronzeLFG_ApplyVisibleVersion then
        BronzeLFG_ApplyVisibleVersion()
      elseif BLFG.titleText then
        BLFG.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or ("SignalFire v" .. tostring(BLFG.version) .. " (Beta)"))
      end
      sfui_suppress_legacy_version_elements()
      if BLFG.sideBrand then
        BLFG.sideBrand:SetText(sfui_profile_name(true))
        if BLFG.sideBrand.SetWidth then BLFG.sideBrand:SetWidth(164) end
      end
      if BLFG.optionsStatus and BLFG.optionsStatus.GetText then
        local text = tostring(BLFG.optionsStatus:GetText() or "")
        if string.find(text, "^Active server profile:") then
          BLFG.optionsStatus:SetText("Active server profile: " .. sfui_profile_name(false))
        end
      end
      for _, panel in ipairs(sfui_subpanels()) do
        if panel then sfui_style_subpanel(panel) end
      end
    end

    function BLFG:SFUI1434_Apply()
      sfui_layout_options_header()
      sfui_hide_legacy_module_controls()
      sfui_apply_identity()
    end

    local oldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local r = oldCreateUI and oldCreateUI(self, ...)
      self:SFUI1434_Apply()
      if self.frame and self.frame.HookScript and not self.frame.sfui1434ShowHooked then
        self.frame.sfui1434ShowHooked = true
        self.frame:HookScript("OnShow", function() BLFG:SFUI1434_Apply() end)
      end
      return r
    end

    local oldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = oldBuildOptions and oldBuildOptions(self, ...)
      self:SFUI1434_Apply()
      return r
    end

    local oldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      sfui_hide_subpanels(nil)
      local r = oldShowOptions and oldShowOptions(self, ...)
      self:SFUI1434_Apply()
      return r
    end

    local oldBuildSide = BLFG.BuildSide
    function BLFG:BuildSide(...)
      local r = oldBuildSide and oldBuildSide(self, ...)
      sfui_apply_identity()
      return r
    end

    local oldHidePanels = BLFG.HidePanels
    function BLFG:HidePanels(...)
      local r = oldHidePanels and oldHidePanels(self, ...)
      sfui_apply_identity()
      return r
    end

    local oldBrand = BLFG.SF143_UpdateServerBrand
    function BLFG:SF143_UpdateServerBrand(...)
      local r = oldBrand and oldBrand(self, ...)
      sfui_apply_identity()
      return r
    end

    -- Legacy guild/network refreshes still call this helper. Preserve their behavior,
    -- then reapply the one authoritative title and suppress obsolete version elements.
    local sfui_old_beta_title = BLFG.ApplySignalFireBetaTitle
    function BLFG:ApplySignalFireBetaTitle(...)
      local r = sfui_old_beta_title and sfui_old_beta_title(self, ...)
      if BronzeLFG_ApplyVisibleVersion then BronzeLFG_ApplyVisibleVersion() end
      sfui_suppress_legacy_version_elements()
      return r
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
      if BLFG and BLFG.SFUI1434_Apply then BLFG:SFUI1434_Apply() end
    end)

    if BLFG.frame then BLFG:SFUI1434_Apply() end
  until true
end

-- Phase 6: final hot-path ownership diagnostics and re-entry protection.
function SignalFire_InstallPhase6()
  local B = _G.BronzeLFG
  local P4 = _G.SignalFireRefresh151
  if B and P4 and P4.original then
    local P6 = _G.SignalFireHotPath151 or {}
    _G.SignalFireHotPath151 = P6
    P6.generation = "1.5.1-phase6"
    P6.original = P6.original or {}
    P6.active = P6.active or {}
    P6.stats = P6.stats or {}

    local function p6_clock_ms()
      if debugprofilestop then return debugprofilestop() end
      return ((GetTime and GetTime()) or 0) * 1000
    end

    local function p6_count(values)
      if type(values) ~= "table" then return 0 end
      local count = 0
      for _ in pairs(values) do count = count + 1 end
      return count
    end

    local function p6_dataset_size(panel)
      if panel == "publicGroups" then return p6_count(B.publicGroups) end
      if panel == "guildBrowser" then return p6_count(B.guilds) + p6_count(B.guildPosts) end
      if panel == "network" or panel == "roster" then
        return p6_count(B.onlineUsers) + p6_count(B.sfnStatuses)
      end
      return 0
    end

    local function p6_panel_stats(panel)
      P6.stats.panels = P6.stats.panels or {}
      P6.stats.panels[panel] = P6.stats.panels[panel] or {
        calls = 0, nestedSuppressed = 0, totalMs = 0, maxMs = 0, maxRows = 0,
      }
      return P6.stats.panels[panel]
    end

    local function p6_install_panel_owner(panel)
      if P6.original[panel] then return end
      local old = P4.original[panel]
      if type(old) ~= "function" then return end
      P6.original[panel] = old
      P4.original[panel] = function(self, ...)
        local stats = p6_panel_stats(panel)
        if P6.active[panel] then
          stats.nestedSuppressed = (stats.nestedSuppressed or 0) + 1
          return
        end
        P6.active[panel] = true
        local rows = p6_dataset_size(panel)
        if rows > (stats.maxRows or 0) then stats.maxRows = rows end
        local started = p6_clock_ms()
        local result = old(self, ...)
        local elapsed = math.max(0, p6_clock_ms() - started)
        P6.active[panel] = nil
        stats.calls = (stats.calls or 0) + 1
        stats.totalMs = (stats.totalMs or 0) + elapsed
        if elapsed > (stats.maxMs or 0) then stats.maxMs = elapsed end
        return result
      end
    end

    for _, panel in ipairs({"network", "roster", "publicGroups", "guildBrowser", "browse", "applicants", "myListing"}) do
      p6_install_panel_owner(panel)
    end

    local function p6_wrap_ui_method(methodName, counterName)
      P6.uiOriginal = P6.uiOriginal or {}
      if P6.uiOriginal[methodName] or type(B[methodName]) ~= "function" then return end
      local old = B[methodName]
      P6.uiOriginal[methodName] = old
      B[methodName] = function(self, ...)
        P6.stats[counterName] = (P6.stats[counterName] or 0) + 1
        return old(self, ...)
      end
    end

    p6_wrap_ui_method("BuildOptions", "buildOptions")
    p6_wrap_ui_method("ShowOptions", "showOptions")
    p6_wrap_ui_method("BuildCreate", "buildCreate")
    p6_wrap_ui_method("ShowCreate", "showCreate")

    function B:SF151_ResetHotPathStats()
      P6.stats = {}
      return true
    end

    function B:SF151_GetHotPathStats()
      local report = {
        generation = P6.generation,
        panels = {},
        buildOptions = P6.stats.buildOptions or 0,
        showOptions = P6.stats.showOptions or 0,
        buildCreate = P6.stats.buildCreate or 0,
        showCreate = P6.stats.showCreate or 0,
      }
      for _, panel in ipairs({"network", "roster", "publicGroups", "guildBrowser", "browse", "applicants", "myListing"}) do
        local source = p6_panel_stats(panel)
        report.panels[panel] = {
          calls = source.calls or 0,
          nestedSuppressed = source.nestedSuppressed or 0,
          totalMs = source.totalMs or 0,
          maxMs = source.maxMs or 0,
          maxRows = source.maxRows or 0,
        }
      end
      return report
    end

    function B:SF151_PrintHotPathStats()
      local report = self:SF151_GetHotPathStats()
      local function out(text)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. text) end
      end
      out("hot owner " .. tostring(report.generation) .. ", options=" .. tostring(report.buildOptions) .. "/" .. tostring(report.showOptions) .. ", create=" .. tostring(report.buildCreate) .. "/" .. tostring(report.showCreate))
      for _, panel in ipairs({"network", "roster", "publicGroups", "guildBrowser", "browse", "applicants", "myListing"}) do
        local stats = report.panels[panel]
        local average = stats.calls > 0 and (stats.totalMs / stats.calls) or 0
        out(panel .. ": calls=" .. tostring(stats.calls) .. ", nested=" .. tostring(stats.nestedSuppressed) .. ", avgMs=" .. string.format("%.2f", average) .. ", maxMs=" .. string.format("%.2f", stats.maxMs) .. ", maxRows=" .. tostring(stats.maxRows))
      end
      return report
    end
  end
end

-- Phase 4: batch bursty data changes into one visible-panel refresh.
do
  local B = _G.BronzeLFG
  if B and CreateFrame then
    local P4 = _G.SignalFireRefresh151 or {}
    _G.SignalFireRefresh151 = P4
    P4.generation = "1.5.1-phase4d"
    P4.debounceSeconds = 0.15
    P4.presenceDebounceSeconds = 0.75
    P4.maximumBurstSeconds = 2.0
    P4.dirty = P4.dirty or {}
    P4.deadline = P4.deadline or {}
    P4.firstDirtyAt = P4.firstDirtyAt or {}
    P4.hiddenCounted = P4.hiddenCounted or {}
    P4.original = P4.original or {}
    P4.executing = nil
    P4.pending = false

    local panelOrder = {
      "network", "roster", "publicGroups", "guildBrowser",
      "browse", "applicants", "myListing",
    }

    local function newStats()
      return {
        incomingPresence = 0,
        requests = 0,
        executed = 0,
        merged = 0,
        hiddenSkipped = 0,
        nestedSuppressed = 0,
        maxDirty = 0,
        requestedByPanel = {},
        executedByPanel = {},
      }
    end

    P4.stats = P4.stats or newStats()

    local function stats()
      P4.stats = P4.stats or newStats()
      return P4.stats
    end

    local function frameShown(frame)
      if not frame then return false end
      if frame.IsVisible then return frame:IsVisible() and true or false end
      if frame.IsShown then return frame:IsShown() and true or false end
      return false
    end

    local function panelVisible(panel)
      if panel == "network" then return frameShown(B.sfnPanel) end
      if panel == "roster" then return frameShown(B.onlinePanel) end
      if panel == "publicGroups" then return frameShown(B.publicPanel) end
      if panel == "guildBrowser" then return frameShown(B.guildPanel) end
      if panel == "browse" then return frameShown(B.browse) end
      if panel == "applicants" then return frameShown(B.apps) end
      if panel == "myListing" then return frameShown(B.myPanel) end
      return false
    end

    local function dirtyCount()
      local count = 0
      for _, panel in ipairs(panelOrder) do
        if P4.dirty[panel] then count = count + 1 end
      end
      return count
    end

    local function hasVisibleDirty()
      for _, panel in ipairs(panelOrder) do
        if P4.dirty[panel] and panelVisible(panel) then return true end
      end
      return false
    end

    local function clock()
      return GetTime and GetTime() or 0
    end

    P4.frame = P4.frame or CreateFrame("Frame")
    P4.frame:Hide()
    P4.frame.elapsed = 0

    local function schedule()
      if P4.pending then return end
      P4.pending = true
      P4.frame.elapsed = 0
      P4.frame:Show()
    end

    local function request(panel, mode)
      if not panel or not P4.original[panel] then return false end
      local s = stats()
      local at = clock()
      s.requests = (s.requests or 0) + 1
      s.requestedByPanel[panel] = (s.requestedByPanel[panel] or 0) + 1
      if P4.executing == panel then
        s.nestedSuppressed = (s.nestedSuppressed or 0) + 1
        return true
      end
      if P4.dirty[panel] or P4.pending then s.merged = (s.merged or 0) + 1 end
      if not P4.dirty[panel] then
        P4.firstDirtyAt[panel] = at
        P4.hiddenCounted[panel] = nil
      end
      P4.dirty[panel] = true
      if mode == "show" then
        P4.deadline[panel] = at
      elseif mode == "presence" and (panel == "network" or panel == "roster") then
        local first = P4.firstDirtyAt[panel] or at
        local deadline = at + P4.presenceDebounceSeconds
        local maximum = first + P4.maximumBurstSeconds
        if deadline > maximum then deadline = maximum end
        P4.deadline[panel] = deadline
      else
        local deadline = at + P4.debounceSeconds
        if not P4.deadline[panel] or P4.deadline[panel] < deadline then
          P4.deadline[panel] = deadline
        end
      end
      local count = dirtyCount()
      if count > (s.maxDirty or 0) then s.maxDirty = count end
      schedule()
      return true
    end

    local function execute(panel)
      local fn = P4.original[panel]
      if not fn then return end
      local s = stats()
      P4.executing = panel
      fn(B)
      P4.executing = nil
      s.executed = (s.executed or 0) + 1
      s.executedByPanel[panel] = (s.executedByPanel[panel] or 0) + 1
    end

    local function flush()
      local run = {}
      local s = stats()
      local at = clock()
      for _, panel in ipairs(panelOrder) do
        if P4.dirty[panel] then
          if panelVisible(panel) then
            if at >= (P4.deadline[panel] or 0) then
              P4.dirty[panel] = nil
              P4.deadline[panel] = nil
              P4.firstDirtyAt[panel] = nil
              P4.hiddenCounted[panel] = nil
              table.insert(run, panel)
            end
          else
            if not P4.hiddenCounted[panel] then
              P4.hiddenCounted[panel] = true
              s.hiddenSkipped = (s.hiddenSkipped or 0) + 1
            end
          end
        end
      end
      for _, panel in ipairs(run) do execute(panel) end
      if hasVisibleDirty() then
        P4.pending = true
      else
        P4.pending = false
        P4.frame:Hide()
      end
    end

    P4.frame:SetScript("OnUpdate", function(frame, elapsed)
      frame.elapsed = (frame.elapsed or 0) + (tonumber(elapsed) or 0)
      if frame.elapsed < 0.03 then return end
      frame.elapsed = 0
      flush()
    end)

    local refreshMethods = {
      network = "RefreshSFNetwork",
      roster = "RefreshOnlinePanel",
      publicGroups = "RefreshPublicGroups",
      guildBrowser = "RefreshGuildBrowser",
      browse = "RefreshBrowse",
      applicants = "RefreshApplicants",
      myListing = "RefreshMyListing",
    }

    local showMethods = {
      network = "ShowSFNetwork",
      roster = "ShowFullRoster",
      publicGroups = "ShowPublicGroups",
      guildBrowser = "ShowGuildBrowser",
      browse = "ShowBrowse",
      applicants = "ShowApplicants",
      myListing = "ShowMyListing",
    }

    local function installFinalOwners()
      if P4.installed then return end
      P4.installed = true

      for panel, methodName in pairs(refreshMethods) do
        local panelKey = panel
        local methodKey = methodName
        local old = B[methodKey]
        if type(old) == "function" then
          P4.original[panelKey] = old
          B[methodKey] = function()
            request(panelKey)
          end
        end
      end

      for panel, methodName in pairs(showMethods) do
        local panelKey = panel
        local methodKey = methodName
        local old = B[methodKey]
        if type(old) == "function" then
          B[methodKey] = function(self, ...)
            local result = old(self, ...)
            request(panelKey, "show")
            return result
          end
        end
      end

      local oldHandlePresence = B.HandlePresence
      if type(oldHandlePresence) == "function" then
        B.HandlePresence = function(self, ...)
          local s = stats()
          s.incomingPresence = (s.incomingPresence or 0) + 1
          local result = oldHandlePresence(self, ...)
          request("network", "presence")
          request("roster", "presence")
          return result
        end
      end
    end

    P4.InstallFinalOwners = installFinalOwners

    function B:SF151_NotePresencePacket()
      local s = stats()
      s.incomingPresence = (s.incomingPresence or 0) + 1
      return s.incomingPresence
    end

    function B:SF151_RequestPanelRefresh(panel, mode)
      return request(panel, mode)
    end

    function B:SF151_ResetRefreshStats()
      P4.stats = newStats()
      return true
    end

    function B:SF151_GetRefreshStats()
      local source = stats()
      local result = {
        generation = P4.generation,
        debounceSeconds = P4.debounceSeconds,
        presenceDebounceSeconds = P4.presenceDebounceSeconds,
        pending = P4.pending == true,
        dirtyCount = dirtyCount(),
      }
      for key, value in pairs(source) do
        if type(value) == "table" then
          result[key] = {}
          for childKey, childValue in pairs(value) do result[key][childKey] = childValue end
        else
          result[key] = value
        end
      end
      return result
    end

    function B:SF151_GetRefreshRuntimeStatus()
      local s = stats()
      return s.incomingPresence or 0, s.requests or 0, s.executed or 0,
        s.merged or 0, s.hiddenSkipped or 0, s.maxDirty or 0,
        s.executedByPanel.network or 0, s.executedByPanel.roster or 0
    end

    function B:SF151_PrintRefreshStats()
      local report = self:SF151_GetRefreshStats()
      local s = stats()
      local function emit(text)
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text)) end
      end
      emit("refresh owner " .. tostring(report.generation) .. ", pending=" .. tostring(report.pending)
        .. ", dirty=" .. tostring(report.dirtyCount) .. ", debounce=" .. tostring(report.debounceSeconds)
        .. ", presenceDebounce=" .. tostring(report.presenceDebounceSeconds))
      emit("presence=" .. tostring(s.incomingPresence or 0) .. ", requests=" .. tostring(s.requests or 0)
        .. ", executed=" .. tostring(s.executed or 0) .. ", merged=" .. tostring(s.merged or 0)
        .. ", hidden=" .. tostring(s.hiddenSkipped or 0) .. ", nested=" .. tostring(s.nestedSuppressed or 0)
        .. ", maxDirty=" .. tostring(s.maxDirty or 0))
      for _, panel in ipairs(panelOrder) do
        emit(panel .. ": requested=" .. tostring(s.requestedByPanel[panel] or 0)
          .. ", executed=" .. tostring(s.executedByPanel[panel] or 0)
          .. ", dirty=" .. tostring(P4.dirty[panel] == true)
          .. ", visible=" .. tostring(panelVisible(panel)))
      end
      return report
    end
  end
end

-- SignalFire 1.5.1 Phase 2: class normalization and invasion runtime protection.
do
  local B = _G.BronzeLFG
  if B and not B._sf151Phase2Installed then
    B._sf151Phase2Installed = true

    local function sf152_trim(value)
      local s = tostring(value or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sf152_nonempty(value)
      local s = sf152_trim(value)
      if s == "" or s == "Unknown" or s == "UNKNOWN" then return nil end
      return s
    end

    local function sf152_name_key(value)
      local s = string.lower(sf152_trim(value))
      s = string.gsub(s, "%-.*$", "")
      s = string.gsub(s, "[^a-z0-9]", "")
      return s
    end

    local function sf152_profile()
      if B.SF143_GetProfileId then
        local ok, id = pcall(function() return B:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      return BronzeLFG_DB and BronzeLFG_DB.options and tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate") or "Triumvirate"
    end

    local function sf152_module_enabled()
      if sf152_profile() ~= "Triumvirate" then return false end
      if B.SFModuleIsEnabled then
        local ok, enabled = pcall(function() return B:SFModuleIsEnabled("invasions") end)
        if ok then return enabled == true end
      end
      if B.SFCore149_ModuleEnabled then
        local ok, enabled = pcall(function() return B:SFCore149_ModuleEnabled("invasions") end)
        if ok then return enabled == true end
      end
      local o = BronzeLFG_DB and BronzeLFG_DB.options or nil
      local byProfile = o and o.modulesByProfile and o.modulesByProfile.Triumvirate or nil
      if byProfile and byProfile.invasions ~= nil then return byProfile.invasions == true end
      if o and o.modules and o.modules.invasions ~= nil then return o.modules.invasions == true end
      return true
    end

    local function sf152_localized_class(token)
      token = sf152_nonempty(token)
      if not token then return nil end
      local upper = string.upper(token)
      if LOCALIZED_CLASS_NAMES_MALE and sf152_nonempty(LOCALIZED_CLASS_NAMES_MALE[upper]) then
        return LOCALIZED_CLASS_NAMES_MALE[upper]
      end
      if LOCALIZED_CLASS_NAMES_FEMALE and sf152_nonempty(LOCALIZED_CLASS_NAMES_FEMALE[upper]) then
        return LOCALIZED_CLASS_NAMES_FEMALE[upper]
      end
      return nil
    end

    local function sf152_display_candidate(value)
      local s = sf152_nonempty(value)
      if not s then return nil end
      -- All-uppercase identifiers are generally internal class/spec tokens. Only
      -- accept them when the game can localize them as a normal Wrath class.
      if string.find(s, "^[A-Z_]+$") then return sf152_localized_class(s) end
      return s
    end

    local function sf152_unit_for_name(name)
      local wanted = sf152_name_key(name)
      if wanted == "" or not UnitName then return nil end
      local candidates = {"player", "target", "focus", "mouseover"}
      for i = 1, 4 do table.insert(candidates, "party" .. tostring(i)) end
      for i = 1, 40 do table.insert(candidates, "raid" .. tostring(i)) end
      for _, unit in ipairs(candidates) do
        if (not UnitExists or UnitExists(unit)) and sf152_name_key(UnitName(unit)) == wanted then return unit end
      end
      return nil
    end

    B._sf151KnownClassNames = B._sf151KnownClassNames or {}

    function B:SF151_ResolveClassDisplay(row)
      row = row or {}
      local key = sf152_name_key(row.name)
      local value = sf152_display_candidate(row.className) or sf152_display_candidate(row.class)

      if not value then
        local unit = sf152_unit_for_name(row.name)
        if unit then
          local unitDisplay, unitToken = "", ""
          if UnitClass then unitDisplay, unitToken = UnitClass(unit) end
          local guidDisplay, guidToken = "", ""
          if UnitGUID and GetPlayerInfoByGUID then
            local guid = UnitGUID(unit)
            if guid then guidDisplay, guidToken = GetPlayerInfoByGUID(guid) end
          end
          value = sf152_display_candidate(guidDisplay) or sf152_display_candidate(unitDisplay)
          if not sf152_nonempty(row.classFile) then
            row.classFile = sf152_nonempty(guidToken) or sf152_nonempty(unitToken) or row.classFile
          end
        end
      end

      if not value and key ~= "" then value = sf152_nonempty(self._sf151KnownClassNames[key]) end
      if not value then value = sf152_localized_class(row.classFile) end
      if not value then value = "Unknown" end

      row.className = value
      if key ~= "" and value ~= "Unknown" then self._sf151KnownClassNames[key] = value end
      return value
    end

    local oldGetRows = B.GetOnlineUserRows
    function B:GetOnlineUserRows(...)
      local rows = oldGetRows and oldGetRows(self, ...) or {}
      local byStatus = self.sfnStatuses or {}
      for _, row in ipairs(rows or {}) do
        local key = sf152_name_key(row and row.name)
        if key ~= "" then
          for name, status in pairs(byStatus) do
            if sf152_name_key(name) == key then
              if not sf152_nonempty(row.className) and sf152_nonempty(status.className) then row.className = status.className end
              if not sf152_nonempty(row.classFile) and sf152_nonempty(status.classFile) then row.classFile = status.classFile end
              break
            end
          end
        end
        self:SF151_ResolveClassDisplay(row)
      end
      return rows
    end

    local function sf152_stop_scan()
      local scan = B.invasionWhoScan
      if scan then
        scan.active = false
        scan.pending = false
        if SetWhoToUI then pcall(SetWhoToUI, 1) end
        if WhoFrame and WhoFrame.Hide then WhoFrame:Hide() end
        if FriendsFrame and FriendsFrame.Hide and not scan.friendsWasShown then FriendsFrame:Hide() end
      end
      B.invasionWhoScan = nil
      if B.invasionWhoFrame and B.invasionWhoFrame.Hide then B.invasionWhoFrame:Hide() end
    end

    function B:SF151_InvasionRuntimeEnabled()
      return sf152_profile() == "Triumvirate" and sf152_module_enabled()
    end

    function B:SF151_SyncInvasionRuntime()
      local enabled = self:SF151_InvasionRuntimeEnabled()
      local nearby = _G.BLFG_SF575_InvNearbyFrame
      if nearby then
        if enabled then
          nearby:RegisterEvent("PLAYER_TARGET_CHANGED")
          nearby:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        else
          nearby:UnregisterEvent("PLAYER_TARGET_CHANGED")
          nearby:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        end
      end

      local whoEvents = _G.BLFG_SF575_InvWhoFrame
      local scanActive = enabled and self.invasionWhoScan and self.invasionWhoScan.active
      if whoEvents then
        if scanActive then whoEvents:RegisterEvent("WHO_LIST_UPDATE")
        else whoEvents:UnregisterEvent("WHO_LIST_UPDATE") end
      end

      if not enabled then
        sf152_stop_scan()
        if self.invasionPanel and self.invasionPanel.Hide then self.invasionPanel:Hide() end
        if self.invasionPlayerPanel and self.invasionPlayerPanel.Hide then self.invasionPlayerPanel:Hide() end
      end

      self._sf151InvasionRuntimeActive = enabled and true or false
      return enabled
    end

    function B:SF151_GetInvasionRuntimeStatus()
      local nearby = _G.BLFG_SF575_InvNearbyFrame
      local whoEvents = _G.BLFG_SF575_InvWhoFrame
      local combat = nearby and nearby.IsEventRegistered and nearby:IsEventRegistered("COMBAT_LOG_EVENT_UNFILTERED") or false
      local target = nearby and nearby.IsEventRegistered and nearby:IsEventRegistered("PLAYER_TARGET_CHANGED") or false
      local who = whoEvents and whoEvents.IsEventRegistered and whoEvents:IsEventRegistered("WHO_LIST_UPDATE") or false
      return self:SF151_InvasionRuntimeEnabled(), combat and true or false, target and true or false, who and true or false
    end

    local oldQueueWho = B.QueueInvasionWhoScan
    if oldQueueWho then
      function B:QueueInvasionWhoScan(...)
        if not self:SF151_InvasionRuntimeEnabled() then
          if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r Invasion scanning requires the Triumvirate profile with the Invasions module enabled.") end
          self:SF151_SyncInvasionRuntime()
          return false
        end
        local r = oldQueueWho(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldWhoUpdate = B.HandleInvasionWhoListUpdate
    if oldWhoUpdate then
      function B:HandleInvasionWhoListUpdate(...)
        if not self:SF151_InvasionRuntimeEnabled() then self:SF151_SyncInvasionRuntime(); return false end
        local r = oldWhoUpdate(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldWhoTick = B.InvasionWhoScanTick
    if oldWhoTick then
      function B:InvasionWhoScanTick(...)
        if not self:SF151_InvasionRuntimeEnabled() then self:SF151_SyncInvasionRuntime(); return end
        local wasActive = self.invasionWhoScan and self.invasionWhoScan.active
        local r = oldWhoTick(self, ...)
        local isActive = self.invasionWhoScan and self.invasionWhoScan.active
        if wasActive and not isActive then self:SF151_SyncInvasionRuntime() end
        return r
      end
    end

    local oldSendInv = B.SendInvasionPresence
    if oldSendInv then
      function B:SendInvasionPresence(...)
        if not self:SF151_InvasionRuntimeEnabled() then return false end
        return oldSendInv(self, ...)
      end
    end

    local oldHandleInv = B.HandleInvasionPresence
    if oldHandleInv then
      function B:HandleInvasionPresence(...)
        if not self:SF151_InvasionRuntimeEnabled() then return false end
        return oldHandleInv(self, ...)
      end
    end

    local oldRecordNearby = B.RecordInvasionNearbyUnit
    if oldRecordNearby then
      function B:RecordInvasionNearbyUnit(...)
        if not self:SF151_InvasionRuntimeEnabled() then return false end
        return oldRecordNearby(self, ...)
      end
    end

    local oldRecordCombat = B.RecordInvasionCombatLogPlayer
    if oldRecordCombat then
      function B:RecordInvasionCombatLogPlayer(...)
        if not self:SF151_InvasionRuntimeEnabled() then return false end
        return oldRecordCombat(self, ...)
      end
    end

    local oldShowInv = B.ShowInvasions
    if oldShowInv then
      function B:ShowInvasions(...)
        if not self:SF151_InvasionRuntimeEnabled() then
          self:SF151_SyncInvasionRuntime()
          if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r Invasions are available only on Triumvirate while the Invasions module is enabled.") end
          return false
        end
        return oldShowInv(self, ...)
      end
    end

    local oldProfileSet = B.SF143_SetServerProfile
    if oldProfileSet then
      function B:SF143_SetServerProfile(...)
        local r = oldProfileSet(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldModuleSet = B.SFModuleSetEnabled
    if oldModuleSet then
      function B:SFModuleSetEnabled(...)
        local r = oldModuleSet(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldModuleDefault = B.SFModuleUseProfileDefault
    if oldModuleDefault then
      function B:SFModuleUseProfileDefault(...)
        local r = oldModuleDefault(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldModulesApply = B.SFModulesApply
    if oldModulesApply then
      function B:SFModulesApply(...)
        local r = oldModulesApply(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local oldSaveOptions = B.SaveOptions
    if oldSaveOptions then
      function B:SaveOptions(...)
        local r = oldSaveOptions(self, ...)
        self:SF151_SyncInvasionRuntime()
        return r
      end
    end

    local phase2Frame = CreateFrame("Frame")
    phase2Frame:RegisterEvent("PLAYER_LOGIN")
    phase2Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    phase2Frame:SetScript("OnEvent", function()
      if B and B.SF151_SyncInvasionRuntime then B:SF151_SyncInvasionRuntime() end
    end)

    B:SF151_SyncInvasionRuntime()
  end
end
-- SignalFire 1.5.1 Phase 3i: deterministic links with explicit chat ownership.
do
  local B = _G.BronzeLFG
  if B and not B._sf151Phase3Installed then
    B._sf151Phase3Installed = true

    local P3 = _G.SignalFireChatRuntime151 or {}
    _G.SignalFireChatRuntime151 = P3
    P3.generation = "1.5.1-phase3k"

    local function p3_now()
      if GetTime then return GetTime() end
      if time then return time() end
      return 0
    end

    local function p3_epoch_now()
      if time then return time() end
      return p3_now()
    end

    local function p3_epoch_value(value)
      local stamp = tonumber(value or 0) or 0
      if stamp < 100000000 then return nil end
      return stamp
    end

    local function p3_repair_row_time(row, fallback)
      if not row then return end
      local stamp = p3_epoch_value(fallback) or p3_epoch_now()
      row.created = p3_epoch_value(row.created) or stamp
      row.firstSeen = p3_epoch_value(row.firstSeen) or row.created
      row.seen = p3_epoch_value(row.seen) or stamp
    end

    local function p3_trim(value)
      local s = tostring(value or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function p3_author(value)
      return p3_trim(tostring(value or ""):gsub("%-.*$", ""))
    end

    local function p3_norm(value)
      local s = string.lower(tostring(value or ""))
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
      s = string.gsub(s, "|h(%b[])|h", "%1")
      s = string.gsub(s, "%s+", " ")
      return p3_trim(s)
    end

    local function p3_options()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local o = BronzeLFG_DB.options
      if o.publicGroups == nil then o.publicGroups = true end
      if o.publicStrict == nil then o.publicStrict = true end
      if o.parseGuildRecruitment == nil then o.parseGuildRecruitment = true end
      if o.inlineChatLinks == nil then o.inlineChatLinks = true end
      -- Earlier stutter-safety builds could leave this hidden switch disabled
      -- while the visible "Build Public Groups From Chat" option remained on.
      -- Migrate that stale state once; later user changes are still respected.
      if o.sf151Phase3iLinkOptionMigrated ~= true then
        if o.publicGroups ~= false then o.inlineChatLinks = true end
        o.disableInlineChatLinks = nil
        o.chatLinkSafeMode = nil
        if tostring(o.chatLinksMode or ""):lower() == "off" then o.chatLinksMode = nil end
        if tostring(o.chatLinkMode or ""):lower() == "off" then o.chatLinkMode = nil end
        o.sf151Phase3iLinkOptionMigrated = true
      end
      -- Preserve the older all-frame migration marker for existing profiles;
      -- the visible-frame migration below supersedes its runtime scope.
      if o.sf151AllFrameLinksMigrated ~= true then
        o.chatLinkScope = "all"
        o.sf151AllFrameLinksMigrated = true
      elseif o.chatLinkScope ~= "main" and o.chatLinkScope ~= "all" and o.chatLinkScope ~= "visible" then
        o.chatLinkScope = "all"
      end
      -- Phase 3j limited links to visible frames, which left plain messages in
      -- hidden tab histories. Restore complete coverage once; the finished
      -- hyperlink is cached per listing below so every frame reuses it.
      if o.sf151VisibleFrameLinksMigrated ~= true then
        o.chatLinkScope = "visible"
        o.sf151VisibleFrameLinksMigrated = true
      end
      if o.sf151Phase3kAllFrameLinksMigrated ~= true then
        o.chatLinkScope = "all"
        o.sf151Phase3kAllFrameLinksMigrated = true
      end
      return o
    end

    local function p3_has_existing_link(raw)
      return string.find(raw, "|Hbronzelfg", 1, true)
        or string.find(raw, "bronzelfgpub:", 1, true)
        or string.find(raw, "bronzelfgguild:", 1, true)
    end

    local function p3_is_protocol(raw)
      return string.sub(raw, 1, 8) == "BLFG312~"
    end

    local function p3_has_external_noise(low)
      return string.find(low, "kick.com", 1, true)
        or string.find(low, "twitch.tv", 1, true)
        or string.find(low, "youtube.com", 1, true)
        or string.find(low, "youtu.be", 1, true)
        or string.find(low, "http://", 1, true)
        or string.find(low, "https://", 1, true)
        or string.find(low, "www.", 1, true)
    end

    local function p3_hash(value)
      local h = 5381
      local text = tostring(value or "")
      for i = 1, string.len(text) do h = (h * 33 + string.byte(text, i)) % 2147483647 end
      return tostring(h)
    end

    local function p3_key(author, text)
      return string.lower(p3_author(author)) .. "\031" .. p3_norm(text)
    end

    local function p3_public_key(author, text)
      if B.SignalFirePublicChatKey then return B:SignalFirePublicChatKey(author, text) end
      return p3_author(author) .. "\031" .. tostring(text or "")
    end

    local function p3_stats()
      B._sfP3Stats = B._sfP3Stats or {}
      local stats = B._sfP3Stats
      local fields = {
        "filterCalls", "wrapperCalls", "eligibleDisplayDecisions", "linksAppended",
        "alreadyLinkedSkips", "linksDisabledSkips", "enqueued", "deduped", "processed", "coreCalls",
        "parserCalls", "failedRenderedExtraction", "maxDepth", "decisionCacheHits",
        "decisionCacheMisses", "decisionNegativeHits", "testParseCalls", "testParseTimedCalls",
        "testParseMsTotal", "testParseMsMax", "hiddenFrameLinkSkips",
        "linkCacheHits", "linkCacheMisses",
      }
      for _, field in ipairs(fields) do
        if stats[field] == nil then stats[field] = 0 end
      end
      return stats
    end

    local function p3_diagnostics_enabled()
      return BronzeLFG_DB and BronzeLFG_DB.options
        and BronzeLFG_DB.options.developerDiagnostics == true
    end

    local function p3_note(field, amount)
      if not p3_diagnostics_enabled() then return nil end
      local stats = p3_stats()
      stats[field] = (stats[field] or 0) + (amount or 1)
      return stats
    end

    local function p3_frame_name(frame)
      if not frame then return "<nil>" end
      if frame.GetName then
        local ok, name = pcall(frame.GetName, frame)
        if ok and name and tostring(name) ~= "" then return tostring(name) end
      end
      return tostring(frame)
    end

    local function p3_frame_diag(frame)
      P3._frameDiagnostics = P3._frameDiagnostics or {}
      local name = p3_frame_name(frame)
      local diag = P3._frameDiagnostics[name]
      if not diag then
        diag = {name=name, filterCalls=0, wrapperCalls=0, eligible=0, rewritten=0}
        P3._frameDiagnostics[name] = diag
      end
      return diag
    end

    local function p3_depth()
      return #(B._sfP3Queue or {})
    end

    local function p3_parse(text)
      local o = p3_options()
      if o.publicGroups == false then return nil end
      local raw = p3_trim(text)
      if raw == "" or p3_is_protocol(raw) or p3_has_existing_link(raw) then return nil end

      local low = " " .. string.lower(raw) .. " "
      if p3_has_external_noise(low) and not string.find(low, "discord.gg", 1, true)
        and not string.find(low, "discord.com/invite", 1, true) then return nil end
      if string.find(low, " guild", 1, true) and B.SF151_IsGuildSeeking and B:SF151_IsGuildSeeking(raw) then return nil end

      local probe = _G.SignalFireFastChatLinks and _G.SignalFireFastChatLinks.TestParse
      if type(probe) ~= "function" then return nil end
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if stats then stats.testParseCalls = stats.testParseCalls + 1 end
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
      local ok, parsed = pcall(probe, raw)
      if stats and started and debugprofilestop then
        local elapsed = debugprofilestop() - started
        if elapsed < 0 then elapsed = 0 end
        stats.testParseTimedCalls = stats.testParseTimedCalls + 1
        stats.testParseMsTotal = stats.testParseMsTotal + elapsed
        if elapsed > stats.testParseMsMax then stats.testParseMsMax = elapsed end
      end
      if not ok or type(parsed) ~= "table" or parsed.eligible ~= true then return nil end
      if parsed.kind == "guild" and o.parseGuildRecruitment == false then return nil end
      if parsed.kind ~= "guild" and parsed.kind ~= "group" then return nil end
      return parsed
    end

    local function p3_make_preview(rec, parsed)
      if not rec or not parsed or parsed.kind ~= "group" then return nil end
      B.publicGroups = B.publicGroups or {}
      local stamp = p3_epoch_now()
      local id = "sf151-" .. p3_hash(p3_key(rec.author, rec.text))
      local row = B.publicGroups[id]
      if row and (string.lower(p3_author(row.player or row.author)) ~= string.lower(p3_author(rec.author))
        or p3_norm(row.rawMessage or row.message) ~= p3_norm(rec.text)) then
        id = id .. "-" .. p3_hash(tostring(rec.author or "") .. "\031" .. tostring(rec.text or ""))
        row = B.publicGroups[id]
      end
      local isNew = row == nil
      if not row then
        row = {}
        B.publicGroups[id] = row
      end

      row.id = id
      row.key = id
      row.player = p3_author(rec.author)
      row.message = tostring(rec.text or "")
      row.rawMessage = tostring(rec.text or "")
      row.channel = rec.channel or row.channel or "Public"
      row.type = parsed.type or row.type or "Dungeon"
      row.activity = parsed.activity or row.activity or "Group Listing"
      row.roles = parsed.roles or row.roles or ""
      row.intent = row.type == "LFG" and "Applicant" or "Recruiter"
      row.tags = row.tags or row.type
      row.score = tonumber(row.score or 80) or 80
      row.created = row.created or stamp
      row.firstSeen = row.firstSeen or row.created
      row.seen = stamp
      p3_repair_row_time(row, stamp)
      row.sessionOnly = true
      row.fastChatLink = nil
      row.sf151StableLink = true
      row.sf151Pending = true

      rec.stableId = id
      rec.resolvedId = id
      rec.previewRow = row
      rec.isNew = isNew
      B._lastPublicGroupTouched = row
      B._lastPublicGroupTouchedKey = id
      return row
    end

    local function p3_prune(stamp)
      stamp = stamp or p3_now()
      local scanned = 0
      for key, seen in pairs(B._sfP3Seen or {}) do
        scanned = scanned + 1
        if (stamp - (tonumber(seen or 0) or 0)) > 20 then B._sfP3Seen[key] = nil end
        if scanned > 240 then break end
      end
      scanned = 0
      for id, rec in pairs(B._sfP3Records or {}) do
        scanned = scanned + 1
        if not rec or (stamp - (tonumber(rec.time or 0) or 0)) > 300 then B._sfP3Records[id] = nil end
        if scanned > 240 then break end
      end
    end

    local function p3_enqueue(author, text, channel, parsed)
      local raw = tostring(text or "")
      parsed = parsed or p3_parse(raw)
      if not parsed then return nil end
      if p3_author(author) == p3_author(UnitName and UnitName("player") or "") and not B.SignalFireTestSay then return nil end

      local stamp = p3_now()
      local key = p3_key(author, raw)
      B._sfP3Seen = B._sfP3Seen or {}
      B._sfP3Records = B._sfP3Records or {}
      local id = "p3-" .. p3_hash(key)
      local existing = B._sfP3Records[id]
      local last = tonumber(B._sfP3Seen[key] or 0) or 0
      if existing and (stamp - last) <= 5 then
        p3_note("deduped")
        return existing
      end

      local rec = existing or {id=id}
      rec.author = author
      rec.text = raw
      rec.channel = channel or "Public"
      rec.kind = parsed.kind
      rec.parsed = parsed
      rec.guildName = parsed.guild
      rec.time = stamp
      rec.done = false
      rec.alerted = false
      rec.isNew = false
      if parsed.kind == "group" then p3_make_preview(rec, parsed) end

      B._sfP3Records[id] = rec
      B._sfP3Seen[key] = stamp
      B._sfP3Queue = B._sfP3Queue or {}
      while #B._sfP3Queue >= 40 do table.remove(B._sfP3Queue, 1) end
      table.insert(B._sfP3Queue, rec)
      P3._enqueueCount = (tonumber(P3._enqueueCount or 0) or 0) + 1
      local stats = p3_note("enqueued")
      local depth = p3_depth()
      if stats and depth > stats.maxDepth then stats.maxDepth = depth end

      B._inlinePublicChatEventSeen = B._inlinePublicChatEventSeen or {}
      B._inlinePublicChatEventSeen[p3_public_key(author, raw)] = stamp
      if B._sfP3Frame then B._sfP3Frame:Show() end
      if P3._enqueueCount % 25 == 0 then p3_prune(stamp) end
      return rec
    end

    local function p3_cache_decision(key, rec, stamp, ttl)
      if not key or key == "" then return end
      stamp = stamp or p3_now()
      P3._decisionCache = P3._decisionCache or {}
      P3._decisionSlots = P3._decisionSlots or {}
      P3._decisionCursor = ((tonumber(P3._decisionCursor or 0) or 0) % 256) + 1

      local old = P3._decisionSlots[P3._decisionCursor]
      if old then
        local current = P3._decisionCache[old.key]
        if current and current.stamp == old.stamp then P3._decisionCache[old.key] = nil end
      end

      local item = {rec=rec or false, stamp=stamp, expires=stamp + (ttl or 2)}
      P3._decisionCache[key] = item
      P3._decisionSlots[P3._decisionCursor] = {key=key, stamp=stamp}
    end

    local function p3_cached_decision(author, text)
      local key = p3_key(author, text)
      local item = P3._decisionCache and P3._decisionCache[key] or nil
      if not item then return nil, false, key end
      if p3_now() > (tonumber(item.expires or 0) or 0) then
        P3._decisionCache[key] = nil
        return nil, false, key
      end
      p3_note("decisionCacheHits")
      if item.rec == false then
        p3_note("decisionNegativeHits")
        return nil, true, key
      end
      return item.rec, true, key
    end

    -- Chat filters run once per receiving ChatFrame on Wrath clients. Cache the
    -- decision before classification so hidden tabs reuse both positive and
    -- negative results instead of invoking TestParse again.
    local function p3_resolve(author, text, channel)
      local cached, found, key = p3_cached_decision(author, text)
      if found then return cached end

      p3_note("decisionCacheMisses")
      local parsed = p3_parse(text)
      if not parsed then
        p3_cache_decision(key, nil, p3_now(), 2)
        return nil
      end

      local rec = p3_enqueue(author, text, channel, parsed)
      p3_cache_decision(key, rec, p3_now(), rec and 6 or 2)
      return rec
    end

    local function p3_copy_authoritative(dst, src)
      if not (dst and src) then return end
      local fields = {"player", "message", "rawMessage", "channel", "type", "activity", "roles", "intent", "tags", "ilevel", "score"}
      local function genericActivity(value)
        local v = tostring(value or "")
        return v == "" or v == "Group Listing" or v == "Looking For Group"
      end
      for _, field in ipairs(fields) do
        local value = src[field]
        local keepSpecific = field == "activity" and genericActivity(value) and not genericActivity(dst.activity)
        if value ~= nil and value ~= "" and not keepSpecific then dst[field] = value end
      end
      local dc = tonumber(dst.created or dst.firstSeen or 0) or 0
      local sc = tonumber(src.created or src.firstSeen or 0) or 0
      if dc <= 0 or (sc > 0 and sc < dc) then dst.created = sc; dst.firstSeen = sc end
      local ds = tonumber(dst.seen or 0) or 0
      local ss = tonumber(src.seen or 0) or 0
      if ss > ds then dst.seen = ss end
    end

    local function p3_consolidate(rec, coreResult)
      if not rec or rec.kind ~= "group" or not rec.stableId then return nil end
      B.publicGroups = B.publicGroups or {}
      local stable = B.publicGroups[rec.stableId]
      if not stable then
        stable = {id=rec.stableId, key=rec.stableId}
        B.publicGroups[rec.stableId] = stable
      end
      if type(coreResult) == "table" and coreResult ~= stable then p3_copy_authoritative(stable, coreResult) end

      local wantedAuthor = string.lower(p3_author(rec.author))
      local wantedText = p3_norm(rec.text)
      local remove = {}
      for id, row in pairs(B.publicGroups) do
        if row and id ~= rec.stableId
          and string.lower(p3_author(row.player or row.author)) == wantedAuthor
          and p3_norm(row.rawMessage or row.message) == wantedText then
          p3_copy_authoritative(stable, row)
          table.insert(remove, id)
        end
      end
      for _, id in ipairs(remove) do
        B.publicGroups[id] = nil
        if B.selectedPublic == id then B.selectedPublic = rec.stableId end
      end

      stable.id = rec.stableId
      stable.key = rec.stableId
      stable.sf151StableLink = true
      stable.sf151Pending = nil
      stable.fastChatLink = nil
      p3_repair_row_time(stable, p3_epoch_now())
      stable.seen = p3_epoch_now()
      rec.resolvedId = rec.stableId
      rec.previewRow = stable
      B._lastPublicGroupTouched = stable
      B._lastPublicGroupTouchedKey = rec.stableId
      if B.RequestPublicGroupsRefresh then B:RequestPublicGroupsRefresh() end
      return stable
    end

    local function p3_row_quality(row)
      if not row then return -1 end
      local score = tonumber(row.score or 0) or 0
      local activity = tostring(row.activity or "")
      if row.sf151StableLink then score = score + 1000 end
      if activity ~= "" and activity ~= "Group Listing" and activity ~= "Looking For Group" then score = score + 100 end
      if tostring(row.roles or "") ~= "" then score = score + 10 end
      score = score + math.min(tonumber(row.seen or row.created or 0) or 0, 9)
      return score
    end

    local function p3_dedupe_existing_public_groups()
      B.publicGroups = B.publicGroups or {}
      local winners, remove = {}, {}
      for id, row in pairs(B.publicGroups) do
        if row then
          p3_repair_row_time(row, p3_epoch_now())
          local author = string.lower(p3_author(row.player or row.author))
          local message = p3_norm(row.rawMessage or row.message)
          if author ~= "" and message ~= "" then
            local key = author .. "\031" .. message
            local current = winners[key]
            if not current then
              winners[key] = {id=id, row=row}
            else
              local winner, loser = current, {id=id, row=row}
              if p3_row_quality(loser.row) > p3_row_quality(winner.row) then
                winner, loser = loser, winner
                winners[key] = winner
              end
              p3_copy_authoritative(winner.row, loser.row)
              table.insert(remove, {id=loser.id, keep=winner.id})
            end
          end
        end
      end
      for _, item in ipairs(remove) do
        B.publicGroups[item.id] = nil
        if B.selectedPublic == item.id then B.selectedPublic = item.keep end
      end
      return #remove
    end

    local function p3_process(rec)
      if not rec or rec.done then return end
      rec.done = true
      local core = B._sfP3CoreAddPublicGroup
      local result = nil
      B._sfChatQueueProcessing = true
      B._suppressPublicRefreshInChatLink = true
      B._sfP3SuppressNotify = true
      if core then
        p3_note("coreCalls")
        p3_note("parserCalls")
        local ok, value = pcall(core, B, rec.author, rec.text, rec.channel)
        if ok then result = value end
      end
      B._sfP3SuppressNotify = nil
      B._suppressPublicRefreshInChatLink = nil
      B._sfChatQueueProcessing = nil

      if rec.kind == "group" then
        local row = p3_consolidate(rec, result)
        if rec.isNew and row and not rec.alerted and B.NotifyForPublicGroup then
          rec.alerted = true
          pcall(B.NotifyForPublicGroup, B, row)
        end
      elseif rec.kind == "guild" and rec.guildName and B.UpsertGuildBrowserChatListing then
        pcall(B.UpsertGuildBrowserChatListing, B, rec.guildName, rec.author, rec.text)
      end
      p3_note("processed")
    end

    local function p3_next()
      local queue = B._sfP3Queue or {}
      if not queue[1] then return nil end
      return table.remove(queue, 1)
    end

    local function p3_each_chat_frame(callback)
      local seen = {}
      local function add(frame)
        if frame and type(frame.AddMessage) == "function" and not seen[frame] then
          seen[frame] = true
          callback(frame)
        end
      end

      for _, name in ipairs(_G.CHAT_FRAMES or {}) do add(_G[name]) end
      local n = tonumber(NUM_CHAT_WINDOWS or 0) or 0
      for i = 1, math.max(n, 10) do add(_G["ChatFrame" .. tostring(i)]) end
      add(DEFAULT_CHAT_FRAME)
      add(_G.SELECTED_CHAT_FRAME)
      if _G.GENERAL_CHAT_DOCK then add(_G.GENERAL_CHAT_DOCK.primary) end
      if FCF_GetCurrentChatFrame then
        local ok, current = pcall(FCF_GetCurrentChatFrame)
        if ok then add(current) end
      end
    end

    local function p3_links_enabled()
      local o = p3_options()
      return o.publicGroups ~= false and o.inlineChatLinks ~= false
    end

    local function p3_frame_is_visible(frame)
      if not frame or not frame.IsShown then return true end
      local ok, shown = pcall(frame.IsShown, frame)
      if not ok then return true end
      return shown and true or false
    end

    local function p3_frame_allowed(frame)
      local scope = tostring(p3_options().chatLinkScope or "all")
      if scope == "all" then return true end
      if scope == "main" then
        return not frame or frame == DEFAULT_CHAT_FRAME or frame == _G.ChatFrame1
      end
      return p3_frame_is_visible(frame)
    end

    local function p3_render(rec, raw)
      if not rec then return raw end
      if rec.kind == "guild" then
        local guild = tostring(rec.guildName or "")
        if guild == "" then return raw end
        if B.InsertGuildLinkInText then
          local ok, out = pcall(B.InsertGuildLinkInText, B, raw, guild)
          if ok and out and out ~= "" and out ~= raw then return out end
        end
        local link = B.GuildChatLink and B:GuildChatLink(guild) or nil
        return link and (raw .. " " .. link) or raw
      end
      local row = rec.stableId and B.publicGroups and B.publicGroups[rec.stableId] or rec.previewRow
      if not row and rec.kind == "group" and rec.parsed then row = p3_make_preview(rec, rec.parsed) end
      if row and rec.stableId and not row.id then row.id = rec.stableId end

      local link = nil
      if row then
        local signature = table.concat({
          tostring(row.id or ""), tostring(row.type or ""), tostring(row.activity or ""),
          tostring(row.roles or ""), tostring(row.difficulty or ""),
        }, "\031")
        if rec._sfP3CachedLinkSignature == signature and rec._sfP3CachedLink then
          link = rec._sfP3CachedLink
          p3_note("linkCacheHits")
        else
          p3_note("linkCacheMisses")
          if B.PublicChatLink then
            local ok, value = pcall(B.PublicChatLink, B, row)
            if ok then link = value end
          end
          -- The stable row ID is the actual hyperlink contract. Keep a direct
          -- fallback so a replaced/legacy PublicChatLink method cannot suppress
          -- a valid display decision.
          if not link and row.id then
            local title = tostring(row.activity or (rec.parsed and rec.parsed.activity) or "")
            if B.PublicLinkTitle then
              local ok, value = pcall(B.PublicLinkTitle, B, row)
              if ok and value and tostring(value) ~= "" then title = tostring(value) end
            end
            title = string.gsub(title, "|", "")
            title = string.gsub(title, "%[", "(")
            title = string.gsub(title, "%]", ")")
            if title ~= "" then
              link = "|cffd4a017|Hbronzelfgpub:" .. tostring(row.id) .. "|h[" .. title .. "]|h|r"
            end
          end
          if link then
            rec._sfP3CachedLinkSignature = signature
            rec._sfP3CachedLink = link
          end
        end
      end
      return link and (raw .. " " .. link) or raw
    end

    function P3.Filter(frame, event, msgText, author, ...)
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if stats then stats.filterCalls = stats.filterCalls + 1 end
      local diag = p3_frame_diag(frame)
      if diagnostics then
        diag.filterCalls = (diag.filterCalls or 0) + 1
        diag.lastFilterEvent = event
        diag.lastFilterText = tostring(msgText or "")
      end
      local isTestSay = B.SignalFireTestSay and (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL")
      if (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") and not isTestSay then
        return false, msgText, author, ...
      end
      local raw = tostring(msgText or "")
      diag.lastFilterKey = p3_norm(raw)
      diag.lastFilterAt = p3_now()

      local channel = event
      if event == "CHAT_MSG_CHANNEL" then
        channel = tostring(select(8, ...) or select(7, ...) or "Channel")
      elseif event == "CHAT_MSG_SAY" then
        channel = "Say"
      elseif event == "CHAT_MSG_YELL" then
        channel = "Yell"
      end
      local rec = p3_resolve(author, raw, channel)
      diag.lastFilterWasEligible = rec ~= nil
      diag.lastFilterRec = rec
      if not rec then return false, msgText, author, ... end

      if stats then stats.eligibleDisplayDecisions = stats.eligibleDisplayDecisions + 1 end
      if diagnostics then
        diag.eligible = (diag.eligible or 0) + 1
        diag.lastEligibleText = raw
        diag.lastFilterSawEligible = true
      end
      if not p3_links_enabled() then
        if stats then stats.linksDisabledSkips = stats.linksDisabledSkips + 1 end
        return false, msgText, author, ...
      end
      if not p3_frame_allowed(frame) then
        if stats then stats.hiddenFrameLinkSkips = stats.hiddenFrameLinkSkips + 1 end
        if diagnostics then diag.lastFilterRewritten = false end
        return false, msgText, author, ...
      end

      local out = p3_render(rec, raw)
      if out and out ~= raw then
        if stats then stats.linksAppended = stats.linksAppended + 1 end
        if diagnostics then
          diag.rewritten = (diag.rewritten or 0) + 1
          diag.lastFilterRewritten = true
        end
        return false, out, author, ...
      end
      if diagnostics then diag.lastFilterRewritten = false end
      return false, msgText, author, ...
    end

    local function p3_remove_filter(event, fn)
      if ChatFrame_RemoveMessageEventFilter and type(fn) == "function" then
        pcall(ChatFrame_RemoveMessageEventFilter, event, fn)
      end
    end

    P3.PassiveFilter = P3.PassiveFilter or function(frame, event, msgText, author, ...)
      return false, msgText, author, ...
    end

    local function p3_restore_chat_frames()
      p3_each_chat_frame(function(frame)
        local base = frame._sffclOldAddMessage or frame._sfcpBaseAddMessage
        -- Only unwind a legacy wrapper when it still owns the method. Phase 3g
        -- restored this stale base unconditionally, clobbering later chat addons
        -- and its own newer wrapper during every reconciliation pass.
        if frame.AddMessage == frame._sffclAddMessageHook and base then frame.AddMessage = base end
        frame._sffclAddMessageHook = nil
      end)
    end

    -- Some custom 3.3.5 chat UIs discard the rewritten value returned by
    -- ChatFrame_AddMessageEventFilter and later render the original line through
    -- AddMessage. Inspect the line that is actually being rendered, classify it
    -- with the same side-effect-free lightweight parser, and append the real
    -- activity/guild link. Heavy parsing remains deduplicated in p3_enqueue().
    local function p3_display_plain(value)
      local text = tostring(value or "")
      text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
      text = string.gsub(text, "|r", "")
      text = string.gsub(text, "|T.-|t", "")
      text = string.gsub(text, "|A.-|a", "")
      text = string.gsub(text, "|H[^|]+|h(.-)|h", "%1")
      return p3_trim(text)
    end

    local function p3_display_parts(value, prepared)
      local clean = prepared or p3_display_plain(value)
      if clean == "" then return "", "", "" end
      if string.find(clean, "SignalFire>", 1, true)
        or string.find(clean, "SignalFire:", 1, true)
        or string.find(clean, "SignalFire Alert:", 1, true) then
        return "", "", ""
      end

      -- Channel lines, with or without a timestamp prefix:
      -- [3. Newcomers] [Player]: message
      local channel, author, body = string.match(clean, "^.-%[([^%]]+)%]%s*%[([^%]]+)%]:%s*(.+)$")
      if body then return p3_author(author), p3_trim(body), p3_trim(channel) end

      -- Say/yell lines used by Blizzard and custom chat replacements.
      author, body = string.match(clean, "^.-%[([^%]]+)%]%s+says:%s*(.+)$")
      if body then return p3_author(author), p3_trim(body), "Say" end
      author, body = string.match(clean, "^.-%[([^%]]+)%]%s+yells:%s*(.+)$")
      if body then return p3_author(author), p3_trim(body), "Yell" end
      author, body = string.match(clean, "^.-([^:%[%]]-)%s+says:%s*(.+)$")
      if body then return p3_author(author), p3_trim(body), "Say" end
      author, body = string.match(clean, "^.-([^:%[%]]-)%s+yells:%s*(.+)$")
      if body then return p3_author(author), p3_trim(body), "Yell" end

      -- Last-resort custom-frame format: Player: message. Do not treat URLs as
      -- authors and require a non-empty, reasonably short author field.
      author, body = string.match(clean, "^([^:]-):%s*(.+)$")
      author = p3_trim(author)
      if body and author ~= "" and string.len(author) <= 64
        and not string.find(author, "://", 1, true) then
        return p3_author(author), p3_trim(body), "Chat"
      end
      return "", "", ""
    end

    local function p3_rewrite_rendered_message(frame, value)
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if stats then stats.wrapperCalls = stats.wrapperCalls + 1 end
      local diag = p3_frame_diag(frame)
      if diagnostics then
        diag.wrapperCalls = (diag.wrapperCalls or 0) + 1
        diag.lastWrapperText = tostring(value or "")
      end
      local displayed = tostring(value or "")
      if displayed == "" then return value end
      if p3_has_existing_link(displayed) then
        if stats then stats.alreadyLinkedSkips = stats.alreadyLinkedSkips + 1 end
        if diagnostics then diag.lastAlreadyLinked = true end
        return value
      end
      if not p3_links_enabled() then
        if stats then stats.linksDisabledSkips = stats.linksDisabledSkips + 1 end
        return value
      end
      if not p3_frame_allowed(frame) then
        if stats then stats.hiddenFrameLinkSkips = stats.hiddenFrameLinkSkips + 1 end
        return value
      end

      local plain = p3_display_plain(displayed)
      if string.find(plain, "SignalFire>", 1, true)
        or string.find(plain, "SignalFire:", 1, true)
        or string.find(plain, "SignalFire Alert:", 1, true) then return value end

      local rec = nil
      local renderedKey = p3_norm(displayed)
      local filterAge = p3_now() - (tonumber(diag.lastFilterAt or 0) or 0)
      local sameFilterLine = filterAge <= 1 and tostring(diag.lastFilterKey or "") ~= ""
        and string.find(renderedKey, tostring(diag.lastFilterKey), 1, true) ~= nil
      if sameFilterLine then
        rec = diag.lastFilterRec
        if not rec and diag.lastFilterWasEligible == false then
          if diagnostics then diag.lastWrapperRewritten = false end
          return value
        end
      end

      local author, body, channel = "", "", ""
      if not rec then author, body, channel = p3_display_parts(displayed, plain) end
      if not rec and author ~= "" and body ~= "" then rec = p3_resolve(author, body, channel) end
      if not rec then
        if author == "" or body == "" then
          if stats then stats.failedRenderedExtraction = stats.failedRenderedExtraction + 1 end
          if diagnostics then diag.failedExtraction = (diag.failedExtraction or 0) + 1 end
        end
        if diagnostics then diag.lastWrapperRewritten = false end
        return value
      end

      if stats then stats.eligibleDisplayDecisions = stats.eligibleDisplayDecisions + 1 end
      if diagnostics then
        diag.eligible = (diag.eligible or 0) + 1
        diag.lastEligibleText = tostring(rec.text or body or "")
      end
      local out = p3_render(rec, displayed)
      if out and out ~= displayed then
        if stats then stats.linksAppended = stats.linksAppended + 1 end
        if diagnostics then
          diag.rewritten = (diag.rewritten or 0) + 1
          diag.lastWrapperRewritten = true
        end
        return out
      end
      if diagnostics then diag.lastWrapperRewritten = false end
      return value
    end

    local function p3_hook_custom_chat_frame(frame)
      if not (frame and type(frame.AddMessage) == "function") then return end
      local diag = p3_frame_diag(frame)
      if frame._sfP3CustomAddMessageHook and frame.AddMessage == frame._sfP3CustomAddMessageHook then
        diag.wrapperInstalled = true
        diag.wrapperGeneration = P3.generation
        return
      end
      if frame._sfP3CustomAddMessageHook and frame.AddMessage ~= frame._sfP3CustomAddMessageHook then
        diag.replacements = (diag.replacements or 0) + 1
        diag.lastReplacementDetected = p3_now()
      end
      local base = frame.AddMessage
      frame._sfP3CustomBaseAddMessage = base
      frame._sfP3CustomAddMessageHook = function(self, text, ...)
        return base(self, p3_rewrite_rendered_message(self, text), ...)
      end
      frame.AddMessage = frame._sfP3CustomAddMessageHook
      frame._sfP3WrapperGeneration = P3.generation
      diag.wrapperInstalled = true
      diag.wrapperGeneration = P3.generation
      diag.installedAt = p3_now()
    end

    local function p3_hook_custom_chat_frames()
      p3_each_chat_frame(p3_hook_custom_chat_frame)
    end

    local function p3_remember_filter(fn)
      if type(fn) ~= "function" then return end
      P3._legacyFilters = P3._legacyFilters or {}
      for _, old in ipairs(P3._legacyFilters) do if old == fn then return end end
      table.insert(P3._legacyFilters, fn)
    end

    local function p3_disable_old_runtime()
      if B._sfChatParseFrame then
        B._sfChatParseFrame:SetScript("OnUpdate", nil)
        B._sfChatParseFrame:Hide()
      end
      B._sfChatParseQueue = {}
      B._sfChatParseSeen = {}

      p3_remember_filter(_G.BLFG_PublicInlineFilter_561)
      p3_remember_filter(_G.SF577_RoleComboInlineFilter)
      p3_remember_filter(_G.SignalFireFastChatLinks and _G.SignalFireFastChatLinks.Filter)
      p3_remember_filter(_G.SignalFireChatParsingControls and _G.SignalFireChatParsingControls.Filter)
      p3_remember_filter(P3.PassiveFilter)
      for _, event in ipairs({"CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL"}) do
        for _, fn in ipairs(P3._legacyFilters or {}) do p3_remove_filter(event, fn) end
      end

      if _G.SignalFireFastChatLinks then _G.SignalFireFastChatLinks.Filter = P3.PassiveFilter end
      if _G.SignalFireChatParsingControls then _G.SignalFireChatParsingControls.Filter = P3.PassiveFilter end
      _G.BLFG_PublicInlineFilter_561 = P3.PassiveFilter
      _G.SF577_RoleComboInlineFilter = P3.PassiveFilter
      p3_restore_chat_frames()
    end

    local function p3_add_filter()
      if not ChatFrame_AddMessageEventFilter then return end
      -- Reconcile ownership instead of trusting a one-time boolean. Options and
      -- late chat addons can legitimately rebuild the filter chain after login.
      if ChatFrame_RemoveMessageEventFilter then
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_CHANNEL", P3.Filter)
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_SAY", P3.Filter)
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_YELL", P3.Filter)
      elseif P3._filterInstalled then
        return
      end
      ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", P3.Filter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", P3.Filter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", P3.Filter)
      P3._filterInstalled = true
      P3._filterInstalledAt = p3_now()
    end

    B._sfP3CoreAddPublicGroup = B._sfChatQueueOldAddPublicGroup or B.AddPublicGroup

    if not P3._notifyWrapped then
      P3._notifyWrapped = true
      P3._oldNotify = B.NotifyForPublicGroup
      function B:NotifyForPublicGroup(row)
        if self._sfP3SuppressNotify then return end
        return P3._oldNotify and P3._oldNotify(self, row) or nil
      end
    end

    local function p3_add_public(self, author, text, channel)
      if self._sfP3Processing then
        local core = self._sfP3CoreAddPublicGroup
        return core and core(self, author, text, channel) or nil
      end
      p3_resolve(author, text, channel)
      return nil
    end

    local function p3_inline(self, text, author, channel)
      p3_resolve(author, text, channel)
      -- Rendering is owned by the Phase 3h filter/fallback pair. Returning text
      -- here lets historical paths append a second link, so this must stay nil.
      return nil
    end

    function P3.Apply()
      p3_disable_old_runtime()
      B.AddPublicGroup = p3_add_public
      B.InlinePublicChatLinkForMessage = p3_inline
      p3_add_filter()
      p3_hook_custom_chat_frames()
      if not B._sfP3CanonicalDedupeDone then
        B._sfP3CanonicalDedupeDone = true
        p3_dedupe_existing_public_groups()
      end
    end

    B._sfP3Frame = B._sfP3Frame or (CreateFrame and CreateFrame("Frame") or nil)
    if B._sfP3Frame then
      B._sfP3Frame:Hide()
      B._sfP3Frame.elapsed = 0
      B._sfP3Frame:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
        if frame.elapsed < 0.06 then return end
        frame.elapsed = 0
        local rec = p3_next()
        if not rec then frame:Hide(); return end
        p3_process(rec)
        if p3_depth() <= 0 then frame:Hide() end
      end)
    end

    function B:SF151_GetChatRuntimeStatus()
      local stats = p3_stats()
      return p3_depth(), stats.enqueued or 0, stats.processed or 0, stats.deduped or 0, stats.coreCalls or 0, stats.maxDepth or 0
    end

    function B:SF151_SetDeveloperDiagnostics(enabled)
      local options = p3_options()
      options.developerDiagnostics = enabled == true
      self._sfP3Stats = {}
      P3._frameDiagnostics = {}
      p3_stats()
      return options.developerDiagnostics
    end

    function B:SF151_GetDeveloperDiagnostics()
      return p3_diagnostics_enabled()
    end

    function B:SF151_ResetChatRuntimeStats()
      self._sfP3Stats = {}
      P3._frameDiagnostics = {}
      p3_stats()
      return true
    end

    function B:SF151_GetChatFrameDiagnostics()
      local options = p3_options()
      local result = {
        generation=P3.generation,
        developerDiagnostics=p3_diagnostics_enabled(),
        filterInstalled=P3._filterInstalled == true,
        filterInstalledAt=P3._filterInstalledAt,
        linksEnabled=p3_links_enabled(),
        publicGroupsEnabled=options.publicGroups ~= false,
        inlineChatLinksEnabled=options.inlineChatLinks ~= false,
        chatLinkScope=options.chatLinkScope,
        queueDepth=p3_depth(),
        counters={},
        frames={},
      }
      for key, value in pairs(p3_stats()) do result.counters[key] = value end
      result.counters.heavyJobsQueued = result.counters.enqueued or 0
      result.counters.heavyJobsDeduplicated = result.counters.deduped or 0

      p3_each_chat_frame(function(frame)
        local diag = p3_frame_diag(frame)
        local item = {}
        for key, value in pairs(diag) do item[key] = value end
        item.visible = not frame.IsShown or frame:IsShown()
        item.signalFireWrapperInstalled = frame.AddMessage == frame._sfP3CustomAddMessageHook
        item.anotherFunctionReplacedIt = frame._sfP3CustomAddMessageHook ~= nil and not item.signalFireWrapperInstalled
        item.wrapperGeneration = frame._sfP3WrapperGeneration
        item.currentAddMessage = tostring(frame.AddMessage)
        item.signalFireAddMessage = tostring(frame._sfP3CustomAddMessageHook)
        table.insert(result.frames, item)
      end)
      table.sort(result.frames, function(a, b) return tostring(a.name) < tostring(b.name) end)
      return result
    end

    function B:SF151_PrintChatFrameDiagnostics()
      local report = self:SF151_GetChatFrameDiagnostics()
      local stats = report.counters or {}
      local function emit(text)
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text)) end
      end
      emit("chat owner " .. tostring(report.generation) .. ", queue=" .. tostring(report.queueDepth)
        .. ", filter=" .. tostring(report.filterInstalled) .. ", links=" .. tostring(report.linksEnabled)
        .. ", public=" .. tostring(report.publicGroupsEnabled) .. ", inline=" .. tostring(report.inlineChatLinksEnabled)
        .. ", scope=" .. tostring(report.chatLinkScope)
        .. ", diagnostics=" .. tostring(report.developerDiagnostics))
      emit("filter=" .. tostring(stats.filterCalls or 0) .. ", wrapper=" .. tostring(stats.wrapperCalls or 0)
        .. ", eligible=" .. tostring(stats.eligibleDisplayDecisions or 0) .. ", linked=" .. tostring(stats.linksAppended or 0)
        .. ", queued=" .. tostring(stats.heavyJobsQueued or 0) .. ", deduped=" .. tostring(stats.heavyJobsDeduplicated or 0)
        .. ", parsed=" .. tostring(stats.parserCalls or 0) .. ", extractFail=" .. tostring(stats.failedRenderedExtraction or 0))
      local timed = tonumber(stats.testParseTimedCalls or 0) or 0
      local average = timed > 0 and ((tonumber(stats.testParseMsTotal or 0) or 0) / timed) or 0
      emit("decisionCache=" .. tostring(stats.decisionCacheHits or 0) .. "/" .. tostring(stats.decisionCacheMisses or 0)
        .. ", negativeHits=" .. tostring(stats.decisionNegativeHits or 0)
        .. ", testParse=" .. tostring(stats.testParseCalls or 0)
        .. ", avgMs=" .. string.format("%.3f", average)
        .. ", maxMs=" .. string.format("%.3f", tonumber(stats.testParseMsMax or 0) or 0)
        .. ", hiddenLinkSkips=" .. tostring(stats.hiddenFrameLinkSkips or 0)
        .. ", linkCache=" .. tostring(stats.linkCacheHits or 0) .. "/" .. tostring(stats.linkCacheMisses or 0))
      for _, item in ipairs(report.frames or {}) do
        emit(tostring(item.name) .. ": visible=" .. tostring(item.visible)
          .. ", owner=" .. tostring(item.signalFireWrapperInstalled)
          .. ", replaced=" .. tostring(item.anotherFunctionReplacedIt)
          .. ", filterSeen=" .. tostring(item.filterCalls or 0)
          .. ", wrapperSeen=" .. tostring(item.wrapperCalls or 0)
          .. ", rewritten=" .. tostring(item.rewritten or 0))
      end
      return report
    end

    function B:SF151_DedupePublicGroups()
      return p3_dedupe_existing_public_groups()
    end

    if _G.SignalFireChatParsingControls and not P3._wrappedApplyRuntime then
      P3._wrappedApplyRuntime = true
      local oldApply = _G.SignalFireChatParsingControls.ApplyRuntime
      _G.SignalFireChatParsingControls.ApplyRuntime = function(...)
        local result = oldApply and oldApply(...)
        P3.Apply()
        return result
      end
      local oldMethod = B.SFCP_ApplyRuntime
      function B:SFCP_ApplyRuntime(...)
        local result = oldMethod and oldMethod(self, ...)
        P3.Apply()
        return result
      end
    end

    local startup = CreateFrame and CreateFrame("Frame") or nil
    if startup then
      startup.elapsed = 0
      startup.ticks = 0
      local function settle(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < 0.5 then return end
        self.elapsed = 0
        self.ticks = (self.ticks or 0) + 1
        P3.Apply()
        if self.ticks >= 8 then self:SetScript("OnUpdate", nil) end
      end
      local function schedule()
        P3.Apply()
        startup.elapsed = 0
        startup.ticks = 0
        startup:SetScript("OnUpdate", settle)
      end
      P3.ScheduleReconcile = schedule

      for _, event in ipairs({
        "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD",
        "UPDATE_CHAT_WINDOWS", "UPDATE_FLOATING_CHAT_WINDOWS",
        "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
      }) do
        pcall(startup.RegisterEvent, startup, event)
      end
      startup:SetScript("OnEvent", schedule)

      if hooksecurefunc then
        for _, functionName in ipairs({
          "FCF_OpenNewWindow", "FCF_Close", "FCF_DockFrame", "FCF_UnDockFrame",
          "FCF_SetWindowName", "FCF_ResetChatWindows",
        }) do
          if type(_G[functionName]) == "function" then
            pcall(hooksecurefunc, functionName, schedule)
          end
        end
      end

      schedule()
    end

    if not startup then P3.Apply() end
  end
end

if _G.SignalFireRefresh151 and _G.SignalFireRefresh151.InstallFinalOwners then
  _G.SignalFireRefresh151.InstallFinalOwners()
end

-- Phase 5: event-driven UI animation and bounded slow maintenance.
do
  local B = _G.BronzeLFG
  if B and CreateFrame then
    local T = _G.SignalFireTimer151 or {}
    _G.SignalFireTimer151 = T
    T.generation = "1.5.1-phase5"
    T.stats = T.stats or {}

    local function p5_now()
      return (GetTime and GetTime()) or 0
    end

    local function p5_epoch()
      return (time and time()) or 0
    end

    local function p5_reset_visuals()
      if B.applicantsButton then
        B.applicantsButton:SetBackdropColor(0, 0, 0, .82)
        B.applicantsButton:SetBackdropBorderColor(.85, .62, .12, .95)
      end
      if B.applicantsButtonTitle then B.applicantsButtonTitle:SetTextColor(1, .92, .68) end
      if B.badge then B.badge:Hide() end
      if B.mm then B.mm:SetAlpha(1) end
      if B.mm and B.mm.icon then B.mm.icon:SetVertexColor(1, 1, 1, 1) end
      if B.mm and B.mm.border then B.mm.border:SetVertexColor(1, 1, 1, 1) end
    end

    local function p5_update_minimap_drag()
      local mm = B.mm
      if not mm or not mm.dragging or not Minimap or not GetCursorPosition or not UIParent then return false end
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      if not mx or not my or not px or not py or not scale or scale == 0 then return false end
      px = px / scale
      py = py / scale
      B.minimapAngle = ((math.deg(math.atan2(py - my, px - mx)) % 360) + 360) % 360
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.minimap = BronzeLFG_DB.minimap or {}
      BronzeLFG_DB.minimap.angle = B.minimapAngle
      BronzeLFG_DB.minimapAngle = B.minimapAngle
      if B.UpdateMinimap then B:UpdateMinimap() end
      return true
    end

    local function p5_animate_alert()
      if not B.newApplicantAlert then return false end
      local a = (math.sin(p5_now() * 6) + 1) / 2
      if B.applicantsButton then
        B.applicantsButton:SetBackdropColor(.35 + (.35 * a), .12 + (.20 * a), .02, .98)
        B.applicantsButton:SetBackdropBorderColor(1, .82, .18, 1)
      end
      if B.applicantsButtonTitle then B.applicantsButtonTitle:SetTextColor(1, .35 + (.65 * a), .15) end
      if B.badge then
        B.badge:Show()
        B.badge:SetBackdropColor(.55 + (.35 * a), .05, .05, .98)
        B.badge:SetBackdropBorderColor(1, .9, .25, 1)
      end
      if B.mm then B.mm:SetAlpha(.65 + (.35 * a)) end
      if B.mm and B.mm.icon then B.mm.icon:SetVertexColor(1, .35 + (.65 * a), .15, 1) end
      if B.mm and B.mm.border then B.mm.border:SetVertexColor(1, .75 + (.25 * a), .15, 1) end
      return true
    end

    T.pulseFrame = T.pulseFrame or CreateFrame("Frame")
    T.pulseFrame:Hide()
    T.pulseFrame.elapsed = 0
    T.pulseFrame:SetScript("OnUpdate", function(self, elapsed)
      local dragging = p5_update_minimap_drag()
      self.elapsed = (self.elapsed or 0) + (elapsed or 0)
      if B.newApplicantAlert and self.elapsed >= .05 then
        self.elapsed = 0
        p5_animate_alert()
      end
      if not dragging and not B.newApplicantAlert then
        p5_reset_visuals()
        self:Hide()
        T.stats.pulseStops = (T.stats.pulseStops or 0) + 1
      end
    end)

    function T.WakePulse()
      if not T.pulseFrame:IsShown() then
        T.pulseFrame.elapsed = 0
        T.pulseFrame:Show()
        T.stats.pulseStarts = (T.stats.pulseStarts or 0) + 1
      end
    end

    function T.ApplyApplicantOwner()
      if B.applicantsButton then B.applicantsButton:SetScript("OnUpdate", nil) end
      if B.newApplicantAlert then T.WakePulse() else p5_reset_visuals() end
    end

    function T.ApplyMinimapOwner()
      local mm = B.mm
      if not mm then return end
      mm:SetScript("OnUpdate", nil)
      if mm._sfP5DragOwner then return end
      mm._sfP5DragOwner = true
      local oldStart = mm:GetScript("OnDragStart")
      local oldStop = mm:GetScript("OnDragStop")
      mm:SetScript("OnDragStart", function(self, ...)
        if oldStart then oldStart(self, ...) end
        if self.dragging then T.WakePulse() end
      end)
      mm:SetScript("OnDragStop", function(self, ...)
        if oldStop then oldStop(self, ...) end
        if not B.newApplicantAlert then
          p5_reset_visuals()
          T.pulseFrame:Hide()
        end
      end)
    end

    local oldBuildSide = B.BuildSide
    function B:BuildSide(...)
      local result = oldBuildSide and oldBuildSide(self, ...)
      T.ApplyApplicantOwner()
      return result
    end

    local oldBuildMinimap = B.BuildMinimap
    function B:BuildMinimap(...)
      local result = oldBuildMinimap and oldBuildMinimap(self, ...)
      T.ApplyMinimapOwner()
      return result
    end

    local oldSetApplicantAlert = B.SetApplicantAlert
    function B:SetApplicantAlert(active, ...)
      local result = oldSetApplicantAlert and oldSetApplicantAlert(self, active, ...)
      self.newApplicantAlert = active and true or false
      if self.newApplicantAlert then T.WakePulse() else p5_reset_visuals() end
      return result
    end

    local function p5_prune_timestamps(values, cutoff)
      if type(values) ~= "table" then return 0 end
      local removed = 0
      for key, stamp in pairs(values) do
        if tonumber(stamp) and tonumber(stamp) < cutoff then
          values[key] = nil
          removed = removed + 1
        end
      end
      return removed
    end

    local function p5_cap_table(values, trigger, keep)
      if type(values) ~= "table" then return 0 end
      local count = 0
      for _ in pairs(values) do count = count + 1 end
      if count <= trigger then return 0 end
      local removed = 0
      for key in pairs(values) do
        if count <= keep then break end
        values[key] = nil
        count = count - 1
        removed = removed + 1
      end
      return removed
    end

    local function p5_prune_event_state(network)
      if type(network) ~= "table" or type(network.events) ~= "table" then return 0 end
      local active = {}
      for _, row in ipairs(network.events) do
        local id = tostring((row and row.id) or "")
        if id ~= "" then active[id] = true end
      end
      local removed = 0
      for _, name in ipairs({"eventAlertSeen", "eventAlertKnown", "eventAlertCooldowns", "eventDismissed"}) do
        local values = network[name]
        if type(values) == "table" then
          for key in pairs(values) do
            if not active[tostring(key)] then
              values[key] = nil
              removed = removed + 1
            end
          end
        end
      end
      return removed
    end

    function B:SF151_RunSlowMaintenance()
      local now = p5_now()
      if T.lastMaintenance and (now - T.lastMaintenance) < 30 then return false end
      T.lastMaintenance = now
      T.stats.maintenanceRuns = (T.stats.maintenanceRuns or 0) + 1

      local removed = 0
      removed = removed + p5_cap_table(self.sfamSeenPublic, 512, 256)
      removed = removed + p5_cap_table(self.sfamSeenApplicants, 512, 256)

      local epoch = p5_epoch()
      local favorite = BronzeLFG_DB and BronzeLFG_DB.network or nil
      if favorite then
        removed = removed + p5_prune_timestamps(favorite.favoriteAlertCooldowns, epoch - 7200)
        removed = removed + p5_prune_timestamps(favorite.favoriteAlertSeenListings, epoch - 7200)
        removed = removed + p5_prune_timestamps(favorite.favoriteOnlineSeen, epoch - 3600)
      end

      if not T.lastEventExpiry or (now - T.lastEventExpiry) >= 60 then
        T.lastEventExpiry = now
        T.stats.eventExpiryRuns = (T.stats.eventExpiryRuns or 0) + 1
        if self.SFE_GetEventRows then self:SFE_GetEventRows() end
        local network = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
        removed = removed + p5_prune_event_state(network)
      end

      T.stats.cacheEntriesRemoved = (T.stats.cacheEntriesRemoved or 0) + removed
      return true
    end

    function B:SF151_ResetTimerStats()
      T.stats = {}
      return true
    end

    function B:SF151_GetTimerDiagnostics()
      local eventPolling = self._sfe141EventFrame and self._sfe141EventFrame:GetScript("OnUpdate") and true or false
      local previewPolling = self.create and self.create:GetScript("OnUpdate") and true or false
      local p4 = _G.SignalFireRefresh151
      local p3 = _G.SignalFireChatRuntime151
      return {
        generation = T.generation,
        pulseActive = T.pulseFrame:IsShown() and true or false,
        applicantAlert = self.newApplicantAlert and true or false,
        minimapDragging = self.mm and self.mm.dragging and true or false,
        eventPolling = eventPolling,
        previewPolling = previewPolling,
        maintenanceRuns = T.stats.maintenanceRuns or 0,
        eventExpiryRuns = T.stats.eventExpiryRuns or 0,
        cacheEntriesRemoved = T.stats.cacheEntriesRemoved or 0,
        pulseStarts = T.stats.pulseStarts or 0,
        pulseStops = T.stats.pulseStops or 0,
        refreshPending = p4 and p4.pending and true or false,
        chatQueueActive = p3 and p3.queueFrame and p3.queueFrame:IsShown() and true or false,
      }
    end

    function B:SF151_PrintTimerDiagnostics()
      local d = self:SF151_GetTimerDiagnostics()
      local function out(text)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. text) end
      end
      out("timer owner " .. tostring(d.generation) .. ", pulse=" .. tostring(d.pulseActive) .. ", applicant=" .. tostring(d.applicantAlert) .. ", dragging=" .. tostring(d.minimapDragging))
      out("eventPoll=" .. tostring(d.eventPolling) .. ", previewPoll=" .. tostring(d.previewPolling) .. ", refreshPending=" .. tostring(d.refreshPending) .. ", chatQueue=" .. tostring(d.chatQueueActive))
      out("maintenance=" .. tostring(d.maintenanceRuns) .. ", eventExpiry=" .. tostring(d.eventExpiryRuns) .. ", cacheRemoved=" .. tostring(d.cacheEntriesRemoved) .. ", pulseStarts=" .. tostring(d.pulseStarts) .. ", pulseStops=" .. tostring(d.pulseStops))
      return d
    end

    T.ApplyApplicantOwner()
    T.ApplyMinimapOwner()
  end
end

if SignalFire_InstallPhase6 then SignalFire_InstallPhase6() end
