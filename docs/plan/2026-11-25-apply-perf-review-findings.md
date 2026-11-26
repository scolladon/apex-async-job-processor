# Plan — apply-perf-review-findings

> Source: design doc `docs/design/2026-11-25-apply-perf-review-findings.md` · Rulings `R-001..R-015` · Doctrine D-1
> The plan is the implementation script AND the knowledge handoff. Part agents start
> with zero context: whatever a part block omits is paid later as agent rediscovery.
> `plan-lint.sh` enforces the schema below — the plan phase cannot close without it.

Branch: `fix/apply-perf-review-findings` (already checked out in the worktree). All commands run from the worktree root.

**Phase gate (orchestrator, after the last part):**

```bash
npm run prettier && sf code-analyzer run && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -l RunLocalTests -w 30 && npm run test:lwc
```

## Shared facts every part needs

- **Measured proofs (orchestrator, not parts)**:
  - the fresh-org deploy (Part 1);
  - `query?explain=` showing `leadingOperationType: Index` on `NextExecutionDateTime__c` and the selector timings (Part 5);
  - the CPU deltas of the trigger (Part 7);
  - the finalizer CPU and selector heap (Part 8);
  - the share of single-item transactions (Parts 9-10);
  - the manual devtools network check, which must show one `getEngineStatus` call per 5 s per tab and nothing after navigating away (Part 13).
- **LWC test filter**: Parts 13-15 run `npm run test:lwc -- <component>`. If Part 12 recorded a different working forwarding form in CONTRIBUTING.md, use that form.

- **Org**: alias `dev-async-processor` holds main's code, Apex Mockery v2.3.0, benchmark-only `Perf*` classes and about 200k `JobRequest__c` rows. The engine is paused (`ApexJobConfig__c.Enabled__c = false`). Apex tests do not see org data. Never commit `Perf*` benchmark classes, never re-enable the engine, never run anonymous Apex that writes data (this includes the backfill script of Part 4). The org user is en_US and has `AdminAsyncJob`. `NextExecutionDateTime__c` in the org matches the repo (no default). Normal red-first applies everywhere: deploy the test, watch it fail, then change the code.
- **Conventions** (CLAUDE.local.md and user rules): `given<Pre>_when<Act>_then<Exp>` method names (PMD-enforced), `// Arrange` / `// Act` / `// Assert` bodies, SUT variable `sut` (except stateless static utilities), `final` locals and params, Apex Mockery (`Mock.forType`, `.stub`, `spyOn(...).returns(...)`, `.throwsException(...)`, `Expect.that(spy).hasBeenCalledTimes(n)` / `.hasBeenCalledWith(v)` / `.hasNotBeenCalled()`). Methods ≤20 lines, no boolean parameters, no magic values (named constants), early returns, nesting ≤2. No ruling, doctrine or item ids (R-xxx, D-x, "item 4") in source or test code. No new `@SuppressWarnings`, no `// NOPMD`.
- **Formatting**: Prettier with `prettier-plugin-apex` and `@prettier/plugin-xml`, print width 200. Several files already fail `prettier --check` on main (`Async_Job_Monitor.app-meta.xml`, `JobIds__c.field-meta.xml`, `JobRequestAfterInsert.trigger`, all four monitor LWC `.js` files). A part that touches one of them runs `npx prettier --write <file>` before its gate.
- **Pre-commit hook**: Husky runs lint-staged, i.e. `sf code-analyzer run -t <staged .cls/.xml>`. Commit with `git commit -m "<message>"`, one line, no body, no trailers. Stage only the part's own files.
- **New Apex class companions**: every new `.cls` needs a `.cls-meta.xml` with `apiVersion` 65.0, `status` Active (copy apex-job/test/integration/classes/ApexJobManagerTest.cls-meta.xml).
- **`DESIGN.md` and `README.md` are edited by most parts on purpose.** Docs travel with the code, and each part edits only its own disjoint section, so plan-lint's cross-part overlap warning on them is expected. Line numbers cited for them are main's; re-locate by heading, because earlier parts shift lines.
- **Apex part gate shape**: `npx prettier --check <touched .cls/.trigger/.xml> && sf code-analyzer run -t <touched .cls> && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t <touched test classes> -w 20 -r human`. A deploy error or any failing test is red.

## Decision candidates

- **DC-A — unhandled rejection under jest (Parts 13-15).** The design keeps `try { await this.refresh(); } finally { re-arm }` with no `catch`, so a rejected Apex call surfaces as an unhandled promise rejection. If jest (sfdx-lwc-jest 7, Jest 29) turns that into a failed test or a crashed worker, the `givenRejectedCall_...` case cannot go green as designed.
  - (a) Keep the design: the test attaches a no-op `process.on('unhandledRejection', ...)` handler scoped to the case, then restores it. Production code stays as designed.
  - (b) Add a `catch (error)` that logs with context (`console.error('statusByProcessorTable: refresh failed', error)`) and keeps polling. The error is logged, not swallowed, but this changes the design.
  - (c) Stop and raise a blocker.
  - Recommendation: (a). It needs no design change. If (a) fails, choose (c), because (b) changes a ruled shape.
- **DC-B — whole-file Prettier reformat of the LWC `.js` files (Parts 13-15).** The four monitor `.js` files are not Prettier-clean on main, and the part gate requires `prettier --check` on every touched file.
  - (a) Run `prettier --write` on the touched file in the same commit.
  - (b) Commit a separate `style(monitor): format LWC sources` first, inside the same part.
  - Recommendation: (b). The behaviour diff stays readable, and the part still lands as one agent lifecycle with two commits. The style commit comes first and the part's named commit comes last.

## Part 1 — app deploys on a fresh org; scratch definition in en_US

