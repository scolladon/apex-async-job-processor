/**
 * @description Functional test implementation of ApexJob that consumes 25% of max CPU time
 * and logs the nextExecutionDateTime from the JobRequest argument
 */
public with sharing class ApexJobFunctional5Test extends ApexJobFunctionalBaseTest {
  public ApexJobFunctional5Test() {
    this.consumptionPercentage = 0.25;
  }
}
