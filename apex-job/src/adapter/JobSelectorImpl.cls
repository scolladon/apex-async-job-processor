/**
 * @description Implementation of JobSelector interface for retrieving JobRequest__c records
 * This class is used inside a system class and runs in without sharing context
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class JobSelectorImpl implements JobSelector {
  private final ApexJobFactory factory;

  public JobSelectorImpl() {
    this(new ApexJobFactoryImpl());
  }

  @testVisible
  public JobSelectorImpl(final ApexJobFactory factory) {
    this.factory = factory;
  }

  public JobRequest__c[] getEligibleJobs(final List<Id> jobDescriptionToExclude) {
    final List<Id> jobDescriptionIdsToExclude = jobDescriptionToExclude ?? new List<Id>();

    final LimitService limitService = this.factory.getLimitService();
    final LimitsUsage availableLimits = limitService.getAvailableLimits();
    final Integer minMaxChunkSize = this.getMinimumMaxChunkSize();
    final Integer maxCallout = this.getMaxCallout(availableLimits);
    return [
      SELECT
        Id,
        Name,
        Argument__c,
        Enabled__c,
        Status__c,
        NextExecutionDateTime__c,
        LastExecutionDateTime__c,
        LastExecutionMessage__c,
        AttemptNumber__c,
        JobDescription__c,
        // Include all JobDescription fields
        JobDescription__r.Id,
        JobDescription__r.Name,
        JobDescription__r.ProcessorName__c,
        JobDescription__r.Enabled__c,
        JobDescription__r.MaxChunkSize__c,
        JobDescription__r.MaxExecutionAttempt__c,
        JobDescription__r.MinJobInterval__c,
        JobDescription__r.isHighPriority__c,
        JobDescription__r.isRecurrent__c,
        JobDescription__r.LastExecutionDateTime__c,
        // Governor limits consumption fields
        JobDescription__r.CpuTimeConsumption__c,
        JobDescription__r.HeapSizeConsumption__c,
        JobDescription__r.CalloutConsumption__c,
        JobDescription__r.CalloutTimeConsumption__c,
        JobDescription__r.PublishImmediateDmlConsumption__c,
        JobDescription__r.DmlRowsConsumption__c,
        JobDescription__r.DmlStatementsConsumption__c,
        JobDescription__r.QueryRowsConsumption__c,
        JobDescription__r.QueriesConsumption__c,
        JobDescription__r.SoslQueriesConsumption__c,
        JobDescription__r.FutureCallsConsumption__c
      FROM JobRequest__c
      WHERE
        JobDescription__c NOT IN :jobDescriptionIdsToExclude
        AND IsCandidat__c = TRUE
        AND JobDescription__r.MaxChunkSize__c >= :minMaxChunkSize
        AND JobDescription__r.CpuTimeConsumption__c <= :availableLimits.cpuTime
        AND JobDescription__r.HeapSizeConsumption__c <= :availableLimits.heapSize
        AND JobDescription__r.CalloutConsumption__c <= :maxCallout
        AND JobDescription__r.CalloutTimeConsumption__c <= :availableLimits.calloutTime
        AND JobDescription__r.PublishImmediateDmlConsumption__c <= :availableLimits.publishImmediateDml
        AND JobDescription__r.DmlRowsConsumption__c <= :availableLimits.dmlRows
        AND JobDescription__r.DmlStatementsConsumption__c <= :availableLimits.dmlStatements
        AND JobDescription__r.QueryRowsConsumption__c <= :availableLimits.queryRows
        AND JobDescription__r.QueriesConsumption__c <= :availableLimits.queries
        AND JobDescription__r.SoslQueriesConsumption__c <= :availableLimits.soslQueries
        AND JobDescription__r.FutureCallsConsumption__c <= :availableLimits.futureCalls
      ORDER BY
        JobDescription__r.isHighPriority__c DESC,
        JobDescription__r.MaxChunkSize__c ASC,
        JobDescription__r.CalloutConsumption__c ASC,
        JobDescription__r.LastExecutionDateTime__c ASC NULLS FIRST,
        NextExecutionDateTime__c ASC
      LIMIT :ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE
    ];
  }

  private Integer getMaxCallout(LimitsUsage availableLimits) {
    // Avoid Uncommited Work Pending
    if (availableLimits.callout != Limits.getLimitCallouts() && Limits.getDmlStatements() > 0) {
      return 0;
    }
    return availableLimits.callout;
  }

  private Integer getMinimumMaxChunkSize() {
    // Ensure Unknown governor limit is selected when full governor limit is available
    return ApexJobTransactionContext.getInstance().hasExecutedJobs ? 0 : -1;
  }
}
