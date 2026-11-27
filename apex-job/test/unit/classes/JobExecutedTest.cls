@IsTest
private class JobExecutedTest {
  private static final Id FAILED_JOB_ID = TestDataFactory.generateUniqueFakeId(AsyncApexJob.SObjectType);
  private static final String CAUSE_MESSAGE = 'Too many DML statements: 151';
  private static final Integer LAST_EXECUTION_MESSAGE_LENGTH = 131072;

  @IsTest
  static void givenStageExecution_whenJobSucceeds_thenRecordsSuccess() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(100)
      .withHeapSize(1000)
      .withCallout(0)
      .withCalloutTime(0)
      .withPublishImmediateDml(0)
      .withDmlRows(1)
      .withDmlStatements(1)
      .withQueryRows(10)
      .withQueries(1)
      .withSoslQueries(0)
      .withFutureCalls(0)
      .build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestApexJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.SUCCESS.name(), jobRequest.Status__c, 'Job request status should be SUCCESS');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution datetime should be set');
    Assert.isNull(jobRequest.NextExecutionDateTime__c, 'Next execution datetime should be null for success');
    Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Last selection datetime should be set');
    Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    Assert.areEqual('', jobRequest.LastExecutionMessage__c, 'Last execution message should be empty for success');
    Assert.isTrue(jobRequest.WaitTime__c >= 0, 'Wait time should be >= 0');
    Assert.areEqual(
      (Decimal) (jobRequest.LastExecutionDateTime__c.getTime() - jobRequest.LastSelectionDateTime__c.getTime()),
      jobRequest.ChunkRunTime__c,
      'Run time should equal end - selection in ms'
    );
    Assert.isTrue(jobRequest.ProcessingTime__c >= jobRequest.ChunkRunTime__c, 'Processing time should be >= run time');
    Assert.isTrue(jobRequest.ChunkRunTime__c >= jobRequest.UnitRunTime__c, 'Chunk run time should be >= unit run time');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromSuccessSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenStageExecution_whenJobFails_thenRecordsFailure() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('FailingTestApexJob')
      .withProcessorName('JobExecutedTest.FailingTestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionAttempt(3)
      .withMinJobInterval(5)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(new TestException('Test failure'));
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.FAILURE.name(), jobRequest.Status__c, 'Job request status should be FAILURE');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution datetime should be set');
    Assert.isNotNull(jobRequest.NextExecutionDateTime__c, 'Next execution datetime should be set for retry');
    Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Last selection datetime should be set');
    Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    Assert.isTrue(jobRequest.LastExecutionMessage__c.contains('Test failure'), 'Last execution message should contain error');
    Assert.isTrue(jobRequest.WaitTime__c >= 0, 'Wait time should be >= 0');
    Assert.areEqual(
      (Decimal) (jobRequest.LastExecutionDateTime__c.getTime() - jobRequest.LastSelectionDateTime__c.getTime()),
      jobRequest.ChunkRunTime__c,
      'Run time should equal end - selection in ms'
    );
    Assert.isTrue(jobRequest.ProcessingTime__c >= jobRequest.ChunkRunTime__c, 'Processing time should be >= run time');
    Assert.isTrue(jobRequest.ChunkRunTime__c >= jobRequest.UnitRunTime__c, 'Chunk run time should be >= unit run time');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromFailureSpy).hasBeenCalled();
  }

  @IsTest
  static void givenStageExecution_whenJobKilled_thenRecordsKilled() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('KillingTestApexJob')
      .withProcessorName('JobExecutedTest.KillingTestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionAttempt(3)
      .withMinJobInterval(5)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.KILLED, new ApexJobResult.ApexJobError('Test killed', ''));
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.KILLED.name(), jobRequest.Status__c, 'Job request status should be KILLED');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution datetime should be set');
    Assert.isNotNull(jobRequest.NextExecutionDateTime__c, 'Next execution datetime should be set for retry');
    Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Last selection datetime should be set');
    Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    Assert.isTrue(jobRequest.LastExecutionMessage__c.contains('Test killed'), 'Last execution message should contain error');
    Assert.isTrue(jobRequest.WaitTime__c >= 0, 'Wait time should be >= 0');
    Assert.areEqual(
      (Decimal) (jobRequest.LastExecutionDateTime__c.getTime() - jobRequest.LastSelectionDateTime__c.getTime()),
      jobRequest.ChunkRunTime__c,
      'Run time should equal end - selection in ms'
    );
    Assert.isTrue(jobRequest.ProcessingTime__c >= jobRequest.ChunkRunTime__c, 'Processing time should be >= run time');
    Assert.isTrue(jobRequest.ChunkRunTime__c >= jobRequest.UnitRunTime__c, 'Chunk run time should be >= unit run time');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromKillSpy).hasBeenCalled();
  }

  @IsTest
  static void givenStageExecution_whenJobFailsTooMuch_thenRecordsAbort() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('FailingTestApexJob')
      .withProcessorName('JobExecutedTest.FailingTestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionAttempt(2)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(1).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(new TestException('Test failure'));
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.ABORTED.name(), jobRequest.Status__c, 'Job request status should be ABORTED');
    Assert.areEqual(2, jobRequest.AttemptNumber__c, 'Attempt number should be at max');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution datetime should be set');
    Assert.isNull(jobRequest.NextExecutionDateTime__c, 'Next execution datetime should be null for abort');
    Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Last selection datetime should be set');
    Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    Assert.isTrue(jobRequest.LastExecutionMessage__c.contains('Max execution attempt reached'), 'Should contain max attempt message');
    Assert.isTrue(jobRequest.LastExecutionMessage__c.contains('Test failure'), 'Should contain error message');
    Assert.isTrue(jobRequest.WaitTime__c >= 0, 'Wait time should be >= 0');
    Assert.areEqual(
      (Decimal) (jobRequest.LastExecutionDateTime__c.getTime() - jobRequest.LastSelectionDateTime__c.getTime()),
      jobRequest.ChunkRunTime__c,
      'Run time should equal end - selection in ms'
    );
    Assert.isTrue(jobRequest.ProcessingTime__c >= jobRequest.ChunkRunTime__c, 'Processing time should be >= run time');
    Assert.isTrue(jobRequest.ChunkRunTime__c >= jobRequest.UnitRunTime__c, 'Chunk run time should be >= unit run time');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromFailureSpy).hasBeenCalled();
  }

  @IsTest
  static void givenStageExecution_whenMultipleJobRequests_thenStagesAll() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(100)
      .withHeapSize(1000)
      .withCallout(0)
      .withCalloutTime(0)
      .withPublishImmediateDml(0)
      .withDmlRows(1)
      .withDmlStatements(1)
      .withQueryRows(10)
      .withQueries(1)
      .withSoslQueries(0)
      .withFutureCalls(0)
      .build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestApexJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(3).build();
    final JobRequest__c jobRequest1 = ApexJobTestFixture.aJobRequest().withName('Test1').withAttemptNumber(0).build();
    jobRequest1.JobDescription__r = jobDescription;
    final JobRequest__c jobRequest2 = ApexJobTestFixture.aJobRequest().withName('Test2').withAttemptNumber(1).build();
    jobRequest2.JobDescription__r = jobDescription;
    final JobRequest__c jobRequest3 = ApexJobTestFixture.aJobRequest().withName('Test3').withAttemptNumber(0).build();
    jobRequest3.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest1, jobRequest2, jobRequest3 };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    for (JobRequest__c jobRequest : jobRequests) {
      Assert.areEqual(ApexJobStatus.SUCCESS.name(), jobRequest.Status__c, 'All job requests should have SUCCESS status');
      Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'All job requests should have last execution datetime');
      Assert.isNull(jobRequest.NextExecutionDateTime__c, 'All job requests should have null next execution datetime');
      Assert.areEqual('', jobRequest.LastExecutionMessage__c, 'All job requests should have empty message');
      Assert.isTrue(jobRequest.WaitTime__c >= 0, 'Wait time should be >= 0');
      Assert.areEqual(
        (Decimal) (jobRequest.LastExecutionDateTime__c.getTime() - jobRequest.LastSelectionDateTime__c.getTime()),
        jobRequest.ChunkRunTime__c,
        'Run time should equal end - selection in ms'
      );
      Assert.isTrue(jobRequest.ProcessingTime__c >= jobRequest.ChunkRunTime__c, 'Processing time should be >= run time');
      Assert.isTrue(jobRequest.ChunkRunTime__c >= jobRequest.UnitRunTime__c, 'Chunk run time should be >= unit run time');
      Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'All job requests should have last selection datetime');
      Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    }
    Assert.areEqual(1, jobRequests[0].AttemptNumber__c, 'First job request attempt should be 1');
    Assert.areEqual(2, jobRequests[1].AttemptNumber__c, 'Second job request attempt should be 2');
    Assert.areEqual(1, jobRequests[2].AttemptNumber__c, 'Third job request attempt should be 1');
    Expect.that(mocks.adjustFromSuccessSpy).hasBeenCalled();
  }

  @IsTest
  static void givenStageExecution_whenAborted_thenAdjustsFromFailure() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestApexJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.ABORTED);
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.ABORTED.name(), jobRequest.Status__c, 'Job request status should be ABORTED');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution datetime should be set');
    Assert.isNull(jobRequest.NextExecutionDateTime__c, 'Next execution datetime should be null for abort');
    Assert.areEqual('', jobRequest.LastExecutionMessage__c, 'Last execution message should be empty for direct abort');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromFailureSpy).hasBeenCalled();
  }

  @IsTest
  static void givenStageExecution_whenRecurrentJobEnds_thenRecordsExecutionAndMarkReady() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(100)
      .withHeapSize(1000)
      .withCallout(0)
      .withCalloutTime(0)
      .withPublishImmediateDml(0)
      .withDmlRows(1)
      .withDmlStatements(1)
      .withQueryRows(10)
      .withQueries(1)
      .withSoslQueries(0)
      .withFutureCalls(0)
      .build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestApexJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).recurrent().build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.READY.name(), jobRequest.Status__c, 'Job request status should be READY');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
    Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'Last execution date time should be set');
    Assert.isNotNull(jobRequest.NextExecutionDateTime__c, 'Next execution date time should be set');
    Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Last selection datetime should be set');
    Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
    Assert.areEqual(jobRequest.LastExecutionDateTime__c.addMinutes((Integer) jobDescription.MinJobInterval__c), jobRequest.NextExecutionDateTime__c, 'Next should be end + interval');
    Assert.areEqual('', jobRequest.LastExecutionMessage__c, 'Last execution message should be empty for success');
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Job description last execution datetime should be set');
    Expect.that(mocks.adjustFromSuccessSpy).hasBeenCalled();
  }

  @IsTest
  static void givenRateLimitConfigured_whenJobSucceeds_thenUpdatesCounter() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).withHeapSize(1000).build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestApexJob')
      .withProcessorName('JobExecutedTest.TestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionsPerMinute(100)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(1, jobDescription.ExecutionsInCurrentWindow__c, 'Counter should be set to chunk size for fresh window');
    Assert.isNotNull(jobDescription.CurrentWindowStart__c, 'Window start should be set');
  }

  @IsTest
  static void givenRateLimitWithActiveWindow_whenJobSucceeds_thenIncrementsCounter() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).withHeapSize(1000).build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestApexJob')
      .withProcessorName('JobExecutedTest.TestApexJob')
      .withMaxChunkSize(5)
      .withMaxExecutionsPerMinute(100)
      .withExecutionsInCurrentWindow(10)
      .withCurrentWindowStart(System.now())
      .build();
    final JobRequest__c jobRequest1 = ApexJobTestFixture.aJobRequest().withName('Test1').withAttemptNumber(0).build();
    jobRequest1.JobDescription__r = jobDescription;
    final JobRequest__c jobRequest2 = ApexJobTestFixture.aJobRequest().withName('Test2').withAttemptNumber(0).build();
    jobRequest2.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest1, jobRequest2 };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(12, jobDescription.ExecutionsInCurrentWindow__c, 'Counter should be incremented by chunk size (10 + 2)');
  }

  @IsTest
  static void givenRateLimitWithExpiredWindow_whenJobSucceeds_thenResetsCounter() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).withHeapSize(1000).build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestApexJob')
      .withProcessorName('JobExecutedTest.TestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionsPerMinute(100)
      .withExecutionsInCurrentWindow(50)
      .withCurrentWindowStart(System.now().addMinutes(-2))
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(1, jobDescription.ExecutionsInCurrentWindow__c, 'Counter should be reset to chunk size for expired window');
    Assert.isTrue(jobDescription.CurrentWindowStart__c.getTime() > System.now().addMinutes(-1).getTime(), 'Window start should be refreshed to recent time');
  }

  @IsTest
  static void givenNoRateLimit_whenJobSucceeds_thenCounterUnchanged() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage consumedLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).withHeapSize(1000).build();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestApexJob')
      .withProcessorName('JobExecutedTest.TestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionsPerMinute(0)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = consumedLimits;
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(0, jobDescription.ExecutionsInCurrentWindow__c, 'Counter should remain 0 when rate limiting is disabled');
    Assert.isNull(jobDescription.CurrentWindowStart__c, 'Window start should remain null when rate limiting is disabled');
  }

  @IsTest
  static void givenChunkWithMalformedRequest_whenStageExecution_thenThatRequestTaggedTerminalAndValidFollowsChunkResult() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('ChunkWithMalformed').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c validRequest = ApexJobTestFixture.aJobRequest().withName('valid').withAttemptNumber(0).build();
    validRequest.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    validRequest.JobDescription__r = jobDescription;
    final JobRequest__c malformedRequest = ApexJobTestFixture.aJobRequest().withName('bad').withAttemptNumber(0).build();
    malformedRequest.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    malformedRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ validRequest, malformedRequest };
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, jobRequests);
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.SUCCESS);
    jobResult.consumedLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(100).build();
    jobResult.malformedRequestErrors = new Map<Id, String>{ malformedRequest.Id => 'Unexpected character at pos 1' };
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.MALFORMED_ARGUMENT.name(), malformedRequest.Status__c, 'Malformed request must be terminal-failed with MALFORMED_ARGUMENT status');
    Assert.areEqual('Unexpected character at pos 1', malformedRequest.LastExecutionMessage__c, 'Malformed request carries the parser error message');
    Assert.isNull(malformedRequest.NextExecutionDateTime__c, 'Malformed request must not be retried');
    Assert.areEqual(ApexJobStatus.SUCCESS.name(), validRequest.Status__c, 'Valid request must follow the chunk-level SUCCESS result');
  }

  @IsTest
  static void givenAllMalformedChunk_whenStageExecution_thenConsumptionLearnerNotInvoked() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('AllMalformed').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c malformedRequest = ApexJobTestFixture.aJobRequest().withName('bad').withAttemptNumber(0).build();
    malformedRequest.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    malformedRequest.JobDescription__r = jobDescription;
    final JobExecutable jobExecutable = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ malformedRequest });
    final ApexJobResult jobResult = new ApexJobResult(ApexJobStatus.MALFORMED_ARGUMENT);
    jobResult.malformedRequestErrors = new Map<Id, String>{ malformedRequest.Id => 'bad' };
    final JobExecuted sut = new JobExecuted(mocks.factoryStub, jobExecutable, jobResult);

    // Act
    sut.stageExecution();

    // Assert
    Expect.that(mocks.adjustFromSuccessSpy).hasNotBeenCalled();
    Expect.that(mocks.adjustFromFailureSpy).hasNotBeenCalled();
    Expect.that(mocks.adjustFromKillSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenSuccessfulRunRolledBack_whenStageExecution_thenRequestKeepsStatusAttemptAndNextExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Datetime nextExecution = Datetime.newInstance(2030, 1, 1, 8, 0, 0);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(2).withNextExecutionDateTime(nextExecution).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.READY.name(), jobRequest.Status__c, 'Status must stay READY');
    Assert.areEqual(2, jobRequest.AttemptNumber__c, 'Attempt number must not be incremented');
    Assert.areEqual(nextExecution, jobRequest.NextExecutionDateTime__c, 'Next execution must be unchanged');
  }

  @IsTest
  static void givenRunRolledBack_whenStageExecution_thenRequestMessageNamesFailedJobExceptionCalloutsAndImmediateEvents() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    final String message = jobRequest.LastExecutionMessage__c;
    Assert.isTrue(message.startsWith('Rolled back: AsyncApexJob ' + String.valueOf(FAILED_JOB_ID)), message);
    Assert.isTrue(message.contains('JobExecutedTest.TestException: ' + CAUSE_MESSAGE), message);
    Assert.isTrue(message.contains('Callouts made: 2.'), message);
    Assert.isTrue(message.contains('Immediate events published: 1.'), message);
    Assert.isTrue(message.endsWith('The chunk will run again.'), message);
  }

  @IsTest
  static void givenRunRolledBack_whenStageExecution_thenTimingFieldsUntouched() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Assert.isNull(jobRequest.WaitTime__c, 'Wait time untouched');
    Assert.isNull(jobRequest.ChunkRunTime__c, 'Chunk run time untouched');
    Assert.isNull(jobRequest.UnitRunTime__c, 'Unit run time untouched');
    Assert.isNull(jobRequest.ProcessingTime__c, 'Processing time untouched');
    Assert.isNull(jobRequest.LastSelectionDateTime__c, 'Last selection untouched');
    Assert.isNull(jobRequest.LastExecutionDateTime__c, 'Last execution untouched');
  }

  @IsTest
  static void givenOversizedExceptionMessage_whenRolledBack_thenMessageTruncatedToFieldLength() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException('x'.repeat(LAST_EXECUTION_MESSAGE_LENGTH)));

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(LAST_EXECUTION_MESSAGE_LENGTH, jobRequest.LastExecutionMessage__c.length(), 'Message must be truncated to the field length');
  }

  @IsTest
  static void givenRolledBackRun_whenDescribeRollback_thenNamesDescriptionRequestIdsAndTrace() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c first = ApexJobTestFixture.aJobRequest().withName('first').withAttemptNumber(0).build();
    first.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    final JobRequest__c second = ApexJobTestFixture.aJobRequest().withName('second').withAttemptNumber(0).build();
    second.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ first, second }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    final String result = sut.describeRollback();

    // Assert
    final String expectedPrefix = 'RolledBackJob (' + String.valueOf(first.Id) + ', ' + String.valueOf(second.Id) + '): Rolled back: AsyncApexJob ' + String.valueOf(FAILED_JOB_ID);
    Assert.isTrue(result.startsWith(expectedPrefix), result);
  }

  @IsTest
  static void givenSuccessfulRunRolledBack_whenStageExecution_thenLearnerAdjustsFromSuccessWithMeasuredLimits() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final ApexJobResult result = buildMeasuredResult(ApexJobStatus.SUCCESS);
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), result).rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Expect.that(mocks.adjustFromSuccessSpy).hasBeenCalledWith(result.consumedLimits, 1);
  }

  @IsTest
  static void givenFailedRunRolledBack_whenStageExecution_thenLearnerAdjustsFromFailureWithMeasuredLimits() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withStatus(ApexJobStatus.FAILURE).withAttemptNumber(1).build();
    final ApexJobResult result = new ApexJobResult(new TestException('boom'));
    result.consumedLimits = ApexJobTestFixture.aLimitsUsage().withCallout(2).withPublishImmediateDml(1).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), result).rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Expect.that(mocks.adjustFromFailureSpy).hasBeenCalledWith(result.consumedLimits, 1);
    Assert.areEqual(ApexJobStatus.FAILURE.name(), jobRequest.Status__c, 'Status must stay FAILURE');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number must not be incremented');
  }

  @IsTest
  static void givenMalformedRunRolledBack_whenStageExecution_thenRequestKeepsStatusAndLearnerNotInvoked() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('bad').withAttemptNumber(0).build();
    jobRequest.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    final ApexJobResult result = buildMeasuredResult(ApexJobStatus.MALFORMED_ARGUMENT);
    result.malformedRequestErrors = new Map<Id, String>{ jobRequest.Id => 'bad' };
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), result).rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.READY.name(), jobRequest.Status__c, 'Malformed row must not be marked terminal');
    Assert.isTrue(jobRequest.LastExecutionMessage__c.startsWith('Rolled back: AsyncApexJob '), 'Trace must be written');
    Expect.that(mocks.adjustFromSuccessSpy).hasNotBeenCalled();
    Expect.that(mocks.adjustFromFailureSpy).hasNotBeenCalled();
    Expect.that(mocks.adjustFromKillSpy).hasNotBeenCalled();
    Assert.isNotNull(jobDescription.LastExecutionDateTime__c, 'Description last execution must be set');
  }

  @IsTest
  static void givenRateLimitConfigured_whenRolledBackRunStaged_thenWindowCountsChunkSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('RolledBackJob')
      .withProcessorName('JobExecutedTest.TestApexJob')
      .withMaxChunkSize(2)
      .withMaxExecutionsPerMinute(100)
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS))
      .rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(1, jobDescription.ExecutionsInCurrentWindow__c, 'Counter should be set to chunk size for fresh window');
    Assert.isNotNull(jobDescription.CurrentWindowStart__c, 'Window start should be set');
  }

  @IsTest
  static void givenCompletedRun_whenRolledBackBy_thenOriginalEntryStagesAsBefore() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('RolledBackJob').withProcessorName('JobExecutedTest.TestApexJob').withMaxChunkSize(2).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').withAttemptNumber(0).build();
    final JobExecuted sut = buildCompletedRun(mocks, attachDescription(jobDescription, new List<JobRequest__c>{ jobRequest }), buildMeasuredResult(ApexJobStatus.SUCCESS));
    sut.rolledBackBy(FAILED_JOB_ID, new TestException(CAUSE_MESSAGE));

    // Act
    sut.stageExecution();

    // Assert
    Assert.areEqual(ApexJobStatus.SUCCESS.name(), jobRequest.Status__c, 'Original entry must still complete the request');
    Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number must be incremented');
    Assert.areEqual('', jobRequest.LastExecutionMessage__c, 'Message must be empty for success');
  }

  private static ApexJobResult buildMeasuredResult(final ApexJobStatus status) {
    final ApexJobResult result = new ApexJobResult(status);
    result.consumedLimits = ApexJobTestFixture.aLimitsUsage().withCallout(2).withPublishImmediateDml(1).build();
    return result;
  }

  private static List<JobRequest__c> attachDescription(final JobDescription__c description, final List<JobRequest__c> requests) {
    for (JobRequest__c request : requests) {
      request.JobDescription__r = description;
    }
    return requests;
  }

  private static JobExecuted buildCompletedRun(final ApexJobTestMock mocks, final List<JobRequest__c> requests, final ApexJobResult result) {
    return new JobExecuted(mocks.factoryStub, new JobExecutable(mocks.factoryStub, requests), result);
  }

  // Test exception class
  public class TestException extends Exception {
  }
}
