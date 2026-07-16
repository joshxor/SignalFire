-- SignalFire 1.5.0
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Network services
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFN_PREFIX = "BLFG312"
    local SFN_CHANNEL = "BLFG"
    local SFN_VERSION = _G.SignalFire_VERSION or "1.4.23"

    local function sfn_now()
      return (time and time()) or 0
    end

    local function sfn_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfn_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfn_clean(s, maxLen)
      s = sfn_trim(s)
      s = string.gsub(s, "[~|\r\n]", " ")
      s = string.gsub(s, "%s+", " ")
      maxLen = tonumber(maxLen) or 0
      if maxLen > 0 and string.len(s) > maxLen then s = string.sub(s, 1, maxLen) end
      return s
    end

    local function sfn_low(s)
      return string.lower(tostring(s or ""))
    end

    local function sfn_name_key(name)
      name = sfn_low(sfn_trim(name or ""))
      name = string.gsub(name, "%-.+$", "")
      return name
    end

    local SFN_AUTO_REFRESH_VALUES = {0, 15, 30, 60}

    local function sfn_auto_refresh_seconds()
      local n = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
      local v = tonumber(n and n.autoRefreshSeconds or 30) or 30
      if v ~= 0 and v ~= 15 and v ~= 30 and v ~= 60 then v = 30 end
      return v
    end

    local function sfn_auto_refresh_label()
      local v = sfn_auto_refresh_seconds()
      if v <= 0 then return "Auto: Off" end
      return "Auto: " .. tostring(v) .. "s"
    end

    local function sfn_cycle_auto_refresh()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local current = sfn_auto_refresh_seconds()
      local nextValue = 0
      for i, v in ipairs(SFN_AUTO_REFRESH_VALUES) do
        if v == current then
          nextValue = SFN_AUTO_REFRESH_VALUES[(i % #SFN_AUTO_REFRESH_VALUES) + 1]
          break
        end
      end
      BronzeLFG_DB.signalFireNetwork.autoRefreshSeconds = nextValue
      return nextValue
    end

    local function sfn_split(s)
      local t = {}
      s = tostring(s or "")
      local start = 1
      while true do
        local pos = string.find(s, "~", start, true)
        if not pos then
          table.insert(t, string.sub(s, start))
          break
        end
        table.insert(t, string.sub(s, start, pos - 1))
        start = pos + 1
      end
      return t
    end

    local function sfn_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0)
      end
    end

    local function sfn_send(payload)
      payload = tostring(payload or "")
      if payload == "" then return false end
      local id = GetChannelName and GetChannelName(SFN_CHANNEL) or nil
      if id and id ~= 0 and SendChatMessage then
        SendChatMessage(payload, "CHANNEL", nil, id)
        return true
      end
      if JoinChannelByName then JoinChannelByName(SFN_CHANNEL) end
      return false
    end

    local function sfn_backdrop(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .86)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end

    local function sfn_flat(frame, alpha)
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

    local function sfn_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end

    local function sfn_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 100); b:SetHeight(h or 24)
      b:SetText(tostring(text or "Button"))
      return b
    end

    local function sfn_edit(parent, w, h, multi)
      local e = CreateFrame("EditBox", nil, parent)
      e:SetWidth(w or 160); e:SetHeight(h or 24)
      e:EnableMouse(true)
      e:SetAutoFocus(false)
      e:SetFontObject(GameFontHighlightSmall)
      e:SetTextInsets(6, 6, 3, 3)
      e:SetMaxLetters(multi and 240 or 96)
      e:SetMultiLine(multi and true or false)
      sfn_backdrop(e, .62)
      e:SetScript("OnMouseDown", function(self) self:SetFocus() end)
      e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
      if not multi then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
      return e
    end

    local function sfn_check(parent, label)
      local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
      cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
      cb.text:SetText(label or "")
      return cb
    end

    local function sfn_add_special_frame(name)
      if not name or not UISpecialFrames then return end
      for _, v in ipairs(UISpecialFrames) do
        if v == name then return end
      end
      table.insert(UISpecialFrames, name)
    end

    local function sfn_close_notice_creator(frame)
      if CloseDropDownMenus then CloseDropDownMenus() end
      if frame then
        if frame.titleBox and frame.titleBox.ClearFocus then frame.titleBox:ClearFocus() end
        if frame.updateBox and frame.updateBox.ClearFocus then frame.updateBox:ClearFocus() end
        if frame.bodyBox and frame.bodyBox.ClearFocus then frame.bodyBox:ClearFocus() end
        frame:Hide()
      end
    end

    local function sfn_make_dialog_closable(frame, globalName)
      if not frame then return end
      if globalName then
        _G[globalName] = frame
        sfn_add_special_frame(globalName)
      end
      if frame.EnableKeyboard then frame:EnableKeyboard(true) end
      frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then sfn_close_notice_creator(self) end
      end)
      frame:HookScript("OnHide", function(self)
        if CloseDropDownMenus then CloseDropDownMenus() end
        if self.titleBox and self.titleBox.ClearFocus then self.titleBox:ClearFocus() end
        if self.updateBox and self.updateBox.ClearFocus then self.updateBox:ClearFocus() end
        if self.bodyBox and self.bodyBox.ClearFocus then self.bodyBox:ClearFocus() end
      end)
    end

    local function sfn_raise_control(control, parent, offset)
      if control and control.SetFrameLevel and parent and parent.GetFrameLevel then
        control:SetFrameLevel(parent:GetFrameLevel() + (offset or 40))
      end
      if control and control.EnableMouse then control:EnableMouse(true) end
    end


    -- Saved data + Network wire helpers.  These must be defined before any UI builder
    -- calls sfn_ensure_db(); otherwise the Network tab stops after the Status label.
    local function sfn_ensure_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.network = BronzeLFG_DB.network or {}
      BronzeLFG_DB.signalFireNetwork = BronzeLFG_DB.signalFireNetwork or {}
      local n = BronzeLFG_DB.signalFireNetwork
      local public = BronzeLFG_DB.network

      n.status = n.status or {}
      if public.status ~= nil and public.status ~= "" and (n.status.looking == nil or n.status.looking == "") then
        n.status.looking = tostring(public.status)
      end
      if public.shareStatus ~= nil and n.status.share == nil then
        n.status.share = public.shareStatus and true or false
      end
      if n.status.looking == nil or n.status.looking == "" then n.status.looking = "Online" end
      if n.status.share == nil then n.status.share = true end
      n.status.tank = n.status.tank and true or false
      n.status.healer = n.status.healer and true or false
      n.status.dps = n.status.dps and true or false
      n.autoRefreshSeconds = tonumber(n.autoRefreshSeconds or 30) or 30
      if n.autoRefreshSeconds ~= 0 and n.autoRefreshSeconds ~= 15 and n.autoRefreshSeconds ~= 30 and n.autoRefreshSeconds ~= 60 then
        n.autoRefreshSeconds = 30
      end
      public.status = n.status.looking
      public.shareStatus = n.status.share and true or false

      n.notices = n.notices or {}
      n.noticeSeen = n.noticeSeen or {}
      n.noticeDismissed = n.noticeDismissed or {}
      n.noticeMasterCleared = n.noticeMasterCleared or {}
      n.noticeMasterClearAllAt = tonumber(n.noticeMasterClearAllAt or 0) or 0
      n.trustedNoticeSenders = n.trustedNoticeSenders or public.trustedNoticeSenders or {}
      public.trustedNoticeSenders = n.trustedNoticeSenders
      n.trustedNoticeSenders[sfn_name_key(sfn_player())] = true
      n.trustedNoticeSenders[sfn_name_key("Hsoj")] = true
      n.trustedNoticeSenders[sfn_name_key("Hs0j")] = true
      n.trustedNoticeSenders[sfn_name_key("Aesri")] = true
      if public.acceptTrustedNoticesOnly == nil and n.acceptTrustedNoticesOnly == nil then
        n.acceptTrustedNoticesOnly = true
      elseif public.acceptTrustedNoticesOnly ~= nil then
        n.acceptTrustedNoticesOnly = public.acceptTrustedNoticesOnly and true or false
      end
      public.acceptTrustedNoticesOnly = n.acceptTrustedNoticesOnly ~= false
      n.favoriteActivity = n.favoriteActivity or {}
      n.recruitmentTemplates = n.recruitmentTemplates or {}
      return n
    end


    local sfn_is_master_notice_admin_name

    local function sfn_prune_legacy_welcome_notice(n)
      n = n or sfn_ensure_db()
      local changed = false
      local kept = {}
      for _, row in ipairs(n.notices or {}) do
        local id = tostring(row.id or "")
        local title = tostring(row.title or "")
        local body = tostring(row.body or "")
        local sender = tostring(row.sender or "")
        local isLegacyWelcome =
          id == "welcome-135" or
          string.find(title, "SignalFire Network Notice Board enabled", 1, true) or
          string.find(body, "Network notices, status, recruitment channel targeting", 1, true)

        -- 1.4.1i: notice permissions are now Hsoj-only. Remove any old stored
        -- network notice from non-admin senders that existed before the hardening.
        -- This clears "ghost" rows like old Fate urgent test notices.
        local isUnauthorizedNetworkNotice =
          (row.localOnly ~= true) and sender ~= "" and not (sfn_is_master_notice_admin_name and sfn_is_master_notice_admin_name(sender))

        -- Extra safety: non-admin urgent rows should never survive as popup-capable notices.
        local isUnauthorizedUrgent =
          tostring(row.priority or "") == "Urgent" and not (sfn_is_master_notice_admin_name and sfn_is_master_notice_admin_name(sender))

        if isLegacyWelcome or isUnauthorizedNetworkNotice or isUnauthorizedUrgent then
          changed = true
          if id ~= "" then
            n.noticeSeen[id] = true
            n.noticeDismissed[id] = true
            n.noticeMasterCleared[id] = true
          end
        else
          table.insert(kept, row)
        end
      end
      if changed then n.notices = kept end
      return changed
    end

    local function sfn_notice_priority(p)
      p = sfn_clean(p or "Normal", 16)
      local low = sfn_low(p)
      if low == "urgent" then return "Urgent" end
      if low == "important" then return "Important" end
      return "Normal"
    end

    local function sfn_is_trusted_notice_sender(sender)
      local n = sfn_ensure_db()
      local key = sfn_name_key(sender)
      return key ~= "" and n.trustedNoticeSenders and n.trustedNoticeSenders[key] and true or false
    end

    local sfn_is_update_notice

    function sfn_is_master_notice_admin_name(name)
      local key = sfn_name_key(name or "")
      return key == "hsoj" or key == "hs0j" or key == "aesri"
    end

    local function sfn_is_master_notice_admin()
      return sfn_is_master_notice_admin_name(sfn_player())
    end

    local function sfn_update_create_notice_button(btn)
      if not btn then return end
      if sfn_is_master_notice_admin() then
        btn:SetText("Create Notice")
        if btn.Enable then btn:Enable() end
      else
        btn:SetText("Admin Only")
        -- Leave the button visually disabled so regular users understand this is an
        -- admin/update channel, not a public notice broadcaster.
        if btn.Disable then btn:Disable() end
      end
    end

    local function sfn_short_display(text, maxLen)
      text = tostring(text or "")
      text = string.gsub(text, "[\r\n]", " ")
      text = string.gsub(text, "%s+", " ")
      maxLen = tonumber(maxLen) or 0
      if maxLen > 0 and string.len(text) > maxLen then
        return string.sub(text, 1, math.max(1, maxLen - 3)) .. "..."
      end
      return text
    end

    local function sfn_notice_row_title(row, read)
      row = row or {}
      local parts = {}
      if read then table.insert(parts, "|cff888888[Read]|r") end
      if sfn_is_update_notice and sfn_is_update_notice(row) then table.insert(parts, "|cff44ccff[Update]|r") end
      if tostring(row.priority or "") == "Urgent" then
        table.insert(parts, "|cffff4444[Urgent]|r")
      elseif tostring(row.priority or "") == "Important" then
        table.insert(parts, "|cffffaa33[Important]|r")
      end
      table.insert(parts, sfn_short_display(row.title or "SignalFire Notice", 34))
      return table.concat(parts, " ")
    end

    local function sfn_remove_notice_local(id)
      local n = sfn_ensure_db()
      id = sfn_clean(id or "", 64)
      n.noticeMasterCleared = n.noticeMasterCleared or {}
      if id == "" or sfn_low(id) == "all" then
        n.notices = {}
        n.noticeSeen = {}
        n.noticeDismissed = {}
        n.noticeMasterCleared = {}
        n.noticeSeen["welcome-135"] = true
        n.noticeDismissed["welcome-135"] = true
        n.noticeMasterCleared["welcome-135"] = true
        n.noticeMasterClearAllAt = sfn_now()
        return true, "ALL"
      end
      n.noticeSeen[id] = true
      n.noticeDismissed[id] = true
      n.noticeMasterCleared[id] = true
      local kept = {}
      for _, row in ipairs(n.notices or {}) do
        if tostring(row.id or "") ~= id then table.insert(kept, row) end
      end
      n.notices = kept
      return true, id
    end

    local function sfn_master_clear_notice(id)
      if not sfn_is_master_notice_admin() then
        sfn_msg("Only a SignalFire admin alias can master-clear SignalFire notices.", 1, .35, .35)
        return false
      end
      id = sfn_clean(id or "ALL", 64)
      if id == "" then id = "ALL" end
      sfn_remove_notice_local(id)
      sfn_send(table.concat({SFN_PREFIX, "NOTICECLEAR", sfn_player(), tostring(sfn_now()), id}, "~"))
      if sfn_low(id) == "all" then
        sfn_msg("Master cleared all SignalFire notices.", .4, 1, .4)
      else
        sfn_msg("Master cleared SignalFire notice.", .4, 1, .4)
      end
      if BLFG and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      return true
    end


    function BLFG:SFN_IsNoticeAdmin()
      return sfn_is_master_notice_admin() and true or false
    end

    function BLFG:SFN_MasterClearNotice(id)
      return sfn_master_clear_notice(id or (self and self.sfnSelectedNoticeId) or "")
    end

    function BLFG:SFN_MasterClearAllNotices()
      return sfn_master_clear_notice("ALL")
    end

    local function sfn_notice_expiration_seconds(label)
      local low = sfn_low(label)
      if low == "never" then return 0 end
      if low == "1 hour" or low == "hour" then return 3600 end
      if low == "7 days" or low == "7 day" then return 604800 end
      return 86400
    end

    local function sfn_notice_expiration_label(expires, created)
      expires = tonumber(expires or 0) or 0
      created = tonumber(created or 0) or 0
      if expires == 0 then return "Never" end
      local delta = expires - created
      if delta <= 4000 then return "1 hour" end
      if delta >= 600000 then return "7 days" end
      return "1 day"
    end

    local function sfn_version_parts(v)
      v = tostring(v or "")
      local nums = {}
      for n in string.gmatch(v, "(%d+)") do table.insert(nums, tonumber(n) or 0) end
      local suffix = string.lower(string.gsub(v, "[%d%.%-_%s]", ""))
      return nums, suffix
    end

    local function sfn_version_newer(remote, current)
      local rn, rs = sfn_version_parts(remote)
      local cn, cs = sfn_version_parts(current)
      local max = math.max(#rn, #cn, 4)
      for i = 1, max do
        local a = rn[i] or 0
        local b = cn[i] or 0
        if a > b then return true end
        if a < b then return false end
      end
      return rs ~= "" and rs > cs
    end

    function sfn_is_update_notice(row)
      return row and row.updateVersion and row.updateVersion ~= "" and sfn_version_newer(row.updateVersion, SFN_VERSION)
    end

    local function sfn_notice_summary(row)
      if not row then return "" end
      if sfn_is_update_notice(row) then
        return "SignalFire Update Available\nCurrent stable version: " .. tostring(row.updateVersion or "") .. "\nYour installed version: " .. tostring(SFN_VERSION)
      end
      return tostring(row.title or "SignalFire Notice") .. "\n" .. tostring(row.body or "")
    end

    local function sfn_notice_body_for_display(row)
      row = row or {}
      local bodyText = tostring(row.body or "")
      if sfn_is_update_notice(row) then
        bodyText = "Stable " .. tostring(row.updateVersion or "") .. " available. " .. bodyText
      end
      return bodyText
    end

    local function sfn_notice_tooltip(row, read)
      if not row or not GameTooltip then return end
      GameTooltip:ClearLines()
      GameTooltip:SetText("SignalFire Notice", 1, .82, 0)
      local title = tostring(row.title or "SignalFire Notice")
      local priority = sfn_notice_priority(row.priority or "Normal")
      local sender = tostring(row.sender or "SignalFire")
      GameTooltip:AddLine(title, 1, 1, 1, true)
      GameTooltip:AddLine("From: " .. sender .. "  |  Priority: " .. priority .. "  |  Expires: " .. sfn_notice_expiration_label(row.expires, row.created), .8, .8, .8, true)
      local bodyText = sfn_notice_body_for_display(row)
      if bodyText ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(bodyText, .9, .9, .9, true)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(read and "Left-click: open details" or "Left-click: open details and mark read", .45, .85, 1, true)
      if sfn_is_master_notice_admin() then
        GameTooltip:AddLine("Right-click: admin-clear this notice", 1, .55, .25, true)
      end
    end


    local sfn_show_notice_popup

    local function sfn_notice_popups_enabled()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      if BronzeLFG_DB.options.noticePopups == nil then BronzeLFG_DB.options.noticePopups = true end
      return BronzeLFG_DB.options.noticePopups ~= false
    end

    local function sfn_notice_chat_push(row)
      if not row then return end
      local title = sfn_clean(row.title or "SignalFire Notice", 70)
      local body = sfn_clean(sfn_is_update_notice(row) and sfn_notice_summary(row) or sfn_notice_body_for_display(row), 120)
      local pri = sfn_notice_priority(row.priority or "Normal")
      local sender = sfn_clean(row.sender or "SignalFire", 40)
      if body ~= "" then
        sfn_msg("Notice [" .. pri .. "] " .. title .. " - " .. body .. " (from " .. sender .. ")", 1, .82, .35)
      else
        sfn_msg("Notice [" .. pri .. "] " .. title .. " (from " .. sender .. ")", 1, .82, .35)
      end
    end

    local function sfn_notice_alert(row, forcePopup)
      if not row then return end
      if forcePopup or sfn_notice_popups_enabled() then
        sfn_show_notice_popup(row)
      else
        sfn_notice_chat_push(row)
      end
    end

    function sfn_show_notice_popup(row)
      if not row then return end
      local body = sfn_is_update_notice(row) and sfn_notice_summary(row) or sfn_notice_body_for_display(row)
      if body == "" then body = tostring(row.title or "SignalFire Notice") end
      if not BLFG.sfnNoticePopup then
        local f = CreateFrame("Frame", "SignalFireNoticeDetailsFrame", UIParent)
        BLFG.sfnNoticePopup = f
        f:SetWidth(460); f:SetHeight(240); f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetToplevel(true); f:EnableMouse(true)
        sfn_backdrop(f, .96)
        f.title = sfn_font(f, "SignalFire Notice", 14, 1, .75, 0); f.title:SetPoint("TOP", f, "TOP", 0, -14); f.title:SetWidth(390); f.title:SetJustifyH("CENTER")
        f.meta = sfn_font(f, "", 9, .75, .75, .75); f.meta:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -40); f.meta:SetWidth(420); f.meta:SetJustifyH("LEFT")
        f.body = sfn_font(f, "", 10, .9, .9, .9); f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -62); f.body:SetWidth(420); f.body:SetHeight(120); f.body:SetJustifyH("LEFT"); f.body:SetJustifyV("TOP")
        if f.body.SetNonSpaceWrap then f.body:SetNonSpaceWrap(true) end
        if f.body.SetWordWrap then f.body:SetWordWrap(true) end
        local x = CreateFrame("Button", nil, f, "UIPanelCloseButton"); x:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4); x:SetScript("OnClick", function() f:Hide() end)
        local close = sfn_button(f, "OK", 80, 24); close:SetPoint("BOTTOM", f, "BOTTOM", 0, 14); close:SetScript("OnClick", function() f:Hide() end)
        f:Hide()
      end
      BLFG.sfnNoticePopup.title:SetText(sfn_is_update_notice(row) and "SignalFire Update Available" or tostring(row.title or "SignalFire Notice"))
      if BLFG.sfnNoticePopup.meta then
        BLFG.sfnNoticePopup.meta:SetText("From: " .. tostring(row.sender or "SignalFire") .. "  |  Priority: " .. sfn_notice_priority(row.priority or "Normal") .. "  |  Expires: " .. sfn_notice_expiration_label(row.expires, row.created))
      end
      BLFG.sfnNoticePopup.body:SetText(body)
      BLFG.sfnNoticePopup:Show(); BLFG.sfnNoticePopup:Raise()
    end

    local function sfn_status_flags(st)
      st = st or {}
      local flags = {}
      if st.tank then table.insert(flags, "T") end
      if st.healer then table.insert(flags, "H") end
      if st.dps then table.insert(flags, "D") end
      if #flags == 0 then return "-" end
      return table.concat(flags, "")
    end

    local function sfn_store_favorite_activity(title, body, icon)
      local n = sfn_ensure_db()
      n.favoriteActivity = n.favoriteActivity or {}
      table.insert(n.favoriteActivity, 1, {
        title = sfn_clean(title or "", 90),
        body = sfn_clean(body or "", 120),
        icon = icon or "Interface\\Icons\\INV_Misc_Note_01",
        created = sfn_now(),
      })
      while #n.favoriteActivity > 12 do table.remove(n.favoriteActivity) end
    end

    local function sfn_store_notice(id, sender, created, expires, priority, title, body, localOnly, updateVersion)
      local n = sfn_ensure_db()
      id = sfn_clean(id or "", 64)
      if id == "" then id = tostring(sfn_now()) .. "-" .. tostring(math.random(1000, 9999)) end
      sender = sfn_clean(sender or "SignalFire", 40)

      if not localOnly then
        -- Network notices are an admin/update channel. Do not trust client UI:
        -- receivers reject non-Hsoj notice payloads, even if someone edits their addon.
        if not (sfn_is_master_notice_admin_name and sfn_is_master_notice_admin_name(sender)) then
          return nil, "notadmin"
        end

        n.noticeMasterCleared = n.noticeMasterCleared or {}
        local createdNumber = tonumber(created) or sfn_now()
        if n.noticeMasterCleared[id] then return nil, "cleared" end
        if (tonumber(n.noticeMasterClearAllAt or 0) or 0) > 0 and createdNumber <= (tonumber(n.noticeMasterClearAllAt or 0) or 0) then
          return nil, "cleared"
        end
      end

      if not localOnly and n.acceptTrustedNoticesOnly ~= false and not sfn_is_trusted_notice_sender(sender) and not (sfn_is_master_notice_admin_name and sfn_is_master_notice_admin_name(sender)) then
        return nil, "untrusted"
      end

      local row
      for _, existing in ipairs(n.notices or {}) do
        if tostring(existing.id or "") == id then row = existing; break end
      end
      if not row then
        row = { id = id }
        table.insert(n.notices, 1, row)
      end

      row.sender = sender
      row.created = tonumber(created) or sfn_now()
      row.expires = tonumber(expires) or (sfn_now() + 86400)
      row.priority = sfn_notice_priority(priority)
      if row.priority == "Urgent" and not (sfn_is_master_notice_admin_name and sfn_is_master_notice_admin_name(sender)) then
        row.priority = "Important"
      end
      row.title = sfn_clean(title or "SignalFire Notice", 80)
      row.body = sfn_clean(body or "", 180)
      row.updateVersion = sfn_clean(updateVersion or "", 20)
      row.localOnly = localOnly and true or false

      while #n.notices > 40 do table.remove(n.notices) end
      sfn_store_favorite_activity("Notice: " .. row.title, row.body, "Interface\\Icons\\INV_Misc_Note_02")
      return row
    end

    function BLFG:SFN_GetNoticeRows()
      local n = sfn_ensure_db()
      sfn_prune_legacy_welcome_notice(n)
      local out = {}
      local stamp = sfn_now()
      for _, a in ipairs(n.notices or {}) do
        local id = tostring(a.id or "")
        local exp = tonumber(a.expires or 0) or 0
        if id ~= "" and not n.noticeDismissed[id] and (exp == 0 or exp > stamp) then
          table.insert(out, a)
        end
      end
      table.sort(out, function(a, b)
        return (tonumber(a.created) or 0) > (tonumber(b.created) or 0)
      end)
      return out
    end

    local function sfn_count_unread_notices(rows, n)
      n = n or sfn_ensure_db()
      local count = 0
      for _, a in ipairs(rows or {}) do
        local id = tostring((a and a.id) or "")
        if id ~= "" and not n.noticeSeen[id] and not n.noticeDismissed[id] then
          count = count + 1
        end
      end
      return count
    end

    local function sfn_set_mark_all_read_state(btn, unread)
      if not btn then return end
      unread = tonumber(unread or 0) or 0
      if unread > 0 then
        if btn.Enable then btn:Enable() end
        if btn.SetAlpha then btn:SetAlpha(1) end
        if btn.SetText then btn:SetText("Mark All Read") end
      else
        if btn.SetText then btn:SetText("All Read") end
        if btn.Disable then btn:Disable() end
        if btn.SetAlpha then btn:SetAlpha(.65) end
      end
    end

    function BLFG:SFN_SendNotice(title, body, priority, expiresValue, updateVersion)
      local nowStamp = sfn_now()
      if not sfn_is_master_notice_admin() then
        sfn_msg("Only a SignalFire admin alias can create SignalFire network notices.", 1, .35, .35)
        return false
      end
      title = sfn_clean(title or "", 80)
      body = sfn_clean(body or "", 180)
      if title == "" then
        sfn_msg("Notice title cannot be empty.", 1, .35, .35)
        return false
      end
      priority = sfn_notice_priority(priority)
      local expires
      if type(expiresValue) == "string" then
        local seconds = sfn_notice_expiration_seconds(expiresValue)
        expires = seconds == 0 and 0 or (nowStamp + seconds)
      else
        expires = nowStamp + ((tonumber(expiresValue) or 24) * 3600)
      end
      updateVersion = sfn_clean(updateVersion or "", 20)
      local id = sfn_clean(sfn_player() .. "-" .. tostring(nowStamp) .. "-" .. tostring(math.random(1000, 9999)), 64)
      sfn_store_notice(id, sfn_player(), nowStamp, expires, priority, title, body, false, updateVersion)
      sfn_send(table.concat({SFN_PREFIX, "NOTICE", id, sfn_player(), tostring(nowStamp), tostring(expires), priority, title, body, updateVersion}, "~"))
      if self.RefreshSFNetwork then self:RefreshSFNetwork() end
      sfn_msg("SignalFire notice sent.", .4, 1, .4)
      return true
    end

    function BLFG:SFN_SendStatus()
      local n = sfn_ensure_db()
      local st = n.status or {}
      if st.share == false then return false end

      local unitClassName, unitClassFile = "", ""
      if UnitClass then unitClassName, unitClassFile = UnitClass("player") end
      local guidClassName, guidClassFile = "", ""
      if UnitGUID and GetPlayerInfoByGUID then
        local guid = UnitGUID("player")
        if guid then guidClassName, guidClassFile = GetPlayerInfoByGUID(guid) end
      end

      local uiClassName = ""
      if CharacterClassText and CharacterClassText.GetText then
        uiClassName = CharacterClassText:GetText() or ""
      end

      local classFile = (unitClassFile and unitClassFile ~= "") and unitClassFile or guidClassFile
      local className = (unitClassName and unitClassName ~= "") and unitClassName or ""
      if (className == "" or className == classFile or string.find(className, "^[A-Z_]+$") ~= nil) and uiClassName ~= "" then
        className = uiClassName
      end
      if (className == "" or className == classFile or string.find(className, "^[A-Z_]+$") ~= nil) and classFile and classFile ~= "" then
        local upper = string.upper(tostring(classFile))
        local localized = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[upper])
          or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[upper])
        if localized and localized ~= "" then className = localized end
      end
      if (className == "" or className == classFile or string.find(className, "^[A-Z_]+$") ~= nil) and guidClassName and guidClassName ~= "" and string.find(guidClassName, "^[A-Z_]+$") == nil then
        className = guidClassName
      end
      if not className or className == "" then className = classFile or "" end
      if not classFile or classFile == "" then classFile = guidClassFile or className or "" end

      local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
      local name = sfn_player()
      local looking = sfn_clean(st.looking or "Online", 32)
      local flags = sfn_status_flags(st)
      local stamp = sfn_now()

      self.sfnStatuses = self.sfnStatuses or {}
      self.sfnStatuses[name] = {
        name = name,
        className = className or classFile or "",
        classFile = classFile or className or "",
        looking = looking,
        flags = flags,
        zone = zone,
        seen = stamp,
      }

      return sfn_send(table.concat({SFN_PREFIX, "SFNSTATUS", name, classFile or className or "", looking, flags, zone, tostring(stamp), className or classFile or ""}, "~"))
    end

    local function sfn_handle_channel_payload(msg, author)
      msg = tostring(msg or "")
      if string.sub(msg, 1, string.len(SFN_PREFIX) + 1) ~= (SFN_PREFIX .. "~") then return false end
      local p = sfn_split(msg)
      if p[1] ~= SFN_PREFIX then return false end

      if p[2] == "SFNSTATUS" then
        local name = sfn_clean(p[3] or author or "", 40)
        if name == "" then return true end
        local classFile = sfn_clean(p[4] or "", 24)
        local looking = sfn_clean(p[5] or "Online", 32)
        local flags = sfn_clean(p[6] or "-", 8)
        local zone = sfn_clean(p[7] or "", 40)
        local seen = tonumber(p[8]) or sfn_now()
        local className = sfn_clean(p[9] or "", 32)

        BLFG.sfnStatuses = BLFG.sfnStatuses or {}
        local oldStatus = BLFG.sfnStatuses[name] or {}
        if className == "" or className == "Unknown" then className = tostring(oldStatus.className or "") end
        if classFile == "" or classFile == "UNKNOWN" then classFile = tostring(oldStatus.classFile or "") end
        BLFG.sfnStatuses[name] = {
          name = name,
          className = className,
          classFile = classFile,
          looking = looking ~= "" and looking or oldStatus.looking,
          flags = flags ~= "" and flags or oldStatus.flags,
          zone = zone ~= "" and zone or oldStatus.zone,
          seen = seen,
        }
        BLFG._sfnLastPresenceResponse = sfn_now()
        BLFG._sfnPresenceRefreshPending = nil
        if BLFG.SF151_NotePresencePacket then BLFG:SF151_NotePresencePacket("SFNSTATUS") end
        if BLFG.SF151_RequestPanelRefresh then
          BLFG:SF151_RequestPanelRefresh("network", "presence")
          BLFG:SF151_RequestPanelRefresh("roster", "presence")
        else
          if BLFG.sfnPanel and BLFG.sfnPanel:IsVisible() and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          if BLFG.onlinePanel and BLFG.onlinePanel:IsVisible() and BLFG.RefreshOnlinePanel then BLFG:RefreshOnlinePanel() end
        end
        return true
      end

      if p[2] == "NOTICECLEAR" then
        local clearAuthor = author or ""
        local payloadAuthor = p[3] or ""
        if sfn_is_master_notice_admin_name(clearAuthor) or sfn_is_master_notice_admin_name(payloadAuthor) then
          local target = sfn_clean(p[5] or "ALL", 64)
          if target == "" then target = "ALL" end
          sfn_remove_notice_local(target)
          if BLFG.SF151_RequestPanelRefresh then BLFG:SF151_RequestPanelRefresh("network")
          elseif BLFG.sfnPanel and BLFG.sfnPanel:IsVisible() and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        end
        return true
      end

      if p[2] == "SFNNOTICE" or p[2] == "NOTICE" then
        local row, reason = sfn_store_notice(p[3], p[4] or author, tonumber(p[5]), tonumber(p[6]), p[7], p[8], p[9], false, p[10])
        if row and (sfn_notice_priority(row.priority) == "Urgent" or sfn_is_update_notice(row)) then
          local n = sfn_ensure_db()
          if not n.noticeSeen[row.id] then sfn_notice_alert(row, false) end
        elseif reason == "untrusted" or reason == "notadmin" then
          -- Ignore silently; notices are admin-only and trusted-sender guarded.
        end
        if BLFG.SF151_RequestPanelRefresh then BLFG:SF151_RequestPanelRefresh("network")
        elseif BLFG.sfnPanel and BLFG.sfnPanel:IsVisible() and BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        return true
      end

      return false
    end



    local function sfn_fix_dropdown_layers()
      -- One-shot layering for SignalFire-owned menus only. Blizzard's global
      -- DropDownList frames are also used by portrait and party menus, so never
      -- attach a permanent OnShow hook to them.
      local maxLevels = tonumber(UIDROPDOWNMENU_MAXLEVELS or 2) or 2
      for i = 1, maxLevels do
        local f = _G["DropDownList" .. tostring(i)]
        if f and (not f.IsShown or f:IsShown()) then
          if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
          if f.SetFrameLevel then f:SetFrameLevel(1000 + i) end
        end
      end
    end

    -- Use the same native WoW/SignalFire dropdown style as the rest of the addon.
    -- The previous custom status selector caused ugly arrow rendering and could visually
    -- differ from Options/Create Listing dropdowns. Keep this page consistent instead.
    local SFN_STATUS_VALUES = {"Online", "Looking for Dungeons", "Looking for Guild", "Looking for Raid", "Not Looking"}

    local function sfn_set_status_text(d, value)
      value = tostring(value or "Online")
      if not d then return end
      -- Supports both native UIDropDownMenu frames and the small SignalFire menu-button
      -- used by Network.  The Network version still uses UIDropDownMenu for the menu
      -- list, but keeps its own visible button so the arrow cannot disappear.
      if d.sfnLabel and d.sfnLabel.SetText then d.sfnLabel:SetText(value); return end
      if UIDropDownMenu_SetText then UIDropDownMenu_SetText(d, value) end
    end

    local function sfn_status_dropdown(parent, name, w, values, selected, onchange)
      -- 3.3.5-safe menu pattern based on WoWWiki: the menu frame inherits
      -- UIDropDownMenuTemplate and is toggled from a separate visible button.
      -- This avoids the missing-arrow/half-render issue while still using the real
      -- Blizzard UIDropDownMenu list system.
      values = values or SFN_STATUS_VALUES
      selected = tostring(selected or values[1] or "Online")

      local btn = CreateFrame("Button", name .. "Button", parent)
      btn:SetWidth(w or 220)
      btn:SetHeight(24)
      sfn_flat(btn, .92)
      btn:EnableMouse(true)

      local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      label:SetPoint("LEFT", btn, "LEFT", 8, 0)
      label:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
      label:SetJustifyH("LEFT")
      label:SetText(selected)
      btn.sfnLabel = label
      btn.sfnValue = selected
      btn.values = values

      local arrow = btn:CreateTexture(nil, "ARTWORK")
      arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
      arrow:SetWidth(18)
      arrow:SetHeight(18)
      arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
      btn.sfnArrow = arrow

      btn:SetScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(1, .82, .18, 1) end
      end)
      btn:SetScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(.55, .40, .08, .85) end
      end)

      local menu = CreateFrame("Frame", name .. "Menu", UIParent, "UIDropDownMenuTemplate")
      btn.sfnMenu = menu
      menu.sfnButton = btn
      menu.values = values

      UIDropDownMenu_Initialize(menu, function(self, level)
        level = level or 1
        if level ~= 1 then return end
        local button = self and self.sfnButton or btn
        for _, v in ipairs(button.values or SFN_STATUS_VALUES) do
          local info = UIDropDownMenu_CreateInfo()
          info.text = v
          info.value = v
          info.checked = (button.sfnValue == v)
          info.func = function()
            button.sfnValue = v
            if button.sfnLabel then button.sfnLabel:SetText(v) end
            if onchange then onchange(v) end
            if CloseDropDownMenus then CloseDropDownMenus() end
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end, "MENU")

      btn:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, self.sfnMenu, self, 0, 0)
        if sfn_fix_dropdown_layers then sfn_fix_dropdown_layers() end
      end)

      return btn
    end


    function BLFG:SFN_UpdateNoticePopupToggle()
      if not self.sfnNoticePopupToggle then return end
      local label = sfn_notice_popups_enabled() and "Popups: On" or "Popups: Off"
      self.sfnNoticePopupToggle:SetText(label)
    end

    function BLFG:SFN_ToggleNoticePopups()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.noticePopups = not sfn_notice_popups_enabled()
      self:SFN_UpdateNoticePopupToggle()
      if BronzeLFG_DB.options.noticePopups == false then
        sfn_msg("Notice popups disabled. Incoming urgent notices will be pushed to chat only.", .8, .8, .8)
      else
        sfn_msg("Notice popups enabled.", .4, 1, .4)
      end
    end

    function BLFG:BuildSFNetworkPanel()
      if self.sfnPanel or not self.content then return end
      local p = CreateFrame("Frame", nil, self.content)
      self.sfnPanel = p
      p:SetAllPoints(); p:Hide()

      local title = sfn_font(p, "SignalFire Network", 18, 1, .75, 0); title:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -2)
      local sub = sfn_font(p, "Announcements, online users, status, and favorite activity.", 10, .8, .8, .8); sub:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -26)

      -- Left top: compact status controls. Uses the same native dropdown style as SignalFire Options/Create Listing.
      local leftTop = CreateFrame("Frame", nil, p); leftTop:SetWidth(400); leftTop:SetHeight(220); leftTop:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -48); sfn_backdrop(leftTop, .90)
      sfn_font(leftTop, "Set Your Status", 13, 1, .75, 0):SetPoint("TOPLEFT", leftTop, "TOPLEFT", 12, -12)
      sfn_font(leftTop, "Status:", 10, 1, .82, .35):SetPoint("TOPLEFT", leftTop, "TOPLEFT", 14, -42)

      local statusBtn = sfn_status_dropdown(leftTop, "SignalFireNetworkStatusDropdown", 210, SFN_STATUS_VALUES, (sfn_ensure_db().status and sfn_ensure_db().status.looking) or "Online", function(v)
        local n = sfn_ensure_db()
        n.status.looking = v or "Online"
        BronzeLFG_DB.network.status = n.status.looking
        if BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
        if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      end)
      self.sfnStatusButton = statusBtn
      statusBtn:SetPoint("TOPLEFT", leftTop, "TOPLEFT", 76, -34)

      sfn_font(leftTop, "Roles", 10, 1, .82, .35):SetPoint("TOPLEFT", leftTop, "TOPLEFT", 14, -82)
      self.sfnTank = sfn_check(leftTop, "Tank"); self.sfnTank:SetPoint("TOPLEFT", leftTop, "TOPLEFT", 76, -78)
      self.sfnHealer = sfn_check(leftTop, "Healer"); self.sfnHealer:SetPoint("LEFT", self.sfnTank, "RIGHT", 76, 0)
      self.sfnDPS = sfn_check(leftTop, "DPS"); self.sfnDPS:SetPoint("LEFT", self.sfnHealer, "RIGHT", 82, 0)
      local share = sfn_check(leftTop, "Share status with SignalFire users"); self.sfnShare = share; share:SetPoint("TOPLEFT", leftTop, "TOPLEFT", 58, -116)
      local trustedOnly = sfn_check(leftTop, "Accept notices from trusted senders only"); self.sfnTrustedNoticesOnly = trustedOnly; trustedOnly:SetPoint("TOPLEFT", leftTop, "TOPLEFT", 58, -144)
      trustedOnly:SetScript("OnClick", function(self)
        local n = sfn_ensure_db()
        n.acceptTrustedNoticesOnly = self:GetChecked() and true or false
        BronzeLFG_DB.network.acceptTrustedNoticesOnly = n.acceptTrustedNoticesOnly
      end)
      local save = sfn_button(leftTop, "Save Status", 120, 24); save:SetPoint("TOPLEFT", leftTop, "TOPLEFT", 140, -178)
      save:SetScript("OnClick", function()
        local n=sfn_ensure_db(); n.status.looking=(self.sfnStatusButton and self.sfnStatusButton.sfnValue) or n.status.looking or "Online"; n.status.tank=self.sfnTank:GetChecked() and true or false; n.status.healer=self.sfnHealer:GetChecked() and true or false; n.status.dps=self.sfnDPS:GetChecked() and true or false; n.status.share=self.sfnShare:GetChecked() and true or false; n.acceptTrustedNoticesOnly=self.sfnTrustedNoticesOnly:GetChecked() and true or false; BronzeLFG_DB.network.status=n.status.looking; BronzeLFG_DB.network.shareStatus=n.status.share and true or false; BronzeLFG_DB.network.acceptTrustedNoticesOnly=n.acceptTrustedNoticesOnly; BLFG:SFN_SendStatus(); BLFG:RefreshSFNetwork(); sfn_msg("SignalFire Network status saved.", .4, 1, .4)
      end)

      -- Left bottom: paged online list so we do not silently hide users when more are known.
      local leftBottom = CreateFrame("Frame", nil, p); leftBottom:SetWidth(400); leftBottom:SetHeight(250); leftBottom:SetPoint("TOPLEFT", leftTop, "BOTTOMLEFT", 0, -10); sfn_backdrop(leftBottom, .90)
      sfn_font(leftBottom, "Online SignalFire Users", 13, 1, .75, 0):SetPoint("TOPLEFT", leftBottom, "TOPLEFT", 12, -12)
      self.sfnUserCount = sfn_font(leftBottom, "Showing 0 online user(s)", 9, .8, .8, .8); self.sfnUserCount:SetPoint("TOPLEFT", leftBottom, "TOPLEFT", 12, -32)
      local uh = CreateFrame("Frame", nil, leftBottom); uh:SetWidth(374); uh:SetHeight(22); uh:SetPoint("TOPLEFT", leftBottom, "TOPLEFT", 12, -56); sfn_flat(uh, .95)
      sfn_font(uh, "Name", 9, 1, .82, .35):SetPoint("LEFT", uh, "LEFT", 8, 0)
      sfn_font(uh, "Class", 9, 1, .82, .35):SetPoint("LEFT", uh, "LEFT", 115, 0)
      sfn_font(uh, "Status", 9, 1, .82, .35):SetPoint("LEFT", uh, "LEFT", 185, 0)
      sfn_font(uh, "Zone", 9, 1, .82, .35):SetPoint("LEFT", uh, "LEFT", 292, 0)
      self.sfnUserRows = {}
      self.sfnRowsPerPage = 5
      for i=1,5 do
        local r = CreateFrame("Button", nil, leftBottom); r:SetWidth(374); r:SetHeight(24); r:SetPoint("TOPLEFT", leftBottom, "TOPLEFT", 12, -80 - ((i-1)*26)); sfn_flat(r, .72)
        r.name = sfn_font(r, "", 9, 1, 1, 1); r.name:SetPoint("LEFT", r, "LEFT", 8, 0); r.name:SetWidth(102); r.name:SetJustifyH("LEFT")
        r.class = sfn_font(r, "", 9, .8, .8, .8); r.class:SetPoint("LEFT", r, "LEFT", 115, 0); r.class:SetWidth(62); r.class:SetJustifyH("LEFT")
        r.status = sfn_font(r, "", 9, .4, 1, .4); r.status:SetPoint("LEFT", r, "LEFT", 185, 0); r.status:SetWidth(102); r.status:SetJustifyH("LEFT")
        r.zone = sfn_font(r, "", 9, .8, .8, .8); r.zone:SetPoint("LEFT", r, "LEFT", 292, 0); r.zone:SetWidth(80); r.zone:SetJustifyH("LEFT")
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, button)
          if not self.sfnName or self.sfnName == "" then return end
          BLFG.selectedSFNUser = tostring(self.sfnName)
          if button == "RightButton" and BLFG.ShowOnlineUserMenu then
            BLFG:ShowOnlineUserMenu(self, {name=self.sfnName})
          elseif BLFG.RefreshSFNetwork then
            BLFG:RefreshSFNetwork()
          end
        end)
        self.sfnUserRows[i]=r
      end
      local refresh = sfn_button(leftBottom, "Refresh Now", 88, 24); refresh:SetPoint("BOTTOMLEFT", leftBottom, "BOTTOMLEFT", 12, 12)
      self.sfnRefreshButton = refresh
      refresh:SetScript("OnClick", function()
        BLFG._sfnPresenceRefreshPending = sfn_now()
        if SignalFirePresenceAdminFix and SignalFirePresenceAdminFix.RequestPresence then
          SignalFirePresenceAdminFix.RequestPresence("network-button", true)
        else
          if BLFG.SendPresence then BLFG:SendPresence() end
          if BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
        end
        if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      end)
      self.sfnPrev = sfn_button(leftBottom, "Prev", 46, 24); self.sfnPrev:SetPoint("LEFT", refresh, "RIGHT", 6, 0); self.sfnPrev:SetScript("OnClick", function() BLFG.sfnUserPage = math.max(1, (BLFG.sfnUserPage or 1) - 1); BLFG:RefreshSFNetwork() end)
      self.sfnNext = sfn_button(leftBottom, "Next", 46, 24); self.sfnNext:SetPoint("LEFT", self.sfnPrev, "RIGHT", 4, 0); self.sfnNext:SetScript("OnClick", function() BLFG.sfnUserPage = (BLFG.sfnUserPage or 1) + 1; BLFG:RefreshSFNetwork() end)
      local autoRefresh = sfn_button(leftBottom, sfn_auto_refresh_label(), 82, 24); autoRefresh:SetPoint("LEFT", self.sfnNext, "RIGHT", 6, 0)
      self.sfnAutoRefreshButton = autoRefresh
      autoRefresh:SetScript("OnClick", function(selfButton)
        local seconds = sfn_cycle_auto_refresh()
        selfButton:SetText(sfn_auto_refresh_label())
        BLFG._sfnNextAutoRefresh = sfn_now() + math.max(1, seconds)
        if seconds <= 0 then
          sfn_msg("Network auto-refresh disabled.", .8, .8, .8)
        else
          sfn_msg("Network auto-refresh set to " .. tostring(seconds) .. " seconds.", .4, 1, .4)
        end
      end)
      self.sfnUpdated = sfn_font(leftBottom, "Waiting for presence...", 9, .8, .8, .8); self.sfnUpdated:SetPoint("TOPRIGHT", leftBottom, "TOPRIGHT", -12, -32)

      local rightTop = CreateFrame("Frame", nil, p); rightTop:SetWidth(400); rightTop:SetHeight(285); rightTop:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -48); sfn_backdrop(rightTop, .90)
      sfn_font(rightTop, "Notice Board", 13, 1, .75, 0):SetPoint("TOPLEFT", rightTop, "TOPLEFT", 12, -12)
      self.sfnNoticeCount = sfn_font(rightTop, "Showing 0 notice(s)", 9, .8, .8, .8); self.sfnNoticeCount:SetPoint("TOPLEFT", rightTop, "TOPLEFT", 12, -32)
      local mark = sfn_button(rightTop, "Mark All Read", 110, 24); mark:SetPoint("TOPRIGHT", rightTop, "TOPRIGHT", -130, -10)
      self.sfnMarkAllRead = mark
      local create = sfn_button(rightTop, "Create Notice", 110, 24); create:SetPoint("LEFT", mark, "RIGHT", 8, 0)
      self.sfnCreateNoticeButton = create
      sfn_update_create_notice_button(create)
      local popupToggle = sfn_button(rightTop, "Popups: On", 96, 22)
      self.sfnNoticePopupToggle = popupToggle
      popupToggle:SetPoint("TOPRIGHT", rightTop, "TOPRIGHT", -12, -10)
      popupToggle:Enable()
      popupToggle:SetFrameLevel((rightTop:GetFrameLevel() or 1) + 80)
      popupToggle:SetScript("OnClick", function() BLFG:SFN_ToggleNoticePopups() end)
      self:SFN_UpdateNoticePopupToggle()
      mark:SetScript("OnClick", function()
        local n = sfn_ensure_db()
        local rows = BLFG:SFN_GetNoticeRows()
        local unread = sfn_count_unread_notices(rows, n)
        for _, a in ipairs(rows or {}) do
          local id = tostring((a and a.id) or "")
          if id ~= "" then n.noticeSeen[id] = true end
        end
        if unread > 0 then
          sfn_msg("Marked " .. tostring(unread) .. " notice(s) as read.", .4, 1, .4)
        else
          sfn_msg("No unread SignalFire notices.", .8, .8, .8)
        end
        if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
      end)
      create:SetScript("OnClick", function()
        if not sfn_is_master_notice_admin() then
          sfn_msg("Only a SignalFire admin alias can create SignalFire network notices.", 1, .35, .35)
          return
        end
        BLFG:OpenSFNoticeCreator()
      end)
      self.sfnNoticeRows = {}
      for i=1,5 do
        local r = CreateFrame("Button", nil, rightTop); r:SetWidth(374); r:SetHeight(42); r:SetPoint("TOPLEFT", rightTop, "TOPLEFT", 12, -58 - ((i-1)*45)); sfn_flat(r, .72)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture("Interface\\COMMON\\Indicator-Green"); r.dot:SetWidth(10); r.dot:SetHeight(10); r.dot:SetPoint("LEFT", r, "LEFT", 8, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01"); r.icon:SetWidth(24); r.icon:SetHeight(24); r.icon:SetPoint("LEFT", r, "LEFT", 24, 0)
        r.title = sfn_font(r, "", 10, 1, 1, 1); r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 56, -6); r.title:SetWidth(238); r.title:SetHeight(12); r.title:SetJustifyH("LEFT")
        if r.title.SetNonSpaceWrap then r.title:SetNonSpaceWrap(false) end
        if r.title.SetWordWrap then r.title:SetWordWrap(false) end
        r.body = sfn_font(r, "", 8, .78, .78, .78); r.body:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2); r.body:SetWidth(275); r.body:SetHeight(12); r.body:SetJustifyH("LEFT")
        if r.body.SetNonSpaceWrap then r.body:SetNonSpaceWrap(false) end
        if r.body.SetWordWrap then r.body:SetWordWrap(false) end
        r.time = sfn_font(r, "", 8, .8, .8, .8); r.time:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8, -8)
        r:SetScript("OnClick", function(self, button)
          if not self.noticeId then return end
          if button == "RightButton" then
            if sfn_is_master_notice_admin() then
              sfn_master_clear_notice(self.noticeId)
            else
              sfn_msg("Only a SignalFire admin alias can master-clear SignalFire notices.", 1, .35, .35)
            end
            return
          end
          local row = self.noticeRow
          local n=sfn_ensure_db(); n.noticeSeen[self.noticeId]=true
          BLFG.sfnSelectedNoticeId = self.noticeId
          BLFG.sfnSelectedNoticeRow = row
          BLFG:RefreshSFNetwork()
          if row and BLFG.SFE_ShowNoticeDetail then
            BLFG:SFE_ShowNoticeDetail(row)
          elseif row then
            sfn_show_notice_popup(row)
          end
        end)
        r:SetScript("OnEnter", function(self)
          if not self.noticeRow then return end
          if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            sfn_notice_tooltip(self.noticeRow, (sfn_ensure_db().noticeSeen or {})[self.noticeId])
            GameTooltip:Show()
          end
        end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        self.sfnNoticeRows[i]=r
      end

      local rightBottom = CreateFrame("Frame", nil, p); rightBottom:SetWidth(400); rightBottom:SetHeight(140); rightBottom:SetPoint("TOPLEFT", rightTop, "BOTTOMLEFT", 0, -10); sfn_backdrop(rightBottom, .90)
      self.sfnBeaconPanel = rightBottom
      self.sfnBeaconTitle = sfn_font(rightBottom, "Event / Notice Details", 13, 1, .75, 0)
      self.sfnBeaconTitle:SetPoint("TOPLEFT", rightBottom, "TOPLEFT", 12, -12)
      self.sfnActivityRows = {}
      for i=1,2 do
        local r = CreateFrame("Frame", nil, rightBottom); r:SetWidth(374); r:SetHeight(31); r:SetPoint("TOPLEFT", rightBottom, "TOPLEFT", 12, -34 - ((i-1)*34)); sfn_flat(r, .60)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetWidth(22); r.icon:SetHeight(22); r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
        r.title = sfn_font(r, "", 9, 1, 1, 1); r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 38, -5); r.title:SetWidth(300); r.title:SetJustifyH("LEFT")
        r.body = sfn_font(r, "", 8, .75, .75, .75); r.body:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -1); r.body:SetWidth(300); r.body:SetJustifyH("LEFT")
        self.sfnActivityRows[i]=r
      end
      local fg = sfn_button(rightBottom, "Favorite Guilds", 125, 24); fg:SetPoint("BOTTOMLEFT", rightBottom, "BOTTOMLEFT", 36, 10); fg:SetScript("OnClick", function() BLFG:ShowGuildBrowser() end); fg:Hide()
      local fp = sfn_button(rightBottom, "Favorite Players", 125, 24); fp:SetPoint("LEFT", fg, "RIGHT", 22, 0); fp:SetScript("OnClick", function() BLFG:ShowSFNetwork() end)
      fp:Hide()
    end

    function BLFG:OpenSFNoticeCreator()
      sfn_ensure_db()
      if not sfn_is_master_notice_admin() then
        sfn_msg("Only a SignalFire admin alias can create SignalFire network notices.", 1, .35, .35)
        return
      end
      if self.sfnNoticeCreator then
        self.sfnNoticeCreator:Show()
        if self.sfnNoticeCreator.Raise then self.sfnNoticeCreator:Raise() end
        return
      end

      local f = CreateFrame("Frame", "SignalFireNoticeCreatorFrame", UIParent)
      self.sfnNoticeCreator = f
      f:SetWidth(460); f:SetHeight(310); f:SetPoint("CENTER", self.frame or UIParent, "CENTER", 90, 10)
      f:SetFrameStrata("FULLSCREEN_DIALOG"); f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 50) + 800)
      f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
      if f.SetClampedToScreen then f:SetClampedToScreen(true) end
      f:SetScript("OnDragStart", function(self) self:StartMoving() end); f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
      sfn_backdrop(f, .96)
      sfn_make_dialog_closable(f, "SignalFireNoticeCreatorFrame")

      local title = sfn_font(f, "Create SignalFire Notice", 14, 1, .75, 0); title:SetPoint("TOP", f, "TOP", 0, -14)
      local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
      f.closeButton = close
      close:SetWidth(32); close:SetHeight(32)
      close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
      sfn_raise_control(close, f, 90)
      close:SetScript("OnClick", function() sfn_close_notice_creator(f) end)

      sfn_font(f, "Title", 10, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -48)
      local titleBox = sfn_edit(f, 320, 24, false); titleBox:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -44); f.titleBox = titleBox
      sfn_raise_control(titleBox, f, 20)
      titleBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); sfn_close_notice_creator(f) end)

      sfn_font(f, "Priority", 10, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -82)
      local priorityBox = sfn_status_dropdown(f, "SignalFireNoticePriorityDropdown", 120, {"Normal", "Important", "Urgent"}, "Important", nil); priorityBox:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -78); f.priorityBox = priorityBox
      sfn_raise_control(priorityBox, f, 30)

      sfn_font(f, "Expires", 10, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 238, -82)
      local exp = sfn_status_dropdown(f, "SignalFireNoticeExpirationDropdown", 120, {"1 hour", "1 day", "7 days", "Never"}, "1 day", nil); exp:SetPoint("TOPLEFT", f, "TOPLEFT", 292, -78); f.expiresBox = exp
      sfn_raise_control(exp, f, 30)

      sfn_font(f, "Update", 10, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -116)
      local updateBox = sfn_edit(f, 110, 24, false); updateBox:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -112); f.updateBox = updateBox
      sfn_raise_control(updateBox, f, 20)
      updateBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); sfn_close_notice_creator(f) end)
      sfn_font(f, "optional stable version", 9, .8, .8, .8):SetPoint("LEFT", updateBox, "RIGHT", 8, 0)

      sfn_font(f, "Body", 10, 1, .82, .35):SetPoint("TOPLEFT", f, "TOPLEFT", 20, -150)
      local bodyBox = sfn_edit(f, 350, 86, true); bodyBox:SetPoint("TOPLEFT", f, "TOPLEFT", 90, -146); f.bodyBox = bodyBox
      sfn_raise_control(bodyBox, f, 20)
      bodyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); sfn_close_notice_creator(f) end)

      local send = sfn_button(f, "Send Notice", 110, 26); send:SetPoint("BOTTOM", f, "BOTTOM", -62, 16); f.sendButton = send
      local cancel = sfn_button(f, "Cancel", 90, 26); cancel:SetPoint("LEFT", send, "RIGHT", 10, 0); f.cancelButton = cancel
      sfn_raise_control(send, f, 70)
      sfn_raise_control(cancel, f, 70)
      cancel:SetScript("OnClick", function() sfn_close_notice_creator(f) end)
      send:SetScript("OnClick", function()
        BLFG:SFN_SendNotice(titleBox:GetText(), bodyBox:GetText(), priorityBox.sfnValue or "Important", exp.sfnValue or "1 day", updateBox:GetText())
        sfn_close_notice_creator(f)
      end)

      if f.Raise then f:Raise() end
    end

    function BLFG:RefreshSFNetwork()
      if not self.sfnPanel or not self.sfnPanel:IsVisible() then return end
      local n = sfn_ensure_db()
      local st = n.status or {}
      if self.sfnTank then self.sfnTank:SetChecked(st.tank and true or false) end
      if self.sfnHealer then self.sfnHealer:SetChecked(st.healer and true or false) end
      if self.sfnDPS then self.sfnDPS:SetChecked(st.dps and true or false) end
      if self.sfnShare then self.sfnShare:SetChecked(st.share ~= false) end
      if self.sfnTrustedNoticesOnly then self.sfnTrustedNoticesOnly:SetChecked(n.acceptTrustedNoticesOnly ~= false) end
      if self.sfnStatusButton then self.sfnStatusButton.sfnValue = st.looking or "Online"; sfn_set_status_text(self.sfnStatusButton, st.looking or "Online") end

      local rows = {}
      if self.GetOnlineUserRows then rows = self:GetOnlineUserRows() or {} end
      local nowStamp = sfn_now()
      local byName = {}
      for _, u in ipairs(rows) do
        local key = sfn_name_key(u and u.name or "")
        if key ~= "" then byName[key] = u end
      end
      for name, su in pairs(self.sfnStatuses or {}) do
        local seen = tonumber(su and su.seen or 0) or 0
        if seen <= 0 or (nowStamp - seen) > 180 then
          self.sfnStatuses[name] = nil
        else
          local key = sfn_name_key((su and su.name) or name)
          local existing = key ~= "" and byName[key] or nil
          if existing then
            existing.looking = su.looking
            existing.sfnRoleFlags = su.flags
            if tostring(existing.zone or "") == "" then existing.zone = su.zone end
            if tostring(existing.className or "") == "" or tostring(existing.className or "") == "Unknown" then existing.className = su.className end
            if tostring(existing.classFile or "") == "" or tostring(existing.classFile or "") == "UNKNOWN" then existing.classFile = su.classFile end
            if self.SF151_ResolveClassDisplay then self:SF151_ResolveClassDisplay(existing) end
            if seen > (tonumber(existing.seen or 0) or 0) then existing.seen = seen end
          else
            local row = {name=(su and su.name) or name, className=su.className, classFile=su.classFile, role=su.role, looking=su.looking, zone=su.zone, seen=seen}
            if self.SF151_ResolveClassDisplay then self:SF151_ResolveClassDisplay(row) end
            table.insert(rows, row)
            if key ~= "" then byName[key] = row end
          end
        end
      end
      table.sort(rows, function(a,b)
        if a.self and not b.self then return true end
        if b.self and not a.self then return false end
        if a.favorite and not b.favorite then return true end
        if b.favorite and not a.favorite then return false end
        return tostring(a.name or "") < tostring(b.name or "")
      end)

      self.sfnUserPage = tonumber(self.sfnUserPage or 1) or 1
      local per = tonumber(self.sfnRowsPerPage or #(self.sfnUserRows or {})) or 6
      if per < 1 then per = 6 end
      local pages = math.max(1, math.ceil((#rows) / per))
      if self.sfnUserPage > pages then self.sfnUserPage = pages end
      if self.sfnUserPage < 1 then self.sfnUserPage = 1 end
      local first = ((self.sfnUserPage - 1) * per) + 1
      local last = math.min(#rows, first + per - 1)
      if self.sfnUserCount then
        local pending = tonumber(self._sfnPresenceRefreshPending or 0) or 0
        if pending > 0 and (nowStamp - pending) <= 5 and #rows <= 1 then
          self.sfnUserCount:SetText("Searching for SignalFire users...")
        elseif #rows == 0 then
          self.sfnUserCount:SetText("No active SignalFire users found")
        elseif #rows == 1 and rows[1] and rows[1].self then
          self.sfnUserCount:SetText("Only you are currently visible on SignalFire")
        else
          self.sfnUserCount:SetText("Showing " .. tostring(first) .. "-" .. tostring(last) .. " of " .. tostring(#rows) .. " active user(s)")
        end
      end
      if self.sfnPrev then if self.sfnUserPage <= 1 then self.sfnPrev:Disable() else self.sfnPrev:Enable() end end
      if self.sfnNext then if self.sfnUserPage >= pages then self.sfnNext:Disable() else self.sfnNext:Enable() end end

      for i, r in ipairs(self.sfnUserRows or {}) do
        local u = rows[first + i - 1]
        if u then
          r:Show(); r.sfnName = u.name
          r.name:SetText((u.favorite and "|cffffd100[F] |r" or "") .. tostring(u.name or ""))
          local classText = self.SF151_ResolveClassDisplay and self:SF151_ResolveClassDisplay(u) or tostring(u.className or "")
          if classText == "" or classText == "Unknown" then classText = tostring(u.class or "") end
          if classText == "" or classText == "Unknown" then classText = "Unknown" end
          r.class:SetText(classText)
          r.status:SetText(tostring(u.looking or u.status or "Online"))
          r.zone:SetText(tostring(u.zone or ""))
        else
          r.sfnName=nil
          r.noticeRow=nil
          r.noticeId=nil
          if r.title then r.title:SetText("") end
          if r.body then r.body:SetText("") end
          if r.time then r.time:SetText("") end
          r:Hide()
        end
      end
      if self.sfnAutoRefreshButton then self.sfnAutoRefreshButton:SetText(sfn_auto_refresh_label()) end
      if self.sfnUpdated then
        local pending = tonumber(self._sfnPresenceRefreshPending or 0) or 0
        local response = tonumber(self._sfnLastPresenceResponse or 0) or 0
        if pending > 0 and (nowStamp - pending) <= 5 then
          self.sfnUpdated:SetText("Refreshing network...")
          self.sfnUpdated:SetTextColor(1, .82, .25)
        elseif response > 0 then
          local age = math.max(0, nowStamp - response)
          self.sfnUpdated:SetText("Last response: " .. tostring(age) .. "s ago")
          self.sfnUpdated:SetTextColor(.4, 1, .4)
        else
          self.sfnUpdated:SetText("No responses received yet")
          self.sfnUpdated:SetTextColor(.8, .8, .8)
        end
      end

      sfn_update_create_notice_button(self.sfnCreateNoticeButton)

      local notices = self:SFN_GetNoticeRows()
      local unread = sfn_count_unread_notices(notices, n)
      if self.sfnNoticeCount then
        self.sfnNoticeCount:SetText("Showing " .. tostring(#notices) .. " notice(s)  |  " .. tostring(unread) .. " unread")
      end
      sfn_set_mark_all_read_state(self.sfnMarkAllRead, unread)
      local selectedNoticeFound = false
      for i, r in ipairs(self.sfnNoticeRows or {}) do
        local a = notices[i]
        if a then
          r:Show(); r.noticeId=a.id; r.noticeRow=a
          if self.sfnSelectedNoticeId and tostring(a.id or "") == tostring(self.sfnSelectedNoticeId or "") then self.sfnSelectedNoticeRow = a; selectedNoticeFound = true end
          local read = n.noticeSeen[a.id] or n.noticeDismissed[a.id]
          if r.SetAlpha then r:SetAlpha(read and .62 or 1) end
          if r.SetBackdropColor then r:SetBackdropColor(0, 0, 0, read and .46 or .78) end
          if r.SetBackdropBorderColor then r:SetBackdropBorderColor(read and .35 or .85, read and .35 or .62, read and .35 or .12, read and .65 or .95) end
          if r.dot and r.dot.SetVertexColor then r.dot:SetVertexColor(read and .35 or .15, read and .35 or 1, read and .35 or .25, 1) end
          r.title:SetText(sfn_notice_row_title(a, read))
          if r.title.SetTextColor then r.title:SetTextColor(read and .72 or 1, read and .72 or 1, read and .72 or 1) end
          local bodyText = sfn_notice_body_for_display(a)
          local sender = sfn_short_display(a.sender or "SignalFire", 12)
          r.body:SetText(sfn_short_display("From: " .. sender .. " - " .. bodyText, 62))
          if r.body.SetTextColor then r.body:SetTextColor(read and .55 or .78, read and .55 or .78, read and .55 or .78) end
          if r.time.SetTextColor then r.time:SetTextColor(read and .55 or .8, read and .55 or .8, read and .55 or .8) end
          local age = math.max(0, sfn_now() - (tonumber(a.created) or sfn_now()))
          if age < 60 then r.time:SetText(tostring(age) .. "s") elseif age < 3600 then r.time:SetText(tostring(math.floor(age/60)) .. "m") elseif age < 86400 then r.time:SetText(tostring(math.floor(age/3600)) .. "h") else r.time:SetText(tostring(math.floor(age/86400)) .. "d") end
        else
          r.noticeId=nil; r.noticeRow=nil; r:Hide()
        end
      end
      if self.sfnSelectedNoticeId and not selectedNoticeFound then self.sfnSelectedNoticeId = nil; self.sfnSelectedNoticeRow = nil end
      for i, r in ipairs(self.sfnActivityRows or {}) do
        r:Hide()
      end
      if self.sfnBeaconTitle then self.sfnBeaconTitle:Hide() end
      if self.SFE_ShowNoticeDetail and n.eventBoardTab == "Notices" then
        self:SFE_ShowNoticeDetail(self.sfnSelectedNoticeRow)
      end
    end

    function BLFG:ShowSFNetwork()
      self:CreateUI(); self:HidePanels(); self:BuildSFNetworkPanel(); self.sfnPanel:Show(); self.frame:Show(); self.currentTab="Network"; self:SFN_SendStatus(); self:RefreshSFNetwork()
    end

    local function sfn_add_side_button(self)
      -- v1.3.5a: Network is now part of the normal left navigation in BronzeLFG:BuildSide().
      -- Do not add an extra bottom-anchored button; it overlapped the Triumvirate label.
      return
    end

    local SFN_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local r = SFN_OldCreateUI and SFN_OldCreateUI(self, ...)
      self:BuildSFNetworkPanel()
      sfn_add_side_button(self)
      return r
    end

    local SFN_OldHidePanels = BLFG.HidePanels
    function BLFG:HidePanels(...)
      local r = SFN_OldHidePanels and SFN_OldHidePanels(self, ...)
      if self.sfnPanel then self.sfnPanel:Hide() end
      return r
    end

    -- Recruitment Creator helpers -------------------------------------------------
    local function sfn_get_rc()
      sfn_ensure_db()
      return BLFG.RecruitmentCreator or {}
    end

    local function sfn_join_map(map)
      local out = {}
      for k,v in pairs(map or {}) do if v then table.insert(out, k) end end
      table.sort(out)
      return table.concat(out, ", ")
    end

    local function sfn_build_broadcast_preview()
      local rc = sfn_get_rc()
      local guild = sfn_clean((rc.guildEdit and rc.guildEdit:GetText()) or GetGuildInfo("player") or "Guild", 40)
      local notes = sfn_clean((rc.notesEdit and rc.notesEdit:GetText()) or "", 200)
      local discord = sfn_clean((rc.discordEdit and rc.discordEdit:GetText()) or "", 80)
      local roles = sfn_join_map(rc.roles)
      local activities = sfn_join_map(rc.activities)
      local msg
      if notes ~= "" then
        if string.find(sfn_low(notes), sfn_low(guild), 1, true) then msg = notes else msg = "<" .. guild .. "> " .. notes end
      else
        msg = "<" .. guild .. "> Recruiting!"
        if roles ~= "" and string.len(msg .. " Looking for: " .. roles .. ".") <= 255 then msg = msg .. " Looking for: " .. roles .. "." end
        if activities ~= "" and string.len(msg .. " Activities: " .. activities .. ".") <= 255 then msg = msg .. " Activities: " .. activities .. "." end
      end
      if discord ~= "" and string.find(sfn_low(msg), sfn_low(discord), 1, true) == nil and string.len(msg .. " Discord: " .. discord) <= 255 then msg = msg .. " Discord: " .. discord end
      if string.len(msg) > 255 then msg = string.sub(msg, 1, 252) .. "..." end
      return msg
    end

    function BLFG:SFN_SaveRecruitmentTemplate()
      local rc = sfn_get_rc()
      local db = BronzeLFG_DB.recruitmentCreator
      db.templates = db.templates or {}
      local name = sfn_clean((rc.templateName and rc.templateName:GetText()) or "", 40)
      if name == "" then name = sfn_clean((rc.guildEdit and rc.guildEdit:GetText()) or "Recruitment", 32) end
      if name == "" then name = "Recruitment" end
      db.templates[name] = {
        guild=(rc.guildEdit and rc.guildEdit:GetText()) or "",
        discord=(rc.discordEdit and rc.discordEdit:GetText()) or "",
        notes=(rc.notesEdit and rc.notesEdit:GetText()) or "",
        activities=rc.activities or {}, roles=rc.roles or {}, saved=sfn_now()
      }
      db.lastTemplate = name
      if rc.templateName then rc.templateName:SetText(name) end
      sfn_msg("Saved recruitment template: " .. name, .4, 1, .4)
    end

    local function sfn_copy_map(src)
      local out = {}
      for k,v in pairs(src or {}) do if v then out[k]=true end end
      return out
    end

    function BLFG:SFN_LoadRecruitmentTemplate()
      local rc = sfn_get_rc()
      local db = BronzeLFG_DB.recruitmentCreator
      local name = sfn_clean((rc.templateName and rc.templateName:GetText()) or db.lastTemplate or "", 40)
      local tpl = name ~= "" and db.templates and db.templates[name] or nil
      if not tpl then
        for k,v in pairs(db.templates or {}) do name=k; tpl=v; break end
      end
      if not tpl then sfn_msg("No recruitment templates saved yet.", 1, .82, .35); return end
      if rc.guildEdit then rc.guildEdit:SetText(tpl.guild or "") end
      if rc.discordEdit then rc.discordEdit:SetText(tpl.discord or "") end
      if rc.notesEdit then rc.notesEdit:SetText(tpl.notes or "") end
      rc.activities = sfn_copy_map(tpl.activities)
      rc.roles = sfn_copy_map(tpl.roles)
      if rc.activityChecks then for k,cb in pairs(rc.activityChecks) do cb:SetChecked(rc.activities[k] and true or false) end end
      if rc.roleChecks then for k,cb in pairs(rc.roleChecks) do cb:SetChecked(rc.roles[k] and true or false) end end
      if rc.templateName then rc.templateName:SetText(name) end
      db.lastTemplate = name
      if BLFG.RefreshRecruitmentPreview then BLFG:RefreshRecruitmentPreview() end
      if BLFG.SFN_UpdateRecruitmentEnhancements then BLFG:SFN_UpdateRecruitmentEnhancements() end
      sfn_msg("Loaded recruitment template: " .. name, .4, 1, .4)
    end

    function BLFG:SFN_DeleteRecruitmentTemplate()
      local rc = sfn_get_rc()
      local db = BronzeLFG_DB.recruitmentCreator
      local name = sfn_clean((rc.templateName and rc.templateName:GetText()) or db.lastTemplate or "", 40)
      if name ~= "" and db.templates and db.templates[name] then
        db.templates[name] = nil
        if rc.templateName then rc.templateName:SetText("") end
        sfn_msg("Deleted recruitment template: " .. name, 1, .82, .35)
      else
        sfn_msg("Template not found.", 1, .35, .35)
      end
    end

    function BLFG:SFN_UpdateRecruitmentEnhancements()
      local rc = sfn_get_rc()
      if rc.channelEdit then
        BronzeLFG_DB.recruitmentCreator.broadcastChannel = sfn_clean(rc.channelEdit:GetText(), 40)
        if BronzeLFG_DB.recruitmentCreator.broadcastChannel == "" then BronzeLFG_DB.recruitmentCreator.broadcastChannel = "Global-Guild-Recruitment" end
      end
      if rc.broadcastPreview then
        local msg = sfn_build_broadcast_preview()
        rc.broadcastPreview:SetText(msg)
        if rc.broadcastCount then
          local n = string.len(msg)
          if n <= 255 then rc.broadcastCount:SetText("|cff44ff44" .. tostring(n) .. " / 255|r") else rc.broadcastCount:SetText("|cffff4444" .. tostring(n) .. " / 255|r") end
        end
      end
    end

    function BLFG:SFN_EnhanceRecruitmentCreator()
      local rc = sfn_get_rc()
      local f = rc.frame
      if not f or rc.sfnEnhanced then return end
      rc.sfnEnhanced = true
      sfn_ensure_db()
      f:SetHeight(510)
      local label = sfn_font(f, "Template", 10, 1, .82, .35); label:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 70)
      local tn = sfn_edit(f, 118, 22, false); tn:SetPoint("LEFT", label, "RIGHT", 8, 0); rc.templateName = tn
      tn:SetText(BronzeLFG_DB.recruitmentCreator.lastTemplate or "")
      local load = sfn_button(f, "Load", 55, 22); load:SetPoint("LEFT", tn, "RIGHT", 5, 0); load:SetScript("OnClick", function() BLFG:SFN_LoadRecruitmentTemplate() end)
      local save = sfn_button(f, "Save", 55, 22); save:SetPoint("LEFT", load, "RIGHT", 5, 0); save:SetScript("OnClick", function() BLFG:SFN_SaveRecruitmentTemplate() end)
      local del = sfn_button(f, "Del", 45, 22); del:SetPoint("LEFT", save, "RIGHT", 5, 0); del:SetScript("OnClick", function() BLFG:SFN_DeleteRecruitmentTemplate() end)
      local chLabel = sfn_font(f, "Channel", 10, 1, .82, .35); chLabel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 45)
      local ch = sfn_edit(f, 150, 22, false); ch:SetPoint("LEFT", chLabel, "RIGHT", 8, 0); ch:SetText(BronzeLFG_DB.recruitmentCreator.broadcastChannel or "Global-Guild-Recruitment"); rc.channelEdit = ch
      ch:SetScript("OnTextChanged", function() BLFG:SFN_UpdateRecruitmentEnhancements() end)
      local count = sfn_font(f, "0 / 255", 10, .4, 1, .4); count:SetPoint("LEFT", ch, "RIGHT", 12, 0); rc.broadcastCount = count
      local pbox = CreateFrame("Frame", nil, f); pbox:SetWidth(440); pbox:SetHeight(34); pbox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 92); sfn_backdrop(pbox, .55)
      local ptext = sfn_font(pbox, "", 8, .9, .9, .9); ptext:SetPoint("TOPLEFT", pbox, "TOPLEFT", 6, -5); ptext:SetWidth(425); ptext:SetHeight(22); ptext:SetJustifyH("LEFT"); ptext:SetJustifyV("TOP"); rc.broadcastPreview = ptext
      local pl = sfn_font(f, "Broadcast Preview", 9, 1, .82, .35); pl:SetPoint("BOTTOMLEFT", pbox, "TOPLEFT", 0, 2)
      if rc.guildEdit then rc.guildEdit:HookScript("OnTextChanged", function() BLFG:SFN_UpdateRecruitmentEnhancements() end) end
      if rc.discordEdit then rc.discordEdit:HookScript("OnTextChanged", function() BLFG:SFN_UpdateRecruitmentEnhancements() end) end
      if rc.notesEdit then rc.notesEdit:HookScript("OnTextChanged", function() BLFG:SFN_UpdateRecruitmentEnhancements() end) end
      BLFG:SFN_UpdateRecruitmentEnhancements()
    end

    local SFN_OldOpenRecruitmentCreator = BLFG.OpenRecruitmentCreator
    function BLFG:OpenRecruitmentCreator(...)
      local r = SFN_OldOpenRecruitmentCreator and SFN_OldOpenRecruitmentCreator(self, ...)
      self:SFN_EnhanceRecruitmentCreator()
      return r
    end

    -- Optional hooks for favorite activity feed.
    if BLFG.UpsertGuildBrowserChatListing then
      local oldUpsert = BLFG.UpsertGuildBrowserChatListing
      function BLFG:UpsertGuildBrowserChatListing(guildName, author, raw, ...)
        local r = oldUpsert(self, guildName, author, raw, ...)
        if BronzeLFG_DB and BronzeLFG_DB.favoriteGuilds and BronzeLFG_DB.favoriteGuilds[string.lower(tostring(guildName or ""))] then
          sfn_add_activity(tostring(guildName or "Guild") .. " posted recruitment", tostring(raw or ""), "Interface\\Icons\\INV_Misc_TabardPVP_01")
          if self.RefreshSFNetwork then self:RefreshSFNetwork() end
        end
        return r
      end
    end

    function BLFG:SFN_MasterClearNotice(id)
      return sfn_master_clear_notice(id or (self and self.sfnSelectedNoticeId) or "")
    end

    -- Slash integration -----------------------------------------------------------
    local function sfn_handle_slash(input, old)
      local raw = tostring(input or "")
      local cmd = sfn_low(sfn_trim(raw))
      if cmd == "network" or cmd == "net" or cmd == "notice" or cmd == "notices" or cmd == "announcements" then BLFG:ShowSFNetwork(); return true end
      if cmd == "noticepopups" or cmd == "noticepopup" then
        if BLFG.SFN_ToggleNoticePopups then BLFG:SFN_ToggleNoticePopups() end
        return true
      end
      if cmd == "announce" then
        if not sfn_is_master_notice_admin() then sfn_msg("Only a SignalFire admin alias can create SignalFire network notices.", 1, .35, .35); return true end
        BLFG:CreateUI(); BLFG:OpenSFNoticeCreator(); return true
      end
      if string.sub(cmd, 1, 9) == "announce " then
        if not sfn_is_master_notice_admin() then sfn_msg("Only a SignalFire admin alias can create SignalFire network notices.", 1, .35, .35); return true end
        local rest = sfn_trim(string.sub(raw, 10))
        local lowRest = sfn_low(rest)
        if lowRest == "masterclear" or lowRest == "master clear" or lowRest == "clearall" then
          sfn_master_clear_notice("ALL")
          return true
        end
        if string.sub(lowRest, 1, 12) == "masterclear " then
          sfn_master_clear_notice(sfn_trim(string.sub(rest, 13)))
          return true
        end
        if lowRest == "clear" then
          local n = sfn_ensure_db(); n.notices = {}; n.noticeSeen = {}; n.noticeDismissed = {}; sfn_msg("SignalFire notices cleared locally.", .4, 1, .4); if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end; return true
        end
        if lowRest == "show" then
          local row = (BLFG.SFN_GetNoticeRows and BLFG:SFN_GetNoticeRows() or {})[1]
          if row then sfn_show_notice_popup(row) else sfn_msg("No SignalFire notice is available.", 1, .82, .35) end
          return true
        end
        if string.sub(lowRest, 1, 5) == "test " then
          local body = sfn_trim(string.sub(rest, 6))
          local row = sfn_store_notice("local-test-" .. tostring(sfn_now()), sfn_player(), sfn_now(), sfn_now() + 3600, "Urgent", "Local Test Notice", body, true, "")
          sfn_notice_alert(row, false)
          if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
          return true
        end
        local bar = string.find(rest, "|", 1, true)
        if bar then BLFG:SFN_SendNotice(sfn_trim(string.sub(rest,1,bar-1)), sfn_trim(string.sub(rest,bar+1)), "Important", "1 day", "")
        else BLFG:SFN_SendNotice(rest, "", "Important", "1 day", "") end
        return true
      end
      if string.sub(cmd, 1, 8) == "channel " then
        sfn_ensure_db(); BronzeLFG_DB.recruitmentCreator.broadcastChannel = sfn_clean(string.sub(raw, 9), 40); sfn_msg("Recruitment broadcast channel set to: " .. BronzeLFG_DB.recruitmentCreator.broadcastChannel); return true
      end
      return false
    end

    BLFG.SFN_HandleSlash = sfn_handle_slash

    local SFN_OldSlashSF = SlashCmdList and SlashCmdList["SIGNALFIRE"]
    local SFN_OldSlashBLFG = SlashCmdList and SlashCmdList["BRONZELFG"]
    if SlashCmdList then
      SLASH_SIGNALFIRE1 = "/sf"
      SLASH_SIGNALFIRE2 = "/signalfire"
      SlashCmdList["SIGNALFIRE"] = function(input)
        if sfn_handle_slash(input, SFN_OldSlashSF) then return end
        if SFN_OldSlashSF then return SFN_OldSlashSF(input) end
        if SFN_OldSlashBLFG then return SFN_OldSlashBLFG(input) end
      end
      SlashCmdList["BRONZELFG"] = function(input)
        if sfn_handle_slash(input, SFN_OldSlashBLFG) then return end
        if SFN_OldSlashBLFG then return SFN_OldSlashBLFG(input) end
      end
    end

    local SFN_Frame = CreateFrame("Frame")
    SFN_Frame.elapsed = 45
    SFN_Frame:RegisterEvent("PLAYER_LOGIN")
    SFN_Frame:RegisterEvent("CHAT_MSG_CHANNEL")
    SFN_Frame:SetScript("OnEvent", function(self, event, msgText, author)
      if event == "CHAT_MSG_CHANNEL" then
        sfn_handle_channel_payload(msgText, author)
        return
      end

      sfn_ensure_db()
      if BLFG and BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
      -- 1.4.1e: remove the old local-only welcome notice. It was seeded per
      -- character and could survive as a "ghost" even after Hsoj cleared notices.
      local n = sfn_ensure_db()
      n.seeded135 = true
      sfn_prune_legacy_welcome_notice(n)
      for _, row in ipairs(BLFG:SFN_GetNoticeRows()) do
        if not n.noticeSeen[row.id] and (sfn_notice_priority(row.priority) == "Urgent" or sfn_is_update_notice(row)) then
          sfn_show_notice_popup(row)
          break
        end
      end
    end)
    SFN_Frame:SetScript("OnUpdate", function(self, elapsed)
      self.elapsed = (self.elapsed or 0) + (elapsed or 0)
      if self.elapsed >= 60 then
        self.elapsed = 0
        if BLFG and BLFG.sfnPanel and BLFG.sfnPanel:IsVisible() then
          if BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
          if BLFG.RefreshSFNetwork then BLFG:RefreshSFNetwork() end
        end
      end
    end)

    -- ============================================================================
    -- SignalFire v1.3.5j: Network online user row interaction fix
    -- ============================================================================
    -- Left click now selects/highlights a user.  Right click opens social actions.
    -- The old Network-tab row click toggled favorites immediately, which caused chat
    -- spam and made it too easy to favorite several users by accident.
    function SFN135J_PlayerName()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    function SFN135J_UserTableForName(name)
      name = tostring(name or "")
      if name == "" or not BLFG then return {name=name} end
      local low = string.lower(name)
      if BLFG.GetOnlineUserRows then
        for _, u in ipairs(BLFG:GetOnlineUserRows() or {}) do
          if string.lower(tostring(u.name or "")) == low then return u end
        end
      end
      if BLFG.sfnStatuses then
        for n, su in pairs(BLFG.sfnStatuses or {}) do
          if string.lower(tostring(n or "")) == low then
            return {name=n, className=su.className, classFile=su.classFile, role=su.role, looking=su.looking, zone=su.zone, seen=su.seen}
          end
        end
      end
      return {name=name}
    end

    function SFN135J_OpenWho(name)
      name = tostring(name or "")
      if name == "" then return end
      if SetWhoToUI then SetWhoToUI(1) end
      if SendWho then SendWho('n-"' .. name .. '"') end
    end

    local function SFN135K_ShowRegion(region, show)
      if not region then return end
      if show then region:Show() else region:Hide() end
    end

    local function SFN135K_EnsureRowVisuals(row)
      if not row or row.SFN135KVisuals then return end
      row.SFN135KVisuals = true

      -- 3.3.5 fonts commonly render Unicode stars/arrows as question marks.
      -- Use simple row chrome instead of adding text symbols beside names.
      local select = row:CreateTexture(nil, "ARTWORK")
      select:SetTexture("Interface\\Buttons\\WHITE8X8")
      select:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
      select:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
      select:SetVertexColor(1, .72, .10, .14)
      select:Hide()
      row.SFN135KSelect = select

      local accent = row:CreateTexture(nil, "OVERLAY")
      accent:SetTexture("Interface\\Buttons\\WHITE8X8")
      accent:SetWidth(3)
      accent:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
      accent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
      accent:SetVertexColor(1, .82, .10, .95)
      accent:Hide()
      row.SFN135KAccent = accent

      local hover = row:CreateTexture(nil, "ARTWORK")
      hover:SetTexture("Interface\\Buttons\\WHITE8X8")
      hover:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
      hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
      hover:SetVertexColor(1, .82, .15, .08)
      hover:Hide()
      row.SFN135KHover = hover

      row:SetScript("OnEnter", function(self)
        if tostring(self.sfnName or "") ~= tostring(BLFG.selectedSFNUser or "") then SFN135K_ShowRegion(self.SFN135KHover, true) end
        if self.SetBackdropBorderColor then self:SetBackdropBorderColor(.95, .68, .16, .95) end
      end)
      row:SetScript("OnLeave", function(self)
        SFN135K_ShowRegion(self.SFN135KHover, false)
        if tostring(self.sfnName or "") == tostring(BLFG.selectedSFNUser or "") then
          if self.SetBackdropBorderColor then self:SetBackdropBorderColor(.95, .68, .16, .95) end
        else
          if self.SetBackdropBorderColor then self:SetBackdropBorderColor(.55, .40, .08, .85) end
        end
      end)
    end

    function SFN135J_InstallRows()
      if not BLFG or not BLFG.sfnUserRows then return end
      for _, row in ipairs(BLFG.sfnUserRows or {}) do
        if row then
          SFN135K_EnsureRowVisuals(row)
          if not row.SFN135JFixed then
            row.SFN135JFixed = true
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:SetScript("OnClick", function(self, button)
              if not self.sfnName or self.sfnName == "" then return end
              BLFG.selectedSFNUser = tostring(self.sfnName)
              if button == "RightButton" then
                if BLFG.ShowOnlineUserMenu then BLFG:ShowOnlineUserMenu(self, SFN135J_UserTableForName(self.sfnName)) end
              else
                if IsShiftKeyDown and IsShiftKeyDown() and ChatFrame_OpenChat then
                  ChatFrame_OpenChat("/w " .. tostring(self.sfnName) .. " ")
                elseif IsControlKeyDown and IsControlKeyDown() and InviteUnit and tostring(self.sfnName) ~= SFN135J_PlayerName() then
                  InviteUnit(self.sfnName)
                elseif BLFG.RefreshSFNetwork then
                  BLFG:RefreshSFNetwork()
                end
              end
            end)
          end
        end
      end
    end

    function SFN135J_ApplySelection()
      if not BLFG or not BLFG.sfnUserRows then return end
      for _, row in ipairs(BLFG.sfnUserRows or {}) do
        if row then SFN135K_EnsureRowVisuals(row) end
        if row and row.sfnName then
          local selected = tostring(row.sfnName or "") == tostring(BLFG.selectedSFNUser or "")
          SFN135K_ShowRegion(row.SFN135KSelect, selected)
          SFN135K_ShowRegion(row.SFN135KAccent, selected)
          if not selected then SFN135K_ShowRegion(row.SFN135KHover, false) end
          if row.SetBackdropColor then row:SetBackdropColor(0, 0, 0, selected and .78 or .72) end
          if row.SetBackdropBorderColor then
            if selected then row:SetBackdropBorderColor(.95, .68, .16, .95) else row:SetBackdropBorderColor(.55, .40, .08, .85) end
          end
          -- Do not prefix selected rows with arrows. The 3.3.5 client can render
          -- those as question marks with some fonts/locales.
        elseif row then
          SFN135K_ShowRegion(row.SFN135KSelect, false)
          SFN135K_ShowRegion(row.SFN135KAccent, false)
          SFN135K_ShowRegion(row.SFN135KHover, false)
          if row.SetBackdropColor then row:SetBackdropColor(0, 0, 0, .72) end
          if row.SetBackdropBorderColor then row:SetBackdropBorderColor(.55, .40, .08, .85) end
        end
      end
    end

    SFN135J_OldShowOnlineUserMenu = SFN135J_OldShowOnlineUserMenu or BLFG.ShowOnlineUserMenu
    function BLFG:ShowOnlineUserMenu(anchor, u)
      if not u or not u.name then return end
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
        info.func = function() if BLFG.ShowBronzeNetProfile then BLFG:ShowBronzeNetProfile(SFN135J_UserTableForName(name)) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Whisper"
        info.notCheckable = true
        info.disabled = (name == SFN135J_PlayerName())
        info.func = function() if name ~= SFN135J_PlayerName() and ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " ") end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Invite"
        info.notCheckable = true
        info.disabled = (name == SFN135J_PlayerName())
        info.func = function() if name ~= SFN135J_PlayerName() and InviteUnit then InviteUnit(name) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Add Friend"
        info.notCheckable = true
        info.disabled = (name == SFN135J_PlayerName())
        info.func = function() if name ~= SFN135J_PlayerName() and AddFriend then AddFriend(name) end end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Who Lookup"
        info.notCheckable = true
        info.disabled = (name == SFN135J_PlayerName())
        info.func = function() if name ~= SFN135J_PlayerName() then SFN135J_OpenWho(name) end end
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
        info.text = "Cancel"
        info.notCheckable = true
        info.func = function() if CloseDropDownMenus then CloseDropDownMenus() end end
        UIDropDownMenu_AddButton(info)
      end, "MENU")
      ToggleDropDownMenu(1, nil, self.onlineMenu, anchor or UIParent, 0, 0)
      if sfn_fix_dropdown_layers then sfn_fix_dropdown_layers() end
      if self.RefreshSFNetwork then self:RefreshSFNetwork() end
    end

    SFN135J_OldBuildSFNetworkPanel = SFN135J_OldBuildSFNetworkPanel or BLFG.BuildSFNetworkPanel
    function BLFG:BuildSFNetworkPanel(...)
      local r = SFN135J_OldBuildSFNetworkPanel and SFN135J_OldBuildSFNetworkPanel(self, ...)
      SFN135J_InstallRows()
      SFN135J_ApplySelection()
      return r
    end

    SFN135J_OldRefreshSFNetwork = SFN135J_OldRefreshSFNetwork or BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      local visible = self and self.sfnPanel and self.sfnPanel:IsVisible()
      local r = SFN135J_OldRefreshSFNetwork and SFN135J_OldRefreshSFNetwork(self, ...)
      if visible then
        SFN135J_InstallRows()
        SFN135J_ApplySelection()
      end
      return r
    end

    SFN135J_OldShowSFNetwork = SFN135J_OldShowSFNetwork or BLFG.ShowSFNetwork
    function BLFG:ShowSFNetwork(...)
      local r = SFN135J_OldShowSFNetwork and SFN135J_OldShowSFNetwork(self, ...)
      SFN135J_InstallRows()
      SFN135J_ApplySelection()
      return r
    end
  until true
end

-- Network presentation
do
  repeat
    local BLFG = _G.BronzeLFG
    if not BLFG then break end

    local SFAM_VERSION = _G.SignalFire_VERSION or "1.4.23"

    local function sfam_now()
      return (GetTime and GetTime()) or (time and time()) or 0
    end

    local function sfam_time()
      return (time and time()) or 0
    end

    local function sfam_player()
      return (UnitName and UnitName("player")) or "Unknown"
    end

    local function sfam_trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      s = string.gsub(s, "%s+$", "")
      return s
    end

    local function sfam_short(s, n)
      s = tostring(s or "")
      n = tonumber(n) or 0
      if n > 0 and string.len(s) > n then return string.sub(s, 1, math.max(1, n - 3)) .. "..." end
      return s
    end

    local function sfam_dd_text(d)
      if not d then return "" end
      local text = nil
      if UIDropDownMenu_GetText then text = UIDropDownMenu_GetText(d) end
      if (not text or text == "") and d.GetName then
        local name = d:GetName()
        local fs = name and _G[tostring(name) .. "Text"] or nil
        if fs and fs.GetText then text = fs:GetText() end
      end
      if (not text or text == "") and d.selectedName then text = d.selectedName end
      if (not text or text == "") and d.selectedValue then text = d.selectedValue end
      return tostring(text or "")
    end

    local function sfam_raise_children(frame, level)
      if not frame or not frame.GetChildren then return end
      level = tonumber(level) or ((frame.GetFrameLevel and frame:GetFrameLevel()) or 1) + 5
      for _, child in ipairs({frame:GetChildren()}) do
        if child and child.SetFrameLevel then child:SetFrameLevel(level) end
        sfam_raise_children(child, level + 1)
      end
    end

    local function sfam_msg(text, r, g, b)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text or ""), r or 1, g or .82, b or 0) end
    end

    local function sfam_ensure_options()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      local o = BronzeLFG_DB.options
      if o.pulseEffects == nil then o.pulseEffects = true end
      if o.tooltips == nil then o.tooltips = true end
      if o.beaconEnabled == nil then o.beaconEnabled = true end
      if o.loginSummaryToast == nil then o.loginSummaryToast = true end
      if o.activityIcons == nil then o.activityIcons = false end
      return o
    end

    local function sfam_enabled(key)
      local o = sfam_ensure_options()
      return o[key] ~= false
    end

    local function sfam_backdrop(frame, alpha)
      if not frame or not frame.SetBackdrop then return end
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}
      })
      frame:SetBackdropColor(0, 0, 0, alpha or .86)
      frame:SetBackdropBorderColor(.85, .62, .12, .95)
    end


    local function sfam_register_escape_frame(frame, name)
      if not frame then return end
      if name and _G[name] ~= frame then _G[name] = frame end
      if name and UISpecialFrames then
        local exists = false
        for _, v in ipairs(UISpecialFrames) do if v == name then exists = true; break end end
        if not exists then table.insert(UISpecialFrames, name) end
      end
      if frame.EnableKeyboard then frame:EnableKeyboard(true) end
      frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then self:Hide() end
      end)
    end

    local function sfam_prepare_beacon_host(host, keep)
      if not host then return end
      host._sfamBeaconHiddenChildren = host._sfamBeaconHiddenChildren or {}
      host._sfamBeaconHiddenRegions = host._sfamBeaconHiddenRegions or {}
      if host.GetChildren then
        for _, child in ipairs({host:GetChildren()}) do
          if child and child ~= keep then
            if child.IsShown and child:IsShown() then table.insert(host._sfamBeaconHiddenChildren, child) end
            if child.Hide then child:Hide() end
            if child.EnableMouse then child:EnableMouse(false) end
          end
        end
      end
      if host.GetRegions then
        for _, region in ipairs({host:GetRegions()}) do
          if region and region.GetText and region:GetText() == "Favorite Activity" then
            if region.IsShown and region:IsShown() then table.insert(host._sfamBeaconHiddenRegions, region) end
            if region.Hide then region:Hide() end
          end
        end
      end
    end

    local function sfam_restore_beacon_host(host)
      if not host then return end
      for _, child in ipairs(host._sfamBeaconHiddenChildren or {}) do
        if child and child.Show then child:Show() end
        if child and child.EnableMouse then child:EnableMouse(true) end
      end
      for _, region in ipairs(host._sfamBeaconHiddenRegions or {}) do
        if region and region.Show then region:Show() end
      end
      host._sfamBeaconHiddenChildren = {}
      host._sfamBeaconHiddenRegions = {}
    end
    local function sfam_flat(frame, alpha)
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

    local function sfam_font(parent, text, size, r, g, b)
      local fs = parent:CreateFontString(nil, "OVERLAY", size and size >= 13 and "GameFontNormal" or "GameFontNormalSmall")
      fs:SetText(tostring(text or ""))
      fs:SetTextColor(r or 1, g or .82, b or 0)
      return fs
    end

    local function sfam_button(parent, text, w, h)
      local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetWidth(w or 90); b:SetHeight(h or 24); b:SetText(tostring(text or "Button"))
      return b
    end

    local function sfam_class_color(classFile)
      classFile = tostring(classFile or "")
      if RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] then
        local c = RAID_CLASS_COLORS[classFile]
        return c.r or 1, c.g or 1, c.b or 1
      end
      if classFile == "PALADIN" then return .96, .55, .73 end
      if classFile == "DEATHKNIGHT" then return .77, .12, .23 end
      if classFile == "WARRIOR" then return .78, .61, .43 end
      if classFile == "MAGE" then return .41, .80, .94 end
      if classFile == "PRIEST" then return 1, 1, 1 end
      if classFile == "SHAMAN" then return .0, .44, .87 end
      if classFile == "DRUID" then return 1, .49, .04 end
      if classFile == "ROGUE" then return 1, .96, .41 end
      if classFile == "HUNTER" then return .67, .83, .45 end
      if classFile == "WARLOCK" then return .58, .51, .79 end
      return .8, .8, .8
    end

    local function sfam_activity_icon(kind, activity)
      kind = tostring(kind or "")
      activity = tostring(activity or "")
      if string.find(activity, "Dungeon") or kind == "Dungeon" then return "Interface\\Icons\\INV_Misc_Map_01" end
      if kind == "Raid" or string.find(activity, "Raid") then return "Interface\\Icons\\INV_Helmet_08" end
      if kind == "Guild" or string.find(activity, "Guild") then return "Interface\\Icons\\INV_Misc_TabardPVP_01" end
      if kind == "Event" or string.find(activity, "Event") then return "Interface\\Icons\\INV_Misc_GroupLooking" end
      if kind == "Keystone" or string.find(activity, "Keystone") or string.find(activity, "Mythic") then return "Interface\\Icons\\INV_Relics_Hourglass" end
      return "Interface\\Icons\\INV_Misc_Note_01"
    end

    local function sfam_make_glow(frame)
      if not frame or frame.sfamGlow then return frame and frame.sfamGlow end
      local glow = frame:CreateTexture(nil, "OVERLAY")
      glow:SetTexture("Interface\\Buttons\\WHITE8X8")
      glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
      glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
      glow:SetVertexColor(1, .72, .12, 0)
      glow:Hide()
      frame.sfamGlow = glow
      return glow
    end

    local function sfam_pulse(frame, duration, r, g, b, maxAlpha)
      if not frame or not sfam_enabled("pulseEffects") then return end
      duration = tonumber(duration) or 5
      local glow = sfam_make_glow(frame)
      if not glow then return end
      frame.sfamPulseUntil = sfam_now() + duration
      frame.sfamPulseDuration = duration
      frame.sfamPulseColor = {r or 1, g or .72, b or .12, maxAlpha or .25}
      glow:Show()
      if frame.sfamPulseHooked then return end
      frame.sfamPulseHooked = true
      local oldUpdate = frame:GetScript("OnUpdate")
      frame.sfamOldOnUpdate = oldUpdate
      frame:SetScript("OnUpdate", function(self, elapsed)
        if self.sfamOldOnUpdate then self.sfamOldOnUpdate(self, elapsed) end
        if self.sfamPulseUntil and sfam_now() < self.sfamPulseUntil then
          local c = self.sfamPulseColor or {1,.72,.12,.25}
          local remain = self.sfamPulseUntil - sfam_now()
          local fade = math.max(0, math.min(1, remain / (self.sfamPulseDuration or 5)))
          local wave = (math.sin(sfam_now() * 7) + 1) / 2
          local alpha = (.04 + (wave * (c[4] or .25))) * fade
          if self.sfamGlow then
            self.sfamGlow:SetVertexColor(c[1] or 1, c[2] or .72, c[3] or .12, alpha)
            self.sfamGlow:Show()
          end
        else
          self.sfamPulseUntil = nil
          if self.sfamGlow then self.sfamGlow:Hide() end
          local restore = self.sfamOldOnUpdate
          self.sfamOldOnUpdate = nil
          self.sfamPulseHooked = nil
          self:SetScript("OnUpdate", restore)
        end
      end)
    end

    local function sfam_tooltip(frame, title, body, extra)
      if not frame or frame.sfamTooltipHooked then return end
      frame.sfamTooltipHooked = true
      frame.sfamTooltipTitle = title
      frame.sfamTooltipBody = body
      frame.sfamTooltipExtra = extra
      local oldEnter = frame:GetScript("OnEnter")
      local oldLeave = frame:GetScript("OnLeave")
      frame:SetScript("OnEnter", function(self, ...)
        if oldEnter then oldEnter(self, ...) end
        if not sfam_enabled("tooltips") then return end
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(tostring(self.sfamTooltipTitle or title or "SignalFire"), 1, .82, 0)
        local b = self.sfamTooltipBody or body
        if b and b ~= "" then GameTooltip:AddLine(tostring(b), .9, .9, .9, true) end
        local e = self.sfamTooltipExtra or extra
        if e and e ~= "" then GameTooltip:AddLine(tostring(e), .45, .85, 1, true) end
        GameTooltip:Show()
      end)
      frame:SetScript("OnLeave", function(self, ...)
        if oldLeave then oldLeave(self, ...) end
        if GameTooltip then GameTooltip:Hide() end
      end)
    end

    function BLFG:SFAM_MarkRelevant(reason, duration)
      if not sfam_enabled("pulseEffects") then return end
      self.sfamRelevantUntil = sfam_now() + (tonumber(duration) or 8)
      self.sfamRelevantReason = tostring(reason or "SignalFire update")
      if self.mm then sfam_pulse(self.mm, tonumber(duration) or 8, 1, .72, .10, .35) end
      if self.SFAM_PulseSideButton then self:SFAM_PulseSideButton("Network", tonumber(duration) or 8) end
    end

    function BLFG:SFAM_ShowToast(title, body, icon, duration)
      if not sfam_enabled("pulseEffects") then return end
      duration = tonumber(duration) or 5
      if not self.sfamToast then
        local f = CreateFrame("Frame", nil, UIParent)
        self.sfamToast = f
        f:SetWidth(330); f:SetHeight(70)
        f:SetPoint("TOP", UIParent, "TOP", 0, -120)
        f:SetFrameStrata("TOOLTIP")
        f:EnableMouse(true)
        sfam_backdrop(f, .92)
        f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetWidth(34); f.icon:SetHeight(34); f.icon:SetPoint("LEFT", f, "LEFT", 12, 0)
        f.title = sfam_font(f, "", 13, 1, .82, 0); f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 56, -14); f.title:SetWidth(255); f.title:SetJustifyH("LEFT")
        f.body = sfam_font(f, "", 9, .85, .85, .85); f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4); f.body:SetWidth(255); f.body:SetJustifyH("LEFT")
        f:SetScript("OnMouseUp", function(self) self:Hide() end)
        f:SetScript("OnUpdate", function(self)
          if not self.sfamHideAt then return end
          local left = self.sfamHideAt - sfam_now()
          if left <= 0 then self:Hide(); return end
          if left < .6 then self:SetAlpha(math.max(0, left / .6)) else self:SetAlpha(1) end
        end)
      end
      local f = self.sfamToast
      if f.icon then f.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_GroupLooking") end
      if f.title then f.title:SetText(tostring(title or "SignalFire")) end
      if f.body then f.body:SetText(tostring(body or "")) end
      f.sfamHideAt = sfam_now() + duration
      f:SetAlpha(1)
      f:Show()
    end

    function BLFG:SFAM_FindSideButtons()
      if not self.side or not self.side.GetChildren then return end
      self.sfamSideButtons = self.sfamSideButtons or {}
      local kids = { self.side:GetChildren() }
      for _, child in ipairs(kids) do
        if child and child.GetRegions then
          local regions = { child:GetRegions() }
          for _, region in ipairs(regions) do
            if region and region.GetText then
              local text = region:GetText()
              if text and text ~= "" then
                self.sfamSideButtons[text] = child
                child.sfamTabName = text
              end
            end
          end
        end
      end
    end

    function BLFG:SFAM_PulseSideButton(name, duration)
      self:SFAM_FindSideButtons()
      local b = self.sfamSideButtons and self.sfamSideButtons[name]
      if b then sfam_pulse(b, duration or 6, 1, .75, .10, .30) end
    end

    local function sfam_role_label(flags, role)
      flags = tostring(flags or "")
      role = tostring(role or "")
      if flags ~= "" and flags ~= "-" then return flags end
      if role ~= "" then
        local r = string.lower(role)
        if string.find(r, "tank") then return "T" end
        if string.find(r, "heal") then return "H" end
        if string.find(r, "dps") then return "D" end
      end
      return "-"
    end

    local function sfam_compiled_online_rows(self)
      local rows = {}
      local seen = {}
      if self and self.GetOnlineUserRows then
        for _, u in ipairs(self:GetOnlineUserRows() or {}) do
          if u then
            table.insert(rows, u)
            local n = string.lower(tostring(u.name or ""))
            if n ~= "" then seen[n] = u end
          end
        end
      end
      if self and self.sfnStatuses then
        for name, su in pairs(self.sfnStatuses or {}) do
          local low = string.lower(tostring(name or ""))
          if low ~= "" and seen[low] then
            local u = seen[low]
            u.looking = su.looking or u.looking
            u.status = su.looking or u.status
            u.sfnRoleFlags = su.flags or u.sfnRoleFlags
            u.flags = su.flags or u.flags
            u.zone = (u.zone and u.zone ~= "") and u.zone or su.zone
            u.className = (u.className and u.className ~= "") and u.className or su.className
            u.classFile = (u.classFile and u.classFile ~= "") and u.classFile or su.classFile
            u.role = (u.role and u.role ~= "") and u.role or su.role
          elseif low ~= "" then
            table.insert(rows, {
              name = name,
              className = su.className,
              classFile = su.classFile,
              role = su.role,
              looking = su.looking or "Online",
              status = su.looking or "Online",
              zone = su.zone,
              seen = su.seen,
              sfnRoleFlags = su.flags,
              flags = su.flags,
              favorite = self.IsFavorite and self:IsFavorite(name) or false,
            })
          end
        end
      end
      table.sort(rows, function(a,b)
        if a.self and not b.self then return true end
        if b.self and not a.self then return false end
        if a.favorite and not b.favorite then return true end
        if b.favorite and not a.favorite then return false end
        return tostring(a.name or "") < tostring(b.name or "")
      end)
      if self then self.sfamCompiledOnlineRows = rows end
      return rows
    end

    function BLFG:SFAM_UserByName(name)
      name = tostring(name or "")
      if name == "" then return nil end
      local low = string.lower(name)
      for _, u in ipairs(sfam_compiled_online_rows(self) or {}) do
        if string.lower(tostring(u.name or "")) == low then return u end
      end
      return { name = name }
    end

    function BLFG:SFAM_BuildBeaconPanel()
      if not self.sfnPanel then return end
      local p = self.sfnPanel
      local parent = p

      -- Own the lower-right Network slot.  If the older Favorite Activity panel was
      -- built first, use its parent as the host and hide the old child controls while
      -- Beacon is enabled.  This prevents bleed-through and competing buttons.
      if self.sfnActivityRows and self.sfnActivityRows[1] and self.sfnActivityRows[1].GetParent then
        parent = self.sfnActivityRows[1]:GetParent() or p
      end

      if self.sfamBeaconPanel then
        if self.sfamBeaconHost ~= parent and self.sfamBeaconPanel.SetParent then
          sfam_restore_beacon_host(self.sfamBeaconHost)
          self.sfamBeaconPanel:SetParent(parent)
          self.sfamBeaconHost = parent
        end
        sfam_prepare_beacon_host(parent, self.sfamBeaconPanel)
        return
      end

      local f = CreateFrame("Frame", nil, parent)
      self.sfamBeaconPanel = f
      self.sfamBeaconHost = parent
      if parent ~= p then
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -4)
        f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
      else
        f:SetWidth(400); f:SetHeight(150)
        f:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -343)
      end
      f:SetFrameLevel(((parent.GetFrameLevel and parent:GetFrameLevel()) or (p:GetFrameLevel() or 1)) + 30)
      sfam_backdrop(f, .99)
      f:EnableMouse(true)
      sfam_prepare_beacon_host(parent, f)

      f.title = sfam_font(f, "SignalFire Beacon", 13, 1, .75, 0)
      f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)

      -- Do not put a secondary Roster button inside the compact Beacon. The Network
      -- user list already has a View Full Roster button directly beside it. Keeping
      -- Beacon as pure information prevents header/button crowding in this short box.
      f.roster = nil

      f.summary = sfam_font(f, "", 9, .88, .88, .88)
      f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -34)
      f.summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -34)
      f.summary:SetHeight(14)
      f.summary:SetJustifyH("LEFT")
      if f.summary.SetNonSpaceWrap then f.summary:SetNonSpaceWrap(false) end
      if f.summary.SetWordWrap then f.summary:SetWordWrap(false) end

      -- Content lane: this is the only area that changes.  In selected-player mode
      -- it shows compact player details; in idle mode it shows favorite activity.
      -- Beacon is intentionally information-only now.  Quick actions stay on the
      -- row right-click menu and in the Full Roster, which avoids duplicated controls
      -- and permanently prevents button/text overlap in this compact panel.
      f.content = CreateFrame("Frame", nil, f)
      f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -52)
      f.content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
      f.content:SetFrameLevel((f:GetFrameLevel() or 1) + 2)
      sfam_flat(f.content, .66)
      f.content:EnableMouse(false)

      f.modeLabel = sfam_font(f.content, "", 9, 1, .82, 0)
      f.modeLabel:SetPoint("TOPLEFT", f.content, "TOPLEFT", 8, -6)
      f.modeLabel:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -8, -6)
      f.modeLabel:SetHeight(13)
      f.modeLabel:SetJustifyH("LEFT")

      f.line1 = sfam_font(f.content, "", 10, 1, 1, 1)
      f.line1:SetPoint("TOPLEFT", f.modeLabel, "BOTTOMLEFT", 0, -3)
      f.line1:SetPoint("TOPRIGHT", f.modeLabel, "BOTTOMRIGHT", 0, -3)
      f.line1:SetHeight(14)
      f.line1:SetJustifyH("LEFT")

      f.line2 = sfam_font(f.content, "", 9, .9, .9, .9)
      f.line2:SetPoint("TOPLEFT", f.line1, "BOTTOMLEFT", 0, -2)
      f.line2:SetPoint("TOPRIGHT", f.line1, "BOTTOMRIGHT", 0, -2)
      f.line2:SetHeight(13)
      f.line2:SetJustifyH("LEFT")

      f.line3 = sfam_font(f.content, "", 9, .8, .9, 1)
      f.line3:SetPoint("TOPLEFT", f.line2, "BOTTOMLEFT", 0, -2)
      f.line3:SetPoint("TOPRIGHT", f.line2, "BOTTOMRIGHT", 0, -2)
      f.line3:SetHeight(13)
      f.line3:SetJustifyH("LEFT")

      for _, fs in ipairs({f.modeLabel, f.line1, f.line2, f.line3}) do
        if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
        if fs.SetWordWrap then fs:SetWordWrap(false) end
      end

      -- No extra help/instruction line inside Beacon. It was crowding the selected
      -- player lane and visually overlapping the old action-button area. Actions are
      -- available by right-clicking the selected row or by opening Full Roster.
      f.help = nil
    end

    function BLFG:SFAM_UpdateBeaconPanel()
      if not self.sfamBeaconPanel then return end
      local f = self.sfamBeaconPanel
      if not sfam_enabled("beaconEnabled") then
        f:Hide()
        sfam_restore_beacon_host(self.sfamBeaconHost)
        return
      end
      sfam_prepare_beacon_host(self.sfamBeaconHost, f)
      f:Show()

      local selected = self.selectedSFNUser
      local u = selected and self:SFAM_UserByName(selected) or nil
      local rows = sfam_compiled_online_rows(self) or {}
      local online = #rows
      local favOnline = 0
      for _, row in ipairs(rows) do
        if row and row.favorite then favOnline = favOnline + 1 end
      end
      local notices = 0
      if self.SFN_GetNoticeRows then notices = #(self:SFN_GetNoticeRows() or {}) end
      local summary = tostring(online) .. " online  |  " .. tostring(favOnline) .. " favorite(s)  |  " .. tostring(notices) .. " notice(s)"
      if f.summary then f.summary:SetText(summary) end

      if u and u.name then
        local cls = tostring(u.className or u.class or u.classFile or "")
        local status = tostring(u.looking or u.status or "Online")
        local zone = tostring(u.zone or "Unknown zone")
        local flags = sfam_role_label(u.sfnRoleFlags or u.flags, u.role)
        local level = tostring(u.level or "?")
        if f.modeLabel then f.modeLabel:SetText("Selected Player") end
        if f.line1 then f.line1:SetText(sfam_short(u.name, 18) .. "  |  " .. sfam_short(cls, 11) .. "  |  " .. sfam_short(status, 12)); f.line1:Show() end
        if f.line2 then f.line2:SetText("Level " .. level .. "  |  Role: " .. flags); f.line2:Show() end
        if f.line3 then f.line3:SetText("Zone: " .. sfam_short(zone, 34)); f.line3:Show() end
      else
        local activity = nil
        local n = BronzeLFG_DB and BronzeLFG_DB.signalFireNetwork or nil
        local feed = n and n.favoriteActivity or nil
        if feed and feed[1] then activity = feed[1] end
        if f.modeLabel then f.modeLabel:SetText("Favorite Activity") end
        if activity then
          local age = math.max(0, sfam_time() - (tonumber(activity.created) or sfam_time()))
          local ageText = age < 60 and (tostring(age) .. "s ago") or (age < 3600 and (tostring(math.floor(age/60)) .. "m ago") or (tostring(math.floor(age/3600)) .. "h ago"))
          if f.line1 then f.line1:SetText(sfam_short(activity.title or "Favorite activity", 44)); f.line1:Show() end
          if f.line2 then f.line2:SetText(sfam_short(activity.body or "", 48)); f.line2:Show() end
          if f.line3 then f.line3:SetText("Open Full Roster for player actions."); f.line3:Show() end
        else
          if f.line1 then f.line1:SetText("No favorite activity yet."); f.line1:Show() end
          if f.line2 then f.line2:SetText("Favorite players from the roster to watch them."); f.line2:Show() end
          if f.line3 then f.line3:SetText("Use View Full Roster above for visible action buttons."); f.line3:Show() end
        end
      end
    end

    function BLFG:SFAM_EnhanceNetworkRows()
      if not self.sfnUserRows then return end
      for _, row in ipairs(self.sfnUserRows) do
        if row and not row.sfamBadges then
          row.sfamBadges = true
          row.sfamDot = row:CreateTexture(nil, "OVERLAY")
          row.sfamDot:SetTexture("Interface\\Buttons\\WHITE8X8")
          row.sfamDot:SetWidth(8); row.sfamDot:SetHeight(8); row.sfamDot:SetPoint("LEFT", row, "LEFT", 7, 0)
          row.sfamDot:SetVertexColor(.15, 1, .25, .95)
          if row.name then row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row, "LEFT", 21, 0); row.name:SetWidth(92); row.name:SetJustifyH("LEFT") end
          if row.class then row.class:ClearAllPoints(); row.class:SetPoint("LEFT", row, "LEFT", 120, 0); row.class:SetWidth(64); row.class:SetJustifyH("LEFT") end
          if row.status then row.status:ClearAllPoints(); row.status:SetPoint("LEFT", row, "LEFT", 190, 0); row.status:SetWidth(54); row.status:SetJustifyH("LEFT") end
          row.sfamRoleBadge = sfam_font(row, "", 8, 1, .82, 0)
          row.sfamRoleBadge:SetPoint("LEFT", row, "LEFT", 249, 0)
          row.sfamRoleBadge:SetWidth(24); row.sfamRoleBadge:SetJustifyH("CENTER")
          if row.zone then row.zone:ClearAllPoints(); row.zone:SetPoint("LEFT", row, "LEFT", 279, 0); row.zone:SetWidth(86); row.zone:SetJustifyH("LEFT") end
          for _, fs in ipairs({row.name, row.class, row.status, row.zone, row.sfamRoleBadge}) do
            if fs and fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
            if fs and fs.SetWordWrap then fs:SetWordWrap(false) end
          end
        end
        if row and row.sfnName and row.sfamDot then
          row.sfamDot:Show()
          local u = self:SFAM_UserByName(row.sfnName) or {}
          local st = string.lower(tostring(u.looking or u.status or "online"))
          if string.find(st, "not") or string.find(st, "busy") then row.sfamDot:SetVertexColor(.9, .25, .15, .95)
          elseif string.find(st, "looking") then row.sfamDot:SetVertexColor(.18, .65, 1, .95)
          else row.sfamDot:SetVertexColor(.15, 1, .25, .95) end
          if row.zone and row.zone.GetText then row.zone:SetText(sfam_short(row.zone:GetText() or "", 12)) end
          if row.status and row.status.GetText then row.status:SetText(sfam_short(row.status:GetText() or "", 9)) end
          if row.sfamRoleBadge then row.sfamRoleBadge:SetText(sfam_role_label(u.sfnRoleFlags or u.flags, u.role)) end
          if row.class then local r,g,b = sfam_class_color(u.classFile or u.class); row.class:SetTextColor(r,g,b) end
          sfam_tooltip(row, "SignalFire user", "Left-click selects. Right-click opens whisper, invite, friend, who, and favorite actions.", "Shift-click whispers. Ctrl-click invites.")
        elseif row and row.sfamDot then
          row.sfamDot:Hide()
          if row.sfamRoleBadge then row.sfamRoleBadge:SetText("") end
        end
      end
    end

    function BLFG:SFAM_BuildCreatePreview()
      if not self.create or self.sfamCreatePreview then return end
      local p = self.create
      local box = CreateFrame("Frame", nil, p)
      self.sfamCreatePreview = box
      box:SetWidth(250); box:SetHeight(112)
      -- Move the preview below the loot row, beside the notes field, so it no longer
      -- covers the Loot Method dropdown.
      if self.noteBox and self.noteBox.SetWidth then
        self.noteBox:SetWidth(380)
        box:SetPoint("TOPLEFT", self.noteBox, "TOPRIGHT", 18, 0)
      else
        box:SetPoint("TOPRIGHT", p, "TOPRIGHT", -16, -316)
      end
      box:SetFrameLevel((p:GetFrameLevel() or 1) + 7)
      sfam_backdrop(box, .92)
      box.title = sfam_font(box, "Posting Preview", 13, 1, .75, 0); box.title:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -12)
      box.text = sfam_font(box, "", 9, .92, .92, .92); box.text:SetPoint("TOPLEFT", box, "TOPLEFT", 14, -34); box.text:SetWidth(222); box.text:SetJustifyH("LEFT")
      box.hint = sfam_font(box, "Updates as you edit.", 8, .55, .85, 1); box.hint:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 14, 8)

      -- The early icon experiment was too busy, so do not place contextual icons beside fields.
      if self.sfamTypeIcon then self.sfamTypeIcon:Hide() end
      if self.sfamActivityIcon then self.sfamActivityIcon:Hide() end

      sfam_tooltip(box, "Posting Preview", "Shows the listing other players will understand from your selected activity, difficulty, roles, loot, and notes.")
      sfam_tooltip(self.minIlvlBox, "Minimum item level", "Optional. Leave blank if you do not want to require an item level.")
      sfam_tooltip(self.maxBox, "Maximum members", "SignalFire will publish this as the intended group size.")
      sfam_tooltip(self.noteBox, "Listing note", "Add short context such as run goal, requirements, or what you still need.")
    end

    function BLFG:SFAM_UpdateCreatePreview()
      if not self.sfamCreatePreview then return end
      local t = sfam_dd_text(self.typeDrop)
      local activity = sfam_dd_text(self.activityDrop)
      local specific = sfam_dd_text(self.specificDungeonDrop)
      local diff = sfam_dd_text(self.diffDrop)
      local dungeonMode = (t == "Dungeon" or t == "Mythic+")
        and BLFG_DungeonListForMode and BLFG_DungeonListForMode(activity) or nil
      local shownActivity = (dungeonMode and specific and specific ~= "" and specific ~= "Select Dungeon")
        and specific or activity
      local roles = {}
      if self.needTank and self.needTank:GetChecked() then table.insert(roles, "Tank") end
      if self.needHealer and self.needHealer:GetChecked() then table.insert(roles, "Healer") end
      if self.needDPS and self.needDPS:GetChecked() then table.insert(roles, "DPS") end
      if #roles == 0 then table.insert(roles, "Flexible") end
      local voice = sfam_dd_text(self.voiceDrop); if voice == "" then voice = "None" end
      local loot = sfam_dd_text(self.lootDrop); if loot == "" then loot = "Group Loot" end
      local note = self.noteBox and self.noteBox:GetText() or ""
      local line = "|cffffcc00" .. sfam_short((shownActivity ~= "" and shownActivity or "Choose an activity"), 28) .. "|r"
      if diff and diff ~= "" then line = line .. " - " .. diff end
      line = line .. "\nNeed: " .. table.concat(roles, "/")
      line = line .. "\nVoice: " .. sfam_short(voice, 12) .. "  |  Loot: " .. sfam_short(loot, 13)
      if note and note ~= "" then line = line .. "\nNote: " .. sfam_short(note, 36) end
      self.sfamCreatePreview.text:SetText(line)
      if self.sfamTypeIcon then self.sfamTypeIcon:Hide() end
      if self.sfamActivityIcon then self.sfamActivityIcon:Hide() end
    end

    function BLFG:SFAM_HookCreateInputs()
      local function upd() if BLFG.SFAM_UpdateCreatePreview then BLFG:SFAM_UpdateCreatePreview() end end
      local inputs = { self.minIlvlBox, self.maxBox, self.noteBox, self.keyBox }
      for _, e in ipairs(inputs) do
        if e and not e.sfamPreviewHooked then
          e.sfamPreviewHooked = true
          local old = e:GetScript("OnTextChanged")
          e:SetScript("OnTextChanged", function(self, ...) if old then old(self, ...) end; upd() end)
        end
      end
      for _, c in ipairs({ self.needTank, self.needHealer, self.needDPS }) do
        if c and not c.sfamPreviewHooked then
          c.sfamPreviewHooked = true
          local old = c:GetScript("OnClick")
          c:SetScript("OnClick", function(self, ...) if old then old(self, ...) end; upd() end)
        end
      end

    end

    function BLFG:SFAM_AddPolishOptions()
      if not self.optionsPanel or self.sfamPolishButton then return end
      sfam_ensure_options()
      local p = self.optionsPanel
      local open = sfam_button(p, "Polish Settings", 130, 26)
      self.sfamPolishButton = open
      open:SetPoint("TOPRIGHT", p, "TOPRIGHT", -148, -4)
      sfam_tooltip(open, "Appearance & Polish", "Open the SignalFire polish options as a full Options sub-page. Press ESC or Back to close it.")

      local function buildPanel()
        if self.sfamPolishPanel then return self.sfamPolishPanel end
        local name = "SignalFirePolishSettingsPanel"
        local f = CreateFrame("Frame", name, p)
        self.sfamPolishPanel = f
        f:SetAllPoints(p)
        f:SetFrameLevel(((p.GetFrameLevel and p:GetFrameLevel()) or 1) + 120)
        f:SetToplevel(true)
        f:EnableMouse(true)
        sfam_backdrop(f, .985)
        sfam_register_escape_frame(f, name)
        f:SetScript("OnShow", function(self)
          sfam_raise_children(self, ((self.GetFrameLevel and self:GetFrameLevel()) or 1) + 10)
        end)
        f:Hide()

        local title = sfam_font(f, "Appearance & Polish", 18, 1, .75, 0)
        title:SetPoint("TOP", f, "TOP", 0, -28)
        local note = sfam_font(f, "These settings auto-save. This page replaces the crowded popup so the options are readable and clickable.", 10, .82, .9, 1)
        note:SetPoint("TOP", title, "BOTTOM", 0, -12)
        note:SetWidth(620); note:SetJustifyH("CENTER")

        local panel = CreateFrame("Frame", nil, f)
        panel:SetWidth(620); panel:SetHeight(250)
        panel:SetPoint("TOP", f, "TOP", 0, -88)
        panel:SetFrameLevel(f:GetFrameLevel() + 5)
        sfam_flat(panel, .82)
        panel:EnableMouse(true)

        local function check(key, label, body, y)
          local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
          cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 26, y)
          cb:SetFrameLevel(panel:GetFrameLevel() + 10)
          cb.text = sfam_font(panel, label, 11, 1, 1, 1)
          cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
          cb.body = sfam_font(panel, body or "", 9, .75, .75, .75)
          cb.body:SetPoint("TOPLEFT", cb.text, "BOTTOMLEFT", 0, -2)
          cb.body:SetWidth(520); cb.body:SetJustifyH("LEFT")
          cb:SetScript("OnClick", function(self)
            local o = sfam_ensure_options(); o[key] = self:GetChecked() and true or false
            if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
            if BLFG.SFAM_UpdateBeaconPanel then BLFG:SFAM_UpdateBeaconPanel() end
            if BLFG.SFAM_UpdateCreatePreview then BLFG:SFAM_UpdateCreatePreview() end
          end)
          f[key] = cb
          return cb
        end

        check("pulseEffects", "Subtle pulse effects", "Soft row, tab, and minimap pulses for new activity. No sparkly nonsense.", -24)
        check("tooltips", "Tooltips", "Helpful hover hints on tabs, rows, buttons, and fields.", -78)
        check("beaconEnabled", "SignalFire Beacon", "Selected-user details and quick actions on the Network tab.", -132)
        check("loginSummaryToast", "Login summary toast", "A short ready message. It avoids early online counts while the roster is still compiling.", -186)

        local back = sfam_button(f, "Back to Options", 140, 28)
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
        local o = sfam_ensure_options()
        if f.pulseEffects then f.pulseEffects:SetChecked(o.pulseEffects ~= false) end
        if f.tooltips then f.tooltips:SetChecked(o.tooltips ~= false) end
        if f.beaconEnabled then f.beaconEnabled:SetChecked(o.beaconEnabled ~= false) end
        if f.loginSummaryToast then f.loginSummaryToast:SetChecked(o.loginSummaryToast ~= false) end
        sfam_raise_children(f, ((f.GetFrameLevel and f:GetFrameLevel()) or 1) + 10)
        return f
      end

      open:SetScript("OnClick", function()
        local f = refreshPanel()
        f:Show()
      end)
    end

    function BLFG:SFAM_InstallGeneralTooltips()
      self:SFAM_FindSideButtons()
      if self.sfamSideButtons then
        sfam_tooltip(self.sfamSideButtons["Browse"], "Browse", "Find active SignalFire listings.")
        sfam_tooltip(self.sfamSideButtons["Create Listing"], "Create Listing", "Create a group listing and broadcast it to the SignalFire network.")
        sfam_tooltip(self.sfamSideButtons["Profile"], "Profile", "Set the role, spec, item level, and whisper template sent when you apply.")
        sfam_tooltip(self.sfamSideButtons["Applicants"], "Applicants", "Review players who applied to your active listing.")
        sfam_tooltip(self.sfamSideButtons["Public Groups"], "Public Groups", "Groups detected from chat and SignalFire activity.")
        sfam_tooltip(self.sfamSideButtons["Guild Browser"], "Guild Browser", "Find guilds and recruitment listings.")
        sfam_tooltip(self.sfamSideButtons["Invasions"], "Invasions", "See invasion groups and assist options.")
        sfam_tooltip(self.sfamSideButtons["My Listing"], "My Listing", "Manage, refresh, or cancel your current listing.")
        sfam_tooltip(self.sfamSideButtons["Options"], "Options", "Adjust SignalFire behavior, alerts, and polish settings.")
        sfam_tooltip(self.sfamSideButtons["Network"], "Network", "Online SignalFire users, notices, favorites, and Beacon actions.")
      end
      if self.mm then sfam_tooltip(self.mm, "SignalFire", "Left-click opens SignalFire. Right-click opens your profile. Drag to move if unlocked.") end
    end

    -- Hooks ----------------------------------------------------------------------
    local SFAM_OldBuildSFNetworkPanel = BLFG.BuildSFNetworkPanel
    function BLFG:BuildSFNetworkPanel(...)
      local r = SFAM_OldBuildSFNetworkPanel and SFAM_OldBuildSFNetworkPanel(self, ...)
      self:SFAM_BuildBeaconPanel()
      self:SFAM_EnhanceNetworkRows()
      self:SFAM_UpdateBeaconPanel()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldRefreshSFNetwork = BLFG.RefreshSFNetwork
    function BLFG:RefreshSFNetwork(...)
      local beforeSelected = self.selectedSFNUser
      local r = SFAM_OldRefreshSFNetwork and SFAM_OldRefreshSFNetwork(self, ...)
      if beforeSelected and not self.selectedSFNUser then self.selectedSFNUser = beforeSelected end
      self:SFAM_EnhanceNetworkRows()
      self:SFAM_UpdateBeaconPanel()

      -- Favorite online alerts are handled by SignalFireFavoriteAlerts.lua in v1.3.8+.
      -- Keep the old lightweight toast only if that module is not installed.
      if not self.SFN138_FavoriteAlertsInstalled then
        local current = {}
        local favorites = {}
        for _, u in ipairs(sfam_compiled_online_rows(self) or {}) do
          local n = tostring(u.name or "")
          if n ~= "" then
            current[n] = true
            if u.favorite then favorites[n] = u end
          end
        end
        self.sfamSeenOnline = self.sfamSeenOnline or {}
        if self.sfamOnlineInitialized then
          for n, u in pairs(favorites) do
            if not self.sfamSeenOnline[n] and n ~= sfam_player() then
              self:SFAM_ShowToast("Favorite online", n .. " is now online in " .. tostring(u.zone or "the world") .. ".", "Interface\\Icons\\INV_Misc_GroupLooking", 5)
              self:SFAM_MarkRelevant("Favorite online", 7)
            end
          end
        else
          self.sfamOnlineInitialized = true
        end
        self.sfamSeenOnline = current
      end

      local notices = self.SFN_GetNoticeRows and self:SFN_GetNoticeRows() or {}
      local newest = ""
      if notices[1] then newest = tostring(notices[1].id or "") end
      if self.sfamNoticeInitialized and newest ~= "" and newest ~= self.sfamNewestNotice then
        self:SFAM_PulseSideButton("Network", 8)
        self:SFAM_MarkRelevant("Notice update", 8)
      elseif not self.sfamNoticeInitialized then
        self.sfamNoticeInitialized = true
      end
      self.sfamNewestNotice = newest
      return r
    end

    local SFAM_OldBuildCreate = BLFG.BuildCreate
    function BLFG:BuildCreate(...)
      local r = SFAM_OldBuildCreate and SFAM_OldBuildCreate(self, ...)
      self:SFAM_BuildCreatePreview()
      self:SFAM_HookCreateInputs()
      self:SFAM_UpdateCreatePreview()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldUpdateCreateControls = BLFG.UpdateCreateControls
    function BLFG:UpdateCreateControls(...)
      local r = SFAM_OldUpdateCreateControls and SFAM_OldUpdateCreateControls(self, ...)
      self:SFAM_BuildCreatePreview()
      self:SFAM_HookCreateInputs()
      self:SFAM_UpdateCreatePreview()
      return r
    end

    local SFAM_OldShowCreate = BLFG.ShowCreate
    function BLFG:ShowCreate(...)
      local r = SFAM_OldShowCreate and SFAM_OldShowCreate(self, ...)
      self:SFAM_BuildCreatePreview()
      self:SFAM_HookCreateInputs()
      self:SFAM_UpdateCreatePreview()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldBuildOptions = BLFG.BuildOptions
    function BLFG:BuildOptions(...)
      local r = SFAM_OldBuildOptions and SFAM_OldBuildOptions(self, ...)
      self:SFAM_AddPolishOptions()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldShowOptions = BLFG.ShowOptions
    function BLFG:ShowOptions(...)
      local r = SFAM_OldShowOptions and SFAM_OldShowOptions(self, ...)
      self:SFAM_AddPolishOptions()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldBuildMinimap = BLFG.BuildMinimap
    function BLFG:BuildMinimap(...)
      local r = SFAM_OldBuildMinimap and SFAM_OldBuildMinimap(self, ...)
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    local SFAM_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
    function BLFG:RefreshPublicGroups(...)
      local r = SFAM_OldRefreshPublicGroups and SFAM_OldRefreshPublicGroups(self, ...)
      self.sfamSeenPublic = self.sfamSeenPublic or {}
      if self.publicRows then
        for _, row in ipairs(self.publicRows) do
          if row and row.key then
            local key = tostring(row.key)
            if self.sfamPublicInitialized and not self.sfamSeenPublic[key] then
              sfam_pulse(row, 5, .25, .65, 1, .22)
              self:SFAM_MarkRelevant("New group listing", 5)
            end
            self.sfamSeenPublic[key] = true
          end
        end
      end
      self.sfamPublicInitialized = true
      return r
    end

    local SFAM_OldRefreshApplicants = BLFG.RefreshApplicants
    function BLFG:RefreshApplicants(...)
      local r = SFAM_OldRefreshApplicants and SFAM_OldRefreshApplicants(self, ...)
      self.sfamSeenApplicants = self.sfamSeenApplicants or {}
      if self.appRows then
        for _, row in ipairs(self.appRows) do
          if row and row.key then
            local key = tostring(row.key)
            if self.sfamApplicantsInitialized and not self.sfamSeenApplicants[key] then
              sfam_pulse(row, 5, 1, .55, .12, .28)
              self:SFAM_MarkRelevant("New applicant", 7)
            end
            self.sfamSeenApplicants[key] = true
            sfam_tooltip(row, "Applicant", "Left-click selects this applicant. Use the detail panel to accept, decline, or whisper.")
          end
        end
      end
      self.sfamApplicantsInitialized = true
      return r
    end

    local SFAM_OldCreateUI = BLFG.CreateUI
    function BLFG:CreateUI(...)
      local r = SFAM_OldCreateUI and SFAM_OldCreateUI(self, ...)
      self:SFAM_FindSideButtons()
      self:SFAM_InstallGeneralTooltips()
      return r
    end

    -- Login summary, delayed so the addon has time to build/cache its first state.
    local sfamLogin = CreateFrame("Frame")
    sfamLogin:RegisterEvent("PLAYER_LOGIN")
    sfamLogin:SetScript("OnEvent", function()
      sfam_ensure_options()
      sfamLogin.waitUntil = sfam_now() + 8
      sfamLogin:SetScript("OnUpdate", function(self)
        if not self.waitUntil or sfam_now() < self.waitUntil then return end
        self:SetScript("OnUpdate", nil)
        if not sfam_enabled("loginSummaryToast") then return end
        if BLFG.SFN_SendStatus then BLFG:SFN_SendStatus() end
        if BLFG.SendPresence then BLFG:SendPresence() end
        local notices = 0
        if BLFG.SFN_GetNoticeRows then notices = #(BLFG:SFN_GetNoticeRows() or {}) end
        local noticeText = tostring(notices) .. " notice(s)"
        BLFG:SFAM_ShowToast("SignalFire ready", "Network roster compiling  |  " .. noticeText, "Interface\\Icons\\Spell_Fire_FlameBolt", 5)
      end)
    end)

    sfam_ensure_options()

    -- Keep the polish dialog from lingering when changing SignalFire tabs.
    local SFAM_OldHidePanels = BLFG.HidePanels
    function BLFG:HidePanels(...)
      local r = SFAM_OldHidePanels and SFAM_OldHidePanels(self, ...)
      if self.sfamPolishPanel then self.sfamPolishPanel:Hide() end
      return r
    end
  until true
