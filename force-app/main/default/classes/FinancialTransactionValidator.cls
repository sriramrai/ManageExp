public class FinancialTransactionValidator {
  public static String validate(FinancialTransactionRequestDTO request) {
    if (request == null) {
      return 'Request body is required.';
    }

    if (String.isBlank(request.source)) {
      return 'Source is required.';
    }

    if (String.isBlank(request.provider)) {
      return 'Provider is required.';
    }

    /* if (
      request.provider.trim().toUpperCase() != 'ICICI' &&
      request.provider.trim().toUpperCase() != 'AXIS'
    ) {
      return 'Unsupported provider. Supported providers: ICICI, Axis.';
    } */

    if (request.transactionDate == null) {
      return 'Transaction date is required.';
    }

    if (String.isBlank(request.merchant)) {
      return 'Merchant is required.';
    }

    if (request.amount == null || request.amount <= 0) {
      return 'Amount must be greater than zero.';
    }

    if (
      request.source.trim().equalsIgnoreCase('GMAIL') &&
      String.isBlank(request.emailMessageId)
    ) {
      return 'Email message ID is required for Gmail transactions.';
    }

    return null;
  }
}
