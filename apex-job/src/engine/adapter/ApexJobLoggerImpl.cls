public without sharing class ApexJobLoggerImpl implements ApexJobLogger {
  public void error(String message) {
    this.log(message, LoggingLevel.ERROR);
  }

  public void debug(String message) {
    this.log(message, LoggingLevel.DEBUG);
  }

  @SuppressWarnings('PMD.EmptyStatementBlock')
  private void log(String message, LoggingLevel level) {
    System.debug(level, message); //NOPMD
  }
}
