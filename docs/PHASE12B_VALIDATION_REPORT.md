# Phase 12B Validation Report

## Scope

Phase 12B preserves the Phase 12A cache-lifecycle correction and changes only Public Groups chat option gating, source ingestion, candidate rejection, parser queue/worker ownership, canonical chat upsert ownership, display-filter registration, render decisions, diagnostics, tests, and RC metadata.

## Before and After

Before Phase 12B, the final ChatFrame filter could call `p3_resolve`, which could call `TestParse`, create queue work, and prepare listing identity while a message was being delivered to receiving chat frames. Links were checked too late.

After Phase 12B, source events gate and enqueue once. `TestParse` runs only in the sleeping bounded worker. Canonical chat mutations use the Phase 5 index. Optional filters only retrieve completed immutable strings. Parsing Off and Links Off both produce zero Public Groups filters.

## External Field Evidence

An affected player reported approximately 19 FPS before the partial Phase 12A hotfix and approximately 35-38 FPS with it. This supports the conclusion that chat-triggered cache cleanup was a significant real-world component. The partial package did not include the final Phase 12B parser/filter architecture, and performance did not return to normal.

This is external field evidence, not harness validation and not confirmation that Phase 12B fixes the remaining loss. Comparable testing by the same affected player is required.

## Harness Results

- Lua 5.1 parsing: required for every TOC Lua file and changed test harness.
- Parser regression: 33 passed, 0 skipped, 0 failed.
- Parsing-Off stress: 100,000 messages with zero candidate, parser, queue, filter, rewrite, and worker activity.
- Links-Off stress: four 50,000-message runs at 1, 2, 5, and 10 receiving frames; each produced 500 `TestParse` calls and 500 queue records, with zero filters.
- Links-On stress: the same matrix retained 500 parser calls and queue records. Filter receipts were 50,000, 100,000, 250,000, and 500,000 respectively.
- Worker burst: queue capped at 40, deterministic drops counted, and no active frame processed more than four records.
- Toggle lifecycle: 100 parsing/link transitions retained 0/0/3 filters in the required states.
- Canonical live path: historical full-table duplicate scans remained zero.
- Native hyperlinks and foreign `SetItemRef`/`AddMessage` ownership remained unchanged in the harness.

## Remaining Risk

WoW 3.3.5 does not expose live filter-list introspection, so registration count is the final owner's known state rather than independent client enumeration. The harness cannot reproduce Ascension's renderer, ElvUI timing, server traffic, or real frame-time behavior. The first uncached line may be plain by design. Final acceptance requires the staged affected-player field test.
