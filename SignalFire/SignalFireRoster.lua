-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Roster presentation
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFRP_VERSION = _G.SignalFire_VERSION or "1.4.23"
    local SFRP_FRAME_NAME = "SignalFireFullRosterFrame"

    local function sfrp_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfrp_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfrp_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfrp_short(s, n)
      s = tostring(s or "")
      n = tonumber(n) or 0
      if n > 0 and string.len(s) > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
      return s
    end

    local function sfrp_backdrop(frame, alpha, borderAlpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .86)
      frame:SetBackdropBorderColor(.85, .62, .12, borderAlpha or .92)
    end

    local function sfrp_flat(frame, alpha)
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

    local function sfrp_font(parent, text, size, r, g, b)
      local obj = (size and size >= 13) and "GameFontNormal" or "GameFontNormalSmall"
      local fs = parent:CreateFontString(nil, "OVERLAY", obj)
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      if size and fs.SetFont then
        local fontPath, _, flags = fs:GetFont()
        fs:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", size, flags)
      end
      return fs
    end

    local function sfrp_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 110)
      b:SetHeight(h or 22)
      b:SetText(tostring(text or "Button"))
      return b
    end

    local function sfrp_colored_class(file)
      local c = string.upper(tostring(file or ""))
      if c == "WARRIOR" then return "|cffc79c6e"
      elseif c == "PALADIN" then return "|cfff58cba"
      elseif c == "HUNTER" then return "|cffabd473"
      elseif c == "ROGUE" then return "|cfffff569"
      elseif c == "PRIEST" then return "|cffffffff"
      elseif c == "DEATHKNIGHT" or c == "DK" then return "|cffc41f3b"
      elseif c == "SHAMAN" then return "|cff0070de"
      elseif c == "MAGE" then return "|cff69ccf0"
      elseif c == "WARLOCK" then return "|cff9482c9"
      elseif c == "DRUID" then return "|cffff7d0a" end
      return "|cff9fd6ff"
    end

    local function sfrp_role_letter(role)
      local r = tostring(role or "")
      if r == "Tank" then return "|cff4aa3ffT|r" end
      if r == "Healer" then return "|cff44ff66H|r" end
      if r == "DPS" then return "|cffff5555D|r" end
      if r == "Flexible" then return "|cffffff66F|r" end
      if r ~= "" then return "|cffffff66" .. string.sub(r, 1, 1) .. "|r" end
      return "|cff777777-|r"
    end

    local function sfrp_age(t)
      local now = (time and time()) or 0
      local d = now - (tonumber(t) or now)
      if d < 0 then d = 0 end
      if d < 60 then return tostring(d) .. "s" end
      if d < 3600 then return tostring(math.floor(d / 60)) .. "m" end
      if d < 86400 then return tostring(math.floor(d / 3600)) .. "h" end
      return tostring(math.floor(d / 86400)) .. "d"
    end

    local function sfrp_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfrp_my_guild()
      if GetGuildInfo then
        local g = GetGuildInfo("player")
        return g or ""
      end
      return ""
    end

    local function sfrp_is_fav(self, name)
      if self and self.IsFavorite then return self:IsFavorite(name) end
      if BronzeLFG_DB and BronzeLFG_DB.favorites then
        local k = sfrp_low(name or "")
        return BronzeLFG_DB.favorites[k] or BronzeLFG_DB.favorites[name]
      end
      return false
    end

    local function sfrp_display_name(self, u, limit)
      local name = tostring((u and u.name) or "Unknown")
      local prefix = ""
      if u and u.self then prefix = "|cffffd100[Me] |r"
      elseif u and u.favorite then prefix = "|cffffd100[F] |r"
      elseif u and u.friend then prefix = "|cff44ff66[Fr] |r"
      elseif u and u.groupmate then prefix = "|cff4aa3ff[Grp] |r" end
      if u and u.whoOnly then prefix = "|cff999999/w |r" .. prefix end
      return prefix .. sfrp_colored_class(u and u.classFile) .. sfrp_short(name, limit or 16) .. "|r"
    end

    local function sfrp_tooltip(frame, title, body)
      if not frame then return end
      frame:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(tostring(title or "SignalFire"), 1, .82, 0)
        if body and body ~= "" then GameTooltip:AddLine(tostring(body), .85, .85, .85, true) end
        GameTooltip:Show()
      end)
      frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end

    local function sfrp_raise_children(frame, level)
      if not frame or not frame.GetChildren then return end
      level = tonumber(level) or (((frame.GetFrameLevel and frame:GetFrameLevel()) or 1) + 5)
      for _, child in ipairs({frame:GetChildren()}) do
        if child and child.SetFrameLevel then child:SetFrameLevel(level) end
        sfrp_raise_children(child, level + 1)
      end
    end

    local function sfrp_hide_full_roster()
      local f = _G[SFRP_FRAME_NAME]
      if f then f:Hide() end
    end

    local function sfrp_count_rows(rows)
      local stats = {total=0, signalFire=0, whoOnly=0, favorites=0, guilds=0}
      local guilds = {}
      for _, u in ipairs(rows or {}) do
        stats.total = stats.total + 1
        if u.whoOnly then stats.whoOnly = stats.whoOnly + 1 else stats.signalFire = stats.signalFire + 1 end
        if u.favorite then stats.favorites = stats.favorites + 1 end
        local g = tostring(u.guild or "")
        if g ~= "" and not guilds[g] then guilds[g] = true; stats.guilds = stats.guilds + 1 end
      end
      return stats
    end

    local function sfrp_matches_search(u, needle)
      if not needle or needle == "" then return true end
      local blob = sfrp_low(tostring(u.name or "") .. " " .. tostring(u.guild or "") .. " " .. tostring(u.zone or "") .. " " .. tostring(u.role or "") .. " " .. tostring(u.spec or "") .. " " .. tostring(u.className or u.class or "") .. " " .. tostring(u.classFile or ""))
      return string.find(blob, needle, 1, true) ~= nil
    end

    function BLFG:SFRP_GetRosterRows()
      local allRows = self.GetOnlineUserRows and self:GetOnlineUserRows() or {}
      local rows = {}
      local filter = tostring(self.onlineFilter or "All")
      local search = ""
      if self.fullRosterSearch and self.fullRosterSearch.GetText then search = sfrp_low(sfrp_trim(self.fullRosterSearch:GetText() or "")) end
      local myGuild = sfrp_my_guild()

      for _, u in ipairs(allRows) do
        u.favorite = u.favorite or sfrp_is_fav(self, u.name)
        local keep = true
        if filter == "SignalFire" then keep = not u.whoOnly
        elseif filter == "Who" then keep = u.whoOnly == true
        elseif filter == "Favorites" then keep = u.favorite == true
        elseif filter == "Guild" then keep = myGuild ~= "" and tostring(u.guild or "") == myGuild end
        if keep and sfrp_matches_search(u, search) then table.insert(rows, u) end
      end
      return rows, allRows
    end

    local function sfrp_select_user(self, u)
      self.fullRosterSelectedUser = u
      if u and u.name then self.fullRosterSelectedName = tostring(u.name) else self.fullRosterSelectedName = nil end
      if self.RefreshFullRosterDetail then self:RefreshFullRosterDetail() end
      if self.RefreshOnlinePanel then self:RefreshOnlinePanel() end
    end

    function BLFG:RefreshFullRosterDetail()
      local f = self.fullRosterDetail
      if not f then return end
      local u = self.fullRosterSelectedUser
      if (not u) and self.fullRosterSelectedName then
        local wanted = sfrp_low(self.fullRosterSelectedName)
        local rows = self.GetOnlineUserRows and self:GetOnlineUserRows() or {}
        for _, row in ipairs(rows) do
          if sfrp_low(row.name or "") == wanted then u = row; self.fullRosterSelectedUser = row; break end
        end
      end

      if not u then
        f.name:SetText("Select a player")
        f.meta:SetText("Click a row to view details and quick actions.")
        f.detail:SetText("|cff888888No roster entry selected.|r")
        if f.whisper then f.whisper:Disable() end
        if f.invite then f.invite:Disable() end
        if f.who then f.who:Disable() end
        if f.favorite then f.favorite:Disable() end
        if f.copy then f.copy:Disable() end
        if f.profile then f.profile:Disable() end
        return
      end

      local name = tostring(u.name or "Unknown")
      f.name:SetText(sfrp_display_name(self, u, 22))
      f.meta:SetText("Level " .. tostring(u.level or "?") .. "  |  " .. tostring(u.className or u.class or u.classFile or "Unknown") .. "  |  " .. tostring(u.role or "Unknown"))

      local lines = {}
      table.insert(lines, "|cffffcc00Source:|r " .. (u.whoOnly and "/who discovered" or "SignalFire presence"))
      table.insert(lines, "|cffffcc00Status:|r " .. (u.self and "You" or (u.friend and "Friend" or (u.groupmate and "Party/Raid" or "Online"))))
      table.insert(lines, "|cffffcc00Role:|r " .. tostring(u.role or "Unknown"))
      if u.spec and tostring(u.spec) ~= "" then table.insert(lines, "|cffffcc00Spec:|r " .. tostring(u.spec)) end
      if u.zone and tostring(u.zone) ~= "" then table.insert(lines, "|cffffcc00Zone:|r " .. tostring(u.zone)) end
      if u.guild and tostring(u.guild) ~= "" then table.insert(lines, "|cffffcc00Guild:|r " .. tostring(u.guild)) end
      table.insert(lines, "|cffffcc00Last Seen:|r " .. sfrp_age(u.seen))
      table.insert(lines, "|cffffcc00Favorite:|r " .. (sfrp_is_fav(self, name) and "Yes" or "No"))
      table.insert(lines, "")
      if u.whoOnly then
        table.insert(lines, "|cff999999This player was discovered through the online roster scan. Some SignalFire-specific profile data may be unavailable.|r")
      else
        table.insert(lines, "|cff99ff99Right-click the row for the full actions menu.|r")
      end
      f.detail:SetText(table.concat(lines, "\n"))

      local canTarget = name ~= "" and name ~= sfrp_player()
      if f.whisper then if canTarget then f.whisper:Enable() else f.whisper:Disable() end end
      if f.invite then if canTarget then f.invite:Enable() else f.invite:Disable() end end
      if f.who then f.who:Enable() end
      if f.favorite then f.favorite:Enable(); f.favorite:SetText(sfrp_is_fav(self, name) and "Unfavorite" or "Favorite") end
      if f.copy then f.copy:Enable() end
      if f.profile then if self.ShowBronzeNetProfile then f.profile:Enable() else f.profile:Disable() end end

      if f.whisper then f.whisper:SetScript("OnClick", function() if canTarget and ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end end) end
      if f.invite then f.invite:SetScript("OnClick", function() if canTarget and InviteUnit then InviteUnit(name) end end) end
      if f.who then f.who:SetScript("OnClick", function()
        if SendWho then SendWho(name); sfrp_msg("Who lookup sent for " .. name .. ".")
        elseif ChatFrame_OpenChat then ChatFrame_OpenChat("/who " .. name) end
      end) end
      if f.copy then f.copy:SetScript("OnClick", function() if ChatFrame_OpenChat then ChatFrame_OpenChat(name) end end) end
      if f.profile then f.profile:SetScript("OnClick", function() if BLFG.ShowBronzeNetProfile then BLFG:ShowBronzeNetProfile(u) end end) end
      if f.favorite then f.favorite:SetScript("OnClick", function()
        if BLFG.ToggleFavorite then BLFG:ToggleFavorite(name) end
        u.favorite = sfrp_is_fav(BLFG, name)
        BLFG:RefreshFullRosterDetail()
        BLFG:RefreshOnlinePanel()
        if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
        if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      end) end
    end

    local function sfrp_make_detail(parent)
      local d = CreateFrame("Frame", nil, parent)
      d:SetWidth(260); d:SetHeight(370)
      d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -18, -126)
      sfrp_flat(d, .78)
      parent.detailPane = d

      d.title = sfrp_font(d, "Selected Player", 12, 1, .82, 0)
      d.title:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -10)
      d.name = sfrp_font(d, "Select a player", 13, .65, .85, 1)
      d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -34)
      d.name:SetWidth(238); d.name:SetJustifyH("LEFT")
      d.meta = sfrp_font(d, "Click a row to view details.", 9, .82, .82, .82)
      d.meta:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -4)
      d.meta:SetWidth(238); d.meta:SetJustifyH("LEFT")

      d.detail = sfrp_font(d, "", 10, .9, .9, .9)
      d.detail:SetPoint("TOPLEFT", d, "TOPLEFT", 10, -82)
      d.detail:SetWidth(238); d.detail:SetHeight(176)
      d.detail:SetJustifyH("LEFT"); d.detail:SetJustifyV("TOP")

      d.whisper = sfrp_button(d, "Whisper", 70, 22)
      d.whisper:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 76)
      d.invite = sfrp_button(d, "Invite", 70, 22)
      d.invite:SetPoint("LEFT", d.whisper, "RIGHT", 8, 0)
      d.who = sfrp_button(d, "Who", 54, 22)
      d.who:SetPoint("LEFT", d.invite, "RIGHT", 8, 0)

      d.favorite = sfrp_button(d, "Favorite", 88, 22)
      d.favorite:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 48)
      d.copy = sfrp_button(d, "Copy Name", 98, 22)
      d.copy:SetPoint("LEFT", d.favorite, "RIGHT", 8, 0)

      d.profile = sfrp_button(d, "Profile", 82, 22)
      d.profile:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 10, 20)
      d.menuHint = sfrp_font(d, "Right-click roster rows for more actions.", 9, .65, .85, 1)
      d.menuHint:SetPoint("LEFT", d.profile, "RIGHT", 10, 0)
      d.menuHint:SetWidth(126); d.menuHint:SetJustifyH("LEFT")

      return d
    end

    local function sfrp_set_filter(self, filter)
      self.onlineFilter = filter or "All"
      self.onlinePage = 1
      if self.RefreshOnlinePanel then self:RefreshOnlinePanel() end
    end

    function BLFG:BuildOnlinePanel()
      if self.onlinePanel and self.onlinePanel._sfrpFullRoster then return end

      local parent = UIParent or (self.frame or nil)
      local f = CreateFrame("Frame", SFRP_FRAME_NAME, parent)
      self.onlinePanel = f
      _G[SFRP_FRAME_NAME] = f
      f._sfrpFullRoster = true
      f:SetWidth(860); f:SetHeight(560)
      f:SetPoint("CENTER", UIParent or parent, "CENTER", 0, 0)
      f:SetFrameStrata("FULLSCREEN_DIALOG")
      f:SetFrameLevel(9000)
      f:SetToplevel(true)
      f:EnableMouse(true)
      f:SetMovable(true)
      f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", function(selfFrame) selfFrame:StartMoving() end)
      f:SetScript("OnDragStop", function(selfFrame) selfFrame:StopMovingOrSizing() end)
      if f.SetClampedToScreen then f:SetClampedToScreen(true) end
      f:Hide()
      sfrp_backdrop(f, .985, 1)
      f:SetAlpha(1)

      if UISpecialFrames then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == SFRP_FRAME_NAME then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, SFRP_FRAME_NAME) end
      end
      if f.EnableKeyboard then f:EnableKeyboard(true) end
      f:SetScript("OnKeyDown", function(selfFrame, key)
        if key == "ESCAPE" then selfFrame:Hide() end
      end)
      f:SetScript("OnShow", function(selfFrame)
        selfFrame:EnableKeyboard(true)
        selfFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        selfFrame:SetFrameLevel(9000)
        selfFrame:Raise()
        sfrp_raise_children(selfFrame, 9010)
      end)
      f:SetScript("OnHide", function()
        if GameTooltip then GameTooltip:Hide() end
        if CloseDropDownMenus then CloseDropDownMenus() end
        if BLFG and BLFG._sfrpRestoreMainFrameOnClose and BLFG.frame then
          BLFG._sfrpRestoreMainFrameOnClose = nil
          BLFG.frame:Show()
        end
      end)

      local drag = CreateFrame("Frame", nil, f)
      drag:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
      drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -6)
      drag:SetHeight(34)
      drag:EnableMouse(true)
      drag:RegisterForDrag("LeftButton")
      drag:SetScript("OnDragStart", function() f:StartMoving() end)
      drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

      local title = sfrp_font(f, "SignalFire Full Roster", 16, 1, .75, 0)
      title:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -16)
      self.onlinePanelTitle = title

      local subtitle = sfrp_font(f, "Expanded online directory for SignalFire presence and /who-discovered players.", 10, .82, .82, .82)
      subtitle:SetPoint("LEFT", title, "RIGHT", 16, 0)
      subtitle:SetWidth(450); subtitle:SetJustifyH("LEFT")
      f.subtitle = subtitle

      local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
      close:SetFrameLevel(9020)
      close:SetScript("OnClick", function() f:Hide() end)
      f.closeButton = close

      local statsBar = CreateFrame("Frame", nil, f)
      statsBar:SetWidth(830); statsBar:SetHeight(42)
      statsBar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -48)
      sfrp_flat(statsBar, .68)
      f.statsBar = statsBar

      f.statTotal = sfrp_font(statsBar, "Total: 0", 11, .65, .85, 1)
      f.statTotal:SetPoint("LEFT", statsBar, "LEFT", 10, 8)
      f.statSF = sfrp_font(statsBar, "SignalFire: 0", 11, .65, 1, .65)
      f.statSF:SetPoint("LEFT", statsBar, "LEFT", 110, 8)
      f.statWho = sfrp_font(statsBar, "Online: 0", 11, .78, .78, .78)
      f.statWho:SetPoint("LEFT", statsBar, "LEFT", 238, 8)
      f.statFav = sfrp_font(statsBar, "Favorites: 0", 11, 1, .82, .25)
      f.statFav:SetPoint("LEFT", statsBar, "LEFT", 346, 8)
      f.statGuilds = sfrp_font(statsBar, "Guilds: 0", 11, .9, .82, .55)
      f.statGuilds:SetPoint("LEFT", statsBar, "LEFT", 468, 8)

      f.onlineStats = sfrp_font(statsBar, "", 9, .82, .82, .82)
      self.onlineStats = f.onlineStats
      f.onlineStats:SetPoint("LEFT", statsBar, "LEFT", 10, -10)
      f.onlineStats:SetWidth(520); f.onlineStats:SetJustifyH("LEFT")

      local refresh = sfrp_button(statsBar, "Refresh Ping", 104, 22)
      refresh:SetPoint("RIGHT", statsBar, "RIGHT", -10, 0)
      refresh:SetScript("OnClick", function()
        if BLFG.SendPresence then BLFG:SendPresence() end
        if BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
        sfrp_msg("SignalFire presence ping sent.")
      end)
      f.refreshButton = refresh

      local filterBar = CreateFrame("Frame", nil, f)
      filterBar:SetWidth(830); filterBar:SetHeight(28)
      filterBar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -96)
      f.filterBar = filterBar

      self.onlineFilter = self.onlineFilter or "All"
      local all = sfrp_button(filterBar, "All", 72, 22)
      all:SetPoint("LEFT", filterBar, "LEFT", 0, 0)
      all:SetScript("OnClick", function() sfrp_set_filter(BLFG, "All") end)
      local sf = sfrp_button(filterBar, "SignalFire", 96, 22)
      sf:SetPoint("LEFT", all, "RIGHT", 6, 0)
      sf:SetScript("OnClick", function() sfrp_set_filter(BLFG, "SignalFire") end)
      local whoOnly = sfrp_button(filterBar, "Online", 88, 22)
      whoOnly:SetPoint("LEFT", sf, "RIGHT", 6, 0)
      whoOnly:SetScript("OnClick", function() sfrp_set_filter(BLFG, "Who") end)
      local fav = sfrp_button(filterBar, "Favorites", 92, 22)
      fav:SetPoint("LEFT", whoOnly, "RIGHT", 6, 0)
      fav:SetScript("OnClick", function() sfrp_set_filter(BLFG, "Favorites") end)
      local guild = sfrp_button(filterBar, "My Guild", 82, 22)
      guild:SetPoint("LEFT", fav, "RIGHT", 6, 0)
      guild:SetScript("OnClick", function() sfrp_set_filter(BLFG, "Guild") end)
      self.onlineFilterButtons = {All=all, SignalFire=sf, Who=whoOnly, Favorites=fav, Guild=guild}

      local searchLabel = sfrp_font(filterBar, "Search", 10, .82, .82, .82)
      searchLabel:SetPoint("LEFT", guild, "RIGHT", 16, 0)
      local search = CreateFrame("EditBox", nil, filterBar)
      self.fullRosterSearch = search
      search:SetWidth(150); search:SetHeight(22)
      search:SetPoint("LEFT", searchLabel, "RIGHT", 6, 0)
      search:EnableMouse(true)
      search:SetAutoFocus(false)
      search:SetFontObject(GameFontHighlightSmall)
      search:SetTextInsets(6, 6, 2, 2)
      search:SetMaxLetters(40)
      sfrp_backdrop(search, .62)
      search:SetScript("OnEscapePressed", function(selfBox) selfBox:ClearFocus(); sfrp_hide_full_roster() end)
      search:SetScript("OnEnterPressed", function(selfBox) selfBox:ClearFocus() end)
      search:SetScript("OnTextChanged", function() BLFG.onlinePage = 1; BLFG:RefreshOnlinePanel() end)
      local clear = sfrp_button(filterBar, "Clear", 54, 22)
      clear:SetPoint("LEFT", search, "RIGHT", 6, 0)
      clear:SetScript("OnClick", function() search:SetText(""); search:ClearFocus(); BLFG.onlinePage = 1; BLFG:RefreshOnlinePanel() end)

      local rosterBox = CreateFrame("Frame", nil, f)
      rosterBox:SetWidth(560); rosterBox:SetHeight(370)
      rosterBox:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -126)
      sfrp_flat(rosterBox, .58)
      f.rosterBox = rosterBox

      local header = CreateFrame("Frame", nil, rosterBox)
      header:SetWidth(540); header:SetHeight(24)
      header:SetPoint("TOPLEFT", rosterBox, "TOPLEFT", 10, -10)
      sfrp_flat(header, .92)
      f.onlineHeader = header
      sfrp_font(header, "Name", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 8, 0)
      sfrp_font(header, "Lvl", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 168, 0)
      sfrp_font(header, "Role", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 206, 0)
      sfrp_font(header, "Zone", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 248, 0)
      sfrp_font(header, "Guild", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 370, 0)
      sfrp_font(header, "Seen", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 494, 0)

      self.onlineRows = {}
      for i=1,8 do
        local r = CreateFrame("Button", nil, rosterBox)
        r:SetWidth(540); r:SetHeight(35)
        r:SetPoint("TOPLEFT", rosterBox, "TOPLEFT", 10, -39 - ((i-1)*38))
        sfrp_flat(r, .70)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        r.name = sfrp_font(r, "", 9, .65, .85, 1); r.name:SetPoint("LEFT", r, "LEFT", 8, 0); r.name:SetWidth(154); r.name:SetJustifyH("LEFT")
        r.level = sfrp_font(r, "", 9, 1, 1, 1); r.level:SetPoint("LEFT", r, "LEFT", 168, 0); r.level:SetWidth(30); r.level:SetJustifyH("LEFT")
        r.role = sfrp_font(r, "", 10, 1, 1, 1); r.role:SetPoint("LEFT", r, "LEFT", 206, 0); r.role:SetWidth(34); r.role:SetJustifyH("CENTER")
        r.zone = sfrp_font(r, "", 9, .9, .9, .9); r.zone:SetPoint("LEFT", r, "LEFT", 248, 0); r.zone:SetWidth(116); r.zone:SetJustifyH("LEFT")
        r.guild = sfrp_font(r, "", 9, .9, .82, .55); r.guild:SetPoint("LEFT", r, "LEFT", 370, 0); r.guild:SetWidth(118); r.guild:SetJustifyH("LEFT")
        r.seen = sfrp_font(r, "", 9, .8, .8, .8); r.seen:SetPoint("LEFT", r, "LEFT", 494, 0); r.seen:SetWidth(38); r.seen:SetJustifyH("LEFT")
        r:SetScript("OnClick", function(row, mouseButton)
          if not row.user then return end
          if mouseButton == "RightButton" then
            if BLFG.ShowOnlineUserMenu then BLFG:ShowOnlineUserMenu(row, row.user) end
          else
            sfrp_select_user(BLFG, row.user)
          end
        end)
        r:SetScript("OnEnter", function(row)
          if not row.user then return end
          if row.SetBackdropBorderColor then row:SetBackdropBorderColor(1, .82, .18, 1) end
          if GameTooltip then
            local u = row.user
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:AddLine(u.whoOnly and "/who Discovered Player" or "SignalFire User", 1, .82, 0)
            GameTooltip:AddLine(tostring(u.name or "Unknown"), .65, .85, 1)
            if u.guild and tostring(u.guild) ~= "" then GameTooltip:AddLine("Guild: " .. tostring(u.guild), .9, .82, .55) end
            if u.zone and tostring(u.zone) ~= "" then GameTooltip:AddLine("Zone: " .. tostring(u.zone), .9, .9, .9) end
            if u.role and tostring(u.role) ~= "" then GameTooltip:AddLine("Role: " .. tostring(u.role), 1, 1, 1) end
            if u.spec and tostring(u.spec) ~= "" then GameTooltip:AddLine("Spec: " .. tostring(u.spec), 1, 1, 1) end
            GameTooltip:AddLine("Left-click for details. Right-click for actions.", .4, 1, .4)
            GameTooltip:Show()
          end
        end)
        r:SetScript("OnLeave", function(row)
          if BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
          if GameTooltip then GameTooltip:Hide() end
        end)
        self.onlineRows[i] = r
      end

      self.fullRosterDetail = sfrp_make_detail(f)

      self.onlineFooter = sfrp_font(f, "", 10, .65, .85, 1)
      self.onlineFooter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 48)
      self.onlineFooter:SetWidth(360); self.onlineFooter:SetJustifyH("LEFT")

      self.onlineNote = sfrp_font(f, "Page 1 / 1", 10, .82, .82, .82)
      self.onlineNote:SetPoint("BOTTOM", f, "BOTTOM", -42, 48)

      local up = sfrp_button(f, "Prev", 66, 22)
      up:SetPoint("BOTTOM", f, "BOTTOM", -42, 18)
      up:SetScript("OnClick", function() BLFG.onlinePage = math.max(1, (BLFG.onlinePage or 1) - 1); BLFG:RefreshOnlinePanel() end)
      local down = sfrp_button(f, "Next", 66, 22)
      down:SetPoint("LEFT", up, "RIGHT", 8, 0)
      down:SetScript("OnClick", function() BLFG.onlinePage = (BLFG.onlinePage or 1) + 1; BLFG:RefreshOnlinePanel() end)
      self.onlinePageUp = up
      self.onlinePageDown = down

      local who = sfrp_button(f, "Who List to Chat", 126, 24)
      who:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
      who:SetScript("OnClick", function() if BLFG.PrintOnlineUsers then BLFG:PrintOnlineUsers() end end)
      local hide = sfrp_button(f, "Close Roster", 118, 24)
      hide:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 18)
      hide:SetScript("OnClick", function() f:Hide() end)
      f.hideButton = hide

      sfrp_tooltip(refresh, "Refresh Ping", "Broadcast your current SignalFire presence and refresh the roster view.")
      sfrp_tooltip(search, "Search Full Roster", "Filter by player name, guild, zone, role, spec, or class.")
      sfrp_raise_children(f, 9010)
    end

    function BLFG:RefreshOnlinePanel()
      if not self.onlinePanel or not self.onlineRows then return end
      if not self.onlinePanel._sfrpFullRoster then return end

      local rows, allRows = self:SFRP_GetRosterRows()
      local allStats = sfrp_count_rows(allRows)
      local shownStats = sfrp_count_rows(rows)
      local per = #(self.onlineRows or {})
      if per < 1 then per = 8 end
      local pages = math.max(1, math.ceil(#rows / per))
      self.onlinePage = math.max(1, math.min(tonumber(self.onlinePage or 1) or 1, pages))
      local start = ((self.onlinePage - 1) * per) + 1

      if self.onlinePanelTitle then self.onlinePanelTitle:SetText("SignalFire Full Roster") end
      local f = self.onlinePanel
      if f.statTotal then f.statTotal:SetText("Total: " .. tostring(allStats.total)) end
      if f.statSF then f.statSF:SetText("SignalFire: " .. tostring(allStats.signalFire)) end
      if f.statWho then f.statWho:SetText("Online: " .. tostring(allStats.whoOnly)) end
      if f.statFav then f.statFav:SetText("Favorites: " .. tostring(allStats.favorites)) end
      if f.statGuilds then f.statGuilds:SetText("Guilds: " .. tostring(allStats.guilds)) end
      if self.onlineStats then
        local filterName = tostring(self.onlineFilter or "All")
        if filterName == "Who" then filterName = "Online /who" end
        self.onlineStats:SetText("Showing " .. tostring(shownStats.total) .. " result(s)  |  Filter: " .. filterName .. "  |  Search narrows name, guild, zone, role, spec, and class.")
      end

      if self.onlineFilterButtons then
        local current = tostring(self.onlineFilter or "All")
        local labels = {
          All="All (" .. tostring(allStats.total) .. ")",
          SignalFire="SignalFire (" .. tostring(allStats.signalFire) .. ")",
          Who="Online (" .. tostring(allStats.whoOnly) .. ")",
          Favorites="Favorites (" .. tostring(allStats.favorites) .. ")",
          Guild="My Guild",
        }
        for k, b in pairs(self.onlineFilterButtons) do
          if b then
            local text = labels[k] or k
            if current == k then text = "[" .. text .. "]" end
            b:SetText(text)
          end
        end
      end

      if self.onlineFooter then self.onlineFooter:SetText("Left-click a row for details. Right-click for actions.") end
      if self.onlineNote then self.onlineNote:SetText("Page " .. tostring(self.onlinePage) .. " / " .. tostring(pages)) end
      if self.onlinePageUp then if self.onlinePage <= 1 then self.onlinePageUp:Disable() else self.onlinePageUp:Enable() end end
      if self.onlinePageDown then if self.onlinePage >= pages then self.onlinePageDown:Disable() else self.onlinePageDown:Enable() end end

      local selectedFound = false
      for i, r in ipairs(self.onlineRows) do
        local u = rows[start + i - 1]
        if u then
          r:Show()
          r.user = u
          r.playerName = u.name
          local selected = self.fullRosterSelectedName and sfrp_low(self.fullRosterSelectedName) == sfrp_low(u.name or "")
          if selected then selectedFound = true end
          r.name:SetText(sfrp_display_name(self, u, 16))
          r.level:SetText(sfrp_short(u.level or "?", 3))
          r.role:SetText(sfrp_role_letter(u.role))
          r.zone:SetText(sfrp_short(u.zone or "", 18))
          r.guild:SetText(sfrp_short(u.guild or "", 16))
          r.seen:SetText(sfrp_age(u.seen))
          if selected then
            sfrp_flat(r, .90)
            if r.SetBackdropBorderColor then r:SetBackdropBorderColor(1, .82, .18, 1) end
          elseif u.self then sfrp_flat(r, .84)
          elseif u.favorite then sfrp_flat(r, .82)
          elseif u.friend then sfrp_flat(r, .78)
          elseif u.whoOnly then sfrp_flat(r, .56)
          else sfrp_flat(r, .68) end
        else
          r.user = nil
          r.playerName = nil
          r:Hide()
        end
      end

      if (not self.fullRosterSelectedUser) and rows[1] then
        self.fullRosterSelectedUser = rows[1]
        self.fullRosterSelectedName = tostring(rows[1].name or "")
        selectedFound = true
      elseif self.fullRosterSelectedName and not selectedFound then
        -- Keep the detail panel readable even if the selected row is on another page/filter.
      end
      if self.RefreshFullRosterDetail then self:RefreshFullRosterDetail() end
    end

    function BLFG:ShowFullRoster()
      if self.CreateUI then self:CreateUI() end
      if not self.onlinePanel or not self.onlinePanel._sfrpFullRoster then self:BuildOnlinePanel() end
      if self.onlinePanel then
        if self.frame and self.frame.IsShown and self.frame:IsShown() then
          self._sfrpRestoreMainFrameOnClose = true
          self.frame:Hide()
        else
          self._sfrpRestoreMainFrameOnClose = nil
        end
        self.onlinePanel:ClearAllPoints()
        self.onlinePanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        self.onlinePanel:SetFrameStrata("FULLSCREEN_DIALOG")
        self.onlinePanel:SetFrameLevel(9000)
        self.onlinePanel:Show()
        if self.onlinePanel.Raise then self.onlinePanel:Raise() end
        sfrp_raise_children(self.onlinePanel, 9010)
        if self.SendPresence then self:SendPresence() end
        if self.RefreshOnlinePanel then self:RefreshOnlinePanel() end
      else
        sfrp_msg("Full Roster panel is not available yet.", 1, .35, .35)
      end
    end

    function BLFG:ToggleFullRoster()
      if not self.onlinePanel or not self.onlinePanel._sfrpFullRoster then self:BuildOnlinePanel() end
      if self.onlinePanel and self.onlinePanel:IsShown() then self.onlinePanel:Hide() else self:ShowFullRoster() end
    end

    function BLFG:ToggleOnlinePanel()
      self:ToggleFullRoster()
    end

    local function sfrp_online_count(self)
      local rows = self and self.GetOnlineUserRows and self:GetOnlineUserRows() or {}
      return #(rows or {})
    end

    local function sfrp_apply_public_button(self)
      if not self or not self.onlinePanelButton then return end
      local count = sfrp_online_count(self)
      self.onlinePanelButton:SetText("Full Roster (" .. tostring(count) .. ")")
      self.onlinePanelButton:SetWidth(146)
      sfrp_tooltip(self.onlinePanelButton, "SignalFire Full Roster", "Open the expanded online directory with level, role, zone, guild, seen time, and /who-discovered users.")
    end

    local function sfrp_apply_guild_button(self)
      if not self or not self.guildOpenOnlineButton then return end
      self.guildOpenOnlineButton:SetText("Full Roster")
      self.guildOpenOnlineButton:SetWidth(120)
      sfrp_tooltip(self.guildOpenOnlineButton, "SignalFire Full Roster", "Open the expanded online directory. The main SignalFire Network hub stays in the left Network tab.")
    end

    local SFRP_OldBuildPublicGroups = BLFG.BuildPublicGroups
    function BLFG:BuildPublicGroups(...)
      local r = SFRP_OldBuildPublicGroups and SFRP_OldBuildPublicGroups(self, ...)
      sfrp_apply_public_button(self)
      return r
    end

    local SFRP_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
    function BLFG:RefreshPublicGroups(...)
      local r = SFRP_OldRefreshPublicGroups and SFRP_OldRefreshPublicGroups(self, ...)
      sfrp_apply_public_button(self)
      return r
    end

    local SFRP_OldBuildGuildBrowser = BLFG.BuildGuildBrowser
    function BLFG:BuildGuildBrowser(...)
      local r = SFRP_OldBuildGuildBrowser and SFRP_OldBuildGuildBrowser(self, ...)
      sfrp_apply_guild_button(self)
      return r
    end

    local SFRP_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
    function BLFG:RefreshGuildBrowser(...)
      local r = SFRP_OldRefreshGuildBrowser and SFRP_OldRefreshGuildBrowser(self, ...)
      sfrp_apply_guild_button(self)
      return r
    end

    local function sfrp_install_network_full_roster_button(self)
      if not self or not self.sfnUserRows or not self.sfnUserRows[1] then return end
      local host = self.sfnUserRows[1]:GetParent()
      if not host then return end

      if self.sfnFullRosterButton and self.sfnFullRosterButton.GetParent and self.sfnFullRosterButton:GetParent() ~= host then
        self.sfnFullRosterButton:Hide()
        self.sfnFullRosterButton = nil
      end

      if not self.sfnFullRosterButton then
        local b = sfrp_button(host, "View Full Roster", 118, 22)
        self.sfnFullRosterButton = b
        b:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -8)
        b:SetScript("OnClick", function() BLFG:ShowFullRoster() end)
        sfrp_tooltip(b, "View Full Roster", "Open the expanded roster/directory with guild, level, seen time, and /who-discovered players.")
      else
        self.sfnFullRosterButton:ClearAllPoints()
        self.sfnFullRosterButton:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -8)
        self.sfnFullRosterButton:SetText("View Full Roster")
        self.sfnFullRosterButton:Show()
      end
    end

    local SFRP_OldBuildSFNetworkPanel = BLFG.BuildSFNetworkPanel
    function BLFG:BuildSFNetworkPanel(...)
      local r = SFRP_OldBuildSFNetworkPanel and SFRP_OldBuildSFNetworkPanel(self, ...)
      sfrp_install_network_full_roster_button(self)
      return r
    end

    local SFRP_OldRefreshSFNetwork = BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      local r = SFRP_OldRefreshSFNetwork and SFRP_OldRefreshSFNetwork(self, ...)
      sfrp_install_network_full_roster_button(self)
      return r
    end

    local SFRP_OldShowSFNetwork = BLFG.ShowSFNetwork
    function BLFG:ShowSFNetwork(...)
      local r = SFRP_OldShowSFNetwork and SFRP_OldShowSFNetwork(self, ...)
      sfrp_install_network_full_roster_button(self)
      return r
    end

    local function sfrp_handle_roster_slash(input)
      local cmd = sfrp_low(sfrp_trim(input or ""))
      if cmd == "roster" or cmd == "fullroster" or cmd == "full roster" or cmd == "directory" or cmd == "online" then
        BLFG:ShowFullRoster()
        return true
      end
      return false
    end

    local SFRP_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"]
    local SFRP_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"]
    if SlashCmdList then
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sfrp_handle_roster_slash(input) then return end
        if SFRP_OldSlashSF then return SFRP_OldSlashSF(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sfrp_handle_roster_slash(input) then return end
        if SFRP_OldSlashBLFG then return SFRP_OldSlashBLFG(input) end
      end
    end

    BLFG.SFRosterPolishVersion = SFRP_VERSION
  until true
end

-- Favorite alerts
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFN138_VERSION = _G.SignalFire_VERSION or "1.4.23"
    BLFG.SFN138_FavoriteAlertsInstalled = true

    local function sfn138_now()
      return (time and time()) or 0
    end

    local function sfn138_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfn138_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfn138_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfn138_clean(s, maxLen)
      s = sfn138_trim(s)
      s = string.gsub(s, "[~|\r\n]", " ")
      s = string.gsub(s, "%s+", " ")
      maxLen = tonumber(maxLen) or 0
      if maxLen > 0 and string.len(s) > maxLen then s = string.sub(s, 1, maxLen - 3) .. "..." end
      return s
    end

    local function sfn138_key(name)
      name = sfn138_low(sfn138_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      return name
    end

    local function sfn138_short(s, n)
      s = tostring(s or "")
      n = tonumber(n) or 0
      if n > 0 and string.len(s) > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
      return s
    end

    local function sfn138_split(s)
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

    local function sfn138_ensure_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.network = BronzeLFG_DB.network or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}

      local o = BronzeLFG_DB.options
      if o.favoritePlayerOnlineAlerts == nil then o.favoritePlayerOnlineAlerts = true end
      if o.favoritePlayerListingAlerts == nil then o.favoritePlayerListingAlerts = true end
      if o.favoriteActivityFeed == nil then o.favoriteActivityFeed = true end
      if o.favoriteAlertSound == nil then o.favoriteAlertSound = false end
      if o.favoriteAlertToasts == nil then o.favoriteAlertToasts = true end
      -- Intentionally off for 1.3.8 per Stacey's direction: guild recruitment alerts are not part of this build.
      o.favoriteGuildRecruitmentAlerts = false

      local n = BronzeLFG_DB.signalFireNetwork
      n.favoriteActivity = n.favoriteActivity or {}
      n.favoriteAlertCooldowns = n.favoriteAlertCooldowns or {}
      n.favoriteAlertSeenListings = n.favoriteAlertSeenListings or {}
      n.favoriteOnlineSeen = n.favoriteOnlineSeen or {}

      -- Mirror these onto BronzeLFG_DB.network for easier troubleshooting/user inspection.
      BronzeLFG_DB.network.favoriteActivity = n.favoriteActivity
      BronzeLFG_DB.network.favoriteAlertCooldowns = n.favoriteAlertCooldowns
      BronzeLFG_DB.network.favoriteAlertSeenListings = n.favoriteAlertSeenListings
      BronzeLFG_DB.network.favoriteOnlineSeen = n.favoriteOnlineSeen
      return n, o
    end

    local function sfn138_is_favorite(name)
      name = tostring(name or "")
      if name == "" then return false end
      if BLFG and BLFG.IsFavorite then return BLFG:IsFavorite(name) and true or false end
      local f = BronzeLFG_DB and BronzeLFG_DB.favorites or nil
      if not f then return false end
      return f[sfn138_key(name)] or f[name]
    end

    local function sfn138_activity(title, body, icon)
      local n, o = sfn138_ensure_db()
      if o.favoriteActivityFeed == false then return end
      table.insert(n.favoriteActivity, 1, {
        title = sfn138_clean(title or "Favorite Activity", 86),
        body = sfn138_clean(body or "", 128),
        icon = icon or "Interface\\Icons\\INV_Misc_GroupLooking",
        created = sfn138_now(),
      })
      while #n.favoriteActivity > 15 do table.remove(n.favoriteActivity) end
    end

    function BLFG:SFN138_AddFavoriteActivity(title, body, icon)
      sfn138_activity(title, body, icon)
      if self.RefreshSFNetwork then self:RefreshSFNetwork() end
    end

    -- SignalFireNetworkPlus had an old optional favorite-guild activity hook that called
    -- a missing global.  Keep it harmless, and keep guild alerts off for this build.
    _G.sfn_add_activity = function(...) end

    local function sfn138_cooldown_ok(key, seconds)
      local n = sfn138_ensure_db()
      local stamp = sfn138_now()
      key = tostring(key or "")
      seconds = tonumber(seconds) or 0
      if key == "" then return true end
      local last = tonumber(n.favoriteAlertCooldowns[key] or 0) or 0
      if seconds > 0 and last > 0 and (stamp - last) < seconds then return false end
      n.favoriteAlertCooldowns[key] = stamp
      return true
    end

    local function sfn138_emit(title, body, icon, cooldownKey, cooldownSeconds)
      local _, o = sfn138_ensure_db()
      if not sfn138_cooldown_ok(cooldownKey, cooldownSeconds) then return false end

      title = sfn138_clean(title or "Favorite Alert", 80)
      body = sfn138_clean(body or "", 140)
      icon = icon or "Interface\\Icons\\INV_Misc_GroupLooking"

      sfn138_activity(title, body, icon)

      if DEFAULT_CHAT_FRAME then
        local suffix = body ~= "" and (" - " .. body) or ""
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire Favorite>|r " .. title .. suffix, 1, .82, 0)
      end
      if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage("SignalFire: " .. title, 1, .82, 0, 1.0, 4)
      end
      if o.favoriteAlertSound == true and PlaySoundFile then
        PlaySoundFile("Sound\\Interface\\RaidWarning.wav")
      end
      if o.favoriteAlertToasts ~= false and BLFG.SFAM_ShowToast then
        BLFG:SFAM_ShowToast(title, body, icon, 5)
      end
      if BLFG.SFAM_MarkRelevant then BLFG:SFAM_MarkRelevant("Favorite activity", 7) end
      if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      return true
    end

    local function sfn138_alert_online(u, source)
      local _, o = sfn138_ensure_db()
      if o.favoritePlayerOnlineAlerts == false then return end
      if not u or not u.name then return end
      local name = tostring(u.name or "")
      if name == "" or sfn138_key(name) == sfn138_key(sfn138_player()) then return end
      if not sfn138_is_favorite(name) then return end

      local n = sfn138_ensure_db()
      local key = sfn138_key(name)
      local stamp = sfn138_now()
      local lastSeen = tonumber(n.favoriteOnlineSeen[key] or 0) or 0
      n.favoriteOnlineSeen[key] = stamp

      -- Avoid reload/login bursts.  The first snapshot after loading only seeds seen-state.
      BLFG.sfn138LoadTime = BLFG.sfn138LoadTime or stamp
      if (stamp - BLFG.sfn138LoadTime) < 20 then return end

      -- Only treat it as a new online event if we have not seen them recently.
      if lastSeen > 0 and (stamp - lastSeen) < 300 then return end

      local zone = sfn138_clean(u.zone or "", 34)
      local body = zone ~= "" and ("Seen in " .. zone .. ".") or "Seen online."
      sfn138_emit("Favorite online: " .. sfn138_short(name, 20), body, "Interface\\Icons\\INV_Misc_GroupLooking", "online:" .. key, 600)
    end

    local function sfn138_alert_listing(author, listingId, activity, listingType, message)
      local _, o = sfn138_ensure_db()
      if o.favoritePlayerListingAlerts == false then return end
      author = tostring(author or "")
      if author == "" or sfn138_key(author) == sfn138_key(sfn138_player()) then return end
      if not sfn138_is_favorite(author) then return end

      listingType = tostring(listingType or "")
      if listingType == "Guild" then return end

      local n = sfn138_ensure_db()
      local safeId = tostring(listingId or "")
      if safeId == "" then safeId = sfn138_key(author) .. ":" .. sfn138_low(tostring(activity or "")) .. ":" .. sfn138_low(tostring(message or "")) end
      if n.favoriteAlertSeenListings[safeId] then return end
      n.favoriteAlertSeenListings[safeId] = sfn138_now()

      local a = sfn138_clean(activity or listingType or "group", 36)
      if a == "" then a = "group" end
      local body = sfn138_clean(message or "", 86)
      if body == "" then body = "New listing detected." end
      sfn138_emit("Favorite listing: " .. sfn138_short(author, 20) .. " - " .. a, body, "Interface\\Icons\\INV_Misc_GroupNeedMore", "listing:" .. safeId, 0)
    end

    local function sfn138_scan_online_rows(self)
      local _, o = sfn138_ensure_db()
      if o.favoritePlayerOnlineAlerts == false then return end
      if not self or not self.GetOnlineUserRows then return end
      local rows = self:GetOnlineUserRows() or {}
      for _, u in ipairs(rows) do
        if u and u.name then sfn138_alert_online(u, "scan") end
      end
    end

    -- Hooks ----------------------------------------------------------------------
    local SFN138_OldHandlePresence = BLFG.HandlePresence
    function BLFG:HandlePresence(p, ...)
      local name, zone, role, classFile = nil, nil, nil, nil
      if type(p) == "table" then
        name = p[3]; classFile = p[6]; role = p[7]
        if tonumber(p[10]) then zone = p[8] else zone = "" end
      end
      local r = SFN138_OldHandlePresence and SFN138_OldHandlePresence(self, p, ...)
      if name then sfn138_alert_online({name=name, zone=zone or "", role=role or "", classFile=classFile or ""}, "presence") end
      return r
    end

    local SFN138_OldAddPublicGroup = BLFG.AddPublicGroup
    function BLFG:AddPublicGroup(author, text, channelName, ...)
      local r = SFN138_OldAddPublicGroup and SFN138_OldAddPublicGroup(self, author, text, channelName, ...)
      local g = r or self._lastPublicGroupTouched
      if g and tostring(g.player or author or "") ~= "" then
        sfn138_alert_listing(g.player or author, g.id or self._lastPublicGroupTouchedKey, g.activity or g.type, g.type, g.message or text)
      end
      return r
    end

    local SFN138_OldHandleMessage = BLFG.HandleMessage
    function BLFG:HandleMessage(text, ...)
      local p = nil
      local s = tostring(text or "")
      if string.sub(s, 1, 8) == "BLFG312~" and string.find(s, "~LIST~", 1, true) then p = sfn138_split(s) end
      local r = SFN138_OldHandleMessage and SFN138_OldHandleMessage(self, text, ...)
      if p and p[2] == "LIST" then
        sfn138_alert_listing(p[4], p[3], p[8], p[7], p[19])
      end
      return r
    end

    local SFN138_OldRefreshSFNetwork = BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      local r = SFN138_OldRefreshSFNetwork and SFN138_OldRefreshSFNetwork(self, ...)
      if self.sfn138Refreshing then return r end
      self.sfn138Refreshing = true
      sfn138_scan_online_rows(self)
      if self.SFN138_UpdateBeaconActivity then self:SFN138_UpdateBeaconActivity() end
      self.sfn138Refreshing = nil
      return r
    end

    local SFN138_OldToggleFavorite = BLFG.ToggleFavorite
    function BLFG:ToggleFavorite(name, ...)
      local before = self.IsFavorite and self:IsFavorite(name)
      local r = SFN138_OldToggleFavorite and SFN138_OldToggleFavorite(self, name, ...)
      local after = self.IsFavorite and self:IsFavorite(name)
      if before ~= after then
        local title = after and ("Favorite added: " .. sfn138_short(name, 22)) or ("Favorite removed: " .. sfn138_short(name, 22))
        sfn138_activity(title, after and "Favorite alerts will watch this player." or "Favorite alerts stopped watching this player.", "Interface\\Icons\\INV_Misc_GroupLooking")
        if self.RefreshSFNetwork then self:RefreshSFNetwork() end
        if self.SFRP_RefreshOnlinePanel then self:SFRP_RefreshOnlinePanel() end
      end
      return r
    end

    -- Beacon/Network activity display -------------------------------------------
    function BLFG:SFN138_UpdateBeaconActivity()
      local _, o = sfn138_ensure_db()
      if o.favoriteActivityFeed == false then return end
      local f = self.sfamBeaconPanel
      if not f or not f.detail then return end
      if self.selectedSFNUser and self.selectedSFNUser ~= "" then return end
      local n = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
      local feed = n and n.favoriteActivity or nil
      local a = feed and feed[1] or nil
      if a then
        local age = math.max(0, sfn138_now() - (tonumber(a.created) or sfn138_now()))
        local ageText = age < 60 and (tostring(age) .. "s ago") or (age < 3600 and (tostring(math.floor(age/60)) .. "m ago") or (tostring(math.floor(age/3600)) .. "h ago"))
        f.detail:SetText("|cffffcc00Latest favorite activity:|r " .. sfn138_short(a.title or "", 32) .. "\n|cff999999" .. ageText .. "|r")
      end
    end

    local SFN138_OldSFAMUpdateBeacon = BLFG.SFAM_UpdateBeaconPanel
    if SFN138_OldSFAMUpdateBeacon then
      function BLFG:SFAM_UpdateBeaconPanel(...)
        local r = SFN138_OldSFAMUpdateBeacon(self, ...)
        if self.SFN138_UpdateBeaconActivity then self:SFN138_UpdateBeaconActivity() end
        return r
      end
    end

    -- Options sub-page -----------------------------------------------------------
    local function sfn138_backdrop(frame, alpha)
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

    local function sfn138_flat(frame, alpha)
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

    local function sfn138_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end

    local function sfn138_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 120); b:SetHeight(h or 24); b:SetText(text or "Button")
      return b
    end

    local function sfn138_register_escape(frame, name)
      if name then _G[name] = frame end
      if name and UISpecialFrames then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == name then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, name) end
      end
      if frame.EnableKeyboard then frame:EnableKeyboard(true) end
      frame:SetScript("OnKeyDown", function(self, key) if key == "ESCAPE" then self:Hide() end end)
    end

    function BLFG:SFN138_AddFavoriteAlertOptions()
      if not self.optionsPanel or self.sfn138FavoriteAlertButton then return end
      sfn138_ensure_db()
      local p = self.optionsPanel
      local open = sfn138_button(p, "Favorite Alerts", 130, 26)
      self.sfn138FavoriteAlertButton = open
      open:SetPoint("TOPRIGHT", p, "TOPRIGHT", -276, -4)

      local function buildPanel()
        if self.sfn138FavoriteOptionsPanel then return self.sfn138FavoriteOptionsPanel end
        local name = "SignalFireFavoriteAlertsPanel"
        local f = CreateFrame("Frame", name, p)
        self.sfn138FavoriteOptionsPanel = f
        f:SetAllPoints(p)
        f:SetFrameLevel(((p.GetFrameLevel and p:GetFrameLevel()) or 1) + 130)
        f:SetToplevel(true); f:EnableMouse(true)
        sfn138_backdrop(f, .985)
        sfn138_register_escape(f, name)
        f:Hide()

        local title = sfn138_font(f, "Favorite Alerts", 18, 1, .75, 0)
        title:SetPoint("TOP", f, "TOP", 0, -28)
        local note = sfn138_font(f, "Favorite players can now trigger useful, throttled alerts without turning SignalFire into spam city.", 10, .82, .9, 1)
        note:SetPoint("TOP", title, "BOTTOM", 0, -12)
        note:SetWidth(650); note:SetJustifyH("CENTER")

        local panel = CreateFrame("Frame", nil, f)
        panel:SetWidth(650); panel:SetHeight(285)
        panel:SetPoint("TOP", f, "TOP", 0, -88)
        panel:SetFrameLevel(f:GetFrameLevel() + 5)
        sfn138_flat(panel, .82); panel:EnableMouse(true)

        local function check(key, label, body, y)
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, y)
          cb:SetFrameLevel(panel:GetFrameLevel() + 10)
          cb.text = sfn138_font(panel, label, 11, 1, 1, 1)
          cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
          cb.body = sfn138_font(panel, body or "", 9, .75, .75, .75)
          cb.body:SetPoint("TOPLEFT", cb.text, "BOTTOMLEFT", 0, -2)
          cb.body:SetWidth(560); cb.body:SetJustifyH("LEFT")
          cb:SetScript("OnClick", function(self)
            BronzeLFG_DB.options = BronzeLFG_DB.options or {}
            BronzeLFG_DB.options[key] = self:GetChecked() and true or false
            if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
            if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          end)
          f[key] = cb
          return cb
        end

        check("favoritePlayerOnlineAlerts", "Favorite player online alerts", "Shows a small alert when a favorite player appears online after being away. Throttled to avoid spam.", -24)
        check("favoritePlayerListingAlerts", "Favorite player group/listing alerts", "BIG one: alerts when a favorite player posts or creates a group listing. Guild recruitment alerts stay off.", -78)
        check("favoriteActivityFeed", "Favorite Activity feed", "Stores recent favorite-player online/listing events and surfaces the latest item in the Network Beacon.", -132)
        check("favoriteAlertToasts", "Favorite alert toasts", "Uses the existing subtle SignalFire toast when available. Chat/UIErrors notice still appears.", -186)
        check("favoriteAlertSound", "Favorite alert sound", "Optional sound for favorite alerts. Off by default so it does not get annoying.", -240)

        local back = sfn138_button(f, "Back to Options", 140, 28)
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
        sfn138_ensure_db()
        local o = BronzeLFG_DB.options or {}
        if f.favoritePlayerOnlineAlerts then f.favoritePlayerOnlineAlerts:SetChecked(o.favoritePlayerOnlineAlerts ~= false) end
        if f.favoritePlayerListingAlerts then f.favoritePlayerListingAlerts:SetChecked(o.favoritePlayerListingAlerts ~= false) end
        if f.favoriteActivityFeed then f.favoriteActivityFeed:SetChecked(o.favoriteActivityFeed ~= false) end
        if f.favoriteAlertToasts then f.favoriteAlertToasts:SetChecked(o.favoriteAlertToasts ~= false) end
        if f.favoriteAlertSound then f.favoriteAlertSound:SetChecked(o.favoriteAlertSound == true) end
        return f
      end

      open:SetScript("OnClick", function()
        local f = refreshPanel()
        f:Show(); if f.Raise then f:Raise() end
      end)
    end

    local SFN138_OldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = SFN138_OldBuildOptions and SFN138_OldBuildOptions(self, ...)
      self:SFN138_AddFavoriteAlertOptions()
      return r
    end

    local SFN138_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFN138_OldShowOptions and SFN138_OldShowOptions(self, ...)
      self:SFN138_AddFavoriteAlertOptions()
      return r
    end

    -- Slash helper.  This is intentionally small; the main controls live in Options.
    local function sfn138_handle_favalerts_slash(input, old)
      local raw = tostring(input or "")
      local cmd = sfn138_low(sfn138_trim(raw))
      if cmd == "favalerts" or cmd == "favoritealerts" then
        if BLFG.ShowOptions then BLFG:ShowOptions() end
        if BLFG.SFN138_AddFavoriteAlertOptions then BLFG:SFN138_AddFavoriteAlertOptions() end
        if BLFG.sfn138FavoriteAlertButton then BLFG.sfn138FavoriteAlertButton:Click() end
        return true
      end
      if old then return old(input) end
    end

    local SFN138_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
    local SFN138_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
    if SlashCmdList then
      SlashCmdList["BRONZELFG"] = function(input) return sfn138_handle_favalerts_slash(input, SFN138_OldSlashBLFG) end
      SlashCmdList["SIGNALFIRE"] = function(input) return sfn138_handle_favalerts_slash(input, SFN138_OldSlashSF) end
    end

    -- Seed once loaded.
    BLFG.sfn138LoadTime = sfn138_now()
    sfn138_ensure_db()
  until true
end

