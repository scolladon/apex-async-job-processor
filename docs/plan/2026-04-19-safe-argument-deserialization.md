# Safe argument deserialization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Stop letting one malformed `JobRequest__c.Argument__c` kill a whole chunk and pollute the consumption model. Extract JSON parsing into a dedicated `JobRequestArgumentParser` class; route malformed requests to a terminal `MALFORMED_ARGUMENT` status; skip the consumption learner when every request in a chunk is malformed.

**Architecture:** New domain class + per-request routing inside `JobExecuted`. Chunk-level short-circuit in `JobExecutable` when all requests are malformed. Consumption-learner gate in `stageJobDescriptionExecution` skips learning for all-malformed chunks.

**Tech Stack:** Apex, SFDX metadata (one enum value, one picklist value), Apex Mockery.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-safe-argument-deserialization.md`](../design/2026-04-19-safe-argument-deserialization.md)

**Branch:** `feat/safe-argument-deserialization` (from `main`).

**Preconditions:** none. This PR removes the stale TODO at `JobExecutable.cls:58` as part of the refactor.

---

## PR description template

```
## Summary
Isolate malformed `Argument__c` failures to the individual `JobRequest__c`
record rather than killing the whole chunk and penalizing the
`JobDescription__c` consumption model.

## Motivation
Today one malformed JSON in `Argument__c` raises a `JSONException` inside
`JobExecutable.getArgument`, which escapes `executeChunk` and fails every
other request in the chunk. The consumption learner then calls
`adjustFromFailure` against a `JobDescription__c` whose processor never ran,
inflating its learned base.

## Changes
- New `JobRequestArgumentParser` class that returns `validArguments` plus a
  `Map<Id, String> malformedErrors` for a given chunk.
- New `MALFORMED_ARGUMENT` value in `ApexJobStatus` enum and
  `JobRequest__c.Status__c` picklist.
- New `ApexJobResult.malformedRequestErrors` field.
- `JobExecutable.executeChunk` uses the parser; short-circuits the processor
  when every request is malformed.
- `JobExecuted.stageJobRequestExecution` branches on per-request malformed
  entries and writes terminal-failure fields.
- `JobExecuted.stageJobDescriptionExecution` skips the consumption learner
  when the chunk status is `MALFORMED_ARGUMENT`.
- `ApexJobFactory(Impl)` exposes the parser via `getArgumentParser()`.
- Removes the stale TODO at `JobExecutable.cls:58`.

## Test plan
- [x] New `JobRequestArgumentParserTest` covers valid / null / malformed /
      mixed inputs.
- [x] New `JobExecutableTest` cases cover mixed and all-malformed chunks.
- [x] New `JobExecutedTest` cases cover per-request routing and learner
      skip.
- [x] `npm run prettier`, `npm run lint`, `npm run test:unit` green.
- [ ] `npm run test:integration` green (post-deploy, requires scratch org).
```

---

### Task 1: Add `MALFORMED_ARGUMENT` to the status enum and picklist

**Files:**
- Modify: `apex-job/src/engine/domain/classes/ApexJobStatus.cls`
- Modify: `apex-job/src/engine/domain/objects/JobRequest__c/fields/Status__c.field-meta.xml`

**Step 1: Add the enum constant**

In `ApexJobStatus.cls`, append a new constant. Keep alphabetical-ish grouping
by operational meaning (MALFORMED_ARGUMENT is terminal like ABORTED):

```apex
public enum ApexJobStatus {
  ABORTED,
  FAILURE,
  KILLED,
  MALFORMED_ARGUMENT, // Argument__c JSON could not be parsed; terminal
  READY,
  SUCCESS
}
```

**Step 2: Add the picklist value**

Open `Status__c.field-meta.xml` and append a new `<value>` entry inside the
`<valueSet>` / `<valueSetDefinition>` block. Match the existing format (look
at `ABORTED` or `KILLED` for the exact XML shape).

**Step 3: Commit**

```bash
git add apex-job/src/engine/domain/classes/ApexJobStatus.cls apex-job/src/engine/domain/objects/JobRequest__c/fields/Status__c.field-meta.xml
git commit -m "feat(status): add MALFORMED_ARGUMENT status enum and picklist value"
```

### Task 2: Extend `ApexJobResult` with per-chunk malformed tracking

**Files:**
- Modify: `apex-job/src/engine/domain/classes/ApexJobResult.cls`

**Step 1: Add the field**

After `consumedLimits` (line 4), add:

```apex
  public Map<Id, String> malformedRequestErrors { get; set; }
