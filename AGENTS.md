# SignalFire Codex Instructions

This file contains standing repository instructions for Codex and other coding agents working on SignalFire.

Read this file before making changes. Then read `docs/SIGNALFIRE_MASTER_PLAN.md` for the current roadmap, completed milestones, active pass, planned passes, and historical architecture decisions.

## Project

- Repository: `joshxor/SignalFire`
- Default branch: `main`
- Current addon version: `1.5.3`
- Target client: World of Warcraft 3.3.5
- Production language compatibility: Lua 5.1
- Primary reusable feature worktree:
  `C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-2b-exact-links`
- Normal repository:
  `C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-main`
- Separate older Network worktree:
  `C:\Users\joshx\OneDrive\Documents\SignalFire\SignalFire-2a-network-sync`

Do not assume branch, SHA, or worktree state from prior context. Fetch/prune and verify exact state before work.

## Scope Discipline

SignalFire is developed through narrow feature passes.

Do not implement the whole roadmap in one branch.

For every task:

1. Identify the requested pass.
2. Read the relevant section of `docs/SIGNALFIRE_MASTER_PLAN.md`.
3. Inspect the current production owner before editing.
4. Change only what is required for the pass.
5. Add or update production-loaded regression coverage.
6. Validate before committing.
7. Stop at the exact demonstrated CI failure rather than stacking speculative fixes.

Do not reopen completed passes unless a demonstrated regression requires it.

## Compatibility

All production Lua must remain compatible with:

- WoW 3.3.5 APIs, or explicit compatibility shims already used by the project.
- Lua 5.1 syntax and semantics.

Do not introduce modern Lua syntax or retail-only WoW APIs without a compatible implementation.

## LIST Packet Contract

The established LIST packet layout currently extends through `p[26]`.

Important positions:

- `p21` = Tank
- `p22` = Healer
- `p23` = DPS
- `p24` = Support
- `p25` = minimum level
- `p26` = maximum level

Do not:

- add `p27+` without an explicitly approved protocol migration;
- reorder existing packet fields;
- silently repurpose established packet positions.

Internal BLFG transport remains authoritative.

Do not automatically join public channels.

Do not restore the removed Global public-broadcast fallback.

Do not change Marketplace, applicant, exact-link, or Network presence protocols inside unrelated feature passes.

## Server Profiles

Preserve server-profile distinctions.

Ascension and Triumvirate are not interchangeable.

Current Ascension creation ownership includes:

- ordinary Dungeon: Normal, Heroic, plain Mythic;
- dedicated Mythic+ activity: keyed Mythic+.

Plain Mythic is not Mythic+.

Do not copy Ascension-specific behavior into Triumvirate without evidence and explicit scope.

## Public Groups Identity and Keystone Metadata

The established ownership contract is:

- `listing.key` = listing Mythic+ keystone level;
- `parsed.keyLevel` = canonical parsed keystone level;
- `row.key` = stable Public Groups row identity/index key;
- `row.keyLevel` = discovered Public Groups Mythic+ keystone level.

Never overload `row.key` with keystone level again.

Canonical `Dire Maul - North` spelling, including the hyphen, is authoritative.

## Performance Architecture

Existing performance ownership is intentional.

SignalFire uses:

- deferred work;
- dirty-state ownership;
- debounced/batched refreshes;
- lazy panel construction;
- bounded worker frames;
- idle workers that sleep when there is no work.

Do not add a permanent parser `OnUpdate` while idle.

Do not bypass a production debounce/scheduler merely to make a test synchronous.

When a harness needs to observe a debounced result, drive the real production scheduler.

Do not reintroduce broad hidden-panel refreshes or unnecessary polling removed by Runtime FPS Cleanup.

## Public Groups UI Lifecycle

When adding controls to a lazy panel:

- identify the final production owner;
- ensure final lazy lifecycle reuse can reconcile the control;
- keep attachment idempotent;
- prevent duplicate hooks and duplicate controls;
- include required controls in readiness when appropriate;
- register dropdowns through the standard UI lifecycle;
- safely reuse named WoW frames;
- test through the real `Show...` lifecycle rather than pre-seeding fake controls.

