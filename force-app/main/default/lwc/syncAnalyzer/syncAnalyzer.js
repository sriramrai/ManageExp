import { LightningElement, api } from 'lwc';

export default class SyncAnalyzer extends LightningElement {
    // Record Id is provided automatically when used as a record action
    @api recordId;
}
