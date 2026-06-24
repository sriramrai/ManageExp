import { LightningElement } from "lwc";

import askQuestion from "@salesforce/apex/FinanceCopilotController.askQuestion";

export default class FinanceCopilot extends LightningElement {
  question = "";
  response = "";

  handleChange(event) {
    this.question = event.target.value;
  }

  send() {
    askQuestion({
      question: this.question
    }).then((result) => {
      this.response = result;
    });
  }
}
