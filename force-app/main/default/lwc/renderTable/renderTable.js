import { LightningElement, api, track } from 'lwc';
import {log, toString} from 'c/utilityClass';

export default class RenderTable extends LightningElement {
    _columns = [];
    _tabledata = [];
    @track rowData = [];

    @api
    set columns(value) {
        this._columns = value;
        this.buildRowData();
    }

    get columns() {
        return this._columns;
    }

    @api
    set tabledata(value) {
        this._tabledata = value;
        this.buildRowData();
    }

    get tabledata() {
        return this._tabledata;
    }

    buildRowData() {
        if (!this._tabledata || !this._columns || this._tabledata.length === 0) {
            this.rowData = [];
            return;
        }

        this.rowData = this._tabledata.map((record, index) => {
            return {
                id: record.Id || record.id || index, // fallback if Id missing
                values: this._columns.map(col => record[col.fieldName] || '')
            };
        });
    }

}