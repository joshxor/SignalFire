-- SignalFire 1.5.3
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
      return "v" .. tostring(SignalFire_VERSION or "1.5.3") .. " - " .. sfui_profile_name(true)
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
      BLFG.version = (SignalFire_GetVersion and SignalFire_GetVersion()) or tostring(SignalFire_VERSION or "1.5.3")
      if BronzeLFG_ApplyVisibleVersion then
        BronzeLFG_ApplyVisibleVersion()
      elseif BLFG.titleText then
        BLFG.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or ("SignalFire v" .. tostring(BLFG.version)))
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
    eventFrame:SetScript("OnEvent", function(_, event)
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
    P3.generation = "1.5.3-phase12c-coverage"
    P3.workerGeneration = "1.5.3-phase12c-coverage"
    P3.aliasGeneration = "1.5.3-guild-group-v1"
    P3.workerMaximumRecords = 4
    P3.workerMaximumMs = 0.75
    P3.renderDecisionMaximum = 256
    P3.renderDecisionPositiveTTL = 30
    P3.renderDecisionNegativeTTL = 5

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
      if B.SF151_ApplyChatLinkSafeDefault then
        B:SF151_ApplyChatLinkSafeDefault(BronzeLFG_DB)
      elseif o.inlineChatLinks ~= true and o.inlineChatLinks ~= false then
        o.inlineChatLinks = false
      end
      -- Earlier stutter-safety builds could leave this hidden switch disabled
      -- while the visible "Build Public Groups From Chat" option remained on.
      -- Migrate that stale state once; later user changes are still respected.
      if o.sf151Phase3iLinkOptionMigrated ~= true then
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

    -- Source and display paths deliberately share one semantic identity.
    local function p3_render_key(author, text)
      return P3.SemanticKey and P3.SemanticKey(author, text) or p3_key(author, text)
    end

    local function p3_source_key(event, channel, author, text)
      return P3.SemanticKey and P3.SemanticKey(author, text) or p3_key(author, text)
    end

    local function p3_public_key(author, text)
      if B.SignalFirePublicChatKey then return B:SignalFirePublicChatKey(author, text) end
      return p3_author(author) .. "\031" .. tostring(text or "")
    end

    local function p3_stats()
      B._sfP3Stats = B._sfP3Stats or {}
      local stats = B._sfP3Stats
      if stats._schema == P3.generation then return stats end
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
        "parsingDisabledSourceReturns", "parsingDisabledLegacyQueueReturns",
        "parsingDisabledFilterReturns", "parsingDisabledCandidateCalls",
        "parsingDisabledParserCalls", "parsingDisabledQueueCalls",
        "sourceEventsReceived", "sourceEventsIgnored", "sourceEventsEligible",
        "sourceEventsIneligible", "sourceDuplicatesSuppressed", "candidateGateCalls",
        "candidateGateAccepted", "candidateGateRejected", "TestParseCalls",
        "queueRecordsCreated", "queueRecordsProcessed", "workerFramesActive",
        "workerRecordsProcessed", "workerBudgetStopsByCount", "workerBudgetStopsByTime",
        "queueMaximumDepth", "workerMaximumFrameMs", "workerMaximumRecordMs", "workerIdleFrames", "parserErrors",
        "filtersCurrentlyInstalled", "filterRegistrationCalls", "filterUnregistrationCalls",
        "duplicateRegistrationsPrevented", "filterReceipts", "filterDecisionHits",
        "filterDecisionMisses", "chatLinesRewritten", "chatLinesPassedThrough",
        "filterReceiptsWhileDisabled", "inlineCandidateCalls", "inlineParserCalls",
        "inlineQueueCalls", "inlineUpsertCalls", "inlineAddPublicGroupCalls",
        "inlineRefreshCalls", "inlineSavedVariableWrites", "inlineCacheSweepCalls",
        "canonicalIndexHits", "canonicalIndexMisses", "canonicalIndexRepairs",
        "historicalFullTableDuplicateScans", "exactResolverCalls",
        "exactResolverCacheHits", "exactResolverCacheMisses", "exactResolverFilterFallbacks",
        "exactResolverSourceOwners", "exactResolverFilterOwners", "exactResolverReentryPrevented",
        "canonicalUpserts", "exactLinksBuilt", "eligibleMessagesWithoutLinks", "genericLinksBuilt",
        "guildCandidates", "guildAccepted", "guildRejected", "guildNameExtractionFailures",
        "guildLinksBuilt", "eligibleGuildMessagesWithoutLinks", "groupCandidates", "groupAccepted",
        "unknownActivities", "eligibleGroupMessagesWithoutLinks", "negativeCacheHits",
        "negativeCacheInvalidations", "guildCanonicalUpserts",
        "normalizationCalls", "normalizationMsTotal", "normalizationMsMax",
        "candidateMsTotal", "candidateMsMax", "canonicalUpsertMsTotal", "canonicalUpsertMsMax",
        "linkTitleMsTotal", "linkTitleMsMax", "exactResolverMsTotal", "exactResolverMsMax",
      }
      for _, field in ipairs(fields) do
        if stats[field] == nil then stats[field] = 0 end
      end
      stats._schema = P3.generation
      return stats
    end

    local function p3_diagnostics_enabled()
      return (BronzeLFG_DB and BronzeLFG_DB.options
        and BronzeLFG_DB.options.developerDiagnostics == true)
        or (_G.SignalFirePerf151 and _G.SignalFirePerf151.enabled == true)
        or P3._stabilityDiagnosticsEnabled == true
        or P3._canaryDiagnosticsEnabled == true
        or P3._traceDiagnosticsEnabled == true
    end

    local function p3_note(field, amount)
      if not p3_diagnostics_enabled() then return nil end
      local stats = p3_stats()
      stats[field] = (stats[field] or 0) + (amount or 1)
      return stats
    end

    function P3.Note(field, amount)
      return p3_note(field, amount)
    end

    -- Session-only semantic-key cache. Owner: SignalFireChatRuntime151.
    -- Key: realm-stripped lowercase author plus the unmodified event text.
    -- Value: normalized semantic key. Maximum: 256 entries. TTL: 30 seconds.
    -- Eviction: cyclic oldest-slot replacement. Cleanup: replacement, runtime
    -- cache clear, or session end. It is never persisted.
    local function p3_semantic_key(author, text)
      local stamp = p3_now()
      local rawKey = string.lower(p3_author(author)) .. "\031" .. tostring(text or "")
      P3._semanticKeyCache = P3._semanticKeyCache or {}
      local cached = P3._semanticKeyCache[rawKey]
      if cached and stamp <= (tonumber(cached.expires or 0) or 0) then
        return cached.key, rawKey
      end
      local diagnostics = p3_diagnostics_enabled()
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
      local key = p3_key(author, text)
      if diagnostics then
        local stats = p3_stats()
        stats.normalizationCalls = stats.normalizationCalls + 1
        if started and debugprofilestop then
          local elapsed = math.max(0, debugprofilestop() - started)
          stats.normalizationMsTotal = stats.normalizationMsTotal + elapsed
          if elapsed > stats.normalizationMsMax then stats.normalizationMsMax = elapsed end
        end
      end
      P3._semanticKeySlots = P3._semanticKeySlots or {}
      P3._semanticKeyCursor = ((tonumber(P3._semanticKeyCursor or 0) or 0) % 256) + 1
      local old = P3._semanticKeySlots[P3._semanticKeyCursor]
      if old then
        local current = P3._semanticKeyCache[old.rawKey]
        if current and current.stamp == old.stamp then P3._semanticKeyCache[old.rawKey] = nil end
      end
      P3._semanticKeyCache[rawKey] = {key=key, stamp=stamp, expires=stamp + 30}
      P3._semanticKeySlots[P3._semanticKeyCursor] = {rawKey=rawKey, stamp=stamp}
      return key, rawKey
    end

    P3.SemanticKey = p3_semantic_key

    local function p3_canary_owner()
      local owner = _G.SignalFireParserCanary151
      return owner and owner.active == true and owner or nil
    end

    local function p3_canary_abort(reason)
      local owner = p3_canary_owner()
      if owner and owner.AbortSafety then
        pcall(owner.AbortSafety, owner, tostring(reason or "runtime safety trigger"))
      end
      return false
    end

    local function p3_canary_check(stage)
      local owner = p3_canary_owner()
      if not owner or not owner.CheckRuntime then return true end
      local ok, allowed = pcall(owner.CheckRuntime, owner, tostring(stage or "runtime"))
      if not ok then
        p3_canary_abort("canary safety check error")
        return false
      end
      return allowed ~= false
    end

    local function p3_option_parsing_enabled()
      return BronzeLFG_DB ~= nil and BronzeLFG_DB.options ~= nil
        and BronzeLFG_DB.options.publicGroups ~= false
    end

    local function p3_parsing_enabled()
      return p3_option_parsing_enabled() and P3._parserSuspended ~= true
    end

    local function p3_candidate_raw(text)
      if not p3_parsing_enabled() then
        p3_note("parsingDisabledCandidateCalls")
        return false
      end
      p3_note("candidateGateCalls")
      local raw = p3_norm(text)
      if raw == "" or p3_is_protocol(raw) or p3_has_existing_link(raw) then
        p3_note("candidateGateRejected")
        return false, "Empty, protocol, or already linked"
      end
      if p3_has_external_noise(" " .. raw .. " ")
        and not string.find(raw, "discord.gg", 1, true)
        and not string.find(raw, "discord.com/invite", 1, true) then
        p3_note("candidateGateRejected")
        return false, "External promotion"
      end
      if string.find(raw, "/join guild recruitment", 1, true)
        or string.find(raw, "use proper chat channels", 1, true) then
        p3_note("candidateGateRejected")
        p3_note("guildRejected")
        return false, "Guild channel announcement"
      end
      if string.find(raw, "?", 1, true)
        or string.find(raw, "do i need ", 1, true)
        or string.find(raw, "does the ", 1, true)
        or string.find(raw, "which dungeon", 1, true)
        or string.find(raw, "what tank", 1, true)
        or string.find(raw, "can dps", 1, true) then
        p3_note("candidateGateRejected")
        return false, "Question or ordinary conversation"
      end

      local words = " " .. string.gsub(raw, "[^%w%+<>']", " ") .. " "
      words = string.gsub(words, "%s+", " ")
      local role = string.find(words, " tank ", 1, true) or string.find(words, " heal ", 1, true)
        or string.find(words, " healer ", 1, true) or string.find(words, " heals ", 1, true)
        or string.find(words, " heasl ", 1, true)
        or string.find(words, " dps ", 1, true) or string.find(words, " damage ", 1, true)
      local activity = string.find(words, " dungeon ", 1, true) or string.find(words, " dung ", 1, true)
        or string.find(words, " raid ", 1, true) or string.find(words, " rdf ", 1, true)
        or string.find(words, " df ", 1, true) or string.find(words, " heroic ", 1, true)
        or string.find(words, " mythic ", 1, true) or string.find(words, " keystone ", 1, true)
        or string.find(words, " key ", 1, true) or string.find(words, " invasion ", 1, true)
        or string.find(words, " vault ", 1, true) or string.find(words, " mc ", 1, true)
        or string.find(words, " bwl ", 1, true) or string.find(words, " icc ", 1, true)
        or string.find(words, " sfk ", 1, true) or string.find(words, " hol ", 1, true)
        or string.find(words, " zf ", 1, true) or string.find(words, " wc ", 1, true)
        or string.find(words, " aq40 ", 1, true) or string.find(words, " naxx ", 1, true)
        or string.find(words, " ony ", 1, true) or string.find(words, " boss ", 1, true)
        or string.find(words, " snowgrave ", 1, true) or string.find(words, " kaldros ", 1, true)
        or string.find(words, " soggoth ", 1, true) or string.find(words, " sogoth ", 1, true)
        or string.find(words, " kazzak ", 1, true)
        or string.find(words, " azuregos ", 1, true)
        or string.find(raw, "other side", 1, true) or string.find(raw, "otha side", 1, true)
      local direct = string.find(words, " lfm ", 1, true) or string.find(words, " lfg ", 1, true)
        or string.find(words, " lf1m ", 1, true) or string.find(words, " lf2m ", 1, true)
        or string.find(words, " lf3m ", 1, true) or string.find(words, " lf4m ", 1, true)
        or string.find(words, " lf%d+m ")
      local recruiting = string.find(words, " recruiting ", 1, true)
        or string.find(words, " recruitment ", 1, true)
        or string.find(raw, "looking for members", 1, true)
        or string.find(raw, "accepting members", 1, true)
        or string.find(raw, "seeking members", 1, true)
        or string.find(raw, "join our guild", 1, true)
        or (string.find(raw, "guild tag", 1, true) and string.find(raw, "<", 1, true))
      local guildWrapped = string.find(raw, "<", 1, true) and string.find(raw, ">", 1, true)
      local guildRecruiting = recruiting
        or string.find(raw, " guild looking for", 1, true)
        or string.find(raw, "looking for active", 1, true)
        or string.find(raw, "looking for committed", 1, true)
        or string.find(raw, "preferably looking for", 1, true)
        or string.find(raw, "players welcome", 1, true)
        or string.find(raw, "player welcome", 1, true)
        or string.find(raw, "whisper for invite", 1, true)
        or string.find(raw, "guild invite", 1, true)
        or string.find(raw, "active community", 1, true)
        or string.find(raw, " recluta", 1, true)
        or string.find(raw, " reclutando", 1, true)
        or string.find(raw, "buscamos jugadores", 1, true)
        or string.find(raw, "jugadores nuevos", 1, true)
        or string.find(raw, " guild latina", 1, true)
        or string.find(raw, " hermandad", 1, true)
        or string.find(raw, " unete", 1, true)
        or string.find(raw, " \195\186nete", 1, true)
        or string.find(raw, " invitacion", 1, true)
        or string.find(raw, " invitaci\195\179n", 1, true)
      local structuredGuild = guildWrapped and (guildRecruiting
        or string.find(words, " guild ", 1, true) or string.find(words, " pve ", 1, true)
        or string.find(words, " pvp ", 1, true) or string.find(words, " raid ", 1, true)
        or string.find(words, " mythic ", 1, true) or string.find(words, " members ", 1, true)
        or string.find(words, " players ", 1, true))
      if guildRecruiting and (structuredGuild or string.find(raw, " guild latina", 1, true)
        or string.find(raw, " hermandad", 1, true)) then
        p3_note("candidateGateAccepted")
        p3_note("guildCandidates")
        return true, "Bounded guild recruitment signal"
      end
      local anchored = direct or recruiting
        or (string.find(words, " lf ", 1, true) and (role or activity))
        or (string.find(raw, "looking for", 1, true) and (role or activity))
        or (string.find(words, " need ", 1, true) and (role or activity))
        or (string.find(raw, "last spot", 1, true) and (role or activity))
        or (role and activity and (string.find(words, " spam ", 1, true)
          or string.find(words, " farm ", 1, true) or string.find(words, " farming ", 1, true)
          or string.find(words, " grp ", 1, true) or string.find(words, " group ", 1, true)
          or string.find(words, " aura ", 1, true)))
      if anchored then
        p3_note("candidateGateAccepted")
        p3_note("groupCandidates")
        return true, "Bounded group signal"
      end
      p3_note("candidateGateRejected")
      return false, "No bounded group or guild signal"
    end

    local function p3_candidate(text)
      local diagnostics = p3_diagnostics_enabled()
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
      local accepted, reason = p3_candidate_raw(text)
      if started and debugprofilestop then
        local elapsed = math.max(0, debugprofilestop() - started)
        local stats = p3_stats()
        stats.candidateMsTotal = stats.candidateMsTotal + elapsed
        if elapsed > stats.candidateMsMax then stats.candidateMsMax = elapsed end
      end
      return accepted, reason
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
      return type(B._sfP3Queue) == "table" and #B._sfP3Queue or 0
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
      P3._renderGeneration = (tonumber(P3._renderGeneration or 0) or 0) + 1
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
          p3_note("canonicalIndexHits")
          return row, item.id
        end
        p3_index_remove_key(key)
        p3_note("indexStaleRepairs")
      end

      p3_note("indexMisses")
      p3_note("canonicalIndexMisses")
      local id, row = p3_stable_id(key)
      if row then
        row.sf151CanonicalKey = key
        p3_index_store(key, id, stamp)
        p3_note("indexStaleRepairs")
        p3_note("canonicalIndexRepairs")
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
      if not p3_parsing_enabled() then
        p3_note("parsingDisabledParserCalls")
        return nil
      end
      if not p3_canary_check("before TestParse") then return nil end
      local o = p3_options()
      local raw = p3_trim(text)
      if raw == "" or p3_has_existing_link(raw) then return nil end
      if p3_is_protocol(raw) then p3_note("protocolRejected"); return nil end

      local low = " " .. string.lower(raw) .. " "
      if p3_has_external_noise(low) and not string.find(low, "discord.gg", 1, true)
        and not string.find(low, "discord.com/invite", 1, true) then return nil end
      local probe = _G.SignalFireFastChatLinks and _G.SignalFireFastChatLinks.TestParse
      if type(probe) ~= "function" then return nil end
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if diagnostics and _G.SignalFirePerf151 and _G.SignalFirePerf151.Note then
        _G.SignalFirePerf151:Note("chat", "uniqueMessagesClassified", 1)
      end
      if stats then
        stats.testParseCalls = stats.testParseCalls + 1
        stats.TestParseCalls = stats.TestParseCalls + 1
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
      if not ok then
        p3_note("parserErrors")
        p3_canary_abort("parser error")
        return nil
      end
      if type(parsed) ~= "table" or parsed.eligible ~= true then
        if string.find(low, " guild", 1, true) or string.find(raw, "<", 1, true) then
          p3_note("guildRejected")
          p3_note("guildNameExtractionFailures")
        end
        return nil
      end
      if parsed.kind == "guild" and o.parseGuildRecruitment == false then return nil end
      if parsed.kind ~= "guild" and parsed.kind ~= "group" then return nil end
      if parsed.kind == "guild" then
        p3_note("guildAccepted")
        if not parsed.guild and not parsed.guildName then p3_note("guildNameExtractionFailures") end
      else
        p3_note("groupAccepted")
        if parsed.unknownActivity then p3_note("unknownActivities") end
      end
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
      row.activities = parsed.activities or row.activities
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

    local function p3_enqueue(author, text, channel, event, semanticKey, prepare)
      if not p3_parsing_enabled() then
        p3_note("parsingDisabledQueueCalls")
        return nil
      end
      if not p3_canary_check("before queue") then return nil end
      local raw = tostring(text or "")
      if p3_author(author) == p3_author(UnitName and UnitName("player") or "") and not B.SignalFireTestSay then return nil end

      local stamp = p3_now()
      local key = semanticKey or p3_key(author, raw)
      B._sfP3Seen = B._sfP3Seen or {}
      B._sfP3Records = B._sfP3Records or {}
      local last = tonumber(B._sfP3Seen[key] or 0) or 0
      local existing = B._sfP3ActiveRecords and B._sfP3ActiveRecords[key] or nil
      if existing and (stamp - last) <= 5 then
        p3_note("deduped")
        if type(prepare) == "function" then
          local prepared, prepareError = pcall(prepare, existing)
          if not prepared then error(prepareError, 0) end
        end
        return existing
      end

      P3._recordSequence = (tonumber(P3._recordSequence or 0) or 0) + 1
      local id = "p5-" .. p3_hash(key) .. "-" .. tostring(P3._recordSequence)
      local rec = {id=id}
      rec.author = author
      rec.text = raw
      rec.channel = channel or "Public"
      rec.event = event or "CHAT"
      rec.canonicalKey = key
      rec.time = stamp
      rec.done = false
      rec.alerted = false
      rec.isNew = false
      B._sfP3Records[id] = rec
      B._sfP3ActiveRecords = B._sfP3ActiveRecords or {}
      B._sfP3ActiveRecords[key] = rec
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

      -- Complete the exact display decision before this record becomes visible
      -- to the deferred worker. The protected cleanup prevents a failed prepare
      -- from leaving an active record that can never be processed.
      if type(prepare) == "function" then
        local prepared, prepareError = pcall(prepare, rec)
        if not prepared then
          if B._sfP3ActiveRecords[key] == rec then B._sfP3ActiveRecords[key] = nil end
          if B._sfP3Records[id] == rec then B._sfP3Records[id] = nil end
          error(prepareError, 0)
        end
      end
      P3._pendingByStableId = P3._pendingByStableId or {}
      if rec.stableId then P3._pendingByStableId[rec.stableId] = rec end

      if B._sfP3Queue ~= nil and type(B._sfP3Queue) ~= "table" then
        p3_canary_abort("queue corruption")
        return nil
      end
      B._sfP3Queue = B._sfP3Queue or {}
      if #B._sfP3Queue > 40 then
        p3_canary_abort("hard queue bound exceeded")
        return nil
      end
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
      p3_note("queueRecordsCreated")
      local depth = p3_depth()
      if stats and depth > stats.maxDepth then stats.maxDepth = depth end
      if stats and depth > stats.queueMaximumDepth then stats.queueMaximumDepth = depth end

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
      if P3.StartParserWork then P3.StartParserWork()
      elseif B._sfP3Frame then B._sfP3Frame:Show() end
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

    -- Session-only exact decisions. Owner: SignalFireChatRuntime151. Key:
    -- normalized author plus complete normalized message. Value: one completed
    -- parser record or a conclusive negative. Maximum: 256 entries. TTL: 30s
    -- positive/5s negative. Eviction: cyclic oldest-slot replacement. Cleanup:
    -- replacement, runtime cache clear, profile reload, or session end.
    local function p3_cache_render_decision(key, rec, positive, stamp, ttl, rejection, origin)
      if not key or key == "" then return end
      stamp = stamp or p3_now()
      P3._renderDecisionCache = P3._renderDecisionCache or {}
      P3._renderDecisionSlots = P3._renderDecisionSlots or {}
      P3._renderDecisionCursor = ((tonumber(P3._renderDecisionCursor or 0) or 0) % P3.renderDecisionMaximum) + 1
      local old = P3._renderDecisionSlots[P3._renderDecisionCursor]
      if old then
        local current = P3._renderDecisionCache[old.key]
        if current and current.stamp == old.stamp then P3._renderDecisionCache[old.key] = nil end
      end
      local item = {
        rec=rec or false, stableId=rec and rec.stableId or nil, positive=positive == true,
         generation=tonumber(P3._renderGeneration or 0) or 0,
         aliasGeneration=P3.aliasGeneration,
         stamp=stamp, expires=stamp + (ttl or (positive and P3.renderDecisionPositiveTTL or P3.renderDecisionNegativeTTL)),
         rejection=rejection, ownerOrigin=origin or "source", sourceConsumed=origin ~= "filter",
      }
      P3._renderDecisionCache[key] = item
      P3._renderDecisionSlots[P3._renderDecisionCursor] = {key=key, stamp=stamp}
    end

    local function p3_cached_render_decision(author, text, preparedKey)
      local key = preparedKey or p3_render_key(author, text)
      local item = P3._renderDecisionCache and P3._renderDecisionCache[key] or nil
      if not item then p3_note("renderDecisionMisses"); return nil, false, key end
      local groupRowMissing = item.rec and item.rec ~= false and item.rec.kind == "group"
        and item.stableId and not (B.publicGroups and B.publicGroups[item.stableId])
      local guildRowMissing = item.rec and item.rec ~= false and item.rec.kind == "guild"
        and not item.rec.guildRow
      if item.aliasGeneration ~= P3.aliasGeneration
        or item.generation ~= (tonumber(P3._renderGeneration or 0) or 0)
        or p3_now() > (tonumber(item.expires or 0) or 0)
        or groupRowMissing or guildRowMissing then
        if item.rec == false then p3_note("negativeCacheInvalidations") end
        P3._renderDecisionCache[key] = nil
        p3_note("renderDecisionMisses")
        return nil, false, key
      end
      p3_note("renderDecisionHits")
      if item.rec == false then p3_note("negativeCacheHits") end
      return item.rec ~= false and item.rec or nil, true, key, item
    end

    local p3_render
    local p3_upsert_canonical
    local p3_upsert_guild_canonical

    -- Session-only re-entry guard. Owner: SignalFireChatRuntime151. Key: the
    -- semantic message key. Maximum: 64 simultaneously resolving messages.
    -- There is no TTL because each entry is removed by the protected-call
    -- cleanup before ResolveExactMessage returns. It is never persisted.
    local function p3_resolve(author, text, channel, event, origin)
      if not p3_parsing_enabled() then
        p3_note("parsingDisabledSourceReturns")
        return tostring(text or ""), nil
      end
      if not p3_canary_check("before source candidate") then return nil end
      p3_note("sourceEventsReceived")
      p3_note("exactResolverCalls")
      local raw = tostring(text or "")
      if raw == "" or p3_is_protocol(raw) then
        if p3_is_protocol(raw) then p3_note("protocolRejected") end
        p3_note("sourceEventsIgnored")
        return raw, nil
      end
      if p3_author(author) == p3_author(UnitName and UnitName("player") or "") and not B.SignalFireTestSay then
        p3_note("sourceEventsIgnored")
        return raw, nil
      end

      local diagnostics = p3_diagnostics_enabled()
      local resolverStarted = diagnostics and debugprofilestop and debugprofilestop() or nil
      local sourceKey = p3_source_key(event, channel, author, text)
      local cached, found, _, cachedItem = p3_cached_render_decision(author, raw, sourceKey)
      if found and origin == "source" and cachedItem and cachedItem.sourceConsumed == true then
        -- A new source event with identical text is a new logical occurrence.
        -- Filters may reuse the previous exact result before this point, but the
        -- source owner must refresh canonical time and deferred side effects once.
        P3._renderDecisionCache[sourceKey] = nil
        cached, found, cachedItem = nil, false, nil
      elseif found and origin == "source" and cachedItem then
        cachedItem.sourceConsumed = true
      end
      if found then
        p3_note("sourceDecisionHits")
        p3_note("sourceDuplicatesSuppressed")
        p3_note("exactResolverCacheHits")
        local display = cached and p3_options().inlineChatLinks == true and p3_render
          and p3_render(cached, raw) or raw
        return display, cached, sourceKey, cachedItem and cachedItem.rejection or nil
      end

      p3_note("decisionCacheMisses")
      p3_note("sourceDecisionMisses")
      p3_note("exactResolverCacheMisses")
      if origin == "filter" then p3_note("exactResolverFilterFallbacks") end

      P3._exactInFlight = P3._exactInFlight or {}
      P3._exactInFlightCount = tonumber(P3._exactInFlightCount or 0) or 0
      if P3._exactInFlight[sourceKey] or P3._exactInFlightCount >= 64 then
        p3_note("exactResolverReentryPrevented")
        return raw, nil, sourceKey
      end
      P3._exactInFlight[sourceKey] = true
      P3._exactInFlightCount = P3._exactInFlightCount + 1

      local display, decision, rejection = raw, nil, nil
      local ok, err = pcall(function()
        local accepted, candidateReason = p3_candidate(raw)
        if not accepted then
          rejection = candidateReason or "Cheap candidate gate rejected"
          p3_cache_render_decision(sourceKey, nil, false, nil, nil, rejection, origin)
          p3_note("sourceEventsIneligible")
          return
        end

        local parsed = p3_parse(raw)
        if not parsed then
          rejection = "Authoritative parser rejected the candidate"
          p3_cache_render_decision(sourceKey, nil, false, nil, nil, rejection, origin)
          p3_note("sourceEventsIneligible")
          return
        end

        p3_note("sourceEvents")
        p3_note("sourceEventsEligible")
        local rec = p3_enqueue(author, raw, channel, event, sourceKey, function(prepared)
          prepared.parsed = parsed
          prepared.kind = parsed.kind
          prepared.guildName = parsed.guildName or parsed.guild
          prepared.semanticKey = sourceKey
          prepared.candidateAccepted = true
          prepared.candidateReason = candidateReason
          prepared.resolverOwner = origin
          prepared.rejectionReason = nil
          if prepared.kind == "group" then
            p3_note("coreCalls")
            prepared.linkRow = p3_make_link_row(prepared, parsed)
            p3_upsert_canonical(prepared)
            p3_note("canonicalUpserts")
          elseif prepared.kind == "guild" then
            p3_upsert_guild_canonical(prepared)
            p3_note("canonicalUpserts")
            p3_note("guildCanonicalUpserts")
          end

          -- A positive decision is cached only after its canonical group row
          -- exists and its exact hyperlink has been constructed.
          if prepared.kind == "group" and not (prepared.stableId and B.publicGroups
            and B.publicGroups[prepared.stableId]) then
            error("Canonical Public Groups row was not created", 0)
          elseif prepared.kind == "guild" and not prepared.guildRow then
            error("Canonical Guild Browser row was not created", 0)
          end
          decision = prepared
          if p3_options().inlineChatLinks == true and p3_render then
            display = p3_render(prepared, raw)
            if display == raw then
              p3_note("eligibleMessagesWithoutLinks")
              if prepared.kind == "guild" then p3_note("eligibleGuildMessagesWithoutLinks")
              else p3_note("eligibleGroupMessagesWithoutLinks") end
            end
          end
          p3_cache_render_decision(sourceKey, prepared, true, nil, nil, nil, origin)
        end)
        if not rec then
          rejection = "Deferred side-effect queue unavailable"
          return
        end
      end)
      P3._exactInFlight[sourceKey] = nil
      P3._exactInFlightCount = math.max(0, P3._exactInFlightCount - 1)
      if not ok then
        p3_note("processingErrors")
        p3_note("parserErrors")
        rejection = tostring(err or "exact resolver error")
        display, decision = raw, nil
      end
      if decision then
        if origin == "filter" then p3_note("exactResolverFilterOwners")
        else p3_note("exactResolverSourceOwners") end
      end
      if decision then decision.rejectionReason = rejection end
      if diagnostics and resolverStarted and debugprofilestop then
        local elapsed = math.max(0, debugprofilestop() - resolverStarted)
        local stats = p3_stats()
        stats.exactResolverMsTotal = stats.exactResolverMsTotal + elapsed
        if elapsed > stats.exactResolverMsMax then stats.exactResolverMsMax = elapsed end
      end
      return display, decision, sourceKey, rejection
    end

    P3.ResolveExactMessage = p3_resolve

    local function p3_copy_authoritative(dst, src)
      if not (dst and src) then return end
      local fields = {"player", "message", "rawMessage", "channel", "type", "activity", "activities", "roles", "intent", "tags", "difficulty", "key", "keyLevel", "ilevel", "score"}
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

    p3_upsert_canonical = function(rec)
      if not rec or rec.kind ~= "group" then return nil end
      local diagnostics = p3_diagnostics_enabled()
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
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
      row.activities = parsed.activities or row.activities
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
      -- Compatibility layers may enrich tags or scores, but the one exact parser
      -- result remains authoritative for fields used by identity and link titles.
      row.type = parsed.type or row.type
      row.activity = parsed.activity or row.activity
      row.activities = parsed.activities or row.activities
      row.roles = parsed.roles or row.roles
      row.intent = parsed.intent or row.intent
      row.difficulty = parsed.difficulty or row.difficulty
      row.keyLevel = parsed.keyLevel or parsed.keylevel or row.keyLevel

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
      rec.shouldAlert = rec.shouldAlert or isNew
      B._lastPublicGroupTouched = row
      B._lastPublicGroupTouchedKey = id
      rec.publicDirtyReason = isNew and "chat-insert" or "chat-update"
      rec.needsPublicRefresh = true
      if diagnostics and started and debugprofilestop then
        local elapsed = math.max(0, debugprofilestop() - started)
        local stats = p3_stats()
        stats.canonicalUpsertMsTotal = stats.canonicalUpsertMsTotal + elapsed
        if elapsed > stats.canonicalUpsertMsMax then stats.canonicalUpsertMsMax = elapsed end
      end
      return row
    end

    -- Guild Browser rows use the existing normalized chat-listing map, so the
    -- shared resolver can create the canonical target in O(1) before caching a
    -- positive display decision. UI and favorite-feed side effects stay deferred.
    p3_upsert_guild_canonical = function(rec)
      if not rec or rec.kind ~= "guild" then return nil end
      local guild = p3_trim(rec.guildName)
      if guild == "" or type(B.UpsertGuildBrowserChatListing) ~= "function" then return nil end
      local diagnostics = p3_diagnostics_enabled()
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
      local key = type(_G.SF576_GuildKey) == "function" and _G.SF576_GuildKey(guild)
        or string.lower(guild):gsub("[^%w]+", "")

      B._sfP3SuppressGuildSideEffects = true
      local ok, err = pcall(B.UpsertGuildBrowserChatListing, B, guild, rec.author, rec.text)
      B._sfP3SuppressGuildSideEffects = nil
      if not ok then error(err, 0) end

      local row = B.chatGuildListings and B.chatGuildListings[key] or nil
      if not row then return nil end
      row.sf153CanonicalKey = key
      row.sessionOnly = true
      rec.guildKey = key
      rec.guildRow = row
      rec.stableId = "guild-" .. p3_hash(key)
      rec.resolvedId = rec.stableId
      rec.needsGuildRefresh = true
      rec.needsGuildFavoriteSideEffect = true
      if diagnostics and started and debugprofilestop then
        local elapsed = math.max(0, debugprofilestop() - started)
        local stats = p3_stats()
        stats.canonicalUpsertMsTotal = stats.canonicalUpsertMsTotal + elapsed
        if elapsed > stats.canonicalUpsertMsMax then stats.canonicalUpsertMsMax = elapsed end
      end
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
      P3._renderGeneration = (tonumber(P3._renderGeneration or 0) or 0) + 1
      P3._publicIndex = {}
      P3._publicIndexById = {}
      P3._publicIndexSlots = {}
      P3._publicIndexCursor = 0
      p3_note("indexRebuilds")
      p3_note("indexFullScans")
      p3_note("canonicalIndexRepairs")
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

    local p3_process

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
      local o = BronzeLFG_DB and BronzeLFG_DB.options
      return o ~= nil and p3_parsing_enabled() and o.inlineChatLinks == true
    end

    local function p3_frame_is_visible(frame)
      if not frame or not frame.IsShown then return true end
      local ok, shown = pcall(frame.IsShown, frame)
      if not ok then return true end
      return shown and true or false
    end

    local function p3_frame_allowed(frame, scope)
      scope = tostring(scope or "all")
      if scope == "all" then return true end
      if scope == "main" then
        return not frame or frame == DEFAULT_CHAT_FRAME or frame == _G.ChatFrame1
      end
      return p3_frame_is_visible(frame)
    end

    local function p3_role_summary(row)
      local roles = string.lower(tostring(row and row.roles or ""))
      local out = {}
      if string.find(roles, "tank", 1, true) then table.insert(out, "T") end
      if string.find(roles, "heal", 1, true) then table.insert(out, "H") end
      if string.find(roles, "dps", 1, true) or string.find(roles, "damage", 1, true) then
        table.insert(out, "D")
      end
      return table.concat(out, "/")
    end

    local function p3_exact_link_title(row)
      local diagnostics = p3_diagnostics_enabled()
      local started = diagnostics and debugprofilestop and debugprofilestop() or nil
      local activity = tostring(row and row.activity or "")
      if activity == "" or activity == "Unknown" then activity = tostring(row and row.type or "") end
      local intent = tostring(row and row.intent or "")
      local applicant = intent == "Applicant" or tostring(row and row.type or "") == "LFG"
      local roles = p3_role_summary(row)
      local suffix = applicant and "LFG" or "LFM"
      if roles ~= "" then suffix = (applicant and "LFG " or "Need ") .. roles end
      local title = activity ~= "" and (activity .. " - " .. suffix) or suffix
      title = string.gsub(title, "|", "")
      title = string.gsub(title, "%[", "(")
      title = string.gsub(title, "%]", ")")
      if string.len(title) > 72 then title = string.sub(title, 1, 69) .. "..." end
      if diagnostics and started and debugprofilestop then
        local elapsed = math.max(0, debugprofilestop() - started)
        local stats = p3_stats()
        stats.linkTitleMsTotal = stats.linkTitleMsTotal + elapsed
        if elapsed > stats.linkTitleMsMax then stats.linkTitleMsMax = elapsed end
      end
      return title
    end

    P3.BuildExactLinkTitle = p3_exact_link_title

    local function p3_insert_guild_link(raw, guild, link)
      local low = string.lower(tostring(raw or ""))
      local name = string.lower(tostring(guild or ""))
      if name == "" or not link then return raw end
      for _, wrapped in ipairs({"<" .. name .. ">", "[" .. name .. "]", name}) do
        local first, last = string.find(low, wrapped, 1, true)
        if first then return string.sub(raw, 1, first - 1) .. link .. string.sub(raw, last + 1) end
      end
      return raw .. " " .. link
    end

    p3_render = function(rec, raw)
      if not rec then return raw end
      if rec.kind == "guild" then
        local guild = tostring(rec.guildName or "")
        if guild == "" then return raw end
        if not rec._sfP3CachedLink and B.GuildChatLink then
          local ok, link = pcall(B.GuildChatLink, B, guild)
          if ok and link then
            rec._sfP3CachedLink = link
            p3_note("linksBuilt")
            p3_note("exactLinksBuilt")
            p3_note("guildLinksBuilt")
          end
        end
        return p3_insert_guild_link(raw, guild, rec._sfP3CachedLink)
      end
      local row = rec.stableId and B.publicGroups and B.publicGroups[rec.stableId] or nil
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
          local activity = tostring(row.activity or "")
          local generic = activity == "" or activity == "Group Listing"
            or activity == "Looking For Group" or activity == "SignalFire Group"
            or activity == "Open Group"
          if generic then
            p3_note("genericLinksBuilt")
          elseif row.id then
            local title = p3_exact_link_title(row)
            link = "|cffd4a017|Hbronzelfgpub:" .. tostring(row.id) .. "|h[" .. title .. "]|h|r"
          end
          if link then
            rec._sfP3CachedLinkSignature = signature
            rec._sfP3CachedLink = link
            p3_note("linksBuilt")
            p3_note("exactLinksBuilt")
          end
        end
      end
      return link and (raw .. " " .. link) or raw
    end

    p3_process = function(rec)
      if not rec or rec.done then return false end
      local row = rec.stableId and B.publicGroups and B.publicGroups[rec.stableId] or rec.linkRow
      B._sfChatQueueProcessing = true
      B._suppressPublicRefreshInChatLink = true
      B._sfP3SuppressNotify = true
      local ok, err = pcall(function()
        if rec.kind == "group" then
          if rec.needsPublicRefresh then
            if B.SF151_InvalidatePublicGroupsData then
              B:SF151_InvalidatePublicGroupsData(rec.publicDirtyReason or "chat-update", rec.stableId)
            end
            p3_note("refreshDirtyRequests")
            if B.RequestPublicGroupsRefresh then B:RequestPublicGroupsRefresh() end
            rec.needsPublicRefresh = nil
          end
        elseif rec.kind == "guild" then
          if rec.needsGuildRefresh and B.SF151_RequestPanelRefresh then
            B:SF151_RequestPanelRefresh("guildBrowser")
            rec.needsGuildRefresh = nil
          end
          if rec.needsGuildFavoriteSideEffect and B.SFN_RecordGuildRecruitmentActivity then
            B:SFN_RecordGuildRecruitmentActivity(rec.guildName, rec.text)
            rec.needsGuildFavoriteSideEffect = nil
          end
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
      elseif rec.kind == "group" and rec.shouldAlert and row and not rec.alerted and B.NotifyForPublicGroup then
        rec.alerted = true
        local alertOk = pcall(B.NotifyForPublicGroup, B, row)
        if alertOk then p3_note("alertsEmitted") else p3_note("processingErrors") end
        local removed = p3_prune_alert_seen()
        if removed > 0 then p3_note("entriesPruned", removed) end
      end
      p3_note("processed")
      p3_note("queueRecordsProcessed")
      return ok
    end

    function P3.Filter(frame, event, msgText, author, ...)
      local diagnostics = p3_diagnostics_enabled()
      local stats = diagnostics and p3_stats() or nil
      if stats then
        stats.filterCalls = stats.filterCalls + 1
        stats.filterReceipts = stats.filterReceipts + 1
      end
      local diag = diagnostics and p3_frame_diag(frame) or nil
      if diagnostics then
        diag.filterCalls = (diag.filterCalls or 0) + 1
        diag.lastFilterEvent = event
        diag.lastFilterText = tostring(msgText or "")
      end
      local options = BronzeLFG_DB and BronzeLFG_DB.options
      if not options or options.publicGroups == false or options.inlineChatLinks ~= true then
        if stats then
          stats.parsingDisabledFilterReturns = stats.parsingDisabledFilterReturns + 1
          stats.filterReceiptsWhileDisabled = stats.filterReceiptsWhileDisabled + 1
          stats.chatLinesPassedThrough = stats.chatLinesPassedThrough + 1
        end
        return false, msgText, author, ...
      end
      if msgText == nil or author == nil then
        if stats then stats.chatLinesPassedThrough = stats.chatLinesPassedThrough + 1 end
        return false, msgText, author, ...
      end
      if (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") and not B.SignalFireTestSay then
        if stats then stats.chatLinesPassedThrough = stats.chatLinesPassedThrough + 1 end
        return false, msgText, author, ...
      end
      if not p3_frame_allowed(frame, options.chatLinkScope) then
        if stats then
          stats.hiddenFrameLinkSkips = stats.hiddenFrameLinkSkips + 1
          stats.chatLinesPassedThrough = stats.chatLinesPassedThrough + 1
        end
        return false, msgText, author, ...
      end
      local raw = tostring(msgText)
      if diagnostics then
        diag.lastFilterAt = p3_now()
      end

      local rec, found, semanticKey = p3_cached_render_decision(author, raw)
      local out = rec and p3_render(rec, raw) or raw
      if not found then
        out, rec, semanticKey = p3_resolve(author, raw, select(2, ...), event, "filter")
      end
      if diagnostics and _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled
        and _G.SignalFirePerf151.NoteChatReceiver then
        _G.SignalFirePerf151:NoteChatReceiver(semanticKey or p3_render_key(author, raw), p3_frame_name(frame))
      end
      if diagnostics then
        diag.lastFilterKey = semanticKey
        diag.lastFilterWasEligible = rec ~= nil
      end
      if stats then
        if found then stats.filterDecisionHits = stats.filterDecisionHits + 1
        else stats.filterDecisionMisses = stats.filterDecisionMisses + 1 end
      end
      if out and out ~= raw then
        if stats then
          stats.linksAppended = stats.linksAppended + 1
          stats.chatLinesRewritten = stats.chatLinesRewritten + 1
        end
        if diagnostics then
          diag.rewritten = (diag.rewritten or 0) + 1
          diag.lastFilterRewritten = true
        end
        return false, out, author, ...
      end
      if stats then stats.chatLinesPassedThrough = stats.chatLinesPassedThrough + 1 end
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
        if frame.AddMessage == frame._sfP3CustomAddMessageHook and frame._sfP3CustomBaseAddMessage then
          frame.AddMessage = frame._sfP3CustomBaseAddMessage
        end
        frame._sfP3CustomAddMessageHook = nil
        frame._sfP3CustomBaseAddMessage = nil
        frame._sfP3WrapperGeneration = nil
        local base = frame._sffclOldAddMessage or frame._sfcpBaseAddMessage
        -- Only unwind a legacy wrapper when it still owns the method. Phase 3g
        -- restored this stale base unconditionally, clobbering later chat addons
        -- and its own newer wrapper during every reconciliation pass.
        if frame.AddMessage == frame._sffclAddMessageHook and base then frame.AddMessage = base end
        frame._sffclAddMessageHook = nil
      end)
    end

    -- Some custom 3.3.5 chat UIs discard the rewritten filter result. AddMessage
    -- reuses a completed decision or invokes the same exact resolver as the
    -- source/filter path. It has no independent parser, upsert, or side effects.
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

      local author, body, channel = p3_display_parts(displayed, plain)
      local rec, found, semanticKey = nil, false, nil
      if author ~= "" and body ~= "" then
        rec, found, semanticKey = p3_cached_render_decision(author, body)
        if not found then
          local _, resolved
          _, resolved, semanticKey = p3_resolve(author, body, channel, "CHAT", "filter")
          rec = resolved
        end
      end
      if diagnostics and rec and _G.SignalFirePerf151 and _G.SignalFirePerf151.enabled
        and _G.SignalFirePerf151.NoteChatReceiver then
        _G.SignalFirePerf151:NoteChatReceiver(semanticKey or p3_render_key(rec.author or author, rec.text or body), p3_frame_name(frame))
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
        local probe = P3._ownershipProbe
        if probe and probe.active and probe.sink == self then
          probe.depth = (probe.depth or 0) + 1
          probe.maximumDepth = math.max(probe.maximumDepth or 0, probe.depth)
          probe.hits = (probe.hits or 0) + 1
          probe.depth = math.max(0, probe.depth - 1)
          return
        end
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

    function P3.ReconcileFilterRegistration()
      local wanted = p3_links_enabled()
      if wanted == (P3._filterInstalled == true) then
        p3_note("duplicateRegistrationsPrevented")
        local stats = p3_diagnostics_enabled() and p3_stats() or nil
        if stats then stats.filtersCurrentlyInstalled = wanted and 3 or 0 end
        return wanted
      end
      if wanted then
        if not ChatFrame_AddMessageEventFilter then return false end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", P3.Filter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", P3.Filter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", P3.Filter)
        P3._filterInstalled = true
        P3._filterInstalledAt = p3_now()
        p3_note("filterRegistrationCalls", 3)
      else
        if P3._filterInstalled and ChatFrame_RemoveMessageEventFilter then
          pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_CHANNEL", P3.Filter)
          pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_SAY", P3.Filter)
          pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_YELL", P3.Filter)
          p3_note("filterUnregistrationCalls", 3)
        end
        P3._filterInstalled = false
        P3._filterInstalledAt = nil
      end
      local stats = p3_diagnostics_enabled() and p3_stats() or nil
      if stats then stats.filtersCurrentlyInstalled = wanted and 3 or 0 end
      return wanted
    end

    B._sfP3CoreAddPublicGroup = B._sfChatQueueOldAddPublicGroup or B.AddPublicGroup

    if not P3._sourceGateWrapped then
      P3._sourceGateWrapped = true
      P3._oldShouldSkipPublicChatEvent = B.SignalFireShouldSkipPublicChatEvent
      function B:SignalFireShouldSkipPublicChatEvent(author, text)
        if not p3_parsing_enabled() then
          p3_note("parsingDisabledSourceReturns")
          return true
        end
        if p3_is_protocol(text) then
          p3_note("protocolRejected")
          return true
        end
        return P3._oldShouldSkipPublicChatEvent
          and P3._oldShouldSkipPublicChatEvent(self, author, text) or false
      end
    end

    if not P3._notifyWrapped then
      P3._notifyWrapped = true
      P3._oldNotify = B.NotifyForPublicGroup
      function B:NotifyForPublicGroup(row)
        if self._sfP3SuppressNotify then return end
        return P3._oldNotify and P3._oldNotify(self, row) or nil
      end
    end

    local function p3_add_public(self, author, text, channel)
      if not p3_parsing_enabled() then
        p3_note("parsingDisabledSourceReturns")
        return nil
      end
      if self._sfP3Processing then
        local core = self._sfP3CoreAddPublicGroup
        return core and core(self, author, text, channel) or nil
      end
      local event = channel == "Say" and "CHAT_MSG_SAY"
        or (channel == "Yell" and "CHAT_MSG_YELL" or "CHAT_MSG_CHANNEL")
      p3_resolve(author, text, channel, event)
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

    if not P3._clearWrapped then
      P3._clearWrapped = true
      P3._oldClearPublicGroups = B.ClearPublicGroups
      function B:ClearPublicGroups(...)
        local results = {pcall(P3._oldClearPublicGroups, self, ...)}
        if not results[1] then error(results[2], 0) end
        p3_rebuild_public_index()
        return unpack(results, 2)
      end
    end

    -- Pending click targets are session-only, keyed by stable row ID, capped by
    -- the 40-record queue, and removed on process/drop. A click may finish the
    -- already-classified record before the next queue tick without reparsing.
    if not P3._publicLinkWrapped then
      P3._publicLinkWrapped = true
      P3._oldOpenPublicGroupLink = B.OpenPublicGroupLink
      function B:OpenPublicGroupLink(id, title)
        return P3._oldOpenPublicGroupLink and P3._oldOpenPublicGroupLink(self, id, title) or nil
      end
    end

    local function p3_discard_pending_records()
      local dropped = 0
      local queue = type(B._sfP3Queue) == "table" and B._sfP3Queue or {}
      for _, rec in ipairs(queue) do
        if type(rec) == "table" then
          rec.done = true
          rec.dropped = true
          if B._sfP3Records and rec.id then B._sfP3Records[rec.id] = nil end
          dropped = dropped + 1
        end
      end
      B._sfP3Queue = {}
      B._sfP3ActiveRecords = {}
      B._sfP3Seen = {}
      B._sfP3SeenSlots = {}
      P3._decisionCache = {}
      P3._decisionSlots = {}
      P3._pendingByStableId = {}
      P3._exactInFlight = {}
      P3._exactInFlightCount = 0
      return dropped
    end

    function P3.StopParserWork(reason)
      P3._parserSuspended = true
      P3._lastStopReason = tostring(reason or "parser stopped")
      local dropped = p3_discard_pending_records()
      if B._sfP3Frame then
        B._sfP3Frame:SetScript("OnUpdate", nil)
        B._sfP3Frame:Hide()
      end
      P3.ReconcileFilterRegistration()
      return true, dropped
    end

    function P3.Apply()
      if p3_option_parsing_enabled() then P3._parserSuspended = false end
      p3_disable_old_runtime()
      B.AddPublicGroup = p3_add_public
      B.InlinePublicChatLinkForMessage = p3_inline
      P3.PublicLinkTitle = P3.PublicLinkTitle or function(_, row)
        return p3_exact_link_title(row)
      end
      B.PublicLinkTitle = P3.PublicLinkTitle
      p3_restore_chat_frames()
      P3.ReconcileFilterRegistration()
      if not p3_parsing_enabled() then
        P3.StopParserWork("parsing disabled")
        P3._renderDecisionCache = {}
        P3._renderDecisionSlots = {}
      end
      if not P3._canonicalIndexBuilt then
        P3._canonicalIndexBuilt = true
        p3_rebuild_public_index()
      end
    end

    function P3.ClearRuntimeCaches()
      p3_discard_pending_records()
      B._sfP3Seen = {}
      B._sfP3SeenSlots = {}
      B._sfP3Records = {}
      B._sfP3RecordSlots = {}
      B._inlinePublicChatEventSeen = {}
      B._sfP3InlineSeenSlots = {}
      P3._decisionCache = {}
      P3._decisionSlots = {}
      P3._renderDecisionCache = {}
      P3._renderDecisionSlots = {}
      P3._pendingByStableId = {}
      P3._exactInFlight = {}
      P3._exactInFlightCount = 0
      P3._semanticKeyCache = {}
      P3._semanticKeySlots = {}
      P3._semanticKeyCursor = 0
      P3._renderGeneration = (tonumber(P3._renderGeneration or 0) or 0) + 1
      if B._sfP3Frame then
        B._sfP3Frame:SetScript("OnUpdate", nil)
        B._sfP3Frame:Hide()
      end
      return true
    end

    function P3.IngestSource(author, text, channel, event)
      local display, rec = p3_resolve(author, text, channel, event, "source")
      return rec, display
    end

    function P3.Candidate(text)
      return p3_candidate(text)
    end

    function P3.GetExactDiagnostics()
      local stats = p3_stats()
      return {
        generation=P3.generation,
        exactResolverCalls=stats.exactResolverCalls or 0,
        exactResolverCacheHits=stats.exactResolverCacheHits or 0,
        exactResolverCacheMisses=stats.exactResolverCacheMisses or 0,
        exactResolverFilterFallbacks=stats.exactResolverFilterFallbacks or 0,
        exactResolverSourceOwners=stats.exactResolverSourceOwners or 0,
        exactResolverFilterOwners=stats.exactResolverFilterOwners or 0,
        exactResolverReentryPrevented=stats.exactResolverReentryPrevented or 0,
        parserCalls=stats.parserCalls or 0,
        canonicalUpserts=stats.canonicalUpserts or 0,
        exactLinksBuilt=stats.exactLinksBuilt or 0,
        eligibleMessagesWithoutLinks=stats.eligibleMessagesWithoutLinks or 0,
        guildCandidates=stats.guildCandidates or 0,
        guildAccepted=stats.guildAccepted or 0,
        guildRejected=stats.guildRejected or 0,
        guildNameExtractionFailures=stats.guildNameExtractionFailures or 0,
        guildLinksBuilt=stats.guildLinksBuilt or 0,
        eligibleGuildMessagesWithoutLinks=stats.eligibleGuildMessagesWithoutLinks or 0,
        groupCandidates=stats.groupCandidates or 0,
        groupAccepted=stats.groupAccepted or 0,
        unknownActivities=stats.unknownActivities or 0,
        eligibleGroupMessagesWithoutLinks=stats.eligibleGroupMessagesWithoutLinks or 0,
        negativeCacheHits=stats.negativeCacheHits or 0,
        negativeCacheInvalidations=stats.negativeCacheInvalidations or 0,
        genericLinksBuilt=stats.genericLinksBuilt or 0,
        candidateMsTotal=stats.candidateMsTotal or 0,
        candidateMsMax=stats.candidateMsMax or 0,
        normalizationMsTotal=stats.normalizationMsTotal or 0,
        normalizationMsMax=stats.normalizationMsMax or 0,
        testParseMsTotal=stats.testParseMsTotal or 0,
        testParseMsMax=stats.testParseMsMax or 0,
        canonicalUpsertMsTotal=stats.canonicalUpsertMsTotal or 0,
        canonicalUpsertMsMax=stats.canonicalUpsertMsMax or 0,
        linkTitleMsTotal=stats.linkTitleMsTotal or 0,
        linkTitleMsMax=stats.linkTitleMsMax or 0,
        exactResolverMsTotal=stats.exactResolverMsTotal or 0,
        exactResolverMsMax=stats.exactResolverMsMax or 0,
      }
    end

    function P3.TraceMessage(message)
      local raw = p3_trim(message)
      local sourceKey = p3_source_key("CHAT_MSG_CHANNEL", "Trace", "SignalFireTrace", raw)
      local filterKey = p3_render_key("SignalFireTrace", raw)
      local before = p3_stats()
      local parserBefore = tonumber(before.parserCalls or 0) or 0
      local upsertBefore = tonumber(before.canonicalUpserts or 0) or 0
      local linkBefore = tonumber(before.exactLinksBuilt or 0) or 0
      local filterBefore = tonumber(before.filterReceipts or 0) or 0
      local priorDecision = P3._renderDecisionCache and P3._renderDecisionCache[sourceKey] or nil
      P3._traceDiagnosticsEnabled = true
      local ok, display, rec, semanticKey, rejection = pcall(
        p3_resolve, "SignalFireTrace", raw, "Trace", "CHAT_MSG_CHANNEL", "source")
      P3._traceDiagnosticsEnabled = false
      if not ok then
        return {message=raw, sourceCacheKey=sourceKey, filterCacheKey=filterKey,
          keyMatches=sourceKey == filterKey, candidateAccepted=false,
          rejectionReason=tostring(display or "trace resolver error"), exactParserResult="error",
          parserCallCount=0, upsertCount=0, linkBuildCount=0}
      end
      local after = p3_stats()
      local parsed = rec and rec.parsed or nil
      local row = rec and rec.kind == "guild" and rec.guildRow
        or (rec and rec.stableId and B.publicGroups and B.publicGroups[rec.stableId] or nil)
      local title = rec and rec.kind == "guild" and rec.guildName
        or (row and p3_exact_link_title(row) or nil)
      local hyperlink = rec and rec._sfP3CachedLink or nil
      return {
        message=raw,
        semanticKey=semanticKey or sourceKey,
        sourceCacheKey=sourceKey,
        filterCacheKey=filterKey,
        keyMatches=sourceKey == filterKey,
        candidateAccepted=rec and rec.candidateAccepted == true or false,
        candidateReason=rec and rec.candidateReason or nil,
        rejectionReason=rejection,
        exactParserResult=parsed and "eligible" or "ineligible",
        kind=parsed and parsed.kind or nil,
        intent=parsed and parsed.intent or nil,
        activity=parsed and parsed.activity or nil,
        activities=parsed and parsed.activities or nil,
        roles=parsed and parsed.roles or nil,
        unknownActivity=parsed and parsed.unknownActivity or nil,
        guildSeeker=parsed and parsed.kind == "guild" and false
          or (B.SF151_IsGuildSeeking and B:SF151_IsGuildSeeking(raw) or false),
        guildRecruiter=parsed and parsed.kind == "guild" or false,
        guildName=parsed and (parsed.guildName or parsed.guild) or nil,
        stableId=rec and rec.stableId or nil,
        canonicalRowExists=row ~= nil,
        linkTitle=title,
        finalHyperlink=hyperlink,
        finalDisplay=display,
        resolverOwner=rec and rec.resolverOwner or (priorDecision and priorDecision.ownerOrigin) or nil,
        negativeCacheState=priorDecision and priorDecision.rec == false or false,
        parserCallCount=(tonumber(after.parserCalls or 0) or 0) - parserBefore,
        upsertCount=(tonumber(after.canonicalUpserts or 0) or 0) - upsertBefore,
        linkBuildCount=(tonumber(after.exactLinksBuilt or 0) or 0) - linkBefore,
        filterReceiptCount=(tonumber(after.filterReceipts or 0) or 0) - filterBefore,
      }
    end

    local function p3_worker_update(frame, elapsed)
      if P3._workerRunning then
        p3_canary_abort("worker re-entry")
        return
      end
      if not p3_canary_check("worker frame") then return end
      P3._workerRunning = true
      local canaryWasActive = p3_canary_owner() ~= nil
      local ok, err = pcall(function()
        if type(B._sfP3Queue) ~= "table" then
          p3_canary_abort("queue corruption")
          return
        end
        if #B._sfP3Queue > 40 then
          p3_canary_abort("hard queue bound exceeded")
          return
        end
        if p3_depth() <= 0 then
          frame:SetScript("OnUpdate", nil)
          frame:Hide()
          p3_note("workerIdleFrames")
          return
        end
        p3_note("workerFramesActive")
        local frameStarted = debugprofilestop and debugprofilestop() or nil
        local processed = 0
        local stoppedByTime = false
        while processed < P3.workerMaximumRecords do
          if not p3_canary_check("before worker record") then return end
          local rec = p3_next()
          if rec ~= nil and type(rec) ~= "table" then
            p3_canary_abort("queue corruption")
            return
          end
          if not rec then break end
          local recordStarted = debugprofilestop and debugprofilestop() or nil
          p3_process(rec)
          processed = processed + 1
          p3_note("workerRecordsProcessed")
          if recordStarted and debugprofilestop then
            local recordMs = math.max(0, debugprofilestop() - recordStarted)
            local stats = p3_diagnostics_enabled() and p3_stats() or nil
            if stats and recordMs > stats.workerMaximumRecordMs then stats.workerMaximumRecordMs = recordMs end
          end
          if frameStarted and debugprofilestop and (debugprofilestop() - frameStarted) >= P3.workerMaximumMs then
            if p3_depth() > 0 then p3_note("workerBudgetStopsByTime") end
            stoppedByTime = true
            break
          end
        end
        if not stoppedByTime and processed >= P3.workerMaximumRecords and p3_depth() > 0 then
          p3_note("workerBudgetStopsByCount")
        end
        if frameStarted and debugprofilestop then
          local frameMs = math.max(0, debugprofilestop() - frameStarted)
          local stats = p3_diagnostics_enabled() and p3_stats() or nil
          if stats and frameMs > stats.workerMaximumFrameMs then stats.workerMaximumFrameMs = frameMs end
          if frameMs > 10 and p3_canary_owner() then p3_canary_abort("worker frame exceeded 10 ms") end
        end
        if p3_depth() <= 0 then
          frame:SetScript("OnUpdate", nil)
          frame:Hide()
        end
      end)
      P3._workerRunning = false
      if not ok then
        if canaryWasActive then p3_canary_abort("worker error") else error(err, 0) end
      end
    end

    B._sfP3Frame = B._sfP3Frame or (CreateFrame and CreateFrame("Frame") or nil)
    if B._sfP3Frame then
      B._sfP3Frame:SetScript("OnUpdate", nil)
      B._sfP3Frame:Hide()
    end

    function P3.StartParserWork()
      if not p3_parsing_enabled() or p3_depth() <= 0 or not B._sfP3Frame then return false end
      B._sfP3Frame:SetScript("OnUpdate", p3_worker_update)
      B._sfP3Frame:Show()
      return true
    end

    function P3.GetParserRuntimeState()
      local frame = B._sfP3Frame
      return {
        generation=P3.generation,
        workerGeneration=P3.workerGeneration,
        sourceOwnerActive=B.AddPublicGroup == p3_add_public,
        workerOwnerActive=type(p3_worker_update) == "function" and frame ~= nil,
        shutdownOwnerActive=type(P3.StopParserWork) == "function",
        sourceActive=p3_parsing_enabled(),
        workerActive=frame and frame.IsShown and frame:IsShown() or false,
        workerScript=frame and frame.GetScript and frame:GetScript("OnUpdate") ~= nil or false,
        queueDepth=p3_depth(),
        filtersInstalled=P3._filterInstalled == true and 3 or 0,
        suspended=P3._parserSuspended == true,
        lastStopReason=P3._lastStopReason,
      }
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

    function B:SF151_SetChatOwnershipDiagnostics(enabled)
      P3._stabilityDiagnosticsEnabled = enabled == true
      if not P3._stabilityDiagnosticsEnabled then P3._ownershipProbe = nil end
      return P3._stabilityDiagnosticsEnabled
    end

    -- Explicit, one-shot reachability probe. A temporary table proxy prevents a
    -- missing chain from writing to a real chat frame. The valid, visually empty
    -- string passes wrappers that reject nil and is intercepted before the stored
    -- SignalFire wrapper calls the underlying message frame.
    function B:SF151_ProbeChatFrameOwnership()
      local report = {generation="1.5.1-phase10b", frames={}, totals={
        signalFireOutermost=0, signalFireChained=0, signalFireMissing=0,
        signalFireDuplicated=0, unknown=0,
      }}
      p3_each_chat_frame(function(frame)
        local name = p3_frame_name(frame)
        local stored = frame._sfP3CustomAddMessageHook
        local current = frame.AddMessage
        local item = {name=name, generation=frame._sfP3WrapperGeneration,
          current=tostring(current), signalFire=tostring(stored), hits=0,
          maximumDepth=0, callSucceeded=false}
        if type(stored) ~= "function" or type(current) ~= "function" then
          item.state = "signalFireMissing"
        else
          local sink = {}
          setmetatable(sink, {__index=function(_, key)
            if key == "AddMessage" then return function() end end
            local value = frame[key]
            if type(value) == "function" then
              return function(_, ...) return value(frame, ...) end
            end
            return value
          end})
          local probe = {active=true, frame=frame, sink=sink, hits=0, depth=0, maximumDepth=0}
          P3._ownershipProbe = probe
          local ok, err = pcall(current, sink, "|c00000000|r")
          P3._ownershipProbe = nil
          item.callSucceeded = ok == true
          item.error = ok and nil or tostring(err or "probe call failed")
          item.hits = probe.hits or 0
          item.maximumDepth = probe.maximumDepth or 0
          if item.hits > 1 or item.maximumDepth > 1 then
            item.state = "signalFireDuplicated"
          elseif current == stored and item.hits == 1 then
            item.state = "signalFireOutermost"
          elseif item.hits == 1 then
            item.state = "signalFireChained"
          elseif ok then
            item.state = "signalFireMissing"
          else
            item.state = "unknown"
          end
        end
        report.totals[item.state] = (report.totals[item.state] or 0) + 1
        table.insert(report.frames, item)
      end)
      P3._ownershipProbe = nil
      table.sort(report.frames, function(left, right) return tostring(left.name) < tostring(right.name) end)
      P3._lastOwnershipProbe = report
      return report
    end

    function B:SF151_GetChatFilterState()
      local stats = p3_stats()
      stats.filtersCurrentlyInstalled = P3._filterInstalled == true and 3 or 0
      return {
        generation=P3.generation,
        expectedSignalFireFilters=p3_links_enabled() and 3 or 0,
        knownSignalFireRegistrations=P3._filterInstalled == true and 3 or 0,
        registrationKnown=P3._filterInstalled == true,
        introspection="WoW 3.3.5 does not expose the live filter list",
        filterCalls=stats.filterCalls or 0,
        messagesClassified=stats.sourceDecisionMisses or 0,
        messagesLinked=stats.linksAppended or 0,
        messagesParsed=stats.parserCalls or 0,
        logicalRecordsQueued=stats.enqueued or 0,
        logicalRecordsProcessed=stats.processed or 0,
        drops=stats.queueDrops or 0,
        candidateGateCalls=stats.candidateGateCalls or 0,
        candidateGateAccepted=stats.candidateGateAccepted or 0,
        candidateGateRejected=stats.candidateGateRejected or 0,
        TestParseCalls=stats.TestParseCalls or 0,
        filterReceipts=stats.filterReceipts or 0,
        filterDecisionHits=stats.filterDecisionHits or 0,
        filterDecisionMisses=stats.filterDecisionMisses or 0,
        chatLinesRewritten=stats.chatLinesRewritten or 0,
        workerFramesActive=stats.workerFramesActive or 0,
        workerRecordsProcessed=stats.workerRecordsProcessed or 0,
        workerBudgetStopsByCount=stats.workerBudgetStopsByCount or 0,
        workerBudgetStopsByTime=stats.workerBudgetStopsByTime or 0,
        historicalFullTableDuplicateScans=stats.historicalFullTableDuplicateScans or 0,
      }
    end

    function B:SF151_ResetChatRuntimeStats()
      self._sfP3Stats = {}
      P3._frameDiagnostics = {}
      local stats = p3_stats()
      stats.filtersCurrentlyInstalled = P3._filterInstalled == true and 3 or 0
      return true
    end

    function B:SF151_GetChatFrameDiagnostics()
      local options = p3_options()
      local probeByName = {}
      for _, item in ipairs((P3._lastOwnershipProbe and P3._lastOwnershipProbe.frames) or {}) do
        probeByName[item.name] = item
      end
      local result = {
        generation=P3.generation,
        developerDiagnostics=p3_diagnostics_enabled(),
        filterInstalled=P3._filterInstalled == true,
        filterInstalledAt=P3._filterInstalledAt,
        linksEnabled=p3_links_enabled(),
        publicGroupsEnabled=options.publicGroups ~= false,
        inlineChatLinksEnabled=options.inlineChatLinks == true,
        chatLinkScope=options.chatLinkScope,
        queueDepth=p3_depth(),
        counters={},
        frames={},
      }
      local liveStats = p3_stats()
      liveStats.filtersCurrentlyInstalled = P3._filterInstalled == true and 3 or 0
      for key, value in pairs(liveStats) do result.counters[key] = value end
      result.counters.heavyJobsQueued = result.counters.enqueued or 0
      result.counters.heavyJobsDeduplicated = result.counters.deduped or 0

      p3_each_chat_frame(function(frame)
        local diag = p3_frame_diag(frame)
        local item = {}
        for key, value in pairs(diag) do item[key] = value end
        item.visible = not frame.IsShown or frame:IsShown()
        item.signalFireWrapperInstalled = frame.AddMessage == frame._sfP3CustomAddMessageHook
        item.anotherFunctionReplacedIt = frame._sfP3CustomAddMessageHook ~= nil and not item.signalFireWrapperInstalled
        item.signalFireOutermostIdentity = item.signalFireWrapperInstalled
        item.differentOutermostIdentity = item.anotherFunctionReplacedIt
        item.ownershipState = probeByName[item.name] and probeByName[item.name].state
          or (item.signalFireOutermostIdentity and "signalFireOutermost" or "unknown")
        item.wrapperGeneration = frame._sfP3WrapperGeneration
        item.currentAddMessage = tostring(frame.AddMessage)
        item.signalFireAddMessage = tostring(frame._sfP3CustomAddMessageHook)
        if type(FCF_IsDocked) == "function" then
          local ok, value = pcall(FCF_IsDocked, frame)
          item.docked = ok and (value and true or false) or "unavailable"
        else
          item.docked = "unavailable"
        end
        item.messageCategories = {}
        if type(frame.GetMessageTypeList) == "function" then
          local values = {pcall(frame.GetMessageTypeList, frame)}
          if values[1] then
            for index = 2, #values do table.insert(item.messageCategories, tostring(values[index])) end
          end
        end
        item.displayedChannels = {}
        if type(frame.GetChannelList) == "function" then
          local values = {pcall(frame.GetChannelList, frame)}
          if values[1] then
            for index = 2, #values do table.insert(item.displayedChannels, tostring(values[index])) end
          end
        end
        table.insert(result.frames, item)
      end)
      local channelCounts = {}
      for _, item in ipairs(result.frames) do
        if item.visible then
          for _, channel in ipairs(item.displayedChannels or {}) do
            channelCounts[channel] = (channelCounts[channel] or 0) + 1
          end
        end
      end
      for _, item in ipairs(result.frames) do
        item.duplicatedPublicRouting = false
        for _, channel in ipairs(item.displayedChannels or {}) do
          if (channelCounts[channel] or 0) > 1 then item.duplicatedPublicRouting = true; break end
        end
      end
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
      emit("exact=" .. tostring(stats.exactResolverCalls or 0)
        .. ", cache=" .. tostring(stats.exactResolverCacheHits or 0) .. "/" .. tostring(stats.exactResolverCacheMisses or 0)
        .. ", owner=" .. tostring(stats.exactResolverSourceOwners or 0) .. "/" .. tostring(stats.exactResolverFilterOwners or 0)
        .. ", fallback=" .. tostring(stats.exactResolverFilterFallbacks or 0)
        .. ", reentry=" .. tostring(stats.exactResolverReentryPrevented or 0)
        .. ", upsert=" .. tostring(stats.canonicalUpserts or 0)
        .. ", links=" .. tostring(stats.exactLinksBuilt or 0)
        .. ", missing=" .. tostring(stats.eligibleMessagesWithoutLinks or 0)
        .. ", generic=" .. tostring(stats.genericLinksBuilt or 0))
      emit("exact ms: candidate=" .. string.format("%.3f/%.3f", tonumber(stats.candidateMsTotal or 0) or 0, tonumber(stats.candidateMsMax or 0) or 0)
        .. ", normalize=" .. string.format("%.3f/%.3f", tonumber(stats.normalizationMsTotal or 0) or 0, tonumber(stats.normalizationMsMax or 0) or 0)
        .. ", parse=" .. string.format("%.3f/%.3f", tonumber(stats.testParseMsTotal or 0) or 0, tonumber(stats.testParseMsMax or 0) or 0)
        .. ", upsert=" .. string.format("%.3f/%.3f", tonumber(stats.canonicalUpsertMsTotal or 0) or 0, tonumber(stats.canonicalUpsertMsMax or 0) or 0)
        .. ", title=" .. string.format("%.3f/%.3f", tonumber(stats.linkTitleMsTotal or 0) or 0, tonumber(stats.linkTitleMsMax or 0) or 0)
        .. ", resolver=" .. string.format("%.3f/%.3f", tonumber(stats.exactResolverMsTotal or 0) or 0, tonumber(stats.exactResolverMsMax or 0) or 0))
      for _, item in ipairs(report.frames or {}) do
        emit(tostring(item.name) .. ": visible=" .. tostring(item.visible)
          .. ", docked=" .. tostring(item.docked)
          .. ", categories=" .. tostring(#(item.messageCategories or {}))
          .. ", channels=" .. tostring(#(item.displayedChannels or {}))
          .. ", duplicateRoute=" .. tostring(item.duplicatedPublicRouting)
          .. ", state=" .. tostring(item.ownershipState)
          .. ", outermost=" .. tostring(item.signalFireOutermostIdentity)
          .. ", differentOutermost=" .. tostring(item.differentOutermostIdentity)
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
        selfRow.version = tostring(_G.SignalFire_VERSION or "1.5.3")
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
      local ok, result = pcall(B.SF151_RunSlowMaintenance, B, reason)
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
    eventFrame:SetScript("OnEvent", function(_, event)
      p4_attach_panel(B.sfnPanel)
      p4_attach_panel(B.onlinePanel)
      T.ApplyApplicantOwner()
      T.ApplyMinimapOwner()
      p4_update_listing_owner()
      T.RunMaintenance(event == "PLAYER_LOGIN" and "player-login" or "world-entry")
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

-- Phase 7 true lazy panel construction. Runtime data continues to load at
-- startup, while the main shell and feature frames are created on first use.
-- SIGNALFIRE_PHASE7_LAZY_PANELS_BEGIN
do
  local B = _G.BronzeLFG
  if B then
    local LP = _G.SignalFireLazyPanels151 or {}
    _G.SignalFireLazyPanels151 = LP
    LP.generation = "1.5.1-perf-phase7"
    LP.maximumErrors = 20
    -- Session-only lazy build error history. Owner: SignalFireLazyPanels151;
    -- key: FIFO insertion order with panel scope; max: 20; TTL: UI session;
    -- eviction: oldest on insert; cleanup: /sf perf reset or UI reload; never persisted.
    LP.errors = LP.errors or {}
    LP.stats = LP.stats or {}
    LP.panels = LP.panels or {}
    LP.order = LP.order or {
      "browse", "create", "profile", "applicants", "publicGroups",
      "guildBrowser", "myListing", "options", "network", "fullRoster", "invasions",
    }

    local function p7_now_ms()
      if debugprofilestop then return debugprofilestop() end
      return (GetTime and GetTime() or 0) * 1000
    end

    local function p7_pack(...)
      return {n=select("#", ...), ...}
    end

    local function p7_return(results)
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end

    local function p7_note(field, amount)
      LP.stats[field] = (tonumber(LP.stats[field] or 0) or 0) + (amount or 1)
      local perf = _G.SignalFirePerf151
      if perf and perf.enabled and perf.Note then perf:Note("ui", "lazy" .. string.upper(string.sub(field, 1, 1)) .. string.sub(field, 2), amount or 1) end
    end

    local function p7_emit(text)
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. tostring(text or ""))
      end
    end

    local function p7_frame_ready(field, required)
      return function(owner)
        if not owner or not owner[field] then return false end
        if required and not owner[required] then return false end
        return true
      end
    end

    local function p7_frame_visible(field)
      return function(owner)
        local frame = owner and owner[field]
        return frame and frame.IsShown and frame:IsShown() and true or false
      end
    end

    local original = LP.original or {}
    LP.original = original
    original.CreateUI = original.CreateUI or B.CreateUI
    original.HidePanels = original.HidePanels or B.HidePanels
    original.Show = original.Show or B.Show
    original.Toggle = original.Toggle or B.Toggle
    original.EnsureCoreUI = original.EnsureCoreUI or B.SF135N_EnsureCoreUI
    original.BuildMinimap = original.BuildMinimap or B.BuildMinimap
    original.UpdateMinimap = original.UpdateMinimap or B.UpdateMinimap
    original.RestoreMyListingState = original.RestoreMyListingState or B.RestoreMyListingState

    local definitions = {
      browse={builder="BuildBrowse", show="ShowBrowse", refresh="RefreshBrowse", ready=p7_frame_ready("browse"), visible=p7_frame_visible("browse"), shell=true},
      create={builder="BuildCreate", show="ShowCreate", refresh="UpdateCreateControls", ready=p7_frame_ready("create", "typeDrop"), visible=p7_frame_visible("create"), shell=true},
      profile={builder="BuildProfile", show="ShowProfile", refresh="UpdateWhisperPreview569", ready=p7_frame_ready("profile", "profileRole"), visible=p7_frame_visible("profile"), shell=true},
      applicants={builder="BuildApplicants", show="ShowApplicants", refresh="RefreshApplicants", ready=p7_frame_ready("apps", "appRows"), visible=p7_frame_visible("apps"), shell=true},
      publicGroups={builder="BuildPublicGroups", show="ShowPublicGroups", refresh="RefreshPublicGroups", ready=p7_frame_ready("publicPanel", "publicRows"), visible=p7_frame_visible("publicPanel"), shell=true},
      guildBrowser={builder="BuildGuildBrowser", show="ShowGuildBrowser", refresh="RefreshGuildBrowser", ready=p7_frame_ready("guildPanel"), visible=p7_frame_visible("guildPanel"), shell=true},
      myListing={builder="BuildMyListing", show="ShowMyListing", refresh="RefreshMyListing", ready=p7_frame_ready("myPanel"), visible=p7_frame_visible("myPanel"), shell=true},
      options={builder="BuildOptions", show="ShowOptions", ready=p7_frame_ready("optionsPanel"), shell=true},
      network={builder="BuildSFNetworkPanel", show="ShowSFNetwork", refresh="RefreshSFNetwork", ready=p7_frame_ready("sfnPanel"), visible=p7_frame_visible("sfnPanel"), shell=true, embedded={"events", "notices"}},
      fullRoster={builder="BuildOnlinePanel", show="ShowFullRoster", refresh="RefreshOnlinePanel",
        ready=function(owner) return owner and owner.onlinePanel and owner.onlinePanel._sfrpFullRoster and true or false end,
        visible=p7_frame_visible("onlinePanel"), shell=false},
      invasions={builder="BuildInvasions", show="ShowInvasions", refresh="RefreshInvasions", ready=p7_frame_ready("invasionPanel"), visible=p7_frame_visible("invasionPanel"), shell=true},
    }

    for key, def in pairs(definitions) do
      local record = LP.panels[key] or {}
      LP.panels[key] = record
      record.key = key
      record.builderName = def.builder
      record.showName = def.show
      record.refreshName = def.refresh
      record.ready = def.ready
      record.visible = def.visible
      record.requiresShell = def.shell ~= false
      record.dependencies = def.dependencies or {}
      record.embedded = def.embedded
      record.builder = record.builder or B[def.builder]
      record.show = record.show or B[def.show]
      record.refresh = record.refresh or (def.refresh and B[def.refresh] or nil)
      record.built = def.ready(B) and true or false
      record.building = false
      record.failed = record.failed == true
      record.dirty = record.dirty == true
      record.buildCount = tonumber(record.buildCount or 0) or 0
      record.buildRequests = tonumber(record.buildRequests or 0) or 0
      record.reuses = tonumber(record.reuses or 0) or 0
      record.failures = tonumber(record.failures or 0) or 0
      record.retries = tonumber(record.retries or 0) or 0
      record.refreshWhileUnbuilt = tonumber(record.refreshWhileUnbuilt or 0) or 0
      record.firstTrigger = record.firstTrigger
      record.buildMsTotal = tonumber(record.buildMsTotal or 0) or 0
      record.buildMsMax = tonumber(record.buildMsMax or 0) or 0
    end

    function LP:RecordError(scope, err)
      local row = {scope=tostring(scope or "unknown"), error=tostring(err or "unknown error"), at=time and time() or 0}
      table.insert(self.errors, row)
      while #self.errors > self.maximumErrors do table.remove(self.errors, 1) end
      return row
    end

    function LP:IsShellReady()
      return B.frame and B.side and B.content and true or false
    end

    function LP:EnsureStartup()
      p7_note("startupRequests", 1)
      if not self.restoredListingState and type(original.RestoreMyListingState) == "function" then
        self.restoredListingState = true
        local ok, err = pcall(original.RestoreMyListingState, B)
        if not ok then self:RecordError("RestoreMyListingState", err) end
      end
      if not B.mm and type(original.BuildMinimap) == "function" then
        local ok, err = pcall(original.BuildMinimap, B)
        if not ok then self:RecordError("BuildMinimap", err) end
      end
      if B.mm and type(original.UpdateMinimap) == "function" then
        local ok, err = pcall(original.UpdateMinimap, B)
        if not ok then self:RecordError("UpdateMinimap", err) end
      end
      return true
    end

    function LP:EnsureMainShell(trigger)
      p7_note("shellRequests", 1)
      if self:IsShellReady() then
        p7_note("shellReuses", 1)
        return true
      end
      if self.shellBuilding then
        local err = "recursive main-shell construction"
        self:RecordError("mainShell", err)
        p7_note("shellFailures", 1)
        return false, err
      end
      self.shellBuilding = true
      self.suppressFeatureBuilders = true
      self.shellTrigger = self.shellTrigger or tostring(trigger or "unknown")
      local started = p7_now_ms()
      local results = p7_pack(pcall(original.CreateUI, B))
      self.suppressFeatureBuilders = nil
      self.shellBuilding = nil
      local elapsed = math.max(0, p7_now_ms() - started)
      if results[1] and self:IsShellReady() then
        self.shellBuilt = true
        self.shellBuildCount = (tonumber(self.shellBuildCount or 0) or 0) + 1
        self.shellBuildMsTotal = (tonumber(self.shellBuildMsTotal or 0) or 0) + elapsed
        self.shellBuildMsMax = math.max(tonumber(self.shellBuildMsMax or 0) or 0, elapsed)
        p7_note("shellBuilds", 1)
        if B.frame and BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.scale then
          B.frame:SetScale(BronzeLFG_DB.options.scale)
        end
        if B.ApplySignalFireBetaTitle then pcall(B.ApplySignalFireBetaTitle, B) end
        if B.SFUI1434_Apply then pcall(B.SFUI1434_Apply, B) end
        return true
      end
      local err = results[1] and "main shell did not create its required controls" or results[2]
      self:RecordError("mainShell", err)
      p7_note("shellFailures", 1)
      return false, err
    end

    function LP:MarkDirty(key, reason)
      local record = self.panels[key]
      if not record then return false end
      record.dirty = true
      record.lastDirtyReason = tostring(reason or "data")
      if not record.built then
        record.dirtyWhileUnbuilt = (tonumber(record.dirtyWhileUnbuilt or 0) or 0) + 1
        p7_note("dirtyMarksWhileUnbuilt", 1)
      end
      return true
    end

    function LP:EnsurePanel(key, trigger)
      local record = self.panels[key]
      if not record then return false, "unknown panel: " .. tostring(key) end
      record.buildRequests = record.buildRequests + 1
      p7_note("panelBuildRequests", 1)
      if record.ready(B) and not record.failed then
        record.built = true
        record.failed = false
        record.reuses = record.reuses + 1
        p7_note("panelReuses", 1)
        return true, false
      end
      if record.building then
        local err = "lazy-panel dependency cycle at " .. tostring(key)
        record.failures = record.failures + 1
        record.lastError = err
        self:RecordError(key, err)
        p7_note("panelFailures", 1)
        return false, err
      end
      if record.failed then
        record.retries = record.retries + 1
        p7_note("panelRetries", 1)
      end
      if record.requiresShell then
        local ok, err = self:EnsureMainShell(trigger or key)
        if not ok then return false, err end
      end
      record.building = true
      for _, dependency in ipairs(record.dependencies or {}) do
        local ok, err = self:EnsurePanel(dependency, "dependency:" .. tostring(key))
        if not ok then
          record.building = false
          record.failed = true
          record.failures = record.failures + 1
          record.lastError = tostring(err)
          self:RecordError(key, err)
          p7_note("panelFailures", 1)
          return false, err
        end
      end
      self.activeBuilder = key
      record.firstTrigger = record.firstTrigger or tostring(trigger or "direct")
      local started = p7_now_ms()
      local results
      if type(record.builder) == "function" then
        results = p7_pack(pcall(record.builder, B))
      else
        results = {n=2, false, "missing builder " .. tostring(record.builderName)}
      end
      self.activeBuilder = nil
      record.building = false
      local elapsed = math.max(0, p7_now_ms() - started)
      if results[1] and record.ready(B) then
        record.built = true
        record.failed = false
        record.lastError = nil
        record.buildCount = record.buildCount + 1
        record.buildMsTotal = record.buildMsTotal + elapsed
        record.buildMsMax = math.max(record.buildMsMax, elapsed)
        if not self.mainOpenRequested then
          record.builtBeforeFirstOpen = (tonumber(record.builtBeforeFirstOpen or 0) or 0) + 1
          p7_note("panelsBuiltBeforeFirstOpen", 1)
        end
        if not self.mainOpenRequested and not (B.frame and B.frame:IsShown()) then
          record.builtWhileHidden = (tonumber(record.builtWhileHidden or 0) or 0) + 1
          p7_note("panelsBuiltWhileHidden", 1)
        end
        p7_note("panelBuilds", 1)
        local lifecycle = _G.SignalFireUILifecycle151
        if lifecycle and lifecycle.RegisterKnownDropdowns then lifecycle:RegisterKnownDropdowns(B) end
        return true, true
      end
      local err = results[1] and ("builder did not create " .. tostring(key)) or results[2]
      record.failed = true
      record.built = false
      record.failures = record.failures + 1
      record.lastError = tostring(err)
      self:RecordError(key, err)
      p7_note("panelFailures", 1)
      return false, err
    end

    function LP:HideBuiltPanels()
      local fields = {
        "browse", "create", "profile", "apps", "publicPanel", "guildPanel", "myPanel",
        "optionsPanel", "sfmmPanel", "sfcpPanel", "sfn138FavoriteOptionsPanel", "sfamPolishPanel",
        "sfe141EventOptionsPanel", "sfnPanel", "onlinePanel", "invasionPanel", "bronzeNetProfile",
      }
      for _, field in ipairs(fields) do
        local frame = B[field]
        if frame and frame.Hide then frame:Hide() end
      end
    end

    function LP:Open(key, trigger)
      self.mainOpenRequested = true
      local ok, builtOrError = self:EnsurePanel(key, trigger)
      if not ok then
        p7_emit("Could not open " .. tostring(key) .. ": " .. tostring(builtOrError))
        return false
      end
      local record = self.panels[key]
      local renderStarted = p7_now_ms()
      local results = p7_pack(pcall(record.show, B))
      if not results[1] then
        record.lastError = tostring(results[2])
        self:RecordError(key .. ".show", results[2])
        p7_emit("Could not show " .. tostring(key) .. ": " .. tostring(results[2]))
        return false
      end
      record.openCount = (tonumber(record.openCount or 0) or 0) + 1
      if not builtOrError then record.fastOpens = (tonumber(record.fastOpens or 0) or 0) + 1 end
      if builtOrError and not record.firstRenderMs then
        record.firstRenderMs = math.max(0, p7_now_ms() - renderStarted)
      end
      record.dirty = false
      return true
    end

    -- Login callers retain SavedVariables/minimap recovery but no longer create
    -- the shell or any feature panel.
    B.CreateUI = function(self)
      return LP:EnsureStartup()
    end

    -- Legacy recovery callers now repair only the shared shell and the currently
    -- selected failed panel. They never enumerate every feature panel.
    B.SF135N_EnsureCoreUI = function(self)
      if LP.shellBuilding then return LP:IsShellReady() end
      if not LP:IsShellReady() then return false end
      local tabMap = {
        ["Browse"]="browse", ["Create Listing"]="create", ["Profile"]="profile",
        ["Applicants"]="applicants", ["Public Groups"]="publicGroups",
        ["Guild Browser"]="guildBrowser", ["My Listing"]="myListing",
        ["Options"]="options", ["Network"]="network", ["Invasions"]="invasions",
      }
      local key = tabMap[self.currentTab]
      if key and LP.panels[key] and LP.panels[key].failed then LP:EnsurePanel(key, "repair") end
      return true
    end

    for key, record in pairs(LP.panels) do
      local panelKey = key
      local panelRecord = record
      B[panelRecord.builderName] = function(self, ...)
        if LP.suppressFeatureBuilders then
          p7_note("backgroundBuildsPrevented", 1)
          return nil
        end
        if panelRecord.ready(self) and not panelRecord.failed then return true end
        LP:MarkDirty(panelKey, "builder:" .. tostring(panelRecord.builderName))
        p7_note("backgroundBuildsPrevented", 1)
        return false
      end
      if panelRecord.refreshName and type(panelRecord.refresh) == "function" then
        local refreshName = panelRecord.refreshName
        B[refreshName] = function(self, ...)
          local isBuilt = panelRecord.ready(self)
          if not isBuilt or (panelRecord.visible and not panelRecord.visible(self)) then
            if not isBuilt then panelRecord.refreshWhileUnbuilt = panelRecord.refreshWhileUnbuilt + 1 end
            LP:MarkDirty(panelKey, refreshName)
            p7_note("refreshesConvertedToDirty", 1)
            return false
          end
          local results = p7_pack(pcall(panelRecord.refresh, self, ...))
          if not results[1] then error(results[2], 0) end
          panelRecord.dirty = false
          return unpack(results, 2, results.n)
        end
      end
      if type(panelRecord.show) == "function" then
        B[panelRecord.showName] = function(self, ...)
          if LP.suppressFeatureBuilders then
            p7_note("backgroundBuildsPrevented", 1)
            return false
          end
          return LP:Open(panelKey, "show:" .. tostring(panelRecord.showName))
        end
      end
    end

    -- Event/Notice boards are embedded in the current Network hub. Background
    -- protocol updates may dirty Network, but cannot create its board.
    original.SFE_BuildEventBoard = original.SFE_BuildEventBoard or B.SFE_BuildEventBoard
    original.SFE_RefreshEventBoard = original.SFE_RefreshEventBoard or B.SFE_RefreshEventBoard
    original.OpenSFEEventBoard = original.OpenSFEEventBoard or B.OpenSFEEventBoard
    if type(original.SFE_BuildEventBoard) == "function" then
      B.SFE_BuildEventBoard = function(self, ...)
        if LP.activeBuilder == "network" or (self.sfnPanel and self.sfnPanel:IsShown()) then
          return original.SFE_BuildEventBoard(self, ...)
        end
        LP:MarkDirty("network", "event-board-build")
        p7_note("backgroundBuildsPrevented", 1)
        return false
      end
    end
    if type(original.SFE_RefreshEventBoard) == "function" then
      B.SFE_RefreshEventBoard = function(self, ...)
        if not (self.sfnPanel and self.sfeEventPanel and self.sfnPanel:IsShown()) then
          LP:MarkDirty("network", "event-board-refresh")
          p7_note("refreshesConvertedToDirty", 1)
          return false
        end
        return original.SFE_RefreshEventBoard(self, ...)
      end
    end
    if type(original.OpenSFEEventBoard) == "function" then
      B.OpenSFEEventBoard = function(self, ...)
        local ok, err = LP:EnsurePanel("network", "show:Event Board")
        if not ok then return false, err end
        return original.OpenSFEEventBoard(self, ...)
      end
    end

    original.RequestPublicGroupsRefresh = original.RequestPublicGroupsRefresh or B.RequestPublicGroupsRefresh
    if type(original.RequestPublicGroupsRefresh) == "function" then
      B.RequestPublicGroupsRefresh = function(self, ...)
        LP:MarkDirty("publicGroups", "public-data")
        return original.RequestPublicGroupsRefresh(self, ...)
      end
    end

    B.HidePanels = function(self)
      LP:HideBuiltPanels()
    end

    B.Show = function(self)
      return LP:Open("browse", "show:main")
    end

    B.Toggle = function(self)
      LP:EnsureStartup()
      if self.frame and self.frame:IsShown() then self.frame:Hide(); return true end
      return LP:Open("browse", "toggle:main")
    end

    function B:SF151_GetLazyPanelDiagnostics()
      local panels = {}
      for _, key in ipairs(LP.order) do
        local record = LP.panels[key]
        panels[key] = {
          built=record.ready(self) and true or false,
          building=record.building == true,
          failed=record.failed == true,
          dirty=record.dirty == true,
          buildRequests=record.buildRequests,
          buildCount=record.buildCount,
          reuses=record.reuses,
          failures=record.failures,
          retries=record.retries,
          refreshWhileUnbuilt=record.refreshWhileUnbuilt,
          dirtyWhileUnbuilt=record.dirtyWhileUnbuilt or 0,
          fastOpens=record.fastOpens or 0,
          firstTrigger=record.firstTrigger,
          buildMsAverage=record.buildCount > 0 and (record.buildMsTotal / record.buildCount) or 0,
          buildMsMaximum=record.buildMsMax,
          firstRenderMs=record.firstRenderMs or 0,
          lastError=record.lastError,
        }
      end
      return {
        generation=LP.generation,
        shellBuilt=LP:IsShellReady(),
        shellBuildCount=LP.shellBuildCount or 0,
        shellBuildRequests=LP.stats.shellRequests or 0,
        shellReuses=LP.stats.shellReuses or 0,
        shellFailures=LP.stats.shellFailures or 0,
        shellBuildMsAverage=(LP.shellBuildCount or 0) > 0 and ((LP.shellBuildMsTotal or 0) / LP.shellBuildCount) or 0,
        shellBuildMsMaximum=LP.shellBuildMsMax or 0,
        backgroundBuildsPrevented=LP.stats.backgroundBuildsPrevented or 0,
        refreshesConvertedToDirty=LP.stats.refreshesConvertedToDirty or 0,
        panelsBuiltBeforeFirstOpen=LP.stats.panelsBuiltBeforeFirstOpen or 0,
        panelsBuiltWhileHidden=LP.stats.panelsBuiltWhileHidden or 0,
        errors=LP.errors,
        panels=panels,
      }
    end

    function B:SF151_PrintLazyPanelDiagnostics()
      local d = self:SF151_GetLazyPanelDiagnostics()
      p7_emit("lazy owner " .. tostring(d.generation) .. ", shell=" .. tostring(d.shellBuilt)
        .. ", shellBuilds=" .. tostring(d.shellBuildCount) .. ", prevented=" .. tostring(d.backgroundBuildsPrevented)
        .. ", dirty=" .. tostring(d.refreshesConvertedToDirty))
      for _, key in ipairs(LP.order) do
        local row = d.panels[key]
        p7_emit(key .. ": built=" .. tostring(row.built) .. ", builds=" .. tostring(row.buildCount)
          .. ", reuse=" .. tostring(row.reuses) .. ", dirty=" .. tostring(row.dirty)
          .. ", deferred=" .. tostring(row.refreshWhileUnbuilt) .. ", failures=" .. tostring(row.failures)
          .. ", avg=" .. string.format("%.3fms", row.buildMsAverage or 0)
          .. ", max=" .. string.format("%.3fms", row.buildMsMaximum or 0))
      end
      return d
    end

    function B:SF151_ResetLazyPanelStats()
      LP.stats = {}
      LP.errors = {}
      for _, record in pairs(LP.panels) do
        record.buildRequests = 0
        record.reuses = 0
        record.failures = 0
        record.retries = 0
        record.refreshWhileUnbuilt = 0
        record.dirtyWhileUnbuilt = 0
        record.fastOpens = 0
        record.buildMsTotal = 0
        record.buildMsMax = 0
      end
      return true
    end
  end
end
-- SIGNALFIRE_PHASE7_LAZY_PANELS_END

-- Phase 8 Browse snapshot, view, and incremental renderer ownership.
-- SIGNALFIRE_PHASE8_BROWSE_VIEW_BEGIN
do
  local B = _G.BronzeLFG
  local P4 = _G.SignalFireRefresh151
  local LP = _G.SignalFireLazyPanels151
  if B and P4 and P4.original and LP and LP.panels and LP.panels.browse then
    local BV = _G.SignalFireBrowseView151 or {}
    _G.SignalFireBrowseView151 = BV
    BV.generation = "1.5.1-perf-phase8"
    BV.dataGeneration = tonumber(BV.dataGeneration or 1) or 1
    BV.maximumViews = 16
    BV.viewCache = BV.viewCache or {}
    BV.viewOrder = BV.viewOrder or {}
    BV.rowStates = BV.rowStates or {}
    BV.detailState = BV.detailState or {fields={}}
    BV.stats = BV.stats or {}
    BV.dirty = BV.dirty ~= false
    BV.rendering = false
    BV.maximumErrors = 12
    BV.errors = BV.errors or {}

    -- Snapshot owner: SignalFireBrowseView151. Key: dataGeneration. Maximum:
    -- one snapshot. TTL: current generation. Eviction: material Browse data
    -- invalidation. Cleanup: mutation, profile change, or UI reload. Session-only.
    -- View owner: SignalFireBrowseView151. Key: generation/filter/search/sort/
    -- profile. Maximum: 16. TTL: current generation. Eviction: FIFO or data
    -- invalidation. Cleanup: view insertion, mutation, or UI reload. Session-only.

    local function p8_perf_enabled()
      local perf = _G.SignalFirePerf151
      return perf and perf.enabled == true
    end

    local function p8_note(field, amount)
      if not p8_perf_enabled() then return end
      BV.stats[field] = (tonumber(BV.stats[field] or 0) or 0) + (amount or 1)
    end

    local function p8_max(field, value)
      if not p8_perf_enabled() then return end
      value = tonumber(value or 0) or 0
      if value > (tonumber(BV.stats[field] or 0) or 0) then BV.stats[field] = value end
    end

    local function p8_now_ms()
      if debugprofilestop then return debugprofilestop() end
      return ((GetTime and GetTime()) or 0) * 1000
    end

    local function p8_now()
      return (time and time()) or 0
    end

    local function p8_pack(...)
      return {n=select("#", ...), ...}
    end

    local function p8_return(results)
      if not results[1] then error(results[2], 0) end
      return unpack(results, 2, results.n)
    end

    local function p8_visible()
      local frame = B.browse
      if not frame then return false end
      if frame.IsVisible then return frame:IsVisible() and true or false end
      return frame.IsShown and frame:IsShown() and true or false
    end

    local function p8_lower(value)
      return string.lower(tostring(value or ""))
    end

    local function p8_short(value, maximum)
      local text = tostring(value or "")
      maximum = tonumber(maximum or 34) or 34
      if string.len(text) <= maximum then return text end
      return string.sub(text, 1, math.max(1, maximum - 3)) .. "..."
    end

    local function p8_type_color(kind)
      local colors = {
        Dungeon="|cff3fa7ff", Raid="|cff4dff7a", Key="|cffb866ff",
        Event="|cffff9a33", Guild="|cff00e6cc", LFG="|cffffff66",
        Social="|cffff66cc", Other="|cffaaaaaa",
      }
      return colors[tostring(kind or "")] or colors.Other
    end

    local function p8_icon(kind)
      kind = tostring(kind or "")
      if kind == "Raid" then return "Interface\\Icons\\Achievement_Boss_Ragnaros" end
      if kind == "World Boss" then return "Interface\\Icons\\Achievement_Boss_CThun" end
      if kind == "Ascended" then return "Interface\\Icons\\Spell_Holy_SealOfWrath" end
      return "Interface\\Icons\\INV_Misc_Map07"
    end

    local function p8_role_letter(role)
      if role == "Tank" then return "|cff4aa3ffT|r" end
      if role == "Healer" then return "|cff44ff66H|r" end
      if role == "DPS" then return "|cffff5555D|r" end
      return "|cffffff66F|r"
    end

    local function p8_role_text(role)
      if role == "Tank" then return "|TInterface\\Icons\\Ability_Defend:14:14:0:0|t |cff4aa3ffTank|r" end
      if role == "Healer" then return "|TInterface\\Icons\\Spell_Holy_FlashHeal:14:14:0:0|t |cff44ff66Healer|r" end
      if role == "DPS" then return "|TInterface\\Icons\\Ability_DualWield:14:14:0:0|t |cffff5555DPS|r" end
      return "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t |cffffff66Flexible|r"
    end

    local function p8_roles_short(listing)
      local out = {}
      if listing.needTank == "1" or listing.needTank == 1 then table.insert(out, p8_role_letter("Tank")) end
      if listing.needHealer == "1" or listing.needHealer == 1 then table.insert(out, p8_role_letter("Healer")) end
      if listing.needDPS == "1" or listing.needDPS == 1 then table.insert(out, p8_role_letter("DPS")) end
      if #out == 0 then return p8_role_letter("Flexible") end
      return table.concat(out, "/")
    end

    local function p8_roles_long(listing)
      local out = {}
      if listing.needTank == "1" or listing.needTank == 1 then table.insert(out, p8_role_text("Tank")) end
      if listing.needHealer == "1" or listing.needHealer == 1 then table.insert(out, p8_role_text("Healer")) end
      if listing.needDPS == "1" or listing.needDPS == 1 then table.insert(out, p8_role_text("DPS")) end
      if #out == 0 then return p8_role_text("Flexible") end
      return table.concat(out, "  ")
    end

    local function p8_age(timestamp)
      local seconds = p8_now() - (tonumber(timestamp) or p8_now())
      if seconds < 0 then seconds = 0 end
      if seconds < 60 then return tostring(seconds) .. " sec ago" end
      if seconds < 3600 then return tostring(math.floor(seconds / 60)) .. " min ago" end
      return tostring(math.floor(seconds / 3600)) .. " hr ago"
    end

    local function p8_listing_signature(listing)
      if type(listing) ~= "table" then return "" end
      return table.concat({
        tostring(listing.id or ""), tostring(listing.leader or ""), tostring(listing.class or ""),
        tostring(listing.classFile or ""), tostring(listing.type or ""), tostring(listing.activity or ""),
        tostring(listing.difficulty or ""), tostring(listing.key or ""), tostring(listing.minItemLevel or ""),
        tostring(listing.members or ""), tostring(listing.maxMembers or ""), tostring(listing.needTank or ""),
        tostring(listing.needHealer or ""), tostring(listing.needDPS or ""), tostring(listing.voice or ""),
        tostring(listing.loot or ""), tostring(listing.note or ""), tostring(listing.created or ""),
        tostring(listing.seen or ""),
      }, "\31")
    end

    local function p8_applicant_signature(applicant)
      if type(applicant) ~= "table" then return "" end
      return table.concat({
        tostring(applicant.listingId or ""), tostring(applicant.name or ""), tostring(applicant.class or ""),
        tostring(applicant.role or ""), tostring(applicant.itemLevel or ""), tostring(applicant.roleType or ""),
        tostring(applicant.discord or ""), tostring(applicant.note or ""), tostring(applicant.applied or ""),
      }, "\31")
    end

    local function p8_profile()
      return tostring(BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "Triumvirate")
    end

    local function p8_clear_views()
      BV.viewCache = {}
      BV.viewOrder = {}
    end

    function BV:CommitInvalidation(reason)
      self.dataGeneration = (tonumber(self.dataGeneration or 0) or 0) + 1
      self.snapshot = nil
      p8_clear_views()
      self.dirty = true
      self.lastDirtyReason = tostring(reason or "data")
      p8_note("generationIncrements", 1)
      local record = LP.panels and LP.panels.browse
      if record then
        record.dirty = true
        record.lastDirtyReason = self.lastDirtyReason
      end
      return self.dataGeneration
    end

    function BV:Invalidate(reason)
      if (tonumber(self.mutationDepth or 0) or 0) > 0 then
        self.pendingInvalidation = true
        self.pendingInvalidationReason = tostring(reason or self.pendingInvalidationReason or "data")
        self.dirty = true
        local record = LP.panels and LP.panels.browse
        if record then record.dirty = true end
        return self.dataGeneration
      end
      return self:CommitInvalidation(reason)
    end

    function BV:BeginMutation()
      self.mutationDepth = (tonumber(self.mutationDepth or 0) or 0) + 1
    end

    function BV:EndMutation()
      self.mutationDepth = math.max(0, (tonumber(self.mutationDepth or 1) or 1) - 1)
      if self.mutationDepth == 0 and self.pendingInvalidation then
        local reason = self.pendingInvalidationReason
        self.pendingInvalidation = nil
        self.pendingInvalidationReason = nil
        return self:CommitInvalidation(reason)
      end
      return self.dataGeneration
    end

    local function p8_record_error(scope, err)
      table.insert(BV.errors, {scope=tostring(scope or "browse"), error=tostring(err or "unknown"), at=p8_now()})
      while #BV.errors > BV.maximumErrors do table.remove(BV.errors, 1) end
    end

    local function p8_build_applicant_counts()
      local counts = {}
      for _, applicant in pairs(B.applicants or {}) do
        local id = tostring(applicant and applicant.listingId or "")
        if id ~= "" then counts[id] = (counts[id] or 0) + 1 end
      end
      return counts
    end

    local function p8_build_snapshot()
      p8_note("snapshotRequests", 1)
      if BV.snapshot and BV.snapshot.generation == BV.dataGeneration then
        p8_note("snapshotCacheHits", 1)
        return BV.snapshot
      end
      if BV.injectSnapshotFailure then error("injected Browse snapshot failure") end
      local started = p8_perf_enabled() and p8_now_ms() or nil
      local rows = {}
      local expired = {}
      local applicantCounts = p8_build_applicant_counts()
      local nowValue = p8_now()
      for id, listing in pairs(B.listings or {}) do
        local seen = tonumber(listing and listing.seen or 0) or 0
        if seen > 0 and nowValue - seen > 900 then
          table.insert(expired, id)
        elseif type(listing) == "table" then
          local kind = tostring(listing.type or "Group")
          local activity = tostring(listing.activity or "Unknown")
          local difficulty = tostring(listing.difficulty or "")
          if difficulty == "Mythic+" and tostring(listing.key or "") ~= "" then
            difficulty = difficulty .. " " .. tostring(listing.key)
          end
          local meta = kind
          if difficulty ~= "" then meta = meta .. " - " .. difficulty end
          if tostring(listing.note or "") ~= "" then meta = meta .. " - " .. tostring(listing.note) end
          local record = {
            id=tostring(listing.id or id), listing=listing, kind=kind, activity=activity,
            difficulty=difficulty, leader=tostring(listing.leader or ""), note=tostring(listing.note or ""),
            seen=seen, created=tonumber(listing.created or seen) or seen,
            sortSeen=seen, icon=p8_icon(kind), title=p8_type_color(kind) .. activity .. "|r",
            rowNote=p8_short(meta, 34), rolesShort=p8_roles_short(listing), rolesLong=p8_roles_long(listing),
            itemLevel=(tostring(listing.minItemLevel or "") ~= "") and (tostring(listing.minItemLevel) .. "+") or "--",
            detailItemLevel=(tostring(listing.minItemLevel or "") ~= "") and (tostring(listing.minItemLevel) .. "+") or "Not provided",
            members=tostring(listing.members or 1) .. " / " .. tostring(listing.maxMembers or 5),
            applicantCount=applicantCounts[tostring(listing.id or id)] or 0,
          }
          record.searchText = p8_lower(table.concat({activity, record.leader, record.note, kind, difficulty}, " "))
          record.materialSignature = p8_listing_signature(listing) .. "\31" .. tostring(record.applicantCount)
          record.rowSignature = table.concat({
            record.id, record.icon, record.title, record.rowNote, record.leader,
            record.rolesShort, record.itemLevel, record.members,
          }, "\31")
          table.insert(rows, record)
          p8_note("listingsProcessed", 1)
          p8_note("normalizedStringsGenerated", 1)
        end
      end
      if #expired > 0 then
        for _, id in ipairs(expired) do B.listings[id] = nil end
        if B.selectedListing and not B.listings[B.selectedListing] then B.selectedListing = nil end
        BV:Invalidate("expiration")
        p8_note("expiredListings", #expired)
      end
      table.sort(rows, function(left, right)
        if left.sortSeen ~= right.sortSeen then return left.sortSeen > right.sortSeen end
        return left.id < right.id
      end)
      p8_note("canonicalSorts", 1)
      local snapshot = {
        generation=BV.dataGeneration, rows=rows, byId={},
        applicantCounts=applicantCounts,
      }
      for _, record in ipairs(rows) do snapshot.byId[record.id] = record end
      BV.snapshot = snapshot
      p8_note("snapshotsBuilt", 1)
      if started then
        local elapsed = math.max(0, p8_now_ms() - started)
        p8_note("snapshotBuildMsTotal", elapsed)
        p8_max("snapshotBuildMsMax", elapsed)
      end
      return snapshot
    end

    local function p8_filter_matches(record, filter)
      if filter == "Dungeons" then return record.kind == "Dungeon" end
      if filter == "Raids" then return record.kind == "Raid" or record.kind == "Ascended" end
      if filter == "World Bosses" then return record.kind == "World Boss" end
      if filter == "Custom" then return record.kind == "Custom Event" end
      return true
    end

    local function p8_view_inputs()
      local filter = tostring(B.filter or "All")
      local search = ""
      if B.search and B.search.GetText then
        local value = B.search:GetText()
        if type(value) == "string" or type(value) == "number" then search = p8_lower(value) end
      end
      search = string.gsub(search, "^%s+", "")
      search = string.gsub(search, "%s+$", "")
      local sortMode = tostring(B.browseSort or "Recent")
      local profile = p8_profile()
      return filter, search, sortMode, profile
    end

    local function p8_get_view(snapshot)
      p8_note("viewRequests", 1)
      local filter, search, sortMode, profile = p8_view_inputs()
      local signature = table.concat({tostring(snapshot.generation), filter, search, sortMode, profile}, "\31")
      local cached = BV.viewCache[signature]
      if cached then
        p8_note("viewCacheHits", 1)
        return cached, signature
      end
      if BV.injectViewFailure then error("injected Browse view failure") end
      local started = p8_perf_enabled() and p8_now_ms() or nil
      local rows = {}
      for _, record in ipairs(snapshot.rows) do
        p8_note("filterScans", 1)
        local keep = p8_filter_matches(record, filter)
        if keep and search ~= "" then
          p8_note("searchScans", 1)
          keep = string.find(record.searchText, search, 1, true) ~= nil
        end
        if keep then table.insert(rows, record) end
      end
      local view = {signature=signature, rows=rows, filter=filter, search=search, sortMode=sortMode, profile=profile}
      BV.viewCache[signature] = view
      table.insert(BV.viewOrder, signature)
      while #BV.viewOrder > BV.maximumViews do
        local old = table.remove(BV.viewOrder, 1)
        BV.viewCache[old] = nil
        p8_note("viewEvictions", 1)
      end
      p8_note("viewsBuilt", 1)
      if started then
        local elapsed = math.max(0, p8_now_ms() - started)
        p8_note("viewBuildMsTotal", elapsed)
        p8_max("viewBuildMsMax", elapsed)
      end
      return view, signature
    end

    local function p8_set_text(cache, key, target, value)
      value = tostring(value or "")
      if cache[key] == value then return false end
      cache[key] = value
      if target and target.SetText then target:SetText(value) end
      p8_note("setTextCalls", 1)
      return true
    end

    local function p8_set_texture(cache, key, target, value)
      value = tostring(value or "")
      if cache[key] == value then return false end
      cache[key] = value
      if target and target.SetTexture then target:SetTexture(value) end
      p8_note("textureWrites", 1)
      return true
    end

    local function p8_set_shown(cache, key, target, shown)
      shown = shown and true or false
      if cache[key] == shown then return false end
      cache[key] = shown
      if target then
        if shown and target.Show then target:Show() elseif not shown and target.Hide then target:Hide() end
      end
      return true
    end

    local function p8_render_rows(view, page, pageSize)
      if BV.injectRowFailure then error("injected Browse row-render failure") end
      local started = p8_perf_enabled() and p8_now_ms() or nil
      local first = ((page - 1) * pageSize) + 1
      p8_note("pageSliceRequests", 1)
      for index, row in ipairs(B.rows or {}) do
        p8_note("rowsConsidered", 1)
        local record = view.rows[first + index - 1]
        local state = BV.rowStates[index]
        if type(state) ~= "table" then state = {fields={}}; BV.rowStates[index] = state end
        if type(state.fields) ~= "table" then state.fields = {} end
        local cache = state.fields
        if record then
          local selected = record.id == B.selectedListing
          local signature = record.rowSignature .. "\31" .. tostring(selected)
          if state.signature == signature then
            p8_note("rowSignatureHits", 1)
          else
            state.signature = signature
            row.key = record.id
            p8_set_shown(cache, "shown", row, true)
            p8_set_texture(cache, "icon", row.icon, record.icon)
            p8_set_text(cache, "title", row.title, record.title)
            p8_set_text(cache, "note", row.note, record.rowNote)
            p8_set_text(cache, "leader", row.leader, record.leader)
            p8_set_text(cache, "roles", row.roles, record.rolesShort)
            p8_set_text(cache, "ilvl", row.ilvl, record.itemLevel)
            p8_set_text(cache, "members", row.members, record.members)
            if cache.selected ~= selected then
              cache.selected = selected
              if row.SetBackdropColor then
                if selected then row:SetBackdropColor(.45, .28, .02, .95) else row:SetBackdropColor(0, 0, 0, .85) end
              end
              p8_note("backdropWrites", 1)
            end
            p8_note("rowsMateriallyWritten", 1)
          end
        else
          if cache.shown ~= false or row.key ~= nil then
            row.key = nil
            state.signature = nil
            p8_set_shown(cache, "shown", row, false)
            p8_note("rowsMateriallyWritten", 1)
          end
        end
      end
      if started then
        local elapsed = math.max(0, p8_now_ms() - started)
        p8_note("rowRenderMsTotal", elapsed)
        p8_max("rowRenderMsMax", elapsed)
      end
    end

    local function p8_render_detail(snapshot)
      p8_note("detailRequests", 1)
      local detail = B.detail
      if not detail then return end
      if type(BV.detailState) ~= "table" then BV.detailState = {fields={}} end
      if type(BV.detailState.fields) ~= "table" then BV.detailState.fields = {} end
      local cache = BV.detailState.fields
      local record = snapshot.byId[tostring(B.selectedListing or "")]
      if B.selectedListing and not record then B.selectedListing = nil end
      local age = record and p8_age(record.created) or ""
      local signature = record and (record.id .. "\31" .. record.materialSignature .. "\31" .. age) or "none"
      if BV.detailState.signature == signature then
        p8_note("detailSignatureHits", 1)
        return
      end
      local started = p8_perf_enabled() and p8_now_ms() or nil
      BV.detailState.signature = signature
      if not record then
        p8_set_text(cache, "title", detail.title, "No group selected")
        p8_set_text(cache, "sub", detail.sub, "")
        p8_set_text(cache, "note", detail.note, "Select a listing to view details.")
        p8_set_text(cache, "body", detail.body, "")
        p8_set_text(cache, "apps", detail.apps, "View Applicants")
      else
        local listing = record.listing
        local sub = record.difficulty .. " " .. record.kind
        local body = "|cffffcc00Leader:|r " .. record.leader
          .. "\n|cffffcc00Created:|r " .. age
          .. "\n|cffffcc00Level Req:|r 60"
          .. "\n|cffffcc00Item Level:|r " .. record.detailItemLevel
          .. "\n|cffffcc00SignalFire Network:|r " .. record.members
          .. "\n|cffffcc00Applicants:|r " .. tostring(record.applicantCount)
          .. "\n|cffffcc00Roles Needed:|r " .. record.rolesLong
          .. "\n|cffffcc00Voice Chat:|r " .. tostring(listing.voice or "None")
          .. "\n|cffffcc00Loot Method:|r " .. tostring(listing.loot or "Group Loot")
        p8_set_text(cache, "title", detail.title, "|cffb84dff" .. record.activity .. "|r")
        p8_set_text(cache, "sub", detail.sub, sub)
        p8_set_text(cache, "note", detail.note, record.note)
        p8_set_text(cache, "body", detail.body, body)
        p8_set_text(cache, "apps", detail.apps, "View Applicants (" .. tostring(record.applicantCount) .. ")")
      end
      p8_note("detailRenders", 1)
      if started then
        local elapsed = math.max(0, p8_now_ms() - started)
        p8_note("detailRenderMsTotal", elapsed)
        p8_max("detailRenderMsMax", elapsed)
      end
    end

    local function p8_render_badge(snapshot)
      local count = 0
      if B.myListing and B.myListing.id then count = snapshot.applicantCounts[tostring(B.myListing.id)] or 0 end
      if BV.lastBadgeCount == count then return end
      BV.lastBadgeCount = count
      if B.badge then
        if count > 0 then
          if B.badge.Show then B.badge:Show() end
          if B.badge.text and B.badge.text.SetText then B.badge.text:SetText(tostring(count)); p8_note("setTextCalls", 1) end
        elseif B.badge.Hide then B.badge:Hide() end
      end
    end

    function BV:AuthoritativeRefresh()
      p8_note("authoritativeRefreshes", 1)
      if not B.rows or not B.browse then
        self.dirty = true
        p8_note("refreshWhileUnbuilt", 1)
        return false
      end
      if not p8_visible() then
        self.dirty = true
        p8_note("hiddenRendersSkipped", 1)
        return false
      end
      if self.rendering then
        self.dirty = true
        p8_note("duplicateRefreshAvoided", 1)
        return false
      end
      self.rendering = true
      local started = p8_perf_enabled() and p8_now_ms() or nil
      local previousGeneration = self.lastRenderedGeneration
      local previousView = self.lastRenderedView
      local previousSelection = self.lastRenderedSelection
      local results = p8_pack(pcall(function()
        local snapshot = p8_build_snapshot()
        local view, viewSignature = p8_get_view(snapshot)
        local pageSize = math.max(1, #(B.rows or {}))
        local pages = math.max(1, math.ceil(#view.rows / pageSize))
        local page = tonumber(B.browsePage or 1) or 1
        if page < 1 then page = 1 end
        if page > pages then page = pages end
        B.browsePage = page
        if previousGeneration == snapshot.generation and previousView == viewSignature
          and previousSelection ~= B.selectedListing then
          p8_note("selectionOnlyUpdates", 1)
        end
        BV.controlCache = BV.controlCache or {}
        p8_set_text(BV.controlCache, "count", B.browseCountText, "Active Listings: " .. tostring(#view.rows))
        local empty = #view.rows == 0
        p8_set_shown(BV.controlCache, "emptyText", B.emptyBrowseText, empty)
        p8_set_shown(BV.controlCache, "emptyIcon", B.emptyBrowseIcon, empty)
        p8_render_rows(view, page, pageSize)
        p8_render_detail(snapshot)
        p8_render_badge(snapshot)
        self.lastRenderedGeneration = snapshot.generation
        self.lastRenderedView = viewSignature
        self.lastRenderedSelection = B.selectedListing
        self.lastRenderedPage = page
        self.dirty = false
        local lazyRecord = LP.panels and LP.panels.browse
        if lazyRecord then lazyRecord.dirty = false end
        p8_note("visibleRenders", 1)
        return true
      end))
      self.rendering = false
      if started then
        local elapsed = math.max(0, p8_now_ms() - started)
        p8_note("totalRefreshMsTotal", elapsed)
        p8_max("totalRefreshMsMax", elapsed)
        local hot = _G.SignalFireHotPath151
        if hot then
          hot.stats = hot.stats or {}
          hot.stats.panels = hot.stats.panels or {}
          local panel = hot.stats.panels.browse or {calls=0, nestedSuppressed=0, totalMs=0, maxMs=0, maxRows=0}
          hot.stats.panels.browse = panel
          panel.calls = (panel.calls or 0) + 1
          panel.totalMs = (panel.totalMs or 0) + elapsed
          panel.maxMs = math.max(panel.maxMs or 0, elapsed)
          local count = 0
          for _ in pairs(B.listings or {}) do count = count + 1 end
          panel.maxRows = math.max(panel.maxRows or 0, count)
        end
      end
      if not results[1] then
        self.dirty = true
        local lazyRecord = LP.panels and LP.panels.browse
        if lazyRecord then lazyRecord.dirty = true end
        p8_record_error("refresh", results[2])
        error(results[2], 0)
      end
      return results[2]
    end

    -- The Phase 4 scheduler remains the burst owner; only its Browse execution
    -- slot changes from the historical renderer to this authoritative workflow.
    P4.original.browse = function()
      local ok, result = pcall(BV.AuthoritativeRefresh, BV)
      if not ok then
        -- The Browse owner already retained the error and dirty state. Returning
        -- lets the shared scheduler finish its flush and sleep normally.
        return false, result
      end
      return result
    end

    B.RefreshBrowse = function(self, reason)
      p8_note("refreshWrapperCalls", 1)
      local record = LP.panels and LP.panels.browse
      if not self.rows or not self.browse then
        BV.dirty = true
        if record then LP:MarkDirty("browse", reason or "RefreshBrowse") end
        p8_note("refreshWhileUnbuilt", 1)
        p8_note("refreshConvertedToDirty", 1)
        return false
      end
      if not p8_visible() then
        BV.dirty = true
        if record then LP:MarkDirty("browse", reason or "RefreshBrowse") end
        p8_note("refreshConvertedToDirty", 1)
        return false
      end
      p8_note("dirtyRequests", 1)
      if P4.dirty and P4.dirty.browse then p8_note("dirtyRequestsMerged", 1) end
      if self.SF151_RequestPanelRefresh then return self:SF151_RequestPanelRefresh("browse", reason == "show" and "show" or nil) end
      return BV:AuthoritativeRefresh()
    end

    function B:SF151_SetBrowsePage(page)
      local nextPage = math.max(1, tonumber(page or 1) or 1)
      if self.browsePage == nextPage then return false end
      self.browsePage = nextPage
      return self:RefreshBrowse("page")
    end

    function B:SF151_InvalidateBrowseData(reason, requestRefresh)
      BV:Invalidate(reason)
      if requestRefresh and self.RefreshBrowse then self:RefreshBrowse(reason) end
      return BV.dataGeneration
    end

    local function p8_wrap_mutation(methodName, beforeFn, changedFn, requestRefresh)
      local old = B[methodName]
      if type(old) ~= "function" then return end
      BV.original = BV.original or {}
      if BV.original[methodName] then return end
      BV.original[methodName] = old
      B[methodName] = function(self, ...)
        local before = beforeFn and beforeFn(self, ...) or nil
        BV:BeginMutation()
        local results = p8_pack(pcall(old, self, ...))
        local changed, reason = false, methodName
        local afterResults = {true}
        if results[1] and changedFn then
          afterResults = p8_pack(pcall(changedFn, self, before, ...))
          if afterResults[1] then changed, reason = afterResults[2], afterResults[3] end
        end
        if changed then
          BV:Invalidate(reason or methodName)
          if requestRefresh and self.RefreshBrowse then
            local refreshOK, refreshError = pcall(self.RefreshBrowse, self, reason or methodName)
            if not refreshOK then afterResults = {false, refreshError} end
          end
        end
        BV:EndMutation()
        if not results[1] then error(results[2], 0) end
        if not afterResults[1] then error(afterResults[2], 0) end
        return unpack(results, 2, results.n)
      end
    end

    local function p8_my_listing_before(self)
      return self.myListing and p8_listing_signature(self.myListing) or ""
    end

    local function p8_my_listing_changed(self, before)
      local after = self.myListing and p8_listing_signature(self.myListing) or ""
      return before ~= after, "my-listing"
    end

    p8_wrap_mutation("CreateListing", p8_my_listing_before, p8_my_listing_changed, false)
    p8_wrap_mutation("Broadcast", p8_my_listing_before, p8_my_listing_changed, true)
    p8_wrap_mutation("CancelMyListing", p8_my_listing_before, p8_my_listing_changed, false)
    p8_wrap_mutation("RestoreMyListingState", p8_my_listing_before, p8_my_listing_changed, true)

    local function p8_selected_app_count(self)
      local id = self.myListing and tostring(self.myListing.id or "") or ""
      local count = 0
      local signatures = {}
      for name, applicant in pairs(self.applicants or {}) do
        if id ~= "" and tostring(applicant and applicant.listingId or "") == id then
          count = count + 1
          table.insert(signatures, tostring(name) .. "=" .. p8_applicant_signature(applicant))
        end
      end
      table.sort(signatures)
      return tostring(count) .. "\31" .. table.concat(signatures, "\30")
    end

    local function p8_applicants_changed(self, before)
      return before ~= p8_selected_app_count(self), "applicants"
    end

    p8_wrap_mutation("Apply", p8_selected_app_count, p8_applicants_changed, true)
    p8_wrap_mutation("AcceptSelected", p8_selected_app_count, p8_applicants_changed, true)
    p8_wrap_mutation("DeclineSelected", p8_selected_app_count, p8_applicants_changed, true)

    local oldHandleMessage = B.HandleMessage
    if type(oldHandleMessage) == "function" and not BV.originalHandleMessage then
      BV.originalHandleMessage = oldHandleMessage
      B.HandleMessage = function(self, text, ...)
        local raw = tostring(text or "")
        local operation, id, name = string.match(raw, "^BLFG312~([^~]+)~([^~]*)~?([^~]*)")
        local before
        if operation == "LIST" or operation == "REMOVE" then
          before = p8_listing_signature(self.listings and self.listings[id])
        elseif operation == "APP" then
          before = p8_applicant_signature(self.applicants and self.applicants[name])
        end
        BV:BeginMutation()
        local results = p8_pack(pcall(oldHandleMessage, self, text, ...))
        local changed = false
        local afterResults = {true}
        if results[1] then
          afterResults = p8_pack(pcall(function()
            if operation == "LIST" or operation == "REMOVE" then
              changed = before ~= p8_listing_signature(self.listings and self.listings[id])
            elseif operation == "APP" then
              changed = before ~= p8_applicant_signature(self.applicants and self.applicants[name])
            end
            if changed then BV:Invalidate("protocol-" .. string.lower(operation)) end
          end))
        end
        BV:EndMutation()
        if not results[1] then error(results[2], 0) end
        if not afterResults[1] then error(afterResults[2], 0) end
        return unpack(results, 2, results.n)
      end
    end

    local oldSetProfile = B.SF143_SetServerProfile
    if type(oldSetProfile) == "function" and not BV.originalSetProfile then
      BV.originalSetProfile = oldSetProfile
      B.SF143_SetServerProfile = function(self, ...)
        local before = p8_profile()
        local results = p8_pack(pcall(oldSetProfile, self, ...))
        if not results[1] then error(results[2], 0) end
        if before ~= p8_profile() then BV:Invalidate("profile") end
        return unpack(results, 2, results.n)
      end
    end

    function B:SF151_ResetBrowseViewStats()
      BV.stats = {}
      BV.errors = {}
      return true
    end

    function B:SF151_GetBrowseViewDiagnostics()
      local result = {
        generation=BV.generation, dataGeneration=BV.dataGeneration,
        dirty=BV.dirty == true, rendering=BV.rendering == true,
        snapshotGeneration=BV.snapshot and BV.snapshot.generation or 0,
        snapshotRows=BV.snapshot and #BV.snapshot.rows or 0,
        viewCacheEntries=0, maximumViews=BV.maximumViews,
        errors=BV.errors,
      }
      for _ in pairs(BV.viewCache or {}) do result.viewCacheEntries = result.viewCacheEntries + 1 end
      local fields = {
        "generationIncrements", "snapshotRequests", "snapshotsBuilt", "snapshotCacheHits",
        "listingsProcessed", "normalizedStringsGenerated", "canonicalSorts", "viewRequests",
        "viewsBuilt", "viewCacheHits", "filterScans", "searchScans", "viewSorts",
        "pageSliceRequests", "offPageRowsFormatted", "visibleRenders", "hiddenRendersSkipped",
        "rowsConsidered", "rowsMateriallyWritten", "rowSignatureHits", "setTextCalls",
        "textureWrites", "backdropWrites", "tooltipDataBuilds", "selectionOnlyUpdates",
        "detailRequests", "detailRenders", "detailSignatureHits", "buttonStateWrites",
        "actionRewrites", "refreshWrapperCalls", "authoritativeRefreshes", "duplicateRefreshAvoided",
        "dirtyRequests", "dirtyRequestsMerged", "refreshWhileUnbuilt", "refreshConvertedToDirty",
        "expiredListings", "snapshotBuildMsTotal", "snapshotBuildMsMax", "viewBuildMsTotal",
        "viewBuildMsMax", "rowRenderMsTotal", "rowRenderMsMax", "detailRenderMsTotal",
        "detailRenderMsMax", "totalRefreshMsTotal", "totalRefreshMsMax", "viewEvictions",
      }
      for _, field in ipairs(fields) do result[field] = tonumber(BV.stats[field] or 0) or 0 end
      return result
    end

    function B:SF151_PrintBrowseViewDiagnostics()
      local d = self:SF151_GetBrowseViewDiagnostics()
      local function emit(text)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("SignalFire> " .. tostring(text)) end
      end
      emit("browse owner " .. tostring(d.generation) .. ", gen=" .. tostring(d.dataGeneration)
        .. ", dirty=" .. tostring(d.dirty) .. ", snapshotRows=" .. tostring(d.snapshotRows)
        .. ", views=" .. tostring(d.viewCacheEntries) .. "/" .. tostring(d.maximumViews))
      emit("browse data: increments=" .. tostring(d.generationIncrements) .. ", snapshot="
        .. tostring(d.snapshotRequests) .. "/" .. tostring(d.snapshotsBuilt) .. ", hits="
        .. tostring(d.snapshotCacheHits) .. ", listings=" .. tostring(d.listingsProcessed)
        .. ", normalized=" .. tostring(d.normalizedStringsGenerated) .. ", sorts=" .. tostring(d.canonicalSorts))
      emit("browse view: requests=" .. tostring(d.viewRequests) .. ", built=" .. tostring(d.viewsBuilt)
        .. ", hits=" .. tostring(d.viewCacheHits) .. ", filters=" .. tostring(d.filterScans)
        .. ", searches=" .. tostring(d.searchScans) .. ", sorts=" .. tostring(d.viewSorts)
        .. ", slices=" .. tostring(d.pageSliceRequests) .. ", offPage=" .. tostring(d.offPageRowsFormatted))
      emit("browse renderer: requests=" .. tostring(d.refreshWrapperCalls) .. ", executed="
        .. tostring(d.authoritativeRefreshes) .. ", visible=" .. tostring(d.visibleRenders)
        .. ", hidden=" .. tostring(d.hiddenRendersSkipped) .. ", rows=" .. tostring(d.rowsConsidered)
        .. ", written=" .. tostring(d.rowsMateriallyWritten) .. ", signatureHits=" .. tostring(d.rowSignatureHits)
        .. ", setText=" .. tostring(d.setTextCalls) .. ", texture=" .. tostring(d.textureWrites)
        .. ", backdrop=" .. tostring(d.backdropWrites))
      local snapshotAverage = d.snapshotsBuilt > 0 and d.snapshotBuildMsTotal / d.snapshotsBuilt or 0
      local viewAverage = d.viewsBuilt > 0 and d.viewBuildMsTotal / d.viewsBuilt or 0
      local rowAverage = d.visibleRenders > 0 and d.rowRenderMsTotal / d.visibleRenders or 0
      local detailAverage = d.detailRenders > 0 and d.detailRenderMsTotal / d.detailRenders or 0
      local totalAverage = d.visibleRenders > 0 and d.totalRefreshMsTotal / d.visibleRenders or 0
      emit("browse timing: snapshot=" .. string.format("%.3f/%.3fms", snapshotAverage, d.snapshotBuildMsMax)
        .. ", view=" .. string.format("%.3f/%.3fms", viewAverage, d.viewBuildMsMax)
        .. ", rows=" .. string.format("%.3f/%.3fms", rowAverage, d.rowRenderMsMax)
        .. ", detail=" .. string.format("%.3f/%.3fms", detailAverage, d.detailRenderMsMax)
        .. ", total=" .. string.format("%.3f/%.3fms", totalAverage, d.totalRefreshMsMax))
      return d
    end
  end
end
-- SIGNALFIRE_PHASE8_BROWSE_VIEW_END
