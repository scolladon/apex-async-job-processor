<div align="center">
  	<h1>Async Processor</h1>
  	<p>Performant job selection and execution utilities for Apex with governor limit safety.</p>
 </div>
 
 Build job processors that respect limits. The engine selects eligible jobs, sizes chunks, and runs them in Queueable. It learns after each run.

 - [Why](#why)
   - [The four walls you hit](#the-four-walls-you-hit)
   - [How Async Processor stays under every limit](#how-async-processor-stays-under-every-limit)
 - [Install](#install)
 - [Quick start](#quick-start)
 - [Developer API: Request and Job](#developer-api-request-and-job)
 - [Implementing ApexJob](#implementing-apexjob)
 - [Exploitation and monitoring](#exploitation-and-monitoring)
 - [Monitoring console](#monitoring-console)
 - [Configuration](#configuration)
 - [Queueable runtime](#queueable-runtime)
 - [Algorithms](#algorithms)
   - [Learning](#learning)
   - [Chunking](#chunking)
   - [Selector (Jar of Rocks)](#selector-jar-of-rocks)
 - [Architecture](#architecture)

## Why

Queueable looks free. It isn't. The platform meters async at four levels you can't see from Apex, and the obvious design — _one `System.enqueueJob` per record_ — trips every one of them. Salesforce says it plainly in its own [Asynchronous Processing decision guide][async]: async patterns have **"no SLA"**, are **"subject to multiple governor mechanisms,"** and **"can cause processing delays due to the finite nature of the resources allocated to asynchronous infrastructure."** The platform **"doesn't scale infinitely."**

Async Processor inverts the pattern: **one self-chaining executor drains a backlog you own, sizing each chunk to the limits it has measured.** One slot, never a swarm.

- Simple. Extensible.
- Governor-limit safe by design.
- Testable via dependency injection.
- Hexagonal architecture.

### The four walls you hit

A single routine bulk operation can hit all four — and none of them is visible from Apex until you're already over.

**1 · The 24-hour async ceiling.** Batch + `@future` + Queueable + Scheduled all draw from **one budget — 250,000 executions or `user licenses × 200` per rolling 24 h, whichever is greater** ([limits][gov]). One Queueable per record lets a single bulk job spend six figures of that budget in minutes. When it trips, _every_ async feature in the org starts throwing `AsyncApexExecutions Limit exceeded` — and you usually learn about it hours later, from a [proactive alert][alert], org-wide.

**2 · A finite pool of worker threads — with no dial to turn.** Async handlers run on **"a finite number of worker threads on each application server,"** and the **"fair usage algorithm controls the number of threads that an org has available for each message type"** ([guide][async]) — a small per-org share, with no setting to raise it. Fan out chained Queueables and you saturate _your own_ share. No exception is thrown; jobs simply sit `Queued`. `AsyncApexJob` shows you rows, never a reason.

**3 · Queue-depth caps.** You can enqueue at most **50 Queueables per transaction**, chain only **1** from inside a running job, and the **Apex Flex Queue holds 100** jobs before it rejects new ones ([flex queue][flex]). A burst overflows it instantly: `You've exceeded the limit of 100 jobs in the flex queue`.

**4 · Flow control & fair usage — the silent one.** Before adding work to a message type's queue, the platform **checks the first several thousand entries; if most belong to your org and you already hold worker threads, your new entries are moved to the back of the queue — a process it calls _re-enqueuing_** ([fundamentals][fund]). Keep flooding and the fair-usage algorithm **cuts the threads allocated to your org** ([guide][async]). The blast radius isn't local — your runaway Queueable delays _unrelated_ async: Bulk API loads, Platform Event delivery, integration callbacks, nightly batch. The symptom (integrations gone slow) sits nowhere near the cause (a fire-and-forget Queueable someone shipped last week). Almost nobody connects the two.

None of it is observable from the platform — `AsyncApexJob` reports _status_, never _consumption_. You hit the wall before you knew it was there.

```text
NAIVE — one Queueable per record
────────────────────────────────────────────────────────────────────
  bulk load 10k rows
        │  System.enqueueJob × 10,000   (burst)
        ▼
  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓  platform queue ──▶ overflow at 100 holding
        │                                  flow control ──▶ shoved to back
        ▼                                  fair usage   ──▶ your threads cut
  ┌──────────────────────────────┐    24h cap ──▶ 250k executions drained
  │ your fair share of threads    │
  │ ░░░░░░░  SATURATED  ░░░░░░░░  │ ──▶ Platform Events   delayed
  └──────────────────────────────┘ ──▶ Bulk API async    delayed
                                     ──▶ @future / batch   starved

ASYNC PROCESSOR — one executor treats them all
────────────────────────────────────────────────────────────────────
  JobRequest__c backlog  (your table, priority-ordered)
        │
        ▼  System.enqueueJob × 1
  ┌──────────────────────────────┐  ◀─┐
  │ AsyncApexJobExecutor          │   │ re-enqueue (self-chain)
  │ select ▸ size chunk ▸ execute │   │
  │ ▸ record ▸ repeat             │ ──┘
  └──────────────────────────────┘
        │  idle? back off 1–10 min  (off-hours aware)
        ▼
  ┌──────────────────────────────┐
  │ your fair share of threads    │
  │ ▏ one steady slot ▏           │ ──▶ Platform Events   clear
  └──────────────────────────────┘ ──▶ Bulk API async    clear
                                     ──▶ @future / batch   clear
  Watcher ── every 5 min ── restarts the chain only if it dies
```

### How Async Processor stays under every limit

| Wall | How fast you hit it | What Async Processor does |
|---|---|---|
| **250k execs / 24 h** | One bulk job, one Queueable per record | Runs **many requests per execution** via learned chunking; **idle back-off** + a 5-min watchdog instead of busy-spin keep the execution count near-flat — [`AsyncApexJobExecutor`][f1], [`ApexJobConfigServiceImpl`][f5] |
| **Finite per-org threads** | A swarm of chained Queueables | **Exactly one executor at a time** — `DuplicateSignature` on enqueue + a running-executor guard — so you never hold more than one scarce slot — [`JobExecutorQueueableSpawner`][f2], [`JobExecutorServiceImpl`][f3] |
| **Flex / queue depth 100** | A burst of enqueues | The backlog lives in **your `JobRequest__c` table**, drained in priority order by one queueable — the platform queue never sees the burst — [`JobSelectorImpl`][f4] |
| **Flow control / fair usage** | Flooding any message type | One entry in the queue at a time never trips the "first several thousand entries" re-enqueuing check — **the async lane stays clear for your integrations** |

Same backlog, drained by one disciplined executor instead of a swarm — plus a learned, per-processor consumption model and a [monitoring console](#monitoring-console) so you can finally _see_ what each job costs.

[gov]: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm
[async]: https://architect.salesforce.com/decision-guides/async-processing
[fund]: https://architect.salesforce.com/docs/architect/fundamentals/guide/async-fundamentals
[flex]: https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_flex_queue.htm
[alert]: https://help.salesforce.com/s/articleView?id=000382490&type=1
[f1]: apex-job/src/engine/application/AsyncApexJobExecutor.cls
[f2]: apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls
[f3]: apex-job/src/engine/service/JobExecutorServiceImpl.cls
[f4]: apex-job/src/engine/adapter/JobSelectorImpl.cls
[f5]: apex-job/src/engine/adapter/ApexJobConfigServiceImpl.cls

 ## Install

 Requires Node.js 18+, npm 9+, Salesforce CLI.

 ```bash
 npm install
 sf org create scratch -f config/project-scratch-def.json -a dev -d 1
 npm run build
 ```

 ## Quick start

 1) Implement your processor ([ApexJob](apex-job/src/engine/domain/classes/ApexJob.cls)).

 ```apex
 public with sharing class DataCleanupExecutor implements ApexJob {
   public ApexJobResult execute(ApexJobContext ctx) {
     // Use ctx.arguments
     return new ApexJobResult(ApexJobStatus.SUCCESS);
   }
 }
 ```

 2) Define a Job Description.

 ```apex
 Id jobDescriptionId = ApexJobManager.define()
   .processor('DataCleanupExecutor')
   .priority(100)
   .minInterval(10)
   .maxAttempts(-1) // unlimited retries
   .allowedOn(new List<String>{ '2','3','4','5','6' }) // Mon..Fri (2..6)
   .allowedBetween(Time.newInstance(9,0,0,0), Time.newInstance(17,0,0,0))
   .save().Id;
 ```

 3) Create Job Requests.

 ```apex
 ApexJobManager.request()
   .forDescription(jobDescriptionId)
   .payload(new Map<String,Object>{ 'startDate' => '2025-01-01' })
   .scheduleAt(Datetime.now())
   .save();

 ApexJobManager.request()
   .forProcessor('DataCleanupExecutor')
   .payloadJson('{"foo":"bar"}')
   .save();
 ```

 4) Start the engine (once per org).

 ```apex
 ApexJobWatcher.schedule();
 ```

 ## Developer API: Request and Job

 File: [ApexJobManager](apex-job/src/engine/application/ApexJobManager.cls)

 - Job Description builder: `define()` → chain `processor(String)`, `priority(Integer)`, `minInterval(Integer)`, `maxAttempts(Integer)`, `recurrent()`, `allowedOn(List<String>)`, `allowedBetween(Time, Time)`, then `save()`.
 - Manage descriptions: `enableJobDescription(Id|String)`, `disableJobDescription(Id|String)`, `resetConsumptionModel(String processorName)`.
 - Job Request builder: `request()` → chain `forDescription(Id)` or `forProcessor(String)`, `payload(Object)` or `payloadJson(String)`, `scheduleAt(Datetime)`, then `save()`.
 - Manage requests: `enableJobRequest(Id)`, `disableJobRequest(Id)`.

 Your Apex processor implements [ApexJob](apex-job/src/engine/domain/classes/ApexJob.cls) and returns [ApexJobResult](apex-job/src/engine/domain/classes/ApexJobResult.cls). Context arrives in `ApexJobContext.arguments`.

 ## Implementing ApexJob

 Contract (file: [ApexJob](apex-job/src/engine/domain/classes/ApexJob.cls)):

 ```apex
 public interface ApexJob {
   ApexJobResult execute(ApexJobContext apexJobContext);
 }
 ```

 - Input: `ApexJobContext.arguments` is a `List<Object>`. One entry per `JobRequest__c` in the chunk.
 - Output: return one `ApexJobResult` for the whole chunk.

 Input patterns
  
 - Primitive payload (see [ApexJobFunctionalBaseTest](apex-job/test/functional/classes/ApexJobFunctionalBaseTest.cls)):

 ```apex
 public ApexJobResult execute(final ApexJobContext ctx) {
   final List<Datetime> when = new List<Datetime>();
   for (final Object raw : ctx.arguments) {
     final String json = '' + raw;
     when.add((Datetime) JSON.deserialize(json, Datetime.class));
   }
   return new ApexJobResult(ApexJobStatus.SUCCESS);
 }
 ```

 - Typed DTO (recommended):

 ```apex
 public class JobArgs { public String recordId; public Integer batchSize; }

 public ApexJobResult execute(final ApexJobContext ctx) {
   try {
     for (final Object raw : ctx.arguments) {
       final String json = JSON.serialize(raw); // Or `'' + raw;` if you are sure the toString() method is not overriden  
       final JobArgs args = (JobArgs) JSON.deserialize(json, JobArgs.class);
       // use args.recordId, args.batchSize
     }
     return new ApexJobResult(ApexJobStatus.SUCCESS);
   } catch (final Exception e) {
     return new ApexJobResult(e);
   }
 }
 ```

 - Dynamic map:

 ```apex
 public ApexJobResult execute(final ApexJobContext ctx) {
   for (final Object raw : ctx.arguments) {
     final Map<String, Object> args = (Map<String, Object>) raw;
     final String recordId = (String) args.get('recordId');
     final Integer batchSize = (Integer) args.get('batchSize');
   }
   return new ApexJobResult(ApexJobStatus.SUCCESS);
 }
 ```

 Notes
 - Payload is set via `ApexJobManager.request().payload(...)` or `.payloadJson(...)`.
 - At runtime, `JobRequestArgumentParser` deserializes each `JobRequest__c.Argument__c` into `ApexJobContext.arguments` before your processor runs.
 - A chunk may contain several arguments. Make your work idempotent.

Malformed arguments
 - If `Argument__c` cannot be parsed by `JSON.deserializeUntyped`, the request is marked `Status__c = MALFORMED_ARGUMENT` and is **not** retried (the data is user-supplied and won't fix itself).
 - Other valid requests in the same chunk run normally; your processor receives only the valid arguments.
 - If *every* request in a chunk is malformed, the processor is **not called** and the consumption learner is skipped (no unjust penalty on the model).

 Returning results
  
 - Success:

 ```apex
 return new ApexJobResult(ApexJobStatus.SUCCESS);
 ```

 - Business failure without exception:

 ```apex
 return new ApexJobResult(
   ApexJobStatus.FAILURE,
   new ApexJobResult.ApexJobError('Validation failed', null)
 );
 ```

 - Unexpected exception:

 ```apex
 try { /* work */ }
 catch (final Exception e) { return new ApexJobResult(e); }
 ```

 Kill handling (hard transaction aborts)
 - You never return `KILLED` yourself.
 - The Queueable finalizer detects unhandled kills and appends a synthetic result with status `KILLED` (file: [AsyncApexJobExecutor](apex-job/src/engine/application/AsyncApexJobExecutor.cls)).
 - Results are recorded and the engine re-enqueues promptly.
 - The learner then adapts (penalizes consumption and/or resets) so next chunks run smaller and safer (files: `JobExecuted.stageJobDescriptionExecution()`, `AdaptiveConsumptionLearner`).

 ## Exploitation

File: [ApexJobWatcher](apex-job/src/engine/adapter/ApexJobWatcher.cls)

- `ApexJobWatcher.schedule()` registers 12 Scheduled Apex jobs (every 5 minutes). Idempotent.
- Each tick checks config. If enabled, it enqueues `AsyncApexJobExecutor` with a computed delay.
- Monitor via `AsyncApexJob`, `JobRequest__c` fields (`Status__c`, `LastExecutionDateTime__c`, `LastExecutionMessage__c`, `AttemptNumber__c`, `NextExecutionDateTime__c`), and `JobDescription__c.LastExecutionDateTime__c`.
- Bypass `JobRequest__c` after insert trigger via the `Bypass_JobRequest_Trigger` custom permission.

## Monitoring console

UI: Lightning App "Async Job Monitor" with App Page "Job Monitor Console".

Monitoring is possible at all because the backlog lives in _your_ data, not the opaque platform queue:

```text
 NAIVE — backlog in the platform queue   │  ENGINE — backlog in YOUR table
   ├ capped (100 holding)                │    ├ unbounded JobRequest__c rows
   ├ opaque: AsyncApexJob = status only  │    ├ queryable: status, attempts,
   └ no priority, no cost visibility     │    │  next-run, timing, learned cost
                                         │    └ priority-ordered + LWC console
```

- **Access**
  - App Launcher → Async Job Monitor → Job Monitor Console.
  - Deploys with metadata: `applications/Async_Job_Monitor.app-meta.xml` and `flexipages/Job_Monitor_Console.flexipage-meta.xml`.

- **Permission required for controls**
  - Custom Permission: `Manage_Async_Job_Engine` (Included in the `AdminAsyncJob` permission set).
  - Without it, nothing displays.

- **Controls** (calls `JobMonitorController`)
  - Pause engine → sets `ApexJobConfig__c.Enabled__c = false`.
  - Resume engine → sets `ApexJobConfig__c.Enabled__c = true`.
  - Restart executor → enqueues a new `AsyncApexJobExecutor` now.
  - Guard rails: live counts from `AsyncApexJob` for executors and the scheduled watcher.

- **Tables and status**
  - Status by processor: grouped counts by `Status__c`, max chunk metrics, attempts, next/last execution.
  - Requests: live candidate queue ordered by priority, chunk size, callout base, and dates.
  - Engine state: enabled flag, active executors, recovery scheduler alive.

 ## Configuration

 Files:
 - [ApexJobConfig](apex-job/src/engine/domain/objects/ApexJobConfig__c/*)
 - [ApexJobConfigServiceImpl](apex-job/src/engine/adapter/ApexJobConfigServiceImpl.cls)

 Global switches (Hierarchy Custom Setting `ApexJobConfig__c`):
 - `Enabled__c` (Checkbox). Turns the engine on/off.
 - `EnqueueDelayOutsideBusinessHours__c` (0..10). Minutes to wait when outside Business Hours. Default idle delay is 1 minute. Values are clamped to [0,10].

 Candidate rules (`JobRequest__c.IsCandidate__c`):
 - `JobRequest__c.Enabled__c` and `JobDescription__c.Enabled__c` must be true.
 - Status in READY, FAILURE, KILLED. (Terminal statuses — `SUCCESS`, `ABORTED`, `MALFORMED_ARGUMENT` — are never re-selected.)
 - Time window and days respected (`AllowedDays__c`, `AllowedStartTime__c`, `AllowedEndTime__c`).
 - Attempts below `MaxExecutionAttempt__c` (or -1 for unlimited).

 Tip: The learner updates consumption fields on `JobDescription__c`. You rarely set them by hand.

 ## Queueable runtime

 File: [AsyncApexJobExecutor](apex-job/src/engine/application/AsyncApexJobExecutor.cls)

```text
 new JobRequest__c ─(trigger)─┐        ┌─ ApexJobWatcher ─ every 5 min,
                              ▼        │   re-arms the chain only if it died
                          Spawner ◀────┘
                              │  enqueueJob ×1   (DuplicateSignature = no doubles)
                              ▼
 ╔════════════ QUEUEABLE transaction ═════════════╗
 ║  attach Finalizer                              ║
 ║  ┌─ loop ──────────────────────────────────┐  ║
 ║  │  select candidates   (priority-ordered)  │  ║
 ║  │  size chunk          (adaptive)          │  ║
 ║  │  execute   ◀── your ApexJob.execute()    │  ║
 ║  │  measure limits consumed                 │  ║
 ║  └── until no candidates OR limits exhausted┘  ║
 ╚═══════════════════════╤════════════════════════╝
                         ▼   limits reset at the boundary
 ╔════════════ FINALIZER transaction ═════════════╗
 ║  persist results  +  learn (update model)      ║
 ║  re-enqueue:  did work → now · idle → back off  ║
 ╚═══════════════════════╤════════════════════════╝
                         └──▶ next Queueable  (self-chain)
```

 - Queueable + Finalizer.
 - Loop: fetch candidates → pick first executable → execute chunk → collect results.
 - Finalizer: records results, then re-enqueues.
   - If this run did work: re-enqueue with 0 minutes.
   - If idle: use configured delay.

 ## Algorithms

 The engine is a closed control loop — every chunk it runs measures the limits it cost, and that measurement sizes the next one:

```text
   (1) SIZE  ──▶  (2) EXECUTE  ──▶  (3) MEASURE  ──▶  (4) LEARN
    ▲   chunk = min over 18 limits     actual limit      blend into
    │   (avail−base)·safety/perItem+1  usage this run    base/perItem/safety
    │                                                        │
    └──────────────  next chunk sized by what  ◀─────────────┘
                     this run just taught it
   SUCCESS → safety↑, chunk↑      FAILURE → safety↓, cap chunk
   KILL    → base/perItem ×1.1, safety↓  (back off hard)
```

 ### Learning

 File: [AdaptiveConsumptionLearner](apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls)

 - Tracks `Base`, `PerItem`, `Safety` per dimension from `ConsumptionModel.asList()` (internally cached).
 - Success: safety +0.05 (capped at 0.98), reset failure count, increment success streak, raise `MaxChunkSize__c` up to `MaxChunkSizeLimit__c`.
 - Failure: safety -0.05, track `ConsecutiveFailures__c` and `SmallestFailingChunk__c`.
 - Kill: penalize `Base` and `PerItem` by 1.1, lower safety. Reset if failures reach configured max.
 - Per-dimension base/per-item updates use an **EWMA blend** (`α·observed + (1−α)·current`, α = `LearningRate__c`, default 0.30) — smooth adaptation instead of a hard `max()` ratchet that outliers could stick permanently.
 - Observations whose variation exceeds `VariationResetThreshold__c` are not assimilated; instead `ConsecutiveVariationCount__c` increments. A full model reset fires only once the counter reaches `VariationResetCount__c` (default 3), so a single noisy sample can no longer wipe months of learning.
 - After a `KILL` or `FAILURE` (which zeroes `SuccessStreak__c`), the next `KillCooldownCount__c` successful chunks (default 3) still fall back to `Math.max` semantics so the post-kill `base × 1.1` / `perItem × 1.1` inflation stays sticky until the smaller chunk size is proven safe. Once the streak catches up, EWMA resumes.
 - Safety floor still triggers a reset (safety would drop below `MIN_SAFETY = 0.5`).
 - Per-item update applies when chunk size > 1; when chunk size == 1, update base only.
 - Safety range: [0.5 .. 0.98].

 ### Chunking

 File: [AdaptiveChunkCalculator](apex-job/src/engine/domain/classes/chunk-calculation/AdaptiveChunkCalculator.cls)

 - For each dimension with known base:
   - `usable = availableLimit - base`
   - If usable > 0: `chunk = (usable * safety / perItem) + 1`
 - Take the minimum across dimensions.
 - Apply caps: `MaxChunkSizeLimit__c`, `SmallestFailingChunk__c - 1`.
 - Unknown `MaxChunkSize__c` yields chunk = 1 to bootstrap.

 ### Selector (Jar of Rocks)

 Files: [JobSelectorImpl](apex-job/src/engine/adapter/JobSelectorImpl.cls), `apex-job/src/engine/domain/objects/JobRequest__c/fields/IsCandidate__c.field-meta.xml`

 - Database pre-filter on base consumption and candidacy rules. Only eligible rows reach Apex.
 - Extra callout guard avoids "Uncommitted work pending".
 - Order to pack the jar well:
   - Priority desc → important jobs first.
   - MaxChunkSize asc → smaller chunks first (fill the gaps).
   - Lower callout base first, then oldest.

 ## Architecture

 Hexagonal design.

 - Domain: [ApexJob](apex-job/src/engine/domain/classes/ApexJob.cls), [ApexJobContext](apex-job/src/engine/domain/classes/ApexJobContext.cls), [ApexJobResult](apex-job/src/engine/domain/classes/ApexJobResult.cls), [JobCandidate](apex-job/src/engine/domain/classes/JobCandidate.cls), [AdaptiveConsumptionLearner](apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls), [AdaptiveChunkCalculator](apex-job/src/engine/domain/classes/chunk-calculation/AdaptiveChunkCalculator.cls).
 - Application: [AsyncApexJobExecutor](apex-job/src/engine/application/AsyncApexJobExecutor.cls), [ApexJobManager](apex-job/src/engine/application/ApexJobManager.cls).
 - Adapters: [JobSelectorImpl](apex-job/src/engine/adapter/JobSelectorImpl.cls), [JobRepositoryImpl](apex-job/src/engine/adapter/JobRepositoryImpl.cls), [ApexJobWatcher](apex-job/src/engine/adapter/ApexJobWatcher.cls), [ApexJobConfigServiceImpl](apex-job/src/engine/adapter/ApexJobConfigServiceImpl.cls), [ApexJobLoggerImpl](apex-job/src/engine/adapter/ApexJobLoggerImpl.cls), [JobExecutorQueueableSpawner](apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls), [JobExecutorFinalizerAttacherImpl](apex-job/src/engine/adapter/JobExecutorFinalizerAttacherImpl.cls), [LimitServiceImpl](apex-job/src/engine/service/LimitServiceImpl.cls).

 ```plantuml
 @startuml
 title Async Processor (Hexagonal)

 package "Application" {
   class AsyncApexJobExecutor
   class ApexJobManager
 }

 package "Domain" {
   interface ApexJob
   class ApexJobContext
   class ApexJobResult
   class JobCandidate
 }

 package "Adapters" {
   class JobSelectorImpl
   class JobRepositoryImpl
   class ApexJobWatcher
   class ApexJobConfigServiceImpl
   class ApexJobLoggerImpl
   class JobExecutorQueueableSpawner
   class JobExecutorFinalizerAttacherImpl
   class LimitServiceImpl
 }

 AsyncApexJobExecutor --> JobRepositoryImpl : fetch/record
 AsyncApexJobExecutor --> JobSelectorImpl : select
 JobRepositoryImpl --> JobCandidate : build
 JobCandidate --> ApexJob : execute chunk
 ApexJobWatcher --> AsyncApexJobExecutor : enqueue
 ApexJobManager --> JobDescription__c : manage
 @enduml
 ```

  ## Authors
  
  - scolladon and contributors

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, coding standards, and testing guidance.

## License

MIT — see [LICENSE](LICENSE).
