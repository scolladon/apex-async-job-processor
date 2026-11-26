@IsTest
private class ApexJobRepositoryImplTest {
  private static final String UPSERT_PROCESSOR = 'RepositoryUpsert';

  private static JobDescription__c insertDescriptionAsAdmin(final String processorName, final Integer maxChunkSize) {
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().withProcessorName(processorName).withMaxChunkSize(maxChunkSize).build();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert as system description;
    }
    return description;
  }

  @IsTest
  static void givenMinimumAccessUser_whenInsertJobRequest_thenRequestPersisted() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryInsertRequest', 40);
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    // Act
    System.runAs(minimumAccessUser) {
      sut.insertJobRequest(request);
    }
    // Assert
    final List<JobRequest__c> result = [SELECT Id FROM JobRequest__c WHERE Id = :request.Id WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size());
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpdateJobRequest_thenRequestUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryUpdateRequest', 40);
    final JobRequest__c request = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert as system request;
    }
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    request.AttemptNumber__c = 2;
    // Act
    System.runAs(minimumAccessUser) {
      sut.updateJobRequest(request);
    }
    // Assert
    final JobRequest__c result = [SELECT AttemptNumber__c FROM JobRequest__c WHERE Id = :request.Id WITH SYSTEM_MODE];
    Assert.areEqual(2, result.AttemptNumber__c);
  }

  @IsTest
  static void givenMinimumAccessUser_whenInsertJobDescription_thenDescriptionPersisted() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().withProcessorName('RepositoryInsertDescription').withMaxChunkSize(40).build();
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    // Act
    System.runAs(minimumAccessUser) {
      sut.insertJobDescription(description);
    }
    // Assert
    final List<JobDescription__c> result = [SELECT Id FROM JobDescription__c WHERE Id = :description.Id WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size());
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpdateJobDescription_thenDescriptionUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin('RepositoryUpdateDescription', 40);
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    description.MaxChunkSize__c = 10;
    // Act
    System.runAs(minimumAccessUser) {
      sut.updateJobDescription(description);
    }
    // Assert
    final JobDescription__c result = [SELECT MaxChunkSize__c FROM JobDescription__c WHERE Id = :description.Id WITH SYSTEM_MODE];
    Assert.areEqual(10, result.MaxChunkSize__c);
  }

  @IsTest
  static void givenMinimumAccessUser_whenUpsertJobDescriptionByProcessorName_thenExistingDescriptionUpdated() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    insertDescriptionAsAdmin(UPSERT_PROCESSOR, 40);
    final JobDescription__c incoming = new JobDescription__c(ProcessorName__c = UPSERT_PROCESSOR, MaxChunkSize__c = 10);
    final ApexJobRepositoryImpl sut = new ApexJobRepositoryImpl();
    // Act
    System.runAs(minimumAccessUser) {
      sut.upsertJobDescriptionByProcessorName(incoming);
    }
    // Assert
    final List<JobDescription__c> result = [SELECT MaxChunkSize__c FROM JobDescription__c WHERE ProcessorName__c = :UPSERT_PROCESSOR WITH SYSTEM_MODE];
    Assert.areEqual(1, result.size());
    Assert.areEqual(10, result[0].MaxChunkSize__c);
  }
}
