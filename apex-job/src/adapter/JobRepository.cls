public interface JobRepository {
  void recordJobExecution(List<JobExecuted> executedCandidate);
  JobCandidate[] getJobCandidates(List<JobExecuted> candidatesToExclude);
}
