@IsTest
private class KillRuleTest {
  @IsTest
  private static void givenMultiItemChunk_whenIsFloorKill_thenFalse() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxChunkSize(-1).withSmallestFailingChunk(1).build());

    // Act
    final Boolean result = sut.isFloorKill(2);

    // Assert
    Assert.isFalse(result, 'A multi-item kill is never a floor kill');
  }

  @IsTest
  private static void givenUnknownModel_whenIsFloorKill_thenTrue() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxChunkSize(0).withSmallestFailingChunk(0).build());

    // Act
    final Boolean result = sut.isFloorKill(1);

    // Assert
    Assert.isTrue(result, 'A one-item kill of an unknown model is a floor kill');
  }

  @IsTest
  private static void givenSmallestFailingChunkAtCap_whenIsFloorKill_thenTrue() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxChunkSize(1).withSmallestFailingChunk(2).build());

    // Act
    final Boolean result = sut.isFloorKill(1);

    // Assert
    Assert.isTrue(result, 'A one-item kill of a description capped at one item is a floor kill');
  }

  @IsTest
  private static void givenSmallestFailingChunkAboveCap_whenIsFloorKill_thenFalse() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxChunkSize(1).withSmallestFailingChunk(3).build());

    // Act
    final Boolean result = sut.isFloorKill(1);

    // Assert
    Assert.isFalse(result, 'A description not yet capped at one item is not floor killed');
  }

  @IsTest
  private static void givenNoFailingChunk_whenIsFloorKill_thenFalse() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxChunkSize(1).withSmallestFailingChunk(0).build());

    // Act
    final Boolean result = sut.isFloorKill(1);

    // Assert
    Assert.isFalse(result, 'A first one-item kill of a learned model is not a floor kill');
  }

  @IsTest
  private static void givenUnlimitedAttempts_whenExhaustsAttempts_thenFalse() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxExecutionAttempt(-1).withConsecutiveFailures(10).build());

    // Act
    final Boolean result = sut.exhaustsAttempts();

    // Assert
    Assert.isFalse(result, 'Unlimited attempts are never exhausted');
  }

  @IsTest
  private static void givenFailuresBelowMax_whenExhaustsAttempts_thenFalse() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxExecutionAttempt(3).withConsecutiveFailures(2).build());

    // Act
    final Boolean result = sut.exhaustsAttempts();

    // Assert
    Assert.isFalse(result, 'Failures below the max do not exhaust attempts');
  }

  @IsTest
  private static void givenFailuresAtMax_whenExhaustsAttempts_thenTrue() {
    // Arrange
    final KillRule sut = new KillRule(ApexJobTestFixture.aJobDescription().withMaxExecutionAttempt(3).withConsecutiveFailures(3).build());

    // Act
    final Boolean result = sut.exhaustsAttempts();

    // Assert
    Assert.isTrue(result, 'Failures reaching the max exhaust attempts');
  }
}
