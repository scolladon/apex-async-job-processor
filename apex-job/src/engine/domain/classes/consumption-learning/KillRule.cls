public without sharing class KillRule {
  private static final Integer SINGLE_ITEM_CHUNK = 1;
  private static final Integer CAPPED_AT_ONE_ITEM_FAILING_CHUNK = 2;
  private static final Integer UNLIMITED_ATTEMPTS = -1;

  private final JobDescription__c job;

  public KillRule(final JobDescription__c job) {
    this.job = job;
  }

  public Boolean isFloorKill(final Integer chunkSize) {
    return chunkSize == SINGLE_ITEM_CHUNK && (this.isModelUnknown() || this.isCappedAtOneItem());
  }

  public Boolean exhaustsAttempts() {
    return this.job.MaxExecutionAttempt__c != UNLIMITED_ATTEMPTS && this.job.ConsecutiveFailures__c >= this.job.MaxExecutionAttempt__c;
  }

  private Boolean isModelUnknown() {
    return this.job.MaxChunkSize__c < SINGLE_ITEM_CHUNK;
  }

  private Boolean isCappedAtOneItem() {
    return this.job.SmallestFailingChunk__c >= SINGLE_ITEM_CHUNK && this.job.SmallestFailingChunk__c <= CAPPED_AT_ONE_ITEM_FAILING_CHUNK;
  }
}
