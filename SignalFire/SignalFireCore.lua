-- SignalFire 1.5.1
-- Runtime modules are grouped by subsystem; initialization order is preserved.

-- Version
do
  repeat
    SignalFire_VERSION = "1.5.1"
    SignalFire_RELEASE_CHANNEL = "stable"
    SignalFire_RELEASE_NAME = "SignalFire 1.5.1"

    function SignalFire_GetVersion()
      return tostring(SignalFire_VERSION or "1.5.1")
    end

    function SignalFire_GetTitleText()
      return "SignalFire v" .. SignalFire_GetVersion() .. " (Beta)"
    end

    function SignalFire_GetProfileDisplayName(profile, compact)
      profile = tostring(profile or "")
      local lower = string.lower(profile)
      if lower == "ascension" or lower == "bronzebeard" or lower == "coa" or lower == "conquest of azeroth" then
        if compact == false then return "Ascension / Bronzebeard / CoA" end
        return "Ascension / CoA"
      end
      if lower == "triumvirate" then return "Triumvirate" end
      if profile ~= "" then return profile end
      return ""
    end

    function SignalFire_GetVersionLabel(profile)
      local v = SignalFire_GetVersion()
      local label = SignalFire_GetProfileDisplayName(profile, true)
      if label ~= "" then return "v" .. v .. " - " .. label end
      return "v" .. v
    end

    local function sfv_profile_id()
      if BronzeLFG and BronzeLFG.SF143_GetProfileId then
        local ok, id = pcall(function() return BronzeLFG:SF143_GetProfileId() end)
        if ok and id and tostring(id) ~= "" then return tostring(id) end
      end
      if BronzeLFG_DB and BronzeLFG_DB.options and BronzeLFG_DB.options.serverProfile then
        return tostring(BronzeLFG_DB.options.serverProfile or "")
      end
      return ""
    end

    function BronzeLFG_GetVisibleVersionLabel()
      return SignalFire_GetVersionLabel(sfv_profile_id())
    end

    -- The main title is the only visible version owner. The inherited versionText
    -- and the abandoned 1.4.34 badge are always suppressed so refresh paths cannot
    -- create a second, flashing identity element.
    function BronzeLFG_ApplyVisibleVersion()
      if not BronzeLFG then return end
      BronzeLFG.version = SignalFire_GetVersion()
      BronzeLFG.SignalFireVisibleVersion = SignalFire_GetVersion()
      if BronzeLFG.titleText and BronzeLFG.titleText.SetText then
        BronzeLFG.titleText:SetText(SignalFire_GetTitleText())
        if BronzeLFG.titleText.Show then BronzeLFG.titleText:Show() end
        if BronzeLFG.titleText.SetAlpha then BronzeLFG.titleText:SetAlpha(1) end
      end
      if BronzeLFG.versionText then
        if BronzeLFG.versionText.SetText then BronzeLFG.versionText:SetText("") end
        if BronzeLFG.versionText.SetAlpha then BronzeLFG.versionText:SetAlpha(0) end
        if BronzeLFG.versionText.Hide then BronzeLFG.versionText:Hide() end
      end
      if BronzeLFG.sfui1434VersionBadge then
        if BronzeLFG.sfui1434VersionBadge.Hide then BronzeLFG.sfui1434VersionBadge:Hide() end
        if BronzeLFG.sfui1434VersionBadge.SetAlpha then BronzeLFG.sfui1434VersionBadge:SetAlpha(0) end
      end
      if BronzeLFG.sfui1434VersionBadgeText and BronzeLFG.sfui1434VersionBadgeText.SetText then
        BronzeLFG.sfui1434VersionBadgeText:SetText("")
      end
    end
  until true
end

