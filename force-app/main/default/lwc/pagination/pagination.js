/*** 
 * VAR Description
 * @api recordsize: Page wise record size, This varible is defaulted at 5, and can be modified by the caller, If needs to display more than 5 records 
 * 
*/
import { LightningElement, api } from 'lwc';

export default class Pagination extends LightningElement {
    @api recordsize = 7;
    totalPage = 0;
    currentPage = 1;
    totalrecords;
    get disableNext() {
        let status = this.totalPage == this.currentPage ? true : false;
        return status;
    }
    
    get disablePrevious() {
        let status = this.currentPage > 1 ? false : true;
        return status;
    }

    get records() {
        return this.visibleRecords;
    }

    @api set records(data) {
        if(data) {
            this.totalrecords = data;
            this.recordsize = Number(this.recordsize);
            this.totalPage = Math.ceil(data.length/this.recordsize);
            this.updateRecords();
        }
    }

    updateRecords() {
        const start = (this.currentPage-1)*this.recordsize;
        const end = this.recordsize*this.currentPage;
        this.visibleRecords = this.totalrecords.slice(start, end);
        this.dispatchEvent(new CustomEvent('update', {
            detail: {
                records:this.visibleRecords
            }
        }));
    }
    
    nextHandler() {
        this.currentPage = this.currentPage+1;
        this.updateRecords();
    }

    previousHandler() {
        this.currentPage = this.currentPage-1;
        this.updateRecords();
    }
}