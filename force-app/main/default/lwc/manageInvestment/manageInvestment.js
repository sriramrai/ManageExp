import { LightningElement, wire, track } from "lwc";
import getAllInvestMentMap from "@salesforce/apex/ExpenseManagerUtil.getAllInvestMentMapForEntity";
import {
  log,
  logError,
  toString,
  deepClone,
  isValidValue
} from "c/utilityClass";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import createRecordModal from "c/createNewRecordModal";
import createNewFutureInvestmentModal from "c/createNewFutureInvestment";
import createStockModal from "c/createNewStockModal";

export default class ManageInvestment extends NavigationMixin(
  LightningElement
) {
  sbiEntries = [];
  axisEntries = [];
  scEntries = [];
  ppfEntries = [];
  npsEntires = [];
  provisionedItem;
  //activeTabName = "axis";
  //@track activeTabName = "";
  fdTabs = ["axis", "sbi", "bob", "ubi", "sc", "hdfc", "boi"];
  futureInvestmentTabs = ["NPS", "PPF"];
  entityOptions = [
    { label: "Ragini", value: "Ragini" },
    { label: "Sriram", value: "Sriram" },
    { label: "Mom", value: "Mom" },
    { label: "Dad", value: "Dad" }
  ];
  selectedEntity = "Sriram";
  get getSbiLabel() {
    return "SBI (" + this.sbiEntries.length + ")";
  }

  get getAxisLabel() {
    return "AXIS (" + this.axisEntries.length + ")";
  }

  @track tabList = [];

  get shouldShowNonFdTabs() {
    let show = this.selectedEntity == "Sriram" ? true : false;
    return show;
  }

  handleEntityChange(event) {
    let selectedValue = event.target.value;
    this.selectedEntity = selectedValue;
  }

  @wire(getAllInvestMentMap, { entityName: "$selectedEntity" })
  allInvestment(result) {
    //this.tabList = [];
    this.provisionedItem = result;
    let data = result.data;
    let error = result.error;
    if (data) {
      this.tabList = null;
      this.activeTabName = null;
      console.log("Wire data:", result.data);
      const tabs = [];
      let firstTab;

      Object.keys(data).forEach((bank) => {
        const entries = [...data[bank]];

        if (!firstTab) {
          firstTab = bank;
        }

        tabs.push({
          key: `${this.selectedEntity}-${bank}`,
          label: `${bank.toUpperCase()} (${entries.length})`,
          value: bank,
          dataId: bank.toUpperCase(),
          records: entries
        });
      });

      // remove old tabset
      this.tabList = null;

      setTimeout(() => {
        this.tabList = tabs;
        this.tabsetKey++;

        // wait until lightning-tabset registers tabs
        setTimeout(() => {
          this.activeTabName = firstTab;
        }, 50);
      }, 0);
    } else if (error) {
      logError("Error While Fetching Investment record...");
    }
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

  activeTabHandler(event) {
    this.activeTabName = event.target.value;

    this.tabList = this.tabList.map((tab) => ({
      ...tab,
      isActive: tab.value === this.activeTabName
    }));
  }

  refreshHandler(event) {
    refreshApex(this.provisionedItem);
  }

  counterHandler(event) {
    log("inside conter Handler*** : " + event.detail.count);
  }

  async logFd() {
    let contentData = {
      objectapiname: "Investment__c",
      fieldList: this.getFieldList()
    };

    const result = await createRecordModal.open({
      size: "small",
      description: "Renewal/Close",
      content: contentData
    });

    return result;
  }

  async logTreaseure() {
    let contentData = {
      objectapiname: "Treasure__c",
      fieldList: this.getTresureFields()
    };

    const result = await createRecordModal.open({
      size: "small",
      description: "Treasure",
      content: contentData
    });

    return result;
  }

  async logFutureInvestment() {
    const result = await createNewFutureInvestmentModal.open({
      size: "small",
      description: "Future Investment",
      content: this.activeTabName
    });

    return result;
  }

  async logStock() {
    const result = await createStockModal.open({
      size: "small",
      description: "New Stock Registration",
      content: this.activeTabName
    });
    return result;
  }

  async createInvestment(event) {
    let result;
    if (this.fdTabs.indexOf(this.activeTabName) >= 0) {
      result = await this.logFd();
    } else if (this.futureInvestmentTabs.indexOf(this.activeTabName) >= 0) {
      result = await this.logFutureInvestment();
    } else if (this.activeTabName == "Stock") {
      result = await this.logStock();
    } else if (this.activeTabName == "Treasure") {
      log("inside treasure....");
      result = await this.logTreaseure();
    }

    if (isValidValue(result) && result.STATUS == "CREATED") {
      if (result.BANK == "Stock") {
        let queryStr = "[data-id=" + result.BANK;
        const stockComponent = this.template.querySelector(queryStr);
        stockComponent.refreshData();
      } else {
        refreshApex(this.provisionedItem);
        let queryStr = "[data-id=" + result.BANK;
        const investmentListLWC = this.template.querySelector(queryStr);
        investmentListLWC.newRecordCreatedHandler();
      }
    }
  }

  getTresureFields() {
    let fieldList = [];
    let field1 = {
      fieldapiname: "Date__c",
      value: "",
      key: 1,
      disabled: false,
      required: true
    };

    let field2 = {
      fieldapiname: "Amount__c",
      value: "",
      key: 1,
      disabled: false,
      required: true
    };

    let field3 = {
      fieldapiname: "Tresuree__c",
      value: "",
      key: 1,
      disabled: false,
      required: true
    };

    let field4 = {
      fieldapiname: "Details__c",
      value: "",
      key: 1,
      disabled: false,
      required: true
    };

    let field5 = {
      fieldapiname: "FD_Breakage__c",
      value: false,
      key: 1,
      disabled: false,
      required: false
    };

    fieldList.push(field1);
    fieldList.push(field2);
    fieldList.push(field3);
    fieldList.push(field4);
    fieldList.push(field5);

    return fieldList;
  }

  getObject() {
    let dataObj = this.provisionedItem.data;
    const bank = Object.keys(dataObj).find(
      (bank) => bank === this.activeTabName
    );
    if (bank) {
      return [...dataObj[bank]][0];
    }

    return null;
  }

  getFieldList() {
    let applicableObj = this.getObject();
    let fieldList = [];

    let field1 = {
      fieldapiname: "Account_Number__c",
      value: "",
      key: 1,
      disabled: false,
      required: true
    };
    let field2 = {
      fieldapiname: "Start_Date__c",
      value: new Date(Date.now()).toISOString(),
      key: 2,
      disabled: false,
      required: true
    };
    let field3 = {
      fieldapiname: "Amount__c",
      value: "",
      key: 3,
      disabled: false,
      required: true
    };
    let field4 = {
      fieldapiname: "RecordTypeId",
      value: applicableObj.RecordTypeId,
      key: 4,
      disabled: true,
      required: true
    };

    let field5 = {
      fieldapiname: "Bank__c",
      value: applicableObj.Bank__c,
      key: 5,
      disabled: true,
      required: true
    };

    let field6 = {
      fieldapiname: "Rate__c",
      value: "",
      key: 6,
      disabled: false,
      required: true
    };

    let field7 = {
      fieldapiname: "Year__c",
      value: "",
      key: 7,
      disabled: false,
      required: true
    };

    let field8 = {
      fieldapiname: "Month__c",
      value: "",
      key: 8,
      disabled: false,
      required: false
    };

    let field9 = {
      fieldapiname: "Day__c",
      value: "",
      key: 9,
      disabled: false,
      required: false
    };

    let field10 = {
      fieldapiname: "Tax_saver__c",
      value: false,
      key: 10,
      disabled: false,
      required: false,
      isCheckbox: true,
      label: "Tax Saver"
    };
    let field11 = {
      fieldapiname: "Entity__c",
      value: this.selectedEntity,
      key: 11,
      disabled: true,
      required: true
    };

    fieldList.push(field1);
    fieldList.push(field2);
    fieldList.push(field3);
    fieldList.push(field4);
    fieldList.push(field5);
    fieldList.push(field6);
    fieldList.push(field7);
    fieldList.push(field8);
    fieldList.push(field9);
    fieldList.push(field11);
    fieldList.push(field10);

    return fieldList;
  }
}