### Context
- Create `apex-job/src/monitor/tabs/Job_Monitor_Console.tab-meta.xml` with exactly this content:
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <CustomTab xmlns="http://soap.sforce.com/2006/04/metadata">
      <flexiPage>Job_Monitor_Console</flexiPage>
      <label>Job Monitor Console</label>
      <motif>Custom67: Gears</motif>
  </CustomTab>
  ```
  The FlexiPage apex-job/src/monitor/flexipages/Job_Monitor_Console.flexipage-meta.xml already exists and is an AppPage (read-only reference).
- Edit `apex-job/src/monitor/applications/Async_Job_Monitor.app-meta.xml`: delete line 18, `<utilityBar>Async_Job_Monitor_UtilityBar</utilityBar>`. Keep line 16, `<tabs>Job_Monitor_Console</tabs>`. The file is not Prettier-clean: run `npx prettier --write` on it.
- Edit `apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml`. Add one `tabSettings` element after the last `objectPermissions` block and before `</PermissionSet>`, following metadata alphabetical order:
  ```xml
      <tabSettings>
          <tab>Job_Monitor_Console</tab>
          <visibility>Visible</visibility>
      </tabSettings>
  ```
  Add NO `applicationVisibilities`, because the ruling refuses it.
- Edit `config/project-scratch-def.json`: add `"language": "en_US"` after `"edition"`. Reference shape: `{ "orgName", "edition": "Developer", "language": "en_US", "features": [...], "settings": {...} }`. The file uses 2-space indent.
- Docs:
  - `README.md:300`: the "Deploys with metadata" line lists `applications/Async_Job_Monitor.app-meta.xml`, `tabs/Job_Monitor_Console.tab-meta.xml` and `flexipages/Job_Monitor_Console.flexipage-meta.xml`.
  - `DESIGN.md:611-613`, "Permission Set: AdminAsyncJob": add "Grants the `Job_Monitor_Console` tab (Visible)."
  - `DESIGN.md` directory tree, around `:734-738` under `monitor/`: add the line `├── tabs/              (Job_Monitor_Console)`.
- No Apex surface. Metadata validity is proven by the deploy. The orchestrator proves the fresh-org deploy.

### TDD steps
- GUARD: none. The change is metadata only and has no Apex test surface. The deploy below is the check: it must succeed with the utility bar reference gone and the tab present.
- GREEN: add the tab file, delete the utility-bar line, add `tabSettings`, add the scratch-def language, and edit the docs.
- REFACTOR: none.

### Gate
```bash
npx prettier --check apex-job/src/monitor/tabs/Job_Monitor_Console.tab-meta.xml apex-job/src/monitor/applications/Async_Job_Monitor.app-meta.xml apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml config/project-scratch-def.json && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30
```

### Commit
`fix(monitor): ship the Job Monitor Console tab and drop the missing utility bar`

## Part 2 — `NextExecutionDateTime__c` defaults to NOW() on insert

### Context
- The mechanism is a platform field default, never a trigger. Edit `apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml` to exactly:
  ```xml
  <?xml version="1.0" encoding="UTF-8" ?>
  <CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
      <fullName>NextExecutionDateTime__c</fullName>
      <defaultValue>NOW()</defaultValue>
      <label>Next Execution Date Time</label>
      <required>false</required>
      <trackTrending>false</trackTrending>
      <type>DateTime</type>
  </CustomField>
  ```
  Do not touch any trigger or any `JobRequest__c` trigger code for this part.
- The default applies on create only, and only when the field is left unset:
  - Applies: builder `save()` without `scheduleAt`, `insert new JobRequest__c(...)`, bulk API with the field omitted.
  - Does not apply: an explicit `null` on insert, and every update.
- Shared test helper (DRY; public static, test-only, no downstream surface): edit `apex-job/test/unit/classes/TestDataFactory.cls`.
  - Add `public static final String TRIGGER_BYPASS_USERNAME = 'test.user@ajp.io';`.
  - Add `public static User createUserWithTriggerBypass()`. It moves the body of apex-job/test/integration/classes/AsyncProcessorTest.cls `setup()` (lines 3-28) unchanged:
    - a System Administrator user with the en_US locale, the Europe/Paris timezone and username `TRIGGER_BYPASS_USERNAME`;
    - a runtime `PermissionSet` `ByPassTriggers`;
    - a `SetupEntityAccess` on the `Bypass_JobRequest_Trigger` CustomPermission;
    - a `PermissionSetAssignment`.
  - The helper returns the inserted user. Keep each method ≤20 lines by splitting it into private helpers (for example `insertAdminUser()` and `grantTriggerBypass(Id userId)`).
- Edit `apex-job/test/integration/classes/AsyncProcessorTest.cls`:
  - `setup()` becomes a one-line `TestDataFactory.createUserWithTriggerBypass();`.
  - `getRunningUser()` queries `WHERE Username = :TestDataFactory.TRIGGER_BYPASS_USERNAME`.
  - Add the end-to-end test below. Model it on `givenSystemEnabled_whenExecutorRunsWithEligibleJobs_thenDeleteSuccessfulJob` (`:100-144`): `System.runAs(getRunningUser())`, an inline insert of `JobDescription__c(Name='NormalPriorityProcessor', ProcessorName__c='AsyncProcessorTest.NormalPriorityProcessor', Enabled__c=true)`, `insert new ApexJobConfig__c(Enabled__c = true)`, `new AsyncApexJobExecutor(new ApexJobFactoryForTest())`, and `System.enqueueJob` between `startTest` and `stopTest`. The private inner `ApexJobFactoryForTest` (`:751-761`) mocks only the spawner.
- Create `apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls` (`@IsTest private class`) plus its cls-meta.xml companion.
  - Each stamp assertion brackets the stored value: `lowerBound` is `Datetime.now()` captured before the DML and truncated to the whole second (`Datetime.newInstance(t.getTime() - Math.mod(t.getTime(), MILLIS_PER_SECOND))`, with a `MILLIS_PER_SECOND = 1000` constant); `upperBound` is `Datetime.now()` after the re-query.
  - Descriptions come from `ApexJobTestFixture.aJobDescription().build()` followed by `insert`. Requests are `new JobRequest__c(JobDescription__c = d.Id, Status__c = ApexJobStatus.READY.name(), Enabled__c = true)` with NO `NextExecutionDateTime__c`.
  - The bypass test calls `TestDataFactory.createUserWithTriggerBypass()` inside the test method, then does both the description insert and the request insert inside `System.runAs(user)`. `runAs` is what makes the setup-object DML followed by non-setup DML legal (otherwise `MIXED_DML_OPERATION`).
  - No `ApexJobConfig__c` is inserted, so the engine is disabled and the after-insert wake-up returns early.
- Docs:
  - `README.md:170`, the Job Request builder bullet: add "Without `scheduleAt`, the request is due as soon as it is inserted (`NextExecutionDateTime__c` defaults to `NOW()`)."
  - `DESIGN.md:79`, the data-model line `NextExecutionDateTime__c (DateTime)`: becomes `NextExecutionDateTime__c (DateTime, default NOW())`.
  - `DESIGN.md` directory tree `integration/ (3 test classes)`: becomes `(4 test classes)`.
  - Do NOT edit the `Bypass_JobRequest_Trigger` description, `DESIGN.md:609` or `DESIGN.md:701-703`, because stamping does not involve the trigger.

### TDD steps
1. Preparatory REFACTOR (GUARD first): move the bypass-user setup into `TestDataFactory.createUserWithTriggerBypass()` and point `AsyncProcessorTest.setup`/`getRunningUser` at it. GUARD: every existing `AsyncProcessorTest` method stays green, which proves the move changes no behaviour.
2. RED `JobRequestNextExecutionDateTimeTest.givenBuilderWithoutScheduleAt_whenSave_thenNextExecutionDateTimeIsStamped`: `ApexJobManager.request().forDescription(d.Id).save()`, re-query, assert the date is non-null and within the bounds. It fails because the field has no default, so the stored value is `null`.
3. RED `givenPlainInsertWithoutDate_whenInsert_thenNextExecutionDateTimeIsStamped`: same, through `insert`. It fails because the stored value is `null`.
4. RED `givenUserWithTriggerBypass_whenInsertWithoutDate_thenNextExecutionDateTimeIsStamped`: the insert runs inside `System.runAs(bypassUser)`. It fails because the stored value is `null`.
5. GUARD `givenExplicitDate_whenInsert_thenDateIsKept`: insert with `NextExecutionDateTime__c = Datetime.now().addHours(1)` and assert the stored value is the same date. It passes today because no default exists and an explicit value is stored as given. It must stay green after GREEN, which proves the default never overrides an explicit value.
6. RED `AsyncProcessorTest.givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded`: inside `System.runAs(getRunningUser())`, `ApexJobManager.request().forDescription(descId).save()` with no `scheduleAt`, then run the executor between `startTest` and `stopTest`. Assert that `[SELECT COUNT() FROM JobRequest__c WHERE Id = :saved.Id] == 0`, i.e. the request succeeded and was deleted. It fails today: the null-dated row is selected through the formula's `ISNULL` branch, `JobExecuted.calculateTimingMetrics` reads the unselected `CreatedDate` and throws `SObjectException`, the finalizer swallows it, and the row stays `READY` with `AttemptNumber__c == null`.
7. GREEN: add `<defaultValue>NOW()</defaultValue>` to the field metadata, then deploy. Steps 2-6 are green.
8. REFACTOR: shared bracket helper `assertStamped(Id requestId, Datetime lowerBound)` inside the test class. Edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml apex-job/test/unit/classes/TestDataFactory.cls apex-job/test/integration/classes/AsyncProcessorTest.cls apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls && sf code-analyzer run -t apex-job/test/unit/classes/TestDataFactory.cls apex-job/test/integration/classes/AsyncProcessorTest.cls apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobRequestNextExecutionDateTimeTest,AsyncProcessorTest,ApexJobManagerTest -w 20 -r human
```

### Commit
`fix(engine): default NextExecutionDateTime__c to NOW() on insert`

## Part 3 — no zero-delay re-enqueue after a failed recording; drop the CreatedDate fallback

### Context
- Edit `apex-job/src/engine/application/AsyncApexJobExecutor.cls`.
  - `execute(FinalizerContext)` (`:53-81`): the first `catch` (`:63-67`) logs. Add a call to a new `private void discardUnrecordedResults() { this.jobExecutionResults.clear(); }` at the end of that `catch`. It exists because nothing was persisted: the exception fires in `stageExecution` before any DML, and the DML is `allOrNone:false`, so it does not throw.
  - `getDelayInMinutes()` (`:97-102`) keeps its body. An empty list then yields `configService.getEnqueueDelayInMinutes()` (1 min in business hours, clamped to [0,10]), never `0`.
  - `wasLastChunkKilled` runs before the clear, so nothing reads the list after the first `try`.
  - Add no new delay constant and no boolean flag.
- Edit `apex-job/src/engine/domain/classes/JobExecuted.cls:59`: `final Datetime baseRef = job.NextExecutionDateTime__c ?? job.CreatedDate;` becomes `final Datetime baseRef = job.NextExecutionDateTime__c;`. Part 2 makes the fallback unreachable for unset inserts, and Part 4/5 exclude null dates from selection.
- Edit `apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls`:
  - The model to follow is `givenFinalizerContext_whenEnabledAndRecordExecutionThrows_thenItReenqueue` (`:79-94`), which uses `mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'))`. The private `TestException` is at `:322`.
  - The non-empty-results pattern is at `:26-27`: `final Mock jobExecutedMock = Mock.forType(JobExecuted.class); sut.jobExecutionResults.add((JobExecuted) jobExecutedMock.stub);`.
  - Mocks come from apex-job/test/unit/classes/ApexJobTestMock.cls (read-only): `isSystemEnabledSpy`, `getEnqueueDelayInMinutesSpy`, `recordJobExecutionSpy`, `enqueueSpy`, `errorSpy`.
- Docs:
  - `DESIGN.md`, the Execution Flow "[Block 2: Re-enqueue]" (around `:206-208`): it reads "delay = 0 if work done and recorded; configured idle delay if idle or if recording threw (results discarded)".
  - `README.md:362-364`, the Finalizer bullets: add "If recording failed: results are discarded and the idle delay is used."
  - `DESIGN.md:387-400` "AsyncApexJobExecutor": if it states the delay rule, align it the same way.

