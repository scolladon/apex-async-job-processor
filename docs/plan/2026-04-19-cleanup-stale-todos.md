# Cleanup stale TODO comments — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove two misleading `// TODO` comments that reference a rejected future refactor.

**Architecture:** Pure comment deletion. No code, test, or metadata changes.

**Tech Stack:** Apex source edits only.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-cleanup-stale-todos.md`](../design/2026-04-19-cleanup-stale-todos.md)

**Branch:** `chore/cleanup-stale-todos` (from `main`).

---

## PR description template

```
## Summary
Remove two stale `// TODO` comments in the engine that reference a domain-extraction
refactor which has been evaluated and rejected.

## Motivation
The comments are misleading — the referenced domain classes do not exist and are
not planned — and they violate the repo's "no dead comments" guideline in CLAUDE.md.

## Changes
- Delete `// TODO Part of the JobDescription domain` from `JobExecutable.cls`.
- Delete `// TODO part of the JobRequest Domain` from `JobRepositoryImpl.cls`.

The third TODO at `JobExecutable.cls:58` is intentionally preserved; it will be
removed by an upcoming PR that refactors the annotated method.

## Test plan
- [x] `npm run prettier` — no formatting delta.
- [x] `npm run lint` — no new PMD warnings.
- [x] `npm run test:unit` — full suite passes (no code change, so no behavioral impact expected).
```

---

### Task 1: Remove the two stale TODO comments

**Files:**
- Modify: `apex-job/src/engine/domain/classes/JobExecutable.cls`
- Modify: `apex-job/src/engine/adapter/JobRepositoryImpl.cls`

**Step 1: Delete the JobDescription TODO**

In `apex-job/src/engine/domain/classes/JobExecutable.cls`, remove the single-line
comment at line 36:

```apex
  // TODO Part of the JobDescription domain
  private static ApexJob getProcessor(final JobDescription__c jobDescription) {
```

becomes:

```apex
  private static ApexJob getProcessor(final JobDescription__c jobDescription) {
```

**Step 2: Delete the JobRequest TODO**

In `apex-job/src/engine/adapter/JobRepositoryImpl.cls`, remove the single-line
comment at line 92:

```apex
  // TODO part of the JobRequest Domain
  private static Boolean shouldDeleteJobRequest(final JobRequest__c jobRequest) {
```

becomes:

```apex
  private static Boolean shouldDeleteJobRequest(final JobRequest__c jobRequest) {
```

**Step 3: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

Expected:
- prettier: no file reformatted.
- lint: no new warnings.
- unit tests: all pass (identical set as before this change).

**Step 4: Commit**

```bash
git add apex-job/src/engine/domain/classes/JobExecutable.cls apex-job/src/engine/adapter/JobRepositoryImpl.cls
git commit -m "chore: remove stale TODO comments from engine"
```

Commit body (pasted via HEREDOC):

```
Both comments referenced a planned "move into a domain class" refactor that
has been evaluated and is not going to happen. Removing them rather than
leaving misleading guidance in the codebase.

The third TODO in JobExecutable.cls is intentionally left in place; it is
addressed by the upcoming safe-argument-deserialization change.
```

---

## Verification (done when)

- Working tree shows only the two comment deletions.
- `git log --oneline main..HEAD` shows exactly one commit with the subject above.
- No test file was touched.
- CI (once PR is opened) passes.
