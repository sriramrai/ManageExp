import { LightningElement, wire, track, api } from 'lwc';
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
    isChartJsLoaded = false;
    isPolyfillLoaded = false;
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
        console.log('inside handle message**** : '+ this.selectedFiscalYear);
        // Force refresh by re-initializing the chart
        this.tryRenderChart();
    }

    @api
    loadData() {
        //loadData() will be called from component whern user will reselect the tab
        let totalAmount = 0;
        Object.entries(this.data).forEach(([key, value]) => {
          totalAmount += value;
        });
        this.notifyTotal(totalAmount);
    }

    refreshChart() {
        // Reset data loading state to force reload
        this.isDataLoaded = false;
        // Destroy existing chart if it exists
        if (this.chart) {
            this.chart.destroy();
            this.chart = null;
        }
        // Force re-render by setting a temporary flag
        setTimeout(() => {
            this.isDataLoaded = true;
        }, 10);
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
        console.log('inside notify total method*** : '+value);
        let customEvent = new CustomEvent("updatetotal", {detail: {total: value}});
        this.dispatchEvent(customEvent);
    }

    tryRenderChart() {
        if (this.isChartJsLoaded && this.isDataLoaded) {
            this.renderChart();
        }
    }

    renderedCallback() {
        console.log('inside rendered Callback****');
        if (this.isChartJsLoaded && this.isPolyfillLoaded) {
            return;
        }

        // Check if Chart.js is already available (safari compatibility fix)
        if (typeof window.Chart !== 'undefined' && typeof window.ChartDataLabels !== 'undefined') {
            this.isChartJsLoaded = true;
            this.isPolyfillLoaded = true;
            this.tryRenderChart();
            return;
        }

        // Load scripts with explicit error handling and retry mechanism
        this.loadChartResources();
    }

    loadChartResources() {
        loadScript(this, resizeObserverPolyfill)
            .then(() => {
                this.isPolyfillLoaded = true;
                return loadScript(this, chartJs);
            })
            .then(() => {
                // Verify Chart.js was loaded correctly
                if (typeof window.Chart === 'undefined') {
                    console.error('Chart.js failed to load properly');
                    throw new Error('Chart.js failed to load');
                }
                this.isChartJsLoaded = true;
                
                // Load ChartDataLabels
                return loadScript(this, chartjsDataLabels);
            })
            .then(() => {
                // Safely register ChartDataLabels if available
                if (typeof window.Chart !== 'undefined' && typeof window.ChartDataLabels !== 'undefined') {
                    try {
                        // Check if we're dealing with a newer version of Chart.js that uses different registration
                        if (typeof window.Chart.register === 'function') {
                            window.Chart.register(window.ChartDataLabels);
                        } else if (typeof window.Chart.plugins !== 'undefined') {
                            // For Chart.js v3+, plugins are registered differently
                            window.Chart.plugins.register(window.ChartDataLabels);
                        } else {
                            console.warn('Unknown Chart.js version, skipping plugin registration');
                        }
                    } catch (registerError) {
                        console.warn('Failed to register ChartDataLabels:', registerError);
                    }
                } else {
                    console.warn('ChartDataLabels not available for registration');
                }
                
                this.tryRenderChart();
            })
            .catch(error => {
                console.error('Error loading Chart.js resources:', error);
                // Add a fallback mechanism
                this.handleChartLoadFailure();
            });
    }

    handleChartLoadFailure() {
        // If we fail to load Chart.js properly, we should still render something
        console.warn('Chart.js failed to load, attempting fallback rendering');
        // We could show a message or placeholder here
        // For now, just make sure we don't crash the component
        this.isChartJsLoaded = true; // Prevent further attempts
        this.isPolyfillLoaded = true;
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

        // Safari compatibility fix: Check if Chart.js is available before creating chart
        if (typeof window.Chart === 'undefined') {
            console.error('Chart.js is not available when trying to create chart');
            return;
        }

        // Additional safeguard to ensure Chart.js helpers are available
        // Safari-specific fix: Create a fallback for Chart.helpers if needed
        if (typeof window.Chart === 'object' && window.Chart !== null) {
            // Ensure Chart.helpers exists to prevent Safari from failing
            if (typeof window.Chart.helpers === 'undefined') {
                console.warn('Chart.js helpers are not available, creating fallback...');
                // Create a minimal helpers object to prevent Safari errors
                window.Chart.helpers = {
                    // Provide minimal helpers that won't cause errors
                    array: {},
                    color: function() {},
                    easing: {},
                    element: {},
                    font: {},
                    math: {},
                    merge: function() { return {}; },
                    resolveObjectKey: function() { return null; }
                };
            }
        }

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
