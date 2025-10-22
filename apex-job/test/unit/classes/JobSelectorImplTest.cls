@IsTest
private class JobSelectorImplTest {
  @TestSetup
  static void setup() {
    // Arrange

    // Create JobDescription records using ApexJobTestFixture
    final List<JobDescription__c> jobDescriptions = new List<JobDescription__c>();

    // High priority enabled job description
    jobDescriptions.add(
      ApexJobTestFixture.aJobDescription()
        .withName('HighPriorityProcessor')
        .withProcessorName('HighPriorityProcessor')
        .enabled()
        .withMaxChunkSize(100)
        .withMaxExecutionAttempt(3)
        .withMinJobInterval(5)
        .priority(100)
        .recurrent()
        .build()
    );

    // Normal priority enabled job description
    jobDescriptions.add(
      ApexJobTestFixture.aJobDescription()
        .withName('NormalPriorityProcessor')
        .withProcessorName('NormalPriorityProcessor')
        .enabled()
        .withMaxChunkSize(-1)
        .withMaxExecutionAttempt(2)
        .withMinJobInterval(10)
        .priority(10)
        .build()
    );

    // Disabled job description
    jobDescriptions.add(
      ApexJobTestFixture.aJobDescription()
        .withName('DisabledProcessor')
        .withProcessorName('DisabledProcessor')
        .disabled()
        .withMaxChunkSize(25)
        .withMaxExecutionAttempt(1)
        .withMinJobInterval(15)
        .priority(10)
        .recurrent()
        .build()
    );

    insert jobDescriptions;

    // Create JobRequest records using ApexJobTestFixture
    final List<JobRequest__c> jobRequests = new List<JobRequest__c>();

    // Ready high priority job
    jobRequests.add(
      ApexJobTestFixture.aJobRequest()
        .withName('HighPriorityJob1')
        .withArgument('{"test": "data1"}')
        .enabled()
        .ready()
        .readyNow()
        .withAttemptNumber(0)
        .withJobDescription(jobDescriptions[0].Id)
        .build()
    );

    // Ready normal priority job
    jobRequests.add(
      ApexJobTestFixture.aJobRequest()
        .withName('NormalPriorityJob1')
        .withArgument('{"test": "data2"}')
        .enabled()
        .ready()
        .withNextExecutionDateTime(System.now().addMinutes(-10))
        .withAttemptNumber(0)
        .withJobDescription(jobDescriptions[1].Id)
        .build()
    );

    // Future job (not ready)
    jobRequests.add(
      ApexJobTestFixture.aJobRequest()
        .withName('FutureJob')
        .withArgument('{"test": "data3"}')
        .enabled()
        .ready()
        .readyInFuture(60)
        .withAttemptNumber(0)
        .withJobDescription(jobDescriptions[0].Id)
        .build()
    );

    // Disabled job request
    jobRequests.add(
      ApexJobTestFixture.aJobRequest()
        .withName('DisabledJob')
        .withArgument('{"test": "data4"}')
        .disabled()
        .failure()
        .withNextExecutionDateTime(System.now().addMinutes(-5))
        .withAttemptNumber(0)
        .withJobDescription(jobDescriptions[0].Id)
        .build()
    );

    // Job with disabled job description
    jobRequests.add(
      ApexJobTestFixture.aJobRequest()
        .withName('JobWithDisabledDescription')
        .withArgument('{"test": "data5"}')
        .enabled()
        .ready()
        .withNextExecutionDateTime(System.now().addMinutes(-5))
        .withAttemptNumber(0)
        .withJobDescription(jobDescriptions[2].Id)
        .build()
    );

    insert jobRequests;
  }

  private static LimitsUsage buildMaxAvailableGovernorLimits() {
    return ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(60000)
      .withHeapSize(12 * 1024 * 1024)
      .withCallout(100)
      .withCalloutTime(120000)
      .withPublishImmediateDml(150)
      .withDmlRows(10000)
      .withDmlStatements(150)
      .withQueryRows(50000)
      .withQueries(200)
      .withSoslQueries(20)
      .withFutureCalls(50)
      .build();
  }

