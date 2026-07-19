public without sharing class TransactionItemTriggerHandler {
  List<Transaction_Item__c> newList = new List<Transaction_Item__c>();
  List<Transaction_Item__c> oldList = new List<Transaction_Item__c>();
  Map<Id, Transaction_Item__c> newMap = new Map<Id, Transaction_Item__c>();
  Map<Id, Transaction_Item__c> oldMap = new Map<Id, Transaction_Item__c>();
  public TransactionItemTriggerHandler() {
  }

  public TransactionItemTriggerHandler(
    List<Transaction_Item__c> newList,
    List<Transaction_Item__c> oldList,
    Map<Id, Transaction_Item__c> newMap,
    Map<Id, Transaction_Item__c> oldMap
  ) {
    this.newList = newList;
    this.oldList = oldList;
    this.newMap = newMap;
    this.oldMap = oldMap;
  }

  public void afterInsert() {
    sendEvent(newList);
  }

  public void afterUpdate() {
    sendEvent(newList);
  }

  public void afterDelete() {
    sendEvent(oldList);
  }

  private void sendEvent(List<Transaction_Item__c> newList) {
    if (newList.size() > 0) {
      Transaction_Updator__e event = new Transaction_Updator__e();
      event.Updated__c = true;
      Database.SaveResult sr = EventBus.publish(event);
    }
  }
}
