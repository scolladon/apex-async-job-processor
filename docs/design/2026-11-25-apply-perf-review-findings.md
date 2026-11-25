# Design — apply-perf-review-findings

> Brief: apply the 2026-11-25 scratch-org performance review in one run. Items 8, 1, 2, 4, 5, 6 and 7 get code; item 3 gets documentation only. Item 9, splitting the selector, multiple chunks per description, and tracking the executor by job Id are out.
> Status: draft → self-reviewed ×3 → revised against `docs/RULINGS.md` (R-001..R-014) and `docs/DOCTRINE.md` (D-1)

## Context

What exists today and constrains this change:

- **Hexagonal engine** under `apex-job/src/engine/{application,domain,service,adapter}`. DI goes through `ApexJobFactory` / `ApexJobFactoryImpl`, whose instances are static lazy singletons. Each domain or adapter class has a public no-arg constructor and a `@TestVisible` private constructor that takes the factory.
- **Per-transaction state** has exactly one home, `ApexJobTransactionContext` (`apex-job/src/engine/service/ApexJobTransactionContext.cls`). It is a static singleton with a `@TestVisible reset()`. Today it holds only `hasExecutedJobs`, which `JobExecutable.cls:37` writes and `JobSelectorImpl.cls:165` reads.
- **Insert trigger**: `apex-job/src/engine/domain/triggers/JobRequestAfterInsert.trigger` has one event, `after insert`. When the running user lacks `Bypass_JobRequest_Trigger` it calls `new ApexJobFactoryImpl().getSpawner().enqueue(0)`. No `before` trigger exists on `JobRequest__c`.
- **Scheduling date**: `JobRequest__c.NextExecutionDateTime__c` is a plain DateTime with no default and no index. `JobExecuted.cls` writes `null` on terminal states (`:52`, `:75`, `:87`) and a date on retry or recurrence (`:79`, `:83`). `IsCandidate__c` accepts `ISNULL(NextExecutionDateTime__c)` as due, and `DESIGN.md:138` documents the same rule.
- **Packaging**: `sfdx-project.json` declares only `packageDirectories` (`apex-job/src`, `apex-job/test`), with no `package`, `versionName` or `packageAliases`. The only shipping path in the repo is `sf project deploy start -d apex-job` (`package.json` wireit `build`). The brief's open question "does CustomIndex ship" therefore reduces to "does a source deploy accept it". The review's tested deploy already answers yes. Unlocked or managed packaging is not used here and is not designed for.
- **Tests**: Apex Mockery (`Mock.forType`, `spyOn`, `Expect.that`) centralised in `apex-job/test/unit/classes/ApexJobTestMock.cls`; builders in `ApexJobTestFixture.cls`. `AsyncProcessorTest.cls:3-28` already builds a user carrying `Bypass_JobRequest_Trigger` through a runtime `PermissionSet` and `SetupEntityAccess`. That is the pattern to reuse for the bypass creation path. `JobMonitorController` has no test class. The repo has no LWC test setup: no `@salesforce/sfdx-lwc-jest` and no `jest.config.js`. `.forceignore` already excludes `**/__tests__/**` (under its "LWC Jest" heading), so jest suites never deploy.
- **Prior designs** in `docs/design/2026-04-19-*.md` set the house style: a prose rationale, code sketches, a touchpoint table, and edge cases. `docs/design/2026-04-19-ewma-consumption-learning.md` introduced the variation counter that item 6 refines.
- **Doctrine / rulings**: `docs/RULINGS.md` R-001..R-014 settle every load-bearing choice of this design; each part below cites the ruling it implements. `docs/DOCTRINE.md` D-1 ("keep logic out of triggers") governs save-time values: a declarative mechanism comes before trigger code, and a trigger only delegates side effects such as the wake-up. The brief's PERIMETER and "Ruled" lines still bind. Ruling ids live in this doc only, never in source or test code.

## Requirements