```

Default value is `null`; callers treat `null` and empty map equivalently.

**Step 2: Commit**

```bash
git add apex-job/src/engine/domain/classes/ApexJobResult.cls
git commit -m "feat(job-result): carry per-request malformed-argument errors"
```

### Task 3: Create `JobRequestArgumentParser` + test (RED → GREEN)

**Files:**
- Create: `apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls`
- Create: `apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls-meta.xml`
- Create: `apex-job/test/unit/classes/JobRequestArgumentParserTest.cls`
- Create: `apex-job/test/unit/classes/JobRequestArgumentParserTest.cls-meta.xml`

**Step 1: Write the test first (RED)**

Create `JobRequestArgumentParserTest.cls`:

```apex
@IsTest
private class JobRequestArgumentParserTest {
  @IsTest
  static void givenAllValidArguments_whenParse_thenValidListPopulatedAndNoErrors() {
    // Arrange
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{
      new JobRequest__c(Id = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 1), Argument__c = '{"k":"v"}'),
      new JobRequest__c(Id = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 2), Argument__c = '[1,2,3]')
    };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    // Act
    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    // Assert
    Assert.areEqual(2, result.validArguments.size(), 'Both requests should parse into validArguments');
    Assert.isTrue(result.malformedErrors.isEmpty(), 'No malformed errors expected');
  }

  @IsTest
  static void givenBlankArgument_whenParse_thenValidAsNull() {
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{
      new JobRequest__c(Id = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 1), Argument__c = null),
      new JobRequest__c(Id = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 2), Argument__c = '   ')
    };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    Assert.areEqual(2, result.validArguments.size(), 'Blank argument is valid-as-null, not malformed');
    Assert.isNull(result.validArguments[0], 'null Argument__c should parse as null');
    Assert.isNull(result.validArguments[1], 'whitespace Argument__c should parse as null');
    Assert.isTrue(result.malformedErrors.isEmpty(), 'No malformed errors expected for blank arguments');
  }

  @IsTest
  static void givenMalformedJson_whenParse_thenMalformedErrorsPopulated() {
    final Id malformedId = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 1);
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{
      new JobRequest__c(Id = malformedId, Argument__c = '{not valid json')
    };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    Assert.isTrue(result.validArguments.isEmpty(), 'Malformed arguments must not appear in validArguments');
    Assert.areEqual(1, result.malformedErrors.size(), 'Exactly one malformed entry expected');
    Assert.isTrue(result.malformedErrors.containsKey(malformedId), 'Malformed entry keyed by the request Id');
    Assert.isTrue(String.isNotBlank(result.malformedErrors.get(malformedId)), 'Malformed entry value must carry the JSON parser error message');
  }

  @IsTest
  static void givenMixedChunk_whenParse_thenValidAndMalformedSplitCorrectly() {
    final Id validId = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 1);
    final Id malformedId = ApexJobTestFixture.fakeId(JobRequest__c.SObjectType, 2);
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{
      new JobRequest__c(Id = validId, Argument__c = '{"ok":true}'),
      new JobRequest__c(Id = malformedId, Argument__c = 'not-json')
    };
    final JobRequestArgumentParser sut = new JobRequestArgumentParser();

    final JobRequestArgumentParser.ParseResult result = sut.parse(jobRequests);

    Assert.areEqual(1, result.validArguments.size(), 'Exactly one valid argument');
    Assert.areEqual(1, result.malformedErrors.size(), 'Exactly one malformed entry');
    Assert.isTrue(result.malformedErrors.containsKey(malformedId), 'Malformed keyed by correct Id');
  }
}
```

`ApexJobTestFixture.fakeId(SObjectType, Integer)` may not exist. If not, add
a minimal helper on `ApexJobTestFixture`:

```apex
public static Id fakeId(final SObjectType sobjType, final Integer i) {
  final String prefix = sobjType.getDescribe().getKeyPrefix();
  final String padded = String.valueOf(i).leftPad(12, '0');
  return Id.valueOf(prefix + padded);
}
```

**Step 2: Run tests — expect RED**

```bash
npm run test:unit
```

Expected: compilation fails — `JobRequestArgumentParser` doesn't exist yet.

**Step 3: Implement `JobRequestArgumentParser` (GREEN)**

Create `JobRequestArgumentParser.cls`:

```apex
public without sharing class JobRequestArgumentParser {
  public ParseResult parse(final List<JobRequest__c> jobRequests) {
    final ParseResult result = new ParseResult();
    final Integer size = jobRequests.size();
    for (Integer i = 0; i < size; ++i) {
      final JobRequest__c job = jobRequests[i];
      try {
        result.validArguments.add(JobRequestArgumentParser.parseOne(job));
      } catch (Exception e) {
        result.malformedErrors.put(job.Id, e.getMessage());
      }
    }
    return result;
  }

  private static Object parseOne(final JobRequest__c job) {
    if (String.isBlank(job.Argument__c)) {
      return null;
    }
    return JSON.deserializeUntyped(job.Argument__c);
  }

  public class ParseResult {
    public List<Object> validArguments { get; private set; }
    public Map<Id, String> malformedErrors { get; private set; }

    public ParseResult() {
      this.validArguments = new List<Object>();
      this.malformedErrors = new Map<Id, String>();
    }
  }
}
```

Create `JobRequestArgumentParser.cls-meta.xml`:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>65.0</apiVersion>
    <status>Active</status>
</ApexClass>
```

