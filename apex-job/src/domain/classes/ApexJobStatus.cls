public enum ApexJobStatus {
  ABORTED, // Job failed, and should not be retried
  FAILURE, // Job failed, candidat to retry
  READY, // Job ready to be executed
  SUCCESS // Job successful
}
