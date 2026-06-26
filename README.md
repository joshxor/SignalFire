# SignalFire
A WotLK 3.3.5 guild, group, recruitment, and invasion coordination addon for the Triumvirate realm.
# SignalFire

**SignalFire** is a WotLK 3.3.5 addon for the Triumvirate realm, built to help players coordinate guild recruitment, public groups, dungeon runs, raids, world boss events, and invasion activity through a cleaner addon-powered interface.

SignalFire keeps the stable BronzeLFG addon core internally for compatibility while presenting a Triumvirate-focused SignalFire experience in-game.

---

## Current Version

**v1.3.4a — Performance + Recruitment Broadcast Hotfix**

This version includes a targeted Guild Browser performance fix and a Recruitment Post Creator broadcast improvement for the WoW 255-character chat limit.

---

## Features

### Guild Browser

* Tracks guild recruitment messages from chat.
* Displays guild listings in a dedicated browser.
* Supports recruitment details, focus tags, Discord/link fields, and seen-player information.
* Keeps SignalFire Network guild activity visible in one place.

### Recruitment Post Creator

* Create polished guild recruitment posts from an in-game UI.
* Save and reload your recruitment profile.
* Publish full listings to the Guild Browser.
* Broadcast a 255-character-safe chat version while preserving full listing details in the addon.

### Public Groups

* Detects LFG/LFM-style chat posts.
* Organizes public group listings by activity type.
* Supports dungeon, raid, key, world boss, event, social, and LFG-style posts.
* Adds clickable SignalFire-enhanced links for users with the addon.

### SignalFire Network

* Shows other SignalFire users.
* Merges addon users with visible guild/player activity where supported.
* Helps players find active guilds and groups more easily.

### Invasion Assist

* Tracks known Triumvirate invasion hubs.
* Displays invasion location information.
* Includes nearby-player and manual invite helper tools.

---

## Installation

1. Download the latest SignalFire release zip.
2. Extract the folder.
3. Place the `SignalFire` folder into:

```text
World of Warcraft/Interface/AddOns/
```

4. Restart the game or type:

```text
/reload
```

5. Open SignalFire in-game using:

```text
/sf
```

---

## Common Commands

```text
/sf
/blfg
/sf public
/sf guild
/sf invasions
/sfparse
```

---

## Latest Update — v1.3.4a

### Fixed

* Fixed a hidden Guild Browser refresh issue that could continue using CPU after the Guild Browser tab had been opened once.
* Replaced background Guild Browser refresh checks with true visibility checks.
* Reduced micro-stutter and FPS drops tied to opening and closing the Guild Browser.
* Updated Recruitment Post Creator broadcasts to respect the WoW 255-character chat limit.
* Broadcast now prioritizes the player-written recruitment pitch instead of forcing the full preview text into chat.
* Discord/link info is preserved in the Guild Browser listing and only added to chat if it fits.
* Broadcast now reports the sent message length, such as `243/255`.

### Preserved

* Existing Guild Browser behavior.
* Existing clickable chat-link behavior.
* Existing Public Groups behavior.
* Existing Recruitment Creator preview/listing behavior.
* Existing Invasion Assist behavior.
* Existing SignalFire Network behavior.

---

## Compatibility

SignalFire is designed for:

```text
World of Warcraft Wrath 3.3.5
Triumvirate realm
Lua 5.1 / WoW addon environment
```

Internal globals and SavedVariables intentionally remain based on the original BronzeLFG structure for compatibility:

```text
BronzeLFG
BLFG
BronzeLFG_DB
```

---

## Project Layout

```text
SignalFire.toc                    Addon load order and metadata
BronzeLFG.lua                     Main addon engine and UI logic
SignalFireProfile.lua             Triumvirate profile data and activity aliases
SignalFireParserTightening.lua    Parser refinements for Triumvirate chat patterns
SignalFire_Invasions.lua          Invasion hub database
SignalFireCompat.lua              SignalFire branding and compatibility layer
README.md                         Project overview
CHANGELOG.md                      Version history
docs/                             Extra documentation
images/                           Screenshots and preview images
releases/                         Optional release zip archive copies
```

---

## Known Notes

* SignalFire users see enhanced clickable chat links locally.
* Non-SignalFire users see normal chat.
* Broadcasted recruitment chat is kept within the WoW chat limit when possible.
* Full recruitment details are preserved in the addon UI instead of being forced into one chat message.

---

## Future Ideas

* Add support for Triumvirate’s dedicated guild recruitment channel as a preferred Recruitment Post Creator broadcast target.
* Add a channel preference dropdown for recruitment broadcasts.
* Add optional chat-link display modes.
* Continue parser tuning for Triumvirate-specific dungeon, raid, world boss, and recruitment language.
* Add more screenshots and visual documentation.

---

## Maintainer

Created and maintained for the Triumvirate community by **hs0j**.
