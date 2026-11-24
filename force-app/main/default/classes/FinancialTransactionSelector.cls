public with sharing class FinancialTransactionSelector {
  public static List<Expense__c> selectExpenseByTransactionDate(
    Date transactionDate
  ) {
    return [
      SELECT Id, Name, Start_Date__c, End_Date__c
      FROM Expense__c
      WHERE
        Start_Date__c <= :transactionDate
        AND End_Date__c >= :transactionDate
      ORDER BY Start_Date__c DESC
      LIMIT 2
    ];
  }

  public static List<Expense_Line_Item__c> selectByEmailMessageId(
    String emailMessageId
  ) {
    return [
      SELECT Id, Name, Email_Message_Id__c
      FROM Expense_Line_Item__c
      WHERE Email_Message_Id__c = :emailMessageId
      LIMIT 1
    ];
  }
}