1. A fresh org accepts `sf project deploy start -d apex-job/src` (item 8).
2. A request saved through `ApexJobManager.request()...save()` without `scheduleAt` gets executed and recorded. If recording fails, the finalizer does not re-enqueue at delay 0 (item 1).
3. Every request inserted with `NextExecutionDateTime__c` left unset carries a non-null date on all three creation paths: builder, plain DML, and DML under `Bypass_JobRequest_Trigger`. Terminal rows keep `null`. A `null` date, whether inserted explicitly or left by an update, means "not scheduled": the selector and `IsCandidate__c` both exclude the row (items 1 and 2; R-002, R-007).
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
- Permission set (R-001): `AdminAsyncJob.permissionset-meta.xml` gains `<tabSettings><tab>Job_Monitor_Console</tab><visibility>Visible</visibility></tabSettings>`. No `applicationVisibilities` is added; R-001 refuses both leaving the tab ungranted and adding app visibility on top.
- `README.md:300` lists the monitor's deploy metadata and gains `tabs/Job_Monitor_Console.tab-meta.xml`.

**Proof**: the orchestrator deploys `apex-job/src` to a new scratch org. Item 8 has no Apex test surface because metadata validity is checked by the deploy itself.

### Shared decision (items 1 and 2) — how `NextExecutionDateTime__c` gets its date (R-002, D-1)

The trap: `JobRequestAfterInsert.trigger:2` skips its whole body when the user has `Bypass_JobRequest_Trigger`, and an after-insert trigger cannot modify `Trigger.new` without a second DML. Stamping there would leave bulk-loaded rows `null`. With the new `<= :now` filter, those rows would never be selected again, so this location is excluded.

**Mechanism (R-002).** A platform field default on `apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml`:

```xml
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>NextExecutionDateTime__c</fullName>
    <defaultValue>NOW()</defaultValue>
    <label>Next Execution Date Time</label>
    <required>false</required>
    <trackTrending>false</trackTrending>
    <type>DateTime</type>
</CustomField>
```

No trigger stamps the date and no `JobRequestDueDate` class exists. D-1 puts a declarative mechanism before trigger code, and R-002 refuses a before-save trigger stamping null dates, a field default backed by a delegating before-save trigger, and builder-only stamping. No `JobRequest__c` trigger is added or changed for the date; `JobRequestAfterInsert.trigger` changes only for item 4.

**Pinned matrix** (scratch org, 2026-11-25, `NOW()` default deployed):

| Insert / save path | `NextExecutionDateTime__c` at save | Default stamps? |
|---|---|---|
| `ApexJobManager.request()...save()` without `scheduleAt` | unset (the builder constructor never touches it, `ApexJobManager.cls:49-53`) | yes |
| Apex `insert new JobRequest__c(...)` | unset | yes |
| Apex `JobRequest__c.SObjectType.newSObject(null, false)` then `insert` | unset, defaults not loaded in memory | yes |
| REST `POST /sobjects/JobRequest__c` | field omitted from the body | yes |
| Apex `insert` | explicit `null` (also `scheduleAt(null)`, `ApexJobManager.cls:66`) | **no** |
| REST `POST` | explicit `"NextExecutionDateTime__c": null` | **no** |
| Any `update` (Apex or REST), including a re-queue to `READY` | any | **no**, defaults apply on create only |

**Consequences.**
- An insert that leaves the field unset is due at once. Its stamp equals the insert transaction's clock, which is effectively `CreatedDate`, so `WaitTime__c` keeps its meaning ("waited since creation") for unscheduled requests.
- An explicit `null` on insert, and a re-queue that flips a row back to `READY`/`FAILURE`/`KILLED` without setting a date, both produce a row that is **not scheduled**. The selector's `<= :now` filter excludes it, and with R-007 so does `IsCandidate__c`. Today the `ISNULL` branch would run such a row; after this change it waits until someone sets a date. That rule is stated for consumers in `README.md` (developer API section, next to `scheduleAt(Datetime)` at `:170`, and the monitoring line at `:281`) and in `DESIGN.md` (the candidate-criteria block at `:134-140`): "a request runs when `NextExecutionDateTime__c <= now`; leave the field unset on insert to run as soon as possible; a `null` date (explicit on insert, or left by an update) means not scheduled, so a manual re-queue must set a date."
- `Bypass_JobRequest_Trigger` keeps its meaning, "skip the wake-up". The default is applied by the platform, not by a trigger, so the bypass has no effect on stamping. The custom-permission description (`apex-job/src/admin/customPermissions/Bypass_JobRequest_Trigger.customPermission-meta.xml`), `DESIGN.md:609` and `DESIGN.md:701-703` do **not** change for stamping.
- Stamping on update is refused by R-002 ("an update gets no date"). No `before update` path exists.

