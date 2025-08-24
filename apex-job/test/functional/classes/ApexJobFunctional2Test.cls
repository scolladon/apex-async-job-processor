/**
 * @description Functional test implementation of ApexJob that consumes 25% of max CPU time
 * and logs the nextExecutionDateTime from the JobRequest argument
 */
public with sharing class ApexJobFunctional2Test extends ApexJobFunctionalBaseTest {
  public ApexJobFunctional2Test() {
    this.consumptionPercentage = 0.10;
  }
}
