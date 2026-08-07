# SignalFire Master Development Plan

**Project:** SignalFire  
**Repository:** `joshxor/SignalFire`  
**Current addon version:** `1.5.3`  
**Plan snapshot:** August 1, 2026

This document is the standing project roadmap and architectural handoff for SignalFire.

It should be read together with the repository-root `AGENTS.md`.

`AGENTS.md` contains durable operating rules. This document contains the broader roadmap, completed milestones, active status, planned passes, architectural decisions, testing workflow, and sequencing.

---

# 1. Project Development Model

SignalFire is developed through narrowly scoped feature passes.

The normal lifecycle is:

1. Verify current `main`.
2. Fetch/prune and verify exact SHAs.
3. Create or reuse the appropriate feature worktree.
4. Create one narrowly scoped feature branch.
5. Implement only that pass.
6. Add production-loaded regression coverage.
7. Run local/static validation.
8. Push normally.
9. Keep the PR draft while implementation and CI are active.
10. Investigate exact CI failures one at a time.
11. When CI is fully green, use the exact CI package artifact as the release candidate.
12. Give the user the exact ZIP and a pass-specific step-by-step in-game smoke-test checklist.
13. Do not merge until that exact production build has passed live testing.
14. After live approval:
    - finalize the PR;
    - mark ready when appropriate;
    - merge normally;
    - verify post-merge `main` CI;
    - verify package construction;
    - clean branch/worktree state.
15. Start the next feature pass from newly verified `main`.

Do not combine the entire roadmap into one branch.

---

# 2. Codex Chat and Model Strategy

## Chat continuity

Use the same Codex chat for one complete feature round, including:

- implementation;
- corrections;
- source verifier changes;
- harness changes;
- CI debugging;
- RC preparation;
- merge preparation;
- post-merge verification;
- cleanup.

Start a new Codex chat for a genuinely new feature round.

## Token-efficient model strategy

Default:

**Luna / Extra High / Standard**

Escalate to:

**Terra / Medium / Standard**

only when:

- Luna fails twice on the same underlying root problem;
- Luna repeatedly misunderstands the same multi-owner architecture;
- Luna proposes broad changes where evidence supports a narrow correction;
- a task demonstrably requires deeper cross-subsystem reasoning.

Use Sol High only after evidenced Terra attempts have also failed.

A new CI assertion uncovered after the prior assertion passes is not the same as failing twice on one root problem.

Routine harness fixes, mock corrections, CI investigation, verifier work, merge work, and cleanup should normally remain on Luna.

---

# 3. Repository and Worktrees

Repository:

`joshxor/SignalFire`

Default branch:

`main`

Normal repository:

`C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-main`

Primary reusable feature worktree:

`C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-2b-exact-links`

Separate older Network worktree:

`C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-2a-network-sync`

The `SignalFire-2b-exact-links` folder is reusable and should be preserved across passes.

Never assume a worktree's branch or SHA from old context.

---

# 4. Core Compatibility and Protocol Guardrails

SignalFire targets:

- World of Warcraft 3.3.5
- Lua 5.1

Production changes must remain compatible with that environment.

## LIST packet contract

Established packet positions extend through `p[26]`.

Current extension:

- `p21` Tank
- `p22` Healer
- `p23` DPS
- `p24` Support
- `p25` minimum level
- `p26` maximum level

Do not add `p27+` without an explicitly approved protocol migration.

Do not reorder or silently repurpose existing packet positions.

## Transport

Internal BLFG transport remains.

Do not automatically join public channels.

Do not restore the removed Global public-broadcast fallback.

Marketplace protocols, applicant packets, exact-link protocols, and Network presence packets are out of scope unless a pass explicitly targets them.

---

# 5. Server Profile Ownership

SignalFire preserves server-specific behavior.

Ascension and Triumvirate must not be treated as interchangeable.

Current Ascension creation ownership:

## Ordinary Dungeon

- Normal
- Heroic
- plain Mythic

## Dedicated Mythic+

- keyed Mythic+
- separate activity ownership
- key validation retained

Plain Mythic is not Mythic+.

Do not copy Ascension-specific behavior into Triumvirate without evidence and explicit scope.

---

# 6. Performance Architecture

The current runtime architecture is intentional.

Public parsing and UI refresh work use:

- deferred processing;
- dirty-state ownership;
- debounced/batched refreshes;
- lazy panels;
- bounded worker frames;
- idle workers that sleep when no work exists.

