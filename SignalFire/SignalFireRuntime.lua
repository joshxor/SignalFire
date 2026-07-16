-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Startup guard
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SF135N_VERSION = _G.SignalFire_VERSION or "1.4.23"

    local function sf135n_print(msg)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(msg or "")) end
    end

    local function sf135n_err_text(err)
      err = tostring(err or "unknown error")
      if string.len(err) > 220 then err = string.sub(err, 1, 217) .. "..." end
      return err
    end

    local function sf135n_call(self, label, fn, ...)
      if not fn then return false end
      local ok, result = pcall(fn, self, ...)
      if not ok then
        self.sf135nLastError = tostring(label or "step") .. ": " .. tostring(result or "unknown error")
        self.sf135nErrors = self.sf135nErrors or {}
        table.insert(self.sf135nErrors, self.sf135nLastError)
        return false, result
      end
      return true, result
    end

    local function sf135n_rebuild_panel(self, label, field, buildFn, requiredField)
      if not self or not self.content or not buildFn then return end
      if self[field] and ((not requiredField) or self[requiredField]) then return end
      sf135n_call(self, label, buildFn)
    end

    function BLFG:SF135N_EnsureCoreUI()
      if not self.frame or not self.content then return false end

      -- If startup stopped midway, rebuild only the pieces that are missing.  This keeps
      -- the addon usable even if a non-critical enhancement panel fails.
      sf135n_rebuild_panel(self, "BuildSide", "side", self.BuildSide)
      sf135n_rebuild_panel(self, "BuildBrowse", "browse", self.BuildBrowse)
      sf135n_rebuild_panel(self, "BuildCreate", "create", self.BuildCreate, "typeDrop")
      sf135n_rebuild_panel(self, "BuildProfile", "profile", self.BuildProfile, "profileRole")
      sf135n_rebuild_panel(self, "BuildApplicants", "apps", self.BuildApplicants, "appRows")
      sf135n_rebuild_panel(self, "BuildPublicGroups", "publicPanel", self.BuildPublicGroups, "publicRows")
      sf135n_rebuild_panel(self, "BuildOnlinePanel", "onlinePanel", self.BuildOnlinePanel)
      sf135n_rebuild_panel(self, "BuildGuildBrowser", "guildPanel", self.BuildGuildBrowser)
      sf135n_rebuild_panel(self, "BuildOptions", "optionsPanel", self.BuildOptions)
      sf135n_rebuild_panel(self, "BuildMyListing", "myPanel", self.BuildMyListing)
      if self.BuildSFNetworkPanel and (not self.sfnPanel) then sf135n_call(self, "BuildSFNetworkPanel", self.BuildSFNetworkPanel) end
      if self.BuildInvasions and (not self.invasionPanel) then sf135n_call(self, "BuildInvasions", self.BuildInvasions) end
      if self.BuildMinimap and (not self.mm) then sf135n_call(self, "BuildMinimap", self.BuildMinimap) end
      if self.mm and self.UpdateMinimap then sf135n_call(self, "UpdateMinimap", self.UpdateMinimap) end
      if self.ApplySignalFireBetaTitle then sf135n_call(self, "ApplySignalFireBetaTitle", self.ApplySignalFireBetaTitle) end
      return true
    end

    local SF135N_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local ok, result = true, nil
      if SF135N_OldCreateUI then ok, result = sf135n_call(self, "CreateUI", SF135N_OldCreateUI, ...) end
      self:SF135N_EnsureCoreUI()
      if (not ok) and not self.sf135nWarned then
        self.sf135nWarned = true
        sf135n_print("Recovered from a startup panel error. Last error: " .. sf135n_err_text(result))
      end
      return result
    end

    local function sf135n_show_panel(self, field, buildFn, refreshFn, tabName)
      self:CreateUI()
      self:SF135N_EnsureCoreUI()
      if buildFn and not self[field] then sf135n_call(self, tostring(buildFn), buildFn) end
      if not self[field] then
        sf135n_print("Could not open " .. tostring(tabName or field) .. ". A panel failed to build" .. (self.sf135nLastError and (": " .. sf135n_err_text(self.sf135nLastError)) or "."))
        return
      end
      if self.HidePanels then sf135n_call(self, "HidePanels", self.HidePanels) end
      self[field]:Show()
      if self.frame then self.frame:Show() end
      self.currentTab = tabName or field
      if refreshFn then sf135n_call(self, tostring(tabName or field) .. " refresh", refreshFn) end
    end

    function BLFG:Show()
      self:CreateUI()
      self:SF135N_EnsureCoreUI()
      if self.frame then self.frame:Show() end
      if self.browse then
        if self.HidePanels then sf135n_call(self, "HidePanels", self.HidePanels) end
        self.browse:Show()
        if self.RefreshBrowse then sf135n_call(self, "RefreshBrowse", self.RefreshBrowse) end
      end
    end

    function BLFG:Toggle()
      self:CreateUI()
      self:SF135N_EnsureCoreUI()
      if not self.frame then return end
      if self.frame:IsShown() then self.frame:Hide() else self:Show() end
    end


    function BLFG:ShowBrowse()
      sf135n_show_panel(self, "browse", self.BuildBrowse, self.RefreshBrowse, "Browse")
    end

    function BLFG:ShowPublicGroups()
      sf135n_show_panel(self, "publicPanel", self.BuildPublicGroups, self.RefreshPublicGroups, "Public Groups")
    end

    function BLFG:ShowCreate()
      sf135n_show_panel(self, "create", self.BuildCreate, self.UpdateCreateControls, "Create Listing")
      if self.SFAM_BuildCreatePreview then sf135n_call(self, "SFAM_BuildCreatePreview", self.SFAM_BuildCreatePreview) end
      if self.SFAM_UpdateCreatePreview then sf135n_call(self, "SFAM_UpdateCreatePreview", self.SFAM_UpdateCreatePreview) end
    end

    function BLFG:ShowProfile()
      sf135n_show_panel(self, "profile", self.BuildProfile, self.UpdateWhisperPreview569, "Profile")
    end

    function BLFG:ShowApplicants()
      sf135n_show_panel(self, "apps", self.BuildApplicants, self.RefreshApplicants, "Applicants")
      if self.RefreshApplicantDetail then sf135n_call(self, "RefreshApplicantDetail", self.RefreshApplicantDetail) end
    end

    function BLFG:ShowOptions()
      sf135n_show_panel(self, "optionsPanel", self.BuildOptions, nil, "Options")
      if self.SFAM_AddPolishOptions then sf135n_call(self, "SFAM_AddPolishOptions", self.SFAM_AddPolishOptions) end
    end

    function BLFG:ShowMyListing()
      sf135n_show_panel(self, "myPanel", self.BuildMyListing, self.RefreshMyListing, "My Listing")
    end

    function BLFG:ShowGuildBrowser()
      sf135n_show_panel(self, "guildPanel", self.BuildGuildBrowser, self.RefreshGuildBrowser, "Guild Browser")
    end

    function BLFG:ShowSFNetwork()
      self:CreateUI()
      self:SF135N_EnsureCoreUI()
      if not self.sfnPanel and self.BuildSFNetworkPanel then sf135n_call(self, "BuildSFNetworkPanel", self.BuildSFNetworkPanel) end
      if not self.sfnPanel then
        sf135n_print("Could not open Network. A panel failed to build" .. (self.sf135nLastError and (": " .. sf135n_err_text(self.sf135nLastError)) or "."))
        return
      end
      if self.HidePanels then sf135n_call(self, "HidePanels", self.HidePanels) end
      self.sfnPanel:Show()
      if self.frame then self.frame:Show() end
      self.currentTab = "Network"
      if self.SFN_SendStatus then sf135n_call(self, "SFN_SendStatus", self.SFN_SendStatus) end
      if self.RefreshSFNetwork then sf135n_call(self, "RefreshSFNetwork", self.RefreshSFNetwork) end
    end

    function BLFG:ShowInvasions()
      self:CreateUI()
      self:SF135N_EnsureCoreUI()
      if not self.invasionPanel and self.BuildInvasions then sf135n_call(self, "BuildInvasions", self.BuildInvasions) end
      if not self.invasionPanel then
        sf135n_print("Could not open Invasions. A panel failed to build" .. (self.sf135nLastError and (": " .. sf135n_err_text(self.sf135nLastError)) or "."))
        return
      end
      if self.HidePanels then sf135n_call(self, "HidePanels", self.HidePanels) end
      self.invasionPanel:Show()
      if self.frame then self.frame:Show() end
      self.currentTab = "Invasions"
      if self.SendInvasionPresence then sf135n_call(self, "SendInvasionPresence", self.SendInvasionPresence) end
      if self.RefreshInvasions then sf135n_call(self, "RefreshInvasions", self.RefreshInvasions) end
    end

    -- Optional diagnostic command.  It chains into the active /sf handler without taking it over.
    local SF135N_OldSlash = SlashCmdList and SlashCmdList["SIGNALFIRE"]
    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(msg)
        local cmd = string.lower(tostring(msg or "")):gsub("^%s+", ""):gsub("%s+$", "")
        if cmd == "repair" or cmd == "init" then
          BLFG:CreateUI()
          BLFG:SF135N_EnsureCoreUI()
          sf135n_print("Repair pass complete. Minimap=" .. tostring(BLFG.mm and "ready" or "missing") .. ", PublicGroups=" .. tostring(BLFG.publicPanel and "ready" or "missing"))
          return
        elseif cmd == "minimap" then
          BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}; BronzeLFG_DB.options.showMinimap = true
          BLFG:CreateUI(); if BLFG.BuildMinimap and not BLFG.mm then sf135n_call(BLFG, "BuildMinimap", BLFG.BuildMinimap) end; if BLFG.UpdateMinimap then sf135n_call(BLFG, "UpdateMinimap", BLFG.UpdateMinimap) end
          sf135n_print("Minimap icon enabled/refreshed.")
          return
        elseif cmd == "network" or cmd == "net" or cmd == "notice" or cmd == "notices" or cmd == "announcements" then
          BLFG:ShowSFNetwork()
          return
        elseif cmd == "browse" then
          BLFG:ShowBrowse()
          return
        elseif cmd == "public" or cmd == "groups" or cmd == "publicgroups" then
          BLFG:ShowPublicGroups()
          return
        elseif cmd == "create" or cmd == "listing" then
          BLFG:ShowCreate()
          return
        elseif cmd == "profile" then
          BLFG:ShowProfile()
          return
        elseif cmd == "applicants" or cmd == "apps" then
          BLFG:ShowApplicants()
          return
        elseif cmd == "guild" or cmd == "guildbrowser" then
          BLFG:ShowGuildBrowser()
          return
        elseif cmd == "invasions" or cmd == "invasion" then
          BLFG:ShowInvasions()
          return
        elseif cmd == "mine" or cmd == "my" or cmd == "mylisting" then
          BLFG:ShowMyListing()
          return
        elseif cmd == "options" or cmd == "settings" then
          BLFG:ShowOptions()
          return
        end
        if SF135N_OldSlash then return SF135N_OldSlash(msg) end
      end
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
      if BLFG and BLFG.CreateUI then
        -- Do not force the window open; just ensure the launcher can be created if the DB allows it.
        BLFG:CreateUI()
        if BLFG.UpdateMinimap then sf135n_call(BLFG, "UpdateMinimap", BLFG.UpdateMinimap) end
      end
    end)
  until true
