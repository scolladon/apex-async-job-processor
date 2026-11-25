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
