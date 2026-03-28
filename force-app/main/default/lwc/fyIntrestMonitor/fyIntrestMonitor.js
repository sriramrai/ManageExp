import { LightningElement, wire, api, track } from 'lwc';
import getFYIntrest from '@salesforce/apex/InvestmentController.getFYIntrest';
import { NavigationMixin } from 'lightning/navigation';
import interestWrapper from '@salesforce/apex/ExpenseManagerUtil.getInterestWrapper';
import {log, logError, toString, isValid} from 'c/utilityClass';
import {
    subscribe,
    unsubscribe,
    APPLICATION_SCOPE,
    MessageContext,
} from 'lightning/messageService';
import recordSelected from '@salesforce/messageChannel/Record_Selected__c';

export default class FyIntrestMonitor extends NavigationMixin(LightningElement) {
    subscription = null;
    fyvalue;
    intrestList = [];
    totalIntr = 0;
    totalTds = 0;
    errorMessage;
    investmentMap = {};
    selectedBank = 'SBI';
    totalAccumulated = 0;
    totalPaid = 0;
    totalTds = 0;
    @track wrapperData = [];
    isShowModal = false;
    @track recordList = [];
    rowOffset = 0;
    recordList1 = [];

    columns = [
        {label: 'Account Number', fieldName: 'accountLink', type: 'url', 
            typeAttributes: {
                label: {fieldName: 'accountNumber'},
                target: '_blank'
            }
        },
        {label: 'Bank Name', fieldName: 'bankName'},
        {label: 'Acc. Interest', fieldName: 'accumulatedInteres'},
        {label: 'Paid Interest', fieldName: 'interestPaid'},
        {label: 'TDS', fieldName: 'tds'},
        /* {label: 'Is Closed', fieldName: 'isClosed', type: 'boolean'}, */
        {label: 'Closed Date', fieldName: 'closedDate', type: 'date'}
    ];

    @wire(MessageContext)
    messageContext;

    @wire (interestWrapper, {'fy' : '$fyvalue'})
    interestWrapperList({data, error}) {
        if(data) {
            this.investmentMap = data;
            this.initialize();
            this.calculateTotals();

        }else if(error) {
            console.log('Error occured.....'+JSON.stringify(error));
        }
    }

    subscribeToMessageChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                recordSelected,
                (message) => this.handleMessage(message),
                { scope: APPLICATION_SCOPE }
            );
        }
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
        this.subscription = null;
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    handleMessage(message) {
        this.fyvalue = message.recordId;
    }

    initialize() {
        let myMap = {};
        this.wrapperData = [];
        for(const key in this.investmentMap) {
            console.log('key**** : '+key);
            let allLines = this.investmentMap[key];
            let totalAI = 0;
            let totalPI = 0;
            let totalTDS = 0;
            for(let item of allLines) {
                if(item.accumulatedInteres != null) {
                    totalAI += item.accumulatedInteres;
                }
                if(item.interestPaid != null) {
                    totalPI += item.interestPaid
                }
                if(item.tds != null) {
                    totalTDS += item.tds;
                }
            }
            let ivtObj = {};
            if(myMap.hasOwnProperty(key)) {
                ivtObj = myMap[key];
            }
            ivtObj.bank = key;
            ivtObj.interest = totalAI+totalPI;
            ivtObj.interest = ivtObj.interest.toFixed(2);
            ivtObj.isShow = true;
            myMap[key] = ivtObj;
            this.wrapperData.push(myMap[key]);
        }
        log('myMap**** : '+JSON.stringify(this.wrapperData));
    }
    
    @api 
    get allInvestments() {
        if(!isValid(this.investmentMap)) {
            return null;
        }else {
            log('inside getter of Investments***** : '+this.investmentMap[this.selectedBank]);
            return this.investmentMap[this.selectedBank];
        }
    }

    calculateTotals() {
        this.interestList = this.allInvestments;
        if(!isValid(this.interestList)) {
            return;
        }
        this.totalAccumulated = 0;
        this.totalPaid = 0;
        this.totalTds = 0;
        this.interestList.forEach(item => {
            if(item.accumulatedInteres != null) {
                this.totalAccumulated += item.accumulatedInteres;
            }
            if(item.interestPaid != null) {
                this.totalPaid += item.interestPaid;
            }
            if(item.tds != null) {
                this.totalTds += item.tds;
            }
        })

        this.totalAccumulated = this.totalAccumulated > 0 ? this.totalAccumulated.toFixed(2) : 0;
        this.totalPaid = this.totalPaid > 0 ? this.totalPaid.toFixed(2) : 0;
        this.totalTds = this.totalTds > 0 ? this.totalTds.toFixed(2) : 0;
    }

    get fyOptions() {
        return [
            { label: 'FY 21-22', value:'2021-2022'},
            { label: 'FY 22-23', value:'2022-2023'},
            { label: 'FY 23-24', value:'2023-2024'},
            { label: 'FY 24-25', value:'2024-2025'},
            { label: 'FY 25-26', value:'2025-2026'},
            { label: 'FY 26-27', value:'2026-2027'},
            { label: 'FY 27-28', value:'2027-2028'},
            { label: 'FY 28-29', value:'2028-2029'},
            { label: 'FY 29-30', value:'2029-2030'},
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
        this.subscribeToMessageChannel();
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
    showMore(event) {
        this.selectedBank = event.currentTarget.dataset.id;
        log('selected Bank**** : '+this.selectedBank);
        this.isShowModal = true;
        this.recordList = [];
        let allLines = this.investmentMap[this.selectedBank];
        /* this.recordList = allLines.map( record => {
            record,
            accountLink: '/${record.recordId}'
        }); */
        for(let item of allLines) {
            let obj = {...item};
            obj.accountLink = `/${item.recordId}`;
            this.recordList.push(obj);
        }
        this.calculateTotals();
    }

    hideModalBox(event) {
        this.isShowModal = false;
    }

    handleValueChange(event) {
        this.totalIntr = event.detail.fyintr;
        this.totalTds = event.detail.fytds;
    }
}