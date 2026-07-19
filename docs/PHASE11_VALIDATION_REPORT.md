# Phase 11 Production Preparation

## Baseline

- Approved baseline branch: `release/10b-chat-ownership-diagnostics`
- Approved baseline commit: `5bc7fd1114a6f46dec3db68d58288dc7b836f9da`
- Approved baseline package SHA-256: `10B5ADFD54751A956F5796C765E56C4585744E91CDB7AE4B3D0ABC1643A70EFF`
- Phase 11 branch: `release/11-1.5.1-production-prep`
- Public version: `1.5.1`

Phase 11 changes release metadata, public documentation, release-specific tests, and package validation only. It does not change parser rules, chat routing, protocols, schedulers, cache ownership, panel architecture, or gameplay features.

## Version Sources

| Source | Final value |
|---|---|
| `SignalFire.toc` | `1.5.1` |
| `SignalFire_VERSION` | `1.5.1` |
| `SignalFire_RELEASE_CHANNEL` | `stable` |
| `SignalFire_RELEASE_NAME` | `SignalFire 1.5.1` |
| Visible title | `SignalFire v1.5.1` |
| README and changelog | `1.5.1` |
| Package | `SignalFire-1.5.1.zip` |

Internal diagnostic generation labels retain their subsystem phase origin so reports can identify the runtime owner. Protocol identifiers are unchanged.

## Production Defaults

| Setting | Fresh value |
|---|---|
| Chat Links | Off |
| Public Groups parsing | On |
| Chat Link scope | Main Chat Only |
| Profile | Auto-detected; safe fallback Triumvirate |
| Ascension Invasions | Off |
| Network auto-refresh | 30 seconds |
| Performance diagnostics | Off |
| Stability diagnostics | Off |
| Deep diagnostics | Off |
| Test-say mode | Off |

## Migration Results

The production harness passed 14 database shapes: fresh, explicit Chat Links On, explicit Off, missing legacy preference, malformed profile, malformed scale, malformed modules, stale Network state, stale Event/Notice state, invalid optional caches, and representative Phase 8, 9, 10, and 10b structures.

- Fresh, missing, and malformed Chat Links preferences become Off.
- Existing explicit On and Off preferences remain unchanged.
- Valid profile, scale, event, notice, and unknown fields remain intact.
- Invalid optional structures are repaired.
- Ascension Invasions remain disabled.
- A second migration performs zero repairs.
- Migration does not construct UI, build lazy panels, or wake the delayed timer.

## Chat Links

With links Off, classification and Public Groups parsing remained active, no SignalFire hyperlink was injected, and item, spell, quest, achievement, player, and trade links were preserved byte-for-byte. With explicit links On, the preference survived migration, one SignalFire hyperlink was created, no duplicate hyperlink was added, and the queue remained within its 40-record bound.

SetItemRef reachability, later-wrapper chaining, duplicate/missing/unknown reporting, and no-side-effect ownership probes passed the Phase 10b stability harness.

## Regression Results

- Lua 5.1 parse: 13 loaded addon files plus the production harness passed.
- Parser: 33 passed, 0 skipped, 0 failed.
- Phase 1 performance diagnostics: passed.
- Phase 2 UI lifecycle: passed; recursive scans 0, frames visited 0.
- Phase 3 Network/roster snapshots: passed.
- Phase 4 event-driven timers: passed; sleeping owners and callback recovery passed.
- Phase 5 canonical chat/Public Groups: passed; AddMessage parser calls and full scans remain 0.
- Phase 6 Public Groups view/renderer: passed; off-page formatting remains 0.
- Phase 7 lazy panels: passed; no background construction.
- Phase 8 Browse view/renderer: passed; off-page formatting remains 0.
- Phase 9 cache lifecycle: passed; 15,644 stress entries removed.
- Long session: 50,000 messages passed; queue drops 0, decision caches capped at 256.
- Phase 10/10b migration, diagnostics, ownership, and resource tests: passed.
- Production migration, native-link, profile, default, and version tests: passed.

These are static and harness results. They are not a new in-game confirmation.

## Package

- File: `SignalFire-1.5.1.zip`
- Root: `SignalFire/`
- Contents: one TOC and the 13 Lua files listed by the TOC
- Public README/changelog in ZIP: no, matching the established addon-package convention
- SHA-256: populated after the reproducible production archive is built

## Remaining Risks

- Some Ascension/CoA clients may still experience intermittent micro-stutter while custom SignalFire links are visible during very busy chat. Links default Off while parsing remains active.
- The first Public Groups link click can briefly pause during one-time lazy panel construction.
- Harnesses cannot reproduce custom-client rendering, protected UI behavior, or actual addon CPU scheduling.
- Known measured hotspots were optimized. No claim is made that every FPS issue or client crash is fixed.
- A test by a player previously affected by severe FPS loss or crashing is still preferred before publication.

## Publication Gate

The production candidate may be built without publishing it. Merge, push, tag, GitHub release publication, distributor upload, and public announcement each require explicit user authorization.
