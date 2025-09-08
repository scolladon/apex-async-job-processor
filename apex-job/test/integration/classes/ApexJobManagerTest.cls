@IsTest
private class ApexJobManagerTest {
  @IsTest
  static void givenJobRequestId_whenDisableJobRequest_thenEnabledFalse() {
    // Arrange
    final JobDescription__c jdSeed = new JobDescription__c(Enabled__c = true, ProcessorName__c = 'Proc_Seed');
    insert jdSeed;
    final JobRequest__c jr = new JobRequest__c(Enabled__c = true, Status__c = 'READY', JobDescription__c = jdSeed.Id);
    insert jr;

    // Act
    ApexJobManager.disableJobRequest(jr.Id);

    // Assert
    final JobRequest__c reloaded = [SELECT Id, Enabled__c FROM JobRequest__c WHERE Id = :jr.Id];
    Assert.isFalse(reloaded.Enabled__c, 'JobRequest must be disabled');
  }

  @IsTest
  static void givenJobDescriptionId_whenDisableJobDescription_thenEnabledFalse() {
    // Arrange
    final JobDescription__c jd = new JobDescription__c(Enabled__c = true, ProcessorName__c = 'Proc_A');
    insert jd;

    // Act
    ApexJobManager.disableJobDescription(jd.Id);

    // Assert
    final JobDescription__c reloaded = [SELECT Id, Enabled__c FROM JobDescription__c WHERE Id = :jd.Id];
    Assert.isFalse(reloaded.Enabled__c, 'JobDescription must be disabled');
  }

  @IsTest
  static void givenProcessorName_whenDisableJobDescription_thenUpsertsAndDisables() {
    // Arrange
    final String processorName = 'Proc_B';
    final JobDescription__c pre = new JobDescription__c(ProcessorName__c = processorName, Enabled__c = true);
    insert pre;

    // Act
    ApexJobManager.disableJobDescription(processorName);

    // Assert
    final JobDescription__c reloaded = [
      SELECT Id, ProcessorName__c, Enabled__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      LIMIT 1
    ];
    Assert.areEqual(processorName, reloaded.ProcessorName__c, 'Processor name must match');
    Assert.isFalse(reloaded.Enabled__c, 'JobDescription must be disabled via upsert');
  }

