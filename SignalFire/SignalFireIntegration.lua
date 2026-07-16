-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Commands
do
  repeat
    SignalFireSlashFinal = SignalFireSlashFinal or {}
    local SFSF = SignalFireSlashFinal

    local function sfsf_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfsf_low(s)
      return string.lower(sfsf_trim(s or ""))
    end

    local function sfsf_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfsf_B()
      return _G.BronzeLFG
    end

    local function sfsf_profile_id()
      local B = sfsf_B()
      if B and B.SF143_GetProfileId then return B:SF143_GetProfileId() end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sfsf_ensure_modules_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      return BronzeLFG_DB.options.modules
    end

    local function sfsf_profile_modules()
      sfsf_ensure_modules_db()
      local id = tostring(sfsf_profile_id() or "Triumvirate")
      BronzeLFG_DB.options.modulesByProfile[id] = BronzeLFG_DB.options.modulesByProfile[id] or {}
      return BronzeLFG_DB.options.modulesByProfile[id], id
    end

    local function sfsf_apply_profile_defaults()
      sfsf_ensure_modules_db()
      local id = tostring(sfsf_profile_id() or "Triumvirate")
      if id == "Ascension" then
        BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
        BronzeLFG_DB.options.modulesByProfile.Ascension.invasions = false
      end
    end

    local function sfsf_default_invasions()
      local B = sfsf_B()
      if B and B.SFModuleDefaultEnabled then return B:SFModuleDefaultEnabled("invasions") end
      local id = sfsf_profile_id()
      return id ~= "Ascension"
    end

    local function sfsf_invasions_enabled()
      sfsf_apply_profile_defaults()
      local B = sfsf_B()
      if B and B.SFModuleIsEnabled then return B:SFModuleIsEnabled("invasions") end
      local byProfile, id = sfsf_profile_modules()
      if id == "Ascension" then return false end
      if byProfile.invasions ~= nil then return byProfile.invasions == true end
      local mods = sfsf_ensure_modules_db()
      if mods.invasions ~= nil then return mods.invasions == true end
      return sfsf_default_invasions()
    end

    local function sfsf_status_line()
      local B = sfsf_B()
      if B and B.SFModulesStatusLine then return B:SFModulesStatusLine() end
      local state = sfsf_invasions_enabled() and "on" or "off"
      local def = sfsf_default_invasions() and "default on" or "default off"
      return "Invasions=" .. state .. " (" .. def .. ")"
    end


    local function sfsf_debug()
      local sf = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
      local blfg = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
      local sfmods = SlashCmdList and SlashCmdList["SIGNALFIREMODULES"] or nil
      local hsf = hash_SlashCmdList and (hash_SlashCmdList["/sf"] or hash_SlashCmdList["/SF"]) or nil
      local hsfm = hash_SlashCmdList and (hash_SlashCmdList["/sfm"] or hash_SlashCmdList["/SFM"]) or nil
      sfsf_msg("slashdebug: modules=" .. tostring(SignalFireModules ~= nil) .. " final=" .. tostring(SignalFireSlashFinal ~= nil))
      sfsf_msg("slashdebug: SIGNALFIRE=" .. tostring(sf) .. " BRONZELFG=" .. tostring(blfg) .. " SFMODULES=" .. tostring(sfmods))
      sfsf_msg("slashdebug: hash /sf=" .. tostring(hsf) .. " /sfm=" .. tostring(hsfm))
    end

    local function sfsf_apply_modules()
      local B = sfsf_B()
      if B and B.SFModulesApply then B:SFModulesApply() end
      if SignalFireModules and SignalFireModules.ApplyEventInvasionGate then SignalFireModules.ApplyEventInvasionGate() end
    end

    local function sfsf_utility_help()
      sfsf_msg("Utility commands: /sf presence, /sf admin, /sf adminclear, /sf purgelegacy, /sf clearallevents")
      sfsf_msg("Short aliases also installed: /sfp, /sfa, /sfac, /sfpl, /sfce")
    end

    local function sfsf_call_alias(kind, input)
      if SignalFireCommandAliases and SignalFireCommandAliases.Dispatch then
        return SignalFireCommandAliases.Dispatch(kind, input or "")
      end
      local PA = SignalFirePresenceAdminFix
      if kind == "presence" and PA and PA.RequestPresence then
        PA.RequestPresence("slash-final", true)
        sfsf_msg("SignalFire presence request sent.", .4, 1, .4)
        return true
      end
      if kind == "admin" and PA and PA.IsCurrentAdmin then
        local name = (UnitName and UnitName("player")) or "Unknown"
        sfsf_msg("SignalFire admin alias active: " .. tostring(PA.IsCurrentAdmin()) .. " (character: " .. tostring(name) .. ")")
        return true
      end
      if kind == "adminclear" and PA and PA.AdminClearEvent then return PA.AdminClearEvent(nil) end
      if kind == "clearall" and PA and PA.AdminClearEvent then return PA.AdminClearEvent("ALL") end
      sfsf_utility_help()
      return true
    end

    function SFSF.HandleUtilitySlash(input)
      local cmd = sfsf_low(input or "")

      if cmd == "presence" or cmd == "pingnet" or cmd == "network ping" or cmd == "netping" then
        return sfsf_call_alias("presence", "")
      end
      if cmd == "admin" or cmd == "admin status" then
        return sfsf_call_alias("admin", "")
      end
      if cmd == "adminclear" or cmd == "admin clear" or cmd == "clearselected" or cmd == "events adminclear" or cmd == "event adminclear" or cmd == "events clearselected" then
        return sfsf_call_alias("adminclear", "")
      end
      if cmd == "purgelegacy" or cmd == "purge legacy" or cmd == "clearlegacy" or cmd == "clear legacy" or cmd == "events purgelegacy" or cmd == "event purgelegacy" then
        return sfsf_call_alias("purgelegacy", "")
      end
      if cmd == "clearallevents" or cmd == "clear all events" or cmd == "masterclearevents" or cmd == "events clearall" or cmd == "event clearall" or cmd == "events masterclear" then
        return sfsf_call_alias("clearall", "")
      end
      if cmd == "commands" or cmd == "cmds" or cmd == "utilities" or cmd == "events" then
        sfsf_utility_help()
        return true
      end

      return false
    end

    local function sfsf_set_invasions(enabled)
      local B = sfsf_B()
      if B and B.SFModuleSetEnabled then
        B:SFModuleSetEnabled("invasions", enabled == true)
      else
        local byProfile, id = sfsf_profile_modules()
        byProfile.invasions = (id ~= "Ascension") and (enabled == true) or false
        sfsf_apply_modules()
      end
    end

    local function sfsf_default_invasions_override()
      local B = sfsf_B()
      if B and B.SFModuleUseProfileDefault then
        B:SFModuleUseProfileDefault("invasions")
      else
        local byProfile = sfsf_profile_modules()
        byProfile.invasions = nil
        sfsf_apply_modules()
      end
    end

    local function sfsf_disabled_message()
      sfsf_msg("Invasions module is disabled for " .. tostring(sfsf_profile_id()) .. ". Use /sf invasions on or Options > Modules to enable it.")
    end

    function SFSF.HandleModuleSlash(input)
      local cmd = sfsf_low(input or "")

      if cmd == "modules" or cmd == "module" or cmd == "mods" or cmd == "mod" then
        sfsf_msg("Active modules for " .. tostring(sfsf_profile_id()) .. ": " .. sfsf_status_line())
        sfsf_msg("Module commands: /sf invasions on, /sf invasions off, /sf invasions default")
        return true
      end

      if cmd == "module invasions" or cmd == "modules invasions" or cmd == "mod invasions" or cmd == "invasions status" then
        sfsf_msg("Invasions module: " .. (sfsf_invasions_enabled() and "on" or "off") .. " for " .. tostring(sfsf_profile_id()) .. ".")
        sfsf_msg("Use /sf invasions on, /sf invasions off, or /sf invasions default.")
        return true
      end

      if cmd == "module invasions on" or cmd == "modules invasions on" or cmd == "mod invasions on" or cmd == "invasions on" then
        sfsf_set_invasions(true)
        sfsf_msg("Invasions module enabled.")
        return true
      end

      if cmd == "module invasions off" or cmd == "modules invasions off" or cmd == "mod invasions off" or cmd == "invasions off" then
        sfsf_set_invasions(false)
        sfsf_msg("Invasions module disabled.")
        return true
      end

      if cmd == "module invasions default" or cmd == "modules invasions default" or cmd == "mod invasions default" or cmd == "invasions default" then
        sfsf_default_invasions_override()
        sfsf_msg("Invasions module reset to profile default.")
        return true
      end

      if cmd == "slashdebug" or cmd == "slash debug" or cmd == "debug slash" or cmd == "debug" then
        sfsf_debug()
        return true
      end

      if (cmd == "invasion" or cmd == "invasions" or cmd == "inv" or cmd == "invbeacon" or cmd == "invclear" or cmd == "invdebug" or cmd == "invtarget") and not sfsf_invasions_enabled() then
        sfsf_disabled_message()
        return true
      end

      return false
    end

    local function sfsf_core_help()
      sfsf_msg("Commands: /sf, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf guild, /sf invasions, /sf modules, /sf options, /sf online, /sf who")
      sfsf_msg("Utilities: /sf presence, /sf admin, /sf purgelegacy, /sf clearallevents")
    end

    function SFSF.Install()
      if not SlashCmdList then return end

      local currentSF = SlashCmdList["SIGNALFIRE"]
      local currentBLFG = SlashCmdList["BRONZELFG"]
      if currentSF and currentSF ~= SFSF.wrapper then SFSF.oldSignalFire = currentSF end
      if currentBLFG and currentBLFG ~= SFSF.wrapper then SFSF.oldBronzeLFG = currentBLFG end

      SFSF.wrapper = function(input)
        local raw = tostring(input or "")
        local cmd = sfsf_low(raw)

        if SFSF.HandleUtilitySlash and SFSF.HandleUtilitySlash(cmd) then return true end
        if SFSF.HandleModuleSlash and SFSF.HandleModuleSlash(cmd) then return true end

        local old = SFSF.oldSignalFire or SFSF.oldBronzeLFG
        if old and old ~= SFSF.wrapper then return old(raw) end

        local B = sfsf_B()
        if cmd == "" and B then
          if B.ToggleFrame then B:ToggleFrame(); return true end
          if B.Toggle then B:Toggle(); return true end
          if B.Show then B:Show(); return true end
        end
        sfsf_core_help()
        return true
      end

      SLASH_SIGNALFIRE1 = "/sf"
      SLASH_SIGNALFIRE2 = "/signalfire"
      SLASH_SIGNALFIRE3 = "/sfo"
      SlashCmdList["SIGNALFIRE"] = SFSF.wrapper

      SLASH_BRONZELFG1 = "/blfg"
      SLASH_BRONZELFG2 = "/bronzelfg"
      SlashCmdList["BRONZELFG"] = SFSF.wrapper

      SLASH_SIGNALFIREMODULES1 = "/sfmodules"
      SLASH_SIGNALFIREMODULES2 = "/sfm"
      SlashCmdList["SIGNALFIREMODULES"] = function(input)
        input = sfsf_trim(input or "")
        if input == "" then return SFSF.HandleModuleSlash("modules") end
        return SFSF.HandleModuleSlash("module " .. input)
      end

      SLASH_SIGNALFIRESLASHDEBUG1 = "/sfslash"
      SlashCmdList["SIGNALFIRESLASHDEBUG"] = function() sfsf_debug() end

      SLASH_SIGNALFIREPRESENCEFINAL1 = "/sfp"
      SLASH_SIGNALFIREPRESENCEFINAL2 = "/sfpresence"
      SlashCmdList["SIGNALFIREPRESENCEFINAL"] = function(input) sfsf_call_alias("presence", input) end

      SLASH_SIGNALFIREADMINFINAL1 = "/sfa"
      SLASH_SIGNALFIREADMINFINAL2 = "/sfadmin"
      SlashCmdList["SIGNALFIREADMINFINAL"] = function(input) sfsf_call_alias("admin", input) end

      SLASH_SIGNALFIREADMINCLEARFINAL1 = "/sfac"
      SLASH_SIGNALFIREADMINCLEARFINAL2 = "/sfadminclear"
      SlashCmdList["SIGNALFIREADMINCLEARFINAL"] = function(input) sfsf_call_alias("adminclear", input) end

      SLASH_SIGNALFIREPURGEFINAL1 = "/sfpl"
      SLASH_SIGNALFIREPURGEFINAL2 = "/sfpurgelegacy"
      SLASH_SIGNALFIREPURGEFINAL3 = "/sfclearlegacy"
      SlashCmdList["SIGNALFIREPURGEFINAL"] = function(input) sfsf_call_alias("purgelegacy", input) end

      SLASH_SIGNALFIRECLEARALLFINAL1 = "/sfce"
      SLASH_SIGNALFIRECLEARALLFINAL2 = "/sfclearallevents"
      SlashCmdList["SIGNALFIRECLEARALLFINAL"] = function(input) sfsf_call_alias("clearall", input) end

      -- Wrath 3.3.5 keeps an internal slash hash. Refresh both lower and upper
      -- forms as callable functions, and safely ask FrameXML to import the list when available.
      if ChatFrame_ImportListToHash then
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRE")
        pcall(ChatFrame_ImportListToHash, "BRONZELFG")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREMODULES")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRESLASHDEBUG")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREPRESENCEFINAL")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREADMINFINAL")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREADMINCLEARFINAL")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREPURGEFINAL")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRECLEARALLFINAL")
      end
      if ChatFrame_ImportAllLists then pcall(ChatFrame_ImportAllLists) end
      if hash_SlashCmdList then
        local pairsToSet = {
          {"/sf", "SIGNALFIRE"}, {"/SF", "SIGNALFIRE"},
          {"/signalfire", "SIGNALFIRE"}, {"/SIGNALFIRE", "SIGNALFIRE"},
          {"/sfo", "SIGNALFIRE"}, {"/SFO", "SIGNALFIRE"},
          {"/blfg", "BRONZELFG"}, {"/BLFG", "BRONZELFG"},
          {"/bronzelfg", "BRONZELFG"}, {"/BRONZELFG", "BRONZELFG"},
          {"/sfmodules", "SIGNALFIREMODULES"}, {"/SFMODULES", "SIGNALFIREMODULES"},
          {"/sfm", "SIGNALFIREMODULES"}, {"/SFM", "SIGNALFIREMODULES"},
          {"/sfslash", "SIGNALFIRESLASHDEBUG"}, {"/SFSLASH", "SIGNALFIRESLASHDEBUG"},
          {"/sfp", "SIGNALFIREPRESENCEFINAL"}, {"/SFP", "SIGNALFIREPRESENCEFINAL"}, {"sfp", "SIGNALFIREPRESENCEFINAL"},
          {"/sfpresence", "SIGNALFIREPRESENCEFINAL"}, {"/SFPRESENCE", "SIGNALFIREPRESENCEFINAL"}, {"sfpresence", "SIGNALFIREPRESENCEFINAL"},
          {"/sfa", "SIGNALFIREADMINFINAL"}, {"/SFA", "SIGNALFIREADMINFINAL"}, {"sfa", "SIGNALFIREADMINFINAL"},
          {"/sfadmin", "SIGNALFIREADMINFINAL"}, {"/SFADMIN", "SIGNALFIREADMINFINAL"}, {"sfadmin", "SIGNALFIREADMINFINAL"},
          {"/sfac", "SIGNALFIREADMINCLEARFINAL"}, {"/SFAC", "SIGNALFIREADMINCLEARFINAL"}, {"sfac", "SIGNALFIREADMINCLEARFINAL"},
          {"/sfadminclear", "SIGNALFIREADMINCLEARFINAL"}, {"/SFADMINCLEAR", "SIGNALFIREADMINCLEARFINAL"},
          {"/sfpl", "SIGNALFIREPURGEFINAL"}, {"/SFPL", "SIGNALFIREPURGEFINAL"}, {"sfpl", "SIGNALFIREPURGEFINAL"},
          {"/sfpurgelegacy", "SIGNALFIREPURGEFINAL"}, {"/SFPURGELEGACY", "SIGNALFIREPURGEFINAL"},
          {"/sfclearlegacy", "SIGNALFIREPURGEFINAL"}, {"/SFCLEARLEGACY", "SIGNALFIREPURGEFINAL"},
          {"/sfce", "SIGNALFIRECLEARALLFINAL"}, {"/SFCE", "SIGNALFIRECLEARALLFINAL"}, {"sfce", "SIGNALFIRECLEARALLFINAL"},
          {"/sfclearallevents", "SIGNALFIRECLEARALLFINAL"}, {"/SFCLEARALLEVENTS", "SIGNALFIRECLEARALLFINAL"},
        }
        for _, row in ipairs(pairsToSet) do
          local fn = SlashCmdList and SlashCmdList[row[2]]
          if type(fn) == "function" then
            hash_SlashCmdList[row[1]] = fn
            if hash_SecureCmdList then hash_SecureCmdList[row[1]] = fn end
          end
        end
      end
    end

    SFSF.Install()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame.elapsed = 0
    frame.reinstalls = 0
    frame:SetScript("OnEvent", function(self, event, addon)
      if event == "ADDON_LOADED" and addon and addon ~= "SignalFire" and addon ~= "BronzeLFG" then return end
      if SFSF.Install then SFSF.Install() end
      sfsf_apply_modules()
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (elapsed or 0)
      if self.elapsed < 1 then return end
      self.elapsed = 0
      self.reinstalls = (self.reinstalls or 0) + 1
      if self.reinstalls <= 10 then
        if SFSF.Install then SFSF.Install() end
      else
        self:SetScript("OnUpdate", nil)
      end
    end)
  until true
