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

  @IsTest
  private static void givenNoRateLimit_whenGetMaxPossible_thenNoChunkCapping() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(0)
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
    Assert.areEqual(37, result, 'Should not cap when rate limit is disabled');
  }

  @IsTest
  private static void givenRateLimitWithItemsLoggedInWindow_whenGetMaxPossible_thenCapToRemainingBudget() {
    // Arrange
    final Long now = System.now().getTime();
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(20)
      .withRateLog((now - 5000) + ':15;')
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
    Assert.areEqual(5, result, 'Should cap to remaining rate budget');
  }

  @IsTest
  private static void givenRateLimitWithEntriesOlderThanWindow_whenGetMaxPossible_thenFullBudget() {
    // Arrange
    final Long now = System.now().getTime();
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(20)
      .withRateLog((now - 61000) + ':20;')
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
    Assert.areEqual(20, result, 'Should use full budget when entries left the window');
  }

  @IsTest
  private static void givenRateLimitLowerThanGovernorChunk_whenGetMaxPossible_thenRateLimitWins() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(3)
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
    Assert.areEqual(3, result, 'Should cap to rate limit when lower than governor chunk');
  }

  @IsTest
  private static void givenRateLimitFullyConsumed_whenGetMaxPossible_thenReturnZero() {
    // Arrange
    final Long now = System.now().getTime();
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(10)
      .withRateLog((now - 5000) + ':15;')
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
    Assert.areEqual(0, result, 'Should return 0 when rate limit budget is exhausted');
  }

  @IsTest
  private static void givenRateLimitWithNullLog_whenGetMaxPossible_thenFullBudget() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(10)
      .withRateLog(null)
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
    Assert.areEqual(10, result, 'Should use full budget when the log is null');
  }

  @IsTest
  private static void givenOneItemEnded61sAgoAndNineItems2sAgo_whenGetMaxPossible_thenReturnsOne() {
    // Arrange
    final Long now = System.now().getTime();
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(10)
      .withRateLog((now - 61000) + ':1;' + (now - 2000) + ':9;')
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
    Assert.areEqual(1, result, 'Only the nine recent items count against a limit of 10');
  }

  @IsTest
  private static void givenModelBelowOneItemWithRateBudgetExhausted_whenGetMaxPossible_thenReturnsZero() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription().withMaxChunkSize(0).withMaxExecutionsPerMinute(1).withRateLog((System.now().getTime() - 10000) + ':1;').build();

    final Mock limitServiceMock = Mock.forType(LimitService.class);
    final AdaptiveChunkCalculator sut = new AdaptiveChunkCalculator((LimitService) limitServiceMock.stub);

    // Act
    final Integer result = sut.getMaxPossible(job);

    // Assert
    Assert.areEqual(0, result, 'One item ended 10 s ago against a limit of 1');
  }
}
