@IsTest
private class ConsumptionModelTest {
  private static final Decimal EXPECTED_COUNTER_FLOOR = 1;
  private static final Decimal EXPECTED_CPU_TIME_FLOOR_MS = 5;
  private static final Decimal EXPECTED_HEAP_SIZE_FLOOR_BYTES = 4096;
  private static final Decimal EXPECTED_CALLOUT_TIME_FLOOR_MS = 5;
  private static final Decimal THRESHOLD = 0.3;

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

  @IsTest
  static void givenDeviationBelowFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenFalse() {
    // Arrange
    final ConsumptionModel sut = cpuTimeModel();

    // Act
    final Boolean result = sut.isSignificantVariation(2, 1, THRESHOLD);

    // Assert
    Assert.isFalse(result, 'A deviation below the noise floor is never significant');
  }

  @IsTest
  static void givenDeviationAboveFloorAndRatioAboveThreshold_whenIsSignificantVariation_thenTrue() {
    // Arrange
    final ConsumptionModel sut = cpuTimeModel();

    // Act
    final Boolean result = sut.isSignificantVariation(200, 100, THRESHOLD);

    // Assert
    Assert.isTrue(result, 'Deviation above the floor and ratio above the threshold is significant');
  }

  @IsTest
  static void givenDeviationAboveFloorAndRatioBelowThreshold_whenIsSignificantVariation_thenFalse() {
    // Arrange
    final ConsumptionModel sut = cpuTimeModel();

    // Act
    final Boolean result = sut.isSignificantVariation(110, 100, THRESHOLD);

    // Assert
    Assert.isFalse(result, 'A ratio below the threshold is not significant');
  }

  @IsTest
  static void givenDeviationEqualToFloor_whenIsSignificantVariation_thenFalse() {
    // Arrange
    final ConsumptionModel sut = cpuTimeModel();

    // Act
    final Boolean result = sut.isSignificantVariation(10, 5, THRESHOLD);

    // Assert
    Assert.isFalse(result, 'A deviation equal to the floor is not significant');
  }

  private static ConsumptionModel cpuTimeModel() {
    for (ConsumptionModel model : ConsumptionModel.asList()) {
      if (model.dimension == LimitsUsage.CPU_TIME_DIMENSION) {
        return model;
      }
    }
    return null;
  }
}
