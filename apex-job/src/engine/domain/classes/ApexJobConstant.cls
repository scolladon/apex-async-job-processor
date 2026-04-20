public without sharing class ApexJobConstant {
  public static final Integer UNKNOWN_MAX_CHUNK_SIZE = -1;
  public static final Integer DEFAULT_MAX_CHUNK_SIZE = 50;
  public static final Long RATE_WINDOW_MS = 60 * 1000L;

  public static final Decimal UNKNOWN_BASE_CONSUMPTION = 0;
  public static final Decimal UNKNOWN_PERITEM_CONSUMPTION = 0;
  public static final Decimal UNKNOWN_SAFETY = 0.74;
  public static final Decimal AVAILABLE_LIMITS_BUFFER = 0.97;

  public static final Integer MINUTES_PER_HOUR = 60;
  public static final Integer WATCHER_INTERVAL_MINUTES = 5;

  public static final Decimal DEFAULT_LEARNING_RATE = 0.30;
  public static final Integer DEFAULT_VARIATION_RESET_COUNT = 3;
  public static final Integer DEFAULT_KILL_COOLDOWN_COUNT = 3;
}
