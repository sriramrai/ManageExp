import { LightningElement } from 'lwc';

function isValid(data) {
    console.log('inside isvalid method...');
    if(data != '' && typeof data != 'undefined' && data != undefined) {
        return true;
    }

    return false;
}

export { isValid };