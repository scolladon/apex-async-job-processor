@IsTest
private class JobMonitorControllerTest {
  private static final Integer PAGE_SIZE = 10;
  private static final Integer FIRST_OFFSET = 0;

  @IsTest
  static void givenDeletedRunnableRequest_whenGetJobRequestPage_thenDeletedRequestIsNotReturned() {
    // Arrange
    final JobDescription__c description = ApexJobTestFixture.aJobDescription().build();
    insert description;
    final JobRequest__c kept = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    final JobRequest__c deleted = ApexJobTestFixture.aJobRequest().withJobDescription(description.Id).build();
    insert new List<JobRequest__c>{ kept, deleted };
    delete deleted;

    // Act
    final List<JobRequest__c> result = JobMonitorController.getJobRequestPage(PAGE_SIZE, FIRST_OFFSET);

    // Assert
    final Map<Id, JobRequest__c> resultById = new Map<Id, JobRequest__c>(result);
    Assert.isTrue(resultById.containsKey(kept.Id), 'Should return the kept request');
    Assert.isFalse(resultById.containsKey(deleted.Id), 'Should not return the deleted request');
  }
}
