import { LightningElement, wire } from 'lwc';
import getNaamJaapData from '@salesforce/apex/NaamJaapController.getNaamJaapData';
import getNaamJaapDataByMonthYear from '@salesforce/apex/NaamJaapController.getNaamJaapDataByMonthYear';

export default class NaamJaapTracker extends LightningElement {
    naamJaapList;
    error;
    isLoading = true;
    entityTotals = {};
    selectedMonth = '1';
    selectedYear = '2026';

    monthOptions = [
        { label: 'January', value: '1' },
        { label: 'February', value: '2' },
        { label: 'March', value: '3' },
        { label: 'April', value: '4' },
        { label: 'May', value: '5' },
        { label: 'June', value: '6' },
        { label: 'July', value: '7' },
        { label: 'August', value: '8' },
        { label: 'September', value: '9' },
        { label: 'October', value: '10' },
        { label: 'November', value: '11' },
        { label: 'December', value: '12' }
    ];

    yearOptions = [
        { label: '2026', value: '2026' },
        { label: '2027', value: '2027' },
        { label: '2028', value: '2028' },
        { label: '2029', value: '2029' },
        { label: '2030', value: '2030' }
    ];

    @wire(getNaamJaapDataByMonthYear, {month: '$selectedMonth', year: '$selectedYear'})
    wiredNaamJaapData({error, data}) {
        if(data) {
            this.naamJaapList = data.map(item => ({
                ...item,
                recordUrl: '/' + item.recordId
            }));
            this.calculateEntityTotals();
            this.error = undefined;
            this.isLoading = false;
        } else if(error) {
            this.error = error;
            this.naamJaapList = undefined;
            this.isLoading = false;
            console.error('Error fetching Naam Jaap records: ', error);
        }
    }

    connectedCallback() {
        this.selectedMonth = (new Date().getMonth() + 1).toString();
        this.selectedYear = new Date().getFullYear().toString();
    }
    
    handleMonthChange(event) {
        this.selectedMonth = event.detail.value;
    }

    handleYearChange(event) {
        this.selectedYear = event.detail.value;
    }

    calculateEntityTotals() {
        this.entityTotals = {};
        if(this.naamJaapList && this.naamJaapList.length > 0) {
            this.naamJaapList.forEach(item => {
                if(item.entity) {
                    if(this.entityTotals[item.entity]) {
                        this.entityTotals[item.entity] += item.count;
                    } else {
                        this.entityTotals[item.entity] = item.count;
                    }
                }
            });
        }
    }

    get entityTotalsArray() {
        return Object.keys(this.entityTotals).map(entity => ({
            entity: entity,
            totalCount: this.entityTotals[entity]
        }));
    }
}
