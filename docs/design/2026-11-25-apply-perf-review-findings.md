# Design — apply-perf-review-findings

> Brief: apply the 2026-11-25 scratch-org performance review in one run. Items 8, 1, 2, 4, 5, 6 and 7 get code; item 3 gets documentation only. Item 9, splitting the selector, multiple chunks per description, and tracking the executor by job Id are out.
> Status: draft → self-reviewed ×3

## Context

What exists today and constrains this change:

- **Hexagonal engine** under `apex-job/src/engine/{application,domain,service,adapter}`. DI goes through `ApexJobFactory` / `ApexJobFactoryImpl`, whose instances are static lazy singletons. Each domain or adapter class has a public no-arg constructor and a `@TestVisible` private constructor that takes the factory.
- **Per-transaction state** has exactly one home, `ApexJobTransactionContext` (`apex-job/src/engine/service/ApexJobTransactionContext.cls`). It is a static singleton with a `@TestVisible reset()`. Today it holds only `hasExecutedJobs`, which `JobExecutable.cls:37` writes and `JobSelectorImpl.cls:165` reads.
- **Insert trigger**: `apex-job/src/engine/domain/triggers/JobRequestAfterInsert.trigger` has one event, `after insert`. When the running user lacks `Bypass_JobRequest_Trigger` it calls `new ApexJobFactoryImpl().getSpawner().enqueue(0)`. No `before` trigger exists on `JobRequest__c`.
- **Scheduling date**: `JobRequest__c.NextExecutionDateTime__c` is a plain DateTime with no default and no index. `JobExecuted.cls` writes `null` on terminal states (`:52`, `:75`, `:87`) and a date on retry or recurrence (`:79`, `:83`). `IsCandidate__c` accepts `ISNULL(NextExecutionDateTime__c)` as due, and `DESIGN.md:138` documents the same rule.
- **Packaging**: `sfdx-project.json` declares only `packageDirectories` (`apex-job/src`, `apex-job/test`), with no `package`, `versionName` or `packageAliases`. The only shipping path in the repo is `sf project deploy start -d apex-job` (`package.json` wireit `build`). The brief's open question "does CustomIndex ship" therefore reduces to "does a source deploy accept it". The review's tested deploy already answers yes. Unlocked or managed packaging is not used here and is not designed for.
- **Tests**: Apex Mockery (`Mock.forType`, `spyOn`, `Expect.that`) centralised in `apex-job/test/unit/classes/ApexJobTestMock.cls`; builders in `ApexJobTestFixture.cls`. `AsyncProcessorTest.cls:3-28` already builds a user carrying `Bypass_JobRequest_Trigger` through a runtime `PermissionSet` and `SetupEntityAccess`. That is the pattern to reuse for the bypass creation path. `JobMonitorController` has no test class. The repo has no LWC test setup: no `@salesforce/sfdx-lwc-jest` and no `jest.config.js`.
- **Prior designs** in `docs/design/2026-04-19-*.md` set the house style: a prose rationale, code sketches, a touchpoint table, and edge cases. `docs/design/2026-04-19-ewma-consumption-learning.md` introduced the variation counter that item 6 refines.
- **Doctrine / rulings**: the repo has no `DOCTRINE.md` and no rulings file. The binding constraints are the brief's PERIMETER and the "Ruled" lines.

## Requirements

1. A fresh org accepts `sf project deploy start -d apex-job/src` (item 8).
2. A request saved through `ApexJobManager.request()...save()` without `scheduleAt` gets executed and recorded. If recording fails, the finalizer does not re-enqueue at delay 0 (item 1).
3. Every runnable request (`READY`, `FAILURE`, `KILLED`) carries a non-null `NextExecutionDateTime__c` on all three creation paths: builder, plain DML, and DML under `Bypass_JobRequest_Trigger`. Terminal rows keep `null` (items 1 and 2).
4. The selector stays ONE query. Its WHERE clause gains `AND NextExecutionDateTime__c <= :now`, a `CustomIndex` on `NextExecutionDateTime__c` ships, and `IsCandidate__c = TRUE` remains as the residual check. The selector never uses `OR ... = NULL` (item 2).
5. The insert trigger attempts the wake-up at most once per transaction and never in Batch or `@future` context. No enqueue happens once `Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs()`. The four measured rows are reproduced by tests (item 4).
6. `JobIds__c` keeps only the last N ids (item 5).
7. A variation counts toward a model reset only when its deviation also exceeds a per-dimension noise floor. ONE named predicate, unit-tested on its own, serves both the base branch and the per-item branch (item 6).
8. `getStatusByProcessor` consumes one query row per group. The engine panel makes one Apex call every 5 s. Every LWC timer is cleared on disconnect (item 7).
9. `DESIGN.md` documents the one-chunk-per-description-per-transaction rule, its cost and why it stays (item 3). It also follows every behaviour change above.

## Design

Part order follows the brief: 8, then the date decision shared by items 1 and 2, then 1, 2, 4, 5, 6, 7 and 3.

### Item 8 — app deploys on a fresh org

**Context**
- `apex-job/src/monitor/applications/Async_Job_Monitor.app-meta.xml:16`: `<tabs>Job_Monitor_Console</tabs>` (the tab is missing).
- `:18`: `<utilityBar>Async_Job_Monitor_UtilityBar</utilityBar>` (the FlexiPage is missing).
- `apex-job/src/monitor/flexipages/Job_Monitor_Console.flexipage-meta.xml` exists with `<type>AppPage</type>`. A CustomTab can therefore target it.
- `apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml` has no `tabSettings` and no `applicationVisibilities`.

**Change** (ruled)
- Add `apex-job/src/monitor/tabs/Job_Monitor_Console.tab-meta.xml` with the brief's exact content: `flexiPage` `Job_Monitor_Console`, `label` `Job Monitor Console`, `motif` `Custom67: Gears`.
- Delete line 18 of the app.
- The permission-set grant is D1.
- `README.md:300` lists the monitor's deploy metadata and gains `tabs/Job_Monitor_Console.tab-meta.xml`.

**Proof**: the orchestrator deploys `apex-job/src` to a new scratch org. Item 8 has no Apex test surface because metadata validity is checked by the deploy itself.

