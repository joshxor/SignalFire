# SignalFire 1.5.2 Phase 12B Canary Field Test

This build is an unpublished safety test for the affected player. It preserves existing `BronzeLFG_DB` settings but forces Public Groups parsing and Chat Links Off after every canary.

## Install

1. Fully exit World of Warcraft.
2. Delete the existing `Interface\AddOns\SignalFire` folder.
3. Install the supplied `SignalFire` folder into `Interface\AddOns`.
4. Keep the existing SavedVariables, normal addons, and normal chat tabs.
5. Launch the game and leave **Parse Public Groups From Chat** and **Chat Links** Off.

## Verify the Installed Build

Before starting any timed test, run:

```text
/sf parser identity
```

The result must report:

- Version: `1.5.2`
- Release channel: `rc`
- Release name: `SignalFire 1.5.2 Phase 12B Canary RC`
- Chat runtime: `1.5.2-phase12b`
- Diagnostics: `1.5.1-phase10b`
- Parser worker: `1.5.2-phase12b`
- Canary: `1.5.2-phase12b-canary`
- Source owner: `true`
- Worker owner: `true`
- Shutdown owner: `true`
- Parser: `Off`
- Chat Links: `Off`
- Installed filters: `0`
- Parser queue: `0`
- Identity: `MATCH`

Do not begin the canary if any value differs. A mismatch leaves parsing and Chat Links Off and means the installed files are stale or mixed.

## Test

1. Run `/sf parser identity` and confirm the exact expected identity above.
2. Record normal and lowest FPS for two minutes with parsing Off.
3. Run `/sf parser canary 5`.
4. Wait for the automatic shutdown message.
5. Run `/sf parser report` and record the output.
6. Continue only if stable: `/sf parser canary 15`.
7. Continue only if stable: `/sf parser canary 30`.
8. Continue only if stable: `/sf parser canary 120`.

At the first serious performance problem, run:

```text
/sf parser abort
```

The canary automatically leaves both parsing and Chat Links Off. Do not test Chat Links in this pass.

Also report the character/location, chat-tab count, enabled addons, whether SignalFire was open, starting/minimum/ending FPS, and whether the slowdown was sustained or a brief hitch.
