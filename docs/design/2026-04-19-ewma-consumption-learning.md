# EWMA consumption learning — Design

`AdaptiveConsumptionLearner` absorbs every observed governor-limit usage via
`Math.max(current, observed)` in both `adjustBaseConsumptionModel` (line 53–57)
and `adjustPerItemConsumptionModel` (line 70). A single anomalous observation
— a cold buffer cache, an unusually long trigger cascade, a retried callout —
permanently raises the learned value and there is no path back down short of
a full `resetConsumptionModel()` nuke.

In production, this means the learned base drifts strictly upward over time.
`AdaptiveChunkCalculator` then computes a tighter `usable = availableLimit -
base`, producing smaller chunks, and throughput collapses. The only way to
recover months of valid learning is to blow it away.

Two independent problems hide in the current code:

1. **Math.max absorption** with no averaging — any spike is a permanent spike.
2. **Reset triggered on a single observation** of `variation > VariationResetThreshold__c`
   (line 65) — noisy inputs cause premature resets, which are too aggressive
   a remediation for a single outlier.

This change adds exponentially-weighted moving average (EWMA) smoothing for
normal observations, and an N-of-N consecutive-variation counter before reset
fires.

## Behavior

- **Cold start unchanged.** If the learned value is `UNKNOWN_BASE_CONSUMPTION`
  (0), the first observation sets it directly. Same as today.
- **Normal observations** (variation within `VariationResetThreshold__c`) are
  blended into the learned value via EWMA:
  `new = α · observed + (1 − α) · current`, with `α` read from the new
  `LearningRate__c` field. Values move smoothly, both up and down.
- **Extreme observations** (variation above threshold) are *not* applied to
  the learned value. Instead they increment a new
  `ConsecutiveVariationCount__c` counter.
- **Reset** fires only when `ConsecutiveVariationCount__c` reaches
  `VariationResetCount__c` (default 3). A single spike no longer wipes the
  model.
- **Variation streak break.** Any normal observation resets the counter to 0,
  so the model recovers quickly from transient noise.
- **No hard cap on observation ratio** is introduced — the variation gate
  already serves that role. Observations within the threshold are safe to
  assimilate at full EWMA weight; observations above it are never assimilated.

## Data Model

Three new fields on `JobDescription__c`:

| Field | Type | Default | Purpose |
|---|---|---|---|
| `LearningRate__c` | Number(3,2) | `0.30` | EWMA α; weight given to the latest observation. Lower = smoother, slower adaptation. Higher = more reactive, more noise. 0 < α ≤ 1. |
| `ConsecutiveVariationCount__c` | Number(4,0) | `0` | State: how many consecutive observations exceeded `VariationResetThreshold__c`. Managed by the engine; reset to 0 whenever a normal observation lands or a full reset fires. |
| `VariationResetCount__c` | Number(2,0) | `3` | Configuration: how many consecutive variations trigger a full `resetConsumptionModel`. |

`LearningRate__c` and `VariationResetCount__c` are configuration — not reset
by `resetConsumptionModel`. `ConsecutiveVariationCount__c` is state — zeroed
by reset.

## Algorithm / Logic

### `adjustBaseConsumptionModel(usage, model)` (called when chunkSize == 1)

```
currentBase = job.get(model.base)

// Cold start
if currentBase <= UNKNOWN_BASE_CONSUMPTION:
  job.put(model.base, usage)
  job.ConsecutiveVariationCount__c = 0
  return false

variation = abs(usage - currentBase) / currentBase
if variation > job.VariationResetThreshold__c:
  // Extreme — don't assimilate
  job.ConsecutiveVariationCount__c = (job.ConsecutiveVariationCount__c ?? 0) + 1
  resetCount = job.VariationResetCount__c ?? DEFAULT_VARIATION_RESET_COUNT
  if job.ConsecutiveVariationCount__c >= resetCount:
    return true   // reset requested
  return false

// Normal — apply EWMA. Fall back to DEFAULT_LEARNING_RATE if the field is null
// on a legacy record (non-breaking upgrade).
alpha = job.LearningRate__c ?? DEFAULT_LEARNING_RATE
blended = alpha * usage + (1 - alpha) * currentBase
job.put(model.base, blended)
job.ConsecutiveVariationCount__c = 0
return false
```

### `adjustPerItemConsumptionModel(usage, model, chunkSize)` (called when chunkSize > 1)

```
currentPerItem = job.get(model.perItem)
newPerItem = (usage - job.get(model.base)) / (chunkSize - 1)   // unchanged

// Cold start
if currentPerItem <= UNKNOWN_PERITEM_CONSUMPTION:
  job.put(model.perItem, newPerItem)
  job.ConsecutiveVariationCount__c = 0
  return false

variation = abs(newPerItem - currentPerItem) / currentPerItem
if variation > job.VariationResetThreshold__c:
  job.ConsecutiveVariationCount__c = (job.ConsecutiveVariationCount__c ?? 0) + 1
  resetCount = job.VariationResetCount__c ?? DEFAULT_VARIATION_RESET_COUNT
  if job.ConsecutiveVariationCount__c >= resetCount:
    return true
  return false

alpha = job.LearningRate__c ?? DEFAULT_LEARNING_RATE
blended = alpha * newPerItem + (1 - alpha) * currentPerItem
job.put(model.perItem, blended)
job.ConsecutiveVariationCount__c = 0
return false
```

