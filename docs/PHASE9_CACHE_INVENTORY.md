# SignalFire Phase 9 Cache Inventory

Baseline: `perf/08-browse-view-cache` at `8708839c250b82bc6e5bb6f219a87177eb986f3f`.

Phase 9 adds no renderer, parser, chat-link, timer, lazy-panel, roster-snapshot, or Network-snapshot owner. Phase 12A removes its independent event frame and routes automatic cleanup through the Phase 4 lifecycle owner with a minimum 30-second gate. Public chat never triggers a cache sweep. `/sf perf cleanup` remains an immediate forced cleanup command. No cache-lifecycle `OnUpdate` script exists.

## Mutable Session Data

| Store | Owner and purpose | Key and value | Bound and expiry | Cleanup and persistence |
|---|---|---|---|---|
| `B.publicGroups` | Phase 5 identity; Public Groups rows | Stable listing ID to canonical row | 512; normal `publicExpire` age | `ExpirePublicGroups`, then Phase 9 capacity reconciliation; session |
| `B.listings` | Browse listings | Listing ID to listing row | 256; 900s, active own listing protected | Phase 9 automatic lifecycle maintenance; session |
| `B.applicants` | Listing applicants | Player/listing identity to applicant row | 128; 7200s | Phase 9; session |
| `B.chatGuildListings` | Guild parser results | Normalized guild identity to recruitment row | 256; 21600s | Phase 9; session |
| `B.guilds` | Guild Browser profiles | Guild identity to profile | 256; timestamped rows 14d | Phase 9; session |
| `B.guildPosts` | Guild recruitment posts | Post identity to row | 256; 21600s | Phase 9; session |
| `B.onlineUsers` | Network presence | Normalized player to presence row | 512; 300s | Phase 9, followed by roster-generation invalidation; session |
| `B.sfnStatuses` | Network statuses | Normalized player to status row | 512; 300s | Phase 9, followed by roster-generation invalidation; session |
| `B._sf151KnownClassNames` | CoA class resolver | Normalized player to class token/name | 256; capacity lifecycle | Phase 9; session; retained because the final UI owner uses it |
| `B.invasionUsers` | Invasion participants | Player identity to row | 256; capacity lifecycle | Phase 9; session |
| `B.invasionOtherPlayers` | Nearby Invasion players | Player identity to row | 256; capacity lifecycle | Phase 9; session |
| `B.invasionBeacons` | Invasion beacons | Beacon identity to row | 256; capacity lifecycle | Phase 9; session |
| `B.publicPlayerWho.lastQuery` | Public-row WHO throttling | Normalized player to timestamp | 128; 120s | Phase 9; session |
| `B.publicPlayerWho.finalResult` | Public-row WHO completion | Normalized player to timestamp | 128; 120s | Phase 9; session |
| `B._notifySeen569` | Notification deduplication | Listing signature to timestamp | 256; 120s | Phase 9; session |
| `B.sfamSeenPublic` | Favorite-alert row state | Public row ID to state | 512; source-row lifetime | Phase 9 orphan reconciliation; session |
| `B.sfamSeenApplicants` | Applicant alert state | Applicant ID to state | 128; source-row lifetime | Phase 9 orphan reconciliation; session |

## Chat And Public Identity

