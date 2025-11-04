public with sharing class JobDescriptionActionsController {
  @AuraEnabled
  public static void resetConsumptionModel(final Id recordId) {
    if (recordId == null) {
      throw new AuraHandledException('recordId is required');
    }

    final JobDescription__c job = [
      SELECT ProcessorName__c
      FROM JobDescription__c
      WHERE Id = :recordId
      WITH SECURITY_ENFORCED
      LIMIT 1
    ];

    ApexJobManager.resetConsumptionModel(job.ProcessorName__c);
  }
}
