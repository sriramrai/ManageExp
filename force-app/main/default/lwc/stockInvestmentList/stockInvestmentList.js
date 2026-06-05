import { LightningElement, wire, api, track } from "lwc";
import {
  log,
  logError,
  isValidValue,
  toString,
  formatDate
} from "c/utilityClass";
import getAllStock from "@salesforce/apex/ExpenseManagerUtil.getAllStocks";
import refreshStockPrice from "@salesforce/apex/ExpenseManagerUtil.refreshStockPrice";
import buySellStock from "c/buySellStockModal";
import { refreshApex } from "@salesforce/apex";
export default class StockInvestmentList extends LightningElement {
  @track stockData;
  stockProvisionedData;
  expandedStockIds = new Set(); // Track which stock IDs are expanded
  @track last10Transaction = [];
  isOpen = false;
  totalInvested = 0;
  totalCurrentValue = 0;
  totalDiff = 0;
  headerNote = "";
  @track originalData;
  @track diffSortOrder = null; // null (original), 'desc' (greater to smaller), 'asc' (smaller to greater)
  totalDiffClass = "header-diff-positive";
  @track showButtonModal = false;
  @track selectedStockId = null;
  @track modalButtons = [
    { label: "More", variant: "neutral" },
    { label: "Buy", variant: "brand" },
    { label: "Sell", variant: "brand" }
  ];

  get searchClass() {
    return this.isOpen ? "search-box open" : "search-box";
  }

  toggleSearch() {
    this.isOpen = !this.isOpen;
  }

  handleSearch(event) {
    let searchString = event.target.value.toLowerCase();
    if (!searchString) {
      this.stockData = this.originalData;
      return;
    }
    this.stockData = this.originalData.filter((item) =>
      item.stockName.toLowerCase().includes(searchString)
    );
  }

  handleReset() {
    this.stockData = this.originalData;
  }

  handleRefresh() {
    refreshStockPrice()
      .then((result) => {
        log("Stock prices refreshed successfully: " + result);
        refreshApex(this.stockProvisionedData);
      })
      .catch((error) => {
        logError("Error refreshing stock prices: " + toString(error));
      });
  }

  getHeaderNote() {
    if (this.last10Transaction.length < 1) {
      return "";
    }
    let message = "*Last share ";
    message += "(" + this.stockData[0].stockName + ") ";
    message += this.last10Transaction[0].buySell == "Buy" ? "bought " : "sold ";
    message += "on " + formatDate(new Date(this.last10Transaction[0].sdate));
    return message;
  }

