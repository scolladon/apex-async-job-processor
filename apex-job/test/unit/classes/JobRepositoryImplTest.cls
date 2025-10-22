@isTest
private class JobRepositoryImplTest {
  @isTest
  static void givenGetJobCandidates_whenCalledWithNotEnoughQueries_thenReturnEmptyList() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    JobRepository sut = new JobRepositoryImpl(mocks.factoryStub);
    // Burn SOQL queries
    for (Integer i = 0; i < Limits.getLimitQueries() - 1; i++) {
      final List<Account> accs = [SELECT Id FROM Account LIMIT 1]; //NOPMD
    }

    // Act
    List<JobCandidate> actual = sut.getJobCandidates(new List<JobExecuted>());

    // Assert
    Assert.areEqual(0, actual.size(), 'It should not return any job candidates');
  }

  @isTest
  static void givenGetJobCandidates_whenCalledWithEmptyList_thenCallTheSelectorLayerWIthEmptyList() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    // Create test job request
    final JobRequest__c testJobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob').withJobDescription(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)).build();

    // Setup selector to return test job
    mocks.getEligibleJobsSpy.returns(new List<JobRequest__c>{ testJobRequest });

    // Create system under test
    JobRepository sut = new JobRepositoryImpl(mocks.factoryStub);

    // Act
    List<JobCandidate> actual = sut.getJobCandidates(new List<JobExecuted>());

    // Assert
    Assert.areEqual(1, actual.size(), 'It should return one job candidate');
    Assert.areEqual(testJobRequest, actual[0].jobRequests[0], 'The job candidate should be the same');
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledWith(new List<Id>());
  }

  @isTest
  static void givenGetJobCandidates_whenCalledWithNotEmptyList_thenCallTheSelectorLayerWIthNotEmptyList() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    // Create test job request
    final JobRequest__c testJobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob').withJobDescription(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)).build();
    final JobDescription__c testJobDescription = ApexJobTestFixture.aJobDescription().withName('TestJobDescription').withProcessorName('TestProcessor').withMaxChunkSize(1).build();
    testJobDescription.Id = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    final JobRequest__c jobRequestToExclude = ApexJobTestFixture.aJobRequest().withName('TestJobToExclude').withJobDescription(testJobDescription.Id).build();
    jobRequestToExclude.JobDescription__r = testJobDescription;

    // Setup selector to return test job
    mocks.getEligibleJobsSpy.returns(new List<JobRequest__c>{ testJobRequest });

    // Create system under test
    JobRepository sut = new JobRepositoryImpl(mocks.factoryStub);
    JobExecuted jobCandidatesToExclude = new JobExecuted(new JobExecutable(new List<JobRequest__c>{ jobRequestToExclude }), new ApexJobResult(ApexJobStatus.SUCCESS));

    // Act
    List<JobCandidate> actual = sut.getJobCandidates(new List<JobExecuted>{ jobCandidatesToExclude });

    // Assert
    Assert.areEqual(1, actual.size(), 'It should return one job candidate');
    Assert.areEqual(testJobRequest, actual[0].jobRequests[0], 'The job candidate should be the same');
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledWith(new List<Id>{ jobRequestToExclude.JobDescription__c });
  }

  @isTest
  static void givenRecordJobExecution_whenCalledWithSuccess_thenUpdateAndDeleteRequestAndUpdateDescription() {
    // Arrange
    // Create test data in database
    final List<JobDescription__c> testJobDescs = new List<JobDescription__c>();
    final List<JobRequest__c> testJobRequests = new List<JobRequest__c>();
    final List<JobExecuted> testJobsExecuted = new List<JobExecuted>();

    for (Integer i = 0; i < 11; i++) {
      final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription().withName('TestProcessor' + i).withProcessorName('TestProcessor' + i).enabled().withMaxChunkSize(-1).build();
      testJobDescs.add(jobDesc);
    }
    insert testJobDescs;

    for (Integer i = 0; i < 11; i++) {
      final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).success().enabled().build();
      jobRequest.JobDescription__r = testJobDescs[i];
      testJobRequests.add(jobRequest);
    }
    insert testJobRequests;

    // Mock JobCandidates interface for each group
    ApexJobResult mockResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    final LimitsUsage limitsUsage = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(1)
      .withHeapSize(1)
      .withCallout(1)
      .withCalloutTime(1)
      .withPublishImmediateDml(1)
      .withDmlRows(1)
      .withDmlStatements(1)
      .withQueryRows(1)
      .withQueries(1)
      .withSoslQueries(1)
      .withFutureCalls(1)
      .build();
    mockResult.consumedLimits = limitsUsage;
    for (Integer i = 0; i < 11; i++) {
      testJobsExecuted.add(new JobExecuted(new JobExecutable(new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted);
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(0, [SELECT COUNT() FROM JobRequest__c], 'All JobRequest should have been deleted');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c], 'Should have 11 JobDescription updated');
    // 11 updates (JobRequests for metrics) + 11 deletes (JobRequests) + 11 updates (JobDescriptions)
    Assert.areEqual(33, dmlAfter - dmlBefore, 'Should update all requests for metrics, delete them, and update descriptions');
  }

  @isTest
  static void givenRecordJobExecution_whenCalledWithFailure_thenUpdateRequestAndDescription() {
    // Arrange
    // Create test data in database
    List<JobDescription__c> testJobDescs = new List<JobDescription__c>();
    List<JobRequest__c> testJobRequests = new List<JobRequest__c>();
    List<JobExecuted> testJobsExecuted = new List<JobExecuted>();

    for (Integer i = 0; i < 11; i++) {
      final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription().withName('TestProcessor' + i).withProcessorName('TestProcessor' + i).enabled().withMaxChunkSize(-1).build();
      testJobDescs.add(jobDesc);
    }
    insert testJobDescs;

    for (Integer i = 0; i < 11; i++) {
      final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).failure().enabled().build();
      jobRequest.JobDescription__r = testJobDescs[i];
      testJobRequests.add(jobRequest);
    }
    insert testJobRequests;

    // Mock JobCandidates interface for each group
    ApexJobResult mockResult = new ApexJobResult(ApexJobStatus.FAILURE);
    final LimitsUsage limitsUsage = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(1)
      .withHeapSize(1)
      .withCallout(1)
      .withCalloutTime(1)
      .withPublishImmediateDml(1)
      .withDmlRows(1)
      .withDmlStatements(1)
      .withQueryRows(1)
      .withQueries(1)
      .withSoslQueries(1)
      .withFutureCalls(1)
      .build();
    mockResult.consumedLimits = limitsUsage;
    for (Integer i = 0; i < 11; i++) {
      testJobsExecuted.add(new JobExecuted(new JobExecutable(new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted);
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(11, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.FAILURE.name()], 'All JobRequest should have been updated');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c], 'All JobDescription should have been updated');
    // 11 updates (JobRequests) + 11 updates (JobDescriptions)
    Assert.areEqual(22, dmlAfter - dmlBefore, 'Should update all requests and descriptions');
  }

  @isTest
  static void givenRecordJobExecution_whenCalledWithFailureAndSuccess_thenUpdateDeleteRequestAndUpdateDescription() {
    // Arrange
    // Create test data in database
    List<JobDescription__c> testJobDescs = new List<JobDescription__c>();
    List<JobRequest__c> testJobRequests = new List<JobRequest__c>();

    for (Integer i = 0; i < 11; i++) {
      final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
        .withName('TestProcessor' + i)
        .withProcessorName('TestProcessor' + i)
        .enabled()
        .withMaxChunkSize(-1)
        .withCpuTimeConsumption(1000)
        .withHeapSizeConsumption(512000)
        .withCalloutConsumption(1)
        .withCalloutTimeConsumption(5000)
        .withPublishImmediateDmlConsumption(1)
        .withDmlRowsConsumption(50)
        .withDmlStatementsConsumption(200)
        .withQueryRowsConsumption(100)
        .withQueriesConsumption(5)
        .withSoslQueriesConsumption(1)
        .withFutureCallsConsumption(1)
        .build();
      testJobDescs.add(jobDesc);
    }
    insert testJobDescs;

    for (Integer i = 0; i < 11; i++) {
      ApexJobStatus status = Math.mod(i, 2) == 0 ? ApexJobStatus.SUCCESS : ApexJobStatus.FAILURE;
      JobRequest__c jobRequest;
      if (status == ApexJobStatus.SUCCESS) {
        jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).success().enabled().build();
      } else {
        jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).failure().enabled().build();
      }
      jobRequest.JobDescription__r = testJobDescs[i];
      testJobRequests.add(jobRequest);
    }
    insert testJobRequests;

    List<JobExecuted> testJobsExecuted = new List<JobExecuted>();
    for (Integer i = 0; i < 11; i++) {
      ApexJobResult mockResult;
      if (Math.mod(i, 2) == 0) {
        mockResult = new ApexJobResult(ApexJobStatus.SUCCESS);
      } else {
        mockResult = new ApexJobResult(ApexJobStatus.FAILURE);
      }
      final LimitsUsage successLimits = ApexJobTestFixture.aLimitsUsage()
        .withCpuTime(1)
        .withHeapSize(1)
        .withCallout(1)
        .withCalloutTime(1)
        .withPublishImmediateDml(1)
        .withDmlRows(1)
        .withDmlStatements(1)
        .withQueryRows(1)
        .withQueries(1)
        .withSoslQueries(1)
        .withFutureCalls(1)
        .build();
      mockResult.consumedLimits = successLimits;
      testJobsExecuted.add(new JobExecuted(new JobExecutable(new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted);
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(5, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.FAILURE.name()], '5 JobRequest should have been updated');
    Assert.areEqual(0, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.SUCCESS.name()], '6 JobRequest should have been deleted');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c], 'All JobDescription should have been updated');
    // 11 updates (JobRequests) + 6 deletes (successful JobRequests) + 11 updates (JobDescriptions) = 28
    Assert.areEqual(28, dmlAfter - dmlBefore, 'Should update all requests for metrics, delete successes, and update descriptions');
  }

  @isTest
  static void givenRecordJobExecution_whenCalledWithoutCandidates_thenDoesNothing() {
    // Arrange
    JobRepository sut = new JobRepositoryImpl();
    final Integer dmlBeforeAct = Limits.getDmlRows();

    // Act
    Test.startTest();
    sut.recordJobExecution(new List<JobExecuted>());
    Test.stopTest();

    // Assert
    Assert.areEqual(0, Limits.getDmlRows() - dmlBeforeAct, 'Should have 0 save results');
  }
}
