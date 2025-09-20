import { LightningElement, wire } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import chartJs from '@salesforce/resourceUrl/chartjs';
import { log, logError, toString, isValid } from 'c/utilityClass';
import expenseByMonth from '@salesforce/apex/ExpenseManagerUtil.getExpenseByMonth';

export default class ExpenseAnalysisChart extends LightningElement {
    chart;
    isChartJsInitialized = false;
    isDataLoaded = false;
    data;
    chartData = [];
    chartLabel = [];

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

    prepareChartData(data) {
        this.chartLabel = [];
        this.chartData = [];
        Object.entries(data).forEach(([key, value]) => {
            this.chartLabel.push(key);
            this.chartData.push(value);
        });
    }

    tryRenderChart() {
        if (this.isChartJsLoaded && this.isDataLoaded) {
            this.renderChart();
        }
    }

    renderedCallback() {
        if (this.isChartJsInitialized) {
            return;
        }

        Promise.all([
            loadScript(this, chartJs)
        ])
        .then(() => {
            this.isChartJsLoaded = true;
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
            this.chart.destroy(); // Destroy existing chart if re-rendering
        }
        this.chart = new window.Chart(ctx, {
            type: 'bar', // or 'line', 'pie', etc.
            data: {
                //labels: ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'],
                labels: this.chartLabel,
                datasets: [{
                    label: '# Total Expenses',
                    data: this.chartData,
                    backgroundColor: [
                        'rgba(255, 99, 132, 0.2)',
                        'rgba(54, 162, 235, 0.2)',
                        'rgba(255, 206, 86, 0.2)',
                        'rgba(75, 192, 192, 0.2)',
                        'rgba(153, 102, 255, 0.2)',
                        'rgba(255, 159, 64, 0.2)'
                    ],
                    borderColor: [
                        'rgba(255, 99, 132, 1)',
                        'rgba(54, 162, 235, 1)',
                        'rgba(255, 206, 86, 1)',
                        'rgba(75, 192, 192, 1)',
                        'rgba(153, 102, 255, 1)',
                        'rgba(255, 159, 64, 1)'
                    ],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

}