  @wire(getAllStock, {})
  fetchStocks(stockObjs) {
    this.stockProvisionedData = stockObjs;
    if (stockObjs.data) {
      let stocks = JSON.parse(JSON.stringify(stockObjs.data));
      this.totalInvested = 0;
      this.totalCurrentValue = 0;
      stocks.forEach((stock) => {
        this.totalInvested += Number(stock.totalInvested) || 0;
        this.totalCurrentValue += Number(stock.currentValue) || 0;
        stock.quantity = Number(stock.quantity);
        stock.totalSold = Number(stock.totalSold);
        stock.lines.forEach((stockLine) => {
          stockLine.styleclass =
            "slds-grid slds-gutters slds-var-p-vertical_xx-small";
          if (stockLine.buySell == "Sell") {
            stockLine.styleclass += " sold-hilighter";
          }
          if (this.last10Transaction.length < 10) {
            this.last10Transaction.push(stockLine);
          }
          stockLine.sdate = formatDate(new Date(stockLine.sdate));
        });
      });
      this.totalDiff = this.totalInvested - this.totalCurrentValue;
      this.totalDiffClass =
        this.totalCurrentValue < this.totalInvested
          ? "header-diff-negative"
          : "header-diff-positive";
      //this.stockData = stockObjs.data;
      this.stockData = stocks;
      this.headerNote = this.getHeaderNote();
      this.originalData = stocks;
      log("stock data fetched successfully.... : " + toString(this.stockData));
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

  // Handle diff column header click for sorting
  handleDiffSort() {
    if (this.diffSortOrder === null) {
      // First click: sort descending (greater to smaller)
      this.diffSortOrder = "desc";
    } else if (this.diffSortOrder === "desc") {
      // Second click: sort ascending (smaller to greater)
      this.diffSortOrder = "asc";
    } else {
      // Third click: back to original order
      this.diffSortOrder = null;
    }
  }

  // Get icon name based on sort order
  get diffSortIconName() {
    return this.diffSortOrder === "desc"
      ? "utility:arrowdown"
      : "utility:arrowup";
  }

  // Getter for formatted stock data with expanded state and sorting
  get formattedStockData() {
    if (!this.stockData) return [];

    let dataToFormat = [...this.stockData];

    // Apply diff sorting if active
    if (this.diffSortOrder) {
      dataToFormat.sort((a, b) => {
        const diffA =
          (Number(a.currentValue) || 0) - (Number(a.totalInvested) || 0);
        const diffB =
          (Number(b.currentValue) || 0) - (Number(b.totalInvested) || 0);
        return this.diffSortOrder === "desc" ? diffB - diffA : diffA - diffB;
      });
    }

    return dataToFormat.map((stock) => {
      // Create a copy of the stock object
      // Determine if return is positive or negative
      const investedAmount = Number(stock.totalInvested) || 0;
      const currentValueAmount = Number(stock.currentValue) || 0;
      const returnStatus =
        currentValueAmount >= investedAmount ? "positive" : "negative";

      // Calculate diff value and class
      const diff = currentValueAmount - investedAmount;
      const diffValue = "₹ " + this.formatAmount(Math.abs(diff));
      const diffClass = "diff-value"; // Single class for both positive and negative

      const formattedStock = {
        ...stock,
        totalBuyed: this.formatAmount(stock.totalBuyed),
        totalSold: this.formatAmount(stock.totalSold),
        totalInvested: this.formatAmount(stock.totalInvested),
        // Add expanded state property
        isExpanded: this.expandedStockIds.has(stock.recordId),
        expandedRowKey: stock.recordId + "_expanded",
        returnStatus: returnStatus,
        returnClass:
          returnStatus === "positive"
            ? "return-cell positive"
            : "return-cell negative",
        diffValue: diffValue,
        diffClass: diffClass
      };

      // Format the lines if they exist
      if (formattedStock.lines && Array.isArray(formattedStock.lines)) {
        formattedStock.lines = formattedStock.lines.map((line) => ({
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
      return "0";
    }
    // Convert to number and round to integer
    return Math.round(Number(amount)).toLocaleString();
  }

  // Handle stock name click - prevent row click from firing
  handleStockNameClick(event) {
    event.stopPropagation();
  }

  // Handle row click to open modal
  handleRowClick(event) {
    const stockId = event.currentTarget.dataset.id;
    this.selectedStockId = stockId;
    this.showButtonModal = true;
  }

  // Handle modal close event
  handleModalClose() {
    this.showButtonModal = false;
  }

  // Handle modal button click
  handleModalButtonClick(event) {
    const buttonLabel = event.detail.label;
    this.showButtonModal = false;

    if (buttonLabel === "More") {
      this.toggleStockExpansion(this.selectedStockId);
      // Wait for re-render and then scroll
      window.requestAnimationFrame(() => {
        window.requestAnimationFrame(() => {
          setTimeout(() => this.scrollToExpandedRow(this.selectedStockId), 50);
        });
      });
    } else if (buttonLabel === "Buy") {
      this.buyOrder({
        currentTarget: { dataset: { id: this.selectedStockId } }
      });
    } else if (buttonLabel === "Sell") {
      this.sellOrder({
        currentTarget: { dataset: { id: this.selectedStockId } }
      });
    }
  }

  // Single Actions menu handler (More, Buy, Sell)
  async handleActionsMenuSelect(event) {
    // Get the ID from the event target's closest data-id attribute
    let id = "";
    // Check if the event detail has the ID directly
    if (event.detail && event.detail.id) {
      id = event.detail.id;
    }
    // If not, try to find the data-id from the event target or currentTarget
    else if (event.currentTarget && event.currentTarget.dataset) {
      id = event.currentTarget.dataset.id;
    } else if (event.target && event.target.closest) {
      const closestWithDataId = event.target.closest("[data-id]");
      if (closestWithDataId) {
        id = closestWithDataId.dataset.id;
      }
    }
    // If still no ID, try to get it from the menu trigger
    else if (
      event.target &&
      event.target.parentElement &&
      event.target.parentElement.dataset
    ) {
      id = event.target.parentElement.dataset.id;
    }
    // Final fallback - try to get from event.detail if it contains the id
    else if (event.detail && event.detail.id) {
      id = event.detail.id;
    }

    const action = event.detail.value;
    if (action === "more") {
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
    } else if (action === "buy") {
      await this.buyOrder({ currentTarget: { dataset: { id: id } } });
    } else if (action === "sell") {
      await this.sellOrder({ currentTarget: { dataset: { id: id } } });
    }
  }

  scrollToExpandedRow(stockId) {
    const container = this.template.querySelector(".slds-scrollable_y");
    const expandedRow = this.template.querySelector(
      `tr[data-stock-id="${stockId}"]`
    );
    if (!expandedRow || !container) return;

    // Position relative to scroll container (offsetTop can be relative to table, so use rects)
    const containerRect = container.getBoundingClientRect();
    const rowRect = expandedRow.getBoundingClientRect();
    const headerHeight =
      this.template.querySelector(".custom-investments-table thead")
        ?.offsetHeight ?? 0;
    const padding = 8;

    // How far the row's top is from the visible top of the container
    const rowOffsetFromVisibleTop = rowRect.top - containerRect.top;
    // Desired scroll: bring row just below the sticky header
    const targetScrollTop =
      container.scrollTop + rowOffsetFromVisibleTop - headerHeight - padding;
    const maxScroll = Math.max(
      0,
      container.scrollHeight - container.clientHeight
    );
    const clampedScroll = Math.max(0, Math.min(targetScrollTop, maxScroll));

    container.scrollTo({
      top: clampedScroll,
      behavior: "smooth"
    });
  }

  async buyOrder(event) {
    // Open Buy modal
    const id = event.currentTarget.dataset.id || event.currentTarget.id;
    log("inside buy Order.... : " + id);
    const result = await buySellStock.open({
      size: "small",
      description: "Buy/Sell",
      content: { id: id, actionLabel: "Buy" }
    });
    if (result === "CREATED") {
      refreshApex(this.stockProvisionedData);
    }
  }

  async sellOrder(event) {
    // Open Sell modal
    const id = event.currentTarget.dataset.id || event.currentTarget.id;
    log("inside sell order.... : " + id);
    const result = await buySellStock.open({
      size: "small",
      description: "Buy/Sell",
      content: { id: id, actionLabel: "Sell" }
    });
    if (result === "CREATED") {
      refreshApex(this.stockProvisionedData);
    }
  }
}
