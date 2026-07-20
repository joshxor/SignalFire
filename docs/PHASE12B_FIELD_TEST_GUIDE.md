# Phase 12B Affected-Player Field Test

Use the combined Phase 12B RC with the same client, character, location, chat tabs, UI addons, and SavedVariables used for the earlier approximately 19 FPS and 35-38 FPS tests. Do not compare unrelated gameplay locations.

## Stage A: Control

1. Set **Parse Public Groups From Chat** Off.
2. Set **Chat Links** Off.
3. Run `/sf diag reset`, `/sf diag start`, and `/sf diag chatframes`.
4. Play in busy public chat for 10-15 minutes.
5. Run `/sf diag report`, then `/sf diag stop`.

Expected: zero candidate calls, parser calls, queue records, Public Groups filters, rewritten lines, and chat-maintenance runs.

## Stage B: Primary Test

1. Set **Parse Public Groups From Chat** On.
2. Keep **Chat Links** Off.
3. Repeat the diagnostic commands.
4. Play in comparable busy chat for 20-30 minutes.

Expected: source parsing is active, filter count remains zero, the worker queue drains, budget counters are active under bursts, forbidden inline counters remain zero, and there is no severe sustained FPS loss.

## Stage C: Optional Links

Only after Stage B is stable, enable **Chat Links** for a 5-10 minute controlled test. Stop if severe FPS loss returns. A first uncached occurrence may be plain; later matching occurrences can use the completed cached link.

Report normal and lowest FPS, whether the loss was sustained or a brief hitch, chat window/tab count, duplicated channel routes, enabled addons, whether SignalFire was open, existing or clean SavedVariables, active parsing/link settings, and the full diagnostic report.

The earlier partial Phase 12A field test improved approximately 19 FPS to 35-38 FPS. That is useful external evidence, but Phase 12B must be tested by the same affected player before the remaining issue can be called fixed.
