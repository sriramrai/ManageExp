import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import { toString, log, logError } from 'c/utilityClass';

export default class CreateNewRecordModal extends LightningModal {
    @api content;
    get modalObj() {
        let myObj = this.content;
        return myObj;
    }

    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave(event) {
        log('inside handle save*****');
        let inputForm = this.template.querySelector("lightning-record-edit-form");
        log('inputForm**** : '+inputForm); 
        log('inputForm fields*** : '+inputForm.fields);
        inputForm.submit();
    }

    handleSuccess(event) {
        console.log('record saved successfully... : '+this.modalObj.fieldList[4].value);
        //let response = "{'STATUS': 'CREATED', 'BANK': this.modalObj.fieldList[4].value)}";
        const responseObj = {'STATUS': 'CREATED', 'BANK': this.modalObj.fieldList[4].value};
        this.handleOkay(responseObj);
    }

    handleError(event) {
        console.log('Error occured while saving record...');
    }
}