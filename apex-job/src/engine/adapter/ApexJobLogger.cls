public interface ApexJobLogger {
  void error(String message);
  void debug(String message);
  void flush();
}
