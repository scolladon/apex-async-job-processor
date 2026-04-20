public without sharing class JobRequestArgumentParser {
  public ParseResult parse(final List<JobRequest__c> jobRequests) {
    final ParseResult result = new ParseResult();
    final Integer size = jobRequests.size();
    for (Integer i = 0; i < size; ++i) {
      final JobRequest__c job = jobRequests[i];
      try {
        result.validArguments.add(JobRequestArgumentParser.parseOne(job));
      } catch (Exception e) {
        result.malformedErrors.put(job.Id, e.getMessage());
      }
    }
    return result;
  }

  private static Object parseOne(final JobRequest__c job) {
    if (String.isBlank(job.Argument__c)) {
      return null;
    }
    return JSON.deserializeUntyped(job.Argument__c);
  }

  public class ParseResult {
    public List<Object> validArguments { get; private set; }
    public Map<Id, String> malformedErrors { get; private set; }

    public ParseResult() {
      this.validArguments = new List<Object>();
      this.malformedErrors = new Map<Id, String>();
    }
  }
}