### TDD steps
1. RED `givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay`. Arrange: `isSystemEnabledSpy.returns(true)`, `getEnqueueDelayInMinutesSpy.returns(3)`, `recordJobExecutionSpy.throwsException(...)`, and one stub `JobExecuted` added to `sut.jobExecutionResults`. Act: `sut.execute((FinalizerContext) null)`. Assert `Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1)` and `.hasBeenCalledWith(3)`; calledTimes(1) together with calledWith(3) proves it was never called with `0`. It fails because `getDelayInMinutes()` sees the non-empty list and returns `0`, so `enqueue` receives `0`.
2. GREEN: add `discardUnrecordedResults()` in the first `catch`.
3. GUARD `givenFinalizerContext_whenExecuteWithRemainingJobs_thenExecuteAndReenqueueWith0Delay` (`:21-38`): it stays green, which proves the success path still re-enqueues at `0`.
4. REFACTOR (GUARD-protected): remove the `?? job.CreatedDate` fallback in `JobExecuted.cls:59`. GUARDs: `JobExecutedTest` (every fixture request carries a date, ApexJobTestFixture.cls:417) and `AsyncProcessorTest.givenBuilderRequestWithoutScheduleAt_whenExecutorRuns_thenRequestIsRecorded` from Part 2 both stay green. Edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/application/AsyncApexJobExecutor.cls apex-job/src/engine/domain/classes/JobExecuted.cls apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls && sf code-analyzer run -t apex-job/src/engine/application/AsyncApexJobExecutor.cls apex-job/src/engine/domain/classes/JobExecuted.cls apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t AsyncApexJobExecutorTest,JobExecutedTest,AsyncProcessorTest -w 20 -r human
```

### Commit
`fix(executor): re-enqueue with the idle delay when recording fails`

## Part 4 — a null date means not scheduled; backfill script

### Context
- Edit `apex-job/src/engine/domain/objects/JobRequest__c/fields/IsCandidate__c.field-meta.xml`. In `<formula>`, the line `  ,OR( NOW() &gt;= NextExecutionDateTime__c , ISNULL(NextExecutionDateTime__c) )` becomes `  ,NOW() &gt;= NextExecutionDateTime__c`. Change nothing else. `formulaTreatBlanksAs` stays `BlankAsZero`.
  - A probe (FormulaEval, 2026-11-25) evaluated `AND(true, NOW() >= null)` to `false`.
  - If the deployed field still yields `IsCandidate__c = true` for a null date, removing the branch alone does not meet the rule. Do NOT try another formula: raise a blocker `{ unit: Part 4, reason: null date still a candidate after ISNULL removal, options: … }`.
- Extend `apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls` (created in Part 2) with one test.
  - The selector call is `new JobSelectorImpl().getEligibleJobs(new List<Id>())`. Its public no-arg constructor is at apex-job/src/engine/adapter/JobSelectorImpl.cls:9.
  - Use one enabled description from `ApexJobTestFixture.aJobDescription().build()` (MaxChunkSize -1, base consumptions 0), so limits and description filters pass.
- Create `scripts/apex/backfill-next-execution.apex`. This is an operator script outside every packageDirectory. Mirror the header style of scripts/apex/restart-watcher.apex (purpose comment, `// Run with: sf apex run -f scripts/apex/backfill-next-execution.apex -o <org-alias>`, and "re-run until it reports 0"). Body:
  ```apex
  final List<JobRequest__c> requests = [
    SELECT Id, CreatedDate
    FROM JobRequest__c
    WHERE NextExecutionDateTime__c = NULL AND Status__c IN ('READY', 'FAILURE', 'KILLED')
    LIMIT 10000
  ];
  for (JobRequest__c request : requests) {
    request.NextExecutionDateTime__c = request.CreatedDate;
  }
  update requests;
  System.debug(LoggingLevel.INFO, 'Backfilled requests: ' + requests.size());
  ```
  NEVER run it against `dev-async-processor`: it writes the benchmark data. Review it by reading it.
- Docs, stating the rule: "a request runs when `NextExecutionDateTime__c <= now`; leave the field unset on insert to run as soon as possible; a `null` date (explicit on insert, or left by an update) means not scheduled, so a manual re-queue must set a date."
  - `DESIGN.md:130-145` "IsCandidate__c Formula Field": the line `AND (NextExecutionDateTime__c <= NOW() OR NextExecutionDateTime__c IS NULL)` becomes `AND NextExecutionDateTime__c <= NOW()`. Add the rule as a paragraph after the block.
  - `DESIGN.md:592-598` "Operator Scripts" table: add a row for `scripts/apex/backfill-next-execution.apex`: "Sets `NextExecutionDateTime__c = CreatedDate` on runnable (`READY`/`FAILURE`/`KILLED`) requests whose date is null, 10,000 per run. Run once after upgrading, and re-run until it reports 0." Run: `sf apex run -f scripts/apex/backfill-next-execution.apex -o <org-alias>`.
  - `README.md:170`, next to `scheduleAt(Datetime)`: add the rule (the null half; the unset half landed in Part 2).
  - `README.md:281`, the monitoring line: add "a `null` `NextExecutionDateTime__c` on a `READY`/`FAILURE`/`KILLED` row means not scheduled".
  - `README.md:328-332` "Candidate rules": add the bullet "`NextExecutionDateTime__c <= now` (a null date is not scheduled)."
  - `CONTRIBUTING.md`, the "Anonymous-Apex operator scripts" list (Useful Scripts): add the backfill script with its run command.

### TDD steps
1. RED `givenExplicitNullDate_whenInsert_thenRequestIsNotSelected`.
   - Arrange: one enabled description, a `READY`, enabled request with `NextExecutionDateTime__c = null` set explicitly, and a control request with the field unset.
   - Act: call the selector.
   - Assert:
     - the null row's re-queried date is still `null` (the default does not apply to an explicit null);
     - the selector result contains the control Id but not the null-row Id;
     - the re-queried `IsCandidate__c` is `false` for the null row and `true` for the control.
   - It fails because the formula's `ISNULL(NextExecutionDateTime__c)` branch makes the null row a candidate, so the selector returns it and `IsCandidate__c` is `true`.
2. GREEN: remove the `ISNULL` branch from the formula, then deploy.
3. GUARD: `JobSelectorImplTest` and `AsyncProcessorTest` stay green (every fixture request carries a past date).
4. REFACTOR: add the script and edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/objects/JobRequest__c/fields/IsCandidate__c.field-meta.xml apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls && sf code-analyzer run -t apex-job/test/integration/classes/JobRequestNextExecutionDateTimeTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobRequestNextExecutionDateTimeTest,JobSelectorImplTest,AsyncProcessorTest -w 20 -r human
```

### Commit
`fix(engine): treat a null NextExecutionDateTime__c as not scheduled`

## Part 5 — indexed date filter in the selector; monitor page without ALL ROWS

### Context
- Create `apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml` with exactly the content below. The field comes from the file name, and a `<field>` element is rejected. `allowNullValues` stays `true`.
  ```xml
  <?xml version="1.0" encoding="UTF-8"?>
  <CustomIndex xmlns="http://soap.sforce.com/2006/04/metadata">
      <allowNullValues>true</allowNullValues>
  </CustomIndex>
  ```
- Edit `apex-job/src/engine/adapter/JobSelectorImpl.cls`, `getEligibleJobs(final List<Id> jobDescriptionToExclude)` (`:18-153`).
  - Add `final Datetime now = Datetime.now();` next to the locals at `:21-24`.
  - In the WHERE clause (`:123-144`), add `AND NextExecutionDateTime__c <= :now` directly after `AND IsCandidate__c = TRUE` (`:125`).
  - It stays ONE query. Never add `OR NextExecutionDateTime__c = NULL`. Nothing else changes (SELECT list, ORDER BY, `LIMIT :ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE`).
- Edit `apex-job/src/monitor/classes/adapter/JobMonitorController.cls`, `getJobRequestPage(final Integer limitSize, final Integer offsetVal)` (`:11-44`).
  - Add `final Datetime now = Datetime.now();` and `WHERE IsCandidate__c = TRUE AND NextExecutionDateTime__c <= :now`.
  - Delete the `IsDeleted ASC,` ORDER BY key (`:34`) and the `ALL ROWS` clause (`:42`).
  - The method stays `@AuraEnabled public static` with an unchanged signature; requestTable.js consumes it.
- Create `apex-job/test/unit/classes/JobMonitorControllerTest.cls` (`@IsTest private class`) plus its cls-meta.xml companion. It does not exist today; Part 11 extends it.
  - Insert data with `ApexJobTestFixture.aJobDescription().build()` and `ApexJobTestFixture.aJobRequest().withJobDescription(d.Id).build()`. Fixture requests are `READY`, enabled, with a date 5 minutes in the past.
  - Static method under test, so there is no `sut` instance: call `JobMonitorController.getJobRequestPage(...)` inline in Act.
- Docs:
  - `DESIGN.md:312-327`, the selector WHERE block: add `AND NextExecutionDateTime__c <= :now` after `AND IsCandidate__c = TRUE`. Add one sentence: "`NextExecutionDateTime__c` carries a custom index (`allowNullValues` true); the explicit filter lets the optimizer lead with it, and the formula stays as the residual check."
  - `DESIGN.md:169`, the execution-flow line `JobSelectorImpl: 18-dimension WHERE + IsCandidate__c = TRUE`: add `+ NextExecutionDateTime__c <= now (indexed)`.
  - `DESIGN.md:144`, "The selector query only needs `WHERE IsCandidate__c = TRUE`.": align it with the indexed filter.
  - `DESIGN.md` directory tree: add `customindex/ (JobRequest__c.NextExecutionDateTime__c)` under `domain/`. Change `unit/ (16 test classes + helpers)` to `17`.

### TDD steps
1. RED `JobMonitorControllerTest.givenDeletedRunnableRequest_whenGetJobRequestPage_thenDeletedRequestIsNotReturned`.
   - Arrange: insert one enabled description and two runnable requests, then `delete` one.
   - Act: `getJobRequestPage(10, 0)`.
   - Assert: the result holds the kept Id and not the deleted Id.
   - Expected failure: `ALL ROWS` returns the soft-deleted row, whose formula still evaluates as a candidate.
   - If it passes at this step (the platform evaluates `IsCandidate__c` false on recycle-bin rows), record it as a GUARD in your hand-off and keep it. R-008 still removes `ALL ROWS` and the `IsDeleted` key.
2. GREEN: change the monitor query.
3. GUARD: add the selector filter and the custom index. `JobSelectorImplTest`, including `givenFutureJobs_whenGetJobs_thenExcludesFutureJobs` (`:200-212`), stays green. The filter cannot be observed behaviourally, because the formula already excludes the same rows. The orchestrator proves it with `query?explain=` (leading operation Index).
4. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/customindex/JobRequest__c.NextExecutionDateTime__c.indx-meta.xml apex-job/src/engine/adapter/JobSelectorImpl.cls apex-job/src/monitor/classes/adapter/JobMonitorController.cls apex-job/test/unit/classes/JobMonitorControllerTest.cls && sf code-analyzer run -t apex-job/src/engine/adapter/JobSelectorImpl.cls apex-job/src/monitor/classes/adapter/JobMonitorController.cls apex-job/test/unit/classes/JobMonitorControllerTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobMonitorControllerTest,JobSelectorImplTest,JobRequestNextExecutionDateTimeTest -w 20 -r human
```

