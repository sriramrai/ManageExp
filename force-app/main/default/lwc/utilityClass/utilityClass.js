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

/**
 * Converts a total number of days (measured from startDate) into a
 * calendar-accurate [years, months, days] breakdown. Mirrors the logic
 * used for interpreting FD tenure such as "555 days" against a start date.
 *
 * @param {string|Date} startDateInput - Start date (e.g. "YYYY-MM-DD").
 * @param {number} totalDays - Total number of days to add to the start date.
 * @returns {number[]} [years, months, days], or [0, 0, 0] on invalid input.
 */
const getCalendarDurationFromDays = (startDateInput, totalDays) => {
  if (!isValidValue(startDateInput) || !isValidValue(totalDays)) {
    return [0, 0, 0];
  }

  const parsedStart = new Date(startDateInput);

  if (isNaN(parsedStart.getTime()) || isNaN(Number(totalDays))) {
    return [0, 0, 0];
  }

  const startDate = new Date(
    Date.UTC(
      parsedStart.getUTCFullYear(),
      parsedStart.getUTCMonth(),
      parsedStart.getUTCDate()
    )
  );

  const maturityDate = new Date(startDate);
  maturityDate.setUTCDate(maturityDate.getUTCDate() + Number(totalDays));

  let years = maturityDate.getUTCFullYear() - startDate.getUTCFullYear();
  let tempDate = new Date(startDate);
  tempDate.setUTCFullYear(tempDate.getUTCFullYear() + years);

  if (tempDate > maturityDate) {
    years--;
    tempDate = new Date(startDate);
    tempDate.setUTCFullYear(tempDate.getUTCFullYear() + years);
  }

  let months = 0;

  while (true) {
    const nextDate = new Date(tempDate);
    nextDate.setUTCMonth(nextDate.getUTCMonth() + 1);

    if (nextDate <= maturityDate) {
      months++;
      tempDate = nextDate;
    } else {
      break;
    }
  }

  const days = Math.round(
    (maturityDate.getTime() - tempDate.getTime()) / (24 * 60 * 60 * 1000)
  );

  return [years, months, days];
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
  getLoggedInUserName,
  getCalendarDurationFromDays
};
