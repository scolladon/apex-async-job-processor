# Move watcher anon-apex snippet — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Move the anonymous-apex snippet out of the `ApexJobWatcher.cls` header comment into an executable operator script at `scripts/apex/restart-watcher.apex`.

**Architecture:** Two-file change — one create, one modify. No code logic change, no test change.

**Tech Stack:** Apex source + filesystem.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-move-watcher-anon-apex-script.md`](../design/2026-04-19-move-watcher-anon-apex-script.md)

**Branch:** `chore/move-watcher-anon-apex-script` (from `main`).

---

## PR description template

```
## Summary
Extract the anon-apex snippet from the `ApexJobWatcher` header comment into
`scripts/apex/restart-watcher.apex` so operators can run it directly instead of
copy-pasting from a comment.

## Motivation
Executable instructions embedded in a `/** */` block at the top of a production
class drift silently when names change and require manual transcription before
use. Moving it to a dedicated script file makes it runnable and reviewable.

## Changes
- Create `scripts/apex/restart-watcher.apex` with the snippet.
- Delete lines 1–7 of `apex-job/src/engine/adapter/ApexJobWatcher.cls` (the
  `/** */` comment block).

## Test plan
- [x] `sfdx-project.json` inspected — `scripts/` is outside every packageDirectory, so the new file is never deployed.
- [x] `npm run prettier` — no formatting delta on touched files.
- [x] `npm run lint` — no new PMD warnings.
- [x] `npm run test:unit` — unchanged (no code logic touched).
```

---

### Task 1: Create the operator script

**Files:**
- Create: `scripts/apex/restart-watcher.apex`

**Step 1: Create the directory and script file**

```bash
mkdir -p scripts/apex
```

Create `scripts/apex/restart-watcher.apex` with the following content:

```apex
// Kill any existing "Async Job Watcher" cron triggers and reschedule fresh ones.
// Cron-job name literal: 'Async Job Watcher%' — must match ApexJobWatcher.schedule().
// Run with: sf apex run -f scripts/apex/restart-watcher.apex -o dev-async-processor

for (CronTrigger ct : [
  SELECT Id
  FROM CronTrigger
  WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'Async Job Watcher%'
]) {
  System.abortJob(ct.Id);
}
ApexJobWatcher.schedule();
```

### Task 2: Remove the comment block from the watcher class

**Files:**
- Modify: `apex-job/src/engine/adapter/ApexJobWatcher.cls`

**Step 1: Delete the header comment block**

Remove lines 1–7 (the `/** ... */` block containing the anon-apex snippet). The
file should now begin at the `@SuppressWarnings('PMD.ApexCRUDViolation')`
annotation (previously at line 9).

Before:

```apex
/**
 * Execute anonymously to kill and (re)schedule the job watcher
for(CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name Like 'Async Job Watcher%']) {
  System.abortJob(ct.Id);
}
ApexJobWatcher.schedule();
 */

@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobWatcher implements Schedulable {
```

After:

```apex
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobWatcher implements Schedulable {
```

### Task 3: Gate + commit

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

Expected: no new warnings; unit tests unchanged.

**Step 2: Commit**

```bash
git add scripts/apex/restart-watcher.apex apex-job/src/engine/adapter/ApexJobWatcher.cls
git commit -m "chore: move watcher restart snippet to scripts/apex/"
```

Commit body:

```
The anon-apex snippet previously lived inside a /** */ block at the top of
ApexJobWatcher.cls, which prevented direct execution and drifted silently
from reality when class or cron-job names changed. Moving it to a dedicated
script file under scripts/apex/ makes it runnable via `sf apex run -f`.

scripts/ is outside every sfdx-project.json packageDirectory, so the new
file is never deployed to orgs.
```

---

## Verification (done when)

- `scripts/apex/restart-watcher.apex` exists and is tracked.
- `ApexJobWatcher.cls` begins at the `@SuppressWarnings` annotation.
- `git log --oneline main..HEAD` shows exactly one commit.
- `git diff main..HEAD --stat` shows `+<N>` insertions (the new script) and `-7` deletions on the watcher class.
- CI passes.