Same meta file for the test class with `<status>Active</status>`.

**Step 4: Run tests — expect GREEN**

```bash
npm run test:unit
```

Expected: all four new tests pass. Existing tests unaffected.

**Step 5: Commit**

```bash
git add apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls-meta.xml apex-job/test/unit/classes/JobRequestArgumentParserTest.cls apex-job/test/unit/classes/JobRequestArgumentParserTest.cls-meta.xml apex-job/test/unit/classes/ApexJobTestFixture.cls
git commit -m "feat(argument-parser): introduce JobRequestArgumentParser"
```

### Task 4: Expose parser through `ApexJobFactory`

**Files:**
- Modify: `apex-job/src/engine/service/ApexJobFactory.cls`
- Modify: `apex-job/src/engine/service/ApexJobFactoryImpl.cls`
- Modify: `apex-job/test/unit/classes/ApexJobTestMock.cls`

**Step 1: Add the factory method signature**

In `ApexJobFactory.cls`, add:

```apex
  JobRequestArgumentParser getArgumentParser();
```

**Step 2: Implement in `ApexJobFactoryImpl`**

Add a lazy-initialized static singleton following the pattern of the other
getters (e.g. `getLimitService`):

```apex
  private static JobRequestArgumentParser argumentParserInstance;

  public JobRequestArgumentParser getArgumentParser() {
    if (argumentParserInstance == null) {
      argumentParserInstance = new JobRequestArgumentParser();
    }
    return argumentParserInstance;
  }
```

**Step 3: Wire spies in `ApexJobTestMock`**

Per `CLAUDE.local.md` ("Mocks: Apex Mockery — centralized in `ApexJobTestMock`"),
add the new spies alongside the existing factory stubs so downstream tests
(Tasks 5 and 6) can reference them:

1. **Parser mock** — `argumentParserMock`, `argumentParserStub`, and a spy on `parse(List<JobRequest__c>)`. Default return: an empty `ParseResult` (all valid, no errors). Wire `factoryStub.getArgumentParser()` to return `argumentParserStub`.
2. **Consumption-learner spies** — if not already present, wire `consumptionLearnerSpy_adjustFromSuccess`, `consumptionLearnerSpy_adjustFromFailure`, and `consumptionLearnerSpy_adjustFromKill` on `consumptionLearnerMock` and expose them as public fields on `ApexJobTestMock`. Task 6 test `givenAllMalformedChunk_whenStageExecution_thenConsumptionLearnerNotInvoked` asserts on these; they must exist before Task 6 begins.

