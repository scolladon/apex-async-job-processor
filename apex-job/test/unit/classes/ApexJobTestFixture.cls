@isTest
@SuppressWarnings('PMD.ExcessivePublicCount')
public class ApexJobTestFixture {
  private static Integer uniqueCounter = 0;

  // JobDescription Builder
  public class JobDescriptionBuilder {
    private final JobDescription__c record;

    public JobDescriptionBuilder() {
      this.record = new JobDescription__c(
        Name = 'TestProcessor' + (++uniqueCounter),
        ProcessorName__c = 'TestProcessor',
        Enabled__c = true,
        MaxChunkSize__c = ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE,
        MaxChunkSizeLimit__c = ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE,
        MaxExecutionAttempt__c = -1,
        MinJobInterval__c = 0,
        Priority__c = -1,
        isRecurrent__c = false,
        ConsecutiveFailures__c = 0,
        SmallestFailingChunk__c = 0,
        SuccessStreak__c = 0,
        VariationResetThreashold__c = 0.3
      );
      for (ConsumptionModel model : ConsumptionModel.asList()) {
        this.record.put(model.base, ApexJobConstant.UNKNOWN_BASE_CONSUMPTION);
        this.record.put(model.perItem, ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION);
        this.record.put(model.safety, ApexJobConstant.UNKNOWN_SAFETY);
      }
    }

    public JobDescriptionBuilder withId(final Id id) {
      this.record.Id = id;
      return this;
    }

    public JobDescriptionBuilder withName(final String name) {
      this.record.Name = name;
      return this;
    }

    public JobDescriptionBuilder withProcessorName(final String processorName) {
      this.record.ProcessorName__c = processorName;
      return this;
    }

    public JobDescriptionBuilder enabled() {
      this.record.Enabled__c = true;
      return this;
    }

    public JobDescriptionBuilder disabled() {
      this.record.Enabled__c = false;
      return this;
    }

    public JobDescriptionBuilder withMaxChunkSize(final Integer maxChunkSize) {
      this.record.MaxChunkSize__c = maxChunkSize;
      return this;
    }

    public JobDescriptionBuilder withMaxChunkSizeLimit(final Integer value) {
      this.record.MaxChunkSizeLimit__c = value;
      return this;
    }

    public JobDescriptionBuilder withConsecutiveFailures(final Integer value) {
      this.record.ConsecutiveFailures__c = value;
      return this;
    }

    public JobDescriptionBuilder withSmallestFailingChunk(final Integer value) {
      this.record.SmallestFailingChunk__c = value;
      return this;
    }

    public JobDescriptionBuilder withSuccessStreak(final Integer value) {
      this.record.SuccessStreak__c = value;
      return this;
    }

    public JobDescriptionBuilder withMaxExecutionAttempt(final Integer maxAttempt) {
      this.record.MaxExecutionAttempt__c = maxAttempt;
      return this;
    }

    public JobDescriptionBuilder withMinJobInterval(final Integer minutes) {
      this.record.MinJobInterval__c = minutes;
      return this;
    }

    public JobDescriptionBuilder withVariationResetThreashold(final Decimal value) {
      this.record.VariationResetThreashold__c = value;
      return this;
    }

    public JobDescriptionBuilder priority(final Integer priority) {
      this.record.Priority__c = priority;
      return this;
    }

    public JobDescriptionBuilder recurrent() {
      this.record.isRecurrent__c = true;
      return this;
    }

    public JobDescriptionBuilder nonRecurrent() {
      this.record.isRecurrent__c = false;
      return this;
    }

