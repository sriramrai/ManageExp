trigger InvestmentLineTrigger on Investment_Line_Items__c (after insert, after update) {
    if(trigger.isAfter) {
        if(trigger.isInsert) {
            InvestmentLineTriggerHandler.handleAfterInsert(trigger.new);
        }else if(trigger.isUpdate) {
            InvestmentLineTriggerHandler.handleAfterUpdate(trigger.new, trigger.oldMap);
        }
    }
}