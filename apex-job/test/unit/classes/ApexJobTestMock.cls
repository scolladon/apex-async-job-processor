@IsTest
public class ApexJobTestMock {
  // Stubs
  public ApexJobFactory factoryStub { get; private set; }
  public ApexJobLogger loggerStub { get; private set; }
  public JobSelector selectorStub { get; private set; }
  public JobRepository repositoryStub { get; private set; }
  public JobExecutorSpawner spawnerStub { get; private set; }
  public JobExecutorFinalizerAttacher finalizerAttacherStub { get; private set; }
  public ApexJobConfigService configServiceStub { get; private set; }
  public LimitService limitServiceStub { get; private set; }

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
  public MethodSpy updateUsageSpy { get; private set; }
  public MethodSpy resetUsageSpy { get; private set; }
  public MethodSpy getAvailableLimitsSpy { get; private set; }
  public MethodSpy getConsumedLimitsSpy { get; private set; }
  public MethodSpy computeMaxChunkSizeForTransactionSpy { get; private set; }

  public ApexJobTestMock() {
    // Mocks
    Mock factoryMock = Mock.forType(ApexJobFactory.class);
    Mock loggerMock = Mock.forType(ApexJobLogger.class);
    Mock selectorMock = Mock.forType(JobSelector.class);
    Mock repositoryMock = Mock.forType(JobRepository.class);
    Mock spawnerMock = Mock.forType(JobExecutorSpawner.class);
    Mock finalizerAttacherMock = Mock.forType(JobExecutorFinalizerAttacher.class);
    Mock configServiceMock = Mock.forType(ApexJobConfigService.class);
    Mock limitServiceMock = Mock.forType(LimitService.class);

    // Stubs
    this.factoryStub = (ApexJobFactory) factoryMock.stub;
    this.loggerStub = (ApexJobLogger) loggerMock.stub;
    this.selectorStub = (JobSelector) selectorMock.stub;
    this.repositoryStub = (JobRepository) repositoryMock.stub;
    this.spawnerStub = (JobExecutorSpawner) spawnerMock.stub;
    this.finalizerAttacherStub = (JobExecutorFinalizerAttacher) finalizerAttacherMock.stub;
    this.configServiceStub = (ApexJobConfigService) configServiceMock.stub;
    this.limitServiceStub = (LimitService) limitServiceMock.stub;

    // Factory Spies
    factoryMock.spyOn('getLogger').returns(this.loggerStub);
    factoryMock.spyOn('getSelector').returns(this.selectorStub);
    factoryMock.spyOn('getRepository').returns(this.repositoryStub);
    factoryMock.spyOn('getSpawner').returns(this.spawnerStub);
    factoryMock.spyOn('getFinalizerAttacher').returns(this.finalizerAttacherStub);
    factoryMock.spyOn('getConfigService').returns(this.configServiceStub);
    factoryMock.spyOn('getLimitService').returns(this.limitServiceStub);

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

    // Finalizer Spies
    this.attachSpy = finalizerAttacherMock.spyOn('attach');

    // Config Spies
    this.isSystemEnabledSpy = configServiceMock.spyOn('isSystemEnabled');
    this.getEnqueueDelayInMinutesSpy = configServiceMock.spyOn('getEnqueueDelayInMinutes');

    // Limit Spies
    this.startSnapshotSpy = limitServiceMock.spyOn('startSnapshot');
    this.stopSnapshotSpy = limitServiceMock.spyOn('stopSnapshot');
    this.updateUsageSpy = limitServiceMock.spyOn('updateUsage');
    this.resetUsageSpy = limitServiceMock.spyOn('resetUsage');
    this.getAvailableLimitsSpy = limitServiceMock.spyOn('getAvailableLimits');
    this.getConsumedLimitsSpy = limitServiceMock.spyOn('getConsumedLimits');
    this.computeMaxChunkSizeForTransactionSpy = limitServiceMock.spyOn('computeMaxChunkSizeForTransaction');
  }
}
