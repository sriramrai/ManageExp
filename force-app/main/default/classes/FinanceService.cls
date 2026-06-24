public with sharing class FinanceService {
  /**
   * Evaluate a free-text question and route to the appropriate helper.
   * The FinanceCopilotController already exposes controller methods to LWC,
   * so this service focuses on domain logic.
   *
   * @param q user question
   * @return human-readable answer
   */
  public static String answer(String q) {
    if (String.isBlank(q)) {
      return 'Sorry, I do not know';
    }
    try {
      String lower = q.toLowerCase();
      if (lower.contains('net worth')) {
        return getNetWorth();
      }
      if (lower.contains('salary')) {
        return getSalary();
      }
      if (
        lower.contains('fd') ||
        lower.contains('fixed deposit') ||
        lower.contains('fixed')
      ) {
        return getFD();
      }
      return 'Sorry, I do not know';
    } catch (Exception e) {
      // Return a safe message; controllers should wrap as AuraHandledException where needed
      return 'An error occurred while evaluating the question.';
    }
  }

  /**
   * Compute net worth as sum of current value for stock-type investments and total amount for other investments (e.g., FD).
   * Uses Investment__c where:
   *  - Current_Value__c holds current market value for stocks
   *  - Amount__c holds the invested amount (for FD or other types)
   *
   * @return formatted string with net worth and breakdown
   */
  private static String getNetWorth() {
    Decimal stockTotal = 0;
    Decimal fdTotal = 0;
    Decimal otherTotal = 0;

    // Detect stock recordType id (RecordType 'Stock') as used elsewhere in the project
    Id stockRT;
    try {
      stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName()
        .get('Stock')
        .getRecordTypeId();
    } catch (Exception e) {
      stockRT = null;
    }

    // Query investments; use fields that exist in this project (Amount__c, Current_Price__c, Available_Quantity__c, Maturity_Date__c, Bank__c)
    for (Investment__c inv : [
      SELECT
        Id,
        RecordTypeId,
        Amount__c,
        Current_Price__c,
        Available_Quantity__c,
        Maturity_Amount__c,
        Maturity_Date__c,
        Bank__c
      FROM Investment__c
      WHERE Amount__c != NULL OR Current_Price__c != NULL
    ]) {
      // Stocks: identified via RecordType = Stock
      if (stockRT != null && inv.RecordTypeId == stockRT) {
        Decimal price = (inv.Current_Price__c == null
          ? 0
          : inv.Current_Price__c);
        Decimal qty = (inv.Available_Quantity__c == null
          ? 0
          : inv.Available_Quantity__c);
        stockTotal += (price * qty);
        continue;
      }

      // FD: infer by presence of Maturity_Date__c or Bank__c common FD names
      if (
        inv.Maturity_Date__c != null ||
        (inv.Bank__c != null && inv.Bank__c.toLowerCase().contains('fd'))
      ) {
        fdTotal += (inv.Maturity_Amount__c == null
          ? (inv.Amount__c == null ? 0 : inv.Amount__c)
          : inv.Maturity_Amount__c);
        continue;
      }

      // Fallback: treat as other investment using Amount__c
      otherTotal += (inv.Amount__c == null ? 0 : inv.Amount__c);
    }

    Decimal net = stockTotal + fdTotal + otherTotal;
    return 'Net worth : ₹' +
      formatDecimal(net) +
      ' (Stocks: ₹' +
      formatDecimal(stockTotal) +
      ', FDs: ₹' +
      formatDecimal(fdTotal) +
      ', Others: ₹' +
      formatDecimal(otherTotal) +
      ')';
  }

  /**
   * Sum salary amounts from Income__c records where Type__c indicates salary.
   *
   * @return formatted salary string
   */
  private static String getSalary() {
    Decimal salaryTotal = 0;
    for (Income__c inc : [
      SELECT Salary__c
      FROM Income__c
      WHERE Salary__c != NULL
    ]) {
      salaryTotal += (inc.Salary__c == null ? 0 : inc.Salary__c);
    }
    return 'Salary total: ₹' + formatDecimal(salaryTotal);
  }

  /**
   * Sum FD investments from Investment__c where Type__c indicates FD.
   *
   * @return formatted FD total string
   */
  private static String getFD() {
    Decimal fdTotal = 0;
    for (Investment__c inv : [
      SELECT Amount__c, Maturity_Amount__c, Maturity_Date__c, Bank__c
      FROM Investment__c
      WHERE Amount__c != NULL OR Maturity_Amount__c != NULL
    ]) {
      // infer FD by maturity date or bank naming
      if (
        inv.Maturity_Date__c != null ||
        (inv.Bank__c != null && inv.Bank__c.toLowerCase().contains('fd'))
      ) {
        fdTotal += (inv.Maturity_Amount__c == null
          ? (inv.Amount__c == null ? 0 : inv.Amount__c)
          : inv.Maturity_Amount__c);
      }
    }
    return 'Total FDs: ₹' + formatDecimal(fdTotal);
  }

  /**
   * Helper to format Decimal values to 2 decimal places without scientific notation.
   */
  private static String formatDecimal(Decimal d) {
    if (d == null)
      return '0.00';
    // Use Decimal.format to respect locale; fallback to string formatting
    try {
      return d.setScale(2, RoundingMode.HALF_UP).format();
    } catch (Exception e) {
      return String.valueOf(d.setScale(2, RoundingMode.HALF_UP));
    }
  }
}
