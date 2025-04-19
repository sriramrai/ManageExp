import { LightningElement, api, wire } from 'lwc';
import currentExpenseId from '@salesforce/apex/ExpenseController.getCurrentExpenseId';
import ltngNewExpenseModal from 'c/newExpenseModal';

export default class ExpenseHeaderV2 extends LightningElement {
    @api total;
    startDate;
    endDate;
    currentExpenseId;
    @api selectedItems;
    //section='';
    
    @wire(currentExpenseId)
    getCurrentId({error, data}) {
        if(data) {
            this.currentExpenseId = data;
        }else if(error) {
            console.error('Error Occured while fetching current Expense Id');
            console.error(error);
        }
    }

    connectedCallback() {
        this.init();
    }

    init() {
        let today = new Date(), y=today.getFullYear(), m=today.getMonth();
        let firstDate = new Date(y, m, 1);
        let lastDate = new Date(y, m+1, 0);
        this.startDate = new Date(firstDate.getTime() - (firstDate.getTimezoneOffset() * 60000 )).toISOString().split("T")[0];
        this.endDate = new Date(lastDate.getTime() - (lastDate.getTimezoneOffset() * 60000 )).toISOString().split("T")[0];
        this.notifyParent();
    }

    searchHandler(event) {
        let searchText = event.target.value;
        let searchEvent = new CustomEvent("searchevent", {detail: {searchText: searchText}});
        this.dispatchEvent(searchEvent);
    }

    dateChangeHandler(event) {
        let changedValue = event.target.value;
        let changedTarget = event.target.name;
        if(changedTarget == 'from') {
            this.startDate = changedValue;
        }else {
            this.endDate = changedValue;
        }
    }

    refetchRecords() {
        console.log('inside refetch records...');
        this.notifyParent();
    }

    notifyParent() {
        let customEvent = new CustomEvent("datachanged", {detail: {fromDate: this.startDate, toDate: this.endDate}});
        this.dispatchEvent(customEvent);
    }

    async createRecord(event) {
        let result = await ltngNewExpenseModal.open({
            size: 'small',
            description: 'Accessible description of modal\'s purpose',
            content: 'test contetnt',
            headerText:'Set the filter',
            modalData : this.currentExpenseId,
        });

        console.log('record created successfully...');
        console.log(result);
        if(result) {
            let customEvent = new CustomEvent("newrecord", {detail : {newrecord: true}});
            this.dispatchEvent(customEvent);
        }
    }

   /*  handleSectionToggle(event) {
        this.section = event.detail.openSections;
    } */
}