# Prevent finalizer double-record — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate the double-record window between a successful chunk `add` and the pointer clear in `AsyncApexJobExecutor`. The finalizer derives "already recorded?" from `jobExecutionResults` rather than from a separate flag.

**Architecture:** Invariant shift — `lastExecutableJob` stops being cleared on success; `wasLastChunkKilled` consults the list instead. `JobExecuted` grows a public read-only `executable` field so the identity check is direct.

**Tech Stack:** Apex source + Apex Mockery tests.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-prevent-finalizer-double-record.md`](../design/2026-04-19-prevent-finalizer-double-record.md)

**Branch:** `fix/prevent-finalizer-double-record` (from `main`).

**Preconditions:** **Must** be applied after `refactor/rename-finalizer-kill-predicate` (pair #4) has merged. This plan's Task 3 Step 2 rewrites the body of `wasLastChunkKilled`; if pair #4 has not landed, the method is still called `shouldTreatException` on `main` and this branch will either (a) include the rename in Task 3 Step 1 as a prerequisite edit, or (b) stop and wait for pair #4 to merge. Verify with: `grep -n "wasLastChunkKilled\|shouldTreatException" apex-job/src/engine/application/AsyncApexJobExecutor.cls` — if `shouldTreatException` is present, apply the rename first.

---

## PR description template

```
## Summary
Fix the race condition in `AsyncApexJobExecutor.execute(QueueableContext)` that
can cause a single chunk to be persisted twice — once as SUCCESS and once as
KILLED — when the platform terminates the Queueable between `.add()` of the
result and the subsequent pointer clear.

## Motivation
Between `jobExecutionResults.add(executionResult)` and
`this.lastExecutableJob = null`, a CPU-tick or heap `LimitException` raised by
the next statement (typically the logger call) leaves the executor in a state
where the finalizer gate `wasLastChunkKilled` returns true even though the
chunk is already in the list. The finalizer then appends a second KILLED
result; the consumption learner runs `adjustFromSuccess` followed by
`adjustFromKill` on the same `JobDescription__c`, corrupting the learned
model.

## Changes
- Stop clearing `lastExecutableJob` on success — the list becomes the source
  of truth for "was it recorded".
- Expose `JobExecuted.executable` (public read-only field) so the finalizer
  can identity-compare the last recorded executable against the in-flight
  pointer.
- Rewrite `wasLastChunkKilled` as a list-consulting idempotent predicate.

## Test plan
- [x] New unit tests cover the three branches of the new predicate (empty list, already-recorded, not-recorded).
- [x] Existing `AsyncApexJobExecutorTest` cases still pass.
- [x] `npm run prettier`, `npm run lint`, `npm run test:unit` all green.
```

---

### Task 1: Expose the source executable on JobExecuted

**Files:**
- Modify: `apex-job/src/engine/domain/classes/JobExecuted.cls`

**Step 1: Add the public field**

In `JobExecuted.cls`, alongside the existing `jobDescription` and `jobRequests`
public fields (around line 11), add:

```apex
  public final JobExecutable executable { get; private set; }
```

**Step 2: Populate the field in the constructor**

In the constructor (line 14), assign from the parameter:

```apex
  public JobExecuted(final ApexJobFactory factory, final JobExecutable jobExecutable, final ApexJobResult jobExecutionResult) {
    this.factory = factory;
    this.executable = jobExecutable;                           // NEW
    this.jobDescription = jobExecutable.jobDescription;
    this.jobRequests = jobExecutable.jobRequests;
    this.jobExecutionResult = jobExecutionResult;
    this.stagingInfo = new JobRequestExecutionStagingInfo(jobExecutable, jobExecutionResult, this.jobDescription);
  }
