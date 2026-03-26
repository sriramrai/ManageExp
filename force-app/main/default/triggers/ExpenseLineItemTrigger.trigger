trigger ExpenseLineItemTrigger on Expense_Line_Item__c (after insert, after update) {
    if(ApexUtilityClass.isTriggerDisabled()) {
        return;
    }
    ExpenseLineItemTriggerHandler ehandler = new ExpenseLineItemTriggerHandler();
    if(trigger.isAfter) {
        System.debug('===Expense Line Item Trigger Started====');
        if(trigger.isInsert) {
            ehandler.handleAfterInsert(trigger.new);
        }
        if(trigger.isUpdate) {
            ehandler.handleAfterUpdate(trigger.new, trigger.oldMap);
        }
    }
}