@IsTest
private class ApexJobRepositoryImplTest {
  private static final String UPSERT_PROCESSOR = 'RepositoryUpsert';
  private static final Integer ORIGINAL_MAX_CHUNK_SIZE = 40;
  private static final Integer UPDATED_MAX_CHUNK_SIZE = 10;
  private static final Integer UPDATED_ATTEMPT_NUMBER = 2;

  private static JobDescription__c insertDescriptionAsAdmin(final String processorName) {
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().withProcessorName(processorName).withMaxChunkSize(ORIGINAL_MAX_CHUNK_SIZE).build();
    TestDataFactory.insertAsAdmin(new List<SObject>{ description });
    return description;
  }

  @IsTest
  static void givenMinimumAccessUser_whenInsertJobRequest_thenRequestPersisted() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryInsertRequest');
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();

    // Act
    System.runAs(minimumAccessUser) {
      sut.insertJobRequest(request);
    }

    // Assert
    final List<JobRequest__c> result = [SELECT Id FROM JobRequest__c WHERE Id = :request.Id WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size(), 'Should persist the request');
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpdateJobRequest_thenRequestUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryUpdateRequest');
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    TestDataFactory.insertAsAdmin(new List<SObject>{ request });
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    request.AttemptNumber__c = UPDATED_ATTEMPT_NUMBER;

    // Act
    System.runAs(minimumAccessUser) {
      sut.updateJobRequest(request);
    }

    // Assert
    final JobRequest__c result = [SELECT AttemptNumber__c FROM JobRequest__c WHERE Id = :request.Id WITH SYSTEM_MODE];
    Assert.areEqual(UPDATED_ATTEMPT_NUMBER, result.AttemptNumber__c, 'Should persist the updated attempt number');
  }

  @IsTest
  static void givenMinimumAccessUser_whenInsertJobDescription_thenDescriptionPersisted() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().withProcessorName('RepositoryInsertDescription').withMaxChunkSize(ORIGINAL_MAX_CHUNK_SIZE).build();
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();

    // Act
    System.runAs(minimumAccessUser) {
      sut.insertJobDescription(description);
    }

    // Assert
    final List<JobDescription__c> result = [SELECT Id FROM JobDescription__c WHERE Id = :description.Id WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size(), 'Should persist the description');
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpdateJobDescription_thenDescriptionUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryUpdateDescription');
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    description.MaxChunkSize__c = UPDATED_MAX_CHUNK_SIZE;

    // Act
    System.runAs(minimumAccessUser) {
      sut.updateJobDescription(description);
    }

    // Assert
    final JobDescription__c result = [SELECT MaxChunkSize__c FROM JobDescription__c WHERE Id = :description.Id WITH SYSTEM_MODE];
    Assert.areEqual(UPDATED_MAX_CHUNK_SIZE, result.MaxChunkSize__c, 'Should persist the updated chunk size');
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpsertJobDescriptionByProcessorName_thenExistingDescriptionUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    insertDescriptionAsAdmin(UPSERT_PROCESSOR);
    final JobDescription__c incoming = new JobDescription__c(ProcessorName__c = UPSERT_PROCESSOR, MaxChunkSize__c = UPDATED_MAX_CHUNK_SIZE);
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();

    // Act
    System.runAs(minimumAccessUser) {
      sut.upsertJobDescriptionByProcessorName(incoming);
    }

    // Assert
    final List<JobDescription__c> result = [SELECT MaxChunkSize__c FROM JobDescription__c WHERE ProcessorName__c = :UPSERT_PROCESSOR WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size(), 'Should match the existing description by processor name');
    Assert.areEqual(UPDATED_MAX_CHUNK_SIZE, result[0].MaxChunkSize__c, 'Should persist the upserted chunk size');
  }
}
