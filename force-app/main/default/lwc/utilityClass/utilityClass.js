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

export { isValid, log, logError, getFYForExpManager,  getMonthOptionForExpManager, getSalaryAmountFields};