**Per-path tests** (new `apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls`). They pin the field default, so the first three are red today and green once the `defaultValue` deploys:
- `givenBuilderWithoutScheduleAt_whenSave_thenNextExecutionDateTimeIsStamped`
- `givenPlainInsertWithoutDate_whenInsert_thenNextExecutionDateTimeIsStamped`
- `givenUserWithTriggerBypass_whenInsertWithoutDate_thenNextExecutionDateTimeIsStamped`. It uses `System.runAs` with the bypass user and proves the bypass does not reach the default.
- `givenExplicitDate_whenInsert_thenDateIsKept`. This is a guard, and it is green today.
- `givenExplicitNullDate_whenInsert_thenRequestIsNotSelected`. It inserts, against one enabled description, a `READY` enabled request with `NextExecutionDateTime__c = null` and a control request with the field unset. It asserts the null row's field stays `null`, `new JobSelectorImpl().getEligibleJobs(new List<Id>())` returns the control row but not the null row (so the exclusion is due to the date, not to limits or the description), and the re-queried `IsCandidate__c` is `false` for the null row and `true` for the control. It is red today on the selector and `IsCandidate__c` assertions (the `ISNULL` branch makes the row a candidate), and pins the R-007 formula behaviour described in item 2.

Stamp assertions bracket the stored value between a `Datetime` captured before the DML, truncated to the whole second, and `Datetime.now()` after the re-query. The platform clock cannot be injected, and the comparison must not depend on whether the stored value keeps milliseconds.

DRY: the bypass-user setup in `AsyncProcessorTest.cls:3-28` moves into a shared test helper, `TestDataFactory.createUserWithTriggerBypass()` in `apex-job/test/unit/classes/TestDataFactory.cls`. `AsyncProcessorTest` and `JobRequestNextExecutionDateTimeTest` call it, so the code is not duplicated.

### Item 1 — null-date requests are never recorded and the engine hot-loops

**Context**
- `apex-job/src/engine/domain/classes/JobExecuted.cls:59`: `final Datetime baseRef = job.NextExecutionDateTime__c ?? job.CreatedDate;`. `CreatedDate` is never selected (`JobSelectorImpl.cls:26-121`), so the fallback throws `SObjectException`.
- `apex-job/src/engine/application/AsyncApexJobExecutor.cls:53-81` is `execute(FinalizerContext)`. Its first `try` (`:54-67`) catches the exception and logs it. The second `try` (`:69-80`) then calls `getDelayInMinutes()` (`:97-102`), which returns `0` because `jobExecutionResults` is non-empty.
- `README.md:152-155` documents exactly this builder call without `scheduleAt`.

**(a) Null-date path.** The shared decision closes it at the source: a builder request without `scheduleAt` now carries the `NOW()` default, and the `<= :now` filter excludes every `null` date, so a selected row always has a date. A synthesized `KILLED` result reuses rows that came from the selector, so it is covered too. The `?? job.CreatedDate` fallback is therefore unreachable, and R-004 removes it: `JobExecuted.cls:59` becomes `final Datetime baseRef = job.NextExecutionDateTime__c;`. R-004 refuses keeping the fallback with `CreatedDate` added to the SELECT, and falling back to the selection time.

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

`getDelayInMinutes()` keeps its current body, and an empty list yields `configService.getEnqueueDelayInMinutes()`. This avoids a boolean parameter and a new state flag. The list is read nowhere after the first `try`, because `wasLastChunkKilled` runs before it. Per R-005 the delay is the existing idle delay from `getEnqueueDelayInMinutes()`, never `0`: 1 min in business hours, clamped to [0, 10] by `ApexJobConfigServiceImpl.cls:21-31`. R-005 refuses a new fixed delay constant and leaving the restart to the watcher.

