@IsTest
private class JobMonitorControllerTest {
  private static final Integer PAGE_SIZE = 10;
  private static final Integer FIRST_OFFSET = 0;
  private static final Integer REQUESTS_PER_GROUP = 5;
  private static final Integer GROUP_COUNT = 4;
  private static final Integer MAX_CHUNK_SIZE = 40;
  private static final Integer SMALLEST_FAILING_CHUNK = 12;
  private static final Integer SUCCESS_STREAK = 7;
  private static final Integer CONSECUTIVE_FAILURES = 2;
  private static final Datetime LAST_EXECUTION = Datetime.newInstanceGmt(2026, 1, 15, 10, 30, 0);

  @IsTest
  static void givenDeletedRunnableRequest_whenGetJobRequestPage_thenDeletedRequestIsNotReturned() {
    // Arrange
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().build();
    insert description;
    final JobRequest__c kept = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    final JobRequest__c deleted = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    insert new List<JobRequest__c>{ kept, deleted };
    delete deleted;

    // Act
    final List<JobRequest__c> result = JobMonitorController.getJobRequestPage(PAGE_SIZE, FIRST_OFFSET);

    // Assert
    final Map<Id, JobRequest__c> resultById = new Map<Id, JobRequest__c>(result);
    Assert.isTrue(resultById.containsKey(kept.Id), 'Should return the kept request');
    Assert.isFalse(resultById.containsKey(deleted.Id), 'Should not return the deleted request');
  }

  @IsTest
  static void givenRequestsAcrossTwoDescriptionsAndTwoStatuses_whenGetStatusByProcessor_thenQueryRowsEqualGroupCount() {
    // Arrange
    final List<JobDescription__c> descriptions = new List<JobDescription__c>{
      ApexJobTestFixture.aJobDescription().withProcessorName('ProcessorA').build(),
      ApexJobTestFixture.aJobDescription().withProcessorName('ProcessorB').build()
    };
    insert descriptions;
    final List<JobRequest__c> requests = new List<JobRequest__c>();
    for (JobDescription__c description : descriptions) {
      for (Integer j = 0; j < REQUESTS_PER_GROUP; j++) {
        requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build());
        requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).failure().build());
      }
    }
    insert requests;

    // Act
    Test.startTest();
    final List<Map<String, Object>> result = JobMonitorController.getStatusByProcessor();
    final Integer queryRows = Limits.getQueryRows();
    Test.stopTest();

    // Assert
    Assert.areEqual(GROUP_COUNT, queryRows, 'Should consume one query row per group');
    Assert.areEqual(GROUP_COUNT, result.size(), 'Should return one entry per group');
    for (Map<String, Object> statusGroup : result) {
      Assert.areEqual(REQUESTS_PER_GROUP, statusGroup.get('nbRows'), 'Should count every request of the group');
    }
  }

  @IsTest
  static void givenDescriptions_whenGetJobDescriptionInfos_thenReturnsStatisticsFields() {
    // Arrange
    final JobDescription__c description = ApexJobTestFixture.aJobDescription()
      .withMaxChunkSize(MAX_CHUNK_SIZE)
      .withSmallestFailingChunk(SMALLEST_FAILING_CHUNK)
      .withSuccessStreak(SUCCESS_STREAK)
      .withConsecutiveFailures(CONSECUTIVE_FAILURES)
      .build();
    description.LastExecutionDateTime__c = LAST_EXECUTION;
    insert description;

    // Act
    final List<JobDescription__c> result = JobMonitorController.getJobDescriptionInfos(new List<Id>{ description.Id });

    // Assert
    Assert.areEqual(1, result.size(), 'Should return the description');
    Assert.areEqual(MAX_CHUNK_SIZE, result[0].MaxChunkSize__c, 'Should expose MaxChunkSize__c');
    Assert.areEqual(SMALLEST_FAILING_CHUNK, result[0].SmallestFailingChunk__c, 'Should expose SmallestFailingChunk__c');
    Assert.areEqual(SUCCESS_STREAK, result[0].SuccessStreak__c, 'Should expose SuccessStreak__c');
    Assert.areEqual(CONSECUTIVE_FAILURES, result[0].ConsecutiveFailures__c, 'Should expose ConsecutiveFailures__c');
    Assert.areEqual(LAST_EXECUTION, result[0].LastExecutionDateTime__c, 'Should expose LastExecutionDateTime__c');
  }

  @IsTest
  static void givenEngineState_whenGetEngineStatus_thenReturnsThreeValues() {
    // Arrange
    insert new ApexJobConfig__c(Enabled__c = true);

    // Act
    final JobMonitorController.EngineStatus result = JobMonitorController.getEngineStatus();

    // Assert
    Assert.isTrue(result.enabled, 'Should report the engine enabled');
    Assert.areEqual(0, result.executorCount, 'Should report no executor');
    Assert.isFalse(result.watcherScheduled, 'Should report no watcher');
  }
}
