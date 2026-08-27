import { LightningElement, api, track, wire } from "lwc";
import { createRecord, deleteRecord } from "lightning/uiRecordApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getIvt from "@salesforce/apex/InvestmentController.getinvestment";
import postIvt from "@salesforce/apex/InvestmentController.postData";
import operatePPF from "./operatePPF.html";
import operateFD from "./operatefds.html";
import { refreshApex } from "@salesforce/apex";
import { isValidValue } from "c/utilityClass";
const RE_INVEST = "Re-Invest";

export default class Operatefds extends LightningElement {
  fdvalue = RE_INVEST;
  @api ivtid;
  isPPF;
  isLoading = true;
  ivtRecord;
  disableSave = false;
  errorMessage = "";
  tdsApplied = false;
  @track dataObj = {};
  expectedMaturity;
  filename;
  uploadeDocumentId;
  contentDocumentId = "069GA000019IABjYAO";
  investmentRecord;

  @wire(getIvt, { recordId: "$ivtid" })
  getRecord(result) {
    this.investmentRecord = result;
    let data = result.data;
    let error = result.error;
    if (data) {
      this.isLoading = false;
      this.ivtRecord = data;
      if (this.ivtRecord.Is_Closed__c) {
        this.errorMessage = "Account is closed...";
        this.isLoading = false;
      } else {
        this.isPPF =
          (this.ivtRecord.Bank__c == "NPS" || this.ivtRecord.Bank__c == "PPF") >
          0
            ? true
            : false;
        this.initializeData();
      }
    } else if (error) {
      console.log("error occured while fetching record...");
      console.error(error);
    }
  }

  connectedCallback() {
    //refreshApex(this.investmentRecord);
  }

  get acceptFormats() {
    return [".pdf", ".png", ".jpg", ".jpeg"];
  }

  initializeData() {
    this.dataObj = {};
    this.dataObj["Type__c"] = this.fdvalue;
    this.dataObj["Date__c"] = this.operationDate();
    this.dataObj["Amount__c"] = null;
    this.dataObj["Rate__c"] = 7;
    if (!this.isPPF) {
      this.dataObj["Rate__c"] = null;
      this.dataObj["IS_TDS__c"] = false;
      this.dataObj["TDS_Deducted__c"] = null;
      this.dataObj["Comment__c"] = "";
      this.dataObj["Tenure_Yr__c"] = this.showTenure
        ? this.ivtRecord["Year__c"]
        : 0;
      this.dataObj["Tenure_Mnt__c"] = this.showTenure
        ? this.ivtRecord["Month__c"]
        : 0;
      this.dataObj["Tenure_Day__c"] = this.showTenure
        ? this.ivtRecord["Day__c"]
        : 0;
    }
    this.expectedMaturity = this.ivtRecord["Maturity_Amount__c"];
  }

  @api get showTenure() {
    let result = this.fdvalue == RE_INVEST ? true : false;
    return result;
  }

  operationDate() {
    let investDate = new Date();
    if (this.fdvalue == RE_INVEST && !this.isPPF) {
      let maturedDate = this.ivtRecord["Maturity_Date__c"];
      investDate = new Date(maturedDate);
      investDate.setDate(investDate.getDate() + 1);
    }

    let mth = investDate.getMonth() + 1;
    let dy = investDate.getDate();
    let yr = investDate.getFullYear();
    return yr + "-" + mth + "-" + dy;
  }

  @api get fdOptions() {
    return [
      { label: "Closed", value: "Closed" },
      { label: "Re Invest", value: RE_INVEST },
      { label: "Contribution", value: "Contribution" }
    ];
  }

  handleChange(event) {
    this.fdvalue = event.target.value;
    this.initializeData();
  }

  handleToggle(event) {
    this.dataObj.IS_TDS__c = event.target.checked;
  }

  /**
   * Applies the OCR-extracted receipt data (from c-ocr-reader) onto
   * the renewal form. Date__c/Tenure_*__c are reactively bound to
   * dataObj, so updating dataObj is enough to refresh those inputs.
   * Amount__c/Rate__c have no value binding (read directly from the
   * DOM at save time), so they're set imperatively on the element.
   */
  handleOcrSubmit(event) {
    const data = event.detail?.data || {};

    if (isValidValue(data.Start_Date__c)) {
      this.dataObj.Date__c = data.Start_Date__c;
    }

    if (isValidValue(data.Year__c)) {
      this.dataObj.Tenure_Yr__c = data.Year__c;
    }

    if (isValidValue(data.Month__c)) {
      this.dataObj.Tenure_Mnt__c = data.Month__c;
    }

    if (isValidValue(data.Day__c)) {
      this.dataObj.Tenure_Day__c = data.Day__c;
    }

    this.setInputValue("Amount__c", data.Amount__c);
    this.setInputValue("Rate__c", data.Rate__c);
  }

