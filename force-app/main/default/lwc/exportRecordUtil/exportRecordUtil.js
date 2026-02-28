import { LightningElement, wire, track } from 'lwc';
import exportData from '@salesforce/apex/SyncDataController.exportExpenseRecord';
import sheetjs from '@salesforce/resourceUrl/sheetjs';
import { loadScript } from 'lightning/platformResourceLoader';
import exportRecords from '@salesforce/apex/SyncDataController.exportRecords';
import getAvailableObjects from '@salesforce/apex/SyncDataController.getAvailableObjects';
import getAvailableFields from '@salesforce/apex/SyncDataController.getFieldsForObject';
import { log, logError, toString, formatDate, isValidValue } from 'c/utilityClass';

export default class ExportRecordUtil extends LightningElement {
    @track records;
    @track error;
    sheetJsInitialized = false;
    @track messageObj = {};

    // Bindings for inputs
    objectName;
    groupedField;
    fromDate;
    toDate;
    filterField;
    // Object options for combobox
    objectOptions = [];
    fieldOptions = [];
    @track exportedRecordCounts;

    // Load available objects (custom objects per existing Apex) for selector
    @wire(getAvailableObjects)
    wiredObjects({ error, data }) {
        if (data) {
            this.objectOptions = data;
        } else if (error) {
            this.error = error;
            logError('Error Occured... : '+toString(error));
        }
    }

    @wire(getAvailableFields, {objectName : '$objectName'})
    wiredFields({ error, data }) {
        if (data) {
            this.fieldOptions = data;
        } else if (error) {
            this.error = error;
            logError('Error Occured... : '+toString(error));
        }
    }

    // Existing demo wire (kept but unused in UI)
    @wire(exportData)
    wiredData1({ error, data }) {
        if (error) {
            this.error = error;
        }
    }

    // Fetch lines based on selected object and grouped field
    /* @wire(exportExpenseLines, { objectName: '$objectName', groupedField: '$groupedField', fromDate: '$fromDate', toDate : '$toDate' })
    wiredLines({ error, data }) {
        if (data) {
            this.records = data;
        } else if (error) {
            this.error = error;
        }
    } */

    renderedCallback() {
        if (this.sheetJsInitialized) {
            return;
        }
        this.sheetJsInitialized = true;

        loadScript(this, sheetjs)
            .then(() => {
                // SheetJS loaded
            })
            .catch(error => {
                this.error = error;
            });
    }

    // Handlers for UI inputs
    handleObjectChange(event) {
        this.objectName = event.detail.value;
    }

    handleGroupedFieldChange(event) {
        this.groupedField = event.target.value;
    }

    handleFromDateChange(event) {
        this.fromDate = event.target.value;
    }

    handleToDateChange(event) {
        this.toDate = event.target.value;
    }

    handlerFilterFieldChange(event) {
        this.filterField = event.target.value;
    }

    checkFormValidity() {
        if(!isValidValue(this.objectName) ||
        !isValidValue(this.groupedField) || 
        !isValidValue(this.fromDate) ||
        !isValidValue(this.toDate) || 
        !isValidValue(this.filterField)) {
            return false;
        }
        return true;
    }

    exportToExcel() {
        //if (!this.records || this.records.length === 0) return;
        let valid = this.checkFormValidity();
        if(valid) {
            this.exportAndSaveData();
        }else {
            this.messageObj.type = 'ERROR';
            this.messageObj.class = 'msg-error';
            this.messageObj.message = 'Please fill all fields prior to Export Data';
        }
    }

    exportAndSaveData() {
        exportRecords({ 
            objectName: this.objectName, 
            groupedField: this.groupedField, 
            fromDate: this.fromDate, 
            toDate : this.toDate,
            filterField: this.filterField })
        .then(success => {
            log('Data Exported Successfully....'+toString(success));
            this.messageObj.type = 'SUCCESS';
            this.messageObj.class = 'msg-success';
            if(isValidValue(success)) {
                this.writeToFile(success);
                this.messageObj.message = 'Data Exported Successfully...Total Records: '+this.exportedRecordCounts;
            }else {
                this.messageObj.message = 'No Data to Export...';
            }
        })
        .catch(error => {
            this.messageObj.type = 'ERROR';
            this.messageObj.class = 'msg-error';
            this.messageObj.message = toString(error);
            logError('Error Occured while exporing data .... : '+toString(error));
        })
    }

    writeToFile(data) {
        const fieldName = this.groupedField || 'Name';
        const parts = fieldName.split('.');
        const field1 = parts[0];
        const field2 = parts.length > 1 ? parts[1] : null;
        const dataMap = this.formatData(data, field1, field2);
        const workbook = XLSX.utils.book_new();
        this.exportedRecordCounts = 0;
        dataMap.forEach((value, key) => {
            const worksheet = XLSX.utils.json_to_sheet(value);
            this.exportedRecordCounts += value.length;
            // Sheet names max length 31; sanitize
            const safeKey = String(key).substring(0, 31).replace(/[/\\?*[\]:]/g, ' ');
            XLSX.utils.book_append_sheet(workbook, worksheet, safeKey || 'Sheet');
        });
        const fileName = this.objectName + '_' + formatDate(this.fromDate) + '_' + formatDate(this.toDate) + '.xlsx';
        XLSX.writeFile(workbook, fileName);
    }

    formatData(data, field1, field2) {
        const dataMap = new Map();
        data.forEach(record => {
            let groupKey = 'Unknown';
            try {
                if (field2) {
                    // relationship field
                    groupKey = (record[field1] && record[field1][field2]) ? record[field1][field2] : 'Unknown';
                } else {
                    groupKey = record[field1] || 'Unknown';
                }
            } catch (e) {
                groupKey = 'Unknown';
            }
            if (!dataMap.has(groupKey)) {
                dataMap.set(groupKey, []);
            }
            dataMap.get(groupKey).push(record);
        });

        return dataMap;
    }
}