```

**Step 3: Verify no existing test constructs `JobExecuted` by field without the new field**

```bash
grep -rn "new JobExecuted" apex-job/test/
```

Expected: every match uses the three-arg constructor that still works. If any
test uses a different constructor shape, update it in this task.

**Step 4: Run existing tests to confirm no regression**

```bash
npm run test:unit
```

Expected: all tests pass. The new field is additive.

**Step 5: Commit**

```bash
git add apex-job/src/engine/domain/classes/JobExecuted.cls
git commit -m "refactor(job-executed): expose source executable for finalizer use"
```

Body:

```
Finalizer gate in AsyncApexJobExecutor needs to identity-compare the last
recorded JobExecuted against the in-flight JobExecutable. Exposing the source
JobExecutable as a public read-only field enables that check without any
other architectural change.
```

### Task 2: Write RED tests for the new finalizer gate (TDD)

**Files:**
- Modify: `apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls`

The existing test file already has a reusable `KilledFinalizerContext implements FinalizerContext` inner class (around line 113) returning `ParentJobResult.UNHANDLED_EXCEPTION` — these tests reuse it instead of trying to mock the sealed `FinalizerContext` system type (Apex Mockery cannot mock it). `sut.lastExecutableJob` and `sut.jobExecutionResults` are already `@TestVisible private`, so direct field assignment from the test class is supported.

**Step 1: Add a helper that builds a plain `JobExecutable`**

Most of these tests need a `JobExecutable` instance but don't care about its internal details. Keep the setup local to the test file with one small helper:

```apex
  private static JobExecutable buildExecutable(final ApexJobTestMock mocks) {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withProcessorName('AsyncApexJobExecutorTest.NoOpProcessor').build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().build();
    jobRequest.JobDescription__r = jobDescription;
    return new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ jobRequest });
  }
```

Place this as a `private static` helper at the bottom of `AsyncApexJobExecutorTest` (alongside the existing `KilledFinalizerContext`). No changes to `ApexJobTestFixture` are required.

**Step 2: Add three tests covering the new branches**

Append to `AsyncApexJobExecutorTest`:

```apex
  @IsTest
  static void givenLastChunkAlreadyRecorded_whenFinalizerFires_thenNoDoubleRecord() {
    // Arrange — simulate the success-then-kill race: the chunk is already in the results list.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable inFlight = buildExecutable(mocks);
    sut.lastExecutableJob = inFlight;
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, inFlight, new ApexJobResult(ApexJobStatus.SUCCESS)));

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert — list must still contain exactly one result, not two.
    Assert.areEqual(1, sut.jobExecutionResults.size(), 'Finalizer must not append a KILLED duplicate when the chunk is already recorded');
    Assert.areEqual(ApexJobStatus.SUCCESS, sut.jobExecutionResults[0].jobExecutionResult.status, 'Existing SUCCESS record must be preserved unchanged');
  }

  @IsTest
  static void givenInFlightChunkNotRecorded_whenFinalizerFires_thenKilledAppended() {
    // Arrange — simulate a kill during executeChunk: pointer set, list still empty of this chunk.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    sut.lastExecutableJob = buildExecutable(mocks);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert — exactly one KILLED record synthesized.
    Assert.areEqual(1, sut.jobExecutionResults.size(), 'Finalizer must append exactly one KILLED record when the in-flight chunk is not already recorded');
    Assert.areEqual(ApexJobStatus.KILLED, sut.jobExecutionResults[0].jobExecutionResult.status, 'The synthesized record status must be KILLED');
  }

  @IsTest
  static void givenPreviousChunkRecordedButCurrentInFlight_whenFinalizerFires_thenKilledAppendedForCurrent() {
    // Arrange — executor finished chunk N, started chunk N+1, then was killed mid-executeChunk.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable previousChunk = buildExecutable(mocks);
    final JobExecutable currentChunk = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, previousChunk, new ApexJobResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = currentChunk;

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert — two results: previous SUCCESS plus current KILLED.
    Assert.areEqual(2, sut.jobExecutionResults.size(), 'Finalizer must append KILLED for the new in-flight chunk while preserving the previously recorded SUCCESS');
    Assert.areEqual(ApexJobStatus.KILLED, sut.jobExecutionResults[1].jobExecutionResult.status, 'The new tail record must be KILLED');
  }
