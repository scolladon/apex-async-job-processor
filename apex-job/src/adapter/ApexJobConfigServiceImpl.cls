@SuppressWarnings('PMD.ApexCRUDViolation')
public without sharing class ApexJobConfigServiceImpl implements ApexJobConfigService {
  private static final Integer MAX_ENQUEUE_DELAY_IN_MINUTES = 10;
  private static final Integer MIN_ENQUEUE_DELAY_IN_MINUTES = 0;
  private static final Integer DEFAULT_IDLE_ENQUEUE_DELAY_IN_MINUTES = 1;

  private static ApexJobConfig__c configInstance {
    get {
      if (configInstance == null) {
        configInstance = ApexJobConfig__c.getInstance();
      }
      return configInstance;
    }
    private set;
  }

  public Boolean isSystemEnabled() {
    return configInstance?.Enabled__c == true;
  }

  public Integer getEnqueueDelayInMinutes() {
    Integer enqueueDelayInMinutes = DEFAULT_IDLE_ENQUEUE_DELAY_IN_MINUTES;

    if (this.nowOutsideBusinessHours()) {
      enqueueDelayInMinutes = Integer.valueOf(configInstance?.EnqueueDelayOutsideBusinessHours__c ?? DEFAULT_IDLE_ENQUEUE_DELAY_IN_MINUTES);
    }

    enqueueDelayInMinutes = Math.max(Math.min(enqueueDelayInMinutes, MAX_ENQUEUE_DELAY_IN_MINUTES), MIN_ENQUEUE_DELAY_IN_MINUTES);

    return enqueueDelayInMinutes;
  }

  private Boolean nowOutsideBusinessHours() {
    final BusinessHours defaultBusinessHours = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE AND IsActive = TRUE];
    return defaultBusinessHours == null || !BusinessHours.isWithin(defaultBusinessHours.Id, Datetime.now());
  }
}
