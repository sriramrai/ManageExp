import { LightningElement, wire, track} from 'lwc';
import maturityThisMonth from '@salesforce/apex/DataProvider.maturityThisMonth'
export default class MaturitySoon extends LightningElement {
    @track recent = [];
    norecord = false;
    @wire (maturityThisMonth)
    getRecentRecord({data, error}) {
        if(data) {
            data.forEach(element => {
                let arrayObj = {};
                arrayObj.Account_Number__c = element.Account_Number__c;
                arrayObj.Bank__c = element.Bank__c;
                arrayObj.Id = element.Id;
                arrayObj.recordURL = '/'+element.Id;
                arrayObj.Maturity_Date__c = element.Maturity_Date__c;
                let today = new Date();
                arrayObj.class = today >= this.toDate(element.Maturity_Date__c) ? 'slds-hint-parent matured' : 'slds-hint-parent not_matured';
                this.recent.push(arrayObj);
            });
            console.log('Maturity Soon Data **** : '+JSON.stringify(this.recent));
            this.norecord = this.recent.length == 0 ? true : false;
        }else {
            console.log('error occured*** : '+error);
        }
    }

    toDate(dateStr) {
        let result = new Date(dateStr);
        return result;
    }
}