# Rename finalizer kill predicate — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rename `AsyncApexJobExecutor.shouldTreatException` to `wasLastChunkKilled` and its `ctx` parameter to `finalizerContext`.

**Architecture:** Private-method rename inside a single class. No behavior change, no test change.

**Tech Stack:** Apex source only.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-rename-finalizer-kill-predicate.md`](../design/2026-04-19-rename-finalizer-kill-predicate.md)

**Branch:** `refactor/rename-finalizer-kill-predicate` (from `main`).

---

## PR description template

```
## Summary
Rename the private finalizer predicate `shouldTreatException` to
`wasLastChunkKilled` so its name describes what it actually answers.

## Motivation
"shouldTreatException" reads as "should we treat this exception" — the real
semantic is "was the last chunk killed by the platform before its result could
be recorded". The rename lets the call site in `execute(FinalizerContext)` read
as its own explanation.

## Changes
- Declaration renamed in `AsyncApexJobExecutor.cls`.
- Single call site updated.
- Parameter renamed from `ctx` to `finalizerContext` for consistency with the
  caller-side variable name.

## Test plan
- [x] `npm run prettier` — no delta outside the touched file.
- [x] `npm run lint` — no new PMD warnings.
- [x] `npm run test:unit` — unchanged (private method, no tests reference it).
```

---

### Task 1: Rename the predicate and its parameter

**Files:**
- Modify: `apex-job/src/engine/application/AsyncApexJobExecutor.cls`

**Step 1: Rename the call site (line 57)**

Before:

```apex
      if (this.shouldTreatException(finalizerContext)) {
```

After:

```apex
      if (this.wasLastChunkKilled(finalizerContext)) {
```

**Step 2: Rename the declaration + parameter (line 84)**

Before:

```apex
  private Boolean shouldTreatException(FinalizerContext ctx) {
    return ctx?.getResult() == ParentJobResult.UNHANDLED_EXCEPTION && this.lastExecutableJob != null;
  }
```

After:

```apex
  private Boolean wasLastChunkKilled(final FinalizerContext finalizerContext) {
    return finalizerContext?.getResult() == ParentJobResult.UNHANDLED_EXCEPTION && this.lastExecutableJob != null;
  }
```

Three changes in this step: method name, parameter name (`ctx` → `finalizerContext`),
and `final` modifier added to the parameter (consistent with the repo's code style
per `CLAUDE.local.md` — "Use `final` for variables and parameters").

**Step 3: Verify no other references**

```bash
grep -rn "shouldTreatException" apex-job/
```

Expected: zero matches. If any are found (unexpected), update them in the same
commit.

### Task 2: Gate + commit

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

Expected:
- prettier: no formatting delta.
- lint: no new PMD warnings.
- unit tests: `AsyncApexJobExecutorTest` unchanged — private method rename is
  invisible to tests.

**Step 2: Commit**

```bash
git add apex-job/src/engine/application/AsyncApexJobExecutor.cls
git commit -m "refactor(async-executor): rename shouldTreatException predicate"
```

Commit body:

```
The predicate answered "was the last chunk killed before we could record it",
not "should we treat an exception". Renaming aligns the name with the behavior
and makes the finalizer body self-explanatory.

Parameter also renamed from `ctx` to `finalizerContext` to match the caller-side
variable and receive the `final` modifier.
```

---

## Verification (done when)

- `grep -rn "shouldTreatException" apex-job/` returns zero matches.
- `grep -n "wasLastChunkKilled" apex-job/src/engine/application/AsyncApexJobExecutor.cls` returns exactly two matches (declaration + call site).
- `git log --oneline main..HEAD` shows exactly one commit.
- Unit test suite passes unchanged.
- CI passes.
