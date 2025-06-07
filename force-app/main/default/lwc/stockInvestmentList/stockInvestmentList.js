import { LightningElement, wire, api } from 'lwc';
import {log, logError, isValidValue, toString} from 'c/utilityClass';
import getAllStock from '@salesforce/apex/ExpenseManagerUtil.getAllStocks';
import buySellStock from 'c/buySellStockModal';
import { refreshApex } from '@salesforce/apex';

export default class StockInvestmentList extends LightningElement {
    stockData;
    stockProvisionedData;
    showLines = false;
    @api refreshData() {
        refreshApex(this.stockProvisionedData);
    }

    @wire (getAllStock, {})
    fetchStocks(stockObjs) {
        this.stockProvisionedData = stockObjs;
        if(stockObjs.data) {
            this.stockData = stockObjs.data;
            log('stock data fetched successfully.... : '+toString(this.stockData));
        }
    }

    showMore(event) {
        const id = event.currentTarget.id;
        const link = this.template.querySelector('a[id="' + id + '"]');
        const actionName = link.innerText;
        if(actionName == 'More' || actionName == 'Less') {
            const activeArea = this.template.querySelector('div[id="' + id + '"]');
            activeArea.style.display = activeArea.style.display == 'block' ? 'none' : 'block';
            link.innerText = link.innerText == 'Less' ? 'More' : 'Less';
        }else if(actionName == 'Buy') {
            log('Buy Order...');
        }else if(actionName == 'Sell') {
            log('Sell Order...');
        }
    }

    async buyOrder(event) {
        const id = event.currentTarget.id;
        log('inside buy Order.... : '+id);
        const result = await buySellStock.open({
            size: 'small',
            description: 'Buy/Sell',
            content: {'id': id, 'actionLabel': 'Buy'},
        });

        if(result == 'CREATED') {
            refreshApex(this.stockProvisionedData);
        }
    }

    async sellOrder(event) {
        const id = event.currentTarget.id;
        log('inside sell order.... : '+id);
        const result = await buySellStock.open({
            size: 'small',
            description: 'Buy/Sell',
            content: {'id': id, 'actionLabel': 'Sell'},
        });

        if(result == 'CREATED') {
            refreshApex(this.stockProvisionedData);
        }
    }
}