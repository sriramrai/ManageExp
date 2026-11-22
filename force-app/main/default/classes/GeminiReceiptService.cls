public with sharing class GeminiReceiptService {
  private static final String MODEL = 'gemini-3.1-flash-lite';
  private static final String ENDPOINT = 'callout:Gemini_API/v1beta';

  @AuraEnabled
  public static Map<String, Object> extractReceipt(
    String fileBase64,
    String mimeType
  ) {
    // Validate input
    if (String.isBlank(fileBase64)) {
      throw new AuraHandledException('Please select a receipt.');
    }

    Set<String> allowedTypes = new Set<String>{
      'image/jpeg',
      'image/png',
      'application/pdf'
    };

    if (!allowedTypes.contains(mimeType)) {
      throw new AuraHandledException(
        'Only JPG, PNG and PDF files are supported.'
      );
    }

    // Keep the direct browser-to-Apex request small.
    if (fileBase64.length() > 2200000) {
      throw new AuraHandledException(
        'File is too large. Please use a file smaller than 1.5 MB.'
      );
    }

    // Instructions for Gemini
    String prompt =
      'You are an expense receipt extraction assistant. ' +
      'Extract the following information from the supplied receipt: ' +
      '1. Expense date. ' +
      '2. A short description of the purchased goods or services. ' +
      '3. Final amount paid. ' +
      'Return the date in YYYY-MM-DD format. ' +
      'Return amount as a number only, without currency symbols. ' +
      'Do not guess or invent missing values. ' +
      'If the date or description cannot be identified, return an empty string. ' +
      'If the amount cannot be identified, return 0. ' +
      'Use the final payable amount, not subtotal or tax, when available.';

    // Gemini JSON response schema
    Map<String, Object> schema = new Map<String, Object>{
      'type' => 'object',
      'properties' => new Map<String, Object>{
        'expense_date' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'Expense date in YYYY-MM-DD format'
        },
        'description' => new Map<String, Object>{
          'type' => 'string',
          'description' => 'Short description of purchased goods or services'
        },
        'amount' => new Map<String, Object>{
          'type' => 'number',
          'description' => 'Final amount paid, or 0 if unavailable'
        }
      },
      'required' => new List<String>{ 'expense_date', 'description', 'amount' }
    };

    // Correct Gemini GenerateContent parts structure
    List<Object> inputContent = new List<Object>{
      new Map<String, Object>{ 'text' => prompt },
      new Map<String, Object>{
        'inlineData' => new Map<String, Object>{
          'mimeType' => mimeType,
          'data' => fileBase64
        }
      }
    };

    // Correct GenerateContent request body
    Map<String, Object> requestBody = new Map<String, Object>{
      'contents' => new List<Object>{
        new Map<String, Object>{ 'role' => 'user', 'parts' => inputContent }
      },
      'generationConfig' => new Map<String, Object>{
        'responseMimeType' => 'application/json',
        'responseJsonSchema' => schema,
        'temperature' => 0
      }
    };

    HttpRequest request = new HttpRequest();

    request.setEndpoint(ENDPOINT + '/models/' + MODEL + ':generateContent');

    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(120000);
    request.setBody(JSON.serialize(requestBody));

    HttpResponse response = new HttpResponse();

    // Send the request exactly once
    try {
      response = new Http().send(request);
      //String responseBody = '{\n  \"candidates\": [\n    {\n      \"content\": {\n        \"parts\": [\n          {\n            \"text\": \"{\\n  \\\"amount\\\": 4451.0,\\n  \\\"description\\\": \\\"Crompton ASWH-3015 ARNO NEO 5S 15 L Storage Water Geyser\\\",\\n  \\\"expense_date\\\": \\\"2026-10-10\\\"\\n}\",\n            \"thoughtSignature\": \"EqEBCp4BAWkUfRM4XfDAr0+trEF/WsxWfvVa/qKLGQ288sjVFPaqCbBZBgJR0XSQ6+xpWldMq0x/tQUVmQJiCGPKFqFzQ2JV9/sqPNY0ieL7NlofMfSVjViRxjJhc92bIgyd5xU9SV8tbXKe05dEGetgfyiwDd/nXZ25gebE5ea2shzDqtEXgSMvWzqiZwmfH8bXVGW9Hxt5wN2YHQ0h9GxBK68=\"\n          }\n        ],\n        \"role\": \"model\"\n      },\n      \"finishReason\": \"STOP\",\n      \"index\": 0\n    }\n  ],\n  \"usageMetadata\": {\n    \"promptTokenCount\": 2776,\n    \"candidatesTokenCount\": 66,\n    \"totalTokenCount\": 2842,\n    \"promptTokensDetails\": [\n      {\n        \"modality\": \"IMAGE\",\n        \"tokenCount\": 2660\n      },\n      {\n        \"modality\": \"TEXT\",\n        \"tokenCount\": 116\n      }\n    ],\n    \"serviceTier\": \"standard\"\n  },\n  \"modelVersion\": \"gemini-3.1-flash-lite\",\n  \"responseId\": \"ZrABa6aVC-Kw694Pt_yCsQw\"\n}\n';
      //response.setStatusCode(205);
      //response.setBody(responseBody);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Gemini callout exception: ' + ex.getMessage()
      );

      throw new AuraHandledException(
        'Unable to connect to Gemini. Please try again.'
      );
    }

    // Validate HTTP response
    if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
      System.debug(
        LoggingLevel.ERROR,
        'Gemini API error: ' + response.getBody()
      );

      throw new AuraHandledException(
        'Gemini could not scan the receipt. Please try again.'
      );
    }
    System.debug(
      'Gemini response******: ' + JSON.serialize(response.getBody())
    );
    return parseGeminiResponse(response.getBody());
  }

  // Parse standard Gemini GenerateContent response
  private static Map<String, Object> parseGeminiResponse(String responseBody) {
    Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
      responseBody
    );

    List<Object> candidates = (List<Object>) result.get('candidates');

    if (candidates == null || candidates.isEmpty()) {
      throw new AuraHandledException(
        'Gemini did not return any extraction results.'
      );
    }

    Map<String, Object> candidate = (Map<String, Object>) candidates[0];

    Map<String, Object> content = (Map<String, Object>) candidate.get(
      'content'
    );

    if (content == null) {
      throw new AuraHandledException('Gemini returned an invalid response.');
    }

    List<Object> parts = (List<Object>) content.get('parts');

    if (parts == null || parts.isEmpty()) {
      throw new AuraHandledException('Gemini returned an empty response.');
    }

    String extractedJson;

    for (Object partObject : parts) {
      Map<String, Object> part = (Map<String, Object>) partObject;

      if (part.containsKey('text')) {
        extractedJson = (String) part.get('text');
        break;
      }
    }

    if (String.isBlank(extractedJson)) {
      throw new AuraHandledException(
        'Gemini did not return the extracted receipt details.'
      );
    }

    try {
      return (Map<String, Object>) JSON.deserializeUntyped(extractedJson);
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Gemini JSON parsing error: ' + ex.getMessage()
      );

      throw new AuraHandledException(
        'Unable to read the extracted receipt details.'
      );
    }
  }
}
