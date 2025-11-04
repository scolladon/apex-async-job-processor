public interface JobExecutorSpawner {
  Id enqueue(Integer delayInMinutes);
  Id enqueue();
}
