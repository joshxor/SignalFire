# SignalFire

SignalFire is a group-discovery and community coordination addon for World of Warcraft 3.3.5, with dedicated profiles for **Ascension / Conquest of Azeroth** and **Triumvirate**.

It turns fast-moving public chat into organized listings for dungeons, raids, random dungeon finder groups, Mythic+, world bosses, guild recruitment, and community activities. SignalFire also includes listing and applicant tools, a user Network and Full Roster, favorites, community events, notices, and profile-aware modules.

**Current release: 1.5.1**

[Download SignalFire on CurseForge](https://www.curseforge.com/wow/addons/signalfire)

## Highlights

- Public Groups parsing for supported group and guild advertisements.
- Exact activity and role detection with search, filters, paging, and expiration.
- Optional SignalFire chat links that open and highlight the matching listing.
- Random Normal, Heroic, and Mythic Dungeon Finder listing flows.
- Dungeon, raid, Mythic+, Ascended, world boss, and custom listing tools.
- Applicant management, rebroadcasting, listing updates, and cancellation.
- Network and Full Roster views with favorites and Ascension custom classes.
- Guild Browser, Recruitment Creator, Community Events, and Notice Board.
- Separate Ascension/CoA and Triumvirate settings and module availability.
- 90%, 100%, 110%, and 120% interface scaling.

## What Changed in 1.5.1

- Improved chat classification, exact link targeting, RDF shorthand, and role-first messages.
- Added Random Dungeon Finder, Random Heroic Dungeon Finder, and Random Mythic Dungeon Finder listing options.
- Corrected listing ages and Ascension custom class display.
- Reduced repeated parsing, refreshes, hidden work, recursive UI scans, and unnecessary timers.
- Added cached Network, roster, Public Groups, and Browse views with bounded session caches.
- Added lazy panel construction and incremental visible-row rendering.
- Improved SavedVariables repair and profile-safe module migration.
- Added opt-in stability and ownership diagnostics.
- Changed **Chat Links to Off by default** for fresh installations and missing legacy preferences. Public Groups parsing remains active, and existing explicit On or Off choices are preserved.

## Chat Links

SignalFire continues to parse eligible chat and populate Public Groups while Chat Links are Off. Enable links manually under **Options > Chat & Parsing** when you want clickable activity and guild links.

Available scopes are Main Chat Only, Visible Chat Frames, and All Chat Frames. All Chat Frames provides the broadest coverage; lighter scopes may reduce custom-link rendering work on affected Ascension clients.

## Commands

- `/sf` opens SignalFire.
- `/sf public` opens Public Groups.
- `/sf guild` opens the Guild Browser.
- `/sfparse` opens the parser regression tests.
- `/sf diag start` begins session-only stability diagnostics.
- `/sf diag report` prints a diagnostic report.
- `/sf diag stop` disables diagnostics.
- `/sf diag` lists the remaining diagnostic commands.

Diagnostics and deep traces are disabled by default and are not saved between sessions.

## Installation

1. Fully exit World of Warcraft.
2. Delete the existing `Interface\AddOns\SignalFire` addon folder.
3. Extract the release into `Interface\AddOns`.
4. Confirm the final path is `Interface\AddOns\SignalFire\SignalFire.toc`.
5. Launch the game and use `/sf` to open SignalFire.

Deleting the addon folder does not delete `BronzeLFG_DB`; normal upgrades preserve settings. Do not overwrite an older addon folder because removed or renamed files can remain behind.

## Compatibility

- World of Warcraft 3.3.5 build 12340 / Lua 5.1
- Ascension / Conquest of Azeroth
- Triumvirate

SignalFire retains the internal `BronzeLFG`, `BLFG`, and `BronzeLFG_DB` names for SavedVariables and compatibility with established data.

## Known Limitations

- Some Ascension/CoA clients may experience intermittent micro-stutter while custom SignalFire links are visible during very busy chat. Chat Links now default Off as a safety measure. This does not disable Public Groups parsing.
- The first Public Groups link click can briefly pause while that panel is constructed for the first time. Reopening it is substantially faster.
- The current testing optimized known measured hotspots, but it does not establish that every FPS issue or client crash is fixed.

## Troubleshooting

1. Confirm Chat Links are Off under **Options > Chat & Parsing**.
2. Run `/sf diag start`.
3. Reproduce the problem briefly.
4. Run `/sf diag report`, then `/sf diag stop`.
5. Include the output, addon list, server profile, and any Lua error in the report.

As a controlled file test, fully exit WoW and temporarily rename both `BronzeLFG.lua` and any `BronzeLFG.lua.bak` found in the SignalFire folder, then restore them before normal play. Resetting `BronzeLFG_DB` resets settings and cached data; back it up first and use that only as a troubleshooting test, not as a standard upgrade step.

## Repository

- `SignalFire/` contains the complete addon source and TOC.
- `CHANGELOG.md` contains the user-facing release notes.
- `.github/workflows/release.yml` validates and packages the TOC file set.

Repository automation can build an installable ZIP. Publishing, tagging, and distributor uploads remain explicit maintainer actions.

**SignalFire. Lighting the Path to Adventure.**
