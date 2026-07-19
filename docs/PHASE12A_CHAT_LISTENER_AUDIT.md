# Phase 12A Chat Listener Audit

Baseline: `release/11-1.5.1-production-prep` at `b8011d4b828aa7a86ffa7b6c38a65102c5d8a8b8`.

## Confirmed Defect

The Phase 9 cache-lifecycle block registered `CHAT_MSG_CHANNEL`, `CHAT_MSG_SAY`, and `CHAT_MSG_YELL`. Every 256 observed source messages it ran the complete cache cleanup chain, including Public Groups, Browse, Network, guild, WHO, alerts, Events, and Notices. The work ran whether developer diagnostics were enabled or disabled.

Phase 12A removes those chat registrations and the cache-lifecycle event frame. `ObserveChat` is now a diagnostic scalar only and never starts maintenance.

## Final Ownership

| Path | Final owner | Gate | Result |
|---|---|---|---|
| Login and world entry | Phase 4 `SignalFireTimer151.eventFrame` | Phase 9 `MaybeRun`, minimum 30 seconds | At most one automatic full cleanup in the interval |
| Other existing maintenance requests | Phase 4 `RunMaintenance` | Same Phase 9 gate | Requests merge through one owner |
| Public chat | Existing parser/filter owners | No cache-lifecycle call | Parsing behavior is unchanged |
| Manual cleanup | `/sf perf cleanup` | Forced | Runs immediately, even inside the automatic interval |

## Other Chat Listeners

| Subsystem | Initial rejection | Work after rejection | Phase 12A decision |
|---|---|---|---|
| Core public parser | Channel and eligibility checks | Existing classification and deferred parse queue | Preserve; this is the active parser path |
| Community Events | Exact `BLFG312~` prefix | Event payload split and handling | Preserve |
| Integration protocol | Exact protocol prefix | Protocol payload split and handling | Preserve |
| Network protocol | Exact protocol prefix | Presence payload split and handling | Preserve |
| Cache lifecycle | Previously counted all public messages and swept every 256 | Broad cache cleanup | Remove chat ownership |

The protocol listeners reject unrelated messages before payload splitting. Consolidating them would change protocol ownership and is outside this hotfix.

## Cache Contract

The hotfix introduces no cache. The automatic gate stores one session-only timestamp, `lastAutomaticRunAt`. It has deterministic one-value lifetime, resets on reload, and is updated only after a successful automatic cleanup.
