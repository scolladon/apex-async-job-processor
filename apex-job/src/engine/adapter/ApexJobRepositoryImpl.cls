@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobRepositoryImpl implements ApexJobRepository {
  public JobRequest__c insertJobRequest(final JobRequest__c jobRequest) {
    insert jobRequest;
    return jobRequest;
  }

  public JobRequest__c updateJobRequest(final JobRequest__c jobRequest) {
    update jobRequest;
    return jobRequest;
  }

  public JobDescription__c insertJobDescription(final JobDescription__c jobDescription) {
    insert jobDescription;
    return jobDescription;
  }

  public JobDescription__c updateJobDescription(final JobDescription__c jobDescription) {
    update jobDescription;
    return jobDescription;
  }

  public JobDescription__c upsertJobDescriptionByProcessorName(final JobDescription__c jobDescription) {
    upsert jobDescription ProcessorName__c;
    return jobDescription;
  }
}