Implementation detail: follow the exact naming and visibility pattern used by the existing `isSystemEnabledSpy`, `recordJobExecutionSpy` fields on `ApexJobTestMock` so new callers feel idiomatic.

**Step 4: Commit**

```bash
git add apex-job/src/engine/service/ApexJobFactory.cls apex-job/src/engine/service/ApexJobFactoryImpl.cls apex-job/test/unit/classes/ApexJobTestMock.cls
git commit -m "feat(factory): expose JobRequestArgumentParser via ApexJobFactory"
```

### Task 5: Refactor `JobExecutable.executeChunk` to use the parser (TDD)

**Files:**
- Modify: `apex-job/src/engine/domain/classes/JobExecutable.cls`
- Modify: `apex-job/test/unit/classes/JobExecutableTest.cls`

**Step 1: Write failing tests (RED)**

Processor-invocation assertions cannot use a centralized Mockery spy because
`JobExecutable.getProcessor` resolves the processor class by name via
`Type.forName` at runtime — the factory does not intermediate the
instantiation (restructuring that path is scope-creep tied to §1 processor
whitelist, deferred). Use a real `ApexJob` stub class defined inside
`JobExecutableTest`, set `JobDescription__r.ProcessorName__c` to its
fully-qualified name, and have the stub record invocations on a
`public static Integer invocationCount` field.

Add the stub near the top of `JobExecutableTest`:

```apex
  public class SpyProcessor implements ApexJob {
    public static Integer invocationCount = 0;
    public static Integer lastArgumentsSize = 0;

    public ApexJobResult execute(final ApexJobContext ctx) {
      invocationCount++;
      lastArgumentsSize = ctx.getArguments().size();
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }
```

Reset the counters at the top of each test (`SpyProcessor.invocationCount = 0; SpyProcessor.lastArgumentsSize = 0;`).

Then append the tests:

```apex
  @IsTest
  static void givenAllMalformedChunk_whenExecuteChunk_thenProcessorNotCalledAndResultStatusIsMalformed() {
    // Arrange — two requests with invalid JSON; processor stub should not be invoked.
    SpyProcessor.invocationCount = 0;
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobRequest__c request1 = ApexJobTestFixture.aJobRequest().withArgument('bad-json-1').build();
    final JobRequest__c request2 = ApexJobTestFixture.aJobRequest().withArgument('bad-json-2').build();
    request1.JobDescription__r = ApexJobTestFixture.aJobDescription().withProcessorName('JobExecutableTest.SpyProcessor').build();
    request2.JobDescription__r = request1.JobDescription__r;
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ request1, request2 });

    // Act
    final JobExecuted executed = sut.executeChunk();

    // Assert
    Assert.areEqual(ApexJobStatus.MALFORMED_ARGUMENT, executed.jobExecutionResult.status, 'All-malformed chunk must return MALFORMED_ARGUMENT status');
    Assert.areEqual(2, executed.jobExecutionResult.malformedRequestErrors.size(), 'Both request Ids must be recorded in malformedRequestErrors');
    Assert.areEqual(0, SpyProcessor.invocationCount, 'Processor must not be invoked when every request is malformed');
  }

  @IsTest
  static void givenMixedChunk_whenExecuteChunk_thenProcessorCalledOnlyWithValidArguments() {
    // Arrange — one valid, one malformed.
    SpyProcessor.invocationCount = 0;
    SpyProcessor.lastArgumentsSize = 0;
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobRequest__c valid = ApexJobTestFixture.aJobRequest().withArgument('{"ok":true}').build();
    final JobRequest__c malformed = ApexJobTestFixture.aJobRequest().withArgument('bad').build();
    valid.JobDescription__r = ApexJobTestFixture.aJobDescription().withProcessorName('JobExecutableTest.SpyProcessor').build();
    malformed.JobDescription__r = valid.JobDescription__r;
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ valid, malformed });

    // Act
    final JobExecuted executed = sut.executeChunk();

    // Assert
    Assert.areEqual(1, SpyProcessor.invocationCount, 'Processor must be invoked exactly once when the chunk has at least one valid request');
    Assert.areEqual(1, SpyProcessor.lastArgumentsSize, 'Processor must receive only the valid argument');
    Assert.areEqual(1, executed.jobExecutionResult.malformedRequestErrors.size(), 'Only the malformed request is tracked');
    Assert.isTrue(executed.jobExecutionResult.malformedRequestErrors.containsKey(malformed.Id), 'Malformed entry keyed by the malformed request Id');
  }
```

