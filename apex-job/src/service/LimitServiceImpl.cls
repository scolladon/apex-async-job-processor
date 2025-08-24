public with sharing class LimitServiceImpl implements LimitService {
  private static final Decimal BUFFER_COEFFICIENT = 0.97;
  private static final Integer DEFAULT_CONSUMPTION_VALUE = -1;
  private static final Integer MAX_CALLOUT_TIME_IN_MS = 120000;

  // This value is shared accross all instance in the same transaction
  private static Integer totalCalloutTimeConsumedInMs = 0;

  private LimitsUsage startSnapshot;
  private LimitsUsage stopSnapshot;
  private Long startSnapshotTimestamp;

  public void startSnapshot() {
    this.startSnapshot = this.getConsumedLimits();
    this.startSnapshotTimestamp = System.now().getTime();
  }

  public LimitsUsage stopSnapshot() {
    final Long stopSnapshotTimestamp = System.now().getTime();
    final LimitsUsage consumedUsage = this.getConsumedLimits();
    Integer calloutTimeConsumedInMs = 0;
    if (consumedUsage.callout > this.startSnapshot.callout) {
      calloutTimeConsumedInMs = (Integer) (stopSnapshotTimestamp - this.startSnapshotTimestamp);
      LimitServiceImpl.totalCalloutTimeConsumedInMs += calloutTimeConsumedInMs;
    }

    LimitsUsage result = new LimitsUsage();
    result.cpuTime = consumedUsage.cpuTime - this.startSnapshot.cpuTime;
    result.heapSize = consumedUsage.heapSize - this.startSnapshot.heapSize;
    result.callout = consumedUsage.callout - this.startSnapshot.callout;
    result.calloutTime = calloutTimeConsumedInMs;
    result.publishImmediateDml = consumedUsage.publishImmediateDml - this.startSnapshot.publishImmediateDml;
    result.dmlRows = consumedUsage.dmlRows - this.startSnapshot.dmlRows;
    result.dmlStatements = consumedUsage.dmlStatements - this.startSnapshot.dmlStatements;
    result.queryRows = consumedUsage.queryRows - this.startSnapshot.queryRows;
    result.queries = consumedUsage.queries - this.startSnapshot.queries;
    result.soslQueries = consumedUsage.soslQueries - this.startSnapshot.soslQueries;
    result.futureCalls = consumedUsage.futureCalls - this.startSnapshot.futureCalls;
    return result;
  }

  public void updateUsage(final JobDescription__c jobDescription, final LimitsUsage limitsUsage, final Integer currentChunkSize) {
    if (jobDescription.MaxChunkSize__c == ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE) {
      jobDescription.CpuTimeConsumption__c = limitsUsage.cpuTime;
      jobDescription.HeapSizeConsumption__c = limitsUsage.heapSize;
      jobDescription.CalloutConsumption__c = limitsUsage.callout;
      jobDescription.CalloutTimeConsumption__c = limitsUsage.calloutTime;
      jobDescription.PublishImmediateDmlConsumption__c = limitsUsage.publishImmediateDml;
      jobDescription.DmlRowsConsumption__c = limitsUsage.dmlRows;
      jobDescription.DmlStatementsConsumption__c = limitsUsage.dmlStatements;
      jobDescription.QueryRowsConsumption__c = limitsUsage.queryRows;
      jobDescription.QueriesConsumption__c = limitsUsage.queries;
      jobDescription.SoslQueriesConsumption__c = limitsUsage.soslQueries;
      jobDescription.FutureCallsConsumption__c = limitsUsage.futureCalls;
    }
    // Update the max chunk size (after interpolation)
    jobDescription.MaxChunkSize__c = Math.max(jobDescription.MaxChunkSize__c, currentChunkSize);
  }

  // TODO should be part of the JobDescription domain
  public void resetUsage(final JobDescription__c jobDescription) {
    jobDescription.CpuTimeConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.HeapSizeConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.CalloutConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.CalloutTimeConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.PublishImmediateDmlConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.DmlRowsConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.DmlStatementsConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.QueryRowsConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.QueriesConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.SoslQueriesConsumption__c = DEFAULT_CONSUMPTION_VALUE;
    jobDescription.FutureCallsConsumption__c = DEFAULT_CONSUMPTION_VALUE;
  }

  public LimitsUsage getAvailableLimits() {
    // Calculate base available limits
    final Integer baseCpuTime = Limits.getLimitCpuTime() - Limits.getCpuTime();
    final Integer baseHeapSize = Limits.getLimitHeapSize() - Limits.getHeapSize();

    LimitsUsage result = new LimitsUsage();
    result.cpuTime = (Integer) (baseCpuTime * BUFFER_COEFFICIENT);
    result.heapSize = (Integer) (baseHeapSize * BUFFER_COEFFICIENT);
    result.callout = Limits.getLimitCallouts() - Limits.getCallouts();
    result.calloutTime = MAX_CALLOUT_TIME_IN_MS - LimitServiceImpl.totalCalloutTimeConsumedInMs;
    result.publishImmediateDml = Limits.getLimitPublishImmediateDml() - Limits.getPublishImmediateDml();
    result.dmlRows = Limits.getLimitDmlRows() - Limits.getDmlRows();
    result.dmlStatements = Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    result.queryRows = Limits.getLimitQueryRows() - Limits.getQueryRows();
    result.queries = Limits.getLimitQueries() - Limits.getQueries();
    result.soslQueries = Limits.getLimitSoslQueries() - Limits.getSoslQueries();
    result.futureCalls = Limits.getLimitFutureCalls() - Limits.getFutureCalls();
    return result;
  }

  public LimitsUsage getConsumedLimits() {
    LimitsUsage result = new LimitsUsage();
    result.cpuTime = Limits.getCpuTime();
    result.heapSize = Limits.getHeapSize();
    result.callout = Limits.getCallouts();
    result.calloutTime = 0; // Callout time is not tracked for consumed limits
    result.publishImmediateDml = Limits.getPublishImmediateDml();
    result.dmlRows = Limits.getDmlRows();
    result.dmlStatements = Limits.getDmlStatements();
    result.queryRows = Limits.getQueryRows();
    result.queries = Limits.getQueries();
    result.soslQueries = Limits.getSoslQueries();
    result.futureCalls = Limits.getFutureCalls();
    return result;
  }

  public Integer computeMaxChunkSizeForTransaction(final JobDescription__c jobDescription) {
    if (jobDescription.MaxChunkSize__c == ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE) {
      return 1;
    }

    final LimitsUsage availableLimits = this.getAvailableLimits();
    Integer minChunkSize = ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE;

    // Check each limit type and calculate potential chunk size
    Integer potentialChunkSize;

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.dmlStatements, jobDescription.DmlStatementsConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.queries, jobDescription.QueriesConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.queryRows, jobDescription.QueryRowsConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.dmlRows, jobDescription.DmlRowsConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.soslQueries, jobDescription.SoslQueriesConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.cpuTime, jobDescription.CpuTimeConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.callout, jobDescription.CalloutConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.calloutTime, jobDescription.CalloutTimeConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.futureCalls, jobDescription.FutureCallsConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.publishImmediateDml, jobDescription.PublishImmediateDmlConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    potentialChunkSize = this.computePotentialChunkSize(availableLimits.heapSize, jobDescription.HeapSizeConsumption__c);
    if (potentialChunkSize <= 1) {
      return potentialChunkSize;
    }
    minChunkSize = Math.min(minChunkSize, potentialChunkSize);

    return minChunkSize;
  }

  private Integer computePotentialChunkSize(final Integer availableLimit, final Decimal jobDescriptionLimit) {
    if (jobDescriptionLimit <= 0) {
      return ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE;
    }
    return (Integer) Math.floor(availableLimit / jobDescriptionLimit);
  }
}
