import { LightningElement, track } from "lwc";
import chat from "@salesforce/apex/AIChatController.chat";

export default class AiChat extends LightningElement {
  @track messages = [];

  userInput = "";

  isTyping = false;

  messageCounter = 1;

  connectedCallback() {
    this.messages = [
      {
        id: this.messageCounter++,
        role: "assistant",
        text: "Hello 👋 I am your Finance AI Assistant.\n\nHow can I help you today?"
      }
    ];
  }

  handleInput(event) {
    this.userInput = event.target.value;
  }

  handleKeyDown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();

      this.sendMessage();
    }
  }

  async sendMessage() {
    if (!this.userInput.trim()) {
      return;
    }

    const userMessage = this.userInput;

    this.messages = [
      ...this.messages,
      {
        id: this.messageCounter++,
        role: "user",
        text: userMessage
      }
    ];

    this.userInput = "";
    this.isTyping = true;

    try {
      const request = {
        message: userMessage,
        history: this.buildHistory()
      };

      const response = await chat({ request });

      this.messages = [
        ...this.messages,
        {
          id: this.messageCounter++,
          role: "assistant",
          text: response.success ? response.message : response.errorMessage
        }
      ];
    } catch (e) {
      this.messages = [
        ...this.messages,
        {
          id: this.messageCounter++,
          role: "assistant",
          text: e.body?.message || e.message
        }
      ];
    } finally {
      this.isTyping = false;
      this.scrollToBottom();
    }
  }

  buildHistory() {
    return this.messages.map((message) => ({
      role: message.role,
      content: message.text
    }));
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      const body = this.refs.chatBody;

      if (body) {
        body.scrollTop = body.scrollHeight;
      }
    });
  }
}
