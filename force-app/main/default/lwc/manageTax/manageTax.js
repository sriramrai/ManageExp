import { LightningElement, api, wire } from 'lwc';
import getFiscalYear from '@salesforce/apex/ExpenseManagerUtil.getIncome';
import { log, logError, getFYForExpManager, getMonthOptionForExpManager } from 'c/utilityClass';
import { refreshApex } from "@salesforce/apex";
import getFDIncomes from '@salesforce/apex/InvestmentController.getFYIntrest';
import interestWrapper from '@salesforce/apex/ExpenseManagerUtil.getInterestWrapper';

export default class ManageTax extends LightningElement {
    fyValue = '2025-2026';
    interestList = [];
    totalAccumulated = 0;
    totalPaid = 0;
    totalTds = 0;
    get options() {
        return getFYForExpManager();
    }

    @wire (interestWrapper, {'fy' : 'test'})
    interestWrapperList({data, error}) {
        if(data) {
            this.interestList = data;
            this.calculateTotals();
            console.log('data**** : '+JSON.stringify(this.interestList));
        }else if(error) {
            console.log('Error occured.....'+JSON.stringify(error));
        }
    }

    @wire (getFDIncomes, {'fy' : '$fyValue'})
    fetchAllFdInterest( { data, error } ) {
        if(data) {
        this.incomeFromIntrest = data['Total'];
        console.log('income from interest*** : '+this.incomeFromIntrest);
        }else if(error){
        console.log('Error while provisioning FD Interests....');
        }
    }

    calculateTotals() {
        this.interestList.forEach(item => {
            if(item.accumulatedInteres != null) {
                this.totalAccumulated += item.accumulatedInteres;
            }
            if(item.interestPaid != null) {
                this.totalPaid += item.interestPaid;
            }
            if(item.tds != null) {
                this.totalTds += item.tds;
            }
        })

        this.totalAccumulated = this.totalAccumulated.toFixed(2);
        this.totalPaid = this.totalPaid.toFixed(2);
        this.totalTds = this.totalTds.toFixed(2);
    }

    handleChange(event) {
        this.fyValue = event.target.value;
        this.data = null;
        this.enableCreate = false;
    }
}