**Tests**
- Red, end-to-end: in `apex-job/test/integration/classes/AsyncProcessorTest.cls`, `givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded`. It creates a description for `AsyncProcessorTest.NormalPriorityProcessor`, then `ApexJobManager.request().forDescription(id).save()` with no `scheduleAt`, and runs `System.enqueueJob(new AsyncApexJobExecutor(factoryForTest))` inside `startTest`/`stopTest`. It asserts that the request was deleted (SUCCESS). Today the request stays `READY` with `AttemptNumber__c == null`. Like the neighbouring tests, it runs inside `System.runAs(getRunningUser())` (the bypass user). Otherwise the real after-insert wake-up would enqueue a second, unmocked executor. Because the date comes from the platform default (R-002), the bypass user's insert still gets a date, so this test also exercises that guarantee end to end.
- Red, unit: in `apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls`, `givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay`. `jobExecutionResults` is non-empty, `recordJobExecutionSpy` throws, and `getEnqueueDelayInMinutesSpy` returns `3`. Expect `enqueueSpy` to have been called with `3` and never with `0`. The existing `givenFinalizerContext_whenExecuteWithRemainingJobs_thenExecuteAndReenqueueWith0Delay` stays green, which proves the success path is unchanged.

### Item 2 — the selector does a full table scan

**Context**
- `apex-job/src/engine/adapter/JobSelectorImpl.cls:18-153` is `getEligibleJobs(List<Id>)`. Its WHERE clause is at `:123-144`, `IsCandidate__c = TRUE` at `:125`, and `LIMIT :ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE` at `:151`.
- `apex-job/src/monitor/classes/adapter/JobMonitorController.cls:11-44` is `getJobRequestPage`: `WHERE IsCandidate__c = TRUE ... ALL ROWS`, polled every 2 s.

**Change**
1. New `apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml`. The brief gives the exact content (`<allowNullValues>true</allowNullValues>`, no `<field>` element). R-006 keeps `allowNullValues` at `true`, the only measured value, and refuses `false`.
2. Selector: capture `final Datetime now = Datetime.now();` next to the other locals at `:21-24`, and add `AND NextExecutionDateTime__c <= :now` directly after `IsCandidate__c = TRUE`. Everything else is unchanged: it stays one query, keeps the formula as the residual check, and never uses `OR NULL`.
3. The date invariant comes from the shared decision above (R-002): unset on insert means due now, `null` means not scheduled.
4. Installed orgs that already hold runnable rows with a null date are covered by R-003, which refuses a release note alone. Those rows predate the not-scheduled rule and were due under the `ISNULL` branch, so they are backfilled rather than left unscheduled. The operator script `scripts/apex/backfill-next-execution.apex` follows the house pattern of `scripts/apex/restart-watcher.apex` and lives outside every packageDirectory. It runs after the deploy. Each run sets `NextExecutionDateTime__c = CreatedDate` on rows where `NextExecutionDateTime__c = null AND Status__c IN ('READY','FAILURE','KILLED')`, for up to 10,000 rows, and is re-run until it reports 0.
5. `IsCandidate__c` (R-007). The formula loses its `ISNULL(NextExecutionDateTime__c)` branch: `,OR( NOW() &gt;= NextExecutionDateTime__c , ISNULL(NextExecutionDateTime__c) )` becomes `,NOW() &gt;= NextExecutionDateTime__c`. The premise is no longer "a null date cannot exist" but "a null date means not scheduled": explicit-null inserts and date-less re-queues do exist (shared decision), and the formula must reject them like the selector does. `DESIGN.md:138` drops `OR NextExecutionDateTime__c IS NULL` and gains the not-scheduled rule. R-007 refuses keeping the branch and documenting the selector's exclusion instead.
   - Null-date evaluation after removal. The field sets `formulaTreatBlanksAs` `BlankAsZero`; whether that option changes a blank DateTime comparison is not pinned on the field itself. Probe (FormulaEval API, `Formula.builder()` on `JobRequest__c`, scratch org, 2026-11-25; the builder exposes no treat-blanks option): `NOW() >= NextExecutionDateTime__c` on a null date evaluates to `null`, `AND(true, NOW() >= NextExecutionDateTime__c)` evaluates to `false`, and a past date evaluates to `true`. Expected field result: `IsCandidate__c = false` for a null date. The field-level pin is `givenExplicitNullDate_whenInsert_thenRequestIsNotSelected`, which asserts the re-queried `IsCandidate__c` is `false`. If that assertion fails on the deployed formula, R-007's outcome is not met by removal alone; that is a blocker raised to the user, not a silent formula change.
   - The monitor's "Is Candidate?" column and the selector then agree for every row.
