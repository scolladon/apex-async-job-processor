public interface JobRepository {
  void recordJobExecution(List<JobExecuted> executedCandidate, FinalizerContext ctx);
  JobCandidate[] getJobCandidates(List<JobExecuted> candidatesToExclude);
}
