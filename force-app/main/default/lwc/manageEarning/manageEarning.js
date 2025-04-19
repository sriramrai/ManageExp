import { LightningElement, wire, track } from 'lwc';
import getSalaryStructure from '@salesforce/apex/ExpenseManagerUtil.getSalaryStructure';
import getEarning from '@salesforce/apex/ExpenseManagerUtil.getEarning';
import { refreshApex } from "@salesforce/apex";
import { log, logError, getFYForExpManager, 
            getMonthOptionForExpManager, getSalaryAmountFields} from 'c/utilityClass';
import { CurrentPageReference } from 'lightning/navigation';

export default class ManageEarning extends LightningElement {
    fyValue = '2025-2026';
    selectedMonth = '04';
    @track data = {};
    salaryStructure;
    earning;
    disableForm=false;
    displayNewLink = false;
    createNewClicked = false;
    showCreateSection = false;
    @track diffData = {};

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef) {
            // Extracting URL parameters
            this.urlParams = pageRef.state;
            log('urlparmas*** : '+JSON.stringify(this.urlParams));
        }
    }

    @wire (getSalaryStructure, {'fy' : '$fyValue'})
    fetchSalaryStructure({ data, error }) {
        if(data) {
            this.salaryStructure = JSON.parse(JSON.stringify(data));
            this.salaryStructure.Id = '';
        }else if(error) {
            logError('Error Occurred while fetching Salary Structure....');
        }
    }

    @wire(getEarning, {'fy' : '$salaryStructure.Fiscal_Year__c', 'month' : '$selectedMonth'})
    fetchEarning( eanrningObj ) {
        this.data = null;
        this.earning = null;
        this.earning = eanrningObj;
        if(eanrningObj) {
            if(this.earning.data) {
                if(this.salaryStructure) {
                    this.initData();
                }
            }else if(this.earning.error) {
                logError('error occured while provisioning earning object...');
            }else {
                if(this.salaryStructure) {
                    this.initData();
                }
            }
        }
    }

    connectedCallback() {
        log('inside connected callback123....');
        logError('inside connected callback....');
    }

    initData() {
        this.displayNewLink = true;
        this.showCreateSection = false;
        this.data = this.salaryStructure;
        this.disableForm = this.data.Id != '' ? false : true;
        if(this.earning.data) {
            this.data = this.earning.data;
            this.showCreateSection = true;
            this.displayNewLink = false;
        }

        this.constructDiffData();
    }

    diffValue(field, sourceValue) {
        let diff = sourceValue <= this.salaryStructure[field] ? 
                    this.salaryStructure[field]-sourceValue : 
                    sourceValue-this.salaryStructure[field];
        diff = sourceValue >= this.salaryStructure[field] ? diff*(1) : diff*(-1);
        return diff.toString();
    }

    constructDiffData() {
        this.diffData = {}
        let amountFields = getSalaryAmountFields();
        for(const field in this.data) {
            if(amountFields.indexOf(field) > -1) {
                this.diffData[field] = this.diffValue(field, this.data[field]);
            }
        }
        log('Diffdata*** : '+JSON.stringify(this.diffData));
    }

    get options() {
        return getFYForExpManager();
    }

    get monthOptions() {
        return getMonthOptionForExpManager();
    }

    createEarning() {
        this.displayNewLink = false;
        this.showCreateSection = true;
        this.disableForm = false;
    }

    handleCancel(event) {
        if(this.data.Id) {
            this.disableForm = true;
            this.resetFields();
        }else {
            this.showCreateSection = false;
            this.displayNewLink = true;
        }
    }

    handleSuccess() {
        refreshApex(this.earning);
        this.disableForm = true;
    }

    enableEdit() {
        this.disableForm = false;
    }

    handleMonthChange(event) {
        this.showCreateSection = false;
        this.selectedMonth = event.target.value;
        refreshApex(this.earning);
    }

    inputChangeHandler(event) {
        log('inpur change handler called...'+event.target.value);
        let field = event.target.fieldName;
        let changedValue = event.target.value;
        this.diffData[field] = this.diffValue(field, changedValue);
    }

    resetFields() {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        let amountFields = getSalaryAmountFields();
        inputFields.forEach( field => {
            field.reset();
            let fieldName = field.fieldName;
            if(amountFields.indexOf(fieldName) > -1) {
                this.diffData[fieldName] = this.diffValue(fieldName, this.data[fieldName]);
            }
        });
    }
}