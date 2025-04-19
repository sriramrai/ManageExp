import { LightningElement, api, wire } from 'lwc';
import allReinvestedAccounts from '@salesforce/apex/InvestmentController.allReinvestedAccounts';
import investmentWithLines from '@salesforce/apex/InvestmentController.getInvestmentWithLines';

export default class InvestmentHistory extends LightningElement {
    selectedFd;
    @api recordId;
    allFds;
    fetchedResponse;
    dataList;
    
    @wire (allReinvestedAccounts, {'recordId': '$recordId'})
    allInvestment({error, data}) {
        if(data) {
            let objectKeys = Object.keys(data);
            this.selectedFd = this.recordId;
            this.allFds = [];
            for(let i=0; i<objectKeys.length; i++) {
                let acnumber = objectKeys[i];
                let recId = data[acnumber];
                this.allFds.push({'label': acnumber, 'value': recId});
            }
        }else if(error) {
            console.error('Error while retrieving record... : '+error);
        }
    }

    @wire(investmentWithLines, {'investmentId': '$selectedFd'})
    investmentAndLines({error, data}) {
        if(data) {
            this.fetchedResponse = JSON.stringify(data);
            this.formateData(data);
        }else if(error){
            console.error('Error occured while fetching invetment with line items...: '+error);
        }
    }

    formateDateIST(dateValue) {
        return new Date(dateValue).toLocaleDateString("hi-IN");
    }

    initLines(records) {
        if(records != '' && records != null && typeof records != 'undefined') {
            records.forEach(record => {
                let dataObj = {};
                dataObj.Id = record.Id;
                dataObj.startDate = this.formateDateIST(record.Investment_Date__c);
                dataObj.maturityDate = this.formateDateIST(record.Maturity_Date__c);
                dataObj.principle = record.Principle__c;
                dataObj.maturedAmount = record.Amount__c;
                dataObj.rate = record.Rate__c;
                dataObj.tds = Math.round(record.TDS_Deducted__c * 100) / 100;
                this.dataList.push(dataObj);
            });   
        }
    }

    initFromInvestment(record) {
        if(record != '' && record != null && typeof record != 'undefined') {
            this.initLines(record.Investment_Line_Items__r)
            let dataObj = {};
            dataObj.Id = record.Id;
            dataObj.startDate = this.formateDateIST(record.Start_Date__c);
            dataObj.maturityDate = this.formateDateIST(record.Maturity_Date__c);
            dataObj.principle = record.Amount__c;
            dataObj.maturedAmount = record.Maturity_Amount__c;
            dataObj.rate = record.Rate__c;
            this.dataList.push(dataObj);
        }
    }

    formateData(investment) {
        this.dataList=[];
        this.initFromInvestment(investment);
    }

    handleChange(event) {
        this.selectedFd = event.detail.value;
        console.log(this.selectedFd);
    }

    connectedCallback() {
        console.log('inside connected callback.... : '+this.recordId);
    }
}