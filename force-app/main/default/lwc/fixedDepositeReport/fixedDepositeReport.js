import { LightningElement, wire, track } from 'lwc';
import getInvestment from "@salesforce/apex/InvestmentController.getInvestments"
const MONTH_ARRAY = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

export default class FixedDepositeReport extends LightningElement {
    total;
    selectedValue = 'Last 3 Months';
    @track records = [];

    @wire(getInvestment, {'selectedValue' : '$selectedValue'}) 
    investments({error, data}) {
        if(data) {
            this.records = [];
            const investmentMap = this.organizeByMonths(data);
            this.initializeData(investmentMap);
        }else if(error) {
            console.error('Error occured for fixedDepositeReport.getInvestments... : '+error);
        }
    }

    getApplicableMonths() {
        let months = [];
        let today = new Date();
        let currentMonth = today.getMonth();
        let currentYear = today.getFullYear();
        let backTrack = 12;
        if(this.selectedValue == 'Last 3 Months') {
            backTrack = 3;
        }else if(this.selectedValue == 'Last 6 Months') {
            backTrack = 6;
        }

        for(let i=0 ; i<backTrack; i++) {
            let monthName = MONTH_ARRAY[currentMonth] + ' '+ currentYear;
            months.push(monthName);
            currentMonth -= 1;
            if(currentMonth < 0) {
                currentYear -= 1;
                currentMonth += 12;
            }
        }

        return months;
    }

    initializeData(investmentMap) {
        let totalAmout = 0;
        let appliedMonths = this.getApplicableMonths();
        let actualInvestments = [];
        for(const key of investmentMap.keys()) {
            let investments = investmentMap.get(key);
            let record = {
                'monthname' : key,
                'banks' : '',
                'total' : 0
            };
            investments.forEach(investment => {
                record.banks += ', ' + investment.Bank__c;
                record.total += investment.Amount__c;
            });
            totalAmout += record.total;
            if(record.banks != '') {
                record.banks = record.banks.substring(1, record.banks.length);
                record.total = record.total;
                //record.total = record.total.toLocaleString('en-IN');
            }
            actualInvestments.push(record);
        }
       // this.total = totalAmout.toLocaleString('en-IN');
       this.total = 0;
        appliedMonths.forEach(mnth => {
            let investment = this.isPresent(mnth, actualInvestments);
            if(!investment) {
                let record = {
                    'monthname' : mnth,
                    'banks' : '',
                    'total' : 0,
                    'classname' : 'noinvestmentClass'
                };
                //this.records.push(record); 
            }else {
                this.records.push(investment); 
                this.total += parseInt(investment['total']);
                investment.total = investment.total.toLocaleString('en-IN');
            }
        });

        this.total = this.total.toLocaleString('en-IN');
    }

    isPresent(month, investmentArray) {
        let result = false;
        for(let i=0; i<investmentArray.length; i++) {
            let invst = investmentArray[i];
            if(invst.monthname == month) {
                result = invst;
                break;
            }
        }

        return result;
    }

    organizeByMonths(data) {
        let investmentsByMonths = new Map();
        data.forEach(record => {
            let investmentDate = new Date(record.Start_Date__c);
            let mapKey = investmentDate.toLocaleString('en-us',{month:'short', year:'numeric'});
            if(investmentsByMonths.has(mapKey)) {
                let values = investmentsByMonths.get(mapKey);
                values.push(record);
                investmentsByMonths.set(mapKey, values);
            }else {
                investmentsByMonths.set(mapKey, [record]);
            }
        });

        return investmentsByMonths;
    }

    get options() {
        return [
            { label: 'Last 3 Months', value:'Last 3 Months'},
            { label: 'Last 6 Months', value:'Last 6 Months'},
            { label: 'Last 1 Year', value:'Last 1 Year'},
        ]
    }

  /*   buttonClickHandler(event) {
        let combobox = this.template.querySelector("lightning-combobox");
        let selectedValue = combobox.value;
        if(this.selectedValue != selectedValue) {
            this.selectedValue = selectedValue;
        }
    } */

    handleChange(event) {
        this.selectedValue = event.target.value;
    }
}