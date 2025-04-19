import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import validCheck from 'c/utilityClass';
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

    connectedCallback() {
        this.debitedBy = this.userId == '0057F000002MzEsQAK'? 'Other' : this.userId == '005GA00000B44UAYAZ' ? 'Papa' : 'Ragini';
        this.source = this.userId == '005GA00000B44UAYAZ' ? 'Cash' : 'Gpay';
    }

    handleAccountCreated() {
        // Run code when account is created.
        console.log('Accout Created..');
        this.close(true);
    }

    sourceChangeHandler(event) {
        this.creditSection = ['Axis CC', 'ICICI CC'].indexOf(event.target.value) > -1 ? true : false;
    }
}