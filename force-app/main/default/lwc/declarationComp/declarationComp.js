import { LightningElement, wire, track } from 'lwc';
import getFiscalYear from '@salesforce/apex/ExpenseManagerUtil.getIncome';
import { refreshApex } from "@salesforce/apex";
import getFDIncomes from '@salesforce/apex/InvestmentController.getFYIntrest';
import { log, logError, getFYForExpManager, getMonthOptionForExpManager } from 'c/utilityClass';

export default class DeclarationComp extends LightningElement {
  fyValue = '2025-2026';
  incomeResult;
  data;
  actionLabel = 'New';
  recordId;
  @track fieldList = this.buildFields();
  enableCreate = false;
  incomeFromIntrest = 0;

  get totalIncome() {
    return this.incomeFromIntrest+this.data['Salary__c']+this.data['Other__c'];
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

  @wire (getFiscalYear, {'fiscalYear': '$fyValue'})
  fetchFY(record) {
    if(record) {
      this.incomeResult = record;
      if(record.data) {
        this.data = record.data;
        this.actionLabel = 'Edit';
        this.recordId = this.data.Id;
        this.fieldList = this.buildFields();
      }else if(record.error) {
        console.error('record not found');
      }else {
        this.data = null;
        this.actionLabel = 'New';
        this.recordId=null;
      }
    }
  }

  get options() {
    return getFYForExpManager();
  }

  buildFields() {
    let startDate, endDate, fiscalYear, salary, other;
    if(this.data) {
      startDate = this.data.Start_Date__c;
      endDate = this.data.End_Date__c;
      fiscalYear = this.data.Fiscal_Year__c;
      salary = this.data.Salary__c;
      other = this.data.Other__c
    }else {
      fiscalYear = this.fyValue;
      let splittedYear = fiscalYear.split('-');
      startDate = "20"+splittedYear[0]+"-"+"04-01";
      endDate = "20"+splittedYear[1]+"-"+"03-31";
    }
    return [
        { key : 1, name : 'Start_Date__c', disabled: true, value: startDate},
        { key : 2, name : 'End_Date__c', disabled: true, value: endDate},
        { key : 3, name : 'Fiscal_Year__c', disabled: true, value: fiscalYear},
        { key : 4, name : 'Salary__c', disabled: false, value: salary},
        { key : 5, name : 'Other__c', disabled: false, value: other},
    ];
  }

  declareIncome(event) {
    this.enableCreate = true;
    this.fieldList = this.buildFields();
    if(this.enableCreate && this.actionLabel === 'New') {
      
    }
  }

  handleCancel(event) {
    this.enableCreate = false;
  }

  saveSucceeded() {
    this.enableCreate = false;
    refreshApex(this.incomeResult);
  }

  handleChange(event) {
    this.fyValue = event.target.value;
    this.data = null;
    this.enableCreate = false;
  }
}