### Shared decision (items 1 and 2) — where `NextExecutionDateTime__c` is stamped

The trap: `JobRequestAfterInsert.trigger:2` skips its whole body when the user has `Bypass_JobRequest_Trigger`, and an after-insert trigger cannot modify `Trigger.new` without a second DML. Stamping there would leave bulk-loaded rows `null`. With the new `<= :now` filter, those rows would never be selected again, so this location is excluded.

Options (D2):

| | Mechanism | Builder | Plain DML | DML + bypass | API / Data Loader | Manual re-queue (update) | Pinned? |
|---|---|---|---|---|---|---|---|
| **A** | `before insert` trigger that ignores the bypass permission and sets `NextExecutionDateTime__c = Datetime.now()` when null | yes | yes | yes | yes (triggers fire on every API insert) | only if `before update` is added (D3) | Yes, by our own code and the per-path tests below |
| **B** | Field `defaultValue` formula `NOW()` on `NextExecutionDateTime__c` | ? | ? | ? | ? | no (defaults apply on create only) | **No.** Whether a default fills a field that is unset or explicitly `null` on an Apex `insert` of a `new JobRequest__c(...)`, and on an API insert that sends the column blank, is not pinned. The brief forbids designing from memory, and no org may be touched in this phase. |
| **C** | Builder-only stamping (`JobRequestBuilder` constructor) | yes | **no** | **no** | **no** | no | Fails requirement 3 by construction. Listed for completeness. |

**Recommendation: A.** It is the only option whose behaviour is fully determined by code in this repo and covers every insert path. It also keeps working when the caller passes an explicit `null`. If the user prefers B, the same three per-path tests become the empirical pin, and B is accepted only if all three go green on a scratch org.

Shape of A:

```apex
// apex-job/src/engine/domain/triggers/JobRequestBeforeInsert.trigger  (new; name follows JobRequestAfterInsert)
trigger JobRequestBeforeInsert on JobRequest__c (before insert) {
  new JobRequestDueDate().stampMissing(Trigger.new, Datetime.now());
}
```

```apex
// apex-job/src/engine/domain/classes/JobRequestDueDate.cls  (new, domain, no DB access)
public without sharing class JobRequestDueDate {
  public void stampMissing(final List<JobRequest__c> jobRequests, final Datetime now) {
    for (JobRequest__c jobRequest : jobRequests) {
      if (jobRequest.NextExecutionDateTime__c == null) {
        jobRequest.NextExecutionDateTime__c = now;
      }
    }
  }
}
```

- The trigger does **not** call `FeatureManagement.checkPermission('Bypass_JobRequest_Trigger')`. The permission's meaning narrows to "skip the wake-up". The custom-permission description (`apex-job/src/admin/customPermissions/Bypass_JobRequest_Trigger.customPermission-meta.xml`), `DESIGN.md:609` and `DESIGN.md:701-703` change accordingly.
- `now` is a parameter so the unit test is deterministic. On insert, status is ignored: inserting a row that is already terminal is not an engine path, and a stamped date on such a row is inert because `IsCandidate__c` rejects the status.
- If D3 = A (stamp on update too), the event list becomes `(before insert, before update)` and the file is named `JobRequestBeforeSave.trigger`. A second method `stampMissingOnRunnable(List<JobRequest__c>, Datetime)` stamps only rows whose `Status__c` is in `{READY, FAILURE, KILLED}`. `JobExecuted` never writes a runnable status with a null date (its two runnable branches, `:79` and `:83`, write `nextTry`), so the finalizer's own updates never hit this branch. The branch serves manual re-queues only.
- Stamp time equals the insert transaction's clock, which is effectively `CreatedDate`. `WaitTime__c` keeps its current meaning ("waited since creation") for unscheduled requests.

Per-path tests (new `apex-job/test/integration/classes/JobRequestTriggerTest.cls`). Each one is red today:
- `givenBuilderWithoutScheduleAt_whenSave_thenNextExecutionDateTimeIsStamped`
- `givenPlainInsertWithoutDate_whenInsert_thenNextExecutionDateTimeIsStamped`
- `givenUserWithTriggerBypass_whenInsertWithoutDate_thenNextExecutionDateTimeIsStamped`. It uses `System.runAs` with the bypass user.
- `givenExplicitDate_whenInsert_thenDateIsKept`. This is a guard, and it is green today.
- Unit tests in `apex-job/test/unit/classes/JobRequestDueDateTest.cls` (new) check that a null date gets `now`, a set date is kept, and an empty list is a no-op.

DRY: the bypass-user setup in `AsyncProcessorTest.cls:3-28` moves into a shared test helper, `TestDataFactory.createUserWithTriggerBypass()` in `apex-job/test/unit/classes/TestDataFactory.cls`. Both test classes call it, so the code is not duplicated a second time.

### Item 1 — null-date requests are never recorded and the engine hot-loops

**Context**
- `apex-job/src/engine/domain/classes/JobExecuted.cls:59`: `final Datetime baseRef = job.NextExecutionDateTime__c ?? job.CreatedDate;`. `CreatedDate` is never selected (`JobSelectorImpl.cls:26-121`), so the fallback throws `SObjectException`.
- `apex-job/src/engine/application/AsyncApexJobExecutor.cls:53-81` is `execute(FinalizerContext)`. Its first `try` (`:54-67`) catches the exception and logs it. The second `try` (`:69-80`) then calls `getDelayInMinutes()` (`:97-102`), which returns `0` because `jobExecutionResults` is non-empty.
- `README.md:152-155` documents exactly this builder call without `scheduleAt`.

**(a) Null-date path.** The shared decision closes it at the source: a selected row always has a date, because the stamp guarantees one and the `<= :now` filter excludes `null`. The `?? job.CreatedDate` fallback becomes unreachable for every row `JobExecuted` sees. A synthesized `KILLED` result reuses rows that came from the selector, so it is covered too. D5 decides between three options: remove the fallback (recommended, since the codebase does not keep dead code), keep it and add `CreatedDate` to the SELECT, or fall back to `selectionTime`.

**(b) No zero-delay re-enqueue after a failed recording.** If recording threw, nothing was persisted: the exception fires in `stageExecution` before any DML, and DML itself is `allOrNone:false` and does not throw. In that case the finalizer must not treat the results as progress.

