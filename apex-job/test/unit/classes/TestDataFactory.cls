@isTest
public without sharing class TestDataFactory {
  static Integer identifier = 1;
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
