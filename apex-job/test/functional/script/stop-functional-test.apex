// Stop Functional Test Script
// This script aborts all running AsyncApexJobExecutor jobs from the queue       
ApexJobConfig__c orgConfig = ApexJobConfig__c.getOrgDefaults();
orgConfig.Enabled__c = false;
orgConfig.EnqueueDelayOutsideBusinessHours__c = 1;
upsert orgConfig;