There must not be a permanent parser `OnUpdate` while idle.

Do not make production synchronous just to satisfy a test when the real architecture intentionally uses a scheduler/debounce.

When a test needs a debounced result, the harness should drive the real scheduler.

Performance passes should remain evidence-driven.

---

# 7. Completed Milestone — v1.4.33 UI / Version Consolidation

Status:

**Completed**

Key changes:

- `SignalFireVersion.lua` became the authoritative version/profile identity source.
- Visible version/profile label made persistent.
- Options header buttons normalized.
- Options subpanels standardized.
- Legacy Invasions controls hidden.
- 90% and 120% UI scale presets added.

Do not rebuild or replace this architecture unless a demonstrated regression requires it.

---

# 8. Completed Milestone — v1.4.34 Compatibility / Performance

Status:

**Completed**

Root cause corrected:

Inherited BronzeLFG refresh functions intentionally cleared the shared version text while an earlier SignalFire finalizer only restored it temporarily.

The SignalFire identity label was separated from that inherited lifecycle.

Do not return to timer-based temporary restoration.

---

# 9. Completed Milestone — Marketplace Phase 2B

Status:

**Completed and merged**

PR:

`#17`

Merge baseline:

`4e326398fe2ee013f83cee52033284ec61a4a829`

Delivered:

- exact Marketplace posted links;
- Share Link composer.

Marketplace is regression-sensitive but is not an open roadmap target unless explicitly requested.

---

# 10. Completed Milestone — Runtime FPS Cleanup Pass A

Status:

**Completed and merged**

PR:

`#18`

Merge baseline:

`8c09bebf47f9a30024b48e839cb54d613c7f7590`

Important retained architecture:

Phase 3 public parser worker intentionally has no permanent `OnUpdate` while idle.

Tests must preserve this rather than forcing the worker to remain active.

---

# 11. Completed Milestone — Listing and Broadcast UX Pass A

Status:

**Completed and merged**

PR:

`#19`

Feature head:

`52daa41d4db429cdba64c314f366c493a264d8ba`

Merge commit:

`c548a9f45225d2422335f8ab10313f3d5db2ff7f`

Delivered:

- profile-aware public-channel discovery;
- multi-channel user-triggered broadcast;
- role counts including Support;
- full role wording;
- minimum/maximum level metadata;
- listing template variables;
- Listing/Create/Preview/Public Groups presentation improvements.

Retained broadcast contract:

- dynamically discover joined public channels;
- exclude BLFG from public destination selection;
- prune stale public-channel selections;
- never automatically join public channels;
- keep internal BLFG;
- resolve public destination IDs live at send time.

Do not reopen this pass unless a demonstrated regression exists.

---

# 12. Activity Discovery Pass A

PR:

`#20 – Add Mythic activity discovery and filters`

Feature branch:

`feature/activity-discovery-pass-a`

Tested feature head:

`7d6067e3da0f5dbe8616f5232d0eaebd9d668ba4`

Base main at pass start:

`c548a9f45225d2422335f8ab10313f3d5db2ff7f`

Green workflow:

- Run `#113`
- Run ID `30709566633`
- Package job `91394515781`

Green RC artifact:

- `SignalFire-1.5.3`
- Artifact ID `8821418947`

Live in-game smoke test:

**PASSED**

Final documentation head:

`fac0006be5ce555bee73ef325926683432178c76`

Merge SHA:

`a201cab826d1b3859a40cc135355dfafc259b83e`

Post-merge workflow:

- Run `#115`
- Run ID `30710497798`
- Package job `91396986881`
- Conclusion: success

Post-merge artifact:

- `SignalFire-1.5.3`
- Artifact ID `8821707756`
- Digest `sha256:536cbd2208c2ff98825e8908b2c7d645c7b0483f37714b99225b154ed62b292d`

Status:

**COMPLETE AND MERGED**

---

# 13. Activity Discovery Pass A — Delivered Behavior

## 13.1 Ascension plain Mythic creation

Ordinary Ascension Dungeon owns:

- Normal
- Heroic
- Mythic

Plain Mythic:

- `Type = Dungeon`
- preserves exact selected dungeon
- `Difficulty = Mythic`
- does not require a key
- hides/inactivates key controls
- survives saved-state migration without coercion to Normal
- preview/recruitment wording shows Mythic

