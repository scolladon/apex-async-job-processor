public without sharing class JobRepositoryImpl implements JobRepository {
  private ApexJobFactory factory;

  public JobRepositoryImpl() {
    this(new ApexJobFactoryImpl());
  }

  @TestVisible
  private JobRepositoryImpl(final ApexJobFactory factory) {
    this.factory = factory;
  }

  public JobCandidate[] getJobCandidates(final List<JobExecuted> executedJobs) {
    if (Limits.getLimitQueries() - Limits.getQueries() < 2) {
      // At least one query to get eligible jobs
      return new List<JobCandidate>();
    }
    final List<Id> jobDescriptionToExclude = JobRepositoryImpl.extractDescriptionIds(executedJobs);
    final List<JobRequest__c> eligibleJobs = this.factory.getSelector().getEligibleJobs(jobDescriptionToExclude);
    return JobRepositoryImpl.buildCandidates(eligibleJobs);
  }

  private static List<Id> extractDescriptionIds(final List<JobExecuted> executedJobs) {
    if (executedJobs.isEmpty()) {
      return new List<Id>();
    }
    final List<Id> jobDescriptionIds = new List<Id>();
    final Integer executedJobsNumber = executedJobs.size();
    for (Integer i = 0; i < executedJobsNumber; ++i) {
      final JobExecuted executedJob = executedJobs[i];
      final JobDescription__c jobDescription = executedJob.jobDescription;
      jobDescriptionIds.add(jobDescription.Id);
    }
    return jobDescriptionIds;
  }

  private static List<JobCandidate> buildCandidates(final List<JobRequest__c> eligibleJobs) {
    final Map<Id, List<JobRequest__c>> jobPerDescription = JobRepositoryImpl.groupJobsByDescription(eligibleJobs);
    final List<JobCandidate> jobCandidates = new List<JobCandidate>();
    final List<Id> jobDescriptionIds = new List<Id>(jobPerDescription.keySet());
    final Integer jobDescriptionIdsNumber = jobDescriptionIds.size();
    for (Integer i = 0; i < jobDescriptionIdsNumber; ++i) {
      final List<JobRequest__c> jobRequests = jobPerDescription.get(jobDescriptionIds[i]);
      final JobCandidate jobCandidate = new JobCandidate(jobRequests);
      jobCandidates.add(jobCandidate);
    }
    return jobCandidates;
  }

  private static Map<Id, List<JobRequest__c>> groupJobsByDescription(final List<JobRequest__c> jobs) {
    final Map<Id, List<JobRequest__c>> jobPerDescription = new Map<Id, List<JobRequest__c>>();
    final Integer jobsNumber = jobs.size();
    for (Integer i = 0; i < jobsNumber; ++i) {
      JobRequest__c job = jobs[i];
      if (!jobPerDescription.containsKey(job.JobDescription__c)) {
        jobPerDescription.put(job.JobDescription__c, new List<JobRequest__c>());
      }
      jobPerDescription.get(job.JobDescription__c).add(job);
    }
    return jobPerDescription;
  }

  public void recordJobExecution(final List<JobExecuted> executedJobs) {
    final Integer executedJobsSize = executedJobs.size();
    if (executedJobsSize == 0) {
      return;
    }
    final List<JobRequest__c> jobsToDelete = new List<JobRequest__c>();
    final List<JobRequest__c> jobsToUpdate = new List<JobRequest__c>();
    final List<SObject> recordsToUpdate = new List<SObject>();
    for (Integer i = 0; i < executedJobsSize; ++i) {
      final JobExecuted executedJob = executedJobs[i];
      final List<JobRequest__c> executedJobRequests = executedJob.jobRequests;
      final Integer executedJobRequestsSize = executedJobRequests.size();
      executedJob.stageExecution();
      for (Integer j = 0; j < executedJobRequestsSize; ++j) {
        final JobRequest__c job = executedJobRequests[j];
        jobsToUpdate.add(job); // add it to update the metrics, even if they should be deleted
        if (JobRepositoryImpl.shouldDeleteJobRequest(job)) {
          jobsToDelete.add(job);
        }
      }
      recordsToUpdate.add(executedJob.jobDescription);
    }
    recordsToUpdate.addAll(jobsToUpdate);
    Database.update(recordsToUpdate, false, AccessLevel.SYSTEM_MODE);
    Database.delete(jobsToDelete, false, AccessLevel.SYSTEM_MODE);
  }

  // TODO part of the JobRequest Domain
  private static Boolean shouldDeleteJobRequest(final JobRequest__c jobRequest) {
    return jobRequest.Status__c == ApexJobStatus.SUCCESS.name();
  }
}
