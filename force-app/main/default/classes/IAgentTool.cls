public interface IAgentTool {
  String getName();
  String getDescription();
  List<String> getSupportedActions();
  ToolResult execute(Map<String, Object> arguments);
}
