# SignalFire 1.5.2 Phase 12B Canary Validation

## Official 1.5.1 Affected-Player Baseline

The affected player tested the parser under the older SignalFire 1.5.1 runtime:

| Test | Before | Lowest | After Off | Result |
| --- | ---: | ---: | ---: | --- |
| Parser Off baseline | about 120 FPS | about 100 FPS | n/a | Normal |
| Parser On, 5 seconds | 122 FPS | 38 FPS | 117 FPS | Immediate recovery; stutter |
| Parser On, 15 seconds | 118 FPS | 38 FPS | 125 FPS | Immediate recovery; camera and animation stutter |
| Parser On, second 15 seconds | 126 FPS | 46 FPS | 125 FPS | Immediate recovery; camera and animation stutter |

This is authoritative field evidence that the parser-enabled 1.5.1 runtime triggers the slowdown. It is not a Phase 12B failure: the tested report identified version 1.5.1, retained three SignalFire filters with Chat Links Off, omitted the Phase 12B source diagnostic, and did not expose the Phase 12A cache-clear owner.

## Required Canary Identity

The Phase 12B canary may start only when `/sf parser identity` reports:

- Version `1.5.2`, channel `rc`
- Release `SignalFire 1.5.2 Phase 12B Canary RC`
- Chat runtime and parser worker `1.5.2-phase12b`
- Diagnostics `1.5.1-phase10b`
- Canary `1.5.2-phase12b-canary`
- Source, worker, and shutdown owners active
- Parser Off, Chat Links Off, zero installed SignalFire filters, and an empty parser queue
- Identity `MATCH`

Any mismatch is fail-closed: the timed test is refused and both parser options remain Off.

## Field Validation Still Required

The same affected player must test this exact identified build under comparable conditions. Complete the Off baseline and then the 5-, 15-, 30-, and 120-second canaries in order, stopping immediately on a serious slowdown. Static and harness validation cannot establish in-game FPS behavior.
