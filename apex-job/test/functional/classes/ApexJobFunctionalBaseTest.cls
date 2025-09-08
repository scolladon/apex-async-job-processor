/**
 * @description Functional test implementation of ApexJob that consumes x% of max CPU time
 * 20% of the time, the consumption is halved up or down to bring more variability
 * and logs the nextExecutionDateTime from the JobRequest argument
 */
public without sharing abstract class ApexJobFunctionalBaseTest implements ApexJob {
  protected Decimal consumptionPercentage;
  protected ApexJobLogger logger = new ApexJobFactoryImpl().getLogger();

  public ApexJobResult execute(final ApexJobContext apexJobContext) {
    final String instanceName = String.valueOf(this).split(':')[0];
    // 20% of the time, the consumption is halved up or down to bring more variability
    final Decimal entropicMultiplier = Math.random() < 0.2 ? (Math.random() < 0.5 ? 0.9 : 1.1) : 1;

    // Burn time
    final Integer targetCpuTime = (Integer) (Limits.getLimitCpuTime() * this.consumptionPercentage * entropicMultiplier) * ApexJobContext.arguments.size();
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

    // Kill the job 5% of the time
    if (Math.random() < 0.05) {
      for (;;) {
        Math.sqrt(2 * 2 + 1);
      }
    }

    this.logger.debug(instanceName + '(' + UUID.randomUUID() + ') - Job completed successfully ' + nextExecutionDateTimes);
    return new ApexJobResult(ApexJobStatus.SUCCESS);
  }

  public class ApexJobFunctionalException extends Exception {
  }
}
