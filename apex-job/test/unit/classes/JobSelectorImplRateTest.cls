@IsTest
private class JobSelectorImplRateTest {
  @IsTest
  static void givenLimitLoweredBelowLoggedItemsAndNoHint_whenGetEligibleJobs_thenReturnsItsRequests() {
    // Arrange
    final String rateLog = (System.now().getTime() - 10000) + ':1;';
    final Id requestId = insertDueRequest(aRateLimitedDescription('RateLoggedJob').withMaxExecutionsPerMinute(1).withRateLog(rateLog).withRateBlockedUntil(null).buildAndInsert(), 'RateLoggedJob');
    final JobSelectorImpl sut = buildSut();

    // Act
    Test.startTest();
    final List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    final Map<Id, JobRequest__c> resultById = new Map<Id, JobRequest__c>(result);
    Assert.isTrue(resultById.containsKey(requestId), 'Should return requests of a description with no rate hint');
    Assert.areEqual(rateLog, resultById.get(requestId).JobDescription__r.RateLog__c, 'Should select the rate log of the description');
  }

  @IsTest
  static void givenRateHintInFuture_whenGetEligibleJobs_thenExcludesItsRequests() {
    // Arrange
    final Id requestId = insertDueRequest(
      aRateLimitedDescription('RateBlockedJob').withMaxExecutionsPerMinute(10).withRateLog(null).withRateBlockedUntil(System.now().addSeconds(30)).buildAndInsert(),
      'RateBlockedJob'
    );
    final JobSelectorImpl sut = buildSut();

    // Act
    Test.startTest();
    final List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.isFalse(new Map<Id, JobRequest__c>(result).containsKey(requestId), 'Should not return requests of a description rate-blocked until the future');
  }

  @IsTest
  static void givenRateHintPassed_whenGetEligibleJobs_thenReturnsItsRequests() {
    // Arrange
    final Id requestId = insertDueRequest(
      aRateLimitedDescription('RateElapsedJob').withMaxExecutionsPerMinute(10).withRateLog(null).withRateBlockedUntil(System.now().addSeconds(-1)).buildAndInsert(),
      'RateElapsedJob'
    );
    final JobSelectorImpl sut = buildSut();

    // Act
    Test.startTest();
    final List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.isTrue(new Map<Id, JobRequest__c>(result).containsKey(requestId), 'Should return requests once the rate hint has passed');
  }

  @IsTest
  static void givenRateHintInFutureButNoLimit_whenGetEligibleJobs_thenReturnsItsRequests() {
    // Arrange
    final Id requestId = insertDueRequest(
      aRateLimitedDescription('RateUnlimitedJob').withMaxExecutionsPerMinute(0).withRateLog(null).withRateBlockedUntil(System.now().addSeconds(30)).buildAndInsert(),
      'RateUnlimitedJob'
    );
    final JobSelectorImpl sut = buildSut();

    // Act
    Test.startTest();
    final List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.isTrue(new Map<Id, JobRequest__c>(result).containsKey(requestId), 'Should ignore the rate hint when the description has no rate limit');
  }

  private static JobSelectorImpl buildSut() {
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getAvailableLimitsSpy.returns(buildMaxAvailableGovernorLimits());
    return new JobSelectorImpl(mocks.factoryStub);
  }

  private static LimitsUsage buildMaxAvailableGovernorLimits() {
    return ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(60000)
      .withHeapSize(12 * 1024 * 1024)
      .withCallout(100)
      .withCalloutTime(120000)
      .withPublishImmediateDml(150)
      .withDmlRows(10000)
      .withDmlStatements(150)
      .withQueryRows(50000)
      .withQueries(200)
      .withSoslQueries(20)
      .withFutureCalls(50)
      .build();
  }

  private static ApexJobTestFixture.JobDescriptionBuilder aRateLimitedDescription(final String requestName) {
    return ApexJobTestFixture.aJobDescription().withName(requestName + 'Processor').withProcessorName(requestName + 'Processor').enabled().withMaxChunkSize(-1);
  }

  private static Id insertDueRequest(final JobDescription__c description, final String requestName) {
    final JobRequest__c request = ApexJobTestFixture.aJobRequest()
      .withJobDescription(description)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName(requestName)
      .withArgument('{"rate": "job"}')
      .build();
    insert as system request;
    return request.Id;
  }
}
