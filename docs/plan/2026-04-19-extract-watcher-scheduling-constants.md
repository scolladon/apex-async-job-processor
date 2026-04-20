# Extract watcher scheduling constants — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the literal `60` and `5` in `ApexJobWatcher.schedule()` with named constants on `ApexJobConstant`.

**Architecture:** Constant extraction. No logic change, no test change.

**Tech Stack:** Apex source only.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-extract-watcher-scheduling-constants.md`](../design/2026-04-19-extract-watcher-scheduling-constants.md)

**Branch:** `refactor/extract-watcher-scheduling-constants` (from `main`).

---

## PR description template

```
## Summary
Extract the literal `60` and `5` used in `ApexJobWatcher.schedule()` into named
constants `MINUTES_PER_HOUR` and `WATCHER_INTERVAL_MINUTES` on `ApexJobConstant`.

## Motivation
The literals are semantically meaningful ("60 minutes per hour", "5-minute
watcher cadence") but the code expresses neither. Named constants let the loop
read as its own comment and match the convention already used by
`DEFAULT_MAX_CHUNK_SIZE` and `RATE_WINDOW_MS`.

## Changes
- Add two constants to `ApexJobConstant.cls`.
- Update the `for` loop in `ApexJobWatcher.schedule()` to reference them.

## Test plan
- [x] `npm run prettier` — no delta outside the touched files.
- [x] `npm run lint` — no new PMD warnings.
- [x] `npm run test:unit` — `ApexJobWatcherTest` still asserts 12 scheduled triggers.
```

---

### Task 1: Add the new constants

**Files:**
- Modify: `apex-job/src/engine/domain/classes/ApexJobConstant.cls`

**Step 1: Append two constants**

Insert the following lines after the existing `UNKNOWN_SAFETY` declaration (after
line 8), keeping a blank line for grouping:

```apex
  public static final Integer MINUTES_PER_HOUR = 60;
  public static final Integer WATCHER_INTERVAL_MINUTES = 5;
```

Full file after change:

```apex
public without sharing class ApexJobConstant {
  public static final Integer UNKNOWN_MAX_CHUNK_SIZE = -1;
  public static final Integer DEFAULT_MAX_CHUNK_SIZE = 50;
  public static final Long RATE_WINDOW_MS = 60 * 1000L;

  public static final Decimal UNKNOWN_BASE_CONSUMPTION = 0;
  public static final Decimal UNKNOWN_PERITEM_CONSUMPTION = 0;
  public static final Decimal UNKNOWN_SAFETY = 0.74;

  public static final Integer MINUTES_PER_HOUR = 60;
  public static final Integer WATCHER_INTERVAL_MINUTES = 5;
}
```

### Task 2: Reference the constants in the watcher

**Files:**
- Modify: `apex-job/src/engine/adapter/ApexJobWatcher.cls`

**Step 1: Replace the loop literals**

In `ApexJobWatcher.schedule()`, change:

```apex
// Schedule the job to run every 5 minutes
for (Integer i = 0; i < 60; i += 5) {
  System.schedule(String.format(cronJobNameTemplate, new List<Object>{ cronJobBaseName, ('0' + i).right(2) }), '0 ' + i + ' * ? * * *', new ApexJobWatcher());
}
```

to:

```apex
for (Integer i = 0; i < ApexJobConstant.MINUTES_PER_HOUR; i += ApexJobConstant.WATCHER_INTERVAL_MINUTES) {
  System.schedule(String.format(cronJobNameTemplate, new List<Object>{ cronJobBaseName, ('0' + i).right(2) }), '0 ' + i + ' * ? * * *', new ApexJobWatcher());
}
```

The inline `// Schedule the job to run every 5 minutes` comment is redundant once
the interval is named — delete it. The cron expression `'0 ' + i + ' * ? * * *'`
is unchanged.

### Task 3: Gate + commit

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

Expected:
- prettier: no formatting delta.
- lint: no new PMD warnings.
- unit tests: `ApexJobWatcherTest` still passes — the 12-trigger assertion is
  unaffected because `MINUTES_PER_HOUR / WATCHER_INTERVAL_MINUTES = 60 / 5 = 12`.

**Step 2: Commit**

```bash
git add apex-job/src/engine/domain/classes/ApexJobConstant.cls apex-job/src/engine/adapter/ApexJobWatcher.cls
git commit -m "refactor(watcher): name scheduling loop constants"
```

Commit body:

```
Replace the literal 60 and 5 in ApexJobWatcher.schedule() with
MINUTES_PER_HOUR and WATCHER_INTERVAL_MINUTES on ApexJobConstant.

Matches the existing convention (DEFAULT_MAX_CHUNK_SIZE, RATE_WINDOW_MS
already live there) and makes the loop read as its own intent. Behavior
unchanged: 60 / 5 = 12 cron triggers per hour.
```

---

## Verification (done when)

- `ApexJobConstant.cls` gains two lines.
- `ApexJobWatcher.cls` has no literal `60` or `5` in its body (grep to confirm).
- `ApexJobWatcherTest` passes without modification.
- `git log --oneline main..HEAD` shows exactly one commit.
- CI passes.
