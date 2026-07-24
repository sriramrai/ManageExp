public without sharing class TransactionItemTriggerHandler {
  private List<Transaction_Item__c> newList;
  private List<Transaction_Item__c> oldList;
  private Map<Id, Transaction_Item__c> newMap;
  private Map<Id, Transaction_Item__c> oldMap;

  // Prevent recursion
  private static Boolean isCreatingCreditTransactions = false;

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

  public void beforeInsert() {
    modifyTransactionType();
  }

  public void beforeUpdate() {
    modifyTransactionType();
  }

  public void afterInsert() {
    if (!isCreatingCreditTransactions) {
      createCreditTransactions(newList);
    }

    sendEvent(newList);
  }

  public void afterUpdate() {
    List<Transaction_Item__c> transactionsToProcess = new List<Transaction_Item__c>();

    for (Transaction_Item__c tnx : newList) {
      Transaction_Item__c oldTnx = oldMap.get(tnx.Id);

      Boolean shouldCreate = false;

      // Became Debit because user selected A/C Transfer
      if (oldTnx.Type__c != 'Debit' && tnx.Type__c == 'Debit') {
        shouldCreate = true;
      }

      // Destination account changed
      if (tnx.Type__c == 'Debit' && oldTnx.To_Account__c != tnx.To_Account__c) {
        shouldCreate = true;
      }

      if (shouldCreate) {
        transactionsToProcess.add(tnx);
      }
    }

    if (!isCreatingCreditTransactions && !transactionsToProcess.isEmpty()) {
      createCreditTransactions(transactionsToProcess);
    }

    sendEvent(newList);
  }

  public void afterDelete() {
    sendEvent(oldList);
  }

  private void modifyTransactionType() {
    for (Transaction_Item__c tnx : newList) {
      if (
        String.isNotBlank(tnx.Type__c) &&
        tnx.Type__c.equalsIgnoreCase('A/C Transfer') &&
        String.isNotBlank(tnx.To_Account__c)
      ) {
        tnx.Type__c = 'Debit';
      }
    }
  }

  private void createCreditTransactions(List<Transaction_Item__c> records) {
    if (records.isEmpty()) {
      return;
    }

    isCreatingCreditTransactions = true;

    Map<String, Id> transactionMap = getTransactionIdByTransactionName();

    List<Transaction_Item__c> creditTransactions = new List<Transaction_Item__c>();

    for (Transaction_Item__c tnx : records) {
      if (
        tnx.Type__c == 'Debit' &&
        String.isNotBlank(tnx.To_Account__c) &&
        transactionMap.containsKey(tnx.To_Account__c)
      ) {
        Transaction_Item__c credit = new Transaction_Item__c();

        credit.Transaction__c = transactionMap.get(tnx.To_Account__c);
        credit.Date__c = tnx.Date__c;
        credit.Amount__c = tnx.Amount__c;
        credit.Description__c = tnx.Description__c;
        credit.Type__c = 'Credit';

        creditTransactions.add(credit);
      }
    }

    if (!creditTransactions.isEmpty()) {
      insert creditTransactions;
    }

    isCreatingCreditTransactions = false;
  }

  private Map<String, Id> getTransactionIdByTransactionName() {
    Map<String, Id> result = new Map<String, Id>();

    for (Transaction__c t : [
      SELECT Id, Name
      FROM Transaction__c
    ]) {
      result.put(t.Name, t.Id);
    }

    return result;
  }

  private void sendEvent(List<Transaction_Item__c> records) {
    if (!records.isEmpty()) {
      Transaction_Updator__e event = new Transaction_Updator__e();
      event.Updated__c = true;

      EventBus.publish(event);
    }
  }
}
