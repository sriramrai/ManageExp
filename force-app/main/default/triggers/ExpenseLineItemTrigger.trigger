trigger ExpenseLineItemTrigger on Expense_Line_Item__c(
  after insert,
  after update,
  before delete
) {
  if (ApexUtilityClass.isTriggerDisabled()) {
    return;
  }
  ExpenseLineItemTriggerHandler ehandler = new ExpenseLineItemTriggerHandler();
  if (Trigger.isAfter) {
    System.debug('===Expense Line Item Trigger Started====');
    if (Trigger.isInsert) {
      ehandler.handleAfterInsert(Trigger.new);
    }
    if (Trigger.isUpdate) {
      ehandler.handleAfterUpdate(Trigger.new, Trigger.oldMap, Trigger.newMap);
    }
  }
  if (Trigger.isBefore) {
    if (Trigger.isDelete) {
      ehandler.handleBeforeDelete(Trigger.old, Trigger.oldMap);
    }
  }
}
