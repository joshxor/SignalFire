-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Parser rules
do
  repeat
    function SF577_CleanText(text)
      local s = tostring(text or "")
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
      s = string.gsub(s, "|h(%b[])|h", "%1")
      s = string.gsub(s, "%s+", " ")
      return s
    end

    function SF577_Low(text)
      return " " .. string.lower(SF577_CleanText(text or "")) .. " "
    end

    function SF577_Contains(s, token)
      return string.find(s, token, 1, true) ~= nil
    end

    function SF577_RecruitIntent(text)
      local s = SF577_Low(text)
      if isPublicRecruiterIntent and isPublicRecruiterIntent(s) then return true end
      if string.find(s, " lf%d+m") then return true end
      if SF577_Contains(s, " lfm") or SF577_Contains(s, " lf1m") or SF577_Contains(s, " lf2m") then return true end
      if SF577_Contains(s, " need ") or SF577_Contains(s, " looking for ") then return true end
      if SF577_Contains(s, " tank +") or SF577_Contains(s, " tank and ") or SF577_Contains(s, " healer +") or SF577_Contains(s, " healer and ") or SF577_Contains(s, " heals +") then return true end
      return false
    end

    function SF577_ShouldIgnorePublic(text)
      local s = SF577_Low(text)
      if SF577_Contains(s, " guild wars 2 ") or SF577_Contains(s, " ffxiv ") then return true end
      if SF577_Contains(s, " not rdf ") or SF577_Contains(s, " its not rdf ") or SF577_Contains(s, " it's not rdf ") or SF577_Contains(s, " isnt rdf ") or SF577_Contains(s, " isn't rdf ") then return true end
      if SF577_IsPublicQueueChatter and SF577_IsPublicQueueChatter(text) then return true end
      if (SF577_Contains(s, " vendor") or SF577_Contains(s, " vendors")) and not SF577_RecruitIntent(s) then return true end
      if SF577_Contains(s, " [hc] ") and not SF577_RecruitIntent(s) then return true end
      if (SF577_Contains(s, " queue pop") or SF577_Contains(s, " declined") or SF577_Contains(s, " decline ")) and not (SF577_Contains(s, " lfm") or SF577_Contains(s, " need ") or SF577_Contains(s, " lfg ") or SF577_Contains(s, " rdf ")) then return true end
      return false
    end

    function SF577_IsPublicQueueChatter(text)
      local s = SF577_Low(text)
      if (SF577_Contains(s, " does ") or SF577_Contains(s, " how ") or SF577_Contains(s, " why ") or SF577_Contains(s, " what ")) and (SF577_Contains(s, " rdf ") or SF577_Contains(s, " random dungeon")) then return true end
      if (SF577_Contains(s, " scale ") or SF577_Contains(s, " scales ") or SF577_Contains(s, " all the way ") or SF577_Contains(s, " level ") or SF577_Contains(s, " group together") or SF577_Contains(s, " work?")) and (SF577_Contains(s, " rdf ") or SF577_Contains(s, " random dungeon")) then return true end
      return false
    end

    function SF577_RoleComboRecruiter(text)
      local s = SF577_Low(text)
      local combo = SF577_Contains(s, " tank +") or SF577_Contains(s, " tank and ") or SF577_Contains(s, " tank/heal") or SF577_Contains(s, " tank/healer") or SF577_Contains(s, " heals +") or SF577_Contains(s, " healer +") or SF577_Contains(s, " healer and ") or SF577_Contains(s, " dps +")
      local context = SF577_Contains(s, " for ") or SF577_Contains(s, " need ") or SF577_Contains(s, " lfm") or SF577_Contains(s, " queue ") or SF577_Contains(s, " rdf ") or SF577_Contains(s, " random") or SF577_Contains(s, " hc ") or SF577_Contains(s, " heroic") or SF577_Contains(s, " wotlk ") or SF577_Contains(s, " wrath ") or SF577_Contains(s, " tbc ") or SF577_Contains(s, " bc ")
      return combo and context
    end

    function SF577_ContainsLFGFallback(text)
      local s = SF577_Low(text)
      if SF577_Contains(s, " tank +") and SF577_Contains(s, " dps") then return true end
      if SF577_Contains(s, " healer +") and SF577_Contains(s, " dps") then return true end
      if SF577_Contains(s, " heals +") and SF577_Contains(s, " dps") then return true end
      if SF577_Contains(s, " tank and ") and SF577_Contains(s, " dps") then return true end
      return false
    end

    function SF577_Roles(text)
      local s = SF577_Low(text)
      local out = {}
      if SF577_Contains(s, " tank") or SF577_Contains(s, " prot") then table.insert(out, roleText and roleText("Tank") or "Tank") end
      if SF577_Contains(s, " heal") or SF577_Contains(s, " healer") or SF577_Contains(s, " heals") or SF577_Contains(s, " resto") then table.insert(out, roleText and roleText("Healer") or "Healer") end
      if SF577_Contains(s, " dps") or SF577_Contains(s, " damage") then table.insert(out, roleText and roleText("DPS") or "DPS") end
      return table.concat(out, "  ")
    end

    function SF577_ApplyPublicParser(g)
      if not g or g.isInvasionBeacon then return end
      local msg = tostring(g.message or g.rawMessage or "")
      if msg == "" then return end
      local s = SF577_Low(msg)

      if SF577_ShouldIgnorePublic(msg) then
        g.type = "Other"
        g.activity = "General Listing"
        g.intent = "Chat"
        g.roles = ""
        g.tags = "Ignored"
        g.score = 0
        g.noInlineLink = true
        return
      end

      if SF577_Contains(s, " ring of blood ") or SF577_Contains(s, " ring blood ") then
        if SF577_RecruitIntent(msg) then
          g.type = "Event"
          g.activity = "Ring of Blood"
          g.intent = "Recruiter"
          g.roles = SF577_Roles(msg)
          g.tags = "Quest Group | Event"
          g.score = math.max(tonumber(g.score or 0) or 0, 85)
        end
        return
      end

      if SF577_Contains(s, " diremaul ") or SF577_Contains(s, " dire maul ") then
        if SF577_RecruitIntent(msg) or SF577_Contains(s, " quest") then
          g.type = "Dungeon"
          g.activity = "Dire Maul"
          g.intent = "Recruiter"
          g.roles = SF577_Roles(msg)
          g.tags = SF577_Contains(s, " quest") and "Dungeon | Quest Group" or "Dungeon"
          g.score = math.max(tonumber(g.score or 0) or 0, 80)
        end
      end

      if SF577_RoleComboRecruiter(msg) then
        g.type = "Dungeon"
        g.intent = "Recruiter"
        g.roles = SF577_Roles(msg)
        if SF577_Contains(s, " tbc ") or SF577_Contains(s, " bc ") or SF577_Contains(s, " outland") then
          g.activity = "BC Random Dungeon Finder"
        elseif SF577_Contains(s, " wotlk ") or SF577_Contains(s, " wrath ") or SF577_Contains(s, " northrend") then
          g.activity = "Wrath Random Dungeon Finder"
        elseif SF577_Contains(s, " rdf ") or SF577_Contains(s, " random") then
          g.activity = "Random Dungeon Finder"
        end
        if not g.activity or g.activity == "" or g.activity == "General Listing" then g.activity = "Random Dungeon Finder" end
        g.tags = "Dungeon | RDF"
        g.score = math.max(tonumber(g.score or 0) or 0, 85)
      elseif SF577_Contains(s, " lfg rdf ") or SF577_Contains(s, " healer lfg rdf ") or SF577_Contains(s, " dps queue rdf") or SF577_Contains(s, " tank queue rdf") then
        g.type = "LFG"
        g.intent = "Applicant"
        g.activity = "Random Dungeon Finder"
        g.roles = SF577_Roles(msg)
        g.tags = "LFG | RDF"
        g.score = math.max(tonumber(g.score or 0) or 0, 75)
      end
    end

    BLFG_SF577_OldApplyPublicParserFix = BLFG_570b1c_ApplyPublicParserFix
    function BLFG_570b1c_ApplyPublicParserFix(g)
      if BLFG_SF577_OldApplyPublicParserFix then BLFG_SF577_OldApplyPublicParserFix(g) end
      SF577_ApplyPublicParser(g)
    end

    BLFG_SF577_OldInlinePublicChatLinkForMessage = BLFG and BLFG.InlinePublicChatLinkForMessage
    if BLFG_SF577_OldInlinePublicChatLinkForMessage then
      function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
        local raw = tostring(msgText or "")
        if raw ~= "" and SF577_ShouldIgnorePublic(raw) then return nil end
        local out = BLFG_SF577_OldInlinePublicChatLinkForMessage(self, msgText, author, channelName)
        if out then return out end
        if not SF577_RoleComboRecruiter(raw) then return nil end

        self.publicGroups = self.publicGroups or {}
        local name = tostring(author or ""):gsub("%-.*", "")
        if name == "" then return nil end
        local stamp = time and time() or 0
        local g = {
          id = name .. "-" .. tostring(stamp),
          player = name,
          message = raw,
          rawMessage = raw,
          channel = channelName or "Public",
          type = "Dungeon",
          activity = "Random Dungeon Finder",
          intent = "Recruiter",
          roles = SF577_Roles(raw),
          tags = "Dungeon | RDF",
          score = 85,
          created = stamp,
          seen = stamp,
        }
        SF577_ApplyPublicParser(g)
        if g.type == "Guild" or g.type == "Social" or g.type == "Other" then return nil end
        local existingKey = nil
        for id, row in pairs(self.publicGroups) do
          if row and tostring(row.player or "") == name and (tostring(row.message or "") == raw or tostring(row.activity or "") == tostring(g.activity or "")) then existingKey = id; break end
        end
        if existingKey then
          g.id = existingKey
          g.created = self.publicGroups[existingKey].created or stamp
          self.publicGroups[existingKey] = g
        else
          self.publicGroups[g.id] = g
        end
        self._lastPublicGroupTouched = g
        self._lastPublicGroupTouchedKey = g.id
        if self.RequestPublicGroupsRefresh then self:RequestPublicGroupsRefresh() elseif self.RefreshPublicGroups then self:RefreshPublicGroups() end
        local link = self.PublicChatLink and self:PublicChatLink(g) or nil
        return link and (raw .. " " .. link) or nil
      end
    end




    -- Dedicated live-chat filter for role-combo posts that the old core gate rejects.
    function SF577_BuildRoleComboLink(raw, author, channelName)
      if not BLFG then return nil end
      raw = tostring(raw or "")
      if raw == "" or raw:find("bronzelfgpub:", 1, true) or raw:find("|Hblfg:", 1, true) then return nil end
      if SF577_ShouldIgnorePublic and SF577_ShouldIgnorePublic(raw) then return nil end
      if not (SF577_RoleComboRecruiter and SF577_RoleComboRecruiter(raw)) then return nil end

      BLFG.publicGroups = BLFG.publicGroups or {}
      local name = tostring(author or ""):gsub("%-.*", "")
      if name == "" then return nil end
      local stamp = time and time() or 0
      local g = {
        id = name .. "-" .. tostring(stamp),
        player = name,
        message = raw,
        rawMessage = raw,
        channel = channelName or "Public",
        type = "Dungeon",
        activity = "Random Dungeon Finder",
        intent = "Recruiter",
        roles = SF577_Roles and SF577_Roles(raw) or "",
        tags = "Dungeon | RDF",
        score = 85,
        created = stamp,
        seen = stamp,
      }
      if SF577_ApplyPublicParser then SF577_ApplyPublicParser(g) end
      if g.type == "Guild" or g.type == "Social" or g.type == "Other" then return nil end

      local existingKey = nil
      for id, row in pairs(BLFG.publicGroups) do
        if row and tostring(row.player or "") == name and (tostring(row.message or "") == raw or tostring(row.activity or "") == tostring(g.activity or "")) then
          existingKey = id
          break
        end
      end
      if existingKey then
        g.id = existingKey
        g.created = BLFG.publicGroups[existingKey].created or stamp
        BLFG.publicGroups[existingKey] = g
      else
        BLFG.publicGroups[g.id] = g
      end
      BLFG._lastPublicGroupTouched = g
      BLFG._lastPublicGroupTouchedKey = g.id
      if BLFG.RequestPublicGroupsRefresh then BLFG:RequestPublicGroupsRefresh() elseif BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
      local link = BLFG.PublicChatLink and BLFG:PublicChatLink(g) or nil
      return link and (raw .. " " .. link) or nil
    end

    BLFG_SF577b_OldInlinePublicChatLinkForMessage = BLFG and BLFG.InlinePublicChatLinkForMessage
    if BLFG_SF577b_OldInlinePublicChatLinkForMessage then
      function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
        local out = BLFG_SF577b_OldInlinePublicChatLinkForMessage(self, msgText, author, channelName)
        if out then return out end
        return SF577_BuildRoleComboLink(msgText, author, channelName)
      end
    end

    function SF577_RoleComboInlineFilter(frame, event, msgText, author, ...)
      if not BLFG then return false, msgText, author, ... end
      if (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") and not BLFG.SignalFireTestSay then return false, msgText, author, ... end
      local channelName = event
      if event == "CHAT_MSG_CHANNEL" then
        local args = {...}
        channelName = tostring(args[8] or args[7] or "Channel")
      elseif event == "CHAT_MSG_SAY" then
        channelName = "Say"
      elseif event == "CHAT_MSG_YELL" then
        channelName = "Yell"
      end
      local out = SF577_BuildRoleComboLink(msgText, author, channelName)
      if out and out ~= msgText then return false, out, author, ... end
      return false, msgText, author, ...
    end

    if ChatFrame_AddMessageEventFilter and BLFG and not BLFG._sf577RoleComboFilterInstalled then
      BLFG._sf577RoleComboFilterInstalled = true
      ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", SF577_RoleComboInlineFilter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", SF577_RoleComboInlineFilter)
      ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", SF577_RoleComboInlineFilter)
    end


    -- ============================================================
    -- SignalFire 1.3 - Guild recruitment priority fix
    -- Purpose: guild recruitment intent must beat dungeon aliases like Gnomeregan.
    -- Loaded after BronzeLFG.lua, so this final wrapper runs before public parser fallback.
    -- ============================================================
    function SF578_CleanGuildPriorityText(text)
      local s = tostring(text or "")
      if SF577_CleanText then s = SF577_CleanText(s) end
      if cleanPublicChatText then s = cleanPublicChatText(s) end
      s = string.gsub(s, "|c%x%x%x%x%x%x%x%x", "")
      s = string.gsub(s, "|r", "")
      s = string.gsub(s, "%s+", " ")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    function SF578_LowGuildPriorityText(text)
      return string.lower(SF578_CleanGuildPriorityText(text or ""))
    end

    function SF578_BadGuildPriorityName(name)
      local raw = SF578_CleanGuildPriorityText(name or "")
      local low = string.lower(raw)
      local compact = string.gsub(low, "[^%w]+", "")
      if raw == "" or compact == "" then return true end
      if string.len(raw) < 2 or string.len(raw) > 34 then return true end
      local bad = {
        guild=true, recruitment=true, recruiting=true, recruit=true,
        lfg=true, lfm=true, lf=true, rdf=true, dungeon=true, raid=true,
        tank=true, healer=true, heals=true, dps=true, vendor=true, vendors=true,
        sw=true, org=true, stormwind=true, orgrimmar=true, hc=true, pvp=true, pve=true,
      }
      if bad[compact] then return true end
      if string.find(low, "lfm ", 1, true) or string.find(low, "need ", 1, true) or string.find(low, "looking for", 1, true) then return true end
      return false
    end

    function SF578_HasGuildRecruitmentIntent(text)
      local low = " " .. SF578_LowGuildPriorityText(text or "") .. " "
      if string.find(low, " guild recruitment ", 1, true) then return true end
      if string.find(low, " recruiting", 1, true) or string.find(low, " recruits", 1, true) or string.find(low, " recruit ", 1, true) then return true end
      if string.find(low, " recruitment ", 1, true) then return true end
      if string.find(low, " looking for members", 1, true) or string.find(low, " seeking members", 1, true) then return true end
      if string.find(low, " accepting members", 1, true) or string.find(low, " accepting all", 1, true) then return true end
      if string.find(low, " join our guild", 1, true) or string.find(low, " join us", 1, true) then return true end
      if string.find(low, " discord", 1, true) and (string.find(low, " guild", 1, true) or string.find(low, " recruit", 1, true) or string.find(low, " community", 1, true)) then return true end
      if (string.find(low, " raiding guild", 1, true) or string.find(low, " social guild", 1, true) or string.find(low, " leveling guild", 1, true) or string.find(low, " casual guild", 1, true) or string.find(low, " pvp guild", 1, true)) then return true end
      return false
    end

    function SF578_IsDungeonRecruitmentPost(text)
      local low = " " .. SF578_LowGuildPriorityText(text or "") .. " "
      if string.find(low, "%s+lf%d+m[%s%p]") then return true end
      if string.find(low, " lfm ", 1, true) or string.find(low, " lf1m ", 1, true) or string.find(low, " lf2m ", 1, true) or string.find(low, " lf3m ", 1, true) then return true end
      if string.find(low, " need tank", 1, true) or string.find(low, " need heal", 1, true) or string.find(low, " need dps", 1, true) then return true end
      if string.find(low, " run ", 1, true) and (string.find(low, " tank", 1, true) or string.find(low, " heal", 1, true) or string.find(low, " dps", 1, true)) then return true end
      if string.find(low, " lf tank", 1, true) or string.find(low, " lf heals", 1, true) or string.find(low, " lf healer", 1, true) or string.find(low, " lf dps", 1, true) then return true end
      return false
    end

    function SF578_GuildNameFromPriorityRecruitment(text)
      local s = SF578_CleanGuildPriorityText(text or "")
      if s == "" then return "" end

      local g = string.match(s, "<([^>]+)>")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      g = string.match(s, "^%s*%[([^%]]+)%]%s+.*[Rr]ecruit")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      g = string.match(s, "[Gg]uild%s+[Rr]ecruitment%s*[%+:%-%|]%s*(.-)%s+[Rr]ecru")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      g = string.match(s, "^%s*([%w%s%'%-]+)%s+[Ii]s%s+[Rr]ecruiting")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      g = string.match(s, "^%s*([%w%s%'%-]+)%s+[Rr]ecruiting")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      g = string.match(s, "^%s*([%w%s%'%-]+)%s+[Rr]ecruits")
      if g and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end

      if SF578_OldBLFG570b1bGuildNameFromAd then
        g = SF578_OldBLFG570b1bGuildNameFromAd(s)
        if g and g ~= "" and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end
      end
      if SF578_OldBLFG5618GuildNameFromAd then
        g = SF578_OldBLFG5618GuildNameFromAd(s)
        if g and g ~= "" and not SF578_BadGuildPriorityName(g) then return SF578_CleanGuildPriorityText(g) end
      end
      return ""
    end

    function SF578_IsStrongGuildRecruitmentText(text)
      if SF578_IsDungeonRecruitmentPost(text) then return false end
      if not SF578_HasGuildRecruitmentIntent(text) then return false end
      local g = SF578_GuildNameFromPriorityRecruitment(text)
      return g ~= nil and g ~= ""
    end

    function SF578_RouteGuildRecruitment(self, author, raw)
      if not self or not SF578_IsStrongGuildRecruitmentText(raw) then return nil end
      local guildName = SF578_GuildNameFromPriorityRecruitment(raw)
      if not guildName or guildName == "" then return nil end

      if self.UpsertGuildBrowserChatListing then
        pcall(function() self:UpsertGuildBrowserChatListing(guildName, author, raw) end)
      end

      -- Remove any public-group row the older parser may have made for this exact guild ad.
      local cleanRaw = SF578_CleanGuildPriorityText(raw)
      for id, row in pairs(self.publicGroups or {}) do
        local rowMsg = SF578_CleanGuildPriorityText(row and (row.rawMessage or row.message) or "")
        if row and rowMsg == cleanRaw then self.publicGroups[id] = nil end
      end

      if self.guildPanel and self.guildPanel.IsShown and self.guildPanel:IsShown() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
      if self.RefreshPublicGroups then
        if self.RequestPublicGroupsRefresh then self:RequestPublicGroupsRefresh() else self:RefreshPublicGroups() end
      end
      return guildName
    end

    -- Keep all older guild helpers pointed at the stronger final detector.
    SF578_OldBLFG570b1bGuildNameFromAd = BLFG_570b1b_GuildNameFromAd
    function BLFG_570b1b_GuildNameFromAd(text)
      local g = SF578_GuildNameFromPriorityRecruitment(text)
      if g and g ~= "" then return g end
      if SF578_OldBLFG570b1bGuildNameFromAd then return SF578_OldBLFG570b1bGuildNameFromAd(text) end
      return ""
    end
    SF578_OldBLFG5618GuildNameFromAd = BLFG_5618_GuildNameFromAd
    function BLFG_5618_GuildNameFromAd(text)
      local g = SF578_GuildNameFromPriorityRecruitment(text)
      if g and g ~= "" then return g end
      if SF578_OldBLFG5618GuildNameFromAd then return SF578_OldBLFG5618GuildNameFromAd(text) end
      return ""
    end
    SF578_OldBLFG570b1bIsGuildAd = BLFG_570b1b_IsGuildAd
    function BLFG_570b1b_IsGuildAd(text)
      if SF578_IsStrongGuildRecruitmentText(text) then return true end
      return SF578_OldBLFG570b1bIsGuildAd and SF578_OldBLFG570b1bIsGuildAd(text) or false
    end
    function BLFG_5618_IsGuildAd(text)
      if SF578_IsStrongGuildRecruitmentText(text) then return true end
      if BLFG_570b1b_IsGuildAd then return BLFG_570b1b_IsGuildAd(text) end
      return false
    end
    BLFG_5628_IsGuildAd = BLFG_5618_IsGuildAd
    BLFG_5617_IsGuildAd = BLFG_5618_IsGuildAd
    BLFG_5616_IsGuildAd = BLFG_5618_IsGuildAd
    BLFG_5612_IsGuildAd = BLFG_5618_IsGuildAd
    BLFG_569_IsGuildAd = BLFG_5618_IsGuildAd
    BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5618_IsGuildAd

    SF578_OldAddPublicGroup = BLFG and BLFG.AddPublicGroup
    if SF578_OldAddPublicGroup then
      function BLFG:AddPublicGroup(author, text, channelName)
        local raw = tostring(text or "")
        if SF578_RouteGuildRecruitment(self, author, raw) then return nil end
        return SF578_OldAddPublicGroup(self, author, text, channelName)
      end
    end

    SF578_OldInlinePublicChatLinkForMessage = BLFG and BLFG.InlinePublicChatLinkForMessage
    if SF578_OldInlinePublicChatLinkForMessage then
      function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
        local raw = tostring(msgText or "")
        local guildName = SF578_RouteGuildRecruitment(self, author, raw)
        if guildName and guildName ~= "" then
          local out = nil
          if self.InsertGuildLinkInText then out = self:InsertGuildLinkInText(raw, guildName) end
          if not out or out == raw then
            local link = self.GuildChatLink and self:GuildChatLink(guildName) or ("[" .. guildName .. "]")
            out = raw .. " " .. link
          end
          return out
        end
        return SF578_OldInlinePublicChatLinkForMessage(self, msgText, author, channelName)
      end
    end

    SLASH_SF578TEST1 = "/sfguildtest"
    SlashCmdList["SF578TEST"] = function(msg)
      local s = tostring(msg or "")
      if s == "" then s = "Gnomeregan is recruiting members for raids and social leveling" end
      local g = SF578_GuildNameFromPriorityRecruitment(s)
      DEFAULT_CHAT_FRAME:AddMessage("SignalFire guild-priority test: guild=" .. tostring(g) .. " strong=" .. tostring(SF578_IsStrongGuildRecruitmentText(s)))
    end



    -- ============================================================
    -- SignalFire 1.3.1 - Guild priority pronoun/name extraction fix
    -- Fixes "We're recruiting! Guild Name -- ..." linking "We're" as the guild.
    -- ============================================================
    SF579_OldBadGuildPriorityName = SF578_BadGuildPriorityName
    function SF579_BadGuildPriorityName(name)
      local raw = SF578_CleanGuildPriorityText and SF578_CleanGuildPriorityText(name or "") or tostring(name or "")
      local low = string.lower(raw)
      local compact = string.gsub(low, "[^%w]+", "")
      local bad = {
        we=true, were=true, our=true, us=true, ours=true,
        you=true, your=true, youre=true, they=true, theyre=true,
        i=true, im=true, iam=true, guild=true, recruiting=true, recruit=true,
        recruitment=true, members=true, players=true, friendly=true, community=true,
      }
      if bad[compact] then return true end
      if SF579_OldBadGuildPriorityName and SF579_OldBadGuildPriorityName(raw) then return true end
      return false
    end
    SF578_BadGuildPriorityName = SF579_BadGuildPriorityName

    function SF579_CleanGuildCandidate(g)
      g = SF578_CleanGuildPriorityText and SF578_CleanGuildPriorityText(g or "") or tostring(g or "")
      -- Trim common lead-in leftovers if a broad pattern caught too much.
      g = string.gsub(g, "^.*[%?%!%.]%s*", "")
      g = string.gsub(g, "%s+%-%-.*$", "")
      g = string.gsub(g, "%s+%-%s+.*$", "")
      g = string.gsub(g, "^%s+", "")
      g = string.gsub(g, "%s+$", "")
      return g
    end

    SF579_OldGuildNameFromPriorityRecruitment = SF578_GuildNameFromPriorityRecruitment
    function SF579_GuildNameFromPriorityRecruitment(text)
      local s = SF578_CleanGuildPriorityText and SF578_CleanGuildPriorityText(text or "") or tostring(text or "")
      if s == "" then return "" end
      local g

      -- Explicit common ad style: "We're recruiting! Drunken Dwarves -- friendly..."
      g = string.match(s, "[Ww]e're%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-%-")
      if not g then g = string.match(s, "[Ww]ere%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-%-") end
      if not g then g = string.match(s, "[Ww]e%s+are%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-%-") end
      -- Same, but single dash separator.
      if not g then g = string.match(s, "[Ww]e're%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-") end
      if not g then g = string.match(s, "[Ww]ere%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-") end
      if not g then g = string.match(s, "[Ww]e%s+are%s+[Rr]ecruiting[%!:%s%-]+([%w%s%'%-]+)%s+%-") end

      if g then
        g = SF579_CleanGuildCandidate(g)
        if g ~= "" and not SF579_BadGuildPriorityName(g) then return g end
      end

      if SF579_OldGuildNameFromPriorityRecruitment then
        g = SF579_OldGuildNameFromPriorityRecruitment(s)
        if g then
          g = SF579_CleanGuildCandidate(g)
          if g ~= "" and not SF579_BadGuildPriorityName(g) then return g end
        end
      end

      return ""
    end
    SF578_GuildNameFromPriorityRecruitment = SF579_GuildNameFromPriorityRecruitment

    -- Re-point older stacked helpers to the corrected extractor.
    BLFG_570b1b_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_5618_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_5628_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_5617_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_5616_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_5612_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
    BLFG_569_GuildNameFromAd = SF579_GuildNameFromPriorityRecruitment
  until true
