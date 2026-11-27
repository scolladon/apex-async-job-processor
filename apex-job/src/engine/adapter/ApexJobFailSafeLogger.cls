public without sharing class ApexJobFailSafeLogger implements ApexJobLogger {
  private static final String FAILURE_PREFIX = 'AsyncJob: subscriber logger failed: ';

  private final ApexJobLogger subscriberLogger;
  private final ApexJobLogger fallbackLogger;

  public ApexJobFailSafeLogger(final ApexJobLogger subscriberLogger, final ApexJobLogger fallbackLogger) {
    this.subscriberLogger = subscriberLogger;
    this.fallbackLogger = fallbackLogger;
  }

  public void error(final String message) {
    try {
      this.subscriberLogger.error(message);
    } catch (Exception loggerError) {
      this.fallbackLogger.error(message);
      this.reportFailure(loggerError);
    }
  }

  public void debug(final String message) {
    try {
      this.subscriberLogger.debug(message);
    } catch (Exception loggerError) {
      this.fallbackLogger.debug(message);
      this.reportFailure(loggerError);
    }
  }

  public void flush() {
    try {
      this.subscriberLogger.flush();
    } catch (Exception loggerError) {
      this.reportFailure(loggerError);
    }
  }

  private void reportFailure(final Exception loggerError) {
    this.fallbackLogger.error(FAILURE_PREFIX + loggerError.getTypeName() + ': ' + loggerError.getMessage());
  }
}
