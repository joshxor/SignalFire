# SignalFire 1.5.3

Development milestone: **Guild and Group Link Coverage**

## Guild Recruitment Coverage

- Expanded exact guild recruitment detection across common English and explicitly supported Spanish recruitment phrases.
- Added reliable guild-name extraction from angle-bracketed advertisements and exact Guild Browser links for qualifying recruitment posts.
- Ensured the canonical Guild Browser row exists before first-link rendering.
- Improved detection of PvE, PvP, raid, Mythic, leveling, social, and world-content recruitment advertisements.
- Preserved exclusion of players merely seeking a guild and ordinary channel announcements.

## Group and Activity Coverage

- Added Azuregos instanced activity recognition.
- Improved role-first and abbreviated applicant messages and bounded `LF1M`/`LF2M`-style recruiter detection.
- Preserved activity-unspecified aura group advertisements through the existing Random Dungeon Finder category.
- Kept the ambiguous `SC` abbreviation unassigned while reporting it through parser diagnostics.
- Prevented stale negative cache decisions from suppressing repeated valid posts.
- Invalidated stale negative parser decisions when parser aliases or runtime generations change.
- Added bounded guild/group diagnostics and expanded regression fixtures based on live Ascension messages.

## Performance and Compatibility

- Preserved the Phase 12A-12C one-resolution-per-logical-message architecture and FPS behavior across multiple ChatFrames.
- Kept one authoritative parser decision per logical message while ChatFrame filters reuse the completed result.
- Confirmed parser work does not scale with receiving ChatFrame count and Chat Links Off installs zero display filters.
- Added no permanent idle `OnUpdate` or chat-triggered full-table maintenance.
- Preserved native Blizzard hyperlinks, SavedVariables, server profiles, `BLFG312`, and TOC order.

# SignalFire 1.5.2

Development milestone: **Phase 12C Exact Contextual Chat Links**

## Performance

- Removed synchronous cache-lifecycle maintenance from public chat message checkpoints.
- Consolidated automatic cache cleanup under one throttled lifecycle owner.
- Reworked Public Groups parsing so expensive parser work runs once per logical chat message instead of multiplying across receiving ChatFrames.
- Added cheap early rejection for ordinary chat, addon protocol traffic, disabled features, and unsupported messages.
- Added bounded parser work and deferred non-display bookkeeping.
- Removed filter-side refreshes, notifications, cache cleanup, and duplicate parsing.
- Preserved Public Groups collection when Chat Links are disabled.
- Prevented unnecessary display filters from remaining registered when Chat Links are disabled.
- Preserved the field-tested FPS fix for high-volume city and global chat.

## Exact Contextual Chat Links

- Added one shared exact-message resolver for source chat events and ChatFrame fallback handling.
- Added first-occurrence exact links for eligible LFM and LFG posts.
- Ensured repeated messages receive the same correct contextual link without reprocessing once per ChatFrame.
- Added correct recruiter wording using `Need T/H/D`.
- Added correct applicant wording using `LFG T/H/D`.
- Prevented applicant roles from being mislabeled as needed roles.
- Prevented generic fallback links from replacing known exact activities.
- Ensured the canonical Public Groups row exists before caching the positive link decision.
- Preserved indexed Public Groups updates without restoring full-table live-chat scans.

## Parser and Activity Coverage

- Added or improved explicit aliases for Random Dungeon Finder/RDF, Vaults of Inquisition/Vault, Blackfathom Deeps/BFD, Molten Core/MC, Lord Kazzak/Kazzak, Snowgrave, Kaldros/Kaldros Depthbreaker, and Soggoth/Sogoth.
- Added support for multi-activity applicant posts such as Snowgrave, Kaldros, and Soggoth.
- Added narrow role typo handling for `Heasl` as Healer.
- Improved recruiter and applicant intent detection for common private-server phrasing.
- Preserved ordinary chat and unrelated announcements without adding links.

## Guild Recruitment Links

