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

  private static List<Date> getDateRangeFromArguments(
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
    System.debug('Calculated date range: ' + startDate + ' to ' + endDate);
    return new List<Date>{ startDate, endDate };
  }

  public static DTO_ExpenseSummary getMonthlyExpense(
    Map<String, Object> arguments
  ) {
    List<Date> dateRange = getDateRangeFromArguments(arguments);
    List<Expense__c> expenses = DataProvider.getAllExpenseByMonth(
      dateRange[0],
      dateRange[1]
    );

    if (expenses.isEmpty()) {
      return null;
    }

    Decimal totalExpense = 0;
    for (Expense__c expense : expenses) {
      totalExpense += expense.Other__c;
      totalExpense += expense.Ragini__c;
    }

    DTO_ExpenseSummary summary = new DTO_ExpenseSummary();
    //summary.expenseId = expense.Id;
    //summary.monthName = expense.Name;
    summary.startDate = dateRange[0];
    summary.endDate = dateRange[1];
    summary.totalExpense = totalExpense;

    return summary;
  }

  public static Map<String, DTO_ExpenseSummary> getExpenseByPerson(
    Map<String, Object> arguments
  ) {
    List<Date> dateRange = getDateRangeFromArguments(arguments);
    List<Expense__c> expenses = DataProvider.getAllExpenseByMonth(
      dateRange[0],
      dateRange[1]
    );

    if (expenses.isEmpty()) {
      return null;
    }

    String personNames = (String) arguments.get('person');

    Boolean raginiIncluded = false;
    Boolean sriramIncluded = false;
    if (String.isNotBlank(personNames)) {
      List<String> personNameList = personNames.split(',');
      for (String person : personNameList) {
        if (person.equalsIgnoreCase('Ragini')) {
          raginiIncluded = true;
        } else if (person.equalsIgnoreCase('Sriram')) {
          sriramIncluded = true;
        }
      }
    } else {
      // If no specific person is mentioned, include both by default
      raginiIncluded = true;
      sriramIncluded = true;
    }

    Map<String, DTO_ExpenseSummary> expenseByPersonMap = new Map<String, DTO_ExpenseSummary>();

    Map<String, List<Expense__c>> expensesByPerson = new Map<String, List<Expense__c>>();
    Decimal totalRaginiExpense = 0;
    Decimal totalOtherExpense = 0;
    for (Expense__c expense : expenses) {
      totalRaginiExpense += expense.Ragini__c;
      totalOtherExpense += expense.Other__c;
    }
    if (raginiIncluded) {
      DTO_ExpenseSummary raginiSummary = new DTO_ExpenseSummary();
      raginiSummary.totalExpense = totalRaginiExpense;
      raginiSummary.startDate = dateRange[0];
      raginiSummary.endDate = dateRange[1];
      expenseByPersonMap.put('Ragini', raginiSummary);
    }
    if (sriramIncluded) {
      DTO_ExpenseSummary sriramSummary = new DTO_ExpenseSummary();
      sriramSummary.totalExpense = totalOtherExpense;
      sriramSummary.startDate = dateRange[0];
      sriramSummary.endDate = dateRange[1];
      expenseByPersonMap.put('Sriram', sriramSummary);
    }

    return expenseByPersonMap;
  }

  public static Map<String, Map<String, DTO_ExpenseSummary>> getExpenseByCategory(
    Map<String, Object> arguments
  ) {
    List<Date> dateRange = getDateRangeFromArguments(arguments);
    System.debug('Date range for expense by category: ' + dateRange);
    List<Expense_Line_Item__c> expenses = DataProvider.getAllExpenseLineItems(
      dateRange[0],
      dateRange[1]
    );

    if (expenses.isEmpty()) {
      return null;
    }

    Map<String, Map<String, DTO_ExpenseSummary>> expenseByCategoryMap = new Map<String, Map<String, DTO_ExpenseSummary>>();

    System.debug(
      'Retrieved expenses' + expenses.size() + JSON.serializePretty(expenses)
    );
    for (Expense_Line_Item__c expense : expenses) {
      String category = expense.Category__c;
      String personName = expense.Debited_By__c == 'Sriram' ||
        expense.Debited_By__c == 'Other'
        ? 'Sriram'
        : expense.Debited_By__c;
      DTO_ExpenseSummary expSummary = new DTO_ExpenseSummary();
      expSummary.startDate = expense.Date__c;
      expSummary.endDate = expense.Date__c;
      expSummary.totalExpense = expense.Amount__c;
      expSummary.expenseId = expense.Id;

      if (!expenseByCategoryMap.containsKey(personName)) {
        Map<String, DTO_ExpenseSummary> categoryMap = new Map<String, DTO_ExpenseSummary>();
        categoryMap.put(category, expSummary);
        expenseByCategoryMap.put(personName, categoryMap);
      } else {
        Map<String, DTO_ExpenseSummary> categoryMap = expenseByCategoryMap.get(
          personName
        );
        if (!categoryMap.containsKey(category)) {
          categoryMap.put(category, expSummary);
        } else {
          DTO_ExpenseSummary existingSummary = categoryMap.get(category);
          existingSummary.totalExpense += expense.Amount__c;
        }
      }
    }
    //DTO_ExpenseSummary existingSummary = personMap.get(personName);
    //existingSummary.totalExpense += expense.Other__c + expense.Ragini__c;
    System.debug(
      'Expense by category map: ' + JSON.serializePretty(expenseByCategoryMap)
    );
    return expenseByCategoryMap;
  }

  public static DTO_ExpenseSummary createExpense(
    Map<String, Object> arguments
  ) {
    try {
      String expenseName = (String) arguments.get('expenseName');
      Date expdate = Date.valueOf((String) arguments.get('date'));
      String debitedBy = (String) arguments.get('debitedBy');
      String details = (String) arguments.get('details');
      String category = (String) arguments.get('category');
      String source = (String) arguments.get('source');
      Decimal amount = (Decimal) arguments.get('amount');

      Expense__c exp = [
        SELECT Id, Name
        FROM Expense__c
        WHERE Name = :expenseName
        LIMIT 1
      ];

      Expense_Line_Item__c newExpense = new Expense_Line_Item__c();
      newExpense.Expense__c = exp.Id;
      newExpense.Date__c = expdate;
      newExpense.Debited_By__c = debitedBy;
      newExpense.Details__c = details;
      newExpense.Category__c = category;
      newExpense.Source__c = source;
      newExpense.Amount__c = amount;
      insert newExpense;

      DTO_ExpenseSummary summary = new DTO_ExpenseSummary();
      summary.expenseId = newExpense.Id;
      summary.monthName = newExpense.Name;

      return summary;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Error creating expense: ' + e.getMessage()
      );
    }
  }
}
