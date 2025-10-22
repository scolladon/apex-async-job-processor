@IsTest
private class JobExecutedTest {
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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
    final JobExecutable jobExecutable = new JobExecutable(jobRequests);
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

  // Test exception class
  public class TestException extends Exception {
  }
}
