public with sharing class Agent_ToolRegistry {
  public static List<IAgentTool> getTools() {
    return new List<IAgentTool>{ new ExpenseTool() };
  }

  public static IAgentTool getTool(String toolName) {
    for (IAgentTool tool : getTools()) {
      if (tool.getName().equalsIgnoreCase(toolName)) {
        return tool;
      }
    }

    return null;
  }
}