- Routed eligible guild recruitment advertisements through the shared Phase 12C resolver and display-cache architecture.
- Preserved clickable detected guild-name links to Guild Browser entries.
- Deferred Guild Browser listing updates away from ChatFrame display callbacks.
- Continued excluding players merely looking for a guild unless guild-applicant support is deliberately added later.

## Diagnostics and Safety

- Added parser identity and runtime-owner reporting.
- Added bounded parser trace diagnostics for individual messages.
- Added exact resolver, parser call, canonical upsert, link-build, cache-hit, fallback, and missing-link counters.
- Added safe parser and link canary commands.
- Added automatic canary shutdown that leaves parsing and Chat Links disabled after testing.
- Kept diagnostics session-only, bounded, disabled by default, and inexpensive while inactive.
- Added regression fixtures for real affected-player chat examples.
- Added validation across multiple receiving ChatFrame counts.

## Compatibility

- Preserved WoW 3.3.5 build 12340 and Lua 5.1 compatibility.
- Preserved Ascension, Conquest of Azeroth, and Triumvirate profiles.
- Preserved `BronzeLFG_DB` saved-variable compatibility.
- Preserved the `BLFG312` addon communication prefix.
- Preserved existing TOC load order.
- Preserved native Blizzard item, spell, quest, achievement, trade, and player links.
- Preserved explicit user Chat Links On and Off choices.
- Chat Links continue to default Off for fresh or missing settings.

## Deferred

- Automatic activity-alias learning remains deferred for a later release.
- Crafter development remains deferred until parser and chat-link field validation is complete.

## Phase 12B Canary Foundation

This unpublished affected-player build adds a bounded parser safety canary. `/sf parser canary 5` temporarily enables Public Groups parsing with Chat Links forced Off, then automatically disables parsing and clears unfinished parser work. Emergency abort, status, and bounded session-report commands are included without changing parser classification or Public Groups identity.

- Added a fail-closed `/sf parser identity` check so stale or mixed installations cannot start the canary.
- The identity report includes release metadata, runtime generations, final parser owners, parser/link state, and installed SignalFire filter count.
- Recorded the affected-player 1.5.1 parser-on FPS tests as the official comparison baseline; those tests did not run the Phase 12B implementation.
- Added 5-120 second parser canaries with a 10-second default.
- Added automatic shutdown at the deadline and one shared emergency stop owner.
- Added safety aborts for parser errors, worker re-entry, queue corruption, hard queue overflow, worker frames above 10 ms, forbidden render work, unexpected filters, and chat-triggered maintenance.
- Added session-only FPS, source, queue, worker, and filter reporting without retaining raw chat.
- Kept Chat Links Off throughout every canary and left both parsing and links Off afterward.
- Preserved the Phase 12A cache correction and Phase 12B source/worker architecture.

## Phase 12B Parser Isolation

This combined test candidate preserves the Phase 12A cache-lifecycle hotfix and restructures Public Groups chat parsing so one logical source message produces at most one bounded parser job, regardless of how many chat frames receive it.

- Added an immediate Public Groups option gate before candidate, parser, queue, and cache work.
- Added a strict low-cost candidate gate that rejects ordinary role, guild, queue, dungeon, raid, and Mythic conversation without recruitment context.
- Moved `TestParse` into a sleeping worker limited to four records and 0.75 ms per active frame.
- Kept accepted chat updates on the canonical indexed Public Groups path.
- Removed parser, queue, listing mutation, refresh, and cache-maintenance work from ChatFrame filters.
- Registers zero Public Groups display filters while parsing is Off or Chat Links are Off; links-on mode owns exactly three display-only filters.
- Removed SignalFire's active ChatFrame `AddMessage` wrappers from the final chat path.
- Added bounded render-decision caching and Phase 12B source, worker, filter, and index diagnostics.
- Preserved all 33 parser regression cases and the Phase 12A cache-maintenance correction.

An affected-player test of the separate Phase 12A partial hotfix improved performance from approximately 19 FPS to 35-38 FPS, but did not restore normal performance. That is external field evidence that cache cleanup was one significant component; it is not confirmation that the combined Phase 12B architecture fixes the remaining loss. Comparable affected-player testing is still required.

## Phase 12A Foundation

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
