# Phase 10 Field Validation

## Normal Tester

Start with diagnostics off. Fully exit WoW, install the RC into a clean `Interface\AddOns\SignalFire` folder, and launch normally.

1. Confirm the title shows SignalFire 1.5.1 and the correct server profile.
2. Confirm Chat Links are Off on a fresh or reset configuration while Public Groups still fills from chat.
3. Manually enable Chat Links and confirm eligible group and guild messages receive one real link.
4. Click several links and confirm the exact Public Groups or Guild Browser row is selected.
5. Run the parser suite and confirm `33 passed, 0 failed`.
6. Open every page once, then reopen each page several times.
7. Switch Ascension -> Triumvirate -> Ascension and verify module availability and saved settings.
8. Test UI scales 75%, 85%, 90%, 100%, 110%, 120%, and 125%.
9. Create, post, rebroadcast, and cancel Normal RDF, Heroic RDF, and Mythic RDF listings. The specific dungeon selector must stay hidden for random activities.
10. Open Network and Full Roster, use Refresh Now, and verify correct custom class names and no duplicate users.
11. Create/open Events and Notices; verify Favorites, Guild Browser, Applicants, and Invasions profile gating.
12. Play 20-30 minutes in normal busy chat with Chat Links at their default Off state. Open each major panel during the first interval, then close SignalFire and continue playing. Run `/sf diag start` only for a short final sample, followed by `/sf diag report`, `/sf diag memory`, and `/sf diag stop`.

## Affected Tester

Use this only when investigating a hitch, stale panel, missing link, or another-addon conflict. Back up `WTF\Account\<account>\SavedVariables\BronzeLFG.lua` before testing.

1. First test SignalFire with every other addon disabled. Record whether lag begins at login, when chat appears, when SignalFire opens, when Network or Browse opens, when Chat Links are enabled, or only after prolonged play.
2. Repeat with the normal addon set and record the exact enabled addons.
3. Run `/sf diag start` immediately before reproducing the issue.
4. Reproduce the issue for 30-60 seconds; avoid leaving diagnostics on for an entire play session, and stop if the client becomes unstable.
5. Run `/sf diag report`, `/sf diag conflicts`, `/sf perf print`, and `/dump BronzeLFG:SF151_PrintTimerDiagnostics()`.
6. Run `/sf diag memory` before and after a longer reproduction.
7. CPU attribution is optional and intrusive. Enable it only for a controlled test with `/console scriptProfile 1`, reload, run `/sf diag start`, reproduce briefly, then run `/sf diag cpu`.
8. Disable CPU profiling afterward with `/console scriptProfile 0` and reload.
9. Run `/sf diag stop` when finished.

For visible-link stutter, compare the same busy-chat sample with Chat Links Off, Main Chat Only, Visible Frames, and All Chat Frames. Record the selected scope, loaded chat/UI addons, whether SignalFire was open, and whether the hitch disappears with links Off.

## Report Contents

Include the first Lua error, `/sf diag report`, `/sf diag conflicts`, server profile, client build, chat-link scope, and exact reproduction steps. Diagnostics sanitize trigger labels and do not retain raw chat/private message bodies.
