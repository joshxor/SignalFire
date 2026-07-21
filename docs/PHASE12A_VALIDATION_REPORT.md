# Phase 12A Validation Report

Baseline: `release/11-1.5.1-production-prep` at `b8011d4b828aa7a86ffa7b6c38a65102c5d8a8b8`.

Branch: `fix/12a-cache-lifecycle-chat-trigger`.

## Runtime Change

Before Phase 12A, the cache-lifecycle subsystem owned an event frame for login, world entry, channel, say, and yell messages. Every 256 observed public-chat messages invoked the complete cache cleanup chain.

After Phase 12A, the Phase 4 timer subsystem remains the only automatic lifecycle-event owner. Its existing maintenance path reaches a Phase 9 gate with a minimum 30-second interval. Public chat does not request or execute cache maintenance. Manual `/sf perf cleanup` remains forced and immediate.

## Stress Results

- 100,000 chat observations: zero cache-maintenance runs and zero cache mutations.
- 103 automatic maintenance requests: 3 executions and 100 cooldown skips.
- 2 manual cleanup requests: 2 forced executions.
- Per-pass timing instrumentation reported all eight passes while diagnostics were enabled.
- 50,000-message long-session harness: queue drained, cache limits held, and no errors were reported.

Harness timings are synthetic and validate counter wiring only. They are not in-game performance measurements.

## Regression Results

- Lua 5.1 parsing: passed for all addon files and changed Lua harnesses.
- Parser regression: 33 passed, 0 skipped, 0 failed.
- Performance diagnostics: passed.
- UI lifecycle: passed.
- Network and roster snapshots: passed.
- Event-driven timers: passed.
- Chat/Public Groups canonical index: passed.
- Public Groups renderer and view cache: passed.
- Lazy panels: passed in isolated and full-runtime harnesses.
- Browse renderer and view cache: passed.
- Cache lifecycle and long-session cache bounds: passed.
- Release migration: passed.
- Stability diagnostics: passed.
- Production release behavior: passed.
- Source ownership and package-source verifiers: passed.

## Field Validation Still Required

- Confirm normal public chat continues to populate Public Groups.
- Confirm optional activity and guild links still select the exact row.
- Compare busy-chat frame pacing against the 1.5.1 fallback.
- Run `/sf perf cachelife` before and after busy chat and confirm `chatRuns=0`.
- Trigger login/world entry close together and confirm one automatic run with a cooldown skip.
- Run `/sf perf cleanup` twice and confirm both commands execute immediately.

No in-game result is claimed by this report.
