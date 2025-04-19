import { LightningElement, api, track, wire} from 'lwc';
import { createRecord, deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getIvt from '@salesforce/apex/InvestmentController.getinvestment';
import postIvt from '@salesforce/apex/InvestmentController.postData';
import operatePPF from './operatePPF.html';
import operateFD from './operatefds.html';
const RE_INVEST = 'Re-Invest';

export default class Operatefds extends LightningElement {
    fdvalue = RE_INVEST;
    @api ivtid;
    isPPF;
    isLoading = true;
    ivtRecord;
    disableSave = false;
    errorMessage='';
    tdsApplied = false;
    @track dataObj = {};
    expectedMaturity;
    filename;
    uploadeDocumentId;
    contentDocumentId = "069GA000019IABjYAO";
    
    @wire(getIvt, {'recordId' : '$ivtid'})
    getRecord({error, data}) {
        if(data) {
            this.isLoading = false;
            this.ivtRecord = data;
            if(this.ivtRecord.Is_Closed__c) {
                this.errorMessage = 'Account is closed...';
                this.isLoading = false;
            }else {
                this.isPPF = (this.ivtRecord.Bank__c == 'NPS' || this.ivtRecord.Bank__c == 'PPF') > 0 ? true : false;
                this.initializeData();
            }
            
        }else if(error){
            console.log('error occured while fetching record...');
            console.error(error);
        }
    };

    get acceptFormats() {
        return [".pdf", ".png", ".jpg", ".jpeg"]
    }

    initializeData() {
        this.dataObj = {};
        this.dataObj['Type__c'] = this.fdvalue;
        this.dataObj['Date__c'] = this.operationDate();
        this.dataObj['Amount__c'] = null;
        this.dataObj['Rate__c'] = 7;
        if(!this.isPPF) {
            this.dataObj['Rate__c'] = null;
            this.dataObj['IS_TDS__c'] = false;
            this.dataObj['TDS_Deducted__c'] = null;
            this.dataObj['Comment__c'] = '';
            this.dataObj['Tenure_Yr__c'] = this.showTenure ? this.ivtRecord['Year__c'] : 0;
            this.dataObj['Tenure_Mnt__c'] = this.showTenure ? this.ivtRecord['Month__c'] : 0;
            this.dataObj['Tenure_Day__c'] = this.showTenure ? this.ivtRecord['Day__c'] : 0;
        }
        this.expectedMaturity = this.ivtRecord['Maturity_Amount__c'];
    }
    
    @api get showTenure() {
        let result = this.fdvalue == RE_INVEST ?  true : false;
        return result;
    }

    operationDate() {
        let investDate = new Date();
        if(this.fdvalue == RE_INVEST && !this.isPPF) {
            let maturedDate = this.ivtRecord['Maturity_Date__c'];
            investDate = new Date(maturedDate);
            investDate.setDate(investDate.getDate()+1);
        }

        let mth = investDate.getMonth()+1;
        let dy = investDate.getDate();
        let yr = investDate.getFullYear()
        return yr+'-'+mth+'-'+dy;
    }

    @api get fdOptions(){
        return [
            { label :'Closed', value :'Closed'},
            { label :'Re Invest', value :RE_INVEST},
            { label :'Contribution', value :'Contribution'}
        ];
    }

    handleChange(event) {
        this.fdvalue = event.target.value;
        this.initializeData();
    }

    handleToggle(event) {
        this.dataObj.IS_TDS__c = event.target.checked;
    }

    amountChange(event) {
        let closureAmt = event.target.value;
        let expectedMeturity = this.ivtRecord['Maturity_Amount__c'];
        let difference = expectedMeturity-closureAmt;
        this.selectTDS(difference);
    }

    selectTDS(tds) {
        this.template.querySelectorAll("lightning-input").forEach(elem => {
           let elementtype = elem.type;
           console.log(elementtype);
           if(elementtype == 'toggle') {
                if(tds > 50) {
                    elem.checked = true;
                    this.dataObj.IS_TDS__c = true;
                    this.dataObj.TDS_Deducted__c = tds;
                }
           } 
        });
    }

    handleCancel(event) {
        this.closeQuickAction();
    }

    handleSave(event) {
        this.disableSave = true;
        this.errorMessage = null;
        this.template.querySelectorAll(["lightning-input", "lightning-textarea"]).forEach(elem => {
            if(elem.name != 'Maturity_Amt') {
                let elementtype = elem.type;
                let elemenntvalue = elem.value;
                if(elementtype == 'toggle') {
                    elemenntvalue = elem.checked;
                }
                let elementname = elem.name;
                this.dataObj[elementname] = elemenntvalue;
            }

        });

        if(this.validityPass()) {
            console.log('Validity is passed...');
            console.log(JSON.stringify(this.dataObj));
            postIvt({'data' : JSON.stringify(this.dataObj), 'recordId' : this.ivtid, 'isPPF' : this.isPPF})
            .then((result) => {
                console.log('data posted successfully....');
                console.log(result);
                this.closeQuickAction();
            })
            .catch((error) => {
                console.log('Error Occured while posting data...');
                this.errorMessage += JSON.stringify(error);
                this.disableSave = false;
            })
        }else {
            this.errorMessage = 'Please Fill Mandatory fields ' + this.errorMessage;
            this.disableSave = false;
        }
    }

    handleUploadFinished(event) {
        let uploadedFileName = event.detail.files[0].name;
        this.filename = uploadedFileName;
        this.uploadeDocumentId = event.detail.files[0].documentId;
        console.log('files**** : '+JSON.stringify(event.detail.files));
    }
    
    async deleteFile(event) {
        console.log('inside delete file....');
        try {
            await deleteRecord(this.uploadeDocumentId);
            this.uploadeDocumentId = null;
            this.filename = null;
        }catch(error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error deleting record',
                    message: JSON.stringify(error),
                    variant: 'error'
                })
            );
        }
    }

    closeQuickAction() {
        const closeAction = new CustomEvent('success');
        this.dispatchEvent(closeAction);
    }

    validityPass() {
        let result = true;
        let objKeys = Object.keys(this.dataObj);
        for(let i=0; i<objKeys.length; i++) {
            let key = objKeys[i];
            if((key == 'Date__c' || key == 'Amount__c' || key == 'Rate__c') && !this.isValidValue(this.dataObj[key])) {
                if(this.fdvalue == 'Closed' && key == 'Rate__c') {
                    continue;
                }
                result = false;
                this.errorMessage = 'Validation Failed for '+key+' Having value : '+this.dataObj[key];
                break;
            }
            if(key == 'IS_TDS__c' && this.dataObj[key] && !this.isValidValue(this.dataObj['TDS_Deducted__c'])) {
                result = false;
                this.errorMessage = 'Validation Failed for '+key+' Having value : '+this.dataObj['TDS_Deducted__c'];
                break;
            }
        }

        return result;
    }

    isValidValue(val) {
        if(val == '' || val == null || typeof val == 'undefined') {
            return false;
        }

        return true;
    }

    render() {
        return this.isPPF ? operatePPF : operateFD;
    }

}