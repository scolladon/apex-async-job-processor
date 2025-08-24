public without sharing class AsyncApexJobExecutor implements Finalizer, Queueable, Database.AllowsCallouts {
  private ApexJobConfigService configService;
  private ApexJobLogger logger;
  private ApexJobFactory factory;

  @TestVisible
  private List<JobExecuted> jobExecutionResults = new List<JobExecuted>();
  public AsyncApexJobExecutor() {
    this(new ApexJobFactoryImpl());
  }

  @testVisible
  private AsyncApexJobExecutor(final ApexJobFactory factory) {
    this.factory = factory;
    this.logger = this.factory.getLogger();
    this.configService = this.factory.getConfigService();
  }

  public void execute(QueueableContext ctx) {
    final JobExecutorFinalizerAttacher finalizerAttacher = this.factory.getFinalizerAttacher();
    finalizerAttacher.attach(this);

    if (this.configService.isSystemEnabled() != true) {
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
      JobExecutable executableJob;
      for (Integer i = 0; i < jobCandidatesNumber; ++i) {
        final JobCandidate jobCandidate = jobCandidates[i];
        if (jobCandidate.isExecutable() == true) {
          executableJob = jobCandidate.getExecutableChunk();
          break;
        }
      }
      if (executableJob == null) {
        break;
      }
      final JobExecuted executionResult = executableJob.executeChunk();
      this.jobExecutionResults.add(executionResult);
      this.logger.debug('Job executed: ' + executionResult);
    }
  }

  public void execute(FinalizerContext ctx) {
    try {
      this.factory.getRepository().recordJobExecution(this.jobExecutionResults);
    } catch (Exception e) {
      this.logger.debug('AsyncJob: Error while recording job execution');
      this.logger.error(e.getMessage());
    }

    try {
      if (this.configService.isSystemEnabled() != true) {
        return;
      }
      Integer delayInMinutes = this.getDelayInMinutes();
      this.factory.getSpawner().enqueue(new AsyncApexJobExecutor(), delayInMinutes);
      this.logger.debug('Enqueued AsyncApexJobExecutor.execute() again in ' + delayInMinutes + ' minutes');
    } catch (Exception e) {
      this.logger.debug('AsyncJob: Error while enqueuing AsyncApexJobExecutor, engine killed');
      this.logger.error(e.getMessage());
    }
  }

  private Integer getDelayInMinutes() {
    if (this.jobExecutionResults.isEmpty()) {
      return this.configService.getEnqueueDelayInMinutes();
    }
    return 0;
  }
}
