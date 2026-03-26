trigger InvestmentTrigger on Investment__c (before insert, after insert) {
    if(ApexUtilityClass.isTriggerDisabled()) {
        return;
    }
    if(trigger.isBefore) {
        InvestmentTriggerHandler.handleBeforeInsert(trigger.new);
    }
    if(trigger.isAfter) {
        InvestmentTriggerHandler.handleAfterInsert(trigger.new);
    }
}