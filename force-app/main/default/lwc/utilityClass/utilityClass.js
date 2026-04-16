import { LightningElement } from 'lwc';

const isValid = (data) => {
    console.log('inside isvalid method...');
    if(data != '' && typeof data != 'undefined' && data != undefined) {
        return true;
    }

    return false;
}

const log = (message) => {
    console.log(message);
}

const logError = (message) => {
    console.error(message);
}

const getFYForExpManager = () => {
    return [
        { value: '2021-2022', label: 'FY 21-22' },
        { value: '2022-2023', label: 'FY 22-23' },
        { value: '2023-2024', label: 'FY 23-24' },
        { value: '2024-2025', label: 'FY 24-25' },
        { value: '2025-2026', label: 'FY 25-26' },
        { value: '2026-2027', label: 'FY 26-27' },
        { value: '2027-2028', label: 'FY 27-28' },
        { value: '2028-2029', label: 'FY 28-29' },
        { value: '2029-2030', label: 'FY 29-30' },
        { value: '2030-2031', label: 'FY 30-31' },
        { value: '2031-2032', label: 'FY 31-32' },
    ];
}

const getSalaryAmountFields = () => {
    return ['Basic__c', 'Conveyance__c', 'Project_Allowance__c', 'Food_Allowance__c', 'HRA__c', 'Income_Tax__c', 'Labor_Welfare_Fund__c', 'LTA__c', 'Medical_Allowance__c', 'Professional_Tax__c', 'Telephone_Allowance__c'];
}

const getMonthOptionForExpManager = () => {
    return [
        { value: '01', label: 'JAN' },
        { value: '02', label: 'FEB' },
        { value: '03', label: 'MAR' },
        { value: '04', label: 'APR' },
        { value: '05', label: 'MAY' },
        { value: '06', label: 'JUN' },
        { value: '07', label: 'JUL' },
        { value: '08', label: 'AUG' },
        { value: '09', label: 'SEP' },
        { value: '10', label: 'OCT' },
        { value: '11', label: 'NOV' },
        { value: '12', label: 'DEC' },
    ];
}

const toString = (data) => {
    return JSON.stringify(data);
}

const deepClone = (data) => {
    return JSON.parse(JSON.stringify(data));
}

const isValidValue = (data) => {
    if(data != '' && typeof(data) != undefined && data != null) {
        return true;
    }
    return false;
}

const formatDate = (data) => {
    const formatter = new Intl.DateTimeFormat('en-IN', {
        day: '2-digit',
        month: 'short',
        year: '2-digit'
    });
    return data  ? formatter.format(new Date(data)) : '';
}

export { isValid, log, logError, getFYForExpManager,  getMonthOptionForExpManager, getSalaryAmountFields, toString, deepClone, isValidValue, formatDate};