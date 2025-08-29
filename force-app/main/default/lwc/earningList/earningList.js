import { LightningElement, wire, api } from 'lwc';
import {log, logError, toString, getFYForExpManager} from 'c/utilityClass';
import getEarnings from '@salesforce/apex/ExpenseManagerUtil.getEarnings';
import manageEarningModal from 'c/manageEarning';
import { refreshApex } from "@salesforce/apex";

export default class EarningList extends LightningElement {
    fyValue = '2025-2026';
    earningList = [];
    earningDataObj;

    @wire(getEarnings, {'fiscalYear' : '$fyValue'})
    earnings(earningObj) {
        this.earningDataObj = earningObj;
        if(earningObj.data) {
            this.earningList = earningObj.data;
            log('Earning fetched successfully.... : '+toString(earningObj.data));
        }else if(earningObj.error) {
            logError('Error while fetching earning... : '+toString(earningObj.error));
        }
    }

    get options() {
        return getFYForExpManager();
    }

    handleChange(event) {
        this.fyValue = event.target.value;
        this.earningList = null;
        this.enableCreate = false;
    }

    async createNew(event) {
        let result = await manageEarningModal.open({
            size: 'small',
            description: 'Accessible description of modal\'s purpose',
            content: 'test contetnt',
            headerText:'Set the filter',
            modalData : this.currentExpenseId,
        });

        if(true) {
            refreshApex(this.earningDataObj);
        }
    }
}