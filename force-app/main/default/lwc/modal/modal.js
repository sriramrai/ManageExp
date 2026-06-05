import { LightningElement, api } from "lwc";

export default class Modal extends LightningElement {
  @api title = "Modal Title";
  @api isOpen = false;
  @api buttons = []; // Array of button objects: { label: 'Button Text', variant: 'brand' }

  // Call this from parent to open modal
  @api open() {
    this.isOpen = true;
  }

  // Call this from parent or close internally
  @api close() {
    this.isOpen = false;
  }

  handleClose() {
    this.close();
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleButtonClick(event) {
    const buttonLabel = event.currentTarget.dataset.label;
    this.dispatchEvent(
      new CustomEvent("buttonclick", {
        detail: {
          label: buttonLabel
        }
      })
    );
    this.close();
  }

  handleBackdropClick() {
    this.handleClose();
  }
}