-- Profiles
do
  repeat
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
    -- Ascension/CoA chat shorthand. These remain profile-specific so "vault" does
    -- not hijack similarly named content on Triumvirate or other realms.
    table.insert(ASCENSION_ACTIVITY_ALIASES, {"Vaults of Inquisition", {"vault", "vault dungeon"}})
    table.insert(ASCENSION_ACTIVITY_ALIASES, {"Road to De Other Side", {"de other side", "da other side", "de otha side", "da otha side", "the other side", "other side", "dos"}})

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
      activityTypes = {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"},
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


    -- ============================================================
    -- SignalFire 1.4.3 - Ascension / Triumvirate profile data pass
    -- Keeps the original BronzeLFG Ascension-era activity pool available while
    -- letting Triumvirate keep its RDF + Classic/TBC/Wrath mode layout.
    -- ============================================================

    do
      local function sf143_copy(src)
        local out = {}
        for i, v in ipairs(src or {}) do out[i] = v end
        return out
      end

      local function sf143_set(src)
        local out = {}
        for _, v in ipairs(src or {}) do out[v] = true end
        return out
      end

      local ASCENSION_DUNGEONS_143 = {
        "Blackfathom Deeps",
        "Blackrock Caverns",
        "Blackrock Depths - Manufacturing",
        "Blackrock Depths - Prison",
        "Blackrock Depths - Upper City",
        "Deadmines",
        "Dire Maul - East",
        "Dire Maul - North",
        "Dire Maul - West",
        "Gnomeregan",
        "Lower Blackrock Spire",
        "Lower Scholomance",
        "Maraudon - Orange Crystals",
        "Maraudon - Pristine Waters",
        "Maraudon - Purple Crystals",
        "Ragefire Chasm",
        "Razorfen Downs",
        "Razorfen Kraul",
        "Road to De Other Side",
        "Scarlet Monastery - Armory",
        "Scarlet Monastery - Cathedral",
        "Scarlet Monastery - Graveyard",
        "Scarlet Monastery - Library",
        "Shadowfang Keep",
        "Shadowfang Keep - Arugal's Rise",
        "Shadowfang Keep - Halls of the Fallen",
        "Stormwind Stockade",
        "Stratholme - Main Gate",
        "Stratholme - Service Entrance",
        "Sunken Temple",
        "Uldaman",
        "Upper Scholomance",
        "Vaults of Inquisition",
        "Wailing Caverns",
        "Wailing Caverns - Crag of the Everliving",
        "Wailing Caverns - Pit of the Fang",
        "Zul'Farrak",
      }

      local ASCENSION_RAIDS_143 = {
        "Zul'Gurub",
        "Onyxia",
        "Molten Core",
        "Blackwing Lair",
      }

      local ASCENSION_WORLDBOSSES_143 = {
        "Custom World Boss",
        "Azuregos",
        "Lord Kazzak",
        "Dragons of Nightmare",
      }

      -- Keep Ascension/CoA creation usable: the final listing still broadcasts the
      -- exact dungeon, but the Activity dropdown is grouped into short categories.
      local ASCENSION_STANDARD_DUNGEONS_143 = {
        "Blackfathom Deeps",
        "Blackrock Caverns",
        "Deadmines",
        "Gnomeregan",
        "Lower Blackrock Spire",
        "Ragefire Chasm",
        "Razorfen Downs",
        "Razorfen Kraul",
        "Shadowfang Keep",
        "Stormwind Stockade",
        "Sunken Temple",
        "Uldaman",
        "Upper Scholomance",
        "Zul'Farrak",
      }

      local ASCENSION_BRD_WINGS_143 = {
        "Blackrock Depths - Prison",
        "Blackrock Depths - Manufacturing",
        "Blackrock Depths - Upper City",
      }

      local ASCENSION_DIRE_MAUL_WINGS_143 = {
        "Dire Maul - East",
        "Dire Maul - North",
        "Dire Maul - West",
      }

      local ASCENSION_MARAUDON_WINGS_143 = {
        "Maraudon - Orange Crystals",
        "Maraudon - Pristine Waters",
        "Maraudon - Purple Crystals",
      }

      local ASCENSION_SCARLET_WINGS_143 = {
        "Scarlet Monastery - Armory",
        "Scarlet Monastery - Cathedral",
        "Scarlet Monastery - Graveyard",
        "Scarlet Monastery - Library",
      }

      local ASCENSION_SFK_WINGS_143 = {
        "Shadowfang Keep - Arugal's Rise",
        "Shadowfang Keep - Halls of the Fallen",
      }

      local ASCENSION_STRATHOLME_WINGS_143 = {
        "Stratholme - Main Gate",
        "Stratholme - Service Entrance",
      }

      local ASCENSION_WAILING_WINGS_143 = {
        "Wailing Caverns - Crag of the Everliving",
        "Wailing Caverns - Pit of the Fang",
      }

      local ASCENSION_CUSTOM_DUNGEONS_143 = {
        "Road to De Other Side",
        "Vaults of Inquisition",
      }

      local ASCENSION_DUNGEON_MODES_143 = {
        "Ascension: Standard Dungeons",
        "Ascension: BRD Wings",
        "Ascension: Dire Maul Wings",
        "Ascension: Maraudon Wings",
        "Ascension: Scarlet Monastery Wings",
        "Ascension: Shadowfang Keep Wings",
        "Ascension: Stratholme Wings",
        "Ascension: Wailing Caverns Wings",
        "Ascension: Custom Dungeons",
      }

      local ASCENSION_DUNGEON_MODE_LISTS_143 = {
        ["Ascension: Standard Dungeons"] = ASCENSION_STANDARD_DUNGEONS_143,
        ["Ascension: BRD Wings"] = ASCENSION_BRD_WINGS_143,
        ["Ascension: Dire Maul Wings"] = ASCENSION_DIRE_MAUL_WINGS_143,
        ["Ascension: Maraudon Wings"] = ASCENSION_MARAUDON_WINGS_143,
        ["Ascension: Scarlet Monastery Wings"] = ASCENSION_SCARLET_WINGS_143,
        ["Ascension: Shadowfang Keep Wings"] = ASCENSION_SFK_WINGS_143,
        ["Ascension: Stratholme Wings"] = ASCENSION_STRATHOLME_WINGS_143,
        ["Ascension: Wailing Caverns Wings"] = ASCENSION_WAILING_WINGS_143,
        ["Ascension: Custom Dungeons"] = ASCENSION_CUSTOM_DUNGEONS_143,
      }

      local ASCENSION_DUNGEON_ALERT_OPTIONS_143 = {"Any Dungeon"}
      for _, v in ipairs(ASCENSION_DUNGEON_MODES_143) do table.insert(ASCENSION_DUNGEON_ALERT_OPTIONS_143, v) end

      local ASCENSION_DUNGEON_ALERT_ALIASES_143 = {}
      for mode, list in pairs(ASCENSION_DUNGEON_MODE_LISTS_143) do ASCENSION_DUNGEON_ALERT_ALIASES_143[mode] = list end

      local ASCENSION_ALIASES_143 = sf143_copy(SHARED_ACTIVITY_ALIASES)
      local function sf143_alias(name, tokens)
        table.insert(ASCENSION_ALIASES_143, {name, tokens})
      end
      sf143_alias("Blackrock Depths - Manufacturing", {"brd manufacturing", "manufacturing"})
      sf143_alias("Blackrock Depths - Prison", {"brd prison", "prison"})
      sf143_alias("Blackrock Depths - Upper City", {"brd upper", "upper city"})
      sf143_alias("Dire Maul - East", {"dire maul east", "dm east", "dme"})
      sf143_alias("Dire Maul - North", {"dire maul north", "dm north", "dmn"})
      sf143_alias("Dire Maul - West", {"dire maul west", "dm west", "dmw"})
      sf143_alias("Lower Scholomance", {"lower scholomance", "lower scholo", "l scholo"})
      sf143_alias("Maraudon - Orange Crystals", {"mara orange", "orange crystals"})
      sf143_alias("Maraudon - Pristine Waters", {"mara princess", "mara water", "pristine waters", "pristine"})
      sf143_alias("Maraudon - Purple Crystals", {"mara purple", "purple crystals"})
      sf143_alias("Scarlet Monastery - Armory", {"sm armory", "sm arm", "smarm", "scarlet monastery armory", "armory"})
      sf143_alias("Scarlet Monastery - Cathedral", {"sm cath", "smcath", "sm cathedral", "scarlet monastery cathedral", "cathedral", "cath"})
      sf143_alias("Scarlet Monastery - Graveyard", {"sm gy", "smgy", "sm grave", "sm graveyard", "scarlet monastery graveyard", "graveyard"})
      sf143_alias("Scarlet Monastery - Library", {"sm lib", "smlib", "sm library", "scarlet monastery library", "biblioteca", "library"})
      sf143_alias("Shadowfang Keep - Arugal's Rise", {"arugal's rise", "arugals rise", "sfk arugal", "arugal"})
      sf143_alias("Shadowfang Keep - Halls of the Fallen", {"halls of the fallen", "sfk halls", "fallen"})
      sf143_alias("Stratholme - Main Gate", {"stratholme main", "strat main", "strat live", "strat living"})
      sf143_alias("Stratholme - Service Entrance", {"stratholme service", "strat service", "strat ud", "strat undead"})
      sf143_alias("Wailing Caverns - Crag of the Everliving", {"crag of the everliving", "wc crag", "everliving"})
      sf143_alias("Wailing Caverns - Pit of the Fang", {"pit of the fang", "wc pit", "fang"})
      sf143_alias("Vaults of Inquisition", {"vaults of inquisition", "vaults", "voi", "vault", "vault dungeon"})
      sf143_alias("Road to De Other Side", {"road to de other side", "road to da other side", "roads", "rdos", "de other side", "da other side", "de otha side", "da otha side", "the other side", "other side", "dos"})

      if SignalFireProfiles and SignalFireProfiles.Triumvirate then
        SignalFireProfiles.Triumvirate.useDungeonModes = true
        SignalFireProfiles.Triumvirate.basicDungeonDifficulties = {"Normal", "Heroic"}
        SignalFireProfiles.Triumvirate.dungeonDifficulties = {"Normal", "Heroic", "Mythic+"}
        SignalFireProfiles.Triumvirate.raidDifficulties = {"Normal", "Heroic"}
        SignalFireProfiles.Triumvirate.raidAlertOptions = {"Any Raid", "Zul'Gurub", "Onyxia", "Molten Core", "Blackwing Lair", "AQ20", "AQ40", "Naxxramas", "Karazhan", "Ulduar", "Icecrown Citadel"}
      end

      SignalFireProfiles.Ascension = {
        id = "Ascension",
        label = "Ascension / Bronzebeard / CoA",
        useDungeonModes = true,
        features = {
          rdf = false, tbc = false, wrath = false, seasonOneKeys = false,
          ascended = true, mythicPlus = true,
        },
        activityTypes = {"Dungeon", "Mythic+", "Raid", "World Boss", "Custom Event"},
        difficulties = {"Normal", "Heroic", "Mythic", "Mythic+", "Ascended", "Custom"},
        basicDungeonDifficulties = {"Normal", "Heroic"},
        dungeonDifficulties = {"Normal", "Heroic", "Mythic+"},
        raidDifficulties = {"Normal", "Heroic", "Ascended"},
        dungeons = ASCENSION_DUNGEONS_143,
        dungeonActivityModes = ASCENSION_DUNGEON_MODES_143,
        dungeonModeLists = ASCENSION_DUNGEON_MODE_LISTS_143,
        dungeonAlertOptions = ASCENSION_DUNGEON_ALERT_OPTIONS_143,
        dungeonAlertAliases = ASCENSION_DUNGEON_ALERT_ALIASES_143,
        classicDungeons = ASCENSION_DUNGEONS_143,
        tbcDungeons = {},
        wrathDungeons = {},
        raids = ASCENSION_RAIDS_143,
        worldBosses = ASCENSION_WORLDBOSSES_143,
        keys = ASCENSION_DUNGEONS_143,
        keyAlertOptions = (function()
          local t = {"Any Keystone"}
          for _, v in ipairs(ASCENSION_DUNGEONS_143) do table.insert(t, v) end
          return t
        end)(),
        raidAlertOptions = {"Any Raid", "Zul'Gurub", "Onyxia", "Molten Core", "Blackwing Lair"},
        dungeonActivities = sf143_set(ASCENSION_DUNGEONS_143),
        raidActivities = sf143_set(ASCENSION_RAIDS_143),
        activityAliases = ASCENSION_ALIASES_143,
        focusAliases = {
          ascended = {"ascended", " asc ", "ascension", "wildcard", "mystic enchant", "enchants", "builds"},
          mythicPlus = {"mythic+", "m+", "mythic plus", "keystone", "keystones", "key", "keys"},
        },
      }
    end


    do
      local SF143_PreviousGetActiveProfile = SignalFireProfiles and SignalFireProfiles.GetActiveProfile
      local function sf143_lower(s) return string.lower(tostring(s or "")) end
      local function sf143_detect_profile()
        local realm = GetRealmName and sf143_lower(GetRealmName() or "") or ""
        if string.find(realm, "triumvirate", 1, true) then return "Triumvirate" end
        if string.find(realm, "bronzebeard", 1, true) or string.find(realm, "conquest", 1, true) or string.find(realm, "azeroth", 1, true) or string.find(realm, "ascension", 1, true) or string.find(realm, "vol'jin", 1, true) or string.find(realm, "voljin", 1, true) then return "Ascension" end
        return "Triumvirate"
      end
      function SignalFireProfiles.GetActiveProfile()
        local id = nil
        if BronzeLFG_DB and BronzeLFG_DB.options then id = BronzeLFG_DB.options.serverProfile end
        id = tostring(id or "")
        if id == "" or id == "Auto" then id = sf143_detect_profile() end
        if SignalFireProfiles[id] then return SignalFireProfiles[id] end
        if SF143_PreviousGetActiveProfile then
          local p = SF143_PreviousGetActiveProfile()
          if p then return p end
        end
        return SignalFireProfiles.Triumvirate
      end
    end
  until true
end
