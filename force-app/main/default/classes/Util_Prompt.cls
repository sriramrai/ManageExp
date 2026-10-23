public with sharing class Util_Prompt {
  /**
   * Builds the prompt used to decide which tool to execute.
   */
  public static String buildToolSelectionPrompt(ChatRequest request) {
    List<AI_Prompts__mdt> prompts = [
      SELECT Prompt__c
      FROM AI_Prompts__mdt
      WHERE Active__c = TRUE AND DeveloperName = 'request_prompt'
      LIMIT 1
    ];
    if (prompts.isEmpty()) {
      throw new AuraException('No active AI prompt found.');
    }
    System.debug('inside building prompt ' + JSON.serializePretty(request));
    String prompt = prompts[0].Prompt__c;
    System.debug('inside building prompt ' + prompt);
    String toolText = buildTools();
    String historyText = buildHistory(request.history);
    String userQuestionText = request.message;
    prompt = prompt.replace('{{TOOLS}}', toolText);
    prompt = prompt.replace('{{HISTORY}}', historyText);
    prompt = prompt.replace('{{QUESTION}}', userQuestionText);

    return prompt;
  }

  /**
   * Builds the prompt to generate the final response
   * after Salesforce returns data.
   */
  public static String buildResponsePrompt(
    String userQuestion,
    Object toolResult
  ) {
    List<AI_Prompts__mdt> prompts = [
      SELECT Prompt__c
      FROM AI_Prompts__mdt
      WHERE Active__c = TRUE AND DeveloperName = 'response_prompt'
      LIMIT 1
    ];

    if (prompts.isEmpty()) {
      throw new AuraException('No active AI prompt found.');
    }

    String prompt = prompts[0].Prompt__c;
    prompt = prompt.replace('{{QUESTION}}', userQuestion);
    prompt = prompt.replace('{{DATA}}', JSON.serializePretty(toolResult));
    return prompt;
  }

  private static string buildTools() {
    List<String> lines = new List<String>();

    lines.add('');
    lines.add('Available Tools');
    lines.add('================');

    for (IAgentTool tool : Agent_ToolRegistry.getTools()) {
      lines.add('');
      lines.add('Tool: ' + tool.getName());
      lines.add('Description: ' + tool.getDescription());

      lines.add('Supported Actions:');

      for (String action : tool.getSupportedActions()) {
        lines.add('- ' + action);
      }
    }

    return String.join(lines, '\n');
  }

  private static String buildHistory(List<ChatRequest.ChatMessage> history) {
    if (history == null || history.isEmpty()) {
      return '';
    }

    List<String> lines = new List<String>();

    for (ChatRequest.ChatMessage msg : history) {
      lines.add(msg.role + ': ' + msg.content);
    }

    return String.join(lines, '\n');
  }
}
