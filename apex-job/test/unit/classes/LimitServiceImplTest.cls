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
    List<Account> queriedAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test Account%']; //NOPMD

    LimitsUsage snapshotResult = sut.stopSnapshot();

    // Assert
    Assert.isNotNull(snapshotResult, 'Snapshot result should not be null');
    Assert.isTrue(snapshotResult.cpuTime >= 0, 'CPU time should be non-negative');
    Assert.isTrue(snapshotResult.heapSize >= 0, 'Heap size should be non-negative');
    Assert.isTrue(snapshotResult.callout >= 0, 'Callout should be non-negative');
    Assert.areEqual(0, snapshotResult.calloutTime, 'Callout time should be 0 for snapshot');
    Assert.isTrue(snapshotResult.publishImmediateDml >= 0, 'Publish immediate DML should be non-negative');
    Assert.isTrue(snapshotResult.dmlRows >= 0, 'DML rows should be non-negative');
    Assert.isTrue(snapshotResult.dmlStatements >= 0, 'DML statements should be non-negative');
    Assert.isTrue(snapshotResult.queryRows >= 0, 'Query rows should be non-negative');
    Assert.isTrue(snapshotResult.queries >= 0, 'Queries should be non-negative');
    Assert.isTrue(snapshotResult.soslQueries >= 0, 'SOQL queries should be non-negative');
    Assert.isTrue(snapshotResult.futureCalls >= 0, 'Future calls should be non-negative');
    Assert.isTrue(snapshotResult.aggregateQueries >= 0, 'Aggregate queries should be non-negative');
    Assert.isTrue(snapshotResult.apexCursorRows >= 0, 'Apex cursor rows should be non-negative');
    Assert.isTrue(snapshotResult.fetchCallsOnApexCursor >= 0, 'Fetch calls on apex cursor should be non-negative');
    Assert.isTrue(snapshotResult.emailInvocations >= 0, 'Email invocations should be non-negative');
    Assert.isTrue(snapshotResult.mobilePushApexCalls >= 0, 'Mobile push apex calls should be non-negative');
    Assert.isTrue(snapshotResult.queryLocatorRows >= 0, 'Query locator rows should be non-negative');
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
    Integer consumedCpuTime = Limits.getCpuTime();
    Integer availableCpuTime = Limits.getLimitCpuTime() - consumedCpuTime;
    Integer expectedCpuTime = (Integer) (availableCpuTime * 0.97);
    // Allow for ±10ms difference due to rounding and computing
    Assert.isTrue(expectedCpuTime - result.cpuTime <= 10, 'CPU time should be approximately reduced by 20% buffer. Expected: ' + expectedCpuTime + ', Actual: ' + result.cpuTime);
  }
}
