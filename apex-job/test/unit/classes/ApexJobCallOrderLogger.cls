@IsTest
public class ApexJobCallOrderLogger implements ApexJobLogger {
  public static final String DEBUG_CALL = 'debug';
  public static final String ERROR_CALL = 'error';
  public static final String FLUSH_CALL = 'flush';

  public final List<String> calls = new List<String>();

  public void debug(final String message) {
    this.calls.add(DEBUG_CALL);
  }

  public void error(final String message) {
    this.calls.add(ERROR_CALL);
  }

  public void flush() {
    this.calls.add(FLUSH_CALL);
  }

  public Integer countOf(final String call) {
    Integer count = 0;
    for (String recorded : this.calls) {
      count += recorded == call ? 1 : 0;
    }
    return count;
  }

  public String lastCall() {
    return this.calls.isEmpty() ? null : this.calls[this.calls.size() - 1];
  }
}
