@IsTest
private class JobRepositoryImplTest {
  private static final Integer TRACKED_JOB_ID_CAPACITY = 20;
  private static final Integer ID_15_LENGTH = 15;
  @IsTest
  static void givenGetJobCandidates_whenCalledWithNotEnoughQueries_thenReturnEmptyList() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    JobRepository sut = new JobRepositoryImpl(mocks.factoryStub);
    // Burn SOQL queries
    for (Integer i = 0; i < Limits.getLimitQueries() - 1; i++) {
      final List<Account> accs = [SELECT Id FROM Account WITH SYSTEM_MODE LIMIT 1]; //NOPMD
    }

    // Act
    List<JobCandidate> actual = sut.getJobCandidates(new List<JobExecuted>());

    // Assert
    Assert.areEqual(0, actual.size(), 'It should not return any job candidates');
  }

  @IsTest
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

  @IsTest
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
    JobExecuted jobCandidatesToExclude = new JobExecuted(
      new ApexJobFactoryImpl(),
      new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequestToExclude }),
      new ApexJobResult(ApexJobStatus.SUCCESS)
    );

    // Act
    List<JobCandidate> actual = sut.getJobCandidates(new List<JobExecuted>{ jobCandidatesToExclude });

    // Assert
    Assert.areEqual(1, actual.size(), 'It should return one job candidate');
    Assert.areEqual(testJobRequest, actual[0].jobRequests[0], 'The job candidate should be the same');
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getEligibleJobsSpy).hasBeenCalledWith(new List<Id>{ jobRequestToExclude.JobDescription__c });
  }

  @IsTest
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
    insert as system testJobDescs;

    for (Integer i = 0; i < 11; i++) {
      final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).success().enabled().build();
      jobRequest.JobDescription__r = testJobDescs[i];
      testJobRequests.add(jobRequest);
    }
    insert as system testJobRequests;

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
      testJobsExecuted.add(new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted, new TestFinalizerContext(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)));
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(0, [SELECT COUNT() FROM JobRequest__c WITH SYSTEM_MODE], 'All JobRequest should have been deleted');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c WITH SYSTEM_MODE], 'Should have 11 JobDescription updated');
    // 11 updates (JobRequests for metrics) + 11 deletes (JobRequests) + 11 updates (JobDescriptions)
    Assert.areEqual(33, dmlAfter - dmlBefore, 'Should update all requests for metrics, delete them, and update descriptions');
  }

  @IsTest
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
    insert as system testJobDescs;

    for (Integer i = 0; i < 11; i++) {
      final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob' + i).withJobDescription(testJobDescs[i].Id).failure().enabled().build();
      jobRequest.JobDescription__r = testJobDescs[i];
      testJobRequests.add(jobRequest);
    }
    insert as system testJobRequests;

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
      testJobsExecuted.add(new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted, new TestFinalizerContext(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)));
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(11, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.FAILURE.name() WITH SYSTEM_MODE], 'All JobRequest should have been updated');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c WITH SYSTEM_MODE], 'All JobDescription should have been updated');
    // 11 updates (JobRequests) + 11 updates (JobDescriptions)
    Assert.areEqual(22, dmlAfter - dmlBefore, 'Should update all requests and descriptions');
  }

  @IsTest
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
        .withBaseConsumption(JobDescription__c.CalloutTimeBaseConsumption__c, 5000)
        .withBaseConsumption(JobDescription__c.PublishImmediateDmlBaseConsumption__c, 1)
        .withBaseConsumption(JobDescription__c.DmlRowsBaseConsumption__c, 50)
        .withBaseConsumption(JobDescription__c.DmlStatementsBaseConsumption__c, 200)
        .withBaseConsumption(JobDescription__c.QueryRowsBaseConsumption__c, 100)
        .withBaseConsumption(JobDescription__c.QueriesBaseConsumption__c, 5)
        .withBaseConsumption(JobDescription__c.SoslQueriesBaseConsumption__c, 1)
        .withBaseConsumption(JobDescription__c.FutureCallsBaseConsumption__c, 1)
        .build();
      testJobDescs.add(jobDesc);
    }
    insert as system testJobDescs;

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
    insert as system testJobRequests;

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
      testJobsExecuted.add(new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ testJobRequests[i] }), mockResult));
    }

    // Create system under test with real factory
    JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType); // Using JobDescription ID as fake AsyncApexJob ID for simplicity
    TestFinalizerContext ctx = new TestFinalizerContext(asyncJobId);
    final Integer dmlBefore = Limits.getDmlRows();
    sut.recordJobExecution(testJobsExecuted, ctx);
    final Integer dmlAfter = Limits.getDmlRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(5, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.FAILURE.name() WITH SYSTEM_MODE], '5 JobRequest should have been updated');
    Assert.areEqual(0, [SELECT COUNT() FROM JobRequest__c WHERE Status__c = :ApexJobStatus.SUCCESS.name() WITH SYSTEM_MODE], '6 JobRequest should have been deleted');
    Assert.areEqual(11, [SELECT COUNT() FROM JobDescription__c WITH SYSTEM_MODE], 'All JobDescription should have been updated');
    // 11 updates (JobRequests) + 6 deletes (successful JobRequests) + 11 updates (JobDescriptions) = 28
    Assert.areEqual(28, dmlAfter - dmlBefore, 'Should update all requests for metrics, delete successes, and update descriptions');
  }

  @IsTest
  static void givenRecordJobExecution_whenCalledWithoutCandidates_thenDoesNothing() {
    // Arrange
    JobRepository sut = new JobRepositoryImpl();
    final Integer dmlBeforeAct = Limits.getDmlRows();

    // Act
    Test.startTest();
    sut.recordJobExecution(new List<JobExecuted>(), new TestFinalizerContext(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)));
    Test.stopTest();

    // Assert
    Assert.areEqual(0, Limits.getDmlRows() - dmlBeforeAct, 'Should have 0 save results');
  }

  @IsTest
  static void givenRecordJobExecution_whenCalledWithAsyncJobId_thenPopulateJobIds() {
    // Arrange
    final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').enabled().withMaxChunkSize(-1).build();
    insert as system jobDesc;
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob').withJobDescription(jobDesc.Id).failure().enabled().build();
    jobRequest.JobDescription__r = jobDesc;
    insert as system jobRequest;

    ApexJobResult mockResult = new ApexJobResult(ApexJobStatus.FAILURE);
    mockResult.consumedLimits = ApexJobTestFixture.aLimitsUsage().build();
    List<JobExecuted> testJobsExecuted = new List<JobExecuted>{
      new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequest }), mockResult)
    };

    JobRepository sut = new JobRepositoryImpl();
    Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType); // Using JobDescription ID as fake AsyncApexJob ID for simplicity
    TestFinalizerContext ctx = new TestFinalizerContext(asyncJobId);

    // Act
    Test.startTest();
    sut.recordJobExecution(testJobsExecuted, ctx);

    // Assert
    JobRequest__c updatedJob = [SELECT JobIds__c FROM JobRequest__c WHERE Id = :jobRequest.Id WITH SYSTEM_MODE];
    final String shortId = String.valueOf(asyncJobId).left(15);
    Assert.areEqual(shortId, updatedJob.JobIds__c, 'JobIds__c should be populated with 15-char ID');

    Id anotherAsyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType); // Using JobDescription ID as fake AsyncApexJob ID for simplicity
    ctx = new TestFinalizerContext(anotherAsyncJobId);
    sut.recordJobExecution(testJobsExecuted, ctx);
    Test.stopTest();

    final String anotherShortId = String.valueOf(anotherAsyncJobId).left(15);
    updatedJob = [SELECT JobIds__c FROM JobRequest__c WHERE Id = :jobRequest.Id WITH SYSTEM_MODE];
    Assert.areEqual(shortId + ';' + anotherShortId, updatedJob.JobIds__c, 'JobIds__c should be appended with 15-char IDs');
  }

  @IsTest
  static void givenJobIdsAtCapacity_whenRecordJobExecution_thenOldestDroppedAndNewestAppended() {
    // Arrange
    final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').enabled().withMaxChunkSize(-1).build();
    insert as system jobDesc;
    final List<String> existingIds = new List<String>();
    for (Integer i = 0; i < TRACKED_JOB_ID_CAPACITY; ++i) {
      existingIds.add(String.valueOf(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType)).left(ID_15_LENGTH));
    }
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob').withJobDescription(jobDesc.Id).failure().enabled().build();
    jobRequest.JobDescription__r = jobDesc;
    jobRequest.JobIds__c = String.join(existingIds, ';');
    insert as system jobRequest;

    final ApexJobResult mockResult = new ApexJobResult(ApexJobStatus.FAILURE);
    mockResult.consumedLimits = ApexJobTestFixture.aLimitsUsage().build();
    final List<JobExecuted> testJobsExecuted = new List<JobExecuted>{
      new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequest }), mockResult)
    };
    final JobRepository sut = new JobRepositoryImpl();
    final Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);

    // Act
    Test.startTest();
    sut.recordJobExecution(testJobsExecuted, new TestFinalizerContext(asyncJobId));
    Test.stopTest();

    // Assert
    final List<String> result = [SELECT JobIds__c FROM JobRequest__c WHERE Id = :jobRequest.Id WITH SYSTEM_MODE].JobIds__c.split(';');
    Assert.areEqual(TRACKED_JOB_ID_CAPACITY, result.size(), 'Should keep only the most recent ids');
    Assert.areNotEqual(existingIds[0], result[0], 'Oldest id should be dropped');
    Assert.areEqual(existingIds[1], result[0], 'Second oldest id should now be first');
    Assert.areEqual(String.valueOf(asyncJobId).left(ID_15_LENGTH), result[TRACKED_JOB_ID_CAPACITY - 1], 'Newest id should be appended last');
  }

  @IsTest
  static void givenRolledBackSuccessfulRun_whenRecordJobExecution_thenRequestKeptWithTraceAndJobIdAndDescriptionUpdated() {
    // Arrange
    final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').enabled().withMaxChunkSize(-1).build();
    insert as system jobDesc;
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('TestJob').withJobDescription(jobDesc.Id).ready().withAttemptNumber(0).enabled().build();
    jobRequest.JobDescription__r = jobDesc;
    insert as system jobRequest;
    final ApexJobResult result = new ApexJobResult(ApexJobStatus.SUCCESS);
    result.consumedLimits = ApexJobTestFixture.aLimitsUsage().build();
    final Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    final JobExecuted rolledBack = new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequest }), result)
      .rolledBackBy(asyncJobId, new JobExecuted.RollbackCause(new TestException('Too many DML statements: 151')));
    final JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    sut.recordJobExecution(new List<JobExecuted>{ rolledBack }, new TestFinalizerContext(asyncJobId));
    Test.stopTest();

    // Assert
    final List<JobRequest__c> rows = [SELECT Status__c, AttemptNumber__c, JobIds__c, LastExecutionMessage__c FROM JobRequest__c WHERE Id = :jobRequest.Id WITH SYSTEM_MODE];
    Assert.areEqual(1, rows.size(), 'Rolled-back request must not be deleted');
    Assert.areEqual(ApexJobStatus.READY.name(), rows[0].Status__c, 'Status must stay READY');
    Assert.areEqual(0, rows[0].AttemptNumber__c, 'Attempt number must stay 0');
    Assert.areEqual(String.valueOf(asyncJobId).left(ID_15_LENGTH), rows[0].JobIds__c, 'JobIds__c must carry the failed job id');
    Assert.isTrue(rows[0].LastExecutionMessage__c.startsWith('Rolled back: AsyncApexJob ' + String.valueOf(asyncJobId)), 'Trace must be persisted');
    final JobDescription__c updatedDescription = [SELECT LastExecutionDateTime__c FROM JobDescription__c WHERE Id = :jobDesc.Id WITH SYSTEM_MODE];
    Assert.isNotNull(updatedDescription.LastExecutionDateTime__c, 'Description must still be updated');
  }

  @IsTest
  static void givenFloorKilledChunk_whenRecordJobExecution_thenDescriptionBacksOffAndModelResets() {
    // Arrange
    final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
      .withName('FloorKilledProcessor')
      .withProcessorName('FloorKilledProcessor')
      .enabled()
      .withMaxChunkSize(1)
      .withSmallestFailingChunk(1)
      .build();
    insert as system jobDesc;
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('FloorKilledJob').withJobDescription(jobDesc.Id).ready().withAttemptNumber(0).enabled().build();
    jobRequest.JobDescription__r = jobDesc;
    insert as system jobRequest;
    final ApexJobResult result = new ApexJobResult(ApexJobStatus.KILLED, new ApexJobResult.ApexJobError('Too many DML statements: 151', ''));
    final Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    final JobExecuted killed = new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequest }), result);
    final JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    sut.recordJobExecution(new List<JobExecuted>{ killed }, new TestFinalizerContext(asyncJobId));
    Test.stopTest();

    // Assert
    final JobRequest__c request = [SELECT LastExecutionDateTime__c FROM JobRequest__c WHERE Id = :jobRequest.Id WITH SYSTEM_MODE];
    final JobDescription__c description = [SELECT KillBackoffUntil__c, MaxChunkSize__c FROM JobDescription__c WHERE Id = :jobDesc.Id WITH SYSTEM_MODE];
    Assert.areEqual(
      request.LastExecutionDateTime__c.addMinutes(ApexJobConstant.KILL_BACKOFF_MINUTES),
      description.KillBackoffUntil__c,
      'Backoff must be persisted as kill time plus the backoff period'
    );
    Assert.areEqual(ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE, description.MaxChunkSize__c, 'Model must be reset');
  }

  @IsTest
  static void givenChunkReachingRateLimit_whenRecordJobExecution_thenPersistsLogAndWholeSecondHint() {
    // Arrange
    final JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
      .withName('RateLimitedProcessor')
      .withProcessorName('RateLimitedProcessor')
      .enabled()
      .withMaxChunkSize(-1)
      .withMaxExecutionsPerMinute(1)
      .build();
    insert as system jobDesc;
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('RateLimitedJob').withJobDescription(jobDesc.Id).ready().withAttemptNumber(0).enabled().build();
    jobRequest.JobDescription__r = jobDesc;
    insert as system jobRequest;
    final ApexJobResult result = new ApexJobResult(ApexJobStatus.SUCCESS);
    result.consumedLimits = ApexJobTestFixture.aLimitsUsage()
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
    final Id asyncJobId = TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    final JobExecuted executed = new JobExecuted(new ApexJobFactoryImpl(), new JobExecutable(new ApexJobFactoryImpl(), new List<JobRequest__c>{ jobRequest }), result);
    final JobRepository sut = new JobRepositoryImpl();

    // Act
    Test.startTest();
    sut.recordJobExecution(new List<JobExecuted>{ executed }, new TestFinalizerContext(asyncJobId));
    Test.stopTest();

    // Assert
    final JobDescription__c persisted = [SELECT RateLog__c, RateBlockedUntil__c FROM JobDescription__c WHERE Id = :jobDesc.Id WITH SYSTEM_MODE];
    final Long endMs = jobDesc.LastExecutionDateTime__c.getTime();
    final Long hintMs = persisted.RateBlockedUntil__c.getTime();
    Assert.areEqual(endMs + ':1;', persisted.RateLog__c, 'Log should be persisted with the chunk end and size');
    Assert.areEqual(0, Math.mod(hintMs, 1000), 'Persisted hint should be a whole second');
    Assert.isTrue(hintMs >= endMs + 60000 && hintMs <= endMs + 60999, 'Persisted hint should be the chunk end plus the window, ceiled to the second');
  }

  private class TestException extends Exception {
  }

  private class TestFinalizerContext implements FinalizerContext {
    private Id asyncJobId;
    public TestFinalizerContext(Id asyncJobId) {
      this.asyncJobId = asyncJobId;
    }
    public Id getAsyncApexJobId() {
      return this.asyncJobId;
    }
    public Id getRequestId() {
      return null;
    }
    public System.ParentJobResult getResult() {
      return ParentJobResult.SUCCESS;
    }
    public Exception getException() {
      return null;
    }
  }
}
