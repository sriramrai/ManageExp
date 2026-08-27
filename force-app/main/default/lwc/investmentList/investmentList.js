import { LightningElement, api, track, wire } from "lwc";
import { log, deepClone } from "c/utilityClass";
import renewalModal from "c/renewalModal";
import getAllInvestmentByBank from "@salesforce/apex/ExpenseManagerUtil.getAllInvestmentByBank";
import { refreshApex } from "@salesforce/apex";
import templateMobile from "./investmentList.html";
import templateLarge from "./investmentList_Large.html";
import FORM_FACTOR from "@salesforce/client/formFactor";

export default class InvestmentList extends LightningElement {
  _ivts = [];
  @api bankName;
  @track totalInvested = 0;
  @track totalMaturity = 0;
  //@track investments = [];
  provisionedItem;
  isMobile = FORM_FACTOR === "Small" ? true : false;

  /** Same shadow root and investmentList.css for both; only the template changes. */
  render() {
    return this.isMobile ? templateMobile : templateLarge;
  }

  @api
  set ivts(value) {
    this.totalInvested = 0;
    this.totalMaturity = 0;
    console.log("Bank:", this.bankName, "Received:", value?.length);

    this._ivts = (value || []).map((element) => {
      this.totalInvested += element.Amount__c || 0;
      this.totalMaturity += element.Maturity_Amount__c || 0;

      const today = new Date();
      const maturityDate = new Date(element.Maturity_Date__c);
      const differenceDays = Math.round(
        Math.abs(maturityDate - today) / (24 * 60 * 60 * 1000)
      );

      return {
        ...element,
        badgeStyle: maturityDate <= today ? "badge-red" : "badge-green",
        daysLeft: this.convertIntoMonth(differenceDays)
      };
    });

    this.totalInvested = Math.trunc(this.totalInvested);
    this.totalMaturity = Math.trunc(this.totalMaturity);
  }

  get ivts() {
    return this._ivts;
  }

  get investments() {
    return this.sortArray([...this._ivts]);
  }

  connectedCallback() {
    console.log("ivts:", JSON.stringify(this.ivts));
  }

  sortArray(arr) {
    arr.sort(function (a, b) {
      let d1 = a.Maturity_Date__c;
      let d2 = b.Maturity_Date__c;
      if (d1 < d2) {
        return -1;
      }
      if (d2 > d1) {
        return 1;
      }
    });
    return arr;
  }

  badgeClickHandler(event) {
    let selectedRecord = event.target.dataset.id;
    let url = "/" + selectedRecord;
    window.open(url, "_blank");
  }

  async renewCloseHandler(event) {
    let selectedRecord = event.target.dataset.id;
    let selectedAccountNumber = event.target.dataset.acc;
    selectedRecord = selectedRecord + "#" + selectedAccountNumber;
    const result = await renewalModal.open({
      size: "small",
      description: "Renewal/Close",
      content: selectedRecord
    });
    if (result == "refresh") {
      const refreshdata = new CustomEvent("refreshdata");
      this.dispatchEvent(refreshdata);
    }
  }

  convertIntoMonth(days) {
    let result = "";
    if (days >= 365) {
      let yr = Math.floor(days / 365);
      result += yr + "Y ";
      days = days % 365;
    }
    if (days >= 30) {
      let month = Math.floor(days / 30);
      result += month + "M ";
      days = days % 30;
    }
    if (days > 0) {
      result += days + "D ";
    }

    return result;
  }

  get title() {
    return "Total " + this.total;
  }

  @api newRecordCreatedHandler() {
    log("inside new record created handler**** : " + this.bankName);
    refreshApex(this.provisionedItem);
  }
}