  setInputValue(fieldName, value) {
    if (!isValidValue(value)) {
      return;
    }

    const input = this.template.querySelector(
      `lightning-input[name="${fieldName}"]`
    );

    if (input) {
      input.value = value;
    }
  }

  amountChange(event) {
    if (this.fdvalue == "Closed") {
      return;
    }
    let closureAmt = event.target.value;
    let expectedMeturity = this.ivtRecord["Maturity_Amount__c"];
    let difference = expectedMeturity - closureAmt;
    this.selectTDS(difference);
  }

  selectTDS(tds) {
    this.template.querySelectorAll("lightning-input").forEach((elem) => {
      let elementtype = elem.type;
      console.log(elementtype);
      if (elementtype == "toggle") {
        if (tds > 50) {
          elem.checked = true;
          this.dataObj.IS_TDS__c = true;
          this.dataObj.TDS_Deducted__c = tds;
        } else {
          elem.checked = false;
          this.dataObj.IS_TDS__c = true;
          this.dataObj.TDS_Deducted__c = 0;
        }
      }
    });
  }

  handleCancel(event) {
    this.closeQuickAction();
  }

  mandatoryFields = ["Amount__c", "Rate__c", "Date__c"];
  @api handleSave(event) {
    this.disableSave = true;
    this.errorMessage = null;
    let valid = true;
    this.template
      .querySelectorAll(["lightning-input", "lightning-textarea"])
      .forEach((elem) => {
        if (elem.name != "Maturity_Amt") {
          let elementtype = elem.type;
          let elemenntvalue = elem.value;
          if (elementtype == "toggle") {
            elemenntvalue = elem.checked;
          }
          let elementname = elem.name;
          elem.setCustomValidity("");
          elem.reportValidity();
          if (
            this.mandatoryFields.indexOf(elementname) > -1 &&
            !isValidValue(elemenntvalue)
          ) {
            valid = false;
            elem.setCustomValidity("Please fill this mandatory field");
            elem.reportValidity();
            //event.preventDefault();
            // return;
          }
          this.dataObj[elementname] = elemenntvalue;
        }
      });

    if (valid) {
      postIvt({
        data: JSON.stringify(this.dataObj),
        recordId: this.ivtid,
        isPPF: this.isPPF
      })
        .then((result) => {
          console.log("data posted successfully....");
          console.log(result);
          this.closeQuickAction();
        })
        .catch((error) => {
          console.log("Error Occured while posting data...");
          this.errorMessage += JSON.stringify(error);
          this.disableSave = false;
        });
    } else {
      this.errorMessage = "Please Fill Mandatory fields \n" + this.errorMessage;
      this.disableSave = false;
      event.preventDefault();
      return;
    }
  }

  handleUploadFinished(event) {
    let uploadedFileName = event.detail.files[0].name;
    this.filename = uploadedFileName;
    this.uploadeDocumentId = event.detail.files[0].documentId;
    console.log("files**** : " + JSON.stringify(event.detail.files));
  }

  async deleteFile(event) {
    console.log("inside delete file....");
    try {
      await deleteRecord(this.uploadeDocumentId);
      this.uploadeDocumentId = null;
      this.filename = null;
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error deleting record",
          message: JSON.stringify(error),
          variant: "error"
        })
      );
    }
  }

  closeQuickAction() {
    refreshApex(this.investmentRecord);
    const closeAction = new CustomEvent("success");
    this.dispatchEvent(closeAction);
  }

  validityPass() {
    let result = true;
    let objKeys = Object.keys(this.dataObj);
    for (let i = 0; i < objKeys.length; i++) {
      let key = objKeys[i];
      if (
        (key == "Date__c" || key == "Amount__c" || key == "Rate__c") &&
        !this.isValidValue(this.dataObj[key])
      ) {
        if (this.fdvalue == "Closed" && key == "Rate__c") {
          continue;
        }
        result = false;
        this.errorMessage =
          "Validation Failed for " +
          key +
          " Having value : " +
          this.dataObj[key];
        break;
      }
      if (
        key == "IS_TDS__c" &&
        this.dataObj[key] &&
        !this.isValidValue(this.dataObj["TDS_Deducted__c"])
      ) {
        result = false;
        this.errorMessage =
          "Validation Failed for " +
          key +
          " Having value : " +
          this.dataObj["TDS_Deducted__c"];
        break;
      }
    }

    return result;
  }

  isValidValue(val) {
    if (val == "" || val == null || typeof val == "undefined") {
      return false;
    }

    return true;
  }

  render() {
    return this.isPPF ? operatePPF : operateFD;
  }
}
