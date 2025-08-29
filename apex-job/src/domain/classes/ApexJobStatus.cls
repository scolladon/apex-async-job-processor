public enum ApexJobStatus {
  ABORTED, // Job failed, and should not be retried
  FAILURE, // Job failed, candidat to retry
  KILLED, // Job killed because of governor limit issue.
  READY, // Job ready to be executed
  SUCCESS // Job successful
}