6. Monitor `getJobRequestPage` (R-008): add the same `AND NextExecutionDateTime__c <= :now` and drop `ALL ROWS` together with the `IsDeleted ASC` sort key. R-008 refuses keeping `ALL ROWS` with the filter, and leaving the query as is. The engine deletes only `SUCCESS` rows (`JobRepositoryImpl.cls:92-94`), and `IsCandidate__c` rejects those. `ALL ROWS` can therefore surface only rows a user deleted while they were runnable. The engine never runs those rows because the selector has no `ALL ROWS`, so showing them as candidates is wrong.

**Tests**
- Unit: `JobSelectorImplTest.cls` keeps its existing coverage (`givenFutureJobs_whenGetJobs_thenExcludesFutureJobs`, etc.). After R-007 the filter and the residual formula exclude the same rows, so the filter alone cannot be observed behaviourally. Its proof is the query plan, not a unit test.
- The per-path tests above prove requirement 3, and `givenExplicitNullDate_whenInsert_thenRequestIsNotSelected` proves the not-scheduled rule end to end (selector plus formula).
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
- R-009 settles where the flag lives (`ApexJobTransactionContext`) and that the guard goes in a new `wakeUp()` called only by the insert trigger, rather than inside `enqueue(Integer)` or in a static flag in the spawner. Putting it inside `enqueue` would also gate the finalizer, the watcher and `restartEngine` whenever they share a transaction with an insert. In tests that share a transaction routinely, so an explicit enqueue would silently return `null`.

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

**Change** (N = 20 per R-010, which refuses 10 and 50; no ruling ids go in source)

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

**Callers.** Both deviations are in chunk-total units, which is where measurement resolution lives (1 ms CPU over the whole chunk). R-012 rules this single predicate for both branches and refuses comparing the per-item deviation to the floor.
- Base: `isSignificantVariation(usage, currentBase, model.noiseFloor)`.
- Per-item: `final Integer itemsBeyondFirst = chunkSize - 1;` then `isSignificantVariation(newPerItem * itemsBeyondFirst, currentPerItem * itemsBeyondFirst, model.noiseFloor)`. The relative part is unchanged from today because `itemsBeyondFirst` cancels. The absolute part becomes the deviation of the chunk total. Example: a reading of 0.0204 ms/item against a learned 0.0408 ms/item over 49 items gives `|1 - 2| = 1 ms`, below the 5 ms floor, so it is not counted. A real per-item doubling of a 1 ms/item job gives 48 ms, which is counted.

**Floors** (R-011). The values are cpuTime 5 ms, heapSize 4,096 B, calloutTime 5 ms and 1 for every counter dimension, held as named constants on `ConsumptionModel`. Each model resolves its floor once in the constructor, so the signature does not change:

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
- `calloutTime` is a millisecond dimension, not a counter. R-011 sets its floor at 5 ms and refuses 1; it also refuses deferring the values to a measured run.

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

**LWC verification (R-013)**: `sfdx-lwc-jest` fake-timer tests plus one manual scratch-org network check. R-013 refuses either one alone.

Setup:
- `package.json` `devDependencies` gains `@salesforce/sfdx-lwc-jest`.
- New `jest.config.js` at the repo root uses the package's default config unchanged:

  ```js
  const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

  module.exports = { ...jestConfig };
  ```

- `package.json` `scripts` gains `"test:lwc": "wireit"`, with this wireit entry. It needs no org, so it does **not** depend on `build`:

  ```json
  "test:lwc": {
    "command": "sfdx-lwc-jest",
    "files": ["apex-job/src/monitor/lwc/**", "jest.config.js", "package.json"],
    "output": []
  }
  ```

- `test:lwc` joins the `test` wireit `dependencies` next to `test:unit` and `test:integration`, so `npm test` runs all three. Coverage runs as `npm run test:lwc -- --coverage`.
- Suites live in `apex-job/src/monitor/lwc/<cmp>/__tests__/<cmp>.test.js` for `engineControls`, `requestTable` and `statusByProcessorTable`. `.forceignore` already lists `**/__tests__/**`, so no `.forceignore` change is needed and the suites never deploy.
- Each suite mocks its Apex imports with `jest.mock('@salesforce/apex/JobMonitorController.<method>', () => ({ default: jest.fn() }), { virtual: true })`. `engineControls` also mocks `@salesforce/customPermission/Manage_Async_Job_Engine` the same way. Suites use `jest.useFakeTimers()` and flush promises between timer advances.
- Cases per component:
  - `givenConnected_whenIntervalElapses_thenOneApexCallPerInterval` (one call on connect, one more per `POLL_INTERVAL_MS`; for `statusByProcessorTable` one `getStatusByProcessor` plus one `getJobDescriptionInfos`).
  - `givenDisconnected_whenIntervalElapses_thenNoFurtherCall`.
  - `givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed`.
  - `givenRejectedCall_whenIntervalElapses_thenPollingResumes`.
