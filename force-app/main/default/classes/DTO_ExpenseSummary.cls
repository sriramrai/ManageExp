public class DTO_ExpenseSummary {
  @AuraEnabled
  public Id expenseId;

  @AuraEnabled
  public String monthName;

  @AuraEnabled
  public Date startDate;

  @AuraEnabled
  public Date endDate;

  @AuraEnabled
  public Decimal totalExpense;
}
