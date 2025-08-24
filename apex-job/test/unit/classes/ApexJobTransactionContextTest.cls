@IsTest
private class ApexJobTransactionContextTest {
  @IsTest
  static void givenTransactionContext_whenGetInstance_thenReturnsSingleton() {
    // Arrange
    ApexJobTransactionContext.reset();

    // Act
    final ApexJobTransactionContext instance1 = ApexJobTransactionContext.getInstance();
    final ApexJobTransactionContext instance2 = ApexJobTransactionContext.getInstance();

    // Assert
    Assert.areEqual(instance1, instance2, 'Should return the same singleton instance');
  }

  @IsTest
  static void givenNewTransaction_whenhasExecutedJobs_thenReturnsFalse() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    final Boolean result = sut.hasExecutedJobs;

    // Assert
    Assert.isFalse(result, 'Should return false for new transaction');
  }

  @IsTest
  static void givenTransactionContext_whenmarkExecutedJobs_thenFlagIsSet() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    sut.markExecutedJobs();

    // Assert
    Assert.isTrue(sut.hasExecutedJobs, 'Should return true after marking as executed');
  }

  @IsTest
  static void givenFlagSet_whenReset_thenNewInstanceHasFlagCleared() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext instance1 = ApexJobTransactionContext.getInstance();
    instance1.markExecutedJobs();
    Assert.isTrue(instance1.hasExecutedJobs, 'Flag should be set');

    // Act
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext instance2 = ApexJobTransactionContext.getInstance();

    // Assert
    Assert.isFalse(instance2.hasExecutedJobs, 'New instance should have flag cleared');
  }

  @IsTest
  static void givenMultipleCalls_whenmarkExecutedJobs_thenRemainsTrue() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    sut.markExecutedJobs();
    sut.markExecutedJobs(); // Call twice

    // Assert
    Assert.isTrue(sut.hasExecutedJobs, 'Should remain true after multiple calls');
  }
}
