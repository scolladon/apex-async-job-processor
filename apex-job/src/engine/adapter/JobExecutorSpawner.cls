public interface JobExecutorSpawner {
  Id enqueue(AsyncApexJobExecutor executor, Integer delayInMinutes);
}
