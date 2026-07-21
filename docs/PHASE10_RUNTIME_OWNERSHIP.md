# Phase 10 Runtime Ownership Audit

Baseline: `perf/09-cache-lifecycle` at `cb354ddf67f3714ac8e3bdd9160c1a36244c4864`.
Load order is unchanged and ends with `SignalFireUI.lua`, then `SignalFireDiagnostics.lua`.

## Final Owners

| Subsystem | Original/compatibility chain | Final runtime owner | Repeat/recursion safety | Replacement risk | Required? |
|---|---|---|---|---|---|
| Main UI creation | `BronzeLFG:CreateUI` -> profile/UI wrappers -> Phase 2 lifecycle -> Phase 7 lazy shell | Phase 7 `B.CreateUI` | Startup path is idempotent; shell guard is cleared after protected construction | Later addons can call it but do not normally replace it | Yes |
| Main Show/Toggle | Core Show/Toggle compatibility path -> Phase 7 | Phase 7 `B.Show`, `B.Toggle` | Reuses shell and Browse after first open | Low | Yes |
| Feature Show/Build | Historical builders remain callable through compatibility names -> Phase 7 panel registry | Phase 7 generated Show/Build owners | Per-panel building guard, failure recovery, one build per panel | Low | Yes |
| Options/Create/Profile | Core builders -> profile/module wrappers -> Phase 2 lifecycle -> Phase 7 lazy owner | Phase 7 lazy owner with Phase 2 patching | UI patch signatures prevent repeated traversal/build work | Low | Yes |
| Create controls/preview | Core control callbacks -> Ascension/RDF compatibility -> Phase 2 preview signature | Final late UI owner called through existing control callbacks | Signature skips unchanged preview work | Low | Yes |
| Scale | Core Options dropdown callback; Phase 7 reapplies stored scale when shell is built | Direct callback plus Phase 7 shell restore | No recurring owner or polling | Low | Yes |
| Profile switching | Runtime profile owner -> module/integration wrappers -> Phase 2 transaction -> Phase 8 invalidation wrapper | Final Phase 8 wrapper around the Phase 2 transaction | Transaction guard and signatures prevent duplicate application | Medium: many compatibility layers | Yes |
| Module apply | Runtime/integration compatibility chain -> Chat module manager -> UI invalidation wrapper | Final late UI wrapper around Chat module manager | Module state is profile-scoped; repeated applies are signature-gated | Medium | Yes |
| Refresh scheduler | Phase 4 scheduler supersedes immediate per-packet refresh wrappers | `SignalFireRefresh151` / `SF151_RequestPanelRefresh` | Dirty merge, visibility checks, nested suppression | Low | Yes |
| Public Groups model | Historical `AddPublicGroup` wrappers -> Phase 5 canonical index | Phase 5 canonical mutation owner | Stable identity, bounded index, one dirty request per mutation | Medium: compatibility entry points remain | Yes |
| Public Groups view | Historical renderer -> Phase 6 cached snapshot/view/row renderer -> Phase 7 visibility gate | Phase 6 renderer behind Phase 7 lazy gate | Generation invalidation, cached view, row signatures | Low | Yes |
| Browse view | Core Browse -> Phase 7 lazy gate -> Phase 8 snapshot/view/renderer | Phase 8 `B.RefreshBrowse` | Error-safe render guard, generation cache, visible-page slice | Low | Yes |
| Network/Full Roster | Core/Network handlers -> Phase 3 snapshot owner -> Phase 4 batching -> Phase 7 lazy gate | Phase 3 snapshot/view owner, invoked by Phase 4/7 | Generation invalidation and hidden-panel skips | Medium | Yes |
| Presence | Network protocol handler -> batching wrapper -> Phase 3 invalidation | Final late UI `B.HandlePresence` wrapper | One generation increment and batched refresh request | Medium | Yes |
| Community Events | Community owner -> timer expiration/invalidation -> Phase 7 lazy gate | Community renderer behind Phase 7 | No hidden construction; expiration is event/slow-maintenance driven | Low | Yes |
| Guild/Applicants/My Listing/Invasions | Core/community/runtime owners -> Phase 4 dirty scheduler -> Phase 7 lazy gate | Phase 7 gated refresh owners | Hidden/unbuilt panels become dirty instead of rebuilding | Low | Yes |
| Chat source decision | Earlier FastChatLinks and control filters are removed/neutralized -> Phase 5 filter | `SignalFireChatRuntime151.Filter` | One source decision cache; bounded queue and stable row ID | High: chat addons can replace frame methods | Yes |
| ChatFrame AddMessage | Original frame method -> Phase 5 wrapper | `_sfP3CustomAddMessageHook` on each ChatFrame | Wrapper checks existing links and uses cached decision; no full parse per frame | High: chat addons can replace it after load | Required for custom frames |
| Chat click routing | Four historical `SetItemRef` wrappers in `BronzeLFG.lua` delegate in load order | Final fourth `SetItemRef` wrapper | Public/group and guild routes delegate unknown links | High: global API shared by addons | Compatibility-sensitive |
| Public link selection | Historical selector -> Phase 5 stable-ID wrapper | Phase 5 `OpenPublicGroupLink` | Stable canonical row ID survives enrichment | Low | Yes |
| Tooltip hyperlink | SignalFire does not replace final `ItemRefTooltip:SetHyperlink` | Blizzard/client owner | N/A | External addons may replace it | No SignalFire owner |
| Delayed work | Historical pulse frames disabled by Phase 4b | Phase 4b event-driven delayed scheduler | Wakes only with queued work; protected callbacks | Low | Yes |
| Visible Network ticker | Historical Network pulse disabled by Phase 4b | Phase 4b visible-only ticker | Sleeps when panel is hidden | Low | Yes |
| Applicant attention | Historical button polling removed | Phase 4b temporary animation frame | Active only while attention animation is needed | Low | Yes |
| Minimap drag | Historical permanent update removed | Phase 4b temporary drag frame | Active only while dragging; final state saved once | Low | Yes |
| Cache maintenance | Earlier scattered cleanup remains compatibility-only -> Phase 9 owner | `SignalFireCacheLifecycle151` | One slow scheduled owner, bounded caches, error-safe running guard | Low | Yes |
| Slash commands | Core slash -> freeze/reinstall compatibility -> Phase 1 diagnostics -> Phase 10 diagnostics | Final dynamic Phase 10 wrapper around `SF151_HandlePerfSlash` | Idempotent slash/hash installation | Medium: older client hash tables | Yes |

