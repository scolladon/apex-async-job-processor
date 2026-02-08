public class JobCandidate {
  private final JobDescription__c jobDescription;
  public final List<JobRequest__c> jobRequests;
  private final ChunkSizeCalculator chunkSizeCalculator;
  private final ApexJobFactory factory;

  public JobCandidate(final ApexJobFactory factory, final List<JobRequest__c> jobRequests) {
    this.factory = factory;
    this.chunkSizeCalculator = factory.getChunkSizeCalculator();
    this.jobRequests = jobRequests;
    this.jobDescription = jobRequests[0].JobDescription__r;
  }

  public JobExecutable getExecutableChunk() {
    final Integer chunkSize = this.calculateChunkSize();
    if (chunkSize <= 0) {
      return null;
    }
    final List<JobRequest__c> jobsChunk = new List<JobRequest__c>();
    for (Integer i = 0; i < chunkSize; ++i) {
      jobsChunk.add(this.jobRequests[i]);
    }
    return new JobExecutable(this.factory, jobsChunk);
  }

  private Integer calculateChunkSize() {
    Integer chunkSize = this.jobDescription.MaxChunkSize__c.intValue();
    if (chunkSize == ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE) {
      return 1;
    }

    chunkSize = this.chunkSizeCalculator.getMaxPossible(this.jobDescription);
    return Math.min(chunkSize, this.jobRequests.size());
  }
}
