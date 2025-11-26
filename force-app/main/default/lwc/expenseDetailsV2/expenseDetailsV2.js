import { LightningElement, api, wire, track } from 'lwc';
import getExpense from '@salesforce/apex/ExpenseController.getExpensesV2'
import { refreshApex } from "@salesforce/apex";
import deleteELI from '@salesforce/apex/ExpenseController.deleteELI';
import LightningConfirm from "lightning/confirm";
import ltngMoreActionModal from 'c/expenseMoreActionModal';
import ltngEditRecord from 'c/editExpenseForm';
import {log, logError, toString} from 'c/utilityClass';

export default class ExpenseDetailsV2 extends LightningElement {
    @track dataMap = new Map();
    @api entity;
    @api fromdate;
    @api todate;
    @track data = [];
    @api refreshRecord=false;
    expenseResult;
    allrecords;
    total;
    @track selectedItems = [];
    @track groceries = [];
    @track utilitybills = [];
    
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

    calculateTotal() {
        this.total = 0;
        this.allrecords.forEach(record => {
            this.total += record.Amount__c;
            if(record.Category__c == 'Grocery') {
                this.groceries.push(record);
            }else if(record.Category__c == 'Utility & Bill') {
                this.utilitybills.push(record);
            }
            if(this.dataMap.has(record.Category__c)) {
                this.dataMap.get(record.Category__c).push(record);
            }else {
                this.dataMap.set(record.Category__c, [record]);
            }
        });
        let customEvent = new CustomEvent("updatetotal", {detail: {total: this.total}});
        this.dispatchEvent(customEvent);
        log('MyMap**** : '+this.dataMap);
    }

    @api refreshData() {
        refreshApex(this.expenseResult);
    }

    @api searchData(searchText) {
        if(searchText) {
            this.allrecords = this.expenseResult.data.filter(
                function(item) {
                    if(item.Details__c.toLowerCase().includes(searchText.toLowerCase())) {
                        return true;
                    }
                    return false;
                }
            );
        }else {
            this.allrecords = this.expenseResult.data;
        }
        this.calculateTotal();
    }

    updateDataTableSelection() {
        this.selectedItems = [];
        let selectedrows = this.template.querySelector("lightning-datatable").getSelectedRows();
        selectedrows = [];
        this.template.querySelector("lightning-datatable").selectedRows=[];
    }

    viewRecord(recordId) {
        console.log('inside view record...');
        window.open('/'+recordId, "_blank");
    }

    async editRecord(recordId) {
        const result = await ltngEditRecord.open({
            size: 'small',
            description: 'Edit Expense',
            content: recordId,
            headerText: 'Edit Record'
        });
        if(this.result) {
            this.refreshData();
        }
    }

    async deleteRecord(recordId) {
        const result = await LightningConfirm.open({
            message: "Do you really want to delete this record.",
            variant: "headerless",
            label: "This is the aria-label value",
        });
        if(result) {
            deleteELI({'recordIds' : JSON.stringify([recordId])})
            .then((result) => {
                this.refreshData();
            })
            .catch((error) => {
                console.error('Error Occured while posting data...');
            })
        }
    }

    async moreActionHandler(event) {
        let containerChoosen = this.template.querySelector('.expense_container');
        let recordId = event.target.getAttribute("data-id");
        this.result = await ltngMoreActionModal.open({
            size: 'small',
            description: 'Accessible description of modal\'s purpose',
            content: recordId,
            headerText: 'Perform More',
            modalData : [{'no': '1', 'label': 'View'}, {'no': '2', 'label': 'Edit'}, {'no': '3', 'label': 'Delete'}],
        });
        if(this.result ==1 ) {
            this.viewRecord(recordId);
        }
        if(this.result == 2) {
            this.editRecord(recordId);
        }else if(this.result == 3) {
            this.deleteRecord(recordId);
        }
        console.log('zcontainerChoosen : '+containerChoosen);
        containerChoosen.scrollIntoView();
    }

    handleSectionToggle(event) {
        const openSections = event.detail.openSections;
    }

    @api
    get groceryLabel() {
        return 'Grocery--------' + this.totalSum(this.groceries);
    }

    totalSum(dataArray) {
        let result = 0;
        dataArray.forEach(element => {
            result += element.Amount__c;
        });
        return result;
    }
    /* @api 
    get groceries() {
        let records = this.dataMap.has('Grocery') ? this.dataMap.get('Grocery') : [];
        return records;
    } */
}