# EWMA consumption learning — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace `Math.max`-based absorption in `AdaptiveConsumptionLearner` with exponentially-weighted moving average (EWMA) smoothing, and require `VariationResetCount__c` consecutive variations before triggering a reset.

**Architecture:** Three new fields on `JobDescription__c`; algorithm change confined to two methods on `AdaptiveConsumptionLearner`; SELECT update in `JobSelectorImpl`; fixture and test updates.

**Tech Stack:** Apex, SFDX metadata (3 number fields), Apex Mockery, `ApexJobTestFixture` builder.

**Target org:** all `sf` and `npm run` commands in this plan target the `dev-async-processor` scratch-org alias and **only** that alias. Export the alias as the session default before running any command below:

```bash
export SF_TARGET_ORG=dev-async-processor
```

Verify with `sf config get target-org` (or `echo $SF_TARGET_ORG`) before proceeding.

**Design doc:** [`../design/2026-04-19-ewma-consumption-learning.md`](../design/2026-04-19-ewma-consumption-learning.md)

**Branch:** `feat/ewma-consumption-learning` (from `main`).

**Preconditions:** none.

---

## PR description template

```
## Summary
Introduce EWMA smoothing and N-of-N variation gating in
`AdaptiveConsumptionLearner` so that single outlier observations no longer
permanently inflate the learned consumption model or trigger aggressive
resets.

## Motivation
Today `adjustBaseConsumptionModel` and `adjustPerItemConsumptionModel` use
`Math.max(current, observed)`, which turns any spike into a permanent ceiling.
`VariationResetThreshold__c` is checked on a single observation — one noisy
measurement can wipe months of learning. Together these produce a ratchet:
the learned base drifts strictly upward, chunks shrink, throughput collapses,
and the only recovery is a full manual reset.

## Changes
- Three new fields on `JobDescription__c`:
  `LearningRate__c` (α, default 0.30),
  `ConsecutiveVariationCount__c` (engine-managed counter, default 0),
  `VariationResetCount__c` (how many consecutive variations trigger reset,
  default 3).
- `JobSelectorImpl` SELECT adds the three new fields.
- `AdaptiveConsumptionLearner` rewritten for base + per-item:
  - cold start sets the value directly (unchanged),
  - normal observations blend via EWMA,
  - extreme observations (variation > threshold) are *not* assimilated;
    they increment the counter,
  - counter resets on any normal observation,
  - reset fires only when counter hits `VariationResetCount__c`.
- `resetConsumptionModel` also zeros the new counter.
- Fixture + tests updated.

## Test plan
Local gate (blocking before PR):
- [x] Learner tests cover cold-start, EWMA blend (up + down), variation
      gate, N-consecutive-variation → reset, streak break.
- [x] Convergence scenario: 5 observations at 2× current value approach
      target without resetting.
- [x] `npm run prettier`, `npm run lint`, `npm run test:unit` green.

Scratch-org gate (blocking before merge):
- [ ] `npm run test:integration` green.

Observability check (non-blocking; result recorded in the PR body at review time):
- [ ] Functional suite throughput did not regress — run
      `npm run test:functional:monitor-engine` before and after the deploy,
      compare metrics. If a regression is observed, tune `LearningRate__c`
      on affected records and record the new values in the PR body rather
      than reverting the change.

## Open question for reviewers
Default `LearningRate__c = 0.30`. If the functional suite shows a regression,
tune via the field on the affected `JobDescription__c` record rather than
changing the algorithm.
```

---

### Task 1: Create the three new `JobDescription__c` fields

**Files:**
- Create: `apex-job/src/engine/domain/objects/JobDescription__c/fields/LearningRate__c.field-meta.xml`
- Create: `apex-job/src/engine/domain/objects/JobDescription__c/fields/ConsecutiveVariationCount__c.field-meta.xml`
- Create: `apex-job/src/engine/domain/objects/JobDescription__c/fields/VariationResetCount__c.field-meta.xml`

