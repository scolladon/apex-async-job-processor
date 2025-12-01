@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class JobExecutorQueueableSpawner implements JobExecutorSpawner {
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
    }
    return null;
  }

  private Boolean cannotEnqueue() {
    return System.isQueueable() || // Finalizer is not queueable ;)
      this.factory.getConfigService().isSystemEnabled() == false ||
      this.factory.getExecutorService().isRunning(null) == true;
  }
}
