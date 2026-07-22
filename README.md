# SignalFire

SignalFire is a group-discovery and community coordination addon for World of Warcraft 3.3.5, with dedicated profiles for **Ascension / Conquest of Azeroth** and **Triumvirate**.

It turns fast-moving public chat into organized listings for dungeons, raids, random dungeon finder groups, Mythic+, world bosses, guild recruitment, and community activities. SignalFire also includes listing and applicant tools, a user Network and Full Roster, favorites, community events, notices, and profile-aware modules.

**Current release: 1.5.3**

SignalFire 1.5.3 expands exact guild and group-link coverage while preserving the public-chat FPS corrections introduced in 1.5.2. It recognizes more English and Spanish guild recruitment phrasing, creates canonical Guild Browser rows before first-link rendering, and improves Azuregos and activity-unspecified group detection.



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

## What Changed in 1.5.3

- Expanded guild recruitment detection across common English and supported Spanish phrases.
- Added exact Guild Browser links for qualifying recruitment posts and canonical guild-row creation before the first link is rendered.
- Added Azuregos recognition and activity-unspecified aura group support.
- Preserved ambiguous `SC` text as diagnostic context instead of assigning an unsupported specific dungeon.
- Invalidates stale negative parser decisions when parser generations change.
- Added bounded guild and group diagnostics plus expanded live-message regression fixtures.
- Preserved one authoritative parser decision per logical message; receiving ChatFrame filters reuse the completed result.
- Preserved zero display filters while Chat Links are Off, with no permanent idle `OnUpdate` or chat-triggered full-table maintenance.

## Chat Links

SignalFire continues to parse eligible chat and populate Public Groups while Chat Links are Off. Enable links manually under **Options > Chat & Parsing** when you want clickable activity and guild links.

Available scopes are Main Chat Only, Visible Chat Frames, and All Chat Frames. All Chat Frames provides the broadest coverage; lighter scopes may reduce custom-link rendering work on affected Ascension clients.

Public Groups source parsing does not scale with the number of chat frames receiving a message. Chat Links register display filters only while both Public Groups parsing and Chat Links are enabled. Source events and filter fallback share one exact resolver, so the first eligible occurrence receives the same contextual link across every receiving frame.

## Commands

- `/sf` opens SignalFire.
- `/sf public` opens Public Groups.
- `/sf guild` opens the Guild Browser.
- `/sfparse` opens the parser regression tests.
- `/sf diag start` begins session-only stability diagnostics.
- `/sf diag report` prints a diagnostic report.
- `/sf diag stop` disables diagnostics.
- `/sf diag` lists the remaining diagnostic commands.
- `/sf parser canary 5` runs a five-second parser-only safety test with Chat Links Off.
- `/sf parser abort` immediately stops an active canary and discards unfinished parser work.
- `/sf parser off` is the emergency parser and Chat Links shutdown command.
- `/sf parser status` and `/sf parser report` show bounded session-only canary results.
- `/sf parser identity` reports the active release and parser owners.
- `/sf parser trace <message>` explains one parser and exact-link decision without retaining live chat history.

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
