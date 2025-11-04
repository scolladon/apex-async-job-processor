public interface ConsumptionLearner {
  void adjustFromSuccess(LimitsUsage consumedLimits, Integer chunkSize);
  void adjustFromFailure(LimitsUsage consumedLimits, Integer chunkSize);
  void adjustFromKill(Integer chunkSize);
}
