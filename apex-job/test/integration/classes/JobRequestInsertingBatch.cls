@IsTest
public class JobRequestInsertingBatch implements Database.Batchable<SObject> {
  private static final Integer INSERT_COUNT = 2;
  private final Id descriptionId;

  public JobRequestInsertingBatch(final Id descriptionId) {
    this.descriptionId = descriptionId;
  }

  public Database.QueryLocator start(final Database.BatchableContext context) {
    return Database.getQueryLocator([SELECT Id FROM JobDescription__c WHERE Id = :descriptionId]);
  }

  public void execute(final Database.BatchableContext context, final List<SObject> scope) {
    for (Integer i = 0; i < INSERT_COUNT; ++i) {
      insertRequest();
    }
  }

  public void finish(final Database.BatchableContext context) {
    return;
  }

  private void insertRequest() {
    insert new JobRequest__c(JobDescription__c = descriptionId, Status__c = ApexJobStatus.READY.name(), Enabled__c = true);
  }
}
