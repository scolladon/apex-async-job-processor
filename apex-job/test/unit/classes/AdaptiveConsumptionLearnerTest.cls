@IsTest
private class AdaptiveConsumptionLearnerTest {
  @IsTest
  private static void givenSingleChunkSuccess_whenAdjustFromSuccess_thenTrackBaseConsumption() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 1);
    Test.stopTest();

    // Assert
    Assert.areEqual(100, job.CpuTimeBaseConsumption__c, 'Should track base consumption');
    Assert.areEqual(0, job.CpuTimePerItemConsumption__c, 'Per item should remain 0');
  }

  @IsTest
  private static void givenScaledChunkSuccess_whenAdjustFromSuccess_thenBlendPerItemViaEwma() {
    // Arrange — new observed per-item is (208 - 100) / (10 - 1) = 12; current is 10.
    // Variation = 0.2, below the default threshold 0.3, so EWMA blends:
    // 0.30 * 12 + 0.70 * 10 = 10.6.
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(10).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).withSuccessStreak(3).build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(208).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(10.6, job.CpuTimePerItemConsumption__c, 'Should blend per-item consumption via EWMA (0.30*12 + 0.70*10)');
  }

  @IsTest
  private static void givenLargeVariationAndResetCountOne_whenAdjustFromSuccess_thenResetModel() {
    // Arrange — with VariationResetCount = 1, a single variation above threshold
    // is enough to trigger a full reset.
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(10).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(5).withVariationResetCount(1).build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(1000).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(0, job.CpuTimeBaseConsumption__c, 'Should reset on large variation when reset count is 1');
    Assert.areEqual(0, job.CpuTimePerItemConsumption__c, 'Should reset on large variation when reset count is 1');
  }

  @IsTest
  private static void givenSuccess_whenAdjustFromSuccess_thenSetBaseConsumptionOnly() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(ApexJobTestFixture.aLimitsUsage().withCpuTime(200).build(), 1);
    Test.stopTest();

    // Assert
    Assert.areEqual(200, job.CpuTimeBaseConsumption__c, 'Should set base consumption');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, job.CpuTimePerItemConsumption__c, 'Should not set per item consumption');
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, job.CpuTimeSafety__c, 'Should not set safety factor');
  }

  @IsTest
  private static void givenFailure_whenAdjustFromFailure_thenDecreaseSafety() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withConsecutiveFailures(1).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).withCpuTimeSafety(0.9).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromFailure(ApexJobTestFixture.aLimitsUsage().withCpuTime(200).build(), 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(0.85, job.CpuTimeSafety__c, 'Should reset safety factor');
  }

  @IsTest
  private static void givenFailure_whenAdjustFromFailureAndSafetyTooLow_thenResetModel() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withConsecutiveFailures(1).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).withCpuTimeSafety(0.5).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromFailure(ApexJobTestFixture.aLimitsUsage().withCpuTime(200).build(), 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, job.CpuTimeBaseConsumption__c, 'Should reset base consumption');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, job.CpuTimePerItemConsumption__c, 'Should reset per item consumption');
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, job.CpuTimeSafety__c, 'Should reset safety factor');
  }

  @IsTest
  private static void givenMaxAttemptsKill_whenAdjustFromKill_thenResetModel() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxExecutionAttempt(3).withConsecutiveFailures(3).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromKill(5);
    Test.stopTest();

    // Assert
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, job.CpuTimeBaseConsumption__c, 'Should reset on max attempts');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, job.CpuTimePerItemConsumption__c, 'Should reset on max attempts');
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, job.CpuTimeSafety__c, 'Should reset on max attempts');
  }

  @IsTest
  private static void givenKill_whenAdjustFromKillAndSafetyTooLow_thenResetModel() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withConsecutiveFailures(0).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).withCpuTimeSafety(0.5).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromKill(5);
    Test.stopTest();

    // Assert
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, job.CpuTimeBaseConsumption__c, 'Should reset on max attempts');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, job.CpuTimePerItemConsumption__c, 'Should reset on max attempts');
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, job.CpuTimeSafety__c, 'Should reset on max attempts');
  }

  @IsTest
  private static void givenKill_whenAdjustFromKill_thenInflateConsumptionModel() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withConsecutiveFailures(0).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).build();

    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromKill(5);
    Test.stopTest();

    // Assert
    Assert.areEqual(110, job.CpuTimeBaseConsumption__c, 'Should inflate consumption model');
    Assert.areEqual(11, job.CpuTimePerItemConsumption__c, 'Should inflate consumption model');
  }

  @IsTest
  static void givenColdStartBase_whenAdjustFromSuccessChunkOne_thenBaseSetToObservation() {
    // Arrange
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withCpuTimeConsumption(0).build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(120).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert
    Assert.areEqual(120, jobDescription.CpuTimeBaseConsumption__c, 'Cold-start base must equal the observation');
  }

  @IsTest
  static void givenBase100_whenObserving150WithinThreshold_thenBaseBlendsToward115WithAlpha030() {
    // Arrange — alpha = 0.30 means new base = 0.30 * 150 + 0.70 * 100 = 115.
    // withSuccessStreak(3) bypasses the post-failure Math.max cooldown so we exercise EWMA directly.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withCpuTimeConsumption(100).withLearningRate(0.30).withVariationResetThreshold(1.0).withSuccessStreak(3).build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(150).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert
    Assert.areEqual(115, jobDescription.CpuTimeBaseConsumption__c, 'Normal observation must blend via EWMA');
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter stays 0 when the observation is normal');
  }

  @IsTest
  static void givenSingleVariationAboveThreshold_whenAdjust_thenCounterIncrementedBaseUnchanged() {
    // Arrange — 100% variation, threshold 50%.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(0.5)
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(0)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(200).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert
    Assert.areEqual(100, jobDescription.CpuTimeBaseConsumption__c, 'Extreme observation must NOT be assimilated');
    Assert.areEqual(1, jobDescription.ConsecutiveVariationCount__c, 'Variation counter must increment');
  }

  @IsTest
  static void givenCounterAtResetThresholdMinusOne_whenAnotherVariation_thenResetTriggered() {
    // Arrange — counter is already at 2; one more variation hits the reset threshold (3).
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withCpuTimePerItemConsumption(50)
      .withLearningRate(0.30)
      .withVariationResetThreshold(0.5)
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(2)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(500).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — full reset wipes all dimensions and zeroes the counter.
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jobDescription.CpuTimeBaseConsumption__c, 'Reset must zero base');
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jobDescription.CpuTimePerItemConsumption__c, 'Reset must zero per-item');
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Reset must zero the variation counter');
  }

  @IsTest
  static void givenCounterAtOne_whenNormalObservation_thenCounterResets() {
    // Arrange — counter at 1 from a prior variation; next observation is normal (10% variation, below threshold).
    // withSuccessStreak(3) ensures we're past the post-failure Math.max cooldown so EWMA blend fires.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withVariationResetCount(3)
      .withConsecutiveVariationCount(1)
      .withSuccessStreak(3)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(110).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — counter cleared; EWMA applied (0.30*110 + 0.70*100 = 103).
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter must reset on any normal observation');
    Assert.areEqual(103, jobDescription.CpuTimeBaseConsumption__c, '0.30*110 + 0.70*100 = 103');
  }

  @IsTest
  static void givenBase100_whenFiveConsecutiveObservationsAt130_thenBaseConvergesTowardTargetWithoutReset() {
    // Arrange — alpha = 0.30, repeated observations of 130 against starting base 100.
    // withSuccessStreak(3) ensures EWMA fires from iteration 1 instead of spending 3 iterations in Math.max cooldown.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(100)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withVariationResetCount(3)
      .withSuccessStreak(3)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);

    // Act
    for (Integer i = 0; i < 5; i++) {
      sut.adjustFromSuccess(ApexJobTestFixture.aLimitsUsage().withCpuTime(130).build(), 1);
    }

    // Assert — five EWMA iterations from 100 toward 130 at alpha=0.30
    // 100 → 109 → 115.3 → 119.71 → 122.797 → 124.9579
    Assert.areEqual(124.9579, jobDescription.CpuTimeBaseConsumption__c, 'Base must equal the deterministic EWMA convergence value after 5 iterations');
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter must stay at 0 through the run');
  }

  @IsTest
  static void givenPostKillInflatedBase_whenSuccessDuringCooldown_thenMathMaxHoldsInflation() {
    // Arrange — SuccessStreak (0) < KillCooldownCount (3) means the post-kill cooldown is active.
    // An observation LOWER than the inflated base must NOT blend downward — Math.max keeps the inflated value.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(110)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withSuccessStreak(0)
      .withKillCooldownCount(3)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(95).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — Math.max(110, 95) = 110; cooldown protects the inflation from erosion.
    Assert.areEqual(110, jobDescription.CpuTimeBaseConsumption__c, 'Cooldown must hold the inflated base via Math.max');
  }

  @IsTest
  static void givenPostKillCooldownExpired_whenSuccess_thenEwmaResumes() {
    // Arrange — SuccessStreak (3) >= KillCooldownCount (3) means the cooldown has expired.
    // A lower observation must now blend via EWMA: 0.30 * 95 + 0.70 * 110 = 105.5.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(110)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withSuccessStreak(3)
      .withKillCooldownCount(3)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(95).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — EWMA blend downward once cooldown releases.
    Assert.areEqual(105.5, jobDescription.CpuTimeBaseConsumption__c, '0.30*95 + 0.70*110 = 105.5');
  }

  @IsTest
  static void givenKillCooldownCountZero_whenSuccessAfterKill_thenEwmaAppliesImmediately() {
    // Arrange — with KillCooldownCount = 0, the guard `SuccessStreak < KillCooldownCount` is always false,
    // so EWMA applies on the very first success after a kill (no protective plateau).
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withCpuTimeConsumption(110)
      .withLearningRate(0.30)
      .withVariationResetThreshold(1.0)
      .withSuccessStreak(0)
      .withKillCooldownCount(0)
      .build();
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(95).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — no cooldown, EWMA fires: 0.30*95 + 0.70*110 = 105.5.
    Assert.areEqual(105.5, jobDescription.CpuTimeBaseConsumption__c, 'EWMA must apply immediately when cooldown is disabled');
  }

  @IsTest
  static void givenSeededModelAcrossAllDimensions_whenResetTriggered_thenEveryDimensionWiped() {
    // Arrange — pre-populate every dimension with non-default values, then force a variation reset
    // on the first processed dimension to verify the wipe covers ALL dimensions, not just cpuTime.
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withVariationResetCount(1).withVariationResetThreshold(0.3).build();
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      jobDescription.put(model.base, 100);
      jobDescription.put(model.perItem, 10);
      jobDescription.put(model.safety, 0.8);
    }
    final AdaptiveConsumptionLearner sut = new AdaptiveConsumptionLearner(jobDescription);
    // 10x variation on cpuTime → trips reset on the first dimension iterated.
    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(1000).build();

    // Act
    sut.adjustFromSuccess(consumed, 1);

    // Assert — the reset must zero base / perItem / safety on EVERY registered dimension.
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, (Decimal) jobDescription.get(model.base), 'Base must reset on dimension ' + model.dimension);
      Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, (Decimal) jobDescription.get(model.perItem), 'PerItem must reset on dimension ' + model.dimension);
      Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, (Decimal) jobDescription.get(model.safety), 'Safety must reset on dimension ' + model.dimension);
    }
    Assert.areEqual(0, jobDescription.ConsecutiveVariationCount__c, 'Counter must be cleared by reset');
  }
}