Dedicated Mythic+ retains separate keyed ownership and key validation.

## 13.2 Discovery parser

Production parsing differentiates:

- plain Mythic
- Mythic+ / keystone

Mythic+ signals include:

- `Mythic+`
- `mythic plus`
- `m+`
- numeric `+N`
- `keystone`

Mythic+ precedence wins over plain Mythic.

Guild/Raid precedence protections remain.

## 13.3 Canonical activity examples

- `BFD` → `Blackfathom Deeps`
- `SM Cath` → `Scarlet Monastery - Cathedral`
- `SM Lib` → `Scarlet Monastery - Library`
- `BRD Prison` → `Blackrock Depths - Prison`
- `DMN` / `Dire Maul North` → `Dire Maul - North`
- `SFK` → `Shadowfang Keep`
- `WC` → `Wailing Caverns`
- Deadmines context → `Deadmines`

`Dire Maul - North` is the authoritative spelling.

## 13.4 Public Groups Difficulty filter

Exact options:

- All Difficulties
- Normal
- Heroic
- Mythic
- Mythic+

Difficulty combines with:

- Type
- Role
- Search

`All Difficulties` removes only the Difficulty restriction.

It does not reset Type, Role, or Search.

## 13.5 Search metadata

Current Public Groups search includes relevant normalized metadata such as:

- canonical activity;
- normalized difficulty;
- key level.

## 13.6 Keystone and row identity ownership

Stable ownership contract:

- `listing.key` = listing Mythic+ keystone level
- `parsed.keyLevel` = canonical parser key level
- `row.key` = stable Public Groups row identity
- `row.keyLevel` = discovered Public Groups Mythic+ key level

Never overload `row.key` with keystone level again.

## 13.7 Public Groups lifecycle

Difficulty controls are owned by:

`SignalFirePublicGroupsView151.AttachPanel`

The final lazy lifecycle reconciles them during:

- reuse;
- post-build paths.

Readiness includes the Difficulty controls.

Attachment is idempotent:

- missing controls can be repaired;
- controls are not duplicated;
- named dropdown frames are reused safely;
- OnShow/OnHide hooks are installed once;
- dropdown registration uses the standard lifecycle.

## 13.8 Selection clearing

When the selected row becomes filtered out:

the real Phase 6 renderer clears `selectedPublic` after the normal Phase 4 debounced refresh executes.

Do not bypass the scheduler.

---

# 14. Activity Discovery Pass A — CI Lessons

The production-loaded harness progressively exposed several independent issues.

Important lessons:

- Canonical expectations must match production exactly.
- `Dire Maul - North` is authoritative.
- Do not assume obsolete/nonexistent parser frames.
- Shared WoW transport mocks must represent BLFG behavior where required.
- Listing lifecycle tests must account for active listings and deterministic timestamps.
- Idle worker state is valid and should not be converted into permanent polling.
- Public Groups row identity must be separate from keystone metadata.
- `All Difficulties` does not imply clearing Type/Role/Search.
- Later lazy lifecycle owners can bypass earlier UI builder wrappers.
- Hook markers must not incorrectly imply that all controls exist.
- Debounced refresh effects must not be asserted synchronously.
- Shared WoW UI mocks must honor APIs such as `UIDropDownMenu_SetWidth`.

Fix harness defects as harness defects.

Fix production defects only when production evidence supports them.

---

# 15. Activity Discovery Pass A — Closeout

Pass A is complete and merged. The exact RC passed live testing, and the
post-merge `main` workflow and package construction succeeded.

Merge evidence is recorded in Section 12.

---

# 16. Activity Discovery Pass B - Closeout

**Status: COMPLETE AND MERGED**

Activity Discovery Pass B was implemented on PR #21 from the verified Pass A
baseline. The exact production RC passed live testing, merged successfully,
and passed the post-merge `main` workflow and package construction.

PR:

`#21 - Add XP Aura discovery and Public Groups search`

Feature branch:

`feature/activity-discovery-pass-b`

Final tested and merged evidence:

- merge commit: `2780abd279a3973089008df8c51216ae13953164`;
- post-merge `main` workflow #125;
- run ID `30766863644`;
- package job `91547044785`;
- artifact `SignalFire-1.5.3`;
- artifact ID `8839225729`;
- artifact digest `sha256:b5ac4b98bb613d54fb2f257b3a737c0608f6898fcc8d71a58b4a6017e927a6f4`;
- live smoke test: passed.

