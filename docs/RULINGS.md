# Rulings

What is settled, what was refused, for which paths. One line per ruling, append-only; the
decisions phase writes them, `rulings-lint` checks them. Why a ruling was made is not stored:
infer it from `DOCTRINE.md` and the code.

- R-001 [apex-job/src/admin/permissionsets/AdminAsyncJob.permissionset-meta.xml] AdminAsyncJob grants the Job_Monitor_Console tab as Visible through tabSettings. Refused: leave the tab ungranted · tabSettings plus applicationVisibilities.
