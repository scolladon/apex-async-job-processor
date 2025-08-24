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
  static void givenProcessorName_whenResetUsage_thenAllConsumptionsSetToMinusOne() {
    // Arrange
    final String processorName = 'Proc_E';
    insert new JobDescription__c(
      ProcessorName__c = processorName,
      Enabled__c = true,
      MaxChunkSize__c = 10,
      CpuTimeConsumption__c = 1,
      HeapSizeConsumption__c = 1,
      CalloutConsumption__c = 1,
      CalloutTimeConsumption__c = 1,
      DmlRowsConsumption__c = 1,
      DmlStatementsConsumption__c = 1,
      FutureCallsConsumption__c = 1,
      PublishImmediateDmlConsumption__c = 1,
      QueryRowsConsumption__c = 1,
      QueriesConsumption__c = 1,
      SoslQueriesConsumption__c = 1
    );

    // Act
    ApexJobManager.resetUsage(processorName);

    // Assert
    final JobDescription__c jd = [
      SELECT
        ProcessorName__c,
        MaxChunkSize__c,
        CpuTimeConsumption__c,
        HeapSizeConsumption__c,
        CalloutConsumption__c,
        CalloutTimeConsumption__c,
        DmlRowsConsumption__c,
        DmlStatementsConsumption__c,
        FutureCallsConsumption__c,
        PublishImmediateDmlConsumption__c,
        QueryRowsConsumption__c,
        QueriesConsumption__c,
        SoslQueriesConsumption__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      LIMIT 1
    ];
    Assert.areEqual(-1, jd.MaxChunkSize__c, 'MaxChunkSize must be reset');
    Assert.areEqual(-1, jd.CpuTimeConsumption__c);
    Assert.areEqual(-1, jd.HeapSizeConsumption__c);
    Assert.areEqual(-1, jd.CalloutConsumption__c);
    Assert.areEqual(-1, jd.CalloutTimeConsumption__c);
    Assert.areEqual(-1, jd.DmlRowsConsumption__c);
    Assert.areEqual(-1, jd.DmlStatementsConsumption__c);
    Assert.areEqual(-1, jd.FutureCallsConsumption__c);
    Assert.areEqual(-1, jd.PublishImmediateDmlConsumption__c);
    Assert.areEqual(-1, jd.QueryRowsConsumption__c);
    Assert.areEqual(-1, jd.QueriesConsumption__c);
    Assert.areEqual(-1, jd.SoslQueriesConsumption__c);
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
      .highPriority()
      .recurrent()
      .allowedOn(allowedDays)
      .allowedBetween(startTime, endTime)
      .maxAttempts(maxAttempts)
      .minInterval(minInterval);
    final JobDescription__c created = sut.save();

    // Assert
    final JobDescription__c jd = [
      SELECT ProcessorName__c, Enabled__c, isHighPriority__c, isRecurrent__c, AllowedDays__c, AllowedStartTime__c, AllowedEndTime__c, MaxExecutionAttempt__c, MinJobInterval__c
      FROM JobDescription__c
      WHERE Id = :created.Id
    ];
    Assert.areEqual(processorName, jd.ProcessorName__c);
    Assert.isTrue(jd.Enabled__c, 'JobDescription must be enabled by default');
    Assert.isTrue(jd.isHighPriority__c, 'High priority must be set');
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