## 16.1 Delivered Pass B behavior

- affirmative XP Aura is authoritative canonical metadata owned by discovery/parser results and Public Groups rows; it did not require LIST expansion;
- Aura shorthand is conservative and bounded to useful XP Aura candidate context;
- negated XP Aura, class/combat aura, and unrelated aura wording do not become affirmative XP Aura metadata;
- useful exact chat links receive the specific `- XP Aura` suffix;
- messages without a more specific exact activity link can receive the generic `[XP Aura]` fallback;
- Public Groups exposes a top `XP Aura (N)` additive filter button;
- XP Aura was not added as a new Type or transport/protocol category, and LIST remains through `p26`;
- Public Groups search normalizes its corpus and requires all whitespace-separated search tokens to match;
- existing Normal, Heroic, Mythic, Mythic+, role, Type, pagination, selected-row, and search behavior remains authoritative;
- Public Groups lazy-panel lifecycle, repeated-open reuse, control idempotence, and XP Aura count/highlight hydration are covered;
- Search label and layout corrections are retained;
- existing Runtime FPS, Marketplace, and Listing/Broadcast regressions remain green.

## 16.2 Pass B validation and handoff

The production-loaded Pass B harness covers positive and negative XP Aura
fixtures, parser precedence, generic and exact links, canonical Public Groups
rows, combined filters, normalized multi-token search, pagination, selected-row
clearing, lazy-panel reuse, control duplication, and the no-chat-send/no-new-
protocol constraints. Pass A compatibility coverage remains in the same CI
workflow.

Workflow #123 passed Lua 5.1 syntax, all applicable source verifiers, loader
preparation, Marketplace Create/Edit and regression harnesses, Runtime FPS
cleanup, Listing/Broadcast, Activity Discovery Pass A, Activity Discovery Pass
B, release validation, and package construction.

---

# 17. Deferred XP Aura UI polish

## 17.1 XP Aura additive-button interaction consistency

The current XP Aura button behavior is functionally correct and intentionally
different from the mutually exclusive Type buttons:

- the first click shows XP Aura-only rows;
- the second click returns to all permitted rows;
- repeated clicks toggle between those two states.

This is a future UI consistency/polish item, not a Pass B blocker. Future work
should make the additive-vs-mutually-exclusive distinction more visually
obvious without changing the underlying semantic model merely for visual
symmetry. Possible treatments include a visually distinct additive filter chip
or a clearer selected/off state. Do not implement this in PR #21.

---

# 18. Public Groups Discovery and Alerts Roadmap

The previous vague conditional Search Pass C is superseded by the concrete
follow-up sequence below. Pass C is complete and merged. Pass D is the active
feature round.

## 18.1 Public Groups World Boss Discovery and Recruiting Intent - Pass C

**Status: COMPLETE AND MERGED**

PR: #22

Merge SHA: `6413e99458828d6c1e8dabe62a401a4d0eb8636f`

Post-merge workflow: #133

Run ID: `30772837579`

Package job: `91562878553`

Artifact: `SignalFire-1.5.3`

Artifact ID: `8841072745`

Digest: `sha256:abb23c555e7741eb909b34d478c257aa972bd729a9b3f2e95c6bc34229311780`

Pass C makes Public Groups reliably identify the high-value group posts that
alerting will later consume. Pass D alerts and rules are out of scope for this
round and remain deferred.

### World Boss discovery robustness

Audit the historical World Boss parser behavior and use active server-profile
World Boss names and aliases as authoritative data. Do not create a separate
manually duplicated boss database when the active profile already owns these
names.

Add production-loaded regression fixtures including at minimum:

- `LF DPS Azuregos`;
- `LFM Azuregos need DPS`;
- `LFM Kazzak`;
- `LFM for Worldboss Tour Instance Loot FFA w/ me ilvl+spec start: Kazzak`.

Recognize appropriate concepts such as `world boss`, `worldboss`, `world boss
tour`, and known boss names/aliases, without treating arbitrary uses of
`boss` as World Boss. The missed Kazzak tour fixture must create a canonical
Public Groups row when it otherwise satisfies discovery rules.

Canonical World Boss rows should expose `Type = World Boss` and the correct
canonical activity/boss when known.

### World Boss filter

Expose a dedicated `World Boss (N)` Public Groups filter or an equally clear
final UX based on authoritative Type metadata. Do not hide World Boss rows only
inside a generic category.

