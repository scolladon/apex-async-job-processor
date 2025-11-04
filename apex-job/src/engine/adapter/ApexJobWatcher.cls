/**
 * Execute anonymously to enqueue the AsyncApexJobExecutor
 * ApexJobWatcher.schedule();
 */

@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobWatcher implements Schedulable {
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
    final JobExecutorSpawner asyncJobQueueableSpawner = this.factory.getSpawner();
    asyncJobQueueableSpawner.enqueue();
  }

  public static void schedule() {
    // If already schedule the job, do nothing
    final Integer jobsNumber = [SELECT COUNT() FROM AsyncApexJob WHERE JobType = 'ScheduledApex' AND ApexClass.Name = :ApexJobWatcher.class.getName()];
    if (jobsNumber >= 1) {
      return;
    }
    final String asyncApexJobEntryBaseName = 'Async Job Watcher';
    final Long currentTime = System.currentTimeMillis();
    // Schedule the job to run every 5 minutes
    System.schedule(asyncApexJobEntryBaseName + ' 00-05 ' + currentTime, '0 00 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 05-10 ' + currentTime, '0 05 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 10-15 ' + currentTime, '0 10 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 15-20 ' + currentTime, '0 15 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 20-25 ' + currentTime, '0 20 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 25-30 ' + currentTime, '0 25 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 30-35 ' + currentTime, '0 30 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 35-40 ' + currentTime, '0 35 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 40-45 ' + currentTime, '0 40 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 45-50 ' + currentTime, '0 45 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 50-55 ' + currentTime, '0 50 * * * ?', new ApexJobWatcher());
    System.schedule(asyncApexJobEntryBaseName + ' 55-60 ' + currentTime, '0 55 * * * ?', new ApexJobWatcher());
  }
}