| Store | Owner and purpose | Key and value | Bound and expiry | Cleanup and persistence |
|---|---|---|---|---|
| `B._sfP3Seen` and slots | Source delivery dedupe | Sender/message signature to timestamp | 256; 5s | Phase 5 ring replacement/prune; session |
| `B._sfP3Records` and slots | Classified message records | Stable record ID to record | 256; 30s | Phase 5 ring replacement/prune; session |
| `B._sfP3ActiveRecords` | Active queue lookup | Stable ID to queued record | Queue-bound 40; until process/drop | Phase 5 queue owner; session |
| `B._sfP3Queue` | Deferred heavy parser queue | FIFO slots to records | 40; until process/drop | Phase 5 queue owner; session |
| `B._inlinePublicChatEventSeen` and slots | Inline delivery dedupe | Event signature to timestamp | 256; Phase 5 delivery window | Phase 5 ring replacement; session |
| `P3._decisionCache` and slots | Source classification decision | Event signature to decision | 256; 2-6s | Phase 5 ring replacement/lookup; session |
| `P3._renderDecisionCache` and slots | Render-only decision reuse | Sender/message signature to decision | 256; 2-6s | Phase 5 ring replacement/lookup; session |
| `P3._pendingByStableId` | Link target awaiting parser completion | Stable public row ID to record | 40; until process/drop | Phase 5 queue owner; session |
| `P3._publicIndex` | Canonical Public Groups identity | Canonical sender/message to row ID | 512; row expiry plus grace | Phase 5 index ring and expiry wrapper; session |
| `P3._publicIndexById` | Reverse canonical identity | Stable row ID to canonical key | 512; source index lifetime | Phase 5; session |
| `P3._publicIndexSlots` | Canonical index eviction ring | Slot to canonical key | 512 | Phase 5; session |
| `B._sf151AlertSeen` | Listing-alert dedupe | Alert signature to timestamp | Phase 5 bounded TTL owner | Phase 5 maintenance; session |
| `B._sfChatParseQueue/Seen` | Compatibility placeholders | Empty tables | Deterministically empty under final Phase 5 owner | Cleared by compatibility command/reload; session |

## Snapshots, Views, And Fixed Registries

| Store | Owner and purpose | Key and value | Bound and expiry | Cleanup and persistence |
|---|---|---|---|---|
| `Roster.snapshot` | Canonical roster snapshot | Current generation to snapshot | 1; generation/next expiry | Phase 3 invalidation; session |
| `Roster.viewCache` | Filtered roster views | Generation/filter/search/guild signature to view | 16; current generation | Phase 3 FIFO/invalidation; session |
| `Roster.classCache` | Unit/class lookup | Normalized player to class record | 128; 1800s | Phase 3 snapshot build; session |
| `Roster.statusByNameKey` | Snapshot status map | Normalized player to status | Current snapshot only | Rebuilt once per snapshot; session |
| `Roster.unitByNameKey` | Snapshot unit-token map | Normalized player to unit token | Current snapshot only | Rebuilt once per snapshot; session |
| `PublicView.snapshot` | Public Groups display snapshot | Data generation to row array/map | 1; current generation | Phase 6b invalidation; session |
| `PublicView.viewCache` | Filtered Public Groups views | View signature to page-independent view | 16; current generation | Phase 6b FIFO/invalidation; session |
| `PublicView.rowStates` | Renderer signatures | Fixed visible row index to signature | Fixed row-pool size | Phase 6b renderer lifecycle; session |
| `BrowseView.snapshot` | Browse display snapshot | Data generation to row array/map | 1; current generation | Phase 8 invalidation; session |
| `BrowseView.viewCache` | Filtered Browse views | View signature to view | 16; current generation | Phase 8 FIFO/invalidation; session |
| `BrowseView.rowStates` | Renderer signatures | Fixed visible row index to signature | Fixed row-pool size | Phase 8 renderer lifecycle; session |
| `Timer.taskByKey/tasks` | Delayed callbacks | Task key/queue slot to task | 128; callback deadline | Phase 4b execute/cancel/replace; session |
| `Timer.errors` | Timer callback diagnostics | FIFO slot to error record | 20; session | Phase 4b FIFO/reset; session |
| `LazyPanels.panels` | Lazy construction registry | Fixed panel name to state | 13 fixed entries | Phase 7/reload; session |
| Dropdown registrations | One-time dropdown patches | Fixed dropdown widget to registration state | Deterministic UI count | Phase 2 UI owner/reload; session |
| Wrapper/frame bindings | Diagnostics and compatibility ownership | Fixed function/frame identity to binding | Deterministic loaded-owner count | Final owner/reload; session |
| Selection/search/filter state | Current panel state | Fixed scalar and small option maps | Deterministic panel fields | Panel repair/profile switch/reload; session |

## Diagnostics

