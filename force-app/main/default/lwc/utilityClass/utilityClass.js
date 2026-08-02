import { LightningElement } from "lwc";
import getCurrentUserName from "@salesforce/apex/ApexUtilityClass.getCurrentUserName";

const isValid = (data) => {
  console.log("inside isvalid method...");
  if (data != "" && typeof data != "undefined" && data != undefined) {
    return true;
  }

  return false;
};

const log = (message) => {
  console.log(message);
};

const logError = (message) => {
  console.error(message);
};

const getFYForExpManager = () => {
  return [
    { value: "2021-2022", label: "FY 21-22" },
    { value: "2022-2023", label: "FY 22-23" },
    { value: "2023-2024", label: "FY 23-24" },
    { value: "2024-2025", label: "FY 24-25" },
    { value: "2025-2026", label: "FY 25-26" },
    { value: "2026-2027", label: "FY 26-27" },
    { value: "2027-2028", label: "FY 27-28" },
    { value: "2028-2029", label: "FY 28-29" },
    { value: "2029-2030", label: "FY 29-30" },
    { value: "2030-2031", label: "FY 30-31" },
    { value: "2031-2032", label: "FY 31-32" }
  ];
};

const getCurrentFY = () => {
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

  return fyStart + "-" + fyEnd;
};

const getSalaryAmountFields = () => {
  return [
    "Basic__c",
    "Conveyance__c",
    "Project_Allowance__c",
    "Food_Allowance__c",
    "HRA__c",
    "Income_Tax__c",
    "Labor_Welfare_Fund__c",
    "LTA__c",
    "Medical_Allowance__c",
    "Professional_Tax__c",
    "Telephone_Allowance__c"
  ];
};

const getMonthOptionForExpManager = () => {
  return [
    { value: "01", label: "JAN" },
    { value: "02", label: "FEB" },
    { value: "03", label: "MAR" },
    { value: "04", label: "APR" },
    { value: "05", label: "MAY" },
    { value: "06", label: "JUN" },
    { value: "07", label: "JUL" },
    { value: "08", label: "AUG" },
    { value: "09", label: "SEP" },
    { value: "10", label: "OCT" },
    { value: "11", label: "NOV" },
    { value: "12", label: "DEC" }
  ];
};

const toString = (data) => {
  return JSON.stringify(data);
};

const deepClone = (data) => {
  return JSON.parse(JSON.stringify(data));
};

const isValidValue = (data) => {
  if (data != "" && typeof data != "undefined" && data != null) {
    return true;
  }
  return false;
};

const formatDate = (data) => {
  const formatter = new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "2-digit"
  });
  return data ? formatter.format(new Date(data)) : "";
};

const getLoggedInUserName = async () => {
  return await getCurrentUserName();
};

/**
 * Returns true if the current device is a mobile device.
 * Detection is based on navigator.userAgent keywords and a screen-width
 * threshold (< 768 px).  Either condition being true is sufficient.
 */
const isMobile = () => {
  const mobileUserAgentPattern =
    /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i;
  const hasMobileUserAgent = mobileUserAgentPattern.test(navigator.userAgent);
  const hasSmallScreen = window.innerWidth < 768;
  return hasMobileUserAgent || hasSmallScreen;
};

/**
 * Returns true if the current device is a laptop / desktop.
 * This is the logical inverse of isMobile().
 */
const isLaptop = () => {
  return !isMobile();
};

/**
 * Returns a string representing the current device type.
 * @returns {'mobile'|'laptop'} - 'mobile' for phones/tablets, 'laptop' for desktops/laptops
 */
const getDeviceType = () => {
  return isMobile() ? "mobile" : "laptop";
};

export {
  isValid,
  log,
  logError,
  getFYForExpManager,
  getCurrentFY,
  getMonthOptionForExpManager,
  getSalaryAmountFields,
  toString,
  deepClone,
  isValidValue,
  formatDate,
  isMobile,
  isLaptop,
  getDeviceType,
  getLoggedInUserName
};
