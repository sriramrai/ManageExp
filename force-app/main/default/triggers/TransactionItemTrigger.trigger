trigger TransactionItemTrigger on Transaction_Item__c(
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
