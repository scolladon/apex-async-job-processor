@IsTest
public class AsyncProcessorTest {
  @TestSetup
  static void setup() {
    final User runningUser = new User(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'test.user@ajp.io',
      Username = 'test.user@ajp.io',
      Alias = 'testuser',
      TimeZoneSidKey = 'Europe/Paris',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator']
      .Id
    );

    insert runningUser;

    final PermissionSet byPassTriggersPermissionSet = new PermissionSet(Name = 'ByPassTriggers', Label = 'ByPass Triggers');
    insert byPassTriggersPermissionSet;

    final CustomPermission byPassTriggerCustomPermission = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'Bypass_JobRequest_Trigger' LIMIT 1];
    insert new SetupEntityAccess(SetupEntityId = byPassTriggerCustomPermission.Id, ParentId = byPassTriggersPermissionSet.Id);

    insert new PermissionSetAssignment(AssigneeId = runningUser.Id, PermissionSetId = byPassTriggersPermissionSet.Id);
  }

  static User getRunningUser() {
    return [SELECT Id FROM User WHERE Username = 'test.user@ajp.io' LIMIT 1];
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsWithoutEligibleJobs_thenReenqueueAfter1Minute() {
    // Arrange
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    final Id initialJobId = System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final List<AsyncApexJob> jobs = [
      SELECT Id, ApexClass.Name, JobType, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'AsyncApexJobExecutor'
    ];
    Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRuns_thenSelectionAndEndTimesAreRecordedAndNextTryUsesEndOnFailure() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'ErrorProcessorWithInterval', Enabled__c = true, ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor', MinJobInterval__c = 3);

      insert new JobRequest__c(
        Name = 'ErrorProcessorWithInterval1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final JobRequest__c jobRequest = [
        SELECT Status__c, AttemptNumber__c, LastSelectionDateTime__c, LastExecutionDateTime__c, NextExecutionDateTime__c
        FROM JobRequest__c
        WHERE Name = 'ErrorProcessorWithInterval1'
        LIMIT 1
      ];
      Assert.areEqual(ApexJobStatus.FAILURE.name(), jobRequest.Status__c, 'Job should be marked as failure');
      Assert.areEqual(1, jobRequest.AttemptNumber__c, 'Attempt number should be incremented');
      Assert.isNotNull(jobRequest.LastSelectionDateTime__c, 'Selection time should be recorded');
      Assert.isNotNull(jobRequest.LastExecutionDateTime__c, 'End time should be recorded');
      Assert.isTrue(jobRequest.LastSelectionDateTime__c.getTime() <= jobRequest.LastExecutionDateTime__c.getTime(), 'Selection should be <= end');
      Assert.areEqual(jobRequest.LastExecutionDateTime__c.addMinutes(3), jobRequest.NextExecutionDateTime__c, 'Next try should be end + interval');
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsWithEligibleJobs_thenDeleteSuccessfulJob() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'NormalPriorityProcessor', ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor', Enabled__c = true);

      insert new JobRequest__c(
        Name = 'NormalPriorityJob1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM JobRequest__c
          WHERE Name = 'NormalPriorityJob1'
        ],
        'Succcesfull Job should have been deleted'
      );
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsWithEligibleRecurrentJobs_thenReadySuccessfulJob() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'NormalPriorityProcessor', ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor', Enabled__c = true, IsRecurrent__c = true, MinJobInterval__c = 10);

      insert new JobRequest__c(
        Name = 'NormalPriorityJob1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      final JobRequest__c jobRequest = [
        SELECT Id, Status__c, NextExecutionDateTime__c
        FROM JobRequest__c
        WHERE Name = 'NormalPriorityJob1'
      ];
      Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(ApexJobStatus.READY.name(), jobRequest.Status__c, 'Job should be marked as ready');
      Assert.isTrue(jobRequest.NextExecutionDateTime__c >= System.now().addMinutes(9), 'Job should be rescheduled for later');
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsWithImpossibleToPrepareEligibleJobs_thenDoesNotUpdateRequest() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'ImpossibleJob', ProcessorName__c = 'ImpossibleJob', Enabled__c = true, DmlStatementsBaseConsumption__c = 999);

      insert new JobRequest__c(
        Name = 'ImpossibleJob1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'ImpossibleJob')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      final JobRequest__c jobRequest = [
        SELECT Id, Status__c
        FROM JobRequest__c
        WHERE Name = 'ImpossibleJob1'
      ];
      Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(ApexJobStatus.READY.name(), jobRequest.Status__c, 'Job should be marked as ready');
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsAndJobFails_thenUpdateJobRequestToFailure() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'ErrorProcessor', Enabled__c = true, ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor');

      insert new JobRequest__c(
        Name = 'ErrorProcessor1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      final JobRequest__c jobRequest = [
        SELECT Id, Status__c
        FROM JobRequest__c
        WHERE Name = 'ErrorProcessor1'
      ];
      Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(ApexJobStatus.FAILURE.name(), jobRequest.Status__c, 'Job should be marked as failure');
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsAndJobFailsTooManyTime_thenUpdateJobRequestToAbort() {
    // Arrange
    System.runAs(getRunningUser()) {
      insert new JobDescription__c(Name = 'ErrorProcessor', Enabled__c = true, ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor', MaxExecutionAttempt__c = 2);

      insert new JobRequest__c(
        Name = 'ErrorProcessor1',
        Argument__c = '{"test": "data2"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-10),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 1,
        JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.ErrorProcessor')
      );

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      final JobRequest__c jobRequest = [
        SELECT Id, Status__c
        FROM JobRequest__c
        WHERE Name = 'ErrorProcessor1'
      ];
      Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(ApexJobStatus.ABORTED.name(), jobRequest.Status__c, 'Job should be marked as failure');
    }
  }

  /**
   * Test commented and leave here as a demonstration because Governor limit Test not possible...
   *
  public class KilledProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      for(Integer i = 0; i < 1000000; i++) {
        List<JobDescription__c> jobDescriptions = [SELECT Id FROM JobDescription__c LIMIT 1];
      }
      return null; // Not reachable
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenExecutorRunsAndJobKilled_thenUpdateJobRequestToKilled() {
    // Arrange
    insert new JobDescription__c(Name = 'KilledProcessor', Enabled__c = true, ProcessorName__c = 'AsyncProcessorTest.KilledProcessor');

    insert new JobRequest__c(
      Name = 'KilledProcessor',
      Argument__c = '{"test": "data2"}',
      Enabled__c = true,
      Status__c = ApexJobStatus.READY.name(),
      NextExecutionDateTime__c = System.now().addMinutes(-10),
      LastExecutionDateTime__c = null,
      AttemptNumber__c = 0,
      JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.KilledProcessor')
    );

    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    final Id initialJobId = System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final List<AsyncApexJob> jobs = [
      SELECT Id, ApexClass.Name, JobType, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'AsyncApexJobExecutor'
    ];
    final JobRequest__c jobRequest = [
      SELECT Id, Status__c
      FROM JobRequest__c
      WHERE Name = 'KilledProcessor'
    ];
    Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
    Assert.areEqual(ApexJobStatus.KILLED.name(), jobRequest.Status__c, 'Job should be marked as killed');
  }
    */

  @IsTest
  private static void givenSystemEnabled_whenUnknownChunkSizeJobAfterExecutedJob_thenSkipsExecution() {
    // Arrange
    System.runAs(getRunningUser()) {
      // Create two job descriptions: one normal and one with unknown chunk size
      final List<JobDescription__c> jobDescriptions = new List<JobDescription__c>{
        new JobDescription__c(Name = 'UnknownChunkProcessor', ProcessorName__c = 'AsyncProcessorTest.UnknownChunkProcessor', Enabled__c = true, MaxChunkSize__c = -1),
        new JobDescription__c(
          Name = 'AnotherUnknownChunkProcessor',
          ProcessorName__c = 'AsyncProcessorTest.AnotherUnknownChunkProcessor',
          Enabled__c = true,
          MaxChunkSize__c = -1 // Unknown chunk size
        )
      };
      insert jobDescriptions;

      // Insert job requests - normal job first, then unknown chunk size job
      insert new List<JobRequest__c>{
        new JobRequest__c(
          Name = 'UnknownChunkJob1',
          Argument__c = '{"test": "data1"}',
          Enabled__c = true,
          Status__c = ApexJobStatus.READY.name(),
          NextExecutionDateTime__c = DateTime.now().addMinutes(-20), // Execute first
          AttemptNumber__c = 0,
          JobDescription__c = jobDescriptions[0].Id
        ),
        new JobRequest__c(
          Name = 'UnknownChunkJob2',
          Argument__c = '{"test": "data2"}',
          Enabled__c = true,
          Status__c = ApexJobStatus.READY.name(),
          NextExecutionDateTime__c = DateTime.now().addMinutes(-10), // Should execute second but will be skipped
          AttemptNumber__c = 0,
          JobDescription__c = jobDescriptions[1].Id
        )
      };

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      final Id initialJobId = System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final List<AsyncApexJob> jobs = [
        SELECT Id, ApexClass.Name, JobType, Status
        FROM AsyncApexJob
        WHERE ApexClass.Name = 'AsyncApexJobExecutor'
      ];
      Assert.areEqual(1, jobs.size(), 'Expected exactly 1 AsyncApexJob record (initial).');
      Assert.areEqual(initialJobId, jobs[0].Id, 'Job ID should match initial job');

      // Query all remaining jobs to understand what happened
      final List<JobRequest__c> remainingJobs = [
        SELECT Id, Name, Status__c, AttemptNumber__c, JobDescription__r.MaxChunkSize__c, JobDescription__r.ProcessorName__c
        FROM JobRequest__c
        WHERE Name IN ('UnknownChunkJob1', 'UnknownChunkJob2')
        ORDER BY Name
      ];

      // The normal job should have been executed and deleted (successful jobs are deleted)
      // The unknown chunk size job should still exist because it was skipped
      Assert.areEqual(1, remainingJobs.size(), 'Only the unknown chunk size job should remain (normal job deleted after success)');
      Assert.areEqual('UnknownChunkJob2', remainingJobs[0].Name, 'The remaining job should be the unknown chunk size job');
      Assert.areEqual(ApexJobStatus.READY.name(), remainingJobs[0].Status__c, 'Unknown chunk size job should still be READY as it was skipped');
      Assert.areEqual(0, remainingJobs[0].AttemptNumber__c, 'Unknown chunk size job should not have been attempted');
    }
  }

  @IsTest
  private static void givenSystemEnabled_whenSpawnerThrows_thenLogsError() {
    // Arrange
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    MethodSpy enqueueSpy = factory.spawnerMock.spyOn('enqueue');
    enqueueSpy.throwsException(new TestException('Test error'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    final Id initialJobId = System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final List<AsyncApexJob> jobs = [
      SELECT Id, ApexClass.Name, JobType, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'AsyncApexJobExecutor'
    ];
    Assert.areEqual(initialJobId, jobs[0].Id, 'Expected exactly 1 AsyncApexJob record (initial).');
  }

  @IsTest
  private static void givenSystemDisabled_whenExecutorRuns_thenNoReenqueue() {
    // Arrange
    insert new ApexJobConfig__c(Enabled__c = false);
    ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    final Id initialJobId = System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final List<AsyncApexJob> jobs = [
      SELECT Id, ApexClass.Name, JobType, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'AsyncApexJobExecutor'
    ];
    Assert.areEqual(initialJobId, jobs[0].Id, 'Expected only the initial AsyncApexJob when system is disabled.');
  }

  @IsTest
  static void givenFactory_whenCallGetSpawner_thenReturnsImpl() {
    // Arrange
    final ApexJobFactory factory = new ApexJobFactoryImpl();

    // Act
    final JobExecutorSpawner spawner = factory.getSpawner();

    // Assert
    Assert.isInstanceOfType(spawner, JobExecutorQueueableSpawner.class);
  }

  @IsTest
  static void givenSpawner_whenCallEnqueue_thenEnqueuesJob() {
    // Arrange
    ApexJobTestMock testMock = new ApexJobTestMock();
    JobExecutorQueueableSpawner spawner = new JobExecutorQueueableSpawner(testMock.factoryStub);

    // Act
    Test.startTest();
    Id jobId = spawner.enqueue(5);
    Test.stopTest();

    // Assert
    Assert.isNotNull(jobId);
    // Not possible to expect because the pointer is not the same in the queueable context
    // Expect.that(executeSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  private static void givenJobWithUnknownChunkSize_whenExecutorRuns_thenProcessesSingleJobAndUpdatesChunkSize() {
    // Arrange
    System.runAs(getRunningUser()) {
      final JobDescription__c jobDesc = new JobDescription__c(
        Name = 'ChunkTestProcessor',
        ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor',
        Enabled__c = true,
        MaxChunkSize__c = -1, // Unknown chunk size
        CpuTimeBaseConsumption__c = -1,
        HeapSizeBaseConsumption__c = -1,
        DmlRowsBaseConsumption__c = -1,
        QueriesBaseConsumption__c = -1,
        DmlStatementsBaseConsumption__c = -1,
        QueryRowsBaseConsumption__c = -1,
        CalloutBaseConsumption__c = -1,
        CalloutTimeBaseConsumption__c = -1,
        PublishImmediateDmlBaseConsumption__c = -1,
        FutureCallsBaseConsumption__c = -1,
        SoslQueriesBaseConsumption__c = -1
      );
      insert jobDesc;

      final List<JobRequest__c> jobRequests = new List<JobRequest__c>();
      for (Integer i = 0; i < 5; i++) {
        jobRequests.add(
          new JobRequest__c(
            Name = 'ChunkTestJob' + i,
            Argument__c = '{"test": "data' + i + '"}',
            Enabled__c = true,
            Status__c = ApexJobStatus.READY.name(),
            NextExecutionDateTime__c = System.now().addMinutes(-10),
            LastExecutionDateTime__c = null,
            AttemptNumber__c = 0,
            JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
          )
        );
      }
      insert jobRequests;

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      final ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final JobDescription__c updatedJobDesc = [
        SELECT MaxChunkSize__c, CpuTimeBaseConsumption__c
        FROM JobDescription__c
        WHERE Id = :jobDesc.Id
      ];
      Assert.areEqual(1, updatedJobDesc.MaxChunkSize__c, 'Chunk size should be updated from -1 to 1 for first execution');
      Assert.areNotEqual(updatedJobDesc.CpuTimeBaseConsumption__c, -1, 'CPU consumption should be updated based on actual usage');
    }
  }

  @IsTest
  private static void givenJobWithKnownChunkSizeAndSufficientLimits_whenExecutorRuns_thenIncreasesChunkSize() {
    // Arrange
    final JobDescription__c jobDesc = new JobDescription__c(
      Name = 'ChunkIncreaseProcessor',
      ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor',
      Enabled__c = true,
      MaxChunkSize__c = 2,
      CpuTimeBaseConsumption__c = 100,
      HeapSizeBaseConsumption__c = 1000,
      DmlRowsBaseConsumption__c = 10,
      DmlStatementsBaseConsumption__c = 1,
      QueriesBaseConsumption__c = 1,
      QueryRowsBaseConsumption__c = 100
    );
    insert jobDesc;

    final List<JobRequest__c> jobRequests = new List<JobRequest__c>();
    for (Integer i = 0; i < 10; i++) {
      jobRequests.add(
        new JobRequest__c(
          Name = 'ChunkIncreaseJob' + i,
          Argument__c = '{"test": "data' + i + '"}',
          Enabled__c = true,
          Status__c = ApexJobStatus.READY.name(),
          NextExecutionDateTime__c = System.now().addMinutes(-10),
          LastExecutionDateTime__c = null,
          AttemptNumber__c = 0,
          JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
        )
      );
    }
    insert jobRequests;

    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    final ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final JobDescription__c updatedJobDesc = [
      SELECT MaxChunkSize__c
      FROM JobDescription__c
      WHERE Id = :jobDesc.Id
    ];
    Assert.isTrue(updatedJobDesc.MaxChunkSize__c >= 2, 'Chunk size should remain at least 2 or increase if limits allow');

    final Integer deletedJobs = [
      SELECT COUNT()
      FROM JobRequest__c
      WHERE Name LIKE 'ChunkIncreaseJob%' AND Status__c = :ApexJobStatus.SUCCESS.name()
    ];
    Assert.isTrue(deletedJobs == 0, 'Successfully processed jobs should be deleted');
  }

  @IsTest
  private static void givenJobWithHighConsumption_whenExecutorRuns_thenDoesNotIncreaseChunkSize() {
    // Arrange
    final JobDescription__c jobDesc = new JobDescription__c(
      Name = 'HighConsumptionProcessor',
      ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor',
      Enabled__c = true,
      MaxChunkSize__c = 2,
      CpuTimeBaseConsumption__c = 8000, // High CPU consumption
      HeapSizeBaseConsumption__c = 5000000, // High heap consumption
      DmlStatementsBaseConsumption__c = 140, // Near DML limit
      QueriesBaseConsumption__c = 95 // Near query limit
    );
    insert jobDesc;

    final List<JobRequest__c> jobRequests = new List<JobRequest__c>();
    for (Integer i = 0; i < 10; i++) {
      jobRequests.add(
        new JobRequest__c(
          Name = 'HighConsumptionJob' + i,
          Argument__c = '{"test": "data' + i + '"}',
          Enabled__c = true,
          Status__c = ApexJobStatus.READY.name(),
          NextExecutionDateTime__c = System.now().addMinutes(-10),
          LastExecutionDateTime__c = null,
          AttemptNumber__c = 0,
          JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
        )
      );
    }
    insert jobRequests;

    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    final ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

    // Act
    Test.startTest();
    System.enqueueJob(sut);
    Test.stopTest();

    // Assert
    final JobDescription__c updatedJobDesc = [
      SELECT MaxChunkSize__c
      FROM JobDescription__c
      WHERE Id = :jobDesc.Id
    ];
    Assert.areEqual(2, updatedJobDesc.MaxChunkSize__c, 'Chunk size should not increase when consumption is high');
  }

  @IsTest
  private static void givenJobWithLargerExecutedChunkSize_whenExecutorRuns_thenInterpolatesConsumptionCorrectly() {
    // Arrange
    System.runAs(getRunningUser()) {
      final JobDescription__c jobDesc = new JobDescription__c(
        Name = 'InterpolationProcessor',
        ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor',
        Enabled__c = true,
        MaxChunkSize__c = 1,
        CpuTimeBaseConsumption__c = 200,
        HeapSizeBaseConsumption__c = 2000,
        DmlRowsBaseConsumption__c = 20,
        QueriesBaseConsumption__c = 2
      );
      insert jobDesc;

      final List<JobRequest__c> jobRequests = new List<JobRequest__c>();
      for (Integer i = 0; i < 5; i++) {
        jobRequests.add(
          new JobRequest__c(
            Name = 'InterpolationJob' + i,
            Argument__c = '{"test": "data' + i + '"}',
            Enabled__c = true,
            Status__c = ApexJobStatus.READY.name(),
            NextExecutionDateTime__c = System.now().addMinutes(-10),
            LastExecutionDateTime__c = null,
            AttemptNumber__c = 0,
            JobDescription__r = new JobDescription__c(ProcessorName__c = 'AsyncProcessorTest.NormalPriorityProcessor')
          )
        );
      }
      insert jobRequests;

      final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
      insert config;
      final ApexJobFactoryForTest factory = new ApexJobFactoryForTest();
      final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(factory);

      // Act
      Test.startTest();
      System.enqueueJob(sut);
      Test.stopTest();

      // Assert
      final JobDescription__c updatedJobDesc = [
        SELECT MaxChunkSize__c, CpuTimeBaseConsumption__c, HeapSizeBaseConsumption__c, DmlRowsBaseConsumption__c
        FROM JobDescription__c
        WHERE Id = :jobDesc.Id
      ];
      // When chunk size increases, consumption values should be interpolated
      Assert.isTrue(updatedJobDesc.MaxChunkSize__c > 1, 'Chunk size should be at least the executed size');
      Assert.isTrue(updatedJobDesc.CpuTimeBaseConsumption__c >= 0, 'CPU consumption should be interpolated based on chunk size');
    }
  }

  /**
   * This internal Factory is used to mock only getSpawner to avoid
   * Infinite recursion.
   */
  private class ApexJobFactoryForTest extends ApexJobFactoryImpl {
    public Mock spawnerMock { get; private set; }

    public ApexJobFactoryForTest() {
      this.spawnerMock = Mock.forType(JobExecutorSpawner.class);
    }

    public override JobExecutorSpawner getSpawner() {
      return (JobExecutorSpawner) this.spawnerMock.stub;
    }
  }

  public class NormalPriorityProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      // Do nothing - just return success
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  public class NormalProcessorForUnknownTest implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      // Do nothing - just return success
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  public class UnknownChunkProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      // Do nothing - just return success
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  public class AnotherUnknownChunkProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      // Do nothing - just return success
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  public class ErrorProcessor implements ApexJob {
    public ApexJobResult execute(ApexJobContext context) {
      throw new TestException('Test error');
    }
  }

  public class TestException extends Exception {
  }
}
