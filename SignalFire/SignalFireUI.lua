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
        local results = {pcall(old, self, ...)}
        local elapsed = math.max(0, p6_clock_ms() - started)
        P6.active[panel] = nil
        stats.calls = (stats.calls or 0) + 1
        stats.totalMs = (stats.totalMs or 0) + elapsed
        if elapsed > (stats.maxMs or 0) then stats.maxMs = elapsed end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
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
      local ok, err = pcall(fn, B)
      P4.executing = nil
      if not ok then error(err, 0) end
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
        if _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled then
          _G.SignalFirePerf151:Note("network", "unitTokensScanned", 1)
        end
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
            if _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled then
              _G.SignalFirePerf151:Note("network", "statusesScanned", 1)
            end
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
-- SIGNALFIRE_PHASE5_CHAT_PUBLIC_INDEX_BEGIN
-- SignalFire 1.5.1 Phase 5: source-owned chat decisions and canonical Public Groups indexing.
do
  local B = _G.BronzeLFG
  if B and not B._sf151Phase3Installed then
    B._sf151Phase3Installed = true

    local P3 = _G.SignalFireChatRuntime151 or {}
    _G.SignalFireChatRuntime151 = P3
    P3.generation = "1.5.1-perf-phase5"

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
      return "group\031" .. string.lower(p3_author(author)) .. "\031" .. p3_norm(text)
    end

    local function p3_source_key(event, channel, author, text)
      return string.lower(tostring(event or "chat")) .. "\031"
        .. p3_norm(channel) .. "\031" .. p3_key(author, text)
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
        "queueDrops", "consolidationRowsScanned", "entriesPruned",
        "sourceEvents", "sourceDecisionHits", "sourceDecisionMisses", "protocolRejected",
        "renderDecisionHits", "renderDecisionMisses", "addMessageParseCalls",
        "indexLookups", "indexHits", "indexMisses", "indexInserts", "indexUpdates",
        "indexRemovals", "indexRebuilds", "indexCollisions", "indexStaleRepairs",
        "indexFullScans", "indexRowsScanned", "refreshDirtyRequests", "alertsEmitted",
        "linksBuilt", "wrapperDuplicateSkips", "processingErrors",
      }
      for _, field in ipairs(fields) do
        if stats[field] == nil then stats[field] = 0 end
      end
      return stats
    end

    local function p3_diagnostics_enabled()
      return (BronzeLFG_DB and BronzeLFG_DB.options
        and BronzeLFG_DB.options.developerDiagnostics == true)
        or (_G.SignalFirePerf151 and _G.SignalFirePerf151.enabled == true)
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

    -- Session-only canonical Public Groups index.
    -- Owner: SignalFireChatRuntime151. Key: normalized sender + rendered message.
    -- Maximum: 512 entries. TTL: current Public Groups expiry plus 30 seconds.
    -- Eviction: cyclic oldest-slot eviction with deterministic-ID repair.
    -- Cleanup: expiry wrapper, direct index lookup repair, or explicit rebuild.
    local P3_INDEX_MAX = 512

    local function p3_index_ttl()
      local value = BronzeLFG_DB and BronzeLFG_DB.options and tonumber(BronzeLFG_DB.options.publicExpire) or 300
      return math.max(60, value or 300) + 30
    end

    local function p3_chat_row(id, row)
      if not row or row.signalFireListing or row.isInvasionBeacon then return false end
      local key = tostring(id or row.id or row.key or "")
      local source = string.lower(tostring(row.source or ""))
      if string.find(key, "^listing%-") or string.find(key, "^INVASION%-") then return false end
      if string.find(source, "network", 1, true) or string.find(source, "invasion", 1, true)
        or row.networkUser or row.signalFireNetwork then return false end
      return true
    end

    local function p3_row_identity(row)
      if not row then return nil end
      local author = p3_author(row.player or row.author)
      local message = row.rawMessage or row.message
      if author == "" or p3_norm(message) == "" then return nil end
      return p3_key(author, message)
    end

    local function p3_index_remove_key(key)
      local item = P3._publicIndex and P3._publicIndex[key] or nil
      if not item then return false end
      P3._publicIndex[key] = nil
      if P3._publicIndexById and P3._publicIndexById[item.id] == key then P3._publicIndexById[item.id] = nil end
      p3_note("indexRemovals")
      return true
    end

    local function p3_index_store(key, id, stamp)
      if not key or key == "" or not id then return end
      stamp = stamp or p3_now()
      P3._publicIndex = P3._publicIndex or {}
      P3._publicIndexById = P3._publicIndexById or {}
      P3._publicIndexSlots = P3._publicIndexSlots or {}
      local current = P3._publicIndex[key]
      if current then
        if current.id ~= id and P3._publicIndexById[current.id] == key then P3._publicIndexById[current.id] = nil end
        current.id = id
        current.stamp = stamp
        current.expires = stamp + p3_index_ttl()
        P3._publicIndexById[id] = key
        p3_note("indexUpdates")
        return
      end

      P3._publicIndexCursor = ((tonumber(P3._publicIndexCursor or 0) or 0) % P3_INDEX_MAX) + 1
      local old = P3._publicIndexSlots[P3._publicIndexCursor]
      if old then
        local oldItem = P3._publicIndex[old.key]
        if oldItem and oldItem.stamp == old.stamp then p3_index_remove_key(old.key) end
      end
      local item = {id=id, stamp=stamp, expires=stamp + p3_index_ttl()}
      P3._publicIndex[key] = item
      P3._publicIndexById[id] = key
      P3._publicIndexSlots[P3._publicIndexCursor] = {key=key, stamp=stamp}
      p3_note("indexInserts")
    end

    local function p3_id_matches(id, key)
      local row = B.publicGroups and B.publicGroups[id] or nil
      if not row then return nil end
      local rowKey = row.sf151CanonicalKey or p3_row_identity(row)
      if rowKey == key then return row end
      return false
    end

    local function p3_stable_id(key)
      local first = "sf151-" .. p3_hash(key)
      for attempt = 0, 7 do
        local id = attempt == 0 and first or (first .. "-" .. p3_hash(key .. "\031" .. tostring(attempt)))
        local match = p3_id_matches(id, key)
        if match ~= false then return id, match end
        p3_note("indexCollisions")
      end
      return first .. "-" .. p3_hash("overflow\031" .. key), nil
    end

    local function p3_index_lookup(key)
      p3_note("indexLookups")
      local stamp = p3_now()
      local item = P3._publicIndex and P3._publicIndex[key] or nil
      if item then
        local row = B.publicGroups and B.publicGroups[item.id] or nil
        if row and (row.sf151CanonicalKey == key or p3_row_identity(row) == key) then
          item.stamp = stamp
          item.expires = stamp + p3_index_ttl()
          p3_note("indexHits")
          return row, item.id
        end
        p3_index_remove_key(key)
        p3_note("indexStaleRepairs")
      end

      p3_note("indexMisses")
      local id, row = p3_stable_id(key)
      if row then
        row.sf151CanonicalKey = key
        p3_index_store(key, id, stamp)
        p3_note("indexStaleRepairs")
        return row, id
      end
      return nil, id
    end

    local function p3_prune_index_missing()
      local removed = 0
      local stamp = p3_now()
      for key, item in pairs(P3._publicIndex or {}) do
        local row = B.publicGroups and B.publicGroups[item.id] or nil
        local expired = stamp > (tonumber(item.expires or 0) or 0)
        local rowSeen = tonumber(row and (row.seen or row.created) or 0) or 0
        local rowFresh = row and (p3_epoch_now() - rowSeen) <= p3_index_ttl()
        if not row or (expired and not rowFresh) or (row and p3_row_identity(row) ~= key) then
          if p3_index_remove_key(key) then removed = removed + 1 end
        elseif expired then
          item.stamp = stamp
          item.expires = stamp + p3_index_ttl()
        end
      end
      return removed
    end

    local function p3_parse(text)
      local o = p3_options()
      if o.publicGroups == false then return nil end
      local raw = p3_trim(text)
      if raw == "" or p3_has_existing_link(raw) then return nil end
      if p3_is_protocol(raw) then p3_note("protocolRejected"); return nil end

      local low = " " .. string.lower(raw) .. " "
      if p3_has_external_noise(low) and not string.find(low, "discord.gg", 1, true)
        and not string.find(low, "discord.com/invite", 1, true) then return nil end
      if string.find(low, " guild", 1, true) and B.SF151_IsGuildSeeking and B:SF151_IsGuildSeeking(raw) then return nil end

      local probe = _G.SignalFireFastChatLinks and _G.SignalFireFastChatLinks.TestParse
      if type(probe) ~= "function" then return nil end
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if diagnostics and _G.SignalFirePerf151 and _G.SignalFirePerf151.Note then
        _G.SignalFirePerf151:Note("chat", "uniqueMessagesClassified", 1)
      end
      if stats then
        stats.testParseCalls = stats.testParseCalls + 1
        stats.parserCalls = stats.parserCalls + 1
      end
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

    local function p3_make_link_row(rec, parsed)
      if not rec or not parsed or parsed.kind ~= "group" then return nil end
      local key = rec.canonicalKey or p3_key(rec.author, rec.text)
      local indexed = P3._publicIndex and P3._publicIndex[key] or nil
      local id = indexed and indexed.id or select(1, p3_stable_id(key))
      local row = {}
      row.id = id
      row.key = id
      row.player = p3_author(rec.author)
      row.message = tostring(rec.text or "")
      row.rawMessage = tostring(rec.text or "")
      row.channel = rec.channel or row.channel or "Public"
      row.type = parsed.type or row.type or "Dungeon"
      row.activity = parsed.activity or row.activity or "Group Listing"
      row.roles = parsed.roles or row.roles or ""
      row.intent = parsed.intent or row.intent or (row.type == "LFG" and "Applicant" or "Recruiter")
      row.tags = parsed.tags or row.tags or row.type
      row.difficulty = parsed.difficulty or row.difficulty
      row.keyLevel = parsed.keyLevel or parsed.keylevel or row.keyLevel
      row.ilevel = parsed.ilevel or row.ilevel
      row.score = tonumber(parsed.score or row.score or 80) or 80
      row.sf151CanonicalKey = key
      row.sf151StableLink = true
      rec.stableId = id
      rec.resolvedId = id
      rec.linkRow = row
      return row
    end

    local function p3_prune(stamp)
      stamp = stamp or p3_now()
      local removed = 0
      for _, slot in ipairs(B._sfP3SeenSlots or {}) do
        local current = B._sfP3Seen and B._sfP3Seen[slot.key] or nil
        if current and current == slot.stamp and (stamp - current) > 20 then
          B._sfP3Seen[slot.key] = nil
          removed = removed + 1
        end
      end
      for _, slot in ipairs(B._sfP3RecordSlots or {}) do
        local rec = B._sfP3Records and B._sfP3Records[slot.id] or nil
        if rec and rec.time == slot.stamp and (stamp - rec.time) > 300 then
          B._sfP3Records[slot.id] = nil
          removed = removed + 1
        end
      end
      for _, slot in ipairs(B._sfP3InlineSeenSlots or {}) do
        local current = B._inlinePublicChatEventSeen and B._inlinePublicChatEventSeen[slot.key] or nil
        if current and current == slot.stamp and (stamp - current) > 20 then
          B._inlinePublicChatEventSeen[slot.key] = nil
          removed = removed + 1
        end
      end
      if removed > 0 then
        p3_note("entriesPruned", removed)
        if _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled then _G.SignalFirePerf151:Note("memory", "entriesPruned", removed) end
      end
    end

    local function p3_enqueue(author, text, channel, event, parsed)
      local raw = tostring(text or "")
      parsed = parsed or p3_parse(raw)
      if not parsed then return nil end
      if p3_author(author) == p3_author(UnitName and UnitName("player") or "") and not B.SignalFireTestSay then return nil end

      local stamp = p3_now()
      local key = p3_key(author, raw)
      B._sfP3Seen = B._sfP3Seen or {}
      B._sfP3Records = B._sfP3Records or {}
      local last = tonumber(B._sfP3Seen[key] or 0) or 0
      local existing = B._sfP3ActiveRecords and B._sfP3ActiveRecords[key] or nil
      if existing and (stamp - last) <= 5 then
        p3_note("deduped")
        return existing
      end

      P3._recordSequence = (tonumber(P3._recordSequence or 0) or 0) + 1
      local id = "p5-" .. p3_hash(key) .. "-" .. tostring(P3._recordSequence)
      local rec = {id=id}
      rec.author = author
      rec.text = raw
      rec.channel = channel or "Public"
      rec.event = event or "CHAT"
      rec.kind = parsed.kind
      rec.parsed = parsed
      rec.guildName = parsed.guild
      rec.canonicalKey = key
      rec.time = stamp
      rec.done = false
      rec.alerted = false
      rec.isNew = false
      if parsed.kind == "group" then p3_make_link_row(rec, parsed) end

      B._sfP3Records[id] = rec
      B._sfP3ActiveRecords = B._sfP3ActiveRecords or {}
      B._sfP3ActiveRecords[key] = rec
      P3._pendingByStableId = P3._pendingByStableId or {}
      if rec.stableId then P3._pendingByStableId[rec.stableId] = rec end
      B._sfP3Seen[key] = stamp
      B._sfP3SeenSlots = B._sfP3SeenSlots or {}
      B._sfP3SeenCursor = ((tonumber(B._sfP3SeenCursor or 0) or 0) % 256) + 1
      local oldSeen = B._sfP3SeenSlots[B._sfP3SeenCursor]
      if oldSeen and B._sfP3Seen[oldSeen.key] == oldSeen.stamp then B._sfP3Seen[oldSeen.key] = nil end
      B._sfP3SeenSlots[B._sfP3SeenCursor] = {key=key, stamp=stamp}

      B._sfP3RecordSlots = B._sfP3RecordSlots or {}
      B._sfP3RecordCursor = ((tonumber(B._sfP3RecordCursor or 0) or 0) % 256) + 1
      local oldRecord = B._sfP3RecordSlots[B._sfP3RecordCursor]
      if oldRecord then
        local oldRec = B._sfP3Records[oldRecord.id]
        if oldRec and oldRec.time == oldRecord.stamp then B._sfP3Records[oldRecord.id] = nil end
      end
      B._sfP3RecordSlots[B._sfP3RecordCursor] = {id=id, stamp=stamp}

      B._sfP3Queue = B._sfP3Queue or {}
      while #B._sfP3Queue >= 40 do
        local dropped = table.remove(B._sfP3Queue, 1)
        if dropped then
          dropped.done = true
          dropped.dropped = true
          if B._sfP3ActiveRecords[dropped.canonicalKey] == dropped then B._sfP3ActiveRecords[dropped.canonicalKey] = nil end
          if P3._pendingByStableId and P3._pendingByStableId[dropped.stableId] == dropped then
            P3._pendingByStableId[dropped.stableId] = nil
          end
        end
        p3_note("queueDrops")
      end
      table.insert(B._sfP3Queue, rec)
      P3._enqueueCount = (tonumber(P3._enqueueCount or 0) or 0) + 1
      local stats = p3_note("enqueued")
      local depth = p3_depth()
      if stats and depth > stats.maxDepth then stats.maxDepth = depth end

      B._inlinePublicChatEventSeen = B._inlinePublicChatEventSeen or {}
      local inlineKey = p3_public_key(author, raw)
      B._inlinePublicChatEventSeen[inlineKey] = stamp
      B._sfP3InlineSeenSlots = B._sfP3InlineSeenSlots or {}
      B._sfP3InlineSeenCursor = ((tonumber(B._sfP3InlineSeenCursor or 0) or 0) % 256) + 1
      local oldInline = B._sfP3InlineSeenSlots[B._sfP3InlineSeenCursor]
      if oldInline and B._inlinePublicChatEventSeen[oldInline.key] == oldInline.stamp then
        B._inlinePublicChatEventSeen[oldInline.key] = nil
      end
      B._sfP3InlineSeenSlots[B._sfP3InlineSeenCursor] = {key=inlineKey, stamp=stamp}
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
        if current and current.stamp == old.stamp then
          P3._decisionCache[old.key] = nil
          if _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled then _G.SignalFirePerf151:Note("memory", "entriesPruned", 1) end
        end
      end

      local item = {rec=rec or false, stamp=stamp, expires=stamp + (ttl or 2)}
      P3._decisionCache[key] = item
      P3._decisionSlots[P3._decisionCursor] = {key=key, stamp=stamp}
    end

    local function p3_cached_decision(key)
      local item = P3._decisionCache and P3._decisionCache[key] or nil
      if not item then return nil, false, key end
      if p3_now() > (tonumber(item.expires or 0) or 0) then
        P3._decisionCache[key] = nil
        return nil, false, key
      end
      p3_note("decisionCacheHits")
      if _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled then
        _G.SignalFirePerf151:Note("chat", "duplicateClassificationsAvoided", 1)
      end
      if item.rec == false then
        p3_note("decisionNegativeHits")
        return nil, true, key
      end
      return item.rec, true, key
    end

    local function p3_cache_render_decision(key, rec, stamp, ttl)
      if not key or key == "" then return end
      stamp = stamp or p3_now()
      P3._renderDecisionCache = P3._renderDecisionCache or {}
      P3._renderDecisionSlots = P3._renderDecisionSlots or {}
      P3._renderDecisionCursor = ((tonumber(P3._renderDecisionCursor or 0) or 0) % 256) + 1
      local old = P3._renderDecisionSlots[P3._renderDecisionCursor]
      if old then
        local current = P3._renderDecisionCache[old.key]
        if current and current.stamp == old.stamp then P3._renderDecisionCache[old.key] = nil end
      end
      local item = {rec=rec or false, stamp=stamp, expires=stamp + (ttl or 2)}
      P3._renderDecisionCache[key] = item
      P3._renderDecisionSlots[P3._renderDecisionCursor] = {key=key, stamp=stamp}
    end

    local function p3_cached_render_decision(author, text)
      local key = p3_key(author, text)
      local item = P3._renderDecisionCache and P3._renderDecisionCache[key] or nil
      if not item then p3_note("renderDecisionMisses"); return nil, false, key end
      if p3_now() > (tonumber(item.expires or 0) or 0) then
        P3._renderDecisionCache[key] = nil
        p3_note("renderDecisionMisses")
        return nil, false, key
      end
      p3_note("renderDecisionHits")
      return item.rec ~= false and item.rec or nil, true, key
    end

    -- Chat filters run once per receiving ChatFrame on Wrath clients. Cache the
    -- decision before classification so hidden tabs reuse both positive and
    -- negative results instead of invoking TestParse again.
    local function p3_resolve(author, text, channel, event)
      local sourceKey = p3_source_key(event, channel, author, text)
      local cached, found = p3_cached_decision(sourceKey)
      if found then p3_note("sourceDecisionHits"); return cached end

      local shared, sharedFound, renderKey = p3_cached_render_decision(author, text)
      if sharedFound then
        p3_cache_decision(sourceKey, shared, p3_now(), shared and 6 or 2)
        p3_note("sourceDecisionHits")
        return shared
      end

      p3_note("decisionCacheMisses")
      p3_note("sourceDecisionMisses")
      p3_note("sourceEvents")
      local parsed = p3_parse(text)
      if not parsed then
        p3_cache_decision(sourceKey, nil, p3_now(), 2)
        p3_cache_render_decision(renderKey, nil, p3_now(), 2)
        return nil
      end

      local rec = p3_enqueue(author, text, channel, event, parsed)
      p3_cache_decision(sourceKey, rec, p3_now(), rec and 6 or 2)
      p3_cache_render_decision(renderKey, rec, p3_now(), rec and 6 or 2)
      return rec
    end

    local function p3_copy_authoritative(dst, src)
      if not (dst and src) then return end
      local fields = {"player", "message", "rawMessage", "channel", "type", "activity", "roles", "intent", "tags", "difficulty", "key", "keyLevel", "ilevel", "score"}
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

    local function p3_upsert_canonical(rec)
      if not rec or rec.kind ~= "group" then return nil end
      B.publicGroups = B.publicGroups or {}
      local key = rec.canonicalKey or p3_key(rec.author, rec.text)
      local row, id = p3_index_lookup(key)
      local isNew = row == nil
      row = row or rec.linkRow or {}

      local parsed = rec.parsed or {}
      row.id = id
      row.key = id
      row.player = p3_author(rec.author)
      row.message = tostring(rec.text or "")
      row.rawMessage = tostring(rec.text or "")
      row.channel = rec.channel or row.channel or "Public"
      row.type = parsed.type or row.type or "Dungeon"
      row.activity = parsed.activity or row.activity or "Group Listing"
      row.roles = parsed.roles or row.roles or ""
      row.intent = parsed.intent or row.intent or (row.type == "LFG" and "Applicant" or "Recruiter")
      row.tags = parsed.tags or row.tags or row.type
      row.difficulty = parsed.difficulty or row.difficulty
      row.keyLevel = parsed.keyLevel or parsed.keylevel or row.keyLevel
      row.ilevel = parsed.ilevel or row.ilevel
      row.score = tonumber(parsed.score or row.score or 80) or 80
      row.sf151CanonicalKey = key
      row.sf151StableLink = true
      row.sessionOnly = true
      row.fastChatLink = nil
      row.sf151Pending = nil

      -- Reuse the final profile-aware parser fix without invoking the historical
      -- AddPublicGroup wrapper chain or its full-table duplicate scans.
      if type(_G.BLFG_570b1c_ApplyPublicParserFix) == "function" then
        local ok = pcall(_G.BLFG_570b1c_ApplyPublicParserFix, row)
        if not ok then p3_note("processingErrors") end
      end

      local stamp = p3_epoch_now()
      if isNew then
        row.created = stamp
        row.firstSeen = stamp
      end
      row.seen = stamp
      p3_repair_row_time(row, stamp)
      B.publicGroups[id] = row
      p3_index_store(key, id, p3_now())
      rec.stableId = id
      rec.resolvedId = id
      rec.linkRow = row
      rec.isNew = isNew
      B._lastPublicGroupTouched = row
      B._lastPublicGroupTouchedKey = id
      if B.SF151_InvalidatePublicGroupsData then
        B:SF151_InvalidatePublicGroupsData(isNew and "chat-insert" or "chat-update", id)
      end
      p3_note("refreshDirtyRequests")
      if B.RequestPublicGroupsRefresh then B:RequestPublicGroupsRefresh() end
      return row
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

    local function p3_rebuild_public_index()
      B.publicGroups = B.publicGroups or {}
      local winners, remove = {}, {}
      P3._publicIndex = {}
      P3._publicIndexById = {}
      P3._publicIndexSlots = {}
      P3._publicIndexCursor = 0
      p3_note("indexRebuilds")
      p3_note("indexFullScans")
      for id, row in pairs(B.publicGroups) do
        p3_note("indexRowsScanned")
        if p3_chat_row(id, row) then
          p3_repair_row_time(row, p3_epoch_now())
          local key = p3_row_identity(row)
          if key then
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
      for key, winner in pairs(winners) do
        winner.row.sf151CanonicalKey = key
        winner.row.sf151StableLink = true
        p3_index_store(key, winner.id, p3_now())
      end
      return #remove
    end

    -- Existing alert signatures remain session-only. Cap them at 256 entries,
    -- expire after 120 seconds, and prune only when an alert is actually emitted.
    local function p3_prune_alert_seen()
      local cache = B._sf151AlertSeen
      if type(cache) ~= "table" then return 0 end
      local stamp = p3_epoch_now()
      local rows, removed = {}, 0
      for key, seen in pairs(cache) do
        local value = tonumber(seen or 0) or 0
        if (stamp - value) > 120 then
          cache[key] = nil
          removed = removed + 1
        else
          table.insert(rows, {key=key, stamp=value})
        end
      end
      if #rows > 256 then
        table.sort(rows, function(a, b) return a.stamp < b.stamp end)
        for i = 1, #rows - 256 do
          if cache[rows[i].key] == rows[i].stamp then cache[rows[i].key] = nil; removed = removed + 1 end
        end
      end
      return removed
    end

    local function p3_process(rec)
      if not rec or rec.done then return end
      local row = nil
      B._sfChatQueueProcessing = true
      B._suppressPublicRefreshInChatLink = true
      B._sfP3SuppressNotify = true
      local ok, err = pcall(function()
        if rec.kind == "group" then
          p3_note("coreCalls")
          row = p3_upsert_canonical(rec)
        elseif rec.kind == "guild" and rec.guildName and B.UpsertGuildBrowserChatListing then
          B:UpsertGuildBrowserChatListing(rec.guildName, rec.author, rec.text)
        end
      end)
      B._sfP3SuppressNotify = nil
      B._suppressPublicRefreshInChatLink = nil
      B._sfChatQueueProcessing = nil
      rec.done = true
      if B._sfP3ActiveRecords and B._sfP3ActiveRecords[rec.canonicalKey] == rec then
        B._sfP3ActiveRecords[rec.canonicalKey] = nil
      end
      if P3._pendingByStableId and P3._pendingByStableId[rec.stableId] == rec then
        P3._pendingByStableId[rec.stableId] = nil
      end
      if not ok then
        rec.error = tostring(err or "unknown processing error")
        p3_note("processingErrors")
      elseif rec.kind == "group" and rec.isNew and row and not rec.alerted and B.NotifyForPublicGroup then
        rec.alerted = true
        local alertOk = pcall(B.NotifyForPublicGroup, B, row)
        if alertOk then p3_note("alertsEmitted") else p3_note("processingErrors") end
        local removed = p3_prune_alert_seen()
        if removed > 0 then p3_note("entriesPruned", removed) end
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
      local row = rec.stableId and B.publicGroups and B.publicGroups[rec.stableId] or rec.linkRow
      if not row and rec.kind == "group" and rec.parsed then row = p3_make_link_row(rec, rec.parsed) end
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
            p3_note("linksBuilt")
          end
        end
      end
      return link and (raw .. " " .. link) or raw
    end

    function P3.Filter(frame, event, msgText, author, ...)
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if stats then stats.filterCalls = stats.filterCalls + 1 end
      local diag = diagnostics and p3_frame_diag(frame) or nil
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
      if diagnostics then
        diag.lastFilterKey = p3_norm(raw)
        diag.lastFilterAt = p3_now()
      end

      local channel = event
      if event == "CHAT_MSG_CHANNEL" then
        channel = tostring(select(8, ...) or select(7, ...) or "Channel")
      elseif event == "CHAT_MSG_SAY" then
        channel = "Say"
      elseif event == "CHAT_MSG_YELL" then
        channel = "Yell"
      end
      local rec = p3_resolve(author, raw, channel, event)
      if diagnostics and _G.SignalFirePerf151 and _G.SignalFirePerf151.NoteChatReceiver then
        _G.SignalFirePerf151:NoteChatReceiver(p3_key(author, raw), p3_frame_name(frame))
      end
      if diagnostics then
        diag.lastFilterWasEligible = rec ~= nil
        diag.lastFilterRec = rec
      end
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

    -- Some custom 3.3.5 chat UIs discard the rewritten filter result. AddMessage
    -- may only reuse a source-event decision; it never parses, queues, mutates a
    -- listing, alerts, or requests a refresh.
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
      local diag = diagnostics and p3_frame_diag(frame) or nil
      if diagnostics then
        diag.wrapperCalls = (diag.wrapperCalls or 0) + 1
        diag.lastWrapperText = tostring(value or "")
      end
      local displayed = tostring(value or "")
      if displayed == "" then return value end
      if p3_has_existing_link(displayed) then
        if stats then stats.alreadyLinkedSkips = stats.alreadyLinkedSkips + 1 end
        p3_note("wrapperDuplicateSkips")
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

      local author, body = p3_display_parts(displayed, plain)
      local rec = nil
      if author ~= "" and body ~= "" then
        rec = select(1, p3_cached_render_decision(author, body))
      end
      if diagnostics and rec and _G.SignalFirePerf151 and _G.SignalFirePerf151.NoteChatReceiver then
        _G.SignalFirePerf151:NoteChatReceiver(p3_key(rec.author or author, rec.text or body), p3_frame_name(frame))
      end
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
      local diagnostics = p3_diagnostics_enabled()
      local diag = diagnostics and p3_frame_diag(frame) or nil
      if frame._sfP3CustomAddMessageHook and frame.AddMessage == frame._sfP3CustomAddMessageHook then
        if diag then diag.wrapperInstalled = true; diag.wrapperGeneration = P3.generation end
        return
      end
      if frame._sfP3CustomAddMessageHook and frame.AddMessage ~= frame._sfP3CustomAddMessageHook then
        if diag then
          diag.replacements = (diag.replacements or 0) + 1
          diag.lastReplacementDetected = p3_now()
        end
      end
      local base = frame.AddMessage
      frame._sfP3CustomBaseAddMessage = base
      frame._sfP3CustomAddMessageHook = function(self, text, ...)
        return base(self, p3_rewrite_rendered_message(self, text), ...)
      end
      frame.AddMessage = frame._sfP3CustomAddMessageHook
      frame._sfP3WrapperGeneration = P3.generation
      if diag then
        diag.wrapperInstalled = true
        diag.wrapperGeneration = P3.generation
        diag.installedAt = p3_now()
      end
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
      p3_resolve(author, text, channel, "ADD_PUBLIC_GROUP")
      return nil
    end

    local function p3_inline()
      -- The source event filter is authoritative. Historical inline callers are
      -- display-passive so they cannot classify or enqueue the same line again.
      return nil
    end

    if not P3._expiryWrapped then
      P3._expiryWrapped = true
      P3._oldExpirePublicGroups = B.ExpirePublicGroups
      function B:ExpirePublicGroups(...)
        local result = P3._oldExpirePublicGroups and P3._oldExpirePublicGroups(self, ...)
        p3_prune_index_missing()
        return result
      end
    end

    -- Pending click targets are session-only, keyed by stable row ID, capped by
    -- the 40-record queue, and removed on process/drop. A click may finish the
    -- already-classified record before the next queue tick without reparsing.
    if not P3._publicLinkWrapped then
      P3._publicLinkWrapped = true
      P3._oldOpenPublicGroupLink = B.OpenPublicGroupLink
      function B:OpenPublicGroupLink(id, title)
        local rec = P3._pendingByStableId and P3._pendingByStableId[tostring(id or "")] or nil
        if rec and not rec.done then p3_process(rec) end
        return P3._oldOpenPublicGroupLink and P3._oldOpenPublicGroupLink(self, id, title) or nil
      end
    end

    function P3.Apply()
      p3_disable_old_runtime()
      B.AddPublicGroup = p3_add_public
      B.InlinePublicChatLinkForMessage = p3_inline
      p3_add_filter()
      p3_hook_custom_chat_frames()
      if not P3._canonicalIndexBuilt then
        P3._canonicalIndexBuilt = true
        p3_rebuild_public_index()
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
      return p3_rebuild_public_index()
    end


    function B:SF151_GetChatPublicIndexDiagnostics()
      local stats = p3_stats()
      local indexEntries, recordEntries, renderEntries = 0, 0, 0
      for _ in pairs(P3._publicIndex or {}) do indexEntries = indexEntries + 1 end
      for _ in pairs(B._sfP3Records or {}) do recordEntries = recordEntries + 1 end
      for _ in pairs(P3._renderDecisionCache or {}) do renderEntries = renderEntries + 1 end
      return {
        generation=P3.generation,
        queueDepth=p3_depth(),
        indexEntries=indexEntries,
        indexMaximum=P3_INDEX_MAX,
        indexTTL=p3_index_ttl(),
        recordEntries=recordEntries,
        recordMaximum=256,
        renderDecisionEntries=renderEntries,
        renderDecisionMaximum=256,
        addMessageParseCalls=stats.addMessageParseCalls or 0,
        counters=stats,
      }
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
      local function schedule()
        P3.Apply()
        startup:SetScript("OnUpdate", nil)
        if B.SF151_ScheduleDelayed then
          B:SF151_ScheduleDelayed("startup.chat-owner", 1.0, P3.Apply)
        end
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
-- SIGNALFIRE_PHASE5_CHAT_PUBLIC_INDEX_END