### Commit
`perf(selector): filter on an indexed NextExecutionDateTime__c`

## Part 6 — spawner: once-per-transaction `wakeUp()` and a free-slot guard

### Context
- Public surface: `JobExecutorSpawner.wakeUp()` is PUBLIC, a new method on a public interface.
  - The only production implementer is apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls.
  - Test doubles are `Mock.forType(JobExecutorSpawner.class)` (ApexJobTestMock.cls, AsyncProcessorTest.cls `ApexJobFactoryForTest`). They absorb the new method without edits.
  - Downstream surface gates to pre-pay in this part: the `DESIGN.md` spawner and transaction-context sections (below). There are no barrels, registries or API reports in this repo.
  - The new members of `ApexJobTransactionContext` (`hasAttemptedWakeUp`, `markWakeUpAttempted()`) are public, consumed only by the spawner.
- Edit `apex-job/src/engine/service/ApexJobTransactionContext.cls`. Current shape: `public virtual class`, static `instance`, `hasExecutedJobs { get; private set; }`, private constructor sets false, `markExecutedJobs()`, `@TestVisible private static void reset()`. Add:
  ```apex
  public Boolean hasAttemptedWakeUp { get; private set; }   // initialised false in the private constructor
  public void markWakeUpAttempted() { this.hasAttemptedWakeUp = true; }
  ```
- Edit `apex-job/src/engine/adapter/JobExecutorSpawner.cls`. It is currently `Id enqueue(Integer delayInMinutes); Id enqueue();`. Add `void wakeUp();`.
- Edit `apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls`. It has `enqueue(Integer)` at `:21-36` and `cannotEnqueue()` at `:38-42`. Target:
  ```apex
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
    return System.isQueueable() || // Finalizer is not queueable ;)
      this.hasNoQueueableSlotLeft() ||
      this.factory.getConfigService().isSystemEnabled() == false ||
      this.factory.getExecutorService().isRunning(null) == true;
  }

  private Boolean hasNoQueueableSlotLeft() {
    return Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs();
  }
  ```
  The slot check sits before the SOQL in `isRunning`, so it protects every enqueue: the trigger, the finalizer, the watcher and `restartEngine`. The once-per-transaction guard lives only in `wakeUp()`. Do NOT put it in `enqueue`.
- Edit `apex-job/test/unit/classes/ApexJobTransactionContextTest.cls`, which has 5 tests modelled with `ApexJobTransactionContext.reset()` in Arrange.
- Edit `apex-job/test/unit/classes/JobExecutorQueueableSpawnerTest.cls`. Its pattern (`:4-20`): `ApexJobTestMock mocks = new ApexJobTestMock(); mocks.isSystemEnabledSpy.returns(true); mocks.isRunningSpy.returns(...); JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);`. Add a private inner `NoOpQueueable implements Queueable` with an empty `execute`.
- Docs:
  - `DESIGN.md:294-296` "ApexJobTransactionContext": add "and a `hasAttemptedWakeUp` boolean set by `JobExecutorQueueableSpawner.wakeUp()` so the insert trigger attempts at most one wake-up per transaction".
  - `DESIGN.md:337-339` "JobExecutorQueueableSpawner": add "Every enqueue first checks for a free queueable slot (`Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()`) and returns `null` otherwise, ahead of the `isRunning` query. `wakeUp()` is the trigger's entry point: once per transaction, skipped in Batch and `@future` contexts."

### TDD steps
1. RED (one cycle, three tests) in `ApexJobTransactionContextTest`:
   - `givenNewTransaction_whenHasAttemptedWakeUp_thenReturnsFalse`
   - `givenTransactionContext_whenMarkWakeUpAttempted_thenFlagIsSet`
   - `givenWakeUpAttempted_whenReset_thenNewInstanceHasFlagCleared`
   - Failure: the deploy fails to compile, because `hasAttemptedWakeUp` and `markWakeUpAttempted` do not exist.
2. GREEN: add the property and the command to `ApexJobTransactionContext`.
3. RED `JobExecutorQueueableSpawnerTest.givenWakeUpAlreadyAttempted_whenWakeUp_thenIsRunningNotQueried`.
   - Arrange: `ApexJobTransactionContext.reset()`, `isSystemEnabledSpy.returns(true)`, and `isRunningSpy.returns(true)` so no real enqueue happens.
   - Act: call `sut.wakeUp()` twice.
   - Assert: `Expect.that(mocks.isRunningSpy).hasBeenCalledTimes(1)`.
   - Failure: compile error, because `wakeUp()` is not on `JobExecutorSpawner`/`JobExecutorQueueableSpawner`.
4. GREEN: add `wakeUp()` to the interface and the implementation.
5. RED `givenNoQueueableSlotLeft_whenEnqueue_thenReturnsNullWithoutQuery`.
   - Arrange: `isSystemEnabledSpy.returns(true)`, `isRunningSpy.returns(false)`, then inside `Test.startTest()` loop `Limits.getLimitQueueableJobs()` times `System.enqueueJob(new NoOpQueueable())`.
   - Act: `final Id result = sut.enqueue(0);`, then `Test.stopTest()`.
   - Assert: `Assert.isNull(result)` and `Expect.that(mocks.isRunningSpy).hasNotBeenCalled()`.
   - Failure: `cannotEnqueue` queries `isRunning` and then `System.enqueueJob` throws the uncatchable `LimitException: Too many queueable jobs added to the queue: 51`.
6. GREEN: `hasNoQueueableSlotLeft()` in `cannotEnqueue`.
7. GUARD: the existing spawner tests (`:4-130`) stay green.
8. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/service/ApexJobTransactionContext.cls apex-job/src/engine/adapter/JobExecutorSpawner.cls apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls apex-job/test/unit/classes/ApexJobTransactionContextTest.cls apex-job/test/unit/classes/JobExecutorQueueableSpawnerTest.cls && sf code-analyzer run -t apex-job/src/engine/service/ApexJobTransactionContext.cls apex-job/src/engine/adapter/JobExecutorSpawner.cls apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls apex-job/test/unit/classes/ApexJobTransactionContextTest.cls apex-job/test/unit/classes/JobExecutorQueueableSpawnerTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t ApexJobTransactionContextTest,JobExecutorQueueableSpawnerTest,AsyncApexJobExecutorTest,ApexJobWatcherTest -w 20 -r human
```

### Commit
`perf(spawner): add a once-per-transaction wake-up and a free queueable slot guard`

## Part 7 — insert trigger wakes the executor once per transaction

### Context
- Edit `apex-job/src/engine/domain/triggers/JobRequestAfterInsert.trigger`. Today it reads `if(!FeatureManagement.checkPermission('Bypass_JobRequest_Trigger')) { new ApexJobFactoryImpl().getSpawner().enqueue(0); }`. The call becomes `new ApexJobFactoryImpl().getSpawner().wakeUp();`, and the bypass check stays as is (one-line delegation). The file is not Prettier-clean: run `npx prettier --write` on it.
- Create `apex-job/test/integration/classes/JobRequestTriggerTest.cls` (`@IsTest private class`) plus its cls-meta.xml companion.
  - Every test inserts `new ApexJobConfig__c(Enabled__c = true)` and a DISABLED description (`ApexJobTestFixture.aJobDescription().build()` with `Enabled__c = false`, then insert) BEFORE `Test.startTest()`, so the executor that runs at `stopTest` finds no work.
  - Requests are `new JobRequest__c(JobDescription__c = d.Id, Status__c = ApexJobStatus.READY.name(), Enabled__c = true)`.
  - Runs as the default test user, which has no bypass.
  - Named constants: `SINGLE_INSERT_COUNT = 40`, `OVER_LIMIT_INSERT_COUNT = 120`, `BULK_INSERT_SIZE = 10000`, `EXPECTED_WAKE_UP_COUNT = 1`.
  - Deltas: capture `Limits.getQueries()` and `Limits.getQueueableJobs()` right after `startTest()`, and read them again before `stopTest()`.
  - The executor `AsyncApexJob` rows query: `[SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'AsyncApexJobExecutor']`.
  - Inner helpers in the test class:
    - `RequestInsertingBatch implements Database.Batchable<Integer>`: its constructor takes the description Id, `start` returns `new List<Integer>{ 1 }`, and `execute` does two single-row inserts;
    - `@future static void insertTwoRequests(final Id descriptionId)`, which does two single-row inserts.
- Docs:
  - `DESIGN.md:150-156`, the execution flow head `External trigger ... → JobExecutorQueueableSpawner.enqueue()`: show the trigger path as `JobRequestAfterInsert → JobExecutorQueueableSpawner.wakeUp() (once per transaction; skipped in Batch/@future) → enqueue(0)`.
  - `README.md:338-342`, the runtime diagram `new JobRequest__c ─(trigger)─┐`: annotate it with `wake-up once per transaction`.
  - `README.md:282`, the bypass line: add "The trigger attempts at most one wake-up per transaction and none from Batch or `@future`."
  - `DESIGN.md` directory tree `integration/`: change `(4 test classes)` to `(5 test classes)`.
  - Leave `DESIGN.md:609` and `:701-703` unchanged (the design pins them).
- CPU is not asserted. The orchestrator reports the CPU deltas.

### TDD steps
All five tests are RED against the trigger as it stands after Part 6, which still calls `enqueue(0)` on every 200-row invocation:
1. RED `givenEngineIdle_when40SingleRowInserts_thenOneQueryAndOneQueueable`: asserts query delta 1 and queueable delta 1. It fails because each insert runs the `isRunning` SOQL and enqueues: 40 / 40.
2. RED `givenEngineIdle_when120SingleRowInserts_thenNoQueueableLimitException`: asserts the queueable delta is 1. It fails at 50, because the Part 6 slot guard stops the LimitException but every insert until the limit still enqueues.
3. RED `givenEngineIdle_whenOneInsertOf10000Rows_thenOneQueryAndOneQueueable`: one `insert` of a 10,000-row list. The description is inserted before `startTest` so the DML fits the 10,000-row budget. It fails at 50 / 50 (one per 200-row trigger chunk).
4. RED `givenBatchExecute_whenInsertTwoRequests_thenScopeCompletes`: `Database.executeBatch(new RequestInsertingBatch(d.Id))` inside `startTest` and `stopTest`. Asserts 2 requests persisted, `NumberOfErrors == 0` on the batch `AsyncApexJob`, and 0 executor `AsyncApexJob` rows. It fails because the first insert still enqueues an executor from batch context (1 row).
5. RED `givenFutureMethod_whenInsertTwoRequests_thenNoWakeUp`: `insertTwoRequests(d.Id)` inside `startTest` and `stopTest`. Asserts 2 requests persisted and 0 executor `AsyncApexJob` rows. It fails with 1 executor row, enqueued from `@future`.
6. GREEN: the trigger calls `wakeUp()`. All five are green: 1 / 1 for 1-3, and no enqueue in Batch or `@future`.
   - Contingency for 4 and 5: if either already passes at its RED step, report it as a GUARD in your hand-off and keep it. The platform may show no `AsyncApexJob` row for a queueable enqueued from an async context in a test. Both tests still pin the measured pre-fix failure modes (`queue: 2` from Batch, the second enqueue from `@future`).
7. GUARD: `AsyncProcessorTest`, `ApexJobManagerTest` and `JobRequestNextExecutionDateTimeTest` stay green.
8. REFACTOR: shared `private static Id insertDisabledDescriptionWithEngineEnabled()` arrange helper. Edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/triggers/JobRequestAfterInsert.trigger apex-job/test/integration/classes/JobRequestTriggerTest.cls && sf code-analyzer run -t apex-job/test/integration/classes/JobRequestTriggerTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobRequestTriggerTest,AsyncProcessorTest,ApexJobManagerTest,JobRequestNextExecutionDateTimeTest -w 20 -r human
```

