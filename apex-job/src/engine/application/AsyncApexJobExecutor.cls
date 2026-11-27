public without sharing class AsyncApexJobExecutor implements Finalizer, Queueable, Database.AllowsCallouts {
  private static final String ROLLED_BACK_CHUNK_LOG_PREFIX = 'AsyncJob: chunk rolled back ';

  private ApexJobConfigService configService;
  private ApexJobLogger logger;
  private ApexJobFactory factory;

  @TestVisible
  private JobExecutable lastExecutableJob;
  @TestVisible
  private List<JobExecuted> jobExecutionResults = new List<JobExecuted>();
  public AsyncApexJobExecutor() {
    this(new ApexJobFactoryImpl());
  }

  @TestVisible
  private AsyncApexJobExecutor(final ApexJobFactory factory) {
    this.factory = factory;
    this.logger = this.factory.getLogger();
    this.configService = this.factory.getConfigService();
  }

  public void execute(QueueableContext queueableContext) {
    final JobExecutorFinalizerAttacher finalizerAttacher = this.factory.getFinalizerAttacher();
    finalizerAttacher.attach(this);

    try {
      this.runChunks(queueableContext);
    } finally {
      this.logger.flush();
    }
  }

  private void runChunks(final QueueableContext queueableContext) {
    if (this.cannotRun(queueableContext.getJobId())) {
      return;
    }

    final JobRepository jobRepository = this.factory.getRepository();

    // Infinite loop
    for (;;) {
      final JobCandidate[] jobCandidates = jobRepository.getJobCandidates(this.jobExecutionResults);
      final Integer jobCandidatesNumber = jobCandidates?.size() ?? 0;
      if (jobCandidatesNumber == 0) {
        break;
      }
      for (Integer i = 0; i < jobCandidatesNumber; ++i) {
        this.lastExecutableJob = jobCandidates[i].getExecutableChunk();
        if (this.lastExecutableJob != null) {
          break;
        }
      }
      if (this.lastExecutableJob == null) {
        break;
      }
      final JobExecuted executionResult = this.lastExecutableJob.executeChunk();
      this.jobExecutionResults.add(executionResult);
      this.logger.debug('Job executed: ' + executionResult);
    }
  }

  public void execute(FinalizerContext finalizerContext) {
    try {
      this.recordExecution(finalizerContext);
      this.reenqueue();
    } finally {
      this.logger.flush();
    }
  }

  private void recordExecution(final FinalizerContext finalizerContext) {
    try {
      if (finalizerContext?.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
        this.rollBackTransaction(finalizerContext);
      }
      this.factory.getRepository().recordJobExecution(this.jobExecutionResults, finalizerContext);
    } catch (Exception e) {
      this.logger.debug('AsyncJob: Error while recording job execution');
      this.logger.error(e.getMessage());
      this.logger.error(e.getStackTraceString());
      this.discardUnrecordedResults();
    }
  }

  private void reenqueue() {
    try {
      if (this.configService.isSystemEnabled() != true) {
        return;
      }
      Integer delayInMinutes = this.getDelayInMinutes();
      this.factory.getSpawner().enqueue(delayInMinutes);
      this.logger.debug('Enqueued AsyncApexJobExecutor.execute() again in ' + delayInMinutes + ' minutes');
    } catch (Exception e) {
      this.logger.debug('AsyncJob: Error while enqueuing AsyncApexJobExecutor, engine killed');
      this.logger.error(e.getMessage());
      this.logger.error(e.getStackTraceString());
    }
  }

  private void rollBackTransaction(final FinalizerContext finalizerContext) {
    final JobExecutable killedChunk = this.findKilledChunk();
    final List<JobExecuted> surviving = this.rollBackCompletedChunks(finalizerContext, killedChunk);
    if (killedChunk != null) {
      final ApexJobResult killedJobResult = new ApexJobResult(ApexJobStatus.KILLED, new ApexJobResult.ApexJobError(finalizerContext.getException()));
      surviving.add(new JobExecuted(this.factory, killedChunk, killedJobResult));
    }
    this.jobExecutionResults = surviving;
  }

  private List<JobExecuted> rollBackCompletedChunks(final FinalizerContext finalizerContext, final JobExecutable killedChunk) {
    final List<JobExecuted> rolledBack = new List<JobExecuted>();
    for (JobExecuted completed : this.jobExecutionResults) {
      if (completed.executable !== killedChunk) {
        rolledBack.add(this.rollBack(completed, finalizerContext));
      }
    }
    return rolledBack;
  }

  private JobExecuted rollBack(final JobExecuted completed, final FinalizerContext finalizerContext) {
    final JobExecuted rolledBack = completed.rolledBackBy(finalizerContext.getAsyncApexJobId(), new JobExecuted.RollbackCause(finalizerContext.getException()));
    this.logger.error(ROLLED_BACK_CHUNK_LOG_PREFIX + rolledBack.describeRollback());
    return rolledBack;
  }

  private JobExecutable findKilledChunk() {
    if (this.isChunkInFlight()) {
      return this.lastExecutableJob;
    }
    return this.lastCompletedChunk();
  }

  private Boolean isChunkInFlight() {
    if (this.lastExecutableJob == null) {
      return false;
    }
    if (this.jobExecutionResults.isEmpty()) {
      return true;
    }
    return this.lastCompletedChunk() !== this.lastExecutableJob;
  }

  private JobExecutable lastCompletedChunk() {
    if (this.jobExecutionResults.isEmpty()) {
      return null;
    }
    return this.jobExecutionResults[this.jobExecutionResults.size() - 1].executable;
  }

  private void discardUnrecordedResults() {
    this.jobExecutionResults.clear();
  }

  private Integer getDelayInMinutes() {
    if (this.jobExecutionResults.isEmpty()) {
      return this.configService.getEnqueueDelayInMinutes();
    }
    return 0;
  }

  private Boolean cannotRun(final Id jobExecutorToExclude) {
    return this.configService.isSystemEnabled() == false || this.factory.getExecutorService().isRunning(jobExecutorToExclude) == true;
  }
}
