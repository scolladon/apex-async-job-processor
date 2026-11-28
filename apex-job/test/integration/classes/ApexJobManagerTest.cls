@IsTest
private class ApexJobManagerTest {
  @IsTest
  static void givenJobRequestId_whenDisableJobRequest_thenEnabledFalse() {
    // Arrange
    final JobDescription__c jdSeed = new JobDescription__c(Enabled__c = true, ProcessorName__c = 'Proc_Seed');
    insert as system jdSeed;
    final JobRequest__c jr = new JobRequest__c(Enabled__c = true, Status__c = 'READY', JobDescription__c = jdSeed.Id);
    insert as system jr;

    // Act
    ApexJobManager.disableJobRequest(jr.Id);

    // Assert
    final JobRequest__c reloaded = [SELECT Id, Enabled__c FROM JobRequest__c WHERE Id = :jr.Id WITH SYSTEM_MODE];
    Assert.isFalse(reloaded.Enabled__c, 'JobRequest must be disabled');
  }

  @IsTest
  static void givenJobDescriptionId_whenDisableJobDescription_thenEnabledFalse() {
    // Arrange
    final JobDescription__c jd = new JobDescription__c(Enabled__c = true, ProcessorName__c = 'Proc_A');
    insert as system jd;

    // Act
    ApexJobManager.disableJobDescription(jd.Id);

    // Assert
    final JobDescription__c reloaded = [SELECT Id, Enabled__c FROM JobDescription__c WHERE Id = :jd.Id WITH SYSTEM_MODE];
    Assert.isFalse(reloaded.Enabled__c, 'JobDescription must be disabled');
  }

  @IsTest
  static void givenProcessorName_whenDisableJobDescription_thenUpsertsAndDisables() {
    // Arrange
    final String processorName = 'Proc_B';
    final JobDescription__c pre = new JobDescription__c(ProcessorName__c = processorName, Enabled__c = true);
    insert as system pre;

    // Act
    ApexJobManager.disableJobDescription(processorName);

    // Assert
    final JobDescription__c reloaded = [
      SELECT Id, ProcessorName__c, Enabled__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(processorName, reloaded.ProcessorName__c, 'Processor name must match');
    Assert.isFalse(reloaded.Enabled__c, 'JobDescription must be disabled via upsert');
  }

  @IsTest
  static void givenBackedOffDescription_whenResetConsumptionModel_thenKillBackoffCleared() {
    // Arrange
    final String processorName = 'Proc_Backoff';
    insert as system new JobDescription__c(ProcessorName__c = processorName, Enabled__c = true, KillBackoffUntil__c = System.now().addMinutes(5));

    // Act
    ApexJobManager.resetConsumptionModel(processorName);

    // Assert
    final JobDescription__c jd = [SELECT KillBackoffUntil__c FROM JobDescription__c WHERE ProcessorName__c = :processorName WITH SYSTEM_MODE LIMIT 1];
    Assert.isNull(jd.KillBackoffUntil__c, 'Reset must clear the kill backoff');
  }

  @IsTest
  static void givenRateLimitedDescription_whenResetConsumptionModel_thenRateLogAndHintCleared() {
    // Arrange
    final String processorName = 'Proc_RateLimited';
    insert as system new JobDescription__c(
      ProcessorName__c = processorName,
      Enabled__c = true,
      MaxExecutionsPerMinute__c = 10,
      RateLog__c = (System.now().getTime() - 5000) + ':10;',
      RateBlockedUntil__c = System.now().addSeconds(30)
    );

    // Act
    ApexJobManager.resetConsumptionModel(processorName);

    // Assert
    final JobDescription__c jd = [SELECT RateLog__c, RateBlockedUntil__c FROM JobDescription__c WHERE ProcessorName__c = :processorName WITH SYSTEM_MODE LIMIT 1];
    Assert.isNull(jd.RateLog__c, 'Reset must clear the rate log');
    Assert.isNull(jd.RateBlockedUntil__c, 'Reset must clear the rate blocked hint');
  }

  @IsTest
  static void givenProcessorName_whenResetConsumptionModel_thenAllConsumptionsAAreReset() {
    // Arrange
    final String processorName = 'Proc_E';
    insert as system seedConsumedDescription(processorName);

    // Act
    ApexJobManager.resetConsumptionModel(processorName);

    // Assert
    final JobDescription__c jd = queryWithConsumptions(processorName);
    Assert.areEqual(-1, jd.MaxChunkSize__c, 'MaxChunkSize must be reset');
    Assert.areEqual(0, jd.ConsecutiveVariationCount__c, 'ConsecutiveVariationCount must be reset (EWMA state)');
    Assert.areEqual(0.42, jd.LearningRate__c, 'LearningRate is configuration and must be preserved by reset');
    Assert.areEqual(7, jd.VariationResetCount__c, 'VariationResetCount is configuration and must be preserved by reset');
    Assert.areEqual(0.55, jd.VariationResetThreshold__c, 'VariationResetThreshold is configuration and must be preserved by reset');
    Assert.areEqual(5, jd.KillCooldownCount__c, 'KillCooldownCount is configuration and must be preserved by reset');
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      assertModelReset(jd, model);
    }
  }