end

-- Module interface
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local function sf149_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sf149_profile_id()
      if BLFG.SF143_GetProfileId then return BLFG:SF143_GetProfileId() end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sf149_apply_profile_defaults()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      local id = tostring(sf149_profile_id() or "Triumvirate")
      if id == "Ascension" then
        BronzeLFG_DB.options.modulesByProfile.Ascension = BronzeLFG_DB.options.modulesByProfile.Ascension or {}
        BronzeLFG_DB.options.modulesByProfile.Ascension.invasions = false
      end
    end

    local function sf149_module_enabled(key)
      sf149_apply_profile_defaults()
      if BLFG.SFCore149_ModuleEnabled then return BLFG:SFCore149_ModuleEnabled(key) end
      if BLFG.SFModuleIsEnabled then return BLFG:SFModuleIsEnabled(key) end
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      local id = tostring(sf149_profile_id() or "Triumvirate")
      if key == "invasions" and id == "Ascension" then return false end
      local byProfile = BronzeLFG_DB.options.modulesByProfile[id]
      if byProfile and byProfile[key] ~= nil then return byProfile[key] == true end
      local mods = BronzeLFG_DB.options.modules
      if id ~= "Ascension" and mods and mods[key] ~= nil then return mods[key] == true end
      if key == "invasions" then return id ~= "Ascension" end
      return true
    end

    local function sf149_set_module(key, enabled)
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
      local id = tostring(sf149_profile_id() or "Triumvirate")
      BronzeLFG_DB.options.modulesByProfile[id] = BronzeLFG_DB.options.modulesByProfile[id] or {}
      if key == "invasions" and id == "Ascension" then
        BronzeLFG_DB.options.modulesByProfile[id][key] = false
      else
        BronzeLFG_DB.options.modulesByProfile[id][key] = enabled == true
      end
    end

    local function sf149_apply_side()
      if not BLFG or not BLFG.side or not BLFG.BuildSide then return end
      if BLFG._sf149_rebuilding_side then return end
      BLFG._sf149_rebuilding_side = true
      BLFG:BuildSide()
      BLFG._sf149_rebuilding_side = false
    end

    local function sf149_refresh_options()
      sf149_apply_profile_defaults()
      local id = tostring(sf149_profile_id() or "Triumvirate")
      if BLFG.optModuleInvasions then
        BLFG.optModuleInvasions:SetChecked(sf149_module_enabled("invasions"))
        if id == "Ascension" then BLFG.optModuleInvasions:Disable() else BLFG.optModuleInvasions:Enable() end
      end
      if BLFG.optGuildWhoDiscovery then
        BLFG.optGuildWhoDiscovery:Enable()
      end
      if BLFG.moduleInvasionsDefaultText then
        local def = (id == "Ascension") and "profile default: off" or "profile default: on"
        BLFG.moduleInvasionsDefaultText:SetText(id .. " " .. def)
      end
    end

    local function sf149_apply()
      sf149_apply_profile_defaults()
      if not sf149_module_enabled("invasions") then
        if BLFG.invasionPanel and BLFG.invasionPanel.IsShown and BLFG.invasionPanel:IsShown() then
          BLFG.invasionPanel:Hide()
          if BLFG.ShowOptions then BLFG:ShowOptions() end
        end
        BLFG.selectedInvasion = nil
        BLFG.selectedInvasionName = nil
        BLFG.selectedInvasionBeacon = nil
      end
      sf149_apply_side()
      sf149_refresh_options()
    end

    -- Final ShowInvasions guard. This stays after the older wrappers.
    local SF149_OldShowInvasions = BLFG.ShowInvasions
    function BLFG:ShowInvasions(...)
      if not sf149_module_enabled("invasions") then
        sf149_msg("Invasions are disabled for " .. tostring(sf149_profile_id()) .. ". Ascension/CoA does not use Triumvirate invasions.")
        if self.ShowOptions then self:ShowOptions() end
        return
      end
      return SF149_OldShowInvasions and SF149_OldShowInvasions(self, ...)
    end

    local SF149_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local r = SF149_OldCreateUI and SF149_OldCreateUI(self, ...)
      sf149_apply()
      return r
    end

    local SF149_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SF149_OldShowOptions and SF149_OldShowOptions(self, ...)
      sf149_refresh_options()
      return r
    end

    local SF149_OldProfileSet = BLFG.SF143_SetServerProfile
    if SF149_OldProfileSet then
      function BLFG:SF143_SetServerProfile(...)
        local r = SF149_OldProfileSet(self, ...)
        sf149_apply()
        return r
      end
    end

    -- If the user toggles the core checkbox, force the sidebar immediately.
    function BLFG:SF149_SetInvasionsModule(enabled)
      sf149_set_module("invasions", enabled == true)
      sf149_apply()
      sf149_msg("Invasions module " .. (sf149_module_enabled("invasions") and "enabled." or "disabled."))
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
      sf149_apply()
    end)
  until true
