@IsTest
private class JobDescriptionActionsControllerTest {
  private static final String RESET_TARGET = 'ResetTarget';
  private static final Integer ORIGINAL_MAX_CHUNK_SIZE = 40;
  private static final Integer ORIGINAL_CONSECUTIVE_FAILURES = 2;
  private static final String ADMIN_PERMISSION_SET = 'AdminAsyncJob';

  private static JobDescription__c insertDescriptionAsAdmin() {
    final JobDescription__c description = ApexJobTestFixture.aJobDescription()
      .withProcessorName(RESET_TARGET)
      .withMaxChunkSize(ORIGINAL_MAX_CHUNK_SIZE)
      .withConsecutiveFailures(ORIGINAL_CONSECUTIVE_FAILURES)
      .build();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert as system description;
    }
    return description;
  }

  private static JobDescription__c reload(final Id recordId) {
    return [SELECT MaxChunkSize__c, ConsecutiveFailures__c FROM JobDescription__c WHERE Id = :recordId WITH SYSTEM_MODE];
  }

  @IsTest
  static void givenMinimumAccessUserWithoutObjectAccess_whenResetConsumptionModel_thenQueryExceptionThrown() {
    // Arrange
    final User minimumAccessUser = TestDataFactory.createMinimumAccessUser();
    final JobDescription__c description = insertDescriptionAsAdmin();
    System.QueryException caught;
    // Act
    System.runAs(minimumAccessUser) {
      try {
        JobDescriptionActionsController.resetConsumptionModel(description.Id);
      } catch (System.QueryException e) {
        caught = e;
      }
    }
    // Assert
    Assert.isNotNull(caught);
    final JobDescription__c result = reload(description.Id);
    Assert.areEqual(ORIGINAL_MAX_CHUNK_SIZE, result.MaxChunkSize__c);
    Assert.areEqual(ORIGINAL_CONSECUTIVE_FAILURES, result.ConsecutiveFailures__c);
  }

  @IsTest
  static void givenMinimumAccessUserWithAdminAsyncJob_whenResetConsumptionModel_thenModelReset() {
    // Arrange
    final User adminUser = TestDataFactory.createMinimumAccessUser();
    TestDataFactory.assignPermissionSet(adminUser.Id, ADMIN_PERMISSION_SET);
    final JobDescription__c description = insertDescriptionAsAdmin();
    // Act
    System.runAs(adminUser) {
      JobDescriptionActionsController.resetConsumptionModel(description.Id);
    }
    // Assert
    final JobDescription__c result = reload(description.Id);
    Assert.areEqual(ApexJobConstant.UNKNOWN_MAX_CHUNK_SIZE, result.MaxChunkSize__c);
    Assert.areEqual(0, result.ConsecutiveFailures__c);
  }

  @IsTest
  static void givenNullRecordId_whenResetConsumptionModel_thenAuraHandledExceptionThrown() {
    // Arrange
    AuraHandledException caught;
    // Act
    try {
      JobDescriptionActionsController.resetConsumptionModel(null);
    } catch (AuraHandledException e) {
      caught = e;
    }
    // Assert
    Assert.isNotNull(caught);
  }
}
