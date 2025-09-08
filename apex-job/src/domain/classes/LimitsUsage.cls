public class LimitsUsage {
  private static final String CPU_TIME_DIMENSION = 'cpuTime';
  private static final String HEAP_SIZE_DIMENSION = 'heapSize';
  private static final String CALLOUT_DIMENSION = 'callout';
  private static final String CALLOUT_TIME_DIMENSION = 'calloutTime';
  private static final String PUBLISH_IMMEDIATE_DML_DIMENSION = 'publishImmediateDml';
  private static final String DML_ROWS_DIMENSION = 'dmlRows';
  private static final String DML_STATEMENTS_DIMENSION = 'dmlStatements';
  private static final String QUERY_ROWS_DIMENSION = 'queryRows';
  private static final String QUERIES_DIMENSION = 'queries';
  private static final String SOSL_QUERIES_DIMENSION = 'soslQueries';
  private static final String FUTURE_CALLS_DIMENSION = 'futureCalls';
  private static final String AGGREGATE_QUERIES_DIMENSION = 'aggregateQueries';
  private static final String APEX_CURSOR_ROWS_DIMENSION = 'apexCursorRows';
  private static final String FETCH_CALLS_ON_APEX_CURSOR_DIMENSION = 'fetchCallsOnApexCursor';
  private static final String EMAIL_INVOCATIONS_DIMENSION = 'emailInvocations';
  private static final String MOBILE_PUSH_APEX_CALLS_DIMENSION = 'mobilePushApexCalls';
  private static final String QUERY_LOCATOR_ROWS_DIMENSION = 'queryLocatorRows';
  private static final String QUEUEABLE_JOBS_DIMENSION = 'queueableJobs';

  private static final List<String> ALL_DIMENSIONS = new List<String>{
    CPU_TIME_DIMENSION,
    HEAP_SIZE_DIMENSION,
    CALLOUT_DIMENSION,
    CALLOUT_TIME_DIMENSION,
    PUBLISH_IMMEDIATE_DML_DIMENSION,
    DML_ROWS_DIMENSION,
    DML_STATEMENTS_DIMENSION,
    QUERY_ROWS_DIMENSION,
    QUERIES_DIMENSION,
    SOSL_QUERIES_DIMENSION,
    FUTURE_CALLS_DIMENSION,
    AGGREGATE_QUERIES_DIMENSION,
    APEX_CURSOR_ROWS_DIMENSION,
    FETCH_CALLS_ON_APEX_CURSOR_DIMENSION,
    EMAIL_INVOCATIONS_DIMENSION,
    MOBILE_PUSH_APEX_CALLS_DIMENSION,
    QUERY_LOCATOR_ROWS_DIMENSION,
    QUEUEABLE_JOBS_DIMENSION
  };

  private Map<String, Integer> store = new Map<String, Integer>();

  public Integer get(String key) {
    return store.get(key);
  }

  public Integer cpuTime {
    get {
      return this.get(CPU_TIME_DIMENSION);
    }
    set {
      this.store.put(CPU_TIME_DIMENSION, value);
    }
  }
  public Integer heapSize {
    get {
      return this.get(HEAP_SIZE_DIMENSION);
    }
    set {
      this.store.put(HEAP_SIZE_DIMENSION, value);
    }
  }
  public Integer callout {
    get {
      return this.get(CALLOUT_DIMENSION);
    }
    set {
      this.store.put(CALLOUT_DIMENSION, value);
    }
  }
  public Integer calloutTime {
    get {
      return this.get(CALLOUT_TIME_DIMENSION);
    }
    set {
      this.store.put(CALLOUT_TIME_DIMENSION, value);
    }
  }
  public Integer publishImmediateDml {
    get {
      return this.get(PUBLISH_IMMEDIATE_DML_DIMENSION);
    }
    set {
      this.store.put(PUBLISH_IMMEDIATE_DML_DIMENSION, value);
    }
  }
  public Integer dmlRows {
    get {
      return this.get(DML_ROWS_DIMENSION);
    }
    set {
      this.store.put(DML_ROWS_DIMENSION, value);
    }
  }
  public Integer dmlStatements {
    get {
      return this.get(DML_STATEMENTS_DIMENSION);
    }
    set {
      this.store.put(DML_STATEMENTS_DIMENSION, value);
    }
  }
  public Integer queryRows {
    get {
      return this.get(QUERY_ROWS_DIMENSION);
    }
    set {
      this.store.put(QUERY_ROWS_DIMENSION, value);
    }
  }
  public Integer queries {
    get {
      return this.get(QUERIES_DIMENSION);
    }
    set {
      this.store.put(QUERIES_DIMENSION, value);
    }
  }
  public Integer soslQueries {
    get {
      return this.get(SOSL_QUERIES_DIMENSION);
    }
    set {
      this.store.put(SOSL_QUERIES_DIMENSION, value);
    }
  }
  public Integer futureCalls {
    get {
      return this.get(FUTURE_CALLS_DIMENSION);
    }
    set {
      this.store.put(FUTURE_CALLS_DIMENSION, value);
    }
  }
  public Integer aggregateQueries {
    get {
      return this.get(AGGREGATE_QUERIES_DIMENSION);
    }
    set {
      this.store.put(AGGREGATE_QUERIES_DIMENSION, value);
    }
  }
  public Integer apexCursorRows {
    get {
      return this.get(APEX_CURSOR_ROWS_DIMENSION);
    }
    set {
      this.store.put(APEX_CURSOR_ROWS_DIMENSION, value);
    }
  }
  public Integer fetchCallsOnApexCursor {
    get {
      return this.get(FETCH_CALLS_ON_APEX_CURSOR_DIMENSION);
    }
    set {
      this.store.put(FETCH_CALLS_ON_APEX_CURSOR_DIMENSION, value);
    }
  }
  public Integer emailInvocations {
    get {
      return this.get(EMAIL_INVOCATIONS_DIMENSION);
    }
    set {
      this.store.put(EMAIL_INVOCATIONS_DIMENSION, value);
    }
  }
  public Integer mobilePushApexCalls {
    get {
      return this.get(MOBILE_PUSH_APEX_CALLS_DIMENSION);
    }
    set {
      this.store.put(MOBILE_PUSH_APEX_CALLS_DIMENSION, value);
    }
  }
  public Integer queryLocatorRows {
    get {
      return this.get(QUERY_LOCATOR_ROWS_DIMENSION);
    }
    set {
      this.store.put(QUERY_LOCATOR_ROWS_DIMENSION, value);
    }
  }
  public Integer queueableJobs {
    get {
      return this.get(QUEUEABLE_JOBS_DIMENSION);
    }
    set {
      this.store.put(QUEUEABLE_JOBS_DIMENSION, value);
    }
  }

  public static List<String> dimensions() {
    return ALL_DIMENSIONS;
  }
}
