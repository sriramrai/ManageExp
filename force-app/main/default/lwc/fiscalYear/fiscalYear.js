import { LightningElement, wire } from "lwc";
import { log, logError, toString, isValid } from "c/utilityClass";
import { publish, MessageContext } from "lightning/messageService";
import recordSelected from "@salesforce/messageChannel/Record_Selected__c";

export default class FiscalYear extends LightningElement {
  fyvalue;

  @wire(MessageContext)
  messageContext;

  get fyOptions() {
    return [
      { label: "FY 21-22", value: "2021-2022" },
      { label: "FY 22-23", value: "2022-2023" },
      { label: "FY 23-24", value: "2023-2024" },
      { label: "FY 24-25", value: "2024-2025" },
      { label: "FY 25-26", value: "2025-2026" },
      { label: "FY 26-27", value: "2026-2027" },
      { label: "FY 27-28", value: "2027-2028" },
      { label: "FY 28-29", value: "2028-2029" },
      { label: "FY 29-30", value: "2029-2030" }
    ];
  }

  connectedCallback() {
    this.initData();
  }

  renderedCallback() {
    if (this.initialized) {
      return;
    }
    this.initialized = true;
    this.publishLMS();
  }

  initData() {
    let today = new Date();
    let currentMonth = today.getMonth() + 1;
    let currentYear = today.getFullYear();
    let fyStart, fyEnd;
    if (currentMonth < 4) {
      fyStart = currentYear - 1;
      fyEnd = currentYear;
    } else {
      fyStart = currentYear;
      fyEnd = currentYear + 1;
    }

    this.fyvalue = fyStart + "-" + fyEnd;
    //this.publishLMS();
  }

  handleChange(event) {
    this.fyvalue = event.target.value;
    log("publishing event.....");
    this.publishLMS();
  }

  publishLMS() {
    console.log("Publishing", this.fyvalue);
    const payload = { recordId: this.fyvalue };
    publish(this.messageContext, recordSelected, payload);
  }
}
