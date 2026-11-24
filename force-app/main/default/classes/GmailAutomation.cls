@RestResource(urlMapping='/gmail/expenses/*')
global with sharing class GmailAutomation {
  @HttpPost
  global static void createExpense() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;
    res.addHeader('Content-Type', 'application/json');
    try {
      FinancialTransactionRequestDTO request = (FinancialTransactionRequestDTO) JSON.deserialize(
        req.requestBody.toString(),
        FinancialTransactionRequestDTO.class
      );
      FinancialTransactionResponseDTO response = FinancialTransactionService.process(
        request
      );

      Integer statusCode = 200;

      if (response.status == 'CREATED') {
        statusCode = 201;
      } else if (
        response.status == 'VALIDATION_ERROR' ||
        response.status == 'PARENT_NOT_FOUND'
      ) {
        statusCode = 400;
      } else if (response.status == 'ERROR') {
        statusCode = 500;
      }

      res.statusCode = statusCode;
      res.responseBody = Blob.valueOf(JSON.serialize(response));
    } catch (Exception ex) {
      ErrorLogger.log(
        ex,
        'GmailAutomation',
        'doPost',
        'Failed while processing REST request'
      );

      ErrorLogger.saveLog();

      FinancialTransactionResponseDTO response = new FinancialTransactionResponseDTO();

      response.success = false;
      response.status = 'ERROR';
      response.errorCode = 'UNEXPECTED_ERROR';
      response.message = 'Unable to process transaction request.';

      res.statusCode = 500;
      res.responseBody = Blob.valueOf(JSON.serialize(response));
    }
  }
}
