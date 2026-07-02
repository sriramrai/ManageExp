import { LightningElement, wire, api, track } from "lwc";
import {
  log,
  logError,
  toString,
  getFYForExpManager,
  getCurrentFY
} from "c/utilityClass";
import getEarnings from "@salesforce/apex/ExpenseManagerUtil.getEarnings";
import manageEarningModal from "c/manageEarning";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import {
  subscribe,
  unsubscribe,
  MessageContext
} from "lightning/messageService";
import recordSelected from "@salesforce/messageChannel/Record_Selected__c";

export default class EarningList extends LightningElement {
  fyValue = "2025-2026";
  @track earningList = [];
  earningDataObj;
  @track isValuesVisible = false;
  passwordInput = "";
  isPasswordModalOpen = false;

  @wire(getEarnings, { fiscalYear: "$fyValue" })
  earnings(earningObj) {
    this.earningDataObj = earningObj;
    this.earningList = [];
    if (earningObj.data) {
      let dataObj = JSON.parse(JSON.stringify(earningObj.data));
      dataObj.forEach((item) => {
        let obj = {};
        for (let key in item) {
          if (key == "Id") {
            obj["recordURL"] = "/" + item.Id;
          }
          obj[key] = item[key];
        }
        this.earningList.push(obj);
      });
    } else if (earningObj.error) {
      logError(
        "Error while fetching earning... : " + toString(earningObj.error)
      );
    }
  }

  get options() {
    return getFYForExpManager();
  }

  @wire(MessageContext)
  messageContext;
  connectedCallback() {
    this.fyValue = getCurrentFY();
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  subscribeToMessageChannel() {
    this.subscription = subscribe(
      this.messageContext,
      recordSelected,
      (message) => {
        console.log(
          "inside subscribeToMessageChannel earningList**** : " + message
        );
        this.handleMessage(message);
      }
    );
  }

  unsubscribeToMessageChannel() {
    unsubscribe(this.subscription);
  }

  handleMessage(message) {
    this.fyValue = message.recordId;
    console.log("inside handle message earningList**** : " + this.fyValue);
    refreshApex(this.earningDataObj);
  }

  handleChange(event) {
    this.fyValue = event.target.value;
    this.earningList = null;
    this.enableCreate = false;
  }

  async createNew(event) {
    let result = await manageEarningModal.open({
      size: "small",
      description: "Accessible description of modal's purpose",
      content: this.fyValue,
      headerText: "Set the filter",
      modalData: this.fyValue
    });

    if (true) {
      refreshApex(this.earningDataObj);
    }
  }

  navigateToPage(event) {
    let password = prompt("Enter Password");
    if (password != "100") {
      event.preventDefault();
    }
  }

  // Get icon name based on visibility state
  get eyeIconName() {
    return this.isValuesVisible ? "utility:hide" : "utility:preview";
  }

  // Format earning data with masked/visible values
  get formattedEarningList() {
    if (!this.earningList) return [];
    return this.earningList.map((item) => ({
      ...item,
      displayNetInHand: this.isValuesVisible ? item.Net_In_Hand__c : "****"
    }));
  }

  // Handle eye icon click
  handleToggleVisibility() {
    if (this.isValuesVisible) {
      // If values are visible, hide them
      this.isValuesVisible = false;
    } else {
      // If values are hidden, show password modal
      this.isPasswordModalOpen = true;
    }
  }

  // Handle password input change
  handlePasswordChange(event) {
    this.passwordInput = event.target.value;
  }

  // Handle password modal close
  handleCloseModal() {
    this.isPasswordModalOpen = false;
    this.passwordInput = "";
  }

  // Handle password submission
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

  // Handle Enter key press in password input
  handlePasswordKeyUp(event) {
    if (event.keyCode === 13) {
      this.handlePasswordSubmit();
    }
  }
}
