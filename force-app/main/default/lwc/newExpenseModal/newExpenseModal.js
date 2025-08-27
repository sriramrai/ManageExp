import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import {log, logError, toString, validCheck} from 'c/utilityClass';
import ACCOUNT_OBJECT from "@salesforce/schema/Account";
import NAME_FIELD from "@salesforce/schema/Account.Name";
import WEBSITE_FIELD from "@salesforce/schema/Account.Website";
import Id from "@salesforce/user/Id";

export default class NewExpenseModal extends LightningModal {
    accountObject = ACCOUNT_OBJECT;
    nameField = NAME_FIELD;
    websiteField = WEBSITE_FIELD;
    @api content;
    @api modalData;
    @api headerText;
    expensename = this.modalData;
    debitedBy = 'Other';
    source = 'Gpay';
    userId = Id;
    creditSection = false;
    selectedDate = new Date().toISOString();
    emiTerms;
    
    connectedCallback() {
        this.debitedBy = this.userId == '0057F000002MzEsQAK'? 'Other' : this.userId == '005GA00000B44UAYAZ' ? 'Papa' : 'Ragini';
        this.source = this.userId == '005GA00000B44UAYAZ' ? 'Cash' : 'Gpay';
        log('this.selected date*** : '+this.selectedDate);
    }

    handleAccountCreated() {
        // Run code when account is created.
        console.log('Accout Created..');
        this.close(true);
    }

    sourceChangeHandler(event) {
        this.source = event.target.value;
        this.creditSection = ['Axis CC', 'ICICI CC'].indexOf(this.source) > -1 ? true : false;
    }

    @api
    get paymentDueDate() {
        log('inside payment due date*** : '+this.selectedDate);

        return this.selectedDate;
    }

    inputChangeHandler(event) {
        let value = event.target.value;
        let fieldName = event.target.fieldName;
        if(fieldName === 'Date__c') {
            this.selectedDate = value;
        }
    }
}