**Step 2: Implement the refactor (GREEN)**

In `JobExecutable.cls`, replace the body of `executeChunk()` (currently lines
17–34) with the block below. Also delete the private `getContextArguments`
(around line 47) and `getArgument` (around line 59) methods — the parser
subsumes both — and remove the stale TODO at line 58.

```apex
public JobExecuted executeChunk() {
  final JobRequestArgumentParser parser = this.factory.getArgumentParser();
  final JobRequestArgumentParser.ParseResult parsed = parser.parse(this.jobRequests);

  this.limitService.startSnapshot();
  ApexJobResult apexJobResult;
  if (parsed.validArguments.isEmpty() && !parsed.malformedErrors.isEmpty()) {
    apexJobResult = new ApexJobResult(ApexJobStatus.MALFORMED_ARGUMENT);
  } else {
    try {
      final ApexJob jobProcessor = JobExecutable.getProcessor(this.jobDescription);
      apexJobResult = jobProcessor.execute(new ApexJobContext(parsed.validArguments));
    } catch (final Exception ex) {
      apexJobResult = new ApexJobResult(ex);
    }
  }
  apexJobResult.consumedLimits = this.limitService.stopSnapshot();
  apexJobResult.malformedRequestErrors = parsed.malformedErrors;
  this.endTime = System.now();

  ApexJobTransactionContext.getInstance().markExecutedJobs();
  return new JobExecuted(this.factory, this, apexJobResult);
}
```

(The deletion of `getContextArguments`, `getArgument`, and the TODO at line
58 was already called out in Step 2 above; no further action needed here.)

**Step 3: Run tests — expect GREEN**

```bash
npm run test:unit
```

**Step 4: Commit**

```bash
git add apex-job/src/engine/domain/classes/JobExecutable.cls apex-job/test/unit/classes/JobExecutableTest.cls
git commit -m "feat(executable): isolate malformed arguments from processor invocation"
```

### Task 6: Update `JobExecuted` for per-request routing + learner skip (TDD)

**Files:**
- Modify: `apex-job/src/engine/domain/classes/JobExecuted.cls`
- Modify: `apex-job/test/unit/classes/JobExecutedTest.cls`

**Step 1: Write failing tests (RED)**

Add to `JobExecutedTest.cls`:

```apex
  @IsTest
  static void givenChunkWithMalformedRequest_whenStageExecution_thenThatRequestMarkedMalformedTerminal() {
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().build();
    final JobRequest__c valid = ApexJobTestFixture.aJobRequest().withName('ok').build();
    final JobRequest__c malformed = ApexJobTestFixture.aJobRequest().withName('bad').build();
    valid.JobDescription__r = jobDescription;
    malformed.JobDescription__r = jobDescription;

    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ valid, malformed });
    final ApexJobResult apexJobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    apexJobResult.consumedLimits = ApexJobTestFixture.aLimitsUsage().build();
    apexJobResult.malformedRequestErrors = new Map<Id, String>{ malformed.Id => 'Unexpected character at pos 1' };

    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, apexJobResult);

    sut.stageExecution();

    Assert.areEqual('MALFORMED_ARGUMENT', malformed.Status__c, 'Malformed request must be terminal-failed');
    Assert.areEqual('Unexpected character at pos 1', malformed.LastExecutionMessage__c);
    Assert.isNull(malformed.NextExecutionDateTime__c, 'Malformed request must not be retried');
    Assert.areEqual('SUCCESS', valid.Status__c, 'Valid request must follow the chunk result');
  }

  @IsTest
  static void givenAllMalformedChunk_whenStageExecution_thenConsumptionLearnerNotInvoked() {
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().build();
    final JobRequest__c malformed = ApexJobTestFixture.aJobRequest().build();
    malformed.JobDescription__r = jobDescription;

    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ malformed });
    final ApexJobResult apexJobResult = new ApexJobResult(ApexJobStatus.MALFORMED_ARGUMENT);
    apexJobResult.malformedRequestErrors = new Map<Id, String>{ malformed.Id => 'bad' };
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, apexJobResult);

    sut.stageExecution();

    Expect.that(mocks.consumptionLearnerSpy_adjustFromSuccess).hasNotBeenCalled();
    Expect.that(mocks.consumptionLearnerSpy_adjustFromFailure).hasNotBeenCalled();
    Expect.that(mocks.consumptionLearnerSpy_adjustFromKill).hasNotBeenCalled();
  }
```

