public with sharing class Util_Prompt {
  /**
   * Builds the prompt used to decide which tool to execute.
   */
  public static String buildToolSelectionPrompt(ChatRequest request) {
    System.debug('inside building prompt ' + JSON.serializePretty(request));
    List<String> lines = new List<String>();

    lines.add('You are a Salesforce Finance AI Assistant.');
    lines.add('');
    lines.add(
      'Your ONLY responsibility is to determine which Salesforce tool should be executed.'
    );
    lines.add('');
    lines.add('Rules:');
    lines.add('1. Do NOT answer the users question.');
    lines.add('2. Return ONLY valid JSON.');
    lines.add('3. Do NOT wrap JSON inside markdown.');
    lines.add('4. Always return tool, action and arguments.');
    lines.add('5. If no arguments are required, return an empty JSON object.');
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

    lines.add('');
    lines.add('Examples');
    lines.add('========');

    lines.add('');
    lines.add('User: What is my expense this month?');
    lines.add('Response:');
    lines.add(
      '{"tool":"expense","action":"monthlyExpense","arguments":{"month":"current", "year":"current"}}'
    );

    lines.add('');
    lines.add('User: What is my expense last month?');
    lines.add('Response:');
    lines.add(
      '{"tool":"expense","action":"monthlyExpense","arguments":{"month":"last", "year":"current"}}'
    );

    lines.add('');
    lines.add('User: Compare my last 3 months expenses.');
    lines.add('Response:');
    lines.add(
      '{"tool":"expense","action":"expenseTrend","arguments":{"months":3}}'
    );

    lines.add('');
    lines.add(
      'When the user mentions a month or year, extract them into the arguments object.'
    );
    lines.add('Examples');
    lines.add('========');

    lines.add('');
    lines.add('User: What was my expense in January 2024?');
    lines.add('Response:');
    lines.add(
      '{"tool":"expense","action":"monthlyExpense","arguments":{"month":7,"year":2026}}'
    );

    if (request.history != null && !request.history.isEmpty()) {
      lines.add('');
      lines.add('Conversation History');
      lines.add('====================');

      for (ChatRequest.ChatMessage msg : request.history) {
        lines.add(msg.role + ': ' + msg.content);
      }
    }

    lines.add('');
    lines.add('Current User Question');
    lines.add('=====================');
    lines.add(request.message);

    lines.add('');
    lines.add('Return ONLY the JSON object.');
    lines.add('Do not explain.');
    lines.add('Do not use markdown.');

    return String.join(lines, '\n');
  }

  /**
   * Builds the prompt to generate the final response
   * after Salesforce returns data.
   */
  public static String buildResponsePrompt(
    String userQuestion,
    Object toolResult
  ) {
    List<String> lines = new List<String>();

    lines.add('You are a helpful Finance AI Assistant.');
    lines.add('');
    lines.add('Answer ONLY using the Salesforce data provided.');
    lines.add('Never invent numbers.');
    lines.add('Never make assumptions.');
    lines.add('If no data exists, clearly say so.');
    lines.add('Keep the answer concise.');
    lines.add('');

    lines.add('User Question');
    lines.add('=============');
    lines.add(userQuestion);

    lines.add('');
    lines.add('Salesforce Data');
    lines.add('===============');
    lines.add(JSON.serializePretty(toolResult));

    lines.add('');
    lines.add('Generate a friendly response.');

    return String.join(lines, '\n');
  }
}
