public with sharing class JobMonitorController {
  private static final List<String> ALIVE_QUEUEABLE_STATUS = new List<String>{ 'Processing', 'Queued', 'Preparing', 'Holding' };
  private static final String QUEUEABLE_JOB_TYPE = 'Queueable';
  private static final String SCHEDULED_JOB_TYPE = 'ScheduledApex';
  private static final String JOB_NAME = AsyncApexJobExecutor.class.getName();
  private static final String JOB_WATCHER_NAME = ApexJobWatcher.class.getName();
  private static final String CUSTOM_PERMISSION = 'Manage_Async_Job_Engine';

  @AuraEnabled
  public static List<JobRequest__c> getJobRequestPage(final Integer limitSize, final Integer offsetVal) {
    final Datetime now = Datetime.now();
    return [
      SELECT
        Id,
        Name,
        JobDescription__c,
        JobDescription__r.ProcessorName__c,
        Status__c,
        Enabled__c,
        IsCandidate__c,
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
      WHERE IsCandidate__c = TRUE AND NextExecutionDateTime__c <= :now
      WITH SYSTEM_MODE
      ORDER BY
        JobDescription__r.Priority__c DESC,
        JobDescription__r.MaxChunkSize__c ASC,
        JobDescription__r.CalloutBaseConsumption__c ASC,
        JobDescription__r.LastExecutionDateTime__c ASC NULLS FIRST,
        NextExecutionDateTime__c ASC
      LIMIT :limitSize
      OFFSET :offsetVal
    ];
  }

  @AuraEnabled
  @SuppressWarnings('PMD.AvoidNonRestrictiveQueries ')
  public static List<Map<String, Object>> getStatusByProcessor() {
    final List<AggregateResult> rows = [
      SELECT COUNT(Id) nbRows, Status__c status, JobDescription__c processorId
      FROM JobRequest__c
      WITH SYSTEM_MODE
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

  // Not cacheable: ExecutionsInCurrentWindow__c, CurrentWindowStart__c and KillBackoffUntil__c are volatile runtime state
  @AuraEnabled
  public static List<JobDescription__c> getJobDescriptionInfos(final List<Id> jobDescriptionIds) {
    return [
      SELECT
        Id,
        ProcessorName__c,
        MaxExecutionsPerMinute__c,
        ExecutionsInCurrentWindow__c,
        CurrentWindowStart__c,
        MaxChunkSize__c,
        SmallestFailingChunk__c,
        SuccessStreak__c,
        ConsecutiveFailures__c,
        LastExecutionDateTime__c,
        KillBackoffUntil__c
      FROM JobDescription__c
      WHERE Id IN :jobDescriptionIds
      WITH SYSTEM_MODE
    ];
  }

  @AuraEnabled
  public static EngineStatus getEngineStatus() {
    final EngineStatus status = new EngineStatus();
    status.enabled = isEnabled();
    status.executorCount = getExecutorCount();
    status.watcherScheduled = isRecoveryBatchAlive();
    return status;
  }

  private static Boolean isEnabled() {
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    return cfg?.Enabled__c == true;
  }

  private static Integer getExecutorCount() {
    final Integer asyncApexJobExecutorCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status IN :ALIVE_QUEUEABLE_STATUS AND JobType = :QUEUEABLE_JOB_TYPE AND ApexClass.Name = :JOB_NAME
      WITH SYSTEM_MODE
    ];
    return asyncApexJobExecutorCount;
  }

  private static Boolean isRecoveryBatchAlive() {
    final Integer recoveryCount = [
      SELECT COUNT()
      FROM AsyncApexJob
      WHERE Status IN :ALIVE_QUEUEABLE_STATUS AND JobType = :SCHEDULED_JOB_TYPE AND ApexClass.Name = :JOB_WATCHER_NAME
      WITH SYSTEM_MODE
    ];
    return recoveryCount > 0;
  }

  @AuraEnabled
  public static Boolean pauseEngine() {
    assertPerm();
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    cfg.Enabled__c = false;
    upsert as system cfg;
    return !cfg.Enabled__c;
  }

  @AuraEnabled
  public static Boolean resumeEngine() {
    assertPerm();
    ApexJobConfig__c cfg = ApexJobConfig__c.getOrgDefaults();
    cfg.Enabled__c = true;
    upsert as system cfg;
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

  public class EngineStatus {
    @AuraEnabled
    public Boolean enabled;
    @AuraEnabled
    public Integer executorCount;
    @AuraEnabled
    public Boolean watcherScheduled;
  }
}
