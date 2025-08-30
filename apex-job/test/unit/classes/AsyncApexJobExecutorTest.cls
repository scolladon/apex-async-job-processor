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
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(Argument.ofType(AsyncApexJobExecutor.class), 0);
    Assert.areNotEqual(sut, mocks.enqueueSpy.callLog.get(0).get(0)); // Ensure it reenqueues a new instance each time
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
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(Argument.ofType(AsyncApexJobExecutor.class), 10);
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
    sut.lastExecutableJob = (JobExecutable) Mock.forType(JobExecutable.class).stub;

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
  }
  @isTest
  static void givenQueueableContext_whenExecuteWithSystemDisabled_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((QueueableContext) null);

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
    sut.execute((QueueableContext) null);

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
    sut.execute((QueueableContext) null);

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
    sut.execute((QueueableContext) null);

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
}
