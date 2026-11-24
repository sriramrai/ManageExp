public class FinancialTransactionService {
  public static FinancialTransactionResponseDTO process(
    FinancialTransactionRequestDTO request
  ) {
    String validationError = FinancialTransactionValidator.validate(request);

    if (validationError != null) {
      return buildResponse(
        false,
        'VALIDATION_ERROR',
        validationError,
        null,
        null,
        'INVALID_REQUEST'
      );
    }

    // 1. Duplicate check
    if (!String.isBlank(request.emailMessageId)) {
      List<Expense_Line_Item__c> existingRecords = FinancialTransactionSelector.selectByEmailMessageId(
        request.emailMessageId.trim()
      );

      if (!existingRecords.isEmpty()) {
        return buildResponse(
          true,
          'DUPLICATE',
          'This transaction has already been processed.',
          existingRecords[0].Id,
          null,
          null
        );
      }
    }

    // 2. Find monthly Expense parent
    List<Expense__c> expenses = FinancialTransactionSelector.selectExpenseByTransactionDate(
      request.transactionDate
    );

    if (expenses.isEmpty()) {
      return buildResponse(
        false,
        'PARENT_NOT_FOUND',
        'No monthly Expense record found for transaction date: ' +
        String.valueOf(request.transactionDate),
        null,
        null,
        'PARENT_NOT_FOUND'
      );
    }

    if (expenses.size() > 1) {
      return buildResponse(
        false,
        'ERROR',
        'Multiple monthly Expense records found for the transaction date.',
        null,
        null,
        'MULTIPLE_PARENTS_FOUND'
      );
    }

    // 3. Create expense line item
    Expense_Line_Item__c lineItem = new Expense_Line_Item__c();

    lineItem.Date__c = request.transactionDate;
    lineItem.Amount__c = request.amount;
    lineItem.Debited_By__c = 'Other';
    lineItem.Source__c = normalizeProvider(request.provider);
    lineItem.Details__c = request.merchant.trim();
    lineItem.Expense__c = expenses[0].Id;

    if (!String.isBlank(request.emailMessageId)) {
      lineItem.Email_Message_Id__c = request.emailMessageId.trim();
    }

    try {
      insert lineItem;

      return buildResponse(
        true,
        'CREATED',
        'Expense line item created successfully.',
        lineItem.Id,
        expenses[0].Id,
        null
      );
    } catch (DmlException ex) {
      // A unique field constraint can protect against
      // simultaneous duplicate requests.
      if (
        !String.isBlank(request.emailMessageId) &&
        ex.getMessage().contains('DUPLICATE_VALUE')
      ) {
        List<Expense_Line_Item__c> duplicateRecords = FinancialTransactionSelector.selectByEmailMessageId(
          request.emailMessageId.trim()
        );

        if (!duplicateRecords.isEmpty()) {
          return buildResponse(
            true,
            'DUPLICATE',
            'This transaction has already been processed.',
            duplicateRecords[0].Id,
            expenses[0].Id,
            null
          );
        }
      }

      // Log unexpected DML exception.
      ErrorLogger.log(
        ex,
        'FinancialTransactionService',
        'process',
        'Failed while creating expense line item. Email Message ID: ' +
        request.emailMessageId
      );
      ErrorLogger.saveLog();

      return buildResponse(
        false,
        'ERROR',
        'Unable to create expense line item: ' + ex.getMessage(),
        null,
        null,
        'DML_ERROR'
      );
    }
  }

  private static String normalizeProvider(String provider) {
    if (provider.trim().equalsIgnoreCase('ICICI')) {
      return 'ICICI CC';
    }

    if (provider.trim().equalsIgnoreCase('AXIS')) {
      return 'Axis CC';
    }

    return provider.trim();
  }

  private static FinancialTransactionResponseDTO buildResponse(
    Boolean success,
    String status,
    String message,
    Id lineItemId,
    Id expenseId,
    String errorCode
  ) {
    FinancialTransactionResponseDTO response = new FinancialTransactionResponseDTO();

    response.success = success;
    response.status = status;
    response.message = message;
    response.expenseLineItemId = lineItemId;
    response.expenseId = expenseId;
    response.errorCode = errorCode;

    return response;
  }
}