**Step 1: `LearningRate__c`**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>LearningRate__c</fullName>
    <defaultValue>0.30</defaultValue>
    <description>EWMA learning rate (alpha) for the adaptive consumption model. Weight given to the most recent observation. 0 &lt; alpha &lt;= 1. Lower values smooth more.</description>
    <externalId>false</externalId>
    <label>Learning Rate</label>
    <precision>3</precision>
    <required>false</required>
    <scale>2</scale>
    <trackTrending>false</trackTrending>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
```

**Step 2: `ConsecutiveVariationCount__c`**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>ConsecutiveVariationCount__c</fullName>
    <defaultValue>0</defaultValue>
    <description>State: consecutive observations whose variation exceeded VariationResetThreshold__c. Managed by the engine. Resets to 0 on any normal observation or on a full model reset.</description>
    <externalId>false</externalId>
    <label>Consecutive Variation Count</label>
    <precision>4</precision>
    <required>false</required>
    <scale>0</scale>
    <trackTrending>false</trackTrending>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
```

**Step 3: `VariationResetCount__c`**

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
    <fullName>VariationResetCount__c</fullName>
    <defaultValue>3</defaultValue>
    <description>How many consecutive variations above VariationResetThreshold__c are required before the engine triggers a full consumption-model reset. Default 3.</description>
    <externalId>false</externalId>
    <label>Variation Reset Count</label>
    <precision>2</precision>
    <required>false</required>
    <scale>0</scale>
    <trackTrending>false</trackTrending>
    <type>Number</type>
    <unique>false</unique>
</CustomField>
```

**Step 4: Commit**

```bash
git add apex-job/src/engine/domain/objects/JobDescription__c/fields/LearningRate__c.field-meta.xml apex-job/src/engine/domain/objects/JobDescription__c/fields/ConsecutiveVariationCount__c.field-meta.xml apex-job/src/engine/domain/objects/JobDescription__c/fields/VariationResetCount__c.field-meta.xml
git commit -m "feat(consumption-learning): add EWMA fields to JobDescription__c"
```

### Task 2: Add a default learning-rate constant

**Files:**
- Modify: `apex-job/src/engine/domain/classes/ApexJobConstant.cls`

**Step 1: Append the constant**

Add to `ApexJobConstant.cls`:

```apex
  public static final Decimal DEFAULT_LEARNING_RATE = 0.30;
  public static final Integer DEFAULT_VARIATION_RESET_COUNT = 3;
```

Used as `??`-fallback when the field is null on a legacy record.

**Step 2: Commit**

```bash
git add apex-job/src/engine/domain/classes/ApexJobConstant.cls
git commit -m "feat(consumption-learning): add learning-rate constants"
```

### Task 3: Extend `ApexJobTestFixture` with the new fields

**Files:**
- Modify: `apex-job/test/unit/classes/ApexJobTestFixture.cls`

**Step 1: Set defaults in `JobDescriptionBuilder` constructor**

Locate the existing default-field assignment block in the
`JobDescriptionBuilder` constructor (near where `VariationResetThreshold__c`
is set). Add:

```apex
        LearningRate__c = ApexJobConstant.DEFAULT_LEARNING_RATE,
        ConsecutiveVariationCount__c = 0,
        VariationResetCount__c = ApexJobConstant.DEFAULT_VARIATION_RESET_COUNT
```

**Step 2: Add three builder methods**

Add after the existing `with*` methods in the builder:

```apex
    public JobDescriptionBuilder withLearningRate(final Decimal value) {
      this.record.LearningRate__c = value;
      return this;
    }

    public JobDescriptionBuilder withConsecutiveVariationCount(final Integer value) {
      this.record.ConsecutiveVariationCount__c = value;
      return this;
    }

    public JobDescriptionBuilder withVariationResetCount(final Integer value) {
      this.record.VariationResetCount__c = value;
      return this;
    }