```apex
} catch (Exception e) {
  this.logger.debug('AsyncJob: Error while recording job execution');
  this.logger.error(e.getMessage());
  this.logger.error(e.getStackTraceString());
  this.discardUnrecordedResults();   // nothing was persisted: re-enqueue as idle, not as "work done"
}
...
private void discardUnrecordedResults() {
  this.jobExecutionResults.clear();
}
```

`getDelayInMinutes()` keeps its current body, and an empty list yields `configService.getEnqueueDelayInMinutes()`. This avoids a boolean parameter and a new state flag. The list is read nowhere after the first `try`, because `wasLastChunkKilled` runs before it. D6 covers which delay to use. The recommendation is the existing idle delay: 1 min in business hours, clamped to [0, 10] by `ApexJobConfigServiceImpl.cls:21-31`.

**Tests**
- Red, end-to-end: in `apex-job/test/integration/classes/AsyncProcessorTest.cls`, `givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded`. It creates a description for `AsyncProcessorTest.NormalPriorityProcessor`, then `ApexJobManager.request().forDescription(id).save()` with no `scheduleAt`, and runs `System.enqueueJob(new AsyncApexJobExecutor(factoryForTest))` inside `startTest`/`stopTest`. It asserts that the request was deleted (SUCCESS). Today the request stays `READY` with `AttemptNumber__c == null`. Like the neighbouring tests, it runs inside `System.runAs(getRunningUser())` (the bypass user). Otherwise the real after-insert wake-up would enqueue a second, unmocked executor. This also exercises the D2 = A guarantee that bypassed inserts still get a date.
- Red, unit: in `apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls`, `givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay`. `jobExecutionResults` is non-empty, `recordJobExecutionSpy` throws, and `getEnqueueDelayInMinutesSpy` returns `3`. Expect `enqueueSpy` to have been called with `3` and never with `0`. The existing `givenFinalizerContext_whenExecuteWithRemainingJobs_thenExecuteAndReenqueueWith0Delay` stays green, which proves the success path is unchanged.

### Item 2 — the selector does a full table scan

**Context**
- `apex-job/src/engine/adapter/JobSelectorImpl.cls:18-153` is `getEligibleJobs(List<Id>)`. Its WHERE clause is at `:123-144`, `IsCandidate__c = TRUE` at `:125`, and `LIMIT :ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE` at `:151`.
- `apex-job/src/monitor/classes/adapter/JobMonitorController.cls:11-44` is `getJobRequestPage`: `WHERE IsCandidate__c = TRUE ... ALL ROWS`, polled every 2 s.

**Change**
1. New `apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml`. The brief gives the exact content (`<allowNullValues>true</allowNullValues>`, no `<field>` element). D7 decides between `true` and `false`.
2. Selector: capture `final Datetime now = Datetime.now();` next to the other locals at `:21-24`, and add `AND NextExecutionDateTime__c <= :now` directly after `IsCandidate__c = TRUE`. Everything else is unchanged: it stays one query, keeps the formula as the residual check, and never uses `OR NULL`.
3. The date invariant comes from the shared decision above.
4. Installed orgs that already hold runnable rows with a null date are covered by D4. The recommendation is an operator script, `scripts/apex/backfill-next-execution.apex`, following the house pattern of `scripts/apex/restart-watcher.apex`, which lives outside every packageDirectory. Each run sets `NextExecutionDateTime__c = CreatedDate` on rows where `NextExecutionDateTime__c = null AND Status__c IN ('READY','FAILURE','KILLED')`, for up to 10,000 rows, and is re-run until it reports 0.
5. `IsCandidate__c` still has the `ISNULL(NextExecutionDateTime__c)` branch, and `DESIGN.md:138` documents it (D8). Recommendation: with D2 = A and D3 = A, a runnable null-dated row cannot exist, so the branch is dead. Remove it from the formula and from `DESIGN.md:138`. The monitor's "Is Candidate?" column and the selector then agree. Caveat: with `formulaTreatBlanksAs` `BlankAsZero`, the result of `NOW() >= <null datetime>` is not pinned. Since D3 = A guarantees no runnable null rows, the formula never meets that case on a runnable row. If D3 = B, keep the branch and document instead that the selector excludes null-dated rows.
6. Monitor `getJobRequestPage` (D9). Recommendation: add the same `AND NextExecutionDateTime__c <= :now` and drop `ALL ROWS` together with the `IsDeleted ASC` sort key. The engine deletes only `SUCCESS` rows (`JobRepositoryImpl.cls:92-94`), and `IsCandidate__c` rejects those. `ALL ROWS` can therefore surface only rows a user deleted while they were runnable. The engine never runs those rows because the selector has no `ALL ROWS`, so showing them as candidates is wrong.

**Tests**
- Unit: `JobSelectorImplTest.cls` keeps its existing coverage (`givenFutureJobs_whenGetJobs_thenExcludesFutureJobs`, etc.). The explicit filter cannot be observed behaviourally, because the residual formula already excludes the same rows. Its proof is the query plan, not a unit test.
- The per-path stamping tests above prove requirement 3.
- Done-when (orchestrator): REST `query?explain=` on the selector's SOQL shows `leadingOperationType: Index` on `NextExecutionDateTime__c` when few rows are due. Wait about a minute after deploy before measuring. Timings go next to the brief's baselines (410-480 ms TableScan, compared with the target band of 73-82 ms Index).

### Item 4 — the insert trigger spends the caller's governor limits

**Context**
- `JobRequestAfterInsert.trigger:3` calls `getSpawner().enqueue(0)` on every 200-row trigger invocation.
- `apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls:21-36` is `enqueue(Integer)`. `:38-42` is `cannotEnqueue()`: `System.isQueueable() || !isSystemEnabled() || isRunning(null)`. `isRunning` is the SOQL at `JobExecutorServiceImpl.cls:7-11`.
- `apex-job/src/engine/adapter/JobExecutorSpawner.cls` is the interface: `Id enqueue(Integer)` and `Id enqueue()`.

**Change**

```apex
// ApexJobTransactionContext (existing home of per-transaction state)
public Boolean hasAttemptedWakeUp { get; private set; }   // false in the private constructor
public void markWakeUpAttempted() { this.hasAttemptedWakeUp = true; }
```

