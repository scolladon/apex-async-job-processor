@IsTest
private class JobCandidateTest {
  @IsTest
  static void givenIsExecutable_whenCalculatedChunkSizeIsAbove0_thenReturnsTrue() {
    // Arrange
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(-1).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final JobCandidate sut = new JobCandidate(new List<JobRequest__c>{ jobRequest });

    // Act
    final Boolean result = sut.isExecutable();

    // Assert
    Assert.isTrue(result, 'Should be executable when chunk size is unknown for first execution');
  }

  @IsTest
  static void givenIsExecutable_whenCalculatedChunkSizeIsBelow1_thenReturnsFalse() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(0);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(0).build();
    final JobRequest__c jobRequest = ApexJobTestFixture.aJobRequest().withName('Test').build();
    jobRequest.JobDescription__r = jobDescription;
    final JobCandidate sut = new JobCandidate(mocks.chunkSizeCalculatorStub, new List<JobRequest__c>{ jobRequest });

    // Act
    final Boolean result = sut.isExecutable();

    // Assert
    Assert.isFalse(result, 'Should not be executable when chunk size is 0');
  }

  @IsTest
  static void givenGetExecutableChunk_whenMultipleJobRequests_thenReturnsChunkWithCalculatedSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(2);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(2).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(3);
    final JobCandidate sut = new JobCandidate(mocks.chunkSizeCalculatorStub, jobRequests);
    sut.isExecutable(); // Must call isExecutable first to calculate chunk size

    // Act
    final JobExecutable result = sut.getExecutableChunk();

    // Assert
    Assert.areEqual(2, result.jobRequests.size(), 'Should include calculated chunk size');
    Assert.areEqual(jobRequests[0], result.jobRequests[0], 'Should include first job request');
    Assert.areEqual(jobRequests[1], result.jobRequests[1], 'Should include second job request');
  }

  @IsTest
  static void givenIsExecutable_whenCanIncreaseChunk_thenReturnsIncreasedChunkSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(6);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(5).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(10);
    final JobCandidate sut = new JobCandidate(mocks.chunkSizeCalculatorStub, jobRequests);

    // Act
    final Boolean result = sut.isExecutable();
    final JobExecutable chunk = sut.getExecutableChunk();

    // Assert
    Assert.isTrue(result, 'Should be executable');
    Assert.areEqual(6, chunk.jobRequests.size(), 'Should return increased chunk size');
    Expect.that(mocks.getMaxPossibleSpy).hasBeenCalledWith(jobDescription);
  }

  @IsTest
  static void givenIsExecutable_whenCannotProcessMuch_thenReturnsPossibleChunkSize() {
    // Arrange
    final ApexJobTestMock mocks = new ApexJobTestMock();
    mocks.getMaxPossibleSpy.returns(1);
    final JobDescription__c jobDescription = ApexJobTestFixture.aJobDescription().withName('TestProcessor').withProcessorName('TestProcessor').withMaxChunkSize(3).build();
    final List<JobRequest__c> jobRequests = ApexJobTestFixture.aJobRequest().withJobDescription(jobDescription).buildMany(5);
    final JobCandidate sut = new JobCandidate(mocks.chunkSizeCalculatorStub, jobRequests);

    // Act
    final Boolean result = sut.isExecutable();
    final JobExecutable chunk = sut.getExecutableChunk();

    // Assert
    Assert.isTrue(result, 'Should be executable');
    Assert.areEqual(1, chunk.jobRequests.size(), 'Should return possible chunk size');
    Expect.that(mocks.getMaxPossibleSpy).hasBeenCalledWith(jobDescription);
  }
}
