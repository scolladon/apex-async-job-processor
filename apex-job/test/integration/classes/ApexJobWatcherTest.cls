@IsTest
private class ApexJobWatcherTest {
  @IsTest
  static void givenSystemEnabled_whenExecute_thenEnqueuesJobWithConfiguredDelay() {
    // Arrange
    final Mock factoryMock = Mock.forType(ApexJobFactory.class);
    final Mock configMock = Mock.forType(ApexJobConfigService.class);
    final Mock spawnerMock = Mock.forType(JobExecutorSpawner.class);

    final Integer delayInMinutes = 5;

    factoryMock.spyOn('getConfigService').returns(configMock.stub);
    factoryMock.spyOn('getSpawner').returns(spawnerMock.stub);
    configMock.spyOn('isSystemEnabled').returns(true);
    configMock.spyOn('getEnqueueDelayInMinutes').returns(delayInMinutes);
    MethodSpy enqueueSpy = spawnerMock.spyOn('enqueue');

    final ApexJobWatcher sut = new ApexJobWatcher((ApexJobFactory) factoryMock.stub);

    // Act
    sut.execute(null);

    // Assert
    Expect.that(enqueueSpy).hasBeenCalled();
    Expect.that(configMock.spyOn('getEnqueueDelayInMinutes')).hasBeenCalled();
  }

  @IsTest
  static void givenSystemDisabled_whenExecute_thenDoesNotEnqueue() {
    // Arrange
    final Mock factoryMock = Mock.forType(ApexJobFactory.class);
    final Mock configMock = Mock.forType(ApexJobConfigService.class);
    final Mock spawnerMock = Mock.forType(JobExecutorSpawner.class);

    factoryMock.spyOn('getConfigService').returns(configMock.stub);
    factoryMock.spyOn('getSpawner').returns(spawnerMock.stub);
    configMock.spyOn('isSystemEnabled').returns(false);
    MethodSpy enqueueSpy = spawnerMock.spyOn('enqueue');

    final ApexJobWatcher sut = new ApexJobWatcher((ApexJobFactory) factoryMock.stub);

    // Act
    Test.startTest();
    sut.execute(null);
    Test.stopTest();

    // Assert
    Expect.that(enqueueSpy).hasNotBeenCalled();
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
