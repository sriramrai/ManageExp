/* Exense Line Item Trigger Handler */
public without sharing class ExpenseLineItemTriggerHandler {
  Set<String> applicableSource = new Set<String>{ 'Axis CC', 'ICICI CC' };
  Integer AXIS_BILLING_DAY = 18;
  Integer ICICI_BILLING_DAY = 24;
  Integer AXIS_DUE_DATE = 7;
  Integer ICIC_DUE_DATE = 10;

  public void handleAfterInsert(List<Expense_Line_Item__c> newList) {
    List<Expense_Line_Item__c> newExpenses = filterExpenses(newList);
    List<Expense_Line_Item__c> creditExpenses = new List<Expense_Line_Item__c>();
    for (Expense_Line_Item__c exp : newExpenses) {
      if (
        exp.Source__c.equalsIgnoreCase('AXIS CC') ||
        exp.Source__c.equalsIgnoreCase('ICICI CC')
      ) {
        creditExpenses.add(exp);
      }
    }
    createPayments(creditExpenses);
    createTransactions(newExpenses);
  }

  public void handleAfterUpdate(
    List<Expense_Line_Item__c> newList,
    Map<Id, Expense_Line_Item__c> oldMap,
    Map<Id, Expense_Line_Item__c> newMap
  ) {
    List<Expense_Line_Item__c> newExpenses = filterExpenses(newList);
    List<Expense_Line_Item__c> creditExpenses = new List<Expense_Line_Item__c>();
    List<Id> paymentsToBeDeleted = new List<Id>();
    for (Expense_Line_Item__c newExp : newExpenses) {
      Expense_Line_Item__c oldRecord = oldMap.get(newExp.Id);
      if (
        oldRecord.Source__c != newExp.Source__c ||
        oldRecord.EMI_Term__c != newExp.EMI_Term__c
      ) {
        paymentsToBeDeleted.add(newExp.Id);
        if (
          newExp.Source__c.equalsIgnoreCase('AXIS CC') ||
          newExp.Source__c.equalsIgnoreCase('ICICI CC')
        ) {
          creditExpenses.add(newExp);
        }
      }
    }
    deletePayments(paymentsToBeDeleted);
    createPayments(creditExpenses);
    updateTransactions(newExpenses, newMap, oldMap);
  }

  public void handleBeforeDelete(
    List<Expense_Line_Item__c> oldList,
    Map<Id, Expense_Line_Item__c> oldMap
  ) {
    List<Expense_Line_Item__c> oldRecords = filterExpenses(oldList);
    deleteTransactions(oldMap.keySet());
  }

  public void deleteTransactions(Set<Id> expLineIds) {
    List<Transaction_Item__c> tnxToDelete = new List<Transaction_Item__c>(
      [
        SELECT Id
        FROM Transaction_Item__c
        WHERE Source_Record_Id__c IN :expLineIds
      ]
    );
    if (!tnxToDelete.isEmpty()) {
      try {
        delete tnxToDelete;
      } catch (Exception exp) {
        throw exp;
      }
    }
  }

  private Date getDueDate(String source, Date expenseDate, Integer termNumber) {
    Integer billingDay = source.equalsIgnoreCase('AXIS CC')
      ? AXIS_BILLING_DAY
      : ICICI_BILLING_DAY;
    Integer dueDateDay = source.equalsIgnoreCase('AXIS CC')
      ? AXIS_DUE_DATE
      : ICIC_DUE_DATE;
    Integer expenseDay = expenseDate.day();
    Integer expenseMonth = expenseDate.month();
    Integer expenseYear = expenseDate.year();
    Date dueDate = Date.newInstance(expenseYear, expenseMonth, dueDateDay);
    if (expenseDay <= billingDay) {
      dueDate = dueDate.addMonths(termNumber);
    } else {
      dueDate = dueDate.addMonths(termNumber + 1);
    }
    return dueDate;
  }

  private List<Payment__c> getPaymentSchedules(Expense_Line_Item__c exp) {
    List<Payment__c> schedules = new List<Payment__c>();
    Integer termLength = Integer.valueOf(exp.EMI_Term__c.split(' ')[0]);
    for (Integer counter = 1; counter <= termLength; counter++) {
      Payment__c payment = new Payment__c();
      payment.Expense_Line_Item__c = exp.Id;
      payment.Amount__c = termLength == 1
        ? exp.Amount__c
        : ((exp.Amount__c / termLength) +
          ((exp.Amount__c / termLength) * 0.16));
      //payment.Payment_Date__c = exp.Date__c;
      payment.Source__c = exp.Source__c;
      payment.Due_Date__c = getDueDate(exp.Source__c, exp.Date__c, counter);
      payment.Description__c =
        '(' +
        String.valueOf(counter) +
        '/' +
        String.valueOf(termLength) +
        ') - ' +
        exp.Details__c;
      schedules.add(payment);
    }
    return schedules;
  }

  private void createPayments(List<Expense_Line_Item__c> newExpenses) {
    List<Payment__c> payments = new List<Payment__c>();
    for (Expense_Line_Item__c exp : newExpenses) {
      payments.addAll(getPaymentSchedules(exp));
    }
    insert payments;
  }

  private void deletePayments(List<Id> lineItemIds) {
    delete [
      SELECT Id
      FROM Payment__c
      WHERE Expense_Line_Item__c IN :lineItemIds
    ];
  }

  private List<Expense_Line_Item__c> filterExpenses(
    List<Expense_Line_Item__c> newList
  ) {
    List<Expense_Line_Item__c> filteredList = new List<Expense_Line_Item__c>();
    for (Expense_Line_Item__c expLineItem : newList) {
      if (
        String.isNotBlank(expLineItem.Debited_By__c) &&
        expLineItem.Debited_By__c == 'Sriram' ||
        expLineItem.Debited_By__c == 'Other'
      ) {
        filteredList.add(expLineItem);
      }
    }
    return filteredList;
  }

  private String getBankName(String source) {
    String bankName = '';
    if (String.isBlank(source)) {
      return '';
    }
    if (source == 'Gpay' || source == 'Apay' || source == 'SC') {
      bankName = 'SC';
    } else if (source == 'Phone' || source == 'Axis') {
      bankName = 'Axis';
    } else if (source == 'Pluxee') {
      bankName = 'Pluxee';
    } else if (source == 'HDFC') {
      bankName = 'HDFC';
    } else if (source == 'SBI') {
      bankName = 'SBI';
    }
    return bankName;
  }
  private Map<String, Id> getTransactionByNameMap() {
    Map<String, Id> transactionIdByName = new Map<String, Id>();
    for (Transaction__c tnx : DataProvider.getAllTransaction()) {
      transactionIdByName.put(tnx.Name, tnx.Id);
    }
    return transactionIdByName;
  }

  private void createTransactions(List<Expense_Line_Item__c> newList) {
    List<Transaction_Item__c> newTnxs = new List<Transaction_Item__c>();
    Map<String, Id> transactionIdByName = getTransactionByNameMap();
    for (Expense_Line_Item__c expItem : newList) {
      Transaction_Item__c tItem = new Transaction_Item__c();
      String bankName = getBankName(expItem.Source__c);
      if (
        String.isBlank(bankName) || !transactionIdByName.containsKey(bankName)
      ) {
        continue;
      }
      tItem.transaction__c = transactionIdByName.get(bankName);
      tItem.Date__c = expItem.Date__c;
      tItem.Amount__c = expItem.Amount__c;
      tItem.Description__c = expItem.Details__c;
      tItem.Type__c = 'Debit';
      tItem.Source_Record_Id__c = expItem.Id;
      newTnxs.add(tItem);
    }
    try {
      insert newTnxs;
    } catch (Exception exp) {
      throw exp;
    }
  }

  private void updateTransactions(
    List<Expense_Line_Item__c> newList,
    Map<Id, Expense_Line_Item__c> newMap,
    Map<Id, Expense_Line_Item__c> oldMap
  ) {
    List<Id> expItemIds = new List<Id>();
    List<Expense_Line_Item__c> newTnxs = new List<Expense_Line_Item__c>();
    for (Expense_Line_Item__c expItem : newList) {
      Expense_Line_Item__c oldExpense = oldMap.get(expItem.Id);
      if (
        expItem.Source__c != oldExpense.Source__c ||
        expItem.Details__c != oldExpense.Details__c ||
        expItem.Amount__c != oldExpense.Amount__c ||
        expItem.Date__c != oldExpense.Date__c ||
        expItem.Debited_By__c != oldExpense.Debited_By__c
      ) {
        if (
          expItem.Debited_By__c != oldExpense.Debited_By__c &&
          (oldExpense.Debited_By__c != 'Sriram' ||
          oldExpense.Debited_By__c != 'Other')
        ) {
          newTnxs.add(expItem);
        } else {
          expItemIds.add(expItem.Id);
        }
      }
    }

    if (!newTnxs.isEmpty()) {
      createTransactions(newTnxs);
    }
    if (expItemIds.isEmpty()) {
      return;
    }

    List<Transaction_Item__c> transactionItems = new List<Transaction_Item__c>(
      [
        SELECT
          Id,
          Name,
          Amount__c,
          Description__c,
          Date__c,
          transaction__c,
          Source_Record_Id__c
        FROM Transaction_Item__c
        WHERE Source_Record_Id__c IN :expItemIds
      ]
    );
    List<Transaction_Item__c> tnxList = new List<Transaction_Item__c>();
    List<Transaction_Item__c> tnxTobeDeleted = new List<Transaction_Item__c>();
    for (Transaction_Item__c tItem : transactionItems) {
      Expense_Line_Item__c expLine = newMap.get(tItem.Source_Record_Id__c);
      String bankName = getBankName(expLine.Source__c);
      Map<String, Id> transactionIdByName = getTransactionByNameMap();
      if (
        string.isBlank(bankName) || !transactionIdByName.containsKey(bankName)
      ) {
        tnxTobeDeleted.add(tItem);
        continue;
      }
      tItem.Transaction__c = transactionIdByName.get(bankName);
      tItem.Description__c = expLine.Details__c;
      tItem.Amount__c = expLine.Amount__c;
      tItem.Date__c = expLine.Date__c;
      tnxList.add(tItem);
    }
    try {
      update tnxList;
      if(!tnxTobeDeleted.isEmpty()){
        delete tnxTobeDeleted;
      }
    } catch (Exception exp) {
      throw exp;
    }
  }
}