### Reset

`resetConsumptionModel()` (unchanged except it also clears
`ConsecutiveVariationCount__c = 0`).

### Interaction with `adjustSafetyModel`

`adjustSafetyModel` is untouched. Safety factor (multiplicative guard) lives
on a different axis and its step-up / step-down logic is orthogonal to base
and per-item averaging.

### Interaction with `inflateConsumptionModel` (on kill, no reset)

`inflateConsumptionModel` multiplies base and perItem by `KILL_PENALTY = 1.1`.
This is a deliberate pessimistic bump on kill events and should **not** run
through EWMA — a kill is a correctness signal, not a normal observation.
Left unchanged.

## Touchpoint Summary

| Component | File | Change |
|---|---|---|
| New field: learning rate | `apex-job/src/engine/domain/objects/JobDescription__c/fields/LearningRate__c.field-meta.xml` | Create — `Number(3,2)`, default `0.30`. |
| New field: variation count | `apex-job/src/engine/domain/objects/JobDescription__c/fields/ConsecutiveVariationCount__c.field-meta.xml` | Create — `Number(4,0)`, default `0`. |
| New field: reset threshold count | `apex-job/src/engine/domain/objects/JobDescription__c/fields/VariationResetCount__c.field-meta.xml` | Create — `Number(2,0)`, default `3`. |
| Learner | `apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls` | Replace `Math.max`-based updates in `adjustBaseConsumptionModel` and `adjustPerItemConsumptionModel` with the EWMA-plus-variation-gate form above. Add `ConsecutiveVariationCount__c` reset in `resetConsumptionModel`. |
| Selector | `apex-job/src/engine/adapter/JobSelectorImpl.cls` | Add the three new fields to the `SELECT` `JobDescription__r.*` clause so the SObject passed into the learner has them populated. |
| Test fixture | `apex-job/test/unit/classes/ApexJobTestFixture.cls` | Add `withLearningRate`, `withConsecutiveVariationCount`, `withVariationResetCount` builder methods. Set sensible defaults in the `JobDescriptionBuilder` constructor. |
| Learner tests | `apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls` | Add coverage: cold-start, EWMA blend, variation gate (single), variation gate (N consecutive → reset), streak break. Plus a convergence scenario test (N=5 steps reach target). |
| Admin perm set | N/A | Out of scope for this batch. A follow-up PR must grant read/write on the three new fields to any admin persona that needs to see or tune them. |

## Edge cases

- **`LearningRate__c` is null (field newly added, legacy records):** the
  selector populates `null`; the learner must fall back to a safe default.
  Use `ApexJobConstant.DEFAULT_LEARNING_RATE = 0.30` inline via `??`.
- **`VariationResetCount__c` is null or 0:** treat null/≤0 as "reset on the
  next variation" — i.e. preserve today's aggressive-reset behaviour so the
  upgrade is non-behaviour-breaking until the admin sets a positive value.
  Applied via `?? 1`.
- **Cold start with `UNKNOWN_BASE_CONSUMPTION = 0` but observed usage = 0:**
  sets value to 0. Next observation treats `currentBase <= 0` as still-cold
  and sets it. No divide-by-zero path.
- **Variation > threshold on first observation (`currentPerItem = 0`):** not
  reachable because the cold-start branch triggers first (no `currentPerItem`
  to compare against).
- **Migration of existing orgs:** existing `JobDescription__c` records have
  populated `base`, `perItem`, `safety` — they keep those values. The first
  observation after deployment runs through the new algorithm; variation is
  computed against existing state. No backfill needed.

## Rollback

`git revert <commit-sha>` on the merge commit restores `Math.max`-only
assimilation. Existing orgs retain the three new fields on `JobDescription__c`
until a separate metadata-delete PR removes them — harmless because the
revert leaves the fields unreferenced.

## Open questions

- **Is `0.30` the right default α?** Matches common EWMA-for-operational-
  metrics guidance (0.2–0.3 for slow-drift signals), but the real validation
  comes from the convergence scenario in `AdaptiveConsumptionLearnerTest`
  and from the functional-test throughput metric. If the functional suite
  regresses, we tune via `LearningRate__c` on the per-description record
  rather than rebuilding the algorithm.
- **Per-dimension counter, or global?** This design uses a single global
  counter (`ConsecutiveVariationCount__c`) across all 18 dimensions —
  simpler, matches how `SuccessStreak__c` / `ConsecutiveFailures__c` work
  today, and avoids 18 × field-metadata bloat. If a specific dimension is
  known to be noisy independently, a follow-up can split.
- **Permission set updates** to grant admins read/write on the three new
  fields are explicitly out of scope for this batch.
