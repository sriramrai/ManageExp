public with sharing class GeminiService {
  public static String test() {
    HttpRequest req = new HttpRequest();

    req.setEndpoint(
      'callout:Gemini/v1beta/models/gemini-3.1-flash-lite:generateContent?key=YOUR_API_KEY'
    );

    req.setMethod('POST');

    req.setHeader('Content-Type', 'application/json');

    req.setBody('{"contents":[{"parts":[{"text":"Say Hello"}]}]}');

    Http http = new Http();

    HttpResponse res = http.send(req);

    return res.getBody();
  }
  public static ToolDecision decideTool(ChatRequest request) {
    System.debug(
      'GeminiService.decideTool called with request: ' +
      JSON.serializePretty(request)
    );
    String prompt = Util_Prompt.buildToolSelectionPrompt(request);
    System.debug('Gemini Prompt:**** ' + prompt);
    String geminiResponse = callGemini(prompt);
    System.debug('Gemini Response:**** ' + geminiResponse);

    return parseToolDecision(geminiResponse);
  }

  public static ToolDecision parseToolDecision(String response) {
    try {
      Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(
        response
      );
      ToolDecision decision = new ToolDecision();
      decision.tool = (String) data.get('tool');
      decision.action = (String) data.get('action');
      decision.arguments = (Map<String, Object>) data.get('arguments');
      return decision;
    } catch (Exception ex) {
      throw new AuraHandledException(
        'Unable to understand Gemini response: ' + response
      );
    }
  }

  public static String generateFinalResponse(
    String userQuestion,
    Object toolResult
  ) {
    String prompt = Util_Prompt.buildResponsePrompt(userQuestion, toolResult);

    String geminiResponse = callGemini(prompt);

    return geminiResponse;
  }

  private static String callGemini(String prompt) {
    Http http = new Http();

    HttpRequest req = new HttpRequest();

    req.setEndpoint(
      'callout:Gemini/v1beta/models/gemini-3.1-flash-lite:generateContent?key=AQ.Ab8RN6KkGP5IlfwOv05UD4Y1j07ysnnDOW3GU7KyVpDcNkBWJQ'
    );

    req.setMethod('POST');

    req.setHeader('Content-Type', 'application/json');

    Map<String, Object> body = new Map<String, Object>();

    body.put(
      'contents',
      new List<Object>{
        new Map<String, Object>{
          'parts' => new List<Object>{
            new Map<String, Object>{ 'text' => prompt }
          }
        }
      }
    );

    req.setBody(JSON.serialize(body));

    HttpResponse res = http.send(req);
    System.debug('Status Code: ' + res.getStatusCode());
    System.debug('Response Body: ' + res.getBody());

    if (res.getStatusCode() != 200) {
      throw new AuraHandledException('Gemini Error: ' + res.getBody());
    }
    return extractText(res.getBody());
  }

  private static String extractText(String responseBody) {
    System.debug('Gemini Raw Response: ' + responseBody);
    Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(
      responseBody
    );

    List<Object> candidates = (List<Object>) response.get('candidates');

    Map<String, Object> candidate = (Map<String, Object>) candidates[0];

    Map<String, Object> content = (Map<String, Object>) candidate.get(
      'content'
    );

    List<Object> parts = (List<Object>) content.get('parts');

    Map<String, Object> part = (Map<String, Object>) parts[0];

    return (String) part.get('text');
  }
}
