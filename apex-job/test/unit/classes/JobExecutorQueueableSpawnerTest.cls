@IsTest
private class JobExecutorQueueableSpawnerTest {
  @IsTest
  static void givenJobExecutorQueueableSpawner_whenAlreadyQueued_thenJobNotEnqueued() {
    // Arrange
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner();
    Mock asyncApexJobExecutorMock = Mock.forType(AsyncApexJobExecutor.class);
    Integer delayInMinutes = 5;

    // Act
    Test.startTest();
    System.enqueueJob(new AsyncApexJobExecutor());
    Id jobId = sut.enqueue((AsyncApexJobExecutor) asyncApexJobExecutorMock.stub, delayInMinutes);
    Test.stopTest();

    Assert.isNull(jobId);
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWithDelay_thenJobEnqueued() {
    // Arrange
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner();
    Mock asyncApexJobExecutorMock = Mock.forType(AsyncApexJobExecutor.class);
    Integer delayInMinutes = 5;

    // Act
    Id jobId = sut.enqueue((AsyncApexJobExecutor) asyncApexJobExecutorMock.stub, delayInMinutes);

    Assert.isNotNull(jobId);
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWithMinus1_thenJobNotEnqueued() {
    // Arrange
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner();
    Mock asyncApexJobExecutorMock = Mock.forType(AsyncApexJobExecutor.class);
    Integer delayInMinutes = -1;

    // Act
    try {
      sut.enqueue((AsyncApexJobExecutor) asyncApexJobExecutorMock.stub, delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.InvalidParameterValueException e) {
      Assert.areEqual('Delay must be greater than or equal to 0 minutes', e.getMessage());
    }
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueuedWith11_thenJobNotEnqueued() {
    // Arrange
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner();
    Mock asyncApexJobExecutorMock = Mock.forType(AsyncApexJobExecutor.class);
    Integer delayInMinutes = 11;

    // Act
    try {
      sut.enqueue((AsyncApexJobExecutor) asyncApexJobExecutorMock.stub, delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.InvalidParameterValueException e) {
      Assert.areEqual('Delay must be less than or equal to 10 minutes', e.getMessage());
    }
  }

  @IsTest
  static void givenJobExecutorQueueableSpawner_whenEnqueueWithNullDelay_thenJobEnqueued() {
    // Arrange
    JobExecutorQueueableSpawner sut = new JobExecutorQueueableSpawner();
    Mock asyncApexJobExecutorMock = Mock.forType(AsyncApexJobExecutor.class);
    Integer delayInMinutes = null;

    // Act
    try {
      sut.enqueue((AsyncApexJobExecutor) asyncApexJobExecutorMock.stub, delayInMinutes);
      Assert.fail('Expected exception to be thrown');
    } catch (System.NullPointerException e) {
      Assert.areEqual('Argument 2 cannot be null', e.getMessage());
    }
  }
}
