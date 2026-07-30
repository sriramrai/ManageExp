public with sharing class Repository_Expense {
  public static DTO_ExpenseSummary getCurrentMonthExpense() {
    List<Expense__c> expenses = [
      SELECT Id, Name, Start_Date__c, End_Date__c, Other__c
      FROM Expense__c
      WHERE Start_Date__c <= :Date.today() AND End_Date__c >= :Date.today()
      LIMIT 1
    ];

    if (expenses.isEmpty()) {
      return null;
    }

    Expense__c expense = expenses[0];

    DTO_ExpenseSummary summary = new DTO_ExpenseSummary();
    summary.expenseId = expense.Id;
    summary.monthName = expense.Name;
    summary.startDate = expense.Start_Date__c;
    summary.endDate = expense.End_Date__c;
    summary.totalExpense = expense.Other__c;

    return summary;
  }
  public static DTO_ExpenseSummary getMonthlyExpense(
    Map<String, Object> arguments
  ) {
    Integer month;
    Integer year;
    if (arguments.get('month') == 'current') {
      month = Date.today().month();
      year = Date.today().year();
    } else if (arguments.get('month') == 'last') {
      Date lastMonthDate = Date.today().addMonths(-1);
      month = lastMonthDate.month();
      year = lastMonthDate.year();
    } else {
      month = (Integer) arguments.get('month');
      year = (Integer) arguments.get('year');
    }
    Date startDate = Date.newInstance(year, month, 1);
    Date endDate = startDate.toStartOfMonth().addMonths(1).addDays(-1);

    List<Expense__c> expenses = [
      SELECT Id, Name, Start_Date__c, End_Date__c, Other__c
      FROM Expense__c
      WHERE Start_Date__c <= :endDate AND End_Date__c >= :startDate
      LIMIT 1
    ];

    if (expenses.isEmpty()) {
      return null;
    }

    Expense__c expense = expenses[0];

    DTO_ExpenseSummary summary = new DTO_ExpenseSummary();
    summary.expenseId = expense.Id;
    summary.monthName = expense.Name;
    summary.startDate = expense.Start_Date__c;
    summary.endDate = expense.End_Date__c;
    summary.totalExpense = expense.Other__c;

    return summary;
  }
}
