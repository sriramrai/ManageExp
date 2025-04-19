import { LightningElement, wire, api } from 'lwc';
import differece from '@salesforce/apex/ExpenseController.calculateDifference'

export default class ExpenseDiff extends LightningElement {
    result;
    @api prop1;
    @wire(differece)
    getDifferene({error, data}) {
        if(data) {
            console.log('Data retrived successfully');
            this.result = JSON.stringify(data);
            console.log(this.result);
        }else if(error) {
            console.log('Error occured while fetching difference');
        }
    }
}