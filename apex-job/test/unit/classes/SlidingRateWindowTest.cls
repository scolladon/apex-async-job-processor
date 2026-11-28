@IsTest
private class SlidingRateWindowTest {
  private static final Integer MAX_ITEMS = 10;
  private static final Integer LARGE_MAX_ITEMS = 10000;
  private static final Long SECOND_MS = 1000L;
  private static final Long T0 = 1764240000000L;

  @IsTest
  static void givenOneItemEndedAt0sAndNineItemsAt59s_whenBudgetReadAt61s_thenOnlyOneItemRemains() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + 59 * SECOND_MS, 9);

    // Act
    final Integer result = sut.remainingBudget(T0 + 61 * SECOND_MS);

    // Assert
    Assert.areEqual(1, result, 'Nine items ended 2 s ago: a sliding 60 s window leaves 1 (the fixed window gave 10)');
  }

  @IsTest
  static void givenEntryEndedExactly60sAgo_whenRemainingBudget_thenEntryNoLongerCounts() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1);

    // Act
    final Integer result = sut.remainingBudget(T0 + 60 * SECOND_MS);

    // Assert
    Assert.areEqual(MAX_ITEMS, result, 'An entry ended exactly 60 s ago is out of the window');
  }

  @IsTest
  static void givenEntryEnded59999msAgo_whenRemainingBudget_thenEntryStillCounts() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1);

    // Act
    final Integer result = sut.remainingBudget(T0 + 60 * SECOND_MS - 1);

    // Assert
    Assert.areEqual(MAX_ITEMS - 1, result, 'An entry ended 59.999 s ago is still in the window');
  }

  @IsTest
  static void givenSeveralChunks_whenItemCount_thenSumsItems() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + SECOND_MS, 2).record(T0 + 2 * SECOND_MS, 3);

    // Act
    final Long result = sut.itemCount();

    // Assert
    Assert.areEqual(6L, result, 'Item count sums the items of every entry');
  }

  @IsTest
  static void givenMoreItemsThanMax_whenRemainingBudget_thenZero() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 12);

    // Act
    final Integer result = sut.remainingBudget(T0 + SECOND_MS);

    // Assert
    Assert.areEqual(0, result, 'Budget never goes negative');
  }

  @IsTest
  static void givenRecord_whenOriginalReused_thenOriginalUnchanged() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1);

    // Act
    final SlidingRateWindow result = sut.record(T0 + SECOND_MS, 2);

    // Assert
    Assert.areEqual(1L, sut.itemCount(), 'Recording does not mutate the original window');
    Assert.areEqual(3L, result.itemCount(), 'The derived window holds both entries');
  }

  private static SlidingRateWindow spikeWindow() {
    return SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + 59 * SECOND_MS, 9);
  }

  private static SlidingRateWindow staggeredWindow() {
    return SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + 10 * SECOND_MS, 5).record(T0 + 20 * SECOND_MS, 5);
  }

  private static SlidingRateWindow fractionalWindow() {
    return SlidingRateWindow.parse(MAX_ITEMS, null).record(T0 + 123, 5).record(T0 + 500, 5);
  }

  @IsTest
  static void givenItemsBelowMax_whenBlockedUntil_thenNull() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 9);

    // Act
    final Datetime result = sut.blockedUntil();

    // Assert
    Assert.isNull(result, 'No hint while the window is below the maximum');
  }

  @IsTest
  static void givenMaxReachedByOldestEntry_whenBlockedUntil_thenOldestEndPlusWindow() {
    // Arrange
    final SlidingRateWindow sut = spikeWindow();

    // Act
    final Datetime result = sut.blockedUntil();

    // Assert
    Assert.areEqual(Datetime.newInstance(T0 + 60 * SECOND_MS), result, 'The oldest entry leaving the window frees capacity');
  }

  @IsTest
  static void givenMaxReachedByNewerEntries_whenBlockedUntil_thenTippingEntryEndPlusWindow() {
    // Arrange
    final SlidingRateWindow sut = staggeredWindow();

    // Act
    final Datetime result = sut.blockedUntil();

    // Assert
    Assert.areEqual(Datetime.newInstance(T0 + 70 * SECOND_MS), result, 'The entry tipping the newest-first sum decides the hint');
  }

  @IsTest
  static void givenTippingEndNotOnWholeSecond_whenBlockedUntil_thenRoundedUpToNextSecond() {
    // Arrange
    final SlidingRateWindow sut = fractionalWindow();

    // Act
    final Datetime result = sut.blockedUntil();

    // Assert
    Assert.areEqual(Datetime.newInstance(T0 + 61 * SECOND_MS), result, 'The hint is rounded up to the next whole second');
  }

  @IsTest
  static void givenMaxReachedByOldestEntry_whenBudgetReadAtHint_thenAtLeastOne() {
    // Arrange
    final SlidingRateWindow sut = spikeWindow();

    // Act
    final Integer result = sut.remainingBudget(sut.blockedUntil().getTime());

    // Assert
    Assert.isTrue(result >= 1, 'Capacity is available at the hint');
  }

  @IsTest
  static void givenMaxReachedByNewerEntries_whenBudgetReadAtHint_thenAtLeastOne() {
    // Arrange
    final SlidingRateWindow sut = staggeredWindow();

    // Act
    final Integer result = sut.remainingBudget(sut.blockedUntil().getTime());

    // Assert
    Assert.isTrue(result >= 1, 'Capacity is available at the hint');
  }

  @IsTest
  static void givenTippingEndNotOnWholeSecond_whenBudgetReadAtHint_thenAtLeastOne() {
    // Arrange
    final SlidingRateWindow sut = fractionalWindow();

    // Act
    final Integer result = sut.remainingBudget(sut.blockedUntil().getTime());

    // Assert
    Assert.isTrue(result >= 1, 'Capacity is available at the rounded hint');
  }

  @IsTest
  static void givenMaxReachedByOldestEntry_whenBudgetReadOneSecondBeforeHint_thenZero() {
    // Arrange
    final SlidingRateWindow sut = spikeWindow();

    // Act
    final Integer result = sut.remainingBudget(sut.blockedUntil().getTime() - SECOND_MS);

    // Assert
    Assert.areEqual(0, result, 'No capacity before the hint');
  }

  @IsTest
  static void givenMaxReachedByNewerEntries_whenBudgetReadOneSecondBeforeHint_thenZero() {
    // Arrange
    final SlidingRateWindow sut = staggeredWindow();

    // Act
    final Integer result = sut.remainingBudget(sut.blockedUntil().getTime() - SECOND_MS);

    // Assert
    Assert.areEqual(0, result, 'No capacity before the hint');
  }

  @IsTest
  static void givenEntries_whenSerialize_thenEndMsColonItemsSemicolonFormat() {
    // Arrange
    final SlidingRateWindow sut = spikeWindow();

    // Act
    final String result = sut.serialize();

    // Assert
    Assert.areEqual('1764240000000:1;1764240059000:9;', result, 'Each entry is written as endMs:items followed by a semicolon');
  }

  @IsTest
  static void givenRecordedWindow_whenSerializeThenParse_thenSameBudgetCountAndHint() {
    // Arrange
    final SlidingRateWindow original = spikeWindow();

    // Act
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, original.serialize());

    // Assert
    Assert.areEqual(original.remainingBudget(T0 + 61 * SECOND_MS), sut.remainingBudget(T0 + 61 * SECOND_MS), 'Budget survives the round trip');
    Assert.areEqual(original.itemCount(), sut.itemCount(), 'Item count survives the round trip');
    Assert.areEqual(original.blockedUntil(), sut.blockedUntil(), 'Hint survives the round trip');
  }

  @IsTest
  static void givenEntryOlderThanWindow_whenRecord_thenPrunedFromSerializedLog() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + 61 * SECOND_MS, 1);

    // Act
    final String result = sut.serialize();

    // Assert
    Assert.areEqual((T0 + 61 * SECOND_MS) + ':1;', result, 'Entries out of the window are dropped from the log');
  }

  @IsTest
  static void givenEntryEndedExactly60sBeforeRecordedChunk_whenRecord_thenPrunedFromLog() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, null).record(T0, 1).record(T0 + 60 * SECOND_MS, 1);

    // Act
    final String result = sut.serialize();

    // Assert
    Assert.areEqual((T0 + 60 * SECOND_MS) + ':1;', result, 'An entry ended exactly 60 s before the recorded chunk leaves the log');
  }

  @IsTest
  static void givenNullLog_whenParse_thenFullBudgetAndNoItem() {
    // Arrange
    final String log = null;

    // Act
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Assert
    Assert.areEqual(MAX_ITEMS, sut.remainingBudget(T0), 'An absent log leaves the full budget');
    Assert.areEqual(0L, sut.itemCount(), 'An absent log holds no item');
  }

  @IsTest
  static void givenEmptyLog_whenParse_thenFullBudgetAndNoItem() {
    // Arrange
    final String log = '';

    // Act
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Assert
    Assert.areEqual(MAX_ITEMS, sut.remainingBudget(T0), 'An empty log leaves the full budget');
    Assert.areEqual(0L, sut.itemCount(), 'An empty log holds no item');
  }

  @IsTest
  static void givenEntriesOutOfOrder_whenBlockedUntil_thenUsesEndOrder() {
    // Arrange
    final String log = (T0 + 20000) + ':5;' + T0 + ':1;' + (T0 + 10000) + ':5;';
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Act
    final Datetime result = sut.blockedUntil();

    // Assert
    Assert.areEqual(Datetime.newInstance(T0 + 70 * SECOND_MS), result, 'Entries are ordered by end before the hint is computed');
  }

  @IsTest
  static void givenMalformedEntries_whenParse_thenSkipsThemAndKeepsValidOnes() {
    // Arrange
    final String log = 'abc;1764240000000:x;:3;1764240059000:9;-5:1;99999999999999999999:1;1764240000000:0;1764240000000;1764240000000:1:1;1764240000000:9999999999;';

    // Act
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Assert
    Assert.areEqual(9L, sut.itemCount(), 'Only the well-formed entry is kept');
    Assert.areEqual('1764240059000:9;', sut.serialize(), 'Malformed entries do not reach the log');
  }

  @IsTest
  static void givenLogLongerThanField_whenSerialize_thenFitsAndCoalescesOldestIntoNext() {
    // Arrange
    final SlidingRateWindow sut = oversizedWindow(MAX_ITEMS);

    // Act
    final String result = sut.serialize();

    // Assert
    Assert.isTrue(result.length() <= 131072, 'The log fits the field length');
    Assert.areEqual(8401L, sut.itemCount(), 'The window keeps every item');
    Assert.areEqual(8401L, SlidingRateWindow.parse(MAX_ITEMS, result).itemCount(), 'Coalescing keeps every item');
    Assert.isTrue(result.endsWith((T0 + 45 * SECOND_MS) + ':1;'), 'The newest entry is kept as is');
  }

  @IsTest
  static void givenCoalescedLog_whenBudgetReadAfterOldestRawEntryLeftWindow_thenMergedItemsStillCount() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(LARGE_MAX_ITEMS, oversizedWindow(LARGE_MAX_ITEMS).serialize());

    // Act
    final Integer result = sut.remainingBudget(T0 + 60 * SECOND_MS + 1);

    // Assert
    Assert.areEqual(LARGE_MAX_ITEMS - 8401, result, 'Coalesced items keep the later end, so they still count once the oldest raw entry has left the window');
  }

  private static SlidingRateWindow oversizedWindow(final Integer maxItems) {
    final List<String> texts = new List<String>();
    for (Integer i = 0; i < 8400; i++) {
      texts.add((T0 + i * 5) + ':1;');
    }
    return SlidingRateWindow.parse(maxItems, String.join(texts, '')).record(T0 + 45 * SECOND_MS, 1);
  }

  @IsTest
  static void givenItemsSummingBeyondIntegerRange_whenRemainingBudget_thenZero() {
    // Arrange
    final String log = T0 + ':999999999;' + (T0 + 1) + ':999999999;' + (T0 + 2) + ':999999999;';
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Act
    final Integer result = sut.remainingBudget(T0 + SECOND_MS);

    // Assert
    Assert.areEqual(0, result, 'A sum beyond the Integer range still exhausts the budget');
  }

  @IsTest
  static void givenItemsSummingBeyondIntegerRange_whenItemCount_thenExactSum() {
    // Arrange
    final String log = T0 + ':999999999;' + (T0 + 1) + ':999999999;' + (T0 + 2) + ':999999999;';
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, log);

    // Act
    final Long result = sut.itemCount();

    // Assert
    Assert.areEqual(2999999997L, result, 'The count does not wrap past the Integer range');
  }

  @IsTest
  static void givenEntryEndingAfterNow_whenRemainingBudget_thenEntryIgnored() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, (T0 + 3600 * SECOND_MS) + ':10;');

    // Act
    final Integer result = sut.remainingBudget(T0);

    // Assert
    Assert.areEqual(MAX_ITEMS, result, 'An entry ending in the future cannot block the description forever');
  }

  @IsTest
  static void givenEntryEndingAfterRecordedChunk_whenRecord_thenDroppedFromLog() {
    // Arrange
    final SlidingRateWindow sut = SlidingRateWindow.parse(MAX_ITEMS, (T0 + 3600 * SECOND_MS) + ':10;').record(T0, 1);

    // Act
    final String result = sut.serialize();

    // Assert
    Assert.areEqual(T0 + ':1;', result, 'The next write heals a log holding a future entry');
  }
}
