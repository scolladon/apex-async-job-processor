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
    final JobRequestArgumentParser parser = this.factory.getArgumentParser();
    final JobRequestArgumentParser.ParseResult parsed = parser.parse(this.jobRequests);

    this.limitService.startSnapshot();
    ApexJobResult apexJobResult;
    if (parsed.validArguments.isEmpty() && !parsed.malformedErrors.isEmpty()) {
      apexJobResult = new ApexJobResult(ApexJobStatus.MALFORMED_ARGUMENT);
    } else {
      final ApexJob jobProcessor = JobExecutable.getProcessor(this.jobDescription);
      try {
        apexJobResult = jobProcessor.execute(new ApexJobContext(parsed.validArguments));
      } catch (final Exception ex) {
        apexJobResult = new ApexJobResult(ex);
      }
    }
    apexJobResult.consumedLimits = this.limitService.stopSnapshot();
    apexJobResult.malformedRequestErrors = parsed.malformedErrors;
    this.endTime = System.now();

    ApexJobTransactionContext.getInstance().markExecutedJobs();
    return new JobExecuted(this.factory, this, apexJobResult);
  }

  private static ApexJob getProcessor(final JobDescription__c jobDescription) {
    final String processorName = jobDescription.ProcessorName__c;
    final Type processorType = Type.forName(processorName);
    if (processorType == null) {
      throw new IllegalArgumentException('Processor class not found: ' + processorName);
    }
    return (ApexJob) processorType.newInstance();
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
