public with sharing class OpenAIService {
  public static String testConnection() {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:OpenAI/v1/responses');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');

    req.setBody(
      JSON.serialize(
        new Map<String, Object>{
          'model' => 'gpt-5.5',
          'input' => 'Reply with only the word: Connected'
        }
      )
    );

    Http http = new Http();
    HttpResponse res = http.send(req);

    System.debug(res.getBody());

    return res.getBody();
  }
}
