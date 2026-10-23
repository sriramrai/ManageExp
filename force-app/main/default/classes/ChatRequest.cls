public class ChatRequest {
  @AuraEnabled
  public String message { get; set; }

  @AuraEnabled
  public List<ChatMessage> history { get; set; }

  public class ChatMessage {
    @AuraEnabled
    public String role { get; set; }

    @AuraEnabled
    public String content { get; set; }
  }
}
