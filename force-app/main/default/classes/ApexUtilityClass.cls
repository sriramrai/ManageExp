public with sharing class ApexUtilityClass {
  public ApexUtilityClass() {
  }

  public static Boolean isTriggerDisabled() {
    Automation_Switch__c automationSwitch = Automation_Switch__c.getInstance();
    return automationSwitch.Disable_Trigger__c;
  }
}
