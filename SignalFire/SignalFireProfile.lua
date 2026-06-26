-- SignalFireProfile.lua
-- Profile data only. Keep parser behavior in BronzeLFG.lua and read realm-specific
-- content from these tables.

SignalFireProfiles = SignalFireProfiles or {}

local function copyList(src)
  local out = {}
  for i, v in ipairs(src or {}) do out[i] = v end
  return out
end

local function makeSet(src)
  local out = {}
  for _, v in ipairs(src or {}) do out[v] = true end
  return out
end

local CLASSIC_DUNGEONS = {
  "Blackfathom Deeps", "Blackrock Depths", "Deadmines", "Dire Maul",
  "Gnomeregan", "Lower Blackrock Spire", "Maraudon", "Ragefire Chasm",
  "Razorfen Downs", "Razorfen Kraul", "Scarlet Monastery",
  "Shadowfang Keep", "Stormwind Stockade", "Stratholme", "Sunken Temple",
  "Uldaman", "Upper Scholomance", "Wailing Caverns", "Zul'Farrak",
}

local TBC_DUNGEONS = {
  "Auchenai Crypts", "The Arcatraz", "The Black Morass", "Blood Furnace",
  "Hellfire Ramparts", "Magisters' Terrace", "Mana-Tombs",
  "Old Hillsbrad Foothills", "Sethekk Halls", "Shadow Labyrinth",
  "Shattered Halls", "The Botanica", "The Mechanar", "The Slave Pens",
  "The Steamvault", "The Underbog",
}

local WRATH_DUNGEONS = {
  "Ahn'kahet: The Old Kingdom", "Azjol-Nerub", "Culling of Stratholme",
  "Drak'Tharon Keep", "Forge of Souls", "Gundrak",
  "Halls of Lightning", "Halls of Reflection", "Halls of Stone",
  "The Nexus", "The Oculus", "Pit of Saron", "Trial of the Champion",
  "Utgarde Keep", "Utgarde Pinnacle", "Violet Hold",
}

local CLASSIC_RAIDS = {
  "Zul'Gurub", "Onyxia", "Molten Core", "Blackwing Lair",
  "Ruins of Ahn'Qiraj", "Temple of Ahn'Qiraj", "Naxxramas",
}

local TBC_RAIDS = {
  "Karazhan", "Gruul's Lair", "Magtheridon's Lair",
  "Serpentshrine Cavern", "Tempest Keep", "Battle for Mount Hyjal",
  "Black Temple", "Sunwell Plateau",
}

local WRATH_RAIDS = {
  "Vault of Archavon", "The Obsidian Sanctum", "The Eye of Eternity",
  "Ulduar", "Trial of the Crusader", "Icecrown Citadel", "The Ruby Sanctum",
}

local TRIUMVIRATE_KEYS = {
  "Utgarde Keep", "Drak'Tharon Keep", "Gundrak", "The Nexus",
  "Hellfire Ramparts", "The Slave Pens", "The Botanica", "Mana-Tombs",
}

local ASCENSION_KEYS = {
  "Wailing Caverns", "Deadmines", "Shadowfang Keep", "Blackfathom Deeps",
  "Razorfen Kraul", "Razorfen Downs", "Scarlet Monastery", "Zul'Farrak",
  "Maraudon", "Blackrock Depths", "Dire Maul",
}

local SHARED_ACTIVITY_ALIASES = {
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
  {"Dire Maul", {"dire maul", "diremaul"}},
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
  {"Zul'Farrak", {"zul'farrak", "zulfarrak", " zf ", "zf hc"}},
  {"Vaults of Inquisition", {"vaults of inquisition", "vaults", "voi"}},
  {"Road to De Other Side", {"road to de other side", "roads", "rdos"}},
  {"Molten Core", {" mc ", "molten core", "molten"}},
  {"Blackwing Lair", {"bwl", "blackwing lair", "blackwing", "nefarian", "nef"}},
  {"Zul'Gurub", {"zg", "zul'gurub", "zulgurub"}},
  {"Ruins of Ahn'Qiraj", {"aq20", "ruins of ahn'qiraj", "ruins of ahnqiraj", "ruins aq", "raq"}},
  {"Temple of Ahn'Qiraj", {"aq40", "temple of ahn'qiraj", "temple of ahnqiraj", "temple aq", "taq"}},
  {"Naxxramas", {"naxx", "naxxramas"}},
  {"Onyxia", {"ony", "onyxia"}},
  {"Karazhan", {" kara ", "karazhan"}},
  {"Icecrown Citadel", {" icc ", "icecrown citadel"}},
}