```apex
// JobExecutorSpawner: new command
void wakeUp();

// JobExecutorQueueableSpawner
private static final Integer WAKE_UP_DELAY_IN_MINUTES = 0;

public void wakeUp() {
  final ApexJobTransactionContext transactionContext = ApexJobTransactionContext.getInstance();
  if (transactionContext.hasAttemptedWakeUp || System.isBatch() || System.isFuture()) {
    return;
  }
  transactionContext.markWakeUpAttempted();
  this.enqueue(WAKE_UP_DELAY_IN_MINUTES);
}

private Boolean cannotEnqueue() {
  return System.isQueueable() || this.hasNoQueueableSlotLeft() || this.factory.getConfigService().isSystemEnabled() == false || this.factory.getExecutorService().isRunning(null) == true;
}

private Boolean hasNoQueueableSlotLeft() {
  return Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs();
}
```

```apex
// JobRequestAfterInsert.trigger:3
new ApexJobFactoryImpl().getSpawner().wakeUp();
```

- The flag is checked before `markWakeUpAttempted()`, so a skipped Batch or `@future` call does not mark it. That makes no difference, because these contexts never wake up anyway.
- The slot check sits in `cannotEnqueue`, ahead of the SOQL. It therefore protects every enqueue: trigger, finalizer, watcher and `restartEngine`. At the limit, `System.enqueueJob` would otherwise throw an uncatchable `LimitException`, so returning `null` is strictly better.
- D10 decides where the flag lives and why the guard goes in a new `wakeUp()` rather than inside `enqueue(Integer)`. Putting it inside `enqueue` would also gate the finalizer, the watcher and `restartEngine` whenever they share a transaction with an insert. In tests that share a transaction routinely, so an explicit enqueue would silently return `null`.

**Public-surface impact (checked)**

| Surface | File | Impact |
|---|---|---|
| `JobExecutorSpawner` | `apex-job/src/engine/adapter/JobExecutorSpawner.cls` | **+ `void wakeUp()`**. The only production implementer is `JobExecutorQueueableSpawner`. Test doubles are `Mock.forType(JobExecutorSpawner.class)` (`ApexJobTestMock.cls`, `AsyncProcessorTest.cls:751-761`), which absorb the new method without edits. Any subscriber-org class implementing this `public` interface would stop compiling. None exists in the repo. |
| `ApexJobFactory` / `ApexJobFactoryImpl` | `apex-job/src/engine/service/ApexJobFactory*.cls` | None. `getSpawner()` is unchanged. |
| `ApexJobTransactionContext` | `apex-job/src/engine/service/ApexJobTransactionContext.cls` | + `hasAttemptedWakeUp` (read-only property) and + `markWakeUpAttempted()`. `reset()` covers the new field for free because it builds a new instance. |
| `JobMonitorController.restartEngine` | `JobMonitorController.cls:123-128` | Code unchanged (`new JobExecutorQueueableSpawner().enqueue(0)`). Behaviour: gains the slot guard. Not subject to the once-per-transaction flag. |
| `ApexJobWatcher` | `apex-job/src/engine/adapter/ApexJobWatcher.cls:18-21` | Code unchanged (`enqueue()`). Gains the slot guard. |
| `AsyncApexJobExecutor` finalizer | `AsyncApexJobExecutor.cls:74` | Code unchanged. Gains the slot guard. |
| `JobRequestAfterInsert.trigger` | | `enqueue(0)` becomes `wakeUp()`. |

**Tests** reproduce the four measured rows in `JobRequestTriggerTest.cls` (integration). Each test enables the engine (`insert new ApexJobConfig__c(Enabled__c = true)`) and uses a **disabled** description, so the executor that runs at `stopTest` finds no work.

| Test | Today (red) | After |
|---|---|---|
| `givenEngineIdle_when40SingleRowInserts_thenOneQueryAndOneQueueable`: 40 inserts inside `startTest`, Δ`Limits.getQueries()` and `Limits.getQueueableJobs()` captured before `stopTest` | 40 / 40 | 1 / 1 |
| `givenEngineIdle_when120SingleRowInserts_thenNoQueueableLimitException` | `LimitException ... queue: 51` | passes, 1 queueable |
| `givenEngineIdle_whenOneInsertOf10000Rows_thenOneQueryAndOneQueueable`: the description is inserted **before** `startTest` so the 10,000-row DML fits the row budget | 50 / 50 | 1 / 1 |
| `givenBatchExecute_whenInsertTwoRequests_thenScopeCompletes`: an inner `Database.Batchable<Integer>` inserts 2 rows, then assert 2 rows persisted and `AsyncApexJob.NumberOfErrors == 0` | scope fails `... queue: 2` | completes, no executor enqueued |
| `givenFutureMethod_whenInsertTwoRequests_thenNoWakeUp`: the brief's `@future` ruling | fails on the 2nd enqueue | no `AsyncApexJobExecutor` `AsyncApexJob` row |

CPU time is not asserted because it is not deterministic in tests. The orchestrator reports the before/after CPU figures. Unit tests in `JobExecutorQueueableSpawnerTest.cls`:
- `givenWakeUpAlreadyAttempted_whenWakeUp_thenIsRunningNotQueried`: two `wakeUp()` calls, then `Expect.that(mocks.isRunningSpy).hasBeenCalledTimes(1)`.
- `givenNoQueueableSlotLeft_whenEnqueue_thenReturnsNullWithoutQuery`: fill 50 slots with a trivial test queueable, then `enqueue(0)` returns `null` and `isRunningSpy` is not called.

`ApexJobTransactionContextTest.cls` gains the flag's default (false), the mark, and reset.

### Item 5 — `JobIds__c` keeps the last N ids

**Context**
- `apex-job/src/engine/adapter/JobRepositoryImpl.cls:79` calls `buildJobIds` for each row in the finalizer.
- `:96-112` holds `buildJobIds` with `JOBIDS_SEP`, `MAX_LONG_TEXT_LENGTH`, `ID_15_LENGTH` and the trim `while` loop.
- The selector reads the field (`JobSelectorImpl.cls:41`) because appending needs the previous value. No other code reads it.

**Change** (N = 20 pending D11; no decision ids go in source)

