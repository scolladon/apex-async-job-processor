public with sharing class JobExecuted {
  private static final List<ApexJobStatus> RETRYABLE_STATUS = new List<ApexJobStatus>{ ApexJobStatus.FAILURE, ApexJobStatus.KILLED };
  private static final String MAX_EXECUTION_ATTEMPT_REACHED = 'Max execution attempt reached';
  private static final Integer MAX_EXECUTION_ATTEMPT_NUMBER = 9999999;
  private static final Integer MAX_LONG_TEXT_LENGTH = 131072;

  @TestVisible
  private final ApexJobResult jobExecutionResult;
  private final ApexJobFactory factory;
  public final JobDescription__c jobDescription { get; private set; }
  public final List<JobRequest__c> jobRequests { get; private set; }

  public JobExecuted(final JobExecutable jobExecutable, final ApexJobResult jobExecutionResult) {
    this(new ApexJobFactoryImpl(), jobExecutable, jobExecutionResult);
  }

  @TestVisible
  private JobExecuted(final ApexJobFactory factory, final JobExecutable jobExecutable, final ApexJobResult jobExecutionResult) {
    this.factory = factory;
    this.jobDescription = jobExecutable.jobDescription;
    this.jobRequests = jobExecutable.jobRequests;
    this.jobExecutionResult = jobExecutionResult;
  }

  public void stageExecution() {
    this.stageJobRequestsChunkExecution();
    this.stageJobDescriptionExecution();
  }

  private void stageJobRequestsChunkExecution() {
    final Integer jobChunkNumber = this.jobRequests.size();
    final JobRequestExecutionStagingInfo stagingInfo = new JobRequestExecutionStagingInfo(this.jobExecutionResult, this.jobDescription);
    for (Integer i = 0; i < jobChunkNumber; ++i) {
      this.stageJobRequestExecution(this.jobRequests[i], stagingInfo);
    }
  }

  private void stageJobRequestExecution(final JobRequest__c job, final JobRequestExecutionStagingInfo stagingInfo) {
    job.LastExecutionDateTime__c = stagingInfo.executionTimestamp;
    job.AttemptNumber__c = Math.min((job.AttemptNumber__c ?? 0) + 1, MAX_EXECUTION_ATTEMPT_NUMBER);
    // Should abort
    if (stagingInfo.candidateAbortable && job.AttemptNumber__c >= this.jobDescription.MaxExecutionAttempt__c) {
      job.Status__c = ApexJobStatus.ABORTED.name();
      job.NextExecutionDateTime__c = null;
      List<String> lastExecutionMessage = new List<String>{ MAX_EXECUTION_ATTEMPT_REACHED };
      if (String.isNotBlank(stagingInfo.errorMessage)) {
        lastExecutionMessage.add(stagingInfo.errorMessage);
      }
      job.LastExecutionMessage__c = String.join(lastExecutionMessage, '\n').left(MAX_LONG_TEXT_LENGTH);
      // Failure or Killed
    } else if (stagingInfo.candidateStatusRetryable) {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = stagingInfo.nextTry;
      job.LastExecutionMessage__c = stagingInfo.errorMessage;
      // Recurrent candidat
    } else if (stagingInfo.recurrentCandidat) {
      job.Status__c = ApexJobStatus.READY.name();
      job.NextExecutionDateTime__c = stagingInfo.nextTry;
      job.LastExecutionMessage__c = stagingInfo.errorMessage;
      // Abort or Success
    } else {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = null;
      job.LastExecutionMessage__c = stagingInfo.errorMessage;
    }
  }

  private void stageJobDescriptionExecution() {
    final ConsumptionLearner consumptionLearner = this.factory.getConsumptionLearner(this.jobDescription);
    this.jobDescription.LastExecutionDateTime__c = System.now();
    if (this.jobExecutionResult.status == ApexJobStatus.FAILURE || this.jobExecutionResult.status == ApexJobStatus.ABORTED) {
      consumptionLearner.adjustFromFailure(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.SUCCESS) {
      consumptionLearner.adjustFromSuccess(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.KILLED) {
      consumptionLearner.adjustFromKill(this.jobRequests.size());
    }
  }

  private class JobRequestExecutionStagingInfo {
    public final Datetime executionTimestamp { get; private set; }
    public final Boolean candidateStatusRetryable { get; private set; }
    public final Boolean candidateAbortable { get; private set; }
    public final String errorMessage { get; private set; }
    public final Datetime nextTry { get; private set; }
    public final Boolean recurrentCandidat { get; private set; }

    public JobRequestExecutionStagingInfo(final ApexJobResult result, final JobDescription__c description) {
      this.executionTimestamp = System.now();
      this.candidateStatusRetryable = RETRYABLE_STATUS.contains(result.status);
      this.candidateAbortable = this.candidateStatusRetryable && description.MaxExecutionAttempt__c != -1;
      this.errorMessage = (result.error?.toString() ?? '').left(MAX_LONG_TEXT_LENGTH);
      final Integer minutes = (Integer) description.MinJobInterval__c ?? 0;
      this.nextTry = this.executionTimestamp.addMinutes(minutes);
      this.recurrentCandidat = description.isRecurrent__c == true;
    }
  }
}