local ASCENSION_ACTIVITY_ALIASES = copyList(SHARED_ACTIVITY_ALIASES)

local TRIUMVIRATE_DUNGEONS = copyList(CLASSIC_DUNGEONS)
for _, v in ipairs(TBC_DUNGEONS) do table.insert(TRIUMVIRATE_DUNGEONS, v) end
for _, v in ipairs(WRATH_DUNGEONS) do table.insert(TRIUMVIRATE_DUNGEONS, v) end

local TRIUMVIRATE_RAIDS = copyList(CLASSIC_RAIDS)
for _, v in ipairs(TBC_RAIDS) do table.insert(TRIUMVIRATE_RAIDS, v) end
for _, v in ipairs(WRATH_RAIDS) do table.insert(TRIUMVIRATE_RAIDS, v) end

SignalFireProfiles.Triumvirate = {
  id = "Triumvirate",
  label = "Triumvirate",
  features = {
    rdf = true, tbc = true, wrath = true, seasonOneKeys = true,
    ascended = false, mythicPlus = false,
  },
  activityTypes = {"Dungeon", "Raid", "World Boss", "Custom Event"},
  difficulties = {"Normal", "Heroic", "Mythic", "Mythic+", "Custom"},
  dungeons = TRIUMVIRATE_DUNGEONS,
  classicDungeons = CLASSIC_DUNGEONS,
  tbcDungeons = TBC_DUNGEONS,
  wrathDungeons = WRATH_DUNGEONS,
  raids = TRIUMVIRATE_RAIDS,
  worldBosses = {"Custom World Boss", "Xiah", "Yuna", "Xyo"},
  keys = TRIUMVIRATE_KEYS,
  keyAlertOptions = {"Any Key", "Utgarde Keep", "Drak'Tharon Keep", "Gundrak", "Nexus", "Hellfire Ramparts", "The Slave Pens", "The Botanica", "Mana-Tombs"},
  dungeonActivities = makeSet(TRIUMVIRATE_DUNGEONS),
  raidActivities = makeSet(TRIUMVIRATE_RAIDS),
  activityAliases = SHARED_ACTIVITY_ALIASES,
  rdfAliases = {
    default = "Random Dungeon Finder",
    tbc = "BC Random Dungeon Finder",
    wrath = "Wrath Random Dungeon Finder",
    tbcTokens = {"bc", "tbc", "outland"},
    wrathTokens = {"wrath", "wotlk", "northrend"},
  },
}

SignalFireProfiles.Ascension = {
  id = "Ascension",
  label = "Ascension",
  features = {
    rdf = false, tbc = false, wrath = false, seasonOneKeys = false,
    ascended = true, mythicPlus = true,
  },
  activityTypes = {"Dungeon", "Raid", "World Boss", "Custom Event"},
  difficulties = {"Normal", "Heroic", "Mythic", "Mythic+", "Ascended", "Custom"},
  dungeons = CLASSIC_DUNGEONS,
  classicDungeons = CLASSIC_DUNGEONS,
  tbcDungeons = {},
  wrathDungeons = {},
  raids = CLASSIC_RAIDS,
  worldBosses = {"Custom World Boss"},
  keys = ASCENSION_KEYS,
  keyAlertOptions = {"Any Keystone", "Wailing Caverns", "Deadmines", "Shadowfang Keep", "Blackfathom Deeps", "Razorfen Kraul", "Razorfen Downs", "Scarlet Monastery", "Zul'Farrak", "Maraudon", "Blackrock Depths", "Dire Maul"},
  dungeonActivities = makeSet(CLASSIC_DUNGEONS),
  raidActivities = makeSet(CLASSIC_RAIDS),
  activityAliases = ASCENSION_ACTIVITY_ALIASES,
  focusAliases = {
    ascended = {"ascended", " asc ", "ascension", "wildcard", "mystic enchant", "enchants", "builds"},
    mythicPlus = {"mythic+", "m+", "mythic plus", "keystone", "keystones", "key", "keys"},
  },
}

function SignalFireProfiles.GetActiveProfile()
  local id = "Triumvirate"
  if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
    id = tostring(BronzeLFG_DB.options.serverProfile or id)
  end
  return SignalFireProfiles[id] or SignalFireProfiles.Triumvirate
end

function SignalFireProfiles.GetList(name)
  local p = SignalFireProfiles.GetActiveProfile()
  return (p and p[name]) or {}
end

function SignalFireProfiles.GetSet(name)
  local p = SignalFireProfiles.GetActiveProfile()
  return (p and p[name]) or {}
end
