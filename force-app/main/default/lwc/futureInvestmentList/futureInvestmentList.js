import { LightningElement, api, wire } from 'lwc';
import getFutureInvestments from '@salesforce/apex/ExpenseManagerUtil.getAllFutureInvestments';
import {log, logError, toString, deepClone} from 'c/utilityClass';
import { refreshApex } from '@salesforce/apex';

export default class FutureInvestmentList extends LightningElement {
    @api bankName;
    provisionedItem;
    dataObj;

    @wire(getFutureInvestments, {})
    fetchAllFutureInvestments(result) {
        this.provisionedItem = result;
        let data = this.provisionedItem.data;
        let error = this.provisionedItem.error;
        if(data) {
            data.forEach(dataObj => {
                if(dataObj.bankName == this.bankName) {
                    this.dataObj = deepClone(dataObj);
                    return;
                }
            });
            log('Data fetched successful.... : '+toString(this.dataObj));
        }else if(error) {
            logError('Error while fetching data.... : '+toString(error));
        }
    }

    badgeClickHandler(event) {
        let selectedRecord = event.target.dataset.id;
        let url = '/'+selectedRecord;
        window.open(url, '_blank');
    }

    @api newRecordCreatedHandler() {
        log('inside new record created handler**** : '+this.bankName);
        refreshApex(this.provisionedItem);
    }
}