- Manual check, once on the scratch org: devtools Network on the console tab shows one `getEngineStatus` call per 5 s per tab, and the calls stop after navigating away.

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
| 8 | `apex-job/src/monitor/tabs/Job_Monitor_Console.tab-meta.xml` (new), `apex-job/src/monitor/applications/Async_Job_Monitor.app-meta.xml`, `apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml` (R-001), `README.md` |
| 1+2 date | `apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml` (`<defaultValue>NOW()</defaultValue>`, R-002), `scripts/apex/backfill-next-execution.apex` (new, R-003). No trigger and no new class. |
| 1 | `AsyncApexJobExecutor.cls` (R-005), `JobExecuted.cls:59` (R-004) |
| 2 | `apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml` (new, R-006), `JobSelectorImpl.cls`, `IsCandidate__c.field-meta.xml` (R-007), `JobMonitorController.getJobRequestPage` (R-008) |
| 4 | `ApexJobTransactionContext.cls`, `JobExecutorSpawner.cls`, `JobExecutorQueueableSpawner.cls`, `JobRequestAfterInsert.trigger` (R-009) |
| 5 | `JobRepositoryImpl.cls`, `JobIds__c.field-meta.xml` (R-010) |
| 6 | `AdaptiveConsumptionLearner.cls` (R-012), `ConsumptionModel.cls` (R-011), `LimitsUsage.cls` (3 constants made public) |
| 7 | `JobMonitorController.cls`, `engineControls.js`, `requestTable.js`, `statusByProcessorTable.js`, `apex-job/src/monitor/lwc/<cmp>/__tests__/<cmp>.test.js` (new ×3), `jest.config.js` (new), `package.json` (R-013) |
| docs | `DESIGN.md` (`:138` plus the not-scheduled rule, `:154`, `:296`, `:335`, `:337-339`, `:455-456`, `:553-590`, `:677-679`, new item-3 section; `:609` and `:701-703` unchanged), `README.md` (`:170`, `:281`, `:300`), `CONTRIBUTING.md` (R-014) |

## Rulings

Settled in `docs/RULINGS.md`; this design implements them as written.

- R-001 — `AdminAsyncJob` grants `Job_Monitor_Console` as Visible through `tabSettings`, no `applicationVisibilities` (item 8).
- R-002 — `NextExecutionDateTime__c` carries a `NOW()` field default and no trigger stamps it; unset on insert is due now, explicit `null` or update gets no date (shared decision).
- R-003 — operator script `scripts/apex/backfill-next-execution.apex` sets null dates of runnable rows to `CreatedDate`, 10,000 rows per run, re-run until 0 (item 2).
- R-004 — `JobExecuted` drops the `CreatedDate` fallback; `NextExecutionDateTime__c` alone is the timing base (item 1).
- R-005 — after a failed recording the finalizer discards the results and re-enqueues with `getEnqueueDelayInMinutes()`, never `0` (item 1).
- R-006 — the custom index keeps `allowNullValues` `true` (item 2).
- R-007 — `IsCandidate__c` loses its `ISNULL` branch so a null date means not scheduled, and `DESIGN.md` states it (item 2).
- R-008 — `getJobRequestPage` adds `NextExecutionDateTime__c <= :now` and drops `ALL ROWS` with its `IsDeleted` sort key (item 2).
- R-009 — wake-up flag in `ApexJobTransactionContext`, guard in a new `JobExecutorSpawner.wakeUp()` called only by the insert trigger, free-slot check before every enqueue (item 4).
- R-010 — `JobIds__c` keeps the last 20 ids (item 5).
- R-011 — noise floors as named constants: cpuTime 5 ms, heapSize 4,096 B, calloutTime 5 ms, every counter 1 (item 6).
- R-012 — one named predicate requires chunk-total deviation above the floor and relative deviation above `VariationResetThreshold__c`, for both branches (item 6).
- R-013 — LWC changes verified by `sfdx-lwc-jest` fake-timer tests plus one manual scratch-org network check (item 7).
- R-014 — `CONTRIBUTING.md` documents deploying Apex Mockery from source at tag `v2.3.0` before deploying `apex-job/test` (test strategy).

