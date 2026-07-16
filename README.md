# SignalFire

SignalFire is a group-discovery and community coordination addon for World of Warcraft 3.3.5, with dedicated profiles for:

- Ascension / Conquest of Azeroth
- Triumvirate

SignalFire turns fast-moving public chat into organized listings for dungeons, raids, random dungeon finder groups, Mythic+, world bosses, guild recruitment, and community activities. It also includes tools for creating listings, handling applicants, discovering other SignalFire users, following favorites, and organizing events and notices.

**Current release: 1.5.1**

[Download SignalFire on CurseForge](https://www.curseforge.com/wow/addons/signalfire)

## What's New in 1.5.1

- Improved activity-link coverage across multiple chat windows and tabs.
- Added exact Public Groups selection when an activity link is clicked.
- Expanded recognition for RDF, dungeon shorthand, role-first messages, and Ascension activities.
- Added Random Dungeon Finder, Random Heroic Dungeon Finder, and Random Mythic Dungeon Finder listing options.
- Corrected listing ages and Ascension custom class names.
- Reduced duplicate parsing, listings, alerts, and Network refreshes.
- Disabled unsupported Invasion listeners outside an enabled Triumvirate profile.
- Removed unnecessary hidden-panel polling and recurring UI scans.
- Added bounded caches, batched refreshes, and deferred chat processing.
- Expanded the built-in parser regression suite to 33 cases.

## Features

### Public Groups

- Detects supported group advertisements from public chat.
- Recognizes dungeons, raids, RDF, Mythic+, Ascended raids, world bosses, roles, and common shorthand.
- Adds clickable activity links that open and highlight the matching listing.
- Provides search, filters, paging, duplicate control, and automatic expiration.
- Separates guild recruitment from players who are simply looking for a guild.

### Create Listing

- Creates dungeon, raid, Mythic+, RDF, world boss, and custom listings.
- Supports Normal, Heroic, Mythic+, and Ascended difficulty where available.
- Tracks requested roles, key level, item level, group size, and notes.
- Includes posting previews, rebroadcasting, applicant management, and cancellation.
- Hides individual dungeon selection for random dungeon finder activities.

### Guilds and Community

- Guild Browser with recruitment detection and guild details.
- Recruitment Creator with reusable guild advertisements.
- Community Event Board and Notice Board.
- Favorite-player, activity, listing, and event alerts.

### SignalFire Network

- Discovers other active SignalFire users.
- Includes Network and Full Roster views, player details, favorites, and quick actions.
- Supports manual refresh and optional 15, 30, or 60-second auto-refresh.
- Displays Ascension custom class names supplied by each player's client.

### Server Profiles

- Separate settings and activity data for Ascension / CoA and Triumvirate.
- Profile-aware module availability and discovery behavior.
- Ascension disables unsupported invasion and `/who` systems.
- Triumvirate retains supported Invasions and `/who` enhancements.

### Interface and Customization

- Profile-aware Modules manager.
- 90%, 100%, 110%, and 120% interface scaling.
- Persistent window position and profile-specific settings.
- Searchable, filterable, and paged list views.
- Configurable chat-link scope, strict parsing, favorites, alerts, and Network refresh intervals.

## Commands

- `/sf` opens SignalFire.
- `/sf public` opens Public Groups.
- `/sf guild` opens the Guild Browser.
- `/sfparse` opens the parser regression tests.

## Installation

1. Fully close World of Warcraft.
2. Delete any existing `Interface\AddOns\SignalFire` folder.
3. Extract the latest release into `Interface\AddOns`.
4. Confirm the final path is `Interface\AddOns\SignalFire\SignalFire.toc`.
5. Launch the game and use `/sf` to open SignalFire.

Do not overwrite an older SignalFire installation.

## Compatibility

- World of Warcraft 3.3.5
- Ascension / Conquest of Azeroth
- Triumvirate
- Lua 5.1 / Wrath addon environment

SignalFire retains the `BronzeLFG`, `BLFG`, and `BronzeLFG_DB` names internally for SavedVariables and compatibility with established addon data.

## Repository Layout

- `SignalFire/` contains the complete addon source and TOC.
- `CHANGELOG.md` contains user-facing release history.
- `.github/workflows/release.yml` validates and packages the addon.

Pushing changes to `main` builds an installable ZIP as a workflow artifact. Pushing a version tag such as `v1.5.1` also publishes that ZIP and its SHA-256 checksum as GitHub release assets.

## Known Limitation

Some Ascension / CoA clients may experience intermittent micro-stutter while custom SignalFire links are visible during very busy public chat. Players can reduce the impact by selecting **Main Chat Only** or **Visible Chat Frames**, or by disabling visible links while keeping Public Groups parsing enabled.

## Support

When reporting a problem, include the active server profile, the SignalFire version, what was happening when the issue occurred, and any Lua error shown by the client.

**SignalFire. Lighting the Path to Adventure.**
