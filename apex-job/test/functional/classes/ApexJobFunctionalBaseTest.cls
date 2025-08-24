/**
 * @description Functional test implementation of ApexJob that consumes 25% of max CPU time
 * and logs the nextExecutionDateTime from the JobRequest argument
 */
public without sharing abstract class ApexJobFunctionalBaseTest implements ApexJob {
  protected Decimal consumptionPercentage;
  protected ApexJobLogger logger = new ApexJobFactoryImpl().getLogger();

  public ApexJobResult execute(final ApexJobContext apexJobContext) {
    final String instanceName = String.valueOf(this).split(':')[0];

    // Burn time
    final Integer targetCpuTime = (Integer) (Limits.getLimitCpuTime() * this.consumptionPercentage) * ApexJobContext.arguments.size();
    final Integer startCpuTime = Limits.getCpuTime();
    while ((Limits.getCpuTime() - startCpuTime) < targetCpuTime) {
      for (Integer i = 0; i < 1000; i++) {
        Math.sqrt(i * 2 + 1);
      }
    }

    // Simulate random exception
    if (Math.random() < this.consumptionPercentage) {
      final String exceptionMessage = instanceName + ' - Random failure for testing purposes';
      this.logger.error(exceptionMessage);
      throw new ApexJobFunctionalException(exceptionMessage);
    }

    // Display arguments
    List<Datetime> nextExecutionDateTimes = new List<Datetime>();
    for (Object argument : apexJobContext.arguments) {
      final String serializedDatetimeArgument = '' + argument;
      nextExecutionDateTimes.add((Datetime) JSON.deserialize(serializedDatetimeArgument, Datetime.class));
    }
    this.logger.debug(instanceName + '(' + UUID.randomUUID() + ') - Job completed successfully ' + nextExecutionDateTimes);
    return new ApexJobResult(ApexJobStatus.SUCCESS);
  }

  public class ApexJobFunctionalException extends Exception {
  }
}
