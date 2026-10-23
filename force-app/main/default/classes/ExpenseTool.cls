public with sharing class ExpenseTool implements IAgentTool {
  public String getName() {
    return 'expense';
  }

  public String getDescription() {
    return 'Provides expense related information.';
  }

  public ToolResult execute(Map<String, Object> arguments) {
    ToolResult result = new ToolResult();
    try {
      String action = (String) arguments.get('action');
      System.debug(
        'Executing action: ' + action + ' with arguments: ' + arguments
      );
      switch on action {
        when 'monthlyExpense' {
          result.success = true;
          result.data = Repository_Expense.getMonthlyExpense(arguments);
        }
        when 'expenseByPerson' {
          result.success = true;
          result.data = Repository_Expense.getExpenseByPerson(arguments);
        }
        when 'expenseByCategory' {
          result.success = true;
          result.data = Repository_Expense.getExpenseByCategory(arguments);
        }
        when 'expenseTrend' {
          result.success = true;
          //result.data = Repository_Expense.getExpenseTrend(arguments);
        }
        when 'createExpense' {
          result.success = true;
          result.data = Repository_Expense.createExpense(arguments);
        }
        when else {
          result.success = false;
          result.errorMessage = 'Unsupported action: ' + action;
        }
      }
      return result;
    } catch (Exception e) {
      result.success = false;
      result.errorMessage = 'Error executing expense tool: ' + e.getMessage();
    }
    return result;
  }
  public List<String> getSupportedActions() {
    return new List<String>{
      'currentMonthExpense',
      'lastMonthExpense',
      'expenseTrend',
      'expenseByCategory',
      'expenseByPerson',
      'monthlyExpense',
      'createExpense'
    };
  }
}