### Recruiter versus seeker intent

Create or normalize canonical intent metadata distinguishing approximately:

- Recruiting / Hosting: `LFM`, `need healer`, `LF DPS Azuregos` when clearly a
  group seeking a player, `LF2 DPS`, `need tank/heals`, or a group with slots;
- Seeking Group: `LFG ZG`, `DPS LFG ZG`, or `healer looking for group`.

Do not implement this as a naive substring test where every `LF` means
Recruiting. Reuse and extend the authoritative intent parser so the canonical
row distinguishes a group that needs players from a player who needs a group.

### Recruiting-only filter

Add a Recruiting Only Public Groups filter/facet based on canonical intent.
Keep seeker rows discoverable and filterable; do not discard them globally.

### Mythic versus RDF discoverability

Audit whether the existing canonical Difficulty filter remains sufficient once
Recruiting intent exists. If needed, add a compact quick-filter/preset while
keeping Normal, Heroic, Mythic, and Mythic+ Difficulty as the single parser
owner. Do not invent a second Mythic classification system.

### Pass C closeout evidence

The exact production RC passed the live in-game smoke test. Closeout evidence:

- production RC: `0d6f3893f007b8b31b704cb2ec28bc1f4290a5a1`;
- workflow #131;
- run ID `30770089451`;
- package job `91555637086`;
- artifact `SignalFire-1.5.3`;
- artifact ID `8840222778`;
- artifact digest `sha256:5863a5efb41a823e25aea46a8628c2d86dc58b02c4702d1204b333f95553bdfd`;
- live smoke test: passed.

World Boss discovery is active-profile-owned with bounded aliases. Azuregos,
Lord Kazzak/Kazzak canonicalization, and profile-supported Snowgrave, Kaldros,
and Soggoth recognition are preserved, including multi-boss results. Generic
World Boss posts remain useful without inventing a boss name. The live Kazzak
Worldboss Tour fixture enters Public Groups, while guild precedence, raid
precedence, ordinary `boss` false-positive rejection, and Ascension/Triumvirate
profile isolation remain intact.

Canonical intent distinguishes Recruiter from Applicant: LFM and clear
role-recruitment posts are Recruiter, while LFG/looking-for-group posts are
Applicant. `LF DPS Azuregos` is a World Boss Recruiter result,
`DPS LFG Azuregos` is a World Boss Applicant result, and the `LFM ZG` versus
`LFG ZG` distinction remains covered.

Public Groups now exposes a first-class mutually-exclusive World Boss Type
filter with `World Boss (N)` counts, plus an Intent dropdown with All Intents,
Recruiting, and Seeking Group. Type, Intent, Difficulty, Role, Search, and XP
Aura intersections are covered; plain Mythic Recruiting remains isolated from
RDF and Mythic+. World Boss count/highlight hydration survives panel reuse and
controls remain idempotent through lifecycle reuse.

Compatibility and performance constraints remain preserved: the Lua 5.1
local-limit correction, LIST p3-p26, no permanent idle parser `OnUpdate`, one
authoritative parser path, no automatic public-channel joins, and green Pass A,
Pass B, Marketplace, Runtime FPS, and Listing/Broadcast regressions.

## 18.2 Pass D - Public Groups Alerts and Rules

**Status: ACTIVE**

Pass D is the active feature round now that Pass C has established reliable
canonical rows and intent.
Alerts must be driven by genuinely new or meaningfully changed canonical Public
Groups rows, never by raw chat substring matches.

### World Boss and recruiting-only alerts

- alert on a new matching World Boss recruiting row;
- support any-World-Boss rules and, where practical, individual boss enable/
  disable choices using active profile data;
- allow rules to require `Intent = Recruiting`, so `LFG ZG` does not alert but
  `LFM ZG need healer` can.

### Filter-aware rules and quick filters

Rules should be able to use canonical Type, Activity, Difficulty, Role,
Recruiting/Seeking intent, XP Aura when useful, and normalized search terms.
Support a simple custom keyword/quick rule such as `Azuregos`, `Kazzak`,
`world boss`, or `Mythic` before considering advanced query syntax. Do not
reparse raw chat independently inside alerts.

### Dedupe, cooldown, and rule controls

- dedupe repeated rebroadcasts using canonical row identity/generation and
  bounded cooldown ownership;
