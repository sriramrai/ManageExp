import { LightningElement, wire} from 'lwc';
import getAllInvestMentMap from '@salesforce/apex/ExpenseManagerUtil.getAllInvestMentMap';
import { log, logError, toString, deepClone, isValidValue} from 'c/utilityClass';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import createRecordModal from 'c/createNewRecordModal';
import createNewFutureInvestmentModal from 'c/createNewFutureInvestment';

export default class ManageInvestment extends NavigationMixin(LightningElement) {
    sbiEntries = [];
    axisEntries = [];
    scEntries = [];
    ppfEntries = [];
    npsEntires = [];
    provisionedItem;
    activeTabName = 'SBI';
    fdTabs = ['AXIS', 'SBI'];
    futureInvestmentTabs = ['NPS', 'PPF'];

    get getSbiLabel() {
        return 'SBI ('+this.sbiEntries.length+')';
    }

    get getAxisLabel() {
        return 'AXIS (' + this.axisEntries.length+')';
    }
    
    @wire(getAllInvestMentMap, {})
    allInvestment(result) {
        this.provisionedItem = result;
        let data = result.data;
        let error = result.error;
        if(data) {
            for(const bank in data) {
                if(bank == 'sbi') {
                    this.sbiEntries = this.sortArray(deepClone(data[bank]));
                }else if(bank == 'axis') {
                    this.axisEntries = this.sortArray(deepClone(data[bank]));
                }else if(bank == 'sc') {
                    this.scEntries = deepClone(data[bank]);
                }else if(bank == 'nps') {
                    this.npsEntires = deepClone(data[bank]);
                }else if(bank == 'ppf') {
                    this.ppfEntries = deepClone(data[bank]);
                }
            }

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
    activeTabHandler(event) {
        let activeTab = event.target.value;
        this.activeTabName = activeTab;
    }

    refreshHandler(event) {
        refreshApex(this.provisionedItem);
    }

    counterHandler(event) {
        log('inside conter Handler*** : '+event.detail.count);
    }

    async logFd() {
        let contentData = {
            'objectapiname': 'Investment__c',
            'fieldList' : this.getFieldList()
        }

        const result = await createRecordModal.open({
            size: 'small',
            description: 'Renewal/Close',
            content: contentData
        });

        return result;
    }

    async logFutureInvestment() {
        const result = await createNewFutureInvestmentModal.open({
            size: 'small',
            description: 'Future Investment',
            content: this.activeTabName
        });

        return result;
    }

    async createInvestment(event) {
        let result;
        if(this.fdTabs.indexOf(this.activeTabName) >= 0) {
            result = await this.logFd();
        }else if(this.futureInvestmentTabs.indexOf(this.activeTabName) >= 0) {
            result = await this.logFutureInvestment();
        }else {
            log('else block in promise*** : ');
        }
        
        if(isValidValue(result) && result.STATUS == 'CREATED') {
            refreshApex(this.provisionedItem);
            let queryStr = '[data-id='+result.BANK;
            const investmentListLWC = this.template.querySelector(queryStr);
            investmentListLWC.newRecordCreatedHandler();
        }
    }

    getFieldList() {
        let applicableObj;
        if(this.activeTabName == 'SBI') {
            applicableObj = this.sbiEntries[0];
        }else if(this.activeTabName == 'AXIS') {
            applicableObj = this.axisEntries[0];
        }
        let fieldList = [];
        let field1 = {
            'fieldapiname' : 'Account_Number__c',
            'value' : '',
            'key': 1,
            'disabled': false,
            'required': true
        }
        let field2 = {
            'fieldapiname' : 'Start_Date__c',
            'value': new Date(Date.now()).toISOString(),
            'key': 2,
            'disabled': false,
            'required': true
        }
        let field3 = {
            'fieldapiname': 'Amount__c',
            'value': '',
            'key': 3,
            'disabled': false,
            'required': true
        }
        let field4 = {
            'fieldapiname': 'RecordTypeId',
            'value': applicableObj.RecordTypeId,
            'key': 4,
            'disabled': true,
            'required': true
        }

        let field5 = {
            'fieldapiname': 'Bank__c',
            'value': applicableObj.Bank__c,
            'key': 5,
            'disabled': true,
            'required': true
        }

        let field6 = {
            'fieldapiname': 'Rate__c',
            'value': '',
            'key': 6,
            'disabled': false,
            'required': true
        }

        let field7 = {
            'fieldapiname': 'Year__c',
            'value': '',
            'key': 7,
            'disabled': false,
            'required': true
        }

        let field8 = {
            'fieldapiname': 'Month__c',
            'value': '',
            'key': 8,
            'disabled': false,
            'required': false
        }

        let field9 = {
            'fieldapiname': 'Day__c',
            'value': '',
            'key': 9,
            'disabled': false,
            'required': false
        }

        let field10 = {
            'fieldapiname': 'Tax_saver__c',
            'value': '',
            'key': 10,
            'disabled': false,
            'required': false
        }

        fieldList.push(field1);
        fieldList.push(field2);
        fieldList.push(field3);
        fieldList.push(field4);
        fieldList.push(field5);
        fieldList.push(field6);
        fieldList.push(field7);
        fieldList.push(field8);
        fieldList.push(field9);
        fieldList.push(field10);

        return fieldList;
    }

}