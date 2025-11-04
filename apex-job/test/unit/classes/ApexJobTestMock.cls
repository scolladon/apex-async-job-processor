@IsTest
@SuppressWarnings('PMD.ExcessivePublicCount')
public class ApexJobTestMock {
  // Stubs
  public ApexJobFactory factoryStub { get; private set; }
  public ApexJobLogger loggerStub { get; private set; }
  public JobSelector selectorStub { get; private set; }
  public JobRepository repositoryStub { get; private set; }
  public JobExecutorSpawner spawnerStub { get; private set; }
  public JobExecutorService executorServiceStub { get; private set; }
  public JobExecutorFinalizerAttacher finalizerAttacherStub { get; private set; }
  public ApexJobConfigService configServiceStub { get; private set; }
  public LimitService limitServiceStub { get; private set; }
  public ChunkSizeCalculator chunkSizeCalculatorStub { get; private set; }
  public ConsumptionLearner consumptionLearnerStub { get; private set; }

  // Spies
  public MethodSpy errorSpy { get; private set; }
  public MethodSpy debugSpy { get; private set; }
  public MethodSpy selectorSpy { get; private set; }
  public MethodSpy getEligibleJobsSpy { get; private set; }
  public MethodSpy repositorySpy { get; private set; }
  public MethodSpy recordJobExecutionSpy { get; private set; }
  public MethodSpy getJobCandidatesSpy { get; private set; }
  public MethodSpy spawnerSpy { get; private set; }
  public MethodSpy enqueueSpy { get; private set; }
  public MethodSpy finalizerAttacherSpy { get; private set; }
  public MethodSpy attachSpy { get; private set; }
  public MethodSpy configSpy { get; private set; }
  public MethodSpy isSystemEnabledSpy { get; private set; }
  public MethodSpy getEnqueueDelayInMinutesSpy { get; private set; }
  public MethodSpy limitServiceSpy { get; private set; }
  public MethodSpy startSnapshotSpy { get; private set; }
  public MethodSpy stopSnapshotSpy { get; private set; }
  public MethodSpy getAvailableLimitsSpy { get; private set; }
  public MethodSpy getMaxPossibleSpy { get; private set; }
  public MethodSpy adjustFromSuccessSpy { get; private set; }
  public MethodSpy adjustFromFailureSpy { get; private set; }
  public MethodSpy adjustFromKillSpy { get; private set; }
  public MethodSpy isRunningSpy { get; private set; }

  @SuppressWarnings('PMD.NcssConstructorCount')
  public ApexJobTestMock() {
    // Mocks
    Mock factoryMock = Mock.forType(ApexJobFactory.class);
    Mock loggerMock = Mock.forType(ApexJobLogger.class);
    Mock selectorMock = Mock.forType(JobSelector.class);
    Mock repositoryMock = Mock.forType(JobRepository.class);
    Mock spawnerMock = Mock.forType(JobExecutorSpawner.class);
    Mock executorServiceMock = Mock.forType(JobExecutorService.class);
    Mock finalizerAttacherMock = Mock.forType(JobExecutorFinalizerAttacher.class);
    Mock configServiceMock = Mock.forType(ApexJobConfigService.class);
    Mock limitServiceMock = Mock.forType(LimitService.class);
    Mock chunkSizeCalculatorMock = Mock.forType(ChunkSizeCalculator.class);
    Mock consumptionLearnerMock = Mock.forType(ConsumptionLearner.class);

    // Stubs
    this.factoryStub = (ApexJobFactory) factoryMock.stub;
    this.loggerStub = (ApexJobLogger) loggerMock.stub;
    this.selectorStub = (JobSelector) selectorMock.stub;
    this.repositoryStub = (JobRepository) repositoryMock.stub;
    this.spawnerStub = (JobExecutorSpawner) spawnerMock.stub;
    this.executorServiceStub = (JobExecutorService) executorServiceMock.stub;
    this.finalizerAttacherStub = (JobExecutorFinalizerAttacher) finalizerAttacherMock.stub;
    this.configServiceStub = (ApexJobConfigService) configServiceMock.stub;
    this.limitServiceStub = (LimitService) limitServiceMock.stub;
    this.chunkSizeCalculatorStub = (ChunkSizeCalculator) chunkSizeCalculatorMock.stub;
    this.consumptionLearnerStub = (ConsumptionLearner) consumptionLearnerMock.stub;

    // Factory Spies
    factoryMock.spyOn('getLogger').returns(this.loggerStub);
    factoryMock.spyOn('getSelector').returns(this.selectorStub);
    factoryMock.spyOn('getRepository').returns(this.repositoryStub);
    factoryMock.spyOn('getSpawner').returns(this.spawnerStub);
    factoryMock.spyOn('getExecutorService').returns(this.executorServiceStub);
    factoryMock.spyOn('getFinalizerAttacher').returns(this.finalizerAttacherStub);
    factoryMock.spyOn('getConfigService').returns(this.configServiceStub);
    factoryMock.spyOn('getLimitService').returns(this.limitServiceStub);
    factoryMock.spyOn('getChunkSizeCalculator').returns(this.chunkSizeCalculatorStub);
    factoryMock.spyOn('getConsumptionLearner').returns(this.consumptionLearnerStub);

    // Logger Spies
    this.errorSpy = loggerMock.spyOn('error');
    this.debugSpy = loggerMock.spyOn('debug');

    // Selector Spies
    this.getEligibleJobsSpy = selectorMock.spyOn('getEligibleJobs');

    // Repository Spies
    this.recordJobExecutionSpy = repositoryMock.spyOn('recordJobExecution');
    this.getJobCandidatesSpy = repositoryMock.spyOn('getJobCandidates');

    // Spawner Spies
    this.enqueueSpy = spawnerMock.spyOn('enqueue');

    // Executor Spies
    this.isRunningSpy = executorServiceMock.spyOn('isRunning');

    // Finalizer Spies
    this.attachSpy = finalizerAttacherMock.spyOn('attach');

    // Config Spies
    this.isSystemEnabledSpy = configServiceMock.spyOn('isSystemEnabled');
    this.getEnqueueDelayInMinutesSpy = configServiceMock.spyOn('getEnqueueDelayInMinutes');

    // Limit Spies
    this.startSnapshotSpy = limitServiceMock.spyOn('startSnapshot');
    this.stopSnapshotSpy = limitServiceMock.spyOn('stopSnapshot');
    this.getAvailableLimitsSpy = limitServiceMock.spyOn('getAvailableLimits');

    // ChunkSizeCalculator Spies
    this.getMaxPossibleSpy = chunkSizeCalculatorMock.spyOn('getMaxPossible');

    // ConsumptionLearner Spies
    this.adjustFromSuccessSpy = consumptionLearnerMock.spyOn('adjustFromSuccess');
    this.adjustFromFailureSpy = consumptionLearnerMock.spyOn('adjustFromFailure');
    this.adjustFromKillSpy = consumptionLearnerMock.spyOn('adjustFromKill');
  }
}
