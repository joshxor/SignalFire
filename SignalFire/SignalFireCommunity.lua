-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Recruitment
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SF139_VERSION = _G.SignalFire_VERSION or "1.4.23"
    local SF139_DEFAULT_CHANNEL = "Global-Guild-Recruitment"
    local SF139_FALLBACK_CHANNEL = "Global-Guild-Recruitment"

    BLFG.SignalFireRecruitmentVersion = SF139_VERSION
    BLFG.version = SF139_VERSION

    local function sf139_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sf139_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sf139_clean(s, maxLen)
      s = sf139_trim(s)
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
      s = string.gsub(s, "|h(%b[])|h", "%1")
      s = string.gsub(s, "[~|\r\n]", " ")
      s = string.gsub(s, "%s+", " ")
      maxLen = tonumber(maxLen) or 0
      if maxLen > 0 and string.len(s) > maxLen then s = string.sub(s, 1, maxLen) end
      return sf139_trim(s)
    end

    local function sf139_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sf139_ensure_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.recruitmentCreator = BronzeLFG_DB.recruitmentCreator or {}
      local db = BronzeLFG_DB.recruitmentCreator
      db.templates = db.templates or {}
      -- Triumvirate uses a single guild recruitment channel. Keep this locked so the
      -- creator does not expose redundant Guild/Global/BLFG choices or fall back to
      -- the wrong channel.
      db.broadcastChannel = SF139_DEFAULT_CHANNEL
      return db
    end

    local function sf139_copy_map(src)
      local out = {}
      for k, v in pairs(src or {}) do
        if v then out[k] = true end
      end
      return out
    end

    local function sf139_join_selected(map)
      local out = {}
      for k, v in pairs(map or {}) do
        if v then table.insert(out, tostring(k)) end
      end
      table.sort(out)
      return table.concat(out, ", ")
    end

    local function sf139_rc()
      sf139_ensure_db()
      BLFG.RecruitmentCreator = BLFG.RecruitmentCreator or {}
      return BLFG.RecruitmentCreator
    end

    local function sf139_set_frame_level(frame, level)
      if not frame or not frame.SetFrameLevel then return end
      frame:SetFrameLevel(level)
    end

    local function sf139_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 80)
      b:SetHeight(h or 22)
      b:SetText(tostring(text or "Button"))
      return b
    end

    local function sf139_font(parent, text, template, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end

    local function sf139_unique_insert(t, value)
      value = sf139_clean(value, 60)
      if value == "" then return end
      local lv = sf139_low(value)
      for _, v in ipairs(t) do
        if sf139_low(v) == lv then return end
      end
      table.insert(t, value)
    end

    local function sf139_channel_candidates(preferred)
      local out = {}
      -- Do not rotate through Guild/Global/BLFG anymore. The Triumvirate recruitment
      -- channel is Global-Guild-Recruitment. If it is missing, join it and ask the
      -- user to retry instead of broadcasting to the wrong place.
      sf139_unique_insert(out, SF139_DEFAULT_CHANNEL)
      return out
    end

    local function sf139_find_channel(preferred)
      if not GetChannelName then return nil, nil end
      for _, name in ipairs(sf139_channel_candidates(preferred)) do
        local id = GetChannelName(name)
        if id and id ~= 0 then return id, name end
      end
      return nil, nil
    end

    function BLFG:SF139_BuildRecruitmentBroadcast()
      local rc = sf139_rc()
      local guild = sf139_clean((rc.guildEdit and rc.guildEdit:GetText()) or (GetGuildInfo and GetGuildInfo("player")) or "", 42)
      local notes = sf139_clean((rc.notesEdit and rc.notesEdit:GetText()) or "", 210)
      local discord = sf139_clean((rc.discordEdit and rc.discordEdit:GetText()) or "", 80)
      local roles = sf139_clean(sf139_join_selected(rc.roles), 120)
      local activities = sf139_clean(sf139_join_selected(rc.activities), 120)
      local omittedDiscord = false
      local clipped = false

      if guild == "" then guild = "Guild" end

      local msg
      if notes ~= "" then
        if string.find(sf139_low(notes), sf139_low(guild), 1, true) then
          msg = notes
        else
          msg = "<" .. guild .. "> " .. notes
        end
      else
        msg = "<" .. guild .. "> Recruiting!"
      end

      if roles ~= "" and not string.find(sf139_low(msg), sf139_low(roles), 1, true) then
        local add = " Looking for: " .. roles .. "."
        if string.len(msg .. add) <= 255 then msg = msg .. add end
      end

      if activities ~= "" and not string.find(sf139_low(msg), sf139_low(activities), 1, true) then
        local add = " Activities: " .. activities .. "."
        if string.len(msg .. add) <= 255 then msg = msg .. add end
      end

      if discord ~= "" and not string.find(sf139_low(msg), sf139_low(discord), 1, true) then
        local add = " Discord: " .. discord
        if string.len(msg .. add) <= 255 then
          msg = msg .. add
        else
          omittedDiscord = true
        end
      end

      msg = sf139_clean(msg, 0)
      if string.len(msg) > 255 then
        msg = string.sub(msg, 1, 252) .. "..."
        clipped = true
      end
      return msg, clipped, omittedDiscord
    end

    function BLFG:SF139_GetRecruitmentChannel()
      local db = sf139_ensure_db()
      db.broadcastChannel = SF139_DEFAULT_CHANNEL
      return SF139_DEFAULT_CHANNEL
    end

    function BLFG:SF139_SetRecruitmentChannel(channelName)
      local db = sf139_ensure_db()
      local rc = sf139_rc()
      db.broadcastChannel = SF139_DEFAULT_CHANNEL
      if rc.channelEdit and rc.channelEdit.SetText then rc.channelEdit:SetText(SF139_DEFAULT_CHANNEL) end
      if self.SF139_UpdateRecruitmentUI then self:SF139_UpdateRecruitmentUI() end
      sf139_msg("Recruitment broadcast channel locked to: " .. SF139_DEFAULT_CHANNEL, .4, 1, .4)
    end

    function BLFG:SF139_SendRecruitmentBroadcast()
      local db = sf139_ensure_db()
      local preferred = self:SF139_GetRecruitmentChannel()
      local payload, clipped, omittedDiscord = self:SF139_BuildRecruitmentBroadcast()
      if payload == "" then
        sf139_msg("Nothing to broadcast yet. Add a guild name or recruitment pitch first.", 1, .35, .35)
        return false
      end

      local id, channelName = sf139_find_channel(preferred)
      if id and id ~= 0 and SendChatMessage then
        SendChatMessage(payload, "CHANNEL", nil, id)
        db.broadcastChannel = preferred
        sf139_msg("Broadcast sent to /" .. tostring(channelName) .. " (" .. tostring(string.len(payload)) .. "/255).", .4, 1, .4)
        if channelName ~= preferred then
          sf139_msg("Preferred channel /" .. tostring(preferred) .. " was not found; used /" .. tostring(channelName) .. " fallback.", 1, .82, .35)
        end
        if clipped then sf139_msg("Broadcast was shortened to fit the WoW chat limit.", 1, .82, .35) end
        if omittedDiscord then sf139_msg("Discord/link stayed in the full Guild Browser listing but did not fit in chat.", 1, .82, .35) end
        return true
      end

      if JoinChannelByName then
        JoinChannelByName(SF139_DEFAULT_CHANNEL)
      end
      sf139_msg("Could not find /" .. tostring(SF139_DEFAULT_CHANNEL) .. ". I tried joining it; try Broadcast again in a moment.", 1, .35, .35)
      return false
    end

    function BLFG:SF139_SaveRecruitmentTemplate()
      local rc = sf139_rc()
      local db = sf139_ensure_db()
      local name = sf139_clean((rc.templateName and rc.templateName:GetText()) or "", 40)
      if name == "" then name = sf139_clean((rc.guildEdit and rc.guildEdit:GetText()) or "Recruitment", 32) end
      if name == "" then name = "Recruitment" end
      db.templates[name] = {
        guild = (rc.guildEdit and rc.guildEdit:GetText()) or "",
        discord = (rc.discordEdit and rc.discordEdit:GetText()) or "",
        notes = (rc.notesEdit and rc.notesEdit:GetText()) or "",
        activities = sf139_copy_map(rc.activities),
        roles = sf139_copy_map(rc.roles),
        channel = SF139_DEFAULT_CHANNEL,
        saved = (time and time()) or 0,
      }
      db.lastTemplate = name
      if rc.templateName then rc.templateName:SetText(name) end
      sf139_msg("Saved recruitment template: " .. name, .4, 1, .4)
    end

    function BLFG:SF139_LoadRecruitmentTemplate()
      local rc = sf139_rc()
      local db = sf139_ensure_db()
      local name = sf139_clean((rc.templateName and rc.templateName:GetText()) or db.lastTemplate or "", 40)
      local tpl = name ~= "" and db.templates and db.templates[name] or nil
      if not tpl then
        for k, v in pairs(db.templates or {}) do name = k; tpl = v; break end
      end
      if not tpl then
        sf139_msg("No recruitment templates saved yet.", 1, .82, .35)
        return
      end
      if rc.guildEdit then rc.guildEdit:SetText(tpl.guild or "") end
      if rc.discordEdit then rc.discordEdit:SetText(tpl.discord or "") end
      if rc.notesEdit then rc.notesEdit:SetText(tpl.notes or "") end
      rc.activities = sf139_copy_map(tpl.activities)
      rc.roles = sf139_copy_map(tpl.roles)
      if rc.activityChecks then for k, cb in pairs(rc.activityChecks) do cb:SetChecked(rc.activities[k] and true or false) end end
      if rc.roleChecks then for k, cb in pairs(rc.roleChecks) do cb:SetChecked(rc.roles[k] and true or false) end end
      if rc.templateName then rc.templateName:SetText(name) end
      self:SF139_SetRecruitmentChannel(SF139_DEFAULT_CHANNEL)
      db.lastTemplate = name
      if self.RefreshRecruitmentPreview then self:RefreshRecruitmentPreview() end
      if self.SF139_UpdateRecruitmentUI then self:SF139_UpdateRecruitmentUI() end
      sf139_msg("Loaded recruitment template: " .. name, .4, 1, .4)
    end

    function BLFG:SF139_DeleteRecruitmentTemplate()
      local rc = sf139_rc()
      local db = sf139_ensure_db()
      local name = sf139_clean((rc.templateName and rc.templateName:GetText()) or db.lastTemplate or "", 40)
      if name ~= "" and db.templates and db.templates[name] then
        db.templates[name] = nil
        if db.lastTemplate == name then db.lastTemplate = nil end
        if rc.templateName then rc.templateName:SetText("") end
        sf139_msg("Deleted recruitment template: " .. name, 1, .82, .35)
      else
        sf139_msg("Template not found.", 1, .35, .35)
      end
    end

    -- Keep the legacy NetworkPlus helper names working, but harden them for 1.3.9.
    BLFG.SFN_SaveRecruitmentTemplate = function(self, ...) return self:SF139_SaveRecruitmentTemplate(...) end
    BLFG.SFN_LoadRecruitmentTemplate = function(self, ...) return self:SF139_LoadRecruitmentTemplate(...) end
    BLFG.SFN_DeleteRecruitmentTemplate = function(self, ...) return self:SF139_DeleteRecruitmentTemplate(...) end

    function BLFG:SF139_UpdateRecruitmentUI()
      local rc = sf139_rc()
      local db = sf139_ensure_db()
      db.broadcastChannel = SF139_DEFAULT_CHANNEL
      if rc.channelEdit and rc.channelEdit.SetText then
        if rc.channelEdit:GetText() ~= SF139_DEFAULT_CHANNEL then rc.channelEdit:SetText(SF139_DEFAULT_CHANNEL) end
      end
      -- 1.4.0d: the separate Broadcast Preview stays removed because it duplicated the
      -- normal Preview and consumed the exact space needed by templates/channel/buttons.
      -- Keep only the useful part: the outgoing chat character count for the 255-safe
      -- broadcast payload.
      local payload = self:SF139_BuildRecruitmentBroadcast()
      if rc.broadcastPreview then rc.broadcastPreview:SetText("") end
      if rc.broadcastCount then
        local n = string.len(payload or "")
        if n <= 230 then rc.broadcastCount:SetText("|cff44ff44" .. tostring(n) .. " / 255|r")
        elseif n <= 255 then rc.broadcastCount:SetText("|cffffff66" .. tostring(n) .. " / 255|r")
        else rc.broadcastCount:SetText("|cffff4444" .. tostring(n) .. " / 255|r") end
      end
      if rc.channelStatus then rc.channelStatus:SetText("") end
    end

    local function sf139_child_text(child)
      if child and child.GetText then return child:GetText() end
      return nil
    end

    local function sf139_hook_broadcast_button(frame)
      if not frame or not frame.GetChildren then return end
      for _, child in ipairs({frame:GetChildren()}) do
        local text = sf139_child_text(child)
        if text == "Broadcast" or text == "Broadcast Chat" then
          child:SetText("Broadcast")
          child:SetScript("OnClick", function() BLFG:SF139_SendRecruitmentBroadcast() end)
          BLFG.RecruitmentCreator.sf139BroadcastButton = child
        end
      end
    end

    local function sf139_find_region_text(frame, text)
      if not frame or not frame.GetRegions then return nil end
      for _, r in ipairs({frame:GetRegions()}) do
        if r and r.GetText and r:GetText() == text then return r end
      end
      return nil
    end

    local function sf139_find_button(frame, text)
      if not frame or not frame.GetChildren then return nil end
      for _, child in ipairs({frame:GetChildren()}) do
        if child and child.GetText and child:GetText() == text then return child end
      end
      return nil
    end

    local function sf139_hide_broadcast_preview(rc, f)
      if rc.broadcastPreview then
        local parent = rc.broadcastPreview.GetParent and rc.broadcastPreview:GetParent() or nil
        if rc.broadcastPreview.Hide then rc.broadcastPreview:Hide() end
        if parent and parent ~= f and parent.Hide then parent:Hide() end
      end
      local pl = sf139_find_region_text(f, "Broadcast Preview")
      if pl and pl.Hide then pl:Hide() end
    end

    local function sf139_move_to(frame, point, rel, relPoint, x, y)
      if not frame then return end
      if frame.ClearAllPoints then frame:ClearAllPoints() end
      if frame.SetPoint then frame:SetPoint(point, rel, relPoint, x, y) end
    end

    function BLFG:SF139_EnhanceRecruitmentCreator()
      local rc = sf139_rc()
      local f = rc.frame
      if not f then return end
      sf139_ensure_db()

      -- 1.4.0d: keep the creator readable and stop stacking controls at the bottom.
      -- The normal Preview remains the readable listing preview. Broadcast uses a
      -- 255-safe version of that text, represented only by the character counter.
      if f.SetHeight then f:SetHeight(560) end
      sf139_hook_broadcast_button(f)
      sf139_hide_broadcast_preview(rc, f)

      -- Remove the old quick channel buttons if any older 1.3.9 build created them.
      if rc.sf139GuildBtn then rc.sf139GuildBtn:Hide() end
      if rc.sf139GlobalBtn then rc.sf139GlobalBtn:Hide() end
      if rc.sf139BLFGBtn then rc.sf139BLFGBtn:Hide() end

      if rc.channelEdit and rc.channelEdit.SetText then
        rc.channelEdit:SetText(SF139_DEFAULT_CHANNEL)
        rc.channelEdit:SetWidth(230)
        rc.channelEdit:SetAutoFocus(false)
        if rc.channelEdit.EnableMouse then rc.channelEdit:EnableMouse(false) end
        if rc.channelEdit.ClearFocus then rc.channelEdit:ClearFocus() end
      end

      -- Reposition existing NetworkPlus template/channel controls into three clean
      -- rows above the original bottom buttons.
      local templateLabel = sf139_find_region_text(f, "Template")
      local channelLabel = sf139_find_region_text(f, "Channel")
      local loadTpl = sf139_find_button(f, "Load")
      local saveTpl = sf139_find_button(f, "Save")
      local delTpl = sf139_find_button(f, "Del")
      local loadExisting = sf139_find_button(f, "Load Existing")
      local broadcast = sf139_find_button(f, "Broadcast")
      local publish = sf139_find_button(f, "Publish Listing")

      sf139_move_to(templateLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", 30, 96)
      sf139_move_to(rc.templateName, "LEFT", templateLabel or f, templateLabel and "RIGHT" or "BOTTOMLEFT", templateLabel and 8 or 88, templateLabel and 0 or 96)
      sf139_move_to(loadTpl, "LEFT", rc.templateName or f, rc.templateName and "RIGHT" or "BOTTOMLEFT", rc.templateName and 6 or 250, rc.templateName and 0 or 96)
      sf139_move_to(saveTpl, "LEFT", loadTpl or f, loadTpl and "RIGHT" or "BOTTOMLEFT", loadTpl and 6 or 310, loadTpl and 0 or 96)
      sf139_move_to(delTpl, "LEFT", saveTpl or f, saveTpl and "RIGHT" or "BOTTOMLEFT", saveTpl and 6 or 370, saveTpl and 0 or 96)

      sf139_move_to(channelLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", 30, 64)
      sf139_move_to(rc.channelEdit, "LEFT", channelLabel or f, channelLabel and "RIGHT" or "BOTTOMLEFT", channelLabel and 8 or 88, channelLabel and 0 or 64)
      sf139_move_to(rc.broadcastCount, "LEFT", rc.channelEdit or f, rc.channelEdit and "RIGHT" or "BOTTOMLEFT", rc.channelEdit and 12 or 330, rc.channelEdit and 0 or 64)

      -- The green status line was what overlapped the bottom buttons. Hide it; failed
      -- channel joins are reported in chat when Broadcast is pressed.
      if rc.channelStatus and rc.channelStatus.Hide then rc.channelStatus:Hide() end

      sf139_move_to(loadExisting, "BOTTOMLEFT", f, "BOTTOMLEFT", 30, 18)
      sf139_move_to(broadcast, "LEFT", loadExisting or f, loadExisting and "RIGHT" or "BOTTOMLEFT", loadExisting and 8 or 145, loadExisting and 0 or 18)
      sf139_move_to(publish, "LEFT", broadcast or f, broadcast and "RIGHT" or "BOTTOMLEFT", broadcast and 8 or 260, broadcast and 0 or 18)

      local baseLevel = (f.GetFrameLevel and f:GetFrameLevel() or 500) + 25
      for _, obj in ipairs({rc.templateName, loadTpl, saveTpl, delTpl, rc.channelEdit, rc.broadcastCount, loadExisting, broadcast, publish}) do
        sf139_set_frame_level(obj, baseLevel)
        if obj and obj.Show then obj:Show() end
      end

      if rc.channelEdit and not rc.sf139ChannelHooked then
        rc.sf139ChannelHooked = true
        rc.channelEdit:HookScript("OnTextChanged", function() BLFG:SF139_UpdateRecruitmentUI() end)
      end

      if rc.guildEdit and not rc.sf139GuildHooked then rc.sf139GuildHooked = true; rc.guildEdit:HookScript("OnTextChanged", function() BLFG:SF139_UpdateRecruitmentUI() end) end
      if rc.discordEdit and not rc.sf139DiscordHooked then rc.sf139DiscordHooked = true; rc.discordEdit:HookScript("OnTextChanged", function() BLFG:SF139_UpdateRecruitmentUI() end) end
      if rc.notesEdit and not rc.sf139NotesHooked then rc.sf139NotesHooked = true; rc.notesEdit:HookScript("OnTextChanged", function() BLFG:SF139_UpdateRecruitmentUI() end) end

      self:SF139_UpdateRecruitmentUI()
    end

    local SF139_OldOpenRecruitmentCreator = BLFG.OpenRecruitmentCreator
    function BLFG:OpenRecruitmentCreator(...)
      local r = SF139_OldOpenRecruitmentCreator and SF139_OldOpenRecruitmentCreator(self, ...)
      if self.SF139_EnhanceRecruitmentCreator then self:SF139_EnhanceRecruitmentCreator() end
      return r
    end

    local SF139_OldRefreshRecruitmentPreview = BLFG.RefreshRecruitmentPreview
    function BLFG:RefreshRecruitmentPreview(...)
      local r = SF139_OldRefreshRecruitmentPreview and SF139_OldRefreshRecruitmentPreview(self, ...)
      if self.SF139_UpdateRecruitmentUI and not self._sf139UpdatingPreview then
        self._sf139UpdatingPreview = true
        self:SF139_UpdateRecruitmentUI()
        self._sf139UpdatingPreview = nil
      end
      return r
    end

    local SF139_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"]
    local SF139_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"]
    local function sf139_handle_slash(input)
      local raw = tostring(input or "")
      local cmd = sf139_low(sf139_trim(raw))
      if cmd == "channel" or cmd == "recruit channel" then
        sf139_ensure_db()
        sf139_msg("Recruitment broadcast channel: " .. tostring(BronzeLFG_DB.recruitmentCreator.broadcastChannel or SF139_DEFAULT_CHANNEL))
        return true
      end
      if string.sub(cmd, 1, 8) == "channel " then
        BLFG:SF139_SetRecruitmentChannel(sf139_trim(string.sub(raw, 9)))
        return true
      end
      if cmd == "recruit" or cmd == "recruitment" or cmd == "ad" or cmd == "templates" or cmd == "recruitment templates" then
        BLFG:OpenRecruitmentCreator()
        return true
      end
      if cmd == "broadcast" or cmd == "recruit broadcast" then
        BLFG:SF139_SendRecruitmentBroadcast()
        return true
      end
      return false
    end

    if SlashCmdList then
      SLASH_SIGNALFIRE1 = SLASH_SIGNALFIRE1 or "/sf"
      SLASH_SIGNALFIRE2 = SLASH_SIGNALFIRE2 or "/signalfire"
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sf139_handle_slash(input) then return end
        if SF139_OldSlashSF then return SF139_OldSlashSF(input) end
        if SF139_OldSlashBLFG then return SF139_OldSlashBLFG(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sf139_handle_slash(input) then return end
        if SF139_OldSlashBLFG then return SF139_OldSlashBLFG(input) end
      end
    end

    -- Try to seed the default on login without forcing UI creation.
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", function()
      sf139_ensure_db()
    end)
  until true
end

-- Community events
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFE_VERSION = _G.SignalFire_VERSION or "1.4.23"
    local SFE_PREFIX = "BLFG312"
    local SFE_CHANNEL = "BLFG"

    local SFE_TYPES = {"All", "Dungeon", "World Boss", "Invasion", "PvP", "Social", "Other"}
    local SFE_CREATE_TYPES = {"Dungeon", "World Boss", "Invasion", "PvP", "Social", "Other"}
    local SFE_EXPIRES = {"1 hour", "Tonight", "1 day", "7 days", "Never"}

    local SFE_TYPE_COLOR = {
      ["Dungeon"]="|cff44aaff", ["World Boss"]="|cffff55ff", ["Invasion"]="|cffff7733",
      ["PvP"]="|cffff5555", ["Social"]="|cff44ff66", ["Other"]="|cffffcc00",
    }

    local SFE_TYPE_ICON = {
      ["Dungeon"]="Interface\\Icons\\INV_Shield_05",
      ["World Boss"]="Interface\\Icons\\Spell_Shadow_SummonVoidWalker",
      ["Invasion"]="Interface\\Icons\\Ability_Warrior_RallyingCry",
      ["PvP"]="Interface\\Icons\\Achievement_PVP_A_01",
      ["Social"]="Interface\\Icons\\INV_Drink_05",
      ["Other"]="Interface\\Icons\\INV_Misc_Note_01",
    }

    local SFE_FILTER_LABEL = {
      ["All"]="All", ["Dungeon"]="Dungeon", ["World Boss"]="Boss",
      ["Invasion"]="Invasion", ["PvP"]="PvP", ["Social"]="Social", ["Other"]="Other",
    }
    local SFE_FILTER_WIDTH = {
      ["All"]=38, ["Dungeon"]=58, ["World Boss"]=44, ["Invasion"]=58, ["PvP"]=38, ["Social"]=48, ["Other"]=46,
    }

    local function sfe_now() return (time and time()) or 0 end
    local function sfe_player() return (UnitName and UnitName("player")) or "Unknown" end
    local function sfe_low(s) return string.lower(tostring(s or "")) end
    local function sfe_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end
    local function sfe_clean(s, maxLen)
      s = sfe_trim(s)
      s = string.gsub(s, "[~|\r\n]", " ")
      s = string.gsub(s, "%s+", " ")
      maxLen = tonumber(maxLen) or 0
      if maxLen > 0 and string.len(s) > maxLen then s = string.sub(s, 1, maxLen) end
      return s
    end
    local function sfe_short(s, n)
      s = tostring(s or "")
      n = tonumber(n) or 0
      if n > 0 and string.len(s) > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
      return s
    end
    local function sfe_name_key(name)
      name = sfe_low(sfe_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      return name
    end
    local function sfe_split(s)
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
    local function sfe_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0) end
    end
    local function sfe_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local n = BronzeLFG_DB.signalFireNetwork
      n.events = n.events or {}
      n.eventDismissed = n.eventDismissed or {}
      n.eventBoardFilter = n.eventBoardFilter or "All"
      n.eventBoardTab = n.eventBoardTab or "Events"
      return n
    end
    local function sfe_backdrop(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .90)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end
    local function sfe_flat(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=2,right=2,top=2,bottom=2}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .72)
      frame:SetBackdropBorderColor(.55, .40, .08, .85)
    end
    local function sfe_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end
    local function sfe_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 100); b:SetHeight(h or 24)
      b:SetText(tostring(text or "Button"))
      return b
    end
    local function sfe_edit(parent, w, h, multi)
      local e = CreateFrame("EditBox", nil, parent)
      e:SetWidth(w or 160); e:SetHeight(h or 24)
      e:EnableMouse(true)
      e:SetAutoFocus(false)
      e:SetFontObject(GameFontHighlightSmall)
      e:SetTextInsets(6, 6, 3, 3)
      e:SetMaxLetters(multi and 240 or 80)
      e:SetMultiLine(multi and true or false)
      sfe_backdrop(e, .70)
      e:SetScript("OnMouseDown", function(self) self:SetFocus() end)
      e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      if not multi then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
      return e
    end
    local function sfe_set_button_enabled(btn, enabled)
      if not btn then return end
      if enabled then btn:Enable(); btn:SetAlpha(1) else btn:Disable(); btn:SetAlpha(.45) end
    end
    local function sfe_send(payload)
      payload = tostring(payload or "")
      if payload == "" then return false end
      local id = GetChannelName and GetChannelName(SFE_CHANNEL) or nil
      if id and id ~= 0 and SendChatMessage then
        SendChatMessage(payload, "CHANNEL", nil, id)
        return true
      end
      if JoinChannelByName then JoinChannelByName(SFE_CHANNEL) end
      sfe_msg("Joining /" .. SFE_CHANNEL .. ". Try again in a moment if needed.", .8, .8, .8)
      return false
    end
    local function sfe_drop_layers()
      local maxLevels = tonumber(UIDROPDOWNMENU_MAXLEVELS or 2) or 2
      for i=1,maxLevels do
        local f = _G["DropDownList" .. tostring(i)]
        if f then
          if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
          if f.SetFrameLevel then f:SetFrameLevel(1200 + i) end
        end
      end
    end
    local function sfe_dropdown(parent, name, w, values, value, onchange)
      local btn = CreateFrame("Button", name .. "Button", parent)
      btn:SetWidth(w or 150); btn:SetHeight(24)
      sfe_flat(btn, .82)
      btn.values = values or {}
      btn.sfeValue = value or btn.values[1] or ""
      btn.label = sfe_font(btn, btn.sfeValue, 9, 1, 1, 1)
      btn.label:SetPoint("LEFT", btn, "LEFT", 8, 0)
      btn.label:SetPoint("RIGHT", btn, "RIGHT", -20, 0)
      btn.label:SetJustifyH("LEFT")
      btn.arrow = btn:CreateTexture(nil, "OVERLAY")
      btn.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
      btn.arrow:SetWidth(14); btn.arrow:SetHeight(14); btn.arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
      local menu = CreateFrame("Frame", name .. "Menu", UIParent, "UIDropDownMenuTemplate")
      btn.menu = menu; menu.ownerButton = btn
      UIDropDownMenu_Initialize(menu, function(self, level)
        level = level or 1
        if level ~= 1 then return end
        local owner = self and self.ownerButton or btn
        for _, v in ipairs(owner.values or {}) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = v; info.value = v; info.checked = owner.sfeValue == v
          info.func = function()
            owner.sfeValue = v
            if owner.label then owner.label:SetText(v) end
            if onchange then onchange(v) end
            if CloseDropDownMenus then CloseDropDownMenus() end
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end, "MENU")
      btn:SetScript("OnClick", function(self)
        sfe_drop_layers()
        ToggleDropDownMenu(1, nil, self.menu, self, 0, 0)
        sfe_drop_layers()
      end)
      return btn
    end

    local function sfe_event_type(t)
      t = sfe_clean(t or "Other", 18)
      for _, v in ipairs(SFE_CREATE_TYPES) do if t == v then return t end end
      return "Other"
    end
    local function sfe_expires_seconds(label)
      local low = sfe_low(label)
      if low == "never" then return 0 end
      if low == "1 hour" or low == "hour" then return 3600 end
      if low == "tonight" then return 21600 end
      if low == "7 days" or low == "7 day" then return 604800 end
      return 86400
    end
    local function sfe_expire_text(expires)
      expires = tonumber(expires or 0) or 0
      if expires == 0 then return "Never" end
      local left = expires - sfe_now()
      if left <= 0 then return "Expired" end
      if left < 3600 then return tostring(math.max(1, math.floor(left/60))) .. "m" end
      if left < 86400 then return tostring(math.floor(left/3600)) .. "h" end
      return tostring(math.floor(left/86400)) .. "d"
    end
    local function sfe_event_title(row)
      row = row or {}
      local color = SFE_TYPE_COLOR[row.type or "Other"] or "|cffffcc00"
      return color .. "[" .. tostring(row.type or "Other") .. "]|r " .. sfe_short(row.name or "Community Event", 32)
    end
    local function sfe_copy_text(row)
      row = row or {}
      local eventType = sfe_clean(row.type or "Other", 24)
      local name = sfe_clean(row.name or "Community Event", 48)
      local timeText = sfe_clean(row.timeText or "", 32)
      local host = sfe_clean(row.host or row.sender or "", 24)
      local desc = sfe_clean(row.description or "", 80)
      local out = "[SignalFire Event] [" .. eventType .. "] " .. name
      if timeText ~= "" then out = out .. " - " .. timeText end
      if host ~= "" then out = out .. " - Host: " .. host end
      if desc ~= "" then out = out .. " - " .. desc end
      out = string.gsub(out, "%s+", " ")
      if string.len(out) > 245 then out = string.sub(out, 1, 242) .. "..." end
      return out
    end
    local function sfe_is_expired(row, nowValue)
      row = row or {}
      local exp = tonumber(row.expires or 0) or 0
      if exp == 0 then return false end
      return exp <= (tonumber(nowValue) or sfe_now())
    end

    local function sfe_clear_expired_events(silent)
      local n = sfe_db()
      local nowValue = sfe_now()
      local kept = {}
      local removed = 0
      for _, row in ipairs(n.events or {}) do
        local id = tostring((row and row.id) or "")
        if row and id ~= "" and sfe_is_expired(row, nowValue) then
          removed = removed + 1
          if n.eventDismissed then n.eventDismissed[id] = nil end
          if n.eventAlertSeen then n.eventAlertSeen[id] = nil end
          if n.eventAlertKnown then n.eventAlertKnown[id] = nil end
          if n.eventAlertCooldowns then n.eventAlertCooldowns[id] = nil end
        elseif row then
          table.insert(kept, row)
        end
      end
      if removed > 0 then n.events = kept end
      if removed > 0 and not silent then
        sfe_msg("Cleared " .. tostring(removed) .. " expired SignalFire event(s).", .4, 1, .4)
      elseif removed == 0 and not silent then
        sfe_msg("No expired SignalFire events to clear.", .8, .8, .8)
      end
      return removed
    end

    local function sfe_store_event(id, sender, created, expires, typeName, name, timeText, host, contact, description, localOnly)
      local n = sfe_db()
      id = sfe_clean(id, 64)
      if id == "" then return nil end
      created = tonumber(created) or sfe_now()
      expires = tonumber(expires) or 0
      if expires ~= 0 and expires <= sfe_now() then return nil end
      local row = {
        id = id,
        sender = sfe_clean(sender or host or "", 40),
        created = created,
        expires = expires,
        type = sfe_event_type(typeName),
        name = sfe_clean(name or "Community Event", 64),
        timeText = sfe_clean(timeText or "", 40),
        host = sfe_clean(host or sender or "", 40),
        contact = sfe_clean(contact or "", 64),
        description = sfe_clean(description or "", 180),
        localOnly = localOnly and true or false,
      }
      local replaced = false
      for i, old in ipairs(n.events or {}) do
        if tostring(old.id or "") == id then n.events[i] = row; replaced = true; break end
      end
      if not replaced then table.insert(n.events, 1, row) end
      table.sort(n.events, function(a,b) return (tonumber(a.created) or 0) > (tonumber(b.created) or 0) end)
      while #n.events > 60 do table.remove(n.events) end
      return row
    end
    function BLFG:SFE_GetEventRows()
      local n = sfe_db()
      sfe_clear_expired_events(true)
      local rows = {}
      local filter = tostring(n.eventBoardFilter or "All")
      local myOnly = n.eventBoardMyEvents and true or false
      local now = sfe_now()
      for _, row in ipairs(n.events or {}) do
        local id = tostring(row.id or "")
        local expired = sfe_is_expired(row, now)
        if not expired and id ~= "" and not n.eventDismissed[id] then
          if (filter == "All" or row.type == filter) and ((not myOnly) or sfe_name_key(row.host) == sfe_name_key(sfe_player()) or sfe_name_key(row.sender) == sfe_name_key(sfe_player())) then
            table.insert(rows, row)
          end
        end
      end
      table.sort(rows, function(a,b) return (tonumber(a.created) or 0) > (tonumber(b.created) or 0) end)
      return rows
    end
    local function sfe_selected_event(self)
      local id = self and self.sfeSelectedEventId or nil
      if id then
        for _, row in ipairs(self:SFE_GetEventRows() or {}) do if row.id == id then return row end end
      end
      return nil
    end
    local function sfe_notice_title(row)
      row = row or {}
      local title = tostring(row.title or "")
      if title ~= "" then return title end
      local body = tostring(row.body or row.message or row.text or "")
      if body ~= "" then return sfe_short(body, 40) end
      return "SignalFire Notice"
    end

    local function sfe_notice_body(row)
      row = row or {}
      return tostring(row.body or row.message or row.text or "")
    end

    local function sfe_notice_expires(row)
      row = row or {}
      local expires = tonumber(row.expires or 0) or 0
      if expires <= 0 then return "Never" end
      return sfe_expire_text(expires)
    end

    local function sfe_detail_panel(self)
      local host = self.sfnBeaconPanel
      if not host then return nil end
      if not self.sfeBeaconEventDetail then
        local b = CreateFrame('Frame', nil, host)
        self.sfeBeaconEventDetail = b
        b:SetPoint('TOPLEFT', host, 'TOPLEFT', 8, -8)
        b:SetPoint('BOTTOMRIGHT', host, 'BOTTOMRIGHT', -8, 8)
        b:SetFrameLevel((host:GetFrameLevel() or 1) + 40)
        b:EnableMouse(true)
        sfe_backdrop(b, .92)
        b.title = sfe_font(b, 'Details', 13, 1, .75, 0)
        b.title:SetPoint('TOPLEFT', b, 'TOPLEFT', 10, -8)
        b.name = sfe_font(b, '', 11, 1, 1, 1)
        b.name:SetPoint('TOPLEFT', b.title, 'BOTTOMLEFT', 0, -6)
        b.name:SetWidth(250); b.name:SetJustifyH('LEFT')
        b.meta = sfe_font(b, '', 9, 1, .82, .35)
        b.meta:SetPoint('TOPLEFT', b.name, 'BOTTOMLEFT', 0, -2)
        b.meta:SetWidth(360); b.meta:SetJustifyH('LEFT')
        b.body = sfe_font(b, '', 9, .9, .9, .9)
        b.body:SetPoint('TOPLEFT', b.meta, 'BOTTOMLEFT', 0, -4)
        b.body:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', -10, 34)
        b.body:SetJustifyH('LEFT')
        if b.body.SetWordWrap then b.body:SetWordWrap(true) end
        b.dismiss = sfe_button(b, 'Dismiss', 84, 22)
        b.dismiss:SetPoint('BOTTOMRIGHT', b, 'BOTTOMRIGHT', -8, 7)
        b.copy = sfe_button(b, 'Copy Event', 92, 22)
        b.copy:SetPoint('RIGHT', b.dismiss, 'LEFT', -8, 0)
        b.view = sfe_button(b, 'View', 76, 22)
        b.view:SetPoint('RIGHT', b.copy, 'LEFT', -8, 0)
      end
      local keep = self.sfeBeaconEventDetail
      local baseLevel = (host:GetFrameLevel() or 1) + 40
      keep:SetFrameLevel(baseLevel)
      if keep.title and keep.title.SetDrawLayer then keep.title:SetDrawLayer('OVERLAY') end
      if keep.name and keep.name.SetDrawLayer then keep.name:SetDrawLayer('OVERLAY') end
      if keep.meta and keep.meta.SetDrawLayer then keep.meta:SetDrawLayer('OVERLAY') end
      if keep.body and keep.body.SetDrawLayer then keep.body:SetDrawLayer('OVERLAY') end
      if keep.view and keep.view.SetFrameLevel then keep.view:SetFrameLevel(baseLevel + 10); keep.view:Raise() end
      if keep.copy and keep.copy.SetFrameLevel then keep.copy:SetFrameLevel(baseLevel + 10); keep.copy:Raise() end
      if keep.dismiss and keep.dismiss.SetFrameLevel then keep.dismiss:SetFrameLevel(baseLevel + 10); keep.dismiss:Raise() end
      local regions = { host:GetRegions() }
      for i = 1, #regions do
        if regions[i] and regions[i].Hide then regions[i]:Hide() end
      end
      local children = { host:GetChildren() }
      for i = 1, #children do
        if children[i] ~= keep and children[i].Hide then children[i]:Hide() end
      end
      keep:Show()
      return self.sfeBeaconEventDetail
    end

    function BLFG:SFE_ShowBeaconEvent(row)
      local b = sfe_detail_panel(self)
      if not b then return end
      b.sfeNoticeRow = nil
      b.sfeRow = row
      b.title:SetText("Event Details")
      if not row then
        b.name:SetText("Select an event above.")
        b.meta:SetText("")
        b.body:SetText("Event details will appear here.")
        b.view:Hide(); b.copy:Hide(); b.dismiss:Hide()
        b:Show()
        return
      end
      b.name:SetText(sfe_short(row.name or 'Community Event', 42))
      b.meta:SetText((row.type or 'Other') .. ' | Host: ' .. sfe_short(row.host or row.sender or '', 18) .. ' | Time: ' .. sfe_short(row.timeText or '', 22))
      b.body:SetText(sfe_short(row.description or '', 120))
      b.view:SetText("View"); b.copy:SetText("Copy Event"); b.dismiss:SetText("Dismiss")
      b.view:Show(); b.copy:Show(); b.dismiss:Show()
      b.view:SetScript('OnClick', function() sfe_show_event_popup(BLFG.sfeBeaconEventDetail and BLFG.sfeBeaconEventDetail.sfeRow or nil) end)
      b.copy:SetScript('OnClick', function() local ev = BLFG.sfeBeaconEventDetail and BLFG.sfeBeaconEventDetail.sfeRow or nil; if ev and ChatFrame_OpenChat then ChatFrame_OpenChat(sfe_copy_text(ev)) end end)
      b.dismiss:SetScript('OnClick', function()
        local ev = BLFG.sfeBeaconEventDetail and BLFG.sfeBeaconEventDetail.sfeRow or nil
        if ev then local n=sfe_db(); n.eventDismissed[ev.id]=true; BLFG.sfeSelectedEventId=nil; sfe_msg('Event dismissed locally. This does not remove it for other users.', .8, .8, .8); BLFG:SFE_RefreshEventBoard() end
      end)
      b:Show()
    end

    function BLFG:SFE_ShowNoticeDetail(row)
      local b = sfe_detail_panel(self)
      if not b then return end
      b.sfeRow = nil
      b.sfeNoticeRow = row
      b.title:SetText("Notice Details")
      if not row then
        b.name:SetText("Select a notice above.")
        b.meta:SetText("")
        b.body:SetText("Notice details will appear here.")
        b.view:Hide(); b.copy:Hide(); b.dismiss:Hide()
        b:Show()
        return
      end
      b.name:SetText(sfe_short(sfe_notice_title(row), 42))
      b.meta:SetText("Priority: " .. tostring(row.priority or "Normal") .. " | From: " .. sfe_short(row.sender or "SignalFire", 18) .. " | Expires: " .. sfe_notice_expires(row))
      b.body:SetText(sfe_short(sfe_notice_body(row), 160))
      b.view:Hide()
      b.copy:Show(); b.copy:SetText("Copy Notice")
      b.dismiss:Show(); b.dismiss:SetText("Dismiss")
      b.copy:SetScript('OnClick', function()
        local nrow = BLFG.sfeBeaconEventDetail and BLFG.sfeBeaconEventDetail.sfeNoticeRow or nil
        if nrow and ChatFrame_OpenChat then ChatFrame_OpenChat(sfe_notice_title(nrow) .. " - " .. sfe_notice_body(nrow)) end
      end)
      b.dismiss:SetScript('OnClick', function()
        local nrow = BLFG.sfeBeaconEventDetail and BLFG.sfeBeaconEventDetail.sfeNoticeRow or nil
        if not nrow or not nrow.id then return end
        BronzeLFG_DB = BronzeLFG_DB or {}
        BronzeLFG_DB.network = BronzeLFG_DB.network or {}
        BronzeLFG_DB.network.noticeDismissed = BronzeLFG_DB.network.noticeDismissed or {}
        BronzeLFG_DB.network.noticeSeen = BronzeLFG_DB.network.noticeSeen or {}
        BronzeLFG_DB.network.noticeDismissed[nrow.id] = true
        BronzeLFG_DB.network.noticeSeen[nrow.id] = true
        BLFG.sfnSelectedNoticeId = nil
        BLFG.sfnSelectedNoticeRow = nil
        if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      end)
      b:Show()
    end
    local sfe_apply_embedded_tab
    local function sfe_apply_tab(self, tab)
      local n = sfe_db()
      n.eventBoardTab = tab or n.eventBoardTab or "Events"

      if self and self.SFE_BuildEventBoard then self:SFE_BuildEventBoard() end
      if self then sfe_apply_embedded_tab(self, n.eventBoardTab) end
      if self and self.SFE_RefreshEventBoard then self:SFE_RefreshEventBoard() end
    end
    local function sfe_is_admin_name(name)
      local key = sfe_name_key(name or "")
      return key == "hsoj" or key == "hs0j" or key == "aesri"
    end

    local function sfe_is_admin()
      return sfe_is_admin_name(sfe_player())
    end

    local function sfe_is_event_owner(row, name)
      row = row or {}
      local key = sfe_name_key(name or sfe_player())
      if key == "" then return false end
      if sfe_name_key(row.sender or "") == key or sfe_name_key(row.host or "") == key then return true end
      -- Locally created event IDs are prefixed with the creator key. This fallback
      -- handles realm/name formatting differences in CHAT_MSG_CHANNEL author fields.
      local id = tostring(row.id or "")
      if string.sub(id, 1, string.len(key) + 1) == (key .. "-") then return true end
      return false
    end

    local function sfe_find_event_by_id(id)
      id = tostring(id or "")
      local n = sfe_db()
      for _, row in ipairs(n.events or {}) do
        if tostring(row.id or "") == id then return row end
      end
      return nil
    end

    local function sfe_remove_event_local(id)
      local n = sfe_db()
      id = sfe_clean(id or "", 64)
      if id == "" or sfe_low(id) == "all" then
        n.events = {}; n.eventDismissed = {}; return true
      end
      n.eventDismissed[id] = true
      return true
    end

    local function sfe_owner_clear(id)
      local row = sfe_find_event_by_id(id)
      if not row or not sfe_is_event_owner(row, sfe_player()) then
        sfe_msg("Only the event creator/host or a SignalFire admin alias can clear that event for everyone.", 1, .4, .4)
        return false
      end
      id = sfe_clean(id or "", 64)
      if id == "" then return false end
      sfe_remove_event_local(id)
      sfe_send(table.concat({SFE_PREFIX, "EVENTCLEAR", sfe_player(), tostring(sfe_now()), id}, "~"))
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfe_msg("Cancelled your event for SignalFire users.", .4, 1, .4)
      return true
    end
    local function sfe_master_clear(id)
      if not sfe_is_admin() then sfe_msg("Only a SignalFire admin alias can master-clear SignalFire events.", 1, .35, .35); return false end
      id = sfe_clean(id or "ALL", 64)
      if id == "" then id = "ALL" end
      sfe_remove_event_local(id)
      sfe_send(table.concat({SFE_PREFIX, "EVENTCLEAR", sfe_player(), tostring(sfe_now()), id}, "~"))
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfe_msg(sfe_low(id) == "all" and "Master cleared all SignalFire events." or "Master cleared SignalFire event.", .4, 1, .4)
      return true
    end
    local function sfe_show_event_popup(row)
      if not row then return end
      if not BLFG.sfeEventPopup then
        local f = CreateFrame("Frame", "SignalFireEventDetailFrame", UIParent)
        BLFG.sfeEventPopup = f
        f:SetWidth(420); f:SetHeight(260); f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        if f.SetClampedToScreen then f:SetClampedToScreen(true) end
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        sfe_backdrop(f, .97)
        f.title = sfe_font(f, "Community Event", 14, 1, .75, 0); f.title:SetPoint("TOP", f, "TOP", 0, -14)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3); close:SetScript("OnClick", function() f:Hide() end)
        f.meta = sfe_font(f, "", 9, 1, .82, .35); f.meta:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -48); f.meta:SetWidth(370); f.meta:SetJustifyH("LEFT")
        f.body = sfe_font(f, "", 10, .9, .9, .9); f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -78); f.body:SetWidth(370); f.body:SetHeight(110); f.body:SetJustifyH("LEFT"); f.body:SetJustifyV("TOP")
        if f.body.SetWordWrap then f.body:SetWordWrap(true) end
        local copy = sfe_button(f, "Copy Event", 110, 26); copy:SetPoint("BOTTOM", f, "BOTTOM", -58, 18); f.copyButton = copy
        local ok = sfe_button(f, "OK", 80, 26); ok:SetPoint("LEFT", copy, "RIGHT", 12, 0); ok:SetScript("OnClick", function() f:Hide() end)
      end
      local f = BLFG.sfeEventPopup
      f.sfeRow = row
      f.title:SetText(sfe_event_title(row))
      f.meta:SetText("Host: " .. tostring(row.host or "") .. "  |  Time: " .. tostring(row.timeText or "") .. "  |  Expires: " .. sfe_expire_text(row.expires))
      local contact = row.contact and row.contact ~= "" and ("\nContact: " .. tostring(row.contact)) or ""
      f.body:SetText(tostring(row.description or "") .. contact)
      f.copyButton:SetScript("OnClick", function() if ChatFrame_OpenChat then ChatFrame_OpenChat(sfe_copy_text(row)) end end)
      f:Show(); if f.Raise then f:Raise() end
    end
    function BLFG:SFE_SendEvent(name, typeName, timeText, host, contact, description, expiresLabel)
      local created = sfe_now()
      local id = sfe_name_key(sfe_player()) .. "-" .. tostring(created) .. "-" .. tostring(math.random(1000,9999))
      local expiresSec = sfe_expires_seconds(expiresLabel or "Tonight")
      local expires = expiresSec == 0 and 0 or (created + expiresSec)
      local row = sfe_store_event(id, sfe_player(), created, expires, typeName, name, timeText, host, contact, description, true)
      if not row then return false end
      local ok = sfe_send(table.concat({SFE_PREFIX, "EVENT", row.id, row.sender, tostring(row.created), tostring(row.expires), row.type, row.name, row.timeText, row.host, row.contact, row.description}, "~"))
      if ok then sfe_msg("Community event posted.", .4, 1, .4) end
      if self.RefreshSFNetwork then self:RefreshSFNetwork() end
      return ok
    end
    local function sfe_reset_event_creator(f)
      if not f then return end
      if f.nameBox then f.nameBox:SetText("") end
      if f.typeBox then
        f.typeBox.sfeValue = "Dungeon"
        if f.typeBox.label then f.typeBox.label:SetText("Dungeon") end
      end
      if f.hostBox then f.hostBox:SetText(sfe_player()) end
      if f.timeBox then f.timeBox:SetText("Tonight 8 PM server") end
      if f.expBox then
        f.expBox.sfeValue = "Tonight"
        if f.expBox.label then f.expBox.label:SetText("Tonight") end
      end
      if f.descBox then f.descBox:SetText("") end
    end

    function BLFG:OpenSFEEventCreator()
      if self.sfeEventCreator then
        sfe_reset_event_creator(self.sfeEventCreator)
        self.sfeEventCreator:Show(); if self.sfeEventCreator.Raise then self.sfeEventCreator:Raise() end; return
      end
      local f = CreateFrame("Frame", "SignalFireEventCreatorFrame", UIParent)
      self.sfeEventCreator = f
      f:SetWidth(370); f:SetHeight(352); f:SetPoint("CENTER", self.frame or UIParent, "CENTER", 80, -20)
      f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 50) + 900)
      f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
      if f.SetClampedToScreen then f:SetClampedToScreen(true) end
      f:SetScript("OnDragStart", function(self) self:StartMoving() end); f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
      sfe_backdrop(f, .78)
      f:EnableKeyboard(true)
      f:SetScript("OnKeyDown", function(self, key) if key == "ESCAPE" then self:Hide() end end)
      if UISpecialFrames then
        _G.SignalFireEventCreatorFrame = f
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == "SignalFireEventCreatorFrame" then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, "SignalFireEventCreatorFrame") end
      end
      local title = sfe_font(f, "Create Community Event", 14, 1, .75, 0); title:SetPoint("TOP", f, "TOP", 0, -14)
      local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3); close:SetScript("OnClick", function() f:Hide() end)
      sfe_font(f, "Event Name", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -48)
      f.nameBox = sfe_edit(f, 230, 22, false); f.nameBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -44)
      sfe_font(f, "Event Type", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80)
      f.typeBox = sfe_dropdown(f, "SignalFireEventTypeDropdown", 230, SFE_CREATE_TYPES, "Dungeon", nil); f.typeBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -76)
      sfe_font(f, "Host / Contact", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -112)
      f.hostBox = sfe_edit(f, 230, 22, false); f.hostBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -108); f.hostBox:SetText(sfe_player())
      sfe_font(f, "Time Text", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -144)
      f.timeBox = sfe_edit(f, 230, 22, false); f.timeBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -140); f.timeBox:SetText("Tonight 8 PM server")
      sfe_font(f, "Expiration", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -176)
      f.expBox = sfe_dropdown(f, "SignalFireEventExpirationDropdown", 230, SFE_EXPIRES, "Tonight", nil); f.expBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -172)
      sfe_font(f, "Description", 9, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -208)
      f.descBox = sfe_edit(f, 230, 70, true); f.descBox:SetPoint("TOPLEFT", f, "TOPLEFT", 118, -204)
      local function closeCreatorOnEsc(self) if self and self.ClearFocus then self:ClearFocus() end; f:Hide() end
      f.nameBox:SetScript("OnEscapePressed", closeCreatorOnEsc)
      f.hostBox:SetScript("OnEscapePressed", closeCreatorOnEsc)
      f.timeBox:SetScript("OnEscapePressed", closeCreatorOnEsc)
      f.descBox:SetScript("OnEscapePressed", closeCreatorOnEsc)
      sfe_reset_event_creator(f)
      local create = sfe_button(f, "Create Event", 120, 26); create:SetPoint("BOTTOM", f, "BOTTOM", -66, 18)
      local cancel = sfe_button(f, "Cancel", 90, 26); cancel:SetPoint("LEFT", create, "RIGHT", 14, 0); cancel:SetScript("OnClick", function() f:Hide() end)
      local popupKids = {f:GetChildren()}
      for _, child in ipairs(popupKids) do
        if child and child.SetFrameLevel then child:SetFrameLevel((f:GetFrameLevel() or 1) + 20) end
        if child and child.EnableMouse then child:EnableMouse(true) end
      end
      create:SetScript("OnClick", function()
        local name = f.nameBox:GetText()
        if sfe_trim(name) == "" then sfe_msg("Event Name is required.", 1, .4, .4); return end
        BLFG:SFE_SendEvent(name, f.typeBox.sfeValue or "Dungeon", f.timeBox:GetText(), f.hostBox:GetText(), f.hostBox:GetText(), f.descBox:GetText(), f.expBox.sfeValue or "Tonight")
        sfe_reset_event_creator(f)
        f:Hide()
      end)
    end

    local function sfe_find_button_by_text(parent, needle)
      if not parent or not parent.GetChildren then return nil end
      local kids = {parent:GetChildren()}
      for _, child in ipairs(kids) do
        if child and child.GetText then
          local ok, txt = pcall(child.GetText, child)
          if ok and txt == needle then return child end
        end
      end
      return nil
    end

    local function sfe_layout_notice_host(self)
      local host = self and self.sfeNoticeHost or nil
      if not host then return end
      local f = self and self.sfeEventPanel or nil
      local header = f and f.header or nil
      local createNotice = self.sfnCreateNoticeButton or sfe_find_button_by_text(host, 'Create Notice') or sfe_find_button_by_text(header, 'Create Notice') or sfe_find_button_by_text(header, 'Admin Only')
      self.sfnCreateNoticeButton = createNotice

      -- Notices mode has one clean header strip:
      -- top row: Events / Notices tabs on the left, Popups + Create Notice on the right
      -- bottom row: notice count on the left, Mark All Read on the right
      if header then
        if self.sfnNoticePopupToggle then
          self.sfnNoticePopupToggle:SetParent(header)
          self.sfnNoticePopupToggle:Show()
          self.sfnNoticePopupToggle:Enable()
          self.sfnNoticePopupToggle:SetWidth(92)
          self.sfnNoticePopupToggle:SetHeight(22)
          self.sfnNoticePopupToggle:SetFrameLevel((header:GetFrameLevel() or 1) + 50)
          self.sfnNoticePopupToggle:ClearAllPoints()
          if createNotice then
            self.sfnNoticePopupToggle:SetPoint('RIGHT', createNotice, 'LEFT', -8, 0)
          else
            self.sfnNoticePopupToggle:SetPoint('TOPRIGHT', header, 'TOPRIGHT', -10, -8)
          end
          if self.SFN_UpdateNoticePopupToggle then self:SFN_UpdateNoticePopupToggle() end
        end

        if createNotice then
          createNotice:SetParent(header)
          createNotice:Show()
          createNotice:SetWidth(100)
          createNotice:SetHeight(22)
          createNotice:SetFrameLevel((header:GetFrameLevel() or 1) + 50)
          createNotice:ClearAllPoints()
          createNotice:SetPoint('TOPRIGHT', header, 'TOPRIGHT', -10, -8)
        end

        if self.sfnMarkAllRead then
          self.sfnMarkAllRead:SetParent(header)
          self.sfnMarkAllRead:Show()
          self.sfnMarkAllRead:SetWidth(104)
          self.sfnMarkAllRead:SetHeight(22)
          self.sfnMarkAllRead:SetFrameLevel((header:GetFrameLevel() or 1) + 50)
          self.sfnMarkAllRead:ClearAllPoints()
          self.sfnMarkAllRead:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', -10, 7)
        end

        if self.sfnNoticeCount then
          self.sfnNoticeCount:SetParent(header)
          self.sfnNoticeCount:Show()
          self.sfnNoticeCount:ClearAllPoints()
          self.sfnNoticeCount:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', 14, 10)
          self.sfnNoticeCount:SetWidth(230)
          self.sfnNoticeCount:SetJustifyH('LEFT')
        end
      else
        if self.sfnNoticePopupToggle then
          self.sfnNoticePopupToggle:Show()
          self.sfnNoticePopupToggle:ClearAllPoints()
          self.sfnNoticePopupToggle:SetPoint('TOPRIGHT', host, 'TOPRIGHT', -12, -10)
          self.sfnNoticePopupToggle:Enable()
          if self.SFN_UpdateNoticePopupToggle then self:SFN_UpdateNoticePopupToggle() end
        end
        if self.sfnMarkAllRead then
          self.sfnMarkAllRead:Show()
          self.sfnMarkAllRead:ClearAllPoints()
          self.sfnMarkAllRead:SetPoint('TOPLEFT', host, 'TOPLEFT', 178, -66)
          self.sfnMarkAllRead:SetWidth(96)
        end
        if createNotice then
          createNotice:Show()
          createNotice:ClearAllPoints()
          createNotice:SetPoint('TOPRIGHT', host, 'TOPRIGHT', -12, -66)
          createNotice:SetWidth(104)
        end
        if self.sfnNoticeCount then
          self.sfnNoticeCount:Show()
          self.sfnNoticeCount:ClearAllPoints()
          self.sfnNoticeCount:SetPoint('TOPLEFT', host, 'TOPLEFT', 14, -66)
          self.sfnNoticeCount:SetWidth(158)
          self.sfnNoticeCount:SetJustifyH('LEFT')
        end
      end

      for i, r in ipairs(self.sfnNoticeRows or {}) do
        r:SetParent(host)
        if i <= 4 then
          r:SetHeight(40)
          r:ClearAllPoints()
          r:SetPoint('TOPLEFT', host, 'TOPLEFT', 12, -108 - ((i-1)*43))
          r:SetWidth(374)
          -- Do not force-show empty rows. NetworkPlus owns whether a notice row is populated.
          if r.noticeRow then r:Show() else r:Hide() end
        else
          r:Hide()
        end
      end
    end

    local function sfe_set_notice_host_chrome(self, show)
      local host = self and self.sfeNoticeHost or nil
      if not host or not host.GetRegions then return end
      local regions = {host:GetRegions()}
      for _, region in ipairs(regions) do
        if region and region.GetText and region.Show and region.Hide then
          local ok, text = pcall(region.GetText, region)
          text = ok and tostring(text or "") or ""
          if text == "Notice Board" or string.find(text, "^Showing ") then
            if show then region:Show() else region:Hide() end
          end
        end
      end
    end

    local function sfe_raise_child(frame, parent, offset)
      if frame and frame.SetFrameLevel and parent and parent.GetFrameLevel then
        frame:SetFrameLevel((parent:GetFrameLevel() or 1) + (offset or 10))
      end
      if frame and frame.EnableMouse then frame:EnableMouse(true) end
    end

    local function sfe_raise_event_controls(f)
      if not f then return end
      if f.header then sfe_raise_child(f.header, f, 5) end
      if f.content then sfe_raise_child(f.content, f, 3) end
      if f.eventsTab then sfe_raise_child(f.eventsTab, f.header or f, 20) end
      if f.noticesTab then sfe_raise_child(f.noticesTab, f.header or f, 20) end
      if f.create then sfe_raise_child(f.create, f.header or f, 20); f.create:Enable(); f.create:SetAlpha(1) end
      if f.my then sfe_raise_child(f.my, f.header or f, 20); f.my:Enable(); f.my:SetAlpha(1) end
      if f.adminPing then sfe_raise_child(f.adminPing, f.header or f, 25); f.adminPing:Show(); f.adminPing:EnableMouse(true) end
      if f.adminLegacy then sfe_raise_child(f.adminLegacy, f.header or f, 25); f.adminLegacy:Show(); f.adminLegacy:EnableMouse(true) end
      if f.adminClearSelected then sfe_raise_child(f.adminClearSelected, f.header or f, 25); f.adminClearSelected:Show(); f.adminClearSelected:EnableMouse(true) end
      if f.adminClearAll then sfe_raise_child(f.adminClearAll, f.header or f, 25); f.adminClearAll:Show(); f.adminClearAll:EnableMouse(true) end
      for _, btn in ipairs(f.filters or {}) do sfe_raise_child(btn, f.content or f, 20); btn:Enable(); btn:SetAlpha(1) end
      for _, row in ipairs(f.rows or {}) do sfe_raise_child(row, f.content or f, 15) end
      if f.detail then sfe_raise_child(f.detail, f.content or f, 16) end
      if f.prevPage then sfe_raise_child(f.prevPage, f.detail or f, 45); f.prevPage:EnableMouse(true) end
      if f.nextPage then sfe_raise_child(f.nextPage, f.detail or f, 45); f.nextPage:EnableMouse(true) end
      if f.clearExpired then sfe_raise_child(f.clearExpired, f.detail or f, 45); f.clearExpired:EnableMouse(true) end
      if f.view then sfe_raise_child(f.view, f.detail or f, 25) end
      if f.copy then sfe_raise_child(f.copy, f.detail or f, 25) end
      if f.dismiss then sfe_raise_child(f.dismiss, f.detail or f, 25) end
    end

    function sfe_apply_embedded_tab(self, tab)
      local n = sfe_db()
      n.eventBoardTab = tab or n.eventBoardTab or 'Events'
      local host = self and self.sfeNoticeHost or nil
      local f = self and self.sfeEventPanel or nil
      if not host or not f then return end
      local createNotice = self.sfnCreateNoticeButton or sfe_find_button_by_text(host, 'Create Notice')
      self.sfnCreateNoticeButton = createNotice

      if f.headerTitle then f.headerTitle:SetText((n.eventBoardTab == 'Notices') and 'Notice Board' or 'Community Event Board') end
      if f.eventsTab then f.eventsTab:SetText((n.eventBoardTab == 'Events') and '[Events]' or 'Events') end
      if f.noticesTab then f.noticesTab:SetText((n.eventBoardTab == 'Notices') and '[Notices]' or 'Notices') end

      if n.eventBoardTab == 'Events' then
        sfe_set_notice_host_chrome(self, false)
        f:Show(); f.header:Show(); f.content:Show()
        if f.create then f.create:Show() end
        if f.my then f.my:Show() end
        if self.sfnMarkAllRead then self.sfnMarkAllRead:Hide() end
        if createNotice then createNotice:Hide() end
        if self.sfnNoticeCount then self.sfnNoticeCount:Hide(); if self.sfeNoticeHost then self.sfnNoticeCount:SetParent(self.sfeNoticeHost) end end
        if self.sfnMarkAllRead then self.sfnMarkAllRead:Hide(); if self.sfeNoticeHost then self.sfnMarkAllRead:SetParent(self.sfeNoticeHost) end end
        if createNotice then createNotice:Hide(); if self.sfeNoticeHost then createNotice:SetParent(self.sfeNoticeHost) end end
        if self.sfnNoticePopupToggle then self.sfnNoticePopupToggle:Hide(); if self.sfeNoticeHost then self.sfnNoticePopupToggle:SetParent(self.sfeNoticeHost) end end
        for _, r in ipairs(self.sfnNoticeRows or {}) do r:Hide() end
        if self.sfeEventsShortcut then self.sfeEventsShortcut:Hide() end
        sfe_raise_event_controls(f)
        if self.SFE_ShowBeaconEvent then self:SFE_ShowBeaconEvent(sfe_selected_event(self)) end
      else
        if self.SFE_ShowNoticeDetail then self:SFE_ShowNoticeDetail(self.sfnSelectedNoticeRow) end
        sfe_set_notice_host_chrome(self, false)
        f:Show(); f.header:Show(); f.content:Hide()
        if f.create then f.create:Hide() end
        if f.my then f.my:Hide() end
        sfe_layout_notice_host(self)
        if f.eventsTab then sfe_raise_child(f.eventsTab, f.header or f, 25) end
        if f.noticesTab then sfe_raise_child(f.noticesTab, f.header or f, 25) end
      end
    end


    local function sfe_tool_set_enabled(btn, enabled)
      if not btn then return end
      if enabled then
        if btn.Enable then btn:Enable() end
        if btn.SetAlpha then btn:SetAlpha(1) end
      else
        if btn.Disable then btn:Disable() end
        if btn.SetAlpha then btn:SetAlpha(.48) end
      end
    end

    local function sfe_tool_request_presence()
      local PA = _G.SignalFirePresenceAdminFix
      if PA and PA.RequestPresence then
        PA.RequestPresence("event-board", true)
      else
        if BLFG and BLFG.SendPresence then BLFG:SendPresence() end
        if BLFG and BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
      end
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      sfe_msg("SignalFire presence refresh requested.", .4, 1, .4)
    end

    local function sfe_tool_clear_legacy()
      local util = _G.SignalFireUtilityUI
      if util and util.PurgeLegacy then
        return util.PurgeLegacy(false)
      end
      sfe_msg("Legacy cleanup module is not ready yet. Reopen Network or /reload.", 1, .82, .35)
    end

    local function sfe_tool_clear_selected()
      local n = sfe_db()
      if tostring(n.eventBoardTab or "Events") == "Notices" then
        if not (BLFG and BLFG.SFN_IsNoticeAdmin and BLFG:SFN_IsNoticeAdmin()) then
          sfe_msg("Only a SignalFire admin alias can clear notices globally.", 1, .35, .35)
          return
        end
        local id = tostring((BLFG and BLFG.sfnSelectedNoticeId) or "")
        if id == "" then
          sfe_msg("Select a notice first, then click Clear Notice.", 1, .82, .35)
          return
        end
        if BLFG and BLFG.SFN_MasterClearNotice then return BLFG:SFN_MasterClearNotice(id) end
        sfe_msg("Notice clear function is not available.", 1, .35, .35)
        return
      end

      local row = sfe_selected_event(BLFG)
      if not row then
        sfe_msg("Select an event first, then click Clear Selected.", 1, .82, .35)
        return
      end
      return sfe_master_clear(row.id)
    end

    local function sfe_tool_clear_all()
      local n = sfe_db()
      if tostring(n.eventBoardTab or "Events") == "Notices" then
        if not (BLFG and BLFG.SFN_IsNoticeAdmin and BLFG:SFN_IsNoticeAdmin()) then
          sfe_msg("Only a SignalFire admin alias can clear notices globally.", 1, .35, .35)
          return
        end
        if BLFG and BLFG.SFN_MasterClearAllNotices then return BLFG:SFN_MasterClearAllNotices() end
        if BLFG and BLFG.SFN_MasterClearNotice then return BLFG:SFN_MasterClearNotice("ALL") end
        sfe_msg("Notice clear function is not available.", 1, .35, .35)
        return
      end
      return sfe_master_clear("ALL")
    end


    local function sfe_compact_notice_count_text()
      local c = BLFG and BLFG.sfnNoticeCount
      if not c or not c.GetText or not c.SetText then return end
      local t = tostring(c:GetText() or "")
      local total, unread = string.match(t, "Showing%s+(%d+)%s+notice%(s%)%s*|%s*(%d+)%s+unread")
      if total and unread then
        c:SetText(tostring(total) .. " notice(s) | " .. tostring(unread) .. " unread")
      end
    end

    local function sfe_update_admin_tools(f)
      if not f then return end
      local n = sfe_db()
      local isNotices = tostring(n.eventBoardTab or "Events") == "Notices"
      local header = f.header or f

      if isNotices then
        if f.adminPing then f.adminPing:Hide() end
        if f.adminLegacy then f.adminLegacy:Hide() end

        local canNoticeAdmin = (BLFG and BLFG.SFN_IsNoticeAdmin and BLFG:SFN_IsNoticeAdmin()) or false

        -- 1.4.21: Notice Board has limited horizontal space.  Admin aliases get
        -- Clear Notice / Clear Notices on the right; Mark All Read is hidden for
        -- admins so it cannot overlap the count.  Non-admins keep Mark All Read and
        -- do not see admin clear controls.
        if BLFG and BLFG.sfnNoticeCount then
          BLFG.sfnNoticeCount:SetParent(header)
          BLFG.sfnNoticeCount:Show()
          BLFG.sfnNoticeCount:ClearAllPoints()
          BLFG.sfnNoticeCount:SetPoint('BOTTOMLEFT', header, 'BOTTOMLEFT', 14, 10)
          BLFG.sfnNoticeCount:SetWidth(215)
          BLFG.sfnNoticeCount:SetJustifyH('LEFT')
          if BLFG.sfnNoticeCount.SetWordWrap then BLFG.sfnNoticeCount:SetWordWrap(false) end
          if BLFG.sfnNoticeCount.SetNonSpaceWrap then BLFG.sfnNoticeCount:SetNonSpaceWrap(false) end
          sfe_compact_notice_count_text()
        end

        if canNoticeAdmin then
          if BLFG and BLFG.sfnMarkAllRead then
            BLFG.sfnMarkAllRead:Hide()
            BLFG.sfnMarkAllRead:ClearAllPoints()
          end
          if f.adminClearAll then
            f.adminClearAll:Show(); f.adminClearAll:ClearAllPoints(); f.adminClearAll:SetWidth(98); f.adminClearAll:SetHeight(18)
            f.adminClearAll:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', -10, 7)
            sfe_raise_child(f.adminClearAll, header, 55); f.adminClearAll:EnableMouse(true)
            if f.adminClearAll.SetText then f.adminClearAll:SetText("Clear Notices") end
          end
          if f.adminClearSelected then
            f.adminClearSelected:Show(); f.adminClearSelected:ClearAllPoints(); f.adminClearSelected:SetWidth(94); f.adminClearSelected:SetHeight(18)
            if f.adminClearAll then
              f.adminClearSelected:SetPoint('RIGHT', f.adminClearAll, 'LEFT', -6, 0)
            else
              f.adminClearSelected:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', -10, 7)
            end
            sfe_raise_child(f.adminClearSelected, header, 55); f.adminClearSelected:EnableMouse(true)
            if f.adminClearSelected.SetText then f.adminClearSelected:SetText("Clear Notice") end
          end
        else
          if f.adminClearSelected then f.adminClearSelected:Hide() end
          if f.adminClearAll then f.adminClearAll:Hide() end
          if BLFG and BLFG.sfnMarkAllRead then
            BLFG.sfnMarkAllRead:Show()
            BLFG.sfnMarkAllRead:ClearAllPoints()
            BLFG.sfnMarkAllRead:SetWidth(104)
            BLFG.sfnMarkAllRead:SetHeight(20)
            BLFG.sfnMarkAllRead:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', -10, 7)
            sfe_raise_child(BLFG.sfnMarkAllRead, header, 50)
          end
        end
      else
        if BLFG and BLFG.sfnMarkAllRead then BLFG.sfnMarkAllRead:Hide() end
        if f.adminPing then
          f.adminPing:Show(); f.adminPing:ClearAllPoints(); f.adminPing:SetWidth(76); f.adminPing:SetHeight(18)
          f.adminPing:SetPoint('TOPLEFT', header, 'TOPLEFT', 10, -36)
          sfe_raise_child(f.adminPing, header, 55); f.adminPing:EnableMouse(true)
        end
        if f.adminLegacy then
          f.adminLegacy:Show(); f.adminLegacy:ClearAllPoints(); f.adminLegacy:SetWidth(86); f.adminLegacy:SetHeight(18)
          f.adminLegacy:SetPoint('LEFT', f.adminPing or header, f.adminPing and 'RIGHT' or 'TOPLEFT', 6, 0)
          sfe_raise_child(f.adminLegacy, header, 55); f.adminLegacy:EnableMouse(true)
        end
        if f.adminClearSelected then
          f.adminClearSelected:Show(); f.adminClearSelected:ClearAllPoints(); f.adminClearSelected:SetWidth(98); f.adminClearSelected:SetHeight(18)
          f.adminClearSelected:SetPoint('LEFT', f.adminLegacy or header, f.adminLegacy and 'RIGHT' or 'TOPLEFT', 6, 0)
          sfe_raise_child(f.adminClearSelected, header, 55); f.adminClearSelected:EnableMouse(true)
          if f.adminClearSelected.SetText then f.adminClearSelected:SetText("Clear Selected") end
        end
        if f.adminClearAll then
          f.adminClearAll:Show(); f.adminClearAll:ClearAllPoints(); f.adminClearAll:SetWidth(76); f.adminClearAll:SetHeight(18)
          f.adminClearAll:SetPoint('LEFT', f.adminClearSelected or header, f.adminClearSelected and 'RIGHT' or 'TOPLEFT', 6, 0)
          sfe_raise_child(f.adminClearAll, header, 55); f.adminClearAll:EnableMouse(true)
          if f.adminClearAll.SetText then f.adminClearAll:SetText("Clear All") end
        end
      end

      local canAdmin = isNotices and (BLFG and BLFG.SFN_IsNoticeAdmin and BLFG:SFN_IsNoticeAdmin()) or sfe_is_admin()
      sfe_tool_set_enabled(f.adminClearSelected, canAdmin)
      sfe_tool_set_enabled(f.adminClearAll, canAdmin)
    end

    function BLFG:SFE_BuildEventBoard()
      if not self.sfnPanel then return end
      local host = self.sfnNoticeRows and self.sfnNoticeRows[1] and self.sfnNoticeRows[1].GetParent and self.sfnNoticeRows[1]:GetParent() or nil
      self.sfeNoticeHost = host
      if not host then return end
      if self.sfeEventsShortcut then self.sfeEventsShortcut:Hide() end

      if self.sfeEventPanel then return end

      local f = CreateFrame('Frame', nil, host)
      self.sfeEventPanel = f
      f:SetAllPoints(host)
      f:SetFrameStrata(host:GetFrameStrata() or 'DIALOG')
      f:SetFrameLevel((host:GetFrameLevel() or 1) + 60)
      f:EnableMouse(false)
      f:Show()

      f.headerTitle = sfe_font(f, 'Community Event Board', 13, 1, .75, 0)
      f.headerTitle:SetPoint('TOPLEFT', f, 'TOPLEFT', 10, -8)
      f.headerTitle:SetWidth(230)
      f.headerTitle:SetJustifyH('LEFT')

      local header = CreateFrame('Frame', nil, f)
      f.header = header
      header:SetPoint('TOPLEFT', f, 'TOPLEFT', 4, -30)
      header:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -4, -30)
      header:SetHeight(66)
      header:SetFrameLevel((f:GetFrameLevel() or 1) + 2)
      sfe_backdrop(header, .68)

      f.eventsTab = sfe_button(header, 'Events', 58, 20)
      f.eventsTab:SetPoint('TOPLEFT', header, 'TOPLEFT', 10, -8)
      f.eventsTab:SetScript('OnClick', function() sfe_apply_embedded_tab(BLFG, 'Events'); BLFG:SFE_RefreshEventBoard() end)

      f.noticesTab = sfe_button(header, 'Notices', 64, 20)
      f.noticesTab:SetPoint('LEFT', f.eventsTab, 'RIGHT', 6, 0)
      f.noticesTab:SetScript('OnClick', function() sfe_apply_embedded_tab(BLFG, 'Notices'); BLFG:SFE_RefreshEventBoard() end)

      f.create = sfe_button(header, 'Create Event', 100, 22)
      f.create:SetPoint('TOPRIGHT', header, 'TOPRIGHT', -10, -8)
      f.create:SetScript('OnClick', function() BLFG:OpenSFEEventCreator() end)

      f.my = sfe_button(header, 'My Events', 76, 22)
      f.my:SetPoint('RIGHT', f.create, 'LEFT', -8, 0)
      f.my:SetScript('OnClick', function()
        local n = sfe_db(); n.eventBoardMyEvents = not n.eventBoardMyEvents; n.eventBoardPage = 1; BLFG.sfeSelectedEventId=nil; BLFG:SFE_RefreshEventBoard()
      end)

      -- Core admin/presence utility row.  These are built in the native Event Board
      -- layer so they remain visible on both Events and Notices tabs.
      f.adminPing = sfe_button(header, 'Ping Users', 76, 18)
      f.adminPing:SetPoint('TOPLEFT', header, 'TOPLEFT', 10, -36)
      f.adminPing:SetScript('OnClick', function() sfe_tool_request_presence() end)

      f.adminLegacy = sfe_button(header, 'Clear Legacy', 86, 18)
      f.adminLegacy:SetPoint('LEFT', f.adminPing, 'RIGHT', 6, 0)
      f.adminLegacy:SetScript('OnClick', function() sfe_tool_clear_legacy() end)

      f.adminClearSelected = sfe_button(header, 'Clear Selected', 98, 18)
      f.adminClearSelected:SetPoint('LEFT', f.adminLegacy, 'RIGHT', 6, 0)
      f.adminClearSelected:SetScript('OnClick', function() sfe_tool_clear_selected() end)

      f.adminClearAll = sfe_button(header, 'Clear All', 76, 18)
      f.adminClearAll:SetPoint('LEFT', f.adminClearSelected, 'RIGHT', 6, 0)
      f.adminClearAll:SetScript('OnClick', function() sfe_tool_clear_all() end)
      sfe_update_admin_tools(f)

      -- Clear Expired is placed in the Selected Event control strip below.
      -- Keeping it out of the header prevents overlap with Events/Notices/My Events/Create Event.

      local content = CreateFrame('Frame', nil, f)
      f.content = content
      content:SetPoint('TOPLEFT', f, 'TOPLEFT', 4, -104)
      content:SetPoint('BOTTOMRIGHT', f, 'BOTTOMRIGHT', -4, 4)
      content:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
      content:EnableMouse(true)
      sfe_backdrop(content, .62)
      content:SetScript('OnMouseDown', function()
        if BLFG.sfeSelectedEventId then
          BLFG.sfeSelectedEventId = nil
          BLFG:SFE_RefreshEventBoard()
        end
      end)

      f.filters = {}
      local filters = {'All', 'Dungeon', 'World Boss', 'Invasion', 'PvP', 'Social', 'Other'}
      local last = nil
      for i, v in ipairs(filters) do
        local btn = sfe_button(content, SFE_FILTER_LABEL[v] or v, SFE_FILTER_WIDTH[v] or 56, 20)
        if last then btn:SetPoint('LEFT', last, 'RIGHT', 4, 0) else btn:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, -7) end
        btn.sfeFilter = v
        btn:SetScript('OnClick', function(self)
          local n=sfe_db(); n.eventBoardFilter=self.sfeFilter or 'All'; n.eventBoardPage = 1; BLFG.sfeSelectedEventId=nil; BLFG:SFE_RefreshEventBoard()
        end)
        table.insert(f.filters, btn)
        last = btn
      end

      f.rows = {}
      for i=1,3 do
        local r = CreateFrame('Button', nil, content)
        r:SetHeight(28)
        r:SetPoint('TOPLEFT', content, 'TOPLEFT', 10, -32 - ((i-1)*31))
        r:SetPoint('RIGHT', content, 'RIGHT', -10, 0)
        sfe_flat(r, .88)
        r:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
        r:EnableMouse(true)
        r.icon = r:CreateTexture(nil, 'ARTWORK')
        r.icon:SetWidth(18); r.icon:SetHeight(18); r.icon:SetPoint('LEFT', r, 'LEFT', 8, 0)
        r.title = sfe_font(r, '', 10, 1, 1, 1)
        r.title:SetPoint('TOPLEFT', r, 'TOPLEFT', 32, -2); r.title:SetWidth(176); r.title:SetHeight(10); r.title:SetJustifyH('LEFT'); if r.title.SetWordWrap then r.title:SetWordWrap(false) end
        r.host = sfe_font(r, '', 8, 1, .82, .35)
        r.host:SetPoint('TOPLEFT', r.title, 'BOTTOMLEFT', 0, -1); r.host:SetWidth(168); r.host:SetHeight(9); r.host:SetJustifyH('LEFT'); if r.host.SetWordWrap then r.host:SetWordWrap(false) end
        r.desc = sfe_font(r, '', 8, .86, .86, .86)
        r.desc:SetPoint('TOPLEFT', r, 'TOPLEFT', 226, -13); r.desc:SetWidth(104); r.desc:SetHeight(9); r.desc:SetJustifyH('RIGHT'); if r.desc.SetWordWrap then r.desc:SetWordWrap(false) end; if r.desc.SetNonSpaceWrap then r.desc:SetNonSpaceWrap(false) end
        r.time = sfe_font(r, '', 9, .95, .95, .95)
        r.time:SetPoint('TOPRIGHT', r, 'TOPRIGHT', -8, -2); r.time:SetWidth(104); r.time:SetHeight(9); r.time:SetJustifyH('RIGHT'); if r.time.SetWordWrap then r.time:SetWordWrap(false) end
        r:SetScript('OnClick', function(self, button)
          if not self.sfeRow then return end
          if button == 'RightButton' then
            if sfe_is_admin() then
              -- Admin override: right-click clears this selected event for everyone.
              -- Full-board clear remains an explicit slash action: /sf events clearall.
              sfe_master_clear(self.sfeRow.id)
            elseif sfe_is_event_owner(self.sfeRow, sfe_player()) then
              -- Event owner/host can cancel their own event for everyone.
              sfe_owner_clear(self.sfeRow.id)
            else
              sfe_msg('Only the event creator/host or a SignalFire admin alias can clear that event for everyone. Use Dismiss for local-only hide.', 1, .4, .4)
            end
            return
          end
          BLFG.sfeSelectedEventId = self.sfeRow.id
          BLFG:SFE_RefreshEventBoard()
        end)
        r:SetScript('OnEnter', function(self)
          if not self.sfeRow or not GameTooltip then return end
          local row = self.sfeRow
          GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
          GameTooltip:AddLine(sfe_event_title(row))
          GameTooltip:AddLine('Host: ' .. tostring(row.host or ''), 1, .82, .35)
          GameTooltip:AddLine('Time: ' .. tostring(row.timeText or ''), .9, .9, .9)
          GameTooltip:AddLine(tostring(row.description or ''), .9, .9, .9, true)
          GameTooltip:AddLine('Left-click selects. Right-click clears this event if you created it or are a SignalFire admin.', .45, 1, .45)
          GameTooltip:Show()
        end)
        r:SetScript('OnLeave', function() if GameTooltip then GameTooltip:Hide() end end)
        f.rows[i] = r
      end

      f.detail = CreateFrame('Frame', nil, content)
      f.detail:SetPoint('BOTTOMLEFT', content, 'BOTTOMLEFT', 10, 8)
      f.detail:SetPoint('BOTTOMRIGHT', content, 'BOTTOMRIGHT', -10, 8)
      f.detail:SetHeight(24)
      f.detail:EnableMouse(false)
      sfe_flat(f.detail, .68)
      f.d1 = sfe_font(f.detail, '', 10, 1, .82, .35)
      f.d1:SetPoint('LEFT', f.detail, 'LEFT', 10, 0); f.d1:SetWidth(112)
      f.more = sfe_font(f.detail, '', 8, .65, .82, 1)
      f.more:SetPoint('RIGHT', f.detail, 'RIGHT', -10, 0)
      f.more:SetWidth(132); f.more:SetJustifyH('RIGHT')
      f.prevPage = sfe_button(f.detail, 'Prev', 44, 20)
      f.nextPage = sfe_button(f.detail, 'Next', 44, 20)
      f.prevPage:EnableMouse(true); f.nextPage:EnableMouse(true)
      f.prevPage:RegisterForClicks('LeftButtonUp'); f.nextPage:RegisterForClicks('LeftButtonUp')
      f.prevPage:SetFrameLevel((f.detail:GetFrameLevel() or 1) + 45)
      f.nextPage:SetFrameLevel((f.detail:GetFrameLevel() or 1) + 45)
      f.nextPage:SetPoint('RIGHT', f.more, 'LEFT', -6, 0)
      f.prevPage:SetPoint('RIGHT', f.nextPage, 'LEFT', -5, 0)
      f.prevPage:SetScript('OnClick', function()
        local n = sfe_db()
        n.eventBoardTab = 'Events'
        n.eventBoardPage = math.max(1, (tonumber(n.eventBoardPage or 1) or 1) - 1)
        BLFG.sfeSelectedEventId = nil
        BLFG:SFE_RefreshEventBoard()
      end)
      f.nextPage:SetScript('OnClick', function()
        local n = sfe_db()
        n.eventBoardTab = 'Events'
        n.eventBoardPage = (tonumber(n.eventBoardPage or 1) or 1) + 1
        BLFG.sfeSelectedEventId = nil
        BLFG:SFE_RefreshEventBoard()
      end)
      content:EnableMouseWheel(true)
      content:SetScript('OnMouseWheel', function(self, delta)
        local n = sfe_db()
        if delta and delta < 0 then n.eventBoardPage = (tonumber(n.eventBoardPage or 1) or 1) + 1
        else n.eventBoardPage = math.max(1, (tonumber(n.eventBoardPage or 1) or 1) - 1) end
        BLFG.sfeSelectedEventId = nil
        BLFG:SFE_RefreshEventBoard()
      end)
      f.d2 = sfe_font(f.detail, '', 10, .95, .95, .95)
      f.d2:SetPoint('TOPLEFT', f.d1, 'BOTTOMLEFT', 0, -2); f.d2:SetWidth(348); f.d2:SetHeight(13); f.d2:SetJustifyH('LEFT'); if f.d2.SetWordWrap then f.d2:SetWordWrap(false) end
      f.d2:Hide()
      f.d3 = sfe_font(f.detail, '', 8, 1, .82, .35)
      f.d3:SetPoint('TOPLEFT', f.d2, 'BOTTOMLEFT', 0, -1); f.d3:SetWidth(348); f.d3:SetHeight(12); f.d3:SetJustifyH('LEFT'); if f.d3.SetWordWrap then f.d3:SetWordWrap(false) end
      f.d3:Hide()
      f.d4 = sfe_font(f.detail, '', 8, .9, .9, .9)
      f.d4:SetPoint('TOPLEFT', f.d3, 'BOTTOMLEFT', 0, -1); f.d4:SetWidth(348); f.d4:SetHeight(12); f.d4:SetJustifyH('LEFT'); if f.d4.SetWordWrap then f.d4:SetWordWrap(false) end; if f.d4.SetNonSpaceWrap then f.d4:SetNonSpaceWrap(false) end
      f.d4:Hide()
      f.view = sfe_button(f.detail, 'View', 78, 22)
      f.view:SetScript('OnClick', function() sfe_show_event_popup(sfe_selected_event(BLFG)) end)
      f.copy = sfe_button(f.detail, 'Copy Event', 94, 22)
      f.copy:SetScript('OnClick', function() local row=sfe_selected_event(BLFG); if row and ChatFrame_OpenChat then ChatFrame_OpenChat(sfe_copy_text(row)) end end)
      f.dismiss = sfe_button(f.detail, 'Dismiss', 86, 22)
      f.dismiss:SetPoint('BOTTOMRIGHT', f.detail, 'BOTTOMRIGHT', -8, 5)
      f.copy:SetPoint('RIGHT', f.dismiss, 'LEFT', -8, 0)
      f.view:SetPoint('RIGHT', f.copy, 'LEFT', -8, 0)
      f.dismiss:SetScript('OnClick', function() local row=sfe_selected_event(BLFG); if row then local n=sfe_db(); n.eventDismissed[row.id]=true; BLFG.sfeSelectedEventId=nil; sfe_msg('Event dismissed locally. This does not remove it for other users.', .8, .8, .8); BLFG:SFE_RefreshEventBoard() end end)
      f.view:Hide(); f.copy:Hide(); f.dismiss:Hide()

      sfe_apply_embedded_tab(self, sfe_db().eventBoardTab or 'Events')
      sfe_update_admin_tools(f)
      sfe_raise_event_controls(f)
    end

    function BLFG:OpenSFEEventBoard()
      if self.ShowSFNetwork then self:ShowSFNetwork() end
      self:SFE_BuildEventBoard()
      sfe_apply_embedded_tab(self, 'Events')
      self:SFE_RefreshEventBoard()
    end

    function BLFG:SFE_RefreshEventBoard()
      self:SFE_BuildEventBoard()
      local f = self.sfeEventPanel
      if not f or not self.sfeNoticeHost then return end
      local n = sfe_db()
      sfe_apply_embedded_tab(self, n.eventBoardTab or 'Events')
      sfe_update_admin_tools(f)
      if n.eventBoardTab ~= 'Events' then if self.SFE_ShowNoticeDetail then self:SFE_ShowNoticeDetail(self.sfnSelectedNoticeRow) end; return end
      sfe_raise_event_controls(f)
      sfe_update_admin_tools(f)

      local rows = self:SFE_GetEventRows()
      local rowsPerPage = #(f.rows or {})
      if rowsPerPage < 1 then rowsPerPage = 1 end
      local maxPage = math.max(1, math.ceil((#rows) / rowsPerPage))
      n.eventBoardPage = tonumber(n.eventBoardPage or 1) or 1
      if n.eventBoardPage < 1 then n.eventBoardPage = 1 end
      if n.eventBoardPage > maxPage then n.eventBoardPage = maxPage end
      local pageStart = ((n.eventBoardPage - 1) * rowsPerPage) + 1

      if self.sfeSelectedEventId then
        local exists = false
        for _, row in ipairs(rows) do if row.id == self.sfeSelectedEventId then exists = true; break end end
        if not exists then self.sfeSelectedEventId = nil end
      end

      for _, btn in ipairs(f.filters or {}) do
        local label = SFE_FILTER_LABEL[btn.sfeFilter or ''] or tostring(btn.sfeFilter or 'All')
        if btn.SetText then btn:SetText((btn.sfeFilter == n.eventBoardFilter) and ('[' .. label .. ']') or label) end
      end
      if f.my and f.my.SetText then f.my:SetText(n.eventBoardMyEvents and 'Show All' or 'My Events') end
      if f.more then
        local shownStart = (#rows == 0) and 0 or pageStart
        local shownEnd = math.min(#rows, pageStart + rowsPerPage - 1)
        local prefix = ''
        if n.eventBoardMyEvents then prefix = 'Mine: '
        elseif tostring(n.eventBoardFilter or 'All') ~= 'All' then prefix = tostring(SFE_FILTER_LABEL[n.eventBoardFilter] or n.eventBoardFilter) .. ': ' end
        if #rows > rowsPerPage then
          f.more:SetText(prefix .. tostring(shownStart) .. '-' .. tostring(shownEnd) .. '/' .. tostring(#rows) .. ' P' .. tostring(n.eventBoardPage) .. '/' .. tostring(maxPage))
        elseif #rows > 0 then
          f.more:SetText(prefix .. tostring(#rows) .. ' event(s)')
        elseif prefix ~= '' then
          f.more:SetText(prefix .. '0')
        else
          f.more:SetText('')
        end
      end
      sfe_set_button_enabled(f.prevPage, (n.eventBoardPage or 1) > 1)
      sfe_set_button_enabled(f.nextPage, (n.eventBoardPage or 1) < maxPage)

      for i, r in ipairs(f.rows or {}) do
        local row = rows[pageStart + i - 1]
        if row then
          r:Show(); r.sfeRow = row
          r.icon:SetTexture(SFE_TYPE_ICON[row.type or 'Other'] or SFE_TYPE_ICON.Other)
          r.title:SetText(sfe_event_title(row))
          r.host:SetText('Host: ' .. sfe_short(row.host or row.sender or '', 24))
          r.time:SetText(sfe_short(row.timeText or sfe_expire_text(row.expires), 10))
          r.desc:SetText(sfe_short(row.description or '', 12))
          if row.id == self.sfeSelectedEventId then
            if r.SetBackdropColor then r:SetBackdropColor(.16, .10, .02, .94) end
            if r.SetBackdropBorderColor then r:SetBackdropBorderColor(1, .72, .12, 1) end
          else
            if r.SetBackdropColor then r:SetBackdropColor(0, 0, 0, .78) end
            if r.SetBackdropBorderColor then r:SetBackdropBorderColor(.55, .40, .08, .85) end
          end
        else
          r.sfeRow = nil; r:Hide()
        end
      end

      local sel = sfe_selected_event(self)
      if self.SFE_ShowBeaconEvent then self:SFE_ShowBeaconEvent(sel) end
      if sel then
        if f.d1 then f.d1:SetText('Selected: ' .. sfe_short(sel.name or 'Event', 26)) end
      else
        if f.d1 then f.d1:SetText('') end
      end
    end

    local function sfe_handle_payload(msg, author)
      msg = tostring(msg or "")
      if string.sub(msg, 1, string.len(SFE_PREFIX) + 1) ~= (SFE_PREFIX .. "~") then return false end
      local p = sfe_split(msg)
      if p[1] ~= SFE_PREFIX then return false end
      if p[2] == "EVENT" then
        local row = sfe_store_event(p[3], p[4] or author, tonumber(p[5]), tonumber(p[6]), p[7], p[8], p[9], p[10], p[11], p[12], false)
        if row then
          local n = sfe_db()
          n.eventBoardMyEvents = false
          n.eventBoardPage = 1
        end
        if row and BLFG and BLFG.SFE141_NotifyEventRow then BLFG:SFE141_NotifyEventRow(row) end
        if BLFG and BLFG.sfnPanel and BLFG.sfnPanel:IsVisible() and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        return true
      end
      if p[2] == "EVENTCLEAR" then
        local clearAuthor = author or ""
        local payloadAuthor = p[3] or ""
        local authorKey = sfe_name_key(clearAuthor)
        if authorKey == "" then authorKey = sfe_name_key(payloadAuthor) end
        local target = sfe_clean(p[5] or "ALL", 64)
        if target == "" then target = "ALL" end

        if sfe_is_admin_name(authorKey) or sfe_is_admin_name(payloadAuthor) then
          sfe_remove_event_local(target)
          if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          return true
        end

        -- Non-admins may only clear their own specific event. Clients verify against
        -- the stored sender/host before honoring the clear.
        if sfe_low(target) ~= "all" then
          local row = sfe_find_event_by_id(target)
          if row and (sfe_is_event_owner(row, authorKey) or sfe_is_event_owner(row, payloadAuthor)) then
            sfe_remove_event_local(target)
            if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          end
        end
        return true
      end
      return false
    end
    local SFE_OldBuildSFNetworkPanel = BLFG.BuildSFNetworkPanel
    function BLFG:BuildSFNetworkPanel(...)
      local r = SFE_OldBuildSFNetworkPanel and SFE_OldBuildSFNetworkPanel(self, ...)
      self:SFE_BuildEventBoard()
      self:SFE_RefreshEventBoard()
      return r
    end
    local SFE_OldRefreshSFNetwork = BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      local r = SFE_OldRefreshSFNetwork and SFE_OldRefreshSFNetwork(self, ...)
      if self.sfnPanel and self.sfnPanel:IsVisible() then
        self:SFE_BuildEventBoard()
        self:SFE_RefreshEventBoard()
      end
      return r
    end
    local SFE_OldShowSFNetwork = BLFG.ShowSFNetwork
    function BLFG:ShowSFNetwork(...)
      local r = SFE_OldShowSFNetwork and SFE_OldShowSFNetwork(self, ...)
      self:SFE_BuildEventBoard()
      self:SFE_RefreshEventBoard()
      return r
    end
    local SFE_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
    local SFE_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
    local function sfe_handle_slash(input, old)
      input = sfe_trim(input or "")
      local cmd, rest = string.match(input, "^(%S+)%s*(.-)$")
      cmd = sfe_low(cmd or "")
      if cmd == "events" or cmd == "event" then
        local lowRest = sfe_low(rest or "")
        if rest == "" then if BLFG.ShowSFNetwork then BLFG:ShowSFNetwork() end; if BLFG.OpenSFEEventBoard then BLFG:OpenSFEEventBoard() end; return true end
        if lowRest == "create" then BLFG:OpenSFEEventCreator(); return true end
        if lowRest == "clear expired" or lowRest == "clearexpired" then sfe_clear_expired_events(false); if BLFG.SFE_RefreshEventBoard then BLFG:SFE_RefreshEventBoard() end; return true end
        if lowRest == "clear local" or lowRest == "reset" then local n=sfe_db(); n.events={}; n.eventDismissed={}; n.eventBoardPage=1; BLFG.sfeSelectedEventId=nil; sfe_msg("Cleared local SignalFire events. This does not affect other users.", .4, 1, .4); if BLFG.SFE_RefreshEventBoard then BLFG:SFE_RefreshEventBoard() end; return true end
        if lowRest == "page next" or lowRest == "next" then local n=sfe_db(); n.eventBoardPage=(tonumber(n.eventBoardPage or 1) or 1)+1; if BLFG.SFE_RefreshEventBoard then BLFG:SFE_RefreshEventBoard() end; return true end
        if lowRest == "page prev" or lowRest == "prev" then local n=sfe_db(); n.eventBoardPage=math.max(1,(tonumber(n.eventBoardPage or 1) or 1)-1); if BLFG.SFE_RefreshEventBoard then BLFG:SFE_RefreshEventBoard() end; return true end
        if lowRest == "clearall" or lowRest == "masterclear" then sfe_master_clear("ALL"); return true end
      end
      return false
    end
    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sfe_handle_slash(input, SFE_OldSlashSF) then return end
        if SFE_OldSlashSF then return SFE_OldSlashSF(input) end
        if SFE_OldSlashBLFG then return SFE_OldSlashBLFG(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sfe_handle_slash(input, SFE_OldSlashBLFG) then return end
        if SFE_OldSlashBLFG then return SFE_OldSlashBLFG(input) end
      end
    end
    local SFE_Frame = CreateFrame("Frame")
    SFE_Frame:RegisterEvent("PLAYER_LOGIN")
    SFE_Frame:RegisterEvent("CHAT_MSG_CHANNEL")
    SFE_Frame:SetScript("OnEvent", function(self, event, msgText, author)
      if event == "CHAT_MSG_CHANNEL" then sfe_handle_payload(msgText, author); return end
      local n = sfe_db()
      if not n.seeded140 then
        n.seeded140 = true
        local created = sfe_now()
        sfe_store_event("welcome-140-event", "SignalFire", created, created + 86400, "Dungeon", "TBC Keys Tonight", "Tonight 8 PM server", "Hsoj", "Whisper host or check Discord", "Need DPS/healer, whisper for invite.", true)
      end
    end)
  until true
end

-- Event alerts
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFE141_VERSION = _G.SignalFire_VERSION or "1.4.23"
    local SFE141_TYPES = {"Dungeon", "World Boss", "Invasion", "PvP", "Social", "Other"}
    local function sfe141_now()
      return (time and time()) or 0
    end

    local function sfe141_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfe141_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfe141_key(name)
      name = sfe141_low(sfe141_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      return name
    end

    local function sfe141_short(s, n)
      s = tostring(s or "")
      n = tonumber(n) or 0
      if n > 0 and string.len(s) > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
      return s
    end

    local function sfe141_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfe141_backdrop(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .96)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end

    local function sfe141_flat(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=10,
        insets={left=2,right=2,top=2,bottom=2}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .78)
      frame:SetBackdropBorderColor(.55, .40, .08, .85)
    end

    local function sfe141_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end

    local function sfe141_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 120)
      b:SetHeight(h or 24)
      b:SetText(text or "Button")
      return b
    end

    local function sfe141_register_escape(frame, name)
      if name then _G[name] = frame end
      if name and UISpecialFrames then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == name then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, name) end
      end
      if frame.EnableKeyboard then frame:EnableKeyboard(true) end
      frame:SetScript("OnKeyDown", function(self, key) if key == "ESCAPE" then self:Hide() end end)
    end

    local function sfe141_ensure_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}

      local o = BronzeLFG_DB.options
      if o.eventAlertsEnabled == nil then o.eventAlertsEnabled = true end
      if o.eventAlertFavoriteHosts == nil then o.eventAlertFavoriteHosts = true end
      if o.eventAlertSound == nil then o.eventAlertSound = false end
      if o.eventAlertToasts == nil then o.eventAlertToasts = true end
      if type(o.eventAlertTypes) ~= "table" then o.eventAlertTypes = {} end
      for _, t in ipairs(SFE141_TYPES) do
        if o.eventAlertTypes[t] == nil then o.eventAlertTypes[t] = true end
      end

      local n = BronzeLFG_DB.signalFireNetwork
      n.eventAlertSeen = n.eventAlertSeen or {}
      n.eventAlertKnown = n.eventAlertKnown or {}
      n.eventAlertCooldowns = n.eventAlertCooldowns or {}
      return o, n
    end

    local function sfe141_is_favorite_name(name)
      local key = sfe141_key(name)
      if key == "" then return false end
      local favs = BronzeLFG_DB and BronzeLFG_DB.favorites or nil
      if type(favs) ~= "table" then return false end
      return favs[key] or favs[name] or favs[sfe141_trim(name)]
    end

    local function sfe141_is_own_event(row)
      local me = sfe141_key((UnitName and UnitName("player")) or "")
      if me == "" then return false end
      return sfe141_key(row and row.sender) == me or sfe141_key(row and row.host) == me
    end

    local function sfe141_should_alert(row, o)
      if not row or not row.id or row.id == "" then return false end
      if row.localOnly then return false end
      if sfe141_is_own_event(row) then return false end
      if o.eventAlertsEnabled == false then return false end

      local rowType = tostring(row.type or "Other")
      local typeAllowed = (o.eventAlertTypes and o.eventAlertTypes[rowType]) ~= false
      local favoriteHost = sfe141_is_favorite_name(row.host) or sfe141_is_favorite_name(row.sender)

      if favoriteHost and o.eventAlertFavoriteHosts ~= false then return true, true end
      return typeAllowed, false
    end

    local function sfe141_play_sound()
      local o = BronzeLFG_DB and BronzeLFG_DB.options or {}
      if o.eventAlertSound ~= true then return end
      if PlaySoundFile then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
      elseif PlaySound then
        PlaySound("RaidWarning")
      end
    end

    local function sfe141_toast(text)
      local o = BronzeLFG_DB and BronzeLFG_DB.options or {}
      if o.eventAlertToasts == false then return end
      if UIErrorsFrame then
        UIErrorsFrame:AddMessage("SignalFire: " .. tostring(text or ""), 1, .82, 0, 1, UIERRORS_HOLD_TIME)
      end
    end

    function BLFG:SFE141_MarkExistingEventsKnown()
      local _, n = sfe141_ensure_db()
      if self.SFE_GetEventRows then
        for _, row in ipairs(self:SFE_GetEventRows() or {}) do
          if row and row.id then
            n.eventAlertKnown[row.id] = true
            n.eventAlertSeen[row.id] = n.eventAlertSeen[row.id] or false
          end
        end
      end
      self.sfe141InitialScanDone = true
    end


    function BLFG:SFE141_NotifyEventRow(row)
      local o, n = sfe141_ensure_db()
      if not row then return false end
      local id = tostring(row.id or "")
      if id == "" then return false end
      if n.eventAlertSeen[id] then return false end

      -- Direct receive path: this is called by SignalFireEvents140 as soon as an EVENT
      -- payload arrives, so alerts do not depend on waiting for the background scan.
      local should, favHost = sfe141_should_alert(row, o)
      n.eventAlertKnown[id] = true
      if not should then return false end

      n.eventAlertSeen[id] = true
      n.eventAlertCooldowns[id] = sfe141_now()

      local typeName = tostring(row.type or "Event")
      local name = sfe141_short(row.name or "Community Event", 44)
      local timeText = sfe141_short(row.timeText or "", 28)
      local host = sfe141_short(row.host or row.sender or "Unknown", 24)
      local prefix = favHost and "Favorite host event" or "New community event"
      local line = prefix .. ": [" .. typeName .. "] " .. name
      if timeText ~= "" then line = line .. " - " .. timeText end
      if host ~= "" then line = line .. " by " .. host end

      sfe141_msg(line, .45, 1, .45)
      sfe141_toast(line)
      sfe141_play_sound()
      return true
    end

    function BLFG:SFE141_ScanEventAlerts()
      local o, n = sfe141_ensure_db()
      if not self.SFE_GetEventRows then return end

      -- First scan is quiet so installing/updating does not alert for old stored events.
      if not self.sfe141InitialScanDone then
        self:SFE141_MarkExistingEventsKnown()
        return
      end

      local rows = self:SFE_GetEventRows() or {}
      local now = sfe141_now()
      for _, row in ipairs(rows) do
        local id = tostring((row and row.id) or "")
        if id ~= "" and not n.eventAlertSeen[id] then
          if not n.eventAlertKnown[id] then
            n.eventAlertKnown[id] = true
            if self.SFE141_NotifyEventRow then
              self:SFE141_NotifyEventRow(row)
            end
          end
        end
      end
    end

    -- Options sub-page -----------------------------------------------------------
    function BLFG:SFE141_AddEventAlertOptions()
      if not self.optionsPanel or self.sfe141EventAlertButton then return end
      sfe141_ensure_db()
      local p = self.optionsPanel
      local open = sfe141_button(p, "Event Alerts", 120, 26)
      self.sfe141EventAlertButton = open

      -- 1.4.1b: normalize the three custom Options buttons into one safe row.
      -- Previous builds let Event Alerts and Polish Settings fight for the same
      -- BOTTOMRIGHT offset, causing the exact overlap seen at smaller scales.
      local function place(btn, rightOffset, width)
        if not btn then return end
        btn:ClearAllPoints()
        btn:SetWidth(width or 120)
        btn:SetHeight(24)
        btn:SetPoint("TOPRIGHT", p, "TOPRIGHT", rightOffset, -4)
      end
      -- Keep custom sub-page buttons in the Options header, not the bottom action row.
      -- Bottom row belongs to Play Alert Sound / Reset Settings / Open Profile.
      place(open, -18, 118)
      place(self.sfamPolishButton, -144, 124)
      place(self.sfn138FavoriteAlertButton, -276, 124)

      local function buildPanel()
        if self.sfe141EventOptionsPanel then return self.sfe141EventOptionsPanel end
        local name = "SignalFireEventAlertsPanel"
        local f = CreateFrame("Frame", name, p)
        self.sfe141EventOptionsPanel = f
        f:SetAllPoints(p)
        f:SetFrameLevel(((p.GetFrameLevel and p:GetFrameLevel()) or 1) + 135)
        f:SetToplevel(true)
        f:EnableMouse(true)
        sfe141_backdrop(f, .985)
        sfe141_register_escape(f, name)
        f:Hide()

        local title = sfe141_font(f, "Event Alerts", 18, 1, .75, 0)
        title:SetPoint("TOP", f, "TOP", 0, -28)
        local note = sfe141_font(f, "Choose which Community Event Board posts should notify you. Alerts are local and throttled.", 10, .82, .9, 1)
        note:SetPoint("TOP", title, "BOTTOM", 0, -12)
        note:SetWidth(650)
        note:SetJustifyH("CENTER")

        local panel = CreateFrame("Frame", nil, f)
        panel:SetWidth(650)
        panel:SetHeight(330)
        panel:SetPoint("TOP", f, "TOP", 0, -88)
        panel:SetFrameLevel(f:GetFrameLevel() + 5)
        panel:EnableMouse(true)
        sfe141_flat(panel, .82)

        local function check(key, label, body, y)
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, y)
          cb:SetFrameLevel(panel:GetFrameLevel() + 10)
          cb.text = sfe141_font(panel, label, 11, 1, 1, 1)
          cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
          cb.body = sfe141_font(panel, body or "", 9, .75, .75, .75)
          cb.body:SetPoint("TOPLEFT", cb.text, "BOTTOMLEFT", 0, -2)
          cb.body:SetWidth(560)
          cb.body:SetJustifyH("LEFT")
          cb:SetScript("OnClick", function(self)
            local o = sfe141_ensure_db()
            BronzeLFG_DB.options[key] = self:GetChecked() and true or false
            if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
          end)
          f[key] = cb
          return cb
        end

        check("eventAlertsEnabled", "Alert me when a new event is posted", "Shows a local SignalFire chat/toast alert for new Community Event Board posts matching your preferences.", -24)
        check("eventAlertFavoriteHosts", "Always alert for favorite hosts", "If the event host/sender is one of your favorite players, alert even when that event type is otherwise disabled.", -78)
        check("eventAlertToasts", "Show event alert toast", "Uses the existing subtle UIErrorsFrame-style SignalFire toast in addition to chat.", -132)
        check("eventAlertSound", "Play sound for event alerts", "Optional sound for event alerts. Off by default.", -186)

        local typesTitle = sfe141_font(panel, "Alert for event types", 11, 1, .82, .35)
        typesTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 28, -230)

        f.typeChecks = {}
        local x, y = 28, -254
        for i, eventType in ipairs(SFE141_TYPES) do
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetWidth(24); cb:SetHeight(24)
          cb:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
          cb:SetFrameLevel(panel:GetFrameLevel() + 10)
          cb.sfe141Type = eventType
          cb.text = sfe141_font(panel, eventType, 9, 1, 1, 1)
          cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
          cb:SetScript("OnClick", function(self)
            local o = sfe141_ensure_db()
            BronzeLFG_DB.options.eventAlertTypes = BronzeLFG_DB.options.eventAlertTypes or {}
            BronzeLFG_DB.options.eventAlertTypes[self.sfe141Type] = self:GetChecked() and true or false
            if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
          end)
          table.insert(f.typeChecks, cb)
          x = x + 104
          if i == 3 then x = 28; y = -280 end
        end

        local back = sfe141_button(f, "Back to Options", 140, 28)
        back:SetPoint("BOTTOM", f, "BOTTOM", 0, 36)
        back:SetFrameLevel(f:GetFrameLevel() + 20)
        back:SetScript("OnClick", function() f:Hide() end)

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
        close:SetFrameLevel(f:GetFrameLevel() + 20)
        close:SetScript("OnClick", function() f:Hide() end)

        return f
      end

      local function refreshPanel()
        local f = buildPanel()
        local o = sfe141_ensure_db()
        if f.eventAlertsEnabled then f.eventAlertsEnabled:SetChecked(o.eventAlertsEnabled ~= false) end
        if f.eventAlertFavoriteHosts then f.eventAlertFavoriteHosts:SetChecked(o.eventAlertFavoriteHosts ~= false) end
        if f.eventAlertToasts then f.eventAlertToasts:SetChecked(o.eventAlertToasts ~= false) end
        if f.eventAlertSound then f.eventAlertSound:SetChecked(o.eventAlertSound == true) end
        for _, cb in ipairs(f.typeChecks or {}) do
          cb:SetChecked((o.eventAlertTypes and o.eventAlertTypes[cb.sfe141Type]) ~= false)
        end
        return f
      end

      open:SetScript("OnClick", function()
        local f = refreshPanel()
        f:Show()
        if f.Raise then f:Raise() end
      end)
    end

    local SFE141_OldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = SFE141_OldBuildOptions and SFE141_OldBuildOptions(self, ...)
      self:SFE141_AddEventAlertOptions()
      return r
    end

    local SFE141_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFE141_OldShowOptions and SFE141_OldShowOptions(self, ...)
      self:SFE141_AddEventAlertOptions()
      return r
    end

    -- Slash helper: /sf eventalerts opens the options sub-page.
    local function sfe141_handle_slash(input, old)
      local raw = tostring(input or "")
      local cmd = sfe141_low(sfe141_trim(raw))
      if cmd == "eventalerts" or cmd == "eventalert" or cmd == "events alerts" then
        if BLFG.ShowOptions then BLFG:ShowOptions() end
        if BLFG.SFE141_AddEventAlertOptions then BLFG:SFE141_AddEventAlertOptions() end
        if BLFG.sfe141EventAlertButton then BLFG.sfe141EventAlertButton:Click() end
        return true
      end
      if old then return old(input) end
    end

    local SFE141_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
    local SFE141_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
    if SlashCmdList then
      SlashCmdList["BRONZELFG"] = function(input) return sfe141_handle_slash(input, SFE141_OldSlashBLFG) end
      SlashCmdList["SIGNALFIRE"] = function(input) return sfe141_handle_slash(input, SFE141_OldSlashSF) end
    end

    local SFE141_Frame = CreateFrame("Frame")
    BLFG._sfe141EventFrame = SFE141_Frame
    SFE141_Frame:RegisterEvent("PLAYER_LOGIN")
    SFE141_Frame:SetScript("OnEvent", function()
      sfe141_ensure_db()
      if BLFG and BLFG.SFE141_MarkExistingEventsKnown then BLFG:SFE141_MarkExistingEventsKnown() end
    end)
    sfe141_ensure_db()
    BLFG.SFE141_EventAlertsInstalled = true
  until true
end
