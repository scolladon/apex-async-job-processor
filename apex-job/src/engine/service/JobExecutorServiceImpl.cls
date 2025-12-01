public inherited sharing class JobExecutorServiceImpl implements JobExecutorService {
  private static final String PROCESSING_QUEUEABLE_STATUS = 'Processing';
  private static final String QUEUEABLE_JOB_TYPE = 'Queueable';

  @SuppressWarnings('PMD.ApexCRUDViolation')
  public Boolean isRunning(final Id jobExecutorToExclude) {
    final Integer asyncApexJobExecutorCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status = :PROCESSING_QUEUEABLE_STATUS AND JobType = :QUEUEABLE_JOB_TYPE AND ApexClass.Name = :AsyncApexJobExecutor.class.getName() AND Id != :jobExecutorToExclude
    ];
    return asyncApexJobExecutorCount > 0;
  }
}
