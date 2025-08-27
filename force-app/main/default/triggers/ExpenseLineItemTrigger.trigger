trigger ExpenseLineItemTrigger on Expense_Line_Item__c (after insert, after update) {
    ExpenseLineItemTriggerHandler ehandler = new ExpenseLineItemTriggerHandler();
    if(trigger.isAfter) {
        if(trigger.isInsert) {
            ehandler.handleAfterInsert(trigger.new);
        }
        if(trigger.isUpdate) {
            //ehandler.handleAfterUpdate(trigger.new, trigger.oldMap);
        }
    }
}