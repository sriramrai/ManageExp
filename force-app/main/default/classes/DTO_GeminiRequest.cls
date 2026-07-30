public class DTO_GeminiRequest {
  public List<Content> contents;

  public class Content {
    public List<Part> parts;
  }

  public class Part {
    public String text;
  }
}
