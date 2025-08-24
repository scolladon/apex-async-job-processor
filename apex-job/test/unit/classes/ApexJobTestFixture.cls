@isTest
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
        MaxChunkSize__c = -1,
        MaxExecutionAttempt__c = -1,
        MinJobInterval__c = 0,
        isHighPriority__c = false,
        isRecurrent__c = false,
        CpuTimeConsumption__c = -1,
        HeapSizeConsumption__c = -1,
        CalloutConsumption__c = -1,
        CalloutTimeConsumption__c = -1,
        PublishImmediateDmlConsumption__c = -1,
        DmlRowsConsumption__c = -1,
        DmlStatementsConsumption__c = -1,
        QueryRowsConsumption__c = -1,
        QueriesConsumption__c = -1,
        SoslQueriesConsumption__c = -1,
        FutureCallsConsumption__c = -1
      );
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

    public JobDescriptionBuilder withMaxExecutionAttempt(final Integer maxAttempt) {
      this.record.MaxExecutionAttempt__c = maxAttempt;
      return this;
    }

    public JobDescriptionBuilder withMinJobInterval(final Integer minutes) {
      this.record.MinJobInterval__c = minutes;
      return this;
    }

    public JobDescriptionBuilder highPriority() {
      this.record.isHighPriority__c = true;
      return this;
    }

    public JobDescriptionBuilder normalPriority() {
      this.record.isHighPriority__c = false;
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
      this.record.CpuTimeConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withHeapSizeConsumption(final Integer value) {
      this.record.HeapSizeConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutConsumption(final Integer value) {
      this.record.CalloutConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withCalloutTimeConsumption(final Integer value) {
      this.record.CalloutTimeConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlRowsConsumption(final Integer value) {
      this.record.DmlRowsConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withDmlStatementsConsumption(final Integer value) {
      this.record.DmlStatementsConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueryRowsConsumption(final Integer value) {
      this.record.QueryRowsConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withQueriesConsumption(final Integer value) {
      this.record.QueriesConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withPublishImmediateDmlConsumption(final Integer value) {
      this.record.PublishImmediateDmlConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withSoslQueriesConsumption(final Integer value) {
      this.record.SoslQueriesConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withFutureCallsConsumption(final Integer value) {
      this.record.FutureCallsConsumption__c = value;
      return this;
    }

    public JobDescriptionBuilder withAllConsumptions(final Integer cpuTime, final Integer heapSize, final Integer queries) {
      this.record.CpuTimeConsumption__c = cpuTime;
      this.record.HeapSizeConsumption__c = heapSize;
      this.record.QueriesConsumption__c = queries;
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

  // Common test scenarios
  public static JobDescription__c createHighPriorityJobDescription() {
    return aJobDescription().highPriority().recurrent().buildAndInsert();
  }

  public static JobDescription__c createNormalPriorityJobDescription() {
    return aJobDescription().normalPriority().nonRecurrent().buildAndInsert();
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
