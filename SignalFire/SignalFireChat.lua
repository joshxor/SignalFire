-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Chat rendering guard
do
  repeat
    local function sfcls_now()
      if now then return now() end
      if time then return time() end
      return 0
    end

    local function sfcls_public_key(author, text)
      local name = tostring(author or ""):gsub("%-.*", "")
      return name .. "\031" .. tostring(text or "")
    end

    local function sfcls_has_signalfire_link(text)
      local raw = tostring(text or "")
      return raw:find("bronzelfgpub:", 1, true)
        or raw:find("bronzelfgguild:", 1, true)
        or raw:find("|Hbronzelfg", 1, true)
    end

    local function sfcls_has_public_signal(text)
      local raw = tostring(text or "")
      local s = " " .. string.lower(raw) .. " "
      if s == "  " then return false end
      local guildSeeking = s:find(" guild", 1, true)
        and (s:find(" lf guild", 1, true) or s:find(" lf a guild", 1, true) or s:find(" lfm", 1, true) or s:find(" lfg", 1, true) or s:find(" looking for", 1, true)
          or s:find(" seeking ", 1, true) or s:find(" need a guild", 1, true) or s:find(" want a guild", 1, true)
          or s:find(" any guild", 1, true) or s:find(" guild pls", 1, true) or s:find(" guild please", 1, true))
      local guildRecruiting = s:find(" recruit", 1, true) or s:find(" recruitment", 1, true)
        or s:find(" looking for members", 1, true) or s:find(" seeking members", 1, true)
        or s:find(" accepting members", 1, true) or s:find(" join us", 1, true)
        or s:find(" join our", 1, true) or raw:find("<[^>]+>")
      if guildSeeking and not guildRecruiting then return false end
      if s:find("lfm", 1, true) or s:find("lfg", 1, true) or s:find(" lf ", 1, true) then return true end
      if s:find("looking for", 1, true) or s:find("need ", 1, true) then return true end
      if s:find("tank", 1, true) or s:find("heal", 1, true) or s:find("dps", 1, true) then return true end
      if s:find("key", 1, true) or s:find("keystone", 1, true) or s:find("mythic", 1, true) then return true end
      if s:find("rdf", 1, true) or s:find("random dungeon", 1, true) or s:find("queue", 1, true) then return true end
      if s:find("boss blitz", 1, true) or s:find("hcbb", 1, true) or s:find("bbhc", 1, true) then return true end
      if s:find("last spot", 1, true) or s:find("invasion", 1, true) then return true end
      if s:find("recruit", 1, true) or s:find("guild", 1, true) or s:find("discord", 1, true) then return true end
      if s:find("lf%d+m") then return true end
      return false
    end

    local function sfcls_mark_seen(self, author, text)
      if not self then return end
      local stamp = sfcls_now()
      local key = self.SignalFirePublicChatKey and self:SignalFirePublicChatKey(author, text) or sfcls_public_key(author, text)
      self._inlinePublicChatEventSeen = self._inlinePublicChatEventSeen or {}
      self._inlinePublicChatEventSeen[key] = stamp
    end

    local function sfcls_public_panel_visible(self)
      if not self then return false end
      if self.publicPanel and self.publicPanel.IsVisible and self.publicPanel:IsVisible() then return true end
      if self.publicPanel and self.publicPanel.IsShown and self.publicPanel:IsShown() then return true end
      return self.currentTab == "PublicGroups"
    end

    local function sfcls_prune_cache(cache, stamp)
      if not cache then return end
      local scanned = 0
      for key, rec in pairs(cache) do
        scanned = scanned + 1
        if scanned > 80 then break end
        local t = rec and tonumber(rec.t or 0) or 0
        if t <= 0 or (stamp - t) > 10 then cache[key] = nil end
      end
    end

    if BLFG and not BLFG._sfChatLinkStutterFixInstalled then
      BLFG._sfChatLinkStutterFixInstalled = true

      local oldInline = BLFG.InlinePublicChatLinkForMessage
      function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
        local raw = tostring(msgText or "")
        if raw == "" then return nil end

        if sfcls_has_signalfire_link(raw) then
          return nil
        end

        if not sfcls_has_public_signal(raw) then
          local stamp = sfcls_now()
          self._inlinePublicChatCache = self._inlinePublicChatCache or {}
          local key = self.SignalFirePublicChatKey and self:SignalFirePublicChatKey(author, raw) or sfcls_public_key(author, raw)
          self._inlinePublicChatCache[key] = {t=stamp, out=nil}
          sfcls_prune_cache(self._inlinePublicChatCache, stamp)
          return nil
        end

        local out = oldInline and oldInline(self, msgText, author, channelName) or nil
        if out and out ~= raw then
          sfcls_mark_seen(self, author, raw)
        end
        sfcls_prune_cache(self._inlinePublicChatCache, sfcls_now())
        return out
      end

      local oldAddPublicGroup = BLFG.AddPublicGroup
      function BLFG:AddPublicGroup(author, text, channelName)
        local raw = tostring(text or "")
        if raw == "" or sfcls_has_signalfire_link(raw) then return nil end
        if not sfcls_has_public_signal(raw) then return nil end
        return oldAddPublicGroup and oldAddPublicGroup(self, author, text, channelName) or nil
      end

      local oldRequestPublicGroupsRefresh = BLFG.RequestPublicGroupsRefresh
      function BLFG:RequestPublicGroupsRefresh()
        self._publicGroupsDirty = true
        if not sfcls_public_panel_visible(self) then return end
        if oldRequestPublicGroupsRefresh then return oldRequestPublicGroupsRefresh(self) end
        if self.RefreshPublicGroups then return self:RefreshPublicGroups() end
      end
    end

    if type(SF577_BuildRoleComboLink) == "function" and not _G.SF577_BuildRoleComboLink_StutterGuarded then
      _G.SF577_BuildRoleComboLink_StutterGuarded = true
      local oldBuildRoleComboLink = SF577_BuildRoleComboLink
      function SF577_BuildRoleComboLink(raw, author, channelName)
        raw = tostring(raw or "")
        if raw == "" or sfcls_has_signalfire_link(raw) then return nil end

        local B = BLFG or (_G and _G.BronzeLFG)
        local stamp = sfcls_now()
        local key = sfcls_public_key(author, raw)
        if B then
          B._sfDirectLinkCache = B._sfDirectLinkCache or {}
          local cached = B._sfDirectLinkCache[key]
          if cached and cached.t and (stamp - cached.t) <= 2 then return cached.out end
        end

        if not sfcls_has_public_signal(raw) then
          if B then
            B._sfDirectLinkCache[key] = {t=stamp, out=nil}
            sfcls_prune_cache(B._sfDirectLinkCache, stamp)
          end
          return nil
        end

        local out = oldBuildRoleComboLink(raw, author, channelName)
        if out and out ~= raw and B then sfcls_mark_seen(B, author, raw) end
        if B then
          B._sfDirectLinkCache[key] = {t=stamp, out=out}
          sfcls_prune_cache(B._sfDirectLinkCache, stamp)
        end
        return out
      end
    end
  until true
end

-- Command input guard
do
  repeat
    SignalFireSlashFreezeFix = SignalFireSlashFreezeFix or {}

    local function sfsff_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfsff_low(s)
      return string.lower(sfsff_trim(s or ""))
    end

    local function sfsff_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfsff_B()
      return _G.BronzeLFG or BLFG
    end

    local function sfsff_help()
      sfsff_msg("Commands: /sf, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf guild, /sf invasions, /sf modules, /sf options, /sf online, /sf who, /sf testsay on|off")
    end

    local function sfsff_help_true()
      sfsff_help()
      return true
    end

    local function sfsff_call(method, ...)
      local B = sfsff_B()
      if B and B[method] then
        B[method](B, ...)
        return true
      end
      return false
    end

    local function sfsff_show_then(method)
      local B = sfsff_B()
      if not B then return false end
      if B.Show then B:Show() end
      if B[method] then B[method](B); return true end
      return false
    end

    local function sfsff_handle(input)
      local raw = tostring(input or "")
      local cmd = sfsff_low(raw)
      local B = sfsff_B()

      if SignalFireSlashFinal and SignalFireSlashFinal.HandleUtilitySlash and SignalFireSlashFinal.HandleUtilitySlash(cmd) then return true end
      if SignalFireSlashFinal and SignalFireSlashFinal.HandleModuleSlash and SignalFireSlashFinal.HandleModuleSlash(cmd) then return true end
      if SignalFireModules and SignalFireModules.HandleSlash and SignalFireModules.HandleSlash(cmd, nil) then return true end

      if cmd == "" then
        if B and B.ToggleFrame then B:ToggleFrame(); return true end
        if B and B.Toggle then B:Toggle(); return true end
        if B and B.Show then B:Show(); return true end
        return true
      end

      if cmd == "testsay on" then
        if B then B.SignalFireTestSay = true end
        sfsff_msg("/say test mode: ON")
        return true
      end
      if cmd == "testsay off" then
        if B then B.SignalFireTestSay = false end
        sfsff_msg("/say test mode: OFF")
        return true
      end

      if cmd == "help" or cmd == "commands" or cmd == "cmds" then sfsff_help(); return true end
      if cmd == "public" or cmd == "groups" then return sfsff_show_then("ShowPublicGroups") or sfsff_help_true() end
      if cmd == "create" or cmd == "new" then return sfsff_show_then("ShowCreate") or sfsff_help_true() end
      if cmd == "profile" then return sfsff_call("ShowProfile") or sfsff_help_true() end
      if cmd == "applicants" then return sfsff_show_then("ShowApplicants") or sfsff_help_true() end
      if cmd == "my" or cmd == "listing" then return sfsff_show_then("ShowMyListing") or sfsff_help_true() end
      if cmd == "guild" or cmd == "guilds" then return sfsff_show_then("ShowGuildBrowser") or sfsff_help_true() end
      if cmd == "options" or cmd == "settings" then return sfsff_call("ShowOptions") or sfsff_help_true() end
      if cmd == "who" then return sfsff_call("PrintOnlineUsers") or sfsff_help_true() end
      if cmd == "online" then
        if B and B.Show then B:Show() end
        if B and B.ShowPublicGroups then B:ShowPublicGroups() end
        if B and B.ToggleOnlinePanel then B:ToggleOnlinePanel(); return true end
        sfsff_help()
        return true
      end
      if cmd == "guildwho" or cmd == "whoguilds" then return sfsff_call("QueueWhoGuildDiscovery", true) or sfsff_help_true() end
      if cmd == "clearpublic" then return sfsff_call("ClearPublicGroups") or sfsff_help_true() end
      if cmd == "cancel" then return sfsff_call("CancelMyListing", "manual") or sfsff_help_true() end

      if cmd == "invasion" or cmd == "invasions" or cmd == "inv" then
        return sfsff_show_then("ShowInvasions") or sfsff_help_true()
      end
      if cmd == "invbeacon" then
        if B and B.CreateUI then B:CreateUI() end
        return sfsff_call("CreateInvasionBeacon") or sfsff_help_true()
      end
      if cmd == "invclear" then return sfsff_call("ClearInvasionData") or sfsff_help_true() end
      if cmd == "invtarget" or cmd == "invasiontarget" then
        if B and B.CreateUI then B:CreateUI() end
        return sfsff_call("AddCurrentInvasionTarget") or sfsff_help_true()
      end
      if cmd == "invwhisper" or cmd == "invasionwhisper" then return sfsff_call("WhisperSelectedInvasionOtherPlayer") or sfsff_help_true() end
      if cmd == "invinviteother" or cmd == "invasioninvite" then return sfsff_call("InviteSelectedInvasionOtherPlayer") or sfsff_help_true() end

      if B and B.SFN_HandleSlash and (cmd == "announce" or string.sub(cmd, 1, 9) == "announce ") and B:SFN_HandleSlash(raw) then return true end

      sfsff_help()
      return true
    end

    function SignalFireSlashFreezeFix.Apply()
      if not SlashCmdList then return end

      SLASH_SIGNALFIRE1 = "/sf"
      SLASH_SIGNALFIRE2 = "/signalfire"
      SLASH_SIGNALFIRE3 = "/sfo"
      SlashCmdList["SIGNALFIRE"] = sfsff_handle

      SLASH_BRONZELFG1 = "/blfg"
      SLASH_BRONZELFG2 = "/bronzelfg"
      SlashCmdList["BRONZELFG"] = sfsff_handle

      if ChatFrame_ImportListToHash then
        pcall(ChatFrame_ImportListToHash, "SIGNALFIRE")
        pcall(ChatFrame_ImportListToHash, "BRONZELFG")
      end

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
    end

    SignalFireSlashFreezeFix.Apply()

    local sfsff_frame = CreateFrame and CreateFrame("Frame")
    if sfsff_frame then
      sfsff_frame:RegisterEvent("ADDON_LOADED")
      sfsff_frame:RegisterEvent("PLAYER_LOGIN")
      sfsff_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
      sfsff_frame.elapsed = 0
      sfsff_frame.ticks = 0
      sfsff_frame:SetScript("OnEvent", function(self, event, addon)
        if event == "ADDON_LOADED" and addon and addon ~= "SignalFire" and addon ~= "BronzeLFG" then return end
        SignalFireSlashFreezeFix.Apply()
      end)
      sfsff_frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = (self.elapsed or 0) + (elapsed or 0)
        if self.elapsed < 0.75 then return end
        self.elapsed = 0
        self.ticks = (self.ticks or 0) + 1
        SignalFireSlashFreezeFix.Apply()
        if self.ticks >= 8 then self:SetScript("OnUpdate", nil) end
      end)
    end
  until true
end

