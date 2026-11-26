@IsTest
private class JobExecutorQueueableSpawnerTest {
  @IsTest
  static void givenJobExecutorQueueableSpawner_whenAlreadyQueued_thenJobNotEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(true);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = 5;

    // Act
    Test.startTest();
    System.enqueueJob(new AsyncApexJobExecutor());
    Id jobId = sut.enqueue(delayInMinutes);
    Test.stopTest();

    // Assert
    Assert.isNull(jobId);
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenQueuedWithSameSignature_thenJobNotEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = 5;

    // Act
    Test.startTest();
    AsyncOptions options = new AsyncOptions();
    options.MinimumQueueableDelayInMinutes = delayInMinutes;
    options.DuplicateSignature = QueueableDuplicateSignature.Builder().addInteger(delayInMinutes).addString(AsyncApexJobExecutor.class.getName()).build();
    System.enqueueJob(new AsyncApexJobExecutor(), options);
    Id jobId = sut.enqueue(delayInMinutes);
    Test.stopTest();

    // Assert
    Assert.isNull(jobId);
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWithDelay_thenJobEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = 5;

    // Act
    Id jobId = sut.enqueue(delayInMinutes);

    // Assert
    Assert.isNotNull(jobId);
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWithMinus1_thenJobNotEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = -1;

    // Act
    try {
      sut.enqueue(delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.InvalidParameterValueException e) {
      Assert.areEqual('Delay must be greater than or equal to 0 minutes', e.getMessage());
    }
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWith11_thenJobNotEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = 11;

    // Act
    try {
      sut.enqueue(delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.InvalidParameterValueException e) {
      Assert.areEqual('Delay must be less than or equal to 10 minutes', e.getMessage());
    }
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueueWithNullDelay_thenJobEnqueued() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);
    Integer delayInMinutes = null;

    // Act
    try {
      sut.enqueue(delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.InvalidParameterValueException e) {
      Assert.areEqual('Cannot add null to a deduplication signature', e.getMessage());
    }
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueueWithoutDelay_thenGetDefaultDelay() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);

    // Act
    sut.enqueue();

    // Assert
    Expect.that(mocks.getEnqueueDelayInMinutesSpy).hasBeenCalled();
  }

  @IsTest
  static void givenWakeUpAlreadyAttempted_whenWakeUpAgain_thenIsRunningQueriedOnce() {
    // Arrange
    ApexJobTransactionContext.reset();
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(true);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);

    // Act
    sut.wakeUp();
    sut.wakeUp();

    // Assert
    Expect.that(mocks.isRunningSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenNoQueueableSlotLeft_whenEnqueue_thenReturnsNullWithoutQuery() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.isRunningSpy.returns(false);
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner(mocks.factoryStub);

    // Act
    Test.startTest();
    enqueueNoOpJobs(Limits.getLimitQueueableJobs());
    final Id result = sut.enqueue(0);
    Test.stopTest();

    // Assert
    Assert.isNull(result);
    Expect.that(mocks.isRunningSpy).hasNotBeenCalled();
  }

  private static void enqueueNoOpJobs(final Integer remaining) {
    if (remaining <= 0) {
      return;
    }
    System.enqueueJob(new NoOpQueueable());
    enqueueNoOpJobs(remaining - 1);
  }

  private class NoOpQueueable implements Queueable {
    public void execute(final QueueableContext context) {
      System.debug(LoggingLevel.FINEST, 'no-op');
    }
  }
}
