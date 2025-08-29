@IsTest
private class AdaptiveChunkCalculatorTest {
  @IsTest
  private static void givenJobWithMaxChunkBelow1_whenGetMaxPossible_thenReturn1() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(0).build();
    final AdaptiveChunkCalculator sut = new AdaptiveChunkCalculator();

    // Act
    final Integer result = sut.getMaxPossible(job);

    // Assert
    Assert.areEqual(1, result, 'Should return 1 when max chunk size is below 1');
  }

  @IsTest
  private static void givenJobWithLimits_whenGetMaxPossible_thenCalculateCorrectly() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(100).withCpuTimeConsumption(100).withCpuTimePerItemConsumption(10).withCpuTimeSafety(0.9).build();

    final Mock limitServiceMock = Mock.forType(LimitService.class);
    limitServiceMock.spyOn('getAvailableLimits').returns(ApexJobTestFixture.aLimitsUsage().withCpuTime(500).build());

    final AdaptiveChunkCalculator sut = new AdaptiveChunkCalculator((LimitService) limitServiceMock.stub);

    // Act
    final Integer result = sut.getMaxPossible(job);

    // Assert
    Assert.areEqual(37, result, 'Should correctly calculate chunk size');
    Expect.that(limitServiceMock.spyOn('getAvailableLimits')).hasBeenCalled();
  }

  @IsTest
  private static void givenJobWithFailingChunk_whenGetMaxPossible_thenRespectLimit() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withSmallestFailingChunk(20)
      .withCpuTimeConsumption(100)
      .withCpuTimePerItemConsumption(10)
      .withCpuTimeSafety(0.9)
      .build();

    final Mock limitServiceMock = Mock.forType(LimitService.class);
    limitServiceMock.spyOn('getAvailableLimits').returns(ApexJobTestFixture.aLimitsUsage().withCpuTime(500).build());

    final AdaptiveChunkCalculator sut = new AdaptiveChunkCalculator((LimitService) limitServiceMock.stub);

    // Act
    final Integer result = sut.getMaxPossible(job);

    // Assert
    Assert.areEqual(19, result, 'Should respect smallest failing chunk');
    Expect.that(limitServiceMock.spyOn('getAvailableLimits')).hasBeenCalled();
  }

  @IsTest
  private static void givenBaseExceedsLimits_whenGetMaxPossible_thenReturn0() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(100).withCpuTimeConsumption(600).withCpuTimePerItemConsumption(10).build();

    final Mock limitServiceMock = Mock.forType(LimitService.class);
    limitServiceMock.spyOn('getAvailableLimits').returns(ApexJobTestFixture.aLimitsUsage().withCpuTime(500).build());

    final AdaptiveChunkCalculator sut = new AdaptiveChunkCalculator((LimitService) limitServiceMock.stub);

    // Act
    final Integer result = sut.getMaxPossible(job);

    // Assert
    Assert.areEqual(0, result, 'Should return 0 when base exceeds limits');
    Expect.that(limitServiceMock.spyOn('getAvailableLimits')).hasBeenCalled();
  }
}
