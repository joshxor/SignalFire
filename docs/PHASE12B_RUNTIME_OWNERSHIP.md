# Phase 12B Runtime Ownership

Baseline: `fix/12a-cache-lifecycle-chat-trigger` at `063b1fdced3eeb7786db8f555bd1ed9f5c9ffbcf`.

## Final Source Pipeline

`BronzeLFG.lua` owns the source `CHAT_MSG_CHANNEL`, `CHAT_MSG_SAY`, and `CHAT_MSG_YELL` event frame. Protocol channel traffic is routed to `HandleMessage`. Supported public traffic passes the immediate `SignalFireShouldSkipPublicChatEvent` option/protocol gate and reaches the final `AddPublicGroup` owner installed by `SignalFireChatRuntime151`.

The final Public Groups path is:

1. `BronzeLFG` source event frame
2. immediate parsing option and protocol rejection
3. `SignalFireChatRuntime151.IngestSource` / `p3_resolve`
4. bounded source-decision deduplication
5. strict `p3_candidate` gate
6. raw `p3_enqueue` record
7. sleeping `_sfP3Frame` worker
8. `p3_parse` / `SignalFireFastChatLinks.TestParse`
9. `p3_upsert_canonical`
10. merged Public Groups refresh request
11. immutable render-decision cache entry

The worker processes at most four records and at most 0.75 ms per active frame. It hides when the queue drains.

## Display Pipeline

`SignalFireChatRuntime151.ReconcileFilterRegistration` is the final filter-registration owner.

| Public parsing | Chat Links | Filters |
|---|---:|---:|
| Off | Off or On | 0 |
| On | Off | 0 |
| On | On | 3 |

The three filters cover channel, say, and yell. `P3.Filter` validates primitive inputs and options, checks display scope, constructs an exact event-payload key, and performs one bounded completed-cache lookup. A miss returns the original line. A hit returns the immutable decorated string. It cannot call the candidate gate, parser, queue, canonical upsert, refresh scheduler, cache lifecycle, or SavedVariables writers.

SignalFire installs no final `ChatFrame.AddMessage` wrapper and does not change `SetItemRef` ownership.

## Legacy Ownership

- `SignalFireChatQueueFix.sfcq_enqueue` now exits before text conversion or signal work when Public Groups parsing is unavailable or Off.
- `SignalFireFastChatLinks.Filter` and `SignalFireChatParsingControls.Filter` become passive when the final Phase 12B owner exists.
- Their registration functions remove legacy registrations and do not reinstall parser-capable filters.
- Legacy queue storage is cleared and its worker is disabled when the final owner applies.
- Historical inline filters and role-combination filters are removed and replaced with passive references.
- `InlinePublicChatLinkForMessage` is display-passive.

Protocol-specific listeners in Network, Events, Notices, presence, and other subsystems remain separate because they reject by protocol prefix and do not own Public Groups parsing.

## Confirmed Baseline Findings

| Finding | Result |
|---|---|
| Legacy `sfcq_enqueue` lacked the early Public Groups gate | True; hardened |
| Legacy public-signal gate contained generic standalone words | True; superseded and defensively gated |
| Original `AddPublicGroup` historically scanned Public Groups | True; not used by normal Phase 12B live chat |
| Phase 5 provides canonical indexed upsert | True; retained |
| Final Phase 12A `P3.Filter` called `p3_resolve` | True; removed |
| Filter-reachable resolution could call `TestParse` | True; moved to worker |
| Parser work could originate once per receiving ChatFrame | True for uncached filter ownership; eliminated |
| Turning parsing Off avoided the heavy path | True; Phase 12B makes the exit immediate and complete |

## Cache Contract

The render-decision cache is owned by `SignalFireChatRuntime151`. Its key is the exact lowercased author plus exact event message payload. Values contain the immutable display string, stable canonical ID, positive/negative state, generation, and expiration. It is session-only, capped at 256 entries, uses deterministic cyclic eviction, expires positive entries after 30 seconds and negative entries after 5 seconds, and is cleared on parsing disable, explicit Public Groups cache clear, profile/runtime clear, or generation invalidation. Filters never clean or scan it.
