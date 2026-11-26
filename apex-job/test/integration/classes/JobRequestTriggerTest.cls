@IsTest
private class JobRequestTriggerTest {
  private static final Integer SINGLE_INSERT_COUNT = 40;
  private static final Integer OVER_LIMIT_INSERT_COUNT = 120;
  private static final Integer BULK_INSERT_SIZE = 9999; // aborting the queued executor costs the last of the 10,000 DML rows
  private static final Integer EXPECTED_WAKE_UP_COUNT = 1;
  private static final Integer BATCH_INSERT_COUNT = 2;
  private static final Integer NO_EXECUTOR = 0;
  private static final String EXECUTOR_CLASS_NAME = 'AsyncApexJobExecutor';

  @IsTest
  private static void givenEngineIdle_whenSingleRowInsertsRepeat40Times_thenOneQueryAndOneQueueable() {
    // Arrange
    final Id descriptionId = insertDisabledDescriptionWithEngineEnabled();
    Test.startTest();
    final Integer queriesBefore = Limits.getQueries();
    final Integer queueablesBefore = Limits.getQueueableJobs();

    // Act
    insertSingleRows(descriptionId, SINGLE_INSERT_COUNT);

    // Assert
    final Integer queriesDelta = Limits.getQueries() - queriesBefore;
    final Integer queueablesDelta = Limits.getQueueableJobs() - queueablesBefore;
    Assert.areEqual(EXPECTED_WAKE_UP_COUNT, queriesDelta, 'Only the first insert should query the running state');
    Assert.areEqual(EXPECTED_WAKE_UP_COUNT, queueablesDelta, 'Only the first insert should enqueue the executor');
    abortQueuedExecutors();
  }

  @IsTest
  private static void givenEngineIdle_whenSingleRowInsertsRepeat120Times_thenNoSoqlLimitExceptionAndOneQueueable() {
    // Arrange
    final Id descriptionId = insertDisabledDescriptionWithEngineEnabled();
    Test.startTest();
    final Integer queueablesBefore = Limits.getQueueableJobs();

    // Act
    insertSingleRows(descriptionId, OVER_LIMIT_INSERT_COUNT);

    // Assert
    final Integer queueablesDelta = Limits.getQueueableJobs() - queueablesBefore;
    Assert.areEqual(EXPECTED_WAKE_UP_COUNT, queueablesDelta, 'Only the first insert should enqueue the executor');
    abortQueuedExecutors();
  }

  @IsTest
  private static void givenEngineIdle_whenOneInsertOf9999Rows_thenOneQueryAndOneQueueable() {
    // Arrange
    final Id descriptionId = insertDisabledDescriptionWithEngineEnabled();
    final List<JobRequest__c> requests = new List<JobRequest__c>();
    for (Integer i = 0; i < BULK_INSERT_SIZE; ++i) {
      requests.add(readyRequest(descriptionId));
    }
    Test.startTest();
    final Integer queriesBefore = Limits.getQueries();
    final Integer queueablesBefore = Limits.getQueueableJobs();

    // Act
    insert requests;

    // Assert
    final Integer queriesDelta = Limits.getQueries() - queriesBefore;
    final Integer queueablesDelta = Limits.getQueueableJobs() - queueablesBefore;
    Assert.areEqual(EXPECTED_WAKE_UP_COUNT, queriesDelta, 'Every 200-row trigger chunk should share one running-state query');
    Assert.areEqual(EXPECTED_WAKE_UP_COUNT, queueablesDelta, 'Every 200-row trigger chunk should share one enqueue');
    abortQueuedExecutors();
  }

  @IsTest
  private static void givenBatchExecute_whenInsertTwoRequests_thenScopeCompletes() {
    // Arrange
    final Id descriptionId = insertDisabledDescriptionWithEngineEnabled();

    // Act
    Test.startTest();
    final Id batchId = Database.executeBatch(new JobRequestInsertingBatch(descriptionId));
    Test.stopTest();

    // Assert
    Assert.areEqual(BATCH_INSERT_COUNT, [SELECT COUNT() FROM JobRequest__c], 'Both requests should persist');
    Assert.areEqual(0, [SELECT NumberOfErrors FROM AsyncApexJob WHERE Id = :batchId].NumberOfErrors, 'The batch scope should complete without error');
    Assert.areEqual(NO_EXECUTOR, executorJobCount(), 'The batch should not wake the executor');
  }

  @IsTest
  private static void givenFutureMethod_whenInsertTwoRequests_thenNoWakeUp() {
    // Arrange
    final Id descriptionId = insertDisabledDescriptionWithEngineEnabled();

    // Act
    Test.startTest();
    insertTwoRequests(descriptionId);
    Test.stopTest();

    // Assert
    Assert.areEqual(BATCH_INSERT_COUNT, [SELECT COUNT() FROM JobRequest__c], 'Both requests should persist');
    Assert.areEqual(NO_EXECUTOR, executorJobCount(), 'The future method should not wake the executor');
  }

  private static Id insertDisabledDescriptionWithEngineEnabled() {
    insert new ApexJobConfig__c(Enabled__c = true);
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().build();
    description.Enabled__c = false;
    insert description;
    return description.Id;
  }

  private static JobRequest__c readyRequest(final Id descriptionId) {
    return new JobRequest__c(JobDescription__c = descriptionId, Status__c = ApexJobStatus.READY.name(), Enabled__c = true);
  }

  private static void insertSingleRows(final Id descriptionId, final Integer count) {
    for (Integer i = 0; i < count; ++i) {
      insertSingleRow(descriptionId);
    }
  }

  private static void insertSingleRow(final Id descriptionId) {
    insert readyRequest(descriptionId);
  }

  private static void abortQueuedExecutors() {
    for (AsyncApexJob executor : [SELECT Id FROM AsyncApexJob WHERE ApexClass.Name = :EXECUTOR_CLASS_NAME]) {
      abortJob(executor.Id);
    }
  }

  private static void abortJob(final Id jobId) {
    System.abortJob(jobId);
  }

  private static Integer executorJobCount() {
    return [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = :EXECUTOR_CLASS_NAME];
  }

  @Future
  private static void insertTwoRequests(final Id descriptionId) {
    insertSingleRows(descriptionId, BATCH_INSERT_COUNT);
  }
}
