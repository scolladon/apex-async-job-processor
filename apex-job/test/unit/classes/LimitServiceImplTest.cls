@IsTest
private class LimitServiceImplTest {
  @IsTest
  static void givenService_whenStartSnapshot_thenSnapshotIsInitialized() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    sut.startSnapshot();

    // Assert
    LimitsUsage snapshotResult = sut.stopSnapshot();
    Assert.isNotNull(snapshotResult, 'Snapshot result should not be null after startSnapshot is called');
  }

  @IsTest
  static void givenSnapshotStarted_whenStopSnapshot_thenReturnsUsageDifference() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    sut.startSnapshot();

    // Simulate some governor limit consumption by performing operations
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < 5; i++) {
      accounts.add(new Account(Name = 'Test Account ' + i));
    }
    insert accounts;

    // Query to consume SOQL limits
    List<Account> queriedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%'];

    LimitsUsage snapshotResult = sut.stopSnapshot();

    // Assert
    Assert.isNotNull(snapshotResult, 'Snapshot result should not be null');
    Assert.isTrue(snapshotResult.dmlStatements >= 0, 'DML statements should be non-negative');
    Assert.isTrue(snapshotResult.dmlRows >= 0, 'DML rows should be non-negative');
    Assert.areEqual(1, snapshotResult.queries, 'One query should have been executed');
    Assert.areEqual(queriedAccounts.size(), snapshotResult.queryRows, 'Query rows should have been executed');
    Assert.isTrue(snapshotResult.cpuTime >= 0, 'CPU time should be non-negative');
    Assert.isTrue(snapshotResult.heapSize >= 0, 'Heap size should be non-negative');
  }

  @IsTest
  static void givenJobDescriptionNotComputed_whenUpdateUsage_thenFieldsAreUpdated() {
    // Arrange
    JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
      .withName('TestProcessor')
      .withProcessorName('TestProcessor')
      .enabled()
      .withMaxChunkSize(-1)
      .withCpuTimeConsumption(-1)
      .withHeapSizeConsumption(-1)
      .withCalloutConsumption(-1)
      .withCalloutTimeConsumption(-1)
      .withPublishImmediateDmlConsumption(-1)
      .withDmlRowsConsumption(-1)
      .withDmlStatementsConsumption(-1)
      .withQueryRowsConsumption(-1)
      .withQueriesConsumption(-1)
      .withSoslQueriesConsumption(-1)
      .withFutureCallsConsumption(-1)
      .build();

    LimitsUsage newUsage = ApexJobTestFixture.aLimitsUsage()
      .withCpuTime(4000)
      .withHeapSize(512000)
      .withCallout(2)
      .withCalloutTime(10000)
      .withPublishImmediateDml(1)
      .withDmlRows(100)
      .withDmlStatements(5)
      .withQueryRows(200)
      .withQueries(10)
      .withSoslQueries(2)
      .withFutureCalls(1)
      .build();
    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    sut.updateUsage(jobDesc, newUsage, 1);

    // Assert
    Assert.areEqual(1, jobDesc.MaxChunkSize__c, 'Max chunk size should be updated');
    Assert.areEqual(4000, jobDesc.CpuTimeConsumption__c, 'CPU time should be updated');
    Assert.areEqual(512000, jobDesc.HeapSizeConsumption__c, 'Heap size should be updated');
    Assert.areEqual(2, jobDesc.CalloutConsumption__c, 'Callout should be updated');
    Assert.areEqual(10000, jobDesc.CalloutTimeConsumption__c, 'Callout time should be updated');
    Assert.areEqual(1, jobDesc.PublishImmediateDmlConsumption__c, 'Publish immediate DML should be updated');
    Assert.areEqual(100, jobDesc.DmlRowsConsumption__c, 'DML rows should be updated');
    Assert.areEqual(5, jobDesc.DmlStatementsConsumption__c, 'DML statements should be updated');
    Assert.areEqual(200, jobDesc.QueryRowsConsumption__c, 'Query rows should be updated');
    Assert.areEqual(10, jobDesc.QueriesConsumption__c, 'Queries should be updated');
    Assert.areEqual(2, jobDesc.SoslQueriesConsumption__c, 'SOSL queries should be updated');
    Assert.areEqual(1, jobDesc.FutureCallsConsumption__c, 'Future calls should be updated');
  }

  @IsTest
  static void givenJobDescriptionAlreadyComputed_whenUpdateUsage_thenFieldsAreNotUpdated() {
    // Arrange
    JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
      .withName('TestProcessor')
      .withProcessorName('TestProcessor')
      .enabled()
      .withMaxChunkSize(1)
      .withCpuTimeConsumption(4000)
      .withHeapSizeConsumption(512000)
      .withCalloutConsumption(2)
      .withCalloutTimeConsumption(10000)
      .withPublishImmediateDmlConsumption(1)
      .withDmlRowsConsumption(100)
      .withDmlStatementsConsumption(5)
      .withQueryRowsConsumption(200)
      .withQueriesConsumption(10)
      .withSoslQueriesConsumption(2)
      .withFutureCallsConsumption(1)
      .build();

    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    sut.updateUsage(jobDesc, ApexJobTestFixture.aLimitsUsage().build(), 2);

    // Assert
    Assert.areEqual(2, jobDesc.MaxChunkSize__c, 'Max chunk size should be updated');
    Assert.areEqual(4000, jobDesc.CpuTimeConsumption__c, 'CPU time should be updated');
    Assert.areEqual(512000, jobDesc.HeapSizeConsumption__c, 'Heap size should be updated');
    Assert.areEqual(2, jobDesc.CalloutConsumption__c, 'Callout should be updated');
    Assert.areEqual(10000, jobDesc.CalloutTimeConsumption__c, 'Callout time should be updated');
    Assert.areEqual(1, jobDesc.PublishImmediateDmlConsumption__c, 'Publish immediate DML should be updated');
    Assert.areEqual(100, jobDesc.DmlRowsConsumption__c, 'DML rows should be updated');
    Assert.areEqual(5, jobDesc.DmlStatementsConsumption__c, 'DML statements should be updated');
    Assert.areEqual(200, jobDesc.QueryRowsConsumption__c, 'Query rows should be updated');
    Assert.areEqual(10, jobDesc.QueriesConsumption__c, 'Queries should be updated');
    Assert.areEqual(2, jobDesc.SoslQueriesConsumption__c, 'SOSL queries should be updated');
    Assert.areEqual(1, jobDesc.FutureCallsConsumption__c, 'Future calls should be updated');
  }

  @IsTest
  static void givenJobDescription_whenResetUsage_thenFieldsAreReseted() {
    // Arrange
    JobDescription__c jobDesc = ApexJobTestFixture.aJobDescription()
      .withName('TestProcessor')
      .withProcessorName('TestProcessor')
      .enabled()
      .withCpuTimeConsumption(4000)
      .withHeapSizeConsumption(512000)
      .withCalloutConsumption(2)
      .withCalloutTimeConsumption(10000)
      .withPublishImmediateDmlConsumption(1)
      .withDmlRowsConsumption(100)
      .withDmlStatementsConsumption(5)
      .withQueryRowsConsumption(200)
      .withQueriesConsumption(10)
      .withSoslQueriesConsumption(2)
      .withFutureCallsConsumption(1)
      .build();

    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    sut.resetUsage(jobDesc);

    // Assert
    Assert.areEqual(-1, jobDesc.CpuTimeConsumption__c, 'CPU time should be updated');
    Assert.areEqual(-1, jobDesc.HeapSizeConsumption__c, 'Heap size should be updated');
    Assert.areEqual(-1, jobDesc.CalloutConsumption__c, 'Callout should be updated');
    Assert.areEqual(-1, jobDesc.CalloutTimeConsumption__c, 'Callout time should be updated');
    Assert.areEqual(-1, jobDesc.PublishImmediateDmlConsumption__c, 'Publish immediate DML should be updated');
    Assert.areEqual(-1, jobDesc.DmlRowsConsumption__c, 'DML rows should be updated');
    Assert.areEqual(-1, jobDesc.DmlStatementsConsumption__c, 'DML statements should be updated');
    Assert.areEqual(-1, jobDesc.QueryRowsConsumption__c, 'Query rows should be updated');
    Assert.areEqual(-1, jobDesc.QueriesConsumption__c, 'Queries should be updated');
    Assert.areEqual(-1, jobDesc.SoslQueriesConsumption__c, 'SOSL queries should be updated');
    Assert.areEqual(-1, jobDesc.FutureCallsConsumption__c, 'Future calls should be updated');
  }

  // Not possible to simulate callout time during Tests...
  /*@IsTest
  static void givenMultipleSnapshots_whenStopSnapshot_thenCalloutTimeAccumulates() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();

    // Act & Assert - First snapshot
    Test.startTest();
    sut.startSnapshot();

    // Simulate some time passing and operations
    List<Account> accounts1 = new List<Account>();
    accounts1.add(new Account(Name = 'Test Account 1'));
    insert accounts1;

    LimitsUsage firstSnapshot = sut.stopSnapshot();

    // Second snapshot
    sut.startSnapshot();

    List<Account> accounts2 = new List<Account>();
    accounts2.add(new Account(Name = 'Test Account 2'));
    insert accounts2;

    LimitsUsage secondSnapshot = sut.stopSnapshot();
    Test.stopTest();

    // Assert
    Assert.isTrue(firstSnapshot.calloutTime >= 0, 'First snapshot callout time should be non-negative');
    Assert.isTrue(secondSnapshot.calloutTime >= 0, 'Second snapshot callout time should be non-negative');
  }*/

  @IsTest
  static void givenMultipleServiceInstances_whenCreated_thenInstancesAreIndependent() {
    // Arrange
    LimitServiceImpl sut1 = new LimitServiceImpl();
    LimitServiceImpl sut2 = new LimitServiceImpl();

    // Act
    Test.startTest();
    sut1.startSnapshot();

    // Only perform operations that affect service1
    List<Account> accounts = new List<Account>();
    accounts.add(new Account(Name = 'Test Account Service1'));
    insert accounts;

    LimitsUsage snapshot1 = sut1.stopSnapshot();

    // service2 should have independent state
    sut2.startSnapshot();
    LimitsUsage snapshot2 = sut2.stopSnapshot();
    Test.stopTest();

    // Assert
    Assert.areNotEqual(snapshot1, snapshot2, 'Service1 snapshot should not be equal to Service2 snapshot');
  }

  @IsTest
  static void givenLimitServiceImpl_whenGetAvailableLimits_thenReturnsLimitsWithBuffer() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();

    // Act
    LimitsUsage result = sut.getAvailableLimits();

    // Assert - Verify buffer is applied (approximately 20% reduction, allowing for rounding)
    Integer availableCpuTime = Limits.getLimitCpuTime() - Limits.getCpuTime();
    Integer expectedCpuTime = (Integer) (availableCpuTime * 0.97);
    // Allow for ±1 difference due to rounding
    Assert.isTrue(Math.abs(result.cpuTime - expectedCpuTime) <= 1, 'CPU time should be approximately reduced by 20% buffer. Expected: ' + expectedCpuTime + ', Actual: ' + result.cpuTime);
  }

  @IsTest
  static void givenLimitServiceImpl_whenGetConsumedLimits_thenReturnsCurrentConsumption() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();

    // Capture current limits before the test
    Integer currentCpuTime = Limits.getCpuTime();
    Integer currentHeapSize = Limits.getHeapSize();

    // Act
    LimitsUsage result = sut.getConsumedLimits();

    // Assert - Test that values are reasonable and match current consumption
    Assert.isTrue(result.cpuTime >= currentCpuTime, 'CPU time should be at least the captured value');
    Assert.isTrue(result.heapSize >= currentHeapSize, 'Heap size should be at least the captured value');
    Assert.areEqual(0, result.calloutTime, 'Callout time should be 0 for consumed limits');
  }

  @IsTest
  static void givenComputeMaxChunkSizeForTransaction_whenCalledWithNotComputedJobDescription_thenReturns1() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();
    JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').enabled().withMaxChunkSize(-1).build();

    // Act
    Integer result = sut.computeMaxChunkSizeForTransaction(jobDescription);

    // Assert
    Assert.areEqual(1, result, 'Max chunk size should be 1');
  }

  @IsTest
  static void givenComputeMaxChunkSizeForTransaction_whenCalledWithFullAlreadyComputedChunkSize_thenComputeChunkSize() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();
    JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestProcessor')
      .withProcessorName('TestProcessor')
      .enabled()
      .withMaxChunkSize(1)
      .withCpuTimeConsumption(4000)
      .withHeapSizeConsumption(512000)
      .withCalloutConsumption(2)
      .withCalloutTimeConsumption(10000)
      .withPublishImmediateDmlConsumption(0)
      .withDmlRowsConsumption(0)
      .withDmlStatementsConsumption(5)
      .withQueryRowsConsumption(200)
      .withQueriesConsumption(10)
      .withSoslQueriesConsumption(2)
      .withFutureCallsConsumption(1)
      .build();

    // Act
    Integer result = sut.computeMaxChunkSizeForTransaction(jobDescription);

    // Assert
    Assert.isTrue(result > 1, 'Max chunk size should be greater than 1');
  }

  @IsTest
  static void givenComputeMaxChunkSizeForTransaction_whenCalledWithoutEnoughLimit_thenReturnBelow1() {
    // Arrange
    LimitServiceImpl sut = new LimitServiceImpl();
    JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription()
      .withName('TestProcessor')
      .withProcessorName('TestProcessor')
      .enabled()
      .withMaxChunkSize(1)
      .withCpuTimeConsumption(4000)
      .withHeapSizeConsumption(512000)
      .withCalloutConsumption(2)
      .withCalloutTimeConsumption(10000)
      .withPublishImmediateDmlConsumption(1)
      .withDmlRowsConsumption(100)
      .withDmlStatementsConsumption(5)
      .withQueryRowsConsumption(200)
      .withQueriesConsumption(Limits.getLimitQueries() + 1)
      .withSoslQueriesConsumption(2)
      .withFutureCallsConsumption(1)
      .build();

    // Act
    Integer result = sut.computeMaxChunkSizeForTransaction(jobDescription);

    // Assert
    Assert.areEqual(0, result, 'Max chunk size should be 0');
  }
}