| Store | Owner and purpose | Key and value | Bound and expiry | Cleanup and persistence |
|---|---|---|---|---|
| `SignalFirePerf151` counters | Phase 1 measurements | Fixed counter name to number | Fixed schema | `/sf perf reset` or reload; session |
| Diagnostic receiver history | Per-message frame receipt data | Message key/frame to counters | 128 messages; 30s | Phase 1 ring/TTL; session |
| Method/frame bindings | Instrumentation ownership | Fixed owner/frame to wrapper metadata | Loaded function/frame count | Reload; session |
| Cache maximum samples | Peak cache sizes | Descriptor name to number | Fixed inventory descriptor count | `/sf perf reset` or reload; session |
| `CL.stats` | Phase 9 lifecycle counters | Fixed counter name to number/string | 48 fixed fields | `/sf perf reset` or reload; session |
| `CL.peaks` | Phase 9 cache peaks | Inventory name to number | 35 inventory entries | `/sf perf reset` or reload; session |
| `CL.errors` | Cleanup failures | FIFO error records | 12 | FIFO/reset/reload; session |
| `CL.inventory` | Cache ownership metadata | Fixed array slot to metadata row | 35 static rows | Source load/reload; session |

## Persisted Data And State Caches

| Store | Owner and purpose | Key and value | Bound and expiry | Cleanup and persistence |
|---|---|---|---|---|
| `DB.chatGuildListings` | Persisted recruitment cache | Normalized guild to recruitment row | 256; 21600s | Phase 9 when distinct from runtime table; persisted |
| `DB.whoPlayers` | WHO discovery | Normalized player to row | 1024; existing 3600s prune | WHO owner plus Phase 9 capacity; persisted |
| `DB.whoGuilds` | WHO guild discovery | Normalized guild to row | 256; existing 14d prune | WHO owner plus Phase 9 capacity; persisted |
| `DB.whoGuilds[*].members` | WHO guild members | Normalized player to row | 128 per guild; parent lifecycle | Phase 9 capacity; persisted |
| `DB.network.favoriteAlertCooldowns` | Favorite-alert cooldown | Alert key to timestamp | 256; 7200s | Phase 9; persisted |
| `DB.network.favoriteAlertSeenListings` | Favorite listing dedupe | Listing key to timestamp | 256; 7200s | Phase 9; persisted |
| `DB.network.favoriteOnlineSeen` | Favorite online dedupe | Player key to timestamp | 256; 3600s | Phase 9; persisted |
| `DB.signalFireNetwork.events` | Community events | Event array | 60; event expiry | Community Events owner; persisted |
| Event alert/dismiss maps | Event state | Event ID to state | 60; source-event lifetime | Phase 9 orphan reconciliation; persisted |
| `DB.signalFireNetwork.notices` | Notice Board | Notice array | 40; notice expiry | Notice owner; persisted |
| Current and legacy notice maps | Read/dismiss state | Notice ID to state | 40; source-notice lifetime | Phase 9 orphan reconciliation; persisted |
| Favorites, favorite guilds | User-owned preferences | User-selected identity to state | Deterministic user data | Explicit user action; persisted |
| Recruitment templates | User-owned templates | Template ID to template | User-controlled | Explicit user action; persisted |
| Parser stats/settings/hidden types | User configuration/statistics | Fixed field or user option to value | Deterministic schema | Explicit user action/profile lifecycle; persisted |

## Removed Compatibility Caches

The final Phase 5 owner makes these earlier chat-link caches unreachable during normal runtime. Phase 9 removes any remaining entries at load and at lifecycle maintenance: `_inlinePublicChatCache`, `_sfDirectLinkCache`, `_sffclSeen`, `_sffclLastRow`, `_sffclFilterCache`, and `_sffclDisplayCache`. Their historical functions remain available for load-order compatibility, but the final active parser/link owner does not use these tables.

## Temporary Allocations

Capacity cleanup creates a transient candidate array only when a table is already over its limit, sorts it once by age/key, removes excess entries, and releases all references when the cleanup call returns. Event/notice live-ID maps are also transient and maintenance-only. Phase 9 does not add row-by-row or renderer allocations, and it leaves the generation-cached Phase 3, 6b, and 8 snapshot/view structures unchanged.
