/**
 * Execute anonymously to kill and (re)schedule the job watcher
for(CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name Like 'Async Job Watcher%']) {
  System.abortJob(ct.Id);
}
ApexJobWatcher.schedule();
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

  @SuppressWarnings('PMD.OperationWithLimitsInLoop')
  public static void schedule() {
    // If already schedule the job, do nothing
    final String cronJobBaseName = 'Async Job Watcher';
    final Integer jobsNumber = [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE :cronJobBaseName + '%'];
    if (jobsNumber >= 1) {
      return;
    }
    final String cronJobNameTemplate = '{0} {1} (' + System.currentTimeMillis() + ')';
    // Schedule the job to run every 5 minutes
    for (Integer i = 0; i < 60; i += 5) {
      System.schedule(String.format(cronJobNameTemplate, new List<Object>{ cronJobBaseName, ('0' + i).right(2) }), '0 ' + i + ' * ? * * *', new ApexJobWatcher());
    }
  }
}
