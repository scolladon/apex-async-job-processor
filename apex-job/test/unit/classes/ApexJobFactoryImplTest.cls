@isTest
private class ApexJobFactoryImplTest {
  @isTest
  static void givenFactoryImpl_whenGetLogger_thenReturnsApexJobLoggerImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    ApexJobLogger result = sut.getLogger();

    // Assert
    Assert.isNotNull(result, 'Logger should not be null');
    Assert.isInstanceOfType(result, ApexJobLoggerImpl.class, 'Logger should be of type ApexJobLoggerImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetLoggerCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    ApexJobLogger result1 = sut.getLogger();
    ApexJobLogger result2 = sut2.getLogger();

    // Assert
    Assert.areEqual(result1, result2, 'Logger should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetSelector_thenReturnsJobSelectorImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    JobSelector result = sut.getSelector();

    // Assert
    Assert.isNotNull(result, 'Selector should not be null');
    Assert.isInstanceOfType(result, JobSelectorImpl.class, 'Selector should be of type JobSelectorImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetSelectorCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    JobSelector result1 = sut.getSelector();
    JobSelector result2 = sut2.getSelector();

    // Assert
    Assert.areEqual(result1, result2, 'Selector should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetRepository_thenReturnsJobRepositoryImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    JobRepository result = sut.getRepository();

    // Assert
    Assert.isNotNull(result, 'Repository should not be null');
    Assert.isInstanceOfType(result, JobRepositoryImpl.class, 'Repository should be of type JobRepositoryImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetRepositoryCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    JobRepository result1 = sut.getRepository();
    JobRepository result2 = sut2.getRepository();

    // Assert
    Assert.areEqual(result1, result2, 'Repository should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetSpawner_thenReturnsJobExecutorQueueableSpawner() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    JobExecutorSpawner result = sut.getSpawner();

    // Assert
    Assert.isNotNull(result, 'Spawner should not be null');
    Assert.isInstanceOfType(result, JobExecutorQueueableSpawner.class, 'Spawner should be of type JobExecutorQueueableSpawner');
  }

  @isTest
  static void givenFactoryImpl_whenGetSpawnerCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    JobExecutorSpawner result1 = sut.getSpawner();
    JobExecutorSpawner result2 = sut2.getSpawner();

    // Assert
    Assert.areEqual(result1, result2, 'Spawner should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetExecutorService_thenReturnsJobExecutorServiceImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    JobExecutorService result = sut.getExecutorService();

    // Assert
    Assert.isNotNull(result, 'ExecutorService should not be null');
    Assert.isInstanceOfType(result, JobExecutorServiceImpl.class, 'ExecutorService should be of type JobExecutorServiceImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetExecutorServiceCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    JobExecutorService result1 = sut.getExecutorService();
    JobExecutorService result2 = sut2.getExecutorService();

    // Assert
    Assert.areEqual(result1, result2, 'ExecutorService should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetConfigService_thenReturnsApexJobConfigServiceImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    ApexJobConfigService result = sut.getConfigService();

    // Assert
    Assert.isNotNull(result, 'ConfigService should not be null');
    Assert.isInstanceOfType(result, ApexJobConfigServiceImpl.class, 'ConfigService should be of type ApexJobConfigServiceImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetConfigServiceCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    ApexJobConfigService result1 = sut.getConfigService();
    ApexJobConfigService result2 = sut2.getConfigService();

    // Assert
    Assert.areEqual(result1, result2, 'ConfigService should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetFinalizerAttacher_thenReturnsJobExecutorFinalizerAttacherImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    JobExecutorFinalizerAttacher result = sut.getFinalizerAttacher();

    // Assert
    Assert.isNotNull(result, 'FinalizerAttacher should not be null');
    Assert.isInstanceOfType(result, JobExecutorFinalizerAttacherImpl.class, 'FinalizerAttacher should be of type JobExecutorFinalizerAttacherImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetFinalizerAttacherCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    JobExecutorFinalizerAttacher result1 = sut.getFinalizerAttacher();
    JobExecutorFinalizerAttacher result2 = sut2.getFinalizerAttacher();

    // Assert
    Assert.areEqual(result1, result2, 'FinalizerAttacher should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetLimitService_thenReturnsLimitServiceImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    LimitService result = sut.getLimitService();

    // Assert
    Assert.isNotNull(result, 'LimitService should not be null');
    Assert.isInstanceOfType(result, LimitServiceImpl.class, 'LimitService should be of type LimitServiceImpl');
  }

  @isTest
  static void givenFactoryImpl_whenGetLimitServiceCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    LimitService result1 = sut.getLimitService();
    LimitService result2 = sut2.getLimitService();

    // Assert
    Assert.areEqual(result1, result2, 'LimitService should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetChunkSizeCalculator_thenReturnsChunkSizeCalculatorImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    ChunkSizeCalculator result = sut.getChunkSizeCalculator();

    // Assert
    Assert.isNotNull(result, 'ChunkSizeCalculator should not be null');
    Assert.isInstanceOfType(result, AdaptiveChunkCalculator.class, 'ChunkSizeCalculator should be of type AdaptiveChunkCalculator');
  }

  @isTest
  static void givenFactoryImpl_whenGetChunkSizeCalculatorCalledTwice_thenReturnsSameInstance() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();
    ApexJobFactory sut2 = new ApexJobFactoryImpl();

    // Act
    ChunkSizeCalculator result1 = sut.getChunkSizeCalculator();
    ChunkSizeCalculator result2 = sut2.getChunkSizeCalculator();

    // Assert
    Assert.areEqual(result1, result2, 'ChunkSizeCalculator should return the same singleton instance');
  }

  @isTest
  static void givenFactoryImpl_whenGetConsumptionLearner_thenReturnsConsumptionLearnerImpl() {
    // Arrange
    ApexJobFactory sut = new ApexJobFactoryImpl();

    // Act
    ConsumptionLearner result = sut.getConsumptionLearner(null);

    // Assert
    Assert.isNotNull(result, 'ConsumptionLearner should not be null');
    Assert.isInstanceOfType(result, AdaptativeConsumptionLearner.class, 'ConsumptionLearner should be of type AdaptativeConsumptionLearner');
  }
}
