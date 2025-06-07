import { api } from 'lwc';
import LightningModal from 'lightning/modal';
import { toString, log, logError } from 'c/utilityClass';
import manageStock from '@salesforce/apex/ExpenseManagerUtil.manageStock';

export default class BuySellStockModal extends LightningModal {
    @api content;

    connectedCallback() {
        this.actionLabel = this.content.actionLabel;
    }

    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave(event) {
        const allElements = this.template.querySelectorAll('lightning-input');
        log('content *** : '+this.content);
        let invId = this.content.id.split('-')[0];
        this.actionLabel = this.content.actionLabel;
        log('invId*** : '+invId);
        let obj = {
            'Investment__c': invId
        };

        allElements.forEach(element => {
            let elementName = element.label;
            let elementValue = element.value;
            let elementFieldName = element.fieldName;
            obj[elementFieldName] = elementValue;
        });
        obj['Amount__c'] = obj['Per_Share_Price__c']*obj['Quantity__c'];
        obj['Amount__c'] = this.roundToDecimalPlaces(obj['Amount__c'], 2);
        obj['Type__c'] = this.actionLabel == 'Buy' ? 'Re-invest' : 'Closed';
        obj['Buy_Sell__c'] = this.actionLabel == 'Buy' ? 'Buy' : 'Sell';
        log('obj to posted*** : '+toString(obj));
        manageStock({'stockData': toString(obj)})
        .then(success => {
            this.handleOkay('CREATED');
        })
        .catch(error => {
            logError('record creation failed.... : '+toString(error));
        })
    }

    roundToDecimalPlaces(number, decimalPlaces) {
        const multiplier = Math.pow(10, decimalPlaces);
        return Math.round(number * multiplier) / multiplier;
    }
}