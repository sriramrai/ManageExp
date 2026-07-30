public class DTO_GeminiResponse {
  public List<Candidate> candidates;

  public class Candidate {
    public Content content;
  }

  public class Content {
    public List<Part> parts;
  }

  public class Part {
    public String text;
  }
}
