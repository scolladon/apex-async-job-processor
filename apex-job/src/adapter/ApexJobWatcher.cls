public without sharing class ApexJobWatcher implements Schedulable {
  /**
   *
   */
  private final ApexJobFactory factory;

  public ApexJobWatcher() {
    this(new ApexJobFactoryImpl());
  }

  @TestVisible
  private ApexJobWatcher(final ApexJobFactory factory) {
    this.factory = factory;
  }

  public void execute(SchedulableContext ctx) {
    this.watchAndWakeup();
  }

  private void watchAndWakeup() {
    final ApexJobConfigService configService = this.factory.getConfigService();
    if (configService.isSystemEnabled() != true) {
      return;
    }

    final Integer delay = configService.getEnqueueDelayInMinutes();
    final JobExecutorSpawner asyncJobQueueableSpawner = this.factory.getSpawner();
    asyncJobQueueableSpawner.enqueue(new AsyncApexJobExecutor(), delay);
  }

  public static void schedule() {
    // If already schedule the job, do nothing
    final Integer jobsNumber = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND ApexClass.Name = :ApexJobWatcher.class.getName()];
    if (jobsNumber >= 1) {
      return;
    }
    final String asyncApexJobEntryBaseName = 'Async Job Watcher';
    // Schedule the job to run every 5 minutes
    System.schedule(asyncApexJobEntryBaseName + ' 00-05', '0 00 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 05-10', '0 05 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 10-15', '0 10 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 15-20', '0 15 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 20-25', '0 20 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 25-30', '0 25 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 30-35', '0 30 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 35-40', '0 35 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 40-45', '0 40 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 45-50', '0 45 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 50-55', '0 50 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 55-60', '0 55 * * * ?', new ApexJobWatcher());
  }
}