end

-- Invasions
do
  repeat
    SignalFire_InvasionData = {
      {
        name = "Azure Watch",
        faction = "Alliance",
        zone = "Azuremyst Isle",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Dolanaar",
        faction = "Alliance",
        zone = "Teldrassil",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Goldshire",
        faction = "Alliance",
        zone = "Elwynn Forest",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Kharanos",
        faction = "Alliance",
        zone = "Dun Morogh",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Auberdine",
        faction = "Alliance",
        zone = "Darkshore",
        minLevel = 11,
        maxLevel = 14,
        rewardXP = 5300,
        itemMin = 11,
        itemMax = 14,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Sentinel Hill",
        faction = "Alliance",
        zone = "Westfall",
        minLevel = 11,
        maxLevel = 14,
        rewardXP = 5300,
        itemMin = 11,
        itemMax = 14,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Thelsamar",
        faction = "Alliance",
        zone = "Loch Modan",
        minLevel = 11,
        maxLevel = 14,
        rewardXP = 5300,
        itemMin = 11,
        itemMax = 14,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Blood Watch",
        faction = "Alliance",
        zone = "Bloodmyst Isle",
        minLevel = 12,
        maxLevel = 15,
        rewardXP = 5900,
        itemMin = 12,
        itemMax = 15,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Lakeshire",
        faction = "Alliance",
        zone = "Redridge Mountains",
        minLevel = 14,
        maxLevel = 17,
        rewardXP = 7700,
        itemMin = 14,
        itemMax = 17,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Menethil Harbor",
        faction = "Alliance",
        zone = "Wetlands",
        minLevel = 18,
        maxLevel = 21,
        rewardXP = 10000,
        itemMin = 18,
        itemMax = 21,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Astranaar",
        faction = "Alliance",
        zone = "Ashenvale",
        minLevel = 19,
        maxLevel = 22,
        rewardXP = 10700,
        itemMin = 19,
        itemMax = 22,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Stonetalon Peak",
        faction = "Alliance",
        zone = "Stonetalon Mountains",
        minLevel = 19,
        maxLevel = 22,
        rewardXP = 10700,
        itemMin = 19,
        itemMax = 22,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Southshore",
        faction = "Alliance",
        zone = "Hillsbrad Foothills",
        minLevel = 20,
        maxLevel = 23,
        rewardXP = 11300,
        itemMin = 20,
        itemMax = 23,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Darkshire",
        faction = "Alliance",
        zone = "Duskwood",
        minLevel = 26,
        maxLevel = 29,
        rewardXP = 18000,
        itemMin = 26,
        itemMax = 29,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Nijel's Point",
        faction = "Alliance",
        zone = "Desolace",
        minLevel = 27,
        maxLevel = 30,
        rewardXP = 18000,
        itemMin = 27,
        itemMax = 30,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Rebel Camp",
        faction = "Alliance",
        zone = "Stranglethorn Vale",
        minLevel = 28,
        maxLevel = 31,
        rewardXP = 21600,
        itemMin = 28,
        itemMax = 31,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Refuge Point",
        faction = "Alliance",
        zone = "Arathi Highlands",
        minLevel = 28,
        maxLevel = 31,
        rewardXP = 21600,
        itemMin = 28,
        itemMax = 31,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Theramore",
        faction = "Alliance",
        zone = "Dustwallow Marsh",
        minLevel = 31,
        maxLevel = 34,
        rewardXP = 25600,
        itemMin = 31,
        itemMax = 34,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Thalanaar",
        faction = "Alliance",
        zone = "Feralas",
        minLevel = 34,
        maxLevel = 37,
        rewardXP = 37200,
        itemMin = 34,
        itemMax = 37,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Aerie Peak",
        faction = "Alliance",
        zone = "The Hinterlands",
        minLevel = 37,
        maxLevel = 40,
        rewardXP = 37200,
        itemMin = 37,
        itemMax = 40,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Talrendis Point",
        faction = "Alliance",
        zone = "Azshara",
        minLevel = 39,
        maxLevel = 42,
        rewardXP = 49100,
        itemMin = 39,
        itemMax = 42,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Nethergarde Keep",
        faction = "Alliance",
        zone = "Blasted Lands",
        minLevel = 40,
        maxLevel = 43,
        rewardXP = 51300,
        itemMin = 40,
        itemMax = 43,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Emerald Sanctuary",
        faction = "Alliance",
        zone = "Felwood",
        minLevel = 42,
        maxLevel = 45,
        rewardXP = 55700,
        itemMin = 42,
        itemMax = 45,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Morgan's Vigil",
        faction = "Alliance",
        zone = "Burning Steppes",
        minLevel = 47,
        maxLevel = 50,
        rewardXP = 70000,
        itemMin = 47,
        itemMax = 50,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Bloodhoof Village",
        faction = "Horde",
        zone = "Mulgore",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Brill",
        faction = "Horde",
        zone = "Tirisfal Glades",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Falconwing Square",
        faction = "Horde",
        zone = "Eversong Woods",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Razor Hill",
        faction = "Horde",
        zone = "Durotar",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Fairbreeze Village",
        faction = "Horde",
        zone = "Eversong Woods",
        minLevel = 8,
        maxLevel = 11,
        rewardXP = 3800,
        itemMin = 8,
        itemMax = 11,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Crossroads",
        faction = "Horde",
        zone = "The Barrens",
        minLevel = 11,
        maxLevel = 14,
        rewardXP = 5300,
        itemMin = 11,
        itemMax = 14,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Sepulcher",
        faction = "Horde",
        zone = "Silverpine Forest",
        minLevel = 12,
        maxLevel = 15,
        rewardXP = 5900,
        itemMin = 12,
        itemMax = 15,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Tranquillien",
        faction = "Horde",
        zone = "Ghostlands",
        minLevel = 12,
        maxLevel = 15,
        rewardXP = 5900,
        itemMin = 12,
        itemMax = 15,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Camp Taurajo",
        faction = "Horde",
        zone = "The Barrens",
        minLevel = 17,
        maxLevel = 20,
        rewardXP = 8000,
        itemMin = 17,
        itemMax = 20,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Sun Rock Retreat",
        faction = "Horde",
        zone = "Stonetalon Mountains",
        minLevel = 19,
        maxLevel = 22,
        rewardXP = 10700,
        itemMin = 19,
        itemMax = 22,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Tarren Mill",
        faction = "Horde",
        zone = "Hillsbrad Foothills",
        minLevel = 20,
        maxLevel = 23,
        rewardXP = 11300,
        itemMin = 20,
        itemMax = 23,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Freewind Post",
        faction = "Horde",
        zone = "Thousand Needles",
        minLevel = 22,
        maxLevel = 25,
        rewardXP = 12800,
        itemMin = 22,
        itemMax = 25,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Splintertree Post",
        faction = "Horde",
        zone = "Ashenvale",
        minLevel = 22,
        maxLevel = 25,
        rewardXP = 12800,
        itemMin = 22,
        itemMax = 25,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Hammerfall",
        faction = "Horde",
        zone = "Arathi Highlands",
        minLevel = 27,
        maxLevel = 31,
        rewardXP = 21600,
        itemMin = 27,
        itemMax = 31,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Shadowprey Village",
        faction = "Horde",
        zone = "Desolace",
        minLevel = 31,
        maxLevel = 34,
        rewardXP = 25600,
        itemMin = 31,
        itemMax = 34,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Brackenwall Village",
        faction = "Horde",
        zone = "Dustwallow Marsh",
        minLevel = 32,
        maxLevel = 35,
        rewardXP = 27000,
        itemMin = 32,
        itemMax = 35,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Stonard",
        faction = "Horde",
        zone = "Swamp of Sorrows",
        minLevel = 32,
        maxLevel = 35,
        rewardXP = 27000,
        itemMin = 32,
        itemMax = 35,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Grom'gol Base Camp",
        faction = "Horde",
        zone = "Stranglethorn Vale",
        minLevel = 32,
        maxLevel = 36,
        rewardXP = 35400,
        itemMin = 32,
        itemMax = 36,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Kargath",
        faction = "Horde",
        zone = "Badlands",
        minLevel = 34,
        maxLevel = 37,
        rewardXP = 37200,
        itemMin = 34,
        itemMax = 37,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Camp Mojache",
        faction = "Horde",
        zone = "Feralas",
        minLevel = 35,
        maxLevel = 38,
        rewardXP = nil,
        itemMin = 35,
        itemMax = 38,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Revantusk Village",
        faction = "Horde",
        zone = "The Hinterlands",
        minLevel = 38,
        maxLevel = 41,
        rewardXP = nil,
        itemMin = 38,
        itemMax = 41,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Valormok",
        faction = "Horde",
        zone = "Azshara",
        minLevel = 42,
        maxLevel = 45,
        rewardXP = 55700,
        itemMin = 42,
        itemMax = 45,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
      {
        name = "Bloodvenom Post",
        faction = "Horde",
        zone = "Felwood",
        minLevel = 42,
        maxLevel = 45,
        rewardXP = 55700,
        itemMin = 42,
        itemMax = 45,
        playersRequired = 3,
        cooldownSeconds = 3600,
        x = nil,
        y = nil,
        notes = "",
      },
    }

    SignalFireInvasions = SignalFireInvasions or {}
    SignalFireInvasions.data = SignalFire_InvasionData

    for _, entry in ipairs(SignalFire_InvasionData or {}) do
      if entry.subZone == nil then entry.subZone = entry.name end
      if entry.radiusMapPercent == nil then entry.radiusMapPercent = 0.06 end
      if entry.coordinateSource == nil then entry.coordinateSource = "zone/subzone fallback" end
    end

    function SignalFireInvasions.GetAll()
      return SignalFire_InvasionData or {}
    end

    function SignalFireInvasions.LevelFits(entry, level)
      level = tonumber(level or 0) or 0
      if not entry then return false end
      return level >= (tonumber(entry.minLevel or 0) or 0) and level <= (tonumber(entry.maxLevel or 0) or 0)
    end

    function SignalFireInvasions.LevelNear(entry, level)
      level = tonumber(level or 0) or 0
      if not entry then return false end
      local minLevel = tonumber(entry.minLevel or 0) or 0
      local maxLevel = tonumber(entry.maxLevel or 0) or 0
      return level >= (minLevel - 2) and level <= (maxLevel + 2)
    end

    function SignalFireInvasions.GetRecommended(level)
      local rows = {}
      local nearRows = {}
      local data = SignalFireInvasions.GetAll()
      for i = 1, #data do
        local entry = data[i]
        if SignalFireInvasions.LevelFits(entry, level) then
          table.insert(rows, entry)
        elseif SignalFireInvasions.LevelNear(entry, level) then
          table.insert(nearRows, entry)
        end
      end
      if #rows > 0 then return rows end
      return nearRows
    end

    function SignalFireInvasions.GetByFaction(faction)
      local rows = {}
      faction = tostring(faction or "")
      local data = SignalFireInvasions.GetAll()
      for i = 1, #data do
        local entry = data[i]
        if entry and entry.faction == faction then table.insert(rows, entry) end
      end
      return rows
    end

    function SignalFireInvasions.FormatLevel(entry)
      if not entry then return "--" end
      return tostring(entry.minLevel or "?") .. "-" .. tostring(entry.maxLevel or "?")
    end

    function SignalFireInvasions.FormatXP(entry)
      if not entry or not entry.rewardXP then return "Unknown" end
      return tostring(entry.rewardXP)
    end

    function SignalFireInvasions.FormatCooldown(entry)
      local seconds = tonumber(entry and entry.cooldownSeconds or 0) or 0
      if seconds <= 0 then return "Unknown" end
      if seconds == 3600 then return "1 hour" end
      return tostring(math.floor(seconds / 60)) .. " min"
    end

    function SignalFireInvasions.CountByFaction(faction)
      local rows = SignalFireInvasions.GetByFaction(faction)
      return #rows
    end

    function SignalFireInvasions.GetPlayerZone()
      local zone = GetRealZoneText and GetRealZoneText() or ""
      local subZone = GetSubZoneText and GetSubZoneText() or ""
      return tostring(zone or ""), tostring(subZone or "")
    end

    function SignalFireInvasions.GetPlayerMapPosition()
      if not GetPlayerMapPosition then return nil, nil end
      if SetMapToCurrentZone then SetMapToCurrentZone() end
      local x, y = GetPlayerMapPosition("player")
      x = tonumber(x or 0) or 0
      y = tonumber(y or 0) or 0
      if x <= 0 and y <= 0 then return nil, nil end
      return x, y
    end

    local function sfInvLower(text)
      return string.lower(tostring(text or ""))
    end

    local function sfInvDistancePercent(x1, y1, x2, y2)
      if not x1 or not y1 or not x2 or not y2 then return nil end
      local dx = (tonumber(x1) or 0) - (tonumber(x2) or 0)
      local dy = (tonumber(y1) or 0) - (tonumber(y2) or 0)
      return math.sqrt((dx * dx) + (dy * dy))
    end

    function SignalFireInvasions.EntryMatchesArea(entry, zone, subZone, x, y)
      if not entry then return false end
      zone = sfInvLower(zone)
      subZone = sfInvLower(subZone)
      local entryZone = sfInvLower(entry.zone)
      local entrySub = sfInvLower(entry.subZone or entry.name)
      if zone == "" or entryZone == "" or zone ~= entryZone then return false end
      if entry.x and entry.y and x and y then
        local radius = tonumber(entry.radiusMapPercent or 0.06) or 0.06
        local dist = sfInvDistancePercent(x, y, entry.x, entry.y)
        if dist and dist <= radius then return true end
      end
      if subZone ~= "" and entrySub ~= "" then return subZone == entrySub end
      return not entry.x or not entry.y
    end

    function SignalFireInvasions.GetCurrentInvasionArea()
      local zone, subZone = SignalFireInvasions.GetPlayerZone()
      local x, y = SignalFireInvasions.GetPlayerMapPosition()
      local data = SignalFireInvasions.GetAll()
      for i = 1, #data do
        local entry = data[i]
        if SignalFireInvasions.EntryMatchesArea(entry, zone, subZone, x, y) then return entry, zone, subZone, x, y end
      end
      return nil, zone, subZone, x, y
    end

    function SignalFireInvasions.GetRecommendedSorted(level)
      local rows = {}
      local data = SignalFireInvasions.GetAll()
      level = tonumber(level or 0) or 0
      for i = 1, #data do
        local entry = data[i]
        if SignalFireInvasions.LevelFits(entry, level) or SignalFireInvasions.LevelNear(entry, level) then
          table.insert(rows, entry)
        end
      end
      table.sort(rows, function(a, b)
        local amid = ((tonumber(a.minLevel or 0) or 0) + (tonumber(a.maxLevel or 0) or 0)) / 2
        local bmid = ((tonumber(b.minLevel or 0) or 0) + (tonumber(b.maxLevel or 0) or 0)) / 2
        return math.abs(level - amid) < math.abs(level - bmid)
      end)
      return rows
    end

    SignalFire_GetPlayerZone = function() return SignalFireInvasions.GetPlayerZone() end
    SignalFire_GetPlayerMapPosition = function() return SignalFireInvasions.GetPlayerMapPosition() end
    SignalFire_GetRecommendedInvasionsForLevel = function(level) return SignalFireInvasions.GetRecommendedSorted(level) end
    SignalFire_GetCurrentInvasionArea = function() return SignalFireInvasions.GetCurrentInvasionArea() end
  until true
end

