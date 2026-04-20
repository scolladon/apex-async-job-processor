# Safe argument deserialization — Design

`JobExecutable.executeChunk()` builds an `ApexJobContext` by calling
`JSON.deserializeUntyped(job.Argument__c)` for every `JobRequest__c` in the
chunk (via `getArgument`, line 59). There is no try/catch around the parse,
so **one malformed `Argument__c` value fails the whole chunk**:

- Every other valid request in the chunk is marked `FAILURE`, retried,
  penalized in the consumption-learning model.
- The `JobDescription__c`'s consumption base is inflated as if the processor
  itself misbehaved, even though the fault is user data.
- Subsequent `getEligibleJobs` queries may under-sized the chunk because the
  learned base grew unjustly.

We also have a standing TODO on this method (`JobExecutable.cls:58`:
`// TODO Part of the JobRequest__c domain`), acknowledging it should live
outside `JobExecutable`. This change addresses both: extracts parsing into a
dedicated class with typed error handling, and re-routes malformed requests
so they don't contaminate the consumption model.

## Behavior

- A `JobRequest__c` whose `Argument__c` cannot be parsed by
  `JSON.deserializeUntyped` is marked `Status__c = 'MALFORMED_ARGUMENT'`,
  the error message is written to `LastExecutionMessage__c`, and
  `NextExecutionDateTime__c` is set to `null`. It is *not* retried (the
  data is user-supplied and won't fix itself).
- Other requests in the same chunk that parse successfully are passed to
  the processor as usual.
- If **every** request in a chunk is malformed, the processor is **not
  called**, and the chunk's consumption model is **not** adjusted — no
  SUCCESS increment, no FAILURE decrement, no KILL inflation. The learner
  skips the chunk entirely.
- If **some** requests are malformed and the rest succeed (processor
  returns `SUCCESS`), the consumption learner still runs with the observed
  limits — these are valid observations for the *valid* portion of the
  chunk. The learner is unaware of the malformed-request exclusions.

## Data Model

No new SObject fields. One new enum value.

| Artifact | Location | Change |
|---|---|---|
| `MALFORMED_ARGUMENT` enum constant | `ApexJobStatus` (Apex enum) | Append — does not affect existing picklist on `JobRequest__c.Status__c` until a follow-up PR adds the picklist value. See Open Questions. |

**On `JobRequest__c.Status__c`:** this is a picklist value-set on the custom
object. Adding a new status in the Apex enum lets the code refer to it, but
the in-org picklist must also include `MALFORMED_ARGUMENT` before Apex can
write it to the SObject without validation failure. The plan doc therefore
adds the picklist value in the same PR.

## Algorithm / Logic

New flow in `JobExecutable.executeChunk`:

```apex
parseResults = parser.parse(this.jobRequests)
  // { validArguments: [...], malformedErrors: Map<Id, String> }

if parseResults.validArguments is empty and parseResults.malformedErrors not empty:
  // All malformed — skip the processor
  apexJobResult = new ApexJobResult(ApexJobStatus.MALFORMED_ARGUMENT)
else:
  startLimitsSnapshot()
  try:
    apexJobResult = processor.execute(new ApexJobContext(parseResults.validArguments))
  catch Exception e:
    apexJobResult = new ApexJobResult(e)   // FAILURE — existing behavior
  apexJobResult.consumedLimits = stopLimitsSnapshot()

apexJobResult.malformedRequestErrors = parseResults.malformedErrors   // always attached, even when empty
return new JobExecuted(factory, this, apexJobResult)
```

In `JobExecuted.stageJobRequestExecution(job)`, add a malformed-request branch
ahead of the existing retry/success/abort routing:

```apex
if jobExecutionResult.malformedRequestErrors contains job.Id:
  job.Status__c = ApexJobStatus.MALFORMED_ARGUMENT.name()
  job.LastExecutionMessage__c = jobExecutionResult.malformedRequestErrors.get(job.Id)
  job.NextExecutionDateTime__c = null
  job.AttemptNumber__c = (job.AttemptNumber__c ?? 0) + 1
  job.LastSelectionDateTime__c = stagingInfo.selectionTime
  job.LastExecutionDateTime__c = stagingInfo.endTime
  return   // skip timing metrics (processor never ran for this request)

// existing path: calculateTimingMetrics + determineNextStatus
```

In `JobExecuted.stageJobDescriptionExecution`, the rate-limit counter update
still runs first (a malformed-spam burst is bounded by the per-minute rate
limit just like any other burst), and the consumption-learner call is the
only step gated by the all-malformed early return:

```apex
jobDescription.LastExecutionDateTime__c = stagingInfo.endTime
updateRateLimitCounter()                   // still runs — counts the attempted chunk
if jobExecutionResult.status == ApexJobStatus.MALFORMED_ARGUMENT:
  return                                   // no processor ran, no limits deserve learning
// existing routing: FAILURE / SUCCESS / KILLED → adjustFromFailure / adjustFromSuccess / adjustFromKill
```

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| Argument parser class | `apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls` | **Create** — `parse(List<JobRequest__c>)` returns a `ParseResult` inner class carrying `validArguments` (`List<Object>`) and `malformedErrors` (`Map<Id, String>`). Inner class `MalformedArgumentException` wraps JSON errors. |
| Parser metadata | `apex-job/src/engine/domain/classes/JobRequestArgumentParser.cls-meta.xml` | **Create** — api version 65.0. |
| Parser test | `apex-job/test/unit/classes/JobRequestArgumentParserTest.cls` + meta | **Create** — given valid/null/malformed/mixed `Argument__c`, when parse, then result fields match. |
| Status enum | `apex-job/src/engine/domain/classes/ApexJobStatus.cls` | Add `MALFORMED_ARGUMENT` constant. |
| Status picklist | `apex-job/src/engine/domain/objects/JobRequest__c/fields/Status__c.field-meta.xml` | Add `MALFORMED_ARGUMENT` to the picklist value set. |
| Result payload | `apex-job/src/engine/domain/classes/ApexJobResult.cls` | Add `public Map<Id, String> malformedRequestErrors { get; set; }`. Default null. |
| Factory port | `apex-job/src/engine/service/ApexJobFactory.cls` | Add `JobRequestArgumentParser getArgumentParser();` method to the interface. |
| Factory impl | `apex-job/src/engine/service/ApexJobFactoryImpl.cls` | Implement `getArgumentParser()` with lazy-initialized static singleton matching the pattern of the other getters. |
| Executable | `apex-job/src/engine/domain/classes/JobExecutable.cls` | Remove `getContextArguments` (line 47) and `getArgument` (line 59). Use factory-provided parser in `executeChunk`. Short-circuit processor call for all-malformed chunks. Attach `malformedRequestErrors` to the result. |
| Executable test | `apex-job/test/unit/classes/JobExecutableTest.cls` | Add tests: mixed chunk, all-malformed chunk, processor-exception with mixed. |
| Execution staging | `apex-job/src/engine/domain/classes/JobExecuted.cls` | Per-request malformed branch in `stageJobRequestExecution`. All-malformed early return in `stageJobDescriptionExecution`. |
| Execution staging test | `apex-job/test/unit/classes/JobExecutedTest.cls` | Given mixed chunk, then malformed requests tagged terminal; given all-malformed chunk, then consumption learner not invoked. |
| Admin perm set | N/A | No change — the permission set is out of scope for this batch per CLAUDE-confirmed scope. Note in PR: the permset does **not** currently grant read on `JobRequest__c.Status__c`, so any downstream persona consuming the new picklist value must be addressed in a separate follow-up if needed. |

## Edge cases

- **Empty `Argument__c`:** returns `null` as valid (same as today); not
  marked malformed.
- **Whitespace-only `Argument__c`:** today this is blank → returns null.
  Parser preserves that semantic (uses `String.isNotBlank`).
- **`JSON.deserializeUntyped` throws a non-`JSONException` subtype:** the
  parser's try/catch wraps *any* `Exception` into `MalformedArgumentException`
  to be conservative.
- **Processor throws after receiving the validArguments list:** unchanged —
  `ApexJobResult` becomes `FAILURE` with the processor's exception, just as
  today. Malformed request entries are still tagged terminal; their status
  does not depend on whether the valid portion succeeded.
- **All requests in chunk are valid:** parser still runs (one map-allocation
  overhead per request, negligible CPU); `malformedRequestErrors` is an empty
  map; existing flow is unchanged.
- **One request malformed, processor succeeds, learner runs:** the consumed
  limits reflect processing `validArguments.size()` items. This can slightly
  understate the per-item base (the learner thinks fewer items produced the
  same usage) — acceptable, and no worse than today where a pre-parse
  deserialize failure would have killed the whole chunk.
- **Chunk size of 1, that one is malformed:** routes through the
  all-malformed path; learner skipped; the single `JobRequest__c` marked
  `MALFORMED_ARGUMENT`. No retry, no metric inflation.

## Rollback

Multi-commit branch, squash-merge recommended. `git revert` of the merge
commit restores: in-line parsing in `JobExecutable`, no `MALFORMED_ARGUMENT`
status, no parser class. `JobRequest__c` records that were already written
with `Status__c = 'MALFORMED_ARGUMENT'` need manual cleanup (one-off SOQL +
DML) if the picklist value is also reverted — the plan doc flags this.

## Open questions

- **Should the admin perm set grant read on `Status__c` for the new value?**
  Perm sets are out of scope for this batch. Filed as a follow-up item.

## Notes for reviewers (not open questions — decisions already made)

- **Picklist metadata ships with the enum change in the same PR.** Because
  `JobRequest__c.Status__c` is a value-set picklist owned by this package,
  the new value is packaged; subscriber orgs upgrade atomically with the
  rest of the feature. This is deliberate, not an open choice.
