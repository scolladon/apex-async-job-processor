@isTest
private class AsyncApexJobExecutorTest {
  @isTest
  static void givenFinalizerContext_whenExecuteWithSystemDisabled_thenExecuteDoNotReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @isTest
  static void givenFinalizerContext_whenExecuteWithRemainingJobs_thenExecuteAndReenqueueWith0Delay() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    sut.jobExecutionResults.add((JobExecuted) jobExecutedMock.stub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @isTest
  static void givenFinalizerContext_whenExecuteWithoutRemainingJobs_thenExecuteAndReenqueueWithDelay() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.getEnqueueDelayInMinutesSpy.returns(10);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.getEnqueueDelayInMinutesSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(10);
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @isTest
  static void givenFinalizerContext_whenNotPossibleToReenqueue_thenItLogsAndStopTheQueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.enqueueSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
  }

  @isTest
  static void givenFinalizerContext_whenEnabledAndRecordExecutionThrows_thenItReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'));
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
  }

  @isTest
  static void givenFinalizerContext_whenSystemIsDisabledThrows_thenItCallsLoggerError() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
  }

  class KilledFinalizerContext implements FinalizerContext {
    public Id getAsyncApexJobId() {
      return null;
    }
    public Id getRequestId() {
      return null;
    }
    public System.ParentJobResult getResult() {
      return ParentJobResult.UNHANDLED_EXCEPTION;
    }
    public Exception getException() {
      return new TestException('Killed');
    }
  }

  @isTest
  static void givenFinalizerContext_whenExceptionOccurs_thenItRecordsJobExecutionAndReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('KilledPathJob').withProcessorName('AsyncApexJobExecutorTest.KilledPathJob').withMinJobInterval(3).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Req').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobs = new List<JobRequest__c>{ jobRequest };
    sut.lastExecutableJob = new JobExecutable(jobs);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);

    // Validate timestamps propagated when staging
    final List<Object> args = mocks.recordJobExecutionSpy.callLog.get(0);
    final List<JobExecuted> recorded = (List<JobExecuted>) args.get(0);
    Assert.areEqual(1, recorded.size(), 'One job executed should be recorded');
    final JobExecuted captured = recorded[0];
    captured.stageExecution();
    final JobRequest__c staged = jobs[0];
    Assert.isNotNull(staged.LastSelectionDateTime__c, 'Selection time should be set from executable');
    Assert.isNotNull(staged.LastExecutionDateTime__c, 'End time should fallback to now in killed path');
    Assert.isTrue(staged.LastSelectionDateTime__c.getTime() <= staged.LastExecutionDateTime__c.getTime(), 'Selection <= End');
    Assert.areEqual(staged.LastExecutionDateTime__c.addMinutes(3), staged.NextExecutionDateTime__c, 'Next try from end + interval');
  }
  @isTest
  static void givenQueueableContext_whenExecuteWithSystemDisabled_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  @isTest
  static void givenQueueableContext_whenNoJobToExecute_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(1);
  }

  @isTest
  static void givenQueueableContext_whenJobCandidatesPrepareChunkSuccessfully_thenExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    final Mock jobExecutableMock = Mock.forType(JobExecutable.class);
    final MethodSpy executeChunkSpy = jobExecutableMock.spyOn('executeChunk');
    executeChunkSpy.returns(jobExecutedMock.stub);

    final Mock jobCandidateMock = Mock.forType(JobCandidate.class);
    jobCandidateMock.spyOn('isExecutable').returns(true);
    jobCandidateMock.spyOn('getExecutableChunk').returns((JobExecutable) jobExecutableMock.stub);

    mocks.getJobCandidatesSpy.returnsOnce(new List<JobCandidate>{ (JobCandidate) jobCandidateMock.stub });
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);

    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(2);
    Expect.that(executeChunkSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  @isTest
  static void givenQueueableContext_whenJobCandidatesPrepareChunkFails_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    final Mock jobExecutableMock = Mock.forType(JobExecutable.class);
    final MethodSpy executeChunkSpy = jobExecutableMock.spyOn('executeChunk');
    executeChunkSpy.returns(jobExecutedMock.stub);

    final Mock jobCandidateMock = Mock.forType(JobCandidate.class);
    jobCandidateMock.spyOn('isExecutable').returns(false);

    mocks.getJobCandidatesSpy.returnsOnce(new List<JobCandidate>{ (JobCandidate) jobCandidateMock.stub });
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);

    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(1);
    Expect.that(executeChunkSpy).hasNotBeenCalled();
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  private class TestException extends Exception {
  }

  private class QueueableContextStub implements QueueableContext {
    public Id getJobId() {
      return TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    }
  }
}