```

**Step 3: Run tests**

```bash
npm run test:unit
```

Expected: all existing tests pass (additive change, no test references new
fields yet).

**Step 4: Commit**

```bash
git add apex-job/test/unit/classes/ApexJobTestFixture.cls
git commit -m "test(fixture): add EWMA field builders to JobDescriptionBuilder"
```

### Task 4: Add the new fields to `JobSelectorImpl` SELECT

**Files:**
- Modify: `apex-job/src/engine/adapter/JobSelectorImpl.cls`

**Step 1: Include the three fields in the `SELECT`**

In the big `SELECT` in `getEligibleJobs`, locate the block that reads
`JobDescription__r.VariationResetThreshold__c` (around line 58) and append:

```apex
        JobDescription__r.LearningRate__c,
        JobDescription__r.ConsecutiveVariationCount__c,
        JobDescription__r.VariationResetCount__c,
```

Make sure the trailing comma sits correctly — the block has strict order.

**Step 2: Run tests**

```bash
npm run test:unit
```

Expected: `JobSelectorImplTest` still passes (SELECT widening is additive).

**Step 3: Commit**

```bash
git add apex-job/src/engine/adapter/JobSelectorImpl.cls
git commit -m "feat(selector): include EWMA fields in eligible-jobs SELECT"
```

### Task 5: Write RED tests for EWMA + variation gating

**Files:**
- Modify: `apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls`

**Step 1: Add cold-start assertion**

```apex
  @IsTest
  static void givenColdStartBase_whenAdjustFromSuccessChunkOne_thenBaseSetToObservation() {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(120).build();

    sut.adjustFromSuccess(consumed, 1);

    Assert.areEqual(120, jobDescription.CpuTimeBaseConsumption__c, 'Cold-start base must equal the observation');
  }
```

**Step 2: Add EWMA blend assertion**

```apex
  @IsTest
  static void givenBase100_whenObserving150_thenBaseBlendsToward115WithAlpha030() {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(150).build();

    sut.adjustFromSuccess(consumed, 1);

    // 0.30 * 150 + 0.70 * 100 = 115
    Assert.areEqual(115, jobDescription.CpuTimeBaseConsumption__c, 'Normal observation must blend via EWMA');
  }
```

**Step 3: Add variation-gate (single variation, no reset)**

```apex
  @IsTest
  static void givenSingleVariationAboveThreshold_whenAdjust_thenCounterIncrementedBaseUnchanged() {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(0.5)   // 50% variation boundary
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(0)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(200).build();  // 100% variation

    sut.adjustFromSuccess(consumed, 1);

    Assert.areEqual(100, jobDescription.CpuTimeBaseConsumption__c, 'Extreme observation must NOT be assimilated');
    Assert.areEqual(1, jobDescription.ConsecutiveVariationCount__c, 'Variation counter must increment');
  }
```

**Step 4: Add reset-on-N-consecutive-variations**

```apex
  @IsTest
  static void givenCounterAtResetThresholdMinusOne_whenAnotherVariation_thenResetTriggered() {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withCpuTimePerItemConsumption(50)
      .withLearningRate(0.30)
      .withVariationResetThreshold(0.5)
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(2)   // one short of reset
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(500).build();

    sut.adjustFromSuccess(consumed, 1);

    // Reset fires: all dimensions zeroed, counter zeroed.
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jobDescription.CpuTimeBaseConsumption__c, 'Reset must zero base');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jobDescription.CpuTimePerItemConsumption__c, 'Reset must zero per-item');
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Reset must zero the variation counter');
  }
```

**Step 5: Add streak-break test**

```apex
  @IsTest
  static void givenCounterAtOne_whenNormalObservation_thenCounterResets() {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(1)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(110).build();   // small variation, normal

    sut.adjustFromSuccess(consumed, 1);

    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter must reset on any normal observation');
    Assert.areEqual(103, jobDescription.CpuTimeBaseConsumption__c, '0.30*110 + 0.70*100 = 103');
  }
