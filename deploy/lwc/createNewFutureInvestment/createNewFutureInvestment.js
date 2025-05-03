import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import { toString, log, logError } from 'c/utilityClass';
import postData from '@salesforce/apex/ExpenseManagerUtil.postFutureInvestment';

export default class CreateNewFutureInvestment extends LightningModal {
    @api content;
    dataObj;

    get modalObj() {
        let myObj = {
            'bank' : this.content,
            'date': new Date(Date.now()).toISOString()
        }
        this.dataObj = myObj;
        return myObj;
    }

    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave(event) {
        let inputFields = this.template.querySelectorAll("lightning-input");
        let validData = true;
        inputFields.forEach(field => {
            let fieldValue = field.value;
            let fieldname = field.name;
            let fieldLabel = field.label;
            this.dataObj[fieldname] = field.value;
            if(fieldValue == '') {
                field.setCustomValidity(fieldLabel+' Can\'t be blank ');
                validData = false;
            }
            field.reportValidity();
        });
        
        if(validData) {
            postData({'formData': JSON.stringify(this.dataObj)})
            .then(success => {
                log('data saved successfully...');
                const responseObj = {'STATUS': 'CREATED', 'BANK': this.content};
                this.handleOkay(responseObj);
            })
            .catch(error => {
                logError('Error occured while saving record.... : '+toString(error));
            })
        }
    }

    @api newRecordCreatedHandler() {

    }
}