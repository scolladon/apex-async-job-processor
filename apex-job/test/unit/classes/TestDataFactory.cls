@IsTest
public without sharing class TestDataFactory {
  public static final String TRIGGER_BYPASS_USERNAME = 'test.user@ajp.io';
  static Integer identifier = 1;

  public static User createUserWithTriggerBypass() {
    final User runningUser = insertAdminUser();
    grantTriggerBypass(runningUser.Id);
    return runningUser;
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
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator']
      .Id
    );
    insert runningUser;
    return runningUser;
  }

  private static void grantTriggerBypass(final Id userId) {
    final PermissionSet byPassTriggersPermissionSet = new PermissionSet(Name = 'ByPassTriggers', Label = 'ByPass Triggers');
    insert byPassTriggersPermissionSet;

    final CustomPermission byPassTriggerCustomPermission = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'Bypass_JobRequest_Trigger' LIMIT 1];
    insert new SetupEntityAccess(SetupEntityId = byPassTriggerCustomPermission.Id, ParentId = byPassTriggersPermissionSet.Id);

    insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = byPassTriggersPermissionSet.Id);
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
