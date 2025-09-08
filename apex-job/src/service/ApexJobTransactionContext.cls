public virtual class ApexJobTransactionContext {
  private static ApexJobTransactionContext instance = new ApexJobTransactionContext();
  public Boolean hasExecutedJobs { get; private set; }

  private ApexJobTransactionContext() {
    this.hasExecutedJobs = false;
  }

  public static ApexJobTransactionContext getInstance() {
    return instance;
  }

  public void markExecutedJobs() {
    this.hasExecutedJobs = true;
  }

  @TestVisible
  private static void reset() {
    instance = new ApexJobTransactionContext();
  }
}
