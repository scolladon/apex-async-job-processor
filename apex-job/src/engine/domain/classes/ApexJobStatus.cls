public enum ApexJobStatus {
  ABORTED, // Job failed, and should not be retried
  FAILURE, // Job failed, candidat to retry
  KILLED, // Job killed because of governor limit issue.
  MALFORMED_ARGUMENT, // Argument__c JSON could not be parsed; terminal failure.
  READY, // Job ready to be executed
  SUCCESS // Job successful
}
