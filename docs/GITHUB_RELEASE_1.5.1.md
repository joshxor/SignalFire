# SignalFire 1.5.1

SignalFire 1.5.1 focuses on measured performance hotspots, safer defaults, and compatibility for World of Warcraft 3.3.5 players on Ascension/CoA and Triumvirate.

## Major Improvements

- Faster startup, reopening, Public Groups, Browse, Network, and roster workflows.
- Event-driven timers that sleep while inactive.
- Lazy construction for panels that have not been opened.
- Bounded chat queues and session caches with deterministic cleanup.
- Better chat classification, exact link targeting, RDF listings, listing ages, and Ascension class display.
- Idempotent repair for malformed legacy SavedVariables structures.
- Opt-in runtime, ownership, resource, and compatibility diagnostics.

## Safer Chat-Link Default

Chat Links now default to **Off** for fresh installations and missing or malformed legacy settings. Public Groups parsing remains active while links are Off. Existing explicit On or Off preferences are preserved.

Links can be enabled under **Options > Chat & Parsing**. Some Ascension clients may still show intermittent micro-stutter while custom links are visible during very busy chat.

## Installation

1. Fully exit World of Warcraft.
2. Delete `Interface\AddOns\SignalFire`.
3. Extract the release into `Interface\AddOns`.
4. Confirm `Interface\AddOns\SignalFire\SignalFire.toc` exists.
5. Launch the game and use `/sf`.

This clean addon-folder replacement preserves normal `BronzeLFG_DB` SavedVariables.

## Upgrading

Do not overwrite the old addon folder. Delete only the installed SignalFire addon folder, then install the new one. Existing valid settings, profiles, favorites, events, and notices are preserved. A SavedVariables reset is not required.

## Diagnostics

- `/sf diag start` begins session-only diagnostics.
- `/sf diag report` prints the current report.
- `/sf diag stop` disables diagnostics.
- `/sf diag` lists ownership, conflict, memory, CPU, reset, and deep-trace commands.

Diagnostics and deep traces are Off by default.

## Troubleshooting

1. Confirm Chat Links are Off.
2. Run `/sf diag start`.
3. Reproduce the problem briefly.
4. Run `/sf diag report`.
5. Run `/sf diag stop`.
6. Provide the output, addon list, server profile, and any Lua error.
7. As a controlled test, fully exit WoW and temporarily rename both `BronzeLFG.lua` and `BronzeLFG.lua.bak`; restore them before normal play.
8. Do not permanently delete SavedVariables without a backup.

Resetting `BronzeLFG_DB` resets settings and cached data. It is a troubleshooting test, not a universal upgrade requirement.

## Known Limitations

- Visible custom SignalFire links may still cause intermittent chat-rendering micro-stutter on some Ascension/CoA clients. Chat Links remain Off by default.
- The first Public Groups link click may briefly pause while the panel is constructed; steady reopen measured substantially faster in current field testing.
- Known measured hotspots were optimized. No claim is made that every FPS issue or client crash is fixed.

Previously affected players are encouraged to test this candidate and submit a short diagnostic report if symptoms remain.

**SignalFire. Lighting the Path to Adventure.**
