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
    result.aggregateQueries = consumedUsage.aggregateQueries - this.startSnapshot.aggregateQueries;
    result.apexCursorRows = consumedUsage.apexCursorRows - this.startSnapshot.apexCursorRows;
    result.fetchCallsOnApexCursor = consumedUsage.fetchCallsOnApexCursor - this.startSnapshot.fetchCallsOnApexCursor;
    result.emailInvocations = consumedUsage.emailInvocations - this.startSnapshot.emailInvocations;
    result.mobilePushApexCalls = consumedUsage.mobilePushApexCalls - this.startSnapshot.mobilePushApexCalls;
    result.queryLocatorRows = consumedUsage.queryLocatorRows - this.startSnapshot.queryLocatorRows;
    result.queueableJobs = consumedUsage.queueableJobs - this.startSnapshot.queueableJobs;
    return result;
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
    result.aggregateQueries = Limits.getLimitAggregateQueries() - Limits.getAggregateQueries();
    result.apexCursorRows = Limits.getLimitApexCursorRows() - Limits.getApexCursorRows();
    result.fetchCallsOnApexCursor = Limits.getLimitFetchCallsOnApexCursor() - Limits.getFetchCallsOnApexCursor();
    result.emailInvocations = Limits.getLimitEmailInvocations() - Limits.getEmailInvocations();
    result.mobilePushApexCalls = Limits.getLimitMobilePushApexCalls() - Limits.getMobilePushApexCalls();
    result.queryLocatorRows = Limits.getLimitQueryLocatorRows() - Limits.getQueryLocatorRows();
    result.queueableJobs = Limits.getLimitQueueableJobs() - Limits.getQueueableJobs();
    return result;
  }

  private LimitsUsage getConsumedLimits() {
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
    result.aggregateQueries = Limits.getAggregateQueries();
    result.apexCursorRows = Limits.getApexCursorRows();
    result.fetchCallsOnApexCursor = Limits.getFetchCallsOnApexCursor();
    result.emailInvocations = Limits.getEmailInvocations();
    result.mobilePushApexCalls = Limits.getMobilePushApexCalls();
    result.queryLocatorRows = Limits.getQueryLocatorRows();
    result.queueableJobs = Limits.getQueueableJobs();
    return result;
  }
}
