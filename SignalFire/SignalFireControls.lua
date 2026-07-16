-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Command aliases
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireCommandAliases = SignalFireCommandAliases or {}
    local SFCA = SignalFireCommandAliases

    local PREFIX = "BLFG312"
    local CHANNEL = "BLFG"

    local function sfca_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfca_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfca_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfca_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfca_time()
      return (time and time()) or 0
    end

    local function sfca_send(payload)
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

    local function sfca_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local n = BronzeLFG_DB.signalFireNetwork
      n.events = n.events or {}
      n.eventDismissed = n.eventDismissed or {}
      return n
    end

    local function sfca_is_admin()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.IsCurrentAdmin then return PA.IsCurrentAdmin() end
      local B = _G.BronzeLFG
      if B and B.SF_IsCurrentAdmin then return B:SF_IsCurrentAdmin() end
      return false
    end

    local function sfca_request_presence()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.RequestPresence then
        PA.RequestPresence("alias", true)
      else
        if BLFG and BLFG.SendPresence then BLFG:SendPresence() end
        if BLFG and BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
      end
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfca_msg("SignalFire presence request sent.", .4, 1, .4)
    end

    local function sfca_admin_status()
      sfca_msg("SignalFire admin alias active: " .. tostring(sfca_is_admin()) .. " (character: " .. sfca_player() .. ")")
    end

    local function sfca_admin_clear_selected()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.AdminClearEvent then
        PA.AdminClearEvent(nil)
        return
      end
      sfca_msg("Admin clear is unavailable until SignalFirePresenceAdminFix loads.", 1, .35, .35)
    end

    local function sfca_admin_clear_all()
      if not sfca_is_admin() then
        sfca_msg("Only a SignalFire admin alias can master-clear events.", 1, .35, .35)
        return
      end
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.AdminClearEvent then
        PA.AdminClearEvent("ALL")
        return
      end
      local n = sfca_db()
      n.events = {}
      n.eventDismissed = {}
      sfca_send(table.concat({PREFIX, "EVENTCLEAR", sfca_player(), tostring(sfca_time()), "ALL"}, "~"))
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfca_msg("Admin cleared all SignalFire events.", .4, 1, .4)
    end

    local function sfca_purge_legacy()
      local n = sfca_db()
      local removed = 0
      for i = #(n.events or {}), 1, -1 do
        local row = n.events[i]
        local id = tostring((row and row.id) or "")
        local host = sfca_low((row and (row.host or row.owner or row.leader)) or "")
        local title = sfca_low((row and (row.title or row.name)) or "")
        -- The old demo seed used this exact id/title/host. Keep the match narrow so
        -- real player-created events are not removed accidentally.
        if id == "welcome-140-event" or (host == "hsoj" and string.find(title, "tbc keys tonight", 1, true)) then
          table.remove(n.events, i)
          if id ~= "" then n.eventDismissed[id] = true end
          removed = removed + 1
        end
      end
      n.seeded140 = true
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfca_msg("Purged " .. tostring(removed) .. " legacy seeded event(s).", .4, 1, .4)
    end

    local function sfca_help()
      sfca_msg("Utility aliases: /sfp, /sfa, /sfac, /sfpl, /sfce or /sf presence/admin/purgelegacy")
    end

    function SFCA.Dispatch(kind, input)
      kind = sfca_low(kind or "")
      input = sfca_low(sfca_trim(input or ""))

      if kind == "presence" or kind == "ping" then sfca_request_presence(); return true end
      if kind == "admin" then sfca_admin_status(); return true end
      if kind == "adminclear" then sfca_admin_clear_selected(); return true end
      if kind == "clearall" then sfca_admin_clear_all(); return true end
      if kind == "purgelegacy" then sfca_purge_legacy(); return true end
      if kind == "help" or kind == "cmds" then sfca_help(); return true end

      if kind == "events" then
        if input == "" or input == "help" then sfca_help(); return true end
        if input == "adminclear" or input == "clearselected" then sfca_admin_clear_selected(); return true end
        if input == "clearall" or input == "masterclear" then sfca_admin_clear_all(); return true end
        if input == "purgelegacy" or input == "purge legacy" then sfca_purge_legacy(); return true end
        sfca_help(); return true
      end

      sfca_help()
      return true
    end

    function SFCA.Install()
      if not SlashCmdList then return end

      SLASH_SIGNALFIREPRESENCE1 = "/sfpresence"
      SLASH_SIGNALFIREPRESENCE2 = "/sfpingnet"
      SLASH_SIGNALFIREPRESENCE3 = "/sfp"
      SlashCmdList["SIGNALFIREPRESENCE"] = function(input) SFCA.Dispatch("presence", input) end

      SLASH_SIGNALFIREADMIN1 = "/sfadmin"
      SLASH_SIGNALFIREADMIN2 = "/sfa"
      SlashCmdList["SIGNALFIREADMIN"] = function(input) SFCA.Dispatch("admin", input) end

      SLASH_SIGNALFIREADMINCLEAR1 = "/sfadminclear"
      SLASH_SIGNALFIREADMINCLEAR2 = "/sfac"
      SlashCmdList["SIGNALFIREADMINCLEAR"] = function(input) SFCA.Dispatch("adminclear", input) end

      SLASH_SIGNALFIREPURGELEGACY1 = "/sfpurgelegacy"
      SLASH_SIGNALFIREPURGELEGACY2 = "/sfclearlegacy"
      SLASH_SIGNALFIREPURGELEGACY3 = "/sfpl"
      SlashCmdList["SIGNALFIREPURGELEGACY"] = function(input) SFCA.Dispatch("purgelegacy", input) end

      SLASH_SIGNALFIRECLEARALLEVENTS1 = "/sfclearallevents"
      SLASH_SIGNALFIRECLEARALLEVENTS2 = "/sfmasterclearevents"
      SLASH_SIGNALFIRECLEARALLEVENTS3 = "/sfce"
      SlashCmdList["SIGNALFIRECLEARALLEVENTS"] = function(input) SFCA.Dispatch("clearall", input) end

      SLASH_SIGNALFIREEVENTALIASES1 = "/sfevents"
      SlashCmdList["SIGNALFIREEVENTALIASES"] = function(input) SFCA.Dispatch("events", input) end

      SLASH_SIGNALFIRECMDS1 = "/sfcmds"
      SlashCmdList["SIGNALFIRECMDS"] = function(input) SFCA.Dispatch("help", input) end

      if ChatFrame_ImportListToHash then
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREPRESENCE")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREADMIN")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREADMINCLEAR")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREPURGELEGACY")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRECLEARALLEVENTS")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIREEVENTALIASES")
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRECMDS")
      end
      if ChatFrame_ImportAllLists then pcall(ChatFrame_ImportAllLists) end

      if hash_SlashCmdList then
        local map = {
          {"/sfpresence", "SIGNALFIREPRESENCE"}, {"/SFPRESENCE", "SIGNALFIREPRESENCE"}, {"/sfp", "SIGNALFIREPRESENCE"}, {"/SFP", "SIGNALFIREPRESENCE"}, {"sfp", "SIGNALFIREPRESENCE"},
          {"/sfpingnet", "SIGNALFIREPRESENCE"}, {"/SFPINGNET", "SIGNALFIREPRESENCE"},
          {"/sfadmin", "SIGNALFIREADMIN"}, {"/SFADMIN", "SIGNALFIREADMIN"}, {"/sfa", "SIGNALFIREADMIN"}, {"/SFA", "SIGNALFIREADMIN"}, {"sfa", "SIGNALFIREADMIN"},
          {"/sfadminclear", "SIGNALFIREADMINCLEAR"}, {"/SFADMINCLEAR", "SIGNALFIREADMINCLEAR"}, {"/sfac", "SIGNALFIREADMINCLEAR"}, {"/SFAC", "SIGNALFIREADMINCLEAR"}, {"sfac", "SIGNALFIREADMINCLEAR"},
          {"/sfpurgelegacy", "SIGNALFIREPURGELEGACY"}, {"/SFPURGELEGACY", "SIGNALFIREPURGELEGACY"}, {"/sfpl", "SIGNALFIREPURGELEGACY"}, {"/SFPL", "SIGNALFIREPURGELEGACY"}, {"sfpl", "SIGNALFIREPURGELEGACY"},
          {"/sfclearlegacy", "SIGNALFIREPURGELEGACY"}, {"/SFCLEARLEGACY", "SIGNALFIREPURGELEGACY"},
          {"/sfclearallevents", "SIGNALFIRECLEARALLEVENTS"}, {"/SFCLEARALLEVENTS", "SIGNALFIRECLEARALLEVENTS"}, {"/sfce", "SIGNALFIRECLEARALLEVENTS"}, {"/SFCE", "SIGNALFIRECLEARALLEVENTS"}, {"sfce", "SIGNALFIRECLEARALLEVENTS"},
          {"/sfmasterclearevents", "SIGNALFIRECLEARALLEVENTS"}, {"/SFMASTERCLEAREVENTS", "SIGNALFIRECLEARALLEVENTS"},
          {"/sfevents", "SIGNALFIREEVENTALIASES"}, {"/SFEVENTS", "SIGNALFIREEVENTALIASES"},
          {"/sfcmds", "SIGNALFIRECMDS"}, {"/SFCMDS", "SIGNALFIRECMDS"},
        }
        for _, row in ipairs(map) do
          local fn = SlashCmdList and SlashCmdList[row[2]]
          if type(fn) == "function" then
            hash_SlashCmdList[row[1]] = fn
            if hash_SecureCmdList then hash_SecureCmdList[row[1]] = fn end
          end
        end
      end
    end

    SFCA.Install()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function() SFCA.Install() end)
  until true
