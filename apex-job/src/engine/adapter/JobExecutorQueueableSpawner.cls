public without sharing class JobExecutorQueueableSpawner implements JobExecutorSpawner {
  private static final Integer WAKE_UP_DELAY_IN_MINUTES = 0;

  private ApexJobLogger logger;
  private ApexJobFactory factory;

  @TestVisible
  private JobExecutorQueueableSpawner(final ApexJobFactory factory) {
    this.logger = factory.getLogger();
    this.factory = factory;
  }

  public JobExecutorQueueableSpawner() {
    this(new ApexJobFactoryImpl());
  }

  public Id enqueue() {
    final Integer delayInMinutes = this.factory.getConfigService().getEnqueueDelayInMinutes();
    return this.enqueue(delayInMinutes);
  }

  public void wakeUp() {
    final ApexJobTransactionContext transactionContext = ApexJobTransactionContext.getInstance();
    if (transactionContext.hasAttemptedWakeUp || System.isBatch() || System.isFuture()) {
      return;
    }
    transactionContext.markWakeUpAttempted();
    this.enqueue(WAKE_UP_DELAY_IN_MINUTES);
  }

  public Id enqueue(final Integer delayInMinutes) {
    if (this.cannotEnqueue()) {
      return null;
    }
    AsyncOptions options = new AsyncOptions();
    options.MinimumQueueableDelayInMinutes = delayInMinutes;
    options.DuplicateSignature = QueueableDuplicateSignature.Builder().addInteger(delayInMinutes).addString(AsyncApexJobExecutor.class.getName()).build();
    try {
      return System.enqueueJob(new AsyncApexJobExecutor(), options);
    } catch (DuplicateMessageException ex) {
      this.logger.debug('AsyncJob: Error while enqueuing AsyncApexJobExecutor, engine killed');
      this.logger.debug(ex.getStackTraceString());
      this.logger.error(ex.getMessage());
      this.logger.flush();
    }
    return null;
  }

  private Boolean cannotEnqueue() {
    return System.isQueueable() || // Finalizer is not queueable ;)
      this.hasNoQueueableSlotLeft() ||
      this.factory.getConfigService().isSystemEnabled() == false ||
      this.factory.getExecutorService().isRunning(null) == true;
  }

  private Boolean hasNoQueueableSlotLeft() {
    return Limits.getQueueableJobs() >= Limits.getLimitQueueableJobs();
  }
}
