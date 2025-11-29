import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import resizeObserverPolyfill from '@salesforce/resourceUrl/ResizeObserverPolyfill';
import chartJs from '@salesforce/resourceUrl/chartjs';
import chartjsDataLabels from '@salesforce/resourceUrl/chartjsDataLabels'
import { log, logError, toString, isValid } from 'c/utilityClass';
import expenseByMonth from '@salesforce/apex/ExpenseManagerUtil.getExpenseByMonth';

export default class ExpenseAnalysisChart extends LightningElement {
    chart;
    isPolyfillLoaded = false;
    isChartJsInitialized = false;
    isDataLoaded = false;
    data;
    chartData = [];      // Stores the ACTUAL expense values
    chartLabel = [];
    
    // 🔥 New properties for capping logic
    maxPercent = 0.01;   // Max allowed visual size for any slice (30%)
    displayValues = [];  // Stores the CAPPED values for visual rendering

    @wire (expenseByMonth, {'fy' : 'test'})
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
        Object.entries(data).forEach(([key, value]) => {
            this.chartLabel.push(key);
            this.chartData.push(value); // Store the actual value
        });

        // 🔥 Implement Capping Logic: Limit the visual size of the largest slice
        const total = this.chartData.reduce((a, b) => a + b, 0);
        let maxAllowed = total * this.maxPercent;
        
        // Ensure no value exceeds the maximum allowed visual size
        this.displayValues = this.chartData.map(v => Math.min(v, maxAllowed));
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
            type: 'doughnut',
            data: {
                labels: this.chartLabel,
                datasets: [{
                    // 🔥 Use the CAPPED data for slice size rendering
                    data: this.displayValues,
                    backgroundColor: [
                        '#ff6384', '#36a2eb', '#ffce56',
                        '#4bc0c0', '#9966ff', '#ff9f40',
                        '#2c3e50', '#c0392b', '#7f8c8d'
                    ],
                    borderColor: '#fff',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                cutout: '60%', // Increased cutout for more space
                plugins: {
                    tooltip: { 
                        // Show the actual value on hover
                        enabled: true,
                        callbacks: {
                            label: (context) => {
                                const index = context.dataIndex;
                                const label = context.label;
                                const originalValue = this.chartData[index];
                                return `${label}: ${this.formatExpenseValue(originalValue)}`;
                            }
                        }
                    },
                    legend: { position: 'right' },
                    datalabels: {
                        color: (ctx) => {
                            const backgroundColor = ctx.dataset.backgroundColor[ctx.dataIndex];
                            return getContrastColor(backgroundColor);
                        },
                        font: { weight: 'bold', size: 13 },
                        
                        // Dynamic alignment to prevent label overlap
                        align: (ctx) => {
                            const dataset = ctx.chart.data.datasets[0].data;
                            const total = dataset.reduce((a, b) => a + b, 0);
                            const pct = dataset[ctx.dataIndex] / total;
                            
                            // Use 'outside' for visually small slices (< 5%)
                            return pct < 0.05 ? 'outside' : 'center';
                        },

                        anchor: 'center',
                        offset: 0,
                        clip: false, 
                        connector: {
                            enabled: true,
                            lineWeight: 1,
                            color: '#666',
                            length: 10
                        },
                        
                        // Formatter uses the ACTUAL uncapped data
                        formatter: (value, context) => {
                            // Fetch the original uncapped value
                            const originalValue = this.chartData[context.dataIndex]; 
                            const label = context.chart.data.labels[context.dataIndex];
                            
                            // Format the label (MM/YY) and the expense value (K/L/Cr)
                            const [mon, year] = label.split(" ");
                            const monthMap = {
                                JAN: "01", FEB: "02", MAR: "03", APR: "04",
                                MAY: "05", JUN: "06", JUL: "07", AUG: "08",
                                SEP: "09", OCT: "10", NOV: "11", DEC: "12"
                            };
                            const formattedMonth = `${monthMap[mon]}/${year.slice(-2)}`;
                            
                            const formattedValue = this.formatExpenseValue(originalValue);

                            return `${mon}\n${formattedValue}`;
                        }
                    }
                },
                layout: {
                    padding: 40 // Increased padding for outside labels
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