For Public Groups, the established Difficulty control attachment owner is:

`SignalFirePublicGroupsView151.AttachPanel`

## Harness Discipline

A failing harness is not automatically a production defect.

Before changing production, determine whether the failure comes from:

- real production behavior;
- incorrect test state;
- incorrect timing assumptions;
- stale canonical expectations;
- incomplete WoW API mocks;
- an obsolete owner assumption.

Fix harness defects as harness defects.

Do not weaken valid assertions just to make CI green.

Do not distort production behavior to satisfy an inaccurate mock.

Shared WoW mocks should emulate the relevant API contract generically, not hard-code feature-specific values.

## Validation

Run all applicable validation for the current pass.

Expected checks normally include:

- `git diff --check`;
- feature-specific source verifier;
- all applicable repository Node/source verifiers;
- loader preparation;
- release validation;
- Lua 5.1 syntax/harness execution in GitHub Actions;
- existing Marketplace regression coverage;
- Runtime FPS Cleanup regression coverage;
- Listing/Broadcast regression coverage;
- current feature harness.

If Lua 5.1 is unavailable locally, report that honestly. Do not fabricate a local Lua result.

## CI Failure Handling

After pushing:

1. Inspect the exact replacement workflow for the pushed SHA.
2. If CI fails, report the exact failing assertion/log evidence.
3. Stop there unless explicitly instructed to continue.
4. Do not add another speculative fix in the same response.

Sequential new assertions after previous assertions pass are expected and do not by themselves imply the same root problem is unresolved.

## Green Build / Live Test Gate

A green CI build is not permission to merge automatically.

For a testable feature build:

1. Verify the exact CI SHA.
2. Verify the exact workflow run.
3. Verify package construction.
4. Preserve/provide the exact `SignalFire-<version>` artifact for live testing.
5. Do not merge until the user confirms the exact artifact passed the pass-specific in-game smoke test.

Documentation-only commits after an already approved production artifact do not invalidate the prior production smoke test, provided production Lua/package contents relevant to behavior are unchanged and CI remains green.

## Merge and Cleanup

After explicit live-test approval:

1. Finalize the PR.
2. Mark ready when appropriate.
3. Merge normally.
4. Record the exact merge SHA.
5. Verify post-merge `main` CI.
6. Verify package construction on `main`.
7. Clean feature branch/worktree state.
8. Preserve the reusable `SignalFire-2b-exact-links` worktree.

Do not:

- force-push;
- rewrite history;
- rebase/squash/amend unless explicitly requested;
- broadly clean or reset unrelated local work;
- delete the reusable feature worktree without a specific reason.

## Versioning

Current version is `1.5.3`.

Do not bump the addon version, create a tag, or publish a release merely because a feature PR exists.

Ordinary PR CI may build an artifact using the current version for RC testing.

Tagged release publication should remain skipped unless explicitly authorized.

## Completed Work That Must Not Be Reopened Accidentally

See `docs/SIGNALFIRE_MASTER_PLAN.md` for details.

Completed milestones include:

- v1.4.33 UI / Version Consolidation;
- v1.4.34 Compatibility / Performance;
- Marketplace Phase 2B / PR #17;
- Runtime FPS Cleanup Pass A / PR #18;
- Listing and Broadcast UX Pass A / PR #19.

Activity Discovery Pass A / PR #20 has passed automated CI and live in-game testing and is awaiting controlled closeout/merge at the time this file was introduced.

## Codex Reporting

At the end of an implementation/correction, report:

- starting HEAD;
- new commit SHA;
- exact files changed;
- root cause;
- production behavior changed;
- harness/test behavior changed;
- local validation results;
- PR number/state/head;
- workflow run number;
- workflow run ID;
- package job ID;
- workflow conclusion;
- exact next assertion if failing;
- worktree status.

## Guiding Principle

Prefer narrow, evidence-driven changes over broad rewrites.

SignalFire should become more exact, useful, searchable, maintainable, and performant while preserving:

- WoW 3.3.5 / Lua 5.1 compatibility;
- protocol contracts;
- server-profile distinctions;
- completed functionality;
- idle-performance architecture;
- regression-test coverage.
