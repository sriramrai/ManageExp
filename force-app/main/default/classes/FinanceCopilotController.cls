public with sharing class FinanceCopilotController {
  @AuraEnabled
  public static String askQuestion(String question) {
    return FinanceService.answer(question);
  }
}