end

-- Profile discovery gate
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireWhoProfileGate = SignalFireWhoProfileGate or {}
    local SFWG = SignalFireWhoProfileGate

    local function sfwg_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfwg_profile_id()
      if BLFG and BLFG.SF143_GetProfileId then return tostring(BLFG:SF143_GetProfileId() or "Triumvirate") end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sfwg_is_ascension()
      return sfwg_profile_id() == "Ascension"
    end

    local function sfwg_show(frame, show)
      if not frame then return end
      if show then
        if frame.Show then frame:Show() end
        if frame.Enable then frame:Enable() end
      else
        if frame.Disable then frame:Disable() end
        if frame.Hide then frame:Hide() end
      end
    end

    local function sfwg_walk(frame, fn, seen)
      if not frame or not frame.GetChildren then return end
      seen = seen or {}
      if seen[frame] then return end
      seen[frame] = true
      fn(frame)
      for _, child in ipairs({frame:GetChildren()}) do
        sfwg_walk(child, fn, seen)
      end
    end

    local function sfwg_rename_button(root, oldText, newText)
      if not root then return end
      sfwg_walk(root, function(f)
        if f and f.GetText and f.SetText then
          local t = tostring(f:GetText() or "")
          if t == oldText then f:SetText(newText) end
        end
      end)
    end

    function BLFG:SFWhoGate_IsAscension()
      return sfwg_is_ascension()
    end

    -- This intentionally does NOT control Guild Browser discovery. That checkbox stays
    -- available because we are keeping #1 in for now.
    function BLFG:SFWhoGate_ShowNetworkWhoLayer()
      return not sfwg_is_ascension()
    end

    local function sfwg_filter_network_rows(rows)
      if not sfwg_is_ascension() then return rows end
      local out = {}
      for _, u in ipairs(rows or {}) do
        if not (u and u.whoOnly) then table.insert(out, u) end
      end
      return out
    end

    local SFWG_OldGetOnlineUserRows = BLFG.GetOnlineUserRows
    function BLFG:GetOnlineUserRows(...)
      local rows = SFWG_OldGetOnlineUserRows and SFWG_OldGetOnlineUserRows(self, ...) or {}
      return sfwg_filter_network_rows(rows)
    end

    local function sfwg_fix_online_ui(self)
      if not self then return end
      local asc = sfwg_is_ascension()

      if asc and self.onlineFilter == "Who" then
        self.onlineFilter = "All"
        self.onlinePage = 1
      end

      if self.onlineFilterButtons and self.onlineFilterButtons.Who then
        sfwg_show(self.onlineFilterButtons.Who, not asc)
        local sf = self.onlineFilterButtons.SignalFire
        local who = self.onlineFilterButtons.Who
        local fav = self.onlineFilterButtons.Favorites
        local guild = self.onlineFilterButtons.Guild
        if fav and fav.ClearAllPoints and fav.SetPoint then
          fav:ClearAllPoints()
          if asc and sf then fav:SetPoint("LEFT", sf, "RIGHT", 6, 0)
          elseif who then fav:SetPoint("LEFT", who, "RIGHT", 6, 0) end
        end
        if guild and guild.ClearAllPoints and guild.SetPoint and fav then
          guild:ClearAllPoints()
          guild:SetPoint("LEFT", fav, "RIGHT", 6, 0)
        end
      end

      if self.onlinePanel then
        if self.onlinePanel.subtitle and self.onlinePanel.subtitle.SetText then
          if asc then
            self.onlinePanel.subtitle:SetText("Expanded online directory for SignalFire presence users.")
          else
            self.onlinePanel.subtitle:SetText("Expanded online directory for SignalFire presence and /who-discovered players.")
          end
        end
        if asc then
          sfwg_rename_button(self.onlinePanel, "Who List to Chat", "List to Chat")
          sfwg_rename_button(self.onlinePanel, "Online (0)", "Online")
        end
      end

      local f = self.onlinePanel
      if f and f.statWho then
        if asc then
          f.statWho:SetText("")
          sfwg_show(f.statWho, false)
        else
          sfwg_show(f.statWho, true)
        end
      end

      if self.onlinePanelTitle and asc then
        self.onlinePanelTitle:SetText("SignalFire Network")
      end

      if self.onlineStats and asc and self.onlineStats.GetText and self.onlineStats.SetText then
        local txt = tostring(self.onlineStats:GetText() or "")
        txt = string.gsub(txt, "  |  /who Only:%s*%d+", "")
        txt = string.gsub(txt, "  |  Online /who", "")
        txt = string.gsub(txt, "Online /who", "SignalFire")
        txt = string.gsub(txt, "/who%-discovered", "SignalFire")
        self.onlineStats:SetText(txt)
      end
    end

    local SFWG_OldBuildOnlinePanel = BLFG.BuildOnlinePanel
    function BLFG:BuildOnlinePanel(...)
      local r = SFWG_OldBuildOnlinePanel and SFWG_OldBuildOnlinePanel(self, ...)
      sfwg_fix_online_ui(self)
      return r
    end

    local SFWG_OldRefreshOnlinePanel = BLFG.RefreshOnlinePanel
    function BLFG:RefreshOnlinePanel(...)
      if sfwg_is_ascension() and self.onlineFilter == "Who" then
        self.onlineFilter = "All"
        self.onlinePage = 1
      end
      local r = SFWG_OldRefreshOnlinePanel and SFWG_OldRefreshOnlinePanel(self, ...)
      sfwg_fix_online_ui(self)
      return r
    end

    -- Full Roster: hide /who-only records and /who controls on Ascension. The row
    -- filter is handled by GetOnlineUserRows above; this cleans up the presentation.
    local SFWG_OldSFRPGetRosterRows = BLFG.SFRP_GetRosterRows
    if SFWG_OldSFRPGetRosterRows then
      function BLFG:SFRP_GetRosterRows(...)
        if sfwg_is_ascension() and self.onlineFilter == "Who" then
          self.onlineFilter = "All"
          self.onlinePage = 1
        end
        local rows, allRows = SFWG_OldSFRPGetRosterRows(self, ...)
        return sfwg_filter_network_rows(rows), sfwg_filter_network_rows(allRows)
      end
    end

    local SFWG_OldRefreshFullRosterDetail = BLFG.RefreshFullRosterDetail
    if SFWG_OldRefreshFullRosterDetail then
      function BLFG:RefreshFullRosterDetail(...)
        if sfwg_is_ascension() and self.fullRosterSelectedUser and self.fullRosterSelectedUser.whoOnly then
          self.fullRosterSelectedUser = nil
          self.fullRosterSelectedName = nil
        end
        local r = SFWG_OldRefreshFullRosterDetail(self, ...)
        if sfwg_is_ascension() and self.fullRosterDetail then
          local f = self.fullRosterDetail
          if f.who then
            f.who:SetScript("OnClick", function() sfwg_msg("Who lookup is disabled on the Ascension profile.") end)
            sfwg_show(f.who, false)
          end
          if f.detail and f.detail.GetText and f.detail.SetText then
            local txt = tostring(f.detail:GetText() or "")
            txt = string.gsub(txt, "Source:|r /who discovered", "Source:|r SignalFire presence")
            txt = string.gsub(txt, "This player was discovered through the online roster scan%.[^\n]*\n?", "")
            f.detail:SetText(txt)
          end
        elseif self.fullRosterDetail and self.fullRosterDetail.who then
          sfwg_show(self.fullRosterDetail.who, true)
        end
        return r
      end
    end

    -- Right-click SignalFire Network menu: remove SendWho-powered lookup on Ascension.
    local SFWG_OldShowOnlineUserMenu = BLFG.ShowOnlineUserMenu
    function BLFG:ShowOnlineUserMenu(anchor, u)
      if not sfwg_is_ascension() then
        return SFWG_OldShowOnlineUserMenu and SFWG_OldShowOnlineUserMenu(self, anchor, u)
      end
      if not u or not u.name then return end
      if u.whoOnly then return end
      if not self.onlineMenu then self.onlineMenu = CreateFrame("Frame", "BronzeLFGOnlineMenu", UIParent, "UIDropDownMenuTemplate") end
      local name = tostring(u.name or "")
      self.selectedSFNUser = name
      UIDropDownMenu_Initialize(self.onlineMenu, function()
        local info = UIDropDownMenu_CreateInfo()
        info.text = name
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "View SignalFire Network Profile"
        info.notCheckable = true
        info.func = function()
          if BLFG.ShowBronzeNetProfile then
            if SFN135J_UserTableForName then BLFG:ShowBronzeNetProfile(SFN135J_UserTableForName(name))
            else BLFG:ShowBronzeNetProfile(u) end
          end
        end
        UIDropDownMenu_AddButton(info)

        local playerName = (UnitName and UnitName("player")) or ""
        info = UIDropDownMenu_CreateInfo()
        info.text = "Whisper"
        info.notCheckable = true
        info.disabled = (name == playerName)
        info.func = function() if name ~= playerName and ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Invite"
        info.notCheckable = true
        info.disabled = (name == playerName)
        info.func = function() if name ~= playerName and InviteUnit then InviteUnit(name) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Add Friend"
        info.notCheckable = true
        info.disabled = (name == playerName)
        info.func = function() if name ~= playerName and AddFriend then AddFriend(name) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Copy Name to Chat"
        info.notCheckable = true
        info.func = function() if ChatFrame_OpenChat then ChatFrame_OpenChat(name) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = (BLFG.IsFavorite and BLFG:IsFavorite(name)) and "Remove Favorite" or "Add Favorite"
        info.notCheckable = true
        info.func = function()
          if BLFG.ToggleFavorite then BLFG:ToggleFavorite(name) end
          if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          if BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
          if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Who Lookup unavailable on Ascension"
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Cancel"
        info.notCheckable = true
        info.func = function() if CloseDropDownMenus then CloseDropDownMenus() end end
        UIDropDownMenu_AddButton(info)
      end, "MENU")
      if sfn_fix_dropdown_layers then sfn_fix_dropdown_layers() end
      ToggleDropDownMenu(1, nil, self.onlineMenu, anchor or UIParent, 0, 0)
      if sfn_fix_dropdown_layers then sfn_fix_dropdown_layers() end
    end

    if SFN135J_OpenWho then
      local SFWG_OldSFN135JOpenWho = SFN135J_OpenWho
      function SFN135J_OpenWho(name)
        if sfwg_is_ascension() then
          sfwg_msg("Who lookup is disabled on the Ascension profile.")
          return
        end
        return SFWG_OldSFN135JOpenWho(name)
      end
    end

    -- Safety: Invasions already module-gate off on Ascension, but the zone /who scan
    -- should never start there even if an old slash command reaches it.
    local SFWG_OldQueueInvasionWhoScan = BLFG.QueueInvasionWhoScan
    if SFWG_OldQueueInvasionWhoScan then
      function BLFG:QueueInvasionWhoScan(manual, ...)
        if sfwg_is_ascension() then
          if manual then sfwg_msg("Invasion /who scan is disabled on the Ascension profile.") end
          return
        end
        return SFWG_OldQueueInvasionWhoScan(self, manual, ...)
      end
    end

    -- Keep the Guild Browser /who discovery checkbox available for now. Older 1.4.11
    -- guards disabled it for Ascension; this final pass reverses only the UI lock, not
    -- the user's saved checked/unchecked value.
    local function sfwg_fix_options()
      if BLFG and BLFG.optGuildWhoDiscovery then
        BLFG.optGuildWhoDiscovery:Enable()
      end
    end

    local SFWG_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFWG_OldShowOptions and SFWG_OldShowOptions(self, ...)
      sfwg_fix_options()
      sfwg_fix_online_ui(self)
      return r
    end

    local SFWG_OldProfileSet = BLFG.SF143_SetServerProfile
    if SFWG_OldProfileSet then
      function BLFG:SF143_SetServerProfile(...)
        local r = SFWG_OldProfileSet(self, ...)
        if sfwg_is_ascension() and self.onlineFilter == "Who" then self.onlineFilter = "All" end
        sfwg_fix_options()
        if self.RefreshOnlinePanel then self:RefreshOnlinePanel() end
        if self.RefreshFullRosterDetail then self:RefreshFullRosterDetail() end
        return r
      end
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
      sfwg_fix_options()
      if BLFG and BLFG.onlineFilter == "Who" and sfwg_is_ascension() then BLFG.onlineFilter = "All" end
      if BLFG and BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
    end)
  until true
