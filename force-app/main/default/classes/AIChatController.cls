public with sharing class AIChatController {
  @AuraEnabled
  public static ChatResponse chat(ChatRequest request) {
    System.debug(
      'AIChatController.chat called with request: ' +
      JSON.serializePretty(request)
    );
    return FinanceAgent.process(request);
  }
}
