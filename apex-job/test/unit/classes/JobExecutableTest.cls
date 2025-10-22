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
    final JobExecutable sut = new JobExecutable(mocks.limitServiceStub, jobRequests);
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
    final JobExecutable sut = new JobExecutable(mocks.limitServiceStub, jobRequests);
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
    final JobExecutable sut = new JobExecutable(mocks.limitServiceStub, jobRequests);
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
    final JobExecutable sut = new JobExecutable(mocks.limitServiceStub, jobRequests);

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
    final JobExecutable sut = new JobExecutable(mocks.limitServiceStub, jobRequests);
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