```apex
private static final Integer MAX_TRACKED_JOB_IDS = 20;

private static String buildJobIds(final String jobIdValues, final String asyncJobId) {
  final List<String> jobIds = String.isNotBlank(jobIdValues) ? jobIdValues.split(JOBIDS_SEP) : new List<String>();
  jobIds.add(asyncJobId.left(ID_15_LENGTH));
  final Integer firstKept = Math.max(0, jobIds.size() - MAX_TRACKED_JOB_IDS);
  final List<String> kept = new List<String>();
  for (Integer i = firstKept; i < jobIds.size(); ++i) {
    kept.add(jobIds[i]);
  }
  return String.join(kept, JOBIDS_SEP);
}
```

- `MAX_LONG_TEXT_LENGTH` and the `while` loop become dead code and are removed: 20 × 16 characters is far below 131,072.
- Rows that already hold 8,192 ids self-heal on their next recording.
- The field length is not reduced, because a metadata change with existing data is out of scope.
- `JobIds__c.field-meta.xml`'s `<description>` and `DESIGN.md:335` say "last 20 ids".

**Tests** in `JobRepositoryImplTest.cls`:
- `givenJobIdsAtCapacity_whenRecordJobExecution_thenOldestDroppedAndNewestAppended`: the row starts with 20 ids, and after recording it holds the same count, the first id is gone, and the new id is last. Red today because the row ends with 21.
- The existing `givenRecordJobExecution_whenCalledWithAsyncJobId_thenPopulateJobIds` stays green.

### Item 6 — noise floor in the learner

**Context**
- In `apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls`, the base branch (`:62-65`) and the per-item branch (`:80-83`) each compute `Math.abs((x - current) / current)` and compare it with `VariationResetThreshold__c`.
- `recordVariationHit` (`:104-108`) counts hits, and `resetConsumptionModel` (`:156-167`) resets the model.
- `ConsumptionModel` (`apex-job/src/engine/domain/classes/ConsumptionModel.cls`) is the per-dimension descriptor the learner iterates.
- The dimension names are `private static final` in `LimitsUsage.cls:3-20`.

**The single predicate**

```apex
@TestVisible
private Boolean isSignificantVariation(final Decimal observed, final Decimal expected, final Decimal noiseFloor) {
  final Decimal deviation = Math.abs(observed - expected);
  return deviation > noiseFloor && deviation / expected > this.job.VariationResetThreshold__c;
}
```

`expected > 0` always holds here: both callers return early when the learned value is `<= UNKNOWN_*` (0).

**Callers.** Both deviations are in chunk-total units, which is where measurement resolution lives (1 ms CPU over the whole chunk). See D13.
- Base: `isSignificantVariation(usage, currentBase, model.noiseFloor)`.
- Per-item: `final Integer itemsBeyondFirst = chunkSize - 1;` then `isSignificantVariation(newPerItem * itemsBeyondFirst, currentPerItem * itemsBeyondFirst, model.noiseFloor)`. The relative part is unchanged from today because `itemsBeyondFirst` cancels. The absolute part becomes the deviation of the chunk total. Example: a reading of 0.0204 ms/item against a learned 0.0408 ms/item over 49 items gives `|1 - 2| = 1 ms`, below the 5 ms floor, so it is not counted. A real per-item doubling of a 1 ms/item job gives 48 ms, which is counted.

**Floors** (D12). The values are placeholders, held as named constants on `ConsumptionModel`. Each model resolves its floor once in the constructor, so the signature does not change:

```apex
private static final Decimal COUNTER_NOISE_FLOOR = 1;
private static final Decimal CPU_TIME_NOISE_FLOOR_MS = 5;
private static final Decimal HEAP_SIZE_NOISE_FLOOR_BYTES = 4096;
private static final Decimal CALLOUT_TIME_NOISE_FLOOR_MS = 5;
private static final Map<String, Decimal> NOISE_FLOOR_BY_DIMENSION = new Map<String, Decimal>{
  LimitsUsage.CPU_TIME_DIMENSION => CPU_TIME_NOISE_FLOOR_MS,
  LimitsUsage.HEAP_SIZE_DIMENSION => HEAP_SIZE_NOISE_FLOOR_BYTES,
  LimitsUsage.CALLOUT_TIME_DIMENSION => CALLOUT_TIME_NOISE_FLOOR_MS
};
public Decimal noiseFloor { get; private set; }   // = NOISE_FLOOR_BY_DIMENSION.get(dimension) ?? COUNTER_NOISE_FLOOR
```

- `LimitsUsage.CPU_TIME_DIMENSION`, `HEAP_SIZE_DIMENSION` and `CALLOUT_TIME_DIMENSION` go from `private` to `public` so the floor map does not repeat string literals.
- `calloutTime` is a millisecond dimension, not a counter. The brief does not name it, so its 5 ms placeholder is part of D12.

**Tests** in `AdaptiveConsumptionLearnerTest.cls`:
- Predicate on its own:
  - `givenDeviationBelowFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenFalse`
  - `givenDeviationAboveFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenTrue`
  - `givenDeviationAboveFloorAndRatioBelowThreshold_whenIsSignificantVariation_thenFalse`
  - `givenDeviationEqualToFloor_whenIsSignificantVariation_thenFalse`, which pins the strict `>`.
- Red behaviour: `givenPerItemAtResolutionFloor_whenAdjustFromSuccess_thenCounterUnchangedAndBlended`. The job has `CpuTimePerItemConsumption__c = 0.0204`, base 10, chunk 50, and a usage that yields a 100 % per-item variation but a 1 ms chunk deviation. Today `ConsecutiveVariationCount__c` becomes 1; after the change it stays 0 and the value is blended.
- Red behaviour, base branch: `givenBaseAtResolutionFloor_whenAdjustFromSuccess_thenCounterUnchanged`, with base 1 ms, an observation of 2 ms, and chunk 1.
- `ConsumptionModelTest`: no test class exists today. A minimal `apex-job/test/unit/classes/ConsumptionModelTest.cls` asserts that cpuTime, heapSize and calloutTime get their constants and that each counter gets `1`. It iterates `ConsumptionModel.asList()` rather than an exact set, per the house rule on evolving shapes.
- The existing variation tests (`:43`, `:198`, `:219`) use deviations of 100 ms and more, far above the floors. They stay green unchanged.

