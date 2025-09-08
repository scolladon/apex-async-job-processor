<div align="center">
  	<h1>Async Processor</h1>
  	<p>Performant job selection and execution utilities for Apex with governor limit safety.</p>
 </div>
 
 Build job processors that respect limits. The engine selects eligible jobs, sizes chunks, and runs them in Queueable. It learns after each run.

 - [Why](#why)
 - [Install](#install)
 - [Quick start](#quick-start)
 - [Developer API: Request and Job](#developer-api-request-and-job)
 - [Implementing ApexJob](#implementing-apexjob)
 - [Exploitation and monitoring](#exploitation-and-monitoring)
 - [Configuration](#configuration)
 - [Queueable runtime](#queueable-runtime)
 - [Algorithms](#algorithms)
   - [Learning](#learning)
   - [Chunking](#chunking)
   - [Selector (Jar of Rocks)](#selector-jar-of-rocks)
 - [Architecture](#architecture)

 ## Why

 - Simple. Extensible.
 - Governor-limit safe by design.
 - Testable via dependency injection.
 - Hexagonal architecture.

 ## Install

 Requires Node.js 18+, npm 9+, Salesforce CLI.

 ```bash
 npm install
 sf org create scratch -f config/project-scratch-def.json -a dev -d 1
 npm run build
 ```

 ## Quick start

 1) Implement your processor ([ApexJob](apex-job/src/domain/classes/ApexJob.cls)).

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

 File: [ApexJobManager](apex-job/src/application/ApexJobManager.cls)

 - Job Description builder: `define()` → chain `processor(String)`, `priority(Integer)`, `minInterval(Integer)`, `maxAttempts(Integer)`, `recurrent()`, `allowedOn(List<String>)`, `allowedBetween(Time, Time)`, then `save()`.
 - Manage descriptions: `enableJobDescription(Id|String)`, `disableJobDescription(Id|String)`, `resetConsumptionModel(String processorName)`.
 - Job Request builder: `request()` → chain `forDescription(Id)` or `forProcessor(String)`, `payload(Object)` or `payloadJson(String)`, `scheduleAt(Datetime)`, then `save()`.
 - Manage requests: `enableJobRequest(Id)`, `disableJobRequest(Id)`.

 Your Apex processor implements [ApexJob](apex-job/src/domain/classes/ApexJob.cls) and returns [ApexJobResult](apex-job/src/domain/classes/ApexJobResult.cls). Context arrives in `ApexJobContext.arguments`.

 ## Implementing ApexJob

 Contract (file: [ApexJob](apex-job/src/domain/classes/ApexJob.cls)):

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
 - At runtime, the engine deserializes each `JobRequest__c.Argument__c` into `ApexJobContext.arguments` (see `JobExecutable.getArgument(...)`).
 - A chunk may contain several arguments. Make your work idempotent.

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
 - The Queueable finalizer detects unhandled kills and appends a synthetic result with status `KILLED` (file: [AsyncApexJobExecutor](apex-job/src/application/AsyncApexJobExecutor.cls)).
 - Results are recorded and the engine re-enqueues promptly.
 - The learner then adapts (penalizes consumption and/or resets) so next chunks run smaller and safer (files: `JobExecuted.stageJobDescriptionExecution()`, `AdaptativeConsumptionLearner`).

 ## Exploitation and monitoring

 File: [ApexJobWatcher](apex-job/src/adapter/ApexJobWatcher.cls)

 - `ApexJobWatcher.schedule()` registers 12 Scheduled Apex jobs (every 5 minutes). Idempotent.
 - Each tick checks config. If enabled, it enqueues `AsyncApexJobExecutor` with a computed delay.
 - Monitor via `AsyncApexJob`, `JobRequest__c` fields (`Status__c`, `LastExecutionDateTime__c`, `LastExecutionMessage__c`, `AttemptNumber__c`, `NextExecutionDateTime__c`), and `JobDescription__c.LastExecutionDateTime__c`.

 ## Configuration

 Files:
 - [ApexJobConfig](apex-job/src/domain/objects/ApexJobConfig__c/*)
 - [ApexJobConfigServiceImpl](apex-job/src/adapter/ApexJobConfigServiceImpl.cls)

 Global switches (Hierarchy Custom Setting `ApexJobConfig__c`):
 - `Enabled__c` (Checkbox). Turns the engine on/off.
 - `EnqueueDelayOutsideBusinessHours__c` (0..10). Minutes to wait when outside Business Hours. Default idle delay is 1 minute. Values are clamped to [0,10].

 Candidate rules (`JobRequest__c.IsCandidat__c`):
 - `JobRequest__c.Enabled__c` and `JobDescription__c.Enabled__c` must be true.
 - Status in READY, FAILURE, KILLED.
 - Time window and days respected (`AllowedDays__c`, `AllowedStartTime__c`, `AllowedEndTime__c`).
 - Attempts below `MaxExecutionAttempt__c` (or -1 for unlimited).

 Tip: The learner updates consumption fields on `JobDescription__c`. You rarely set them by hand.

 ## Queueable runtime

 File: [AsyncApexJobExecutor](apex-job/src/application/AsyncApexJobExecutor.cls)

 - Queueable + Finalizer.
 - Loop: fetch candidates → pick first executable → execute chunk → collect results.
 - Finalizer: records results, then re-enqueues.
   - If this run did work: re-enqueue with 0 minutes.
   - If idle: use configured delay.

 ## Algorithms

 ### Learning

 File: [AdaptativeConsumptionLearner](apex-job/src/domain/classes/consumption-learning/AdaptativeConsumptionLearner.cls)

 - Tracks `Base`, `PerItem`, `Safety` per dimension from `ConsumptionModel.asList()` (internally cached).
 - Success: safety +0.05 (capped at 0.98), reset failure count, increment success streak, raise `MaxChunkSize__c` up to `MaxChunkSizeLimit__c`.
 - Failure: safety -0.05, track `ConsecutiveFailures__c` and `SmallestFailingChunk__c`.
 - Kill: penalize `Base` and `PerItem` by 1.1, lower safety. Reset if failures reach configured max.
 - Reset when per-item variation exceeds `VariationResetThreashold__c` or safety would drop below 0.5.
 - Per-item update applies when chunk size > 1; when chunk size == 1, update base only.
 - Safety range: [0.5 .. 0.98].

 ### Chunking

 File: [AdaptiveChunkCalculator](apex-job/src/domain/classes/chunk-calculation/AdaptiveChunkCalculator.cls)

 - For each dimension with known base:
   - `usable = availableLimit - base`
   - If usable > 0: `chunk = (usable * safety / perItem) + 1`
 - Take the minimum across dimensions.
 - Apply caps: `MaxChunkSizeLimit__c`, `SmallestFailingChunk__c - 1`.
 - Unknown `MaxChunkSize__c` yields chunk = 1 to bootstrap.

 ### Selector (Jar of Rocks)

 Files: [JobSelectorImpl](apex-job/src/adapter/JobSelectorImpl.cls), `apex-job/src/domain/objects/JobRequest__c/fields/IsCandidat__c.field-meta.xml`

 - Database pre-filter on base consumption and candidacy rules. Only eligible rows reach Apex.
 - Extra callout guard avoids "Uncommitted work pending".
 - Order to pack the jar well:
   - Priority desc → important jobs first.
   - MaxChunkSize asc → smaller chunks first (fill the gaps).
   - Lower callout base first, then oldest.

 ## Architecture

 Hexagonal design.

 - Domain: [ApexJob](apex-job/src/domain/classes/ApexJob.cls), [ApexJobContext](apex-job/src/domain/classes/ApexJobContext.cls), [ApexJobResult](apex-job/src/domain/classes/ApexJobResult.cls), [JobCandidate](apex-job/src/domain/classes/JobCandidate.cls), [AdaptativeConsumptionLearner](apex-job/src/domain/classes/consumption-learning/AdaptativeConsumptionLearner.cls), [AdaptiveChunkCalculator](apex-job/src/domain/classes/chunk-calculation/AdaptiveChunkCalculator.cls).
 - Application: [AsyncApexJobExecutor](apex-job/src/application/AsyncApexJobExecutor.cls), [ApexJobManager](apex-job/src/application/ApexJobManager.cls).
 - Adapters: [JobSelectorImpl](apex-job/src/adapter/JobSelectorImpl.cls), [JobRepositoryImpl](apex-job/src/adapter/JobRepositoryImpl.cls), [ApexJobWatcher](apex-job/src/adapter/ApexJobWatcher.cls), [ApexJobConfigServiceImpl](apex-job/src/adapter/ApexJobConfigServiceImpl.cls), [ApexJobLogger](apex-job/src/adapter/ApexJobLogger.cls), [ApexJobSpawner](apex-job/src/adapter/ApexJobSpawner.cls), [ApexJobFinalizer](apex-job/src/adapter/ApexJobFinalizer.cls), [ApexJobLimitService](apex-job/src/adapter/ApexJobLimitService.cls).

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
   class ApexJobLogger
   class ApexJobSpawner
   class ApexJobFinalizer
   class ApexJobLimitService
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
