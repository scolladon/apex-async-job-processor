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
  static void givenNewTransaction_whenHasExecutedJobs_thenReturnsFalse() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    final Boolean result = sut.hasExecutedJobs;

    // Assert
    Assert.isFalse(result, 'Should return false for new transaction');
  }

  @IsTest
  static void givenTransactionContext_whenMarkExecutedJobs_thenFlagIsSet() {
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
  static void givenMultipleCalls_whenMarkExecutedJobs_thenRemainsTrue() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    sut.markExecutedJobs();
    sut.markExecutedJobs(); // Call twice

    // Assert
    Assert.isTrue(sut.hasExecutedJobs, 'Should remain true after multiple calls');
  }

  @IsTest
  static void givenNewTransaction_whenHasAttemptedWakeUp_thenReturnsFalse() {
    // Arrange
    ApexJobTransactionContext.reset();

    // Act
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Assert
    Assert.isFalse(sut.hasAttemptedWakeUp, 'Should be false for a new transaction');
  }

  @IsTest
  static void givenTransactionContext_whenMarkWakeUpAttempted_thenFlagIsSet() {
    // Arrange
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Act
    sut.markWakeUpAttempted();

    // Assert
    Assert.isTrue(sut.hasAttemptedWakeUp, 'Should be true after marking the wake-up as attempted');
  }

  @IsTest
  static void givenWakeUpAttempted_whenReset_thenNewInstanceHasFlagCleared() {
    // Arrange
    ApexJobTransactionContext.reset();
    ApexJobTransactionContext.getInstance().markWakeUpAttempted();

    // Act
    ApexJobTransactionContext.reset();
    final ApexJobTransactionContext sut = ApexJobTransactionContext.getInstance();

    // Assert
    Assert.isFalse(sut.hasAttemptedWakeUp, 'New instance should have the wake-up flag cleared');
  }
}
