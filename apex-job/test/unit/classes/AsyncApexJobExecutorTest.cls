@IsTest
private class AsyncApexJobExecutorTest {
  private static final String ROLLED_BACK_LOG_PREFIX = 'AsyncJob: chunk rolled back ';
  private static final Id FAILED_JOB_ID = TestDataFactory.generateUniqueFakeId(AsyncApexJob.SObjectType);

  @IsTest
  static void givenFinalizerContext_whenExecuteWithSystemDisabled_thenExecuteDoNotReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenFinalizerContext_whenExecuteWithRemainingJobs_thenExecuteAndReenqueueWith0Delay() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    sut.jobExecutionResults.add((JobExecuted) jobExecutedMock.stub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenFinalizerContext_whenExecuteWithoutRemainingJobs_thenExecuteAndReenqueueWithDelay() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.getEnqueueDelayInMinutesSpy.returns(10);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.getEnqueueDelayInMinutesSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(10);
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenFinalizerContext_whenNotPossibleToReenqueue_thenItLogsAndStopTheQueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.enqueueSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
  }

  @IsTest
  static void givenFinalizerContext_whenEnabledAndRecordExecutionThrows_thenItReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'));
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenExecutedResultsAndRecordingThrows_whenFinalizerRuns_thenReenqueueWithIdleDelay() {
    // Arrange
    final Integer idleDelayInMinutes = 3;
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.getEnqueueDelayInMinutesSpy.returns(idleDelayInMinutes);
    mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    sut.jobExecutionResults.add((JobExecuted) jobExecutedMock.stub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(idleDelayInMinutes);
  }

  @IsTest
  static void givenFinalizerContext_whenSystemIsDisabledThrows_thenItCallsLoggerError() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
  }

  class SucceededFinalizerContext implements FinalizerContext {
    public Id getAsyncApexJobId() {
      return FAILED_JOB_ID;
    }
    public Id getRequestId() {
      return null;
    }
    public System.ParentJobResult getResult() {
      return ParentJobResult.SUCCESS;
    }
    public Exception getException() {
      return null;
    }
  }

  class KilledFinalizerContext implements FinalizerContext {
    public Id getAsyncApexJobId() {
      return FAILED_JOB_ID;
    }
    public Id getRequestId() {
      return null;
    }
    public System.ParentJobResult getResult() {
      return ParentJobResult.UNHANDLED_EXCEPTION;
    }
    public Exception getException() {
      return new TestException('Killed');
    }
  }