### Commit
`perf(trigger): wake the executor once per transaction and never from batch or future`

## Part 8 — `JobIds__c` keeps the last 20 ids

### Context
- Edit `apex-job/src/engine/adapter/JobRepositoryImpl.cls`.
  - `recordJobExecution` calls `JobRepositoryImpl.buildJobIds(job.JobIds__c, asyncJobId)` at `:79`.
  - The constants and the method are at `:96-112`: `JOBIDS_SEP = ';'`, `MAX_LONG_TEXT_LENGTH = 131072` (used only by the trim loop), `ID_15_LENGTH = 15`, and `private static String buildJobIds(final String jobIdValues, final String asyncJobId)` with the `while` trim loop.
  - Target: add `private static final Integer MAX_TRACKED_JOB_IDS = 20;`. Delete `MAX_LONG_TEXT_LENGTH` and the `while` loop, which become dead code.
    ```apex
    private static String buildJobIds(final String jobIdValues, final String asyncJobId) {
      final List<String> jobIds = String.isNotBlank(jobIdValues) ? jobIdValues.split(JOBIDS_SEP) : new List<String>();
      jobIds.add(asyncJobId.left(ID_15_LENGTH));
      return String.join(keepLast(jobIds, MAX_TRACKED_JOB_IDS), JOBIDS_SEP);
    }

    private static List<String> keepLast(final List<String> values, final Integer count) {
      final List<String> kept = new List<String>();
      for (Integer i = Math.max(0, values.size() - count); i < values.size(); ++i) {
        kept.add(values[i]);
      }
      return kept;
    }
    ```
- Edit `apex-job/src/engine/domain/objects/JobRequest__c/fields/JobIds__c.field-meta.xml`. The `<description>` becomes `Last 20 AsyncApexJob ids (15 characters) separated by semi-colon`. Keep `<length>131072</length>`. The file is not Prettier-clean: run `npx prettier --write`.
- Edit `apex-job/test/unit/classes/JobRepositoryImplTest.cls`. Model on `givenRecordJobExecution_whenCalledWithAsyncJobId_thenPopulateJobIds` (`:295-331`): fixture description and request, `new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(...), mockResult)`, `JobRepository sut = new JobRepositoryImpl();`, the private `TestFinalizerContext(asyncJobId)`, and fake ids from `TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)`.
- Docs: `DESIGN.md:335` becomes "`JobIds__c` accumulation: appends the 15-char async job ID to a semicolon-delimited string and keeps only the last 20 ids." Existing rows that hold more ids are trimmed on their next recording.

### TDD steps
1. RED `givenJobIdsAtCapacity_whenRecordJobExecution_thenOldestDroppedAndNewestAppended`.
   - Arrange: a request whose `JobIds__c` is 20 fake 15-char ids joined with `;`.
   - Act: record once with a new async id.
   - Assert, after splitting the re-queried value: size is 20, the first original id is absent, and the last element is the new 15-char id.
   - It fails because the current code only trims beyond 131,072 characters, so 21 ids remain.
2. GREEN: `MAX_TRACKED_JOB_IDS` and `keepLast`.
3. GUARD `givenRecordJobExecution_whenCalledWithAsyncJobId_thenPopulateJobIds`: it stays green (below capacity: 1 id, then 2 ids appended).
4. REFACTOR: delete `MAX_LONG_TEXT_LENGTH` and the loop, edit the description and the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/adapter/JobRepositoryImpl.cls apex-job/src/engine/domain/objects/JobRequest__c/fields/JobIds__c.field-meta.xml apex-job/test/unit/classes/JobRepositoryImplTest.cls && sf code-analyzer run -t apex-job/src/engine/adapter/JobRepositoryImpl.cls apex-job/test/unit/classes/JobRepositoryImplTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobRepositoryImplTest,AsyncProcessorTest -w 20 -r human
```

### Commit
`perf(repository): keep only the last 20 ids in JobIds__c`

## Part 9 — per-dimension noise floors on `ConsumptionModel`

### Context
- Public surface:
  - `ConsumptionModel.noiseFloor` is PUBLIC (read-only property). Its consumer is `AdaptiveConsumptionLearner` (Part 10).
  - `LimitsUsage.CPU_TIME_DIMENSION`, `HEAP_SIZE_DIMENSION` and `CALLOUT_TIME_DIMENSION` go from `private static final` to `public static final`. They are consumed by `ConsumptionModel` and `ConsumptionModelTest`.
  - Surface gate: the `DESIGN.md` extensibility checklist (below).
- Edit `apex-job/src/engine/domain/classes/LimitsUsage.cls:3-6`. Change the three constants to `public`; the other 15 stay private.
- Edit `apex-job/src/engine/domain/classes/ConsumptionModel.cls`. Today it holds `dimension`/`base`/`perItem`/`safety` with `{ get; private set; }`, a public 4-arg constructor (under the existing `@SuppressWarnings('PMD.ExcessiveParameterList')`), and `asList()` that lazily fills the static `MODELS` list. Add:
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
  public Decimal noiseFloor { get; private set; }
  ```
  In the constructor: `this.noiseFloor = NOISE_FLOOR_BY_DIMENSION.get(dimension) ?? COUNTER_NOISE_FLOOR;`. The constructor signature does not change.
  - Static initialisation order: declare `NOISE_FLOOR_BY_DIMENSION` before `MODELS` or anything that constructs models. `asList()` is lazy, so the map is always initialised before the first construction.
- Create `apex-job/test/unit/classes/ConsumptionModelTest.cls` (`@IsTest private class`) plus its cls-meta.xml companion.
  - `ConsumptionModel.asList()` is a stateless static utility: keep the call inline in Act, with no `sut`.
  - Iterate the contract and do not assert an exact set: for each model, the expected floor is 5 for `cpuTime`, 4096 for `heapSize`, 5 for `calloutTime` and 1 for every other dimension.
  - Use test-local named constants for the expected values.
- Docs:
  - `DESIGN.md:640-648` "Adding a New Governor Limit Dimension": add step "5. If the dimension is measured in time or bytes rather than counted, add its noise floor to `ConsumptionModel.NOISE_FLOOR_BY_DIMENSION`; counters default to 1." Adjust the "Zero changes needed in ... `ConsumptionModel`" sentence to "except a noise floor for non-counter dimensions".
  - `DESIGN.md` directory tree `unit/`: change `(17 test classes + helpers)` to `(18 ...)`.

