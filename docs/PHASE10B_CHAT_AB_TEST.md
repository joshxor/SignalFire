# SignalFire Phase 10b Field Test

Use one warmed login session for both halves. Do not reload, log out, or force garbage collection between Chat Links Off and On.

## Warmup

1. Install the Phase 10b RC with WoW fully closed.
2. Log in and open SignalFire.
3. Open Browse, Public Groups, Create Listing, Network, Full Roster, Guild Browser, Applicants, Options, Events, and Notices once.
4. Close SignalFire and wait one minute during normal play.

## Chat Links Off

1. Disable Chat Links in SignalFire.
2. Run `/sf diag reset`.
3. Run `/sf diag start`.
4. Run `/sf diag memory` to record the interval start.
5. Play for 10 minutes in busy public chat.
6. Once during the interval, open and close these panels in order: Public Groups, Browse, Network, Full Roster, Create Listing, Events, Notices.
7. Run `/sf diag ownership`.
8. Run `/sf diag report`.
9. Run `/sf diag memory`.
10. Run `/sf diag stop`.

## Chat Links On

Without reloading or leaving the session:

1. Enable Chat Links and keep the same Chat Link Scope used for the intended comparison.
2. Repeat the exact commands, 10-minute interval, and panel sequence above.
3. Click at least three SignalFire activity links and confirm each opens and highlights the exact Public Groups row.

## Report Checks

- Chat ownership reports `outermost`, `chained`, `missing`, `duplicated`, and `unknown` separately.
- A later ElvUI wrapper may produce `chained`; it must not be called missing unless the controlled probe completes without reaching SignalFire.
- Chat filters report expected/known registrations separately from interval calls, classifications, links, parses, queue work, and drops.
- `SetItemRef` reports an explicit ownership state instead of treating `currentChanged=true` as proof of a fault.
- Refresh `nested` remains zero, `pending` returns false after activity settles, and merged requests substantially exceed executions during bursts.
- Compare `SignalFireStartKB` to `endKB` and `totalStartKB` to `totalEndKB` within each interval. Do not compare unrelated raw snapshots between sessions.
- First-open panel work appears separately from steady-state reopen timings.

The ownership probe uses no visible chat message, does not create a listing, and sends no addon traffic. Diagnostics remain disabled after `/sf diag stop` or a reload.