```

No changes to `ApexJobTestFixture` are required for these tests.

**Step 3: Run tests to confirm RED**

```bash
npm run test:unit
```

Expected: the first test **fails** — today's gate appends KILLED whenever `lastExecutableJob != null`, regardless of whether the chunk is already in `jobExecutionResults`. The other two tests should pass today by coincidence; they are included to lock in the desired behaviour post-fix.

### Task 3: Implement the list-as-source-of-truth predicate (GREEN)

**Files:**
- Modify: `apex-job/src/engine/application/AsyncApexJobExecutor.cls`

**Step 1: Delete the post-success pointer clear**

In `execute(QueueableContext)`, remove line 49:

```apex
      this.lastExecutableJob = null;
```

The surrounding lines retain their order:

```apex
      final JobExecuted executionResult = this.lastExecutableJob.executeChunk();
      this.jobExecutionResults.add(executionResult);
      this.logger.debug('Job executed: ' + executionResult);
```

**Step 2: Replace the body of `wasLastChunkKilled`**

Before (post-rename state from pair #4):

```apex
  private Boolean wasLastChunkKilled(final FinalizerContext finalizerContext) {
    return finalizerContext?.getResult() == ParentJobResult.UNHANDLED_EXCEPTION && this.lastExecutableJob != null;
  }
```

After:

```apex
  private Boolean wasLastChunkKilled(final FinalizerContext finalizerContext) {
    if (finalizerContext?.getResult() != ParentJobResult.UNHANDLED_EXCEPTION) {
      return false;
    }
    if (this.lastExecutableJob == null) {
      return false;
    }
    if (this.jobExecutionResults.isEmpty()) {
      return true;
    }
    final JobExecuted lastRecorded = this.jobExecutionResults[this.jobExecutionResults.size() - 1];
    return lastRecorded.executable != this.lastExecutableJob;
  }
```

Early-return style matches the existing codebase convention (see
`AdaptiveConsumptionLearner.adjustSafetyModel`).

**Step 3: Run tests to confirm GREEN**

```bash
npm run test:unit
```

Expected: all three new tests **pass**, and the full suite still passes. If any
existing test relied on `lastExecutableJob` being null after a successful
chunk, it fails here — update the test to reflect the new invariant (the
pointer intentionally lingers) and document the change in the commit body.

### Task 4: Gate + commit

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

**Step 2: Commit**

```bash
git add apex-job/src/engine/application/AsyncApexJobExecutor.cls apex-job/src/engine/domain/classes/JobExecuted.cls apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls
git commit -m "fix(async-executor): prevent finalizer double-recording of chunks"
```

Body:

```
The executor's finalizer used a separate pointer (`lastExecutableJob`) to
decide whether to synthesize a KILLED result. A CPU-tick or heap
LimitException between `jobExecutionResults.add(...)` and the subsequent
`this.lastExecutableJob = null` could leave both states true at once, causing
the finalizer to append a duplicate KILLED entry for a chunk that was already
recorded as SUCCESS. Downstream, `adjustFromSuccess` followed by
`adjustFromKill` corrupted the consumption-learning model on that
JobDescription__c.

Make the list the source of truth: stop clearing the pointer on success; let
the finalizer compare the last recorded JobExecuted against the in-flight
JobExecutable by reference. The check is idempotent — the list either
contains the element or it doesn't — so the race cannot produce a duplicate.

Exposes JobExecuted.executable as a public read-only field to support the
identity check without loosening any other encapsulation.
```

---

## Verification (done when)

- All three new unit tests pass.
- The existing `AsyncApexJobExecutorTest` suite passes.
- `grep -n "this.lastExecutableJob = null" apex-job/src/engine/application/AsyncApexJobExecutor.cls` returns zero matches.
- `grep -n "public final JobExecutable executable" apex-job/src/engine/domain/classes/JobExecuted.cls` returns exactly one match.
- `git log --oneline main..HEAD` shows at most two commits (Task 1 and Task 4 collapse-option: squash into one if reviewers prefer).
- CI passes.