end

-- Compatibility
do
  repeat
    local SF_VERSION = _G.SignalFire_VERSION or "1.4.23"

    local function cleanAddonText(msg)
      if type(msg) ~= "string" then return msg end
      msg = string.gsub(msg, "BronzeLFG", "SignalFire")
      msg = string.gsub(msg, "BronzeNet", "SignalFire Network")
      msg = string.gsub(msg, "Bronzebeard", "Triumvirate")
      msg = string.gsub(msg, "SignalFire Network Network", "SignalFire Network")
      msg = string.gsub(msg, "v5%.7%.0%-beta1d[%w%-%.]*", "v" .. SF_VERSION)
      return msg
    end

    local function SFPrint(msg)
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire>|r " .. tostring(cleanAddonText(msg) or "")) end
    end

    local function installChatBrandingFilter()
      -- Never hook DEFAULT_CHAT_FRAME:AddMessage globally.
      -- Player chat must remain untouched; only SignalFire-generated messages call cleanAddonText directly.
    end

    local function cleanVisibleString(t)
      if type(t) ~= "string" or t == "" then return t end
      local nt = t
      nt = string.gsub(nt, "BronzeLFG", "SignalFire")
      nt = string.gsub(nt, "BronzeNet", "SignalFire Network")
      nt = string.gsub(nt, "Bronzebeard", "Triumvirate")
      nt = string.gsub(nt, "SignalFire Network Network", "SignalFire Network")
      -- Any visible 5.7 beta version line, including suffix spam, becomes the exact current skin version.
      -- This intentionally collapses strings like v5.7.0-beta1d-sf11-sf11-sf11 to one clean value.
      nt = string.gsub(nt, "v5%.7%.0%-beta1d[%w%-%.]*", "v" .. SF_VERSION)
      return nt
    end

    local function installTooltipBrandingFilter()
      -- Do not hook GameTooltip globally. Addon UI text is branded directly instead.
    end

    local function replaceVisibleText(frame)
      if not frame or not frame.GetRegions then return end
      local regions = { frame:GetRegions() }
      for _, r in ipairs(regions) do
        if r and r.GetText and r.SetText then
          local t = r:GetText()
          local nt = cleanVisibleString(t)
          if nt ~= t then r:SetText(nt) end
        end
      end
    end

    local function recursiveSkin(frame, depth)
      if not frame or depth > 8 then return end
      replaceVisibleText(frame)
      local kids = { frame:GetChildren() }
      for _, child in ipairs(kids) do recursiveSkin(child, depth + 1) end
    end

    local function setChildrenAbove(parent, frame)
      if not parent or not frame then return end
      local base = parent.GetFrameLevel and parent:GetFrameLevel() or 1
      local kids = { frame:GetChildren() }
      for _, child in ipairs(kids) do
        if child and child.SetFrameLevel and child ~= parent.SignalFireDragHandle and child ~= parent.SignalFireCloseButton then
          local cur = child.GetFrameLevel and child:GetFrameLevel() or 0
          if cur <= base then child:SetFrameLevel(base + 5) end
        end
        setChildrenAbove(parent, child)
      end
    end

    local function ensureCloseButton()
      local f = _G.BronzeLFGFrame
      if not f then return end
      if not f.SignalFireCloseButton then
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.SignalFireCloseButton = close
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        close:SetScript("OnClick", function() f:Hide() end)
      end
      local close = f.SignalFireCloseButton
      if close then
        close:EnableMouse(true)
        close:SetFrameStrata(f:GetFrameStrata() or "HIGH")
        close:SetFrameLevel((f:GetFrameLevel() or 50) + 300)
        close:Show()
      end
    end

    local function makeClickSafe()
      local f = _G.BronzeLFGFrame
      if not f then return false end
      f:EnableMouse(false)
      f:SetToplevel(true)
      f:SetFrameStrata("HIGH")
      f:SetFrameLevel(50)
      if not f._sfChildrenAboveApplied then
        setChildrenAbove(f, f)
        f._sfChildrenAboveApplied = true
      end
      if not f.SignalFireDragHandle then
        local drag = CreateFrame("Frame", nil, f)
        f.SignalFireDragHandle = drag
        drag:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -36, 0)
        drag:SetHeight(42)
        drag:EnableMouse(true)
        drag:SetFrameLevel((f:GetFrameLevel() or 50) + 100)
        drag:RegisterForDrag("LeftButton")
        drag:SetScript("OnDragStart", function() f:StartMoving() end)
        drag:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
      end
      ensureCloseButton()
      return true
    end

    local function hookPostRefreshBranding_DISABLED()
      local B = _G.BronzeLFG
      if not B or B.SignalFirePostRefreshBrandingHooked then return end
      B.SignalFirePostRefreshBrandingHooked = true
      local names = {
        "RefreshPublicGroups", "RefreshGuildBrowser", "RefreshOnlinePanel",
        "ShowPublicGroups", "ShowGuildBrowser", "ToggleOnlinePanel",
        "RefreshBrowse", "BuildGuildBrowser", "BuildPublicGroups"
      }
      for _, name in ipairs(names) do
        local old = B[name]
        if type(old) == "function" then
          B[name] = function(self, ...)
            local a,b,c,d,e = old(self, ...)
            if self and self.frame then recursiveSkin(self.frame, 0) end
            ensureCloseButton()
            return a,b,c,d,e
          end
        end
      end
    end

    local function applySignalFireSkin()
      installChatBrandingFilter()
      installTooltipBrandingFilter()
      local B = _G.BronzeLFG
      if B then
        -- Direct-source branding is used in sf23; no recursive repaint hook.
        B.version = SF_VERSION
        if BronzeLFG_ApplyVisibleVersion then
          BronzeLFG_ApplyVisibleVersion()
        else
          if B.titleText and B.titleText.SetText then B.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or ("SignalFire v" .. tostring(SF_VERSION) .. " (Beta)")) end
          if B.versionText then
            if B.versionText.SetText then B.versionText:SetText("") end
            if B.versionText.SetAlpha then B.versionText:SetAlpha(0) end
            if B.versionText.Hide then B.versionText:Hide() end
          end
        end
        -- Do not recursively repaint the UI; it causes the BronzeNet/SignalFire flicker and masks native colored rows.
      end
      makeClickSafe()
      ensureCloseButton()
    end

    local function tableCount(t)
      local n = 0
      if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
      return n
    end

    local function publicRows()
      local B = _G.BronzeLFG
      return (B and B.publicGroups) or {}
    end

    local function guildRows()
      local B = _G.BronzeLFG
      if not B then return 0 end
      if B.GetGuildRows then
        local ok, list = pcall(function() return B:GetGuildRows() end)
        if ok and type(list) == "table" then return #list end
      end
      return tableCount(B.chatGuildListings) + tableCount(B.bronzeNetGuilds) + tableCount(B.guilds)
    end

    local function selectedGuildName()
      local B = _G.BronzeLFG
      if not B then return "nil" end
      if type(B.selectedGuild) == "table" then return tostring(B.selectedGuild.name or "table") end
      return tostring(B.selectedGuild or "nil")
    end


    local function sfcompat_profile_id()
      local B = _G.BronzeLFG
      if B and B.SF143_GetProfileId then return B:SF143_GetProfileId() end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "Triumvirate")
      end
      return "Triumvirate"
    end

    local function sfcompat_ensure_modules_db()
      BronzeLFG_DB = BronzeLFG_DB or {}
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}
      return BronzeLFG_DB.options.modules
    end

    local function sfcompat_invasion_default()
      local B = _G.BronzeLFG
      if B and B.SFModuleDefaultEnabled then return B:SFModuleDefaultEnabled("invasions") end
      return sfcompat_profile_id() ~= "Ascension"
    end

    local function sfcompat_invasion_enabled()
      local B = _G.BronzeLFG
      if B and B.SFModuleIsEnabled then return B:SFModuleIsEnabled("invasions") end
      local mods = sfcompat_ensure_modules_db()
      if mods.invasions ~= nil then return mods.invasions == true end
      return sfcompat_invasion_default()
    end

    local function sfcompat_apply_modules()
      local B = _G.BronzeLFG
      if B and B.SFModulesApply then B:SFModulesApply() end
      if SignalFireModules and SignalFireModules.ApplyEventInvasionGate then SignalFireModules.ApplyEventInvasionGate() end
    end

    local function sfcompat_set_invasions(value)
      local B = _G.BronzeLFG
      if B and B.SFModuleSetEnabled then
        B:SFModuleSetEnabled("invasions", value == true)
      else
        local mods = sfcompat_ensure_modules_db()
        mods.invasions = value == true
        sfcompat_apply_modules()
      end
    end

    local function sfcompat_default_invasions()
      local B = _G.BronzeLFG
      if B and B.SFModuleUseProfileDefault then
        B:SFModuleUseProfileDefault("invasions")
      else
        local mods = sfcompat_ensure_modules_db()
        mods.invasions = nil
        sfcompat_apply_modules()
      end
    end

    local function sfcompat_modules_status_line()
      local B = _G.BronzeLFG
      if B and B.SFModulesStatusLine then return B:SFModulesStatusLine() end
      local state = sfcompat_invasion_enabled() and "on" or "off"
      local def = sfcompat_invasion_default() and "default on" or "default off"
      return "Invasions=" .. state .. " (" .. def .. ")"
    end

    local function sfcompat_module_disabled_msg()
      SFPrint("Invasions module is disabled for " .. tostring(sfcompat_profile_id()) .. ". Use /sf invasions on or Options > Modules to enable it.")
    end

    local function sfcompat_slash_debug()
      local sf = SlashCmdList and SlashCmdList["SIGNALFIRE"] or nil
      local blfg = SlashCmdList and SlashCmdList["BRONZELFG"] or nil
      local sfmods = SlashCmdList and SlashCmdList["SIGNALFIREMODULES"] or nil
      local h1 = hash_SlashCmdList and (hash_SlashCmdList["/sf"] or hash_SlashCmdList["/SF"]) or nil
      local h2 = hash_SlashCmdList and (hash_SlashCmdList["/sfm"] or hash_SlashCmdList["/SFM"]) or nil
      SFPrint("slashdebug: modules=" .. tostring(SignalFireModules ~= nil) .. " final=" .. tostring(SignalFireSlashFinal ~= nil))
      SFPrint("slashdebug: SIGNALFIRE=" .. tostring(sf) .. " BRONZELFG=" .. tostring(blfg) .. " SFMODULES=" .. tostring(sfmods))
      SFPrint("slashdebug: hash /sf=" .. tostring(h1) .. " /sfm=" .. tostring(h2))
    end

    local function sfcompat_handle_modules_slash(msg)
      local cmd = tostring(msg or "")
      if cmd == "modules" or cmd == "module" or cmd == "mods" or cmd == "mod" then
        SFPrint("Active modules for " .. tostring(sfcompat_profile_id()) .. ": " .. sfcompat_modules_status_line())
        SFPrint("Module commands: /sf invasions on, /sf invasions off, /sf invasions default")
        return true
      elseif cmd == "module invasions" or cmd == "modules invasions" or cmd == "mod invasions" or cmd == "invasions status" then
        SFPrint("Invasions module: " .. (sfcompat_invasion_enabled() and "on" or "off") .. " for " .. tostring(sfcompat_profile_id()) .. ".")
        SFPrint("Use /sf invasions on, /sf invasions off, or /sf invasions default.")
        return true
      elseif cmd == "module invasions on" or cmd == "modules invasions on" or cmd == "mod invasions on" or cmd == "invasions on" then
        sfcompat_set_invasions(true)
        SFPrint("Invasions module enabled.")
        return true
      elseif cmd == "module invasions off" or cmd == "modules invasions off" or cmd == "mod invasions off" or cmd == "invasions off" then
        sfcompat_set_invasions(false)
        SFPrint("Invasions module disabled.")
        return true
      elseif cmd == "module invasions default" or cmd == "modules invasions default" or cmd == "mod invasions default" or cmd == "invasions default" then
        sfcompat_default_invasions()
        SFPrint("Invasions module reset to profile default.")
        return true
      elseif cmd == "slashdebug" or cmd == "slash debug" or cmd == "debug slash" then
        sfcompat_slash_debug()
        return true
      elseif (cmd == "invasion" or cmd == "invasions" or cmd == "inv" or cmd == "invscan" or cmd == "invasionscan" or cmd == "invbeacon" or cmd == "invclear" or cmd == "invdebug" or cmd == "invtarget" or cmd == "invasiontarget" or cmd == "invwhisper" or cmd == "invasionwhisper" or cmd == "invinviteother" or cmd == "invasioninvite") and not sfcompat_invasion_enabled() then
        sfcompat_module_disabled_msg()
        return true
      end
      return false
    end

    local function slash(msg)
      local raw = tostring(msg or "")
      msg = string.lower(raw)
      msg = string.gsub(msg, "^%s+", "")
      msg = string.gsub(msg, "%s+$", "")
      local B = _G.BronzeLFG
      -- 1.4.8: Handle module commands directly in the main /sf owner first.
      -- This avoids the old wrapper chain swallowing /sf modules before the module layer sees it.
      if sfcompat_handle_modules_slash and sfcompat_handle_modules_slash(msg) then return end
      if SignalFireSlashFinal and SignalFireSlashFinal.HandleModuleSlash and SignalFireSlashFinal.HandleModuleSlash(msg) then return end
      if SignalFireModules and SignalFireModules.HandleSlash and SignalFireModules.HandleSlash(msg, nil) then return end
      if msg == "fixclick" then
        applySignalFireSkin(); SFPrint("click-safe pass applied"); return
      elseif msg == "mouse" then
        local f = GetMouseFocus and GetMouseFocus()
        SFPrint("mouse focus=" .. tostring(f and f:GetName() or f)); return
      elseif msg == "version" then
        SFPrint("visible=" .. SF_VERSION .. " engine=" .. tostring(B and B.version or "nil")); return
      elseif msg == "pgcount" then
        local rows = publicRows(); SFPrint("PG rows: " .. tostring(tableCount(rows))); return
      elseif msg == "pgdebug on" then
        if B then B.SignalFirePGDebug = true end; SFPrint("Public Groups debug: ON"); return
      elseif msg == "pgdebug off" then
        if B then B.SignalFirePGDebug = false end; SFPrint("Public Groups debug: OFF"); return
      elseif msg == "testsay on" then
        if B then B.SignalFireTestSay = true end; SFPrint("/say test mode: ON"); return
      elseif msg == "testsay off" then
        if B then B.SignalFireTestSay = false end; SFPrint("/say test mode: OFF"); return
      elseif msg == "guildaudit" or msg == "sfguildaudit" then
        SFPrint("guildRows=" .. tostring(guildRows()) .. " selected=" .. selectedGuildName()); return
      elseif msg == "invscan" or msg == "invasionscan" then
        if B and B.CreateUI and B.QueueInvasionWhoScan then B:CreateUI(); B:QueueInvasionWhoScan(true); return end
      elseif msg == "invtarget" or msg == "invasiontarget" then
        if B and B.CreateUI and B.AddCurrentInvasionTarget then B:CreateUI(); B:AddCurrentInvasionTarget(); return end
      elseif msg == "invwhisper" or msg == "invasionwhisper" then
        if B and B.WhisperSelectedInvasionOtherPlayer then B:WhisperSelectedInvasionOtherPlayer(); return end
      elseif msg == "invinviteother" or msg == "invasioninvite" then
        if B and B.InviteSelectedInvasionOtherPlayer then B:InviteSelectedInvasionOtherPlayer(); return end
      elseif msg == "online" then
        if B and B.Show and B.ShowPublicGroups and B.ToggleOnlinePanel then
          B:Show(); B:ShowPublicGroups(); B:ToggleOnlinePanel(); return
        end
      elseif msg == "who" then
        if B and B.PrintOnlineUsers then B:PrintOnlineUsers(); return end
      elseif msg == "public" or msg == "groups" then
        if B and B.Show and B.ShowPublicGroups then B:Show(); B:ShowPublicGroups(); return end
      elseif msg == "create" then
        if B and B.Show and B.ShowCreate then B:Show(); B:ShowCreate(); return end
      elseif msg == "profile" then
        if B and B.Show and B.ShowProfile then B:Show(); B:ShowProfile(); return end
      elseif msg == "applicants" then
        if B and B.Show and B.ShowApplicants then B:Show(); B:ShowApplicants(); return end
      elseif msg == "my" or msg == "listing" then
        if B and B.Show and B.ShowMyListing then B:Show(); B:ShowMyListing(); return end
      elseif msg == "guild" or msg == "guilds" then
        if B and B.Show and B.ShowGuildBrowser then B:Show(); B:ShowGuildBrowser(); return end
      elseif msg == "invasions" or msg == "inv" then
        if B and B.Show and B.ShowInvasions then B:Show(); B:ShowInvasions(); return end
      elseif msg == "options" or msg == "settings" then
        if B and B.Show and B.ShowOptions then B:Show(); B:ShowOptions(); return end
      elseif msg == "cancel" then
        if B and B.CancelMyListing then B:CancelMyListing("manual"); return end
      elseif msg == "guildwho" or msg == "whoguilds" then
        if B and B.QueueWhoGuildDiscovery then B:QueueWhoGuildDiscovery(true); return end
      elseif msg == "clearpublic" then
        if B and B.ClearPublicGroups then B:ClearPublicGroups(); return end
      elseif (msg == "announce" or string.sub(msg, 1, 9) == "announce ") then
        if B and B.SFN_HandleSlash and B.SFN_HandleSlash(raw) then return end
      elseif msg == "help" or msg == "commands" then
        SFPrint("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf modules, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic"); return
      elseif msg == "" and B then
        if B.ToggleFrame then B:ToggleFrame() elseif B.Toggle then B:Toggle() end
        applySignalFireSkin(); return
      end
      if B and B.SlashCommand then B:SlashCommand(msg) else SFPrint("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf modules, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic") end
    end

    SLASH_SIGNALFIRE1 = "/sf"
    SLASH_SIGNALFIRE2 = "/sfo"
    SLASH_SIGNALFIRE3 = "/signalfire"
    SlashCmdList["SIGNALFIRE"] = slash
    SLASH_SFCREATE1 = "/sfcreate"
    SlashCmdList["SFCREATE"] = function() slash("create") end
    SLASH_SFPROFILE1 = "/sfprofile"
    SlashCmdList["SFPROFILE"] = function() slash("profile") end
    SLASH_SFGUILDAUDIT1 = "/sfguildaudit"
    SlashCmdList["SFGUILDAUDIT"] = function() slash("guildaudit") end

    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, event, arg1)
      if event == "ADDON_LOADED" and arg1 ~= "SignalFire" and arg1 ~= "BronzeLFG" then return end
      applySignalFireSkin()
    end)
  until true
end
