import { api, wire, track } from "lwc";
import LightningModal from "lightning/modal";
import getSalaryStructure from "@salesforce/apex/ExpenseManagerUtil.getSalaryStructure";
import getEarning from "@salesforce/apex/ExpenseManagerUtil.getEarning";
import {
  log,
  logError,
  getFYForExpManager,
  getMonthOptionForExpManager,
  getSalaryAmountFields
} from "c/utilityClass";
import {
  subscribe,
  unsubscribe,
  APPLICATION_SCOPE,
  MessageContext
} from "lightning/messageService";
import recordSelected from "@salesforce/messageChannel/Record_Selected__c";

export default class ManageEarning extends LightningModal {
  @api fyValue = "2025-2026";
  @api modalData;
  //fyValue = "2026-2027";
  disableSave = false;
  selectedMonth = "04";
  @track data = {};
  salaryStructure;
  earning;
  @track diffData = {};

  connectedCallback() {
    this.fyValue = this.modalData;
    this.subscribeToMessageChannel();
  }

  disconnectedCallback() {
    this.unsubscribeToMessageChannel();
  }

  @wire(MessageContext)
  messageContext;

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

  handleMessage(message) {
    this.fyValue = message.recordId;
  }

  @wire(getSalaryStructure, { fy: "$fyValue" })
  fetchSalaryStructure({ data, error }) {
    if (data) {
      this.salaryStructure = JSON.parse(JSON.stringify(data));
      this.salaryStructure.Id = "";
    } else if (error) {
      logError("Error Occurred while fetching Salary Structure....");
    }
  }

  @wire(getEarning, {
    fy: "$salaryStructure.Fiscal_Year__c",
    month: "$selectedMonth"
  })
  fetchEarning(eanrningObj) {
    this.data = null;
    this.earning = null;
    this.earning = eanrningObj;
    if (eanrningObj) {
      if (this.earning.data) {
        if (this.salaryStructure) {
          this.initData();
        }
      } else if (this.earning.error) {
        logError("error occured while provisioning earning object...");
      } else {
        if (this.salaryStructure) {
          this.initData();
        }
      }
    }
  }

  initData() {
    this.data = this.salaryStructure;
  }

  diffValue(field, sourceValue) {
    let diff =
      sourceValue <= this.salaryStructure[field]
        ? this.salaryStructure[field] - sourceValue
        : sourceValue - this.salaryStructure[field];
    diff = sourceValue >= this.salaryStructure[field] ? diff * 1 : diff * -1;
    return diff.toString();
  }

  constructDiffData() {
    this.diffData = {};
    let amountFields = getSalaryAmountFields();
    for (const field in this.data) {
      if (amountFields.indexOf(field) > -1) {
        this.diffData[field] = this.diffValue(field, this.data[field]);
      }
    }
  }

  handleSubmit(event) {
    this.disableSave = true;
  }

  handleCancel(event) {
    this.close(false);
  }

  handleSuccess(event) {
    this.close(true);
  }

  handleError(event) {
    log("Error while saving earning record... : " + event.detail.detail);
  }

  inputChangeHandler(event) {
    log("inpur change handler called..." + event.target.value);
    let field = event.target.fieldName;
    let changedValue = event.target.value;
    this.diffData[field] = this.diffValue(field, changedValue);
  }
}