-- Chat queue
do
  repeat
    SignalFireChatQueueFix = SignalFireChatQueueFix or {}

    local function sfcq_now()
      if now then return now() end
      if time then return time() end
      return 0
    end

    local function sfcq_player()
      return (UnitName and UnitName("player")) or ""
    end

    local function sfcq_clean_author(author)
      return tostring(author or ""):gsub("%-.*", "")
    end

    local function sfcq_key(author, text)
      return sfcq_clean_author(author) .. "\031" .. tostring(text or "")
    end

    local function sfcq_has_signalfire_link(text)
      local raw = tostring(text or "")
      return raw:find("bronzelfgpub:", 1, true)
        or raw:find("bronzelfgguild:", 1, true)
        or raw:find("|Hbronzelfg", 1, true)
    end

    local function sfcq_public_signal(text)
      local raw = tostring(text or "")
      local s = " " .. string.lower(raw) .. " "
      if s == "  " or sfcq_has_signalfire_link(s) then return false end
      local guildSeeking = s:find(" guild", 1, true)
        and (s:find(" lf guild", 1, true) or s:find(" lf a guild", 1, true) or s:find(" lfm", 1, true) or s:find(" lfg", 1, true) or s:find(" looking for", 1, true)
          or s:find(" seeking ", 1, true) or s:find(" need a guild", 1, true) or s:find(" want a guild", 1, true)
          or s:find(" any guild", 1, true) or s:find(" guild pls", 1, true) or s:find(" guild please", 1, true))
      local guildRecruiting = s:find(" recruit", 1, true) or s:find(" recruitment", 1, true)
        or s:find(" looking for members", 1, true) or s:find(" seeking members", 1, true)
        or s:find(" accepting members", 1, true) or s:find(" join us", 1, true)
        or s:find(" join our", 1, true) or raw:find("<[^>]+>")
      if guildSeeking and not guildRecruiting then return false end
      if s:find("kick.com", 1, true) or s:find("twitch.tv", 1, true)
        or s:find("youtube.com", 1, true) or s:find("youtu.be", 1, true) then return false end
      if s:find("lfm", 1, true) or s:find("lfg", 1, true) or s:find(" lf ", 1, true) then return true end
      if s:find("looking for", 1, true) or s:find("need ", 1, true) then return true end
      if s:find("tank", 1, true) or s:find("heal", 1, true) or s:find("dps", 1, true) then return true end
      if s:find("key", 1, true) or s:find("keystone", 1, true) or s:find("mythic", 1, true) then return true end
      if s:find("rdf", 1, true) or s:find("random dungeon", 1, true) or s:find("queue", 1, true) then return true end
      if s:find("boss blitz", 1, true) or s:find("hcbb", 1, true) or s:find("bbhc", 1, true) then return true end
      if s:find("last spot", 1, true) or s:find("invasion", 1, true) then return true end
      if s:find("recruit", 1, true) or s:find("guild", 1, true) or s:find("discord", 1, true) then return true end
      if s:find("lf%d+m") then return true end
      return false
    end

    local function sfcq_remove_filter(event, fn)
      if ChatFrame_RemoveMessageEventFilter and type(fn) == "function" then
        pcall(ChatFrame_RemoveMessageEventFilter, event, fn)
      end
    end

    local function sfcq_disable_inline_filters()
      sfcq_remove_filter("CHAT_MSG_CHANNEL", _G.BLFG_PublicInlineFilter_561)
      sfcq_remove_filter("CHAT_MSG_SAY", _G.BLFG_PublicInlineFilter_561)
      sfcq_remove_filter("CHAT_MSG_YELL", _G.BLFG_PublicInlineFilter_561)
      sfcq_remove_filter("CHAT_MSG_CHANNEL", _G.SF577_RoleComboInlineFilter)
      sfcq_remove_filter("CHAT_MSG_SAY", _G.SF577_RoleComboInlineFilter)
      sfcq_remove_filter("CHAT_MSG_YELL", _G.SF577_RoleComboInlineFilter)

      if type(SF577_BuildRoleComboLink) == "function" and not _G.SF577_BuildRoleComboLink_QueueDisabled then
        _G.SF577_BuildRoleComboLink_QueueDisabled = true
        _G.SF577_BuildRoleComboLink_BeforeQueueFix = SF577_BuildRoleComboLink
        function SF577_BuildRoleComboLink() return nil end
      end
    end

    local function sfcq_mark_seen(B, author, text)
      if not B then return end
      B._inlinePublicChatEventSeen = B._inlinePublicChatEventSeen or {}
      local key = B.SignalFirePublicChatKey and B:SignalFirePublicChatKey(author, text) or sfcq_key(author, text)
      B._inlinePublicChatEventSeen[key] = sfcq_now()
    end

    local function sfcq_prune_seen(map, stamp, maxAge)
      if not map then return end
      local scanned = 0
      for key, t in pairs(map) do
        scanned = scanned + 1
        if scanned > 160 then break end
        if (stamp - (tonumber(t or 0) or 0)) > maxAge then map[key] = nil end
      end
    end

    local function sfcq_row_time(row)
      return tonumber(row and (row.seen or row.created or row.firstSeen) or 0) or 0
    end

    local function sfcq_keep_public_row(row)
      if not row then return false end
      if row.isInvasionBeacon or row.signalFireListing then return true end
      local id = tostring(row.id or row.key or "")
      if id:find("^listing%-") or id:find("^INVASION%-") then return true end
      return false
    end

    local function sfcq_prune_public_groups(B)
      local groups = B and B.publicGroups
      if not groups then return end
      local stamp = sfcq_now()
      local rows, count = {}, 0

      for id, row in pairs(groups) do
        count = count + 1
        local age = stamp - sfcq_row_time(row)
        if not sfcq_keep_public_row(row) and age > 180 then
          groups[id] = nil
          if B.selectedPublic == id then B.selectedPublic = nil end
        else
          table.insert(rows, {id=id, t=sfcq_row_time(row), keep=sfcq_keep_public_row(row)})
        end
      end

      if #rows <= 60 then return end
      table.sort(rows, function(a, b)
        if a.keep ~= b.keep then return a.keep end
        return a.t > b.t
      end)
      for i = 61, #rows do
        local id = rows[i].id
        if id and not rows[i].keep then
          groups[id] = nil
          if B.selectedPublic == id then B.selectedPublic = nil end
        end
      end
    end

    local function sfcq_prune_guild_chat(B)
      local rows = B and B.chatGuildListings
      if not rows then return end
      local stamp = sfcq_now()
      local list = {}
      for key, row in pairs(rows) do
        local t = tonumber(row and (row.lastPostSeen or row.seen or row.created) or 0) or 0
        if t > 0 and (stamp - t) > 300 then
          rows[key] = nil
        else
          table.insert(list, {key=key, t=t})
        end
      end
      if #list <= 60 then return end
      table.sort(list, function(a, b) return a.t > b.t end)
      for i = 61, #list do rows[list[i].key] = nil end
    end

    local function sfcq_prune_state(B)
      if not B then return end
      local stamp = sfcq_now()
      sfcq_prune_seen(B._sfChatParseSeen, stamp, 20)
      sfcq_prune_seen(B._inlinePublicChatEventSeen, stamp, 20)
      sfcq_prune_public_groups(B)
      sfcq_prune_guild_chat(B)
    end

    local function sfcq_panel_visible(B)
      if not B then return false end
      if B.publicPanel and B.publicPanel.IsVisible and B.publicPanel:IsVisible() then return true end
      if B.publicPanel and B.publicPanel.IsShown and B.publicPanel:IsShown() then return true end
      return B.currentTab == "PublicGroups"
    end

    local function sfcq_enqueue(B, author, text, channelName)
      if not B then return nil end
      local raw = tostring(text or "")
      if raw == "" or sfcq_has_signalfire_link(raw) then return nil end
      if not sfcq_public_signal(raw) then return nil end
      if sfcq_clean_author(author) == sfcq_player() and not B.SignalFireTestSay then return nil end

      local stamp = sfcq_now()
      local key = sfcq_key(author, raw)
      B._sfChatParseSeen = B._sfChatParseSeen or {}
      if B._sfChatParseSeen[key] and (stamp - B._sfChatParseSeen[key]) <= 2 then return nil end
      B._sfChatParseSeen[key] = stamp
      sfcq_prune_seen(B._sfChatParseSeen, stamp, 20)

      B._sfChatParseQueue = B._sfChatParseQueue or {}
      while #B._sfChatParseQueue > 20 do table.remove(B._sfChatParseQueue, 1) end
      table.insert(B._sfChatParseQueue, {author=author, text=raw, channel=channelName or "Public", queued=stamp})
      sfcq_mark_seen(B, author, raw)
      if B._sfChatParseFrame then B._sfChatParseFrame:Show() end
      return nil
    end

    local function sfcq_install()
      local B = BLFG or (_G and _G.BronzeLFG)
      if not B or B._sfChatQueueFixInstalled then return end
      B._sfChatQueueFixInstalled = true

      sfcq_disable_inline_filters()

      local oldInline = B.InlinePublicChatLinkForMessage
      function B:InlinePublicChatLinkForMessage(msgText, author, channelName)
        sfcq_enqueue(self, author, msgText, channelName)
        return nil
      end
      B._sfChatQueueOldInline = oldInline

      local oldAddPublicGroup = B.AddPublicGroup
      B._sfChatQueueOldAddPublicGroup = oldAddPublicGroup
      function B:AddPublicGroup(author, text, channelName)
        if self._sfChatQueueProcessing then
          return oldAddPublicGroup and oldAddPublicGroup(self, author, text, channelName) or nil
        end
        return sfcq_enqueue(self, author, text, channelName)
      end

      local oldRequestPublicGroupsRefresh = B.RequestPublicGroupsRefresh
      function B:RequestPublicGroupsRefresh()
        self._publicGroupsDirty = true
        sfcq_prune_state(self)
        if not sfcq_panel_visible(self) then return end
        if oldRequestPublicGroupsRefresh then return oldRequestPublicGroupsRefresh(self) end
        if self.RefreshPublicGroups then return self:RefreshPublicGroups() end
      end

      local oldExpirePublicGroups = B.ExpirePublicGroups
      function B:ExpirePublicGroups(...)
        local r = oldExpirePublicGroups and oldExpirePublicGroups(self, ...)
        sfcq_prune_public_groups(self)
        return r
      end

      B._sfChatParseFrame = CreateFrame and CreateFrame("Frame") or nil
      if B._sfChatParseFrame then
        B._sfChatParseFrame:Hide()
        B._sfChatParseFrame.elapsed = 0
        B._sfChatParseFrame:SetScript("OnUpdate", function(frame, elapsed)
          frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
          if frame.elapsed < 0.08 then return end
          frame.elapsed = 0

          local owner = BLFG or (_G and _G.BronzeLFG)
          local q = owner and owner._sfChatParseQueue
          if not (owner and q and q[1]) then frame:Hide(); return end

          local item = table.remove(q, 1)
          sfcq_prune_state(owner)
          owner._sfChatQueueProcessing = true
          owner._suppressPublicRefreshInChatLink = true
          if owner._sfChatQueueOldAddPublicGroup then
            pcall(owner._sfChatQueueOldAddPublicGroup, owner, item.author, item.text, item.channel)
          end
          if owner.SF151_ReconcilePublicGroups then owner:SF151_ReconcilePublicGroups(item.author, item.text) end
          owner._suppressPublicRefreshInChatLink = nil
          owner._sfChatQueueProcessing = nil
          sfcq_prune_state(owner)

          if not q[1] then frame:Hide() end
        end)
      end
    end

    sfcq_install()

    local sfcq_frame = CreateFrame and CreateFrame("Frame")
    if sfcq_frame then
      sfcq_frame:RegisterEvent("PLAYER_LOGIN")
      sfcq_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
      sfcq_frame:SetScript("OnEvent", function() sfcq_install(); sfcq_disable_inline_filters() end)
    end
  until true
end

