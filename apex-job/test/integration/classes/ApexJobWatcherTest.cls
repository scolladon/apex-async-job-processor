@IsTest
private class ApexJobWatcherTest {
  @IsTest
  static void givenSystemDisabled_whenExecute_thenCallsEnqueue() {
    // Arrange
    ApexJobTestMock mocks = new ApexJobTestMock();
    final ApexJobWatcher sut = new ApexJobWatcher(mocks.factoryStub);

    // Act
    Test.startTest();
    sut.execute(null);
    Test.stopTest();

    // Assert
    Expect.that(mocks.enqueueSpy).hasBeenCalled();
  }

  @IsTest
  static void givenSchedule_whenNoExistingJobs_thenSchedulesTwelveJobs() {
    // Act
    ApexJobWatcher.schedule();

    // Assert
    final Integer jobsNumber = [
      SELECT COUNT()
      FROM CronTrigger
      WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'Async Job Watcher%'
    ];
    Assert.areEqual(12, jobsNumber, 'Exactly 12 scheduled jobs must be created');
  }

  @IsTest
  static void givenScheduleCalledTwice_whenJobsAlreadyScheduled_thenDoesNotDuplicate() {
    // Arrange
    ApexJobWatcher.schedule();

    // Act
    Test.startTest();
    ApexJobWatcher.schedule();
    Test.stopTest();

    // Assert
    final Integer jobsNumber = [
      SELECT COUNT()
      FROM CronTrigger
      WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'Async Job Watcher%'
    ];
    Assert.areEqual(12, jobsNumber, 'Scheduling twice must not create duplicates');
  }
}
