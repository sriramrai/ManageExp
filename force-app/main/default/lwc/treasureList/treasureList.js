import { LightningElement, wire, track } from 'lwc';
import {log, logError, toString} from 'c/utilityClass';
import getTreasures from '@salesforce/apex/ExpenseManagerUtil.getTreasures';

export default class TreasureList extends LightningElement {
    fyValue = null;
    showFY = true;
    initialData;
    @track recordList;
    totalObj = {'Dad': 0, 'Mom' : 0, 'Spouse' : 0, 'Total' : 0};
    @track column = [
                {'colId' :1, 'fieldName' : 'Tresuree__c', 'fieldValue' : 'Tresuree'}, 
                {'colId' :2, 'fieldName' : 'Date__c', 'fieldValue': 'Date'}, 
                {'colId' :3, 'fieldName' : 'Amount__c', 'fieldValue': 'Amount'}, 
                {'colId' :4, 'fieldName' : 'Details__c', 'fieldValue': 'Details'}
    ];
    initialCols;

    @wire(getTreasures, {'fy': '$fyValue'})
    getTresurees({error, data}) {
        if(data) {
            this.recordList = data;
            this.initialData = [...data];
            this.initialCols = [...this.column];
            log('data inside meth *** : '+toString(this.recordList));
            this.caculateTotal();
        }else if(error) {
            logError('Error while fetching data*** : '+toString(error));
        }
    }

    caculateTotal() {
        this.recordList.forEach(item => {
            let amount = item.Amount__c;
            if(item.Tresuree__c == 'Mom') {
                this.totalObj['Mom'] += amount;
            }else if(item.Tresuree__c == 'Dad') {
                this.totalObj['Dad'] += amount;
            }else if(item.Tresuree__c == 'Spouse') {
                this.totalObj['Spouse'] += amount;
            }
            this.totalObj['Total'] += amount;
        });
    }

    alignByYear() {
        if(this.showFY) {
            const grouped = this.sumByTresureeAndFiscalYear(this.recordList);
            const groupedArray = Object.entries(grouped).map(([key, total]) => {
                const [fiscalYear, name] = key.split(' - ');
                const fyStart = parseInt(fiscalYear.match(/\d{4}/)[0], 10);
                return {
                    id: `${fiscalYear}-${name}`,
                    fiscalYear,
                    tresuree: name,
                    fyStart,
                    total
                };
            }).sort((a, b) => a.fyStart - b.fyStart);
            log('groupedArray*** : '+toString(groupedArray));
            this.recordList = [...groupedArray];
            let column1 = [
                { 'colId' :1, fieldName: 'fiscalYear', fieldValue: 'fiscalYear' }, 
                { 'colId' :2, fieldName: 'tresuree', fieldValue: 'tresuree' }, 
                { 'colId' :3, fieldName: 'total', fieldValue: 'total' }
            ];
            this.column = [...column1];
            log('modified List ***** : '+toString(this.recordList));
        }else {
            this.recordList = [...this.initialData];
            this.column = [...this.initialCols];
        }

        this.showFY = !this.showFY;
        
    }

    sumByTresureeAndFiscalYear(records) {
        const groupedTotals = {};
        records.forEach(record => {
        const fiscalYear = this.getFiscalYearFromDate(record.Date__c);
        const name = record.Tresuree__c || 'Unknown';
        const key = `${fiscalYear} - ${name}`;
        const amount = Number(record.Amount__c) || 0;
        if (!groupedTotals[key]) {
            groupedTotals[key] = 0;
        }
            groupedTotals[key] += amount;
        });
        return groupedTotals;
    }

    getFiscalYearFromDate(dateStr) {
        const date = new Date(dateStr);
        const year = date.getFullYear();
        const month = date.getMonth(); // 0 = Jan, 11 = Dec

        const fiscalYearStart = month >= 3 ? year : year - 1;
        const fiscalYearEnd = fiscalYearStart + 1;

        return `FY ${fiscalYearStart}-${fiscalYearEnd}`;
    }

}