**Docs**: `DESIGN.md:455-456` and `DESIGN.md:677-679` ("Variation Reset Threshold with N-of-N Counter") gain the conjunction: the relative deviation must exceed the threshold **and** the absolute chunk deviation must exceed the dimension's noise floor. They also explain why: resolution-floor readings of cheap jobs.

### Item 7 — monitor

**Context**
- `JobMonitorController.cls:46-71` is `getStatusByProcessor`, with the MAX, SUM and FORMAT aggregates at `:54-60`.
- `:73-77` is `getJobDescriptionInfos(List<Id>)`.
- `:79-103` holds `isEnabled`, `getExecutorCount` and `isRecoveryBatchAlive`, each with `@AuraEnabled`.
- `apex-job/src/monitor/lwc/engineControls/engineControls.js:30-36` runs `setInterval` every 500 ms with 3 calls.
- `requestTable/requestTable.js:36-53` chains `setTimeout` every 2 s.
- `statusByProcessorTable/statusByProcessorTable.js:29-63` chains `setTimeout` every 5 s.
- None of the three components has a `disconnectedCallback`.

**Apex**

```apex
@AuraEnabled
public static List<Map<String, Object>> getStatusByProcessor() {
  final List<AggregateResult> rows = [
    SELECT COUNT(Id) nbRows, Status__c status, JobDescription__c processorId
    FROM JobRequest__c
    GROUP BY Status__c, JobDescription__c
    ORDER BY Status__c, JobDescription__c
  ];
  ... // unchanged mapping
}

@AuraEnabled
public static List<JobDescription__c> getJobDescriptionInfos(final List<Id> jobDescriptionIds) {
  return [
    SELECT Id, ProcessorName__c, MaxExecutionsPerMinute__c, ExecutionsInCurrentWindow__c, CurrentWindowStart__c,
           MaxChunkSize__c, SmallestFailingChunk__c, SuccessStreak__c, ConsecutiveFailures__c, LastExecutionDateTime__c
    FROM JobDescription__c WHERE Id IN :jobDescriptionIds
  ];
}

@AuraEnabled
public static EngineStatus getEngineStatus() {
  return new EngineStatus(isEnabled(), getExecutorCount(), isRecoveryBatchAlive());
}

public class EngineStatus {
  @AuraEnabled public Boolean enabled { get; private set; }
  @AuraEnabled public Integer executorCount { get; private set; }
  @AuraEnabled public Boolean watcherScheduled { get; private set; }
  // constructor assigns the three values
}
```

- `isEnabled`, `getExecutorCount` and `isRecoveryBatchAlive` lose `@AuraEnabled` and become `private`. After the change no LWC imports them (`grep` shows `engineControls.js` is their only consumer), so keeping them public would leave dead surface.
- The `@SuppressWarnings('PMD.AvoidNonRestrictiveQueries ')` on `getStatusByProcessor` stays as-is. It is existing code, and the contract forbids only adding new suppressions.

**LWC**

The pattern shared by all three components: a `stopped` flag, a stored timer id, re-arming in `finally`, and clearing on disconnect.

```js
const POLL_INTERVAL_MS = 5000;   // engineControls; 2000 requestTable; 5000 statusByProcessorTable

connectedCallback() {
  this.stopped = false;
  this.poll();
}

disconnectedCallback() {
  this.stopped = true;
  clearTimeout(this.pollTimer);
}

async poll() {
  try {
    await this.refresh();               // one Apex round trip (two for statusByProcessorTable)
  } finally {
    if (!this.stopped) {
      this.pollTimer = setTimeout(() => this.poll(), POLL_INTERVAL_MS);
    }
  }
}
```

- `try/finally` with no `catch` lets a rejection surface as an unhandled rejection in the console, so it is not swallowed. Unlike today, polling also survives a transient Apex error: currently the `setTimeout` sits after the `await`, so one failure ends the chain.
- The `stopped` flag covers the case where `disconnectedCallback` runs during the `await`. `clearTimeout` alone would miss it, because the timer is armed after the call returns.
- **engineControls**: `refresh()` makes one `getEngineStatus()` call, then sets `enabled`, `executorCountValue` and `recoveryBatchStatusValue`. The interval goes from 500 ms to 5 s, so 6 calls/s become 0.2 calls/s per tab. The `setInterval` is removed.
- **requestTable**: keeps `refreshData` as `refresh()` and stores the timer.
- **statusByProcessorTable**: `refresh()` calls `getStatusByProcessor()`, then `getJobDescriptionInfos(ids)`, and merges per `processorId`:
  - `maxBulk ← MaxChunkSize__c`
  - `smallestFailingChunk ← SmallestFailingChunk__c`
  - `successStreak ← SuccessStreak__c`
  - `consecutiveFailure ← ConsecutiveFailures__c`
  - `lastExecutionDateTime ← LastExecutionDateTime__c`, as a `type: 'date'` column with date and time `typeAttributes`, because the value is now an ISO datetime rather than a `FORMAT()`ed string.
  - The rate-limit fields as today.
- The `Nb Try` and `Next Exec` columns are removed.
- `arePagesDifferent` is removed from this component. It never short-circuits today: `rowValues` entries carry `processorUrl`, `processorName` and the other added keys, which the fresh `rows` lack, so `JSON.stringify` always differs. Description stats also change without the counts changing, so both calls run every poll by design.
- `DESIGN.md` "Monitoring UI" (`:553-590`) updates the polling intervals, the single engine-status call, and the source of the per-processor statistics.

**Tests** (new `apex-job/test/unit/classes/JobMonitorControllerTest.cls`):
- `givenRequestsAcrossTwoDescriptionsAndTwoStatuses_whenGetStatusByProcessor_thenQueryRowsEqualGroupCount`. It inserts 2 descriptions × 2 statuses × 5 rows (20 rows, 4 groups) before `startTest`, then asserts `Limits.getQueryRows() == 4` after the call and that the `nbRows` per group is 5. Red today: the MAX/SUM aggregates count every source row, which is how 50,200 rows threw. This row accounting is the proof the brief asks for, because a test with more than 50,000 rows is impractical.
- `givenDescriptions_whenGetJobDescriptionInfos_thenReturnsStatisticsFields`.
- `givenEngineState_whenGetEngineStatus_thenReturnsThreeValues`.

