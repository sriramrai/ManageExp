import { LightningElement, api, wire } from "lwc";
import currentExpenseId from "@salesforce/apex/ExpenseController.getCurrentExpenseId";
import ltngNewExpenseModal from "c/newExpenseModal";
import { log, logError, toString } from "c/utilityClass";

export default class ExpenseHeaderV2 extends LightningElement {
  @api total;
  startDate;
  endDate;
  currentExpenseId;
  @api selectedItems;
  selectedDuration = 0;
  isEnabled = false;
  durations = [
    { label: "0", value: 0 },
    { label: "1", value: 1 },
    { label: "2", value: 2 },
    { label: "3", value: 3 },
    { label: "4", value: 4 },
    { label: "5", value: 5 },
    { label: "6", value: 6 },
    { label: "7", value: 7 },
    { label: "8", value: 8 },
    { label: "9", value: 9 },
    { label: "10", value: 10 },
    { label: "11", value: 11 },
    { label: "12", value: 12 }
  ];

  selectedfrequency = "Months";
  frequencies = [
    { label: "Months", value: "Months" },
    { label: "Years", value: "Years" }
  ];

  @wire(currentExpenseId)
  getCurrentId({ error, data }) {
    if (data) {
      this.currentExpenseId = data;
    } else if (error) {
      console.error("Error Occured while fetching current Expense Id");
      console.error(error);
    }
  }

  connectedCallback() {
    this.init();
  }

  init() {
    let today = new Date(),
      y = today.getFullYear(),
      m = today.getMonth();
    let firstDate = new Date(y, m, 1);
    let lastDate = new Date(y, m + 1, 0);
    this.startDate = new Date(
      firstDate.getTime() - firstDate.getTimezoneOffset() * 60000
    )
      .toISOString()
      .split("T")[0];
    this.endDate = new Date(
      lastDate.getTime() - lastDate.getTimezoneOffset() * 60000
    )
      .toISOString()
      .split("T")[0];
    const today1 = new Date();
    const currentMonth = String(today1.getMonth() + 1);
    const currentYear = String(today1.getFullYear()); // Default: Single Month
    this.selectedMonth = currentMonth;
    this.selectedYear = currentYear;
    // Default Range
    this.fromMonth = currentMonth;
    this.fromYear = currentYear;
    this.toMonth = currentMonth;
    this.toYear = currentYear;
    this.notifyParent();
  }

  searchHandler(event) {
    let searchText = event.target.value;
    let searchEvent = new CustomEvent("searchevent", {
      detail: { searchText: searchText, alltime: this.isOn }
    });
    this.dispatchEvent(searchEvent);
  }

  isOn = false;

  get switchText() {
    return this.isOn ? "ALL" : "ALL";
  }

  handleToggle(event) {
    this.isOn = event.target.checked;
  }

  refetchRecords() {
    let today = new Date(),
      y = today.getFullYear(),
      m = today.getMonth();
    let currentMonthStartDate = new Date(y, m, 1);
    let duration =
      this.selectedfrequency == "Months"
        ? this.selectedDuration
        : this.selectedDuration * 12;
    this.startDate = currentMonthStartDate.setMonth(
      currentMonthStartDate.getMonth() - duration
    );
    let d = new Date(this.startDate);
    this.startDate =
      d.getFullYear() +
      "-" +
      String(d.getMonth() + 1).padStart(2, "0") +
      "-" +
      String(d.getDate()).padStart(2, "0");
    this.notifyParent();
  }

  notifyParent() {
    let customEvent = new CustomEvent("datachanged", {
      detail: { fromDate: this.startDate, toDate: this.endDate }
    });
    this.dispatchEvent(customEvent);
  }

  async createRecord(event) {
    let result = await ltngNewExpenseModal.open({
      size: "small",
      description: "Accessible description of modal's purpose",
      content: "test contetnt",
      headerText: "Set the filter",
      modalData: this.currentExpenseId
    });

    console.log("record created successfully...");
    console.log(result);
    if (result) {
      let customEvent = new CustomEvent("newrecord", {
        detail: { newrecord: true }
      });
      this.dispatchEvent(customEvent);
    }
  }

  changedDuration(event) {
    let val = event.target.value;
    this.selectedDuration = parseInt(val);
  }

  changedFrequency(event) {
    let val = event.target.value;
    debugger;
    this.selectedfrequency = val;
    //this.selectedDuration = this.selectedfrequency == 'Months' ? this.selectedDuration : this.selectedDuration*12;
  }
  showFilters = false;
  selectedMonth;
  selectedYear;
  filterType = "single";
  fromMonth;
  fromYear;
  toMonth;
  toYear;
  get isSingleMonth() {
    return this.filterType === "single";
  }
  get isDateRange() {
    return this.filterType === "range";
  }
  get selectedMonthLabel() {
    const selected = this.months.find(
      (month) => month.value === this.selectedMonth
    );
    return selected ? selected.label : "";
  }
  get isSingleMonth() {
    return this.filterType === "single";
  }
  get isDateRange() {
    return this.filterType === "range";
  }
  months = [
    { label: "January", value: "1" },
    { label: "February", value: "2" },
    { label: "March", value: "3" },
    { label: "April", value: "4" },
    { label: "May", value: "5" },
    { label: "June", value: "6" },
    { label: "July", value: "7" },
    { label: "August", value: "8" },
    { label: "September", value: "9" },
    { label: "October", value: "10" },
    { label: "November", value: "11" },
    { label: "December", value: "12" }
  ];
  years = Array.from({ length: 9 }, (_, index) => {
    const year = 2024 + index;
    return { label: String(year), value: String(year) };
  });

  toggleFilters() {
    this.showFilters = !this.showFilters;
  }
  changedMonth(event) {
    this.selectedMonth = event.detail.value;
  }
  changedYear(event) {
    this.selectedYear = event.detail.value;
  }
  applyFilters() {
    this.showFilters = false;
  }
}
