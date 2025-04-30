import { api, LightningElement, wire } from 'lwc';
import getFdReport from '@salesforce/apex/InvestmentController.getFdReport';
import laptopTemplate from './fyIntrestDetails.html';
import mobileTemplate from './fyIntrestDetailsMob.html';

export default class FyIntrestDetails extends LightningElement {
    @api fiscalYear;
    @api bank;
    @api selectedData;
    dataList=[];
    allrecords = [];

    render() {
        console.log('window.screen.width*** : '+window.screen.width);
        return window.screen.width < 768 ? mobileTemplate : laptopTemplate;
    }

    @wire(getFdReport, {'fy': '$selectedData.fy', 'bank': '$selectedData.bank'})
    fdReport({error, data}){
        if(data) {
            console.log('Data retrieved successfully in modal...');
            console.log(data);
            this.allrecords = data;
            this.calculateTDS();
        }else if(error) {
            console.error(this.selectedData);
            console.error('BankName****' + this.selectedData.bank);
            console.error('Something unexpected occured..'+error);
        }
    }

    calculateTDS() {
        let totalIntr = 0;
        let totalTds = 0;
        this.allrecords.forEach(element => {
            totalIntr += element.fyIntrest;
            totalTds += element.tds;
        });
        let obj = {
            'fyintr': totalIntr.toFixed(2),
            'fytds': totalTds.toFixed(2)
        };
        const notifyEvent = new CustomEvent(
            "valuechange", {detail: obj}
        );

        this.dispatchEvent(notifyEvent);
    }

    updaterecords(event) {
        this.dataList = [...event.detail.records];
        //let updatedRecords = [...event.detail.records];
        this.dataList = this.formatRecord(this.dataList);
    }

    formatRecord(records) {
        console.log('inside format records...');
        console.log(records);
        let results = [];
        records.forEach((rec) => {
            console.log('rec** :'+rec);
            //console.log(rec);
            let myObj = {
                'startDate' : this.formatDate(rec.startDate),
                'endDate' : this.formatDate(rec.endDate),
                'acno' : rec.acno,
                'fyIntrest' : rec.fyIntrest
            }
            results.push(myObj);
        });
        
        console.log('record list updated...');
        console.log(results);
        return results;
    }   

    formatDate(dateVal) {
        console.log('informat date....');
        console.log(dateVal);
        let dateArr = dateVal.split('-');
        return dateArr[1]+'-'+dateArr[0].substr(2,4);
    } 
}