  @IsTest
  static void givenEnabledJobsReadyForProcessing_whenGetJobs_thenReturnsValidJobs() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.areEqual(2, result.size(), 'Should return 2 eligible jobs (high and normal priority)');
    Assert.areEqual('HighPriorityJob1', result[0].Name, 'First job should be high priority job');
    Assert.areEqual('NormalPriorityJob1', result[1].Name, 'Second job should be normal priority job');
    Assert.areEqual(100, result[0].JobDescription__r.Priority__c, 'First job should be high priority');
    Assert.areEqual(10, result[1].JobDescription__r.Priority__c, 'Second job should be normal priority');
  }

  @IsTest
  static void givenEnabledJobReadyForProcessingAndAlreadyExecutedJobs_whenGetJobs_thenReturnsValidJobsWithoutUnknownChunkSizeJobs() {
    // Arrange
    ApexJobTransactionContext.getInstance().markExecutedJobs();
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.areEqual(1, result.size(), 'Should return 2 eligible jobs (high and normal priority)');
    Assert.areNotEqual(-1, result[0].JobDescription__r.MaxChunkSize__c, 'No unknown chunk size job');
  }

  @IsTest
  static void givenFutureJobs_whenGetJobs_thenExcludesFutureJobs() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl selector = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = selector.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    for (JobRequest__c job : result) {
      Assert.isTrue(job.NextExecutionDateTime__c <= System.now(), 'Should not return future jobs');
    }
  }

  @IsTest
  static void givenNoEligibleJobs_whenGetJobs_thenReturnsEmptyList() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Delete all test data to simulate no eligible jobs
    delete [SELECT Id FROM JobRequest__c WHERE NextExecutionDateTime__c <= :System.now()];

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.areEqual(0, result.size(), 'Should return empty list when no eligible jobs exist');
  }

  @IsTest
  static void givenValidJobs_whenGetJobs_thenReturnsAllRequiredFields() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);
    Set<String> expectedFields = new Set<String>{
      'Id',
      'Name',
      'Argument__c',
      'Enabled__c',
      'Status__c',
      'NextExecutionDateTime__c',
      //'LastExecutionDateTime__c', // Not populated by getPopulatedFieldsAsMap from Apex because null value cf https://salesforce.stackexchange.com/a/204467
      //'LastExecutionMessage__c', // Not populated by getPopulatedFieldsAsMap from Apex because null value cf https://salesforce.stackexchange.com/a/204467
      'AttemptNumber__c',
      'JobDescription__c',
      // Include all JobDescription fields
      'JobDescription__r.Id',
      'JobDescription__r.Name',
      'JobDescription__r.ProcessorName__c',
      'JobDescription__r.Enabled__c',
      'JobDescription__r.MaxChunkSize__c',
      'JobDescription__r.MaxChunkSizeLimit__c',
      'JobDescription__r.MaxExecutionAttempt__c',
      'JobDescription__r.MinJobInterval__c',
      'JobDescription__r.Priority__c',
      'JobDescription__r.isRecurrent__c',
      //'JobDescription__r.LastExecutionDateTime__c', // Not populated by getPopulatedFieldsAsMap from Apex because null value cf https://salesforce.stackexchange.com/a/204467
      'JobDescription__r.ConsecutiveFailures__c',
      'JobDescription__r.SmallestFailingChunk__c',
      'JobDescription__r.SuccessStreak__c',
      'JobDescription__r.VariationResetThreashold__c',
      // Governor limits consumption fields
      'JobDescription__r.CpuTimeBaseConsumption__c',
      'JobDescription__r.CpuTimePerItemConsumption__c',
      'JobDescription__r.CpuTimeSafety__c',
      'JobDescription__r.HeapSizeBaseConsumption__c',
      'JobDescription__r.HeapSizePerItemConsumption__c',
      'JobDescription__r.HeapSizeSafety__c',
      'JobDescription__r.CalloutBaseConsumption__c',
      'JobDescription__r.CalloutPerItemConsumption__c',
      'JobDescription__r.CalloutSafety__c',
      'JobDescription__r.CalloutTimeBaseConsumption__c',
      'JobDescription__r.CalloutTimePerItemConsumption__c',
      'JobDescription__r.CalloutTimeSafety__c',
      'JobDescription__r.PublishImmediateDmlBaseConsumption__c',
      'JobDescription__r.PublishImmediateDmlPerItemConsumption__c',
      'JobDescription__r.PublishImmediateDmlSafety__c',
      'JobDescription__r.DmlRowsBaseConsumption__c',
      'JobDescription__r.DmlRowsPerItemConsumption__c',
      'JobDescription__r.DmlRowsSafety__c',
      'JobDescription__r.DmlStatementsBaseConsumption__c',
      'JobDescription__r.DmlStatementsPerItemConsumption__c',
      'JobDescription__r.DmlStatementsSafety__c',
      'JobDescription__r.QueryRowsBaseConsumption__c',
      'JobDescription__r.QueryRowsPerItemConsumption__c',
      'JobDescription__r.QueryRowsSafety__c',
      'JobDescription__r.QueriesBaseConsumption__c',
      'JobDescription__r.QueriesPerItemConsumption__c',
      'JobDescription__r.QueriesSafety__c',
      'JobDescription__r.SoslQueriesBaseConsumption__c',
      'JobDescription__r.SoslQueriesPerItemConsumption__c',
      'JobDescription__r.SoslQueriesSafety__c',
      'JobDescription__r.FutureCallsBaseConsumption__c',
      'JobDescription__r.FutureCallsPerItemConsumption__c',
      'JobDescription__r.FutureCallsSafety__c',
      'JobDescription__r.AggregateQueriesBaseConsumption__c',
      'JobDescription__r.AggregateQueriesPerItemConsumption__c',
      'JobDescription__r.AggregateQueriesSafety__c',
      'JobDescription__r.ApexCursorRowsBaseConsumption__c',
      'JobDescription__r.ApexCursorRowsPerItemConsumption__c',
      'JobDescription__r.ApexCursorRowsSafety__c',
      'JobDescription__r.FetchCallsOnApexCursorBaseConsumption__c',
      'JobDescription__r.FetchCallsOnApexCursorPerItemConsumption__c',
      'JobDescription__r.FetchCallsOnApexCursorSafety__c',
      'JobDescription__r.EmailInvocationsBaseConsumption__c',
      'JobDescription__r.EmailInvocationsPerItemConsumption__c',
      'JobDescription__r.EmailInvocationsSafety__c',
      'JobDescription__r.MobilePushApexCallsBaseConsumption__c',
      'JobDescription__r.MobilePushApexCallsPerItemConsumption__c',
      'JobDescription__r.MobilePushApexCallsSafety__c',
      'JobDescription__r.QueryLocatorRowsBaseConsumption__c',
      'JobDescription__r.QueryLocatorRowsPerItemConsumption__c',
      'JobDescription__r.QueryLocatorRowsSafety__c',
      'JobDescription__r.QueueableJobsBaseConsumption__c',
      'JobDescription__r.QueueableJobsPerItemConsumption__c',
      'JobDescription__r.QueueableJobsSafety__c'
    };

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    for (JobRequest__c job : result) {
      Set<String> remainingExpectedFields = expectedFields.clone();
      Set<String> populatedFields = getPopulatedFieldNames(job);

      remainingExpectedFields.removeAll(populatedFields);
      populatedFields.removeAll(expectedFields);

      Assert.isTrue(populatedFields.isEmpty(), 'Unexpected extra fields found: ' + String.join(new List<String>(populatedFields), ', '));
      Assert.isTrue(remainingExpectedFields.isEmpty(), 'Missing expected fields: ' + String.join(new List<String>(remainingExpectedFields), ', '));
    }
  }

  private static Set<String> getPopulatedFieldNames(SObject record) {
    Set<String> fieldNames = new Set<String>();
    Map<String, Object> populatedFields = record.getPopulatedFieldsAsMap();

    for (String fieldName : populatedFields.keySet()) {
      if (fieldName.endsWith('__r')) {
        // Handle lookup fields
        SObject relatedRecord = record.getSObject(fieldName);
        Map<String, Object> relatedFields = relatedRecord.getPopulatedFieldsAsMap();
        for (String relatedFieldName : relatedFields.keySet()) {
          fieldNames.add(fieldName + '.' + relatedFieldName);
        }
      } else {
        // Handle fields
        fieldNames.add(fieldName);
      }
    }

    return fieldNames;
  }

  @IsTest
  static void givenLargeNumberOfJobs_whenGetJobs_thenRespectsLimitOf50() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final LimitsUsage mockAvailableLimits = ApexJobTestFixture.aLimitsUsage().withCpuTime(10000).withHeapSize(5000000).withCallout(10).build();

    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    // Get existing job description for bulk insert
    JobDescription__c jobDesc = new JobDescription__c(ProcessorName__c = 'HighPriorityProcessor');

    List<JobRequest__c> bulkJobs = ApexJobTestFixture.aJobRequest()
      .withJobDescription(jobDesc)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-1))
      .withAttemptNumber(0)
      .withName('BulkJob{0}')
      .withArgument('"{test: \"data\"}"')
      .buildMany(60);
    insert bulkJobs;

    JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.areEqual(50, result.size(), 'Should respect LIMIT 50 in SOQL query');
  }

  @IsTest
  static void givenJobsWithSameProcessor_whenGetJobs_thenOrdersByProcessorNameAndExecutionTime() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    // Create additional jobs with same processor to test ordering
    JobDescription__c jobDesc = new JobDescription__c(ProcessorName__c = 'HighPriorityProcessor');

    List<JobRequest__c> additionalJobs = ApexJobTestFixture.aJobRequest()
      .withJobDescription(jobDesc)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-20))
      .withAttemptNumber(0)
      .withName('SameProcessorJob')
      .withArgument('{"order": "test1"}')
      .buildMany(2);

    insert additionalJobs;

    JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.areEqual(4, result.size(), 'Should return multiple jobs for ordering test');
    // Find jobs from same processor and verify they are ordered by execution time
    for (Integer i = 0; i < 1; ++i) {
      Assert.areEqual('HighPriorityProcessor', result[i].JobDescription__r.ProcessorName__c, 'Jobs from same processor should be ordered by NextExecutionDateTime__c ASC');
      Assert.isTrue(result[i].NextExecutionDateTime__c <= result[i + 1].NextExecutionDateTime__c, 'Jobs from same processor should be ordered by NextExecutionDateTime__c ASC');
    }
  }

  @IsTest
  static void givenAvailableLimits_whenGetEligibleJobsWithLimits_thenFiltersCorrectly() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    // Create JobDescription with specific consumption values
    JobDescription__c limitedJobDesc = ApexJobTestFixture.aJobDescription()
      .withName('LimitedProcessor')
      .withProcessorName('LimitedProcessor')
      .enabled()
      .withCpuTimeConsumption(5000) // Within limits
      .withHeapSizeConsumption(1000000) // Within limits
      .withCalloutConsumption(2) // Within limits
      .buildAndInsert();

    JobRequest__c limitedJob = ApexJobTestFixture.aJobRequest()
      .withJobDescription(limitedJobDesc)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName('LimitedJob')
      .withArgument('{"limited": "test"}')
      .build();
    insert limitedJob;

    // Set available limits that allow the job
    LimitsUsage availableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(availableLimits);

    JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.isFalse(result.isEmpty(), 'Result should not be empty');
    Boolean foundLimitedJob = false;
    for (JobRequest__c job : result) {
      if (job.Name == 'LimitedJob') {
        foundLimitedJob = true;
        break;
      }
    }
    Assert.isTrue(foundLimitedJob, 'Should include job that fits within available limits');
  }

  @IsTest
  static void givenInsufficientLimits_whenGetEligibleJobsWithLimits_thenExcludesJobs() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    // Create JobDescription with high consumption values
    JobDescription__c highConsumptionJobDesc = ApexJobTestFixture.aJobDescription()
      .withName('HighConsumptionProcessor')
      .withProcessorName('HighConsumptionProcessor')
      .enabled()
      .withCpuTimeConsumption(15000) // Higher than available
      .withHeapSizeConsumption(10000000) // Higher than available
      .withCalloutConsumption(20) // Higher than available
      .buildAndInsert();

    JobRequest__c highConsumptionJob = ApexJobTestFixture.aJobRequest()
      .withJobDescription(highConsumptionJobDesc)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName('HighConsumptionJob')
      .withArgument('{"high": "consumption"}')
      .build();
    insert highConsumptionJob;

    // Set available limits that are insufficient
    LimitsUsage insufficientLimits = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(5000)
      .withHeapSize(1000000)
      .withCallout(2)
      .withCalloutTime(-1)
      .withPublishImmediateDml(-1)
      .withDmlRows(-1)
      .withDmlStatements(-1)
      .withQueryRows(-1)
      .withQueries(-1)
      .withSoslQueries(-1)
      .withFutureCalls(-1)
      .build();
    mocks.getAvailableLimitsSpy.returns(insufficientLimits);

    JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Assert.isNotNull(result, 'Result should not be null');
    Boolean foundHighConsumptionJob = false;
    for (JobRequest__c job : result) {
      if (job.Name == 'HighConsumptionJob') {
        foundHighConsumptionJob = true;
        break;
      }
    }
    Assert.isFalse(foundHighConsumptionJob, 'Should exclude job that exceeds available limits');
  }

  @IsTest
  static void givenExistingJobDescription_whenGetEligibleJobs_thenExcludesJobDescription() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();

    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);
    JobDescription__c jobDescriptionToExclude = [SELECT Id FROM JobDescription__c WHERE ProcessorName__c = 'NormalPriorityProcessor' LIMIT 1];

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>{ jobDescriptionToExclude.Id });
    Test.stopTest();

    // Assert
    Assert.areEqual(1, result.size(), 'Should return only one eligible job');
    Assert.areEqual('HighPriorityJob1', result[0].Name, 'First job should be high priority job');
  }

  @IsTest
  static void givenRestrictedJobDescription_whenGetEligibleJobs_thenRespectTimeRestriction() {
    // Arrange
    Integer currentWeekDay = Integer.valueOf(Datetime.now().format('u'));
    List<String> restrictedDays = new List<String>{};
    for (Integer i = 1; i <= 7; ++i) {
      if (i != currentWeekDay) {
        restrictedDays.add('' + i);
      }
    }
    Time currentTime = Datetime.now().time();
    JobDescription__c restrictedJobDescription = ApexJobTestFixture.aJobDescription()
      .withName('Restricted NormalPriorityProcessor')
      .withProcessorName('RestrictedNormalPriorityProcessor')
      .enabled()
      .withAllowedDays(String.join(restrictedDays, ';'))
      .withAllowedStartTime(currentTime.addSeconds(-2))
      .withAllowedEndTime(currentTime.addSeconds(-1))
      .buildAndInsert();
    JobRequest__c restrictedJobRequest = ApexJobTestFixture.aJobRequest()
      .withJobDescription(restrictedJobDescription)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName('RestrictedJob')
      .withArgument('{"restricted": "job"}')
      .build();
    insert restrictedJobRequest;

    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage mockAvailableLimits = buildMaxAvailableGovernorLimits();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    List<JobRequest__c> result = sut.getEligibleJobs(new List<Id>());
    Test.stopTest();

    // Assert
    Assert.areEqual(2, result.size(), 'Should not return restricted job');
    Assert.areNotEqual('RestrictedJob', result[0].Name, 'First job should not be restricted job');
    Assert.areNotEqual('RestrictedJob', result[1].Name, 'Second job should not be restricted job');
  }

  @IsTest
  static void givenCalloutAndDmlLimits_whenGetEligibleJobs_thenFiltersJobsWithCallouts() {
    // Arrange - Create job with callout
    final JobDescription__c jobDescWithCallout = ApexJobTestFixture.aJobDescription()
      .withName('JobWithCallout')
      .withProcessorName('JobWithCalloutProcessor')
      .enabled()
      .withCalloutConsumption(5)
      .withCpuTimeConsumption(-1)
      .withHeapSizeConsumption(-1)
      .withCalloutTimeConsumption(-1)
      .withPublishImmediateDmlConsumption(-1)
      .withDmlRowsConsumption(-1)
      .withDmlStatementsConsumption(-1)
      .withQueryRowsConsumption(-1)
      .withQueriesConsumption(-1)
      .withSoslQueriesConsumption(-1)
      .withFutureCallsConsumption(-1)
      .buildAndInsert();

    ApexJobTestFixture.aJobRequest()
      .withJobDescription(jobDescWithCallout)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName('JobWithCallout')
      .withArgument('{"callout": "test"}')
      .buildAndInsert();

    // Create job without callout
    final JobDescription__c jobDescWithoutCallout = ApexJobTestFixture.aJobDescription()
      .withName('JobWithoutCallout')
      .withProcessorName('JobWithoutCalloutProcessor')
      .enabled()
      .withCalloutConsumption(0)
      .withCpuTimeConsumption(-1)
      .withHeapSizeConsumption(-1)
      .withCalloutTimeConsumption(-1)
      .withPublishImmediateDmlConsumption(-1)
      .withDmlRowsConsumption(-1)
      .withDmlStatementsConsumption(-1)
      .withQueryRowsConsumption(-1)
      .withQueriesConsumption(-1)
      .withSoslQueriesConsumption(-1)
      .withFutureCallsConsumption(-1)
      .buildAndInsert();

    final JobRequest__c jobWithoutCallout = ApexJobTestFixture.aJobRequest()
      .withJobDescription(jobDescWithoutCallout)
      .enabled()
      .withStatus(ApexJobStatus.READY)
      .withNextExecutionDateTime(System.now().addMinutes(-5))
      .withAttemptNumber(0)
      .withName('JobWithoutCallout')
      .withArgument('{"callout": "test"}')
      .buildAndInsert();

    // Mock LimitService to return available limits with callout = 0 (simulating DML + callout scenario)
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final LimitsUsage mockAvailableLimits = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(10000)
      .withHeapSize(6000000)
      .withCallout(10) // This simulates the getMaxCallout returning 0 when DML and callouts exist
      .withCalloutTime(120000)
      .withPublishImmediateDml(150)
      .withDmlRows(10000)
      .withDmlStatements(150)
      .withQueryRows(50000)
      .withQueries(100)
      .withSoslQueries(20)
      .withFutureCalls(50)
      .build();
    mocks.getAvailableLimitsSpy.returns(mockAvailableLimits);

    final JobSelectorImpl sut = new JobSelectorImpl(mocks.factoryStub);

    // Act
    Test.startTest();
    update jobWithoutCallout; // Simulate DML;
    final List<JobRequest__c> result = sut.getEligibleJobs(null);
    Test.stopTest();

    // Assert
    Boolean foundCalloutJob = false;
    Boolean foundNonCalloutJob = false;
    for (JobRequest__c job : result) {
      if (job.Name == 'JobWithCallout') {
        foundCalloutJob = true;
      }
      if (job.Name == 'JobWithoutCallout') {
        foundNonCalloutJob = true;
      }
    }

    Assert.isFalse(foundCalloutJob, 'When callout limit is 0 (DML + callout scenario), should exclude jobs with callouts');
    Assert.isTrue(foundNonCalloutJob, 'When callout limit is 0, should still include jobs without callouts');
  }
}
