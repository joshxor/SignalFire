-- SignalFireCompat.lua
-- Cosmetic + click-safe layer over the stable BronzeLFG engine.
-- Internal globals/SavedVariables intentionally remain BronzeLFG/BronzeLFG_DB.

local SF_VERSION = "5.7.19-stalelinkfix"

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
  setChildrenAbove(f, f)
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
    if B.titleText and B.titleText.SetText then B.titleText:SetText("SignalFire") end
    if B.versionText and B.versionText.SetText then B.versionText:SetText("v" .. SF_VERSION) end
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

local function slash(msg)
  msg = string.lower(tostring(msg or ""))
  msg = string.gsub(msg, "^%s+", "")
  msg = string.gsub(msg, "%s+$", "")
  local B = _G.BronzeLFG
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
  elseif msg == "help" or msg == "commands" then
    SFPrint("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic"); return
  elseif msg == "" and B then
    if B.ToggleFrame then B:ToggleFrame() elseif B.Toggle then B:Toggle() end
    applySignalFireSkin(); return
  end
  if B and B.SlashCommand then B:SlashCommand(msg) else SFPrint("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic") end
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
f.elapsed = 0
f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= "SignalFire" and arg1 ~= "BronzeLFG" then return end
  applySignalFireSkin()
end)
f:SetScript("OnUpdate", function(_, elapsed)
  -- sf23: no timed cosmetic repaint. Keep only the close button/click safety alive.
  f.elapsed = (f.elapsed or 0) + elapsed
  if f.elapsed < 2 then return end
  f.elapsed = 0
  makeClickSafe()
  ensureCloseButton()
end)
