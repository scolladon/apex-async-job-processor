@SuppressWarnings('PMD.ApexCRUDViolation')
public with sharing class JobMonitorController {
  private static final List<String> ALIVE_QUEUEABLE_STATUS = new List<String>{ 'Processing', 'Queued', 'Preparing' };
  private static final String QUEUEABLE_JOB_TYPE = 'Queueable';
  private static final String SCHEDULED_JOB_TYPE = 'ScheduledApex';
  private static final String JOB_NAME = AsyncApexJobExecutor.class.getName();
  private static final String JOB_WATCHER_NAME = ApexJobWatcher.class.getName();
  private static final String CUSTOM_PERMISSION = 'Manage_Async_Job_Engine';

  @AuraEnabled
  public static List<JobRequest__c> getJobRequestPage(final Integer limitSize, final Integer offsetVal) {
    return [
      SELECT
        Id,
        Name,
        JobDescription__c,
        JobDescription__r.ProcessorName__c,
        Status__c,
        Enabled__c,
        IsCandidat__c,
        AttemptNumber__c,
        WaitTime__c,
        ChunkRunTime__c,
        UnitRunTime__c,
        ProcessingTime__c,
        LastSelectionDateTime__c,
        LastExecutionDateTime__c,
        NextExecutionDateTime__c,
        LastExecutionMessage__c,
        Argument__c
      FROM JobRequest__c
      WHERE IsCandidat__c = TRUE
      ORDER BY
        IsDeleted ASC,
        JobDescription__r.Priority__c DESC,
        JobDescription__r.MaxChunkSize__c ASC,
        JobDescription__r.CalloutBaseConsumption__c ASC,
        JobDescription__r.LastExecutionDateTime__c ASC NULLS FIRST,
        NextExecutionDateTime__c ASC
      LIMIT :limitSize
      OFFSET :offsetVal
      ALL ROWS
    ];
  }

  @AuraEnabled
  public static List<Map<String, Object>> getStatusByProcessor() {
    final List<AggregateResult> rows = [
      SELECT
        Count(Id) nbRows,
        Status__c status,
        JobDescription__c processorId,
        MAX(JobDescription__r.MaxChunkSize__c) maxBulk,
        MAX(JobDescription__r.SmallestFailingChunk__c) smallestFailingChunk,
        MAX(JobDescription__r.SuccessStreak__c) successStreak,
        MAX(JobDescription__r.ConsecutiveFailures__c) consecutiveFailure,
        SUM(AttemptNumber__c) nbTry,
        FORMAT(MIN(NextExecutionDateTime__c)) nextExecutionDateTime,
        FORMAT(MIN(LastModifiedDate)) lastExecutionDateTime
      FROM JobRequest__c
      GROUP BY Status__c, JobDescription__c
      ORDER BY Status__c, JobDescription__c
    ];
    final List<Map<String, Object>> out = new List<Map<String, Object>>();
    for (AggregateResult ar : rows) {
      final Map<String, Object> m = ar.getPopulatedFieldsAsMap();
      out.add(m);
    }
    return out;
  }

  @AuraEnabled(cacheable=true)
  public static List<JobDescription__c> getJobDescriptionInfos(final List<Id> jobDescriptionIds) {
    return [SELECT Id, ProcessorName__c FROM JobDescription__c WHERE Id IN :jobDescriptionIds];
  }

  @AuraEnabled
  public static Boolean isEnabled() {
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    return cfg?.Enabled__c == true;
  }

  @AuraEnabled
  public static Integer getExecutorCount() {
    final Integer asyncApexJobExecutorCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status IN :ALIVE_QUEUEABLE_STATUS AND JobType = :QUEUEABLE_JOB_TYPE AND ApexClass.Name = :JOB_NAME
    ];
    return asyncApexJobExecutorCount;
  }

  @AuraEnabled
  public static Boolean isRecoveryBatchAlive() {
    final Integer recoveryCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status IN :ALIVE_QUEUEABLE_STATUS AND JobType = :SCHEDULED_JOB_TYPE AND ApexClass.Name = :JOB_WATCHER_NAME
    ];
    return recoveryCount > 0;
  }

  @AuraEnabled
  public static Boolean pauseEngine() {
    assertPerm();
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    cfg.Enabled__c = false;
    upsert cfg;
    return !cfg.Enabled__c;
  }

  @AuraEnabled
  public static Boolean resumeEngine() {
    assertPerm();
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    cfg.Enabled__c = true;
    upsert cfg;
    return cfg.Enabled__c;
  }

  @AuraEnabled
  public static Id restartEngine() {
    assertPerm();
    final JobExecutorSpawner spawner = new JobExecutorQueueableSpawner();
    return spawner.enqueue(0);
  }

  private static void assertPerm() {
    if (!FeatureManagement.checkPermission(CUSTOM_PERMISSION)) {
      throw new AuthorizationException('Missing permission: ' + CUSTOM_PERMISSION);
    }
  }

  public class AuthorizationException extends Exception {
  }
}
