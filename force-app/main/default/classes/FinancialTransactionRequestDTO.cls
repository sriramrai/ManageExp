public class FinancialTransactionRequestDTO {
  public String source { get; set; }
  public String provider { get; set; }
  public String paymentMethod { get; set; }

  public Date transactionDate { get; set; }
  public String merchant { get; set; }
  public Decimal amount { get; set; }

  public String debitedBy { get; set; }

  public String cardLastFour { get; set; }
  public String transactionReference { get; set; }

  public String emailMessageId { get; set; }
  public String sourceTransactionId { get; set; }
}
