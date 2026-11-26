// Give every runnable request that has no NextExecutionDateTime__c its CreatedDate, so it stays a candidate:
// a null date now means "not scheduled". Handles 10,000 requests per run, so re-run until it reports 0.
// Run with: sf apex run -f scripts/apex/backfill-next-execution.apex -o <org-alias>

final List<JobRequest__c> requests = [
  SELECT Id, CreatedDate
  FROM JobRequest__c
  WHERE NextExecutionDateTime__c = NULL AND Status__c IN ('READY', 'FAILURE', 'KILLED')
  LIMIT 10000
];
for (JobRequest__c request : requests) {
  request.NextExecutionDateTime__c = request.CreatedDate;
}
update requests;
System.debug(LoggingLevel.INFO, 'Backfilled requests: ' + requests.size());
