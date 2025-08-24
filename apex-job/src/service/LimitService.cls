public interface LimitService {
  void startSnapshot();
  LimitsUsage stopSnapshot();
  void updateUsage(JobDescription__c jobDescription, LimitsUsage limitsUsage, Integer chunkSize);
  void resetUsage(JobDescription__c jobDescription);
  LimitsUsage getAvailableLimits();
  LimitsUsage getConsumedLimits();
  Integer computeMaxChunkSizeForTransaction(JobDescription__c jobDescription);
}
