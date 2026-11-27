@IsTest
private class ApexJobLoggerResolverTest {
  private static final String CTOR_FAILURE = 'constructor failed';
  private static final String FIXTURE_PREFIX = 'ApexJobLoggerResolverTest.';

  private static final String FLUSH_MARKER = 'FLUSH';
  private static List<String> recordedMessages = new List<String>();
  private static Mock fallbackMock = Mock.forType(ApexJobLogger.class);
  private static MethodSpy fallbackDebugSpy = fallbackMock.spyOn('debug');
  private static MethodSpy fallbackErrorSpy = fallbackMock.spyOn('error');

  private class TestException extends Exception {
  }

  public class RecordingLogger implements ApexJobLogger {
    public void debug(final String message) {
      recordedMessages.add(message);
    }

    public void error(final String message) {
      recordedMessages.add(message);
    }

    public void flush() {
      recordedMessages.add(FLUSH_MARKER);
    }
  }

  public class NotALogger {
    public String name() {
      return 'not a logger';
    }
  }

  public class NoNoArgCtorLogger implements ApexJobLogger {
    private final String label;

    public NoNoArgCtorLogger(final String label) {
      this.label = label;
    }

    public void debug(final String message) {
      recordedMessages.add(message);
    }

    public void error(final String message) {
      recordedMessages.add(message);
    }

    public void flush() {
      recordedMessages.add(FLUSH_MARKER);
    }
  }

  public class ThrowingCtorLogger implements ApexJobLogger {
    public ThrowingCtorLogger() {
      throw new TestException(CTOR_FAILURE);
    }

    public void debug(final String message) {
      recordedMessages.add(message);
    }

    public void error(final String message) {
      recordedMessages.add(message);
    }

    public void flush() {
      recordedMessages.add(FLUSH_MARKER);
    }
  }

  public class ThrowingLogger implements ApexJobLogger {
    public void debug(final String message) {
      throw new TestException(message);
    }

    public void error(final String message) {
      throw new TestException(message);
    }

    public void flush() {
      throw new TestException('flush');
    }
  }

  private class PrivateLogger implements ApexJobLogger {
    public void debug(final String message) {
      recordedMessages.add(message);
    }

    public void error(final String message) {
      recordedMessages.add(message);
    }

    public void flush() {
      recordedMessages.add(FLUSH_MARKER);
    }
  }

  private static ApexJobLogger fallbackStub() {
    return (ApexJobLogger) fallbackMock.stub;
  }

  @IsTest
  static void givenNullClassName_whenResolve_thenReturnsFallbackWithoutError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    final ApexJobLogger result = sut.resolve(null);

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenEmptyClassName_whenResolve_thenReturnsFallbackWithoutError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    final ApexJobLogger result = sut.resolve('');

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenWhitespaceClassName_whenResolve_thenReturnsFallbackWithoutError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    final ApexJobLogger result = sut.resolve('   ');

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenUnknownClassName_whenResolve_thenFallsBackAndLogsError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    final ApexJobLogger result = sut.resolve('DoesNotExist');

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String loggedMessage = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(loggedMessage.contains('DoesNotExist'), loggedMessage);
    Assert.isTrue(loggedMessage.contains('not found'), loggedMessage);
  }

  @IsTest
  static void givenPrivateClassName_whenResolve_thenFallsBackAndLogsError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());
    final String className = FIXTURE_PREFIX + 'PrivateLogger';

    // Act
    final ApexJobLogger result = sut.resolve(className);

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String loggedMessage = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(loggedMessage.contains(className), loggedMessage);
    Assert.isTrue(loggedMessage.contains('not found'), loggedMessage);
  }

  @IsTest
  static void givenPaddedLoggerClassName_whenResolve_thenDelegatesToConfiguredLogger() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    sut.resolve(' ' + FIXTURE_PREFIX + 'RecordingLogger ').debug('x');

    // Assert
    Assert.areEqual(new List<String>{ 'x' }, recordedMessages);
    Expect.that(fallbackDebugSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenLowerCaseLoggerClassName_whenResolve_thenDelegatesToConfiguredLogger() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    // Act
    sut.resolve((FIXTURE_PREFIX + 'RecordingLogger').toLowerCase()).debug('x');

    // Assert
    Assert.areEqual(new List<String>{ 'x' }, recordedMessages);
    Expect.that(fallbackDebugSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenClassNotImplementingLogger_whenResolve_thenFallsBackAndLogsError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    final String className = FIXTURE_PREFIX + 'NotALogger';

    // Act
    final ApexJobLogger result = sut.resolve(className);

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String loggedMessage = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(loggedMessage.contains(className), loggedMessage);
    Assert.isTrue(loggedMessage.contains('does not implement ApexJobLogger'), loggedMessage);
  }

  @IsTest
  static void givenLoggerWithoutNoArgConstructor_whenResolve_thenFallsBackAndLogsError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());
    final String className = FIXTURE_PREFIX + 'NoNoArgCtorLogger';

    // Act
    final ApexJobLogger result = sut.resolve(className);

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String loggedMessage = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(loggedMessage.contains(className), loggedMessage);
    Assert.isTrue(loggedMessage.contains('no-arg constructor'), loggedMessage);
  }

  @IsTest
  static void givenLoggerWhoseConstructorThrows_whenResolve_thenFallsBackAndLogsConstructorError() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());

    final String className = FIXTURE_PREFIX + 'ThrowingCtorLogger';

    // Act
    final ApexJobLogger result = sut.resolve(className);

    // Assert
    Assert.isTrue(result === fallbackStub(), 'Expected the fallback logger');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
    final String loggedMessage = (String) fallbackErrorSpy.getArguments(0)[0];
    Assert.isTrue(loggedMessage.contains(className), loggedMessage);
    Assert.isTrue(loggedMessage.contains(CTOR_FAILURE), loggedMessage);
  }

  @IsTest
  static void givenLoggerThatThrowsWhileLogging_whenResolvedLoggerDebugs_thenFallbackReceivesLineAndFailure() {
    // Arrange
    final ApexJobLoggerResolver sut = new ApexJobLoggerResolver(fallbackStub());
    final ApexJobLogger resolved = sut.resolve(FIXTURE_PREFIX + 'ThrowingLogger');

    // Act
    resolved.debug('x');

    // Assert
    Expect.that(fallbackDebugSpy).hasBeenCalledWith('x');
    Expect.that(fallbackErrorSpy).hasBeenCalledTimes(1);
  }
}
