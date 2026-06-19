import { LightningElement, wire, track } from 'lwc';
import getTotal from '@salesforce/apex/HeaderController.getTotal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SummrizerComponent extends LightningElement {
    total = [];
    errorMessge;
    @track isValuesVisible = false;
    passwordInput = '';
    isPasswordModalOpen = false;
    
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
    }

    // Get icon name based on visibility state
    get eyeIconName() {
        return this.isValuesVisible ? 'utility:hide' : 'utility:preview';
    }

    // Get masked or actual value for deposited
    getDisplayValue(value) {
        return this.isValuesVisible ? value : '****';
    }

    // Format total data with masked/visible values
    get formattedTotal() {
        if(!this.total) return [];
        return this.total.map(item => ({
            ...item,
            displayDeposited: this.isValuesVisible ? item.deposited : '****',
            displayMatured: this.isValuesVisible ? item.maturedamount : '****'
        }));
    }

    // Handle eye icon click
    handleToggleVisibility() {
        if(this.isValuesVisible) {
            // If values are visible, hide them
            this.isValuesVisible = false;
        } else {
            // If values are hidden, show password modal
            this.isPasswordModalOpen = true;
        }
    }

    // Handle password input change
    handlePasswordChange(event) {
        this.passwordInput = event.target.value;
    }

    // Handle password modal close
    handleCloseModal() {
        this.isPasswordModalOpen = false;
        this.passwordInput = '';
    }

    // Handle password submission
    handlePasswordSubmit() {
        if(this.passwordInput === '100') {
            // Correct password
            this.isValuesVisible = true;
            this.isPasswordModalOpen = false;
            this.passwordInput = '';
            
            // Show success message
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Values are now visible',
                    variant: 'success'
                })
            );
        } else {
            // Incorrect password
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Incorrect password. Please try again.',
                    variant: 'error'
                })
            );
            this.passwordInput = '';
        }
    }

    // Handle Enter key press in password input
    handlePasswordKeyUp(event) {
        if(event.keyCode === 13) {
            this.handlePasswordSubmit();
        }
    }
}
