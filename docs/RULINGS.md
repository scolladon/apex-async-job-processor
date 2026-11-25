# Rulings

What is settled, what was refused, for which paths. One line per ruling, append-only; the
decisions phase writes them, `rulings-lint` checks them. Why a ruling was made is not stored:
infer it from `DOCTRINE.md` and the code.

- R-001 [apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml] AdminAsyncJob grants the Job_Monitor_Console tab as Visible through tabSettings. Refused: leave the tab ungranted · tabSettings plus applicationVisibilities.
- R-002 [apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml, apex-job/src/engine/domain/triggers/**] NextExecutionDateTime__c carries a NOW() field default and no trigger stamps it, so an insert that leaves it unset is due at once while an explicit null or an update gets no date. Refused: before-save trigger stamping null dates · field default plus a delegating before-save trigger · builder-only stamping.
- R-003 [scripts/apex/backfill-next-execution.apex] Installed orgs backfill runnable null-dated requests with an operator script that sets NextExecutionDateTime__c to CreatedDate, 10,000 rows per run, re-run until it reports 0. Refused: release note only.
- R-004 [apex-job/src/engine/domain/classes/JobExecuted.cls] JobExecuted drops the CreatedDate fallback and takes NextExecutionDateTime__c alone as the timing base. Refused: keep the fallback and select CreatedDate · fall back to the selection time.
- R-005 [apex-job/src/engine/application/AsyncApexJobExecutor.cls] After a failed recording the finalizer re-enqueues with the idle delay from getEnqueueDelayInMinutes, never with 0. Refused: a new fixed delay constant · no re-enqueue, leave it to the watcher.
- R-006 [apex-job/src/engine/domain/customindex/**] The NextExecutionDateTime__c custom index sets allowNullValues to true. Refused: allowNullValues false.
- R-007 [apex-job/src/engine/domain/objects/JobRequest__c/fields/IsCandidate__c.field-meta.xml, DESIGN.md] IsCandidate__c loses its ISNULL(NextExecutionDateTime__c) branch so a null date means not scheduled, and DESIGN.md states it. Refused: keep the branch and document that the selector excludes null-dated rows.
- R-008 [apex-job/src/monitor/classes/adapter/JobMonitorController.cls] getJobRequestPage adds NextExecutionDateTime__c <= now and drops ALL ROWS with its IsDeleted sort key. Refused: add the filter and keep ALL ROWS · leave the query as is.
- R-009 [apex-job/src/engine/service/ApexJobTransactionContext.cls, apex-job/src/engine/adapter/JobExecutorSpawner.cls, apex-job/src/engine/adapter/JobExecutorQueueableSpawner.cls, apex-job/src/engine/domain/triggers/JobRequestAfterInsert.trigger] The once-per-transaction wake-up flag lives in ApexJobTransactionContext, its guard sits in a new JobExecutorSpawner.wakeUp called only by the insert trigger, and every enqueue checks for a free queueable slot first. Refused: the guard inside enqueue · a static flag in the spawner.
- R-010 [apex-job/src/engine/adapter/JobRepositoryImpl.cls] JobIds__c keeps the last 20 AsyncApexJob ids. Refused: 10 ids · 50 ids.
- R-011 [apex-job/src/engine/domain/classes/ConsumptionModel.cls] Learner noise floors are named constants: cpuTime 5 ms, heapSize 4,096 B, calloutTime 5 ms, every counter dimension 1. Refused: a calloutTime floor of 1 · defer the values to a measured run.
