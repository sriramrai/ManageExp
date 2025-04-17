import { LightningElement, wire } from 'lwc';
import getTotal from '@salesforce/apex/HeaderController.getTotal';

export default class SummrizerComponent extends LightningElement {
    total = [];
    errorMessge;
    @wire(getTotal)
    fetchTotal({error, data}) {
        if(data) {
            console.log('data retrived....'+JSON.stringify(data));
            this.total = data;
        }else if(error){
            console.log('Error Occured...:'+JSON.stringify(error));
            this.errorMessge = error;
        }else {
            console.log('something unexpected occured...');
        }
    };
}