  @IsTest
  static void givenFinalizerContext_whenExceptionOccurs_thenItRecordsJobExecutionAndReenqueue() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('KilledPathJob').withProcessorName('AsyncApexJobExecutorTest.KilledPathJob').withMinJobInterval(3).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Req').withAttemptNumber(0).build();
    jobRequest.JobDescription__r = jobDescription;
    final List<JobRequest__c> jobs = new List<JobRequest__c>{ jobRequest };
    sut.lastExecutableJob = new JobExecutable(mocks.factoryStub, jobs);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.recordJobExecutionSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);

    // Validate timestamps propagated when staging
    final List<Object> args = mocks.recordJobExecutionSpy.getArguments(0);
    final List<JobExecuted> recorded = (List<JobExecuted>) args.get(0);
    Assert.areEqual(1, recorded.size(), 'One job executed should be recorded');
    final JobExecuted captured = recorded[0];
    captured.stageExecution();
    final JobRequest__c staged = jobs[0];
    Assert.isNotNull(staged.LastSelectionDateTime__c, 'Selection time should be set from executable');
    Assert.isNotNull(staged.LastExecutionDateTime__c, 'End time should fallback to now in killed path');
    Assert.isTrue(staged.LastSelectionDateTime__c.getTime() <= staged.LastExecutionDateTime__c.getTime(), 'Selection <= End');
    Assert.areEqual(staged.LastExecutionDateTime__c.addMinutes(3), staged.NextExecutionDateTime__c, 'Next try from end + interval');
  }
  @IsTest
  static void givenQueueableContext_whenExecuteWithSystemDisabled_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenQueueableContext_whenNoJobToExecute_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenQueueableContext_whenJobCandidatesPrepareChunkSuccessfully_thenExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    final Mock jobExecutableMock = Mock.forType(JobExecutable.class);
    final MethodSpy executeChunkSpy = jobExecutableMock.spyOn('executeChunk');
    executeChunkSpy.returns(jobExecutedMock.stub);

    final Mock jobCandidateMock = Mock.forType(JobCandidate.class);
    jobCandidateMock.spyOn('getExecutableChunk').returns((JobExecutable) jobExecutableMock.stub);

    mocks.getJobCandidatesSpy.returnsOnce(new List<JobCandidate>{ (JobCandidate) jobCandidateMock.stub });
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);

    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(2);
    Expect.that(executeChunkSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenQueueableContext_whenJobCandidatesPrepareChunkFails_thenNoExecution() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    final Mock jobExecutableMock = Mock.forType(JobExecutable.class);
    final MethodSpy executeChunkSpy = jobExecutableMock.spyOn('executeChunk');
    executeChunkSpy.returns(jobExecutedMock.stub);

    final Mock jobCandidateMock = Mock.forType(JobCandidate.class);
    jobCandidateMock.spyOn('getExecutableChunk').returns(null);

    mocks.getJobCandidatesSpy.returnsOnce(new List<JobCandidate>{ (JobCandidate) jobCandidateMock.stub });
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);

    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.attachSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.isSystemEnabledSpy).hasBeenCalledTimes(1);
    Expect.that(mocks.getJobCandidatesSpy).hasBeenCalledTimes(1);
    Expect.that(executeChunkSpy).hasNotBeenCalled();
    Expect.that(mocks.recordJobExecutionSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasNotBeenCalled();
  }

  @IsTest
  static void givenSuccessIsLastResultAndNoChunkInFlight_whenFinalizerRunsWithUnhandledException_thenRecordsTailAsKilled() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable inFlight = buildExecutable(mocks);
    sut.lastExecutableJob = inFlight;
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, inFlight, buildCompletedResult(ApexJobStatus.SUCCESS)));

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(1, recorded.size(), 'The tail must be recorded once');
    Assert.areEqual(ApexJobStatus.KILLED, recorded[0].jobExecutionResult.status, 'The tail must be recorded as KILLED');
    Assert.isTrue(recorded[0].executable === inFlight, 'The killed entry must carry the tail chunk');
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
  }

  @IsTest
  static void givenInFlightChunkNotRecorded_whenFinalizerFires_thenKilledAppended() {
    // Arrange — simulate a kill during executeChunk: pointer set, list still empty of this chunk.
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    sut.lastExecutableJob = buildExecutable(mocks);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert — exactly one KILLED record synthesized.
    Assert.areEqual(1, sut.jobExecutionResults.size(), 'Finalizer must append exactly one KILLED record when the in-flight chunk is not already recorded');
    Assert.areEqual(ApexJobStatus.KILLED, sut.jobExecutionResults[0].jobExecutionResult.status, 'The synthesized record status must be KILLED');
  }

  @IsTest
  static void givenSuccessForChunkNAndChunkNPlus1InFlight_whenFinalizerRunsWithUnhandledException_thenRecordsChunkNRolledBackAndChunkNPlus1Killed() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable previousChunk = buildExecutable(mocks);
    final JobExecutable currentChunk = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, previousChunk, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = currentChunk;

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(2, recorded.size(), 'Chunk N and chunk N+1 must be recorded');
    Assert.isTrue(recorded[1].executable === currentChunk, 'The killed entry must carry the in-flight chunk');
    Assert.areEqual(ApexJobStatus.KILLED, recorded[1].jobExecutionResult.status, 'The in-flight chunk must be KILLED');
    assertRolledBack(stagedRequestOf(recorded[0]));
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
  }

  @IsTest
  static void givenSeveralCompletedChunksAndChunkInFlight_whenFinalizerRunsWithUnhandledException_thenRollsBackEveryCompletedChunk() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable chunkA = buildExecutable(mocks);
    final JobExecutable chunkB = buildExecutable(mocks);
    final JobExecutable chunkC = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkA, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkB, buildCompletedResult(ApexJobStatus.FAILURE)));
    sut.lastExecutableJob = chunkC;

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(3, recorded.size(), 'Two rolled back chunks and one killed chunk must be recorded');
    assertRolledBack(stagedRequestOf(recorded[0]));
    assertRolledBack(stagedRequestOf(recorded[1]));
    Assert.isTrue(recorded[2].executable === chunkC, 'The killed entry must carry the in-flight chunk');
  }

  @IsTest
  static void givenSeveralCompletedChunksAndNullPointer_whenFinalizerRunsWithUnhandledException_thenRollsBackAllButTailAndKillsTail() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable chunkA = buildExecutable(mocks);
    final JobExecutable chunkB = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkA, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkB, buildCompletedResult(ApexJobStatus.SUCCESS)));

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(2, recorded.size(), 'The rolled back chunk and the killed tail must be recorded');
    assertRolledBack(stagedRequestOf(recorded[0]));
    Assert.areEqual(ApexJobStatus.KILLED, recorded[1].jobExecutionResult.status, 'The tail must be KILLED');
    Assert.isTrue(recorded[1].executable === chunkB, 'The killed entry must carry the tail chunk');
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
  }

  @IsTest
  static void givenSeveralCompletedChunksAndPointerOnTail_whenFinalizerRunsWithUnhandledException_thenRollsBackAllButTailAndKillsTail() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable chunkA = buildExecutable(mocks);
    final JobExecutable chunkB = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkA, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkB, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = chunkB;

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(2, recorded.size(), 'The rolled back chunk and the killed tail must be recorded');
    assertRolledBack(stagedRequestOf(recorded[0]));
    Assert.areEqual(ApexJobStatus.KILLED, recorded[1].jobExecutionResult.status, 'The tail must be KILLED');
    Assert.isTrue(recorded[1].executable === chunkB, 'The killed entry must carry the tail chunk');
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
  }

  @IsTest
  static void givenCompletedChunksAndChunkInFlight_whenFinalizerRunsWithUnhandledException_thenLogsOneErrorPerRolledBackChunk() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecutable chunkA = buildExecutable(mocks);
    final JobExecutable chunkB = buildExecutable(mocks);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkA, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, chunkB, buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = buildExecutable(mocks);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.errorSpy).hasBeenCalledTimes(2);
    assertRollbackLogLine((String) mocks.errorSpy.getArguments(0).get(0), chunkA);
    assertRollbackLogLine((String) mocks.errorSpy.getArguments(1).get(0), chunkB);
  }

  @IsTest
  static void givenRolledBackChunkAndRecordingThrows_whenFinalizerRuns_thenRollbackLineIsLoggedBeforeFailure() {
    // Arrange
    final Integer idleDelayInMinutes = 3;
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.getEnqueueDelayInMinutesSpy.returns(idleDelayInMinutes);
    mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, buildExecutable(mocks), buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = buildExecutable(mocks);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.errorSpy).hasBeenCalledTimes(3);
    Assert.isTrue(((String) mocks.errorSpy.getArguments(0).get(0)).startsWith(ROLLED_BACK_LOG_PREFIX), 'The rollback line must be logged first');
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(idleDelayInMinutes);
  }

  @IsTest
  static void givenNoResultAndNoPointer_whenFinalizerRunsWithUnhandledException_thenRecordsNothingAndReenqueuesWithIdleDelay() {
    // Arrange
    final Integer idleDelayInMinutes = 3;
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.getEnqueueDelayInMinutesSpy.returns(idleDelayInMinutes);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Assert.isTrue(recordedEntries(mocks).isEmpty(), 'Nothing must be recorded');
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(idleDelayInMinutes);
  }

  @IsTest
  static void givenSuccessResults_whenFinalizerRunsWithSuccessfulParent_thenRecordsResultsUnchanged() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final JobExecuted first = new JobExecuted(mocks.factoryStub, buildExecutable(mocks), buildCompletedResult(ApexJobStatus.SUCCESS));
    final JobExecuted second = new JobExecuted(mocks.factoryStub, buildExecutable(mocks), buildCompletedResult(ApexJobStatus.SUCCESS));
    sut.jobExecutionResults.add(first);
    sut.jobExecutionResults.add(second);

    // Act
    sut.execute(new SucceededFinalizerContext());

    // Assert
    final List<JobExecuted> recorded = recordedEntries(mocks);
    Assert.areEqual(2, recorded.size(), 'Both results must be recorded');
    Assert.isTrue(recorded[0] === first && recorded[1] === second, 'Results must be recorded unchanged');
    Expect.that(mocks.errorSpy).hasNotBeenCalled();
    Expect.that(mocks.enqueueSpy).hasBeenCalledWith(0);
  }

  @IsTest
  static void givenJobsToRun_whenQueueableExecutes_thenFlushesLoggerOnce() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    final Mock jobExecutableMock = Mock.forType(JobExecutable.class);
    jobExecutableMock.spyOn('executeChunk').returns(jobExecutedMock.stub);
    final Mock jobCandidateMock = Mock.forType(JobCandidate.class);
    jobCandidateMock.spyOn('getExecutableChunk').returns((JobExecutable) jobExecutableMock.stub);
    mocks.getJobCandidatesSpy.returnsOnce(new List<JobCandidate>{ (JobCandidate) jobCandidateMock.stub });
    mocks.getJobCandidatesSpy.returns(new List<JobCandidate>());
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.flushSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenSystemDisabled_whenQueueableExecutes_thenFlushesLoggerOnce() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute(new QueueableContextStub());

    // Assert
    Expect.that(mocks.flushSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenRecordedResults_whenFinalizerRuns_thenFlushesLoggerOnce() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    final Mock jobExecutedMock = Mock.forType(JobExecuted.class);
    sut.jobExecutionResults.add((JobExecuted) jobExecutedMock.stub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.flushSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenSystemDisabled_whenFinalizerRuns_thenFlushesLoggerOnce() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(false);
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);

    // Act
    sut.execute((FinalizerContext) null);

    // Assert
    Expect.that(mocks.flushSpy).hasBeenCalledTimes(1);
  }

  @IsTest
  static void givenRolledBackChunkAndRecordingThrows_whenFinalizerRuns_thenFlushesLoggerOnceAfterLogging() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.isSystemEnabledSpy.returns(true);
    mocks.recordJobExecutionSpy.throwsException(new TestException('Test exception'));
    final AsyncApexJobExecutor sut = new AsyncApexJobExecutor(mocks.factoryStub);
    sut.jobExecutionResults.add(new JobExecuted(mocks.factoryStub, buildExecutable(mocks), buildCompletedResult(ApexJobStatus.SUCCESS)));
    sut.lastExecutableJob = buildExecutable(mocks);

    // Act
    sut.execute(new KilledFinalizerContext());

    // Assert
    Expect.that(mocks.errorSpy).hasBeenCalledTimes(3);
    Expect.that(mocks.flushSpy).hasBeenCalledTimes(1);
  }

  private static void assertRollbackLogLine(final String line, final JobExecutable chunk) {
    Assert.isTrue(line.startsWith(ROLLED_BACK_LOG_PREFIX), line);
    Assert.isTrue(line.contains(chunk.jobRequests[0].JobDescription__r.Name), line);
    Assert.isTrue(line.contains(String.valueOf(chunk.jobRequests[0].Id)), line);
    Assert.isTrue(line.contains(String.valueOf(FAILED_JOB_ID)), line);
  }

  private static JobExecutable buildExecutable(final ApexJobTestMock mocks) {
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withProcessorName('AsyncApexJobExecutorTest.NoOpProcessor').build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withAttemptNumber(0).build();
    jobRequest.Id = TestDataFactory.generateUniqueFakeId(JobRequest__c.SObjectType);
    jobRequest.JobDescription__r = jobDescription;
    return new JobExecutable(mocks.factoryStub, new List<JobRequest__c>{ jobRequest });
  }

  private static ApexJobResult buildCompletedResult(final ApexJobStatus status) {
    final ApexJobResult result = new ApexJobResult(status);
    result.consumedLimits = ApexJobTestFixture.aLimitsUsage().withCallout(2).withPublishImmediateDml(1).build();
    return result;
  }

  private static List<JobExecuted> recordedEntries(final ApexJobTestMock mocks) {
    return (List<JobExecuted>) mocks.recordJobExecutionSpy.getArguments(0).get(0);
  }

  private static JobRequest__c stagedRequestOf(final JobExecuted entry) {
    entry.stageExecution();
    return entry.jobRequests[0];
  }

  private static void assertRolledBack(final JobRequest__c request) {
    Assert.areEqual(ApexJobStatus.READY.name(), request.Status__c, 'A rolled back request must stay READY');
    Assert.areEqual(0, request.AttemptNumber__c, 'A rolled back request must not consume an attempt');
    final String message = request.LastExecutionMessage__c;
    Assert.isTrue(message.contains(String.valueOf(FAILED_JOB_ID)), message);
    Assert.isTrue(message.contains('Callouts made: 2.'), message);
    Assert.isTrue(message.contains('Immediate events published: 1.'), message);
  }

  public class NoOpProcessor implements ApexJob {
    public ApexJobResult execute(final ApexJobContext ctx) {
      return new ApexJobResult(ApexJobStatus.SUCCESS);
    }
  }

  private class TestException extends Exception {
  }

  private class QueueableContextStub implements QueueableContext {
    public Id getJobId() {
      return TestDataFactory.generateUniqueFakeId(JobDescription__c.SObjectType);
    }
  }
}
