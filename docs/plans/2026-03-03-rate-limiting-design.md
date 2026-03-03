# Rate Limiting per JobDescription — Design

Limit the number of times a `JobDescription__c` can be executed per minute, counted as individual `JobRequest__c` records processed.

## Behavior

- When the rate limit is hit, the executor **skips** the `JobDescription__c` and moves on to other jobs.
- No forced delay — the rate-limited description becomes eligible again when the 1-minute window expires.
- Chunk size is capped to the remaining budget within the window.
- `MaxExecutionsPerMinute__c = 0` or null means no rate limit.

## Data Model

Three new fields on `JobDescription__c`:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `MaxExecutionsPerMinute__c` | Number(18,0) | `0` | Configuration: max requests processed per minute. 0/null = no limit. |
| `ExecutionsInCurrentWindow__c` | Number(18,0) | `0` | State: counter of requests processed in the current window. |
| `CurrentWindowStart__c` | DateTime | null | State: start of the current rate limit window. |

## IsCandidate__c Formula

Add one new AND clause to the existing formula on `JobRequest__c`:

```
,OR(
  ISNULL(JobDescription__r.MaxExecutionsPerMinute__c),
  JobDescription__r.MaxExecutionsPerMinute__c = 0,
  ISNULL(JobDescription__r.CurrentWindowStart__c),
  (NOW() - JobDescription__r.CurrentWindowStart__c) * 1440 >= 1,
  JobDescription__r.ExecutionsInCurrentWindow__c < JobDescription__r.MaxExecutionsPerMinute__c
)
```

Rate-limited descriptions are excluded at SOQL level — no wasted query rows.

## Chunk Capping — AdaptiveChunkCalculator

Add rate limit remaining budget as one more `Math.min` in the existing hard-cap chain inside `getMaxPossible()`:

```
chunk = calculateFromModel(job, available)       // governor-limit model
chunk = min(chunk, MaxChunkSizeLimit)             // user-defined cap
chunk = min(chunk, SmallestFailingChunk - 1)      // failure-based cap
chunk = min(chunk, remainingRateBudget(job))      // rate-limit cap  ← NEW
```

`remainingRateBudget(job)` returns:
- `DEFAULT_MAX_CHUNK_SIZE` when `MaxExecutionsPerMinute` is 0/null (no-op on `Math.min`).
- `MaxExecutionsPerMinute` (full budget) when no window is active or window expired (> 1 minute).
- `MaxExecutionsPerMinute - ExecutionsInCurrentWindow` when window is active.

No changes to `JobCandidate`. All chunk constraints resolved in one place, one uniform pattern.

## Counter Update — JobExecuted

In `JobExecuted.stageJobDescriptionExecution()`, after updating `LastExecutionDateTime__c`:

```
IF CurrentWindowStart__c is null OR (now - CurrentWindowStart__c) >= 1 minute:
    CurrentWindowStart__c = now
    ExecutionsInCurrentWindow__c = chunkSize
ELSE:
    ExecutionsInCurrentWindow__c += chunkSize
```

Updated on the in-memory `JobDescription__c` SObject already being modified. Persisted by the existing `Database.update(records, allOrNone=false)` in `JobRepositoryImpl`.

Edge case: if the update fails due to `allOrNone=false`, the counter may be stale, allowing slightly more executions than the limit. Same failure mode as the existing consumption model fields.

## Reset Behavior — ApexJobManager

`resetConsumptionModel()` resets the two state fields alongside existing consumption model fields:
- `ExecutionsInCurrentWindow__c = 0`
- `CurrentWindowStart__c = null`

`MaxExecutionsPerMinute__c` is configuration — not reset.

## Builder API — ApexJobManager

`JobDescriptionBuilder` gains one new method:

```apex
ApexJobManager.define()
    .processor('MyProcessor')
    .maxExecutionsPerMinute(100)
    .save();
```

## Monitoring — statusByProcessorTable

Two new columns in the `statusByProcessorTable` LWC:

| Column | Source |
|---|---|
| Rate Limit | `MaxExecutionsPerMinute__c` |
| Executions/min | `ExecutionsInCurrentWindow__c` |

`JobMonitorController.getJobDescriptionInfos()` query adds the 3 new fields.

## Permissions — AdminAsyncJob

Add read/write field permissions for all three new fields.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| `JobDescription__c` | `objects/JobDescription__c/fields/` | 3 new field metadata files |
| `IsCandidate__c` | `objects/JobRequest__c/fields/IsCandidate__c.field-meta.xml` | 1 new AND clause in formula |
| `AdaptiveChunkCalculator` | `domain/classes/chunk-calculation/AdaptiveChunkCalculator.cls` | `remainingRateBudget` method + 1 `Math.min` |
| `JobExecuted` | `domain/classes/JobExecuted.cls` | Counter update in `stageJobDescriptionExecution` |
| `ApexJobManager` | `application/ApexJobManager.cls` | Reset 2 state fields + builder method |
| `AdminAsyncJob` | `admin/permissionsets/AdminAsyncJob.permissionset-meta.xml` | 3 new field permissions |
| `JobMonitorController` | `monitor/classes/adapter/JobMonitorController.cls` | Add fields to `getJobDescriptionInfos` query |
| `statusByProcessorTable` | `monitor/lwc/statusByProcessorTable/` | 2 new columns |
