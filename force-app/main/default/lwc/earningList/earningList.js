import { LightningElement, wire, api, track } from 'lwc';
import {log, logError, toString, getFYForExpManager} from 'c/utilityClass';
import getEarnings from '@salesforce/apex/ExpenseManagerUtil.getEarnings';
import manageEarningModal from 'c/manageEarning';
import { refreshApex } from "@salesforce/apex";

export default class EarningList extends LightningElement {
    fyValue = '2025-2026';
    @track earningList = [];
    earningDataObj;

    @wire(getEarnings, {'fiscalYear' : '$fyValue'})
    earnings(earningObj) {
        this.earningDataObj = earningObj;
        if(earningObj.data) {
            let dataObj = JSON.parse(JSON.stringify(earningObj.data));
            dataObj.forEach(item => {
                let obj = {}
                for(let key in item) {
                    if(key == 'Id') {
                        obj['recordURL'] = '/'+item.Id;
                    }
                    obj[key] = item[key];
                }
                this.earningList.push(obj);
            });
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

    navigateToPage(event) {
        let password = prompt('Enter Password');
        if(password != '100') {
            event.preventDefault();
        }
    }
}