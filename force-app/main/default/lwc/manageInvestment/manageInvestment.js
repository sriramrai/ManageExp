import { LightningElement, wire, track } from "lwc";
import getAllInvestMentMap from "@salesforce/apex/ExpenseManagerUtil.getAllInvestMentMapForEntity";
import {
  log,
  logError,
  toString,
  deepClone,
  isValidValue,
  getLoggedInUserName
} from "c/utilityClass";
import { refreshApex } from "@salesforce/apex";
import { NavigationMixin } from "lightning/navigation";
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";
import createRecordModal from "c/createNewRecordModal";
import createNewFutureInvestmentModal from "c/createNewFutureInvestment";
import createStockModal from "c/createNewStockModal";
import { publish, MessageContext } from "lightning/messageService";
import ENTITYCHANGE_CHANNEL from "@salesforce/messageChannel/EntityChange__c";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import INVESTMENT_OBJECT from "@salesforce/schema/Investment__c";
import bookFdModal from "c/bookFd";
export default class ManageInvestment extends NavigationMixin(
  LightningElement
) {
  @wire(MessageContext)
  messageContext;
  provisionedItem;
  fdTabs = ["axis", "sbi", "bob", "ubi", "sc", "hdfc", "boi"];
  futureInvestmentTabs = ["NPS", "PPF"];
  selectedEntity;
  @track tabList = [];
  investmentRecordTypeId;

  @wire(getObjectInfo, { objectApiName: INVESTMENT_OBJECT })
  objectInfo({ data, error }) {
    if (data) {
      const recordType = Object.values(data.recordTypeInfos).find(
        (rt) => rt.name === "Investment"
      );

      this.investmentRecordTypeId = recordType?.recordTypeId;

      console.log("Investment RT Id:", this.investmentRecordTypeId);
    }

    if (error) {
      console.error(error);
    }
  }

  get shouldShowNonFdTabs() {
    let show = this.selectedEntity == "Sriram" ? true : false;
    return show;
  }

  get entityOptions() {
    if (this.userName == "Sriram" || this.userName == "User") {
      return [
        { label: "Ragini", value: "Ragini" },
        { label: "Sriram", value: "Sriram" },
        { label: "Mom", value: "Mom" },
        { label: "Dad", value: "Dad" }
      ];
    } else if (this.userName == "Ragini") {
      return [{ label: "Ragini", value: "Ragini" }];
    } else {
      return [
        { label: "Mom", value: "Mom" },
        { label: "Dad", value: "Dad" }
      ];
    }
  }

  handleEntityChange(event) {
    this.selectedEntity = event.target.value;
    this.publishSelectedEntity();
  }

  publishSelectedEntity() {
    publish(this.messageContext, ENTITYCHANGE_CHANNEL, {
      entityName: this.selectedEntity
    });
  }

  async connectedCallback() {
    const userName = await getLoggedInUserName();
    if (userName == "Ragini") {
      this.userName = "Ragini";
    } else if (userName == "Sriram" || userName == "User") {
      this.userName = "Sriram";
    } else {
      this.userName = "Dad";
    }
    this.selectedEntity = this.userName;
    //this.userName = userName == "Ragini" ? "Ragini" : "Sriram";
    //this.selectedEntity = this.userName == "Ragini" ? "Ragini" : "Sriram";
    this.publishSelectedEntity();
  }

  /* @wire(getAllInvestMentMap, { entityName: "$selectedEntity" })
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
      const previousTab = this.previousTabName;
      Object.keys(data).forEach((bank) => {
        const entries = [...data[bank]];

        if (!firstTab) {
          firstTab = bank;
        }

        if (previousTab) {
          firstTab = previousTab;
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
  } */
  @wire(getAllInvestMentMap, { entityName: "$selectedEntity" })
  allInvestment(result) {
    this.provisionedItem = result;

    if (result.data) {
      console.log("Wire data:", result.data);

      const previousTab = this.previousTabName;
      const tabs = [];

      Object.keys(result.data).forEach((bank) => {
        const entries = [...result.data[bank]];

        tabs.push({
          key: `${this.selectedEntity}-${bank}`,
          label: `${bank.toUpperCase()} (${entries.length})`,
          value: bank,
          dataId: bank.toUpperCase(),
          records: entries
        });
      });

      // Determine which tab should be active
      const previousTabStillExists = tabs.some(
        (tab) => tab.value === previousTab
      );

      const tabToActivate = previousTabStillExists
        ? previousTab
        : tabs[0]?.value;

      // Remove old tabset
      this.tabList = null;

      setTimeout(() => {
        this.tabList = tabs;
        this.tabsetKey++;

        setTimeout(() => {
          this.activeTabName = tabToActivate;

          console.log("Restoring tab:", this.activeTabName);

          // Clear it after restoring
          this.previousTabName = null;
        }, 50);
      }, 0);
    } else if (result.error) {
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
    return refreshApex(this.provisionedItem);
  }

  counterHandler(event) {
    log("inside conter Handler*** : " + event.detail.count);
  }

  async logFd() {
    let contentData = {
      objectapiname: "Investment__c",
      fieldList: this.getFieldList(false)
    };

    const fdResult = await bookFdModal.open({
      size: "small",
      description: "Book modal",
      content: {}
    });

    if (fdResult === "createManual") {
      contentData.fieldList = this.getFieldList(false);
    } else if (isValidValue(fdResult)) {
      contentData.fieldList = this.getFieldList(false, JSON.parse(fdResult));
    } else {
      return;
    }

    const result = await createRecordModal.open({
      size: "small",
      description: "Renewal/Close",
      content: contentData
    });

    return result;
  }

  async logDefault() {
    let contentData = {
      objectapiname: "Investment__c",
      fieldList: this.getFieldList(true)
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
    if (this.activeTabName == null) {
      result = await this.logDefault();
    } else if (this.fdTabs.indexOf(this.activeTabName) >= 0) {
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

  getFieldList(isDefault, cloneFrom) {
    let applicableObj = this.getObject();
    if (isDefault) {
      applicableObj = {
        RecordTypeId: this.investmentRecordTypeId
      };
    }
    let fieldList = [];

    let field1 = {
      fieldapiname: "Account_Number__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Account_Number__c") &&
        isValidValue(cloneFrom.Account_Number__c)
          ? cloneFrom.Account_Number__c
          : "",
      key: 1,
      disabled: false,
      required: true
    };
    let field2 = {
      fieldapiname: "Start_Date__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Start_Date__c") &&
        isValidValue(cloneFrom.Start_Date__c)
          ? cloneFrom.Start_Date__c
          : new Date(Date.now()).toISOString(),
      key: 2,
      disabled: false,
      required: true
    };
    let field3 = {
      fieldapiname: "Amount__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Amount__c") &&
        isValidValue(cloneFrom.Amount__c)
          ? cloneFrom.Amount__c
          : "",
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
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Bank__c") &&
        isValidValue(cloneFrom.Bank__c)
          ? cloneFrom.Bank__c
          : applicableObj.Bank__c,
      key: 5,
      disabled: isDefault ? false : true,
      required: true
    };

    let field6 = {
      fieldapiname: "Rate__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Rate__c") &&
        isValidValue(cloneFrom.Rate__c)
          ? cloneFrom.Rate__c
          : "",
      key: 6,
      disabled: false,
      required: true
    };

    let field7 = {
      fieldapiname: "Year__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Year__c") &&
        isValidValue(cloneFrom.Year__c)
          ? cloneFrom.Year__c
          : 0,
      key: 7,
      disabled: false,
      // Not individually required - at least one of Year__c/Month__c/Day__c
      // is enforced by createNewRecordModal before save.
      required: false
    };

    let field8 = {
      fieldapiname: "Month__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Month__c") &&
        isValidValue(cloneFrom.Month__c)
          ? cloneFrom.Month__c
          : 0,
      key: 8,
      disabled: false,
      required: false
    };

    let field9 = {
      fieldapiname: "Day__c",
      value:
        isValidValue(cloneFrom) &&
        cloneFrom.hasOwnProperty("Day__c") &&
        isValidValue(cloneFrom.Day__c)
          ? cloneFrom.Day__c
          : 0,
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

  async handleRefreshData(event) {
    console.log("inside handleRefreshData....");

    // Save currently selected tab
    this.previousTabName = this.activeTabName;

    console.log("Saving previous tab:", this.previousTabName);

    this.refreshHandler();

    console.log("refreshApex completed");
  }
}
