public without sharing class AdaptiveChunkCalculator implements ChunkSizeCalculator {
  private static final Decimal INCREASE_SCALING_FACTOR = 0.01;
  private static final Decimal DECREASE_SCALING_FACTOR = 3 * INCREASE_SCALING_FACTOR;
  private static final Decimal MAX_SCALING_FACTOR = 0.1;

  private final LimitService limitService;

  public AdaptiveChunkCalculator() {
    this(new ApexJobFactoryImpl().getLimitService());
  }

  @TestVisible
  private AdaptiveChunkCalculator(final LimitService limitService) {
    this.limitService = limitService;
  }

  public Integer getMaxPossible(final JobDescription__c job) {
    if (job.MaxChunkSize__c < 1) {
      return 1;
    }

    final LimitsUsage available = limitService.getAvailableLimits();
    Decimal chunk = calculateFromModel(job, available);

    // Apply hard limits
    if (job.MaxChunkSizeLimit__c > 0) {
      chunk = Math.min(chunk, job.MaxChunkSizeLimit__c);
    }
    if (job.SmallestFailingChunk__c > 1) {
      chunk = Math.min(chunk, job.SmallestFailingChunk__c - 1);
    }

    return Math.floor(chunk).intValue();
  }

  private Decimal calculateFromModel(final JobDescription__c job, final LimitsUsage availableLimits) {
    Decimal minChunk; //  Do not set value in case no dimension are calculable
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      final Decimal base = (Decimal) job.get(model.base);

      // Only calculate if we have a known base consumption
      if (base > 0) {
        final Decimal dbPerItem = (Decimal) job.get(model.perItem);
        final Decimal perItem = dbPerItem > 0 ? dbPerItem : base;
        final Decimal safety = (Decimal) job.get(model.safety);
        final Integer availableLimit = availableLimits.get(model.dimension);
        final Decimal dimensionChunk = calculateForDimension(base, perItem, safety, availableLimit);

        // Track the most restrictive (smallest) chunk size across all dimensions
        minChunk = Math.min(minChunk ?? ApexJobConstant.DEFAULT_MAX_CHUNK_SIZE, dimensionChunk);

        // Early exit if we can't process more than one item
        // This is the most limitant dimension, no need to process others
        if (minChunk <= 1) {
          break;
        }
      }
    }

    // Return calculated minimum chunk size, or 0 if no valid calculation
    return minChunk ?? 0;
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private Decimal calculateForDimension(final Decimal base, final Decimal perItem, final Decimal safety, final Integer availableLimit) {
    // Calculate the usable limit after subtracting the base consumption
    // Base consumption is the fixed overhead required regardless of chunk size
    final Decimal usable = availableLimit - base;

    // If we have usable capacity, calculate the maximum chunk size
    // Formula: (usable_capacity * safety_factor / per_item_cost) + 1
    // The +1 accounts for the base execution
    // If no usable capacity remains, return 0 (cannot process any items)
    return usable > 0 ? (usable * safety / perItem) + 1 : 0;
  }
}
