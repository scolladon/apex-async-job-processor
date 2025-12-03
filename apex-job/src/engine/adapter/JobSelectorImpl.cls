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

  @TestVisible
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
        LastSelectionDateTime__c,
        AttemptNumber__c,
        WaitTime__c,
        ChunkRunTime__c,
        UnitRunTime__c,
        ProcessingTime__c,
        JobIds__c,
        JobDescription__c,
        // Include all JobDescription fields
        JobDescription__r.Id,
        JobDescription__r.Name,
        JobDescription__r.ProcessorName__c,
        JobDescription__r.Enabled__c,
        JobDescription__r.MaxChunkSize__c,
        JobDescription__r.MaxChunkSizeLimit__c,
        JobDescription__r.MaxExecutionAttempt__c,
        JobDescription__r.MinJobInterval__c,
        JobDescription__r.Priority__c,
        JobDescription__r.isRecurrent__c,
        JobDescription__r.LastExecutionDateTime__c,
        JobDescription__r.ConsecutiveFailures__c,
        JobDescription__r.SmallestFailingChunk__c,
        JobDescription__r.SuccessStreak__c,
        JobDescription__r.VariationResetThreashold__c,
        // Governor limits consumption fields
        JobDescription__r.CpuTimeBaseConsumption__c,
        JobDescription__r.CpuTimePerItemConsumption__c,
        JobDescription__r.CpuTimeSafety__c,
        JobDescription__r.HeapSizeBaseConsumption__c,
        JobDescription__r.HeapSizePerItemConsumption__c,
        JobDescription__r.HeapSizeSafety__c,
        JobDescription__r.CalloutBaseConsumption__c,
        JobDescription__r.CalloutPerItemConsumption__c,
        JobDescription__r.CalloutSafety__c,
        JobDescription__r.CalloutTimeBaseConsumption__c,
        JobDescription__r.CalloutTimePerItemConsumption__c,
        JobDescription__r.CalloutTimeSafety__c,
        JobDescription__r.PublishImmediateDmlBaseConsumption__c,
        JobDescription__r.PublishImmediateDmlPerItemConsumption__c,
        JobDescription__r.PublishImmediateDmlSafety__c,
        JobDescription__r.DmlRowsBaseConsumption__c,
        JobDescription__r.DmlRowsPerItemConsumption__c,
        JobDescription__r.DmlRowsSafety__c,
        JobDescription__r.DmlStatementsBaseConsumption__c,
        JobDescription__r.DmlStatementsPerItemConsumption__c,
        JobDescription__r.DmlStatementsSafety__c,
        JobDescription__r.QueryRowsBaseConsumption__c,
        JobDescription__r.QueryRowsPerItemConsumption__c,
        JobDescription__r.QueryRowsSafety__c,
        JobDescription__r.QueriesBaseConsumption__c,
        JobDescription__r.QueriesPerItemConsumption__c,
        JobDescription__r.QueriesSafety__c,
        JobDescription__r.SoslQueriesBaseConsumption__c,
        JobDescription__r.SoslQueriesPerItemConsumption__c,
        JobDescription__r.SoslQueriesSafety__c,
        JobDescription__r.FutureCallsBaseConsumption__c,
        JobDescription__r.FutureCallsPerItemConsumption__c,
        JobDescription__r.FutureCallsSafety__c,
        JobDescription__r.AggregateQueriesBaseConsumption__c,
        JobDescription__r.AggregateQueriesPerItemConsumption__c,
        JobDescription__r.AggregateQueriesSafety__c,
        JobDescription__r.ApexCursorRowsBaseConsumption__c,
        JobDescription__r.ApexCursorRowsPerItemConsumption__c,
        JobDescription__r.ApexCursorRowsSafety__c,
        JobDescription__r.FetchCallsOnApexCursorBaseConsumption__c,
        JobDescription__r.FetchCallsOnApexCursorPerItemConsumption__c,
        JobDescription__r.FetchCallsOnApexCursorSafety__c,
        JobDescription__r.EmailInvocationsBaseConsumption__c,
        JobDescription__r.EmailInvocationsPerItemConsumption__c,
        JobDescription__r.EmailInvocationsSafety__c,
        JobDescription__r.MobilePushApexCallsBaseConsumption__c,
        JobDescription__r.MobilePushApexCallsPerItemConsumption__c,
        JobDescription__r.MobilePushApexCallsSafety__c,
        JobDescription__r.QueryLocatorRowsBaseConsumption__c,
        JobDescription__r.QueryLocatorRowsPerItemConsumption__c,
        JobDescription__r.QueryLocatorRowsSafety__c,
        JobDescription__r.QueueableJobsBaseConsumption__c,
        JobDescription__r.QueueableJobsPerItemConsumption__c,
        JobDescription__r.QueueableJobsSafety__c
      FROM JobRequest__c
      WHERE
        JobDescription__c NOT IN :jobDescriptionIdsToExclude
        AND IsCandidat__c = TRUE
        AND JobDescription__r.MaxChunkSize__c >= :minMaxChunkSize
        AND JobDescription__r.CpuTimeBaseConsumption__c <= :availableLimits.cpuTime
        AND JobDescription__r.HeapSizeBaseConsumption__c <= :availableLimits.heapSize
        AND JobDescription__r.CalloutBaseConsumption__c <= :maxCallout
        AND JobDescription__r.CalloutTimeBaseConsumption__c <= :availableLimits.calloutTime
        AND JobDescription__r.PublishImmediateDmlBaseConsumption__c <= :availableLimits.publishImmediateDml
        AND JobDescription__r.DmlRowsBaseConsumption__c <= :availableLimits.dmlRows
        AND JobDescription__r.DmlStatementsBaseConsumption__c <= :availableLimits.dmlStatements
        AND JobDescription__r.QueryRowsBaseConsumption__c <= :availableLimits.queryRows
        AND JobDescription__r.QueriesBaseConsumption__c <= :availableLimits.queries
        AND JobDescription__r.SoslQueriesBaseConsumption__c <= :availableLimits.soslQueries
        AND JobDescription__r.FutureCallsBaseConsumption__c <= :availableLimits.futureCalls
        AND JobDescription__r.AggregateQueriesBaseConsumption__c <= :availableLimits.aggregateQueries
        AND JobDescription__r.ApexCursorRowsBaseConsumption__c <= :availableLimits.apexCursorRows
        AND JobDescription__r.FetchCallsOnApexCursorBaseConsumption__c <= :availableLimits.fetchCallsOnApexCursor
        AND JobDescription__r.EmailInvocationsBaseConsumption__c <= :availableLimits.emailInvocations
        AND JobDescription__r.MobilePushApexCallsBaseConsumption__c <= :availableLimits.mobilePushApexCalls
        AND JobDescription__r.QueryLocatorRowsBaseConsumption__c <= :availableLimits.queryLocatorRows
        AND JobDescription__r.QueueableJobsBaseConsumption__c <= :availableLimits.queueableJobs
      ORDER BY
        JobDescription__r.Priority__c DESC,
        JobDescription__r.MaxChunkSize__c ASC,
        JobDescription__r.CalloutBaseConsumption__c ASC,
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
