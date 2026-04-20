# Prevent finalizer double-record — Design

**The bug in one line:** a single chunk can be persisted twice — once as
`SUCCESS` and once as `KILLED` — if the Queueable is terminated between the
successful `add()` of its result and the subsequent clear of
`lastExecutableJob`. The consumption learner then runs `adjustFromSuccess`
followed by `adjustFromKill` on the same `JobDescription__c`, corrupting the
model.

The rest of this section proves it.

`AsyncApexJobExecutor` tracks the chunk currently in flight in
`this.lastExecutableJob`. When the platform kills the Queueable mid-chunk, the
finalizer synthesizes a `KILLED` `ApexJobResult` for that pointer so the
consumption learner can penalize the right job.

The current control flow:

```apex
// execute(QueueableContext), inner loop
this.lastExecutableJob = jobCandidates[i].getExecutableChunk();      // (A) dispatch
...
final JobExecuted executionResult = this.lastExecutableJob.executeChunk();  // (B) work
this.jobExecutionResults.add(executionResult);                        // (C) record
this.lastExecutableJob = null;                                        // (D) clear
```

and the finalizer gate:

```apex
// wasLastChunkKilled()
return ctx?.getResult() == UNHANDLED_EXCEPTION && this.lastExecutableJob != null;
```

**The bug.** Between (C) and (D) is a window of one statement. If the platform
terminates the Queueable there — CPU-limit tick, heap exhaustion raised by a
subsequent `logger.debug` allocation, `LimitException` — the finalizer sees:

1. `jobExecutionResults` already containing the successful result **and**
2. `lastExecutableJob` still pointing to that same chunk.

It therefore appends a second `KILLED` result for the same chunk. Downstream,
`recordJobExecution` runs `JobExecuted.stageJobDescriptionExecution` twice on
the paired `JobDescription__c`: first `adjustFromSuccess` (streak ++), then
`adjustFromKill` (inflate / reset). The learned model ends corrupt. The
`JobRequest__c` records are persisted with success metrics (and deleted if
status = `SUCCESS`), so the user-visible outcome lies.

The window is tiny but real: `LimitException` can be raised at any statement
boundary, and `List.add` can exhaust heap on large `ApexJobResult` bodies
(embedded stack traces, 50–200 KB).

## Decision

Move the source of truth for "was this chunk recorded?" **into the list itself**.
Never clear `lastExecutableJob` on success — let its pointer linger. The finalizer
determines double-record risk by comparing the in-flight `JobExecutable` against
the last element of `jobExecutionResults`:

- list is empty → in-flight never made it in → record KILLED.
- list's last element's source `JobExecutable` IS `lastExecutableJob` → already
  recorded → do **not** double-record.
- list's last element's source `JobExecutable` is a different reference →
  in-flight chunk was not recorded → record KILLED.

This makes the predicate *idempotent by construction*: no matter where the
platform terminates the Queueable, the answer derives from list contents, not
from a flag that might be half-updated.

## Behavior

- Normal-exit finalizer: unchanged (ctx result is not `UNHANDLED_EXCEPTION`).
- Kill during `executeChunk`: `KILLED` result recorded for that chunk, as today.
- Kill between `.add()` and the (now-deleted) pointer clear: **no longer
  produces a duplicate** — list check short-circuits.
- Kill during `.add()` itself: list did not receive the element → last element
  is the previous chunk (or list empty) → `KILLED` recorded. As intended.

No behavior change for the consumption learner, the repository, or the
downstream persistence path. The fix is confined to two files.

## Data Model

None.

## Algorithm / Logic

New executor inner loop body:

```apex
this.lastExecutableJob = jobCandidates[i].getExecutableChunk();   // (A)
if (this.lastExecutableJob == null) break;
final JobExecuted executionResult = this.lastExecutableJob.executeChunk();  // (B)
this.jobExecutionResults.add(executionResult);                    // (C)
this.logger.debug('Job executed: ' + executionResult);
// (D) deleted — pointer is left as-is
```

New finalizer gate:

```apex
private Boolean wasLastChunkKilled(final FinalizerContext finalizerContext) {
  if (finalizerContext?.getResult() != ParentJobResult.UNHANDLED_EXCEPTION) return false;
  if (this.lastExecutableJob == null) return false;
  if (this.jobExecutionResults.isEmpty()) return true;
  final JobExecuted lastRecorded = this.jobExecutionResults[this.jobExecutionResults.size() - 1];
  // Reference inequality: Apex `!=` on non-SObject, non-primitive class references
  // checks identity. `true` here means the last recorded JobExecuted was produced
  // from a different JobExecutable than the one currently in flight → in-flight
  // was not recorded → synthesize KILLED.
  return lastRecorded.executable != this.lastExecutableJob;
}
```

`JobExecuted.executable` is a new public read-only field exposing the source
`JobExecutable` so the identity check is direct. `JobExecutable` does not
override `equals`, so Apex's default reference-equality semantics apply.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Finalizer gate + loop clear | `apex-job/src/engine/application/AsyncApexJobExecutor.cls` | Delete line 49 (`this.lastExecutableJob = null;`). Replace the body of `wasLastChunkKilled` with the list-consulting form above. |
| Source-executable exposure | `apex-job/src/engine/domain/classes/JobExecuted.cls` | Add `public final JobExecutable executable { get; private set; }` and assign it in the constructor from the `jobExecutable` argument. |
| Regression test | `apex-job/test/unit/classes/AsyncApexJobExecutorTest.cls` | Add three tests covering the three branches of the new predicate. Tests reuse the existing `KilledFinalizerContext` stub inner class rather than mocking the sealed `FinalizerContext` system type. |

## Edge cases

- **`getExecutableChunk` throws after assignment at (A):** the RHS is evaluated
  first in Apex; if it throws, the LHS is not written. Previous iteration's
  `lastExecutableJob` remains. That previous chunk was recorded in the list →
  `wasLastChunkKilled` returns false → no spurious KILLED. Correct.
- **First iteration, empty candidate list:** loop breaks without setting
  `lastExecutableJob`. Pointer stays `null`. Finalizer gate returns false.
- **`jobExecutionResults.add` throws:** list is unchanged; last element (if
  any) is the previous chunk; finalizer returns true → records KILLED for the
  in-flight chunk. Correct.
- **`executeChunk` catches a processor-level `Exception` internally** (already
  the case today, lines 24–28 of `JobExecutable.cls`): the returned
  `ApexJobResult` carries `FAILURE` status; `jobExecutionResults.add` proceeds
  normally; no change to this path.
- **Concurrent `AsyncApexJobExecutor` instances:** each runs in its own
  transaction with its own instance state; no shared mutable state between
  instances. Not a concern.

## Rollback

`git revert <commit-sha>` restores the previous clear-then-check pattern
(double-record window re-opens). Because `JobExecuted.executable` is only
referenced by the executor's finalizer, reverting does not break any other
consumer.

## Open questions

None. The list-as-source-of-truth approach was chosen over alternatives
(try/finally with flag restoration, per-chunk recorded-flag) because those
alternatives retain a similar write-ordering window that CPU-tick exceptions
can expose. The list contents are already atomic wrt platform kills (either the
element is in or it isn't — no half-state).