```

**Step 6: Run tests — expect RED**

```bash
npm run test:unit
```

Expected: all five new tests fail (current code uses `Math.max` so blend is
wrong, and there is no counter).

### Task 6: Implement EWMA + variation gating (GREEN)

**Files:**
- Modify: `apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls`

**Step 1: Add the two private helpers first**

Define the helpers at the bottom of the class (before the closing `}`) so
they are in scope when the refactored methods reference them:

```apex
  private Decimal blend(final Decimal current, final Decimal observed) {
    final Decimal alpha = this.job.LearningRate__c ?? ApexJobConstant.DEFAULT_LEARNING_RATE;
    return alpha * observed + (1 - alpha) * current;
  }

  private Boolean recordVariationHit() {
    final Integer threshold = ((Decimal) (this.job.VariationResetCount__c ?? ApexJobConstant.DEFAULT_VARIATION_RESET_COUNT)).intValue();
    this.job.ConsecutiveVariationCount__c = (this.job.ConsecutiveVariationCount__c ?? 0) + 1;
    return this.job.ConsecutiveVariationCount__c >= threshold;
  }
```

**Step 2: Replace `adjustBaseConsumptionModel`**

```apex
  private Boolean adjustBaseConsumptionModel(final Decimal usage, final ConsumptionModel model) {
    final Decimal currentBase = (Decimal) this.job.get(model.base);
    if (currentBase <= ApexJobConstant.UNKNOWN_BASE_CONSUMPTION) {
      this.job.put(model.base, usage);
      this.job.ConsecutiveVariationCount__c = 0;
      return false;
    }
    final Decimal variation = Math.abs((usage - currentBase) / currentBase);
    if (variation > this.job.VariationResetThreshold__c) {
      return this.recordVariationHit();
    }
    this.job.put(model.base, this.blend(currentBase, usage));
    this.job.ConsecutiveVariationCount__c = 0;
    return false;
  }
```

**Step 3: Replace `adjustPerItemConsumptionModel`**

```apex
  private Boolean adjustPerItemConsumptionModel(final Decimal usage, final ConsumptionModel model, final Integer chunkSize) {
    final Decimal currentPerItem = (Decimal) this.job.get(model.perItem);
    final Decimal newPerItem = this.calculateNewPerItem(usage, model, chunkSize);

    if (currentPerItem <= ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION) {
      this.job.put(model.perItem, newPerItem);
      this.job.ConsecutiveVariationCount__c = 0;
      return false;
    }
    final Decimal variation = Math.abs((newPerItem - currentPerItem) / currentPerItem);
    if (variation > this.job.VariationResetThreshold__c) {
      return this.recordVariationHit();
    }
    this.job.put(model.perItem, this.blend(currentPerItem, newPerItem));
    this.job.ConsecutiveVariationCount__c = 0;
    return false;
  }
```

**Step 4: Zero the counter in `resetConsumptionModel`**

At the end of `resetConsumptionModel()`:

```apex
    this.job.ConsecutiveVariationCount__c = 0;
