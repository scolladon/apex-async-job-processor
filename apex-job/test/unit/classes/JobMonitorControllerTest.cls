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
  private static final Datetime KILL_BACKOFF_UNTIL = Datetime.newInstanceGmt(2026, 1, 15, 10, 35, 0);
  private static final String MANAGE_ENGINE_PERMISSION = 'Manage_Async_Job_Engine';
  private static final String ADMIN_PERMISSION_SET = 'AdminAsyncJob';

  @IsTest
  static void givenDeletedRunnableRequest_whenGetJobRequestPage_thenDeletedRequestIsNotReturned() {
    // Arrange
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().build();
    insert as system description;
    final JobRequest__c kept = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    final JobRequest__c deleted = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    insert as system new List<JobRequest__c>{ kept, deleted };
    delete as system deleted;

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
    insert as system descriptions;
    final List<JobRequest__c> requests = new List<JobRequest__c>();
    for (JobDescription__c description : descriptions) {
      for (Integer j = 0; j < REQUESTS_PER_GROUP; j++) {
        requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build());
        requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).failure().build());
      }
    }
    insert as system requests;

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
      .withKillBackoffUntil(KILL_BACKOFF_UNTIL)
      .build();
    description.LastExecutionDateTime__c = LAST_EXECUTION;
    insert as system description;

    // Act
    final List<JobDescription__c> result = JobMonitorController.getJobDescriptionInfos(new List<Id>{ description.Id });

    // Assert
    Assert.areEqual(1, result.size(), 'Should return the description');
    Assert.areEqual(MAX_CHUNK_SIZE, result[0].MaxChunkSize__c, 'Should expose MaxChunkSize__c');
    Assert.areEqual(SMALLEST_FAILING_CHUNK, result[0].SmallestFailingChunk__c, 'Should expose SmallestFailingChunk__c');
    Assert.areEqual(SUCCESS_STREAK, result[0].SuccessStreak__c, 'Should expose SuccessStreak__c');
    Assert.areEqual(CONSECUTIVE_FAILURES, result[0].ConsecutiveFailures__c, 'Should expose ConsecutiveFailures__c');
    Assert.areEqual(LAST_EXECUTION, result[0].LastExecutionDateTime__c, 'Should expose LastExecutionDateTime__c');
    Assert.areEqual(KILL_BACKOFF_UNTIL, result[0].KillBackoffUntil__c, 'Should expose KillBackoffUntil__c');
  }

  @IsTest
  static void givenEnabledEngineAndNoAsyncJob_whenGetEngineStatus_thenReportsEnabledAndIdle() {
    // Arrange
    insert as system new ApexJobConfig__c(Enabled__c = true);

    // Act
    final JobMonitorController.EngineStatus result = JobMonitorController.getEngineStatus();

    // Assert
    Assert.isTrue(result.enabled, 'Should report the engine enabled');
    Assert.areEqual(0, result.executorCount, 'Should report no executor');
    Assert.isFalse(result.watcherScheduled, 'Should report no watcher');
  }

  @IsTest
  static void givenDisabledEngineWithQueuedExecutorAndScheduledWatcher_whenGetEngineStatus_thenReportsThem() {
    // Arrange
    insert as system new ApexJobConfig__c(Enabled__c = false);
    Test.startTest();
    final Id executorId = System.enqueueJob(new AsyncApexJobExecutor());
    ApexJobWatcher.schedule();

    // Act
    final JobMonitorController.EngineStatus result = JobMonitorController.getEngineStatus();

    // Assert
    Assert.isFalse(result.enabled, 'Should report the engine disabled');
    Assert.areEqual(1, result.executorCount, 'Should count the queued executor');
    Assert.isTrue(result.watcherScheduled, 'Should report the scheduled watcher');
    System.abortJob(executorId);
  }

  private static User createEngineManager() {
    final User manager = TestDataFactory.createUserWithTriggerBypass();
    TestDataFactory.assignPermissionSet(manager.Id, ADMIN_PERMISSION_SET);
    return manager;
  }

  @IsTest
  static void givenEnabledEngineAndManagePermission_whenPauseEngine_thenEngineDisabledAndTrueReturned() {
    // Arrange
    final User manager = createEngineManager();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = true) });

    // Act
    Boolean result;
    System.runAs(manager) {
      result = JobMonitorController.pauseEngine();
    }

    // Assert
    Assert.isTrue(result, 'Should report the engine paused');
    Assert.isFalse(ApexJobConfig__c.getOrgDefaults().Enabled__c, 'Should persist the engine disabled');
  }

  @IsTest
  static void givenDisabledEngineAndManagePermission_whenResumeEngine_thenEngineEnabledAndTrueReturned() {
    // Arrange
    final User manager = createEngineManager();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = false) });

    // Act
    Boolean result;
    System.runAs(manager) {
      result = JobMonitorController.resumeEngine();
    }

    // Assert
    Assert.isTrue(result, 'Should report the engine resumed');
    Assert.isTrue(ApexJobConfig__c.getOrgDefaults().Enabled__c, 'Should persist the engine enabled');
  }

  @IsTest
  static void givenDisabledEngineAndManagePermission_whenRestartEngine_thenNothingEnqueued() {
    // Arrange
    final User manager = createEngineManager();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = false) });

    // Act
    Id result;
    System.runAs(manager) {
      result = JobMonitorController.restartEngine();
    }

    // Assert
    Assert.isNull(result, 'Should not enqueue an executor while the engine is disabled');
  }

  @IsTest
  static void givenEnabledEngineAndManagePermission_whenRestartEngine_thenExecutorEnqueued() {
    // Arrange
    final User manager = createEngineManager();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = true) });

    // Act
    Test.startTest();
    Id result;
    System.runAs(manager) {
      result = JobMonitorController.restartEngine();
    }

    // Assert
    Assert.isNotNull(result, 'Should enqueue an executor');
    System.abortJob(result);
    Test.stopTest();
  }

  @IsTest
  static void givenNoManagePermission_whenPauseResumeOrRestartEngine_thenAuthorizationExceptionThrown() {
    // Arrange
    final User nonManager = TestDataFactory.createUserWithTriggerBypass();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = true) });
    final List<String> failures = new List<String>();

    // Act
    System.runAs(nonManager) {
      try {
        JobMonitorController.pauseEngine();
      } catch (JobMonitorController.AuthorizationException ex) {
        failures.add('pause');
      }
      try {
        JobMonitorController.resumeEngine();
      } catch (JobMonitorController.AuthorizationException ex) {
        failures.add('resume');
      }
      try {
        JobMonitorController.restartEngine();
      } catch (JobMonitorController.AuthorizationException ex) {
        failures.add('restart');
      }
    }

    // Assert
    Assert.areEqual(new List<String>{ 'pause', 'resume', 'restart' }, failures, 'Should refuse every engine control');
    Assert.isTrue(ApexJobConfig__c.getOrgDefaults().Enabled__c, 'Should leave the engine untouched');
  }

  private static JobDescription__c insertDescriptionAsAdmin(final String processorName) {
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().withProcessorName(processorName).withMaxChunkSize(MAX_CHUNK_SIZE).build();
    TestDataFactory.insertAsAdmin(new List<SObject>{ description });
    return description;
  }

  @IsTest
  static void givenMinimumAccessUser_whenGetJobRequestPage_thenReturnsRunnableRequests() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('MonitorPage');
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    TestDataFactory.insertAsAdmin(new List<SObject>{ request });

    // Act
    List<JobRequest__c> result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.getJobRequestPage(PAGE_SIZE, FIRST_OFFSET);
    }

    // Assert
    final Map<Id, JobRequest__c> resultById = new Map<Id, JobRequest__c>(result);
    Assert.isTrue(resultById.containsKey(request.Id), 'Should return the arranged request');
  }

  @IsTest
  static void givenMinimumAccessUser_whenGetStatusByProcessor_thenReturnsGroupCounts() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('MonitorStatus');
    final List<JobRequest__c> requests = new List<JobRequest__c>();
    for (Integer i = 0; i < 2; i++) {
      requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build());
      requests.add(ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).failure().build());
    }
    TestDataFactory.insertAsAdmin(requests);

    // Act
    List<Map<String, Object>> result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.getStatusByProcessor();
    }

    // Assert
    Assert.areEqual(2, result.size(), 'Should return one entry per status');
    for (Map<String, Object> statusGroup : result) {
      Assert.areEqual(2, statusGroup.get('nbRows'), 'Should count the requests of the group');
    }
  }

  @IsTest
  static void givenMinimumAccessUser_whenGetJobDescriptionInfos_thenReturnsStatistics() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('MonitorInfos');

    // Act
    List<JobDescription__c> result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.getJobDescriptionInfos(new List<Id>{ description.Id });
    }

    // Assert
    Assert.areEqual(1, result.size(), 'Should return the description');
    Assert.areEqual(MAX_CHUNK_SIZE, result[0].MaxChunkSize__c, 'Should expose MaxChunkSize__c');
  }

  @IsTest
  static void givenMinimumAccessUserAndJobsQueuedByAdmin_whenGetEngineStatus_thenCountsThem() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = false) });
    Test.startTest();
    final Id executorId = System.enqueueJob(new AsyncApexJobExecutor());
    ApexJobWatcher.schedule();

    // Act
    JobMonitorController.EngineStatus result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.getEngineStatus();
    }

    // Assert
    Assert.isFalse(result.enabled, 'Should report the engine disabled');
    Assert.areEqual(1, result.executorCount, 'Should count the executor queued by another user');
    Assert.isTrue(result.watcherScheduled, 'Should report the watcher scheduled by another user');
    System.abortJob(executorId);
  }

  @IsTest
  static void givenMinimumAccessUserWithManagePermission_whenPauseEngine_thenEngineDisabled() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUserWithCustomPermission(MANAGE_ENGINE_PERMISSION);
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = true) });

    // Act
    Boolean result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.pauseEngine();
    }

    // Assert
    Assert.isTrue(result, 'Should report the engine paused');
    Assert.isFalse(ApexJobConfig__c.getOrgDefaults().Enabled__c, 'Should persist the engine disabled');
  }

  @IsTest
  static void givenMinimumAccessUserWithManagePermission_whenResumeEngine_thenEngineEnabled() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUserWithCustomPermission(MANAGE_ENGINE_PERMISSION);
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = false) });

    // Act
    Boolean result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.resumeEngine();
    }

    // Assert
    Assert.isTrue(result, 'Should report the engine resumed');
    Assert.isTrue(ApexJobConfig__c.getOrgDefaults().Enabled__c, 'Should persist the engine enabled');
  }

  @IsTest
  static void givenMinimumAccessUserWithManagePermissionAndEnabledEngine_whenRestartEngine_thenExecutorEnqueued() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUserWithCustomPermission(MANAGE_ENGINE_PERMISSION);
    TestDataFactory.insertAsAdmin(new List<SObject>{ new ApexJobConfig__c(Enabled__c = true) });

    // Act
    Test.startTest();
    Id result;
    System.runAs(minimumAccessUser) {
      result = JobMonitorController.restartEngine();
    }

    // Assert
    Assert.isNotNull(result, 'Should enqueue an executor');
    System.abortJob(result);
    Test.stopTest();
  }
}
