public interface ApexJobRepository {
  JobRequest__c insertJobRequest(final JobRequest__c jobRequest);
  JobRequest__c updateJobRequest(final JobRequest__c jobRequest);

  JobDescription__c insertJobDescription(final JobDescription__c jobDescription);
  JobDescription__c updateJobDescription(final JobDescription__c jobDescription);
  JobDescription__c upsertJobDescriptionByProcessorName(final JobDescription__c jobDescription);
}
