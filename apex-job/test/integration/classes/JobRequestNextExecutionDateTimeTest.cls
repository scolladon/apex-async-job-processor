@IsTest
private class JobRequestNextExecutionDateTimeTest {
  private static final Integer MILLIS_PER_SECOND = 1000;
  private static final String STAMP_MESSAGE = 'NextExecutionDateTime__c should be stamped between the insert and the re-query';

  @IsTest
  private static void givenBuilderWithoutScheduleAt_whenSave_thenNextExecutionDateTimeIsStamped() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final Datetime lowerBound = wholeSecondNow();

    // Act
    final JobRequest__c saved = ApexJobManager.request().forDescription(description.Id).save();

    // Assert
    Assert.isTrue(isStampedSince(saved.Id, lowerBound), STAMP_MESSAGE);
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
    Assert.isTrue(isStampedSince(request.Id, lowerBound), STAMP_MESSAGE);
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
      Assert.isTrue(isStampedSince(request.Id, lowerBound), STAMP_MESSAGE);
    }
  }

  @IsTest
  private static void givenExplicitDate_whenInsert_thenDateIsKept() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final JobRequest__c request = readyRequest(description);
    final Datetime explicitDate = wholeSecondNow().addHours(1);
    request.NextExecutionDateTime__c = explicitDate;

    // Act
    insert request;

    // Assert
    final JobRequest__c stored = [SELECT NextExecutionDateTime__c FROM JobRequest__c WHERE Id = :request.Id];
    Assert.areEqual(explicitDate, stored.NextExecutionDateTime__c, 'An explicit date must not be overridden by the default');
  }

  @IsTest
  private static void givenExplicitNullDate_whenInsert_thenRequestIsNotSelected() {
    // Arrange
    final JobDescription__c description = insertDescription();
    final JobRequest__c nullDated = readyRequest(description);
    nullDated.NextExecutionDateTime__c = null;
    final JobRequest__c control = readyRequest(description);
    insert new List<JobRequest__c>{ nullDated, control };
    final JobSelectorImpl sut = new JobSelectorImpl();

    // Act
    final List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());

    // Assert
    final Map<Id, JobRequest__c> stored = new Map<Id, JobRequest__c>([SELECT NextExecutionDateTime__c, IsCandidate__c FROM JobRequest__c]);
    final Set<Id> selectedIds = new Map<Id, JobRequest__c>(result).keySet();
    Assert.isNull(stored.get(nullDated.Id).NextExecutionDateTime__c, 'An explicit null must not receive the default');
    Assert.isTrue(selectedIds.contains(control.Id), 'The control request must be selected');
    Assert.isFalse(selectedIds.contains(nullDated.Id), 'A null date means not scheduled');
    Assert.isFalse(stored.get(nullDated.Id).IsCandidate__c, 'IsCandidate__c must be false for a null date');
    Assert.isTrue(stored.get(control.Id).IsCandidate__c, 'IsCandidate__c must be true for the control');
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

  private static Boolean isStampedSince(final Id requestId, final Datetime lowerBound) {
    final Datetime stamp = [SELECT NextExecutionDateTime__c FROM JobRequest__c WHERE Id = :requestId].NextExecutionDateTime__c;
    return stamp != null && stamp >= lowerBound && stamp <= Datetime.now();
  }
}