LWC verification is D14.

### Item 3 — documentation only

New `DESIGN.md` subsection under "Key Design Decisions", titled "One Chunk per Description per Transaction". It states:

- **Rule**: a description gets at most ONE chunk of at most 50 requests per transaction. The selector excludes descriptions already executed (`JobSelectorImpl.cls:124`, fed by `JobRepositoryImpl.extractDescriptionIds`) and caps rows at `ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE` (`:151`).
- **Cost** (Developer Edition scratch org, 2026-11-25): 1,000 no-op jobs take 25 transactions and 24-47 s, using about 21 ms of the 60,000 ms CPU budget per transaction. A one-transaction prototype did the same work in about 3.2 s.
- **Why it stays**:
  - The rate counter is written only in the finalizer (`JobExecuted.cls:116-129`) and read by `AdaptiveChunkCalculator.cls:77-88`, so several chunks in one transaction would read a stale counter.
  - The learner runs in the finalizer (`JobExecuted.cls:100-114`), so later chunks would size against an un-updated model.
  - Every eligible description gets a turn today.
  - A failing finalizer would lose up to about 5,000 recordings instead of 50.
  - Executed requests stay on the heap until the finalizer.

No code change.

### Touchpoint summary

| Item | Files |
|---|---|
| 8 | `apex-job/src/monitor/tabs/Job_Monitor_Console.tab-meta.xml` (new), `apex-job/src/monitor/applications/Async_Job_Monitor.app-meta.xml`, `apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml` (D1), `README.md` |
| 1+2 date | `apex-job/src/engine/domain/triggers/JobRequestBeforeInsert.trigger` (new; `JobRequestBeforeSave` if D3 = A), `apex-job/src/engine/domain/classes/JobRequestDueDate.cls` (new), `Bypass_JobRequest_Trigger.customPermission-meta.xml` description, `scripts/apex/backfill-next-execution.apex` (D4) |
| 1 | `AsyncApexJobExecutor.cls`, `JobExecuted.cls:59` (D5) |
| 2 | `apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml` (new), `JobSelectorImpl.cls`, `IsCandidate__c.field-meta.xml` (D8), `JobMonitorController.getJobRequestPage` (D9) |
| 4 | `ApexJobTransactionContext.cls`, `JobExecutorSpawner.cls`, `JobExecutorQueueableSpawner.cls`, `JobRequestAfterInsert.trigger` |
| 5 | `JobRepositoryImpl.cls`, `JobIds__c.field-meta.xml` |
| 6 | `AdaptiveConsumptionLearner.cls`, `ConsumptionModel.cls`, `LimitsUsage.cls` (3 constants made public) |
| 7 | `JobMonitorController.cls`, `engineControls.js`, `requestTable.js`, `statusByProcessorTable.js` |
| docs | `DESIGN.md` (`:138`, `:154`, `:296`, `:335`, `:337-339`, `:455-456`, `:553-590`, `:609`, `:677-679`, `:701-703`, new item-3 section), `README.md`, `CONTRIBUTING.md` (D16) |

## Decision candidates

| # | Choice | Alternatives (≤3) | Recommendation | Why |
|---|---|---|---|---|
| D1 | Item 8: does `AdminAsyncJob` grant the new tab? | A. Add `<tabSettings><tab>Job_Monitor_Console</tab><visibility>Visible</visibility></tabSettings>` · B. Leave it out (admins enable the tab by hand) · C. A plus `<applicationVisibilities>` for `Async_Job_Monitor` | A | The permission set's stated purpose is full engine administration. Granting the tab makes the console reachable from it. Whether the app also needs `applicationVisibilities` to appear in the launcher is not pinned. Choose C only if the fresh-org check shows the app hidden. |
| D2 | Items 1+2: where the date is stamped | A. `before insert` trigger that ignores the bypass permission · B. Field default `NOW()` (not pinned) · C. Builder only | A | A covers builder, plain DML, DML under bypass and API loads by code. B's behaviour on explicit `null` and API blanks is unpinned. C leaves DML rows null, so they are never selected. |
| D3 | Also stamp on update (manual re-queue of a null-dated row to a runnable status) | A. `before update` stamps runnable rows with a null date · B. Insert only, and document that re-queues must set a date | A | Without A, an admin who flips a row back to `READY` produces a row the selector never sees. Today the `ISNULL` branch would pick it up, so B is a silent regression. The engine's own writes never hit the branch. |
| D4 | Existing runnable rows with a null date in installed orgs | A. Operator script `scripts/apex/backfill-next-execution.apex` (date = `CreatedDate`, 10k per run, re-run until 0) · B. Release note only | A | Without a backfill those rows are invisible to the new filter forever. The script follows the existing `scripts/apex/` pattern and is never deployed. |
| D5 | `JobExecuted.cls:59` `?? job.CreatedDate` fallback | A. Remove it (`baseRef = NextExecutionDateTime__c`) · B. Keep it and add `CreatedDate` to the selector SELECT · C. Fall back to `selectionTime` (wait 0) | A | After D2 and the `<= :now` filter, every row `JobExecuted` sees has a date, so the fallback is dead code. |
| D6 | Re-enqueue delay after a failed recording | A. The idle delay `getEnqueueDelayInMinutes()` (1 min in business hours, ≤ 10) · B. A new fixed constant · C. No re-enqueue; the watcher restarts within 5 min | A | It reuses an existing, operator-tunable semantic and adds no constant. C costs up to 5 min of latency on every transient failure. |
| D7 | `CustomIndex.allowNullValues` | A. `true` (tested) · B. `false` (untested) | A | Only `true` was measured. The filter never matches `null`, so B might shrink the index, but it has no measurement behind it. |
| D8 | `IsCandidate__c` `ISNULL` branch and `DESIGN.md:138` | A. Remove the branch and update the doc (requires D3 = A) · B. Keep the formula and update the doc to say the selector excludes null-dated rows | A | With D2 = A and D3 = A the branch is unreachable for runnable rows. Removing it makes the monitor's "Is Candidate?" agree with the selector. |
| D9 | `JobMonitorController.getJobRequestPage` | A. Add `<= :now`, drop `ALL ROWS` and the `IsDeleted` sort · B. Add `<= :now` and keep `ALL ROWS` · C. Leave as is | A | Polled every 2 s per tab, it runs the same scan as the selector. `ALL ROWS` can only surface user-deleted runnable rows, which the engine never runs. |
| D10 | Item 4: where the once-per-transaction flag lives and where the guard sits | A. Flag in `ApexJobTransactionContext`, guard in a new `JobExecutorSpawner.wakeUp()` called only by the trigger · B. Flag in `ApexJobTransactionContext`, guard inside `enqueue(Integer)` (no interface change) · C. A private static in `JobExecutorQueueableSpawner` | A | It keeps the single home for per-transaction state, which the brief names. B silently turns a second explicit `enqueue` in the same transaction (finalizer, watcher or restart after an insert) into `null`. C scatters mutable static state, which the brief refuses. |
| D11 | Item 5: N | A. 20 (tested) · B. 10 · C. 50 | A | Measured at 34 KB of heap and 79 ms of finalizer CPU per 50-row chunk. |
| D12 | Item 6: floor values | A. Placeholders: cpuTime 5 ms, heapSize 4,096 B, calloutTime 5 ms, counters 1 · B. Same, but calloutTime 1 (treated as a counter) · C. Defer the values to a measured run after the change | A | These are the prototype's values (1 of 25 single-item transactions). calloutTime is wall-clock ms like cpuTime, so a 1 ms floor would not absorb clock jitter. |
| D13 | Item 6: unit of the floor comparison | A. Chunk-total deviation (`perItemDelta × (chunkSize − 1)`) · B. Per-item deviation | A | Measurement resolution applies to the chunk total. With B, a 5 ms per-item floor would mute every real per-item drift of any job cheaper than 5 ms/item. |
| D14 | Item 7: how the LWC changes are verified | A. Add `@salesforce/sfdx-lwc-jest` with fake-timer tests (one call per interval; no call after `disconnectedCallback`; re-arm after a rejected call) · B. A manual scratch-org checklist (devtools Network: calls per tab per 5 s; navigate away → calls stop) · C. Both | C | A is the only repeatable proof, and the code-review rules ask for TDD and ≥ 80 % coverage. B is still needed once, because jest mocks the Apex wire and cannot prove the server-side call count. |
| D15 | Document the Apex Mockery install step (README and CONTRIBUTING have none) | A. A CONTRIBUTING step: deploy Apex Mockery from source at a pinned tag before `apex-job/test` (what the orchestrator does today) · B. A CONTRIBUTING step: install its published package by version id · C. Leave undocumented | A | It documents the path that is proven to work in this repo. B needs a version id that nobody has pinned yet. |

