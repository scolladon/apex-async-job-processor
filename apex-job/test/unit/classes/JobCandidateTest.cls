@IsTest
private class JobCandidateTest {
  @IsTest
  static void givenGetExecutableChunk_whenChunkSizeIsUnknown_thenReturnsExecutableWithOneItem() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(-1).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final JobCandidate sut = new JobCandidate(mocks.factoryStub, new List<JobRequest__c>{ jobRequest });

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.isNotNull(result, 'Should return executable when chunk size is unknown for first execution');
    Assert.areEqual(1, result.jobRequests.size(), 'Should return chunk of size 1');
  }

  @IsTest
  static void givenGetExecutableChunk_whenCalculatedChunkSizeIsZero_thenReturnsNull() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(0);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(0).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final JobCandidate sut = new JobCandidate(mocks.factoryStub, new List<JobRequest__c>{ jobRequest });

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.isNull(result, 'Should return null when chunk size is 0');
  }

  @IsTest
  static void givenGetExecutableChunk_whenMultipleJobRequests_thenReturnsChunkWithCalculatedSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(2);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(2).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(3);
    final JobCandidate sut = new JobCandidate(mocks.factoryStub, jobRequests);

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.areEqual(2, result.jobRequests.size(), 'Should include calculated chunk size');
    Assert.areEqual(jobRequests[0], result.jobRequests[0], 'Should include first job request');
    Assert.areEqual(jobRequests[1], result.jobRequests[1], 'Should include second job request');
  }

  @IsTest
  static void givenGetExecutableChunk_whenCanIncreaseChunk_thenReturnsIncreasedChunkSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(6);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(5).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(10);
    final JobCandidate sut = new JobCandidate(mocks.factoryStub, jobRequests);

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.isNotNull(result, 'Should be executable');
    Assert.areEqual(6, result.jobRequests.size(), 'Should return increased chunk size');
    Expect.that(mocks.getMaxPossibleSpy).hasBeenCalledWith(jobDescription);
  }

  @IsTest
  static void givenGetExecutableChunk_whenCannotProcessMuch_thenReturnsPossibleChunkSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(1);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(3).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(5);
    final JobCandidate sut = new JobCandidate(mocks.factoryStub, jobRequests);

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.isNotNull(result, 'Should be executable');
    Assert.areEqual(1, result.jobRequests.size(), 'Should return possible chunk size');
    Expect.that(mocks.getMaxPossibleSpy).hasBeenCalledWith(jobDescription);
  }
}
