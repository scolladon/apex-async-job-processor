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

  public static void resetConsumptionModel(final String processorName) {
    final JobDescription__c jobDescription = new JobDescription__c(ProcessorName__c = processorName);
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      jobDescription.put(model.base, ApexJobConstant.UNKNOWN_BASE_CONSUMPTION);
      jobDescription.put(model.perItem, ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION);
      jobDescription.put(model.safety, ApexJobConstant.UNKNOWN_SAFETY);
    }
    jobDescription.MaxChunkSize__c = ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE;
    jobDescription.ConsecutiveFailures__c = 0;
    jobDescription.SuccessStreak__c = 0;
    jobDescription.SmallestFailingChunk__c = 0;
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
