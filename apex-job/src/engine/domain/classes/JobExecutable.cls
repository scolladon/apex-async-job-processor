public without sharing class JobExecutable {
  private final LimitService limitService;
  private final ApexJobFactory factory;
  private Datetime selectionTime;
  private Datetime endTime;
  public final JobDescription__c jobDescription { get; private set; }
  public final List<JobRequest__c> jobRequests { get; private set; }

  public JobExecutable(final ApexJobFactory factory, final List<JobRequest__c> jobRequests) {
    this.factory = factory;
    this.limitService = factory.getLimitService();
    this.jobDescription = jobRequests[0].JobDescription__r;
    this.jobRequests = jobRequests;
    this.selectionTime = System.now();
  }

  public JobExecuted executeChunk() {
    final ApexJob jobProcessor = JobExecutable.getProcessor(this.jobDescription);
    final ApexJobContext jobContext = JobExecutable.getContextArguments(this.jobRequests);

    // Execute the job
    this.limitService.startSnapshot();
    ApexJobResult apexJobResult;
    try {
      apexJobResult = jobProcessor.execute(jobContext);
    } catch (final Exception ex) {
      apexJobResult = new ApexJobResult(ex);
    }
    apexJobResult.consumedLimits = this.limitService.stopSnapshot();
    this.endTime = System.now();

    ApexJobTransactionContext.getInstance().markExecutedJobs();
    return new JobExecuted(this.factory, this, apexJobResult);
  }

  // TODO Part of the JobDescription domain
  private static ApexJob getProcessor(final JobDescription__c jobDescription) {
    final String processorName = jobDescription.ProcessorName__c;
    final Type processorType = Type.forName(processorName);
    if (processorType == null) {
      throw new IllegalArgumentException('Processor class not found: ' + processorName);
    }
    return (ApexJob) processorType.newInstance();
  }

  @TestVisible
  private static ApexJobContext getContextArguments(final List<JobRequest__c> jobRequests) {
    final List<Object> argumentsChunkToProcess = new List<Object>();
    final Integer jobRequestsSize = jobRequests.size();
    for (Integer i = 0; i < jobRequestsSize; ++i) {
      final JobRequest__c job = jobRequests[i];
      final Object argument = JobExecutable.getArgument(job);
      argumentsChunkToProcess.add(argument);
    }
    return new ApexJobContext(argumentsChunkToProcess);
  }

  // TODO Part of the JobRequest__c domain
  private static Object getArgument(final JobRequest__c job) {
    return String.isNotBlank(job.Argument__c) ? JSON.deserializeUntyped(job.Argument__c) : null;
  }

  public Datetime getSelectionTime() {
    return this.selectionTime;
  }

  public Datetime getEndTime() {
    if (this.endTime == null) {
      this.endTime = System.now();
    }
    return this.endTime;
  }
}
