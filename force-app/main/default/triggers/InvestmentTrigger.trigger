trigger InvestmentTrigger on Investment__c (before insert, after insert) {
    if(ApexUtilityClass.isTriggerDisabled()) {
        return;
    }

    InvestmentTriggerHandler handler = new InvestmentTriggerHandler();
    handler.init(trigger.new);

    if(trigger.isBefore) {
        if(trigger.isInsert) {
            handler.handleBeforeInsert();
        }
    }
    if(trigger.isAfter) {
        if(trigger.isInsert) {  
            handler.handleAfterInsert(); 
        }  
    }
}