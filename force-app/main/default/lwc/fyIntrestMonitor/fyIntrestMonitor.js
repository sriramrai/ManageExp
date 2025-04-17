import { LightningElement, wire } from 'lwc';
import getFYIntrest from '@salesforce/apex/InvestmentController.getFYIntrest';
import { NavigationMixin } from 'lightning/navigation';

export default class FyIntrestMonitor extends NavigationMixin(LightningElement) {
    fyvalue;
    intrestList = [];
    totalIntr = 0;
    totalTds = 0;
    errorMessage;

    get fyOptions() {
        return [
            { label: 'FY 21-22', value:'2021-2022'},
            { label: 'FY 22-23', value:'2022-2023'},
            { label: 'FY 23-24', value:'2023-2024'},
            { label: 'FY 24-25', value:'2024-2025'},
            { label: 'FY 25-26', value:'2025-2026'}
        ]
    }

    @wire(getFYIntrest, {'fy' : '$fyvalue'})
    fyIntrest({error, data}) {
        if(data) {
            this.intrestList = [];
            let objectKeys = Object.keys(data);
            for(let i=0; i<objectKeys.length; i++) {
                let bank = objectKeys[i];
                let show = bank !== 'Total' ? true : false; 
                let obj = {
                    'bank': bank,
                    'intrest' : data[bank],
                    'isShow' : show
                };
                this.intrestList.push(obj);
            }
        }else if(error) {
            console.error(error);
            this.errorMessage = error.body.stackTrace;
        }
    }

    connectedCallback() {
        this.initializeData();
    }

    initializeData() {
        let today = new Date();
        let currentMonth = today.getMonth()+1;
        let currentYear = today.getFullYear();
        let fyStart, fyEnd;
        if(currentMonth < 4) {
            fyStart = currentYear-1;
            fyEnd = currentYear
        }else {
            fyStart = currentYear;
            fyEnd = currentYear+1;
        }

        this.fyvalue = fyStart+"-"+fyEnd;
    }

    handleChange(event) {
        this.fyvalue = event.target.value;  
    }

    showMore1(event) {
        let selectedIndex = event.target.getAttribute("data-id");
        let selectedValue = this.intrestList[selectedIndex];
        let selectedObj = {
            'fy' : this.fyvalue,
            'bank' : selectedValue.bank
        };
        console.log('this.fyear*** : '+this.fyvalue);
        this[NavigationMixin.Navigate]({
            type: "standard__component",
            attributes: {
                componentName: "c__fiscalYearNavigationHelper"
            },
            state: {
                c__fiscalYr : {'fy' : this.fyvalue, 'bank' : selectedObj.bank}
            }
        });
    }
    /* showMore(event) {
        console.log('anchor tab clicked...');
        this.isShowModal = true;
        this.selectedBank = 'AXIS';
        console.log('Show more clicked...');
        let selectedIndex = event.target.getAttribute("data-id");
        let selectedValue = this.intrestList[selectedIndex];
        this.selectedObj = {
            'fy' : this.fyvalue,
            'bank' : selectedValue.bank
        };
    } */

    handleValueChange(event) {
        this.totalIntr = event.detail.fyintr;
        this.totalTds = event.detail.fytds;
    }
}