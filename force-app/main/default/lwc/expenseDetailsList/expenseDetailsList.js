import { LightningElement, api } from 'lwc';
import deleteELI from '@salesforce/apex/ExpenseController.deleteELI';
import LightningConfirm from "lightning/confirm";
import ltngMoreActionModal from 'c/expenseMoreActionModal';
import ltngEditRecord from 'c/editExpenseForm';
import { NavigationMixin } from 'lightning/navigation';

export default class ExpenseDetailsList extends NavigationMixin(LightningElement) {
    @api recordList = [];
    get records() {
        return this.recordList.map(rec => ({
            ...rec,
            recordUrl: '/' + rec.Id
        }));
    }
    async moreActionHandler(event) {
        let recordId = event.target.getAttribute("data-id");
        this.result = await ltngMoreActionModal.open({
            size: 'small',
            description: 'Accessible description of modal\'s purpose',
            content: recordId,
            headerText: 'Perform More',
            modalData : [{'no': '1', 'label': 'Edit'}, {'no': '2', 'label': 'Delete'}],
        });
        /* if(this.result ==1 ) {
            this.viewRecord(recordId);
        } */
        if(this.result == 1) {
            this.editRecord(recordId);
        }else if(this.result == 2) {
            this.deleteRecord(recordId);
        }
    
        // Wait for DOM to settle
        requestAnimationFrame(() => {
            const containerChoosen = this.template.querySelector('.expense_container1');
            if(containerChoosen) {
                containerChoosen.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                });
            }
        });
    }

    viewRecord(recordId) {
        console.log('inside view record...');
        //window.open('/'+recordId, "_blank");
        // Bug Fix as navigation not working in mobile device
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view'
            }
        });
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

    refreshData() {
        const dataRefresh = new CustomEvent("updatedata");
        this.dispatchEvent(dataRefresh);
    }
}