### TDD steps
1. RED `ConsumptionModelTest.givenEveryDimension_whenAsList_thenNoiseFloorMatchesItsUnit`. It fails to compile: `noiseFloor` does not exist on `ConsumptionModel`, and the `LimitsUsage` dimension constants are private.
2. GREEN: make the constants public, add the floor constants, the map and the property.
3. GUARD: `AdaptiveConsumptionLearnerTest`, `AdaptiveChunkCalculatorTest` and `LimitServiceImplTest` stay green, because nothing reads the floor yet.
4. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/classes/ConsumptionModel.cls apex-job/src/engine/domain/classes/LimitsUsage.cls apex-job/test/unit/classes/ConsumptionModelTest.cls && sf code-analyzer run -t apex-job/src/engine/domain/classes/ConsumptionModel.cls apex-job/src/engine/domain/classes/LimitsUsage.cls apex-job/test/unit/classes/ConsumptionModelTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t ConsumptionModelTest,AdaptiveConsumptionLearnerTest,AdaptiveChunkCalculatorTest,LimitServiceImplTest -w 20 -r human
```

### Commit
`feat(learner): define per-dimension noise floors on the consumption model`

## Part 10 — one significance predicate for both learner branches

### Context
- Edit `apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls`.
  - Base branch: `adjustBaseConsumptionModel(usage, model, inCooldown)` (`:56-69`), with the variation test at `:62-65`: `Math.abs((usage - currentBase) / currentBase) > this.job.VariationResetThreshold__c → recordVariationHit()`.
  - Per-item branch: `adjustPerItemConsumptionModel(usage, model, chunkSize, inCooldown)` (`:71-87`), with the variation test at `:80-83` on `newPerItem` against `currentPerItem`.
  - Both return early when the learned value is `<= UNKNOWN_*` (0), so `expected > 0` inside the predicate.
  - Add the single predicate:
    ```apex
    @TestVisible
    private Boolean isSignificantVariation(final Decimal observed, final Decimal expected, final Decimal noiseFloor) {
      final Decimal deviation = Math.abs(observed - expected);
      return deviation > noiseFloor && deviation / expected > this.job.VariationResetThreshold__c;
    }
    ```
  - Callers:
    - Base: `if (this.isSignificantVariation(usage, currentBase, model.noiseFloor)) { return this.recordVariationHit(); }`.
    - Per-item: `final Integer itemsBeyondFirst = chunkSize - 1;` then `this.isSignificantVariation(newPerItem * itemsBeyondFirst, currentPerItem * itemsBeyondFirst, model.noiseFloor)`. Both deviations are in chunk-total units. Never compare the per-item deviation itself to the floor.
  - `model.noiseFloor` comes from Part 9.
- Edit `apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls`.
  - Builders: `ApexJobTestFixture.aJobDescription().withCpuTimeConsumption(Integer).withCpuTimePerItemConsumption(Decimal).withSuccessStreak(Integer).withVariationResetThreshold(Decimal).withConsecutiveVariationCount(Integer).build()` and `ApexJobTestFixture.aLimitsUsage().withCpuTime(Integer).build()`.
  - Fixture defaults: threshold 0.3, reset count 3, kill cooldown 3, success streak 0, which means cooldown and `Math.max` assimilation. Use `withSuccessStreak(3)` to get the EWMA blend.
  - Existing variation tests (`:43`, `:198`, `:219`) use deviations of 100 ms or more, so they stay green.
  - Predicate tests call `new AdaptiveConsumptionLearner(job).isSignificantVariation(observed, expected, floor)` directly with test-local constants (floor 5, threshold 0.3).
- Docs:
  - `DESIGN.md:448-460` "On Success", the variation bullet: "If the relative variation is above `VariationResetThreshold__c` **and** the absolute chunk-total deviation is above the dimension's noise floor (`ConsumptionModel.noiseFloor`: 5 ms CPU, 4,096 B heap, 5 ms callout time, 1 for counters) → not assimilated...". Add the per-item note that the deviation is `|newPerItem − currentPerItem| × (chunkSize − 1)`.
  - `DESIGN.md:677-679` "Variation Reset Threshold with N-of-N Counter": state the conjunction and why (readings at the measurement floor of cheap jobs, e.g. 1 ms of CPU over a 50-item chunk, no longer count as variation).
  - `README.md:392`, the learner bullet: add "and only when the absolute deviation of the chunk total also exceeds the dimension's noise floor".

### TDD steps
1. RED (one cycle, four tests). Each fails to compile, because `isSignificantVariation` does not exist:
   - `givenDeviationBelowFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenFalse`: observed 2, expected 1, floor 5.
   - `givenDeviationAboveFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenTrue`: observed 200, expected 100.
   - `givenDeviationAboveFloorAndRatioBelowThreshold_whenIsSignificantVariation_thenFalse`: observed 110, expected 100.
   - `givenDeviationEqualToFloor_whenIsSignificantVariation_thenFalse`: observed 10, expected 5. Deviation 5 equals the floor; this pins the strict `>`.
2. GREEN: add the predicate (not yet wired).
3. RED `givenPerItemAtResolutionFloor_whenAdjustFromSuccess_thenCounterUnchangedAndBlended`.
   - Job: base 10, `CpuTimePerItemConsumption__c = 0.0204`, success streak 3. Usage `cpuTime = 12`, chunk 50.
   - This gives newPerItem = 2/49 ≈ 0.0408 (about +100 % relative) and a chunk-total deviation of about 1 ms, below the 5 ms floor.
   - Assert `ConsecutiveVariationCount__c == 0` and `CpuTimePerItemConsumption__c > 0.0204` (blended).
   - It fails because today's relative-only test counts the variation: the counter becomes 1 and the value is unchanged.
4. GREEN: wire the predicate into the per-item branch.
5. RED `givenBaseAtResolutionFloor_whenAdjustFromSuccess_thenCounterUnchanged`.
   - Job: base 1, success streak 3. Usage `cpuTime = 2`, chunk 1.
   - Assert the counter is 0 and the base is blended (`> 1`).
   - It fails because a 100 % relative variation counts today.
6. GREEN: wire the predicate into the base branch.
7. GUARD: all existing learner tests stay green.
8. REFACTOR: remove the now-unused inline `variation` locals and edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls && sf code-analyzer run -t apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t AdaptiveConsumptionLearnerTest,ConsumptionModelTest,JobExecutedTest,AsyncProcessorTest -w 20 -r human
```

### Commit
`fix(learner): count a variation only above the dimension noise floor`

## Part 11 — monitor Apex: one row per group, statistics from descriptions, one engine-status call

### Context
- Public surface:
  - `JobMonitorController.getEngineStatus()` and `JobMonitorController.EngineStatus` are PUBLIC (`@AuraEnabled`). Their consumer is engineControls.js (Part 13).
  - Surface gates to pre-pay here: the `DESIGN.md` "Apex Controller" section and `README.md` "Controls (calls `JobMonitorController`)".
  - `isEnabled`, `getExecutorCount` and `isRecoveryBatchAlive` KEEP `@AuraEnabled public` in this part, because engineControls.js still imports them and the deploy would fail otherwise. Part 13 makes them private.
- Edit `apex-job/src/monitor/classes/adapter/JobMonitorController.cls` (`with sharing`, class-level `@SuppressWarnings('PMD.ApexCRUDViolation')`).
  - `getStatusByProcessor()` (`:46-71`): the SOQL becomes `SELECT COUNT(Id) nbRows, Status__c status, JobDescription__c processorId FROM JobRequest__c GROUP BY Status__c, JobDescription__c ORDER BY Status__c, JobDescription__c`. Drop every MAX, SUM and FORMAT aggregate. Keep the mapping loop and the existing method-level `@SuppressWarnings('PMD.AvoidNonRestrictiveQueries ')`, which is existing code.
  - `getJobDescriptionInfos(final List<Id> jobDescriptionIds)` (`:73-77`): SELECT `Id, ProcessorName__c, MaxExecutionsPerMinute__c, ExecutionsInCurrentWindow__c, CurrentWindowStart__c, MaxChunkSize__c, SmallestFailingChunk__c, SuccessStreak__c, ConsecutiveFailures__c, LastExecutionDateTime__c`. Keep the "Not cacheable" comment.
  - Add:
    ```apex
    @AuraEnabled
    public static EngineStatus getEngineStatus() {
      return new EngineStatus(isEnabled(), getExecutorCount(), isRecoveryBatchAlive());
    }

    public class EngineStatus {
      @AuraEnabled public Boolean enabled { get; private set; }
      @AuraEnabled public Integer executorCount { get; private set; }
      @AuraEnabled public Boolean watcherScheduled { get; private set; }
      // constructor (Boolean, Integer, Boolean) assigns the three
    }
    ```
    The constructor's two Booleans are values, not behaviour switches.
- Edit `apex-job/test/unit/classes/JobMonitorControllerTest.cls` (created in Part 5). Data comes from `ApexJobTestFixture.aJobDescription()` / `aJobRequest()` with `.withJobDescription(id)` and the status builders (`.failure()`, the default READY). The methods are static, so call them inline.
- Docs:
  - `DESIGN.md:586-590` "Apex Controller": list `getEngineStatus()`, which returns `EngineStatus { enabled, executorCount, watcherScheduled }` in one round trip. Note that `getStatusByProcessor` counts rows per group only (one query row per group), while per-processor statistics come from `getJobDescriptionInfos`.
  - `README.md:306-310` "Controls": add "Engine status: one `getEngineStatus()` call (enabled flag, executor count, watcher scheduled)".
- Transient state: until Part 15, statusByProcessorTable shows blank statistic columns, because it still reads the removed aggregate keys. That is acceptable within the branch.

### TDD steps
1. RED `givenRequestsAcrossTwoDescriptionsAndTwoStatuses_whenGetStatusByProcessor_thenQueryRowsEqualGroupCount`.
   - Arrange (before `startTest`): 2 descriptions × 2 statuses (READY, FAILURE) × 5 requests = 20 rows in 4 groups.
   - Act: inside `startTest`, call the method and read `Limits.getQueryRows()` before `stopTest`.
   - Assert: query rows equal 4, the result has 4 entries, and each `nbRows` is 5. Use named constants.
   - It fails because the MAX/SUM aggregates count every source row toward query rows (20).
