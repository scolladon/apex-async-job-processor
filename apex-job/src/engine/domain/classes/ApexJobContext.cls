public without sharing class ApexJobContext {
  public final List<Object> arguments { get; private set; }

  public ApexJobContext(final List<Object> arguments) {
    this.arguments = arguments;
  }
}
