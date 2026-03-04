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
  private static void givenRateLimitWithBudgetRemaining_whenGetMaxPossible_thenCapToRemainingBudget() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(20)
      .withExecutionsInCurrentWindow(15)
      .withCurrentWindowStart(System.now())
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
  private static void givenRateLimitWithExpiredWindow_whenGetMaxPossible_thenFullBudget() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(20)
      .withExecutionsInCurrentWindow(20)
      .withCurrentWindowStart(System.now().addMinutes(-2))
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
    Assert.areEqual(20, result, 'Should use full budget when window has expired');
  }

  @IsTest
  private static void givenRateLimitLowerThanGovernorChunk_whenGetMaxPossible_thenRateLimitWins() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(3)
      .withExecutionsInCurrentWindow(0)
      .withCurrentWindowStart(System.now())
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
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(10)
      .withExecutionsInCurrentWindow(15)
      .withCurrentWindowStart(System.now())
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
  private static void givenRateLimitWithNullWindow_whenGetMaxPossible_thenFullBudget() {
    // Arrange
    final JobDescription__c job = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(100)
      .withMaxExecutionsPerMinute(10)
      .withExecutionsInCurrentWindow(5)
      .withCurrentWindowStart(null)
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
    Assert.areEqual(10, result, 'Should use full budget when window start is null');
  }
}
