import { LightningElement, api, track, wire} from 'lwc';
import {log, deepClone} from 'c/utilityClass';
import renewalModal from 'c/renewalModal';
import getAllInvestmentByBank from '@salesforce/apex/ExpenseManagerUtil.getAllInvestmentByBank';
import { refreshApex } from '@salesforce/apex';

export default class InvestmentList extends LightningElement {
    @api ivts;
    @api bankName;
    totalInvested = 0;
    totalMaturity = 0;
    @track investments = [];
    provisionedItem;

    @wire(getAllInvestmentByBank, {'bankName' : '$bankName'})
    allInvestment(result) {
        this.provisionedItem = result;
        let data = result.data;
        let error = result.error;
        this.investments = [];
        if(data) {
            let myObjs = deepClone(data);
            myObjs.forEach(element => {
                this.totalInvested += element.Amount__c;
                this.totalMaturity += element.Maturity_Amount__c;
                element.badgeStyle = 'badge-green';
                let today = new Date();
                let maturityDate = new Date(element.Maturity_Date__c);
                if(maturityDate <= today) {
                    element.badgeStyle = 'badge-red';
                }
                const oneDay = 24 * 60 * 60 * 1000; 
                const differenceMs = Math.abs(maturityDate - today);
                const differenceDays = Math.round(differenceMs / oneDay);
                element.daysLeft = this.convertIntoMonth(differenceDays);
                this.investments.push(element);
            });
            this.totalInvested = Math.trunc(this.totalInvested);
            this.totalMaturity = Math.trunc(this.totalMaturity);
            this.investments = this.sortArray(this.investments);

        }else if(error) {
            logError('Error While Fetching Investment record...');
        }
    }


    sortArray(arr) {
        arr.sort(function (a, b) {
            let d1 = a.Maturity_Date__c;
            let d2 = b.Maturity_Date__c;
            if(d1 < d2) {
                return -1;
            }
            if(d2 > d1) {
                return 1;
            }
        });
        return arr;
    }

    badgeClickHandler(event) {
        let selectedRecord = event.target.dataset.id;
        let url = '/'+selectedRecord;
        window.open(url, '_blank');
    }

    async renewCloseHandler(event) {
        let selectedRecord = event.target.dataset.id;
        let selectedAccountNumber = event.target.dataset.acc;
        selectedRecord = selectedRecord + "#" + selectedAccountNumber;
        const result = await renewalModal.open({
            size: 'small',
            description: 'Renewal/Close',
            content: selectedRecord
        });
        if(result == 'refresh') {
            refreshApex(this.provisionedItem);
        }
    }

    convertIntoMonth(days) {
        let result = '';
        if(days >= 365) {
            let yr = Math.floor(days / 365);
            result += yr + ' Year ';
            days = days % 365;
        }
        if(days >= 30) {
            let month = Math.floor(days / 30);
            result += month + ' Month '
            days = days%30;
        }
        if(days > 0) {
            result += days + ' Days'
        }

        return result;
    }
    
    
    get title() {
        return 'Total '+this.total;
    }

    @api newRecordCreatedHandler() {
        log('inside new record created handler**** : '+this.bankName);
        refreshApex(this.provisionedItem);
    }
}