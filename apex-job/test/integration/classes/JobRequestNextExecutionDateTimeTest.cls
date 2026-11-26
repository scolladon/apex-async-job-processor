@IsTest
private class JobRequestNextExecutionDateTimeTest {
  private static final Integer MILLIS_PER_SECOND = 1000;

  @IsTest
  private static void givenBuilderWithoutScheduleAt_whenSave_thenNextExecutionDateTimeIsStamped() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final Datetime lowerBound = wholeSecondNow();

    // Act
    final JobRequest__c saved = ApexJobManager.request().forDescription(description.Id).save();

    // Assert
    assertStamped(saved.Id, lowerBound);
  }

  @IsTest
  private static void givenPlainInsertWithoutDate_whenInsert_thenNextExecutionDateTimeIsStamped() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final JobRequest__c request = readyRequest(description);
    final Datetime lowerBound = wholeSecondNow();

    // Act
    insert request;

    // Assert
    assertStamped(request.Id, lowerBound);
  }

  @IsTest
  private static void givenUserWithTriggerBypass_whenInsertWithoutDate_thenNextExecutionDateTimeIsStamped() {
    // Arrange
    final User bypassUser = TestDataFactory.createUserWithTriggerBypass();
    System.runAs(bypassUser) {
      final JobDescription__c description = insertDescription();
      final JobRequest__c request = readyRequest(description);
      final Datetime lowerBound = wholeSecondNow();

      // Act
      insert request;

      // Assert
      assertStamped(request.Id, lowerBound);
    }
  }

  @IsTest
  private static void givenExplicitDate_whenInsert_thenDateIsKept() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final JobRequest__c request = readyRequest(description);
    final Datetime explicitDate = Datetime.now().addHours(1);
    request.NextExecutionDateTime__c = explicitDate;

    // Act
    insert request;

    // Assert
    final JobRequest__c stored = [SELECT NextExecutionDateTime__c FROM JobRequest__c WHERE Id = :request.Id];
    Assert.areEqual(explicitDate, stored.NextExecutionDateTime__c, 'An explicit date must not be overridden by the default');
  }

  private static JobDescription__c insertDescription() {
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().build();
    insert description;
    return description;
  }

  private static JobRequest__c readyRequest(final JobDescription__c description) {
    return new JobRequest__c(JobDescription__c = description.Id, Status__c = ApexJobStatus.READY.name(), Enabled__c = true);
  }

  private static Datetime wholeSecondNow() {
    final Datetime now = Datetime.now();
    return Datetime.newInstance(now.getTime() - Math.mod(now.getTime(), MILLIS_PER_SECOND));
  }

  private static void assertStamped(final Id requestId, final Datetime lowerBound) {
    final JobRequest__c stored = [SELECT NextExecutionDateTime__c FROM JobRequest__c WHERE Id = :requestId];
    final Datetime upperBound = Datetime.now();
    Assert.isNotNull(stored.NextExecutionDateTime__c, 'NextExecutionDateTime__c should be stamped on insert');
    Assert.isTrue(stored.NextExecutionDateTime__c >= lowerBound, 'Stamp should not precede the insert');
    Assert.isTrue(stored.NextExecutionDateTime__c <= upperBound, 'Stamp should not follow the re-query');
  }
}
