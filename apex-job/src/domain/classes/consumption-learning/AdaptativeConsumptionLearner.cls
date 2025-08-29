public without sharing class AdaptativeConsumptionLearner implements ConsumptionLearner {
  private static final Decimal SAFETY_STEP = 0.05;
  private static final Decimal MIN_SAFETY = 0.5;
  private static final Decimal MAX_SAFETY = 0.98;
  private static final Decimal KILL_PENALTY = 0.1;
  private static final Decimal VARIATION_RESET_THRESHOLD = 0.3;

  private final JobDescription__c job;
  private Boolean shouldResetConsumptionModel = false;

  public AdaptativeConsumptionLearner(final JobDescription__c jobDescription) {
    this.job = jobDescription;
  }

  public void adjustFromSuccess(final LimitsUsage consumed, final Integer chunkSize) {
    this.job.ConsecutiveFailures__c = 0;
    this.job.SuccessStreak__c = (this.job.SuccessStreak__c ?? 0) + 1;
    this.job.SmallestFailingChunk__c = 0;
    this.job.MaxChunkSize__c = Math.min(Math.max(this.job.MaxChunkSize__c ?? 0, chunkSize), this.job.MaxChunkSizeLimit__c ?? ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE);
    this.adjustStats(consumed, chunkSize, SAFETY_STEP);
  }

  public void adjustFromFailure(final LimitsUsage consumed, final Integer chunkSize) {
    this.job.ConsecutiveFailures__c = (this.job.ConsecutiveFailures__c ?? 0) + 1;
    this.job.SuccessStreak__c = 0;
    this.calculateSmallestFailingChunk(chunkSize);
    this.adjustStats(consumed, chunkSize, -SAFETY_STEP);
  }

  public void adjustFromKill(final Integer chunkSize) {
    this.job.ConsecutiveFailures__c = (this.job.ConsecutiveFailures__c ?? 0) + 1;
    this.job.SuccessStreak__c = 0;
    this.calculateSmallestFailingChunk(chunkSize);
    if (this.shouldResetConsumptionModelOnKill()) {
      this.resetConsumptionModel();
    } else {
      this.inflateConsumptionModel();
    }
  }

  private void adjustStats(final LimitsUsage consumed, final Integer chunkSize, final Decimal safetyStep) {
    if (chunkSize == 1) {
      this.recordInitialStats(consumed);
    } else {
      this.recordConsumption(consumed, chunkSize);
    }
    this.adjustSafetyFactors(safetyStep);
    if (this.shouldResetConsumptionModel) {
      this.resetConsumptionModel();
    }
  }

  private void recordInitialStats(final LimitsUsage consumed) {
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      final Decimal usage = consumed.get(model.dimension);
      final Decimal base = (Decimal) this.job.get(model.base) ?? 0;
      this.job.put(model.base, Math.max(base, usage));
    }
  }

  private void recordConsumption(final LimitsUsage consumed, final Integer chunkSize) {
    Decimal maxVariation = 0;
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      final Decimal base = (Decimal) this.job.get(model.base);
      final Decimal usage = consumed.get(model.dimension);
      final Decimal perItem = (Decimal) this.job.get(model.perItem);
      final Decimal calculatedPerItem = (usage - base) / (chunkSize - 1);
      if (perItem > 0) {
        maxVariation = Math.max(maxVariation, Math.abs((calculatedPerItem - perItem) / perItem));
      }

      if (maxVariation > VARIATION_RESET_THRESHOLD) {
        this.shouldResetConsumptionModel = true;
        break;
      }
      this.job.put(model.perItem, Math.max(perItem, calculatedPerItem));
    }
  }

  private void adjustSafetyFactors(final Decimal step) {
    if (this.shouldResetConsumptionModel) {
      return;
    }

    for (ConsumptionModel model : ConsumptionModel.asList()) {
      Decimal newSafety = (Decimal) this.job.get(model.safety);
      newSafety = Math.min(MAX_SAFETY, newSafety + step);
      // Means metrics are changing, we should recalculate
      if (newSafety < MIN_SAFETY) {
        this.shouldResetConsumptionModel = true;
        break;
      }
      this.job.put(model.safety, newSafety);
    }
  }

  private void resetConsumptionModel() {
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      this.job.put(model.base, ApexJobConstant.UNKNOWN_BASE_CONSUMPTION);
      this.job.put(model.perItem, ApexJobConstant.UNKNOWN_PERITEM_CONSUMPTION);
      this.job.put(model.safety, ApexJobConstant.UNKNOWN_SAFETY);
    }
    this.job.MaxChunkSize__c = ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE;
    this.job.ConsecutiveFailures__c = 0;
    this.job.SuccessStreak__c = 0;
    this.job.SmallestFailingChunk__c = 0;
  }

  private void inflateConsumptionModel() {
    final Decimal penalty = 1 + KILL_PENALTY;
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      Decimal base = (Decimal) this.job.get(model.base) ?? 0;
      Decimal perItem = (Decimal) this.job.get(model.perItem) ?? 0;
      this.job.put(model.base, base * penalty);
      this.job.put(model.perItem, perItem * penalty);
    }
  }

  private Boolean shouldResetConsumptionModelOnKill() {
    return this.job.MaxExecutionAttempt__c != -1 && this.job.ConsecutiveFailures__c >= this.job.MaxExecutionAttempt__c;
  }

  private void calculateSmallestFailingChunk(final Integer chunkSize) {
    this.job.SmallestFailingChunk__c = Math.min(this.job.SmallestFailingChunk__c == 0 ? ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE : this.job.SmallestFailingChunk__c, chunkSize);
  }
}