end

-- Utility interface
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireUtilityUI = SignalFireUtilityUI or {}
    local SFU = SignalFireUtilityUI

    local PREFIX = "BLFG312"
    local CHANNEL = "BLFG"

    local ADMIN_ALIASES = {
      hsoj = true,
      hs0j = true,
      aesri = true,
    }

    local function sfu_now()
      return (time and time()) or 0
    end

    local function sfu_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfu_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfu_key(name)
      name = sfu_low(sfu_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      name = string.gsub(name, "[^a-z0-9]", "")
      return name
    end

    local function sfu_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfu_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfu_send(payload)
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

    function SFU.IsAdminName(name)
      return ADMIN_ALIASES[sfu_key(name or "")] == true
    end

    function SFU.IsCurrentAdmin()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.IsCurrentAdmin then return PA.IsCurrentAdmin() == true end
      return SFU.IsAdminName(sfu_player())
    end

    local function sfu_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local n = BronzeLFG_DB.signalFireNetwork
      n.events = n.events or {}
      n.eventDismissed = n.eventDismissed or {}
      return n
    end

    local function sfu_event_id(row)
      return tostring((row and row.id) or "")
    end

    local function sfu_event_title_blob(row)
      if not row then return "" end
      return sfu_low(table.concat({
        tostring(row.title or ""), tostring(row.name or ""), tostring(row.activity or ""),
        tostring(row.description or ""), tostring(row.note or ""), tostring(row.type or ""),
      }, " "))
    end

    local function sfu_event_host_key(row)
      if not row then return "" end
      return sfu_key(row.host or row.owner or row.leader or row.sender or row.author or row.name or "")
    end

    local function sfu_is_legacy_seed(row)
      local id = sfu_event_id(row)
      local host = sfu_event_host_key(row)
      local blob = sfu_event_title_blob(row)
      if id == "welcome-140-event" then return true end
      if (host == "hsoj" or host == "hs0j") and string.find(blob, "tbc keys tonight", 1, true) then return true end
      -- Extra narrow fallback for the original seeded demo event, in case old builds
      -- stored the title/body under a different field.
      if string.find(blob, "tbc keys tonight", 1, true) and string.find(blob, "need dps", 1, true) then return true end
      return false
    end

    function SFU.PurgeLegacy(quiet)
      local n = sfu_db()
      local removed = 0
      local clearedIds = {}
      for i = #(n.events or {}), 1, -1 do
        local row = n.events[i]
        if sfu_is_legacy_seed(row) then
          local id = sfu_event_id(row)
          table.remove(n.events, i)
          if id ~= "" then
            n.eventDismissed[id] = true
            table.insert(clearedIds, id)
          end
          removed = removed + 1
        end
      end
      n.seeded140 = true
      n._sfLegacyPurged = true
      if BLFG then BLFG.sfeSelectedEventId = nil end
      if removed > 0 then
        for _, id in ipairs(clearedIds) do
          sfu_send(table.concat({PREFIX, "EVENTCLEAR", sfu_player(), tostring(sfu_now()), id}, "~"))
        end
        if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        if not quiet then sfu_msg("Cleared " .. tostring(removed) .. " legacy seeded event(s).", .4, 1, .4) end
      elseif not quiet then
        sfu_msg("No legacy seeded events found.", .8, .8, .8)
      end
      return removed
    end

    local function sfu_remove_local(id)
      local n = sfu_db()
      id = sfu_trim(id or "")
      if id == "" then return false end
      if sfu_low(id) == "all" then
        n.events = {}
        n.eventDismissed = {}
        BLFG.sfeSelectedEventId = nil
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

    function SFU.AdminClear(id, quiet)
      if not SFU.IsCurrentAdmin() then
        if not quiet then sfu_msg("Only a SignalFire admin alias can clear events globally.", 1, .35, .35) end
        return false
      end
      id = sfu_trim(id or "")
      if id == "" and BLFG then id = tostring(BLFG.sfeSelectedEventId or "") end
      if id == "" then
        if not quiet then sfu_msg("Select an event first, then use Admin Clear Selected.", 1, .82, .35) end
        return false
      end
      sfu_remove_local(id)
      sfu_send(table.concat({PREFIX, "EVENTCLEAR", sfu_player(), tostring(sfu_now()), id}, "~"))
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      if not quiet then
        sfu_msg(sfu_low(id) == "all" and "Admin cleared all SignalFire events." or "Admin cleared selected SignalFire event.", .4, 1, .4)
      end
      return true
    end

    function SFU.RequestPresence()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.RequestPresence then
        PA.RequestPresence("ui-button", true)
      else
        if BLFG and BLFG.SendPresence then BLFG:SendPresence() end
        if BLFG and BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
      end
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfu_msg("SignalFire presence refresh requested.", .4, 1, .4)
    end

    local function sfu_backdrop(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=2,right=2,top=2,bottom=2}
      })
      frame:SetBackdropColor(0,0,0,alpha or .82)
      frame:SetBackdropBorderColor(.85,.62,.12,.85)
    end

    local function sfu_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      if size and fs.SetFont then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
      return fs
    end

    local function sfu_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent)
      b:SetWidth(w or 88); b:SetHeight(h or 20)
      b:EnableMouse(true)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      sfu_backdrop(b, .86)
      b.label = sfu_font(b, text or "Button", 9, 1, .82, 0)
      b.label:SetPoint("CENTER")
      b:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(.12,.07,.02,.96) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1,.82,.18,1) end
      end)
      b:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then self:SetBackdropColor(0,0,0,.86) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(.85,.62,.12,.85) end
      end)
      b.SetText = function(self, t) if self.label then self.label:SetText(tostring(t or "")) end end
      b.GetText = function(self) return self.label and self.label:GetText() or "" end
      return b
    end

    function SFU.PatchEventBoardUI()
      local f = BLFG and BLFG.sfeEventPanel
      if not f or not f.header then return end
      local isAdmin = SFU.IsCurrentAdmin()

      if not f.sfuPresence then
        f.sfuPresence = sfu_button(f.header, "Ping Users", 80, 18)
        f.sfuPresence:SetPoint("BOTTOMLEFT", f.header, "BOTTOMLEFT", 10, 8)
        f.sfuPresence:SetScript("OnClick", function() SFU.RequestPresence() end)
      end
      f.sfuPresence:Show()

      if not f.sfuLegacy then
        f.sfuLegacy = sfu_button(f.header, "Clear Legacy", 86, 18)
        f.sfuLegacy:SetPoint("BOTTOMRIGHT", f.header, "BOTTOMRIGHT", -10, 8)
        f.sfuLegacy:SetScript("OnClick", function() SFU.PurgeLegacy(false) end)
      end

      if not f.sfuClearSelected then
        f.sfuClearSelected = sfu_button(f.header, "Clear Selected", 96, 18)
        f.sfuClearSelected:SetPoint("RIGHT", f.sfuLegacy, "LEFT", -6, 0)
        f.sfuClearSelected:SetScript("OnClick", function() SFU.AdminClear(nil, false) end)
      end

      if not f.sfuClearAll then
        f.sfuClearAll = sfu_button(f.header, "Clear All", 66, 18)
        f.sfuClearAll:SetPoint("RIGHT", f.sfuClearSelected, "LEFT", -6, 0)
        f.sfuClearAll:SetScript("OnClick", function() SFU.AdminClear("ALL", false) end)
      end

      if isAdmin then
        f.sfuLegacy:Show(); f.sfuClearSelected:Show(); f.sfuClearAll:Show()
      else
        f.sfuLegacy:Hide(); f.sfuClearSelected:Hide(); f.sfuClearAll:Hide()
      end

      -- Keep row right-click admin clearing available without depending on slash commands.
      for _, rowBtn in ipairs(f.rows or {}) do
        if rowBtn and not rowBtn._sfuAdminPatched then
          rowBtn._sfuAdminPatched = true
          local oldClick = rowBtn:GetScript("OnClick")
          rowBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.sfeRow and SFU.IsCurrentAdmin() then
              SFU.AdminClear(self.sfeRow.id, false)
              return
            end
            if oldClick then return oldClick(self, button) end
          end)
          local oldEnter = rowBtn:GetScript("OnEnter")
          rowBtn:SetScript("OnEnter", function(self)
            if oldEnter then oldEnter(self) end
            if self.sfeRow and SFU.IsCurrentAdmin() and GameTooltip then
              GameTooltip:AddLine("Admin: right-click clears this event globally.", .4, 1, .4)
              GameTooltip:Show()
            end
          end)
        end
      end
    end

    -- Command helpers still exist, but they are now wrapped in pcall and are no
    -- longer required for event cleanup.
    function SFU.Dispatch(kind)
      kind = sfu_low(kind or "")
      if kind == "presence" then return SFU.RequestPresence() end
      if kind == "admin" then return sfu_msg("SignalFire admin alias active: " .. tostring(SFU.IsCurrentAdmin()) .. " (character: " .. sfu_player() .. ")") end
      if kind == "purgelegacy" then return SFU.PurgeLegacy(false) end
      if kind == "adminclear" then return SFU.AdminClear(nil, false) end
      if kind == "clearall" then return SFU.AdminClear("ALL", false) end
      sfu_msg("Use the Event Board admin buttons: Ping Users, Clear Legacy, Clear Selected, Clear All.")
    end

    local function sfu_safe(label, fn, ...)
      local ok, err = pcall(fn, ...)
      if not ok then sfu_msg(tostring(label or "action") .. " failed: " .. tostring(err or "unknown error"), 1, .35, .35) end
      return ok
    end

    local oldRefresh = BLFG.SFE_RefreshEventBoard
    if oldRefresh then
      function BLFG:SFE_RefreshEventBoard(...)
        sfu_safe("Legacy purge", SFU.PurgeLegacy, true)
        local r = oldRefresh(self, ...)
        sfu_safe("Event Board tools", SFU.PatchEventBoardUI)
        return r
      end
    end

    local oldBuild = BLFG.SFE_BuildEventBoard
    if oldBuild then
      function BLFG:SFE_BuildEventBoard(...)
        local r = oldBuild(self, ...)
        sfu_safe("Event Board tools", SFU.PatchEventBoardUI)
        return r
      end
    end

    local oldShowNet = BLFG.ShowSFNetwork
    if oldShowNet then
      function BLFG:ShowSFNetwork(...)
        sfu_safe("Legacy purge", SFU.PurgeLegacy, true)
        local r = oldShowNet(self, ...)
        sfu_safe("Event Board tools", SFU.PatchEventBoardUI)
        return r
      end
    end

    -- If slash commands do reach us, handle them safely. If the client refuses to
    -- submit them, the UI buttons above are the supported path.
    local oldSF = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
    local oldBLFG = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
    local function sfu_slash(input)
      local cmd = sfu_low(sfu_trim(input or ""))
      if cmd == "presence" or cmd == "pingnet" then return sfu_safe("Presence", SFU.Dispatch, "presence") end
      if cmd == "admin" then return sfu_safe("Admin", SFU.Dispatch, "admin") end
      if cmd == "purgelegacy" or cmd == "events purgelegacy" or cmd == "clearlegacy" then return sfu_safe("Legacy purge", SFU.Dispatch, "purgelegacy") end
      if cmd == "adminclear" or cmd == "events adminclear" then return sfu_safe("Admin clear", SFU.Dispatch, "adminclear") end
      if cmd == "clearallevents" or cmd == "events clearall" then return sfu_safe("Clear all", SFU.Dispatch, "clearall") end
      return false
    end

    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sfu_slash(input) then return end
        if oldSF then return oldSF(input) end
        if oldBLFG then return oldBLFG(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sfu_slash(input) then return end
        if oldBLFG then return oldBLFG(input) end
        if oldSF then return oldSF(input) end
      end
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame.elapsed = 0
    frame.count = 0
    frame:SetScript("OnEvent", function()
      sfu_safe("Legacy purge", SFU.PurgeLegacy, true)
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (elapsed or 0)
      if self.elapsed < 2 then return end
      self.elapsed = 0
      self.count = (self.count or 0) + 1
      sfu_safe("Legacy purge", SFU.PurgeLegacy, true)
      sfu_safe("Event Board tools", SFU.PatchEventBoardUI)
      if self.count >= 8 then self:SetScript("OnUpdate", nil) end
    end)


    -- SignalFire 1.4.17 hard-visible utility controls.
    -- Parent tools directly to the Event Board panel at a high frame level so they
    -- cannot disappear behind the embedded header/backdrop or old button layers.
    local function sfu1717_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 78); b:SetHeight(h or 20)
      b:SetText(tostring(text or "Button"))
      b:EnableMouse(true)
      b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      return b
    end

    function SFU.PatchEventBoardUI()
      local f = BLFG and BLFG.sfeEventPanel
      if not f then return end
      local header = f.header or f
      local baseLevel = (f.GetFrameLevel and f:GetFrameLevel()) or 1
      local isAdmin = SFU.IsCurrentAdmin()

      if not f.sfuTools then
        local tools = CreateFrame("Frame", nil, f)
        f.sfuTools = tools
        tools:SetHeight(24)
        tools:SetWidth(360)
        tools:SetFrameStrata((f.GetFrameStrata and f:GetFrameStrata()) or "DIALOG")
        tools:SetFrameLevel(baseLevel + 250)
        tools:EnableMouse(false)
        -- Explicit fixed placement inside the blank lower half of the Event Board header.
        tools:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -36)

        tools.ping = sfu1717_button(tools, "Ping Users", 76, 20)
        tools.ping:SetPoint("LEFT", tools, "LEFT", 0, 0)
        tools.ping:SetScript("OnClick", function() SFU.RequestPresence() end)

        tools.legacy = sfu1717_button(tools, "Clear Legacy", 88, 20)
        tools.legacy:SetPoint("LEFT", tools.ping, "RIGHT", 6, 0)
        tools.legacy:SetScript("OnClick", function() SFU.PurgeLegacy(false) end)

        tools.selected = sfu1717_button(tools, "Clear Selected", 98, 20)
        tools.selected:SetPoint("LEFT", tools.legacy, "RIGHT", 6, 0)
        tools.selected:SetScript("OnClick", function() SFU.AdminClear(nil, false) end)

        tools.all = sfu1717_button(tools, "Clear All", 70, 20)
        tools.all:SetPoint("LEFT", tools.selected, "RIGHT", 6, 0)
        tools.all:SetScript("OnClick", function() SFU.AdminClear("ALL", false) end)
      end

      local tools = f.sfuTools
      tools:ClearAllPoints()
      tools:SetPoint("TOPLEFT", header, "TOPLEFT", 10, -36)
      tools:SetFrameLevel(baseLevel + 250)
      tools:Show()
      for _, child in ipairs({tools:GetChildren()}) do
        if child and child.SetFrameLevel then child:SetFrameLevel(baseLevel + 255) end
        if child and child.Show then child:Show() end
      end

      -- Ping and Clear Legacy are always visible. Admin-only buttons remain visible
      -- but disabled if the current character is not in the admin alias list, so the
      -- user can tell the controls exist instead of wondering where they went.
      if tools.selected then
        if isAdmin then tools.selected:Enable(); tools.selected:SetAlpha(1) else tools.selected:Disable(); tools.selected:SetAlpha(.45) end
      end
      if tools.all then
        if isAdmin then tools.all:Enable(); tools.all:SetAlpha(1) else tools.all:Disable(); tools.all:SetAlpha(.45) end
      end

      -- Also keep row right-click admin clearing available, but do not rely on it.
      for _, rowBtn in ipairs(f.rows or {}) do
        if rowBtn and not rowBtn._sfuAdminPatched then
          rowBtn._sfuAdminPatched = true
          local oldClick = rowBtn:GetScript("OnClick")
          rowBtn:SetScript("OnClick", function(self, button)
            if button == "RightButton" and self.sfeRow and SFU.IsCurrentAdmin() then
              SFU.AdminClear(self.sfeRow.id, false)
              return
            end
            if oldClick then return oldClick(self, button) end
          end)
        end
      end
    end

    -- Patch the active panel immediately and repeatedly for a few seconds because
    -- old Network/Event Board code can rebuild or restack pieces after login/open.
    do
      local f2 = CreateFrame("Frame")
      f2.elapsed = 0
      f2.count = 0
      f2:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < .5 then return end
        self.elapsed = 0
        self.count = (self.count or 0) + 1
        if BLFG and BLFG.sfeEventPanel then sfu_safe("Event Board hard tools", SFU.PatchEventBoardUI) end
        if self.count >= 20 then self:SetScript("OnUpdate", nil) end
      end)
    end

    -- SignalFire 1.4.19: UtilityUI must not draw a second Event/Notice tool row.
    -- SignalFireEvents140.lua now owns the native header buttons.  Keep the utility
    -- functions (PurgeLegacy/AdminClear/RequestPresence) for those buttons, but make
    -- this late overlay a no-op so it cannot overlap Notice Board controls.
    function SFU.PatchEventBoardUI()
      local f = BLFG and BLFG.sfeEventPanel
      if not f then return end
      if f.sfuTools then f.sfuTools:Hide() end
      if f.sfuPresence then f.sfuPresence:Hide() end
      if f.sfuLegacy then f.sfuLegacy:Hide() end
      if f.sfuClearSelected then f.sfuClearSelected:Hide() end
      if f.sfuClearAll then f.sfuClearAll:Hide() end
    end
  until true