if _G.SignalFireRefresh151 and _G.SignalFireRefresh151.InstallFinalOwners then
  _G.SignalFireRefresh151.InstallFinalOwners()
end

-- Phase 5: event-driven UI animation and bounded slow maintenance.
do
  local B = _G.BronzeLFG
  if B and CreateFrame then
    -- Phase 4 timer owner. Delayed tasks are session-only, keyed by caller,
    -- capped at 128, and removed on execution, cancellation, or replacement.
    -- The owner wakes on the first task, sleeps on an empty queue, runs at no
    -- more than 30 Hz, and isolates callback failures so later tasks continue.
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

-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_BEGIN
-- Phase 6 owns only the Public Groups display pipeline. Canonical chat identity,
-- queueing, alerts, and the Phase 4 refresh scheduler remain authoritative.
do
  local B = _G.BronzeLFG
  local Refresh = _G.SignalFireRefresh151
  if B and Refresh and Refresh.original then
    local PG = _G.SignalFirePublicGroupsView151 or {}
    _G.SignalFirePublicGroupsView151 = PG
    PG.generationName = "1.5.1-perf-phase6b"
    PG.dataGeneration = tonumber(PG.dataGeneration or 0) or 0
    if PG.dataGeneration < 1 then PG.dataGeneration = 1 end
    PG.maximumViews = 16
    PG.viewCache = PG.viewCache or {}
    PG.viewOrder = PG.viewOrder or {}
    PG.stats = PG.stats or {}
    PG.dirty = true

    -- Session-only cache design:
    -- Snapshot owner: SignalFirePublicGroupsView151, key=dataGeneration, max=1,
    -- no TTL, replaced on material Public Groups mutation.
    -- View owner: SignalFirePublicGroupsView151, key=generation/filter/search/
    -- role/sort/profile/hidden settings, max=16, no TTL, FIFO eviction and full
    -- invalidation on data-generation change. Nothing is persisted.
    local function p6_diagnostics()
      return (_G.SignalFirePerf151 and _G.SignalFirePerf151.enabled == true)
        or (BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.developerDiagnostics == true)
    end

    local function p6_note(field, amount)
      if not p6_diagnostics() then return end
      PG.stats[field] = (PG.stats[field] or 0) + (amount or 1)
    end

    local function p6_max(field, value)
      if not p6_diagnostics() then return end
      value = tonumber(value or 0) or 0
      if value > (PG.stats[field] or 0) then PG.stats[field] = value end
    end

    local function p6_clock()
      if debugprofilestop then return debugprofilestop() end
      return ((GetTime and GetTime()) or 0) * 1000
    end

    local function p6_time_call(totalField, maxField, callback)
      if not p6_diagnostics() then return callback() end
      local started = p6_clock()
      local results = {pcall(callback)}
      local elapsed = math.max(0, p6_clock() - started)
      PG.stats[totalField] = (PG.stats[totalField] or 0) + elapsed
      p6_max(maxField, elapsed)
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2)
    end

    local function p6_trim(value)
      local text = tostring(value or "")
      text = string.gsub(text, "^%s+", "")
      text = string.gsub(text, "%s+$", "")
      return text
    end

    local function p6_lower(value)
      return string.lower(tostring(value or ""))
    end

    local function p6_epoch()
      return (time and time()) or 0
    end

    local function p6_visible(frame)
      if not frame then return false end
      if frame.IsVisible then return frame:IsVisible() and true or false end
      if frame.IsShown then return frame:IsShown() and true or false end
      return false
    end

    local function p6_count(values)
      local count = 0
      for _ in pairs(values or {}) do count = count + 1 end
      return count
    end

    local function p6_shorten(value, maximum)
      local text = tostring(value or "")
      maximum = tonumber(maximum or 30) or 30
      if string.len(text) <= maximum then return text end
      return string.sub(text, 1, math.max(1, maximum - 3)) .. "..."
    end

    local function p6_stable_time(row)
      local stamp = tonumber(row and (row.firstSeen or row.created or row.seen) or 0) or 0
      if stamp <= 0 then stamp = p6_epoch() end
      return stamp
    end

    local function p6_age(stamp)
      local delta = math.max(0, p6_epoch() - (tonumber(stamp or 0) or p6_epoch()))
      if delta < 60 then return tostring(delta) .. " sec ago" end
      if delta < 3600 then return tostring(math.floor(delta / 60)) .. " min ago" end
      return tostring(math.floor(delta / 3600)) .. " hr ago"
    end

    local typeIcon = {
      Dungeon="Interface\\Icons\\Ability_DualWield",
      Raid="Interface\\Icons\\Achievement_Boss_CThun",
      Key="Interface\\Icons\\INV_Misc_Key_03",
      Event="Interface\\Icons\\INV_Misc_Ticket_Tarot_Madness",
      Guild="Interface\\Icons\\INV_Misc_TabardPVP_01",
      LFG="Interface\\Icons\\INV_Misc_GroupNeedMore",
      Social="Interface\\Icons\\INV_Misc_GroupLooking",
      Other="Interface\\Icons\\INV_Misc_Note_01",
    }
    local typeColor = {
      Dungeon="|cff3fa7ff", Raid="|cff4dff7a", Key="|cffb866ff",
      Event="|cffff9a33", Guild="|cff00e6cc", LFG="|cffffff66",
      Social="|cffff66cc", Other="|cffaaaaaa",
    }
    local classColors = {
      WARRIOR="|cffc79c6e", PALADIN="|cfff58cba", HUNTER="|cffabd473",
      ROGUE="|cfffff569", PRIEST="|cffffffff", DEATHKNIGHT="|cffc41f3b",
      SHAMAN="|cff0070de", MAGE="|cff69ccf0", WARLOCK="|cff9482c9",
      DRUID="|cffff7d0a",
    }

    local function p6_type_label(value)
      local kind = tostring(value or "Other")
      local icon = typeIcon[kind] or typeIcon.Other
      local color = typeColor[kind] or typeColor.Other
      return "|T" .. icon .. ":14:14:0:0|t " .. color .. kind .. "|r"
    end

    local function p6_filter_label(kind, count)
      count = tonumber(count or 0) or 0
      if kind == "All" then return "All (" .. tostring(count) .. ")" end
      local icon = typeIcon[kind] or typeIcon.Other
      return "|T" .. icon .. ":12:12:0:0|t " .. tostring(kind) .. " (" .. tostring(count) .. ")"
    end

    local function p6_class_color(value)
      local key = string.upper(tostring(value or ""))
      key = string.gsub(key, "%s+", "")
      key = string.gsub(key, "[^A-Z]", "")
      if key == "DK" then key = "DEATHKNIGHT" end
      return classColors[key] or "|cff9fd6ff"
    end

    local function p6_roles(value)
      local raw = tostring(value or "")
      local low = p6_lower(raw)
      if raw == "" or low == "not detected" then return "-", false, false, false end
      local tank = string.find(low, "tank", 1, true) ~= nil or string.find(raw, ">T<", 1, true) ~= nil or string.find(raw, "T/", 1, true) ~= nil
      local healer = string.find(low, "heal", 1, true) ~= nil or string.find(raw, ">H<", 1, true) ~= nil or string.find(raw, "/H", 1, true) ~= nil
      local dps = string.find(low, "dps", 1, true) ~= nil or string.find(raw, ">D<", 1, true) ~= nil or string.find(raw, "/D", 1, true) ~= nil
      if string.find(raw, "T/H/D", 1, true) then tank, healer, dps = true, true, true end
      local values = {}
      if tank then table.insert(values, "|cff4aa3ffT|r") end
      if healer then table.insert(values, "|cff44ff66H|r") end
      if dps then table.insert(values, "|cffff5555D|r") end
      if string.find(low, "flex", 1, true) then table.insert(values, "|cffffff66F|r") end
      if #values == 0 then return "-", false, false, false end
      return table.concat(values, "/"), tank, healer, dps
    end

    local function p6_is_invasion(row)
      return row and (row.isInvasionBeacon
        or tostring(row.source or "") == "Invasion Beacon"
        or string.find(tostring(row.tags or ""), "Invasion", 1, true) ~= nil)
    end

    local function p6_material_signature(row)
      if not row then return "" end
      return table.concat({
        tostring(row.id or ""), tostring(row.player or ""), tostring(row.message or ""),
        tostring(row.channel or ""), tostring(row.type or ""), tostring(row.activity or ""),
        tostring(row.roles or ""), tostring(row.intent or ""), tostring(row.tags or ""),
        tostring(row.ilevel or ""), tostring(row.score or ""), tostring(row.playerLevel or ""),
        tostring(row.playerClassFile or row.playerClass or ""), tostring(row.playerRole or ""),
        tostring(row.playerSpec or ""), tostring(row.playerZone or ""),
        tostring(row.playerGuild or ""), tostring(row.playerInfoSource or ""),
        tostring(row.seen or ""), tostring(row.created or ""), tostring(row.firstSeen or ""),
      }, "\31")
    end

    local function p6_expire_seconds()
      local value = BronzeLFG_DB and BronzeLFG_DB.options and tonumber(BronzeLFG_DB.options.publicExpire) or 300
      return math.max(1, value or 300)
    end

    local function p6_row_deadline(row)
      return (tonumber(row and (row.seen or row.created) or 0) or 0) + p6_expire_seconds() + 1
    end

    local function p6_schedule_expiry(deadline)
      deadline = tonumber(deadline or 0) or 0
      if deadline <= 0 then return end
      if not p6_visible(B.publicPanel) then
        if B.SF151_CancelDelayed then B:SF151_CancelDelayed("public-groups.expiry") end
        PG.expiryScheduled = nil
        PG.expiryDeadline = nil
        return
      end
      if PG.expiryScheduled and PG.expiryDeadline and PG.expiryDeadline <= deadline then return end
      PG.expiryDeadline = deadline
      if not B.SF151_ScheduleDelayed then return end
      PG.expiryScheduled = true
      B:SF151_ScheduleDelayed("public-groups.expiry", math.max(0, deadline - p6_epoch()), function()
        PG.expiryScheduled = nil
        PG.expiryDeadline = nil
        p6_note("scheduledExpiryWakes")
        p6_note("expirationChecks")
        local removed = B.ExpirePublicGroups and (tonumber(B:ExpirePublicGroups()) or 0) or 0
        if removed <= 0 then p6_note("noChangeExpirationChecks") end
        if removed > 0 and B.RefreshPublicGroups then B:RefreshPublicGroups() end
        if PG.RescheduleExpiry then PG.RescheduleExpiry() end
      end)
    end

    function PG.RescheduleExpiry()
      if not p6_visible(B.publicPanel) then
        if B.SF151_CancelDelayed then B:SF151_CancelDelayed("public-groups.expiry") end
        PG.expiryScheduled = nil
        PG.expiryDeadline = nil
        return false
      end
      local nearest = nil
      for _, row in pairs(B.publicGroups or {}) do
        local deadline = p6_row_deadline(row)
        if deadline > p6_epoch() and (not nearest or deadline < nearest) then nearest = deadline end
      end
      if nearest then
        PG.expiryScheduled = nil
        p6_schedule_expiry(nearest)
      elseif B.SF151_CancelDelayed then
        B:SF151_CancelDelayed("public-groups.expiry")
        PG.expiryScheduled = nil
        PG.expiryDeadline = nil
      end
      return nearest ~= nil
    end

    local function p6_clear_views()
      PG.viewCache = {}
      PG.viewOrder = {}
    end

    function B:SF151_InvalidatePublicGroupsData(reason, id)
      PG.dataGeneration = (tonumber(PG.dataGeneration or 0) or 0) + 1
      PG.snapshot = nil
      PG.snapshotGeneration = nil
      p6_clear_views()
      PG.dirty = true
      p6_note("generationIncrements")
      local row = id and self.publicGroups and self.publicGroups[id] or nil
      if row then p6_schedule_expiry(p6_row_deadline(row)) end
      return PG.dataGeneration, reason
    end

    local function p6_module_enabled(row)
      if not p6_is_invasion(row) then return true end
      if B.SFModuleIsEnabled then return B:SFModuleIsEnabled("invasions") and true or false end
      return true
    end

    local function p6_displayable(id, row)
      if not row or not row.message or row.message == "" then return false end
      if _G.BronzeLFG_IsAddonSpam and _G.BronzeLFG_IsAddonSpam(row.message) then return false end
      if not p6_module_enabled(row) then return false end
      if row.type == "Guild" or row.activity == "Guild Recruitment" then return false end
      if row.sf151StableLink then return true end
      if row.signalFireListing or row.isInvasionBeacon or tostring(id or ""):find("^listing%-") then return true end
      if _G.BLFG_5713_IsPublicQueueChatter and _G.BLFG_5713_IsPublicQueueChatter(row.message) then return false end
      if _G.BLFG_5713_IsStrongPublicListing and not _G.BLFG_5713_IsStrongPublicListing(row.message) then return false end
      return true
    end

    local function p6_snapshot_build()
      if PG.testErrorStage == "snapshot" then error("injected Public Groups snapshot error") end
      p6_note("snapshotsBuilt")
      local rows, byId = {}, {}
      local counts = {All=0, Dungeon=0, Raid=0, Key=0, Event=0, Guild=0, LFG=0, Social=0}
      local nearest = nil
      for id, row in pairs(B.publicGroups or {}) do
        if p6_displayable(id, row) then
          p6_note("canonicalRowsProcessed")
          local rolesText, tank, healer, dps = p6_roles(row.roles)
          local playerClass = row.playerClassFile or row.playerClass or ""
          local lookup = _G.BLFG_PublicPlayerLookup and _G.BLFG_PublicPlayerLookup(B, row.player) or nil
          if playerClass == "" and lookup then playerClass = lookup.classFile or lookup.class or "" end
          local kind = tostring(row.type or "Other")
          local stableTime = p6_stable_time(row)
          local record = {
            id=tostring(row.id or id), row=row, player=tostring(row.player or ""),
            message=tostring(row.message or ""), activity=tostring(row.activity or ""),
            kind=kind, roles=tostring(row.roles or ""), rolesText=rolesText,
            needsTank=tank, needsHealer=healer, needsDPS=dps,
            intent=tostring(row.intent or (kind == "LFG" and "Applicant" or "Recruiter")),
            tags=tostring(row.tags or ""), channel=tostring(row.channel or "Public"),
            ilevel=tostring(row.ilevel or ""), score=tostring(row.score or ""),
            playerClass=playerClass, playerLevel=tostring(row.playerLevel or (lookup and lookup.level) or ""),
            playerRole=tostring(row.playerRole or (lookup and lookup.role) or ""),
            playerSpec=tostring(row.playerSpec or (lookup and lookup.spec) or ""),
            playerZone=tostring(row.playerZone or (lookup and lookup.zone) or ""),
            playerGuild=tostring(row.playerGuild or (lookup and lookup.guild) or ""),
            playerInfoSource=tostring(row.playerInfoSource or (lookup and lookup.source) or ""),
            stableTime=stableTime, seen=tonumber(row.seen or row.created or 0) or 0,
            materialSignature=p6_material_signature(row),
          }
          record.playerText = record.player
          if record.playerClass ~= "" then record.playerText = p6_class_color(record.playerClass) .. record.player .. "|r" end
          record.typeText = p6_type_label(kind)
          record.activityText = p6_shorten(record.activity, 26)
          record.messageText = p6_shorten(record.message, 70)
          record.searchText = p6_lower(table.concat({record.player, kind, record.activity,
            record.message, record.intent, record.roles, record.tags, record.channel}, " "))
          p6_note("normalizedStringsGenerated")
          table.insert(rows, record)
          byId[record.id] = record
          counts.All = counts.All + 1
          if kind == "Dungeon" then counts.Dungeon = counts.Dungeon + 1 end
          if kind == "Raid" then counts.Raid = counts.Raid + 1 end
          if kind == "Key" then counts.Key = counts.Key + 1 end
          if kind == "Event" or record.activity == "Event" or record.activity == "Seasonal Event"
            or string.find(record.tags, "Boss Blitz", 1, true) then counts.Event = counts.Event + 1 end
          if kind == "LFG" or record.intent == "Applicant" then counts.LFG = counts.LFG + 1 end
          if kind == "Social" or record.intent == "Social" then counts.Social = counts.Social + 1 end
          local deadline = p6_row_deadline(row)
          if deadline > p6_epoch() and (not nearest or deadline < nearest) then nearest = deadline end
        end
      end
      PG.snapshot = {rows=rows, byId=byId, counts=counts, generation=PG.dataGeneration}
      PG.snapshotGeneration = PG.dataGeneration
      if nearest then p6_schedule_expiry(nearest) end
      return PG.snapshot
    end

    local function p6_snapshot()
      p6_note("snapshotRequests")
      if PG.snapshot and PG.snapshotGeneration == PG.dataGeneration then
        p6_note("snapshotCacheHits")
        return PG.snapshot
      end
      return p6_time_call("snapshotBuildMsTotal", "snapshotBuildMsMax", p6_snapshot_build)
    end

    local function p6_hidden_signature()
      local hidden = BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes or {}
      local names = {"Other", "Social", "Guild", "LFG", "Event", "Raid", "Dungeon", "Key"}
      local values = {}
      for _, name in ipairs(names) do
        if hidden and hidden[name] then table.insert(values, name) end
      end
      if B.publicHideOther == true and not (hidden and hidden.Other) then table.insert(values, "Other") end
      return table.concat(values, ",")
    end

    local function p6_filter_matches(record, filter)
      if filter == "All" then return true end
      if filter == "Event" then
        return record.kind == "Event" or record.activity == "Event" or record.activity == "Seasonal Event"
          or string.find(record.tags, "Boss Blitz", 1, true) ~= nil
      end
      if filter == "LFG" then return record.kind == "LFG" or record.intent == "Applicant" end
      if filter == "Social" then return record.kind == "Social" or record.intent == "Social" end
      return record.kind == filter
    end

    local function p6_role_matches(record, filter)
      if filter == "T" then return record.needsTank end
      if filter == "H" then return record.needsHealer end
      if filter == "D" then return record.needsDPS end
      return true
    end

    local function p6_view_inputs()
      local filter = tostring(B.publicFilter or "All")
      if filter == "Ascended" then filter = "Raid" end
      if filter == "Boss Blitz" then filter = "Event" end
      if filter == "Guild" then filter = "All" end
      B.publicFilter = filter
      if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes.Guild = nil end
      local query = B.publicSearchText or (B.publicSearch and B.publicSearch.GetText and B.publicSearch:GetText()) or ""
      query = p6_lower(p6_trim(query))
      local role = tostring(B.publicRoleFilter or "All")
      local mode = tostring(B.publicSortMode or "Newest")
      local hidden = p6_hidden_signature()
      local profile = tostring(BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "")
      local invasion = B.SFModuleIsEnabled and tostring(B:SFModuleIsEnabled("invasions")) or "true"
      return filter, query, role, mode, hidden, profile, invasion
    end

    local function p6_view_build(snapshot, signature, filter, query, role, mode, hiddenSignature)
      if PG.testErrorStage == "view" then error("injected Public Groups view error") end
      p6_note("viewsBuilt")
      local hidden = {}
      for name in string.gmatch(hiddenSignature or "", "[^,]+") do hidden[name] = true end
      local rows = {}
      for _, record in ipairs(snapshot.rows) do
        p6_note("filterScans")
        local keep = not hidden[record.kind] and p6_filter_matches(record, filter) and p6_role_matches(record, role)
        if keep and query ~= "" then
          p6_note("searchScans")
          keep = string.find(record.searchText, query, 1, true) ~= nil
        end
        if keep then table.insert(rows, record) end
      end
      p6_note("viewSorts")
      table.sort(rows, function(a, b)
        if mode == "Type" and a.kind ~= b.kind then return a.kind < b.kind end
        if mode == "Activity" and a.activity ~= b.activity then return a.activity < b.activity end
        if mode == "Player" and a.player ~= b.player then return a.player < b.player end
        return a.seen > b.seen
      end)
      local view = {rows=rows, signature=signature, generation=PG.dataGeneration}
      PG.viewCache[signature] = view
      table.insert(PG.viewOrder, signature)
      while #PG.viewOrder > PG.maximumViews do
        local old = table.remove(PG.viewOrder, 1)
        if old then PG.viewCache[old] = nil end
      end
      return view
    end

    local function p6_view()
      p6_note("viewRequests")
      local snapshot = p6_snapshot()
      local filter, query, role, mode, hidden, profile, invasion = p6_view_inputs()
      local signature = table.concat({tostring(PG.dataGeneration), filter, query, role, mode, hidden, profile, invasion}, "\31")
      local cached = PG.viewCache[signature]
      if cached then p6_note("viewCacheHits"); return cached, snapshot end
      local view = p6_time_call("viewBuildMsTotal", "viewBuildMsMax", function()
        return p6_view_build(snapshot, signature, filter, query, role, mode, hidden)
      end)
      return view, snapshot
    end

    local function p6_set_text(widget, value)
      if not widget or not widget.SetText then return false end
      value = tostring(value or "")
      if widget._sfP6Text == value then return false end
      widget._sfP6Text = value
      widget:SetText(value)
      p6_note("setTextCalls")
      return true
    end

    local function p6_set_highlight(button, active)
      if not button or button._sfP6Highlight == active then return false end
      button._sfP6Highlight = active
      if active and button.LockHighlight then button:LockHighlight()
      elseif not active and button.UnlockHighlight then button:UnlockHighlight() end
      return true
    end

    local function p6_set_backdrop(row, selected)
      if not row or row._sfP6Selected == selected then return false end
      row._sfP6Selected = selected
      if row.SetBackdropColor then
        if selected then row:SetBackdropColor(.25, .25, .05, .95) else row:SetBackdropColor(0, 0, 0, .80) end
        p6_note("backdropWrites")
      end
      return true
    end

    local function p6_apply_metadata(row, record, age)
      if row._sfP6DataSignature == record.materialSignature then
        row.fullTime = age
        return false
      end
      row._sfP6DataSignature = record.materialSignature
      row.key = record.id
      row.fullPlayer = record.player
      row.fullActivity = record.activity
      row.fullType = record.kind
      row.fullRoles = record.roles ~= "" and record.roles or "Not detected"
      row.fullIntent = record.intent
      row.fullChannel = record.channel
      row.fullTags = record.tags
      row.fullILevel = record.ilevel
      row.fullScore = record.score
      row.fullMessage = record.message
      row.fullPlayerLevel = record.playerLevel
      row.fullPlayerClass = record.playerClass
      row.fullPlayerRole = record.playerRole
      row.fullPlayerSpec = record.playerSpec
      row.fullPlayerZone = record.playerZone
      row.fullPlayerGuild = record.playerGuild
      row.fullPlayerInfoSource = record.playerInfoSource
      row.fullTime = age
      row._sfP6StableTime = record.stableTime
      return true
    end

    local function p6_hide_row(row)
      if not row then return end
      if row.IsShown and row:IsShown() then row:Hide() end
      row.key = nil
      row._sfP6RenderSignature = nil
      row._sfP6DataSignature = nil
      row._sfP6StableTime = nil
      row._sfP6Selected = nil
      row.fullPlayer, row.fullActivity, row.fullMessage, row.fullType = nil, nil, nil, nil
    end

    local function p6_render_row(row, record, selected)
      p6_note("rowsConsidered")
      if not record then p6_hide_row(row); return end
      local age = p6_age(record.stableTime)
      local signature = table.concat({record.materialSignature, record.playerText, record.typeText,
        record.activityText, record.rolesText, record.messageText, tostring(selected)}, "\31")
      if row._sfP6RenderSignature == signature then
        if p6_set_text(row.time, age) then row.fullTime = age end
        p6_note("rowRenderSignatureHits")
        return
      end
      if PG.testErrorStage == "row" then error("injected Public Groups row-render error") end
      local writes = 0
      if not (row.IsShown and row:IsShown()) then row:Show() end
      if p6_set_text(row.player, record.playerText) then writes = writes + 1 end
      if p6_set_text(row.time, age) then writes = writes + 1 end
      if p6_set_text(row.type, record.typeText) then writes = writes + 1 end
      if p6_set_text(row.activity, record.activityText) then writes = writes + 1 end
      if p6_set_text(row.roles, record.rolesText) then writes = writes + 1 end
      if p6_set_text(row.message, record.messageText) then writes = writes + 1 end
      if p6_set_backdrop(row, selected) then writes = writes + 1 end
      if p6_apply_metadata(row, record, age) then writes = writes + 1 end
      row._sfP6RenderSignature = signature
      if writes > 0 then p6_note("rowsFullyWritten") else p6_note("rowRenderSignatureHits") end
    end

    local function p6_online_count()
      local rows = B.GetOnlineUserRows and B:GetOnlineUserRows() or {}
      return #(rows or {})
    end

    local function p6_render_controls(snapshot, view, page, pages)
      local online = p6_online_count()
      p6_set_text(B.publicCountText, "Listings: " .. tostring(snapshot.counts.All or #view.rows)
        .. "  |  Results: " .. tostring(#view.rows) .. "  |  SignalFire Network: " .. tostring(online))
      local hiddenCount = 0
      for _ in string.gmatch(p6_hidden_signature(), "[^,]+") do hiddenCount = hiddenCount + 1 end
      p6_set_text(B.publicHideOtherButton, "Hide Types: " .. tostring(hiddenCount))
      p6_set_text(B.publicSortButton, "Sort: " .. tostring(B.publicSortMode or "Newest"))
      p6_set_text(B.onlinePanelButton, "Full Roster (" .. tostring(online) .. ")")
      if B.onlinePanelButton and B.onlinePanelButton.SetWidth and B.onlinePanelButton._sfP6Width ~= 146 then
        B.onlinePanelButton._sfP6Width = 146
        B.onlinePanelButton:SetWidth(146)
      end
      local names = {"All", "Dungeon", "Raid", "Key", "Event", "Guild", "LFG", "Social"}
      for _, name in ipairs(names) do
        local button = B.publicFilterButtons and B.publicFilterButtons[name]
        if button then
          p6_set_text(button, p6_filter_label(name, snapshot.counts[name] or 0))
          p6_set_highlight(button, tostring(B.publicFilter or "All") == name)
        end
      end
      for key, button in pairs(B.publicRoleFilterButtons or {}) do
        p6_set_highlight(button, tostring(B.publicRoleFilter or "All") == tostring(key))
      end
      p6_set_text(B.publicPageText, "Page " .. tostring(page) .. " / " .. tostring(pages))
    end

    local function p6_render_detail(snapshot)
      p6_note("detailRenderRequests")
      local selected = B.selectedPublic and snapshot.byId[tostring(B.selectedPublic)] or nil
      if B.selectedPublic and not selected then B.selectedPublic = nil end
      local signature = selected and (selected.id .. "\31" .. selected.materialSignature) or "none"
      if PG.detailSignature == signature then p6_note("detailSignatureHits"); return end
      PG.detailSignature = signature
      p6_note("detailRendersExecuted")
    end

    local function p6_record_public_attention()
      B.sfamSeenPublic = B.sfamSeenPublic or {}
      for _, row in ipairs(B.publicRows or {}) do
        if row and row.key then
          local key = tostring(row.key)
          if B.sfamPublicInitialized and not B.sfamSeenPublic[key] then
            if B.SFAM_PulsePublicGroupRow then B:SFAM_PulsePublicGroupRow(row) end
            if B.SFAM_MarkRelevant then B:SFAM_MarkRelevant("New group listing", 5) end
          end
          B.sfamSeenPublic[key] = true
        end
      end
      B.sfamPublicInitialized = true
    end

    local function p6_update_visible_ages()
      if not p6_visible(B.publicPanel) then return end
      for _, row in ipairs(B.publicRows or {}) do
        if row and row.key and row._sfP6StableTime then
          local age = p6_age(row._sfP6StableTime)
          if p6_set_text(row.time, age) then
            row.fullTime = age
          end
        end
      end
      if B.SF151_ScheduleDelayed then
        B:SF151_ScheduleDelayed("public-groups.age", 1, p6_update_visible_ages)
      end
    end

    local function p6_render_internal()
      if not p6_visible(B.publicPanel) then
        PG.dirty = true
        p6_note("hiddenRendersSkipped")
        return false
      end
      local view, snapshot = p6_view()
      local per = tonumber(B.publicRowsPerPage or 8) or 8
      local pages = math.max(1, math.ceil(#view.rows / per))
      local page = tonumber(B.publicPage or 1) or 1
      if page < 1 then page = 1 end
      if page > pages then page = pages end
      B.publicPage = page
      local start = ((page - 1) * per) + 1
      local selected = tostring(B.selectedPublic or "")
      if PG.lastRenderedViewSignature == view.signature and PG.lastRenderedSelection ~= nil
        and PG.lastRenderedSelection ~= selected then p6_note("selectionOnlyUpdates") end
      p6_render_controls(snapshot, view, page, pages)
      p6_time_call("rowRenderMsTotal", "rowRenderMsMax", function()
        for index, row in ipairs(B.publicRows or {}) do
          p6_render_row(row, view.rows[start + index - 1], B.selectedPublic == (view.rows[start + index - 1] and view.rows[start + index - 1].id))
        end
      end)
      p6_time_call("detailRenderMsTotal", "detailRenderMsMax", function() p6_render_detail(snapshot) end)
      PG.lastRenderedViewSignature = view.signature
      PG.lastRenderedSelection = selected
      p6_record_public_attention()
      PG.dirty = false
      if B.SF151_ScheduleDelayed then B:SF151_ScheduleDelayed("public-groups.age", 1, p6_update_visible_ages) end
      return true
    end

    function PG.Render()
      p6_note("visibleRenderRequests")
      if PG.rendering then p6_note("renderReentrySkipped"); return false end
      PG.rendering = true
      local result = {pcall(function()
        return p6_time_call("totalRefreshMsTotal", "totalRefreshMsMax", p6_render_internal)
      end)}
      PG.rendering = nil
      if not result[1] then
        PG.dirty = true
        PG.lastError = tostring(result[2] or "Public Groups render error")
        p6_note("renderErrors")
        return false, PG.lastError
      end
      if result[2] then p6_note("visibleRendersExecuted") end
      return result[2]
    end

    local function p6_attach_panel(panel)
      if not panel or panel._sfP6ViewHooks then return end
      panel._sfP6ViewHooks = true
      if panel.HookScript then
        panel:HookScript("OnShow", function()
          PG.dirty = true
          if B.ExpirePublicGroups then B:ExpirePublicGroups() end
          PG.RescheduleExpiry()
          if B.RefreshPublicGroups then B:RefreshPublicGroups() end
        end)
        panel:HookScript("OnHide", function()
          if B.SF151_CancelDelayed then B:SF151_CancelDelayed("public-groups.age") end
          if B.SF151_CancelDelayed then B:SF151_CancelDelayed("public-groups.expiry") end
          PG.expiryScheduled = nil
          PG.expiryDeadline = nil
        end)
      end
    end
    PG.AttachPanel = p6_attach_panel

    local oldBuildPublicGroups = B.BuildPublicGroups
    if type(oldBuildPublicGroups) == "function" then
      B.BuildPublicGroups = function(self, ...)
        local results = {pcall(oldBuildPublicGroups, self, ...)}
        if not results[1] then error(results[2], 0) end
        p6_attach_panel(self.publicPanel)
        return unpack(results, 2)
      end
    end
    p6_attach_panel(B.publicPanel)

    local oldExpirePublicGroups = B.ExpirePublicGroups
    if type(oldExpirePublicGroups) == "function" then
      B.ExpirePublicGroups = function(self, ...)
        local results = {pcall(oldExpirePublicGroups, self, ...)}
        if not results[1] then error(results[2], 0) end
        local removed = tonumber(results[2] or 0) or 0
        if removed > 0 then
          p6_note("rowsExpired", removed)
          p6_note("expirationIndexRemovals", removed)
          self:SF151_InvalidatePublicGroupsData("expiration")
        end
        return unpack(results, 2)
      end
    end

    local function p6_wrap_row_mutation(methodName)
      local old = B[methodName]
      if type(old) ~= "function" then return end
      B[methodName] = function(self, ...)
        local args = {...}
        local beforeId = nil
        if methodName == "MirrorListingToPublic" and args[1] then beforeId = "listing-" .. tostring(args[1].id or "") end
        if methodName == "UpsertInvasionPublicListing" and args[1] then
          local name = tostring(args[1].invasionName or args[1].name or args[1].activity or "Invasion")
          name = string.gsub(name, " Invasion$", "")
          beforeId = "INVASION-" .. tostring(args[1].id or string.gsub(string.lower(name), "%s+", "-"))
        end
        local before = beforeId and p6_material_signature(self.publicGroups and self.publicGroups[beforeId]) or ""
        local results = {pcall(old, self, unpack(args))}
        if not results[1] then error(results[2], 0) end
        local row = results[2] or (beforeId and self.publicGroups and self.publicGroups[beforeId])
        local after = p6_material_signature(row)
        if before ~= after then self:SF151_InvalidatePublicGroupsData(methodName, row and row.id or beforeId) end
        return unpack(results, 2)
      end
    end
    p6_wrap_row_mutation("MirrorListingToPublic")
    p6_wrap_row_mutation("UpsertInvasionPublicListing")

    local function p6_wrap_removal(methodName, countBefore)
      local old = B[methodName]
      if type(old) ~= "function" then return end
      B[methodName] = function(self, ...)
        local before = countBefore(self, ...)
        local results = {pcall(old, self, ...)}
        if not results[1] then error(results[2], 0) end
        if before > 0 then self:SF151_InvalidatePublicGroupsData(methodName) end
        return unpack(results, 2)
      end
    end
    p6_wrap_removal("RemovePublicMirrorForListing", function(self, listingId)
      local count = 0
      for id, row in pairs(self.publicGroups or {}) do
        if id == "listing-" .. tostring(listingId) or (row and row.listingId == listingId) then count = count + 1 end
      end
      return count
    end)
    p6_wrap_removal("RemoveInvasionBeaconFromPublic", function(self, id)
      return self.publicGroups and self.publicGroups["INVASION-" .. tostring(id)] and 1 or 0
    end)
    p6_wrap_removal("ClearInvasionData", function(self)
      local count = 0
      for _, row in pairs(self.publicGroups or {}) do if p6_is_invasion(row) then count = count + 1 end end
      return count
    end)
    p6_wrap_removal("ClearPublicGroups", function(self) return p6_count(self.publicGroups) end)

    local oldCleanupInvasion = B.CleanupInvasionNetworkData
    if type(oldCleanupInvasion) == "function" then
      B.CleanupInvasionNetworkData = function(self, ...)
        local before = 0
        for _, row in pairs(self.publicGroups or {}) do if p6_is_invasion(row) then before = before + 1 end end
        local results = {pcall(oldCleanupInvasion, self, ...)}
        if not results[1] then error(results[2], 0) end
        local after = 0
        for _, row in pairs(self.publicGroups or {}) do if p6_is_invasion(row) then after = after + 1 end end
        if before ~= after then self:SF151_InvalidatePublicGroupsData("invasion-cleanup") end
        return unpack(results, 2)
      end
    end

    B.GetSortedPublicGroups = function()
      local results = {pcall(p6_view)}
      if not results[1] then PG.dirty = true; return {} end
      return results[2].rows
    end
    B.GetPublicFilterCounts = function()
      local results = {pcall(p6_snapshot)}
      if not results[1] then PG.dirty = true; return {} end
      return results[2].counts
    end

    PG.legacyRefreshOwner = PG.legacyRefreshOwner or Refresh.original.publicGroups
    Refresh.original.publicGroups = function() return PG.Render() end

    function B:SF151_ResetPublicGroupsViewStats()
      PG.stats = {}
      PG.lastError = nil
      return true
    end

    function B:SF151_GetPublicGroupsViewDiagnostics()
      local report = {
        owner=PG.generationName, dataGeneration=PG.dataGeneration,
        snapshotGeneration=PG.snapshotGeneration or 0, dirty=PG.dirty == true,
        cachedViews=#(PG.viewOrder or {}), rendering=PG.rendering == true,
        lastError=PG.lastError,
      }
      for key, value in pairs(PG.stats or {}) do report[key] = value end
      return report
    end

    function B:SF151_PrintPublicGroupsViewDiagnostics()
      local d = self:SF151_GetPublicGroupsViewDiagnostics()
      local function out(text)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. text) end
      end
      out("public view owner " .. tostring(d.owner) .. ", generation=" .. tostring(d.dataGeneration)
        .. ", snapshot=" .. tostring(d.snapshotGeneration) .. ", views=" .. tostring(d.cachedViews) .. ", dirty=" .. tostring(d.dirty))
      out("snapshot: requests=" .. tostring(d.snapshotRequests or 0) .. ", built=" .. tostring(d.snapshotsBuilt or 0)
        .. ", hits=" .. tostring(d.snapshotCacheHits or 0) .. ", rows=" .. tostring(d.canonicalRowsProcessed or 0)
        .. ", normalized=" .. tostring(d.normalizedStringsGenerated or 0) .. ", sorts=" .. tostring(d.canonicalSorts or 0))
      out("views: requests=" .. tostring(d.viewRequests or 0) .. ", built=" .. tostring(d.viewsBuilt or 0)
        .. ", hits=" .. tostring(d.viewCacheHits or 0) .. ", filters=" .. tostring(d.filterScans or 0)
        .. ", searches=" .. tostring(d.searchScans or 0) .. ", sorts=" .. tostring(d.viewSorts or 0)
        .. ", offPageFormatted=" .. tostring(d.offPageRowsFormatted or 0))
      out("render: requests=" .. tostring(d.visibleRenderRequests or 0) .. ", executed=" .. tostring(d.visibleRendersExecuted or 0)
        .. ", hidden=" .. tostring(d.hiddenRendersSkipped or 0) .. ", rows=" .. tostring(d.rowsConsidered or 0)
        .. ", written=" .. tostring(d.rowsFullyWritten or 0) .. ", signatureHits=" .. tostring(d.rowRenderSignatureHits or 0)
        .. ", setText=" .. tostring(d.setTextCalls or 0) .. ", backdrop=" .. tostring(d.backdropWrites or 0))
      out("detail: requests=" .. tostring(d.detailRenderRequests or 0) .. ", executed=" .. tostring(d.detailRendersExecuted or 0)
        .. ", hits=" .. tostring(d.detailSignatureHits or 0) .. ", errors=" .. tostring(d.renderErrors or 0))
      out("expiry: checks=" .. tostring(d.expirationChecks or 0) .. ", expired=" .. tostring(d.rowsExpired or 0)
        .. ", unchanged=" .. tostring(d.noChangeExpirationChecks or 0) .. ", wakes=" .. tostring(d.scheduledExpiryWakes or 0)
        .. ", indexRemovals=" .. tostring(d.expirationIndexRemovals or 0))
      return d
    end

    local startup = CreateFrame and CreateFrame("Frame") or nil
    if startup then
      startup:RegisterEvent("PLAYER_LOGIN")
      startup:RegisterEvent("PLAYER_ENTERING_WORLD")
      startup:SetScript("OnEvent", function()
        p6_attach_panel(B.publicPanel)
        PG.RescheduleExpiry()
      end)
      PG.eventFrame = startup
    end
  end
end
-- SIGNALFIRE_PHASE6_PUBLIC_GROUPS_VIEW_END

if SignalFire_InstallPhase6 then SignalFire_InstallPhase6() end

-- Phase 2 UI lifecycle stabilization. This late owner keeps the compatibility
-- wrapper chain intact for first-build recovery, then makes repeated UI calls
-- cheap and replaces whole-tree dropdown discovery with explicit registration.
-- SIGNALFIRE_PHASE2_UI_LIFECYCLE_BEGIN
do
  local B = _G.BronzeLFG
  if B then
    local L = _G.SignalFireUILifecycle151 or {}
    _G.SignalFireUILifecycle151 = L
    L.generation = "1.5.1-perf-phase2"
    L.initialized = L.initialized == true
    L.uiGeneration = tonumber(L.uiGeneration or 0) or 0
    L.transactionDepth = tonumber(L.transactionDepth or 0) or 0
    L.previewSignatures = L.previewSignatures or {}
    L.moduleKeys = L.moduleKeys or {
      "chatParsing", "guildBrowser", "recruitmentCreator", "events", "notices", "invasions", "ascensionListingTools",
    }

    -- Dropdown registration is session-only and stored on each dropdown frame.
    -- Owner: SignalFireUILifecycle151; key: dropdown frame; maximum: one marker
    -- per created dropdown; TTL: frame lifetime; eviction/cleanup: UI reload.
    -- No registry table is retained, so destroyed frames cannot accumulate here.
    local function p2_note(field, amount)
      local perf = _G.SignalFirePerf151
      if perf and perf.enabled and perf.Note then perf:Note("ui", field, amount or 1) end
    end

    local function p2_pack(...)
      return {n=select("#", ...), ...}
    end

    local function p2_return(results)
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end

    local function p2_dropdown_text(dropdown)
      if not dropdown then return "" end
      if _G.BLFG_DropdownText then
        local ok, value = pcall(_G.BLFG_DropdownText, dropdown)
        if ok then return tostring(value or "") end
      end
      if UIDropDownMenu_GetText then
        local ok, value = pcall(UIDropDownMenu_GetText, dropdown)
        if ok then return tostring(value or "") end
      end
      if dropdown.GetText then
        local ok, value = pcall(dropdown.GetText, dropdown)
        if ok then return tostring(value or "") end
      end
      return ""
    end

    local function p2_text(control)
      if not control or not control.GetText then return "" end
      local ok, value = pcall(control.GetText, control)
      return ok and tostring(value or "") or ""
    end

    local function p2_checked(control)
      if not control or not control.GetChecked then return "0" end
      local ok, value = pcall(control.GetChecked, control)
      return ok and value and "1" or "0"
    end

    local function p2_profile_id(self)
      if self and self.SF143_GetProfileId then
        local ok, value = pcall(self.SF143_GetProfileId, self)
        if ok and value then return tostring(value) end
      end
      return tostring(BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "")
    end

    local function p2_module_signature(profile)
      local options = BronzeLFG_DB and BronzeLFG_DB.options or nil
      local global = options and options.modules or nil
      local scoped = options and options.modulesByProfile and options.modulesByProfile[profile] or nil
      local out = ""
      for _, key in ipairs(L.moduleKeys) do
        local value = scoped and scoped[key]
        if value == nil and global then value = global[key] end
        out = out .. key .. "=" .. tostring(value) .. ";"
      end
      return out
    end

    local function p2_create_signature(self, target)
      self = self or B
      local profile = p2_profile_id(self)
      return tostring(target or "create") .. "|g=" .. tostring(L.uiGeneration)
        .. "|p=" .. profile .. "|m=" .. p2_module_signature(profile)
        .. "|f=" .. tostring(self.frame) .. "|c=" .. tostring(self.create)
        .. "|td=" .. tostring(self.typeDrop) .. ":" .. p2_dropdown_text(self.typeDrop)
        .. "|ad=" .. tostring(self.activityDrop) .. ":" .. p2_dropdown_text(self.activityDrop)
        .. "|sd=" .. tostring(self.specificDungeonDrop) .. ":" .. p2_dropdown_text(self.specificDungeonDrop)
        .. "|dd=" .. tostring(self.diffDrop) .. ":" .. p2_dropdown_text(self.diffDrop)
        .. "|kd=" .. p2_text(self.keyBox)
        .. "|roles=" .. p2_checked(self.needTank) .. p2_checked(self.needHealer) .. p2_checked(self.needDPS)
        .. "|voice=" .. p2_dropdown_text(self.voiceDrop) .. "|loot=" .. p2_dropdown_text(self.lootDrop)
        .. "|min=" .. p2_text(self.minIlvlBox) .. "|max=" .. p2_text(self.maxBox)
        .. "|note=" .. p2_text(self.noteBox)
        .. "|preview=" .. tostring(self.sfamCreatePreview) .. ":" .. tostring(self.sf1429Preview)
    end

    local function p2_options_signature(self)
      self = self or B
      local options = BronzeLFG_DB and BronzeLFG_DB.options or nil
      local profile = p2_profile_id(self)
      return "options|g=" .. tostring(L.uiGeneration) .. "|p=" .. profile
        .. "|m=" .. p2_module_signature(profile) .. "|panel=" .. tostring(self.optionsPanel)
        .. "|server=" .. p2_dropdown_text(self.serverProfileDD)
        .. "|key=" .. tostring(options and options.notifyKeyFilter or "")
        .. "|raid=" .. tostring(options and options.notifyRaidFilter or "")
        .. "|dungeon=" .. tostring(options and options.notifyDungeonFilter or "")
    end

    local function p2_identity_signature(self)
      self = self or B
      return "identity|g=" .. tostring(L.uiGeneration) .. "|p=" .. p2_profile_id(self)
        .. "|frame=" .. tostring(self.frame) .. "|options=" .. tostring(self.optionsPanel)
        .. "|modules=" .. tostring(self.sfmmOpenButton) .. ":" .. tostring(self.sfcpOpenButton)
        .. ":" .. tostring(self.sfn138FavoriteAlertButton) .. ":" .. tostring(self.sfamPolishButton)
        .. ":" .. tostring(self.sfe141EventAlertButton)
    end

    local function p2_core_complete(self)
      return self and self.frame and self.content and self.side and self.browse
        and self.create and self.typeDrop and self.activityDrop and self.diffDrop
        and self.profile and self.profileRole and self.apps and self.publicPanel
        and self.onlinePanel and self.guildPanel and self.optionsPanel and self.myPanel
    end

    L.originalFixDropdown = L.originalFixDropdown or _G.BLFG_FixDropdownButton

    function L:RegisterDropdown(dropdown)
      if not dropdown then return false end
      if not dropdown._signalFireDropdownRegistered then
        dropdown._signalFireDropdownRegistered = true
        p2_note("dropdownsRegistered", 1)
      end
      local mode = dropdown.SFDisableNativeMenu and "suppressed" or "native"
      if dropdown._signalFireDropdownPatched == mode then
        p2_note("dropdownPatchSkips", 1)
        return true
      end
      local fixer = self.originalFixDropdown
      if type(fixer) == "function" then
        local ok, err = pcall(fixer, dropdown)
        if not ok then error(err, 0) end
      elseif dropdown.SFDisableNativeMenu and _G.BLFG_SF1430H_SuppressNativeDropdown then
        _G.BLFG_SF1430H_SuppressNativeDropdown(dropdown)
      end
      dropdown._signalFireDropdownPatched = mode
      p2_note("dropdownsPatched", 1)
      return true
    end

    L.knownDropdownFields = L.knownDropdownFields or {
      "typeDrop", "activityDrop", "specificDungeonDrop", "diffDrop", "voiceDrop", "lootDrop",
      "profileRole", "serverProfileDD", "scaleDropdown", "eventFilterDD", "raidFilterDD", "keyFilterDD",
      "dungeonFilterDD", "dungeonFilterDD5612", "dungeonAlertDropdown5613", "dungeonAlertDropdown5614",
      "dungeonAlertDropdown5615", "publicSortDropdown", "publicHideTypesDropdown", "focusDropdown",
      "keystoneAlertDropdown",
    }

    function L:RegisterKnownDropdowns(owner)
      owner = owner or B
      for _, field in ipairs(self.knownDropdownFields) do
        if owner[field] then self:RegisterDropdown(owner[field]) end
      end
      if owner.sfcpPanel and owner.sfcpPanel.scopeDropdown then
        self:RegisterDropdown(owner.sfcpPanel.scopeDropdown)
      end
    end

    _G.BLFG_FixDropdownButton = function(dropdown)
      return L:RegisterDropdown(dropdown)
    end

    -- Compatibility names remain callable, but no longer recurse through any
    -- parent tree. Existing wrappers therefore become bounded registration calls.
    _G.BLFG_SF135J_FixAllDropdowns = function(dropdown)
      if dropdown and dropdown.GetName then
        local name = dropdown:GetName()
        if dropdown.SFDisableNativeMenu or (name and _G[name .. "Button"]) then
          return L:RegisterDropdown(dropdown)
        end
      end
      return false
    end

    _G.BLFG_SF135J_FixVisibleDropdowns = function()
      L:RegisterKnownDropdowns(B)
      return true
    end

    function L:BeginTransaction()
      self.transactionDepth = (tonumber(self.transactionDepth or 0) or 0) + 1
    end

    function L:EndTransaction(owner, successful)
      self.transactionDepth = math.max(0, (tonumber(self.transactionDepth or 1) or 1) - 1)
      if self.transactionDepth == 0 and self.previewPending then
        self.previewPending = nil
        if successful then
          local ok, err = pcall(self.FlushPreviews, self, owner or B)
          if not ok then return false, err end
        end
      end
      return true
    end

    function L:InvokeTransactional(fn, owner, ...)
      self:BeginTransaction()
      local results = p2_pack(pcall(fn, owner, ...))
      local ended, endError = self:EndTransaction(owner, results[1])
      if results[1] and not ended then return {n=2, false, endError} end
      return results
    end

    local function p2_install_preview_owner(target, methodName, key)
      local old = target and target[methodName]
      if type(old) ~= "function" then return end
      target[methodName] = function(self, ...)
        p2_note("previewUpdatesRequested", 1)
        if L.transactionDepth > 0 then
          L.previewPending = true
          p2_note("previewUpdatesDeferred", 1)
          return
        end
        local signature = p2_create_signature(self, key)
        if L.previewSignatures[key] == signature then
          p2_note("previewUpdatesSkipped", 1)
          return
        end
        if L.previewActive then
          L.previewPending = true
          p2_note("previewUpdatesDeferred", 1)
          return
        end
        L.previewActive = true
        local results = p2_pack(pcall(old, self, ...))
        L.previewActive = nil
        if results[1] then
          L.previewSignatures[key] = p2_create_signature(self, key)
          p2_note("previewUpdatesExecuted", 1)
        end
        return p2_return(results)
      end
    end

    p2_install_preview_owner(B, "SFAM_UpdateCreatePreview", "posting")
    local SFALP = _G.SignalFireAscensionListingPolish
    if SFALP then p2_install_preview_owner(SFALP, "UpdatePreview", "compact") end

    function L:FlushPreviews(owner)
      owner = owner or B
      if owner.SFAM_UpdateCreatePreview then owner:SFAM_UpdateCreatePreview() end
      local polish = _G.SignalFireAscensionListingPolish
      if polish and polish.UpdatePreview then polish.UpdatePreview(owner) end
    end

    local function p2_install_signature_owner(target, methodName, signatureFn, stateKey, requestedField, executedField, skippedField, registerDropdowns)
      local old = target and target[methodName]
      if type(old) ~= "function" then return end
      target[methodName] = function(self, ...)
        p2_note(requestedField, 1)
        local signature = signatureFn(self)
        if L[stateKey] == signature or L[stateKey .. "Active"] then
          p2_note(skippedField, 1)
          return
        end
        L[stateKey .. "Active"] = true
        local results = L:InvokeTransactional(old, self, ...)
        L[stateKey .. "Active"] = nil
        if results[1] then
          L[stateKey] = signatureFn(self)
          p2_note(executedField, 1)
          if registerDropdowns then L:RegisterKnownDropdowns(self) end
        end
        return p2_return(results)
      end
    end

    p2_install_signature_owner(B, "SF143_ApplyProfileToCreate",
      function(self) return p2_create_signature(self, "profile-create") end,
      "lastCreateProfileSignature", "profileApplicationsRequested", "profileApplicationsExecuted", "profileApplicationsSkipped", true)

    p2_install_signature_owner(B, "SF143_ApplyProfileToOptions", p2_options_signature,
      "lastOptionsProfileSignature", "profileApplicationsRequested", "profileApplicationsExecuted", "profileApplicationsSkipped", true)

    if SFALP then
      p2_install_signature_owner(SFALP, "ApplyUI",
        function(self) return p2_create_signature(self, "apply-ui") end,
        "lastApplyUISignature", "applyUIRequests", "applyUIExecutions", "applyUISkips", true)
    end

    p2_install_signature_owner(B, "UpdateCreateControls",
      function(self) return p2_create_signature(self, "controls") end,
      "lastControlsSignature", "createControlRequests", "createControlExecutions", "createControlSkips", true)

    p2_install_signature_owner(B, "SFUI1434_Apply", p2_identity_signature,
      "lastIdentitySignature", "identityRequests", "identityExecutions", "identitySkips", false)

    local oldShowCreate = B.ShowCreate
    if type(oldShowCreate) == "function" then
      B.ShowCreate = function(self, ...)
        local results = L:InvokeTransactional(oldShowCreate, self, ...)
        return p2_return(results)
      end
    end

    local oldCreateUI = B.CreateUI
    if type(oldCreateUI) == "function" then
      B.CreateUI = function(self, ...)
        p2_note("createUIRequests", 1)
        if L.initialized and p2_core_complete(self) then
          p2_note("createUIFastPath", 1)
          return
        end
        if L.createUIActive then
          p2_note("createUIFastPath", 1)
          return
        end
        p2_note("createUIFullExecutions", 1)
        L.createUIActive = true
        L.uiGeneration = (tonumber(L.uiGeneration or 0) or 0) + 1
        local results = L:InvokeTransactional(oldCreateUI, self, ...)
        L.createUIActive = nil
        if results[1] then
          L.initialized = p2_core_complete(self) and true or false
          L:RegisterKnownDropdowns(self)
        end
        return p2_return(results)
      end
    end

    function B:SF151_GetUILifecycleDiagnostics()
      local perf = _G.SignalFirePerf151
      local ui = perf and perf.stats and perf.stats.ui or {}
      return {
        generation=L.generation,
        initialized=L.initialized == true,
        createUIRequests=ui.createUIRequests or 0,
        createUIFullExecutions=ui.createUIFullExecutions or 0,
        createUIFastPath=ui.createUIFastPath or 0,
        dropdownsRegistered=ui.dropdownsRegistered or 0,
        dropdownsPatched=ui.dropdownsPatched or 0,
        dropdownPatchSkips=ui.dropdownPatchSkips or 0,
        profileApplicationsRequested=ui.profileApplicationsRequested or 0,
        profileApplicationsExecuted=ui.profileApplicationsExecuted or 0,
        profileApplicationsSkipped=ui.profileApplicationsSkipped or 0,
        previewUpdatesRequested=ui.previewUpdatesRequested or 0,
        previewUpdatesExecuted=ui.previewUpdatesExecuted or 0,
        previewUpdatesSkipped=ui.previewUpdatesSkipped or 0,
      }
    end

    if B.frame then
      L.initialized = p2_core_complete(B) and true or false
      L:RegisterKnownDropdowns(B)
    end
  end
end
-- SIGNALFIRE_PHASE2_UI_LIFECYCLE_END

-- Phase 3 generation-cached Network and Full Roster ownership.
-- SIGNALFIRE_PHASE3_NETWORK_ROSTER_BEGIN
do
  local B = _G.BronzeLFG
  if B then
    local R = _G.SignalFireRosterSnapshot151 or {}
    _G.SignalFireRosterSnapshot151 = R
    R.owner = "1.5.1-perf-phase3"
    R.generation = tonumber(R.generation or 1) or 1
    R.stats = R.stats or {}
    R.viewCache = R.viewCache or {}
    R.viewOrder = R.viewOrder or {}
    R.classCache = R.classCache or {}
    R.sourceSignatures = R.sourceSignatures or {}
    R.maximumRows = 512
    R.maximumViews = 16
    R.maximumClassEntries = 128
    R.classTTL = 1800

    -- Session caches owned by SignalFireRosterSnapshot151:
    -- canonical snapshot: key=roster generation, max=1, TTL=until source
    -- invalidation or earliest 180/300-second source expiry, cleared on invalidation.
    -- filtered views: key=generation/filter/search/guild, max=16, TTL=generation
    -- lifetime, FIFO eviction on insertion and full cleanup on invalidation.
    -- class cache: key=normalized player name, max=128, TTL=1800 seconds,
    -- oldest-entry eviction during snapshot construction. Presence/status/friend/
    -- guild lookup maps use normalized-name keys, max=512, TTL=one generation;
    -- the unit map uses the fixed 48-token set. All are cleared by invalidation.
    -- None of these caches are persisted.

    R.unitTokens = R.unitTokens or (function()
      local values = {"player", "target", "focus", "mouseover"}
      for i = 1, 4 do table.insert(values, "party" .. tostring(i)) end
      for i = 1, 40 do table.insert(values, "raid" .. tostring(i)) end
      return values
    end)()

    local function p3_now()
      return (time and time()) or 0
    end

    local function p3_clock_ms()
      if debugprofilestop then return debugprofilestop() end
      return ((GetTime and GetTime()) or 0) * 1000
    end

    local function p3_trim(value)
      local s = tostring(value or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function p3_key(value)
      local s = string.lower(p3_trim(value))
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "%-.*$", "")
      s = string.gsub(s, "%s+", "")
      return s
    end

    local function p3_nonempty(value)
      local s = p3_trim(value)
      if s == "" or s == "Unknown" or s == "UNKNOWN" then return nil end
      return s
    end

    local function p3_perf_enabled()
      local perf = _G.SignalFirePerf151
      return perf and perf.enabled == true
    end

    local function p3_note(field, amount)
      if not p3_perf_enabled() then return end
      R.stats[field] = (R.stats[field] or 0) + (amount or 1)
    end

    local function p3_max(field, value)
      if not p3_perf_enabled() then return end
      value = tonumber(value or 0) or 0
      if value > (R.stats[field] or 0) then R.stats[field] = value end
    end

    local function p3_profile()
      if B.SF143_GetProfileId then
        local ok, value = pcall(B.SF143_GetProfileId, B)
        if ok and p3_nonempty(value) then return tostring(value) end
      end
      return tostring(BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "Triumvirate")
    end

    local function p3_is_ascension()
      local value = string.lower(p3_profile())
      return string.find(value, "ascension", 1, true) ~= nil or value == "coa"
    end

    local function p3_localized_class(token)
      local value = p3_nonempty(token)
      if not value then return nil end
      local upper = string.upper(value)
      if LOCALIZED_CLASS_NAMES_MALE and p3_nonempty(LOCALIZED_CLASS_NAMES_MALE[upper]) then return LOCALIZED_CLASS_NAMES_MALE[upper] end
      if LOCALIZED_CLASS_NAMES_FEMALE and p3_nonempty(LOCALIZED_CLASS_NAMES_FEMALE[upper]) then return LOCALIZED_CLASS_NAMES_FEMALE[upper] end
      return nil
    end

    local function p3_display_candidate(value)
      local s = p3_nonempty(value)
      if not s then return nil end
      if string.find(s, "^[A-Z_]+$") then return p3_localized_class(s) end
      return s
    end

    local function p3_request_panels(mode)
      if B.SF151_RequestPanelRefresh then
        B:SF151_RequestPanelRefresh("network", mode)
        B:SF151_RequestPanelRefresh("roster", mode)
      end
    end

    local function p3_clear_views()
      R.viewCache = {}
      R.viewOrder = {}
    end

    function B:SF151_InvalidateRosterData(reason, name)
      R.generation = (tonumber(R.generation or 0) or 0) + 1
      R.snapshot = nil
      R.snapshotGeneration = nil
      R.nextExpiry = nil
      R.presenceByNameKey = nil
      R.statusByNameKey = nil
      R.unitByNameKey = nil
      R.guildByNameKey = nil
      R.friendByNameKey = nil
      R.rowByNameKey = nil
      p3_clear_views()
      p3_note("generationIncrements", 1)
      R.lastInvalidationReason = tostring(reason or "unknown")
      R.lastInvalidationName = tostring(name or "")
      return R.generation
    end

    function B:SF151_NoteRosterSnapshotStat(field, amount)
      p3_note(tostring(field or "unknown"), amount or 1)
    end

    local function p3_prune_class_cache(nowStamp)
      local count, order = 0, {}
      for key, record in pairs(R.classCache) do
        local seen = tonumber(record and record.seen or 0) or 0
        if seen <= 0 or (nowStamp - seen) > R.classTTL then
          R.classCache[key] = nil
          p3_note("classEntriesPruned", 1)
        else
          count = count + 1
          table.insert(order, {key=key, seen=seen})
        end
      end
      if count > R.maximumClassEntries then
        table.sort(order, function(a, b) return a.seen < b.seen end)
        for i = 1, count - R.maximumClassEntries do
          if order[i] and R.classCache[order[i].key] then
            R.classCache[order[i].key] = nil
            p3_note("classEntriesPruned", 1)
          end
        end
      end
    end

    local function p3_build_unit_map()
      local map = {}
      p3_note("unitMapBuilds", 1)
      if UnitName then
        for _, token in ipairs(R.unitTokens) do
          p3_note("unitTokensInspected", 1)
          if not UnitExists or UnitExists(token) then
            local name = UnitName(token)
            local key = p3_key(name)
            if key ~= "" then
              local className, classFile = nil, nil
              if UnitClass then className, classFile = UnitClass(token) end
              map[key] = {token=token, name=name, className=className, classFile=classFile}
            end
          end
        end
      end
      R.unitByNameKey = map
      return map
    end

    local function p3_build_friend_map()
      local map = {}
      if GetNumFriends and GetFriendInfo then
        local count = math.min(512, tonumber(GetNumFriends() or 0) or 0)
        for i = 1, count do
          local name = GetFriendInfo(i)
          local key = p3_key(name)
          if key ~= "" then map[key] = true end
        end
      end
      R.friendByNameKey = map
      return map
    end

    local function p3_build_guild_map()
      local map = {}
      if GetNumGuildMembers and GetGuildRosterInfo then
        local count = math.min(512, tonumber(GetNumGuildMembers() or 0) or 0)
        for i = 1, count do
          local name, _, _, level, className, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
          local key = p3_key(name)
          if key ~= "" then
            map[key] = {name=name, level=level, className=className, classFile=classFile, zone=zone, online=online}
          end
        end
      end
      R.guildByNameKey = map
      return map
    end

    local function p3_cache_class(key, value, nowStamp)
      if key ~= "" and value and value ~= "Unknown" then
        R.classCache[key] = {value=value, seen=nowStamp}
      end
    end

    function B:SF151_ResolveClassDisplay(row)
      row = row or {}
      local nowStamp = p3_now()
      local key = p3_key(row.name)
      local value = p3_display_candidate(row.className) or p3_display_candidate(row.class)
      local unit = key ~= "" and R.unitByNameKey and R.unitByNameKey[key] or nil
      if not value and unit then
        value = p3_display_candidate(unit.className)
        if not p3_nonempty(row.classFile) then row.classFile = p3_nonempty(unit.classFile) or row.classFile end
      end
      if not value and key ~= "" then
        local cached = R.classCache[key]
        if cached and (nowStamp - (tonumber(cached.seen or 0) or 0)) <= R.classTTL then value = p3_nonempty(cached.value) end
      end
      if not value then value = p3_localized_class(row.classFile) end
      if not value then value = "Unknown" end
      row.className = value
      p3_cache_class(key, value, nowStamp)
      return value
    end

    local function p3_copy_fields(target, source, overwrite)
      for _, field in ipairs({"version", "level", "className", "class", "classFile", "role", "spec", "zone", "guild", "looking", "status", "sfnRoleFlags", "flags"}) do
        local value = source and source[field]
        if p3_nonempty(value) and (overwrite or not p3_nonempty(target[field])) then target[field] = value end
      end
      local seen = tonumber(source and source.seen or 0) or 0
      if seen > (tonumber(target.seen or 0) or 0) then target.seen = seen end
    end

    local function p3_new_row(name)
      return {name=tostring(name or ""), seen=0, self=false, friend=false, groupmate=false, favorite=false, whoOnly=false}
    end

    local function p3_snapshot_build()
      local started = p3_clock_ms()
      local nowStamp = p3_now()
      local byKey, rows = {}, {}
      local presenceMap, statusMap = {}, {}
      local unitMap = p3_build_unit_map()
      local friendMap = p3_build_friend_map()
      local guildMap = p3_build_guild_map()
      local nextExpiry = nil

      p3_prune_class_cache(nowStamp)
      p3_note("statusMapBuilds", 1)

      local function ensure(name)
        local key = p3_key(name)
        if key == "" then return nil, key end
        local row = byKey[key]
        if not row then
          row = p3_new_row(name)
          byKey[key] = row
          table.insert(rows, row)
        end
        return row, key
      end

      for tableKey, source in pairs(B.onlineUsers or {}) do
        local seen = tonumber(source and source.seen or 0) or 0
        if not source or seen <= 0 or (nowStamp - seen) > 180 then
          B.onlineUsers[tableKey] = nil
          p3_note("staleUsersRemoved", 1)
        else
          local row, key = ensure(source.name or tableKey)
          if row then
            p3_copy_fields(row, source, seen >= (tonumber(row.seen or 0) or 0))
            presenceMap[key] = source
            local expiry = seen + 180
            if not nextExpiry or expiry < nextExpiry then nextExpiry = expiry end
          end
        end
      end

      for tableKey, source in pairs(B.sfnStatuses or {}) do
        p3_note("statusComparisons", 1)
        local seen = tonumber(source and source.seen or 0) or 0
        if not source or seen <= 0 or (nowStamp - seen) > 180 then
          B.sfnStatuses[tableKey] = nil
          p3_note("staleStatusesRemoved", 1)
        else
          local row, key = ensure(source.name or tableKey)
          if row then
            p3_copy_fields(row, source, false)
            statusMap[key] = source
            local expiry = seen + 180
            if not nextExpiry or expiry < nextExpiry then nextExpiry = expiry end
          end
        end
      end

      if not p3_is_ascension() then
        local who = BronzeLFG_DB and BronzeLFG_DB.whoPlayers or B.whoPlayers or {}
        for tableKey, source in pairs(who or {}) do
          local seen = tonumber(source and source.seen or 0) or 0
          if source and seen > 0 and (nowStamp - seen) <= 300 then
            local row = ensure(source.name or tableKey)
            if row and not presenceMap[p3_key(source.name or tableKey)] and not statusMap[p3_key(source.name or tableKey)] then
              p3_copy_fields(row, source, false)
              row.whoOnly = true
              row.version = "/who"
            end
            local expiry = seen + 300
            if not nextExpiry or expiry < nextExpiry then nextExpiry = expiry end
          end
        end
      end

      local selfName = UnitName and UnitName("player") or "Unknown"
      local selfRow, selfKey = ensure(selfName)
      if selfRow then
        local className, classFile = nil, nil
        if UnitClass then className, classFile = UnitClass("player") end
        selfRow.name = selfName
        selfRow.version = tostring(_G.SignalFire_VERSION or "1.5.1")
        selfRow.level = tostring(UnitLevel and UnitLevel("player") or "")
        selfRow.className = className or selfRow.className
        selfRow.classFile = classFile or selfRow.classFile
        selfRow.role = BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.role or selfRow.role
        selfRow.spec = BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.roleType or selfRow.spec
        selfRow.zone = GetZoneText and GetZoneText() or selfRow.zone
        selfRow.guild = GetGuildInfo and GetGuildInfo("player") or selfRow.guild
        selfRow.seen = nowStamp
        selfRow.self = true
        selfRow.whoOnly = false
        presenceMap[selfKey] = selfRow
      end

      local myGuild = tostring(GetGuildInfo and GetGuildInfo("player") or "")
      for _, row in ipairs(rows) do
        local key = p3_key(row.name)
        local unit = unitMap[key]
        local guild = guildMap[key]
        row.friend = friendMap[key] == true
        row.groupmate = unit ~= nil and not row.self
          and (string.find(tostring(unit.token or ""), "^party") ~= nil or string.find(tostring(unit.token or ""), "^raid") ~= nil)
        if unit then
          if not p3_nonempty(row.className) then row.className = unit.className end
          if not p3_nonempty(row.classFile) then row.classFile = unit.classFile end
        end
        if guild then
          if not p3_nonempty(row.level) then row.level = guild.level end
          if not p3_nonempty(row.className) then row.className = guild.className end
          if not p3_nonempty(row.classFile) then row.classFile = guild.classFile end
          if not p3_nonempty(row.zone) then row.zone = guild.zone end
          if not p3_nonempty(row.guild) then row.guild = myGuild end
        end
        row.favorite = B.IsFavorite and B:IsFavorite(row.name) or false
        B:SF151_ResolveClassDisplay(row)
        row.status = row.status or row.looking
        p3_note("rowsProcessedPerCanonicalBuild", 1)
      end

      p3_note("canonicalSorts", 1)
      table.sort(rows, function(a, b)
        if a.self and not b.self then return true end
        if b.self and not a.self then return false end
        if a.favorite and not b.favorite then return true end
        if b.favorite and not a.favorite then return false end
        if a.friend and not b.friend then return true end
        if b.friend and not a.friend then return false end
        if a.groupmate and not b.groupmate then return true end
        if b.groupmate and not a.groupmate then return false end
        if a.whoOnly and not b.whoOnly then return false end
        if b.whoOnly and not a.whoOnly then return true end
        local as = tonumber(a.seen or 0) or 0
        local bs = tonumber(b.seen or 0) or 0
        if as ~= bs then return as > bs end
        return tostring(a.name or "") < tostring(b.name or "")
      end)

      while #rows > R.maximumRows do
        local removed = table.remove(rows)
        if removed then byKey[p3_key(removed.name)] = nil end
        p3_note("snapshotEntriesEvicted", 1)
      end

      for key in pairs(presenceMap) do if not byKey[key] then presenceMap[key] = nil end end
      for key in pairs(statusMap) do if not byKey[key] then statusMap[key] = nil end end

      R.presenceByNameKey = presenceMap
      R.statusByNameKey = statusMap
      R.rowByNameKey = byKey
      R.nextExpiry = nextExpiry
      R.snapshot = rows
      R.snapshotGeneration = R.generation
      p3_note("canonicalSnapshotsBuilt", 1)
      p3_max("maximumSnapshotRows", #rows)
      p3_max("maximumSnapshotBuildMs", math.max(0, p3_clock_ms() - started))
      return rows
    end

    function B:GetOnlineUserRows()
      p3_note("canonicalSnapshotRequests", 1)
      local nowStamp = p3_now()
      if R.snapshot and R.snapshotGeneration == R.generation and R.nextExpiry and nowStamp >= R.nextExpiry then
        self:SF151_InvalidateRosterData("stale-expiry")
      end
      if R.snapshot and R.snapshotGeneration == R.generation then
        p3_note("snapshotCacheHits", 1)
        p3_note("fullRosterScansAvoided", 1)
        return R.snapshot
      end
      if R.building then return R.snapshot or {} end
      R.building = true
      local results = {pcall(p3_snapshot_build)}
      R.building = nil
      if not results[1] then error(results[2], 0) end
      return results[2]
    end

    local function p3_copy_row(source)
      local target = {}
      for key, value in pairs(source or {}) do target[key] = value end
      return target
    end

    local function p3_matches(row, needle)
      if needle == "" then return true end
      local blob = string.lower(table.concat({
        tostring(row.name or ""), tostring(row.guild or ""), tostring(row.zone or ""),
        tostring(row.role or ""), tostring(row.spec or ""), tostring(row.className or row.class or ""),
        tostring(row.classFile or "")
      }, " "))
      return string.find(blob, needle, 1, true) ~= nil
    end

    function B:SFRP_GetRosterRows()
      local snapshot = self:GetOnlineUserRows() or {}
      local filter = tostring(self.onlineFilter or "All")
      if p3_is_ascension() and filter == "Who" then filter = "All"; self.onlineFilter = "All"; self.onlinePage = 1 end
      local search = ""
      if self.fullRosterSearch and self.fullRosterSearch.GetText then search = string.lower(p3_trim(self.fullRosterSearch:GetText() or "")) end
      local myGuild = tostring(GetGuildInfo and GetGuildInfo("player") or "")
      local signature = table.concat({tostring(R.generation), filter, search, myGuild}, "\31")
      local cached = R.viewCache[signature]
      if cached then
        p3_note("filteredViewCacheHits", 1)
        return cached.rows, snapshot
      end

      local started = p3_clock_ms()
      local rows = {}
      for _, source in ipairs(snapshot) do
        local keep = true
        if filter == "SignalFire" then keep = not source.whoOnly
        elseif filter == "Who" then keep = source.whoOnly == true
        elseif filter == "Favorites" then keep = source.favorite == true
        elseif filter == "Guild" then keep = myGuild ~= "" and tostring(source.guild or "") == myGuild end
        if keep and p3_matches(source, search) then table.insert(rows, p3_copy_row(source)) end
      end

      R.viewCache[signature] = {rows=rows, created=p3_now()}
      table.insert(R.viewOrder, signature)
      while #R.viewOrder > R.maximumViews do
        local oldest = table.remove(R.viewOrder, 1)
        if oldest then R.viewCache[oldest] = nil end
      end
      p3_note("filteredViewsBuilt", 1)
      p3_max("maximumFilteredViewBuildMs", math.max(0, p3_clock_ms() - started))
      return rows, snapshot
    end

    local oldDetail = B.RefreshFullRosterDetail
    if type(oldDetail) == "function" then
      B.RefreshFullRosterDetail = function(self, ...)
        if self.fullRosterSelectedName and R.rowByNameKey then
          self.fullRosterSelectedUser = R.rowByNameKey[p3_key(self.fullRosterSelectedName)]
        end
        return oldDetail(self, ...)
      end
    end

    local oldPresence = B.HandlePresence
    if type(oldPresence) == "function" then
      B.HandlePresence = function(self, packet, ...)
        local name = type(packet) == "table" and packet[3] or nil
        local nameKey = p3_key(name)
        local oldRow = nameKey ~= "" and self.onlineUsers and self.onlineUsers[name] or nil
        local oldGuild = tostring(oldRow and oldRow.guild or "")
        local refreshGuild = self.RefreshGuildBrowser
        local refreshPublic = self.RefreshPublicGroups
        self.RefreshGuildBrowser = function() end
        self.RefreshPublicGroups = function() end
        local results = {pcall(oldPresence, self, packet, ...)}
        self.RefreshGuildBrowser = refreshGuild
        self.RefreshPublicGroups = refreshPublic
        if not results[1] then error(results[2], 0) end
        if nameKey ~= "" and nameKey ~= p3_key(UnitName and UnitName("player") or "") then
          self:SF151_InvalidateRosterData("presence", name)
          local current = self.onlineUsers and (self.onlineUsers[name] or self.onlineUsers[nameKey]) or nil
          local newGuild = tostring(current and current.guild or "")
          if newGuild ~= oldGuild and refreshGuild and self.guildPanel and self.guildPanel.IsVisible and self.guildPanel:IsVisible() then
            refreshGuild(self)
          end
        end
        return unpack(results, 2)
      end
    end

    local oldFavoriteTransition = B.SF151_CheckFavoriteTransition
    if type(oldFavoriteTransition) == "function" then
      B.SF151_CheckFavoriteTransition = function(self, row, source)
        p3_note("favoriteTransitionChecks", 1)
        return oldFavoriteTransition(self, row, source)
      end
    end

    local oldToggleFavorite = B.ToggleFavorite
    if type(oldToggleFavorite) == "function" then
      B.ToggleFavorite = function(self, name, ...)
        local results = {pcall(oldToggleFavorite, self, name, ...)}
        if not results[1] then error(results[2], 0) end
        self:SF151_InvalidateRosterData("favorite", name)
        p3_request_panels("favorite")
        return unpack(results, 2)
      end
    end

    local oldRecordWho = B.RecordWhoGuildMember
    if type(oldRecordWho) == "function" then
      B.RecordWhoGuildMember = function(self, name, ...)
        local results = {pcall(oldRecordWho, self, name, ...)}
        if not results[1] then error(results[2], 0) end
        if not p3_is_ascension() then
          self:SF151_InvalidateRosterData("who", name)
          p3_request_panels("who")
        end
        return unpack(results, 2)
      end
    end

    local oldSetProfile = B.SF143_SetServerProfile
    if type(oldSetProfile) == "function" then
      B.SF143_SetServerProfile = function(self, ...)
        local before = p3_profile()
        local results = {pcall(oldSetProfile, self, ...)}
        if not results[1] then error(results[2], 0) end
        local after = p3_profile()
        if before ~= after then
          self:SF151_InvalidateRosterData("profile", after)
          p3_request_panels("profile")
        end
        return unpack(results, 2)
      end
    end

    local function p3_friend_signature()
      local values = {}
      if GetNumFriends and GetFriendInfo then
        for i = 1, tonumber(GetNumFriends() or 0) or 0 do table.insert(values, p3_key(GetFriendInfo(i))) end
      end
      table.sort(values)
      return table.concat(values, "|")
    end

    local function p3_group_signature()
      local values = {}
      if UnitName then
        for _, token in ipairs(R.unitTokens) do
          if token == "player" or string.find(token, "^party") or string.find(token, "^raid") then
            if not UnitExists or UnitExists(token) then table.insert(values, token .. "=" .. p3_key(UnitName(token))) end
          end
        end
      end
      return table.concat(values, "|")
    end

    local function p3_guild_signature()
      local values = {}
      if GetNumGuildMembers and GetGuildRosterInfo then
        for i = 1, tonumber(GetNumGuildMembers() or 0) or 0 do
          local name, _, _, level, className, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
          table.insert(values, table.concat({p3_key(name), tostring(level or ""), tostring(className or ""), tostring(zone or ""), tostring(online and 1 or 0), tostring(classFile or "")}, ":"))
        end
      end
      table.sort(values)
      return table.concat(values, "|")
    end

    local eventFrame = CreateFrame and CreateFrame("Frame") or nil
    if eventFrame then
      for _, event in ipairs({"PLAYER_ENTERING_WORLD", "FRIENDLIST_UPDATE", "PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE"}) do
        eventFrame:RegisterEvent(event)
      end
      eventFrame:SetScript("OnEvent", function(_, event)
        local key, signature = nil, nil
        if event == "FRIENDLIST_UPDATE" then key, signature = "friends", p3_friend_signature()
        elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then key, signature = "group", p3_group_signature()
        elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then key, signature = "guild", p3_guild_signature()
        elseif event == "PLAYER_ENTERING_WORLD" then
          R.sourceSignatures.friends = p3_friend_signature()
          R.sourceSignatures.group = p3_group_signature()
          R.sourceSignatures.guild = p3_guild_signature()
          B:SF151_InvalidateRosterData("enter-world")
          p3_request_panels("world")
          return
        end
        if key and R.sourceSignatures[key] ~= signature then
          R.sourceSignatures[key] = signature
          B:SF151_InvalidateRosterData(key)
          p3_request_panels(key)
        end
      end)
      R.eventFrame = eventFrame
    end

    function B:SF151_ResetRosterSnapshotStats()
      R.stats = {}
      return true
    end

    function B:SF151_GetRosterSnapshotDiagnostics()
      local result = {
        owner=R.owner,
        generation=R.generation,
        snapshotGeneration=R.snapshotGeneration,
        snapshotRows=R.snapshot and #R.snapshot or 0,
        nextExpiry=R.nextExpiry,
      }
      for key, value in pairs(R.stats or {}) do result[key] = value end
      return result
    end
  end
end
-- SIGNALFIRE_PHASE3_NETWORK_ROSTER_END

-- SIGNALFIRE_PHASE4_EVENT_TIMERS_BEGIN
do
  local B = _G.BronzeLFG
  if B and CreateFrame then
    local T = _G.SignalFireTimer151 or {}
    _G.SignalFireTimer151 = T
    T.generation = "1.5.1-perf-phase4"
    T.maximumTasks = 128
    T.maximumErrors = 20
    T.tasks = {}
    T.taskByKey = {}
    T.taskSequence = 0
    T.errors = {}
    T.stats = {}

    local function p4_now()
      return (GetTime and GetTime()) or 0
    end

    local function p4_epoch()
      return (time and time()) or math.floor(p4_now())
    end

    local function p4_perf_enabled()
      local perf = _G.SignalFirePerf151
      return perf and perf.enabled == true
    end

    local function p4_note(field, amount)
      if not p4_perf_enabled() then return end
      T.stats[field] = (T.stats[field] or 0) + (amount or 1)
    end

    local function p4_max(field, value)
      if not p4_perf_enabled() then return end
      value = tonumber(value or 0) or 0
      if value > (T.stats[field] or 0) then T.stats[field] = value end
    end

    local function p4_note_owner(field, owner)
      if not p4_perf_enabled() then return end
      local rows = T.stats[field]
      if type(rows) ~= "table" then rows = {}; T.stats[field] = rows end
      owner = tostring(owner or "unknown")
      rows[owner] = (rows[owner] or 0) + 1
    end

    local function p4_visible(frame)
      if not frame then return false end
      if frame.IsVisible then return frame:IsVisible() and true or false end
      if frame.IsShown then return frame:IsShown() and true or false end
      return false
    end

    local function p4_sleep(frame, stat)
      if frame and frame.IsShown and frame:IsShown() then
        frame:Hide()
        p4_note(stat, 1)
      end
    end

    local function p4_wake(frame, stat)
      if frame and frame.IsShown and not frame:IsShown() then
        frame.elapsed = 0
        frame:Show()
        p4_note(stat, 1)
      end
    end

    local function p4_record_error(key, err)
      table.insert(T.errors, {
        key=tostring(key or "task"),
        message=tostring(err or "unknown callback error"),
        at=p4_now(),
      })
      while #T.errors > T.maximumErrors do table.remove(T.errors, 1) end
      p4_note("callbackErrors", 1)
    end

    local function p4_remove_task_at(index, cancelled)
      local task = table.remove(T.tasks, index)
      if not task then return nil end
      if task.key and T.taskByKey[task.key] == task then T.taskByKey[task.key] = nil end
      if cancelled then p4_note("tasksCancelled", 1) end
      return task
    end

    function B:SF151_CancelDelayed(key)
      key = tostring(key or "")
      if key == "" then return false end
      local task = T.taskByKey[key]
      if not task then return false end
      for index = #T.tasks, 1, -1 do
        if T.tasks[index] == task then p4_remove_task_at(index, true); break end
      end
      if #T.tasks == 0 then p4_sleep(T.delayFrame, "delayedSleeps") end
      return true
    end

    function B:SF151_ScheduleDelayed(key, delay, callback)
      if type(callback) ~= "function" then return false end
      key = tostring(key or "")
      if key == "" then
        T.taskSequence = T.taskSequence + 1
        key = "task." .. tostring(T.taskSequence)
      else
        if T.taskByKey[key] and string.sub(key, 1, 8) == "startup." then
          p4_note_owner("startupRedundantPassesSkipped", key)
        end
        self:SF151_CancelDelayed(key)
        T.taskSequence = T.taskSequence + 1
      end
      if #T.tasks >= T.maximumTasks then
        p4_note("tasksDropped", 1)
        return false
      end

      local task = {
        key=key,
        deadline=p4_now() + math.max(0, tonumber(delay or 0) or 0),
        sequence=T.taskSequence,
        callback=callback,
      }
      local insertAt = #T.tasks + 1
      for index, current in ipairs(T.tasks) do
        if task.deadline < current.deadline
          or (task.deadline == current.deadline and task.sequence < current.sequence) then
          insertAt = index
          break
        end
      end
      table.insert(T.tasks, insertAt, task)
      T.taskByKey[key] = task
      p4_note("tasksScheduled", 1)
      if string.sub(key, 1, 8) == "startup." then
        p4_note("startupPassesScheduled", 1)
        p4_note_owner("startupPassesByOwner", key)
      end
      p4_max("maximumQueueDepth", #T.tasks)
      p4_wake(T.delayFrame, "delayedWakes")
      return key
    end

    T.delayFrame = T.delayFrame or CreateFrame("Frame")
    T.delayFrame:Hide()
    T.delayFrame.elapsed = 0
    T.delayFrame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
      if self.elapsed < (1 / 30) then return end
      self.elapsed = 0
      p4_note("delayedTicks", 1)

      local now = p4_now()
      while T.tasks[1] and now >= (T.tasks[1].deadline or 0) do
        local task = p4_remove_task_at(1, false)
        if task then
          local lateness = math.max(0, now - (task.deadline or now))
          if lateness > (1 / 30) then p4_note("lateExecutions", 1) end
          p4_max("maximumDeadlineLateness", lateness)
          T.executingTask = task.key
          local ok, err = pcall(task.callback)
          T.executingTask = nil
          p4_note("tasksExecuted", 1)
          if string.sub(task.key or "", 1, 8) == "startup." then
            p4_note("startupVerificationPasses", 1)
            p4_note_owner("startupVerificationByOwner", task.key)
          end
          if not ok then p4_record_error(task.key, err) end
        end
        now = p4_now()
      end
      if #T.tasks == 0 then p4_sleep(self, "delayedSleeps") end
    end)

    local function p4_network_interval()
      local n = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
      local interval = tonumber(n and n.autoRefreshSeconds or 30) or 30
      if interval ~= 0 and interval ~= 15 and interval ~= 30 and interval ~= 60 then interval = 30 end
      return interval
    end

    local function p4_any_network_visible()
      return p4_visible(B.sfnPanel) or p4_visible(B.onlinePanel)
    end

    local function p4_update_response_text(now)
      if not p4_visible(B.sfnPanel) or not B.sfnUpdated then return false end
      local pending = tonumber(B._sfnPresenceRefreshPending or 0) or 0
      local response = tonumber(B._sfnLastPresenceResponse or 0) or 0
      local text, r, g, b
      if pending > 0 and (now - pending) <= 5 then
        text, r, g, b = "Refreshing network...", 1, .82, .25
      elseif response > 0 then
        text, r, g, b = "Last response: " .. tostring(math.max(0, now - response)) .. "s ago", .4, 1, .4
      else
        text, r, g, b = "No responses received yet", .8, .8, .8
      end
      if B.sfnUpdated.GetText and B.sfnUpdated:GetText() == text then return false end
      B.sfnUpdated:SetText(text)
      B.sfnUpdated:SetTextColor(r, g, b)
      return true
    end

    local function p4_refresh_visible_ages(now)
      T.lastVisibleAgeRefresh = tonumber(T.lastVisibleAgeRefresh or 0) or 0
      if (now - T.lastVisibleAgeRefresh) < 15 then return end
      T.lastVisibleAgeRefresh = now
      if p4_visible(B.sfnPanel) then
        if B.SF151_RequestPanelRefresh then B:SF151_RequestPanelRefresh("network")
        elseif B.RefreshSFNetwork then B:RefreshSFNetwork() end
      end
      if p4_visible(B.onlinePanel) then
        if B.SF151_RequestPanelRefresh then B:SF151_RequestPanelRefresh("roster")
        elseif B.RefreshOnlinePanel then B:RefreshOnlinePanel() end
      end
      p4_note("visibleAgeRefreshes", 1)
    end

    local function p4_network_tick()
      if not p4_any_network_visible() then
        B._sfnNextAutoRefresh = nil
        p4_sleep(T.networkFrame, "networkSleeps")
        return
      end

      local now = p4_epoch()
      p4_note("networkTicks", 1)
      p4_note("autoRefreshChecks", 1)
      if p4_update_response_text(now) then p4_note("ageLabelUpdates", 1) end

      local interval = p4_network_interval()
      if interval <= 0 then
        B._sfnNextAutoRefresh = nil
      else
        B._sfnNextAutoRefresh = tonumber(B._sfnNextAutoRefresh or (now + interval)) or (now + interval)
        if now >= B._sfnNextAutoRefresh then
          B._sfnNextAutoRefresh = now + interval
          local presence = _G.SignalFirePresenceAdminFix
          if presence and presence.RequestPresence then
            presence.RequestPresence("auto-refresh")
            p4_note("autoRefreshRequests", 1)
          end
        end
      end
      p4_refresh_visible_ages(now)
    end

    T.networkFrame = T.networkFrame or CreateFrame("Frame")
    T.networkFrame:Hide()
    T.networkFrame.elapsed = 0
    T.networkFrame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
      if self.elapsed < 1 then return end
      self.elapsed = 0
      p4_network_tick()
    end)

    function T.UpdateNetworkOwner()
      if p4_any_network_visible() then
        p4_wake(T.networkFrame, "networkWakes")
      else
        B._sfnNextAutoRefresh = nil
        p4_sleep(T.networkFrame, "networkSleeps")
      end
    end

    local function p4_attach_panel(frame)
      if not frame or frame._sfP4TimerAttached then return end
      frame._sfP4TimerAttached = true
      local oldShow = frame:GetScript("OnShow")
      local oldHide = frame:GetScript("OnHide")
      frame:SetScript("OnShow", function(self, ...)
        if oldShow then oldShow(self, ...) end
        T.UpdateNetworkOwner()
      end)
      frame:SetScript("OnHide", function(self, ...)
        if oldHide then oldHide(self, ...) end
        T.UpdateNetworkOwner()
      end)
    end

    local oldBuildNetwork = B.BuildSFNetworkPanel
    if type(oldBuildNetwork) == "function" then
      B.BuildSFNetworkPanel = function(self, ...)
        local results = {pcall(oldBuildNetwork, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_attach_panel(self.sfnPanel)
        T.UpdateNetworkOwner()
        return unpack(results, 2)
      end
    end

    local oldBuildRoster = B.BuildOnlinePanel
    if type(oldBuildRoster) == "function" then
      B.BuildOnlinePanel = function(self, ...)
        local results = {pcall(oldBuildRoster, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_attach_panel(self.onlinePanel)
        T.UpdateNetworkOwner()
        return unpack(results, 2)
      end
    end

    local function p4_reset_auto_deadline()
      local interval = p4_network_interval()
      B._sfnNextAutoRefresh = interval > 0 and (p4_epoch() + interval) or nil
      T.UpdateNetworkOwner()
    end

    local oldShowNetwork = B.ShowSFNetwork
    if type(oldShowNetwork) == "function" then
      B.ShowSFNetwork = function(self, ...)
        local results = {pcall(oldShowNetwork, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_attach_panel(self.sfnPanel)
        p4_reset_auto_deadline()
        return unpack(results, 2)
      end
    end

    local oldShowRoster = B.ShowFullRoster
    if type(oldShowRoster) == "function" then
      B.ShowFullRoster = function(self, ...)
        local results = {pcall(oldShowRoster, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_attach_panel(self.onlinePanel)
        p4_reset_auto_deadline()
        return unpack(results, 2)
      end
    end

    local function p4_reset_applicant_visuals()
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

    local function p4_animate_applicant()
      local a = (math.sin(p4_now() * 6) + 1) / 2
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
    end

    T.applicantFrame = T.applicantFrame or CreateFrame("Frame")
    T.applicantFrame:Hide()
    T.applicantFrame.elapsed = 0
    T.applicantFrame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
      if self.elapsed < (1 / 30) then return end
      self.elapsed = 0
      if not B.newApplicantAlert then
        p4_reset_applicant_visuals()
        p4_sleep(self, "applicantSleeps")
        return
      end
      p4_animate_applicant()
      p4_note("applicantTicks", 1)
    end)

    local function p4_wake_applicant()
      if B.newApplicantAlert then p4_wake(T.applicantFrame, "applicantWakes") end
    end

    local function p4_stop_applicant()
      p4_reset_applicant_visuals()
      p4_sleep(T.applicantFrame, "applicantSleeps")
    end

    local function p4_position_minimap()
      local mm = B.mm
      if not mm or not mm.dragging or not Minimap or not GetCursorPosition or not UIParent then return false end
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      if not mx or not my or not px or not py or not scale or scale == 0 then return false end
      px, py = px / scale, py / scale
      B.minimapAngle = ((math.deg(math.atan2(py - my, px - mx)) % 360) + 360) % 360
      mm:ClearAllPoints()
      mm:SetParent(Minimap)
      local angle = math.rad(B.minimapAngle)
      mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
      return true
    end

    T.dragFrame = T.dragFrame or CreateFrame("Frame")
    T.dragFrame:Hide()
    T.dragFrame.elapsed = 0
    T.dragFrame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (tonumber(elapsed) or 0)
      if self.elapsed < (1 / 60) then return end
      self.elapsed = 0
      if not (B.mm and B.mm.dragging) then
        p4_sleep(self, "dragSleeps")
        return
      end
      if p4_position_minimap() then p4_note("dragTicks", 1) end
    end)

    local function p4_wake_drag()
      if B.mm and B.mm.dragging then p4_wake(T.dragFrame, "dragWakes") end
    end

    local function p4_stop_drag()
      p4_sleep(T.dragFrame, "dragSleeps")
    end

    T.WakePulse = function()
      p4_wake_applicant()
      p4_wake_drag()
    end
    T.ApplyApplicantOwner = function()
      if B.applicantsButton then B.applicantsButton:SetScript("OnUpdate", nil) end
      if B.newApplicantAlert then p4_wake_applicant() else p4_stop_applicant() end
    end
    T.ApplyMinimapOwner = function()
      local mm = B.mm
      if not mm then return end
      mm:SetScript("OnUpdate", nil)
      if mm._sfP4DragOwner then return end
      mm._sfP4DragOwner = true
      local oldStart = mm:GetScript("OnDragStart")
      local oldStop = mm:GetScript("OnDragStop")
      mm:SetScript("OnDragStart", function(self, ...)
        local results = oldStart and {pcall(oldStart, self, ...)} or {true}
        p4_wake_drag()
        if not results[1] then error(results[2], 0) end
      end)
      mm:SetScript("OnDragStop", function(self, ...)
        local wasActive = self.dragging or (BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.freeLauncher)
        local results = oldStop and {pcall(oldStop, self, ...)} or {true}
        p4_stop_drag()
        if wasActive then p4_note("finalDragSaves", 1) end
        if not results[1] then error(results[2], 0) end
      end)
    end

    local oldSetApplicantAlert = B.SetApplicantAlert
    if type(oldSetApplicantAlert) == "function" then
      B.SetApplicantAlert = function(self, active, ...)
        local results = {pcall(oldSetApplicantAlert, self, active, ...)}
        self.newApplicantAlert = active and true or false
        if self.newApplicantAlert then p4_wake_applicant() else p4_stop_applicant() end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
      end
    end

    local function p4_listing_tick()
      if not B.myListing then return end
      local ok, err = pcall(function()
        if B.CheckAutoCloseListing then B:CheckAutoCloseListing() end
        if B.myListing and B.Broadcast then B:Broadcast() end
      end)
      if B.myListing then B:SF151_ScheduleDelayed("listing.maintenance", 10, p4_listing_tick) end
      if not ok then error(err, 0) end
    end

    local function p4_update_listing_owner()
      if B.myListing then
        B:SF151_ScheduleDelayed("listing.maintenance", 10, p4_listing_tick)
      else
        B:SF151_CancelDelayed("listing.maintenance")
      end
    end

    local oldCreateListing = B.CreateListing
    if type(oldCreateListing) == "function" then
      B.CreateListing = function(self, ...)
        local results = {pcall(oldCreateListing, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_update_listing_owner()
        return unpack(results, 2)
      end
    end

    local oldRestoreListing = B.RestoreMyListingState
    if type(oldRestoreListing) == "function" then
      B.RestoreMyListingState = function(self, ...)
        local results = {pcall(oldRestoreListing, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_update_listing_owner()
        return unpack(results, 2)
      end
    end

    local oldCancelListing = B.CancelMyListing
    if type(oldCancelListing) == "function" then
      B.CancelMyListing = function(self, ...)
        local results = {pcall(oldCancelListing, self, ...)}
        if not results[1] then error(results[2], 0) end
        p4_update_listing_owner()
        return unpack(results, 2)
      end
    end

    -- Cache cleanup is opportunistic in Phase 4: run on real lifecycle/data
    -- events, then rely on the existing 30-second guard in the maintenance
    -- function. Event reads already remove expired rows, so no background
    -- maintenance deadline needs to keep the delayed scheduler awake.
    function T.RunMaintenance(reason)
      if not B.SF151_RunSlowMaintenance then return false end
      local ok, result = pcall(B.SF151_RunSlowMaintenance, B)
      if not ok then
        p4_record_error("maintenance." .. tostring(reason or "event"), result)
        return false
      end
      return result
    end

    local oldSendEvent = B.SFE_SendEvent
    if type(oldSendEvent) == "function" then
      B.SFE_SendEvent = function(self, ...)
        local results = {pcall(oldSendEvent, self, ...)}
        if not results[1] then error(results[2], 0) end
        T.RunMaintenance("event-created")
        return unpack(results, 2)
      end
    end

    if B._sfPerfCorePulseFrame then B._sfPerfCorePulseFrame:SetScript("OnUpdate", nil) end
    if B._sfPerfNetworkPulseFrame then B._sfPerfNetworkPulseFrame:SetScript("OnUpdate", nil) end
    if B._sfPerfPresencePulseFrame then B._sfPerfPresencePulseFrame:SetScript("OnUpdate", nil) end
    if T.pulseFrame then T.pulseFrame:SetScript("OnUpdate", nil); T.pulseFrame:Hide() end
    if B.applicantsButton then B.applicantsButton:SetScript("OnUpdate", nil) end
    if B.mm then B.mm:SetScript("OnUpdate", nil) end

    p4_attach_panel(B.sfnPanel)
    p4_attach_panel(B.onlinePanel)
    T.ApplyApplicantOwner()
    T.ApplyMinimapOwner()
    p4_update_listing_owner()
    T.RunMaintenance("addon-load")

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_LOGIN")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
      p4_attach_panel(B.sfnPanel)
      p4_attach_panel(B.onlinePanel)
      T.ApplyApplicantOwner()
      T.ApplyMinimapOwner()
      p4_update_listing_owner()
      T.RunMaintenance("world-entry")
      T.UpdateNetworkOwner()
    end)
    T.eventFrame = eventFrame

    function B:SF151_ResetTimerStats()
      T.stats = {}
      T.errors = {}
      return true
    end

    function B:SF151_GetTimerDiagnostics()
      local result = {
        generation=T.generation,
        delayedActive=T.delayFrame:IsShown() and true or false,
        delayedTasks=#T.tasks,
        networkActive=T.networkFrame:IsShown() and true or false,
        applicantActive=T.applicantFrame:IsShown() and true or false,
        dragActive=T.dragFrame:IsShown() and true or false,
        oldCoreActive=B._sfPerfCorePulseFrame and B._sfPerfCorePulseFrame:GetScript("OnUpdate") and true or false,
        oldNetworkActive=B._sfPerfNetworkPulseFrame and B._sfPerfNetworkPulseFrame:GetScript("OnUpdate") and true or false,
        oldPresenceActive=B._sfPerfPresencePulseFrame and B._sfPerfPresencePulseFrame:GetScript("OnUpdate") and true or false,
        callbackErrorCount=#T.errors,
        errors=T.errors,
      }
      for key, value in pairs(T.stats or {}) do result[key] = value end
      return result
    end

    function B:SF151_PrintTimerDiagnostics()
      local d = self:SF151_GetTimerDiagnostics()
      local function out(text)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. text) end
      end
      out("timer owner " .. tostring(d.generation) .. ", delayed=" .. tostring(d.delayedActive) .. "/" .. tostring(d.delayedTasks)
        .. ", network=" .. tostring(d.networkActive) .. ", applicant=" .. tostring(d.applicantActive) .. ", drag=" .. tostring(d.dragActive))
      out("legacy pulses: core=" .. tostring(d.oldCoreActive) .. ", network=" .. tostring(d.oldNetworkActive)
        .. ", presence=" .. tostring(d.oldPresenceActive) .. ", callbackErrors=" .. tostring(d.callbackErrorCount))
      out("delayed: wakes=" .. tostring(d.delayedWakes or 0) .. ", sleeps=" .. tostring(d.delayedSleeps or 0)
        .. ", scheduled=" .. tostring(d.tasksScheduled or 0) .. ", executed=" .. tostring(d.tasksExecuted or 0)
        .. ", cancelled=" .. tostring(d.tasksCancelled or 0) .. ", maxDepth=" .. tostring(d.maximumQueueDepth or 0))
      out("visible ticker: wakes=" .. tostring(d.networkWakes or 0) .. ", sleeps=" .. tostring(d.networkSleeps or 0)
        .. ", ticks=" .. tostring(d.networkTicks or 0) .. ", hiddenTicks=" .. tostring(d.networkHiddenTicks or 0)
        .. ", autoRequests=" .. tostring(d.autoRefreshRequests or 0))
      out("interaction: applicantTicks=" .. tostring(d.applicantTicks or 0) .. ", dragTicks=" .. tostring(d.dragTicks or 0)
        .. ", dragWrites=0, finalDragSaves=" .. tostring(d.finalDragSaves or 0))
      return d
    end
  end
end
-- SIGNALFIRE_PHASE4_EVENT_TIMERS_END
