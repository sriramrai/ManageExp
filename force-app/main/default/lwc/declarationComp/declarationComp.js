import { LightningElement, wire, track } from "lwc";
import getFiscalYear from "@salesforce/apex/ExpenseManagerUtil.getIncome";
import { refreshApex } from "@salesforce/apex";
import getTotalInterest from "@salesforce/apex/ExpenseManagerUtil.totalFdInterest";
import getSalaryStructure from "@salesforce/apex/ExpenseManagerUtil.getSalaryStructure";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  log,
  logError,
  getFYForExpManager,
  getMonthOptionForExpManager,
  toString,
  getCurrentFY,
  isValid
} from "c/utilityClass";
import HideLightningHeader from "@salesforce/resourceUrl/NoHeader";
import { loadStyle, loadScript } from "lightning/platformResourceLoader";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import recordSelected from "@salesforce/messageChannel/Record_Selected__c";

export default class DeclarationComp extends LightningElement {
  fyValue = "2025-2026";
  incomeResult;
  data;
  actionLabel = "New";
  recordId;
  @track fieldList = this.buildFields();
  enableCreate = false;
  incomeFromIntrest = 0;
  @wire(MessageContext)
  messageContext;
  @track isValuesVisible = false;
  passwordInput = "";
  isPasswordModalOpen = false;

  get totalIncome() {
    return (
      this.incomeFromIntrest + this.data["Salary__c"] + this.data["Other__c"]
    );
  }

  // Get icon name based on visibility state
  get eyeIconName() {
    return this.isValuesVisible ? "utility:hide" : "utility:preview";
  }

  @wire(getSalaryStructure, { fy: "$fyValue" })
  salaryStructure({ data, error }) {
    if (data) {
      this.ssRecord = data;
    } else if (error) {
      console.log("Error while provisioning salary structure....");
    }
  }

  @wire(getTotalInterest, { fy: "$fyValue" })
  getTotalFDIntrest({ data, error }) {
    if (data) {
      this.incomeFromIntrest = data;
    }
  }

  @wire(getFiscalYear, { fiscalYear: "$fyValue" })
  fetchFY(record) {
    if (record) {
      this.incomeResult = record;
      if (record.data) {
        this.data = record.data;
        this.actionLabel = "Edit";
        this.recordId = this.data.Id;
        this.fieldList = this.buildFields();
      } else if (record.error) {
        console.error("record not found");
      } else {
        this.data = null;
        this.actionLabel = "New";
        this.recordId = null;
      }
    }
  }

  get options() {
    return getFYForExpManager();
  }

  handleToggleVisibility() {
    if (this.isValuesVisible) {
      // If values are visible, hide them
      this.isValuesVisible = false;
    } else {
      // If values are hidden, show password modal
      this.isPasswordModalOpen = true;
    }
  }
  // Handle Enter key press in password input
  handlePasswordKeyUp(event) {
    if (event.keyCode === 13) {
      this.handlePasswordSubmit();
    }
  }

  // Handle password input change
  handlePasswordChange(event) {
    this.passwordInput = event.target.value;
  }

  handlePasswordSubmit() {
    if (this.passwordInput === "100") {
      // Correct password
      this.isValuesVisible = true;
      this.isPasswordModalOpen = false;
      this.passwordInput = "";

      // Show success message
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Success",
          message: "Values are now visible",
          variant: "success"
        })
      );
    } else {
      // Incorrect password
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error",
          message: "Incorrect password. Please try again.",
          variant: "error"
        })
      );
      this.passwordInput = "";
    }
  }

  // Handle password modal close
  handleCloseModal() {
    this.isPasswordModalOpen = false;
    this.passwordInput = "";
  }

  subscription = null;
  subscribeToMessageChannel() {
    if (!this.subscription) {
      this.subscription = subscribe(
        this.messageContext,
        recordSelected,
        (message) => this.handleMessage(message)
      );
    }
  }

  unsubscribeToMessageChannel() {
    unsubscribe(this.subscription);
    this.subscription = null;
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  handleMessage(message) {
    this.fyValue = message.recordId;
  }

  connectedCallback() {
    this.fyValue = getCurrentFY();
    this.subscribeToMessageChannel();
    loadStyle(this, HideLightningHeader);
  }

  buildFields() {
    let startDate, endDate, fiscalYear, salary, other;
    if (this.data) {
      startDate = this.data.Start_Date__c;
      endDate = this.data.End_Date__c;
      fiscalYear = this.data.Fiscal_Year__c;
      salary = this.data.Salary__c;
      other = this.data.Other__c;
    } else {
      fiscalYear = this.fyValue;
      let splittedYear = fiscalYear.split("-");
      startDate = splittedYear[0] + "-" + "04-01";
      endDate = splittedYear[1] + "-" + "03-31";
      salary = isValid(this.ssRecord) ? this.ssRecord.Total_CTC__c : 0;
      other = isValid(this.ssRecord) ? this.ssRecord.Bonus__c : 0;
    }
    return [
      { key: 1, name: "Start_Date__c", disabled: true, value: startDate },
      { key: 2, name: "End_Date__c", disabled: true, value: endDate },
      { key: 3, name: "Fiscal_Year__c", disabled: true, value: fiscalYear },
      { key: 4, name: "Salary__c", disabled: false, value: salary },
      { key: 5, name: "Other__c", disabled: false, value: other }
    ];
  }

  declareIncome(event) {
    this.enableCreate = true;
    this.fieldList = this.buildFields();
    if (this.enableCreate && this.actionLabel === "New") {
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