end

-- Server profiles
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local PROFILE_CHOICES = {"Triumvirate", "Ascension"}

    local function sf143_lower(s)
      return string.lower(tostring(s or ""))
    end

    local function sf143_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0) end
    end

    local function sf143_copy(src)
      local out = {}
      for i, v in ipairs(src or {}) do out[i] = v end
      return out
    end

    local function sf143_contains(list, value)
      if not list or value == nil then return false end
      for _, v in ipairs(list) do if v == value then return true end end
      return false
    end

    local function sf143_detect_profile()
      local realm = ""
      if GetRealmName then realm = sf143_lower(GetRealmName() or "") end
      if string.find(realm, "triumvirate", 1, true) then return "Triumvirate" end
      if string.find(realm, "bronzebeard", 1, true) then return "Ascension" end
      if string.find(realm, "conquest", 1, true) then return "Ascension" end
      if string.find(realm, "azeroth", 1, true) then return "Ascension" end
      if string.find(realm, "ascension", 1, true) then return "Ascension" end
      if string.find(realm, "vol'jin", 1, true) or string.find(realm, "voljin", 1, true) then return "Ascension" end
      return "Triumvirate"
    end

    local function sf143_profile_id()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local id = tostring(BronzeLFG_DB.options.serverProfile or "")
      if id == "" then id = sf143_detect_profile() end
      if id ~= "Triumvirate" and id ~= "Ascension" then id = sf143_detect_profile() end
      return id
    end

    local function sf143_profile()
      local id = sf143_profile_id()
      if SignalFireProfiles and SignalFireProfiles[id] then return SignalFireProfiles[id] end
      if SignalFireProfiles and SignalFireProfiles.Triumvirate then return SignalFireProfiles.Triumvirate end
      return nil
    end

    local function sf143_dropdown_text(d)
      if BLFG_DropdownText then return BLFG_DropdownText(d) end
      if UIDropDownMenu_GetText then return UIDropDownMenu_GetText(d) or "" end
      return ""
    end

    local function sf143_reset_dropdown(d, values, selected, onchange)
      if not d then return nil end
      values = values or {}
      if not sf143_contains(values, selected) then selected = values[1] end
      selected = selected or ""
      d.values = values
      if UIDropDownMenu_SetText then UIDropDownMenu_SetText(d, selected) end
      if UIDropDownMenu_Initialize then
        UIDropDownMenu_Initialize(d, function()
          for _, v in ipairs(d.values or values) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = v
            info.notCheckable = true
            info.func = function()
              if UIDropDownMenu_SetText then UIDropDownMenu_SetText(d, v) end
              if onchange then onchange(v) end
            end
            UIDropDownMenu_AddButton(info)
          end
        end)
      end
      if BLFG_FixDropdownButton then BLFG_FixDropdownButton(d) end
      return selected
    end


    local function sf143_apply_profile_defaults(id)
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      id = tostring(id or sf143_profile_id() or "Triumvirate")
      if id == "Ascension" then
        BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
        BronzeLFG_DB.options.modulesByProfile.Ascension.invasions = false
      end
    end

    local function sf143_list_with_any(label, src)
      local out = {label}
      for _, v in ipairs(src or {}) do table.insert(out, v) end
      return out
    end

    function BLFG:SF143_GetProfile()
      return sf143_profile()
    end

    function BLFG:SF143_GetProfileId()
      local p = sf143_profile()
      return (p and p.id) or sf143_profile_id()
    end

    function BLFG:SF143_ListForType(typeName)
      local p = sf143_profile()
      if typeName == "Dungeon" then
        if p and p.dungeonActivityModes and #p.dungeonActivityModes > 0 then return sf143_copy(p.dungeonActivityModes) end
        if p and p.useDungeonModes == false then return sf143_copy(p.dungeons or {}) end
        local out = {}
        if p and p.features and p.features.rdf then
          table.insert(out, "Random Dungeon Finder")
          table.insert(out, "Random Heroic Dungeon Finder")
          if p.tbcDungeons and #p.tbcDungeons > 0 then table.insert(out, "BC Random Dungeon Finder") end
          if p.wrathDungeons and #p.wrathDungeons > 0 then table.insert(out, "Wrath Random Dungeon Finder") end
        end
        if p and p.classicDungeons and #p.classicDungeons > 0 then table.insert(out, "Classic Dungeon") end
        if p and p.tbcDungeons and #p.tbcDungeons > 0 then table.insert(out, "TBC Dungeon") end
        if p and p.wrathDungeons and #p.wrathDungeons > 0 then table.insert(out, "Wrath Dungeon") end
        if #out == 0 and p and p.dungeons then out = sf143_copy(p.dungeons) end
        return out
      end
      if typeName == "Mythic+" and p and p.id == "Ascension" then return {"Mythic+ Pool"} end
      if typeName == "Raid" then return sf143_copy((p and p.raids) or {}) end
      if typeName == "World Boss" then return sf143_copy((p and p.worldBosses) or {"Custom World Boss"}) end
      return {"Custom Activity"}
    end

    -- Replace the old global helpers with profile-aware versions.  These helpers are
    -- used by the existing Create Listing flow and by the keystone autofill button.
    function BLFG_ActivitySupportsKeyLevel(activity)
      local p = sf143_profile()
      if not activity or not p then return false end
      if p.id == "Ascension" and activity == "Mythic+ Pool" then return true end
      if p.dungeonModeLists and p.dungeonModeLists[activity] then
        return p.features and (p.features.seasonOneKeys or p.features.mythicPlus) and true or false
      end
      if p.useDungeonModes == false then
        return p.features and p.features.mythicPlus and p.dungeonActivities and p.dungeonActivities[activity] and true or false
      end
      if activity == "Classic Dungeon" or activity == "TBC Dungeon" or activity == "Wrath Dungeon" then
        return p.features and (p.features.seasonOneKeys or p.features.mythicPlus) and true or false
      end
      return p.dungeonActivities and p.dungeonActivities[activity] and true or false
    end

    function BLFG_DungeonListForMode(activity)
      local p = sf143_profile()
      if not p then return nil end
      if p.id == "Ascension" and activity == "Mythic+ Pool" then return p.keys or p.dungeons end
      if p.dungeonModeLists and p.dungeonModeLists[activity] then return p.dungeonModeLists[activity] end
      if p.useDungeonModes == false then return nil end
      if activity == "Classic Dungeon" then return p.classicDungeons or p.dungeons end
      if activity == "TBC Dungeon" then return p.tbcDungeons or p.dungeons end
      if activity == "Wrath Dungeon" then return p.wrathDungeons or p.dungeons end
      return nil
    end

    function BLFG_DungeonModeForActivity(activity)
      local p = sf143_profile()
      if not p then return nil end
      local function has(list)
        for _, v in ipairs(list or {}) do if v == activity then return true end end
        return false
      end
      if p.dungeonActivityModes and p.dungeonModeLists then
        for _, mode in ipairs(p.dungeonActivityModes) do
          if has(p.dungeonModeLists[mode]) then return mode end
        end
      end
      if p.useDungeonModes == false then return nil end
      if has(p.classicDungeons) then return "Classic Dungeon" end
      if has(p.tbcDungeons) then return "TBC Dungeon" end
      if has(p.wrathDungeons) then return "Wrath Dungeon" end
      return nil
    end

    function BLFG_DifficultyListForType(typeName)
      local p = sf143_profile()
      if p and p.id == "Ascension" and typeName == "Mythic+" then return {"Mythic+"} end
      if typeName == "Raid" then return (p and p.raidDifficulties) or {"Normal", "Heroic"} end
      if typeName == "Dungeon" then
        if p and p.id == "Ascension" then return (p and p.basicDungeonDifficulties) or {"Normal", "Heroic"} end
        return (p and p.dungeonDifficulties) or {"Normal", "Heroic", "Mythic+"}
      end
      return (p and p.difficulties) or {"Normal", "Heroic", "Mythic", "Mythic+", "Custom"}
    end

    function BLFG_CreateDifficultyListFor(typeName, activity)
      local p = sf143_profile()
      if p and p.id == "Ascension" and typeName == "Mythic+" then return {"Mythic+"} end
      if typeName == "Raid" then return (p and p.raidDifficulties) or {"Normal", "Heroic"} end
      if typeName == "Dungeon" then
        if p and p.id == "Ascension" then return (p and p.basicDungeonDifficulties) or {"Normal", "Heroic"} end
        if BLFG_ActivitySupportsKeyLevel(activity) then return (p and p.dungeonDifficulties) or {"Normal", "Heroic", "Mythic+"} end
        return (p and p.basicDungeonDifficulties) or {"Normal", "Heroic"}
      end
      return (p and p.difficulties) or {"Normal", "Heroic", "Mythic", "Mythic+", "Custom"}
    end

    function BLFG:SF143_EnsureDetectedProfile()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local opts = BronzeLFG_DB.options
      if opts.serverProfileManual == true then sf143_apply_profile_defaults(opts.serverProfile); return end
      local detected = sf143_detect_profile()
      if not opts.serverProfile or opts.serverProfile == "" or opts.serverProfile == "Triumvirate" then
        opts.serverProfile = detected
      end
      sf143_apply_profile_defaults(opts.serverProfile)
    end

    local function sf143_apply_profile_alert_aliases(p)
      if not p or not _G.BLFG_5611_DUNGEON_ALIASES then return end
      if p.dungeonModeLists then
        for mode, list in pairs(p.dungeonModeLists) do
          _G.BLFG_5611_DUNGEON_ALIASES[mode] = list
        end
      end
      if p.dungeonAlertAliases then
        for name, list in pairs(p.dungeonAlertAliases) do
          _G.BLFG_5611_DUNGEON_ALIASES[name] = list
        end
      end
    end

    function BLFG:SF143_UpdateServerBrand()
      local id = self.SF143_GetProfileId and self:SF143_GetProfileId() or sf143_profile_id()
      local label = (id == "Ascension") and "Ascension" or "Triumvirate"
      if self.sideBrand and self.sideBrand.SetText then self.sideBrand:SetText(label) end
      if BronzeLFG_ApplyVisibleVersion then BronzeLFG_ApplyVisibleVersion() end
    end

    function BLFG:SF143_SetServerProfile(id, manual)
      if id ~= "Triumvirate" and id ~= "Ascension" then id = sf143_detect_profile() end
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.serverProfile = id
      sf143_apply_profile_defaults(id)
      if manual ~= false then BronzeLFG_DB.options.serverProfileManual = true end

      -- Reset stale alert filters that do not exist in the new profile.
      local p = sf143_profile()
      if p then
        sf143_apply_profile_alert_aliases(p)
        if not sf143_contains(p.keyAlertOptions or {}, BronzeLFG_DB.options.notifyKeyFilter) then BronzeLFG_DB.options.notifyKeyFilter = (p.keyAlertOptions and p.keyAlertOptions[1]) or "Any Key" end
        if not sf143_contains(p.raidAlertOptions or {}, BronzeLFG_DB.options.notifyRaidFilter) then BronzeLFG_DB.options.notifyRaidFilter = (p.raidAlertOptions and p.raidAlertOptions[1]) or "Any Raid" end
        if p.dungeonAlertOptions and not sf143_contains(p.dungeonAlertOptions or {}, BronzeLFG_DB.options.notifyDungeonFilter) then BronzeLFG_DB.options.notifyDungeonFilter = p.dungeonAlertOptions[1] or "Any Dungeon" end
      end

      if self.SF143_UpdateServerBrand then self:SF143_UpdateServerBrand() end
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      if self.SF143_ApplyProfileToOptions then self:SF143_ApplyProfileToOptions() end
      if self.RefreshPublicGroups then self:RefreshPublicGroups() end
      if self.RefreshBrowse then self:RefreshBrowse() end
      sf143_msg("Server profile set to " .. tostring(id) .. ".")
    end

    function BLFG:SF143_ApplyProfileToCreate()
      if not self.typeDrop or not self.activityDrop then return end
      local p = sf143_profile()
      if not p then return end

      local typeName = sf143_reset_dropdown(self.typeDrop, p.activityTypes or {"Dungeon", "Raid", "World Boss", "Custom Event"}, sf143_dropdown_text(self.typeDrop), function(v)
        local vals = BLFG:SF143_ListForType(v)
        sf143_reset_dropdown(BLFG.activityDrop, vals, vals[1], function() if BLFG.SF143_ApplyProfileToCreate then BLFG:SF143_ApplyProfileToCreate() end end)
        if BLFG.SF143_ApplyProfileToCreate then BLFG:SF143_ApplyProfileToCreate() end
      end)

      local activityValues = self:SF143_ListForType(typeName)
      local activity = sf143_reset_dropdown(self.activityDrop, activityValues, sf143_dropdown_text(self.activityDrop), function()
        if BLFG.SF143_ApplyProfileToCreate then BLFG:SF143_ApplyProfileToCreate() end
      end)

      local diffs = BLFG_CreateDifficultyListFor(typeName, activity)
      local diff = sf143_reset_dropdown(self.diffDrop, diffs, sf143_dropdown_text(self.diffDrop), function()
        if BLFG.SF143_ApplyProfileToCreate then BLFG:SF143_ApplyProfileToCreate() end
      end)

      local dungeonList = BLFG_DungeonListForMode(activity)
      if self.specificDungeonLabel and self.specificDungeonDrop then
        if dungeonList and #dungeonList > 0 then
          self.specificDungeonLabel:Show()
          self.specificDungeonDrop:Show()
          sf143_reset_dropdown(self.specificDungeonDrop, dungeonList, sf143_dropdown_text(self.specificDungeonDrop), nil)
        else
          self.specificDungeonLabel:Hide()
          self.specificDungeonDrop:Hide()
        end
      end

      local keyAllowed = ((typeName == "Dungeon" or typeName == "Mythic+") and diff == "Mythic+" and BLFG_ActivitySupportsKeyLevel(activity))
      if self.keyLabel then if keyAllowed then self.keyLabel:Show() else self.keyLabel:Hide() end end
      if self.keyBox then
        if keyAllowed then
          self.keyBox:Show(); self.keyBox:EnableMouse(true); self.keyBox:SetTextColor(1, 1, 1)
        else
          self.keyBox:SetText(""); self.keyBox:EnableMouse(false); self.keyBox:SetTextColor(.45, .45, .45); self.keyBox:Hide()
        end
      end
      if self.useKeystoneButton then
        if keyAllowed then self.useKeystoneButton:Show(); self.useKeystoneButton:Enable() else self.useKeystoneButton:Disable(); self.useKeystoneButton:Hide() end
      end
      if self.maxBox and BLFG_DefaultMaxMembersFor then self.maxBox:SetText(tostring(BLFG_DefaultMaxMembersFor(typeName, activity, diff))) end
      if BLFG_SF135J_FixVisibleDropdowns then BLFG_SF135J_FixVisibleDropdowns() end
    end

    function BLFG:SF143_ApplyProfileToOptions()
      sf143_apply_profile_defaults(sf143_profile_id())
      local p = sf143_profile()
      if not p then return end
      if self.serverProfileDD then
        sf143_reset_dropdown(self.serverProfileDD, PROFILE_CHOICES, self:SF143_GetProfileId(), function(v)
          BLFG:SF143_SetServerProfile(v, true)
        end)
      end
      if self.keyFilterDD then
        local selected = BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.notifyKeyFilter or nil
        selected = sf143_reset_dropdown(self.keyFilterDD, p.keyAlertOptions or {"Any Key"}, selected, function(v)
          BronzeLFG_DB.options.notifyKeyFilter = v
          if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
        end)
        BronzeLFG_DB.options.notifyKeyFilter = selected
      end
      if self.raidFilterDD then
        local selected = BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.notifyRaidFilter or nil
        selected = sf143_reset_dropdown(self.raidFilterDD, p.raidAlertOptions or sf143_list_with_any("Any Raid", p.raids), selected, function(v)
          BronzeLFG_DB.options.notifyRaidFilter = v
          if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
        end)
        BronzeLFG_DB.options.notifyRaidFilter = selected
      end

      sf143_apply_profile_alert_aliases(p)
      if self.SF143_UpdateServerBrand then self:SF143_UpdateServerBrand() end

      local dungeonOptions = p.dungeonAlertOptions or sf143_list_with_any("Any Dungeon", p.dungeons)
      local dds = {self.dungeonFilterDD, self.dungeonFilterDD5612, self.dungeonAlertDropdown5613, self.dungeonAlertDropdown5614, self.dungeonAlertDropdown5615}
      for _, d in ipairs(dds) do
        if d then
          local selected = BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.notifyDungeonFilter or nil
          selected = sf143_reset_dropdown(d, dungeonOptions, selected or "Any Dungeon", function(v)
            BronzeLFG_DB.options.notifyDungeonFilter = v
            if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
          end)
          BronzeLFG_DB.options.notifyDungeonFilter = selected
        end
      end
      if self.optionsStatus then self.optionsStatus:SetText("Active server profile: " .. tostring(p.label or p.id or self:SF143_GetProfileId())) end
      if BLFG_SF135J_FixVisibleDropdowns then BLFG_SF135J_FixVisibleDropdowns() end
    end

    local SF143_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      if self.SF143_EnsureDetectedProfile then self:SF143_EnsureDetectedProfile() end
      local r = SF143_OldCreateUI and SF143_OldCreateUI(self, ...)
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      if self.SF143_ApplyProfileToOptions then self:SF143_ApplyProfileToOptions() end
      if self.SF143_UpdateServerBrand then self:SF143_UpdateServerBrand() end
      return r
    end

    local SF143_OldShowCreate = BLFG.ShowCreate
    function BLFG:ShowCreate(...)
      local r = SF143_OldShowCreate and SF143_OldShowCreate(self, ...)
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      return r
    end

    local SF143_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SF143_OldShowOptions and SF143_OldShowOptions(self, ...)
      if self.SF143_ApplyProfileToOptions then self:SF143_ApplyProfileToOptions() end
      return r
    end

    local SF143_OldUpdateCreateControls = BLFG.UpdateCreateControls
    function BLFG:UpdateCreateControls(...)
      local r = SF143_OldUpdateCreateControls and SF143_OldUpdateCreateControls(self, ...)
      if not self.SF143ApplyingUpdate and self.SF143_ApplyProfileToCreate then
        self.SF143ApplyingUpdate = true
        self:SF143_ApplyProfileToCreate()
        self.SF143ApplyingUpdate = false
      end
      return r
    end

    local SF143_OldSaveOptions = BLFG.SaveOptions
    function BLFG:SaveOptions(showFlash)
      local before = BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile
      local r = SF143_OldSaveOptions and SF143_OldSaveOptions(self, showFlash)
      BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local after = self.serverProfileDD and sf143_dropdown_text(self.serverProfileDD) or BronzeLFG_DB.options.serverProfile or before
      if after ~= before then BronzeLFG_DB.options.serverProfileManual = true end
      BronzeLFG_DB.options.serverProfile = after
      sf143_apply_profile_defaults(after)
      if self.SF143_ApplyProfileToOptions then self:SF143_ApplyProfileToOptions() end
      if self.SF143_ApplyProfileToCreate then self:SF143_ApplyProfileToCreate() end
      return r
    end

    local SF143_OldSlash = SlashCmdList and (SlashCmdList["SIGNALFIRE"] or SlashCmdList["BRONZELFG"])
    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(msg)
        local cmd = sf143_lower(msg)
        cmd = string.gsub(cmd, "^%s+", "")
        cmd = string.gsub(cmd, "%s+$", "")
        if cmd == "profile ascension" or cmd == "ascension" or cmd == "coa" or cmd == "bronzebeard" then
          BLFG:SF143_SetServerProfile("Ascension", true)
          return
        elseif cmd == "profile triumvirate" or cmd == "triumvirate" then
          BLFG:SF143_SetServerProfile("Triumvirate", true)
          return
        elseif cmd == "profile" or cmd == "server" then
          sf143_msg("Active server profile: " .. tostring(BLFG:SF143_GetProfileId()) .. ". Use /sf ascension or /sf triumvirate to switch.")
          return
        end
        if SF143_OldSlash then return SF143_OldSlash(msg) end
      end
      SlashCmdList["BRONZELFG"] = SlashCmdList["SIGNALFIRE"]
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
      if BLFG and BLFG.SF143_EnsureDetectedProfile then BLFG:SF143_EnsureDetectedProfile() end
      if BLFG and BLFG.SF143_UpdateServerBrand then BLFG:SF143_UpdateServerBrand() end
    end)
  until true
