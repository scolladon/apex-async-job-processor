public interface ApexJobFactory {
  ApexJobLogger getLogger();
  ApexJobLogger newLogger();
  void adoptLogger(ApexJobLogger carried);
  JobSelector getSelector();
  JobRepository getRepository();
  JobExecutorSpawner getSpawner();
  JobExecutorService getExecutorService();
  JobExecutorFinalizerAttacher getFinalizerAttacher();
  ApexJobConfigService getConfigService();
  LimitService getLimitService();
  ChunkSizeCalculator getChunkSizeCalculator();
  ConsumptionLearner getConsumptionLearner(JobDescription__c jobDescription);
  JobRequestArgumentParser getArgumentParser();
}
