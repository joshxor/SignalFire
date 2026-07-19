# SignalFire 1.5.2 Phase 12A RC

This test candidate removes a cache-maintenance path that could perform broad cleanup during sustained public chat. Automatic cleanup now runs through the existing lifecycle scheduler with a minimum 30-second interval, while `/sf perf cleanup` remains available as an immediate developer command.

- Removed cache sweeps triggered by every 256 public chat messages.
- Removed the duplicate cache-lifecycle event frame.
- Consolidated login and world-entry cleanup under the existing timer lifecycle owner.
- Added cooldown, execution, skip, forced-run, and per-pass timing diagnostics.
- Preserved chat parsing, chat links, Public Groups identity, and all cache bounds.

# SignalFire 1.5.1

SignalFire 1.5.1 is a performance, stability, and compatibility update for Ascension / Conquest of Azeroth and Triumvirate.

## Performance

- Reduced repeated UI construction and made reopened panels substantially faster.
- Added cached Network and Full Roster snapshots and views.
- Replaced recurring background work with event-driven, sleeping timer owners.
- Added a canonical Public Groups index, cached views, and incremental visible-row rendering.
- Added lazy panel construction so unused panels are not built in the background.
- Added cached Browse views and faster detail rendering.
- Bounded session caches and assigned deterministic cleanup ownership for long sessions.

## Stability

- Removed recursive UI-tree scans and reduced hidden-panel work.
- Bounded chat queues and reduced duplicate classification, listing, and alert work.
- Improved SavedVariables repair for malformed legacy profile, scale, module, Network, Event, and Notice data.
- Improved refresh merging and wrapper ownership reporting without repeatedly rehooking global functions.
- Preserved Public Groups parsing and ordinary Blizzard hyperlinks when SignalFire links are disabled.

## Chat and Public Groups

- Improved activity-link coverage across chat windows and tabs.
- Links show the recognized activity and requested roles and select the exact Public Groups row.
- Expanded RDF, dungeon shorthand, role-first, and Ascension activity recognition.
- Improved guild-seeker filtering and guild recruitment handling.
- Corrected Public Groups listing ages and timestamps.
- The parser regression suite now covers 33 cases.

## Create Listing

- Added Random Dungeon Finder, Random Heroic Dungeon Finder, and Random Mythic Dungeon Finder options.
- Random finder activities hide the individual dungeon selector and choose the matching difficulty.
- Preserved existing Dungeon, Mythic+, Raid, World Boss, Ascended, applicant, and posting-preview behavior.

## Network and Profiles

- Corrected Ascension custom class names in Network and Full Roster.
- Batched presence responses and visible-panel updates.
- Preserved separate Ascension and Triumvirate settings and profile-aware modules.
- Unsupported Invasion listeners remain disabled on Ascension and when the Triumvirate module is disabled.

## Safety

- **Chat Links now default to Off** on fresh installations and when an older installation has no valid saved preference.
- Existing explicit Chat Links On and Off choices are preserved during upgrade.
- Public Groups parsing remains active while Chat Links are Off.

## Diagnostics

- Added opt-in `/sf diag` stability, ownership, memory, and compatibility reporting.
- Diagnostics are disabled by default, session-only, bounded, and have no idle update loop.

## Compatibility

- World of Warcraft 3.3.5 build 12340 / Lua 5.1.
- Ascension / Conquest of Azeroth and Triumvirate profiles.
- Existing `BronzeLFG_DB` SavedVariables remain supported through normal upgrades.

## Installation and Upgrade

1. Fully exit World of Warcraft.
2. Delete the existing `Interface\AddOns\SignalFire` addon folder.
3. Extract the new SignalFire folder into `Interface\AddOns`.
4. Confirm `Interface\AddOns\SignalFire\SignalFire.toc` exists.
5. Launch the game and use `/sf`.

Deleting the addon folder does not delete SavedVariables. A SavedVariables reset is not required for normal upgrades.

## Known Limitations

- Some Ascension/CoA clients may still experience intermittent micro-stutter while custom SignalFire links are visible during very busy chat. Links can remain Off while Public Groups parsing stays active.
- The first Public Groups link click may briefly pause while the lazily built panel opens for the first time.
- This release optimizes known measured hotspots; it does not claim that every FPS issue or client crash is fixed.

**SignalFire. Lighting the Path to Adventure.**
