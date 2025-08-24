public interface JobSelector {
  JobRequest__c[] getEligibleJobs(List<Id> jobDescriptionToExclude);
}
