trigger JobRequestAfterInsert on JobRequest__c (after insert) {
    if(!FeatureManagement.checkPermission('Bypass_JobRequest_Trigger')) {
        new ApexJobFactoryImpl().getSpawner().enqueue(0);
    }
}