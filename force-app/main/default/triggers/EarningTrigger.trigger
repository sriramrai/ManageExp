trigger EarningTrigger on Earning__c(
  after insert,
  after update,
  before delete
) {
  if (ApexUtilityClass.isTriggerDisabled()) {
    return;
  }
  EarningTriggerHandler eHandler = new EarningTriggerHandler(
    Trigger.new,
    Trigger.newMap,
    Trigger.old,
    Trigger.oldMap
  );

  if (Trigger.isAfter) {
    if (Trigger.isInsert) {
      eHandler.handleAfterInsert();
    }
    if (Trigger.isUpdate) {
      eHandler.handleAfterUpdate();
    }
  }

  if (Trigger.isBefore) {
    if (Trigger.isDelete) {
      eHandler.handleBeforeDelete();
    }
  }
}