## Decision candidates

| # | Choice | Alternatives (≤3) | Recommendation | Why |
|---|---|---|---|---|
| DC-1 | How the en_US requirement on the test user is held (two existing test classes depend on it, see Test strategy) | A. Add `"language": "en_US"` to `config/project-scratch-def.json` · B. A `CONTRIBUTING.md` line next to the R-014 step: create the scratch org with an en_US admin user · C. Leave it to whoever creates the org | B | B documents the condition the suite actually needs, at no risk. A is not pinned: whether the scratch-def `language` key also sets the admin user's language and locale was not measured, so A is acceptable only after one scratch org created from it shows an en_US user. C keeps the two tests locale-fragile. |

## Test strategy

- **Red first, per item**:
  - 1: `AsyncProcessorTest.givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded` and `AsyncApexJobExecutorTest.givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay`.
  - 1+2: the three per-path tests and the explicit-null test in `JobRequestNextExecutionDateTimeTest`. They pin the `NOW()` field default (R-002) and the null-date formula result (R-007).
  - 4: the four measured rows plus `@future` in `JobRequestTriggerTest`.
  - 5: `JobRepositoryImplTest.givenJobIdsAtCapacity_...`.
  - 6: the two resolution-floor tests in `AdaptiveConsumptionLearnerTest`.
  - 7: `JobMonitorControllerTest.givenRequestsAcrossTwoDescriptionsAndTwoStatuses_..._thenQueryRowsEqualGroupCount`, and the jest suites (red because no component has a `disconnectedCallback` and `engineControls` makes 3 calls per 500 ms).
  - Every one of these fails on `main` for the reason the brief measured.
- **Unit vs integration**:
  - Domain logic (the learner predicate, `ConsumptionModel` floors, `buildJobIds`) gets unit tests with Apex Mockery where a factory is involved.
  - The field default, the formula, trigger, Batch and `@future` behaviour and the governor-limit accounting run as real-DML tests in `apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls` and `JobRequestTriggerTest.cls`, because a field default, `System.isBatch()`, `System.isFuture()` and `Limits.*` cannot be mocked.
  - LWC polling runs under `npm run test:lwc` (R-013), locally, without an org.
- **Test environment** (facts the suites depend on):
  - The scratch org's running user must be en_US. `JobExecutorQueueableSpawnerTest.cls:74`, `:92` and `:110` assert English platform exception messages (none of the three strings exists in `apex-job/src`), and `AsyncProcessorTest.cls:15` looks up the profile by `Name = 'System Administrator'`, which is the English label. `config/project-scratch-def.json` sets no `language`; DC-1 covers how the requirement is held.
  - Apex Mockery v2.3.0 is deployed from source at that tag before `apex-job/test` (R-014, documented in `CONTRIBUTING.md`).
- **Edge matrix**:

  | Edge | Covered by |
  |---|---|
  | Explicit date kept on insert | `givenExplicitDate_whenInsert_thenDateIsKept` |
  | Explicit `null` date on insert is not scheduled | `givenExplicitNullDate_whenInsert_thenRequestIsNotSelected` |
  | Bypass user still gets a date | per-path bypass test |
  | Second wake-up in the same transaction | spawner unit test |
  | Slots exhausted | spawner unit test (50 trivial queueables) |
  | Batch | inner batchable |
  | `@future` | inner future |
  | Floor boundary (`==` floor → not counted) | predicate test |
  | `JobIds__c` below / at / above N | existing test plus the capacity test |
  | Monitor component disconnected during an in-flight call | jest (R-013) |
  | Re-queue by update without a date | not tested: the platform never applies defaults on update (pinned matrix); documented as "not scheduled" in `README.md` and `DESIGN.md` |

- **Not unit-testable, proven by measurement (orchestrator)**:
  - The query plan (`query?explain=` with `leadingOperationType: Index`) and selector timings at 201k rows.
  - The CPU deltas for item 4.
  - Finalizer CPU and selector heap for item 5.
  - The share of single-item transactions for item 6 (baseline 5 of 25 and 3 of 27).
  - The fresh-org deploy for item 8.
  - The manual network check for item 7 (R-013).
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
