@IsTest
private class JobExecutableTest {
  @IsTest
  static void givenExecuteChunk_whenJobSucceeds_thenReturnsJobExecutedWithSuccess() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage expectedConsumedLimits = ApexJobTestFixture.aLimitsUsage()
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

    mocks.stopSnapshotSpy.returns(expectedConsumedLimits);

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('TestApexJob')
      .withProcessorName('JobExecutableTest.TestApexJob')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);
    Assert.isFalse(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should not have executed jobs');

    // Act
    final JobExecuted result = sut.executeChunk();

    // Assert
    Assert.isNotNull(result.jobExecutionResult, 'Should return JobExecuted');
    Assert.areEqual(jobDescription, result.jobDescription, 'JobExecuted should have same job description');
    Assert.areEqual(jobRequests, result.jobRequests, 'JobExecuted should have same job requests');
    Expect.that(mocks.startSnapshotSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.stopSnapshotSpy).hasBeenCalledTimes(1);
    Assert.isTrue(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should have executed jobs');
  }

  @IsTest
  static void givenExecuteChunk_whenJobFails_thenReturnsJobExecutedWithFailure() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('FailingTestApexJob')
      .withProcessorName('JobExecutableTest.FailingTestApexJob')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);
    Assert.isFalse(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should not have executed jobs');

    // Act
    final JobExecuted result = sut.executeChunk();

    // Assert
    Assert.areEqual(ApexJobStatus.FAILURE, result.jobExecutionResult.status, 'Should return JobExecuted');
    Assert.areEqual(jobDescription, result.jobDescription, 'JobExecuted should have same job description');
    Assert.areEqual(jobRequests, result.jobRequests, 'JobExecuted should have same job requests');
    Expect.that(mocks.startSnapshotSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.stopSnapshotSpy).hasBeenCalledTimes(1);
    Assert.isTrue(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should have executed jobs');
  }

  @IsTest
  static void givenExecuteChunk_whenJobThrows_thenReturnsJobExecutedWithException() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('ThrowingTestApexJob')
      .withProcessorName('JobExecutableTest.ThrowingTestApexJob')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);
    Assert.isFalse(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should not have executed jobs');

    // Act
    final JobExecuted result = sut.executeChunk();

    // Assert
    Assert.areEqual(ApexJobStatus.FAILURE, result.jobExecutionResult.status, 'Should return JobExecuted');
    Assert.areEqual(jobDescription, result.jobDescription, 'JobExecuted should have same job description');
    Assert.areEqual(jobRequests, result.jobRequests, 'JobExecuted should have same job requests');
    Expect.that(mocks.startSnapshotSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.stopSnapshotSpy).hasBeenCalledTimes(1);
    Assert.isTrue(ApexJobTransactionContext.getInstance().hasExecutedJobs, 'Should have executed jobs');
  }

  @IsTest
  static void givenExecuteChunk_whenProcessorNameInvalid_thenThrowsDescriptiveException() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('InvalidProcessor')
      .withProcessorName('NonExistentClassName')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);

    // Act
    try {
      sut.executeChunk();
      Assert.fail('Should have thrown IllegalArgumentException');
    } catch (IllegalArgumentException e) {
      // Assert
      Assert.isTrue(e.getMessage().contains('NonExistentClassName'), 'Exception should contain the invalid class name');
      Assert.isTrue(e.getMessage().contains('Processor class not found'), 'Exception should contain descriptive message');
    }
  }

  // Test ApexJob implementations
  public class TestApexJob implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  public class FailingTestApexJob implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      return new ApexJobResult(new TestException('Test failure'));
    }
  }

  public class ThrowingTestApexJob implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      throw new TestException('Test exception');
    }
  }

  public class TestException extends Exception {
  }

  @IsTest
  static void givenAllMalformedChunk_whenExecuteChunk_thenProcessorNotCalledAndResultStatusIsMalformed() {
    // Arrange — parser returns two malformed entries, zero valid.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobRequest__c request1 = ApexJobTestFixture.aJobRequest().withName('req1').withArgument('bad-json-1').build();
    request1.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    final JobRequest__c request2 = ApexJobTestFixture.aJobRequest().withName('req2').withArgument('bad-json-2').build();
    request2.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    request1.JobDescription__r = ApexJobTestFixture.aJobDescription().withProcessorName('JobExecutableTest.TestApexJob').build();
    request2.JobDescription__r = request1.JobDescription__r;
    final JobRequestArgumentParser.ParseResult allMalformed = new JobRequestArgumentParser.ParseResult();
    allMalformed.malformedErrors.put(request1.Id, 'Unexpected character at pos 1');
    allMalformed.malformedErrors.put(request2.Id, 'Unexpected character at pos 1');
    mocks.parseSpy.returns(allMalformed);

    final JobExecutable sut = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ request1, request2 });

    // Act
    final JobExecuted executed = sut.executeChunk();

    // Assert
    Assert.areEqual(ApexJobStatus.MALFORMED_ARGUMENT, executed.jobExecutionResult.status, 'All-malformed chunk must return MALFORMED_ARGUMENT status');
    Assert.areEqual(2, executed.jobExecutionResult.malformedRequestErrors.size(), 'Both request Ids must be recorded in malformedRequestErrors');
  }

  @IsTest
  static void givenMixedChunk_whenExecuteChunk_thenProcessorCalledAndMalformedPropagated() {
    // Arrange — parser returns one valid argument, one malformed entry.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobRequest__c valid = ApexJobTestFixture.aJobRequest().withName('valid').withArgument('{"ok":true}').build();
    valid.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    final JobRequest__c malformed = ApexJobTestFixture.aJobRequest().withName('bad').withArgument('not-json').build();
    malformed.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    valid.JobDescription__r = ApexJobTestFixture.aJobDescription().withProcessorName('JobExecutableTest.TestApexJob').build();
    malformed.JobDescription__r = valid.JobDescription__r;
    final JobRequestArgumentParser.ParseResult mixed = new JobRequestArgumentParser.ParseResult();
    mixed.validArguments.add(new Map<String, Object>{ 'ok' => true });
    mixed.malformedErrors.put(malformed.Id, 'Unexpected character');
    mocks.parseSpy.returns(mixed);

    final JobExecutable sut = new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ valid, malformed });

    // Act
    final JobExecuted executed = sut.executeChunk();

    // Assert
    Assert.areEqual(ApexJobStatus.SUCCESS, executed.jobExecutionResult.status, 'Processor succeeded for the valid portion of the chunk');
    Assert.areEqual(1, executed.jobExecutionResult.malformedRequestErrors.size(), 'Only the malformed request is tracked');
    Assert.isTrue(executed.jobExecutionResult.malformedRequestErrors.containsKey(malformed.Id), 'Malformed entry keyed by the malformed request Id');
  }

  @IsTest
  static void givenNewExecutable_whenGetters_thenSelectionSetAndEndFallsBackToNow() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('GetterTestApexJob')
      .withProcessorName('JobExecutableTest.TestApexJob')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);

    // Act
    final Datetime selectionTime = sut.getSelectionTime();
    final Datetime endTime = sut.getEndTime();

    // Assert
    Assert.isNotNull(selectionTime, 'Selection time should be set at construction');
    Assert.isNotNull(endTime, 'End time should fallback to now before execution');
    Assert.isTrue(endTime.getTime() >= selectionTime.getTime(), 'End should be >= selection');
  }

  @IsTest
  static void givenExecuteChunk_whenEnds_thenEndTimeSetAndGteSelection() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withId(TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType))
      .withName('GetterExecApexJob')
      .withProcessorName('JobExecutableTest.TestApexJob')
      .build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>{ jobRequest };
    final JobExecutable sut = new JobExecutable(mocks.factoryStub, jobRequests);
    final Long beforeEnd = System.now().getTime();

    // Act
    sut.executeChunk();
    final Datetime selectionTime = sut.getSelectionTime();
    final Datetime endTime = sut.getEndTime();

    // Assert
    Assert.isNotNull(selectionTime, 'Selection time should be set');
    Assert.isNotNull(endTime, 'End time should be set after execution');
    Assert.isTrue(endTime.getTime() >= selectionTime.getTime(), 'End should be >= selection');
    Assert.isTrue(endTime.getTime() >= beforeEnd, 'End should be after test start');
  }
}