## Conflict Indicators

Phase 10 diagnostics capture the expected `SetItemRef`, `ItemRefTooltip:SetHyperlink`, and every Phase 5 ChatFrame `AddMessage` wrapper after SignalFire has loaded. `/sf diag conflicts` reports later replacement and known loaded chat/UI addons. It is an indicator report, not proof that another addon caused a fault: WoW 3.3.5 exposes no supported API for enumerating installed chat-event filters.

## Remaining Sensitive Chains

- `SetItemRef` has four historical SignalFire wrappers. They delegate correctly and are retained for compatibility, but a future cleanup must trace every link type before consolidation.
- Profile and module application still include compatibility wrappers across Runtime, Integration, Chat, and UI. Phase 2 signatures make repeated calls inexpensive; removing layers is outside Phase 10.
- Chat frame methods are intentionally wrapped because some custom chat UIs ignore event-filter return text. Replacement after SignalFire loads can cause missing visible links while parsing continues.
- Historical OnUpdate definitions remain in source, but Phase 4 disables or replaces the permanent owners. Active Phase 10 diagnostics add no OnUpdate script.

## Phase 10 Diagnostics Cache

Owner: `SignalFireStability151`. Keys: fixed audited method names and bounded FIFO records. Maximums: 40 audited methods, 32 recent operations, 12 errors, 16 resource samples. TTL: session lifetime. Eviction: oldest FIFO entry. Cleanup: `/sf diag reset` or reload. Persistence: none.
