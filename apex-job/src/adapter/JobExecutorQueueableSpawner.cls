@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class JobExecutorQueueableSpawner implements JobExecutorSpawner {
  private static final String[] ALIVE_QUEUEABLE_STATUS = new List<String>{ 'Processing', 'Queued', 'Preparing' };
  private static final String QUEUEABLE_JOB_TYPE = 'Queueable';
  public Id enqueue(final AsyncApexJobExecutor executor, final Integer delayInMinutes) {
    final Integer asyncApexJobExecutorCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status IN :ALIVE_QUEUEABLE_STATUS AND JobType = :QUEUEABLE_JOB_TYPE AND ApexClass.Name = :AsyncApexJobExecutor.class.getName()
    ];
    if (asyncApexJobExecutorCount >= 1) {
      return null;
    }
    return System.enqueueJob(executor, delayInMinutes);
  }
}
