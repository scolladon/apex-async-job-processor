public without sharing class ConsumptionModel {
  private static final Decimal COUNTER_NOISE_FLOOR = 1;
  private static final Decimal CPU_TIME_NOISE_FLOOR_MS = 5;
  private static final Decimal HEAP_SIZE_NOISE_FLOOR_BYTES = 4096;
  private static final Decimal CALLOUT_TIME_NOISE_FLOOR_MS = 5;
  private static final Map<String, Decimal> NOISE_FLOOR_BY_DIMENSION = new Map<String, Decimal>{
    LimitsUsage.CPU_TIME_DIMENSION => CPU_TIME_NOISE_FLOOR_MS,
    LimitsUsage.HEAP_SIZE_DIMENSION => HEAP_SIZE_NOISE_FLOOR_BYTES,
    LimitsUsage.CALLOUT_TIME_DIMENSION => CALLOUT_TIME_NOISE_FLOOR_MS
  };
  private static final List<ConsumptionModel> MODELS = new List<ConsumptionModel>();

  public String dimension { get; private set; }
  public String base { get; private set; }
  public String perItem { get; private set; }
  public String safety { get; private set; }
  public Decimal noiseFloor { get; private set; }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  public ConsumptionModel(final String dimension, final String base, final String perItem, final String safety) {
    this.dimension = dimension;
    this.base = base;
    this.perItem = perItem;
    this.safety = safety;
    this.noiseFloor = NOISE_FLOOR_BY_DIMENSION.get(dimension) ?? COUNTER_NOISE_FLOOR;
  }

  public Boolean isSignificantVariation(final Decimal observed, final Decimal expected, final Decimal relativeThreshold) {
    return Math.abs(observed - expected) > Math.max(this.noiseFloor, relativeThreshold * expected);
  }

  public static List<ConsumptionModel> asList() {
    if (ConsumptionModel.MODELS.isEmpty()) {
      for (String dimension : LimitsUsage.dimensions()) {
        String prefix = dimension.capitalize();
        // Do not validate against the schema because :
        // 1. it is costly
        // 2. it is not open to end user
        // 3. it is tested during unit test so we are pretty safe
        String base = prefix + 'BaseConsumption__c';
        String perItem = prefix + 'PerItemConsumption__c';
        String safety = prefix + 'Safety__c';
        ConsumptionModel.MODELS.add(new ConsumptionModel(dimension, base, perItem, safety));
      }
    }
    return ConsumptionModel.MODELS;
  }
}
