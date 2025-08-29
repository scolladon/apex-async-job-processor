public interface LimitService {
  void startSnapshot();
  LimitsUsage stopSnapshot();
  LimitsUsage getAvailableLimits();
}
