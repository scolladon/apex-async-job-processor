public with sharing class JobExecuted {
  private static final List<ApexJobStatus> RETRYABLE_STATUS = new List<ApexJobStatus>{ ApexJobStatus.FAILURE, ApexJobStatus.KILLED };
  private static final String MAX_EXECUTION_ATTEMPT_REACHED = 'Max execution attempt reached';
  private static final Integer MAX_EXECUTION_ATTEMPT_NUMBER = 9999999;
  private static final Integer MAX_LONG_TEXT_LENGTH = 131072;

  @TestVisible
  private final ApexJobResult jobExecutionResult;
  private final ApexJobFactory factory;
  private final JobRequestExecutionStagingInfo stagingInfo;
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
    this.stagingInfo = new JobRequestExecutionStagingInfo(jobExecutable, jobExecutionResult, this.jobDescription);
  }

  public void stageExecution() {
    this.stageJobRequestsChunkExecution();
    this.stageJobDescriptionExecution();
  }

  private void stageJobRequestsChunkExecution() {
    final Integer jobChunkNumber = this.jobRequests.size();
    for (Integer i = 0; i < jobChunkNumber; ++i) {
      this.stageJobRequestExecution(this.jobRequests[i]);
    }
  }

  private void stageJobRequestExecution(final JobRequest__c job) {
    // Capture base reference before any NextExecutionDateTime__c change
    final Datetime baseRef = job.NextExecutionDateTime__c ?? job.CreatedDate;
    final Long baseMs = baseRef.getTime();
    final Long selectionMs = this.stagingInfo.selectionTime.getTime();
    final Long endMs = this.stagingInfo.endTime.getTime();
    job.WaitTime__c = selectionMs - baseMs;
    job.ChunkRunTime__c = endMs - selectionMs;
    job.UnitRunTime__c = job.ChunkRunTime__c / this.jobRequests.size();
    job.ProcessingTime__c = endMs - baseMs;
    job.AttemptNumber__c = Math.min((job.AttemptNumber__c ?? 0) + 1, MAX_EXECUTION_ATTEMPT_NUMBER);
    job.LastSelectionDateTime__c = this.stagingInfo.selectionTime;
    job.LastExecutionDateTime__c = this.stagingInfo.endTime;
    // Should abort
    if (this.stagingInfo.candidateAbortable && job.AttemptNumber__c >= this.jobDescription.MaxExecutionAttempt__c) {
      job.Status__c = ApexJobStatus.ABORTED.name();
      job.NextExecutionDateTime__c = null;
      List<String> lastExecutionMessage = new List<String>{ MAX_EXECUTION_ATTEMPT_REACHED };
      if (String.isNotBlank(this.stagingInfo.errorMessage)) {
        lastExecutionMessage.add(this.stagingInfo.errorMessage);
      }
      job.LastExecutionMessage__c = String.join(lastExecutionMessage, '\n').left(MAX_LONG_TEXT_LENGTH);
      // Failure or Killed
    } else if (this.stagingInfo.candidateStatusRetryable) {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = this.stagingInfo.nextTry;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
      // Recurrent candidat
    } else if (this.stagingInfo.recurrentCandidat) {
      job.Status__c = ApexJobStatus.READY.name();
      job.NextExecutionDateTime__c = this.stagingInfo.nextTry;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
      // Abort or Success
    } else {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = null;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
    }
  }

  private void stageJobDescriptionExecution() {
    final ConsumptionLearner consumptionLearner = this.factory.getConsumptionLearner(this.jobDescription);
    this.jobDescription.LastExecutionDateTime__c = this.stagingInfo.endTime;
    if (this.jobExecutionResult.status == ApexJobStatus.FAILURE || this.jobExecutionResult.status == ApexJobStatus.ABORTED) {
      consumptionLearner.adjustFromFailure(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.SUCCESS) {
      consumptionLearner.adjustFromSuccess(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.KILLED) {
      consumptionLearner.adjustFromKill(this.jobRequests.size());
    }
  }

  private class JobRequestExecutionStagingInfo {
    public final Datetime selectionTime { get; private set; }
    public final Datetime endTime { get; private set; }
    public final Boolean candidateStatusRetryable { get; private set; }
    public final Boolean candidateAbortable { get; private set; }
    public final String errorMessage { get; private set; }
    public final Datetime nextTry { get; private set; }
    public final Boolean recurrentCandidat { get; private set; }

    public JobRequestExecutionStagingInfo(final JobExecutable executable, final ApexJobResult result, final JobDescription__c description) {
      this.endTime = executable.getEndTime();
      this.selectionTime = executable.getSelectionTime();
      final Integer minutes = (Integer) description.MinJobInterval__c ?? 0;
      this.nextTry = this.endTime.addMinutes(minutes);

      this.candidateStatusRetryable = RETRYABLE_STATUS.contains(result.status);
      this.candidateAbortable = this.candidateStatusRetryable && description.MaxExecutionAttempt__c != -1;
      this.recurrentCandidat = description.isRecurrent__c == true;

      final String rawErrorMessage = result.error?.toString() ?? '';
      this.errorMessage = rawErrorMessage.left(MAX_LONG_TEXT_LENGTH);
    }
  }
}
