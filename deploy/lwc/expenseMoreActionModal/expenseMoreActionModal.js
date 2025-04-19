import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class ExpenseMoreActionModal extends LightningModal {
    @api actionList = [];
    @api headerText;
    @api content;
    @api modalData;
    
    connectedCallback() {
        this.modalData.forEach(data => {
            this.actionList.push(data);
        });
    }

    buttonClickedHandler(event) {
        let operationno = event.target.getAttribute("data-id");
        this.close(operationno);
    }
}