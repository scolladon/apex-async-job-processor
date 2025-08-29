public class JobCandidate {
  private Integer calculatedChunkSize;
  private final JobDescription__c jobDescription;
  public final List<JobRequest__c> jobRequests;
  private final ChunkSizeCalculator chunkSizeCalculator;

  public JobCandidate(final List<JobRequest__c> jobRequests) {
    this(new ApexJobFactoryImpl().getChunkSizeCalculator(), jobRequests);
  }

  @TestVisible
  private JobCandidate(final ChunkSizeCalculator chunkSizeCalculator, final List<JobRequest__c> jobRequests) {
    this.jobRequests = jobRequests;
    this.jobDescription = jobRequests[0].JobDescription__r;
    this.chunkSizeCalculator = chunkSizeCalculator;
  }

  public Boolean isExecutable() {
    this.calculatedChunkSize = this.calculateChunkSize();
    return this.calculatedChunkSize > 0;
  }

  public JobExecutable getExecutableChunk() {
    final List<JobRequest__c> jobsChunk = new List<JobRequest__c>();
    for (Integer i = 0; i < this.calculatedChunkSize; ++i) {
      jobsChunk.add(this.jobRequests[i]);
    }
    return new JobExecutable(jobsChunk);
  }

  private Integer calculateChunkSize() {
    Integer chunkSize = this.jobDescription.MaxChunkSize__c.intValue();
    if (chunkSize == ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE) {
      return 1;
    }

    // Define max possible chunk size for current transaction
    chunkSize = this.chunkSizeCalculator.getMaxPossible(this.jobDescription);
    return Math.min(chunkSize, this.jobRequests.size());
  }
}
