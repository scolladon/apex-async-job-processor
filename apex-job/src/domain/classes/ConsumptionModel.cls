public without sharing class ConsumptionModel {
  private static final List<ConsumptionModel> MODELS = new List<ConsumptionModel>();

  public String dimension { get; private set; }
  public String base { get; private set; }
  public String perItem { get; private set; }
  public String safety { get; private set; }

  @SuppressWarnings('PMD.ExcessiveParameterList')
  public ConsumptionModel(final String dimension, final String base, final String perItem, final String safety) {
    this.dimension = dimension;
    this.base = base;
    this.perItem = perItem;
    this.safety = safety;
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