2. GREEN: slim the aggregate query.
3. RED `givenDescriptions_whenGetJobDescriptionInfos_thenReturnsStatisticsFields`: a description with `MaxChunkSize__c`, `SmallestFailingChunk__c`, `SuccessStreak__c`, `ConsecutiveFailures__c` and `LastExecutionDateTime__c` set. Assert the returned row exposes each value. It fails with `SObjectException` (field not queried).
4. GREEN: widen the SELECT.
5. RED `givenEngineState_whenGetEngineStatus_thenReturnsThreeValues`. Arrange `insert new ApexJobConfig__c(Enabled__c = true)`. Assert `enabled == true`, `executorCount == 0`, `watcherScheduled == false`. It fails to compile, because `getEngineStatus` and `EngineStatus` do not exist.
6. GREEN: add `getEngineStatus` and `EngineStatus`.
7. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/monitor/classes/adapter/JobMonitorController.cls apex-job/test/unit/classes/JobMonitorControllerTest.cls && sf code-analyzer run -t apex-job/src/monitor/classes/adapter/JobMonitorController.cls apex-job/test/unit/classes/JobMonitorControllerTest.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobMonitorControllerTest -w 20 -r human
```

### Commit
`perf(monitor): count status groups without per-row aggregates and serve engine status in one call`

## Part 12 — LWC jest tooling and test-org setup docs

### Context
Test-infra and docs only, with no `apex-job/src` delta, so this part legitimately stands alone.
- Install with `npm install --save-dev --ignore-scripts @salesforce/sfdx-lwc-jest@^7.9.0`. `--ignore-scripts` is mandatory: the repo's `postinstall` globally installs the Salesforce CLI and a plugin. This edits `package.json` and `package-lock.json`.
- Create `jest.config.js` at the repo root:
  ```js
  const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

  module.exports = { ...jestConfig };
  ```
  Write it in Prettier form: double quotes are Prettier's default and `.prettierrc` does not override `singleQuote`.
- Edit `package.json`:
  - `scripts` gains `"test:lwc": "wireit"`.
  - `wireit` gains:
    ```json
    "test:lwc": {
      "command": "sfdx-lwc-jest",
      "files": ["apex-job/src/monitor/lwc/**", "jest.config.js", "package.json"],
      "output": []
    }
    ```
    It does NOT depend on `build`, because it needs no org.
  - The `test` wireit entry's `dependencies` becomes `["test:unit", "test:integration", "test:lwc"]`.
  - Keep the file's existing tab indentation; `npm install` preserves it. package.json is not Prettier-clean on main (tabs against `tabWidth: 2`), and the phase's `npm run prettier` formats only `.cls`. Do not reformat it, and leave it out of the Prettier gate.
- Forwarding arguments: sfdx-lwc-jest forwards yargs positionals (`argv._`) to jest, so `npm run test:lwc -- engineControls` filters by path pattern. Verify the exact form once with `npm run test:lwc -- --passWithNoTests`. If wireit or sfdx-lwc-jest rejects it, use `npx sfdx-lwc-jest -- --passWithNoTests` for this part's gate and record the working forwarding form in CONTRIBUTING.md.
- No `.forceignore` change: it already ignores `**/__tests__/**`, so the suites never deploy. `.gitignore` already ignores `coverage/`.
- Edit `CONTRIBUTING.md`.
  - "Development Setup": insert a step between "3. Create or select a dev org" and "4. Deploy": "Deploy Apex Mockery v2.3.0 from source before deploying `apex-job/test`", with commands:
    - `git clone --depth 1 --branch v2.3.0 https://github.com/salesforce/apex-mockery.git <apex-mockery-dir>`
    - `sf project deploy start -d <apex-mockery-dir>/force-app/src -o <org-alias>`

    `force-app/src` is the package directory in that tag's `sfdx-project.json`. Note that the scratch definition sets `"language": "en_US"`, because some tests assert English platform messages.
  - "Useful Scripts": add `LWC tests: npm run test:lwc (coverage: npm run test:lwc -- --coverage)` with the verified forwarding form.
  - Renumber the following steps.

### TDD steps
- GUARD: `npm run test:lwc -- --passWithNoTests` exits 0 with "No tests found". This proves the wiring before any suite exists.
- GREEN: add the dependency, the config, the scripts and the docs.
- REFACTOR: none.

### Gate
```bash
npx prettier --check jest.config.js && npm run test:lwc -- --passWithNoTests
```

### Commit
`test(lwc): set up sfdx-lwc-jest and document the test org prerequisites`

## Part 13 — engineControls polls one engine-status call every 5 s

### Context
- Edit `apex-job/src/monitor/lwc/engineControls/engineControls.js`.
  - Today: imports of isEnabled, getExecutorCount and isRecoveryBatchAlive from @salesforce/apex/JobMonitorController.*, and `connectedCallback` runs `setInterval` every 500 ms with 3 calls (`:30-36`). Keep the pause/resume/restart handlers unchanged.
  - Target: import getEngineStatus. Add `const POLL_INTERVAL_MS = 5000;` at module level.
    ```js
    connectedCallback() { this.stopped = false; this.poll(); }
    disconnectedCallback() { this.stopped = true; clearTimeout(this.pollTimer); }
    async poll() {
      try { await this.refresh(); }
      finally { if (!this.stopped) { this.pollTimer = setTimeout(() => this.poll(), POLL_INTERVAL_MS); } }
    }
    async refresh() {
      const status = await getEngineStatus();
      this.enabled = status.enabled;
      this.executorCountValue = status.executorCount;
      this.recoveryBatchStatusValue = status.watcherScheduled;
    }
    ```
    Remove the `setInterval` and the three `poll*` methods. No `catch` in `poll` (see DC-A).
  - The file is not Prettier-clean (see DC-B).
- Create `apex-job/src/monitor/lwc/engineControls/__tests__/engineControls.test.js`.
  - Mock getEngineStatus with `jest.mock("@salesforce/apex/JobMonitorController.getEngineStatus", () => ({ default: jest.fn() }), { virtual: true })`. Mock pauseEngine, resumeEngine and restartEngine the same way.
  - Mock the custom permission with `jest.mock("@salesforce/customPermission/Manage_Async_Job_Engine", () => ({ default: true }), { virtual: true })`.
  - Mount: `createElement("c-engine-controls", { is: EngineControls })` from `lwc`, then `document.body.appendChild`.
  - `beforeEach`: `jest.useFakeTimers()` and `getEngineStatus.mockResolvedValue({ enabled: true, executorCount: 1, watcherScheduled: true })`.
  - `afterEach`: remove the DOM children, `jest.clearAllMocks()`, `jest.useRealTimers()`.
  - Advance time with `await jest.advanceTimersByTimeAsync(ms)`, which flushes promises between timers (Jest 29.5+).
  - For the in-flight case, use a deferred promise (`let resolveCall; getEngineStatus.mockReturnValue(new Promise((r) => { resolveCall = r; }))`).
- Edit `apex-job/src/monitor/classes/adapter/JobMonitorController.cls`: `isEnabled`, `getExecutorCount` and `isRecoveryBatchAlive` lose `@AuraEnabled` and become `private static`. engineControls.js is their only consumer (checked by grep), and it no longer imports them.
- Docs: `DESIGN.md` "Monitoring UI".
  - The box diagram line `500ms polling` (around `:566`) becomes `5s polling`.
  - The `engineControls` paragraph (`:578`) becomes "Polls every 5 s with one `getEngineStatus()` call (enabled flag, executor count, watcher status); the timer is cleared on disconnect and re-armed after each call, so a failed call does not stop polling."

### TDD steps
1. Run `npx prettier --write` on engineControls.js and commit it as `style(monitor): format engineControls` (DC-B).
2. RED `givenConnected_whenIntervalElapses_thenOneApexCallPerInterval`: after mount and `advanceTimersByTimeAsync(0)`, getEngineStatus has 1 call; after `advanceTimersByTimeAsync(5000)`, 2. It fails because getEngineStatus is never imported or called; the component calls the three old methods every 500 ms.
3. GREEN: the poll loop with getEngineStatus.
4. RED `givenDisconnected_whenIntervalElapses_thenNoFurtherCall`: mount, flush, remove the element, advance 10,000 ms, and expect 1 call. It fails because no `disconnectedCallback` clears the timer, so calls continue.
5. RED `givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed`: mount with a deferred call, remove the element, resolve, flush, and expect `jest.getTimerCount() === 0` and 1 call. It fails because the `finally` re-arms the timer when no `stopped` flag exists.
6. GREEN: `disconnectedCallback` plus the `stopped` flag.
7. GUARD `givenRejectedCall_whenIntervalElapses_thenPollingResumes`: the first call is rejected (`mockRejectedValueOnce`), advance 5000 ms, expect 2 calls. It passes after step 6 because the `finally` re-arms. Apply DC-A for the unhandled rejection.
8. REFACTOR: make the controller methods private and edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/monitor/lwc/engineControls/engineControls.js apex-job/src/monitor/lwc/engineControls/__tests__/engineControls.test.js apex-job/src/monitor/classes/adapter/JobMonitorController.cls && npm run test:lwc -- engineControls && sf code-analyzer run -t apex-job/src/monitor/classes/adapter/JobMonitorController.cls && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30 && sf apex test run -o dev-async-processor -t JobMonitorControllerTest -w 20 -r human
```

### Commit
`perf(monitor): poll engine status once every 5 s and stop on disconnect`

## Part 14 — requestTable stops on disconnect and survives a failed call

### Context
- Edit `apex-job/src/monitor/lwc/requestTable/requestTable.js`.
  - Today: `connectedCallback() { this.refreshData(); }` and `async refreshData()` (`:40-53`), which awaits `getJobRequestPage({ limitSize: this.pageSize, offsetVal: 0 })`, replaces rows when `arePagesDifferent`, then calls `setTimeout(() => this.refreshData(), 2000)` after the await. A rejection therefore ends the chain, and nothing clears the timer.
  - Target: `const POLL_INTERVAL_MS = 2000;` at module level. `connectedCallback` and `disconnectedCallback` follow the same shape as Part 13 (`stopped` flag, `pollTimer`, `poll()` with `try { await this.refresh(); } finally { re-arm unless stopped }`).
  - `refreshData` is renamed `refresh()` and keeps its body minus the trailing `setTimeout`.
  - Keep `handleLoadMore`, `transformRows`, `arePagesDifferent` and the columns unchanged.
  - The file is not Prettier-clean (DC-B).
- Create `apex-job/src/monitor/lwc/requestTable/__tests__/requestTable.test.js`.
  - Mock getJobRequestPage virtually (as in Part 13), `mockResolvedValue([])`.
  - Mount `c-request-table`. Use the same fake-timer helpers as apex-job/src/monitor/lwc/engineControls/__tests__/engineControls.test.js (read-only reference).
- Docs: `DESIGN.md:582` `requestTable` paragraph: add "the 2 s timer is cleared on disconnect and re-armed after each call, so a failed call does not stop polling".

### TDD steps
1. Run `npx prettier --write` on requestTable.js and commit it as `style(monitor): format requestTable` (DC-B).
2. GUARD `givenConnected_whenIntervalElapses_thenOneApexCallPerInterval`: 1 call on connect, 2 after 2000 ms. It passes today because the `setTimeout` chain already polls every 2 s.
3. RED `givenDisconnected_whenIntervalElapses_thenNoFurtherCall`: it fails because the timer keeps firing after removal (no `disconnectedCallback`).
4. RED `givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed`: it fails because the timer is armed after the await regardless of disconnect.
5. RED `givenRejectedCall_whenIntervalElapses_thenPollingResumes`: it fails because a rejected await skips the `setTimeout`, so the chain stops at 1 call. Apply DC-A.
6. GREEN: the `poll()`/`refresh()` split with `finally`, the `stopped` flag and `disconnectedCallback`. Steps 3-5 are green.
7. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/monitor/lwc/requestTable/requestTable.js apex-job/src/monitor/lwc/requestTable/__tests__/requestTable.test.js && npm run test:lwc -- requestTable && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30
```

### Commit
`fix(monitor): stop request table polling on disconnect and survive failed calls`

## Part 15 — statusByProcessorTable reads statistics from descriptions

### Context
- Edit `apex-job/src/monitor/lwc/statusByProcessorTable/statusByProcessorTable.js`. Today: `pollStatusByProcessor()` (`:45-63`) calls getStatusByProcessor and, when `arePagesDifferent`, calls `resolveProcessorNames(ids)` (`:33-43`, which calls getJobDescriptionInfos), merges the name and the rate-limit fields, then calls `setTimeout(..., 5000)` after the await. Target:
  - `const POLL_INTERVAL_MS = 5000;` and the Part 13 poll shape (`stopped`, `pollTimer`, `disconnectedCallback`, `poll()` with `finally`).
  - `refresh()` calls getStatusByProcessor, then `getJobDescriptionInfos({ jobDescriptionIds })` every poll, and merges per `processorId`:
    - `processorUrl = "/" + processorId`
    - `processorName ← ProcessorName__c`
    - `maxExecutionsPerMinute ← MaxExecutionsPerMinute__c`
    - `executionsInCurrentWindow ← ExecutionsInCurrentWindow__c`
    - `maxBulk ← MaxChunkSize__c`
    - `smallestFailingChunk ← SmallestFailingChunk__c`
    - `successStreak ← SuccessStreak__c`
    - `consecutiveFailure ← ConsecutiveFailures__c`
    - `lastExecutionDateTime ← LastExecutionDateTime__c`
  - Rename `resolveProcessorNames` to `resolveDescriptionInfos`; it returns a map keyed by Id. Build new row objects (`{ ...row, ...info }`) instead of mutating the Apex rows.
  - Delete `arePagesDifferent`. It never short-circuits, because the merged rows always differ from the fresh ones.
  - Columns: remove `Nb Try` (`nbTry`) and `Next Exec` (`nextExecutionDateTime`). `Last Exec` becomes `{ label: "Last Exec", fieldName: "lastExecutionDateTime", type: "date", typeAttributes: { year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit", second: "2-digit" }, hideDefaultActions: true, wrapText: true }`.
  - The file is not Prettier-clean (DC-B).
- Create `apex-job/src/monitor/lwc/statusByProcessorTable/__tests__/statusByProcessorTable.test.js`.
  - Mock getStatusByProcessor and getJobDescriptionInfos virtually.
  - Fixtures: `getStatusByProcessor` resolves `[{ processorId: "a01", status: "READY", nbRows: 5 }]`. `getJobDescriptionInfos` resolves `[{ Id: "a01", ProcessorName__c: "P", MaxChunkSize__c: 10, SmallestFailingChunk__c: 0, SuccessStreak__c: 3, ConsecutiveFailures__c: 0, LastExecutionDateTime__c: "2026-11-25T10:00:00.000Z", MaxExecutionsPerMinute__c: 0, ExecutionsInCurrentWindow__c: 0 }]`.
  - Read the rendered data from the `lightning-datatable` stub: `element.shadowRoot.querySelector("lightning-datatable").data`.
- Docs:
  - `DESIGN.md:580` `statusByProcessorTable` paragraph: "Polls every 5 s: one `getStatusByProcessor()` (`COUNT` per status and description, one query row per group) plus one `getJobDescriptionInfos()` for the processor name and statistics (max chunk, smallest failing chunk, success streak, consecutive failures, last execution, rate limit); timer cleared on disconnect."
  - `README.md:313`, the "Status by processor" bullet: "grouped counts by `Status__c`, with per-processor statistics (max chunk, smallest failing chunk, success streak, consecutive failures, rate limit, last execution) read from `JobDescription__c`."

### TDD steps
1. Run `npx prettier --write` on statusByProcessorTable.js and commit it as `style(monitor): format statusByProcessorTable` (DC-B).
2. RED `givenDescriptionInfos_whenRefresh_thenRowCarriesDescriptionStatistics`: after the first flush, the datatable row has `maxBulk 10`, `successStreak 3` and `lastExecutionDateTime` equal to the ISO string. It fails because those keys are only read from the (now slimmed) aggregate row, so they are `undefined`.
3. GREEN: the merge from `resolveDescriptionInfos` and the column changes.
4. GUARD `givenConnected_whenIntervalElapses_thenOneApexCallPerInterval`: 1 + 1 calls on connect, 2 + 2 after 5000 ms. It passes because `arePagesDifferent` always differs and the chain polls every 5 s.
5. RED `givenDisconnected_whenIntervalElapses_thenNoFurtherCall`: it fails because there is no `disconnectedCallback`.
6. RED `givenDisconnectedDuringInFlightCall_whenCallResolves_thenNoTimerArmed`: it fails because the timer is re-armed after the await.
7. RED `givenRejectedCall_whenIntervalElapses_thenPollingResumes`: it fails because the chain stops on rejection. Apply DC-A.
8. GREEN: the poll shape with `finally` and `stopped`. Delete `arePagesDifferent`.
9. REFACTOR: edit the docs.

### Gate
```bash
npx prettier --check apex-job/src/monitor/lwc/statusByProcessorTable/statusByProcessorTable.js apex-job/src/monitor/lwc/statusByProcessorTable/__tests__/statusByProcessorTable.test.js && npm run test:lwc -- statusByProcessorTable && sf project deploy start -o dev-async-processor -d apex-job/src -d apex-job/test -w 30
```

### Commit
`perf(monitor): read processor statistics from descriptions and stop polling on disconnect`

## Part 16 — document one chunk per description per transaction

### Context
Docs only, with no code delta.
- Edit `DESIGN.md`. Add a new `###` subsection under `## Key Design Decisions` (`:651`), titled "One Chunk per Description per Transaction". Place it after "Two-Transaction Architecture" (`:661`). Content:
  - **Rule**: a description gets at most ONE chunk of at most 50 requests per transaction. The selector excludes descriptions already executed (`JobSelectorImpl`, `JobDescription__c NOT IN :jobDescriptionIdsToExclude`, fed by `JobRepositoryImpl.extractDescriptionIds`) and caps rows at `ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE`.
  - **Cost** (Developer Edition scratch org, 2026-11-25): 1,000 no-op jobs take 25 transactions and 24-47 s, using about 21 ms of the 60,000 ms CPU budget per transaction. A one-transaction prototype did the same work in about 3.2 s.
  - **Why it stays**:
    - The rate counter is written only in the finalizer (`JobExecuted` description staging) and read by `AdaptiveChunkCalculator`, so several chunks in one transaction would read a stale counter.
    - The learner runs in the finalizer, so later chunks would size against an un-updated model.
    - Every eligible description gets a turn today.
    - A failing finalizer would lose up to about 5,000 recordings instead of 50.
    - Executed requests stay on the heap until the finalizer.
  - Add the entry to the Table of Contents (`:7-26`) only if the TOC lists `###` subsections; check first.
- Before writing, cite symbols, not line numbers, in the prose: earlier parts shifted lines in `JobSelectorImpl` and `JobExecuted`.

### TDD steps
- GUARD: none, because no code changes. Review: every claim in the section points at a symbol that exists in the tree at this commit. Check with `grep -n "extractDescriptionIds\|DEFAULT_MAX_CHUNK_SIZE" apex-job/src -r`.
- GREEN: write the section.
- REFACTOR: none.

### Gate
```bash
grep -n "One Chunk per Description per Transaction" DESIGN.md
```

### Commit
`docs(design): document the one-chunk-per-description-per-transaction rule`
