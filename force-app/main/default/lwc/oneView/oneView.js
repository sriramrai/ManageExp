import { LightningElement, api, wire, track } from 'lwc';
import {log, logError, toString} from 'c/utilityClass';
import getOneViewWrapper from '@salesforce/apex/ExpenseManagerUtil.getOneViewWrapper';

export default class OneView extends LightningElement {
    @track earningList = [];
    @track investmentList = [];
    @track expenseList = [];

    @api get totalEarning() {
        let totalEarning = 0;
        this.earningList.forEach(item => {
            totalEarning += item.amount;
        });
        return totalEarning;
    }

    @api get totalInvestment() {
        let totalInvestment = 0;
        this.investmentList.forEach(item => {
            totalInvestment += item.amount;
        });
        return totalInvestment;
    }

    @api get totalExpense() {
        let totalExpense = 0;
        this.expenseList.forEach(item => {
            totalExpense += item.amount;
        });
        return totalExpense;
    }

    @api get totalDifference() {
        return this.totalEarning - (this.totalInvestment + this.totalExpense);
    }

    @wire(getOneViewWrapper, {'fiscalYear' : '2024-2025'})
    oneViewWrapper({data, error}) {
        if(data) {
            log('Data Retrieved successfully...'+toString(data));
            Object.entries(data).map(([key, value]) => {
                log('key*** : '+key);
                log('value*** : '+value);
                if(key == 'Earning') {
                    this.earningList.push(...value);
                }else if(key == 'Investment') {
                    this.investmentList.push(...value);
                }else if(key == 'Expense') {
                    this.expenseList.push(...value);
                }
            });
            log('earninglist*** : '+this.earningList);
            log('investmentList*** : '+this.investmentList);
        }else if(error) {
            logError('Error Occurred while retriving one-view... : '+toString(error));
        }
    }
}