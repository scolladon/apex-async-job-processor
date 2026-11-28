public class SlidingRateWindow {
  private static final String ENTRY_SEPARATOR = ';';
  private static final String FIELD_SEPARATOR = ':';
  private static final Long MS_PER_SECOND = 1000L;
  private static final Integer LOG_MAX_LENGTH = 131072;
  private static final Integer ENTRY_FIELD_COUNT = 2;
  private static final Integer MAX_END_MS_DIGITS = 18;
  private static final Integer MAX_ITEMS_DIGITS = 9;
  private final Integer maxItems;
  private final List<Entry> entries;

  private SlidingRateWindow(final Integer maxItems, final List<Entry> entries) {
    this.maxItems = maxItems;
    this.entries = entries;
  }

  public static SlidingRateWindow parse(final Integer maxItems, final String log) {
    if (String.isBlank(log)) {
      return new SlidingRateWindow(maxItems, new List<Entry>());
    }
    final List<Entry> parsed = wellFormedEntries(log);
    parsed.sort();
    return new SlidingRateWindow(maxItems, parsed);
  }

  private static List<Entry> wellFormedEntries(final String log) {
    final List<Entry> parsed = new List<Entry>();
    for (String piece : log.split(ENTRY_SEPARATOR)) {
      final List<String> fields = piece.split(FIELD_SEPARATOR);
      if (isWellFormed(fields)) {
        parsed.add(new Entry(Long.valueOf(fields[0]), Long.valueOf(fields[1])));
      }
    }
    return parsed;
  }

  private static Boolean isWellFormed(final List<String> fields) {
    return fields.size() == ENTRY_FIELD_COUNT && isNumber(fields[0], MAX_END_MS_DIGITS) && isNumber(fields[1], MAX_ITEMS_DIGITS) && Long.valueOf(fields[1]) > 0;
  }

  private static Boolean isNumber(final String text, final Integer maxDigits) {
    return text.isNumeric() && text.length() <= maxDigits;
  }

  public String serialize() {
    final List<String> texts = new List<String>();
    for (Entry entry : this.fittedEntries()) {
      texts.add(entry.toText());
    }
    return String.join(texts, '');
  }

  private List<Entry> fittedEntries() {
    Integer length = 0;
    for (Entry entry : this.entries) {
      length += entry.length();
    }
    if (length <= LOG_MAX_LENGTH) {
      return this.entries;
    }
    return this.coalescedOldest(length);
  }

  // Tracks the length incrementally: re-serializing at each merge costs seconds of CPU on a full log
  private List<Entry> coalescedOldest(final Integer fullLength) {
    Integer length = fullLength;
    Entry carried = this.entries[0];
    Integer next = 1;
    while (length > LOG_MAX_LENGTH && next < this.entries.size()) {
      final Entry following = this.entries[next];
      final Entry merged = new Entry(following.endMs, carried.items + following.items);
      length += merged.length() - carried.length() - following.length();
      carried = merged;
      next++;
    }
    final List<Entry> fitted = new List<Entry>{ carried };
    for (Integer i = next; i < this.entries.size(); i++) {
      fitted.add(this.entries[i]);
    }
    return fitted;
  }

  public Integer remainingBudget(final Long nowMs) {
    return Math.max(0L, this.maxItems - this.itemsInWindowEndingAt(nowMs)).intValue();
  }

  public SlidingRateWindow record(final Long endMs, final Integer items) {
    final List<Entry> kept = new List<Entry>();
    for (Entry entry : this.entries) {
      if (entry.isInWindowEndingAt(endMs)) {
        kept.add(entry);
      }
    }
    kept.add(new Entry(endMs, items));
    return new SlidingRateWindow(this.maxItems, kept);
  }

  public Long itemCount() {
    Long total = 0L;
    for (Entry entry : this.entries) {
      total += entry.items;
    }
    return total;
  }

  public Datetime blockedUntil() {
    Long total = 0L;
    for (Integer i = this.entries.size() - 1; i >= 0; i--) {
      final Entry entry = this.entries[i];
      total += entry.items;
      if (total >= this.maxItems) {
        return ceilToSecond(entry.endMs + ApexJobConstant.RATE_WINDOW_MS);
      }
    }
    return null;
  }

  private static Datetime ceilToSecond(final Long ms) {
    return Datetime.newInstance(((ms + MS_PER_SECOND - 1) / MS_PER_SECOND) * MS_PER_SECOND);
  }

  private Long itemsInWindowEndingAt(final Long nowMs) {
    Long total = 0L;
    for (Entry entry : this.entries) {
      if (entry.isInWindowEndingAt(nowMs)) {
        total += entry.items;
      }
    }
    return total;
  }

  private class Entry implements Comparable {
    private final Long endMs;
    private final Long items;

    private Entry(final Long endMs, final Long items) {
      this.endMs = endMs;
      this.items = items;
    }

    // An entry ending after the reference can only come from an edit, never from a Finalizer: counting it would block the description forever
    private Boolean isInWindowEndingAt(final Long referenceMs) {
      return this.endMs > referenceMs - ApexJobConstant.RATE_WINDOW_MS && this.endMs <= referenceMs;
    }

    private Integer length() {
      return this.toText().length();
    }

    private String toText() {
      return String.valueOf(this.endMs) + FIELD_SEPARATOR + String.valueOf(this.items) + ENTRY_SEPARATOR;
    }

    public Integer compareTo(final Object other) {
      final Long otherEnd = ((Entry) other).endMs;
      if (this.endMs < otherEnd) {
        return -1;
      }
      if (this.endMs > otherEnd) {
        return 1;
      }
      return 0;
    }
  }
}
