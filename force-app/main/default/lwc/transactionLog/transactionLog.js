import { LightningElement, wire, track, api } from "lwc";
import getTransactions from "@salesforce/apex/ExpenseManagerUtil.getAllTransactions";
import getBanks from "@salesforce/apex/ExpenseManagerUtil.getBanks";
import { toString, log } from "c/utilityClass";
import { refreshApex } from "@salesforce/apex";

export default class TransactionLog extends LightningElement {
  errorMessage = "";
  @track selectedId;
  @track transactionList = [];
  @track bankList = [];
  @track showAddSection = false;
  iconName = "utility:add";
  transactionProvisionedData;
  bankProvisionedData;

  @wire(getTransactions, { transactionId: "$selectedId" })
  allTransactions(transactionRecord) {
    this.transactionProvisionedData = transactionRecord;
    if (!transactionRecord) {
      return;
    }
    let data = transactionRecord.data;
    let error = transactionRecord.error;
    if (data) {
      this.transactionList = [];
      data.forEach((transaction) => {
        this.transactionList.push({
          id: transaction.Id,
          date: transaction.Date__c,
          description: transaction.Description__c,
          amount: transaction.Amount__c,
          recordURL: "/" + transaction.Id,
          sign: transaction.Type__c === "Debit" ? "-" : "+",
          typeClass: transaction.Type__c === "Debit" ? "debit" : "credit"
        });
      });
    } else if (error) {
      this.errorMessage = toString(transactionData.data);
    }
  }

  @wire(getBanks, {})
  allBanks(bankRecord) {
    this.bankProvisionedData = bankRecord;
    if (!bankRecord) {
      return;
    }
    let data = bankRecord.data;
    let error = bankRecord.error;
    if (data) {
      this.bankList = [];
      data.forEach((bank, index) => {
        this.bankList.push({
          id: bank.Id,
          name: bank.Name,
          balance: bank.Balance__c,
          className: index === 0 ? "bank-card active" : "bank-card"
        });
        this.selectedId = index === 0 ? bank.Id : this.selectedId;
      });
    } else if (error) {
      this.errorMessage = toString(error);
    }
  }

  handleBankClick(event) {
    let dataId = event.currentTarget.dataset.id;
    log("clicked bank id*** : " + dataId);
    this.bankList.forEach((bank) => {
      if (bank.id == dataId) {
        bank.className += " active";
      } else if (bank.className.indexOf("active") > 0) {
        bank.className = "bank-card";
      }
    });
    this.selectedId = dataId;
  }

  handleAdd(event) {
    this.showAddSection = !this.showAddSection;
    this.iconName = this.showAddSection ? "utility:close" : "utility:add";
  }

  handleSuccess(event) {
    this.showAddSection = false;
    this.iconName = "utility:add";
    refreshApex(this.transactionProvisionedData);
    refreshApex(this.bankProvisionedData);
  }
}