-- Chat links
do
  repeat
    SignalFireFastChatLinks = SignalFireFastChatLinks or {}

    local function sffcl_now()
      if now then return now() end
      if time then return time() end
      return 0
    end

    local function sffcl_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sffcl_lower(s)
      return string.lower(tostring(s or ""))
    end

    local function sffcl_clean_text(text)
      local s = tostring(text or "")
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
      s = string.gsub(s, "|h(%b[])|h", "%1")
      s = string.gsub(s, "%s+", " ")
      return sffcl_trim(s)
    end

    local function sffcl_author(author)
      return sffcl_trim(tostring(author or ""):gsub("%-.*", ""))
    end

    local function sffcl_player()
      return sffcl_author((UnitName and UnitName("player")) or "")
    end

    local function sffcl_hash(text)
      local h = 5381
      text = tostring(text or "")
      for i = 1, math.min(string.len(text), 180) do
        h = ((h * 33) + string.byte(text, i)) % 2147483647
      end
      return tostring(h)
    end

    local function sffcl_key(author, text)
      return sffcl_author(author) .. "\031" .. tostring(text or "")
    end

    local function sffcl_has_link(text)
      local raw = tostring(text or "")
      return raw:find("bronzelfgpub:", 1, true)
        or raw:find("bronzelfgguild:", 1, true)
        or raw:find("|Hbronzelfg", 1, true)
    end

    local function sffcl_public_enabled()
      return not (BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.publicGroups == false)
    end

    local function sffcl_is_ascension()
      local B = BLFG or (_G and _G.BronzeLFG)
      if B and B.SF143_GetProfileId then
        local ok, id = pcall(function() return B:SF143_GetProfileId() end)
        if ok then return tostring(id or "") == "Ascension" end
      end
      return BronzeLFG_DB and BronzeLFG_DB.options
        and tostring(BronzeLFG_DB.options.serverProfile or "") == "Ascension"
    end

    local function sffcl_noise_or_trade(text)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      if s == "  " or sffcl_has_link(s) then return false end
      if s:find(" wts ", 1, true) or s:find(" wtb ", 1, true) or s:find(" wtt ", 1, true) then return true end
      if s:find(" sell", 1, true) or s:find(" buying ", 1, true) or s:find(" price ", 1, true) then return true end
      -- Do not treat "leveling" as trade/noise when the same line is clearly a
      -- guild recruitment ad.  Ascension guild ads often say "dungeons, leveling,
      -- and PvP".
      local guildish = s:find("guild", 1, true) or s:find("recruit", 1, true) or s:find("<", 1, true)
      if s:find(" bis ", 1, true) or (s:find(" leveling ", 1, true) and not guildish) or s:find(" boe ", 1, true) then return true end
      if s:find(" craft ", 1, true) or s:find(" crafting ", 1, true) or s:find(" enchant", 1, true) then return true end
      if s:find(" lf craft", 1, true) or s:find(" lf crafter", 1, true) then return true end
      local taggedGuildAd = s:find("<", 1, true) and s:find(">", 1, true)
        and (s:find("consider", 1, true) or s:find("join", 1, true)
          or s:find("recruit", 1, true) or s:find("guild tag", 1, true))
      local guildSeeking = s:find(" guild", 1, true)
        and (s:find(" lf guild", 1, true) or s:find(" lf a guild", 1, true) or s:find(" lfm", 1, true) or s:find(" lfg", 1, true) or s:find(" looking for", 1, true)
          or s:find(" seeking ", 1, true) or s:find(" need a guild", 1, true) or s:find(" want a guild", 1, true)
          or s:find(" any guild", 1, true) or s:find(" a guild", 1, true)
          or s:find(" guild pls", 1, true) or s:find(" guild please", 1, true))
      local guildRecruiting = taggedGuildAd or s:find(" recruit", 1, true) or s:find(" recruitment", 1, true)
        or s:find(" looking for members", 1, true) or s:find(" seeking members", 1, true)
        or s:find(" accepting members", 1, true) or s:find(" join us", 1, true) or s:find(" join our", 1, true)
      if guildSeeking and not guildRecruiting then return true end
      -- Streaming/video promotions are never SignalFire group or guild listings.
      -- Do this before the generic recruitment exception: a personal stream line such
      -- as "kick.com/name ... recruiting" must not become a guild/group link merely
      -- because it contains the word recruiting.
      if s:find("kick.com", 1, true) or s:find("twitch.tv", 1, true)
        or s:find("youtube.com", 1, true) or s:find("youtu.be", 1, true) then
        return true
      end
      -- Ordinary URLs are ignored unless they are clearly guild/community Discord ads.
      if (s:find("http://", 1, true) or s:find("https://", 1, true) or s:find("www.", 1, true))
        and not (s:find("guild", 1, true) or s:find("discord.gg", 1, true) or s:find("discord.com/invite", 1, true)) then
        return true
      end
      return false
    end

    local function sffcl_role_signal(s)
      return s:find(" tank", 1, true) or s:find(" heal", 1, true) or s:find(" healer", 1, true) or s:find(" heals", 1, true) or s:find(" dps", 1, true)
    end

    local function sffcl_activity_signal(s)
      return s:find(" rdf", 1, true) or s:find(" random dungeon", 1, true) or s:find(" dungeon", 1, true)
        or s:find(" dung ", 1, true) or s:find(" df ", 1, true)
        or s:find(" heroic", 1, true) or s:find(" mythic", 1, true) or s:find(" keystone", 1, true)
        or s:find(" key ", 1, true) or s:find(" raid", 1, true) or s:find(" boss blitz", 1, true)
        or s:find(" hcbb", 1, true) or s:find(" bbhc", 1, true) or s:find(" invasion", 1, true)
        or s:find(" de other side", 1, true) or s:find(" other side", 1, true)
        or s:find(" vault ", 1, true) or s:find(" wc ", 1, true)
    end

    local function sffcl_public_signal(text, parsedType, parsedActivity)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      if s == "  " or sffcl_has_link(s) or sffcl_noise_or_trade(s) then return false end

      local activity = tostring(parsedActivity or "")
      local specificActivity = activity ~= "" and activity ~= "Group Listing" and activity ~= "Looking For Group"
      local hasActivity = sffcl_activity_signal(s) or specificActivity
      local hasRole = sffcl_role_signal(s)

      if s:find(" lf%d+m") or s:find(" lfm", 1, true) then return true end
      if s:find(" lfg ", 1, true) and hasActivity then return true end
      if s:find("%slf%s+%d+%s*dps") or s:find("%slf%s+%d+%s*tank") or s:find("%slf%s+%d+%s*heal") then return true end
      if s:find("%slf%s+%d+") and (hasRole or hasActivity) then return true end
      -- CoA chat frequently uses role-first and short LF forms such as
      -- "healer lf Vault", "DPS 56 LF RDF", or "dps LF DF farming grp".
      if s:find("%slf%s+") and (hasRole or hasActivity) then return true end
      if (s:find("looking for", 1, true) or s:find(" need ", 1, true) or s:find(" last spot", 1, true))
        and (hasRole or hasActivity) then return true end
      if hasActivity and hasRole then return true end
      return false
    end

    local function sffcl_clean_guild_candidate(s)
      s = sffcl_clean_text(s)
      s = string.gsub(s, "{%s*[Rr][Tt]%d+%s*}", " ")
      s = string.gsub(s, "%[[Rr][Tt]%d+%]", " ")
      s = string.gsub(s, "^[^%w]+", "")
      s = string.gsub(s, "[^%w]+$", "")
      s = string.gsub(s, "^%s*[%p%s]+", "")
      s = string.gsub(s, "[%p%s]+%s*$", "")
      s = string.gsub(s, "%s+", " ")
      return sffcl_trim(s)
    end

    local function sffcl_bad_guild_name(name)
      local n = sffcl_clean_guild_candidate(name)
      if n == "" or string.len(n) < 2 or string.len(n) > 40 then return true end
      local low = sffcl_lower(n)
      local words = 0
      for _ in string.gmatch(n, "%S+") do words = words + 1 end
      if words >= 6 then return true end
      if low:find("lfm", 1, true) or low:find("looking for", 1, true) or low:find("need ", 1, true) then return true end
      if low:find("dungeon", 1, true) or low:find("random dungeon", 1, true) or low:find("rdf", 1, true) then return true end
      return false
    end

    local function sffcl_salvage_guild_name(name)
      local n = sffcl_clean_guild_candidate(name)
      if not sffcl_bad_guild_name(n) then return n end
      local g = n:match("[Gg]uild%s+%a+%s+([%w%'%-]+)")
      if g and not sffcl_bad_guild_name(g) then return sffcl_clean_guild_candidate(g) end
      g = n:match("[Gg]uild%s+([%w%'%-]+)")
      if g and not sffcl_bad_guild_name(g) then return sffcl_clean_guild_candidate(g) end
      return ""
    end

    local function sffcl_roles(text)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      local out = {}
      if s:find("tank", 1, true) or s:find("prot", 1, true) then table.insert(out, roleText and roleText("Tank") or "Tank") end
      if s:find("heal", 1, true) or s:find("heals", 1, true) or s:find("healer", 1, true) or s:find("resto", 1, true) then table.insert(out, roleText and roleText("Healer") or "Healer") end
      if s:find("dps", 1, true) or s:find("damage", 1, true) then table.insert(out, roleText and roleText("DPS") or "DPS") end
      if #out == 0 and (s:find("need", 1, true) or s:find("lfm", 1, true)) then return "Needed" end
      return table.concat(out, "  ")
    end

    local function sffcl_guild_name(text)
      local raw = sffcl_clean_text(text)
      local low = sffcl_lower(raw)

      -- Fast lane for guild tags.  A lot of Ascension guild ads are phrased as
      -- "join <Guild>", "consider <Guild>", or "guild tag <Guild>" and may not
      -- include the word recruiting.  Parse the tag first, but still require a
      -- guild-ad style signal so random angle-bracket chatter does not turn into a
      -- guild link.
      local angleGuild = raw:match("<([^>]+)>")
      local angleSignal = low:find("recruit", 1, true)
        or low:find("guild", 1, true)
        or low:find("join", 1, true)
        or low:find("consider", 1, true)
        or low:find("tag", 1, true)
        or low:find("pvp", 1, true)
        or low:find("pve", 1, true)
        or low:find("level", 1, true)
        or low:find("dungeon", 1, true)
        or low:find("raid", 1, true)
      if angleGuild and angleSignal then
        local g = sffcl_salvage_guild_name(angleGuild)
        if g ~= "" then return g end
      end

      local guildIntent = low:find("recruit", 1, true) or low:find("guild", 1, true) or low:find("discord", 1, true) or low:find("join us", 1, true)
        or low:find("join ", 1, true) or low:find("consider ", 1, true) or low:find("guild tag", 1, true)
        or low:find("realm first", 1, true) or low:find("main-raid", 1, true) or low:find("main raid", 1, true)
      if not guildIntent then return "" end
      if low:find("lfm", 1, true) or low:find("need tank", 1, true) or low:find("need heal", 1, true) or low:find("need dps", 1, true) then return "" end

      -- Use the core/legacy guild extractor first when available.  This matches the
      -- older BronzeLFG guild parser instead of the reduced fast-link parser.
      if type(extractGuildNameFromPost) == "function" then
        local ok, coreName = pcall(extractGuildNameFromPost, {message=raw, player=""})
        if ok and coreName and coreName ~= "" and not sffcl_bad_guild_name(coreName) then
          return sffcl_clean_guild_candidate(coreName)
        end
      end

      -- Prefer the strongest core parser if present, then the older aliases.
      local parsers = { BLFG_570b1b_GuildNameFromAd, BLFG_570b1_GuildNameFromAd, BLFG_5628_GuildNameFromAd, BLFG_5618_GuildNameFromAd }
      for _, fn in ipairs(parsers) do
        if type(fn) == "function" then
          local ok, oldName = pcall(fn, raw)
          if ok and oldName and oldName ~= "" and not sffcl_bad_guild_name(oldName) then
            return sffcl_clean_guild_candidate(oldName)
          end
        end
      end

      local g = angleGuild
      if g then g = sffcl_salvage_guild_name(g) end
      if not g or g == "" then g = raw:match("[Gg][Uu][Ii][Ll][Dd]%s+[%a%s]*[\"']([^\"']+)[\"']") end
      if not g then g = raw:match("^(.-)%s*%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") end
      if not g then g = raw:match("^(.-)%s*%[[Nn][Aa]%]") end
      if not g then g = raw:match("^(.-)%s*%[[Ee][Uu]%]") end
      if not g then g = raw:match("[Gg]uild%s+[Rr]ecruitment%s*[%+:%-%|]%s*(.-)%s+[Rr]ecru") end

      -- Common all-caps Ascension format:
      --   GUILD NAME - FRESH GUILD RECRUITING ...
      if not g and (low:find("guild recruiting", 1, true) or low:find("guild recruitment", 1, true) or low:find("fresh guild", 1, true)) then
        local dashName = raw:match("^%s*(.-)%s*%-%s*.*[Gg][Uu][Ii][Ll][Dd]%s+[Rr][Ee][Cc][Rr][Uu][Ii][Tt]")
        if dashName and dashName ~= "" then g = dashName end
      end

      if not g then g = raw:match("^%s*([%w%s%'%-]+)%s+[Ii][Ss]%s+[Rr][Ee][Cc][Rr][Uu][Ii][Tt][Ii][Nn][Gg]") end
      if not g then g = raw:match("^%s*([%w%s%'%-]+)%s+[Rr][Ee][Cc][Rr][Uu][Ii][Tt][Ii][Nn][Gg]") end
      if not g then g = raw:match("^(.-)%s+[Rr][Ee][Cc][Rr][Uu][Ii][Tt]") end
      g = sffcl_clean_guild_candidate(g or "")
      if sffcl_bad_guild_name(g) then return "" end
      return g
    end

    local function sffcl_word(haystack, token)
      haystack = " " .. sffcl_lower(sffcl_clean_text(haystack or "")) .. " "
      token = sffcl_lower(tostring(token or ""))
      if token == "" then return false end
      return haystack:find("%f[%w]" .. token .. "%f[%W]") ~= nil
    end

    local function sffcl_specific_raid(text)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      local raids = {
        {"Molten Core", {"mc", "molten core", "molten"}},
        {"Blackwing Lair", {"bwl", "blackwing lair", "blackwing"}},
        {"Zul'Gurub", {"zg", "zul'gurub", "zulgurub"}},
        {"Ruins of Ahn'Qiraj", {"aq20", "aq ruins", "ruins aq", "ruins of ahn'qiraj", "ruins of ahnqiraj", "raq"}},
        {"Temple of Ahn'Qiraj", {"aq40", "temple aq", "temple of ahn'qiraj", "temple of ahnqiraj", "taq"}},
        {"Onyxia", {"ony", "onyxia"}},
        {"Naxxramas", {"naxx", "naxxramas"}},
        {"Karazhan", {"kara", "karazhan"}},
        {"Gruul's Lair", {"gruul", "gruul's lair", "gruuls lair"}},
        {"Magtheridon's Lair", {"mag", "magtheridon", "magtheridon's lair", "magtheridons lair"}},
        {"Serpentshrine Cavern", {"ssc", "serpentshrine", "serpentshrine cavern"}},
        {"Tempest Keep", {"tk", "tempest keep"}},
        {"Black Temple", {"bt", "black temple"}},
        {"Sunwell Plateau", {"swp", "sunwell", "sunwell plateau"}},
        {"Ulduar", {"ulduar", "uld"}},
        {"Icecrown Citadel", {"icc", "icecrown citadel"}},
        {"Trial of the Crusader", {"toc", "trial of the crusader"}},
        {"The Ruby Sanctum", {"rs", "ruby sanctum"}},
      }
      for _, row in ipairs(raids) do
        for _, token in ipairs(row[2]) do
          if sffcl_word(s, token) then return row[1] end
        end
      end
      return nil
    end

    local function sffcl_specific_dungeon(text)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      -- On Ascension/CoA, players commonly shorten Vaults of Inquisition to just
      -- "Vault". Keep that shorthand profile-specific so it does not steal other
      -- servers' Vault-named activities.
      if sffcl_is_ascension() and sffcl_word(s, "vault") and not s:find("vault of archavon", 1, true) then
        return "Vaults of Inquisition"
      end
      local dungeons = {
        {"Utgarde Keep", {"utgarde keep", "uk", "uk key", "uk m+", "uk mythic"}},
        {"Drak'Tharon Keep", {"drak'tharon keep", "draktharon keep", "drak tharon", "dtk", "drak"}},
        {"Gundrak", {"gundrak", "gd"}},
        {"The Nexus", {"the nexus", "nexus"}},
        {"Hellfire Ramparts", {"hellfire ramparts", "ramparts", "ramps", "ramp"}},
        {"The Slave Pens", {"the slave pens", "slave pens", "sp"}},
        {"The Botanica", {"the botanica", "botanica", "bot"}},
        {"Mana-Tombs", {"mana-tombs", "mana tombs", "manatombs", "mt"}},
        {"Blood Furnace", {"blood furnace", "bf"}},
        {"Shattered Halls", {"shattered halls", "sh"}},
        {"The Underbog", {"the underbog", "underbog", "ub"}},
        {"The Steamvault", {"the steamvault", "steamvault", "steam vault", "sv"}},
        {"Auchenai Crypts", {"auchenai crypts", "crypts", "ac key", "ac"}},
        {"Sethekk Halls", {"sethekk halls", "sethekk", "seth", "shalls"}},
        {"Shadow Labyrinth", {"shadow labyrinth", "slabs", "slab", "shadow lab", "sl"}},
        {"Old Hillsbrad Foothills", {"old hillsbrad foothills", "old hillsbrad", "hillsbrad", "ohf"}},
        {"The Black Morass", {"the black morass", "black morass", "bm"}},
        {"The Mechanar", {"the mechanar", "mechanar", "mech"}},
        {"The Arcatraz", {"the arcatraz", "arcatraz", "arc"}},
        {"Magisters' Terrace", {"magisters' terrace", "magisters terrace", "mgt", "mag t", "terrace"}},
        {"Utgarde Pinnacle", {"utgarde pinnacle", "up", "up key", "up m+"}},
        {"The Oculus", {"the oculus", "oculus", "occ"}},
        {"Azjol-Nerub", {"azjol-nerub", "azjol nerub", "azjol", "an"}},
        {"Ahn'kahet: The Old Kingdom", {"ahn'kahet", "ahnkahet", "old kingdom", "ok", "ank"}},
        {"Violet Hold", {"violet hold", "vh"}},
        {"Halls of Stone", {"halls of stone", "hos"}},
        {"Halls of Lightning", {"halls of lightning", "hol"}},
        {"Culling of Stratholme", {"culling of stratholme", "culling strat", "cos"}},
        {"Trial of the Champion", {"trial of the champion", "toc", "champion trial"}},
        {"Forge of Souls", {"forge of souls", "fos"}},
        {"Pit of Saron", {"pit of saron", "pos"}},
        {"Halls of Reflection", {"halls of reflection", "hor"}},
        {"Blackrock Caverns", {"blackrock caverns", "brc"}},
        {"Blackrock Depths - Prison", {"brd prison", "prison"}},
        {"Blackrock Depths - Manufacturing", {"brd manufacturing", "manufacturing"}},
        {"Blackrock Depths - Upper City", {"brd upper", "upper city"}},
        {"Blackrock Depths", {"blackrock depths", "brd", "brd arena", "brd emp", "brd emperor"}},
        {"Dire Maul North", {"dire maul north", "dm north", "dmn", "dire maul n"}},
        {"Dire Maul East", {"dire maul east", "dm east", "dme"}},
        {"Dire Maul West", {"dire maul west", "dm west", "dmw"}},
        {"Dire Maul", {"dire maul"}},
        {"Lower Blackrock Spire", {"lower blackrock spire", "lbrs"}},
        {"Upper Blackrock Spire", {"upper blackrock spire", "ubrs"}},
        {"Lower Scholomance", {"lower scholomance", "lower scholo", "l scholo"}},
        {"Upper Scholomance", {"upper scholomance", "upper scholo", "u scholo"}},
        {"Scholomance", {"scholomance", "scholo"}},
        {"Stratholme - Main Gate", {"stratholme main", "strat main", "strat live", "strat living"}},
        {"Stratholme - Service Entrance", {"stratholme service", "strat service", "strat ud", "strat undead"}},
        {"Stratholme", {"stratholme", "strat"}},
        {"Scarlet Monastery - Armory", {"sm armory", "sm arm", "smarm", "scarlet monastery armory", "armory"}},
        {"Scarlet Monastery - Cathedral", {"sm cath", "smcath", "sm cathedral", "scarlet monastery cathedral", "cathedral", "cath"}},
        {"Scarlet Monastery - Graveyard", {"sm gy", "smgy", "sm grave", "sm graveyard", "scarlet monastery graveyard", "graveyard"}},
        {"Scarlet Monastery - Library", {"sm lib", "smlib", "sm library", "scarlet monastery library", "monasterio escarlata - biblioteca", "biblioteca", "library"}},
        {"Scarlet Monastery", {"scarlet", "sm"}},
        {"Maraudon - Orange Crystals", {"mara orange", "orange crystals"}},
        {"Maraudon - Pristine Waters", {"mara princess", "mara water", "pristine waters", "pristine"}},
        {"Maraudon - Purple Crystals", {"mara purple", "purple crystals"}},
        {"Maraudon", {"mara", "maraudon"}},
        {"Razorfen Downs", {"rfd", "razorfen downs", "razor fen downs"}},
        {"Razorfen Kraul", {"rfk", "razorfen kraul", "razor fen kraul"}},
        {"Ragefire Chasm", {"rfc", "ragefire"}},
        {"Deadmines", {"deadmines", "dm", "vc", "dm hc", "dm group", "dm blitz"}},
        {"Blackfathom Deeps", {"bfd", "blackfathom"}},
        {"Wailing Caverns", {"wc", "wailing caverns", "wailing", "wc blitz", "wc hc"}},
        {"Shadowfang Keep", {"sfk", "shadowfang"}},
        {"Gnomeregan", {"gnomeregan", "gnomer", "gnome"}},
        {"Stormwind Stockade", {"stockade", "stocks"}},
        {"Sunken Temple", {"sunken temple", "temple of atal", "atal", "st"}},
        {"Uldaman", {"uldaman", "ulda"}},
        {"Zul'Farrak", {"zul'farrak", "zulfarrak", "zf", "zf hc"}},
        {"Vaults of Inquisition", {"vaults of inquisition", "vaults", "vault", "voi"}},
        {"Road to De Other Side", {"road to de other side", "road to da other side", "roads", "rdos", "de other side", "da other side", "de otha side", "da otha side", "the other side", "other side", "dos"}},
      }
      for _, row in ipairs(dungeons) do
        for _, token in ipairs(row[2]) do
          if sffcl_word(s, token) then return row[1] end
        end
      end
      return nil
    end

    local function sffcl_activity_type(text)
      local s = " " .. sffcl_lower(sffcl_clean_text(text)) .. " "
      if s:find("invasion", 1, true) then return "Event", "Invasion" end
      if s:find("boss blitz", 1, true) or s:find("hcbb", 1, true) or s:find("bbhc", 1, true) then return "Event", "Boss Blitz" end
      local randomFinder = s:find(" rdf ", 1, true) or s:find("random dungeon", 1, true)
        or s:find("random mythic dungeon", 1, true)
      local mythicFinder = s:find(" mythic ", 1, true) or s:find("mythic+", 1, true)
        or s:find(" m+ ", 1, true)
      if randomFinder and mythicFinder then return "Dungeon", "Random Mythic Dungeon Finder" end
      if s:find("key", 1, true) or s:find("keystone", 1, true) or s:find("mythic+", 1, true) or s:find(" m+ ", 1, true) then
        local dungeon = sffcl_specific_dungeon(text)
        return "Key", dungeon or "Mythic+"
      end
      local raid = sffcl_specific_raid(text)
      if raid then return "Raid", raid end
      if s:find("raid", 1, true) then return "Raid", "General Raid" end
      local dungeon = sffcl_specific_dungeon(text)
      if dungeon then return "Dungeon", dungeon end
      if s:find("rdf", 1, true) or s:find("random dungeon", 1, true) or s:find("heroic", 1, true)
        or s:find(" dungeon", 1, true) or s:find(" dung ", 1, true) or s:find(" df ", 1, true) then
        return "Dungeon", "Random Dungeon Finder"
      end
      if s:find(" lfg ", 1, true) then return "LFG", "Looking For Group" end
      return "Dungeon", "Group Listing"
    end

    -- SignalFire 1.4.30: deterministic parser probe used by the in-game
    -- regression suite. This calls the exact lightweight parser used by live
    -- chat links, but does not create listings or modify chat.
    function SignalFireFastChatLinks.TestParse(text)
      local raw = sffcl_clean_text(text)
      local result = {
        input = raw,
        eligible = false,
        kind = "ignored",
        reason = "No clear group or guild intent",
      }

      if raw == "" then
        result.reason = "Empty text"
        return result
      end
      if sffcl_has_link(raw) then
        result.reason = "Already contains a SignalFire link"
        return result
      end
      if sffcl_noise_or_trade(raw) then
        result.reason = "Noise, trade, or external promotion"
        return result
      end

      local guild = sffcl_guild_name(raw)
      if guild ~= "" then
        result.eligible = true
        result.kind = "guild"
        result.type = "Guild"
        result.activity = "Guild Recruitment"
        result.guild = guild
        result.reason = nil
        return result
      end

      local publicType, activity = sffcl_activity_type(raw)
      if not sffcl_public_signal(raw, publicType, activity) then return result end

      result.eligible = true
      result.kind = "group"
      result.type = publicType
      result.activity = activity
      result.roles = sffcl_roles(raw)
      result.reason = nil
      return result
    end

    local function sffcl_prune(B)
      if not (B and B.publicGroups) then return end
      local stamp = sffcl_now()
      local rows = {}
      for id, row in pairs(B.publicGroups) do
        local keep = row and (row.isInvasionBeacon or row.signalFireListing or tostring(id):find("^listing%-") or tostring(id):find("^INVASION%-"))
        local t = tonumber(row and (row.seen or row.created or row.firstSeen) or 0) or stamp
        if not keep and (stamp - t) > 180 then
          B.publicGroups[id] = nil
        else
          table.insert(rows, {id=id, t=t, keep=keep})
        end
      end
      if #rows <= 80 then return end
      table.sort(rows, function(a, b)
        if a.keep ~= b.keep then return a.keep end
        return a.t > b.t
      end)
      for i = 81, #rows do
        if rows[i] and rows[i].id and not rows[i].keep then B.publicGroups[rows[i].id] = nil end
      end
    end

    local function sffcl_prune_fast_maps(B, stamp)
      if not B then return end
      stamp = stamp or sffcl_now()
      local scanned = 0
      for key, t in pairs(B._sffclSeen or {}) do
        scanned = scanned + 1
        if scanned > 200 then break end
        if (stamp - (tonumber(t or 0) or 0)) > 10 then
          B._sffclSeen[key] = nil
          if B._sffclLastRow then B._sffclLastRow[key] = nil end
        end
      end
      scanned = 0
      for key, rec in pairs(B._sffclFilterCache or {}) do
        scanned = scanned + 1
        if scanned > 200 then break end
        if (stamp - (tonumber(rec and rec.t or 0) or 0)) > 5 then B._sffclFilterCache[key] = nil end
      end
    end

    local function sffcl_mark_seen(B, author, text)
      if not B then return end
      B._inlinePublicChatEventSeen = B._inlinePublicChatEventSeen or {}
      local key = B.SignalFirePublicChatKey and B:SignalFirePublicChatKey(author, text) or sffcl_key(author, text)
      B._inlinePublicChatEventSeen[key] = sffcl_now()
    end

    local function sffcl_upsert(B, author, text, channelName)
      if not B or not sffcl_public_enabled() then return nil end
      local raw = tostring(text or "")
      if raw == "" or sffcl_has_link(raw) or sffcl_noise_or_trade(raw) then return nil end
      if B.SF151_IsGuildSeeking and B:SF151_IsGuildSeeking(raw) then return nil end
      local name = sffcl_author(author)
      if name == "" then return nil end
      if name == sffcl_player() and not B.SignalFireTestSay then return nil end

      local stamp = sffcl_now()
      local eventKey = sffcl_key(name, raw)
      B._sffclSeen = B._sffclSeen or {}
      local seen = B._sffclSeen[eventKey]
      if seen and (stamp - seen) <= 1 then
        return B._sffclLastRow and B._sffclLastRow[eventKey] or nil
      end
      B._sffclSeen[eventKey] = stamp
      sffcl_prune_fast_maps(B, stamp)

      B.publicGroups = B.publicGroups or {}
      B._sffclLastRow = B._sffclLastRow or {}

      local guild = sffcl_guild_name(raw)
      if guild ~= "" then
        if B.UpsertGuildBrowserChatListing then pcall(function() B:UpsertGuildBrowserChatListing(guild, author, raw) end) end
        local row = {name=guild, guild=guild, id="guild-" .. sffcl_hash(guild), seen=stamp}
        B._sffclLastRow[eventKey] = row
        sffcl_mark_seen(B, author, raw)
        return row
      end

      if not sffcl_public_signal(raw) then return nil end

      local typ, activity = sffcl_activity_type(raw)
      local id = "sffcl-" .. sffcl_hash(name .. "\031" .. raw)
      local row = B.publicGroups[id] or {}
      row.id = id
      row.key = id
      row.player = name
      row.message = sffcl_clean_text(raw)
      row.rawMessage = raw
      row.channel = channelName or row.channel or "Public"
      row.type = typ
      row.activity = activity
      row.intent = typ == "LFG" and "Applicant" or "Recruiter"
      row.roles = sffcl_roles(raw)
      row.tags = typ
      row.score = 80
      row.created = row.created or stamp
      row.firstSeen = row.firstSeen or row.created
      row.seen = stamp
      row.sessionOnly = true
      row.fastChatLink = true
      B.publicGroups[id] = row
      B._lastPublicGroupTouched = row
      B._lastPublicGroupTouchedKey = id
      B._sffclLastRow[eventKey] = row
      sffcl_mark_seen(B, author, raw)
      sffcl_prune(B)
      if B.RequestPublicGroupsRefresh then B:RequestPublicGroupsRefresh() end
      return row
    end

    local function sffcl_insert_guild_link(B, raw, guild)
      raw = tostring(raw or "")
      guild = tostring(guild or "")
      if raw == "" or guild == "" then return raw end
      if B and B.InsertGuildLinkInText then
        local ok, out = pcall(function() return B:InsertGuildLinkInText(raw, guild) end)
        if ok and out and out ~= "" and out ~= raw .. " " .. (B.GuildChatLink and B:GuildChatLink(guild) or "") then return out end
      end
      local link = B and B.GuildChatLink and B:GuildChatLink(guild) or ("[" .. guild .. "]")
      local low = sffcl_lower(raw)
      local nameLow = sffcl_lower(guild)
      local as, ae = low:find("<" .. nameLow .. ">", 1, true)
      if as then return raw:sub(1, as - 1) .. link .. raw:sub(ae + 1) end
      as, ae = low:find("[" .. nameLow .. "]", 1, true)
      if as then return raw:sub(1, as - 1) .. link .. raw:sub(ae + 1) end
      as, ae = low:find(nameLow, 1, true)
      if as then return raw:sub(1, as - 1) .. link .. raw:sub(ae + 1) end
      return raw .. " " .. link
    end

    local function sffcl_link_for(B, row, raw)
      if not (B and row) then return nil end
      if row.guild and not row.player then
        return sffcl_insert_guild_link(B, raw, row.guild)
      end
      local link = B.PublicChatLink and B:PublicChatLink(row) or nil
      return link and (raw .. " " .. link) or nil
    end

    local function sffcl_link_suffix(B, row)
      if not (B and row) then return nil end
      if row.guild and not row.player then
        return B.GuildChatLink and B:GuildChatLink(row.guild) or ("[" .. tostring(row.guild) .. "]")
      end
      return B.PublicChatLink and B:PublicChatLink(row) or nil
    end

    local function sffcl_valid_listing_text(text)
      if sffcl_noise_or_trade(text) then return false end
      if sffcl_guild_name(text) ~= "" then return true end
      return sffcl_public_signal(text)
    end

    local function sffcl_remove_bad_fast_rows(B)
      if not (B and B.publicGroups) then return end
      for id, row in pairs(B.publicGroups) do
        if row and row.fastChatLink then
          local raw = row.rawMessage or row.message or ""
          if not sffcl_valid_listing_text(raw) then
            B.publicGroups[id] = nil
            if B.selectedPublic == id then B.selectedPublic = nil end
          end
        end
      end
    end

    local function sffcl_display_parts(text)
      local clean = sffcl_clean_text(text)
      local channel, author, body = clean:match("^%[([^%]]+)%]%s*%[([^%]]+)%]:%s*(.+)$")
      if body then return sffcl_author(author), body, channel end
      author, body = clean:match("^%[([^%]]+)%]:%s*(.+)$")
      if body then return sffcl_author(author), body, "Chat" end
      author, body = clean:match("^([^:]-):%s*(.+)$")
      if body and not author:find("://", 1, true) then return sffcl_author(author), body, "Chat" end
      return "", "", ""
    end

    local function sffcl_rewrite_display_message(text)
      local B = BLFG or (_G and _G.BronzeLFG)
      if not B or not sffcl_public_enabled() then return text end
      local raw = tostring(text or "")
      if raw == "" or sffcl_has_link(raw) then return text end

      local clean = sffcl_clean_text(raw)
      if clean == "" then return text end
      if clean:find("SignalFire>", 1, true) or clean:find("SignalFire:", 1, true) or clean:find("SignalFire Alert:", 1, true) then return text end

      local author, body, channelName = sffcl_display_parts(clean)
      if author == "" or body == "" then return text end
      if sffcl_noise_or_trade(body) then return text end
      if B.SF151_IsGuildSeeking and B:SF151_IsGuildSeeking(body) then return text end
      if not sffcl_public_signal(body) and sffcl_guild_name(body) == "" then return text end

      local stamp = sffcl_now()
      local cacheKey = sffcl_key(author, body) .. "\030display"
      B._sffclDisplayCache = B._sffclDisplayCache or {}
      local cached = B._sffclDisplayCache[cacheKey]
      if cached and (stamp - (cached.t or 0)) <= 2 then
        return cached.out or text
      end

      local row = sffcl_upsert(B, author, body, channelName or "Chat")
      local out = nil
      if row and row.guild and not row.player then
        out = sffcl_insert_guild_link(B, raw, row.guild)
      else
        local suffix = sffcl_link_suffix(B, row)
        out = suffix and (raw .. " " .. suffix) or text
      end
      B._sffclDisplayCache[cacheKey] = {t=stamp, out=out}
      return out
    end

    local function sffcl_hook_chat_frame(frame)
      if not (frame and frame.AddMessage) then return end
      if frame._sffclAddMessageHook and frame.AddMessage == frame._sffclAddMessageHook then return end
      local oldAddMessage = frame.AddMessage
      frame._sffclOldAddMessage = oldAddMessage
      frame._sffclAddMessageHook = function(self, text, ...)
        return oldAddMessage(self, sffcl_rewrite_display_message(text), ...)
      end
      frame.AddMessage = frame._sffclAddMessageHook
    end

    local function sffcl_hook_chat_frames()
      local n = tonumber(NUM_CHAT_WINDOWS or 0) or 0
      for i = 1, math.max(n, 10) do
        local frame = _G and _G["ChatFrame" .. tostring(i)]
        sffcl_hook_chat_frame(frame)
      end
      sffcl_hook_chat_frame(DEFAULT_CHAT_FRAME)
    end

    local function sffcl_remove_filter(event, fn)
      if ChatFrame_RemoveMessageEventFilter and type(fn) == "function" then pcall(ChatFrame_RemoveMessageEventFilter, event, fn) end
    end

    local function sffcl_disable_old_filters()
      sffcl_remove_filter("CHAT_MSG_CHANNEL", _G.BLFG_PublicInlineFilter_561)
      sffcl_remove_filter("CHAT_MSG_SAY", _G.BLFG_PublicInlineFilter_561)
      sffcl_remove_filter("CHAT_MSG_YELL", _G.BLFG_PublicInlineFilter_561)
      sffcl_remove_filter("CHAT_MSG_CHANNEL", _G.SF577_RoleComboInlineFilter)
      sffcl_remove_filter("CHAT_MSG_SAY", _G.SF577_RoleComboInlineFilter)
      sffcl_remove_filter("CHAT_MSG_YELL", _G.SF577_RoleComboInlineFilter)
      if type(SF577_BuildRoleComboLink) == "function" then function SF577_BuildRoleComboLink() return nil end end
    end

    function SignalFireFastChatLinks.Filter(frame, event, msgText, author, ...)
      local B = BLFG or (_G and _G.BronzeLFG)
      if not B then return false, msgText, author, ... end
      if (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") and not B.SignalFireTestSay then return false, msgText, author, ... end

      local channelName = event
      if event == "CHAT_MSG_CHANNEL" then
        local args = {...}
        channelName = tostring(args[8] or args[7] or "Channel")
      elseif event == "CHAT_MSG_SAY" then
        channelName = "Say"
      elseif event == "CHAT_MSG_YELL" then
        channelName = "Yell"
      end

      local raw = tostring(msgText or "")
      local cacheKey = sffcl_key(author, raw)
      local stamp = sffcl_now()
      B._sffclFilterCache = B._sffclFilterCache or {}
      local cached = B._sffclFilterCache[cacheKey]
      if cached and (stamp - (cached.t or 0)) <= 1 then
        if cached.out and cached.out ~= raw then return false, cached.out, author, ... end
        return false, msgText, author, ...
      end

      local row = sffcl_upsert(B, author, raw, channelName)
      -- Let SignalFireChatQueueFix/core BronzeLFG parser re-parse the same line later.
      -- The fast parser is only for lightweight inline display; the core parser owns the
      -- Public Groups/Guild Browser row quality.
      if B.AddPublicGroup and not B._sfChatQueueProcessing then pcall(function() B:AddPublicGroup(author, raw, channelName) end) end
      local out = sffcl_link_for(B, row, raw)
      B._sffclFilterCache[cacheKey] = {t=stamp, out=out}
      sffcl_prune_fast_maps(B, stamp)
      if out and out ~= raw then return false, out, author, ... end
      return false, msgText, author, ...
    end

    local function sffcl_install()
      local B = BLFG or (_G and _G.BronzeLFG)
      if not B then return end
      sffcl_disable_old_filters()
      sffcl_hook_chat_frames()
      sffcl_remove_bad_fast_rows(B)

      function B:InlinePublicChatLinkForMessage(msgText, author, channelName)
        local row = sffcl_upsert(self, author, msgText, channelName)
        return sffcl_link_for(self, row, tostring(msgText or ""))
      end

      -- Do not override B:AddPublicGroup here. SignalFireChatQueueFix keeps the
      -- legacy/core BronzeLFG parser deferred off the chat-render path. Replacing it
      -- with the fast parser caused weaker dungeon/raid/guild recognition.

      if ChatFrame_RemoveMessageEventFilter and ChatFrame_AddMessageEventFilter then
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_CHANNEL", SignalFireFastChatLinks.Filter)
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_SAY", SignalFireFastChatLinks.Filter)
        pcall(ChatFrame_RemoveMessageEventFilter, "CHAT_MSG_YELL", SignalFireFastChatLinks.Filter)
        B._sffclFilterInstalled = nil
      end
      if ChatFrame_AddMessageEventFilter and (ChatFrame_RemoveMessageEventFilter or not B._sffclFilterInstalled) then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", SignalFireFastChatLinks.Filter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", SignalFireFastChatLinks.Filter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", SignalFireFastChatLinks.Filter)
        B._sffclFilterInstalled = true
      end
    end

    sffcl_install()

    local sffcl_frame = CreateFrame and CreateFrame("Frame")
    if sffcl_frame then
      sffcl_frame:RegisterEvent("PLAYER_LOGIN")
      sffcl_frame:RegisterEvent("PLAYER_ENTERING_WORLD")
      sffcl_frame:SetScript("OnEvent", function() sffcl_install() end)
    end
  until true
end

-- Parsing controls
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    SignalFireChatParsingControls = SignalFireChatParsingControls or {}
    local SFCP = SignalFireChatParsingControls

    local function sfcp_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfcp_lower(s)
      return string.lower(tostring(s or ""))
    end

    local function sfcp_clean(s)
      s = tostring(s or "")
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
      s = string.gsub(s, "|h(%b[])|h", "%1")
      s = string.gsub(s, "%s+", " ")
      return sfcp_trim(s)
    end

    local function sfcp_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfcp_ensure_options()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local o = BronzeLFG_DB.options

      if o.publicGroups == nil then o.publicGroups = true end
      if o.publicStrict == nil then o.publicStrict = true end
      if o.parseGuildRecruitment == nil then o.parseGuildRecruitment = true end

      if o.inlineChatLinks == nil then
        if o.disableInlineChatLinks == true or o.chatLinkSafeMode == true then
          o.inlineChatLinks = false
        else
          o.inlineChatLinks = true
        end
      end

      local oldScope = tostring(o.chatLinkScope or o.chatLinksMode or o.chatLinkMode or "")
      oldScope = sfcp_lower(oldScope)
      if oldScope == "all" or oldScope == "all chat frames" then
        o.chatLinkScope = "all"
      elseif oldScope == "visible" or oldScope == "visible chat frames" then
        o.chatLinkScope = "visible"
      elseif oldScope == "off" then
        o.inlineChatLinks = false
        o.chatLinkScope = "main"
      elseif o.chatLinkScope ~= "main" and o.chatLinkScope ~= "all" and o.chatLinkScope ~= "visible" then
        o.chatLinkScope = "main"
      end

      return o
    end

    local function sfcp_is_main_frame(frame)
      if not frame then return true end
      if frame == DEFAULT_CHAT_FRAME then return true end
      if _G.ChatFrame1 and frame == _G.ChatFrame1 then return true end
      return false
    end

    local function sfcp_frame_allowed(frame)
      local o = sfcp_ensure_options()
      if o.chatLinkScope == "all" then return true end
      if o.chatLinkScope == "visible" then
        if not frame or not frame.IsShown then return true end
        local ok, shown = pcall(frame.IsShown, frame)
        if not ok then return true end
        return shown and true or false
      end
      return sfcp_is_main_frame(frame)
    end

    local function sfcp_has_external_stream(text)
      local s = sfcp_lower(sfcp_clean(text))
      return string.find(s, "kick.com", 1, true)
        or string.find(s, "twitch.tv", 1, true)
        or string.find(s, "youtube.com", 1, true)
        or string.find(s, "youtu.be", 1, true)
    end

    local function sfcp_has_generic_url(text)
      local s = sfcp_lower(sfcp_clean(text))
      return string.find(s, "http://", 1, true)
        or string.find(s, "https://", 1, true)
        or string.find(s, "www.", 1, true)
    end

    local function sfcp_has_discord(text)
      local s = sfcp_lower(sfcp_clean(text))
      return string.find(s, "discord.gg", 1, true)
        or string.find(s, "discord.com/invite", 1, true)
    end

    local function sfcp_is_guild_seeking(text)
      local raw = sfcp_clean(text)
      local s = " " .. sfcp_lower(raw) .. " "
      if s == "  " or not string.find(s, " guild", 1, true) then return false end
      local seeking = string.find(s, " lf guild", 1, true) or string.find(s, " lf a guild", 1, true) or string.find(s, " lfm", 1, true) or string.find(s, " lfg", 1, true)
        or string.find(s, " looking for", 1, true) or string.find(s, " seeking ", 1, true)
        or string.find(s, " need a guild", 1, true) or string.find(s, " want a guild", 1, true)
        or string.find(s, " any guild", 1, true) or string.find(s, " a guild", 1, true)
        or string.find(s, " guild pls", 1, true) or string.find(s, " guild please", 1, true)
      if not seeking then return false end
      local recruiting = string.find(s, " recruit", 1, true) or string.find(s, " recruitment", 1, true)
        or string.find(s, " looking for members", 1, true) or string.find(s, " seeking members", 1, true)
        or string.find(s, " accepting members", 1, true) or string.find(s, " join us", 1, true)
        or string.find(s, " join our", 1, true) or string.find(raw, "<[^>]+>")
      return not recruiting
    end

    local function sfcp_is_guild_candidate(text)
      local raw = sfcp_clean(text)
      if raw == "" then return false end

      if type(_G.SF578_IsStrongGuildRecruitmentText) == "function" then
        local ok, result = pcall(_G.SF578_IsStrongGuildRecruitmentText, raw)
        if ok and result then return true end
      end

      local s = " " .. sfcp_lower(raw) .. " "
      local hasTag = string.find(raw, "<[^>]+>") ~= nil
      local intent = string.find(s, " recruit", 1, true)
        or string.find(s, " recruitment ", 1, true)
        or string.find(s, " guild ", 1, true)
        or string.find(s, " join our ", 1, true)
        or string.find(s, " join <", 1, true)
        or string.find(s, " consider <", 1, true)
        or string.find(s, " guild tag ", 1, true)
        or string.find(s, " looking for members", 1, true)
        or string.find(s, " seeking members", 1, true)
        or string.find(s, " accepting members", 1, true)

      return (hasTag and intent) or (intent and (string.find(s, " guild", 1, true) or string.find(s, " recruiting", 1, true)))
    end

    local function sfcp_has_role(text)
      local s = " " .. sfcp_lower(sfcp_clean(text)) .. " "
      return string.find(s, " tank", 1, true)
        or string.find(s, " heal", 1, true)
        or string.find(s, " healer", 1, true)
        or string.find(s, " heals", 1, true)
        or string.find(s, " dps", 1, true)
        or string.find(s, " damage", 1, true)
    end

    local function sfcp_has_activity(text)
      local s = " " .. sfcp_lower(sfcp_clean(text)) .. " "
      return string.find(s, " dungeon", 1, true)
        or string.find(s, " raid", 1, true)
        or string.find(s, " rdf", 1, true)
        or string.find(s, " heroic", 1, true)
        or string.find(s, " mythic", 1, true)
        or string.find(s, " keystone", 1, true)
        or string.find(s, " key ", 1, true)
        or string.find(s, " invasion", 1, true)
        or string.find(s, " boss blitz", 1, true)
        or string.find(s, " hcbb", 1, true)
        or string.find(s, " molten core", 1, true)
        or string.find(s, " blackwing", 1, true)
        or string.find(s, " de other side", 1, true)
        or string.find(s, " otha side", 1, true)
        or string.find(s, " vault", 1, true)
    end

    local function sfcp_has_explicit_group_intent(text)
      local s = " " .. sfcp_lower(sfcp_clean(text)) .. " "
      if string.find(s, " lfm", 1, true) or string.find(s, " lf1m", 1, true)
        or string.find(s, " lf2m", 1, true) or string.find(s, " lf3m", 1, true)
        or string.find(s, " lf4m", 1, true) or string.find(s, " lfg ", 1, true)
        or string.find(s, " lf%d+m") then return true end
      if string.find(s, " looking for ", 1, true) or string.find(s, " need ", 1, true)
        or string.find(s, " last spot", 1, true) or string.find(s, " forming ", 1, true) then return true end
      return false
    end

    local function sfcp_is_group_candidate(text)
      local s = " " .. sfcp_lower(sfcp_clean(text)) .. " "
      if s == "  " then return false end
      if string.find(s, " lfm", 1, true) or string.find(s, " lf1m", 1, true)
        or string.find(s, " lf2m", 1, true) or string.find(s, " lf3m", 1, true)
        or string.find(s, " lf4m", 1, true) or string.find(s, " lfg ", 1, true)
        or string.find(s, " lf%d+m") then return true end
      if string.find(s, " looking for ", 1, true) or string.find(s, " need ", 1, true)
        or string.find(s, " last spot", 1, true) or string.find(s, " forming ", 1, true) then
        return sfcp_has_role(s) or sfcp_has_activity(s)
      end
      if string.find(s, " lf ", 1, true) then return sfcp_has_role(s) or sfcp_has_activity(s) end
      return sfcp_has_role(s) and sfcp_has_activity(s)
    end

    local function sfcp_broad_candidate(text)
      local s = " " .. sfcp_lower(sfcp_clean(text)) .. " "
      if s == "  " then return false end
      if sfcp_is_group_candidate(s) or sfcp_is_guild_candidate(s) then return true end
      return string.find(s, " lfm", 1, true)
        or string.find(s, " lfg", 1, true)
        or string.find(s, " looking for", 1, true)
        or string.find(s, " need ", 1, true)
        or sfcp_has_role(s)
        or sfcp_has_activity(s)
    end

    local function sfcp_should_handle(text)
      local o = sfcp_ensure_options()
      if o.publicGroups == false then return false end

      local raw = sfcp_clean(text)
      if raw == "" then return false end
      if string.find(raw, "bronzelfgpub:", 1, true) or string.find(raw, "bronzelfgguild:", 1, true)
        or string.find(raw, "|Hbronzelfg", 1, true) then return false end

      if sfcp_has_external_stream(raw) then return false end
      if sfcp_has_generic_url(raw) and not sfcp_has_discord(raw) then return false end
      if sfcp_is_guild_seeking(raw) then return false end

      local guildCandidate = sfcp_is_guild_candidate(raw)
      local groupCandidate = sfcp_is_group_candidate(raw)

      if guildCandidate and o.parseGuildRecruitment == false and not sfcp_has_explicit_group_intent(raw) then return false end

      if o.publicStrict ~= false then
        if groupCandidate then return true end
        return o.parseGuildRecruitment ~= false and guildCandidate
      end

      if guildCandidate and o.parseGuildRecruitment == false then return sfcp_has_explicit_group_intent(raw) and groupCandidate end
      return sfcp_broad_candidate(raw)
    end

    local function sfcp_links_enabled()
      local o = sfcp_ensure_options()
      return o.publicGroups ~= false and o.inlineChatLinks ~= false
    end

    local function sfcp_remove_filter(event, fn)
      if ChatFrame_RemoveMessageEventFilter and type(fn) == "function" then
        pcall(ChatFrame_RemoveMessageEventFilter, event, fn)
      end
    end

    local function sfcp_restore_chat_addmessage()
      local n = tonumber(NUM_CHAT_WINDOWS or 0) or 0
      for i = 1, math.max(n, 10) do
        local frame = _G["ChatFrame" .. tostring(i)]
        if frame and frame.AddMessage then
          if not frame._sfcpBaseAddMessage and frame._sffclOldAddMessage then
            frame._sfcpBaseAddMessage = frame._sffclOldAddMessage
          end
          if frame._sfcpBaseAddMessage then frame.AddMessage = frame._sfcpBaseAddMessage end
        end
      end
      if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        if not DEFAULT_CHAT_FRAME._sfcpBaseAddMessage and DEFAULT_CHAT_FRAME._sffclOldAddMessage then
          DEFAULT_CHAT_FRAME._sfcpBaseAddMessage = DEFAULT_CHAT_FRAME._sffclOldAddMessage
        end
        if DEFAULT_CHAT_FRAME._sfcpBaseAddMessage then DEFAULT_CHAT_FRAME.AddMessage = DEFAULT_CHAT_FRAME._sfcpBaseAddMessage end
      end
    end

    function SFCP.Filter(frame, event, msgText, author, ...)
      if not sfcp_links_enabled() then return false, msgText, author, ... end
      if not sfcp_frame_allowed(frame) then return false, msgText, author, ... end
      if not sfcp_should_handle(msgText) then return false, msgText, author, ... end

      local old = SFCP.fastFilter
      if type(old) == "function" then return old(frame, event, msgText, author, ...) end
      return false, msgText, author, ...
    end

    local function sfcp_install_filter()
      if not ChatFrame_AddMessageEventFilter then return end

      if SignalFireFastChatLinks and type(SignalFireFastChatLinks.Filter) == "function"
        and SignalFireFastChatLinks.Filter ~= SFCP.Filter then
        SFCP.fastFilter = SignalFireFastChatLinks.Filter
      end

      sfcp_remove_filter("CHAT_MSG_CHANNEL", _G.BLFG_PublicInlineFilter_561)
      sfcp_remove_filter("CHAT_MSG_SAY", _G.BLFG_PublicInlineFilter_561)
      sfcp_remove_filter("CHAT_MSG_YELL", _G.BLFG_PublicInlineFilter_561)
      sfcp_remove_filter("CHAT_MSG_CHANNEL", _G.SF577_RoleComboInlineFilter)
      sfcp_remove_filter("CHAT_MSG_SAY", _G.SF577_RoleComboInlineFilter)
      sfcp_remove_filter("CHAT_MSG_YELL", _G.SF577_RoleComboInlineFilter)
      sfcp_remove_filter("CHAT_MSG_CHANNEL", SFCP.fastFilter)
      sfcp_remove_filter("CHAT_MSG_SAY", SFCP.fastFilter)
      sfcp_remove_filter("CHAT_MSG_YELL", SFCP.fastFilter)
      sfcp_remove_filter("CHAT_MSG_CHANNEL", SFCP.Filter)
      sfcp_remove_filter("CHAT_MSG_SAY", SFCP.Filter)
      sfcp_remove_filter("CHAT_MSG_YELL", SFCP.Filter)

      ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", SFCP.Filter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", SFCP.Filter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", SFCP.Filter)
    end

    local function sfcp_wrap_inline()
      if not BLFG then return end
      if BLFG.InlinePublicChatLinkForMessage ~= SFCP.inlineWrapper then
        SFCP.oldInline = BLFG.InlinePublicChatLinkForMessage
      end
      if not SFCP.inlineWrapper then
        SFCP.inlineWrapper = function(self, msgText, author, channelName)
          if not sfcp_links_enabled() or not sfcp_should_handle(msgText) then return nil end
          return SFCP.oldInline and SFCP.oldInline(self, msgText, author, channelName) or nil
        end
      end
      BLFG.InlinePublicChatLinkForMessage = SFCP.inlineWrapper
    end

    local function sfcp_wrap_parser()
      if not BLFG or BLFG._sfcpParserWrapped then return end
      BLFG._sfcpParserWrapped = true

      SFCP.oldAddPublicGroup = BLFG.AddPublicGroup
      function BLFG:AddPublicGroup(author, text, channelName)
        if not sfcp_should_handle(text) then return nil end
        return SFCP.oldAddPublicGroup and SFCP.oldAddPublicGroup(self, author, text, channelName) or nil
      end

      SFCP.oldGuildUpsert = BLFG.UpsertGuildBrowserChatListing
      if SFCP.oldGuildUpsert then
        function BLFG:UpsertGuildBrowserChatListing(guildName, author, text, ...)
          local o = sfcp_ensure_options()
          if o.parseGuildRecruitment == false then return nil end
          return SFCP.oldGuildUpsert(self, guildName, author, text, ...)
        end
      end
    end

    local function sfcp_apply_runtime()
      sfcp_ensure_options()
      sfcp_restore_chat_addmessage()
      sfcp_install_filter()
      sfcp_wrap_inline()
      sfcp_wrap_parser()
    end

    -- SignalFire 1.4.31: exported runtime refresh for the central module registry.
    SFCP.ApplyRuntime = sfcp_apply_runtime
    function BLFG:SFCP_ApplyRuntime()
      return sfcp_apply_runtime()
    end

    local function sfcp_flat(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .9)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end

    local function sfcp_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      if size and fs.SetFont then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path or "Fonts\\FRIZQT__.TTF", size, flags or "")
      end
      return fs
    end

    local function sfcp_button(parent, text, width, height)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(width or 130)
      b:SetHeight(height or 24)
      b:SetText(text or "Button")
      return b
    end

    local function sfcp_register_escape(frame, name)
      if name then _G[name] = frame end
      if name and UISpecialFrames then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == name then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, name) end
      end
      if frame.EnableKeyboard then frame:EnableKeyboard(true) end
      frame:SetScript("OnKeyDown", function(self, key) if key == "ESCAPE" then self:Hide() end end)
    end

    local function sfcp_scope_label(value)
      if value == "all" then return "All Chat Frames" end
      if value == "visible" then return "Visible Chat Frames" end
      return "Main Chat Only"
    end

    local function sfcp_set_status(text)
      if BLFG and BLFG.optionsStatus then BLFG.optionsStatus:SetText(tostring(text or "Options saved.")) end
      if BLFG and BLFG.sfcpPanel and BLFG.sfcpPanel.status then BLFG.sfcpPanel.status:SetText(tostring(text or "Options saved.")) end
    end

    local function sfcp_clear_public_cache()
      if not BLFG then return end
      BLFG.publicGroups = {}
      BLFG.selectedPublic = nil
      BLFG.publicPage = 1
      BLFG._sfChatParseQueue = {}
      BLFG._sfChatParseSeen = {}
      BLFG._inlinePublicChatEventSeen = {}
      BLFG._sffclSeen = {}
      BLFG._sffclLastRow = {}
      BLFG._sffclFilterCache = {}
      BLFG._sffclDisplayCache = {}
      if SignalFireChatRuntime151 then
        SignalFireChatRuntime151._decisionCache = {}
        SignalFireChatRuntime151._decisionSlots = {}
        SignalFireChatRuntime151._decisionCursor = 0
      end
      if BLFG.RefreshPublicGroups then pcall(function() BLFG:RefreshPublicGroups() end) end
      sfcp_set_status("Public Groups cache cleared.")
    end

    function BLFG:SFCP_AddOptions()
      if not self.optionsPanel or self.sfcpOpenButton then return end
      sfcp_ensure_options()

      local p = self.optionsPanel
      local open = sfcp_button(p, "Chat & Parsing", 132, 24)
      self.sfcpOpenButton = open

      local function place(btn, offset, width)
        if not btn then return end
        btn:ClearAllPoints()
        btn:SetWidth(width or 120)
        btn:SetHeight(24)
        btn:SetPoint("TOPRIGHT", p, "TOPRIGHT", offset, -4)
      end

      place(self.sfe141EventAlertButton, -18, 118)
      place(self.sfamPolishButton, -144, 124)
      place(self.sfn138FavoriteAlertButton, -276, 124)
      place(open, -408, 132)

      local function build_panel()
        if self.sfcpPanel then return self.sfcpPanel end

        local name = "SignalFireChatParsingPanel"
        local f = CreateFrame("Frame", name, p)
        self.sfcpPanel = f
        f:SetAllPoints(p)
        f:SetFrameLevel(((p.GetFrameLevel and p:GetFrameLevel()) or 1) + 145)
        f:SetToplevel(true)
        f:EnableMouse(true)
        sfcp_flat(f, .985)
        sfcp_register_escape(f, name)
        f:Hide()

        local title = sfcp_font(f, "Chat & Parsing", 18, 1, .75, 0)
        title:SetPoint("TOP", f, "TOP", 0, -28)

        local note = sfcp_font(f, "Control chat parsing and SignalFire links without editing SavedVariables. All Chat Frames preserves links in every tab.", 10, .82, .9, 1)
        note:SetPoint("TOP", title, "BOTTOM", 0, -12)
        note:SetWidth(700)
        note:SetJustifyH("CENTER")

        local panel = CreateFrame("Frame", nil, f)
        panel:SetWidth(700)
        panel:SetHeight(350)
        panel:SetPoint("TOP", f, "TOP", 0, -88)
        panel:SetFrameLevel(f:GetFrameLevel() + 5)
        panel:EnableMouse(true)
        sfcp_flat(panel, .82)

        local function check(key, label, body, y)
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, y)
          cb:SetFrameLevel(panel:GetFrameLevel() + 10)
          cb.text = sfcp_font(panel, label, 11, 1, 1, 1)
          cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
          cb.body = sfcp_font(panel, body or "", 9, .75, .75, .75)
          cb.body:SetPoint("TOPLEFT", cb.text, "BOTTOMLEFT", 0, -2)
          cb.body:SetWidth(620)
          cb.body:SetJustifyH("LEFT")
          cb:SetScript("OnClick", function(self)
            local o = sfcp_ensure_options()
            o[key] = self:GetChecked() and true or false
            if key == "publicGroups" and BLFG.optPublic then BLFG.optPublic:SetChecked(o.publicGroups ~= false) end
            sfcp_apply_runtime()
            sfcp_set_status("Chat & Parsing options saved.")
          end)
          f[key] = cb
          return cb
        end

        check("publicGroups", "Parse Public Groups From Chat", "Builds Public Groups from eligible chat posts. Turning this off stops both background parsing and SignalFire chat links.", -22)
        check("inlineChatLinks", "Show SignalFire Links in Chat", "Adds clickable SignalFire group/guild links to eligible chat lines. Parsing can remain enabled while links are off.", -78)
        check("parseGuildRecruitment", "Parse Guild Recruitment", "Detects guild advertisements and creates Guild Browser links/listings. Personal Kick/Twitch/YouTube promotions remain ignored.", -134)
        check("publicStrict", "Strict Parsing", "Recommended. Requires clear group or guild intent and reduces false positives from ordinary chat.", -190)

        local scopeTitle = sfcp_font(panel, "Chat Link Scope", 11, 1, .82, .35)
        scopeTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 30, -252)
        local scopeHelp = sfcp_font(panel, "All Chat Frames preserves linked history in every tab. Visible Chat Frames reduces hyperlink rendering work.", 9, .75, .75, .75)
        scopeHelp:SetPoint("TOPLEFT", scopeTitle, "BOTTOMLEFT", 0, -4)
        scopeHelp:SetWidth(430)
        scopeHelp:SetJustifyH("LEFT")

        local dd = CreateFrame("Frame", "SignalFireChatLinkScopeDropdown", panel, "UIDropDownMenuTemplate")
        f.scopeDropdown = dd
        dd:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -242)
        UIDropDownMenu_SetWidth(dd, 150)
        UIDropDownMenu_Initialize(dd, function()
          local o = sfcp_ensure_options()
          local choices = {
            {label="Visible Chat Frames", value="visible"},
            {label="Main Chat Only", value="main"},
            {label="All Chat Frames", value="all"},
          }
          for _, choice in ipairs(choices) do
            local label = choice.label
            local value = choice.value
            local info = UIDropDownMenu_CreateInfo()
            info.text = label
            info.value = value
            info.checked = o.chatLinkScope == value
            info.func = function()
              o.chatLinkScope = value
              UIDropDownMenu_SetSelectedValue(dd, value)
              UIDropDownMenu_SetText(dd, label)
              CloseDropDownMenus()
              sfcp_apply_runtime()
              sfcp_set_status("Chat link scope saved: " .. label .. ".")
            end
            UIDropDownMenu_AddButton(info)
          end
        end)

        local clear = sfcp_button(panel, "Clear Public Groups Cache", 178, 26)
        f.clearButton = clear
        clear:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 26, 18)
        clear:SetScript("OnClick", sfcp_clear_public_cache)

        local runTests = sfcp_button(panel, "Run Parser Tests", 148, 26)
        f.runParserTestsButton = runTests
        runTests:SetPoint("LEFT", clear, "RIGHT", 10, 0)
        runTests:SetScript("OnClick", function()
          if SignalFireParserRegression and SignalFireParserRegression.Show then
            SignalFireParserRegression.Show()
          else
            sfcp_msg("Parser regression suite is not available in this build.", 1, .35, .35)
          end
        end)

        local recommendation = sfcp_font(panel, "Complete coverage: all protections On; All Chat Frames.", 9, .45, 1, .45)
        f.recommendation = recommendation
        recommendation:SetPoint("LEFT", runTests, "RIGHT", 12, 0)
        recommendation:SetWidth(292)
        recommendation:SetJustifyH("LEFT")

        f.status = sfcp_font(f, "Options auto-save.", 10, .45, 1, .45)
        f.status:SetPoint("BOTTOM", f, "BOTTOM", 0, 72)

        local back = sfcp_button(f, "Back to Options", 140, 28)
        back:SetPoint("BOTTOM", f, "BOTTOM", 0, 36)
        back:SetFrameLevel(f:GetFrameLevel() + 20)
        back:SetScript("OnClick", function() f:Hide() end)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
        close:SetFrameLevel(f:GetFrameLevel() + 20)
        close:SetScript("OnClick", function() f:Hide() end)

        return f
      end

      local function refresh_panel()
        local f = build_panel()
        local o = sfcp_ensure_options()
        f.publicGroups:SetChecked(o.publicGroups ~= false)
        f.inlineChatLinks:SetChecked(o.inlineChatLinks ~= false)
        f.parseGuildRecruitment:SetChecked(o.parseGuildRecruitment ~= false)
        f.publicStrict:SetChecked(o.publicStrict ~= false)
        UIDropDownMenu_SetSelectedValue(f.scopeDropdown, o.chatLinkScope)
        UIDropDownMenu_SetText(f.scopeDropdown, sfcp_scope_label(o.chatLinkScope))
        return f
      end

      open:SetScript("OnClick", function()
        local f = refresh_panel()
        f:Show()
        if f.Raise then f:Raise() end
      end)
    end


    -- SignalFire 1.4.31b: integrated module manager
    -- This lives in the already-proven Chat & Parsing UI module so it cannot be
    -- skipped by a late sidecar or hidden by the inherited one-checkbox module UI.
    local SFMM_DEFS = {
      {key="chatParsing", label="Chat Parsing", description="Public Groups parsing, guild recruitment detection, and SignalFire chat links.", profiles={Triumvirate=true, Ascension=true}, default=true, toggleable=true},
      {key="guildBrowser", label="Guild Browser", description="Guild discovery, recruitment listings, favorites, and guild chat links.", profiles={Triumvirate=true, Ascension=true}, default=true, toggleable=true},
      {key="recruitmentCreator", label="Recruitment Creator", description="Guild recruitment post builder, templates, preview, and broadcast tools.", profiles={Triumvirate=true, Ascension=true}, default=true, toggleable=true, requires="guildBrowser"},
      {key="eventBoard", label="Community Event Board", description="Community events, event discovery, and event creation.", profiles={Triumvirate=true, Ascension=true}, default=true, required=true},
      {key="notices", label="Notice Board", description="Trusted network notices, update notices, and admin notice controls.", profiles={Triumvirate=true, Ascension=true}, default=true, required=true},
      {key="invasions", label="Invasions", description="Triumvirate invasion beacons, grouping tools, and invasion listings.", profiles={Triumvirate=true, Ascension=false}, defaults={Triumvirate=true, Ascension=false}, toggleable=true},
      {key="ascensionListingTools", label="Ascension Listing Tools", description="Ascension Mythic+, Ascended raids, profile aliases, and compact dungeon selection.", profiles={Triumvirate=false, Ascension=true}, defaults={Triumvirate=false, Ascension=true}, required=true},
      {key="raidTools", label="Raid Tools", description="Reserved for a later raid-leader tools package.", profiles={Triumvirate=false, Ascension=false}, defaults={Triumvirate=false, Ascension=false}, unavailable="Deferred until after 1.5"},
    }

    local function sfmm_profile()
      if BLFG and BLFG.SF143_GetProfileId then
        local ok, id = pcall(function() return BLFG:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      return BronzeLFG_DB and BronzeLFG_DB.options and tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate") or "Triumvirate"
    end

    local function sfmm_options()
      BronzeLFG_DB = BronzeLFG_DB or {}
      if type(BronzeLFG_DB.options) ~= "table" then BronzeLFG_DB.options = {} end
      local o = BronzeLFG_DB.options
      if type(o.modules) ~= "table" then o.modules = {} end
      if type(o.modulesByProfile) ~= "table" then o.modulesByProfile = {} end
      if type(o.moduleSavedSettings) ~= "table" then o.moduleSavedSettings = {} end
      for _, profile in ipairs({"Triumvirate", "Ascension"}) do
        if type(o.modulesByProfile[profile]) ~= "table" then o.modulesByProfile[profile] = {} end
        if type(o.moduleSavedSettings[profile]) ~= "table" then o.moduleSavedSettings[profile] = {} end
      end
      o.modulesByProfile.Ascension.invasions = false
      return o
    end

    local function sfmm_def(key)
      for _, d in ipairs(SFMM_DEFS) do if d.key == key then return d end end
      return nil
    end

    local function sfmm_available(key, profile)
      local d = sfmm_def(key)
      profile = tostring(profile or sfmm_profile())
      return d and d.profiles and d.profiles[profile] == true or false
    end

    local function sfmm_default(key, profile)
      local d = sfmm_def(key)
      profile = tostring(profile or sfmm_profile())
      if not d then return false end
      if d.defaults and d.defaults[profile] ~= nil then return d.defaults[profile] == true end
      return d.default == true
    end

    local function sfmm_enabled(key, profile)
      local d = sfmm_def(key)
      profile = tostring(profile or sfmm_profile())
      if not d or not sfmm_available(key, profile) then return false end
      if d.required then return true end
      local o = sfmm_options()
      local mods = o.modulesByProfile[profile]
      local value = mods[key]
      if value == nil and key == "invasions" and profile == "Triumvirate" and o.modules.invasions ~= nil then value = o.modules.invasions end
      if value == nil then value = sfmm_default(key, profile) end
      if value ~= true then return false end
      if d.requires and not sfmm_enabled(d.requires, profile) then return false end
      return true
    end

    local function sfmm_status(key, profile)
      local d = sfmm_def(key)
      profile = tostring(profile or sfmm_profile())
      if not d then return "Unknown" end
      if not sfmm_available(key, profile) then return d.unavailable or ("Not supported on " .. profile) end
      if d.required then return "Required for " .. profile end
      if d.requires and not sfmm_enabled(d.requires, profile) then
        local dep = sfmm_def(d.requires)
        return "Requires " .. tostring(dep and dep.label or d.requires)
      end
      return sfmm_enabled(key, profile) and "Enabled" or "Disabled"
    end

    local function sfmm_apply_runtime()
      local o = sfmm_options()
      local profile = sfmm_profile()
      local saved = o.moduleSavedSettings[profile]

      if sfmm_enabled("chatParsing", profile) then
        if saved.chatCaptured then
          o.publicGroups = saved.publicGroups ~= false
          o.inlineChatLinks = saved.inlineChatLinks ~= false
          saved.chatCaptured = nil
        elseif o.publicGroups == nil then
          o.publicGroups = true
          o.inlineChatLinks = true
        end
      else
        if not saved.chatCaptured then
          saved.chatCaptured = true
          saved.publicGroups = o.publicGroups ~= false
          saved.inlineChatLinks = o.inlineChatLinks ~= false
        end
        o.publicGroups = false
        o.inlineChatLinks = false
      end

      if sfmm_enabled("guildBrowser", profile) then
        if saved.guildCaptured then
          o.parseGuildRecruitment = saved.parseGuildRecruitment ~= false
          saved.guildCaptured = nil
        elseif o.parseGuildRecruitment == nil then
          o.parseGuildRecruitment = true
        end
      else
        if not saved.guildCaptured then
          saved.guildCaptured = true
          saved.parseGuildRecruitment = o.parseGuildRecruitment ~= false
        end
        o.parseGuildRecruitment = false
        if BLFG.guildPanel then BLFG.guildPanel:Hide() end
      end

      if not sfmm_enabled("recruitmentCreator", profile) then
        if BLFG.RecruitmentCreator and BLFG.RecruitmentCreator.frame then BLFG.RecruitmentCreator.frame:Hide() end
        if BLFG.guildRecruitCreatorBtn then BLFG.guildRecruitCreatorBtn:Hide() end
        if BLFG.recruitCreatorBtn then BLFG.recruitCreatorBtn:Hide() end
      else
        if BLFG.guildRecruitCreatorBtn then BLFG.guildRecruitCreatorBtn:Show() end
        if BLFG.recruitCreatorBtn then BLFG.recruitCreatorBtn:Show() end
      end

      if profile == "Ascension" then o.modulesByProfile.Ascension.invasions = false end
      if not sfmm_enabled("invasions", profile) and BLFG.invasionPanel then BLFG.invasionPanel:Hide() end

      sfcp_apply_runtime()
      if BLFG.optPublic then BLFG.optPublic:SetChecked(o.publicGroups ~= false) end
      if BLFG.side and BLFG.BuildSide then pcall(function() BLFG:BuildSide() end) end
    end

    local function sfmm_set(key, enabled, quiet)
      local d = sfmm_def(key)
      local profile = sfmm_profile()
      if not d then return false end
      if not sfmm_available(key, profile) then
        if not quiet then sfcp_msg(d.label .. " is not available for " .. profile .. ".", 1, .45, .2) end
        return false
      end
      if d.required or not d.toggleable then
        if not quiet then sfcp_msg(d.label .. " is required for " .. profile .. ".", 1, .75, .2) end
        return false
      end
      if enabled and d.requires and not sfmm_enabled(d.requires, profile) then
        local dep = sfmm_def(d.requires)
        if not quiet then sfcp_msg(d.label .. " requires " .. tostring(dep and dep.label or d.requires) .. ".", 1, .45, .2) end
        return false
      end

      local o = sfmm_options()
      o.modulesByProfile[profile][key] = enabled == true
      if key == "guildBrowser" and enabled ~= true then o.modulesByProfile[profile].recruitmentCreator = false end
      sfmm_apply_runtime()
      return true
    end

    function BLFG:SFModuleDefaultEnabled(key) return sfmm_default(key) end
    function BLFG:SFModuleIsEnabled(key) return sfmm_enabled(key) end
    function BLFG:SFCore149_ModuleEnabled(key) return sfmm_enabled(key) end
    function BLFG:SFModuleSetEnabled(key, enabled) return sfmm_set(key, enabled, false) end
    function BLFG:SFModuleUseProfileDefault(key)
      local o = sfmm_options()
      o.modulesByProfile[sfmm_profile()][key] = nil
      sfmm_apply_runtime()
    end
    function BLFG:SFModulesApply() sfmm_apply_runtime(); return true end
    function BLFG:SFModulesStatusLine()
      local bits = {}
      for _, d in ipairs(SFMM_DEFS) do
        if sfmm_available(d.key) then table.insert(bits, d.label .. "=" .. (sfmm_enabled(d.key) and "on" or "off")) end
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
      }
      if sfmm_enabled("guildBrowser") then table.insert(items, {"Guild Browser", "Find guilds", "INV_Misc_TabardPVP_01", function() BLFG:ShowGuildBrowser() end}) end
      if sfmm_enabled("invasions") then table.insert(items, {"Invasions", "Nearby invasion groups", "INV_Misc_Head_Dragon_01", function() BLFG:ShowInvasions() end}) end
      table.insert(items, {"My Listing", "Manage your group", "INV_Misc_Book_09", function() BLFG:ShowMyListing() end})
      table.insert(items, {"Options", "Addon settings", "INV_Misc_Gear_01", function() BLFG:ShowOptions() end})
      table.insert(items, {"Network", "SignalFire users", "INV_Misc_GroupLooking", function() if BLFG.ShowSFNetwork then BLFG:ShowSFNetwork() else BLFG:ToggleOnlinePanel() end end})
      return items
    end

    local function sfmm_hide_legacy()
      local inv = BLFG.optModuleInvasions
      if not inv then return end
      inv:Hide()
      inv:Disable()
      if inv.EnableMouse then inv:EnableMouse(false) end
      local host = inv:GetParent()
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

    local function sfmm_refresh_panel()
      local f = BLFG.sfmmPanel
      if not f then return end
      local profile = sfmm_profile()
      f.profileText:SetText("Active profile: " .. profile)
      for _, d in ipairs(SFMM_DEFS) do
        local row = f.rows[d.key]
        if row then
          local available = sfmm_available(d.key, profile)
          local enabled = sfmm_enabled(d.key, profile)
          local canToggle = available and d.toggleable and not d.required and (not d.requires or sfmm_enabled(d.requires, profile))
          row.checkbox:SetChecked(enabled)
          if canToggle then row.checkbox:Enable(); row.checkbox:SetAlpha(1) else row.checkbox:Disable(); row.checkbox:SetAlpha(.45) end
          row.status:SetText(sfmm_status(d.key, profile))
          if enabled then row.status:SetTextColor(.45, 1, .45)
          elseif available then row.status:SetTextColor(1, .65, .2)
          else row.status:SetTextColor(.55, .55, .55) end
          row.label:SetAlpha(available and 1 or .48)
          row.description:SetAlpha(available and 1 or .48)
        end
      end
    end

    local function sfmm_build_panel()
      if BLFG.sfmmPanel then return BLFG.sfmmPanel end
      local p = BLFG.optionsPanel
      if not p then return nil end

      local f = CreateFrame("Frame", "SignalFireIntegratedModuleManager", p)
      BLFG.sfmmPanel = f
      f:SetAllPoints(p)
      f:SetFrameLevel(((p.GetFrameLevel and p:GetFrameLevel()) or 1) + 170)
      f:SetToplevel(true)
      f:EnableMouse(true)
      sfcp_flat(f, .985)
      sfcp_register_escape(f, "SignalFireIntegratedModuleManager")
      f:Hide()

      local title = sfcp_font(f, "Modules", 18, 1, .75, 0)
      title:SetPoint("TOP", f, "TOP", 0, -24)
      f.profileText = sfcp_font(f, "", 10, .45, .85, 1)
      f.profileText:SetPoint("TOP", title, "BOTTOM", 0, -8)

      local note = sfcp_font(f, "Profile-aware module settings. Changes apply immediately and are saved separately for Ascension and Triumvirate.", 10, .78, .84, .9)
      note:SetPoint("TOP", f.profileText, "BOTTOM", 0, -6)
      note:SetWidth(720)
      note:SetJustifyH("CENTER")

      local host = CreateFrame("Frame", nil, f)
      host:SetWidth(740)
      host:SetHeight(386)
      host:SetPoint("TOP", f, "TOP", 0, -82)
      host:SetFrameLevel(f:GetFrameLevel() + 5)
      sfcp_flat(host, .80)

      f.rows = {}
      for i, d in ipairs(SFMM_DEFS) do
        local rowKey = d.key
        local row = CreateFrame("Frame", nil, host)
        row:SetWidth(704)
        row:SetHeight(40)
        row:SetPoint("TOPLEFT", host, "TOPLEFT", 18, -12 - ((i - 1) * 44))
        row:SetFrameLevel(host:GetFrameLevel() + 5)

        local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cb:SetPoint("LEFT", row, "LEFT", 0, 0)
        cb:SetFrameLevel(row:GetFrameLevel() + 2)
        row.checkbox = cb

        row.label = sfcp_font(row, d.label, 11, 1, .92, .68)
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -2)
        row.description = sfcp_font(row, d.description, 9, .68, .72, .78)
        row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
        row.description:SetWidth(470)
        row.description:SetJustifyH("LEFT")
        row.status = sfcp_font(row, "", 9, .45, 1, .45)
        row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.status:SetWidth(190)
        row.status:SetJustifyH("RIGHT")

        cb:SetScript("OnClick", function(button)
          if not sfmm_set(rowKey, button:GetChecked() and true or false, true) then button:SetChecked(sfmm_enabled(rowKey)) end
          sfmm_refresh_panel()
          sfcp_set_status("Module settings saved.")
        end)
        f.rows[rowKey] = row
      end

      local reset = sfcp_button(f, "Reset Profile Defaults", 170, 28)
      reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 42, 30)
      reset:SetScript("OnClick", function()
        local o = sfmm_options()
        o.modulesByProfile[sfmm_profile()] = {}
        o.moduleSavedSettings[sfmm_profile()] = {}
        if sfmm_profile() == "Ascension" then o.modulesByProfile.Ascension.invasions = false end
        sfmm_apply_runtime()
        sfmm_refresh_panel()
      end)

      local back = sfcp_button(f, "Back to Options", 150, 28)
      back:SetPoint("BOTTOM", f, "BOTTOM", 0, 30)
      back:SetScript("OnClick", function() f:Hide() end)

      local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
      close:SetFrameLevel(f:GetFrameLevel() + 20)
      close:SetScript("OnClick", function() f:Hide() end)
      return f
    end

    function BLFG:SFMM_AddOptions()
      if not self.optionsPanel then return end
      local p = self.optionsPanel
      sfmm_hide_legacy()

      if not self.sfmmOpenButton then
        self.sfmmOpenButton = sfcp_button(p, "Modules", 132, 24)
        self.sfmmOpenButton:SetScript("OnClick", function()
          local f = sfmm_build_panel()
          sfmm_refresh_panel()
          if f then f:Show(); if f.Raise then f:Raise() end end
        end)
      end

      local function place(btn, offset, width)
        if not btn then return end
        btn:ClearAllPoints()
        btn:SetWidth(width or 120)
        btn:SetHeight(24)
        btn:SetPoint("TOPRIGHT", p, "TOPRIGHT", offset, -4)
        btn:Show()
        btn:Enable()
        btn:SetAlpha(1)
      end
      place(self.sfe141EventAlertButton, -18, 118)
      place(self.sfamPolishButton, -144, 124)
      place(self.sfn138FavoriteAlertButton, -276, 124)
      place(self.sfcpOpenButton, -408, 132)
      place(self.sfmmOpenButton, -548, 132)

      local inv = self.optModuleInvasions
      local host = inv and inv:GetParent() or nil
      if host and not self.sfmmBodyButton then
        self.sfmmBodyButton = sfcp_button(host, "Manage Modules", 150, 24)
        self.sfmmBodyButton:SetPoint("TOPLEFT", host, "TOPLEFT", 580, -248)
        self.sfmmBodyButton:SetScript("OnClick", function()
          local f = sfmm_build_panel()
          sfmm_refresh_panel()
          if f then f:Show(); if f.Raise then f:Raise() end end
        end)
        self.sfmmBodyNote = sfcp_font(host, "Profile-aware settings", 9, .70, .78, .88)
        self.sfmmBodyNote:SetPoint("TOPLEFT", host, "TOPLEFT", 582, -279)
      end
      if self.sfmmBodyButton then self.sfmmBodyButton:Show(); self.sfmmBodyButton:Enable(); self.sfmmBodyButton:SetAlpha(1) end
      if self.sfmmBodyNote then self.sfmmBodyNote:Show() end
    end

    SignalFireModuleRegistry = SignalFireModuleRegistry or {}
    SignalFireModuleRegistry.IsEnabled = sfmm_enabled
    SignalFireModuleRegistry.IsAvailable = sfmm_available
    SignalFireModuleRegistry.SetEnabled = sfmm_set
    SignalFireModuleRegistry.RefreshPanel = sfmm_refresh_panel
    SignalFireModuleRegistry.SafeApply = function() sfmm_apply_runtime(); return true end

    local SFCP_OldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = SFCP_OldBuildOptions and SFCP_OldBuildOptions(self, ...)
      self:SFCP_AddOptions()
      self:SFMM_AddOptions()
      return r
    end

    local SFCP_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFCP_OldShowOptions and SFCP_OldShowOptions(self, ...)
      self:SFCP_AddOptions()
      self:SFMM_AddOptions()
      if self.optPublic then self.optPublic:SetChecked(sfcp_ensure_options().publicGroups ~= false) end
      return r
    end

    function BLFG:SFCP_GetSettings()
      local o = sfcp_ensure_options()
      return {
        publicGroups = o.publicGroups ~= false,
        inlineChatLinks = o.inlineChatLinks ~= false,
        parseGuildRecruitment = o.parseGuildRecruitment ~= false,
        publicStrict = o.publicStrict ~= false,
        chatLinkScope = o.chatLinkScope,
      }
    end

    sfcp_apply_runtime()

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:SetScript("OnEvent", function()
      sfcp_apply_runtime()
      if BLFG and BLFG.SFCP_AddOptions then BLFG:SFCP_AddOptions() end
      if BLFG and BLFG.SFMM_AddOptions then BLFG:SFMM_AddOptions() end
      sfmm_apply_runtime()
    end)


    -- SignalFire 1.4.30a: integrated parser regression suite
    -- Kept inside this existing loaded module so stale TOC files cannot omit it.
    SignalFireParserRegression = SignalFireParserRegression or {}
    local SFPR = SignalFireParserRegression

    SFPR.tests = {
      {name="Molten Core abbreviation", text="LFM MC", type="Raid", activity="Molten Core"},
      {name="Molten Core with roles", text="LFM TANK/HEAL/DPS MC", type="Raid", activity="Molten Core"},
      {name="De Otha Side shorthand", text="LF1M De Otha Side", type="Dungeon", activity="Road to De Other Side", profile="Ascension"},
      {name="Vault shorthand", text="LF2M Vault Tank/Dps", type="Dungeon", activity="Vaults of Inquisition", profile="Ascension"},
      {name="Da Other Side shorthand", text="LFM DPS DA OTHER SIDE 10+", type="Dungeon", activity="Road to De Other Side", profile="Ascension"},
      {name="Icecrown abbreviation", text="LFM ICC 10 need heals", type="Raid", activity="Icecrown Citadel"},
      {name="Blackwing abbreviation", text="LFM BWL need DPS", type="Raid", activity="Blackwing Lair"},
      {name="Shadowfang abbreviation", text="LFM SFK need tank", type="Dungeon", activity="Shadowfang Keep"},
      {name="Halls of Lightning abbreviation", text="LFM HoL need healer", type="Dungeon", activity="Halls of Lightning"},
      {name="Zul'Farrak abbreviation", text="LFM ZF need DPS", type="Dungeon", activity="Zul'Farrak"},
      {name="Mythic+ named dungeon", text="LFM Mythic+ Road to De Other Side key 10", type="Key", activity="Road to De Other Side", profile="Ascension"},
      {name="Bracketed guild recruitment", text="Join <Pattern Recognition> today! We are recruiting for dungeons and raids.", kind="guild", guild="Pattern Recognition"},
      {name="All-caps guild recruitment", text="THREE INCHES UNBUFFED - FRESH GUILD RECRUITING FOR DUNGEONS, LEVELING, AND PVP!", kind="guild", guild="THREE INCHES UNBUFFED"},
      {name="Consider guild tag", text="Anyone that wants a guild tag, but no commitment, consider <Cobra Gym Purple Cobras>.", kind="guild", guild="Cobra Gym Purple Cobras"},
      {name="Ignore Kick promotion", text="https://kick.com/bean codebean recruiting", ignore=true},
      {name="Ignore Twitch promotion", text="twitch.tv/example recruiting tonight", ignore=true},
      {name="Ignore YouTube promotion", text="youtube.com/example recruiting viewers", ignore=true},
      {name="Ignore trade post", text="WTS MC carry cheap", ignore=true},
      {name="Ignore ordinary dungeon chatter", text="vault is fun", ignore=true},
      {name="Ignore vague role chatter", text="tank available", ignore=true},
      {name="Ignore guild-seeking LFM", text="LFM GERMAN GUILD PLS", ignore=true},
      {name="Ignore shorthand LF GUILD", text="LF GUILD", ignore=true},
      {name="Ignore described LF guild", text="LF HIGH RISK GUILD", ignore=true},
      {name="Ignore localized guild seeker", text="BUSCO GUILD NAMEKU", ignore=true},
      {name="RDF role-first LF", text="DPS 56 LF RDF SPAM", type="Dungeon", activity="Random Dungeon Finder"},
      {name="RDF LFG with level and aura", text="Lvl 43 (with aura) LFG RDF", type="Dungeon", activity="Random Dungeon Finder"},
      {name="Wailing Caverns numbered shorthand", text="LF2M WC NEED TANK/HEALS", type="Dungeon", activity="Wailing Caverns"},
      {name="RDF expanded LFM wording", text="LFM FOR RDF LVL 58 LOOKING FOR SOMEONE WITH EXP AURA NEAR MY LEVEL PST", type="Dungeon", activity="Random Dungeon Finder"},
      {name="Random Mythic Dungeon Finder", text="LFM Random Mythic Dungeon Finder need healer", type="Dungeon", activity="Random Mythic Dungeon Finder", profile="Ascension"},
      {name="Vault role-first LF", text="healer lf Vault", type="Dungeon", activity="Vaults of Inquisition", profile="Ascension"},
      {name="Vault numbered singular shorthand", text="LF3M VAULT", type="Dungeon", activity="Vaults of Inquisition", profile="Ascension"},
      {name="Dungeon abbreviation LFG", text="lvl 53Big aoe Star caller LFG Dung spam hat has aura", type="Dungeon", activity="Random Dungeon Finder"},
      {name="DF role-first shorthand", text="Stormbringer dps LF DF farming grp", type="Dungeon", activity="Random Dungeon Finder"},
    }

    local function sfpr_profile()
      if BLFG and BLFG.SF143_GetProfileId then
        local ok, id = pcall(function() return BLFG:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      return BronzeLFG_DB and BronzeLFG_DB.options and tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate") or "Triumvirate"
    end

    local function sfpr_lower(s)
      return string.lower(tostring(s or ""))
    end

    local function sfpr_same(a, b)
      return sfpr_lower(a) == sfpr_lower(b)
    end

    local function sfpr_actual(result)
      if not result then return "no result" end
      if not result.eligible then return "ignored" .. (result.reason and (" (" .. tostring(result.reason) .. ")") or "") end
      if result.kind == "guild" then return "Guild: " .. tostring(result.guild or result.activity or "?") end
      return tostring(result.type or "?") .. ": " .. tostring(result.activity or "?")
    end

    local function sfpr_expect(test)
      if test.ignore then return "Ignored" end
      if test.kind == "guild" then return "Guild: " .. tostring(test.guild) end
      return tostring(test.type or "Any") .. ": " .. tostring(test.activity or "Any")
    end

    local function sfpr_check(test, result)
      if test.ignore then return not (result and result.eligible) end
      if not result or not result.eligible then return false end
      if test.kind == "guild" then
        return result.kind == "guild" and sfpr_same(result.guild, test.guild)
      end
      if test.type and not sfpr_same(result.type, test.type) then return false end
      if test.activity and not sfpr_same(result.activity, test.activity) then return false end
      return true
    end

    local function sfpr_run_one(test, profile)
      if test.profile and test.profile ~= profile then
        return {status="SKIP", test=test, detail="Requires " .. tostring(test.profile) .. " profile"}
      end

      local fast
      local core
      local fastOK, fastErr = pcall(function()
        fast = SignalFireFastChatLinks and SignalFireFastChatLinks.TestParse and SignalFireFastChatLinks.TestParse(test.text)
      end)
      local coreOK, coreErr = pcall(function()
        core = BLFG.SF1430_CoreParseText and BLFG:SF1430_CoreParseText(test.text)
      end)

      if not fastOK then fast = {eligible=false, reason=tostring(fastErr)} end
      if not coreOK then core = {eligible=false, reason=tostring(coreErr)} end

      local fastPass = sfpr_check(test, fast)
      local corePass = sfpr_check(test, core)
      local status = fastPass and corePass and "PASS" or "FAIL"
      local detail = "Expected " .. sfpr_expect(test) .. " | Live " .. sfpr_actual(fast) .. " | Core " .. sfpr_actual(core)
      return {status=status, test=test, fast=fast, core=core, detail=detail}
    end

    function SFPR.Run()
      local profile = sfpr_profile()
      local results = {}
      local passed, failed, skipped = 0, 0, 0
      for _, test in ipairs(SFPR.tests) do
        local row = sfpr_run_one(test, profile)
        table.insert(results, row)
        if row.status == "PASS" then passed = passed + 1
        elseif row.status == "FAIL" then failed = failed + 1
        else skipped = skipped + 1 end
      end
      SFPR.last = {profile=profile, results=results, passed=passed, failed=failed, skipped=skipped, total=#results}
      return SFPR.last
    end

    local function sfpr_backdrop(frame, alpha)
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3},
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .96)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end

    local function sfpr_font(parent, size)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      if size and fs.SetFont then
        local path, _, flags = fs:GetFont()
        fs:SetFont(path or "Fonts\\FRIZQT__.TTF", size, flags or "")
      end
      return fs
    end

    local function sfpr_button(parent, text, width)
      local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      button:SetWidth(width or 110)
      button:SetHeight(26)
      button:SetText(text or "Button")
      return button
    end

    local function sfpr_register_escape(frame)
      _G.SignalFireParserRegressionFrame = frame
      if UISpecialFrames then
        local found = false
        for _, name in ipairs(UISpecialFrames) do if name == "SignalFireParserRegressionFrame" then found = true end end
        if not found then table.insert(UISpecialFrames, "SignalFireParserRegressionFrame") end
      end
    end

    function SFPR.BuildFrame()
      if SFPR.frame then return SFPR.frame end

      local frame = CreateFrame("Frame", "SignalFireParserRegressionFrame", UIParent)
      SFPR.frame = frame
      frame:SetWidth(860)
      frame:SetHeight(510)
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
      frame:SetFrameStrata("DIALOG")
      frame:SetToplevel(true)
      frame:SetMovable(true)
      frame:EnableMouse(true)
      frame:SetClampedToScreen(true)
      frame:RegisterForDrag("LeftButton")
      frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
      frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
      sfpr_backdrop(frame, .985)
      sfpr_register_escape(frame)

      frame.title = sfpr_font(frame, 18)
      frame.title:SetText("SignalFire Parser Regression Tests")
      frame.title:SetTextColor(1, .75, 0)
      frame.title:SetPoint("TOP", frame, "TOP", 0, -18)

      frame.summary = sfpr_font(frame, 11)
      frame.summary:SetPoint("TOP", frame.title, "BOTTOM", 0, -8)
      frame.summary:SetWidth(810)
      frame.summary:SetJustifyH("CENTER")

      frame.note = sfpr_font(frame, 9)
      frame.note:SetText("Runs locally against both parser paths. It does not post chat, create listings, or alter your settings.")
      frame.note:SetTextColor(.65, .85, 1)
      frame.note:SetPoint("TOP", frame.summary, "BOTTOM", 0, -5)

      frame.rows = {}
      for i = 1, 10 do
        local row = CreateFrame("Frame", nil, frame)
        row:SetWidth(820)
        row:SetHeight(34)
        row:SetPoint("TOP", frame, "TOP", 0, -92 - ((i - 1) * 35))
        sfpr_backdrop(row, i % 2 == 0 and .72 or .58)

        row.status = sfpr_font(row, 10)
        row.status:SetPoint("LEFT", row, "LEFT", 8, 6)
        row.status:SetWidth(42)
        row.status:SetJustifyH("LEFT")

        row.name = sfpr_font(row, 10)
        row.name:SetPoint("LEFT", row, "LEFT", 58, 6)
        row.name:SetWidth(235)
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(1, .88, .55)

        row.detail = sfpr_font(row, 9)
        row.detail:SetPoint("LEFT", row, "LEFT", 58, -8)
        row.detail:SetWidth(748)
        row.detail:SetJustifyH("LEFT")
        row.detail:SetTextColor(.86, .86, .86)

        frame.rows[i] = row
      end

      frame.pageText = sfpr_font(frame, 10)
      frame.pageText:SetPoint("BOTTOM", frame, "BOTTOM", 0, 49)
      frame.pageText:SetTextColor(.8, .8, .8)

      frame.prev = sfpr_button(frame, "Previous", 90)
      frame.prev:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
      frame.prev:SetScript("OnClick", function()
        SFPR.page = math.max(1, (SFPR.page or 1) - 1)
        SFPR.Refresh()
      end)

      frame.next = sfpr_button(frame, "Next", 90)
      frame.next:SetPoint("LEFT", frame.prev, "RIGHT", 8, 0)
      frame.next:SetScript("OnClick", function()
        SFPR.page = math.min(SFPR.pages or 1, (SFPR.page or 1) + 1)
        SFPR.Refresh()
      end)

      frame.run = sfpr_button(frame, "Run Again", 110)
      frame.run:SetPoint("BOTTOM", frame, "BOTTOM", -58, 18)
      frame.run:SetScript("OnClick", function()
        SFPR.Run()
        SFPR.page = 1
        SFPR.Refresh()
      end)

      frame.close = sfpr_button(frame, "Close", 110)
      frame.close:SetPoint("LEFT", frame.run, "RIGHT", 8, 0)
      frame.close:SetScript("OnClick", function() frame:Hide() end)

      local x = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      x:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
      x:SetScript("OnClick", function() frame:Hide() end)

      frame:Hide()
      return frame
    end

    function SFPR.Refresh()
      local frame = SFPR.BuildFrame()
      local data = SFPR.last or SFPR.Run()
      local pageSize = #frame.rows
      SFPR.pages = math.max(1, math.ceil(#data.results / pageSize))
      SFPR.page = math.max(1, math.min(SFPR.page or 1, SFPR.pages))

      local summaryColor = data.failed == 0 and "|cff55ff55" or "|cffff5555"
      frame.summary:SetText(summaryColor .. tostring(data.passed) .. " passed|r  |  |cffff5555" .. tostring(data.failed) .. " failed|r  |  |cffffff55" .. tostring(data.skipped) .. " skipped|r  |  Profile: |cffffffff" .. tostring(data.profile) .. "|r")

      local startIndex = ((SFPR.page - 1) * pageSize) + 1
      for i, row in ipairs(frame.rows) do
        local result = data.results[startIndex + i - 1]
        if result then
          row:Show()
          row.status:SetText(result.status)
          if result.status == "PASS" then row.status:SetTextColor(.35, 1, .35)
          elseif result.status == "FAIL" then row.status:SetTextColor(1, .3, .3)
          else row.status:SetTextColor(1, .9, .3) end
          row.name:SetText(tostring(result.test.name or "Test"))
          row.detail:SetText(tostring(result.detail or ""))
        else
          row:Hide()
        end
      end

      frame.pageText:SetText("Page " .. tostring(SFPR.page) .. " of " .. tostring(SFPR.pages))
      if SFPR.page <= 1 then frame.prev:Disable() else frame.prev:Enable() end
      if SFPR.page >= SFPR.pages then frame.next:Disable() else frame.next:Enable() end
    end

    function SFPR.Show()
      SFPR.Run()
      SFPR.page = 1
      local frame = SFPR.BuildFrame()
      SFPR.Refresh()
      frame:Show()
      if frame.Raise then frame:Raise() end
    end



    -- SignalFire 1.4.30b: regression corrections discovered by the 1.4.30 suite.
    do
      local sfcp1430bOldExtractGuildName = extractGuildNameFromPost
      function extractGuildNameFromPost(group)
        local raw = tostring(group and group.message or "")
        local low = string.lower(raw)
        local marker = string.find(low, " - fresh guild recruiting", 1, true)
        if marker and marker > 1 then
          local name = string.sub(raw, 1, marker - 1)
          name = string.gsub(name, "^%s+", "")
          name = string.gsub(name, "%s+$", "")
          if name ~= "" and string.len(name) <= 64 then return name end
        end
        if sfcp1430bOldExtractGuildName then return sfcp1430bOldExtractGuildName(group) end
        return nil
      end

      local sfcp1430bOldCoreProbe = BLFG.SF1430_CoreParseText
      function BLFG:SF1430_CoreParseText(text)
        local result = sfcp1430bOldCoreProbe and sfcp1430bOldCoreProbe(self, text) or nil
        if not result or not result.eligible then return result end

        if result.activity == "Icecrown Citadel" then
          result.type = "Raid"
          result.kind = "group"
        elseif result.activity == "Halls of Lightning" then
          result.type = "Dungeon"
          result.kind = "group"
        end

        if result.kind == "guild" and (not result.guild or result.guild == "" or result.guild == "Guild Recruitment") then
          local ok, parsed = pcall(function()
            return SignalFireFastChatLinks and SignalFireFastChatLinks.TestParse and SignalFireFastChatLinks.TestParse(text)
          end)
          if ok and parsed and parsed.eligible and parsed.kind == "guild" and parsed.guild and parsed.guild ~= "" then
            result.guild = parsed.guild
          end
        end

        return result
      end
    end
  until true
end



-- SignalFire 1.5.1 Phase 1: Public Groups and Network correctness.
do
  local B = _G.BronzeLFG
  if B and not B._sf151CorrectnessInstalled then
    B._sf151CorrectnessInstalled = true

    local function sf151_now()
      if time then return time() end
      if GetTime then return math.floor(GetTime()) end
      return 0
    end

    local function sf151_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      s = string.gsub(s, "%s+", " ")
      return s
    end

    local function sf151_norm(s)
      s = string.lower(tostring(s or ""))
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "[%p%s]+", " ")
      return sf151_trim(s)
    end

    local function sf151_player(s)
      return string.lower(sf151_trim(tostring(s or ""):gsub("%-.*$", "")))
    end

    function B:SF151_IsGuildSeeking(text)
      local raw = tostring(text or "")
      local s = " " .. sf151_norm(raw) .. " "

      local guildWords = {" guild ", " guilds ", " gremio ", " gremios ", " gilde ", " guilde "}
      local guildPos = nil
      for _, word in ipairs(guildWords) do
        local pos = string.find(s, word, 1, true)
        if pos and (not guildPos or pos < guildPos) then guildPos = pos end
      end
      if not guildPos then return false end

      -- Real recruitment language wins. This keeps posts such as
      -- "Guild LF members" and "<Guild> is recruiting" valid.
      local recruiting = string.find(s, " recruit", 1, true) or string.find(s, " recrutement", 1, true)
        or string.find(s, " recruiting", 1, true) or string.find(s, " looking for members", 1, true)
        or string.find(s, " seeking members", 1, true) or string.find(s, " accepting members", 1, true)
        or string.find(s, " need members", 1, true) or string.find(s, " needs members", 1, true)
        or string.find(s, " lf members", 1, true) or string.find(s, " lfm members", 1, true)
        or string.find(s, " pst me for an invite", 1, true) or string.find(s, " whisper for invite", 1, true)
        or string.find(s, " join us", 1, true) or string.find(s, " join our", 1, true)
        or string.find(s, " guild is looking for", 1, true) or string.find(raw, "<[^>]+>")
      if recruiting then return false end

      -- A player seeking a guild can place any number of descriptors between
      -- the intent and the word guild: "lf high risk guild", "lf active pvp guild", etc.
      local seekerPhrases = {
        " lf ", " lfg ", " lfm ", " looking for ", " searching for ", " seeking ",
        " need ", " want ", " wants ", " any ", " busco ", " buscando ",
        " procuro ", " procurando ", " cherche ", " recherche ", " suche "
      }
      for _, phrase in ipairs(seekerPhrases) do
        local seekPos = string.find(s, phrase, 1, true)
        if seekPos and seekPos < guildPos then return true end
      end

      if string.find(s, " guild pls ", 1, true) or string.find(s, " guild please ", 1, true)
        or string.find(s, " guild inv ", 1, true) or string.find(s, " any guild ", 1, true)
        or string.find(s, " gremio pls ", 1, true) or string.find(s, " gremio please ", 1, true) then
        return true
      end

      local compact = sf151_trim(s)
      if compact == "guild" or compact == "gremio" or compact == "gilde" or compact == "guilde" then
        return true
      end
      return false
    end

    local function sf151_chat_row(id, row)
      if not row then return false end
      if row.signalFireListing or row.isInvasionBeacon then return false end
      id = tostring(id or row.id or row.key or "")
      if string.find(id, "^listing%-") or string.find(id, "^INVASION%-") then return false end
      return true
    end

    local function sf151_row_rank(row)
      local rank = tonumber(row and row.score or 0) or 0
      if row and not row.fastChatLink then rank = rank + 1000 end
      if row and not row.sessionOnly then rank = rank + 100 end
      return rank
    end

    local function sf151_merge_row(dst, src)
      if not (dst and src) then return end
      local fields = {"player", "message", "rawMessage", "channel", "type", "activity", "roles", "intent", "tags", "ilevel", "score"}
      for _, field in ipairs(fields) do
        if (dst[field] == nil or dst[field] == "") and src[field] ~= nil and src[field] ~= "" then dst[field] = src[field] end
      end
      local dc = tonumber(dst.created or dst.firstSeen or 0) or 0
      local sc = tonumber(src.created or src.firstSeen or 0) or 0
      if dc <= 0 or (sc > 0 and sc < dc) then dst.created = sc; dst.firstSeen = sc end
      local ds = tonumber(dst.seen or 0) or 0
      local ss = tonumber(src.seen or 0) or 0
      if ss > ds then dst.seen = ss end
    end

    function B:SF151_ReconcilePublicGroups(author, text)
      local groups = self.publicGroups
      if type(groups) ~= "table" then return nil end
      local wantedPlayer = sf151_player(author)
      local wantedMessage = sf151_norm(text)
      local buckets = {}

      for id, row in pairs(groups) do
        if sf151_chat_row(id, row) then
          local player = sf151_player(row.player or row.author)
          local message = sf151_norm(row.rawMessage or row.message)
          if player ~= "" and message ~= ""
            and (wantedPlayer == "" or player == wantedPlayer)
            and (wantedMessage == "" or message == wantedMessage) then
            local signature = player .. "\031" .. message
            local bucket = buckets[signature]
            if not bucket then bucket = {}; buckets[signature] = bucket end
            table.insert(bucket, {id=id, row=row})
          end
        end
      end

      local changed = false
      local kept = nil
      for _, bucket in pairs(buckets) do
        if #bucket > 0 then
          local best = bucket[1]
          for i = 2, #bucket do
            local candidate = bucket[i]
            local br = sf151_row_rank(best.row)
            local cr = sf151_row_rank(candidate.row)
            local bs = tonumber(best.row and best.row.seen or 0) or 0
            local cs = tonumber(candidate.row and candidate.row.seen or 0) or 0
            if cr > br or (cr == br and cs > bs) then best = candidate end
          end
          kept = best.row
          for _, candidate in ipairs(bucket) do
            if candidate.id ~= best.id then
              sf151_merge_row(best.row, candidate.row)
              groups[candidate.id] = nil
              if self.selectedPublic == candidate.id then self.selectedPublic = best.id end
              changed = true
            end
          end
        end
      end

      if changed then
        self._publicGroupsDirty = true
        if self.RequestPublicGroupsRefresh then self:RequestPublicGroupsRefresh() end
      end
      return kept
    end

    local oldAdd = B.AddPublicGroup
    function B:AddPublicGroup(author, text, channelName)
      if self:SF151_IsGuildSeeking(text) then return nil end
      local result = oldAdd and oldAdd(self, author, text, channelName) or nil
      if result then self:SF151_ReconcilePublicGroups(author, text) end
      return result
    end

    local oldNotify = B.NotifyForPublicGroup
    function B:NotifyForPublicGroup(row)
      if not row then return end
      local signature = sf151_player(row.player) .. "\031" .. sf151_norm(row.type) .. "\031" .. sf151_norm(row.activity) .. "\031" .. sf151_norm(row.rawMessage or row.message)
      local stamp = sf151_now()
      self._sf151AlertSeen = self._sf151AlertSeen or {}
      local last = tonumber(self._sf151AlertSeen[signature] or 0) or 0
      if signature ~= "\031\031\031" and last > 0 and (stamp - last) < 15 then return end
      self._sf151AlertSeen[signature] = stamp
      local scanned = 0
      for key, seen in pairs(self._sf151AlertSeen) do
        scanned = scanned + 1
        if scanned > 120 then break end
        if (stamp - (tonumber(seen or 0) or 0)) > 120 then self._sf151AlertSeen[key] = nil end
      end
      if oldNotify then return oldNotify(self, row) end
    end

    local oldCoreProbe = B.SF1430_CoreParseText
    function B:SF1430_CoreParseText(text)
      if self:SF151_IsGuildSeeking(text) then
        return {input=tostring(text or ""), eligible=false, kind="ignored", reason="Guild-seeking message"}
      end
      return oldCoreProbe and oldCoreProbe(self, text) or nil
    end

    if SignalFireFastChatLinks and SignalFireFastChatLinks.TestParse then
      local oldFastProbe = SignalFireFastChatLinks.TestParse
      function SignalFireFastChatLinks.TestParse(text)
        if B:SF151_IsGuildSeeking(text) then
          return {input=tostring(text or ""), eligible=false, kind="ignored", reason="Guild-seeking message"}
        end
        return oldFastProbe(text)
      end
    end

    local frame = CreateFrame and CreateFrame("Frame") or nil
    if frame then
      frame:RegisterEvent("PLAYER_LOGIN")
      frame:RegisterEvent("PLAYER_ENTERING_WORLD")
      frame:SetScript("OnEvent", function()
        if B.publicGroups then
          for id, row in pairs(B.publicGroups) do
            if sf151_chat_row(id, row) and B:SF151_IsGuildSeeking(row.rawMessage or row.message) then
              B.publicGroups[id] = nil
              if B.selectedPublic == id then B.selectedPublic = nil end
            end
          end
          B:SF151_ReconcilePublicGroups()
        end
      end)
    end
  end
end

-- SignalFire 1.5.1 Phase 3f: align the full parser probe with the enhanced
-- live-link classifier for CoA shorthand. This does not add another chat hook.
do
  local B = _G.BronzeLFG
  if B and not B._sf151Phase3fCoreAlignment then
    B._sf151Phase3fCoreAlignment = true
    local oldCoreProbe = B.SF1430_CoreParseText
    function B:SF1430_CoreParseText(text)
      local result = oldCoreProbe and oldCoreProbe(self, text) or nil
      local fast = SignalFireFastChatLinks and SignalFireFastChatLinks.TestParse and SignalFireFastChatLinks.TestParse(text) or nil
      if fast and fast.eligible then
        result = result or {}
        result.input = tostring(text or "")
        result.eligible = true
        result.kind = fast.kind
        result.type = fast.type
        result.activity = fast.activity
        result.roles = fast.roles
        if fast.guild and fast.guild ~= "" then result.guild = fast.guild end
        result.reason = nil
      end
      return result
    end
  end
end
