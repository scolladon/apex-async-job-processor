# Extract LimitService buffer constant — Design

`LimitServiceImpl.cls:2` declares a private `BUFFER_COEFFICIENT = 0.97`, applied
to `cpuTime` and `heapSize` headroom in `getAvailableLimits()` (lines 55–56).
Two issues:

1. **Value duplication.** `LimitServiceImplTest.cls:126` re-hardcodes the literal
   `0.97` inside the expected-value calculation. If the constant ever changes,
   the test silently keeps asserting against the old value.
2. **Comment-vs-value drift.** The same test file contains two comments claiming
   the buffer is a "20 % reduction" (lines 123 and 128) while the actual
   multiplier `0.97` corresponds to a **3 % reduction**. Either the code is
   wrong or the comments are wrong — the test's numeric assertion uses `0.97`
   and passes, so the test binding is consistent; only the comment is adrift.

This change promotes the constant to `ApexJobConstant`, points both the
production class and the test at the promoted constant, and fixes the comment
drift. The numeric value (`0.97`, 3 % buffer) is preserved — see Open Questions
for the rationale.

## Behavior

No runtime change. `getAvailableLimits()` returns exactly the same `cpuTime` and
`heapSize` headroom values as before.

## Data Model

None — new constant lives in an Apex class, not on an SObject.

## Algorithm / Logic

None — a single multiplier (`0.97`) relocates from a class-local static to
`ApexJobConstant`. Applied identically in the two existing call sites.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Constants | `apex-job/src/engine/domain/classes/ApexJobConstant.cls` | Add `public static final Decimal AVAILABLE_LIMITS_BUFFER = 0.97;`. |
| Limit service | `apex-job/src/engine/service/LimitServiceImpl.cls` | Remove the local `BUFFER_COEFFICIENT` (line 2). Reference `ApexJobConstant.AVAILABLE_LIMITS_BUFFER` in lines 55 and 56. |
| Test | `apex-job/test/unit/classes/LimitServiceImplTest.cls` | Replace hardcoded `0.97` (line 126) with `ApexJobConstant.AVAILABLE_LIMITS_BUFFER`. Fix both "20 %" comment mentions (lines 123, 128) to reflect the actual 3 % buffer. |

## Edge cases

- **No consumer exists outside this class today.** Grep confirms `BUFFER_COEFFICIENT`
  is referenced only in `LimitServiceImpl.cls` itself and by comment drift in the
  test. Moving it is safe.
- **Prettier may reflow the test assertion line** if the reference becomes longer
  than the print width. Handled by `npm run prettier` in the gate step.

## Rollback

`git revert <commit-sha>` restores the local constant, the duplicate literal in
the test, and the (misleading) 20 % comments. No data migration, no consumer
impact.

## Open questions

None. This PR commits to `0.97` (3 % buffer) as the correct value: the
consumption model already applies a separate per-`JobDescription__c` safety
factor (`UNKNOWN_SAFETY = 0.74`, `MAX_SAFETY = 0.98`) on top of the system
headroom, so layering a conservative 20 % system buffer on top would compound
the discount and collapse throughput. The "20 %" wording in the existing test
comment is therefore treated as a bug; both it and the numeric literal are
corrected to match the 3 % actually implemented. If a follow-up benchmark
demonstrates the buffer needs to change, that is a separate PR with its own
functional-test throughput evidence.
