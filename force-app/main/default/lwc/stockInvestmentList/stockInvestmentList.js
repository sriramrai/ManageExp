import { LightningElement, wire, api, track } from 'lwc';
import {log, logError, isValidValue, toString} from 'c/utilityClass';
import getAllStock from '@salesforce/apex/ExpenseManagerUtil.getAllStocks';
import buySellStock from 'c/buySellStockModal';
import { refreshApex } from '@salesforce/apex';

export default class StockInvestmentList extends LightningElement {
    stockData;
    stockProvisionedData;
    expandedStockIds = new Set(); // Track which stock IDs are expanded
    
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

    // Toggle the expanded state for a stock
    toggleStockExpansion(stockId) {
        const expandedStockIds = new Set(this.expandedStockIds);
        if (expandedStockIds.has(stockId)) {
            expandedStockIds.delete(stockId);
        } else {
            expandedStockIds.add(stockId);
        }
        this.expandedStockIds = expandedStockIds;
    }

    // Getter for formatted stock data with expanded state
    get formattedStockData() {
        if (!this.stockData) return [];
        
        return this.stockData.map(stock => {
            // Create a copy of the stock object
            const formattedStock = {
                ...stock,
                totalBuyed: this.formatAmount(stock.totalBuyed),
                totalSold: this.formatAmount(stock.totalSold),
                totalInvested: this.formatAmount(stock.totalInvested),
                // Add expanded state property
                isExpanded: this.expandedStockIds.has(stock.recordId),
                expandedRowKey: stock.recordId + '_expanded'
            };
            
            // Format the lines if they exist
            if (formattedStock.lines && Array.isArray(formattedStock.lines)) {
                formattedStock.lines = formattedStock.lines.map(line => ({
                    ...line,
                    amount: this.formatAmount(line.amount)
                }));
            }
            
            return formattedStock;
        });
    }

    // Format amount to integer (remove decimals)
    formatAmount(amount) {
        if (amount === null || amount === undefined) {
            return '0';
        }
        // Convert to number and round to integer
        return Math.round(Number(amount)).toLocaleString();
    }

    // Single Actions menu handler (More, Buy, Sell)
    async handleActionsMenuSelect(event) {
        // Get the ID from the event target's closest data-id attribute
        let id = '';
        // Check if the event detail has the ID directly
        if (event.detail && event.detail.id) {
            id = event.detail.id;
        }
        // If not, try to find the data-id from the event target or currentTarget
        else if (event.currentTarget && event.currentTarget.dataset) {
            id = event.currentTarget.dataset.id;
        }
        else if (event.target && event.target.closest) {
            const closestWithDataId = event.target.closest('[data-id]');
            if (closestWithDataId) {
                id = closestWithDataId.dataset.id;
            }
        }
        // If still no ID, try to get it from the menu trigger
        else if (event.target && event.target.parentElement && event.target.parentElement.dataset) {
            id = event.target.parentElement.dataset.id;
        }
        // Final fallback - try to get from event.detail if it contains the id
        else if (event.detail && event.detail.id) {
            id = event.detail.id;
        }
        
        const action = event.detail.value;
        if (action === 'more') {
            // Scroll only when opening (before toggle, row is not expanded yet)
            const isOpening = !this.expandedStockIds.has(id);
            this.toggleStockExpansion(id);

            if (isOpening) {
                // Wait for LWC to re-render the expanded row before scrolling (double rAF + short delay)
                window.requestAnimationFrame(() => {
                    window.requestAnimationFrame(() => {
                        setTimeout(() => this.scrollToExpandedRow(id), 50);
                    });
                });
            }
        } else if (action === 'buy') {
            await this.buyOrder({ currentTarget: { dataset: { id: id } } });
        } else if (action === 'sell') {
            await this.sellOrder({ currentTarget: { dataset: { id: id } } });
        }
    }

    scrollToExpandedRow(stockId) {
        const container = this.template.querySelector('.slds-scrollable_y');
        const expandedRow = this.template.querySelector(`tr[data-stock-id="${stockId}"]`);
        if (!expandedRow || !container) return;

        // Position relative to scroll container (offsetTop can be relative to table, so use rects)
        const containerRect = container.getBoundingClientRect();
        const rowRect = expandedRow.getBoundingClientRect();
        const headerHeight = this.template.querySelector('.custom-investments-table thead')?.offsetHeight ?? 0;
        const padding = 8;

        // How far the row's top is from the visible top of the container
        const rowOffsetFromVisibleTop = rowRect.top - containerRect.top;
        // Desired scroll: bring row just below the sticky header
        const targetScrollTop = container.scrollTop + rowOffsetFromVisibleTop - headerHeight - padding;
        const maxScroll = Math.max(0, container.scrollHeight - container.clientHeight);
        const clampedScroll = Math.max(0, Math.min(targetScrollTop, maxScroll));

        container.scrollTo({
            top: clampedScroll,
            behavior: 'smooth'
        });
    }

    async buyOrder(event) {
        // Open Buy modal
        const id = event.currentTarget.dataset.id || event.currentTarget.id;
        log('inside buy Order.... : ' + id);
        const result = await buySellStock.open({
            size: 'small',
            description: 'Buy/Sell',
            content: { id: id, actionLabel: 'Buy' },
        });
        if (result === 'CREATED') {
            refreshApex(this.stockProvisionedData);
        }
    }

    async sellOrder(event) {
        // Open Sell modal
        const id = event.currentTarget.dataset.id || event.currentTarget.id;
        log('inside sell order.... : ' + id);
        const result = await buySellStock.open({
            size: 'small',
            description: 'Buy/Sell',
            content: { id: id, actionLabel: 'Sell' },
        });
        if (result === 'CREATED') {
            refreshApex(this.stockProvisionedData);
        }
    }
}