  @IsTest
  static void givenProcessorName_whenResetConsumptionModel_thenAllConsumptionsAAreReset() {
    // Arrange
    final String processorName = 'Proc_E';
    insert new JobDescription__c(
      ProcessorName__c = processorName,
      Enabled__c = true,
      MaxChunkSize__c = 10,
      ConsecutiveFailures__c = 2,
      SuccessStreak__c = 8,
      SmallestFailingChunk__c = 7,
      CpuTimeBaseConsumption__c = 1,
      CpuTimePerItemConsumption__c = 1,
      CpuTimeSafety__c = 1,
      HeapSizePerItemConsumption__c = 1,
      HeapSizeSafety__c = 1,
      HeapSizeBaseConsumption__c = 1,
      CalloutBaseConsumption__c = 1,
      CalloutPerItemConsumption__c = 1,
      CalloutSafety__c = 1,
      CalloutTimeBaseConsumption__c = 1,
      CalloutTimePerItemConsumption__c = 1,
      CalloutTimeSafety__c = 1,
      DmlRowsBaseConsumption__c = 1,
      DmlRowsPerItemConsumption__c = 1,
      DmlRowsSafety__c = 1,
      DmlStatementsBaseConsumption__c = 1,
      DmlStatementsPerItemConsumption__c = 1,
      DmlStatementsSafety__c = 1,
      FutureCallsBaseConsumption__c = 1,
      FutureCallsPerItemConsumption__c = 1,
      FutureCallsSafety__c = 1,
      PublishImmediateDmlBaseConsumption__c = 1,
      PublishImmediateDmlPerItemConsumption__c = 1,
      PublishImmediateDmlSafety__c = 1,
      QueryRowsBaseConsumption__c = 1,
      QueryRowsPerItemConsumption__c = 1,
      QueryRowsSafety__c = 1,
      QueriesBaseConsumption__c = 1,
      QueriesPerItemConsumption__c = 1,
      QueriesSafety__c = 1,
      SoslQueriesBaseConsumption__c = 1,
      SoslQueriesPerItemConsumption__c = 1,
      SoslQueriesSafety__c = 1,
      AggregateQueriesBaseConsumption__c = 1,
      AggregateQueriesPerItemConsumption__c = 1,
      AggregateQueriesSafety__c = 1,
      ApexCursorRowsBaseConsumption__c = 1,
      ApexCursorRowsPerItemConsumption__c = 1,
      ApexCursorRowsSafety__c = 1,
      FetchCallsOnApexCursorBaseConsumption__c = 1,
      FetchCallsOnApexCursorPerItemConsumption__c = 1,
      FetchCallsOnApexCursorSafety__c = 1,
      EmailInvocationsBaseConsumption__c = 1,
      EmailInvocationsPerItemConsumption__c = 1,
      EmailInvocationsSafety__c = 1,
      MobilePushApexCallsBaseConsumption__c = 1,
      MobilePushApexCallsPerItemConsumption__c = 1,
      MobilePushApexCallsSafety__c = 1,
      QueryLocatorRowsBaseConsumption__c = 1,
      QueryLocatorRowsPerItemConsumption__c = 1,
      QueryLocatorRowsSafety__c = 1
    );

    // Act
    ApexJobManager.resetConsumptionModel(processorName);

    // Assert
    final JobDescription__c jd = [
      SELECT
        ProcessorName__c,
        MaxChunkSize__c,
        CpuTimeBaseConsumption__c,
        CpuTimePerItemConsumption__c,
        CpuTimeSafety__c,
        HeapSizeBaseConsumption__c,
        HeapSizePerItemConsumption__c,
        HeapSizeSafety__c,
        CalloutBaseConsumption__c,
        CalloutPerItemConsumption__c,
        CalloutSafety__c,
        CalloutTimeBaseConsumption__c,
        CalloutTimePerItemConsumption__c,
        CalloutTimeSafety__c,
        DmlRowsBaseConsumption__c,
        DmlRowsPerItemConsumption__c,
        DmlRowsSafety__c,
        DmlStatementsBaseConsumption__c,
        DmlStatementsPerItemConsumption__c,
        DmlStatementsSafety__c,
        FutureCallsBaseConsumption__c,
        FutureCallsPerItemConsumption__c,
        FutureCallsSafety__c,
        PublishImmediateDmlBaseConsumption__c,
        PublishImmediateDmlPerItemConsumption__c,
        PublishImmediateDmlSafety__c,
        QueryRowsBaseConsumption__c,
        QueryRowsPerItemConsumption__c,
        QueryRowsSafety__c,
        QueriesBaseConsumption__c,
        QueriesPerItemConsumption__c,
        QueriesSafety__c,
        SoslQueriesBaseConsumption__c,
        SoslQueriesPerItemConsumption__c,
        SoslQueriesSafety__c,
        AggregateQueriesBaseConsumption__c,
        AggregateQueriesPerItemConsumption__c,
        AggregateQueriesSafety__c,
        ApexCursorRowsBaseConsumption__c,
        ApexCursorRowsPerItemConsumption__c,
        ApexCursorRowsSafety__c,
        FetchCallsOnApexCursorBaseConsumption__c,
        FetchCallsOnApexCursorPerItemConsumption__c,
        FetchCallsOnApexCursorSafety__c,
        EmailInvocationsBaseConsumption__c,
        EmailInvocationsPerItemConsumption__c,
        EmailInvocationsSafety__c,
        MobilePushApexCallsBaseConsumption__c,
        MobilePushApexCallsPerItemConsumption__c,
        MobilePushApexCallsSafety__c,
        QueryLocatorRowsBaseConsumption__c,
        QueryLocatorRowsPerItemConsumption__c,
        QueryLocatorRowsSafety__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      LIMIT 1
    ];
    Assert.areEqual(-1, jd.MaxChunkSize__c, 'MaxChunkSize must be reset');
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.CpuTimeBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.CpuTimePerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.CpuTimeSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.HeapSizeBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.HeapSizePerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.HeapSizeSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.CalloutBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.CalloutPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.CalloutSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.CalloutTimeBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.CalloutTimePerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.CalloutTimeSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.DmlRowsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.DmlRowsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.DmlRowsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.DmlStatementsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.DmlStatementsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.DmlStatementsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.FutureCallsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.FutureCallsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.FutureCallsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.PublishImmediateDmlBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.PublishImmediateDmlPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.PublishImmediateDmlSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.QueryRowsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.QueryRowsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.QueryRowsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.QueriesBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.QueriesPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.QueriesSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.SoslQueriesBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.SoslQueriesPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.SoslQueriesSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.futureCallsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.futureCallsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.futureCallsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.AggregateQueriesBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.AggregateQueriesPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.AggregateQueriesSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.ApexCursorRowsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.ApexCursorRowsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.ApexCursorRowsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.FetchCallsOnApexCursorBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.FetchCallsOnApexCursorPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.FetchCallsOnApexCursorSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.EmailInvocationsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.EmailInvocationsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.EmailInvocationsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.MobilePushApexCallsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.MobilePushApexCallsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.MobilePushApexCallsSafety__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.QueryLocatorRowsBaseConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.QueryLocatorRowsPerItemConsumption__c);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.QueryLocatorRowsSafety__c);
  }

  @IsTest
  static void givenDescribeJobBuilder_whenConfigureAllOptions_thenInsertsEnabledWithFields() {
    // Arrange
    final String processorName = 'Proc_F';
    final List<Schema.PicklistEntry> allowedDaysEntries = JobDescription__c.AllowedDays__c.getDescribe().getPicklistValues();
    final Integer pickCount = Math.min(3, allowedDaysEntries.size());
    final List<String> allowedDays = new List<String>();
    for (Integer i = 0; i < pickCount; i++) {
      allowedDays.add(allowedDaysEntries[i].getValue());
    }
    final String expectedAllowedDays = String.join(allowedDays, ';');
    final Time startTime = Time.newInstance(8, 0, 0, 0);
    final Time endTime = Time.newInstance(18, 0, 0, 0);
    final Integer maxAttempts = 4;
    final Integer minInterval = 30;

    // Act
    final ApexJobManager.JobDescriptionBuilder sut = ApexJobManager.define()
      .processor(processorName)
      .priority(10)
      .recurrent()
      .allowedOn(allowedDays)
      .allowedBetween(startTime, endTime)
      .maxAttempts(maxAttempts)
      .minInterval(minInterval);
    final JobDescription__c created = sut.save();

    // Assert
    final JobDescription__c jd = [
      SELECT ProcessorName__c, Enabled__c, Priority__c, isRecurrent__c, AllowedDays__c, AllowedStartTime__c, AllowedEndTime__c, MaxExecutionAttempt__c, MinJobInterval__c
      FROM JobDescription__c
      WHERE Id = :created.Id
    ];
    Assert.areEqual(processorName, jd.ProcessorName__c);
    Assert.isTrue(jd.Enabled__c, 'JobDescription must be enabled by default');
    Assert.areEqual(10, jd.Priority__c, 'Priority must be set');
    Assert.isTrue(jd.isRecurrent__c, 'Recurrent must be set');
    Assert.areEqual(expectedAllowedDays, jd.AllowedDays__c, 'Allowed days must be semicolon-joined');
    Assert.areEqual(startTime, jd.AllowedStartTime__c, 'Start time must match');
    Assert.areEqual(endTime, jd.AllowedEndTime__c, 'End time must match');
    Assert.areEqual(maxAttempts, jd.MaxExecutionAttempt__c, 'Max attempts must match');
    Assert.areEqual(minInterval, jd.MinJobInterval__c, 'Min interval must match');
  }

  @IsTest
  static void givenBuilder_whenRequestWithProcessorNameString_thenInsertsResolvingLookupByProcessorName() {
    // Arrange
    final String processorName = 'Proc_G';
    final JobDescription__c jd = new JobDescription__c(ProcessorName__c = processorName, Enabled__c = true);
    insert jd;
    final Datetime scheduled = Datetime.now().addHours(2);
    final Map<String, Object> payload = new Map<String, Object>{ 'x' => 1 };

    // Act
    final ApexJobManager.JobRequestBuilder sut = ApexJobManager.request().forProcessor(processorName).scheduleAt(scheduled).payload(payload);
    final JobRequest__c created = sut.save();

    // Assert
    final JobRequest__c reloaded = [
      SELECT Id, Status__c, Enabled__c, JobDescription__c, JobDescription__r.ProcessorName__c, NextExecutionDateTime__c, Argument__c
      FROM JobRequest__c
      WHERE Id = :created.Id
    ];
    Assert.areEqual('READY', reloaded.Status__c, 'Default status must be READY');
    Assert.isTrue(reloaded.Enabled__c, 'JobRequest must be enabled by default');
    Assert.areEqual(jd.Id, reloaded.JobDescription__c, 'JobDescription lookup must resolve from processor name');
    Assert.areEqual(processorName, reloaded.JobDescription__r.ProcessorName__c, 'Processor name must match');
    Assert.areEqual(scheduled, reloaded.NextExecutionDateTime__c, 'Scheduled datetime must match');
    Assert.isTrue(String.valueOf(reloaded.Argument__c).contains('"x":1'), 'Argument must be serialized');
  }

  @IsTest
  static void givenDisabledJobRequest_whenEnableJobRequest_thenEnabledTrue() {
    // Arrange
    final JobDescription__c jd = new JobDescription__c(Enabled__c = true, ProcessorName__c = 'Proc_Enable_JR');
    insert jd;
    final JobRequest__c jr = new JobRequest__c(Enabled__c = false, Status__c = 'READY', JobDescription__c = jd.Id);
    insert jr;

    // Act
    ApexJobManager.enableJobRequest(jr.Id);

    // Assert
    final JobRequest__c reloaded = [SELECT Id, Enabled__c FROM JobRequest__c WHERE Id = :jr.Id];
    Assert.isTrue(reloaded.Enabled__c, 'JobRequest must be enabled');
  }

  @IsTest
  static void givenDisabledJobDescriptionId_whenEnableJobDescription_thenEnabledTrue() {
    // Arrange
    final JobDescription__c jd = new JobDescription__c(Enabled__c = false, ProcessorName__c = 'Proc_Enable_JD');
    insert jd;

    // Act
    ApexJobManager.enableJobDescription(jd.Id);

    // Assert
    final JobDescription__c reloaded = [SELECT Id, Enabled__c FROM JobDescription__c WHERE Id = :jd.Id];
    Assert.isTrue(reloaded.Enabled__c, 'JobDescription must be enabled');
  }

  @IsTest
  static void givenProcessorName_whenEnableJobDescription_thenUpsertsAndEnables() {
    // Arrange
    final String processorName = 'Proc_Enable_Upsert';
    insert new JobDescription__c(ProcessorName__c = processorName, Enabled__c = false);

    // Act
    ApexJobManager.enableJobDescription(processorName);

    // Assert
    final JobDescription__c reloaded = [
      SELECT Id, ProcessorName__c, Enabled__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      LIMIT 1
    ];
    Assert.isTrue(reloaded.Enabled__c, 'JobDescription must be enabled via upsert');
  }

  @IsTest
  static void givenAliases_whenRequestAndDefine_thenSavePersists() {
    // Arrange
    final String processorName = 'Proc_Aliases';

    // Act
    final JobDescription__c jd = ApexJobManager.define().processor(processorName).maxAttempts(2).minInterval(5).save();

    final Datetime scheduled = Datetime.now().addMinutes(15);
    final Map<String, Object> payload = new Map<String, Object>{ 'k' => 'v' };
    final ApexJobManager.JobRequestBuilder req = ApexJobManager.request().forDescription(jd.Id).scheduleAt(scheduled).payload(payload);

    final JobRequest__c beforeSave = req.toSObject();
    final JobRequest__c saved = req.save();

    // Assert
    Assert.areEqual(jd.Id, beforeSave.JobDescription__c, 'Builder should hold JD Id before save');
    Assert.areEqual(scheduled, beforeSave.NextExecutionDateTime__c, 'Builder should hold schedule before save');

    final JobRequest__c reloaded = [
      SELECT Id, Status__c, Enabled__c, JobDescription__c, NextExecutionDateTime__c, Argument__c
      FROM JobRequest__c
      WHERE Id = :saved.Id
    ];
    Assert.areEqual('READY', reloaded.Status__c, 'Default status must be READY');
    Assert.isTrue(reloaded.Enabled__c, 'JobRequest must be enabled by default');
    Assert.areEqual(jd.Id, reloaded.JobDescription__c, 'JobDescription lookup must be set');
    Assert.areEqual(scheduled, reloaded.NextExecutionDateTime__c, 'Scheduled datetime must match');
    Assert.isTrue(String.valueOf(reloaded.Argument__c).contains('"k":"v"'), 'Argument must be serialized');
  }
}
