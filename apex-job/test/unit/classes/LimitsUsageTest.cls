@IsTest
private class LimitsUsageTest {
  private static final Decimal EXPECTED_COUNTER_FLOOR = 1;
  private static final Decimal EXPECTED_CPU_TIME_FLOOR_MS = 5;
  private static final Decimal EXPECTED_HEAP_SIZE_FLOOR_BYTES = 4096;
  private static final Decimal EXPECTED_CALLOUT_TIME_FLOOR_MS = 5;

  @IsTest
  static void givenTimeAndHeapDimensions_whenNoiseFloor_thenReturnsTheirResolution() {
    // Arrange
    final Map<String, Decimal> expectedFloorByDimension = new Map<String, Decimal>{
      'cpuTime' => EXPECTED_CPU_TIME_FLOOR_MS,
      'heapSize' => EXPECTED_HEAP_SIZE_FLOOR_BYTES,
      'calloutTime' => EXPECTED_CALLOUT_TIME_FLOOR_MS
    };

    // Act
    final Map<String, Decimal> result = new Map<String, Decimal>();
    for (String dimension : expectedFloorByDimension.keySet()) {
      result.put(dimension, LimitsUsage.noiseFloor(dimension));
    }

    // Assert
    Assert.areEqual(expectedFloorByDimension, result, 'Time and heap dimensions carry their own noise floor');
  }

  @IsTest
  static void givenCounterDimension_whenNoiseFloor_thenReturnsCounterFloor() {
    // Arrange
    final String counterDimension = 'queries';

    // Act
    final Decimal result = LimitsUsage.noiseFloor(counterDimension);

    // Assert
    Assert.areEqual(EXPECTED_COUNTER_FLOOR, result, 'A counter dimension uses the counter noise floor');
  }

  @IsTest
  static void givenGovernedLimits_whenDimensions_thenContainsEveryLearnedDimension() {
    // Arrange
    final Set<String> mustHave = new Set<String>{
      'cpuTime',
      'heapSize',
      'callout',
      'calloutTime',
      'publishImmediateDml',
      'dmlRows',
      'dmlStatements',
      'queryRows',
      'queries',
      'soslQueries',
      'futureCalls',
      'aggregateQueries',
      'apexCursorRows',
      'fetchCallsOnApexCursor',
      'emailInvocations',
      'mobilePushApexCalls',
      'queryLocatorRows',
      'queueableJobs'
    };

    // Act
    final Set<String> result = new Set<String>(LimitsUsage.dimensions());

    // Assert
    Assert.isTrue(result.containsAll(mustHave), 'Every dimension with consumption fields on the description is learned and reset');
  }
}
