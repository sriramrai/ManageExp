import { LightningElement, api } from 'lwc';

export default class Modal extends LightningElement {
    @api title = 'Modal Title';
    @api isOpen = false;

    //@api showCancel = true;
    //@api showSubmit = true;
    @api cancelLabel = 'Cancel';
    @api submitLabel = 'Submit';

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
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleSubmit() {
        this.dispatchEvent(new CustomEvent('submit'));
    }

    handleBackdropClick() {
        this.handleClose();
    }
}
