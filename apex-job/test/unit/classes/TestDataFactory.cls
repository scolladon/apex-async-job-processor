@IsTest
public without sharing class TestDataFactory {
  public static final String TRIGGER_BYPASS_USERNAME = 'test.user@ajp.io';
  private static final String MINIMUM_ACCESS_PROFILE = 'Minimum Access - Salesforce';
  private static final String SYSTEM_ADMINISTRATOR_PROFILE = 'System Administrator';
  private static final String BYPASS_TRIGGER_PERMISSION = 'Bypass_JobRequest_Trigger';
  static Integer identifier = 1;

  public static User createUserWithTriggerBypass() {
    final User runningUser = insertAdminUser();
    grantCustomPermission(runningUser.Id, BYPASS_TRIGGER_PERMISSION);
    return runningUser;
  }

  public static User createMinimumAccessUser() {
    final String uniqueName = 'min.access.' + UUID.randomUUID() + '@ajp.io';
    final User minimumAccessUser = new User(
      FirstName = 'Minimum',
      LastName = 'Access',
      Email = uniqueName,
      Username = uniqueName,
      Alias = 'minacc',
      TimeZoneSidKey = 'Europe/Paris',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = :MINIMUM_ACCESS_PROFILE WITH SYSTEM_MODE]
      .Id
    );
    insert as system minimumAccessUser;
    return minimumAccessUser;
  }

  public static User createMinimumAccessUserWithCustomPermission(final String customPermissionName) {
    final User minimumAccessUser = createMinimumAccessUser();
    grantCustomPermission(minimumAccessUser.Id, customPermissionName);
    return minimumAccessUser;
  }

  private static User insertAdminUser() {
    final User runningUser = new User(
      FirstName = 'Test',
      LastName = 'User',
      Email = TRIGGER_BYPASS_USERNAME,
      Username = TRIGGER_BYPASS_USERNAME,
      Alias = 'testuser',
      TimeZoneSidKey = 'Europe/Paris',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = :SYSTEM_ADMINISTRATOR_PROFILE WITH SYSTEM_MODE]
      .Id
    );
    insert as system runningUser;
    return runningUser;
  }

  private static void grantCustomPermission(final Id userId, final String customPermissionName) {
    final PermissionSet permissionSet = new PermissionSet(Name = 'Grant_' + customPermissionName, Label = 'Grant ' + customPermissionName);
    insert as system permissionSet;

    final CustomPermission customPermission = [SELECT Id FROM CustomPermission WHERE DeveloperName = :customPermissionName WITH SYSTEM_MODE LIMIT 1];
    insert as system new SetupEntityAccess(SetupEntityId = customPermission.Id, ParentId = permissionSet.Id);

    insert as system new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = permissionSet.Id);
  }

  public static String generateUniqueFakeId(Schema.SObjectType sot) {
    String result = String.valueOf(identifier++);
    return sot.getDescribe().getKeyPrefix() + '0'.repeat(12 - result.length()) + result;
  }

  public static Object build(final Type sobjectType, final Map<String, Object> data) {
    for (String fieldName : data.keySet()) {
      final Object fieldValue = data.get(fieldName);
      if (fieldValue instanceof List<SObject>) {
        List<Map<String, Object>> serializedChildren = new List<Map<String, Object>>();
        for (SObject child : (List<SObject>) fieldValue) {
          serializedChildren.add((Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(child)));
        }
        data.put(fieldName, new Map<String, Object>{ 'totalSize' => ((List<Object>) fieldValue).size(), 'done' => true, 'records' => serializedChildren });
      } else if (fieldValue instanceof List<Object>) {
        List<Map<String, Object>> serializedChildren = new List<Map<String, Object>>();
        for (Object child : (List<Object>) fieldValue) {
          serializedChildren.add((Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(child)));
        }
        data.put(fieldName, serializedChildren);
      } else if (fieldValue instanceof SObject) {
        data.put(fieldName, (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(fieldValue)));
      }
    }
    return JSON.deserialize(JSON.serialize(data), sobjectType);
  }
}