end

-- Presence and administration
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFirePresenceAdminFix = SignalFirePresenceAdminFix or {}
    local SFPA = SignalFirePresenceAdminFix

    local PREFIX = "BLFG312"
    local CHANNEL = "BLFG"

    local ADMIN_ALIASES = {
      hsoj = true,
      hs0j = true,
      aesri = true,
    }

    local function sfpa_now()
      return (time and time()) or 0
    end

    local function sfpa_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfpa_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfpa_key(name)
      name = sfpa_low(sfpa_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      name = string.gsub(name, "[^a-z0-9]", "")
      return name
    end

    local function sfpa_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfpa_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfpa_split(s)
      local t = {}
      s = tostring(s or "")
      local start = 1
      while true do
        local pos = string.find(s, "~", start, true)
        if not pos then table.insert(t, string.sub(s, start)); break end
        table.insert(t, string.sub(s, start, pos - 1))
        start = pos + 1
      end
      return t
    end

    local function sfpa_send(payload)
      payload = tostring(payload or "")
      if payload == "" then return false end
      local id = GetChannelName and GetChannelName(CHANNEL) or nil
      if id and id ~= 0 and SendChatMessage then
        SendChatMessage(payload, "CHANNEL", nil, id)
        return true
      end
      if JoinChannelByName then JoinChannelByName(CHANNEL) end
      return false
    end

    local scheduled = {}
    local function sfpa_after(delay, fn)
      table.insert(scheduled, {t = sfpa_now() + (tonumber(delay) or 0), fn = fn})
    end

    function SFPA.IsAdminName(name)
      return ADMIN_ALIASES[sfpa_key(name)] == true
    end

    function SFPA.IsCurrentAdmin()
      return SFPA.IsAdminName(sfpa_player())
    end

    function BLFG:SF_IsAdminName(name)
      return SFPA.IsAdminName(name)
    end

    function BLFG:SF_IsCurrentAdmin()
      return SFPA.IsCurrentAdmin()
    end

    local function sfpa_is_ascension()
      if BLFG and BLFG.SF143_GetProfileId then
        local ok, value = pcall(function() return BLFG:SF143_GetProfileId() end)
        if ok then
          local id = sfpa_low(value or "")
          return string.find(id, "ascension", 1, true) ~= nil or string.find(id, "bronzebeard", 1, true) ~= nil or id == "coa"
        end
      end
      local id = sfpa_low(BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile or "")
      return string.find(id, "ascension", 1, true) ~= nil or string.find(id, "bronzebeard", 1, true) ~= nil or id == "coa"
    end

    local function sfpa_row_score(u)
      if not u then return -1 end
      local score = 0
      if u.self then score = score + 1000 end
      if not u.whoOnly then score = score + 200 end
      if u.favorite then score = score + 40 end
      if u.friend then score = score + 20 end
      if u.groupmate then score = score + 20 end
      if tostring(u.guild or "") ~= "" then score = score + 5 end
      if tostring(u.zone or "") ~= "" then score = score + 5 end
      if tostring(u.role or "") ~= "" then score = score + 3 end
      score = score + math.min(10, math.max(0, math.floor((tonumber(u.seen or 0) or 0) / 100000000)))
      return score
    end

    -- Final active-roster gate. Earlier layers may contribute the same character
    -- through SignalFire presence, status packets, friends/group state, and /who.
    -- Collapse those records here and reject stale entries before any Network UI
    -- consumes them. Ascension remains SignalFire-presence only.
    local SFPA_OldGetOnlineUserRows = BLFG.GetOnlineUserRows
    function BLFG:GetOnlineUserRows(...)
      local raw = SFPA_OldGetOnlineUserRows and SFPA_OldGetOnlineUserRows(self, ...) or {}
      local current = sfpa_now()
      local byKey, order = {}, {}
      local ascension = sfpa_is_ascension()

      for _, u in ipairs(raw or {}) do
        local keep = u ~= nil
        local seen = tonumber(u and u.seen or current) or current
        if keep and not u.self then
          local ttl = u.whoOnly and 300 or 180
          if seen <= 0 or (current - seen) > ttl then keep = false end
        end
        if keep and ascension and u.whoOnly then keep = false end

        if keep then
          local key = sfpa_key(u.name or "")
          if key ~= "" then
            local old = byKey[key]
            if not old then
              byKey[key] = u
              table.insert(order, key)
            else
              local oldScore = sfpa_row_score(old)
              local newScore = sfpa_row_score(u)
              local oldSeen = tonumber(old.seen or 0) or 0
              if newScore > oldScore or (newScore == oldScore and seen > oldSeen) then
                byKey[key] = u
              end
            end
          end
        end
      end

      local rows = {}
      for _, key in ipairs(order) do
        local u = byKey[key]
        if u then table.insert(rows, u) end
      end

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
      return rows
    end

    -- Presence handshake ---------------------------------------------------------
    -- Older builds only broadcast status on a 60 second heartbeat. If you opened
    -- the Network tab right after everyone else had already pinged, the list could
    -- look empty until the next heartbeat. This request asks other 1.4.13+ clients
    -- to answer immediately with their normal SignalFire presence/status packets.

    local lastRequest = 0
    local lastRespond = 0

    function SFPA.SendOwnPresence()
      if BLFG and BLFG.SendPresence then BLFG:SendPresence() end
      if BLFG and BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
    end

    function SFPA.RequestPresence(reason, force)
      local now = sfpa_now()
      if not force and (now - (lastRequest or 0)) < 12 then return false end
      lastRequest = now
      if BLFG then
        BLFG._sfnPresenceRefreshPending = now
        BLFG._sfnLastPresenceRequest = now
        BLFG._sfnLastPresenceReason = tostring(reason or "request")
      end
      SFPA.SendOwnPresence()
      local ok = sfpa_send(table.concat({PREFIX, "SFNREQ", sfpa_player(), tostring(now), tostring(reason or "request")}, "~"))
      if not ok then
        sfpa_after(2.0, function() SFPA.RequestPresence(reason or "retry", true) end)
      end
      return ok
    end

    function SFPA.HandlePresenceRequest(payloadAuthor, payloadName)
      local requester = sfpa_key(payloadName or payloadAuthor or "")
      if requester == "" or requester == sfpa_key(sfpa_player()) then return true end
      local now = sfpa_now()
      if (now - (lastRespond or 0)) < 6 then return true end
      lastRespond = now
      sfpa_after(0.4, function() SFPA.SendOwnPresence() end)
      return true
    end

    local SFPA_OldHandleMessage = BLFG.HandleMessage
    function BLFG:HandleMessage(text, ...)
      local raw = tostring(text or "")
      if string.sub(raw, 1, string.len(PREFIX) + 1) == (PREFIX .. "~") then
        local p = sfpa_split(raw)
        if p[1] == PREFIX and p[2] == "SFNREQ" then
          SFPA.HandlePresenceRequest(nil, p[3])
          return
        end
      end
      return SFPA_OldHandleMessage and SFPA_OldHandleMessage(self, text, ...)
    end

    local SFPA_OldShowSFNetwork = BLFG.ShowSFNetwork
    function BLFG:ShowSFNetwork(...)
      local r = SFPA_OldShowSFNetwork and SFPA_OldShowSFNetwork(self, ...)
      self._sfnNextAutoRefresh = sfpa_now() + 1
      SFPA.RequestPresence("network-open", true)
      return r
    end

    local SFPA_OldRefreshSFNetwork = BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      return SFPA_OldRefreshSFNetwork and SFPA_OldRefreshSFNetwork(self, ...)
    end

    local function sfpa_install_roster_refresh()
      local f = BLFG and BLFG.onlinePanel
      local b = f and f.refreshButton
      if not b or b._sfpa1432 then return end
      b._sfpa1432 = true
      b:SetText("Refresh Now")
      b:SetScript("OnClick", function()
        SFPA.RequestPresence("full-roster-button", true)
        if BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
        sfpa_msg("Refreshing SignalFire presence...", .4, 1, .4)
      end)
    end

    local SFPA_OldBuildOnlinePanel = BLFG.BuildOnlinePanel
    if SFPA_OldBuildOnlinePanel then
      function BLFG:BuildOnlinePanel(...)
        local r = SFPA_OldBuildOnlinePanel(self, ...)
        sfpa_install_roster_refresh()
        return r
      end
    end

    local SFPA_OldRefreshOnlinePanel = BLFG.RefreshOnlinePanel
    if SFPA_OldRefreshOnlinePanel then
      function BLFG:RefreshOnlinePanel(...)
        local r = SFPA_OldRefreshOnlinePanel(self, ...)
        sfpa_install_roster_refresh()
        if self.onlineStats and self.onlinePanel and self.onlinePanel:IsVisible() then
          local response = tonumber(self._sfnLastPresenceResponse or 0) or 0
          if response > 0 then
            local age = math.max(0, sfpa_now() - response)
            local existing = tostring(self.onlineStats:GetText() or "")
            existing = string.gsub(existing, "%s+|%s+Last response:.*$", "")
            self.onlineStats:SetText(existing .. "  |  Last response: " .. tostring(age) .. "s ago")
          end
        end
        return r
      end
    end

    local SFPA_OldShowFullRoster = BLFG.ShowFullRoster
    if SFPA_OldShowFullRoster then
      function BLFG:ShowFullRoster(...)
        local r = SFPA_OldShowFullRoster(self, ...)
        self._sfnNextAutoRefresh = sfpa_now() + 1
        SFPA.RequestPresence("full-roster-open", true)
        sfpa_install_roster_refresh()
        return r
      end
    end

    -- Admin/event cleanup --------------------------------------------------------

    local function sfpa_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local n = BronzeLFG_DB.signalFireNetwork
      n.events = n.events or {}
      n.eventDismissed = n.eventDismissed or {}
      return n
    end

    local function sfpa_remove_event_local(id)
      local n = sfpa_db()
      id = sfpa_trim(id or "")
      if id == "" or sfpa_low(id) == "all" then
        n.events = {}
        n.eventDismissed = {}
        return true
      end
      n.eventDismissed[id] = true
      for i = #(n.events or {}), 1, -1 do
        local row = n.events[i]
        if row and tostring(row.id or "") == id then table.remove(n.events, i) end
      end
      if BLFG then BLFG.sfeSelectedEventId = nil end
      return true
    end

    local function sfpa_purge_legacy_seed()
      local n = sfpa_db()
      local removed = 0
      for i = #(n.events or {}), 1, -1 do
        local row = n.events[i]
        local id = tostring((row and row.id) or "")
        local host = sfpa_key((row and (row.host or row.owner or row.leader or row.name)) or "")
        local title = sfpa_low((row and (row.title or row.name or row.activity or row.note)) or "")
        local legacySeed = false
        if id == "welcome-140-event" then legacySeed = true end
        if host == "hsoj" and string.find(title, "tbc keys tonight", 1, true) then legacySeed = true end
        if legacySeed then
          table.remove(n.events, i)
          if id ~= "" then n.eventDismissed[id] = true end
          removed = removed + 1
        end
      end
      n.seeded140 = true
      if removed > 0 and BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      return removed
    end

    function SFPA.AdminClearEvent(id, quiet)
      if not SFPA.IsCurrentAdmin() then
        if not quiet then sfpa_msg("Only a SignalFire admin alias can master-clear events.", 1, .35, .35) end
        return false
      end
      id = sfpa_trim(id or "")
      if id == "" and BLFG then id = tostring(BLFG.sfeSelectedEventId or "") end
      if id == "" then
        if not quiet then sfpa_msg("Select an event first, or use /sf events clearall.", 1, .82, .35) end
        return false
      end
      sfpa_remove_event_local(id)
      sfpa_send(table.concat({PREFIX, "EVENTCLEAR", sfpa_player(), tostring(sfpa_now()), id}, "~"))
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      if not quiet then
        sfpa_msg(sfpa_low(id) == "all" and "Admin cleared all SignalFire events." or "Admin cleared SignalFire event.", .4, 1, .4)
      end
      return true
    end

    function SFPA.HandleEventClear(msgText, author)
      local raw = tostring(msgText or "")
      if string.sub(raw, 1, string.len(PREFIX) + 1) ~= (PREFIX .. "~") then return false end
      local p = sfpa_split(raw)
      if p[1] ~= PREFIX or p[2] ~= "EVENTCLEAR" then return false end
      local payloadAuthor = p[3] or ""
      local clearAuthor = author or ""
      if not (SFPA.IsAdminName(clearAuthor) or SFPA.IsAdminName(payloadAuthor)) then return false end
      local target = sfpa_trim(p[5] or "ALL")
      if target == "" then target = "ALL" end
      sfpa_remove_event_local(target)
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      return true
    end

    local function sfpa_patch_event_rows()
      local f = BLFG and BLFG.sfeEventPanel
      if not f or not f.rows then return end
      for _, rowBtn in ipairs(f.rows or {}) do
        if rowBtn and not rowBtn._sfpaAdminPatched then
          rowBtn._sfpaAdminPatched = true
          local oldClick = rowBtn:GetScript("OnClick")
          rowBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.sfeRow and SFPA.IsCurrentAdmin() then
              SFPA.AdminClearEvent(self.sfeRow.id)
              return
            end
            if oldClick then return oldClick(self, button) end
          end)
          local oldEnter = rowBtn:GetScript("OnEnter")
          rowBtn:SetScript("OnEnter", function(self)
            if oldEnter then oldEnter(self) end
            if self.sfeRow and SFPA.IsCurrentAdmin() and GameTooltip then
              GameTooltip:AddLine("Admin: right-click to clear this event for everyone.", .4, 1, .4)
              GameTooltip:Show()
            end
          end)
        end
      end
    end

    local SFPA_OldSFERefresh = BLFG.SFE_RefreshEventBoard
    if SFPA_OldSFERefresh then
      function BLFG:SFE_RefreshEventBoard(...)
        sfpa_purge_legacy_seed()
        local r = SFPA_OldSFERefresh(self, ...)
        sfpa_patch_event_rows()
        return r
      end
    end

    local oldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"]
    local oldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"]
    local function sfpa_slash(input)
      input = sfpa_trim(input or "")
      local cmd, rest = string.match(input, "^(%S+)%s*(.-)$")
      cmd = sfpa_low(cmd or "")
      local restLow = sfpa_low(rest or "")

      if cmd == "presence" or cmd == "pingnet" then
        SFPA.RequestPresence("slash", true)
        sfpa_msg("SignalFire presence request sent.", .4, 1, .4)
        return true
      end

      if cmd == "admin" then
        sfpa_msg("SignalFire admin alias active: " .. tostring(SFPA.IsCurrentAdmin()) .. " (character: " .. sfpa_player() .. ")")
        return true
      end

      if cmd == "events" or cmd == "event" then
        if restLow == "adminclear" or restLow == "clearselected" then
          SFPA.AdminClearEvent(nil)
          return true
        end
        if restLow == "purgelegacy" or restLow == "purge legacy" then
          local removed = sfpa_purge_legacy_seed()
          sfpa_msg("Purged " .. tostring(removed) .. " legacy seeded event(s).", .4, 1, .4)
          return true
        end
        if (restLow == "clearall" or restLow == "masterclear") and SFPA.IsCurrentAdmin() then
          SFPA.AdminClearEvent("ALL")
          return true
        end
      end
      return false
    end

    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sfpa_slash(input) then return end
        if oldSlashSF then return oldSlashSF(input) end
        if oldSlashBLFG then return oldSlashBLFG(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sfpa_slash(input) then return end
        if oldSlashBLFG then return oldSlashBLFG(input) end
      end
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHAT_MSG_CHANNEL")
    frame:SetScript("OnEvent", function(self, event, msgText, author)
      if event == "CHAT_MSG_CHANNEL" then
        local raw = tostring(msgText or "")
        if string.sub(raw, 1, string.len(PREFIX) + 1) ~= (PREFIX .. "~") then return end
        local p = sfpa_split(raw)
        if p[1] ~= PREFIX then return end
        if p[2] == "SFNREQ" then SFPA.HandlePresenceRequest(author, p[3]); return end
        if p[2] == "EVENTCLEAR" then SFPA.HandleEventClear(raw, author); return end
        return
      end

      sfpa_after(1.5, function()
        sfpa_purge_legacy_seed()
        SFPA.SendOwnPresence()
      end)
      sfpa_after(3.0, function()
        SFPA.RequestPresence("login", true)
      end)
    end)
    local sfpa_tick = 0
    frame:SetScript("OnUpdate", function(self, elapsed)
      local now = sfpa_now()
      for i = #scheduled, 1, -1 do
        local item = scheduled[i]
        if item and now >= (item.t or 0) then
          table.remove(scheduled, i)
          if item.fn then item.fn() end
        end
      end

      sfpa_tick = sfpa_tick + (tonumber(elapsed) or 0)
      if sfpa_tick < 1 then return end
      sfpa_tick = 0

      local networkVisible = BLFG and BLFG.sfnPanel and BLFG.sfnPanel:IsVisible()
      local rosterVisible = BLFG and BLFG.onlinePanel and BLFG.onlinePanel:IsVisible()
      if not networkVisible and not rosterVisible then
        if BLFG then BLFG._sfnNextAutoRefresh = nil end
        return
      end

      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local interval = tonumber(BronzeLFG_DB.signalFireNetwork.autoRefreshSeconds or 30) or 30
      if interval ~= 0 and interval ~= 15 and interval ~= 30 and interval ~= 60 then interval = 30 end

      if interval > 0 then
        BLFG._sfnNextAutoRefresh = tonumber(BLFG._sfnNextAutoRefresh or (now + interval)) or (now + interval)
        if now >= BLFG._sfnNextAutoRefresh then
          BLFG._sfnNextAutoRefresh = now + interval
          SFPA.RequestPresence("auto-refresh")
        end
      end

      if networkVisible and BLFG.sfnUpdated then
        local pending = tonumber(BLFG._sfnPresenceRefreshPending or 0) or 0
        local response = tonumber(BLFG._sfnLastPresenceResponse or 0) or 0
        if pending > 0 and (now - pending) <= 5 then
          BLFG.sfnUpdated:SetText("Refreshing network...")
          BLFG.sfnUpdated:SetTextColor(1, .82, .25)
        elseif response > 0 then
          BLFG.sfnUpdated:SetText("Last response: " .. tostring(math.max(0, now - response)) .. "s ago")
          BLFG.sfnUpdated:SetTextColor(.4, 1, .4)
        else
          BLFG.sfnUpdated:SetText("No responses received yet")
          BLFG.sfnUpdated:SetTextColor(.8, .8, .8)
        end
      end

      BLFG._sfnLastMaintenanceRefresh = tonumber(BLFG._sfnLastMaintenanceRefresh or 0) or 0
      if (now - BLFG._sfnLastMaintenanceRefresh) >= 15 then
        BLFG._sfnLastMaintenanceRefresh = now
        if networkVisible then
          if BLFG.SF151_RequestPanelRefresh then BLFG:SF151_RequestPanelRefresh("network")
          elseif BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        end
        if rosterVisible then
          if BLFG.SF151_RequestPanelRefresh then BLFG:SF151_RequestPanelRefresh("roster")
          elseif BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
        end
      end
    end)
  until true
end
