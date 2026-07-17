public with sharing class EarningTriggerHandler {
  List<Earning__c> newList = new List<Earning__c>();
  List<Earning__c> oldList = new List<Earning__c>();
  Map<Id, Earning__c> newMap = new Map<Id, Earning__c>();
  Map<Id, Earning__c> oldMap = new Map<Id, Earning__c>();

  public EarningTriggerHandler() {
  }

  public EarningTriggerHandler(
    List<Earning__c> newList,
    Map<Id, Earning__c> newMap,
    List<Earning__c> oldList,
    Map<Id, Earning__c> oldMap
  ) {
    this.newList = newList;
    this.oldList = oldList;
    this.newMap = newMap;
    this.oldMap = oldMap;
  }

  public void handleBeforeDelete() {
  }

  public void handleAfterInsert() {
    createTransactions();
  }

  public void handleAfterUpdate() {
  }

  public Map<String, Id> getTransactionById() {
    Map<String, Id> bankById = new Map<String, Id>();
    List<Transaction__c> txns = new List<Transaction__c>(
      [SELECT Id, Name FROM Transaction__c]
    );
    for (Transaction__c txn : txns) {
      bankById.put(txn.Name, txn.Id);
    }
    return bankById;
  }
  private void createTransactions() {
    List<Transaction_Item__c> newTnxs = new List<Transaction_Item__c>();
    Map<String, Id> transactionNameById = getTransactionById();
    if (transactionNameById.keySet().isEmpty()) {
      return;
    }
    for (Earning__c earn : newList) {
      Transaction_Item__c tnxSal = new Transaction_Item__c();
      tnxSal.Transaction__c = transactionNameById.get('HDFC');
      tnxSal.Date__c = earn.Credit_Date__c;
      tnxSal.Description__c =
        'Salary Credited for ' +
        earn.Month__c +
        ' ' +
        earn.Credit_Date__c.year();
      tnxSal.Type__c = 'Credit';
      tnxSal.Source_Record_Id__c = earn.Id;
      tnxSal.Amount__c = earn.Net_In_Hand__c;

      Transaction_Item__c tnxPluxee = new Transaction_Item__c();
      tnxPluxee.Transaction__c = transactionNameById.get('Pluxee');
      tnxPluxee.Date__c = earn.Credit_Date__c;
      tnxPluxee.Description__c =
        'Food Coupen Alloted for ' +
        earn.Month__c +
        ' ' +
        earn.Credit_Date__c.year();
      tnxPluxee.Type__c = 'Credit';
      tnxPluxee.Source_Record_Id__c = earn.Id;
      tnxPluxee.Amount__c = 2000;
      newTnxs.add(tnxSal);
      newTnxs.add(tnxPluxee);
    }

    try {
      if (!newTnxs.isEmpty()) {
        insert newTnxs;
      }
    } catch (Exception exp) {
      throw exp;
    }
  }
}
