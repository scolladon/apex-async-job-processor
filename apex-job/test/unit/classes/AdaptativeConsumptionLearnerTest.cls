@IsTest
private class AdaptativeConsumptionLearnerTest {
  @IsTest
  private static void givenSingleChunkSuccess_whenAdjustFromSuccess_thenTrackBaseConsumption() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).build();

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 1);
    Test.stopTest();

    // Assert
    Assert.areEqual(100, job.CpuTimeBaseConsumption__c, 'Should track base consumption');
    Assert.areEqual(0, job.CpuTimePerItemConsumption__c, 'Per item should remain 0');
  }

  @IsTest
  private static void givenScaledChunkSuccess_whenAdjustFromSuccess_thenUpdatePerItem() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(10).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(208).build();

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(12, job.CpuTimePerItemConsumption__c, 'Should update per item consumption');
  }

  @IsTest
  private static void givenLargeVariation_whenAdjustFromSuccess_thenResetModel() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(10).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(5).build();

    final LimitsUsage consumed = ApexJobTestFixture.aLimitsUsage().withCpuTime(1000).build();

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromSuccess(consumed, 10);
    Test.stopTest();

    // Assert
    Assert.areEqual(0, job.CpuTimeBaseConsumption__c, 'Should reset on large variation');
    Assert.areEqual(0, job.CpuTimePerItemConsumption__c, 'Should reset on large variation');
  }

  @IsTest
  private static void givenSuccess_whenAdjustFromSuccess_thenSetBaseConsumptionOnly() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().build();

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

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

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

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

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

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

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

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

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

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

    final AdaptativeConsumptionLearner sut = new AdaptativeConsumptionLearner(job);

    // Act
    Test.startTest();
    sut.adjustFromKill(5);
    Test.stopTest();

    // Assert
    Assert.areEqual(110, job.CpuTimeBaseConsumption__c, 'Should inflate consumption model');
    Assert.areEqual(11, job.CpuTimePerItemConsumption__c, 'Should inflate consumption model');
  }
}
