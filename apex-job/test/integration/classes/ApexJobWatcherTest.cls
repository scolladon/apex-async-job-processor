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
    // Arrange

    // Act
    Test.startTest();
    ApexJobWatcher.schedule();
    Test.stopTest();

    // Assert
    final Integer jobsNumber = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE JobType = 'ScheduledApex' AND ApexClass.Name = :ApexJobWatcher.class.getName()
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
      FROM AsyncApexJob
      WHERE JobType = 'ScheduledApex' AND ApexClass.Name = :ApexJobWatcher.class.getName()
    ];
    Assert.areEqual(12, jobsNumber, 'Scheduling twice must not create duplicates');
  }
}
