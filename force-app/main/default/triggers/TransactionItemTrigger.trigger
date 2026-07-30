trigger TransactionItemTrigger on Transaction_Item__c(
  before insert,
  before update,
  before delete,
  after insert,
  after update,
  after delete
) {
  TransactionItemTriggerHandler tHandler = new TransactionItemTriggerHandler(
    Trigger.new,
    Trigger.old,
    Trigger.newMap,
    Trigger.oldMap
  );
  if (ApexUtilityClass.isTriggerDisabled()) {
    return;
  }
  if (Trigger.isBefore) {
    if (Trigger.isInsert) {
      tHandler.beforeInsert();
    } else if (Trigger.isUpdate) {
      tHandler.beforeUpdate();
    } else if (Trigger.isDelete) {
      //tHandler.beforeDelete();
    }
  }
  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      tHandler.afterInsert();
    } else if (Trigger.isUpdate) {
      tHandler.afterUpdate();
    } else if (Trigger.isDelete) {
      tHandler.afterDelete();
    }
  }
}