- do not play a sound for every equivalent repost;
- provide global alert enable/disable, a default/chosen sound, and per-rule
  enabled state;
- remain compatible with WoW 3.3.5 APIs.

### Alert safety and performance

Require authoritative canonical discovery before alerting. Preserve the
existing performance architecture: no permanent idle parser `OnUpdate`, no raw
full-table scan per chat line, bounded cache/dedupe ownership, hidden-panel
inactivity, one authoritative parser pass, and no duplicate ChatFrame parsing.

---

# 19. Planned Runtime FPS Cleanup Follow-Up

Runtime FPS Cleanup Pass A is complete, but a future evidence-driven performance pass remains planned.

Do not optimize speculatively.

Before another FPS pass:

1. Start from verified current `main`.
2. Capture current profiler/runtime evidence.
3. Separate SignalFire cost from:
   - Blizzard/default UI;
   - native client behavior;
   - other addons.
4. Rank SignalFire-owned hotspots by evidence.

Candidate investigation areas:

- remaining OnUpdate handlers;
- timer wakeups;
- duplicate refresh requests;
- hidden-panel refreshes;
- lazy-panel reconstruction;
- Public Groups render frequency;
- Browse render frequency;
- Network/Roster refresh frequency;
- chat wrapper/filter duplication;
- repeated normalization/parsing;
- repeated sorting/view builds;
- unnecessary row rewrites;
- dropdown/control reconstruction;
- SavedVariables writes on hot paths;
- callbacks around group state transitions.

The goal is not to remove every OnUpdate.

The goal is to remove unnecessary permanent work while idle.

Performance passes require:

- evidence before change;
- before/after counters where useful;
- production-loaded regression coverage;
- live FPS/stutter smoke testing.

---

# 20. UI Lifecycle Rules

When adding a new control to an existing lazy panel:

1. Identify the authoritative attachment owner.
2. Identify the final lazy-panel owner.
3. Ensure lazy reuse reconciles the control.
4. Ensure post-build paths reconcile the control.
5. Make attachment idempotent.
6. Separate control reconciliation from one-time hook installation.
7. Include required controls in readiness where appropriate.
8. Register dropdowns using the standard lifecycle.
9. Reuse named frames safely.
10. Exercise the real public `Show...` path in tests.

Do not seed fake production controls into the feature harness.

---

# 21. Shared WoW Harness Rules

The shared mock environment should emulate the APIs required by production behavior.

Prefer generic API-faithful mock improvements over feature-specific test hacks.

Example:

`UIDropDownMenu_SetWidth(frame, width)`

must propagate the requested width instead of remaining a no-op when geometry is under test.

Do not hard-code an Activity Discovery width inside the shared mock.

---

# 22. CI and Validation Standard

Every feature pass should run all applicable validation.

Normally:

- `git diff --check`;
- Lua syntax in GitHub Actions;
- feature-specific source verifier;
- all applicable existing Node/source verifiers;
- prepared loader generation;
- feature regression harness;
- Marketplace regression harnesses;
- Runtime FPS regression coverage;
- Listing/Broadcast regression coverage;
- release/package validation.

GitHub Actions is authoritative for Lua 5.1 executable harness validation when Lua 5.1 is unavailable locally.

Do not fabricate local Lua execution.

---

# 23. Green Build Handoff Standard

Whenever a pass reaches a testable green build, the project handoff must include:

1. exact ZIP artifact download;
2. exact commit SHA;
3. exact workflow run number and ID;
4. package job/artifact evidence;
5. pass name;
6. comprehensive step-by-step in-game test instructions;
7. expected result for each test;
8. a compact pass/fail response template;
9. what evidence to provide for failures;
10. next step after a pass;
11. next step after a failure.

The exact CI artifact must be tested.

Do not use a stale local addon folder.

Recommended clean test installation:

- exit WoW completely;
- remove/rename old SignalFire addon folder;
- extract exact CI artifact;
- install fresh SignalFire folder;
- launch WoW;
- verify version/profile;
- execute pass-specific smoke test.

---

# 24. Live Test Failure Handling

If a live smoke test fails, collect:

- numbered failed step;
- expected behavior;
- actual behavior;
- screenshot/video if visual;
- full Lua error if applicable;
- server profile;
- exact relevant listing/chat text.

Do not tell the user to work around the failure.

Investigate the exact production path before issuing another Codex correction.

Continue the same Codex chat for that feature round.

---

