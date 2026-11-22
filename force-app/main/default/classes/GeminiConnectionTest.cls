public with sharing class GeminiConnectionTest {
  public static String testConnection() {
    HttpRequest request = new HttpRequest();

    request.setEndpoint(
      'callout:Gemini_API/v1beta/models/gemini-2.5-flash:generateContent'
    );

    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setTimeout(120000);

    Map<String, Object> requestBody = new Map<String, Object>{
      'contents' => new List<Object>{
        new Map<String, Object>{
          'parts' => new List<Object>{
            new Map<String, Object>{
              'text' => 'Reply with exactly: Gemini connection successful'
            }
          }
        }
      }
    };

    request.setBody(JSON.serialize(requestBody));

    Http http = new Http();

    try {
      HttpResponse response = http.send(request);

      System.debug('HTTP STATUS: ' + response.getStatusCode());
      System.debug('RESPONSE: ' + response.getBody());

      if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(
          response.getBody()
        );

        List<Object> candidates = (List<Object>) result.get('candidates');

        if (candidates != null && !candidates.isEmpty()) {
          Map<String, Object> candidate = (Map<String, Object>) candidates[0];

          Map<String, Object> content = (Map<String, Object>) candidate.get(
            'content'
          );

          List<Object> parts = (List<Object>) content.get('parts');

          Map<String, Object> firstPart = (Map<String, Object>) parts[0];

          return 'SUCCESS: ' + firstPart.get('text');
        }

        return 'Connected, but Gemini returned no candidates.';
      }

      return 'FAILED: HTTP ' +
        response.getStatusCode() +
        ' - ' +
        response.getBody();
    } catch (Exception ex) {
      System.debug(
        LoggingLevel.ERROR,
        'Gemini callout exception: ' + ex.getMessage()
      );

      return 'ERROR: ' + ex.getMessage();
    }
  }
}
