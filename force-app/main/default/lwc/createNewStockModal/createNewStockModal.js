import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { toString, log, logError } from 'c/utilityClass';
import postData from '@salesforce/apex/ExpenseManagerUtil.createStock';
export default class CreateNewStockModal extends LightningModal {
    @api content;
    dataObj = {};
    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave(event) {
        log('inside handle Save......');
        let inputFields = this.template.querySelectorAll("lightning-input");
        let validData = true;
        inputFields.forEach(field => {
            let fieldValue = field.value;
            let fieldname = field.fieldName;
            let fieldLabel = field.label;
            this.dataObj[fieldname] = field.value;
            if(fieldValue == '') {
                field.setCustomValidity(fieldLabel+' Can\'t be blank ');
                validData = false;
            }
            field.reportValidity();
        });
        log('prior to post valid check...');
        if(validData) {
            log('prior to post valid data...');
            this.dataObj['Total_buy__c'] = this.dataObj['Quantity__c'];
            this.dataObj['Total_Sold__c'] = 0;
            this.dataObj['Amount__c'] = this.dataObj['Total_buy__c']*this.dataObj['Buying_Price__c'];
            postData({'stockData': JSON.stringify(this.dataObj)})
            .then(success => {
                log('data saved successfully...');
                const responseObj = {'STATUS': 'CREATED', 'BANK': 'Stock'};
                this.handleOkay(responseObj);
            })
            .catch(error => {
                logError('Error occured while saving record.... : '+toString(error));
            })
        }
    }
}