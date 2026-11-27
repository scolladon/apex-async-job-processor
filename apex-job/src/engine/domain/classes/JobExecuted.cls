public with sharing class JobExecuted {
  private static final List<ApexJobStatus> RETRYABLE_STATUS = new List<ApexJobStatus>{ ApexJobStatus.FAILURE, ApexJobStatus.KILLED };
  private static final String MAX_EXECUTION_ATTEMPT_REACHED = 'Max execution attempt reached';
  private static final Integer MAX_EXECUTION_ATTEMPT_NUMBER = 9999999;
  private static final Integer MAX_LONG_TEXT_LENGTH = 131072;
  private static final String ROLLBACK_TRACE_FORMAT = 'Rolled back: AsyncApexJob {0} failed with {1}: {2}. Callouts made: {3}. Immediate events published: {4}. The chunk will run again.';
  private static final String CHUNK_DESCRIPTION_FORMAT = '{0} ({1}): {2}';
  private static final String REQUEST_ID_SEPARATOR = ', ';

  @TestVisible
  private final ApexJobResult jobExecutionResult;
  private final ApexJobFactory factory;
  private final JobRequestExecutionStagingInfo stagingInfo;
  private final RequestStaging requestStaging;
  private final String rollbackTrace;
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
    this.rollbackTrace = null;
    this.requestStaging = new CompletedRunStaging();
  }

  private JobExecuted(final JobExecuted completed, final String rollbackTrace) {
    this.factory = completed.factory;
    this.executable = completed.executable;
    this.jobDescription = completed.jobDescription;
    this.jobRequests = completed.jobRequests;
    this.jobExecutionResult = completed.jobExecutionResult;
    this.stagingInfo = completed.stagingInfo;
    this.rollbackTrace = rollbackTrace;
    this.requestStaging = new RollbackTraceStaging(rollbackTrace);
  }

  public JobExecuted rolledBackBy(final Id failedAsyncJobId, final RollbackCause cause) {
    final LimitsUsage consumed = this.jobExecutionResult.consumedLimits;
    final String trace = String.format(ROLLBACK_TRACE_FORMAT, new List<Object>{ failedAsyncJobId, cause.typeName, cause.message, consumed.callout, consumed.publishImmediateDml });
    return new JobExecuted(this, trace.left(MAX_LONG_TEXT_LENGTH));
  }

  public String describeRollback() {
    return String.format(CHUNK_DESCRIPTION_FORMAT, new List<Object>{ this.jobDescription.Name, this.joinRequestIds(), this.rollbackTrace });
  }

  public String describeExecution() {
    return String.format(CHUNK_DESCRIPTION_FORMAT, new List<Object>{ this.jobDescription.Name, this.joinRequestIds(), this.jobExecutionResult.status.name() });
  }

  public void stageExecution() {
    this.requestStaging.stage(this);
    this.stageJobDescriptionExecution();
  }

  private String joinRequestIds() {
    final List<String> ids = new List<String>();
    for (JobRequest__c job : this.jobRequests) {
      ids.add(String.valueOf(job.Id));
    }
    return String.join(ids, REQUEST_ID_SEPARATOR);
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
    final Datetime baseRef = job.NextExecutionDateTime__c;
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
      consumptionLearner.adjustFromKill(this.jobRequests.size(), this.stagingInfo.endTime);
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
      this.candidateAbortable = this.candidateStatusRetryable && description.MaxExecutionAttempt__c != ApexJobConstant.UNLIMITED_EXECUTION_ATTEMPTS;
      this.recurrentCandidate = description.isRecurrent__c == true;

      final String rawErrorMessage = result.error?.toString() ?? '';
      this.errorMessage = rawErrorMessage.left(MAX_LONG_TEXT_LENGTH);
    }
  }

  public class RollbackCause {
    public final String typeName { get; private set; }
    public final String message { get; private set; }

    public RollbackCause(final Exception cause) {
      this.typeName = cause.getTypeName();
      this.message = cause.getMessage();
    }
  }

  private interface RequestStaging {
    void stage(JobExecuted executed);
  }

  private class CompletedRunStaging implements RequestStaging {
    public void stage(final JobExecuted executed) {
      executed.stageJobRequestsChunkExecution();
    }
  }

  private class RollbackTraceStaging implements RequestStaging {
    private final String trace;

    public RollbackTraceStaging(final String trace) {
      this.trace = trace;
    }

    public void stage(final JobExecuted executed) {
      for (JobRequest__c job : executed.jobRequests) {
        job.LastExecutionMessage__c = this.trace;
      }
    }
  }
}
