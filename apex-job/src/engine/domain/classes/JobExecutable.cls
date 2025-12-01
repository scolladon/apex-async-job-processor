public without sharing class JobExecutable {
  private final LimitService limitService;
  private Datetime selectionTime;
  private Datetime endTime;
  public final JobDescription__c jobDescription { get; private set; }
  public final List<JobRequest__c> jobRequests { get; private set; }

  public JobExecutable(final List<JobRequest__c> jobRequests) {
    this(new ApexJobFactoryImpl().getLimitService(), jobRequests);
  }

  @TestVisible
  private JobExecutable(final LimitService limitService, final List<JobRequest__c> jobRequests) {
    this.limitService = limitService;
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
    return new JobExecuted(this, apexJobResult);
  }

  // TODO Part of the JobDescription domain
  private static ApexJob getProcessor(final JobDescription__c jobDescription) {
    return (ApexJob) Type.forName(jobDescription.ProcessorName__c).newInstance();
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
