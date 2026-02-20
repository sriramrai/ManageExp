import { LightningElement, wire, track } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import resizeObserverPolyfill from '@salesforce/resourceUrl/ResizeObserverPolyfill';
import chartJs from '@salesforce/resourceUrl/chartjs';
import chartjsDataLabels from '@salesforce/resourceUrl/chartjsDataLabels'
import { log, logError, toString, isValid } from 'c/utilityClass';
import expenseByMonth from '@salesforce/apex/ExpenseManagerUtil.getExpenseByMonth';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import recordSelected from '@salesforce/messageChannel/Record_Selected__c';

export default class ExpenseAnalysisChart extends LightningElement {
    chart;
    isPolyfillLoaded = false;
    isChartJsInitialized = false;
    isDataLoaded = false;
    data;
    chartData = [];      // Stores the ACTUAL expense values
    chartLabel = [];
    selectedFiscalYear = '2025-2026'; // Default fiscal year
    
    // 🔥 New properties for capping logic
    maxPercent = 0.01;   // Max allowed visual size for any slice (30%)
    displayValues = [];  // Stores the CAPPED values for visual rendering

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    disconnectedCallback() {
        this.unsubscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            recordSelected,
            (message) => this.handleMessage(message)
        );
    }

    unsubscribeToMessageChannel() {
        unsubscribe(this.subscription);
    }

    handleMessage(message) {
        this.selectedFiscalYear = message.recordId;
        // Re-wire the data with the new fiscal year
        this.refreshData();
    }

    refreshData() {
        // Force re-wiring by setting a temporary property
        this.isDataLoaded = false;
        this.requestUpdate();
    }

    requestUpdate() {
        // This will trigger the wire adapter to re-run with the new fiscal year
        // We'll use a workaround by adding a dummy property to force refresh
        this.isDataLoaded = true;
    }

    @wire (expenseByMonth, {'fy' : '$selectedFiscalYear'})
    expenseRecord({data, error}) {
        if(data) {
            this.data = data;
            log('data fetched while accessing expense..'+toString(this.data));
            this.prepareChartData(data);
            this.isDataLoaded = true;
            this.tryRenderChart();
        }else if(error) {
            logError('error while fetching expense by month...');
        }
    }

    /**
     * Prepares data, calculates total, and caps display values.
     */
    prepareChartData(data) {
        this.chartLabel = [];
        this.chartData = [];
        let totalAmount = 0;
        Object.entries(data).forEach(([key, value]) => {
            this.chartLabel.push(key);
            this.chartData.push(value); // Store the actual value
            totalAmount += value;
        });
        this.notifyTotal(totalAmount);
        // 🔥 Implement Capping Logic: Limit the visual size of the largest slice
        const total = this.chartData.reduce((a, b) => a + b, 0);
        let maxAllowed = total * this.maxPercent;
        
        // Ensure no value exceeds the maximum allowed visual size
        this.displayValues = this.chartData.map(v => Math.min(v, maxAllowed));
    }

    notifyTotal(value) {
        let customEvent = new CustomEvent("updatetotal", {detail: {total: value}});
        this.dispatchEvent(customEvent);
    }

    tryRenderChart() {
        if (this.isChartJsLoaded && this.isDataLoaded) {
            this.renderChart();
        }
    }

    renderedCallback() {
        if (this.isChartJsInitialized && this.isPolyfillLoaded) {
            return;
        }

        Promise.all([
            loadScript(this, resizeObserverPolyfill),
            loadScript(this, chartJs),
            loadScript(this, chartjsDataLabels)
        ])
        .then(() => {
            this.isChartJsLoaded = true;
            this.isPolyfillLoaded = true;
            window.Chart.register(window.ChartDataLabels);
            this.tryRenderChart();

        })
        .catch(error => {
            console.error('Error loading Chart.js:', error);
        });
    }

    renderChart() {
        const canvas = this.template.querySelector('canvas.chart');
        if (!canvas) return;

        const ctx = canvas.getContext('2d');

        if (this.chart) {
            this.chart.destroy();
        }

        // Helper function to determine text color based on background color
        // This function calculates luminosity and is placed inside renderChart for simplicity.
        const getContrastColor = (backgroundColor) => {
            // Remove transparency (alpha channel) if present
            const hex = backgroundColor.replace('#', '').substring(0, 6);
            
            // Convert to RGB
            const r = parseInt(hex.substring(0, 2), 16);
            const g = parseInt(hex.substring(2, 4), 16);
            const b = parseInt(hex.substring(4, 6), 16);
            
            // Calculate relative luminosity (standard formula)
            const luminosity = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
            
            // Use black for light colors (luminosity > 0.5), white for dark colors
            return luminosity > 0.5 ? '#000000' : '#FFFFFF';
        };

        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels: this.chartLabel,
                datasets: [
                    {
                        label: 'Monthly Expense',
                        type: 'bar',
                        data: this.chartData, // original uncapped values
                        backgroundColor: [
                            '#ff6384', '#36a2eb', '#ffce56',
                            '#4bc0c0', '#9966ff', '#ff9f40',
                            '#2c3e50', '#c0392b', '#7f8c8d'
                        ],
                        borderWidth: 1
                    },
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    datalabels: {
                        anchor: 'end',
                        align: 'top',
                        font: { weight: 'bold', size: 12 },
                        formatter: (value) => this.formatExpenseValue(value)
                    },
                    tooltip: {
                        callbacks: {
                            label: (context) => {
                                const original = this.chartData[context.dataIndex];
                                const name = context.label;
                                return `${name}: ${this.formatExpenseValue(original)}`;
                            }
                        }
                    },
                    legend: { position: 'top' }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        suggestedMax: Math.max(...this.chartData) * 1.15, // 15% extra space
                        title: {
                            display: true,
                            text: 'Amount'
                        }
                    },
                    x: {
                        title: {
                            display: false,
                            text: 'Month'
                        }
                    }
                }
            }
        });
    }
    
    /**
     * Helper method to format large numbers to K, L, or Cr.
     */
    formatExpenseValue(value) {
        if (value >= 10000000) return (value / 10000000).toFixed(1) + ' Cr';
        if (value >= 100000) return (value / 100000).toFixed(1) + ' L';
        if (value >= 1000) return (value / 1000).toFixed(1) + ' K';
        return value.toLocaleString();
    }
}
