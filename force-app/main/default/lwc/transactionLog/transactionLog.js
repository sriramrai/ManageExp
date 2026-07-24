import { LightningElement, wire, track, api } from "lwc";
import getTransactions from "@salesforce/apex/ExpenseManagerUtil.getAllTransactions";
import getBanks from "@salesforce/apex/ExpenseManagerUtil.getBanks";
import { toString, log, formatDate } from "c/utilityClass";
import { refreshApex } from "@salesforce/apex";
import { subscribe, unsubscribe, onError } from "lightning/empApi";

export default class TransactionLog extends LightningElement {
  channelName = "/event/Transaction_Updator__e";
  subscription = null;
  errorMessage = "";
  @track selectedId;
  @track transactionList = [];
  @track bankList = [];
  @track showBankField = false;
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
          date: formatDate(transaction.Date__c),
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

  connectedCallback() {
    this.registerErrorListener();
    this.handleSubscribe();
  }

  disconnectedCallback() {
    this.handleUnsubscribe();
  }

  handleSubscribe() {
    const messageCallback = (response) => {
      console.log("Platform Event Received");
      console.log(JSON.stringify(response));

      // Access your event fields
      const payload = response.data.payload;

      console.log("Updated:", payload.Updated__c);
      if (payload.Updated__c) {
        refreshApex(this.transactionProvisionedData);
        refreshApex(this.bankProvisionedData);
      }
      // Refresh your component here
      // refreshApex(...)
      // or call an Apex method
    };

    subscribe(this.channelName, -1, messageCallback).then((response) => {
      this.subscription = response;
      console.log("Subscribed to:", response.channel);
    });
  }

  handleUnsubscribe() {
    if (this.subscription) {
      unsubscribe(this.subscription, () => {
        console.log("Unsubscribed");
      });
    }
  }
  handleTypeChange(event) {
    this.selectedId = event.target.value;
    this.showBankField = this.selectedId === "A/C Transfer" ? true : false;
  }

  registerErrorListener() {
    onError((error) => {
      console.error("EMP API Error", JSON.stringify(error));
    });
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
