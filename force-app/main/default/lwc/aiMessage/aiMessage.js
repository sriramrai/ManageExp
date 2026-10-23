import { LightningElement, api } from "lwc";
import { parseMarkdown } from "c/markdownParser";
export default class AiMessage extends LightningElement {
  @api message;

  get isUser() {
    return this.message?.role === "user";
  }

  get bubbleClass() {
    return this.isUser ? "message-row user" : "message-row assistant";
  }

  get bubbleStyle() {
    return this.isUser ? "bubble user-bubble" : "bubble assistant-bubble";
  }
  get formattedMessage() {
    return parseMarkdown(this.message.text);
  }
}
