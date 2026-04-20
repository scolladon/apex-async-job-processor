// Kill any existing "Async Job Watcher" cron triggers and reschedule fresh ones.
// Cron-job name literal: 'Async Job Watcher%' — must match ApexJobWatcher.schedule().
// Run with: sf apex run -f scripts/apex/restart-watcher.apex -o dev-async-processor

for (CronTrigger ct : [
  SELECT Id
  FROM CronTrigger
  WHERE CronJobDetail.JobType = '7' AND CronJobDetail.Name LIKE 'Async Job Watcher%'
]) {
  System.abortJob(ct.Id);
}
ApexJobWatcher.schedule();
