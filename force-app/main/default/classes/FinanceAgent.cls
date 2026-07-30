public with sharing class FinanceAgent {
  public static ChatResponse process(ChatRequest request) {
    ChatResponse response = new ChatResponse();

    try {
      System.debug(
        'inside FinanceAgent.process with request: ' +
        JSON.serializePretty(request)
      );
      // Step 1: Ask Gemini which tool to execute
      ToolDecision decision = GeminiService.decideTool(request);
      // Step 2: Find the tool dynamically
      IAgentTool tool = Agent_ToolRegistry.getTool(decision.tool);
      if (tool == null) {
        response.success = false;
        response.errorMessage = 'Tool not found: ' + decision.tool;

        return response;
      }
      // Step 3: Add action into arguments
      if (decision.arguments == null) {
        decision.arguments = new Map<String, Object>();
      }
      decision.arguments.put('action', decision.action);
      // Step 4: Execute Salesforce logic
      ToolResult result = tool.execute(decision.arguments);

      if (!result.success) {
        response.success = false;
        response.errorMessage = result.errorMessage;

        return response;
      }
      // Step 5: Generate final response
      String finalAnswer = GeminiService.generateFinalResponse(
        request.message,
        result.data
      );

      response.success = true;
      response.message = finalAnswer;
      return response;
    } catch (Exception ex) {
      response.success = false;
      response.errorMessage = ex.getMessage();
      return response;
    }
  }
}