    public JobDescriptionBuilder withCpuTimeConsumption(final Integer value) {
      this.record.CpuTimeBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withHeapSizeConsumption(final Integer value) {
      this.record.HeapSizeBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutConsumption(final Integer value) {
      this.record.CalloutBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutTimeConsumption(final Integer value) {
      this.record.CalloutTimeBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlRowsConsumption(final Integer value) {
      this.record.DmlRowsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlStatementsConsumption(final Integer value) {
      this.record.DmlStatementsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryRowsConsumption(final Integer value) {
      this.record.QueryRowsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueriesConsumption(final Integer value) {
      this.record.QueriesBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withPublishImmediateDmlConsumption(final Integer value) {
      this.record.PublishImmediateDmlBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withSoslQueriesConsumption(final Integer value) {
      this.record.SoslQueriesBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withFutureCallsConsumption(final Integer value) {
      this.record.FutureCallsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCpuTimePerItemConsumption(final Decimal value) {
      this.record.CpuTimePerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCpuTimeSafety(final Decimal value) {
      this.record.CpuTimeSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withHeapSizePerItemConsumption(final Decimal value) {
      this.record.HeapSizePerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withHeapSizeSafety(final Decimal value) {
      this.record.HeapSizeSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryRowsPerItemConsumption(final Decimal value) {
      this.record.QueryRowsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryRowsSafety(final Decimal value) {
      this.record.QueryRowsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlRowsPerItemConsumption(final Decimal value) {
      this.record.DmlRowsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlRowsSafety(final Decimal value) {
      this.record.DmlRowsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutPerItemConsumption(final Decimal value) {
      this.record.CalloutPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutSafety(final Decimal value) {
      this.record.CalloutSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutTimePerItemConsumption(final Decimal value) {
      this.record.CalloutTimePerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutTimeSafety(final Decimal value) {
      this.record.CalloutTimeSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withAllConsumptions(final Integer cpuTime, final Integer heapSize, final Integer queries) {
      this.record.CpuTimeBaseConsumption__c = cpuTime;
      this.record.HeapSizeBaseConsumption__c = heapSize;
      this.record.QueriesBaseConsumption__c = queries;
      return this;
    }

    public JobDescriptionBuilder withAllowedDays(final String allowedDays) {
      this.record.AllowedDays__c = allowedDays;
      return this;
    }

    public JobDescriptionBuilder withAllowedStartTime(final Time allowedStartTime) {
      this.record.AllowedStartTime__c = allowedStartTime;
      return this;
    }

    public JobDescriptionBuilder withAllowedEndTime(final Time allowedEndTime) {
      this.record.AllowedEndTime__c = allowedEndTime;
      return this;
    }

    public JobDescriptionBuilder withAggregateQueriesConsumption(final Integer value) {
      this.record.AggregateQueriesBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withAggregateQueriesPerItemConsumption(final Decimal value) {
      this.record.AggregateQueriesPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withAggregateQueriesSafety(final Decimal value) {
      this.record.AggregateQueriesSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withApexCursorRowsConsumption(final Integer value) {
      this.record.ApexCursorRowsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withApexCursorRowsPerItemConsumption(final Decimal value) {
      this.record.ApexCursorRowsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withApexCursorRowsSafety(final Decimal value) {
      this.record.ApexCursorRowsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withFetchCallsOnApexCursorConsumption(final Integer value) {
      this.record.FetchCallsOnApexCursorBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withFetchCallsOnApexCursorPerItemConsumption(final Decimal value) {
      this.record.FetchCallsOnApexCursorPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withFetchCallsOnApexCursorSafety(final Decimal value) {
      this.record.FetchCallsOnApexCursorSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withEmailInvocationsConsumption(final Integer value) {
      this.record.EmailInvocationsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withEmailInvocationsPerItemConsumption(final Decimal value) {
      this.record.EmailInvocationsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withEmailInvocationsSafety(final Decimal value) {
      this.record.EmailInvocationsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withMobilePushApexCallsConsumption(final Integer value) {
      this.record.MobilePushApexCallsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withMobilePushApexCallsPerItemConsumption(final Decimal value) {
      this.record.MobilePushApexCallsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withMobilePushApexCallsSafety(final Decimal value) {
      this.record.MobilePushApexCallsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryLocatorRowsConsumption(final Integer value) {
      this.record.QueryLocatorRowsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryLocatorRowsPerItemConsumption(final Decimal value) {
      this.record.QueryLocatorRowsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryLocatorRowsSafety(final Decimal value) {
      this.record.QueryLocatorRowsSafety__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueueableJobsConsumption(final Integer value) {
      this.record.QueueableJobsBaseConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueueableJobsPerItemConsumption(final Decimal value) {
      this.record.QueueableJobsPerItemConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueueableJobsSafety(final Decimal value) {
      this.record.QueueableJobsSafety__c = value;
      return this;
    }

    public JobDescription__c build() {
      return this.record;
    }

    public JobDescription__c buildAndInsert() {
      insert this.record;
      return this.record;
    }
  }

  // JobRequest Builder
  public class JobRequestBuilder {
    private final JobRequest__c record;

    public JobRequestBuilder() {
      this.record = new JobRequest__c(
        Name = 'TestJob' + (++uniqueCounter),
        Argument__c = '{"test": "data"}',
        Enabled__c = true,
        Status__c = ApexJobStatus.READY.name(),
        NextExecutionDateTime__c = System.now().addMinutes(-5),
        LastExecutionDateTime__c = null,
        AttemptNumber__c = 0
      );
    }

    public JobRequestBuilder withName(final String name) {
      this.record.Name = name;
      return this;
    }

    public JobRequestBuilder withArgument(final String argument) {
      this.record.Argument__c = argument;
      return this;
    }

    public JobRequestBuilder withArgumentObject(final Object argument) {
      this.record.Argument__c = JSON.serialize(argument);
      return this;
    }

    public JobRequestBuilder enabled() {
      this.record.Enabled__c = true;
      return this;
    }

    public JobRequestBuilder disabled() {
      this.record.Enabled__c = false;
      return this;
    }

    public JobRequestBuilder withStatus(final ApexJobStatus status) {
      this.record.Status__c = status.name();
      return this;
    }

    public JobRequestBuilder ready() {
      this.record.Status__c = ApexJobStatus.READY.name();
      return this;
    }

    public JobRequestBuilder success() {
      this.record.Status__c = ApexJobStatus.SUCCESS.name();
      return this;
    }

    public JobRequestBuilder failure() {
      this.record.Status__c = ApexJobStatus.FAILURE.name();
      return this;
    }

    public JobRequestBuilder aborted() {
      this.record.Status__c = ApexJobStatus.ABORTED.name();
      return this;
    }

    public JobRequestBuilder withNextExecutionDateTime(final Datetime nextExecution) {
      this.record.NextExecutionDateTime__c = nextExecution;
      return this;
    }

    public JobRequestBuilder readyNow() {
      this.record.NextExecutionDateTime__c = System.now().addMinutes(-1);
      return this;
    }

    public JobRequestBuilder readyInFuture(final Integer minutesFromNow) {
      this.record.NextExecutionDateTime__c = System.now().addMinutes(minutesFromNow);
      return this;
    }

    public JobRequestBuilder withLastExecutionDateTime(final Datetime lastExecution) {
      this.record.LastExecutionDateTime__c = lastExecution;
      return this;
    }

    public JobRequestBuilder withAttemptNumber(final Integer attemptNumber) {
      this.record.AttemptNumber__c = attemptNumber;
      return this;
    }

    public JobRequestBuilder withLastExecutionMessage(final String message) {
      this.record.LastExecutionMessage__c = message;
      return this;
    }

    public JobRequestBuilder withJobDescription(final Id jobDescriptionId) {
      this.record.JobDescription__c = jobDescriptionId;
      return this;
    }

    public JobRequestBuilder withJobDescription(final JobDescription__c jobDescription) {
      if (jobDescription.Id != null) {
        this.record.JobDescription__c = jobDescription.Id;
      }
      this.record.JobDescription__r = jobDescription;
      return this;
    }

    public JobRequest__c build() {
      return this.record;
    }

    public JobRequest__c buildAndInsert() {
      insert this.record;
      return this.record;
    }

    public List<JobRequest__c> buildMany(final Integer count) {
      final List<JobRequest__c> records = new List<JobRequest__c>();
      for (Integer i = 0; i < count; i++) {
        records.add(
          new JobRequestBuilder()
            .withName(this.record.Name + '_' + i)
            .withArgument(this.record.Argument__c)
            .withStatus(ApexJobStatus.valueOf(this.record.Status__c))
            .withNextExecutionDateTime(this.record.NextExecutionDateTime__c)
            .withAttemptNumber(Integer.valueOf(this.record.AttemptNumber__c))
            .withJobDescription(this.record.JobDescription__r)
            .build()
        );
      }
      return records;
    }
  }

  // LimitsUsage Builder
  public class LimitsUsageBuilder {
    private final LimitsUsage usage;

    public LimitsUsageBuilder() {
      this.usage = new LimitsUsage();
      this.usage.cpuTime = 0;
      this.usage.heapSize = 0;
      this.usage.callout = 0;
      this.usage.calloutTime = 0;
      this.usage.publishImmediateDml = 0;
      this.usage.dmlRows = 0;
      this.usage.dmlStatements = 0;
      this.usage.queryRows = 0;
      this.usage.queries = 0;
      this.usage.soslQueries = 0;
      this.usage.futureCalls = 0;
      this.usage.aggregateQueries = 0;
      this.usage.apexCursorRows = 0;
      this.usage.fetchCallsOnApexCursor = 0;
      this.usage.emailInvocations = 0;
      this.usage.mobilePushApexCalls = 0;
      this.usage.queryLocatorRows = 0;
      this.usage.queueableJobs = 0;
    }

    public LimitsUsageBuilder withCpuTime(final Integer value) {
      this.usage.cpuTime = value;
      return this;
    }

    public LimitsUsageBuilder withHeapSize(final Integer value) {
      this.usage.heapSize = value;
      return this;
    }

    public LimitsUsageBuilder withCallout(final Integer value) {
      this.usage.callout = value;
      return this;
    }

    public LimitsUsageBuilder withCalloutTime(final Integer value) {
      this.usage.calloutTime = value;
      return this;
    }

    public LimitsUsageBuilder withPublishImmediateDml(final Integer value) {
      this.usage.publishImmediateDml = value;
      return this;
    }

    public LimitsUsageBuilder withDmlRows(final Integer value) {
      this.usage.dmlRows = value;
      return this;
    }

    public LimitsUsageBuilder withDmlStatements(final Integer value) {
      this.usage.dmlStatements = value;
      return this;
    }

    public LimitsUsageBuilder withQueryRows(final Integer value) {
      this.usage.queryRows = value;
      return this;
    }

    public LimitsUsageBuilder withQueries(final Integer value) {
      this.usage.queries = value;
      return this;
    }

    public LimitsUsageBuilder withSoslQueries(final Integer value) {
      this.usage.soslQueries = value;
      return this;
    }

    public LimitsUsageBuilder withFutureCalls(final Integer value) {
      this.usage.futureCalls = value;
      return this;
    }

    public LimitsUsageBuilder withAggregateQueries(final Integer value) {
      this.usage.aggregateQueries = value;
      return this;
    }

    public LimitsUsageBuilder withApexCursorRows(final Integer value) {
      this.usage.apexCursorRows = value;
      return this;
    }

    public LimitsUsageBuilder withFetchCallsOnApexCursor(final Integer value) {
      this.usage.fetchCallsOnApexCursor = value;
      return this;
    }

    public LimitsUsageBuilder withEmailInvocations(final Integer value) {
      this.usage.emailInvocations = value;
      return this;
    }

    public LimitsUsageBuilder withMobilePushApexCalls(final Integer value) {
      this.usage.mobilePushApexCalls = value;
      return this;
    }

    public LimitsUsageBuilder withQueryLocatorRows(final Integer value) {
      this.usage.queryLocatorRows = value;
      return this;
    }

    public LimitsUsageBuilder withQueueableJobs(final Integer value) {
      this.usage.queueableJobs = value;
      return this;
    }

    public LimitsUsage build() {
      return this.usage;
    }
  }

  // Factory methods
  public static JobDescriptionBuilder aJobDescription() {
    return new JobDescriptionBuilder();
  }

  public static JobRequestBuilder aJobRequest() {
    return new JobRequestBuilder();
  }

  public static LimitsUsageBuilder aLimitsUsage() {
    return new LimitsUsageBuilder();
  }

  public static LimitsUsage createMaxAvailableLimits() {
    return aLimitsUsage()
      .withCallout(Limits.getLimitCallouts())
      .withCalloutTime(120000)
      .withCpuTime(Limits.getLimitCpuTime())
      .withDmlRows(Limits.getLimitDmlRows())
      .withDmlStatements(Limits.getLimitDmlStatements())
      .withFutureCalls(Limits.getLimitFutureCalls())
      .withHeapSize(Limits.getLimitHeapSize())
      .withPublishImmediateDml(Limits.getLimitPublishImmediateDml())
      .withQueries(Limits.getLimitQueries())
      .withQueryRows(Limits.getLimitQueryRows())
      .withSoslQueries(Limits.getLimitSoslQueries())
      .withAggregateQueries(Limits.getLimitAggregateQueries())
      .withApexCursorRows(Limits.getLimitApexCursorRows())
      .withFetchCallsOnApexCursor(Limits.getLimitFetchCallsOnApexCursor())
      .withEmailInvocations(Limits.getLimitEmailInvocations())
      .withMobilePushApexCalls(Limits.getLimitMobilePushApexCalls())
      .withQueryLocatorRows(Limits.getLimitQueryLocatorRows())
      .withQueueableJobs(Limits.getLimitQueueableJobs())
      .build();
  }
  // Common test scenarios
  public static JobDescription__c createHighPriorityJobDescription() {
    return aJobDescription().priority(100).recurrent().buildAndInsert();
  }

  public static JobDescription__c createNormalPriorityJobDescription() {
    return aJobDescription().priority(10).nonRecurrent().buildAndInsert();
  }

  public static JobDescription__c createDisabledJobDescription() {
    return aJobDescription().disabled().buildAndInsert();
  }

  public static JobRequest__c createReadyJobRequest(final JobDescription__c jobDescription) {
    return aJobRequest().ready().readyNow().withJobDescription(jobDescription).buildAndInsert();
  }

  public static List<JobRequest__c> createJobRequestsWithDescription(final Integer count) {
    final JobDescription__c jobDescription = createNormalPriorityJobDescription();
    final List<JobRequest__c> requests = new List<JobRequest__c>();
    for (Integer i = 0; i < count; i++) {
      requests.add(aJobRequest().withName('TestJob_' + i).ready().readyNow().withJobDescription(jobDescription).build());
    }
    insert requests;
    return requests;
  }
}