end

-- Feature modules
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireModules = SignalFireModules or {}

    local MODULES = {
      { key = "invasions", label = "Invasions", desc = "Triumvirate invasion grouping tools", icon = "INV_Misc_Head_Dragon_01" },
    }

    local function sfm_lower(s)
      return string.lower(tostring(s or ""))
    end

    local function sfm_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfm_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0) end
    end

    local function sfm_backdrop(f, alpha)
      if not f or not f.SetBackdrop then return end
      f:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=14,
        insets={left=4,right=4,top=4,bottom=4}
      })
      f:SetBackdropColor(0,0,0,alpha or .96)
      f:SetBackdropBorderColor(.85,.62,.12,.95)
    end

    local function sfm_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "")
      fs:SetTextColor(r or 1, g or .82, b or 0)
      fs:SetText(text or "")
      return fs
    end

    local function sfm_profile()
      if BLFG.SF143_GetProfile then return BLFG:SF143_GetProfile() end
      if SignalFireProfiles and SignalFireProfiles.GetActiveProfile then return SignalFireProfiles.GetActiveProfile() end
      return nil
    end

    local function sfm_profile_id()
      if BLFG.SF143_GetProfileId then return BLFG:SF143_GetProfileId() end
      local p = sfm_profile()
      return (p and p.id) or "Triumvirate"
    end

    local function sfm_ensure_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {} -- legacy/global, kept for old SavedVariables
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      return BronzeLFG_DB.options.modules
    end

    local function sfm_profile_modules()
      sfm_ensure_db()
      local id = tostring(sfm_profile_id() or "Triumvirate")
      BronzeLFG_DB.options.modulesByProfile[id] = BronzeLFG_DB.options.modulesByProfile[id] or {}
      return BronzeLFG_DB.options.modulesByProfile[id], id
    end

    local function sfm_apply_hard_profile_defaults()
      sfm_ensure_db()
      local id = tostring(sfm_profile_id() or "Triumvirate")
      if id == "Ascension" then
        BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
        BronzeLFG_DB.options.modulesByProfile.Ascension.invasions = false
      end
    end

    -- Profile defaults live here so old saved variables do not need migration.
    -- Nil in SavedVariables means "follow the active server profile".
    local function sfm_patch_profile_defaults()
      if not SignalFireProfiles then return end
      if SignalFireProfiles.Triumvirate then
        SignalFireProfiles.Triumvirate.modules = SignalFireProfiles.Triumvirate.modules or {}
        SignalFireProfiles.Triumvirate.modules.invasions = true
        SignalFireProfiles.Triumvirate.features = SignalFireProfiles.Triumvirate.features or {}
        SignalFireProfiles.Triumvirate.features.invasions = true
      end
      if SignalFireProfiles.Ascension then
        SignalFireProfiles.Ascension.modules = SignalFireProfiles.Ascension.modules or {}
        SignalFireProfiles.Ascension.modules.invasions = false
        SignalFireProfiles.Ascension.features = SignalFireProfiles.Ascension.features or {}
        SignalFireProfiles.Ascension.features.invasions = false
      end
    end
    sfm_patch_profile_defaults()

    function BLFG:SFModuleDefaultEnabled(key)
      sfm_patch_profile_defaults()
      local p = sfm_profile()
      if p and p.modules and p.modules[key] ~= nil then return p.modules[key] == true end
      if p and p.features and p.features[key] ~= nil then return p.features[key] == true end
      return true
    end

    function BLFG:SFModuleIsEnabled(key)
      sfm_apply_hard_profile_defaults()
      local byProfile, id = sfm_profile_modules()
      if key == "invasions" and id == "Ascension" then return false end
      if byProfile[key] ~= nil then return byProfile[key] == true end

      -- Honor legacy/global module settings only outside Ascension, so old
      -- Triumvirate settings cannot leak into Ascension/CoA.
      local mods = sfm_ensure_db()
      if id ~= "Ascension" and mods[key] ~= nil then return mods[key] == true end
      return self:SFModuleDefaultEnabled(key)
    end

    function BLFG:SFModuleSetEnabled(key, enabled)
      local byProfile, id = sfm_profile_modules()
      if key == "invasions" and id == "Ascension" then
        byProfile[key] = false
      else
        byProfile[key] = enabled == true
      end
      self:SFModulesApply()
    end

    function BLFG:SFModuleUseProfileDefault(key)
      local byProfile = sfm_profile_modules()
      byProfile[key] = nil
      self:SFModulesApply()
    end

    function BLFG:SFModulesStatusLine()
      local bits = {}
      for _, m in ipairs(MODULES) do
        local state = self:SFModuleIsEnabled(m.key) and "on" or "off"
        local def = self:SFModuleDefaultEnabled(m.key) and "default on" or "default off"
        table.insert(bits, m.label .. "=" .. state .. " (" .. def .. ")")
      end
      return table.concat(bits, ", ")
    end

    function BLFG:SFModulesBuildSideItems()
      local items = {
        {"Browse", "Find a group", "INV_Misc_Spyglass_02", function() BLFG:ShowBrowse() end},
        {"Create Listing", "Make your own group", "INV_Misc_Note_01", function() BLFG:ShowCreate() end},
        {"Profile", "Your apply info", "INV_Misc_GroupLooking", function() BLFG:ShowProfile() end},
        {"Applicants", "Review applicants", "INV_Misc_GroupNeedMore", function() BLFG:ShowApplicants() end},
        {"Public Groups", "From chat channels", "INV_Misc_Map_01", function() BLFG:ShowPublicGroups() end},
        {"Guild Browser", "Find guilds", "INV_Misc_TabardPVP_01", function() BLFG:ShowGuildBrowser() end},
      }
      if self:SFModuleIsEnabled("invasions") then
        table.insert(items, {"Invasions", "Nearby invasion groups", "INV_Misc_Head_Dragon_01", function() BLFG:ShowInvasions() end})
      end
      table.insert(items, {"My Listing", "Manage your group", "INV_Misc_Book_09", function() BLFG:ShowMyListing() end})
      table.insert(items, {"Options", "Addon settings", "INV_Misc_Gear_01", function() BLFG:ShowOptions() end})
      table.insert(items, {"Network", "SignalFire users", "INV_Misc_GroupLooking", function() if BLFG.ShowSFNetwork then BLFG:ShowSFNetwork() else BLFG:ToggleOnlinePanel() end end})
      return items
    end

    local function sfm_clear_side(self)
      if not self.side then return end

      -- SignalFire 1.4.10: always hide every child currently attached to the sidebar.
      -- Older layers and previous builds can create sidebar buttons outside sfModuleSideChildren,
      -- so only hiding our tracked table is not enough and causes duplicate/stacked buttons.
      local kids = { self.side:GetChildren() }
      for _, child in ipairs(kids) do
        if child and child.Hide then child:Hide() end
      end

      if self.sfModuleSideChildren then
        for _, child in ipairs(self.sfModuleSideChildren) do
          if child and child.Hide then child:Hide() end
          end
      end

      if self.sideBrand and self.sideBrand.Hide then self.sideBrand:Hide() end
      self.sfModuleSideChildren = {}
      self.sideBrand = nil
      self.applicantsButton = nil
      self.applicantsButtonTitle = nil
      self.badge = nil
    end

    function BLFG:BuildSide()
      if not self.side then return end
      sfm_clear_side(self)
      local items = self:SFModulesBuildSideItems()
      local sideStep = (#items > 9) and 45 or ((#items > 8) and 50 or ((#items > 7) and 58 or 66))
      local sideHeight = (#items > 9) and 38 or ((#items > 8) and 43 or ((#items > 7) and 50 or 56))

      for i, it in ipairs(items) do
        local b = CreateFrame("Button", nil, self.side)
        table.insert(self.sfModuleSideChildren, b)
        b:SetWidth(158); b:SetHeight(sideHeight)
        b:SetPoint("TOP", self.side, "TOP", 0, -10 - ((i-1)*sideStep))
        sfm_backdrop(b, .82)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetTexture("Interface\\Icons\\" .. it[3])
        ic:SetWidth(28); ic:SetHeight(28); ic:SetPoint("LEFT", b, "LEFT", 10, 0)
        local titleSize = 12
        local titleX = 50
        if it[1] == "Profile" then titleSize = 11; titleX = 48 end
        local t = sfm_font(b, it[1], titleSize, 1, .92, .68)
        t:SetPoint("LEFT", b, "LEFT", titleX, 0)
        t:SetJustifyH("LEFT")
        t:SetWidth(104)

        if it[1] == "Applicants" then
          self.applicantsButton = b
          self.applicantsButtonTitle = t
          self.badge = CreateFrame("Frame", nil, b)
          self.badge:SetWidth(20); self.badge:SetHeight(16)
          self.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -9, -8)
          sfm_backdrop(self.badge, .95)
          self.badge.text = sfm_font(self.badge, "0", 9, 1, .2, .2)
          self.badge.text:SetPoint("CENTER")
          self.badge:Hide()
          b:SetScript("OnUpdate", function(btn)
            if BLFG.newApplicantAlert then
              local a = (math.sin(GetTime() * 6) + 1) / 2
              btn:SetBackdropColor(.35 + (.35 * a), .12 + (.20 * a), .02, .98)
              btn:SetBackdropBorderColor(1, .82, .18, 1)
              if BLFG.applicantsButtonTitle then BLFG.applicantsButtonTitle:SetTextColor(1, .35 + (.65 * a), .15) end
              if BLFG.badge then
                BLFG.badge:Show()
                BLFG.badge:SetBackdropColor(.55 + (.35 * a), .05, .05, .98)
                BLFG.badge:SetBackdropBorderColor(1, .9, .25, 1)
              end
            else
              btn:SetBackdropColor(0,0,0,.82)
              btn:SetBackdropBorderColor(.85,.62,.12,.95)
              if BLFG.applicantsButtonTitle then BLFG.applicantsButtonTitle:SetTextColor(1, .92, .68) end
              if BLFG.badge then BLFG.badge:Hide() end
            end
          end)
        end

        b:SetScript("OnEnter", function(btn)
          btn:SetBackdropBorderColor(1, .78, .18, 1)
          btn:SetBackdropColor(.10, .07, .02, .92)
        end)
        b:SetScript("OnLeave", function(btn)
          btn:SetBackdropBorderColor(.85,.62,.12,.95)
          btn:SetBackdropColor(0,0,0,.82)
        end)
        b:SetScript("OnClick", it[4])
      end

      local brand = sfm_font(self.side, sfm_profile_id(), 15, 1, .75, 0)
      table.insert(self.sfModuleSideChildren, brand)
      brand:SetPoint("BOTTOM", self.side, "BOTTOM", 0, 14)
      self.sideBrand = brand
      if self.SF143_UpdateServerBrand then self:SF143_UpdateServerBrand() end
    end

    function BLFG:SFModulesRefreshOptions()
      sfm_apply_hard_profile_defaults()
      local id = tostring(sfm_profile_id() or "Triumvirate")
      if self.optModuleInvasions then
        self.optModuleInvasions:SetChecked(self:SFModuleIsEnabled("invasions"))
        if id == "Ascension" then
          self.optModuleInvasions:Disable()
        else
          self.optModuleInvasions:Enable()
        end
      end
      if self.optGuildWhoDiscovery then
        if id == "Ascension" then
          self.optGuildWhoDiscovery:SetChecked(false)
          self.optGuildWhoDiscovery:Disable()
        else
          self.optGuildWhoDiscovery:Enable()
        end
      end
      if self.moduleInvasionsDefaultText then
        local def = self:SFModuleDefaultEnabled("invasions") and "profile default: on" or "profile default: off"
        self.moduleInvasionsDefaultText:SetText(id .. " " .. def)
      end
    end

    local SFModules_OldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = SFModules_OldBuildOptions and SFModules_OldBuildOptions(self, ...)

      -- SignalFire 1.4.10: BronzeLFG.lua now owns the visible Modules checkbox.
      -- Do not draw the older overlay module frame on top of Window Scale.
      if self.optModuleInvasions then
        self.sfModulesOptionsBuilt = true
        if self.moduleOptionsFrame and self.moduleOptionsFrame.Hide then self.moduleOptionsFrame:Hide() end
        if self.SFModulesRefreshOptions then self:SFModulesRefreshOptions() end
        return r
      end

      if self.optionsPanel and not self.sfModulesOptionsBuilt then
        self.sfModulesOptionsBuilt = true
        local f = CreateFrame("Frame", "BLFGModuleOptionsFrame", self.optionsPanel)
        self.moduleOptionsFrame = f
        f:SetWidth(230); f:SetHeight(74)
        f:SetPoint("TOPLEFT", self.optionsPanel, "TOPLEFT", 575, -248)
        sfm_font(f, "Modules", 13, .35, .7, 1):SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)

        local inv = CreateFrame("CheckButton", "BLFGOptModuleInvasions", f, "UICheckButtonTemplate")
        self.optModuleInvasions = inv
        inv:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -21)
        _G[inv:GetName().."Text"]:SetText("")
        inv:SetScript("OnClick", function(btn)
          BLFG:SFModuleSetEnabled("invasions", btn:GetChecked() and true or false)
          if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Module saved: Invasions " .. (BLFG:SFModuleIsEnabled("invasions") and "on" or "off") .. ".") end
        end)
        sfm_font(f, "Invasions", 11, 1, 1, 1):SetPoint("LEFT", inv, "RIGHT", 4, 1)
        self.moduleInvasionsDefaultText = sfm_font(f, "", 9, .75, .75, .75)
        self.moduleInvasionsDefaultText:SetPoint("TOPLEFT", f, "TOPLEFT", 26, -45)
      end
      if self.SFModulesRefreshOptions then self:SFModulesRefreshOptions() end
      return r
    end

    local SFModules_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFModules_OldShowOptions and SFModules_OldShowOptions(self, ...)
      if self.SFModulesRefreshOptions then self:SFModulesRefreshOptions() end
      return r
    end

    function BLFG:SFModulesRebuildSide()
      if not self.side then return end
      self:BuildSide()
    end

    function BLFG:SFModulesApply()
      sfm_patch_profile_defaults()
      sfm_apply_hard_profile_defaults()
      if self.optionsPanel then self:SFModulesRefreshOptions() end
      if self.side then self:SFModulesRebuildSide() end
      if not self:SFModuleIsEnabled("invasions") then
        if self.invasionPanel and self.invasionPanel:IsShown() then
          self.invasionPanel:Hide()
          if self.ShowBrowse then self:ShowBrowse() end
        end
        self.selectedInvasion = nil
        self.selectedInvasionName = nil
        self.selectedInvasionBeacon = nil
      end
    end

    local SFModules_OldProfileSet = BLFG.SF143_SetServerProfile
    if SFModules_OldProfileSet then
      function BLFG:SF143_SetServerProfile(...)
        local r = SFModules_OldProfileSet(self, ...)
        if self.SFModulesApply then self:SFModulesApply() end
        return r
      end
    end

    local function sfm_invasion_disabled_message()
      local id = sfm_profile_id()
      sfm_msg("Invasions are disabled for " .. tostring(id) .. ". Ascension/CoA does not use Triumvirate invasions.")
    end

    local SFModules_OldShowInvasions = BLFG.ShowInvasions
    function BLFG:ShowInvasions(...)
      if not self:SFModuleIsEnabled("invasions") then
        sfm_invasion_disabled_message()
        if self.ShowOptions then self:ShowOptions() end
        return
      end
      return SFModules_OldShowInvasions and SFModules_OldShowInvasions(self, ...)
    end

    local function sfm_is_invasion_payload(text)
      text = tostring(text or "")
      return string.find(text, "~INV", 1, true) ~= nil
    end

    local SFModules_OldHandleMessage = BLFG.HandleMessage
    function BLFG:HandleMessage(text)
      if not self:SFModuleIsEnabled("invasions") and sfm_is_invasion_payload(text) then return end
      return SFModules_OldHandleMessage and SFModules_OldHandleMessage(self, text)
    end

    local function sfm_guard(methodName)
      local old = BLFG[methodName]
      if old then
        BLFG["SFModules_Old_" .. methodName] = old
        BLFG[methodName] = function(self, ...)
          if not self:SFModuleIsEnabled("invasions") then return end
          return old(self, ...)
        end
      end
    end

    sfm_guard("SendInvasionPresence")
    sfm_guard("HandleInvasionPresence")
    sfm_guard("HandleInvasionBeacon")
    sfm_guard("HandleInvasionJoin")
    sfm_guard("HandleInvasionLeave")
    sfm_guard("HandleInvasionRequest")
    sfm_guard("CreateInvasionBeacon")
    sfm_guard("JoinInvasionBeacon")
    sfm_guard("LeaveInvasionBeacon")
    sfm_guard("RequestInvasionBeacons")
    sfm_guard("PostInvasionToChat")

    local SFModules_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
    function BLFG:RefreshPublicGroups(...)
      if not self:SFModuleIsEnabled("invasions") then
        for id, g in pairs(self.publicGroups or {}) do
          if g and (g.isInvasionBeacon or tostring(g.source or "") == "Invasion Beacon" or tostring(g.tags or ""):find("Invasion", 1, true)) then
            self.publicGroups[id] = nil
          end
        end
      end
      return SFModules_OldRefreshPublicGroups and SFModules_OldRefreshPublicGroups(self, ...)
    end

    local SFModules_OldSlash = SlashCmdList and (SlashCmdList["SIGNALFIRE"] or SlashCmdList["BRONZELFG"])
    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(input)
        local cmd = sfm_lower(sfm_trim(input or ""))
        if cmd == "modules" or cmd == "module" then
          sfm_msg("Active modules for " .. tostring(sfm_profile_id()) .. ": " .. BLFG:SFModulesStatusLine())
          return
        elseif cmd == "module invasions on" or cmd == "invasions on" then
          BLFG:SFModuleSetEnabled("invasions", true)
          sfm_msg("Invasions module enabled.")
          return
        elseif cmd == "module invasions off" or cmd == "invasions off" then
          BLFG:SFModuleSetEnabled("invasions", false)
          sfm_msg("Invasions module disabled.")
          return
        elseif cmd == "module invasions default" or cmd == "invasions default" then
          BLFG:SFModuleUseProfileDefault("invasions")
          sfm_msg("Invasions module reset to profile default.")
          return
        elseif (cmd == "invasion" or cmd == "invasions" or cmd == "invbeacon" or cmd == "invclear" or cmd == "invdebug" or cmd == "invtarget") and not BLFG:SFModuleIsEnabled("invasions") then
          sfm_invasion_disabled_message()
          return
        end
        if SFModules_OldSlash then return SFModules_OldSlash(input) end
      end
      SlashCmdList["BRONZELFG"] = SlashCmdList["SIGNALFIRE"]
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
      sfm_patch_profile_defaults()
      if BLFG and BLFG.SFModulesApply then BLFG:SFModulesApply() end
    end)

    -- SignalFire 1.4.6: reliable module slash dispatcher + fuller Invasions gating.
    -- The first module pass installed /sf handling only once.  Some older SignalFire
    -- layers also wrap /sf, so re-attach this dispatcher after login/world entry and
    -- provide a direct /sfmodules fallback.
    SignalFireModules = SignalFireModules or {}

    local SFM146 = SignalFireModules
    local SFM146_BLFG = _G.BronzeLFG

    local function sfm146_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfm146_low(s)
      return string.lower(sfm146_trim(s or ""))
    end

    local function sfm146_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfm146_profile_id()
      local B = _G.BronzeLFG
      if B and B.SF143_GetProfileId then return B:SF143_GetProfileId() end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then return BronzeLFG_DB.options.serverProfile end
      return "Triumvirate"
    end

    local function sfm146_invasions_enabled()
      local B = _G.BronzeLFG
      if B and B.SFModuleIsEnabled then return B:SFModuleIsEnabled("invasions") end
      return true
    end

    local function sfm146_status_line()
      local B = _G.BronzeLFG
      if B and B.SFModulesStatusLine then return B:SFModulesStatusLine() end
      return "Invasions=unknown"
    end

    local function sfm146_disabled_message()
      sfm146_msg("Invasions module is disabled for " .. tostring(sfm146_profile_id()) .. ". Use /sf invasions on or Options > Modules to enable it.")
    end

    function SFM146.HandleSlash(input, old)
      local B = _G.BronzeLFG
      local raw = tostring(input or "")
      local cmd = sfm146_low(raw)

      if cmd == "modules" or cmd == "module" or cmd == "mod" or cmd == "mods" then
        sfm146_msg("Active modules for " .. tostring(sfm146_profile_id()) .. ": " .. sfm146_status_line())
        sfm146_msg("Module commands: /sf invasions on, /sf invasions off, /sf invasions default")
        return true
      elseif cmd == "module invasions" or cmd == "modules invasions" or cmd == "mod invasions" or cmd == "invasions status" then
        sfm146_msg("Invasions module: " .. (sfm146_invasions_enabled() and "on" or "off") .. " for " .. tostring(sfm146_profile_id()) .. ".")
        sfm146_msg("Use /sf invasions on, /sf invasions off, or /sf invasions default.")
        return true
      elseif cmd == "module invasions on" or cmd == "modules invasions on" or cmd == "mod invasions on" or cmd == "invasions on" then
        if B and B.SFModuleSetEnabled then B:SFModuleSetEnabled("invasions", true) end
        sfm146_msg("Invasions module enabled.")
        return true
      elseif cmd == "module invasions off" or cmd == "modules invasions off" or cmd == "mod invasions off" or cmd == "invasions off" then
        if B and B.SFModuleSetEnabled then B:SFModuleSetEnabled("invasions", false) end
        sfm146_msg("Invasions module disabled.")
        return true
      elseif cmd == "module invasions default" or cmd == "modules invasions default" or cmd == "mod invasions default" or cmd == "invasions default" then
        if B and B.SFModuleUseProfileDefault then B:SFModuleUseProfileDefault("invasions") end
        sfm146_msg("Invasions module reset to profile default.")
        return true
      elseif (cmd == "invasion" or cmd == "invasions" or cmd == "inv" or cmd == "invbeacon" or cmd == "invclear" or cmd == "invdebug" or cmd == "invtarget") and not sfm146_invasions_enabled() then
        sfm146_disabled_message()
        return true
      end

      if old and old ~= SFM146.currentSlashWrapper then return old(input) end
      return nil
    end

    function SFM146.InstallSlash()
      if not SlashCmdList then return end
      local current = SlashCmdList["SIGNALFIRE"] or SlashCmdList["BRONZELFG"]
      if current and current ~= SFM146.currentSlashWrapper then
        SFM146.oldSlash = current
      end
      local function wrapper(input)
        return SFM146.HandleSlash(input, SFM146.oldSlash)
      end
      SFM146.currentSlashWrapper = wrapper

      SLASH_SIGNALFIRE1 = "/sf"
      SLASH_SIGNALFIRE2 = "/signalfire"
      SLASH_SIGNALFIRE3 = "/sfo"
      SlashCmdList["SIGNALFIRE"] = wrapper
      SlashCmdList["BRONZELFG"] = wrapper

      SLASH_SIGNALFIREMODULES1 = "/sfmodules"
      SlashCmdList["SIGNALFIREMODULES"] = function(input)
        input = sfm146_trim(input or "")
        if input == "" then return SFM146.HandleSlash("modules", nil) end
        return SFM146.HandleSlash("module " .. input, nil)
      end
    end

    SFM146.InstallSlash()

    local function sfm146_list_without_invasion()
      return {"Dungeon", "World Boss", "PvP", "Social", "Other"}
    end
    local function sfm146_list_with_invasion()
      return {"Dungeon", "World Boss", "Invasion", "PvP", "Social", "Other"}
    end

    function SFM146.ApplyEventInvasionGate()
      local B = _G.BronzeLFG
      if not B then return end
      local enabled = sfm146_invasions_enabled()

      if BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork then
        local n = BronzeLFG_DB.signalFireNetwork
        if not enabled and tostring(n.eventBoardFilter or "") == "Invasion" then
          n.eventBoardFilter = "All"
          n.eventBoardPage = 1
        end
      end

      local board = B.sfeEventPanel
      if board and board.filters then
        local prev = nil
        for _, btn in ipairs(board.filters or {}) do
          if btn and btn.sfeFilter == "Invasion" then
            if enabled then
              btn:Show(); btn:Enable(); btn:SetAlpha(1)
            else
              btn:Hide(); btn:Disable(); btn:SetAlpha(0)
            end
          end
          -- Do not hard-reanchor the old compact layout; hiding leaves a small gap but avoids taint/layout churn.
          prev = btn
        end
      end

      local creator = B.sfeEventCreator
      if creator and creator.typeBox then
        if enabled then
          creator.typeBox.values = sfm146_list_with_invasion()
        else
          creator.typeBox.values = sfm146_list_without_invasion()
          if creator.typeBox.sfeValue == "Invasion" then
            creator.typeBox.sfeValue = "Dungeon"
            if creator.typeBox.label then creator.typeBox.label:SetText("Dungeon") end
          end
        end
      end

      local alertPanel = B.sfe141EventOptionsPanel
      if alertPanel and alertPanel.typeChecks then
        for _, cb in ipairs(alertPanel.typeChecks or {}) do
          if cb and cb.sfe141Type == "Invasion" then
            if enabled then
              cb:Show(); cb:Enable(); cb:SetAlpha(1)
              if cb.text then cb.text:Show(); cb.text:SetAlpha(1) end
            else
              cb:Hide(); cb:Disable(); cb:SetAlpha(0)
              if cb.text then cb.text:Hide(); cb.text:SetAlpha(0) end
            end
          end
        end
      end
    end

    local SFM146_OldApply = SFM146_BLFG and SFM146_BLFG.SFModulesApply or nil
    if SFM146_BLFG then
      function SFM146_BLFG:SFModulesApply(...)
        local r = nil
        if SFM146_OldApply then r = SFM146_OldApply(self, ...) end
        if SFM146.ApplyEventInvasionGate then SFM146.ApplyEventInvasionGate() end
        return r
      end
    end

    local SFM146_OldRows = SFM146_BLFG and SFM146_BLFG.SFE_GetEventRows or nil
    if SFM146_BLFG and SFM146_OldRows then
      function SFM146_BLFG:SFE_GetEventRows(...)
        local rows = SFM146_OldRows(self, ...) or {}
        if sfm146_invasions_enabled() then return rows end
        local out = {}
        for _, row in ipairs(rows or {}) do
          if tostring(row and row.type or "") ~= "Invasion" then table.insert(out, row) end
        end
        return out
      end
    end

    local SFM146_OldSendEvent = SFM146_BLFG and SFM146_BLFG.SFE_SendEvent or nil
    if SFM146_BLFG and SFM146_OldSendEvent then
      function SFM146_BLFG:SFE_SendEvent(name, typeName, ...)
        if tostring(typeName or "") == "Invasion" and not sfm146_invasions_enabled() then
          sfm146_disabled_message()
          return nil
        end
        return SFM146_OldSendEvent(self, name, typeName, ...)
      end
    end

    local SFM146_OldOpenCreator = SFM146_BLFG and SFM146_BLFG.OpenSFEEventCreator or nil
    if SFM146_BLFG and SFM146_OldOpenCreator then
      function SFM146_BLFG:OpenSFEEventCreator(...)
        local r = SFM146_OldOpenCreator(self, ...)
        if SFM146.ApplyEventInvasionGate then SFM146.ApplyEventInvasionGate() end
        return r
      end
    end

    local SFM146_OldBuildBoard = SFM146_BLFG and SFM146_BLFG.SFE_BuildEventBoard or nil
    if SFM146_BLFG and SFM146_OldBuildBoard then
      function SFM146_BLFG:SFE_BuildEventBoard(...)
        local r = SFM146_OldBuildBoard(self, ...)
        if SFM146.ApplyEventInvasionGate then SFM146.ApplyEventInvasionGate() end
        return r
      end
    end

    local SFM146_OldRefreshBoard = SFM146_BLFG and SFM146_BLFG.SFE_RefreshEventBoard or nil
    if SFM146_BLFG and SFM146_OldRefreshBoard then
      function SFM146_BLFG:SFE_RefreshEventBoard(...)
        local r = SFM146_OldRefreshBoard(self, ...)
        if SFM146.ApplyEventInvasionGate then SFM146.ApplyEventInvasionGate() end
        return r
      end
    end

    local SFM146_OldNotifyEvent = SFM146_BLFG and SFM146_BLFG.SFE141_NotifyEventRow or nil
    if SFM146_BLFG and SFM146_OldNotifyEvent then
      function SFM146_BLFG:SFE141_NotifyEventRow(row, ...)
        if tostring(row and row.type or "") == "Invasion" and not sfm146_invasions_enabled() then return false end
        return SFM146_OldNotifyEvent(self, row, ...)
      end
    end

    local SFM146_Frame = CreateFrame("Frame")
    SFM146_Frame:RegisterEvent("PLAYER_LOGIN")
    SFM146_Frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    SFM146_Frame:SetScript("OnEvent", function()
      if SFM146.InstallSlash then SFM146.InstallSlash() end
      if SFM146.ApplyEventInvasionGate then SFM146.ApplyEventInvasionGate() end
      local B = _G.BronzeLFG
      if B and B.SFModulesApply then B:SFModulesApply() end
    end)
  until true
end

