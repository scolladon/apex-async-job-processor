# Design Document — Async Job Processor

A Salesforce DX unlocked package implementing a Queueable-based async job processor with adaptive governor limit tracking. Jobs are defined via `JobDescription__c` metadata and processed as `JobRequest__c` records in priority order, with chunk sizes dynamically adjusted based on learned consumption patterns.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Data Model](#data-model)
- [Execution Flow](#execution-flow)
- [Domain Layer](#domain-layer)
- [Service Layer](#service-layer)
- [Adapter Layer](#adapter-layer)
- [Application Layer](#application-layer)
- [Adaptive Chunk Calculation](#adaptive-chunk-calculation)
- [Consumption Learning Algorithm](#consumption-learning-algorithm)
- [Governor Limit Tracking](#governor-limit-tracking)
- [Malformed Argument Handling](#malformed-argument-handling)
- [Monitoring UI](#monitoring-ui)
- [Operator Scripts](#operator-scripts)
- [Security Model](#security-model)
- [Extensibility](#extensibility)
- [Key Design Decisions](#key-design-decisions)

---

## Architecture Overview

Hexagonal architecture with four layers under `apex-job/src/engine/`:

```
┌─────────────────────────────────────────────────────────┐
│                    APPLICATION                          │
│  ApexJobManager (public API)                            │
│  AsyncApexJobExecutor (Queueable + Finalizer)           │
├─────────────────────────────────────────────────────────┤
│                      DOMAIN                             │
│  JobCandidate → JobExecutable → JobExecuted             │
│  LimitsUsage, ConsumptionModel, ApexJobStatus           │
│  AdaptiveChunkCalculator, AdaptiveConsumptionLearner    │
├─────────────────────────────────────────────────────────┤
│                      SERVICE                            │
│  ApexJobFactory (DI), LimitService, JobExecutorService  │
│  ApexJobTransactionContext, ApexJobConfigService         │
├─────────────────────────────────────────────────────────┤
│                      ADAPTER                            │
│  JobSelectorImpl, JobRepositoryImpl (without sharing)   │
│  JobExecutorQueueableSpawner, ApexJobWatcher             │
│  ApexJobConfigServiceImpl, ApexJobLoggerImpl             │
└─────────────────────────────────────────────────────────┘
```

- **Application** — Public API and orchestration. The only external surface.
- **Domain** — Pure business logic, no database access. Core types model the job lifecycle.
- **Service** — Interfaces, DI container, transaction context. Bridges domain and adapter.
- **Adapter** — Database/external access, all `without sharing`. SOQL, DML, platform API calls.

Additional directories:
- `apex-job/src/admin/` — Permission sets and custom permissions.
- `apex-job/src/monitor/` — LWC monitoring console and Apex controller.

---

## Data Model

```
ApexJobConfig__c (Hierarchy Custom Setting)
  ├── Enabled__c (Checkbox, default: true)
  └── EnqueueDelayOutsideBusinessHours__c (Number, default: 0)

JobDescription__c [1]                          JobRequest__c [N]
  ├── ProcessorName__c (Text, unique, ext ID)    ├── JobDescription__c (Lookup, required)
  ├── Enabled__c (Checkbox)                      ├── Argument__c (LongTextArea, 131072)
  ├── Priority__c (Number, default: -1)          ├── Status__c (Picklist: READY|FAILURE|KILLED|ABORTED|SUCCESS|MALFORMED_ARGUMENT)
  ├── isRecurrent__c (Checkbox)                  ├── Enabled__c (Checkbox)
  ├── AllowedDays__c (MultiselectPicklist)        ├── IsCandidate__c (Formula, Checkbox)
  ├── AllowedStartTime__c (Time)                 ├── AttemptNumber__c (Number)
  ├── AllowedEndTime__c (Time)                   ├── NextExecutionDateTime__c (DateTime)
  ├── MinJobInterval__c (Number)                 ├── LastSelectionDateTime__c (DateTime)
  ├── MaxExecutionAttempt__c (Number, -1=∞)      ├── LastExecutionDateTime__c (DateTime)
  ├── MaxChunkSize__c (Number, -1=unknown)       ├── LastExecutionMessage__c (LongTextArea)
  ├── MaxChunkSizeLimit__c (Number, default: 50) ├── WaitTime__c (Number, ms)
  ├── SmallestFailingChunk__c (Number)           ├── ChunkRunTime__c (Number, ms)
  ├── ConsecutiveFailures__c (Number)            ├── UnitRunTime__c (Number, ms)
  ├── SuccessStreak__c (Number)                  ├── ProcessingTime__c (Number, ms)
  ├── VariationResetThreshold__c (Number, 0.3)   └── JobIds__c (LongTextArea, audit trail)
  ├── LearningRate__c (Number, 0.30)             // EWMA α — weight of the latest observation
  ├── VariationResetCount__c (Number, 3)         // consecutive variations before model reset
  ├── ConsecutiveVariationCount__c (Number, 0)   // engine-managed counter
  ├── KillCooldownCount__c (Number, 3)           // consecutive successes that must pass before EWMA resumes after a kill/failure
  ├── LastExecutionDateTime__c (DateTime)
  └── 18 dimensions × 3 fields = 54 consumption model fields
```

### The 18-Dimension Consumption Model

Each Salesforce governor limit dimension has three fields on `JobDescription__c`:

- **Base** — Fixed cost per chunk execution, independent of chunk size.
- **PerItem** — Marginal cost per additional item beyond the first.
- **Safety** — Fraction [0.5–0.98] of remaining capacity to target.

| # | Dimension | Salesforce Governor Limit |
|---|---|---|
| 1 | `cpuTime` | CPU time (10,000 ms) |
| 2 | `heapSize` | Heap size (12 MB async) |
| 3 | `callout` | Total callouts (100) |
| 4 | `calloutTime` | Callout time (120,000 ms, custom-tracked) |
| 5 | `publishImmediateDml` | Platform event immediate DML (150) |
| 6 | `dmlRows` | DML rows (10,000) |
| 7 | `dmlStatements` | DML statements (150) |
| 8 | `queryRows` | Query rows (50,000) |
| 9 | `queries` | SOQL queries (100) |
| 10 | `soslQueries` | SOSL queries (20) |
| 11 | `futureCalls` | @future calls (50) |
| 12 | `aggregateQueries` | Aggregate queries (300) |
| 13 | `apexCursorRows` | Apex cursor rows (300,000) |
| 14 | `fetchCallsOnApexCursor` | Fetch calls on Apex cursor (2,000) |
| 15 | `emailInvocations` | Email invocations (10) |
| 16 | `mobilePushApexCalls` | Mobile push calls (10) |
| 17 | `queryLocatorRows` | Query locator rows (10,000) |
| 18 | `queueableJobs` | Queueable jobs (1) |

Field names are derived algorithmically by `ConsumptionModel.asList()` from `LimitsUsage.dimensions()`:
```
dimension "cpuTime" → CpuTimeBaseConsumption__c, CpuTimePerItemConsumption__c, CpuTimeSafety__c
```

### IsCandidate__c Formula Field

All scheduling eligibility is encapsulated in a single formula on `JobRequest__c`:

```
Enabled__c = TRUE
AND JobDescription__r.Enabled__c = TRUE
AND Status__c IN (READY, FAILURE, KILLED)
AND (NextExecutionDateTime__c <= NOW() OR NextExecutionDateTime__c IS NULL)
AND (AttemptNumber__c < MaxExecutionAttempt__c OR MaxExecutionAttempt__c = -1)
AND (AllowedDays__c includes current day OR AllowedDays__c IS NULL)
AND (TIMENOW() between AllowedStartTime__c and AllowedEndTime__c, or both NULL)
```

The selector query only needs `WHERE IsCandidate__c = TRUE`.

---

## Execution Flow

```
External trigger (ApexJobWatcher scheduled job or JobRequest insert trigger)
     │
     ▼
JobExecutorQueueableSpawner.enqueue()
     │ (DuplicateSignature prevents double-enqueue)
     ▼
System.enqueueJob(new AsyncApexJobExecutor(), options)
     │
     ▼
═══════════════════════════════════════════════════════════
  QUEUEABLE TRANSACTION — AsyncApexJobExecutor.execute(QueueableContext)
═══════════════════════════════════════════════════════════
     │
     ├── attachFinalizer(this)
     ├── cannotRun() guard (system enabled? no duplicate executor?)
     │
     └── LOOP:
          ├── JobRepository.getJobCandidates(alreadyExecuted)
          │     └── JobSelectorImpl: 18-dimension WHERE + IsCandidate__c = TRUE
          │          ORDER BY Priority DESC, MaxChunkSize ASC, ...
          │
          ├── JobCandidate.getExecutableChunk()
          │     ├── MaxChunkSize == -1? → chunk = 1 (bootstrap probe)
          │     └── AdaptiveChunkCalculator.getMaxPossible(jobDescription)
          │           └── min across 18 dims: (available - base) × safety / perItem + 1
          │
          ├── JobExecutable.executeChunk()
          │     ├── Type.forName(processorName).newInstance() → ApexJob
          │     ├── LimitService.startSnapshot()
          │     ├── apexJob.execute(ApexJobContext)      ← USER CODE
          │     ├── LimitService.stopSnapshot() → LimitsUsage delta
          │     └── return JobExecuted
          │
          └── accumulate result, loop back
               (exits when no candidates remain or governor limits exhausted)
     │
     ▼
═══════════════════════════════════════════════════════════
  FINALIZER TRANSACTION — AsyncApexJobExecutor.execute(FinalizerContext)
═══════════════════════════════════════════════════════════
     │
     ├── [Block 1: Persist]
     │     ├── wasLastChunkKilled() gate:
     │     │     UNHANDLED_EXCEPTION AND lastExecutableJob set AND
     │     │     last entry of jobExecutionResults was produced by a
     │     │     DIFFERENT executable (reference inequality)
     │     │     → Synthesize KILLED result (idempotent: prevents the
     │     │       SUCCESS-then-kill race from producing a duplicate)
     │     └── JobRepository.recordJobExecution(results)
     │           ├── JobExecuted.stageExecution() per result:
     │           │     ├── Calculate timing metrics
     │           │     ├── Determine next status (state machine)
     │           │     └── ConsumptionLearner.adjustFrom{Success|Failure|Kill}()
     │           ├── Database.update(records, allOrNone=false)
     │           └── Database.delete(successfulJobs, allOrNone=false)
     │
     └── [Block 2: Re-enqueue]
           ├── delay = 0 if work done, configured delay if idle
           └── JobExecutorSpawner.enqueue(delay) → chain continues
```

### Job Request Lifecycle

```
Created (READY) ──▶ Picked up (IsCandidate__c = TRUE)
    │
    ├── SUCCESS ──▶ Record DELETED (non-recurrent)
    ├── SUCCESS ──▶ READY + NextExecutionDateTime (recurrent)
    ├── FAILURE ──▶ READY + NextExecutionDateTime, AttemptNumber++
    ├── KILLED  ──▶ READY + NextExecutionDateTime
    └── ABORTED ──▶ Final state (attempt limit reached)
```

---

## Domain Layer

All domain classes live under `apex-job/src/engine/domain/classes/`. No database access.

### Core Types

| Class | Responsibility |
|---|---|
| `ApexJob` | Interface — the single extension point. Implementors define `execute(ApexJobContext): ApexJobResult`. |
| `ApexJobContext` | Read-only carrier of deserialized `Argument__c` values for a chunk. |
| `ApexJobResult` | Execution outcome. Contains `ApexJobStatus` + optional error + mutable `consumedLimits` (populated post-execution by infrastructure). |
| `ApexJobStatus` | Enum: `READY`, `SUCCESS`, `FAILURE`, `ABORTED`, `KILLED`, `MALFORMED_ARGUMENT`. |
| `JobRequestArgumentParser` | Parses each `JobRequest__c.Argument__c` via `JSON.deserializeUntyped`, returning a `ParseResult(validArguments, malformedErrors)` so one bad row can't fail the whole chunk. |
| `ApexJobConstant` | Sentinel values: `UNKNOWN_MAX_CHUNK_SIZE = -1`, `UNKNOWN_SAFETY = 0.74`, `DEFAULT_MAX_CHUNK_SIZE = 50`. |
| `LimitsUsage` | Map-backed store with 18 typed properties. `dimensions()` returns the canonical ordered list driving the entire system. |
| `ConsumptionModel` | Flyweight mapping a dimension name to its three `JobDescription__c` field names. `asList()` is lazily cached. |

### Lifecycle Objects

**`JobCandidate`** — Wraps a `JobDescription__c` with its eligible `JobRequest__c` list. `getExecutableChunk()` computes chunk size and produces a `JobExecutable`. Bootstrap logic: `MaxChunkSize__c == -1` forces `chunkSize = 1`.

**`JobExecutable`** — Executes a chunk. Parses arguments via `JobRequestArgumentParser`; short-circuits to `MALFORMED_ARGUMENT` without invoking the processor when every request is malformed. Otherwise instantiates the processor via reflection (`Type.forName`), passes only the valid arguments, wraps execution in limit snapshots. Catches processor exceptions and converts to `FAILURE` results. Attaches `malformedRequestErrors` to the `ApexJobResult` for per-request staging. Returns a `JobExecuted`.

**`JobExecuted`** — Post-execution staging. Exposes `executable` (public read-only reference to the source `JobExecutable`, used by the finalizer's idempotent kill-gate). Two responsibilities:
1. Stage `JobRequest__c` records: compute timing metrics, determine next status via a state machine. Malformed requests (in `malformedRequestErrors`) are tagged terminal (`Status__c = MALFORMED_ARGUMENT`, no retry).
2. Drive consumption learning: route to `ConsumptionLearner.adjustFrom{Success|Failure|Kill}()` based on result status. Skipped entirely when the chunk-level status is `MALFORMED_ARGUMENT` — no processor ran, so no limits were consumed that deserve learning.

### Subdirectories

- `chunk-calculation/` — `ChunkSizeCalculator` interface + `AdaptiveChunkCalculator` implementation.
- `consumption-learning/` — `ConsumptionLearner` interface + `AdaptiveConsumptionLearner` implementation.

---

## Service Layer

All services live under `apex-job/src/engine/service/`.

### ApexJobFactory — DI Container

`ApexJobFactory` interface with `ApexJobFactoryImpl` implementation. All instances are **static lazy singletons** — one per transaction, shared across the entire execution loop.

```
getLogger()                → ApexJobLoggerImpl
getSelector()              → JobSelectorImpl
getRepository()            → JobRepositoryImpl
getSpawner()               → JobExecutorQueueableSpawner
getExecutorService()       → JobExecutorServiceImpl
getFinalizerAttacher()     → JobExecutorFinalizerAttacherImpl
getConfigService()         → ApexJobConfigServiceImpl
getLimitService()           → LimitServiceImpl
getChunkSizeCalculator()   → AdaptiveChunkCalculator
getConsumptionLearner(job) → new AdaptiveConsumptionLearner(job)  // NOT a singleton
getArgumentParser()        → JobRequestArgumentParser
```

Every component follows the same DI handshake:
```apex
public SomeClass() { this(new ApexJobFactoryImpl()); }          // production
@TestVisible private SomeClass(ApexJobFactory factory) { ... }   // test injection
```

### LimitService

Tracks 18 governor limit dimensions. `startSnapshot()` / `stopSnapshot()` measure deltas. `getAvailableLimits()` returns remaining capacity with a 3% buffer on `cpuTime` and `heapSize`.

**Callout time** has no `System.Limits` API — tracked via a static `totalCalloutTimeConsumedInMs` accumulator using wall-clock timestamps, detected by comparing `Limits.getCallouts()` before and after.

### ApexJobTransactionContext

Static singleton holding a `hasExecutedJobs` boolean. Set to `true` after the first chunk executes. Consumed by `JobSelectorImpl` to control whether unknown-model jobs (`MaxChunkSize = -1`) are included in the candidate query.

### ApexJobConfigService

Reads `ApexJobConfig__c.getOrgDefaults()`. Provides `isSystemEnabled()` (global kill switch) and `getEnqueueDelayInMinutes()` (idle re-enqueue delay, considering business hours, clamped to [0, 10] minutes).

### JobExecutorService

Queries `AsyncApexJob` to detect if another `AsyncApexJobExecutor` is already running. Prevents duplicate parallel executors.

---

## Adapter Layer

All adapters live under `apex-job/src/engine/adapter/`, all `without sharing`.

### JobSelectorImpl — 18-Dimension SOQL

The WHERE clause includes all 18 base-consumption checks plus structural filters:

```sql
WHERE JobDescription__c NOT IN :excludedIds
  AND IsCandidate__c = TRUE
  AND JobDescription__r.MaxChunkSize__c >= :minMaxChunkSize
  AND JobDescription__r.CpuTimeBaseConsumption__c <= :availableLimits.cpuTime
  AND JobDescription__r.HeapSizeBaseConsumption__c <= :availableLimits.heapSize
  ... (16 more dimensions)
ORDER BY Priority__c DESC, MaxChunkSize__c ASC,
         CalloutBaseConsumption__c ASC, LastExecutionDateTime__c ASC NULLS FIRST,
         NextExecutionDateTime__c ASC
LIMIT 50
```

**Callout guard**: If DML has occurred in the transaction, `maxCallout` is set to 0, excluding callout-making jobs (prevents Salesforce's "Uncommitted Work Pending" error).

### JobRepositoryImpl — Result Persistence

`recordJobExecution()` runs in the Finalizer. Uses `Database.update(records, false)` and `Database.delete(successJobs, false)` — `allOrNone: false` is deliberate because partial success beats total failure in the Finalizer context.

`JobIds__c` accumulation: appends the 15-char async job ID to a semicolon-delimited string, trimming oldest entries when exceeding 131,072 characters.

### JobExecutorQueueableSpawner

Enqueues the next `AsyncApexJobExecutor` with `QueueableDuplicateSignature` to prevent race-condition double-enqueues. `DuplicateMessageException` is caught and silently dropped.

### ApexJobWatcher — Schedulable Watchdog

12 cron jobs (every 5 minutes) call `spawner.enqueue()`. If the executor chain dies unexpectedly, the watcher restarts it within 5 minutes. Scheduling is idempotent — checks for existing `CronTrigger` records before creating.

### Other Adapters

| Class | Purpose |
|---|---|
| `ApexJobRepositoryImpl` | Simple CRUD for `ApexJobManager` public API (insert/update/upsert). |
| `JobExecutorFinalizerAttacherImpl` | Thin wrapper around `System.attachFinalizer()` for testability. |
| `ApexJobConfigServiceImpl` | Reads `ApexJobConfig__c` custom setting + `BusinessHours` for off-hours delay. |
| `ApexJobLoggerImpl` | Delegates to `System.debug()`. |
| `JobDescriptionActionsController` | `with sharing`, `@AuraEnabled` bridge for the reset consumption model LWC action. |

---

## Application Layer

### ApexJobManager — Public API

Static utility class providing all external operations:

```apex
// Create a job request
ApexJobManager.request()
    .forProcessor('MyProcessor')
    .payload(myObject)
    .scheduleAt(Datetime.now().addHours(1))
    .save();

// Define a job type
ApexJobManager.define()
    .processor('MyProcessorClassName')
    .priority(10)
    .recurrent()
    .maxAttempts(3)
    .save();

// Admin operations
ApexJobManager.enableJobDescription(id);
ApexJobManager.disableJobDescription(id);
ApexJobManager.enableJobRequest(id);
ApexJobManager.disableJobRequest(id);
ApexJobManager.resetConsumptionModel(processorName);
```

### AsyncApexJobExecutor — The Runtime Engine

Implements `Queueable`, `Finalizer`, and `Database.AllowsCallouts`. The same instance serves both roles — Salesforce preserves the object heap across the Queueable→Finalizer boundary, allowing `lastExecutableJob` and `jobExecutionResults` to flow without external storage.

**Queueable phase**: Attaches self as Finalizer, runs an infinite loop querying candidates and executing chunks until no candidates remain or governor limits are exhausted.

**Finalizer phase**: Two independent try/catch blocks:
1. **Persist**: If `UNHANDLED_EXCEPTION` and a job was in-flight, synthesize a `KILLED` result. Persist all results via `recordJobExecution`.
2. **Re-enqueue**: If system enabled, enqueue the next executor (delay 0 if work done, configured delay if idle).

The two-block design ensures a persistence failure does not prevent re-enqueueing.

---

## Adaptive Chunk Calculation

`AdaptiveChunkCalculator` computes the maximum safe chunk size for a job within current governor limits.

### Formula (per dimension)

```
chunk = ((available - base) × safety / perItem) + 1
```

- `available` = remaining capacity from `LimitService.getAvailableLimits()`
- `base` = learned fixed overhead from `JobDescription__c`
- `perItem` = learned marginal cost per item (falls back to `base` if unknown)
- `safety` = learned safety factor [0.5–0.98]
- `+1` because `base` covers item #1

### Multi-Dimension Constraint

The calculator iterates all 18 dimensions and takes the **minimum** chunk size across all dimensions with a known `base > 0`. Early exit if any dimension yields `≤ 1`.

### Hard Limits Applied After Model Calculation

1. `MaxChunkSizeLimit__c` — Absolute upper cap (default 50).
2. `SmallestFailingChunk__c - 1` — Stays below the smallest previously-failing chunk size.

### Bootstrap Probe

When `MaxChunkSize__c == -1` (unknown), `JobCandidate` bypasses the calculator entirely and returns `chunkSize = 1`. This single-item probe establishes the initial `base` measurement. Only after `chunkSize > 1` runs does `perItem` get learned.

---

## Consumption Learning Algorithm

`AdaptiveConsumptionLearner` updates the `JobDescription__c` consumption model after each execution.

### Safety Boundaries

```
SAFETY_STEP                   = 0.05  (±5% per execution)
MIN_SAFETY                    = 0.5   (floor)
MAX_SAFETY                    = 0.98  (ceiling)
KILL_PENALTY                  = 1.1   (10% inflation on KILL)
DEFAULT_LEARNING_RATE         = 0.30  (EWMA α — weight of latest observation)
DEFAULT_VARIATION_RESET_COUNT = 3     (consecutive variations before reset)
DEFAULT_KILL_COOLDOWN_COUNT   = 3     (consecutive successes before EWMA resumes after a kill/failure)
```

### On Success

1. Reset `ConsecutiveFailures = 0`, increment `SuccessStreak`, clear `SmallestFailingChunk = 0`.
2. Ratchet up `MaxChunkSize = min(max(current, chunkSize), MaxChunkSizeLimit)`.
3. Increase safety by `+SAFETY_STEP` (capped at 0.98).
4. Per dimension:
   - If the current learned value is unknown (sentinel `0`) → **cold start**: set it directly to the observed value.
   - Else, compute the variation relative to current:
     - If above `VariationResetThreshold__c` → it is **not** assimilated; `ConsecutiveVariationCount__c` increments. A full model reset fires only when the counter reaches `VariationResetCount__c` (default `3`). Any normal (within-threshold) observation resets the counter to `0`, so transient noise no longer wipes the model.
     - Otherwise (within threshold), **assimilate** depending on the post-failure cooldown window:
       - If `SuccessStreak__c < KillCooldownCount__c` → **cooldown active**: `Math.max(current, observed)` — keeps the just-inflated post-kill ceiling sticky so a single recovery chunk cannot blend it back down; this defeats the pre-remediation scenario where EWMA eroded kill penalties after 2–3 observations and re-invited the same kill.
       - Else → **EWMA blend**: `newValue = α·observed + (1−α)·current`, where α = `LearningRate__c` (default `0.30`). Smoothly absorbs small variations instead of permanently latching outliers like the old pure `max()` approach did.
   - For `chunkSize == 1`, the routing lands on `base`; for `chunkSize > 1`, on `perItem` (computed as `(observed − base) / (chunkSize − 1)`).

### On Failure

1. Increment `ConsecutiveFailures`, reset `SuccessStreak = 0`.
2. Record `SmallestFailingChunk = min(current, chunkSize)`.
3. Decrease safety by `-SAFETY_STEP`.
4. If safety drops below `MIN_SAFETY (0.5)` → **full model reset**.

### On Kill (governor limit crash, no consumed limits available)

Two paths:
- **Reset**: If `ConsecutiveFailures >= MaxExecutionAttempt` → wipe all model fields to unknown sentinels (including `ConsecutiveVariationCount__c = 0`).
- **Inflate**: For each dimension, lower safety by `SAFETY_STEP` AND multiply `base` and `perItem` by `KILL_PENALTY (1.1)`. If safety would drop below 0.5 → reset instead.

### State Transition Summary

```
SUCCESS → safety↑, base/perItem EWMA-blended toward observation,
          MaxChunkSize ratcheted up
          observations outside VariationResetThreshold increment a counter;
          reset only after VariationResetCount consecutive hits

FAILURE → safety↓, SmallestFailingChunk updated
          reset if safety < 0.5

KILL    → safety↓, base×1.1, perItem×1.1
          full reset if consecutive failures exceed max attempts
          full reset if safety < 0.5
```

---

## Governor Limit Tracking

`LimitsUsage` is the central data structure — a `Map<String, Integer>` with typed property accessors and a `dimensions()` static method returning the canonical ordered list.

Three distinct usages:

| Context | Each dimension contains | Source |
|---|---|---|
| Available limits | `Limits.getLimitX() - Limits.getX()` (with 3% buffer on CPU/heap) | `LimitService.getAvailableLimits()` |
| Start/stop delta | `consumed_at_stop - consumed_at_start` | `LimitService.stopSnapshot()` |
| Stored model | Learned base/perItem/safety decimal values | `JobDescription__c` fields |

The dual-access design (named properties + string key via `get(dimension)`) lets algorithms iterate all dimensions generically without switch statements:
```apex
for (ConsumptionModel model : ConsumptionModel.asList()) {
    Integer consumed = limitsUsage.get(model.dimension);
    // ... generic processing
}
```

---

## Malformed Argument Handling

`JobRequest__c.Argument__c` is user-supplied JSON. A single malformed value must not fail the entire chunk or unjustly penalize the consumption model — the fault belongs to the row, not the processor.

### Parser

`JobRequestArgumentParser.parse(jobRequests)` returns a `ParseResult`:

```apex
public class ParseResult {
  public List<Object> validArguments;        // parsed values for processor
  public Map<Id, String> malformedErrors;    // jobRequestId → parser error message
}
```

Each request is tried independently in a `try/catch` around `JSON.deserializeUntyped`; any exception (`JSONException` or otherwise) is captured and the request routed to `malformedErrors`. Blank `Argument__c` is valid-as-null (preserves the pre-existing convention).

### Executor short-circuit

`JobExecutable.executeChunk()`:

1. Calls the parser.
2. If **every** request is malformed (`validArguments.isEmpty() && !malformedErrors.isEmpty()`) → builds an `ApexJobResult(MALFORMED_ARGUMENT)` without calling the processor. Also attaches `malformedRequestErrors = parseResult.malformedErrors` to the result.
3. Otherwise → calls the processor with only the valid arguments. Processor-thrown exceptions still convert to `FAILURE` as before. Malformed-request errors are still attached to the result for downstream staging.

### Per-request staging

`JobExecuted.stageJobRequestExecution(jobRequest)` branches before the usual retry/success logic:

- If `jobRequest.Id` appears in `malformedRequestErrors` → `Status__c = MALFORMED_ARGUMENT`, `LastExecutionMessage__c = <parser error>`, `NextExecutionDateTime__c = null`, `AttemptNumber__c++`. **Terminal — no retry.** Timing metrics are skipped because the processor never touched this request.
- Otherwise → the existing state machine runs (`calculateTimingMetrics`, `determineNextStatus`).

### Consumption-learning skip

`JobExecuted.stageJobDescriptionExecution()` still runs `updateRateLimitCounter()` (a malformed-spam flood is bounded by the per-minute rate limit like any other burst). But when the chunk-level status is `MALFORMED_ARGUMENT`, the method **returns before invoking the `ConsumptionLearner`** — no processor ran, so the observed limits don't describe meaningful work and shouldn't be blended into `base`/`perItem`.

---

## Monitoring UI

### Component Architecture

```
┌─ Async_Job_Monitor (Lightning App) ──────────────────────────────┐
│  ┌─ Job_Monitor_Console (FlexiPage) ───────────────────────────┐ │
│  │  ┌─ jobMonitorConsole (LWC container) ────────────────────┐ │ │
│  │  │  ┌─ engineControls ──┐  ┌─ statusByProcessorTable ──┐ │ │ │
│  │  │  │  Toggle ON/OFF    │  │  Aggregate by processor    │ │ │ │
│  │  │  │  Watcher status   │  │  Status, count, metrics    │ │ │ │
│  │  │  │  Executor count   │  │  5s polling                │ │ │ │
│  │  │  │  Restart button   │  └────────────────────────────┘ │ │ │
│  │  │  │  500ms polling    │                                  │ │ │
│  │  │  └──────────────────-┘                                  │ │ │
│  │  │  ┌─ requestTable (full width) ────────────────────────┐ │ │ │
│  │  │  │  Paginated job request list, infinite scroll       │ │ │ │
│  │  │  │  Status color-coding, timing metrics               │ │ │ │
│  │  │  │  2s polling with diff-and-replace                  │ │ │ │
│  │  │  └────────────────────────────────────────────────────┘ │ │ │
│  │  └────────────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

**`engineControls`** — Polls at 500ms for engine status, executor count, and watcher status. Provides pause/resume/restart actions gated by `Manage_Async_Job_Engine` custom permission (client-side check + server-side `assertPerm()`).

**`statusByProcessorTable`** — Polls at 5s. Aggregate `GROUP BY Status__c, JobDescription__c` with a second cacheable call for processor name resolution.

**`requestTable`** — Polls at 2s. Paginated with infinite scroll (page size 50). Diff-and-replace strategy: only refreshes the first page and compares IDs before triggering a full update. Row styling encodes status (red=FAILURE, darker red=KILLED, green=SUCCESS, striped=not candidate).

**`jobDescriptionResetConsumption`** — Headless LWC quick action on `JobDescription__c` record pages. Delegates to `JobDescriptionActionsController.resetConsumptionModel()`.

### Apex Controller

`JobMonitorController` (`with sharing`) provides all backend methods. Read methods respect sharing; mutation methods (`pauseEngine`, `resumeEngine`, `restartEngine`) additionally require the `Manage_Async_Job_Engine` custom permission, enforced via `FeatureManagement.checkPermission`.

---

## Operator Scripts

Anonymous-Apex scripts under `scripts/apex/` (outside every `sfdx-project.json` packageDirectory — never deployed to orgs):

| Script | Purpose | Run |
|---|---|---|
| `scripts/apex/restart-watcher.apex` | Aborts every existing `Async Job Watcher` cron trigger and calls `ApexJobWatcher.schedule()` to re-register the 12 slots. Use when the scheduler drifts or after renaming classes involved. | `sf apex run -f scripts/apex/restart-watcher.apex -o <org-alias>` |

---

## Security Model

### Custom Permissions

| Permission | Purpose |
|---|---|
| `Manage_Async_Job_Engine` | Controls pause/resume/restart actions. Enforced client-side (LWC) and server-side (`assertPerm`). |
| `Bypass_JobRequest_Trigger` | Suppresses auto-enqueue on `JobRequest__c` insert. For bulk data loads. |

### Permission Set: AdminAsyncJob

Full CRUD + ModifyAll + ViewAll on `JobDescription__c` and `JobRequest__c`. Read/write on all custom fields. Includes `Manage_Async_Job_Engine`.

### Sharing Model

- All adapters: `without sharing` — engine runs in system context, not user context.
- `JobMonitorController`: `with sharing` — monitoring respects user access.
- `JobDescriptionActionsController`: `with sharing` + `WITH SECURITY_ENFORCED`.

---

## Extensibility

### Adding a New Job Processor

Implement the `ApexJob` interface:

```apex
public class MyProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
        // Process context.getArguments()
        return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
}
```

Create a `JobDescription__c` record with `ProcessorName__c = 'MyProcessor'`. Create `JobRequest__c` records to enqueue work.

### Adding a New Governor Limit Dimension

1. Add a constant to `LimitsUsage.ALL_DIMENSIONS` and a property.
2. Add three fields to `JobDescription__c` following the naming convention: `{Dimension}BaseConsumption__c`, `{Dimension}PerItemConsumption__c`, `{Dimension}Safety__c`.
3. Add the `Limits.get*()` calls to `LimitServiceImpl`.
4. Add the WHERE clause to `JobSelectorImpl`.

Zero changes needed in `AdaptiveChunkCalculator`, `AdaptiveConsumptionLearner`, or `ConsumptionModel` — they iterate `LimitsUsage.dimensions()` dynamically.

---

## Key Design Decisions

### Self-Finalizer Pattern

`AsyncApexJobExecutor` implements both `Queueable` and `Finalizer`. Salesforce preserves the entire object heap across this boundary, allowing instance state (`lastExecutableJob`, `jobExecutionResults`) to flow without external storage. This eliminates the need for a staging object or platform cache.

### allOrNone: false in the Finalizer

The Finalizer is the last opportunity to persist results. Using `allOrNone: false` ensures partial success — one bad record does not block persisting all other results.

### Two-Transaction Architecture

The Queueable runs user code; the Finalizer persists results and re-enqueues. This separation is necessary because DML after a callout-containing transaction can fail, and governor limits reset between phases.

### Bootstrap Single-Item Probe

When `MaxChunkSize__c == -1`, the system runs exactly 1 item. This establishes the `base` measurement. Only after `chunkSize > 1` runs does `perItem` get learned. This cold-start strategy ensures the system never over-commits on an unknown workload.

### Safety Factor as a Learned Throttle

The safety coefficient is not static — it is actively tuned. Success streaks push it toward 0.98 (using nearly all capacity). Failures push it toward 0.5. A KILL event penalizes both consumption estimates (×1.1) and safety (−5%), making the system very conservative after crashes.

### SmallestFailingChunk as a Hard Ceiling

Once any chunk of size N fails, `SmallestFailingChunk = N` and the calculator enforces `chunk ≤ N - 1`. This prevents retrying a chunk size that has already proven too large, independent of the safety factor math. Resets to 0 on success.

### Variation Reset Threshold with N-of-N Counter

If an observation diverges from the learned model by more than `VariationResetThreshold__c` (default 30%) the sample is **not** blended in — instead `ConsecutiveVariationCount__c` increments. The model is reset only once the counter reaches `VariationResetCount__c` (default 3). A single outlier (cold cache, one-off cascade) is tolerated and can no longer wipe the model; sustained workload drift still triggers a reset and re-enables the bootstrap probe. Any within-threshold observation clears the counter.

### Post-Kill `Math.max` Cooldown

EWMA is symmetric — within-threshold observations blend both up and down. After a `KILL`, `inflateConsumptionModel` multiplies `base` and `perItem` by `KILL_PENALTY = 1.1`. Without a safeguard, the next successful chunk (which typically consumes less than the inflated value) would blend the inflation 30 % of the way back down and re-enable aggressive chunk sizes — exactly the regression the 2026-04-20 Scenario A run surfaced (three clustered kills early, then a nine-item kill mid-run).

The cooldown: while `SuccessStreak__c < KillCooldownCount__c` (default `3`), the within-threshold assimilation uses `Math.max(current, observed)` instead of EWMA blending. The kill penalty sticks for `N` successful chunks, proving the smaller chunk size is actually safe, before the model is allowed to relax. On the `N`-th success, the streak ≥ `N` and EWMA resumes.

The cooldown reuses the existing `SuccessStreak__c` field — no new state. Side effects: the same window also follows any non-kill `FAILURE` (which also resets `SuccessStreak__c = 0`), making learning slightly more conservative post-failure — a deliberate feature. A brand-new `JobDescription__c` at cold start also spends its first `N` successes in Math.max semantics, naturally matching the conservative bootstrap posture; the `currentBase == 0` branch still short-circuits to a direct assignment on observation #1.

### Static Singleton DI

All factory instances are static — one per Apex transaction. This is essential because `LimitServiceImpl.totalCalloutTimeConsumedInMs` is a static accumulator that must be shared across all snapshot cycles. The trade-off: tests must use constructor injection to avoid cross-test pollution.

### DuplicateSignature on Enqueue

Prevents the race condition where two Finalizers fire simultaneously and double-enqueue. Only one succeeds; the other catches `DuplicateMessageException` silently.

### Callout Guard in Selector

If DML has occurred in the current transaction, the selector sets `maxCallout = 0`, excluding all callout-making jobs. This enforces Salesforce's "Uncommitted Work Pending" constraint at the query level rather than at runtime.

### Trigger-Based Auto-Wake

The `JobRequestAfterInsert` trigger immediately enqueues the executor when new requests are inserted, providing low-latency job pickup. The `Bypass_JobRequest_Trigger` custom permission suppresses this during bulk data operations.

---

## Directory Structure

```
apex-job/
├── src/
│   ├── admin/
│   │   ├── customPermissions/
│   │   │   ├── Bypass_JobRequest_Trigger.customPermission-meta.xml
│   │   │   └── Manage_Async_Job_Engine.customPermission-meta.xml
│   │   └── permissionsets/
│   │       └── AdminAsyncJob.permissionset-meta.xml
│   ├── engine/
│   │   ├── adapter/
│   │   │   └── classes/       (JobSelectorImpl, JobRepositoryImpl, ApexJobWatcher, ...)
│   │   ├── application/
│   │   │   └── classes/       (ApexJobManager, AsyncApexJobExecutor)
│   │   ├── domain/
│   │   │   ├── classes/       (ApexJob, JobCandidate, JobExecutable, JobExecuted, ...)
│   │   │   │   ├── chunk-calculation/     (AdaptiveChunkCalculator)
│   │   │   │   └── consumption-learning/  (AdaptiveConsumptionLearner)
│   │   │   ├── lwc/           (jobDescriptionResetConsumption)
│   │   │   ├── objects/       (JobDescription__c, JobRequest__c, ApexJobConfig__c)
│   │   │   ├── triggers/      (JobRequestAfterInsert)
│   │   │   ├── layouts/
│   │   │   └── quickActions/  (JobDescription__c.Reset)
│   │   └── service/
│   │       └── classes/       (ApexJobFactory, LimitService, ApexJobTransactionContext, ...)
│   └── monitor/
│       ├── applications/      (Async_Job_Monitor)
│       ├── classes/adapter/   (JobMonitorController)
│       ├── flexipages/        (Job_Monitor_Console)
│       └── lwc/               (jobMonitorConsole, engineControls, statusByProcessorTable, requestTable)
└── test/
    ├── unit/                  (16 test classes + helpers)
    ├── integration/           (3 test classes)
    └── functional/            (6 test classes + test data)
```
