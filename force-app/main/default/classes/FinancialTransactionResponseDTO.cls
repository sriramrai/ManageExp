public class FinancialTransactionResponseDTO {
  public Boolean success { get; set; }
  public String status { get; set; }
  public String message { get; set; }

  public Id expenseLineItemId { get; set; }
  public Id expenseId { get; set; }

  public String errorCode { get; set; }
}
