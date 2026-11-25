# Rulings

What is settled, what was refused, for which paths. One line per ruling, append-only; the
decisions phase writes them, `rulings-lint` checks them. Why a ruling was made is not stored:
infer it from `DOCTRINE.md` and the code.

- R-001 [apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml] AdminAsyncJob grants the Job_Monitor_Console tab as Visible through tabSettings. Refused: leave the tab ungranted · tabSettings plus applicationVisibilities.
- R-002 [apex-job/src/engine/domain/objects/JobRequest__c/fields/NextExecutionDateTime__c.field-meta.xml, apex-job/src/engine/domain/triggers/**] NextExecutionDateTime__c carries a NOW() field default and no trigger stamps it, so an insert that leaves it unset is due at once while an explicit null or an update gets no date. Refused: before-save trigger stamping null dates · field default plus a delegating before-save trigger · builder-only stamping.
