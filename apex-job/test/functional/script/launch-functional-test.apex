// Launch Functional Test Script
// This script enqueues the AsyncApexJobExecutor to start processing functional test jobs
ApexJobConfig__c orgConfig = ApexJobConfig__c.getOrgDefaults();
orgConfig.Enabled__c = true;
orgConfig.EnqueueDelayOutsideBusinessHours__c = 1;
upsert orgConfig;
Id jobId = System.enqueueJob(new AsyncApexJobExecutor());