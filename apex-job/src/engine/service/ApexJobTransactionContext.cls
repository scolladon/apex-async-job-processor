public virtual class ApexJobTransactionContext {
  private static ApexJobTransactionContext instance = new ApexJobTransactionContext();
  public Boolean hasExecutedJobs { get; private set; }
  public Boolean hasAttemptedWakeUp { get; private set; }

  private ApexJobTransactionContext() {
    this.hasExecutedJobs = false;
    this.hasAttemptedWakeUp = false;
  }

  public static ApexJobTransactionContext getInstance() {
    return instance;
  }

  public void markExecutedJobs() {
    this.hasExecutedJobs = true;
  }

  public void markWakeUpAttempted() {
    this.hasAttemptedWakeUp = true;
  }

  @TestVisible
  private static void reset() {
    instance = new ApexJobTransactionContext();
  }
}
