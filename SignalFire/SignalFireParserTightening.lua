-- SignalFire parser tightening for Triumvirate.
-- Loaded after BronzeLFG.lua so it can safely wrap exported parser hooks.

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
