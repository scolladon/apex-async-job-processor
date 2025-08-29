@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobManager {
  private static ApexJobRepository repository = new ApexJobManager.DefaultApexJobRepository();
  public interface ApexJobRepository {
    JobRequest__c insertJobRequest(final JobRequest__c jobRequest);
    JobRequest__c updateJobRequest(final JobRequest__c jobRequest);

    JobDescription__c insertJobDescription(final JobDescription__c jobDescription);
    JobDescription__c updateJobDescription(final JobDescription__c jobDescription);
    JobDescription__c upsertJobDescriptionByProcessorName(final JobDescription__c jobDescription);
  }

  private with sharing class DefaultApexJobRepository implements ApexJobRepository {
    public JobRequest__c insertJobRequest(final JobRequest__c jobRequest) {
      insert jobRequest;
      return jobRequest;
    }

    public JobRequest__c updateJobRequest(final JobRequest__c jobRequest) {
      update jobRequest;
      return jobRequest;
    }

    public JobDescription__c insertJobDescription(final JobDescription__c jobDescription) {
      insert jobDescription;
      return jobDescription;
    }

    public JobDescription__c updateJobDescription(final JobDescription__c jobDescription) {
      update jobDescription;
      return jobDescription;
    }

    public JobDescription__c upsertJobDescriptionByProcessorName(final JobDescription__c jobDescription) {
      upsert jobDescription ProcessorName__c;
      return jobDescription;
    }
  }

  @TestVisible
  static void setRepository(final ApexJobRepository repo) {
    ApexJobManager.repository = repo;
  }
  public static void disableJobRequest(final Id jobRequestId) {
    final JobRequest__c jobRequest = new JobRequest__c(Id = jobRequestId, Enabled__c = false);
    repository.updateJobRequest(jobRequest);
  }

  public static void disableJobDescription(final Id jobDescriptionId) {
    final JobDescription__c jobDescription = new JobDescription__c(Id = jobDescriptionId, Enabled__c = false);
    repository.updateJobDescription(jobDescription);
  }

  public static void disableJobDescription(final String processorName) {
    final JobDescription__c jobDescription = new JobDescription__c(ProcessorName__c = processorName, Enabled__c = false);
    repository.upsertJobDescriptionByProcessorName(jobDescription);
  }

  public static void enableJobRequest(final Id jobRequestId) {
    final JobRequest__c jobRequest = new JobRequest__c(Id = jobRequestId, Enabled__c = true);
    repository.updateJobRequest(jobRequest);
  }

  public static void enableJobDescription(final Id jobDescriptionId) {
    final JobDescription__c jobDescription = new JobDescription__c(Id = jobDescriptionId, Enabled__c = true);
    repository.updateJobDescription(jobDescription);
  }

  public static void enableJobDescription(final String processorName) {
    final JobDescription__c jobDescription = new JobDescription__c(ProcessorName__c = processorName, Enabled__c = true);
    repository.upsertJobDescriptionByProcessorName(jobDescription);
  }

  public static JobRequestBuilder request() {
    return new JobRequestBuilder();
  }

  public static JobDescriptionBuilder define() {
    return new JobDescriptionBuilder();
  }

  public class JobRequestBuilder {
    private JobRequest__c jobRequest;

    public JobRequestBuilder() {
      this.jobRequest = new JobRequest__c();
      this.jobRequest.Status__c = ApexJobStatus.READY.name();
      this.jobRequest.Enabled__c = true;
    }

    public JobRequestBuilder forDescription(final Id jobDescriptionId) {
      this.jobRequest.JobDescription__c = jobDescriptionId;
      return this;
    }

    public JobRequestBuilder forProcessor(final String processorName) {
      this.jobRequest.JobDescription__r = new JobDescription__c(ProcessorName__c = processorName);
      return this;
    }

    public JobRequestBuilder scheduleAt(final Datetime scheduledDateTime) {
      this.jobRequest.NextExecutionDateTime__c = scheduledDateTime;
      return this;
    }

    public JobRequestBuilder payload(final Object argument) {
      this.jobRequest.Argument__c = JSON.serialize(argument);
      return this;
    }

    public JobRequestBuilder payloadJson(final String argumentJson) {
      this.jobRequest.Argument__c = argumentJson;
      return this;
    }

    public JobRequest__c save() {
      repository.insertJobRequest(this.jobRequest);
      return this.jobRequest;
    }

    @TestVisible
    private JobRequest__c toSObject() {
      return this.jobRequest;
    }
  }

  public static void resetUsage(final String processorName) {
    final JobDescription__c jobDescription = new JobDescription__c(
      ProcessorName__c = processorName,
      MaxChunkSize__c = -1,
      CpuTimeBaseConsumption__c = -1,
      CpuTimePerItemConsumption__c = -1,
      CpuTimeSafety__c = 1,
      HeapSizeBaseConsumption__c = -1,
      HeapSizePerItemConsumption__c = -1,
      HeapSizeSafety__c = 1,
      CalloutBaseConsumption__c = -1,
      CalloutPerItemConsumption__c = -1,
      CalloutSafety__c = 1,
      CalloutTimeBaseConsumption__c = -1,
      CalloutTimePerItemConsumption__c = -1,
      CalloutTimeSafety__c = 1,
      DmlRowsBaseConsumption__c = -1,
      DmlRowsPerItemConsumption__c = -1,
      DmlRowsSafety__c = 1,
      DmlStatementsBaseConsumption__c = -1,
      DmlStatementsPerItemConsumption__c = -1,
      DmlStatementsSafety__c = 1,
      FutureCallsBaseConsumption__c = -1,
      FutureCallsPerItemConsumption__c = -1,
      FutureCallsSafety__c = 1,
      PublishImmediateDmlBaseConsumption__c = -1,
      PublishImmediateDmlPerItemConsumption__c = -1,
      PublishImmediateDmlSafety__c = 1,
      QueryRowsBaseConsumption__c = -1,
      QueryRowsPerItemConsumption__c = -1,
      QueryRowsSafety__c = 1,
      QueriesBaseConsumption__c = -1,
      QueriesPerItemConsumption__c = -1,
      QueriesSafety__c = 1,
      SoslQueriesBaseConsumption__c = -1,
      SoslQueriesPerItemConsumption__c = -1,
      SoslQueriesSafety__c = 1
    );
    repository.upsertJobDescriptionByProcessorName(jobDescription);
  }

  public class JobDescriptionBuilder {
    private JobDescription__c jobDescription;

    public JobDescriptionBuilder() {
      this.jobDescription = new JobDescription__c();
      this.jobDescription.Enabled__c = true;
    }

    public JobDescriptionBuilder priority(final Integer priority) {
      this.jobDescription.Priority__c = priority;
      return this;
    }

    public JobDescriptionBuilder recurrent() {
      this.jobDescription.isRecurrent__c = true;
      return this;
    }

    public JobDescriptionBuilder allowedOn(final List<String> allowedDays) {
      this.jobDescription.AllowedDays__c = String.join(allowedDays, ';');
      return this;
    }

    public JobDescriptionBuilder allowedBetween(final Time allowedStartTime, final Time allowedEndTime) {
      this.jobDescription.AllowedStartTime__c = allowedStartTime;
      this.jobDescription.AllowedEndTime__c = allowedEndTime;
      return this;
    }

    public JobDescriptionBuilder maxAttempts(final Integer maxExecutionAttempt) {
      this.jobDescription.MaxExecutionAttempt__c = maxExecutionAttempt;
      return this;
    }

    public JobDescriptionBuilder minInterval(final Integer minJobInterval) {
      this.jobDescription.MinJobInterval__c = minJobInterval;
      return this;
    }

    public JobDescriptionBuilder processor(final String processorName) {
      this.jobDescription.ProcessorName__c = processorName;
      return this;
    }

    public JobDescription__c save() {
      repository.insertJobDescription(this.jobDescription);
      return this.jobDescription;
    }

    @TestVisible
    private JobDescription__c toSObject() {
      return this.jobDescription;
    }
  }
}
