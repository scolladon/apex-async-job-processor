# Extract LimitService buffer constant — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Promote `LimitServiceImpl.BUFFER_COEFFICIENT` to `ApexJobConstant.AVAILABLE_LIMITS_BUFFER`, point both the production class and its test at the promoted constant, and correct the misleading "20 %" comment in the test.

**Architecture:** Constant promotion + test tightening. Numeric value preserved (0.97 → 3 % buffer).

**Tech Stack:** Apex source + Apex test source.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-extract-limit-service-buffer-constant.md`](../design/2026-04-19-extract-limit-service-buffer-constant.md)

**Branch:** `refactor/extract-limit-service-buffer-constant` (from `main`).

---

## PR description template

```
## Summary
Promote the `BUFFER_COEFFICIENT = 0.97` from `LimitServiceImpl` to
`ApexJobConstant.AVAILABLE_LIMITS_BUFFER`, point the test at the promoted
constant, and fix the `LimitServiceImplTest` comments that claimed a "20 %
reduction" when the multiplier is actually 3 %.

## Motivation
- Two sources of truth (class constant + hardcoded literal in the test) drift
  silently on every change.
- The test comment and the code disagree by a factor of 7 (20 % vs 3 %). The
  test's numeric assertion is right; the comment is wrong.

## Changes
- `ApexJobConstant.cls`: new `AVAILABLE_LIMITS_BUFFER` decimal constant.
- `LimitServiceImpl.cls`: remove local `BUFFER_COEFFICIENT`, reference the
  promoted constant at both usage sites.
- `LimitServiceImplTest.cls`: replace hardcoded `0.97` with the constant, fix
  both "20 %" comments to "3 %".

## Test plan
- [x] `npm run prettier` — no delta outside touched files.
- [x] `npm run lint` — no new PMD warnings.
- [x] `npm run test:unit` — `LimitServiceImplTest.givenLimitServiceImpl_whenGetAvailableLimits_thenReturnsLimitsWithBuffer` still passes (value unchanged).

## Open question flagged to reviewers
Is `0.97` (3 %) the intended buffer value, or was the "20 %" wording a stale
record of an earlier intent? This PR preserves `0.97`; a follow-up can adjust
the number if reviewers confirm a different target.
```

---

### Task 1: Add the promoted constant

**Files:**
- Modify: `apex-job/src/engine/domain/classes/ApexJobConstant.cls`

**Step 1: Append the constant**

Insert after the existing `UNKNOWN_SAFETY` line:

```apex
  public static final Decimal AVAILABLE_LIMITS_BUFFER = 0.97;
```

Place the new line in the `UNKNOWN_*` grouping (it's conceptually close to
`UNKNOWN_SAFETY` — both are multiplier-style scalars applied to limit math).

### Task 2: Point LimitServiceImpl at the promoted constant

**Files:**
- Modify: `apex-job/src/engine/service/LimitServiceImpl.cls`

**Step 1: Remove the local constant**

Delete line 2:

```apex
  private static final Decimal BUFFER_COEFFICIENT = 0.97;
```

**Step 2: Update both call sites**

Lines 55 and 56 currently read:

```apex
    result.cpuTime = (Integer) (baseCpuTime * BUFFER_COEFFICIENT);
    result.heapSize = (Integer) (baseHeapSize * BUFFER_COEFFICIENT);
```

Replace with:

```apex
    result.cpuTime = (Integer) (baseCpuTime * ApexJobConstant.AVAILABLE_LIMITS_BUFFER);
    result.heapSize = (Integer) (baseHeapSize * ApexJobConstant.AVAILABLE_LIMITS_BUFFER);
```

### Task 3: Point the test at the promoted constant + fix comment drift

**Files:**
- Modify: `apex-job/test/unit/classes/LimitServiceImplTest.cls`

**Step 1: Fix both "20 %" comments**

Line 123 currently reads:

```apex
    // Assert - Verify buffer is applied (approximately 20% reduction, allowing for rounding)
```

Replace with:

```apex
    // Assert - Verify buffer is applied (approximately 3% reduction, allowing for rounding)
```

Line 128 currently reads (substring):

```apex
    Assert.isTrue(expectedCpuTime - result.cpuTime <= 10, 'CPU time should be approximately reduced by 20% buffer. Expected: ' + expectedCpuTime + ', Actual: ' + result.cpuTime);
```

Replace the message portion with:

```apex
    Assert.isTrue(expectedCpuTime - result.cpuTime <= 10, 'CPU time should be approximately reduced by the AVAILABLE_LIMITS_BUFFER. Expected: ' + expectedCpuTime + ', Actual: ' + result.cpuTime);
```

**Step 2: Replace the hardcoded literal**

Line 126 currently reads:

```apex
    Integer expectedCpuTime = (Integer) (availableCpuTime * 0.97);
```

Replace with:

```apex
    Integer expectedCpuTime = (Integer) (availableCpuTime * ApexJobConstant.AVAILABLE_LIMITS_BUFFER);
```

**Step 3: Verify the test name still reflects intent**

The test method is `givenLimitServiceImpl_whenGetAvailableLimits_thenReturnsLimitsWithBuffer`
— "with buffer" matches the corrected comment. No rename needed.

### Task 4: Gate + commit

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

Expected:
- prettier: may reflow line 126/128 due to length; accept the reflow.
- lint: no new PMD warnings.
- unit tests: `LimitServiceImplTest` passes — the numeric assertion is unchanged,
  only the source of the multiplier moved.

**Step 2: Commit**

```bash
git add apex-job/src/engine/domain/classes/ApexJobConstant.cls apex-job/src/engine/service/LimitServiceImpl.cls apex-job/test/unit/classes/LimitServiceImplTest.cls
git commit -m "refactor(limit-service): promote buffer constant to ApexJobConstant"
```

Commit body:

```
BUFFER_COEFFICIENT was duplicated between LimitServiceImpl and its test, and
the test comments claimed a 20% reduction while the actual multiplier 0.97
applies a 3% reduction. Promoting the constant to ApexJobConstant removes the
duplication; correcting the comments removes the drift.

Numeric value (0.97) preserved. A reviewer-visible open question on the
intended buffer target is raised in the design doc.
```

---

## Verification (done when)

- `grep -rn "BUFFER_COEFFICIENT" apex-job/` returns zero matches.
- `grep -rn "AVAILABLE_LIMITS_BUFFER" apex-job/` returns at least four matches (one declaration, two in `LimitServiceImpl`, one in the test).
- `grep -rn "20%" apex-job/` returns zero matches (the misleading comment has been corrected).
- `grep -n "20%" apex-job/test/unit/classes/LimitServiceImplTest.cls` returns zero matches.
- Unit test suite passes.
- `git log --oneline main..HEAD` shows exactly one commit.
- CI passes.
