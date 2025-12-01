@IsTest
private class JobExecutorServiceImplTest {
  @IsTest
  static void givenService_whenIsRunningWithoutJobs_thenFalse() {
    // Arrange
    final JobExecutorServiceImpl sut = new JobExecutorServiceImpl();
    // Act
    final Boolean result = sut.isRunning(null);
    // Assert
    Assert.areEqual(false, result);
  }

  private class DummyQueueable implements Queueable {
    public void execute(QueueableContext context) {
      System.Debug('Just a Statement');
    }
  }

  @IsTest
  static void givenService_whenIsRunningWithOtherQueueable_thenFalse() {
    // Arrange
    final JobExecutorServiceImpl sut = new JobExecutorServiceImpl();
    Test.startTest();
    System.enqueueJob(new DummyQueueable());
    // Act
    final Boolean result = sut.isRunning(null);
    Test.stopTest();
    // Assert
    Assert.areEqual(false, result);
  }

  @IsTest
  static void givenService_whenIsRunningWithAsyncExecutorQueued_thenFalse() {
    // Arrange
    final JobExecutorServiceImpl sut = new JobExecutorServiceImpl();
    Test.startTest();
    System.enqueueJob(new AsyncApexJobExecutor());
    // Act
    final Boolean result = sut.isRunning(null);
    Test.stopTest();
    // Assert
    Assert.areEqual(false, result);
  }

  @IsTest
  static void givenService_whenIsRunningAfterAsyncExecutorCompleted_thenFalse() {
    // Arrange
    final JobExecutorServiceImpl sut = new JobExecutorServiceImpl();
    Test.startTest();
    System.enqueueJob(new AsyncApexJobExecutor());
    Test.stopTest();
    // Act
    final Boolean result = sut.isRunning(null);
    // Assert
    Assert.areEqual(false, result);
  }

  @IsTest
  static void givenService_whenIsRunningWithExcludedJobId_thenFalse() {
    // Arrange
    final JobExecutorServiceImpl sut = new JobExecutorServiceImpl();
    Test.startTest();
    final Id enqueuedId = System.enqueueJob(new AsyncApexJobExecutor());
    // Act
    final Boolean result = sut.isRunning(enqueuedId);
    Test.stopTest();
    // Assert
    Assert.areEqual(false, result);
  }
}
