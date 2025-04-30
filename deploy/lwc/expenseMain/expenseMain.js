import { LightningElement, track, api } from 'lwc';

export default class ExpenseMain extends LightningElement {
    @track fromDate;
    @track toDate;
    @track total;
    @track entity;

    @api 
    get displayRagini() {
        let result = this.entity == 'Ragini' ? true : false;
        return result;
    }
    
    @api 
    get displayPapa() {
        let result = this.entity == 'Papa' ? true : false;
        return result;
    }

    @api get displayOther() {
        let result = this.entity == 'Other' ? true : false;
        return result;
    }
    
    getExpenseDetails() {
        return this.template.querySelector("c-expense-details-v2");
    }

    datachangedHandler(event) {
        this.fromDate = event.detail.fromDate;
        this.toDate = event.detail.toDate;
    }

    searchHandler(event) {
        let searchText = event.detail.searchText;
        let expenseDetails = this.getExpenseDetails();
        expenseDetails.searchData(searchText);
    }

    notifyExpenseDetails() {
        let expenseDetails = this.getExpenseDetails();
        if(expenseDetails != null) {
            expenseDetails.fromdate = this.fromDate;
            expenseDetails.todate = this.toDate;
            expenseDetails.entity = this.entity;
            expenseDetails.refreshRecord=true;
        }
    }

    totalUpdateHandler(event) {
        this.total = event.detail.total;
    }

    activeTabHandler(event) {
        this.entity = event.target.label;
        this.notifyExpenseDetails();
    }

    newrecordHandler(event) {
        let expenseDetails = this.getExpenseDetails();
        expenseDetails.refreshRecord = event.detail.newrecord;
        expenseDetails.refreshData();
    }

    selectedItemHandler(event) {
        console.log(event.detail.items);
        let childComp = this.getExpenseDetails();
        childComp.selectedItems = event.detail.items;
    }
}