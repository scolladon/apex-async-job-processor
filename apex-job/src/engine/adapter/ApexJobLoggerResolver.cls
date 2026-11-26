public without sharing class ApexJobLoggerResolver {
  private static final String NOT_FOUND = 'class not found or not public';
  private static final String NOT_A_LOGGER = 'does not implement ApexJobLogger';

  private final ApexJobLogger fallbackLogger;

  public ApexJobLoggerResolver(final ApexJobLogger fallbackLogger) {
    this.fallbackLogger = fallbackLogger;
  }

  public ApexJobLogger resolve(final String className) {
    if (String.isBlank(className)) {
      return this.fallbackLogger;
    }
    final String trimmedName = className.trim();
    final Type loggerType = Type.forName(trimmedName);
    if (loggerType == null) {
      return this.fallBack(trimmedName, NOT_FOUND);
    }
    try {
      return this.adapt(loggerType.newInstance(), trimmedName);
    } catch (Exception instantiationError) {
      return this.fallBack(trimmedName, instantiationError.getMessage());
    }
  }

  private ApexJobLogger adapt(final Object candidate, final String className) {
    if (!(candidate instanceof ApexJobLogger)) {
      return this.fallBack(className, NOT_A_LOGGER);
    }
    return new ApexJobFailSafeLogger((ApexJobLogger) candidate, this.fallbackLogger);
  }

  private ApexJobLogger fallBack(final String className, final String reason) {
    this.fallbackLogger.error('AsyncJob: logger ' + className + ' unusable (' + reason + '), falling back to System.debug');
    return this.fallbackLogger;
  }
}