# 25. Live Test Pass Handling

When all pass-specific live tests succeed:

1. Record user acceptance.
2. Do not add new feature scope to that PR.
3. Finalize the PR.
4. Merge normally.
5. Verify merge SHA.
6. Verify post-merge `main` CI.
7. Verify package construction.
8. Clean the feature branch/worktree.
9. Preserve the reusable worktree.
10. Start the next feature pass only from verified `main`.

---

# 26. Versioning / Release Policy

Current version:

`1.5.3`

Do not automatically bump the version for every feature pass.

Do not create a tag or publish a release unless explicitly instructed.

PR CI may generate `SignalFire-1.5.3` artifacts for release-candidate testing.

Tagged release publication should remain skipped on ordinary PR runs.

---

# 27. Branch Safety

Before working:

- fetch;
- prune;
- verify branch;
- verify HEAD;
- verify main SHA;
- verify worktree cleanliness.

Avoid:

- force push;
- destructive reset;
- broad clean;
- history rewriting;
- unrequested rebase;
- unrequested squash;
- unrequested amend.

Never destroy unrelated local work.

---

# 28. Current Priority Order

Unless reprioritized by the user:

## Priority 1 — Public Groups Alerts and Rules — Pass D

Status:

- Pass C is complete and merged as PR #22;
- World Boss discovery and canonical Recruiting/Seeking intent are complete;
- Pass D is the active canonical-row alert-engine, rules UI, and regression pass.

## Priority 2 — Activity Discovery Pass B

Status:

- complete and merged;
- exact merged artifact passed CI and live smoke testing;
- use the closeout evidence in Section 16.

## Priority 3 — Public Groups Alerts and Rules follow-up

Status:

- Pass D is active in the reusable exact-links worktree;
- alert only from canonical Public Groups rows and intent metadata;
- use the requirements in Section 18.2.

## Priority 4 — Runtime FPS Cleanup follow-up

Evidence-driven performance work remains planned after the high-value discovery
and alert work unless measured regression requires it to move earlier.

## Priority 5 — Future user-approved work

Do not invent the next major feature automatically.

Reassess current `main` and user priorities after the planned discovery and
alert passes.

---

# 29. Definition of Done

A SignalFire pass is complete only when:

- implementation is scoped;
- production code is reviewed;
- source verifiers pass;
- production-loaded harnesses pass;
- full CI passes;
- exact CI artifact exists;
- user receives the exact ZIP;
- user receives step-by-step live-test instructions;
- exact artifact passes in-game testing;
- PR is finalized;
- PR merges;
- post-merge main CI passes;
- package construction passes;
- branch/worktree cleanup is complete;
- next pass starts from verified main.

---

# 30. Do-Not-Reopen List

Do not accidentally reopen:

- PR #19 Listing/Broadcast UX;
- Activity Discovery Pass B / PR #21 after closeout;
- Runtime FPS Cleanup Pass A;
- Marketplace Phase 2B;
- v1.4.33 UI/version consolidation;
- v1.4.34 version identity architecture.

Do not:

- restore permanent parser polling;
- overload `row.key`;
- change `Dire Maul - North` canonical spelling;
- merge plain Mythic with Mythic+ semantics;
- copy Ascension creation ownership into Triumvirate without evidence;
- add LIST `p27+`;
- automatically join public channels;
- restore the Global fallback;
- bypass the Phase 4 refresh scheduler simply to make a test synchronous.

---

# 31. Codex Reporting Standard

At the end of a task, report:

- starting HEAD;
- new commit SHA;
- exact changed files;
- root cause;
- production behavior changed;
- harness/test behavior changed;
- local validation;
- PR number/state/head;
- workflow run number;
- workflow run ID;
- package job ID;
- workflow conclusion;
- exact next assertion if failing;
- worktree status.

If CI fails, stop at the demonstrated failure unless explicitly told to continue.

---

# 32. Guiding Direction

SignalFire should continue becoming:

- more exact;
- easier to use;
- richer in useful activity metadata;
- easier to filter and search;
- safer across server profiles;
- more maintainable;
- better regression-tested;
- lower overhead while idle.

Every improvement must preserve:

- WoW 3.3.5 / Lua 5.1 compatibility;
- protocol contracts;
- server-profile distinctions;
- existing completed features;
- performance ownership;
- live-test discipline.

Favor narrow, evidence-driven passes over giant rewrites.
