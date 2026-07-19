# SignalFire 1.5.1 Publication Checklist

## Candidate

- [ ] Confirm Phase 11 branch and commit.
- [ ] Confirm working tree is clean.
- [ ] Confirm `SignalFire-1.5.1.zip` SHA-256.
- [ ] Confirm ZIP contains only `SignalFire/SignalFire.toc` and the 13 TOC-listed Lua files.
- [ ] Install the candidate by replacing the old addon folder.
- [ ] Confirm the visible title is `SignalFire v1.5.1`.
- [ ] Confirm fresh or missing Chat Links preference is Off.
- [ ] Confirm Public Groups parsing remains active with Chat Links Off.
- [ ] Confirm an explicit Chat Links On preference survives reload.
- [ ] Confirm Ascension and Triumvirate profiles and module gating.
- [ ] Confirm parser tests report 33 passed, 0 failed.
- [ ] Confirm Events, Notices, Guild Browser, Network, Full Roster, applicants, and listing workflows.

## Affected-Player Gate

- [ ] Preferably obtain one test from a player who previously reported severe FPS loss or crashing.
- [ ] Record whether Chat Links were Off or On and which scope was selected.
- [ ] Collect `/sf diag report` output and addon list if symptoms remain.
- [ ] Do not claim the severe FPS/crash issue fixed without supporting field evidence.

## Explicit Authorization Required

- [ ] Merge `release/11-1.5.1-production-prep` to `main`.
- [ ] Push the branch or merge.
- [ ] Create and push tag `v1.5.1`.
- [ ] Publish the GitHub release and attach the ZIP/checksum.
- [ ] Upload the ZIP to CurseForge or another distributor.
- [ ] Post the public announcement.

None of the publication actions above are part of Phase 11 production preparation.
