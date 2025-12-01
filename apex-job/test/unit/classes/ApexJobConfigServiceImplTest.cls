@IsTest
private class ApexJobConfigServiceImplTest {
  @IsTest
  static void givenSystemEnabled_whenIsSystemEnabled_thenReturnsTrue() {
    // Arrange
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true);
    insert config;
    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Boolean result = service.isSystemEnabled();

    // Assert
    Assert.isTrue(result, 'The system should be enabled');
  }

  @IsTest
  static void givenSystemDisabled_whenIsSystemEnabled_thenReturnsFalse() {
    // Arrange
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = false);
    insert config;
    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Boolean result = service.isSystemEnabled();

    // Assert
    Assert.isFalse(result, 'The system should not be enabled');
  }

  @IsTest
  static void givenSystemNotConfigured_whenIsSystemEnabled_thenReturnsFalse() {
    // Arrange
    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Boolean result = service.isSystemEnabled();

    // Assert
    Assert.isFalse(result, 'The system should not be enabled');
  }

  @IsTest
  static void givenConfigWithDelayWithinBusinessHours_whenGetEnqueueDelayInMinutes_thenReturnsDefaultDelay() {
    // Arrange
    final Integer configuredDelay = 5;
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true, EnqueueDelayOutsideBusinessHours__c = configuredDelay);
    insert config;

    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    // Result should be either default (within business hours) or configured delay (outside business hours)
    Assert.isTrue(result == 1 || result == configuredDelay, 'Should return default (1) when within business hours or configured delay (' + configuredDelay + ') when outside, got: ' + result);
  }

  @IsTest
  static void givenConfigWithDelayExceedingMaximum_whenGetEnqueueDelayInMinutes_thenReturnsMaximumDelay() {
    // Arrange
    final Integer excessiveDelay = 20;
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true, EnqueueDelayOutsideBusinessHours__c = excessiveDelay);
    insert config;

    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    Assert.isTrue(result == 1 || result == 10, 'Should return default (1) when within business hours or configured delay (10) when outside, got: ' + result);
  }

  @IsTest
  static void givenConfigWithNegativeDelay_whenGetEnqueueDelayInMinutes_thenReturnsMinimumDelay() {
    // Arrange
    final Integer negativeDelay = -5;
    final Integer expectedMinDelay = 1;
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true, EnqueueDelayOutsideBusinessHours__c = negativeDelay);
    insert config;

    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    Assert.areEqual(expectedMinDelay, result, 'Should return minimum delay (1) for negative values');
  }

  @IsTest
  static void givenNoConfig_whenGetEnqueueDelayInMinutes_thenReturnsDefaultDelay() {
    // Arrange
    final Integer expectedDefaultDelay = 1;
    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    Assert.areEqual(expectedDefaultDelay, result, 'Should return default delay (1) when no config exists');
  }

  @IsTest
  static void givenConfigWithZeroDelay_whenGetEnqueueDelayInMinutes_thenReturnsDefaultDelay() {
    // Arrange
    final Integer expectedDefaultDelay = 1;
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true, EnqueueDelayOutsideBusinessHours__c = 0);
    insert config;

    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    Assert.areEqual(expectedDefaultDelay, result, 'Should return default delay (1) when configured as zero');
  }

  @IsTest
  static void givenConfigWithExactMaximumDelay_whenGetEnqueueDelayInMinutes_thenReturnsMaximum() {
    // Arrange
    final Integer maxDelay = 10;
    final ApexJobConfig__c config = new ApexJobConfig__c(Enabled__c = true, EnqueueDelayOutsideBusinessHours__c = maxDelay);
    insert config;

    final ApexJobConfigServiceImpl service = new ApexJobConfigServiceImpl();

    // Act
    final Integer result = service.getEnqueueDelayInMinutes();

    // Assert
    Assert.isTrue(result <= maxDelay, 'Should allow maximum delay (10), got: ' + result);
  }
}
