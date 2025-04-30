import { LightningElement, api, wire } from 'lwc';
import getCCStatements from '@salesforce/apex/ExpenseController.getCCStatements';


export default class CreditCardMonitor extends LightningElement {
    selectedBank = 'ICICI CC';
    total = 0;
    data = [];
    columns = [
        {label: 'Amount', fieldName: 'Amount__c'},
        {label: 'Details', fieldName: 'Details__c'},
        {label: 'Date', fieldName: 'Date__c'},
        {label: 'Due Date', fieldName: 'Payment_Due_Date__c'}
    ];

    @wire(getCCStatements, {'month': '$selectedMonth', 'year': '$selectedYear', 'bank': '$selectedBank'})
    ccStatements({error, data}) {
        if(data) {
            console.log('Credit statements fetched from server...');
            console.log(data);
            this.data = data;
            data.forEach(rec => {
                this.total += rec.Amount__c;
            })
        }else if(error) {
            console.error('Error receivied while fetching CC');
        }
    }

    get months() {
        return [
            {label: 'Jan', value: '01'},
            {label: 'Feb', value: '02'},
            {label: 'Mar', value: '03'},
            {label: 'Apr', value: '04'},
            {label: 'May', value: '05'},
            {label: 'Jun', value: '06'},
            {label: 'Jul', value: '07'},
            {label: 'Aug', value: '08'},
            {label: 'Sep', value: '09'},
            {label: 'Oct', value: '10'},
            {label: 'Nov', value: '11'},
            {label: 'Dec', value: '12'},
        ];
    }

    get years() {
        return [
            {label: '2025', value: '2025'},
            {label: '2026', value: '2026'},
            {label: '2027', value: '2027'},
            {label: '2028', value: '2028'},
            {label: '2029', value: '2029'},
            {label: '2030', value: '2030'},
        ];
    }

    get banks() {
        return [
            {label: 'Axis', value: 'Axis CC'},
            {label: 'ICICI', value: 'ICICI CC'}
        ];
    }

    get selectedMonth() {
        return '02';
    }

    get selectedYear() {
        return '2025';
    }
}