public interface ApexJobFactory {
  ApexJobLogger getLogger();
  JobSelector getSelector();
  JobRepository getRepository();
  JobExecutorSpawner getSpawner();
  JobExecutorFinalizerAttacher getFinalizerAttacher();
  ApexJobConfigService getConfigService();
  LimitService getLimitService();
  ChunkSizeCalculator getChunkSizeCalculator();
  ConsumptionLearner getConsumptionLearner(JobDescription__c jobDescription);
}
