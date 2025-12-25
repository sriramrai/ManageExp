import { LightningElement, api, wire, track } from 'lwc';
import getExpense from '@salesforce/apex/ExpenseController.getExpensesV2'
import { refreshApex } from "@salesforce/apex";
import serachExp from '@salesforce/apex/ExpenseController.searchExpense';
import { log, logError, toString } from 'c/utilityClass';

export default class ExpenseDetailsV2 extends LightningElement {
    @api entity;
    @api fromdate;
    @api todate;
    @track data = [];
    @api refreshRecord=false;
    expenseResult;
    allrecords;
    total;
    @track accordionData = [];
    @api
    get getLabel() {
        return 'Grocery 1000';
    }
    @wire (getExpense, {'fromDate' : '$fromdate', 'toDate' : '$todate', 'expenseBy' : '$entity'})
    expenses(result) {
        this.expenseResult = result;
        if(result.data) {
            if(this.refreshRecord) {
                this.refreshData();
            }
            this.allrecords = result.data;
            this.calculateTotal();
        }else if(result.error) {
            console.error('Error Occured while retrieving data..'+result.error);
        }
    }

    calculateTotal(operation) {
        this.total = 0;
        const tempMap = {};
        this.allrecords.forEach(record => {
            this.total += record.Amount__c;
            const category = record.Category__c;
            if(!tempMap[category]) {
                tempMap[category] = [];
            }
            tempMap[category].push(record);
        });
        this.accordionData = Object.keys(tempMap).map(cat => ({
            category: operation == 'Searched Result' ? operation : cat,
            records: tempMap[cat],
            totals: this.totalSum(tempMap[cat])
        }));
        let customEvent = new CustomEvent("updatetotal", {detail: {total: this.total}});
        this.dispatchEvent(customEvent);
        log('MyMap**** : '+toString(this.dataMap));
    }

    @api refreshData() {
        refreshApex(this.expenseResult);
    }

    @api async searchData(searchText, fromAll) {
        if(searchText && searchText.length > 2) {
            this.allrecords = await serachExp({'searchtext': searchText, 'fromAll': fromAll});
        }else {
            this.allrecords = this.expenseResult.data;
        }
        this.calculateTotal('Searched Result');
    }

    handleSectionToggle(event) {
        const openSections = event.detail.openSections;
    }

    dataUpdateHandler(event) {
        this.refreshData();
    }

    totalSum(dataArray) {
        let result = 0;
        dataArray.forEach(element => {
            result += element.Amount__c;
        });
        return result;
    }
}