**Step 2: Implement the routing (GREEN)**

In `JobExecuted.stageJobRequestExecution`, prepend a malformed branch:

```apex
private void stageJobRequestExecution(final JobRequest__c job) {
  if (this.jobExecutionResult.malformedRequestErrors != null
      && this.jobExecutionResult.malformedRequestErrors.containsKey(job.Id)) {
    job.Status__c = ApexJobStatus.MALFORMED_ARGUMENT.name();
    job.LastExecutionMessage__c = this.jobExecutionResult.malformedRequestErrors.get(job.Id);
    job.NextExecutionDateTime__c = null;
    job.AttemptNumber__c = Math.min((job.AttemptNumber__c ?? 0) + 1, MAX_EXECUTION_ATTEMPT_NUMBER);
    job.LastSelectionDateTime__c = this.stagingInfo.selectionTime;
    job.LastExecutionDateTime__c = this.stagingInfo.endTime;
    return;
  }
  this.calculateTimingMetrics(job);
  this.determineNextStatus(job);
}
```

In `JobExecuted.stageJobDescriptionExecution`, add an early return at the top
(after `LastExecutionDateTime__c` assignment and rate-limit counter):

```apex
if (this.jobExecutionResult.status == ApexJobStatus.MALFORMED_ARGUMENT) {
  return;
}
```

Place it after `updateRateLimitCounter()` — rate limits still count the
(attempted) chunk size so a malformed-spam flood is still rate-limited, but
the learner is skipped because there is no meaningful consumption data.

**Step 3: Run tests — expect GREEN**

```bash
npm run test:unit
```

**Step 4: Commit**

```bash
git add apex-job/src/engine/domain/classes/JobExecuted.cls apex-job/test/unit/classes/JobExecutedTest.cls
git commit -m "feat(executed): route malformed requests terminal and skip learner"
```

### Task 7: Final gate

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

If prettier reformats anything, commit the result separately:

```bash
git add -u
git commit -m "chore: format safe-argument-deserialization changes"
```

**Step 2: Deploy + integration smoke test (optional, recommended before PR)**

```bash
npm run build          # deploys to configured scratch org
npm run test:integration
```

If integration tests fail due to the new picklist value not being assignable,
confirm `Status__c.field-meta.xml` was deployed.

---

## Verification (done when)

- `JobRequestArgumentParser` + test exist and pass.
- `ApexJobStatus.MALFORMED_ARGUMENT` and picklist value exist.
- `ApexJobResult.malformedRequestErrors` field exists.
- `JobExecutable.executeChunk` uses parser; stale TODO at line 58 is gone;
  `getArgument` + `getContextArguments` methods deleted.
- `JobExecuted` per-request routing + learner skip both in place.
- All unit tests pass; at least 6 new tests added (4 parser + 2 executable + 2 executed).
- `git log --oneline main..HEAD` shows approximately 6 commits, one per task above.
- CI passes.

## Notes for reviewers

- The permission set (`AdminAsyncJob.permissionset-meta.xml`) is **out of
  scope** for this PR per the confirmed batch scope. If a subscriber persona
  needs read access to the new picklist value on `Status__c`, file a
  follow-up.
- The processor resolver (`JobExecutable.getProcessor`) is **not** touched
  by this PR; the unrelated `// TODO Part of the JobDescription domain`
  comment at line 36 was removed by the earlier `chore: cleanup stale TODOs`
  PR.
