# Phase 10 Integrated Stability RC

## Baseline

- Approved baseline branch: `perf/09-cache-lifecycle`
- Approved baseline commit: `cb354ddf67f3714ac8e3bdd9160c1a36244c4864`
- Phase 10 branch: `release/10-integrated-stability-rc`
- Phase 8 reference parent: `8708839c250b82bc6e5bb6f219a87177eb986f3f`
- TOC: unchanged, 13 Lua files, `BronzeLFG_DB` SavedVariables, version 1.5.1

## Before And After

Before Phase 10, optimized runtime owners from Phases 2-9 were present but affected players had no bounded integrated conflict/storm report, and missing legacy Chat Links settings could become enabled. After Phase 10, the runtime behavior remains under the same optimized owners, Chat Links require an explicit true setting, malformed optional release state is repaired idempotently, and testers can opt into bounded stability, conflict, memory, and CPU diagnostics.

No gameplay feature, protocol, parser rule, renderer layout, TOC entry, or SavedVariables declaration changed.

## Diagnostics

Commands:

- `/sf diag start`
- `/sf diag stop`
- `/sf diag report`
- `/sf diag conflicts`
- `/sf diag memory`
- `/sf diag cpu`
- `/sf diag reset`
- `/sf diag deep on|off`

Diagnostics default Off and install no method wrappers until explicitly started. Histories are session-only and capped at 32 recent operations, 12 errors, and 16 resource samples. Deep stack capture is disabled by default and occurs only for slow, reentrant, or cyclic operations. Phase 10 adds no `OnUpdate` script.

The integrated report covers final method rates, same-frame calls, reentrancy, cycle indicators, hidden/unbuilt entries, slow thresholds, refresh scheduler merging, chat queue/frame ownership, lazy panels, timers, cache lifecycle, wrapper replacement, and resource samples. Raw chat/private message bodies are not retained.

## Resource Support

| Measurement | API | Behavior |
|---|---|---|
| SignalFire memory | `UpdateAddOnMemoryUsage`, `GetAddOnMemoryUsage` | Sampled only on command; unsupported is reported safely |
| Total Lua memory | `collectgarbage("count")` | Sampled only on command and reported separately |
| SignalFire CPU | `UpdateAddOnCPUUsage`, `GetAddOnCPUUsage` | Sampled only when `scriptProfile` is already enabled |
| CPU profiling state | `GetCVar("scriptProfile")` | Read only; SignalFire never enables it |
| Loaded addon count | `GetNumAddOns`, `IsAddOnLoaded` | Reported where available |
| Client/build | `GetBuildInfo` | Reported where available |

CPU attribution was harness-tested both unavailable/disabled and enabled. Enabling script profiling remains a manual tester action because it can reduce performance.

## Migration

- Fresh or missing `inlineChatLinks`: Off.
- Explicit true: preserved.
- Explicit false: preserved.
- Public Groups parsing remains enabled independently.
- Native Blizzard/item links are not changed when Chat Links are Off.
- Valid profile, scale, module, event, notice, favorite, and legacy fields are preserved.
- Invalid profile/scale/module structures are repaired without constructing UI or waking a timer.
- Repeated migration produces zero further repairs.

## Stress Results

- Busy chat: 50,000 mixed messages, milestone checks at 5,000/10,000/25,000/50,000, 5,000 authoritative filter traversals plus duplicate frame receipts. Queue drained, drops 0, AddMessage parser calls 0, decision caches capped at 256, Public Groups 60, online users capped at 512.
- Public Groups: 50/100/250/500 rows. Snapshot identity retained, page changes reused snapshots, search selected the exact ID, visible work stayed within eight rows, off-page formatting 0.
- Browse: 50/100/250/500 listings. Page changes reused snapshots, search selected the exact ID, visible work stayed within the row pool, off-page formatting 0.
- Roster: 50/100/250/500 remote users. One snapshot and one canonical sort per generation, immediate cache hit on repeat, hidden panel builds 0.
- Lifecycle: every major panel opened/closed 100 times. Shell and panels built once, panel registry remained fixed.
- Cache lifecycle: 35-cache inventory, 15,644 entries removed in the capacity/TTL/orphan stress harness, no cleanup errors.
- Diagnostic error safety: injected recursion reached depth 2 and was detected; active guards cleared. Error history capped at 12 and slow-operation history capped at 32.

The Fengari test runtime does not expose useful Lua memory samples, so its long-session memory fields were reported as unavailable. The approved Phase 9 in-game readings remain the memory baseline; no SignalFire-only memory claim is made from total Lua memory.

## Regression Results

- Lua 5.1 parse: 26 Lua files passed.
- Parser: 33 passed, 0 skipped, 0 failed.
- Phase 1 diagnostics: passed.
- Phase 2 UI lifecycle: passed; recursive scans 0, frames visited 0.
- Phase 3 roster: passed; large generation caching/sorting passed.
- Phase 4b timers: passed; delayed scheduler sleep and callback recovery passed.
- Phase 5 canonical chat/Public Groups: passed; full scans 0, AddMessage parses 0.
- Phase 6b Public Groups view: passed; off-page formatting 0.
- Phase 7 lazy panels: passed; shell 1, no background panel construction.
- Phase 8 Browse view: passed; off-page formatting 0.
- Phase 9 cache lifecycle and 50,000-message long session: passed.
- Phase 10 migration, stability, conflict, resource, and source-contract tests: passed.

These are static and harness results, not in-game confirmation.

## Changed Files

- `SignalFire/SignalFireChat.lua`: authoritative safe Chat Links default and explicit link gate; updated option help.
- `SignalFire/SignalFireUI.lua`: final Phase 5 link owner uses the safe migration and explicit link gate.
- `SignalFire/SignalFireDiagnostics.lua`: release migration and opt-in integrated diagnostics.
- `CHANGELOG.md`: user-facing safe-default note.
- `docs/PHASE10_RUNTIME_OWNERSHIP.md`: final owner and wrapper audit.
- `docs/PHASE10_FIELD_TESTS.md`: normal and affected-user field plans.
- Phase-specific test harnesses: deterministic large dataset/lifecycle coverage.
- `tests/release_migration_harness.lua`, `tests/stability_diagnostics_harness.lua`, `tests/verify_phase10_sources.js`: Phase 10 gates.

## Package

- File: `SignalFire-1.5.1-phase10-integrated-stability-rc.zip`
- SHA-256: `C85F34E9BAA90F0B10AF8568698D2318E9355A7000F5ED4D79A6568053293011`
- Contents: `SignalFire/` at ZIP root, 13 TOC-listed Lua files, one TOC, no reports/tests/README.

## Remaining Risks

- The reported severe FPS loss/freezing/crash is not claimed fixed without affected-player validation.
- Ascension visible-link stutter may still occur when Chat Links are enabled; the release-safe default is Off.
- WoW 3.3.5 cannot enumerate chat filter closure chains, so conflict output is an indicator rather than proof.
- Addons loaded after SignalFire can replace `SetItemRef`, tooltip, scale, or ChatFrame methods; Phase 10 reports detectable replacement during an active diagnostic session.
- Test harnesses cannot reproduce custom-client rendering, protected UI behavior, or actual addon CPU scheduling.

## Next Phase

Phase 11 only: final 1.5.1 production packaging and public release preparation after normal and affected-user field validation. Do not add features or begin another optimization pass.