  private static JobDescription__c seedConsumedDescription(final String processorName) {
    final JobDescription__c description = new JobDescription__c(
      ProcessorName__c = processorName,
      Enabled__c = true,
      MaxChunkSize__c = 10,
      ConsecutiveFailures__c = 2,
      SuccessStreak__c = 8,
      SmallestFailingChunk__c = 7,
      ConsecutiveVariationCount__c = 2,
      LearningRate__c = 0.42,
      VariationResetCount__c = 7,
      VariationResetThreshold__c = 0.55,
      KillCooldownCount__c = 5
    );
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      description.put(model.base, 1);
      description.put(model.perItem, 1);
      description.put(model.safety, 1);
    }
    return description;
  }

  private static JobDescription__c queryWithConsumptions(final String processorName) {
    final List<String> fields = new List<String>{
      'ProcessorName__c',
      'MaxChunkSize__c',
      'ConsecutiveVariationCount__c',
      'LearningRate__c',
      'VariationResetCount__c',
      'VariationResetThreshold__c',
      'KillCooldownCount__c'
    };
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      fields.add(model.base);
      fields.add(model.perItem);
      fields.add(model.safety);
    }
    final String soql = 'SELECT ' + String.join(fields, ', ') + ' FROM JobDescription__c WHERE ProcessorName__c = :processorName LIMIT 1';
    return (JobDescription__c) Database.queryWithBinds(soql, new Map<String, Object>{ 'processorName' => processorName }, AccessLevel.SYSTEM_MODE)[0];
  }

  private static void assertModelReset(final JobDescription__c jd, final ConsumptionModel model) {
    Assert.areEqual(ApexJobConstant.UNKNOWN_BASE_CONSUMPTION, jd.get(model.base), model.base);
    Assert.areEqual(ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION, jd.get(model.perItem), model.perItem);
    Assert.areEqual(ApexJobConstant.UNKNOWN_SAFETY, jd.get(model.safety), model.safety);
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
      WITH SYSTEM_MODE
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
    insert as system jd;
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
      WITH SYSTEM_MODE
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
    insert as system jd;
    final JobRequest__c jr = new JobRequest__c(Enabled__c = false, Status__c = 'READY', JobDescription__c = jd.Id);
    insert as system jr;

    // Act
    ApexJobManager.enableJobRequest(jr.Id);

    // Assert
    final JobRequest__c reloaded = [SELECT Id, Enabled__c FROM JobRequest__c WHERE Id = :jr.Id WITH SYSTEM_MODE];
    Assert.isTrue(reloaded.Enabled__c, 'JobRequest must be enabled');
  }

  @IsTest
  static void givenDisabledJobDescriptionId_whenEnableJobDescription_thenEnabledTrue() {
    // Arrange
    final JobDescription__c jd = new JobDescription__c(Enabled__c = false, ProcessorName__c = 'Proc_Enable_JD');
    insert as system jd;

    // Act
    ApexJobManager.enableJobDescription(jd.Id);

    // Assert
    final JobDescription__c reloaded = [SELECT Id, Enabled__c FROM JobDescription__c WHERE Id = :jd.Id WITH SYSTEM_MODE];
    Assert.isTrue(reloaded.Enabled__c, 'JobDescription must be enabled');
  }

  @IsTest
  static void givenProcessorName_whenEnableJobDescription_thenUpsertsAndEnables() {
    // Arrange
    final String processorName = 'Proc_Enable_Upsert';
    insert as system new JobDescription__c(ProcessorName__c = processorName, Enabled__c = false);

    // Act
    ApexJobManager.enableJobDescription(processorName);

    // Assert
    final JobDescription__c reloaded = [
      SELECT Id, ProcessorName__c, Enabled__c
      FROM JobDescription__c
      WHERE ProcessorName__c = :processorName
      WITH SYSTEM_MODE
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
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('READY', reloaded.Status__c, 'Default status must be READY');
    Assert.isTrue(reloaded.Enabled__c, 'JobRequest must be enabled by default');
    Assert.areEqual(jd.Id, reloaded.JobDescription__c, 'JobDescription lookup must be set');
    Assert.areEqual(scheduled, reloaded.NextExecutionDateTime__c, 'Scheduled datetime must match');
    Assert.isTrue(String.valueOf(reloaded.Argument__c).contains('"k":"v"'), 'Argument must be serialized');
  }
}
