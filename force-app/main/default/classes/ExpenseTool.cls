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
      switch on action {
        when 'monthlyExpense' {
          result.success = true;
          result.data = Repository_Expense.getMonthlyExpense(arguments);
        }
        when else {
          result.success = false;
          result.errorMessage = 'Unsupported action: ' + action;
        }
      }
      /* if (action == 'currentMonthExpense') {
        result.success = true;
        result.data = Repository_Expense.getCurrentMonthExpense();
        return result;
      } else if (action == 'monthlyExpense') {
        result.success = true;
        result.data = Repository_Expense.getMonthlyExpense(arguments);
        return result;
      } */
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
      'monthlyExpense'
    };
  }
}
