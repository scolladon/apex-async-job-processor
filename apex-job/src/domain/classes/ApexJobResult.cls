public without sharing class ApexJobResult {
  public final ApexJobStatus status { get; private set; }
  public final ApexJobError error { get; private set; }
  public LimitsUsage consumedLimits { get; set; }

  public ApexJobResult(final ApexJobStatus status) {
    this(status, null);
  }

  public ApexJobResult(final ApexJobStatus status, final ApexJobError error) {
    this.status = status;
    this.error = error;
  }

  public ApexJobResult(final Exception ex) {
    this(ApexJobStatus.FAILURE, new ApexJobResult.ApexJobError(ex));
  }

  public class ApexJobError {
    public final String message { get; private set; }
    public final String stackTrace { get; private set; }

    public ApexJobError(final String message, final String stackTrace) {
      this.message = message;
      this.stackTrace = stackTrace;
    }

    public ApexJobError(final Exception ex) {
      this(ex.getMessage(), ex.getStackTraceString());
    }

    public override String toString() {
      List<String> messages = new List<String>();
      if (String.isNotBlank(this.message)) {
        messages.add(this.message);
      }
      if (String.isNotBlank(this.stackTrace)) {
        messages.add(this.stackTrace);
      }
      return String.join(messages, '\n');
    }
  }
}
