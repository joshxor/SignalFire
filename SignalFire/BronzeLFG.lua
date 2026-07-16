
local function BLFG_IsFavorite(name)
  if not name or not BronzeLFGDB or not BronzeLFGDB.favorites then return false end
  local key = tostring(name):lower()
  return BronzeLFGDB.favorites[key] or BronzeLFGDB.favorites[name]
end

local function BLFG_FavPrefix(name)
  return BLFG_IsFavorite(name) and "|cffffd100â˜… |r" or ""
end

-- 4.0.0 Community Edition Source Pass

-- BronzeLFG 3.9.2 Options Layout Repair
-- BronzeNet profiles, right-click options, autosave settings, UI polish.
-- WoW 3.3.5 / Bronzebeard compatible.

local VERSION = SignalFire_VERSION or "1.4.23"
local CHANNEL = "BLFG"
local PREFIX = "BLFG312"

BronzeLFG = {}
local BLFG = BronzeLFG

BronzeLFG_DB = BronzeLFG_DB or {}

local function SFActiveProfile()
  if SignalFireProfiles and SignalFireProfiles.GetActiveProfile then
    return SignalFireProfiles.GetActiveProfile()
  end
  return nil
end

local function SFProfileList(name, fallback)
  local p = SFActiveProfile()
  return (p and p[name]) or fallback or {}
end

local function SFProfileSet(name, fallback)
  local p = SFActiveProfile()
  return (p and p[name]) or fallback or {}
end

BLFG.version = VERSION
BLFG.listings = {}
BLFG.applicants = {}
BLFG.publicGroups = {}
BLFG.selectedPublic = nil
BLFG.publicPage = 1
BLFG.publicRowsPerPage = 8
BLFG.selectedListing = nil
BLFG.selectedApplicant = nil
BLFG.myListing = nil
BLFG.currentTab = "Browse"
BLFG.filter = "All"
BLFG.channelId = nil
BLFG.minimapAngle = tonumber((BronzeLFG_DB.minimap and BronzeLFG_DB.minimap.angle) or BronzeLFG_DB.minimapAngle) or 215
BLFG.minimapHidden = BronzeLFG_DB.minimapHidden or false
BLFG.onlineUsers = {}
BLFG.lastPresence = 0

function BLFG:MarkOptionsDirty()
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.optionsStatus then self.optionsStatus:SetText("Options saved.") end
  self:SaveOptions(false)
end


function BronzeLFG_IsAddonSpam(text)
  local s = tostring(text or "")
  local ls = string.lower(s)

  if string.sub(s, 1, 3) == "LC1" then return true end
  if string.sub(s, 1, 3) == "LC2" then return true end
  if string.sub(s, 1, 3) == "LC3" then return true end

  if string.find(ls, "lc1:conf", 1, true) then return true end
  if string.find(ls, "lc2:conf", 1, true) then return true end
  if string.find(ls, "lc3:conf", 1, true) then return true end
  if string.find(ls, "conf:", 1, true) then return true end

  if string.find(s, "^%u%u%d*:") then return true end
  if string.find(s, "^LC") and string.len(s) > 20 then return true end

  local hasSpace = string.find(s, " ", 1, true)
  if not hasSpace and string.len(s) > 35 then return true end

  return false
end

local DUNGEONS = SFProfileList("dungeons", {})
local RAIDS = SFProfileList("raids", {})
local WORLD_BOSSES = SFProfileList("worldBosses", {"Custom World Boss"})
local ACTIVITY_TYPES = SFProfileList("activityTypes", {"Dungeon", "Raid", "World Boss", "Custom Event"})
local DIFFICULTIES = SFProfileList("difficulties", {"Normal", "Heroic", "Mythic", "Mythic+", "Custom"})
BLFG_BASIC_DUNGEON_DIFFICULTIES = {"Normal", "Heroic"}
BLFG_DUNGEON_DIFFICULTIES = {"Normal", "Heroic", "Mythic+"}
BLFG_RAID_DIFFICULTIES = {"Normal", "Heroic"}
local ROLES = {"Tank", "Healer", "DPS", "Flexible"}
local VOICE = {"None", "Discord", "In-game", "Preferred"}
local LOOT = {"Group Loot", "Master Looter", "Need Before Greed", "Any"}

local CLASS_ICON = {
  PALADIN="Interface\\Icons\\Spell_Holy_HolyBolt",
  WARRIOR="Interface\\Icons\\INV_Sword_27",
  PRIEST="Interface\\Icons\\Spell_Holy_Renew",
  MAGE="Interface\\Icons\\Spell_Frost_FrostBolt02",
  ROGUE="Interface\\Icons\\Ability_BackStab",
  DRUID="Interface\\Icons\\Ability_Druid_Maul",
  HUNTER="Interface\\Icons\\INV_Weapon_Bow_07",
  SHAMAN="Interface\\Icons\\Spell_Nature_BloodLust",
  WARLOCK="Interface\\Icons\\Spell_Shadow_CurseOfTounges",
}

local ROLE_COLOR = {
  Tank="|cff4aa3ff",
  Healer="|cff44ff66",
  DPS="|cffff5555",
  Flexible="|cffffff66",
}

local ROLE_ICON = {
  Tank="Interface\\Icons\\Ability_Defend",
  Healer="Interface\\Icons\\Spell_Holy_FlashHeal",
  DPS="Interface\\Icons\\Ability_DualWield",
  Flexible="Interface\\Icons\\INV_Misc_GroupNeedMore",
}

local function now() return time() end
local function lower(s) return string.lower(tostring(s or "")) end
local function clean(s)
  s = tostring(s or "")
  s = string.gsub(s, "[~|\n\r]", " ")
  return s
end
local function split(s)
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
local function msg(text, r, g, b)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffd8a600SignalFire>|r " .. tostring(text), r or 1, g or .82, b or 0)
  end
end
local function flash(text)
  msg(text, .4, 1, .4)
  if UIErrorsFrame then
    UIErrorsFrame:AddMessage("SignalFire: " .. tostring(text), 1, .82, 0, 1, UIERRORS_HOLD_TIME)
  end
end
local function playerName() return UnitName("player") or "Unknown" end
local function playerLevel() return UnitLevel("player") or 60 end
local function playerClass()
  local unitName, unitFile = "", ""
  if UnitClass then unitName, unitFile = UnitClass("player") end
  local guidName, guidFile = "", ""
  if UnitGUID and GetPlayerInfoByGUID then
    local guid = UnitGUID("player")
    if guid then guidName, guidFile = GetPlayerInfoByGUID(guid) end
  end

  local uiName = ""
  if CharacterClassText and CharacterClassText.GetText then
    uiName = CharacterClassText:GetText() or ""
  end

  local f = (unitFile and unitFile ~= "") and unitFile or guidFile
  local c = (unitName and unitName ~= "") and unitName or ""
  local tokenLike = c == "" or c == f or string.find(c, "^[A-Z_]+$") ~= nil
  if tokenLike and uiName ~= "" then c = uiName end
  if (c == "" or c == f or string.find(c, "^[A-Z_]+$") ~= nil) and f and f ~= "" then
    local upper = string.upper(tostring(f))
    local localized = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[upper])
      or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[upper])
    if localized and localized ~= "" then c = localized end
  end
  if (c == "" or c == f or string.find(c, "^[A-Z_]+$") ~= nil) and guidName and guidName ~= "" and string.find(guidName, "^[A-Z_]+$") == nil then
    c = guidName
  end

  if not c or c == "" then c = "Unknown" end
  if not f or f == "" then f = "UNKNOWN" end
  return c, f
end
local function memberCount()
  local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
  if raid and raid > 0 then return raid end
  return (GetNumPartyMembers and GetNumPartyMembers() or 0) + 1
end
local function getChannel()
  local id = GetChannelName(CHANNEL)
  if id and id > 0 then BLFG.channelId = id; return id end
  return nil
end
local function sendChan(payload)
  local id = getChannel()
  if id then
    SendChatMessage(payload, "CHANNEL", nil, id)
  else
    JoinChannelByName(CHANNEL)
    msg("Joining /" .. CHANNEL .. ". Try again in a moment if needed.")
  end
end
local function ageText(t)
  local d = now() - (tonumber(t) or now())
  if d < 60 then return d .. " sec ago" end
  if d < 3600 then return math.floor(d/60) .. " min ago" end
  return math.floor(d/3600) .. " hr ago"
end
local function normalizeClassFile(file)
  local c = string.upper(tostring(file or ""))
  c = string.gsub(c, "%s+", "")
  c = string.gsub(c, "[^A-Z]", "")
  if c == "DEATHKNIGHT" or c == "DK" then return "DEATHKNIGHT" end
  if c == "PALADIN" then return "PALADIN" end
  if c == "WARRIOR" then return "WARRIOR" end
  if c == "PRIEST" then return "PRIEST" end
  if c == "MAGE" then return "MAGE" end
  if c == "ROGUE" then return "ROGUE" end
  if c == "DRUID" then return "DRUID" end
  if c == "HUNTER" then return "HUNTER" end
  if c == "SHAMAN" then return "SHAMAN" end
  if c == "WARLOCK" then return "WARLOCK" end
  return c
end
local function classIcon(file)
  return CLASS_ICON[normalizeClassFile(file)] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local CLASS_COLOR = {
  WARRIOR="|cffc79c6e", PALADIN="|cfff58cba", HUNTER="|cffabd473", ROGUE="|cfffff569",
  PRIEST="|cffffffff", DEATHKNIGHT="|cffc41f3b", SHAMAN="|cff0070de", MAGE="|cff69ccf0",
  WARLOCK="|cff9482c9", DRUID="|cffff7d0a",
}
local function classColor(file)
  return CLASS_COLOR[normalizeClassFile(file)] or "|cff9fd6ff"
end
local function myGuildName()
  if GetGuildInfo then
    local g = GetGuildInfo("player")
    return g or ""
  end
  return ""
end
local function currentZoneText()
  return (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or ""
end
local function shortRole(role)
  local r = tostring(role or "")
  if r == "Tank" then return "|cff4aa3ffT|r" end
  if r == "Healer" then return "|cff44ff66H|r" end
  if r == "DPS" then return "|cffff5555D|r" end
  if r == "Flexible" then return "|cffffff66F|r" end
  return "-"
end
local function isFriendName(name)
  name = tostring(name or "")
  if name == "" or not GetNumFriends or not GetFriendInfo then return false end
  local n = GetNumFriends() or 0
  for i=1,n do
    local fname = GetFriendInfo(i)
    if fname and string.lower(fname) == string.lower(name) then return true end
  end
  return false
end
local function isPartyOrRaidMember(name)
  name = tostring(name or "")
  if name == "" then return false end
  if UnitInParty and UnitInParty(name) then return true end
  if UnitInRaid and UnitInRaid(name) then return true end
  return false
end
local function decorateOnlineName(u)
  local name = tostring(u.name or "Unknown")
  local prefix = ""
  if u.self then prefix = "|cffffcc00â˜… |r"
  elseif u.favorite then prefix = "|cffffd24aâ˜… |r"
  elseif u.friend then prefix = "|cff44ff66â˜… |r"
  elseif u.groupmate then prefix = "|cff4aa3ffâ—† |r" end
  if u.whoOnly then prefix = "|cff999999/w |r" .. prefix end
  if string.len(name) > 14 then name = string.sub(name, 1, 11) .. "..." end
  return prefix .. classColor(u.classFile) .. name .. "|r"
end
local function roleText(role)
  local r = tostring(role or "Any")
  local icon = ROLE_ICON[r]
  local prefix = icon and ("|T" .. icon .. ":14:14:0:0|t ") or ""
  return prefix .. (ROLE_COLOR[r] or "|cffffffff") .. r .. "|r"
end
local function roleLetter(role)
  local r = tostring(role or "Any")
  local letter = r == "Tank" and "T" or r == "Healer" and "H" or r == "DPS" and "D" or "F"
  return (ROLE_COLOR[r] or "|cffffffff") .. letter .. "|r"
end
local function rolesNeeded(l)
  local t = {}
  if l.needTank == "1" or l.needTank == 1 then table.insert(t, roleText("Tank")) end
  if l.needHealer == "1" or l.needHealer == 1 then table.insert(t, roleText("Healer")) end
  if l.needDPS == "1" or l.needDPS == 1 then table.insert(t, roleText("DPS")) end
  if #t == 0 then return roleText("Flexible") end
  return table.concat(t, "  ")
end

local function rolesNeededShort(l)
  local t = {}
  if l.needTank == "1" or l.needTank == 1 then table.insert(t, roleLetter("Tank")) end
  if l.needHealer == "1" or l.needHealer == 1 then table.insert(t, roleLetter("Healer")) end
  if l.needDPS == "1" or l.needDPS == 1 then table.insert(t, roleLetter("DPS")) end
  if #t == 0 then return roleLetter("Flexible") end
  return table.concat(t, "/")
end

local function compactRoleText(text)
  local raw = tostring(text or "")
  local s = lower(raw)
  if raw == "" or s == "not detected" then return "-" end
  if string.find(raw, "T/H/D", 1, true) then
    return roleLetter("Tank") .. "/" .. roleLetter("Healer") .. "/" .. roleLetter("DPS")
  end
  local t = {}
  if string.find(s, "tank", 1, true) or string.find(raw, ">T<", 1, true) or string.find(raw, "T/", 1, true) then table.insert(t, roleLetter("Tank")) end
  if string.find(s, "heal", 1, true) or string.find(raw, ">H<", 1, true) or string.find(raw, "/H", 1, true) then table.insert(t, roleLetter("Healer")) end
  if string.find(s, "dps", 1, true) or string.find(raw, ">D<", 1, true) or string.find(raw, "/D", 1, true) then table.insert(t, roleLetter("DPS")) end
  if string.find(s, "flex", 1, true) then table.insert(t, roleLetter("Flexible")) end
  if #t == 0 then return "-" end
  return table.concat(t, "/")
end

local function ensureDB()
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {
    role = "DPS",
    itemLevel = "",
    roleType = "",
    discord = false,
    note = "",
  }
  BronzeLFG_DB.options = BronzeLFG_DB.options or {
    autoOpen = false,
    showMinimap = true,
    savePosition = true,
    scale = 1.0,
    publicGroups = true,
    publicExpire = 300,
    publicStrict = true,
    freeLauncher = false,
    notifyEnabled = true,
    notifySound = false,
    notifyHCBB = true,
    notifyKey = true,
    notifyRaid = true,
    notifyGuild = false,
    guildWhoDiscovery = true,
    serverProfile = "Triumvirate",
    invasionAssist = true,
    invasionAllowInvites = false,
    invasionAutoAccept = false,
    notifyEventFilter = "Any Event",
    notifyRaidFilter = "Any Raid",
    notifyKeyFilter = "Any Key",
  }
  if BronzeLFG_DB.options.guildWhoDiscovery == nil then BronzeLFG_DB.options.guildWhoDiscovery = true end
  if BronzeLFG_DB.options.serverProfile == nil then BronzeLFG_DB.options.serverProfile = "Triumvirate" end
  if BronzeLFG_DB.options.invasionAssist == nil then BronzeLFG_DB.options.invasionAssist = true end
  if BronzeLFG_DB.options.invasionAllowInvites == nil then BronzeLFG_DB.options.invasionAllowInvites = false end
  BronzeLFG_DB.options.invasionAutoAccept = false
  BronzeLFG_DB.favorites = BronzeLFG_DB.favorites or {}
  BronzeLFG_DB.favoriteGuilds = BronzeLFG_DB.favoriteGuilds or {}
  BronzeLFG_DB.parserStats = BronzeLFG_DB.parserStats or {}
  BronzeLFG_DB.guildBrowser = BronzeLFG_DB.guildBrowser or {
    selectedGuild = nil,
    focusFilter = nil,
    favoritesOnly = false,
    searchText = "",
  }
  BronzeLFG_DB.publicHiddenTypes = BronzeLFG_DB.publicHiddenTypes or {}
  BronzeLFG_DB.recruitmentCreator = BronzeLFG_DB.recruitmentCreator or {}
  if type(BronzeLFG_DB.minimap) ~= "table" then BronzeLFG_DB.minimap = {} end
  local mm = BronzeLFG_DB.minimap
  local angle = tonumber(mm.angle or BronzeLFG_DB.minimapAngle or BLFG.minimapAngle or 215)
  if not angle or angle ~= angle then angle = 215 end
  mm.angle = ((angle % 360) + 360) % 360
  BronzeLFG_DB.minimapAngle = mm.angle
  BLFG.minimapAngle = mm.angle
  if BronzeLFG_DB.minimapHidden ~= nil and BronzeLFG_DB.options.showMinimap == nil then
    BronzeLFG_DB.options.showMinimap = not BronzeLFG_DB.minimapHidden
  end
  BronzeLFG_DB.minimapHidden = BronzeLFG_DB.options.showMinimap == false
  BLFG.minimapHidden = BronzeLFG_DB.minimapHidden
  local pos = BronzeLFG_DB.launcherPosition
  if type(pos) == "table" then
    pos.point = tostring(pos.point or "CENTER")
    pos.relPoint = tostring(pos.relPoint or "CENTER")
    pos.x = tonumber(pos.x) or 0
    pos.y = tonumber(pos.y) or 0
  else
    BronzeLFG_DB.launcherPosition = nil
  end
  BronzeLFG_DB.create = BronzeLFG_DB.create or {
    type = "Dungeon",
    activity = "Scarlet Monastery - Cathedral",
    difficulty = "Mythic+",
    key = "12",
    minItemLevel = "60",
    maxMembers = "5",
    voice = "None",
    loot = "Group Loot",
    note = "",
  }
end

local function listForType(t)
  if t == "Dungeon" then
    return {
      "Random Dungeon Finder",
      "Random Heroic Dungeon Finder",
      "BC Random Dungeon Finder",
      "Wrath Random Dungeon Finder",
      "Classic Dungeon",
      "TBC Dungeon",
      "Wrath Dungeon",
    }
  end
  if t == "Raid" then return RAIDS end
  if t == "World Boss" then return WORLD_BOSSES end
  return {"Custom Activity"}
end

function BLFG_ActivitySupportsKeyLevel(activity)
  return activity == "Classic Dungeon" or activity == "TBC Dungeon" or activity == "Wrath Dungeon"
end

function BLFG_DungeonListForMode(activity)
  local p = SFActiveProfile and SFActiveProfile() or nil
  if activity == "Classic Dungeon" then return (p and p.classicDungeons) or DUNGEONS end
  if activity == "TBC Dungeon" then return (p and p.tbcDungeons) or DUNGEONS end
  if activity == "Wrath Dungeon" then return (p and p.wrathDungeons) or DUNGEONS end
  return nil
end

function BLFG_ListContainsValue(list, value)
  if not list or not value then return false end
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

function BLFG_DungeonModeForActivity(activity)
  if BLFG_ListContainsValue(BLFG_DungeonListForMode("Classic Dungeon"), activity) then return "Classic Dungeon" end
  if BLFG_ListContainsValue(BLFG_DungeonListForMode("TBC Dungeon"), activity) then return "TBC Dungeon" end
  if BLFG_ListContainsValue(BLFG_DungeonListForMode("Wrath Dungeon"), activity) then return "Wrath Dungeon" end
  return nil
end

function BLFG_DifficultyListForType(typeName)
  if typeName == "Raid" then return BLFG_RAID_DIFFICULTIES end
  if typeName == "Dungeon" then return BLFG_DUNGEON_DIFFICULTIES end
  return DIFFICULTIES
end

function BLFG_CreateDifficultyListFor(typeName, activity)
  if typeName == "Raid" then return BLFG_RAID_DIFFICULTIES end
  if typeName == "Dungeon" then
    if BLFG_ActivitySupportsKeyLevel(activity) then return BLFG_DUNGEON_DIFFICULTIES end
    return BLFG_BASIC_DUNGEON_DIFFICULTIES
  end
  return DIFFICULTIES
end

BLFG_RAID_SIZE_DEFAULTS = {
  ["Zul'Gurub"]=20, ["Ruins of Ahn'Qiraj"]=20, ["Karazhan"]=10,
  ["Molten Core"]=40, ["Blackwing Lair"]=40, ["Onyxia"]=40, ["Temple of Ahn'Qiraj"]=40, ["Naxxramas"]=40,
  ["Gruul's Lair"]=25, ["Magtheridon's Lair"]=25, ["Serpentshrine Cavern"]=25, ["Tempest Keep"]=25,
  ["Battle for Mount Hyjal"]=25, ["Black Temple"]=25, ["Sunwell Plateau"]=25,
  ["Vault of Archavon"]=25, ["The Obsidian Sanctum"]=25, ["The Eye of Eternity"]=25, ["Ulduar"]=25,
  ["Trial of the Crusader"]=25, ["Icecrown Citadel"]=25, ["The Ruby Sanctum"]=25,
}

BLFG_RAID_SIZE_BY_DIFFICULTY = {
  ["Vault of Archavon"]=true, ["The Obsidian Sanctum"]=true, ["The Eye of Eternity"]=true,
  ["Ulduar"]=true, ["Trial of the Crusader"]=true, ["Icecrown Citadel"]=true, ["The Ruby Sanctum"]=true,
}

function BLFG_DefaultMaxMembersFor(typeName, activity, difficulty)
  if typeName == "Dungeon" or typeName == "Key" then return 5 end
  if typeName == "Raid" then
    if BLFG_RAID_SIZE_BY_DIFFICULTY[activity or ""] then
      if difficulty == "Heroic" then return 25 end
      return 10
    end
    return BLFG_RAID_SIZE_DEFAULTS[activity or ""] or 25
  end
  if typeName == "World Boss" then return 40 end
  return 5
end

local function serializeListing(l)
  return table.concat({
    PREFIX, "LIST",
    clean(l.id), clean(l.leader), clean(l.class), clean(l.classFile),
    clean(l.type), clean(l.activity), clean(l.difficulty), clean(l.key),
    clean(l.minItemLevel), clean(l.members), clean(l.maxMembers),
    clean(l.needTank), clean(l.needHealer), clean(l.needDPS),
    clean(l.voice), clean(l.loot), clean(l.note), clean(l.created)
  }, "~")
end

local function parseListing(p)
  return {
    id=p[3], leader=p[4], class=p[5], classFile=p[6],
    type=p[7], activity=p[8], difficulty=p[9], key=p[10],
    minItemLevel=p[11], members=tonumber(p[12]) or 1,
    maxMembers=tonumber(p[13]) or 5,
    needTank=p[14], needHealer=p[15], needDPS=p[16],
    voice=p[17], loot=p[18], note=p[19],
    created=tonumber(p[20]) or now(),
    seen=now()
  }
end

local function serializeApplicant(listingId, a)
  return table.concat({
    PREFIX, "APP",
    clean(listingId), clean(a.name), clean(a.class), clean(a.classFile),
    clean(a.level), clean(a.role), clean(a.itemLevel), clean(a.roleType),
    clean(a.discord), clean(a.note), clean(a.applied)
  }, "~")
end

local function parseApplicant(p)
  return {
    listingId=p[3], name=p[4], class=p[5], classFile=p[6],
    level=p[7], role=p[8], itemLevel=p[9], roleType=p[10],
    discord=p[11], note=p[12], applied=tonumber(p[13]) or now()
  }
end

local function serializeDecision(target, result, activity)
  return table.concat({PREFIX, "DECISION", clean(target), clean(result), clean(activity)}, "~")
end

local function serializeRemove(listingId)
  return table.concat({PREFIX, "REMOVE", clean(listingId)}, "~")
end

local function serializePresence()
  local className, classFile = playerClass()
  local role = (BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.role) or ""
  local spec = (BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.roleType) or ""
  local zone = currentZoneText()
  local guild = myGuildName()
  return table.concat({PREFIX, "PING", clean(playerName()), clean(VERSION), clean(playerLevel()), clean(classFile or className), clean(role), clean(zone), clean(guild), clean(now()), clean(spec), clean(className or classFile)}, "~")
end

local function parsePresence(p)
  -- 3.7.5 sent seen at p[8]. 3.7.6 sends zone/guild/seen at p[8]/p[9]/p[10]. 3.9.0 adds spec at p[11].
  if tonumber(p[10]) then
    return {name=p[3], version=p[4], level=p[5], classFile=p[6], role=p[7], zone=p[8], guild=p[9], seen=tonumber(p[10]) or now(), spec=p[11] or "", className=p[12] or ""}
  end
  return {name=p[3], version=p[4], level=p[5], classFile=p[6], role=p[7], zone="", guild="", seen=tonumber(p[8]) or now(), spec="", className=""}
end



local function containsLFG(text)
  local s = lower(text or "")
  -- Catch numbered recruiter shorthand like LF1M/LF2M/LF4M.
  -- The old gate only checked plain LFM, so posts like "LF2M DPS DM" never reached the parser.
  if string.find(" " .. s .. " ", "%s+lf%d+m[%s%p]") then return true end
  if string.find(s, "lfm", 1, true) then return true end
  if string.find(s, "lfg", 1, true) then return true end
  if string.find(s, "lf ", 1, true) then return true end
  if string.find(s, "looking for", 1, true) then return true end
  if string.find(s, "need tank", 1, true) then return true end
  if string.find(s, "need heal", 1, true) then return true end
  if string.find(s, "need dps", 1, true) then return true end
  if string.find(s, "tank + heal", 1, true) then return true end
  if SF577_ContainsLFGFallback and SF577_ContainsLFGFallback(text) then return true end
  if string.find(s, "key", 1, true) then return true end
  if string.find(s, "keystone", 1, true) then return true end
  if string.find(s, "mythic", 1, true) then return true end
  if string.find(s, "rdf", 1, true) or string.find(s, "random dungeon", 1, true) or string.find(s, "queue", 1, true) then return true end
  if string.find(s, "boss blitz", 1, true) or string.find(s, "hc blitz", 1, true) or string.find(s, "hcbb", 1, true) or string.find(s, "bbhc", 1, true) then return true end
  if string.find(s, "last spot", 1, true) then return true end
  if string.find(s, "recruit", 1, true) or string.find(s, "recruiting", 1, true) then return true end
  if string.find(s, "guild", 1, true) then return true end
  return false
end
local function cleanPublicChatText(text)
  local s = tostring(text or "")
  -- Convert clickable item/keystone links into readable display text, but KEEP the link color.
  -- Example: |cffffcc00|Hitem:...|h[Keystone: Deadmines (7)]|h|r -> |cffffcc00[Keystone: Deadmines (7)]|r
  s = string.gsub(s, "|c(%x%x%x%x%x%x%x%x)|H[^|]+|h(%b[])|h|r", "|c%1%2|r")
  s = string.gsub(s, "|c(%x%x%x%x%x%x%x%x)|H[^|]+|h(%b[])|h", "|c%1%2|r")
  -- Links without color still become plain readable bracket text.
  s = string.gsub(s, "|H[^|]+|h(%b[])|h", "%1")
  s = string.gsub(s, "|h(%b[])|h", "%1")
  -- If a malformed link leaks through, hide the long item payload instead of showing Hitem:400...
  s = string.gsub(s, "%[Hitem:[^%]]+%]", "[Item]")
  s = string.gsub(s, "Hitem:%d+[%d:]*", "Item")
  return s
end

local function publicNorm(s)
  s = lower(cleanPublicChatText(s or ""))
  s = string.gsub(s, "[^%w%+]", " ")
  s = string.gsub(s, "%s+", " ")
  return " " .. s .. " "
end
local function publicHasWord(text, word)
  return string.find(publicNorm(text), " " .. lower(word) .. " ", 1, true) ~= nil
end

local function SFProfileMatchActivity(display)
  local ns = publicNorm(display or "")
  local aliases = SFProfileList("activityAliases", {})
  for _, row in ipairs(aliases) do
    local activity = row and row[1]
    local tokens = row and row[2]
    if activity and tokens then
      for _, token in ipairs(tokens) do
        local tokenNorm = string.gsub(lower(token or ""), "[^%w%+]", " ")
        tokenNorm = string.gsub(tokenNorm, "%s+", " ")
        tokenNorm = string.gsub(tokenNorm, "^%s+", "")
        tokenNorm = string.gsub(tokenNorm, "%s+$", "")
        if tokenNorm ~= "" and string.find(ns, " " .. tokenNorm .. " ", 1, true) then return activity end
      end
    end
  end
  return nil
end

local function trimPublicText(s)
  s = tostring(s or "")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

local function titlePublicActivity(s)
  s = trimPublicText(s)
  if s == "" then return "Unknown" end
  s = string.gsub(s, "%s+", " ")
  return string.gsub(string.lower(s), "(%a)([%w']*)", function(a,b) return string.upper(a) .. b end)
end

local function shortenPublicText(s, maxLen)
  s = tostring(s or "")
  maxLen = tonumber(maxLen) or 30
  if string.len(s) <= maxLen then return s end
  return string.sub(s, 1, math.max(1, maxLen - 3)) .. "..."
end

local PUBLIC_TYPE_ICON = {
  Dungeon="Interface\\Icons\\Ability_DualWield",
  Raid="Interface\\Icons\\Achievement_Boss_CThun",
  Key="Interface\\Icons\\INV_Misc_Key_03",
  Event="Interface\\Icons\\INV_Misc_Ticket_Tarot_Madness",
  Guild="Interface\\Icons\\INV_Misc_TabardPVP_01",
  LFG="Interface\\Icons\\INV_Misc_GroupNeedMore",
  Social="Interface\\Icons\\INV_Misc_GroupLooking",
  Other="Interface\\Icons\\INV_Misc_Note_01",
}

local PUBLIC_TYPE_COLOR = {
  Dungeon="|cff3fa7ff",
  Raid="|cff4dff7a",
  Key="|cffb866ff",
  Event="|cffff9a33",
  Guild="|cff00e6cc",
  LFG="|cffffff66",
  Social="|cffff66cc",
  Other="|cffaaaaaa",
}

local function publicTypeColor(t)
  return PUBLIC_TYPE_COLOR[t or ""] or PUBLIC_TYPE_COLOR.Other
end

local function publicTypeIcon(t)
  return PUBLIC_TYPE_ICON[t or ""] or PUBLIC_TYPE_ICON.Other
end

local function publicTypeLabel(t)
  t = t or "Other"
  return "|T" .. publicTypeIcon(t) .. ":14:14:0:0|t " .. publicTypeColor(t) .. t .. "|r"
end

local function publicFilterButtonLabel(t, count)
  count = tonumber(count or 0) or 0
  if t == "All" then
    return "All (" .. tostring(count) .. ")"
  end
  local label = t
  if t == "Dungeon" then label = "Dungeon" end
  return "|T" .. publicTypeIcon(t) .. ":12:12:0:0|t " .. label .. " (" .. tostring(count) .. ")"
end

local function listingAlertColor(t)
  if t == "Raid" then return 0.3, 1.0, 0.45 end
  if t == "Key" then return 0.75, 0.45, 1.0 end
  if t == "Event" then return 1.0, 0.55, 0.15 end
  if t == "Guild" then return 0.0, 0.9, 0.8 end
  if t == "Dungeon" then return 0.25, 0.65, 1.0 end
  return 1.0, 0.82, 0.0
end

local function activityIconForListing(l)
  local t = l and l.type or ""
  if t == "Raid" then return "Interface\Icons\Achievement_Boss_Ragnaros" end
  if t == "World Boss" then return "Interface\Icons\Achievement_Boss_CThun" end
  if t == "Custom Event" or t == "Event" then return "Interface\Icons\INV_Misc_Ticket_Tarot_Madness" end
  if t == "Key" then return "Interface\Icons\INV_Misc_Key_03" end
  if t == "Guild" then return "Interface\Icons\INV_Misc_TabardPVP_01" end
  if t == "LFG" then return "Interface\Icons\INV_Misc_GroupNeedMore" end
  return "Interface\Icons\Ability_DualWield"
end

local PUBLIC_DUNGEON_ACTIVITIES = {
  ["Blackfathom Deeps"]=true, ["Blackrock Caverns"]=true, ["Blackrock Depths"]=true,
  ["Blackrock Depths - Prison"]=true, ["Blackrock Depths - Manufacturing"]=true, ["Blackrock Depths - Upper City"]=true,
  ["Deadmines"]=true, ["Dire Maul"]=true, ["Dire Maul North"]=true, ["Dire Maul East"]=true, ["Dire Maul West"]=true,
  ["Gnomeregan"]=true, ["Lower Blackrock Spire"]=true, ["Upper Blackrock Spire"]=true,
  ["Lower Scholomance"]=true, ["Upper Scholomance"]=true, ["Scholomance"]=true,
  ["Maraudon"]=true, ["Maraudon - Orange Crystals"]=true, ["Maraudon - Pristine Waters"]=true, ["Maraudon - Purple Crystals"]=true,
  ["Ragefire Chasm"]=true, ["Razorfen Downs"]=true, ["Razorfen Kraul"]=true,
  ["Scarlet Monastery"]=true, ["Scarlet Monastery - Armory"]=true, ["Scarlet Monastery - Cathedral"]=true, ["Scarlet Monastery - Graveyard"]=true, ["Scarlet Monastery - Library"]=true,
  ["Shadowfang Keep"]=true, ["Stormwind Stockade"]=true, ["Stratholme"]=true, ["Stratholme - Main Gate"]=true, ["Stratholme - Service Entrance"]=true,
  ["Sunken Temple"]=true, ["Uldaman"]=true, ["Vaults of Inquisition"]=true, ["Wailing Caverns"]=true, ["Zul'Farrak"]=true, ["Road to De Other Side"]=true,
  ["Hellfire Ramparts"]=true, ["Blood Furnace"]=true, ["Shattered Halls"]=true,
  ["The Slave Pens"]=true, ["The Underbog"]=true, ["The Steamvault"]=true, ["Steamvault"]=true,
  ["Mana-Tombs"]=true, ["Auchenai Crypts"]=true, ["Sethekk Halls"]=true, ["Shadow Labyrinth"]=true,
  ["Old Hillsbrad Foothills"]=true, ["The Black Morass"]=true,
  ["The Mechanar"]=true, ["The Botanica"]=true, ["The Arcatraz"]=true, ["Magisters' Terrace"]=true,
  ["Utgarde Keep"]=true, ["Utgarde Pinnacle"]=true, ["The Nexus"]=true, ["Nexus"]=true, ["The Oculus"]=true,
  ["Azjol-Nerub"]=true, ["Ahn'kahet: The Old Kingdom"]=true, ["Ahn'kahet"]=true,
  ["Drak'Tharon Keep"]=true, ["Violet Hold"]=true, ["Gundrak"]=true,
  ["Halls of Stone"]=true, ["Halls of Lightning"]=true, ["Culling of Stratholme"]=true,
  ["Trial of the Champion"]=true, ["Forge of Souls"]=true, ["Pit of Saron"]=true, ["Halls of Reflection"]=true,
  ["Random Dungeon Finder"]=true, ["Random Heroic Dungeon Finder"]=true, ["BC Random Dungeon Finder"]=true, ["Wrath Random Dungeon Finder"]=true,
  ["Classic Dungeon"]=true, ["TBC Dungeon"]=true, ["Wrath Dungeon"]=true,
}
local PUBLIC_OTHER_ACTIVITIES = {["Guild Recruitment"]=true, ["Event"]=true}
local PUBLIC_RAID_ACTIVITIES = {
  ["Zul'Gurub"]=true, ["Onyxia"]=true, ["Molten Core"]=true, ["Blackwing Lair"]=true,
  ["Ruins of Ahn'Qiraj"]=true, ["Temple of Ahn'Qiraj"]=true, ["Naxxramas"]=true,
}
PUBLIC_DUNGEON_ACTIVITIES = SFProfileSet("dungeonActivities", PUBLIC_DUNGEON_ACTIVITIES)
local SF_PUBLIC_PROFILE = SFActiveProfile()
if not SF_PUBLIC_PROFILE or (SF_PUBLIC_PROFILE.features and SF_PUBLIC_PROFILE.features.rdf) then
  PUBLIC_DUNGEON_ACTIVITIES["Random Dungeon Finder"] = true
  PUBLIC_DUNGEON_ACTIVITIES["Random Heroic Dungeon Finder"] = true
  PUBLIC_DUNGEON_ACTIVITIES["BC Random Dungeon Finder"] = true
  PUBLIC_DUNGEON_ACTIVITIES["Wrath Random Dungeon Finder"] = true
  PUBLIC_DUNGEON_ACTIVITIES["Classic Dungeon"] = true
  PUBLIC_DUNGEON_ACTIVITIES["TBC Dungeon"] = true
  PUBLIC_DUNGEON_ACTIVITIES["Wrath Dungeon"] = true
end
PUBLIC_RAID_ACTIVITIES = SFProfileSet("raidActivities", PUBLIC_RAID_ACTIVITIES)

-- SignalFire 1.4.30b: canonical activity names remain valid parser hints even
-- when they are not exposed by the active profile's Create Listing pool.
-- This keeps ordinary ICC/HoL advertisements classified as Raid/Dungeon.
PUBLIC_DUNGEON_ACTIVITIES["Halls of Lightning"] = true
PUBLIC_RAID_ACTIVITIES["Icecrown Citadel"] = true

local function isPublicGuildText(text)
  local s = lower(cleanPublicChatText(text or ""))
  if string.find(s, "guild on", 1, true) or string.find(s, "top 2 guild", 1, true) or string.find(s, "top 5 guild", 1, true) or string.find(s, "competitive", 1, true) and string.find(s, "guild", 1, true) then return true end
  -- 3.7.0: do not let the bare word "guild" hijack Social/LFG chatter.
  -- Must be a recruitment/joining signal or a bracketed guild-style ad.
  if string.find(s, "guild recruitment", 1, true) then return true end
  if string.find(s, "guild recruiting", 1, true) or string.find(s, "recruiting", 1, true) then return true end
  if string.find(s, "recruit ", 1, true) or string.find(s, " recruitment", 1, true) then return true end
  if string.find(s, "looking for guild", 1, true) or string.find(s, "lf guild", 1, true) or string.find(s, "lf hcbb guild", 1, true) then return true end
  if string.find(s, "guild invite", 1, true) or string.find(s, "invite to", 1, true) and string.find(s, "guild", 1, true) then return true end
  if string.find(s, "join", 1, true) and string.find(s, "guild", 1, true) then return true end
  if string.find(s, "raiding guild", 1, true) or string.find(s, "social guild", 1, true) or string.find(s, "leveling guild", 1, true) or string.find(s, "pvp guild", 1, true) then return true end
  if string.find(s, "accepting all classes", 1, true) then return true end
  if string.find(s, "looking for new", 1, true) and (string.find(s, "players", 1, true) or string.find(s, "members", 1, true)) then return true end
  if string.find(s, "new and old players", 1, true) or string.find(s, "old players alike", 1, true) then return true end
  if string.find(s, "progress in a relaxed", 1, true) or string.find(s, "welcoming", 1, true) and string.find(s, "inclusive", 1, true) then return true end
  if string.find(s, "<", 1, true) and string.find(s, ">", 1, true) and (string.find(s, "recruit", 1, true) or string.find(s, "seeking", 1, true) or string.find(s, "accepting", 1, true) or string.find(s, "join", 1, true) or string.find(s, "consider", 1, true) or string.find(s, "guild tag", 1, true) or string.find(s, "looking for", 1, true) or string.find(s, "players", 1, true) or string.find(s, "members", 1, true)) then return true end
  return false
end

local isPublicSocialQuestion
local isPublicRecruiterIntent

local function isPublicConversation(text)
  local s = lower(cleanPublicChatText(text or ""))
  if isPublicSocialQuestion(s) then return false end
  local hasRecruitIntent = string.find(s, "lf ", 1, true) or string.find(s, "lfm", 1, true) or string.find(s, "lfg", 1, true) or string.find(s, "need", 1, true) or string.find(s, "recruit", 1, true) or string.find(s, "looking for", 1, true) or string.find(s, "last spot", 1, true) or string.find(s, "invite", 1, true)
  if hasRecruitIntent then return false end
  if string.find(s, "?", 1, true) then return true end
  if string.find(s, "can you", 1, true) or string.find(s, "do most", 1, true) or string.find(s, "does ", 1, true) or string.find(s, "why ", 1, true) or string.find(s, "what ", 1, true) or string.find(s, "what's", 1, true) or string.find(s, "whats", 1, true) or string.find(s, "where ", 1, true) or string.find(s, "when ", 1, true) or string.find(s, "this boss blitz", 1, true) then return true end
  if string.find(s, "cannot use", 1, true) or string.find(s, "can't use", 1, true) or string.find(s, "can not use", 1, true) then return true end
  if string.find(s, "talking about", 1, true) or string.find(s, "go full heirloom", 1, true) or string.find(s, "use heirlooms", 1, true) then return true end
  return false
end
local function isPublicBossBlitzText(text)
  local s = lower(cleanPublicChatText(text or ""))
  if string.find(s, "forget boss blitz", 1, true) or string.find(s, "boss bitch", 1, true) or string.find(s, "what's this", 1, true) or string.find(s, "whats this", 1, true) then return false end
  return string.find(s, "boss blitz", 1, true) or string.find(s, "bossblitz", 1, true) or string.find(s, "hc blitz", 1, true)
    or string.find(s, "hcbb", 1, true) or string.find(s, "hbb", 1, true) or string.find(s, "bbhc", 1, true)
    or string.find(s, " hc bb", 1, true) or string.find(s, "hc boss blitz", 1, true)
    or string.find(s, "silver rod", 1, true) or string.find(s, "iridescent pearl", 1, true)
    or string.find(s, "seasonal", 1, true)
end

local function isPublicKeystoneText(text)
  local s = lower(cleanPublicChatText(text or ""))
  return string.find(s, "keystone", 1, true) or string.find(s, "[keystone:", 1, true) or string.find(s, " mythic+", 1, true) or string.find(s, " m+", 1, true) or string.find(s, "mythic plus", 1, true)
end

local function isPublicCoinFarmApplicant(text)
  local s = lower(cleanPublicChatText(text or ""))
  return (string.find(s, " coin farm", 1, true) or string.find(s, "coinfarm", 1, true) or string.find(s, " farm coin", 1, true))
    and (string.find(s, " lf ", 1, true) or string.find(s, " lfg", 1, true) or string.find(s, " looking", 1, true) or string.find(s, " ilvl", 1, true) or string.find(s, " lvl", 1, true))
end

local function isPublicExternalAdText(text)
  local s = lower(cleanPublicChatText(text or ""))
  local hasLink = string.find(s, "youtube", 1, true) or string.find(s, "youtu.be", 1, true) or string.find(s, "twitch", 1, true) or string.find(s, "kick.com", 1, true) or string.find(s, "discord.gg", 1, true) or string.find(s, "www.", 1, true) or string.find(s, "http://", 1, true) or string.find(s, "https://", 1, true)
  if not hasLink then return false end

  -- Stream/video promotions are never group listings, even when the poster uses
  -- words such as "recruiting". Discord remains eligible for real guild/community
  -- recruitment below, but Kick/Twitch/YouTube are rejected immediately.
  if string.find(s, "kick.com", 1, true) or string.find(s, "twitch.tv", 1, true)
    or string.find(s, "youtube.com", 1, true) or string.find(s, "youtu.be", 1, true)
    or string.find(s, " youtube", 1, true) or string.find(s, " twitch", 1, true) then return true end

  -- Keep guild/community recruitment that merely includes Discord info.
  if isPublicGuildText(s) then return false end

  -- Real LFG posts sometimes include a Discord, but YouTube/Twitch/Kick style calls-to-watch are not group listings.
  if string.find(s, "watch", 1, true) or string.find(s, "subscribe", 1, true) or string.find(s, "channel", 1, true) or string.find(s, "stream", 1, true) or string.find(s, "video", 1, true) or string.find(s, "follow", 1, true) then return true end
  if (string.find(s, "youtube", 1, true) or string.find(s, "youtu.be", 1, true) or string.find(s, "twitch", 1, true) or string.find(s, "kick.com", 1, true)) and not isPublicRecruiterIntent(s) then return true end
  return false
end

local function isPublicJunkText(text)
  local s = lower(cleanPublicChatText(text or ""))
  if isPublicExternalAdText(s) then return true end
  if string.find(s, "black pee", 1, true) or string.find(s, "i wouldnt mind myself", 1, true) or string.find(s, "i wouldn't mind myself", 1, true) then return true end
  if string.find(s, "forget boss blitz", 1, true) or string.find(s, "boss bitch", 1, true) then return true end
  if string.find(s, " lf wow gf", 1, true) or string.find(s, "wow gf", 1, true) or string.find(s, "good guild leader", 1, true) then return true end
  return false
end

local function addPublicTag(tags, tag)
  for _, t in ipairs(tags) do if t == tag then return end end
  table.insert(tags, tag)
end

local function guessPublicTags(text, activity, publicType)
  local s = lower(cleanPublicChatText(text or ""))
  local tags = {}
  if string.find(s, "world boss", 1, true) or string.find(s, "wboss", 1, true) then addPublicTag(tags, "World Boss"); addPublicTag(tags, "Event") end
  if isPublicKeystoneText(s) then addPublicTag(tags, "Mythic+"); addPublicTag(tags, "Keystone") end
  if string.find(s, "mythic", 1, true) then addPublicTag(tags, "Mythic") end
  if string.find(s, "heroic", 1, true) or string.find(s, " hc ", 1, true) or string.find(s, "hcb", 1, true) then addPublicTag(tags, "Heroic") end
  if string.find(s, "hardcore", 1, true) then addPublicTag(tags, "Hardcore") end
  if publicType == "Dungeon" or (activity and PUBLIC_DUNGEON_ACTIVITIES[activity]) then addPublicTag(tags, "Dungeon") end
  if publicType == "Raid" or (activity and PUBLIC_RAID_ACTIVITIES[activity]) then addPublicTag(tags, "Raid") end
  return table.concat(tags, " | ")
end

local function detectPublicILevel(text)
  local s = lower(cleanPublicChatText(text or ""))
  local n = string.match(s, "(%d+)%s*ilvl") or string.match(s, "ilvl%s*(%d+)") or string.match(s, "(%d+)%s*%+%s*ilvl")
  if not n then
    n = string.match(s, "(%d+)%s*%+?%s*resto") or string.match(s, "(%d+)%s*%+?%s*dps") or string.match(s, "(%d+)%s*%+?%s*tank") or string.match(s, "(%d+)%s*%+?%s*heal") or string.match(s, "(%d+)%s*%+?%s*boom")
  end
  n = tonumber(n or "")
  if n and n >= 50 and n <= 120 then return tostring(n) end
  return ""
end

local function scorePublicListing(text, publicType, intent, roles, activity, tags)
  local score = 0
  if activity and activity ~= "" and activity ~= "Unknown" and activity ~= "General Listing" then score = score + 25 end
  if roles and roles ~= "" and roles ~= "Not detected" then score = score + 20 end
  if tags and tags ~= "" then score = score + 20 end
  if intent == "Recruiter" or intent == "Applicant" then score = score + 15 end
  if publicType == "Dungeon" or publicType == "Key" or publicType == "Raid" or publicType == "Event" then score = score + 15 end
  if publicType == "Guild" or publicType == "LFG" then score = score + 10 end
  if publicType == "Social" or publicType == "Other" then score = score - 10 end
  if string.find(lower(cleanPublicChatText(text or "")), "?", 1, true) and publicType ~= "Social" then score = score - 10 end
  if score < 0 then score = 0 end
  if score > 100 then score = 100 end
  return score
end

function isPublicSocialQuestion(text)
  local s = lower(cleanPublicChatText(text or ""))
  if isPublicGuildText(s) then return false end
  local q = string.find(s, "?", 1, true) or string.find(s, "any ", 1, true) == 1 or string.find(s, "anyone", 1, true) or string.find(s, "is there", 1, true) or string.find(s, "does anyone", 1, true)
  if not q then return false end
  if isPublicRecruiterIntent and isPublicRecruiterIntent(s) then return false end
  if string.find(s, "guild", 1, true) or string.find(s, "club", 1, true) or string.find(s, "hub", 1, true) or string.find(s, "profession", 1, true) or string.find(s, "professions", 1, true) or isPublicBossBlitzText(s) then return true end
  if string.find(s, "?", 1, true) and not isPublicRecruiterIntent(s) then return true end
  return false
end

function isPublicRecruiterIntent(text)
  local s = " " .. lower(cleanPublicChatText(text or "")) .. " "
  if string.find(s, " lfm", 1, true) or string.find(s, " lf1m", 1, true) or string.find(s, " lf2m", 1, true) or string.find(s, " lf3m", 1, true) or string.find(s, " lf4m", 1, true) then return true end
  if string.find(s, " need ", 1, true) or string.find(s, " needed", 1, true) or string.find(s, " last spot", 1, true) or string.find(s, " all for ", 1, true) then return true end
  if string.find(s, " need tank", 1, true) or string.find(s, " need heal", 1, true) or string.find(s, " need dps", 1, true) then return true end
  if string.find(s, " lf tank", 1, true) or string.find(s, " lf heals", 1, true) or string.find(s, " lf healer", 1, true) or string.find(s, " lf dps", 1, true) or string.find(s, " lf range dps", 1, true) or string.find(s, " lf ranged dps", 1, true) then return true end
  if (string.find(s, " queue ", 1, true) or string.find(s, " rdf ", 1, true) or string.find(s, " random dungeon", 1, true)) and (string.find(s, " need ", 1, true) or string.find(s, " healer", 1, true) or string.find(s, " heal", 1, true) or string.find(s, " tank", 1, true) or string.find(s, " dps", 1, true)) then return true end
  if string.find(s, " tank and", 1, true) and (string.find(s, " for ", 1, true) or string.find(s, " key", 1, true) or string.find(s, " keystone", 1, true)) then return true end
  if string.find(s, " healer and", 1, true) and (string.find(s, " for ", 1, true) or string.find(s, " key", 1, true) or string.find(s, " keystone", 1, true)) then return true end
  if string.find(s, " dps for ", 1, true) or string.find(s, " heals for ", 1, true) or string.find(s, " tank for ", 1, true) then return true end
  if string.find(s, "pst", 1, true) and (string.find(s, "need", 1, true) or string.find(s, "lfm", 1, true)) then return true end
  return false
end

local function guessPublicIntent(text)
  local s = " " .. lower(cleanPublicChatText(text or "")) .. " "
  if isPublicSocialQuestion(s) then return "Social" end
  if isPublicGuildText(s) then return "Recruiter" end
  if isPublicRecruiterIntent(s) then return "Recruiter" end
  if isPublicCoinFarmApplicant(s) then return "Applicant" end
  if string.find(s, " lfg ", 1, true) or string.find(s, " lfg/", 1, true) or string.find(s, " looking for group", 1, true) or string.find(s, " looking for grp", 1, true) or string.find(s, " looking for party", 1, true) then return "Applicant" end
  if string.find(s, " lf group", 1, true) or string.find(s, " lf grp", 1, true) or string.find(s, " lf raid", 1, true) or string.find(s, " lf dungeon", 1, true) then return "Applicant" end
  if (string.find(s, " dps ", 1, true) or string.find(s, " heals ", 1, true) or string.find(s, " healer ", 1, true) or string.find(s, " tank ", 1, true) or string.find(s, " hunter", 1, true) or string.find(s, " mage", 1, true) or string.find(s, " pally", 1, true) or string.find(s, " paladin", 1, true)) and (string.find(s, " looking", 1, true) or string.find(s, " lf ", 1, true)) then return "Applicant" end
  return "Recruiter"
end


local function smartPublicKeyText(s)
  s = lower(cleanPublicChatText(s or ""))
  return string.find(s, "keystone", 1, true)
      or string.find(s, "mythic+", 1, true)
      or string.find(s, " m+ ", 1, true)
      or string.find(s, " mythic plus", 1, true)
      or string.find(s, "piedra angular", 1, true)
      or string.find(s, "piedra", 1, true)
      -- Common non-English keystone wording seen on Bronzebeard.
      or string.find(s, "é’¥çŸ³", 1, true)
      or string.find(s, "é‘°çŸ³", 1, true)
      or string.find(s, "é»‘çŸ³å±±", 1, true)
end

local function smartPublicJunkText(s)
  s = lower(cleanPublicChatText(s or ""))
  if string.find(s, "bread taste better", 1, true) then return true end
  if string.find(s, "dont know where to start", 1, true) then return true end
  if string.find(s, "how do you", 1, true) then return true end
  return false
end

local function smartPublicRoleSummary(text, intent)
  local s = lower(cleanPublicChatText(text or ""))
  local roles = {}
  local function add(v)
    for _,x in ipairs(roles) do if x == v then return end end
    table.insert(roles, v)
  end
  if string.find(s, "tank", 1, true) or string.find(s, "prot", 1, true) then add("Tank") end
  if string.find(s, "heal", 1, true) or string.find(s, "healer", 1, true) or string.find(s, "hpal", 1, true) or string.find(s, "resto", 1, true) or string.find(s, "disc", 1, true) then add("Healer") end
  if string.find(s, "dps", 1, true) or string.find(s, "damage", 1, true) or string.find(s, "caster", 1, true) or string.find(s, "melee", 1, true) then add("DPS") end
  if #roles == 0 then return "" end
  return table.concat(roles, "+")
end


local function blfgBumpParserStat(key)
  if not BronzeLFG_DB then return end
  BronzeLFG_DB.parserStats = BronzeLFG_DB.parserStats or {}
  BronzeLFG_DB.parserStats[key] = (BronzeLFG_DB.parserStats[key] or 0) + 1
end

local function scorePublicCategory(text, activity, intent)
  local s = lower(cleanPublicChatText(text or ""))
  local scores = {Dungeon=0, Raid=0, Key=0, Event=0, Guild=0, LFG=0, Social=0, Other=1}

  -- Strong bucket ownership. These are intentionally weighted instead of hard-priority
  -- so one accidental word does not hijack the whole listing.
  if isPublicGuildText(s) then scores.Guild = scores.Guild + 180; scores.Raid = scores.Raid - 60; scores.Event = scores.Event - 40; scores.LFG = scores.LFG - 40 end
  if activity == "Guild Recruitment" then scores.Guild = scores.Guild + 70 end
  if activity and PUBLIC_DUNGEON_ACTIVITIES[activity] then scores.Dungeon = scores.Dungeon + 80 end
  if activity and PUBLIC_RAID_ACTIVITIES[activity] then scores.Raid = scores.Raid + 80 end
  if activity == "Mythic+" then scores.Key = scores.Key + 80 end

  if isPublicKeystoneText(s) or smartPublicKeyText(s) then scores.Key = scores.Key + 165; scores.Dungeon = scores.Dungeon - 35; scores.Event = scores.Event - 35; scores.LFG = scores.LFG - 35 end
  if string.find(s, "piedra angular", 1, true) then scores.Key = scores.Key + 160; scores.LFG = scores.LFG - 60; scores.Event = scores.Event - 40 end
  if isPublicCoinFarmApplicant(s) then scores.LFG = scores.LFG + 95; scores.Other = scores.Other - 30; scores.Event = scores.Event - 25; scores.Social = scores.Social - 25 end
  if string.find(s, "ascended", 1, true) or string.find(s, " asc ", 1, true) then scores.Raid = scores.Raid + 45 end
  if string.find(s, "raid", 1, true) or string.find(s, "raiding", 1, true) then scores.Raid = scores.Raid + 35 end
  if string.find(s, " mc ", 1, true) or string.find(s, "bwl", 1, true) or string.find(s, "ony", 1, true) or string.find(s, "zg", 1, true) or string.find(s, "aq20", 1, true) or string.find(s, "aq40", 1, true) or string.find(s, "naxx", 1, true) then scores.Raid = scores.Raid + 40 end

  if isPublicBossBlitzText(s) then
    -- Boss Blitz / HCBB / BBHC is the seasonal Event context.
    -- Dungeon and raid names remain useful as the Activity, but the filter bucket should be Event.
    scores.Event = scores.Event + 140
    scores.Dungeon = scores.Dungeon - 35
    scores.Raid = scores.Raid - 20
    scores.LFG = scores.LFG - 15
  end
  if string.find(s, "world boss", 1, true) or string.find(s, "wboss", 1, true) then scores.Event = scores.Event + 60 end

  if intent == "Applicant" then scores.LFG = scores.LFG + 70 end
  if string.find(s, " lfg", 1, true) or string.find(s, "looking for group", 1, true) or string.find(s, " lf group", 1, true) or string.find(s, " lf grp", 1, true) then scores.LFG = scores.LFG + 55 end
  if string.find(s, "queue", 1, true) or string.find(s, " rdf", 1, true) or string.find(s, "random dungeon", 1, true) then
    if intent == "Applicant" then scores.LFG = scores.LFG + 30 else scores.Dungeon = scores.Dungeon + 45 end
  end

  if isPublicRecruiterIntent(s) then
    scores.LFG = scores.LFG + 20
    if activity and PUBLIC_DUNGEON_ACTIVITIES[activity] then scores.Dungeon = scores.Dungeon + 25 end
    if activity and PUBLIC_RAID_ACTIVITIES[activity] then scores.Raid = scores.Raid + 25 end
  end

  if isPublicSocialQuestion(s) then scores.Social = scores.Social + 45 end
  if string.find(s, "any leveling guilds", 1, true) or string.find(s, "recommended professions", 1, true) or string.find(s, "what would be", 1, true) then scores.Social = scores.Social + 55 end

  -- Penalties stop the most common false positives from your screenshots.
  if scores.Guild >= 70 then scores.Social = scores.Social - 60; scores.Event = scores.Event - 20 end
  if not isPublicBossBlitzText(s) then
    if scores.Dungeon >= 80 then scores.Event = scores.Event - 25; scores.LFG = scores.LFG - 10 end
    if scores.Raid >= 80 then scores.Event = scores.Event - 15; scores.LFG = scores.LFG - 10 end
  end
  if string.find(s, "forget boss blitz", 1, true) or string.find(s, "boss bitch", 1, true) then scores.Event = -100 end

    if smartPublicJunkText(s) then scores.Other = scores.Other + 120; scores.LFG = scores.LFG - 60; scores.Event = scores.Event - 40 end

local bestType, bestScore = "Other", -999
  for k, v in pairs(scores) do
    if v > bestScore then bestType, bestScore = k, v end
  end
  return bestType, scores
end

local function classifyPublicType(text, activity, intent)
  local s = lower(cleanPublicChatText(text or ""))
  local result = nil
  if isPublicGuildText(s) and (string.find(s, "recruit", 1, true) or string.find(s, "guild", 1, true)) then result = "Guild"
  elseif smartPublicKeyText(s) then result = "Key"
  else result = scorePublicCategory(text, activity, intent) or "Other" end
  blfgBumpParserStat("type_" .. tostring(result))
  return result
end
local function guessPublicType(text)
  local s = lower(cleanPublicChatText(text or ""))
  if isPublicGuildText(s) then return "Guild" end
  if string.find(s, "top 2 guild", 1, true) or string.find(s, "top 5 guild", 1, true) or (string.find(s, "competitive", 1, true) and string.find(s, "guild", 1, true)) then return "Guild" end
  if isPublicKeystoneText(s) or smartPublicKeyText(s) then return "Key" end
  if isPublicBossBlitzText(s) then return "Event" end
  if string.find(s, "wboss", 1, true) or string.find(s, "world boss", 1, true) then return "WBoss" end
  if string.find(s, "ascended", 1, true) then return "Raid" end
  if string.find(s, "raid", 1, true) or string.find(s, " mc ", 1, true) or string.find(s, "bwl", 1, true) or string.find(s, "zg", 1, true) or string.find(s, "ony", 1, true) or string.find(s, "aq20", 1, true) or string.find(s, "aq ruins", 1, true) or string.find(s, "ossirian", 1, true) or string.find(s, "aq40", 1, true) or string.find(s, "naxx", 1, true) or string.find(s, "kara", 1, true) or string.find(s, "karazhan", 1, true) then return "Raid" end
  if string.find(s, "m+", 1, true) or string.find(s, "mythic+", 1, true) or string.find(s, "key", 1, true) or string.find(s, "keystone", 1, true) then return "Key" end
  if string.find(s, "mythic", 1, true) or string.find(s, "hc ", 1, true) or string.find(s, "dungeon", 1, true) or string.find(s, "deadmines", 1, true) or string.find(s, "mara", 1, true) or string.find(s, "sfk", 1, true) or string.find(s, "bfd", 1, true) or string.find(s, "wc", 1, true) then return "Dungeon" end
  return "Other"
end


local function guessPublicRoles(text, intent)
  local s = lower(cleanPublicChatText(text or ""))
  local roles = {}

  -- Applicant/LFG posts describe the player's role, not roles the group needs.
  if intent == "Applicant" then
    if string.find(s, "tank", 1, true) or string.find(s, "prot", 1, true) then table.insert(roles, roleText("Tank")) end
    if string.find(s, "heal", 1, true) or string.find(s, "heals", 1, true) or string.find(s, "healer", 1, true) or string.find(s, "resto", 1, true) then table.insert(roles, roleText("Healer")) end
    if string.find(s, "dps", 1, true) or string.find(s, "damage", 1, true) or string.find(s, "hunter", 1, true) or string.find(s, "mage", 1, true) or string.find(s, "lock", 1, true) or string.find(s, "rogue", 1, true) or string.find(s, "fury", 1, true) or string.find(s, "ret", 1, true) or string.find(s, "shadow", 1, true) or string.find(s, "boom", 1, true) then table.insert(roles, roleText("DPS")) end
    if #roles == 0 then return "Not detected" end
    return table.concat(roles, "  ")
  end

  -- Recruiter posts describe roles needed. Broad role words are okay here because
  -- intent has already ruled out common player-LFG advertisements.
  if string.find(s, "tank", 1, true) or string.find(s, "tanks", 1, true) then table.insert(roles, roleText("Tank")) end
  if string.find(s, "heal", 1, true) or string.find(s, "heals", 1, true) or string.find(s, "healer", 1, true) then table.insert(roles, roleText("Healer")) end
  if string.find(s, "dps", 1, true) or string.find(s, "damage", 1, true) then table.insert(roles, roleText("DPS")) end
  if string.find(s, "any spec", 1, true) or string.find(s, "any role", 1, true) then table.insert(roles, roleText("Flexible")) end
  if #roles == 0 then return "Not detected" end
  return table.concat(roles, "  ")
end

local function guessPublicActivity(text)
  local display = cleanPublicChatText(text or "")
  local s = lower(display)
  local ns = publicNorm(display)

  local piedraName = string.match(display, "[Pp]iedra angular:%s*([^%]]+)")
  if piedraName and piedraName ~= "" then
    piedraName = string.gsub(piedraName, "%s*%(%d+%)%s*$", "")
    return titlePublicActivity(piedraName)
  end

  -- Chinese key shorthand observed in chat, e.g. "é’¥çŸ³: é»‘çŸ³å±±".
  if string.find(display, "é’¥çŸ³", 1, true) or string.find(display, "é‘°çŸ³", 1, true) then
    if string.find(display, "é»‘çŸ³å±±", 1, true) then return "Blackrock Mountain" end
    return "Mythic+"
  end

  -- FrostSeek-style keystone extraction: [Keystone: Lower Blackrock Spire (3)] -> Lower Blackrock Spire
  local keyName = string.match(display, "%[Keystone:%s*([^%]]+)%]")
  if keyName and keyName ~= "" then
    keyName = string.gsub(keyName, "%s*%(%d+%)%s*$", "")
    return titlePublicActivity(keyName)
  end

  if isPublicGuildText(display) then return "Guild Recruitment" end
  if string.find(s, "rdf", 1, true) or string.find(s, "random dungeon finder", 1, true) or string.find(s, "random dungeon", 1, true) or (string.find(s, "queue", 1, true) and (string.find(s, "dungeon", 1, true) or string.find(s, "bc", 1, true) or string.find(s, "tbc", 1, true) or string.find(s, "wrath", 1, true) or string.find(s, "wotlk", 1, true))) then
    if string.find(s, "bc", 1, true) or string.find(s, "tbc", 1, true) or string.find(s, "outland", 1, true) then return "BC Random Dungeon Finder" end
    if string.find(s, "wrath", 1, true) or string.find(s, "wotlk", 1, true) or string.find(s, "northrend", 1, true) then return "Wrath Random Dungeon Finder" end
    return "Random Dungeon Finder"
  end

  if string.find(ns, " aq ruins ", 1, true) or string.find(ns, " aq ruin ", 1, true) or string.find(ns, " ruins aq ", 1, true) or string.find(ns, " ossirian ", 1, true) then return "Ruins of Ahn'Qiraj" end

  local profileActivity = SFProfileMatchActivity(display)
  if profileActivity then return profileActivity end

  local checks = {
    {"Utgarde Keep", {"utgarde keep", " uk ", "uk key", "uk m+", "uk mythic"}},
    {"Drak'Tharon Keep", {"drak'tharon keep", "draktharon keep", "drak tharon", "dtk", "drak"}},
    {"Gundrak", {"gundrak", " gd "}},
    {"The Nexus", {"the nexus", "nexus"}},
    {"Hellfire Ramparts", {"hellfire ramparts", "ramparts", "ramps", " ramp "}},
    {"The Slave Pens", {"the slave pens", "slave pens", " sp "}},
    {"The Botanica", {"the botanica", "botanica", " bot "}},
    {"Mana-Tombs", {"mana-tombs", "mana tombs", " manatombs", " mt "}},
    {"Blood Furnace", {"blood furnace", " bf "}},
    {"Shattered Halls", {"shattered halls", " sh "}},
    {"The Underbog", {"the underbog", "underbog", " ub "}},
    {"The Steamvault", {"the steamvault", "steamvault", "steam vault", " sv "}},
    {"Auchenai Crypts", {"auchenai crypts", " crypts", "ac key", " ac "}},
    {"Sethekk Halls", {"sethekk halls", "sethekk", " seth ", " shalls"}},
    {"Shadow Labyrinth", {"shadow labyrinth", "slabs", "slab", " shadow lab", " sl "}},
    {"Old Hillsbrad Foothills", {"old hillsbrad foothills", "old hillsbrad", "hillsbrad", " ohf "}},
    {"The Black Morass", {"the black morass", "black morass", " bm "}},
    {"The Mechanar", {"the mechanar", "mechanar", " mech "}},
    {"The Arcatraz", {"the arcatraz", "arcatraz", " arc "}},
    {"Magisters' Terrace", {"magisters' terrace", "magisters terrace", "mgt", " mag t", "terrace"}},
    {"Utgarde Pinnacle", {"utgarde pinnacle", " up ", "up key", "up m+"}},
    {"The Oculus", {"the oculus", "oculus", " occ "}},
    {"Azjol-Nerub", {"azjol-nerub", "azjol nerub", "azjol", " an "}},
    {"Ahn'kahet: The Old Kingdom", {"ahn'kahet", "ahnkahet", "old kingdom", " ok ", "ank"}}, 
    {"Violet Hold", {"violet hold", " vh "}},
    {"Halls of Stone", {"halls of stone", " hos "}},
    {"Halls of Lightning", {"halls of lightning", " hol "}},
    {"Culling of Stratholme", {"culling of stratholme", "culling strat", " cos "}},
    {"Trial of the Champion", {"trial of the champion", " toc ", "champion trial"}},
    {"Forge of Souls", {"forge of souls", " fos "}},
    {"Pit of Saron", {"pit of saron", " pos "}},
    {"Halls of Reflection", {"halls of reflection", " hor "}},
    {"Blackrock Caverns", {"blackrock caverns", " brc "}},
    {"Blackrock Depths", {"blackrock depths", " brd ", "brd arena", "brd emp", "brd emperor"}},
    {"Blackrock Depths - Prison", {"brd prison", "prison"}},
    {"Blackrock Depths - Manufacturing", {"brd manufacturing", "manufacturing"}},
    {"Blackrock Depths - Upper City", {"brd upper", "upper city"}},
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
    {"Scarlet Monastery - Armory", {"sm armory", "sm arm", "smarm", "scarlet monastery armory", " armory"}},
    {"Scarlet Monastery - Cathedral", {"sm cath", "smcath", "sm cathedral", "scarlet monastery cathedral", " cathedral", "cath"}},
    {"Scarlet Monastery - Graveyard", {"sm gy", "smgy", "sm grave", "sm graveyard", "scarlet monastery graveyard", " graveyard"}},
    {"Scarlet Monastery - Library", {"sm lib", "smlib", "sm library", "scarlet monastery library", "monasterio escarlata - biblioteca", "biblioteca", " library"}},
    {"Scarlet Monastery", {"scarlet", "sm "}},
    {"Maraudon - Orange Crystals", {"mara orange", "orange crystals"}},
    {"Maraudon - Pristine Waters", {"mara princess", "mara water", "pristine waters", "pristine"}},
    {"Maraudon - Purple Crystals", {"mara purple", "purple crystals"}},
    {"Maraudon", {"mara", "maraudon"}},
    {"Razorfen Downs", {"rfd", "razorfen downs", "razor fen downs"}},
    {"Razorfen Kraul", {"rfk", "razorfen kraul", "razor fen kraul"}},
    {"Ragefire Chasm", {"rfc", "ragefire"}},
    {"Deadmines", {"deadmines", " dm ", " vc ", "dm hc", "dm group", "dm blitz"}},
    {"Blackfathom Deeps", {"bfd", "blackfathom"}},
    {"Wailing Caverns", {" wc ", "wailing caverns", "wailing", "wc blitz", "wc hc"}},
    {"Shadowfang Keep", {"sfk", "shadowfang"}},
    {"Gnomeregan", {"gnomeregan", "gnomer", "gnome"}},
    {"Stormwind Stockade", {"stockade", "stocks"}},
    {"Sunken Temple", {"sunken temple", "temple of atal", "atal", "st "}},
    {"Uldaman", {"uldaman", "ulda"}},
    {"Zul\'Farrak", {"zul\'farrak", "zulfarrak", " zf ", "zf hc"}},
    {"Vaults of Inquisition", {"vaults of inquisition", "vaults", "voi"}},
    {"Road to De Other Side", {"road to de other side", "roads", "rdos"}},
    {"Molten Core", {" mc ", "molten core", "molten"}},
    {"Blackwing Lair", {"bwl", "blackwing lair", "blackwing", "nefarian", "nef"}},
    {"Zul'Gurub", {"zg", "zul'gurub", "zulgurub"}},
    {"Ruins of Ahn'Qiraj", {"aq20", "aq ruins", "aq ruin", "ruins of ahn'qiraj", "ruins of ahnqiraj", "ruins aq", "raq", "ossirian"}},
    {"Temple of Ahn'Qiraj", {"aq40", "temple of ahn'qiraj", "temple of ahnqiraj", "temple aq", "taq"}},
    {"Naxxramas", {"naxx", "naxxramas"}},
    {"Onyxia", {"ony", "onyxia"}},
    {"Karazhan", {"kara", "karazhan", "prince", "prince malchezaar"}},
  }
  for _, row in ipairs(checks) do
    for _, token in ipairs(row[2]) do
      local tokenNorm = string.gsub(lower(token), "[^%w%+]", " ")
      tokenNorm = string.gsub(tokenNorm, "%s+", " ")
      tokenNorm = string.gsub(tokenNorm, "^%s+", "")
      tokenNorm = string.gsub(tokenNorm, "%s+$", "")
      if tokenNorm ~= "" and string.find(ns, " " .. tokenNorm .. " ", 1, true) then return row[1] end
    end
  end
  if isPublicBossBlitzText(display) then
    if string.find(s, "hub", 1, true) or string.find(s, "invite", 1, true) then return "Event Hub" end
    return "Event"
  end
  if string.find(s, "mythic+", 1, true) or string.find(s, "m+", 1, true) or string.find(s, "mythic plus", 1, true) then return "Mythic+" end
  if string.find(s, "raid", 1, true) or string.find(s, "raiding", 1, true) then return "General Raid" end
  if string.find(s, "dungeon", 1, true) then return "General Dungeon" end
  return "General Listing"
end

local function normalizePublicActivity(publicType, activity, text)
  local s = lower(cleanPublicChatText(text or ""))
  activity = activity or ""
  if publicType == "Social" then
    if string.find(s, "guild", 1, true) or string.find(s, "club", 1, true) or string.find(s, "hub", 1, true) then return "Community / Question" end
    return "Social / Question"
  end
  if publicType == "LFG" and (activity == "" or activity == "Unknown" or activity == "General Listing") then
    if isPublicCoinFarmApplicant(s) then return "Coin Farm" end
    if isPublicKeystoneText(s) then return "Mythic+" end
    if string.find(s, "rdf", 1, true) or string.find(s, "random dungeon", 1, true) then return "Random Dungeon Finder" end
    if string.find(s, "raid", 1, true) then return "General Raid" end
    if isPublicBossBlitzText(s) then return "Event" end
    return "Looking For Group"
  end
  if publicType == "Guild" then return "Guild Recruitment" end
  if publicType == "Key" and (activity == "" or activity == "Unknown" or activity == "General Listing") then return "Mythic+" end
  if publicType == "Raid" and (activity == "" or activity == "Unknown" or activity == "General Listing") then return "General Raid" end
  if publicType == "Dungeon" and (activity == "" or activity == "Unknown" or activity == "General Listing") then return "General Dungeon" end
  if publicType == "Event" then
    if activity == "" or activity == "Unknown" or activity == "General Listing" then return "Seasonal Event" end
    return activity
  end
  if activity == "Unknown" then return "General Listing" end
  return activity
end


function BLFG:NotifyForPublicGroup(g)
  if not g or not BronzeLFG_DB or not BronzeLFG_DB.options then return end
  local opts = BronzeLFG_DB.options
  if opts.notifyEnabled == false then return end

  local t = tostring(g.type or "")
  local activity = tostring(g.activity or t or "listing")
  local msgText = string.lower(tostring(g.tags or "") .. " " .. tostring(g.message or "") .. " " .. activity)
  local should = false

  if opts.notifyKey ~= false and t == "Key" then
    local f = tostring(opts.notifyKeyFilter or "Any Key")
    if f == "Any Key" or f == "Any Keystone" or string.find(msgText, string.lower(f), 1, true) then should = true end
  end

  if opts.notifyRaid ~= false and t == "Raid" then
    local f = tostring(opts.notifyRaidFilter or "Any Raid")
    local fl = string.lower(f)
    if f == "Any Raid" or string.find(msgText, fl, 1, true) then should = true end
    if f == "Molten Core" and string.find(msgText, "mc", 1, true) then should = true end
    if f == "Blackwing Lair" and string.find(msgText, "bwl", 1, true) then should = true end
    if f == "Zul'Gurub" and (string.find(msgText, "zg", 1, true) or string.find(msgText, "zul", 1, true)) then should = true end
    if f == "Onyxia" and string.find(msgText, "ony", 1, true) then should = true end
    if f == "AQ20" and string.find(msgText, "aq20", 1, true) then should = true end
    if f == "AQ40" and string.find(msgText, "aq40", 1, true) then should = true end
    if f == "Naxxramas" and string.find(msgText, "naxx", 1, true) then should = true end
  end

  if opts.notifyHCBB ~= false and (t == "Event" or string.find(msgText, "world boss", 1, true) or string.find(msgText, "wboss", 1, true)) then
    local f = tostring(opts.notifyEventFilter or "Any Event")
    local fl = string.lower(f)
    if f == "Any Event" then should = true
    elseif f == "World Boss" and (string.find(msgText, "world boss", 1, true) or string.find(msgText, "wboss", 1, true)) then should = true
    elseif f ~= "Boss Blitz" and f ~= "World Boss" and string.find(msgText, fl, 1, true) then should = true end
  end

  if opts.notifyGuild == true and t == "Guild" then should = true end
  if not should then return end

  local r,gc,b = listingAlertColor(t)
  local player = tostring(g.player or "someone")
  local line = "SignalFire Alert: New " .. activity .. " listing from " .. player
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(line, r, gc, b, 1.0, 5) end
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire Alert:|r New " .. publicTypeColor(t) .. t .. "|r - " .. activity .. " from " .. player)
  if opts.notifySound == true and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
end

function BLFG:AddPublicGroup(author, text, channelName)
  if not BronzeLFG_DB.options or BronzeLFG_DB.options.publicGroups == false then return end
  if not author or (author == playerName() and not self.SignalFireTestSay) then return end
  if not text then return end
  if BronzeLFG_IsAddonSpam(text) then return end
  if isPublicJunkText(text) then return end
  local raw = tostring(text or "")
  local rawLower = lower(raw)
  if string.sub(raw, 1, 3) == "LC1" or string.sub(raw, 1, 3) == "LC2" or string.find(rawLower, "lc1:conf", 1, true) or string.find(rawLower, "conf:", 1, true) then return end
  local displayText = cleanPublicChatText(raw)
  if not containsLFG(displayText) then return end
  local socialQuestion = isPublicSocialQuestion(displayText)
  if isPublicConversation(displayText) and not socialQuestion then return end

  local name = string.gsub(author, "%-.*", "")
  local guessedIntent = socialQuestion and "Social" or guessPublicIntent(displayText)
  local guessedActivity = guessPublicActivity(displayText)
  local guessedType = classifyPublicType(displayText, guessedActivity, guessedIntent)
  guessedActivity = normalizePublicActivity(guessedType, guessedActivity, displayText)
  local guessedRoles = guessPublicRoles(displayText, guessedIntent)
  local guessedTags = guessPublicTags(displayText, guessedActivity, guessedType)
  local guessedILevel = detectPublicILevel(displayText)
  local guessedScore = scorePublicListing(displayText, guessedType, guessedIntent, guessedRoles, guessedActivity, guessedTags)

  -- De-duplicate repeated public recruiter posts from the same player/activity/message.
  -- This keeps the board retail-clean instead of filling a full page with one spammer.
  for id, g in pairs(self.publicGroups) do
    if g.player == name and (g.activity == guessedActivity or g.message == text) then
      g.message = displayText
      g.channel = channelName or g.channel or "Public"
      g.type = guessedType
      g.activity = guessedActivity
      g.roles = guessedRoles
      g.intent = guessedIntent
      g.tags = guessedTags
      g.ilevel = guessedILevel
      g.score = guessedScore
      g.seen = now()
      self._lastPublicGroupTouched = g
      self._lastPublicGroupTouchedKey = id
      if self._suppressPublicRefreshInChatLink then self:RequestPublicGroupsRefresh() else self:RefreshPublicGroups() end
      return g
    end
  end

  local id = name .. "-" .. tostring(now())
  self.publicGroups[id] = {
    id = id,
    player = name,
    message = displayText,
    channel = channelName or "Public",
    type = guessedType,
    activity = guessedActivity,
    roles = guessedRoles,
    intent = guessedIntent,
    tags = guessedTags,
    ilevel = guessedILevel,
    score = guessedScore,
    created = now(),
    seen = now(),
  }
  self._lastPublicGroupTouched = self.publicGroups[id]
  self._lastPublicGroupTouchedKey = id
  self:NotifyForPublicGroup(self.publicGroups[id])
  if self._suppressPublicRefreshInChatLink then self:RequestPublicGroupsRefresh() else self:RefreshPublicGroups() end
  return self.publicGroups[id]
end

SLASH_SIGNALFIREPARSE1 = "/sfparse"
SlashCmdList["SIGNALFIREPARSE"] = function(msg)
  local text = tostring(msg or "")
  if text == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire parse:|r Usage: /sfparse LFM Halls of Lightning need heals")
    return
  end
  local activity = guessPublicActivity(text)
  local intent = guessPublicIntent(text)
  local publicType = classifyPublicType(text, activity, intent)
  activity = normalizePublicActivity(publicType, activity, text)
  local roles = guessPublicRoles(text, intent)
  local tags = guessPublicTags(text, activity, publicType)
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire parse:|r Type=" .. tostring(publicType) .. " | Activity=" .. tostring(activity) .. " | Intent=" .. tostring(intent) .. " | Roles=" .. tostring(roles) .. " | Tags=" .. tostring(tags))
end

function BLFG:ExpirePublicGroups()
  local expire = 300
  if BronzeLFG_DB.options and BronzeLFG_DB.options.publicExpire then expire = tonumber(BronzeLFG_DB.options.publicExpire) or 300 end
  for id, g in pairs(self.publicGroups) do
    if now() - (g.seen or g.created or now()) > expire then
      self.publicGroups[id] = nil
      if self.selectedPublic == id then self.selectedPublic = nil end
    end
  end
end

function BLFG:BuildProfileWhisper(activity)
  local pr = BronzeLFG_DB.profile or {}
  local className = select(1, UnitClass("player")) or "player"
  local parts = {}
  table.insert(parts, "Hi, I saw your LFG post")
  if activity and activity ~= "Unknown" then table.insert(parts, " for " .. activity) end
  table.insert(parts, ". ")
  if pr.role and pr.role ~= "" then table.insert(parts, "Role: " .. pr.role .. ". ") end
  if pr.roleType and pr.roleType ~= "" then table.insert(parts, "Spec: " .. pr.roleType .. ". ") end
  table.insert(parts, "Class: " .. className .. ". ")
  if pr.itemLevel and pr.itemLevel ~= "" then table.insert(parts, "iLvl: " .. pr.itemLevel .. ". ") end
  if pr.discord then table.insert(parts, "Discord: Yes. ") end
  if pr.note and pr.note ~= "" then table.insert(parts, pr.note .. ". ") end
  table.insert(parts, "Interested if you still need.")
  return table.concat(parts, "")
end

function BLFG:WhisperPublicSelected()
  local g = self.publicGroups[self.selectedPublic]
  if not g then msg("Select a public group first."); return end
  local whisper = self:BuildProfileWhisper(g.activity)
  SendChatMessage(whisper, "WHISPER", nil, g.player)
  flash("Applied to " .. g.player .. " via whisper.")
end

function BLFG:ClearPublicGroups()
  self.publicGroups = {}
  self.selectedPublic = nil
  self.publicPage = 1
  self:RefreshPublicGroups()
  flash("Public Groups cleared.")
end


-- UI helpers
local function backdrop(f, alpha)
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=14,
    insets={left=4,right=4,top=4,bottom=4}
  })
  f:SetBackdropColor(0,0,0,alpha or .96)
  f:SetBackdropBorderColor(.85,.62,.12,.95)
end
local function flat(f, alpha)
  f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background"})
  f:SetBackdropColor(0,0,0,alpha or .85)
end
local function font(parent, text, size, r, g, b)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "")
  fs:SetTextColor(r or 1, g or .82, b or 0)
  fs:SetText(text or "")
  return fs
end
local function button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetWidth(w or 100); b:SetHeight(h or 24); b:SetText(text or "")
  return b
end
local function setButtonEnabled(btn, enabled)
  if not btn then return end
  if enabled then
    btn:Enable()
    btn:SetAlpha(1.0)
  else
    btn:Disable()
    btn:SetAlpha(0.45)
  end
end
local function edit(parent, w, h, multi)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetWidth(w or 100); e:SetHeight(h or 22)
  e:SetAutoFocus(false)
  e:SetFontObject(ChatFontNormal)
  e:SetTextInsets(6,6,3,3)
  if multi then e:SetMultiLine(true) end
  backdrop(e, .92)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  return e
end
function BLFG_SF1430H_SuppressNativeDropdown(d)
  if not d then return end
  d.SFDisableNativeMenu = true
  if d.SetAlpha then d:SetAlpha(0) end
  if d.EnableMouse then d:EnableMouse(false) end
  if d.SetScript then
    d:SetScript("OnMouseDown", nil)
    d:SetScript("OnMouseUp", nil)
  end

  local name = d.GetName and d:GetName() or nil
  local b = name and _G[name .. "Button"] or nil
  if b then
    if b.EnableMouse then b:EnableMouse(false) end
    if b.Disable then b:Disable() end
    if b.SetScript then
      b:SetScript("OnClick", nil)
      b:SetScript("OnMouseDown", nil)
      b:SetScript("OnMouseUp", nil)
    end
    if b.Hide then b:Hide() end
  end

  local catcher = d.sf135jClickCatcher
  if catcher then
    if catcher.EnableMouse then catcher:EnableMouse(false) end
    if catcher.Disable then catcher:Disable() end
    if catcher.SetScript then
      catcher:SetScript("OnClick", nil)
      catcher:SetScript("OnMouseDown", nil)
      catcher:SetScript("OnMouseUp", nil)
    end
    if catcher.Hide then catcher:Hide() end
  end
  if d.sf135jArrow and d.sf135jArrow.Hide then d.sf135jArrow:Hide() end
end

function BLFG_FixDropdownButton(d)
  if d and d.SFDisableNativeMenu then
    BLFG_SF1430H_SuppressNativeDropdown(d)
    return
  end
  if not d or not d.GetName then return end
  local name = d:GetName()
  if not name then return end
  local b = _G[name .. "Button"]
  if not b then return end
  b:Show()
  b:SetAlpha(1)
  if b.sfArrowText then b.sfArrowText:Hide() end
  b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down")
  b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
  if b.GetNormalTexture and b:GetNormalTexture() then b:GetNormalTexture():SetAlpha(1) end
  if b.GetPushedTexture and b:GetPushedTexture() then b:GetPushedTexture():SetAlpha(1) end
  if b.GetDisabledTexture and b:GetDisabledTexture() then b:GetDisabledTexture():SetAlpha(1) end
  if b.GetHighlightTexture and b:GetHighlightTexture() then b:GetHighlightTexture():SetAlpha(.75) end
end
local function dropdown(parent, name, w, values, selected, onchange)
  local d = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(d, w or 120)
  UIDropDownMenu_SetText(d, selected or values[1])
  d.values = values
  BLFG_FixDropdownButton(d)
  UIDropDownMenu_Initialize(d, function()
    for _, v in ipairs(d.values or values) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.func = function()
        UIDropDownMenu_SetText(d, v)
        if onchange then onchange(v) end
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  return d
end
local function dd(d) return UIDropDownMenu_GetText(d) or "" end
local function setDD(d, values, selected)
  d.values = values
  UIDropDownMenu_SetText(d, selected or values[1])
  BLFG_FixDropdownButton(d)
end

function BLFG_DropdownText(d)
  if not d then return "" end
  local text = UIDropDownMenu_GetText and UIDropDownMenu_GetText(d) or nil
  if (not text or text == "") and d.GetName then
    local fs = _G[tostring(d:GetName()) .. "Text"]
    if fs and fs.GetText then text = fs:GetText() end
  end
  return tostring(text or "")
end


local function scaleLabelFromValue(v)
  v = tonumber(v) or 1.0
  local pct = math.floor((v * 100) + 0.5)
  if pct <= 75 then return "75%" end
  if pct <= 85 then return "85%" end
  if pct <= 100 then return "100%" end
  if pct <= 110 then return "110%" end
  return "125%"
end

local function scaleValueFromLabel(label)
  label = tostring(label or "100%")
  if string.find(label, "75", 1, true) then return 0.75 end
  if string.find(label, "85", 1, true) then return 0.85 end
  if string.find(label, "110", 1, true) then return 1.10 end
  if string.find(label, "125", 1, true) then return 1.25 end
  return 1.00
end

local function normalizeFavName(name)
  name = tostring(name or "")
  name = string.gsub(name, "%s+", "")
  return string.lower(name)
end

local RAID_ALERT_OPTIONS = {"Any Raid", "Molten Core", "Blackwing Lair", "Zul'Gurub", "Onyxia", "AQ20", "AQ40", "Naxxramas"}
local KEY_ALERT_OPTIONS = {
  "Any Key",
  "Utgarde Keep",
  "Drak'Tharon Keep",
  "Gundrak",
  "Nexus",
  "Hellfire Ramparts",
  "The Slave Pens",
  "The Botanica",
  "Mana-Tombs",
}
KEY_ALERT_OPTIONS = SFProfileList("keyAlertOptions", KEY_ALERT_OPTIONS)
local EVENT_ALERT_OPTIONS = {"Any Event", "World Boss", "General Event"}
local SCALE_OPTIONS = {"75%", "85%", "90%", "100%", "110%", "120%", "125%"}

function BLFG:CreateUI()
  if self.frame then return end
  ensureDB()

  local f = CreateFrame("Frame", "BronzeLFGFrame", UIParent)
  self.frame = f
  f:SetWidth(1040); f:SetHeight(590)
  if BronzeLFG_DB.position and BronzeLFG_DB.options and BronzeLFG_DB.options.savePosition then
    f:SetPoint(BronzeLFG_DB.position.point or "CENTER", UIParent, BronzeLFG_DB.position.relPoint or "CENTER", BronzeLFG_DB.position.x or 0, BronzeLFG_DB.position.y or 20)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
  end
  f:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
  f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 250)
  f:SetToplevel(true)
  f:SetMovable(true); f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if BronzeLFG_DB.options and BronzeLFG_DB.options.savePosition then
      local point, _, relPoint, x, y = self:GetPoint()
      BronzeLFG_DB.position = {point=point, relPoint=relPoint, x=x, y=y}
    end
  end)
  backdrop(f, .88)
  if BronzeLFG_DB.options and BronzeLFG_DB.options.scale then f:SetScale(BronzeLFG_DB.options.scale) end
  f:Hide()
  table.insert(UISpecialFrames, "BronzeLFGFrame")

  local title = font(f, (SignalFire_GetTitleText and SignalFire_GetTitleText()) or "SignalFire (Beta)", 22, 1, .75, 0)
  title:SetPoint("TOP", f, "TOP", 0, -14)
  local ver = font(f, "", 10, .9, .8, .45)
  ver:SetPoint("LEFT", title, "RIGHT", 8, -4)
  self.titleText = title
  self.versionText = ver

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  local side = CreateFrame("Frame", nil, f)
  self.side = side
  side:SetWidth(180); side:SetHeight(520)
  side:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -52)
  backdrop(side, .96)

  local content = CreateFrame("Frame", nil, f)
  self.content = content
  content:SetWidth(820); content:SetHeight(520)
  content:SetPoint("TOPLEFT", side, "TOPRIGHT", 14, 0)

  self:BuildSide()
  self:BuildBrowse()
  self:BuildCreate()
  self:BuildProfile()
  self:BuildApplicants()
  self:BuildPublicGroups()
  self:BuildOnlinePanel()
  self:BuildGuildBrowser()
  self:BuildOptions()
  self:BuildMyListing()
  self:BuildMinimap()
  self:RestoreMyListingState()
  self:ShowBrowse()
end


-- SignalFire 1.4.9: core-side module check used by the original sidebar builder.
-- Kept in the core file so the sidebar respects module defaults even if late wrapper files
-- are skipped or overwritten by older SignalFire/BronzeLFG layers.
function BLFG:SFCore149_ModuleEnabled(key)
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}
  BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}

  local profile = nil
  if self.SF143_GetProfileId then profile = self:SF143_GetProfileId() end
  if not profile or profile == "" then profile = BronzeLFG_DB.options.serverProfile or "Triumvirate" end
  profile = tostring(profile or "Triumvirate")

  -- Ascension/CoA has no Triumvirate invasions.  Do not let a saved
  -- Triumvirate/global module flag leak into the Ascension profile.
  if key == "invasions" and profile == "Ascension" then return false end

  local byProfile = BronzeLFG_DB.options.modulesByProfile[profile]
  if byProfile and byProfile[key] ~= nil then return byProfile[key] == true end

  -- Legacy global module settings are only honored for Triumvirate so old
  -- saved "Invasions on" state cannot make Ascension show the Invasions tab.
  local mods = BronzeLFG_DB.options.modules
  if profile ~= "Ascension" and mods and mods[key] ~= nil then return mods[key] == true end

  if key == "invasions" then return profile ~= "Ascension" end
  return true
end

function BLFG:BuildSide()
  -- SignalFire 1.4.10: sidebar can be rebuilt when profile/modules change.
  -- Hide controls from the previous build first so toggles do not stack duplicate buttons.
  if self.side then
    if self.sfCoreSideChildren then
      for _, child in ipairs(self.sfCoreSideChildren) do
        if child and child.Hide then child:Hide() end
      end
    end
    if self.sideBrand and self.sideBrand.Hide then self.sideBrand:Hide() end
    self.sfCoreSideChildren = {}
  end
  local items = {
    {"Browse", "Find a group", "INV_Misc_Spyglass_02", function() BLFG:ShowBrowse() end},
    {"Create Listing", "Make your own group", "INV_Misc_Note_01", function() BLFG:ShowCreate() end},
    {"Profile", "Your apply info", "INV_Misc_GroupLooking", function() BLFG:ShowProfile() end},
    {"Applicants", "Review applicants", "INV_Misc_GroupNeedMore", function() BLFG:ShowApplicants() end},
    {"Public Groups", "From chat channels", "INV_Misc_Map_01", function() BLFG:ShowPublicGroups() end},
    {"Guild Browser", "Find guilds", "INV_Misc_TabardPVP_01", function() BLFG:ShowGuildBrowser() end},
    {"My Listing", "Manage your group", "INV_Misc_Book_09", function() BLFG:ShowMyListing() end},
    {"Options", "Addon settings", "INV_Misc_Gear_01", function() BLFG:ShowOptions() end},
    {"Network", "SignalFire users", "INV_Misc_GroupLooking", function() if BLFG.ShowSFNetwork then BLFG:ShowSFNetwork() else BLFG:ToggleOnlinePanel() end end},
  }
  if self.SFCore149_ModuleEnabled and self:SFCore149_ModuleEnabled("invasions") then
    table.insert(items, 7, {"Invasions", "Nearby invasion groups", "INV_Misc_Head_Dragon_01", function() BLFG:ShowInvasions() end})
  end
  for i, it in ipairs(items) do
    local b = CreateFrame("Button", nil, self.side)
    if self.sfCoreSideChildren then table.insert(self.sfCoreSideChildren, b) end
    local sideStep = (#items > 9) and 45 or ((#items > 8) and 50 or ((#items > 7) and 58 or 66))
    local sideHeight = (#items > 9) and 38 or ((#items > 8) and 43 or ((#items > 7) and 50 or 56))
    b:SetWidth(158); b:SetHeight(sideHeight)
    b:SetPoint("TOP", self.side, "TOP", 0, -10 - ((i-1)*sideStep))
    backdrop(b, .82)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetTexture("Interface\\Icons\\" .. it[3])
    ic:SetWidth(28); ic:SetHeight(28); ic:SetPoint("LEFT", b, "LEFT", 10, 0)
    local titleSize = 12
    local titleX = 50
    local titleY = 0
    if it[1] == "Profile" then
      titleSize = 11
      titleX = 48
    end
    local t = font(b, it[1], titleSize, 1, .92, .68)
    t:SetPoint("LEFT", b, "LEFT", titleX, 0)
    t:SetJustifyH("LEFT")
    t:SetWidth(104)
    if it[1] == "Applicants" then
      self.applicantsButton = b
      self.applicantsButtonTitle = t
      self.badge = CreateFrame("Frame", nil, b)
      self.badge:SetWidth(20); self.badge:SetHeight(16)
      self.badge:SetPoint("TOPRIGHT", b, "TOPRIGHT", -9, -8)
      backdrop(self.badge, .95)
      self.badge.text = font(self.badge, "0", 9, 1, .2, .2)
      self.badge.text:SetPoint("CENTER")
      self.badge:Hide()
      b:SetScript("OnUpdate", function(self)
        if BLFG.newApplicantAlert then
          local a = (math.sin(GetTime() * 6) + 1) / 2
          self:SetBackdropColor(.35 + (.35 * a), .12 + (.20 * a), .02, .98)
          self:SetBackdropBorderColor(1, .82, .18, 1)
          if BLFG.applicantsButtonTitle then BLFG.applicantsButtonTitle:SetTextColor(1, .35 + (.65 * a), .15) end
          if BLFG.badge then
            BLFG.badge:Show()
            BLFG.badge:SetBackdropColor(.55 + (.35 * a), .05, .05, .98)
            BLFG.badge:SetBackdropBorderColor(1, .9, .25, 1)
          end
        else
          self:SetBackdropColor(0,0,0,.82)
          self:SetBackdropBorderColor(.85,.62,.12,.95)
          if BLFG.applicantsButtonTitle then BLFG.applicantsButtonTitle:SetTextColor(1, .92, .68) end
        end
      end)
    end
    b:SetScript("OnEnter", function(self)
      self:SetBackdropBorderColor(1, .78, .18, 1)
      self:SetBackdropColor(.10, .07, .02, .92)
    end)
    b:SetScript("OnLeave", function(self)
      self:SetBackdropBorderColor(.85,.62,.12,.95)
      self:SetBackdropColor(0,0,0,.82)
    end)
    b:SetScript("OnClick", it[4])
  end

  local brand = font(self.side, "Triumvirate", 15, 1, .75, 0)
  if self.sfCoreSideChildren then table.insert(self.sfCoreSideChildren, brand) end
  brand:SetPoint("BOTTOM", self.side, "BOTTOM", 0, 14)
  self.sideBrand = brand
  if self.SF143_UpdateServerBrand then self:SF143_UpdateServerBrand() end
end

function BLFG:BuildBrowse()
  local p = CreateFrame("Frame", nil, self.content)
  self.browse = p
  p:SetAllPoints()

  local filters = {"All", "Dungeons", "Raids", "World Bosses", "Custom"}
  local prev
  for i, f in ipairs(filters) do
    local b = button(p, f, i == 1 and 80 or 95, 24)
    if i == 1 then b:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    else b:SetPoint("LEFT", prev, "RIGHT", 8, 0) end
    b:SetScript("OnClick", function() BLFG.filter = f; BLFG:RefreshBrowse() end)
    prev = b
  end

  self.search = edit(p, 190, 24, false)
  self.search:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -36)
  self.searchHint = font(self.search, "Search groups...", 10, .55, .55, .55)
  self.searchHint:SetPoint("LEFT", self.search, "LEFT", 8, 0)
  self.search:SetScript("OnTextChanged", function(self)
    if BLFG.searchHint then
      if self:GetText() and self:GetText() ~= "" then BLFG.searchHint:Hide() else BLFG.searchHint:Show() end
    end
    BLFG:RefreshBrowse()
  end)
  self.search:SetScript("OnEditFocusGained", function(self) if BLFG.searchHint then BLFG.searchHint:Hide() end end)
  self.search:SetScript("OnEditFocusLost", function(self) if BLFG.searchHint and (not self:GetText() or self:GetText() == "") then BLFG.searchHint:Show() end end)

  local refresh = button(p, "Refresh", 95, 24)
  refresh:SetPoint("TOPLEFT", p, "TOPLEFT", 665, -36)

  self.browseCountText = font(p, "Active Listings: 0", 10, .65, .85, 1)
  self.browseCountText:SetPoint("RIGHT", refresh, "LEFT", -14, 0)
  refresh:SetScript("OnClick", function() BLFG:Broadcast(); BLFG:RefreshBrowse(); msg("Refreshed.") end)

  local list = CreateFrame("Frame", nil, p)
  self.list = list
  list:SetWidth(525); list:SetHeight(410)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -76)
  backdrop(list, .96)

  self.emptyBrowseIcon = list:CreateTexture(nil, "ARTWORK")
  self.emptyBrowseIcon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
  self.emptyBrowseIcon:SetWidth(44); self.emptyBrowseIcon:SetHeight(44)
  self.emptyBrowseIcon:SetPoint("CENTER", list, "CENTER", 0, 58)
  self.emptyBrowseIcon:Hide()
    self.emptyBrowseText = font(list, "No groups currently listed.\n\nTry:\n- Refresh Listings\n- Create Your Own Group\n- Check Public Groups", 13, 1, 1, 1)
  self.emptyBrowseText:SetPoint("CENTER", list, "CENTER", 0, -18)
  self.emptyBrowseText:SetJustifyH("CENTER")
  self.emptyBrowseText:Hide()

  local h = CreateFrame("Frame", nil, list)
  h:SetWidth(510); h:SetHeight(24); h:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -7)
  flat(h, .95)
  font(h, "Activity / Title", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 8, 0)
  font(h, "Leader", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 245, 0)
  font(h, "T/H/D", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 330, 0)
  font(h, "iLvl", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 385, 0)
  font(h, "Members", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 438, 0)

  self.rows = {}
  for i=1,8 do
    local r = CreateFrame("Button", nil, list)
    r:SetWidth(510); r:SetHeight(42)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -36 - ((i-1)*45))
    flat(r, .85)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetWidth(28); r.icon:SetHeight(28); r.icon:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.title = font(r, "", 11, .9, .35, 1); r.title:SetPoint("TOPLEFT", r, "TOPLEFT", 43, -7)
    r.note = font(r, "", 9, .8, .8, .8); r.note:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -1)
    r.leader = font(r, "", 10, 1, .82, .5); r.leader:SetPoint("LEFT", r, "LEFT", 245, 0)
    r.roles = font(r, "", 10, 1, 1, 1); r.roles:SetPoint("LEFT", r, "LEFT", 330, 0); r.roles:SetWidth(48); r.roles:SetJustifyH("LEFT")
    r.ilvl = font(r, "", 10, 1, 1, 1); r.ilvl:SetPoint("LEFT", r, "LEFT", 385, 0); r.ilvl:SetWidth(48); r.ilvl:SetJustifyH("LEFT")
    r.members = font(r, "", 10, .25, 1, .25); r.members:SetPoint("LEFT", r, "LEFT", 438, 0); r.members:SetWidth(70); r.members:SetJustifyH("LEFT")
    r:SetScript("OnClick", function(self) BLFG.selectedListing = self.key; BLFG:RefreshBrowse() end)
    self.rows[i] = r
  end

  local d = CreateFrame("Frame", nil, p)
  self.detail = d
  d:SetWidth(280); d:SetHeight(410)
  d:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -76)
  backdrop(d, .96)

  d.title = font(d, "No group selected", 15, .95, .4, 1)
  d.title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -18)
  d.sub = font(d, "", 10, 1, .8, .4)
  d.sub:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -2)
  d.note = font(d, "Select a listing to view details.", 10, 1, 1, 1)
  d.note:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -70)
  d.note:SetWidth(250); d.note:SetJustifyH("LEFT")
  d.body = font(d, "", 10, 1, 1, 1)
  d.body:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -165)
  d.body:SetWidth(250); d.body:SetJustifyH("LEFT")
  d.apply = button(d, "Apply", 92, 28)
  d.apply:SetPoint("BOTTOM", d, "BOTTOM", -52, 28)
  d.apply:SetScript("OnClick", function() BLFG:Apply() end)
  d.whisper = button(d, "Whisper", 92, 28)
  d.whisper:SetPoint("LEFT", d.apply, "RIGHT", 12, 0)
  d.whisper:SetScript("OnClick", function()
    local l = BLFG.listings[BLFG.selectedListing]
    if l then SendChatMessage("Hi! I saw your SignalFire listing for " .. l.activity .. ".", "WHISPER", nil, l.leader) end
  end)
  d.apps = button(d, "View Applicants", 245, 26)
  d.apps:SetPoint("BOTTOM", d, "BOTTOM", 0, 66)
  d.apps:SetScript("OnClick", function() BLFG:ShowApplicants() end)
end

function BLFG:BuildCreate()
  local p = CreateFrame("Frame", nil, self.content)
  self.create = p
  p:SetAllPoints(); p:Hide()
  font(p, "Create Listing", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)

  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(820); box:SetHeight(470)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  backdrop(box, .96)

  local c = BronzeLFG_DB.create
  if c.type == "Ascended" then c.type = "Raid" end
  if c.type == "Dungeon" then
    local savedMode = BLFG_DungeonModeForActivity(c.activity)
    if savedMode then
      c.specificDungeon = c.activity
      c.activity = savedMode
    elseif not BLFG_ListContainsValue(listForType("Dungeon"), c.activity) then
      c.activity = "Random Dungeon Finder"
    end
  end

  font(box, "Activity Type", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -22)
  self.typeDrop = dropdown(box, "BLFGTypeDrop", 150, ACTIVITY_TYPES, c.type, function(v)
    local vals = listForType(v)
    setDD(BLFG.activityDrop, vals, vals[1])
    local diffs = BLFG_CreateDifficultyListFor(v, vals[1])
    setDD(BLFG.diffDrop, diffs, diffs[1])
    if BLFG.UpdateCreateControls then BLFG:UpdateCreateControls() end
  end)
  self.typeDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -18)

  font(box, "Activity", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -68)
  self.activityDrop = dropdown(box, "BLFGActivityDrop", 280, listForType(c.type), c.activity, function()
    if BLFG.UpdateCreateControls then BLFG:UpdateCreateControls() end
  end)
  self.activityDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -64)

  self.specificDungeonLabel = font(box, "Dungeon", 11, 1, .82, .35)
  self.specificDungeonLabel:SetPoint("TOPLEFT", box, "TOPLEFT", 475, -68)
  self.specificDungeonDrop = dropdown(box, "BLFGSpecificDungeonDrop", 220, {"Select Dungeon"}, c.specificDungeon or "Select Dungeon", function()
    if BLFG.UpdateCreateControls then BLFG:UpdateCreateControls() end
  end)
  -- SignalFire 1.4.30h: this one field uses the compact custom selector.
  -- Mark it at construction time so every later dropdown hardening pass knows
  -- never to restore the native arrow/click catcher or stock full-height menu.
  self.specificDungeonDrop.SFDisableNativeMenu = true
  if BLFG_SF1430H_SuppressNativeDropdown then BLFG_SF1430H_SuppressNativeDropdown(self.specificDungeonDrop) end
  self.specificDungeonDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 550, -64)

  font(box, "Difficulty", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -114)
  self.diffDrop = dropdown(box, "BLFGDiffDropCreate", 135, BLFG_CreateDifficultyListFor(c.type, c.activity), c.difficulty, function(v)
    if BLFG.UpdateCreateControls then BLFG:UpdateCreateControls() end
  end)
  self.diffDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -110)

  self.keyLabel = font(box, "Key Level", 11, 1, .82, .35)
  self.keyLabel:SetPoint("TOPLEFT", box, "TOPLEFT", 340, -114)
  self.keyBox = edit(box, 60, 24, false)
  self.keyBox:SetPoint("TOPLEFT", box, "TOPLEFT", 420, -110)
  self.keyBox:SetText(c.key or "")
  self.useKeystoneButton = button(box, "Use Keystone", 105, 24)
  self.useKeystoneButton:SetPoint("TOPLEFT", box, "TOPLEFT", 490, -110)
  self.useKeystoneButton:SetScript("OnClick", function() BLFG:UseInventoryKeystoneForCreate() end)

  font(box, "Min Item Level", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -164)
  self.minIlvlBox = edit(box, 85, 24, false)
  self.minIlvlBox:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -160)
  self.minIlvlBox:SetText(c.minItemLevel or "")

  font(box, "Max Members", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 280, -164)
  self.maxBox = edit(box, 85, 24, false)
  self.maxBox:SetPoint("TOPLEFT", box, "TOPLEFT", 390, -160)
  self.maxBox:SetText(c.maxMembers or "5")

  font(box, "Roles Needed", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -215)
  self.needTank = CreateFrame("CheckButton", "BLFGNeedTank3", box, "UICheckButtonTemplate")
  self.needTank:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -206); _G[self.needTank:GetName().."Text"]:SetText("Tank")
  self.needHealer = CreateFrame("CheckButton", "BLFGNeedHealer3", box, "UICheckButtonTemplate")
  self.needHealer:SetPoint("LEFT", self.needTank, "RIGHT", 75, 0); _G[self.needHealer:GetName().."Text"]:SetText("Healer")
  self.needDPS = CreateFrame("CheckButton", "BLFGNeedDPS3", box, "UICheckButtonTemplate")
  self.needDPS:SetPoint("LEFT", self.needHealer, "RIGHT", 85, 0); _G[self.needDPS:GetName().."Text"]:SetText("DPS")
  self.needTank:SetChecked(true); self.needHealer:SetChecked(true); self.needDPS:SetChecked(true)

  font(box, "Voice Chat", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -265)
  self.voiceDrop = dropdown(box, "BLFGVoiceDrop3", 135, VOICE, c.voice or "None", function()
    if BLFG.SFAM_UpdateCreatePreview then BLFG:SFAM_UpdateCreatePreview() end
  end)
  self.voiceDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -261)

  font(box, "Loot Method", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 320, -265)
  self.lootDrop = dropdown(box, "BLFGLootDrop3", 150, LOOT, c.loot or "Group Loot", function()
    if BLFG.SFAM_UpdateCreatePreview then BLFG:SFAM_UpdateCreatePreview() end
  end)
  self.lootDrop:SetPoint("TOPLEFT", box, "TOPLEFT", 430, -261)

  font(box, "Notes", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 18, -320)
  self.noteBox = edit(box, 560, 85, true)
  self.noteBox:SetPoint("TOPLEFT", box, "TOPLEFT", 150, -316)
  self.noteBox:SetText(c.note or "")

  local create = button(box, "Create & Broadcast Listing", 210, 30)
  create:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -18, 18)
  create:SetScript("OnClick", function() BLFG:CreateListing() end)
  if self.UpdateCreateControls then self:UpdateCreateControls() end
end

function BLFG:UpdateCreateControls()
  if not self.typeDrop or not self.activityDrop then return end
  local t = dd(self.typeDrop)
  local activity = dd(self.activityDrop)
  local diff = self.diffDrop and dd(self.diffDrop) or ""
  local diffs = BLFG_CreateDifficultyListFor(t, activity)
  local validDiff = false
  for _, v in ipairs(diffs) do if v == diff then validDiff = true; break end end
  if self.diffDrop and not validDiff then
    diff = diffs[1]
    setDD(self.diffDrop, diffs, diff)
  elseif self.diffDrop then
    self.diffDrop.values = diffs
  end
  if self.maxBox then self.maxBox:SetText(tostring(BLFG_DefaultMaxMembersFor(t, activity, diff))) end
  local dungeonList = BLFG_DungeonListForMode(activity)
  if self.specificDungeonLabel and self.specificDungeonDrop then
    if dungeonList and #dungeonList > 0 then
      self.specificDungeonLabel:Show()
      self.specificDungeonDrop:Show()
      self.specificDungeonDrop.values = dungeonList
      local selectedDungeon = dd(self.specificDungeonDrop)
      if not BLFG_ListContainsValue(dungeonList, selectedDungeon) then
        selectedDungeon = BronzeLFG_DB.create and BronzeLFG_DB.create.specificDungeon or nil
        if not BLFG_ListContainsValue(dungeonList, selectedDungeon) then selectedDungeon = dungeonList[1] end
        setDD(self.specificDungeonDrop, dungeonList, selectedDungeon)
      end
    else
      self.specificDungeonLabel:Hide()
      self.specificDungeonDrop:Hide()
    end
  end
  local keyAllowed = (t == "Dungeon" and diff == "Mythic+" and BLFG_ActivitySupportsKeyLevel(activity))
  if self.keyLabel then if keyAllowed then self.keyLabel:Show() else self.keyLabel:Hide() end end
  if self.keyBox then
    if keyAllowed then
      self.keyBox:Show(); self.keyBox:EnableMouse(true); self.keyBox:SetTextColor(1,1,1)
    else
      self.keyBox:SetText(""); self.keyBox:EnableMouse(false); self.keyBox:SetTextColor(.45,.45,.45); self.keyBox:Hide()
    end
  end
  if self.useKeystoneButton then
    if keyAllowed then
      self.useKeystoneButton:Show()
      self.useKeystoneButton:Enable()
    else
      self.useKeystoneButton:Disable()
      self.useKeystoneButton:Hide()
    end
  end
end

function BLFG:FindInventoryKeystone()
  if not GetContainerNumSlots or not GetContainerItemLink or not GetItemInfo then return nil end
  for bag = 0, 4 do
    local slots = GetContainerNumSlots(bag) or 0
    for slot = 1, slots do
      local link = GetContainerItemLink(bag, slot)
      if link then
        local itemName = GetItemInfo(link)
        itemName = itemName or string.match(link, "%[(.-)%]")
        if itemName then
          local dungeon, level = string.match(itemName, "^Mythic Keystone:%s*(.-)%s*%+(%d+)$")
          if dungeon and level then
            return dungeon, level, link
          end
        end
      end
    end
  end
  return nil
end

function BLFG:UseInventoryKeystoneForCreate()
  local dungeon, level = self:FindInventoryKeystone()
  if not dungeon then
    msg("No Mythic Keystone found in your bags.", 1, .82, .35)
    return
  end
  local mode = BLFG_DungeonModeForActivity(dungeon)
  if not mode then
    msg("Found keystone for " .. dungeon .. ", but that dungeon is not in the active profile.", 1, .35, .35)
    return
  end
  if self.typeDrop then setDD(self.typeDrop, ACTIVITY_TYPES, "Dungeon") end
  if self.activityDrop then setDD(self.activityDrop, listForType("Dungeon"), mode) end
  if self.specificDungeonDrop then setDD(self.specificDungeonDrop, BLFG_DungeonListForMode(mode), dungeon) end
  if self.diffDrop then setDD(self.diffDrop, BLFG_CreateDifficultyListFor("Dungeon", mode), "Mythic+") end
  if self.keyBox then self.keyBox:SetText(tostring(level or "")) end
  if self.maxBox then self.maxBox:SetText("5") end
  if self.UpdateCreateControls then self:UpdateCreateControls() end
  msg("Loaded keystone: " .. dungeon .. " +" .. tostring(level) .. ".", .55, .9, 1)
end

function BLFG:BuildProfile()
  local p = CreateFrame("Frame", nil, self.content)
  self.profile = p
  p:SetAllPoints(); p:Hide()
  font(p, "Application Profile", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 10, -4)

  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(760); box:SetHeight(470)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 8, -44)
  backdrop(box, .96)
  local pr = BronzeLFG_DB.profile

  font(box, "These details are sent when you apply to a group.", 11, 1, 1, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -30)
  font(box, "Role", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -82)
  self.profileRole = dropdown(box, "BLFGProfileRole3", 135, ROLES, pr.role or "DPS", function()
    if BLFG.UpdateWhisperPreview569 then BLFG:UpdateWhisperPreview569() end
  end)
  self.profileRole:SetPoint("TOPLEFT", box, "TOPLEFT", 170, -78)

  font(box, "Class", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -105)
  self.profileClassText = font(box, select(1, UnitClass("player")) or "", 10, .55, .8, 1)
  self.profileClassText:SetPoint("TOPLEFT", box, "TOPLEFT", 170, -104)
  self.profileClassText:SetWidth(160)

  font(box, "Item Level", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -128)
  self.profileIlvl = edit(box, 90, 24, false)
  self.profileIlvl:SetPoint("TOPLEFT", box, "TOPLEFT", 170, -124)
  self.profileIlvl:SetText(pr.itemLevel or "")
  self.profileIlvl:SetAutoFocus(false)
  self.profileIlvl:EnableMouse(false)
  self.profileIlvl:SetTextColor(.75, .75, .75)
  self.profileIlvl:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)

  font(box, "Specialization", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -174)
  self.profileRoleType = edit(box, 150, 24, false)
  self.profileRoleType:SetPoint("TOPLEFT", box, "TOPLEFT", 170, -170)
  self.profileRoleType:SetText(pr.roleType or "")
  self.profileRoleType:SetScript("OnTextChanged", function() if BLFG.UpdateWhisperPreview569 then BLFG:UpdateWhisperPreview569() end end)
  font(box, "optional", 9, .75, .75, .75):SetPoint("LEFT", self.profileRoleType, "RIGHT", 8, 0)

  self.profileDiscord = CreateFrame("CheckButton", "BLFGProfileDiscord3", box, "UICheckButtonTemplate")
  self.profileDiscord:SetPoint("TOPLEFT", box, "TOPLEFT", 165, -216)
  _G[self.profileDiscord:GetName().."Text"]:SetText("Discord Ready")
  self.profileDiscord:SetChecked(pr.discord)

  font(box, "Applicant Note", 11, 1, .82, .35):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -272)
  self.profileNote = edit(box, 520, 90, true)
  self.profileNote:SetPoint("TOPLEFT", box, "TOPLEFT", 170, -268)
  self.profileNote:SetText(pr.note or "")

  local save = button(box, "Save Profile", 130, 30)
  save:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -18, 18)
  save:SetScript("OnClick", function() BLFG:SaveProfile() end)

  local reset = button(box, "Clear Role/Spec", 130, 30)
  reset:SetPoint("RIGHT", save, "LEFT", -12, 0)
  reset:SetScript("OnClick", function() BLFG:ClearProfileRoleSpec() end)
end

function BLFG:BuildApplicants()
  local p = CreateFrame("Frame", nil, self.content)
  self.apps = p
  p:SetAllPoints(); p:Hide()
  font(p, "Applicants", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  font(p, "Review applicants for your active listing.", 10, .8, .8, .8):SetPoint("TOPLEFT", p, "TOPLEFT", 6, -24)

  local list = CreateFrame("Frame", nil, p)
  list:SetWidth(540); list:SetHeight(470)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  backdrop(list, .96)

  local h = CreateFrame("Frame", nil, list)
  h:SetWidth(525); h:SetHeight(24); h:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -7)
  flat(h, .95)
  font(h, "Name", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 8, 0)
  font(h, "Class", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 145, 0)
  font(h, "Role", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 235, 0)
  font(h, "Spec", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 300, 0)
  font(h, "Lvl", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 370, 0)
  font(h, "iLvl", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 415, 0)
  font(h, "Note", 10, .95, .82, .35):SetPoint("LEFT", h, "LEFT", 465, 0)

  self.appRows = {}
  for i=1,8 do
    local r = CreateFrame("Button", nil, list)
    r:SetWidth(525); r:SetHeight(40)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -36 - ((i-1)*44))
    flat(r, .85)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.name = font(r, "", 11, 1, .55, 1); r.name:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetWidth(18); r.icon:SetHeight(18); r.icon:SetPoint("LEFT", r, "LEFT", 120, 0)
    r.class = font(r, "", 10, 1, .82, .5); r.class:SetPoint("LEFT", r, "LEFT", 145, 0)
    r.role = font(r, "", 10, 1, 1, 1); r.role:SetPoint("LEFT", r, "LEFT", 235, 0)
    r.level = font(r, "", 10, 1, 1, 1); r.spec=font(r,"",9,.8,.8,.8); r.spec:SetPoint("LEFT",r,"LEFT",300,0)
    r.level:SetPoint("LEFT", r, "LEFT", 370, 0)
    r.ilvl = font(r, "", 10, 1, 1, 1); r.ilvl:SetPoint("LEFT", r, "LEFT", 415, 0)
    r.note = font(r, "", 9, .8, .8, .8); r.note:SetPoint("LEFT", r, "LEFT", 465, 0); r.note:SetWidth(55)
    r:SetScript("OnClick", function(self) BLFG.selectedApplicant = self.key; BLFG:RefreshApplicants(); BLFG:RefreshApplicantDetail() end)
    self.appRows[i] = r
  end

  local cancelListing = button(list, "Cancel Listing", 135, 28)
  cancelListing:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 12, 14)
  cancelListing:SetScript("OnClick", function() BLFG:CancelMyListing("manual") end)

  local d = CreateFrame("Frame", nil, p)
  self.appDetail = d
  d:SetWidth(270); d:SetHeight(470)
  d:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -40)
  backdrop(d, .96)

  d.portrait = d:CreateTexture(nil, "ARTWORK")
  d.portrait:SetWidth(58); d.portrait:SetHeight(58)
  d.portrait:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -14)
  d.portrait:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
  d.name = font(d, "No Applicants Yet", 15, 1, .55, 1)
  d.name:SetPoint("TOPLEFT", d, "TOPLEFT", 84, -18)
  d.sub = font(d, "", 10, 1, .9, .6)
  d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
  d.info = font(d, "Applicants will appear here when players apply to your listing.", 10, 1, 1, 1)
  d.info:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -95)
  d.info:SetWidth(240); d.info:SetJustifyH("LEFT")
  d.note = font(d, "", 10, 1, 1, 1)
  d.note:SetPoint("TOPLEFT", d, "TOPLEFT", 14, -245)
  d.note:SetWidth(240); d.note:SetJustifyH("LEFT")
  d.accept = button(d, "Accept", 75, 28)
  d.accept:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 12)
  d.accept:SetScript("OnClick", function() BLFG:AcceptSelected() end)
  d.whisper = button(d, "Whisper", 75, 28)
  d.whisper:SetPoint("LEFT", d.accept, "RIGHT", 8, 0)
  d.whisper:SetScript("OnClick", function()
    local a = BLFG.applicants[BLFG.selectedApplicant]
    if a then SendChatMessage("Hi! Following up on your SignalFire application.", "WHISPER", nil, a.name) end
  end)
  d.decline = button(d, "Decline", 75, 28)
  d.decline:SetPoint("LEFT", d.whisper, "RIGHT", 8, 0)
  d.decline:SetScript("OnClick", function() BLFG:DeclineSelected() end)
end


function BLFG:BuildMyListing()
  local p = CreateFrame("Frame", nil, self.content)
  self.myPanel = p
  p:SetAllPoints()
  p:Hide()

  font(p, "My Listing", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)

  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(820); box:SetHeight(470)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  backdrop(box, .96)

  self.myTitle = font(box, "No active listing", 16, .95, .4, 1)
  self.myTitle:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -20)

  self.myBody = font(box, "You do not currently have an active listing.", 11, 1, 1, 1)
  self.myBody:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -65)
  self.myBody:SetWidth(700)
  self.myBody:SetJustifyH("LEFT")

  local cancel = button(box, "Cancel Listing", 140, 30)
  cancel:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -18, 18)
  cancel:SetScript("OnClick", function() BLFG:CancelMyListing("manual") end)

  local apps = button(box, "View Applicants", 130, 30)
  apps:SetPoint("RIGHT", cancel, "LEFT", -12, 0)
  apps:SetScript("OnClick", function() BLFG:ShowApplicants() end)

  local refresh = button(box, "Refresh Listing", 130, 30)
  refresh:SetPoint("RIGHT", apps, "LEFT", -12, 0)
  refresh:SetScript("OnClick", function() BLFG:Broadcast(); BLFG:RefreshMyListing(); flash("Listing refreshed.") end)
end

function BLFG:ShowMyListing()
  self:CreateUI()
  self:HidePanels()
  self.myPanel:Show()
  self.frame:Show()
  self:RefreshMyListing()
end

function BLFG:ApplicantCountForListing(listingId)
  local n = 0
  if not listingId then return 0 end
  for _, a in pairs(self.applicants or {}) do
    if a and a.listingId == listingId then n = n + 1 end
  end
  return n
end

function BLFG:RefreshMyListing()
  if not self.myPanel then return end
  local l = self.myListing
  if not l then
    self.myTitle:SetText("No active listing")
    self.myBody:SetText("You do not currently have an active listing. Create one from the Create Listing tab.")
    return
  end
  local diff = l.difficulty or ""
  if diff == "Mythic+" and l.key and l.key ~= "" then diff = diff .. " " .. l.key end
  self.myTitle:SetText("|cffb84dff" .. (l.activity or "Active Listing") .. "|r")
  self.myBody:SetText(
    "|cffffcc00Type:|r " .. (l.type or "") ..
    "\n|cffffcc00Difficulty:|r " .. diff ..
    "\n|cffffcc00SignalFire Network:|r " .. (l.members or 1) .. " / " .. (l.maxMembers or 5) ..
    "\n|cffffcc00Applicants:|r " .. self:ApplicantCountForListing(l.id) ..
    "\n|cffffcc00Roles Needed:|r " .. rolesNeeded(l) ..
    "\n|cffffcc00Voice Chat:|r " .. (l.voice or "None") ..
    "\n|cffffcc00Loot Method:|r " .. (l.loot or "Group Loot") ..
    "\n\n|cffffcc00Note:|r\n" .. (l.note or "")
  )
end

function BLFG:RemovePublicMirrorForListing(listingId)
  if not listingId or not self.publicGroups then return end
  for id, row in pairs(self.publicGroups) do
    if id == "listing-" .. tostring(listingId) or (row and row.listingId == listingId) then
      self.publicGroups[id] = nil
    end
  end
  if self.selectedPublicGroup == "listing-" .. tostring(listingId) then self.selectedPublicGroup = nil end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

function BLFG:CancelMyListing(reason)
  if not self.myListing then
    msg("No active listing to cancel.")
    return
  end
  local id = self.myListing.id
  local activity = self.myListing.activity or "listing"
  self.listings[id] = nil
  self:RemovePublicMirrorForListing(id)
  self.myListing = nil
  self.selectedListing = nil
  self:SaveMyListingState()
  sendChan(serializeRemove(id))
  if reason == "full" then
    flash("Listing auto-closed because the group is full: " .. activity)
  else
    flash("Listing canceled: " .. activity)
  end
  self:RefreshBrowse()
  self:RefreshMyListing()
end

function BLFG:CheckAutoCloseListing()
  if not self.myListing then return end
  self.myListing.members = memberCount()
  local max = tonumber(self.myListing.maxMembers or 0) or 0
  if max > 0 and self.myListing.members >= max then
    self:CancelMyListing("full")
  else
    self:SaveMyListingState()
  end
end

function BLFG:SaveMyListingState()
  BronzeLFG_DB = BronzeLFG_DB or {}
  if self.myListing and self.myListing.id then
    BronzeLFG_DB.myListing = self.myListing
  else
    BronzeLFG_DB.myListing = nil
  end
end

function BLFG:RestoreMyListingState()
  if self._restoredMyListingState then return end
  self._restoredMyListingState = true
  BronzeLFG_DB = BronzeLFG_DB or {}
  local l = BronzeLFG_DB.myListing
  if type(l) ~= "table" or not l.id then return end
  if l.leader and l.leader ~= playerName() then
    BronzeLFG_DB.myListing = nil
    return
  end
  l.members = memberCount()
  l.seen = l.seen or now()
  l.created = l.created or l.seen
  self.myListing = l
  self.listings = self.listings or {}
  self.listings[l.id] = l
  self.selectedListing = l.id
  if self.MirrorListingToPublic then self:MirrorListingToPublic(l) end
end






local PUBLIC_HIDE_TYPES = {"Other", "Social", "Guild", "LFG", "Event", "Raid", "Dungeon", "Key"}

local function publicHiddenTypes()
  BronzeLFG_DB.publicHiddenTypes = BronzeLFG_DB.publicHiddenTypes or {}
  return BronzeLFG_DB.publicHiddenTypes
end

local function publicHiddenTypeCount()
  local hidden = publicHiddenTypes()
  local n = 0
  for _, t in ipairs(PUBLIC_HIDE_TYPES) do
    if hidden[t] then n = n + 1 end
  end
  return n
end

local function publicHideTypesButtonText()
  local n = publicHiddenTypeCount()
  if n <= 0 then return "Hide Types: 0" end
  return "Hide Types: " .. tostring(n)
end

function BLFG:IsPublicTypeHidden(t)
  local hidden = publicHiddenTypes()
  return hidden[tostring(t or "Other")] == true
end

function BLFG:ShowPublicHideTypesMenu(anchor)
  if not self.publicHideTypesDropdown then
    local f = CreateFrame("Frame", "BronzeLFGPublicHideTypesDropdown", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(150)
    f:SetHeight(220)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = {left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(0,0,0,.95)
    f.buttons = {}

    local title = font(f, "Hide on All", 10, 1, .82, 0)
    title:SetPoint("TOP", f, "TOP", 0, -8)

    for i,opt in ipairs(PUBLIC_HIDE_TYPES) do
      local b = button(f, opt, 132, 19)
      b:SetPoint("TOP", f, "TOP", 0, -26 - ((i-1)*20))
      b.typeName = opt
      b:SetScript("OnClick", function(self)
        local hidden = publicHiddenTypes()
        hidden[self.typeName] = not hidden[self.typeName] or nil
        BLFG.publicHideOther = hidden["Other"] == true
        BLFG.publicPage = 1
        BLFG:RefreshPublicGroups()
        if BLFG.publicHideTypesDropdown and BLFG.publicHideTypesDropdown.RefreshLabels then
          BLFG.publicHideTypesDropdown:RefreshLabels()
        end
      end)
      f.buttons[i] = b
    end

    local clear = button(f, "Show All Types", 132, 20)
    clear:SetPoint("BOTTOM", f, "BOTTOM", 0, 7)
    clear:SetScript("OnClick", function()
      BronzeLFG_DB.publicHiddenTypes = {}
      BLFG.publicHideOther = false
      BLFG.publicPage = 1
      BLFG:RefreshPublicGroups()
      f:Hide()
    end)
    f.clear = clear

    f.RefreshLabels = function(self)
      local hidden = publicHiddenTypes()
      for _, b in ipairs(self.buttons or {}) do
        local checked = hidden[b.typeName] == true
        b:SetText((checked and "|cff66ff66âœ“ |r" or "   ") .. tostring(b.typeName))
      end
      if BLFG.publicHideOtherButton then BLFG.publicHideOtherButton:SetText(publicHideTypesButtonText()) end
    end

    f:Hide()
    self.publicHideTypesDropdown = f
  end

  local f = self.publicHideTypesDropdown
  if f:IsShown() then f:Hide(); return end
  if f.RefreshLabels then f:RefreshLabels() end
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  f:Show()
end

function BLFG:ShowPublicSortMenu(anchor)
  if not self.publicSortDropdown then
    local f = CreateFrame("Frame", "BronzeLFGPublicSortDropdown", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(145)
    f:SetHeight(104)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = {left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(0,0,0,.95)
    local modes = {"Newest", "Type", "Activity", "Player"}
    f.buttons = {}
    for i,opt in ipairs(modes) do
      local b = button(f, opt, 130, 20)
      b:SetPoint("TOP", f, "TOP", 0, -6 - ((i-1)*23))
      b:SetScript("OnClick", function()
        BLFG.publicSortMode = opt
        BLFG.publicPage = 1
        f:Hide()
        BLFG:RefreshPublicGroups()
      end)
      f.buttons[i] = b
    end
    f:Hide()
    self.publicSortDropdown = f
  end
  local f = self.publicSortDropdown
  if f:IsShown() then f:Hide(); return end
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  f:Show()
end

function BLFG:BuildPublicGroups()
  local p = CreateFrame("Frame", nil, self.content)
  self.publicPanel = p
  p:SetAllPoints()
  p:Hide()

  font(p, "Public Groups", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  self.publicCountText = font(p, "Listings: 0  |  Results: 0  |  SignalFire Network: 0", 10, .65, .85, 1)
  self.publicCountText:SetPoint("TOP", p, "TOP", 0, -24)
  self.publicCountText:SetWidth(520)
  self.publicCountText:SetJustifyH("CENTER")

  font(p, "Search", 10, .65, .85, 1):SetPoint("TOPRIGHT", p, "TOPRIGHT", -248, -92)
  self.publicSearch = edit(p, 230, 22, false)
  self.publicSearch:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -87)
  self.publicSearch:SetScript("OnTextChanged", function(self)
    BLFG.publicSearchText = self:GetText() or ""
    BLFG.publicPage = 1
    BLFG:RefreshPublicGroups()
  end)
  self.publicSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  self.publicFilter = self.publicFilter or "All"
  self.publicFilterButtons = {}
  local publicFilters = {"All", "Dungeon", "Raid", "Key", "Event", "Guild", "LFG", "Social"}
  local publicFilterWidths = {All=62, Dungeon=98, Raid=78, Key=72, Event=86, Guild=84, LFG=70, Social=86}
  local fx = 38
  for _, f in ipairs(publicFilters) do
    local bw = publicFilterWidths[f] or 76
    local fb = button(p, f, bw, 22)
    fb:SetPoint("TOPLEFT", p, "TOPLEFT", fx, -36)
    fb:SetScript("OnClick", function()
      BLFG.publicFilter = f
      BLFG.publicPage = 1
      BLFG:RefreshPublicGroups()
    end)
    self.publicFilterButtons[f] = fb
    fx = fx + bw + 8
  end

  font(p, "Need", 10, .65, .85, 1):SetPoint("TOPLEFT", p, "TOPLEFT", 38, -92)
  self.publicRoleFilter = self.publicRoleFilter or "All"
  self.publicRoleFilterButtons = {}
  local roleFilters = {{"All", 48}, {"T", 34}, {"H", 34}, {"D", 34}}
  local rx = 78
  for _, rf in ipairs(roleFilters) do
    local key, bw = rf[1], rf[2]
    local rb = button(p, key, bw, 22)
    rb:SetPoint("TOPLEFT", p, "TOPLEFT", rx, -87)
    rb:SetScript("OnClick", function()
      BLFG.publicRoleFilter = key
      BLFG.publicPage = 1
      BLFG:RefreshPublicGroups()
    end)
    self.publicRoleFilterButtons[key] = rb
    rx = rx + bw + 6
  end

  self.onlinePanelButton = button(p, "Recent Recruitment Message", 120, 22)
  self.onlinePanelButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -64)
  self.onlinePanelButton:SetScript("OnClick", function() BLFG:ToggleOnlinePanel() end)

  self.publicHideOther = self.publicHideOther or false
  BronzeLFG_DB.publicHiddenTypes = BronzeLFG_DB.publicHiddenTypes or {}
  if self.publicHideOther == true then BronzeLFG_DB.publicHiddenTypes["Other"] = true end
  self.publicHideOtherButton = button(p, "Hide Types: 0", 130, 22)
  self.publicHideOtherButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -160, -64)
  self.publicHideOtherButton:SetScript("OnClick", function()
    BLFG:ShowPublicHideTypesMenu(self.publicHideOtherButton)
  end)

  self.publicSortMode = self.publicSortMode or "Newest"
  self.publicSortButton = button(p, "Sort: Newest", 130, 22)
  self.publicSortButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -318, -64)
  self.publicSortButton:SetScript("OnClick", function()
    BLFG:ShowPublicSortMenu(self.publicSortButton)
  end)

  local list = CreateFrame("Frame", nil, p)
  self.publicList = list
  list:SetWidth(820); list:SetHeight(389)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -122)
  backdrop(list, .96)
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(_, delta)
    BLFG:ScrollPublicGroups(delta)
  end)

  local h = CreateFrame("Frame", nil, list)
  h:SetWidth(805); h:SetHeight(24)
  h:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -7)
  flat(h, .95)
  font(h, "Player", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 8, 0)
  font(h, "Time", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 112, 0)
  font(h, "Type", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 205, 0)
  font(h, "Activity", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 305, 0)
  font(h, "Roles", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 510, 0)
  font(h, "Message", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 585, 0)

  self.publicRows = {}
  for i=1,8 do
    local r = CreateFrame("Button", nil, list)
    -- Full-width row so hover/click/highlight includes the Message column.
    r:SetWidth(805); r:SetHeight(34)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -36 - ((i-1)*37))
    flat(r, .80)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.player = font(r, "", 10, .65, .85, 1); r.player:SetPoint("LEFT", r, "LEFT", 8, 0)
    r.time = font(r, "", 10, .8, .8, .8); r.time:SetPoint("LEFT", r, "LEFT", 112, 0); r.time:SetWidth(88); r.time:SetJustifyH("LEFT")
    r.type = font(r, "", 10, .3, 1, .3); r.type:SetPoint("LEFT", r, "LEFT", 205, 0); r.type:SetWidth(95); r.type:SetJustifyH("LEFT")
    r.activity = font(r, "", 10, 1, 1, 1); r.activity:SetPoint("LEFT", r, "LEFT", 305, 0); r.activity:SetWidth(195); r.activity:SetJustifyH("LEFT")
    r.roles = font(r, "", 10, 1, 1, 1); r.roles:SetPoint("LEFT", r, "LEFT", 510, 0); r.roles:SetWidth(70); r.roles:SetJustifyH("LEFT")
    r.message = font(r, "", 10, 1, 1, 1); r.message:SetPoint("LEFT", r, "LEFT", 585, 0); r.message:SetWidth(205); r.message:SetJustifyH("LEFT")
    r:SetScript("OnClick", function(self)
      BLFG.selectedPublic = self.key
      BLFG:RefreshPublicGroups()
    end)
    r:SetScript("OnDoubleClick", function(self)
      BLFG.selectedPublic = self.key
      BLFG:RefreshPublicGroups()
    end)
    r:SetScript("OnEnter", function(self)
      if self.fullMessage and self.fullMessage ~= "" then
        local lookup = BLFG_PublicPlayerLookup(BLFG, self.fullPlayer)
        if lookup then
          if not self.fullPlayerLevel or self.fullPlayerLevel == "" then self.fullPlayerLevel = lookup.level end
          if not self.fullPlayerClass or self.fullPlayerClass == "" then self.fullPlayerClass = lookup.classFile end
          if not self.fullPlayerGuild or self.fullPlayerGuild == "" then self.fullPlayerGuild = lookup.guild end
          if not self.fullPlayerZone or self.fullPlayerZone == "" then self.fullPlayerZone = lookup.zone end
          if not self.fullPlayerInfoSource or self.fullPlayerInfoSource == "" then self.fullPlayerInfoSource = lookup.source end
        elseif BLFG and BLFG.RequestPublicPlayerWho and self.fullPlayer and self.fullPlayer ~= "" and not (self.fullPlayerLevel and self.fullPlayerLevel ~= "") then
          BLFG:RequestPublicPlayerWho(self.fullPlayer)
        end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:ClearLines()
        GameTooltip:SetText("|cFFFFCC00SignalFire|r", 1, .82, 0)
        GameTooltip:AddLine("|cFFFFCC00Recruiter:|r |cFFFFFFFF" .. (self.fullPlayer or "Unknown") .. "|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        if self.fullActivity and self.fullActivity ~= "" and self.fullActivity ~= "Unknown" then
          GameTooltip:AddLine("|cFFFFCC00Activity:|r |cFFFFFFFF" .. self.fullActivity .. "|r", 1, 1, 1)
        else
          GameTooltip:AddLine("|cFFFFCC00Activity:|r |cFFAAAAAAUnknown|r", 1, 1, 1)
        end
        if self.fullType and self.fullType ~= "" then
          local c = publicTypeColor(self.fullType)
          GameTooltip:AddLine("|cFFFFCC00Category:|r " .. publicTypeLabel(self.fullType), 1, 1, 1)
          if self.fullType == "Guild" then
            local gn = extractGuildNameFromPost({message=self.fullMessage, player=self.fullPlayer})
            if gn and gn ~= "" then GameTooltip:AddLine("|cFFFFCC00Guild:|r |cFFFFFFFF" .. gn .. "|r", 1, 1, 1) end
          end
        end
        if self.fullIntent and self.fullIntent ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Intent:|r |cFFFFFFFF" .. self.fullIntent .. "|r", 1, 1, 1)
        end
        if self.fullPlayerLevel and self.fullPlayerLevel ~= "" then
          local details = "Level " .. tostring(self.fullPlayerLevel)
          if self.fullPlayerClass and self.fullPlayerClass ~= "" then details = details .. " " .. tostring(self.fullPlayerClass) end
          if self.fullPlayerSpec and self.fullPlayerSpec ~= "" then details = details .. " - " .. tostring(self.fullPlayerSpec) end
          GameTooltip:AddLine("|cFFFFCC00Player:|r |cFFFFFFFF" .. details .. "|r", 1, 1, 1)
        elseif self.fullPlayerClass and self.fullPlayerClass ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Player:|r |cFFFFFFFF" .. tostring(self.fullPlayerClass) .. "|r", 1, 1, 1)
        end
        if self.fullPlayerRole and self.fullPlayerRole ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Profile Role:|r |cFFFFFFFF" .. tostring(self.fullPlayerRole) .. "|r", 1, 1, 1)
        end
        if self.fullPlayerGuild and self.fullPlayerGuild ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Guild:|r |cFFFFFFFF" .. tostring(self.fullPlayerGuild) .. "|r", 1, 1, 1)
        end
        if self.fullPlayerZone and self.fullPlayerZone ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Zone:|r |cFFFFFFFF" .. tostring(self.fullPlayerZone) .. "|r", 1, 1, 1)
        end
        if self.fullPlayerInfoSource and self.fullPlayerInfoSource ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Player Info:|r |cFFAAAAAA" .. tostring(self.fullPlayerInfoSource) .. "|r", 1, 1, 1)
        elseif BLFG and BLFG.publicPlayerWho and BLFG.publicPlayerWho.active and BLFG.publicPlayerWho.pendingName == self.fullPlayer then
          GameTooltip:AddLine("|cFFFFCC00Player Info:|r |cFFAAAAAAlooking up...|r", 1, 1, 1)
        elseif BLFG and BLFG.publicPlayerWho and BLFG.publicPlayerWho.finalResult and self.fullPlayer and BLFG.publicPlayerWho.finalResult[string.lower(self.fullPlayer)] and (now() - (tonumber(BLFG.publicPlayerWho.finalResult[string.lower(self.fullPlayer)] or 0) or 0)) < 20 then
          GameTooltip:AddLine("|cFFFFCC00Player Info:|r |cFFAAAAAAnot seen yet|r", 1, 1, 1)
        end
        if self.fullRoles and self.fullRoles ~= "" and self.fullRoles ~= "Not detected" then
          local roleLabel = "Roles Needed"
          if self.fullIntent == "Applicant" or self.fullType == "LFG" then roleLabel = "Player Role" end
          GameTooltip:AddLine("|cFFFFCC00" .. roleLabel .. ":|r " .. self.fullRoles, 1, 1, 1)
        end
        if self.fullTags and self.fullTags ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Tags:|r |cFFFFFFFF" .. self.fullTags .. "|r", 1, 1, 1)
        end
        if self.fullILevel and self.fullILevel ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Detected iLvl:|r |cFFFFFFFF" .. self.fullILevel .. "|r", 1, 1, 1)
        end
        if self.fullTime and self.fullTime ~= "" then
          GameTooltip:AddLine("|cFFFFCC00Posted:|r |cFFFFFFFF" .. self.fullTime .. "|r", 1, 1, 1)
        end
        local channelText = tostring(self.fullChannel or "")
        if channelText ~= "" and channelText ~= "0" then
          GameTooltip:AddLine("|cFFFFCC00Source:|r |cFFAAAAAA" .. channelText .. "|r", 1, 1, 1)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cFFFFCC00Listing:|r", 1, .82, 0)
        GameTooltip:AddLine(self.fullMessage, 1, 1, 1, true)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    self.publicRows[i] = r
  end

  self.publicPageText = font(list, "Page 1 / 1", 10, 1, .82, 0)
  self.publicPageText:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 174, 18)

  local up = button(list, "Up", 70, 26)
  up:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 12, 12)
  up:SetScript("OnClick", function() BLFG:ScrollPublicGroups(1) end)

  local down = button(list, "Down", 70, 26)
  down:SetPoint("LEFT", up, "RIGHT", 8, 0)
  down:SetScript("OnClick", function() BLFG:ScrollPublicGroups(-1) end)

  local whisper = button(list, "Apply Selected", 145, 28)
  whisper:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -12, 12)
  whisper:SetScript("OnClick", function() BLFG:WhisperPublicSelected() end)

  local clear = button(list, "Clear Public Groups", 150, 28)
  clear:SetPoint("RIGHT", whisper, "LEFT", -12, 0)
  clear:SetScript("OnClick", function()
    BLFG:ClearPublicGroups()
  end)
end

function BLFG:ShowPublicGroups()
  self:CreateUI()
  self:HidePanels()
  self.publicPanel:Show()
  self.frame:Show()
  self:RefreshPublicGroups()
end

local function publicMatchesFilter(g, filter)
  filter = filter or "All"
  if filter == "Ascended" then filter = "Raid" end
  if filter == "Boss Blitz" then filter = "Event" end
  if filter == "All" then return true end
  if filter == "Event" then return (g.type == "Event" or g.activity == "Event" or g.activity == "Seasonal Event" or (g.tags and string.find(g.tags, "Boss Blitz", 1, true))) end
  if filter == "Guild" then return (g.type == "Guild" or g.activity == "Guild Recruitment") end
  if filter == "LFG" then return (g.type == "LFG" or g.intent == "Applicant") end
  if filter == "Social" then return (g.type == "Social" or g.intent == "Social") end
  return g.type == filter
end

function BLFG:GetPublicFilterCounts()
  local counts = {All=0, Dungeon=0, Raid=0, Key=0, Event=0, Guild=0, LFG=0, Social=0}
  for _, g in pairs(self.publicGroups or {}) do
    if g.message and not BronzeLFG_IsAddonSpam(g.message) then
      counts.All = counts.All + 1
      if g.type == "Dungeon" then counts.Dungeon = counts.Dungeon + 1 end
      if g.type == "Raid" then counts.Raid = counts.Raid + 1 end
      if g.type == "Key" then counts.Key = counts.Key + 1 end
      if g.type == "Event" or g.activity == "Event" or g.activity == "Seasonal Event" or (g.tags and string.find(g.tags, "Boss Blitz", 1, true)) then counts.Event = counts.Event + 1 end
      if g.type == "Guild" or g.activity == "Guild Recruitment" then counts.Guild = counts.Guild + 1 end
      if g.type == "LFG" or g.intent == "Applicant" then counts.LFG = counts.LFG + 1 end
      if g.type == "Social" or g.intent == "Social" then counts.Social = counts.Social + 1 end
    end
  end
  return counts
end

local function publicMatchesSearch(g, query)
  query = lower(query or "")
  if query == "" then return true end
  local hay = table.concat({
    tostring(g.player or ""), tostring(g.type or ""), tostring(g.activity or ""),
    tostring(g.message or ""), tostring(g.intent or ""), tostring(g.roles or ""),
    tostring(g.tags or ""), tostring(g.channel or "")
  }, " ")
  return string.find(lower(hay), query, 1, true) ~= nil
end

local function publicMatchesRoleFilter(g, filter)
  filter = filter or "All"
  if filter == "All" then return true end
  local roles = compactRoleText((g and g.roles) or "")
  if filter == "T" then return string.find(roles, "T", 1, true) ~= nil end
  if filter == "H" then return string.find(roles, "H", 1, true) ~= nil end
  if filter == "D" then return string.find(roles, "D", 1, true) ~= nil end
  return true
end

function BLFG_PublicStableTime(g)
  if not g then return now() end
  local t = tonumber(g.firstSeen or 0) or 0
  if t <= 0 then t = tonumber(g.created or 0) or 0 end
  if t <= 0 then t = tonumber(g.seen or 0) or 0 end
  if t <= 0 then t = now() end
  g.firstSeen = g.firstSeen or t
  g.created = g.created or t
  return t
end

local function BLFG_PublicCleanPlayerName(name)
  name = tostring(name or "")
  name = string.gsub(name, "%-.*$", "")
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  return name
end

function BLFG_PublicPlayerLookup(self, name)
  name = BLFG_PublicCleanPlayerName(name)
  if name == "" then return nil end
  local key = string.lower(name)
  if key == string.lower(playerName()) then
    local _, cf = playerClass()
    return {name=playerName(), level=tostring(playerLevel()), classFile=cf or "", role=(BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.role) or "", spec=(BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.roleType) or "", zone=currentZoneText(), guild=myGuildName(), source="You"}
  end
  for n, u in pairs((self and self.onlineUsers) or {}) do
    if string.lower(string.gsub(tostring(n or ""), "%-.*", "")) == key or string.lower(string.gsub(tostring(u and u.name or ""), "%-.*", "")) == key then
      u.source = "SignalFire Network"
      return u
    end
  end
  local who = self and self.EnsureWhoPlayerDB and self:EnsureWhoPlayerDB() or nil
  if who and who[key] then
    who[key].source = "/who"
    return who[key]
  end
  return nil
end

function BLFG_EnrichPublicGroup(self, g)
  if not g then return g end
  BLFG_PublicStableTime(g)
  local u = BLFG_PublicPlayerLookup(self, g.player)
  if not u then return g end
  if not g.playerLevel or g.playerLevel == "" then g.playerLevel = u.level end
  if not g.playerClassFile or g.playerClassFile == "" then g.playerClassFile = u.classFile end
  if not g.playerClass or g.playerClass == "" then g.playerClass = u.class end
  if not g.playerRole or g.playerRole == "" then g.playerRole = u.role end
  if not g.playerSpec or g.playerSpec == "" then g.playerSpec = u.spec end
  if not g.playerZone or g.playerZone == "" then g.playerZone = u.zone end
  if not g.playerGuild or g.playerGuild == "" then g.playerGuild = u.guild end
  if not g.playerInfoSource or g.playerInfoSource == "" then g.playerInfoSource = u.source end
  return g
end

function BLFG:GetSortedPublicGroups()
  self:ExpirePublicGroups()
  local rows = {}
  local filter = self.publicFilter or "All"
  local query = self.publicSearchText or (self.publicSearch and self.publicSearch:GetText()) or ""
  for id, g in pairs(self.publicGroups) do
    BLFG_EnrichPublicGroup(self, g)
    if g.message and BronzeLFG_IsAddonSpam(g.message) then
      self.publicGroups[id] = nil
    elseif publicMatchesFilter(g, filter) and publicMatchesSearch(g, query) and publicMatchesRoleFilter(g, self.publicRoleFilter) then
      table.insert(rows, g)
    end
  end
  local hiddenTypes = publicHiddenTypes()
  if BLFG.publicHideOther == true then hiddenTypes["Other"] = true end
  local hideCount = publicHiddenTypeCount()
  if hideCount > 0 then
    local hideFilteredRows = {}
    for _, rg in ipairs(rows) do
      if hiddenTypes[tostring(rg.type or "Other")] ~= true then table.insert(hideFilteredRows, rg) end
    end
    rows = hideFilteredRows
  end

  local mode = self.publicSortMode or "Newest"
  table.sort(rows, function(a,b)
    if mode == "Type" then
      local at, bt = tostring(a.type or ""), tostring(b.type or "")
      if at ~= bt then return at < bt end
    elseif mode == "Activity" then
      local aa, ba = tostring(a.activity or ""), tostring(b.activity or "")
      if aa ~= ba then return aa < ba end
    elseif mode == "Player" then
      local ap, bp = tostring(a.player or ""), tostring(b.player or "")
      if ap ~= bp then return ap < bp end
    end
    return (a.seen or a.created or 0) > (b.seen or b.created or 0)
  end)
  return rows
end

function BLFG:ScrollPublicGroups(delta)
  local rows = self:GetSortedPublicGroups()
  local totalPages = math.max(1, math.ceil(#rows / (self.publicRowsPerPage or 10)))
  if delta < 0 then
    self.publicPage = math.min(totalPages, (self.publicPage or 1) + 1)
  else
    self.publicPage = math.max(1, (self.publicPage or 1) - 1)
  end
  self:RefreshPublicGroups()
end

function BLFG:RefreshPublicGroups()
  if not self.publicRows then return end
  if self.publicFilter == "Ascended" then self.publicFilter = "Raid" end
  if self.publicFilter == "Boss Blitz" then self.publicFilter = "Event" end
  local rows = self:GetSortedPublicGroups()
  local counts = self:GetPublicFilterCounts()
  local per = self.publicRowsPerPage or 10
  local totalPages = math.max(1, math.ceil(#rows / per))
  if not self.publicPage or self.publicPage < 1 then self.publicPage = 1 end
  if self.publicPage > totalPages then self.publicPage = totalPages end
  local start = ((self.publicPage - 1) * per) + 1

  local onlineCount = self:GetOnlineUserCount()
  if self.publicCountText then
    self.publicCountText:SetText("Listings: " .. tostring(counts.All or #rows) .. "  |  Results: " .. tostring(#rows) .. "  |  SignalFire Network: " .. tostring(onlineCount))
  end
  if self.publicHideOtherButton then self.publicHideOtherButton:SetText(publicHideTypesButtonText()) end
  if self.publicSortButton then self.publicSortButton:SetText("Sort: " .. tostring(self.publicSortMode or "Newest")) end
  if self.onlinePanelButton then
    self.onlinePanelButton:SetText("SignalFire Network (" .. tostring(onlineCount) .. ")")
  end
  if self.onlinePanel and self.onlinePanel:IsShown() then
    self:RefreshOnlinePanel()
  end
  if self.publicFilterButtons then
    local labels = {"All", "Dungeon", "Raid", "Key", "Event", "Guild", "LFG", "Social"}
    for _, f in ipairs(labels) do
      local b = self.publicFilterButtons[f]
      if b then
        b:SetText(publicFilterButtonLabel(f, counts[f] or 0))
        if (self.publicFilter or "All") == f then
          if b.LockHighlight then b:LockHighlight() end
        else
          if b.UnlockHighlight then b:UnlockHighlight() end
        end
      end
    end
  end
  if self.publicRoleFilterButtons then
    for key, b in pairs(self.publicRoleFilterButtons) do
      if (self.publicRoleFilter or "All") == key then
        if b.LockHighlight then b:LockHighlight() end
      else
        if b.UnlockHighlight then b:UnlockHighlight() end
      end
    end
  end
  if self.publicPageText then
    self.publicPageText:SetText("Page " .. tostring(self.publicPage) .. " / " .. tostring(totalPages))
  end

  for i, row in ipairs(self.publicRows) do
    local g = rows[start + i - 1]
    if g then
      row:Show()
      row.key = g.id
      if self.selectedPublic == g.id then row:SetBackdropColor(.25,.25,.05,.95) else row:SetBackdropColor(0,0,0,.80) end
      local playerText = g.player or ""
      if g.playerClassFile and g.playerClassFile ~= "" then playerText = classColor(g.playerClassFile) .. playerText .. "|r" end
      row.player:SetText(playerText)
      local t = ageText(BLFG_PublicStableTime(g))
      row.time:SetText(t)
      local ttype = g.type or "Other"
      row.type:SetText(publicTypeLabel(ttype))
      row.activity:SetText(shortenPublicText(g.activity or "", 26))
      if row.roles then row.roles:SetText(compactRoleText(g.roles or "")) end
      row.fullPlayer = g.player or ""
      row.fullActivity = g.activity or ""
      row.fullType = g.type or ""
      row.fullRoles = g.roles or "Not detected"
      row.fullIntent = g.intent or (g.type == "LFG" and "Applicant" or "Recruiter")
      row.fullTime = t
      row.fullChannel = g.channel or "Public"
      row.fullTags = g.tags or ""
      row.fullILevel = g.ilevel or ""
      row.fullScore = g.score and tostring(g.score) or ""
      row.fullMessage = g.message or ""
      row.fullPlayerLevel = g.playerLevel or ""
      row.fullPlayerClass = g.playerClassFile or g.playerClass or ""
      row.fullPlayerRole = g.playerRole or ""
      row.fullPlayerSpec = g.playerSpec or ""
      row.fullPlayerZone = g.playerZone or ""
      row.fullPlayerGuild = g.playerGuild or ""
      row.fullPlayerInfoSource = g.playerInfoSource or ""
      local m = g.message or ""
      m = shortenPublicText(m, 70)
      row.message:SetText(m)
    else
      row.key = nil
      row.fullPlayer = nil
      row.fullActivity = nil
      row.fullMessage = nil
      row.fullType = nil
      row.fullRoles = nil
      row.fullIntent = nil
      row.fullTime = nil
      row.fullChannel = nil
      row.fullTags = nil
      row.fullILevel = nil
      row.fullScore = nil
      row.fullPlayerLevel = nil
      row.fullPlayerClass = nil
      row.fullPlayerRole = nil
      row.fullPlayerSpec = nil
      row.fullPlayerZone = nil
      row.fullPlayerGuild = nil
      row.fullPlayerInfoSource = nil
      row:Hide()
    end
  end
end


function BLFG:IsFavorite(name)
  BronzeLFG_DB.favorites = BronzeLFG_DB.favorites or {}
  return BronzeLFG_DB.favorites[normalizeFavName(name)] == true
end

function BLFG:SetFavorite(name, value)
  if not name or name == "" then return end
  BronzeLFG_DB.favorites = BronzeLFG_DB.favorites or {}
  BronzeLFG_DB.favorites[normalizeFavName(name)] = value and true or nil
  if value then msg(tostring(name) .. " added to SignalFire Network favorites.") else msg(tostring(name) .. " removed from SignalFire Network favorites.") end
  self:RefreshOnlinePanel()
end

function BLFG:ToggleFavorite(name)
  self:SetFavorite(name, not self:IsFavorite(name))
end

function BLFG:GetOnlineUserRows()
  self:PruneOnlineUsers()
  local rows = {}
  local className, myClass = playerClass()
  local myRole = (BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.role) or ""
  local mySpec = (BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.roleType) or ""
  local myZone = currentZoneText()
  local myGuild = myGuildName()
  table.insert(rows, {name=playerName(), version=VERSION, level=tostring(playerLevel()), className=className or myClass or "", classFile=myClass or className or "", role=myRole or "", spec=mySpec or "", zone=myZone or "", guild=myGuild or "", seen=now(), self=true, friend=false, groupmate=false, favorite=self:IsFavorite(playerName())})
  for name, u in pairs(self.onlineUsers or {}) do
    if name ~= playerName() then
      u.friend = isFriendName(u.name)
      u.groupmate = isPartyOrRaidMember(u.name)
      u.favorite = self:IsFavorite(u.name)
      table.insert(rows, u)
    end
  end
  table.sort(rows, function(a,b)
    if a.self and not b.self then return true end
    if b.self and not a.self then return false end
    if a.favorite and not b.favorite then return true end
    if b.favorite and not a.favorite then return false end
    if a.friend and not b.friend then return true end
    if b.friend and not a.friend then return false end
    if tostring(a.guild or "") == myGuild and tostring(b.guild or "") ~= myGuild and myGuild ~= "" then return true end
    if tostring(b.guild or "") == myGuild and tostring(a.guild or "") ~= myGuild and myGuild ~= "" then return false end
    if tostring(a.zone or "") == myZone and tostring(b.zone or "") ~= myZone and myZone ~= "" then return true end
    if tostring(b.zone or "") == myZone and tostring(a.zone or "") ~= myZone and myZone ~= "" then return false end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return rows
end

function BLFG:GetOnlineStats(rows)
  rows = rows or self:GetOnlineUserRows()
  local stats = {total=#rows, zone=0, guild=0, friends=0, group=0, favorites=0, whoOnly=0, signalFire=0}

  local guildCounts = {}
  local zoneCounts = {}
  local newestName = "Unknown"
  local newestAge = 999999

  for _, u in ipairs(rows) do
    local g = tostring(u.guild or "")
    local z = tostring(u.zone or "")

    if g ~= "" then
      guildCounts[g] = (guildCounts[g] or 0) + 1
    end

    if z ~= "" then
      zoneCounts[z] = (zoneCounts[z] or 0) + 1
    end

    if u.friend then stats.friends = stats.friends + 1 end
    if u.favorite then stats.favorites = stats.favorites + 1 end
    if u.groupmate then stats.group = stats.group + 1 end
    if u.whoOnly then stats.whoOnly = stats.whoOnly + 1 else stats.signalFire = stats.signalFire + 1 end

    local age = math.max(0, (time() - (u.seen or time())))
    if age < newestAge then
      newestAge = age
      newestName = tostring(u.name or "Unknown")
    end
  end

  local represented = 0
  local topGuild, topGuildCount = "Unknown", 0
  for k,v in pairs(guildCounts) do
    represented = represented + 1
    if v > topGuildCount then
      topGuild = k
      topGuildCount = v
    end
  end

  local topZone, topZoneCount = "Unknown", 0
  for k,v in pairs(zoneCounts) do
    if v > topZoneCount then
      topZone = k
      topZoneCount = v
    end
  end

  stats.guild = represented
  stats.guildName = topGuild
  stats.guildCount = topGuildCount
  stats.zone = topZone .. ' (' .. tostring(topZoneCount) .. ')'
  stats.newest = newestName .. ' (' .. tostring(newestAge) .. ' sec ago)'

  return stats
end

function BLFG:BuildOnlinePanel()
  local f = CreateFrame("Frame", nil, self.frame)
  self.onlinePanel = f
  f:SetWidth(440); f:SetHeight(540)
  f:SetPoint("TOPLEFT", self.content, "TOPRIGHT", 8, -2)
  f:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
  f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 250)
  f:SetToplevel(true)
  f:Hide()
  backdrop(f, .88)

  local title = font(f, "SignalFire Network Online", 15, 1, .75, 0)
  title:SetPoint("TOP", f, "TOP", 0, -14)
  self.onlinePanelTitle = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  local refresh = button(f, "Refresh Ping", 110, 22)
  refresh:SetPoint("TOPRIGHT", f, "TOPRIGHT", -32, -44)
  refresh:SetScript("OnClick", function()
    BLFG:SendPresence()
    BLFG:RefreshOnlinePanel()
    msg("SignalFire presence ping sent.")
  end)

  self.onlineStats = font(f, "", 10, .65, .85, 1)
  self.onlineStats:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -48)
  self.onlineStats:SetWidth(300)
  self.onlineStats:SetHeight(78)
  self.onlineStats:SetJustifyH("LEFT")
  self.onlineStats:SetJustifyV("TOP")

  self.onlineFilter = self.onlineFilter or "All"
  local all = button(f, "All", 58, 20)
  all:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -128)
  all:SetScript("OnClick", function() BLFG.onlineFilter = "All"; BLFG.onlinePage = 1; BLFG:RefreshOnlinePanel() end)
  local sf = button(f, "SignalFire", 92, 20)
  sf:SetPoint("LEFT", all, "RIGHT", 6, 0)
  sf:SetScript("OnClick", function() BLFG.onlineFilter = "SignalFire"; BLFG.onlinePage = 1; BLFG:RefreshOnlinePanel() end)
  local whoOnly = button(f, "/who Only", 86, 20)
  whoOnly:SetPoint("LEFT", sf, "RIGHT", 6, 0)
  whoOnly:SetScript("OnClick", function() BLFG.onlineFilter = "Who"; BLFG.onlinePage = 1; BLFG:RefreshOnlinePanel() end)
  self.onlineFilterButtons = {All=all, SignalFire=sf, Who=whoOnly}

  local legend = font(f, "â˜… You/Friend   â—† Party/Raid", 9, .8, .8, .8)
  legend:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -150)

  local header = CreateFrame("Frame", nil, f)
  header:SetWidth(416); header:SetHeight(22)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -174)
  flat(header, .95)
  font(header, "Player", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 8, 0)
  font(header, "Lvl", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 124, 0)
  font(header, "Role", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 154, 0)
  font(header, "Zone", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 190, 0)
  font(header, "Guild", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 278, 0)
  font(header, "Seen", 9, .65, .85, 1):SetPoint("LEFT", header, "LEFT", 374, 0)

  self.onlineRows = {}
  for i=1,10 do
    local r = CreateFrame("Button", nil, f)
    r:SetWidth(416); r:SetHeight(27)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -200 - ((i-1)*29))
    flat(r, .72)
    r.icon = r:CreateTexture(nil, "OVERLAY")
    r.icon:SetWidth(16); r.icon:SetHeight(16); r.icon:SetPoint("LEFT", r, "LEFT", 6, 0)
    r.name = font(r, "", 9, .65, .85, 1); r.name:SetPoint("LEFT", r, "LEFT", 26, 0); r.name:SetWidth(96); r.name:SetJustifyH("LEFT")
    r.level = font(r, "", 9, 1, 1, 1); r.level:SetPoint("LEFT", r, "LEFT", 124, 0); r.level:SetWidth(26); r.level:SetJustifyH("LEFT")
    r.role = font(r, "", 9, 1, 1, 1); r.role:SetPoint("LEFT", r, "LEFT", 154, 0); r.role:SetWidth(30); r.role:SetJustifyH("LEFT")
    r.zone = font(r, "", 9, .9, .9, .9); r.zone:SetPoint("LEFT", r, "LEFT", 190, 0); r.zone:SetWidth(82); r.zone:SetJustifyH("LEFT")
    r.guild = font(r, "", 9, .9, .82, .55); r.guild:SetPoint("LEFT", r, "LEFT", 278, 0); r.guild:SetWidth(92); r.guild:SetJustifyH("LEFT")
    r.seen = font(r, "", 9, .8, .8, .8); r.seen:SetPoint("LEFT", r, "LEFT", 374, 0); r.seen:SetWidth(38); r.seen:SetJustifyH("LEFT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if not self.playerName then return end
      if self.user and self.user.whoOnly then return end
      if button == "RightButton" then
        BLFG:ShowOnlineUserMenu(self, self.user)
      end
    end)
    r:SetScript("OnEnter", function(self)
      if not self.user then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.user.whoOnly and "/who Seen Player" or "SignalFire User", 1, .82, 0)
      GameTooltip:AddLine(tostring(self.user.name or "Unknown"), .65, .85, 1)
      if self.user.guild and self.user.guild ~= "" then GameTooltip:AddLine("Guild: " .. self.user.guild, .9, .82, .55) end
      if self.user.zone and self.user.zone ~= "" then GameTooltip:AddLine("Zone: " .. self.user.zone, .9, .9, .9) end
      if self.user.role and self.user.role ~= "" then GameTooltip:AddLine("Role: " .. self.user.role, 1, 1, 1) end
      if self.user.spec and self.user.spec ~= "" then GameTooltip:AddLine("Spec: " .. self.user.spec, 1, 1, 1) end
      if self.user.whoOnly then GameTooltip:AddLine("Source: /who guild scan", .7, .7, .7) end
      if not self.user.whoOnly then GameTooltip:AddLine("Right Click for Options", .4, 1, .4) end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.onlineRows[i] = r
  end

  self.onlineFooter = font(f, "", 10, .65, .85, 1)
  self.onlineFooter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 48)
  self.onlineNote = font(f, "Auto refresh: 10s", 9, .8, .8, .8)
  self.onlineNote:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 48)

  local up = button(f, "Up", 70, 22)
  up:SetPoint("BOTTOM", f, "BOTTOM", -42, 42)
  up:SetScript("OnClick", function() BLFG.onlinePage = math.max(1, (BLFG.onlinePage or 1) - 1); BLFG:RefreshOnlinePanel() end)
  local down = button(f, "Down", 70, 22)
  down:SetPoint("LEFT", up, "RIGHT", 8, 0)
  down:SetScript("OnClick", function() BLFG.onlinePage = (BLFG.onlinePage or 1) + 1; BLFG:RefreshOnlinePanel() end)
  self.onlinePageUp = up
  self.onlinePageDown = down

  local who = button(f, "Who List (Chat)", 126, 24)
  who:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
  who:SetScript("OnClick", function() BLFG:PrintOnlineUsers() end)
  local hide = button(f, "Hide Panel", 126, 24)
  hide:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
  hide:SetScript("OnClick", function() f:Hide() end)
end

function BLFG:FindOnlineUser(name)
  if not name or name == "" then return nil end
  local needle = lower(tostring(name))
  for _, u in pairs(self.onlineUsers or {}) do
    if lower(tostring(u.name or "")) == needle then return u end
  end
  return nil
end

function BLFG:GetOnlineGuildMembers(guildName)
  local members = {}
  if not guildName or guildName == "" then return members end
  local target = lower(tostring(guildName))
  for _, u in ipairs(self:GetOnlineUserRows()) do
    if lower(tostring(u.guild or "")) == target then
      table.insert(members, u)
    end
  end
  table.sort(members, function(a,b)
    if a.favorite and not b.favorite then return true end
    if b.favorite and not a.favorite then return false end
    if a.self and not b.self then return true end
    if b.self and not a.self then return false end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return members
end

local function bronzeNetMemberSummary(members, limit)
  limit = limit or 4
  if not members or #members == 0 then return "" end

    local out = {}
  for i, u in ipairs(members) do
    if i > limit then
      table.insert(out, "+" .. tostring(#members - limit) .. " more")
      break
    end
    local n = tostring(u.name or "?")
    if u.favorite then n = "â˜… " .. n end
    table.insert(out, n)
  end
  return table.concat(out, ", ")
end

local function bronzeNetStatusText(user)
  if user and user.name then
    return "|cff66ff66Online|r"
  end
  return "|cffaaaaaaOffline|r"
end

local function bronzeNetGuildMemberLines(members, limit)
  limit = limit or 5
  local lines = {}
  if not members or #members == 0 then
    table.insert(lines, "|cffaaaaaaNone seen on SignalFire Network.|r")
    return lines
  end
  for i, u in ipairs(members) do
    if i > limit then
      table.insert(lines, "|cffaaaaaa+" .. tostring(#members - limit) .. " more online|r")
      break
    end
    local name = tostring(u.name or "?")
    if u.self then name = "|cffffcc00â˜… " .. name .. "|r"
    elseif u.favorite then name = "|cffffd100â˜… " .. name .. "|r"
    else name = classColor(u.classFile) .. name .. "|r" end
    local role = tostring(u.role or "Unknown")
    table.insert(lines, name .. " [" .. role .. "]")
    if u.zone and u.zone ~= "" then
      table.insert(lines, "  |cff999999" .. shortenPublicText(u.zone,22) .. "|r")
    end
    table.insert(lines, "")
  end
  return lines
end


function BLFG:BuildBronzeNetProfilePanel()
  local f = CreateFrame("Frame", nil, self.frame)
  self.bronzeNetProfile = f
  f:SetWidth(292); f:SetHeight(389)
  -- Profile uses the same right-side detail slot instead of making another side panel.
  f:SetPoint("TOPRIGHT", self.guildBrowser or self.frame, "TOPRIGHT", -2, -166)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  if f.SetToplevel then f:SetToplevel(true) end
  f:EnableMouse(true)
  f:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
  f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 250)
  f:SetToplevel(true)
  f:SetFrameLevel((self.frame:GetFrameLevel() or 1) + 80)
  backdrop(f, 1)
  f:Hide()

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() f:Hide() end)

  f:SetScript("OnHide", function()
    if BLFG.currentTab == "Guild Browser" and BLFG.guildPanel and BLFG.guildPanel:IsVisible() and BLFG.guildDetailPanel then BLFG.guildDetailPanel:Show() end
  end)

  f.title = font(f, "SignalFire Network Profile", 16, 1, .75, 0)
  f.title:SetPoint("TOP", f, "TOP", 0, -16)
  f.name = font(f, "", 14, .65, .85, 1); f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -48); f.name:SetWidth(232); f.name:SetJustifyH("LEFT")
  f.detail = font(f, "", 10, .9, .9, .9); f.detail:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -78); f.detail:SetWidth(262); f.detail:SetHeight(270); f.detail:SetJustifyH("LEFT")
  f.detail:SetJustifyV("TOP")

  f.whisper = button(f, "Whisper", 80, 24); f.whisper:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
  f.invite = button(f, "Invite", 78, 24); f.invite:SetPoint("LEFT", f.whisper, "RIGHT", 8, 0)
  f.favorite = button(f, "Favorite", 90, 24); f.favorite:SetPoint("LEFT", f.invite, "RIGHT", 8, 0)
  f.copy = button(f, "Copy Name", 90, 24); f.copy:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 32, 42)
  f.guild = button(f, "Open Guild", 90, 24); f.guild:SetPoint("LEFT", f.copy, "RIGHT", 12, 0)
end

function BLFG:ShowBronzeNetProfile(u)
  if not u or not u.name then return end
  if not self.bronzeNetProfile then self:BuildBronzeNetProfilePanel() end
  local f = self.bronzeNetProfile
  f.user = u
  self:ShowGuildDetailMode("bronzenet")
  f:ClearAllPoints()
  f:SetPoint("TOPRIGHT", self.guildBrowser or self.frame, "TOPRIGHT", -2, -166)
  f:SetFrameLevel((self.frame:GetFrameLevel() or 1) + 80)
  f.name:SetText((BLFG:IsFavorite(u.name) and "|cffffd100â˜… |r" or "") .. (u.name or "Unknown") .. "  |cffccccccLevel " .. tostring(u.level or "?") .. "|r")

  local lines = {}
  table.insert(lines, "|cFFFFCC00Status:|r " .. (u.self and "You" or (u.friend and "Friend" or (u.groupmate and "Party/Raid" or "SignalFire Network Online"))))
  table.insert(lines, "|cFFFFCC00Favorite:|r " .. (BLFG:IsFavorite(u.name) and "Yes â˜…" or "No"))
  table.insert(lines, "|cFFFFCC00Class:|r " .. tostring(u.className or u.class or u.classFile or "Unknown") .. "   |cFFFFCC00Role:|r " .. tostring(u.role or "Unknown"))
  if u.spec and u.spec ~= "" then table.insert(lines, "|cFFFFCC00Spec:|r " .. tostring(u.spec)) end
  if u.zone and u.zone ~= "" then table.insert(lines, "|cFFFFCC00Zone:|r " .. tostring(u.zone)) end
  table.insert(lines, "|cFFFFCC00Last Seen:|r " .. ageText(u.seen or now()))
  if u.guild and u.guild ~= "" then
    local gm = BLFG:GetOnlineGuildMembers(u.guild)
    table.insert(lines, "")
    table.insert(lines, "|cFFFFCC00Guild:|r " .. tostring(u.guild) .. "  |cff66ff66(" .. tostring(#gm) .. " online)|r")
    table.insert(lines, "|cFFFFCC00Online SignalFire Network:|r")
    local ml = bronzeNetGuildMemberLines(gm, 5)
    for _, line in ipairs(ml) do table.insert(lines, line) end
  end

  table.insert(lines, "")
  table.insert(lines, "|cFFFFCC00Quick Actions:|r whisper, invite, favorite, copy, guild.")
  f.detail:SetText(table.concat(lines, "\n"))

  f.whisper:SetScript("OnClick", function() if u.name ~= playerName() then ChatFrame_OpenChat("/w " .. u.name .. " ") else msg("That is you.") end end)
  f.invite:SetScript("OnClick", function() if u.name ~= playerName() and InviteUnit then InviteUnit(u.name) else msg("That is you.") end end)
  f.copy:SetScript("OnClick", function() ChatFrame_OpenChat(tostring(u.name or "")) end)
  if f.guild then
    f.guild:SetShown(u.guild and u.guild ~= "")
    f.guild:SetScript("OnClick", function() BLFG:ShowBronzeNetSocialPanel("Guild") end)
  end
  f.favorite:SetText(BLFG:IsFavorite(u.name) and "Unfavorite" or "Favorite")
  f.favorite:SetScript("OnClick", function() BLFG:ToggleFavorite(u.name); BLFG:ShowBronzeNetProfile(u); BLFG:RefreshOnlinePanel(); BLFG:RefreshGuildBrowser() end)
  f:Show()
end

function BLFG:GetBronzeNetSocialRows(mode)
  local rows = self:GetOnlineUserRows()
  local myGuild = myGuildName()
  local myZone = currentZoneText()
  local out = {}
  mode = mode or "Favorites"
  for _, u in ipairs(rows) do
    local keep = false
    if mode == "Favorites" then keep = u.favorite == true or u.self == true
    elseif mode == "Guild" then keep = myGuild ~= "" and tostring(u.guild or "") == myGuild
    elseif mode == "Zone" then keep = myZone ~= "" and tostring(u.zone or "") == myZone
    else keep = true end
    if keep then table.insert(out, u) end
  end
  table.sort(out, function(a,b)
    if a.self and not b.self then return true end
    if b.self and not a.self then return false end
    if a.favorite and not b.favorite then return true end
    if b.favorite and not a.favorite then return false end
    if a.friend and not b.friend then return true end
    if b.friend and not a.friend then return false end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return out
end

function BLFG:ShowBronzeNetSocialPanel(mode)
  mode = mode or "Favorites"
  if not self.bronzeNetSocialPanel then
    local f = CreateFrame("Frame", "BronzeLFGSocialPanel", self.frame or UIParent)
    self.bronzeNetSocialPanel = f
    f:SetWidth(300); f:SetHeight(330)
    f:SetPoint("TOPRIGHT", self.frame or UIParent, "TOPRIGHT", -310, -126)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    f:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
  f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 250)
  f:SetToplevel(true)
    f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 70)
    backdrop(f, .90)
    f:Hide()

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)

    f.title = font(f, "SignalFire Network Social", 16, 1, .75, 0)
    f.title:SetPoint("TOP", f, "TOP", 0, -14)

    f.tabs = {}
    local modes = {{"Favorites", "Favorites"}, {"Guild", "Guild"}, {"Zone", "Zone"}}
    local prev
    for i, info in ipairs(modes) do
      local b = button(f, info[1], 76, 21)
      if i == 1 then b:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
      else b:SetPoint("LEFT", prev, "RIGHT", 6, 0) end
      b.modeName = info[2]
      b:SetScript("OnClick", function(self) BLFG:ShowBronzeNetSocialPanel(self.modeName) end)
      f.tabs[info[2]] = b
      prev = b
    end

    f.rows = {}
    for i=1,6 do
      local r = CreateFrame("Button", nil, f)
      r:SetWidth(270); r:SetHeight(30)
      r:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -72 - ((i-1)*33))
      flat(r, .80)
      r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
      r.name = font(r, "", 10, .65, .85, 1); r.name:SetPoint("LEFT", r, "LEFT", 8, 6); r.name:SetWidth(112); r.name:SetJustifyH("LEFT")
      r.meta = font(r, "", 9, .85, .85, .85); r.meta:SetPoint("LEFT", r, "LEFT", 8, -7); r.meta:SetWidth(240); r.meta:SetJustifyH("LEFT")
      r.role = font(r, "", 10, 1, 1, 1); r.role:SetPoint("LEFT", r, "LEFT", 126, 6); r.role:SetWidth(24)
      r.seen = font(r, "", 9, .8, .8, .8); r.seen:SetPoint("RIGHT", r, "RIGHT", -8, 6); r.seen:SetWidth(60); r.seen:SetJustifyH("RIGHT")
      r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r:SetScript("OnClick", function(self, button)
        if not self.user then return end
        if button == "RightButton" then BLFG:ShowOnlineUserMenu(self, self.user)
        else BLFG:ShowBronzeNetProfile(self.user) end
      end)
      f.rows[i] = r
    end

    f.footer = font(f, "Left-click profile - Right-click options", 9, .65, .85, 1)
    f.footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 18)
  end

  local f = self.bronzeNetSocialPanel
  f.mode = mode
  f.title:SetText("SignalFire Network: " .. tostring(mode))
  for name, b in pairs(f.tabs or {}) do
    b:SetText((name == mode and "[" .. name .. "]" or name))
  end

  local rows = self:GetBronzeNetSocialRows(mode)
  for i, r in ipairs(f.rows or {}) do
    local u = rows[i]
    if u then
      r.user = u
      r:Show()
      r.name:SetText(decorateOnlineName(u))
      r.role:SetText(shortRole(u.role))
      r.seen:SetText(ageText(u.seen or now()))
      local meta = tostring(u.zone or "Unknown")
      if u.guild and u.guild ~= "" then meta = meta .. " - " .. tostring(u.guild) end
      r.meta:SetText(shortenPublicText(meta, 42))
    else
      r.user = nil
      r:Hide()
    end
  end

  if #rows == 0 then
    f.footer:SetText("No matching SignalFire Network users online.")
  else
    f.footer:SetText(tostring(#rows) .. " users - Left-click profile - Right-click options")
  end
  f:Show()
end

function BLFG:ShowOnlineUserMenu(anchor, u)
  if not u or not u.name then return end
  if not self.onlineMenu then
    self.onlineMenu = CreateFrame("Frame", "BronzeLFGOnlineMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local name = tostring(u.name or "")
  UIDropDownMenu_Initialize(self.onlineMenu, function()
    local info = UIDropDownMenu_CreateInfo()
    info.text = name
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "View SignalFire Network Profile"
    info.notCheckable = true
    info.func = function() BLFG:ShowBronzeNetProfile(u) end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Whisper"
    info.notCheckable = true
    info.disabled = (name == playerName())
    info.func = function() if name ~= playerName() then ChatFrame_OpenChat("/w " .. name .. " ") end end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Invite"
    info.notCheckable = true
    info.disabled = (name == playerName())
    info.func = function() if name ~= playerName() and InviteUnit then InviteUnit(name) end end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Copy Name to Chat"
    info.notCheckable = true
    info.func = function() ChatFrame_OpenChat(name) end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = BLFG:IsFavorite(name) and "Remove Favorite" or "Add Favorite"
    info.notCheckable = true
    info.func = function() BLFG:ToggleFavorite(name) end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Cancel"
    info.notCheckable = true
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
  end, "MENU")
  ToggleDropDownMenu(1, nil, self.onlineMenu, anchor, 0, 0)
end

function BLFG:ToggleOnlinePanel()
  if not self.onlinePanel then return end
  if self.onlinePanel:IsShown() then
    self.onlinePanel:Hide()
  else
    self.onlinePanel:Show()
    self:SendPresence()
    self:RefreshOnlinePanel()
  end
end

function BLFG:RefreshOnlinePanel()
  if not self.onlinePanel or not self.onlineRows then return end
  local allRows = self:GetOnlineUserRows()
  local stats = self:GetOnlineStats(allRows)
  local rows = {}
  local filter = tostring(self.onlineFilter or "All")
  for _, u in ipairs(allRows) do
    if filter == "SignalFire" then
      if not u.whoOnly then table.insert(rows, u) end
    elseif filter == "Who" then
      if u.whoOnly then table.insert(rows, u) end
    else
      table.insert(rows, u)
    end
  end

  local per = #(self.onlineRows or {})
  if per < 1 then per = 10 end
  local pages = math.max(1, math.ceil(#rows / per))
  self.onlinePage = math.max(1, math.min(tonumber(self.onlinePage or 1) or 1, pages))
  local start = ((self.onlinePage - 1) * per) + 1

  if self.onlinePanelTitle then self.onlinePanelTitle:SetText("SignalFire Network + /who (" .. tostring(#allRows) .. ")") end
  if self.onlineFooter then self.onlineFooter:SetText(tostring(stats.signalFire or 0) .. " SignalFire  +  " .. tostring(stats.whoOnly or 0) .. " /who  -  Favorites online: " .. tostring(stats.favorites or 0)) end
  if self.onlineNote then self.onlineNote:SetText("Page " .. tostring(self.onlinePage) .. " / " .. tostring(pages)) end
  if self.onlinePageUp then if self.onlinePage <= 1 then self.onlinePageUp:Disable() else self.onlinePageUp:Enable() end end
  if self.onlinePageDown then if self.onlinePage >= pages then self.onlinePageDown:Disable() else self.onlinePageDown:Enable() end end
  if self.onlineFilterButtons then
    for k, b in pairs(self.onlineFilterButtons) do
      if b then
        if k == "All" then b:SetText("All (" .. tostring(#allRows) .. ")")
        elseif k == "SignalFire" then b:SetText("SignalFire (" .. tostring(stats.signalFire or 0) .. ")")
        else b:SetText("/who (" .. tostring(stats.whoOnly or 0) .. ")") end
      end
    end
  end
  if self.onlineStats then
    self.onlineStats:SetText("Guilds Represented: "..tostring(stats.guild).."\n"..
      "SignalFire Users: "..tostring(stats.signalFire or 0).."  |  /who Only: "..tostring(stats.whoOnly or 0).."\n"..
      "Friends Online Now: "..tostring(stats.friends).."\n"..
      "Favorites Online Now: "..tostring(stats.favorites).."\n\n"..
      "Most Active Guild: "..tostring(stats.guildName or "Unknown").." ("..tostring(stats.guildCount or 0)..")\n"..
      "Most Active Zone: "..tostring(stats.zone).."\n"..
      "Newest Seen: "..tostring(stats.newest or "Unknown"))
  end
  for i, r in ipairs(self.onlineRows) do
    local u = rows[start + i - 1]
    if u then
      r:Show()
      r.user = u
      r.playerName = u.name
      r.icon:SetTexture(classIcon(u.classFile or ""))
      r.name:SetText(decorateOnlineName(u))
      r.level:SetText(shortenPublicText(u.level or "?", 3))
      r.role:SetText(shortRole(u.role))
      r.zone:SetText(shortenPublicText(u.zone or "", 14))
      r.guild:SetText(shortenPublicText(u.guild or "", 12))
      r.seen:SetText(ageText(u.seen or now()))
      if u.self then flat(r, .84) elseif u.friend then flat(r, .79) elseif u.whoOnly then flat(r, .58) else flat(r, .72) end
    else
      r.user = nil
      r.playerName = nil
      r:Hide()
    end
  end
end



local function guildHas(msg, word)
  return string.find(msg or "", word, 1, true) ~= nil
end

local function addUniqueTag(tags, value)
  if not value or value == "" then return end
  for _, v in ipairs(tags) do if v == value then return end end
  table.insert(tags, value)
end

local function guildPostKind(g)
  local msg = lower((g and g.message) or "")
  local needsTank = guildHas(msg, "tank") or guildHas(msg, "prot")
  local needsHeal = guildHas(msg, "heal") or guildHas(msg, "healer") or guildHas(msg, "hpal") or guildHas(msg, "disc") or guildHas(msg, "priest")
  local needsDps = guildHas(msg, "dps") or guildHas(msg, "damage") or guildHas(msg, "caster") or guildHas(msg, "ranged") or guildHas(msg, "melee")

  if guildHas(msg, "all roles") or guildHas(msg, "any role") or guildHas(msg, "everyone") or guildHas(msg, "all classes") then
    return "All Roles"
  end

  local parts = {}
  if needsTank then table.insert(parts, "Tank") end
  if needsHeal then table.insert(parts, "Healer") end
  if needsDps then table.insert(parts, "DPS") end
  if #parts > 0 then return table.concat(parts, "+") end

  if guildHas(msg, "recruit") or guildHas(msg, "recrute") or guildHas(msg, "recrutement") or guildHas(msg, "looking for") or guildHas(msg, "seeking") or guildHas(msg, "join") then
    return "Recruiting"
  end

  return "Recruiting"
end


local function guildPostFocus(g)
  -- v4.5.2 Enhanced Focus Detection
  -- Detects multiple server-specific focus tags from recruitment text.
  local msg = lower((g and g.message) or "")
  local tags = {}

  local function add(tag)
    for _, existing in ipairs(tags) do
      if existing == tag then return end
    end
    table.insert(tags, tag)
  end

  -- Triumvirate focus types first.
  if guildHas(msg, "mythic+") or guildHas(msg, "m+") or guildHas(msg, "mythic plus") or guildHas(msg, "keystone") or guildHas(msg, "keystones") or guildHas(msg, "key") or guildHas(msg, "keys") then add("Keys") end
  if guildHas(msg, "bosses") or guildHas(msg, "world boss") or guildHas(msg, "world bosses") then add("World Boss") end

  -- Classic broad categories.
  if guildHas(msg, "raid") or guildHas(msg, "raiding") or guildHas(msg, "progression") or guildHas(msg, "core") or guildHas(msg, "roster") or guildHas(msg, "heroic") or guildHas(msg, "bwl") or guildHas(msg, "molten core") or guildHas(msg, "mc") or guildHas(msg, "ony") or guildHas(msg, "onyxia") or guildHas(msg, "zg") or guildHas(msg, "aq20") or guildHas(msg, "aq40") or guildHas(msg, "naxx") then add("Raiding") end
  if guildHas(msg, "pvp") or guildHas(msg, "arena") or guildHas(msg, "arenas") or guildHas(msg, "bg") or guildHas(msg, "bgs") or guildHas(msg, "battleground") or guildHas(msg, "premade") or guildHas(msg, "world pvp") then add("PvP") end
  if guildHas(msg, "level") or guildHas(msg, "leveling") or guildHas(msg, "levelling") or guildHas(msg, "fresh") or guildHas(msg, "alts") or guildHas(msg, "new player") or guildHas(msg, "new players") then add("Leveling") end
  if guildHas(msg, "social") or guildHas(msg, "friendly") or guildHas(msg, "family") or guildHas(msg, "community") or guildHas(msg, "chill") or guildHas(msg, "laid back") then add("Social") end
  if guildHas(msg, "casual") or guildHas(msg, "relaxed") then add("Casual") end
  if guildHas(msg, "hardcore") or guildHas(msg, " hc ") or guildHas(msg, "deathless") then add("Hardcore") end
  if guildHas(msg, "roleplay") or guildHas(msg, " rp ") or guildHas(msg, "rp-") then add("Roleplay") end
  if guildHas(msg, "event") or guildHas(msg, "events") or guildHas(msg, "world event") then add("Events") end
  if guildHas(msg, "competitive") or guildHas(msg, "min max") or guildHas(msg, "min-max") or guildHas(msg, "parse") or guildHas(msg, "parses") then add("Competitive") end
  if guildHas(msg, "dungeon") or guildHas(msg, "dungeons") then add("Dungeons") end

  if #tags == 0 then return "Recruiting" end
  if #tags > 4 then
    local trimmed = {}
    for i=1,4 do table.insert(trimmed, tags[i]) end
    return table.concat(trimmed, " | ")
  end
  return table.concat(tags, " | ")
end

local function likelyGuildBracketName(name)
  if not name or name == "" then return false end
  local s = lower(trimPublicText(name))
  if string.len(s) < 3 or string.len(s) > 32 then return false end
  local bad = {
    "star", "square", "circle", "diamond", "moon", "skull", "cross", "triangle", "rt", "raid", "guild",
    "keystone", "mythic", "quest", "item", "discord", "http", "https", "www", "tank", "healer", "dps", "na/eu", "na", "eu", "us", "oce", "sea",
  }
  for _, b in ipairs(bad) do if s == b or string.find(s, b, 1, true) then return false end end
  return true
end

function extractGuildNameFromPost(g)
  local msg = cleanPublicChatText((g and g.message) or "")

  local function cleanDetectedGuildName(n)
    if not n then return nil end
    n = cleanPublicChatText(tostring(n or ""))
    n = string.gsub(n, "^%s*[\"'â€œâ€]+", "")
    n = string.gsub(n, "[\"'â€œâ€]+%s*$", "")
    n = string.gsub(n, "^%s*Guild:%s*", "")
    n = trimPublicText(n)
    if n == "" then return nil end
    local x = lower(n)

    local exactBad = {
      ["na/eu"]=true, ["na"]=true, ["eu"]=true, ["us"]=true, ["oce"]=true, ["sea"]=true,
      ["lfg"]=true, ["lfm"]=true, ["pst"]=true,
      ["bwl"]=true, ["aq40"]=true, ["naxx"]=true, ["zg"]=true, ["mc"]=true,
      ["guild"]=true, ["raid"]=true, ["raiding"]=true, ["recruiting"]=true,
      ["tank"]=true, ["healer"]=true, ["heal"]=true, ["dps"]=true,
      ["all roles"]=true, ["any role"]=true,
      ["lfm"]=true, ["lf"]=true, ["looking"]=true, ["looking for"]=true,
    }
    if exactBad[x] then return nil end
    if string.len(n) < 3 or string.len(n) > 32 then return nil end
    return n
  end

  -- High-confidence Bronzebeard/Ascension style: {rt8}GUILD NAME{rt8}
  local name = string.match(msg, "{rt%d+}%s*([^{}%[%]<>]+)%s*{rt%d+}")
  name = cleanDetectedGuildName(name)
  if name then return name end

  -- High-confidence classic guild markup.
  name = cleanDetectedGuildName(string.match(msg, "<([^<>]+)>"))
  if name then return name end

  -- Quoted guild names, e.g. "Core Memory" is recruiting.
  name = cleanDetectedGuildName(string.match(msg, "\"([^\"]+)\""))
  if name then return name end

  -- Explicit guild label.
  name = cleanDetectedGuildName(string.match(msg, "[Gg]uild:%s*([^%.,%-%|]+)"))
  if name then return name end

  -- Triumvirate chat format: "Guild Recruitment + French Connection recrute ..."
  name = cleanDetectedGuildName(string.match(msg, "[Gg]uild%s+[Rr]ecruitment%s*[%+:%-%|]%s*(.-)%s+[Rr]ecru"))
  if name then return name end

  -- Bracketed guild names, but reject region/role/raid tags such as [NA/EU].
  for bracket in string.gmatch(msg, "%[([^%]]+)%]") do
    if likelyGuildBracketName(bracket) then
      name = cleanDetectedGuildName(bracket)
      if name then return name end
    end
  end

  -- Common natural-language recruitment formats.
  -- Example: "Looking for a chill guild? Drunken Dwarves is a friendly community..."
  name = cleanDetectedGuildName(string.match(msg, "[%?%!%.]%s*([^%?%!%.]+)%s+[Ii]s%s+[Aa]%s+[Ff]riendly"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "[%?%!%.]%s*([^%?%!%.]+)%s+[Ii]s%s+[Rr]ecruiting"))
  if name then return name end

  -- Example: "The Brawlers Guild is back and better than ever..."
  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-%s+[Gg]uild)%s+[Ii]s%s+[Bb]ack"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-%s+[Gg]uild)%s+[Ii]s%s+[Rr]ecruiting"))
  if name then return name end

  -- Common plain-English guild ads:
  -- "The Silver Hand (NA) is looking members..."
  -- "Core Memory is looking for raiders..."
  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-)%s*%([^%)]*%)%s+[Ii]s%s+[Ll]ooking"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-)%s+[Ii]s%s+[Ll]ooking"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-)%s+[Ii]s%s+[Rr]ecruiting"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "^%s*(.-)%s+[Rr]ecruiting"))
  if name then return name end

  name = cleanDetectedGuildName(string.match(msg, "[Jj]oin%s+(.+)%s+[Gg]uild"))
  if name then return name end

  return nil
end

function BLFG:IsFavoriteGuild(guild)
  BronzeLFG_DB.favoriteGuilds = BronzeLFG_DB.favoriteGuilds or {}
  return BronzeLFG_DB.favoriteGuilds[normalizeFavName(guild)] == true
end

function BLFG:SetFavoriteGuild(guild, value)
  if not guild or guild == "" then return end
  BronzeLFG_DB.favoriteGuilds = BronzeLFG_DB.favoriteGuilds or {}
  BronzeLFG_DB.favoriteGuilds[normalizeFavName(guild)] = value and true or nil
  if value then msg(tostring(guild) .. " added to favorite guilds.") else msg(tostring(guild) .. " removed from favorite guilds.") end
  self:RefreshGuildBrowser()
end

function BLFG:ToggleFavoriteGuild(guild)
  self:SetFavoriteGuild(guild, not self:IsFavoriteGuild(guild))
end

function BLFG:GetGuildRows()
  local byGuild = {}
  local rows = self:GetOnlineUserRows()
  local liveGuilds, postGuilds = 0, 0

  for _, u in ipairs(rows) do
    local g = tostring(u.guild or "")
    if g ~= "" then
      local key = lower(g)
      local row = byGuild[key]
      if not row then
        row = {name=g, online=0, tanks=0, healers=0, dps=0, flex=0, contacts={}, posts=0, favorite=self:IsFavoriteGuild(g), source="Recent Recruitment Message", confidence=100}
        byGuild[key] = row
        liveGuilds = liveGuilds + 1
      end
      row.online = row.online + 1
      local role = tostring(u.role or "")
      if role == "Tank" then row.tanks = row.tanks + 1
      elseif role == "Healer" then row.healers = row.healers + 1
      elseif role == "DPS" then row.dps = row.dps + 1
      elseif role == "Flexible" then row.flex = row.flex + 1 end
      table.insert(row.contacts, u)
    end
  end

  -- Supplement live BronzeNet presence with high-confidence guild recruitment posts only.
  -- Low-confidence "LF guild" / "guild inv pls" posts stay in Public Groups and do not pollute Guild Browser.
  for _, g in pairs(self.publicGroups or {}) do
    if g and g.message and not BronzeLFG_IsAddonSpam(g.message) and (g.type == "Guild" or g.activity == "Guild Recruitment") then
      local extractedGuildName = extractGuildNameFromPost(g)
      if extractedGuildName and extractedGuildName ~= "" then
        local key = lower(extractedGuildName)
        local row = byGuild[key]
        if not row then
          row = {name=extractedGuildName, online=0, tanks=0, healers=0, dps=0, flex=0, contacts={}, posts=0, favorite=self:IsFavoriteGuild(extractedGuildName), source="Public", isUnknownGuild=false, confidence=90}
          byGuild[key] = row
          postGuilds = postGuilds + 1
        end
        row.posts = (row.posts or 0) + 1
        row.source = (row.online and row.online > 0) and "SignalFire Network + Chat" or "Chat"
        local seen = tonumber(g.seen or g.created or 0) or 0
        if not row.lastPostSeen or seen > row.lastPostSeen then
          row.lastPostSeen = seen
          row.lastPost = g.message or ""
          row.lastPostTime = ageText(seen)
          row.postKind = guildPostKind(g)
          row.postFocus = guildPostFocus(g)
          if g.player and g.player ~= "" then row.postContact = g.player end
        end
      end
    end
  end

  local out = {}
  for _, row in pairs(byGuild) do
    table.sort(row.contacts, function(a,b)
      if a.favorite and not b.favorite then return true end
      if b.favorite and not a.favorite then return false end
      return tostring(a.name or "") < tostring(b.name or "")
    end)
    row.onlineMembers = row.contacts or {}
    row.memberSummary = bronzeNetMemberSummary(row.onlineMembers, 4)
    row.contact = row.postContact or (row.contacts[1] and row.contacts[1].name) or ""
    row.contactOnline = (row.contact and row.contact ~= "" and self:FindOnlineUser(row.contact)) and true or false
    if (row.online or 0) > 0 and (row.posts or 0) > 0 then
      row.status = "Live + Chat"
    elseif (row.online or 0) > 0 then
      row.status = "Live"
    else
      row.status = "Chat Only"
    end
    row.recruiting = row.postKind or ((row.online or 0) > 0 and "Unknown" or "Recruiting")
    row.focus = row.postFocus or "Unknown"
    if row.focus and string.len(row.focus) > 32 then row.focus = string.sub(row.focus, 1, 29) .. "..." end

    local q = lower(self.guildSearchText or (self.guildSearch and self.guildSearch:GetText()) or "")
    local searchOk = false
    if q == "" then
      searchOk = true
    else
      local hay = lower(tostring(row.name or "") .. " " .. tostring(row.contact or "") .. " " .. tostring(row.recruiting or "") .. " " .. tostring(row.focus or "") .. " " .. tostring(row.lastPost or ""))
      if string.find(hay, q, 1, true) then searchOk = true end
    end

    local focusOk = true
    local activeFocus = self.guildFocusFilter
    if activeFocus == "All" or activeFocus == "" then activeFocus = nil end
    if activeFocus then
      focusOk = string.find(lower(row.focus or ""), lower(activeFocus), 1, true) ~= nil
    end

    if searchOk and focusOk and (not self.guildFavoritesOnly or row.favorite) then
      table.insert(out, row)
    end
  end

  self.guildLiveCount = liveGuilds
  self.guildPostOnlyCount = postGuilds

  table.sort(out, function(a,b)
    if a.favorite and not b.favorite then return true end
    if b.favorite and not a.favorite then return false end
    if ((a.online or 0) > 0) and not ((b.online or 0) > 0) then return true end
    if ((b.online or 0) > 0) and not ((a.online or 0) > 0) then return false end
    local ap = tonumber(a.lastPostSeen or 0) or 0
    local bp = tonumber(b.lastPostSeen or 0) or 0
    if ap ~= bp then return ap > bp end
    return tostring(a.name or "") < tostring(b.name or "")
  end)

  return out
end


local function guildFocusIcon(focus)
  local f = lower(focus or "")
  if string.find(f, "pvp", 1, true) then return "|TInterface\\Icons\\Ability_DualWield:14:14:0:0|t" end
  if string.find(f, "boss blitz", 1, true) then return "|TInterface\\Icons\\INV_Misc_GroupNeedMore:14:14:0:0|t" end
  if string.find(f, "mythic", 1, true) then return "|TInterface\\Icons\\INV_Misc_Key_06:14:14:0:0|t" end
  if string.find(f, "raid", 1, true) then return "|TInterface\\Icons\\INV_Helmet_06:14:14:0:0|t" end
  if string.find(f, "level", 1, true) then return "|TInterface\\Icons\\Achievement_Character_Human_Male:14:14:0:0|t" end
  if string.find(f, "social", 1, true) or string.find(f, "casual", 1, true) then return "|TInterface\\Icons\\INV_Misc_GroupLooking:14:14:0:0|t" end
  if string.find(f, "hardcore", 1, true) then return "|TInterface\\Icons\\Ability_Warrior_BattleShout:14:14:0:0|t" end
  return "|TInterface\\Icons\\INV_BannerPVP_02:14:14:0:0|t"
end

local function guildFocusTagsText(focus, maxTags)
  local raw = tostring(focus or "")
  if raw == "" or raw == "--" then return "|cff888888[--]|r" end
  raw = string.gsub(raw, "|", ",")
  local tags = {}
  for part in string.gmatch(raw, "[^,]+") do
    part = trimPublicText(part)
    if part ~= "" then table.insert(tags, part) end
  end
  if #tags == 0 then table.insert(tags, raw) end
  local out = {}
  local limit = maxTags or #tags
  for i, tag in ipairs(tags) do
    if i > limit then table.insert(out, "|cffaaaaaa[+" .. tostring(#tags - limit) .. "]|r"); break end
    local l = lower(tag)
    local color = "|cffd7d7d7"
    if string.find(l, "ascended", 1, true) then color = "|cffb77cff"
    elseif string.find(l, "boss blitz", 1, true) then color = "|cffffd35a"
    elseif string.find(l, "mythic", 1, true) then color = "|cff67c1ff"
    elseif string.find(l, "raid", 1, true) then color = "|cffff7777"
    elseif string.find(l, "pvp", 1, true) then color = "|cff8fb3ff"
    elseif string.find(l, "social", 1, true) or string.find(l, "casual", 1, true) then color = "|cff71e68a"
    elseif string.find(l, "level", 1, true) then color = "|cff9be26b"
    elseif string.find(l, "hardcore", 1, true) then color = "|cffff9b4a"
    elseif string.find(l, "roleplay", 1, true) then color = "|cffe6a8ff"
    end
    table.insert(out, color .. "[" .. tag .. "]|r")
  end
  return table.concat(out, " ")
end

function BLFG:SaveGuildBrowserState()
  BronzeLFG_DB.guildBrowser = BronzeLFG_DB.guildBrowser or {}
  BronzeLFG_DB.guildBrowser.selectedGuild = self.selectedGuild
  BronzeLFG_DB.guildBrowser.focusFilter = self.guildFocusFilter
  BronzeLFG_DB.guildBrowser.sourceFilter = self.guildSourceFilter
  BronzeLFG_DB.guildBrowser.favoritesOnly = self.guildFavoritesOnly and true or false
  BronzeLFG_DB.guildBrowser.searchText = self.guildSearchText or (self.guildSearch and self.guildSearch:GetText()) or ""
end

function BLFG:RestoreGuildBrowserState()
  BronzeLFG_DB.guildBrowser = BronzeLFG_DB.guildBrowser or {}
  local st = BronzeLFG_DB.guildBrowser
  self.selectedGuild = st.selectedGuild
  self.guildFocusFilter = st.focusFilter
  self.guildSourceFilter = st.sourceFilter or "All"
  self.guildFavoritesOnly = st.favoritesOnly and true or false
  self.guildSearchText = st.searchText or ""
  if self.guildSearch and not self._restoringGuildSearch then
    self._restoringGuildSearch = true
    self.guildSearch:SetText(self.guildSearchText or "")
    self._restoringGuildSearch = false
  end
end

function BLFG:ShowGuildDetailMode(mode)
  if mode == "bronzenet" then
    if self.guildDetailPanel then self.guildDetailPanel:Hide() end
    if self.bronzeNetProfile then self.bronzeNetProfile:Show() end
  else
    if self.bronzeNetProfile then self.bronzeNetProfile:Hide() end
    if self.guildDetailPanel and self.currentTab == "Guild Browser" then self.guildDetailPanel:Show() end
  end
end


function BLFG:ShowGuildFocusMenu(anchor)
  if not self.focusDropdown then
    local f = CreateFrame("Frame", "BronzeLFGGuildFocusDropdown", UIParent)
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(150)
    f:SetHeight(304)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 12,
      insets = {left=3,right=3,top=3,bottom=3}
    })
    f:SetBackdropColor(0,0,0,.95)
    f.buttons = {}
    local opts = {"All", "Raiding", "Dungeons", "Keys", "World Boss", "PvP", "Leveling", "Social", "Casual", "Hardcore", "Roleplay", "Events", "Competitive"}
    for i,opt in ipairs(opts) do
      local b = button(f, opt, 136, 20)
      b:SetPoint("TOP", f, "TOP", 0, -6 - ((i-1)*22))
      b:SetScript("OnClick", function()
        BLFG.guildFocusFilter = (opt == "All") and nil or opt
        BLFG:SaveGuildBrowserState()
        f:Hide()
        BLFG:RefreshGuildBrowser()
      end)
      f.buttons[i] = b
    end
    f:Hide()
    self.focusDropdown = f
  end
  local f = self.focusDropdown
  if f:IsShown() then f:Hide(); return end
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  f:Show()
end

function BLFG:BuildGuildBrowser()
  local p = CreateFrame("Frame", nil, self.content)
  self.guildPanel = p
  p:SetAllPoints()
  p:Hide()

  font(p, "Guild Browser", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  self.guildCountText = font(p, "Guilds online: 0", 10, .65, .85, 1)
  self.guildCountText:SetPoint("TOP", p, "TOP", 0, -24)
  self.guildCountText:SetWidth(620)
  self.guildCountText:SetJustifyH("CENTER")

  local refresh = button(p, "Refresh SignalFire Network", 190, 22)
  refresh:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -44)
  refresh:SetScript("OnClick", function()
    BLFG:SendPresence()
    if BLFG.QueueWhoGuildDiscovery then BLFG:QueueWhoGuildDiscovery(true) end
    BLFG:RefreshGuildBrowser()
    msg("SignalFire presence ping sent.")
  end)

  self.guildFavFilterButton = button(p, "Favorites: Off", 110, 22)
  self.guildFavFilterButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -175, -44)
  self.guildFavFilterButton:SetScript("OnClick", function()
    BLFG.guildFavoritesOnly = not BLFG.guildFavoritesOnly
    BLFG:SaveGuildBrowserState()
    BLFG:RefreshGuildBrowser()
  end)
  self:RestoreGuildBrowserState()
  self.guildFocusFilterButton = button(p, "Focus: All", 130, 22)
  self.guildFocusFilterButton:SetPoint("TOPRIGHT", p, "TOPRIGHT", -310, -44)
  self.guildFocusFilterButton:SetScript("OnClick", function()
    BLFG:ShowGuildFocusMenu(self.guildFocusFilterButton)
  end)

  font(p, "Show:", 10, .8, .8, .8):SetPoint("TOPLEFT", p, "TOPLEFT", 6, -76)
  self.guildSourceFilterButtons = {}
  local sourceFilters = {
    {"All", "All", 54},
    {"Recruiting", "Recruiting", 92},
    {"Network", "Network", 78},
    {"Seen via /who", "Who", 112},
  }
  local sx = 48
  for _, opt in ipairs(sourceFilters) do
    local label, value, width = opt[1], opt[2], opt[3]
    local b = button(p, label, width, 22)
    b:SetPoint("TOPLEFT", p, "TOPLEFT", sx, -70)
    b:SetScript("OnClick", function()
      BLFG.guildSourceFilter = value
      BLFG.guildPage = 1
      BLFG:SaveGuildBrowserState()
      BLFG:RefreshGuildBrowser()
    end)
    self.guildSourceFilterButtons[value] = b
    sx = sx + width + 8
  end

  font(p, "Search", 10, .65, .85, 1):SetPoint("TOPRIGHT", p, "TOPRIGHT", -260, -78)
  self.guildSearch = edit(p, 220, 22, false)
  self.guildSearch:SetPoint("TOPRIGHT", p, "TOPRIGHT", -2, -76)
  self.guildSearch:SetScript("OnTextChanged", function(self)
    if BLFG._restoringGuildSearch then return end
    BLFG.guildSearchText = self:GetText() or ""
    BLFG:SaveGuildBrowserState()
    BLFG:RefreshGuildBrowser()
  end)
  if self.guildSearchText and self.guildSearchText ~= "" then self.guildSearch:SetText(self.guildSearchText) end
  self.guildSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

  local list = CreateFrame("Frame", nil, p)
  self.guildList = list
  list:SetWidth(520); list:SetHeight(389)
  list:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -126)
  backdrop(list, .96)

  local h = CreateFrame("Frame", nil, list)
  h:SetWidth(505); h:SetHeight(24); h:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -7)
  flat(h, .95)
  font(h, "Guild", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 8, 0)
  font(h, "Online", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 182, 0)
  font(h, "Source", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 230, 0)
  font(h, "Recruiting", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 325, 0)
  font(h, "Focus", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 405, 0)
  -- Detail panel shows Last Post
  -- Detail panel shows Contact
  font(h, "Fav", 10, .65, .85, 1):SetPoint("LEFT", h, "LEFT", 490, 0)

  self.guildRows = {}
  for i=1,8 do
    local r = CreateFrame("Button", nil, list)
    -- Guild Browser rows should stop at the guild table edge.
    -- Public Groups rows stay full-width separately for message-column hover/click.
    r:SetWidth(505); r:SetHeight(34)
    r:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -36 - ((i-1)*37))
    flat(r, .80)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.guild = font(r, "", 10, 1, .92, .68); r.guild:SetPoint("LEFT", r, "LEFT", 8, 0); r.guild:SetWidth(164); r.guild:SetJustifyH("LEFT")
    r.online = font(r, "", 10, 1, 1, 1); r.online:SetPoint("LEFT", r, "LEFT", 182, 0); r.online:SetWidth(42); r.online:SetJustifyH("LEFT")
    r.status = font(r, "", 10, 1, 1, 1); r.status:SetPoint("LEFT", r, "LEFT", 230, 0); r.status:SetWidth(90); r.status:SetJustifyH("LEFT")
    r.recruiting = font(r, "", 10, .9, .9, .9); r.recruiting:SetPoint("LEFT", r, "LEFT", 325, 0); r.recruiting:SetWidth(72); r.recruiting:SetJustifyH("LEFT")
    r.focus = font(r, "", 10, .9, .9, .9); r.focus:SetPoint("LEFT", r, "LEFT", 405, 0); r.focus:SetWidth(84); r.focus:SetJustifyH("LEFT")
    r.lastPost = font(r, "", 10, .8, .8, .8); r.lastPost:Hide()
    r.contact = font(r, "", 10, .65, .85, 1); r.contact:Hide()
    r.fav = font(r, "", 14, 1, .82, 0); r.fav:SetPoint("LEFT", r, "LEFT", 493, 0)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if not self.guildName then return end
      BLFG.selectedGuild = self.guildName
      BLFG.selectedGuildData = self.guildData
      BLFG.guildDetailGuild = self.guildData
      BLFG:SaveGuildBrowserState()
      if button == "RightButton" then
        BLFG:ShowGuildMenu(self, self.guildData)
      elseif button == "LeftButton" and IsShiftKeyDown() and self.guildData and self.guildData.contact ~= "" then
        ChatFrame_OpenChat("/w " .. self.guildData.contact .. " ")
      end
      if self.guildData and BLFG.RefreshGuildDetailPanel then BLFG:RefreshGuildDetailPanel(self.guildData) end
      BLFG:RefreshGuildBrowser()
    end)
    r:SetScript("OnEnter", function(self)
      if not self.guildData then return end
      local g = self.guildData
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT", 0, 0)
      GameTooltip:ClearLines()
      GameTooltip:SetText("|cFFFFCC00" .. tostring(g.name or "Guild") .. "|r", 1, .82, 0)
      local sfOnline = tonumber(g.signalFireOnline or g.online or 0) or 0
      local whoOnline = tonumber(g.whoOnline or 0) or 0
      if whoOnline > 0 then
        GameTooltip:AddLine("SignalFire Network: " .. tostring(sfOnline), 1, 1, 1)
        GameTooltip:AddLine("/who Seen: " .. tostring(whoOnline), 1, 1, 1)
      else
        GameTooltip:AddLine("SignalFire Network: " .. tostring(sfOnline), 1, 1, 1)
      end
      GameTooltip:AddLine("Source: " .. tostring(g.source or "Recent Recruitment Message"), .8, .8, .8)
      GameTooltip:AddLine("Status: " .. tostring(g.status or "Unknown"), 1, 1, 1)
      if g.recruiting then GameTooltip:AddLine("Recruiting: " .. BLFG_5627_RoleTags(BLFG_5627_GetRawRoles(g)), 1, .82, 0) end
      if g.focus then GameTooltip:AddLine("Focus: " .. BLFG_5627_ColorFocusShort(BLFG_5627_GetRawFocus(g), 4), .9, .9, .9) end
      if g.lastPostTime then GameTooltip:AddLine("Last Guild Post: " .. tostring(g.lastPostTime), .65, .85, 1) end
      if g.memberSummary and g.memberSummary ~= "" then GameTooltip:AddLine("Online Now: " .. tostring(g.memberSummary), .65, .85, 1) end
      local intel = BLFG:GetGuildIntelligence(g.name)
      if intel then
        GameTooltip:AddLine("Activity: " .. tostring(intel.activity), .4, 1, .4)
        GameTooltip:AddLine("Roles: Tank " .. tostring(intel.tanks) .. " / Healer " .. tostring(intel.healers) .. " / DPS " .. tostring(intel.dps), 1, 1, 1)
        GameTooltip:AddLine("Zones: " .. tostring(intel.zoneText), .65, .85, 1)
      end
      if g.lastPost and g.lastPost ~= "" then GameTooltip:AddLine(" "); GameTooltip:AddLine(shortenPublicText(g.lastPost, 180), 1, 1, 1, true) end
      if g.contact and g.contact ~= "" then GameTooltip:AddLine("Contact: " .. g.contact .. " (" .. (g.contactOnline and "Online" or "Offline") .. ")", .65, .85, 1) end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Right Click for Options", .4, 1, .4)
      GameTooltip:AddLine("Shift-Click to whisper contact", .8, .8, .8)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.guildRows[i] = r
  end

  self.guildFooter = font(list, "Guild Browser uses SignalFire Network presence plus recent Public Groups guild posts.", 10, .65, .85, 1)
  self.guildFooter:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 14, 44)

  local openOnline = button(list, "Show SignalFire Network", 170, 26)
  openOnline:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -12, 12)
  openOnline:SetScript("OnClick", function() BLFG:ToggleOnlinePanel() end)
  self.guildOpenOnlineButton = openOnline

  local createRecruit = button(list, "Create Recruitment Ad", 180, 26)
  createRecruit:SetPoint("RIGHT", openOnline, "LEFT", -12, 0)
  createRecruit:SetScript("OnClick", function() BLFG:OpenRecruitmentCreator() end)
  self.guildRecruitCreatorBtn = createRecruit

  local clearGuilds = button(list, "Clear Listings", 120, 26)
  clearGuilds:SetPoint("RIGHT", createRecruit, "LEFT", -12, 0)
  clearGuilds:SetScript("OnClick", function() BLFG:ClearLocalGuildListings() end)
  self.guildClearListingsBtn = clearGuilds

  self:BuildGuildDetailPanel(p)
end


function BLFG:BuildGuildDetailPanel(parent)
  local d = CreateFrame("Frame", nil, parent)
  self.guildDetailPanel = d
  d:SetWidth(292); d:SetHeight(389)
  d:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, -126)
  backdrop(d, .96)

  d.title = font(d, "Select a Guild", 16, 1, .75, 0); d.title:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -12); d.title:SetWidth(260); d.title:SetJustifyH("LEFT")

  d.tabOverview = button(d, "Overview", 82, 22); d.tabOverview:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -38)
  d.tabRecruitment = button(d, "Recruitment", 92, 22); d.tabRecruitment:SetPoint("LEFT", d.tabOverview, "RIGHT", 5, 0)
  d.tabSeen = button(d, "Seen Players", 94, 22); d.tabSeen:SetPoint("LEFT", d.tabRecruitment, "RIGHT", 5, 0)
  d.tabOverview:SetScript("OnClick", function() BLFG:SetGuildDetailTab("Overview") end)
  d.tabRecruitment:SetScript("OnClick", function() BLFG:SetGuildDetailTab("Recruitment") end)
  d.tabSeen:SetScript("OnClick", function() BLFG:SetGuildDetailTab("Seen") end)

  d.status = font(d, "Status: --", 11, .9, .9, .9); d.status:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -68); d.status:SetWidth(260); d.status:SetJustifyH("LEFT")
  d.recruiting = font(d, "Recruiting: --", 11, .9, .9, .9); d.recruiting:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -88); d.recruiting:SetWidth(260); d.recruiting:SetJustifyH("LEFT")
  d.online = font(d, "Online Now: --", 11, .9, .9, .9); d.online:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -108); d.online:SetWidth(260); d.online:SetJustifyH("LEFT")
  d.contact = font(d, "Contact: --", 11, .65, .85, 1); d.contact:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -128); d.contact:SetWidth(260); d.contact:SetJustifyH("LEFT")
  d.lastPost = font(d, "Last Post: --", 11, .8, .8, .8); d.lastPost:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -148); d.lastPost:SetWidth(260); d.lastPost:SetJustifyH("LEFT")
  d.members = font(d, "SignalFire Network: --", 10, .65, .85, 1); d.members:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -168); d.members:SetWidth(260); d.members:SetJustifyH("LEFT")

  d.focusLabel = font(d, "Focus:", 11, 1, .75, 0); d.focusLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -191)
  d.focus = font(d, "[--]", 11, .85, .95, 1); d.focus:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -211); d.focus:SetWidth(260); d.focus:SetJustifyH("LEFT")

  local recentBox = CreateFrame("Frame", nil, d)
  d.recentBox = recentBox
  recentBox:SetWidth(268); recentBox:SetHeight(112)
  recentBox:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -238)
  backdrop(recentBox, .88)
  d.recentTitle = font(recentBox, "Recent Recruitment Message", 11, 1, .75, 0); d.recentTitle:SetPoint("TOPLEFT", recentBox, "TOPLEFT", 8, -8)
  d.message = font(recentBox, "Select a guild to view details.", 10, 1, 1, 1)
  d.message:SetPoint("TOPLEFT", recentBox, "TOPLEFT", 8, -30)
  d.message:SetWidth(250); d.message:SetHeight(70); d.message:SetJustifyH("LEFT"); d.message:SetJustifyV("TOP")

  d.whisper = button(d, "Whisper", 86, 24); d.whisper:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 12, 12)
  d.copy = button(d, "Copy Name", 86, 24); d.copy:SetPoint("LEFT", d.whisper, "RIGHT", 8, 0)
  d.favorite = button(d, "Favorite", 86, 24); d.favorite:SetPoint("LEFT", d.copy, "RIGHT", 8, 0)
end


function BLFG:GetGuildIntelligence(guildName)
  local members = self:GetOnlineGuildMembers(guildName)
  local intel = {online=#members, tanks=0, healers=0, dps=0, unknown=0, zones={}, zoneText="None", activity="Quiet"}
  local zoneCounts = {}
  for _, u in ipairs(members) do
    local r = lower(tostring(u.role or ""))
    if r == "t" or r == "tank" then intel.tanks = intel.tanks + 1
    elseif r == "h" or r == "heal" or r == "healer" then intel.healers = intel.healers + 1
    elseif r == "d" or r == "dps" or r == "damage" then intel.dps = intel.dps + 1
    else intel.unknown = intel.unknown + 1 end
    local z = tostring(u.zone or "")
    if z ~= "" then zoneCounts[z] = (zoneCounts[z] or 0) + 1 end
  end
  local zones = {}
  for z,c in pairs(zoneCounts) do table.insert(zones, {zone=z, count=c}) end
  table.sort(zones, function(a,b) if a.count ~= b.count then return a.count > b.count end return a.zone < b.zone end)
  intel.zones = zones
  local parts = {}
  for i,z in ipairs(zones) do
    if i > 3 then break end
    table.insert(parts, tostring(z.zone) .. " (" .. tostring(z.count) .. ")")
  end
  if #parts > 0 then intel.zoneText = table.concat(parts, ", ") end
  if intel.online >= 5 then intel.activity = "High"
  elseif intel.online >= 2 then intel.activity = "Active"
  elseif intel.online == 1 then intel.activity = "Low"
  else intel.activity = "Quiet" end
  return intel
end

local function guildIntelText(intel, g)
  local post = tostring((g and g.lastPost) or "")
  if post == "" then
    post = "No recent recruitment message captured yet."
  end
  return shortenPublicText(post, 260)
end

function BLFG:RefreshGuildDetailPanel(g)
  local d = self.guildDetailPanel
  if not d then return end
  if self.currentTab == "Guild Browser" and (not self.bronzeNetProfile or not self.bronzeNetProfile:IsShown()) then d:Show() end
  local discord = self:GetGuildDiscord(g)
  if not g then
    d.guildData = nil
    d.title:SetText("Select a Guild")
    d.focus:SetText("|cff888888[--]|r")
    d.status:SetText("Status: --")
    d.recruiting:SetText("Recruiting: --")
    d.online:SetText("Online Now: --")
    d.contact:SetText("Contact: --")
    d.lastPost:SetText("Last Post: --")
    if d.members then d.members:SetText("SignalFire Network: --") end
    d.message:SetText("Select a guild to view details.")
    return
  end
  d.guildData = g
  -- Clear all mutable text first so fast row changes never leave ghosted stale labels.
  d.title:SetText("")
  d.focus:SetText("")
  d.status:SetText("")
  d.recruiting:SetText("")
  d.online:SetText("")
  d.contact:SetText("")
  d.lastPost:SetText("")
  if d.members then d.members:SetText("") end
  d.message:SetText("")
  d.title:SetText(shortenPublicText(tostring(g.name or "Guild"), 28))
  d.status:SetText("Status: " .. tostring(g.status or "--") .. "  |  Source: " .. tostring(g.source or "--"))
  d.recruiting:SetText("Recruiting: " .. tostring(g.recruiting or "--"))
  d.online:SetText("Online Now: " .. tostring(g.online or 0) .. "  |  Posts: " .. tostring(g.posts or 0))
  local contactLabel = tostring(g.contact or "--")
  if g.contact and g.contact ~= "" then
    contactLabel = contactLabel .. "  " .. bronzeNetStatusText(self:FindOnlineUser(g.contact))
  end
  d.contact:SetText("Contact: " .. contactLabel)
  d.lastPost:SetText("Last Post: " .. tostring(g.lastPostTime or "--"))
  local intel = self:GetGuildIntelligence(g.name)
  if d.members then
    local memberLine = g.memberSummary and g.memberSummary ~= "" and g.memberSummary or "None seen on SignalFire Network"
    d.members:SetText("SignalFire Network: " .. shortenPublicText(memberLine, 42))
  end
  d.focus:SetText(guildFocusTagsText(g.focus or "--", 4))
  d.message:SetText(guildIntelText(intel, g))

  d.whisper:SetScript("OnClick", function()
    if g.contact and g.contact ~= "" then ChatFrame_OpenChat("/w " .. g.contact .. " ") end
  end)
  d.copy:SetScript("OnClick", function() ChatFrame_OpenChat(tostring(g.name or "")) end)
  d.favorite:SetText(g.favorite and "Unfavorite" or "Favorite")
  d.favorite:SetScript("OnClick", function() BLFG:ToggleFavoriteGuild(g.name); BLFG:SaveGuildBrowserState(); BLFG:RefreshGuildBrowser() end)
end

function BLFG:ShowGuildBrowser()
  self:CreateUI()
  self.currentTab = "Guild Browser"
  self:HidePanels()
  self:RestoreGuildBrowserState()
  self.guildPanel:Show()
  self:ShowGuildDetailMode("guild")
  self.frame:Show()
  self:SendPresence()
  self:RefreshGuildBrowser()
end

function BLFG:RefreshGuildBrowser()
  if not self.guildRows then return end
  local rows = self:GetGuildRows()
  if self.guildCountText then self.guildCountText:SetText("Guilds found: " .. tostring(#rows) .. "  |  Live: " .. tostring(self.guildLiveCount or 0) .. "  |  Chat: " .. tostring(self.guildPostOnlyCount or 0) .. "  |  /who: " .. tostring(self.guildWhoCount or 0)) end
  if self.guildFavFilterButton then
    self.guildFavFilterButton:SetText(self.guildFavoritesOnly and "Favorites: On" or "Favorites: Off")
  end
  if self.guildFocusFilterButton then
    self.guildFocusFilterButton:SetText("Focus: " .. tostring(self.guildFocusFilter or "All"))
  end
  self.selectedGuildData = nil
  for i, r in ipairs(self.guildRows) do
    local g = rows[i]
    if g and r and r.Show then
      r:Show()
      r.guildName = g.name
      r.guildData = g
      if string.lower(tostring(self.selectedGuild or "")) == string.lower(tostring(g.name or "")) then self.selectedGuild = tostring(g.name or self.selectedGuild or ""); r:SetBackdropColor(.25,.25,.05,.95); self.selectedGuildData = g else r:SetBackdropColor(0,0,0,.80) end
      r.guild:SetText((g.favorite and "|cffffd100â˜… |r" or "") .. tostring(g.name or ""))
      r.online:SetText(tostring(g.online or 0))
      r.status:SetText(shortenPublicText(g.status or "Unknown", 10))
      r.recruiting:SetText(shortenPublicText(g.recruiting or "Unknown", 12))
      r.focus:SetText(guildFocusTagsText(g.focus or "--", 1))
      r.lastPost:SetText(g.lastPostTime or "--")
      r.contact:SetText(shortenPublicText(g.contact or "", 10))
      r.fav:SetText(g.favorite and "â˜…" or "")
    else
      if r and r.guildName ~= nil then r.guildName = nil end
      r.guildData = nil
      r.guild:SetText("")
      r.online:SetText("")
      r.status:SetText("")
      r.recruiting:SetText("")
      r.focus:SetText("")
      r.lastPost:SetText("")
      r.contact:SetText("")
      r.fav:SetText("")
      r:SetBackdropColor(0,0,0,.80)
      r:Hide()
    end
  end
  self:RefreshGuildDetailPanel(self.selectedGuildData or rows[1])
end

function BLFG:ShowGuildMenu(anchor, g)
  if not g or not g.name then return end
  if not self.guildMenu then
    self.guildMenu = CreateFrame("Frame", "BronzeLFGGuildMenu", UIParent, "UIDropDownMenuTemplate")
  end
  local guild = tostring(g.name or "")
  local contact = tostring(g.contact or "")
  local unknownGuild = g.isUnknownGuild == true
  UIDropDownMenu_Initialize(self.guildMenu, function()
    local info = UIDropDownMenu_CreateInfo()
    info.text = guild
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = contact ~= "" and ("Whisper " .. contact) or "Whisper Contact"
    info.notCheckable = true
    info.disabled = (contact == "")
    info.func = function() if contact ~= "" then ChatFrame_OpenChat("/w " .. contact .. " ") end end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "View Contact Profile"
    info.notCheckable = true
    info.disabled = (not BLFG:FindOnlineUser(contact))
    info.func = function() local u = BLFG:FindOnlineUser(contact); if u then BLFG:ShowBronzeNetProfile(u) end end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = unknownGuild and "Copy Contact Name to Chat" or "Copy Guild Name to Chat"
    info.notCheckable = true
    info.func = function() ChatFrame_OpenChat(unknownGuild and contact or guild) end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = BLFG:IsFavoriteGuild(guild) and "Remove Favorite Guild" or "Add Favorite Guild"
    info.notCheckable = true
    info.disabled = unknownGuild
    info.func = function() if not unknownGuild then BLFG:ToggleFavoriteGuild(guild) end end
    UIDropDownMenu_AddButton(info)

    info = UIDropDownMenu_CreateInfo()
    info.text = "Cancel"
    info.notCheckable = true
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info)
  end, "MENU")
  ToggleDropDownMenu(1, nil, self.guildMenu, anchor, 0, 0)
end

function BLFG:BuildOptions()
  local p = CreateFrame("Frame", nil, self.content)
  self.optionsPanel = p
  p:SetAllPoints()
  p:Hide()

  font(p, "Options", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(820); box:SetHeight(470)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  backdrop(box, .96)

  font(box, "SignalFire Settings", 17, 1, .75, 0):SetPoint("TOP", box, "TOP", 0, -18)
  font(box, "Options auto-save when changed.", 11, .85, .95, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -58)

  local opts = BronzeLFG_DB.options or {}
  local function check(name, label, x, y, checked, onClick)
    local c = CreateFrame("CheckButton", name, box, "UICheckButtonTemplate")
    c:SetPoint("TOPLEFT", box, "TOPLEFT", x, y)
    _G[c:GetName().."Text"]:SetText("")
    c:SetChecked(checked)
    c:SetScript("OnClick", onClick or function() BLFG:SaveOptions(false) end)
    font(box, label, 11, 1, 1, 1):SetPoint("LEFT", c, "RIGHT", 4, 1)
    return c
  end

  font(box, "General", 14, 1, .75, 0):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -88)

  -- Row 1
  self.optMinimap = check("BLFGOptMinimap", "Show Minimap Icon", 24, -112, opts.showMinimap ~= false)
  self.optFreeLauncher = check("BLFGOptFreeLauncher", "Unlock Minimap Icon", 330, -112, opts.freeLauncher == true)

  -- Row 2
  self.optSavePosition = check("BLFGOptSavePosition", "Remember Window Position", 24, -144, opts.savePosition ~= false)
  self.optPublic = check("BLFGOptPublicGroups", "Build Public Groups From Chat", 330, -144, opts.publicGroups ~= false)
  font(box, "Server Profile", 13, .35, .7, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 580, -88)
  self.serverProfileDD = dropdown(box, "BLFGServerProfileDropdown", 130, {"Triumvirate", "Ascension"}, opts.serverProfile or "Triumvirate", function(v)
    BronzeLFG_DB.options = BronzeLFG_DB.options or {}
    BronzeLFG_DB.options.serverProfile = v or "Triumvirate"
    if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Profile saved. /reload to apply parser data.") end
  end)
  self.serverProfileDD:SetPoint("TOPLEFT", box, "TOPLEFT", 580, -110)

  -- SignalFire 1.4.9: Modules are visible from the core Options panel so profile-gated
  -- features can be toggled even if a late module UI wrapper is skipped.
  font(box, "Modules", 13, .35, .7, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 580, -248)
  self.optModuleInvasions = check("BLFGOptModuleInvasionsCore", "Invasions", 580, -270,
    (self.SFCore149_ModuleEnabled and self:SFCore149_ModuleEnabled("invasions")) or false,
    function(btn)
      if BLFG.SFModuleSetEnabled then
        BLFG:SFModuleSetEnabled("invasions", btn:GetChecked() and true or false)
      else
        BronzeLFG_DB.options = BronzeLFG_DB.options or {}
        BronzeLFG_DB.options.modulesByProfile = BronzeLFG_DB.options.modulesByProfile or {}
        local profile = (BLFG.SF143_GetProfileId and BLFG:SF143_GetProfileId()) or BronzeLFG_DB.options.serverProfile or "Triumvirate"
        BronzeLFG_DB.options.modulesByProfile[profile] = BronzeLFG_DB.options.modulesByProfile[profile] or {}
        BronzeLFG_DB.options.modulesByProfile[profile].invasions = (profile ~= "Ascension") and (btn:GetChecked() and true or false) or false
        if BLFG.side then BLFG:BuildSide() end
      end
      if BLFG.SFModulesApply then BLFG:SFModulesApply() elseif BLFG.side then BLFG:BuildSide() end
      if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Module saved: Invasions " .. ((BLFG.SFCore149_ModuleEnabled and BLFG:SFCore149_ModuleEnabled("invasions")) and "on" or "off") .. ".") end
    end)
  self.optGuildWhoDiscovery = check("BLFGOptGuildWhoDiscovery", "Enable /who Discovery", 580, -205, opts.guildWhoDiscovery ~= false)
  font(box, "Discovery Mode: Manual Refresh Only", 10, .8, .8, .8):SetPoint("TOPLEFT", box, "TOPLEFT", 606, -229)

  -- Row 3: expire + scale, separated so labels cannot collide
  font(box, "Public Groups Expire After", 11, 1, 1, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -184)
  self.publicExpireBox = edit(box, 60, 22, false)
  self.publicExpireBox:SetPoint("TOPLEFT", box, "TOPLEFT", 220, -180)
  self.publicExpireBox:SetText(tostring(math.floor((opts.publicExpire or 300) / 60)))
  self.publicExpireBox:SetScript("OnEditFocusLost", function() BLFG:SaveOptions(false) end)
  self.publicExpireBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); BLFG:SaveOptions(false) end)
  font(box, "minutes", 10, .85, .85, .85):SetPoint("LEFT", self.publicExpireBox, "RIGHT", 8, 0)

  font(box, "Window Scale", 11, 1, 1, 1):SetPoint("TOPLEFT", box, "TOPLEFT", 430, -184)
  self.scaleDropdown = dropdown(box, "BLFGScalePresetDropdown", 90, SCALE_OPTIONS, scaleLabelFromValue(opts.scale or 1.0), function(v)
    BronzeLFG_DB.options = BronzeLFG_DB.options or {}
    BronzeLFG_DB.options.scale = scaleValueFromLabel(v)
    if BLFG.frame then BLFG.frame:SetScale(BronzeLFG_DB.options.scale) end
    if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
  end)
  self.scaleDropdown:SetPoint("TOPLEFT", box, "TOPLEFT", 560, -181)

  -- Alerts are spaced farther apart so dropdown menus do not cover the next row.
  font(box, "Alerts", 14, 1, .75, 0):SetPoint("TOPLEFT", box, "TOPLEFT", 24, -235)
  self.optNotify = check("BLFGOptNotify", "Enable Listing Alerts", 24, -260, opts.notifyEnabled ~= false)

  self.optNotifyHCBB = check("BLFGOptNotifyHCBB", "Event Listings", 24, -300, opts.notifyHCBB ~= false)
  self.eventFilterDD = dropdown(box, "BLFGEventAlertDropdown", 150, EVENT_ALERT_OPTIONS, opts.notifyEventFilter or "Any Event", function(v)
    BronzeLFG_DB.options.notifyEventFilter = v
    if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
  end)
  self.eventFilterDD:SetPoint("TOPLEFT", box, "TOPLEFT", 220, -303)

  self.optNotifyRaid = check("BLFGOptNotifyRaid", "Raid Listings", 24, -355, opts.notifyRaid ~= false)
  self.raidFilterDD = dropdown(box, "BLFGRaidAlertDropdown", 150, RAID_ALERT_OPTIONS, opts.notifyRaidFilter or "Any Raid", function(v)
    BronzeLFG_DB.options.notifyRaidFilter = v
    if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
  end)
  self.raidFilterDD:SetPoint("TOPLEFT", box, "TOPLEFT", 220, -358)

  self.optNotifyKey = check("BLFGOptNotifyKey", "Key Listings", 430, -300, opts.notifyKey ~= false)
  self.keyFilterDD = dropdown(box, "BLFGKeyAlertDropdown", 150, KEY_ALERT_OPTIONS, opts.notifyKeyFilter or "Any Key", function(v)
    BronzeLFG_DB.options.notifyKeyFilter = v
    if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
  end)
  self.keyFilterDD:SetPoint("TOPLEFT", box, "TOPLEFT", 625, -303)

  self.optNotifyDungeon = check("BLFGOptNotifyDungeon", "Dungeon Listings", 430, -355, opts.notifyDungeon ~= false)

  font(box, "Sounds", 14, 1, .75, 0):SetPoint("TOPLEFT", box, "TOPLEFT", 35, -390)
  self.optNotifySound = check("BLFGOptNotifySound", "Play Alert Sound", 35, -415, opts.notifySound == true)

  local profile = button(box, "Open Profile", 130, 30)
  profile:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -18, 24)
  profile:SetScript("OnClick", function() BLFG:ShowProfile() end)

  local reset = button(box, "Reset Settings", 130, 30)
  reset:SetPoint("RIGHT", profile, "LEFT", -24, 0)
  reset:SetScript("OnClick", function()
    BronzeLFG_DB = {}
    ReloadUI()
  end)

  self.optionsStatus = font(box, "Options auto-save.", 12, 0.5, 1, 0.5)
  self.optionsStatus:SetPoint("BOTTOMRIGHT", profile, "TOPRIGHT", 0, 10)
end

function BLFG:ShowOptions()
  self:CreateUI()
  self:HidePanels()
  self.optionsPanel:Show()
  self.frame:Show()
end

function BLFG:SaveOptions(showFlash)
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  BronzeLFG_DB.options.autoOpen = false
  BronzeLFG_DB.options.showMinimap = self.optMinimap and self.optMinimap:GetChecked() and true or false
  BronzeLFG_DB.options.savePosition = self.optSavePosition and self.optSavePosition:GetChecked() and true or false
  BronzeLFG_DB.options.scale = scaleValueFromLabel(self.scaleDropdown and dd(self.scaleDropdown) or scaleLabelFromValue(BronzeLFG_DB.options.scale or 1.0))
  BronzeLFG_DB.options.publicGroups = self.optPublic and self.optPublic:GetChecked() and true or false
  BronzeLFG_DB.options.guildWhoDiscovery = self.optGuildWhoDiscovery and self.optGuildWhoDiscovery:GetChecked() and true or false
  BronzeLFG_DB.options.serverProfile = self.serverProfileDD and dd(self.serverProfileDD) or BronzeLFG_DB.options.serverProfile or "Triumvirate"
  BronzeLFG_DB.options.freeLauncher = self.optFreeLauncher and self.optFreeLauncher:GetChecked() and true or false
  BronzeLFG_DB.options.notifyEnabled = self.optNotify and self.optNotify:GetChecked() and true or false
  BronzeLFG_DB.options.notifySound = self.optNotifySound and self.optNotifySound:GetChecked() and true or false
  BronzeLFG_DB.options.notifyHCBB = self.optNotifyHCBB and self.optNotifyHCBB:GetChecked() and true or false
  BronzeLFG_DB.options.notifyKey = self.optNotifyKey and self.optNotifyKey:GetChecked() and true or false
  BronzeLFG_DB.options.notifyRaid = self.optNotifyRaid and self.optNotifyRaid:GetChecked() and true or false
  BronzeLFG_DB.options.notifyGuild = false
  BronzeLFG_DB.options.notifyDungeon = self.optNotifyDungeon and self.optNotifyDungeon:GetChecked() and true or false
  BronzeLFG_DB.options.notifyEventFilter = self.eventFilterDD and dd(self.eventFilterDD) or BronzeLFG_DB.options.notifyEventFilter or "Any Event"
  BronzeLFG_DB.options.notifyRaidFilter = self.raidFilterDD and dd(self.raidFilterDD) or BronzeLFG_DB.options.notifyRaidFilter or "Any Raid"
  BronzeLFG_DB.options.notifyKeyFilter = self.keyFilterDD and dd(self.keyFilterDD) or BronzeLFG_DB.options.notifyKeyFilter or "Any Key"

  local mins = tonumber(self.publicExpireBox and self.publicExpireBox:GetText() or "5") or 5
  if mins < 1 then mins = 1 end
  if mins > 30 then mins = 30 end
  BronzeLFG_DB.options.publicExpire = mins * 60

  self.minimapHidden = not BronzeLFG_DB.options.showMinimap
  BronzeLFG_DB.minimapHidden = self.minimapHidden
  if self.frame then self.frame:SetScale(BronzeLFG_DB.options.scale) end
  self:UpdateMinimap()
  if self.optionsStatus then self.optionsStatus:SetText("Options saved.") end
  if showFlash ~= false then flash("Options saved.") end
end

function BLFG:BuildMinimap()
  local b = CreateFrame("Button", "BronzeLFGMinimapButton", UIParent)
  self.mm = b
  b:SetWidth(32); b:SetHeight(32)
  b:SetFrameStrata("MEDIUM")
  b:SetMovable(true); b:EnableMouse(true)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local ic = b:CreateTexture(nil, "BACKGROUND")
  ic:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
  ic:SetWidth(22); ic:SetHeight(22); ic:SetPoint("CENTER")
  b.icon = ic
  local br = b:CreateTexture(nil, "OVERLAY")
  br:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  br:SetWidth(54); br:SetHeight(54); br:SetPoint("TOPLEFT")
  b.border = br
  b:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then BLFG:ShowProfile() else BLFG:Toggle() end
  end)
  b:SetScript("OnDragStart", function(self)
    if BronzeLFG_DB.options and BronzeLFG_DB.options.freeLauncher then
      self:StartMoving()
    else
      self.dragging = true
    end
  end)
  b:SetScript("OnDragStop", function(self)
    if BronzeLFG_DB.options and BronzeLFG_DB.options.freeLauncher then
      self:StopMovingOrSizing()
      local point, _, relPoint, x, y = self:GetPoint()
      BronzeLFG_DB.launcherPosition = {point=point or "CENTER", relPoint=relPoint or "CENTER", x=tonumber(x) or 0, y=tonumber(y) or 0}
    else
      self.dragging = false
      if Minimap and GetCursorPosition and UIParent then
        local mx,my = Minimap:GetCenter()
        local px,py = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        px = px / scale; py = py / scale
        local angle = math.deg(math.atan2(py-my, px-mx))
        BLFG.minimapAngle = ((angle % 360) + 360) % 360
        BronzeLFG_DB.minimap = BronzeLFG_DB.minimap or {}
        BronzeLFG_DB.minimap.angle = BLFG.minimapAngle
        BronzeLFG_DB.minimapAngle = BLFG.minimapAngle
      end
    end
  end)
  b:SetScript("OnUpdate", function(self)
    if self.dragging and not (BronzeLFG_DB.options and BronzeLFG_DB.options.freeLauncher) then
      local mx,my = Minimap:GetCenter()
      local px,py = GetCursorPosition()
      local scale = UIParent:GetEffectiveScale()
      px = px / scale; py = py / scale
      BLFG.minimapAngle = ((math.deg(math.atan2(py-my, px-mx)) % 360) + 360) % 360
      BronzeLFG_DB.minimap = BronzeLFG_DB.minimap or {}
      BronzeLFG_DB.minimap.angle = BLFG.minimapAngle
      BronzeLFG_DB.minimapAngle = BLFG.minimapAngle
      BLFG:UpdateMinimap()
    end
    if BLFG.newApplicantAlert then
      local pulse = (math.sin(GetTime() * 7) + 1) / 2
      self:SetAlpha(.65 + (.35 * pulse))
      if ic then ic:SetVertexColor(1, .35 + (.65 * pulse), .15, 1) end
      if br then br:SetVertexColor(1, .75 + (.25 * pulse), .15, 1) end
    else
      self:SetAlpha(1)
      if ic then ic:SetVertexColor(1, 1, 1, 1) end
      if br then br:SetVertexColor(1, 1, 1, 1) end
    end
  end)
  self:UpdateMinimap()
end

function BLFG:UpdateMinimap()
  if not self.mm then return end
  BronzeLFG_DB.minimap = BronzeLFG_DB.minimap or {}
  local savedAngle = tonumber(BronzeLFG_DB.minimap.angle or BronzeLFG_DB.minimapAngle or self.minimapAngle or 215) or 215
  self.minimapAngle = ((savedAngle % 360) + 360) % 360
  BronzeLFG_DB.minimap.angle = self.minimapAngle
  BronzeLFG_DB.minimapAngle = self.minimapAngle
  self.mm:ClearAllPoints()
  if BronzeLFG_DB.options and BronzeLFG_DB.options.freeLauncher then
    self.mm:SetParent(UIParent)
    local pos = BronzeLFG_DB.launcherPosition
    if pos then
      self.mm:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or "CENTER", pos.x or 0, pos.y or 0)
    else
      self.mm:SetPoint("CENTER", UIParent, "CENTER", -260, 180)
    end
  else
    self.mm:SetParent(Minimap)
    local a = math.rad(self.minimapAngle or 215)
    self.mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a)*80, math.sin(a)*80)
  end
  if self.minimapHidden or (BronzeLFG_DB.options and BronzeLFG_DB.options.showMinimap == false) then self.mm:Hide() else self.mm:Show() end
end

function BLFG:HidePanels()
  if self.onlinePanel then self.onlinePanel:Hide() end
  if self.bronzeNetProfile then self.bronzeNetProfile:Hide() end
  if self.browse then self.browse:Hide() end
  if self.create then self.create:Hide() end
  if self.profile then self.profile:Hide() end
  if self.apps then self.apps:Hide() end
  if self.optionsPanel then self.optionsPanel:Hide() end
  if self.publicPanel then self.publicPanel:Hide() end
  if self.guildPanel then self.guildPanel:Hide() end
  if self.myPanel then self.myPanel:Hide() end
end
function BLFG:Show()
  self:CreateUI(); self.frame:Show(); self:RefreshBrowse()
end
function BLFG:Hide()
  if self.frame then self.frame:Hide() end
end
function BLFG:Toggle()
  self:CreateUI()
  if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end

local function detectEquippedItemLevel()
  if not GetInventoryItemLink or not GetItemInfo then return nil end
  local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
  local total, count = 0, 0
  for _, slot in ipairs(slots) do
    local link = GetInventoryItemLink("player", slot)
    if link then
      local _, _, _, itemLevel = GetItemInfo(link)
      itemLevel = tonumber(itemLevel)
      if itemLevel and itemLevel > 0 then
        total = total + itemLevel
        count = count + 1
      end
    end
  end
  if count > 0 then return math.floor((total / count) + 0.5) end
  return nil
end

function BLFG_DetectTalentSpec()
  if not GetTalentTabInfo then return nil end
  local bestName, bestPoints = nil, 0
  local group = GetActiveTalentGroup and GetActiveTalentGroup() or nil
  for i = 1, 3 do
    local name, _, points = GetTalentTabInfo(i, false, false, group)
    if not name then name, _, points = GetTalentTabInfo(i) end
    points = tonumber(points) or 0
    if name and points > bestPoints then
      bestName, bestPoints = name, points
    end
  end
  if bestPoints > 0 then return bestName end
  return nil
end

function BLFG_IsTalentSpecName(spec)
  if not spec or spec == "" or not GetTalentTabInfo then return false end
  local group = GetActiveTalentGroup and GetActiveTalentGroup() or nil
  for i = 1, 3 do
    local name = GetTalentTabInfo(i, false, false, group)
    if not name then name = GetTalentTabInfo(i) end
    if name == spec then return true end
  end
  return false
end

function BLFG_RoleForDetectedSpec(spec)
  local s = string.lower(tostring(spec or ""))
  if s == "protection" or s == "guardian" then return "Tank" end
  if s == "holy" or s == "discipline" or s == "restoration" then return "Healer" end
  if s ~= "" then return "DPS" end
  return nil
end

function BLFG:AutoFillProfile()
  -- Warcraft Reborn's custom advancement UI does not report active spec reliably.
  -- SignalFire auto-refreshes equipped item level. Spec is filled from talents when readable, but stays editable.
  if not BronzeLFG_DB.profile then return end
  local ilvl = detectEquippedItemLevel()
  if ilvl and self.profileIlvl then
    self.profileIlvl:SetText(tostring(ilvl))
    BronzeLFG_DB.profile.itemLevel = tostring(ilvl)
  end
  if self.profileRoleType and BLFG_DetectTalentSpec then
    local spec = BLFG_DetectTalentSpec()
    if spec and spec ~= "" then
      local currentSpec = self.profileRoleType:GetText() or ""
      local previousAuto = BronzeLFG_DB.profile.autoDetectedSpec or ""
      if currentSpec == "" or currentSpec == previousAuto or BLFG_IsTalentSpecName(currentSpec) then
        self.profileRoleType:SetText(spec)
        BronzeLFG_DB.profile.roleType = spec
        BronzeLFG_DB.profile.autoDetectedSpec = spec
        local detectedRole = BLFG_RoleForDetectedSpec(spec)
        if detectedRole and self.profileRole then
          UIDropDownMenu_SetText(self.profileRole, detectedRole)
          BronzeLFG_DB.profile.role = detectedRole
        end
      end
    end
  end
  if self.profileClassText and UnitClass then
    self.profileClassText:SetText(select(1, UnitClass("player")) or "")
  end
  if self.UpdateWhisperPreview569 then self:UpdateWhisperPreview569() end
end

function BLFG:ShowBrowse()
  self:CreateUI(); self:HidePanels(); self.browse:Show(); self.currentTab="Browse"; self:RefreshBrowse()
end
function BLFG:ShowCreate()
  self:CreateUI(); self:HidePanels(); self.create:Show(); self.currentTab="Create"
end
function BLFG:ShowProfile()
  self:CreateUI(); self:HidePanels(); self.profile:Show(); self.frame:Show(); self.currentTab="Profile"; self:AutoFillProfile()
end
function BLFG:ShowApplicants()
  if self.SetApplicantAlert then self:SetApplicantAlert(false) else self.newApplicantAlert = false end
  self:CreateUI(); self:HidePanels(); self.apps:Show(); self.currentTab="Applicants"; self:RefreshApplicants()
end

function BLFG:ClearProfileRoleSpec()
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  BronzeLFG_DB.profile.role = "Flexible"
  BronzeLFG_DB.profile.roleType = ""
  if self.profileRole then UIDropDownMenu_SetText(self.profileRole, "Flexible") end
  if self.profileRoleType then self.profileRoleType:SetText("") end
  flash("Role and spec cleared. Choose your role/spec and save when ready.")
end

function BLFG:SaveProfile()
  BronzeLFG_DB.profile.role = BLFG_DropdownText(self.profileRole)
  local detectedIlvl = detectEquippedItemLevel()
  BronzeLFG_DB.profile.itemLevel = detectedIlvl and tostring(detectedIlvl) or (self.profileIlvl and self.profileIlvl:GetText() or "")
  if detectedIlvl and self.profileIlvl then self.profileIlvl:SetText(tostring(detectedIlvl)) end
  BronzeLFG_DB.profile.roleType = self.profileRoleType:GetText()
  if BronzeLFG_DB.profile.autoDetectedSpec and BronzeLFG_DB.profile.roleType ~= BronzeLFG_DB.profile.autoDetectedSpec then
    BronzeLFG_DB.profile.autoDetectedSpec = nil
  end
  BronzeLFG_DB.profile.discord = self.profileDiscord:GetChecked()
  BronzeLFG_DB.profile.note = self.profileNote:GetText()
  flash("Application profile saved.")
end

function BLFG:ValidateCreateListing()
  if self.myListing and self.myListing.id then
    msg("Please close your current listing before creating a new one.", 1, .82, .35)
    return false
  end

  local activity = dd(self.activityDrop)
  if not activity or activity == "" or activity == "Select activity" then
    msg("Choose an activity before creating a listing.", 1, .35, .35)
    return false
  end
  if BLFG_DungeonListForMode(activity) then
    local specificDungeon = self.specificDungeonDrop and dd(self.specificDungeonDrop) or ""
    if not BLFG_ListContainsValue(BLFG_DungeonListForMode(activity), specificDungeon) then
      msg("Choose a dungeon before creating a listing.", 1, .35, .35)
      return false
    end
  end

  local maxMembers = tonumber(self.maxBox and self.maxBox:GetText() or "")
  if not maxMembers or maxMembers < 2 then
    msg("Max Members must be at least 2.", 1, .35, .35)
    return false
  end
  if maxMembers > 40 then
    msg("Max Members cannot be higher than 40.", 1, .35, .35)
    return false
  end

  local minIlvlText = self.minIlvlBox and self.minIlvlBox:GetText() or ""
  if minIlvlText ~= "" then
    local minIlvl = tonumber(minIlvlText)
    if not minIlvl or minIlvl < 0 or minIlvl > 300 then
      msg("Min Item Level must be a number.", 1, .35, .35)
      return false
    end
  end

  local typeName = dd(self.typeDrop)
  local diff = dd(self.diffDrop)
  local keyAllowed = typeName == "Dungeon" and diff == "Mythic+" and BLFG_ActivitySupportsKeyLevel(activity)
  local keyText = self.keyBox and self.keyBox:GetText() or ""
  if keyAllowed and diff == "Mythic+" then
    local keyLevel = tonumber(keyText)
    if keyText == "" or not keyLevel or keyLevel < 1 or keyLevel > 99 then
      msg("Mythic+ listings need a numeric Key Level between 1 and 99.", 1, .35, .35)
      return false
    end
  elseif keyAllowed and keyText ~= "" and not tonumber(keyText) then
    msg("Key Level must be numeric.", 1, .35, .35)
    return false
  end

  if not self.needTank:GetChecked() and not self.needHealer:GetChecked() and not self.needDPS:GetChecked() then
    msg("Select at least one role needed.", 1, .35, .35)
    return false
  end

  return true
end

function BLFG:CreateListing()
  if not self:ValidateCreateListing() then return end
  local c, cf = playerClass()
  local created = now()
  local activityMode = dd(self.activityDrop)
  local finalActivity = activityMode
  if BLFG_DungeonListForMode(activityMode) and self.specificDungeonDrop then
    finalActivity = dd(self.specificDungeonDrop)
  end
  local keyAllowed = dd(self.typeDrop) == "Dungeon" and dd(self.diffDrop) == "Mythic+" and BLFG_ActivitySupportsKeyLevel(activityMode)
  local l = {
    id = playerName() .. "-" .. created,
    leader = playerName(),
    class = c,
    classFile = cf,
    type = dd(self.typeDrop),
    activity = finalActivity,
    difficulty = dd(self.diffDrop),
    key = keyAllowed and (self.keyBox:GetText() or "") or "",
    minItemLevel = self.minIlvlBox:GetText() or "",
    members = memberCount(),
    maxMembers = tonumber(self.maxBox:GetText()) or 5,
    needTank = self.needTank:GetChecked() and "1" or "0",
    needHealer = self.needHealer:GetChecked() and "1" or "0",
    needDPS = self.needDPS:GetChecked() and "1" or "0",
    voice = dd(self.voiceDrop),
    loot = dd(self.lootDrop),
    note = self.noteBox:GetText() or "",
    created = created,
    seen = created,
  }
  self.myListing = l
  self.listings[l.id] = l
  self.selectedListing = l.id
  self:SaveMyListingState()

  BronzeLFG_DB.create.type = l.type
  BronzeLFG_DB.create.activity = activityMode
  BronzeLFG_DB.create.specificDungeon = finalActivity
  BronzeLFG_DB.create.difficulty = l.difficulty
  BronzeLFG_DB.create.key = l.key
  BronzeLFG_DB.create.minItemLevel = l.minItemLevel
  BronzeLFG_DB.create.maxMembers = tostring(l.maxMembers)
  BronzeLFG_DB.create.voice = l.voice
  BronzeLFG_DB.create.loot = l.loot
  BronzeLFG_DB.create.note = l.note

  sendChan(serializeListing(l))
  flash("Listing created and broadcast: " .. l.activity)
  self:ShowBrowse()
end

function BLFG:Broadcast()
  if self.myListing then
    self.myListing.members = memberCount()
    local max = tonumber(self.myListing.maxMembers or 0) or 0
    if max > 0 and self.myListing.members >= max then
      self:CancelMyListing("full")
      return
    end
    self.myListing.seen = now()
    self:SaveMyListingState()
    sendChan(serializeListing(self.myListing))
  end
end

function BLFG:Apply()
  local l = self.listings[self.selectedListing]
  if not l then msg("Select a listing first."); return end
  local pr = BronzeLFG_DB.profile or {}
  local c, cf = playerClass()
  local a = {
    listingId = l.id,
    name = playerName(),
    class = c,
    classFile = cf,
    level = playerLevel(),
    role = pr.role or "DPS",
    itemLevel = pr.itemLevel or "",
    roleType = pr.roleType or "",
    discord = pr.discord and "Yes" or "No",
    note = pr.note or "",
    applied = now(),
  }
  if l.leader == playerName() then
    self.applicants[a.name] = a
    if self.SetApplicantAlert then self:SetApplicantAlert(true) else self.newApplicantAlert = true end
    flash("New applicant: " .. a.name)
    self:RefreshApplicants()
  else
    sendChan(serializeApplicant(l.id, a))
    SendChatMessage("[SignalFire] I applied to your group: " .. l.activity, "WHISPER", nil, l.leader)
    flash("Application sent.")
  end
end

function BLFG:PassFilter(l)
  if self.filter == "Dungeons" and l.type ~= "Dungeon" then return false end
  if self.filter == "Raids" and l.type ~= "Raid" and l.type ~= "Ascended" then return false end
  if self.filter == "World Bosses" and l.type ~= "World Boss" then return false end
  if self.filter == "Custom" and l.type ~= "Custom Event" then return false end
  local s = lower(self.search and self.search:GetText() or "")
  if s ~= "" then
    local hay = lower((l.activity or "") .. " " .. (l.leader or "") .. " " .. (l.note or ""))
    if not string.find(hay, s, 1, true) then return false end
  end
  if l.seen and now() - l.seen > 900 then return false end
  return true
end

function BLFG:GetVisibleListings()
  local out = {}
  for _, l in pairs(self.listings) do
    if self:PassFilter(l) then table.insert(out, l) end
  end
  table.sort(out, function(a,b) return (a.seen or 0) > (b.seen or 0) end)
  return out
end

function BLFG:RefreshBrowse()
  if not self.rows then return end
  local list = self:GetVisibleListings()
  if self.browseCountText then self.browseCountText:SetText("Active Listings: " .. tostring(#list)) end
  if self.emptyBrowseText then
    if #list == 0 then
      self.emptyBrowseText:Show()
      if self.emptyBrowseIcon then self.emptyBrowseIcon:Show() end
    else
      self.emptyBrowseText:Hide()
      if self.emptyBrowseIcon then self.emptyBrowseIcon:Hide() end
    end
  end
  for i, row in ipairs(self.rows) do
    local l = list[i]
    if l then
      row:Show(); row.key = l.id
      if l.id == self.selectedListing then row:SetBackdropColor(.45,.28,.02,.95) else row:SetBackdropColor(0,0,0,.85) end
      local icon = "Interface\\Icons\\INV_Misc_Map07"
      if l.type == "Raid" then icon = "Interface\\Icons\\Achievement_Boss_Ragnaros" end
      if l.type == "World Boss" then icon = "Interface\\Icons\\Achievement_Boss_CThun" end
      if l.type == "Ascended" then icon = "Interface\\Icons\\Spell_Holy_SealOfWrath" end
      row.icon:SetTexture(icon)
      local diff = l.difficulty or ""
      if diff == "Mythic+" and l.key and l.key ~= "" then diff = diff .. " " .. l.key end
      local typeColor = publicTypeColor(l.type or "Dungeon")
      row.title:SetText(typeColor .. (l.activity or "Unknown") .. "|r")
      local meta = (l.type or "Group")
      if diff and diff ~= "" then meta = meta .. " - " .. diff end
      if l.note and l.note ~= "" then meta = meta .. " - " .. l.note end
      row.note:SetText(shortenPublicText(meta, 34))
      row.leader:SetText(l.leader or "")
      row.roles:SetText(rolesNeededShort(l))
      row.ilvl:SetText((l.minItemLevel and l.minItemLevel ~= "") and (l.minItemLevel .. "+") or "--")
      row.members:SetText((l.members or 1) .. " / " .. (l.maxMembers or 5))
    else
      row.key = nil; row:Hide()
    end
  end
  self:RefreshDetail()
  self:RefreshBadge()
end

function BLFG:RefreshDetail()
  local d = self.detail
  local l = self.listings[self.selectedListing]
  if not l then
    d.title:SetText("No group selected")
    d.sub:SetText("")
    d.note:SetText("Select a listing to view details.")
    d.body:SetText("")
    d.apps:SetText("View Applicants")
    return
  end
  local diff = l.difficulty or ""
  if diff == "Mythic+" and l.key and l.key ~= "" then diff = diff .. " " .. l.key end
  d.title:SetText("|cffb84dff" .. l.activity .. "|r")
  d.sub:SetText(diff .. " " .. l.type)
  if l.note and l.note ~= "" then d.note:SetText(l.note) else d.note:SetText("") end
  d.body:SetText(
    "|cffffcc00Leader:|r " .. (l.leader or "") ..
    "\n|cffffcc00Created:|r " .. ageText(l.created) ..
    "\n|cffffcc00Level Req:|r 60" ..
    "\n|cffffcc00Item Level:|r " .. ((l.minItemLevel and l.minItemLevel ~= "") and (l.minItemLevel .. "+") or "Not provided") ..
    "\n|cffffcc00SignalFire Network:|r " .. (l.members or 1) .. " / " .. (l.maxMembers or 5) ..
    "\n|cffffcc00Applicants:|r " .. self:ApplicantCountForListing(l.id) ..
    "\n|cffffcc00Roles Needed:|r " .. rolesNeeded(l) ..
    "\n|cffffcc00Voice Chat:|r " .. (l.voice or "None") ..
    "\n|cffffcc00Loot Method:|r " .. (l.loot or "Group Loot")
  )
  local n = 0
  for _, a in pairs(self.applicants) do if a.listingId == l.id then n = n + 1 end end
  d.apps:SetText("View Applicants (" .. n .. ")")
end

function BLFG:RefreshBadge()
  local n = 0
  if self.myListing then
    for _, a in pairs(self.applicants) do
      if a.listingId == self.myListing.id then n = n + 1 end
    end
  end
  if self.badge then
    if n > 0 then self.badge:Show(); self.badge.text:SetText(tostring(n)) else self.badge:Hide() end
  end
end

function BLFG:RefreshApplicants()
  if not self.appRows then return end
  local apps = {}
  for _, a in pairs(self.applicants) do
    if not self.myListing or a.listingId == self.myListing.id then table.insert(apps, a) end
  end
  table.sort(apps, function(a,b) return (a.applied or 0) < (b.applied or 0) end)
  for i, row in ipairs(self.appRows) do
    local a = apps[i]
    if a then
      row:Show(); row.key = a.name
      if a.name == self.selectedApplicant then row:SetBackdropColor(.45,.28,.02,.95) else row:SetBackdropColor(0,0,0,.85) end
      row.name:SetText(a.name)
      row.icon:SetTexture(classIcon(a.classFile))
      row.class:SetText(a.class or "")
      row.role:SetText(roleText(a.role))
      if row.spec then row.spec:SetText((a.roleType and a.roleType ~= "") and a.roleType or "--") end
      row.level:SetText(a.level or "")
      row.ilvl:SetText((a.itemLevel and a.itemLevel ~= "") and a.itemLevel or "--")
      row.note:SetText(a.note or "")
    else
      row.key = nil; row:Hide()
    end
  end
  self:RefreshApplicantDetail()
  self:RefreshBadge()
end

function BLFG:RefreshApplicantDetail()
  local d = self.appDetail
  local a = self.applicants[self.selectedApplicant]
  if not a then
    d.name:SetText("No Applicants Yet")
    d.sub:SetText("")
    d.info:SetText("Applicants will appear here when players apply to your listing.")
    d.note:SetText("")
    d.portrait:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
    setButtonEnabled(d.accept, false)
    setButtonEnabled(d.whisper, false)
    setButtonEnabled(d.decline, false)
    return
  end
  setButtonEnabled(d.accept, true)
  setButtonEnabled(d.whisper, true)
  setButtonEnabled(d.decline, true)
  d.portrait:SetTexture(classIcon(a.classFile))
  d.name:SetText("|cffb84dff" .. a.name .. "|r")
  d.sub:SetText("Level " .. (a.level or "60") .. " " .. (a.class or ""))
  d.info:SetText(
    "|cffffcc00Role:|r " .. roleText(a.role) ..
    "\n|cffffcc00Item Level:|r " .. ((a.itemLevel and a.itemLevel ~= "") and a.itemLevel or "Not provided") ..
    "\n|cffffcc00Spec:|r " .. ((a.roleType and a.roleType ~= "") and a.roleType or "Not provided") ..
    "\n|cffffcc00Discord Ready:|r " .. (a.discord or "No") ..
    "\n|cffffcc00Applied:|r " .. ageText(a.applied)
  )
  d.note:SetText("|cffffcc00Note:|r\n" .. (a.note or ""))
end

function BLFG:AcceptSelected()
  local a = self.applicants[self.selectedApplicant]
  if not a then msg("Select an applicant first."); return end
  InviteUnit(a.name)
  local activity = self.myListing and self.myListing.activity or "your group"
  sendChan(serializeDecision(a.name, "accepted", activity))
  self.applicants[a.name] = nil
  self.selectedApplicant = nil
  self:RefreshApplicants()
  self:CheckAutoCloseListing()
  flash("Accepted and invited " .. a.name .. ".")
end

function BLFG:DeclineSelected()
  local a = self.applicants[self.selectedApplicant]
  if not a then msg("Select an applicant first."); return end
  local activity = self.myListing and self.myListing.activity or "your group"
  sendChan(serializeDecision(a.name, "declined", activity))
  self.applicants[a.name] = nil
  self.selectedApplicant = nil
  self:RefreshApplicants()
  flash("Declined applicant.")
end

function BLFG:SendPresence()
  sendChan(serializePresence())
end

function BLFG:PruneOnlineUsers()
  self.onlineUsers = self.onlineUsers or {}
  local cutoff = now() - 180
  for name, u in pairs(self.onlineUsers) do
    if not u.seen or u.seen < cutoff then self.onlineUsers[name] = nil end
  end
end

function BLFG:GetOnlineUserCount()
  self:PruneOnlineUsers()
  local c = 1
  for name, u in pairs(self.onlineUsers or {}) do
    if name ~= playerName() then c = c + 1 end
  end
  return c
end

function BLFG:PrintOnlineUsers()
  self:PruneOnlineUsers()
  local rows = {}
  local _, myClass = playerClass()
  local myRole = (BronzeLFG_DB and BronzeLFG_DB.profile and BronzeLFG_DB.profile.role) or ""
  table.insert(rows, {name=playerName(), version=VERSION, level=tostring(playerLevel()), classFile=myClass or "", role=myRole or "", seen=now(), self=true})
  for name, u in pairs(self.onlineUsers or {}) do
    if name ~= playerName() then table.insert(rows, u) end
  end
  table.sort(rows, function(a,b) return tostring(a.name or "") < tostring(b.name or "") end)
  msg("SignalFire Network Online Now: " .. tostring(#rows))
  for _, u in ipairs(rows) do
    local age = ageText(u.seen or now())
    local level = u.level and u.level ~= "" and (" lvl " .. tostring(u.level)) or ""
    local role = u.role and u.role ~= "" and (" - " .. tostring(u.role)) or ""
    local zone = u.zone and u.zone ~= "" and (" - " .. tostring(u.zone)) or ""
    local guild = u.guild and u.guild ~= "" and (" <" .. tostring(u.guild) .. ">") or ""
    local who = tostring(u.name or "Unknown") .. guild .. level .. role .. zone .. " (seen " .. age .. ")"
    msg("  " .. who, .65, .85, 1)
  end
  BLFG:SendPresence()
end

function BLFG:HandlePresence(p)
  local u = parsePresence(p)
  if not u or not u.name or u.name == "" or u.name == playerName() then return end
  self.onlineUsers = self.onlineUsers or {}
  local old = self.onlineUsers[u.name]
  if old then
    if not u.className or u.className == "" or u.className == "Unknown" then u.className = old.className end
    if not u.classFile or u.classFile == "" or u.classFile == "UNKNOWN" then u.classFile = old.classFile end
    if not u.role or u.role == "" then u.role = old.role end
    if not u.spec or u.spec == "" then u.spec = old.spec end
    if not u.zone or u.zone == "" then u.zone = old.zone end
    if not u.guild or u.guild == "" then u.guild = old.guild end
  end
  self.onlineUsers[u.name] = u
  if self.onlinePanel and self.onlinePanel:IsShown() then self:RefreshOnlinePanel() end
  if self.guildPanel and self.guildPanel:IsVisible() then self:RefreshGuildBrowser() end
  if self.publicCountText then self:RefreshPublicGroups() end
end

function BLFG:HandleMessage(text)
  if not text or string.sub(text,1,string.len(PREFIX)) ~= PREFIX then return end
  local p = split(text)
  if p[1] ~= PREFIX then return end
  if p[2] == "PING" then
    self:HandlePresence(p)
  elseif p[2] == "LIST" then
    local l = parseListing(p)
    if l and l.id then self.listings[l.id] = l; self:RefreshBrowse() end
  elseif p[2] == "APP" then
    local a = parseApplicant(p)
    if a and a.name and self.myListing and a.listingId == self.myListing.id then
      self.applicants[a.name] = a
      if self.SetApplicantAlert then self:SetApplicantAlert(true) else self.newApplicantAlert = true end
      flash(a.name .. " applied to your group.")
      self:RefreshApplicants()
      self:RefreshBrowse()
    end
  elseif p[2] == "REMOVE" then
    local id = p[3]
    if id then
      self.listings[id] = nil
      self:RemovePublicMirrorForListing(id)
      if self.selectedListing == id then self.selectedListing = nil end
      self:RefreshBrowse()
    end
  elseif p[2] == "DECISION" then
    local target, result, activity = p[3], p[4], p[5] or "that group"
    if target == playerName() then
      if result == "accepted" then flash("Your application to " .. activity .. " was accepted.")
      else flash("Your application to " .. activity .. " was declined.") end
    end
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("CHAT_MSG_CHANNEL")
ev:RegisterEvent("CHAT_MSG_SAY")
ev:RegisterEvent("CHAT_MSG_YELL")
ev:RegisterEvent("CHANNEL_UI_UPDATE")
ev:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    ensureDB()
    BLFG:CreateUI()
    JoinChannelByName(CHANNEL)
    msg("SignalFire Network loaded.")
    BLFG:SendPresence()
    if BronzeLFG_DB.options and BronzeLFG_DB.options.autoOpen then
      BLFG:Show()
    end
  elseif event == "CHAT_MSG_CHANNEL" then
    local text, author, _, _, _, _, _, num, name = ...
    if name == CHANNEL or tonumber(num) == tonumber(BLFG.channelId) then
      BLFG:HandleMessage(text)
    else
      if not BLFG:SignalFireShouldSkipPublicChatEvent(author, text) then BLFG:AddPublicGroup(author, text, name) end
    end
  elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" then
    local text, author = ...
    if not BLFG:SignalFireShouldSkipPublicChatEvent(author, text) then BLFG:AddPublicGroup(author, text, event == "CHAT_MSG_YELL" and "Yell" or "Say") end
  elseif event == "CHANNEL_UI_UPDATE" then
    getChannel()
  end
end)

local pulse = CreateFrame("Frame")
pulse.elapsed = 0
pulse.presenceElapsed = 55
pulse:SetScript("OnUpdate", function(self, elapsed)
  self.elapsed = self.elapsed + elapsed
  self.presenceElapsed = self.presenceElapsed + elapsed
  if self.presenceElapsed > 60 then
    self.presenceElapsed = 0
    if BronzeLFG_DB and BronzeLFG_DB.options then BLFG:SendPresence() end
  end
  if self.elapsed > 10 then
    self.elapsed = 0
    getChannel()
    if BLFG.myListing then BLFG:CheckAutoCloseListing(); BLFG:Broadcast() end
    if BLFG.SF151_RunSlowMaintenance then BLFG:SF151_RunSlowMaintenance() end
    if BLFG.frame and BLFG.frame:IsShown() then
      if BLFG.browse and BLFG.browse:IsShown() then BLFG:RefreshBrowse() end
      if BLFG.apps and BLFG.apps:IsShown() then BLFG:RefreshApplicants() end
      if BLFG.myPanel and BLFG.myPanel:IsShown() then BLFG:RefreshMyListing() end
      if BLFG.publicPanel and BLFG.publicPanel:IsShown() then BLFG:RefreshPublicGroups() end
      if BLFG.onlinePanel and BLFG.onlinePanel:IsShown() then BLFG:RefreshOnlinePanel() end
      if BLFG.guildPanel and BLFG.guildPanel:IsVisible() then BLFG:RefreshGuildBrowser() end
    end
  end
end)

SLASH_BRONZELFG1 = "/blfg"
SLASH_BRONZELFG2 = "/bronzelfg"
SlashCmdList["BRONZELFG"] = function(input)
  input = lower(input or "")
  input = string.gsub(input, "^%s+", "")
  input = string.gsub(input, "%s+$", "")

  -- 1.4.8: core fallback for module commands, in case /sf is routed to the
  -- older BronzeLFG command owner by Wrath's slash hash.
  if SignalFireSlashFinal and SignalFireSlashFinal.HandleModuleSlash and SignalFireSlashFinal.HandleModuleSlash(input) then return end
  if SignalFireModules and SignalFireModules.HandleSlash and SignalFireModules.HandleSlash(input, nil) then return end
  if input == "modules" or input == "module" or input == "mods" or input == "mod" then
    local profile = "Triumvirate"
    if BLFG.SF143_GetProfileId then profile = BLFG:SF143_GetProfileId() elseif BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then profile = tostring(BronzeLFG_DB.options.serverProfile or profile) end
    local line = nil
    if BLFG.SFModulesStatusLine then line = BLFG:SFModulesStatusLine() else
      BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}; BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}
      local def = profile ~= "Ascension"
      local enabled = BronzeLFG_DB.options.modules.invasions
      if enabled == nil then enabled = def end
      line = "Invasions=" .. (enabled and "on" or "off") .. " (default " .. (def and "on" or "off") .. ")"
    end
    msg("Active modules for " .. tostring(profile) .. ": " .. tostring(line))
    msg("Module commands: /sf invasions on, /sf invasions off, /sf invasions default")
    return
  elseif input == "invasions on" or input == "module invasions on" or input == "modules invasions on" then
    if BLFG.SFModuleSetEnabled then BLFG:SFModuleSetEnabled("invasions", true) else BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}; BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}; BronzeLFG_DB.options.modules.invasions = true end
    msg("Invasions module enabled.")
    return
  elseif input == "invasions off" or input == "module invasions off" or input == "modules invasions off" then
    if BLFG.SFModuleSetEnabled then BLFG:SFModuleSetEnabled("invasions", false) else BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}; BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}; BronzeLFG_DB.options.modules.invasions = false end
    msg("Invasions module disabled.")
    return
  elseif input == "invasions default" or input == "module invasions default" or input == "modules invasions default" then
    if BLFG.SFModuleUseProfileDefault then BLFG:SFModuleUseProfileDefault("invasions") else BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}; BronzeLFG_DB.options.modules = BronzeLFG_DB.options.modules or {}; BronzeLFG_DB.options.modules.invasions = nil end
    msg("Invasions module reset to profile default.")
    return
  end

  if input == "create" then BLFG:Show(); BLFG:ShowCreate()
  elseif input == "profile" then BLFG:ShowProfile()
  elseif input == "options" or input == "settings" then BLFG:ShowOptions()
  elseif input == "public" or input == "groups" then BLFG:ShowPublicGroups()
  elseif input == "guild" or input == "guilds" then BLFG:ShowGuildBrowser()
  elseif input == "who" then BLFG:PrintOnlineUsers()
  elseif input == "online" then BLFG:Show(); BLFG:ShowPublicGroups(); BLFG:ToggleOnlinePanel()
  elseif input == "clearpublic" then BLFG:ClearPublicGroups()
  elseif input == "applicants" then BLFG:Show(); BLFG:ShowApplicants()
  elseif input == "my" or input == "listing" then BLFG:Show(); BLFG:ShowMyListing()
  elseif input == "cancel" then BLFG:CancelMyListing("manual")
  elseif input == "reset" then BronzeLFG_DB = {}; ReloadUI()
  else BLFG:Toggle() end
end

-- ============================================================================
-- BronzeLFG v5.5.0 - Recruitment Post Creator
-- Practical guild recruitment ad builder.
-- Keeps Guild Browser focused on face-value recruitment information.
-- ============================================================================

BLFG.RecruitmentCreator = BLFG.RecruitmentCreator or {}

local function blfgTrim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function blfgJoinSelected(map)
  local out = {}
  for k, v in pairs(map or {}) do
    if v then table.insert(out, k) end
  end
  table.sort(out)
  if #out == 0 then return "" end
  return table.concat(out, ", ")
end

function BLFG:BuildRecruitmentAd()
  local rc = self.RecruitmentCreator or {}
  local guild = blfgTrim((rc.guildEdit and rc.guildEdit:GetText()) or GetGuildInfo("player") or "")
  local discord = blfgTrim((rc.discordEdit and rc.discordEdit:GetText()) or "")
  BronzeLFG_DB.recruitmentCreator = BronzeLFG_DB.recruitmentCreator or {}
  BronzeLFG_DB.recruitmentCreator.discord = discord
  if discord ~= "" then BLFG_SavedRecruitmentDiscord = discord end
  local notes = blfgTrim((rc.notesEdit and rc.notesEdit:GetText()) or "")
  local activities = blfgJoinSelected(rc.activities)
  local roles = blfgJoinSelected(rc.roles)

  if guild == "" then guild = "Guild" end

  local msg = "<" .. guild .. "> Recruiting!"

  if activities ~= "" then
    msg = msg .. " Activities: " .. activities .. "."
  end

  if roles ~= "" then
    msg = msg .. " Looking for: " .. roles .. "."
  end

  if notes ~= "" then
    msg = msg .. " " .. notes
  end

  if discord ~= "" then
    msg = msg .. " Discord: " .. discord
  end

  return msg
end

function BLFG:RefreshRecruitmentPreview()
  if not self.RecruitmentCreator or not self.RecruitmentCreator.preview then return end
  local msg = self:BuildRecruitmentAd()
  self.RecruitmentCreator.preview:SetText(msg)
end

local function makeCreatorCheck(parent, label, x, y, bucket, key)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  cb:SetWidth(22)
  cb:SetHeight(22)
  cb:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
  cb:EnableMouse(true)
  cb:RegisterForClicks("LeftButtonUp")
  cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  cb.text:SetText(label)
  cb:SetScript("OnClick", function(self)
    BLFG.RecruitmentCreator[bucket] = BLFG.RecruitmentCreator[bucket] or {}
    BLFG.RecruitmentCreator[bucket][key] = self:GetChecked() and true or nil
    BLFG:RefreshRecruitmentPreview()
    if BLFG.SetRecruitmentCreatorButtonState then BLFG:SetRecruitmentCreatorButtonState() end
  end)
  if bucket == "activities" then
    BLFG.RecruitmentCreator.activityChecks = BLFG.RecruitmentCreator.activityChecks or {}
    BLFG.RecruitmentCreator.activityChecks[key] = cb
  elseif bucket == "roles" then
    BLFG.RecruitmentCreator.roleChecks = BLFG.RecruitmentCreator.roleChecks or {}
    BLFG.RecruitmentCreator.roleChecks[key] = cb
  end
  return cb
end

local function makeCreatorLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetText("|cFFFFCC00" .. text .. "|r")
  return fs
end

local function makeCreatorEdit(parent, x, y, w, h, multi)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  eb:SetWidth(w)
  eb:SetHeight(h)
  eb:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
  eb:EnableMouse(true)
  eb:SetAutoFocus(false)
  eb:SetFontObject(GameFontHighlightSmall)
  eb:SetTextInsets(6, 6, 3, 3)
  eb:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  eb:SetBackdropColor(0, 0, 0, .55)
  eb:SetBackdropBorderColor(.85, .55, 0, .9)
  if multi then
    eb:SetMultiLine(true)
    eb:SetMaxLetters(280)
  else
    eb:SetMaxLetters(90)
  end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnTextChanged", function()
    BLFG:RefreshRecruitmentPreview()
    if BLFG.SetRecruitmentCreatorButtonState then BLFG:SetRecruitmentCreatorButtonState() end
  end)
  return eb
end

local function blfgCreatorPostToChat(msg)
  local omittedDiscord = false
  local clipped = false

  -- SignalFire 1.3.3b: Broadcast must send a 255-safe public-chat line.
  -- The full generated recruitment ad still lives in the Preview/Guild Browser;
  -- this outgoing chat payload favors the user's pitch so it does not get cut off
  -- by the WoW 3.3.5 chat limit. Clickable SignalFire links remain local
  -- display-filter additions after chat is received.
  local rc = BLFG and BLFG.RecruitmentCreator or nil
  if rc and rc.frame and rc.frame.IsShown and rc.frame:IsShown() then
    local guild = blfgTrim((rc.guildEdit and rc.guildEdit:GetText()) or GetGuildInfo("player") or "")
    local notes = blfgTrim((rc.notesEdit and rc.notesEdit:GetText()) or "")
    local discord = blfgTrim((rc.discordEdit and rc.discordEdit:GetText()) or "")
    local activities = blfgJoinSelected(rc.activities)
    local roles = blfgJoinSelected(rc.roles)

    if guild == "" then guild = "Guild" end

    if notes ~= "" then
      if string.find(string.lower(notes), string.lower(guild), 1, true) then
        msg = notes
      else
        msg = "<" .. guild .. "> " .. notes
      end
    else
      msg = "<" .. guild .. "> Recruiting!"
      if roles ~= "" and string.len(msg .. " Looking for: " .. roles .. ".") <= 255 then
        msg = msg .. " Looking for: " .. roles .. "."
      end
      if activities ~= "" and string.len(msg .. " Activities: " .. activities .. ".") <= 255 then
        msg = msg .. " Activities: " .. activities .. "."
      end
    end

    if discord ~= "" and not string.find(string.lower(msg), string.lower(discord), 1, true) then
      if string.len(msg .. " Discord: " .. discord) <= 255 then
        msg = msg .. " Discord: " .. discord
      else
        omittedDiscord = true
      end
    end
  end

  msg = blfgTrim(msg)
  if msg == "" then return false end

  if string.len(msg) > 255 then
    msg = string.sub(msg, 1, 252) .. "..."
    clipped = true
  end

  local channelName = (BronzeLFG_DB and BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.broadcastChannel) or BLFG_RecruitmentPostChannel or "global"
  local id = GetChannelName and GetChannelName(channelName) or nil
  if (not id or id == 0) and channelName ~= "global" then
    id = GetChannelName and GetChannelName("global") or nil
    channelName = "global"
  end
  if id and id ~= 0 and SendChatMessage then
    SendChatMessage(msg, "CHANNEL", nil, id)
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire:|r Broadcast sent to /" .. tostring(channelName) .. " (" .. tostring(string.len(msg)) .. "/255).")
    if clipped then
      DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00SignalFire:|r Broadcast was shortened to fit the WoW chat limit.")
    end
    if omittedDiscord then
      DEFAULT_CHAT_FRAME:AddMessage("|cFFFFAA00SignalFire:|r Discord/link was kept in the Guild Browser listing but not added to chat because of the 255 character limit.")
    end
    return true
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555SignalFire:|r Could not find the public/global recruitment channel. Join /global and try Broadcast again.")
  return false
end


function BLFG:PublishRecruitmentListing()
  local guild = blfgTrim((self.RecruitmentCreator and self.RecruitmentCreator.guildEdit and self.RecruitmentCreator.guildEdit:GetText()) or GetGuildInfo("player") or UnitName("player") or "My Guild")
  local hasRole = false
  for _, v in pairs((self.RecruitmentCreator and self.RecruitmentCreator.roles) or {}) do
    if v then hasRole = true break end
  end
  if guild == "" then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555SignalFire:|r Enter a guild name before publishing.")
    return
  end
  if not hasRole then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555SignalFire:|r Select at least one recruiting role before publishing.")
    return
  end
  local msg = self:BuildRecruitmentAd()
  local roles = blfgJoinSelected((self.RecruitmentCreator and self.RecruitmentCreator.roles) or {})
  local focus = blfgJoinSelected((self.RecruitmentCreator and self.RecruitmentCreator.activities) or {})
  local discord = blfgTrim((self.RecruitmentCreator and self.RecruitmentCreator.discordEdit and self.RecruitmentCreator.discordEdit:GetText()) or "")
  if discord ~= "" then BLFG_SavedRecruitmentDiscord = discord end
  if roles == "" then roles = "Recruiting" end
  if focus == "" then focus = "Unknown" end

  BLFG_SavedRecruitmentAd = msg
  BronzeLFG_DB.recruitmentCreator = BronzeLFG_DB.recruitmentCreator or {}
  BronzeLFG_DB.recruitmentCreator.ad = msg
  BronzeLFG_DB.recruitmentCreator.discord = discord
  BLFG_MyRecruitmentListing = {
    guild = guild,
    name = guild,
    status = "Live",
    source = "Recruitment Creator",
    recruiting = roles,
    focus = focus,
    focusText = focus,
    lastPost = msg,
    message = msg,
    posts = 1,
    online = 0,
    contact = UnitName("player") or "",
    discord = discord,
    lastSeen = time(),
    favorite = true,
    mine = true,
  }
  self.myPublishedGuildListing = BLFG_MyRecruitmentListing
  BronzeLFG_DB.recruitmentCreator = BronzeLFG_DB.recruitmentCreator or {}
  BronzeLFG_DB.recruitmentCreator.listing = BLFG_MyRecruitmentListing
  self.suppressPublishedGuildListing = nil

  if self.RefreshGuildBrowser then
    local ok, err = pcall(function() self:RefreshGuildBrowser() end)
    if not ok and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cFFFF5555SignalFire:|r Guild Browser refresh failed: " .. tostring(err))
    end
  end

  if self.SetRecruitmentCreatorButtonState then self:SetRecruitmentCreatorButtonState() end
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire:|r Published recruitment listing locally for |cFFFFFFFF" .. guild .. "|r in Guild Browser.")
end


function BLFG:ClearLocalGuildListings()
  self.myPublishedGuildListing = nil
  self.suppressPublishedGuildListing = true
  BLFG_MyRecruitmentListing = nil
  BLFG_SavedRecruitmentAd = nil

  -- Clear only addon-created local listing data. Do not touch live BronzeNet presence.
  local function removeCreatorRows(t)
    if type(t) ~= "table" then return end
    for i = #t, 1, -1 do
      local r = t[i]
      if r and (r.mine or r.source == "Recruitment Creator") then
        table.remove(t, i)
      end
    end
  end

  removeCreatorRows(self.guildBrowserData)
  removeCreatorRows(self.guildDisplayRows)

  if self.RefreshGuildBrowser then pcall(function() self:RefreshGuildBrowser() end) end
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire:|r Cleared locally published recruitment listings.")
end


function BLFG:OpenRecruitmentCreator()
  if self.RecruitmentCreator.frame then
    self:HideContentForRecruitmentCreator()
    self.RecruitmentCreator.frame:Show()
    self:StyleRecruitmentCreatorOption2()
    self:RefreshRecruitmentPreview()
    if self.SetRecruitmentCreatorButtonState then self:SetRecruitmentCreatorButtonState() end
    return
  end

  self:HideContentForRecruitmentCreator()
  local parentFrame = self.frame or UIParent
  local f = CreateFrame("Frame", "BronzeLFGRecruitmentCreator", UIParent)
  self.RecruitmentCreator.frame = f
  f:SetWidth(500)
  f:SetHeight(470)
  f:SetPoint("CENTER", UIParent, "CENTER", 70, 32)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(500)
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  tinsert(UISpecialFrames, "BronzeLFGRecruitmentCreator")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("|cFFFFCC00Recruitment Post Creator|r")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
  close:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
  f:SetScript("OnHide", function()
    if BLFG and BLFG.RestoreContentAfterRecruitmentCreator then
      BLFG:RestoreContentAfterRecruitmentCreator()
    end
  end)

  makeCreatorLabel(f, "Guild Name", 30, -50)
  local guildEdit = makeCreatorEdit(f, 30, -68, 205, 26, false)
  self.RecruitmentCreator.guildEdit = guildEdit
  local currentGuild = GetGuildInfo("player")
  if currentGuild and currentGuild ~= "" then
    guildEdit:SetText(currentGuild)
  else
    guildEdit:SetText("")
  end

  makeCreatorLabel(f, "Discord / Link", 265, -50)
  local discordEdit = makeCreatorEdit(f, 265, -68, 205, 26, false)
  self.RecruitmentCreator.discordEdit = discordEdit
  local savedDiscord = BLFG_SavedRecruitmentDiscord or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.discord) or ""
  if savedDiscord ~= "" then discordEdit:SetText(savedDiscord) end

  makeCreatorLabel(f, "Activities", 30, -104)
  self.RecruitmentCreator.activities = self.RecruitmentCreator.activities or {}
  makeCreatorCheck(f, "Raiding", 30, -126, "activities", "Raiding")
  makeCreatorCheck(f, "Keys", 145, -126, "activities", "Keys")
  makeCreatorCheck(f, "Dungeons", 260, -126, "activities", "Dungeons")
  makeCreatorCheck(f, "PvP", 375, -126, "activities", "PvP")
  makeCreatorCheck(f, "Leveling", 30, -150, "activities", "Leveling")
  makeCreatorCheck(f, "Social", 145, -150, "activities", "Social")
  makeCreatorCheck(f, "Hardcore", 260, -150, "activities", "Hardcore")
  makeCreatorCheck(f, "World Boss", 375, -150, "activities", "World Boss")

  makeCreatorLabel(f, "Recruiting", 30, -184)
  self.RecruitmentCreator.roles = self.RecruitmentCreator.roles or {}
  makeCreatorCheck(f, "Tank", 30, -208, "roles", "Tank")
  makeCreatorCheck(f, "Healer", 145, -208, "roles", "Healer")
  makeCreatorCheck(f, "DPS", 260, -208, "roles", "DPS")
  makeCreatorCheck(f, "All Players", 375, -208, "roles", "All Players")

  makeCreatorLabel(f, "Recruitment Pitch", 30, -244)
  local notesEdit = makeCreatorEdit(f, 30, -264, 440, 60, true)
  self.RecruitmentCreator.notesEdit = notesEdit
  notesEdit:SetText("Friendly guild building a consistent team. New and returning players welcome.")

  makeCreatorLabel(f, "Preview", 30, -334)
  local previewBox = CreateFrame("Frame", nil, f)
  previewBox:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -354)
  previewBox:SetWidth(440)
  previewBox:SetHeight(72)
  previewBox:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  previewBox:SetBackdropColor(0, 0, 0, .55)
  previewBox:SetBackdropBorderColor(.85, .55, 0, .9)
  previewBox:EnableMouse(false)

  local preview = previewBox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  preview:SetPoint("TOPLEFT", previewBox, "TOPLEFT", 8, -8)
  preview:SetPoint("BOTTOMRIGHT", previewBox, "BOTTOMRIGHT", -8, 8)
  preview:SetJustifyH("LEFT")
  preview:SetJustifyV("TOP")
  self.RecruitmentCreator.preview = preview

  local loadExistingBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  loadExistingBtn:SetWidth(105)
  loadExistingBtn:SetHeight(26)
  loadExistingBtn:SetPoint("BOTTOM", f, "BOTTOM", -180, 18)
  loadExistingBtn:SetText("Load Existing")
  loadExistingBtn:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  loadExistingBtn:SetScript("OnClick", function()
    BLFG:LoadExistingRecruitmentListing()
  end)

  local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  copyBtn:SetWidth(105)
  copyBtn:SetHeight(26)
  copyBtn:SetPoint("LEFT", loadExistingBtn, "RIGHT", 8, 0)
  copyBtn:SetText("Broadcast")
  copyBtn:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  copyBtn:SetScript("OnClick", function()
    blfgCreatorPostToChat(BLFG:BuildRecruitmentAd())
  end)

  local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  saveBtn:SetWidth(115)
  saveBtn:SetHeight(26)
  saveBtn:SetPoint("LEFT", copyBtn, "RIGHT", 8, 0)
  saveBtn:SetText("Publish Listing")
  saveBtn:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  self.RecruitmentCreator.publishButton = saveBtn
  saveBtn:SetScript("OnClick", function()
    BLFG:PublishRecruitmentListing()
  end)

  self:RefreshRecruitmentPreview()
  if self.SetRecruitmentCreatorButtonState then self:SetRecruitmentCreatorButtonState() end
end

-- Slash shortcut
do
  local oldSlash = SlashCmdList["BRONZELFG"]
  SlashCmdList["BRONZELFG"] = function(msg)
    msg = string.lower(tostring(msg or ""))
    if msg == "recruit" or msg == "recruitment" or msg == "ad" then
      BLFG:OpenRecruitmentCreator()
      return
    end
    if oldSlash then oldSlash(msg) end
  end
end



-- Add Recruitment Creator button to Guild Browser screen without disturbing existing layout.
function BLFG:EnsureRecruitmentCreatorButton()
  if self.recruitCreatorBtn then return end
  local parent = self.mainFrame or BronzeLFGFrame or UIParent
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  self.recruitCreatorBtn = b
  b:SetWidth(180)
  b:SetHeight(24)
  b:SetText("Create Recruitment Ad")
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", 42, -16)
  b:SetScript("OnClick", function() BLFG:OpenRecruitmentCreator() end)
  b:Hide()
end

local oldShowGuildBrowser = BLFG.ShowGuildBrowser
if oldShowGuildBrowser then
  function BLFG:ShowGuildBrowser(...)
    local r = oldShowGuildBrowser(self, ...)
    self:EnsureRecruitmentCreatorButton()
    if self.recruitCreatorBtn then self.recruitCreatorBtn:Show() end
    return r
  end
end

local oldShowPage = BLFG.ShowPage
if oldShowPage then
  function BLFG:ShowPage(page, ...)
    local r = oldShowPage(self, page, ...)
    self:EnsureRecruitmentCreatorButton()
    if self.recruitCreatorBtn then
      if page == "Guild Browser" or page == "guild" or page == "guildbrowser" then
        self.recruitCreatorBtn:Show()
      else
        self.recruitCreatorBtn:Hide()
      end
    end
    return r
  end
end


-- Global utility buttons near the left sidebar/top area.

-- Stable global top-left utility buttons.
function BLFG:EnsureGlobalUtilityButtons()
  local parent = self.mainFrame or BronzeLFGFrame or UIParent

  -- Hide older dynamically-created buttons if they were anchored badly.
  if self.globalBronzeNetBtn then
    self.globalBronzeNetBtn:ClearAllPoints()
    self.globalBronzeNetBtn:SetParent(parent)
    self.globalBronzeNetBtn:SetFrameStrata("HIGH")
    self.globalBronzeNetBtn:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    self.globalBronzeNetBtn:SetWidth(165)
    self.globalBronzeNetBtn:SetHeight(24)
    self.globalBronzeNetBtn:SetText("Show SignalFire Network")
    self.globalBronzeNetBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -42)
    self.globalBronzeNetBtn:Show()
  else
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    self.globalBronzeNetBtn = b
    b:SetWidth(165)
    b:SetHeight(24)
    b:SetText("Show SignalFire Network")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -42)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel((parent:GetFrameLevel() or 1) + 20)
    b:SetScript("OnClick", function()
      if BLFG.ShowBronzeNetOnline then
        BLFG:ShowBronzeNetOnline()
      elseif BLFG.ToggleBronzeNet then
        BLFG:ToggleBronzeNet()
      elseif BLFG.OpenBronzeNet then
        BLFG:OpenBronzeNet()
      end
    end)
    b:Show()
  end

  if self.recruitCreatorBtn then
    self.recruitCreatorBtn:ClearAllPoints()
    self.recruitCreatorBtn:SetParent(parent)
    self.recruitCreatorBtn:SetFrameStrata("HIGH")
    self.recruitCreatorBtn:SetFrameLevel((parent:GetFrameLevel() or 1) + 21)
    self.recruitCreatorBtn:SetWidth(180)
    self.recruitCreatorBtn:SetHeight(24)
    self.recruitCreatorBtn:SetText("Create Recruitment Ad")
    self.recruitCreatorBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 42, -16)
    self.recruitCreatorBtn:Show()
  else
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    self.recruitCreatorBtn = b
    b:SetWidth(180)
    b:SetHeight(24)
    b:SetText("Create Recruitment Ad")
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 42, -16)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel((parent:GetFrameLevel() or 1) + 21)
    b:SetScript("OnClick", function() BLFG:OpenRecruitmentCreator() end)
    b:Show()
  end
end

local oldEnsureRecruitmentCreatorButton_552 = BLFG.EnsureRecruitmentCreatorButton
function BLFG:EnsureRecruitmentCreatorButton(...)
  if oldEnsureRecruitmentCreatorButton_552 then oldEnsureRecruitmentCreatorButton_552(self, ...) end
  self:EnsureGlobalUtilityButtons()
end

local oldShowGuildBrowser_552 = BLFG.ShowGuildBrowser
if oldShowGuildBrowser_552 then
  function BLFG:ShowGuildBrowser(...)
    local r = oldShowGuildBrowser_552(self, ...)
    self:EnsureGlobalUtilityButtons()
    return r
  end
end


function BLFG:EnsureMyPublishedGuildListingPresent()
  local row = self.myPublishedGuildListing or BLFG_MyRecruitmentListing or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.listing)
  if not row then return end
  self.guilds = self.guilds or {}
  self.bronzeNetGuilds = self.bronzeNetGuilds or {}
  self.guildBrowserData = self.guildBrowserData or {}
  self.guildBrowserRows = self.guildBrowserRows or {}
  self.guilds[row.guild or row.name or "My Guild"] = row
  self.bronzeNetGuilds[row.guild or row.name or "My Guild"] = row

  local function upsertArray(t)
    if type(t) ~= "table" then return end
    local key = row.guild or row.name
    local found = false
    for i, r in ipairs(t) do
      if r and (r.guild == key or r.name == key) then
        t[i] = row
        found = true
        break
      end
    end
    if not found then table.insert(t, 1, row) end
  end
  upsertArray(self.guildBrowserData)
  upsertArray(self.guildBrowserRows)
  upsertArray(self.guildRows)
  upsertArray(self.guildList)
end

local oldBuildGuildBrowser_553 = BLFG.BuildGuildBrowser
if oldBuildGuildBrowser_553 then
  function BLFG:BuildGuildBrowser(...)
    self:EnsureMyPublishedGuildListingPresent()
    return oldBuildGuildBrowser_553(self, ...)
  end
end

oldRefreshGuildList_553 = BLFG.RefreshGuildList
if oldRefreshGuildList_553 then
  function BLFG:RefreshGuildList(...)
    self:EnsureMyPublishedGuildListingPresent()
    return oldRefreshGuildList_553(self, ...)
  end
end



-- v5.5.4 final hooks

-- v5.5.4: disable previous floating utility buttons; they overlapped the left navigation.
function BLFG:EnsureGlobalUtilityButtons()
  if self.globalBronzeNetBtn then self.globalBronzeNetBtn:Hide() end
  if self.recruitCreatorBtn then self.recruitCreatorBtn:Hide() end
end

function BLFG:EnsureGuildRecruitmentCreatorButton()
  local parent = self.guildPanel or self.mainFrame or BronzeLFGFrame or UIParent
  if not self.guildRecruitCreatorBtn then
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    self.guildRecruitCreatorBtn = b
    b:SetWidth(185)
    b:SetHeight(24)
    b:SetText("Create Recruitment Ad")
    b:SetScript("OnClick", function() BLFG:OpenRecruitmentCreator() end)
  end
  self.guildRecruitCreatorBtn:SetParent(parent)
  self.guildRecruitCreatorBtn:ClearAllPoints()
  -- Put it in the Guild Browser control row, left of Refresh if possible.
  if self.guildRefreshButton then
    self.guildRecruitCreatorBtn:SetPoint("RIGHT", self.guildRefreshButton, "LEFT", -12, 0)
  else
    self.guildRecruitCreatorBtn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -210, -84)
  end
  self.guildRecruitCreatorBtn:SetFrameStrata("HIGH")
  self.guildRecruitCreatorBtn:SetFrameLevel((parent:GetFrameLevel() or 1) + 10)
  self.guildRecruitCreatorBtn:Show()
end

function BLFG:GetMyPublishedGuildListing()
  local row = self.myPublishedGuildListing or BLFG_MyRecruitmentListing or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.listing)
  if not row then return nil end
  row.guild = row.guild or row.name or "My Guild"
  row.name = row.name or row.guild
  row.status = row.status or "Live"
  row.source = row.source or "BronzeNet"
  row.recruiting = row.recruiting or "Recruiting"
  row.focus = row.focus or row.focusText or "[Unknown]"
  row.focusText = row.focusText or row.focus
  row.lastPost = row.lastPost or row.message or BLFG_SavedRecruitmentAd or ""
  row.posts = row.posts or 1
  row.online = row.online or 0
  row.contact = row.contact or UnitName("player") or ""
  row.lastSeen = row.lastSeen or time()
  row.mine = true
  return row
end

function BLFG:InjectMyPublishedGuildListing()
  local row = self:GetMyPublishedGuildListing()
  if not row then return end
  local key = row.guild or row.name

  self.guilds = self.guilds or {}
  self.bronzeNetGuilds = self.bronzeNetGuilds or {}
  self.guilds[key] = row
  self.bronzeNetGuilds[key] = row

  local function upsert(t)
    if type(t) ~= "table" then return end
    local found = false
    for i, r in ipairs(t) do
      if r and (r.guild == key or r.name == key) then
        t[i] = row
        found = true
        break
      end
    end
    if not found then table.insert(t, 1, row) end
  end

  upsert(self.guildBrowserRows)
  upsert(self.guildBrowserData)
  upsert(self.guildRows)
  upsert(self.guildList)
  upsert(self.guildDisplayRows)
end


local oldShowGuildBrowser_554 = BLFG.ShowGuildBrowser
if oldShowGuildBrowser_554 then
  function BLFG:ShowGuildBrowser(...)
    local r = oldShowGuildBrowser_554(self, ...)
    if self.InjectMyPublishedGuildListing then self:InjectMyPublishedGuildListing() end
    if self.EnsureGuildRecruitmentCreatorButton then self:EnsureGuildRecruitmentCreatorButton() end
    if self.globalBronzeNetBtn then self.globalBronzeNetBtn:Hide() end
    if self.recruitCreatorBtn then self.recruitCreatorBtn:Hide() end
    return r
  end
end

oldRefreshGuildList_554 = BLFG.RefreshGuildList
if oldRefreshGuildList_554 then
  function BLFG:RefreshGuildList(...)
    if self.InjectMyPublishedGuildListing then self:InjectMyPublishedGuildListing() end
    return oldRefreshGuildList_554(self, ...)
  end
end

local oldBuildGuildBrowser_554 = BLFG.BuildGuildBrowser
if oldBuildGuildBrowser_554 then
  function BLFG:BuildGuildBrowser(...)
    if self.InjectMyPublishedGuildListing then self:InjectMyPublishedGuildListing() end
    return oldBuildGuildBrowser_554(self, ...)
  end
end


-- v5.5.5 safety override: never inject listing data into self.guildRows.
function BLFG:InjectMyPublishedGuildListing()
  local row = self.myPublishedGuildListing or BLFG_MyRecruitmentListing or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.listing)
  if not row then return end
  local key = row.guild or row.name or "My Guild"
  self.guilds = self.guilds or {}
  self.bronzeNetGuilds = self.bronzeNetGuilds or {}
  self.guilds[key] = row
  self.bronzeNetGuilds[key] = row
end


-- v5.5.5 hard-disable old floating utility buttons.
function BLFG:EnsureGlobalUtilityButtons()
  if self.globalBronzeNetBtn then self.globalBronzeNetBtn:Hide() end
  if self.recruitCreatorBtn then self.recruitCreatorBtn:Hide() end
end

function BLFG:EnsureGuildRecruitmentCreatorButton()
  if self.recruitCreatorBtn then self.recruitCreatorBtn:Hide() end
  if self.globalBronzeNetBtn then self.globalBronzeNetBtn:Hide() end
  -- The real creator button is built inside BuildGuildBrowser next to Show BronzeNet.
end


-- v5.5.6 cleanup: remove non-frame entries from guildRows if an older bad build polluted them.
function BLFG:CleanGuildRowFrames()
  if type(self.guildRows) ~= "table" then return end
  for i = #self.guildRows, 1, -1 do
    local r = self.guildRows[i]
    if not (r and r.Show and r.Hide) then
      table.remove(self.guildRows, i)
    end
  end
end

oldRefreshGuildBrowser_556 = BLFG.RefreshGuildBrowser
if oldRefreshGuildBrowser_556 then
  function BLFG:RefreshGuildBrowser(...)
    if self.CleanGuildRowFrames then self:CleanGuildRowFrames() end
    return oldRefreshGuildBrowser_556(self, ...)
  end
end


-- v5.5.7: safe Guild Browser injection.
-- Do not touch internal builder locals or UI row frame tables.
oldGetGuildRows_557 = BLFG.GetGuildRows
if oldGetGuildRows_557 then
  function BLFG:GetGuildRows(...)
    local rows, a, b, c = oldGetGuildRows_557(self, ...)
    rows = rows or {}

    local mine = nil
    if not self.suppressPublishedGuildListing then mine = self.myPublishedGuildListing or BLFG_MyRecruitmentListing end
    if mine and (mine.guild or mine.name) then
      local nm = tostring(mine.guild or mine.name)
      local found = false

      for i, r in ipairs(rows) do
        if r and (r.name == nm or r.guild == nm) then
          r.name = nm
          r.guild = nm
          r.online = tonumber(mine.online or r.online or 0) or 0
          r.status = "Live"
          r.source = "Recruitment Creator"
          r.postKind = tostring(mine.recruiting or "Recruiting")
          r.postFocus = tostring(mine.focus or mine.focusText or "Unknown")
          r.lastPost = tostring(mine.lastPost or mine.message or BLFG_SavedRecruitmentAd or "")
          r.lastPostSeen = tonumber(mine.lastSeen or time()) or time()
          r.lastPostTime = "local"
          r.postContact = tostring(mine.contact or UnitName("player") or "")
          r.posts = tonumber(mine.posts or r.posts or 1) or 1
          r.discord = tostring(mine.discord or BLFG_ExtractDiscord(mine.lastPost or mine.message or ""))
          r.mine = true
          found = true
          break
        end
      end

      if not found then
        table.insert(rows, 1, {
          name = nm,
          guild = nm,
          online = tonumber(mine.online or 0) or 0,
          status = "Live",
          source = "Recruitment Creator",
          recruiting = tostring(mine.recruiting or "Recruiting"),
          focus = tostring(mine.focus or mine.focusText or "Unknown"),
          focusText = tostring(mine.focus or mine.focusText or "Unknown"),
          postKind = tostring(mine.recruiting or "Recruiting"),
          postFocus = tostring(mine.focus or mine.focusText or "Unknown"),
          lastPost = tostring(mine.lastPost or mine.message or BLFG_SavedRecruitmentAd or ""),
          lastPostSeen = tonumber(mine.lastSeen or time()) or time(),
          lastPostTime = "local",
          postContact = tostring(mine.contact or UnitName("player") or ""),
          posts = tonumber(mine.posts or 1) or 1,
          discord = tostring(mine.discord or BLFG_ExtractDiscord(mine.lastPost or mine.message or "")),
          favorite = true,
          sourceRank = 100,
          mine = true,
        })
      end
    end

    return rows, a, b, c
  end
end


-- v5.5.7 override: do not mutate UI row arrays.
function BLFG:InjectMyPublishedGuildListing()
  local row = self.myPublishedGuildListing or BLFG_MyRecruitmentListing or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.listing)
  if not row then return end
  self.guilds = self.guilds or {}
  self.bronzeNetGuilds = self.bronzeNetGuilds or {}
  local key = row.guild or row.name or "My Guild"
  self.guilds[key] = row
  self.bronzeNetGuilds[key] = row
end


-- ============================================================================
-- v5.5.15 Recruitment Creator Option 2
-- Hide page content/detail panels while the creator is open.
-- Keep the left navigation visible and restore the previous UI on close.
-- ============================================================================

function BLFG:HideContentForRecruitmentCreator()
  self._creatorHiddenFrames = self._creatorHiddenFrames or {}

  local candidates = {
    self.guildPanel,
    self.guildDetailPanel,
    self.publicList,
    self.publicDetailPanel,
    self.browse,
    self.create,
    self.profile,
    self.applicants,
    self.myPanel,
    self.optionsPanel,
    self.list,
    self.publicSearch,
    self.search,
    self.guildSearch,
    self.guildFavFilterButton,
    self.guildFocusFilterButton,
    self.guildRefreshButton,
    self.guildRecruitCreatorBtn,
    self.guildClearListingsBtn,
    self.guildOpenOnlineButton,
  }

  for _, f in ipairs(candidates) do
    if f and f.IsShown and f.Hide and f:IsShown() then
      self._creatorHiddenFrames[f] = true
      f:Hide()
    end
  end
end

function BLFG:RestoreContentAfterRecruitmentCreator()
  if self._creatorHiddenFrames then
    for f, wasShown in pairs(self._creatorHiddenFrames) do
      if wasShown and f and f.Show then
        f:Show()
      end
    end
  end
  self._creatorHiddenFrames = nil

  -- Re-show Guild Browser cleanly if we were there; this is safer than leaving stale hidden controls.
  if self.ShowGuildBrowser then
    pcall(function() self:ShowGuildBrowser() end)
  end
end

function BLFG:StyleRecruitmentCreatorOption2()
  local f = self.RecruitmentCreator and self.RecruitmentCreator.frame
  if not f then return end

  local parentFrame = self.frame or UIParent
  f:SetParent(UIParent)
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 70, 32)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(500)
  f:SetToplevel(true)
  f:SetWidth(500)
  f:SetHeight(470)
  if f.SetBackdropColor then
    f:SetBackdropColor(0, 0, 0, 0.88)
    f:SetBackdropBorderColor(0.85, 0.55, 0, 1)
  end
  if f.Raise then f:Raise() end
end


-- v5.5.16 Recruitment Creator polish helpers
function BLFG:SetRecruitmentCreatorStatus(text, r, g, b)
  -- v5.5.17: visual status indicator intentionally disabled.
end

function BLFG:SetRecruitmentCreatorButtonState()
  if not self.RecruitmentCreator then return end

  local guild = ""
  if self.RecruitmentCreator.guildEdit then guild = blfgTrim(self.RecruitmentCreator.guildEdit:GetText()) end

  local hasRole = false
  for _, v in pairs(self.RecruitmentCreator.roles or {}) do
    if v then hasRole = true break end
  end

  local canPublish = (guild ~= "" and hasRole)
  local published = self.myPublishedGuildListing or BLFG_MyRecruitmentListing

  if self.RecruitmentCreator.publishButton then
    self.RecruitmentCreator.publishButton:SetText(published and "Update Listing" or "Publish Listing")
    if canPublish then
      self.RecruitmentCreator.publishButton:Enable()
      self.RecruitmentCreator.publishButton:SetAlpha(1)
    else
      self.RecruitmentCreator.publishButton:Disable()
      self.RecruitmentCreator.publishButton:SetAlpha(.55)
    end
  end
end

function BLFG:ApplyCreatorCheckboxes()
  if not self.RecruitmentCreator then return end
  if self.RecruitmentCreator.activityChecks then
    for key, cb in pairs(self.RecruitmentCreator.activityChecks) do
      cb:SetChecked(self.RecruitmentCreator.activities and self.RecruitmentCreator.activities[key] and true or false)
    end
  end
  if self.RecruitmentCreator.roleChecks then
    for key, cb in pairs(self.RecruitmentCreator.roleChecks) do
      cb:SetChecked(self.RecruitmentCreator.roles and self.RecruitmentCreator.roles[key] and true or false)
    end
  end
end

function BLFG:LoadExistingRecruitmentListing()
  local row = self.myPublishedGuildListing or BLFG_MyRecruitmentListing or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.listing)
  if not row then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire:|r No existing recruitment listing found.")
    return
  end

  self.RecruitmentCreator.activities = {}
  self.RecruitmentCreator.roles = {}

  local function loadList(text, bucket)
    text = tostring(text or "")
    for token in string.gmatch(text, "([^,]+)") do
      token = token:gsub("^%s+", ""):gsub("%s+$", "")
      if token ~= "" then bucket[token] = true end
    end
  end

  loadList(row.focus or row.focusText or "", self.RecruitmentCreator.activities)
  loadList(row.recruiting or row.postKind or "", self.RecruitmentCreator.roles)

  if self.RecruitmentCreator.guildEdit then self.RecruitmentCreator.guildEdit:SetText(tostring(row.guild or row.name or "")) end
  if self.RecruitmentCreator.discordEdit then
    local msg = tostring(row.lastPost or row.message or "")
    local link = BLFG_SavedRecruitmentDiscord or row.discord or (BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.discord) or string.match(msg, "(discord%.gg/%S+)") or string.match(msg, "(https?://%S+)") or ""
    self.RecruitmentCreator.discordEdit:SetText(link)
  end
  if self.RecruitmentCreator.notesEdit then
    local msg = tostring(row.lastPost or row.message or "")
    -- Keep this intentionally simple; user can edit the pitch after load.
    self.RecruitmentCreator.notesEdit:SetText(msg ~= "" and msg or "Friendly guild building a consistent team. New and returning players welcome.")
  end

  self:ApplyCreatorCheckboxes()
  self:RefreshRecruitmentPreview()
  self:SetRecruitmentCreatorButtonState()
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire:|r Loaded existing recruitment listing.")
end



-- ============================================================================
-- v5.5.23 Guild Browser Discord + Focus + Role Polish
-- ============================================================================

function BLFG_CleanLink(link)
  link = tostring(link or "")
  link = link:gsub("^%s+", ""):gsub("%s+$", "")
  link = link:gsub("[%.,;!%)]$", "")
  return link
end

function BLFG_ExtractDiscord(text)
  text = tostring(text or "")

  local link =
    string.match(text, "(https?://discord%.gg/%S+)") or
    string.match(text, "(https?://www%.discord%.gg/%S+)") or
    string.match(text, "(https?://discord%.com/invite/%S+)") or
    string.match(text, "(https?://www%.discord%.com/invite/%S+)") or
    string.match(text, "(discord%.gg/%S+)") or
    string.match(text, "(discord%.com/invite/%S+)") or
    string.match(text, "(discord%.me/%S+)") or
    string.match(text, "(discord%.io/%S+)")

  if link then return BLFG_CleanLink(link) end

  -- Common chat shorthand: "discord: opps", "disc opps", "discord opps"
  local code =
    string.match(text, "[Dd]iscord[:%s]+([%w%-%_]+)") or
    string.match(text, "[Dd]isc[:%s]+([%w%-%_]+)")

  if code and code ~= "" and code ~= "ready" and code ~= "required" then
    return "discord.gg/" .. BLFG_CleanLink(code)
  end

  return ""
end

function BLFG_DisplayDiscord(link)
  link = BLFG_CleanLink(link)
  link = link:gsub("^https?://", "")
  link = link:gsub("^www%.", "")
  return link
end

function BLFG_RoleTagText(text)
  text = string.lower(tostring(text or ""))

  local hasTank = text:find("tank") or text:find("tanks") or text:find("%f[%a]t%f[%A]")
  local hasHeal = text:find("heal") or text:find("healer") or text:find("heals") or text:find("%f[%a]h%f[%A]")
  local hasDPS = text:find("dps") or text:find("damage") or text:find("%f[%a]d%f[%A]")

  if text:find("all players") or text:find("any role") or text:find("all roles") or text:find("recruiting all") then
    hasTank, hasHeal, hasDPS = true, true, true
  end

  local out = {}
  if hasTank then table.insert(out, "|cFF33AAFF[T]|r") end
  if hasHeal then table.insert(out, "|cFF55FF55[H]|r") end
  if hasDPS then table.insert(out, "|cFFFF5555[D]|r") end

  if #out == 0 then return "|cFFAAAAAAUnknown|r" end
  return table.concat(out, " ")
end

function BLFG_ParseFocusTags(text)
  text = tostring(text or "")
  local low = string.lower(text)
  local tags = {}

  local function add(tag)
    for _, t in ipairs(tags) do if t == tag then return end end
    table.insert(tags, tag)
  end

  if low:find("mythic%+") or low:find("m%+") or low:find("keystone") or low:find("%f[%a]keys?%f[%A]") then add("Keys") end
  if low:find("raid") or low:find("bwl") or low:find("blackwing") or low:find("mc") or low:find("molten core") or low:find("zg") or low:find("zul.?gurub") or low:find("aq20") or low:find("aq40") or low:find("naxx") or low:find("kara") or low:find("ony") then add("Raiding") end
  if low:find("world boss") or low:find("world bosses") then add("World Boss") end
  if low:find("pvp") or low:find("arena") or low:find("battleground") or low:find("bg") then add("PvP") end
  if low:find("level") or low:find("leveling") or low:find("levelling") then add("Leveling") end
  if low:find("social") or low:find("community") or low:find("casual") or low:find("chill") or low:find("friendly") then add("Social") end
  if low:find("hardcore") then add("Hardcore") end
  if low:find("dungeon") or low:find("rdf") or low:find("lfm") then add("Dungeons") end

  if #tags == 0 then return "" end

  local colors = {
    ["Keys"] = "|cFF80B0FF[Keys]|r",
    ["Mythic+"] = "|cFF80B0FF[Keys]|r",
    ["Raiding"] = "|cFFFF5555[Raiding]|r",
    ["World Boss"] = "|cFFFFCC00[World Boss]|r",
    ["PvP"] = "|cFFFF7777[PvP]|r",
    ["Leveling"] = "|cFF55FF55[Leveling]|r",
    ["Social"] = "|cFF55CCFF[Social]|r",
    ["Hardcore"] = "|cFFFFAA55[Hardcore]|r",
    ["Dungeons"] = "|cFFAAAAFF[Dungeons]|r",
  }

  local out = {}
  for _, t in ipairs(tags) do table.insert(out, colors[t] or ("[" .. t .. "]")) end
  return table.concat(out, " ")
end

function BLFG:FormatRecruitingTags(value)
  return BLFG_RoleTagText(value)
end

function BLFG:FormatFocusTags(value, fallbackText)
  local parsed = BLFG_ParseFocusTags(value or "")
  if parsed ~= "" then return parsed end
  parsed = BLFG_ParseFocusTags(fallbackText or "")
  if parsed ~= "" then return parsed end
  local raw = tostring(value or fallbackText or "")
  if raw == "" then return "|cFFAAAAAA[Unknown]|r" end
  return raw
end

function BLFG:GetGuildDiscord(g)
  if not g then return "" end
  return tostring(g.discord or g.discordLink or BLFG_ExtractDiscord(g.lastPost or g.message or g.rawMessage or g.post or ""))
end

function BLFG:GetGuildDiscordDisplay(g)
  return BLFG_DisplayDiscord(self:GetGuildDiscord(g))
end

function BLFG:ApplyGuildBrowserPolishToRow(row, g)
  if not row or not g then return end

  local recruit = tostring(g.recruiting or g.postKind or "")
  if (recruit == "" or string.lower(recruit) == "recruiting" or string.lower(recruit) == "unknown") and g.lastPost then recruit = tostring(g.lastPost) end

  if row.recruitingText and row.recruitingText.SetText then
    row.recruitingText:SetText(BLFG_RoleTagText(recruit))
  elseif row.recruiting and row.recruiting.SetText then
    row.recruiting:SetText(BLFG_RoleTagText(recruit))
  end

  local focus = tostring(g.focusRaw or g.focus or g.focusText or g.postFocus or "")
  local parsedFocus = self:FormatFocusTags(focus, g.lastPost or g.message or "")
  if row.focusText and row.focusText.SetText then
    row.focusText:SetText(parsedFocus)
  elseif row.focus and row.focus.SetText then
    row.focus:SetText(parsedFocus)
  end
end

oldRefreshGuildBrowser_5522 = BLFG.RefreshGuildBrowser
if oldRefreshGuildBrowser_5522 then
  function BLFG:RefreshGuildBrowser(...)
    local r = oldRefreshGuildBrowser_5522(self, ...)
    if self.guildRows then
      for _, row in ipairs(self.guildRows) do
        if row and row.guildData then
          self:ApplyGuildBrowserPolishToRow(row, row.guildData)
        end
      end
    end
    return r
  end
end


-- v5.5.23 detail panel Discord line: fixed spacing, no overlap.
function BLFG:EnsureGuildDiscordDetailLine()
  if not self.guildDetailPanel then return end
  if self.guildDiscordLine then return end
  local fs = self.guildDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  self.guildDiscordLine = fs
  fs:SetPoint("TOPLEFT", self.guildDetailPanel, "TOPLEFT", 18, -142)
  fs:SetWidth(360)
  fs:SetJustifyH("LEFT")
end

oldRefreshGuildDetailPanel_5523 = BLFG.RefreshGuildDetailPanel
if oldRefreshGuildDetailPanel_5523 then
  function BLFG:RefreshGuildDetailPanel(g, ...)
    local r = oldRefreshGuildDetailPanel_5523(self, g, ...)
    self:EnsureGuildDiscordDetailLine()

    if self.guildDiscordLine then
      local d = self:GetGuildDiscordDisplay(g)
      if d ~= "" then
        self.guildDiscordLine:SetText("|TInterface\\\\FriendsFrame\\\\UI-Toast-ChatInviteIcon:14:14:0:0|t |cFFFFCC00Discord:|r |cFF99CCFF" .. d .. "|r")
        self.guildDiscordLine:Show()
      else
        self.guildDiscordLine:SetText("")
        self.guildDiscordLine:Hide()
      end
    end

    -- If the main detail body has the old inline Discord line from 5.5.22, leave this clean separate line as the visible version.
    return r
  end
end


-- v5.5.23 enhance all Guild Browser row data after normal build.
oldGetGuildRows_5523 = BLFG.GetGuildRows
if oldGetGuildRows_5523 then
  function BLFG:GetGuildRows(...)
    local rows, a, b, c = oldGetGuildRows_5523(self, ...)
    rows = rows or {}
    for _, g in ipairs(rows) do
      if g then
        local msg = tostring(g.lastPost or g.message or g.rawMessage or "")
        if not g.discord or g.discord == "" then
          g.discord = BLFG_ExtractDiscord(msg)
        end
        local rawFocus = BLFG:GetRawFocusTags(tostring(g.focus or g.focusText or g.postFocus or ""), msg)
        if rawFocus ~= "" then
          g.focusRaw = rawFocus
        end
      end
    end
    return rows, a, b, c
  end
end


oldRefreshGuildBrowser_5523 = BLFG.RefreshGuildBrowser
if oldRefreshGuildBrowser_5523 then
  function BLFG:RefreshGuildBrowser(...)
    local r = oldRefreshGuildBrowser_5523(self, ...)
    if self.guildRows then
      for _, row in ipairs(self.guildRows) do
        if row and row.guildData then
          self:ApplyGuildBrowserPolishToRow(row, row.guildData)
        end
      end
    end
    return r
  end
end


-- ============================================================================
-- v5.5.24 Guild Browser display fixes
-- Store raw focus data; colorize only when displaying.
-- ============================================================================

function BLFG_StripWowColors(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("%[c%x%x%x%x%x%x%x%x", "[")
  s = s:gsub("%[r%]", "")
  return s
end

function BLFG_FocusRawTags(text)
  text = BLFG_StripWowColors(tostring(text or ""))
  local low = string.lower(text)
  local tags = {}

  local function add(tag)
    for _, t in ipairs(tags) do if t == tag then return end end
    table.insert(tags, tag)
  end

  if low:find("mythic%+") or low:find("m%+") or low:find("keystone") or low:find("%f[%a]keys?%f[%A]") then add("Keys") end
  if low:find("raid") or low:find("bwl") or low:find("blackwing") or low:find("mc") or low:find("molten core") or low:find("zg") or low:find("zul.?gurub") or low:find("aq20") or low:find("aq40") or low:find("naxx") or low:find("kara") or low:find("ony") then add("Raiding") end
  if low:find("world boss") or low:find("world bosses") then add("World Boss") end
  if low:find("pvp") or low:find("arena") or low:find("battleground") or low:find("bg") then add("PvP") end
  if low:find("level") or low:find("leveling") or low:find("levelling") then add("Leveling") end
  if low:find("social") or low:find("community") or low:find("casual") or low:find("chill") or low:find("friendly") then add("Social") end
  if low:find("hardcore") then add("Hardcore") end
  if low:find("dungeon") or low:find("rdf") or low:find("lfm") then add("Dungeons") end

  if #tags == 0 then return "" end
  return table.concat(tags, ",")
end

function BLFG_ColorFocusRaw(raw)
  raw = BLFG_StripWowColors(tostring(raw or ""))
  if raw == "" then return "|cFFAAAAAA[Unknown]|r" end

  local colors = {
    ["Keys"] = "|cFF80B0FF[Keys]|r",
    ["Mythic+"] = "|cFF80B0FF[Keys]|r",
    ["Raiding"] = "|cFFFF5555[Raiding]|r",
    ["World Boss"] = "|cFFFFCC00[World Boss]|r",
    ["PvP"] = "|cFFFF7777[PvP]|r",
    ["Leveling"] = "|cFF55FF55[Leveling]|r",
    ["Social"] = "|cFF55CCFF[Social]|r",
    ["Hardcore"] = "|cFFFFAA55[Hardcore]|r",
    ["Dungeons"] = "|cFFAAAAFF[Dungeons]|r",
  }

  local out = {}
  for token in string.gmatch(raw, "([^,%s%[%]]+)") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    if token ~= "" then
      table.insert(out, colors[token] or ("|cFFFFFFFF[" .. token .. "]|r"))
    end
  end

  -- Also handle multi-word raw tags if stored comma-separated.
  if #out == 0 then
    for token in string.gmatch(raw, "([^,]+)") do
      token = token:gsub("^%s+", ""):gsub("%s+$", "")
      if token ~= "" then table.insert(out, colors[token] or ("|cFFFFFFFF[" .. token .. "]|r")) end
    end
  end

  if #out == 0 then return "|cFFAAAAAA[Unknown]|r" end
  return table.concat(out, " ")
end

function BLFG:FormatFocusTags(value, fallbackText)
  local raw = BLFG_FocusRawTags(value or "")
  if raw == "" then raw = BLFG_FocusRawTags(fallbackText or "") end
  if raw == "" then
    local stripped = BLFG_StripWowColors(value or fallbackText or "")
    raw = BLFG_FocusRawTags(stripped)
  end
  if raw == "" then return "|cFFAAAAAA[Unknown]|r" end
  return BLFG_ColorFocusRaw(raw)
end

function BLFG:GetRawFocusTags(value, fallbackText)
  local raw = BLFG_FocusRawTags(value or "")
  if raw == "" then raw = BLFG_FocusRawTags(fallbackText or "") end
  return raw
end

function BLFG:ApplyGuildDetailDisplayFix(g)
  self:CleanGuildDetailSupplementalLines()
  self:ShowGuildDiscordOnly(g)
end


oldRefreshGuildDetailPanel_5524 = BLFG.RefreshGuildDetailPanel
if oldRefreshGuildDetailPanel_5524 then
  function BLFG:RefreshGuildDetailPanel(g, ...)
    local r = oldRefreshGuildDetailPanel_5524(self, g, ...)
    if self.ApplyGuildDetailDisplayFix then self:ApplyGuildDetailDisplayFix(g) end
    return r
  end
end


function BLFG:ApplyGuildTooltipDisplayFix(row, g)
  if not row or not g then return end
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(g.name or g.guild or "Guild", 1, .82, 0)
    local sfOnline = tonumber(g.signalFireOnline or g.online or 0) or 0
    local whoOnline = tonumber(g.whoOnline or 0) or 0
    if whoOnline > 0 then
      GameTooltip:AddLine("SignalFire Network: " .. tostring(sfOnline), .8, .8, .8)
      GameTooltip:AddLine("/who Seen: " .. tostring(whoOnline), .8, .8, .8)
    else
      GameTooltip:AddLine("SignalFire Network: " .. tostring(sfOnline), .8, .8, .8)
    end
    GameTooltip:AddLine("Source: " .. tostring(g.source or "Unknown"), .8, .8, .8)
    GameTooltip:AddLine("Status: " .. tostring(g.status or "Unknown"), .8, .8, .8)

    local recruit = tostring(g.recruiting or g.postKind or "")
    if (recruit == "" or string.lower(recruit) == "recruiting" or string.lower(recruit) == "unknown") and g.lastPost then
      recruit = tostring(g.lastPost)
    end
    GameTooltip:AddLine("Recruiting: " .. ((BLFG.FormatRecruitingTags and BLFG.FormatRecruitingTags(BLFG, recruit)) or recruit), 1, 1, 1)

    local focus = (BLFG.FormatFocusTagsCompact and BLFG.FormatFocusTagsCompact(BLFG, g.focusRaw or g.focus or g.focusText or g.postFocus or "", g.lastPost or g.message or "", 3)) or tostring(g.focus or "")
    GameTooltip:AddLine("Focus: " .. focus, 1, 1, 1)

    if g.lastPostSeen then
      local age = math.max(0, time() - tonumber(g.lastPostSeen or time()))
      GameTooltip:AddLine("Last Guild Post: " .. tostring(age) .. " sec ago", .8, .8, .8)
    end

    local d = (BLFG.GetGuildDiscordDisplay and BLFG.GetGuildDiscordDisplay(BLFG, g)) or ""
    if d ~= "" then GameTooltip:AddLine("Discord: " .. d, .6, .8, 1) end

    if g.lastPost and g.lastPost ~= "" then
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(tostring(g.lastPost), 1, 1, 1, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right Click for Options", .2, 1, .2)
    GameTooltip:AddLine("Shift-Click to whisper contact", .8, .8, .8)
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

oldRefreshGuildBrowser_5524 = BLFG.RefreshGuildBrowser
if oldRefreshGuildBrowser_5524 then
  function BLFG:RefreshGuildBrowser(...)
    local r = oldRefreshGuildBrowser_5524(self, ...)
    if self.guildRows then
      for _, row in ipairs(self.guildRows) do
        if row and row.guildData then
          self:ApplyGuildBrowserPolishToRow(row, row.guildData)
          self:ApplyGuildTooltipDisplayFix(row, row.guildData)
        end
      end
    end
    return r
  end
end


-- ============================================================================
-- v5.5.27 Guild Browser display cleanup
-- Fixes over-stacked Focus tags, duplicate right-panel lines, and Discord overlap.
-- ============================================================================

function BLFG_StripDisplayColors_5527(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("%[c%x%x%x%x%x%x%x%x", "[")
  s = s:gsub("%[r%]", "")
  return s
end

function BLFG_FocusTokens_5527(raw)
  raw = BLFG_StripDisplayColors_5527(raw)
  raw = raw:gsub("%[", ""):gsub("%]", "")
  raw = raw:gsub("|", " ")
  local out = {}
  local seen = {}

  local function add(tag)
    if tag and tag ~= "" and not seen[tag] then
      seen[tag] = true
      table.insert(out, tag)
    end
  end

  for token in string.gmatch(raw, "([^,%s]+)") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    if token == "Boss" then
      -- handled by phrase pass below
    elseif token == "Blitz" then
      -- handled by phrase pass below
    elseif token ~= "" then
      add(token)
    end
  end

  local low = string.lower(raw)
  if low:find("world boss") or low:find("world bosses") then add("World Boss") end

  return out
end

function BLFG_ColorFocusLimited_5527(raw, limit)
  limit = limit or 2
  local colors = {
    ["Keys"] = "|cFF80B0FF[Keys]|r",
    ["Mythic+"] = "|cFF80B0FF[Keys]|r",
    ["Raiding"] = "|cFFFF5555[Raiding]|r",
    ["World Boss"] = "|cFFFFCC00[World Boss]|r",
    ["PvP"] = "|cFFFF7777[PvP]|r",
    ["Leveling"] = "|cFF55FF55[Leveling]|r",
    ["Social"] = "|cFF55CCFF[Social]|r",
    ["Hardcore"] = "|cFFFFAA55[Hardcore]|r",
    ["Dungeons"] = "|cFFAAAAFF[Dungeons]|r",
  }

  local tokens = BLFG_FocusTokens_5527(raw)
  local out = {}

  for i, tag in ipairs(tokens) do
    if i > limit then break end
    table.insert(out, colors[tag] or ("|cFFFFFFFF[" .. tag .. "]|r"))
  end

  if #tokens > limit then
    table.insert(out, "|cFFAAAAAA[+" .. tostring(#tokens - limit) .. "]|r")
  end

  if #out == 0 then return "|cFFAAAAAA[Unknown]|r" end
  return table.concat(out, " ")
end

function BLFG:FormatFocusTagsCompact(value, fallbackText, limit)
  local raw = ""
  if self.GetRawFocusTags then
    raw = self:GetRawFocusTags(value or "", fallbackText or "")
  end
  if raw == "" then raw = tostring(value or fallbackText or "") end
  return BLFG_ColorFocusLimited_5527(raw, limit or 2)
end

function BLFG:ApplyGuildBrowserPolishToRow(row, g)
  if not row or not g then return end

  local recruit = tostring(g.recruiting or g.postKind or "")
  if (recruit == "" or string.lower(recruit) == "recruiting" or string.lower(recruit) == "unknown") and g.lastPost then
    recruit = tostring(g.lastPost)
  end

  local roleText = self.FormatRecruitingTags and self:FormatRecruitingTags(recruit) or recruit
  if row.recruitingText and row.recruitingText.SetText then
    row.recruitingText:SetText(roleText)
  elseif row.recruiting and row.recruiting.SetText then
    row.recruiting:SetText(roleText)
  end

  local focusText = self:FormatFocusTagsCompact(g.focusRaw or g.focus or g.focusText or g.postFocus or "", g.lastPost or g.message or "", 2)
  if row.focusText and row.focusText.SetText then
    row.focusText:SetText(focusText)
  elseif row.focus and row.focus.SetText then
    row.focus:SetText(focusText)
  end
end

function BLFG:CleanGuildDetailSupplementalLines()
  -- Previous builds added extra overlay lines that duplicated existing right-panel text.
  -- Hide them so the original detail layout stays clean.
  if self.guildRecruitingTagLine then self.guildRecruitingTagLine:SetText(""); self.guildRecruitingTagLine:Hide() end
  if self.guildFocusTagLine then self.guildFocusTagLine:SetText(""); self.guildFocusTagLine:Hide() end
end

function BLFG:ShowGuildDiscordOnly(g)
  if not self.guildDetailPanel then return end

  if not self.guildDiscordLine then
    local fs = self.guildDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.guildDiscordLine = fs
    fs:SetWidth(360)
    fs:SetJustifyH("LEFT")
  end

  -- Put Discord in the top-detail area under Contact/Last Post without colliding with Focus.
  self.guildDiscordLine:ClearAllPoints()
  self.guildDiscordLine:SetPoint("TOPLEFT", self.guildDetailPanel, "TOPLEFT", 18, -142)

  local d = self.GetGuildDiscordDisplay and self:GetGuildDiscordDisplay(g) or ""
  if d ~= "" then
    self.guildDiscordLine:SetText("|TInterface\\FriendsFrame\\UI-Toast-ChatInviteIcon:14:14:0:0|t |cFFFFCC00Discord:|r |cFF99CCFF" .. d .. "|r")
    self.guildDiscordLine:Show()
  else
    self.guildDiscordLine:SetText("")
    self.guildDiscordLine:Hide()
  end
end


oldRefreshGuildDetailPanel_5527 = BLFG.RefreshGuildDetailPanel
if oldRefreshGuildDetailPanel_5527 then
  function BLFG:RefreshGuildDetailPanel(g, ...)
    local r = oldRefreshGuildDetailPanel_5527(self, g, ...)
    self:CleanGuildDetailSupplementalLines()
    self:ShowGuildDiscordOnly(g)
    return r
  end
end


oldRefreshGuildBrowser_5527 = BLFG.RefreshGuildBrowser
if oldRefreshGuildBrowser_5527 then
  function BLFG:RefreshGuildBrowser(...)
    local r = oldRefreshGuildBrowser_5527(self, ...)
    if self.guildRows then
      for _, row in ipairs(self.guildRows) do
        if row and row.guildData then
          self:ApplyGuildBrowserPolishToRow(row, row.guildData)
          if self.ApplyGuildTooltipDisplayFix then self:ApplyGuildTooltipDisplayFix(row, row.guildData) end
        end
      end
    end
    return r
  end
end


-- ============================================================================
-- v5.6.0 Public Group Chat Links ALPHA
-- Chat -> clickable BronzeLFG public group title -> opens Public Groups.
-- ============================================================================

BLFG_OriginalSetItemRef_560 = SetItemRef

function BLFG_PublicLinkSafeText_560(s)
  s = tostring(s or "")
  s = s:gsub("|", "")
  s = s:gsub("%[", "")
  s = s:gsub("%]", "")
  if string.len(s) > 72 then s = string.sub(s, 1, 69) .. "..." end
  return s
end

function BLFG_PublicRoleNeed_560(g)
  local roles = string.lower(tostring((g and g.roles) or ""))
  local out = {}

  local tank = (string.find(roles, "tank", 1, true) ~= nil)
  local heal = (string.find(roles, "heal", 1, true) ~= nil)
  local dps = (string.find(roles, "dps", 1, true) ~= nil or string.find(roles, "damage", 1, true) ~= nil)

  if tank then table.insert(out, "T") end
  if heal then table.insert(out, "H") end
  if dps then table.insert(out, "D") end

  if #out == 0 then return "" end
  return table.concat(out, "/")
end

function BLFG:PublicLinkTitle(g)
  if not g then return "SignalFire Listing" end
  local title = tostring(g.activity or "")
  if title == "" or title == "Unknown" then
    title = tostring(g.type or "Group")
  end

  local need = BLFG_PublicRoleNeed_560(g)
  if need ~= "" then
    title = title .. " - Need " .. need
  end

  return BLFG_PublicLinkSafeText_560(title)
end

function BLFG:PublicChatLink(g)
  if not g or not g.id then return nil end
  local title = self:PublicLinkTitle(g)
  return "|cffd4a017|Hbronzelfgpub:" .. tostring(g.id) .. "|h[" .. title .. "]|h|r"
end

function BLFG:FindPublicGroupByIdOrTitle(id, title)
  if id and self.publicGroups and self.publicGroups[id] then return self.publicGroups[id], id end
  title = tostring(title or "")
  local best, bestId, bestSeen = nil, nil, 0
  for k, g in pairs(self.publicGroups or {}) do
    if g then
      if tostring(g.id or "") == tostring(id or "") then return g, k end
      local t = self:PublicLinkTitle(g)
      if title ~= "" and t == title and (g.seen or 0) >= bestSeen then
        best, bestId, bestSeen = g, k, g.seen or 0
      end
    end
  end
  return best, bestId
end

function BLFG:OpenPublicGroupLink(id, title)
  self:CreateUI()
  local g, key = self:FindPublicGroupByIdOrTitle(id, title)
  self:ShowPublicGroups()

  if key then
    self.selectedPublic = key

    -- Change filter/search enough so the clicked listing is visible.
    if g and g.type and g.type ~= "" then
      self.publicFilter = g.type
    else
      self.publicFilter = "All"
    end
    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end

    local rows = self:GetSortedPublicGroups()
    local per = self.publicRowsPerPage or 10
    for idx, rg in ipairs(rows) do
      if rg and rg.id == key then
        self.publicPage = math.max(1, math.ceil(idx / per))
        break
      end
    end

    self:RefreshPublicGroups()
    flash("Opened SignalFire listing: " .. self:PublicLinkTitle(g))
  else
    self.publicFilter = "All"
    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end
    self:RefreshPublicGroups()
    flash("That SignalFire chat listing expired or was cleared.")
  end
end

function BLFG:AnnouncePublicChatLink(g, updated)
  if not g or not g.id then return end
  self._lastPublicChatLink = self._lastPublicChatLink or {}
  local stamp = now and now() or time()
  local key = tostring(g.id or "") .. ":" .. tostring(g.seen or g.created or 0)
  if self._lastPublicChatLink[key] and stamp - self._lastPublicChatLink[key] < 10 then return end
  self._lastPublicChatLink[key] = stamp

  local link = self:PublicChatLink(g)
  if not link then return end

  local source = tostring(g.player or "Unknown")
  local line = "|cffd4a017SignalFire:|r " .. link .. " |cffaaaaaaLeader:|r |cffffffff" .. source .. "|r"
  if updated then
    line = line .. " |cff888888(updated)|r"
  end
  DEFAULT_CHAT_FRAME:AddMessage(line)
  DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55Click the title to view it in Public Groups.|r")
end

BLFG_AddPublicGroup_Original_560 = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local before = {}
  for k, g in pairs(self.publicGroups or {}) do
    before[k] = g and (g.seen or g.created or 0) or 0
  end

  local r = BLFG_AddPublicGroup_Original_560(self, author, text, channelName)

  local name = tostring(author or ""):gsub("%-.*", "")
  local newest, newestKey, newestSeen, updated = nil, nil, 0, false
  for k, g in pairs(self.publicGroups or {}) do
    if g and g.player == name then
      local seen = g.seen or g.created or 0
      if seen >= newestSeen then
        newest, newestKey, newestSeen = g, k, seen
      end
      if before[k] and before[k] ~= seen then updated = true end
    end
  end

  if newest and newestKey and newestSeen > 0 then
    self:AnnouncePublicChatLink(newest, updated)
  end

  return r
end

function SetItemRef(link, text, button, chatFrame)
  if type(link) == "string" and string.sub(link, 1, 13) == "bronzelfgpub:" then
    local id = string.sub(link, 14)
    local title = ""
    if type(text) == "string" then
      title = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("^%[", ""):gsub("%]$", "")
    end
    if BLFG and BLFG.OpenPublicGroupLink then
      BLFG:OpenPublicGroupLink(id, title)
    end
    return
  end

  if BLFG_OriginalSetItemRef_560 then
    return BLFG_OriginalSetItemRef_560(link, text, button, chatFrame)
  end
end

-- Slash testing helper:
-- /blfg linktest creates a fake clickable Public Groups chat link without needing live chat.
BLFG_OldSlash_560 = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = lower(input or "")
  if input == "linktest" or input == "chatlinktest" then
    BLFG.publicGroups = BLFG.publicGroups or {}
    local id = "test-" .. tostring(now and now() or time())
    BLFG.publicGroups[id] = {
      id = id,
      player = playerName and playerName() or UnitName("player") or "You",
      message = "LFM ICC25 Heroic Need 2 Healers 3 DPS Link Ach + GS",
      channel = "Test",
      type = "Raid",
      activity = "ICC25 Heroic",
      roles = "|cff55ff55Healer|r  |cffff5555DPS|r",
      intent = "Recruiter",
      tags = "Raid",
      ilevel = "6000",
      score = 100,
      created = now and now() or time(),
      seen = now and now() or time(),
    }
    BLFG:AnnouncePublicChatLink(BLFG.publicGroups[id], false)
    return
  end

  if BLFG_OldSlash_560 then return BLFG_OldSlash_560(input) end
end


-- ============================================================================
-- v5.6.1 Inline Public Group Chat Links
-- Replaces separate BronzeLFG spam messages with an inline clickable link
-- appended to the actual public chat message.
-- ============================================================================

function BLFG:AnnouncePublicChatLink(g, updated)
  -- Disabled in v5.6.1.
  -- Chat links are now injected inline with ChatFrame_AddMessageEventFilter.
  return
end

function BLFG:FindNewestPublicByAuthor(author)
  local name = tostring(author or ""):gsub("%-.*", "")
  local newest, newestKey, newestSeen = nil, nil, 0
  for k, g in pairs(self.publicGroups or {}) do
    if g and g.player == name then
      local seen = tonumber(g.seen or g.created or 0) or 0
      if seen >= newestSeen then
        newest, newestKey, newestSeen = g, k, seen
      end
    end
  end
  return newest, newestKey
end

function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  if not msgText or not author then return nil end
  local raw = tostring(msgText or "")
  if raw == "" then return nil end

  local stamp = now and now() or (time and time() or 0)
  local cleanAuthor = tostring(author or ""):gsub("%-.*", "")
  local cacheKey = cleanAuthor .. "\031" .. raw
  self._inlinePublicChatCache = self._inlinePublicChatCache or {}
  local cached = self._inlinePublicChatCache[cacheKey]
  if cached and (stamp - (cached.t or 0)) <= 2 then
    return cached.out
  end

  -- Do not touch addon traffic, already-linked messages, or obvious guild recruitment.
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end
  if string.find(raw, "bronzelfgpub:", 1, true) then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end
  local low = lower and lower(raw) or string.lower(raw)
  if string.find(low, "guild", 1, true) and (string.find(low, "recruit", 1, true) or string.find(low, "recruiting", 1, true)) then
    self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}
    return nil
  end

  self._inlinePublicChatEventSeen = self._inlinePublicChatEventSeen or {}
  self._inlinePublicChatEventSeen[cacheKey] = stamp

  self._lastPublicGroupTouched = nil
  self._lastPublicGroupTouchedKey = nil
  self._suppressPublicRefreshInChatLink = true
  local ok = pcall(function() self:AddPublicGroup(author, raw, channelName or "Public") end)
  self._suppressPublicRefreshInChatLink = nil
  if not ok then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end

  local g = self._lastPublicGroupTouched
  if not g or not g.id then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end
  if tostring(g.player or "") ~= cleanAuthor or tostring(g.message or "") ~= cleanPublicChatText(raw) then
    self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}
    return nil
  end

  -- Avoid adding links to social/guild chatter. Applicant LFG posts are valid board entries.
  local t = tostring(g.type or "")
  if t == "Guild" or t == "Social" or t == "Other" then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end
  if t == "LFG" and tostring(g.intent or "") ~= "Applicant" then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end

  local link = self:PublicChatLink(g)
  if not link then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end

  local out = raw .. " " .. link
  self._inlinePublicChatCache[cacheKey] = {t=stamp, out=out}
  return out
end

function BLFG_PublicInlineFilter_561(frame, event, msgText, author, ...)
  if not BLFG or not BLFG.InlinePublicChatLinkForMessage then
    return false, msgText, author, ...
  end

  -- SignalFire 5.7.19: SAY/YELL are test-only sources. Do not parse normal
  -- /say or /yell unless /sf testsay on is enabled.
  if (event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL") and not BLFG.SignalFireTestSay then
    return false, msgText, author, ...
  end

  local channelName = event
  if event == "CHAT_MSG_CHANNEL" then
    local args = {...}
    -- 7th returned vararg is usually channel number, 8th is channel name in Wrath-era chat events;
    -- if this varies, it is only used as display/source metadata.
    channelName = tostring(args[8] or args[7] or "Channel")
  elseif event == "CHAT_MSG_SAY" then
    channelName = "Say"
  elseif event == "CHAT_MSG_YELL" then
    channelName = "Yell"
  end

  local newMsg = nil
  if SF577_BuildRoleComboLink then
    newMsg = SF577_BuildRoleComboLink(msgText, author, channelName)
  end
  if not newMsg then
    newMsg = BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  end
  if newMsg and newMsg ~= msgText then
    return false, newMsg, author, ...
  end
  return false, msgText, author, ...
end

if ChatFrame_AddMessageEventFilter and not BLFG._publicInlineFiltersInstalled_561 then
  BLFG._publicInlineFiltersInstalled_561 = true
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", BLFG_PublicInlineFilter_561)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", BLFG_PublicInlineFilter_561)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", BLFG_PublicInlineFilter_561)
end

-- Keep manual test, but make it match the new inline style.
BLFG_OldSlash_561 = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = lower(input or "")
  if input == "linktest" or input == "chatlinktest" then
    BLFG.publicGroups = BLFG.publicGroups or {}
    local id = "test-" .. tostring(now and now() or time())
    BLFG.publicGroups[id] = {
      id = id,
      player = playerName and playerName() or UnitName("player") or "You",
      message = "LFM Molten Core Normal 10m Need OT shaman MS/OS",
      channel = "Test",
      type = "Raid",
      activity = "Molten Core",
      roles = "|cff33aaffTank|r",
      intent = "Recruiter",
      tags = "Raid",
      ilevel = "",
      score = 100,
      created = now and now() or time(),
      seen = now and now() or time(),
    }
    local link = BLFG:PublicChatLink(BLFG.publicGroups[id])
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SignalFire Test]|r Mypetkills: LFM MC Normal 10m Need OT shaman MS/OS " .. link)
    return
  end

  if BLFG_OldSlash_561 then return BLFG_OldSlash_561(input) end
end


-- ============================================================================
-- v5.6.2 Inline Chat Link Cleanup
-- Removes open-confirmation spam and avoids Unicode arrows in 3.3.5 chat.
-- ============================================================================

function BLFG:OpenPublicGroupLink(id, title)
  self:CreateUI()
  local g, key = self:FindPublicGroupByIdOrTitle(id, title)
  self:ShowPublicGroups()

  if key then
    self.selectedPublic = key

    if g and g.type and g.type ~= "" then
      self.publicFilter = g.type
    else
      self.publicFilter = "All"
    end

    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end

    local rows = self:GetSortedPublicGroups()
    local per = self.publicRowsPerPage or 10
    for idx, rg in ipairs(rows) do
      if rg and rg.id == key then
        self.publicPage = math.max(1, math.ceil(idx / per))
        break
      end
    end

    self:RefreshPublicGroups()
    -- No chat confirmation here. The clicked link is already the confirmation.
  else
    self.publicFilter = "All"
    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end
    self:RefreshPublicGroups()
    -- Keep this silent too so chat never gets addon spam from clicking stale links.
  end
end

function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  if not msgText or not author then return nil end
  local raw = tostring(msgText or "")
  if raw == "" then return nil end

  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return nil end
  if string.find(raw, "bronzelfgpub:", 1, true) then return nil end

  local low = lower and lower(raw) or string.lower(raw)
  if string.find(low, "guild", 1, true) and (string.find(low, "recruit", 1, true) or string.find(low, "recruiting", 1, true)) then
    return nil
  end

  self:AddPublicGroup(author, raw, channelName or "Public")

  local g = self:FindNewestPublicByAuthor(author)
  if not g or not g.id then return nil end

  local t = tostring(g.type or "")
  if t == "Guild" or t == "Social" or t == "Other" then return nil end
  if t == "LFG" and tostring(g.intent or "") ~= "Applicant" then return nil end

  local link = self:PublicChatLink(g)
  if not link then return nil end

  -- ASCII only. Unicode arrows render as ? on some 3.3.5 clients/fonts.
  return raw .. " " .. link
end

BLFG_OldSlash_562 = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = lower(input or "")
  if input == "linktest" or input == "chatlinktest" then
    BLFG.publicGroups = BLFG.publicGroups or {}
    local id = "test-" .. tostring(now and now() or time())
    BLFG.publicGroups[id] = {
      id = id,
      player = playerName and playerName() or UnitName("player") or "You",
      message = "LFM Molten Core Normal 10m Need OT shaman MS/OS",
      channel = "Test",
      type = "Raid",
      activity = "Molten Core",
      roles = "|cff33aaffTank|r",
      intent = "Recruiter",
      tags = "Raid",
      ilevel = "",
      score = 100,
      created = now and now() or time(),
      seen = now and now() or time(),
    }
    local link = BLFG:PublicChatLink(BLFG.publicGroups[id])
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SignalFire Test]|r Mypetkills: LFM MC Normal 10m Need OT shaman MS/OS " .. link)
    return
  end

  if BLFG_OldSlash_562 then return BLFG_OldSlash_562(input) end
end


-- ============================================================================
-- v5.6.3 Guild Ad Filter Fix for Public Group Chat Links
-- Prevents guild recruitment pitches from being treated as Event/Public Group links.
-- ============================================================================

function BLFG_IsLikelyGuildRecruitmentAd_563(text)
  local raw = tostring(text or "")
  local low = lower and lower(raw) or string.lower(raw)

  -- Strong signal: guild name style at the beginning or inside the post.
  local hasGuildBracket = string.find(raw, "<[^>]+>") ~= nil

  -- Guild recruitment phrases usually say invite/recruit/join/community/discord,
  -- and often list multiple content interests rather than one group.
  local guildPhrase =
    string.find(low, "guild", 1, true) or
    string.find(low, "recruit", 1, true) or
    string.find(low, "recruiting", 1, true) or
    string.find(low, "join us", 1, true) or
    string.find(low, "community", 1, true) or
    string.find(low, "for an invite", 1, true) or
    string.find(low, "/w for an invite", 1, true) or
    string.find(low, "discord", 1, true)

  local guildMenu =
    (string.find(low, "raids", 1, true) or string.find(low, "raid", 1, true)) and
    (string.find(low, "pvp", 1, true) or string.find(low, "boss blitz", 1, true) or string.find(low, "based", 1, true) or string.find(low, "years", 1, true))

  -- Strong group-post signals. If these exist, do not force guild classification.
  local groupSignal =
    string.find(low, "lfm", 1, true) or
    string.find(low, "lf%d", 1, false) or
    string.find(low, "need tank", 1, true) or
    string.find(low, "need heal", 1, true) or
    string.find(low, "need heals", 1, true) or
    string.find(low, "need dps", 1, true) or
    string.find(low, "need ot", 1, true) or
    string.find(low, "need mt", 1, true) or
    string.find(low, "looking for", 1, true)

  if hasGuildBracket and (guildPhrase or guildMenu) and not groupSignal then
    return true
  end

  -- Explicit guild recruitment without angle brackets.
  if string.find(low, "guild recruitment", 1, true) or string.find(low, "guild is recruiting", 1, true) then
    return true
  end

  return false
end

-- Re-wrap AddPublicGroup so guild ads get normalized as Guild, not Event.
BLFG_AddPublicGroup_Original_563 = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local name = tostring(author or ""):gsub("%-.*", "")
  local isGuildAd = BLFG_IsLikelyGuildRecruitmentAd_563(text)

  local r = BLFG_AddPublicGroup_Original_563(self, author, text, channelName)

  if isGuildAd and self.publicGroups then
    local newest, newestKey, newestSeen = nil, nil, 0
    for k, g in pairs(self.publicGroups or {}) do
      if g and g.player == name then
        local seen = tonumber(g.seen or g.created or 0) or 0
        if seen >= newestSeen then
          newest, newestKey, newestSeen = g, k, seen
        end
      end
    end

    if newest then
      newest.type = "Guild"
      newest.activity = "Guild Recruitment"
      newest.intent = "Recruiter"
      newest.tags = "Guild"
      newest.roles = "Recruiting"
      newest.score = 0
      if self.publicPanel and self.publicPanel:IsShown() then self:RefreshPublicGroups() end
    end
  end

  return r
end

-- Re-wrap inline linker so guild ads never get clickable public-group title links.
BLFG_InlinePublicChatLinkForMessage_Original_563 = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  if BLFG_IsLikelyGuildRecruitmentAd_563(msgText) then
    -- Still let the existing AddPublicGroup path classify it for Guild Browser/Guild filter,
    -- but do not append a Public Group clickable link to chat.
    self:AddPublicGroup(author, msgText, channelName or "Public")
    return nil
  end
  if BLFG_InlinePublicChatLinkForMessage_Original_563 then
    return BLFG_InlinePublicChatLinkForMessage_Original_563(self, msgText, author, channelName)
  end
  return nil
end


-- ============================================================================
-- v5.6.4 Inline Guild Recruitment Links
-- Guild recruitment chat posts now append a clickable [Guild Name] link
-- that opens the Guild Browser and selects the guild.
-- ============================================================================

function BLFG_ExtractGuildNameFromChatAd_564(text)
  text = tostring(text or "")
  local g = string.match(text, "<([^>]+)>")
  if g and g ~= "" then
    g = g:gsub("^%s+", ""):gsub("%s+$", "")
    return g
  end

  -- Fallbacks for posts without angle brackets.
  g = string.match(text, "%[Guild:%s*([^%]]+)%]")
  if g and g ~= "" then return g:gsub("^%s+", ""):gsub("%s+$", "") end

  return ""
end

function BLFG_GuildLinkSafeText_564(s)
  s = tostring(s or "")
  s = s:gsub("|", "")
  s = s:gsub("%[", "")
  s = s:gsub("%]", "")
  if string.len(s) > 40 then s = string.sub(s, 1, 37) .. "..." end
  return s
end

function BLFG:GuildChatLink(guildName)
  guildName = BLFG_GuildLinkSafeText_564(guildName or "")
  if guildName == "" then return nil end
  return "|cffd4a017|Hbronzelfgguild:" .. guildName .. "|h[" .. guildName .. "]|h|r"
end

function BLFG:FindGuildRowByName_564(guildName)
  guildName = tostring(guildName or "")
  if guildName == "" then return nil end
  local target = string.lower(guildName)

  -- Search existing guild rows if available.
  local rows = nil
  if self.GetGuildRows then
    local ok, result = pcall(function() return self:GetGuildRows() end)
    if ok then rows = result end
  end

  if rows then
    for _, g in ipairs(rows) do
      local n = tostring(g.name or g.guild or "")
      if string.lower(n) == target then return g end
    end
  end

  -- Search raw guild cache/table fallback.
  for _, source in ipairs({self.guilds or {}, self.guildBrowserGuilds or {}, self.guildRowsData or {}}) do
    for k, g in pairs(source) do
      if type(g) == "table" then
        local n = tostring(g.name or g.guild or k or "")
        if string.lower(n) == target then return g end
      elseif type(k) == "string" and string.lower(k) == target then
        return {name = k, guild = k}
      end
    end
  end

  return {name = guildName, guild = guildName}
end

function BLFG:OpenGuildBrowserLink(guildName)
  self:CreateUI()
  if self.ShowGuildBrowser then
    self:ShowGuildBrowser()
  else
    self:HidePanels()
    if self.guildPanel then self.guildPanel:Show() end
    if self.frame then self.frame:Show() end
  end

  local g = self:FindGuildRowByName_564(guildName)
  local name = tostring((g and (g.name or g.guild)) or guildName or "")

  -- The project has used a few selected-guild names over time, so set the likely ones.
  self.selectedGuild = name
  self.selectedGuildName = name
  self.guildSelected = name
  self.selectedGuildRow = g

  -- Try common detail refresh functions safely.
  if self.RefreshGuildBrowser then pcall(function() self:RefreshGuildBrowser() end) end
  if self.RefreshGuildDetailPanel then pcall(function() self:RefreshGuildDetailPanel(g) end) end
  if self.ShowGuildDetail then pcall(function() self:ShowGuildDetail(g) end) end
  if self.UpdateGuildDetail then pcall(function() self:UpdateGuildDetail(g) end) end

  -- If the browser did not select automatically, at least use search to narrow it.
  if self.guildSearch and self.guildSearch.SetText and name ~= "" then
    pcall(function()
      self.guildSearch:SetText(name)
      if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
    end)
  end
end

-- Override inline linker: guild ads get Guild Browser links; content gets Public Groups links.
BLFG_InlinePublicChatLinkForMessage_Original_564 = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw = tostring(msgText or "")
  if raw == "" then return nil end

  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return nil end
  if string.find(raw, "bronzelfgpub:", 1, true) or string.find(raw, "bronzelfgguild:", 1, true) then return nil end

  local isGuildAd = false
  if BLFG_IsLikelyGuildRecruitmentAd_563 then
    isGuildAd = BLFG_IsLikelyGuildRecruitmentAd_563(raw)
  else
    local low = lower and lower(raw) or string.lower(raw)
    isGuildAd = string.find(raw, "<[^>]+>") and (string.find(low, "recruit", 1, true) or string.find(low, "guild", 1, true) or string.find(low, "discord", 1, true) or string.find(low, "invite", 1, true))
  end

  if isGuildAd then
    self:AddPublicGroup(author, raw, channelName or "Public")

    local guildName = BLFG_ExtractGuildNameFromChatAd_564(raw)
    if guildName == "" then return nil end

    local link = self:GuildChatLink(guildName)
    if not link then return nil end

    -- ASCII only, no arrow, no extra BronzeLFG spam line.
    return raw .. " " .. link
  end

  if BLFG_InlinePublicChatLinkForMessage_Original_564 then
    return BLFG_InlinePublicChatLinkForMessage_Original_564(self, msgText, author, channelName)
  end

  return nil
end

-- Extend SetItemRef for guild links while preserving public group links.
BLFG_SetItemRef_BeforeGuild_564 = SetItemRef
function SetItemRef(link, text, button, chatFrame)
  if type(link) == "string" and string.sub(link, 1, 15) == "bronzelfgguild:" then
    local guildName = string.sub(link, 16)
    guildName = guildName:gsub("%%20", " ")
    if BLFG and BLFG.OpenGuildBrowserLink then
      BLFG:OpenGuildBrowserLink(guildName)
    end
    return
  end

  if BLFG_SetItemRef_BeforeGuild_564 then
    return BLFG_SetItemRef_BeforeGuild_564(link, text, button, chatFrame)
  end
end

-- Manual test:
-- /blfg guildlinktest
BLFG_OldSlash_564 = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = lower(input or "")
  if input == "guildlinktest" then
    local raw = "<RevSeaAsia> SEA&OCE GMT+8 Top 2 Guild on WoW Ambershire taking a Refuge Here! Competitive English Speaking and Experienced Guild! Guild Is Now 10/10M 6/10Asc MC in Just 1 month Starting From Scratch! Super Fast Prog! Anyone Welcome!"
    local link = BLFG:GuildChatLink("RevSeaAsia")
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SignalFire Test]|r " .. raw .. " " .. link)
    return
  end

  if BLFG_OldSlash_564 then return BLFG_OldSlash_564(input) end
end


-- ============================================================================
-- v5.6.5 Guild Browser Cleanup + Guild Link Stabilizer
-- Final override layer for 5.6.4 experimental inline guild links.
-- Goals:
--   * Guild recruitment ads classify as Guild before Event/Public Groups.
--   * Guild ads append clickable [Guild Name] links.
--   * Public group/guild clicks stay silent.
--   * Guild Browser focus tags stay compact in the list.
--   * Detail panel Discord line no longer overlaps Focus/BronzeNet text.
-- ============================================================================

function BLFG_565_Lower(s)
  if lower then return lower(tostring(s or "")) end
  return string.lower(tostring(s or ""))
end

function BLFG_565_Trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function BLFG_565_StripLinkNoise(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  s = s:gsub("|H.-|h", "")
  s = s:gsub("|h", "")
  return s
end

function BLFG_565_GuildNameFromAd(text)
  text = tostring(text or "")
  local g = string.match(text, "<([^<>]+)>")
  if g and BLFG_565_Trim(g) ~= "" then return BLFG_565_Trim(g) end

  g = string.match(text, "%[Guild:%s*([^%]]+)%]")
  if g and BLFG_565_Trim(g) ~= "" then return BLFG_565_Trim(g) end

  g = string.match(text, "^[%s%p]*([%w%s%-_']+)%s+[Ii]s%s+[Rr]ecruiting")
  if g and BLFG_565_Trim(g) ~= "" then return BLFG_565_Trim(g) end

  g = string.match(text, "^[%s%p]*([%w%s%-_']+)%s+[Rr]ecruiting")
  if g and BLFG_565_Trim(g) ~= "" then return BLFG_565_Trim(g) end

  return ""
end

function BLFG_565_IsGuildRecruitmentAd(text)
  local raw = tostring(text or "")
  local low = BLFG_565_Lower(raw)
  local hasBracketGuild = string.find(raw, "<[^<>]+>") ~= nil

  local guildIntent =
    string.find(low, "guild", 1, true) or
    string.find(low, "recruit", 1, true) or
    string.find(low, "recruiting", 1, true) or
    string.find(low, "recruitment", 1, true) or
    string.find(low, "members", 1, true) or
    string.find(low, "players", 1, true) or
    string.find(low, "join us", 1, true) or
    string.find(low, "anyone welcome", 1, true) or
    string.find(low, "for an invite", 1, true) or
    string.find(low, "discord", 1, true) or
    string.find(low, "top 2 guild", 1, true) or
    string.find(low, "top 5 guild", 1, true) or
    string.find(low, "competitive", 1, true)

  local broadGuildMenu =
    (string.find(low, "raid", 1, true) or string.find(low, "raiding", 1, true) or string.find(low, "mythic", 1, true) or string.find(low, "asc", 1, true)) and
    (string.find(low, "pvp", 1, true) or string.find(low, "boss blitz", 1, true) or string.find(low, "social", 1, true) or string.find(low, "level", 1, true) or string.find(low, "discord", 1, true))

  -- These are true one-off group ads and should remain Public Groups.
  local hardGroupSignal =
    string.find(low, "lfm", 1, true) or
    string.find(low, "lfg", 1, true) or
    string.find(low, "need tank", 1, true) or
    string.find(low, "need healer", 1, true) or
    string.find(low, "need heal", 1, true) or
    string.find(low, "need dps", 1, true) or
    string.find(low, "need ot", 1, true) or
    string.find(low, "need mt", 1, true) or
    string.find(low, "last spot", 1, true)

  if hasBracketGuild and (guildIntent or broadGuildMenu) and not hardGroupSignal then return true end
  if string.find(low, "guild recruitment", 1, true) or string.find(low, "guild recruiting", 1, true) or string.find(low, "guild is recruiting", 1, true) then return true end
  if string.find(low, "top 2 guild", 1, true) or string.find(low, "top 5 guild", 1, true) then return true end
  if string.find(low, "competitive", 1, true) and string.find(low, "guild", 1, true) then return true end
  return false
end

-- Make the core guild classifier use the stronger final logic when later code calls it.
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_565_IsGuildRecruitmentAd

function BLFG_565_SafeLinkPayload(s)
  s = tostring(s or "")
  s = s:gsub("|", "")
  s = s:gsub("%[", "")
  s = s:gsub("%]", "")
  s = s:gsub(":", "-")
  s = BLFG_565_Trim(s)
  return s
end

function BLFG:GuildChatLink(guildName)
  guildName = BLFG_565_SafeLinkPayload(guildName or "")
  if guildName == "" then return nil end
  if string.len(guildName) > 40 then guildName = string.sub(guildName, 1, 37) .. "..." end
  return "|cffd4a017|Hbronzelfgguild:" .. guildName .. "|h[" .. guildName .. "]|h|r"
end

function BLFG:InsertGuildLinkInText(raw, guildName)
  raw = tostring(raw or "")
  guildName = tostring(guildName or "")
  local link = self.GuildChatLink and self:GuildChatLink(guildName) or nil
  if raw == "" or guildName == "" or not link then return raw end
  if string.find(raw, "bronzelfgguild:", 1, true) then return raw end
  local low = string.lower(raw)
  local nameLow = string.lower(guildName)
  local angle = "<" .. nameLow .. ">"
  local as, ae = string.find(low, angle, 1, true)
  if as then return string.sub(raw, 1, as - 1) .. link .. string.sub(raw, ae + 1) end
  local bracket = "[" .. nameLow .. "]"
  local bs, be = string.find(low, bracket, 1, true)
  if bs then return string.sub(raw, 1, bs - 1) .. link .. string.sub(raw, be + 1) end
  local s, e = string.find(low, nameLow, 1, true)
  if s then return string.sub(raw, 1, s - 1) .. link .. string.sub(raw, e + 1) end
  return raw .. " " .. link
end

-- Keep public titles compact and ASCII-only. This also prevents accidental stray
-- glyphs from older inline-link experiments from showing as '?'.
function BLFG:PublicChatLink(g)
  if not g or not g.id then return nil end
  local title = self.PublicLinkTitle and self:PublicLinkTitle(g) or tostring(g.activity or "Open Group")
  title = BLFG_565_SafeLinkPayload(title)
  if string.len(title) > 72 then title = string.sub(title, 1, 69) .. "..." end
  return "|cffd4a017|Hbronzelfgpub:" .. tostring(g.id) .. "|h[" .. title .. "]|h|r"
end

BLFG_AddPublicGroup_Before565 = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local isGuildAd = BLFG_565_IsGuildRecruitmentAd(text)
  local r = nil
  if BLFG_AddPublicGroup_Before565 then
    r = BLFG_AddPublicGroup_Before565(self, author, text, channelName)
  end

  if isGuildAd and self.publicGroups then
    local authorName = tostring(author or ""):gsub("%-.*", "")
    local newest, newestKey, newestSeen = nil, nil, 0
    for k, g in pairs(self.publicGroups or {}) do
      if g and tostring(g.player or "") == authorName then
        local seen = tonumber(g.seen or g.created or 0) or 0
        if seen >= newestSeen then newest, newestKey, newestSeen = g, k, seen end
      end
    end
    if newest then
      newest.type = "Guild"
      newest.activity = "Guild Recruitment"
      newest.intent = "Recruiter"
      newest.tags = "Guild"
      newest.roles = "Recruiting"
      newest.score = 0
      newest.guildName = BLFG_565_GuildNameFromAd(text)
      if self.publicPanel and self.publicPanel:IsShown() and self.RefreshPublicGroups then self:RefreshPublicGroups() end
    end
  end

  return r
end

function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  if not msgText or not author then return nil end
  local raw = tostring(msgText or "")
  if raw == "" then return nil end

  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return nil end
  if string.find(raw, "bronzelfgpub:", 1, true) or string.find(raw, "bronzelfgguild:", 1, true) then return nil end

  if BLFG_565_IsGuildRecruitmentAd(raw) then
    self:AddPublicGroup(author, raw, channelName or "Public")
    local guildName = BLFG_565_GuildNameFromAd(raw)
    if guildName == "" then return nil end
    local link = self:GuildChatLink(guildName)
    if not link then return nil end
    return raw .. " " .. link
  end

  self:AddPublicGroup(author, raw, channelName or "Public")
  local g = self.FindNewestPublicByAuthor and self:FindNewestPublicByAuthor(author) or nil
  if not g or not g.id then return nil end

  local t = tostring(g.type or "")
  if t == "Guild" or t == "Social" or t == "Other" then return nil end
  if t == "LFG" and tostring(g.intent or "") ~= "Applicant" then return nil end

  local link = self:PublicChatLink(g)
  if not link then return nil end
  return raw .. " " .. link
end

function BLFG:OpenPublicGroupLink(id, title)
  self:CreateUI()
  local g, key = nil, nil
  if self.FindPublicGroupByIdOrTitle then g, key = self:FindPublicGroupByIdOrTitle(id, title) end
  if self.ShowPublicGroups then self:ShowPublicGroups() end

  if key then
    self.selectedPublic = key
    self.publicFilter = (g and g.type and g.type ~= "") and g.type or "All"
    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end
    if self.GetSortedPublicGroups then
      local rows = self:GetSortedPublicGroups()
      local per = self.publicRowsPerPage or 10
      for idx, rg in ipairs(rows) do
        if rg and rg.id == key then self.publicPage = math.max(1, math.ceil(idx / per)); break end
      end
    end
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  else
    self.publicFilter = "All"
    self.publicSearchText = ""
    if self.publicSearch then self.publicSearch:SetText("") end
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  end
  -- Deliberately silent. No click-confirmation chat spam.
end

function BLFG:OpenGuildBrowserLink(guildName)
  self:CreateUI()
  guildName = BLFG_565_Trim(guildName or "")
  if self.ShowGuildBrowser then
    self:ShowGuildBrowser()
  else
    self:HidePanels()
    if self.guildPanel then self.guildPanel:Show() end
    if self.frame then self.frame:Show() end
  end

  local g = nil
  if self.FindGuildRowByName_564 then g = self:FindGuildRowByName_564(guildName) end
  local name = tostring((g and (g.name or g.guild)) or guildName or "")
  self.selectedGuild = name
  self.selectedGuildName = name
  self.guildSelected = name
  self.selectedGuildRow = g

  -- Do not force the search box. Selecting the row is cleaner and avoids hiding other rows forever.
  if self.guildSearch and self.guildSearch.SetText then
    pcall(function() self.guildSearch:SetText("") end)
  end
  if self.RefreshGuildBrowser then pcall(function() self:RefreshGuildBrowser() end) end
  if self.RefreshGuildDetailPanel then pcall(function() self:RefreshGuildDetailPanel(g) end) end
  -- Deliberately silent. Clicking a guild link should not print anything.
end

-- Final SetItemRef wrapper: handles both BronzeLFG link types and strips link text safely.
BLFG_SetItemRef_Before565 = SetItemRef
function SetItemRef(link, text, button, chatFrame)
  if type(link) == "string" and string.sub(link, 1, 13) == "bronzelfgpub:" then
    local id = string.sub(link, 14)
    local title = ""
    if type(text) == "string" then
      title = BLFG_565_StripLinkNoise(text):gsub("^%[", ""):gsub("%]$", "")
    end
    if BLFG and BLFG.OpenPublicGroupLink then BLFG:OpenPublicGroupLink(id, title) end
    return
  end
  if type(link) == "string" and string.sub(link, 1, 15) == "bronzelfgguild:" then
    local guildName = string.sub(link, 16)
    guildName = guildName:gsub("%%20", " ")
    if BLFG and BLFG.OpenGuildBrowserLink then BLFG:OpenGuildBrowserLink(guildName) end
    return
  end
  if BLFG_SetItemRef_Before565 then return BLFG_SetItemRef_Before565(link, text, button, chatFrame) end
end

-- More reliable focus tokenization for compact row display.
function BLFG_565_FocusTokens(raw, fallback)
  raw = BLFG_565_StripLinkNoise(tostring(raw or "") .. " " .. tostring(fallback or ""))
  local low = BLFG_565_Lower(raw)
  local tags, seen = {}, {}
  local function add(t)
    if t and t ~= "" and not seen[t] then seen[t] = true; table.insert(tags, t) end
  end
  if string.find(low, "mythic+", 1, true) or string.find(low, "m+", 1, true) or string.find(low, "mythic plus", 1, true) or string.find(low, "key", 1, true) then add("Keys") end
  if string.find(low, "raid", 1, true) or string.find(low, "raiding", 1, true) or string.find(low, "molten core", 1, true) or string.find(low, "bwl", 1, true) or string.find(low, "naxx", 1, true) or string.find(low, "ony", 1, true) or string.find(low, "zg", 1, true) or string.find(low, "aq20", 1, true) or string.find(low, "aq40", 1, true) then add("Raiding") end
  if string.find(low, "world boss", 1, true) or string.find(low, "world bosses", 1, true) then add("World Boss") end
  if string.find(low, "pvp", 1, true) or string.find(low, "arena", 1, true) or string.find(low, "battleground", 1, true) then add("PvP") end
  if string.find(low, "level", 1, true) or string.find(low, "leveling", 1, true) or string.find(low, "new player", 1, true) then add("Leveling") end
  if string.find(low, "social", 1, true) or string.find(low, "community", 1, true) or string.find(low, "casual", 1, true) or string.find(low, "chill", 1, true) or string.find(low, "friendly", 1, true) then add("Social") end
  if string.find(low, "dungeon", 1, true) then add("Dungeons") end
  return tags
end

function BLFG_565_ColorFocusCompact(raw, fallback, limit)
  limit = limit or 2
  local colors = {
    ["Keys"] = "|cFF80B0FF[Keys]|r",
    ["Mythic+"] = "|cFF80B0FF[Keys]|r",
    ["Raiding"] = "|cFFFF5555[Raiding]|r",
    ["World Boss"] = "|cFFFFCC00[World Boss]|r",
    ["PvP"] = "|cFFFF7777[PvP]|r",
    ["Leveling"] = "|cFF55FF55[Leveling]|r",
    ["Social"] = "|cFF55CCFF[Social]|r",
    ["Hardcore"] = "|cFFFFAA55[Hardcore]|r",
    ["Dungeons"] = "|cFFAAAAFF[Dungeons]|r",
  }
  local tags = BLFG_565_FocusTokens(raw, fallback)
  local out = {}
  for i, tag in ipairs(tags) do
    if i > limit then break end
    table.insert(out, colors[tag] or ("|cFFFFFFFF[" .. tag .. "]|r"))
  end
  if #tags > limit then table.insert(out, "|cFFAAAAAA[+" .. tostring(#tags - limit) .. "]|r") end
  if #out == 0 then return "|cFFAAAAAA[Unknown]|r" end
  return table.concat(out, " ")
end

function BLFG:FormatFocusTagsCompact(value, fallbackText, limit)
  return BLFG_565_ColorFocusCompact(value or "", fallbackText or "", limit or 2)
end

BLFG_RefreshGuildBrowser_Before565 = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  local r = nil
  if BLFG_RefreshGuildBrowser_Before565 then r = BLFG_RefreshGuildBrowser_Before565(self, ...) end

  if self.guildRows then
    for _, row in ipairs(self.guildRows) do
      if row and row.guildData then
        local g = row.guildData
        if row.focus and row.focus.SetText then
          row.focus:SetText(self:FormatFocusTagsCompact(g.focusRaw or g.focus or g.focusText or g.postFocus or "", g.lastPost or g.message or "", 2))
          row.focus:SetWidth(92)
          if row.focus.SetNonSpaceWrap then row.focus:SetNonSpaceWrap(false) end
          if row.focus.SetHeight then row.focus:SetHeight(14) end
        end
        if row.recruiting and row.recruiting.SetText and self.FormatRecruitingTags then
          local recruit = tostring(g.recruiting or g.postKind or "")
          if (recruit == "" or BLFG_565_Lower(recruit) == "recruiting" or BLFG_565_Lower(recruit) == "unknown") and g.lastPost then recruit = tostring(g.lastPost) end
          row.recruiting:SetText(self:FormatRecruitingTags(recruit))
        end
      end
    end
  end
  return r
end

BLFG_RefreshGuildDetailPanel_Before565 = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g, ...)
  local r = nil
  if BLFG_RefreshGuildDetailPanel_Before565 then r = BLFG_RefreshGuildDetailPanel_Before565(self, g, ...) end
  local d = self.guildDetailPanel
  if not d then return r end

  -- Re-space the right panel so Discord, BronzeNet, Focus, and message box no longer collide.
  if d.members then d.members:ClearAllPoints(); d.members:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -142); d.members:SetWidth(260); d.members:Show() end
  if d.focusLabel then d.focusLabel:ClearAllPoints(); d.focusLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -182) end
  if d.focus then
    d.focus:ClearAllPoints(); d.focus:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -202); d.focus:SetWidth(260); d.focus:SetHeight(18); d.focus:SetJustifyH("LEFT")
    if d.focus.SetNonSpaceWrap then d.focus:SetNonSpaceWrap(false) end
    if g then d.focus:SetText(self:FormatFocusTagsCompact(g.focusRaw or g.focus or g.focusText or g.postFocus or "", g.lastPost or g.message or "", 4)) end
  end
  if d.recentBox then d.recentBox:ClearAllPoints(); d.recentBox:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -232); d.recentBox:SetHeight(95) end
  if d.message then d.message:SetHeight(55) end

  if not self.guildDiscordLine then
    self.guildDiscordLine = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.guildDiscordLine:SetJustifyH("LEFT")
  end
  self.guildDiscordLine:ClearAllPoints()
  self.guildDiscordLine:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -162)
  self.guildDiscordLine:SetWidth(260)
  local disc = self.GetGuildDiscordDisplay and self:GetGuildDiscordDisplay(g) or ""
  if disc and disc ~= "" then
    self.guildDiscordLine:SetText("|cFFFFCC00Discord:|r |cFF99CCFF" .. disc .. "|r")
    self.guildDiscordLine:Show()
  else
    self.guildDiscordLine:SetText("")
    self.guildDiscordLine:Hide()
  end
  return r
end

-- Test helper for this exact stage.
BLFG_OldSlash_565 = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = BLFG_565_Lower(input or "")
  if input == "guildlinktest" then
    local raw = "<RevSeaAsia> SEA&OCE GMT+8 Top 2 Guild on WoW Ambershire taking a Refuge Here! Competitive English Speaking and Experienced Guild! Guild Is Now 10/10M 6/10Asc MC. Anyone Welcome!"
    DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[SignalFire Test]|r " .. raw .. " " .. (BLFG:GuildChatLink("RevSeaAsia") or ""))
    return
  elseif input == "guildclassifytest" then
    local samples = {
      "<PIRATES> recruiting raiders, PvP, HCBB and social players. Discord available.",
      "<RevSeaAsia> Top 2 Guild recruiting English speaking players. Anyone Welcome!",
      "LFM Maraudon Need DPS",
    }
    for _, s in ipairs(samples) do
      DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017SignalFire classify:|r " .. tostring(BLFG_565_IsGuildRecruitmentAd(s)) .. " - " .. s)
    end
    return
  end
  if BLFG_OldSlash_565 then return BLFG_OldSlash_565(input) end
end

-- ============================================================================
-- BronzeLFG v5.6.7 - Guild moderation + profile whisper templates + alert cleanup
-- ============================================================================

BLFG.version = "5.6.8"

function BLFG_567_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_567_Trim(s) s=tostring(s or ""); return (s:gsub("^%s+",""):gsub("%s+$","")) end
function BLFG_567_Strip(s)
  s=tostring(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("|H.-|h",""):gsub("|h","")
  return s
end
function BLFG_567_PlayerIsAdmin()
  return tostring(UnitName("player") or "") == "Hsoj" and tostring(GetRealmName() or "") == "Bronzebeard"
end
function BLFG_567_ChannelId()
  local id = GetChannelName and GetChannelName("BLFG")
  if id and id > 0 then return id end
  return nil
end
function BLFG_567_Send(payload)
  local id = BLFG_567_ChannelId()
  if id then SendChatMessage(payload, "CHANNEL", nil, id) end
end
function BLFG_567_IsGuildAd(text)
  local l=BLFG_567_Lower(text)
  if l:find("blfg%d",1) or l:find("~ping~",1,true) then return false end
  if l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) or l:find("realm first",1,true) or l:find("server %d") or l:find("raid",1,true) then return true end
  return false
end
function BLFG_567_GuildNameFromAd(text)
  local s=BLFG_567_Strip(text)
  local g=s:match("<([^>]+)>")
  if g and g ~= "" then return BLFG_567_Trim(g) end
  g=s:match("^[%s%p]*([%u][%u%s%-%_']-)%s*[%p%s]*%[NA/EU%]")
  if g and g ~= "" then return BLFG_567_Trim((g:gsub("^[%p%s]+",""):gsub("[%p%s]+$",""))) end
  g=s:match("^[%s%p]*([%u][%u%s%-%_']+)%s+.-[Rr]ecruit")
  if g and g ~= "" then
    g=BLFG_567_Trim((g:gsub("^[%p%s]+",""):gsub("[%p%s]+$","")))
    if string.len(g) <= 32 then return g end
  end
  return nil
end
function BLFG_567_IsKeystoneText(text)
  local l=BLFG_567_Lower(text)
  if l:find("mythic%+") or l:find("m%+") or l:find("keystone",1,true) or l:find(" key",1,true) or l:find("+%d") then return true end
  return false
end
function BLFG_567_IsDungeonText(text)
  local l=BLFG_567_Lower(text)
  if BLFG_567_IsKeystoneText(text) then return false end
  if l:find("dire maul",1,true) or l:find("maraudon",1,true) or l:find("strath",1,true) or l:find("scholo",1,true) or l:find("brd",1,true) or l:find("blackrock depths",1,true) or l:find("sunken temple",1,true) or l:find("uldaman",1,true) or l:find("scarlet monastery",1,true) or l:find("deadmines",1,true) or l:find("dungeon",1,true) then return true end
  return false
end
function BLFG_567_ShortGuildKey(name) return BLFG_567_Lower(BLFG_567_Trim(name or "")) end

function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
  guildName = BLFG_567_Trim(guildName or "")
  if guildName == "" then return end
  self.chatGuildListings = self.chatGuildListings or {}
  BronzeLFG_DB.chatGuildListings = BronzeLFG_DB.chatGuildListings or {}
  local key = BLFG_567_ShortGuildKey(guildName)
  local row = self.chatGuildListings[key] or BronzeLFG_DB.chatGuildListings[key] or {}
  row.name = guildName
  row.guild = guildName
  row.status = "Chat Only"
  row.source = "Chat"
  row.online = row.online or 0
  row.posts = (tonumber(row.posts or 0) or 0) + 1
  row.contact = tostring(author or row.contact or ""):gsub("%-.*","")
  row.postContact = row.contact
  row.lastPost = tostring(text or row.lastPost or "")
  row.message = row.lastPost
  row.lastPostSeen = time()
  row.lastPostTime = "now"
  row.recruiting = "Recruiting"
  row.postKind = "Recruiting"
  row.focus = self.GetRawFocusTags and self:GetRawFocusTags("", row.lastPost) or "Unknown"
  if row.focus == "" then row.focus = "Unknown" end
  row.focusText = row.focus
  row.postFocus = row.focus
  row.discord = BLFG_ExtractDiscord and BLFG_ExtractDiscord(row.lastPost) or ""
  row.chatOnly = true
  self.chatGuildListings[key] = row
  BronzeLFG_DB.chatGuildListings[key] = row
end

BLFG_567_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  local rows,a,b,c = BLFG_567_OldGetGuildRows(self,...)
  rows = rows or {}
  self.chatGuildListings = self.chatGuildListings or BronzeLFG_DB.chatGuildListings or {}
  BronzeLFG_DB.chatGuildListings = self.chatGuildListings
  for key,g in pairs(self.chatGuildListings or {}) do
    if g and g.name then
      local found=false
      for _,r in ipairs(rows) do
        if r and BLFG_567_ShortGuildKey(r.name or r.guild) == key then
          r.posts=(tonumber(r.posts or 0) or 0)+(tonumber(g.posts or 0) or 0)
          r.source=((tonumber(r.online or 0) or 0)>0) and "BronzeNet + Chat" or "Chat"
          r.status=((tonumber(r.online or 0) or 0)>0) and "Live + Chat" or "Chat Only"
          r.lastPost=g.lastPost or r.lastPost
          r.message=g.message or r.message
          r.postContact=g.postContact or r.postContact
          r.contact=r.postContact or r.contact
          r.postKind=g.postKind or r.postKind
          r.recruiting=g.recruiting or r.recruiting
          r.postFocus=g.postFocus or r.postFocus
          r.focus=g.focus or r.focus
          r.focusRaw=g.focusRaw or g.focus or r.focusRaw
          r.discord=g.discord or r.discord
          r.chatOnly = true
          found=true
          break
        end
      end
      if not found then table.insert(rows, g) end
    end
  end
  return rows,a,b,c
end

BLFG_567_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local guildName = nil
  if BLFG_567_IsGuildAd(text) then guildName = BLFG_567_GuildNameFromAd(text) end
  local r = BLFG_567_OldAddPublicGroup and BLFG_567_OldAddPublicGroup(self, author, text, channelName)
  if guildName then
    self:UpsertGuildBrowserChatListing(guildName, author, text)
    for _,g in pairs(self.publicGroups or {}) do
      if g and tostring(g.player or ""):gsub("%-.*","") == tostring(author or ""):gsub("%-.*","") and g.message and tostring(g.message):find(guildName,1,true) then
        g.type="Guild"; g.activity="Guild Recruitment"; g.guildName=guildName
      end
    end
    if self.guildPanel and self.guildPanel:IsVisible() then self:RefreshGuildBrowser() end
  end
  if BLFG_567_IsDungeonText(text) then
    for _,g in pairs(self.publicGroups or {}) do
      if g and tostring(g.player or ""):gsub("%-.*","") == tostring(author or ""):gsub("%-.*","") and g.seen and (time() - (tonumber(g.seen) or 0)) < 5 then
        g.type="Dungeon"
        if not g.activity or g.activity == "Mythic+" or g.activity == "General Listing" or g.activity == "Looking For Group" then g.activity="General Dungeon" end
      end
    end
  end
  return r
end

function BLFG:RemoveGuildListingByName(guildName, broadcast)
  guildName=BLFG_567_Trim(guildName or "")
  if guildName == "" then return end
  local key=BLFG_567_ShortGuildKey(guildName)
  self.chatGuildListings = self.chatGuildListings or BronzeLFG_DB.chatGuildListings or {}
  self.chatGuildListings[key]=nil
  if BronzeLFG_DB.chatGuildListings then BronzeLFG_DB.chatGuildListings[key]=nil end
  for id,g in pairs(self.publicGroups or {}) do
    local gn = tostring(g.guildName or (g.message and BLFG_567_GuildNameFromAd(g.message)) or "")
    if BLFG_567_ShortGuildKey(gn) == key or (g.type == "Guild" and BLFG_567_ShortGuildKey(g.activity) == key) then self.publicGroups[id]=nil end
  end
  if self.selectedGuild and BLFG_567_ShortGuildKey(self.selectedGuild) == key then self.selectedGuild=nil end
  if broadcast == true and BLFG_567_PlayerIsAdmin() then
    BLFG_567_Send("BLFG312~GUILDREMOVE~Hsoj~" .. guildName)
  end
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

BLFG_567_OldHandleMessage = BLFG.HandleMessage
function BLFG:HandleMessage(text)
  if type(text)=="string" and string.sub(text,1,20)=="BLFG312~GUILDREMOVE" then
    local who, guild = text:match("^BLFG312~GUILDREMOVE~([^~]*)~(.*)$")
    if who == "Hsoj" and guild and guild ~= "" then self:RemoveGuildListingByName(guild, false) end
    return
  end
  if BLFG_567_OldHandleMessage then return BLFG_567_OldHandleMessage(self,text) end
end

BLFG_567_OldShowGuildMenu = BLFG.ShowGuildMenu
function BLFG:ShowGuildMenu(anchor, g)
  if not BLFG_567_PlayerIsAdmin() then
    if BLFG_567_OldShowGuildMenu then return BLFG_567_OldShowGuildMenu(self, anchor, g) end
    return
  end
  if not g or not g.name then return end
  if not self.guildMenu then self.guildMenu = CreateFrame("Frame", "BronzeLFGGuildMenu", UIParent, "UIDropDownMenuTemplate") end
  local guild=tostring(g.name or "")
  local contact=tostring(g.contact or g.postContact or "")
  UIDropDownMenu_Initialize(self.guildMenu, function()
    local info=UIDropDownMenu_CreateInfo(); info.text=guild; info.isTitle=true; info.notCheckable=true; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Remove This Guild Listing (Admin)"; info.notCheckable=true; info.func=function() BLFG:RemoveGuildListingByName(guild,true); CloseDropDownMenus(); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00BronzeLFG:|r Removed guild listing: "..guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text=contact ~= "" and ("Whisper "..contact) or "Whisper Contact"; info.notCheckable=true; info.disabled=(contact==""); info.func=function() if contact ~= "" then ChatFrame_OpenChat("/w "..contact.." ") end end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Copy Guild Name to Chat"; info.notCheckable=true; info.func=function() ChatFrame_OpenChat(guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Cancel"; info.notCheckable=true; info.func=function() CloseDropDownMenus() end; UIDropDownMenu_AddButton(info)
  end,"MENU")
  ToggleDropDownMenu(1,nil,self.guildMenu,anchor,0,0)
end

BLFG_567_OldNotifyForPublicGroup = BLFG.NotifyForPublicGroup
function BLFG:NotifyForPublicGroup(g)
  if not g or not BronzeLFG_DB or not BronzeLFG_DB.options then return end
  local opts=BronzeLFG_DB.options
  if opts.notifyEnabled == false then return end
  local t=tostring(g.type or "")
  if t == "Guild" then return end
  if t == "Dungeon" and opts.notifyDungeon == false then return end
  if t ~= "Dungeon" then return BLFG_567_OldNotifyForPublicGroup(self,g) end
  local player=tostring(g.player or "someone")
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire Alert:|r New |cffaaaaffDungeon|r - "..tostring(g.activity or "Dungeon").." from "..player)
  if opts.notifySound == true and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
end

BLFG_567_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_567_OldBuildOptions and BLFG_567_OldBuildOptions(self,...)
  if self.optionsPanel and not self.optNotifyDungeon then
    local box = nil
    for _,child in ipairs({self.optionsPanel:GetChildren()}) do if child and child.GetWidth and child:GetWidth() == 820 then box = child end end
    if box then
      if self.optNotifyGuild then self.optNotifyGuild:Hide() end
      local cover=CreateFrame("Frame",nil,box); cover:SetWidth(230); cover:SetHeight(35); cover:SetPoint("TOPLEFT",box,"TOPLEFT",425,-347); cover:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); cover:SetBackdropColor(0,0,0,.92)
      self.optNotifyDungeon=CreateFrame("CheckButton","BLFGOptNotifyDungeon",box,"UICheckButtonTemplate")
      self.optNotifyDungeon:SetPoint("TOPLEFT",box,"TOPLEFT",430,-355)
      _G[self.optNotifyDungeon:GetName().."Text"]:SetText("Dungeon Listings")
      self.optNotifyDungeon:SetChecked((BronzeLFG_DB.options or {}).notifyDungeon ~= false)
      self.optNotifyDungeon:SetScript("OnClick",function() BLFG:SaveOptions(false) end)
    end
  end
  return r
end

BLFG_567_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_567_OldSaveOptions and BLFG_567_OldSaveOptions(self,showFlash)
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  BronzeLFG_DB.options.notifyGuild = false
  if self.optNotifyDungeon then BronzeLFG_DB.options.notifyDungeon = self.optNotifyDungeon:GetChecked() and true or false end
  return r
end

function BLFG:ExpandWhisperTemplate(template, activity)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  local pr=BronzeLFG_DB.profile
  local className=select(1,UnitClass("player")) or ""
  local role=tostring(pr.role or "")
  local ilvl=tostring(pr.itemLevel or "")
  local spec=tostring(pr.roleType or "")
  local posting=tostring(activity or "your posting")
  local name=tostring(UnitName("player") or "")
  local out=tostring(template or "")
  out=out:gsub("%[posting%]",posting):gsub("%[activity%]",posting):gsub("%[ilvl%]",ilvl):gsub("%[item level%]",ilvl):gsub("%[spec%]",spec):gsub("%[class%]",className):gsub("%[role%]",role):gsub("%[name%]",name)
  return out
end
function BLFG:BuildProfileWhisper(activity)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  local pr=BronzeLFG_DB.profile
  local template=pr.whisperTemplate or "Hi! I applied for your [posting]. I am a [ilvl] [spec] [class] [role]."
  return self:ExpandWhisperTemplate(template, activity)
end

BLFG_567_OldBuildProfile = BLFG.BuildProfile
function BLFG:BuildProfile(...)
  local r = BLFG_567_OldBuildProfile and BLFG_567_OldBuildProfile(self,...)
  if false and self.profile and not self.profileWhisperTemplate then
    BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
    local box = self.profile
    local label=box:CreateFontString(nil,"OVERLAY","GameFontNormal"); label:SetText("Whisper Template"); label:SetPoint("TOPLEFT",box,"TOPLEFT",405,-82)
    self.profileWhisperTemplate = CreateFrame("EditBox",nil,box)
    self.profileWhisperTemplate:SetFontObject(ChatFontNormal); self.profileWhisperTemplate:SetAutoFocus(false); self.profileWhisperTemplate:SetMultiLine(true); self.profileWhisperTemplate:SetWidth(340); self.profileWhisperTemplate:SetHeight(74); self.profileWhisperTemplate:SetPoint("TOPLEFT",box,"TOPLEFT",405,-105); self.profileWhisperTemplate:SetText(BronzeLFG_DB.profile.whisperTemplate or "Hi! I applied for your [posting]. I am a [ilvl] [spec] [class] [role].")
    self.profileWhisperTemplate:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=false, edgeSize=12, insets={left=3,right=3,top=3,bottom=3}}); self.profileWhisperTemplate:SetBackdropColor(.05,.05,.05,.85)
    local vars=box:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); vars:SetText("Variables: [posting] [ilvl] [spec] [class] [role] [name]"); vars:SetPoint("TOPLEFT",self.profileWhisperTemplate,"BOTTOMLEFT",0,-8)
  end
  return r
end
BLFG_567_OldSaveProfile = BLFG.SaveProfile
function BLFG:SaveProfile(...)
  local r = BLFG_567_OldSaveProfile and BLFG_567_OldSaveProfile(self,...)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  if self.profileWhisperTemplate then BronzeLFG_DB.profile.whisperTemplate = self.profileWhisperTemplate:GetText() end
  return r
end

BLFG_567_OldApply = BLFG.Apply
function BLFG:Apply()
  local l = self.listings and self.listings[self.selectedListing]
  if not l then return BLFG_567_OldApply(self) end
  local pr=BronzeLFG_DB.profile or {}; local c,cf=UnitClass("player")
  local a={listingId=l.id,name=UnitName("player"),class=c,classFile=cf,level=UnitLevel("player"),role=pr.role or "DPS",itemLevel=pr.itemLevel or "",roleType=pr.roleType or "",discord=pr.discord and "Yes" or "No",note=pr.note or "",applied=time()}
  if l.leader == UnitName("player") then self.applicants[a.name]=a else BLFG_567_Send("BLFG312~APP~"..tostring(l.id).."~"..tostring(a.name).."~"..tostring(a.class).."~"..tostring(a.classFile).."~"..tostring(a.level).."~"..tostring(a.role).."~"..tostring(a.itemLevel).."~"..tostring(a.roleType).."~"..tostring(a.discord).."~"..tostring(a.note).."~"..tostring(a.applied)); SendChatMessage(self:BuildProfileWhisper(l.activity),"WHISPER",nil,l.leader) end
  if flash then flash("Application sent.") end
end

function BLFG_567_FilterAddonSpam(frame,event,msgText,author,...)
  local s=tostring(msgText or "")
  if s:find("^BLFG%d+") or s:find("^BLFG312~") or s:find("~PING~",1,true) or s:find("~LIST~",1,true) or s:find("~APP~",1,true) then return true end
  return false,msgText,author,...
end
if ChatFrame_AddMessageEventFilter and not BLFG._spamFilter567 then
  BLFG._spamFilter567=true
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", BLFG_567_FilterAddonSpam)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", BLFG_567_FilterAddonSpam)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", BLFG_567_FilterAddonSpam)
end

BLFG_567_OldSlash = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input=BLFG_567_Lower(input or "")
  if input == "commands" or input == "help" then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire commands:|r /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic")
    return
  elseif input == "guildopptest" then
    local raw="â˜  OPPOSITION â˜  [NA/EU] Server 3rd: BWL 7/7/Asc Realm First ZG/ONY/MC Recruiting Melee & HPAL for Main-Raids â€¢ NA Raid Wed/Thur 8PM EST â€¢ discord.gg/opps"
    BLFG:UpsertGuildBrowserChatListing("OPPOSITION", UnitName("player"), raw)
    DEFAULT_CHAT_FRAME:AddMessage(raw .. " " .. (BLFG.GuildChatLink and BLFG:GuildChatLink("OPPOSITION") or "[OPPOSITION]"))
    if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
    return
  end
  if BLFG_567_OldSlash then return BLFG_567_OldSlash(input) end
end



-- ============================================================================
-- BronzeLFG v5.6.8 - Guild moderation fix + safer apply whispers
-- ============================================================================

BLFG.version = "5.6.8"

function BLFG_568_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_568_Trim(s) s=tostring(s or ""); return (s:gsub("^%s+",""):gsub("%s+$","")) end
function BLFG_568_Strip(s)
  s=tostring(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("|H.-|h",""):gsub("|h","")
  return s
end
function BLFG_568_PlayerIsAdmin()
  local n=BLFG_568_Lower(UnitName("player") or "")
  local r=BLFG_568_Lower(GetRealmName() or "")
  return n == "hsoj" and string.find(r, "bronzebeard", 1, true) ~= nil
end
function BLFG_568_GuildNameFromAd(text)
  local s=BLFG_568_Strip(text or "")
  local g=s:match("<([^>]+)>")
  if g and BLFG_568_Trim(g) ~= "" then return BLFG_568_Trim(g) end
  -- Decorated ads: skull OPPOSITION skull [NA/EU]
  g=s:match("^[^%w]*([%u][%u%s%-%_']-)%s*[^%w%s]*%s*%[NA/EU%]")
  if g and BLFG_568_Trim(g) ~= "" then
    g=BLFG_568_Trim(g:gsub("^[%p%s]+",""):gsub("[%p%s]+$",""):gsub("%s+"," "))
    if string.len(g) <= 32 then return g end
  end
  -- Decorated ads without [NA/EU], before Recruiting/Server/Realm/discord.
  g=s:match("^[^%w]*([%u][%u%s%-%_']+)%s+.-[Rr]ecruit") or s:match("^[^%w]*([%u][%u%s%-%_']+)%s+.-[Ss]erver") or s:match("^[^%w]*([%u][%u%s%-%_']+)%s+.-discord")
  if g and BLFG_568_Trim(g) ~= "" then
    g=BLFG_568_Trim(g:gsub("^[%p%s]+",""):gsub("[%p%s]+$",""):gsub("%s+"," "))
    if string.len(g) <= 32 then return g end
  end
  return ""
end
function BLFG_568_IsGuildAd(text)
  local raw=tostring(text or "")
  local l=BLFG_568_Lower(raw)
  if l:find("blfg",1,true) or l:find("~ping~",1,true) then return false end
  local name=BLFG_568_GuildNameFromAd(raw)
  if name == "" then return false end
  if l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) or l:find("realm first",1,true) or l:find("server ",1,true) or l:find("raid",1,true) then return true end
  return false
end

-- Make later/older wrappers use the decorated guild parser too.
BLFG_565_GuildNameFromAd = BLFG_568_GuildNameFromAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_568_IsGuildAd

BLFG_568_OldInline = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw=tostring(msgText or "")
  if raw == "" then return nil end
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return nil end
  if string.find(raw,"bronzelfgpub:",1,true) or string.find(raw,"bronzelfgguild:",1,true) then return nil end
  if BLFG_568_IsGuildAd(raw) then
    local guildName=BLFG_568_GuildNameFromAd(raw)
    if guildName ~= "" then
      if self.UpsertGuildBrowserChatListing then self:UpsertGuildBrowserChatListing(guildName, author, raw) end
      if self.AddPublicGroup then pcall(function() self:AddPublicGroup(author, raw, channelName or "Public") end) end
      local link=self.GuildChatLink and self:GuildChatLink(guildName) or nil
      if link then return raw .. " " .. link end
    end
  end
  if BLFG_568_OldInline then return BLFG_568_OldInline(self,msgText,author,channelName) end
  return nil
end

-- Fix admin test for realm names like "Bronzebeard - Warcraft Reborn" and make removal visible in the detail pane too.
function BLFG_567_PlayerIsAdmin() return BLFG_568_PlayerIsAdmin() end

BLFG_568_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g, ...)
  local r = BLFG_568_OldRefreshGuildDetailPanel and BLFG_568_OldRefreshGuildDetailPanel(self,g,...)
  local d=self.guildDetailPanel
  if not d then return r end
  if BLFG_568_PlayerIsAdmin() then
    if not d.adminRemove then
      d.adminRemove = button(d, "Admin Remove", 104, 24)
      d.adminRemove:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -12, 40)
    end
    if g and g.name then
      d.adminRemove:Show()
      d.adminRemove:SetScript("OnClick", function() BLFG:RemoveGuildListingByName(tostring(g.name or ""), true); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00BronzeLFG:|r Removed guild listing: "..tostring(g.name or "")) end)
    else
      d.adminRemove:Hide()
    end
  elseif d.adminRemove then
    d.adminRemove:Hide()
  end
  return r
end

BLFG_568_OldShowGuildMenu = BLFG.ShowGuildMenu
function BLFG:ShowGuildMenu(anchor, g)
  if not BLFG_568_PlayerIsAdmin() then
    if BLFG_568_OldShowGuildMenu then return BLFG_568_OldShowGuildMenu(self, anchor, g) end
    return
  end
  if not g or not g.name then return end
  if not self.guildMenu then self.guildMenu = CreateFrame("Frame", "BronzeLFGGuildMenu", UIParent, "UIDropDownMenuTemplate") end
  local guild=tostring(g.name or "")
  local contact=tostring(g.contact or g.postContact or "")
  UIDropDownMenu_Initialize(self.guildMenu, function()
    local info=UIDropDownMenu_CreateInfo(); info.text=guild; info.isTitle=true; info.notCheckable=true; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Admin Remove This Guild Listing"; info.notCheckable=true; info.func=function() BLFG:RemoveGuildListingByName(guild,true); CloseDropDownMenus(); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00BronzeLFG:|r Removed guild listing: "..guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text=contact ~= "" and ("Whisper "..contact) or "Whisper Contact"; info.notCheckable=true; info.disabled=(contact==""); info.func=function() if contact ~= "" then ChatFrame_OpenChat("/w "..contact.." ") end end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Copy Guild Name to Chat"; info.notCheckable=true; info.func=function() ChatFrame_OpenChat(guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Cancel"; info.notCheckable=true; info.func=function() CloseDropDownMenus() end; UIDropDownMenu_AddButton(info)
  end,"MENU")
  ToggleDropDownMenu(1,nil,self.guildMenu,anchor,0,0)
end

-- Guild alerts are gone. Dungeon alerts are separate from keystone alerts.
BLFG_568_OldNotifyForPublicGroup = BLFG.NotifyForPublicGroup
function BLFG:NotifyForPublicGroup(g)
  if not g or not BronzeLFG_DB or not BronzeLFG_DB.options then return end
  local opts=BronzeLFG_DB.options
  if opts.notifyEnabled == false then return end
  local t=tostring(g.type or "")
  if t == "Guild" then return end
  if t == "Dungeon" then
    if opts.notifyDungeon == false then return end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire Alert:|r New |cffaaaaffDungeon|r - "..tostring(g.activity or "Dungeon").." from "..tostring(g.player or "someone"))
    if opts.notifySound == true and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
    return
  end
  if BLFG_568_OldNotifyForPublicGroup then return BLFG_568_OldNotifyForPublicGroup(self,g) end
end

-- Remove the ugly 5.6.7 whisper-template box if it exists. Keep application whispers manual/draft-based.
BLFG_568_OldBuildProfile = BLFG.BuildProfile
function BLFG:BuildProfile(...)
  local r = BLFG_568_OldBuildProfile and BLFG_568_OldBuildProfile(self,...)
  if self.profileWhisperTemplate then self.profileWhisperTemplate:Hide() end
  return r
end

function BLFG:BuildProfileWhisper(activity)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  local pr=BronzeLFG_DB.profile
  local className=select(1,UnitClass("player")) or ""
  local role=tostring(pr.role or "")
  local ilvl=tostring(pr.itemLevel or "")
  local spec=tostring(pr.roleType or "")
  local posting=tostring(activity or "your posting")
  local name=tostring(UnitName("player") or "")
  return "Hi! I applied for your "..posting..". I am a "..ilvl.." "..spec.." "..className.." "..role.."."
end

function BLFG:SetApplicantAlert(active)
  self.newApplicantAlert = active and true or false
  if not active then
    if self.applicantsButton then
      self.applicantsButton:SetBackdropColor(0,0,0,.82)
      self.applicantsButton:SetBackdropBorderColor(.85,.62,.12,.95)
    end
    if self.applicantsButtonTitle then self.applicantsButtonTitle:SetTextColor(1, .92, .68) end
    if self.mm then self.mm:SetAlpha(1) end
    if self.mm and self.mm.icon then self.mm.icon:SetVertexColor(1,1,1,1) end
    if self.mm and self.mm.border then self.mm.border:SetVertexColor(1,1,1,1) end
  end
end

-- Applying should submit the addon application only. Whispering is up to the player.
function BLFG:Apply()
  local l = self.listings and self.listings[self.selectedListing]
  if not l then return end
  local pr=BronzeLFG_DB.profile or {}; local c,cf=UnitClass("player")
  local a={listingId=l.id,name=UnitName("player"),class=c,classFile=cf,level=UnitLevel("player"),role=pr.role or "DPS",itemLevel=pr.itemLevel or "",roleType=pr.roleType or "",discord=pr.discord and "Yes" or "No",note=pr.note or "",applied=time()}
  if l.leader == UnitName("player") then
    self.applicants[a.name]=a
    if self.SetApplicantAlert then self:SetApplicantAlert(true) else self.newApplicantAlert = true end
    if self.RefreshApplicants then self:RefreshApplicants() end
    if flash then flash("New applicant: "..tostring(a.name)) end
  else
    BLFG_567_Send("BLFG312~APP~"..tostring(l.id).."~"..tostring(a.name).."~"..tostring(a.class).."~"..tostring(a.classFile).."~"..tostring(a.level).."~"..tostring(a.role).."~"..tostring(a.itemLevel).."~"..tostring(a.roleType).."~"..tostring(a.discord).."~"..tostring(a.note).."~"..tostring(a.applied))
    if flash then flash("Application sent. Use Whisper if you want to send a personal message.") end
  end
end

function BLFG:WhisperPublicSelected()
  local g = self.publicGroups and self.publicGroups[self.selectedPublic]
  if not g or not g.player then if flash then flash("Select a public group first.") end; return end
  local msg=self:BuildProfileWhisper(g.activity or g.message or "your posting")
  ChatFrame_OpenChat("/w "..tostring(g.player):gsub("%-.*","").." "..msg)
end

BLFG_568_OldSlash = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input=BLFG_568_Lower(input or "")
  if input == "guildopptest" then
    local raw="â˜  OPPOSITION â˜  [NA/EU] Server 3rd: BWL 7/7/Asc Realm First ZG/ONY/MC Recruiting Melee & HPAL for Main-Raids â€¢ NA Raid Wed/Thur 8PM EST â€¢ discord.gg/opps"
    local g=BLFG_568_GuildNameFromAd(raw)
    if BLFG.UpsertGuildBrowserChatListing then BLFG:UpsertGuildBrowserChatListing(g, UnitName("player"), raw) end
    DEFAULT_CHAT_FRAME:AddMessage(raw .. " " .. (BLFG.GuildChatLink and BLFG:GuildChatLink(g) or "[OPPOSITION]"))
    if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
    return
  elseif input == "admintest" then
    DEFAULT_CHAT_FRAME:AddMessage("SignalFire admin: "..tostring(BLFG_568_PlayerIsAdmin()).." player="..tostring(UnitName("player")).." realm="..tostring(GetRealmName()))
    return
  end
  if BLFG_568_OldSlash then return BLFG_568_OldSlash(input) end
end

-- ============================================================================
-- BronzeLFG v5.6.9 - OPPOSITION links, admin right-click only, templates, alerts
-- ============================================================================
BLFG.version = "5.6.9"

function BLFG_569_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_569_Trim(s) s=tostring(s or ""); return (s:gsub("^%s+",""):gsub("%s+$","")) end
function BLFG_569_Strip(s)
  s=tostring(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("|H.-|h",""):gsub("|h","")
  return s
end
function BLFG_569_NormalizeName(s)
  s=BLFG_569_Strip(s or "")
  s=s:gsub("[^%w%s%-_']", " ")
  s=s:gsub("%s+", " ")
  return BLFG_569_Lower(BLFG_569_Trim(s))
end
function BLFG_569_PlayerIsAdmin()
  local n=BLFG_569_Lower(UnitName("player") or "")
  local r=BLFG_569_Lower(GetRealmName() or "")
  return n == "hsoj" and string.find(r, "bronzebeard", 1, true) ~= nil
end
function BLFG_569_ChannelId()
  local id = GetChannelName and GetChannelName("BLFG")
  if id and id > 0 then return id end
  return nil
end
function BLFG_569_Send(payload)
  local id = BLFG_569_ChannelId()
  if id then SendChatMessage(payload, "CHANNEL", nil, id) end
end
function BLFG_569_CleanCandidateName(s)
  s=BLFG_569_Strip(s or "")
  s=s:gsub("[^A-Za-z0-9%s%-_']", " ")
  s=s:gsub("%s+", " ")
  s=BLFG_569_Trim(s)
  -- Prefer the last all-caps word/phrase in decorated preambles such as "skull OPPOSITION skull".
  local best=nil
  for token in string.gmatch(s, "[%u][%u0-9%-%_']+") do best=token end
  if best and best ~= "NA" and best ~= "EU" then return best end
  return s
end
function BLFG_569_GuildNameFromAd(text)
  local s=BLFG_569_Strip(text or "")
  local g=s:match("<([^>]+)>")
  if g and BLFG_569_Trim(g) ~= "" then return BLFG_569_Trim(g) end
  -- Strong decorated pattern: everything before [NA/EU]. This catches OPPOSITION with skulls/colors.
  local pre=s:match("^(.-)%s*%[NA/EU%]")
  if pre and pre ~= "" then
    g=BLFG_569_CleanCandidateName(pre)
    if g and g ~= "" and string.len(g) <= 32 then return g end
  end
  -- Fallback: first decorated all-caps phrase before recruitment/server/discord language.
  pre=s:match("^(.-)[Rr]ecruit") or s:match("^(.-)[Ss]erver") or s:match("^(.-)[Rr]ealm") or s:match("^(.-)discord")
  if pre and pre ~= "" then
    g=BLFG_569_CleanCandidateName(pre)
    if g and g ~= "" and string.len(g) <= 32 then return g end
  end
  return ""
end
function BLFG_569_IsGuildAd(text)
  local raw=tostring(text or "")
  local l=BLFG_569_Lower(raw)
  if l:find("blfg",1,true) or l:find("~ping~",1,true) then return false end
  local name=BLFG_569_GuildNameFromAd(raw)
  if not name or name == "" then return false end
  if l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) or l:find("realm first",1,true) or l:find("server ",1,true) or l:find("raid",1,true) then return true end
  return false
end
function BLFG_569_IsKeystoneText(text)
  local l=BLFG_569_Lower(text)
  return l:find("mythic%+") or l:find("m%+") or l:find("keystone",1,true) or l:find(" key",1,true) or l:find("+%d")
end
function BLFG_569_IsDungeonText(text)
  local l=BLFG_569_Lower(text)
  if BLFG_569_IsKeystoneText(text) then return false end
  if l:find("dire maul",1,true) or l:find(" dm ",1,true) or l:find(" dm east",1,true) or l:find("dm east",1,true) or l:find("maraudon",1,true) or l:find("strath",1,true) or l:find("scholo",1,true) or l:find("brd",1,true) or l:find("blackrock depths",1,true) or l:find("sunken temple",1,true) or l:find("uldaman",1,true) or l:find("scarlet monastery",1,true) or l:find("deadmines",1,true) then return true end
  return false
end

BLFG_567_PlayerIsAdmin = BLFG_569_PlayerIsAdmin
BLFG_568_PlayerIsAdmin = BLFG_569_PlayerIsAdmin
BLFG_565_GuildNameFromAd = BLFG_569_GuildNameFromAd
BLFG_567_GuildNameFromAd = BLFG_569_GuildNameFromAd
BLFG_568_GuildNameFromAd = BLFG_569_GuildNameFromAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_569_IsGuildAd

-- Rebuild guild chat listings with stable normalized keys.
function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
  guildName = BLFG_569_Trim(guildName or "")
  if guildName == "" then return end
  BronzeLFG_DB.chatGuildListings = BronzeLFG_DB.chatGuildListings or {}
  self.chatGuildListings = self.chatGuildListings or BronzeLFG_DB.chatGuildListings
  local key = BLFG_569_NormalizeName(guildName)
  local row = self.chatGuildListings[key] or BronzeLFG_DB.chatGuildListings[key] or {}
  row.name = guildName; row.guild = guildName; row.status = "Chat Only"; row.source = "Chat"
  row.online = tonumber(row.online or 0) or 0
  row.posts = (tonumber(row.posts or 0) or 0) + 1
  row.contact = tostring(author or row.contact or ""):gsub("%-.*","")
  row.postContact = row.contact
  row.lastPost = tostring(text or row.lastPost or "")
  row.message = row.lastPost
  row.lastPostSeen = time(); row.lastPostTime = "now"
  row.recruiting = "Recruiting"; row.postKind = "Recruiting"
  row.focus = self.GetRawFocusTags and self:GetRawFocusTags("", row.lastPost) or row.focus or "Unknown"
  if row.focus == "" then row.focus = "Unknown" end
  row.focusText = row.focus; row.postFocus = row.focus; row.focusRaw = row.focus
  row.discord = BLFG_ExtractDiscord and BLFG_ExtractDiscord(row.lastPost) or row.discord or ""
  row.chatOnly = true
  self.chatGuildListings[key] = row; BronzeLFG_DB.chatGuildListings[key] = row
end

BLFG_569_OldInline = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw=tostring(msgText or "")
  if raw == "" then return nil end
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return nil end
  if raw:find("bronzelfgpub:",1,true) or raw:find("bronzelfgguild:",1,true) then return nil end
  if BLFG_569_IsGuildAd(raw) then
    local guildName=BLFG_569_GuildNameFromAd(raw)
    if guildName and guildName ~= "" then
      self:UpsertGuildBrowserChatListing(guildName, author, raw)
      local link = self.GuildChatLink and self:GuildChatLink(guildName) or nil
      if link then return raw .. " " .. link end
      return raw .. " [" .. guildName .. "]"
    end
  end
  if BLFG_569_OldInline then return BLFG_569_OldInline(self,msgText,author,channelName) end
  return nil
end

-- Remove guild listings by normalized guild name OR by the selected row's stored message/name.
function BLFG:RemoveGuildListingByName(guildName, broadcast)
  if not BLFG_569_PlayerIsAdmin() and broadcast == true then return end
  guildName = BLFG_569_Trim(guildName or "")
  if guildName == "" then return end
  local target = BLFG_569_NormalizeName(guildName)
  self.chatGuildListings = self.chatGuildListings or BronzeLFG_DB.chatGuildListings or {}
  local function matchesRow(g)
    if not g then return false end
    local n1=BLFG_569_NormalizeName(g.name or g.guild or g.guildName or "")
    local n2=BLFG_569_NormalizeName(BLFG_569_GuildNameFromAd(g.message or g.lastPost or ""))
    return n1 == target or n2 == target or (target ~= "" and n1:find(target,1,true)) or (target ~= "" and n2:find(target,1,true))
  end
  for k,g in pairs(self.chatGuildListings or {}) do if matchesRow(g) or BLFG_569_NormalizeName(k) == target then self.chatGuildListings[k]=nil end end
  if BronzeLFG_DB.chatGuildListings then for k,g in pairs(BronzeLFG_DB.chatGuildListings) do if matchesRow(g) or BLFG_569_NormalizeName(k) == target then BronzeLFG_DB.chatGuildListings[k]=nil end end end
  for id,g in pairs(self.publicGroups or {}) do if matchesRow(g) or (g.type == "Guild" and BLFG_569_NormalizeName(g.activity) == target) then self.publicGroups[id]=nil end end
  if self.selectedGuild and BLFG_569_NormalizeName(self.selectedGuild) == target then self.selectedGuild=nil end
  if broadcast == true and BLFG_569_PlayerIsAdmin() then BLFG_569_Send("BLFG312~GUILDREMOVE~Hsoj~" .. guildName) end
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

-- No visible admin button. Moderation lives only on right-click and only for Hsoj.
BLFG_569_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g,...)
  local r = BLFG_569_OldRefreshGuildDetailPanel and BLFG_569_OldRefreshGuildDetailPanel(self,g,...)
  local d=self.guildDetailPanel
  if d and d.adminRemove then d.adminRemove:Hide(); d.adminRemove:SetScript("OnClick", nil) end
  return r
end

BLFG_569_OldShowGuildMenu = BLFG.ShowGuildMenu
function BLFG:ShowGuildMenu(anchor, g)
  if not BLFG_569_PlayerIsAdmin() then
    if BLFG_569_OldShowGuildMenu then return BLFG_569_OldShowGuildMenu(self, anchor, g) end
    return
  end
  if not g then return end
  local guild=tostring(g.name or g.guild or g.guildName or BLFG_569_GuildNameFromAd(g.message or g.lastPost or "") or "")
  if guild == "" then return end
  local contact=tostring(g.contact or g.postContact or "")
  if not self.guildMenu then self.guildMenu = CreateFrame("Frame", "BronzeLFGGuildMenu", UIParent, "UIDropDownMenuTemplate") end
  UIDropDownMenu_Initialize(self.guildMenu, function()
    local info=UIDropDownMenu_CreateInfo(); info.text=guild; info.isTitle=true; info.notCheckable=true; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Remove This Guild Listing"; info.notCheckable=true; info.func=function() BLFG:RemoveGuildListingByName(guild,true); CloseDropDownMenus(); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00BronzeLFG:|r Removed guild listing: "..guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text=contact ~= "" and ("Whisper "..contact) or "Whisper Contact"; info.notCheckable=true; info.disabled=(contact==""); info.func=function() if contact ~= "" then ChatFrame_OpenChat("/w "..contact.." ") end end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Cancel"; info.notCheckable=true; info.func=function() CloseDropDownMenus() end; UIDropDownMenu_AddButton(info)
  end,"MENU")
  ToggleDropDownMenu(1,nil,self.guildMenu,anchor,0,0)
end

-- Alerts: guild never alerts; dungeon is separate from keystone; cache prevents duplicates.
function BLFG:NotifyForPublicGroup(g)
  if not g or not BronzeLFG_DB or not BronzeLFG_DB.options then return end
  local opts=BronzeLFG_DB.options
  if opts.notifyEnabled == false then return end
  local t=tostring(g.type or "")
  local text=BLFG_569_Lower(tostring(g.message or "") .. " " .. tostring(g.activity or "") .. " " .. tostring(g.tags or ""))
  if t == "Guild" then return end
  if BLFG_569_IsDungeonText(text) then t="Dungeon" end
  if BLFG_569_IsKeystoneText(text) then t="Key" end
  if (text:find("hcbb",1,true) or text:find("boss blitz",1,true) or text:find("bbhc",1,true)) and t ~= "Dungeon" and t ~= "Key" then t="Event" end
  local should=false
  if t == "Dungeon" and opts.notifyDungeon ~= false then should=true end
  if t == "Key" and opts.notifyKey ~= false then should=true end
  if t == "Raid" and opts.notifyRaid ~= false then should=true end
  if t == "Event" and opts.notifyHCBB ~= false then should=true end
  if not should then return end
  local sig=tostring(g.player or "").."|"..tostring(g.message or g.activity or "").."|"..t
  self._notifySeen569 = self._notifySeen569 or {}
  if self._notifySeen569[sig] and (time() - self._notifySeen569[sig] < 20) then return end
  self._notifySeen569[sig]=time()
  local player=tostring(g.player or "someone")
  local activity=tostring(g.activity or t or "listing")
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire Alert:|r New " .. (publicTypeColor and publicTypeColor(t) or "") .. t .. "|r - " .. activity .. " from " .. player)
  if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage("SignalFire Alert: New "..activity.." from "..player, 1, .82, 0, 1, 5) end
  if opts.notifySound == true and PlaySoundFile then PlaySoundFile("Sound\\Interface\\RaidWarning.wav") end
end

BLFG_569_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw=tostring(text or "")
  local beforeNewest = self.FindNewestPublicByAuthor and self:FindNewestPublicByAuthor(author) or nil
  local r = BLFG_569_OldAddPublicGroup and BLFG_569_OldAddPublicGroup(self, author, text, channelName)
  if BLFG_569_IsGuildAd(raw) then
    local gn=BLFG_569_GuildNameFromAd(raw)
    if gn ~= "" then self:UpsertGuildBrowserChatListing(gn, author, raw) end
    if self.guildPanel and self.guildPanel:IsVisible() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
    return r
  end
  local newest = self.FindNewestPublicByAuthor and self:FindNewestPublicByAuthor(author) or nil
  if newest and raw ~= "" and tostring(newest.message or "") ~= "" then
    if BLFG_569_IsDungeonText(raw) then newest.type="Dungeon"; if not newest.activity or newest.activity=="General Listing" or newest.activity=="Looking For Group" then newest.activity="General Dungeon" end end
    if BLFG_569_IsKeystoneText(raw) then newest.type="Key" end
    self:NotifyForPublicGroup(newest)
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  end
  return r
end

-- Profile whisper template UI, clean and saved. It is for Public Groups only; Guild Browser uses normal whispers.
BLFG_569_OldBuildProfile = BLFG.BuildProfile
function BLFG:BuildProfile(...)
  local r=BLFG_569_OldBuildProfile and BLFG_569_OldBuildProfile(self,...)
  if not self.profile then return r end
  local box = self.profile:GetChildren()
  local pr=BronzeLFG_DB.profile or {}
  local parent = box or self.profile
  if not self.profileWhisperTemplate569 then
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.profileWhisperTemplateLabel569=label
    label:SetText("Whisper Template"); label:SetTextColor(1,.82,0); label:SetPoint("TOPLEFT",parent,"TOPLEFT",405,-82)
    local e=CreateFrame("EditBox",nil,parent)
    self.profileWhisperTemplate569=e
    e:SetWidth(340); e:SetHeight(70); e:SetAutoFocus(false); e:SetMultiLine(true); e:SetFontObject(ChatFontNormal); e:SetTextInsets(6,6,6,6)
    e:SetPoint("TOPLEFT",parent,"TOPLEFT",405,-105)
    e:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=3,right=3,top=3,bottom=3}})
    e:SetBackdropColor(0,0,0,.95)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); BLFG:SaveProfile() end)
    local vars=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.profileWhisperVars569=vars
    vars:SetText("Variables: [posting] [ilvl] [spec] [class] [role] [name]"); vars:SetPoint("TOPLEFT",e,"BOTTOMLEFT",0,-8)
    vars:SetTextColor(.7,.7,.7)
    local prevLbl=parent:CreateFontString(nil,"OVERLAY","GameFontNormal"); self.profileWhisperPreviewLabel569=prevLbl
    prevLbl:SetText("Preview:"); prevLbl:SetTextColor(1,.82,0); prevLbl:SetPoint("TOPLEFT",vars,"BOTTOMLEFT",0,-20)
    local prev=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); self.profileWhisperPreview569=prev
    prev:SetWidth(340); prev:SetJustifyH("LEFT"); prev:SetPoint("TOPLEFT",prevLbl,"BOTTOMLEFT",0,-8); prev:SetTextColor(.55,.8,1)
    e:SetScript("OnTextChanged", function() if BLFG.UpdateWhisperPreview569 then BLFG:UpdateWhisperPreview569() end end)
  end
  self.profileWhisperTemplate569:SetText(pr.whisperTemplate or "Hi! I applied for your [posting]. I am a [ilvl] [spec] [class] [role].")
  self.profileWhisperTemplate569:Show()
  if self.profileWhisperTemplateLabel569 then self.profileWhisperTemplateLabel569:Show() end
  if self.profileWhisperVars569 then self.profileWhisperVars569:Show() end
  if self.profileWhisperPreviewLabel569 then self.profileWhisperPreviewLabel569:Show() end
  if self.profileWhisperPreview569 then self.profileWhisperPreview569:Show() end
  if self.profileRoleType and not self.profileRoleType._sfPreviewHook569 then
    self.profileRoleType._sfPreviewHook569 = true
    self.profileRoleType:SetScript("OnTextChanged", function() if BLFG.UpdateWhisperPreview569 then BLFG:UpdateWhisperPreview569() end end)
  end
  if self.profileRole and not self.profileRole._sfPreviewHook569 then
    self.profileRole._sfPreviewHook569 = true
    UIDropDownMenu_Initialize(self.profileRole, function()
      for _, v in ipairs(ROLES) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = v
        info.func = function()
          UIDropDownMenu_SetText(BLFG.profileRole, v)
          if BLFG.UpdateWhisperPreview569 then BLFG:UpdateWhisperPreview569() end
        end
        UIDropDownMenu_AddButton(info)
      end
    end)
  end
  self:UpdateWhisperPreview569()
  return r
end
function BLFG:UpdateWhisperPreview569()
  if not self.profileWhisperPreview569 then return end
  self.profileWhisperPreview569:SetText(self:BuildProfileWhisper("Shadowfang Keep - Need H"))
end

BLFG_569_OldSaveProfile = BLFG.SaveProfile
function BLFG:SaveProfile(...)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  if BLFG_569_OldSaveProfile then BLFG_569_OldSaveProfile(self,...) end
  if self.profileWhisperTemplate569 then BronzeLFG_DB.profile.whisperTemplate = self.profileWhisperTemplate569:GetText() end
end
function BLFG:BuildProfileWhisper(activity)
  BronzeLFG_DB.profile = BronzeLFG_DB.profile or {}
  local pr=BronzeLFG_DB.profile
  local tmpl=tostring((self.profileWhisperTemplate569 and self.profileWhisperTemplate569:GetText()) or pr.whisperTemplate or "Hi! I applied for your [posting]. I am a [ilvl] [spec] [class] [role].")
  local className=select(1,UnitClass("player")) or ""
  local liveRole = (self.profileRole and BLFG_DropdownText(self.profileRole)) or pr.role or ""
  local liveIlvl = (self.profileIlvl and self.profileIlvl.GetText and self.profileIlvl:GetText()) or pr.itemLevel or ""
  local liveSpec = (self.profileRoleType and self.profileRoleType.GetText and self.profileRoleType:GetText()) or pr.roleType or ""
  local vals={posting=tostring(activity or "your posting"), ilvl=tostring(liveIlvl or ""), spec=tostring(liveSpec or ""), class=tostring(className or ""), role=tostring(liveRole or ""), name=tostring(UnitName("player") or "")}
  tmpl=tmpl:gsub("%[posting%]", vals.posting):gsub("%[ilvl%]", vals.ilvl):gsub("%[spec%]", vals.spec):gsub("%[class%]", vals.class):gsub("%[role%]", vals.role):gsub("%[name%]", vals.name)
  tmpl=tmpl:gsub("%s+", " ")
  return BLFG_569_Trim(tmpl)
end
function BLFG:WhisperPublicSelected()
  local g = self.publicGroups and self.publicGroups[self.selectedPublic]
  if not g or not g.player then if flash then flash("Select a public group first.") end; return end
  local msg=self:BuildProfileWhisper(g.activity or g.message or "your posting")
  ChatFrame_OpenChat("/w "..tostring(g.player):gsub("%-.*","").." "..msg)
end

BLFG_569_OldHandleMessage = BLFG.HandleMessage
function BLFG:HandleMessage(text)
  if type(text)=="string" and string.sub(text,1,20)=="BLFG312~GUILDREMOVE" then
    local who,guild = text:match("^BLFG312~GUILDREMOVE~([^~]*)~(.*)$")
    if who == "Hsoj" and guild and guild ~= "" then self:RemoveGuildListingByName(guild,false) end
    return
  end
  if BLFG_569_OldHandleMessage then return BLFG_569_OldHandleMessage(self,text) end
end

BLFG_569_OldSlash = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input=BLFG_569_Lower(input or "")
  if input == "guildopptest" then
    local raw="â˜  OPPOSITION â˜  [NA/EU] â€¢ Server 3rd: BWL 7/7/Asc â€¢ Realm First: ZG/ONY/MC(Asc) â€¢ Recruiting Melee & HPAL for Main-Raids â€¢ discord.gg/opps"
    local g=BLFG_569_GuildNameFromAd(raw)
    BLFG:UpsertGuildBrowserChatListing(g, UnitName("player"), raw)
    DEFAULT_CHAT_FRAME:AddMessage(raw .. " " .. (BLFG.GuildChatLink and BLFG:GuildChatLink(g) or ("["..g.."]")))
    if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
    return
  elseif input == "admintest" then
    DEFAULT_CHAT_FRAME:AddMessage("SignalFire admin: "..tostring(BLFG_569_PlayerIsAdmin()).." player="..tostring(UnitName("player")).." realm="..tostring(GetRealmName()))
    return
  elseif input == "alerttest" then
    BLFG:NotifyForPublicGroup({type="Dungeon", activity="Dire Maul East", player="Test", message="LFM TANK DM EAST HC BB"})
    return
  end
  if BLFG_569_OldSlash then return BLFG_569_OldSlash(input) end
end


-- ============================================================================
-- v5.6.10 Ghost Addon Broadcast Revert / Hard Filter
-- Stops leaked addon protocol messages from becoming Public Groups again.
-- ============================================================================

function BronzeLFG_IsAddonSpam(text)
  local s = tostring(text or "")
  local ls = string.lower(s)

  -- BronzeLFG / other LFG addon protocol payloads showing in public channels.
  if string.find(s, "^BLFG%d+") then return true end
  if string.find(s, "^BLFG312~") then return true end
  if string.find(s, "~PING~", 1, true) then return true end
  if string.find(s, "~LIST~", 1, true) then return true end
  if string.find(s, "~APP~", 1, true) then return true end
  if string.find(s, "~GUILDREMOVE~", 1, true) then return true end
  if string.find(ls, "blfg") and string.find(s, "~", 1, true) then return true end

  -- Lib/channel chatter style junk.
  if string.sub(s, 1, 3) == "LC1" then return true end
  if string.sub(s, 1, 3) == "LC2" then return true end
  if string.sub(s, 1, 3) == "LC3" then return true end
  if string.find(ls, "lc1:conf", 1, true) then return true end
  if string.find(ls, "lc2:conf", 1, true) then return true end
  if string.find(ls, "lc3:conf", 1, true) then return true end
  if string.find(ls, "conf:", 1, true) then return true end

  -- Generic packed protocol line, but avoid normal chat with punctuation.
  if string.find(s, "^%u%u%d*:") then return true end
  if string.find(s, "^LC") and string.len(s) > 20 then return true end
  local hasSpace = string.find(s, " ", 1, true)
  if not hasSpace and string.len(s) > 35 then return true end

  return false
end

function BLFG_5610_PurgeGhostPublicGroups()
  if not BLFG or not BLFG.publicGroups then return end
  for k,g in pairs(BLFG.publicGroups) do
    local msg = g and tostring(g.message or g.activity or "") or ""
    if BronzeLFG_IsAddonSpam(msg) then
      BLFG.publicGroups[k] = nil
    end
  end
end

BLFG_5610_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(text) then return nil end
  return BLFG_5610_OldAddPublicGroup and BLFG_5610_OldAddPublicGroup(self, author, text, channelName)
end

BLFG_5610_OldInlinePublicChatLinkForMessage = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(msgText) then return nil end
  return BLFG_5610_OldInlinePublicChatLinkForMessage and BLFG_5610_OldInlinePublicChatLinkForMessage(self, msgText, author, channelName)
end

BLFG_5610_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  BLFG_5610_PurgeGhostPublicGroups()
  return BLFG_5610_OldRefreshPublicGroups and BLFG_5610_OldRefreshPublicGroups(self, ...)
end

function BLFG_5610_HideAddonBroadcasts(frame,event,msgText,author,...)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(msgText) then return true end
  return false,msgText,author,...
end
if ChatFrame_AddMessageEventFilter and not BLFG._ghostBroadcastFilter5610 then
  BLFG._ghostBroadcastFilter5610 = true
  ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", BLFG_5610_HideAddonBroadcasts)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", BLFG_5610_HideAddonBroadcasts)
  ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", BLFG_5610_HideAddonBroadcasts)
end

BLFG_5610_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  local r = BLFG_5610_OldOnEnable and BLFG_5610_OldOnEnable(self, ...)
  BLFG_5610_PurgeGhostPublicGroups()
  return r
end

BLFG_5610_OldSlash = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input = string.lower(tostring(input or ""))
  if input == "purgeghosts" or input == "cleanghosts" then
    BLFG_5610_PurgeGhostPublicGroups()
    if BLFG and BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire:|r ghost addon broadcasts removed from Public Groups.")
    return
  end
  if BLFG_5610_OldSlash then return BLFG_5610_OldSlash(input) end
end


-- ============================================================================
-- v5.6.11 Consolidated Guild Suppression + Dungeon Alert Dropdown
-- ============================================================================
BLFG.version = "5.6.11"

BLFG_5611_DUNGEON_OPTIONS = {
  "Any Dungeon",
  "Ragefire Chasm",
  "Deadmines",
  "Wailing Caverns",
  "Shadowfang Keep",
  "Blackfathom Deeps",
  "The Stockade",
  "Gnomeregan",
  "Razorfen Kraul",
  "Scarlet Monastery",
  "Razorfen Downs",
  "Uldaman",
  "Zul'Farrak",
  "Maraudon",
  "Sunken Temple",
  "Blackrock Depths",
  "Dire Maul",
  "Lower Blackrock Spire",
  "Upper Blackrock Spire",
  "Stratholme",
  "Scholomance"
}

BLFG_5611_DUNGEON_ALIASES = {
  ["Ragefire Chasm"] = {"ragefire chasm", "rfc"},
  ["Deadmines"] = {"deadmines", "dmvc", "vc"},
  ["Wailing Caverns"] = {"wailing caverns", "wc"},
  ["Shadowfang Keep"] = {"shadowfang keep", "sfk"},
  ["Blackfathom Deeps"] = {"blackfathom deeps", "bfd"},
  ["The Stockade"] = {"stockade", "stocks"},
  ["Gnomeregan"] = {"gnomeregan", "gnomer"},
  ["Razorfen Kraul"] = {"razorfen kraul", "rfk"},
  ["Scarlet Monastery"] = {"scarlet monastery", " sm ", "sm arm", "sm cath", "sm gy", "sm lib"},
  ["Razorfen Downs"] = {"razorfen downs", "rfd"},
  ["Uldaman"] = {"uldaman", "ulda"},
  ["Zul'Farrak"] = {"zul'farrak", "zulfarrak", "zf"},
  ["Maraudon"] = {"maraudon", "mara"},
  ["Sunken Temple"] = {"sunken temple", "temple of atal", "st"},
  ["Blackrock Depths"] = {"blackrock depths", "brd"},
  ["Dire Maul"] = {"dire maul", "dm east", "dm west", "dm north", " dme", " dmw", " dmn"},
  ["Lower Blackrock Spire"] = {"lower blackrock spire", "lbrs"},
  ["Upper Blackrock Spire"] = {"upper blackrock spire", "ubrs"},
  ["Stratholme"] = {"stratholme", "strat live", "strat dead", "strat ud", "strath"},
  ["Scholomance"] = {"scholomance", "scholo"}
}

function BLFG_5611_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5611_Trim(s) s=tostring(s or ""); return (s:gsub("^%s+",""):gsub("%s+$","")) end
function BLFG_5611_Strip(s)
  s=tostring(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("|H.-|h",""):gsub("|h","")
  return s
end
function BLFG_5611_NormalizeName(s)
  s=BLFG_5611_Strip(s or "")
  s=s:gsub("[^%w%s%-_']", " ")
  s=s:gsub("%s+", " ")
  return BLFG_5611_Lower(BLFG_5611_Trim(s))
end
function BLFG_5611_PlayerIsAdmin()
  return BLFG_5611_Lower(UnitName("player") or "") == "hsoj" and string.find(BLFG_5611_Lower(GetRealmName() or ""), "bronzebeard", 1, true) ~= nil
end
function BLFG_5611_IsGuildSuppressed(name)
  BronzeLFG_DB.suppressedGuilds = BronzeLFG_DB.suppressedGuilds or {}
  local key=BLFG_5611_NormalizeName(name or "")
  return key ~= "" and BronzeLFG_DB.suppressedGuilds[key] == true
end
function BLFG_5611_SetGuildSuppressed(name, value)
  BronzeLFG_DB.suppressedGuilds = BronzeLFG_DB.suppressedGuilds or {}
  local key=BLFG_5611_NormalizeName(name or "")
  if key ~= "" then BronzeLFG_DB.suppressedGuilds[key] = value and true or nil end
end
function BLFG_5611_ChannelId()
  local id = GetChannelName and GetChannelName("BLFG")
  if id and id > 0 then return id end
  return nil
end
function BLFG_5611_Send(payload)
  local id = BLFG_5611_ChannelId()
  if id then SendChatMessage(payload, "CHANNEL", nil, id) end
end
function BLFG_5611_CleanGuildCandidate(s)
  s=BLFG_5611_Strip(s or "")
  s=s:gsub("[^A-Za-z0-9%s%-_']", " ")
  s=s:gsub("%s+", " ")
  s=BLFG_5611_Trim(s)
  local best=nil
  for token in string.gmatch(s, "[%u][%u0-9%-%_']+") do
    if token ~= "NA" and token ~= "EU" and token ~= "LFM" and token ~= "LF" and token ~= "WTS" then best=token end
  end
  if best then return best end
  return s
end
function BLFG_5611_GuildNameFromAd(text)
  local s=BLFG_5611_Strip(text or "")
  local g=s:match("<([^>]+)>")
  if g and BLFG_5611_Trim(g) ~= "" then return BLFG_5611_Trim(g) end
  local pre=s:match("^(.-)%s*%[NA/EU%]") or s:match("^(.-)%s*%[NA%]") or s:match("^(.-)%s*%[EU%]")
  if pre and pre ~= "" then
    g=BLFG_5611_CleanGuildCandidate(pre)
    if g and g ~= "" and string.len(g) <= 32 then return g end
  end
  pre=s:match("^(.-)[Rr]ecruit") or s:match("^(.-)[Ss]erver") or s:match("^(.-)[Rr]ealm") or s:match("^(.-)discord")
  if pre and pre ~= "" then
    g=BLFG_5611_CleanGuildCandidate(pre)
    if g and g ~= "" and string.len(g) <= 32 then return g end
  end
  return ""
end
function BLFG_5611_IsGuildAd(text)
  local raw=tostring(text or "")
  local l=BLFG_5611_Lower(raw)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return false end
  local name=BLFG_5611_GuildNameFromAd(raw)
  if not name or name == "" then return false end
  if l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) or l:find("realm first",1,true) or l:find("server ",1,true) or l:find("raid",1,true) then return true end
  return false
end

-- Make every older wrapper use the newest decorated-guild parser/admin check.
BLFG_565_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_567_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_568_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_569_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_567_PlayerIsAdmin = BLFG_5611_PlayerIsAdmin
BLFG_568_PlayerIsAdmin = BLFG_5611_PlayerIsAdmin
BLFG_569_PlayerIsAdmin = BLFG_5611_PlayerIsAdmin
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5611_IsGuildAd

-- Hard stop for ghost protocol broadcasts before they become rows or alerts.
BLFG_5611_OldIsAddonSpam = BronzeLFG_IsAddonSpam
function BronzeLFG_IsAddonSpam(text)
  local s=tostring(text or "")
  local ls=string.lower(s)
  if string.find(s, "BLFG%d+%s*~") then return true end
  if string.find(s, "BLFG%d+.-~PING~") then return true end
  if string.find(s, "~PING~", 1, true) or string.find(s, "~LIST~", 1, true) or string.find(s, "~APP~", 1, true) or string.find(s, "~GUILDREMOVE~", 1, true) or string.find(s, "~GUILDBLOCK~", 1, true) then return true end
  if string.find(ls, "blfg") and string.find(s, "~", 1, true) then return true end
  if BLFG_5611_OldIsAddonSpam and BLFG_5611_OldIsAddonSpam(text) then return true end
  return false
end

function BLFG_5611_PurgeGhostPublicGroups()
  if not BLFG or not BLFG.publicGroups then return end
  for k,g in pairs(BLFG.publicGroups) do
    local msg = g and tostring(g.message or g.activity or "") or ""
    if BronzeLFG_IsAddonSpam(msg) or BLFG_5611_IsGuildSuppressed(g and (g.guildName or g.activity or "") or "") or BLFG_5611_IsGuildSuppressed(g and BLFG_5611_GuildNameFromAd(msg) or "") then
      BLFG.publicGroups[k] = nil
    end
  end
end

BLFG_5611_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  local rows,a,b,c = BLFG_5611_OldGetGuildRows and BLFG_5611_OldGetGuildRows(self, ...) or {}
  rows = rows or {}
  for i=#rows,1,-1 do
    local g=rows[i]
    if g and BLFG_5611_IsGuildSuppressed(g.name or g.guild or "") then table.remove(rows,i) end
  end
  return rows,a,b,c
end

function BLFG:RemoveGuildListingByName(guildName, broadcast)
  guildName=BLFG_5611_Trim(guildName or "")
  if guildName == "" then return end
  BLFG_5611_SetGuildSuppressed(guildName, true)
  local target=BLFG_5611_NormalizeName(guildName)
  self.chatGuildListings = self.chatGuildListings or BronzeLFG_DB.chatGuildListings or {}
  for k,g in pairs(self.chatGuildListings or {}) do if BLFG_5611_NormalizeName(k) == target or BLFG_5611_NormalizeName(g and (g.name or g.guild or "") or "") == target then self.chatGuildListings[k]=nil end end
  if BronzeLFG_DB.chatGuildListings then for k,g in pairs(BronzeLFG_DB.chatGuildListings) do if BLFG_5611_NormalizeName(k) == target or BLFG_5611_NormalizeName(g and (g.name or g.guild or "") or "") == target then BronzeLFG_DB.chatGuildListings[k]=nil end end end
  for _,source in ipairs({self.guilds or {}, self.bronzeNetGuilds or {}, self.guildBrowserGuilds or {}, self.guildRowsData or {}}) do
    for k,g in pairs(source) do if BLFG_5611_NormalizeName(k) == target or BLFG_5611_NormalizeName(g and (g.name or g.guild or "") or "") == target then source[k]=nil end end
  end
  for id,g in pairs(self.publicGroups or {}) do
    local gn=tostring(g and (g.guildName or BLFG_5611_GuildNameFromAd(g.message or "") or g.activity or "") or "")
    if BLFG_5611_NormalizeName(gn) == target or (g and g.type == "Guild" and BLFG_5611_NormalizeName(g.activity or "") == target) then self.publicGroups[id]=nil end
  end
  if self.selectedGuildData and BLFG_5611_NormalizeName(self.selectedGuildData.name or "") == target then self.selectedGuildData=nil end
  if self.selectedGuild and BLFG_5611_NormalizeName(self.selectedGuild) == target then self.selectedGuild=nil end
  if broadcast == true and BLFG_5611_PlayerIsAdmin() then BLFG_5611_Send("BLFG312~GUILDBLOCK~Hsoj~" .. guildName) end
  BLFG_5611_PurgeGhostPublicGroups()
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

BLFG_5611_OldShowGuildMenu = BLFG.ShowGuildMenu
function BLFG:ShowGuildMenu(anchor, g)
  if not BLFG_5611_PlayerIsAdmin() then
    if BLFG_5611_OldShowGuildMenu then return BLFG_5611_OldShowGuildMenu(self, anchor, g) end
    return
  end
  if not g or not g.name then return end
  if not self.guildMenu then self.guildMenu = CreateFrame("Frame", "BronzeLFGGuildMenu", UIParent, "UIDropDownMenuTemplate") end
  local guild=tostring(g.name or "")
  local contact=tostring(g.contact or g.postContact or "")
  UIDropDownMenu_Initialize(self.guildMenu, function()
    local info=UIDropDownMenu_CreateInfo(); info.text=guild; info.isTitle=true; info.notCheckable=true; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Remove This Guild Listing"; info.notCheckable=true; info.func=function() BLFG:RemoveGuildListingByName(guild,true); CloseDropDownMenus(); DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00BronzeLFG:|r Removed guild listing: "..guild) end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text=contact ~= "" and ("Whisper "..contact) or "Whisper Contact"; info.notCheckable=true; info.disabled=(contact==""); info.func=function() if contact ~= "" then ChatFrame_OpenChat("/w "..contact.." ") end end; UIDropDownMenu_AddButton(info)
    info=UIDropDownMenu_CreateInfo(); info.text="Cancel"; info.notCheckable=true; info.func=function() CloseDropDownMenus() end; UIDropDownMenu_AddButton(info)
  end,"MENU")
  ToggleDropDownMenu(1,nil,self.guildMenu,anchor,0,0)
end

BLFG_5611_OldHandleMessage = BLFG.HandleMessage
function BLFG:HandleMessage(text)
  if type(text)=="string" and (string.sub(text,1,20)=="BLFG312~GUILDBLOCK" or string.sub(text,1,21)=="BLFG312~GUILDREMOVE") then
    local who,guild=text:match("^BLFG312~GUILDBLOCK~([^~]*)~(.*)$")
    if not who then who,guild=text:match("^BLFG312~GUILDREMOVE~([^~]*)~(.*)$") end
    if who == "Hsoj" and guild and guild ~= "" then self:RemoveGuildListingByName(guild,false) end
    return
  end
  if BLFG_5611_OldHandleMessage then return BLFG_5611_OldHandleMessage(self,text) end
end

BLFG_5611_OldInlinePublicChatLinkForMessage = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw=tostring(msgText or "")
  if BronzeLFG_IsAddonSpam(raw) then return nil end
  if BLFG_5611_IsGuildAd(raw) then
    local guildName=BLFG_5611_GuildNameFromAd(raw)
    if guildName ~= "" and not BLFG_5611_IsGuildSuppressed(guildName) then
      if self.UpsertGuildBrowserChatListing then self:UpsertGuildBrowserChatListing(guildName, author, raw) end
      local link=self.GuildChatLink and self:GuildChatLink(guildName) or nil
      if link then return raw .. " " .. link end
    end
  end
  return BLFG_5611_OldInlinePublicChatLinkForMessage and BLFG_5611_OldInlinePublicChatLinkForMessage(self,msgText,author,channelName) or nil
end

BLFG_5611_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw=tostring(text or "")
  if BronzeLFG_IsAddonSpam(raw) then return nil end
  local gn=BLFG_5611_GuildNameFromAd(raw)
  if gn ~= "" and BLFG_5611_IsGuildSuppressed(gn) then return nil end
  return BLFG_5611_OldAddPublicGroup and BLFG_5611_OldAddPublicGroup(self, author, text, channelName)
end

function BLFG_5611_MatchesDungeonFilter(g)
  if not BronzeLFG_DB or not BronzeLFG_DB.options then return true end
  local filter=tostring(BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
  if filter == "" or filter == "Any Dungeon" then return true end
  local hay=" "..BLFG_5611_Lower(tostring(g and g.activity or "").." "..tostring(g and g.message or "").." "..tostring(g and g.tags or "")).." "
  local aliases=BLFG_5611_DUNGEON_ALIASES[filter] or {filter}
  for _,a in ipairs(aliases) do
    if string.find(hay, BLFG_5611_Lower(a), 1, true) then return true end
  end
  return false
end

BLFG_5611_OldNotifyForPublicGroup = BLFG.NotifyForPublicGroup
function BLFG:NotifyForPublicGroup(g)
  if not g or not BronzeLFG_DB or not BronzeLFG_DB.options then return end
  if BronzeLFG_IsAddonSpam(tostring(g.message or g.activity or "")) then return end
  if tostring(g.type or "") == "Dungeon" and not BLFG_5611_MatchesDungeonFilter(g) then return end
  if BLFG_5611_OldNotifyForPublicGroup then return BLFG_5611_OldNotifyForPublicGroup(self,g) end
end

BLFG_5611_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r=BLFG_5611_OldBuildOptions and BLFG_5611_OldBuildOptions(self,...)
  if self.optionsPanel and not self.dungeonFilterDD then
    local box=nil
    for _,child in ipairs({self.optionsPanel:GetChildren()}) do if child and child.GetWidth and child:GetWidth() == 820 then box=child end end
    if box and dropdown then
      self.dungeonFilterDD = dropdown(box, "BLFGDungeonAlertDropdown", 150, BLFG_5611_DUNGEON_OPTIONS, (BronzeLFG_DB.options or {}).notifyDungeonFilter or "Any Dungeon", function(v)
        BronzeLFG_DB.options = BronzeLFG_DB.options or {}
        BronzeLFG_DB.options.notifyDungeonFilter = v
        if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
      end)
      self.dungeonFilterDD:SetPoint("TOPLEFT", box, "TOPLEFT", 625, -358)
    end
  end
  return r
end

BLFG_5611_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r=BLFG_5611_OldSaveOptions and BLFG_5611_OldSaveOptions(self,showFlash)
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.dungeonFilterDD and dd then BronzeLFG_DB.options.notifyDungeonFilter = dd(self.dungeonFilterDD) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon" end
  BronzeLFG_DB.options.notifyGuild = false
  return r
end

BLFG_5611_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  return BLFG_5611_OldRefreshPublicGroups and BLFG_5611_OldRefreshPublicGroups(self,...)
end

BLFG_5611_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  local r=BLFG_5611_OldOnEnable and BLFG_5611_OldOnEnable(self,...)
  BLFG_5611_PurgeGhostPublicGroups()
  return r
end

BLFG_5611_OldSlash = SlashCmdList["BRONZELFG"]
SlashCmdList["BRONZELFG"] = function(input)
  input=BLFG_5611_Lower(input or "")
  if input == "purgeghosts" or input == "cleanghosts" then
    BLFG_5611_PurgeGhostPublicGroups()
    if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SignalFire:|r ghost addon broadcasts removed from Public Groups.")
    return
  elseif input == "admintest" then
    DEFAULT_CHAT_FRAME:AddMessage("SignalFire admin: "..tostring(BLFG_5611_PlayerIsAdmin()).." player="..tostring(UnitName("player")).." realm="..tostring(GetRealmName()))
    return
  elseif input == "guildopptest" then
    local raw="â˜  OPPOSITION â˜  [NA/EU] â€¢ Server 3rd: BWL 7/7/Asc â€¢ Realm First: ZG/ONY/MC(Asc) â€¢ Recruiting Melee & HPAL for Main-Raids â€¢ discord.gg/opps"
    local g=BLFG_5611_GuildNameFromAd(raw)
    if BLFG.UpsertGuildBrowserChatListing then BLFG:UpsertGuildBrowserChatListing(g, UnitName("player"), raw) end
    DEFAULT_CHAT_FRAME:AddMessage(raw .. " " .. (BLFG.GuildChatLink and BLFG:GuildChatLink(g) or ("["..g.."]")))
    if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
    return
  end
  if BLFG_5611_OldSlash then return BLFG_5611_OldSlash(input) end
end

-- ============================================================================
-- v5.6.12 Guild Browser paging + stricter guild parser + dungeon dropdown fix
-- ============================================================================
BLFG.version = "5.6.12"
VERSION = "BronzeLFG v5.6.12"

function BLFG_SF_SafeSetEnabled(button, enabled)
  if not button then return end
  if button.SetEnabled then
    button:SetEnabled(enabled and true or false)
  elseif enabled then
    if button.Enable then button:Enable() end
  elseif button.Disable then
    button:Disable()
  end
end

function BLFG_5612_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5612_Trim(s) s=tostring(s or ""); s=s:gsub("^%s+",""):gsub("%s+$",""); return s end
function BLFG_5612_Normalize(s)
  s=BLFG_5612_Lower(s or "")
  s=s:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
  s=s:gsub("[^%w]+","")
  return s
end
function BLFG_5612_IsSentenceName(n)
  n=BLFG_5612_Trim(n or "")
  local l=BLFG_5612_Lower(n)
  local words=0; for _ in n:gmatch("%S+") do words=words+1 end
  if words >= 5 then return true end
  if l:find(" it ",1,true) or l:find(" seems",1,true) or l:find("you think",1,true) or l:find("single user",1,true) or l:find("bad",1,true) then return true end
  if l:find("lost wifi",1,true) or l:find("msg me",1,true) or l:find("pls",1,true) then return true end
  return false
end

-- Stricter guild ad detection: no more random sentence fragments becoming guilds.
function BLFG_5612_CleanDecoratedGuildCandidate(s)
  s=BLFG_5612_Trim(s or "")
  s=s:gsub("^[%s%p%c]+",""):gsub("[%s%p%c]+$","")
  s=s:gsub("^[â˜ â˜…â˜†%s%-]+",""):gsub("[â˜ â˜…â˜†%s%-]+$","")
  s=BLFG_5612_Trim(s)
  if BLFG_5612_IsSentenceName(s) then return "" end
  if string.len(s) < 2 or string.len(s) > 32 then return "" end
  return s
end

function BLFG_5612_GuildNameFromAd(text)
  local s=tostring(text or "")
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return "" end
  local l=BLFG_5612_Lower(s)
  -- Clean <Guild> is always the highest-confidence guild-name source.
  local g=s:match("<([^>]+)>")
  if g then g=BLFG_5612_CleanDecoratedGuildCandidate(g); if g ~= "" then return g end end
  -- Decorated all-caps names before [NA/EU], [NA], [EU], etc. Example: â˜  OPPOSITION â˜  [NA/EU]
  local pre=s:match("^(.-)%s*%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or s:match("^(.-)%s*%[[Nn][Aa]%]") or s:match("^(.-)%s*%[[Ee][Uu]%]")
  if pre then
    g=BLFG_5612_CleanDecoratedGuildCandidate(pre)
    if g ~= "" then return g end
  end
  -- Only allow no-bracket fallback when the message clearly looks like a formal recruitment ad.
  if l:find("recruit",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) then
    pre=s:match("^(.-)%s+[Rr]ecruit") or s:match("^(.-)%s+discord")
    if pre then
      g=BLFG_5612_CleanDecoratedGuildCandidate(pre)
      if g ~= "" then return g end
    end
  end
  return ""
end

function BLFG_5612_IsGuildAd(text)
  local raw=tostring(text or "")
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then return false end
  local l=BLFG_5612_Lower(raw)
  local name=BLFG_5612_GuildNameFromAd(raw)
  if name == "" then return false end
  if BLFG_5612_IsSentenceName(name) then return false end
  if raw:find("<[^>]+>") then
    if l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord",1,true) or l:find("raid",1,true) or l:find("pvp",1,true) or l:find("boss blitz",1,true) then return true end
  end
  if raw:find("%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or raw:find("%[[Nn][Aa]%]") or raw:find("%[[Ee][Uu]%]") then
    if l:find("recruit",1,true) or l:find("discord",1,true) or l:find("realm first",1,true) or l:find("server 3rd",1,true) or l:find("main%-raid",1,true) or l:find("main raid",1,true) then return true end
  end
  return false
end
BLFG_5611_GuildNameFromAd = BLFG_5612_GuildNameFromAd
BLFG_5611_IsGuildAd = BLFG_5612_IsGuildAd
BLFG_569_GuildNameFromAd = BLFG_5612_GuildNameFromAd
BLFG_568_GuildNameFromAd = BLFG_5612_GuildNameFromAd
BLFG_567_GuildNameFromAd = BLFG_5612_GuildNameFromAd
BLFG_565_GuildNameFromAd = BLFG_5612_GuildNameFromAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5612_IsGuildAd

function BLFG_5612_PurgeBadGuilds()
  if not BLFG then return end
  local function badName(n) return BLFG_5612_IsSentenceName(n) or BLFG_5612_Normalize(n)=="" end
  for _,source in ipairs({BLFG.chatGuildListings or {}, BronzeLFG_DB and BronzeLFG_DB.chatGuildListings or {}, BLFG.guilds or {}, BLFG.guildBrowserGuilds or {}}) do
    for k,g in pairs(source) do
      local n=tostring((g and (g.name or g.guild)) or k or "")
      if badName(n) then source[k]=nil end
    end
  end
  for id,g in pairs(BLFG.publicGroups or {}) do
    local msg=tostring(g and (g.message or g.activity) or "")
    if g and g.type == "Guild" and (badName(g.activity or "") or not BLFG_5612_IsGuildAd(msg)) then BLFG.publicGroups[id]=nil end
  end
end

-- Make right-click removal normalize harder, so live/chat guild rows can be hidden consistently.
BLFG_5612_OldRemoveGuildListingByName = BLFG.RemoveGuildListingByName
function BLFG:RemoveGuildListingByName(guildName, broadcast)
  guildName=BLFG_5612_Trim(guildName or "")
  if guildName == "" then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.guildSuppressed = BronzeLFG_DB.guildSuppressed or {}
  BronzeLFG_DB.guildSuppressed[BLFG_5612_Normalize(guildName)] = true
  if BLFG_5612_OldRemoveGuildListingByName then BLFG_5612_OldRemoveGuildListingByName(self,guildName,broadcast) end
  BLFG_5612_PurgeBadGuilds()
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

-- Add scroll/paging to Guild Browser rows.
BLFG_5612_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  if not self.guildRows then return BLFG_5612_OldRefreshGuildBrowser and BLFG_5612_OldRefreshGuildBrowser(self,...) end
  BLFG_5612_PurgeBadGuilds()
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  rows = rows or {}
  local per=8
  local pages=math.max(1, math.ceil(#rows/per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage=1 end
  if self.guildPage > pages then self.guildPage=pages end
  local start=((self.guildPage-1)*per)+1
  if self.guildCountText then self.guildCountText:SetText("Guilds found: "..#rows.."  |  Live: "..tostring(self.guildLiveCount or 0).."  |  Chat: "..tostring(self.guildPostOnlyCount or 0).."  |  Page: "..self.guildPage.."/"..pages) end
  if self.guildFavFilterButton then self.guildFavFilterButton:SetText(self.guildFavoritesOnly and "Favorites: On" or "Favorites: Off") end
  if self.guildFocusFilterButton then self.guildFocusFilterButton:SetText("Focus: "..tostring(self.guildFocusFilter or "All")) end
  self.selectedGuildData=nil
  for i,r in ipairs(self.guildRows) do
    local g=rows[start+i-1]
    if g and r and r.Show then
      r:Show(); r.guildName=g.name; r.guildData=g
      if string.lower(tostring(self.selectedGuild or "")) == string.lower(tostring(g.name or "")) then self.selectedGuild = tostring(g.name or self.selectedGuild or ""); r:SetBackdropColor(.25,.25,.05,.95); self.selectedGuildData=g else r:SetBackdropColor(0,0,0,.80) end
      r.guild:SetText((g.favorite and "|cffffd100â˜… |r" or "")..tostring(g.name or ""))
      r.online:SetText(tostring(g.online or 0)); r.status:SetText(shortenPublicText(g.status or "Unknown",10)); r.recruiting:SetText(shortenPublicText(g.recruiting or "Unknown",12)); r.focus:SetText(guildFocusTagsText(g.focus or "--",1)); r.fav:SetText(g.favorite and "â˜…" or "")
    else
      if r then r.guildName=nil; r.guildData=nil; r.guild:SetText(""); r.online:SetText(""); r.status:SetText(""); r.recruiting:SetText(""); r.focus:SetText(""); r.fav:SetText(""); r:SetBackdropColor(0,0,0,.80); r:Hide() end
    end
  end
  if self.guildList and not self.guildList._blfg5612wheel then
    self.guildList:EnableMouseWheel(true)
    self.guildList:SetScript("OnMouseWheel", function(_, delta)
      BLFG.guildPage = (BLFG.guildPage or 1) + (delta < 0 and 1 or -1)
      BLFG:RefreshGuildBrowser()
    end)
    self.guildList._blfg5612wheel=true
  end
  if self.guildList and not self.guildPrevPageButton then
    local prev=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); prev:SetWidth(26); prev:SetHeight(22); prev:SetText("<"); prev:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 8, 12); prev:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end); self.guildPrevPageButton=prev
    local nxt=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); nxt:SetWidth(26); nxt:SetHeight(22); nxt:SetText(">"); nxt:SetPoint("LEFT", prev, "RIGHT", 4, 0); nxt:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end); self.guildNextPageButton=nxt
  end
  BLFG_SF_SafeSetEnabled(self.guildPrevPageButton, self.guildPage>1)
  BLFG_SF_SafeSetEnabled(self.guildNextPageButton, self.guildPage<pages)
  if self.RefreshGuildDetailPanel then self:RefreshGuildDetailPanel(self.selectedGuildData or rows[start]) end
end

-- Create our own dropdown; previous patch called a local helper that is not visible here.
function BLFG_5612_SetDDText(frame, text) if frame then UIDropDownMenu_SetText(frame, text or "") end end
function BLFG_5612_CreateDropdown(parent, name, width, values, selected, onchange)
  local d=CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(d, width or 150)
  if BLFG_FixDropdownButton then BLFG_FixDropdownButton(d) end
  UIDropDownMenu_Initialize(d, function()
    for _,v in ipairs(values or {}) do
      local info=UIDropDownMenu_CreateInfo(); info.text=v; info.checked=(UIDropDownMenu_GetText(d)==v); info.func=function() BLFG_5612_SetDDText(d,v); if onchange then onchange(v) end; CloseDropDownMenus() end; UIDropDownMenu_AddButton(info)
    end
  end)
  BLFG_5612_SetDDText(d, selected or (values and values[1]) or "")
  return d
end

BLFG_5612_DUNGEON_OPTIONS = BLFG_5611_DUNGEON_OPTIONS or {"Any Dungeon","Ragefire Chasm","Deadmines","Wailing Caverns","Shadowfang Keep","Blackfathom Deeps","The Stockade","Gnomeregan","Razorfen Kraul","Scarlet Monastery","Razorfen Downs","Uldaman","Zul'Farrak","Maraudon","Sunken Temple","Blackrock Depths","Dire Maul","Lower Blackrock Spire","Upper Blackrock Spire","Stratholme","Scholomance"}
BLFG_5612_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r=BLFG_5612_OldBuildOptions and BLFG_5612_OldBuildOptions(self,...)
  if self.optionsPanel and not self.dungeonFilterDD5612 then
    local box=nil
    for _,child in ipairs({self.optionsPanel:GetChildren()}) do if child and child.GetWidth and child:GetWidth() == 820 then box=child end end
    if box then
      BronzeLFG_DB.options = BronzeLFG_DB.options or {}
      self.dungeonFilterDD5612 = BLFG_5612_CreateDropdown(box, "BLFGDungeonAlertDropdown5612", 150, BLFG_5612_DUNGEON_OPTIONS, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon", function(v)
        BronzeLFG_DB.options.notifyDungeonFilter = v
        if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
      end)
      self.dungeonFilterDD5612:SetPoint("TOPLEFT", box, "TOPLEFT", 625, -358)
    end
  end
  return r
end

BLFG_5612_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r=BLFG_5612_OldSaveOptions and BLFG_5612_OldSaveOptions(self,showFlash)
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.dungeonFilterDD5612 then BronzeLFG_DB.options.notifyDungeonFilter = UIDropDownMenu_GetText(self.dungeonFilterDD5612) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon" end
  return r
end

-- Keep ghost protocol rows and accidental sentence-guilds purged during normal refresh.
BLFG_5612_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  BLFG_5612_PurgeBadGuilds()
  return BLFG_5612_OldRefreshPublicGroups and BLFG_5612_OldRefreshPublicGroups(self,...)
end

BLFG_5612_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  local r=BLFG_5612_OldOnEnable and BLFG_5612_OldOnEnable(self,...)
  BLFG_5612_PurgeBadGuilds()
  return r
end

-- ============================================================================
-- v5.6.13 Dungeon dropdown visibility + Guild Browser paging polish
-- ============================================================================
BLFG.version = "5.6.13"
VERSION = "BronzeLFG v5.6.13"

-- Extra strictness: normal conversation in chat should not become Guild Recruitment.
function BLFG_5613_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5613_Trim(s) s=tostring(s or ""); s=s:gsub("^%s+",""):gsub("%s+$",""); return s end
function BLFG_5613_IsBadGuildConversation(text)
  local l=BLFG_5613_Lower(text or "")
  if l:find("you think",1,true) or l:find("single user",1,true) or l:find("nympho",1,true) then return true end
  if l:find("lost wifi",1,true) or l:find("msg me",1,true) or l:find("pls",1,true) then return true end
  if l:find("it seems like",1,true) or l:find("every private",1,true) then return true end
  if l:find("anyone else",1,true) or l:find("this server",1,true) then return true end
  return false
end
BLFG_5613_OldIsGuildAd = BLFG_5612_IsGuildAd or BLFG_5611_IsGuildAd
function BLFG_5613_IsGuildAd(text)
  if BLFG_5613_IsBadGuildConversation(text) then return false end
  return BLFG_5613_OldIsGuildAd and BLFG_5613_OldIsGuildAd(text) or false
end
BLFG_5612_IsGuildAd = BLFG_5613_IsGuildAd
BLFG_5611_IsGuildAd = BLFG_5613_IsGuildAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5613_IsGuildAd

function BLFG_5613_CreateDungeonDropdown()
  if not BLFG or not BLFG.optionsPanel or not BLFG.optNotifyDungeon then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  local parent = BLFG.optNotifyDungeon:GetParent() or BLFG.optionsPanel
  if not BLFG.dungeonAlertDropdown5613 then
    BLFG.dungeonAlertDropdown5613 = BLFG_5612_CreateDropdown(parent, "BLFGDungeonAlertDropdown5613", 150, BLFG_5612_DUNGEON_OPTIONS, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon", function(v)
      BronzeLFG_DB.options.notifyDungeonFilter = v
      if BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
    end)
  else
    BLFG.dungeonAlertDropdown5613:SetParent(parent)
  end
  BLFG.dungeonAlertDropdown5613:ClearAllPoints()
  -- Anchor directly to Dungeon Listings so it follows the row, instead of guessing panel coordinates.
  BLFG.dungeonAlertDropdown5613:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 245, -2)
  BLFG.dungeonAlertDropdown5613:Show()
  UIDropDownMenu_SetText(BLFG.dungeonAlertDropdown5613, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
end

BLFG_5613_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5613_OldBuildOptions and BLFG_5613_OldBuildOptions(self, ...)
  BLFG_5613_CreateDungeonDropdown()
  return r
end
BLFG_5613_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5613_OldShowOptions and BLFG_5613_OldShowOptions(self, ...)
  BLFG_5613_CreateDungeonDropdown()
  return r
end

BLFG_5613_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_5613_OldSaveOptions and BLFG_5613_OldSaveOptions(self, showFlash)
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.dungeonAlertDropdown5613 then BronzeLFG_DB.options.notifyDungeonFilter = UIDropDownMenu_GetText(self.dungeonAlertDropdown5613) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon" end
  return r
end

function BLFG_5613_SetGuildPager(pages)
  if not BLFG or not BLFG.guildList then return end
  if BLFG.guildPrevPageButton then BLFG.guildPrevPageButton:Hide() end
  if BLFG.guildNextPageButton then BLFG.guildNextPageButton:Hide() end
  if not BLFG.guildPageUpButton then
    BLFG.guildPageUpButton=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageUpButton:SetWidth(90); BLFG.guildPageUpButton:SetHeight(26); BLFG.guildPageUpButton:SetText("Up")
    BLFG.guildPageUpButton:SetPoint("BOTTOMLEFT", BLFG.guildList, "BOTTOMLEFT", 24, 10)
    BLFG.guildPageUpButton:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageDownButton then
    BLFG.guildPageDownButton=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageDownButton:SetWidth(90); BLFG.guildPageDownButton:SetHeight(26); BLFG.guildPageDownButton:SetText("Down")
    BLFG.guildPageDownButton:SetPoint("LEFT", BLFG.guildPageUpButton, "RIGHT", 12, 0)
    BLFG.guildPageDownButton:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageLabel then
    BLFG.guildPageLabel=BLFG.guildList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    BLFG.guildPageLabel:SetPoint("LEFT", BLFG.guildPageDownButton, "RIGHT", 24, 0)
  end
  BLFG.guildPageUpButton:Show(); BLFG.guildPageDownButton:Show(); BLFG.guildPageLabel:Show()
  BLFG_SF_SafeSetEnabled(BLFG.guildPageUpButton, (BLFG.guildPage or 1) > 1)
  BLFG_SF_SafeSetEnabled(BLFG.guildPageDownButton, (BLFG.guildPage or 1) < (pages or 1))
  BLFG.guildPageLabel:SetText("Page "..tostring(BLFG.guildPage or 1).." / "..tostring(pages or 1))
end

-- Replace the small overlapping < > pager with Public Groups-style Up/Down buttons and page x/x text.
BLFG_5613_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  local r = BLFG_5613_OldRefreshGuildBrowser and BLFG_5613_OldRefreshGuildBrowser(self, ...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  local per = 8
  local pages = math.max(1, math.ceil(#rows / per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage = 1 end
  if self.guildPage > pages then self.guildPage = pages end
  BLFG_5613_SetGuildPager(pages)
  if self.guildCountText then
    self.guildCountText:SetText("Guilds found: "..tostring(#rows).."  |  Live: "..tostring(self.guildLiveCount or 0).."  |  Chat: "..tostring(self.guildPostOnlyCount or 0))
  end
  return r
end

-- Ensure options and stale bad guilds settle after load.
BLFG_5613_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  local r = BLFG_5613_OldOnEnable and BLFG_5613_OldOnEnable(self, ...)
  if BLFG_5612_PurgeBadGuilds then BLFG_5612_PurgeBadGuilds() end
  return r
end


-- ============================================================================
-- v5.6.14 Dungeon alert menu polish + Guild Browser footer/persistence cleanup
-- ============================================================================
BLFG.version = "5.6.14"

-- Dungeon dropdown was too tall for the screen. Use grouped submenus so it never
-- turns into a giant unscrollable wall.
BLFG_5614_DUNGEON_GROUPS = {
  { text = "Any Dungeon", value = "Any Dungeon" },
  { text = "Leveling Dungeons", menu = {
    { text="Ragefire Chasm", value="Ragefire Chasm" },
    { text="Wailing Caverns", value="Wailing Caverns" },
    { text="Deadmines", value="Deadmines" },
    { text="Shadowfang Keep", value="Shadowfang Keep" },
    { text="Blackfathom Deeps", value="Blackfathom Deeps" },
    { text="The Stockade", value="The Stockade" },
    { text="Gnomeregan", value="Gnomeregan" },
    { text="Razorfen Kraul", value="Razorfen Kraul" },
    { text="Scarlet Monastery", value="Scarlet Monastery" },
    { text="Razorfen Downs", value="Razorfen Downs" },
    { text="Uldaman", value="Uldaman" },
    { text="Zul'Farrak", value="Zul'Farrak" },
    { text="Maraudon", value="Maraudon" },
    { text="Sunken Temple", value="Sunken Temple" },
  }},
  { text = "Endgame Dungeons", menu = {
    { text="Blackrock Depths", value="Blackrock Depths" },
    { text="Lower Blackrock Spire", value="Lower Blackrock Spire" },
    { text="Upper Blackrock Spire", value="Upper Blackrock Spire" },
    { text="Dire Maul", value="Dire Maul" },
    { text="Dire Maul East", value="Dire Maul East" },
    { text="Dire Maul West", value="Dire Maul West" },
    { text="Dire Maul North", value="Dire Maul North" },
    { text="Stratholme", value="Stratholme" },
    { text="Stratholme Live", value="Stratholme Live" },
    { text="Stratholme Undead", value="Stratholme Undead" },
    { text="Scholomance", value="Scholomance" },
  }},
  { text = "Triumvirate Modes", menu = {
    { text="Any World Boss", value="World Boss" },
    { text="Any Key", value="Key" },
    { text="Any Dungeon Diving", value="Dungeon Diving" },
  }},
}

function BLFG_5614_SetDungeonText(v)
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  BronzeLFG_DB.options.notifyDungeonFilter = v or "Any Dungeon"
  if BLFG and BLFG.dungeonAlertDropdown5614 then UIDropDownMenu_SetText(BLFG.dungeonAlertDropdown5614, BronzeLFG_DB.options.notifyDungeonFilter) end
  if BLFG and BLFG.optionsStatus then BLFG.optionsStatus:SetText("Options saved.") end
end

function BLFG_5614_CreateDungeonDropdown()
  if not BLFG or not BLFG.optionsPanel or not BLFG.optNotifyDungeon then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  local parent = BLFG.optNotifyDungeon:GetParent() or BLFG.optionsPanel
  if BLFG.dungeonFilterDD5612 then BLFG.dungeonFilterDD5612:Hide() end
  if BLFG.dungeonAlertDropdown5613 then BLFG.dungeonAlertDropdown5613:Hide() end
  if not BLFG.dungeonAlertDropdown5614 then
    BLFG.dungeonAlertDropdown5614 = CreateFrame("Frame", "BLFGDungeonAlertDropdown5614", parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(BLFG.dungeonAlertDropdown5614, 170)
    if BLFG_FixDropdownButton then BLFG_FixDropdownButton(BLFG.dungeonAlertDropdown5614) end
    UIDropDownMenu_Initialize(BLFG.dungeonAlertDropdown5614, function(self, level, menuList)
      level = level or 1
      local source = menuList or BLFG_5614_DUNGEON_GROUPS
      for _, item in ipairs(source or {}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = item.text
        info.notCheckable = nil
        if item.menu then
          info.hasArrow = 1
          info.menuList = item.menu
          info.checked = false
        else
          info.checked = ((BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon") == item.value)
          info.func = function()
            BLFG_5614_SetDungeonText(item.value)
            CloseDropDownMenus()
          end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  else
    BLFG.dungeonAlertDropdown5614:SetParent(parent)
  end
  BLFG.dungeonAlertDropdown5614:ClearAllPoints()
  BLFG.dungeonAlertDropdown5614:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 250, -2)
  BLFG.dungeonAlertDropdown5614:Show()
  UIDropDownMenu_SetText(BLFG.dungeonAlertDropdown5614, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
end

BLFG_5614_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5614_OldBuildOptions and BLFG_5614_OldBuildOptions(self, ...)
  BLFG_5614_CreateDungeonDropdown()
  return r
end
BLFG_5614_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5614_OldShowOptions and BLFG_5614_OldShowOptions(self, ...)
  BLFG_5614_CreateDungeonDropdown()
  return r
end
BLFG_5614_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_5614_OldSaveOptions and BLFG_5614_OldSaveOptions(self, showFlash)
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.dungeonAlertDropdown5614 then BronzeLFG_DB.options.notifyDungeonFilter = UIDropDownMenu_GetText(self.dungeonAlertDropdown5614) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon" end
  return r
end

-- Chat-only guild rows are just recent chat captures. They should not survive a reload.
function BLFG_5614_ClearSessionGuildCache()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.chatGuildListings = {}
  if BLFG then BLFG.chatGuildListings = {} end
  -- Also remove saved public-group rows that were only guild recruitment chat captures.
  if BLFG and BLFG.publicGroups then
    for id,g in pairs(BLFG.publicGroups) do
      local t = tostring(g and (g.type or g.category or "") or "")
      local src = tostring(g and (g.source or g.status or "") or "")
      if string.lower(t) == "guild" and (string.find(string.lower(src), "chat", 1, true) or string.find(string.lower(src), "recruit", 1, true) or not g.mine) then
        BLFG.publicGroups[id] = nil
      end
    end
  end
  if BronzeLFG_DB.publicGroups then
    for id,g in pairs(BronzeLFG_DB.publicGroups) do
      local t = tostring(g and (g.type or g.category or "") or "")
      local src = tostring(g and (g.source or g.status or "") or "")
      if string.lower(t) == "guild" and (string.find(string.lower(src), "chat", 1, true) or string.find(string.lower(src), "recruit", 1, true) or not g.mine) then
        BronzeLFG_DB.publicGroups[id] = nil
      end
    end
  end
end

-- Rebuild pager as a clean row above the Guild Browser action buttons, never on top of Clear Listings.
function BLFG_5614_SetGuildPager(pages)
  if not BLFG or not BLFG.guildList then return end
  if BLFG.guildPrevPageButton then BLFG.guildPrevPageButton:Hide() end
  if BLFG.guildNextPageButton then BLFG.guildNextPageButton:Hide() end
  if BLFG.guildPageUpButton then BLFG.guildPageUpButton:Hide() end
  if BLFG.guildPageDownButton then BLFG.guildPageDownButton:Hide() end
  if BLFG.guildPageLabel then BLFG.guildPageLabel:Hide() end

  if not BLFG.guildPageUpButton5614 then
    BLFG.guildPageUpButton5614=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageUpButton5614:SetWidth(82); BLFG.guildPageUpButton5614:SetHeight(24); BLFG.guildPageUpButton5614:SetText("Up")
    BLFG.guildPageUpButton5614:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageDownButton5614 then
    BLFG.guildPageDownButton5614=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageDownButton5614:SetWidth(82); BLFG.guildPageDownButton5614:SetHeight(24); BLFG.guildPageDownButton5614:SetText("Down")
    BLFG.guildPageDownButton5614:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageLabel5614 then
    BLFG.guildPageLabel5614=BLFG.guildList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  end
  BLFG.guildPageUpButton5614:ClearAllPoints()
  BLFG.guildPageUpButton5614:SetPoint("BOTTOMLEFT", BLFG.guildList, "BOTTOMLEFT", 14, 42)
  BLFG.guildPageDownButton5614:ClearAllPoints()
  BLFG.guildPageDownButton5614:SetPoint("LEFT", BLFG.guildPageUpButton5614, "RIGHT", 10, 0)
  BLFG.guildPageLabel5614:ClearAllPoints()
  BLFG.guildPageLabel5614:SetPoint("LEFT", BLFG.guildPageDownButton5614, "RIGHT", 18, 0)
  BLFG.guildPageUpButton5614:Show(); BLFG.guildPageDownButton5614:Show(); BLFG.guildPageLabel5614:Show()
  BLFG_SF_SafeSetEnabled(BLFG.guildPageUpButton5614, (BLFG.guildPage or 1) > 1)
  BLFG_SF_SafeSetEnabled(BLFG.guildPageDownButton5614, (BLFG.guildPage or 1) < (pages or 1))
  BLFG.guildPageLabel5614:SetText("Page "..tostring(BLFG.guildPage or 1).." / "..tostring(pages or 1))
end

BLFG_5614_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  local r = BLFG_5614_OldRefreshGuildBrowser and BLFG_5614_OldRefreshGuildBrowser(self, ...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  local per = 8
  local pages = math.max(1, math.ceil(#rows / per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage = 1 end
  if self.guildPage > pages then self.guildPage = pages end
  BLFG_5614_SetGuildPager(pages)
  return r
end

BLFG_5614_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  BLFG_5614_ClearSessionGuildCache()
  local r = BLFG_5614_OldOnEnable and BLFG_5614_OldOnEnable(self, ...)
  BLFG_5614_ClearSessionGuildCache()
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  return r
end

-- ============================================================================
-- v5.6.15 Layout + session cleanup hardening
-- ============================================================================
BLFG.version = "5.6.15"
VERSION = "5.6.15"
BLFG_5615_SESSION_START = time and time() or 0

function BLFG_5615_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5615_CleanGuildName(n)
  n = tostring(n or "")
  n = n:gsub("{rt%d}", ""):gsub("rt%d}", ""):gsub("{|T.-|t}", "")
  n = n:gsub("^%s+",""):gsub("%s+$","")
  return n
end
function BLFG_5615_IsStaleChatGuildRow(g)
  if not g then return false end
  local name = BLFG_5615_CleanGuildName(g.name or g.guild or "")
  local status = BLFG_5615_Lower(g.status or "")
  local source = BLFG_5615_Lower(g.source or "")
  local online = tonumber(g.online or 0) or 0
  local seen = tonumber(g.lastPostSeen or g.seen or g.created or 0) or 0
  if name == "" then return true end
  if tostring(g.name or g.guild or ""):find("rt%d", 1) then return true end
  if online > 0 then return false end
  if status:find("chat", 1, true) or source:find("chat", 1, true) or source:find("public", 1, true) then
    if seen == 0 or seen < (BLFG_5615_SESSION_START - 2) then return true end
  end
  return false
end
function BLFG_5615_ClearStaleGuildSources()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.chatGuildListings = {}
  if BLFG then BLFG.chatGuildListings = {} end
  local function purge(tbl)
    if not tbl then return end
    for k,g in pairs(tbl) do
      if BLFG_5615_IsStaleChatGuildRow(g) then tbl[k]=nil end
    end
  end
  purge(BLFG and BLFG.guildBrowserGuilds)
  purge(BLFG and BLFG.guildRowsData)
  purge(BLFG and BLFG.guilds)
  purge(BronzeLFG_DB.guildBrowserGuilds)
  purge(BronzeLFG_DB.guildRowsData)
  purge(BronzeLFG_DB.guilds)
  local function purgePublic(tbl)
    if not tbl then return end
    for id,g in pairs(tbl) do
      local typ=BLFG_5615_Lower(g and (g.type or g.category or "") or "")
      local act=BLFG_5615_Lower(g and (g.activity or "") or "")
      local src=BLFG_5615_Lower(g and (g.source or g.status or "") or "")
      local seen=tonumber(g and (g.seen or g.created or 0) or 0) or 0
      if (typ == "guild" or act == "guild recruitment") and (src:find("chat",1,true) or src:find("recruit",1,true) or seen < (BLFG_5615_SESSION_START - 2)) then tbl[id]=nil end
    end
  end
  purgePublic(BLFG and BLFG.publicGroups)
  purgePublic(BronzeLFG_DB.publicGroups)
end

-- Filter stale chat-only rows at display time too, in case an older wrapper rebuilds them from publicGroups.
BLFG_5615_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  BLFG_5615_ClearStaleGuildSources()
  local rows,a,b,c = BLFG_5615_OldGetGuildRows and BLFG_5615_OldGetGuildRows(self, ...) or {}
  rows = rows or {}
  for i=#rows,1,-1 do
    local g=rows[i]
    if BLFG_5615_IsStaleChatGuildRow(g) then table.remove(rows,i) end
  end
  return rows,a,b,c
end

-- Keep dungeon dropdown compact and inside the settings panel.  The grouped submenu
-- was functionally correct, but anchored too far right and felt broken.
function BLFG_5615_CreateDungeonDropdown()
  if not BLFG or not BLFG.optionsPanel or not BLFG.optNotifyDungeon then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  local parent = BLFG.optNotifyDungeon:GetParent() or BLFG.optionsPanel
  if BLFG.dungeonFilterDD5612 then BLFG.dungeonFilterDD5612:Hide() end
  if BLFG.dungeonAlertDropdown5613 then BLFG.dungeonAlertDropdown5613:Hide() end
  if not BLFG.dungeonAlertDropdown5615 then
    BLFG.dungeonAlertDropdown5615 = CreateFrame("Frame", "BLFGDungeonAlertDropdown5615", parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(BLFG.dungeonAlertDropdown5615, 170)
    if BLFG_FixDropdownButton then BLFG_FixDropdownButton(BLFG.dungeonAlertDropdown5615) end
    UIDropDownMenu_Initialize(BLFG.dungeonAlertDropdown5615, function(self, level, menuList)
      level = level or 1
      local source = menuList or BLFG_5614_DUNGEON_GROUPS
      for _, item in ipairs(source or {}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = item.text
        if item.menu then
          info.hasArrow = 1; info.menuList = item.menu; info.notCheckable = true
        else
          info.checked = ((BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon") == item.value)
          info.func = function() BLFG_5614_SetDungeonText(item.value); CloseDropDownMenus() end
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end)
  else
    BLFG.dungeonAlertDropdown5615:SetParent(parent)
  end
  if BLFG.dungeonAlertDropdown5614 then BLFG.dungeonAlertDropdown5614:Hide() end
  BLFG.dungeonAlertDropdown5615:ClearAllPoints()
  BLFG.dungeonAlertDropdown5615:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 160, -2)
  BLFG.dungeonAlertDropdown5615:Show()
  UIDropDownMenu_SetText(BLFG.dungeonAlertDropdown5615, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
end
BLFG_5615_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5615_OldBuildOptions and BLFG_5615_OldBuildOptions(self, ...)
  BLFG_5615_CreateDungeonDropdown()
  return r
end
BLFG_5615_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5615_OldShowOptions and BLFG_5615_OldShowOptions(self, ...)
  BLFG_5615_CreateDungeonDropdown()
  return r
end

-- Clean Guild Browser footer: no overlap with Clear/Create/Show buttons, and no old tiny pager buttons.
function BLFG_5615_SetGuildPager(pages)
  if not BLFG or not BLFG.guildList then return end
  for _,b in ipairs({BLFG.guildPrevPageButton,BLFG.guildNextPageButton,BLFG.guildPageUpButton,BLFG.guildPageDownButton,BLFG.guildPageUpButton5614,BLFG.guildPageDownButton5614}) do if b then b:Hide() end end
  if BLFG.guildPageLabel then BLFG.guildPageLabel:Hide() end
  if BLFG.guildPageLabel5614 then BLFG.guildPageLabel5614:Hide() end
  if not BLFG.guildPageUpButton5615 then
    BLFG.guildPageUpButton5615=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageUpButton5615:SetWidth(82); BLFG.guildPageUpButton5615:SetHeight(24); BLFG.guildPageUpButton5615:SetText("Up")
    BLFG.guildPageUpButton5615:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageDownButton5615 then
    BLFG.guildPageDownButton5615=CreateFrame("Button", nil, BLFG.guildList, "UIPanelButtonTemplate")
    BLFG.guildPageDownButton5615:SetWidth(82); BLFG.guildPageDownButton5615:SetHeight(24); BLFG.guildPageDownButton5615:SetText("Down")
    BLFG.guildPageDownButton5615:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
  end
  if not BLFG.guildPageLabel5615 then BLFG.guildPageLabel5615=BLFG.guildList:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end
  BLFG.guildPageUpButton5615:ClearAllPoints(); BLFG.guildPageUpButton5615:SetPoint("BOTTOMLEFT", BLFG.guildList, "BOTTOMLEFT", 22, 66)
  BLFG.guildPageDownButton5615:ClearAllPoints(); BLFG.guildPageDownButton5615:SetPoint("LEFT", BLFG.guildPageUpButton5615, "RIGHT", 10, 0)
  BLFG.guildPageLabel5615:ClearAllPoints(); BLFG.guildPageLabel5615:SetPoint("LEFT", BLFG.guildPageDownButton5615, "RIGHT", 22, 0)
  BLFG.guildPageUpButton5615:Show(); BLFG.guildPageDownButton5615:Show(); BLFG.guildPageLabel5615:Show()
  BLFG_SF_SafeSetEnabled(BLFG.guildPageUpButton5615, (BLFG.guildPage or 1) > 1)
  BLFG_SF_SafeSetEnabled(BLFG.guildPageDownButton5615, (BLFG.guildPage or 1) < (pages or 1))
  BLFG.guildPageLabel5615:SetText("Page "..tostring(BLFG.guildPage or 1).." / "..tostring(pages or 1))
end
BLFG_5615_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  BLFG_5615_ClearStaleGuildSources()
  local r = BLFG_5615_OldRefreshGuildBrowser and BLFG_5615_OldRefreshGuildBrowser(self, ...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  local per = 8
  local pages = math.max(1, math.ceil(#rows / per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage = 1 end
  if self.guildPage > pages then self.guildPage = pages end
  BLFG_5615_SetGuildPager(pages)
  return r
end
BLFG_5615_OldOnEnable = BLFG.OnEnable
function BLFG:OnEnable(...)
  BLFG_5615_ClearStaleGuildSources()
  local r = BLFG_5615_OldOnEnable and BLFG_5615_OldOnEnable(self, ...)
  BLFG_5615_ClearStaleGuildSources()
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  return r
end

-- ============================================================================
-- v5.6.16 Footer layout + decorated guild upsert hardening
-- ============================================================================
BLFG.version = "5.6.16"
VERSION = "5.6.16"

function BLFG_5616_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5616_Trim(s) s=tostring(s or ""); s=s:gsub("^%s+",""):gsub("%s+$",""); return s end
function BLFG_5616_CleanDecoratedName(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%s*[Rr][Tt]%d+%s*}", "")
  s = s:gsub("[Rr][Tt]%d+}", "")
  s = s:gsub("{%s*[Rr][Tt]%d+", "")
  s = s:gsub("[â˜ â˜…â˜†]", "")
  s = s:gsub("^[%s%p]+", ""):gsub("[%s%p]+$", "")
  s = BLFG_5616_Trim(s)
  return s
end
function BLFG_5616_Normalize(s)
  s = BLFG_5616_CleanDecoratedName(s)
  s = BLFG_5616_Lower(s)
  s = s:gsub("[^%w]+", "")
  return s
end
function BLFG_5616_IsBadGuildName(n)
  n = BLFG_5616_CleanDecoratedName(n)
  if n == "" or string.len(n) < 2 or string.len(n) > 34 then return true end
  local l = BLFG_5616_Lower(n)
  local words=0; for _ in n:gmatch("%S+") do words=words+1 end
  if words >= 5 then return true end
  if l:find("it seems",1,true) or l:find("you think",1,true) or l:find("lost wifi",1,true) or l:find("msg me",1,true) then return true end
  return false
end
function BLFG_5616_GuildNameFromAd(text)
  local s = tostring(text or "")
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return "" end
  local g = s:match("<([^>]+)>")
  if g then g=BLFG_5616_CleanDecoratedName(g); if not BLFG_5616_IsBadGuildName(g) then return g end end
  local pre = s:match("^(.-)%s*%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or s:match("^(.-)%s*%[[Nn][Aa]%]") or s:match("^(.-)%s*%[[Ee][Uu]%]")
  if pre then
    g = BLFG_5616_CleanDecoratedName(pre)
    if not BLFG_5616_IsBadGuildName(g) then return g end
  end
  local l=BLFG_5616_Lower(s)
  if l:find("recruit",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) then
    pre = s:match("^(.-)%s+[Rr]ecruit") or s:match("^(.-)%s+[Dd]iscord")
    if pre then
      g=BLFG_5616_CleanDecoratedName(pre)
      if not BLFG_5616_IsBadGuildName(g) then return g end
    end
  end
  return ""
end
function BLFG_5616_IsGuildAd(text)
  local raw=tostring(text or "")
  local l=BLFG_5616_Lower(raw)
  local gn=BLFG_5616_GuildNameFromAd(raw)
  if gn == "" then return false end
  if raw:find("<[^>]+>") and (l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord",1,true) or l:find("raid",1,true) or l:find("pvp",1,true) or l:find("boss blitz",1,true)) then return true end
  if (raw:find("%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or raw:find("%[[Nn][Aa]%]") or raw:find("%[[Ee][Uu]%]")) and (l:find("recruit",1,true) or l:find("discord",1,true) or l:find("realm first",1,true) or l:find("server",1,true) or l:find("main%-raid",1,true) or l:find("main raid",1,true)) then return true end
  return false
end
BLFG_5612_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_5612_IsGuildAd = BLFG_5616_IsGuildAd
BLFG_5611_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_5611_IsGuildAd = BLFG_5616_IsGuildAd
BLFG_569_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_569_IsGuildAd = BLFG_5616_IsGuildAd
BLFG_568_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_567_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_565_GuildNameFromAd = BLFG_5616_GuildNameFromAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5616_IsGuildAd

function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
  guildName = BLFG_5616_CleanDecoratedName(guildName or BLFG_5616_GuildNameFromAd(text or "") or "")
  if BLFG_5616_IsBadGuildName(guildName) then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.chatGuildListings = BronzeLFG_DB.chatGuildListings or {}
  self.chatGuildListings = self.chatGuildListings or {}
  local key = BLFG_5616_Normalize(guildName)
  local row = self.chatGuildListings[key] or BronzeLFG_DB.chatGuildListings[key] or {}
  row.name = guildName; row.guild = guildName; row.status = "Chat Only"; row.source = "Chat"
  row.online = tonumber(row.online or 0) or 0
  row.posts = (tonumber(row.posts or 0) or 0) + 1
  row.contact = tostring(author or row.contact or ""):gsub("%-.*", "")
  row.postContact = row.contact
  row.lastPost = tostring(text or row.lastPost or "")
  row.message = row.lastPost
  row.lastPostSeen = time and time() or 0; row.lastPostTime = "now"
  row.recruiting = "Recruiting"; row.postKind = "Recruiting"
  row.focus = self.GetRawFocusTags and self:GetRawFocusTags("", row.lastPost) or row.focus or "Unknown"
  if row.focus == "" then row.focus = "Unknown" end
  row.focusText = row.focus; row.postFocus = row.focus; row.focusRaw = row.focus
  row.discord = BLFG_ExtractDiscord and BLFG_ExtractDiscord(row.lastPost) or row.discord or ""
  row.chatOnly = true; row.sessionOnly = true
  self.chatGuildListings[key] = row; BronzeLFG_DB.chatGuildListings[key] = row
end

BLFG_5616_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw=tostring(text or "")
  local r = BLFG_5616_OldAddPublicGroup and BLFG_5616_OldAddPublicGroup(self, author, text, channelName)
  if BLFG_5616_IsGuildAd(raw) then
    local gn=BLFG_5616_GuildNameFromAd(raw)
    if gn ~= "" then self:UpsertGuildBrowserChatListing(gn, author, raw) end
    if self.guildPanel and self.guildPanel:IsVisible() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  end
  return r
end

BLFG_5616_OldInlinePublicChatLinkForMessage = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw=tostring(msgText or "")
  if raw ~= "" and BLFG_5616_IsGuildAd(raw) then
    local gn=BLFG_5616_GuildNameFromAd(raw)
    if gn ~= "" then
      self:UpsertGuildBrowserChatListing(gn, author, raw)
      local link = self.GuildChatLink and self:GuildChatLink(gn) or nil
      if link then return raw .. " " .. link end
      return raw .. " [" .. gn .. "]"
    end
  end
  return BLFG_5616_OldInlinePublicChatLinkForMessage and BLFG_5616_OldInlinePublicChatLinkForMessage(self,msgText,author,channelName) or nil
end

-- Compact footer layout: use 7 rows so the pager/action area has real space.
BLFG_5616_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  -- Let the existing chain rebuild rows/data, then repaint visible rows with 7-per-page.
  if BLFG_5615_ClearStaleGuildSources then BLFG_5615_ClearStaleGuildSources() end
  local _ = BLFG_5616_OldRefreshGuildBrowser and BLFG_5616_OldRefreshGuildBrowser(self, ...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  rows = rows or {}
  local per = 7
  local pages = math.max(1, math.ceil(#rows / per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage = 1 end
  if self.guildPage > pages then self.guildPage = pages end
  local start = ((self.guildPage - 1) * per) + 1
  if self.guildCountText then self.guildCountText:SetText("Guilds found: "..#rows.."  |  Live: "..tostring(self.guildLiveCount or 0).."  |  Chat: "..tostring(self.guildPostOnlyCount or 0).."  |  /who: "..tostring(self.guildWhoCount or 0)) end
  self.selectedGuildData = nil
  for i,r in ipairs(self.guildRows or {}) do
    local g = (i <= per) and rows[start + i - 1] or nil
    if g and r and r.Show then
      r:Show(); r.guildName=g.name; r.guildData=g
      if string.lower(tostring(self.selectedGuild or "")) == string.lower(tostring(g.name or "")) then self.selectedGuild = tostring(g.name or self.selectedGuild or ""); r:SetBackdropColor(.25,.25,.05,.95); self.selectedGuildData=g else r:SetBackdropColor(0,0,0,.80) end
      if r.guild then r.guild:SetText((g.favorite and "|cffffd100â˜… |r" or "")..tostring(g.name or "")) end
      if r.online then r.online:SetText(tostring(g.online or 0)) end
      if r.status then r.status:SetText(shortenPublicText(g.status or "Unknown",10)) end
      if r.recruiting then r.recruiting:SetText(shortenPublicText(g.recruiting or "Unknown",12)) end
      if r.focus then r.focus:SetText(guildFocusTagsText(g.focus or "--",1)) end
      if r.fav then r.fav:SetText(g.favorite and "â˜…" or "") end
    elseif r then
      r.guildName=nil; r.guildData=nil
      if r.guild then r.guild:SetText("") end; if r.online then r.online:SetText("") end; if r.status then r.status:SetText("") end; if r.recruiting then r.recruiting:SetText("") end; if r.focus then r.focus:SetText("") end; if r.fav then r.fav:SetText("") end
      r:SetBackdropColor(0,0,0,.80); r:Hide()
    end
  end
  -- Hide all old pager attempts.
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615}) do if b then b:Hide() end end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615}) do if l then l:Hide() end end
  if not self.guildPageUpButton5616 then
    self.guildPageUpButton5616=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageUpButton5616:SetWidth(82); self.guildPageUpButton5616:SetHeight(24); self.guildPageUpButton5616:SetText("Up"); self.guildPageUpButton5616:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
    self.guildPageDownButton5616=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageDownButton5616:SetWidth(82); self.guildPageDownButton5616:SetHeight(24); self.guildPageDownButton5616:SetText("Down"); self.guildPageDownButton5616:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
    self.guildPageLabel5616=self.guildList:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  end
  self.guildPageUpButton5616:ClearAllPoints(); self.guildPageUpButton5616:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 14, 38)
  self.guildPageDownButton5616:ClearAllPoints(); self.guildPageDownButton5616:SetPoint("LEFT", self.guildPageUpButton5616, "RIGHT", 8, 0)
  self.guildPageLabel5616:ClearAllPoints(); self.guildPageLabel5616:SetPoint("LEFT", self.guildPageDownButton5616, "RIGHT", 14, 0)
  BLFG_SF_SafeSetEnabled(self.guildPageUpButton5616, self.guildPage > 1); BLFG_SF_SafeSetEnabled(self.guildPageDownButton5616, self.guildPage < pages); self.guildPageLabel5616:SetText("Page "..self.guildPage.." / "..pages)
  self.guildPageUpButton5616:Show(); self.guildPageDownButton5616:Show(); self.guildPageLabel5616:Show()
  if self.guildFooter then self.guildFooter:ClearAllPoints(); self.guildFooter:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 14, 66) end
  if self.guildClearListingsBtn then self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetPoint("BOTTOMRIGHT", self.guildRecruitCreatorBtn or self.guildList, self.guildRecruitCreatorBtn and "BOTTOMLEFT" or "BOTTOMRIGHT", self.guildRecruitCreatorBtn and -12 or -330, self.guildRecruitCreatorBtn and 0 or 12) end
  if self.RefreshGuildDetailPanel then self:RefreshGuildDetailPanel(self.selectedGuildData or rows[start]) end
end

-- Move dungeon dropdown further left and keep the menu inside the settings panel.
function BLFG_5616_PositionDungeonDropdown()
  if BLFG and BLFG.dungeonAlertDropdown5615 and BLFG.optNotifyDungeon then
    BLFG.dungeonAlertDropdown5615:ClearAllPoints()
    BLFG.dungeonAlertDropdown5615:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 120, -2)
  end
end
BLFG_5616_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5616_OldShowOptions and BLFG_5616_OldShowOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5616_PositionDungeonDropdown()
  return r
end
BLFG_5616_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5616_OldBuildOptions and BLFG_5616_OldBuildOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5616_PositionDungeonDropdown()
  return r
end

-- ============================================================
-- BronzeLFG v5.6.17 - layout alignment + OPPOSITION public/guild upsert
-- ============================================================
BRONZELFG_VERSION = "5.6.17"
if BLFG then BLFG.version = "5.6.17" end

BLFG_5617_SESSION_START = time and time() or 0

function BLFG_5617_Lower(s) return string.lower(tostring(s or "")) end
function BLFG_5617_Clean(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%s*[Rr][Tt]%d+%s*}", " "):gsub("%[[Rr][Tt]%d+%]", " ")
  s = s:gsub("[â˜ â˜…â˜†â€¢â—â—†â—‡â–ºâ–¶âž¤]+", " ")
  s = s:gsub("^%s*[%p%s]+", ""):gsub("[%p%s]+%s*$", "")
  s = s:gsub("%s+", " ")
  return s
end
function BLFG_5617_Normalize(s)
  s = BLFG_5617_Clean(s):lower()
  s = s:gsub("[^%w]+", "")
  return s
end
function BLFG_5617_IsBadGuildName(n)
  n = BLFG_5617_Clean(n)
  if n == "" or string.len(n) < 2 or string.len(n) > 34 then return true end
  local l = BLFG_5617_Lower(n)
  local words = 0; for _ in n:gmatch("%S+") do words = words + 1 end
  if words >= 5 then return true end
  if l:find("it seems",1,true) or l:find("you think",1,true) or l:find("lost wifi",1,true) or l:find("msg me",1,true) then return true end
  return false
end
function BLFG_5617_GuildNameFromAd(text)
  local s = tostring(text or "")
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return "" end
  -- Best case: visible guild tag.
  local g = s:match("<([^>]+)>")
  if g then g = BLFG_5617_Clean(g); if not BLFG_5617_IsBadGuildName(g) then return g end end
  -- Decorated server-region opener: {rt8}OPPOSITION{rt8} [NA/EU]
  local pre = s:match("^(.-)%s*%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or s:match("^(.-)%s*%[[Nn][Aa]%]") or s:match("^(.-)%s*%[[Ee][Uu]%]")
  if pre then
    g = BLFG_5617_Clean(pre)
    if not BLFG_5617_IsBadGuildName(g) then return g end
  end
  -- Fallback for guild name before recruitment word.
  local l = BLFG_5617_Lower(s)
  if l:find("recruit",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) then
    pre = s:match("^(.-)%s+[Rr]ecruit") or s:match("^(.-)%s+[Dd]iscord")
    if pre then g = BLFG_5617_Clean(pre); if not BLFG_5617_IsBadGuildName(g) then return g end end
  end
  return ""
end
function BLFG_5617_IsGuildAd(text)
  local raw = tostring(text or "")
  local l = BLFG_5617_Lower(raw)
  local gn = BLFG_5617_GuildNameFromAd(raw)
  if gn == "" then return false end
  local hasRecruitSignal = l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord",1,true) or l:find("realm first",1,true) or l:find("server 3rd",1,true) or l:find("main%-raid",1,true) or l:find("main raid",1,true) or l:find("pvp",1,true) or l:find("boss blitz",1,true)
  if not hasRecruitSignal then return false end
  if raw:find("<[^>]+>") then return true end
  if raw:find("%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or raw:find("%[[Nn][Aa]%]") or raw:find("%[[Ee][Uu]%]") then return true end
  return false
end
-- Override older aliases that the stacked wrappers still call.
BLFG_5616_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_5616_IsGuildAd = BLFG_5617_IsGuildAd
BLFG_5612_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_5612_IsGuildAd = BLFG_5617_IsGuildAd
BLFG_5611_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_5611_IsGuildAd = BLFG_5617_IsGuildAd
BLFG_569_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_569_IsGuildAd = BLFG_5617_IsGuildAd
BLFG_568_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_567_GuildNameFromAd = BLFG_5617_GuildNameFromAd; BLFG_565_GuildNameFromAd = BLFG_5617_GuildNameFromAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5617_IsGuildAd

function BLFG_5617_ForcePublicGuild(self, author, raw)
  if not self or not BLFG_5617_IsGuildAd(raw) then return end
  self.publicGroups = self.publicGroups or {}
  local name = tostring(author or ""):gsub("%-.*", "")
  if name == "" then name = "Unknown" end
  local guildName = BLFG_5617_GuildNameFromAd(raw)
  if guildName == "" then return end
  local key = "guild-"..BLFG_5617_Normalize(guildName).."-"..BLFG_5617_Normalize(name)
  local row = self.publicGroups[key] or {}
  row.id = key
  row.player = name
  row.message = BLFG_5617_Clean(raw)
  row.rawMessage = raw
  row.channel = "Public"
  row.type = "Guild"
  row.activity = "Guild Recruitment"
  row.roles = "Recruiting"
  row.intent = "Recruiting"
  row.tags = "Guild"
  row.guild = guildName
  row.ilevel = ""
  row.score = 999
  row.created = row.created or (now and now() or time())
  row.seen = now and now() or time()
  row.source = "Chat"
  self.publicGroups[key] = row
end

function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
  guildName = BLFG_5617_Clean(guildName or BLFG_5617_GuildNameFromAd(text or "") or "")
  if BLFG_5617_IsBadGuildName(guildName) then return end
  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.chatGuildListings = BronzeLFG_DB.chatGuildListings or {}
  self.chatGuildListings = self.chatGuildListings or {}
  local key = BLFG_5617_Normalize(guildName)
  local row = self.chatGuildListings[key] or {}
  row.name = guildName; row.guild = guildName; row.status = "Chat Only"; row.source = "Chat"
  row.online = tonumber(row.online or 0) or 0
  row.posts = (tonumber(row.posts or 0) or 0) + 1
  row.contact = tostring(author or row.contact or ""):gsub("%-.*", "")
  row.postContact = row.contact
  row.lastPost = tostring(text or row.lastPost or "")
  row.message = row.lastPost
  row.lastPostSeen = time and time() or 0; row.lastPostTime = "now"
  row.recruiting = "Recruiting"; row.postKind = "Recruiting"
  row.focus = self.GetRawFocusTags and self:GetRawFocusTags("", row.lastPost) or row.focus or "Unknown"
  if row.focus == "" then row.focus = "Unknown" end
  row.focusText = row.focus; row.postFocus = row.focus; row.focusRaw = row.focus
  row.discord = BLFG_ExtractDiscord and BLFG_ExtractDiscord(row.lastPost) or row.discord or ""
  row.chatOnly = true; row.sessionOnly = true; row.createdSession = BLFG_5617_SESSION_START
  self.chatGuildListings[key] = row
  -- Keep current session available, but do not rely on saved DB for reload persistence.
  BronzeLFG_DB.chatGuildListings[key] = row
end

BLFG_5617_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw = tostring(text or "")
  if BLFG_5617_IsGuildAd(raw) then
    local gn = BLFG_5617_GuildNameFromAd(raw)
    if gn ~= "" then self:UpsertGuildBrowserChatListing(gn, author, raw) end
    BLFG_5617_ForcePublicGuild(self, author, raw)
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
    if self.guildPanel and self.guildPanel:IsVisible() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
    return
  end
  return BLFG_5617_OldAddPublicGroup and BLFG_5617_OldAddPublicGroup(self, author, text, channelName)
end

BLFG_5617_OldInlinePublicChatLinkForMessage = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw = tostring(msgText or "")
  if BLFG_5617_IsGuildAd(raw) then
    local gn = BLFG_5617_GuildNameFromAd(raw)
    if gn ~= "" then
      self:UpsertGuildBrowserChatListing(gn, author, raw)
      BLFG_5617_ForcePublicGuild(self, author, raw)
      local link = self.GuildChatLink and self:GuildChatLink(gn) or nil
      return raw .. " " .. (link or ("["..gn.."]"))
    end
  end
  return BLFG_5617_OldInlinePublicChatLinkForMessage and BLFG_5617_OldInlinePublicChatLinkForMessage(self, msgText, author, channelName) or nil
end

-- Stop older display-time cleanup from deleting current-session chat guilds every refresh.
function BLFG_5615_ClearStaleGuildSources()
  BronzeLFG_DB = BronzeLFG_DB or {}
  -- Remove only rows explicitly older than this session; keep current chat rows alive until reload.
  local function purge(tbl)
    if not tbl then return end
    for k,g in pairs(tbl) do
      if g and g.sessionOnly and tonumber(g.createdSession or 0) > 0 and tonumber(g.createdSession or 0) < BLFG_5617_SESSION_START then tbl[k] = nil end
    end
  end
  purge(BLFG and BLFG.chatGuildListings)
  purge(BronzeLFG_DB.chatGuildListings)
end

BLFG_5617_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  local rows,a,b,c = BLFG_5617_OldGetGuildRows and BLFG_5617_OldGetGuildRows(self, ...) or {}
  rows = rows or {}
  local have = {}
  for _,g in ipairs(rows) do have[BLFG_5617_Normalize(g and (g.name or g.guild or "") or "")] = true end
  for key,g in pairs(self.chatGuildListings or {}) do
    if g and g.name and not have[BLFG_5617_Normalize(g.name)] then table.insert(rows, g) end
  end
  return rows,a,b,c
end

-- Guild Browser layout: six visible rows, centered pager, action buttons below it.
BLFG_5617_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  local _ = BLFG_5617_OldRefreshGuildBrowser and BLFG_5617_OldRefreshGuildBrowser(self, ...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  rows = rows or {}
  local per = 6
  local pages = math.max(1, math.ceil(#rows / per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage = 1 end
  if self.guildPage > pages then self.guildPage = pages end
  local start = ((self.guildPage - 1) * per) + 1
  self.selectedGuildData = nil
  for i,r in ipairs(self.guildRows or {}) do
    local g = (i <= per) and rows[start + i - 1] or nil
    if g and r then
      r:Show(); r.guildName = g.name; r.guildData = g
      if string.lower(tostring(self.selectedGuild or "")) == string.lower(tostring(g.name or "")) then self.selectedGuild = tostring(g.name or self.selectedGuild or ""); r:SetBackdropColor(.25,.25,.05,.95); self.selectedGuildData = g else r:SetBackdropColor(0,0,0,.80) end
      if r.guild then r.guild:SetText((g.favorite and "|cffffd100â˜… |r" or "")..tostring(g.name or "")) end
      if r.online then r.online:SetText(tostring(g.online or 0)) end
      if r.status then r.status:SetText(shortenPublicText(g.status or "Unknown",10)) end
      if r.recruiting then r.recruiting:SetText(shortenPublicText(g.recruiting or "Unknown",12)) end
      if r.focus then r.focus:SetText(guildFocusTagsText(g.focus or "--",1)) end
      if r.fav then r.fav:SetText(g.favorite and "â˜…" or "") end
    elseif r then
      r.guildName=nil; r.guildData=nil
      if r.guild then r.guild:SetText("") end; if r.online then r.online:SetText("") end; if r.status then r.status:SetText("") end; if r.recruiting then r.recruiting:SetText("") end; if r.focus then r.focus:SetText("") end; if r.fav then r.fav:SetText("") end
      r:SetBackdropColor(0,0,0,.80); r:Hide()
    end
  end
  if self.guildCountText then
    local c = self.guildSourceCounts or {}
    self.guildCountText:SetText("Guilds Found: "..tostring(c.All or #rows).."  |  Recruiting: "..tostring(c.Recruiting or 0).."  |  Network: "..tostring(c.Network or 0).."  |  Seen via /who: "..tostring(c.Who or 0))
  end
  if self.guildSourceFilterButtons then
    local activeSource = tostring(self.guildSourceFilter or "All")
    for key,b in pairs(self.guildSourceFilterButtons) do
      if b and b.LockHighlight then
        if key == activeSource then b:LockHighlight() else b:UnlockHighlight() end
      end
    end
  end
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616}) do if b then b:Hide() end end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616}) do if l then l:Hide() end end
  if not self.guildPageUpButton5617 then
    self.guildPageUpButton5617 = CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageUpButton5617:SetWidth(82); self.guildPageUpButton5617:SetHeight(24); self.guildPageUpButton5617:SetText("Up"); self.guildPageUpButton5617:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
    self.guildPageDownButton5617 = CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageDownButton5617:SetWidth(82); self.guildPageDownButton5617:SetHeight(24); self.guildPageDownButton5617:SetText("Down"); self.guildPageDownButton5617:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
    self.guildPageLabel5617 = self.guildList:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  end
  self.guildPageDownButton5617:ClearAllPoints(); self.guildPageDownButton5617:SetPoint("BOTTOM", self.guildList, "BOTTOM", -42, 44)
  self.guildPageUpButton5617:ClearAllPoints(); self.guildPageUpButton5617:SetPoint("RIGHT", self.guildPageDownButton5617, "LEFT", -12, 0)
  self.guildPageLabel5617:ClearAllPoints(); self.guildPageLabel5617:SetPoint("LEFT", self.guildPageDownButton5617, "RIGHT", 18, 0)
  BLFG_SF_SafeSetEnabled(self.guildPageUpButton5617, self.guildPage > 1); BLFG_SF_SafeSetEnabled(self.guildPageDownButton5617, self.guildPage < pages); self.guildPageLabel5617:SetText("Page "..self.guildPage.." / "..pages)
  self.guildPageUpButton5617:Show(); self.guildPageDownButton5617:Show(); self.guildPageLabel5617:Show()
  if self.guildClearListingsBtn then self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 82, 12) end
  if self.guildRecruitCreatorBtn then self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetPoint("LEFT", self.guildClearListingsBtn or self.guildList, "RIGHT", 24, 0) end
  if self.guildShowBronzeNetBtn then self.guildShowBronzeNetBtn:ClearAllPoints(); self.guildShowBronzeNetBtn:SetPoint("LEFT", self.guildRecruitCreatorBtn or self.guildList, "RIGHT", 24, 0) end
  if self.RefreshGuildDetailPanel then self:RefreshGuildDetailPanel(self.selectedGuildData or rows[start]) end
end

-- Options layout: make Dungeon dropdown match Keystone/Raid/Event width and alignment.
function BLFG_5617_PositionDungeonDropdown()
  if not BLFG or not BLFG.optionsPanel then return end
  if BLFG.dungeonAlertDropdown5615 then
    BLFG.dungeonAlertDropdown5615:ClearAllPoints()
    BLFG.dungeonAlertDropdown5615:SetPoint("TOPLEFT", BLFG.optionsPanel, "TOPLEFT", 625, -358)
    UIDropDownMenu_SetWidth(BLFG.dungeonAlertDropdown5615, 150)
    BLFG.dungeonAlertDropdown5615:Show()
  end
end
BLFG_5617_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5617_OldBuildOptions and BLFG_5617_OldBuildOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5617_PositionDungeonDropdown()
  return r
end
BLFG_5617_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5617_OldShowOptions and BLFG_5617_OldShowOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5617_PositionDungeonDropdown()
  return r
end

-- One-time reload cleanup: chat-only guilds should not survive reloads.
BLFG_5617_CleanupFrame = CreateFrame("Frame")
BLFG_5617_CleanupFrame:RegisterEvent("PLAYER_LOGIN")
BLFG_5617_CleanupFrame:SetScript("OnEvent", function()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.chatGuildListings = {}
  if BLFG then BLFG.chatGuildListings = {} end
  if BLFG and BLFG.versionText then BLFG.versionText:SetText("") end
end)

-- ============================================================
-- BronzeLFG v5.6.18 - safe guild refresh, OPPOSITION parser, dropdown alignment
-- ============================================================
BRONZELFG_VERSION = "5.6.18"
if BLFG then BLFG.version = "5.6.18" end

BLFG_5618_SESSION_START = time and time() or 0

function BLFG_5618_StripChatPrefix(s)
  s = tostring(s or "")
  -- When a full chat line leaks into parsing, keep only the actual message after the sender colon.
  local m = s:match("^.-%]:%s*(.+)$")
  if m and m ~= "" then return m end
  m = s:match("^.-:%s*(.+)$")
  if m and m ~= "" and not s:match("^https?://") then return m end
  return s
end
function BLFG_5618_Clean(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%s*[Rr][Tt]%d+%s*}", " "):gsub("%[[Rr][Tt]%d+%]", " ")
  s = s:gsub("[â˜ â˜…â˜†â€¢â—â—†â—‡â–ºâ–¶âž¤]+", " ")
  s = s:gsub("^%s*[%p%s]+", ""):gsub("[%p%s]+%s*$", "")
  s = s:gsub("%s+", " ")
  return s
end
function BLFG_5618_Norm(s) return (BLFG_5618_Clean(s):lower():gsub("[^%w]+", "")) end
function BLFG_5618_BadGuildName(n)
  n = BLFG_5618_Clean(n)
  if n == "" or string.len(n) < 2 or string.len(n) > 34 then return true end
  local l = string.lower(n)
  local words = 0; for _ in n:gmatch("%S+") do words = words + 1 end
  if words >= 5 then return true end
  if l:find("it seems",1,true) or l:find("you think",1,true) or l:find("lost wifi",1,true) or l:find("msg me",1,true) or l:find("lfm ",1,true) or l:find("need ",1,true) then return true end
  return false
end
function BLFG_5618_GuildNameFromAd(text)
  local s = BLFG_5618_StripChatPrefix(text)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return "" end
  local g = s:match("<([^>]+)>")
  if g then g=BLFG_5618_Clean(g); if not BLFG_5618_BadGuildName(g) then return g end end
  -- Decorated opener before region tag: OPPOSITION [NA/EU]
  local pre = s:match("^(.-)%s*%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or s:match("^(.-)%s*%[[Nn][Aa]%]") or s:match("^(.-)%s*%[[Ee][Uu]%]")
  if pre then g=BLFG_5618_Clean(pre); if not BLFG_5618_BadGuildName(g) then return g end end
  -- Very strict fallback: only before recruiting/discord, not normal chatter.
  local l = string.lower(s)
  if l:find("recruit",1,true) or l:find("discord.gg",1,true) or l:find("discord.com/invite",1,true) then
    pre = s:match("^(.-)%s+[Rr]ecruit") or s:match("^(.-)%s+[Dd]iscord")
    if pre then g=BLFG_5618_Clean(pre); if not BLFG_5618_BadGuildName(g) then return g end end
  end
  return ""
end
function BLFG_5618_IsGuildAd(text)
  local msg = BLFG_5618_StripChatPrefix(text)
  local l = string.lower(msg)
  local gn = BLFG_5618_GuildNameFromAd(msg)
  if gn == "" then return false end
  local signal = l:find("recruit",1,true) or l:find("guild",1,true) or l:find("discord",1,true) or l:find("realm first",1,true) or l:find("server 3rd",1,true) or l:find("main%-raid",1,true) or l:find("main raid",1,true) or l:find("boss blitz",1,true) or l:find("raids",1,true)
  if not signal then return false end
  if msg:find("<[^>]+>") then return true end
  if msg:find("%[[Nn][Aa]%s*/%s*[Ee][Uu]%]") or msg:find("%[[Nn][Aa]%]") or msg:find("%[[Ee][Uu]%]") then return true end
  return false
end
BLFG_5617_GuildNameFromAd = BLFG_5618_GuildNameFromAd; BLFG_5617_IsGuildAd = BLFG_5618_IsGuildAd
BLFG_5616_GuildNameFromAd = BLFG_5618_GuildNameFromAd; BLFG_5616_IsGuildAd = BLFG_5618_IsGuildAd
BLFG_5612_GuildNameFromAd = BLFG_5618_GuildNameFromAd; BLFG_5612_IsGuildAd = BLFG_5618_IsGuildAd
BLFG_569_GuildNameFromAd = BLFG_5618_GuildNameFromAd; BLFG_569_IsGuildAd = BLFG_5618_IsGuildAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5618_IsGuildAd

function BLFG_5618_ForcePublicGuild(self, author, raw)
  if not self or not BLFG_5618_IsGuildAd(raw) then return end
  self.publicGroups = self.publicGroups or {}
  local guildName = BLFG_5618_GuildNameFromAd(raw)
  if guildName == "" then return end
  local name = tostring(author or ""):gsub("%-.*", "")
  local key = "guild-"..BLFG_5618_Norm(guildName).."-"..BLFG_5618_Norm(name)
  local row = self.publicGroups[key] or {}
  row.key=key; row.player=name; row.guild=guildName; row.type="Guild"; row.activity="Guild Recruitment"; row.roles="Recruiting"; row.intent="Recruiting"; row.tags="Guild"; row.source="Chat"
  row.message=BLFG_5618_Clean(BLFG_5618_StripChatPrefix(raw)); row.rawMessage=raw
  row.created=row.created or (now and now() or time()); row.seen=now and now() or time(); row.sessionOnly=true; row.createdSession=BLFG_5618_SESSION_START
  self.publicGroups[key]=row
end
function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
  guildName = BLFG_5618_Clean(guildName or BLFG_5618_GuildNameFromAd(text or "") or "")
  if BLFG_5618_BadGuildName(guildName) then return end
  self.chatGuildListings = self.chatGuildListings or {}
  local key = BLFG_5618_Norm(guildName)
  local row = self.chatGuildListings[key] or {}
  row.name=guildName; row.guild=guildName; row.status="Chat Only"; row.source="Chat"; row.chatOnly=true; row.sessionOnly=true; row.createdSession=BLFG_5618_SESSION_START
  row.online=tonumber(row.online or 0) or 0; row.posts=(tonumber(row.posts or 0) or 0)+1
  row.contact=tostring(author or row.contact or ""):gsub("%-.*", ""); row.postContact=row.contact
  row.lastPost=BLFG_5618_StripChatPrefix(text or row.lastPost or ""); row.message=row.lastPost; row.lastPostSeen=time and time() or 0; row.lastPostTime="now"
  row.recruiting="Recruiting"; row.postKind="Recruiting"
  row.focus = self.GetRawFocusTags and self:GetRawFocusTags("", row.lastPost) or row.focus or "Unknown"; if row.focus == "" then row.focus="Unknown" end
  row.focusText=row.focus; row.postFocus=row.focus; row.focusRaw=row.focus
  row.discord = BLFG_ExtractDiscord and BLFG_ExtractDiscord(row.lastPost) or row.discord or ""
  self.chatGuildListings[key]=row
  -- Do not write chat-only guild rows to SavedVariables. They are session-only by design.
end

BLFG_5618_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw=tostring(text or "")
  if BLFG_5618_IsGuildAd(raw) then
    local gn=BLFG_5618_GuildNameFromAd(raw)
    if gn ~= "" then self:UpsertGuildBrowserChatListing(gn, author, raw) end
    BLFG_5618_ForcePublicGuild(self, author, raw)
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
    if self.guildPanel and self.guildPanel:IsVisible() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
    return
  end
  return BLFG_5618_OldAddPublicGroup and BLFG_5618_OldAddPublicGroup(self, author, text, channelName)
end
BLFG_5618_OldInlinePublicChatLinkForMessage = BLFG.InlinePublicChatLinkForMessage
function BLFG:RequestPublicGroupsRefresh()
  self._publicGroupsDirty = true
  if self._publicRefreshQueued then return end
  self._publicRefreshQueued = true
  if not self._publicRefreshFrame then
    self._publicRefreshFrame = CreateFrame("Frame")
    self._publicRefreshFrame:Hide()
    self._publicRefreshFrame:SetScript("OnUpdate", function(f)
      f:Hide()
      if BLFG then
        BLFG._publicRefreshQueued = nil
        if BLFG._publicGroupsDirty and BLFG.RefreshPublicGroups and BLFG.publicRows then
          BLFG._publicGroupsDirty = nil
          BLFG:RefreshPublicGroups()
        end
      end
    end)
  end
  self._publicRefreshFrame:Show()
end

function BLFG:SignalFirePublicChatKey(author, text)
  return tostring(author or ""):gsub("%-.*", "") .. "\031" .. tostring(text or "")
end

function BLFG:SignalFireShouldSkipPublicChatEvent(author, text)
  local stamp = now and now() or (time and time() or 0)
  local key = self:SignalFirePublicChatKey(author, text)
  local t = self._inlinePublicChatEventSeen and self._inlinePublicChatEventSeen[key]
  return t and (stamp - t) <= 2
end
function BLFG:InlinePublicChatLinkForMessage(msgText, author, channelName)
  local raw=tostring(msgText or "")
  if raw == "" then return nil end
  if raw:find("|Hblfg:", 1, true) then return nil end

  local stamp = now and now() or (time and time() or 0)
  local cacheKey = self.SignalFirePublicChatKey and self:SignalFirePublicChatKey(author, raw) or (tostring(author or "") .. "\031" .. raw)
  self._inlinePublicChatCache = self._inlinePublicChatCache or {}
  local cached = self._inlinePublicChatCache[cacheKey]
  if cached and cached.t and (stamp - cached.t) <= 2 then return cached.out end

  -- Guild ads are handled here and may produce guild links.
  if BLFG_5618_IsGuildAd(raw) then
    local gn=BLFG_5618_GuildNameFromAd(raw)
    if gn ~= "" then
      self:UpsertGuildBrowserChatListing(gn, author, raw); BLFG_5618_ForcePublicGuild(self, author, raw)
      local out
      if self.InsertGuildLinkInText then out = self:InsertGuildLinkInText(raw, gn) end
      if not out then
        local link = self.GuildChatLink and self:GuildChatLink(gn) or nil
        out = raw.." "..(link or ("["..gn.."]"))
      end
      self._inlinePublicChatCache[cacheKey] = {t=stamp, out=out}
      return out
    end
  end

  local invLow = string.lower(raw)
  if string.find(invLow, "invasion", 1, true) and (string.find(invLow, "lfm", 1, true) or string.find(invLow, "need", 1, true)) then
    local invName = string.match(raw, "[Ll][Ff][Mm]%s+(.+)%s+[Ii]nvasion") or string.match(raw, "(.+)%s+[Ii]nvasion") or "Invasion"
    invName = tostring(invName or "Invasion"):gsub("%s*%-.*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if invName == "" then invName = "Invasion" end
    local row = self.UpsertInvasionPublicListing and self:UpsertInvasionPublicListing({name=invName}, author) or nil
    if row then
      row.message = raw
      row.channel = channelName or "Public"
      if self.RequestPublicGroupsRefresh then self:RequestPublicGroupsRefresh() elseif self.RefreshPublicGroups then self:RefreshPublicGroups() end
      local link = self.PublicChatLink and self:PublicChatLink(row) or nil
      local out = link and (raw .. " " .. link) or nil
      self._inlinePublicChatCache[cacheKey] = {t=stamp, out=out}
      return out
    end
  end
  -- Stale-link and performance guard: only the current LFG/LFM line may create
  -- a public link, and it must use the row touched by this exact parse.
  if not (containsLFG and containsLFG(raw)) then
    self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}
    return nil
  end

  self._inlinePublicChatEventSeen = self._inlinePublicChatEventSeen or {}
  self._inlinePublicChatEventSeen[cacheKey] = stamp
  self._lastPublicGroupTouched = nil
  self._lastPublicGroupTouchedKey = nil
  self._suppressPublicRefreshInChatLink = true
  local ok = pcall(function() self:AddPublicGroup(author, raw, channelName or "Public") end)
  self._suppressPublicRefreshInChatLink = nil
  if not ok then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end

  local g = self._lastPublicGroupTouched
  if not g or not g.id then self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}; return nil end
  local cleanRaw = cleanPublicChatText and cleanPublicChatText(raw) or raw
  local cleanMsg = cleanPublicChatText and cleanPublicChatText(g.message or "") or tostring(g.message or "")
  local cleanAuthor = tostring(author or ""):gsub("%-.*", "")
  if tostring(g.player or "") ~= cleanAuthor or cleanMsg ~= cleanRaw then
    self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}
    return nil
  end
  if g.type == "Guild" or g.type == "Social" or g.type == "Other" then
    self._inlinePublicChatCache[cacheKey] = {t=stamp, out=nil}
    return nil
  end

  local link = self.PublicChatLink and self:PublicChatLink(g) or nil
  local out = link and (raw .. " " .. link) or nil
  self._inlinePublicChatCache[cacheKey] = {t=stamp, out=out}
  return out
end

BLFG_5618_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  local base = BLFG_5618_OldGetGuildRows and BLFG_5618_OldGetGuildRows(self, ...) or {}
  local rows = {}; local have = {}; local currentChat = self.chatGuildListings or {}
  for _,g in ipairs(base or {}) do
    local nm = g and (g.name or g.guild or "") or ""
    local n = BLFG_5618_Norm(nm)
    local isOldChat = g and ((g.chatOnly or g.status == "Chat Only" or g.source == "Chat") and not currentChat[n])
    if g and nm ~= "" and not isOldChat and not have[n] then table.insert(rows,g); have[n]=true end
  end
  for _,g in pairs(currentChat) do
    local n = BLFG_5618_Norm(g and (g.name or g.guild or "") or "")
    if g and n ~= "" and not have[n] then table.insert(rows,g); have[n]=true end
  end
  return rows
end

-- Final safe guild browser renderer. Does not call older RefreshGuildBrowser wrappers, avoiding SetPoint dependency loops.
function BLFG:RefreshGuildBrowser(...)
  local rows = self.GetGuildRows and self:GetGuildRows() or {}; rows = rows or {}
  local per = 6
  local pages = math.max(1, math.ceil(#rows/per))
  self.guildPage = tonumber(self.guildPage or 1) or 1
  if self.guildPage < 1 then self.guildPage=1 end; if self.guildPage > pages then self.guildPage=pages end
  local start = ((self.guildPage-1)*per)+1
  self.selectedGuildData = nil
  if self.guildCountText then
    local c = self.guildSourceCounts or {}
    self.guildCountText:SetText("Guilds Found: "..tostring(c.All or #rows).."  |  Recruiting: "..tostring(c.Recruiting or 0).."  |  Network: "..tostring(c.Network or 0).."  |  Seen via /who: "..tostring(c.Who or 0))
  end
  if self.guildSourceFilterButtons then
    local activeSource = tostring(self.guildSourceFilter or "All")
    for key,b in pairs(self.guildSourceFilterButtons) do
      if b and b.LockHighlight then
        if key == activeSource then b:LockHighlight() else b:UnlockHighlight() end
      end
    end
  end
  for i,r in ipairs(self.guildRows or {}) do
    local g = (i<=per) and rows[start+i-1] or nil
    if g and r then
      r:Show(); r.guildName=g.name; r.guildData=g
      if string.lower(tostring(self.selectedGuild or "")) == string.lower(tostring(g.name or "")) then self.selectedGuild = tostring(g.name or self.selectedGuild or ""); r:SetBackdropColor(.25,.25,.05,.95); self.selectedGuildData=g else r:SetBackdropColor(0,0,0,.80) end
      if r.guild then r.guild:SetText((g.favorite and "|cffffd100â˜… |r" or "")..tostring(g.name or "")) end
      if r.online then r.online:SetText(tostring(g.online or 0)) end
      if r.status then r.status:SetText(BLFG_SFGuildSourceTag and BLFG_SFGuildSourceTag(g) or shortenPublicText(g.status or "Unknown",10)) end
      if r.recruiting then r.recruiting:SetText(shortenPublicText(g.recruiting or "Unknown",12)) end
      if r.focus then r.focus:SetText(guildFocusTagsText(g.focus or "--",1)) end
      if r.fav then r.fav:SetText(g.favorite and "â˜…" or "") end
    elseif r then
      r.guildName=nil; r.guildData=nil; r:SetBackdropColor(0,0,0,.80); r:Hide()
      if r.guild then r.guild:SetText("") end; if r.online then r.online:SetText("") end; if r.status then r.status:SetText("") end; if r.recruiting then r.recruiting:SetText("") end; if r.focus then r.focus:SetText("") end; if r.fav then r.fav:SetText("") end
    end
  end
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616,self.guildPageUpButton5617,self.guildPageDownButton5617}) do if b then b:Hide() end end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616,self.guildPageLabel5617}) do if l then l:Hide() end end
  if not self.guildPageUpButton5618 then
    self.guildPageUpButton5618=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageUpButton5618:SetWidth(82); self.guildPageUpButton5618:SetHeight(24); self.guildPageUpButton5618:SetText("Up"); self.guildPageUpButton5618:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)-1; BLFG:RefreshGuildBrowser() end)
    self.guildPageDownButton5618=CreateFrame("Button", nil, self.guildList, "UIPanelButtonTemplate"); self.guildPageDownButton5618:SetWidth(82); self.guildPageDownButton5618:SetHeight(24); self.guildPageDownButton5618:SetText("Down"); self.guildPageDownButton5618:SetScript("OnClick", function() BLFG.guildPage=(BLFG.guildPage or 1)+1; BLFG:RefreshGuildBrowser() end)
    self.guildPageLabel5618=self.guildList:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
  end
  self.guildPageUpButton5618:ClearAllPoints(); self.guildPageUpButton5618:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 36, 52)
  self.guildPageDownButton5618:ClearAllPoints(); self.guildPageDownButton5618:SetPoint("LEFT", self.guildPageUpButton5618, "RIGHT", 12, 0)
  self.guildPageLabel5618:ClearAllPoints(); self.guildPageLabel5618:SetPoint("LEFT", self.guildPageDownButton5618, "RIGHT", 28, 0)
  BLFG_SF_SafeSetEnabled(self.guildPageUpButton5618, self.guildPage > 1); BLFG_SF_SafeSetEnabled(self.guildPageDownButton5618, self.guildPage < pages); self.guildPageLabel5618:SetText("Page "..self.guildPage.." / "..pages)
  self.guildPageUpButton5618:Show(); self.guildPageDownButton5618:Show(); self.guildPageLabel5618:Show()
  if self.guildClearListingsBtn then self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", self.guildList, "BOTTOMLEFT", 92, 14) end
  if self.guildRecruitCreatorBtn then self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetPoint("LEFT", self.guildClearListingsBtn, "RIGHT", 34, 0) end
  if self.guildShowBronzeNetBtn then self.guildShowBronzeNetBtn:ClearAllPoints(); self.guildShowBronzeNetBtn:SetPoint("LEFT", self.guildRecruitCreatorBtn, "RIGHT", 34, 0) end
  if self.RefreshGuildDetailPanel then self:RefreshGuildDetailPanel(self.selectedGuildData or rows[start]) end
end

function BLFG_5618_PositionDungeonDropdown()
  if BLFG and BLFG.dungeonAlertDropdown5615 and BLFG.optNotifyDungeon then
    BLFG.dungeonAlertDropdown5615:ClearAllPoints()
    BLFG.dungeonAlertDropdown5615:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 170, -2)
    UIDropDownMenu_SetWidth(BLFG.dungeonAlertDropdown5615, 170)
    BLFG.dungeonAlertDropdown5615:Show()
  end
end
BLFG_5618_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5618_OldBuildOptions and BLFG_5618_OldBuildOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5618_PositionDungeonDropdown()
  return r
end
BLFG_5618_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5618_OldShowOptions and BLFG_5618_OldShowOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5618_PositionDungeonDropdown()
  return r
end

-- One-time cleanup of saved stale chat-only guild rows from earlier builds.
BLFG_5618_Cleanup = CreateFrame("Frame")
BLFG_5618_Cleanup:RegisterEvent("PLAYER_LOGIN")
BLFG_5618_Cleanup:SetScript("OnEvent", function()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.chatGuildListings = nil
  if BLFG then BLFG.chatGuildListings = {} end
end)

-- ============================================================
-- BronzeLFG v5.6.19 - final footer alignment + guild ads stay in Guild Browser
-- ============================================================
BRONZELFG_VERSION = "5.6.19"
VERSION = "5.6.19"
if BLFG then BLFG.version = "5.6.19" end

function BLFG_5619_IsChatGuildRow(row)
  if not row then return false end
  local t = tostring(row.type or row.category or "")
  local src = tostring(row.source or "")
  return (t == "Guild" or row.guild or row.guildName) and (src == "Chat" or row.chatOnly or row.sessionOnly)
end

function BLFG_5619_PurgePublicGuildAds(self)
  if not self or not self.publicGroups then return end
  for k,row in pairs(self.publicGroups) do
    if BLFG_5619_IsChatGuildRow(row) then self.publicGroups[k] = nil end
  end
  if BronzeLFG_DB and BronzeLFG_DB.publicGroups then
    for k,row in pairs(BronzeLFG_DB.publicGroups) do
      if BLFG_5619_IsChatGuildRow(row) then BronzeLFG_DB.publicGroups[k] = nil end
    end
  end
end

-- Guild recruitment ads are now intentionally Guild Browser only. They still get clickable chat links,
-- but they no longer create Public Groups rows.
function BLFG_5618_ForcePublicGuild(self, author, raw)
  BLFG_5619_PurgePublicGuildAds(self)
end

BLFG_5619_OldAddPublicGroup = BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local raw = tostring(text or "")
  if BLFG_5618_IsGuildAd and BLFG_5618_IsGuildAd(raw) then
    local gn = BLFG_5618_GuildNameFromAd(raw)
    if gn ~= "" then self:UpsertGuildBrowserChatListing(gn, author, raw) end
    if self.guildPanel and self.guildPanel:IsVisible() and self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
    return
  end
  return BLFG_5619_OldAddPublicGroup and BLFG_5619_OldAddPublicGroup(self, author, text, channelName)
end

BLFG_5619_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  BLFG_5619_PurgePublicGuildAds(self)
  return BLFG_5619_OldRefreshPublicGroups and BLFG_5619_OldRefreshPublicGroups(self, ...)
end

function BLFG_5619_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.19"
    if BLFG.versionText then BLFG.versionText:SetText("") end
    if BLFG.titleText and BLFG.titleText.GetText and tostring(BLFG.titleText:GetText() or ""):find("BronzeLFG") then
      -- title text itself stays BronzeLFG; separate version label is handled above.
    end
  end
end

function BLFG_5619_LayoutGuildFooter(self)
  if not self or not self.guildList then return end
  local parent = self.guildList

  -- Hide older stacked pager controls from previous experimental builds.
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616,self.guildPageUpButton5617,self.guildPageDownButton5617}) do
    if b and b ~= self.guildPageUpButton5618 and b ~= self.guildPageDownButton5618 then b:Hide() end
  end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616,self.guildPageLabel5617}) do
    if l and l ~= self.guildPageLabel5618 then l:Hide() end
  end

  if self.guildPageUpButton5618 then
    self.guildPageUpButton5618:ClearAllPoints()
    self.guildPageUpButton5618:SetWidth(86); self.guildPageUpButton5618:SetHeight(24)
    self.guildPageUpButton5618:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 42, 54)
  end
  if self.guildPageDownButton5618 then
    self.guildPageDownButton5618:ClearAllPoints()
    self.guildPageDownButton5618:SetWidth(86); self.guildPageDownButton5618:SetHeight(24)
    self.guildPageDownButton5618:SetPoint("LEFT", self.guildPageUpButton5618 or parent, self.guildPageUpButton5618 and "RIGHT" or "BOTTOMLEFT", 22, 0)
  end
  if self.guildPageLabel5618 then
    self.guildPageLabel5618:ClearAllPoints()
    self.guildPageLabel5618:SetPoint("LEFT", self.guildPageDownButton5618 or parent, self.guildPageDownButton5618 and "RIGHT" or "BOTTOMLEFT", 34, 0)
  end

  if self.guildClearListingsBtn then
    self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetWidth(150); self.guildClearListingsBtn:SetHeight(26)
    self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 96, 14)
  end
  if self.guildRecruitCreatorBtn then
    self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetWidth(230); self.guildRecruitCreatorBtn:SetHeight(26)
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", parent, "BOTTOM", 10, 14)
  end
  if self.guildShowBronzeNetBtn then
    self.guildShowBronzeNetBtn:ClearAllPoints(); self.guildShowBronzeNetBtn:SetWidth(170); self.guildShowBronzeNetBtn:SetHeight(26)
    self.guildShowBronzeNetBtn:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 14)
  end
end

BLFG_5619_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  return BLFG_5619_OldRefreshGuildBrowser and BLFG_5619_OldRefreshGuildBrowser(self, ...)
end

function BLFG_5619_PositionDungeonDropdown()
  if BLFG and BLFG.dungeonAlertDropdown5615 and BLFG.optNotifyDungeon then
    BLFG.dungeonAlertDropdown5615:ClearAllPoints()
    -- Match the right-column Keystone dropdown width/placement instead of drifting right.
    if BLFG.keystoneAlertDropdown then
      BLFG.dungeonAlertDropdown5615:SetPoint("TOPLEFT", BLFG.keystoneAlertDropdown, "TOPLEFT", 0, -82)
      BLFG.dungeonAlertDropdown5615:SetPoint("TOPRIGHT", BLFG.keystoneAlertDropdown, "TOPRIGHT", 0, -82)
    else
      BLFG.dungeonAlertDropdown5615:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 120, -2)
    end
    UIDropDownMenu_SetWidth(BLFG.dungeonAlertDropdown5615, 170)
    BLFG.dungeonAlertDropdown5615:Show()
  end
end

BLFG_5619_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5619_OldBuildOptions and BLFG_5619_OldBuildOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5619_PositionDungeonDropdown(); BLFG_5619_FixVersionText()
  return r
end
BLFG_5619_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5619_OldShowOptions and BLFG_5619_OldShowOptions(self, ...)
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  BLFG_5619_PositionDungeonDropdown(); BLFG_5619_FixVersionText()
  return r
end

BLFG_5619_Login = CreateFrame("Frame")
BLFG_5619_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5619_Login:SetScript("OnEvent", function()
  BLFG_5619_FixVersionText()
  if BLFG then
    BLFG_5619_PurgePublicGuildAds(BLFG)
    BLFG.chatGuildListings = {}
    if BronzeLFG_DB then BronzeLFG_DB.chatGuildListings = nil end
  end
end)

-- Manual cleanup command for already-captured public guild rows from older builds.
BLFG_5619_OldSlash = SlashCmdList and SlashCmdList["BRONZELFG"]
if SlashCmdList then
  SlashCmdList["BRONZELFG"] = function(msg)
    msg = tostring(msg or "")
    if msg:lower() == "purgepublicguilds" then
      if BLFG then BLFG_5619_PurgePublicGuildAds(BLFG); if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end end
      if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd100SignalFire:|r Purged chat guild ads from Public Groups.") end
      return
    end
    if BLFG_5619_OldSlash then return BLFG_5619_OldSlash(msg) end
  end
end

-- ============================================================
-- BronzeLFG v5.6.20 - focused footer alignment + remove Public Groups Guild tab
-- ============================================================
BRONZELFG_VERSION = "5.6.20"
VERSION = "5.6.20"
if BLFG then BLFG.version = "5.6.20" end

function BLFG_5620_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.20"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end

-- Guild recruitment is now intentionally Guild Browser-only, so the Public Groups Guild filter tab is removed.
function BLFG_5620_LayoutPublicFilterTabs(self)
  if not self or not self.publicFilterButtons then return end
  local order = {"All", "Dungeon", "Raid", "Key", "Event", "LFG", "Social"}
  local widths = {All=62, Dungeon=98, Raid=78, Key=72, Event=86, LFG=70, Social=86}
  local fx = 38
  for _,name in ipairs(order) do
    local b = self.publicFilterButtons[name]
    if b then
      b:ClearAllPoints()
      b:SetWidth(widths[name] or 76)
      b:SetPoint("TOPLEFT", self.publicPanel, "TOPLEFT", fx, -36)
      b:Show()
      fx = fx + (widths[name] or 76) + 8
    end
  end
  if self.publicFilterButtons["Guild"] then
    self.publicFilterButtons["Guild"]:Hide()
  end
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
end

-- Keep footer controls in three clean lanes:
-- pager row above, blue help text below pager, action buttons on the bottom row.
function BLFG_5620_LayoutGuildFooter(self)
  if not self or not self.guildList then return end
  local list = self.guildList

  -- Hide previous experimental pager controls except the active pair.
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616,self.guildPageUpButton5617,self.guildPageDownButton5617}) do
    if b and b ~= self.guildPageUpButton5618 and b ~= self.guildPageDownButton5618 then b:Hide() end
  end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616,self.guildPageLabel5617}) do
    if l and l ~= self.guildPageLabel5618 then l:Hide() end
  end

  if self.guildPageUpButton5618 then
    self.guildPageUpButton5618:ClearAllPoints()
    self.guildPageUpButton5618:SetWidth(78); self.guildPageUpButton5618:SetHeight(24)
    self.guildPageUpButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 36, 62)
  end
  if self.guildPageDownButton5618 then
    self.guildPageDownButton5618:ClearAllPoints()
    self.guildPageDownButton5618:SetWidth(78); self.guildPageDownButton5618:SetHeight(24)
    self.guildPageDownButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 124, 62)
  end
  if self.guildPageLabel5618 then
    self.guildPageLabel5618:ClearAllPoints()
    self.guildPageLabel5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 246, 68)
  end

  if self.guildFooter then
    self.guildFooter:ClearAllPoints()
    self.guildFooter:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 14, 43)
    self.guildFooter:SetWidth(520)
  end

  if self.guildClearListingsBtn then
    self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetWidth(120); self.guildClearListingsBtn:SetHeight(26)
    self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 42, 12)
  end
  if self.guildRecruitCreatorBtn then
    self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetWidth(180); self.guildRecruitCreatorBtn:SetHeight(26)
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", list, "BOTTOM", 18, 12)
  end
  local showBtn = self.guildShowBronzeNetBtn or self.guildOpenOnlineButton
  if showBtn then
    showBtn:ClearAllPoints(); showBtn:SetWidth(130); showBtn:SetHeight(26)
    showBtn:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -12, 12)
    showBtn:Show()
  end
end

BLFG_5620_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  return BLFG_5620_OldRefreshGuildBrowser and BLFG_5620_OldRefreshGuildBrowser(self, ...)
end

BLFG_5620_OldBuildPublicGroups = BLFG.BuildPublicGroups
function BLFG:BuildPublicGroups(...)
  local r = BLFG_5620_OldBuildPublicGroups and BLFG_5620_OldBuildPublicGroups(self, ...)
  BLFG_5620_LayoutPublicFilterTabs(self)
  BLFG_5620_FixVersionText()
  return r
end

BLFG_5620_OldShowPublicGroups = BLFG.ShowPublicGroups
function BLFG:ShowPublicGroups(...)
  local r = BLFG_5620_OldShowPublicGroups and BLFG_5620_OldShowPublicGroups(self, ...)
  BLFG_5620_LayoutPublicFilterTabs(self)
  return r
end

BLFG_5620_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
  return BLFG_5620_OldRefreshPublicGroups and BLFG_5620_OldRefreshPublicGroups(self, ...)
end

BLFG_5620_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5620_OldShowOptions and BLFG_5620_OldShowOptions(self, ...)
  BLFG_5620_FixVersionText()
  return r
end

BLFG_5620_Login = CreateFrame("Frame")
BLFG_5620_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5620_Login:SetScript("OnEvent", function()
  BLFG_5620_FixVersionText()
  if BLFG then
    BLFG_5620_LayoutPublicFilterTabs(BLFG)
    BLFG_5620_LayoutGuildFooter(BLFG)
  end
end)

-- ============================================================
-- BronzeLFG v5.6.21 - focused Guild footer + Public Hide Types cleanup
-- ============================================================
BRONZELFG_VERSION = "5.6.21"
VERSION = "5.6.21"
if BLFG then BLFG.version = "5.6.21" end

function BLFG_5621_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.21"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end

-- Guild recruitment no longer belongs in Public Groups, so remove it from Hide Types too.
BLFG_5621_PUBLIC_HIDE_TYPES = {"Other", "Social", "LFG", "Event", "Raid", "Dungeon", "Key"}

function BLFG_5621_PublicHiddenTypes()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.publicHiddenTypes = BronzeLFG_DB.publicHiddenTypes or {}
  BronzeLFG_DB.publicHiddenTypes["Guild"] = nil
  return BronzeLFG_DB.publicHiddenTypes
end

function BLFG_5621_PublicHiddenTypeCount()
  local hidden = BLFG_5621_PublicHiddenTypes()
  local n = 0
  for _, t in ipairs(BLFG_5621_PUBLIC_HIDE_TYPES) do
    if hidden[t] then n = n + 1 end
  end
  return n
end

function BLFG_5621_PublicHideTypesButtonText()
  local n = BLFG_5621_PublicHiddenTypeCount()
  if n <= 0 then return "Hide Types: 0" end
  return "Hide Types: " .. tostring(n)
end

function BLFG:IsPublicTypeHidden(t)
  if tostring(t or "") == "Guild" then return false end
  local hidden = BLFG_5621_PublicHiddenTypes()
  return hidden[tostring(t or "Other")] == true
end

function BLFG:ShowPublicHideTypesMenu(anchor)
  -- Replace any older menu so stale Guild/? labels cannot remain.
  if self.publicHideTypesDropdown then
    self.publicHideTypesDropdown:Hide()
    self.publicHideTypesDropdown:SetParent(nil)
    self.publicHideTypesDropdown = nil
  end

  local f = CreateFrame("Frame", "BronzeLFGPublicHideTypesDropdown5621", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetWidth(150)
  f:SetHeight(200)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left=3,right=3,top=3,bottom=3}
  })
  f:SetBackdropColor(0,0,0,.95)
  f.buttons = {}

  local title = font(f, "Hide on All", 10, 1, .82, 0)
  title:SetPoint("TOP", f, "TOP", 0, -8)

  for i,opt in ipairs(BLFG_5621_PUBLIC_HIDE_TYPES) do
    local b = button(f, opt, 132, 19)
    b:SetPoint("TOP", f, "TOP", 0, -26 - ((i-1)*20))
    b.typeName = opt
    b:SetScript("OnClick", function(self)
      local hidden = BLFG_5621_PublicHiddenTypes()
      if hidden[self.typeName] then hidden[self.typeName] = nil else hidden[self.typeName] = true end
      hidden["Guild"] = nil
      BLFG.publicHideOther = hidden["Other"] == true
      BLFG.publicPage = 1
      if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
      if BLFG.publicHideTypesDropdown and BLFG.publicHideTypesDropdown.RefreshLabels then
        BLFG.publicHideTypesDropdown:RefreshLabels()
      end
    end)
    f.buttons[i] = b
  end

  local clear = button(f, "Show All Types", 132, 20)
  clear:SetPoint("BOTTOM", f, "BOTTOM", 0, 7)
  clear:SetScript("OnClick", function()
    BronzeLFG_DB.publicHiddenTypes = {}
    BLFG.publicHideOther = false
    BLFG.publicPage = 1
    if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
    f:Hide()
  end)
  f.clear = clear

  f.RefreshLabels = function(self)
    local hidden = BLFG_5621_PublicHiddenTypes()
    for _, b in ipairs(self.buttons or {}) do
      local checked = hidden[b.typeName] == true
      -- Use ASCII text instead of a special glyph that renders as ? on some 3.3.5 clients.
      b:SetText((checked and "Hide: " or "Show: ") .. tostring(b.typeName))
    end
    if BLFG.publicHideOtherButton then BLFG.publicHideOtherButton:SetText(BLFG_5621_PublicHideTypesButtonText()) end
  end

  self.publicHideTypesDropdown = f
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  if f.RefreshLabels then f:RefreshLabels() end
  f:Show()
end

function BLFG_5621_LayoutPublicFilterTabs(self)
  if not self or not self.publicFilterButtons then return end
  local order = {"All", "Dungeon", "Raid", "Key", "Event", "LFG", "Social"}
  local widths = {All=62, Dungeon=98, Raid=78, Key=72, Event=86, LFG=70, Social=86}
  local fx = 38
  for _,name in ipairs(order) do
    local b = self.publicFilterButtons[name]
    if b then
      b:ClearAllPoints()
      b:SetWidth(widths[name] or 76)
      b:SetPoint("TOPLEFT", self.publicPanel, "TOPLEFT", fx, -36)
      b:Show()
      fx = fx + (widths[name] or 76) + 8
    end
  end
  if self.publicFilterButtons["Guild"] then self.publicFilterButtons["Guild"]:Hide() end
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  if self.publicHideOtherButton then self.publicHideOtherButton:SetText(BLFG_5621_PublicHideTypesButtonText()) end
end

function BLFG_5621_LayoutGuildFooter(self)
  if not self or not self.guildList then return end
  local list = self.guildList

  -- Keep only the active pager visible.
  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616,self.guildPageUpButton5617,self.guildPageDownButton5617}) do
    if b and b ~= self.guildPageUpButton5618 and b ~= self.guildPageDownButton5618 then b:Hide() end
  end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616,self.guildPageLabel5617}) do
    if l and l ~= self.guildPageLabel5618 then l:Hide() end
  end

  -- Pager row, safely above the helper text.
  if self.guildPageUpButton5618 then
    self.guildPageUpButton5618:ClearAllPoints()
    self.guildPageUpButton5618:SetWidth(82); self.guildPageUpButton5618:SetHeight(24)
    self.guildPageUpButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 52, 90)
    self.guildPageUpButton5618:Show()
  end
  if self.guildPageDownButton5618 then
    self.guildPageDownButton5618:ClearAllPoints()
    self.guildPageDownButton5618:SetWidth(82); self.guildPageDownButton5618:SetHeight(24)
    self.guildPageDownButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 150, 90)
    self.guildPageDownButton5618:Show()
  end
  if self.guildPageLabel5618 then
    self.guildPageLabel5618:ClearAllPoints()
    self.guildPageLabel5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 282, 96)
    self.guildPageLabel5618:Show()
  end

  -- Helper text gets its own row.
  if self.guildFooter then
    self.guildFooter:ClearAllPoints()
    self.guildFooter:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 52, 61)
    self.guildFooter:SetWidth(620)
    self.guildFooter:Show()
  end

  -- Bottom action row, spaced to avoid button collisions.
  if self.guildClearListingsBtn then
    self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetWidth(145); self.guildClearListingsBtn:SetHeight(26)
    self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 52, 20)
    self.guildClearListingsBtn:Show()
  end
  if self.guildRecruitCreatorBtn then
    self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetWidth(210); self.guildRecruitCreatorBtn:SetHeight(26)
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", list, "BOTTOM", -8, 20)
    self.guildRecruitCreatorBtn:Show()
  end
  local showBtn = self.guildShowBronzeNetBtn or self.guildOpenOnlineButton
  if showBtn then
    showBtn:ClearAllPoints(); showBtn:SetWidth(150); showBtn:SetHeight(26)
    showBtn:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -34, 20)
    showBtn:Show()
  end
end

BLFG_5621_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  return BLFG_5621_OldRefreshGuildBrowser and BLFG_5621_OldRefreshGuildBrowser(self, ...)
end

BLFG_5621_OldBuildPublicGroups = BLFG.BuildPublicGroups
function BLFG:BuildPublicGroups(...)
  local r = BLFG_5621_OldBuildPublicGroups and BLFG_5621_OldBuildPublicGroups(self, ...)
  BLFG_5621_LayoutPublicFilterTabs(self)
  BLFG_5621_FixVersionText()
  return r
end

BLFG_5621_OldShowPublicGroups = BLFG.ShowPublicGroups
function BLFG:ShowPublicGroups(...)
  local r = BLFG_5621_OldShowPublicGroups and BLFG_5621_OldShowPublicGroups(self, ...)
  BLFG_5621_LayoutPublicFilterTabs(self)
  return r
end

BLFG_5621_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  return BLFG_5621_OldRefreshPublicGroups and BLFG_5621_OldRefreshPublicGroups(self, ...)
end

BLFG_5621_Login = CreateFrame("Frame")
BLFG_5621_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5621_Login:SetScript("OnEvent", function()
  BLFG_5621_FixVersionText()
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  if BLFG then
    BLFG_5621_LayoutPublicFilterTabs(BLFG)
    BLFG_5621_LayoutGuildFooter(BLFG)
  end
end)

-- ============================================================
-- BronzeLFG v5.6.25 - Hide Types toggle + footer revert
-- ============================================================
BRONZELFG_VERSION = "5.6.25"
VERSION = "5.6.25"
if BLFG then BLFG.version = "5.6.25" end

function BLFG_5622_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.25"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end

-- Keep Guild out of Public Groups/Hide Types.
BLFG_5622_PUBLIC_HIDE_TYPES = {"Other", "Social", "LFG", "Event", "Raid", "Dungeon", "Key"}

function BLFG_5622_PublicHiddenTypes()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.publicHiddenTypes = BronzeLFG_DB.publicHiddenTypes or {}
  BronzeLFG_DB.publicHiddenTypes["Guild"] = nil
  return BronzeLFG_DB.publicHiddenTypes
end

function BLFG_5622_PublicHiddenTypeCount()
  local hidden = BLFG_5622_PublicHiddenTypes()
  local n = 0
  for _, t in ipairs(BLFG_5622_PUBLIC_HIDE_TYPES) do
    if hidden[t] then n = n + 1 end
  end
  return n
end

function BLFG_5622_PublicHideTypesButtonText()
  local n = BLFG_5622_PublicHiddenTypeCount()
  if n <= 0 then return "Hide Types: 0" end
  return "Hide Types: " .. tostring(n)
end

function BLFG:IsPublicTypeHidden(t)
  if tostring(t or "") == "Guild" then return false end
  return BLFG_5622_PublicHiddenTypes()[tostring(t or "Other")] == true
end

-- Click Hide Types once to open, click it again to close.
function BLFG:ShowPublicHideTypesMenu(anchor)
  if self.publicHideTypesDropdown and self.publicHideTypesDropdown:IsShown() then
    self.publicHideTypesDropdown:Hide()
    return
  end

  if self.publicHideTypesDropdown then
    self.publicHideTypesDropdown:Hide()
    self.publicHideTypesDropdown:SetParent(nil)
    self.publicHideTypesDropdown = nil
  end

  local f = CreateFrame("Frame", "BronzeLFGPublicHideTypesDropdown5622", UIParent)
  f:SetFrameStrata("TOOLTIP")
  f:SetWidth(150)
  f:SetHeight(200)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = {left=3,right=3,top=3,bottom=3}
  })
  f:SetBackdropColor(0,0,0,.95)
  f.buttons = {}

  local title = font(f, "Hide on All", 10, 1, .82, 0)
  title:SetPoint("TOP", f, "TOP", 0, -8)

  for i,opt in ipairs(BLFG_5622_PUBLIC_HIDE_TYPES) do
    local b = button(f, opt, 132, 19)
    b:SetPoint("TOP", f, "TOP", 0, -26 - ((i-1)*20))
    b.typeName = opt
    b:SetScript("OnClick", function(self)
      local hidden = BLFG_5622_PublicHiddenTypes()
      if hidden[self.typeName] then hidden[self.typeName] = nil else hidden[self.typeName] = true end
      hidden["Guild"] = nil
      BLFG.publicHideOther = hidden["Other"] == true
      BLFG.publicPage = 1
      if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
      if BLFG.publicHideTypesDropdown and BLFG.publicHideTypesDropdown.RefreshLabels then
        BLFG.publicHideTypesDropdown:RefreshLabels()
      end
    end)
    f.buttons[i] = b
  end

  local clear = button(f, "Show All Types", 132, 20)
  clear:SetPoint("BOTTOM", f, "BOTTOM", 0, 7)
  clear:SetScript("OnClick", function()
    BronzeLFG_DB.publicHiddenTypes = {}
    BLFG.publicHideOther = false
    BLFG.publicPage = 1
    if BLFG.RefreshPublicGroups then BLFG:RefreshPublicGroups() end
    f:Hide()
  end)
  f.clear = clear

  f.RefreshLabels = function(self)
    local hidden = BLFG_5622_PublicHiddenTypes()
    for _, b in ipairs(self.buttons or {}) do
      local checked = hidden[b.typeName] == true
      b:SetText((checked and "Hide: " or "Show: ") .. tostring(b.typeName))
    end
    if BLFG.publicHideOtherButton then BLFG.publicHideOtherButton:SetText(BLFG_5622_PublicHideTypesButtonText()) end
  end

  self.publicHideTypesDropdown = f
  f:ClearAllPoints()
  f:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
  if f.RefreshLabels then f:RefreshLabels() end
  f:Show()
end

function BLFG_5622_LayoutPublicFilterTabs(self)
  if not self or not self.publicFilterButtons then return end
  local order = {"All", "Dungeon", "Raid", "Key", "Event", "LFG", "Social"}
  local widths = {All=62, Dungeon=98, Raid=78, Key=72, Event=86, LFG=70, Social=86}
  local fx = 38
  for _,name in ipairs(order) do
    local b = self.publicFilterButtons[name]
    if b then
      b:ClearAllPoints()
      b:SetWidth(widths[name] or 76)
      b:SetPoint("TOPLEFT", self.publicPanel, "TOPLEFT", fx, -36)
      b:Show()
      fx = fx + (widths[name] or 76) + 8
    end
  end
  if self.publicFilterButtons["Guild"] then self.publicFilterButtons["Guild"]:Hide() end
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  if self.publicSortButton then
    self.publicSortButton:ClearAllPoints()
    self.publicSortButton:SetWidth(130)
    self.publicSortButton:SetPoint("TOPRIGHT", self.publicPanel, "TOPRIGHT", -326, -64)
  end
  if self.publicHideOtherButton then
    self.publicHideOtherButton:ClearAllPoints()
    self.publicHideOtherButton:SetWidth(130)
    self.publicHideOtherButton:SetPoint("TOPRIGHT", self.publicPanel, "TOPRIGHT", -180, -64)
  end
  if self.onlinePanelButton then
    self.onlinePanelButton:ClearAllPoints()
    self.onlinePanelButton:SetWidth(170)
    self.onlinePanelButton:SetPoint("TOPRIGHT", self.publicPanel, "TOPRIGHT", -2, -64)
  end
  if self.publicSearch then
    self.publicSearch:ClearAllPoints()
    self.publicSearch:SetWidth(220)
    self.publicSearch:SetPoint("TOPRIGHT", self.publicPanel, "TOPRIGHT", -8, -87)
  end
  if self.publicHideOtherButton then self.publicHideOtherButton:SetText(BLFG_5622_PublicHideTypesButtonText()) end
end

-- Revert footer to the cleaner v5.6.20 placement the user preferred.
function BLFG_5622_LayoutGuildFooter(self)
  if not self or not self.guildList then return end
  local list = self.guildList

  for _,b in ipairs({self.guildPrevPageButton,self.guildNextPageButton,self.guildPageUpButton,self.guildPageDownButton,self.guildPageUpButton5614,self.guildPageDownButton5614,self.guildPageUpButton5615,self.guildPageDownButton5615,self.guildPageUpButton5616,self.guildPageDownButton5616,self.guildPageUpButton5617,self.guildPageDownButton5617}) do
    if b and b ~= self.guildPageUpButton5618 and b ~= self.guildPageDownButton5618 then b:Hide() end
  end
  for _,l in ipairs({self.guildPageLabel,self.guildPageLabel5614,self.guildPageLabel5615,self.guildPageLabel5616,self.guildPageLabel5617}) do
    if l and l ~= self.guildPageLabel5618 then l:Hide() end
  end

  if self.guildPageUpButton5618 then
    self.guildPageUpButton5618:ClearAllPoints()
    self.guildPageUpButton5618:SetWidth(78); self.guildPageUpButton5618:SetHeight(24)
    self.guildPageUpButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 36, 62)
    self.guildPageUpButton5618:Show()
  end
  if self.guildPageDownButton5618 then
    self.guildPageDownButton5618:ClearAllPoints()
    self.guildPageDownButton5618:SetWidth(78); self.guildPageDownButton5618:SetHeight(24)
    self.guildPageDownButton5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 124, 62)
    self.guildPageDownButton5618:Show()
  end
  if self.guildPageLabel5618 then
    self.guildPageLabel5618:ClearAllPoints()
    self.guildPageLabel5618:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 246, 68)
    self.guildPageLabel5618:Show()
  end

  if self.guildFooter then
    self.guildFooter:ClearAllPoints()
    self.guildFooter:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 14, 43)
    self.guildFooter:SetWidth(520)
    self.guildFooter:Show()
  end

  if self.guildClearListingsBtn then
    self.guildClearListingsBtn:ClearAllPoints(); self.guildClearListingsBtn:SetWidth(120); self.guildClearListingsBtn:SetHeight(26)
    self.guildClearListingsBtn:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", 42, 12)
    self.guildClearListingsBtn:Show()
  end
  if self.guildRecruitCreatorBtn then
    self.guildRecruitCreatorBtn:ClearAllPoints(); self.guildRecruitCreatorBtn:SetWidth(180); self.guildRecruitCreatorBtn:SetHeight(26)
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", list, "BOTTOM", 18, 12)
    self.guildRecruitCreatorBtn:Show()
  end
  local showBtn = self.guildShowBronzeNetBtn or self.guildOpenOnlineButton
  if showBtn then
    showBtn:ClearAllPoints(); showBtn:SetWidth(130); showBtn:SetHeight(26)
    showBtn:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -12, 12)
    showBtn:Show()
  end
end

BLFG_5622_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  return BLFG_5622_OldRefreshGuildBrowser and BLFG_5622_OldRefreshGuildBrowser(self, ...)
end

BLFG_5622_OldBuildPublicGroups = BLFG.BuildPublicGroups
function BLFG:BuildPublicGroups(...)
  local r = BLFG_5622_OldBuildPublicGroups and BLFG_5622_OldBuildPublicGroups(self, ...)
  BLFG_5622_LayoutPublicFilterTabs(self)
  BLFG_5622_FixVersionText()
  return r
end

BLFG_5622_OldShowPublicGroups = BLFG.ShowPublicGroups
function BLFG:ShowPublicGroups(...)
  local r = BLFG_5622_OldShowPublicGroups and BLFG_5622_OldShowPublicGroups(self, ...)
  BLFG_5622_LayoutPublicFilterTabs(self)
  return r
end

BLFG_5622_OldRefreshPublicGroups = BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  if self.publicFilter == "Guild" then self.publicFilter = "All" end
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  local r = BLFG_5622_OldRefreshPublicGroups and BLFG_5622_OldRefreshPublicGroups(self, ...)
  BLFG_5622_LayoutPublicFilterTabs(self)
  BLFG_5622_FixVersionText()
  return r
end

BLFG_5622_Login = CreateFrame("Frame")
BLFG_5622_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5622_Login:SetScript("OnEvent", function()
  BLFG_5622_FixVersionText()
  if BronzeLFG_DB and BronzeLFG_DB.publicHiddenTypes then BronzeLFG_DB.publicHiddenTypes["Guild"] = nil end
  if BLFG then
    BLFG_5622_LayoutPublicFilterTabs(BLFG)
    BLFG_5622_LayoutGuildFooter(BLFG)
  end
end)

-- ============================================================================
-- v5.6.25 Options alignment: Dungeon alert dropdown row cleanup
-- ============================================================================
BLFG.version = "5.6.25"
VERSION = "BronzeLFG v5.6.25"

function BLFG_5623_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.25"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end

function BLFG_5623_PositionDungeonDropdown()
  if not BLFG then return end
  -- Hide older duplicate dungeon dropdowns so only one control remains visible.
  if BLFG.dungeonFilterDD5612 then BLFG.dungeonFilterDD5612:Hide() end
  if BLFG.dungeonAlertDropdown5613 then BLFG.dungeonAlertDropdown5613:Hide() end
  if BLFG.dungeonAlertDropdown5614 then BLFG.dungeonAlertDropdown5614:Hide() end

  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end
  local dd = BLFG.dungeonAlertDropdown5615 or BLFG.dungeonAlertDropdown5614 or BLFG.dungeonFilterDD5612
  if not dd then return end

  dd:ClearAllPoints()
  UIDropDownMenu_SetWidth(dd, 170)

  -- Match the right-column dropdown alignment exactly: Dungeon sits directly below Keystone.
  if BLFG.keystoneAlertDropdown then
    dd:SetPoint("TOPLEFT", BLFG.keystoneAlertDropdown, "TOPLEFT", 0, -82)
  elseif BLFG.optNotifyDungeon then
    -- Fallback if the keystone dropdown has not been captured yet.
    dd:SetPoint("LEFT", BLFG.optNotifyDungeon, "RIGHT", 235, -2)
  end
  dd:Show()
  if BronzeLFG_DB and BronzeLFG_DB.options then
    UIDropDownMenu_SetText(dd, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
  else
    UIDropDownMenu_SetText(dd, "Any Dungeon")
  end
end

BLFG_5623_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5623_OldBuildOptions and BLFG_5623_OldBuildOptions(self, ...)
  BLFG_5623_PositionDungeonDropdown()
  BLFG_5623_FixVersionText()
  return r
end

BLFG_5623_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5623_OldShowOptions and BLFG_5623_OldShowOptions(self, ...)
  BLFG_5623_PositionDungeonDropdown()
  BLFG_5623_FixVersionText()
  return r
end

BLFG_5623_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_5623_OldSaveOptions and BLFG_5623_OldSaveOptions(self, showFlash)
  if self.dungeonAlertDropdown5615 then
    BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
    BronzeLFG_DB.options.notifyDungeonFilter = UIDropDownMenu_GetText(self.dungeonAlertDropdown5615) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon"
  end
  BLFG_5623_PositionDungeonDropdown()
  return r
end

BLFG_5623_Login = CreateFrame("Frame")
BLFG_5623_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5623_Login:SetScript("OnEvent", function()
  BLFG_5623_FixVersionText()
  if BLFG then BLFG_5623_PositionDungeonDropdown() end
end)

-- ============================================================================
-- v5.6.25 Dungeon alert dropdown exact alignment fix
-- ============================================================================
BLFG.version = "5.6.25"
VERSION = "BronzeLFG v5.6.25"

function BLFG_5624_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.25"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end

function BLFG_5624_PositionDungeonDropdown()
  if not BLFG or not BLFG.optNotifyDungeon then return end

  -- Make sure the functional submenu dropdown exists, then hide every older/duplicate one.
  if BLFG_5615_CreateDungeonDropdown then BLFG_5615_CreateDungeonDropdown() end

  local dd = BLFG.dungeonAlertDropdown5615 or BLFG.dungeonAlertDropdown5614 or BLFG.dungeonAlertDropdown5613 or BLFG.dungeonFilterDD5612
  if not dd then return end

  if BLFG.dungeonFilterDD5612 and BLFG.dungeonFilterDD5612 ~= dd then BLFG.dungeonFilterDD5612:Hide() end
  if BLFG.dungeonAlertDropdown5613 and BLFG.dungeonAlertDropdown5613 ~= dd then BLFG.dungeonAlertDropdown5613:Hide() end
  if BLFG.dungeonAlertDropdown5614 and BLFG.dungeonAlertDropdown5614 ~= dd then BLFG.dungeonAlertDropdown5614:Hide() end

  local box = BLFG.optNotifyDungeon:GetParent() or BLFG.optionsPanel
  dd:ClearAllPoints()
  -- Exact mirror of the Keystone dropdown's base layout: same X, same width, one row lower.
  -- Keystone: TOPLEFT box 625, -303. Dungeon row: TOPLEFT box 625, -358.
  dd:SetPoint("TOPLEFT", box, "TOPLEFT", 625, -358)
  UIDropDownMenu_SetWidth(dd, 150)
  dd:SetFrameLevel((box:GetFrameLevel() or 1) + 8)
  dd:Show()

  BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  UIDropDownMenu_SetText(dd, BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon")
end

BLFG_5624_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_5624_OldBuildOptions and BLFG_5624_OldBuildOptions(self, ...)
  BLFG_5624_PositionDungeonDropdown()
  BLFG_5624_FixVersionText()
  return r
end

BLFG_5624_OldShowOptions = BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_5624_OldShowOptions and BLFG_5624_OldShowOptions(self, ...)
  BLFG_5624_PositionDungeonDropdown()
  BLFG_5624_FixVersionText()
  return r
end

BLFG_5624_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_5624_OldSaveOptions and BLFG_5624_OldSaveOptions(self, showFlash)
  if self.dungeonAlertDropdown5615 then
    BronzeLFG_DB = BronzeLFG_DB or {}; BronzeLFG_DB.options = BronzeLFG_DB.options or {}
    BronzeLFG_DB.options.notifyDungeonFilter = UIDropDownMenu_GetText(self.dungeonAlertDropdown5615) or BronzeLFG_DB.options.notifyDungeonFilter or "Any Dungeon"
  end
  BLFG_5624_PositionDungeonDropdown()
  return r
end

BLFG_5624_Login = CreateFrame("Frame")
BLFG_5624_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_5624_Login:SetScript("OnEvent", function()
  BLFG_5624_FixVersionText()
  if BLFG then BLFG_5624_PositionDungeonDropdown() end
end)

-- ============================================================================
-- BronzeLFG v5.6.25 - Guild Browser Focus/Recruiting Data Quality Pass
-- Purpose: improve Focus tags, Recruiting role tags, and Discord extraction for
-- chat-discovered guild recruitment without touching current layout fixes.
-- ============================================================================

BLFG_VERSION = "5.6.25"
BronzeLFG_Version = "5.6.25"
if BLFG then BLFG.version = "5.6.25" end

function BLFG_5625_Strip(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{rt%d}", " "):gsub("%b[]", function(x) return x end)
  s = s:gsub("[<>]", " ")
  s = s:gsub("[%c]", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function BLFG_5625_Low(s)
  return string.lower(BLFG_5625_Strip(s or ""))
end

function BLFG_5625_Has(low, pat)
  return low and string.find(low, pat) ~= nil
end

function BLFG_5625_AddTag(tags, tag)
  if not tag or tag == "" then return end
  for _, t in ipairs(tags) do if t == tag then return end end
  table.insert(tags, tag)
end

function BLFG_5625_RawFocus(text)
  local low = BLFG_5625_Low(text)
  local tags = {}

  -- Triumvirate systems
  if BLFG_5625_Has(low, "mythic%+") or BLFG_5625_Has(low, "%f[%w]m%+%f[%W]") or BLFG_5625_Has(low, "mythic plus") or BLFG_5625_Has(low, "keystone") or BLFG_5625_Has(low, "%f[%a]keys?%f[%A]") then BLFG_5625_AddTag(tags, "Keys") end
  if BLFG_5625_Has(low, "world boss") or BLFG_5625_Has(low, "world bosses") then BLFG_5625_AddTag(tags, "World Boss") end

  -- Raids. Use frontiers so "mc" doesn't match normal words/community.
  if BLFG_5625_Has(low, "raids?") or BLFG_5625_Has(low, "raiding") or BLFG_5625_Has(low, "main%-?raids?") or BLFG_5625_Has(low, "progression") or BLFG_5625_Has(low, "raid nights?") or BLFG_5625_Has(low, "roster") or BLFG_5625_Has(low, "realm first") or BLFG_5625_Has(low, "server %d+rd") or BLFG_5625_Has(low, "server %d+nd") or BLFG_5625_Has(low, "server %d+st") or BLFG_5625_Has(low, "bwl") or BLFG_5625_Has(low, "blackwing") or BLFG_5625_Has(low, "molten core") or BLFG_5625_Has(low, "%f[%a]mc%f[%A]") or BLFG_5625_Has(low, "%f[%a]ony%f[%A]") or BLFG_5625_Has(low, "onyxia") or BLFG_5625_Has(low, "%f[%a]zg%f[%A]") or BLFG_5625_Has(low, "zul.?gurub") or BLFG_5625_Has(low, "aq20") or BLFG_5625_Has(low, "aq40") or BLFG_5625_Has(low, "naxx") or BLFG_5625_Has(low, "karazhan") or BLFG_5625_Has(low, "%f[%a]kara%f[%A]") then BLFG_5625_AddTag(tags, "Raiding") end

  if BLFG_5625_Has(low, "%f[%a]pvp%f[%A]") or BLFG_5625_Has(low, "arenas?") or BLFG_5625_Has(low, "battleground") or BLFG_5625_Has(low, "%f[%a]bgs?%f[%A]") or BLFG_5625_Has(low, "world pvp") or BLFG_5625_Has(low, "premade") then BLFG_5625_AddTag(tags, "PvP") end
  if BLFG_5625_Has(low, "leveling") or BLFG_5625_Has(low, "levelling") or BLFG_5625_Has(low, "%f[%a]level%f[%A]") or BLFG_5625_Has(low, "fresh") or BLFG_5625_Has(low, "alts?") or BLFG_5625_Has(low, "new players?") then BLFG_5625_AddTag(tags, "Leveling") end
  if BLFG_5625_Has(low, "social") or BLFG_5625_Has(low, "community") or BLFG_5625_Has(low, "casual") or BLFG_5625_Has(low, "chill") or BLFG_5625_Has(low, "friendly") or BLFG_5625_Has(low, "family") or BLFG_5625_Has(low, "relaxed") or BLFG_5625_Has(low, "drama%-?free") or BLFG_5625_Has(low, "laid back") or BLFG_5625_Has(low, "good people") then BLFG_5625_AddTag(tags, "Social") end
  if BLFG_5625_Has(low, "dungeon") or BLFG_5625_Has(low, "dungeons") or BLFG_5625_Has(low, "%f[%a]rdf%f[%A]") or BLFG_5625_Has(low, "dire maul") or BLFG_5625_Has(low, "maraudon") or BLFG_5625_Has(low, "stratholme") or BLFG_5625_Has(low, "scholomance") then BLFG_5625_AddTag(tags, "Dungeons") end
  if BLFG_5625_Has(low, "events?") or BLFG_5625_Has(low, "giveaway") or BLFG_5625_Has(low, "lottery") then BLFG_5625_AddTag(tags, "Events") end

  if #tags == 0 then return "" end
  return table.concat(tags, ",")
end

function BLFG_5625_ColorFocus(raw, maxTags)
  raw = BLFG_5625_Strip(raw or "")
  if raw == "" then return "|cFFAAAAAA[Unknown]|r" end
  local colors = {
    ["Keys"]="|cFF80B0FF[Keys]|r", ["Mythic+"]="|cFF80B0FF[Keys]|r",
    ["Raiding"]="|cFFFF5555[Raiding]|r", ["World Boss"]="|cFFFFCC00[World Boss]|r",
    ["PvP"]="|cFFFF7777[PvP]|r", ["Leveling"]="|cFF55FF55[Leveling]|r",
    ["Social"]="|cFF55CCFF[Social]|r", ["Hardcore"]="|cFFFFAA55[Hardcore]|r",
    ["Dungeons"]="|cFFAAAAFF[Dungeons]|r", ["Events"]="|cFFFFAA00[Events]|r"
  }
  local out, count, total = {}, 0, 0
  for token in string.gmatch(raw, "([^,]+)") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    if token ~= "" then
      total = total + 1
      if not maxTags or count < maxTags then
        count = count + 1
        table.insert(out, colors[token] or ("|cFFFFFFFF["..token.."]|r"))
      end
    end
  end
  if maxTags and total > maxTags then table.insert(out, "|cFFAAAAAA[+" .. tostring(total - maxTags) .. "]|r") end
  if #out == 0 then return "|cFFAAAAAA[Unknown]|r" end
  return table.concat(out, " ")
end

function BLFG_5625_RoleRaw(text)
  local low = BLFG_5625_Low(text)
  local t, h, d = false, false, false
  if BLFG_5625_Has(low, "all roles") or BLFG_5625_Has(low, "any role") or BLFG_5625_Has(low, "all classes") or BLFG_5625_Has(low, "everyone") or BLFG_5625_Has(low, "all welcome") or BLFG_5625_Has(low, "all specs") then t,h,d = true,true,true end
  if BLFG_5625_Has(low, "tanks?") or BLFG_5625_Has(low, "%f[%a]mt%f[%A]") or BLFG_5625_Has(low, "%f[%a]ot%f[%A]") or BLFG_5625_Has(low, "prot") or BLFG_5625_Has(low, "bear") then t = true end
  if BLFG_5625_Has(low, "heals?") or BLFG_5625_Has(low, "healers?") or BLFG_5625_Has(low, "%f[%a]hpal%f[%A]") or BLFG_5625_Has(low, "holy pal") or BLFG_5625_Has(low, "resto") or BLFG_5625_Has(low, "priest") or BLFG_5625_Has(low, "shaman") then h = true end
  if BLFG_5625_Has(low, "%f[%a]dps%f[%A]") or BLFG_5625_Has(low, "damage") or BLFG_5625_Has(low, "melee") or BLFG_5625_Has(low, "ranged") or BLFG_5625_Has(low, "caster") or BLFG_5625_Has(low, "feral") or BLFG_5625_Has(low, "hunter") or BLFG_5625_Has(low, "mage") or BLFG_5625_Has(low, "warlock") or BLFG_5625_Has(low, "rogue") then d = true end
  local parts = {}
  if t then table.insert(parts, "T") end
  if h then table.insert(parts, "H") end
  if d then table.insert(parts, "D") end
  return table.concat(parts, ",")
end

function BLFG_5625_RoleTags(raw)
  raw = tostring(raw or "")
  if raw == "" then return "|cFFAAAAAAUnknown|r" end
  local out = {}
  if raw:find("T") then table.insert(out, "|cFF33AAFF[T]|r") end
  if raw:find("H") then table.insert(out, "|cFF55FF55[H]|r") end
  if raw:find("D") then table.insert(out, "|cFFFF5555[D]|r") end
  if #out == 0 then return "|cFFAAAAAAUnknown|r" end
  return table.concat(out, " ")
end

function BLFG_5625_Discord(text)
  text = tostring(text or "")
  local link = string.match(text, "(https?://discord%.gg/%S+)") or string.match(text, "(https?://discord%.com/invite/%S+)") or string.match(text, "(discord%.gg/%S+)") or string.match(text, "(discord%.com/invite/%S+)")
  if link then
    link = link:gsub("[%.,;!%)]$", "")
    return link
  end
  local code = string.match(text, "[Dd]iscord[:%s]+([%w%-%_]+)") or string.match(text, "[Dd]isc[:%s]+([%w%-%_]+)")
  if code and code ~= "ready" and code ~= "required" then return "discord.gg/" .. code end
  return ""
end

function BLFG:FormatFocusTags(value, fallbackText)
  local raw = BLFG_5625_RawFocus(value or "")
  if raw == "" then raw = BLFG_5625_RawFocus(fallbackText or "") end
  if raw == "" then return "|cFFAAAAAA[Unknown]|r" end
  return BLFG_5625_ColorFocus(raw, nil)
end

function BLFG:GetRawFocusTags(value, fallbackText)
  local raw = BLFG_5625_RawFocus(value or "")
  if raw == "" then raw = BLFG_5625_RawFocus(fallbackText or "") end
  return raw
end

function BLFG:FormatRecruitingTags(value)
  return BLFG_5625_RoleTags(BLFG_5625_RoleRaw(value or ""))
end

BLFG_5625_OldGetGuildRows = BLFG.GetGuildRows
if BLFG_5625_OldGetGuildRows then
  function BLFG:GetGuildRows(...)
    local rows, a, b, c = BLFG_5625_OldGetGuildRows(self, ...)
    rows = rows or {}
    for _, g in ipairs(rows) do
      if g then
        local msg = tostring(g.lastPost or g.message or g.rawMessage or g.post or g.description or "")
        local rawFocus = BLFG_5625_RawFocus(msg)
        if rawFocus ~= "" then g.focusRaw = rawFocus; g.focus = rawFocus; g.focusText = rawFocus end
        local rawRoles = BLFG_5625_RoleRaw(msg)
        if rawRoles ~= "" then g.recruitingRaw = rawRoles; g.recruiting = rawRoles; g.postKind = "Recruiting" end
        local disc = BLFG_5625_Discord(msg)
        if disc ~= "" then g.discord = disc; g.discordLink = disc end
      end
    end
    return rows, a, b, c
  end
end

function BLFG:ApplyGuildBrowserPolishToRow(row, g)
  if not row or not g then return end
  local msg = tostring(g.lastPost or g.message or g.rawMessage or g.post or "")
  local rawRole = tostring(g.recruitingRaw or "")
  if rawRole == "" then rawRole = BLFG_5625_RoleRaw(msg ~= "" and msg or tostring(g.recruiting or "")) end
  local roleText = BLFG_5625_RoleTags(rawRole)
  if row.recruitingText and row.recruitingText.SetText then row.recruitingText:SetText(roleText) elseif row.recruiting and row.recruiting.SetText then row.recruiting:SetText(roleText) end
  local rawFocus = tostring(g.focusRaw or "")
  if rawFocus == "" then rawFocus = BLFG_5625_RawFocus(msg ~= "" and msg or tostring(g.focus or g.focusText or g.postFocus or "")) end
  local focusText = BLFG_5625_ColorFocus(rawFocus, 2)
  if row.focusText and row.focusText.SetText then row.focusText:SetText(focusText) elseif row.focus and row.focus.SetText then row.focus:SetText(focusText) end
end

BLFG_5625_OldUpsert = BLFG.UpsertGuildBrowserChatListing
if BLFG_5625_OldUpsert then
  function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
    local r = BLFG_5625_OldUpsert(self, guildName, author, text)
    local key = tostring(guildName or "")
    local g = nil
    if self.guilds then g = self.guilds[key] end
    if not g and self.bronzeNetGuilds then g = self.bronzeNetGuilds[key] end
    if g then
      local msg = tostring(text or g.lastPost or g.message or "")
      g.focusRaw = BLFG_5625_RawFocus(msg)
      if g.focusRaw ~= "" then g.focus = g.focusRaw; g.focusText = g.focusRaw end
      g.recruitingRaw = BLFG_5625_RoleRaw(msg)
      if g.recruitingRaw ~= "" then g.recruiting = g.recruitingRaw end
      local disc = BLFG_5625_Discord(msg)
      if disc ~= "" then g.discord = disc; g.discordLink = disc end
    end
    return r
  end
end

BLFG_5625_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
if BLFG_5625_OldRefreshGuildBrowser then
  function BLFG:RefreshGuildBrowser(...)
    local r = BLFG_5625_OldRefreshGuildBrowser(self, ...)
    if self.guildRows then
      for _, row in ipairs(self.guildRows) do
        if row and row.guildData then self:ApplyGuildBrowserPolishToRow(row, row.guildData) end
      end
    end
    return r
  end
end

BLFG_5625_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
if BLFG_5625_OldRefreshGuildDetailPanel then
  function BLFG:RefreshGuildDetailPanel(g, ...)
    if g then
      local msg = tostring(g.lastPost or g.message or g.rawMessage or g.post or "")
      local rawFocus = BLFG_5625_RawFocus(msg)
      if rawFocus ~= "" then g.focusRaw = rawFocus; g.focus = rawFocus; g.focusText = rawFocus end
      local rawRoles = BLFG_5625_RoleRaw(msg)
      if rawRoles ~= "" then g.recruitingRaw = rawRoles; g.recruiting = rawRoles end
      local disc = BLFG_5625_Discord(msg)
      if disc ~= "" then g.discord = disc; g.discordLink = disc end
    end
    return BLFG_5625_OldRefreshGuildDetailPanel(self, g, ...)
  end
end


-- ============================================================================
-- BronzeLFG v5.6.27 - Guild Focus/Recruiting Polish
-- Fix role parsing regression and use compact table tags with full detail tags.
-- ============================================================================

BLFG_VERSION = "5.6.27"
BronzeLFG_Version = "5.6.27"
if BLFG then BLFG.version = "5.6.27" end
VERSION = "5.6.27"

function BLFG_5627_CleanText(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{rt%d+}", " ")
  s = s:gsub("<", " "):gsub(">", " ")
  s = s:gsub("[%c]", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function BLFG_5627_Lower(s)
  return string.lower(BLFG_5627_CleanText(s or ""))
end

function BLFG_5627_GuildText(g)
  if not g then return "" end
  local parts = {}
  local function add(v)
    v = tostring(v or "")
    if v ~= "" and v ~= "Unknown" and v ~= "--" and v ~= "Recruiting" and v ~= "Chat Only" then table.insert(parts, v) end
  end
  add(g.lastPost)
  add(g.message)
  add(g.rawMessage)
  add(g.post)
  add(g.description)
  add(g.recruitmentMessage)
  add(g.pitch)
  add(g.note)
  add(g.focusRaw)
  add(g.focus)
  add(g.focusText)
  add(g.recruitingRaw)
  add(g.recruiting)
  return table.concat(parts, " ")
end

function BLFG_5627_AddRole(parts, role)
  if role == "T" then parts.T = true end
  if role == "H" then parts.H = true end
  if role == "D" then parts.D = true end
end

function BLFG_5627_RoleRaw(text)
  local low = BLFG_5627_Lower(text)
  local r = { T=false, H=false, D=false }

  if string.find(low, "all roles") or string.find(low, "any role") or string.find(low, "all specs") or string.find(low, "all classes") or string.find(low, "everyone") or string.find(low, "all welcome") then
    r.T = true; r.H = true; r.D = true
  end

  -- Tank signals
  if string.find(low, "tanks?") or string.find(low, "%f[%a]mt%f[%A]") or string.find(low, "%f[%a]ot%f[%A]") or string.find(low, "%f[%a]prot%f[%A]") or string.find(low, "protection") or string.find(low, "bear") or string.find(low, "%f[%a]feral tank%f[%A]") then r.T = true end

  -- Healer signals, including common Bronzebeard/WoW shorthand.
  if string.find(low, "heals?") or string.find(low, "healers?") or string.find(low, "%f[%a]hpal%f[%A]") or string.find(low, "holy pal") or string.find(low, "holy pally") or string.find(low, "%f[%a]hpala%f[%A]") or string.find(low, "%f[%a]rdruid%f[%A]") or string.find(low, "resto") or string.find(low, "disc priest") or string.find(low, "holy priest") or string.find(low, "%f[%a]rsham%f[%A]") or string.find(low, "resto sham") then r.H = true end

  -- DPS signals.
  if string.find(low, "%f[%a]dps%f[%A]") or string.find(low, "damage") or string.find(low, "melee") or string.find(low, "ranged") or string.find(low, "caster") or string.find(low, "ret pal") or string.find(low, "%f[%a]ret%f[%A]") or string.find(low, "feral dps") or string.find(low, "hunter") or string.find(low, "mage") or string.find(low, "warlock") or string.find(low, "rogue") or string.find(low, "warrior dps") or string.find(low, "boomkin") or string.find(low, "shadow priest") or string.find(low, "%f[%a]spriest%f[%A]") then r.D = true end

  local out = {}
  if r.T then table.insert(out, "T") end
  if r.H then table.insert(out, "H") end
  if r.D then table.insert(out, "D") end
  return table.concat(out, ",")
end

function BLFG_5627_RoleTags(raw)
  raw = tostring(raw or "")
  if raw == "" or raw == "Unknown" or raw == "Recruiting" then return "|cFFAAAAAAN/A|r" end
  local out = {}
  if string.find(raw, "T") then table.insert(out, "|cFF33AAFF[T]|r") end
  if string.find(raw, "H") then table.insert(out, "|cFF55FF55[H]|r") end
  if string.find(raw, "D") then table.insert(out, "|cFFFF5555[D]|r") end
  if #out == 0 then return "|cFFAAAAAAN/A|r" end
  return table.concat(out, "")
end

function BLFG_5627_TagList(raw)
  raw = BLFG_5627_CleanText(raw or "")
  local out = {}
  local seen = {}
  for token in string.gmatch(raw, "([^,]+)") do
    token = token:gsub("^%s+", ""):gsub("%s+$", "")
    if token ~= "" and not seen[token] then seen[token] = true; table.insert(out, token) end
  end
  return out
end

function BLFG_5627_RawFocus(text)
  if BLFG_5625_RawFocus then return BLFG_5625_RawFocus(text or "") end
  return ""
end

function BLFG_5627_ColorFocusFull(raw, maxTags)
  return BLFG_5627_ColorFocusShort(raw or "", maxTags or 4)
end

function BLFG_5627_ColorFocusShort(raw, maxTags)
  raw = BLFG_5627_CleanText(raw or "")
  if raw == "" then return "|cFFAAAAAAN/A|r" end
  local colors = {
    ["Keys"]={"Key","|cFF80B0FF"}, ["Mythic+"]={"Key","|cFF80B0FF"},
    ["Raiding"]={"Raid","|cFFFF5555"}, ["World Boss"]={"WB","|cFFFFCC00"},
    ["PvP"]={"PvP","|cFFFF7777"}, ["Leveling"]={"Lvl","|cFF55FF55"},
    ["Social"]={"Soc","|cFF55CCFF"},
    ["Dungeons"]={"Dng","|cFFAAAAFF"}, ["Events"]={"Evt","|cFFFFAA00"}
  }
  local tags = BLFG_5627_TagList(raw)
  local out = {}
  local lim = maxTags or 2
  for i, token in ipairs(tags) do
    if i <= lim then
      local c = colors[token]
      if c then table.insert(out, c[2] .. "[" .. c[1] .. "]|r") else table.insert(out, "|cFFFFFFFF[" .. token .. "]|r") end
    end
  end
  if #tags > lim then table.insert(out, "|cFFAAAAAA[+" .. tostring(#tags - lim) .. "]|r") end
  if #out == 0 then return "|cFFAAAAAAN/A|r" end
  return table.concat(out, "")
end

function BLFG_5627_GetRawRoles(g)
  local msg = BLFG_5627_GuildText(g)
  local raw = BLFG_5627_RoleRaw(msg)
  if raw ~= "" then return raw end
  raw = tostring((g and g.recruitingRaw) or "")
  if raw ~= "" and raw ~= "Unknown" and raw ~= "Recruiting" then return raw end
  return ""
end

function BLFG_5627_GetRawFocus(g)
  local msg = BLFG_5627_GuildText(g)
  local raw = BLFG_5627_RawFocus(msg)
  if raw ~= "" then return raw end
  raw = tostring((g and (g.focusRaw or g.focus or g.focusText or g.postFocus)) or "")
  if raw ~= "" and raw ~= "Unknown" and raw ~= "[Unknown]" then return raw end
  return ""
end

function BLFG_5627_PolishGuildData(g)
  if not g then return end
  local roles = BLFG_5627_GetRawRoles(g)
  if roles ~= "" then g.recruitingRaw = roles; g.recruiting = roles end
  local focus = BLFG_5627_GetRawFocus(g)
  if focus ~= "" then g.focusRaw = focus; g.focus = focus; g.focusText = focus end
  local msg = BLFG_5627_GuildText(g)
  if BLFG_5625_Discord then
    local disc = BLFG_5625_Discord(msg)
    if disc and disc ~= "" then g.discord = disc; g.discordLink = disc end
  end
end

BLFG_5627_OldGetGuildRows = BLFG.GetGuildRows
if BLFG_5627_OldGetGuildRows then
  function BLFG:GetGuildRows(...)
    local rows, a, b, c = BLFG_5627_OldGetGuildRows(self, ...)
    if rows then for _, g in ipairs(rows) do BLFG_5627_PolishGuildData(g) end end
    return rows, a, b, c
  end
end

BLFG_5627_OldUpsertGuildBrowserChatListing = BLFG.UpsertGuildBrowserChatListing
if BLFG_5627_OldUpsertGuildBrowserChatListing then
  function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
    local r = BLFG_5627_OldUpsertGuildBrowserChatListing(self, guildName, author, text)
    local key = tostring(guildName or "")
    local g = nil
    if self.guilds then g = self.guilds[key] end
    if not g and self.bronzeNetGuilds then g = self.bronzeNetGuilds[key] end
    if g then
      g.lastPost = tostring(text or g.lastPost or "")
      g.message = g.lastPost
      BLFG_5627_PolishGuildData(g)
    end
    return r
  end
end

function BLFG_5627_ApplyRow(row, g)
  if not row or not g then return end
  BLFG_5627_PolishGuildData(g)
  local roles = BLFG_5627_GetRawRoles(g)
  local roleText = BLFG_5627_RoleTags(roles)
  if row.recruitingText and row.recruitingText.SetText then row.recruitingText:SetText(roleText) elseif row.recruiting and row.recruiting.SetText then row.recruiting:SetText(roleText) end
  local focus = BLFG_5627_GetRawFocus(g)
  local focusText = BLFG_5627_ColorFocusShort(focus, 2)
  if row.focusText and row.focusText.SetText then
    row.focusText:SetText(focusText); row.focusText:SetWidth(84); row.focusText:SetHeight(14); if row.focusText.SetNonSpaceWrap then row.focusText:SetNonSpaceWrap(false) end
  elseif row.focus and row.focus.SetText then
    row.focus:SetText(focusText); row.focus:SetWidth(84); row.focus:SetHeight(14); if row.focus.SetNonSpaceWrap then row.focus:SetNonSpaceWrap(false) end
  end
end

BLFG_5627_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
if BLFG_5627_OldRefreshGuildBrowser then
  function BLFG:RefreshGuildBrowser(...)
    local r = BLFG_5627_OldRefreshGuildBrowser(self, ...)
    if self.guildRows then for _, row in ipairs(self.guildRows) do if row and row.guildData then BLFG_5627_ApplyRow(row, row.guildData) end end end
    return r
  end
end

BLFG_5627_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
if BLFG_5627_OldRefreshGuildDetailPanel then
  function BLFG:RefreshGuildDetailPanel(g, ...)
    if g then BLFG_5627_PolishGuildData(g) end
    local r = BLFG_5627_OldRefreshGuildDetailPanel(self, g, ...)
    local d = self.guildDetailPanel
    if d and g then
      local roles = BLFG_5627_GetRawRoles(g)
      if d.recruiting and d.recruiting.SetText then d.recruiting:SetText("Recruiting: " .. BLFG_5627_RoleTags(roles)) end
      local focus = BLFG_5627_GetRawFocus(g)
      if d.focus and d.focus.SetText then
        d.focus:SetText(BLFG_5627_ColorFocusFull(focus, 4))
        d.focus:SetWidth(330); d.focus:SetHeight(18)
        if d.focus.SetNonSpaceWrap then d.focus:SetNonSpaceWrap(false) end
      end
      local disc = tostring(g.discord or g.discordLink or "")
      if disc ~= "" and self.guildDiscordLine and self.guildDiscordLine.SetText then
        self.guildDiscordLine:SetText("|cFFFFCC00Discord:|r |cFF99CCFF" .. disc .. "|r")
        self.guildDiscordLine:Show()
      end
    end
    return r
  end
end

-- Slash test for the exact OPPOSITION-style recruiting line.
SLASH_BLFG5627TEST1 = "/blfgroleparse"
SlashCmdList["BLFG5627TEST"] = function()
  local msg = "BWL 7/7(Asc) Realm First ZG/ONY/MC(Asc) Recruiting Melee & HPal for Main-Raids NA Raid Wed/Thur 8PM EST discord.gg/opps"
  DEFAULT_CHAT_FRAME:AddMessage("SignalFire role parse: " .. BLFG_5627_RoleTags(BLFG_5627_RoleRaw(msg)) .. " focus: " .. BLFG_5627_ColorFocusFull(BLFG_5627_RawFocus(msg), 4))
end

-- ============================================================
-- BronzeLFG v5.6.28 - guild phrase parser + focus/recruiting recovery
-- ============================================================
BRONZELFG_VERSION = "5.6.28"
VERSION = "5.6.28"
if BLFG then BLFG.version = "5.6.28" end

function BLFG_5628_Clean(s)
  if BLFG_5618_Clean then return BLFG_5618_Clean(s or "") end
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%s*[Rr][Tt]%d+%s*}", " "):gsub("%[[Rr][Tt]%d+%]", " ")
  s = s:gsub("[â˜ â˜…â˜†â€¢â—â—†â—‡â–ºâ–¶âž¤]+", " ")
  s = s:gsub("^%s*[%p%s]+", ""):gsub("[%p%s]+%s*$", "")
  s = s:gsub("%s+", " ")
  return s
end

function BLFG_5628_StripPrefix(s)
  if BLFG_5618_StripChatPrefix then return BLFG_5618_StripChatPrefix(s or "") end
  return tostring(s or "")
end

function BLFG_5628_BadGuildName(n)
  if BLFG_5618_BadGuildName then return BLFG_5618_BadGuildName(n or "") end
  n = BLFG_5628_Clean(n)
  if n == "" or string.len(n) < 2 or string.len(n) > 34 then return true end
  local words = 0; for _ in n:gmatch("%S+") do words = words + 1 end
  if words >= 5 then return true end
  return false
end

BLFG_5628_OldGuildNameFromAd = BLFG_5618_GuildNameFromAd or BLFG_5617_GuildNameFromAd
function BLFG_5628_GuildNameFromAd(text)
  local old = BLFG_5628_OldGuildNameFromAd and BLFG_5628_OldGuildNameFromAd(text)
  if old and old ~= "" then return old end

  local s = BLFG_5628_StripPrefix(text)
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return "" end
  local low = string.lower(s)
  local g

  -- Friendly/chill guild phrasing, e.g.
  -- "Looking for a chill guild? Drunken Dwarves is a friendly PvE community..."
  g = s:match("[Ll]ooking%s+for%s+a%s+chill%s+guild%?%s*([%w%s%'%-]+)%s+is%s+")
  if not g then g = s:match("[Ll]ooking%s+for%s+a%s+guild%?%s*([%w%s%'%-]+)%s+is%s+") end
  if not g then g = s:match("[%?%!%.]%s*([%w%s%'%-]+)%s+is%s+a%s+friendly%s+") end
  if not g then g = s:match("[%?%!%.]%s*([%w%s%'%-]+)%s+is%s+a%s+relaxed%s+") end
  if not g then g = s:match("[%?%!%.]%s*([%w%s%'%-]+)%s+is%s+a%s+casual%s+") end
  if not g then g = s:match("([%w%s%'%-]+)%s+is%s+a%s+friendly%s+[%w%s%-]*community") end
  if not g then g = s:match("([%w%s%'%-]+)%s+is%s+a%s+friendly%s+[%w%s%-]*guild") end

  if g then
    g = BLFG_5628_Clean(g)
    -- Trim leftover conversational lead-ins if a broad pattern caught too much.
    g = g:gsub("^.*[%?%!%.]%s*", "")
    if not BLFG_5628_BadGuildName(g) then return g end
  end

  return ""
end

BLFG_5628_OldIsGuildAd = BLFG_5618_IsGuildAd or BLFG_5617_IsGuildAd
function BLFG_5628_IsGuildAd(text)
  if BLFG_5628_OldIsGuildAd and BLFG_5628_OldIsGuildAd(text) then return true end
  local s = BLFG_5628_StripPrefix(text)
  local low = string.lower(s)
  local gn = BLFG_5628_GuildNameFromAd(s)
  if gn == "" then return false end
  local signal = low:find("guild",1,true) or low:find("community",1,true) or low:find("recruit",1,true) or low:find("raid",1,true) or low:find("discord",1,true) or low:find("pve",1,true) or low:find("pvp",1,true) or low:find("core",1,true)
  return signal and true or false
end

-- Replace all aliases still used by the stacked wrappers.
BLFG_5618_GuildNameFromAd = BLFG_5628_GuildNameFromAd; BLFG_5618_IsGuildAd = BLFG_5628_IsGuildAd
BLFG_5617_GuildNameFromAd = BLFG_5628_GuildNameFromAd; BLFG_5617_IsGuildAd = BLFG_5628_IsGuildAd
BLFG_5616_GuildNameFromAd = BLFG_5628_GuildNameFromAd; BLFG_5616_IsGuildAd = BLFG_5628_IsGuildAd
BLFG_5612_GuildNameFromAd = BLFG_5628_GuildNameFromAd; BLFG_5612_IsGuildAd = BLFG_5628_IsGuildAd
BLFG_569_GuildNameFromAd = BLFG_5628_GuildNameFromAd; BLFG_569_IsGuildAd = BLFG_5628_IsGuildAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_5628_IsGuildAd

function BLFG_5628_AddCSV(raw, tag)
  raw = tostring(raw or "")
  if raw == "" or raw == "Unknown" or raw == "[Unknown]" then raw = "" end
  local seen = {}
  for t in string.gmatch(raw, "([^,]+)") do t=t:gsub("^%s+",""):gsub("%s+$",""); if t ~= "" then seen[t]=true end end
  if not seen[tag] then raw = raw ~= "" and (raw .. "," .. tag) or tag end
  return raw
end

BLFG_5628_OldRawFocus = BLFG_5627_RawFocus or BLFG_5625_RawFocus
function BLFG_5628_RawFocus(text)
  local s = tostring(text or "")
  local low = string.lower(s)
  local raw = BLFG_5628_OldRawFocus and BLFG_5628_OldRawFocus(s) or ""

  -- Bronzebeard shorthand and conversational guild-ad phrasing.
  if low:find("%f[%a]asc%f[%A]") or low:find("asc onyxia",1,true) or low:find("mc%(asc%)") or low:find("ony%(asc%)") or low:find("onyx?%s*~?%s*asc") then raw = BLFG_5628_AddCSV(raw, "Ascended") end
  if low:find("mythic%+",1,false) or low:find("mythic plus",1,true) or low:find("m%+",1,false) or low:find("myth%+",1,false) then raw = BLFG_5628_AddCSV(raw, "Mythic+") end
  if low:find("raid",1,true) or low:find("raid core",1,true) or low:find("bwl",1,true) or low:find("onyxia",1,true) or low:find("ony",1,true) or low:find("molten core",1,true) or low:find("zg",1,true) or low:find("realm first",1,true) then raw = BLFG_5628_AddCSV(raw, "Raiding") end
  if low:find("pve community",1,true) or low:find("friendly",1,true) or low:find("chill",1,true) or low:find("no toxicity",1,true) or low:find("no pressure",1,true) or low:find("hang with us",1,true) or low:find("community",1,true) then raw = BLFG_5628_AddCSV(raw, "Social") end
  if low:find("pvp",1,true) then raw = BLFG_5628_AddCSV(raw, "PvP") end
  if low:find("boss blitz",1,true) or low:find("bossblitz",1,true) then raw = BLFG_5628_AddCSV(raw, "Boss Blitz") end
  if low:find("hcbb",1,true) or low:find("hardcore boss",1,true) then raw = BLFG_5628_AddCSV(raw, "HCBB") end

  return raw
end
BLFG_5627_RawFocus = BLFG_5628_RawFocus
BLFG_5625_RawFocus = BLFG_5628_RawFocus

BLFG_5628_OldRoleRaw = BLFG_5627_RoleRaw or BLFG_5625_RoleRaw
function BLFG_5628_RoleRaw(text)
  local s = tostring(text or "")
  local low = string.lower(s)
  local raw = BLFG_5628_OldRoleRaw and BLFG_5628_OldRoleRaw(s) or ""
  local t,h,d = false,false,false
  if raw:find("T") then t=true end; if raw:find("H") then h=true end; if raw:find("D") then d=true end
  if low:find("tank",1,true) or low:find("flexible tanks",1,true) or low:find("flex tanks",1,true) then t=true end
  if low:find("hpal",1,true) or low:find("healer",1,true) or low:find("healers",1,true) or low:find("heals",1,true) then h=true end
  if low:find("dps",1,true) or low:find("melee",1,true) or low:find("ranged",1,true) or low:find("caster",1,true) then d=true end
  local out = {}
  if t then table.insert(out,"T") end; if h then table.insert(out,"H") end; if d then table.insert(out,"D") end
  return table.concat(out, ",")
end
BLFG_5627_RoleRaw = BLFG_5628_RoleRaw
BLFG_5625_RoleRaw = BLFG_5628_RoleRaw

-- Make the 5.6.27 polish find chat-only guild rows by normalized key, not just exact guild name.
BLFG_5628_OldUpsertGuildBrowserChatListing = BLFG.UpsertGuildBrowserChatListing
if BLFG_5628_OldUpsertGuildBrowserChatListing then
  function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
    guildName = guildName or BLFG_5628_GuildNameFromAd(text or "")
    local r = BLFG_5628_OldUpsertGuildBrowserChatListing(self, guildName, author, text)
    local key = BLFG_5618_Norm and BLFG_5618_Norm(guildName or "") or string.lower(tostring(guildName or "")):gsub("[^%w]+","")
    local g = nil
    if self.chatGuildListings then g = self.chatGuildListings[key] end
    if not g and BronzeLFG_DB and BronzeLFG_DB.chatGuildListings then g = BronzeLFG_DB.chatGuildListings[key] end
    if not g and self.guilds then g = self.guilds[guildName] end
    if not g and self.bronzeNetGuilds then g = self.bronzeNetGuilds[guildName] end
    if g then
      g.lastPost = tostring(text or g.lastPost or "")
      g.message = g.lastPost
      g.rawMessage = g.lastPost
      local f = BLFG_5628_RawFocus(g.lastPost)
      if f ~= "" then g.focusRaw=f; g.focus=f; g.focusText=f; g.postFocus=f end
      local roles = BLFG_5628_RoleRaw(g.lastPost)
      if roles ~= "" then g.recruitingRaw=roles; g.recruiting=roles end
      local disc = BLFG_5625_Discord and BLFG_5625_Discord(g.lastPost) or (BLFG_ExtractDiscord and BLFG_ExtractDiscord(g.lastPost)) or ""
      if disc ~= "" then g.discord=disc; g.discordLink=disc end
    end
    return r
  end
end

-- If a guild slips through with Unknown focus but has a recruitment message, recover on refresh/detail.
BLFG_5628_OldPolishGuildData = BLFG_5627_PolishGuildData
function BLFG_5627_PolishGuildData(g)
  if BLFG_5628_OldPolishGuildData then BLFG_5628_OldPolishGuildData(g) end
  if not g then return end
  local msg = BLFG_5627_GuildText and BLFG_5627_GuildText(g) or table.concat({tostring(g.lastPost or ""), tostring(g.message or ""), tostring(g.rawMessage or "")}, " ")
  local f = BLFG_5628_RawFocus(msg)
  if f ~= "" then g.focusRaw=f; g.focus=f; g.focusText=f; g.postFocus=f end
  local roles = BLFG_5628_RoleRaw(msg)
  if roles ~= "" then g.recruitingRaw=roles; g.recruiting=roles end
end

function BLFG_5628_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.28"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end
f5628 = CreateFrame("Frame")
f5628:RegisterEvent("PLAYER_LOGIN")
f5628:SetScript("OnEvent", function() BLFG_5628_FixVersionText() end)

SLASH_BLFG5628TEST1 = "/blfgguildparse"
SlashCmdList["BLFG5628TEST"] = function()
  local a = "Hey! Looking for a chill guild? Drunken Dwarves is a friendly PvE community for all levels & races -- no toxicity, no pressure."
  local b = "<The Kids Next Door> 2/2 Asc Onyxia / 7/7 Myth BWL is recruiting for Raids & Mythic+ @ 7:30 P.M EST NA/English - Seeking DPS, Healers, Flexible Tanks / discord.gg/A9M6958HCp"
  DEFAULT_CHAT_FRAME:AddMessage("Drunken parse: " .. tostring(BLFG_5628_GuildNameFromAd(a)) .. " focus " .. tostring(BLFG_5628_RawFocus(a)))
  DEFAULT_CHAT_FRAME:AddMessage("Kids focus: " .. tostring(BLFG_5628_RawFocus(b)) .. " roles " .. tostring(BLFG_5628_RoleRaw(b)))
end

-- ============================================================
-- BronzeLFG v5.6.28a - recursion hotfix for guild focus/roles
-- ============================================================
BRONZELFG_VERSION = "5.6.28a"
VERSION = "5.6.28a"
if BLFG then BLFG.version = "5.6.28a" end

function BLFG_5628a_CleanCSV(raw)
  raw = tostring(raw or "")
  raw = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  raw = raw:gsub("%[", ""):gsub("%]", "")
  raw = raw:gsub("Unknown", "")
  raw = raw:gsub("unknown", "")
  raw = raw:gsub("%s+", " ")
  return raw
end

function BLFG_5628a_AddCSV(raw, tag)
  raw = BLFG_5628a_CleanCSV(raw)
  local seen = {}
  local out = {}
  for t in string.gmatch(raw, "([^,]+)") do
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then seen[t] = true; table.insert(out, t) end
  end
  if not seen[tag] then table.insert(out, tag) end
  return table.concat(out, ",")
end

-- IMPORTANT: This does not call BLFG_5625_RawFocus/BLFG_5627_RawFocus.
-- 5.6.28 accidentally made those aliases point back into itself, causing stack overflow.
function BLFG_5628a_RawFocus(text)
  local s = tostring(text or "")
  local low = string.lower(s)
  local raw = ""

  if low:find("asc onyxia",1,true) or low:find("%f[%a]asc%f[%A]") or low:find("mc%(asc%)") or low:find("ony%(asc%)") or low:find("bwl%(asc%)") or low:find("onyx?%s*~?%s*asc") then raw = BLFG_5628a_AddCSV(raw, "Ascended") end
  if low:find("mythic%+") or low:find("mythic plus",1,true) or low:find("m%+") or low:find("myth%+") then raw = BLFG_5628a_AddCSV(raw, "Mythic+") end
  if low:find("raid",1,true) or low:find("main%-?raids?",1,false) or low:find("raid core",1,true) or low:find("bwl",1,true) or low:find("onyxia",1,true) or low:find("%f[%a]ony%f[%A]") or low:find("molten core",1,true) or low:find("%f[%a]mc%f[%A]") or low:find("%f[%a]zg%f[%A]") or low:find("realm first",1,true) then raw = BLFG_5628a_AddCSV(raw, "Raiding") end
  if low:find("pve community",1,true) or low:find("friendly",1,true) or low:find("chill",1,true) or low:find("no toxicity",1,true) or low:find("no pressure",1,true) or low:find("hang with us",1,true) or low:find("community",1,true) or low:find("social",1,true) or low:find("casual",1,true) then raw = BLFG_5628a_AddCSV(raw, "Social") end
  if low:find("pvp",1,true) then raw = BLFG_5628a_AddCSV(raw, "PvP") end
  if low:find("boss blitz",1,true) or low:find("bossblitz",1,true) then raw = BLFG_5628a_AddCSV(raw, "Boss Blitz") end
  if low:find("hcbb",1,true) or low:find("hardcore boss",1,true) then raw = BLFG_5628a_AddCSV(raw, "HCBB") end
  if low:find("leveling",1,true) or low:find("levelling",1,true) then raw = BLFG_5628a_AddCSV(raw, "Leveling") end

  return raw
end

-- IMPORTANT: This also avoids calling old recursive aliases.
function BLFG_5628a_RoleRaw(text)
  local s = tostring(text or "")
  local low = string.lower(s)
  local t,h,d = false,false,false

  if low:find("tank",1,true) or low:find("tanks",1,true) or low:find("flexible tanks",1,true) or low:find("flex tanks",1,true) or low:find("%f[%a]mt%f[%A]") or low:find("%f[%a]ot%f[%A]") or low:find("prot",1,true) then t = true end
  if low:find("hpal",1,true) or low:find("holy pal",1,true) or low:find("healer",1,true) or low:find("healers",1,true) or low:find("heals",1,true) or low:find("resto",1,true) or low:find("disc priest",1,true) then h = true end
  if low:find("dps",1,true) or low:find("melee",1,true) or low:find("ranged",1,true) or low:find("caster",1,true) or low:find("hunter",1,true) or low:find("mage",1,true) or low:find("rogue",1,true) or low:find("warlock",1,true) then d = true end

  local out = {}
  if t then table.insert(out, "T") end
  if h then table.insert(out, "H") end
  if d then table.insert(out, "D") end
  return table.concat(out, ",")
end

-- Replace every parser alias that 5.6.27/5.6.28 use with the safe non-recursive version.
BLFG_5628_RawFocus = BLFG_5628a_RawFocus
BLFG_5627_RawFocus = BLFG_5628a_RawFocus
BLFG_5625_RawFocus = BLFG_5628a_RawFocus
BLFG_5628_RoleRaw = BLFG_5628a_RoleRaw
BLFG_5627_RoleRaw = BLFG_5628a_RoleRaw
BLFG_5625_RoleRaw = BLFG_5628a_RoleRaw

function BLFG_5628a_FixVersionText()
  if BLFG then
    BLFG.version = "5.6.28a"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end
f5628a = CreateFrame("Frame")
f5628a:RegisterEvent("PLAYER_LOGIN")
f5628a:SetScript("OnEvent", function() BLFG_5628a_FixVersionText() end)

SLASH_BLFG5628ATEST1 = "/blfgguildparse2"
SlashCmdList["BLFG5628ATEST"] = function()
  local a = "Hey! Looking for a chill guild? Drunken Dwarves is a friendly PvE community for all levels & races -- no toxicity, no pressure."
  local b = "<The Kids Next Door> 2/2 Asc Onyxia / 7/7 Myth BWL is recruiting for Raids & Mythic+ @ 7:30 P.M EST NA/English - Seeking DPS, Healers, Flexible Tanks / discord.gg/A9M6958HCp"
  DEFAULT_CHAT_FRAME:AddMessage("Drunken focus: " .. tostring(BLFG_5628a_RawFocus(a)))
  DEFAULT_CHAT_FRAME:AddMessage("Kids focus: " .. tostring(BLFG_5628a_RawFocus(b)) .. " roles " .. tostring(BLFG_5628a_RoleRaw(b)))
end

-- ============================================================
-- BronzeLFG v5.7.0-beta1a - Guild parser beta pass
-- Occult/Spanish guild ads + safer non-recursive parser aliases
-- ============================================================
BRONZELFG_VERSION = "5.7.0-beta1a"
VERSION = "5.7.0-beta1a"
if BLFG then BLFG.version = "5.7.0-beta1a" end

function BLFG_570b1_CleanText(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%w+}", " ")
  s = s:gsub("%b[]", function(x)
    -- Keep bracketed guild names but discard common chat/channel wrappers.
    local y = x:sub(2, -2)
    local low = string.lower(y)
    if low == "2%. ascension" or low == "ascension" or low:find("^%d+%.%s*ascension") then return " " end
    return x
  end)
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function BLFG_570b1_StripChatPrefix(s)
  s = BLFG_570b1_CleanText(s)
  -- Remove common visible channel/player prefix while preserving the actual message.
  s = s:gsub("^%s*%[%d+%.%s*Ascension%]%s*%[[^%]]+%]:%s*", "")
  s = s:gsub("^%s*%[%d+%.%s*Ascension%]%s*<[^>]+>%s*:%s*", "")
  s = s:gsub("^%s*%[[^%]]+%]:%s*", "")
  return s
end

function BLFG_570b1_CleanGuildName(g)
  g = tostring(g or "")
  g = g:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  g = g:gsub("{%w+}", " ")
  g = g:gsub("^%s*[<%[]", ""):gsub("[>%]]%s*$", "")
  g = g:gsub("^[%s%p]+", ""):gsub("[%s%p]+$", "")
  g = g:gsub("%s+", " ")
  return g
end

function BLFG_570b1_BadGuildName(g)
  g = BLFG_570b1_CleanGuildName(g)
  if g == "" or #g < 2 or #g > 32 then return true end
  local low = string.lower(g)
  if low == "ascension" or low == "guild" or low == "looking for a chill guild" then return true end
  if low:find("^lfm") or low:find("^lfg") or low:find("^need") or low:find("^recruiting") then return true end
  return false
end

function BLFG_570b1_GuildNameFromAd(text)
  local s = BLFG_570b1_StripChatPrefix(text)
  local g

  -- Classic guild tag ads: <Occult> / <The Kids Next Door>
  g = s:match("<([^>]+)>")
  if g and not BLFG_570b1_BadGuildName(g) then return BLFG_570b1_CleanGuildName(g) end

  -- Bracket guild ad: [Chaotics Ascension] recluta...
  g = s:match("^%s*%[([^%]]+)%]%s+.*")
  if g and not BLFG_570b1_BadGuildName(g) then return BLFG_570b1_CleanGuildName(g) end

  -- Decorated/all-caps guild name before NA/EU or server tags.
  g = s:match("^[%s%p]*([%u][%u%s%'%-]+)[%s%p]*%[NA/EU%]")
  if g and not BLFG_570b1_BadGuildName(g) then return BLFG_570b1_CleanGuildName(g) end

  -- Conversational phrasing: Looking for a chill guild? Drunken Dwarves is...
  g = s:match("[Ll]ooking%s+for%s+a%s+chill%s+guild%?%s*([%w%s%'%-]+)%s+is%s+")
  if not g then g = s:match("[Ll]ooking%s+for%s+a%s+guild%?%s*([%w%s%'%-]+)%s+is%s+") end
  if not g then g = s:match("[%?%!%.]%s*([%w%s%'%-]+)%s+is%s+a%s+friendly%s+") end
  if not g then g = s:match("([%w%s%'%-]+)%s+is%s+a%s+friendly%s+[%w%s%-]*community") end
  if g then
    g = g:gsub("^.*[%?%!%.]%s*", "")
    if not BLFG_570b1_BadGuildName(g) then return BLFG_570b1_CleanGuildName(g) end
  end

  -- Fall back to the last known parser only if it returns a sane name.
  if BLFG_5628_GuildNameFromAd then
    local old = BLFG_5628_GuildNameFromAd(text)
    if old and old ~= "" and not BLFG_570b1_BadGuildName(old) then return BLFG_570b1_CleanGuildName(old) end
  end

  return ""
end

function BLFG_570b1_IsGuildAd(text)
  local s = BLFG_570b1_StripChatPrefix(text)
  if s == "" then return false end
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return false end
  if s:find("BLFG%d*[%|~]", 1, false) or s:find("~PING~", 1, true) then return false end

  local low = string.lower(s)
  local g = BLFG_570b1_GuildNameFromAd(s)
  if g == "" then return false end

  -- English + Spanish recruitment/community signals.
  if low:find("recruit",1,true) or low:find("looking for",1,true) or low:find("seeking",1,true) or low:find("guild",1,true) or low:find("community",1,true) then return true end
  if low:find("recluta",1,true) or low:find("reclutando",1,true) or low:find("buscamos",1,true) or low:find("gremio",1,true) then return true end

  -- Guild-tag raid progression/schedule ads, e.g. <Occult> + BWL CE/SEA...
  if low:find("bwl",1,true) or low:find("molten core",1,true) or low:find("%f[%a]mc%f[%A]") or low:find("%f[%a]zg%f[%A]") or low:find("onyxia",1,true) or low:find("naxx",1,true) or low:find("aq",1,true) or low:find("raid",1,true) or low:find("core",1,true) then return true end
  if low:find("discord",1,true) or low:find("pve",1,true) or low:find("pvp",1,true) or low:find("casual",1,true) or low:find("welcome",1,true) then return true end
  if low:find("%d+:%d+%s*[ap]%.?m") or low:find("%d+:%d+%s*st") or low:find("%d+:%d+%s*cet") or low:find("%d+:%d+%s*est") then return true end

  return false
end

function BLFG_570b1_AddCSV(raw, tag)
  raw = tostring(raw or "")
  raw = raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  raw = raw:gsub("%[", ""):gsub("%]", "")
  raw = raw:gsub("Unknown", ""):gsub("unknown", "")
  local seen, out = {}, {}
  for t in string.gmatch(raw, "([^,]+)") do
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" and not seen[t] then seen[t] = true; table.insert(out, t) end
  end
  if not seen[tag] then table.insert(out, tag) end
  return table.concat(out, ",")
end

function BLFG_570b1_RawFocus(text)
  local s = tostring(text or "")
  local low = string.lower(s)
  local raw = ""

  if low:find("mythic%+") or low:find("mythic plus",1,true) or low:find("m%+") or low:find("myth%+",1,true) or low:find("keystone",1,true) or low:find("%f[%a]keys?%f[%A]") then raw = BLFG_570b1_AddCSV(raw, "Keys") end
  if low:find("raid",1,true) or low:find("raids",1,true) or low:find("bwl",1,true) or low:find("onyxia",1,true) or low:find("%f[%a]ony%f[%A]") or low:find("molten core",1,true) or low:find("%f[%a]mc%f[%A]") or low:find("%f[%a]zg%f[%A]") or low:find("naxx",1,true) or low:find("aq",1,true) or low:find("core principal",1,true) or low:find("main%-?raids?",1,false) then raw = BLFG_570b1_AddCSV(raw, "Raiding") end
  if low:find("pve",1,true) or low:find("friendly",1,true) or low:find("chill",1,true) or low:find("casual",1,true) or low:find("welcome",1,true) or low:find("community",1,true) or low:find("no toxicity",1,true) or low:find("no pressure",1,true) or low:find("buen ambiente",1,true) or low:find("risas",1,true) then raw = BLFG_570b1_AddCSV(raw, "Social") end
  if low:find("pvp",1,true) then raw = BLFG_570b1_AddCSV(raw, "PvP") end
  if low:find("world boss",1,true) or low:find("world bosses",1,true) or low:find("bosses",1,true) then raw = BLFG_570b1_AddCSV(raw, "World Boss") end
  if low:find("level",1,true) or low:find("leveling",1,true) or low:find("leveling",1,true) then raw = BLFG_570b1_AddCSV(raw, "Leveling") end

  return raw
end

function BLFG_570b1_RoleRaw(text)
  local low = string.lower(tostring(text or ""))
  local t,h,d = false,false,false

  if low:find("tank",1,true) or low:find("tanks",1,true) or low:find("tanque",1,true) or low:find("flexible tanks",1,true) or low:find("%f[%a]mt%f[%A]") or low:find("%f[%a]ot%f[%A]") or low:find("prot",1,true) then t = true end
  if low:find("hpal",1,true) or low:find("holy pal",1,true) or low:find("healer",1,true) or low:find("healers",1,true) or low:find("heals",1,true) or low:find("sanador",1,true) or low:find("sanadores",1,true) or low:find("curas",1,true) or low:find("resto",1,true) then h = true end
  if low:find("dps",1,true) or low:find("melee",1,true) or low:find("ranged",1,true) or low:find("caster",1,true) or low:find("boomi",1,true) or low:find("boomkin",1,true) or low:find("hunters?",1,false) or low:find("mage",1,true) or low:find("rogue",1,true) or low:find("warlock",1,true) then d = true end

  local out = {}
  if t then table.insert(out, "T") end
  if h then table.insert(out, "H") end
  if d then table.insert(out, "D") end
  return table.concat(out, ",")
end

-- Push the beta parser into every alias currently used by stacked wrappers.
BLFG_570b1_GuildNameFromAd_Safe = BLFG_570b1_GuildNameFromAd
BLFG_570b1_IsGuildAd_Safe = BLFG_570b1_IsGuildAd
BLFG_5628_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_5618_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_5617_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_5616_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_5612_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_569_GuildNameFromAd = BLFG_570b1_GuildNameFromAd_Safe
BLFG_5628_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_5618_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_5617_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_5616_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_5612_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_569_IsGuildAd = BLFG_570b1_IsGuildAd_Safe
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_570b1_IsGuildAd_Safe
BLFG_5628_RawFocus = BLFG_570b1_RawFocus
BLFG_5628a_RawFocus = BLFG_570b1_RawFocus
BLFG_5627_RawFocus = BLFG_570b1_RawFocus
BLFG_5625_RawFocus = BLFG_570b1_RawFocus
BLFG_5628_RoleRaw = BLFG_570b1_RoleRaw
BLFG_5628a_RoleRaw = BLFG_570b1_RoleRaw
BLFG_5627_RoleRaw = BLFG_570b1_RoleRaw
BLFG_5625_RoleRaw = BLFG_570b1_RoleRaw

-- Ensure upsert refreshes focus/roles/discord with the beta parser.
BLFG_570b1_OldUpsertGuildBrowserChatListing = BLFG.UpsertGuildBrowserChatListing
if BLFG_570b1_OldUpsertGuildBrowserChatListing then
  function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
    guildName = guildName or BLFG_570b1_GuildNameFromAd(text or "")
    local r = BLFG_570b1_OldUpsertGuildBrowserChatListing(self, guildName, author, text)
    local key = BLFG_5618_Norm and BLFG_5618_Norm(guildName or "") or string.lower(tostring(guildName or "")):gsub("[^%w]+","")
    local g = nil
    if self.chatGuildListings then g = self.chatGuildListings[key] end
    if not g and BronzeLFG_DB and BronzeLFG_DB.chatGuildListings then g = BronzeLFG_DB.chatGuildListings[key] end
    if not g and self.guilds then g = self.guilds[guildName] end
    if not g and self.bronzeNetGuilds then g = self.bronzeNetGuilds[guildName] end
    if g then
      local msg = tostring(text or g.lastPost or g.message or g.rawMessage or "")
      g.name = guildName or g.name
      g.guild = guildName or g.guild
      g.lastPost = msg; g.message = msg; g.rawMessage = msg
      local f = BLFG_570b1_RawFocus(msg)
      if f ~= "" then g.focusRaw=f; g.focus=f; g.focusText=f; g.postFocus=f end
      local roles = BLFG_570b1_RoleRaw(msg)
      if roles ~= "" then g.recruitingRaw=roles; g.recruiting=roles end
      local disc = BLFG_5625_Discord and BLFG_5625_Discord(msg) or (BLFG_ExtractDiscord and BLFG_ExtractDiscord(msg)) or ""
      if disc ~= "" then g.discord=disc; g.discordLink=disc end
    end
    return r
  end
end

-- Polish existing rows created earlier in the session.
BLFG_570b1_OldPolishGuildData = BLFG_5627_PolishGuildData
function BLFG_5627_PolishGuildData(g)
  if BLFG_570b1_OldPolishGuildData then BLFG_570b1_OldPolishGuildData(g) end
  if not g then return end
  local msg = table.concat({tostring(g.lastPost or ""), tostring(g.message or ""), tostring(g.rawMessage or "")}, " ")
  local f = BLFG_570b1_RawFocus(msg)
  if f ~= "" then g.focusRaw=f; g.focus=f; g.focusText=f; g.postFocus=f end
  local roles = BLFG_570b1_RoleRaw(msg)
  if roles ~= "" then g.recruitingRaw=roles; g.recruiting=roles end
end

function BLFG_570b1_FixVersionText()
  if BLFG then
    BLFG.version = "5.7.0-beta1a"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end
f570b1 = CreateFrame("Frame")
f570b1:RegisterEvent("PLAYER_LOGIN")
f570b1:SetScript("OnEvent", function() BLFG_570b1_FixVersionText() end)

SLASH_BLFG570B1TEST1 = "/blfgguildparse3"
SlashCmdList["BLFG570B1TEST"] = function()
  local a = "<Occult> + BWL CE/SEA (2/12 ASC) [6/7 M BWL LF Boomkin & talented players for BWL PROG! Mon/Thur 13:00 ST / 21:00 GMT+8 / 14:00 CET / 09:00 EST. Casuals welcome to level!"
  local b = "[Chaotics Ascension] recluta para CORE PRINCIPAL BWL! Buscamos Healers y DPS ! Exp en MC/ZG, farm runs y progreso. Discord activo, buen ambiente y risas."
  DEFAULT_CHAT_FRAME:AddMessage("Occult: " .. tostring(BLFG_570b1_GuildNameFromAd(a)) .. " focus " .. tostring(BLFG_570b1_RawFocus(a)) .. " roles " .. tostring(BLFG_570b1_RoleRaw(a)))
  DEFAULT_CHAT_FRAME:AddMessage("Chaotics: " .. tostring(BLFG_570b1_GuildNameFromAd(b)) .. " focus " .. tostring(BLFG_570b1_RawFocus(b)) .. " roles " .. tostring(BLFG_570b1_RoleRaw(b)))
end

-- ============================================================
-- BronzeLFG v5.7.0-beta1b - parser recursion hotfix
-- Removes fallback recursion caused by aliasing BLFG_5628_GuildNameFromAd.
-- ============================================================
BRONZELFG_VERSION = "5.7.0-beta1b"
VERSION = "5.7.0-beta1b"
if BLFG then BLFG.version = "5.7.0-beta1b" end

local function BLFG_570b1b_BadGuildCandidate(name)
  local raw = tostring(name or "")
  local low = string.lower(raw)
  low = low:gsub("^%s+", ""):gsub("%s+$", "")
  local compact = low:gsub("[%s%p]+", "")
  if raw == "" or compact == "" then return true end
  if BLFG_570b1_BadGuildName and BLFG_570b1_BadGuildName(raw) then return true end

  local bad = {
    hc=true, h=true, n=true, nm=true, heroic=true, normal=true,
    pvp=true, pve=true, rdf=true, lfg=true, lfm=true, lf=true,
    sw=true, org=true, vendor=true, vendors=true, guild=true,
    raid=true, dungeon=true, key=true, keys=true, social=true,
  }
  if bad[compact] then return true end
  if string.len(compact) < 3 then return true end
  return false
end

local function BLFG_570b1b_HasGuildRecruitmentIntent(low)
  if low:find("recruit", 1, true) or low:find("recrut", 1, true) then return true end
  if low:find("recluta", 1, true) or low:find("reclutando", 1, true) then return true end
  if low:find("buscamos", 1, true) or low:find("gremio", 1, true) then return true end
  if low:find("looking for a chill guild", 1, true) or low:find("looking for a guild", 1, true) then return true end
  if low:find("friendly", 1, true) and (low:find("guild", 1, true) or low:find("community", 1, true)) then return true end
  if low:find("join us", 1, true) or low:find("all levels welcome", 1, true) then return true end
  if low:find("raiders", 1, true) and (low:find("guild", 1, true) or low:find("community", 1, true)) then return true end
  if low:find("discord", 1, true) and (low:find("guild", 1, true) or low:find("community", 1, true) or low:find("recruit", 1, true)) then return true end
  if (low:find("pve", 1, true) or low:find("pvp", 1, true) or low:find("casual", 1, true)) and (low:find("guild", 1, true) or low:find("community", 1, true) or low:find("recruit", 1, true)) then return true end
  return false
end

local function BLFG_570b1b_IsObviousNonGuildChat(low)
  if (low:find("vendor", 1, true) or low:find("vendors", 1, true)) and not BLFG_570b1b_HasGuildRecruitmentIntent(low) then return true end
  if (low:find(" near ", 1, true) or low:find(" by ", 1, true)) and (low:find(" sw", 1, true) or low:find(" org", 1, true) or low:find("stormwind", 1, true) or low:find("orgrimmar", 1, true)) and not BLFG_570b1b_HasGuildRecruitmentIntent(low) then return true end
  return false
end

function BLFG_570b1b_GuildNameFromAd(text)
  local s = BLFG_570b1_StripChatPrefix and BLFG_570b1_StripChatPrefix(text) or tostring(text or "")
  local g

  -- Classic guild tag ads: <Occult> / <The Kids Next Door>
  g = s:match("<([^>]+)>")
  if g and not BLFG_570b1b_BadGuildCandidate(g) then
    return BLFG_570b1_CleanGuildName and BLFG_570b1_CleanGuildName(g) or g
  end

  -- Bracket guild ad: [Chaotics Ascension] recluta...
  g = s:match("^%s*%[([^%]]+)%]%s+.+")
  if g and not BLFG_570b1b_BadGuildCandidate(g) then
    local cleaned = BLFG_570b1_CleanGuildName and BLFG_570b1_CleanGuildName(g) or g
    local low = string.lower(cleaned or "")
    if low ~= "2%. ascension" and low ~= "ascension" and not low:find("^%d+%.%s*ascension") then
      return cleaned
    end
  end

  -- Decorated/all-caps guild name before NA/EU or server tags.
  g = s:match("^[%s%p]*([%u][%u%s%'%-]+)[%s%p]*%[NA/EU%]")
  if g and not BLFG_570b1b_BadGuildCandidate(g) then
    return BLFG_570b1_CleanGuildName and BLFG_570b1_CleanGuildName(g) or g
  end

  -- Conversational phrasing: Looking for a chill guild? Drunken Dwarves is...
  g = s:match("[Ll]ooking%s+for%s+a%s+chill%s+guild%?%s*([%w%s%'%-]+)%s+is%s+")
  if not g then g = s:match("[Ll]ooking%s+for%s+a%s+guild%?%s*([%w%s%'%-]+)%s+is%s+") end
  if not g then g = s:match("[%?%!%.]%s*([%w%s%'%-]+)%s+is%s+a%s+friendly%s+") end
  if not g then g = s:match("([%w%s%'%-]+)%s+is%s+a%s+friendly%s+[%w%s%-]*community") end
  if g then
    g = g:gsub("^.*[%?%!%.]%s*", "")
    if not BLFG_570b1b_BadGuildCandidate(g) then
      return BLFG_570b1_CleanGuildName and BLFG_570b1_CleanGuildName(g) or g
    end
  end

  return ""
end

function BLFG_570b1b_IsGuildAd(text)
  local s = BLFG_570b1_StripChatPrefix and BLFG_570b1_StripChatPrefix(text) or tostring(text or "")
  if s == "" then return false end
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(s) then return false end
  if s:find("BLFG%d*[%|~]", 1, false) or s:find("~PING~", 1, true) then return false end

  local low = string.lower(s)
  if BLFG_570b1b_IsObviousNonGuildChat(low) then return false end
  local g = BLFG_570b1b_GuildNameFromAd(s)
  if g == "" then return false end

  if BLFG_570b1b_HasGuildRecruitmentIntent(low) then return true end
  if (low:find("bwl",1,true) or low:find("molten core",1,true) or low:find("%f[%a]mc%f[%A]") or low:find("%f[%a]zg%f[%A]") or low:find("onyxia",1,true) or low:find("naxx",1,true) or low:find("aq",1,true) or low:find("raid",1,true) or low:find("core",1,true)) and (low:find("guild",1,true) or low:find("recruit",1,true) or low:find("community",1,true)) then return true end
  if (low:find("%d+:%d+%s*[ap]%.?m") or low:find("%d+:%d+%s*st") or low:find("%d+:%d+%s*cet") or low:find("%d+:%d+%s*est")) and (low:find("guild",1,true) or low:find("recruit",1,true)) then return true end
  return false
end

-- Reset all stacked aliases to the non-recursive hotfix versions.
BLFG_570b1_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_570b1_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_5628_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_5618_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_5617_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_5616_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_5612_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_569_GuildNameFromAd = BLFG_570b1b_GuildNameFromAd
BLFG_5628_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_5618_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_5617_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_5616_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_5612_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_569_IsGuildAd = BLFG_570b1b_IsGuildAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_570b1b_IsGuildAd

f570b1b = CreateFrame("Frame")
f570b1b:RegisterEvent("PLAYER_LOGIN")
f570b1b:SetScript("OnEvent", function()
  if BLFG then
    BLFG.version = "5.7.0-beta1b"
    if BLFG.versionText then BLFG.versionText:SetText("") end
  end
end)

-- ============================================================
-- BronzeLFG v5.7.0-beta1d - Public Groups LFG classification pass
-- Fixes player-LFG posts being classified as Key/Dungeon/Event.
-- Keeps recruiter posts like LF + DPS [Keystone] as Key.
-- Makes HCBB a tag/context, not an Event override, when a real dungeon is detected.
-- ============================================================
BRONZELFG_VERSION = "5.7.13-parity"
VERSION = "5.7.13-parity"
if BLFG then BLFG.version = "5.7.13-parity" end

function BLFG_570b1c_Lower(s)
  return string.lower(tostring(s or ""))
end

function BLFG_570b1c_CleanMsg(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  s = s:gsub("{%w+%d*}", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function BLFG_570b1c_HasWord(s, w)
  s = " " .. BLFG_570b1c_Lower(s):gsub("[^%w%+]+", " ") .. " "
  return string.find(s, " " .. BLFG_570b1c_Lower(w) .. " ", 1, true) ~= nil
end

function BLFG_570b1c_IsRecruiterPost(text)
  local s = BLFG_570b1c_Lower(text)
  if s:find("lf%d+m") then return true end
  if s:find("lfm", 1, true) or s:find("lf1m", 1, true) or s:find("lf2m", 1, true) or s:find("lf3m", 1, true) or s:find("lf4m", 1, true) then return true end
  if s:find("need", 1, true) or s:find("last spot", 1, true) or s:find("one spot", 1, true) or s:find("need dps", 1, true) or s:find("need tank", 1, true) or s:find("need heal", 1, true) then return true end
  if s:find("lf%s*%+?%s*dps") or s:find("lf%s*%+?%s*tank") or s:find("lf%s*%+?%s*heal") or s:find("lf%s+range%s+dps") or s:find("lf%s+ranged%s+dps") then return true end
  if s:find("msg class", 1, true) or s:find("%[keystone:") then return true end
  return false
end

function BLFG_570b1c_IsPlayerLFG(text)
  local s = BLFG_570b1c_Lower(BLFG_570b1c_CleanMsg(text))
  if s == "" then return false end
  if BLFG_570b1c_IsRecruiterPost(s) then return false end
  if s:find("%f[%a]lfg%f[%A]") or s:find("looking%s+for%s+group") then return true end
  if s:find("^%s*lf%s+group") or s:find("^%s*lf%s+.+") then return true end
  -- Player descriptor before LF, e.g. "ret paly lf M+/BWL/MC".
  local before = s:match("^(.+)%f[%a]lf%f[%A]")
  if before then
    local b = " " .. before:gsub("[^%w]+", " ") .. " "
    if b:find(" ret ",1,true) or b:find(" pally ",1,true) or b:find(" paly ",1,true) or b:find(" paladin ",1,true) or
       b:find(" tank ",1,true) or b:find(" healer ",1,true) or b:find(" heal ",1,true) or b:find(" dps ",1,true) or
       b:find(" mage ",1,true) or b:find(" warlock ",1,true) or b:find(" lock ",1,true) or b:find(" hunter ",1,true) or
       b:find(" rogue ",1,true) or b:find(" priest ",1,true) or b:find(" shaman ",1,true) or b:find(" druid ",1,true) or
       b:find(" warrior ",1,true) or b:find(" boom ",1,true) or b:find(" shadow ",1,true) or b:find(" ele ",1,true) then return true end
  end
  return false
end

function BLFG_570b1c_ActivitySignals(text)
  local s = BLFG_570b1c_Lower(text)
  local raid = s:find("bwl",1,true) or s:find(" mc",1,true) or s:find("molten core",1,true) or s:find("zg",1,true) or s:find("ony",1,true) or s:find("naxx",1,true) or s:find("aq20",1,true) or s:find("aq ruins",1,true) or s:find("ossirian",1,true) or s:find("aq40",1,true) or s:find("kara",1,true) or s:find("karazhan",1,true) or s:find("prince",1,true)
  local key = s:find("m+",1,true) or s:find("mythic+",1,true) or s:find("keystone",1,true)
  local dungeon = s:find("deadmines",1,true) or s:find(" wc",1,true) or s:find("wailing",1,true) or s:find("rfd",1,true) or s:find("rfk",1,true) or s:find("sfk",1,true) or s:find("bfd",1,true) or s:find("mara",1,true) or s:find("uldaman",1,true) or s:find("ulda",1,true) or s:find("dire maul",1,true) or s:find(" dm",1,true) or s:find("sm ",1,true) or s:find("scarlet",1,true) or s:find("gnomer",1,true)
    or s:find("hellfire",1,true) or s:find("ramparts",1,true) or s:find("blood furnace",1,true) or s:find("slave pens",1,true) or s:find("underbog",1,true) or s:find("steamvault",1,true) or s:find("mana%-tombs") or s:find("mana tombs",1,true) or s:find("auchenai",1,true) or s:find("sethekk",1,true) or s:find("shadow labyrinth",1,true) or s:find("shattered halls",1,true) or s:find("mechanar",1,true) or s:find("botanica",1,true) or s:find("arcatraz",1,true) or s:find("magisters",1,true)
    or s:find("utgarde",1,true) or s:find("nexus",1,true) or s:find("oculus",1,true) or s:find("azjol",1,true) or s:find("ahn",1,true) or s:find("old kingdom",1,true) or s:find("drak",1,true) or s:find("violet hold",1,true) or s:find("gundrak",1,true) or s:find("halls of stone",1,true) or s:find("halls of lightning",1,true) or s:find("culling",1,true) or s:find("trial of the champion",1,true) or s:find("forge of souls",1,true) or s:find("pit of saron",1,true) or s:find("halls of reflection",1,true)
  local count = 0; if raid then count=count+1 end; if key then count=count+1 end; if dungeon then count=count+1 end
  return raid, key, dungeon, count
end

function BLFG_570b1c_IsDungeonActivity(activity)
  local a = BLFG_570b1c_Lower(activity)
  if a == "" then return false end
  local tokens = {
    "deadmines","wailing caverns","ragefire","razorfen","shadowfang","blackfathom","gnomeregan","stockade","scarlet monastery","uldaman","zul'farrak","zulfarrak","maraudon","sunken temple","blackrock depths","blackrock spire","dire maul","scholomance","stratholme","vaults of inquisition","road to de other side",
    "hellfire ramparts","blood furnace","slave pens","underbog","steamvault","mana-tombs","mana tombs","auchenai crypts","sethekk halls","shadow labyrinth","shattered halls","old hillsbrad","black morass","mechanar","botanica","arcatraz","magisters",
    "utgarde keep","utgarde pinnacle","nexus","oculus","azjol","ahn'kahet","old kingdom","drak'tharon","violet hold","gundrak","halls of stone","halls of lightning","culling of stratholme","trial of the champion","forge of souls","pit of saron","halls of reflection"
  }
  for _,v in ipairs(tokens) do if a:find(v,1,true) then return true end end
  return false
end

function BLFG_5713_RaidActivity(text)
  local profileActivity = SFProfileMatchActivity(text or "")
  if profileActivity and PUBLIC_RAID_ACTIVITIES[profileActivity] then return profileActivity end
  local s = " " .. BLFG_570b1c_Lower(BLFG_570b1c_CleanMsg(text or "")) .. " "
  local raids = {
    {"Molten Core", {" mc ", " molten core "}},
    {"Onyxia", {" ony ", " onyxia "}},
    {"Zul'Gurub", {" zg ", " zul gurub ", " zulgurub "}},
    {"Ruins of Ahn'Qiraj", {" aq20 ", " aq ruins ", " aq ruin ", " ruins of ahn qiraj ", " ruins aq ", " raq ", " ossirian "}},
    {"Temple of Ahn'Qiraj", {" aq40 ", " temple of ahn qiraj ", " temple aq "}},
    {"Blackwing Lair", {" bwl ", " blackwing lair "}},
    {"Naxxramas", {" naxx ", " naxxramas "}},
    {"Karazhan", {" kara ", " karazhan ", " prince ", " prince malchezaar "}},
    {"Gruul's Lair", {" gruul ", " gruuls lair ", " gruul s lair "}},
    {"Magtheridon's Lair", {" magtheridon ", " magtheridons lair ", " magtheridon s lair ", " mag "}},
    {"Serpentshrine Cavern", {" ssc ", " serpentshrine ", " serpentshrine cavern "}},
    {"Tempest Keep", {" tempest keep ", " the eye ", " tk "}},
    {"Battle for Mount Hyjal", {" hyjal ", " mount hyjal ", " mh "}},
    {"Black Temple", {" black temple ", " bt "}},
    {"Sunwell Plateau", {" sunwell ", " sunwell plateau ", " swp "}},
    {"Vault of Archavon", {" voa ", " vault of archavon ", " archavon "}},
    {"The Obsidian Sanctum", {" os ", " obsidian sanctum ", " sarth ", " sartharion "}},
    {"The Eye of Eternity", {" eoe ", " eye of eternity ", " malygos "}},
    {"Ulduar", {" ulduar ", " uld "}},
    {"Trial of the Crusader", {" toc ", " trial of the crusader ", " totc "}},
    {"Icecrown Citadel", {" icc ", " icecrown citadel "}},
    {"The Ruby Sanctum", {" ruby sanctum ", " rs ", " halion "}},
  }
  for _, row in ipairs(raids) do
    for _, token in ipairs(row[2]) do
      if s:find(token, 1, true) then return row[1] end
    end
  end
  return nil
end

function BLFG_570b1c_ApplyPublicParserFix(g)
  if not g then return end
  local msg = tostring(g.message or g.rawMessage or "")
  if msg == "" then return end
  local low = BLFG_570b1c_Lower(msg)
  local isRDF = low:find("rdf", 1, true) or low:find("random dungeon", 1, true)
    or (low:find("queue", 1, true) and (low:find("dungeon", 1, true) or low:find("bc", 1, true) or low:find("tbc", 1, true) or low:find("wrath", 1, true) or low:find("wotlk", 1, true)))
  if isRDF and BLFG_570b1c_IsRecruiterPost(low) then
    g.type = "Dungeon"
    g.intent = "Recruiter"
    if low:find("bc", 1, true) or low:find("tbc", 1, true) or low:find("outland", 1, true) then
      g.activity = "BC Random Dungeon Finder"
    elseif low:find("wrath", 1, true) or low:find("wotlk", 1, true) or low:find("northrend", 1, true) then
      g.activity = "Wrath Random Dungeon Finder"
    else
      g.activity = "Random Dungeon Finder"
    end
    g.tags = "Dungeon"
    return
  end
  local raidActivity = BLFG_5713_RaidActivity(msg)
  if raidActivity and BLFG_570b1c_IsRecruiterPost(low) and not BLFG_570b1c_IsPlayerLFG(msg) then
    g.type = "Raid"
    g.intent = "Recruiter"
    g.activity = raidActivity
    g.tags = "Raid"
    return
  end
  if BLFG_570b1c_IsRecruiterPost(low) and BLFG_570b1c_IsDungeonActivity(g.activity or "") then
    g.type = "Dungeon"
    g.intent = "Recruiter"
    g.tags = tostring(g.tags or "")
    if not g.tags:find("Dungeon",1,true) then g.tags = (g.tags ~= "" and (g.tags .. ",") or "") .. "Dungeon" end
    return
  end
  if BLFG_570b1c_IsPlayerLFG(msg) then
    g.type = "LFG"
    g.intent = "Applicant"
    local raid, key, dungeon, count = BLFG_570b1c_ActivitySignals(msg)
    if count >= 2 then
      g.activity = "Mixed Content"
    elseif (not g.activity or g.activity == "" or g.activity == "Mythic+" or g.activity == "Molten Core") and key then
      g.activity = "Mythic+"
    elseif not g.activity or g.activity == "" or g.activity == "General Listing" then
      g.activity = "Looking For Group"
    end
    g.tags = "LFG"
    g.score = tonumber(g.score or 0) or 0
    return
  end
  -- HCBB should not make a named dungeon into Event.
  if tostring(g.type or "") == "Event" and BLFG_570b1c_IsDungeonActivity(g.activity or "") then
    g.type = "Dungeon"
    g.intent = g.intent or "Recruiter"
    g.tags = tostring(g.tags or "")
    if not g.tags:find("Dungeon",1,true) then g.tags = (g.tags ~= "" and (g.tags .. ",") or "") .. "Dungeon" end
    if msg:lower():find("hcbb",1,true) and not g.tags:find("HCBB",1,true) then g.tags = g.tags .. ",HCBB" end
  end
end

BLFG_570b1c_OldAddPublicGroup = BLFG and BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  local name = tostring(author or ""):gsub("%-.*", "")
  local r = BLFG_570b1c_OldAddPublicGroup and BLFG_570b1c_OldAddPublicGroup(self, author, text, channelName)
  if self._suppressPublicRefreshInChatLink then
    local touched = r or self._lastPublicGroupTouched
    if touched then
      BLFG_570b1c_ApplyPublicParserFix(touched)
      self._lastPublicGroupTouched = touched
      if self.RefreshPublicGroups then self:RequestPublicGroupsRefresh() end
    end
    return touched or r
  end
  local newest, newestKey, newestSeen
  for k,g in pairs(self.publicGroups or {}) do
    if g and g.player == name then
      local seen = tonumber(g.seen or g.created or 0) or 0
      if (not newestSeen or seen >= newestSeen) then newest, newestKey, newestSeen = g, k, seen end
    end
  end
  if newest then
    BLFG_570b1c_ApplyPublicParserFix(newest)
    self._lastPublicGroupTouched = newest
    self._lastPublicGroupTouchedKey = newestKey
    if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  end
  return newest or r
end

BLFG_570b1c_OldRefreshPublicGroups = BLFG and BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  for _,g in pairs(self.publicGroups or {}) do BLFG_570b1c_ApplyPublicParserFix(g) end
  return BLFG_570b1c_OldRefreshPublicGroups and BLFG_570b1c_OldRefreshPublicGroups(self, ...)
end

SLASH_BLFGPUBPARSE1 = "/blfgpubparse"
SlashCmdList["BLFGPUBPARSE"] = function()
  local samples = {
    "ret paly lf M+/bwl/mc",
    "LFG for WC HC-bb",
    "tank lfg deadmines hcbb",
    "LF1M tank RFD HCBB!",
    "LF + dps [Keystone: Uldaman (1)] msg class + ilvl",
  }
  for _,s in ipairs(samples) do
    DEFAULT_CHAT_FRAME:AddMessage("BLFG public parse sample: " .. s .. " => playerLFG=" .. tostring(BLFG_570b1c_IsPlayerLFG(s)))
  end
end

BLFG_570b1c_Frame = CreateFrame("Frame")
BLFG_570b1c_Frame:RegisterEvent("PLAYER_LOGIN")
BLFG_570b1c_Frame:SetScript("OnEvent", function()
  if BLFG then
    BLFG.version = "5.7.13-parity"
    if BLFG.versionText then BLFG.versionText:SetText("") end
    if BLFG.publicGroups then for _,g in pairs(BLFG.publicGroups) do BLFG_570b1c_ApplyPublicParserFix(g) end end
  end
end)

-- ============================================================
-- SignalFire 5.7.13 - Triumvirate public chat noise gate
-- Keeps real RDF/TBC/Wrath queue posts, but drops conversation about queues.
-- ============================================================
function BLFG_5713_IsStrongPublicListing(text)
  local s = " " .. BLFG_570b1c_Lower(BLFG_570b1c_CleanMsg(text or "")) .. " "
  if s == "  " then return false end
  if s:find(" lf%d+m") then return true end
  if s:find(" lfm", 1, true) or s:find(" lf1m", 1, true) or s:find(" lf2m", 1, true) or s:find(" lf3m", 1, true) or s:find(" lf4m", 1, true) then return true end
  if s:find(" lfg ", 1, true) or s:find(" looking for group", 1, true) or s:find(" lf group", 1, true) or s:find(" lf grp", 1, true) then return true end
  if s:find(" need tank", 1, true) or s:find(" need healer", 1, true) or s:find(" need heals", 1, true) or s:find(" need dps", 1, true) or s:find(" need ", 1, true) then return true end
  if s:find(" lf tank", 1, true) or s:find(" lf healer", 1, true) or s:find(" lf heals", 1, true) or s:find(" lf dps", 1, true) then return true end
  if s:find(" rdf ", 1, true) or s:find(" random dungeon", 1, true) or s:find(" mythic+", 1, true) or s:find(" m+ ", 1, true) or s:find(" keystone", 1, true) then return true end
  if s:find(" tbc ", 1, true) or s:find(" wotlk ", 1, true) or s:find(" wrath ", 1, true) or s:find(" bc ", 1, true) then return true end
  if BLFG_570b1c_ActivitySignals then
    local raid, key, dungeon = BLFG_570b1c_ActivitySignals(s)
    if raid or key or dungeon then return true end
  end
  return false
end

function BLFG_5713_IsPublicQueueChatter(text)
  local s = " " .. BLFG_570b1c_Lower(BLFG_570b1c_CleanMsg(text or "")) .. " "
  if s == "  " then return false end
  if SF577_IsPublicQueueChatter and SF577_IsPublicQueueChatter(text) then return true end
  if s:find(" sitting in queue", 1, true) or s:find(" people are in queue", 1, true) or s:find(" in queue because", 1, true) then return true end
  if s:find(" when you queue random", 1, true) or s:find(" don't get the dungeon you want", 1, true) or s:find(" sit through a random dungeon", 1, true) then return true end
  if s:find(" was that ", 1, true) and (s:find(" queue random", 1, true) or s:find(" random dungeon", 1, true)) then return true end
  if s:find(" play what you want", 1, true) or s:find(" not a lot of people", 1, true) then return true end
  if s:find(" tanks atm", 1, true) or s:find(" tanks at the moment", 1, true) then return true end
  if (s:find(" i'm ", 1, true) or s:find(" im ", 1, true) or s:find(" i am ", 1, true)) and (s:find(" lol ", 1, true) or s:find(" queue ", 1, true)) then return true end
  if BLFG_5713_IsStrongPublicListing(s) then return false end
  if s:find(" queue ", 1, true) and (s:find(" tank", 1, true) or s:find(" healer", 1, true) or s:find(" heal", 1, true) or s:find(" dps", 1, true)) then return true end
  return false
end

BLFG_5713_NoiseGateOldAddPublicGroup = BLFG and BLFG.AddPublicGroup
function BLFG:AddPublicGroup(author, text, channelName)
  if BLFG_5713_IsPublicQueueChatter and BLFG_5713_IsPublicQueueChatter(text) then return end
  if BLFG_5713_IsStrongPublicListing and not BLFG_5713_IsStrongPublicListing(text) and not isPublicGuildText(text) then return end
  return BLFG_5713_NoiseGateOldAddPublicGroup and BLFG_5713_NoiseGateOldAddPublicGroup(self, author, text, channelName)
end

BLFG_5713_NoiseGateOldRefreshPublicGroups = BLFG and BLFG.RefreshPublicGroups
function BLFG:RefreshPublicGroups(...)
  for id, g in pairs(self.publicGroups or {}) do
    if g and (g.isInvasionBeacon or g.signalFireListing or tostring(id or ""):find("^listing%-")) then
      -- Curated SignalFire listings should remain until expired/cleared.
    elseif g and BLFG_5713_IsPublicQueueChatter and BLFG_5713_IsPublicQueueChatter(g.message or "") then
      self.publicGroups[id] = nil
    elseif g and BLFG_5713_IsStrongPublicListing and not BLFG_5713_IsStrongPublicListing(g.message or "") and not isPublicGuildText(g.message or "") then
      self.publicGroups[id] = nil
    end
  end
  return BLFG_5713_NoiseGateOldRefreshPublicGroups and BLFG_5713_NoiseGateOldRefreshPublicGroups(self, ...)
end

-- ============================================================
-- SignalFire 5.7.13 - Triumvirate /who guild discovery
-- Discovers active guilds from WHO results without treating them as ads.
-- ============================================================

local function SFWhoNorm(s)
  s = string.lower(tostring(s or ""))
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "%s+", " ")
  return s
end

local function SFWhoKey(s)
  return string.gsub(SFWhoNorm(s), "[^%w]+", "")
end

local function SFWhoCleanName(s)
  s = tostring(s or "")
  s = string.gsub(s, "%-.*$", "")
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  return s
end

local function SFWhoOptions()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  return BronzeLFG_DB.options
end

local function SFWhoEnabled()
  return SFWhoOptions().guildWhoDiscovery ~= false
end

local function SFWhoSetSilent()
  if SetWhoToUI then SetWhoToUI(1) end
  if WhoFrame and WhoFrame.Hide then WhoFrame:Hide() end
end

local function SFWhoRestoreUI()
  if SetWhoToUI then SetWhoToUI(0) end
end

local function SFWhoHideDefaultUI(scan)
  if WhoFrame and WhoFrame.Hide then WhoFrame:Hide() end
  if FriendsFrame and FriendsFrame.Hide and not (scan and scan.friendsWasShown) then FriendsFrame:Hide() end
end

function BLFG:EnsureWhoGuildDB()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.whoGuilds = BronzeLFG_DB.whoGuilds or {}
  self.whoGuilds = BronzeLFG_DB.whoGuilds
  return self.whoGuilds
end

function BLFG:EnsureWhoPlayerDB()
  BronzeLFG_DB = BronzeLFG_DB or {}
  BronzeLFG_DB.whoPlayers = BronzeLFG_DB.whoPlayers or {}
  self.whoPlayers = BronzeLFG_DB.whoPlayers
  return self.whoPlayers
end

function BLFG:PruneWhoGuilds()
  local db = self:EnsureWhoGuildDB()
  local players = self:EnsureWhoPlayerDB()
  local cutoff = now() - (14 * 24 * 60 * 60)
  for key, g in pairs(db) do
    if not g or (tonumber(g.lastSeen or 0) or 0) < cutoff then db[key] = nil end
  end
  local playerCutoff = now() - 3600
  for key, p in pairs(players) do
    if not p or (tonumber(p.seen or 0) or 0) < playerCutoff then players[key] = nil end
  end
end

function BLFG:RecordWhoGuildMember(name, guild, level, className, zone)
  name = SFWhoCleanName(name)
  guild = tostring(guild or "")
  if name == "" then return end
  local playerDB = self:EnsureWhoPlayerDB()
  playerDB[string.lower(name)] = {
    name = name,
    guild = guild,
    level = tostring(level or ""),
    classFile = normalizeClassFile(className or ""),
    zone = tostring(zone or ""),
    seen = now(),
  }
  if guild == "" then return end
  local key = SFWhoKey(guild)
  if key == "" then return end

  local db = self:EnsureWhoGuildDB()
  local rec = db[key]
  if not rec then
    rec = {name=guild, members={}, firstSeen=now(), lastSeen=now(), onlineSeen=0}
    db[key] = rec
  end
  rec.name = rec.name or guild
  rec.lastSeen = now()
  rec.members = rec.members or {}
  rec.members[name] = {
    name = name,
    guild = rec.name,
    level = tostring(level or ""),
    classFile = normalizeClassFile(className or ""),
    zone = tostring(zone or ""),
    seen = now(),
  }

  local scan = self.whoDiscovery
  if scan and scan.scanId then
    scan.guildPlayers = scan.guildPlayers or {}
    scan.guildPlayers[key] = scan.guildPlayers[key] or {}
    if not scan.guildPlayers[key][name] then
      scan.guildPlayers[key][name] = true
      rec.onlineSeen = (tonumber(rec.onlineSeen or 0) or 0) + 1
    end
    rec.currentScan = scan.scanId
  end
end

function BLFG:RequestPublicPlayerWho(name)
  name = SFWhoCleanName(name)
  if name == "" or name == playerName() then return end
  if not SFWhoEnabled() or not SendWho or not SetWhoToUI then return end
  if self.whoDiscovery and self.whoDiscovery.active then return end
  if self.invasionWhoScan and self.invasionWhoScan.active then return end
  self.publicPlayerWho = self.publicPlayerWho or {lastQuery={}, finalResult={}}
  local st = self.publicPlayerWho
  st.lastQuery = st.lastQuery or {}
  st.finalResult = st.finalResult or {}
  if st.active then return end

  local low = string.lower(name)
  local cached = self:EnsureWhoPlayerDB()[low]
  if cached and (now() - (tonumber(cached.seen or 0) or 0)) < 300 then return end
  if st.lastQuery[low] and (now() - (tonumber(st.lastQuery[low] or 0) or 0)) < 5 then return end

  st.active = true
  st.pendingName = name
  st.elapsed = 0
  st.lastPublicWhoRequestAt = now()
  st.lastQuery[low] = now()
  st.finalResult[low] = nil
  st.suppressWhoTextUntil = now() + 12
  self._publicWhoSuppressUntil = now() + 12
  st.friendsWasShown = FriendsFrame and FriendsFrame.IsShown and FriendsFrame:IsShown() and true or false
  if BLFG_InstallPublicWhoChatSuppressors then BLFG_InstallPublicWhoChatSuppressors() end
  SFWhoSetSilent()
  SendWho('n-"' .. name .. '"')
  SFWhoHideDefaultUI(st)
  if self.whoDiscoveryFrame then self.whoDiscoveryFrame:Show() end
end

function BLFG:PublicPlayerWhoTick(elapsed)
  local st = self.publicPlayerWho
  if not (st and st.active and st.pendingName) then return end
  st.elapsed = (tonumber(st.elapsed or 0) or 0) + (elapsed or 0)
  SFWhoHideDefaultUI(st)
  if st.elapsed < 10 then return end
  -- timeout reached: stop waiting and refresh UI. Mark as final result (not found).
  local pending = st.pendingName
  local pendingLow = string.lower(pending or "")
  st.active = false
  st.pendingName = nil
  st.elapsed = 0
  if pendingLow ~= "" then
    st.finalResult = st.finalResult or {}
    st.finalResult[pendingLow] = now()  -- Mark as "not seen at this time"
  end
  SFWhoRestoreUI()
  SFWhoHideDefaultUI(st)
  -- If the tooltip is currently owned by the row we were inspecting, add a "not seen yet" line
  if pending and GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner then
    local owner = GameTooltip:GetOwner()
    if owner and owner.fullPlayer and string.lower(owner.fullPlayer) == string.lower(pending) then
      GameTooltip:AddLine("|cFFFFCC00Player Info:|r |cFFAAAAAAnot seen yet|r", 1, 1, 1)
      GameTooltip:Show()
    end
  end
  if self.publicPanel and self.publicPanel:IsShown() and self.RefreshPublicGroups then self:RefreshPublicGroups() end
  if self.whoDiscoveryFrame and not (self.whoDiscovery and self.whoDiscovery.active) and not (self.publicPlayerWho and self.publicPlayerWho.active) then self.whoDiscoveryFrame:Hide() end
end

function BLFG:HandlePublicPlayerWhoUpdate()
  local st = self.publicPlayerWho
  local wanted
  local updated = false
  if st and st.pendingName then
    wanted = string.lower(SFWhoCleanName(st.pendingName))
    local count = GetNumWhoResults and GetNumWhoResults() or 0
    if count <= 0 then return false end
    local found = false
    for i = 1, count do
      local name, guild, level, race, className, zone, classFile = GetWhoInfo(i)
      local cleanName = SFWhoCleanName(name)
      if cleanName ~= "" and string.lower(cleanName) == wanted then
        self:RecordWhoGuildMember(cleanName, guild, level, classFile or className, zone)
        found = true
        break
      end
    end
    if not found then
      st.finalResult = st.finalResult or {}
      st.finalResult[wanted] = now()
    end
    st.suppressWhoTextUntil = now() + 12
    st.suppressWhoSummaryUntil = now() + 12
    st.lastPublicWhoRequestAt = now()
    self._publicWhoSuppressUntil = now() + 12
    st.active = false
    st.pendingName = nil
    st.elapsed = 0
    SFWhoRestoreUI()
    SFWhoHideDefaultUI(st)
    if self.whoDiscoveryFrame and not (self.whoDiscovery and self.whoDiscovery.active) and not (self.publicPlayerWho and self.publicPlayerWho.active) then self.whoDiscoveryFrame:Hide() end
    updated = true
  end

  local function RefreshTooltipForOwner(owner)
    if not owner or not owner.fullPlayer then return false end
    local lookup = BLFG_PublicPlayerLookup(self, owner.fullPlayer)
    if not lookup then return false end
    if not owner.fullPlayerLevel or owner.fullPlayerLevel == "" then owner.fullPlayerLevel = lookup.level end
    if not owner.fullPlayerClass or owner.fullPlayerClass == "" then owner.fullPlayerClass = lookup.classFile end
    if not owner.fullPlayerGuild or owner.fullPlayerGuild == "" then owner.fullPlayerGuild = lookup.guild end
    if not owner.fullPlayerZone or owner.fullPlayerZone == "" then owner.fullPlayerZone = lookup.zone end
    if not owner.fullPlayerInfoSource or owner.fullPlayerInfoSource == "" then owner.fullPlayerInfoSource = lookup.source end
    local onEnter = owner.GetScript and owner:GetScript("OnEnter")
    if GameTooltip and GameTooltip:IsShown() then
      GameTooltip:Hide()
      if onEnter then
        onEnter(owner)
      else
        -- Fallback: keep the tooltip visible after updating owner fields.
      end
      GameTooltip:Show()
    end
    return true
  end

  if self.publicPanel and self.publicPanel:IsShown() and self.RefreshPublicGroups then self:RefreshPublicGroups() end
  if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner then
    local owner = GameTooltip:GetOwner()
    if RefreshTooltipForOwner(owner) then updated = true end
  end

  return updated
end

local function SFWhoClassFromText(text)
  text = " " .. string.lower(tostring(text or "")) .. " "
  if string.find(text, " death knight ", 1, true) then return "DEATHKNIGHT" end
  if string.find(text, " warrior ", 1, true) then return "WARRIOR" end
  if string.find(text, " paladin ", 1, true) then return "PALADIN" end
  if string.find(text, " hunter ", 1, true) then return "HUNTER" end
  if string.find(text, " rogue ", 1, true) then return "ROGUE" end
  if string.find(text, " priest ", 1, true) then return "PRIEST" end
  if string.find(text, " shaman ", 1, true) then return "SHAMAN" end
  if string.find(text, " mage ", 1, true) then return "MAGE" end
  if string.find(text, " warlock ", 1, true) then return "WARLOCK" end
  if string.find(text, " druid ", 1, true) then return "DRUID" end
  return ""
end

function BLFG_PublicWhoCleanSystemText(text)
  text = tostring(text or "")
  text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = string.gsub(text, "|r", "")
  text = string.gsub(text, "|H.-|h(.-)|h", "%1")
  text = string.gsub(text, "%s+", " ")
  text = string.gsub(text, "^%s+", "")
  text = string.gsub(text, "%s+$", "")
  return text
end

function BLFG:HandlePublicPlayerWhoSystemMessage(text)
  local st = self.publicPlayerWho
  if not (st and st.active and st.pendingName) then return false end
  text = BLFG_PublicWhoCleanSystemText(text)
  local name, level, desc, guild, zone = string.match(text, "^%[([^%]]+)%]:%s*[Ll]evel%s+(%d+)%s+(.+)%s+%<([^>]*)%>%s*%-%s*(.+)$")
  if not name then
    name, level, desc, zone = string.match(text, "^%[([^%]]+)%]:%s*[Ll]evel%s+(%d+)%s+(.+)%s*%-%s*(.+)$")
    guild = ""
  end
  if not name then
    name, level, desc, guild, zone = string.match(text, "^([^%]]+)%]:%s*[Ll]evel%s+(%d+)%s+(.+)%s+%<([^>]*)%>%s*%-%s*(.+)$")
  end
  if not name then
    name, level, desc, zone = string.match(text, "^([^%]]+)%]:%s*[Ll]evel%s+(%d+)%s+(.+)%s*%-%s*(.+)$")
    guild = ""
  end
  if not name then
    name, level, desc, guild, zone = string.match(text, "^([^:]+):%s*[Ll]evel%s+(%d+)%s+(.+)%s+%<([^>]*)%>%s*%-%s*(.+)$")
  end
  if not name then
    name, level, desc, zone = string.match(text, "^([^:]+):%s*[Ll]evel%s+(%d+)%s+(.+)%s*%-%s*(.+)$")
    guild = ""
  end
  name = SFWhoCleanName(name or "")
  if name == "" or string.lower(name) ~= string.lower(SFWhoCleanName(st.pendingName or "")) then return false end

  local classFile = SFWhoClassFromText(desc)
  self:RecordWhoGuildMember(name, guild or "", level or "", classFile ~= "" and classFile or desc or "", zone or "")
  st.lastCapturedWhoLine = text
  st.lastCapturedWhoAt = now()
  st.suppressWhoSummaryUntil = now() + 12
  st.lastPublicWhoRequestAt = now()
  self._publicWhoSuppressUntil = now() + 12
  st.finalResult = st.finalResult or {}
  st.finalResult[string.lower(name)] = nil
  st.active = false
  st.pendingName = nil
  st.elapsed = 0
  SFWhoRestoreUI()
  SFWhoHideDefaultUI(st)
  if self.whoDiscoveryFrame and not (self.whoDiscovery and self.whoDiscovery.active) and not (self.publicPlayerWho and self.publicPlayerWho.active) then self.whoDiscoveryFrame:Hide() end
  if self.publicPanel and self.publicPanel:IsShown() and self.RefreshPublicGroups then self:RefreshPublicGroups() end
  if GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner then
    local owner = GameTooltip:GetOwner()
    local onEnter = owner and owner.GetScript and owner:GetScript("OnEnter")
    if onEnter then GameTooltip:Hide(); onEnter(owner); GameTooltip:Show() end
  end
  return true
end

function BLFG:ShouldSuppressPublicWhoSystemMessage(text)
  local st = self.publicPlayerWho
  local cleaned = BLFG_PublicWhoCleanSystemText(text)
  local t = now()
  if string.match(cleaned, "^%d+ players? total%.?$") and self._publicWhoSuppressUntil and t < self._publicWhoSuppressUntil then
    return true
  end
  if not st then return false end
  if string.match(cleaned, "^%d+ players? total%.?$") and st.lastPublicWhoRequestAt and (t - st.lastPublicWhoRequestAt) < 15 then
    return true
  end
  if st.lastCapturedWhoLine and st.lastCapturedWhoAt and (t - st.lastCapturedWhoAt) < 3 and cleaned == st.lastCapturedWhoLine then
    return true
  end
  if string.match(cleaned, "^%d+ players? total%.?$") then
    if st.active or (st.suppressWhoTextUntil and t < st.suppressWhoTextUntil) or (st.suppressWhoSummaryUntil and t < st.suppressWhoSummaryUntil) then
      return true
    end
  end
  if st.active and st.pendingName and self.HandlePublicPlayerWhoSystemMessage and self:HandlePublicPlayerWhoSystemMessage(text) then
    return true
  end
  return false
end

function BLFG:HandleWhoListUpdate()
  local scan = self.whoDiscovery
  if not (scan and scan.active and scan.pending) then return end

  local count = GetNumWhoResults and GetNumWhoResults() or 0
  if count > 0 then
    for i = 1, count do
      local name, guild, level, race, className, zone, classFile = GetWhoInfo(i)
      self:RecordWhoGuildMember(name, guild, level, classFile or className, zone)
    end
  end

  scan.pending = false
  scan.awaitingResults = false
  scan.elapsed = 0
  scan.lastResultAt = now()
  SFWhoRestoreUI()
  SFWhoHideDefaultUI(scan)
  if scan.index > #(scan.queue or {}) then
    self:FinishWhoGuildDiscovery("complete")
    return
  end
  if self.guildPanel and self.guildPanel:IsVisible() then self:RefreshGuildBrowser() end
  if self.onlinePanel and self.onlinePanel:IsShown() then self:RefreshOnlinePanel() end
end

function BLFG:FinishWhoGuildDiscovery(reason)
  local scan = self.whoDiscovery
  if scan then scan.active = false; scan.pending = false; scan.awaitingResults = false end
  SFWhoRestoreUI()
  SFWhoHideDefaultUI(scan)
  self.guildWhoCount = self:GetWhoGuildCount()
  if scan and scan.manual and reason ~= "cancelled" then msg("/who guild discovery complete. Seen guilds: " .. tostring(self.guildWhoCount or 0)) end
  if self.guildPanel and self.guildPanel:IsVisible() then self:RefreshGuildBrowser() end
  if self.onlinePanel and self.onlinePanel:IsShown() then self:RefreshOnlinePanel() end
end

function BLFG:QueueWhoGuildDiscovery(manual)
  if self.whoDiscovery and self.whoDiscovery.active then SFWhoRestoreUI() end
  if not SFWhoEnabled() then
    if manual then msg("/who guild discovery is disabled in Options.") end
    return
  end
  if not SendWho or not SetWhoToUI then
    if manual then msg("/who discovery is not available on this client.") end
    return
  end

  self:EnsureWhoGuildDB()
  self:PruneWhoGuilds()

  local scanId = now()
  local queue = {}
  local myGuild = myGuildName()
  if myGuild and myGuild ~= "" then
    table.insert(queue, 'g-"' .. myGuild .. '"')
    table.insert(queue, "g-" .. myGuild)
  end
  if self.selectedGuildData and self.selectedGuildData.name and self.selectedGuildData.name ~= "" and self.selectedGuildData.name ~= myGuild then
    table.insert(queue, 'g-"' .. tostring(self.selectedGuildData.name) .. '"')
    table.insert(queue, "g-" .. tostring(self.selectedGuildData.name))
  end
  table.insert(queue, "")
  table.insert(queue, "1-9")
  table.insert(queue, "10-19")
  table.insert(queue, "20-29")
  table.insert(queue, "30-39")
  table.insert(queue, "40-49")
  table.insert(queue, "50-59")
  table.insert(queue, "60")
  self.whoDiscovery = {
    active = true,
    manual = manual and true or false,
    scanId = scanId,
    queue = queue,
    index = 1,
    elapsed = 8,
    pending = false,
    awaitingResults = false,
    friendsWasShown = FriendsFrame and FriendsFrame.IsShown and FriendsFrame:IsShown() and true or false,
    guildPlayers = {},
  }

  for _, rec in pairs(BronzeLFG_DB.whoGuilds or {}) do
    if rec then rec.onlineSeen = 0; rec.currentScan = nil end
  end

  if manual then msg("Starting /who guild discovery. Results will fill in over a few seconds.") end
  if self.whoDiscoveryFrame then self.whoDiscoveryFrame:Show() end
end

function BLFG:WhoDiscoveryTick(elapsed)
  local scan = self.whoDiscovery
  if not scan or not scan.active then return end
  scan.elapsed = (scan.elapsed or 0) + (elapsed or 0)

  if scan.pending then
    SFWhoHideDefaultUI(scan)
    if scan.elapsed > 12 then
      scan.pending = false
      scan.awaitingResults = false
      scan.elapsed = 0
      SFWhoRestoreUI()
      SFWhoHideDefaultUI(scan)
    end
    return
  end

  if scan.elapsed < 8 then return end
  scan.elapsed = 0

  local query = scan.queue and scan.queue[scan.index]
  if not query then
    self:FinishWhoGuildDiscovery("complete")
    return
  end

  scan.index = scan.index + 1
  scan.pending = true
  scan.awaitingResults = true
  scan.currentQuery = query
  SFWhoSetSilent()
  SendWho(query)
  SFWhoHideDefaultUI(scan)
end

function BLFG:GetWhoGuildCount()
  local db = self:EnsureWhoGuildDB()
  local count = 0
  local cutoff = now() - (14 * 24 * 60 * 60)
  for _, g in pairs(db) do
    if g and g.name and (tonumber(g.lastSeen or 0) or 0) >= cutoff then count = count + 1 end
  end
  return count
end

local function SFWhoMembersForRow(rec)
  local out = {}
  for _, m in pairs((rec and rec.members) or {}) do
    if m and (now() - (tonumber(m.seen or 0) or 0)) < 3600 then
      table.insert(out, {name=m.name, guild=rec.name, level=m.level, classFile=m.classFile, zone=m.zone, seen=m.seen})
    end
  end
  table.sort(out, function(a,b) return tostring(a.name or "") < tostring(b.name or "") end)
  return out
end

BLFG_SFWho_OldGetOnlineUserRows = BLFG.GetOnlineUserRows
function BLFG:GetOnlineUserRows(...)
  local rows = BLFG_SFWho_OldGetOnlineUserRows and BLFG_SFWho_OldGetOnlineUserRows(self, ...) or {}
  local seen = {}
  for _, u in ipairs(rows) do
    local n = SFWhoCleanName(u and u.name or "")
    if n ~= "" then seen[string.lower(n)] = true end
    if u then u.whoOnly = false end
  end

  local myGuild = myGuildName()
  self:PruneWhoGuilds()
  for _, m in pairs(self:EnsureWhoPlayerDB()) do
    local n = SFWhoCleanName(m and m.name or "")
    local low = string.lower(n)
    if n ~= "" and not seen[low] then
      table.insert(rows, {
        name = n,
        version = "/who",
        level = tostring(m.level or ""),
        classFile = normalizeClassFile(m.classFile or ""),
        role = "",
        spec = "",
        zone = tostring(m.zone or ""),
        guild = tostring(m.guild or ""),
        seen = tonumber(m.seen or now()) or now(),
        self = false,
        friend = isFriendName(n),
        groupmate = isPartyOrRaidMember(n),
        favorite = self:IsFavorite(n),
        whoOnly = true,
      })
      seen[low] = true
    end
  end

  local myZone = currentZoneText()
  table.sort(rows, function(a,b)
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
    if tostring(a.guild or "") == myGuild and tostring(b.guild or "") ~= myGuild and myGuild ~= "" then return true end
    if tostring(b.guild or "") == myGuild and tostring(a.guild or "") ~= myGuild and myGuild ~= "" then return false end
    if tostring(a.zone or "") == myZone and tostring(b.zone or "") ~= myZone and myZone ~= "" then return true end
    if tostring(b.zone or "") == myZone and tostring(a.zone or "") ~= myZone and myZone ~= "" then return false end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return rows
end

BLFG_SFWho_OldGetGuildRows = BLFG.GetGuildRows
function BLFG:GetGuildRows(...)
  local rows, a, b, c = BLFG_SFWho_OldGetGuildRows and BLFG_SFWho_OldGetGuildRows(self, ...) or {}
  rows = rows or {}
  self:PruneWhoGuilds()

  local have = {}
  local rowByKey = {}
  for _, g in ipairs(rows) do
    local key = SFWhoKey(g and (g.name or g.guild or "") or "")
    if key ~= "" then
      have[key] = true
      rowByKey[key] = g
    end
  end

  local q = lower(self.guildSearchText or (self.guildSearch and self.guildSearch:GetText()) or "")
  local whoAdded = 0
  local cutoff = now() - (14 * 24 * 60 * 60)
  for key, rec in pairs(self:EnsureWhoGuildDB()) do
    if rec and rec.name and key ~= "" and (tonumber(rec.lastSeen or 0) or 0) >= cutoff then
      local members = SFWhoMembersForRow(rec)
      local whoOnline = tonumber(rec.onlineSeen or 0) or #members
      if rowByKey[key] then
        local row = rowByKey[key]
        row.signalFireOnline = row.signalFireOnline or row.online or 0
        row.whoMembers = members
        row.whoMemberSummary = bronzeNetMemberSummary(members, 6)
        row.whoOnline = whoOnline
        row.lastWhoSeen = rec.lastSeen
        row.sourceHasWho = true
        if whoOnline > (tonumber(row.online or 0) or 0) then row.online = whoOnline end
      elseif not have[key] then
        local contact = members[1] and members[1].name or ""
        local hay = lower(tostring(rec.name or "") .. " " .. tostring(contact or ""))
        local searchOk = (q == "" or string.find(hay, q, 1, true) ~= nil)
        local focusOk = not self.guildFocusFilter or self.guildFocusFilter == "" or self.guildFocusFilter == "All"
        local fav = self:IsFavoriteGuild(rec.name)
        if searchOk and focusOk and (not self.guildFavoritesOnly or fav) then
          table.insert(rows, {
            name = rec.name,
            online = whoOnline,
            contacts = members,
            onlineMembers = members,
            whoMembers = members,
            whoMemberSummary = bronzeNetMemberSummary(members, 6),
            whoOnline = whoOnline,
            memberSummary = bronzeNetMemberSummary(members, 4),
            contact = contact,
            contactOnline = false,
            posts = 0,
            favorite = fav,
            source = "/who Discovery",
            status = "Seen via /who",
            recruiting = "N/A",
            focus = "N/A",
            lastPost = "This guild was discovered from /who results. No recruitment ad has been captured yet.",
            lastPostTime = ageText(rec.lastSeen),
            whoDiscovered = true,
            lastWhoSeen = rec.lastSeen,
          })
          have[key] = true
          whoAdded = whoAdded + 1
        end
      end
    end
  end
  self.guildWhoCount = self:GetWhoGuildCount()
  self.guildWhoShownCount = whoAdded

  local counts = {All=0, Recruiting=0, Network=0, Who=0}
  for _, row in ipairs(rows) do
    local kind = BLFG_SFGuildSourceKind and BLFG_SFGuildSourceKind(row) or "Network"
    counts.All = counts.All + 1
    counts[kind] = (counts[kind] or 0) + 1
    if kind ~= "Who" and row and ((tonumber(row.whoOnline or 0) or 0) > 0 or row.whoDiscovered) then counts.Who = counts.Who + 1 end
  end
  self.guildSourceCounts = counts

  local active = tostring(self.guildSourceFilter or "All")
  if active ~= "All" then
    local filtered = {}
    for _, row in ipairs(rows) do
      if BLFG_SFGuildMatchesSourceFilter and BLFG_SFGuildMatchesSourceFilter(row, active) then table.insert(filtered, row) end
    end
    rows = filtered
  end

  return rows, a, b, c
end

BLFG_SFWho_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g, ...)
  local r = BLFG_SFWho_OldRefreshGuildDetailPanel and BLFG_SFWho_OldRefreshGuildDetailPanel(self, g, ...)
  local d = self.guildDetailPanel
  if d and g and g.whoDiscovered then
    if d.status then d.status:SetText("Status: Seen via /who  |  Source: /who Discovery") end
    if d.recruiting then d.recruiting:SetText("Recruiting: N/A") end
    if d.members then d.members:SetText("/who Seen: " .. shortenPublicText(tostring(g.memberSummary or "None online now"), 42)) end
    if d.message then d.message:SetText("This guild was discovered from /who results. No recruitment ad has been captured yet.") end
  end
  return r
end

BLFG_SFWho_EventFrame = CreateFrame("Frame")
BLFG_SFWho_EventFrame:RegisterEvent("WHO_LIST_UPDATE")
BLFG_SFWho_EventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
BLFG_SFWho_EventFrame:RegisterEvent("PLAYER_LOGIN")
BLFG_SFWho_EventFrame:SetScript("OnEvent", function(_, event, msg)
  if event == "WHO_LIST_UPDATE" then
    if BLFG and BLFG.HandlePublicPlayerWhoUpdate and BLFG:HandlePublicPlayerWhoUpdate() then return end
    if BLFG and BLFG.HandleWhoListUpdate then BLFG:HandleWhoListUpdate() end
  elseif event == "CHAT_MSG_SYSTEM" then
    if BLFG and BLFG.HandlePublicPlayerWhoSystemMessage and BLFG:HandlePublicPlayerWhoSystemMessage(msg) then return end
  elseif event == "PLAYER_LOGIN" then
    if BLFG then
      BLFG:EnsureWhoGuildDB()
      BLFG.guildWhoCount = BLFG:GetWhoGuildCount()
      if BLFG_InstallPublicWhoChatSuppressors then BLFG_InstallPublicWhoChatSuppressors() end
    end
  end
end)

if ChatFrame_AddMessageEventFilter and not BLFG._publicWhoSystemFilterInstalled then
  BLFG._publicWhoSystemFilterInstalled = true
  ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, event, msg, ...)
    if BLFG and BLFG.ShouldSuppressPublicWhoSystemMessage and BLFG:ShouldSuppressPublicWhoSystemMessage(msg) then
      return true
    end
    return false, msg, ...
  end)
end

function BLFG_InstallPublicWhoChatSuppressors()
  BLFG._publicWhoChatSuppressorsInstalled = true
  local function install(frame)
    if not (frame and frame.AddMessage) then return end
    if frame._sfPublicWhoAddMessageWrapper and frame.AddMessage == frame._sfPublicWhoAddMessageWrapper then return end
    local oldAddMessage = frame.AddMessage
    frame._sfPublicWhoAddMessageWrapper = function(self, text, ...)
      if BLFG and BLFG.ShouldSuppressPublicWhoSystemMessage and BLFG:ShouldSuppressPublicWhoSystemMessage(text) then
        return
      end
      return oldAddMessage(self, text, ...)
    end
    frame.AddMessage = frame._sfPublicWhoAddMessageWrapper
  end
  install(DEFAULT_CHAT_FRAME)
  local n = tonumber(NUM_CHAT_WINDOWS or 0) or 0
  for i = 1, n do
    install(_G and _G["ChatFrame" .. i])
  end
end

BLFG_InstallPublicWhoChatSuppressors()

BLFG.whoDiscoveryFrame = CreateFrame("Frame")
BLFG.whoDiscoveryFrame:Hide()
BLFG.whoDiscoveryFrame:SetScript("OnUpdate", function(_, elapsed)
  if BLFG and BLFG.WhoDiscoveryTick then BLFG:WhoDiscoveryTick(elapsed) end
  if BLFG and BLFG.PublicPlayerWhoTick then BLFG:PublicPlayerWhoTick(elapsed) end
end)

BLFG_SFWho_OldSlash = SlashCmdList and SlashCmdList["BRONZELFG"]
if SlashCmdList then
  SlashCmdList["BRONZELFG"] = function(input)
    local cmd = lower(input or "")
    if cmd == "guildwho" or cmd == "whoguilds" then
      BLFG:QueueWhoGuildDiscovery(true)
      return
    elseif cmd == "clearguildwho" then
      BronzeLFG_DB.whoGuilds = {}
      BronzeLFG_DB.whoPlayers = {}
      BLFG.whoGuilds = BronzeLFG_DB.whoGuilds
      BLFG.whoPlayers = BronzeLFG_DB.whoPlayers
      BLFG.guildWhoCount = 0
      if BLFG.RefreshGuildBrowser then BLFG:RefreshGuildBrowser() end
      msg("Cleared /who discovery cache.")
      return
    end
    if BLFG_SFWho_OldSlash then return BLFG_SFWho_OldSlash(input) end
  end
end

-- ============================================================
-- SignalFire 5.7.13 - Guild Browser v2 source tags + detail tabs
-- ============================================================

function BLFG_SFGuildSourceKind(g)
  if not g then return "Network" end
  if g.whoDiscovered then return "Who" end
  if (tonumber(g.posts or 0) or 0) > 0 or tostring(g.source or "") == "Chat" or tostring(g.source or "") == "Public" or tostring(g.status or "") == "Chat Only" then
    return "Recruiting"
  end
  return "Network"
end

function BLFG_SFGuildMatchesSourceFilter(g, filter)
  filter = tostring(filter or "All")
  if filter == "All" then return true end
  if filter == "Who" then return g and ((tonumber(g.whoOnline or 0) or 0) > 0 or g.whoDiscovered) end
  return BLFG_SFGuildSourceKind(g) == filter
end

function BLFG_SFGuildSourceTag(g)
  local kind = BLFG_SFGuildSourceKind(g)
  if kind == "Recruiting" then return "|cffffd35a[Recruit]|r" end
  if kind == "Who" then return "|cffaaaaaa[/who]|r" end
  return "|cff67c1ff[Network]|r"
end

function BLFG_SFGuildSourceLong(g)
  local kind = BLFG_SFGuildSourceKind(g)
  if kind == "Recruiting" then
    local sfOnline = tonumber(g and g.signalFireOnline or 0) or 0
    local whoOnline = tonumber(g and g.whoOnline or 0) or 0
    if whoOnline > 0 and sfOnline > 0 then return "Recruitment Ad + Network + /who" end
    if sfOnline > 0 then return "Recruitment Ad + SignalFire Network" end
    if whoOnline > 0 then return "Recruitment Ad + /who" end
    return "Recruitment Ad"
  end
  if kind == "Who" then return "/who Discovery" end
  if g and (tonumber(g.whoOnline or 0) or 0) > 0 then return "SignalFire Network + /who" end
  return "SignalFire Network"
end

function BLFG:UpdateGuildDetailTabs(g)
  local d = self.guildDetailPanel
  if not d then return end
  local tab = self.guildDetailTab or "Overview"
  if d.tabOverview and d.tabOverview.UnlockHighlight then d.tabOverview:UnlockHighlight() end
  if d.tabRecruitment and d.tabRecruitment.UnlockHighlight then d.tabRecruitment:UnlockHighlight() end
  if d.tabSeen and d.tabSeen.UnlockHighlight then d.tabSeen:UnlockHighlight() end
  if tab == "Recruitment" and d.tabRecruitment and d.tabRecruitment.LockHighlight then d.tabRecruitment:LockHighlight()
  elseif tab == "Seen" and d.tabSeen and d.tabSeen.LockHighlight then d.tabSeen:LockHighlight()
  elseif d.tabOverview and d.tabOverview.LockHighlight then d.tabOverview:LockHighlight() end

  if not g then
    if d.recentTitle then d.recentTitle:SetText("Recent Recruitment Message") end
    if d.message then d.message:SetText("Select a guild to view details.") end
    return
  end

  if tab == "Seen" then
    if d.recentTitle then d.recentTitle:SetText("Recently Seen Players") end
    local members = g.whoMembers or g.onlineMembers or g.contacts or {}
    local lines = {}
    for i, u in ipairs(members) do
      if i > 6 then break end
      table.insert(lines, tostring(u.name or "Unknown") .. "  " .. tostring(u.level or "") .. "  " .. tostring(u.className or u.class or u.classFile or "") .. "  " .. tostring(u.zone or ""))
    end
    if #lines == 0 then table.insert(lines, "No players seen yet.") end
    if d.message then d.message:SetText(table.concat(lines, "\n")) end
  elseif tab == "Recruitment" then
    if d.recentTitle then d.recentTitle:SetText("Recent Recruitment Message") end
    local post = tostring(g.lastPost or "")
    if post == "" or g.whoDiscovered then post = "No recruitment ad has been captured yet." end
    if d.message then d.message:SetText(shortenPublicText(post, 260)) end
  else
    if d.recentTitle then d.recentTitle:SetText("Overview") end
    local source = BLFG_SFGuildSourceLong(g)
    local seen = g.lastPostTime or (g.lastWhoSeen and ageText(g.lastWhoSeen)) or "--"
    local sfOnline = tonumber(g.signalFireOnline or g.online or 0) or 0
    local whoOnline = tonumber(g.whoOnline or 0) or 0
    local lines = {
      "Source: " .. source,
      "SignalFire Network: " .. tostring(sfOnline),
      "/who Seen: " .. tostring(whoOnline),
      "Last Seen: " .. tostring(seen),
    }
    if d.message then d.message:SetText(table.concat(lines, "\n")) end
  end
end

function BLFG:SetGuildDetailTab(tab)
  self.guildDetailTab = tab or "Overview"
  local g = self.selectedGuildData or self.guildDetailGuild
  if self.RefreshGuildDetailPanel then self:RefreshGuildDetailPanel(g) end
end

BLFG_SFGuildV2_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g, ...)
  local r = BLFG_SFGuildV2_OldRefreshGuildDetailPanel and BLFG_SFGuildV2_OldRefreshGuildDetailPanel(self, g, ...)
  local d = self.guildDetailPanel
  if d and g then
    d.guildData = g
    if d.status then d.status:SetText("Status: " .. tostring(g.status or "--")) end
    if d.online and (tonumber(g.whoOnline or 0) or 0) > 0 then d.online:SetText("Online Seen: " .. tostring(g.online or 0) .. "  |  Posts: " .. tostring(g.posts or 0)) end
    if d.members then d.members:SetText("Source: " .. BLFG_SFGuildSourceLong(g)) end
    self:UpdateGuildDetailTabs(g)
  elseif d then
    self:UpdateGuildDetailTabs(nil)
  end
  return r
end

-- ============================================================
-- SignalFire 5.7.13 - Parser parity, Invasion Assist phase 1,
-- and unified listing/public-applicant bridge.
-- ============================================================

local function SF573_Low(text) return string.lower(tostring(text or "")) end
local function SF573_HasAny(text, tokens)
  local s = SF573_Low(text)
  for _, token in ipairs(tokens or {}) do if string.find(s, token, 1, true) then return true end end
  return false
end
local function SF573_AddTag(tags, tag)
  if not tag or tag == "" then return end
  for _, t in ipairs(tags) do if t == tag then return end end
  table.insert(tags, tag)
end
local function SF573_RoleText(role)
  if roleText then return roleText(role) end
  return tostring(role or "")
end

local function SF573_ApplyTriumvirateParser(g)
  if not g then return end
  local msgText = tostring(g.message or g.rawMessage or "")
  if msgText == "" then return end
  local s = " " .. SF573_Low(cleanPublicChatText(msgText)) .. " "
  local roles, tags = {}, {}
  local function addRole(r) table.insert(roles, SF573_RoleText(r)) end
  if string.find(s, "tank", 1, true) or string.find(s, "prot", 1, true) then addRole("Tank") end
  if string.find(s, "heal", 1, true) or string.find(s, "healer", 1, true) or string.find(s, "heals", 1, true) or string.find(s, "resto", 1, true) then addRole("Healer") end
  if string.find(s, "dps", 1, true) or string.find(s, "damage", 1, true) then addRole("DPS") end

  local recruiter = (isPublicRecruiterIntent and isPublicRecruiterIntent(s)) or false
  local applicant = (BLFG_570b1c_IsPlayerLFG and BLFG_570b1c_IsPlayerLFG(msgText)) or false
  local profileActivity = SFProfileMatchActivity and SFProfileMatchActivity(msgText) or nil
  local raidActivity = BLFG_5713_RaidActivity and BLFG_5713_RaidActivity(msgText) or nil
  local hasRDF = string.find(s, " rdf ", 1, true) or string.find(s, " random dungeon", 1, true) or string.find(s, " random ", 1, true) or string.find(s, " queue ", 1, true)
  local hasTBC = SF573_HasAny(s, {" tbc ", " bc ", " outland"})
  local hasWrath = SF573_HasAny(s, {" wotlk ", " wrath ", " northrend"})
  local hasHeroic = SF573_HasAny(s, {" heroic", " hc ", " h "})
  local hasQuest = SF573_HasAny(s, {" quest", " quests", " group quest", " ic group"})
  local hasKey = SF573_HasAny(s, {" key ", " keys ", " keystone", " mythic+", " m+ "})
  local hasRingOfBlood = string.find(s, " ring of blood ", 1, true) or string.find(s, " ring blood ", 1, true)
  local hasZulDrakArena = (string.find(s, " zuldrak ", 1, true) or string.find(s, " zul'drak ", 1, true) or string.find(s, " zul drak ", 1, true)) and string.find(s, " arena ", 1, true)
  local keyActivity = nil
  local seasonKeys = SFProfileList and SFProfileList("keys", {}) or {}
  for _, keyName in ipairs(seasonKeys or {}) do
    if profileActivity == keyName then keyActivity = keyName end
  end

  if hasHeroic then SF573_AddTag(tags, "Heroic") end
  if hasRDF then SF573_AddTag(tags, "RDF") end
  if hasTBC then SF573_AddTag(tags, "TBC") end
  if hasWrath then SF573_AddTag(tags, "Wrath") end
  if hasQuest then SF573_AddTag(tags, "Quest Group") end
  if hasKey then SF573_AddTag(tags, "Keystone") end
  if hasRingOfBlood then SF573_AddTag(tags, "Quest Group"); SF573_AddTag(tags, "Event") end
  if hasZulDrakArena then SF573_AddTag(tags, "Quest Group"); SF573_AddTag(tags, "Event") end
  if string.find(s, " tank +", 1, true) or string.find(s, " healer +", 1, true) or string.find(s, " heals +", 1, true) or string.find(s, " tank and ", 1, true) or string.find(s, " healer and ", 1, true) or string.find(s, " tank/heal", 1, true) then
    recruiter = true
    applicant = false
  end

  if BLFG_SF573_IsLookingForGuildPost(msgText) then
    g.type, g.activity, g.intent = "Social", "Looking For Guild", "Applicant"
    SF573_AddTag(tags, "Guild")
  elseif hasRingOfBlood then
    g.type, g.activity, g.intent = "Event", "Ring of Blood", "Recruiter"
  elseif hasZulDrakArena then
    g.type, g.activity, g.intent = "Event", "Zul'Drak Arena Quest", "Recruiter"
  elseif hasQuest and string.find(s, " ic ", 1, true) then
    g.type, g.activity, g.intent = "Event", "Icecrown Group Quests", "Recruiter"
  elseif hasRDF or (hasHeroic and (hasTBC or hasWrath)) then
    g.type = applicant and not recruiter and "LFG" or "Dungeon"
    if hasTBC then g.activity = "BC Random Dungeon Finder"
    elseif hasWrath then g.activity = "Wrath Random Dungeon Finder"
    else g.activity = "Random Dungeon Finder" end
    g.intent = applicant and not recruiter and "Applicant" or "Recruiter"
  elseif hasKey and keyActivity then
    g.type, g.activity = "Key", keyActivity
    g.intent = recruiter and "Recruiter" or (applicant and "Applicant" or "Recruiter")
  elseif raidActivity and recruiter and not applicant then
    g.type, g.activity, g.intent = "Raid", raidActivity, "Recruiter"
    SF573_AddTag(tags, "Raid")
  elseif profileActivity and recruiter then
    g.type, g.activity, g.intent = "Dungeon", profileActivity, "Recruiter"
  end
  if #roles > 0 then g.roles = table.concat(roles, "  ") end
  if #tags > 0 then g.tags = table.concat(tags, " | ") end
  if not g.score or tonumber(g.score or 0) < 50 then g.score = 75 end
end

BLFG_SF573_OldParserFix = BLFG_570b1c_ApplyPublicParserFix
function BLFG_570b1c_ApplyPublicParserFix(g)
  if g and g.isInvasionBeacon then
    g.type = "Event"
    g.activity = tostring(g.invasionName or g.activity or "Invasion")
    if not string.find(g.activity, "Invasion", 1, true) then g.activity = g.activity .. " Invasion" end
    g.intent = "Recruiter"
    g.roles = g.roles or "T/H/D"
    g.tags = "Invasion,Event"
    g.score = 100
    return
  end
  if BLFG_SF573_OldParserFix then BLFG_SF573_OldParserFix(g) end
  SF573_ApplyTriumvirateParser(g)
end

SLASH_SIGNALFIREPARSE1 = "/sfparse"
SlashCmdList["SIGNALFIREPARSE"] = function(text)
  text = tostring(text or "")
  if text == "" then DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire parse:|r Usage: /sfparse LFM Halls of Lightning need heals"); return end
  local activity = guessPublicActivity(text)
  local intent = guessPublicIntent(text)
  local g = {id="sfparse", player=playerName(), message=text, type=classifyPublicType(text, activity, intent), activity=activity, intent=intent, roles=guessPublicRoles(text, intent), tags=guessPublicTags(text, activity, "Other")}
  if BLFG_570b1c_ApplyPublicParserFix then BLFG_570b1c_ApplyPublicParserFix(g) end
  DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire parse:|r Type=" .. tostring(g.type) .. " | Activity=" .. tostring(g.activity) .. " | Intent=" .. tostring(g.intent) .. " | Roles=" .. tostring(g.roles) .. " | Tags=" .. tostring(g.tags))
end

local function SF573_RolesNeededShort(l)
  local out = {}
  if l.needTank == "1" then table.insert(out, "T") end
  if l.needHealer == "1" then table.insert(out, "H") end
  if l.needDPS == "1" then table.insert(out, "D") end
  return #out > 0 and (" - Need " .. table.concat(out, "/")) or ""
end

function BLFG:ListingRecruitmentText(l)
  l = l or self.myListing
  if not l then return "" end
  return "LFM " .. tostring(l.activity or "Group") .. SF573_RolesNeededShort(l)
end

function BLFG:MirrorListingToPublic(l)
  if not l or not l.id then return nil end
  self.publicGroups = self.publicGroups or {}
  local id = "listing-" .. tostring(l.id)
  local row = self.publicGroups[id] or {}
  row.id, row.listingId, row.player = id, l.id, l.leader or playerName()
  row.message, row.channel = self:ListingRecruitmentText(l), "SignalFire Listing"
  row.type, row.activity, row.roles = l.type or "Dungeon", l.activity or "General Listing", rolesNeeded and rolesNeeded(l) or ""
  row.intent, row.tags, row.ilevel, row.score = "Recruiter", l.difficulty or "", l.minItemLevel or "", 100
  row.created, row.seen = row.created or (l.created or now()), now()
  row.signalFireListing = true
  self.publicGroups[id] = row
  if self.publicPanel and self.publicPanel:IsShown() then
    self.publicFilter = "All"
    self.publicRoleFilter = "All"
    self.publicSearchText = ""
    if self.publicSearch and self.publicSearch.SetText then self.publicSearch:SetText("") end
  end
  if BLFG_570b1c_ApplyPublicParserFix then BLFG_570b1c_ApplyPublicParserFix(row) end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  return row
end

BLFG_SF573_OldCreateListing = BLFG.CreateListing
function BLFG:CreateListing(...)
  local before = self.myListing and self.myListing.id
  local r = BLFG_SF573_OldCreateListing and BLFG_SF573_OldCreateListing(self, ...)
  if self.myListing and self.myListing.id ~= before then self:MirrorListingToPublic(self.myListing) end
  return r
end

BLFG_SF573_OldBroadcast = BLFG.Broadcast
function BLFG:Broadcast(...)
  local r = BLFG_SF573_OldBroadcast and BLFG_SF573_OldBroadcast(self, ...)
  if self.myListing then self:MirrorListingToPublic(self.myListing) end
  return r
end

function BLFG:PostMyListingToChat()
  local l = self.myListing
  if not l then msg("No active listing to post."); return end
  local row = self:MirrorListingToPublic(l)
  local text = self:ListingRecruitmentText(l)
  local channelId = GetChannelName and GetChannelName("global") or nil
  if channelId and channelId ~= 0 and SendChatMessage then
    SendChatMessage(text, "CHANNEL", nil, channelId)
    flash("Posted listing to global chat.")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire listing:|r " .. text .. " " .. (row and self:PublicChatLink(row) or ""))
    flash("Could not find global channel; posted locally.")
  end
end

function BLFG:RebroadcastMyListing()
  if not self.myListing then msg("No active listing to rebroadcast."); return end
  self:Broadcast()
  flash("Listing rebroadcast.")
end

BLFG_SF573_OldBuildMyListing = BLFG.BuildMyListing
function BLFG:BuildMyListing(...)
  local r = BLFG_SF573_OldBuildMyListing and BLFG_SF573_OldBuildMyListing(self, ...)
  if self.myPanel and not self.myPostToChat then
    local box = self.myBody and self.myBody:GetParent()
    if box then
      self.myPostToChat = button(box, "Post to Chat", 120, 30)
      self.myPostToChat:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 18, 18)
      self.myPostToChat:SetScript("OnClick", function() BLFG:PostMyListingToChat() end)
      self.myRebroadcast = button(box, "Rebroadcast", 120, 30)
      self.myRebroadcast:SetPoint("LEFT", self.myPostToChat, "RIGHT", 10, 0)
      self.myRebroadcast:SetScript("OnClick", function() BLFG:RebroadcastMyListing() end)
    end
  end
  return r
end

BLFG_SF573_OldWhisperPublicSelected = BLFG.WhisperPublicSelected
function BLFG:WhisperPublicSelected()
  local g = self.publicGroups and self.publicGroups[self.selectedPublic]
  if g and g.listingId and self.myListing and g.listingId == self.myListing.id then
    local c, cf = playerClass()
    local pr = BronzeLFG_DB.profile or {}
    self.applicants[playerName()] = {listingId=g.listingId, name=playerName(), class=c, classFile=cf, level=playerLevel(), role=pr.role or "DPS", itemLevel=pr.itemLevel or "", roleType=pr.roleType or "", discord=pr.discord and "Yes" or "No", note=pr.note or "", applied=now(), source="Public Groups"}
    if self.RefreshApplicants then self:RefreshApplicants() end
    flash("Added your Public Groups application to Applicants.")
    return
  end
  return BLFG_SF573_OldWhisperPublicSelected and BLFG_SF573_OldWhisperPublicSelected(self)
end

local SF573_INVASION_HUBS = {["goldshire"] = true}
local function SF573_CurrentInvasionHub()
  local zone = GetRealZoneText and GetRealZoneText() or ""
  local subzone = GetSubZoneText and GetSubZoneText() or ""
  local key = SF573_Low(subzone ~= "" and subzone or zone)
  if SF573_INVASION_HUBS[key] then return subzone ~= "" and subzone or zone, zone, subzone end
  return nil, zone, subzone
end

function BLFG:SendInvasionPresence()
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if BronzeLFG_DB.options.invasionAssist == false then return end
  local hub, zone, subzone = SF573_CurrentInvasionHub()
  if not hub then return end
  local solo = ((GetNumPartyMembers and GetNumPartyMembers() or 0) == 0 and (GetNumRaidMembers and GetNumRaidMembers() or 0) == 0) and "1" or "0"
  sendChan(table.concat({PREFIX, "INVASION", clean(playerName()), clean(hub), clean(zone), clean(subzone), clean(solo), clean(now())}, "~"))
end

function BLFG:HandleInvasionPresence(p)
  local name = p[3]
  if not name or name == "" or name == playerName() then return end
  self.invasionUsers = self.invasionUsers or {}
  self.invasionUsers[name] = {name=name, hub=p[4] or "", zone=p[5] or "", subzone=p[6] or "", solo=p[7] == "1", seen=tonumber(p[8]) or now()}
  if self.invasionPanel and self.invasionPanel:IsShown() then self:RefreshInvasions() end
end

BLFG_SF573_OldHandleMessage = BLFG.HandleMessage
function BLFG:HandleMessage(text)
  if text and string.sub(text,1,string.len(PREFIX)) == PREFIX then
    local p = split(text)
    if p[1] == PREFIX and p[2] == "INVASION" then self:HandleInvasionPresence(p); return end
  end
  return BLFG_SF573_OldHandleMessage and BLFG_SF573_OldHandleMessage(self, text)
end

function BLFG:BuildInvasions()
  if self.invasionPanel then return end
  local p = CreateFrame("Frame", nil, self.content)
  self.invasionPanel = p
  p:SetAllPoints()
  p:Hide()
  font(p, "Invasion Assist", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  local box = CreateFrame("Frame", nil, p)
  box:SetWidth(820); box:SetHeight(470)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -40)
  backdrop(box, .96)
  self.invasionStatus = font(box, "", 12, 1, 1, 1)
  self.invasionStatus:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -20)
  self.invasionStatus:SetWidth(760); self.invasionStatus:SetJustifyH("LEFT")
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  self.optInvasionAssist = CreateFrame("CheckButton", "BLFGOptInvasionAssist", box, "UICheckButtonTemplate")
  self.optInvasionAssist:SetPoint("TOPLEFT", box, "TOPLEFT", 18, -52)
  _G[self.optInvasionAssist:GetName().."Text"]:SetText("")
  self.optInvasionAssist:SetChecked(BronzeLFG_DB.options.invasionAssist ~= false)
  self.optInvasionAssist:SetScript("OnClick", function() BLFG:SaveOptions(false) end)
  font(box, "Enable Invasion Assist", 11, 1, 1, 1):SetPoint("LEFT", self.optInvasionAssist, "RIGHT", 4, 1)
  self.optInvasionInvites = CreateFrame("CheckButton", "BLFGOptInvasionInvites", box, "UICheckButtonTemplate")
  self.optInvasionInvites:SetPoint("TOPLEFT", box, "TOPLEFT", 230, -52)
  _G[self.optInvasionInvites:GetName().."Text"]:SetText("")
  self.optInvasionInvites:SetChecked(BronzeLFG_DB.options.invasionAllowInvites == true)
  self.optInvasionInvites:SetScript("OnClick", function() BLFG:SaveOptions(false) end)
  font(box, "Allow invasion invites", 11, 1, 1, 1):SetPoint("LEFT", self.optInvasionInvites, "RIGHT", 4, 1)
  font(box, "Auto-accept: Off", 10, .8, .8, .8):SetPoint("TOPLEFT", box, "TOPLEFT", 450, -57)
  self.invasionRows = {}
  for i=1,8 do local rr = font(box, "", 11, .75, .9, 1); rr:SetPoint("TOPLEFT", box, "TOPLEFT", 22, -100 - ((i-1)*28)); rr:SetWidth(760); rr:SetJustifyH("LEFT"); self.invasionRows[i] = rr end
  local create = button(box, "Create Invasion Group", 165, 28); create:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 18, 18); create:SetScript("OnClick", function() flash("Invasion group helper ready. Phase 1 is manual.") end)
  local invite = button(box, "Invite Nearby Solo Players", 185, 28); invite:SetPoint("LEFT", create, "RIGHT", 10, 0); invite:SetScript("OnClick", function() BLFG:InviteNearbyInvasionPlayers() end)
  local raid = button(box, "Convert to Raid", 130, 28); raid:SetPoint("LEFT", invite, "RIGHT", 10, 0); raid:SetScript("OnClick", function() if ConvertToRaid then ConvertToRaid() else msg("Convert to Raid is unavailable.") end end)
end

function BLFG:RefreshInvasions()
  if not self.invasionPanel then return end
  local hub, zone, subzone = SF573_CurrentInvasionHub()
  self.invasionStatus:SetText("Known hubs: Goldshire\nCurrent: " .. tostring(subzone ~= "" and subzone or zone) .. (hub and " | In invasion hub" or " | Not in known invasion hub"))
  local rows, cutoff = {}, now() - 180
  for _, u in pairs(self.invasionUsers or {}) do if u.seen and u.seen >= cutoff and (not hub or u.hub == hub) then table.insert(rows, u) end end
  table.sort(rows, function(a,b) return tostring(a.name) < tostring(b.name) end)
  for i, line in ipairs(self.invasionRows or {}) do local u = rows[i]; if u then line:SetText(tostring(u.name) .. " - " .. tostring(u.hub) .. " - " .. (u.solo and "Solo" or "Grouped") .. " - seen " .. ageText(u.seen)) else line:SetText("") end end
end

function BLFG:ShowInvasions()
  self:CreateUI(); self:HidePanels(); self:BuildInvasions(); self.invasionPanel:Show(); self.frame:Show(); self.currentTab = "Invasions"; self:SendInvasionPresence(); self:RefreshInvasions()
end

function BLFG:InviteNearbyInvasionPlayers()
  local hub = SF573_CurrentInvasionHub()
  if not hub then msg("Move to a known invasion hub first."); return end
  local n = 0
  for name, u in pairs(self.invasionUsers or {}) do if u.hub == hub and u.solo and InviteUnit then InviteUnit(name); n = n + 1 end end
  flash("Sent invasion invites: " .. tostring(n))
end

BLFG_SF573_OldBuildSide = BLFG.BuildSide
function BLFG:BuildSide(...)
  local r = BLFG_SF573_OldBuildSide and BLFG_SF573_OldBuildSide(self, ...)
  return r
end

BLFG_SF573_OldCreateUI = BLFG.CreateUI
function BLFG:CreateUI(...)
  local r = BLFG_SF573_OldCreateUI and BLFG_SF573_OldCreateUI(self, ...)
  self:BuildInvasions()
  return r
end

BLFG_SF573_OldBuildOptions = BLFG.BuildOptions
function BLFG:BuildOptions(...)
  local r = BLFG_SF573_OldBuildOptions and BLFG_SF573_OldBuildOptions(self, ...)
  return r
end

BLFG_SF573_OldHidePanels = BLFG.HidePanels
function BLFG:HidePanels(...)
  local r = BLFG_SF573_OldHidePanels and BLFG_SF573_OldHidePanels(self, ...)
  if self.invasionPanel then self.invasionPanel:Hide() end
  if self.invasionPlayerPanel then self.invasionPlayerPanel:Hide() end
  return r
end

BLFG_SF573_OldSaveOptions = BLFG.SaveOptions
function BLFG:SaveOptions(showFlash)
  local r = BLFG_SF573_OldSaveOptions and BLFG_SF573_OldSaveOptions(self, showFlash)
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if self.optInvasionAssist then BronzeLFG_DB.options.invasionAssist = self.optInvasionAssist:GetChecked() and true or false end
  if self.optInvasionInvites then BronzeLFG_DB.options.invasionAllowInvites = self.optInvasionInvites:GetChecked() and true or false end
  BronzeLFG_DB.options.invasionAutoAccept = false
  return r
end

BLFG_SF573_OldIsAddonSpam = BronzeLFG_IsAddonSpam
function BronzeLFG_IsAddonSpam(text)
  if string.find(tostring(text or ""), "~INVASION~", 1, true) then return true end
  if BLFG_SF573_OldIsAddonSpam then return BLFG_SF573_OldIsAddonSpam(text) end
  return false
end

local function SF573_GuildRecruitmentLabelName(text)
  local raw = tostring(text or "")
  local n = string.match(raw, "[Gg]uild%s+[Rr]ecruitment%s*[%+:%-%|]%s*(.-)%s+[Rr]ecru")
  if not n or n == "" then return nil end
  n = cleanPublicChatText(n)
  n = string.gsub(n, "^%s+", "")
  n = string.gsub(n, "%s+$", "")
  if n == "" then return nil end
  local low = SF573_Low(n)
  if low == "guild" or low == "guild recruitment" or low == "recruitment" then return nil end
  if string.len(n) < 3 or string.len(n) > 32 then return nil end
  return n
end

BLFG_SF573_OldExtractGuildNameFromPost = extractGuildNameFromPost
function extractGuildNameFromPost(g)
  local n = SF573_GuildRecruitmentLabelName(g and g.message)
  if n then return n end
  if BLFG_SF573_OldExtractGuildNameFromPost then return BLFG_SF573_OldExtractGuildNameFromPost(g) end
  return nil
end

BLFG_SF573_OldGuildNameFromAd = BLFG_5611_GuildNameFromAd or BLFG_569_GuildNameFromAd or BLFG_568_GuildNameFromAd
function BLFG_5611_GuildNameFromAd(text)
  local n = SF573_GuildRecruitmentLabelName(text)
  if n then return n end
  if BLFG_SF573_OldGuildNameFromAd then return BLFG_SF573_OldGuildNameFromAd(text) end
  return ""
end
BLFG_565_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_567_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_568_GuildNameFromAd = BLFG_5611_GuildNameFromAd
BLFG_569_GuildNameFromAd = BLFG_5611_GuildNameFromAd

function BLFG_SF573_IsLookingForGuildPost(text)
  local s = " " .. SF573_Low(cleanPublicChatText(text or "")) .. " "
  if string.find(s, " lf guild ", 1, true) or string.find(s, " lfguild ", 1, true) or string.find(s, " looking for guild ", 1, true) then return true end
  if string.find(s, " lf social guild ", 1, true) or string.find(s, " lf casual guild ", 1, true) or string.find(s, " looking for social guild ", 1, true) then return true end
  if string.find(s, " need a guild ", 1, true) or string.find(s, " looking for a guild ", 1, true) then return true end
  return false
end

BLFG_SF573_OldActiveIsGuildAd = BLFG_570b1b_IsGuildAd or BLFG_IsLikelyGuildRecruitmentAd_563
function BLFG_SF573_IsGuildAd(text)
  if BLFG_SF573_IsLookingForGuildPost(text) then return false end
  return BLFG_SF573_OldActiveIsGuildAd and BLFG_SF573_OldActiveIsGuildAd(text) or false
end
BLFG_570b1b_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_5628_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_5618_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_5617_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_5616_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_5612_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_569_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_567_IsGuildAd = BLFG_SF573_IsGuildAd
BLFG_565_IsGuildRecruitmentAd = BLFG_SF573_IsGuildAd
BLFG_IsLikelyGuildRecruitmentAd_563 = BLFG_SF573_IsGuildAd

BLFG_SF573_OldSlash = SlashCmdList and SlashCmdList["BRONZELFG"]
if SlashCmdList then
  SlashCmdList["BRONZELFG"] = function(input)
    local cmd = SF573_Low(input)
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "invasion" or cmd == "invasions" then
      BLFG:Show()
      BLFG:ShowInvasions()
      return
    end
    if BLFG_SF573_OldSlash then return BLFG_SF573_OldSlash(input) end
  end
end

BLFG_SF573_InvasionFrame = CreateFrame("Frame")
BLFG_SF573_InvasionFrame.elapsed = 0
BLFG_SF573_InvasionFrame:SetScript("OnUpdate", function(self, elapsed)
  self.elapsed = (self.elapsed or 0) + (elapsed or 0)
  if self.elapsed < 20 then return end
  self.elapsed = 0
  if BLFG and BLFG.SendInvasionPresence then BLFG:SendInvasionPresence() end
  if BLFG and BLFG.invasionPanel and BLFG.invasionPanel:IsShown() then BLFG:RefreshInvasions() end
end)

-- ============================================================
-- SignalFire 5.7.13 - Guild/Network UI cleanup
-- ============================================================

local function SF574_IsSignalFireUser(u)
  return u and not u.whoOnly
end

local function SF574_GuildSignalFireOnline(g)
  local n = 0
  local members = (g and (g.onlineMembers or g.contacts or g.whoMembers)) or {}
  local memberCount = 0
  for _, u in ipairs(members) do
    memberCount = memberCount + 1
    if SF574_IsSignalFireUser(u) then n = n + 1 end
  end
  if n > 0 then return n end
  if memberCount > 0 then return 0 end
  if g and g.signalFireOnline and (tonumber(g.signalFireOnline) or 0) > 0 then return tonumber(g.signalFireOnline) or 0 end
  return 0
end

local function SF574_GuildHasRecruitment(g)
  if not g then return false end
  if (tonumber(g.posts or 0) or 0) > 0 then return true end
  local src = tostring(g.source or "")
  local status = tostring(g.status or "")
  if src == "Chat" or src == "Public" or src == "Recruitment Ad" or status == "Chat Only" then return true end
  local msg = tostring(g.lastPost or g.message or g.rawMessage or g.post or "")
  if msg ~= "" and BLFG_570b1b_IsGuildAd and BLFG_570b1b_IsGuildAd(msg) then return true end
  return false
end

function BLFG_SFGuildSourceKind(g)
  if not g then return "Who" end
  if SF574_GuildHasRecruitment(g) then return "Recruiting" end
  if SF574_GuildSignalFireOnline(g) > 0 then return "Network" end
  return "Who"
end

function BLFG_SFGuildMatchesSourceFilter(g, filter)
  filter = tostring(filter or "All")
  if filter == "All" then return true end
  if filter == "Who" then return g and ((tonumber(g.whoOnline or 0) or 0) > 0 or g.whoDiscovered or BLFG_SFGuildSourceKind(g) == "Who") end
  if filter == "Network" then return (not SF574_GuildHasRecruitment(g)) and SF574_GuildSignalFireOnline(g) > 0 end
  return BLFG_SFGuildSourceKind(g) == filter
end

function BLFG_SFGuildSourceTag(g)
  local kind = BLFG_SFGuildSourceKind(g)
  if kind == "Recruiting" then return "|cffffd35a[Recruit]|r" end
  if kind == "Network" then return "|cff67c1ff[Network]|r" end
  return "|cffaaaaaa[Online]|r"
end

function BLFG_SFGuildSourceLong(g)
  local kind = BLFG_SFGuildSourceKind(g)
  if kind == "Recruiting" then
    local sfOnline = SF574_GuildSignalFireOnline(g)
    local whoOnline = tonumber(g and g.whoOnline or 0) or 0
    if whoOnline > 0 and sfOnline > 0 then return "Recruitment Ad + SignalFire Network + Online" end
    if sfOnline > 0 then return "Recruitment Ad + SignalFire Network" end
    if whoOnline > 0 then return "Recruitment Ad + Online" end
    return "Recruitment Ad"
  end
  if kind == "Network" then return "SignalFire Network" end
  return "Online"
end

local function SF574_OnlineDisplayName(u)
  local name = tostring(u and u.name or "Unknown")
  if string.len(name) > 14 then name = string.sub(name, 1, 11) .. "..." end
  return classColor(u and u.classFile or "") .. name .. "|r"
end

local function SF574_FindMainBox(panel)
  if not panel or not panel.GetChildren then return nil end
  for _, child in ipairs({panel:GetChildren()}) do
    if child and child.GetWidth and child.GetHeight and child:GetWidth() >= 500 and child:GetHeight() >= 350 then return child end
  end
  return nil
end

function BLFG:ApplySignalFireBetaTitle()
  if BronzeLFG_ApplyVisibleVersion then
    BronzeLFG_ApplyVisibleVersion()
    return
  end
  if self.titleText then self.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or "SignalFire (Beta)") end
  if self.versionText then
    self.versionText:SetText("")
    if self.versionText.SetAlpha then self.versionText:SetAlpha(0) end
    if self.versionText.Hide then self.versionText:Hide() end
  end
end

BLFG_SF574_OldGetOnlineUserRows = BLFG.GetOnlineUserRows
function BLFG:GetOnlineUserRows(...)
  local rows = BLFG_SF574_OldGetOnlineUserRows and BLFG_SF574_OldGetOnlineUserRows(self, ...) or {}
  table.sort(rows, function(a,b)
    local asf = SF574_IsSignalFireUser(a)
    local bsf = SF574_IsSignalFireUser(b)
    if asf and not bsf then return true end
    if bsf and not asf then return false end
    if a.self and not b.self then return true end
    if b.self and not a.self then return false end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return rows
end

BLFG_SF574_OldCreateUI = BLFG.CreateUI
function BLFG:CreateUI(...)
  local r = BLFG_SF574_OldCreateUI and BLFG_SF574_OldCreateUI(self, ...)
  self:ApplySignalFireBetaTitle()
  return r
end

BLFG_SF574_OldBuildGuildBrowser = BLFG.BuildGuildBrowser
function BLFG:BuildGuildBrowser(...)
  local r = BLFG_SF574_OldBuildGuildBrowser and BLFG_SF574_OldBuildGuildBrowser(self, ...)
  if self.guildSourceFilterButtons then
    if self.guildSourceFilterButtons.Who then self.guildSourceFilterButtons.Who:SetText("Online") end
  end
  if self.guildOpenOnlineButton then
    self.guildOpenOnlineButton:SetText("SignalFire Network")
    self.guildOpenOnlineButton:SetWidth(150)
  end
  if self.guildRecruitCreatorBtn then
    self.guildRecruitCreatorBtn:SetWidth(170)
    self.guildRecruitCreatorBtn:ClearAllPoints()
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", self.guildList, "BOTTOM", 0, 12)
  end
  if self.guildClearListingsBtn then
    self.guildClearListingsBtn:SetWidth(120)
    self.guildClearListingsBtn:ClearAllPoints()
    self.guildClearListingsBtn:SetPoint("RIGHT", self.guildRecruitCreatorBtn, "LEFT", -18, 0)
  end
  if self.guildOpenOnlineButton then
    self.guildOpenOnlineButton:ClearAllPoints()
    self.guildOpenOnlineButton:SetPoint("LEFT", self.guildRecruitCreatorBtn, "RIGHT", 18, 0)
  end
  self:ApplySignalFireBetaTitle()
  return r
end

BLFG_SF574_OldRefreshGuildBrowser = BLFG.RefreshGuildBrowser
function BLFG:RefreshGuildBrowser(...)
  local r = BLFG_SF574_OldRefreshGuildBrowser and BLFG_SF574_OldRefreshGuildBrowser(self, ...)
  self:ApplySignalFireBetaTitle()
  local rows = self.GetGuildRows and self:GetGuildRows() or {}
  local allRows = rows or {}
  local counts = {All=0, Recruiting=0, Network=0, Who=0}
  local oldFilter = self.guildSourceFilter
  if oldFilter ~= "All" then
    self.guildSourceFilter = "All"
    allRows = self:GetGuildRows() or {}
    self.guildSourceFilter = oldFilter
  end
  for _, g in ipairs(allRows) do
    local kind = BLFG_SFGuildSourceKind(g)
    counts.All = counts.All + 1
    counts[kind] = (counts[kind] or 0) + 1
    if (tonumber(g.whoOnline or 0) or 0) > 0 or g.whoDiscovered or kind == "Who" then counts.Who = counts.Who + 1 end
  end
  if self.guildCountText then
    self.guildCountText:SetText("Guilds Found: " .. tostring(counts.All) .. "  |  Recruiting: " .. tostring(counts.Recruiting or 0) .. "  |  Network: " .. tostring(counts.Network or 0) .. "  |  Online: " .. tostring(counts.Who or 0))
  end
  if self.guildSourceFilterButtons then
    if self.guildSourceFilterButtons.All then self.guildSourceFilterButtons.All:SetText("All") end
    if self.guildSourceFilterButtons.Recruiting then self.guildSourceFilterButtons.Recruiting:SetText("Recruiting") end
    if self.guildSourceFilterButtons.Network then self.guildSourceFilterButtons.Network:SetText("Network") end
    if self.guildSourceFilterButtons.Who then self.guildSourceFilterButtons.Who:SetText("Online") end
  end
  if self.guildRecruitCreatorBtn and self.guildList then
    self.guildRecruitCreatorBtn:SetWidth(170)
    self.guildRecruitCreatorBtn:ClearAllPoints()
    self.guildRecruitCreatorBtn:SetPoint("BOTTOM", self.guildList, "BOTTOM", 0, 12)
  end
  if self.guildClearListingsBtn and self.guildRecruitCreatorBtn then
    self.guildClearListingsBtn:SetWidth(120)
    self.guildClearListingsBtn:ClearAllPoints()
    self.guildClearListingsBtn:SetPoint("RIGHT", self.guildRecruitCreatorBtn, "LEFT", -18, 0)
  end
  if self.guildOpenOnlineButton and self.guildRecruitCreatorBtn then
    self.guildOpenOnlineButton:SetText("SignalFire Network")
    self.guildOpenOnlineButton:SetWidth(150)
    self.guildOpenOnlineButton:ClearAllPoints()
    self.guildOpenOnlineButton:SetPoint("LEFT", self.guildRecruitCreatorBtn, "RIGHT", 18, 0)
  end
  return r
end

BLFG_SF574_OldRefreshGuildDetailPanel = BLFG.RefreshGuildDetailPanel
function BLFG:RefreshGuildDetailPanel(g, ...)
  local r = BLFG_SF574_OldRefreshGuildDetailPanel and BLFG_SF574_OldRefreshGuildDetailPanel(self, g, ...)
  local d = self.guildDetailPanel
  if d then
    if d.contact then d.contact:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -126) end
    if d.members then d.members:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -150) end
    if d.lastPost then d.lastPost:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -174) end
    if d.focusLabel then d.focusLabel:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -198) end
    if d.focus then d.focus:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -218) end
    if d.recentBox then d.recentBox:SetPoint("TOPLEFT", d, "TOPLEFT", 12, -244) end
    if g then
      if d.status then d.status:SetText("Status: " .. tostring(g.status or "--")) end
      if d.members then d.members:SetText("Source: " .. BLFG_SFGuildSourceLong(g)) end
    end
  end
  return r
end

BLFG_SF574_OldBuildOnlinePanel = BLFG.BuildOnlinePanel
function BLFG:BuildOnlinePanel(...)
  local r = BLFG_SF574_OldBuildOnlinePanel and BLFG_SF574_OldBuildOnlinePanel(self, ...)
  if self.onlinePanel then backdrop(self.onlinePanel, .72) end
  if self.onlinePanelTitle then self.onlinePanelTitle:SetText("SignalFire Network") end
  if self.onlineFilterButtons and self.onlineFilterButtons.Who then self.onlineFilterButtons.Who:SetText("Online") end
  if self.onlinePanel and self.onlinePanel.GetRegions then
    for _, region in ipairs({self.onlinePanel:GetRegions()}) do
      if region and region.GetText and tostring(region:GetText() or ""):find("You/Friend", 1, true) then region:SetText("") end
    end
  end
  if self.onlineFooter then self.onlineFooter:SetText("") end
  if self.onlineNote then
    self.onlineNote:ClearAllPoints()
    self.onlineNote:SetPoint("BOTTOM", self.onlinePanel, "BOTTOM", 0, 52)
  end
  if self.onlinePageUp then
    self.onlinePageUp:ClearAllPoints()
    self.onlinePageUp:SetPoint("BOTTOM", self.onlinePanel, "BOTTOM", -42, 42)
  end
  if self.onlinePageDown then
    self.onlinePageDown:ClearAllPoints()
    self.onlinePageDown:SetPoint("LEFT", self.onlinePageUp, "RIGHT", 8, 0)
  end
  return r
end

BLFG_SF574_OldRefreshOnlinePanel = BLFG.RefreshOnlinePanel
function BLFG:RefreshOnlinePanel(...)
  local r = BLFG_SF574_OldRefreshOnlinePanel and BLFG_SF574_OldRefreshOnlinePanel(self, ...)
  local allRows = self.GetOnlineUserRows and self:GetOnlineUserRows() or {}
  local sf, who = 0, 0
  for _, u in ipairs(allRows) do if u.whoOnly then who = who + 1 else sf = sf + 1 end end
  if self.onlinePanel then backdrop(self.onlinePanel, .72) end
  if self.onlinePanelTitle then self.onlinePanelTitle:SetText("SignalFire Network") end
  if self.onlinePanel and self.onlinePanel.GetRegions then
    for _, region in ipairs({self.onlinePanel:GetRegions()}) do
      if region and region.GetText and tostring(region:GetText() or ""):find("You/Friend", 1, true) then region:SetText("") end
    end
  end
  if self.onlineStats then
    self.onlineStats:SetText("SignalFire Users: " .. tostring(sf) .. "\nUsers Online: " .. tostring(#allRows))
    self.onlineStats:SetHeight(40)
  end
  if self.onlineFilterButtons then
    if self.onlineFilterButtons.All then self.onlineFilterButtons.All:SetText("All (" .. tostring(#allRows) .. ")") end
    if self.onlineFilterButtons.SignalFire then self.onlineFilterButtons.SignalFire:SetText("SignalFire (" .. tostring(sf) .. ")") end
    if self.onlineFilterButtons.Who then self.onlineFilterButtons.Who:SetText("Online (" .. tostring(who) .. ")") end
  end
  if self.onlineFooter then self.onlineFooter:SetText("") end
  if self.onlineNote then
    self.onlineNote:ClearAllPoints()
    self.onlineNote:SetPoint("BOTTOM", self.onlinePanel, "BOTTOM", 0, 52)
    self.onlineNote:SetText("Page " .. tostring(self.onlinePage or 1) .. " / " .. tostring(math.max(1, math.ceil(((self.onlineFilter == "SignalFire" and sf) or (self.onlineFilter == "Who" and who) or #allRows) / math.max(1, #(self.onlineRows or {}))))))
  end
  for _, row in ipairs(self.onlineRows or {}) do
    if row and row.user then
      row.name:SetText(SF574_OnlineDisplayName(row.user))
      if row.user.whoOnly then flat(row, .70) else flat(row, .78) end
    end
  end
  return r
end

function BLFG:ClearLocalGuildListings()
  self.myPublishedGuildListing = nil
  self.suppressPublishedGuildListing = true
  BLFG_MyRecruitmentListing = nil
  BLFG_SavedRecruitmentAd = nil
  self.chatGuildListings = {}
  if BronzeLFG_DB then
    BronzeLFG_DB.chatGuildListings = {}
    BronzeLFG_DB.whoGuilds = {}
    BronzeLFG_DB.whoPlayers = {}
  end
  self.whoGuilds = BronzeLFG_DB and BronzeLFG_DB.whoGuilds or {}
  self.whoPlayers = BronzeLFG_DB and BronzeLFG_DB.whoPlayers or {}
  for id, g in pairs(self.publicGroups or {}) do
    if g and (g.type == "Guild" or g.activity == "Guild Recruitment") then self.publicGroups[id] = nil end
  end
  self.selectedGuild = nil
  self.selectedGuildData = nil
  self.guildWhoCount = 0
  if self.RefreshGuildBrowser then self:RefreshGuildBrowser() end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  msg("Cleared guild listings and online discovery cache. SignalFire Network presence was kept.")
end

BLFG_SF574_Login = CreateFrame("Frame")
BLFG_SF574_Login:RegisterEvent("PLAYER_LOGIN")
BLFG_SF574_Login:SetScript("OnEvent", function()
  if BLFG and BLFG.ApplySignalFireBetaTitle then BLFG:ApplySignalFireBetaTitle() end
end)

-- ============================================================
-- SignalFire 5.7.13 - Invasions Phase 1 database tab
-- ============================================================

local function SF575_ShortText(text, maxLen)
  text = tostring(text or "")
  maxLen = tonumber(maxLen or 24) or 24
  if string.len(text) <= maxLen then return text end
  return string.sub(text, 1, maxLen - 3) .. "..."
end

local function SF575_InvasionRowsForFilter(filter, level)
  local inv = SignalFireInvasions
  if not inv or not inv.GetAll then return {} end
  filter = tostring(filter or "Recommended")
  if filter == "Alliance" then return inv.GetByFaction("Alliance") end
  if filter == "Horde" then return inv.GetByFaction("Horde") end
  if filter == "All" then return inv.GetAll() end
  return inv.GetRecommended(level)
end

local function SF575_SetButtonActive(btn, active)
  if not btn then return end
  if active then flat(btn, .92) else flat(btn, .72) end
end

if BLFG_SF573_InvasionFrame then
  BLFG_SF573_InvasionFrame:SetScript("OnUpdate", nil)
end

function BLFG:SendInvasionPresence()
end

function BLFG:HandleInvasionPresence()
end

function BLFG:InviteNearbyInvasionPlayers()
  flash("Invasion coordination is not enabled in Phase 1.")
end

function BLFG:BuildInvasions()
  if self.invasionPanel and self.invasionPanel.phaseOne then return end
  if self.invasionPanel then self.invasionPanel:Hide() end
  if self.invasionPlayerPanel then self.invasionPlayerPanel:Hide() end

  local p = CreateFrame("Frame", nil, self.content)
  self.invasionPanel = p
  p.phaseOne = true
  p:SetAllPoints()
  p:Hide()

  font(p, "SignalFire Invasions", 18, 1, .75, 0):SetPoint("TOPLEFT", p, "TOPLEFT", 4, 0)
  self.invasionLevelText = font(p, "", 12, .75, .9, 1)
  self.invasionLevelText:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -30)
  self.invasionLevelText:SetWidth(760)
  self.invasionCurrentText = font(p, "", 11, 1, 1, 1)
  self.invasionCurrentText:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -48)
  self.invasionCurrentText:SetWidth(760)

  self.invasionFilter = self.invasionFilter or "Recommended"
  self.invasionPage = 1
  self.invasionFilterButtons = {}
  local filters = {
    {"Recommended", 120},
    {"Alliance", 90},
    {"Horde", 80},
    {"All", 70},
  }
  local last
  for i = 1, #filters do
    local name, width = filters[i][1], filters[i][2]
    local b = button(p, name, width, 24)
    if last then b:SetPoint("LEFT", last, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", p, "TOPLEFT", 6, -72) end
    b:SetScript("OnClick", function()
      BLFG.invasionFilter = name
      BLFG.invasionPage = 1
      BLFG:RefreshInvasions()
    end)
    self.invasionFilterButtons[name] = b
    last = b
  end

  local box = CreateFrame("Frame", nil, p)
  self.invasionList = box
  box:SetWidth(820); box:SetHeight(258)
  box:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -106)
  backdrop(box, .86)

  local headers = {
    {"Invasion", 14, -18, 140},
    {"Faction", 160, -18, 75},
    {"Zone", 246, -18, 170},
    {"Level", 430, -18, 55},
    {"XP", 496, -18, 75},
    {"Players", 582, -18, 55},
    {"Cooldown", 650, -18, 90},
  }
  for i = 1, #headers do
    local h = headers[i]
    local t = font(box, h[1], 11, .7, .9, 1)
    t:SetPoint("TOPLEFT", box, "TOPLEFT", h[2], h[3])
    t:SetWidth(h[4])
  end

  self.invasionRows = {}
  for i = 1, 7 do
    local r = CreateFrame("Button", nil, box)
    r:SetWidth(790); r:SetHeight(27)
    r:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -38 - ((i - 1) * 29))
    r:EnableMouse(true)
    r:RegisterForClicks("AnyUp")
    r:SetFrameLevel(box:GetFrameLevel() + 3)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    flat(r, i % 2 == 0 and .56 or .48)
    r.selectedOverlay = r:CreateTexture(nil, "BACKGROUND")
    r.selectedOverlay:SetAllPoints(r)
    r.selectedOverlay:SetTexture(1, .82, 0, .28)
    r.selectedOverlay:Hide()
    r.name = font(r, "", 11, 1, .9, .55); r.name:SetPoint("LEFT", r, "LEFT", 4, 0); r.name:SetWidth(132)
    r.faction = font(r, "", 11, .9, .9, .9); r.faction:SetPoint("LEFT", r, "LEFT", 150, 0); r.faction:SetWidth(72)
    r.zone = font(r, "", 11, .9, .9, .9); r.zone:SetPoint("LEFT", r, "LEFT", 236, 0); r.zone:SetWidth(172)
    r.level = font(r, "", 11, 1, 1, 1); r.level:SetPoint("LEFT", r, "LEFT", 418, 0); r.level:SetWidth(52)
    r.xp = font(r, "", 11, .75, .9, 1); r.xp:SetPoint("LEFT", r, "LEFT", 484, 0); r.xp:SetWidth(78)
    r.players = font(r, "", 11, 1, 1, 1); r.players:SetPoint("LEFT", r, "LEFT", 572, 0); r.players:SetWidth(50)
    r.cooldown = font(r, "", 11, .85, .85, .85); r.cooldown:SetPoint("LEFT", r, "LEFT", 640, 0); r.cooldown:SetWidth(90)
    r:SetScript("OnClick", function(self)
      if self.entry then BLFG:SelectInvasion(self.entry) end
    end)
    self.invasionRows[i] = r
  end

  self.invasionPageText = font(p, "Page 1 / 1", 12, 1, .9, 0)
  self.invasionPageText:SetPoint("TOP", box, "BOTTOM", 0, -8)
  self.invasionUp = button(p, "Up", 90, 24)
  self.invasionUp:SetPoint("RIGHT", self.invasionPageText, "LEFT", -55, 0)
  self.invasionUp:SetScript("OnClick", function()
    BLFG.invasionPage = math.max(1, (BLFG.invasionPage or 1) - 1)
    BLFG:RefreshInvasions()
  end)
  self.invasionDown = button(p, "Down", 90, 24)
  self.invasionDown:SetPoint("LEFT", self.invasionPageText, "RIGHT", 55, 0)
  self.invasionDown:SetScript("OnClick", function()
    BLFG.invasionPage = (BLFG.invasionPage or 1) + 1
    BLFG:RefreshInvasions()
  end)

  local side = CreateFrame("Frame", nil, p)
  self.invasionSide = side
  side:SetWidth(810); side:SetHeight(92)
  side:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 42)
  backdrop(side, .82)
  self.invasionBeaconText = font(side, "", 11, 1, 1, 1)
  self.invasionBeaconText:SetPoint("TOPLEFT", side, "TOPLEFT", 10, -10)
  self.invasionBeaconText:SetWidth(790)
  self.invasionBeaconText:SetHeight(72)
  self.invasionBeaconText:SetJustifyH("LEFT")
  if self.BuildInvasionPlayerPanel then self:BuildInvasionPlayerPanel() end

  local b1 = button(p, "Create", 58, 24)
  self.invasionCreateBeaconButton = b1
  b1:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 6, 8)
  b1:SetScript("OnClick", function() BLFG:CreateInvasionBeacon() end)
  local b2 = button(p, "Join", 48, 24)
  self.invasionJoinBeaconButton = b2
  b2:SetPoint("LEFT", b1, "RIGHT", 6, 0)
  b2:SetScript("OnClick", function() BLFG:JoinInvasionBeacon() end)
  local b3 = button(p, "Leave", 52, 24)
  self.invasionLeaveBeaconButton = b3
  b3:SetPoint("LEFT", b2, "RIGHT", 6, 0)
  b3:SetScript("OnClick", function() BLFG:LeaveInvasionBeacon() end)
  local b4 = button(p, "Refresh", 60, 24)
  self.invasionRefreshBeaconButton = b4
  b4:SetPoint("LEFT", b3, "RIGHT", 6, 0)
  b4:SetScript("OnClick", function() BLFG:RequestInvasionBeacons() end)
  local b6 = button(p, "Scan Zone", 78, 24)
  self.invasionAddSeenButton = b6
  b6:SetPoint("LEFT", b4, "RIGHT", 6, 0)
  b6:SetScript("OnClick", function() BLFG:QueueInvasionWhoScan(true) end)
  local b7 = button(p, "Invite", 56, 24)
  self.invasionInviteSeenButton = b7
  b7:SetPoint("LEFT", b6, "RIGHT", 6, 0)
  b7:SetScript("OnClick", function() BLFG:InviteSelectedInvasionOtherPlayer() end)
  local b8 = button(p, "Post", 50, 24)
  self.invasionPostButton = b8
  b8:SetPoint("LEFT", b7, "RIGHT", 6, 0)
  b8:SetScript("OnClick", function() BLFG:PostInvasionToChat() end)
  local b9 = button(p, "Clear", 54, 24)
  self.invasionClearButton = b9
  b9:SetPoint("LEFT", b8, "RIGHT", 6, 0)
  b9:SetScript("OnClick", function() BLFG:ClearInvasionData() end)
end

function BLFG:RefreshInvasions()
  if not self.invasionPanel or not self.invasionPanel.phaseOne then return end
  local inv = SignalFireInvasions
  local level = UnitLevel and UnitLevel("player") or 0
  local alliance = inv and inv.CountByFaction and inv.CountByFaction("Alliance") or 0
  local horde = inv and inv.CountByFaction and inv.CountByFaction("Horde") or 0
  local recommendedRows = inv and inv.GetRecommendedSorted and inv.GetRecommendedSorted(level) or (inv and inv.GetRecommended and inv.GetRecommended(level) or {})
  local recommended = #recommendedRows
  if self.invasionLevelText then
    self.invasionLevelText:SetText("Your Level: " .. tostring(level) .. "  |  Recommended: " .. tostring(recommended) .. "  |  Alliance: " .. tostring(alliance) .. "  |  Horde: " .. tostring(horde))
  end
  if self.invasionCurrentText then
    local current, zone, subZone = nil, "", ""
    if inv and inv.GetCurrentInvasionArea then current, zone, subZone = inv.GetCurrentInvasionArea() end
    if current then
      local ok = inv.LevelFits and inv.LevelFits(current, level) and "recommended" or "not recommended"
      self.invasionCurrentText:SetText("Current Area: " .. tostring(current.name) .. " - " .. tostring(current.faction or "") .. " - Level " .. inv.FormatLevel(current) .. " - XP " .. inv.FormatXP(current) .. " - " .. ok)
    else
      self.invasionCurrentText:SetText("Current Area: No known invasion area detected. Zone: " .. tostring(zone or "") .. (subZone and subZone ~= "" and (" / " .. tostring(subZone)) or ""))
    end
  end

  for name, btn in pairs(self.invasionFilterButtons or {}) do
    SF575_SetButtonActive(btn, name == (self.invasionFilter or "Recommended"))
  end

  local rows = (self.invasionFilter == "Recommended" and inv and inv.GetRecommendedSorted) and inv.GetRecommendedSorted(level) or SF575_InvasionRowsForFilter(self.invasionFilter, level)
  local perPage = #(self.invasionRows or {})
  if perPage < 1 then perPage = 1 end
  local totalPages = math.max(1, math.ceil(#rows / perPage))
  self.invasionPage = math.min(math.max(1, self.invasionPage or 1), totalPages)
  local startIndex = ((self.invasionPage - 1) * perPage) + 1

  for i = 1, perPage do
    local row = self.invasionRows[i]
    local entry = rows[startIndex + i - 1]
    if row and entry then
      row:Show()
      row.entry = entry
      local selectedName = tostring(self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or "")
      local isSelected = selectedName ~= "" and selectedName == tostring(entry.name or "")
      flat(row, isSelected and .86 or (i % 2 == 0 and .56 or .48))
      if row.selectedOverlay then if isSelected then row.selectedOverlay:Show() else row.selectedOverlay:Hide() end end
      row.name:SetText(SF575_ShortText(entry.name, 22))
      row.faction:SetText(tostring(entry.faction or "--"))
      row.zone:SetText(SF575_ShortText(entry.zone, 26))
      row.level:SetText(inv.FormatLevel(entry))
      row.xp:SetText(inv.FormatXP(entry))
      row.players:SetText(tostring(entry.playersRequired or 3))
      row.cooldown:SetText(inv.FormatCooldown(entry))
    elseif row then
      row.entry = nil
      if row.selectedOverlay then row.selectedOverlay:Hide() end
      row.name:SetText(""); row.faction:SetText(""); row.zone:SetText(""); row.level:SetText("")
      row.xp:SetText(""); row.players:SetText(""); row.cooldown:SetText("")
      row:Hide()
    end
  end

  if self.invasionPageText then self.invasionPageText:SetText("Page " .. tostring(self.invasionPage or 1) .. " / " .. tostring(totalPages)) end
  if self.invasionUp then if (self.invasionPage or 1) <= 1 then self.invasionUp:Disable() else self.invasionUp:Enable() end end
  if self.invasionDown then if (self.invasionPage or 1) >= totalPages then self.invasionDown:Disable() else self.invasionDown:Enable() end end
  if self.RefreshInvasionNetworkText then self:RefreshInvasionNetworkText() end
end

function BLFG:ShowInvasions()
  self:CreateUI()
  self:HidePanels()
  self:BuildInvasions()
  self.invasionPanel:Show()
  if self.invasionPlayerPanel then self.invasionPlayerPanel:Show() end
  self.frame:Show()
  self.currentTab = "Invasions"
  self:SendInvasionPresence()
  self:RefreshInvasions()
end

BLFG_SF575_OldSlashSignalFire = SlashCmdList and SlashCmdList["SIGNALFIRE"]
if SlashCmdList then
  SLASH_SIGNALFIRE1 = "/sf"
  SLASH_SIGNALFIRE2 = "/signalfire"
  SlashCmdList["SIGNALFIRE"] = function(input)
    local cmd = SF573_Low(input)
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "invasion" or cmd == "invasions" then
      BLFG:Show()
      BLFG:ShowInvasions()
      return
    end
    if BLFG_SF575_OldSlashSignalFire then return BLFG_SF575_OldSlashSignalFire(input) end
    if cmd == "" then BLFG:Show(); return end
    msg("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic")
  end
end

-- SignalFire Invasion Network - compact safe pass.
local function SF575_InvNow()
  return now and now() or (time and time() or 0)
end

local function SF575_InvPlayerClass()
  local classFile = ""
  if UnitClass then
    local _
    _, classFile = UnitClass("player")
  end
  return tostring(classFile or "")
end

local function SF575_InvShort(text, len)
  text = tostring(text or "")
  len = tonumber(len or 22) or 22
  if string.len(text) <= len then return text end
  return string.sub(text, 1, len - 3) .. "..."
end

local function SF575_InvAge(ts)
  local age = SF575_InvNow() - (tonumber(ts or 0) or 0)
  if age < 60 then return tostring(math.max(0, math.floor(age))) .. " sec ago" end
  return tostring(math.floor(age / 60)) .. " min ago"
end
local function SF575_InvBeaconActive(b)
  return b and b.status == "active" and (tonumber(b.timestamp or 0) or 0) >= SF575_InvNow() - 600
end

local function SF575_InvBeaconWaitingCount(b)
  local count = 0
  for _ in pairs((b and b.waiting) or {}) do count = count + 1 end
  return count
end

local function SF575_InvBeaconWaitingLine(b)
  if not b or not b.waiting then return "None yet." end
  local names = {}
  for name, u in pairs(b.waiting or {}) do
    table.insert(names, {name=tostring(name or ""), level=tonumber(u and u.level or 0) or 0, class=tostring(u and u.class or "")})
  end
  table.sort(names, function(a,b) return tostring(a.name) < tostring(b.name) end)
  if #names == 0 then return "None yet." end
  local parts = {}
  for i=1, math.min(5, #names) do
    local u = names[i]
    table.insert(parts, SF575_InvShort(u.name, 12) .. " " .. tostring(u.level or "") .. (u.class ~= "" and (" " .. u.class) or ""))
  end
  if #names > 5 then table.insert(parts, "+" .. tostring(#names - 5) .. " more") end
  return table.concat(parts, ", ")
end

function BLFG:FindActiveInvasionBeaconForEntry(entry)
  if not entry then return nil end
  local target = tostring(entry.name or "")
  if target == "" then return nil end
  local bestId, bestTime = nil, 0
  for id, b in pairs(self.invasionBeacons or {}) do
    local ts = tonumber(b and b.timestamp or 0) or 0
    if b and b.status == "active" and ts >= SF575_InvNow() - 600 and tostring(b.invasionName or "") == target and ts >= bestTime then
      bestId, bestTime = id, ts
    end
  end
  return bestId
end
function BLFG:GetSelectedInvasionBeacon()
  local id = self.selectedInvasionBeacon
  local b = id and self.invasionBeacons and self.invasionBeacons[id] or nil
  if b and SF575_InvBeaconActive(b) then return id, b end
  if self.selectedInvasion then
    id = self:FindActiveInvasionBeaconForEntry(self.selectedInvasion)
    b = id and self.invasionBeacons and self.invasionBeacons[id] or nil
    if b and SF575_InvBeaconActive(b) then self.selectedInvasionBeacon = id; return id, b end
  end
  self.selectedInvasionBeacon = nil
  return nil, nil
end

function BLFG:RemoveInvasionBeaconFromPublic(id)
  if not id or not self.publicGroups then return end
  self.publicGroups["INVASION-" .. tostring(id)] = nil
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
end
function BLFG:InvasionRecruitmentText(entryOrBeacon)
  local name = tostring((entryOrBeacon and (entryOrBeacon.name or entryOrBeacon.invasionName)) or "Invasion")
  name = string.gsub(name, "%s+[Ii]nvasion$", "")
  return name .. " Invasion"
end

function BLFG:SelectInvasion(entry)
  if not entry then return end
  self.selectedInvasion = entry
  self.selectedInvasionName = tostring(entry.name or "")
  local beaconId = self:FindActiveInvasionBeaconForEntry(entry)
  self.selectedInvasionBeacon = beaconId
  self:RefreshInvasions()
end
function BLFG:GetSelectedOrCurrentInvasion()
  if self.selectedInvasion then return self.selectedInvasion end
  if SignalFireInvasions and SignalFireInvasions.GetCurrentInvasionArea then
    local current = SignalFireInvasions.GetCurrentInvasionArea()
    if current then return current end
  end
  local rows = SignalFireInvasions and SignalFireInvasions.GetRecommendedSorted and SignalFireInvasions.GetRecommendedSorted(UnitLevel("player") or 0) or {}
  return rows[1]
end

function BLFG:BroadcastInvasionBeacon(beacon)
  if not beacon then return end
  sendChan(table.concat({
    PREFIX, "INVBEACON",
    clean(beacon.id), clean(beacon.creator), clean(beacon.invasionName),
    clean(beacon.creatorLevel), clean(beacon.creatorClass), clean(beacon.zone),
    clean(beacon.playersWaiting or 1), clean(beacon.timestamp), clean(beacon.status or "active")
  }, "~"))
end

function BLFG:CreateInvasionBeacon()
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if BronzeLFG_DB.options.invasionAssist == false then msg("Invasion Assist is disabled."); return end
  local entry = self:GetSelectedOrCurrentInvasion()
  if not entry then msg("Select an invasion first, or stand in a known invasion area."); return end
  self.invasionBeacons = self.invasionBeacons or {}
  local id = playerName() .. "-" .. tostring(entry.name or "Invasion")
  local zone = GetRealZoneText and GetRealZoneText() or tostring(entry.zone or "")
  local beacon = self.invasionBeacons[id] or {}
  beacon.id = id
  beacon.creator = playerName()
  beacon.invasionName = tostring(entry.name or "Invasion")
  beacon.creatorLevel = UnitLevel("player") or 0
  beacon.creatorClass = SF575_InvPlayerClass()
  beacon.zone = tostring(zone or "")
  beacon.playersWaiting = beacon.playersWaiting or 1
  beacon.timestamp = SF575_InvNow()
  beacon.status = "active"
  beacon.waiting = beacon.waiting or {}
  beacon.waiting[playerName()] = {name=playerName(), level=beacon.creatorLevel, class=beacon.creatorClass, seen=beacon.timestamp}
  self.invasionBeacons[id] = beacon
  self.selectedInvasionBeacon = id
  self.selectedInvasion = entry
  self.selectedInvasionName = tostring(entry.name or "")
  self:BroadcastInvasionBeacon(beacon)
  self:MirrorInvasionBeaconToPublic(beacon)
  self:RefreshInvasions()
  flash("Created invasion beacon: " .. beacon.invasionName)
end

function BLFG:HandleInvasionBeacon(p)
  if not p or not p[3] then return end
  self.invasionBeacons = self.invasionBeacons or {}
  local id = tostring(p[3] or "")
  local beacon = self.invasionBeacons[id] or {waiting={}}
  beacon.id = id
  beacon.creator = tostring(p[4] or "")
  beacon.invasionName = tostring(p[5] or "Invasion")
  beacon.creatorLevel = tonumber(p[6] or 0) or 0
  beacon.creatorClass = tostring(p[7] or "")
  beacon.zone = tostring(p[8] or "")
  beacon.playersWaiting = tonumber(p[9] or 1) or 1
  beacon.timestamp = tonumber(p[10] or SF575_InvNow()) or SF575_InvNow()
  beacon.status = tostring(p[11] or "active")
  beacon.waiting = beacon.waiting or {}
  if beacon.creator ~= "" then beacon.waiting[beacon.creator] = beacon.waiting[beacon.creator] or {name=beacon.creator, level=beacon.creatorLevel, class=beacon.creatorClass, seen=beacon.timestamp} end
  self.invasionBeacons[id] = beacon
  if beacon.status == "active" then
    self.selectedInvasionBeacon = self.selectedInvasionBeacon or id
    if self.MirrorInvasionBeaconToPublic then self:MirrorInvasionBeaconToPublic(beacon) end
  else
    self:RemoveInvasionBeaconFromPublic(id)
  end
  if self.invasionPanel and self.invasionPanel:IsShown() then self:RefreshInvasions() end
end

function BLFG:JoinInvasionBeacon()
  self.invasionBeacons = self.invasionBeacons or {}
  local id, beacon = self:GetSelectedInvasionBeacon()
  if not id or not beacon then msg("No active invasion beacon selected. Create one for the selected invasion first."); return end
  self.selectedInvasionBeacon = id
  sendChan(table.concat({PREFIX, "INVJOIN", clean(id), clean(playerName()), clean(UnitLevel("player") or 0), clean(SF575_InvPlayerClass()), clean(SF575_InvNow())}, "~"))
  self:HandleInvasionJoin({PREFIX, "INVJOIN", id, playerName(), UnitLevel("player") or 0, SF575_InvPlayerClass(), SF575_InvNow()})
  flash("Joined invasion beacon: " .. tostring(beacon.invasionName or "Invasion"))
end

function BLFG:LeaveInvasionBeacon()
  local id = self.selectedInvasionBeacon
  if (not id or not (self.invasionBeacons and self.invasionBeacons[id])) and self.selectedInvasion then id = self:FindActiveInvasionBeaconForEntry(self.selectedInvasion) end
  if not id then msg("No invasion beacon selected."); return end
  self.selectedInvasionBeacon = id
  sendChan(table.concat({PREFIX, "INVLEAVE", clean(id), clean(playerName()), clean(SF575_InvNow())}, "~"))
  self:HandleInvasionLeave({PREFIX, "INVLEAVE", id, playerName(), SF575_InvNow()})
  flash("Left invasion beacon.")
end

function BLFG:HandleInvasionJoin(p)
  local id, name = tostring(p[3] or ""), tostring(p[4] or "")
  if id == "" or name == "" then return end
  self.invasionBeacons = self.invasionBeacons or {}
  local b = self.invasionBeacons[id]
  if not b then return end
  b.waiting = b.waiting or {}
  b.waiting[name] = {name=name, level=tonumber(p[5] or 0) or 0, class=tostring(p[6] or ""), seen=tonumber(p[7] or SF575_InvNow()) or SF575_InvNow()}
  local count = 0
  for _ in pairs(b.waiting) do count = count + 1 end
  b.playersWaiting = count
  b.timestamp = SF575_InvNow()
  if self.MirrorInvasionBeaconToPublic then self:MirrorInvasionBeaconToPublic(b) end
  if self.invasionPanel and self.invasionPanel:IsShown() then self:RefreshInvasions() end
end

function BLFG:HandleInvasionLeave(p)
  local id, name = tostring(p[3] or ""), tostring(p[4] or "")
  if id == "" or name == "" or not self.invasionBeacons or not self.invasionBeacons[id] then return end
  local b = self.invasionBeacons[id]
  if b.waiting then b.waiting[name] = nil end
  local count = 0
  for _ in pairs(b.waiting or {}) do count = count + 1 end
  b.playersWaiting = count
  b.timestamp = SF575_InvNow()
  if name == b.creator or count <= 0 then
    b.status = "expired"
    self:RemoveInvasionBeaconFromPublic(id)
    if self.selectedInvasionBeacon == id then self.selectedInvasionBeacon = nil end
  else
    if self.MirrorInvasionBeaconToPublic then self:MirrorInvasionBeaconToPublic(b) end
  end
  if self.invasionPanel and self.invasionPanel:IsShown() then self:RefreshInvasions() end
end

function BLFG:RequestInvasionBeacons()
  sendChan(table.concat({PREFIX, "INVREQ", clean(playerName()), clean(SF575_InvNow())}, "~"))
  self:SendInvasionPresence()
  flash("Requested active invasion beacons.")
end

function BLFG:HandleInvasionRequest()
  for _, b in pairs(self.invasionBeacons or {}) do
    if b and b.status == "active" and (tonumber(b.timestamp or 0) or 0) >= SF575_InvNow() - 600 then
      self:BroadcastInvasionBeacon(b)
    end
  end
end

function BLFG:UpsertInvasionPublicListing(entryOrBeacon, author)
  if not entryOrBeacon then return nil end
  self.publicGroups = self.publicGroups or {}
  local invName = tostring(entryOrBeacon.invasionName or entryOrBeacon.name or entryOrBeacon.activity or "Invasion")
  invName = string.gsub(invName, " Invasion$", "")
  local keyName = string.gsub(string.lower(invName), "%s+", "-")
  local id = "INVASION-" .. tostring(entryOrBeacon.id or keyName)
  local text = self:InvasionRecruitmentText(entryOrBeacon)
  local row = self.publicGroups[id] or {}
  row.id = id
  row.listingId = id
  row.player = tostring(author or entryOrBeacon.creator or playerName())
  row.leader = row.player
  row.type = "Event"
  row.invasionName = invName
  row.activity = invName .. " Invasion"
  row.message = text
  row.roles = "T/H/D"
  row.tags = "Invasion,Event"
  row.intent = "Recruiter"
  row.source = "Invasion Beacon"
  row.created = row.created or entryOrBeacon.timestamp or SF575_InvNow()
  row.seen = SF575_InvNow()
  row.time = row.seen
  row.score = 100
  row.isInvasionBeacon = true
  self.publicGroups[id] = row
  self._lastPublicGroupTouched = row
  self._lastPublicGroupTouchedKey = id
  return row
end

function BLFG:MirrorInvasionBeaconToPublic(beacon)
  if not beacon then return end
  if beacon.status and beacon.status ~= "active" then self:RemoveInvasionBeaconFromPublic(beacon.id); return end
  local row = self:UpsertInvasionPublicListing(beacon, beacon.creator)
  if row and self.RefreshPublicGroups then self:RefreshPublicGroups() end
end

function BLFG:PostInvasionToChat()
  local entry = self:GetSelectedOrCurrentInvasion()
  if not entry then msg("Select an invasion first."); return end
  local row = self:UpsertInvasionPublicListing(entry, playerName())
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  local text = self:InvasionRecruitmentText(entry)
  local channelName = (BronzeLFG_DB and BronzeLFG_DB.recruitmentCreator and BronzeLFG_DB.recruitmentCreator.broadcastChannel) or BLFG_RecruitmentPostChannel or "global"
  local channelId = GetChannelName and GetChannelName(channelName) or nil
  if (not channelId or channelId == 0) and channelName ~= "global" then
    channelId = GetChannelName and GetChannelName("global") or nil
  end
  if channelId and channelId ~= 0 and SendChatMessage then
    SendChatMessage(text, "CHANNEL", nil, channelId)
    flash("Posted invasion to global chat.")
  elseif DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cFFFFCC00SignalFire invasion:|r " .. text .. " " .. ((row and self.PublicChatLink and self:PublicChatLink(row)) or ""))
    flash("Global channel not found; posted the invasion locally.")
  else
    msg("Global channel not found for invasion post.")
  end
end

function BLFG:ClearInvasionData()
  self.invasionBeacons = {}
  self.invasionUsers = {}
  self.selectedInvasionBeacon = nil
  self.selectedInvasion = nil
  self.selectedInvasionName = nil
  for id, g in pairs(self.publicGroups or {}) do
    if g and (tostring(g.source or "") == "Invasion Beacon" or tostring(g.tags or ""):find("Invasion", 1, true)) then self.publicGroups[id] = nil end
  end
  if self.RefreshPublicGroups then self:RefreshPublicGroups() end
  self:RefreshInvasions()
  flash("Cleared invasion data.")
end

function BLFG:SendInvasionPresence()
  BronzeLFG_DB.options = BronzeLFG_DB.options or {}
  if BronzeLFG_DB.options.invasionAssist == false then return end
  local inv = SignalFireInvasions
  local current, zone, subZone = nil, "", ""
  if inv and inv.GetCurrentInvasionArea then current, zone, subZone = inv.GetCurrentInvasionArea() end
  local invasionName = current and current.name or ""
  local grouped = ((GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 or (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0) and "1" or "0"
  sendChan(table.concat({PREFIX, "INVPRES", clean(playerName()), clean(UnitLevel("player") or 0), clean(SF575_InvPlayerClass()), clean(zone), clean(subZone), clean(invasionName), clean(grouped), clean(SF575_InvNow())}, "~"))
end

BLFG_SF575_OldHandleInvasionPresence = BLFG.HandleInvasionPresence
function BLFG:HandleInvasionPresence(p)
  if not p then return end
  if p[2] == "INVPRES" then
    local name = tostring(p[3] or "")
    if name == "" or name == playerName() then return end
    self.invasionUsers = self.invasionUsers or {}
    self.invasionUsers[name] = {name=name, level=tonumber(p[4] or 0) or 0, class=tostring(p[5] or ""), zone=tostring(p[6] or ""), subzone=tostring(p[7] or ""), invasion=tostring(p[8] or ""), grouped=p[9] == "1", seen=tonumber(p[10] or SF575_InvNow()) or SF575_InvNow()}
  elseif BLFG_SF575_OldHandleInvasionPresence then
    BLFG_SF575_OldHandleInvasionPresence(self, p)
  end
  if self.invasionPanel and self.invasionPanel:IsShown() then self:RefreshInvasions() end
end


function BLFG:GetInvasionBeaconState()
  local id, beacon = nil, nil
  if self.GetSelectedInvasionBeacon then id, beacon = self:GetSelectedInvasionBeacon() end
  local me = playerName()
  local joined = false
  local mine = false
  if beacon then
    mine = tostring(beacon.creator or "") == me
    joined = mine or (beacon.waiting and beacon.waiting[me] ~= nil) or false
  end
  return id, beacon, mine, joined
end

function BLFG:RefreshInvasionActionButtons()
  local id, beacon, mine, joined = self:GetInvasionBeaconState()
  local hasSelection = self.selectedInvasion ~= nil or (self.GetSelectedOrCurrentInvasion and self:GetSelectedOrCurrentInvasion() ~= nil)
  local hasOther = self.GetSelectedInvasionOtherPlayer and self:GetSelectedInvasionOtherPlayer() ~= nil
  setButtonEnabled(self.invasionCreateBeaconButton, hasSelection and not mine)
  setButtonEnabled(self.invasionJoinBeaconButton, beacon ~= nil and not joined)
  setButtonEnabled(self.invasionLeaveBeaconButton, beacon ~= nil and joined)
  setButtonEnabled(self.invasionRefreshBeaconButton, true)
  setButtonEnabled(self.invasionAddSeenButton, true)
  setButtonEnabled(self.invasionInviteSeenButton, hasOther)
  setButtonEnabled(self.invasionPostButton, hasSelection or beacon ~= nil)
  setButtonEnabled(self.invasionClearButton, true)
end
function BLFG:RefreshInvasionNetworkText()
  if not self.invasionBeaconText then return end
  local active = 0
  local selectedId, selectedBeacon = self:GetSelectedInvasionBeacon()
  local newestId, newestTime = nil, 0
  for id, b in pairs(self.invasionBeacons or {}) do
    if SF575_InvBeaconActive(b) then
      active = active + 1
      local ts = tonumber(b.timestamp or 0) or 0
      if ts >= newestTime then newestId, newestTime = id, ts end
    end
  end
  if not selectedBeacon and newestId then
    self.selectedInvasionBeacon = newestId
    selectedId, selectedBeacon = self:GetSelectedInvasionBeacon()
  end

  local beaconLine = "No active beacon selected."
  local waitingLine = "Waiting: None yet."
  local actionLine = "Action: Select an invasion, then Create a beacon or refresh to find one."
  if selectedBeacon then
    local count = SF575_InvBeaconWaitingCount(selectedBeacon)
    local mine = tostring(selectedBeacon.creator or "") == playerName()
    local joined = mine or (selectedBeacon.waiting and selectedBeacon.waiting[playerName()] ~= nil)
    beaconLine = SF575_InvShort(selectedBeacon.invasionName, 28) .. " - " .. tostring(selectedBeacon.creator or "") .. " - " .. tostring(count) .. " waiting - " .. SF575_InvAge(selectedBeacon.timestamp)
    waitingLine = "Waiting: " .. SF575_InvBeaconWaitingLine(selectedBeacon)
    if mine then
      actionLine = "Action: You are hosting this beacon. Invite players or Post it to chat."
    elseif joined then
      actionLine = "Action: You are joined. Leave when finished, or invite nearby players."
    else
      actionLine = "Action: Join this beacon, or create your own for the selected invasion."
    end
  elseif self.selectedInvasion then
    actionLine = "Action: No beacon for this invasion yet. Create one or Post it to chat."
  end

  local nearby = 0
  local nearbyLine = "None seen yet."
  local nearbyRows = {}
  for _, u in pairs(self.invasionUsers or {}) do
    if u and (tonumber(u.seen or 0) or 0) >= SF575_InvNow() - 180 then
      nearby = nearby + 1
      table.insert(nearbyRows, u)
    end
  end
  table.sort(nearbyRows, function(a,b) return tostring(a.name or "") < tostring(b.name or "") end)
  if nearbyRows[1] then
    local u = nearbyRows[1]
    nearbyLine = SF575_InvShort(u.name, 12) .. " " .. tostring(u.level or "") .. " " .. SF575_InvShort(u.invasion ~= "" and u.invasion or u.zone, 24) .. " " .. (u.grouped and "Grouped" or "Solo") .. " - " .. SF575_InvAge(u.seen)
  end

  local selected = self.selectedInvasion and tostring(self.selectedInvasion.name or "") or "None selected."
  local text = "|cffffcc00Selected|r: " .. selected .. "\n|cffffcc00Active Beacons|r (" .. tostring(active) .. "): " .. beaconLine .. "\n" .. waitingLine .. "\n" .. actionLine .. "\n|cff99ccffNearby SignalFire|r (" .. tostring(nearby) .. "): " .. nearbyLine
  self.invasionBeaconText:SetText(text)
  if self.RefreshInvasionPlayerPanel then self:RefreshInvasionPlayerPanel() end
  if self.RefreshInvasionActionButtons then self:RefreshInvasionActionButtons() end
end

BLFG_SF575_OldHandleMessageInvasion = BLFG.HandleMessage
function BLFG:HandleMessage(text)
  if text and string.sub(text, 1, string.len(PREFIX)) == PREFIX then
    local p = split(text)
    if p[1] == PREFIX then
      if p[2] == "INVPRES" or p[2] == "INVASION" then self:HandleInvasionPresence(p); return end
      if p[2] == "INVBEACON" then self:HandleInvasionBeacon(p); return end
      if p[2] == "INVJOIN" then self:HandleInvasionJoin(p); return end
      if p[2] == "INVLEAVE" then self:HandleInvasionLeave(p); return end
      if p[2] == "INVREQ" then self:HandleInvasionRequest(p); return end
    end
  end
  return BLFG_SF575_OldHandleMessageInvasion and BLFG_SF575_OldHandleMessageInvasion(self, text)
end

BLFG_SF575_OldSlashBronzeLFGInvasion = SlashCmdList and SlashCmdList["BRONZELFG"]
if SlashCmdList then
  SlashCmdList["BRONZELFG"] = function(input)
    local cmd = SF573_Low(input or "")
    cmd = string.gsub(cmd, "^%s+", "")
    cmd = string.gsub(cmd, "%s+$", "")
    if cmd == "invasion" or cmd == "invasions" then BLFG:Show(); BLFG:ShowInvasions(); return end
    if cmd == "invbeacon" then BLFG:CreateUI(); BLFG:CreateInvasionBeacon(); return end
    if cmd == "invclear" then BLFG:ClearInvasionData(); return end
    if cmd == "invdebug" then
      local current, zone, subZone = nil, "", ""
      if SignalFireInvasions and SignalFireInvasions.GetCurrentInvasionArea then current, zone, subZone = SignalFireInvasions.GetCurrentInvasionArea() end
      local beacons, nearby = 0, 0
      for _, b in pairs(BLFG.invasionBeacons or {}) do if b.status == "active" then beacons = beacons + 1 end end
      for _, u in pairs(BLFG.invasionUsers or {}) do if (tonumber(u.seen or 0) or 0) >= SF575_InvNow() - 180 then nearby = nearby + 1 end end
      msg("Invasion debug: level=" .. tostring(UnitLevel("player") or 0) .. " zone=" .. tostring(zone) .. " subZone=" .. tostring(subZone) .. " detected=" .. tostring(current and current.name or "none") .. " beacons=" .. tostring(beacons) .. " nearby=" .. tostring(nearby))
      return
    end
    if BLFG_SF575_OldSlashBronzeLFGInvasion then return BLFG_SF575_OldSlashBronzeLFGInvasion(input) end
  end
end






-- SignalFire Invasion Network - manual group tools pass.
local function SF575_InvGroupSize()
  local raid = GetNumRaidMembers and (tonumber(GetNumRaidMembers()) or 0) or 0
  if raid and raid > 0 then return raid end
  local party = GetNumPartyMembers and (tonumber(GetNumPartyMembers()) or 0) or 0
  return (party or 0) + 1
end

local function SF575_InvCanInviteName(name)
  name = tostring(name or "")
  if name == "" or name == playerName() then return false end
  return InviteUnit ~= nil
end

function BLFG:InviteInvasionBeaconPlayers()
  local id, beacon = self:GetSelectedInvasionBeacon()
  if not id or not beacon then msg("No active invasion beacon selected."); return end
  local invited = 0
  local skipped = 0
  for name, u in pairs(beacon.waiting or {}) do
    if SF575_InvCanInviteName(name) then
      if u and u.grouped then skipped = skipped + 1 else InviteUnit(name); invited = invited + 1 end
    end
  end
  flash("Invasion beacon invites sent: " .. tostring(invited) .. (skipped > 0 and (" skipped grouped: " .. tostring(skipped)) or ""))
end

function BLFG:InviteNearbyInvasionPlayers()
  local target = self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or ""
  local current = nil
  if target == "" and SignalFireInvasions and SignalFireInvasions.GetCurrentInvasionArea then current = SignalFireInvasions.GetCurrentInvasionArea(); target = current and current.name or "" end
  local nowTime = SF575_InvNow()
  local invited = 0
  for name, u in pairs(self.invasionUsers or {}) do
    if u and (tonumber(u.seen or 0) or 0) >= nowTime - 180 and not u.grouped and SF575_InvCanInviteName(name) then
      if target == "" or tostring(u.invasion or "") == target then InviteUnit(name); invited = invited + 1 end
    end
  end
  flash("Nearby SignalFire invasion invites sent: " .. tostring(invited))
end

function BLFG:ConvertInvasionGroupToRaid()
  if not ConvertToRaid then msg("Convert to Raid is unavailable."); return end
  local size = SF575_InvGroupSize()
  if size < 2 then msg("Create or join a group before converting to raid."); return end
  ConvertToRaid()
  flash("Converted invasion group to raid.")
end



-- SignalFire Invasions - Other Players Seen - selected target pass.
function BLFG:AddInvasionSeenUnit(unit, source)
  if not UnitExists or not UnitIsPlayer or not UnitName then return false end
  if not UnitExists(unit) or not UnitIsPlayer(unit) then return false end
  local name = UnitName(unit)
  if not name or name == "" or name == playerName() then return false end
  self.invasionOtherPlayers = self.invasionOtherPlayers or {}
  local className, classFile = "", ""
  if UnitClass then className, classFile = UnitClass(unit) end
  local invName = self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or ""
  if invName == "" and SignalFireInvasions and SignalFireInvasions.GetCurrentInvasionArea then
    local current = SignalFireInvasions.GetCurrentInvasionArea()
    invName = current and tostring(current.name or "") or ""
  end
  self.invasionOtherPlayers[name] = {
    name = name,
    level = UnitLevel and (UnitLevel(unit) or 0) or 0,
    class = tostring(className or classFile or ""),
    classFile = tostring(classFile or ""),
    zone = GetRealZoneText and (GetRealZoneText() or "") or "",
    invasion = tostring(invName or ""),
    source = tostring(source or unit),
    seen = SF575_InvNow()
  }
  self.selectedInvasionOtherPlayer = name
  return true
end

function BLFG:ScanVisibleInvasionPlayers()
  local added = 0
  if self:AddInvasionSeenUnit("target", "target") then added = added + 1 end
  return added
end

local function SF575_InvOtherTTL(source)
  source = tostring(source or "")
  if source == "combat" then return 45 end
  if source == "target" then return 120 end
  if source == "/who" then return 300 end
  return 120
end

function BLFG:GetRecentInvasionOtherPlayers()
  local rows = {}
  local nowTime = SF575_InvNow()
  for _, u in pairs(self.invasionOtherPlayers or {}) do
    local seen = tonumber(u and u.seen or 0) or 0
    if u and seen >= nowTime - SF575_InvOtherTTL(u.source) then table.insert(rows, u) end
  end
  table.sort(rows, function(a,b)
    local sa, sb = tostring(a.source or ""), tostring(b.source or "")
    if sa ~= sb then
      local wa = sa == "combat" and 1 or (sa == "target" and 2 or 3)
      local wb = sb == "combat" and 1 or (sb == "target" and 2 or 3)
      if wa ~= wb then return wa < wb end
    end
    return tostring(a.name or "") < tostring(b.name or "")
  end)
  return rows
end
-- SignalFire Invasion Network - stale cleanup pass.
function BLFG:CleanupInvasionNetworkData()
  local nowTime = SF575_InvNow()
  local changed = false
  self.invasionBeacons = self.invasionBeacons or {}
  self.invasionUsers = self.invasionUsers or {}

  for id, b in pairs(self.invasionBeacons or {}) do
    local ts = tonumber(b and b.timestamp or 0) or 0
    local active = b and b.status == "active" and ts >= nowTime - 600
    if b and b.waiting then
      for name, u in pairs(b.waiting or {}) do
        local seen = tonumber(u and u.seen or ts) or ts
        if seen < nowTime - 900 then
          b.waiting[name] = nil
          changed = true
        end
      end
      b.playersWaiting = SF575_InvBeaconWaitingCount(b)
    end
    if not active then
      if b then b.status = "expired" end
      if self.publicGroups then self.publicGroups["INVASION-" .. tostring(id)] = nil end
      if self.selectedInvasionBeacon == id then self.selectedInvasionBeacon = nil end
      if ts < nowTime - 900 then
        self.invasionBeacons[id] = nil
      end
      changed = true
    end
  end

  for name, u in pairs(self.invasionUsers or {}) do
    local seen = tonumber(u and u.seen or 0) or 0
    if seen < nowTime - 300 then
      self.invasionUsers[name] = nil
      changed = true
    end
  end

  self.invasionOtherPlayers = self.invasionOtherPlayers or {}
  for name, u in pairs(self.invasionOtherPlayers or {}) do
    local seen = tonumber(u and u.seen or 0) or 0
    local ttl = SF575_InvOtherTTL and SF575_InvOtherTTL(u and u.source) or 120
    if seen < nowTime - ttl then
      self.invasionOtherPlayers[name] = nil
      if self.selectedInvasionOtherPlayer == name then self.selectedInvasionOtherPlayer = nil end
      changed = true
    end
  end

  if changed and self.currentTab == "PublicGroups" and self.RefreshPublicGroups then self:RefreshPublicGroups() end
  return changed
end
BLFG_SF575_GroupToolsOldRefreshInvasions = BLFG.RefreshInvasions
function BLFG:RefreshInvasions(...)
  if self.CleanupInvasionNetworkData then self:CleanupInvasionNetworkData() end
  if self.ScanVisibleInvasionPlayers then self:ScanVisibleInvasionPlayers() end
  local r = BLFG_SF575_GroupToolsOldRefreshInvasions and BLFG_SF575_GroupToolsOldRefreshInvasions(self, ...)
  local beacon = nil
  if self.GetSelectedInvasionBeacon then
    local _
    _, beacon = self:GetSelectedInvasionBeacon()
  end
  if self.invasionInviteBeaconButton then if beacon then self.invasionInviteBeaconButton:Enable() else self.invasionInviteBeaconButton:Disable() end end
  if self.invasionRaidButton then if SF575_InvGroupSize() >= 2 then self.invasionRaidButton:Enable() else self.invasionRaidButton:Disable() end end
  return r
end
-- SignalFire Invasions - manual other-player actions pass.
function BLFG:AddCurrentInvasionTarget()
  local added = self.ScanVisibleInvasionPlayers and self:ScanVisibleInvasionPlayers() or 0
  if self.RefreshInvasionNetworkText then self:RefreshInvasionNetworkText() end
  if added and added > 0 then flash("Added invasion player: " .. tostring(self.selectedInvasionOtherPlayer or "seen")) else msg("Target a player first.") end
end

function BLFG:GetSelectedInvasionOtherPlayer()
  local name = self.selectedInvasionOtherPlayer
  local u = name and self.invasionOtherPlayers and self.invasionOtherPlayers[name] or nil
  if u and (tonumber(u.seen or 0) or 0) >= SF575_InvNow() - 300 then return u end
  local rows = self.GetRecentInvasionOtherPlayers and self:GetRecentInvasionOtherPlayers() or {}
  if rows[1] then self.selectedInvasionOtherPlayer = rows[1].name; return rows[1] end
  return nil
end

function BLFG:WhisperSelectedInvasionOtherPlayer()
  local u = self:GetSelectedInvasionOtherPlayer()
  if not u then msg("No nearby non-SignalFire player selected."); return end
  ChatFrame_OpenChat("/w " .. tostring(u.name) .. " ")
end

function BLFG:InviteSelectedInvasionOtherPlayer()
  local u = self:GetSelectedInvasionOtherPlayer()
  if not u then msg("No nearby non-SignalFire player selected."); return end
  if InviteUnit then InviteUnit(u.name); flash("Invasion invite sent to " .. tostring(u.name) .. ".") end
end

local function SF575_HandleInvasionExtraCommand(input, oldHandler)
  local cmd = SF573_Low(input or "")
  cmd = string.gsub(cmd, "^%s+", "")
  cmd = string.gsub(cmd, "%s+$", "")
  if cmd == "" then BLFG:Toggle(); return end
  if cmd == "create" then BLFG:Show(); BLFG:ShowCreate(); return end
  if cmd == "profile" then BLFG:ShowProfile(); return end
  if cmd == "options" or cmd == "settings" then BLFG:ShowOptions(); return end
  if cmd == "public" or cmd == "groups" then BLFG:ShowPublicGroups(); return end
  if cmd == "guild" or cmd == "guilds" then BLFG:ShowGuildBrowser(); return end
  if cmd == "who" then BLFG:PrintOnlineUsers(); return end
  if cmd == "online" then BLFG:Show(); BLFG:ShowPublicGroups(); BLFG:ToggleOnlinePanel(); return end
  if cmd == "guildwho" or cmd == "whoguilds" then BLFG:QueueWhoGuildDiscovery(true); return end
  if cmd == "clearpublic" then BLFG:ClearPublicGroups(); return end
  if cmd == "applicants" then BLFG:Show(); BLFG:ShowApplicants(); return end
  if cmd == "my" or cmd == "listing" then BLFG:Show(); BLFG:ShowMyListing(); return end
  if cmd == "cancel" then BLFG:CancelMyListing("manual"); return end
  if cmd == "help" or cmd == "commands" then msg("Commands: /sf, /sf help, /sf public, /sf create, /sf profile, /sf applicants, /sf my, /sf cancel, /sf guild, /sf invasions, /sf options, /sf online, /sf who, /sf guildwho, /sf clearpublic"); return end
  if cmd == "invtarget" or cmd == "invasiontarget" then BLFG:CreateUI(); BLFG:AddCurrentInvasionTarget(); return end
  if cmd == "invwhisper" then BLFG:WhisperSelectedInvasionOtherPlayer(); return end
  if cmd == "invinviteother" then BLFG:InviteSelectedInvasionOtherPlayer(); return end
  if oldHandler then return oldHandler(input) end
end

BLFG_SF575_OldSlashSignalFireInvasionOther = SlashCmdList and SlashCmdList["SIGNALFIRE"]
BLFG_SF575_OldSlashBronzeLFGInvasionOther = SlashCmdList and SlashCmdList["BRONZELFG"]
if SlashCmdList then
  SLASH_SIGNALFIRE1 = "/sf"
  SLASH_SIGNALFIRE2 = "/signalfire"
  SlashCmdList["SIGNALFIRE"] = function(input) return SF575_HandleInvasionExtraCommand(input, BLFG_SF575_OldSlashSignalFireInvasionOther) end
  SlashCmdList["BRONZELFG"] = function(input) return SF575_HandleInvasionExtraCommand(input, BLFG_SF575_OldSlashBronzeLFGInvasionOther) end
end
-- SignalFire Invasions - silent zone /who scan.
local function SF575_InvWhoHideUI(scan)
  if WhoFrame and WhoFrame.Hide then WhoFrame:Hide() end
  if FriendsFrame and FriendsFrame.Hide and not (scan and scan.friendsWasShown) then FriendsFrame:Hide() end
end

local function SF575_InvWhoSilent()
  if SetWhoToUI then SetWhoToUI(0) end
  SF575_InvWhoHideUI()
end

local function SF575_InvWhoRestore(scan)
  if SetWhoToUI then SetWhoToUI(1) end
  SF575_InvWhoHideUI(scan)
end

function BLFG:QueueInvasionWhoScan(manual)
  if self.whoDiscovery and self.whoDiscovery.active then if manual then msg("SignalFire Network /who discovery is already running. Try again when it finishes.") end; return end
  if not SendWho then if manual then msg("/who scan is unavailable on this client.") end; return end
  local zone = GetRealZoneText and (GetRealZoneText() or "") or ""
  if zone == "" then if manual then msg("Could not determine current zone for invasion scan.") end; return end
  self.invasionWhoScan = {
    active = true,
    pending = false,
    elapsed = 4,
    index = 1,
    queue = {'z-"' .. zone .. '"', zone},
    zone = zone,
    manual = manual and true or false,
    friendsWasShown = FriendsFrame and FriendsFrame.IsShown and FriendsFrame:IsShown() and true or false,
  }
  if manual then msg("Scanning current zone for invasion candidates: " .. zone) end
  if self.invasionWhoFrame then self.invasionWhoFrame:Show() end
end

function BLFG:RecordInvasionWhoPlayer(name, guild, level, className, zone)
  name = tostring(name or "")
  name = string.gsub(name, "%-.*$", "")
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  if name == "" or name == playerName() then return false end
  self.invasionOtherPlayers = self.invasionOtherPlayers or {}
  local invName = self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or ""
  if invName == "" and SignalFireInvasions and SignalFireInvasions.GetCurrentInvasionArea then
    local current = SignalFireInvasions.GetCurrentInvasionArea()
    invName = current and tostring(current.name or "") or ""
  end
  self.invasionOtherPlayers[name] = {
    name = name,
    level = tonumber(level or 0) or 0,
    class = tostring(className or ""),
    classFile = normalizeClassFile and normalizeClassFile(className or "") or tostring(className or ""),
    guild = tostring(guild or ""),
    zone = tostring(zone or ""),
    invasion = tostring(invName or ""),
    source = "/who",
    seen = SF575_InvNow()
  }
  if not self.selectedInvasionOtherPlayer then self.selectedInvasionOtherPlayer = name end
  return true
end

function BLFG:HandleInvasionWhoListUpdate()
  local scan = self.invasionWhoScan
  if not (scan and scan.active and scan.pending) then return false end
  local added = 0
  local count = GetNumWhoResults and GetNumWhoResults() or 0
  for i=1, count do
    local name, guild, level, race, className, zone, classFile = GetWhoInfo(i)
    local z = tostring(zone or "")
    if scan.zone == "" or z == scan.zone then
      if self:RecordInvasionWhoPlayer(name, guild, level, classFile or className, z) then added = added + 1 end
    end
  end
  scan.pending = false
  scan.elapsed = 0
  SF575_InvWhoRestore(scan)
  if scan.index > #(scan.queue or {}) then
    scan.active = false
    if scan.manual then msg("Invasion zone scan complete. Players seen: " .. tostring(#(self:GetRecentInvasionOtherPlayers() or {}))) end
    if self.invasionWhoFrame then self.invasionWhoFrame:Hide() end
  end
  if self.RefreshInvasionNetworkText then self:RefreshInvasionNetworkText() end
  if self.invasionPanel and self.invasionPanel:IsShown() and self.RefreshInvasions then self:RefreshInvasions() end
  return true
end

function BLFG:InvasionWhoScanTick(elapsed)
  local scan = self.invasionWhoScan
  if not scan or not scan.active then return end
  scan.elapsed = (scan.elapsed or 0) + (elapsed or 0)
  if scan.pending then
    SF575_InvWhoHideUI(scan)
    if scan.elapsed > 10 then
      scan.pending = false
      scan.elapsed = 0
      SF575_InvWhoRestore(scan)
    end
    return
  end
  if scan.elapsed < 4 then return end
  scan.elapsed = 0
  local query = scan.queue and scan.queue[scan.index]
  if not query then
    scan.active = false
    SF575_InvWhoRestore(scan)
    if scan.manual then msg("Invasion zone scan complete. Players seen: " .. tostring(#(self:GetRecentInvasionOtherPlayers() or {}))) end
    if self.invasionWhoFrame then self.invasionWhoFrame:Hide() end
    return
  end
  scan.index = scan.index + 1
  scan.pending = true
  SF575_InvWhoSilent()
  SendWho(query)
  SF575_InvWhoHideUI(scan)
end

BLFG_SF575_InvWhoFrame = CreateFrame("Frame")
BLFG_SF575_InvWhoFrame:RegisterEvent("WHO_LIST_UPDATE")
BLFG_SF575_InvWhoFrame:SetScript("OnEvent", function(_, event)
  if event == "WHO_LIST_UPDATE" and BLFG and BLFG.HandleInvasionWhoListUpdate then BLFG:HandleInvasionWhoListUpdate() end
end)
BLFG.invasionWhoFrame = CreateFrame("Frame")
BLFG.invasionWhoFrame:Hide()
BLFG.invasionWhoFrame:SetScript("OnUpdate", function(_, elapsed)
  if BLFG and BLFG.InvasionWhoScanTick then BLFG:InvasionWhoScanTick(elapsed) end
end)
-- SignalFire Invasions - Spy-style passive nearby player detection.
local function SF575_InvCleanName(name)
  name = tostring(name or "")
  name = string.gsub(name, "%s+%-%s+.*$", "")
  name = string.gsub(name, "%-.*$", "")
  name = string.gsub(name, "^%s+", "")
  name = string.gsub(name, "%s+$", "")
  return name
end

local function SF575_InvPlayerGuid(guid)
  guid = tostring(guid or "")
  if guid == "" then return false end
  local ok, t = pcall(function() return tonumber("0x" .. string.sub(guid, 3, 5)) end)
  if not ok or not t then return false end
  local playerType = t % 16
  return playerType == 0 or playerType == 8
end

function BLFG:RecordInvasionNearbyUnit(unit, source)
  if not unit or not UnitExists or not UnitExists(unit) or not UnitIsPlayer or not UnitIsPlayer(unit) then return false end
  local name = GetUnitName and GetUnitName(unit, true) or UnitName(unit)
  name = SF575_InvCleanName(name)
  if name == "" or name == playerName() then return false end
  local _, classFile = UnitClass(unit)
  local level = UnitLevel and UnitLevel(unit) or 0
  local guild = GetGuildInfo and GetGuildInfo(unit) or ""
  local zone = GetRealZoneText and (GetRealZoneText() or "") or ""
  self.invasionOtherPlayers = self.invasionOtherPlayers or {}
  local old = self.invasionOtherPlayers[name] or {}
  old.name = name
  old.level = tonumber(level or old.level or 0) or 0
  old.class = tostring(classFile or old.class or "")
  old.classFile = tostring(classFile or old.classFile or "")
  old.guild = tostring(guild or old.guild or "")
  old.zone = tostring(zone or old.zone or "")
  old.invasion = tostring(self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or old.invasion or "")
  old.source = tostring(source or "nearby")
  old.seen = SF575_InvNow()
  self.invasionOtherPlayers[name] = old
  if not self.selectedInvasionOtherPlayer then self.selectedInvasionOtherPlayer = name end
  return true
end

function BLFG:RecordInvasionCombatLogPlayer(name, guid, source)
  name = SF575_InvCleanName(name)
  if name == "" or name == playerName() or not SF575_InvPlayerGuid(guid) then return false end
  self.invasionOtherPlayers = self.invasionOtherPlayers or {}
  local old = self.invasionOtherPlayers[name] or {}
  old.name = name
  old.level = tonumber(old.level or 0) or 0
  old.class = tostring(old.class or "")
  old.classFile = tostring(old.classFile or "")
  old.guild = tostring(old.guild or "")
  old.zone = tostring(old.zone ~= "" and old.zone or (GetRealZoneText and GetRealZoneText() or ""))
  old.invasion = tostring(self.selectedInvasionName or (self.selectedInvasion and self.selectedInvasion.name) or old.invasion or "")
  old.source = tostring(source or "combat")
  old.seen = SF575_InvNow()
  self.invasionOtherPlayers[name] = old
  if not self.selectedInvasionOtherPlayer then self.selectedInvasionOtherPlayer = name end
  return true
end

function BLFG:RefreshInvasionSeenPanelIfOpen()
  if not (self.invasionPanel and self.invasionPanel:IsShown() and self.RefreshInvasionNetworkText) then return end
  local nowTime = GetTime and GetTime() or SF575_InvNow()
  if self._lastInvasionSeenPanelRefresh and nowTime - self._lastInvasionSeenPanelRefresh < .35 then return end
  self._lastInvasionSeenPanelRefresh = nowTime
  self:RefreshInvasionNetworkText()
end

BLFG_SF575_InvNearbyFrame = BLFG_SF575_InvNearbyFrame or CreateFrame("Frame")
BLFG_SF575_InvNearbyFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
BLFG_SF575_InvNearbyFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
BLFG_SF575_InvNearbyFrame:SetScript("OnEvent", function(_, event, ...)
  if not BLFG then return end
  local changed = false
  if event == "PLAYER_TARGET_CHANGED" then
    changed = BLFG:RecordInvasionNearbyUnit("target", "target") or changed
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    local timestamp, subEvent, srcGUID, srcName, srcFlags, dstGUID, dstName = ...
    changed = BLFG:RecordInvasionCombatLogPlayer(srcName, srcGUID, "combat") or changed
    changed = BLFG:RecordInvasionCombatLogPlayer(dstName, dstGUID, "combat") or changed
  end
  if changed and BLFG.RefreshInvasionSeenPanelIfOpen then BLFG:RefreshInvasionSeenPanelIfOpen() end
end)

-- SignalFire Invasions - Other Players pop-out panel.
function BLFG:BuildInvasionPlayerPanel()
  if self.invasionPlayerPanel then return end
  local parent = self.frame or UIParent
  local f = CreateFrame("Frame", nil, parent)
  self.invasionPlayerPanel = f
  f:SetWidth(260); f:SetHeight(360)
  f:SetPoint("TOPRIGHT", self.frame or UIParent, "TOPLEFT", -8, -52)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  f:SetFrameStrata((self.frame and self.frame:GetFrameStrata()) or "HIGH")
  f:SetFrameLevel(((self.frame and self.frame:GetFrameLevel()) or 1) + 90)
  backdrop(f, .68)
  f.refreshElapsed = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self.refreshElapsed = (self.refreshElapsed or 0) + (elapsed or 0)
    if self.refreshElapsed >= 1 then
      self.refreshElapsed = 0
      if BLFG and BLFG.RefreshInvasionPlayerPanel then BLFG:RefreshInvasionPlayerPanel() end
    end
  end)
  f:Hide()

  f.title = font(f, "Other Players", 14, 1, .82, .05)
  f.title:SetPoint("TOP", f, "TOP", 0, -10)
  f.count = font(f, "0 seen", 10, .75, .9, 1)
  f.count:SetPoint("TOP", f.title, "BOTTOM", 0, -3)

  local close = button(f, "x", 22, 20)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
  close:SetScript("OnClick", function() f:Hide() end)
  self.invasionPlayersCloseButton = close

  local scan = button(f, "Scan Zone", 86, 22)
  scan:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -38)
  scan:SetScript("OnClick", function() BLFG:QueueInvasionWhoScan(true) end)
  local invite = button(f, "Invite", 60, 22)
  invite:SetPoint("LEFT", scan, "RIGHT", 6, 0)
  invite:SetScript("OnClick", function() BLFG:InviteSelectedInvasionOtherPlayer() end)
  local whisp = button(f, "Whisp", 58, 22)
  whisp:SetPoint("LEFT", invite, "RIGHT", 6, 0)
  whisp:SetScript("OnClick", function() BLFG:WhisperSelectedInvasionOtherPlayer() end)

  local header = font(f, "Name              Lvl  Seen", 10, .7, .9, 1)
  header:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -68)
  header:SetWidth(236)

  self.invasionPlayerRows = {}
  for i=1,9 do
    local r = CreateFrame("Button", nil, f)
    r:SetWidth(236); r:SetHeight(23)
    r:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -86 - ((i - 1) * 24))
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    flat(r, i % 2 == 0 and .16 or .10)
    r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    r.name = font(r, "", 10, 1, .9, .55); r.name:SetPoint("LEFT", r, "LEFT", 5, 0); r.name:SetWidth(118)
    r.level = font(r, "", 10, 1, 1, 1); r.level:SetPoint("LEFT", r, "LEFT", 128, 0); r.level:SetWidth(28)
    r.source = font(r, "", 10, .75, .9, 1); r.source:SetPoint("LEFT", r, "LEFT", 158, 0); r.source:SetWidth(72)
    r:SetScript("OnClick", function(self, button)
      if not self.playerName then return end
      BLFG.selectedInvasionOtherPlayer = self.playerName
      if button == "RightButton" then
        ChatFrame_OpenChat("/w " .. tostring(self.playerName) .. " ")
      elseif IsShiftKeyDown and IsShiftKeyDown() and InviteUnit then
        InviteUnit(self.playerName)
        flash("Invasion invite sent to " .. tostring(self.playerName) .. ".")
      end
      if BLFG.RefreshInvasionPlayerPanel then BLFG:RefreshInvasionPlayerPanel() end
    end)
    r:Hide()
    self.invasionPlayerRows[i] = r
  end

  self.invasionPlayerPage = self.invasionPlayerPage or 1
  self.invasionPlayerPageText = font(f, "Page 1 / 1", 11, 1, .9, 0)
  self.invasionPlayerPageText:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
  local up = button(f, "Up", 54, 22)
  self.invasionPlayerUpButton = up
  up:SetPoint("RIGHT", self.invasionPlayerPageText, "LEFT", -18, 0)
  up:SetScript("OnClick", function()
    BLFG.invasionPlayerPage = math.max(1, (BLFG.invasionPlayerPage or 1) - 1)
    BLFG:RefreshInvasionPlayerPanel()
  end)
  local down = button(f, "Down", 62, 22)
  self.invasionPlayerDownButton = down
  down:SetPoint("LEFT", self.invasionPlayerPageText, "RIGHT", 18, 0)
  down:SetScript("OnClick", function()
    BLFG.invasionPlayerPage = (BLFG.invasionPlayerPage or 1) + 1
    BLFG:RefreshInvasionPlayerPanel()
  end)
end

function BLFG:RefreshInvasionPlayerPanel()
  if not self.invasionPlayerPanel then return end
  local rows = self.GetRecentInvasionOtherPlayers and self:GetRecentInvasionOtherPlayers() or {}
  local perPage = 9
  local totalPages = math.max(1, math.ceil(#rows / perPage))
  self.invasionPlayerPage = math.min(math.max(1, self.invasionPlayerPage or 1), totalPages)
  if (not self.selectedInvasionOtherPlayer or not self.invasionOtherPlayers or not self.invasionOtherPlayers[self.selectedInvasionOtherPlayer]) and rows[1] then
    self.selectedInvasionOtherPlayer = rows[1].name
  end
  if self.invasionPlayerPanel.count then self.invasionPlayerPanel.count:SetText(tostring(#rows) .. " seen") end
  local start = ((self.invasionPlayerPage or 1) - 1) * perPage + 1
  for i=1, perPage do
    local row = self.invasionPlayerRows and self.invasionPlayerRows[i]
    local u = rows[start + i - 1]
    if row and u then
      row.playerName = u.name
      row.name:SetText((u.name == self.selectedInvasionOtherPlayer and "> " or "") .. SF575_InvShort(u.name, 16))
      row.level:SetText(tostring(u.level and u.level > 0 and u.level or "-"))
      row.source:SetText(SF575_InvAge(u.seen))
      flat(row, u.name == self.selectedInvasionOtherPlayer and .42 or (i % 2 == 0 and .16 or .10))
      row:Show()
    elseif row then
      row.playerName = nil
      row:Hide()
    end
  end
  if self.invasionPlayerPageText then self.invasionPlayerPageText:SetText("Page " .. tostring(self.invasionPlayerPage or 1) .. " / " .. tostring(totalPages)) end
  if self.invasionPlayerUpButton then if (self.invasionPlayerPage or 1) <= 1 then self.invasionPlayerUpButton:Disable() else self.invasionPlayerUpButton:Enable() end end
  if self.invasionPlayerDownButton then if (self.invasionPlayerPage or 1) >= totalPages then self.invasionPlayerDownButton:Disable() else self.invasionPlayerDownButton:Enable() end end
end

-- SignalFire safe guild recruiting merge fix.
-- Uses global helpers to avoid Lua 5.1's top-level local variable limit.
function SF576_GuildKey(name)
  if BLFG_5618_Norm then return BLFG_5618_Norm(name or "") end
  return string.lower(tostring(name or "")):gsub("[^%w]+", "")
end

function SF576_RowMessage(g)
  if not g then return "" end
  return table.concat({
    tostring(g.lastPost or ""),
    tostring(g.message or ""),
    tostring(g.rawMessage or ""),
    tostring(g.post or ""),
    tostring(g.recruitmentMessage or ""),
    tostring(g.recentRecruitmentMessage or "")
  }, " ")
end

function SF576_HasRecruitment(g)
  if not g then return false end
  if g.sourceHasRecruitment or g.guildRecruitment or g.isGuildRecruitment or g.recruitmentAd then return true end
  if tostring(g.type or "") == "Guild" or tostring(g.activity or "") == "Guild Recruitment" then return true end
  if (tonumber(g.posts or 0) or 0) > 0 then return true end
  if tostring(g.source or "") == "Chat" or tostring(g.source or "") == "Recruitment Ad" or tostring(g.status or "") == "Chat Only" then return true end
  if BLFG_570b1b_IsGuildAd and BLFG_570b1b_IsGuildAd(SF576_RowMessage(g)) then return true end
  return false
end

function SF576_ChatRecruitmentForGuild(g)
  if not BLFG or not g then return nil end
  local key = SF576_GuildKey(g.name or g.guild or g.guildName or "")
  local row = nil
  if key ~= "" and BLFG.chatGuildListings then row = BLFG.chatGuildListings[key] end
  if not row and key ~= "" and BronzeLFG_DB and BronzeLFG_DB.chatGuildListings then row = BronzeLFG_DB.chatGuildListings[key] end
  if row and SF576_HasRecruitment(row) then return row end
  return nil
end

function SF576_MergeRecruitment(g)
  local row = SF576_ChatRecruitmentForGuild(g)
  if not g or not row then return false end
  g.sourceHasRecruitment = true
  g.guildRecruitment = true
  g.isGuildRecruitment = true
  g.recruitmentAd = true
  if not g.lastPost or g.lastPost == "" or g.whoDiscovered then g.lastPost = row.lastPost or row.message or row.rawMessage end
  if not g.message or g.message == "" then g.message = row.message or row.lastPost or row.rawMessage end
  if not g.rawMessage or g.rawMessage == "" then g.rawMessage = row.rawMessage or row.message or row.lastPost end
  if (not g.recruiting or g.recruiting == "" or g.recruiting == "N/A" or g.recruiting == "Unknown") and row.recruiting then g.recruiting = row.recruiting end
  if (not g.recruitingRaw or g.recruitingRaw == "") and row.recruitingRaw then g.recruitingRaw = row.recruitingRaw end
  if (not g.focus or g.focus == "" or g.focus == "N/A" or g.focus == "Unknown") and row.focus then g.focus = row.focus end
  if (not g.focusRaw or g.focusRaw == "") and row.focusRaw then g.focusRaw = row.focusRaw end
  g.posts = math.max(tonumber(g.posts or 0) or 0, tonumber(row.posts or 0) or 1)
  return true
end

BLFG_SF576_OldUpsertGuildBrowserChatListing = BLFG and BLFG.UpsertGuildBrowserChatListing
if BLFG_SF576_OldUpsertGuildBrowserChatListing then
  function BLFG:UpsertGuildBrowserChatListing(guildName, author, text)
    local name = guildName or (BLFG_570b1_GuildNameFromAd and BLFG_570b1_GuildNameFromAd(text or "")) or (BLFG_570b1b_GuildNameFromAd and BLFG_570b1b_GuildNameFromAd(text or "")) or ""
    local r = BLFG_SF576_OldUpsertGuildBrowserChatListing(self, name, author, text)
    if r and SF576_HasRecruitment(r) then
      r.sourceHasRecruitment = true
      r.guildRecruitment = true
      r.isGuildRecruitment = true
      r.recruitmentAd = true
    end
    return r
  end
end

function BLFG_SFGuildSourceKind(g)
  if not g then return "Who" end
  if SF576_HasRecruitment(g) or SF576_MergeRecruitment(g) then return "Recruiting" end
  if SF574_GuildSignalFireOnline and SF574_GuildSignalFireOnline(g) > 0 then return "Network" end
  return "Who"
end

function BLFG_SFGuildMatchesSourceFilter(g, filter)
  filter = tostring(filter or "All")
  if filter == "All" then return true end
  if filter == "Who" or filter == "Online" then return g and ((tonumber(g.whoOnline or 0) or 0) > 0 or g.whoDiscovered or BLFG_SFGuildSourceKind(g) == "Who") end
  if filter == "Network" then return (not SF576_HasRecruitment(g)) and (not SF576_ChatRecruitmentForGuild(g)) and SF574_GuildSignalFireOnline and SF574_GuildSignalFireOnline(g) > 0 end
  return BLFG_SFGuildSourceKind(g) == filter
end

function BLFG_SFGuildSourceLong(g)
  local kind = BLFG_SFGuildSourceKind(g)
  if kind == "Recruiting" then
    if SF574_GuildSignalFireOnline and SF574_GuildSignalFireOnline(g) > 0 then return "Recruitment Ad + SignalFire Network" end
    return "Recruitment Ad"
  end
  if kind == "Network" then return "SignalFire Network" end
  return "Online"
end

-- ============================================================================
-- SignalFire v1.3.5j: dropdown arrow hardening
-- ============================================================================
-- Several older tabs still use native UIDropDownMenuTemplate frames.  Some 3.3.5
-- skins/addon stacks hide or misplace the template's tiny Button texture, so add
-- a visible in-frame arrow overlay and keep the real dropdown button available.
BLFG_SF135J_OrigFixDropdownButton = BLFG_SF135J_OrigFixDropdownButton or BLFG_FixDropdownButton
function BLFG_FixDropdownButton(d)
  -- SignalFire 1.4.30h: the specific-dungeon field intentionally opts out of
  -- the legacy 1.3.5j arrow/click-catcher hardening. This check MUST happen
  -- before calling the original fixer, otherwise it resurrects the stock menu.
  if d and d.SFDisableNativeMenu then
    if BLFG_SF1430H_SuppressNativeDropdown then BLFG_SF1430H_SuppressNativeDropdown(d) end
    return
  end
  if BLFG_SF135J_OrigFixDropdownButton and BLFG_SF135J_OrigFixDropdownButton ~= BLFG_FixDropdownButton then
    pcall(BLFG_SF135J_OrigFixDropdownButton, d)
  end
  if not d or not d.GetName then return end
  local name = d:GetName()
  if not name then return end

  local b = _G[name .. "Button"]
  local middle = _G[name .. "Middle"] or d
  if b then
    b:Show()
    b:SetAlpha(1)
    if b.SetWidth then b:SetWidth(24) end
    if b.SetHeight then b:SetHeight(24) end
    if b.ClearAllPoints then
      b:ClearAllPoints()
      b:SetPoint("RIGHT", middle, "RIGHT", 2, 1)
    end
    if b.SetFrameLevel and d.GetFrameLevel then b:SetFrameLevel((d:GetFrameLevel() or 1) + 10) end
    if b.SetNormalTexture then b:SetNormalTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up") end
    if b.SetPushedTexture then b:SetPushedTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Down") end
    if b.SetDisabledTexture then b:SetDisabledTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Disabled") end
    if b.SetHighlightTexture then b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight") end
  end

  if not d.sf135jArrow then
    d.sf135jArrow = d:CreateTexture(nil, "OVERLAY")
    d.sf135jArrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    d.sf135jArrow:SetWidth(18)
    d.sf135jArrow:SetHeight(18)
  end
  d.sf135jArrow:ClearAllPoints()
  d.sf135jArrow:SetPoint("RIGHT", middle, "RIGHT", -2, 1)
  d.sf135jArrow:Show()

  if not d.sf135jClickCatcher then
    d.sf135jClickCatcher = CreateFrame("Button", nil, d)
    d.sf135jClickCatcher:RegisterForClicks("LeftButtonUp")
    d.sf135jClickCatcher:SetScript("OnClick", function()
      if ToggleDropDownMenu then ToggleDropDownMenu(1, nil, d, d, 0, 0) end
      if BLFG_SF135J_FixDropdownLayers then BLFG_SF135J_FixDropdownLayers() end
    end)
  end
  d.sf135jClickCatcher:ClearAllPoints()
  d.sf135jClickCatcher:SetPoint("RIGHT", middle, "RIGHT", 4, 1)
  d.sf135jClickCatcher:SetWidth(28)
  d.sf135jClickCatcher:SetHeight(24)
  d.sf135jClickCatcher:Show()
  if d.sf135jClickCatcher.SetFrameLevel and d.GetFrameLevel then d.sf135jClickCatcher:SetFrameLevel((d:GetFrameLevel() or 1) + 11) end
end

function BLFG_SF135J_FixAllDropdowns(root)
  if not root or not root.GetChildren then return end
  local kids = {root:GetChildren()}
  for _, child in ipairs(kids) do
    if child and child.GetName then
      local name = child:GetName()
      if name and _G[name .. "Button"] then BLFG_FixDropdownButton(child) end
    end
    if child and child.GetChildren then BLFG_SF135J_FixAllDropdowns(child) end
  end
end

function BLFG_SF135J_FixVisibleDropdowns()
  if not BLFG then return end
  BLFG_SF135J_FixAllDropdowns(BLFG.frame)
  BLFG_SF135J_FixAllDropdowns(BLFG.content)
  BLFG_SF135J_FixAllDropdowns(BLFG.optionsPanel)
  BLFG_SF135J_FixAllDropdowns(BLFG.create)
  BLFG_SF135J_FixAllDropdowns(BLFG.profile)
end

BLFG_SF135J_OldCreateUI = BLFG_SF135J_OldCreateUI or BLFG.CreateUI
function BLFG:CreateUI(...)
  local r = BLFG_SF135J_OldCreateUI and BLFG_SF135J_OldCreateUI(self, ...)
  BLFG_SF135J_FixVisibleDropdowns()
  return r
end

BLFG_SF135J_OldShowCreate = BLFG_SF135J_OldShowCreate or BLFG.ShowCreate
function BLFG:ShowCreate(...)
  local r = BLFG_SF135J_OldShowCreate and BLFG_SF135J_OldShowCreate(self, ...)
  BLFG_SF135J_FixVisibleDropdowns()
  return r
end

BLFG_SF135J_OldShowProfile = BLFG_SF135J_OldShowProfile or BLFG.ShowProfile
function BLFG:ShowProfile(...)
  local r = BLFG_SF135J_OldShowProfile and BLFG_SF135J_OldShowProfile(self, ...)
  BLFG_SF135J_FixVisibleDropdowns()
  return r
end

BLFG_SF135J_OldShowOptions = BLFG_SF135J_OldShowOptions or BLFG.ShowOptions
function BLFG:ShowOptions(...)
  local r = BLFG_SF135J_OldShowOptions and BLFG_SF135J_OldShowOptions(self, ...)
  BLFG_SF135J_FixVisibleDropdowns()
  return r
end

BLFG_SF135J_LoginFrame = BLFG_SF135J_LoginFrame or CreateFrame("Frame")
BLFG_SF135J_LoginFrame:RegisterEvent("PLAYER_LOGIN")
BLFG_SF135J_LoginFrame:SetScript("OnEvent", function()
  if BLFG_SF135J_FixVisibleDropdowns then BLFG_SF135J_FixVisibleDropdowns() end
end)

function BLFG_SF135J_FixDropdownLayers()
  -- Apply layering only when a SignalFire-owned dropdown has just opened.
  -- Never attach hooks to Blizzard's global DropDownList frames: the same
  -- frames are used by player/party portrait menus and must remain untouched.
  local maxLevels = tonumber(UIDROPDOWNMENU_MAXLEVELS or 2) or 2
  for i = 1, maxLevels do
    local f = _G["DropDownList" .. tostring(i)]
    if f and (not f.IsShown or f:IsShown()) then
      if f.SetFrameStrata then f:SetFrameStrata("TOOLTIP") end
      if f.SetFrameLevel then f:SetFrameLevel(1000 + i) end
    end
  end
end


-- SignalFire 1.4.30: side-effect-free probe for the full BronzeLFG parser.
-- Defined in this file so it can use the local parser functions without
-- adding another live chat hook or creating Public Groups rows.
function BLFG:SF1430_CoreParseText(text)
  local raw = tostring(text or "")
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
  if BronzeLFG_IsAddonSpam and BronzeLFG_IsAddonSpam(raw) then
    result.reason = "Addon traffic"
    return result
  end
  if isPublicJunkText and isPublicJunkText(raw) then
    result.reason = "Noise, trade, or external promotion"
    return result
  end

  local display = cleanPublicChatText(raw)
  if not containsLFG(display) then return result end

  local socialQuestion = isPublicSocialQuestion(display)
  if isPublicConversation(display) and not socialQuestion then
    result.reason = "Ordinary conversation"
    return result
  end

  local intent = socialQuestion and "Social" or guessPublicIntent(display)
  local activity = guessPublicActivity(display)
  local publicType = classifyPublicType(display, activity, intent)
  activity = normalizePublicActivity(publicType, activity, display)

  result.eligible = true
  result.kind = publicType == "Guild" and "guild" or "group"
  result.type = publicType
  result.activity = activity
  result.intent = intent
  result.roles = guessPublicRoles(display, intent)
  result.tags = guessPublicTags(display, activity, publicType)

  if result.kind == "guild" and extractGuildNameFromPost then
    local ok, guildName = pcall(extractGuildNameFromPost, {message=display, player=""})
    if ok and guildName and tostring(guildName) ~= "" then result.guild = tostring(guildName) end
  end

  result.reason = nil
  return result
end


-- SignalFire 1.4.23: no-local central visible-version finalizer.
-- Keep this block free of `local` declarations; BronzeLFG.lua is already near
-- Lua 5.1/Wrath's 200-local main-chunk compiler limit.
VERSION = (SignalFire_GetVersion and SignalFire_GetVersion()) or SignalFire_VERSION or "1.4.23"
BRONZELFG_VERSION = VERSION
BLFG_VERSION = VERSION
BronzeLFG_Version = VERSION
if BronzeLFG then
  BronzeLFG.version = VERSION
  if BronzeLFG_ApplyVisibleVersion then
    BronzeLFG_ApplyVisibleVersion()
  elseif BronzeLFG.titleText and BronzeLFG.titleText.SetText then
    BronzeLFG.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or ("SignalFire v" .. tostring(VERSION) .. " (Beta)"))
  end
end
if CreateFrame then
  BLFG_SFV_FinalizeFrame = BLFG_SFV_FinalizeFrame or CreateFrame("Frame")
  BLFG_SFV_FinalizeFrame:RegisterEvent("PLAYER_LOGIN")
  BLFG_SFV_FinalizeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
  BLFG_SFV_FinalizeFrame:SetScript("OnEvent", function()
    VERSION = (SignalFire_GetVersion and SignalFire_GetVersion()) or SignalFire_VERSION or "1.4.23"
    BRONZELFG_VERSION = VERSION
    BLFG_VERSION = VERSION
    BronzeLFG_Version = VERSION
    if BronzeLFG then
      BronzeLFG.version = VERSION
      if BronzeLFG_ApplyVisibleVersion then
        BronzeLFG_ApplyVisibleVersion()
      elseif BronzeLFG.titleText and BronzeLFG.titleText.SetText then
        BronzeLFG.titleText:SetText((SignalFire_GetTitleText and SignalFire_GetTitleText()) or ("SignalFire v" .. tostring(VERSION) .. " (Beta)"))
      end
    end
  end)
end
