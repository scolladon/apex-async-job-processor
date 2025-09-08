public without sharing class AdaptativeConsumptionLearner implements ConsumptionLearner {
  private static final Decimal SAFETY_STEP = 0.05;
  private static final Decimal MIN_SAFETY = 0.5;
  private static final Decimal MAX_SAFETY = 0.98;
  private static final Decimal KILL_PENALTY = 1.1;

  private final JobDescription__c job;

  public AdaptativeConsumptionLearner(final JobDescription__c jobDescription) {
    this.job = jobDescription;
  }

  public void adjustFromSuccess(final LimitsUsage consumed, final Integer chunkSize) {
    this.updateFieldsOnSuccess(chunkSize);
    this.updateModel(consumed, chunkSize, SAFETY_STEP);
  }

  public void adjustFromFailure(final LimitsUsage consumed, final Integer chunkSize) {
    this.updateFieldsOnFailure(chunkSize);
    this.updateModel(consumed, chunkSize, -SAFETY_STEP);
  }

  public void adjustFromKill(final Integer chunkSize) {
    this.updateFieldsOnFailure(chunkSize);
    if (this.requiresResetOnKill()) {
      this.resetConsumptionModel();
    } else {
      this.inflateConsumptionModel();
    }
  }

  private void updateModel(final LimitsUsage consumed, final Integer chunkSize, final Decimal safetyStep) {
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      final Decimal usage = consumed.get(model.dimension);
      if (processDimension(usage, model, chunkSize, safetyStep)) {
        resetConsumptionModel();
        break;
      }
    }
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private Boolean processDimension(final Decimal usage, final ConsumptionModel model, final Integer chunkSize, final Decimal safetyStep) {
    if (adjustSafetyModel(model, safetyStep)) {
      return true;
    }
    if (chunkSize == 1) {
      return adjustBaseConsumptionModel(usage, model);
    }
    return adjustPerItemConsumptionModel(usage, model, chunkSize);
  }

  private Boolean adjustBaseConsumptionModel(final Decimal usage, final ConsumptionModel model) {
    final Decimal currentBase = (Decimal) this.job.get(model.base);
    this.job.put(model.base, Math.max(currentBase, usage));
    return false;
  }

  private Boolean adjustPerItemConsumptionModel(final Decimal usage, final ConsumptionModel model, final Integer chunkSize) {
    final Decimal currentPerItem = (Decimal) this.job.get(model.perItem);
    final Decimal newPerItem = calculateNewPerItem(usage, model, chunkSize);

    if (currentPerItem > 0) {
      final Decimal variation = Math.abs((newPerItem - currentPerItem) / currentPerItem);
      if (variation > this.job.VariationResetThreashold__c) {
        return true; // Variation too large
      }
    }

    this.job.put(model.perItem, Math.max(currentPerItem, newPerItem));
    return false;
  }

  private Decimal calculateNewPerItem(final Decimal usage, final ConsumptionModel model, final Integer chunkSize) {
    final Decimal base = (Decimal) this.job.get(model.base);
    return (usage - base) / (chunkSize - 1);
  }

  private Boolean adjustSafetyModel(final ConsumptionModel model, final Decimal safetyStep) {
    if (this.job.ConsecutiveFailures__c <= 1 && this.job.SuccessStreak__c <= 1) {
      return false; // No safety adjustment needed
    }

    final Decimal currentSafety = (Decimal) this.job.get(model.safety);
    final Decimal newSafety = Math.min(MAX_SAFETY, currentSafety + safetyStep);

    if (newSafety < MIN_SAFETY) {
      return true; // Safety too low
    }

    this.job.put(model.safety, newSafety);
    return false;
  }

  private void inflateConsumptionModel() {
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      if (processDimensionForInflation(model)) {
        resetConsumptionModel();
        return;
      }
    }
  }

  private Boolean processDimensionForInflation(final ConsumptionModel model) {
    final Decimal currentSafety = (Decimal) this.job.get(model.safety);
    final Decimal newSafety = Math.min(MAX_SAFETY, currentSafety - SAFETY_STEP);

    if (newSafety < MIN_SAFETY) {
      return true; // Safety too low - reset required
    }

    penalizeModelValues(model, newSafety);
    return false;
  }

  private void penalizeModelValues(final ConsumptionModel model, final Decimal newSafety) {
    final Decimal base = (Decimal) this.job.get(model.base);
    final Decimal perItem = (Decimal) this.job.get(model.perItem);

    this.job.put(model.base, base * KILL_PENALTY);
    this.job.put(model.perItem, perItem * KILL_PENALTY);
    this.job.put(model.safety, newSafety);
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

  private Boolean requiresResetOnKill() {
    return this.job.MaxExecutionAttempt__c != -1 && this.job.ConsecutiveFailures__c >= this.job.MaxExecutionAttempt__c;
  }

  private void updateFieldsOnFailure(final Integer chunkSize) {
    this.job.ConsecutiveFailures__c = this.job.ConsecutiveFailures__c + 1;
    this.job.SuccessStreak__c = 0;
    this.job.SmallestFailingChunk__c = Math.min(this.job.SmallestFailingChunk__c == 0 ? ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE : this.job.SmallestFailingChunk__c, chunkSize);
  }

  private void updateFieldsOnSuccess(final Integer chunkSize) {
    this.job.ConsecutiveFailures__c = 0;
    this.job.SuccessStreak__c = this.job.SuccessStreak__c + 1;
    this.job.SmallestFailingChunk__c = 0;
    this.job.MaxChunkSize__c = Math.min(Math.max(this.job.MaxChunkSize__c, chunkSize), this.job.MaxChunkSizeLimit__c);
  }
}
