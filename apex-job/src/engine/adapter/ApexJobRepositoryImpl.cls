public without sharing class ApexJobRepositoryImpl implements ApexJobRepository {
  public JobRequest__c insertJobRequest(final JobRequest__c jobRequest) {
    insert as system jobRequest;
    return jobRequest;
  }

  public JobRequest__c updateJobRequest(final JobRequest__c jobRequest) {
    update as system jobRequest;
    return jobRequest;
  }

  public JobDescription__c insertJobDescription(final JobDescription__c jobDescription) {
    insert as system jobDescription;
    return jobDescription;
  }

  public JobDescription__c updateJobDescription(final JobDescription__c jobDescription) {
    update as system jobDescription;
    return jobDescription;
  }

  public JobDescription__c upsertJobDescriptionByProcessorName(final JobDescription__c jobDescription) {
    upsert as system jobDescription ProcessorName__c;
    return jobDescription;
  }
}