## Test strategy

- **Red first, per item**:
  - 1: `AsyncProcessorTest.givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded` and `AsyncApexJobExecutorTest.givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay`.
  - 1+2: the three per-path tests in `JobRequestTriggerTest`.
  - 4: the four measured rows plus `@future` in `JobRequestTriggerTest`.
  - 5: `JobRepositoryImplTest.givenJobIdsAtCapacity_...`.
  - 6: the two resolution-floor tests in `AdaptiveConsumptionLearnerTest`.
  - 7: `JobMonitorControllerTest.givenRequestsAcrossTwoDescriptionsAndTwoStatuses_..._thenQueryRowsEqualGroupCount`.
  - Every one of these fails on `main` for the reason the brief measured.
- **Unit vs integration**:
  - Domain logic (`JobRequestDueDate`, the learner predicate, `ConsumptionModel` floors, `buildJobIds`) gets unit tests with Apex Mockery where a factory is involved.
  - Trigger, Batch and `@future` behaviour and the governor-limit accounting run as real-DML tests in `apex-job/test/integration/classes/JobRequestTriggerTest.cls`, because `System.isBatch()`, `System.isFuture()` and `Limits.*` cannot be mocked.
- **Edge matrix**:

  | Edge | Covered by |
  |---|---|
  | Explicit date kept on insert | `givenExplicitDate_whenInsert_thenDateIsKept` |
  | Bypass user still gets a date | per-path bypass test |
  | Second wake-up in the same transaction | spawner unit test |
  | Slots exhausted | spawner unit test (50 trivial queueables) |
  | Batch | inner batchable |
  | `@future` | inner future |
  | Floor boundary (`==` floor → not counted) | predicate test |
  | `JobIds__c` below / at / above N | existing test plus the capacity test |
  | Monitor component disconnected during an in-flight call | jest (D14) |

- **Not unit-testable, proven by measurement (orchestrator)**:
  - The query plan (`query?explain=` with `leadingOperationType: Index`) and selector timings at 201k rows.
  - The CPU deltas for item 4.
  - Finalizer CPU and selector heap for item 5.
  - The share of single-item transactions for item 6 (baseline 5 of 25 and 3 of 27).
  - The fresh-org deploy for item 8.
  - Each runs three times on a quiet org, with the engine paused (`ApexJobConfig__c.Enabled__c = false`) between runs.
- **Regression guard**: the existing suites (`JobSelectorImplTest`, `AsyncProcessorTest`, `AdaptiveConsumptionLearnerTest`, `JobExecutorQueueableSpawnerTest`, `ApexJobTransactionContextTest`) stay green unchanged. The one exception is the bypass-user setup moving into `TestDataFactory`.

## Out of scope

- **Several chunks per description per transaction**: ruled OUT. Item 3 documents it only.
- **Any change to `JobExecutorServiceImpl.isRunning`**: ruled OUT (item 9). Items 4 and 7 reduce its call count, and that is the whole answer.
- **Splitting the selector into two queries**: ruled OUT. The selector stays one query for governor limits.
- **Tracking the executor by job Id**: ruled OUT.
- **Unlocked or managed packaging of `CustomIndex`**: the repo has no package definition (`sfdx-project.json`). Source deploy is the shipping path and the review proved it.
- **Reducing `JobIds__c` field length**: not needed for the measured gain, and it is a data-bearing metadata change.
- **`requestTable` row styling for non-candidates** (`requestTable.js:76-78`): the query returns candidates only, so the style is inert. It is not touched by this change.