```

**Step 5: Remove the now-unused `calculateNewPerItem` chunkSize-1 guard concern**

The current `calculateNewPerItem` divides by `(chunkSize - 1)`. The outer
`processDimension` routes chunkSize == 1 to `adjustBaseConsumptionModel`, so
`calculateNewPerItem` is never called with chunkSize == 1. Leave as-is for
this PR — the belt-and-suspenders guard is §4 (deferred).

**Step 6: Run tests — expect GREEN**

```bash
npm run test:unit
```

Expected: all five new tests pass. Existing tests may require updates where
they relied on `Math.max` semantics — update them explicitly (not silently).
For every existing test that changes, add a one-line comment explaining why
the expected value changed from `Math.max(a,b)` to the EWMA blend.

### Task 7: Add a convergence scenario test

**Files:**
- Modify: `apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls`

**Step 1: Write the scenario**

```apex
  @IsTest
  static void givenBase100_whenFiveConsecutiveObservationsAt130_thenBaseApproaches130WithoutReset() {
    // α = 0.30 means each step moves 30% of the gap toward the new value.
    // Starting at 100, observing 130 repeatedly:
    //   step 1: 0.3*130 + 0.7*100 = 109
    //   step 2: 0.3*130 + 0.7*109 = 115.3
    //   step 3: 0.3*130 + 0.7*115.3 = 119.71
    //   step 4: 0.3*130 + 0.7*119.71 ≈ 122.8
    //   step 5: 0.3*130 + 0.7*122.8 ≈ 124.96
    // Variation at step 1: |130-100|/100 = 0.30 — within threshold (we set 1.0).
    // Counter stays at 0 throughout.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withVariationResetCount(3)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);

    for (Integer i = 0; i < 5; i++) {
      sut.adjustFromSuccess(ApexJobTestFixture.aLimitsUsage().withCpuTime(130).build(), 1);
    }

    Assert.isTrue(
      jobDescription.CpuTimeBaseConsumption__c > 120 && jobDescription.CpuTimeBaseConsumption__c < 130,
      'Base must converge toward 130 without triggering reset. Got: ' + jobDescription.CpuTimeBaseConsumption__c
    );
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter must stay at 0 through the run');
  }
```

**Step 2: Commit tasks 5–7 together**

```bash
git add apex-job/src/engine/domain/classes/consumption-learning/AdaptiveConsumptionLearner.cls apex-job/test/unit/classes/AdaptiveConsumptionLearnerTest.cls
git commit -m "feat(consumption-learning): EWMA smoothing with variation gate"
```

Body:

```
Replace `Math.max(current, observed)` with EWMA blending in
`adjustBaseConsumptionModel` and `adjustPerItemConsumptionModel`. Extreme
observations (variation > `VariationResetThreshold__c`) are no longer
assimilated; they increment `ConsecutiveVariationCount__c` instead. Reset
fires only when the counter reaches `VariationResetCount__c` (default 3).

Observation ratios within the threshold blend via the configurable
`LearningRate__c` (default 0.30). A single outlier can no longer permanently
inflate the learned base, and a single noisy observation no longer wipes
months of learning.
```

### Task 8: Final gate

**Step 1: Run the full local gate**

```bash
npm run prettier
npm run lint
npm run test:unit
```

**Step 2: Deploy + integration smoke (recommended before PR)**

```bash
npm run build
npm run test:integration
```

**Step 3: Functional throughput check (recommended before PR)**

Run `npm run test:functional:monitor-engine` in the scratch org *before*
deploying, note the throughput metrics; deploy; re-run; record before/after
in the PR body. If post-deploy throughput regressed noticeably, file a
follow-up to tune `LearningRate__c` per the Open Questions note.

**Step 4: If prettier reformatted anything, commit**

```bash
git add -u
git commit -m "chore: format ewma-consumption-learning changes"
```

---

## Verification (done when)

- Three new field metadata files exist under
  `apex-job/src/engine/domain/objects/JobDescription__c/fields/`.
- `ApexJobConstant` has `DEFAULT_LEARNING_RATE` and `DEFAULT_VARIATION_RESET_COUNT`.
- `ApexJobTestFixture.JobDescriptionBuilder` has three new `with*` methods
  and populates sane defaults in its constructor.
- `JobSelectorImpl` SELECT includes the three new fields.
- `AdaptiveConsumptionLearner`:
  - no `Math.max(currentBase, usage)` anywhere,
  - no `Math.max(currentPerItem, newPerItem)` anywhere,
  - `blend` helper present,
  - `recordVariationHit` helper present,
  - `resetConsumptionModel` zeros `ConsecutiveVariationCount__c`.
- `AdaptiveConsumptionLearnerTest` has at least 6 new tests (5 unit + 1
  convergence scenario); all pass.
- `git log --oneline main..HEAD` shows approximately 5–7 commits, each with a
  conventional-commit subject.
- CI passes; integration + functional suites green (or regression recorded in
  the PR body with follow-up ticket).
