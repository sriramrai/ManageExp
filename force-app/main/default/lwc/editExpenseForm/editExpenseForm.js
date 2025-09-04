import { api, wire, track } from 'lwc';
import LightningModal from 'lightning/modal';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import SOURCE_FIELD from '@salesforce/schema/Expense_Line_Item__c.Source__c';


export default class EditExpenseForm extends LightningModal {
    @api content;
    @api headerText;
    @track displayEmi = false;

    @wire(getRecord, {recordId: '$content', fields: [SOURCE_FIELD]})
    wiredRecord({ error, data }) {
        if(data) {
            let sourceField = getFieldValue(data, SOURCE_FIELD);
            this.displayEmi = (sourceField == 'Axis CC' || sourceField == 'ICICI CC') ? true : false;
            console.log('data fetched **** : '+JSON.stringify(data));
        }else if(error) {
            console.log('Error occured *** : '+JSON.stringify(error));
        }
    }

    sourceChangeHandler(event) {
        let source = event.target.value;
        this.displayEmi = (source == 'Axis CC' || source == 'ICICI CC') ? true : false;
    }

    handleSuccess(event) {
        this.close(true);
    }
}