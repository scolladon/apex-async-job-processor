@IsTest
private class ConsumptionModelTest {
  private static final Decimal EXPECTED_COUNTER_FLOOR = 1;
  private static final Decimal EXPECTED_CPU_TIME_FLOOR_MS = 5;
  private static final Decimal EXPECTED_HEAP_SIZE_FLOOR_BYTES = 4096;
  private static final Decimal EXPECTED_CALLOUT_TIME_FLOOR_MS = 5;

  @IsTest
  static void givenEveryDimension_whenAsList_thenNoiseFloorMatchesItsUnit() {
    // Arrange
    final Map<String, Decimal> expectedFloorByDimension = new Map<String, Decimal>{
      LimitsUsage.CPU_TIME_DIMENSION => EXPECTED_CPU_TIME_FLOOR_MS,
      LimitsUsage.HEAP_SIZE_DIMENSION => EXPECTED_HEAP_SIZE_FLOOR_BYTES,
      LimitsUsage.CALLOUT_TIME_DIMENSION => EXPECTED_CALLOUT_TIME_FLOOR_MS
    };

    // Act
    final List<ConsumptionModel> result = ConsumptionModel.asList();

    // Assert
    Assert.isFalse(result.isEmpty());
    for (ConsumptionModel model : result) {
      Assert.areEqual(expectedFloorByDimension.get(model.dimension) ?? EXPECTED_COUNTER_FLOOR, model.noiseFloor, 'noise floor of ' + model.dimension);
    }
  }
}
