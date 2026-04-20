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
  public final JobExecutable executable { get; private set; }

  public JobExecuted(final ApexJobFactory factory, final JobExecutable jobExecutable, final ApexJobResult jobExecutionResult) {
    this.factory = factory;
    this.executable = jobExecutable;
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
    if (this.isMalformed(job)) {
      this.stageMalformedJobRequest(job);
      return;
    }
    this.calculateTimingMetrics(job);
    this.determineNextStatus(job);
  }

  private Boolean isMalformed(final JobRequest__c job) {
    return this.jobExecutionResult.malformedRequestErrors != null && this.jobExecutionResult.malformedRequestErrors.containsKey(job.Id);
  }

  private void stageMalformedJobRequest(final JobRequest__c job) {
    job.Status__c = ApexJobStatus.MALFORMED_ARGUMENT.name();
    job.LastExecutionMessage__c = this.jobExecutionResult.malformedRequestErrors.get(job.Id);
    job.NextExecutionDateTime__c = null;
    job.AttemptNumber__c = Math.min((job.AttemptNumber__c ?? 0) + 1, MAX_EXECUTION_ATTEMPT_NUMBER);
    job.LastSelectionDateTime__c = this.stagingInfo.selectionTime;
    job.LastExecutionDateTime__c = this.stagingInfo.endTime;
  }

  private void calculateTimingMetrics(final JobRequest__c job) {
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
  }

  private void determineNextStatus(final JobRequest__c job) {
    if (this.stagingInfo.candidateAbortable && job.AttemptNumber__c >= this.jobDescription.MaxExecutionAttempt__c) {
      job.Status__c = ApexJobStatus.ABORTED.name();
      job.NextExecutionDateTime__c = null;
      job.LastExecutionMessage__c = this.formatAbortMessage();
    } else if (this.stagingInfo.candidateStatusRetryable) {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = this.stagingInfo.nextTry;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
    } else if (this.stagingInfo.recurrentCandidate) {
      job.Status__c = ApexJobStatus.READY.name();
      job.NextExecutionDateTime__c = this.stagingInfo.nextTry;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
    } else {
      job.Status__c = this.jobExecutionResult.status.name();
      job.NextExecutionDateTime__c = null;
      job.LastExecutionMessage__c = this.stagingInfo.errorMessage;
    }
  }

  private String formatAbortMessage() {
    final List<String> parts = new List<String>{ MAX_EXECUTION_ATTEMPT_REACHED };
    if (String.isNotBlank(this.stagingInfo.errorMessage)) {
      parts.add(this.stagingInfo.errorMessage);
    }
    return String.join(parts, '\n').left(MAX_LONG_TEXT_LENGTH);
  }

  private void stageJobDescriptionExecution() {
    this.jobDescription.LastExecutionDateTime__c = this.stagingInfo.endTime;
    this.updateRateLimitCounter();
    if (this.jobExecutionResult.status == ApexJobStatus.MALFORMED_ARGUMENT) {
      return;
    }
    final ConsumptionLearner consumptionLearner = this.factory.getConsumptionLearner(this.jobDescription);
    if (this.jobExecutionResult.status == ApexJobStatus.FAILURE || this.jobExecutionResult.status == ApexJobStatus.ABORTED) {
      consumptionLearner.adjustFromFailure(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.SUCCESS) {
      consumptionLearner.adjustFromSuccess(this.jobExecutionResult.consumedLimits, this.jobRequests.size());
    } else if (this.jobExecutionResult.status == ApexJobStatus.KILLED) {
      consumptionLearner.adjustFromKill(this.jobRequests.size());
    }
  }

  private void updateRateLimitCounter() {
    final Integer maxPerMinute = this.jobDescription.MaxExecutionsPerMinute__c?.intValue() ?? 0;
    if (maxPerMinute <= 0) {
      return;
    }
    final Datetime windowStart = this.jobDescription.CurrentWindowStart__c;
    final Integer chunkSize = this.jobRequests.size();
    if (windowStart == null || this.stagingInfo.endTime.getTime() - windowStart.getTime() >= ApexJobConstant.RATE_WINDOW_MS) {
      this.jobDescription.CurrentWindowStart__c = this.stagingInfo.endTime;
      this.jobDescription.ExecutionsInCurrentWindow__c = chunkSize;
    } else {
      this.jobDescription.ExecutionsInCurrentWindow__c = (this.jobDescription.ExecutionsInCurrentWindow__c ?? 0) + chunkSize;
    }
  }

  private class JobRequestExecutionStagingInfo {
    public final Datetime selectionTime { get; private set; }
    public final Datetime endTime { get; private set; }
    public final Boolean candidateStatusRetryable { get; private set; }
    public final Boolean candidateAbortable { get; private set; }
    public final String errorMessage { get; private set; }
    public final Datetime nextTry { get; private set; }
    public final Boolean recurrentCandidate { get; private set; }

    public JobRequestExecutionStagingInfo(final JobExecutable executable, final ApexJobResult result, final JobDescription__c description) {
      this.endTime = executable.getEndTime();
      this.selectionTime = executable.getSelectionTime();
      final Integer minutes = (Integer) description.MinJobInterval__c ?? 0;
      this.nextTry = this.endTime.addMinutes(minutes);

      this.candidateStatusRetryable = RETRYABLE_STATUS.contains(result.status);
      this.candidateAbortable = this.candidateStatusRetryable && description.MaxExecutionAttempt__c != -1;
      this.recurrentCandidate = description.isRecurrent__c == true;

      final String rawErrorMessage = result.error?.toString() ?? '';
      this.errorMessage = rawErrorMessage.left(MAX_LONG_TEXT_LENGTH);
    }
  }
}
