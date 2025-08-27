import { LightningElement, api, wire } from 'lwc';
import getCCStatements from '@salesforce/apex/ExpenseController.getCCStatements';
import {log, logError, isValid, toString} from 'c/utilityClass';
import updatePayment from '@salesforce/apex/ExpenseController.updateCCStatements'


export default class CreditCardMonitor extends LightningElement {
    total = 0;
    data = [];
    selectedMonth;
    selectedYear;
    columns = [
        {label: 'Amount', fieldName: 'Amount__c'},
        {label: 'Details', fieldName: 'Details__c'},
        {label: 'Date', fieldName: 'Date__c'},
        {label: 'Due Date', fieldName: 'Payment_Due_Date__c'}
    ];

    connectedCallback() {
        let today = new Date();
        this.selectedMonth = today.getMonth()+1;
        this.selectedYear = today.getFullYear();
        this.fetchData();
    }

    async fetchData(event) {
        log('inside fetchData method');
        try {
            this.recordMap = await getCCStatements({month: this.selectedMonth, year : this.selectedYear});
            log('Data retrieved successful....'+toString(this.recordMap));
            this.initData();
        } catch(error) {
            logError('Error Occured imp...'+toString(error));
        }
    }
    currentMonthDue = [];
    nextMonthDue = [];
    initData() {
        this.currentMonthDue = [];
        this.nextMonthDue = [];
        for(const key in this.recordMap) {
            let bankName = key.split(' ')[0];
            for(let obj of this.recordMap[key]) {
                if(key.includes('DUETM')) {
                    this.currentMonthDue.push(obj);
                }else {
                    this.nextMonthDue.push(obj)
                }
            }
        }
        log('Current Month Due*** : '+toString(this.currentMonthDue));
        log('Next Month Due*** : '+toString(this.nextMonthDue));
    }

    get months() {
        return [
            {label: 'Jan', value: 1},
            {label: 'Feb', value: 2},
            {label: 'Mar', value: 3},
            {label: 'Apr', value: 4},
            {label: 'May', value: 5},
            {label: 'Jun', value: 6},
            {label: 'Jul', value: 7},
            {label: 'Aug', value: 8},
            {label: 'Sep', value: 9},
            {label: 'Oct', value: 10},
            {label: 'Nov', value: 11},
            {label: 'Dec', value: 12},
        ];
    }

    get years() {
        return [
            {label: '2025', value: 2025},
            {label: '2026', value: 2026},
            {label: '2027', value: 2027},
            {label: '2028', value: 2028},
            {label: '2029', value: 2029},
            {label: '2030', value: 2030},
        ];
    }

    get banks() {
        return [
            {label: 'Axis', value: 'Axis CC'},
            {label: 'ICICI', value: 'ICICI CC'}
        ];
    }

    optionChangeHandler(event) {
        let value = event.target.value;
        let fieldName = event.target.name;
        if(fieldName === 'month') {
            this.selectedMonth = parseInt(value);
        }else {
            this.selectedYear = parseInt(value);
        }
    }

    settleHander(event) {
        let paymentDate = prompt('Enter the payment Date in (dd/mm/yyyy)');
        let recordId = event.currentTarget.dataset.id;
        if(isValid(paymentDate)) {
            updatePayment({recordId: recordId, paymentDate : paymentDate})
            .then(success => {
                log('Data updated successfully...');
                this.fetchData();
            }).catch(error => {
                logError('Data Update Failed..... : '+toString(error));
            })
        }
    }
}