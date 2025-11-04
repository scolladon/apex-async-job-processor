public virtual class ApexJobFactoryImpl implements ApexJobFactory {
  private static ApexJobLogger loggerInstance;
  private static JobSelector selectorInstance;
  private static JobRepository repositoryInstance;
  private static JobExecutorSpawner spawnerInstance;
  private static JobExecutorService executorServiceInstance;
  private static JobExecutorFinalizerAttacher finalizerAttacherInstance;
  private static ApexJobConfigService configServiceInstance;
  private static LimitService limitServiceInstance;
  private static ChunkSizeCalculator chunkSizeCalculatorInstance;

  public ApexJobLogger getLogger() {
    if (ApexJobFactoryImpl.loggerInstance == null) {
      ApexJobFactoryImpl.loggerInstance = new ApexJobLoggerImpl();
    }
    return ApexJobFactoryImpl.loggerInstance;
  }

  public JobSelector getSelector() {
    if (ApexJobFactoryImpl.selectorInstance == null) {
      ApexJobFactoryImpl.selectorInstance = new JobSelectorImpl();
    }
    return ApexJobFactoryImpl.selectorInstance;
  }

  public JobRepository getRepository() {
    if (ApexJobFactoryImpl.repositoryInstance == null) {
      ApexJobFactoryImpl.repositoryInstance = new JobRepositoryImpl();
    }
    return ApexJobFactoryImpl.repositoryInstance;
  }

  public virtual JobExecutorSpawner getSpawner() {
    if (ApexJobFactoryImpl.spawnerInstance == null) {
      ApexJobFactoryImpl.spawnerInstance = new JobExecutorQueueableSpawner();
    }
    return ApexJobFactoryImpl.spawnerInstance;
  }

  public JobExecutorService getExecutorService() {
    if (ApexJobFactoryImpl.executorServiceInstance == null) {
      ApexJobFactoryImpl.executorServiceInstance = new JobExecutorServiceImpl();
    }
    return ApexJobFactoryImpl.executorServiceInstance;
  }

  public JobExecutorFinalizerAttacher getFinalizerAttacher() {
    if (ApexJobFactoryImpl.finalizerAttacherInstance == null) {
      ApexJobFactoryImpl.finalizerAttacherInstance = new JobExecutorFinalizerAttacherImpl();
    }
    return ApexJobFactoryImpl.finalizerAttacherInstance;
  }

  public ApexJobConfigService getConfigService() {
    if (ApexJobFactoryImpl.configServiceInstance == null) {
      ApexJobFactoryImpl.configServiceInstance = new ApexJobConfigServiceImpl();
    }
    return ApexJobFactoryImpl.configServiceInstance;
  }

  public LimitService getLimitService() {
    if (ApexJobFactoryImpl.limitServiceInstance == null) {
      ApexJobFactoryImpl.limitServiceInstance = new LimitServiceImpl();
    }
    return ApexJobFactoryImpl.limitServiceInstance;
  }

  public ChunkSizeCalculator getChunkSizeCalculator() {
    if (ApexJobFactoryImpl.chunkSizeCalculatorInstance == null) {
      ApexJobFactoryImpl.chunkSizeCalculatorInstance = new AdaptiveChunkCalculator();
    }
    return ApexJobFactoryImpl.chunkSizeCalculatorInstance;
  }

  public ConsumptionLearner getConsumptionLearner(final JobDescription__c jobDescription) {
    return new AdaptativeConsumptionLearner(jobDescription);
  }
}