end

-- Version ownership
do
  repeat
    local function sfv1434a_apply()
      if BronzeLFG_ApplyVisibleVersion then BronzeLFG_ApplyVisibleVersion() end
    end

    local function sfv1434a_patch_profile_brand()
      if not BronzeLFG or BronzeLFG.SFVersionFinalizer1434aPatched then return end
      BronzeLFG.SFVersionFinalizer1434aPatched = true
      local old = BronzeLFG.SF143_UpdateServerBrand
      BronzeLFG.SF143_UpdateServerBrand = function(self, ...)
        local r
        if old then r = old(self, ...) end
        sfv1434a_apply()
        return r
      end
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
      sfv1434a_patch_profile_brand()
      sfv1434a_apply()
    end)

    sfv1434a_patch_profile_brand()
    sfv1434a_apply()
  until true
end

-- Command compatibility
do
  repeat
    SignalFireSlashHashFix = SignalFireSlashHashFix or {}

    function SignalFireSlashHashFix_Apply()
      if not SlashCmdList then return end

      local function setSlash(cmd, key)
        local fn = SlashCmdList and SlashCmdList[key]
        if type(fn) ~= "function" then return end
        if hash_SlashCmdList then hash_SlashCmdList[cmd] = fn end
        if hash_SecureCmdList then hash_SecureCmdList[cmd] = fn end
      end

      setSlash("/sf", "SIGNALFIRE")
      setSlash("/SF", "SIGNALFIRE")
      setSlash("/signalfire", "SIGNALFIRE")
      setSlash("/SIGNALFIRE", "SIGNALFIRE")
      setSlash("/sfo", "SIGNALFIRE")
      setSlash("/SFO", "SIGNALFIRE")

      setSlash("/blfg", "BRONZELFG")
      setSlash("/BLFG", "BRONZELFG")
      setSlash("/bronzelfg", "BRONZELFG")
      setSlash("/BRONZELFG", "BRONZELFG")

      setSlash("/sfmodules", "SIGNALFIREMODULES")
      setSlash("/SFMODULES", "SIGNALFIREMODULES")
      setSlash("/sfm", "SIGNALFIREMODULES")
      setSlash("/SFM", "SIGNALFIREMODULES")

      setSlash("/sfslash", "SIGNALFIRESLASHDEBUG")
      setSlash("/SFSLASH", "SIGNALFIRESLASHDEBUG")

      setSlash("/sfp", "SIGNALFIREPRESENCEFINAL")
      setSlash("/SFP", "SIGNALFIREPRESENCEFINAL")
      setSlash("/sfpresence", "SIGNALFIREPRESENCEFINAL")
      setSlash("/SFPRESENCE", "SIGNALFIREPRESENCEFINAL")

      setSlash("/sfa", "SIGNALFIREADMINFINAL")
      setSlash("/SFA", "SIGNALFIREADMINFINAL")
      setSlash("/sfadmin", "SIGNALFIREADMINFINAL")
      setSlash("/SFADMIN", "SIGNALFIREADMINFINAL")

      setSlash("/sfac", "SIGNALFIREADMINCLEARFINAL")
      setSlash("/SFAC", "SIGNALFIREADMINCLEARFINAL")
      setSlash("/sfadminclear", "SIGNALFIREADMINCLEARFINAL")
      setSlash("/SFADMINCLEAR", "SIGNALFIREADMINCLEARFINAL")

      setSlash("/sfpl", "SIGNALFIREPURGEFINAL")
      setSlash("/SFPL", "SIGNALFIREPURGEFINAL")
      setSlash("/sfpurgelegacy", "SIGNALFIREPURGEFINAL")
      setSlash("/SFPURGELEGACY", "SIGNALFIREPURGEFINAL")
      setSlash("/sfclearlegacy", "SIGNALFIREPURGEFINAL")
      setSlash("/SFCLEARLEGACY", "SIGNALFIREPURGEFINAL")

      setSlash("/sfce", "SIGNALFIRECLEARALLFINAL")
      setSlash("/SFCE", "SIGNALFIRECLEARALLFINAL")
      setSlash("/sfclearallevents", "SIGNALFIRECLEARALLFINAL")
      setSlash("/SFCLEARALLEVENTS", "SIGNALFIRECLEARALLFINAL")
    end

    SignalFireSlashHashFix_Apply()

    local f = CreateFrame and CreateFrame("Frame")
    if f then
      f:RegisterEvent("ADDON_LOADED")
      f:RegisterEvent("PLAYER_LOGIN")
      f:RegisterEvent("PLAYER_ENTERING_WORLD")
      f.elapsed = 0
      f.ticks = 0
      f:SetScript("OnEvent", function(self, event, addon)
        if event == "ADDON_LOADED" and addon and addon ~= "SignalFire" and addon ~= "BronzeLFG" then return end
        SignalFireSlashHashFix_Apply()
      end)
      f:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < 0.75 then return end
        self.elapsed = 0
        self.ticks = (self.ticks or 0) + 1
        SignalFireSlashHashFix_Apply()
        if self.ticks >= 8 then self:SetScript("OnUpdate", nil) end
      end)
    end
  until true
end

