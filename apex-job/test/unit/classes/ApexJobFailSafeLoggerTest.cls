@IsTest
private class ApexJobFailSafeLoggerTest {
  private static final String FAILURE_PREFIX = 'AsyncJob: subscriber logger failed: ';

  private static Mock subscriberMock = Mock.forType(ApexJobLogger.class);
  private static Mock fallbackMock = Mock.forType(ApexJobLogger.class);
  private static MethodSpy subscriberDebugSpy = subscriberMock.spyOn('debug');
  private static MethodSpy subscriberErrorSpy = subscriberMock.spyOn('error');
  private static MethodSpy fallbackDebugSpy = fallbackMock.spyOn('debug');
  private static MethodSpy fallbackErrorSpy = fallbackMock.spyOn('error');

  private class TestException extends Exception {
  }

  private static ApexJobFailSafeLogger buildSut() {
    return new ApexJobFailSafeLogger((ApexJobLogger) subscriberMock.stub, (ApexJobLogger) fallbackMock.stub);
  }

  @IsTest
  static void givenWorkingSubscriberLogger_whenDebug_thenDelegatesToSubscriberOnly() {
    // Arrange
    final ApexJobFailSafeLogger sut = buildSut();

    // Act
    sut.debug('message');

    // Assert
    Expect.that(subscriberDebugSpy).hasBeenCalledWith('message');
    Expect.that(fallbackDebugSpy).hasNotBeenCalled();
    Expect.that(fallbackErrorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenWorkingSubscriberLogger_whenError_thenDelegatesToSubscriberOnly() {
    // Arrange
    final ApexJobFailSafeLogger sut = buildSut();

    // Act
    sut.error('message');

    // Assert
    Expect.that(subscriberErrorSpy).hasBeenCalledWith('message');
    Expect.that(fallbackDebugSpy).hasNotBeenCalled();
    Expect.that(fallbackErrorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenThrowingSubscriberLogger_whenError_thenRoutesMessageAndFailureToFallback() {
    // Arrange
    subscriberErrorSpy.throwsException(new TestException('boom'));
    final ApexJobFailSafeLogger sut = buildSut();

    // Act
    sut.error('message');

    // Assert
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(2);
    Assert.areEqual('message', (String) fallbackErrorSpy.getArguments(0)[0]);
    final String failure = (String) fallbackErrorSpy.getArguments(1)[0];
    Assert.isTrue(failure.startsWith(FAILURE_PREFIX), failure);
    Assert.isTrue(failure.endsWith(': boom'), failure);
  }

  @IsTest
  static void givenThrowingSubscriberLogger_whenDebug_thenRoutesMessageAndFailureToFallback() {
    // Arrange
    subscriberDebugSpy.throwsException(new TestException('boom'));
    final ApexJobFailSafeLogger sut = buildSut();

    // Act
    sut.debug('message');

    // Assert
    Expect.that(fallbackDebugSpy).hasBeenCalledWith('message');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String failure = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(failure.startsWith(FAILURE_PREFIX), failure);
    Assert.isTrue(failure.endsWith(': boom'), failure);
  }
}
