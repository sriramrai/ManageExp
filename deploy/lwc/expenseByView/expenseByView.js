import { LightningElement, api, wire, track } from 'lwc';
import getAllExpenses from '@salesforce/apex/ExpenseController.getAllExpensesV2';

export default class ExpenseByView extends LightningElement {
    @api viewmode;
    @track records = [];
    sortBy;
    sortDirection;
    columns = [
        { label: 'Month', fieldName: 'Name', hideDefaultActions: 'true'},
        { label: 'Ragini', fieldName: 'Ragini__c', type: 'currency', hideDefaultActions: 'true', sortable: true},
        { label: 'Sriram', fieldName: 'Other__c', type: 'currency', hideDefaultActions: 'true', sortable: true},
    ];
    

    @wire(getAllExpenses)
    getRecords({error, data}) {
        if(data) {
            this.records = data;
            this.calculateTotal();
        }else if(error) {
            console.error('Error occured while fetching records...');
        }
    }

    doSorting(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(this.sortBy, this.sortDirection);
    }

    sortData(fieldname, direction) {
        console.log('inside sort data....');
        console.log(fieldname +' - '+ direction);
        let parseData = JSON.parse(JSON.stringify(this.records));
        // Return the value stored in the field
        let keyValue = (a) => {
            return a[fieldname];
        };
        // cheking reverse direction
        let isReverse = direction === 'asc' ? 1: -1;
        // sorting data
        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';
            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });
        this.records = parseData;
    }    

    calculateTotal() {
        let total = 0;
        this.records.forEach(record => {
            total += record.Ragini__c + record.Other__c;
        });
        let customEvent = new CustomEvent("updatetotal", {detail: {total: total}});
        this.dispatchEvent(customEvent);
    }
}